// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { PackedAddresses, PackedAddressesLib } from "contracts/libraries/PackedAddressesLib.sol";

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
        return PackedAddressesLib._maker(packedAddresses.addressesPart1);
    }

    /**
     * @notice Returns the taker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The taker address.
     */
    function taker(PackedAddresses memory packedAddresses) internal pure returns (address) {
        return PackedAddressesLib._taker(packedAddresses.addressesPart1, packedAddresses.addressesPart2);
    }

    /**
     * @notice Returns the taker address from the packed addresses.
     * @param packedAddresses Packed addresses.
     * @return The taker address.
     */
    function token(PackedAddresses memory packedAddresses) internal pure returns (address) {
        return PackedAddressesLib._token(packedAddresses.addressesPart2);
    }
}
