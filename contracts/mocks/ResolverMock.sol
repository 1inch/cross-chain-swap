// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { TakerTraits } from "limit-order-protocol/libraries/TakerTraitsLib.sol";
import { IWETH } from "solidity-utils/interfaces/IWETH.sol";
import { RevertReasonForwarder } from "solidity-utils/libraries/RevertReasonForwarder.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../interfaces/IEscrowFactory.sol";
import { IResolverMock } from "../interfaces/IResolverMock.sol";
import { Timelocks } from "../libraries/TimelocksLib.sol";

/**
 * @title Sample implementation of a Resolver contract for cross-chain swap.
 */
contract ResolverMock is IResolverMock, Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    IEscrowFactory private immutable _FACTORY;
    IOrderMixin private immutable _LOP;

    constructor(IEscrowFactory factory, IOrderMixin lop, address initialOwner) Ownable(initialOwner) {
        _FACTORY = factory;
        _LOP = lop;
    }

    receive() external payable {} // solhint-disable-line no-empty-blocks

    /**
     * @notice See {IResolverMock-deploySrc}.
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
        immutablesMem.timelocks = Timelocks.wrap(Timelocks.unwrap(immutables.timelocks) | block.timestamp);
        address computed = _FACTORY.addressOfEscrowSrc(immutablesMem);
        (bool success,) = address(computed).call{ value: immutablesMem.safetyDeposit }("");
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();

        // _ARGS_HAS_TARGET = 1 << 251
        takerTraits = TakerTraits.wrap(TakerTraits.unwrap(takerTraits) | uint256(1 << 251));
        bytes memory argsMem = abi.encodePacked(computed, args);
        _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);
    }

    /**
     * @notice See {IResolverMock-deployDst}.
     */
    function deployDst(IBaseEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external onlyOwner payable {
        _FACTORY.createDstEscrow{ value: msg.value }(dstImmutables, srcCancellationTimestamp);
    }

    /**
     * @notice See {IResolverMock-arbitraryCalls}.
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
