// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

/**
 * @title Library with setters for Timelocks.
 */
library TimelocksSettersLib {
    /**
     * @notice Initializes the timelocks.
     * @param srcFinality Duration of the finality period on the source chain.
     * @param srcWithdrawal Duration of the private withdrawal period on the source chain.
     * @param srcCancellation Duration of the private cancellation period on the source chain.
     * @param dstFinality Duration of the finality period on the destination chain.
     * @param dstWithdrawal Duration of the private withdrawal period on the destination chain.
     * @param dstPubWithdrawal Duration of the public withdrawal period on the destination chain.
     * @param deployedAtVal Deployment timestamp.
     * @return The initialized Timelocks.
     */
    function init(
        uint256 srcFinality,
        uint256 srcWithdrawal,
        uint256 srcCancellation,
        uint256 dstFinality,
        uint256 dstWithdrawal,
        uint256 dstPubWithdrawal,
        uint256 deployedAtVal
    ) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            0 | ((srcFinality & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._SRC_FINALITY_OFFSET)
                | ((srcWithdrawal & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._SRC_WITHDRAWAL_OFFSET)
                | ((srcCancellation & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._SRC_CANCELLATION_OFFSET)
                | ((dstFinality & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._DST_FINALITY_OFFSET)
                | ((dstWithdrawal & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._DST_WITHDRAWAL_OFFSET)
                | ((dstPubWithdrawal & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._DST_PUB_WITHDRAWAL_OFFSET)
                | uint40(deployedAtVal)
        );
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
            (Timelocks.unwrap(timelocks) & ~(TimelocksLib._TIMELOCK_MASK << TimelocksLib._SRC_FINALITY_OFFSET))
                | ((value & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._SRC_FINALITY_OFFSET)
        );
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
            (Timelocks.unwrap(timelocks) & ~(TimelocksLib._TIMELOCK_MASK << TimelocksLib._SRC_WITHDRAWAL_OFFSET))
                | ((value & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._SRC_WITHDRAWAL_OFFSET)
        );
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
            (Timelocks.unwrap(timelocks) & ~(TimelocksLib._TIMELOCK_MASK << TimelocksLib._SRC_CANCELLATION_OFFSET))
                | ((value & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._SRC_CANCELLATION_OFFSET)
        );
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
            (Timelocks.unwrap(timelocks) & ~(TimelocksLib._TIMELOCK_MASK << TimelocksLib._DST_FINALITY_OFFSET))
                | ((value & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._DST_FINALITY_OFFSET)
        );
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
            (Timelocks.unwrap(timelocks) & ~(TimelocksLib._TIMELOCK_MASK << TimelocksLib._DST_WITHDRAWAL_OFFSET))
                | ((value & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._DST_WITHDRAWAL_OFFSET)
        );
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
            (Timelocks.unwrap(timelocks) & ~(TimelocksLib._TIMELOCK_MASK << TimelocksLib._DST_PUB_WITHDRAWAL_OFFSET))
                | ((value & TimelocksLib._TIMELOCK_MASK) << TimelocksLib._DST_PUB_WITHDRAWAL_OFFSET)
        );
    }
}
