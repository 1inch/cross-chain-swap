// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @dev Timelocks for the source and the destination chains plus the deployment timestamp.
 * For illustrative purposes, it is possible to describe timelocks by two structures:
 * struct SrcTimelocks {
 *     uint256 finality;
 *     uint256 withdrawal;
 *     uint256 cancellation;
 * }
 *
 * struct DstTimelocks {
 *     uint256 finality;
 *     uint256 withdrawal;
 *     uint256 publicWithdrawal;
 * }
 *
 * finality: The duration of the chain finality period.
 * withdrawal: The duration of the period when only the taker with a secret can withdraw tokens for taker (source chain)
 * or maker (destination chain).
 * publicWithdrawal: The duration of the period when anyone with a secret can withdraw tokens for taker (source chain)
 * or maker (destination chain).
 * cancellation: The duration of the period when escrow can only be cancelled by the taker.
 */
type Timelocks is uint256;

/**
 * @title Timelocks library for compact storage of timelocks in a uint256.
 */
library TimelocksLib {
    error InvalidRescueTime();
    error InvalidWithdrawalTime();
    error InvalidCancellationTime();

    uint256 internal constant _TIMELOCK_MASK = type(uint32).max;
    // 6 variables 32 bits each
    uint256 internal constant _SRC_FINALITY_OFFSET = 224;
    uint256 internal constant _SRC_WITHDRAWAL_OFFSET = 192;
    uint256 internal constant _SRC_CANCELLATION_OFFSET = 160;
    uint256 internal constant _DST_FINALITY_OFFSET = 128;
    uint256 internal constant _DST_WITHDRAWAL_OFFSET = 96;
    uint256 internal constant _DST_PUB_WITHDRAWAL_OFFSET = 64;

    function requireSrcCancellationPeriodStarted(Timelocks timelocks) internal view {
        if (block.timestamp < srcCancellationStart(timelocks)) {
            revert InvalidCancellationTime();
        }
    }

    function requireDstCancellationPeriodStarted(Timelocks timelocks) internal view {
        if (block.timestamp < dstCancellationStart(timelocks)) {
            revert InvalidCancellationTime();
        }
    }

    function requireRescuePeriodStarted(Timelocks timelocks, uint256 rescueDelay) internal view {
        if (block.timestamp < rescueStart(timelocks, rescueDelay)) {
            revert InvalidRescueTime();
        }
    }

    function requireDstWithdrawalPeriodStarted(Timelocks timelocks) internal view {
        if (block.timestamp < dstWithdrawalStart(timelocks) || block.timestamp >= dstCancellationStart(timelocks)) {
            revert InvalidWithdrawalTime();
        }
    }

    function requireSrcWithdrawalPeriodStarted(Timelocks timelocks) internal view {
        if (block.timestamp < srcWithdrawalStart(timelocks) || block.timestamp >= srcCancellationStart(timelocks)) {
            revert InvalidWithdrawalTime();
        }
    }

    function isDstPubWithdrawalPeriodStarted(Timelocks timelocks) internal view returns (bool) {
        return block.timestamp >= dstPubWithdrawalStart(timelocks);
    }

    function isSrcPubCancellationPeriodStarted(Timelocks timelocks) internal view returns (bool) {
        return block.timestamp >= srcPubCancellationStart(timelocks);
    }

    /**
     * @notice Sets the Escrow deployment timestamp.
     * @param timelocks The timelocks to set the deployment timestamp to.
     * @param value The new Escrow deployment timestamp.
     * @return The timelocks with the deployment timestamp set.
     */
    function setDeployedAt(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap((Timelocks.unwrap(timelocks) & ~uint256(type(uint32).max)) | uint32(value));
    }

    /**
     * @notice Returns the start of the rescue period.
     * @param timelocks The timelocks to get the rescue delay from.
     * @return The start of the rescue period.
     */
    function rescueStart(Timelocks timelocks, uint256 rescueDelay) internal pure returns (uint256) {
        unchecked {
            return uint32(Timelocks.unwrap(timelocks)) + rescueDelay;
        }
    }

    // ----- Source chain timelocks ----- //

    /**
     * @notice Returns the start of the private withdrawal period on the source chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @return The start of the private withdrawal period.
     */
    function srcWithdrawalStart(Timelocks timelocks) internal pure returns (uint256) {
        return _get(timelocks, _SRC_FINALITY_OFFSET);
    }

    /**
     * @notice Returns the start of the private cancellation period on the source chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @return The start of the private cancellation period.
     */
    function srcCancellationStart(Timelocks timelocks) internal pure returns (uint256) {
        return _get(timelocks, _SRC_WITHDRAWAL_OFFSET);
    }

    /**
     * @notice Returns the start of the public cancellation period on the source chain.
     * @param timelocks The timelocks to get the private cancellation duration from.
     * @return The start of the public cancellation period.
     */
    function srcPubCancellationStart(Timelocks timelocks) internal pure returns (uint256) {
        return _get(timelocks, _SRC_CANCELLATION_OFFSET);
    }

    // ----- Destination chain timelocks ----- //

    /**
     * @notice Returns the start of the private withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @return The start of the private withdrawal period.
     */
    function dstWithdrawalStart(Timelocks timelocks) internal pure returns (uint256) {
        return _get(timelocks, _DST_FINALITY_OFFSET);
    }

    /**
     * @notice Returns the start of the public withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @return The start of the public withdrawal period.
     */
    function dstPubWithdrawalStart(Timelocks timelocks) internal pure returns (uint256) {
        return _get(timelocks, _DST_WITHDRAWAL_OFFSET);
    }

    /**
     * @notice Returns the start of the private cancellation period on the destination chain.
     * @param timelocks The timelocks to get the public withdrawal duration from.
     * @return The start of the private cancellation period.
     */
    function dstCancellationStart(Timelocks timelocks) internal pure returns (uint256) {
        return _get(timelocks, _DST_PUB_WITHDRAWAL_OFFSET);
    }

    function _get(Timelocks timelocks, uint256 offset) private pure returns (uint256) {
        unchecked {
            uint256 data = Timelocks.unwrap(timelocks);
            return (data + (data >> offset)) & _TIMELOCK_MASK;
        }
    }
}
