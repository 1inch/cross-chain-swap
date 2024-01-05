// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "../../contracts/Escrow.sol";
import { IEscrowFactory } from "../../contracts/EscrowFactory.sol";

import { BaseSetup, IOrderMixin } from "../utils/BaseSetup.sol";

contract EscrowFactoryTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMaker(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            Escrow srcClone
        ) = _prepareDataSrc(secret, srcAmount, dstAmount);

        usdc.transfer(address(srcClone), srcAmount);

        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob, // taker
            srcAmount, // makingAmount
            dstAmount, // takingAmount
            0, // remainingMakingAmount
            extraData
        );

        IEscrow.SrcEscrowImmutables memory returnedImmutables = srcClone.srcEscrowImmutables();
        assertEq(returnedImmutables.extraDataParams.hashlock, uint256(keccak256(abi.encodePacked(secret))));
        assertEq(returnedImmutables.interactionParams.srcAmount, srcAmount);
        assertEq(returnedImmutables.extraDataParams.dstToken, address(dai));
    }

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint56 amount) public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(secret, amount, alice, bob, address(dai));
        uint256 balanceBob = dai.balanceOf(bob);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));

        // deploy escrow
        vm.prank(bob);
        escrowFactory.createEscrow(immutables);

        assertEq(dai.balanceOf(bob), balanceBob - (amount + immutables.safetyDeposit));
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow + amount + immutables.safetyDeposit);

        IEscrow.DstEscrowImmutables memory returnedImmutables = dstClone.dstEscrowImmutables();
        assertEq(returnedImmutables.hashlock, uint256(keccak256(abi.encodePacked(secret))));
        assertEq(returnedImmutables.amount, amount);
    }

    function testFuzz_NoInsufficientBalanceDeploymentForMaker(
        bytes32 secret,
        uint56 srcAmount,
        uint56 dstAmount
    ) public {
        vm.assume(srcAmount > 0);
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* Escrow srcClone */
        ) = _prepareDataSrc(secret, srcAmount, dstAmount);

        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob, // taker
            srcAmount, // makingAmount
            dstAmount, // takingAmount
            0, // remainingMakingAmount
            extraData
        );

    }

    function test_NoUnsafeDeploymentForTaker() public {

        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables,) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice, bob, address(dai));

        vm.warp(immutables.srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createEscrow(immutables);
    }

    /* solhint-enable func-name-mixedcase */
}
