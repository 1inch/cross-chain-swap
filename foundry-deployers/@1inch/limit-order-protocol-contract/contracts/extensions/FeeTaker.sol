// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for FeeTaker.sol.
// The suite only references the FeeTaker type (e.g. for error selectors), so this
// re-exports the real contract; no deployer function is needed.
import { FeeTaker } from "limit-order-protocol/contracts/extensions/FeeTaker.sol";
