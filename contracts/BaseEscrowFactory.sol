// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Create2 } from "openzeppelin-contracts/contracts/utils/Create2.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraitsLib } from "limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { ResolverValidationExtension } from "limit-order-settlement/contracts/extensions/ResolverValidationExtension.sol";
import { ExtensionLib } from "limit-order-settlement/contracts/extensions/ExtensionLib.sol";

import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { FeeCalcLib } from "./libraries/FeeCalcLib.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { IEscrowDst } from "./interfaces/IEscrowDst.sol";
import { SRC_IMMUTABLES_LENGTH } from "./EscrowFactoryContext.sol";
import { MerkleStorageInvalidator } from "./MerkleStorageInvalidator.sol";

/**
 * @title Abstract contract for escrow factory
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 * @dev Immutable variables must be set in the constructor of the derived contracts.
 * @custom:security-contact security@1inch.io
 */
abstract contract BaseEscrowFactory is IEscrowFactory, ResolverValidationExtension, MerkleStorageInvalidator {
    using AddressLib for Address;
    using Clones for address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using ImmutablesLib for IEscrowDst.ImmutablesDst;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;
    using ExtensionLib for bytes;

    /// @notice See {IEscrowFactory-ESCROW_SRC_IMPLEMENTATION}.
    address public immutable ESCROW_SRC_IMPLEMENTATION;
    /// @notice See {IEscrowFactory-ESCROW_DST_IMPLEMENTATION}.
    address public immutable ESCROW_DST_IMPLEMENTATION;
    bytes32 internal immutable _PROXY_SRC_BYTECODE_HASH;
    bytes32 internal immutable _PROXY_DST_BYTECODE_HASH;

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
    ) internal override(ResolverValidationExtension) {
        uint256 superArgsLength = extraData.length - SRC_IMMUTABLES_LENGTH;
        super._postInteraction(
            order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData[:superArgsLength]
        );

        ExtraDataArgs calldata extraDataArgs;
        assembly ("memory-safe") {
            extraDataArgs := add(extraData.offset, superArgsLength)
        }

        bytes32 hashlock;

        if (MakerTraitsLib.allowMultipleFills(order.makerTraits)) {
            uint256 partsAmount = uint256(extraDataArgs.hashlockInfo) >> 240;
            if (partsAmount < 2) revert InvalidSecretsAmount();
            bytes32 key = keccak256(abi.encodePacked(orderHash, uint240(uint256(extraDataArgs.hashlockInfo))));
            ValidationData memory validated = lastValidated[key];
            hashlock = validated.leaf;
            if (!_isValidPartialFill(makingAmount, remainingMakingAmount, order.makingAmount, partsAmount, validated.index)) {
                revert InvalidPartialFill();
            }
        } else {
            hashlock = extraDataArgs.hashlockInfo;
        }

        if (extraDataArgs.integratorShare > FeeCalcLib._BASE_1E2) revert InvalidIntegratorShare();

        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: order.maker,
            taker: Address.wrap(uint160(taker)),
            token: order.makerAsset,
            amount: makingAmount,
            safetyDeposit: extraDataArgs.deposits >> 128,
            timelocks: extraDataArgs.timelocks.setDeployedAt(block.timestamp)
        });

        uint256 protocolFee = _processDiscountForProtocolFee(
            extraData[:superArgsLength],
            taker,
            extraDataArgs.protocolFee,
            extraDataArgs.whitelistDiscountNumerator
        );

        if (extraDataArgs.integratorFee + protocolFee > FeeCalcLib._BASE_1E5) revert InvalidTotalFees();

        (uint256 integratorFeeAmount, uint256 protocolFeeAmount) = FeeCalcLib.getFeeAmounts(
            takingAmount,
            protocolFee,
            extraDataArgs.integratorFee,
            extraDataArgs.integratorShare
        );

        DstImmutablesComplement memory immutablesComplement = DstImmutablesComplement({
            maker: order.receiver.get() == address(0) ? order.maker : order.receiver,
            amount: takingAmount,
            token: extraDataArgs.dstToken,
            protocolFeeRecipient: extraDataArgs.protocolFeeRecipient,
            integratorFeeRecipient: extraDataArgs.integratorFeeRecipient,
            safetyDeposit: extraDataArgs.deposits & type(uint128).max,
            chainId: extraDataArgs.dstChainId,
            protocolFeeAmount: protocolFeeAmount,
            integratorFeeAmount: integratorFeeAmount
        });

        emit SrcEscrowCreated(immutables, immutablesComplement);

        bytes32 salt = immutables.hashMem();
        address escrow = _deployEscrow(salt, 0, ESCROW_SRC_IMPLEMENTATION);
        if (escrow.balance < immutables.safetyDeposit || IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount) {
            revert InsufficientEscrowBalance();
        }
    }

    /**
     * @notice See {IEscrowFactory-createDstEscrow}.
     */
    function createDstEscrow(IEscrowDst.ImmutablesDst calldata dstImmutables, uint256 srcCancellationTimestamp) external payable {
        address token = dstImmutables.core.token.get();
        uint256 nativeAmount = dstImmutables.core.safetyDeposit;
        if (token == address(0)) {
            nativeAmount += dstImmutables.core.amount;
        }
        if (msg.value != nativeAmount) revert InsufficientEscrowBalance();

        IEscrowDst.ImmutablesDst memory immutables = dstImmutables;
        immutables.core.timelocks = immutables.core.timelocks.setDeployedAt(block.timestamp);
        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (immutables.core.timelocks.get(TimelocksLib.Stage.DstCancellation) > srcCancellationTimestamp) revert InvalidCreationTime();

        bytes32 salt = immutables.hashMem();
        address escrow = _deployEscrow(salt, msg.value, ESCROW_DST_IMPLEMENTATION);
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.core.amount);
        }

        emit DstEscrowCreated(escrow, dstImmutables.core.hashlock, dstImmutables.core.taker);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowSrc}.
     */
    function addressOfEscrowSrc(IBaseEscrow.Immutables calldata immutables) external view virtual returns (address) {
        return Create2.computeAddress(immutables.hash(), _PROXY_SRC_BYTECODE_HASH);
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrowDst}.
     */
    function addressOfEscrowDst(IEscrowDst.ImmutablesDst calldata immutables) external view virtual returns (address) {
        return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);
    }

    /**
     * @notice Deploys a new escrow contract.
     * @param salt The salt for the deterministic address computation.
     * @param value The value to be sent to the escrow contract.
     * @param implementation Address of the implementation.
     * @return escrow The address of the deployed escrow contract.
     */
    function _deployEscrow(bytes32 salt, uint256 value, address implementation) internal virtual returns (address escrow) {
        escrow = implementation.cloneDeterministic(salt, value);
    }

    function _isValidPartialFill(
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        uint256 orderMakingAmount,
        uint256 partsAmount,
        uint256 validatedIndex
    ) internal pure returns (bool) {
        uint256 calculatedIndex = (orderMakingAmount - remainingMakingAmount + makingAmount - 1) * partsAmount / orderMakingAmount;

        if (remainingMakingAmount == makingAmount) {
            // If the order is filled to completion, a secret with index i + 1 must be used
            // where i is the index of the secret for the last part.
            return (calculatedIndex + 2 == validatedIndex);
        } else if (orderMakingAmount != remainingMakingAmount) {
            // Calculate the previous fill index only if this is not the first fill.
            uint256 prevCalculatedIndex = (orderMakingAmount - remainingMakingAmount - 1) * partsAmount / orderMakingAmount;
            if (calculatedIndex == prevCalculatedIndex) return false;
        }

        return calculatedIndex + 1 == validatedIndex;
    }
    
    function _processDiscountForProtocolFee(
        bytes calldata extraData,
        address taker,
        uint256 protocolFee,
        uint256 whitelistDiscountNumerator
    ) internal view returns (uint256 protocolFeeDiscounted) {
        if (whitelistDiscountNumerator > FeeCalcLib._BASE_1E2) revert InvalidWhitelistDiscountNumerator();

        bool feeEnabled = extraData.resolverFeeEnabled();
        uint256 resolversCount = extraData.resolversCount();

        if (feeEnabled) {
            extraData = extraData[4:];
        }

        uint256 allowedTime = uint32(bytes4(extraData[0:4]));
        protocolFeeDiscounted = protocolFee;

        if (_isWhitelisted(allowedTime, extraData[4:4+resolversCount * 12], resolversCount, taker)) {
            protocolFeeDiscounted = protocolFeeDiscounted * whitelistDiscountNumerator / FeeCalcLib._BASE_1E2;
        }       
    }
}
