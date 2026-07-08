// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for contracts/mocks/ERC20True.sol.
import { ERC20True } from "contracts/mocks/ERC20True.sol";

function createERC20True() returns (ERC20True) {
    return new ERC20True();
}
