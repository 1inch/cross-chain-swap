// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Clone } from "clones-with-immutable-args/Clone.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

contract EscrowRegistry is Clone {
    function srcEscrowParams() public pure returns (IEscrowFactory.SrcEscrowParams memory) {
        IEscrowFactory.SrcEscrowParams calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data := offset
        }
        return data;
    }

    function dstEscrowParams() public pure returns (IEscrowFactory.DstEscrowParams memory) {
        IEscrowFactory.DstEscrowParams calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data := offset
        }
        return data;
    }
}
