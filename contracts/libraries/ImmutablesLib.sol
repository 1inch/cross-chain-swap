// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Library for escrow immutables.
 * @custom:security-contact security@1inch.io
 */
library ImmutablesLib {
    using Math for uint256;

    uint256 internal constant ESCROW_IMMUTABLES_SIZE = 0x1A0;

    /// @dev Allows fees in range [1e-5, 0.65535]
    uint256 internal constant _BASE_1E5 = 1e5;
    uint256 internal constant _BASE_1E2 = 100;

    /**
     * @notice Returns the hash of the immutables.
     * @param immutables The immutables to hash.
     * @return ret The computed hash.
     */
    function hash(IBaseEscrow.Immutables calldata immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, immutables, ESCROW_IMMUTABLES_SIZE)
            ret := keccak256(ptr, ESCROW_IMMUTABLES_SIZE)
        }
    }

    /**
     * @notice Returns the hash of the immutables.
     * @param immutables The immutables to hash.
     * @return ret The computed hash.
     */
    function hashMem(IBaseEscrow.Immutables memory immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            ret := keccak256(immutables, ESCROW_IMMUTABLES_SIZE)
        }
    }
    /**
     * @notice Calculates the integrator and protocol fee amounts based on immutable fee configuration.
     * @dev This function assumes that `integratorFee`, `protocolFee`, and `integratorShare`
     *      are expressed in basis points (1e5 = 100%) and percentages (1e2 = 100%) respectively.
     *
     *      The total fee is proportionally split between the protocol and integrator.
     *      The integrator only keeps a portion of their assigned fee based on `integratorShare`.
     *
     * @param immutables Struct containing:
     *        - `amount`: the total amount on which fees are based,
     *        - `integratorFee`: fee requested by the integrator (in basis points),
     *        - `protocolFee`: fee for the protocol (in basis points),
     *        - `integratorShare`: % share of the integratorFee retained by the integrator.
     *
     * @return integratorFeeAmount Final amount retained by the integrator
     *         (after applying the integratorShare to the integratorFeeTotal).
     * @return protocolFeeAmount Final amount allocated to the protocol
     *         (includes its own fee plus the remaining part of the integrator’s fee).
     */
    function getFeeAmounts(
        IBaseEscrow.Immutables calldata immutables
    ) internal pure returns (uint256 integratorFeeAmount, uint256 protocolFeeAmount) {
        uint256 denominator = _BASE_1E5 + immutables.integratorFee + immutables.protocolFee;
        uint256 integratorFeeTotal = immutables.amount.mulDiv(immutables.integratorFee, denominator);
        integratorFeeAmount = integratorFeeTotal.mulDiv(immutables.integratorShare, _BASE_1E2);
        protocolFeeAmount = immutables.amount.mulDiv(immutables.protocolFee, denominator) + integratorFeeAmount;
        integratorFeeAmount = integratorFeeTotal - integratorFeeAmount;
    }
}
