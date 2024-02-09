// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { SimpleSettlementExtension } from "limit-order-settlement/SimpleSettlementExtension.sol";

import { Escrow, IEscrow } from "contracts/Escrow.sol";
import { IEscrowFactory } from "contracts/EscrowFactory.sol";
import { PackedAddresses, PackedAddressesMemLib } from "../utils/libraries/PackedAddressesMemLib.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

import { Address, AddressLib, BaseSetup, IOrderMixin } from "../utils/BaseSetup.sol";

contract EscrowFactoryTest is BaseSetup {
    using AddressLib for Address;
    using PackedAddressesMemLib for PackedAddresses;
    using TimelocksLib for Timelocks;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMaker(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(secret, srcAmount, dstAmount, true);

        (bool success,) = address(srcClone).call{ value: uint64(srcAmount) * 10 / 100 }("");
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
        assertEq(returnedImmutables.orderHash, orderHash);
        assertEq(returnedImmutables.hashlock, keccak256(abi.encodePacked(secret)));
        assertEq(returnedImmutables.srcAmount, srcAmount);
        assertEq(returnedImmutables.dstToken.get(), address(dai));
        assertEq(returnedImmutables.packedAddresses.maker(), alice.addr);
        assertEq(returnedImmutables.packedAddresses.taker(), bob.addr);
        assertEq(returnedImmutables.packedAddresses.token(), address(usdc));
        assertEq(returnedImmutables.timelocks.srcWithdrawalStart(), block.timestamp + srcTimelocks.finality);
        assertEq(returnedImmutables.timelocks.srcCancellationStart(), block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal);
        assertEq(
            returnedImmutables.timelocks.srcPubCancellationStart(),
            block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal + srcTimelocks.cancel
        );
        assertEq(returnedImmutables.timelocks.dstWithdrawalStart(), block.timestamp + dstTimelocks.finality);
        assertEq(returnedImmutables.timelocks.dstPubWithdrawalStart(), block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal);
        assertEq(
            returnedImmutables.timelocks.dstCancellationStart(),
            block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal
        );
    }

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint56 amount) public {
        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables, Escrow dstClone) = _prepareDataDst(
            secret, amount, alice.addr, bob.addr, address(dai)
        );
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        uint256 safetyDeposit = uint64(amount) * 10 / 100;
        // deploy escrow
        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: safetyDeposit }(immutables);

        assertEq(bob.addr.balance, balanceBobNative - immutables.args.safetyDeposit);
        assertEq(dai.balanceOf(bob.addr), balanceBob - amount);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow + amount);
        assertEq(address(dstClone).balance, balanceEscrowNative + safetyDeposit);

        IEscrow.DstEscrowImmutables memory returnedImmutables = dstClone.dstEscrowImmutables();
        assertEq(returnedImmutables.orderHash, bytes32(block.timestamp));
        assertEq(returnedImmutables.hashlock, keccak256(abi.encodePacked(secret)));
        assertEq(returnedImmutables.amount, amount);
        assertEq(returnedImmutables.packedAddresses.maker(), alice.addr);
        assertEq(returnedImmutables.packedAddresses.taker(), bob.addr);
        assertEq(returnedImmutables.packedAddresses.token(), address(dai));
        assertEq(returnedImmutables.timelocks.dstWithdrawalStart(), block.timestamp + dstTimelocks.finality);
        assertEq(returnedImmutables.timelocks.dstPubWithdrawalStart(), block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal);
        assertEq(
            returnedImmutables.timelocks.dstCancellationStart(),
            block.timestamp + dstTimelocks.finality + dstTimelocks.withdrawal + dstTimelocks.publicWithdrawal
        );
    }

    function test_NoInsufficientBalanceNativeDeploymentForMaker() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            /* Escrow srcClone */
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
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
    }

    function test_NoInsufficientBalanceDeploymentForMaker() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
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
    }

    // Only whitelisted resolver can deploy escrow
    function test_NoDeploymentForNotResolver() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, true);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(SimpleSettlementExtension.ResolverIsNotWhitelisted.selector);
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            alice.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            extraData
        );
    }

    function test_NoUnsafeDeploymentForTaker() public {
        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables,) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        vm.warp(immutables.srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);
    }

    function test_NoInsufficientBalanceDeploymentForTaker() public {
        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables,) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow(immutables);
    }

    function test_NoInsufficientBalanceNativeDeploymentForTaker() public {
        (IEscrowFactory.DstEscrowImmutablesCreation memory immutables,) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(0x00)
        );

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables);
    }

    /* solhint-enable func-name-mixedcase */
}
