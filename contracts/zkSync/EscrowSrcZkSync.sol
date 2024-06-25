// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Escrow, EscrowSrc } from "contracts/EscrowSrc.sol";
import { EscrowZkSync } from "contracts/zkSync/EscrowZkSync.sol";

contract EscrowSrcZkSync is EscrowSrc, EscrowZkSync {
    constructor(uint32 rescueDelay) EscrowSrc(rescueDelay) EscrowZkSync() {}

    function _validateImmutables(Immutables calldata immutables) internal view override(Escrow, EscrowZkSync) {
        EscrowZkSync._validateImmutables(immutables);
    }
}
