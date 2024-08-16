// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { Escrow, EscrowSrc } from "../EscrowSrc.sol";
import { EscrowZkSync } from "./EscrowZkSync.sol";

/// @custom:security-contact security@1inch.io
contract EscrowSrcZkSync is EscrowSrc, EscrowZkSync {
    constructor(uint32 rescueDelay, IERC20 accessToken) EscrowSrc(rescueDelay, accessToken) EscrowZkSync() {}

    function _validateImmutables(Immutables calldata immutables) internal view override(Escrow, EscrowZkSync) {
        EscrowZkSync._validateImmutables(immutables);
    }
}
