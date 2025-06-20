// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IEscrow } from "./IEscrow.sol";

/**
 * @title Destination Escrow interface for cross-chain atomic swap.
 * @notice Interface implies withdrawing funds initially and then unlocking them with verification of the secret presented.
 * @custom:security-contact security@1inch.io
 */
interface IEscrowDst is IEscrow {
    /**
     * @notice Withdraws funds to a predetermined recipient.
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     * @param immutables The immutables of the escrow contract.
     */
    function withdraw(bytes32 secret, ImmutablesDst calldata immutables) external;

    /**
     * @notice Cancels the escrow and returns tokens to a predetermined recipient.
     * @dev The escrow can only be cancelled during the cancellation period.
     * The safety deposit is sent to the caller.
     * @param immutables The immutables of the escrow contract.
     */
    function cancel(ImmutablesDst calldata immutables) external;

    /**
     * @notice Rescues funds from the escrow.
     * @dev Funds can only be rescued by the taker after the rescue delay.
     * @param token The address of the token to rescue. Zero address for native token.
     * @param amount The amount of tokens to rescue.
     * @param immutables The immutables of the escrow contract.
     */
    function rescueFunds(address token, uint256 amount, ImmutablesDst calldata immutables) external;

    /**
     * @notice Withdraws funds to maker
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * @param secret The secret that unlocks the escrow.
     * @param immutables The immutables of the escrow contract.
     */
    function publicWithdraw(bytes32 secret, IEscrow.ImmutablesDst calldata immutables) external;
}
