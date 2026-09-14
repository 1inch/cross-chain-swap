// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { IEscrowSrc } from "contracts/interfaces/IEscrowSrc.sol";
import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { NoReceiveCaller } from "contracts/mocks/NoReceiveCaller.sol";
import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract EscrowTest is BaseSetup {
    using ImmutablesLib for IBaseEscrow.Immutables;

    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant WRONG_SECRET = keccak256(abi.encodePacked("wrong secret"));

    function setUp() public virtual override {
        BaseSetup.setUp();
        accessToken.mint(address(this), 1);
    }

    /* solhint-disable func-name-mixedcase */
    // Only resolver can withdraw
    function test_NoWithdrawalByAnyoneSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        // withdraw
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);
    }

    function test_NoWithdrawalOutsideOfAllowedPeriodSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        // withdraw during finality lock
        vm.prank(bob.addr);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);

        // withdraw during the cancellation period
        vm.warp(block.timestamp + srcTimelocks.cancellation + 100);
        vm.prank(bob.addr);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);
    }

    function test_NoWithdrawalOutsideOfAllowedPeriodDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // withdraw during the finality lock
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        dstClone.withdraw(SECRET, immutables);

        // withdraw during the cancellation period
        vm.warp(block.timestamp + dstTimelocks.cancellation + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        dstClone.withdraw(SECRET, immutables);
    }

    function test_WithdrawSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = usdc.balanceOf(address(swapData.srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        vm.expectEmit();
        emit IBaseEscrow.EscrowWithdrawal(SECRET);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_WithdrawSrcTo() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        address target = charlie.addr;

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceTarget = usdc.balanceOf(target);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = usdc.balanceOf(address(swapData.srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        swapData.srcClone.withdrawTo(SECRET, target, swapData.immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob);
        assertEq(usdc.balanceOf(target), balanceTarget + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_NoPublicWithdrawalOutsideOfAllowedPeriodSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        // withdraw during the private withdrawal
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        swapData.srcClone.publicWithdraw(SECRET, swapData.immutables);

        //withdraw during the cancellation period
        vm.warp(block.timestamp + srcTimelocks.cancellation + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        swapData.srcClone.publicWithdraw(SECRET, swapData.immutables);
    }

    function test_PublicWithdrawSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceThisNative = address(this).balance;
        uint256 balanceEscrow = usdc.balanceOf(address(swapData.srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.publicWithdrawal + 100);
        swapData.srcClone.publicWithdraw(SECRET, swapData.immutables);

        assertEq(address(this).balance, balanceThisNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }


    function test_RescueFundsSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.startPrank(bob.addr);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectEmit();
        emit IBaseEscrow.FundsRescued(address(usdc), SRC_SAFETY_DEPOSIT);
        swapData.srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, swapData.immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
    }

    function test_RescueFundsSrcNative() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT + MAKING_AMOUNT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.startPrank(bob.addr);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, MAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectEmit();
        emit IBaseEscrow.FundsRescued(address(0), MAKING_AMOUNT);
        swapData.srcClone.rescueFunds(address(0), MAKING_AMOUNT, swapData.immutables);
        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT + MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, 0);
    }

    function test_NoRescueFundsEarlierSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.startPrank(bob.addr);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        swapData.srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, swapData.immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), SRC_SAFETY_DEPOSIT);
    }

    function test_NoRescueFundsByAnyoneSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        swapData.srcClone.withdraw(SECRET, swapData.immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        swapData.srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, swapData.immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), SRC_SAFETY_DEPOSIT);
    }

    function test_WithdrawByResolverDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        vm.expectEmit();
        emit IBaseEscrow.EscrowWithdrawal(SECRET);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), 
            balanceAlice + TAKING_AMOUNT - immutables.integratorFeeAmount() - immutables.protocolFeeAmount());
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_WithdrawByResolverDstNative() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDstCustom(
            HASHED_SECRET,
            TAKING_AMOUNT,
            alice.addr,
            bob.addr,
            address(0x00),
            DST_SAFETY_DEPOSIT,
            PROTOCOL_FEE,
            INTEGRATOR_FEE,
            INTEGRATOR_SHARES,
            WHITELIST_PROTOCOL_FEE_DISCOUNT,
            true
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT + TAKING_AMOUNT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = alice.addr.balance;
        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        vm.expectEmit();
        emit IBaseEscrow.EscrowWithdrawal(SECRET);
        dstClone.withdraw(SECRET, immutables);

        assertEq(alice.addr.balance, balanceAlice + TAKING_AMOUNT - immutables.integratorFeeAmount() - immutables.protocolFeeAmount());
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, balanceEscrow - DST_SAFETY_DEPOSIT - TAKING_AMOUNT);
    }

    function test_RescueFundsDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        dai.transfer(address(dstClone), DST_SAFETY_DEPOSIT);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), 
            balanceAlice + TAKING_AMOUNT - immutables.integratorFeeAmount() - immutables.protocolFeeAmount());
        assertEq(bob.addr.balance, balanceBobNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, 0);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectEmit();
        emit IBaseEscrow.FundsRescued(address(dai), DST_SAFETY_DEPOSIT);
        dstClone.rescueFunds(address(dai), DST_SAFETY_DEPOSIT, immutables);
        assertEq(dai.balanceOf(bob.addr), balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
    }

    function test_RescueFundsDstNative() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        (bool success,) = address(dstClone).call{ value: TAKING_AMOUNT }("");
        assertEq(success, true);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT - FEES_AMOUNT);
        assertEq(dai.balanceOf(protocolFeeReceiver), PROTOCOL_FEE_AMOUNT);
        assertEq(dai.balanceOf(integratorFeeReceiver), FEES_AMOUNT - PROTOCOL_FEE_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectEmit();
        emit IBaseEscrow.FundsRescued(address(0), TAKING_AMOUNT);
        dstClone.rescueFunds(address(0), TAKING_AMOUNT, immutables);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT + TAKING_AMOUNT);
        assertEq(address(dstClone).balance, 0);
    }

    function test_NoRescueFundsEarlierDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        (bool success,) = address(dstClone).call{ value: TAKING_AMOUNT }("");
        assertEq(success, true);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT - FEES_AMOUNT);
        assertEq(dai.balanceOf(protocolFeeReceiver), PROTOCOL_FEE_AMOUNT);
        assertEq(dai.balanceOf(integratorFeeReceiver), FEES_AMOUNT - PROTOCOL_FEE_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);

        // rescue
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        dstClone.rescueFunds(address(0), TAKING_AMOUNT, immutables);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);
    }

    function test_NoRescueFundsByAnyoneDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        (bool success,) = address(dstClone).call{ value: TAKING_AMOUNT }("");
        assertEq(success, true);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT - FEES_AMOUNT);
        assertEq(dai.balanceOf(protocolFeeReceiver), PROTOCOL_FEE_AMOUNT);
        assertEq(dai.balanceOf(integratorFeeReceiver), FEES_AMOUNT - PROTOCOL_FEE_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.stopPrank();
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        dstClone.rescueFunds(address(0), TAKING_AMOUNT, immutables);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);
    }

    function test_NoWithdrawalWithWrongSecretSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        vm.expectRevert(IBaseEscrow.InvalidSecret.selector);
        swapData.srcClone.withdraw(WRONG_SECRET, swapData.immutables);
    }

    function test_NoWithdrawalWithWrongSecretDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidSecret.selector);
        dstClone.withdraw(WRONG_SECRET, immutables);
    }

    // During non-public withdrawal period
    function test_NoWithdrawalByNonResolverDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        dstClone.withdraw(SECRET, immutables);
    }

    // During public withdrawal period
    function test_WithdrawByAnyoneDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceThis = address(this).balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal + 100);
        vm.expectEmit();
        emit IBaseEscrow.EscrowWithdrawal(SECRET);
        IEscrowDst(address(dstClone)).publicWithdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT - FEES_AMOUNT);
        assertEq(dai.balanceOf(protocolFeeReceiver), PROTOCOL_FEE_AMOUNT);
        assertEq(dai.balanceOf(integratorFeeReceiver), FEES_AMOUNT - PROTOCOL_FEE_AMOUNT);
        assertEq(address(this).balance, balanceThis + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    // During public withdrawal period
    function test_WithdrawByResolverPublicDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal + 100);
        vm.expectEmit();
        emit IBaseEscrow.EscrowWithdrawal(SECRET);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT - FEES_AMOUNT);
        assertEq(dai.balanceOf(protocolFeeReceiver), PROTOCOL_FEE_AMOUNT);
        assertEq(dai.balanceOf(integratorFeeReceiver), FEES_AMOUNT - PROTOCOL_FEE_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_NoFailedNativeTokenTransferWithdrawalSrc() public {
        // deploy escrow
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.publicWithdrawal + 100);
        NoReceiveCaller caller = new NoReceiveCaller();
        accessToken.mint(address(caller), 1);
        bytes memory data = abi.encodeWithSelector(IEscrowSrc.publicWithdraw.selector, SECRET, swapData.immutables);
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        caller.arbitraryCall(address(swapData.srcClone), data);
    }

    function test_NoFailedNativeTokenTransferWithdrawalDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal + 10);
        accessToken.mint(address(nativeTokenRejector), 1);
        vm.prank(address(nativeTokenRejector));
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        dstClone.publicWithdraw(SECRET, immutables);
    }

    function test_NoFailedNativeTokenTransferWithdrawalDstNative() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDstCustom(
            HASHED_SECRET,
            TAKING_AMOUNT,
            address(nativeTokenRejector),
            bob.addr, address(0x00),
            DST_SAFETY_DEPOSIT,
            PROTOCOL_FEE,
            INTEGRATOR_FEE,
            INTEGRATOR_SHARES,
            WHITELIST_PROTOCOL_FEE_DISCOUNT,
            true
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT + TAKING_AMOUNT }(immutables, srcCancellationTimestamp);

        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        dstClone.withdraw(SECRET, immutables);
        assertEq(bob.addr.balance, balanceBob);
        assertEq(address(dstClone).balance, balanceEscrow);
    }

    function test_NoPublicWithdrawOutsideOfAllowedPeriodDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // withdraw during the private withdrawal
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        IEscrowDst(address(dstClone)).publicWithdraw(SECRET, immutables);

        // withdraw during the cancellation
        vm.warp(block.timestamp + dstTimelocks.cancellation + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        IEscrowDst(address(dstClone)).publicWithdraw(SECRET, immutables);
    }

    /* solhint-enable func-name-mixedcase */
}
