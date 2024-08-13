// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { AddressLib, Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";

import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";

/**
 * @title Base abstract Escrow contract for cross-chain atomic swap.
 * @dev {IBaseEscrow-withdraw}, {IBaseEscrow-cancel} and _validateImmutables functions must be implemented in the derived contracts.
 * @custom:security-contact security@1inch.io
 */
abstract contract BaseEscrow is IBaseEscrow {
    using AddressLib for Address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for Immutables;

    event Results(bytes32 hashlock, bytes32 hashed);

    /// @notice See {IBaseEscrow-RESCUE_DELAY}.
    uint256 public immutable RESCUE_DELAY;
    /// @notice See {IBaseEscrow-FACTORY}.
    address public immutable FACTORY = msg.sender;

    constructor(uint32 rescueDelay) {
        RESCUE_DELAY = rescueDelay;
    }

    modifier onlyTaker(Immutables calldata immutables) {
        if (msg.sender != immutables.taker.get()) revert InvalidCaller();
        _;
    }

    modifier onlyValidImmutables(Immutables calldata immutables) virtual {
        _validateImmutables(immutables);
        _;
    }

    modifier onlyValidSecret(bytes32 secret, Immutables calldata immutables) {
        emit Results(immutables.hashlock, _keccakBytes32(secret));
        if (_keccakBytes32(secret) != immutables.hashlock) revert InvalidSecret();
        _;
    }

    modifier onlyAfter(uint256 start) {
        if (block.timestamp < start) revert InvalidTime();
        _;
    }

    modifier onlyBefore(uint256 stop) {
        if (block.timestamp >= stop) revert InvalidTime();
        _;
    }

    /**
     * @notice See {IBaseEscrow-rescueFunds}.
     */
    function rescueFunds(address token, uint256 amount, Immutables calldata immutables)
        external
        onlyTaker(immutables)
        onlyValidImmutables(immutables)
        onlyAfter(immutables.timelocks.rescueStart(RESCUE_DELAY))
    {
        _uniTransfer(token, msg.sender, amount);
        emit FundsRescued(token, amount);
    }

    /**
     * @dev Transfers ERC20 or native tokens to the recipient.
     */
    function _uniTransfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            _ethTransfer(to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /**
     * @dev Transfers native tokens to the recipient.
     */
    function _ethTransfer(address to, uint256 amount) internal {
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @dev Should verify that the computed escrow address matches the address of this contract.
     */
    function _validateImmutables(Immutables calldata immutables) internal view virtual;

    /**
     * @dev Computes the Keccak-256 hash of the secret.
     * @param secret The secret that unlocks the escrow.
     * @return ret The computed hash.
     */
    function _keccakBytes32(bytes32 secret) private pure returns (bytes32 ret) {
        assembly ("memory-safe") {
            mstore(0, secret)
            ret := keccak256(0, 0x20)
        }
    }
}
