// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry-side counterpart to the Hardhat shim for contracts/zkSync/EscrowFactoryZkSync.sol.
import { EscrowFactoryZkSync } from "contracts/zkSync/EscrowFactoryZkSync.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

function createEscrowFactoryZkSync(
    address limitOrderProtocol,
    address accessToken,
    address owner,
    uint32 rescueDelaySrc,
    uint32 rescueDelayDst
) returns (EscrowFactoryZkSync) {
    return new EscrowFactoryZkSync(limitOrderProtocol, IERC20(accessToken), owner, rescueDelaySrc, rescueDelayDst);
}
