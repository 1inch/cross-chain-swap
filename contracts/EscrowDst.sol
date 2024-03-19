// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { AddressLib, Address } from "solidity-utils/libraries/AddressLib.sol";

import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IEscrowDst } from "./interfaces/IEscrowDst.sol";
import { Escrow } from "./Escrow.sol";

/**
 * @title Destination Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds and then unlock them with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. For this taker calls the `EscrowFactory.createDstEscrow` function.
 * To perform any action, the caller must provide the same Immutables values used to deploy the clone contract.
 */
contract EscrowDst is Escrow, IEscrowDst {
    using SafeERC20 for IERC20;
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    constructor(uint32 rescueDelay) Escrow(rescueDelay) {}

    /**
     * @notice See {IEscrow-withdraw}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----
     */
    function withdraw(bytes32 secret, Immutables calldata immutables)
        external
        onlyTaker(immutables)
        onlyValidImmutables(immutables)
        onlyValidSecret(secret, immutables)
        onlyAfter(immutables.timelocks.get(TimelocksLib.Stage.DstWithdrawal))
        onlyBefore(immutables.timelocks.get(TimelocksLib.Stage.DstCancellation))
    {
        _uniTransfer(immutables.token.get(), immutables.maker.get(), immutables.amount);
        _ethTransfer(msg.sender, immutables.safetyDeposit);
    }

    /**
     * @notice See {IEscrow-publicWithdraw}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----
     */
    function publicWithdraw(bytes32 secret, Immutables calldata immutables)
        external
        onlyValidImmutables(immutables)
        onlyValidSecret(secret, immutables)
        onlyAfter(immutables.timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal))
    {
        _uniTransfer(immutables.token.get(), immutables.maker.get(), immutables.amount);
        _ethTransfer(msg.sender, immutables.safetyDeposit);
        emit SecretRevealed(secret);
    }

    /**
     * @notice See {IEscrow-cancel}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCELLATION ----
     */
    function cancel(Immutables calldata immutables)
        external
        onlyTaker(immutables)
        onlyValidImmutables(immutables)
        onlyAfter(immutables.timelocks.get(TimelocksLib.Stage.DstCancellation))
    {
        _uniTransfer(immutables.token.get(), immutables.taker.get(), immutables.amount);
        _ethTransfer(msg.sender, immutables.safetyDeposit);
    }
}
