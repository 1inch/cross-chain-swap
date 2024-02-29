// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Base Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 */
interface IEscrow {
    error InvalidCaller();
    error InvalidCancellationTime();
    error InvalidImmutables();
    error InvalidRescueTime();
    error InvalidSecret();
    error InvalidWithdrawalTime();
    error NativeTokenSendingFailure();
    error InvalidRescueDelay();

    /* solhint-disable func-name-mixedcase */
    function RESCUE_DELAY() external view returns (uint256);
    function FACTORY() external view returns (address);
    function PROXY_BYTECODE_HASH() external view returns (bytes32);
    /* solhint-enable func-name-mixedcase */
}
