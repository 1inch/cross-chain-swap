// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { AddressLib, Address } from "solidity-utils/libraries/AddressLib.sol";

import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";

import { IEscrowDst } from "./interfaces/IEscrowDst.sol";
import { Escrow } from "./Escrow.sol";

/**
 * @title Destination Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds and then unlock them with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. For this taker calls the `EscrowFactory.createDstEscrow` function.
 */
contract EscrowDst is Escrow, IEscrowDst {
    using SafeERC20 for IERC20;
    using AddressLib for Address;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for Immutables;

    constructor(uint32 rescueDelay) Escrow(rescueDelay) {}

    modifier onlyValidImmutables(Immutables calldata immutables) {
        _validateImmutables(immutables);
        _;
    }

    /**
     * @notice See {IEscrow-withdraw}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----
     */
    function withdraw(bytes32 secret, Immutables calldata immutables) external onlyValidImmutables(immutables) {
        Timelocks timelocks = immutables.timelocks;

        // Check that it's a withdrawal period.
        if (block.timestamp < timelocks.dstWithdrawalStart() || block.timestamp >= timelocks.dstCancellationStart()) {
            revert InvalidWithdrawalTime();
        }

        // Check that the caller is a taker if it's the private withdrawal period.
        if (block.timestamp < timelocks.dstPubWithdrawalStart() && msg.sender != immutables.taker.get()) {
            revert InvalidCaller();
        }

        _checkSecretAndTransfer(
            secret,
            immutables.hashlock,
            immutables.maker.get(),
            immutables.token.get(),
            immutables.amount
        );

        // Send the safety deposit to the caller.
        _ethTransfer(msg.sender, immutables.safetyDeposit);
    }

    /**
     * @notice See {IEscrow-cancel}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCELLATION ----
     */
    function cancel(Immutables calldata immutables) external onlyValidImmutables(immutables) {
        address taker = immutables.taker.get();
        if (msg.sender != taker) revert InvalidCaller();

        // Check that it's a cancellation period.
        if (block.timestamp < immutables.timelocks.dstCancellationStart()) revert InvalidCancellationTime();

        IERC20(immutables.token.get()).safeTransfer(taker, immutables.amount);

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

    function _validateImmutables(Immutables calldata immutables) private view {
        bytes32 salt = immutables.hash();
        if (Create2.computeAddress(salt, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
            revert InvalidImmutables();
        }
    }
}
