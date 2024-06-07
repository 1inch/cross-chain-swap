// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address, AddressLib } from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

import { IOrderMixin } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IOrderMixin.sol";
import { MakerTraitsLib } from "@1inch/limit-order-protocol-contract/contracts/libraries/MakerTraitsLib.sol";
import { BaseExtension } from "limit-order-settlement/extensions/BaseExtension.sol";
import { ResolverFeeExtension } from "limit-order-settlement/extensions/ResolverFeeExtension.sol";
import { WhitelistExtension } from "limit-order-settlement/extensions/WhitelistExtension.sol";

import { ImmutablesLib } from "contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "contracts/libraries/TimelocksLib.sol";
import { ZkSyncLib } from "contracts/libraries/ZkSyncLib.sol";

import { IEscrow } from "contracts/interfaces/IEscrow.sol";
import { EscrowSrcZkSync } from "./EscrowSrcZkSync.sol";
import { EscrowDstZkSync } from "./EscrowDstZkSync.sol";
import { IEscrowFactoryZkSync } from "./IEscrowFactoryZkSync.sol";
import { MinimalProxyZkSync } from "./MinimalProxyZkSync.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactoryZkSync is IEscrowFactoryZkSync, WhitelistExtension, ResolverFeeExtension {
    using AddressLib for Address;
    using ImmutablesLib for IEscrow.Immutables;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 private constant _SRC_IMMUTABLES_LENGTH = 160;

    address public immutable IMPL_SRC;
    address public immutable IMPL_DST;
    bytes32 public immutable ESCROW_SRC_INPUT_HASH;
    bytes32 public immutable ESCROW_DST_INPUT_HASH;
    bytes32 private immutable _PROXY_SRC_BYTECODE_HASH;
    bytes32 private immutable _PROXY_DST_BYTECODE_HASH;

    constructor(
        address limitOrderProtocol,
        IERC20 token,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    ) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token) {
        IMPL_SRC = address(new EscrowSrcZkSync(rescueDelaySrc));
        IMPL_DST = address(new EscrowDstZkSync(rescueDelayDst));
        ESCROW_SRC_INPUT_HASH = keccak256(abi.encode(IMPL_SRC));
        ESCROW_DST_INPUT_HASH = keccak256(abi.encode(IMPL_DST));
        MinimalProxyZkSync proxySrc = new MinimalProxyZkSync(IMPL_SRC);
        MinimalProxyZkSync proxyDst = new MinimalProxyZkSync(IMPL_DST);
        bytes32 bytecodeHashSrc;
        bytes32 bytecodeHashDst;
        assembly ("memory-safe") {
            bytecodeHashSrc := extcodehash(proxySrc)
            bytecodeHashDst := extcodehash(proxyDst)
        }
        _PROXY_SRC_BYTECODE_HASH = bytecodeHashSrc;
        _PROXY_DST_BYTECODE_HASH = bytecodeHashDst;
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     * `extraData` consists of:
     *   - ExtraDataImmutables struct
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
        if (MakerTraitsLib.allowMultipleFills(order.makerTraits)) revert InvalidMakerTraits();

        super._postInteraction(
            order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData[_SRC_IMMUTABLES_LENGTH:]
        );

        ExtraDataImmutables calldata extraDataImmutables;
        assembly ("memory-safe") {
            extraDataImmutables := extraData.offset
        }

        IEscrow.Immutables memory immutables = IEscrow.Immutables({
            orderHash: orderHash,
            hashlock: extraDataImmutables.hashlock,
            maker: order.maker,
            taker: Address.wrap(uint160(taker)),
            token: order.makerAsset,
            amount: makingAmount,
            safetyDeposit: extraDataImmutables.deposits >> 128,
            timelocks: extraDataImmutables.timelocks.setDeployedAt(block.timestamp)
        });

        DstImmutablesComplement memory immutablesComplement = DstImmutablesComplement({
            maker: order.receiver.get() == address(0) ? order.maker : order.receiver,
            amount: takingAmount,
            token: extraDataImmutables.dstToken,
            safetyDeposit: extraDataImmutables.deposits & type(uint128).max,
            chainId: extraDataImmutables.dstChainId
        });

        emit SrcEscrowCreated(immutables, immutablesComplement);

        bytes32 salt = immutables.hashMem();
        address escrow = address(new MinimalProxyZkSync{salt: salt}(IMPL_SRC));
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
        address escrow = address(new MinimalProxyZkSync{salt: salt, value: msg.value}(IMPL_DST));
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.amount);
        }

        emit DstEscrowCreated(escrow, dstImmutables.taker);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(IEscrow.Immutables calldata immutables) external view returns (address) {
        return ZkSyncLib.computeAddressZkSync(immutables.hash(), _PROXY_SRC_BYTECODE_HASH, address(this), ESCROW_SRC_INPUT_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IEscrow.Immutables calldata immutables) external view returns (address) {
        return ZkSyncLib.computeAddressZkSync(immutables.hash(), _PROXY_DST_BYTECODE_HASH, address(this), ESCROW_DST_INPUT_HASH);
    }
}
