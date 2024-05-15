// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { EscrowSrc } from "contracts/EscrowSrc.sol";
import { EscrowZkSync } from "contracts/mocks/zkSync/EscrowZkSync.sol";

contract EscrowSrcZkSync is EscrowSrc, EscrowZkSync {
    constructor(uint32 rescueDelay) EscrowSrc(rescueDelay) EscrowZkSync() {}

    modifier onlyValidImmutables(Immutables calldata immutables) override {
        _validateImmutablesZk(immutables);
        _;
    }
}
