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
error InvalidBytesLength();

library Config {
    function readEscrowFactoryParamenters(Vm vm, bool useCreate3Deployer) internal view returns (
        address lopAddress, 
        address accessToken, 
        address create3Deployer, 
        bytes32 salt, 
        address owner
    ) {
        uint256 chain = block.chainid;

        string memory path = string.concat(vm.projectRoot(), "/config/constants.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", vm.toString(chain));

        lopAddress = vm.parseJsonAddress(json, string.concat(".lop", key));
        if (lopAddress == address(0)) revert LopAddressDoesNotExist();
        console2.log("LOP address:", lopAddress);

        accessToken = vm.parseJsonAddress(json, string.concat(".accessToken", key));
        if (accessToken == address(0)) revert AccessTokenAddressDoesNotExist();
        console2.log("Access token address:", accessToken);

        if (useCreate3Deployer) {
            create3Deployer = vm.parseJsonAddress(json, string.concat(".create3Deployer", key));
            if (create3Deployer == address(0)) revert Create3DeployerAddressDoesNotExist();
            console2.log("Create3Deployer address:", create3Deployer);

            salt = _parseSalt(vm.parseJsonString(json, string.concat(".factorySalt", key)));
            console2.log("Salt:", vm.toString(salt));
        }

        address factoryOwner = vm.parseJsonAddress(json, string.concat(".factoryOwner", key));
        owner = factoryOwner != address(0) ? factoryOwner : vm.envAddress("DEPLOYER_ADDRESS");
        if (owner == address(0)) revert OwnerAddressDoesNotExist();
        console2.log("Owner address:", owner);
    }

    function readTrueTokenParameters(Vm vm) internal view returns (
        address create3Deployer,
        bytes32 salt
    ) {
        uint256 chain = block.chainid;

        string memory path = string.concat(vm.projectRoot(), "/config/constants.json");
        string memory json = vm.readFile(path);
        string memory key = string.concat(".", vm.toString(chain));

        create3Deployer = vm.parseJsonAddress(json, string.concat(".create3Deployer", key));
        if (create3Deployer == address(0)) revert Create3DeployerAddressDoesNotExist();
        console2.log("Create3Deployer address:", create3Deployer);

        salt = _parseSalt(vm.parseJsonString(json, string.concat(".trueTokenSalt", key)));
        console2.log("Salt:", vm.toString(salt));
    }
}

function _parseSalt(string memory saltString) pure returns (bytes32 salt) {
    if (bytes(saltString).length == 0) revert SaltDoesNotExist();
    if (!_startsWithOx(saltString)) {
        salt = keccak256(abi.encodePacked(saltString));   
    } else {
        salt = _bytesToBytes32(bytes(saltString));
    }
}

function _startsWithOx(string memory str) pure returns (bool) {
    bytes memory b = bytes(str);
    return b.length >= 2 && b[0] == "0" && (b[1] == "x" || b[1] == "X");
}

function _bytesToBytes32(bytes memory b) pure returns (bytes32) {
    if (b.length != 32) revert InvalidBytesLength();
    bytes32 out;
    assembly ("memory-safe") {
        out := mload(add(b, 32))
    }
    return out;
}