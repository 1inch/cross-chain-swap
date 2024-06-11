// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Escrow, EscrowDst } from "contracts/EscrowDst.sol";
import { EscrowZkSync } from "contracts/mocks/zkSync/EscrowZkSync.sol";

contract EscrowDstZkSync is EscrowDst, EscrowZkSync {
    constructor(uint32 rescueDelay) EscrowDst(rescueDelay) EscrowZkSync() payable {}

    function _validateImmutables(Immutables calldata immutables) internal view override(Escrow, EscrowZkSync) {
        EscrowZkSync._validateImmutables(immutables);
    }
}
