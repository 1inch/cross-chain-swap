// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @dev Timelocks for the source and the destination chains.
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
    uint256 internal constant _TIMELOCK_MASK = type(uint32).max;
    // 6 variables 32 bits each
    uint256 internal constant _SRC_FINALITY_OFFSET = 224;
    uint256 internal constant _SRC_WITHDRAWAL_OFFSET = 192;
    uint256 internal constant _SRC_CANCELLATION_OFFSET = 160;
    uint256 internal constant _DST_FINALITY_OFFSET = 128;
    uint256 internal constant _DST_WITHDRAWAL_OFFSET = 96;
    uint256 internal constant _DST_PUB_WITHDRAWAL_OFFSET = 64;

    /**
     * @notice Returns the Escrow deployment timestamp.
     * @param timelocks The timelocks to get the deployment timestamp from.
     * @return The Escrow deployment timestamp.
     */
    function deployedAt(Timelocks timelocks) internal pure returns (uint256) {
        return uint40(Timelocks.unwrap(timelocks));
    }

    /**
     * @notice Sets the Escrow deployment timestamp.
     * @param timelocks The timelocks to set the deployment timestamp to.
     * @param value The new Escrow deployment timestamp.
     * @return The timelocks with the deployment timestamp set.
     */
    function setDeployedAt(Timelocks timelocks, uint256 value) internal pure returns (Timelocks) {
        return Timelocks.wrap((Timelocks.unwrap(timelocks) & ~uint256(type(uint40).max)) | uint40(value));
    }

    // ----- Source chain timelocks ----- //
    /**
     * @notice Returns the duration of the finality period on the source chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @return The duration of the finality period.
     */
    function srcFinalityDuration(Timelocks timelocks) internal pure returns (uint256) {
        return Timelocks.unwrap(timelocks) >> _SRC_FINALITY_OFFSET & _TIMELOCK_MASK ;
    }

    /**
     * @notice Returns the start of the private withdrawal period on the source chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private withdrawal period.
     */
    function srcWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return startTimestamp + srcFinalityDuration(timelocks);
        }
    }

    /**
     * @notice Returns the duration of the private withdrawal period on the source chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @return The duration of the private withdrawal period.
     */
    function srcWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256) {
        return Timelocks.unwrap(timelocks) >> _SRC_WITHDRAWAL_OFFSET & _TIMELOCK_MASK;
    }

    /**
     * @notice Returns the start of the private cancellation period on the source chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private cancellation period.
     */
    function srcCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return srcWithdrawalStart(timelocks, startTimestamp) + srcWithdrawalDuration(timelocks);
        }
    }

    /**
     * @notice Returns the duration of the private cancellation period on the source chain.
     * @param timelocks The timelocks to get the private cancellation duration from.
     * @return The duration of the private cancellation period.
     */
    function srcCancellationDuration(Timelocks timelocks) internal pure returns (uint256) {
        return Timelocks.unwrap(timelocks) >> _SRC_CANCELLATION_OFFSET & _TIMELOCK_MASK;
    }

    /**
     * @notice Returns the start of the public cancellation period on the source chain.
     * @param timelocks The timelocks to get the private cancellation duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the public cancellation period.
     */
    function srcPubCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return srcCancellationStart(timelocks, startTimestamp) + srcCancellationDuration(timelocks);
        }
    }

    // ----- Destination chain timelocks ----- //
    /**
     * @notice Returns the duration of the finality period on the destination chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @return The duration of the finality period.
     */
    function dstFinalityDuration(Timelocks timelocks) internal pure returns (uint256) {
        return Timelocks.unwrap(timelocks) >> _DST_FINALITY_OFFSET & _TIMELOCK_MASK;
    }

    /**
     * @notice Returns the start of the private withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the finality duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private withdrawal period.
     */
    function dstWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return startTimestamp + dstFinalityDuration(timelocks);
        }
    }

    /**
     * @notice Returns the duration of the private withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @return The duration of the private withdrawal period.
     */
    function dstWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256) {
        return Timelocks.unwrap(timelocks) >> _DST_WITHDRAWAL_OFFSET & _TIMELOCK_MASK;
    }

    /**
     * @notice Returns the start of the public withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the private withdrawal duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the public withdrawal period.
     */
    function dstPubWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return dstWithdrawalStart(timelocks, startTimestamp) + dstWithdrawalDuration(timelocks);
        }
    }

    /**
     * @notice Returns the duration of the public withdrawal period on the destination chain.
     * @param timelocks The timelocks to get the public withdrawal duration from.
     * @return The duration of the public withdrawal period.
     */
    function dstPubWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256) {
        return Timelocks.unwrap(timelocks) >> _DST_PUB_WITHDRAWAL_OFFSET & _TIMELOCK_MASK;
    }

    /**
     * @notice Returns the start of the private cancellation period on the destination chain.
     * @param timelocks The timelocks to get the public withdrawal duration from.
     * @param startTimestamp The timestamp when the counting starts.
     * @return The start of the private cancellation period.
     */
    function dstCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256) {
        unchecked {
            return dstPubWithdrawalStart(timelocks, startTimestamp) + dstPubWithdrawalDuration(timelocks);
        }
    }
}
