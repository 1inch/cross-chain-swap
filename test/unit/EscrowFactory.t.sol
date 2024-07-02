// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ResolverValidationExtension } from "limit-order-settlement/extensions/ResolverValidationExtension.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { EscrowDst } from "contracts/EscrowDst.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";

import { Address, AddressLib, BaseSetup, EscrowSrc, IOrderMixin } from "../utils/BaseSetup.sol";

contract EscrowFactoryTest is BaseSetup {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    uint256 public constant SECRETS_AMOUNT = 100;
    bytes32[] public hashedSecrets = new bytes32[](SECRETS_AMOUNT);
    bytes32[] public hashedPairs = new bytes32[](SECRETS_AMOUNT);
    Merkle public merkle = new Merkle();
    bytes32 public root;

    function setUp() public virtual override {
        BaseSetup.setUp();

        for (uint256 i = 0; i < SECRETS_AMOUNT; i++) {
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
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrc(
            keccak256(abi.encode(secret)),
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0),
            true, // fakeOrder
            false // allowMultipleFills
        );

        (bool success,) = address(srcClone).call{ value: srcSafetyDeposit }("");
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

        assertEq(usdc.balanceOf(address(srcClone)), srcAmount);
        assertEq(address(srcClone).balance, srcSafetyDeposit);
    }

    function testFuzz_DeployCloneForMakerWithReceiver() public {
        address receiver = charlie.addr;
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

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint56 amount) public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, EscrowDst dstClone) = _prepareDataDst(
            secret, amount, alice.addr, bob.addr, address(dai)
        );
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        uint256 safetyDeposit = uint64(amount) * 10 / 100;
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
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        usdc.transfer(address(srcClone), MAKING_AMOUNT);

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
            IBaseEscrow srcClone,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

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
            IBaseEscrow srcClone,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), true, false);

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        inch.mint(alice.addr, 10 ether);
        vm.prank(alice.addr);
        inch.approve(address(feeBank), 10 ether);
        vm.prank(alice.addr);
        feeBank.deposit(10 ether);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(ResolverValidationExtension.ResolverCanNotFillOrder.selector);
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
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        vm.warp(srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);
    }

    function test_NoInsufficientBalanceDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp);
    }

    function test_NoInsufficientBalanceNativeDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(0x00)
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

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(rootPlusAmount, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true);

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InvalidSecretsAmount.selector);
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

    function test_MultipleFillsInvalidKey() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            bytes memory extraData,
            /* bytes memory extension */,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(rootPlusAmount, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true);

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InvalidSecretIndex.selector);
        escrowFactory.postInteraction(
            order,
            "", // extension
            orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            MAKING_AMOUNT, // remainingMakingAmount
            extraData
        );
    }

    /* solhint-enable func-name-mixedcase */
}
