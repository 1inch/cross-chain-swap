
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IBaseEscrow } from "../../contracts/interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "../../contracts/libraries/ImmutablesLib.sol";

contract FeeProxy {
    function getFeeAmounts(IBaseEscrow.ImmutablesDst memory m) external view returns (uint256, uint256) {
        return this.getFeeAmountsCall(m);
    }

    function getFeeAmountsCall(IBaseEscrow.ImmutablesDst calldata m) external pure returns (uint256, uint256) {
        return ImmutablesLib.getFeeAmounts(m);
    }
}