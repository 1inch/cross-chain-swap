// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IEscrow } from "./IEscrow.sol";

interface IEscrowFactory {
    /**
     * token, amount and safetyDeposit are related to the destination chain.
    */
    struct DstEscrowImmutablesCreation {
        // Hash of the secret.
        bytes32 hashlock;
        address maker;
        address taker;
        address token;
        uint256 amount;
        uint256 safetyDeposit;
        IEscrow.DstTimelocks timelocks;
        // Start of the cancellation period for the source chain.
        uint256 srcCancellationTimestamp;
    }

    error InsufficientEscrowBalance();
    error InvalidCreationTime();

    /**
     * @notice Creates a new escrow contract for taker on the destination chain.
     * @dev The caller must send the safety deposit in the native token along with the function call
     * and approve the destination token to be transferred to the created escrow.
     * @param dstEscrowImmutables The immutables of the escrow contract that are used in deployment.
     */
    function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external payable;

    /**
     * @notice Returns the deterministic address of the escrow based on the salt.
     * @param salt The salt used to deploy escrow.
     * @return The computed address of the escrow.
     */
    function addressOfEscrow(bytes32 salt) external view returns (address);
}
