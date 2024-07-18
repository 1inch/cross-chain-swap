// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IBaseEscrow } from "../../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../../contracts/interfaces/IEscrowFactory.sol";
import { IEscrowSrc } from "../../contracts/interfaces/IEscrowSrc.sol";
import { IEscrowDst } from "../../contracts/interfaces/IEscrowDst.sol";
import { NoReceiveCaller } from "../../contracts/mocks/NoReceiveCaller.sol";

import { BaseSetup, IOrderMixin } from "../utils/BaseSetup.sol";

contract EscrowTest is BaseSetup {
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant WRONG_SECRET = keccak256(abi.encodePacked("wrong secret"));

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */
    // Only resolver can withdraw
    function test_NoWithdrawalByAnyoneSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // withdraw
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        srcClone.withdraw(SECRET, immutables);
    }

    function test_NoWithdrawalOutsideOfAllowedPeriodSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // withdraw during finality lock
        vm.prank(bob.addr);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.withdraw(SECRET, immutables);

        // withdraw during the cancellation period
        vm.warp(block.timestamp + srcTimelocks.cancellation + 100);
        vm.prank(bob.addr);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.withdraw(SECRET, immutables);
    }

    function test_NoWithdrawalOutsideOfAllowedPeriodDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        vm.expectEmit();
        emit IBaseEscrow.Withdrawal(SECRET);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_WithdrawSrcTo() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        address target = charlie.addr;

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceTarget = usdc.balanceOf(target);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        srcClone.withdrawTo(SECRET, target, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob);
        assertEq(usdc.balanceOf(target), balanceTarget + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_NoPublicWithdrawalOutsideOfAllowedPeriodSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // withdraw during the private withdrawal
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.publicWithdraw(SECRET, immutables);

        //withdraw during the cancellation period
        vm.warp(block.timestamp + srcTimelocks.cancellation + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.publicWithdraw(SECRET, immutables);
    }

    function test_PublicWithdrawSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceThisNative = address(this).balance;
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.publicWithdrawal + 100);
        srcClone.publicWithdraw(SECRET, immutables);

        assertEq(address(this).balance, balanceThisNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }


    function test_RescueFundsSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.startPrank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectEmit();
        emit IBaseEscrow.FundsRescued(address(usdc), SRC_SAFETY_DEPOSIT);
        srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
    }

    function test_RescueFundsSrcNative() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT + MAKING_AMOUNT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.startPrank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, MAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectEmit();
        emit IBaseEscrow.FundsRescued(address(0), MAKING_AMOUNT);
        srcClone.rescueFunds(address(0), MAKING_AMOUNT, immutables);
        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT + MAKING_AMOUNT);
        assertEq(address(srcClone).balance, 0);
    }

    function test_NoRescueFundsEarlierSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.startPrank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);
    }

    function test_NoRescueFundsByAnyoneSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT + SRC_SAFETY_DEPOSIT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);
    }

    function test_WithdrawByResolverDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        emit IBaseEscrow.Withdrawal(SECRET);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_WithdrawByResolverDstNative() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(0x00)
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
        emit IBaseEscrow.Withdrawal(SECRET);
        dstClone.withdraw(SECRET, immutables);

        assertEq(alice.addr.balance, balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, balanceEscrow - DST_SAFETY_DEPOSIT - TAKING_AMOUNT);
    }

    function test_RescueFundsDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
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
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
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
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
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
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
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
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.prank(bob.addr);
        vm.expectRevert(IBaseEscrow.InvalidSecret.selector);
        srcClone.withdraw(WRONG_SECRET, immutables);
    }

    function test_NoWithdrawalWithWrongSecretDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        emit IBaseEscrow.Withdrawal(SECRET);
        IEscrowDst(address(dstClone)).publicWithdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(address(this).balance, balanceThis + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    // During public withdrawal period
    function test_WithdrawByResolverPublicDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        emit IBaseEscrow.Withdrawal(SECRET);
        dstClone.withdraw(SECRET, immutables);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_NoFailedNativeTokenTransferWithdrawalSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.publicWithdrawal + 100);
        NoReceiveCaller caller = new NoReceiveCaller();
        bytes memory data = abi.encodeWithSelector(IEscrowSrc.publicWithdraw.selector, SECRET, immutables);
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        caller.arbitraryCall(address(srcClone), data);
    }

    function test_NoFailedNativeTokenTransferWithdrawalDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal + 10);
        vm.prank(address(escrowFactory));
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        dstClone.publicWithdraw(SECRET, immutables);
    }

    function test_NoFailedNativeTokenTransferWithdrawalDstNative() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, address(escrowFactory), bob.addr, address(0x00)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT + TAKING_AMOUNT }(immutables, srcCancellationTimestamp);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        dstClone.withdraw(SECRET, immutables);
    }

    function test_NoPublicWithdrawOutsideOfAllowedPeriodDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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

    function test_CancelResolverSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = bob.addr.balance;
        uint256 balanceAlice = usdc.balanceOf(alice.addr);
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // cancel
        vm.warp(block.timestamp + srcTimelocks.cancellation + 10);
        vm.prank(bob.addr);
        vm.expectEmit();
        emit IBaseEscrow.EscrowCancelled();
        srcClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBob + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(alice.addr), balanceAlice + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_CancelResolverSrcReceiver() public {
        address receiver = charlie.addr;
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, receiver, true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        IEscrowFactory.DstImmutablesComplement memory immutablesComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(receiver)),
            amount: TAKING_AMOUNT,
            token: Address.wrap(uint160(address(dai))),
            safetyDeposit: DST_SAFETY_DEPOSIT,
            chainId: block.chainid
        });

        vm.prank(address(limitOrderProtocol));
        vm.expectEmit();
        emit IEscrowFactory.SrcEscrowCreated(immutables, immutablesComplement);
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceBob = bob.addr.balance;
        uint256 balanceAlice = usdc.balanceOf(alice.addr);
        uint256 balanceReceiver = usdc.balanceOf(receiver);
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // cancel
        vm.warp(block.timestamp + srcTimelocks.cancellation + 10);
        vm.prank(bob.addr);
        vm.expectEmit();
        emit IBaseEscrow.EscrowCancelled();
        srcClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBob + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(alice.addr), balanceAlice + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(receiver), balanceReceiver);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_CancelPublicSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        uint256 balanceThis = address(this).balance;
        uint256 balanceAlice = usdc.balanceOf(alice.addr);
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // cancel
        vm.warp(block.timestamp + srcTimelocks.publicCancellation + 100);
        vm.expectEmit();
        emit IBaseEscrow.EscrowCancelled();
        srcClone.publicCancel(immutables);

        assertEq(address(this).balance, balanceThis + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(alice.addr), balanceAlice + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_NoCancelDuringWithdrawalSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // cancel
        vm.prank(bob.addr);
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.cancel(immutables);
    }

    function test_NoPublicCancelDuringPrivateCancellationSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // cancel during private cancellation period
        vm.warp(block.timestamp + srcTimelocks.cancellation + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        srcClone.publicCancel(immutables);
    }

    // During non-public cancel period
    function test_NoAnyoneCancelDuringResolverCancelSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // cancel
        vm.warp(block.timestamp + srcTimelocks.cancellation + 10);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        srcClone.cancel(immutables);
    }

    function test_CancelDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // cancel
        vm.warp(block.timestamp + dstTimelocks.cancellation + 100);
        vm.expectEmit();
        emit IBaseEscrow.EscrowCancelled();
        dstClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBobNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(bob.addr), balanceBob + TAKING_AMOUNT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_CancelDstDifferentTarget() public {
        address target = charlie.addr;
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, target, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceTarget = dai.balanceOf(target);
        uint256 balanceTargetNative = target.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // cancel
        vm.warp(block.timestamp + dstTimelocks.cancellation + 100);
        vm.prank(target);
        vm.expectEmit();
        emit IBaseEscrow.EscrowCancelled();
        dstClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBobNative);
        assertEq(target.balance, balanceTargetNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(bob.addr), balanceBob);
        assertEq(dai.balanceOf(target), balanceTarget + TAKING_AMOUNT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_CancelDstWithNativeToken() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(0)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT + TAKING_AMOUNT }(immutables, srcCancellationTimestamp);

        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = address(dstClone).balance;

        // cancel
        vm.warp(block.timestamp + dstTimelocks.cancellation + 100);
        vm.expectEmit();
        emit IBaseEscrow.EscrowCancelled();
        dstClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT + TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrow - DST_SAFETY_DEPOSIT - TAKING_AMOUNT);
    }

    // Only resolver can cancel
    function test_NoCancelByAnyoneDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.cancellation + 100);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        dstClone.cancel(immutables);
    }

    function test_NoCancelDuringWithdrawalDst() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        // cancel during the private withdrawal period
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 100);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        dstClone.cancel(immutables);
    }

    function test_NoFailedNativeTokenTransferCancelSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // cancel
        vm.warp(block.timestamp + srcTimelocks.publicCancellation + 100);
        vm.prank(address(escrowFactory));
        vm.expectRevert(IBaseEscrow.NativeTokenSendingFailure.selector);
        srcClone.publicCancel(immutables);
    }

    function test_NoCallsWithInvalidImmutables() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutablesSrc
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (IBaseEscrow.Immutables memory immutablesDst, uint256 srcCancellationTimestamp, IBaseEscrow dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        // deploy src escrow
        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );

        // deploy dst escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutablesDst, srcCancellationTimestamp);

        // withdraw src
        vm.warp(block.timestamp + srcTimelocks.withdrawal + 10);
        immutablesSrc.amount = TAKING_AMOUNT;
        vm.expectRevert(IBaseEscrow.InvalidImmutables.selector);
        srcClone.withdraw(SECRET, immutablesSrc);

        // withdraw dst
        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        immutablesDst.amount = MAKING_AMOUNT;
        vm.expectRevert(IBaseEscrow.InvalidImmutables.selector);
        dstClone.withdraw(SECRET, immutablesDst);

        // cancel src
        vm.warp(block.timestamp + srcTimelocks.cancellation + 10);
        vm.expectRevert(IBaseEscrow.InvalidImmutables.selector);
        srcClone.cancel(immutablesSrc);

        // cancel dst
        vm.warp(block.timestamp + dstTimelocks.cancellation + 10);
        vm.expectRevert(IBaseEscrow.InvalidImmutables.selector);
        dstClone.cancel(immutablesDst);

        vm.warp(block.timestamp + RESCUE_DELAY);

        // rescue src
        vm.expectRevert(IBaseEscrow.InvalidImmutables.selector);
        srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, immutablesSrc);

        // rescue dst
        vm.expectRevert(IBaseEscrow.InvalidImmutables.selector);
        dstClone.rescueFunds(address(dai), DST_SAFETY_DEPOSIT, immutablesDst);
    }

    /* solhint-enable func-name-mixedcase */
}
