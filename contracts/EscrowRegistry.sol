// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clone } from "clones-with-immutable-args/Clone.sol";

import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IEscrowRegistry } from "./interfaces/IEscrowRegistry.sol";

contract EscrowRegistry is Clone, IEscrowRegistry {
    using SafeERC20 for IERC20;

    function withdrawSrc(bytes32 secret) external {
        IEscrowFactory.SrcEscrowImmutables memory escrowImmutables = srcEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.extraDataParams.srcTimelocks.finality;
        if (
            block.timestamp < finalityTimestamp ||
            block.timestamp > finalityTimestamp + escrowImmutables.extraDataParams.srcTimelocks.publicUnlock
        ) revert InvalidWithdrawalTime();

        _checkSecretAndTransfer(
            secret,
            escrowImmutables.extraDataParams.hashlock,
            escrowImmutables.interactionParams.taker,
            escrowImmutables.interactionParams.srcToken,
            escrowImmutables.interactionParams.srcAmount
        );
    }

    function cancelSrc() external {
        IEscrowFactory.SrcEscrowImmutables memory escrowImmutables = srcEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.extraDataParams.srcTimelocks.finality;
        if (
            block.timestamp < finalityTimestamp ||
            block.timestamp < finalityTimestamp + escrowImmutables.extraDataParams.srcTimelocks.publicUnlock
        ) revert InvalidCancellationTime();

        IERC20(escrowImmutables.interactionParams.srcToken).safeTransfer(
            escrowImmutables.interactionParams.maker,
            escrowImmutables.interactionParams.srcAmount
        );
    }

    function withdrawDst(bytes32 secret) external {
        IEscrowFactory.DstEscrowImmutables memory escrowImmutables = dstEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.timelocks.finality;
        uint256 unlockTimestamp = finalityTimestamp + escrowImmutables.timelocks.unlock;
        if (
            block.timestamp < finalityTimestamp ||
            block.timestamp > unlockTimestamp + escrowImmutables.timelocks.publicUnlock
        ) revert InvalidWithdrawalTime();

        if (block.timestamp < unlockTimestamp) {
            if (msg.sender != escrowImmutables.taker) revert InvalidCaller();
        }
        _checkSecretAndTransfer(
            secret,
            escrowImmutables.hashlock,
            escrowImmutables.maker,
            escrowImmutables.token,
            escrowImmutables.amount
        );
        IERC20(escrowImmutables.token).safeTransfer(
            msg.sender,
            escrowImmutables.safetyDeposit
        );
    }

    function cancelDst() external {
        IEscrowFactory.DstEscrowImmutables memory escrowImmutables = dstEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.timelocks.finality;
        if (
            block.timestamp < finalityTimestamp ||
            block.timestamp < finalityTimestamp + escrowImmutables.timelocks.unlock + escrowImmutables.timelocks.publicUnlock
        ) revert InvalidCancellationTime();

        IERC20(escrowImmutables.token).safeTransfer(
            escrowImmutables.taker,
            escrowImmutables.amount
        );

        IERC20(escrowImmutables.token).safeTransfer(
            msg.sender,
            escrowImmutables.safetyDeposit
        );
    }

    function srcEscrowImmutables() public pure returns (IEscrowFactory.SrcEscrowImmutables memory) {
        IEscrowFactory.SrcEscrowImmutables calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data := offset
        }
        return data;
    }

    function dstEscrowImmutables() public pure returns (IEscrowFactory.DstEscrowImmutables memory) {
        IEscrowFactory.DstEscrowImmutables calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data := offset
        }
        return data;
    }

    function _isValidSecret(bytes32 secret, uint256 hashlock) internal pure returns (bool) {
        return uint256(keccak256(abi.encode(secret))) == hashlock;
    }

    function _checkSecretAndTransfer(bytes32 secret, uint256 hashlock, address recipient, address token, uint256 amount) internal {
        if (!_isValidSecret(secret, hashlock)) revert InvalidSecret();
        IERC20(token).safeTransfer(recipient, amount);
    }
}
