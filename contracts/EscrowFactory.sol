// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "limit-order-settlement/extensions/ResolverFeeExtension.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";

import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Clones } from "./libraries/Clones.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IEscrowDst, EscrowDst } from "./EscrowDst.sol";
import { IEscrowSrc, EscrowSrc } from "./EscrowSrc.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, WhitelistExtension, ResolverFeeExtension {
    using AddressLib for Address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IEscrowDst.Immutables;
    using ImmutablesLib for IEscrowSrc.Immutables;
    using Clones for address;

    uint256 private constant _SRC_IMMUTABLES_LENGTH = 160;

    address public immutable ESCROW_SRC_IMPLEMENTATION;
    address public immutable ESCROW_DST_IMPLEMENTATION;
    bytes32 private immutable _PROXY_SRC_BYTECODE_HASH;
    bytes32 private immutable _PROXY_DST_BYTECODE_HASH;

    constructor(
        address limitOrderProtocol,
        IERC20 token,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) {
        ESCROW_SRC_IMPLEMENTATION = address(new EscrowSrc(rescueDelaySrc));
        ESCROW_DST_IMPLEMENTATION = address(new EscrowDst(rescueDelayDst));
        _PROXY_SRC_BYTECODE_HASH = Clones.computeProxyBytecodeHash(ESCROW_SRC_IMPLEMENTATION);
        _PROXY_DST_BYTECODE_HASH = Clones.computeProxyBytecodeHash(ESCROW_DST_IMPLEMENTATION);
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     * `extraData` consists of:
     *   - ExtraDataImmutables struct
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
        assembly ("memory-safe") {
            extraDataImmutables := extraData.offset
        }

        IEscrowSrc.Immutables memory immutables = IEscrowSrc.Immutables({
            orderHash: orderHash,
            amount: makingAmount,
            maker: order.receiver.get() == address(0) ? order.maker : order.receiver,
            taker: Address.wrap(uint160(taker)),
            token: order.makerAsset,
            hashlock: extraDataImmutables.hashlock,
            safetyDeposit: extraDataImmutables.deposits >> 128,
            timelocks: extraDataImmutables.timelocks.setDeployedAt(block.timestamp)
        });

        DstImmutablesComplement memory immutablesComplement = DstImmutablesComplement({
            amount: takingAmount,
            token: extraDataImmutables.dstToken,
            safetyDeposit: extraDataImmutables.deposits & type(uint128).max,
            chainId: extraDataImmutables.dstChainId
        });

        emit CrosschainSwap(immutables, immutablesComplement);

        bytes32 salt = immutables.hashMem();
        address escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt, 0);
        if (escrow.balance < immutables.safetyDeposit || IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount) {
            revert InsufficientEscrowBalance();
        }
    }

    /**
     * @notice See {IEscrowFactory-createDstEscrow}.
     */
    function createDstEscrow(IEscrowDst.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable {
        address token = dstImmutables.token.get();
        uint256 nativeAmount = dstImmutables.safetyDeposit;
        if (token == address(0)) {
            nativeAmount += dstImmutables.amount;
        }
        if (msg.value != nativeAmount) revert InsufficientEscrowBalance();

        IEscrowDst.Immutables memory immutables = dstImmutables;
        immutables.timelocks = immutables.timelocks.setDeployedAt(block.timestamp);
        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (immutables.timelocks.dstCancellationStart() > srcCancellationTimestamp) revert InvalidCreationTime();

        bytes32 salt = immutables.hashMem();
        address escrow = ESCROW_DST_IMPLEMENTATION.cloneDeterministic(salt, msg.value);
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.amount);
        }
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(IEscrowSrc.Immutables calldata immutables) external view returns (address) {
        return Create2.computeAddress(immutables.hash(), _PROXY_SRC_BYTECODE_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IEscrowDst.Immutables calldata immutables) external view returns (address) {
        return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);
    }
}
