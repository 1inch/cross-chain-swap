// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "contracts/Escrow.sol";
import { IEscrowFactory } from "contracts/EscrowFactory.sol";
import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { IEscrowSrc } from "contracts/interfaces/IEscrowSrc.sol";

import { BaseSetup, IOrderMixin } from "../utils/BaseSetup.sol";

contract EscrowTest is BaseSetup {
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant WRONG_SECRET = keccak256(abi.encodePacked("wrong secret"));

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */
    // Only resolver can withdraw
    function test_NoWithdrawalByAnyone() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        srcClone.withdraw(SECRET, immutables);
    }

    function test_NoWithdrawalDuringFinalityLockSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.prank(bob.addr);
        vm.expectRevert(IEscrow.InvalidWithdrawalTime.selector);
        srcClone.withdraw(SECRET, immutables);
    }

    function test_NoWithdrawalDuringFinalityLockDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // withdraw
        vm.expectRevert(IEscrow.InvalidWithdrawalTime.selector);
        dstClone.withdraw(SECRET, immutables.args);
    }

    function test_WithdrawSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.prank(bob.addr);
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
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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

        address target = users[2].addr;

        uint256 balanceBob = usdc.balanceOf(bob.addr);
        uint256 balanceTarget = usdc.balanceOf(target);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.prank(bob.addr);
        srcClone.withdrawTo(SECRET, target, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob);
        assertEq(usdc.balanceOf(target), balanceTarget + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_RescueFundsSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.startPrank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
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
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.startPrank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, MAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
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
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.startPrank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidRescueTime.selector);
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
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.prank(bob.addr);
        srcClone.withdraw(SECRET, immutables);

        assertEq(bob.addr.balance, balanceBobNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        srcClone.rescueFunds(address(usdc), SRC_SAFETY_DEPOSIT, immutables);
        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), SRC_SAFETY_DEPOSIT);
    }

    function test_WithdrawByResolverDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    function test_WithdrawByResolverDstNative() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(0x00)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT + TAKING_AMOUNT }(immutables);

        uint256 balanceAlice = alice.addr.balance;
        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(alice.addr.balance, balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, balanceEscrow - DST_SAFETY_DEPOSIT - TAKING_AMOUNT);
    }

    function test_RescueFundsDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        dai.transfer(address(dstClone), DST_SAFETY_DEPOSIT);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBobNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, 0);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        dstClone.rescueFunds(address(dai), DST_SAFETY_DEPOSIT, immutables.args);
        assertEq(dai.balanceOf(bob.addr), balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
    }

    function test_RescueFundsDstNative() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        (bool success,) = address(dstClone).call{ value: TAKING_AMOUNT }("");
        assertEq(success, true);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        dstClone.rescueFunds(address(0), TAKING_AMOUNT, immutables.args);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT + TAKING_AMOUNT);
        assertEq(address(dstClone).balance, 0);
    }

    function test_NoRescueFundsEarlierDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        (bool success,) = address(dstClone).call{ value: TAKING_AMOUNT }("");
        assertEq(success, true);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        vm.expectRevert(IEscrow.InvalidRescueTime.selector);
        dstClone.rescueFunds(address(0), TAKING_AMOUNT, immutables.args);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);
    }

    function test_NoRescueFundsByAnyoneDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        assertEq(address(dstClone).balance, 0);

        vm.startPrank(bob.addr);
        (bool success,) = address(dstClone).call{ value: TAKING_AMOUNT }("");
        assertEq(success, true);

        // deploy escrow
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(bob.addr.balance, balanceBob + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, TAKING_AMOUNT);

        // rescue
        vm.warp(block.timestamp + RESCUE_DELAY);
        vm.stopPrank();
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        dstClone.rescueFunds(address(0), TAKING_AMOUNT, immutables.args);
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
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.prank(bob.addr);
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        srcClone.withdraw(WRONG_SECRET, immutables);
    }

    function test_NoWithdrawalWithWrongSecretDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        dstClone.withdraw(WRONG_SECRET, immutables.args);
    }

    // During non-public withdrawal period
    function test_NoWithdrawalByNonResolverDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        dstClone.withdraw(SECRET, immutables.args);
    }

    // During public withdrawal period
    function test_WithdrawByAnyoneDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceThis = address(this).balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + 100);
        dstClone.withdraw(SECRET, immutables.args);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(address(this).balance, balanceThis + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    // During public withdrawal period
    function test_WithdrawByResolverPublicDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = bob.addr.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + 100);
        dstClone.withdraw(SECRET, immutables.args);

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
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.prank(bob.addr);
        vm.mockCallRevert(bob.addr, SRC_SAFETY_DEPOSIT, "", "REVERTED");
        vm.expectRevert(IEscrow.NativeTokenSendingFailure.selector);
        srcClone.withdraw(SECRET, immutables);
    }

    function test_NoFailedNativeTokenTransferWithdrawalDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + 10);
        vm.prank(address(escrowFactory));
        vm.expectRevert(IEscrow.NativeTokenSendingFailure.selector);
        dstClone.withdraw(SECRET, immutables.args);
    }

    function test_NoFailedNativeTokenTransferWithdrawalDstNative() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, address(escrowFactory), bob.addr, address(0x00)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT + TAKING_AMOUNT }(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        vm.expectRevert(IEscrow.NativeTokenSendingFailure.selector);
        dstClone.withdraw(SECRET, immutables.args);
    }

    function test_CancelResolverSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + 10);
        vm.prank(bob.addr);
        srcClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBob + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(alice.addr), balanceAlice + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_CancelResolverSrcReceiver() public {
        address receiver = users[2].addr;
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, receiver, true);

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
        uint256 balanceReceiver= usdc.balanceOf(receiver);
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // cancel
        vm.warp(block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + 10);
        vm.prank(bob.addr);
        srcClone.cancel(immutables);

        assertEq(bob.addr.balance, balanceBob + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(alice.addr), balanceAlice);
        assertEq(usdc.balanceOf(receiver), balanceReceiver + MAKING_AMOUNT);
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
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel + 100);
        srcClone.cancel(immutables);

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
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidCancellationTime.selector);
        srcClone.cancel(immutables);
    }

    // During non-public cancel period
    function test_NoAnyoneCancelDuringResolverCancelSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + 10);
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        srcClone.cancel(immutables);
    }

    function test_CancelDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal + 100);
        dstClone.cancel(immutables.args);

        assertEq(bob.addr.balance, balanceBobNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(bob.addr), balanceBob + TAKING_AMOUNT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - TAKING_AMOUNT);
        assertEq(address(dstClone).balance, balanceEscrowNative - DST_SAFETY_DEPOSIT);
    }

    // Only resolver can cancel
    function test_NoCancelByAnyoneDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal + 100);
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        dstClone.cancel(immutables.args);
    }

    function test_NoCancelDuringResolverWithdrawalDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidCancellationTime.selector);
        dstClone.cancel(immutables.args);
    }

    function test_NoCancelDuringPublicWithdrawalDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + 100);
        vm.expectRevert(IEscrow.InvalidCancellationTime.selector);
        dstClone.cancel(immutables.args);
    }

    function test_NoFailedNativeTokenTransferCancelSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IEscrowSrc srcClone,
            IEscrowSrc.Immutables memory immutables
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true);

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
        vm.warp(block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel + 100);
        vm.prank(address(escrowFactory));
        vm.expectRevert(IEscrow.NativeTokenSendingFailure.selector);
        srcClone.cancel(immutables);
    }

    function test_NoFailedNativeTokenTransferCancelDst() public {
        (IEscrowFactory.EscrowImmutablesCreation memory immutables, IEscrowDst dstClone) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal + 100);
        vm.mockCallRevert(bob.addr, DST_SAFETY_DEPOSIT, "", "REVERTED");
        vm.expectRevert(IEscrow.NativeTokenSendingFailure.selector);
        dstClone.cancel(immutables.args);
    }

    /* solhint-enable func-name-mixedcase */
}
