// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

struct PackedAddresses {
    // 20 least significant bytes of the maker address + 2 empty bytes + 10 bytes of the taker address
    bytes32 addressesPart1;
    // 10 least significant bytes of the taker address + 2 empty bytes + 20 bytes of the token address
    bytes32 addressesPart2;
}

/**
 * @title Packed Addresses library
 * @notice Library to pack 3 addresses into 2 bytes32 values.
 */
library PackedAddressesLib {
    /**
     * @notice Returns the maker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The maker address.
     */
    function maker(PackedAddresses calldata packedAddresses) internal pure returns (address) {
        return _maker(packedAddresses.addressesPart1);
    }

    /**
     * @notice Returns the taker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The taker address.
     */
    function taker(PackedAddresses calldata packedAddresses) internal pure returns (address) {
        return _taker(packedAddresses.addressesPart1, packedAddresses.addressesPart2);
    }

    /**
     * @notice Returns the taker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The taker address.
     */
    function token(PackedAddresses calldata packedAddresses) internal pure returns (address) {
        return _token(packedAddresses.addressesPart2);
    }

    function _maker(bytes32 addressesPart1) internal pure returns (address) {
        // 20 least significant bytes of addressesPart1
        return address(bytes20(addressesPart1));
    }

    function _taker(bytes32 addressesPart1, bytes32 addressesPart2) internal pure returns (address) {
        // 176 = 20 bytes of the maker address + 2 empty bytes, 80 = 10 bytes for the taker address from addressesPart1
        return address(bytes20(addressesPart1 << 176 | addressesPart2 >> 80));
    }

    function _token(bytes32 addressesPart2) internal pure returns (address) {
        // 96 = 10 bytes of the taker address + 2 empty bytes
        return address(bytes20(addressesPart2 << 96));
    }
}
