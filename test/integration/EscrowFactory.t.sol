// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IEscrowFactory } from "contracts/EscrowFactory.sol";
import { EscrowSrc, IEscrowSrc } from "contracts/EscrowSrc.sol";
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
        // uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        // uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;
        
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            EscrowSrc srcClone
        ) = _prepareDataSrc(secret, srcAmount, dstAmount, uint256(srcAmount) * 10 / 100, uint256(dstAmount) * 10 / 100, address(0), false);

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

        {
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
        }

        // assertEq(usdc.balanceOf(address(srcClone)), srcAmount2);
        // assertEq(address(srcClone).balance, uint256(srcAmount) * 10 / 100);
        IEscrowSrc.EscrowImmutables memory returnedImmutables = srcClone.escrowImmutables();
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
            EscrowSrc srcClone
        ) = _prepareDataSrc(SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false);

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
