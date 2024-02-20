// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Timelocks } from "contracts/libraries/TimelocksLib.sol";
import { TimelocksSettersLib } from "../utils/libraries/TimelocksSettersLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { TimelocksLibMock } from "../utils/mocks/TimelocksLibMock.sol";

contract TimelocksLibTest is BaseSetup {
    TimelocksLibMock public timelocksLibMock;

    function setUp() public virtual override {
        BaseSetup.setUp();
        timelocksLibMock = new TimelocksLibMock();
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

        assertEq(timelocksLibMock.rescueStart(timelocksTest, RESCUE_DELAY), timestamp + RESCUE_DELAY);
        assertEq(timelocksLibMock.srcWithdrawalStart(timelocksTest), timestamp + srcTimelocks.finality);
        assertEq(timelocksLibMock.srcCancellationStart(timelocksTest), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal);
        assertEq(timelocksLibMock.srcPubCancellationStart(timelocksTest), timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel);
        assertEq(timelocksLibMock.dstWithdrawalStart(timelocksTest), timestamp + dstTimelocks.finality);
        assertEq(timelocksLibMock.dstPubWithdrawalStart(timelocksTest), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal);
        assertEq(timelocksLibMock.dstCancellationStart(timelocksTest), timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal);
    }

    function test_setDeployedAt() public {
        uint256 timestamp = block.timestamp;
        assertEq(Timelocks.unwrap(timelocksLibMock.setDeployedAt(Timelocks.wrap(0), timestamp)), timestamp);
    }

    /* solhint-enable func-name-mixedcase */
}
