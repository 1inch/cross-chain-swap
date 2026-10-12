// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for TokenCustomDecimalsMock.sol.
import { TokenCustomDecimalsMock } from "solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol";

function createTokenCustomDecimalsMock(string memory name, string memory symbol, uint256 amount, uint8 decimals_)
    returns (TokenCustomDecimalsMock)
{
    return new TokenCustomDecimalsMock(name, symbol, amount, decimals_);
}
