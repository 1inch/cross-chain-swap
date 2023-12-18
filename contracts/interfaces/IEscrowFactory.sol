// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IEscrowFactory {
    // TODO: is it possible to optimise this?
    struct Timelocks {
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
        Timelocks srcTimelocks;
        Timelocks dstTimelocks;
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
        uint256 chainId;
        address token;
        uint256 amount;
        uint256 safetyDeposit;
        Timelocks timelocks;
    }

    struct DstEscrowImmutablesCreation {
        uint256 hashlock;
        address maker;
        address token;
        uint256 amount;
        uint256 safetyDeposit;
        Timelocks timelocks;
    }

    error InsufficientEscrowBalance();
    error OnlyLimitOrderProtocol();
}
