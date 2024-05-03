// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { MakerTraitsLib } from "limit-order-protocol/libraries/MakerTraitsLib.sol";
import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "limit-order-settlement/extensions/ResolverFeeExtension.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";

import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { ProxyHashLib } from "./libraries/ProxyHashLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";
import { EscrowDst } from "./EscrowDst.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { MerkleStorageInvalidator } from "./MerkleStorageInvalidator.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, WhitelistExtension, ResolverFeeExtension {
    using AddressLib for Address;
    using Clones for address;
    using ImmutablesLib for IEscrow.Immutables;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 private constant _SRC_IMMUTABLES_LENGTH = 160;

    /// @notice See {IEscrowFactory-ESCROW_SRC_IMPLEMENTATION}.
    address public immutable ESCROW_SRC_IMPLEMENTATION;
    /// @notice See {IEscrowFactory-ESCROW_DST_IMPLEMENTATION}.
    address public immutable ESCROW_DST_IMPLEMENTATION;
    MerkleStorageInvalidator public immutable MERKLE_STORAGE_INVALIDATOR;
    bytes32 private immutable _PROXY_SRC_BYTECODE_HASH;
    bytes32 private immutable _PROXY_DST_BYTECODE_HASH;

    constructor(
        address limitOrderProtocol,
        IERC20 token,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) {
        ESCROW_SRC_IMPLEMENTATION = address(new EscrowSrc(rescueDelaySrc));
        ESCROW_DST_IMPLEMENTATION = address(new EscrowDst(rescueDelayDst));
        _PROXY_SRC_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_SRC_IMPLEMENTATION);
        _PROXY_DST_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_DST_IMPLEMENTATION);
        MERKLE_STORAGE_INVALIDATOR = new MerkleStorageInvalidator(limitOrderProtocol);
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     * `extraData` consists of:
     *   - ExtraDataArgs struct
     *   - whitelist
     *   - 0 / 4 bytes for the fee
     *   - 1 byte for the bitmap
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) internal override(WhitelistExtension, ResolverFeeExtension) {
        super._postInteraction(
            order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData[_SRC_IMMUTABLES_LENGTH:]
        );

        ExtraDataArgs calldata extraDataArgs;
        assembly ("memory-safe") {
            extraDataArgs := extraData.offset
        }

        bytes32 hashlock = extraDataArgs.hashlock;

        if (MakerTraitsLib.allowMultipleFills(order.makerTraits)) {
            bytes32 key = keccak256(abi.encodePacked(orderHash, extraDataArgs.hashlock));
            (uint256 validated, bytes32 validatedSecret) = MERKLE_STORAGE_INVALIDATOR.lastValidated(key);
            hashlock = validatedSecret;
            uint256 validatedIdx = uint128(validated);
            uint256 secretsAmount = validated >> 128;
            if (secretsAmount == 0) revert InvalidMultipleFills();
            uint256 onePart = order.makingAmount / secretsAmount;
            uint256 calculatedIndex = (order.makingAmount - (remainingMakingAmount - makingAmount)) / onePart - 1;
            if (calculatedIndex != validatedIdx) revert InvalidMultipleFills();
        }

        IEscrow.Immutables memory immutables = IEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: order.maker,
            taker: Address.wrap(uint160(taker)),
            token: order.makerAsset,
            amount: makingAmount,
            safetyDeposit: extraDataArgs.deposits >> 128,
            timelocks: extraDataArgs.timelocks.setDeployedAt(block.timestamp)
        });

        DstImmutablesComplement memory immutablesComplement = DstImmutablesComplement({
            maker: order.receiver.get() == address(0) ? order.maker : order.receiver,
            amount: takingAmount,
            token: extraDataArgs.dstToken,
            safetyDeposit: extraDataArgs.deposits & type(uint128).max,
            chainId: extraDataArgs.dstChainId
        });

        emit SrcEscrowCreated(immutables, immutablesComplement);

        bytes32 salt = immutables.hashMem();
        address escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt, 0);
        if (escrow.balance < immutables.safetyDeposit || IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount) {
            revert InsufficientEscrowBalance();
        }
    }

    /**
     * @notice See {IEscrowFactory-createDstEscrow}.
     */
    function createDstEscrow(IEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable {
        address token = dstImmutables.token.get();
        uint256 nativeAmount = dstImmutables.safetyDeposit;
        if (token == address(0)) {
            nativeAmount += dstImmutables.amount;
        }
        if (msg.value != nativeAmount) revert InsufficientEscrowBalance();

        IEscrow.Immutables memory immutables = dstImmutables;
        immutables.timelocks = immutables.timelocks.setDeployedAt(block.timestamp);
        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (immutables.timelocks.get(TimelocksLib.Stage.DstCancellation) > srcCancellationTimestamp) revert InvalidCreationTime();

        bytes32 salt = immutables.hashMem();
        address escrow = ESCROW_DST_IMPLEMENTATION.cloneDeterministic(salt, msg.value);
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.amount);
        }

        emit DstEscrowCreated(escrow, dstImmutables.taker);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(IEscrow.Immutables calldata immutables) external view returns (address) {
        return Create2.computeAddress(immutables.hash(), _PROXY_SRC_BYTECODE_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IEscrow.Immutables calldata immutables) external view returns (address) {
        return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);
    }
}
