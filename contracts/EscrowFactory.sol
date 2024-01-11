// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SimpleSettlementExtension } from "limit-order-settlement/SimpleSettlementExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { IEscrow } from "./interfaces/IEscrow.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

contract EscrowFactory is IEscrowFactory, SimpleSettlementExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using SafeERC20 for IERC20;

    uint256 private constant _ORDER_FEE_BASE_POINTS = 1e15;
    address public immutable IMPLEMENTATION;

    constructor(address implementation, address limitOrderProtocol, IERC20 token)
        SimpleSettlementExtension(limitOrderProtocol, token) {
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
        uint256 resolverFee = uint256(uint32(bytes4(extraData[:4]))) * _ORDER_FEE_BASE_POINTS * makingAmount / order.makingAmount;
        extraData = extraData[4:];

        bytes calldata extraDataParams = extraData[:352];
        bytes calldata whitelist = extraData[352:];
        
        if (!_isWhitelisted(whitelist, taker)) revert ResolverIsNotWhitelisted();

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
            extraDataParams
        );
        // Salt is orderHash
        address escrow = ClonesWithImmutableArgs.addressOfClone3(orderHash);
        uint256 safetyDeposit = abi.decode(extraDataParams, (IEscrow.ExtraDataParams)).srcSafetyDeposit;
        if (
            escrow.balance < safetyDeposit ||
            IERC20(order.makerAsset.get()).balanceOf(escrow) < makingAmount
        ) revert InsufficientEscrowBalance();
        _createEscrow(data, orderHash);

        _chargeFee(taker, resolverFee);
    }

    /**
     * @dev Creates a new escrow contract for taker.
     */
    function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external payable {
        if (msg.value < dstEscrowImmutables.safetyDeposit) revert InsufficientEscrowBalance();
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

        address escrow = addressOfEscrow(salt);
        (bool success, ) = escrow.call{value: dstEscrowImmutables.safetyDeposit}("");
        if (!success) revert IEscrow.NativeTokenSendingFailure();

        _createEscrow(data, salt);
        IERC20(dstEscrowImmutables.token).safeTransferFrom(
            msg.sender, escrow, dstEscrowImmutables.amount
        );
    }

    function addressOfEscrow(bytes32 salt) public view returns (address) {
        return address(uint160(ClonesWithImmutableArgs.addressOfClone3(salt)));
    }

    function _createEscrow(
        bytes memory data,
        bytes32 salt
    ) private returns (address clone) {
        clone = address(uint160(IMPLEMENTATION.clone3(data, salt)));
    }
}
