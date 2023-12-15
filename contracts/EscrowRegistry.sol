// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Clone } from "clones-with-immutable-args/Clone.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

contract EscrowRegistry is Clone {
    function srcEscrowImmutables() public pure returns (IEscrowFactory.SrcEscrowImmutables memory) {
        IEscrowFactory.SrcEscrowImmutables calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data := offset
        }
        return data;
    }

    function dstEscrowImmutables() public pure returns (IEscrowFactory.DstEscrowImmutables memory) {
        IEscrowFactory.DstEscrowImmutables calldata data;
        uint256 offset = _getImmutableArgsOffset();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data := offset
        }
        return data;
    }
}
