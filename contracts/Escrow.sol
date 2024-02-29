// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { Clones } from "./libraries/Clones.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";

/**
 * @title Base Escrow contract for cross-chain atomic swap.
 */
abstract contract Escrow is IEscrow {
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 public immutable RESCUE_DELAY;
    address public immutable FACTORY = msg.sender;
    bytes32 public immutable PROXY_BYTECODE_HASH = Clones.computeProxyBytecodeHash(address(this));

    constructor(uint256 rescueDelay) {
        if (rescueDelay > type(uint32).max) revert InvalidRescueDelay();
        RESCUE_DELAY = rescueDelay;
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

    function _rescueFunds(Timelocks timelocks, address token, uint256 amount) internal {
        if (block.timestamp < timelocks.rescueStart(RESCUE_DELAY)) revert InvalidRescueTime();
        _uniTransfer(token, msg.sender, amount);
    }

    function _uniTransfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool success,) = to.call{ value: amount }("");
            if (!success) revert NativeTokenSendingFailure();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
