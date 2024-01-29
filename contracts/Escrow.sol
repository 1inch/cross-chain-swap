// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Clone } from "clones-with-immutable-args/Clone.sol";

import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { PackedAddresses, PackedAddressesLib } from "./libraries/PackedAddressesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";

/**
 * @title Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds on both chains and then unlock with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. On both chains this is done by calling `EscrowFactory`
 * functions. On the source chain Limit Order Protocol calls the `postInteraction` function and on the destination
 * chain taker calls the `createEscrowDst` function.
 * Withdrawal and cancellation functions for the source and destination chains are implemented separately.
 */
contract Escrow is Clone, IEscrow {
    using SafeERC20 for IERC20;
    using PackedAddressesLib for PackedAddresses;
    using TimelocksLib for Timelocks;

    /**
     * @notice See {IEscrow-withdrawSrc}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancel --/-- public cancel ----
     */
    function withdrawSrc(bytes32 secret) external {
        SrcEscrowImmutables calldata escrowImmutables = srcEscrowImmutables();
        address taker = escrowImmutables.packedAddresses.taker();
        if (msg.sender != taker) revert InvalidCaller();

        Timelocks timelocks = escrowImmutables.timelocks;
        uint256 deployedAt = escrowImmutables.timelocks.deployedAt();

        // Check that it's a withdrawal period.
        if (
            block.timestamp < timelocks.srcWithdrawalStart(deployedAt) ||
            block.timestamp >= timelocks.srcCancellationStart(deployedAt)
        ) revert InvalidWithdrawalTime();

        _checkSecretAndTransfer(
            secret,
            escrowImmutables.hashlock,
            taker,
            escrowImmutables.packedAddresses.token(),
            escrowImmutables.srcAmount
        );

        // Send the safety deposit to the caller.
        (bool success, ) = msg.sender.call{value: escrowImmutables.deposits >> 128}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @notice See {IEscrow-cancelSrc}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCEL --/-- PUBLIC CANCEL ----
     */
    function cancelSrc() external {
        SrcEscrowImmutables calldata escrowImmutables = srcEscrowImmutables();
        Timelocks timelocks = escrowImmutables.timelocks;
        uint256 deployedAt = escrowImmutables.timelocks.deployedAt();

        // Check that it's a cancellation period.
        if (block.timestamp < timelocks.srcCancellationStart(deployedAt)) {
            revert InvalidCancellationTime();
        }

        // Check that the caller is a taker if it's the private cancellation period.
        if (
            block.timestamp < timelocks.srcPubCancellationStart(deployedAt) &&
            msg.sender != escrowImmutables.packedAddresses.taker()
        ) {
            revert InvalidCaller();
        }

        IERC20(escrowImmutables.packedAddresses.token()).safeTransfer(
            escrowImmutables.packedAddresses.maker(),
            escrowImmutables.srcAmount
        );

        // Send the safety deposit to the caller.
        (bool success, ) = msg.sender.call{value: escrowImmutables.deposits >> 128}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @notice See {IEscrow-withdrawDst}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancel ----
     */
    function withdrawDst(bytes32 secret) external {
        IEscrow.DstEscrowArgs calldata args = dstEscrowImmutables().args;

        uint256 deployedAt = args.timelocks.deployedAt();
        // Check that it's a withdrawal period.
        if (
            block.timestamp < args.timelocks.dstWithdrawalStart(deployedAt) ||
            block.timestamp >= args.timelocks.dstCancellationStart(deployedAt)
        ) revert InvalidWithdrawalTime();

        // Check that the caller is a taker if it's the private withdrawal period.
        if (
            block.timestamp < args.timelocks.dstPubWithdrawalStart(deployedAt) &&
            msg.sender != args.packedAddresses.taker()
        ) revert InvalidCaller();

        _checkSecretAndTransfer(
            secret,
            args.hashlock,
            args.packedAddresses.maker(),
            args.packedAddresses.token(),
            args.amount
        );

        // Send the safety deposit to the caller.
        (bool success, ) = msg.sender.call{value: args.safetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @notice See {IEscrow-cancelDst}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCEL ----
     */
    function cancelDst() external {
        IEscrow.DstEscrowArgs calldata args = dstEscrowImmutables().args;
        address taker = args.packedAddresses.taker();
        if (msg.sender != taker) revert InvalidCaller();

        // Check that it's a cancellation period.
        if (
            block.timestamp < args.timelocks.dstCancellationStart(args.timelocks.deployedAt())
        ) {
            revert InvalidCancellationTime();
        }

        IERC20(args.packedAddresses.token()).safeTransfer(
            taker,
            args.amount
        );

        // Send the safety deposit to the caller.
        (bool success, ) = msg.sender.call{value: args.safetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @notice See {IEscrow-srcEscrowImmutables}.
     */
    function srcEscrowImmutables() public pure returns (SrcEscrowImmutables calldata data) {
         // Get the offset of the immutable args in calldata.
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") { data := offset }
    }

    /**
     * @notice See {IEscrow-dstEscrowImmutables}.
     */
    function dstEscrowImmutables() public pure returns (DstEscrowImmutables calldata data) {
       // Get the offset of the immutable args in calldata.
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") { data := offset }
    }

    /**
     * @notice Verifies the provided secret.
     * @dev The secret is valid if its hash matches the hashlock.
     * @param secret Provided secret to verify.
     * @param hashlock Hashlock to compare with.
     * @return True if the secret is valid, false otherwise.
     */
    function _isValidSecret(bytes32 secret, bytes32 hashlock) internal pure returns (bool) {
        return keccak256(abi.encode(secret)) == hashlock;
    }

    /**
     * @notice Checks the secret and transfers tokens to the recipient.
     * @dev The secret is valid if its hash matches the hashlock.
     * @param secret Provided secret to verify.
     * @param hashlock Hashlock to compare with.
     * @param recipient Address to transfer tokens to.
     * @param token Address of the token to transfer.
     * @param amount Amount of tokens to transfer.
     */
    function _checkSecretAndTransfer(
        bytes32 secret,
        bytes32 hashlock,
        address recipient,
        address token,
        uint256 amount
    ) internal {
        if (!_isValidSecret(secret, hashlock)) revert InvalidSecret();
        IERC20(token).safeTransfer(recipient, amount);
    }
}
