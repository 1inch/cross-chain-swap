// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEscrow {
    // TODO: is it possible to optimise this?
    // Timelocks represent the duration of each period, in seconds
    struct SrcTimelocks {
        uint256 finality;
        uint256 publicUnlock;
    }

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
        uint256 hashlock;
        uint256 dstChainId;
        address dstToken;
        uint256 safetyDeposit;
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
        uint256 hashlock;
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
}
