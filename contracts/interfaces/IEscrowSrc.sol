// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "solidity-utils/libraries/AddressLib.sol";

import { Timelocks } from "../libraries/TimelocksLib.sol";

/**
 * @title Source Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 */
interface IEscrowSrc {
    // Immutables for Escrow on the source chain
    struct Immutables {
        bytes32 orderHash;
        uint256 amount;
        Address maker;
        Address taker;
        Address token;
        bytes32 hashlock;  // Hash of the secret.
        uint256 safetyDeposit;
        Timelocks timelocks;
    }

    /**
     * @notice Withdraws funds to a predetermined recipient.
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     */
    function withdraw(bytes32 secret, Immutables calldata immutables) external;

    /**
     * @notice Withdraws funds to a specified target.
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     */
    function withdrawTo(bytes32 secret, address target, Immutables calldata immutables) external;

    /**
     * @notice Cancels the escrow and returns tokens to a predetermined recipient.
     * @dev The escrow can only be cancelled during the cancellation period.
     * The safety deposit is sent to the caller.
     */
    function cancel(Immutables calldata immutables) external;

    /**
     * @notice Rescues funds from the escrow.
     * @dev Funds can only be rescued by the taker after the rescue delay.
     * @param token The address of the token to rescue. Zero address for native token.
     * @param amount The amount of tokens to rescue.
     */
    function rescueFunds(address token, uint256 amount, Immutables calldata immutables) external;
}
