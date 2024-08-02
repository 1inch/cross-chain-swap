// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Merkle } from "murky/src/Merkle.sol";

import { ITakerInteraction } from "limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";

import { IMerkleStorageInvalidator } from "contracts/interfaces/IMerkleStorageInvalidator.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract MerkleStorageInvalidatorTest is BaseSetup {

    Merkle public merkle = new Merkle();
    bytes32 public root;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_ValidateProof(uint256 secretsAmount, uint256 idx) public {
        secretsAmount = bound(secretsAmount, 2, 1000);
        idx = bound(idx, 0, secretsAmount - 1);
        bytes32[] memory hashedSecrets = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairs = new bytes32[](secretsAmount);

        // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
        for (uint64 i = 0; i < secretsAmount; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);

        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(root, false, true);

        vm.prank(address(limitOrderProtocol));
        ITakerInteraction(escrowFactory).takerInteraction(
            swapData.order,
            swapData.extension,
            swapData.orderHash,
            bob.addr,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0,
            abi.encode(proof, idx, hashedSecrets[idx])
        );
        (uint256 storedIndex, bytes32 storedLeaf) = IMerkleStorageInvalidator(escrowFactory).lastValidated(
            keccak256(abi.encodePacked(swapData.orderHash, uint240(uint256(root))))
        );
        assertEq(storedIndex, idx + 1);
        assertEq(storedLeaf, hashedSecrets[idx]);
    }

    function testFuzz_NoInvalidProofValidation(uint256 secretsAmount, uint256 idx) public {
        secretsAmount = bound(secretsAmount, 2, 1000);
        idx = bound(idx, 0, secretsAmount - 1);
        bytes32[] memory hashedSecrets = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairs = new bytes32[](secretsAmount);

        // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
        for (uint64 i = 0; i < secretsAmount; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);

        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(root, false, true);

        uint256 wrongIndex = idx + 1 < secretsAmount ? idx + 1 : idx - 1;

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IMerkleStorageInvalidator.InvalidProof.selector);
        ITakerInteraction(escrowFactory).takerInteraction(
            swapData.order,
            swapData.extension,
            swapData.orderHash,
            bob.addr,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0,
            abi.encode(proof, wrongIndex, hashedSecrets[wrongIndex])
        );
    }

    function test_ShortenedProofIsNotValid() public {
        uint256 secretsAmount = 8;
        uint256 idx = 0;

        bytes32[] memory hashedSecrets = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairs = new bytes32[](secretsAmount);

        // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
        for (uint64 i = 0; i < secretsAmount; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);

        // Valid proof
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);

        // Calculate the intermediate node to pass as a value
        bytes32 firstInterNode = merkle.hashLeafPairs(hashedPairs[idx], proof[0]);

        (uint256 fakeIdx, bytes32 fakeSecretHash) =
            uint256(firstInterNode) > uint256(proof[1]) ? (uint256(proof[1]), firstInterNode) : (uint256(firstInterNode), proof[1]);

        bytes32[] memory shortenedProof = new bytes32[](1);
        shortenedProof[0] = proof[proof.length - 1];

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(root, false, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IMerkleStorageInvalidator.InvalidProof.selector);
        ITakerInteraction(escrowFactory).takerInteraction(
            swapData.order,
            swapData.extension,
            swapData.orderHash,
            bob.addr,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0,
            abi.encode(shortenedProof, fakeIdx, fakeSecretHash)
        );
    }

    /* solhint-enable func-name-mixedcase */
}
