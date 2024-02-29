// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "limit-order-settlement/extensions/ResolverFeeExtension.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { EscrowDst } from "./EscrowDst.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
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

    constructor(
        address limitOrderProtocol,
        IERC20 token,
        uint256 rescueDelaySrc,
        uint256 rescueDelayDst
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) {
        IMPL_SRC = address(new EscrowSrc(rescueDelaySrc));
        IMPL_DST = address(new EscrowDst(rescueDelayDst));
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

        Timelocks timelocks = Timelocks.wrap(
            uint256(bytes32(extraData[_TIMELOCKS_OFFSET:_SRC_IMMUTABLES_LENGTH]))
        ).setDeployedAt(block.timestamp);

        // Prepare immutables for the escrow contract.
        // 11 * 32 bytes
        bytes memory data = new bytes(0x160);
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mstore(add(data, 0x20), orderHash)
            mstore(add(data, 0x40), makingAmount) // srcAmount
            mstore(add(data, 0x60), takingAmount) // dstAmount
            // receiver offset in order: 2 * 32 bytes
            let receiver := calldataload(add(order, 0x40))
            switch iszero(receiver)
            case 1 {
                // maker offset in order: 32 bytes for salt
                calldatacopy(add(data, 0x80), add(order, 0x20), 0x20)
            }
            default {
                mstore(add(data, 0x80), receiver)
            }
            mstore(add(data, 0xa0), taker)
            // makerAsset offset in order: 3 * 32 bytes
            calldatacopy(add(data, 0xc0), add(order, 0x60), 0x20)
            // Copy hashlock, dstChainId, dstToken, deposits: 4 * 32 bytes
            calldatacopy(add(data, 0xe0), extraData.offset, 0x80)
            mstore(add(data, 0x160), timelocks)
        }

        address escrow = _createEscrow(IMPL_SRC, data, 0);
        uint256 safetyDeposit = uint128(bytes16(extraData[_SRC_DEPOSIT_OFFSET:_DST_DEPOSIT_OFFSET]));
        if (escrow.balance < safetyDeposit || IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount) {
            revert InsufficientEscrowBalance();
        }
    }

    /**
     * @notice See {IEscrowFactory-createDstEscrow}.
     */
    function createDstEscrow(EscrowImmutablesCreation calldata dstImmutables) external payable {
        uint256 nativeAmount = dstImmutables.args.safetyDeposit;
        address token = dstImmutables.args.dstToken.get();
        // If the destination token is native, add its amount to the safety deposit.
        if (token == address(0)) {
            nativeAmount += dstImmutables.args.amount;
        }
        if (msg.value < nativeAmount) revert InsufficientEscrowBalance();

        // 8 * 32 bytes for EscrowImmutablesCreation
        bytes memory data = new bytes(0x100);
        Timelocks timelocks = dstImmutables.args.timelocks.setDeployedAt(block.timestamp);

        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (timelocks.dstCancellationStart() > dstImmutables.srcCancellationTimestamp) revert InvalidCreationTime();

        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            // Copy EscrowImmutablesCreation excluding timelocks
            calldatacopy(add(data, 0x20), dstImmutables, 0x100)
            mstore(add(data, 0x100), timelocks)
        }

        address escrow = _createEscrow(IMPL_DST, data, msg.value);
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, dstImmutables.args.amount);
        }
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(bytes memory data) external view returns (address) {
        return Clones.predictDeterministicAddress(IMPL_SRC, keccak256(data));
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(bytes memory data) external view returns (address) {
        return Clones.predictDeterministicAddress(IMPL_DST, keccak256(data));
    }

    /**
     * @notice Creates a new escrow contract with immutable arguments.
     * @dev The escrow contract is a proxy clone created using the create2 pattern.
     * @param implementation The address of the escrow contract implementation.
     * @param data Encoded immutable args.
     * @return clone The address of the created escrow contract.
     */
    function _createEscrow(
        address implementation,
        bytes memory data,
        uint256 value
    ) private returns (address clone) {
        clone = Clones.cloneDeterministic(implementation, keccak256(data), value);
    }
}
