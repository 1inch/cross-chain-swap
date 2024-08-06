// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

import { IBaseEscrow } from "../../../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../../../contracts/interfaces/IEscrowFactory.sol";
import { TimelocksLib } from "../../../contracts/libraries/TimelocksLib.sol";

contract ResolverReentrancy is Ownable {
    uint256 private constant _ARGS_INTERACTION_LENGTH_OFFSET = 200;
    IEscrowFactory private immutable _FACTORY;
    IOrderMixin private immutable _LOP;
    bytes32 private _r;
    bytes32 private _vs;
    TakerTraits private _takerTraits;
    IBaseEscrow.Immutables private _immutables;

    error AccessDenied();

    /// @notice Only limit order protocol can call this contract.
    modifier onlyLOP() {
        if (msg.sender != address(_LOP)) {
            revert AccessDenied();
        }
        _;
    }

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
        _immutables = immutables;
        _r = r;
        _vs = vs;
        _takerTraits = takerTraits;
        _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);
    }

    function takerInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 /* orderHash */,
        address /* taker */,
        uint256 /* makingAmount */,
        uint256 /* takingAmount */,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external onlyLOP {
        _immutables.amount = 1;
        address computed = _FACTORY.addressOfEscrowSrc(_immutables);
        (bool success,) = address(computed).call{ value: _immutables.safetyDeposit }("");
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();

        _takerTraits = TakerTraits.wrap(
            TakerTraits.unwrap(_takerTraits) &
            ~(uint256(type(uint24).max) << _ARGS_INTERACTION_LENGTH_OFFSET) |
            (extraData.length << _ARGS_INTERACTION_LENGTH_OFFSET)
        );
        bytes memory argsMem = abi.encodePacked(computed, extension, extraData);
        _LOP.fillOrderArgs(order, _r, _vs, 1, _takerTraits, argsMem);
    }
}
