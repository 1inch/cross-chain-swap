// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @dev Timelocks for the source and the destination chains plus the deployment timestamp.
 * Timelocks store the number of seconds from the time the contract is deployed to the start of a specific period.
 * For illustrative purposes, it is possible to describe timelocks by two structures:
 * struct SrcTimelocks {
 *     uint256 withdrawal;
 *     uint256 cancellation;
 *     uint256 publicCancellation;
 * }
 *
 * struct DstTimelocks {
 *     uint256 withdrawal;
 *     uint256 publicWithdrawal;
 *     uint256 cancellation;
 * }
 *
 * withdrawal: Period when only the taker with a secret can withdraw tokens for taker (source chain) or maker (destination chain).
 * publicWithdrawal: Period when anyone with a secret can withdraw tokens for maker (destination chain).
 * cancellation: Period when escrow can only be cancelled by the taker.
 * publicCancellation: Period when escrow can be cancelled by anyone.
 */
type Timelocks is uint256;

/**
 * @title Timelocks library for compact storage of timelocks in a uint256.
 */
library TimelocksLib {
    enum Stage {
        DeployedAt,
        SrcWithdrawal,
        SrcCancellation,
        SrcPublicCancellation,
        DstWithdrawal,
        DstPublicWithdrawal,
        DstCancellation
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

    /**
     * @notice Returns the timelock value for the given stage.
     * @param timelocks The timelocks to get the value from.
     * @param stage The stage to get the value for.
     * @return The timelock value for the given stage.
     */
    function get(Timelocks timelocks, Stage stage) internal pure returns (uint256) {
        uint256 data = Timelocks.unwrap(timelocks);
        uint256 bitShift = uint256(stage) << 5;
        return (uint32(data) + uint32(data >> bitShift));
    }
}
