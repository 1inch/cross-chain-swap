// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { PackedAddresses } from "contracts/libraries/PackedAddressesLib.sol";

library PackedAddressesMemLib {
    /**
     * @notice Packs the addresses into two bytes32 values.
     * @param makerAddr The maker address.
     * @param takerAddr The taker address.
     * @param tokenAddr The token address.
     * @return The packed addresses.
     */
    function packAddresses(address makerAddr, address takerAddr, address tokenAddr) internal pure returns (PackedAddresses memory) {
        return PackedAddresses({
            addressesPart1: bytes32(bytes20(makerAddr)) | bytes32(bytes20(takerAddr)) >> 176,
            addressesPart2: bytes32(bytes20(takerAddr)) << 80 | bytes32(bytes20(tokenAddr)) >> 96
        });
    }

    /**
     * @notice Returns the maker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The maker address.
     */
    function maker(PackedAddresses memory packedAddresses) internal pure returns (address) {
        // 20 least significant bytes of addressesPart1
        return address(bytes20(packedAddresses.addressesPart1));
    }

    /**
     * @notice Returns the taker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The taker address.
     */
    function taker(PackedAddresses memory packedAddresses) internal pure returns (address) {
        // 176 = 20 bytes of the maker address + 2 empty bytes, 80 = 10 bytes for the taker address from addressesPart1
        return address(bytes20(packedAddresses.addressesPart1 << 176 | packedAddresses.addressesPart2 >> 80));
    }

    /**
     * @notice Returns the taker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The taker address.
     */
    function token(PackedAddresses memory packedAddresses) internal pure returns (address) {
        // 96 = 10 bytes of the taker address + 2 empty bytes
        return address(bytes20(packedAddresses.addressesPart2 << 96));
    }
}
