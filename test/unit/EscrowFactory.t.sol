// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "contracts/Escrow.sol";
import { IEscrowFactory } from "contracts/EscrowFactory.sol";

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
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(secret, srcAmount, dstAmount, true);

        (bool success, ) = address(srcClone).call{value: uint64(srcAmount) * 10 / 100}("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), srcAmount);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            srcAmount, // makingAmount
            dstAmount, // takingAmount
            0, // remainingMakingAmount
            extraData
        );

        IEscrow.SrcEscrowImmutables memory returnedImmutables = srcClone.srcEscrowImmutables();
        assertEq(returnedImmutables.extraDataParams.hashlock, keccak256(abi.encodePacked(secret)));
        assertEq(returnedImmutables.interactionParams.srcAmount, srcAmount);
        assertEq(returnedImmutables.extraDataParams.dstToken, address(dai));
    }

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint56 amount) public {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(secret, amount, alice.addr, bob.addr, address(dai));
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        uint256 safetyDeposit = uint64(amount) * 10 / 100;
        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createEscrow{value: safetyDeposit}(immutables);

        assertEq(bob.addr.balance, balanceBobNative - immutables.safetyDeposit);
        assertEq(dai.balanceOf(bob.addr), balanceBob - amount);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow + amount);
        assertEq(address(dstClone).balance, balanceEscrowNative + safetyDeposit);

        IEscrow.DstEscrowImmutables memory returnedImmutables = dstClone.dstEscrowImmutables();
        assertEq(returnedImmutables.hashlock, keccak256(abi.encodePacked(secret)));
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
            /* bytes memory extension */,
            /* Escrow srcClone */
        ) = _prepareDataSrc(secret, srcAmount, dstAmount, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            srcAmount, // makingAmount
            dstAmount, // takingAmount
            0, // remainingMakingAmount
            extraData
        );

    }

    function test_NoUnsafeDeploymentForTaker() public {

        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables,) = _prepareDataDst(SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai));

        vm.warp(immutables.srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createEscrow{value: DST_SAFETY_DEPOSIT}(immutables);
    }

    /* solhint-enable func-name-mixedcase */
}