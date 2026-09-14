// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {StringUtils} from "./StringUtils.sol";

library DevOpsTools {
    using stdJson for string;
    using StringUtils for string;

    error NoDeploymentArtifactsFound();

    struct Receipt {
        address contractAddress;
        bytes32[] topics;
        bytes data;
        uint256 timestamp;
    }

    // solhint-disable const-name-snakecase
    Vm public constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string public constant RELATIVE_BROADCAST_PATH = "./broadcast";

    function getMostRecentDeployment(string memory contractName, string memory arg, uint256 chainId) internal view returns (address) {
        return getMostRecentDeployment(contractName, arg, chainId, RELATIVE_BROADCAST_PATH);
    }

    function getMostRecentDeployment(
        string memory contractName,
        string memory arg,
        uint256 chainId,
        string memory relativeBroadcastPath
    ) internal view returns (address) {
        address latestAddress = address(0);
        uint256 lastTimestamp;

        bool runProcessed;
        Vm.DirEntry[] memory entries = vm.readDir(relativeBroadcastPath, 3);
        for (uint256 i = 0; i < entries.length; i++) {
            string memory normalizedPath = normalizePath(entries[i].path);
            if (
                normalizedPath.contains(string.concat("/", vm.toString(chainId), "/"))
                    && normalizedPath.contains(".json") && !normalizedPath.contains("dry-run")
            ) {
                string memory json = vm.readFile(normalizedPath);
                latestAddress = processRun(json, contractName, arg, latestAddress);
            }
        }
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.DirEntry memory entry = entries[i];
            if (
                entry.path.contains(string.concat("/", vm.toString(chainId), "/")) && entry.path.contains(".json")
                    && !entry.path.contains("dry-run")
            ) {
                runProcessed = true;
                string memory json = vm.readFile(entry.path);

                uint256 timestamp = vm.parseJsonUint(json, ".timestamp");

                if (timestamp > lastTimestamp) {
                    latestAddress = processRun(json, contractName, arg, latestAddress);

                    // If we have found some deployed contract, update the timestamp
                    // Otherwise, the earliest deployment may have been before `lastTimestamp` and we should not update
                    if (latestAddress != address(0)) {
                        lastTimestamp = timestamp;
                    }
                }
            }
        }

        if (!runProcessed) {
            revert NoDeploymentArtifactsFound();
        }

        if (latestAddress != address(0)) {
            return latestAddress;
        } else {
            revert(
                string.concat(
                    "No contract named ", "'", contractName, "'", " has been deployed on chain ", vm.toString(chainId)
                )
            );
        }
    }

    function processRun(string memory json, string memory contractName, string memory arg, address latestAddress)
        internal
        view
        returns (address)
    {
        for (uint256 i = 0; vm.keyExists(json, string.concat("$.transactions[", vm.toString(i), "]")); i++) {
            string memory transactionsPath = string.concat("$.transactions[", vm.toString(i), "]");
            string memory contractNamePath = string.concat(transactionsPath, ".contractName");
            if (vm.keyExists(json, contractNamePath)) {
                string memory deployedContractName = json.readString(contractNamePath);
                if (deployedContractName.isEqualTo(contractName)) {
                    if (arg.isEqualTo("")) {
                        latestAddress =
                            json.readAddress(string.concat(transactionsPath, ".contractAddress"));
                    } else {
                        string memory argumentsPath = string.concat(transactionsPath, ".arguments");
                        if (vm.keyExists(json, argumentsPath)) {
                            string[] memory arguments = vm.parseJsonStringArray(json, argumentsPath);

                            for (uint256 j = 0; j < arguments.length; j++) {
                                if (arguments[j].isEqualTo(arg)) {
                                    latestAddress =
                                        json.readAddress(string.concat(transactionsPath, ".contractAddress"));
                                    
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        return latestAddress;
    }

    function getMostRecentLog(
        address contractAddress, 
        bytes32 topic,
        uint256 chainId,
        string memory relativeBroadcastPath
    ) internal view returns (Receipt memory) {
        Receipt memory latestReceipt = Receipt({
            contractAddress: address(0),
            topics: new bytes32[](0),
            data: "",
            timestamp: 0
        });

        uint256 lastTimestamp;

        bool runProcessed;
        Vm.DirEntry[] memory entries = vm.readDir(relativeBroadcastPath, 3);
        for (uint256 i = 0; i < entries.length; i++) {
            string memory normalizedPath = normalizePath(entries[i].path);
            if (
                normalizedPath.contains(string.concat("/", vm.toString(chainId), "/"))
                    && normalizedPath.contains(".json") && !normalizedPath.contains("dry-run")
            ) {
                string memory json = vm.readFile(normalizedPath);
                latestReceipt = processLogs(json, contractAddress, topic, latestReceipt);
            }
        }
        for (uint256 i = 0; i < entries.length; i++) {
            Vm.DirEntry memory entry = entries[i];
            if (
                entry.path.contains(string.concat("/", vm.toString(chainId), "/")) && entry.path.contains(".json")
                    && !entry.path.contains("dry-run")
            ) {
                runProcessed = true;
                string memory json = vm.readFile(entry.path);

                uint256 timestamp = vm.parseJsonUint(json, ".timestamp");

                if (timestamp > lastTimestamp) {
                    latestReceipt = processLogs(json, contractAddress, topic, latestReceipt);

                    if (latestReceipt.timestamp != 0) {
                        lastTimestamp = timestamp;
                    }
                }
            }
        }

        if (!runProcessed) {
            revert NoDeploymentArtifactsFound();
        }

        if (latestReceipt.timestamp != 0) {
            return latestReceipt;
        } else {
            revert(
                string.concat(
                    "No logs with topic ", "'", vm.toString(topic), "'", " has found on chain ", vm.toString(chainId)
                )
            );
        }
    }

    function processLogs(string memory json, address contractAddress, bytes32 topic, Receipt memory latestReceipt)
        internal
        view
        returns (Receipt memory)
    {
        for (uint256 i = 0; vm.keyExists(json, string.concat("$.receipts[", vm.toString(i), "]")); i++) {
            string memory receiptsPath = string.concat("$.receipts[", vm.toString(i), "]");
            string memory statusPath = string.concat(receiptsPath, ".status");

            if (vm.keyExists(json, statusPath) && json.readUint(statusPath) != 1) {
                continue; // Skip failed transactions
            }

            string memory logsPath = string.concat(receiptsPath, ".logs");
            if (!vm.keyExists(json, logsPath)) {
                continue; // Skip receipts without logs
            }

            for (uint256 j = 0; vm.keyExists(json, string.concat(logsPath, "[", vm.toString(j), "]")); j++) {
                string memory logPath = string.concat(logsPath, "[", vm.toString(j), "]");
                
                string memory addressPath = string.concat(logPath, ".address");
                if (!vm.keyExists(json, addressPath) || json.readAddress(addressPath) != contractAddress) {
                    continue; // Skip logs not match to contract address
                }

                latestReceipt = _parseLatestReceipt(json, contractAddress, topic, logPath, latestReceipt);
            }
        }

        return latestReceipt;
    }

    function _parseLatestReceipt(
        string memory json, 
        address contractAddress, 
        bytes32 topic, 
        string memory logPath, 
        Receipt memory latestReceipt
    ) 
        internal
        pure
        returns (Receipt memory)
    {
        bytes32[] memory topics = vm.parseJsonBytes32Array(json, string.concat(logPath, ".topics"));
        for (uint256 k = 0; k < topics.length; k++) {
            if (topics[k] == topic) {
                latestReceipt.contractAddress = contractAddress;
                latestReceipt.topics = topics;
                latestReceipt.data = json.readBytes(string.concat(logPath, ".data"));
                latestReceipt.timestamp = json.readUint(string.concat(logPath, ".blockTimestamp"));
                
                break;
            }
        }

        return latestReceipt;
    }

    function normalizePath(string memory path) internal pure returns (string memory) {
        // Replace backslashes with forward slashes
        bytes memory b = bytes(path);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == bytes1("\\")) {
                b[i] = "/";
            }
        }
        return string(b);
    }
}