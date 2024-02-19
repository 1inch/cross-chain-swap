// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { PackedAddresses } from "../libraries/PackedAddressesLib.sol";
import { Timelocks } from "../libraries/TimelocksLib.sol";

/**
 * @title Destination Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 */
interface IEscrowDst {

    /**
     * Data for the order immutables.
     * token, amount and safetyDeposit are related to the destination chain.
    */
    struct EscrowImmutables {
        bytes32 orderHash;
        // Hash of the secret.
        bytes32 hashlock;
        // maker, taker, token in two 32-byte slots
        PackedAddresses packedAddresses;
        uint256 amount;
        uint256 safetyDeposit;
        Timelocks timelocks;
    }

    /**
     * @notice Returns the immutable parameters of the escrow contract.
     * @dev The immutables are stored at the end of the proxy clone contract bytecode and
     * are added to the calldata each time the proxy clone function is called.
     * @return The immutables of the escrow contract.
     */
    function escrowImmutables() external pure returns (EscrowImmutables calldata);
}
