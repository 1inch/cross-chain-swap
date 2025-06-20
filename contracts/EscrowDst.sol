// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Create2 } from "openzeppelin-contracts/contracts/utils/Create2.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";
import { AddressLib, Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";

import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IEscrowDst } from "./interfaces/IEscrowDst.sol";
import { BaseEscrow } from "./BaseEscrow.sol";
import { Escrow } from "./Escrow.sol";

/**
 * @title Destination Escrow contract for cross-chain atomic swap.
 * @notice Contract to initially lock funds and then unlock them with verification of the secret presented.
 * @dev Funds are locked in at the time of contract deployment. For this taker calls the `EscrowFactory.createDstEscrow` function.
 * To perform any action, the caller must provide the same Immutables values used to deploy the clone contract.
 * @custom:security-contact security@1inch.io
 */
contract EscrowDst is Escrow, IEscrowDst {
    using SafeERC20 for IERC20;
    using AddressLib for Address;
    using ImmutablesLib for ImmutablesDst;
    using TimelocksLib for Timelocks;

    constructor(uint32 rescueDelay, IERC20 accessToken) BaseEscrow(rescueDelay, accessToken) {}

    /**
     * @notice See {IBaseEscrow-withdraw}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----
     */
    function withdraw(bytes32 secret, ImmutablesDst calldata immutables)
        external
        onlyTaker(immutables.core)
        onlyAfter(immutables.core.timelocks.get(TimelocksLib.Stage.DstWithdrawal))
        onlyBefore(immutables.core.timelocks.get(TimelocksLib.Stage.DstCancellation))
    {
        _withdraw(secret, immutables);
    }

    /**
     * @notice See {IBaseEscrow-publicWithdraw}.
     * @dev The function works on the time intervals highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----
     */
    function publicWithdraw(bytes32 secret, ImmutablesDst calldata immutables)
        external
        onlyAccessTokenHolder()
        onlyAfter(immutables.core.timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal))
        onlyBefore(immutables.core.timelocks.get(TimelocksLib.Stage.DstCancellation))
    {
        _withdraw(secret, immutables);
    }

    /**
     * @notice See {IBaseEscrow-rescueFunds}.
     */
    function rescueFunds(address token, uint256 amount, ImmutablesDst calldata immutables)
        external
        onlyTaker(immutables.core)
        onlyValidImmutables(immutables.hash())
        onlyAfter(immutables.core.timelocks.rescueStart(RESCUE_DELAY))
    {
        _uniTransfer(token, msg.sender, amount);
        emit FundsRescued(token, amount);
    }

    /**
     * @notice See {IBaseEscrow-cancel}.
     * @dev The function works on the time interval highlighted with capital letters:
     * ---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCELLATION ----
     */
    function cancel(ImmutablesDst calldata immutables)
        external
        onlyTaker(immutables.core)
        onlyValidImmutables(immutables.hash())
        onlyAfter(immutables.core.timelocks.get(TimelocksLib.Stage.DstCancellation))
    {
        _uniTransfer(immutables.core.token.get(), immutables.core.taker.get(), immutables.core.amount);
        _ethTransfer(msg.sender, immutables.core.safetyDeposit);
        emit EscrowCancelled();
    }

    /**
     * @dev Transfers ERC20 (or native) tokens to the maker and native tokens to the caller.
     * @param immutables The immutable values used to deploy the clone contract.
     */
    function _withdraw(bytes32 secret, ImmutablesDst calldata immutables)
        internal
        onlyValidImmutables(immutables.hash())
        onlyValidSecret(secret, immutables.core)
    {
        if (immutables.integratorFeeAmount > 0) {
            _uniTransfer(
                immutables.core.token.get(), 
                immutables.integratorFeeRecipient.get(), 
                immutables.integratorFeeAmount
            );
        }
        if (immutables.protocolFeeAmount > 0) {
            _uniTransfer(
                immutables.core.token.get(), 
                immutables.protocolFeeRecipient.get(), 
                immutables.protocolFeeAmount
            );
        }

        _uniTransfer(
            immutables.core.token.get(), 
            immutables.core.maker.get(), 
            immutables.core.amount - immutables.integratorFeeAmount - immutables.protocolFeeAmount
        );
        _ethTransfer(msg.sender, immutables.core.safetyDeposit);
        emit EscrowWithdrawal(secret);
    }
}
