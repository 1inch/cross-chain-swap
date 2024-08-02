// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Escrow, EscrowDst } from "../EscrowDst.sol";
import { EscrowZkSync } from "./EscrowZkSync.sol";

/// @custom:security-contact security@1inch.io
contract EscrowDstZkSync is EscrowDst, EscrowZkSync {
    constructor(uint32 rescueDelay) EscrowDst(rescueDelay) EscrowZkSync() {}

    function _validateImmutables(Immutables calldata immutables) internal view override(Escrow, EscrowZkSync) {
        EscrowZkSync._validateImmutables(immutables);
    }
}
