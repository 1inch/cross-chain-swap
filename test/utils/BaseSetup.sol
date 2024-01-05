// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { IWETH, LimitOrderProtocol } from "lop/LimitOrderProtocol.sol";
import { IOrderMixin } from "lop/interfaces/IOrderMixin.sol";
import { MakerTraits } from "lop/libraries/MakerTraitsLib.sol";
import { TakerTraits } from "lop/libraries/TakerTraitsLib.sol";
import { WrappedTokenMock } from "lop/mocks/WrappedTokenMock.sol";
import { Address } from "solidity-utils/libraries/AddressLib.sol";
import { ECDSA } from "solidity-utils/libraries/ECDSA.sol";
import { TokenCustomDecimalsMock } from "solidity-utils/mocks/TokenCustomDecimalsMock.sol";
import { TokenMock } from "solidity-utils/mocks/TokenMock.sol";

import { Escrow, IEscrow } from "../../contracts/Escrow.sol";
import { EscrowFactory, IEscrowFactory } from "../../contracts/EscrowFactory.sol";

import { Utils, VmSafe } from "./Utils.sol";

contract BaseSetup is Test {
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

    /* solhint-disable private-vars-leading-underscore */
    bytes32 internal constant SECRET = keccak256(abi.encodePacked("secret"));
    uint256 internal constant MAKING_AMOUNT = 0.3 ether;
    uint256 internal constant TAKING_AMOUNT = 0.5 ether;
    uint256 internal constant SAFETY_DEPOSIT = 0.05 ether;

    bytes32 internal constant HASHED_NAME_LOP = keccak256("1inch Limit Order Protocol");
    bytes32 internal constant HASHED_VERSION_LOP = keccak256("4");
    bytes32 internal constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant _LIMIT_ORDER_TYPEHASH = keccak256(
        "Order("
            "uint256 salt,"
            "address maker,"
            "address receiver,"
            "address makerAsset,"
            "address takerAsset,"
            "uint256 makingAmount,"
            "uint256 takingAmount,"
            "uint256 makerTraits"
        ")"
    );
    uint256 internal constant _ORDER_STRUCT_SIZE = 0x100;
    uint256 internal constant _DATA_HASH_SIZE = 0x120;


    Utils internal utils;
    VmSafe.Wallet[] internal users;

    VmSafe.Wallet internal alice;
    VmSafe.Wallet internal bob;

    TokenMock internal dai;
    TokenCustomDecimalsMock internal usdc;
    WrappedTokenMock internal weth;

    LimitOrderProtocol internal limitOrderProtocol;
    EscrowFactory internal escrowFactory;
    Escrow internal escrow;

    IEscrow.SrcTimelocks internal srcTimelocks = IEscrow.SrcTimelocks({
        finality: 120,
        publicUnlock: 900
    });
    IEscrow.DstTimelocks internal dstTimelocks = IEscrow.DstTimelocks({
        finality: 300,
        unlock: 240,
        publicUnlock: 360
    });
    MakerTraitsParams internal makerTraitsParams = MakerTraitsParams({
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
    /* solhint-enable private-vars-leading-underscore */

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(2);

        alice = users[0];
        vm.label(alice.addr, "Alice");
        bob = users[1];
        vm.label(bob.addr, "Bob");

        _deployTokens();
        dai.mint(bob.addr, 1000 ether);
        usdc.mint(alice.addr, 1000 ether);

        _deployContracts();

        vm.startPrank(bob.addr);
        dai.approve(address(escrowFactory), 1000 ether);
        dai.approve(address(limitOrderProtocol), 1000 ether);
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
    }

    function _deployContracts() internal {
        limitOrderProtocol = new LimitOrderProtocol(IWETH(weth));

        escrow = new Escrow();
        vm.label(address(escrow), "Escrow");
        escrowFactory = new EscrowFactory(address(escrow), address(limitOrderProtocol));
        vm.label(address(escrowFactory), "EscrowFactory");
    }

    function _buidDynamicData(
        bytes32 secret,
        uint256 chainId,
        address token,
        uint256 safetyDeposit
    ) internal view returns (bytes memory) {
        uint256 hashlock = uint256(keccak256(abi.encodePacked(secret)));
        return (
            abi.encode(
                hashlock,
                chainId,
                token,
                safetyDeposit,
                srcTimelocks.finality,
                srcTimelocks.publicUnlock,
                dstTimelocks.finality,
                dstTimelocks.unlock,
                dstTimelocks.publicUnlock
            )
        );
    }

    function _prepareDataSrc(
        bytes32 secret,
        uint256 srcAmount,
        uint256 dstAmount
    ) internal view returns(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        bytes memory extraData,
        Escrow srcClone
    ) {
        uint256 safetyDeposit = dstAmount * 10 / 100;
        order = _buildOrder(
            alice.addr,
            bob.addr,
            address(usdc),
            address(dai),
            srcAmount,
            dstAmount,
            MakerTraits.wrap(0),
            InteractionParams("", "", "", "", abi.encodePacked(alice.addr), abi.encodePacked(bob.addr), "", ""),
            ""
        );

        orderHash = limitOrderProtocol.hashOrder(order);

        extraData = _buidDynamicData(
            secret,
            block.chainid,
            address(dai),
            safetyDeposit
        );

        srcClone = Escrow(escrowFactory.addressOfEscrow(orderHash));
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
        address msgSender = bob.addr;
        uint256 deployedAt = block.timestamp;
        bytes32 salt = keccak256(abi.encodePacked(deployedAt, data, msgSender));
        Escrow dstClone = Escrow(escrowFactory.addressOfEscrow(salt));
        return (escrowImmutables, dstClone);
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
        uint256 hashlock = uint256(keccak256(abi.encodePacked(secret)));
        uint256 safetyDeposit = amount * 10 / 100;
        uint256 srcCancellationTimestamp = block.timestamp + srcTimelocks.finality + srcTimelocks.publicUnlock;
        immutables = IEscrowFactory.DstEscrowImmutablesCreation(
            hashlock,
            maker,
            taker,
            token,
            amount,
            safetyDeposit,
            dstTimelocks,
            srcCancellationTimestamp
        );
        data = abi.encode(
            hashlock,
            alice.addr,
            bob.addr,
            block.chainid,
            address(dai),
            amount,
            safetyDeposit,
            dstTimelocks.finality,
            dstTimelocks.unlock,
            dstTimelocks.publicUnlock
        );
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
    ) internal view returns(IOrderMixin.Order memory) {
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
                sum += allInteractions[i].length - 1;
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
            makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << _HAS_EXTENSION_FLAG));
        }

        if (interactions.preInteraction.length > 0) {
            makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << _PRE_INTERACTION_CALL_FLAG));
        }

        if (interactions.postInteraction.length > 0) {
            makerTraits = MakerTraits.wrap(MakerTraits.unwrap(makerTraits) | (1 << _POST_INTERACTION_CALL_FLAG));
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
        return order;
    }

    function _buildTakerTraits() internal pure returns(TakerTraits) {
        // TODO: build taker traits
        return TakerTraits.wrap(1 << 255);
    }
}
