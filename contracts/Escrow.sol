// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Clone } from "clones-with-immutable-args/Clone.sol";

import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { IEscrow } from "./interfaces/IEscrow.sol";

contract Escrow is Clone, IEscrow {
    using SafeERC20 for IERC20;

    function withdrawSrc(bytes32 secret) external {
        SrcEscrowImmutables calldata escrowImmutables = srcEscrowImmutables();
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
        (bool success, ) = msg.sender.call{value: escrowImmutables.extraDataParams.srcSafetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    function cancelSrc() external {
        SrcEscrowImmutables calldata escrowImmutables = srcEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.extraDataParams.srcTimelocks.finality;
        uint256 cancellationTimestamp = finalityTimestamp + escrowImmutables.extraDataParams.srcTimelocks.publicUnlock;
        if (block.timestamp < cancellationTimestamp) {
            revert InvalidCancellationTime();
        }

        if (
            block.timestamp < cancellationTimestamp + escrowImmutables.extraDataParams.srcTimelocks.cancel &&
            msg.sender != escrowImmutables.interactionParams.taker
        ) {
            revert InvalidCaller();
        }

        IERC20(escrowImmutables.interactionParams.srcToken).safeTransfer(
            escrowImmutables.interactionParams.maker,
            escrowImmutables.interactionParams.srcAmount
        );
        (bool success, ) = msg.sender.call{value: escrowImmutables.extraDataParams.srcSafetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    function withdrawDst(bytes32 secret) external {
        DstEscrowImmutables calldata escrowImmutables = dstEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.timelocks.finality;
        uint256 unlockTimestamp = finalityTimestamp + escrowImmutables.timelocks.unlock;
        if (
            block.timestamp < finalityTimestamp ||
            block.timestamp > unlockTimestamp + escrowImmutables.timelocks.publicUnlock
        ) revert InvalidWithdrawalTime();

        if (block.timestamp < unlockTimestamp && msg.sender != escrowImmutables.taker) revert InvalidCaller();

        _checkSecretAndTransfer(
            secret,
            escrowImmutables.hashlock,
            escrowImmutables.maker,
            escrowImmutables.token,
            escrowImmutables.amount
        );
        (bool success, ) = msg.sender.call{value: escrowImmutables.safetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    function cancelDst() external {
        DstEscrowImmutables calldata escrowImmutables = dstEscrowImmutables();
        uint256 finalityTimestamp = escrowImmutables.deployedAt + escrowImmutables.timelocks.finality;
        if (block.timestamp < finalityTimestamp + escrowImmutables.timelocks.unlock + escrowImmutables.timelocks.publicUnlock) {
            revert InvalidCancellationTime();
        }

        IERC20(escrowImmutables.token).safeTransfer(
            escrowImmutables.taker,
            escrowImmutables.amount
        );

        (bool success, ) = msg.sender.call{value: escrowImmutables.safetyDeposit}("");
        if (!success) revert NativeTokenSendingFailure();
    }

    function srcEscrowImmutables() public pure returns (SrcEscrowImmutables calldata) {
        SrcEscrowImmutables calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly { data := offset }
        return data;
    }

    function dstEscrowImmutables() public pure returns (DstEscrowImmutables calldata) {
        DstEscrowImmutables calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly { data := offset }
        return data;
    }

    function _isValidSecret(bytes32 secret, bytes32 hashlock) internal pure returns (bool) {
        return keccak256(abi.encode(secret)) == hashlock;
    }

    function _checkSecretAndTransfer(bytes32 secret, bytes32 hashlock, address recipient, address token, uint256 amount) internal {
        if (!_isValidSecret(secret, hashlock)) revert InvalidSecret();
        IERC20(token).safeTransfer(recipient, amount);
    }
}
