// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

import { Timelocks } from "../libraries/TimelocksLib.sol";

import { IEscrow } from "./IEscrow.sol";

/**
 * @title Escrow Factory interface for cross-chain atomic swap.
 * @notice Interface to deploy escrow contracts for the destination chain and to get the deterministic address of escrow on both chains.
 */
interface IEscrowFactory {
    struct ExtraDataArgs {
        bytes32 hashlock; // Hash of the secret or the Merkle tree root if multiple fills are allowed
        uint256 dstChainId;
        Address dstToken;
        uint256 deposits;
        Timelocks timelocks;
    }

    struct DstImmutablesComplement {
        Address maker;
        uint256 amount;
        Address token;
        uint256 safetyDeposit;
        uint256 chainId;
    }

    error InsufficientEscrowBalance();
    error InvalidCreationTime();
    error InvalidSecretIndex();
    error InvalidSecretsAmount();

    /**
     * @notice Emitted on EscrowSrc deployment to recreate EscrowSrc and EscrowDst immutables off-chain.
     * @param srcImmutables The immutables of the escrow contract that are used in deployment on the source chain.
     * @param dstImmutablesComplement Additional immutables related to the escrow contract on the destination chain.
     */
    event SrcEscrowCreated(IEscrow.Immutables srcImmutables, DstImmutablesComplement dstImmutablesComplement);
    /**
     * @notice Emitted on EscrowDst deployment.
     * @param escrow The address of the created escrow.
     */
    event DstEscrowCreated(address escrow, Address taker);

    /* solhint-disable func-name-mixedcase */
    /// @notice Returns the address of implementation on the source chain.
    function ESCROW_SRC_IMPLEMENTATION() external view returns (address);
    /// @notice Returns the address of implementation on the destination chain.
    function ESCROW_DST_IMPLEMENTATION() external view returns (address);
    /* solhint-enable func-name-mixedcase */

    /**
     * @notice Creates a new escrow contract for taker on the destination chain.
     * @dev The caller must send the safety deposit in the native token along with the function call
     * and approve the destination token to be transferred to the created escrow.
     * @param dstImmutables The immutables of the escrow contract that are used in deployment.
     * @param srcCancellationTimestamp The start of the cancellation period for the source chain.
     */
    function createDstEscrow(IEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable;

    /**
     * @notice Returns the deterministic address of the source escrow based on the salt.
     * @param immutables The immutable arguments used to compute salt for escrow deployment.
     * @return The computed address of the escrow.
     */
    function addressOfEscrowSrc(IEscrow.Immutables calldata immutables) external view returns (address);

    /**
     * @notice Returns the deterministic address of the destination escrow based on the salt.
     * @param immutables The immutable arguments used to compute salt for escrow deployment.
     * @return The computed address of the escrow.
     */
    function addressOfEscrowDst(IEscrow.Immutables calldata immutables) external view returns (address);
}
