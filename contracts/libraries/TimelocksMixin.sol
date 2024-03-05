// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IEscrow } from "../interfaces/IEscrow.sol";
import { Timelocks, TimelocksLib } from "./TimelocksLib.sol";

abstract contract TimelocksMixin {
    using TimelocksLib for Timelocks;

    modifier onlyAfter(TimelocksLib.Start epoch, bytes4 exception, IEscrow.Immutables calldata immutables) {
        if (block.timestamp < immutables.timelocks.get(epoch)) {
            _revertWithException(exception);
        }
        _;
    }

    modifier onlyBetween(TimelocksLib.Start start, TimelocksLib.Start stop, bytes4 exception, IEscrow.Immutables calldata immutables) {
        if (block.timestamp < immutables.timelocks.get(start)
            || block.timestamp >= immutables.timelocks.get(stop)) {
            _revertWithException(exception);
        }
        _;
    }

    function _revertWithException(bytes4 exception) private pure {
        assembly {
            mstore(0, exception)
            revert(0, 4)
        }
    }
}
