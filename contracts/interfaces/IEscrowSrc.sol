// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "solidity-utils/libraries/AddressLib.sol";

import { PackedAddresses } from "../libraries/PackedAddressesLib.sol";
import { Timelocks } from "../libraries/TimelocksLib.sol";

/**
 * @title Source Escrow interface for cross-chain atomic swap.
 * @notice Interface implies locking funds initially and then unlocking them with verification of the secret presented.
 */
interface IEscrowSrc {
    // Data for the order immutables.
    struct EscrowImmutables {
        bytes32 orderHash;
        uint256 srcAmount;
        uint256 dstAmount;
        // maker, taker, token in two 32-byte slots
        PackedAddresses packedAddresses;
        // --- Extra data ---
        // Hash of the secret.
        bytes32 hashlock;
        uint256 dstChainId;
        Address dstToken;
        // 16 bytes for srcSafetyDeposit and 16 bytes for dstSafetyDeposit.
        uint256 deposits;
        Timelocks timelocks;
    }

    /**
     * @notice Withdraws funds to a specified target.
     * @dev Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
     * The safety deposit is sent to the caller.
     * @param secret The secret that unlocks the escrow.
     */
    function withdrawTo(bytes32 secret, address target) external;

    /**
     * @notice Returns the immutable parameters of the escrow contract.
     * @dev The immutables are stored at the end of the proxy clone contract bytecode and
     * are added to the calldata each time the proxy clone function is called.
     * @return The immutables of the escrow contract.
     */
    function escrowImmutables() external pure returns (EscrowImmutables calldata);
}
