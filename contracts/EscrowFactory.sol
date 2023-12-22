// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

// import { IOrderMixin } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IOrderMixin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IOrderMixin, SimpleSettlementExtension } from "@1inch/limit-order-settlement/contracts/SimpleSettlementExtension.sol";
import { Address, AddressLib } from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import { ClonesWithImmutableArgs } from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { EscrowRegistry } from "./EscrowRegistry.sol";

contract EscrowFactory is IEscrowFactory, SimpleSettlementExtension {
    using AddressLib for Address;
    using ClonesWithImmutableArgs for address;
    using SafeERC20 for IERC20;

    address public immutable IMPLEMENTATION;

    constructor(address implementation, address limitOrderProtocol, IERC20 token)
        SimpleSettlementExtension(limitOrderProtocol, token)
    {
        IMPLEMENTATION = implementation;
    }

    /**
     * @dev Creates a new escrow contract for maker.
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) internal override {
        (
            uint256 resolverFee,
            address integrator,
            uint256 integrationFee,
            bytes calldata dataReturned
        ) = _parseFeeData(extraData, order.makingAmount, makingAmount, takingAmount);

        bytes calldata extraDataParams = dataReturned[:320];
        bytes calldata whitelist = dataReturned[320:];

        if (!_isWhitelisted(whitelist, taker)) revert ResolverIsNotWhitelisted();

        _chargeFee(taker, resolverFee);
        if (integrationFee > 0) {
            IERC20(order.takerAsset.get()).safeTransferFrom(taker, integrator, integrationFee);
        }

        bytes memory interactionParams = abi.encode(
            order.maker,
            taker,
            block.chainid, // srcChainId
            order.makerAsset.get(), // srcToken
            makingAmount, // srcAmount
            takingAmount // dstAmount
        );
        bytes memory data = abi.encodePacked(
            block.timestamp, // deployedAt
            interactionParams,
            extraDataParams
        );
        // Salt is orderHash
        address escrow = ClonesWithImmutableArgs.addressOfClone3(orderHash);
        if (IERC20(order.makerAsset.get()).balanceOf(escrow) < makingAmount) revert InsufficientEscrowBalance();
        _createEscrow(data, orderHash);
    }

    /**
     * @dev Creates a new escrow contract for taker.
     */
    function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external {
        bytes memory data = abi.encode(
            block.timestamp, // deployedAt
            dstEscrowImmutables.hashlock,
            dstEscrowImmutables.maker,
            block.chainid,
            dstEscrowImmutables.token,
            dstEscrowImmutables.amount,
            dstEscrowImmutables.safetyDeposit,
            dstEscrowImmutables.timelocks.finality,
            dstEscrowImmutables.timelocks.unlock,
            dstEscrowImmutables.timelocks.publicUnlock
        );
        bytes32 salt = keccak256(abi.encodePacked(data, msg.sender));
        EscrowRegistry escrow = _createEscrow(data, salt);
        IERC20(dstEscrowImmutables.token).safeTransferFrom(
            msg.sender, address(escrow), dstEscrowImmutables.amount + dstEscrowImmutables.safetyDeposit
        );
    }

    function addressOfEscrow(bytes32 salt) external view returns (address) {
        return ClonesWithImmutableArgs.addressOfClone3(salt);
    }

    function _createEscrow(
        bytes memory data,
        bytes32 salt
    ) private returns (EscrowRegistry clone) {
        clone = EscrowRegistry(IMPLEMENTATION.clone3(data, salt));
    }

    function _isWhitelisted(bytes calldata /* whitelist */, address /* resolver */) internal view override returns (bool) {
        return true;
    }
}
