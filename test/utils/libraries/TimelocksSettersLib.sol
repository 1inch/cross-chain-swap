// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

/**
 * @title Library with setters for Timelocks.
 */
library TimelocksSettersLib {
    /**
     * @notice Initializes the timelocks.
     * @param srcWithdrawalStart Seconds between `deployedAt` and the start of the withdrawal period on the source chain.
     * @param srcCancellationStart Seconds between `deployedAt` and the start of the cancellation period on the source chain.
     * @param srcPublicCancellationStart Seconds between `deployedAt` and the start of the public cancellation period on the source chain.
     * @param dstWithdrawalStart Seconds between `deployedAt` and the start of the withdrawal period on the destination chain.
     * @param dstPublicWithdrawalStart Seconds between `deployedAt` and the start of the public withdrawal period on the destination chain.
     * @param dstCancellationStart Seconds between `deployedAt` and the start of the cancellation period on the destination chain.
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
                | (uint256(srcWithdrawalStart) << (uint256(TimelocksLib.Stage.SrcWithdrawal) * 32))
                | (uint256(srcCancellationStart) << (uint256(TimelocksLib.Stage.SrcCancellation) * 32))
                | (uint256(srcPublicCancellationStart) << (uint256(TimelocksLib.Stage.SrcPublicCancellation) * 32))
                | (uint256(dstWithdrawalStart) << (uint256(TimelocksLib.Stage.DstWithdrawal) * 32))
                | (uint256(dstPublicWithdrawalStart) << (uint256(TimelocksLib.Stage.DstPublicWithdrawal) * 32))
                | (uint256(dstCancellationStart) << (uint256(TimelocksLib.Stage.DstCancellation) * 32))
        );
    }
}
