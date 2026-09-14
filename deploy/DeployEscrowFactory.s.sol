// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";

import { ICreate3Deployer } from "solidity-utils/contracts/interfaces/ICreate3Deployer.sol";

import { EscrowFactory } from "contracts/EscrowFactory.sol";

import { Config } from "./utils/Config.sol";

// solhint-disable no-console
import { console2 } from "forge-std/console2.sol";

contract DeployEscrowFactory is Script {
    using Config for *;
    uint32 public constant RESCUE_DELAY = 691200; // 8 days

    function run() external {
        (
            address lopAddress, 
            address accessToken, 
            address create3Deployer, 
            bytes32 salt, 
            address factoryOwner
        ) = vm.readEscrowFactoryParameters(true);

        vm.startBroadcast();
        address escrowFactory = ICreate3Deployer(create3Deployer).deploy(
            salt,
            abi.encodePacked(
                type(EscrowFactory).creationCode,
                abi.encode(lopAddress, accessToken, factoryOwner, RESCUE_DELAY, RESCUE_DELAY)
            )
        );
        vm.stopBroadcast();

        console2.log("Escrow Factory deployed at: ", escrowFactory);
    }
}
// solhint-enable no-console
