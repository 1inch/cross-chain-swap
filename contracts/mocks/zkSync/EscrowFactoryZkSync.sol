// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseExtension } from "@1inch/limit-order-settlement/contracts/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "@1inch/limit-order-settlement/contracts/extensions/ResolverFeeExtension.sol";

import { BaseEscrowFactory } from "contracts/BaseEscrowFactory.sol";
import { MerkleStorageInvalidator } from "contracts/MerkleStorageInvalidator.sol";
import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";
import { ZkSyncLib } from "contracts/libraries/ZkSyncLib.sol";

import { IEscrow } from "contracts/interfaces/IEscrow.sol";
import { EscrowSrcZkSync } from "./EscrowSrcZkSync.sol";
import { EscrowDstZkSync } from "./EscrowDstZkSync.sol";
import { MinimalProxyZkSync } from "./MinimalProxyZkSync.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactoryZkSync is BaseEscrowFactory {
    using ImmutablesLib for IEscrow.Immutables;

    bytes32 public immutable ESCROW_SRC_INPUT_HASH;
    bytes32 public immutable ESCROW_DST_INPUT_HASH;

    constructor(
        address limitOrderProtocol,
        IERC20 token,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) MerkleStorageInvalidator(limitOrderProtocol) {
        ESCROW_SRC_IMPLEMENTATION = address(new EscrowSrcZkSync(rescueDelaySrc));
        ESCROW_DST_IMPLEMENTATION = address(new EscrowDstZkSync(rescueDelayDst));
        ESCROW_SRC_INPUT_HASH = keccak256(abi.encode(ESCROW_SRC_IMPLEMENTATION));
        ESCROW_DST_INPUT_HASH = keccak256(abi.encode(ESCROW_DST_IMPLEMENTATION));
        MinimalProxyZkSync proxySrc = new MinimalProxyZkSync(ESCROW_SRC_IMPLEMENTATION);
        MinimalProxyZkSync proxyDst = new MinimalProxyZkSync(ESCROW_DST_IMPLEMENTATION);
        bytes32 bytecodeHashSrc;
        bytes32 bytecodeHashDst;
        assembly ("memory-safe") {
            bytecodeHashSrc := extcodehash(proxySrc)
            bytecodeHashDst := extcodehash(proxyDst)
        }
        _PROXY_SRC_BYTECODE_HASH = bytecodeHashSrc;
        _PROXY_DST_BYTECODE_HASH = bytecodeHashDst;
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(IEscrow.Immutables calldata immutables) external view override returns (address) {
        return ZkSyncLib.computeAddressZkSync(immutables.hash(), _PROXY_SRC_BYTECODE_HASH, address(this), ESCROW_SRC_INPUT_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IEscrow.Immutables calldata immutables) external view override returns (address) {
        return ZkSyncLib.computeAddressZkSync(immutables.hash(), _PROXY_DST_BYTECODE_HASH, address(this), ESCROW_DST_INPUT_HASH);
    }

    /**
     * @notice Deploys a new escrow contract.
     * @param salt The salt for the deterministic address computation.
     * @param value The value to be sent to the escrow contract.
     * @param data The data to be used during the deployment.
     * @return escrow The address of the deployed escrow contract.
     */
    function _deployEscrow(bytes32 salt, uint256 value, bytes memory data) internal override returns (address escrow){
        address implementation  = abi.decode(data, (address));
        escrow = escrow = address(new MinimalProxyZkSync{salt: salt, value: value}(implementation));
    }
}
