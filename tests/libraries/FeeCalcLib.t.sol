// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";

import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";
import { BaseSetup } from "../utils/BaseSetup.sol";

contract FeeCalcLibTest is BaseSetup {
    using ImmutablesLib for IBaseEscrow.Immutables;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */
    function test_getFeeAmounts() public view {
        (IBaseEscrow.Immutables memory immutables,,) = _prepareDataDst();

        assertEq(FEES_AMOUNT, immutables.integratorFeeAmount() + immutables.protocolFeeAmount());
        assertEq(PROTOCOL_FEE_AMOUNT, immutables.protocolFeeAmount());
    }
    /* solhint-enable func-name-mixedcase */
}
