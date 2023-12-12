// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { EscrowRegistry } from "./EscrowRegistry.sol";

contract EscrowFactory is IEscrowFactory {
    using ClonesWithImmutableArgs for address;

    address public immutable IMPLEMENTATION;

    constructor(address implementation_) {
        IMPLEMENTATION = implementation_;
    }

    function createEscrow(
        bytes calldata data
    ) external returns (EscrowRegistry clone) {
        clone = EscrowRegistry(IMPLEMENTATION.clone(data));
        emit EscrowCreated(address(clone));
    }
}
