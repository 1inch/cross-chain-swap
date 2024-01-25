// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @dev Timelocks for the source and the destination chains.
 * For illustrative purposes, it is possible to describe timelocks by two structures:
 * struct SrcTimelocks {
 *     uint256 finality;
 *     uint256 withdrawal;
 *     uint256 cancel;
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
 * cancel: The duration of the period when escrow can only be cancelled by the taker.
 */
type Timelocks is uint256;

/**
 * @title Timelocks library for compact storage of timelocks in a uint256.
 */
library TimelocksLib {
    uint256 private constant _TIMESTAMP_MASK = type(uint40).max;
    // 6 variables 40 bits each
    uint256 private constant _SRC_FINALITY_OFFSET = 216;
    uint256 private constant _SRC_WITHDRAWAL_OFFSET = 176;
    uint256 private constant _SRC_CANCEL_OFFSET = 136;
    uint256 private constant _DST_FINALITY_OFFSET = 96;
    uint256 private constant _DST_WITHDRAWAL_OFFSET = 56;
    uint256 private constant _DST_PUB_WITHDRAWAL_OFFSET = 16;

    // ----- Source chain timelocks ----- //
    // ---------- Src Finality ----------- //
    /**
     * @notice Gets the duration of the finality period on the source chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @return The duration of the finality period.
     */
    function getSrcFinalityDuration(Timelocks timelocks) internal pure returns (uint256) {
        return (Timelocks.unwrap(timelocks) & (_TIMESTAMP_MASK << _SRC_FINALITY_OFFSET)) >> _SRC_FINALITY_OFFSET;
    }

    /**
     * @notice Sets the duration of the finality period on the source chain.
     * @param timelocks The timelocks to set the finality duration to.
     * @param value The new duration of the finality period.
     * @return The timelocks with the finality duration set.
     */
    function setSrcFinalityDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            // Clear the finality duration bits and set the new value.
            (Timelocks.unwrap(timelocks) & ~(_TIMESTAMP_MASK << _SRC_FINALITY_OFFSET)) |
            ((value & _TIMESTAMP_MASK) << _SRC_FINALITY_OFFSET)
        );
    }

    // ---------- Src Withdrawal ----------- //
    /**
     * @notice Gets the start of the private withdrawal period on the source chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private withdrawal period.
     */
    function getSrcWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return startTimestamp + getSrcFinalityDuration(timelocks);
        }
    }

    /**
     * @notice Gets the duration of the private withdrawal period on the source chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @return The duration of the private withdrawal period.
     */
    function getSrcWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256) {
        return (Timelocks.unwrap(timelocks) & (_TIMESTAMP_MASK << _SRC_WITHDRAWAL_OFFSET)) >> _SRC_WITHDRAWAL_OFFSET;
    }

    /**
     * @notice Sets the duration of the private withdrawal period on the source chain.
     * @param timelocks The timelocks to set the private withdrawal duration to.
     * @param value The new duration of the private withdrawal period.
     * @return The timelocks with the private withdrawal duration set.
     */
    function setSrcWithdrawalDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            // Clear the private withdrawal duration bits and set the new value.
            (Timelocks.unwrap(timelocks) & ~(_TIMESTAMP_MASK << _SRC_WITHDRAWAL_OFFSET)) |
            ((value & _TIMESTAMP_MASK) << _SRC_WITHDRAWAL_OFFSET)
        );
    }

    // ---------- Src Cancellation ----------- //
    /**
     * @notice Gets the start of the private cancellation period on the source chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private cancellation period.
     */
    function getSrcCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return getSrcWithdrawalStart(timelocks, startTimestamp) + getSrcWithdrawalDuration(timelocks);
        }
    }

    /**
     * @notice Gets the duration of the private cancellation period on the source chain.
     * @param timelocks The timelocks to get the private cancellation duration from.
     * @return The duration of the private cancellation period.
     */
    function getSrcCancellationDuration(Timelocks timelocks) internal pure returns (uint256) {
        return (Timelocks.unwrap(timelocks) & (_TIMESTAMP_MASK << _SRC_CANCEL_OFFSET)) >> _SRC_CANCEL_OFFSET;
    }

    /**
     * @notice Sets the duration of the private cancellation period on the source chain.
     * @param timelocks The timelocks to set the private cancellation duration to.
     * @param value The duration of the private cancellation period.
     * @return The timelocks with the private cancellation duration set.
     */
    function setSrcCancellationDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            // Clear the private cancellation duration bits and set the new value.
            (Timelocks.unwrap(timelocks) & ~(_TIMESTAMP_MASK << _SRC_CANCEL_OFFSET)) |
            ((value & _TIMESTAMP_MASK) << _SRC_CANCEL_OFFSET)
        );
    }

    // ---------- Src Public Cancellation ----------- //
    /**
     * @notice Gets the start of the public cancellation period on the source chain.
     * @param timelocks The timelocks to get the private cancellation duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the public cancellation period.
     */
    function getSrcPubCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return getSrcCancellationStart(timelocks, startTimestamp) + getSrcCancellationDuration(timelocks);
        }
    }

    // ----- Destination chain timelocks ----- //
    // ---------- Dst Finality ----------- //
    /**
     * @notice Gets the duration of the finality period on the destination chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @return The duration of the finality period.
     */
    function getDstFinalityDuration(Timelocks timelocks) internal pure returns (uint256) {
        return (Timelocks.unwrap(timelocks) & (_TIMESTAMP_MASK << _DST_FINALITY_OFFSET)) >> _DST_FINALITY_OFFSET;
    }

    /**
     * @notice Sets the duration of the finality period on the destination chain.
     * @param timelocks The timelocks to set the finality duration to.
     * @param value The duration of the finality period.
     * @return The timelocks with the finality duration set.
     */
    function setDstFinalityDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            // Clear the finality duration bits and set the new value.
            (Timelocks.unwrap(timelocks) & ~(_TIMESTAMP_MASK << _DST_FINALITY_OFFSET)) |
            ((value & _TIMESTAMP_MASK) << _DST_FINALITY_OFFSET)
        );
    }

    // ---------- Dst Withdrawal ----------- //
    /**
     * @notice Gets the start of the private withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private withdrawal period.
     */
    function getDstWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return startTimestamp + getDstFinalityDuration(timelocks);
        }
    }

    /**
     * @notice Gets the duration of the private withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @return The duration of the private withdrawal period.
     */
    function getDstWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256) {
        return (Timelocks.unwrap(timelocks) & (_TIMESTAMP_MASK << _DST_WITHDRAWAL_OFFSET)) >> _DST_WITHDRAWAL_OFFSET;
    }

    /**
     * @notice Sets the duration of the private withdrawal period on the destination chain.
     * @param timelocks The timelocks to set the private withdrawal duration to.
     * @param value The new duration of the private withdrawal period.
     * @return The timelocks with the private withdrawal duration set.
     */
    function setDstWithdrawalDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            // Clear the private withdrawal duration bits and set the new value.
            (Timelocks.unwrap(timelocks) & ~(_TIMESTAMP_MASK << _DST_WITHDRAWAL_OFFSET)) |
            ((value & _TIMESTAMP_MASK) << _DST_WITHDRAWAL_OFFSET)
        );
    }

    // ---------- Dst Public Withdrawal ----------- //
    /**
     * @notice Gets the start of the public withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the public withdrawal period.
     */
    function getDstPubWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return getDstWithdrawalStart(timelocks, startTimestamp) + getDstWithdrawalDuration(timelocks);
        }
    }

    /**
     * @notice Gets the duration of the public withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the public withdrawal duration from.
     * @return The duration of the public withdrawal period.
     */
    function getDstPubWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256) {
        return (Timelocks.unwrap(timelocks) & (_TIMESTAMP_MASK << _DST_PUB_WITHDRAWAL_OFFSET)) >> _DST_PUB_WITHDRAWAL_OFFSET;
    }

    /**
     * @notice Sets the duration of the public withdrawal period on the destination chain.
     * @param timelocks The timelocks to set the public withdrawal duration to.
     * @param value The new duration of the public withdrawal period.
     * @return The timelocks with the public withdrawal duration set.
     */
    function setDstPubWithdrawalDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            // Clear the public withdrawal duration bits and set the new value.
            (Timelocks.unwrap(timelocks) & ~(_TIMESTAMP_MASK << _DST_PUB_WITHDRAWAL_OFFSET)) |
            ((value & _TIMESTAMP_MASK) << _DST_PUB_WITHDRAWAL_OFFSET)
        );
    }

    // ---------- Dst Cancellation ----------- //
    /**
     * @notice Gets the start of the private cancellation period on the destination chain.
     * @param timelocks The timelocks to get the public withdrawal duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private cancellation period.
     */
    function getDstCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return getDstPubWithdrawalStart(timelocks, startTimestamp) + getDstPubWithdrawalDuration(timelocks);
        }
    }
}
