// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

contract TimelocksLibMock {
    function setDeployedAt(Timelocks timelocks, uint256 value) external pure returns (Timelocks) {
        return TimelocksLib.setDeployedAt(timelocks, value);
    }

    function rescueStart(Timelocks timelocks, uint256 rescueDelay) external pure returns (uint256) {
        return TimelocksLib.rescueStart(timelocks, rescueDelay);
    }

    function srcWithdrawalStart(Timelocks timelocks) external pure returns (uint256) {
        return TimelocksLib.srcWithdrawalStart(timelocks);
    }

    function srcCancellationStart(Timelocks timelocks) external pure returns (uint256) {
        return TimelocksLib.srcCancellationStart(timelocks);
    }

    function srcPubCancellationStart(Timelocks timelocks) external pure returns (uint256) {
        return TimelocksLib.srcPubCancellationStart(timelocks);
    }

    function dstWithdrawalStart(Timelocks timelocks) external pure returns (uint256) {
        return TimelocksLib.dstWithdrawalStart(timelocks);
    }

    function dstPubWithdrawalStart(Timelocks timelocks) external pure returns (uint256) {
        return TimelocksLib.dstPubWithdrawalStart(timelocks);
    }

    function dstCancellationStart(Timelocks timelocks) external pure returns (uint256) {
        return TimelocksLib.dstCancellationStart(timelocks);
    }
}
