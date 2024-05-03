// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IEscrowDst } from "contracts/interfaces/IEscrowDst.sol";
import { IEscrow, IEscrowSrc } from "contracts/interfaces/IEscrowSrc.sol";
import { Timelocks } from "contracts/libraries/TimelocksLib.sol";
import { IResolverMock, ResolverMock } from "contracts/mocks/ResolverMock.sol";
import { BaseSetup, IOrderMixin, TakerTraits } from "../utils/BaseSetup.sol";

contract IntegrationResolverMockTest is BaseSetup {
    /* solhint-disable-next-line private-vars-leading-underscore */
    address private resolverMock;

    function setUp() public virtual override {
        BaseSetup.setUp();
        resolverMock = address(new ResolverMock(escrowFactory, limitOrderProtocol, address(this)));
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
        _setTimelocks();

        address[] memory resolvers = new address[](1);
        resolvers[0] = resolverMock;

        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrow srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustomResolver(
            HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false, resolvers
        );

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

        immutables.timelocks = Timelocks.wrap(Timelocks.unwrap(immutables.timelocks) & ~(uint256(type(uint32).max)));

        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);

        IResolverMock(resolverMock).deploySrc(
            immutables,
            order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function test_MockWithdrawToSrc() public {
        address[] memory resolvers = new address[](1);
        resolvers[0] = resolverMock;
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrowSrc srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustomResolver(
            HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false, resolvers
        );

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

        // deploy escrow
        IResolverMock(resolverMock).deploySrc(
            immutables,
            order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        uint256 aliceBalance = usdc.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(srcClone);
        arguments[0] = abi.encodePacked(srcClone.withdrawTo.selector, abi.encode(SECRET, alice.addr, immutables));

        skip(srcTimelocks.withdrawal + 10);
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(alice.addr), aliceBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);
    }

    function test_MockCancelSrc() public {
        address[] memory resolvers = new address[](1);
        resolvers[0] = resolverMock;
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrowSrc srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustomResolver(
            HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false, resolvers
        );

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

        // deploy escrow
        IResolverMock(resolverMock).deploySrc(
            immutables,
            order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        uint256 aliceBalance = usdc.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(srcClone);
        arguments[0] = abi.encodePacked(srcClone.cancel.selector, abi.encode(immutables));

        skip(srcTimelocks.cancellation + 10);
        // Cancel escrow
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(alice.addr), aliceBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);
    }

    function test_MockPublicCancelSrc() public {
        address[] memory resolvers = new address[](2);
        resolvers[0] = bob.addr;
        resolvers[1] = resolverMock;
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrowSrc srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustomResolver(
            HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false, resolvers
        );

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

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(bob.addr);
        limitOrderProtocol.fillOrderArgs(
            order,
            r,
            vs,
            MAKING_AMOUNT, // amount
            takerTraits,
            args
        );

        uint256 aliceBalance = usdc.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(srcClone);
        arguments[0] = abi.encodePacked(srcClone.cancel.selector, abi.encode(immutables));

        vm.warp(block.timestamp + srcTimelocks.cancellation + 10);
        // Resolver is bob, so unable to cancel escrow
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        vm.warp(block.timestamp + srcTimelocks.publicCancellation + 10);
        arguments[0] = abi.encodePacked(srcClone.publicCancel.selector, abi.encode(immutables));
        // Now resolver mock is able to cancel escrow
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(alice.addr), aliceBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);
    }

    function test_MockRescueFundsSrc() public {
        address[] memory resolvers = new address[](1);
        resolvers[0] = resolverMock;
        (
            IOrderMixin.Order memory order,
            bytes32 orderHash,
            /* bytes memory extraData */,
            bytes memory extension,
            IEscrowSrc srcClone,
            IEscrow.Immutables memory immutables
        ) = _prepareDataSrcCustomResolver(
            HASHED_SECRET, MAKING_AMOUNT, TAKING_AMOUNT, SRC_SAFETY_DEPOSIT, DST_SAFETY_DEPOSIT, address(0), false, false, resolvers
        );

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

        // deploy escrow
        IResolverMock(resolverMock).deploySrc(
            immutables,
            order,
            r,
            vs,
            MAKING_AMOUNT,
            takerTraits,
            args
        );

        uint256 resolverBalance = usdc.balanceOf(resolverMock);
        uint256 resolverBalanceNative = resolverMock.balance;

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);

        address[] memory targets = new address[](2);
        bytes[] memory arguments = new bytes[](2);
        targets[0] = address(srcClone);
        targets[1] = address(srcClone);
        arguments[0] = abi.encodePacked(srcClone.rescueFunds.selector, abi.encode(address(usdc), MAKING_AMOUNT, immutables));
        arguments[1] = abi.encodePacked(srcClone.rescueFunds.selector, abi.encode(address(0), SRC_SAFETY_DEPOSIT, immutables));

        skip(RESCUE_DELAY + 10);
        // Rescue USDC and native tokens
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(usdc.balanceOf(resolverMock), resolverBalance + MAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + SRC_SAFETY_DEPOSIT);
        assertEq(usdc.balanceOf(address(srcClone)), 0);
        assertEq(address(srcClone).balance, 0);
    }

    function test_MockDeployDst() public {
        (IEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IEscrow dstClone
        ) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, resolverMock, address(dai)
        );

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);
        IResolverMock(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);
    }

    function test_MockWithdrawDst() public {
        (IEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IEscrow dstClone
        ) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, resolverMock, address(dai)
        );

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);
        IResolverMock(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);

        uint256 aliceBalance = dai.balanceOf(alice.addr);
        uint256 resolverBalanceNative = resolverMock.balance;

        targets = new address[](1);
        arguments = new bytes[](1);
        targets[0] = address(dstClone);
        arguments[0] = abi.encodePacked(dstClone.withdraw.selector, abi.encode(SECRET, immutables));

        skip(dstTimelocks.withdrawal + 10);
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(alice.addr), aliceBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    function test_MockPublicWithdrawDst() public {
        (IEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IEscrowDst dstClone
        ) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, bob.addr, address(dai)
        );

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
        vm.expectRevert(IEscrow.InvalidCaller.selector);
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        vm.warp(block.timestamp + dstTimelocks.publicWithdrawal + 10);
        arguments[0] = abi.encodePacked(dstClone.publicWithdraw.selector, abi.encode(SECRET, immutables));
        // Now resolver mock is able to withdraw tokens
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(alice.addr), aliceBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    function test_MockCancelDst() public {
        (IEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IEscrow dstClone
        ) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, resolverMock, address(dai)
        );

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);
        IResolverMock(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

        assertEq(dai.balanceOf(address(dstClone)), TAKING_AMOUNT);
        assertEq(address(dstClone).balance, DST_SAFETY_DEPOSIT);

        uint256 resolverBalance = dai.balanceOf(resolverMock);
        uint256 resolverBalanceNative = resolverMock.balance;

        targets = new address[](1);
        arguments = new bytes[](1);
        targets[0] = address(dstClone);
        arguments[0] = abi.encodePacked(dstClone.cancel.selector, abi.encode(immutables));

        skip(dstTimelocks.cancellation + 10);
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(resolverMock), resolverBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    function test_MockRescueFundsDst() public {
        (IEscrow.Immutables memory immutables,
        uint256 srcCancellationTimestamp,
        IEscrow dstClone
        ) = _prepareDataDst(
            SECRET, TAKING_AMOUNT, alice.addr, resolverMock, address(dai)
        );

        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](1);
        targets[0] = address(dai);
        arguments[0] = abi.encodePacked(dai.approve.selector, abi.encode(address(escrowFactory), type(uint256).max));

        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);

        // Approve DAI to escrowFactory
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);
        IResolverMock(resolverMock).deployDst{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);

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
        IResolverMock(resolverMock).arbitraryCalls(targets, arguments);

        assertEq(dai.balanceOf(resolverMock), resolverBalance + TAKING_AMOUNT);
        assertEq(resolverMock.balance, resolverBalanceNative + DST_SAFETY_DEPOSIT);
        assertEq(dai.balanceOf(address(dstClone)), 0);
        assertEq(address(dstClone).balance, 0);
    }

    /* solhint-enable func-name-mixedcase */

}
