// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "limit-order-settlement/extensions/ResolverFeeExtension.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { PackedAddresses, PackedAddressesLib } from "./libraries/PackedAddressesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, WhitelistExtension, ResolverFeeExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using PackedAddressesLib for PackedAddresses;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 private constant _SRC_DEPOSIT_OFFSET = 100;
    uint256 private constant _DST_DEPOSIT_OFFSET = 116;
    uint256 private constant _TIMELOCKS_OFFSET = 192;
    uint256 private constant _SRC_IMMUTABLES_LENGTH = 224;

    // Address of the source escrow contract implementation to clone.
    address public immutable IMPL_SRC;
    // Address of the destination escrow contract implementation to clone.
    address public immutable IMPL_DST;

    constructor(
        address implSrc,
        address implDst,
        address limitOrderProtocol,
        IERC20 token
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) {
        IMPL_SRC = implSrc;
        IMPL_DST = implDst;
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     * `extraData` consists of:
     *   - 7 * 32 bytes for hashlock, packedAddresses (2 * 32), dstChainId, dstToken, deposits and timelocks
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
        // 10 * 32 bytes
        bytes memory data = new bytes(0x140);
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mstore(add(data, 0x20), orderHash)
            mstore(add(data, 0x40), makingAmount) // srcAmount
            mstore(add(data, 0x60), takingAmount) // dstAmount
            // Copy hashlock, packedAddresses, dstChainId, dstToken, deposits: 6 * 32 bytes
            calldatacopy(add(data, 0x80), extraData.offset, 0xc0)
            mstore(add(data, 0x140), timelocks)
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
        address token = dstImmutables.args.packedAddresses.token();
        // If the destination token is native, add its amount to the safety deposit.
        if (token == address(0)) {
            nativeAmount += dstImmutables.args.amount;
        }
        if (msg.value < nativeAmount) revert InsufficientEscrowBalance();

        // 7 * 32 bytes for EscrowImmutablesCreation
        bytes memory data = new bytes(0xe0);
        Timelocks timelocks = dstImmutables.args.timelocks.setDeployedAt(block.timestamp);

        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (timelocks.dstCancellationStart() > dstImmutables.srcCancellationTimestamp) revert InvalidCreationTime();

        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            // Copy EscrowImmutablesCreation excluding timelocks
            calldatacopy(add(data, 0x20), dstImmutables, 0xc0)
            mstore(add(data, 0xe0), timelocks)
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
        return ClonesWithImmutableArgs.addressOfClone2(IMPL_SRC, data);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(bytes memory data) external view returns (address) {
        return ClonesWithImmutableArgs.addressOfClone2(IMPL_DST, data);
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
        clone = implementation.clone2(data, value);
    }
}
