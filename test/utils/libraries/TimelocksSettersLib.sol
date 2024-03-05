// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

/**
 * @title Library with setters for Timelocks.
 */
library TimelocksSettersLib {
    /**
     * @notice Initializes the timelocks.
     * @param srcWithdrawalStart Seconds between `deplyedAt` and the start of the withdrawal period on the source chain.
     * @param srcCancellationStart Seconds between `deplyedAt` and the start of the cancellation period on the source chain.
     * @param srcPublicCancellationStart Seconds between `deplyedAt` and the start of the public cancellation period on the source chain.
     * @param dstWithdrawalStart Seconds between `deplyedAt` and the start of the withdrawal period on the destination chain.
     * @param dstPublicWithdrawalStart Seconds between `deplyedAt` and the start of the public withdrawal period on the destination chain.
     * @param dstCancellationStart Seconds between `deplyedAt` and the start of the cancellation period on the destination chain.
     * @param deployedAt Deployment timestamp.
     * @return The initialized Timelocks.
     */
    function init(
        uint32 srcWithdrawalStart,
        uint32 srcCancellationStart,
        uint32 srcPublicCancellationStart,
        uint32 dstWithdrawalStart,
        uint32 dstPublicWithdrawalStart,
        uint32 dstCancellationStart,
        uint32 deployedAt
    ) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            deployedAt
                | (uint256(srcWithdrawalStart) << TimelocksLib._SRC_WITHDRAWAL_START_OFFSET)
                | (uint256(srcCancellationStart) << TimelocksLib._SRC_CANCELLATION_START_OFFSET)
                | (uint256(srcPublicCancellationStart) << TimelocksLib._SRC_PUBLIC_CANCELLATION_START_OFFSET)
                | (uint256(dstWithdrawalStart) << TimelocksLib._DST_WITHDRAWAL_START_OFFSET)
                | (uint256(dstPublicWithdrawalStart) << TimelocksLib._DST_PUBLIC_WITHDRAWAL_START_OFFSET)
                | (uint256(dstCancellationStart) << TimelocksLib._DST_CANCELLATION_START_OFFSET)
        );
    }
}
