// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { ExtensionBase } from "limit-order-settlement/ExtensionBase.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

contract EscrowFactory is IEscrowFactory, ExtensionBase {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using SafeERC20 for IERC20;

    address public immutable IMPLEMENTATION;

    constructor(address implementation, address limitOrderProtocol) ExtensionBase(limitOrderProtocol) {
        IMPLEMENTATION = implementation;
    }

    /**
     * @dev Creates a new escrow contract for maker.
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) internal override {
        bytes memory interactionParams = abi.encode(
            order.maker,
            taker,
            block.chainid, // srcChainId
            order.makerAsset.get(), // srcToken
            makingAmount, // srcAmount
            takingAmount // dstAmount
        );
        bytes memory data = abi.encodePacked(
            block.timestamp, // deployedAt
            interactionParams,
            extraData
        );
        // Salt is orderHash
        address escrow = ClonesWithImmutableArgs.addressOfClone3(orderHash);
        if (IERC20(order.makerAsset.get()).balanceOf(escrow) < makingAmount) revert InsufficientEscrowBalance();
        _createEscrow(data, orderHash);
    }

    /**
     * @dev Creates a new escrow contract for taker.
     */
    function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external {
        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (
            block.timestamp +
            dstEscrowImmutables.timelocks.finality +
            dstEscrowImmutables.timelocks.unlock +
            dstEscrowImmutables.timelocks.publicUnlock >
            dstEscrowImmutables.srcCancellationTimestamp
        ) revert InvalidCreationTime();
        bytes memory data = abi.encode(
            block.timestamp, // deployedAt
            dstEscrowImmutables.hashlock,
            dstEscrowImmutables.maker,
            dstEscrowImmutables.taker,
            block.chainid,
            dstEscrowImmutables.token,
            dstEscrowImmutables.amount,
            dstEscrowImmutables.safetyDeposit,
            dstEscrowImmutables.timelocks.finality,
            dstEscrowImmutables.timelocks.unlock,
            dstEscrowImmutables.timelocks.publicUnlock
        );
        bytes32 salt = keccak256(abi.encodePacked(data, msg.sender));
        address escrow = _createEscrow(data, salt);
        IERC20(dstEscrowImmutables.token).safeTransferFrom(
            msg.sender, escrow, dstEscrowImmutables.amount + dstEscrowImmutables.safetyDeposit
        );
    }

    function addressOfEscrow(bytes32 salt) external view returns (address) {
        return ClonesWithImmutableArgs.addressOfClone3(salt);
    }

    function _createEscrow(
        bytes memory data,
        bytes32 salt
    ) private returns (address clone) {
        clone = address(uint160(IMPLEMENTATION.clone3(data, salt)));
    }
}
