// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "contracts/Escrow.sol";
import { IEscrowFactory } from "contracts/EscrowFactory.sol";

import { BaseSetup, IOrderMixin } from "../utils/BaseSetup.sol";

contract EscrowTest is BaseSetup {
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant WRONG_SECRET = keccak256(abi.encodePacked("wrong secret"));

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */
    function test_NoWithdrawalDuringFinalityLockSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

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
        vm.expectRevert(IEscrow.InvalidWithdrawalTime.selector);
        srcClone.withdrawSrc(SECRET);
    }

    function test_NoWithdrawalDuringFinalityLockDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createEscrow(immutables);

        // withdraw
        vm.expectRevert(IEscrow.InvalidWithdrawalTime.selector);
        dstClone.withdrawDst(SECRET);
    }

    function test_WithdrawSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

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
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // withdraw
        vm.warp(block.timestamp + srcTimelocks.finality + 100);
        srcClone.withdrawSrc(SECRET);

        assertEq(usdc.balanceOf(bob.addr), balanceBob + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_WithdrawByResolverDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createEscrow(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdrawDst(SECRET);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(dai.balanceOf(bob.addr), balanceBob + SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - (TAKING_AMOUNT + SAFETY_DEPOSIT));
    }

    function test_NoWithdrawalWithWrongSecretSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

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
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        srcClone.withdrawSrc(WRONG_SECRET);
    }

    function test_NoWithdrawalWithWrongSecretDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createEscrow(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        dstClone.withdrawDst(WRONG_SECRET);
    }

    // During non-public unlock period
    function test_NoWithdrawalByNonResolvertDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createEscrow(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        dstClone.withdrawDst(SECRET);
    }

    // During public unlock period
    function test_WithdrawByAnyonetDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createEscrow(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceThis = dai.balanceOf(address(this));
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.unlock + 100);
        dstClone.withdrawDst(SECRET);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(dai.balanceOf(address(this)), balanceThis + SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - (TAKING_AMOUNT + SAFETY_DEPOSIT));
    }

    // During public unlock period
    function test_WithdrawByResolverPublicDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.startPrank(bob.addr);
        escrowFactory.createEscrow(immutables);

        uint256 balanceAlice = dai.balanceOf(alice.addr);
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.unlock + 100);
        dstClone.withdrawDst(SECRET);

        assertEq(dai.balanceOf(alice.addr), balanceAlice + TAKING_AMOUNT);
        assertEq(dai.balanceOf(bob.addr), balanceBob + SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - (TAKING_AMOUNT + SAFETY_DEPOSIT));
    }

    function test_CancelSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

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

        uint256 balanceAlice = usdc.balanceOf(alice.addr);
        uint256 balanceEscrow = usdc.balanceOf(address(srcClone));

        // cancel
        vm.warp(block.timestamp + srcTimelocks.finality + srcTimelocks.publicUnlock + 100);
        srcClone.cancelSrc();

        assertEq(usdc.balanceOf(alice.addr), balanceAlice + MAKING_AMOUNT);
        assertEq(usdc.balanceOf(address(srcClone)), balanceEscrow - (MAKING_AMOUNT));
    }

    function test_NoCancelDuringUnlockSrc() public {
        // deploy escrow
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

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
        srcClone.cancelSrc();
    }

    function test_CancelDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createEscrow(immutables);

        uint256 balanceThis = dai.balanceOf(address(this));
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.unlock + dstTimelocks.publicUnlock + 100);
        dstClone.cancelDst();

        assertEq(dai.balanceOf(address(this)), balanceThis + SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(bob.addr), balanceBob + TAKING_AMOUNT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - (TAKING_AMOUNT + SAFETY_DEPOSIT));
    }

    function test_NoCancelDuringResolverUnlockDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createEscrow(immutables);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidCancellationTime.selector);
        dstClone.cancelDst();
    }

    function test_NoCancelDuringPublicUnlockDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createEscrow(immutables);

        // cancel
        vm.warp(block.timestamp + dstTimelocks.finality + dstTimelocks.unlock + 100);
        vm.expectRevert(IEscrow.InvalidCancellationTime.selector);
        dstClone.cancelDst();
    }

    /* solhint-enable func-name-mixedcase */
}
