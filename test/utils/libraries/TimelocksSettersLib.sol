// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "../../../contracts/libraries/TimelocksLib.sol";

/**
 * @title Library with setters for Timelocks.
 */
library TimelocksSettersLib {
    /**
     * @notice Initializes the timelocks.
     * @param srcWithdrawal Seconds between `deployedAt` and the start of the withdrawal period on the source chain.
     * @param srcCancellation Seconds between `deployedAt` and the start of the cancellation period on the source chain.
     * @param srcPublicCancellation Seconds between `deployedAt` and the start of the public cancellation period on the source chain.
     * @param dstWithdrawal Seconds between `deployedAt` and the start of the withdrawal period on the destination chain.
     * @param dstPublicWithdrawal Seconds between `deployedAt` and the start of the public withdrawal period on the destination chain.
     * @param dstCancellation Seconds between `deployedAt` and the start of the cancellation period on the destination chain.
     * @param deployedAt Deployment timestamp.
     * @return The initialized Timelocks.
     */
    function init(
        uint32 srcWithdrawal,
        uint32 srcPublicWithdrawal,
        uint32 srcCancellation,
        uint32 srcPublicCancellation,
        uint32 dstWithdrawal,
        uint32 dstPublicWithdrawal,
        uint32 dstCancellation,
        uint32 deployedAt
    ) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            (uint256(deployedAt) << 224)
                | (uint256(srcWithdrawal) << (uint256(TimelocksLib.Stage.SrcWithdrawal) * 32))
                | (uint256(srcPublicWithdrawal) << (uint256(TimelocksLib.Stage.SrcPublicWithdrawal) * 32))
                | (uint256(srcCancellation) << (uint256(TimelocksLib.Stage.SrcCancellation) * 32))
                | (uint256(srcPublicCancellation) << (uint256(TimelocksLib.Stage.SrcPublicCancellation) * 32))
                | (uint256(dstWithdrawal) << (uint256(TimelocksLib.Stage.DstWithdrawal) * 32))
                | (uint256(dstPublicWithdrawal) << (uint256(TimelocksLib.Stage.DstPublicWithdrawal) * 32))
                | (uint256(dstCancellation) << (uint256(TimelocksLib.Stage.DstCancellation) * 32))
        );
    }
}
