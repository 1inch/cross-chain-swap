// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { PackedAddresses, PackedAddressesLib } from "contracts/libraries/PackedAddressesLib.sol";

contract PackedAddressesLibMock {
    function maker(PackedAddresses calldata packedAddresses) external pure returns (address) {
        return PackedAddressesLib.maker(packedAddresses);
    }

    function taker(PackedAddresses calldata packedAddresses) external pure returns (address) {
        return PackedAddressesLib.taker(packedAddresses);
    }

    function token(PackedAddresses calldata packedAddresses) external pure returns (address) {
        return PackedAddressesLib.token(packedAddresses);
    }
}
