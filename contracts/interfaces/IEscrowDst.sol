// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IEscrow } from "./IEscrow.sol";

/**
 * @title Destination Escrow interface for cross-chain atomic swap.
 * @notice Interface implies withdrawing funds initially and then unlocking them with verification of the secret presented.
 */
interface IEscrowDst is IEscrow {
    /**
     * @notice Emitted on successful public withdrawal.
     * @param secret The secret that unlocks the escrow.
     */
    event SecretRevealed(bytes32 secret);

    /**
     * @notice Withdraws funds to maker
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     */
    function publicWithdraw(bytes32 secret, IEscrow.Immutables calldata immutables) external;
}
