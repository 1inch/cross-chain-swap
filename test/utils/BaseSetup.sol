// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { IWETH, LimitOrderProtocol } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { WrappedTokenMock } from "limit-order-protocol/contracts/mocks/WrappedTokenMock.sol";
import { IFeeBank } from "limit-order-settlement/contracts/interfaces/IFeeBank.sol";
import { TokenCustomDecimalsMock } from "solidity-utils/contracts/mocks/TokenCustomDecimalsMock.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";

import { EscrowDst } from "../../contracts/EscrowDst.sol";
import { EscrowSrc } from "../../contracts/EscrowSrc.sol";
import { BaseEscrowFactory } from "../../contracts/BaseEscrowFactory.sol";
import { EscrowFactory } from "../../contracts/EscrowFactory.sol";
import { IBaseEscrow } from "../../contracts/interfaces/IBaseEscrow.sol";
import { EscrowFactoryZkSync } from "../../contracts/zkSync/EscrowFactoryZkSync.sol";
import { Utils } from "./Utils.sol";
import { CrossChainTestLib } from "./libraries/CrossChainTestLib.sol";
import { Timelocks } from "./libraries/TimelocksSettersLib.sol";


/* solhint-disable max-states-count */
contract BaseSetup is Test, Utils {
    /* solhint-disable private-vars-leading-underscore */
    bytes32 internal constant SECRET = keccak256(abi.encodePacked("secret"));
    bytes32 internal constant HASHED_SECRET = keccak256(abi.encodePacked(SECRET));
    uint256 internal constant MAKING_AMOUNT = 0.3 ether;
    uint256 internal constant TAKING_AMOUNT = 0.5 ether;
    uint256 internal constant SRC_SAFETY_DEPOSIT = 0.03 ether;
    uint256 internal constant DST_SAFETY_DEPOSIT = 0.05 ether;
    uint32 internal constant RESOLVER_FEE = 100;
    uint32 internal constant RESCUE_DELAY = 604800; // 7 days

    Wallet internal alice;
    Wallet internal bob;
    Wallet internal charlie;

    TokenMock internal dai;
    TokenCustomDecimalsMock internal usdc;
    WrappedTokenMock internal weth;
    TokenMock internal inch;

    LimitOrderProtocol internal limitOrderProtocol;
    BaseEscrowFactory internal escrowFactory;
    EscrowSrc internal escrowSrc;
    EscrowDst internal escrowDst;
    IFeeBank internal feeBank;

    address[] internal resolvers;

    Timelocks internal timelocks;
    Timelocks internal timelocksDst;

    CrossChainTestLib.SrcTimelocks internal srcTimelocks = CrossChainTestLib.SrcTimelocks({
        withdrawal: 120,
        publicWithdrawal: 500,
        cancellation: 1020,
        publicCancellation: 1530
    });
    CrossChainTestLib.DstTimelocks internal dstTimelocks = CrossChainTestLib.DstTimelocks({
        withdrawal: 300,
        publicWithdrawal: 540,
        cancellation: 900
    });
    bytes internal auctionPoints = abi.encodePacked(
        uint24(800000), uint16(100),
        uint24(700000), uint16(100),
        uint24(600000), uint16(100),
        uint24(500000), uint16(100),
        uint24(400000), uint16(100)
    );
    bool internal isZkSync;
    /* solhint-enable private-vars-leading-underscore */

    receive() external payable {}

    function setUp() public virtual {
        bytes32 profileHash = keccak256(abi.encodePacked(vm.envString("FOUNDRY_PROFILE")));
        if (profileHash == CrossChainTestLib.ZKSYNC_PROFILE_HASH) isZkSync = true;
        _createUsers(3);

        alice = users[0];
        vm.label(alice.addr, "Alice");
        bob = users[1];
        vm.label(bob.addr, "Bob");
        charlie = users[2];
        vm.label(charlie.addr, "Charlie");

        resolvers = new address[](1);
        resolvers[0] = bob.addr;

        _deployTokens();
        dai.mint(bob.addr, 1000 ether);
        usdc.mint(alice.addr, 1000 ether);
        inch.mint(bob.addr, 1000 ether);

        (timelocks, timelocksDst) = CrossChainTestLib.setTimelocks(srcTimelocks, dstTimelocks);

        _deployContracts();

        vm.startPrank(bob.addr);
        dai.approve(address(escrowFactory), 1000 ether);
        inch.approve(address(feeBank), 1000 ether);
        feeBank.deposit(10 ether);
        vm.stopPrank();
        vm.prank(alice.addr);
        usdc.approve(address(limitOrderProtocol), 1000 ether);
    }

    function _deployTokens() internal {
        dai = new TokenMock("DAI", "DAI");
        vm.label(address(dai), "DAI");
        usdc = new TokenCustomDecimalsMock("USDC", "USDC", 1000 ether, 6);
        vm.label(address(usdc), "USDC");
        weth = new WrappedTokenMock("WETH", "WETH");
        vm.label(address(weth), "WETH");
        inch = new TokenMock("1INCH", "1INCH");
        vm.label(address(inch), "1INCH");
    }

    function _deployContracts() internal {
        limitOrderProtocol = new LimitOrderProtocol(IWETH(weth));

        if (isZkSync) {
            escrowFactory = new EscrowFactoryZkSync(address(limitOrderProtocol), inch, inch, charlie.addr,  RESCUE_DELAY, RESCUE_DELAY);
        } else {
            escrowFactory = new EscrowFactory(address(limitOrderProtocol), inch, inch, charlie.addr, RESCUE_DELAY, RESCUE_DELAY);
        }
        vm.label(address(escrowFactory), "EscrowFactory");
        escrowSrc = EscrowSrc(escrowFactory.ESCROW_SRC_IMPLEMENTATION());
        vm.label(address(escrowSrc), "EscrowSrc");
        escrowDst = EscrowDst(escrowFactory.ESCROW_DST_IMPLEMENTATION());
        vm.label(address(escrowDst), "EscrowDst");

        feeBank = IFeeBank(escrowFactory.FEE_BANK());
        vm.label(address(feeBank), "FeeBank");
    }

    function _prepareDataSrc(bool fakeOrder, bool allowMultipleFills) internal returns(CrossChainTestLib.SwapData memory) {
        return _prepareDataSrcCustom(
            HASHED_SECRET,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            SRC_SAFETY_DEPOSIT,
            DST_SAFETY_DEPOSIT,
            address(0),
            fakeOrder,
            allowMultipleFills
        );
    }

    function _prepareDataSrcHashlock(
        bytes32 hashlock,
        bool fakeOrder, 
        bool allowMultipleFills
    ) internal returns(CrossChainTestLib.SwapData memory) {
        return _prepareDataSrcCustom(
            hashlock,
            MAKING_AMOUNT,
            TAKING_AMOUNT,
            SRC_SAFETY_DEPOSIT,
            DST_SAFETY_DEPOSIT,
            address(0),
            fakeOrder,
            allowMultipleFills
        );
    }

    function _prepareDataSrcCustom(
        bytes32 hashlock,
        uint256 srcAmount,
        uint256 dstAmount,
        uint256 srcSafetyDeposit,
        uint256 dstSafetyDeposit,
        address receiver,
        bool fakeOrder,
        bool allowMultipleFills
    ) internal returns(CrossChainTestLib.SwapData memory swapData) {
        swapData = CrossChainTestLib.prepareDataSrc(
            CrossChainTestLib.OrderDetails({
                maker: alice.addr,
                receiver: receiver,
                srcToken: address(usdc),
                dstToken: address(dai),
                srcAmount: srcAmount,
                dstAmount: dstAmount,
                srcSafetyDeposit: srcSafetyDeposit,
                dstSafetyDeposit: dstSafetyDeposit,
                resolvers: resolvers,
                resolverFee: RESOLVER_FEE,
                auctionDetails: CrossChainTestLib.buildAuctionDetails(
                    0, // gasBumpEstimate
                    0, // gasPriceEstimate
                    uint32(block.timestamp), // startTime
                    1800, // duration: 30 minutes
                    0, // delay
                    900000, // initialRateBump
                    auctionPoints
                )
            }),
            CrossChainTestLib.EscrowDetails({
                hashlock: hashlock,
                timelocks: timelocks,
                fakeOrder: fakeOrder,
                allowMultipleFills: allowMultipleFills
            }),
            address(escrowFactory),
            limitOrderProtocol
        );
    }

    function _prepareDataDst(
    ) internal view returns (IBaseEscrow.Immutables memory escrowImmutables, uint256 srcCancellationTimestamp, EscrowDst escrow) {
        return _prepareDataDstCustom(HASHED_SECRET, TAKING_AMOUNT, alice.addr, resolvers[0], address(dai), DST_SAFETY_DEPOSIT);
    }

    function _prepareDataDstCustom(
        bytes32 hashlock,
        uint256 amount,
        address maker,
        address taker,
        address token,
        uint256 safetyDeposit
    ) internal view returns (IBaseEscrow.Immutables memory, uint256, EscrowDst) {
        bytes32 orderHash = bytes32(block.timestamp); // fake order hash
        uint256 srcCancellationTimestamp = block.timestamp + srcTimelocks.cancellation;
        IBaseEscrow.Immutables memory escrowImmutables = CrossChainTestLib.buildDstEscrowImmutables(
            orderHash,
            hashlock,
            amount,
            maker,
            taker,
            token,
            safetyDeposit,
            timelocksDst
        );
        return (escrowImmutables, srcCancellationTimestamp, EscrowDst(escrowFactory.addressOfEscrowDst(escrowImmutables)));
    }
}

/* solhint-enable max-states-count */
