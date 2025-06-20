// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { BaseSetup } from "../utils/BaseSetup.sol";

contract ImmutablesLibTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */
    function test_getFeeAmounts() public {
        (IBaseEscrow.ImmutablesDst memory immutables,,) = _prepareDataDst();

        (uint256 integratorFeeAmount, uint256 protocolFeeAmount) = feeProxy.getFeeAmounts(immutables);

        assertEq(FEES_AMOUNT, integratorFeeAmount + protocolFeeAmount);
        assertEq(PROTOCOL_FEE_AMOUNT, protocolFeeAmount);
    }

    function testFuzz_getFeeAmounts(uint256 amount, uint256 protocolFee, uint256 integratorFee, uint256 integratorShares) public {
        protocolFee = bound(protocolFee, 0, BASE_1E5/2);
        integratorFee = bound(integratorFee, 0, BASE_1E5/2);
        integratorShares = bound(integratorShares, 0, BASE_1E2);

        (IBaseEscrow.ImmutablesDst memory immutables,,) = _prepareDataDstCustom(
            HASHED_SECRET, 
            amount, 
            alice.addr, 
            bob.addr, 
            address(0x00), 
            DST_SAFETY_DEPOSIT,
            protocolFee, 
            integratorFee, 
            integratorShares
        );

        (uint256 integratorFeeAmount, uint256 protocolFeeAmount) = feeProxy.getFeeAmounts(immutables);

        uint256 denominator = (BASE_1E5 + integratorFee + protocolFee);
        uint256 totalFeesAmountRef = Math.mulDiv(amount, integratorFee + protocolFee, denominator);
        uint256 protocolFeeAmountRef = Math.mulDiv(
            amount, 
            Math.mulDiv(integratorFee, BASE_1E2 - integratorShares, BASE_1E2) + protocolFee, denominator
        );

        uint256 tolerance = Math.max(Math.mulDiv(totalFeesAmountRef, integratorShares, BASE_1E2), BASE_1E2);

        assertApproxEqAbs(totalFeesAmountRef, integratorFeeAmount + protocolFeeAmount, 1);
        assertApproxEqAbs(protocolFeeAmountRef, protocolFeeAmount, tolerance);
    }
}