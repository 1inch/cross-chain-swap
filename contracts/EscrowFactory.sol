// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";

import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "limit-order-settlement/extensions/ResolverFeeExtension.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { IEscrowDst, EscrowDst } from "./EscrowDst.sol";
import { IEscrowSrc, EscrowSrc } from "./EscrowSrc.sol";
import { Clones } from "./libraries/Clones.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, WhitelistExtension, ResolverFeeExtension {
    using AddressLib for Address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 private constant _SRC_DEPOSIT_OFFSET = 96;
    uint256 private constant _DST_DEPOSIT_OFFSET = 112;
    uint256 private constant _TIMELOCKS_OFFSET = 128;
    uint256 private constant _SRC_IMMUTABLES_LENGTH = 160;

    // Address of the source escrow contract implementation to clone.
    address public immutable IMPL_SRC;
    // Address of the destination escrow contract implementation to clone.
    address public immutable IMPL_DST;

    bytes32 private immutable _PROXY_SRC_BYTECODE_HASH;
    bytes32 private immutable _PROXY_DST_BYTECODE_HASH;


    constructor(
        address limitOrderProtocol,
        IERC20 token,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) {
        IMPL_SRC = address(new EscrowSrc(rescueDelaySrc));
        IMPL_DST = address(new EscrowDst(rescueDelayDst));
        _PROXY_SRC_BYTECODE_HASH = Clones.computeProxyBytecodeHash(IMPL_SRC);
        _PROXY_DST_BYTECODE_HASH = Clones.computeProxyBytecodeHash(IMPL_DST);
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     * `extraData` consists of:
     *   - 5 * 32 bytes for hashlock, dstChainId, dstToken, deposits and timelocks
     *   - whitelist
     *   - 0 / 4 bytes for the fee
     *   - 1 byte for the bitmap
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) internal override(WhitelistExtension, ResolverFeeExtension) {
        super._postInteraction(
            order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData[_SRC_IMMUTABLES_LENGTH:]
        );

        ExtraDataImmutables calldata extraDataImmutables;
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            extraDataImmutables := extraData.offset
        }

        IEscrowSrc.Immutables memory immutables = IEscrowSrc.Immutables({
            orderHash: orderHash,
            srcAmount: makingAmount,
            dstAmount: takingAmount,
            maker: order.receiver.get() == address(0) ? order.maker : order.receiver,
            taker: Address.wrap(uint160(taker)),
            srcToken: order.makerAsset,
            hashlock: extraDataImmutables.hashlock,
            dstChainId: extraDataImmutables.dstChainId,
            dstToken: extraDataImmutables.dstToken,
            deposits: extraDataImmutables.deposits,
            timelocks: extraDataImmutables.timelocks.setDeployedAt(block.timestamp)
        });

        bytes32 salt;
        assembly ("memory-safe") {
            salt := keccak256(immutables, 0x160)
        }

        address escrow = _createEscrow(IMPL_SRC, salt, 0);
        uint256 safetyDeposit = extraDataImmutables.deposits >> 128;
        if (escrow.balance < safetyDeposit || IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount) {
            revert InsufficientEscrowBalance();
        }
    }

    /**
     * @notice See {IEscrowFactory-createDstEscrow}.
     */
    function createDstEscrow(IEscrowDst.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable {
        uint256 nativeAmount = dstImmutables.safetyDeposit;
        address token = dstImmutables.token.get();
        // If the destination token is native, add its amount to the safety deposit.
        if (token == address(0)) {
            nativeAmount += dstImmutables.amount;
        }
        if (msg.value < nativeAmount) revert InsufficientEscrowBalance();

        IEscrowDst.Immutables memory immutables = dstImmutables;
        immutables.timelocks = dstImmutables.timelocks.setDeployedAt(block.timestamp);

        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (immutables.timelocks.dstCancellationStart() > srcCancellationTimestamp) revert InvalidCreationTime();

        bytes32 salt;
        assembly ("memory-safe") {
            salt := keccak256(immutables, 0x100)
        }

        address escrow = _createEscrow(IMPL_DST, salt, msg.value);
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, dstImmutables.amount);
        }
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(IEscrowSrc.Immutables calldata immutables) external view returns (address) {
        return Create2.computeAddress(keccak256(abi.encode(immutables)), _PROXY_SRC_BYTECODE_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IEscrowDst.Immutables calldata immutables) external view returns (address) {
        return Create2.computeAddress(keccak256(abi.encode(immutables)), _PROXY_DST_BYTECODE_HASH);
    }

    /**
     * @notice Creates a new escrow contract with immutable arguments.
     * @dev The escrow contract is a proxy clone created using the create2 pattern.
     * @param implementation The address of the escrow contract implementation.
     * @param salt Hashed immutable args.
     * @return clone The address of the created escrow contract.
     */
    function _createEscrow(
        address implementation,
        bytes32 salt,
        uint256 value
    ) private returns (address clone) {
        clone = Clones.cloneDeterministic(implementation, salt, value);
    }
}
