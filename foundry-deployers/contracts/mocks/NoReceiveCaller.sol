// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for contracts/mocks/NoReceiveCaller.sol.
import { NoReceiveCaller } from "contracts/mocks/NoReceiveCaller.sol";

function createNoReceiveCaller() returns (NoReceiveCaller) {
    return new NoReceiveCaller();
}
