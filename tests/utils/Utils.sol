// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { CommonBase } from "forge-std/Base.sol";

contract Utils is CommonBase {
    struct Wallet {
        address addr;
        uint256 privateKey;
    }

    /* solhint-disable private-vars-leading-underscore */
    Wallet[] internal users;
    uint256 internal nextUser = uint256(keccak256(abi.encodePacked("user address")));
    /* solhint-enable private-vars-leading-underscore */

    function _getNextUserAddress() internal returns (Wallet memory) {
        address addr = vm.addr(nextUser);
        Wallet memory user = Wallet(addr, nextUser);
        nextUser = uint256(keccak256(abi.encodePacked(nextUser)));
        return user;
    }
    
    // create users with 100 ETH balance each
    function _createUsers(uint256 userNum) internal {
        users = new Wallet[](userNum);
        for (uint256 i = 0; i < userNum; i++) {
            Wallet memory user = _getNextUserAddress();
            vm.deal(user.addr, 100 ether);
            users[i] = user;
        }
    }
}
