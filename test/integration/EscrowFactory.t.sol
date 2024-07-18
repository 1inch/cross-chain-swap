// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IEscrowFactory } from "../../contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "../../contracts/interfaces/IBaseEscrow.sol";

import { Address, AddressLib, BaseSetup, IOrderMixin, TakerTraits } from "../utils/BaseSetup.sol";

contract IntegrationEscrowFactoryTest is BaseSetup {
    using AddressLib for Address;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMakerInt(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrc(
            keccak256(abi.encode(secret)),
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0),
            false, // fakeOrder
            false // allowMultipleFills
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
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

            assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        }

        assertEq(usdc.balanceOf(address(srcClone)), srcAmount);
        assertEq(address(srcClone).balance, srcSafetyDeposit);
    }

    function test_DeployCloneForMakerNonWhitelistedResolverInt() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            IBaseEscrow.Immutables memory immutables
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        immutables.taker = Address.wrap(uint160(charlie.addr));
        srcClone = IBaseEscrow(escrowFactory.addressOfEscrowSrc(immutables));

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
            (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
            assertEq(success, true);

            uint256 resolverCredit = feeBank.availableCredit(bob.addr);
            inch.mint(charlie.addr, 1000 ether);

            vm.startPrank(charlie.addr);
            inch.approve(address(feeBank), 1000 ether);
            feeBank.deposit(10 ether);
            limitOrderProtocol.fillOrderArgs(
                order,
                r,
                vs,
                MAKING_AMOUNT, // amount
                takerTraits,
                args
            );
            vm.stopPrank();

            assertLt(feeBank.availableCredit(charlie.addr), resolverCredit);
        }

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function test_NoInsufficientBalanceDeploymentForMakerInt() public {
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IBaseEscrow srcClone,
            /* IBaseEscrow.Immutables memory immutables */
        ) = _prepareDataSrc(HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, orderHash);
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
