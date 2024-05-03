// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { ITakerInteraction } from "limit-order-protocol/interfaces/ITakerInteraction.sol";
import { MerkleProof } from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";

contract MerkleStorageInvalidator is ITakerInteraction {
    using MerkleProof for bytes32[];

    struct LastValidated {
        uint256 index;
        bytes32 leaf;
    }

    address internal immutable _LIMIT_ORDER_PROTOCOL;

    mapping(bytes32 => LastValidated) public lastValidated;

    error AccessDenied();
    error InvalidProof();

    /// @notice Only limit order protocol can call this contract.
    modifier onlyLimitOrderProtocol() {
        if (msg.sender != _LIMIT_ORDER_PROTOCOL) {
            revert AccessDenied();
        }
        _;
    }

    constructor(address limitOrderProtocol) {
        _LIMIT_ORDER_PROTOCOL = limitOrderProtocol;
    }

    function takerInteraction(
        IOrderMixin.Order calldata /* order */,
        bytes calldata /* extension */,
        bytes32 orderHash,
        address /* taker */,
        uint256 /* makingAmount */,
        uint256 /* takingAmount */,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external onlyLimitOrderProtocol {
        (
            bytes32 root,
            bytes32[] memory proof,
            uint256 idx,
            bytes32 secretHash
        ) = abi.decode(extraData, (bytes32, bytes32[], uint256, bytes32));
        if (!proof.verify(root, keccak256(abi.encodePacked(idx, secretHash)))) revert InvalidProof();
        bytes32 key = keccak256(abi.encodePacked(orderHash, uint240(uint256(root))));
        lastValidated[key] = LastValidated(idx, secretHash);
    }
}
