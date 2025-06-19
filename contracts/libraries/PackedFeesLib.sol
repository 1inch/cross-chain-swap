// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title PackedFeesLib
/// @notice Pack/unpack protocolFee, integratorFee и integratorShare to single uint256
library PackedFeesLib {
    uint256 internal constant SHIFT_INTEGRATOR_FEE = 16;
    uint256 internal constant SHIFT_INTEGRATOR_SHARE = 32;

    uint256 internal constant MASK_16 = 0xFFFF;
    uint256 internal constant MASK_8 = 0xFF;

    /**
     * @notice Returns packed value of fees.
     * @param protocolFee 2 bytes protocol fee value.
     * @param integratorFee 2 bytes integrator fee value.
     * @param integratorShare 1 byte integrator revshare value.
     * @return packed packed fees value.
     */
    function pack(
        uint256 protocolFee,
        uint256 integratorFee,
        uint256 integratorShare
    ) internal pure returns (uint256 packed) {
        packed =
            protocolFee |
            (integratorFee << SHIFT_INTEGRATOR_FEE) |
            (integratorShare << SHIFT_INTEGRATOR_SHARE);
    }

    /// @notice Returns protocolFee
    function getProtocolFee(uint256 packed) internal pure returns (uint256) {
        return packed & MASK_16;
    }

    /// @notice Returns integratorFee
    function getIntegratorFee(uint256 packed) internal pure returns (uint256) {
        return (packed >> SHIFT_INTEGRATOR_FEE) & MASK_16;
    }

    /// @notice Returns integratorShare
    function getIntegratorShare(uint256 packed) internal pure returns (uint256) {
        return (packed >> SHIFT_INTEGRATOR_SHARE) & MASK_8;
    }

    /**
     * @notice Unpack protocol and integrator fees paramenters from 32 bytes value.
     * @param packed 32 bytes encoded fees value.
     * @return protocolFee Unpacked protocol fee percentage in 1e5.
     * @return integratorFee Unpacked integrator fee percentage in 1e5.
     * @return integratorShare Unpacked integrator revshare value percentage in 1e2.
     */
    function unpack(uint256 packed)
        internal
        pure
        returns (uint256 protocolFee, uint256 integratorFee, uint256 integratorShare)
    {
        protocolFee = getProtocolFee(packed);
        integratorFee = getIntegratorFee(packed);
        integratorShare = getIntegratorShare(packed);
    }
}