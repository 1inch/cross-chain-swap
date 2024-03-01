// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IEscrowSrc } from "../interfaces/IEscrowSrc.sol";
import { IEscrowDst } from "../interfaces/IEscrowDst.sol";

library ImmutablesLib {
    uint256 internal constant ESCROW_SRC_IMMUTABLES_SIZE = 0x100;
    uint256 internal constant ESCROW_DST_IMMUTABLES_SIZE = 0x100;

    function hash(IEscrowSrc.Immutables calldata immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, immutables, ESCROW_SRC_IMMUTABLES_SIZE)
            ret := keccak256(ptr, ESCROW_SRC_IMMUTABLES_SIZE)
        }
    }

    function hashMem(IEscrowSrc.Immutables memory immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            ret := keccak256(immutables, ESCROW_SRC_IMMUTABLES_SIZE)
        }
    }

    function hash(IEscrowDst.Immutables calldata immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, immutables, ESCROW_DST_IMMUTABLES_SIZE)
            ret := keccak256(ptr, ESCROW_DST_IMMUTABLES_SIZE)
        }
    }

    function hashMem(IEscrowDst.Immutables memory immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            ret := keccak256(immutables, ESCROW_DST_IMMUTABLES_SIZE)
        }
    }
}
