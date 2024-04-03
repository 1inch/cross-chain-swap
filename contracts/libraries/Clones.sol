// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[ERC-1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 */
library Clones {
    /**
     * @dev A clone instance deployment failed.
     */
    error ERC1167FailedCreateClone();

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt, uint256 value) internal returns (address instance) {
        assembly ("memory-safe"){
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(value, 0x09, 0x37, salt)
        }
        if (instance == address(0)) {
            revert ERC1167FailedCreateClone();
        }
    }

    /**
     * @notice Returns the hash of the proxy bytecode concatenated with the implementation address.
     * @param implementation The address of the contract to clone.
     * @return bytecodeHash The hash of the resulting bytecode.
     */
    function computeProxyBytecodeHash(address implementation) internal pure returns (bytes32 bytecodeHash) {
        assembly ("memory-safe") {
            // Stores the bytecode after address
            mstore(0x20, 0x5af43d82803e903d91602b57fd5bf3)
            // implementation address
            mstore(0x11, implementation)
            // Packs the first 3 bytes of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0x88, implementation), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            bytecodeHash := keccak256(0x09, 0x37)
        }
    }
}
