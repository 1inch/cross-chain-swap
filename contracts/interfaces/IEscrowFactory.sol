// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "solidity-utils/libraries/AddressLib.sol";

import { Timelocks } from "../libraries/TimelocksLib.sol";

import { IEscrowSrc } from "./IEscrowSrc.sol";
import { IEscrowDst } from "./IEscrowDst.sol";

/**
 * @title Escrow Factory interface contract for cross-chain atomic swap.
 * @notice Interface to deploy escrow contracts for the destination chain and to get the deterministic address of escrow on both chains.
 */
interface IEscrowFactory {
    struct ExtraDataImmutables {
        bytes32 hashlock;
        uint256 dstChainId;
        Address dstToken;
        uint256 deposits;
        Timelocks timelocks;
    }

    struct DstImmutablesComplement {
        uint256 amount;
        Address token;
        uint256 safetyDeposit;
        uint256 chainId;
    }

    error InsufficientEscrowBalance();
    error InvalidCreationTime();

    // Emitted on EscrowSrc deployment to recreate EscrowSrc and EscrowDst immutables off-chain
    event CrosschainSwap(IEscrowSrc.Immutables srcImmutables, DstImmutablesComplement dstImmutablesComplement);

    /**
     * @notice Creates a new escrow contract for taker on the destination chain.
     * @dev The caller must send the safety deposit in the native token along with the function call
     * and approve the destination token to be transferred to the created escrow.
     * @param dstImmutables The immutables of the escrow contract that are used in deployment.
     * @param srcCancellationTimestamp The start of the cancellation period for the source chain.
     */
    function createDstEscrow(IEscrowDst.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable;

    /**
     * @notice Returns the deterministic address of the source escrow based on the salt.
     * @param immutables The immutable arguments used to compute salt for escrow deployment.
     * @return The computed address of the escrow.
     */
    function addressOfEscrowSrc(IEscrowSrc.Immutables calldata immutables) external view returns (address);

    /**
     * @notice Returns the deterministic address of the destination escrow based on the salt.
     * @param immutables The immutable arguments used to compute salt for escrow deployment.
     * @return The computed address of the escrow.
     */
    function addressOfEscrowDst(IEscrowDst.Immutables calldata immutables) external view returns (address);
}
