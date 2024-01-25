// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Timelocks } from "../libraries/TimelocksLib.sol";

interface IEscrow {
    // Data for the source chain order immutables.
    struct SrcEscrowImmutables {
        address maker;
        address taker;
        uint256 srcChainId;
        address srcToken;
        uint256 srcAmount;
        uint256 dstAmount;
         // Hash of the secret.
        bytes32 hashlock;
        uint256 dstChainId;
        address dstToken;
        // 16 bytes for srcSafetyDeposit and 16 bytes for dstSafetyDeposit.
        uint256 deposits;
        Timelocks timelocks;
    }

    /**
     * Data for the destination chain order immutables.
     * chainId, token, amount and safetyDeposit relate to the destination chain.
    */
    struct DstEscrowImmutables {
        uint256 chainId;
        // Hash of the secret.
        bytes32 hashlock;
        address maker;
        address taker;
        address token;
        uint256 amount;
        uint256 safetyDeposit;
        Timelocks timelocks;
    }

    error InvalidCaller();
    error InvalidCancellationTime();
    error InvalidSecret();
    error InvalidWithdrawalTime();
    error NativeTokenSendingFailure();

    /**
     * @notice Withdraws funds to the taker on the source chain.
     * @dev Withdrawal can only be made by the taker during the withdrawal period and with secret
     * with hash matches the hashlock.
     * The safety deposit is sent to the caller (taker).
     * @param secret The secret that unlocks the escrow.
     */
    function withdrawSrc(bytes32 secret) external;

    /**
     * @notice Cancels the escrow on the source chain and returns tokens to the maker.
     * @dev The escrow can only be cancelled by taker during the private cancel period or
     * by anyone during the public cancel period.
     * The safety deposit is sent to the caller.
     */
    function cancelSrc() external;

    /**
     * @notice Withdraws funds to the maker on the destination chain.
     * @dev Withdrawal can only be made by taker during the private withdrawal period or by anyone
     * during the public withdrawal period. In both cases, a secret with hash matching the hashlock must be provided.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     */
    function withdrawDst(bytes32 secret) external;

    /**
     * @notice Cancels the escrow on the destination chain and returns tokens to the taker.
     * @dev The escrow can only be cancelled by the taker during the cancel period.
     * The safety deposit is sent to the caller (taker).
     */
    function cancelDst() external;

    /**
     * @notice Returns the immutable parameters of the escrow contract on the source chain.
     * @dev The immutables are stored at the end of the proxy clone contract bytecode and
     * are added to the calldata each time the proxy clone function is called.
     * @return The immutables of the escrow contract.
     */
    function srcEscrowImmutables() external pure returns (SrcEscrowImmutables calldata);

    /**
     * @notice Returns the immutable parameters of the escrow contract on the destination chain.
     * @dev The immutables are stored at the end of the proxy clone contract bytecode and
     * are added to the calldata each time the proxy clone function is called.
     * @return The immutables of the escrow contract.
     */
    function dstEscrowImmutables() external pure returns (DstEscrowImmutables calldata);
}
