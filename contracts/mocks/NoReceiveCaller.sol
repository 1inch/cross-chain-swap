// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { RevertReasonForwarder } from "solidity-utils/libraries/RevertReasonForwarder.sol";

contract NoReceiveCaller {
    function arbitraryCall(address target, bytes calldata arguments) external {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = target.call(arguments);
        if (!success) RevertReasonForwarder.reRevert();
    }
}
