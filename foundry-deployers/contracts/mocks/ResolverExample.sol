// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for contracts/mocks/ResolverExample.sol.
import { ResolverExample } from "contracts/mocks/ResolverExample.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

function createResolverExample(address factory, address lop, address initialOwner) returns (ResolverExample) {
    return new ResolverExample(IEscrowFactory(factory), IOrderMixin(lop), initialOwner);
}
