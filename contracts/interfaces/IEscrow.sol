// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IBaseEscrow } from "./IBaseEscrow.sol";

/**
 * @title Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 * @custom:security-contact security@1inch.io
 */
interface IEscrow is IBaseEscrow {
    /// @notice Returns the bytecode hash of the proxy contract.
    function PROXY_BYTECODE_HASH() external view returns (bytes32); // solhint-disable-line func-name-mixedcase
}
