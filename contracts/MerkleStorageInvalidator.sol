// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { ITakerInteraction } from "limit-order-protocol/interfaces/ITakerInteraction.sol";
import { MerkleProof } from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

import { IMerkleStorageInvalidator } from "contracts/interfaces/IMerkleStorageInvalidator.sol";

/**
 * @title Merkle Storage Invalidator contract
 * @notice Contract to invalidate hashed secrets from an order that supports multiple fills.
 */
contract MerkleStorageInvalidator is IMerkleStorageInvalidator, ITakerInteraction {
    using MerkleProof for bytes32[];

    address internal immutable _LIMIT_ORDER_PROTOCOL;

    /// @notice See {IMerkleStorageInvalidator-lastValidated}.
    mapping(bytes32 => LastValidated) public lastValidated;

    /// @notice Only limit order protocol can call this contract.
    modifier onlyLOP() {
        if (msg.sender != _LIMIT_ORDER_PROTOCOL) {
            revert AccessDenied();
        }
        _;
    }

    constructor(address limitOrderProtocol) {
        _LIMIT_ORDER_PROTOCOL = limitOrderProtocol;
    }

    /**
     * @notice See {ITakerInteraction-takerInteraction}.
     * @dev Verifies the proof and stores the last validated index and hashed secret.
     * Only Limit Order Protocol can call this function.
     */
    function takerInteraction(
        IOrderMixin.Order calldata /* order */,
        bytes calldata /* extension */,
        bytes32 orderHash,
        address /* taker */,
        uint256 /* makingAmount */,
        uint256 /* takingAmount */,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external onlyLOP {
        (
            bytes32 root,
            bytes32[] memory proof,
            uint256 idx,
            bytes32 secretHash
        ) = abi.decode(extraData, (bytes32, bytes32[], uint256, bytes32));
        bytes32 key = keccak256(abi.encodePacked(orderHash, uint240(uint256(root))));
        if (idx < lastValidated[key].index) revert InvalidIndex();
        if (!proof.verify(root, keccak256(abi.encodePacked(idx, secretHash)))) revert InvalidProof();
        lastValidated[key] = LastValidated(idx + 1, secretHash);
    }
}
