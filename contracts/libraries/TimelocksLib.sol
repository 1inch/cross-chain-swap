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
    enum Start {
        DeployedAt,
        SrcWithdrawal,
        SrcCancellation,
        SrcPublicCancellation,
        DstWithdrawal,
        DstPublicWithdrawal,
        DstCancellation
    }

    uint256 internal constant _TIMELOCK_MASK = type(uint32).max;

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

    /**
     * @notice Returns the timelock value for the given epoch.
     * @param timelocks The timelocks to get the value from.
     * @param epoch The epoch to get the value for.
     * @return The timelock value for the given epoch.
     */
    function get(Timelocks timelocks, Start epoch) internal pure returns (uint256) {
        unchecked {
            uint256 data = Timelocks.unwrap(timelocks);
            uint256 bitShift = uint256(epoch) << 5;
            return (data + (data >> bitShift)) & _TIMELOCK_MASK;
        }
    }
}
