// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "solidity-utils/libraries/AddressLib.sol";

import { Timelocks } from "../libraries/TimelocksLib.sol";

/**
 * @title Base Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 */
interface IEscrow {
    struct Immutables {
        bytes32 orderHash;
        bytes32 hashlock;  // Hash of the secret.
        Address maker;
        Address taker;
        Address token;
        uint256 amount;
        uint256 safetyDeposit;
        Timelocks timelocks;
    }

    error InvalidCaller();
    error InvalidCancellationTime();
    error InvalidImmutables();
    error InvalidRescueTime();
    error InvalidSecret();
    error InvalidWithdrawalTime();
    error NativeTokenSendingFailure();

    /* solhint-disable func-name-mixedcase */
    function RESCUE_DELAY() external view returns (uint256);
    function FACTORY() external view returns (address);
    function PROXY_BYTECODE_HASH() external view returns (bytes32);
    /* solhint-enable func-name-mixedcase */

    /**
     * @notice Withdraws funds to a predetermined recipient.
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     */
    function withdraw(bytes32 secret, IEscrow.Immutables calldata immutables) external;

    /**
     * @notice Cancels the escrow and returns tokens to a predetermined recipient.
     * @dev The escrow can only be cancelled during the cancellation period.
     * The safety deposit is sent to the caller.
     */
    function cancel(IEscrow.Immutables calldata immutables) external;

    /**
     * @notice Rescues funds from the escrow.
     * @dev Funds can only be rescued by the taker after the rescue delay.
     * @param token The address of the token to rescue. Zero address for native token.
     * @param amount The amount of tokens to rescue.
     */
    function rescueFunds(address token, uint256 amount, IEscrow.Immutables calldata immutables) external;
}
