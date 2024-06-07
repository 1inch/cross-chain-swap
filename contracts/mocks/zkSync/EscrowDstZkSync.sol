// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { EscrowDst } from "contracts/EscrowDst.sol";
import { EscrowZkSync } from "contracts/mocks/zkSync/EscrowZkSync.sol";

contract EscrowDstZkSync is EscrowDst, EscrowZkSync {
    constructor(uint32 rescueDelay) EscrowDst(rescueDelay) EscrowZkSync() payable {}

    modifier onlyValidImmutables(Immutables calldata immutables) override {
        _validateImmutablesZk(immutables);
        _;
    }
}
