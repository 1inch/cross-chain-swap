// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";

contract Utils is Test {
    // solhint-disable private-vars-leading-underscore
    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    function getNextUserAddress() external returns (VmSafe.Wallet memory) {
        VmSafe.Wallet memory user = vm.createWallet(uint256(nextUser));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    // create users with 100 ETH balance each
    function createUsers(uint256 userNum) external returns (VmSafe.Wallet[] memory) {
        VmSafe.Wallet[] memory users = new VmSafe.Wallet[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            VmSafe.Wallet memory user = this.getNextUserAddress();
            vm.deal(user.addr, 100 ether);
            users[i] = user;
        }

        return users;
    }

    // move block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }
}
