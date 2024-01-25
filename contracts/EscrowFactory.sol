// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/interfaces/IOrderMixin.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SimpleSettlementExtension } from "limit-order-settlement/SimpleSettlementExtension.sol";
import { Address, AddressLib } from "solidity-utils/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/libraries/SafeERC20.sol";
import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { IEscrow } from "./interfaces/IEscrow.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";

/**
 * @title Escrow Factory contract
 * @notice Contract to create escrow contracts for cross-chain atomic swap.
 */
contract EscrowFactory is IEscrowFactory, SimpleSettlementExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;

    uint256 internal constant _EXTRA_DATA_PARAMS_OFFSET = 4;
    uint256 internal constant _WHITELIST_OFFSET = 164;
    // Address of the escrow contract implementation to clone.
    address public immutable IMPLEMENTATION;

    constructor(address implementation, address limitOrderProtocol, IERC20 token)
        SimpleSettlementExtension(limitOrderProtocol, token) {
        IMPLEMENTATION = implementation;
    }

    /**
     * @notice Creates a new escrow contract for maker on the source chain.
     * @dev The caller must be whitelisted and pre-send the safety deposit in a native token
     * to a pre-computed deterministic address of the created escrow.
     * The external postInteraction function call will be made from the Limit Order Protocol
     * after all funds have been transferred. See {IPostInteraction-postInteraction}.
     * `extraData` consists of:
     *   - 4 bytes for the fee
     *   - 5 * 32 bytes for hashlock, dstChainId, dstToken, deposits and timelocks
     *   - whitelist
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 /* orderHash */,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) internal override {
        {
            bytes calldata whitelist = extraData[_WHITELIST_OFFSET:];
            if (!_isWhitelisted(whitelist, taker)) revert ResolverIsNotWhitelisted();
        }

        // Prepare immutables for the escrow contract.
        // 11 * 32 bytes
        bytes memory data = new bytes(0x160);
        IEscrow.SrcEscrowImmutables memory immutables;
        // solhint-disable-next-line no-inline-assembly
        assembly("memory-safe") {
            immutables := add(data, 0x20)
        }
        immutables.maker = order.maker.get();
        immutables.taker = taker;
        immutables.srcChainId = block.chainid;
        immutables.srcToken = order.makerAsset.get();
        immutables.srcAmount = makingAmount;
        immutables.dstAmount = takingAmount;
        // solhint-disable-next-line no-inline-assembly
        assembly("memory-safe") {
            // Copy hashlock, dstChainId, dstToken and deposits from the extraData.
            calldatacopy(add(immutables, 0xc0), add(extraData.offset, _EXTRA_DATA_PARAMS_OFFSET), 0x80)
        }
        immutables.timelocks = Timelocks.wrap(uint256(bytes32(extraData[132:164]))).setDeployedAt(block.timestamp);

        address escrow = _createEscrow(data, 0);
        // 4 bytes for a fee +  3 * 32 bytes for hashlock, dstChainId and dstToken
        // srcSafetyDeposit is the first 16 bytes in the `deposits`
        uint256 safetyDeposit = uint128(bytes16(extraData[100:116]));
        if (
            escrow.balance < safetyDeposit ||
            IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount
        ) revert InsufficientEscrowBalance();

        uint256 resolverFee = _getResolverFee(uint256(uint32(bytes4(extraData[:4]))), order.makingAmount, makingAmount);
        _chargeFee(taker, resolverFee);
    }

    /**
     * @notice See {IEscrowFactory-createEscrow}.
     */
    function createEscrow(DstEscrowImmutablesCreation calldata dstImmutables) external payable {
        if (msg.value < dstImmutables.safetyDeposit) revert InsufficientEscrowBalance();
        // Check that the escrow cancellation will start not later than the cancellation time on the source chain.
        if (
            dstImmutables.timelocks.dstCancellationStart(block.timestamp) >
            dstImmutables.srcCancellationTimestamp
        ) revert InvalidCreationTime();

        // 32 bytes for chaiId + 7 * 32 bytes for DstEscrowImmutablesCreation
        bytes memory data = new bytes(0x100);
        IEscrow.DstEscrowImmutables memory immutables;
        // solhint-disable-next-line no-inline-assembly
        assembly("memory-safe") {
            immutables := add(data, 0x20)
        }
        immutables.chainId = block.chainid;
        immutables.hashlock = dstImmutables.hashlock;
        immutables.maker = dstImmutables.maker;
        immutables.taker = dstImmutables.taker;
        immutables.token = dstImmutables.token;
        immutables.amount = dstImmutables.amount;
        immutables.safetyDeposit = dstImmutables.safetyDeposit;
        immutables.timelocks = dstImmutables.timelocks.setDeployedAt(block.timestamp);

        address escrow = _createEscrow(data, msg.value);
        IERC20(dstImmutables.token).safeTransferFrom(
            msg.sender, escrow, dstImmutables.amount
        );
    }

    /**
     * @notice See {IEscrowFactory-addressOfEscrow}.
     */
    function addressOfEscrow(bytes memory data) public view returns (address) {
        return ClonesWithImmutableArgs.addressOfClone2(IMPLEMENTATION, data);
    }

    /**
     * @notice Creates a new escrow contract with immutable arguments.
     * @dev The escrow contract is a proxy clone created using the create2 pattern.
     * @param data Encoded immutable args.
     * @return clone The address of the created escrow contract.
     */
    function _createEscrow(
        bytes memory data,
        uint256 value
    ) private returns (address clone) {
        clone = IMPLEMENTATION.clone2(data, value);
    }
}
