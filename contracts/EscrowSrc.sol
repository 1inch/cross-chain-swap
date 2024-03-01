// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";
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
 */
contract EscrowSrc is Escrow, IEscrowSrc {
    using AddressLib for Address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for Immutables;

    constructor(uint32 rescueDelay) Escrow(rescueDelay) {}

    modifier onlyValidImmutables(Immutables calldata immutables) {
        _validateImmutables(immutables);
        _;
    }

    /**
     * @notice See {IEscrow-withdraw}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----
     */
    function withdraw(bytes32 secret, Immutables calldata immutables) external onlyValidImmutables(immutables) {
        _withdrawTo(secret, msg.sender, immutables);
    }

    /**
     * @notice See {IEscrowSrc-withdrawTo}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----
     */
    function withdrawTo(bytes32 secret, address target, Immutables calldata immutables) external onlyValidImmutables(immutables) {
        _withdrawTo(secret, target, immutables);
    }

    /**
     * @notice See {IEscrow-cancel}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCELLATION --/-- PUBLIC CANCELLATION ----
     */
    function cancel(Immutables calldata immutables) external {
        // Check that it's a cancellation period.
        if (block.timestamp < immutables.timelocks.srcCancellationStart()) revert InvalidCancellationTime();

        // Check that the caller is a taker if it's the private cancellation period.
        if (block.timestamp < immutables.timelocks.srcPubCancellationStart() && msg.sender != immutables.taker.get()) {
            revert InvalidCaller();
        }

        IERC20(immutables.srcToken.get()).safeTransfer(immutables.maker.get(), immutables.srcAmount);

        // Send the safety deposit to the caller.
        _ethTransfer(msg.sender, immutables.safetyDeposit);
    }

    /**
     * @notice See {IEscrow-rescueFunds}.
     */
    function rescueFunds(address token, uint256 amount, Immutables calldata immutables) external onlyValidImmutables(immutables) {
        if (msg.sender != immutables.taker.get()) revert InvalidCaller();
        _rescueFunds(immutables.timelocks, token, amount);
    }

    function _withdrawTo(bytes32 secret, address target, Immutables calldata immutables) internal {
        if (msg.sender != immutables.taker.get()) revert InvalidCaller();

        Timelocks timelocks = immutables.timelocks;

        // Check that it's a withdrawal period.
        if (block.timestamp < timelocks.srcWithdrawalStart() || block.timestamp >= timelocks.srcCancellationStart()) {
            revert InvalidWithdrawalTime();
        }

        _checkSecretAndTransfer(
            secret,
            immutables.hashlock,
            target,
            immutables.srcToken.get(),
            immutables.srcAmount
        );

        // Send the safety deposit to the caller.
        _ethTransfer(msg.sender, immutables.safetyDeposit);
    }

    function _validateImmutables(Immutables calldata immutables) private view {
        if (Create2.computeAddress(immutables.hash(), PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
            revert InvalidImmutables();
        }
    }
}
