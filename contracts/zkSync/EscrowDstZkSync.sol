// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Escrow, EscrowDst } from "contracts/EscrowDst.sol";
import { EscrowZkSync } from "contracts/zkSync/EscrowZkSync.sol";

contract EscrowDstZkSync is EscrowDst, EscrowZkSync {
    constructor(uint32 rescueDelay) EscrowDst(rescueDelay) EscrowZkSync() {}

    function _validateImmutables(Immutables calldata immutables) internal view override(Escrow, EscrowZkSync) {
        EscrowZkSync._validateImmutables(immutables);
    }
}
