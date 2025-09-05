// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library SafeSendLib {
    function safeSend(address to, uint256 amount) internal {
        assembly ("memory-safe") {
            mstore(0, to)
            mstore8(11, 0x73) // 0x73 = PUSH20 opcode
            mstore8(32, 0xff) // 0xff = SELFDESTRUCT opcode
            pop(create(amount, 11, 22))
        }
    }
}
