// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ResolverValidationExtension } from "limit-order-settlement/contracts/extensions/ResolverValidationExtension.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { EscrowDst } from "contracts/EscrowDst.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract EscrowFactoryTest is BaseSetup {
    using TimelocksLib for Timelocks;

    uint256 public constant SECRETS_AMOUNT = 100;
    bytes32[] public hashedSecrets = new bytes32[](SECRETS_AMOUNT);
    bytes32[] public hashedPairs = new bytes32[](SECRETS_AMOUNT);
    Merkle public merkle = new Merkle();
    bytes32 public root;

    function setUp() public virtual override {
        BaseSetup.setUp();

        // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
        for (uint64 i = 0; i < SECRETS_AMOUNT; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMaker(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            keccak256(abi.encode(secret)),
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0),
            true, // fakeOrder
            false // allowMultipleFills
        );

        (bool success,) = address(swapData.srcClone).call{ value: srcSafetyDeposit }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), srcAmount);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            srcAmount, // makingAmount
            dstAmount, // takingAmount
            0, // remainingMakingAmount
            swapData.extraData
        );

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);
    }

    function testFuzz_DeployCloneForMakerWithReceiver() public {
        address receiver = charlie.addr;
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            HASHED_SECRET,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            SRC_SAFETY_DEPOSIT,
            DST_SAFETY_DEPOSIT,
            receiver,
            true,
            false
        );

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        IEscrowFactory.DstImmutablesComplement memory immutablesComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(receiver)),
            amount: TAKING_AMOUNT,
            token: Address.wrap(uint160(address(dai))),
            safetyDeposit: DST_SAFETY_DEPOSIT,
            chainId: block.chainid
        });

        vm.prank(address(limitOrderProtocol));
        vm.expectEmit();
        emit IEscrowFactory.SrcEscrowCreated(swapData.immutables, immutablesComplement);
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

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint56 amount) public {
        uint256 safetyDeposit = uint64(amount) * 10 / 100;
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, EscrowDst dstClone) = _prepareDataDstCustom(
            secret, amount, alice.addr, bob.addr, address(dai), safetyDeposit
        );
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectEmit();
        emit IEscrowFactory.DstEscrowCreated(address(dstClone), immutables.hashlock, Address.wrap(uint160(bob.addr)));
        escrowFactory.createDstEscrow{ value: safetyDeposit }(immutables, srcCancellationTimestamp);

        assertEq(bob.addr.balance, balanceBobNative - immutables.safetyDeposit);
        assertEq(dai.balanceOf(bob.addr), balanceBob - amount);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow + amount);
        assertEq(address(dstClone).balance, balanceEscrowNative + safetyDeposit);
    }

    function test_NoInsufficientBalanceNativeDeploymentForMaker() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
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
    }

    function test_NoInsufficientBalanceDeploymentForMaker() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
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
    }

    // Only whitelisted resolver can deploy escrow
    function test_NoDeploymentForNotResolver() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        inch.mint(alice.addr, 10 ether);
        vm.prank(alice.addr);
        inch.approve(address(feeBank), 10 ether);
        vm.prank(alice.addr);
        feeBank.deposit(10 ether);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(ResolverValidationExtension.ResolverCanNotFillOrder.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            alice.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );
    }

    function test_NoUnsafeDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst();

        vm.warp(srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);
    }

    function test_NoInsufficientBalanceDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp);
    }

    function test_NoInsufficientBalanceNativeDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDstCustom(
            HASHED_SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(0x00), DST_SAFETY_DEPOSIT
        );

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);
    }

    function test_MultipleFillsInvalidSecretsAmount() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));
        bytes32 rootPlusAmount = bytes32(uint256(0) << 240 | uint240(uint256(root)));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InvalidSecretsAmount.selector);
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
    }

    function test_MultipleFillsInvalidKey() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            MAKING_AMOUNT, // remainingMakingAmount
            swapData.extraData
        );
    }

    /* solhint-enable func-name-mixedcase */
}
