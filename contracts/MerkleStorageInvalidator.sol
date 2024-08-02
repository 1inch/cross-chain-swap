// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { ExtensionLib } from "limit-order-protocol/contracts/libraries/ExtensionLib.sol";
import { ITakerInteraction } from "limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IMerkleStorageInvalidator } from "./interfaces/IMerkleStorageInvalidator.sol";
import { SRC_IMMUTABLES_LENGTH } from "./EscrowFactoryContext.sol"; // solhint-disable-line no-unused-import

/**
 * @title Merkle Storage Invalidator contract
 * @notice Contract to invalidate hashed secrets from an order that supports multiple fills.
 * @custom:security-contact security@1inch.io
 */
contract MerkleStorageInvalidator is IMerkleStorageInvalidator, ITakerInteraction {
    using MerkleProof for bytes32[];
    using ExtensionLib for bytes;

    address private immutable _LIMIT_ORDER_PROTOCOL;

    /// @notice See {IMerkleStorageInvalidator-lastValidated}.
    mapping(bytes32 key => ValidationData) public lastValidated;

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
        bytes calldata postInteraction = extension.postInteractionTargetAndData();
        IEscrowFactory.ExtraDataArgs calldata extraDataArgs;
        TakerData calldata takerData;
        assembly ("memory-safe") {
            extraDataArgs := add(postInteraction.offset, sub(postInteraction.length, SRC_IMMUTABLES_LENGTH))
            takerData := extraData.offset
        }
        uint240 rootShortened = uint240(uint256(extraDataArgs.hashlockInfo));
        bytes32 key = keccak256(abi.encodePacked(orderHash, rootShortened));
        bytes32 rootCalculated = takerData.proof.processProofCalldata(
            keccak256(abi.encodePacked(uint64(takerData.idx), takerData.secretHash))
        );
        if (uint240(uint256(rootCalculated)) != rootShortened) revert InvalidProof();
        lastValidated[key] = ValidationData(takerData.idx + 1, takerData.secretHash);
    }
}
