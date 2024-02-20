// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { PackedAddresses } from "contracts/libraries/PackedAddressesLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { PackedAddressesMemLib } from "../utils/libraries/PackedAddressesMemLib.sol";
import { PackedAddressesLibMock } from "../utils/mocks/PackedAddressesLibMock.sol";

contract PackedAddressesLibTest is BaseSetup {
    PackedAddressesLibMock public packedAddressesLibMock;

    function setUp() public virtual override {
        BaseSetup.setUp();
        packedAddressesLibMock = new PackedAddressesLibMock();
    }

    /* solhint-disable func-name-mixedcase */

    function test_getters() public {
        PackedAddresses memory packedAddresses = PackedAddressesMemLib.packAddresses(
            alice.addr,
            bob.addr,
            address(inch)
        );
        assertEq(packedAddressesLibMock.maker(packedAddresses), alice.addr);
        assertEq(packedAddressesLibMock.taker(packedAddresses), bob.addr);
        assertEq(packedAddressesLibMock.token(packedAddresses), address(inch));
    }

    /* solhint-enable func-name-mixedcase */
}
