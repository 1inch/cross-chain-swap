// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";

/**
 * @title Interface for the sample implementation of a Resolver contract for cross-chain swap.
 * @custom:security-contact security@1inch.io
 */
interface IResolverExample {
    error InvalidLength();
    error LengthMismatch();

    /**
     * @notice Deploys a new escrow contract for maker on the source chain.
     * @param immutables The immutables of the escrow contract that are used in deployment.
     * @param order Order quote to fill.
     * @param r R component of signature.
     * @param vs VS component of signature.
     * @param amount Taker amount to fill
     * @param takerTraits Specifies threshold as maximum allowed takingAmount when takingAmount is zero, otherwise specifies
     * minimum allowed makingAmount. The 2nd (0 based index) highest bit specifies whether taker wants to skip maker's permit.
     * @param args Arguments that are used by the taker (target, extension, interaction, permit).
     */
    function deploySrc(
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external;

    /**
     * @notice Deploys a new escrow contract for taker on the destination chain.
     * @param dstImmutables The immutables of the escrow contract that are used in deployment.
     * @param srcCancellationTimestamp The start of the cancellation period for the source chain.
     */
    function deployDst(IBaseEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable;

    /**
     * @notice Allows the owner to make arbitrary calls to other contracts on behalf of this contract.
     * @param targets The addresses of the contracts to call.
     * @param arguments The arguments to pass to the contract calls.
     */
    function arbitraryCalls(address[] calldata targets, bytes[] calldata arguments) external;
}
