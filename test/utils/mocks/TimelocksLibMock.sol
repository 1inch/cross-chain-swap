// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

contract TimelocksLibMock {
    using TimelocksLib for Timelocks;

    function setDeployedAt(Timelocks timelocks, uint256 value) external pure returns (Timelocks) {
        return TimelocksLib.setDeployedAt(timelocks, value);
    }

    function rescueStart(Timelocks timelocks, uint256 rescueDelay) external pure returns (uint256) {
        return TimelocksLib.rescueStart(timelocks, rescueDelay);
    }

    function srcWithdrawal(Timelocks timelocks) external pure returns (uint256) {
        return timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
    }

    function srcCancellation(Timelocks timelocks) external pure returns (uint256) {
        return timelocks.get(TimelocksLib.Stage.SrcCancellation);
    }

    function srcPublicCancellation(Timelocks timelocks) external pure returns (uint256) {
        return timelocks.get(TimelocksLib.Stage.SrcPublicCancellation);
    }

    function dstWithdrawal(Timelocks timelocks) external pure returns (uint256) {
        return timelocks.get(TimelocksLib.Stage.DstWithdrawal);
    }

    function dstPublicWithdrawal(Timelocks timelocks) external pure returns (uint256) {
        return timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal);
    }

    function dstCancellation(Timelocks timelocks) external pure returns (uint256) {
        return timelocks.get(TimelocksLib.Stage.DstCancellation);
    }
}
