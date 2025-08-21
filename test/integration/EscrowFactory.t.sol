// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import { Merkle } from "murky/src/Merkle.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";

import { BaseEscrowFactory } from "contracts/BaseEscrowFactory.sol";
import { EscrowSrc } from "contracts/EscrowSrc.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";
import { ResolverReentrancy } from "../utils/mocks/ResolverReentrancy.sol";
import { CustomPostInteraction } from "../utils/mocks/CustomPostInteraction.sol";

contract IntegrationEscrowFactoryTest is BaseSetup {
    using ImmutablesLib for IBaseEscrow.Immutables;

    function setUp() public virtual override {
        BaseSetup.setUp();
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMakerInt(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.skip(true);
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;
        bytes32 hashlock = keccak256(abi.encode(secret));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            hashlock,
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0), // receiver
            false, // fakeOrder
            false, // allowMultipleFills,
            ""
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

            uint256 dstAmountCorrected = Math.mulDiv(
                dstAmount,
                BASE_1E5 + PROTOCOL_FEE*WHITELIST_PROTOCOL_FEE_DISCOUNT/BASE_1E2+INTEGRATOR_FEE,
                BASE_1E5,
                Math.Rounding.Ceil
            );

            dstAmountCorrected = Math.mulDiv(
                dstAmountCorrected,
                BASE_1E7 + RATE_BUMP,
                BASE_1E7,
                Math.Rounding.Ceil
            );

            (IBaseEscrow.Immutables memory immutablesDst,,) = _prepareDataDstCustom(
                hashlock,
                dstAmountCorrected,
                alice.addr,
                resolvers[0],
                address(dai),
                dstSafetyDeposit,
                PROTOCOL_FEE,
                INTEGRATOR_FEE,
                INTEGRATOR_SHARES,
                WHITELIST_PROTOCOL_FEE_DISCOUNT,
                true
            );

            IEscrowFactory.DstImmutablesComplement memory immutablesComplement = IEscrowFactory.DstImmutablesComplement({
                maker: Address.wrap(uint160(alice.addr)),
                amount: dstAmountCorrected,
                token: Address.wrap(uint160(address(dai))),
                safetyDeposit: dstSafetyDeposit,
                chainId: block.chainid,
                parameters: abi.encode(
                    immutablesDst.protocolFeeAmount(),
                    immutablesDst.integratorFeeAmount(),
                    immutablesDst.protocolFeeRecipient(),
                    immutablesDst.integratorFeeRecipient()
                )
            });

            vm.prank(bob.addr);
            vm.expectEmit();
            emit IEscrowFactory.SrcEscrowCreated(swapData.immutables, immutablesComplement);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                srcAmount, // amount
                takerTraits,
                args
            );
        }

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);
    }

    function testFuzz_DeployCloneForTakingAmount(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;
        bytes32 hashlock = keccak256(abi.encode(secret));

        uint256 srcAmountCorrected = Math.mulDiv(
            srcAmount,
            BASE_1E5,
            BASE_1E5 + PROTOCOL_FEE*WHITELIST_PROTOCOL_FEE_DISCOUNT/BASE_1E2+INTEGRATOR_FEE
        );

        srcAmountCorrected = Math.mulDiv(
            srcAmountCorrected,
            BASE_1E7,
            BASE_1E7 + RATE_BUMP
        );

        vm.assume(srcAmountCorrected > 0);

        uint256 srcSafetyDeposit = uint256(srcAmountCorrected) * 10 / 100;

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            hashlock,
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0), // receiver
            false, // fakeOrder
            false, // allowMultipleFills,
            ""
        );

        swapData.immutables.amount = srcAmountCorrected;
        swapData.srcClone = EscrowSrc(BaseEscrowFactory(payable(escrowFactory)).addressOfEscrowSrc(swapData.immutables));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            false, // takingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(swapData.srcClone), // target
            swapData.extension, // extension
            "", // interaction
            0 // threshold
        );

        {
            (bool success,) = address(swapData.srcClone).call{ value: uint64(srcAmountCorrected) * 10 / 100 }("");
            assertEq(success, true);

            (IBaseEscrow.Immutables memory immutablesDst,,) = _prepareDataDstCustom(
                hashlock, 
                dstAmount, 
                alice.addr, 
                resolvers[0],
                address(dai), 
                dstSafetyDeposit, 
                PROTOCOL_FEE, 
                INTEGRATOR_FEE,
                INTEGRATOR_SHARES,
                WHITELIST_PROTOCOL_FEE_DISCOUNT,
                true
            );

            IEscrowFactory.DstImmutablesComplement memory immutablesComplement = IEscrowFactory.DstImmutablesComplement({
                maker: Address.wrap(uint160(alice.addr)),
                amount: dstAmount,
                token: Address.wrap(uint160(address(dai))),
                safetyDeposit: dstSafetyDeposit,
                chainId: block.chainid,
                parameters: immutablesDst.parameters
            });

            vm.prank(bob.addr);
            vm.expectEmit();
            emit IEscrowFactory.SrcEscrowCreated(swapData.immutables, immutablesComplement);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                dstAmount,
                takerTraits,
                args
            );
        }

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmountCorrected);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);
    }

    function testFuzz_DeployCloneForMakerIntWithCustomPostInteraction(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;

        (bytes memory postInterationCustomData) = abi.encodePacked(
            bytes20(address(customPostInteractor)),
            bytes1(uint8(0x1)) // random value
        );

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            keccak256(abi.encode(secret)),
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0), // receiver
            false, // fakeOrder
            false, // allowMultipleFills,
            postInterationCustomData
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

            vm.prank(bob.addr);
            vm.expectEmit();
            emit CustomPostInteraction.Invoked(abi.encodePacked(bytes1(uint8(0x1))));
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                srcAmount, // amount
                takerTraits,
                args
            );

        }

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);
    }

    function testFuzz_DeployCloneForMakerIntWithRescueFundsNative(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
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
            false, // allowMultipleFills
            ""
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

        uint256 dust = 1 ether;
        (bool success, ) = address(escrowFactory).call{value: dust}("");
        assertEq(success, true);
        assertEq(address(escrowFactory).balance, dust);

        uint256 charlieBalance = charlie.addr.balance;

        {
            (success,) = address(swapData.srcClone).call{ value: uint64(srcAmount) * 10 / 100 }("");
            assertEq(success, true);

            vm.prank(bob.addr);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                srcAmount, // amount
                takerTraits,
                args
            );
        }

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);

        vm.prank(charlie.addr);
        escrowFactory.rescueFunds(IERC20(address(0)), dust);
        assertEq(charlie.addr.balance - charlieBalance, dust);
    }

    function testFuzz_DeployCloneForMakerIntWithRescueFundsERC20(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
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
            false, // allowMultipleFills
            ""
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

        uint256 dust = 1 ether;
        usdc.mint(bob.addr, dust);

        vm.prank(bob.addr);
        usdc.transfer(address(escrowFactory), dust);
        assertEq(usdc.balanceOf(address(escrowFactory)), dust);

        uint256 charlieBalance = usdc.balanceOf(charlie.addr);

        {
            (bool success,) = address(swapData.srcClone).call{ value: uint64(srcAmount) * 10 / 100 }("");
            assertEq(success, true);

            vm.prank(bob.addr);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                srcAmount, // amount
                takerTraits,
                args
            );
        }

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);

        vm.prank(charlie.addr);
        escrowFactory.rescueFunds(IERC20(address(usdc)), dust);
        assertEq(usdc.balanceOf(charlie.addr) - charlieBalance, dust);
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

            inch.mint(charlie.addr, 1000 ether);
            accessToken.mint(charlie.addr, 1);

            vm.startPrank(charlie.addr);
            limitOrderProtocol.fillOrderArgs(
                swapData.order,
                r,
                vs,
                MAKING_AMOUNT, // amount
                takerTraits,
                args
            );
            vm.stopPrank();
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

    function test_NoResolverReentrancy() public {
        ResolverReentrancy badResolver = new ResolverReentrancy(escrowFactory, limitOrderProtocol, address(this));
        resolvers[0] = address(badResolver);
        vm.deal(address(badResolver), 100 ether);

        uint256 partsAmount = 100;
        uint256 secretsAmount = partsAmount + 1;
        bytes32[] memory hashedSecrets = new bytes32[](secretsAmount);
        bytes32[] memory hashedPairs = new bytes32[](secretsAmount);
        for (uint64 i = 0; i < secretsAmount; i++) {
            // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        Merkle merkle = new Merkle();
        bytes32 root = merkle.getRoot(hashedPairs);
        bytes32 rootPlusAmount = bytes32(partsAmount << 240 | uint240(uint256(root)));
        uint256 idx = 0;
        uint256 makingAmount = MAKING_AMOUNT / partsAmount;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        vm.warp(1710288000); // set current timestamp
        (timelocks, timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);


        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount - 2;

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        bytes memory interaction = abi.encodePacked(address(badResolver));
        bytes memory interactionFull = abi.encodePacked(interaction, escrowFactory, abi.encode(proof, idx, hashedSecrets[idx]));

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension, // extension
            interactionFull,
            0 // threshold
        );

        vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        badResolver.deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            makingAmount - 2,
            takerTraits,
            args
        );
    }

    /* solhint-enable func-name-mixedcase */
}
