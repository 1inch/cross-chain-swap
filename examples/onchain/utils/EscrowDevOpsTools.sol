// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { Timelocks } from "contracts/libraries/TimelocksLib.sol";

import { DevOpsTools } from "./DevOpsTools.sol";
import { Config } from "./ConfigLib.sol";

library EscrowDevOpsTools {
    error NoSrcEscrowCreatedEventFound();
    error NoDstEscrowCreatedEventFound();
    error NoTransferEventFoundForSrcToken();
    error NoOrderFilledEventFound();
    error OutOfBounds();

    string public constant RELATIVE_BROADCAST_PATH = "./broadcast/CreateOrder.s.sol";

    bytes32 public constant ORDER_FILLED_EVENT_SIGNATURE = 0xfec331350fce78ba658e082a71da20ac9f8d798a99b3c79681c8440cbfe77e07;
    bytes32 public constant TRANSFER_EVENT_SIGNATURE = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    bytes32 public constant SRC_ESCROW_CREATED_EVENT_SIGNATURE = 0x0e534c62f0afd2fa0f0fa71198e8aa2d549f24daf2bb47de0d5486c7ce9288ca;
    bytes32 public constant DST_ESCROW_CREATED_EVENT_SIGNATURE = 0xc30e111dcc74fddc2c3a4d98ffb97adec4485c0a687946bf5b22c2a99c7ff96d;

    function getResolver(Config memory config) internal view returns(address) {
        if (block.chainid != 31337) {
            return config.resolver;
        }

        address contractAddress = DevOpsTools.getMostRecentDeployment(
            "ResolverExample", "", block.chainid, RELATIVE_BROADCAST_PATH);
        return contractAddress;
    }

    function getSrcToken(Config memory config) internal view returns(address) {
        return getToken(config.srcToken);
    }

    function getDstToken(Config memory config) internal view returns(address) {
        return getToken(config.dstToken);
    }

    function getToken(address token) internal view returns(address) {
        if (block.chainid != 31337 || token == address(0)) {
            return token;
        }

        address contractAddress = DevOpsTools.getMostRecentDeployment(
            "TokenCustomDecimalsMock", ERC20(token).name(), block.chainid, RELATIVE_BROADCAST_PATH);
        return contractAddress;
    }

    function getEscrowSrcAddressAndTimestamp(address srcToken) internal view returns(address, uint256) {
        DevOpsTools.Receipt memory receipt = DevOpsTools.getMostRecentLog(
            srcToken, 
            TRANSFER_EVENT_SIGNATURE, 
            block.chainid, 
            RELATIVE_BROADCAST_PATH
        );

        if (receipt.topics.length < 3) {
            revert NoTransferEventFoundForSrcToken();
        }

        return (address(uint160(uint256(receipt.topics[2]))), receipt.timestamp);
    }

    function getOrderHashAndTimelocksFromSrcEscrowCreatedEvent(Config memory config) internal view returns(bytes32 orderHash, Timelocks) {
        DevOpsTools.Receipt memory receipt = DevOpsTools.getMostRecentLog(
            config.escrowFactory, 
            SRC_ESCROW_CREATED_EVENT_SIGNATURE, 
            block.chainid, 
            RELATIVE_BROADCAST_PATH
        );

        if (receipt.data.length < 256) {
            revert NoSrcEscrowCreatedEventFound();
        }

        return (toBytes32(receipt.data, 0), Timelocks.wrap(uint256(toBytes32(receipt.data, 224))));
    }

    function getEscrowDstAddressAndDeployTimeFromDstEscrowCreatedEvent(Config memory config) internal view returns(address, uint256) {
        DevOpsTools.Receipt memory receipt = DevOpsTools.getMostRecentLog(
            config.escrowFactory, 
            DST_ESCROW_CREATED_EVENT_SIGNATURE, 
            block.chainid, 
            RELATIVE_BROADCAST_PATH
        );

        if (receipt.data.length < 96) {
            revert NoDstEscrowCreatedEventFound();
        }

        return (address(uint160(uint256(toBytes32(receipt.data, 0)))), receipt.timestamp);
    }

    function getOrderHash(Config memory config) internal view returns(bytes32) {
        DevOpsTools.Receipt memory receipt = DevOpsTools.getMostRecentLog(
            config.limitOrderProtocol, 
            ORDER_FILLED_EVENT_SIGNATURE, 
            block.chainid, 
            RELATIVE_BROADCAST_PATH
        );

        if (receipt.data.length < 32) {
            revert NoOrderFilledEventFound();
        }

        return toBytes32(receipt.data, 0);
    }

    function toBytes32(bytes memory data, uint256 offset) internal pure returns (bytes32 result) {
        if (data.length < offset + 32) {
            revert OutOfBounds();
        }
        assembly {
            result := mload(add(add(data, 32), offset))
        }
    }
}