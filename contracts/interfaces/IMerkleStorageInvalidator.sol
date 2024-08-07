// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @title Merkle Storage Invalidator interface
 * @notice Interface to invalidate hashed secrets from an order that supports multiple fills.
 * @custom:security-contact security@1inch.io
 */
interface IMerkleStorageInvalidator {
    struct ValidationData {
        uint256 index;
        bytes32 leaf;
    }

    struct TakerData {
        bytes32[] proof;
        uint256 idx;
        bytes32 secretHash;
    }

    error AccessDenied();
    error InvalidProof();

    /**
     * @notice Returns the index of the last validated hashed secret and the hashed secret itself.
     * @param key Hash of concatenated order hash and 30 bytes of root hash.
     * @return index Index of the last validated hashed secret.
     * @return secretHash Last validated hashed secret.
     */
    function lastValidated(bytes32 key) external view returns (uint256 index, bytes32 secretHash);
}
