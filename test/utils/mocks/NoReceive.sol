// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

contract NoReceive {
    error NativeTokenCantBeReceived();

    receive() external payable {
        revert NativeTokenCantBeReceived();
    }
}