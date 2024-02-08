// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

contract ERC20True {
    function transfer(address, uint256) public pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) public pure returns (bool) {
        return true;
    }

    function approve(address, uint256) public pure returns (bool) {
        return true;
    }

    function balanceOf(address) public pure returns (uint256) {
        return 0;
    }

    function allowance(address, address) public pure returns (uint256) {
        return 0;
    }
}
