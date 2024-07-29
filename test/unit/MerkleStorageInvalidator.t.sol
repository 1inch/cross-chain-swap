// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Merkle } from "murky/src/Merkle.sol";

import { ITakerInteraction } from "limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";

import { IMerkleStorageInvalidator } from "../../contracts/interfaces/IMerkleStorageInvalidator.sol";

import { Address, BaseSetup, IOrderMixin } from "../utils/BaseSetup.sol";

contract MerkleStorageInvalidatorTest is BaseSetup {

    Merkle public merkle = new Merkle();
    bytes32 public root;
    address[] public resolvers = new address[](1);
    Address public dstWithParts;

    function setUp() public virtual override {
        BaseSetup.setUp();
        resolvers[0] = bob.addr;
        dstWithParts = Address.wrap(uint160(address(dai)));
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_ValidateProof(uint256 secretsAmount, uint256 idx) public {
        secretsAmount = bound(secretsAmount, 2, 1000);
        idx = bound(idx, 0, secretsAmount - 1);
        bytes32[] memory hashedSecrets = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairs = new bytes32[](secretsAmount);

        for (uint256 i = 0; i < secretsAmount; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);

        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            /* IBaseEscrow srcClone */,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        vm.prank(address(limitOrderProtocol));
        ITakerInteraction(escrowFactory).takerInteraction(
            order,
            extension,
            orderHash,
            bob.addr,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0,
            abi.encode(proof, idx, hashedSecrets[idx])
        );
        (uint256 storedIndex, bytes32 storedLeaf) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(orderHash, root))
        );
        assertEq(storedIndex, idx + 1);
        assertEq(storedLeaf, hashedSecrets[idx]);
    }

    function testFuzz_NoInvalidProofValidation(uint256 secretsAmount, uint256 idx) public {
        secretsAmount = bound(secretsAmount, 2, 1000);
        idx = bound(idx, 0, secretsAmount - 1);
        bytes32[] memory hashedSecrets = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairs = new bytes32[](secretsAmount);

        for (uint256 i = 0; i < secretsAmount; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);

        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            /* IBaseEscrow srcClone */,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrcCustom(
            root, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, dstWithParts, address(0), false, true, resolvers
        );

        uint256 wrongIndex = idx + 1 < secretsAmount ? idx + 1 : idx - 1;

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IMerkleStorageInvalidator.InvalidProof.selector);
        ITakerInteraction(escrowFactory).takerInteraction(
            order,
            extension,
            orderHash,
            bob.addr,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0,
            abi.encode(proof, wrongIndex, hashedSecrets[wrongIndex])
        );
    }

    /* solhint-enable func-name-mixedcase */
}
