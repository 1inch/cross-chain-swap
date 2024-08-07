// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import { RevertReasonForwarder } from "solidity-utils/contracts/libraries/RevertReasonForwarder.sol";

import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../interfaces/IEscrowFactory.sol";
import { IResolverExample } from "../interfaces/IResolverExample.sol";
import { TimelocksLib } from "../libraries/TimelocksLib.sol";

/**
 * @title Sample implementation of a Resolver contract for cross-chain swap.
 * @dev It is important when deploying an escrow on the source chain to send the safety deposit and deploy the escrow in the same
 * transaction, since the address of the escrow depends on the block.timestamp.
 * You can find sample code for this in the {ResolverExample-deploySrc}.
 *
 * @custom:security-contact security@1inch.io
 */
contract ResolverExample is IResolverExample, Ownable {
    IEscrowFactory private immutable _FACTORY;
    IOrderMixin private immutable _LOP;

    constructor(IEscrowFactory factory, IOrderMixin lop, address initialOwner) Ownable(initialOwner) {
        _FACTORY = factory;
        _LOP = lop;
    }

    receive() external payable {} // solhint-disable-line no-empty-blocks

    /**
     * @notice See {IResolverExample-deploySrc}.
     */
    function deploySrc(
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external onlyOwner {
        IBaseEscrow.Immutables memory immutablesMem = immutables;
        immutablesMem.timelocks = TimelocksLib.setDeployedAt(immutables.timelocks, block.timestamp);
        address computed = _FACTORY.addressOfEscrowSrc(immutablesMem);
        (bool success,) = address(computed).call{ value: immutablesMem.safetyDeposit }("");
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();

        // _ARGS_HAS_TARGET = 1 << 251
        takerTraits = TakerTraits.wrap(TakerTraits.unwrap(takerTraits) | uint256(1 << 251));
        bytes memory argsMem = abi.encodePacked(computed, args);
        _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);
    }

    /**
     * @notice See {IResolverExample-deployDst}.
     */
    function deployDst(IBaseEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external onlyOwner payable {
        _FACTORY.createDstEscrow{ value: msg.value }(dstImmutables, srcCancellationTimestamp);
    }

    /**
     * @notice See {IResolverExample-arbitraryCalls}.
     */
    function arbitraryCalls(address[] calldata targets, bytes[] calldata arguments) external onlyOwner {
        uint256 length = targets.length;
        if (targets.length != arguments.length) revert LengthMismatch();
        for (uint256 i = 0; i < length; ++i) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = targets[i].call(arguments[i]);
            if (!success) RevertReasonForwarder.reRevert();
        }
    }
}
