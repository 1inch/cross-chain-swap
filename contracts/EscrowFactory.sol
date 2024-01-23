// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SimpleSettlementExtension } from "limit-order-settlement/SimpleSettlementExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, SimpleSettlementExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    // Address of the escrow contract implementation to clone.
    address public immutable IMPLEMENTATION;

    constructor(address implementation, address limitOrderProtocol, IERC20 token)
        SimpleSettlementExtension(limitOrderProtocol, token) {
        IMPLEMENTATION = implementation;
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 /* orderHash */,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) internal override {
        {
            bytes calldata whitelist = extraData[196:];
            if (!_isWhitelisted(whitelist, taker)) revert ResolverIsNotWhitelisted();
        }

        // Prepare immutables for the escrow contract.
        // 32 bytes for block.timestamp + 6 * 32 bytes for InteractionParams + 6 * 32 bytes for ExtraDataParams
        bytes memory data = new bytes(0x1a0);
        // solhint-disable-next-line no-inline-assembly
        assembly("memory-safe") {
            mstore(add(data, 0x20), timestamp())
            // Copy order.maker
            calldatacopy(add(data, 0x40), add(order, 0x20), 0x20)
            mstore(add(data, 0x60), taker)
            mstore(add(data, 0x80), chainid()) // srcChainId
            // Copy order.makerAsset
            calldatacopy(add(data, 0xa0), add(order, 0x60), 0x20) // srcToken
            mstore(add(data, 0xc0), makingAmount) // srcAmount
            mstore(add(data, 0xe0), takingAmount) // dstAmount
            // Copy ExtraDataParams: 6 * 32 bytes excluding first 4 bytes for a fee
            calldatacopy(add(data, 0x100), add(extraData.offset, 0x4), 0xc0)
        }

        address escrow = _createEscrow(data, 0);
        uint256 safetyDeposit;
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            // 4 bytes for a fee +  3 * 32 bytes for hashlock, dstChainId and dstToken
            safetyDeposit := calldataload(add(extraData.offset, 0x64))
        }
        if (
            escrow.balance < safetyDeposit ||
            IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount
        ) revert InsufficientEscrowBalance();

        uint256 resolverFee = _getResolverFee(uint256(uint32(bytes4(extraData[:4]))), order.makingAmount, makingAmount);
        _chargeFee(taker, resolverFee);
    }

    /**
     * @notice See {IEscrowFactory-createEscrow}.
     */
    function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external payable {
        if (msg.value < dstEscrowImmutables.safetyDeposit) revert InsufficientEscrowBalance();
        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (
            dstEscrowImmutables.timelocks.getDstCancellationStart(block.timestamp) >
            dstEscrowImmutables.srcCancellationTimestamp
        ) revert InvalidCreationTime();

        // 32 bytes for block.timestamp + 32 bytes for chaiId + 7 * 32 bytes for DstEscrowImmutablesCreation
        bytes memory data = new bytes(0x140);
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mstore(add(data, 0x20), timestamp())
            mstore(add(data, 0x40), chainid())
            // Copy DstEscrowImmutablesCreation
            calldatacopy(add(data, 0x60), dstEscrowImmutables, 0xe0)
            mstore(add(data, 0x140), caller())
        }

        address escrow = _createEscrow(data, msg.value);
        IERC20(dstEscrowImmutables.token).safeTransferFrom(
            msg.sender, escrow, dstEscrowImmutables.amount
        );
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
