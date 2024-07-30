// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { IBaseEscrow } from "../../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../../contracts/interfaces/IEscrowFactory.sol";
import { IMerkleStorageInvalidator } from "../../contracts/interfaces/IMerkleStorageInvalidator.sol";

import { BaseSetup, EscrowSrc, IOrderMixin, TakerTraits } from "../utils/BaseSetup.sol";

contract MerkleStorageInvalidatorIntTest is BaseSetup {
    uint256 public constant PARTS_AMOUNT = 100;
    uint256 public constant SECRETS_AMOUNT = PARTS_AMOUNT + 1; // 1 extra to be able to fill the whole amount

    Merkle public merkle = new Merkle();
    bytes32 public root;
    bytes32[] public hashedSecrets = new bytes32[](SECRETS_AMOUNT);
    bytes32[] public hashedPairs = new bytes32[](SECRETS_AMOUNT);
    Address public dstWithParts;
    address[] public resolvers = new address[](1);

    function setUp() public virtual override {
        BaseSetup.setUp();

        dstWithParts = Address.wrap(uint256(uint160(address(dai))) | (PARTS_AMOUNT << 240));

        for (uint256 i = 0; i < SECRETS_AMOUNT; i++) {
            // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);
        resolvers[0] = bob.addr;
    }

    /* solhint-disable func-name-mixedcase */

    function test_MultipleFillsOneFill() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = PARTS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);
    }

    function testFuzz_MultipleFillsOneFillPassAndFail(uint256 makingAmount, uint256 partsAmount, uint256 idx) public {
        makingAmount = bound(makingAmount, 1, MAKING_AMOUNT);
        partsAmount = bound(partsAmount, 2, 100);
        idx = bound(idx, 0, partsAmount);
        uint256 secretsAmount = partsAmount + 1;

        uint256 idxCalculated = partsAmount * (makingAmount - 1) / MAKING_AMOUNT;
        bool shouldFail = (idxCalculated != idx) && ((idx != partsAmount) || (makingAmount != MAKING_AMOUNT));

        bytes32[] memory hashedSecretsLocal = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairsLocal = new bytes32[](secretsAmount);

        for (uint256 i = 0; i < secretsAmount; i++) {
            hashedSecretsLocal[i] = keccak256(abi.encodePacked(i));
            hashedPairsLocal[i] = keccak256(abi.encodePacked(i, hashedSecretsLocal[i]));
        }

        root = merkle.getRoot(hashedPairsLocal);
        bytes32[] memory proof = merkle.getProof(hashedPairsLocal, idx);
        assert(merkle.verifyProof(root, proof, hashedPairsLocal[idx]));

        dstWithParts = Address.wrap(uint256(uint160(address(dai))) | (partsAmount << 240));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecretsLocal[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecretsLocal[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        if (shouldFail) {
            vm.expectRevert(IEscrowFactory.InvalidSecretIndex.selector);
        }
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        if (!shouldFail) {
            assertEq(usdc.balanceOf(address(srcClone)), makingAmount);
        }
    }

    function test_MultipleFillsTwoFills() public {
        uint256 makingAmount = MAKING_AMOUNT / 3;
        uint256 idx = PARTS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);

        // ------------ 2nd fill ------------ //
        uint256 makingAmount2 = MAKING_AMOUNT * 2 / 3 - makingAmount;
        idx = PARTS_AMOUNT * (makingAmount2 + makingAmount - 1) / MAKING_AMOUNT;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice.privateKey, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
    }

    function test_MultipleFillsNoDeploymentWithoutValidation() public {

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = 0;
        uint256 makingAmount = MAKING_AMOUNT / PARTS_AMOUNT;
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension, // extension
            "", // interaction
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidSecretIndex.selector);
        limitOrderProtocol.fillOrderArgs(
            order,
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

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);

        // ------------ 2nd fill ------------ //
        uint256 makingAmount2 = fraction / 2;
        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice.privateKey, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IMerkleStorageInvalidator.InvalidIndex.selector);
        limitOrderProtocol.fillOrderArgs(
            order,
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

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);
    }

    function test_MultipleFillsFillFirstTwoFills() public {
        uint256 idx = 0;
        uint256 makingAmount = MAKING_AMOUNT / PARTS_AMOUNT / 2;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);

        // ------------ 2nd fill ------------ //
        idx = 1;
        uint256 makingAmount2 = MAKING_AMOUNT / PARTS_AMOUNT * 3 / 2; // Fill half of the 0-th and  full of the 1-st
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice.privateKey, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(orderHash, root))
        );
        assertEq(storedIndex, idx + 1);
    }

    function test_MultipleFillsFillLast() public {
        uint256 idx = PARTS_AMOUNT - 1;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            MAKING_AMOUNT, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
    }

    function test_MultipleFillsFillAllTwoFills() public {
        uint256 idx = PARTS_AMOUNT - 2;
        uint256 makingAmount = MAKING_AMOUNT * (idx + 1) / PARTS_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);

        // ------------ 2nd fill ------------ //
        idx = PARTS_AMOUNT - 1;
        uint256 makingAmount2 = MAKING_AMOUNT - makingAmount;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice.privateKey, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(orderHash, root))
        );
        assertEq(storedIndex, PARTS_AMOUNT);
    }

    function test_MultipleFillsFillAllExtra() public {
        uint256 idx = PARTS_AMOUNT - 1;
        uint256 makingAmount2 = 10;
        uint256 makingAmount = MAKING_AMOUNT * (idx + 1) / PARTS_AMOUNT - makingAmount2;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(orderHash, root))
        );
        assertEq(storedIndex, PARTS_AMOUNT);

        // ------------ 2nd fill ------------ //
        idx = PARTS_AMOUNT;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice.privateKey, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );

        assertEq(usdc.balanceOf(address(srcClone2)), makingAmount2);
        (storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(orderHash, root))
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
        for (uint256 i = 0; i < secretsAmount; i++) {
            hashedS[i] = keccak256(abi.encodePacked(i));
            hashedP[i] = keccak256(abi.encodePacked(i, hashedS[i]));
        }
        root = merkle.getRoot(hashedP);
        bytes32[] memory proof = merkle.getProof(hashedP, idx);
        assert(merkle.verifyProof(root, proof, hashedP[idx]));

        dstWithParts = Address.wrap(uint256(uint160(address(dai))) | (secretsAmount << 240));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, makingAmount, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedS[idx];
        immutables.amount = makingAmountToFill;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedS[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmountToFill, // amount
            takerTraits,
            args
        );

        assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(address(srcClone)), makingAmountToFill);
    }

    function test_MultipleFillsNoReuseOfSecrets() public {
        uint256 idx = 0;
        uint256 onePart = MAKING_AMOUNT / PARTS_AMOUNT;
        uint256 makingAmount = onePart / 2 - 1;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            /* IBaseEscrow srcClone */,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        address srcClone = escrowFactory.addressOfEscrowSrc(immutables);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            extension,
            interaction,
            0 // threshold
        );

        (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);


        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount, // amount
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(srcClone), makingAmount);
        (uint256 storedIndex,) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(orderHash, root))
        );
        assertEq(storedIndex, idx + 1);

        // ------------ 2nd fill ------------ //
        uint256 makingAmount2 = makingAmount + 1;
        bytes32[] memory hashedSecretsLocal = new bytes32[](SECRETS_AMOUNT);
        bytes32[] memory hashedPairsLocal = new bytes32[](SECRETS_AMOUNT);
        for (uint256 i = 0; i < SECRETS_AMOUNT; i++) {
            hashedSecretsLocal[i] = keccak256(abi.encodePacked(keccak256(abi.encodePacked(i))));
            hashedPairsLocal[i] = keccak256(abi.encodePacked(i, hashedSecretsLocal[i]));
        }
        bytes32 rootLocal = merkle.getRoot(hashedPairsLocal);

        bytes32[] memory proofLocal = merkle.getProof(hashedPairsLocal, idx);
        assert(merkle.verifyProof(rootLocal, proofLocal, hashedPairsLocal[idx]));

        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice.privateKey, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(proofLocal, idx + 1, hashedSecretsLocal[idx]));

        (TakerTraits takerTraits2, bytes memory args2) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone2, // target
            extension,
            interaction,
            0 // threshold
        );

        (success,) = srcClone2.call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IMerkleStorageInvalidator.InvalidProof.selector);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            makingAmount2, // amount
            takerTraits2,
            args2
        );
    }

    /* solhint-enable func-name-mixedcase */
}
