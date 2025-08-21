// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { BaseEscrow } from "../BaseEscrow.sol";

import { ZkSyncLib } from "./ZkSyncLib.sol";

/// @custom:security-contact security@1inch.io
abstract contract EscrowZkSync is BaseEscrow {
    bytes32 private immutable _INPUT_HASH;

    constructor() {
        _INPUT_HASH = keccak256(abi.encode(address(this)));
    }

    function _validateImmutables(bytes32 immutablesHash) internal view virtual override {
        bytes32 bytecodeHash;
        assembly ("memory-safe") {
            bytecodeHash := extcodehash(address())
        }
        if (ZkSyncLib.computeAddressZkSync(immutablesHash, bytecodeHash, FACTORY, _INPUT_HASH) != address(this)) {
            revert InvalidImmutables();
        }
    }
}
