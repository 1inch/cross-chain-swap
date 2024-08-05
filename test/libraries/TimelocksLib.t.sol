// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";

import { Timelocks } from "contracts/libraries/TimelocksLib.sol";
import { TimelocksSettersLib } from "../utils/libraries/TimelocksSettersLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";
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
            srcTimelocks.withdrawal,
            srcTimelocks.publicWithdrawal,
            srcTimelocks.cancellation,
            srcTimelocks.publicCancellation,
            dstTimelocks.withdrawal,
            dstTimelocks.publicWithdrawal,
            dstTimelocks.cancellation,
            uint32(timestamp)
        );

        assertEq(timelocksLibMock.rescueStart(timelocksTest, RESCUE_DELAY), timestamp + RESCUE_DELAY);
        assertEq(timelocksLibMock.srcWithdrawal(timelocksTest), timestamp + srcTimelocks.withdrawal);
        assertEq(timelocksLibMock.srcCancellation(timelocksTest), timestamp + srcTimelocks.cancellation);
        assertEq(timelocksLibMock.srcPublicCancellation(timelocksTest), timestamp + srcTimelocks.publicCancellation);
        assertEq(timelocksLibMock.dstWithdrawal(timelocksTest), timestamp + dstTimelocks.withdrawal);
        assertEq(timelocksLibMock.dstPublicWithdrawal(timelocksTest), timestamp + dstTimelocks.publicWithdrawal);
        assertEq(timelocksLibMock.dstCancellation(timelocksTest), timestamp + dstTimelocks.cancellation);
    }

    function test_setDeployedAt() public {
        uint256 timestamp = block.timestamp;
        assertEq(Timelocks.unwrap(timelocksLibMock.setDeployedAt(Timelocks.wrap(0), timestamp)), timestamp << 224);
    }

    function test_NoTimelocksOverflow() public {
        vm.warp(1710159521); // make it real, it's 0 in foundry

        srcTimelocks = CrossChainTestLib.SrcTimelocks({
            withdrawal: 2584807817,
            publicWithdrawal: 2584807817,
            cancellation: 2584807820,
            publicCancellation:
            2584807820
        });
        dstTimelocks = CrossChainTestLib.DstTimelocks({ withdrawal: 2584807817, publicWithdrawal: 2584807817, cancellation: 2584807820 });
        (timelocks, timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        (IBaseEscrow.Immutables memory immutablesDst, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutablesDst, srcCancellationTimestamp);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal);
        uint256 balanceAlice = dai.balanceOf(alice.addr);
        vm.startPrank(alice.addr);
        dstClone.publicWithdraw(SECRET, immutablesDst);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
    }

    /* solhint-enable func-name-mixedcase */
}
