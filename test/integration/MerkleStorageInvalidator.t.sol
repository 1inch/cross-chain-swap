// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Merkle } from "murky/src/Merkle.sol";

import { IEscrow } from "contracts/interfaces/IEscrow.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IMerkleStorageInvalidator } from "contracts/interfaces/IMerkleStorageInvalidator.sol";

import { BaseSetup, EscrowSrc, IOrderMixin, TakerTraits } from "../utils/BaseSetup.sol";

contract MerkleStorageInvalidatorIntTest is BaseSetup {
    uint256 public constant SECRETS_AMOUNT = 100;

    Merkle public merkle = new Merkle();
    bytes32 public root;
    bytes32[] public hashedSecrets = new bytes32[](SECRETS_AMOUNT);
    bytes32[] public hashedPairs = new bytes32[](SECRETS_AMOUNT);

    function setUp() public virtual override {
        BaseSetup.setUp();

        for (uint256 i = 0; i < SECRETS_AMOUNT; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);
    }

    /* solhint-disable func-name-mixedcase */

    function test_MultipleFillsOneFill() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrow srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrc(rootPlusAmount, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true);

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(root, proof, idx, hashedSecrets[idx]));

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

        assertLt(feeBank.availableCredit(bob.addr), resolverCredit);
        assertEq(usdc.balanceOf(address(srcClone)), makingAmount);
    }

    function test_MultipleFillsTwoFills() public {
        uint256 makingAmount = MAKING_AMOUNT / 3;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrow srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrc(rootPlusAmount, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true);

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(root, proof, idx, hashedSecrets[idx]));

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
        idx = SECRETS_AMOUNT * (makingAmount2 + makingAmount - 1) / MAKING_AMOUNT;
        proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount2;
        address srcClone2 = address(EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables)));

        (v, r, s) = vm.sign(alice, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(root, proof, idx, hashedSecrets[idx]));

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
        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrow srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrc(rootPlusAmount, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true);

        immutables.hashlock = 0;
        uint256 makingAmount = MAKING_AMOUNT / SECRETS_AMOUNT;
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
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
        uint256 fraction = MAKING_AMOUNT / SECRETS_AMOUNT;
        uint256 makingAmount = MAKING_AMOUNT / 10 - fraction / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrow srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrc(rootPlusAmount, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, true);

        immutables.hashlock = hashedSecrets[idx];
        immutables.amount = makingAmount;
        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(escrowFactory, abi.encode(root, proof, idx, hashedSecrets[idx]));

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

        (v, r, s) = vm.sign(alice, orderHash);
        vs = bytes32((uint256(v - 27) << 255)) | s;

        interaction = abi.encodePacked(escrowFactory, abi.encode(root, proof, idx, hashedSecrets[idx]));

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

    /* solhint-enable func-name-mixedcase */
}
