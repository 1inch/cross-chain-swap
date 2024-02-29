// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IEscrowDst } from "./IEscrowDst.sol";

interface IEscrowFactory {
    /**
     * token, amount and safetyDeposit are related to the destination chain.
     */
    struct EscrowImmutablesCreation {
        IEscrowDst.Immutables args;
        // Start of the cancellation period for the source chain.
        uint256 srcCancellationTimestamp;
    }

    error InsufficientEscrowBalance();
    error InvalidCreationTime();

    /**
     * @notice Creates a new escrow contract for taker on the destination chain.
     * @dev The caller must send the safety deposit in the native token along with the function call
     * and approve the destination token to be transferred to the created escrow.
     * @param dstImmutables The immutables of the escrow contract that are used in deployment.
     */
    function createDstEscrow(EscrowImmutablesCreation calldata dstImmutables) external payable;

    /**
     * @notice Returns the deterministic address of the source escrow based on the salt.
     * @param data The immutable arguments used to deploy escrow.
     * @return The computed address of the escrow.
     */
    function addressOfEscrowSrc(bytes memory data) external view returns (address);

    /**
     * @notice Returns the deterministic address of the destination escrow based on the salt.
     * @param data The immutable arguments used to deploy escrow.
     * @return The computed address of the escrow.
     */
    function addressOfEscrowDst(bytes memory data) external view returns (address);
}
