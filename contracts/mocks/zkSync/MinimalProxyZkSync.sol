// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

contract MinimalProxyZkSync {
    address private immutable _IMPLEMENTATION;

    constructor(address implementation) {
        _IMPLEMENTATION = implementation;
    }

    fallback() external payable {
        address _impl = _IMPLEMENTATION;
        assembly ("memory-safe") {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
