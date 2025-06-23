// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { BaseSetup } from "../utils/BaseSetup.sol";

contract FeeCalcLibTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */
    function test_getFeeAmounts() public {
        (IEscrowDst.ImmutablesDst memory immutables,,) = _prepareDataDst();

        assertEq(FEES_AMOUNT, immutables.integratorFeeAmount + immutables.protocolFeeAmount);
        assertEq(PROTOCOL_FEE_AMOUNT, immutables.protocolFeeAmount);
    }

    function testFuzz_getFeeAmounts(uint256 amount, uint256 protocolFee, uint256 integratorFee, uint256 integratorShares) public {
        protocolFee = bound(protocolFee, 100, BASE_1E5/2);
        integratorFee = bound(integratorFee, 100, BASE_1E5/2);
        integratorShares = bound(integratorShares, 0, BASE_1E2);

        (IEscrowDst.ImmutablesDst memory immutables,,) = _prepareDataDstCustom(
            HASHED_SECRET, 
            amount, 
            alice.addr, 
            bob.addr, 
            address(0x00), 
            DST_SAFETY_DEPOSIT,
            protocolFee, 
            integratorFee, 
            integratorShares,
            BASE_1E2,
            true
        );

        uint256 denominator = (BASE_1E5 + integratorFee + protocolFee);
        uint256 totalFeesAmountRef = Math.mulDiv(amount, integratorFee + protocolFee, denominator);
        uint256 protocolFeeAmountRef = Math.mulDiv(
            amount, 
            Math.mulDiv(integratorFee, BASE_1E2 - integratorShares, BASE_1E2) + protocolFee, denominator
        );

        uint256 tolerance = Math.max(Math.mulDiv(totalFeesAmountRef, integratorShares, BASE_1E2), BASE_1E2);

        assertApproxEqAbs(totalFeesAmountRef, immutables.integratorFeeAmount + immutables.protocolFeeAmount, 1);
        assertApproxEqAbs(protocolFeeAmountRef, immutables.protocolFeeAmount, tolerance);
    }
}