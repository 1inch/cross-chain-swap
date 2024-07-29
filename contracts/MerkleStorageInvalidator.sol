// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { ITakerInteraction } from "limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IMerkleStorageInvalidator } from "./interfaces/IMerkleStorageInvalidator.sol";
import { EscrowFactoryContext } from "./EscrowFactoryContext.sol";

/**
 * @title Merkle Storage Invalidator contract
 * @notice Contract to invalidate hashed secrets from an order that supports multiple fills.
 */
contract MerkleStorageInvalidator is IMerkleStorageInvalidator, EscrowFactoryContext, ITakerInteraction {
    using MerkleProof for bytes32[];

    address private immutable _LIMIT_ORDER_PROTOCOL;

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
        bytes calldata extension,
        bytes32 orderHash,
        address /* taker */,
        uint256 /* makingAmount */,
        uint256 /* takingAmount */,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external onlyLOP {
        IEscrowFactory.ExtraDataArgs calldata extraDataArgs;
        assembly ("memory-safe") {
            let offsets := calldataload(extension.offset)
            let bitShift := mul(7, 32) // 7 is index of PostInteractionData in ExtensionLib.DynamicField
            let end := and(0xffffffff, shr(bitShift, offsets)) // Get the end of PostInteractionData
            // Skip the first 32 bytes of the extension containing offsets
            extraDataArgs := add(add(extension.offset, 32), sub(end, _SRC_IMMUTABLES_LENGTH))
        }
        bytes32 root = extraDataArgs.hashlockInfo;
        (
            bytes32[] memory proof,
            uint256 idx,
            bytes32 secretHash
        ) = abi.decode(extraData, (bytes32[], uint256, bytes32));
        bytes32 key = keccak256(abi.encodePacked(orderHash, root));
        if (idx < lastValidated[key].index) revert InvalidIndex();
        if (!proof.verify(root, keccak256(abi.encodePacked(idx, secretHash)))) revert InvalidProof();
        lastValidated[key] = LastValidated(idx + 1, secretHash);
    }
}
