// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { AddressLib, Address } from "solidity-utils/libraries/AddressLib.sol";

import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";

import { IEscrowSrc } from "./interfaces/IEscrowSrc.sol";
import { Escrow } from "./Escrow.sol";

/**
 * @title Source Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds and then unlock them with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. For this Limit Order Protocol
 * calls the `EscrowFactory.postInteraction` function.
 * To perform any action, the caller must provide the same Immutables values used to deploy the clone contract.
 */
contract EscrowSrc is Escrow, IEscrowSrc {
    using AddressLib for Address;
    using ImmutablesLib for Immutables;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    constructor(uint32 rescueDelay) Escrow(rescueDelay) {}

    /**
     * @notice See {IEscrow-withdraw}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----
     */
    function withdraw(bytes32 secret, Immutables calldata immutables) external {
        _withdrawTo(secret, msg.sender, immutables);
    }

    /**
     * @notice See {IEscrowSrc-withdrawTo}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----
     */
    function withdrawTo(bytes32 secret, address target, Immutables calldata immutables) external {
        _withdrawTo(secret, target, immutables);
    }

    /**
     * @notice See {IEscrow-cancel}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCELLATION --/-- PUBLIC CANCELLATION ----
     */
    function cancel(Immutables calldata immutables)
        external
        onlyTaker(immutables)
        onlyValidImmutables(immutables)
        onlyAfter(immutables.timelocks.get(TimelocksLib.Stage.SrcCancellation))
    {
        IERC20(immutables.token.get()).safeTransfer(immutables.maker.get(), immutables.amount);
        _ethTransfer(msg.sender, immutables.safetyDeposit);
        emit EscrowCancelled();
    }

    /**
     * @notice See {IEscrow-publicCancel}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- private cancellation --/-- PUBLIC CANCELLATION ----
     */
    function publicCancel(Immutables calldata immutables)
        external
        onlyValidImmutables(immutables)
        onlyAfter(immutables.timelocks.get(TimelocksLib.Stage.SrcPublicCancellation))
    {
        IERC20(immutables.token.get()).safeTransfer(immutables.maker.get(), immutables.amount);
        _ethTransfer(msg.sender, immutables.safetyDeposit);
        emit EscrowCancelled();
    }

    /**
     * @dev Transfers ERC20 tokens to the target and native tokens to the caller.
     * @param secret The secret that unlocks the escrow.
     * @param target The address to transfer ERC20 tokens to.
     * @param immutables The immutable values used to deploy the clone contract.
     */
    function _withdrawTo(bytes32 secret, address target, Immutables calldata immutables)
        internal
        onlyTaker(immutables)
        onlyValidImmutables(immutables)
        onlyValidSecret(secret, immutables)
        onlyAfter(immutables.timelocks.get(TimelocksLib.Stage.SrcWithdrawal))
        onlyBefore(immutables.timelocks.get(TimelocksLib.Stage.SrcCancellation))
    {
        IERC20(immutables.token.get()).safeTransfer(target, immutables.amount);
        _ethTransfer(msg.sender, immutables.safetyDeposit);
        emit Withdrawal(secret);
    }
}
