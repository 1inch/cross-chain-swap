// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IEscrowFactory } from "contracts/EscrowFactory.sol";
import { Escrow, IEscrow } from "contracts/Escrow.sol";
import { PackedAddressesMemLib } from "../utils/libraries/PackedAddressesMemLib.sol";

import { Address, AddressLib, BaseSetup, IOrderMixin, TakerTraits } from "../utils/BaseSetup.sol";

contract IntegrationEscrowFactoryTest is BaseSetup {
    using AddressLib for Address;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMakerInt(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            Escrow srcClone
        ) = _prepareDataSrc(secret, srcAmount, dstAmount, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(srcClone), // target
            extension, // extension
            "", // interaction
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: uint64(srcAmount) * 10 / 100 }("");
        assertEq(success, true);

        uint256 resolverCredit = feeBank.availableCredit(bob.addr);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            srcAmount, // amount
            takerTraits,
            args
        );

        assertLt(feeBank.availableCredit(bob.addr), resolverCredit);

        IEscrow.SrcEscrowImmutables memory returnedImmutables = srcClone.srcEscrowImmutables();
        assertEq(returnedImmutables.hashlock, keccak256(abi.encodePacked(secret)));
        assertEq(PackedAddressesMemLib.taker(returnedImmutables.packedAddresses), bob.addr);
        assertEq(returnedImmutables.dstToken.get(), address(dai));
    }

    function test_NoInsufficientBalanceDeploymentForMakerInt() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            Escrow srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = _buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            extension, // extension
            "", // interaction
            0 // threshold
        );

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            MAKING_AMOUNT, // amount
            takerTraits,
            args
        );
    }

    /* solhint-enable func-name-mixedcase */
}
