// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";

contract TimelocksLibTest is BaseSetup {
    using TimelocksLib for Timelocks;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function test_SetDurations() public {
        Timelocks timelocksTest;
        timelocksTest = timelocksTest
            .setSrcFinalityDuration(srcTimelocks.finality)
            .setSrcWithdrawalDuration(srcTimelocks.withdrawal)
            .setSrcCancellationDuration(srcTimelocks.cancel)
            .setDstFinalityDuration(dstTimelocks.finality)
            .setDstWithdrawalDuration(dstTimelocks.withdrawal)
            .setDstPubWithdrawalDuration(dstTimelocks.publicWithdrawal);
        
        assertEq(timelocksTest.srcFinalityDuration(), srcTimelocks.finality);
        assertEq(timelocksTest.srcWithdrawalDuration(), srcTimelocks.withdrawal);
        assertEq(timelocksTest.srcCancellationDuration(), srcTimelocks.cancel);
        assertEq(timelocksTest.dstFinalityDuration(), dstTimelocks.finality);
        assertEq(timelocksTest.dstWithdrawalDuration(), dstTimelocks.withdrawal);
        assertEq(timelocksTest.dstPubWithdrawalDuration(), dstTimelocks.publicWithdrawal);
    }

    function test_getStartTimestamps() public {
        uint256 timestamp = block.timestamp;
        Timelocks timelocksTest;
        timelocksTest = timelocksTest
            .setSrcFinalityDuration(srcTimelocks.finality)
            .setSrcWithdrawalDuration(srcTimelocks.withdrawal)
            .setSrcCancellationDuration(srcTimelocks.cancel)
            .setDstFinalityDuration(dstTimelocks.finality)
            .setDstWithdrawalDuration(dstTimelocks.withdrawal)
            .setDstPubWithdrawalDuration(dstTimelocks.publicWithdrawal);
        
        assertEq(timelocksTest.srcWithdrawalStart(timestamp), timestamp + srcTimelocks.finality);
        assertEq(timelocksTest.srcCancellationStart(timestamp), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal);
        assertEq(timelocksTest.srcPubCancellationStart(timestamp), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel);
        assertEq(timelocksTest.dstWithdrawalStart(timestamp), timestamp + dstTimelocks.finality);
        assertEq(timelocksTest.dstPubWithdrawalStart(timestamp), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal);
        assertEq(timelocksTest.dstCancellationStart(timestamp), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal);
    }

    /* solhint-enable func-name-mixedcase */
}
