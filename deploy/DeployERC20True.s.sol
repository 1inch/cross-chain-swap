// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";

import { ICreate3Deployer } from "solidity-utils/contracts/interfaces/ICreate3Deployer.sol";

import { ERC20True } from "contracts/mocks/ERC20True.sol";

import { Config } from "./utils/Config.sol";

// solhint-disable no-console
import { console2 } from "forge-std/console2.sol";

contract DeployERC20True is Script {
    using Config for *;

    function run() external {
        bool useCreate3Deployer = vm.envUint("OPS_CHAIN_ID") != 324;

        if (!useCreate3Deployer) {
            vm.startBroadcast();
            ERC20True trueToken = new ERC20True();
            vm.stopBroadcast();

            console2.log("ERC20True deployed at: ", address(trueToken));
        } else {
            (
                address create3Deployer, 
                bytes32 salt
            ) = vm.readTrueTokenParameters();

            vm.startBroadcast();
            address trueToken = ICreate3Deployer(create3Deployer).deploy(
                salt,
                abi.encodePacked(
                    type(ERC20True).creationCode
                )
            );
            vm.stopBroadcast();

            console2.log("ERC20True deployed at: ", trueToken);
        }
    }
}
// solhint-enable no-console