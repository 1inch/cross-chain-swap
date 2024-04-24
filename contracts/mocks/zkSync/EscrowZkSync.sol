// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Escrow } from "contracts/Escrow.sol";

import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";
import { ZkSyncLib } from "contracts/libraries/ZkSyncLib.sol";

abstract contract EscrowZkSync is Escrow {
    using ImmutablesLib for Immutables;

    bytes32 private immutable _INPUT_HASH;
    
    constructor(uint32 rescueDelay) {
        _INPUT_HASH = keccak256(abi.encode(rescueDelay));
    }

    function _validateImmutablesZk(Immutables calldata immutables) internal view {
        bytes32 salt = immutables.hash();
        bytes32 bytecodeHash;
        assembly ("memory-safe") {
            bytecodeHash := extcodehash(address())
        }
        if (ZkSyncLib.computeAddressZkSync(salt, bytecodeHash, FACTORY, _INPUT_HASH) != address(this)) {
            revert InvalidImmutables();
        }
    }
}
