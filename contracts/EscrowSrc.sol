// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { Escrow } from "./Escrow.sol";
import { PackedAddresses, PackedAddressesLib } from "./libraries/PackedAddressesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrowSrc } from "./interfaces/IEscrowSrc.sol";

/**
 * @title Source Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds and then unlock them with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. For this Limit Order Protocol
 * calls the `EscrowFactory.postInteraction` function.
 */
contract EscrowSrc is Escrow, IEscrowSrc {
    using SafeERC20 for IERC20;
    using PackedAddressesLib for PackedAddresses;
    using TimelocksLib for Timelocks;

    constructor(uint256 rescueDelay) Escrow(rescueDelay) {}

    /**
     * @notice See {IEscrow-withdraw}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----
     */
    function withdraw(bytes32 secret) external {
        _withdrawTo(secret, msg.sender);
    }

    /**
     * @notice See {IEscrowSrc-withdrawTo}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----
     */
    function withdrawTo(bytes32 secret, address target) external {
        _withdrawTo(secret, target);
    }

    /**
     * @notice See {IEscrow-cancel}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCELLATION --/-- PUBLIC CANCELLATION ----
     */
    function cancel() external {
        EscrowImmutables calldata immutables = escrowImmutables();
        Timelocks timelocks = immutables.timelocks;

        // Check that it's a cancellation period.
        if (block.timestamp < timelocks.srcCancellationStart()) revert InvalidCancellationTime();

        // Check that the caller is a taker if it's the private cancellation period.
        if (block.timestamp < timelocks.srcPubCancellationStart() && msg.sender != immutables.packedAddresses.taker()) {
            revert InvalidCaller();
        }

        IERC20(immutables.packedAddresses.token()).safeTransfer(immutables.packedAddresses.maker(), immutables.srcAmount);

        // Send the safety deposit to the caller.
        (bool success,) = msg.sender.call{ value: immutables.deposits >> 128 }("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @notice See {IEscrow-rescueFunds}.
     */
    function rescueFunds(address token, uint256 amount) external {
        EscrowImmutables calldata immutables = escrowImmutables();
        if (msg.sender != immutables.packedAddresses.taker()) revert InvalidCaller();
        _rescueFunds(immutables.timelocks, token, amount);
    }

    /**
     * @notice See {IEscrowSrc-escrowImmutables}.
     */
    function escrowImmutables() public pure returns (EscrowImmutables calldata data) {
        // Get the offset of the immutable args in calldata.
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") { data := offset }
    }

    function _withdrawTo(bytes32 secret, address target) internal {
        EscrowImmutables calldata immutables = escrowImmutables();
        address taker = immutables.packedAddresses.taker();
        if (msg.sender != taker) revert InvalidCaller();

        Timelocks timelocks = immutables.timelocks;

        // Check that it's a withdrawal period.
        if (block.timestamp < timelocks.srcWithdrawalStart() || block.timestamp >= timelocks.srcCancellationStart()) {
            revert InvalidWithdrawalTime();
        }

        _checkSecretAndTransfer(
            secret,
            immutables.hashlock,
            target,
            immutables.packedAddresses.token(),
            immutables.srcAmount
        );

        // Send the safety deposit to the caller.
        (bool success,) = msg.sender.call{ value: immutables.deposits >> 128 }("");
        if (!success) revert NativeTokenSendingFailure();
    }
}
