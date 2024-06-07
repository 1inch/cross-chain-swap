// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { IWETH, LimitOrderProtocol } from "limit-order-protocol/LimitOrderProtocol.sol";
import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { MakerTraits, MakerTraitsLib } from "limit-order-protocol/libraries/MakerTraitsLib.sol";
import { TakerTraits } from "limit-order-protocol/libraries/TakerTraitsLib.sol";
import { WrappedTokenMock } from "limit-order-protocol/mocks/WrappedTokenMock.sol";
import { IFeeBank } from "limit-order-settlement/interfaces/IFeeBank.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { TokenCustomDecimalsMock } from "solidity-utils/mocks/TokenCustomDecimalsMock.sol";
import { TokenMock } from "solidity-utils/mocks/TokenMock.sol";

import { EscrowDst } from "contracts/EscrowDst.sol";
import { EscrowSrc } from "contracts/EscrowSrc.sol";
import { EscrowFactory } from "contracts/EscrowFactory.sol";
import { ERC20True } from "contracts/mocks/ERC20True.sol";
import { IEscrow } from "contracts/interfaces/IEscrow.sol";
import { Timelocks, TimelocksSettersLib } from "./libraries/TimelocksSettersLib.sol";

import { Utils, VmSafe } from "./Utils.sol";

