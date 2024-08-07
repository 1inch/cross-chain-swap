// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { TimelocksLib } from "contracts/libraries/TimelocksLib.sol";
import { IResolverExample, ResolverExample } from "contracts/mocks/ResolverExample.sol";
import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract IntegrationResolverMockTest is BaseSetup {
    /* solhint-disable-next-line private-vars-leading-underscore */
    address private resolverMock;

    function setUp() public virtual override {
        BaseSetup.setUp();
        resolverMock = address(new ResolverExample(escrowFactory, limitOrderProtocol, address(this)));
        resolvers[0] = address(resolverMock);
        vm.label(resolverMock, "resolverMock");
        vm.deal(resolverMock, 100 ether);
        dai.mint(resolverMock, 1000 ether);
        inch.mint(resolverMock, 1000 ether);
        vm.startPrank(resolverMock);
        inch.approve(address(feeBank), 1000 ether);
        feeBank.deposit(10 ether);
        vm.stopPrank();
    }

    /* solhint-disable func-name-mixedcase */

    function test_MockDeploySrc() public {
        vm.warp(1710288000); // set current timestamp
        (timelocks, timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension,
            "", // interaction
            0 // threshold
        );

        swapData.immutables.timelocks = TimelocksLib.setDeployedAt(swapData.immutables.timelocks, 0);

        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);

        IResolverExample(resolverMock).deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function test_MockWithdrawToSrc() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension, // swapData.extension
            "", // interaction
            0 // threshold
        );

        // deploy escrow
        IResolverExample(resolverMock).deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        uint256 aliceBalance = usdc.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(swapData.srcClone);
        arguments[0] = abi.encodePacked(swapData.srcClone.withdrawTo.selector, abi.encode(SECRET, alice.addr, swapData.immutables));

        skip(srcTimelocks.withdrawal + 10);
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(alice.addr), aliceBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);
    }

    function test_MockCancelSrc() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension, // swapData.extension
            "", // interaction
            0 // threshold
        );

        // deploy escrow
        IResolverExample(resolverMock).deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        uint256 aliceBalance = usdc.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(swapData.srcClone);
        arguments[0] = abi.encodePacked(swapData.srcClone.cancel.selector, abi.encode(swapData.immutables));

        skip(srcTimelocks.cancellation + 10);
        // Cancel escrow
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(alice.addr), aliceBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);
    }

    function test_MockPublicCancelSrc() public {
        resolvers = new address[](2);
        resolvers[0] = bob.addr;
        resolvers[1] = resolverMock;
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(swapData.srcClone), // target
            swapData.extension, // swapData.extension
            "", // interaction
            0 // threshold
        );

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT, // amount
            takerTraits,
            args
        );

        uint256 aliceBalance = usdc.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(swapData.srcClone);
        arguments[0] = abi.encodePacked(swapData.srcClone.cancel.selector, abi.encode(swapData.immutables));

        vm.warp(block.timestamp + srcTimelocks.cancellation + 10);
        // Resolver is bob, so unable to cancel escrow
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        vm.warp(block.timestamp + srcTimelocks.publicCancellation + 10);
        arguments[0] = abi.encodePacked(swapData.srcClone.publicCancel.selector, abi.encode(swapData.immutables));
        // Now resolver mock is able to cancel escrow
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(alice.addr), aliceBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);
    }

    function test_MockRescueFundsSrc() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(false, false);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.privateKey, swapData.orderHash);
        bytes32 vs = bytes32((uint256(v - 27) << 255)) | s;

        (TakerTraits takerTraits, bytes memory args) = CrossChainTestLib.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            address(0), // target
            swapData.extension, // swapData.extension
            "", // interaction
            0 // threshold
        );

        // deploy escrow
        IResolverExample(resolverMock).deploySrc(
            swapData.immutables,
            swapData.order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        uint256 resolverBalance = usdc.balanceOf(resolverMock);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](2);
        bytes[] memory arguments = new bytes[](2);
        targets[0] = address(swapData.srcClone);
        targets[1] = address(swapData.srcClone);
        arguments[0] = abi.encodePacked(
            swapData.srcClone.rescueFunds.selector,
            abi.encode(address(usdc), MAKING_AMOUNT, swapData.immutables)
        );
        arguments[1] = abi.encodePacked(
            swapData.srcClone.rescueFunds.selector,
            abi.encode(address(0), SRC_SAFETY_DEPOSIT, swapData.immutables)
        );

        skip(RESCUE_DELAY + 10);
        // Rescue USDC and native tokens
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(resolverMock), resolverBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(swapData.srcClone)), 0);
        assertEq(address(swapData.srcClone).balance, 0);
    }

    function test_MockDeployDst() public {
        (IBaseEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IBaseEscrow dstClone
        ) = _prepareDataDst();

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);
        IResolverExample(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);
    }

    function test_MockWithdrawDst() public {
        (IBaseEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IBaseEscrow dstClone
        ) = _prepareDataDst();

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);
        IResolverExample(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);

        uint256 aliceBalance = dai.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        targets = new address[](1);
        arguments = new bytes[](1);
        targets[0] = address(dstClone);
        arguments[0] = abi.encodePacked(dstClone.withdraw.selector, abi.encode(SECRET, immutables));

        skip(dstTimelocks.withdrawal + 10);
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(alice.addr), aliceBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    function test_MockPublicWithdrawDst() public {
        resolvers[0] = bob.addr;
        (IBaseEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IEscrowDst dstClone
        ) = _prepareDataDst();

        vm.prank(bob.addr);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);

        uint256 aliceBalance = dai.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dstClone);
        arguments[0] = abi.encodePacked(dstClone.withdraw.selector, abi.encode(SECRET, immutables));

        vm.warp(block.timestamp + dstTimelocks.withdrawal + 10);
        // Resolver is bob, so unable to withdraw tokens
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal + 10);
        arguments[0] = abi.encodePacked(dstClone.publicWithdraw.selector, abi.encode(SECRET, immutables));
        // Now resolver mock is able to withdraw tokens
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(alice.addr), aliceBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    function test_MockCancelDst() public {
        (IBaseEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IBaseEscrow dstClone
        ) = _prepareDataDst();

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);
        IResolverExample(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);

        uint256 resolverBalance = dai.balanceOf(resolverMock);
        uint256 resolverBalanceNative = resolverMock.balance;

        targets = new address[](1);
        arguments = new bytes[](1);
        targets[0] = address(dstClone);
        arguments[0] = abi.encodePacked(dstClone.cancel.selector, abi.encode(immutables));

        skip(dstTimelocks.cancellation + 10);
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(resolverMock), resolverBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    function test_MockRescueFundsDst() public {
        (IBaseEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IBaseEscrow dstClone
        ) = _prepareDataDst();

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);
        IResolverExample(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);

        uint256 resolverBalance = dai.balanceOf(resolverMock);
        uint256 resolverBalanceNative = resolverMock.balance;

        targets = new address[](2);
        arguments = new bytes[](2);
        targets[0] = address(dstClone);
        targets[1] = address(dstClone);
        arguments[0] = abi.encodePacked(dstClone.rescueFunds.selector, abi.encode(address(dai), TAKING_AMOUNT, immutables));
        arguments[1] = abi.encodePacked(dstClone.rescueFunds.selector, abi.encode(address(0), DST_SAFETY_DEPOSIT, immutables));

        skip(RESCUE_DELAY + 10);
        // Rescue DAI and native tokens
        IResolverExample(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(resolverMock), resolverBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    /* solhint-enable func-name-mixedcase */

}
