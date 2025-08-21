// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Create2 } from "openzeppelin-contracts/contracts/utils/Create2.sol";

import { ProxyHashLib } from "./libraries/ProxyHashLib.sol";

import { IEscrow } from "./interfaces/IEscrow.sol";
import { BaseEscrow } from "./BaseEscrow.sol";

/**
 * @title Abstract Escrow contract for cross-chain atomic swap.
 * @dev {IBaseEscrow-withdraw} and {IBaseEscrow-cancel} functions must be implemented in the derived contracts.
 * @custom:security-contact security@1inch.io
 */
abstract contract Escrow is BaseEscrow, IEscrow {
    /// @notice See {IEscrow-PROXY_BYTECODE_HASH}.
    bytes32 public immutable PROXY_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(address(this));

    /**
     * @dev Verifies that the computed escrow address matches the address of this contract.
     */
    function _validateImmutables(bytes32 immutablesHash) internal view virtual override {
        if (Create2.computeAddress(immutablesHash, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
            revert InvalidImmutables();
        }
    }
}
