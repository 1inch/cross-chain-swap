// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { Timelocks } from "../libraries/TimelocksLib.sol";

/**
 * @title Base Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 * @custom:security-contact security@1inch.io
 */
interface IBaseEscrow {
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

    /**
     * @notice Emitted on escrow cancellation.
     */
    event EscrowCancelled();

    /**
     * @notice Emitted when funds are rescued.
     * @param token The address of the token rescued. Zero address for native token.
     * @param amount The amount of tokens rescued.
     */
    event FundsRescued(address token, uint256 amount);

    /**
     * @notice Emitted on successful withdrawal.
     * @param secret The secret that unlocks the escrow.
     */
    event EscrowWithdrawal(bytes32 secret);

    error InvalidCaller();
    error InvalidImmutables();
    error InvalidSecret();
    error InvalidTime();
    error NativeTokenSendingFailure();

    /* solhint-disable func-name-mixedcase */
    /// @notice Returns the delay for rescuing funds from the escrow.
    function RESCUE_DELAY() external view returns (uint256);
    /// @notice Returns the address of the factory that created the escrow.
    function FACTORY() external view returns (address);
    /* solhint-enable func-name-mixedcase */
}
