// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for murky/src/Merkle.sol.
import { Merkle } from "murky/src/Merkle.sol";

function createMerkle() returns (Merkle) {
    return new Merkle();
}
