// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";
import { AddressLib, Address } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { Clones } from "./libraries/Clones.sol";
import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IEscrow } from "./interfaces/IEscrow.sol";

/**
 * @title Base Escrow contract for cross-chain atomic swap.
 */
abstract contract Escrow is IEscrow {
    using AddressLib for Address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for Immutables;

    uint256 public immutable RESCUE_DELAY;
    address public immutable FACTORY = msg.sender;
    bytes32 public immutable PROXY_BYTECODE_HASH = Clones.computeProxyBytecodeHash(address(this));

    constructor(uint32 rescueDelay) {
        RESCUE_DELAY = rescueDelay;
    }

    modifier onlyValidImmutables(Immutables calldata immutables) {
        _validateImmutables(immutables);
        _;
    }

    /**
     * @notice See {IEscrow-rescueFunds}.
     */
    function rescueFunds(address token, uint256 amount, Immutables calldata immutables) external onlyValidImmutables(immutables) {
        if (msg.sender != immutables.taker.get()) revert InvalidCaller();
        if (block.timestamp < immutables.timelocks.rescueStart(RESCUE_DELAY)) revert InvalidRescueTime();
        _uniTransfer(token, msg.sender, amount);
    }

    function _isValidSecret(bytes32 secret, bytes32 hashlock) internal pure returns (bool) {
        return keccak256(abi.encode(secret)) == hashlock;
    }

    /**
     * @notice Checks the secret and transfers tokens to the recipient.
     * @dev The secret is valid if its hash matches the hashlock.
     * @param secret Provided secret to verify.
     * @param hashlock Hashlock to compare with.
     * @param recipient Address to transfer tokens to.
     * @param token Address of the token to transfer.
     * @param amount Amount of tokens to transfer.
     */
    function _checkSecretAndTransfer(
        bytes32 secret,
        bytes32 hashlock,
        address recipient,
        address token,
        uint256 amount
    ) internal {
        if (!_isValidSecret(secret, hashlock)) revert InvalidSecret();
        _uniTransfer(token, recipient, amount);
    }

    function _uniTransfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            _ethTransfer(to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _ethTransfer(address to, uint256 amount) internal {
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert NativeTokenSendingFailure();
    }

    function _validateImmutables(Immutables calldata immutables) private view {
        bytes32 salt = immutables.hash();
        if (Create2.computeAddress(salt, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
            revert InvalidImmutables();
        }
    }
}
