// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract IntegrationEscrowFactoryTest is BaseSetup {
    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMakerInt(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            keccak256(abi.encode(secret)),
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0), // receiver
            false, // fakeOrder
            false // allowMultipleFills
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(swapData.srcClone), // target
            swapData.extension, // extension
            "", // interaction
            0 // threshold
        );

        {
            (bool success,) = address(swapData.srcClone).call{ value: uint64(srcAmount) * 10 / 100 }("");
            assertEq(success, true);

            uint256 resolverCredit = feeBank.availableCredit(bob.addr);

            vm.prank(bob.addr);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                srcAmount, // amount
                takerTraits,
                args
            );

            assertEq(feeBank.availableCredit(bob.addr), resolverCredit);
        }

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);
    }

    function test_DeployCloneForMakerNonWhitelistedResolverInt() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        swapData.immutables.taker = Address.wrap(uint160(charlie.addr));
        address srcClone = escrowFactory.addressOfEscrowSrc(swapData.immutables);

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            srcClone, // target
            swapData.extension, // extension
            "", // interaction
            0 // threshold
        );

        {
            (bool success,) = srcClone.call{ value: SRC_SAFETY_DEPOSIT }("");
            assertEq(success, true);

            uint256 resolverCredit = feeBank.availableCredit(bob.addr);
            inch.mint(charlie.addr, 1000 ether);

            vm.startPrank(charlie.addr);
            inch.approve(address(feeBank), 1000 ether);
            feeBank.deposit(10 ether);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                MAKING_AMOUNT, // amount
                takerTraits,
                args
            );
            vm.stopPrank();

            assertLt(feeBank.availableCredit(charlie.addr), resolverCredit);
        }

        assertEq(usdc.balanceOf(srcClone), MAKING_AMOUNT);
        assertEq(srcClone.balance, SRC_SAFETY_DEPOSIT);
    }

    function test_NoInsufficientBalanceDeploymentForMakerInt() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension, // extension
            "", // interaction
            0 // threshold
        );

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT, // amount
            takerTraits,
            args
        );
    }

    /* solhint-enable func-name-mixedcase */
}
