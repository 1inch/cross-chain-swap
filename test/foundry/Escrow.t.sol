// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "../../contracts/Escrow.sol";
import { IEscrowFactory } from "../../contracts/EscrowFactory.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";

contract EscrowTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function test_NoWithdrawalDuringFinalityLockDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT);

        // deploy escrow
        vm.startPrank(bob);
        escrowFactory.createEscrow(immutables);

        // withdraw
        vm.expectRevert(IEscrow.InvalidWithdrawalTime.selector);
        dstClone.withdrawDst(SECRET);
    }

    function test_WithdrawByResolverDst() public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT);

        // deploy escrow
        vm.startPrank(bob);
        escrowFactory.createEscrow(immutables);

        uint256 balanceAlice = dai.balanceOf(alice);
        uint256 balanceBob = dai.balanceOf(bob);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 10);
        dstClone.withdrawDst(SECRET);

        assertEq(dai.balanceOf(alice), balanceAlice + TAKING_AMOUNT);
        assertEq(dai.balanceOf(bob), balanceBob + SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow - (TAKING_AMOUNT + SAFETY_DEPOSIT));
    }

    function test_NoWithdrawalWithWrongSecretDst() public {
        bytes32 wrongSecret = keccak256(abi.encodePacked("wrong secret"));

        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(SECRET, TAKING_AMOUNT);

        // deploy escrow
        vm.startPrank(bob);
        escrowFactory.createEscrow(immutables);

        // withdraw
        vm.warp(block.timestamp + dstTimelocks.finality + 100);
        vm.expectRevert(IEscrow.InvalidSecret.selector);
        dstClone.withdrawDst(wrongSecret);
    }

    /* solhint-enable func-name-mixedcase */
}
