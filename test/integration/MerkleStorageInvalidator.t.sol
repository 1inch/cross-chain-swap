// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IMerkleStorageInvalidator } from "contracts/interfaces/IMerkleStorageInvalidator.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract MerkleStorageInvalidatorIntTest is BaseSetup {
    uint256 public constant PARTS_AMOUNT = 100;
    uint256 public constant SECRETS_AMOUNT = PARTS_AMOUNT + 1; // 1 extra to be able to fill the whole amount

    Merkle public merkle = new Merkle();
    bytes32 public root;
    bytes32[] public hashedSecrets = new bytes32[](SECRETS_AMOUNT);
    bytes32[] public hashedPairs = new bytes32[](SECRETS_AMOUNT);
    bytes32 public rootPlusAmount;

    function setUp() public virtual override {
        BaseSetup.setUp();

        for (uint64 i = 0; i < SECRETS_AMOUNT; i++) {
            // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);
        rootPlusAmount = bytes32(PARTS_AMOUNT << 240 | uint240(uint256(root)));
    }

    /* solhint-disable func-name-mixedcase */

    function test_MultipleFillsOneFill() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = PARTS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(srcClone), makingAmount);
    }

    function _isValidPartialFill(
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        uint256 orderMakingAmount,
        uint256 partsAmount,
        uint256 validatedIndex
    ) internal pure returns (bool) {
        uint256 calculatedIndex = (orderMakingAmount - remainingMakingAmount + makingAmount - 1) * partsAmount / orderMakingAmount;

        if (remainingMakingAmount == makingAmount) {
            // The last secret must be used for the last fill.
            return (calculatedIndex + 2 == validatedIndex);
        } else if (orderMakingAmount != remainingMakingAmount) {
            // Calculate the previous fill index only if this is not the first fill.
            uint256 prevCalculatedIndex = (orderMakingAmount - remainingMakingAmount - 1) * partsAmount / orderMakingAmount;
            if (calculatedIndex == prevCalculatedIndex) return false;
        }

        return calculatedIndex + 1 == validatedIndex;
    }

    function testFuzz_MultipleFillsOneFillPassAndFail(uint256 makingAmount, uint256 partsAmount, uint256 idx) public {
        makingAmount = bound(makingAmount, 1, MAKING_AMOUNT);
        partsAmount = bound(partsAmount, 2, 100);
        idx = bound(idx, 0, partsAmount);
        uint256 secretsAmount = partsAmount + 1;

        bool shouldFail = !_isValidPartialFill(makingAmount, MAKING_AMOUNT, MAKING_AMOUNT, partsAmount, idx + 1);

        bytes32[] memory hashedSecretsLocal = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairsLocal = new bytes32[](secretsAmount);

        for (uint64 i = 0; i < secretsAmount; i++) {
            hashedSecretsLocal[i] = keccak256(abi.encodePacked(i));
            hashedPairsLocal[i] = keccak256(abi.encodePacked(i, hashedSecretsLocal[i]));
        }

        root = merkle.getRoot(hashedPairsLocal);
        bytes32[] memory proof = merkle.getProof(hashedPairsLocal, idx);
        assert(merkle.verifyProof(root, proof, hashedPairsLocal[idx]));

        rootPlusAmount = bytes32(partsAmount << 240 | uint240(uint256(root)));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecretsLocal[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecretsLocal[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        if (shouldFail) {
            vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        }
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        if (!shouldFail) {
            assertEq(usdc.balanceOf(srcClone), makingAmount);
        }
    }

    function test_MultipleFillsTwoFills() public {
        uint256 makingAmount = MAKING_AMOUNT / 3;
        uint256 idx = PARTS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);

        // ------------ 2nd fill ------------ //
        uint256 makingAmount2 = MAKING_AMOUNT * 2 / 3 - makingAmount;
        idx = PARTS_AMOUNT * (makingAmount2 + makingAmount - 1) / MAKING_AMOUNT;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
    }

    function test_MultipleFillsNoDeploymentWithoutValidation() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = 0;
        uint256 makingAmount = MAKING_AMOUNT / PARTS_AMOUNT;
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension, // extension
            "", // interaction
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );
    }

    function test_MultipleFillsNoSecondDeploymentWithTheSameIndex() public {
        uint256 fraction = MAKING_AMOUNT / PARTS_AMOUNT;
        uint256 makingAmount = MAKING_AMOUNT / 10 - fraction / 2;
        uint256 idx = PARTS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);

        // ------------ 2nd fill ------------ //
        uint256 makingAmount2 = fraction / 2;
        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );
    }

    function test_MultipleFillsFillFirst() public {
        uint256 idx = 0;
        uint256 makingAmount = MAKING_AMOUNT / PARTS_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(srcClone), makingAmount);
    }

    function test_MultipleFillsFillFirstTwoFills() public {
        uint256 idx = 0;
        uint256 makingAmount = MAKING_AMOUNT / PARTS_AMOUNT / 2;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(srcClone), makingAmount);

        // ------------ 2nd fill ------------ //
        idx = 1;
        uint256 makingAmount2 = MAKING_AMOUNT / PARTS_AMOUNT * 3 / 2; // Fill half of the 0-th and  full of the 1-st
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, idx + 1);
    }

    function test_MultipleFillsFillLast() public {
        uint256 idx = PARTS_AMOUNT; // Use the "extra" secret
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(srcClone), MAKING_AMOUNT);
    }

    function test_MultipleFillsFillAllFromLast() public {
        uint256 idx = PARTS_AMOUNT - 1;
        uint256 makingAmount = MAKING_AMOUNT - 1;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);

        // ------------ 2nd fill ------------ //
        idx = PARTS_AMOUNT; // Use the "extra" secret
        uint256 makingAmount2 = MAKING_AMOUNT - makingAmount;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, PARTS_AMOUNT + 1);
    }

    function test_MultipleFillsFillAllTwoFills() public {
        uint256 idx = PARTS_AMOUNT - 2;
        uint256 makingAmount = MAKING_AMOUNT * (idx + 1) / PARTS_AMOUNT - 1;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);

        // ------------ 2nd fill ------------ //
        idx = PARTS_AMOUNT; // Use the "extra" secret
        uint256 makingAmount2 = MAKING_AMOUNT - makingAmount;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, PARTS_AMOUNT + 1);
    }

    function test_MultipleFillsFillAllExtra() public {
        uint256 idx = PARTS_AMOUNT - 1;
        uint256 makingAmount2 = 10;
        uint256 makingAmount = MAKING_AMOUNT * (idx + 1) / PARTS_AMOUNT - makingAmount2;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, PARTS_AMOUNT);

        // ------------ 2nd fill ------------ //
        idx = PARTS_AMOUNT;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, SECRETS_AMOUNT);
    }

    function test_MultipleFillsOddDivision() public {
        uint256 secretsAmount = 8;
        uint256 makingAmount = 135;
        uint256 makingAmountToFill = makingAmount / 2;
        uint256 idx = secretsAmount * (makingAmountToFill - 1) / makingAmount;
        bytes32[] memory hashedS = new bytes32[](secretsAmount);
        bytes32[] memory hashedP = new bytes32[](secretsAmount);
        for (uint64 i = 0; i < secretsAmount; i++) {
            hashedS[i] = keccak256(abi.encodePacked(i));
            hashedP[i] = keccak256(abi.encodePacked(i, hashedS[i]));
        }
        root = merkle.getRoot(hashedP);
        bytes32[] memory proof = merkle.getProof(hashedP, idx);
        assert(merkle.verifyProof(root, proof, hashedP[idx]));

        rootPlusAmount = bytes32(secretsAmount << 240 | uint240(uint256(root)));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            rootPlusAmount, makingAmount, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true
        );

        swapData.immutables.hashlock = hashedS[idx];
        swapData.immutables.amount = makingAmountToFill;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedS[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmountToFill, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(srcClone), makingAmountToFill);
    }

    function test_MultipleFillsNoReuseOfSecrets() public {
        uint256 idx = 0;
        uint256 onePart = MAKING_AMOUNT / PARTS_AMOUNT;
        uint256 makingAmount = onePart / 2 - 1;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, idx + 1);

        // ------------ 2nd fill, forged proof ------------ //
        uint256 makingAmount2 = makingAmount + 1;
        bytes32[] memory hashedSecretsLocal = new bytes32[](SECRETS_AMOUNT);
        bytes32[] memory hashedPairsLocal = new bytes32[](SECRETS_AMOUNT);
        for (uint64 i = 0; i < SECRETS_AMOUNT; i++) {
            hashedSecretsLocal[i] = keccak256(abi.encodePacked(keccak256(abi.encodePacked(i))));
            hashedPairsLocal[i] = keccak256(abi.encodePacked(i, hashedSecretsLocal[i]));
        }
        bytes32 rootLocal = merkle.getRoot(hashedPairsLocal);

        bytes32[] memory proofLocal = merkle.getProof(hashedPairsLocal, idx);
        assert(merkle.verifyProof(rootLocal, proofLocal, hashedPairsLocal[idx]));

        swapData.immutables.amount = makingAmount2;
        address srcClone2 = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (v, r, s) = vm.sign(alice.privateKey, swapData.orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proofLocal, idx + 1, hashedSecretsLocal[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IMerkleStorageInvalidator.InvalidProof.selector);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        // ------------ 2nd fill, no taker interaction ------------ //
        (TakerTraits takerTraits3, bytes memory args3) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            swapData.extension,
            "", // interaction
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits3,
            args3
        );
    }

    /* solhint-enable func-name-mixedcase */
}
