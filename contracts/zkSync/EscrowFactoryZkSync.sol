// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { BaseExtension } from "limit-order-settlement/contracts/extensions/BaseExtension.sol";
import { ResolverValidationExtension } from "limit-order-settlement/contracts/extensions/ResolverValidationExtension.sol";

import { BaseEscrowFactory } from "../BaseEscrowFactory.sol";
import { MerkleStorageInvalidator } from "../MerkleStorageInvalidator.sol";
import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "../libraries/ImmutablesLib.sol";

import { EscrowDstZkSync } from "./EscrowDstZkSync.sol";
import { EscrowSrcZkSync } from "./EscrowSrcZkSync.sol";
import { MinimalProxyZkSync } from "./MinimalProxyZkSync.sol";
import { ZkSyncLib } from "./ZkSyncLib.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 * @custom:security-contact security@1inch.io
 */
contract EscrowFactoryZkSync is BaseEscrowFactory {
    using ImmutablesLib for IBaseEscrow.Immutables;

    bytes32 public immutable ESCROW_SRC_INPUT_HASH;
    bytes32 public immutable ESCROW_DST_INPUT_HASH;

    constructor(
        address limitOrderProtocol,
        IERC20 feeToken,
        IERC20 accessToken,
        address owner,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    )
    BaseExtension(limitOrderProtocol)
    ResolverValidationExtension(feeToken, accessToken, owner)
    MerkleStorageInvalidator(limitOrderProtocol) {
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
    function addressOfEscrowSrc(IBaseEscrow.Immutables calldata immutables) external view override returns (address) {
        return ZkSyncLib.computeAddressZkSync(immutables.hash(), _PROXY_SRC_BYTECODE_HASH, address(this), ESCROW_SRC_INPUT_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IBaseEscrow.Immutables calldata immutables) external view override returns (address) {
        return ZkSyncLib.computeAddressZkSync(immutables.hash(), _PROXY_DST_BYTECODE_HASH, address(this), ESCROW_DST_INPUT_HASH);
    }

    /**
     * @notice Deploys a new escrow contract.
     * @param salt The salt for the deterministic address computation.
     * @param value The value to be sent to the escrow contract.
     * @param implementation Address of the implementation.
     * @return escrow The address of the deployed escrow contract.
     */
    function _deployEscrow(bytes32 salt, uint256 value, address implementation) internal override returns (address escrow) {
        escrow = address(new MinimalProxyZkSync{salt: salt, value: value}(implementation));
    }
}
