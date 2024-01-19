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
        
        assertEq(timelocksTest.getSrcFinalityDuration(), srcTimelocks.finality);
        assertEq(timelocksTest.getSrcWithdrawalDuration(), srcTimelocks.withdrawal);
        assertEq(timelocksTest.getSrcCancellationDuration(), srcTimelocks.cancel);
        assertEq(timelocksTest.getDstFinalityDuration(), dstTimelocks.finality);
        assertEq(timelocksTest.getDstWithdrawalDuration(), dstTimelocks.withdrawal);
        assertEq(timelocksTest.getDstPubWithdrawalDuration(), dstTimelocks.publicWithdrawal);
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
        
        assertEq(timelocksTest.getSrcWithdrawalStart(timestamp), timestamp + srcTimelocks.finality);
        assertEq(timelocksTest.getSrcCancellationStart(timestamp), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal);
        assertEq(timelocksTest.getSrcPubCancellationStart(timestamp), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel);
        assertEq(timelocksTest.getDstWithdrawalStart(timestamp), timestamp + dstTimelocks.finality);
        assertEq(timelocksTest.getDstPubWithdrawalStart(timestamp), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal);
        assertEq(timelocksTest.getDstCancellationStart(timestamp), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal);
    }

    /* solhint-enable func-name-mixedcase */
}
