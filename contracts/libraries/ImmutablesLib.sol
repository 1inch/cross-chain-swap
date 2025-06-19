// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { PackedFeesLib } from "./PackedFeesLib.sol";

/**
 * @title Library for escrow immutables.
 * @custom:security-contact security@1inch.io
 */
library ImmutablesLib {
    using Math for uint256;
    using PackedFeesLib for uint256;

    uint256 internal constant ESCROW_IMMUTABLES_SIZE = 0x160;

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

    function getFeeAmounts(
        IBaseEscrow.Immutables calldata immutables
    ) internal pure returns (uint256 integratorFeeAmount, uint256 protocolFeeAmount) {
        (uint256 protocolFee, uint256 integratorFee, uint256 integratorShare) = immutables.packedFees.unpack();
        uint256 denominator = _BASE_1E5 + integratorFee + protocolFee;
        uint256 integratorFeeTotal = immutables.amount.mulDiv(integratorFee, denominator);
        integratorFeeAmount = integratorFeeTotal.mulDiv(integratorShare, _BASE_1E2);
        protocolFeeAmount = immutables.amount.mulDiv(protocolFee, denominator) + integratorFeeAmount;
        integratorFeeAmount = integratorFeeTotal - integratorFeeAmount;
    }
}
