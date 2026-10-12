// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for contracts/EscrowFactory.sol.
import { EscrowFactory } from "contracts/EscrowFactory.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

function createEscrowFactory(
    address limitOrderProtocol,
    address accessToken,
    address owner,
    uint32 rescueDelaySrc,
    uint32 rescueDelayDst
) returns (EscrowFactory) {
    return new EscrowFactory(limitOrderProtocol, IERC20(accessToken), owner, rescueDelaySrc, rescueDelayDst);
}
