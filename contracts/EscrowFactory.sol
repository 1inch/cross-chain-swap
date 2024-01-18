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

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, SimpleSettlementExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using SafeERC20 for IERC20;

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
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) internal override {
        {
            bytes calldata whitelist = extraData[356:];
            if (!_isWhitelisted(whitelist, taker)) revert ResolverIsNotWhitelisted();
        }

        // Prepare immutables for the escrow contract.
        bytes memory interactionParams = abi.encode(
            order.maker,
            taker,
            block.chainid, // srcChainId
            order.makerAsset.get(), // srcToken
            makingAmount, // srcAmount
            takingAmount // dstAmount
        );
        bytes calldata extraDataParams = extraData[4:356];
        bytes memory data = abi.encodePacked(
            block.timestamp, // deployedAt
            interactionParams,
            extraDataParams
        );

        // Salt is orderHash
        address escrow = _createEscrow(data, orderHash, 0);
        uint256 safetyDeposit = abi.decode(extraDataParams, (IEscrow.ExtraDataParams)).srcSafetyDeposit;
        if (
            escrow.balance < safetyDeposit ||
            IERC20(order.makerAsset.get()).balanceOf(escrow) < makingAmount
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
            block.timestamp +
            dstEscrowImmutables.timelocks.finality +
            dstEscrowImmutables.timelocks.withdrawal +
            dstEscrowImmutables.timelocks.publicWithdrawal >
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
            dstEscrowImmutables.timelocks.withdrawal,
            dstEscrowImmutables.timelocks.publicWithdrawal
        );
        bytes32 salt = keccak256(abi.encodePacked(data, msg.sender));

        address escrow = _createEscrow(data, salt, msg.value);
        IERC20(dstEscrowImmutables.token).safeTransferFrom(
            msg.sender, escrow, dstEscrowImmutables.amount
        );
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrow}.
     */
    function addressOfEscrow(bytes32 salt) public view returns (address) {
        return address(uint160(ClonesWithImmutableArgs.addressOfClone3(salt)));
    }

    /**
     * @notice Creates a new escrow contract with immutable arguments.
     * @dev The escrow contract is a proxy clone created using the create3 pattern.
     * @param data Encoded immutable args.
     * @param salt The salt that influences the contract address in deterministic deployment.
     * @return clone The address of the created escrow contract.
     */
    function _createEscrow(
        bytes memory data,
        bytes32 salt,
        uint256 value
    ) private returns (address clone) {
        clone = address(uint160(IMPLEMENTATION.clone3(data, salt, value)));
    }
}
