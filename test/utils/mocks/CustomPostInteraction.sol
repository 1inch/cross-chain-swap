// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { IPostInteraction } from "limit-order-protocol/contracts/interfaces/IPostInteraction.sol";

contract CustomPostInteraction is IPostInteraction {
    event Invoked(bytes extraData);

    function postInteraction(
        IOrderMixin.Order calldata /* order */,
        bytes calldata /* extension */,
        bytes32 /* orderHash */,
        address /* taker */,
        uint256 /* makingAmount */,
        uint256 /* takingAmount */,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external {
        emit Invoked(extraData);
    }
}