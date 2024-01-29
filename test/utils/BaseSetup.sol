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

import { Escrow } from "contracts/Escrow.sol";
import { EscrowFactory, IEscrowFactory } from "contracts/EscrowFactory.sol";
import { PackedAddresses, PackedAddressesMemLib } from "./libraries/PackedAddressesMemLib.sol";
import { Timelocks, TimelocksSettersLib } from "./libraries/TimelocksSettersLib.sol";
import { IEscrow } from "contracts/interfaces/IEscrow.sol";

import { Utils, VmSafe } from "./Utils.sol";

contract BaseSetup is Test {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using PackedAddressesMemLib for PackedAddresses;
    using TimelocksSettersLib for Timelocks;

    /**
     * Timelocks for the source chain.
     * finality: The duration of the chain finality period.
     * withdrawal: The duration of the period when only the taker with a secret can withdraw tokens for the taker.
     * cancel: The duration of the period when escrow can only be cancelled by the taker.
     */
    struct SrcTimelocks {
        uint256 finality;
        uint256 withdrawal;
        uint256 cancel;
    }

    /**
     * Timelocks for the destination chain.
     * finality: The duration of the chain finality period.
     * withdrawal: The duration of the period when only the taker with a secret can withdraw tokens for the maker.
     * publicWithdrawal: The duration of the period when anyone with a secret can withdraw tokens for the maker.
     */
    struct DstTimelocks {
        uint256 finality;
        uint256 withdrawal;
        uint256 publicWithdrawal;
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
    uint256 internal constant MAKING_AMOUNT = 0.3 ether;
    uint256 internal constant TAKING_AMOUNT = 0.5 ether;
    uint256 internal constant SRC_SAFETY_DEPOSIT = 0.03 ether;
    uint256 internal constant DST_SAFETY_DEPOSIT = 0.05 ether;
    uint32 internal constant RESOLVER_FEE = 100;

    VmSafe.Wallet[] internal users;

    VmSafe.Wallet internal alice;
    VmSafe.Wallet internal bob;

    TokenMock internal dai;
    TokenCustomDecimalsMock internal usdc;
    WrappedTokenMock internal weth;
    TokenMock internal inch;

    LimitOrderProtocol internal limitOrderProtocol;
    EscrowFactory internal escrowFactory;
    Escrow internal escrow;
    IFeeBank internal feeBank;

    Timelocks internal timelocks;
    Timelocks internal timelocksDst;

    SrcTimelocks internal srcTimelocks = SrcTimelocks({
        finality: 120,
        withdrawal: 900,
        cancel: 110
    });
    DstTimelocks internal dstTimelocks = DstTimelocks({
        finality: 300,
        withdrawal: 240,
        publicWithdrawal: 360
    });
    /* solhint-enable private-vars-leading-underscore */

    receive() external payable {}

    function setUp() public virtual {
        Utils utils = new Utils();
        users = utils.createUsers(2);

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
        dai.approve(address(limitOrderProtocol), 1000 ether);
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
            srcTimelocks.finality,
            srcTimelocks.withdrawal,
            srcTimelocks.cancel,
            dstTimelocks.finality,
            dstTimelocks.withdrawal,
            dstTimelocks.publicWithdrawal,
            block.timestamp
        );
        timelocksDst = timelocks
            .setSrcFinalityDuration(0)
            .setSrcWithdrawalDuration(0)
            .setSrcCancellationDuration(0);
    }

    function _deployContracts() internal {
        limitOrderProtocol = new LimitOrderProtocol(IWETH(weth));

        escrow = new Escrow();
        vm.label(address(escrow), "Escrow");
        escrowFactory = new EscrowFactory(address(escrow), address(limitOrderProtocol), inch);
        vm.label(address(escrowFactory), "EscrowFactory");
        feeBank = IFeeBank(escrowFactory.FEE_BANK());
        vm.label(address(feeBank), "FeeBank");
    }

    function _buidDynamicData(
        bytes32 secret,
        PackedAddresses memory packedAddresses,
        uint256 chainId,
        address token,
        uint256 srcSafetyDeposit,
        uint256 dstSafetyDeposit
    ) internal view returns (bytes memory) {
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        return (
            abi.encode(
                hashlock,
                packedAddresses,
                chainId,
                token,
                (srcSafetyDeposit << 128) | dstSafetyDeposit,
                timelocks
            )
        );
    }

    function _prepareDataSrc(
        bytes32 secret,
        uint256 srcAmount,
        uint256 dstAmount,
        bool fakeOrder
    ) internal view returns(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        bytes memory extraData,
        bytes memory extension,
        Escrow srcClone
    ) {
        PackedAddresses memory packedAddresses = PackedAddressesMemLib.packAddresses(
            alice.addr,
            bob.addr,
            address(usdc)
        );
        extraData = _buidDynamicData(
            secret,
            packedAddresses,
            block.chainid,
            address(dai),
            srcAmount * 10 / 100,
            dstAmount * 10 / 100
        );

        bytes memory whitelist = abi.encodePacked(
            uint32(block.timestamp), // auction start time
            uint80(uint160(bob.addr)), // resolver address
            uint16(0) // time delta
        );

        if (fakeOrder) {
            order = IOrderMixin.Order({
                salt: 0,
                maker: Address.wrap(uint160(alice.addr)),
                receiver: Address.wrap(uint160(bob.addr)),
                makerAsset: Address.wrap(uint160(address(usdc))),
                takerAsset: Address.wrap(uint160(address(dai))),
                makingAmount: srcAmount,
                takingAmount: dstAmount,
                makerTraits: MakerTraits.wrap(0)
            });
        } else {
            bytes memory postInteractionData = abi.encodePacked(
                address(escrowFactory),
                RESOLVER_FEE,
                extraData,
                whitelist
            );

            (order, extension) = _buildOrder(
                alice.addr,
                bob.addr,
                address(usdc),
                address(dai),
                srcAmount,
                dstAmount,
                MakerTraits.wrap(0),
                InteractionParams("", "", "", "", "", "", "", postInteractionData),
                ""
            );
        }
        orderHash = limitOrderProtocol.hashOrder(order);
        bytes memory interactionParams = abi.encode(
            orderHash,
            srcAmount,
            dstAmount
        );
        bytes memory data = abi.encodePacked(
            interactionParams,
            extraData
        );

        srcClone = Escrow(escrowFactory.addressOfEscrow(data));
        extraData = abi.encodePacked(
            RESOLVER_FEE,
            extraData,
            whitelist
        );
    }

    function _prepareDataDst(
        bytes32 secret,
        uint256 amount,
        address maker,
        address taker,
        address token
    ) internal view returns (
        IEscrowFactory.DstEscrowImmutablesCreation memory,
        Escrow
    ) {
        (
            IEscrowFactory.DstEscrowImmutablesCreation memory escrowImmutables,
            bytes memory data
        ) = _buildDstEscrowImmutables(secret, amount, maker, taker, token);
        return (escrowImmutables, Escrow(escrowFactory.addressOfEscrow(data)));
    }

    function _buildDstEscrowImmutables(
        bytes32 secret,
        uint256 amount,
        address maker,
        address taker,
        address token
    ) internal view returns(
        IEscrowFactory.DstEscrowImmutablesCreation memory immutables,
        bytes memory data
    ) {
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        uint256 safetyDeposit = amount * 10 / 100;
        uint256 srcCancellationTimestamp = block.timestamp + srcTimelocks.finality + srcTimelocks.withdrawal;
        PackedAddresses memory packedAddresses = PackedAddressesMemLib.packAddresses(maker, taker, token);

        IEscrow.DstEscrowImmutables memory args = IEscrow.DstEscrowImmutables({
            orderHash: bytes32(block.timestamp), // fake order hash
            hashlock: hashlock,
            packedAddresses: packedAddresses,
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocksDst
        });
        immutables = IEscrowFactory.DstEscrowImmutablesCreation(
            args,
            srcCancellationTimestamp
        );
        data = abi.encode(args);
    }

    function _buildMakerTraits(MakerTraitsParams memory params) internal pure returns(MakerTraits) {
        return MakerTraits.wrap(
            0 |
            params.series << 160 |
            params.nonce << 120 |
            params.expiry << 80 |
            uint160(params.allowedSender) & ((1 << 80) - 1) |
            (params.unwrapWeth == true ? _UNWRAP_WETH_FLAG : 0) |
            (params.allowMultipleFills == true ? _ALLOW_MULTIPLE_FILLS_FLAG : 0) |
            (params.allowPartialFill == false ? _NO_PARTIAL_FILLS_FLAG : 0) |
            (params.shouldCheckEpoch == true ? _NEED_CHECK_EPOCH_MANAGER_FLAG : 0) |
            (params.usePermit2 == true ? _USE_PERMIT2_FLAG : 0)
        );
    }

    function _buildOrder(
        address maker,
        address receiver,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        MakerTraits makerTraits,
        InteractionParams memory interactions,
        bytes memory customData
    ) internal pure returns(IOrderMixin.Order memory, bytes memory) {
        MakerTraitsParams memory makerTraitsParams = MakerTraitsParams({
            allowedSender: address(0),
            shouldCheckEpoch: false,
            allowPartialFill: true,
            allowMultipleFills: true,
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
            extension = abi.encodePacked(
                offsets,
                allInteractionsConcat
            );
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
    ) internal pure returns(TakerTraits, bytes memory) {
        TakerTraits traits = TakerTraits.wrap(
            threshold | (
                (makingAmount ? _MAKER_AMOUNT_FLAG_TT : 0) |
                (unwrapWeth ? _UNWRAP_WETH_FLAG_TT : 0) |
                (skipMakerPermit ? _SKIP_ORDER_PERMIT_FLAG : 0) |
                (usePermit2 ? _USE_PERMIT2_FLAG_TT : 0) |
                (target != address(0) ? _ARGS_HAS_TARGET : 0) |
                (extension.length << _ARGS_EXTENSION_LENGTH_OFFSET) |
                (interaction.length << _ARGS_INTERACTION_LENGTH_OFFSET)
            )
        );
        bytes memory targetBytes = target != address(0) ? abi.encodePacked(target): abi.encodePacked("");
        bytes memory args = abi.encodePacked(
            targetBytes,
            extension,
            interaction
        );
        return (traits, args);
    }
}
