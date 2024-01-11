// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEscrow {
    // TODO: is it possible to optimise this?
    /**
     * Timelocks for the source chain.
     * finality: The duration of the chain finality period.
     * publicUnlock: The duration of the period when anyone with a secret can withdraw tokens for the taker.
     * cancel: The duration of the period when escrow can only be cancelled by the taker.
     */
    struct SrcTimelocks {
        uint256 finality;
        uint256 publicUnlock;
        uint256 cancel;
    }

    /**
     * Timelocks for the destination chain.
     * finality: The duration of the chain finality period.
     * unlock: The duration of the period when only the taker with a secret can withdraw tokens for the maker.
     * publicUnlock publicUnlock: The duration of the period when anyone with a secret can withdraw tokens for the maker.
     */
    struct DstTimelocks {
        uint256 finality;
        uint256 unlock;
        uint256 publicUnlock;
    }
    struct InteractionParams {
        address maker;
        address taker;
        uint256 srcChainId;
        address srcToken;
        uint256 srcAmount;
        uint256 dstAmount;
    }

    struct ExtraDataParams {
        bytes32 hashlock;
        uint256 dstChainId;
        address dstToken;
        uint256 srcSafetyDeposit;
        uint256 dstSafetyDeposit;
        SrcTimelocks srcTimelocks;
        DstTimelocks dstTimelocks;
    }

    struct SrcEscrowImmutables {
        uint256 deployedAt;
        InteractionParams interactionParams;
        ExtraDataParams extraDataParams;
    }

    struct DstEscrowImmutables {
        uint256 deployedAt;
        bytes32 hashlock;
        address maker;
        address taker;
        uint256 chainId;
        address token;
        uint256 amount;
        uint256 safetyDeposit;
        DstTimelocks timelocks;
    }

    error InvalidCaller();
    error InvalidCancellationTime();
    error InvalidSecret();
    error InvalidWithdrawalTime();
    error NativeTokenSendingFailure();
}
