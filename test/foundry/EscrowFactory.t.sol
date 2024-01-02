// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Escrow, IEscrow } from "../../contracts/Escrow.sol";
import { IEscrowFactory } from "../../contracts/EscrowFactory.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";

contract EscrowFactoryTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint256 amount) public {
        vm.assume(amount > 0.1 ether && amount < 1 ether);
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
            Escrow dstClone
        ) = _prepareDataDst(secret, amount);
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

    function test_NoUnsafeDeploymentForTaker() public {

        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables,) = _prepareDataDst(SECRET, TAKING_AMOUNT);

        vm.warp(immutables.srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createEscrow(immutables);
    }

    /* solhint-enable func-name-mixedcase */
}
