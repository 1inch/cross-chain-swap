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

    uint256 internal constant ESCROW_IMMUTABLES_SIZE = 0x100;
    uint256 internal constant ESCROW_IMMUTABLES_DST_SIZE = 0x1A0;

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
     * @notice Returns the hash of the immutables on dst chain.
     * @param immutables The immutables to hash.
     * @return ret The computed hash.
     */
    function hash(IBaseEscrow.ImmutablesDst calldata immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, immutables, ESCROW_IMMUTABLES_DST_SIZE)
            ret := keccak256(ptr, ESCROW_IMMUTABLES_DST_SIZE)
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
     * @notice Returns the hash of the immutables.
     * @param immutables The immutables to hash.
     * @return ret The computed hash.
     */
    function hashMem(IBaseEscrow.ImmutablesDst memory immutables) internal pure returns(bytes32 ret) {
        assembly ("memory-safe") {
            ret := keccak256(immutables, ESCROW_IMMUTABLES_DST_SIZE)
        }
    }

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
     * @param immutables The full immutable order data, including:
     *        - `core.amount`: the order amount used to calculate fees,
     *        - `protocolFee`: protocol fee (in basis points),
     *        - `integratorFee`: integrator fee (in basis points),
     *        - `integratorShare`: share (%) of integratorFee the integrator retains.
     *
     * @return integratorFeeAmount The final amount retained by the integrator.
     * @return protocolFeeAmount The final amount allocated to the protocol,
     *         including its own fee and the leftover part of the integrator's fee.
     */
    function getFeeAmounts(
        IBaseEscrow.ImmutablesDst calldata immutables
    ) internal pure returns (uint256 integratorFeeAmount, uint256 protocolFeeAmount) {
        uint256 denominator = _BASE_1E5 + immutables.integratorFee + immutables.protocolFee;
        uint256 integratorFeeTotal = immutables.core.amount.mulDiv(immutables.integratorFee, denominator);
        integratorFeeAmount = integratorFeeTotal.mulDiv(immutables.integratorShare, _BASE_1E2);
        protocolFeeAmount = immutables.core.amount.mulDiv(immutables.protocolFee, denominator) + integratorFeeTotal - integratorFeeAmount;
    }
}
