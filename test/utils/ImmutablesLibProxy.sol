// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";

contract ImmutablesLibProxy {
    function hash(IBaseEscrow.Immutables calldata immutables) external pure returns(bytes32) {
        return ImmutablesLib.hash(immutables);
    }

    function hash(IEscrowDst.ImmutablesDst calldata immutables) external pure returns(bytes32) {
        return ImmutablesLib.hash(immutables);
    }

    function hashes(IBaseEscrow.Immutables calldata src, IEscrowDst.ImmutablesDst calldata dst)
        external
        pure
        returns (bytes32, bytes32)
    {
        return (ImmutablesLib.hash(src), ImmutablesLib.hash(ImmutablesLib.asImmutables(dst)));
    }
}