/* solhint-disable max-states-count */
contract BaseSetup is Test {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TimelocksSettersLib for Timelocks;

    /**
     * Timelocks for the source chain.
     * withdrawal: Seconds between `deployedAt` and the start of the withdrawal period.
     * cancellation: Seconds between `deployedAt` and the start of the cancellation period.
     * publicCancellation: Seconds between `deployedAt` and the start of the public cancellation period.
     */
    struct SrcTimelocks {
        uint32 withdrawal;
        uint32 publicWithdrawal;
        uint32 cancellation;
        uint32 publicCancellation;
    }

    /**
     * Timelocks for the destination chain.
     * withdrawal: Seconds between `deployedAt` and the start of the withdrawal period.
     * publicWithdrawal: Seconds between `deployedAt` and the start of the public withdrawal period.
     * cancellation: Seconds between `deployedAt` and the start of the cancellation period.
     */
    struct DstTimelocks {
        uint32 withdrawal;
        uint32 publicWithdrawal;
        uint32 cancellation;
    }

    struct InteractionParams {
        bytes makerAssetSuffix;
        bytes takerAssetSuffix;
        bytes makingAmountData;
        bytes takingAmountData;
        bytes predicate;
        bytes permit;
        bytes preInteraction;
        bytes postInteraction;
    }

    struct MakerTraitsParams {
        address allowedSender;
        bool shouldCheckEpoch;
        bool allowPartialFill;
        bool allowMultipleFills;
        bool usePermit2;
        bool unwrapWeth;
        uint40 expiry;
        uint40 nonce;
        uint40 series;
    }

    // Limit order protocol flags
    uint256 internal constant _NO_PARTIAL_FILLS_FLAG = 1 << 255;
    uint256 internal constant _ALLOW_MULTIPLE_FILLS_FLAG = 1 << 254;
    uint256 internal constant _PRE_INTERACTION_CALL_FLAG = 1 << 252;
    uint256 internal constant _POST_INTERACTION_CALL_FLAG = 1 << 251;
    uint256 internal constant _NEED_CHECK_EPOCH_MANAGER_FLAG = 1 << 250;
    uint256 internal constant _HAS_EXTENSION_FLAG = 1 << 249;
    uint256 internal constant _USE_PERMIT2_FLAG = 1 << 248;
    uint256 internal constant _UNWRAP_WETH_FLAG = 1 << 247;
    // Taker traits flags
    uint256 private constant _MAKER_AMOUNT_FLAG_TT = 1 << 255;
    uint256 private constant _UNWRAP_WETH_FLAG_TT = 1 << 254;
    uint256 private constant _SKIP_ORDER_PERMIT_FLAG = 1 << 253;
    uint256 private constant _USE_PERMIT2_FLAG_TT = 1 << 252;
    uint256 private constant _ARGS_HAS_TARGET = 1 << 251;
    uint256 private constant _ARGS_EXTENSION_LENGTH_OFFSET = 224;
    uint256 private constant _ARGS_INTERACTION_LENGTH_OFFSET = 200;

    /* solhint-disable private-vars-leading-underscore */
    bytes32 internal constant SECRET = keccak256(abi.encodePacked("secret"));
    bytes32 internal constant HASHED_SECRET = keccak256(abi.encodePacked(SECRET));
    uint256 internal constant MAKING_AMOUNT = 0.3 ether;
    uint256 internal constant TAKING_AMOUNT = 0.5 ether;
    uint256 internal constant SRC_SAFETY_DEPOSIT = 0.03 ether;
    uint256 internal constant DST_SAFETY_DEPOSIT = 0.05 ether;
    uint32 internal constant RESOLVER_FEE = 100;
    uint32 internal constant RESCUE_DELAY = 604800; // 7 days

    VmSafe.Wallet[] internal users;

    VmSafe.Wallet internal alice;
    VmSafe.Wallet internal bob;

    TokenMock internal dai;
    TokenCustomDecimalsMock internal usdc;
    WrappedTokenMock internal weth;
    TokenMock internal inch;

    LimitOrderProtocol internal limitOrderProtocol;
    EscrowFactory internal escrowFactory;
    EscrowSrc internal escrowSrc;
    EscrowDst internal escrowDst;
    IFeeBank internal feeBank;

    Timelocks internal timelocks;
    Timelocks internal timelocksDst;

    SrcTimelocks internal srcTimelocks = SrcTimelocks({
        withdrawal: 120,
        publicWithdrawal: 500,
        cancellation: 1020,
        publicCancellation: 1530
    });
    DstTimelocks internal dstTimelocks = DstTimelocks({ withdrawal: 300, publicWithdrawal: 540, cancellation: 900 });
    bytes internal auctionPoints = abi.encodePacked(
        uint24(800000), uint16(100),
        uint24(700000), uint16(100),
        uint24(600000), uint16(100),
        uint24(500000), uint16(100),
        uint24(400000), uint16(100)
    );
    /* solhint-enable private-vars-leading-underscore */

    receive() external payable {}

    function setUp() public virtual {
        Utils utils = new Utils();
        users = utils.createUsers(3);

        alice = users[0];
        vm.label(alice.addr, "Alice");
        bob = users[1];
        vm.label(bob.addr, "Bob");

        _deployTokens();
        dai.mint(bob.addr, 1000 ether);
        usdc.mint(alice.addr, 1000 ether);
        inch.mint(bob.addr, 1000 ether);

        _setTimelocks();

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

    function _setTimelocks() internal {
        timelocks = TimelocksSettersLib.init(
            srcTimelocks.withdrawal,
            srcTimelocks.publicWithdrawal,
            srcTimelocks.cancellation,
            srcTimelocks.publicCancellation,
            dstTimelocks.withdrawal,
            dstTimelocks.publicWithdrawal,
            dstTimelocks.cancellation,
            uint32(block.timestamp)
        );
        timelocksDst = TimelocksSettersLib.init(
            0,
            0,
            0,
            0,
            dstTimelocks.withdrawal,
            dstTimelocks.publicWithdrawal,
            dstTimelocks.cancellation,
            uint32(block.timestamp)
        );
    }

    function _deployContracts() internal {
        limitOrderProtocol = new LimitOrderProtocol(IWETH(weth));

        escrowFactory = new EscrowFactory(address(limitOrderProtocol), inch, RESCUE_DELAY, RESCUE_DELAY);
        vm.label(address(escrowFactory), "EscrowFactory");
        escrowSrc = EscrowSrc(escrowFactory.ESCROW_SRC_IMPLEMENTATION());
        vm.label(address(escrowSrc), "EscrowSrc");
        escrowDst = EscrowDst(escrowFactory.ESCROW_DST_IMPLEMENTATION());
        vm.label(address(escrowDst), "EscrowDst");

        feeBank = IFeeBank(escrowFactory.FEE_BANK());
        vm.label(address(feeBank), "FeeBank");
    }

    function _buidDynamicData(
        bytes32 hashlock,
        uint256 chainId,
        address token,
        uint256 srcSafetyDeposit,
        uint256 dstSafetyDeposit
    ) internal view returns (bytes memory) {
        return (
            abi.encode(
                hashlock,
                chainId,
                token,
                (srcSafetyDeposit << 128) | dstSafetyDeposit,
                timelocks
            )
        );
    }

    function _buildAuctionDetails(
        uint24 gasBumpEstimate,
        uint32 gasPriceEstimate,
        uint32 startTime,
        uint24 duration,
        uint32 delay,
        uint24 initialRateBump
    ) internal view returns (bytes memory auctionDetails) {
        auctionDetails = abi.encodePacked(
            gasBumpEstimate,
            gasPriceEstimate,
            startTime + delay,
            duration,
            initialRateBump,
            auctionPoints
        );
    }
    function _prepareDataSrc(
        bytes32 secret,
        uint256 srcAmount,
        uint256 dstAmount,
        uint256 srcSafetyDeposit,
        uint256 dstSafetyDeposit,
        address receiver,
        bool fakeOrder,
        bool allowMultipleFills
    ) internal returns(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        bytes memory extraData,
        bytes memory extension,
        EscrowSrc srcClone,
        IEscrow.Immutables memory immutables
    ) {
        address[] memory resolvers = new address[](1);
        resolvers[0] = bob.addr;
        (order, orderHash, extraData, extension, srcClone, immutables) = _prepareDataSrcCustomResolver(
            secret,
            srcAmount,
            dstAmount,
            srcSafetyDeposit,
            dstSafetyDeposit,
            receiver,
            fakeOrder,
            allowMultipleFills,
            resolvers
        );
    }

    function _prepareDataSrcCustomResolver(
        bytes32 hashlock,
        uint256 srcAmount,
        uint256 dstAmount,
        uint256 srcSafetyDeposit,
        uint256 dstSafetyDeposit,
        address receiver,
        bool fakeOrder,
        bool allowMultipleFills,
        address[] memory resolvers
    ) internal returns(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        bytes memory extraData,
        bytes memory extension,
        EscrowSrc srcClone,
        IEscrow.Immutables memory immutables
    ) {
        extraData = _buidDynamicData(
            hashlock,
            block.chainid,
            address(dai),
            srcSafetyDeposit,
            dstSafetyDeposit
        );

        bytes memory whitelist = abi.encodePacked(uint32(block.timestamp)); // auction start time
        for (uint256 i = 0; i < resolvers.length; i++) {
            whitelist = abi.encodePacked(whitelist, uint80(uint160(resolvers[i])), uint16(0)); // resolver address, time delta
        }

        if (fakeOrder) {
            order = IOrderMixin.Order({
                salt: 0,
                maker: Address.wrap(uint160(alice.addr)),
                receiver: Address.wrap(uint160(receiver)),
                makerAsset: Address.wrap(uint160(address(usdc))),
                takerAsset: Address.wrap(uint160(address(dai))),
                makingAmount: srcAmount,
                takingAmount: dstAmount,
                makerTraits: MakerTraits.wrap(0)
            });
        } else {
            bytes memory postInteractionData = abi.encodePacked(
                address(escrowFactory),
                extraData,
                RESOLVER_FEE,
                whitelist,
                bytes1(0x08) | bytes1(0x01) // 0x08 - whitelist length = 1, 0x01 - turn on resolver fee
            );

            bytes memory auctionDetails = _buildAuctionDetails(
                0, // gasBumpEstimate
                0, // gasPriceEstimate
                uint32(block.timestamp), // startTime
                1800, // duration: 30 minutes
                0, // delay
                900000 // initialRateBump
            );
            bytes memory gettersAmountData = abi.encodePacked(address(escrowFactory), auctionDetails);

            (order, extension) = _buildOrder(
                alice.addr,
                receiver,
                address(usdc),
                address(new ERC20True()),
                srcAmount,
                dstAmount,
                MakerTraits.wrap(0),
                allowMultipleFills,
                InteractionParams("", "", gettersAmountData, gettersAmountData, "", "", "", postInteractionData),
                ""
            );

            dstAmount = escrowFactory.getTakingAmount(order, extension, orderHash, resolvers[0], srcAmount, srcAmount, auctionDetails);
        }

        orderHash = limitOrderProtocol.hashOrder(order);

        immutables = IEscrow.Immutables({
            orderHash: orderHash,
            amount: srcAmount,
            maker: Address.wrap(uint160(alice.addr)),
            taker: Address.wrap(uint160(resolvers[0])),
            token: Address.wrap(uint160(address(usdc))),
            hashlock: hashlock,
            safetyDeposit: srcSafetyDeposit,
            timelocks: timelocks
        });

        srcClone = EscrowSrc(escrowFactory.addressOfEscrowSrc(immutables));
        // 0x08 - whitelist length = 1, 0x01 - turn on resolver fee
        extraData = abi.encodePacked(extraData, RESOLVER_FEE, whitelist, bytes1(0x08) | bytes1(0x01));
    }

    function _prepareDataDst(
        bytes32 secret,
        uint256 amount,
        address maker,
        address taker,
        address token
    ) internal view returns (IEscrow.Immutables memory, uint256, EscrowDst) {
        (IEscrow.Immutables memory escrowImmutables, uint256 srcCancellationTimestamp) = _buildDstEscrowImmutables(
            secret, amount, maker, taker, token
        );
        return (escrowImmutables, srcCancellationTimestamp, EscrowDst(escrowFactory.addressOfEscrowDst(escrowImmutables)));
    }

    function _buildDstEscrowImmutables(
        bytes32 secret,
        uint256 amount,
        address maker,
        address taker,
        address token
    ) internal view returns (IEscrow.Immutables memory immutables, uint256 srcCancellationTimestamp) {
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 safetyDeposit = amount * 10 / 100;
        srcCancellationTimestamp = block.timestamp + srcTimelocks.cancellation;

        immutables = IEscrow.Immutables({
            orderHash: bytes32(block.timestamp), // fake order hash
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(taker)),
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });
    }

    function _buildMakerTraits(MakerTraitsParams memory params) internal pure returns (MakerTraits) {
        uint256 data = 0
            | params.series << 160
            | params.nonce << 120
            | params.expiry << 80
            | uint160(params.allowedSender) & ((1 << 80) - 1)
            | (params.unwrapWeth == true ? _UNWRAP_WETH_FLAG : 0)
            | (params.allowMultipleFills == true ? _ALLOW_MULTIPLE_FILLS_FLAG : 0)
            | (params.allowPartialFill == false ? _NO_PARTIAL_FILLS_FLAG : 0)
            | (params.shouldCheckEpoch == true ? _NEED_CHECK_EPOCH_MANAGER_FLAG : 0)
            | (params.usePermit2 == true ? _USE_PERMIT2_FLAG : 0);
        return MakerTraits.wrap(data);
    }

    function _buildOrder(
        address maker,
        address receiver,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        MakerTraits makerTraits,
        bool allowMultipleFills,
        InteractionParams memory interactions,
        bytes memory customData
    ) internal pure returns (IOrderMixin.Order memory, bytes memory) {
        MakerTraitsParams memory makerTraitsParams = MakerTraitsParams({
            allowedSender: address(0),
            shouldCheckEpoch: false,
            allowPartialFill: true,
            allowMultipleFills: allowMultipleFills,
            usePermit2: false,
            unwrapWeth: false,
            expiry: 0,
            nonce: 0,
            series: 0
        });
        bytes[8] memory allInteractions = [
            interactions.makerAssetSuffix,
            interactions.takerAssetSuffix,
            interactions.makingAmountData,
            interactions.takingAmountData,
            interactions.predicate,
            interactions.permit,
            interactions.preInteraction,
            interactions.postInteraction
        ];
        bytes memory allInteractionsConcat = bytes.concat(
            interactions.makerAssetSuffix,
            interactions.takerAssetSuffix,
            interactions.makingAmountData,
            interactions.takingAmountData,
            interactions.predicate,
            interactions.permit,
            interactions.preInteraction,
            interactions.postInteraction,
            customData
        );

        bytes32 offsets = 0;
        uint256 sum = 0;
        for (uint256 i = 0; i < allInteractions.length; i++) {
            if (allInteractions[i].length > 0) {
                sum += allInteractions[i].length;
            }
            offsets |= bytes32(sum << (i * 32));
        }

        bytes memory extension = "";
        if (allInteractionsConcat.length > 0) {
            extension = abi.encodePacked(offsets, allInteractionsConcat);
        }
        if (MakerTraits.unwrap(makerTraits) == 0) {
            makerTraits = _buildMakerTraits(makerTraitsParams);
        }

        uint256 salt = 1;
        if (extension.length > 0) {
            salt = uint256(keccak256(extension)) & ((1 << 160) - 1);
            makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | _HAS_EXTENSION_FLAG);
        }

        if (interactions.preInteraction.length > 0) {
            makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | _PRE_INTERACTION_CALL_FLAG);
        }

        if (interactions.postInteraction.length > 0) {
            makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | _POST_INTERACTION_CALL_FLAG);
        }

        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: salt,
            maker: Address.wrap(uint160(maker)),
            receiver: Address.wrap(uint160(receiver)),
            makerAsset: Address.wrap(uint160(makerAsset)),
            takerAsset: Address.wrap(uint160(takerAsset)),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: makerTraits
        });
        return (order, extension);
    }

    function _buildTakerTraits(
        bool makingAmount,
        bool unwrapWeth,
        bool skipMakerPermit,
        bool usePermit2,
        address target,
        bytes memory extension,
        bytes memory interaction,
        uint256 threshold
    ) internal pure returns (TakerTraits, bytes memory) {
        uint256 data = threshold
            | (makingAmount ? _MAKER_AMOUNT_FLAG_TT : 0)
            | (unwrapWeth ? _UNWRAP_WETH_FLAG_TT : 0)
            | (skipMakerPermit ? _SKIP_ORDER_PERMIT_FLAG : 0)
            | (usePermit2 ? _USE_PERMIT2_FLAG_TT : 0)
            | (target != address(0) ? _ARGS_HAS_TARGET : 0)
            | (extension.length << _ARGS_EXTENSION_LENGTH_OFFSET)
            | (interaction.length << _ARGS_INTERACTION_LENGTH_OFFSET);
        TakerTraits traits = TakerTraits.wrap(data);
        bytes memory targetBytes = target != address(0) ? abi.encodePacked(target) : abi.encodePacked("");
        bytes memory args = abi.encodePacked(targetBytes, extension, interaction);
        return (traits, args);
    }
}

/* solhint-enable max-states-count */
