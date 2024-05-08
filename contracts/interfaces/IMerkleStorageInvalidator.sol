// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @title Merkle Storage Invalidator interface
 * @notice Interface to invalidate hashed secrets from an order that supports multimple fills.
 */
interface IMerkleStorageInvalidator {
    struct LastValidated {
        uint256 index;
        bytes32 leaf;
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
