// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IEscrow } from "./IEscrow.sol";

/**
 * @title Source Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 * @custom:security-contact security@1inch.io
 */
interface IEscrowSrc is IEscrow {
    /**
     * @notice Withdraws funds to a specified target.
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     * @param target The address to withdraw the funds to.
     * @param immutables The immutables of the escrow contract.
     */
    function withdrawTo(bytes32 secret, address target, IEscrow.Immutables calldata immutables) external;

    /**
     * @notice Withdraws funds to the taker.
     * @dev Withdrawal can only be made during the public withdrawal period and with secret with hash matches the hashlock.
     * @param secret The secret that unlocks the escrow.
     * @param immutables The immutables of the escrow contract.
     */
    function publicWithdraw(bytes32 secret, Immutables calldata immutables) external;

    /**
     * @notice Cancels the escrow and returns tokens to the maker.
     * @dev The escrow can only be cancelled during the public cancellation period.
     * The safety deposit is sent to the caller.
     * @param immutables The immutables of the escrow contract.
     */
    function publicCancel(IEscrow.Immutables calldata immutables) external;
}
