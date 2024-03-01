// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IEscrow } from "../interfaces/IEscrow.sol";

library ImmutablesLib {
    uint256 internal constant ESCROW_IMMUTABLES_SIZE = 0x100;

    function hash(IEscrow.Immutables calldata immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, immutables, ESCROW_IMMUTABLES_SIZE)
            ret := keccak256(ptr, ESCROW_IMMUTABLES_SIZE)
        }
    }

    function hashMem(IEscrow.Immutables memory immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            ret := keccak256(immutables, ESCROW_IMMUTABLES_SIZE)
        }
    }
}
