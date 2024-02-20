// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { Escrow } from "./Escrow.sol";
import { PackedAddresses, PackedAddressesLib } from "./libraries/PackedAddressesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrowDst } from "./interfaces/IEscrowDst.sol";

/**
 * @title Destination Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds and then unlock them with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. For this taker calls the `EscrowFactory.createDstEscrow` function.
 */
contract EscrowDst is Escrow, IEscrowDst {
    using SafeERC20 for IERC20;
    using PackedAddressesLib for PackedAddresses;
    using TimelocksLib for Timelocks;

    constructor(uint256 rescueDelay) Escrow(rescueDelay) {}

    /**
     * @notice See {IEscrow-withdraw}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----
     */
    function withdraw(bytes32 secret) external {
        EscrowImmutables calldata immutables = escrowImmutables();
        Timelocks timelocks = immutables.timelocks;

        // Check that it's a withdrawal period.
        if (
            block.timestamp < timelocks.dstWithdrawalStart() ||
            block.timestamp >= timelocks.dstCancellationStart()
        ) revert InvalidWithdrawalTime();

        // Check that the caller is a taker if it's the private withdrawal period.
        if (
            block.timestamp < timelocks.dstPubWithdrawalStart() &&
            msg.sender != immutables.packedAddresses.taker()
        ) revert InvalidCaller();

        _checkSecretAndTransfer(
            secret,
            immutables.hashlock,
            immutables.packedAddresses.maker(),
            immutables.packedAddresses.token(),
            immutables.amount
        );

        // Send the safety deposit to the caller.
        (bool success, ) = msg.sender.call{value: immutables.safetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @notice See {IEscrow-cancel}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCELLATION ----
     */
    function cancel() external {
        EscrowImmutables calldata immutables = escrowImmutables();
        address taker = immutables.packedAddresses.taker();
        if (msg.sender != taker) revert InvalidCaller();

        // Check that it's a cancellation period.
        if (
            block.timestamp < immutables.timelocks.dstCancellationStart()
        ) {
            revert InvalidCancellationTime();
        }

        IERC20(immutables.packedAddresses.token()).safeTransfer(
            taker,
            immutables.amount
        );

        // Send the safety deposit to the caller.
        (bool success, ) = msg.sender.call{value: immutables.safetyDeposit}("");
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
     * @notice See {IEscrowDst-escrowImmutables}.
     */
    function escrowImmutables() public pure returns (EscrowImmutables calldata data) {
       // Get the offset of the immutable args in calldata.
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") { data := offset }
    }
}