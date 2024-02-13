// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { FeeBankCharger } from "limit-order-settlement/FeeBankCharger.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";
import { FeeResolverExtension } from "limit-order-settlement/extensions/FeeResolverExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { PackedAddresses, PackedAddressesLib } from "./libraries/PackedAddressesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, FeeResolverExtension, WhitelistExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using PackedAddressesLib for PackedAddresses;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 internal constant _SRC_IMMUTABLES_LENGTH = 224;
    // Address of the escrow contract implementation to clone.
    address public immutable IMPLEMENTATION;

    constructor(address implementation, address limitOrderProtocol, IERC20 token)
        BaseExtension(limitOrderProtocol)
        FeeBankCharger(token) {
        IMPLEMENTATION = implementation;
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
     *   - 4 bytes for the fee
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
    ) internal override (FeeResolverExtension, WhitelistExtension) {
        super._postInteraction(order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData[_SRC_IMMUTABLES_LENGTH:]);

        // 192 - timelocks offset in {IEscrow-SrcEscrowImmutables}
        Timelocks timelocks = Timelocks.wrap(
            uint256(bytes32(extraData[192:_SRC_IMMUTABLES_LENGTH]))
        ).setDeployedAt(block.timestamp);

        // Prepare immutables for the escrow contract.
        // 10 * 32 bytes
        bytes memory data = new bytes(0x140);
        // solhint-disable-next-line no-inline-assembly
        assembly("memory-safe") {
            mstore(add(data, 0x20), orderHash)
            mstore(add(data, 0x40), makingAmount) // srcAmount
            mstore(add(data, 0x60), takingAmount) // dstAmount
            // Copy hashlock, packedAddresses, dstChainId, dstToken, deposits: 6 * 32 bytes
            calldatacopy(add(data, 0x80), extraData.offset, 0xc0)
            mstore(add(data, 0x140), timelocks)
        }

        address escrow = _createEscrow(data, 0);
        // [160:176] - srcSafetyDeposit in {IEscrow-SrcEscrowImmutables}
        uint256 safetyDeposit = uint128(bytes16(extraData[160:176]));
        if (
            escrow.balance < safetyDeposit ||
            IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount
        ) revert InsufficientEscrowBalance();
    }

    /**
     * @notice See {IEscrowFactory-createDstEscrow}.
     */
    function createDstEscrow(DstEscrowImmutablesCreation calldata dstImmutables) external payable {
        uint256 nativeAmount = dstImmutables.args.safetyDeposit;
        address token = dstImmutables.args.packedAddresses.token();
        // If the destination token is native, add its amount to the safety deposit.
        if (token == address(0)) {
            nativeAmount += dstImmutables.args.amount;
        }
        if (msg.value < nativeAmount) revert InsufficientEscrowBalance();

        // 7 * 32 bytes for DstEscrowImmutablesCreation
        bytes memory data = new bytes(0xe0);
        Timelocks timelocks = dstImmutables.args.timelocks.setDeployedAt(block.timestamp);

        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (timelocks.dstCancellationStart() > dstImmutables.srcCancellationTimestamp) revert InvalidCreationTime();

        // solhint-disable-next-line no-inline-assembly
        assembly("memory-safe") {
            // Copy DstEscrowImmutablesCreation excluding timelocks
            calldatacopy(add(data, 0x20), dstImmutables, 0xc0)
            mstore(add(data, 0xe0), timelocks)
        }

        address escrow = _createEscrow(data, msg.value);
        if (token != address(0)) {
            IERC20(dstImmutables.args.packedAddresses.token()).safeTransferFrom(
                msg.sender, escrow, dstImmutables.args.amount
            );
        }
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrow}.
     */
    function addressOfEscrow(bytes memory data) public view returns (address) {
        return ClonesWithImmutableArgs.addressOfClone2(IMPLEMENTATION, data);
    }

    /**
     * @notice Creates a new escrow contract with immutable arguments.
     * @dev The escrow contract is a proxy clone created using the create2 pattern.
     * @param data Encoded immutable args.
     * @return clone The address of the created escrow contract.
     */
    function _createEscrow(
        bytes memory data,
        uint256 value
    ) private returns (address clone) {
        clone = IMPLEMENTATION.clone2(data, value);
    }
}
