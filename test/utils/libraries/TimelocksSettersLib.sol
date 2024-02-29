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
        uint32 srcFinality,
        uint32 srcWithdrawal,
        uint32 srcCancellation,
        uint32 dstFinality,
        uint32 dstWithdrawal,
        uint32 dstPubWithdrawal,
        uint32 deployedAtVal
    ) internal pure returns (Timelocks) {
        return Timelocks.wrap(
            deployedAtVal
                | (uint256(srcFinality) << TimelocksLib._SRC_FINALITY_OFFSET)
                | (uint256(srcWithdrawal) << TimelocksLib._SRC_WITHDRAWAL_OFFSET)
                | (uint256(srcCancellation) << TimelocksLib._SRC_CANCELLATION_OFFSET)
                | (uint256(dstFinality) << TimelocksLib._DST_FINALITY_OFFSET)
                | (uint256(dstWithdrawal) << TimelocksLib._DST_WITHDRAWAL_OFFSET)
                | (uint256(dstPubWithdrawal) << TimelocksLib._DST_PUB_WITHDRAWAL_OFFSET)
        );
    }
}
