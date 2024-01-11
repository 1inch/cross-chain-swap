// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IEscrow } from "./IEscrow.sol";

interface IEscrowFactory {
    struct DstEscrowImmutablesCreation {
        bytes32 hashlock;
        address maker;
        address taker;
        address token;
        uint256 amount;
        uint256 safetyDeposit;
        IEscrow.DstTimelocks timelocks;
        uint256 srcCancellationTimestamp;
    }

    error InsufficientEscrowBalance();
    error InvalidCreationTime();
}
