// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Vm } from "forge-std/Vm.sol";

// solhint-disable no-console
import { console2 } from "forge-std/console2.sol";

error LopAddressDoesNotExist();
error AccessTokenAddressDoesNotExist();
error Create3DeployerAddressDoesNotExist();
error SaltDoesNotExist();
error OwnerAddressDoesNotExist();
error InvalidBytesLength(uint256 length);

library Config {
    function readEscrowFactoryParameters(Vm vm, bool useCreate3Deployer) internal view returns (
        address lopAddress, 
        address accessToken, 
        address create3Deployer, 
        bytes32 salt, 
        address owner
    ) {
        string memory path = string.concat(vm.projectRoot(), "/deploy/config.json");
        string memory json = vm.readFile(path);

        lopAddress = vm.parseJsonAddress(json, ".lop");
        if (lopAddress == address(0)) revert LopAddressDoesNotExist();
        console2.log("LOP address:", lopAddress);

        accessToken = vm.parseJsonAddress(json, ".accessToken");
        if (accessToken == address(0)) revert AccessTokenAddressDoesNotExist();
        console2.log("Access token address:", accessToken);

        if (useCreate3Deployer) {
            create3Deployer = vm.parseJsonAddress(json, ".create3Deployer");
            if (create3Deployer == address(0)) revert Create3DeployerAddressDoesNotExist();
            console2.log("Create3Deployer address:", create3Deployer);

            salt = parseSalt(vm, vm.parseJsonString(json, ".factorySalt"));
            console2.log("Salt:", vm.toString(salt));
        }

        address factoryOwner = vm.parseJsonAddress(json, ".factoryOwner");
        owner = factoryOwner != address(0) ? factoryOwner : vm.envAddress("DEPLOYER_ADDRESS");
        if (owner == address(0)) revert OwnerAddressDoesNotExist();
        console2.log("Owner address:", owner);
    }

    function readTrueTokenParameters(Vm vm) internal view returns (
        address create3Deployer,
        bytes32 salt
    ) {
        string memory path = string.concat(vm.projectRoot(), "/deploy/config.json");
        string memory json = vm.readFile(path);

        create3Deployer = vm.parseJsonAddress(json, ".create3Deployer");
        if (create3Deployer == address(0)) revert Create3DeployerAddressDoesNotExist();
        console2.log("Create3Deployer address:", create3Deployer);

        salt = parseSalt(vm, vm.parseJsonString(json, ".trueTokenSalt"));
        console2.log("Salt:", vm.toString(salt));
    }

    function parseSalt(Vm vm, string memory saltString) internal pure returns (bytes32 salt) {
        if (bytes(saltString).length == 0) revert SaltDoesNotExist();
        if (!startsWithOx(saltString)) {
            salt = keccak256(abi.encodePacked(saltString));
        } else {
            salt = vm.parseBytes32(saltString);
        }
    }

    function startsWithOx(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        return b.length >= 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X");
    }
}