// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IEscrowFactory {
    // TODO: is it possible to optimise this?
    struct Timelocks {
        uint256 finality;
        uint256 unlock;
        uint256 publicUnlock;
    }

    struct Conditions {
        uint256 chainId;
        address token;
        uint256 amount;
        Timelocks timelocks;
    }

    struct SrcEscrowParams {
        uint256 hashlock;
        Conditions srcConditions;
        Conditions dstConditions;
    }

    struct DstEscrowParams {
        uint256 hashlock;
        Conditions conditions;
    }

    // TODO: remove this?
    event EscrowCreated(address escrow);
}
