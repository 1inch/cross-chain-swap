// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

library FeeCalcLib {
    using Math for uint256;

    /// @dev Allows fees in range [1e-5, 0.65535]
    uint256 internal constant _BASE_1E5 = 1e5;
    uint256 internal constant _BASE_1E2 = 100;

    /**
     * @notice Calculates the actual integrator and protocol fee amounts from the given order parameters.
     * @dev Assumes:
     *      - `integratorFee` and `protocolFee` are expressed in basis points (1e5 = 100%),
     *      - `integratorShare` is expressed in percentage (1e2 = 100%).
     *
     *      The total fee is split proportionally between the protocol and integrator,
     *      based on the fee configuration. The integrator receives a share of their allocated fee,
     *      and the remainder is added to the protocol's fee.
     *
     *      protocolFeeAmount = protocol's portion + (1 - integratorShare) of integrator fee
     *      integratorFeeAmount = integratorShare of integrator fee
     *
     * @param amount The order amount used to calculate fees,
     * @param protocolFee Protocol fee (in basis points),
     * @param integratorFee Integrator fee (in basis points),
     * @param integratorShare Share (%) of integratorFee the integrator retains.
     * @return integratorFeeAmount The final amount retained by the integrator.
     * @return protocolFeeAmount The final amount allocated to the protocol,
     *         including its own fee and the leftover part of the integrator's fee.
     */
    function getFeeAmounts(
        uint256 amount,
        uint256 protocolFee,
        uint256 integratorFee,
        uint256 integratorShare
    ) internal pure returns (uint256 integratorFeeAmount, uint256 protocolFeeAmount) {
        uint256 denominator = _BASE_1E5 + integratorFee + protocolFee;
        uint256 integratorFeeTotal = amount.mulDiv(integratorFee, denominator);
        integratorFeeAmount = integratorFeeTotal.mulDiv(integratorShare, _BASE_1E2);
        protocolFeeAmount = amount.mulDiv(protocolFee, denominator) + integratorFeeTotal - integratorFeeAmount;
    }
}
