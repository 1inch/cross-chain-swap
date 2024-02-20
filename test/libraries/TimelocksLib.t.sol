// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";
import { TimelocksSettersLib } from "../utils/libraries/TimelocksSettersLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";

contract TimelocksLibTest is BaseSetup {
    using TimelocksLib for Timelocks;
    using TimelocksSettersLib for Timelocks;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function test_getStartTimestamps() public {
        uint256 timestamp = block.timestamp;
        Timelocks timelocksTest = TimelocksSettersLib.init(
            srcTimelocks.finality,
            srcTimelocks.withdrawal,
            srcTimelocks.cancel,
            dstTimelocks.finality,
            dstTimelocks.withdrawal,
            dstTimelocks.publicWithdrawal,
            timestamp
        );

        assertEq(timelocksTest.rescueStart(RESCUE_DELAY), timestamp + RESCUE_DELAY);
        assertEq(timelocksTest.srcWithdrawalStart(), timestamp + srcTimelocks.finality);
        assertEq(timelocksTest.srcCancellationStart(), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal);
        assertEq(
            timelocksTest.srcPubCancellationStart(), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel
        );
        assertEq(timelocksTest.dstWithdrawalStart(), timestamp + dstTimelocks.finality);
        assertEq(timelocksTest.dstPubWithdrawalStart(), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal);
        assertEq(
            timelocksTest.dstCancellationStart(),
            timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal
        );
    }

    /* solhint-enable func-name-mixedcase */
}
