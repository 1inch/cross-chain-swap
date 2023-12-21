// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IEscrowRegistry {
    error InvalidCaller();
    error InvalidCancellationTime();
    error InvalidSecret();
    error InvalidWithdrawalTime();
}
