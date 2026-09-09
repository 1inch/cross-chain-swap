// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Merkle } from "murky/src/Merkle.sol";

import { FeeTaker } from "limit-order-protocol/contracts/extensions/FeeTaker.sol";
import { EscrowDst } from "contracts/EscrowDst.sol";
import { EscrowSrc } from "contracts/EscrowSrc.sol";
import { BaseEscrowFactory } from "contracts/BaseEscrowFactory.sol";
import { IEscrowFactory } from "contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "contracts/interfaces/IBaseEscrow.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";

import { BaseSetup } from "../utils/BaseSetup.sol";
import { CrossChainTestLib } from "../utils/libraries/CrossChainTestLib.sol";

contract EscrowFactoryTest is BaseSetup {
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;

    uint256 public constant SECRETS_AMOUNT = 100;
    bytes32[] public hashedSecrets = new bytes32[](SECRETS_AMOUNT);
    bytes32[] public hashedPairs = new bytes32[](SECRETS_AMOUNT);
    Merkle public merkle;
    bytes32 public root;

    function setUp() public virtual override {
        BaseSetup.setUp();

        merkle = new Merkle();

        // Note: This is not production-ready code. Use cryptographically secure random to generate secrets.
        for (uint64 i = 0; i < SECRETS_AMOUNT; i++) {
            hashedSecrets[i] = keccak256(abi.encodePacked(i));
            hashedPairs[i] = keccak256(abi.encodePacked(i, hashedSecrets[i]));
        }
        root = merkle.getRoot(hashedPairs);
    }

    /* solhint-disable func-name-mixedcase */

    function testFuzz_DeployCloneForMaker(bytes32 secret, uint56 srcAmount, uint56 dstAmount) public {
        vm.assume(srcAmount > 0 && dstAmount > 0);
        uint256 srcSafetyDeposit = uint256(srcAmount) * 10 / 100;
        uint256 dstSafetyDeposit = uint256(dstAmount) * 10 / 100;
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            keccak256(abi.encode(secret)),
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            address(0),
            true, // fakeOrder
            false, // allowMultipleFills,
            ""
        );

        (bool success,) = address(swapData.srcClone).call{ value: srcSafetyDeposit }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), srcAmount);

        vm.prank(address(limitOrderProtocol));
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            srcAmount, // makingAmount
            dstAmount, // takingAmount
            0, // remainingMakingAmount
            swapData.extraData
        );

        assertEq(usdc.balanceOf(address(swapData.srcClone)), srcAmount);
        assertEq(address(swapData.srcClone).balance, srcSafetyDeposit);
    }

    function testFuzz_DeployCloneForMakerWithReceiver() public {
        address receiver = charlie.addr;
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            HASHED_SECRET,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            SRC_SAFETY_DEPOSIT,
            DST_SAFETY_DEPOSIT,
            receiver,
            true,
            false,
            ""
        );

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        (IBaseEscrow.Immutables memory immutablesDst,,) = _prepareDataDst();

        IEscrowFactory.DstImmutablesComplement memory immutablesComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(receiver)),
            amount: TAKING_AMOUNT,
            token: Address.wrap(uint160(address(dai))),
            safetyDeposit: DST_SAFETY_DEPOSIT,
            chainId: block.chainid,
            parameters: abi.encode(
                immutablesDst.protocolFeeAmount(),
                immutablesDst.integratorFeeAmount(),
                immutablesDst.protocolFeeRecipient(),
                immutablesDst.integratorFeeRecipient()
            )
        });

        vm.prank(address(limitOrderProtocol));
        vm.expectEmit();
        emit IEscrowFactory.SrcEscrowCreated(swapData.immutables, immutablesComplement);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        assertEq(usdc.balanceOf(address(swapData.srcClone)), MAKING_AMOUNT);
        assertEq(address(swapData.srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function testFuzz_DeployWithFullFeesForResolverNotInWhitelistWithAccessToken() public {
        address receiver = charlie.addr;
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcCustom(
            HASHED_SECRET,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            SRC_SAFETY_DEPOSIT,
            DST_SAFETY_DEPOSIT,
            receiver,
            true,
            false,
            ""
        );

        address taker = mary.addr;
        accessToken.mint(taker, 1);

        swapData.immutables.taker = Address.wrap(uint160(taker));
        EscrowSrc srcClone = EscrowSrc(BaseEscrowFactory(payable(address(escrowFactory))).addressOfEscrowSrc(swapData.immutables));

        (bool success,) = address(srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(srcClone), MAKING_AMOUNT);

        (IBaseEscrow.Immutables memory immutablesDst,,) = _prepareDataDstCustom(
            HASHED_SECRET,
            TAKING_AMOUNT,
            alice.addr,
            taker,
            address(dai),
            DST_SAFETY_DEPOSIT,
            PROTOCOL_FEE,
            INTEGRATOR_FEE,
            INTEGRATOR_SHARES,
            WHITELIST_PROTOCOL_FEE_DISCOUNT,
            false
        );

        IEscrowFactory.DstImmutablesComplement memory immutablesComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(receiver)),
            amount: TAKING_AMOUNT,
            token: Address.wrap(uint160(address(dai))),
            safetyDeposit: DST_SAFETY_DEPOSIT,
            chainId: block.chainid,
            parameters: abi.encode(
                immutablesDst.protocolFeeAmount(),
                immutablesDst.integratorFeeAmount(),
                immutablesDst.protocolFeeRecipient(),
                immutablesDst.integratorFeeRecipient()
            )
        });

        vm.prank(address(limitOrderProtocol));
        vm.expectEmit();
        emit IEscrowFactory.SrcEscrowCreated(swapData.immutables, immutablesComplement);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            taker, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );

        assertEq(usdc.balanceOf(address(srcClone)), MAKING_AMOUNT);
        assertEq(address(srcClone).balance, SRC_SAFETY_DEPOSIT);
    }

    function testFuzz_DeployCloneForTaker(bytes32 secret, uint56 amount) public {
        uint256 safetyDeposit = uint64(amount) * 10 / 100;
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp, EscrowDst dstClone) = _prepareDataDstCustom(
            secret,
            amount,
            alice.addr,
            bob.addr,
            address(dai),
            safetyDeposit,
            PROTOCOL_FEE,
            INTEGRATOR_FEE,
            INTEGRATOR_SHARES,
            WHITELIST_PROTOCOL_FEE_DISCOUNT,
            true
        );
        uint256 balanceBobNative = bob.addr.balance;
        uint256 balanceBob = dai.balanceOf(bob.addr);
        uint256 balanceEscrow = dai.balanceOf(address(dstClone));
        uint256 balanceEscrowNative = address(dstClone).balance;

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectEmit();
        emit IEscrowFactory.DstEscrowCreated(address(dstClone), immutables.hashlock, Address.wrap(uint160(bob.addr)));
        escrowFactory.createDstEscrow{ value: safetyDeposit }(immutables, srcCancellationTimestamp);

        assertEq(bob.addr.balance, balanceBobNative - immutables.safetyDeposit);
        assertEq(dai.balanceOf(bob.addr), balanceBob - amount);
        assertEq(dai.balanceOf(address(dstClone)), balanceEscrow + amount);
        assertEq(address(dstClone).balance, balanceEscrowNative + safetyDeposit);
    }

    function test_NoInsufficientBalanceNativeDeploymentForMaker() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );
    }

    function test_NoInsufficientBalanceDeploymentForMaker() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );
    }

    // Only whitelisted resolver can deploy escrow
    function test_NoDeploymentForNotResolver() public {
        CrossChainTestLib.SwapData memory swapData = _prepareDataSrc(true, false);

        (bool success,) = address(swapData.srcClone).call{ value: SRC_SAFETY_DEPOSIT }("");
        assertEq(success, true);
        usdc.transfer(address(swapData.srcClone), MAKING_AMOUNT);

        inch.mint(alice.addr, 10 ether);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(FeeTaker.OnlyWhitelistOrAccessToken.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            alice.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );
    }

    function test_NoUnsafeDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst();

        vm.warp(srcCancellationTimestamp + 1);

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);
    }

    function test_NoInsufficientBalanceDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDst();

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow(immutables, srcCancellationTimestamp);
    }

    function test_NoInsufficientBalanceNativeDeploymentForTaker() public {
        (IBaseEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp,) = _prepareDataDstCustom(
            HASHED_SECRET,
            TAKING_AMOUNT,
            alice.addr,
            bob.addr,
            address(0x00),
            DST_SAFETY_DEPOSIT,
            PROTOCOL_FEE,
            INTEGRATOR_FEE,
            INTEGRATOR_SHARES,
            WHITELIST_PROTOCOL_FEE_DISCOUNT,
            true
        );

        // deploy escrow
        vm.prank(bob.addr);
        vm.expectRevert(IEscrowFactory.InsufficientEscrowBalance.selector);
        escrowFactory.createDstEscrow{ value: DST_SAFETY_DEPOSIT }(immutables, srcCancellationTimestamp);
    }

    function test_MultipleFillsInvalidSecretsAmount() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));
        bytes32 rootPlusAmount = bytes32(uint256(0) << 240 | uint240(uint256(root)));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        swapData.immutables.hashlock = hashedSecrets[idx];
        swapData.immutables.amount = makingAmount;

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InvalidSecretsAmount.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            0, // remainingMakingAmount
            swapData.extraData
        );
    }

    function test_MultipleFillsInvalidKey() public {
        uint256 makingAmount = MAKING_AMOUNT / 2;
        uint256 idx = SECRETS_AMOUNT * (makingAmount - 1) / MAKING_AMOUNT;
        bytes32[] memory proof = merkle.getProof(hashedPairs, idx);
        assert(merkle.verifyProof(root, proof, hashedPairs[idx]));

        bytes32 rootPlusAmount = bytes32(SECRETS_AMOUNT << 240 | uint240(uint256(root)));

        CrossChainTestLib.SwapData memory swapData = _prepareDataSrcHashlock(rootPlusAmount, false, true);

        vm.prank(address(limitOrderProtocol));
        vm.expectRevert(IEscrowFactory.InvalidPartialFill.selector);
        escrowFactory.postInteraction(
            swapData.order,
            "", // extension
            swapData.orderHash,
            bob.addr, // taker
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            MAKING_AMOUNT, // remainingMakingAmount
            swapData.extraData
        );
    }

    function test_RescueFundsNative() public {
        uint256 amount = 1 ether;
        (bool success, ) = address(escrowFactory).call{value: amount}("");
        assertEq(success, true);
        assertEq(address(escrowFactory).balance, amount);

        uint256 charlieBalance = charlie.addr.balance;

        vm.prank(charlie.addr);
        escrowFactory.rescueFunds(IERC20(address(0)), amount);

        assertEq(charlie.addr.balance - charlieBalance, amount);
    }

    function test_NoRescueFundsNativeNotOwner() public {
        uint256 amount = 1 ether;
        (bool success, ) = address(escrowFactory).call{value: amount}("");
        assertEq(success, true);
        assertEq(address(escrowFactory).balance, amount);

        uint256 bobBalance = bob.addr.balance;

        vm.prank(bob.addr);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob.addr)
        );
        escrowFactory.rescueFunds(IERC20(address(0)), amount);

        assertEq(bob.addr.balance, bobBalance);
    }

    function test_RescueFundsERC20() public {
        uint256 amount = 1 ether;
        dai.mint(bob.addr, amount);

        vm.prank(bob.addr);
        dai.transfer(address(escrowFactory), amount);
        assertEq(dai.balanceOf(address(escrowFactory)), amount);

        uint256 charlieBalance = dai.balanceOf(charlie.addr);

        vm.prank(charlie.addr);
        escrowFactory.rescueFunds(IERC20(address(dai)), amount);

        assertEq(dai.balanceOf(charlie.addr) - charlieBalance, amount);
    }

    function test_NoRescueFundsERC20NotOwner() public {
        uint256 amount = 1 ether;
        dai.mint(bob.addr, amount);

        vm.prank(bob.addr);
        dai.transfer(address(escrowFactory), amount);
        assertEq(dai.balanceOf(address(escrowFactory)), amount);

        uint256 bobBalance = dai.balanceOf(bob.addr);

        vm.prank(bob.addr);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob.addr)
        );
        escrowFactory.rescueFunds(IERC20(address(dai)), amount);

        assertEq(dai.balanceOf(bob.addr), bobBalance);
    }

    /* solhint-enable func-name-mixedcase */
}
