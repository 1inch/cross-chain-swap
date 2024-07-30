// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { BaseEscrowFactory } from "../../../contracts/BaseEscrowFactory.sol";
import { EscrowSrc } from "../../../contracts/EscrowSrc.sol";
import { IBaseEscrow } from "../../../contracts/interfaces/IBaseEscrow.sol";
import { ERC20True } from "../../../contracts/mocks/ERC20True.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraits } from "limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { TakerTraits } from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Timelocks, TimelocksSettersLib } from "./TimelocksSettersLib.sol";

library CrossChainTestLib {

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

    struct OrderDetails {
        address maker;
        address receiver;
        address srcToken;
        address dstToken;
        uint256 srcAmount;
        uint256 dstAmount;
        uint256 srcSafetyDeposit;
        uint256 dstSafetyDeposit;
        address[] resolvers;
        uint32 resolverFee;
        bytes auctionDetails;
    }

    struct EscrowDetails {
        bytes32 hashlock;
        Timelocks timelocks;
        bool fakeOrder;
        bool allowMultipleFills;
    }

    struct SwapData {
        IOrderMixin.Order order;
        bytes32 orderHash;
        bytes extraData;
        bytes extension;
        EscrowSrc srcClone;
        IBaseEscrow.Immutables immutables;
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

    bytes32 internal constant ZKSYNC_PROFILE_HASH = keccak256(abi.encodePacked("zksync"));

    function setTimelocks(
        SrcTimelocks memory srcTimelocks,
        DstTimelocks memory dstTimelocks
    ) internal view returns (Timelocks timelocksSrc, Timelocks timelocksDst) {
        timelocksSrc = TimelocksSettersLib.init(
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
    
    function buildAuctionDetails(
        uint24 gasBumpEstimate,
        uint32 gasPriceEstimate,
        uint32 startTime,
        uint24 duration,
        uint32 delay,
        uint24 initialRateBump,
        bytes memory auctionPoints
    ) internal pure returns (bytes memory auctionDetails) {
        auctionDetails = abi.encodePacked(
            gasBumpEstimate,
            gasPriceEstimate,
            startTime + delay,
            duration,
            initialRateBump,
            auctionPoints
        );
    }

    function buildMakerTraits(MakerTraitsParams memory params) internal pure returns (MakerTraits) {
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

    function buildTakerTraits(
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

    function buildOrder(
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
            makerTraits = buildMakerTraits(makerTraitsParams);
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

    function buidDynamicData(
        bytes32 hashlock,
        uint256 chainId,
        address token,
        uint256 srcSafetyDeposit,
        uint256 dstSafetyDeposit,
        Timelocks timelocks
    ) internal pure returns (bytes memory) {
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

    function prepareDataSrc(
        OrderDetails memory orderDetails,
        EscrowDetails memory escrowDetails,
        address factory,
        IOrderMixin limitOrderProtocol
    ) internal returns(SwapData memory swapData) {
        swapData.extraData = buidDynamicData(
            escrowDetails.hashlock,
            block.chainid,
            orderDetails.dstToken,
            orderDetails.srcSafetyDeposit,
            orderDetails.dstSafetyDeposit,
            escrowDetails.timelocks
        );

        bytes memory whitelist = abi.encodePacked(uint32(block.timestamp)); // auction start time
        for (uint256 i = 0; i < orderDetails.resolvers.length; i++) {
            whitelist = abi.encodePacked(whitelist, uint80(uint160(orderDetails.resolvers[i])), uint16(0)); // resolver address, time delta
        }

        if (escrowDetails.fakeOrder) {
            swapData.order = IOrderMixin.Order({
                salt: 0,
                maker: Address.wrap(uint160(orderDetails.maker)),
                receiver: Address.wrap(uint160(orderDetails.receiver)),
                makerAsset: Address.wrap(uint160(address(orderDetails.srcToken))),
                takerAsset: Address.wrap(uint160(address(orderDetails.dstToken))),
                makingAmount: orderDetails.srcAmount,
                takingAmount: orderDetails.dstAmount,
                makerTraits: MakerTraits.wrap(0)
            });
        } else {
            bytes memory postInteractionData = abi.encodePacked(
                factory,
                orderDetails.resolverFee,
                whitelist,
                bytes1(0x08) | bytes1(0x01), // 0x08 - whitelist length = 1, 0x01 - turn on resolver fee
                swapData.extraData
            );

            bytes memory gettersAmountData = abi.encodePacked(factory, orderDetails.auctionDetails);

            (swapData.order, swapData.extension) = buildOrder(
                orderDetails.maker,
                orderDetails.receiver,
                orderDetails.srcToken,
                address(new ERC20True()),
                orderDetails.srcAmount,
                orderDetails.dstAmount,
                MakerTraits.wrap(0),
                escrowDetails.allowMultipleFills,
                InteractionParams("", "", gettersAmountData, gettersAmountData, "", "", "", postInteractionData),
                ""
            );
        }

        swapData.orderHash = limitOrderProtocol.hashOrder(swapData.order);

        swapData.immutables = IBaseEscrow.Immutables({
            orderHash: swapData.orderHash,
            amount: orderDetails.srcAmount,
            maker: Address.wrap(uint160(orderDetails.maker)),
            taker: Address.wrap(uint160(orderDetails.resolvers[0])),
            token: Address.wrap(uint160(orderDetails.srcToken)),
            hashlock: escrowDetails.hashlock,
            safetyDeposit: orderDetails.srcSafetyDeposit,
            timelocks: escrowDetails.timelocks
        });

        swapData.srcClone = EscrowSrc(BaseEscrowFactory(factory).addressOfEscrowSrc(swapData.immutables));
        // 0x08 - whitelist length = 1, 0x01 - turn on resolver fee
        swapData.extraData = abi.encodePacked(orderDetails.resolverFee, whitelist, bytes1(0x08) | bytes1(0x01), swapData.extraData);
    }

    function buildDstEscrowImmutables(
        bytes32 orderHash,
        bytes32 hashlock,
        uint256 amount,
        address maker,
        address taker,
        address token,
        uint256 safetyDeposit,
        Timelocks timelocks
    ) internal pure returns (IBaseEscrow.Immutables memory immutables) {
        immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(taker)),
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocks
        });
    }
}
