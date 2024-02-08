// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

struct PackedAddresses {
    // 20 most significant bytes of the maker address + 2 empty bytes + 10 bytes of the taker address
    uint256 addressesPart1;
    // 10 most significant bytes of the taker address + 2 empty bytes + 20 bytes of the token address
    uint256 addressesPart2;
}

/**
 * @title Packed Addresses library
 * @notice Library to pack 3 addresses into 2 uint256 values.
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

    function _maker(uint256 addressesPart1) internal pure returns (address) {
        // 96 = 2 empty bytes + 10 bytes of the taker address
        return address(uint160(addressesPart1 >> 96));
    }

    function _taker(uint256 addressesPart1, uint256 addressesPart2) internal pure returns (address) {
        // 80 = 10 bytes of the taker address from addressesPart2, 176 = 2 empty bytes + 20 bytes of the token address
        return address(uint160((addressesPart1 << 80) | (addressesPart2 >> 176)));
    }

    function _token(uint256 addressesPart2) internal pure returns (address) {
        return address(uint160(addressesPart2));
    }
}
