// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for TokenMock.sol.
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";

function createTokenMock(string memory name, string memory symbol) returns (TokenMock) {
    return new TokenMock(name, symbol);
}
