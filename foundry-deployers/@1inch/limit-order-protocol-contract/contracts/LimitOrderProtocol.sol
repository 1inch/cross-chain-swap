// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for LimitOrderProtocol.sol.
import { IWETH, LimitOrderProtocol } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";

function createLimitOrderProtocol(address _weth) returns (LimitOrderProtocol) {
    return new LimitOrderProtocol(IWETH(_weth));
}
