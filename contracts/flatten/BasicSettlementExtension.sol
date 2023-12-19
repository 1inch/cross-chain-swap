// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IFeeBank {
    /**
     * @notice Returns the available credit for a given account in the FeeBank contract.
     * @param account The address of the account for which the available credit is being queried.
     * @return availableCredit The available credit of the queried account.
     */
    function availableCredit(address account) external view returns (uint256 availableCredit);

    /**
     * @notice Increases the caller's available credit by the specified amount.
     * @param amount The amount of credit to be added to the caller's account.
     * @return totalAvailableCredit The updated available credit of the caller's account.
     */
    function deposit(uint256 amount) external returns (uint256 totalAvailableCredit);

    /**
     * @notice Increases the specified account's available credit by the specified amount.
     * @param account The address of the account for which the available credit is being increased.
     * @param amount The amount of credit to be added to the account.
     * @return totalAvailableCredit The updated available credit of the specified account.
     */
    function depositFor(address account, uint256 amount) external returns (uint256 totalAvailableCredit);

    /**
     * @notice Increases the caller's available credit by a specified amount with permit.
     * @param amount The amount of credit to be added to the caller's account.
     * @param permit The permit data authorizing the transaction.
     * @return totalAvailableCredit The updated available credit of the caller's account.
     */
    function depositWithPermit(uint256 amount, bytes calldata permit) external returns (uint256 totalAvailableCredit);

    /**
     * @notice Increases the specified account's available credit by a specified amount with permit.
     * @param account The address of the account for which the available credit is being increased.
     * @param amount The amount of credit to be added to the account.
     * @param permit The permit data authorizing the transaction.
     * @return totalAvailableCredit The updated available credit of the specified account.
     */
    function depositForWithPermit(address account, uint256 amount, bytes calldata permit) external returns (uint256 totalAvailableCredit);

    /**
     * @notice Withdraws a specified amount of credit from the caller's account.
     * @param amount The amount of credit to be withdrawn from the caller's account.
     * @return totalAvailableCredit The updated available credit of the caller's account.
     */
    function withdraw(uint256 amount) external returns (uint256 totalAvailableCredit);

    /**
     * @notice Withdraws a specified amount of credit to the specified account.
     * @param account The address of the account to which the credit is being withdrawn.
     * @param amount The amount of credit to be withdrawn.
     * @return totalAvailableCredit The updated available credit of the caller's account.
     */
    function withdrawTo(address account, uint256 amount) external returns (uint256 totalAvailableCredit);
}

////import { IFeeBank } from "./IFeeBank.sol";

interface IFeeBankCharger {
    /**
     * @notice Returns the instance of the FeeBank contract.
     * @return The instance of the FeeBank contract.
     */
    function feeBank() external view returns (IFeeBank);

    /**
     * @notice Returns the available credit for a given account.
     * @param account The address of the account for which the available credit is being queried.
     * @return The available credit of the queried account.
     */
    function availableCredit(address account) external view returns (uint256);

    /**
     * @notice Increases the available credit of a given account by a specified amount.
     * @param account The address of the account for which the available credit is being increased.
     * @param amount The amount by which the available credit will be increased.
     * @return allowance The updated available credit of the specified account.
     */
    function increaseAvailableCredit(address account, uint256 amount) external returns (uint256 allowance);

    /**
     * @notice Decreases the available credit of a given account by a specified amount.
     * @param account The address of the account for which the available credit is being decreased.
     * @param amount The amount by which the available credit will be decreased.
     * @return allowance The updated available credit of the specified account.
     */
    function decreaseAvailableCredit(address account, uint256 amount) external returns (uint256 allowance);
}

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
////import { IFeeBankCharger } from "./interfaces/IFeeBankCharger.sol";
////import { IFeeBank } from "./interfaces/IFeeBank.sol";

/**
 * @title FeeBank
 * @notice FeeBank contract introduces a credit system for paying fees.
 * A user can deposit tokens to the FeeBank contract, obtain credits and then use them to pay fees.
 * @dev FeeBank is coupled with FeeBankCharger to actually charge fees.
 */
contract FeeBank is IFeeBank, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();

    IERC20 private immutable _token;
    IFeeBankCharger private immutable _charger;

    mapping(address account => uint256 availableCredit) private _accountDeposits;

    constructor(IFeeBankCharger charger_, IERC20 inch_, address owner_) Ownable(owner_) {
        if (address(inch_) == address(0)) revert ZeroAddress();
        _charger = charger_;
        _token = inch_;
    }

    /**
     * @notice See {IFeeBank-availableCredit}.
     */
    function availableCredit(address account) external view returns (uint256) {
        return _charger.availableCredit(account);
    }

    /**
     * @notice See {IFeeBank-deposit}.
     */
    function deposit(uint256 amount) external returns (uint256) {
        return _depositFor(msg.sender, amount);
    }

    /**
     * @notice See {IFeeBank-depositFor}.
     */
    function depositFor(address account, uint256 amount) external returns (uint256) {
        return _depositFor(account, amount);
    }

    /**
     * @notice See {IFeeBank-depositWithPermit}.
     */
    function depositWithPermit(uint256 amount, bytes calldata permit) external returns (uint256) {
        return depositForWithPermit(msg.sender, amount, permit);
    }

    /**
     * @notice See {IFeeBank-depositForWithPermit}.
     */
    function depositForWithPermit(
        address account,
        uint256 amount,
        bytes calldata permit
    ) public returns (uint256) {
        _token.safePermit(permit);
        return _depositFor(account, amount);
    }

    /**
     * @notice See {IFeeBank-withdraw}.
     */
    function withdraw(uint256 amount) external returns (uint256) {
        return _withdrawTo(msg.sender, amount);
    }

    /**
     * @notice See {IFeeBank-withdrawTo}.
     */
    function withdrawTo(address account, uint256 amount) external returns (uint256) {
        return _withdrawTo(account, amount);
    }

    /**
     * @notice Admin method returns commissions spent by users.
     * @param accounts Accounts whose commissions are being withdrawn.
     * @return totalAccountFees The total amount of accounts commissions.
     */
    function gatherFees(address[] calldata accounts) external onlyOwner returns (uint256 totalAccountFees) {
        uint256 accountsLength = accounts.length;
        unchecked {
            for (uint256 i = 0; i < accountsLength; ++i) {
                address account = accounts[i];
                uint256 accountDeposit = _accountDeposits[account];
                uint256 availableCredit_ = _charger.availableCredit(account);
                _accountDeposits[account] = availableCredit_;
                totalAccountFees += accountDeposit - availableCredit_;  // overflow is impossible due to checks in FeeBankCharger
            }
        }
        _token.safeTransfer(msg.sender, totalAccountFees);
    }

    function _depositFor(address account, uint256 amount) internal returns (uint256 totalAvailableCredit) {
        if (account == address(0)) revert ZeroAddress();
        _token.safeTransferFrom(msg.sender, address(this), amount);
        unchecked {
            _accountDeposits[account] += amount;  // overflow is impossible due to limited _token supply
        }
        totalAvailableCredit = _charger.increaseAvailableCredit(account, amount);
    }

    function _withdrawTo(address account, uint256 amount) internal returns (uint256 totalAvailableCredit) {
        totalAvailableCredit = _charger.decreaseAvailableCredit(msg.sender, amount);
        unchecked {
            _accountDeposits[msg.sender] -= amount;  // underflow is impossible due to checks in FeeBankCharger
        }
        _token.safeTransfer(account, amount);
    }
}

type TakerTraits is uint256;

/**
 * @title TakerTraitsLib
 * @notice This library to manage and check TakerTraits, which are used to encode the taker's preferences for an order in a single uint256.
 * @dev The TakerTraits are structured as follows:
 * High bits are used for flags
 * 255 bit `_MAKER_AMOUNT_FLAG`         - If set, the taking amount is calculated based on making amount, otherwise making amount is calculated based on taking amount.
 * 254 bit `_UNWRAP_WETH_FLAG`          - If set, the WETH will be unwrapped into ETH before sending to taker.
 * 253 bit `_SKIP_ORDER_PERMIT_FLAG`    - If set, the order skips maker's permit execution.
 * 252 bit `_USE_PERMIT2_FLAG`          - If set, the order uses the permit2 function for authorization.
 * The remaining bits are used to store the threshold amount (the maximum amount a taker agrees to give in exchange for a making amount).
 */
library TakerTraitsLib {
    uint256 private constant _MAKER_AMOUNT_FLAG = 1 << 255;
    uint256 private constant _UNWRAP_WETH_FLAG = 1 << 254;
    uint256 private constant _SKIP_ORDER_PERMIT_FLAG = 1 << 253;
    uint256 private constant _USE_PERMIT2_FLAG = 1 << 252;
    uint256 private constant _ARGS_HAS_TARGET = 1 << 251;

    uint256 private constant _ARGS_EXTENSION_LENGTH_OFFSET = 224;
    uint256 private constant _ARGS_EXTENSION_LENGTH_MASK = 0xffffff;
    uint256 private constant _ARGS_INTERACTION_LENGTH_OFFSET = 200;
    uint256 private constant _ARGS_INTERACTION_LENGTH_MASK = 0xffffff;

    uint256 private constant _AMOUNT_MASK = 0x000000000000000000ffffffffffffffffffffffffffffffffffffffffffffff;

    function argsHasTarget(TakerTraits takerTraits) internal pure returns (bool) {
        return (TakerTraits.unwrap(takerTraits) & _ARGS_HAS_TARGET) != 0;
    }

    function argsExtensionLength(TakerTraits takerTraits) internal pure returns (uint256) {
        return (TakerTraits.unwrap(takerTraits) >> _ARGS_EXTENSION_LENGTH_OFFSET) & _ARGS_EXTENSION_LENGTH_MASK;
    }

    function argsInteractionLength(TakerTraits takerTraits) internal pure returns (uint256) {
        return (TakerTraits.unwrap(takerTraits) >> _ARGS_INTERACTION_LENGTH_OFFSET) & _ARGS_INTERACTION_LENGTH_MASK;
    }

    /**
     * @notice Checks if the taking amount should be calculated based on making amount.
     * @param takerTraits The traits of the taker.
     * @return result A boolean indicating whether the taking amount should be calculated based on making amount.
     */
    function isMakingAmount(TakerTraits takerTraits) internal pure returns (bool) {
        return (TakerTraits.unwrap(takerTraits) & _MAKER_AMOUNT_FLAG) != 0;
    }

    /**
     * @notice Checks if the order should unwrap WETH and send ETH to taker.
     * @param takerTraits The traits of the taker.
     * @return result A boolean indicating whether the order should unwrap WETH.
     */
    function unwrapWeth(TakerTraits takerTraits) internal pure returns (bool) {
        return (TakerTraits.unwrap(takerTraits) & _UNWRAP_WETH_FLAG) != 0;
    }

    /**
     * @notice Checks if the order should skip maker's permit execution.
     * @param takerTraits The traits of the taker.
     * @return result A boolean indicating whether the order don't apply permit.
     */
    function skipMakerPermit(TakerTraits takerTraits) internal pure returns (bool) {
        return (TakerTraits.unwrap(takerTraits) & _SKIP_ORDER_PERMIT_FLAG) != 0;
    }

    /**
     * @notice Checks if the order uses the permit2 instead of permit.
     * @param takerTraits The traits of the taker.
     * @return result A boolean indicating whether the order uses the permit2.
     */
    function usePermit2(TakerTraits takerTraits) internal pure returns (bool) {
        return (TakerTraits.unwrap(takerTraits) & _USE_PERMIT2_FLAG) != 0;
    }

    /**
     * @notice Retrieves the threshold amount from the takerTraits.
     * The maximum amount a taker agrees to give in exchange for a making amount.
     * @param takerTraits The traits of the taker.
     * @return result The threshold amount encoded in the takerTraits.
     */
    function threshold(TakerTraits takerTraits) internal pure returns (uint256) {
        return TakerTraits.unwrap(takerTraits) & _AMOUNT_MASK;
    }
}

type MakerTraits is uint256;

/**
 * @title MakerTraitsLib
 * @notice A library to manage and check MakerTraits, which are used to encode the maker's preferences for an order in a single uint256.
 * @dev
 * The MakerTraits type is a uint256 and different parts of the number are used to encode different traits.
 * High bits are used for flags
 * 255 bit `NO_PARTIAL_FILLS_FLAG`          - if set, the order does not allow partial fills
 * 254 bit `ALLOW_MULTIPLE_FILLS_FLAG`      - if set, the order permits multiple fills
 * 252 bit `PRE_INTERACTION_CALL_FLAG`      - if set, the order requires pre-interaction call
 * 251 bit `POST_INTERACTION_CALL_FLAG`     - if set, the order requires post-interaction call
 * 250 bit `NEED_CHECK_EPOCH_MANAGER_FLAG`  - if set, the order requires to check the epoch manager
 * 249 bit `HAS_EXTENSION_FLAG`             - if set, the order has extension(s)
 * 248 bit `USE_PERMIT2_FLAG`               - if set, the order uses permit2
 * 247 bit `UNWRAP_WETH_FLAG`               - if set, the order requires to unwrap WETH

 * Low 200 bits are used for allowed sender, expiration, nonceOrEpoch, and series
 * uint80 last 10 bytes of allowed sender address (0 if any)
 * uint40 expiration timestamp (0 if none)
 * uint40 nonce or epoch
 * uint40 series
 */
library MakerTraitsLib {
    // Low 200 bits are used for allowed sender, expiration, nonceOrEpoch, and series
    uint256 private constant _ALLOWED_SENDER_MASK = type(uint80).max;
    uint256 private constant _EXPIRATION_OFFSET = 80;
    uint256 private constant _EXPIRATION_MASK = type(uint40).max;
    uint256 private constant _NONCE_OR_EPOCH_OFFSET = 120;
    uint256 private constant _NONCE_OR_EPOCH_MASK = type(uint40).max;
    uint256 private constant _SERIES_OFFSET = 160;
    uint256 private constant _SERIES_MASK = type(uint40).max;

    uint256 private constant _NO_PARTIAL_FILLS_FLAG = 1 << 255;
    uint256 private constant _ALLOW_MULTIPLE_FILLS_FLAG = 1 << 254;
    uint256 private constant _PRE_INTERACTION_CALL_FLAG = 1 << 252;
    uint256 private constant _POST_INTERACTION_CALL_FLAG = 1 << 251;
    uint256 private constant _NEED_CHECK_EPOCH_MANAGER_FLAG = 1 << 250;
    uint256 private constant _HAS_EXTENSION_FLAG = 1 << 249;
    uint256 private constant _USE_PERMIT2_FLAG = 1 << 248;
    uint256 private constant _UNWRAP_WETH_FLAG = 1 << 247;

    /**
     * @notice Checks if the order has the extension flag set.
     * @dev If the `HAS_EXTENSION_FLAG` is set in the makerTraits, then the protocol expects that the order has extension(s).
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the flag is set.
     */
    function hasExtension(MakerTraits makerTraits) internal pure returns (bool) {
        return (MakerTraits.unwrap(makerTraits) & _HAS_EXTENSION_FLAG) != 0;
    }

    /**
     * @notice Checks if the maker allows a specific taker to fill the order.
     * @param makerTraits The traits of the maker.
     * @param sender The address of the taker to be checked.
     * @return result A boolean indicating whether the taker is allowed.
     */
    function isAllowedSender(MakerTraits makerTraits, address sender) internal pure returns (bool) {
        uint160 allowedSender = uint160(MakerTraits.unwrap(makerTraits) & _ALLOWED_SENDER_MASK);
        return allowedSender == 0 || allowedSender == uint160(sender) & _ALLOWED_SENDER_MASK;
    }

    /**
     * @notice Checks if the order has expired.
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the order has expired.
     */
    function isExpired(MakerTraits makerTraits) internal view returns (bool) {
        uint256 expiration = (MakerTraits.unwrap(makerTraits) >> _EXPIRATION_OFFSET) & _EXPIRATION_MASK;
        return expiration != 0 && expiration < block.timestamp;  // solhint-disable-line not-rely-on-time
    }

    /**
     * @notice Returns the nonce or epoch of the order.
     * @param makerTraits The traits of the maker.
     * @return result The nonce or epoch of the order.
     */
    function nonceOrEpoch(MakerTraits makerTraits) internal pure returns (uint256) {
        return (MakerTraits.unwrap(makerTraits) >> _NONCE_OR_EPOCH_OFFSET) & _NONCE_OR_EPOCH_MASK;
    }

    /**
     * @notice Returns the series of the order.
     * @param makerTraits The traits of the maker.
     * @return result The series of the order.
     */
    function series(MakerTraits makerTraits) internal pure returns (uint256) {
        return (MakerTraits.unwrap(makerTraits) >> _SERIES_OFFSET) & _SERIES_MASK;
    }

    /**
      * @notice Determines if the order allows partial fills.
      * @dev If the _NO_PARTIAL_FILLS_FLAG is not set in the makerTraits, then the order allows partial fills.
      * @param makerTraits The traits of the maker, determining their preferences for the order.
      * @return result A boolean indicating whether the maker allows partial fills.
      */
    function allowPartialFills(MakerTraits makerTraits) internal pure returns (bool) {
        return (MakerTraits.unwrap(makerTraits) & _NO_PARTIAL_FILLS_FLAG) == 0;
    }

    /**
     * @notice Checks if the maker needs pre-interaction call.
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the maker needs a pre-interaction call.
     */
    function needPreInteractionCall(MakerTraits makerTraits) internal pure returns (bool) {
        return (MakerTraits.unwrap(makerTraits) & _PRE_INTERACTION_CALL_FLAG) != 0;
    }

    /**
     * @notice Checks if the maker needs post-interaction call.
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the maker needs a post-interaction call.
     */
    function needPostInteractionCall(MakerTraits makerTraits) internal pure returns (bool) {
        return (MakerTraits.unwrap(makerTraits) & _POST_INTERACTION_CALL_FLAG) != 0;
    }

    /**
      * @notice Determines if the order allows multiple fills.
      * @dev If the _ALLOW_MULTIPLE_FILLS_FLAG is set in the makerTraits, then the maker allows multiple fills.
      * @param makerTraits The traits of the maker, determining their preferences for the order.
      * @return result A boolean indicating whether the maker allows multiple fills.
      */
    function allowMultipleFills(MakerTraits makerTraits) internal pure returns (bool) {
        return (MakerTraits.unwrap(makerTraits) & _ALLOW_MULTIPLE_FILLS_FLAG) != 0;
    }

    /**
      * @notice Determines if an order should use the bit invalidator or remaining amount validator.
      * @dev The bit invalidator can be used if the order does not allow partial or multiple fills.
      * @param makerTraits The traits of the maker, determining their preferences for the order.
      * @return result A boolean indicating whether the bit invalidator should be used.
      * True if the order requires the use of the bit invalidator.
      */
    function useBitInvalidator(MakerTraits makerTraits) internal pure returns (bool) {
        return !allowPartialFills(makerTraits) || !allowMultipleFills(makerTraits);
    }

    /**
     * @notice Checks if the maker needs to check the epoch.
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the maker needs to check the epoch manager.
     */
    function needCheckEpochManager(MakerTraits makerTraits) internal pure returns (bool) {
        return (MakerTraits.unwrap(makerTraits) & _NEED_CHECK_EPOCH_MANAGER_FLAG) != 0;
    }

    /**
     * @notice Checks if the maker uses permit2.
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the maker uses permit2.
     */
    function usePermit2(MakerTraits makerTraits) internal pure returns (bool) {
        return MakerTraits.unwrap(makerTraits) & _USE_PERMIT2_FLAG != 0;
    }

    /**
     * @notice Checks if the maker needs to unwraps WETH.
     * @param makerTraits The traits of the maker.
     * @return result A boolean indicating whether the maker needs to unwrap WETH.
     */
    function unwrapWeth(MakerTraits makerTraits) internal pure returns (bool) {
        return MakerTraits.unwrap(makerTraits) & _UNWRAP_WETH_FLAG != 0;
    }
}

import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
////import "../libraries/MakerTraitsLib.sol";
////import "../libraries/TakerTraitsLib.sol";

interface IOrderMixin {
    struct Order {
        uint256 salt;
        Address maker;
        Address receiver;
        Address makerAsset;
        Address takerAsset;
        uint256 makingAmount;
        uint256 takingAmount;
        MakerTraits makerTraits;
    }

    error InvalidatedOrder();
    error TakingAmountExceeded();
    error PrivateOrder();
    error BadSignature();
    error OrderExpired();
    error WrongSeriesNonce();
    error SwapWithZeroAmount();
    error PartialFillNotAllowed();
    error OrderIsNotSuitableForMassInvalidation();
    error EpochManagerAndBitInvalidatorsAreIncompatible();
    error ReentrancyDetected();
    error PredicateIsNotTrue();
    error TakingAmountTooHigh();
    error MakingAmountTooLow();
    error TransferFromMakerToTakerFailed();
    error TransferFromTakerToMakerFailed();
    error MismatchArraysLengths();
    error InvalidPermit2Transfer();
    error SimulationResults(bool success, bytes res);

    /**
     * @notice Emitted when order gets filled
     * @param orderHash Hash of the order
     * @param remainingAmount Amount of the maker asset that remains to be filled
     */
    event OrderFilled(
        bytes32 orderHash,
        uint256 remainingAmount
    );

    /**
     * @notice Emitted when order gets filled
     * @param orderHash Hash of the order
     */
    event OrderCancelled(
        bytes32 orderHash
    );

    /**
     * @notice Returns bitmask for double-spend invalidators based on lowest byte of order.info and filled quotes
     * @param maker Maker address
     * @param slot Slot number to return bitmask for
     * @return result Each bit represents whether corresponding was already invalidated
     */
    function bitInvalidatorForOrder(address maker, uint256 slot) external view returns(uint256 result);

    /**
     * @notice Returns bitmask for double-spend invalidators based on lowest byte of order.info and filled quotes
     * @param orderHash Hash of the order
     * @return remaining Remaining amount of the order
     */
    function remainingInvalidatorForOrder(address maker, bytes32 orderHash) external view returns(uint256 remaining);

    /**
     * @notice Returns bitmask for double-spend invalidators based on lowest byte of order.info and filled quotes
     * @param orderHash Hash of the order
     * @return remainingRaw Remaining amount of the order plus 1 if order was partially filled, otherwise 0
     */
    function rawRemainingInvalidatorForOrder(address maker, bytes32 orderHash) external view returns(uint256 remainingRaw);

    /**
     * @notice Cancels order's quote
     * @param makerTraits Order makerTraits
     * @param orderHash Hash of the order to cancel
     */
    function cancelOrder(MakerTraits makerTraits, bytes32 orderHash) external;

    /**
     * @notice Cancels orders' quotes
     * @param makerTraits Orders makerTraits
     * @param orderHashes Hashes of the orders to cancel
     */
    function cancelOrders(MakerTraits[] calldata makerTraits, bytes32[] calldata orderHashes) external;

    /**
     * @notice Cancels all quotes of the maker (works for bit-invalidating orders only)
     * @param makerTraits Order makerTraits
     * @param additionalMask Additional bitmask to invalidate orders
     */
    function bitsInvalidateForOrder(MakerTraits makerTraits, uint256 additionalMask) external;

    /**
     * @notice Returns order hash, hashed with limit order protocol contract EIP712
     * @param order Order
     * @return orderHash Hash of the order
     */
    function hashOrder(IOrderMixin.Order calldata order) external view returns(bytes32 orderHash);

    /**
     * @notice Delegates execution to custom implementation. Could be used to validate if `transferFrom` works properly
     * @dev The function always reverts and returns the simulation results in revert data.
     * @param target Addresses that will be delegated
     * @param data Data that will be passed to delegatee
     */
    function simulate(address target, bytes calldata data) external;

    /**
     * @notice Fills order's quote, fully or partially (whichever is possible).
     * @param order Order quote to fill
     * @param r R component of signature
     * @param vs VS component of signature
     * @param amount Taker amount to fill
     * @param takerTraits Specifies threshold as maximum allowed takingAmount when takingAmount is zero, otherwise specifies
     * minimum allowed makingAmount. The 2nd (0 based index) highest bit specifies whether taker wants to skip maker's permit.
     * @return makingAmount Actual amount transferred from maker to taker
     * @return takingAmount Actual amount transferred from taker to maker
     * @return orderHash Hash of the filled order
     */
    function fillOrder(
        Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits
    ) external payable returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    /**
     * @notice Same as `fillOrder` but allows to specify arguments that are used by the taker.
     * @param order Order quote to fill
     * @param r R component of signature
     * @param vs VS component of signature
     * @param amount Taker amount to fill
     * @param takerTraits Specifies threshold as maximum allowed takingAmount when takingAmount is zero, otherwise specifies
     * minimum allowed makingAmount. The 2nd (0 based index) highest bit specifies whether taker wants to skip maker's permit.
     * @param args Arguments that are used by the taker (target, extension, interaction, permit)
     * @return makingAmount Actual amount transferred from maker to taker
     * @return takingAmount Actual amount transferred from taker to maker
     * @return orderHash Hash of the filled order
     */
    function fillOrderArgs(
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external payable returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    /**
     * @notice Same as `fillOrder` but uses contract-based signatures.
     * @param order Order quote to fill
     * @param signature Signature to confirm quote ownership
     * @param amount Taker amount to fill
     * @param takerTraits Specifies threshold as maximum allowed takingAmount when takingAmount is zero, otherwise specifies
     * minimum allowed makingAmount. The 2nd (0 based index) highest bit specifies whether taker wants to skip maker's permit.
     * @return makingAmount Actual amount transferred from maker to taker
     * @return takingAmount Actual amount transferred from taker to maker
     * @return orderHash Hash of the filled order
     * @dev See tests for examples
     */
    function fillContractOrder(
        Order calldata order,
        bytes calldata signature,
        uint256 amount,
        TakerTraits takerTraits
    ) external returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);

    /**
     * @notice Same as `fillContractOrder` but allows to specify arguments that are used by the taker.
     * @param order Order quote to fill
     * @param signature Signature to confirm quote ownership
     * @param amount Taker amount to fill
     * @param takerTraits Specifies threshold as maximum allowed takingAmount when takingAmount is zero, otherwise specifies
     * minimum allowed makingAmount. The 2nd (0 based index) highest bit specifies whether taker wants to skip maker's permit.
     * @param args Arguments that are used by the taker (target, extension, interaction, permit)
     * @return makingAmount Actual amount transferred from maker to taker
     * @return takingAmount Actual amount transferred from taker to maker
     * @return orderHash Hash of the filled order
     * @dev See tests for examples
     */
    function fillContractOrderArgs(
        Order calldata order,
        bytes calldata signature,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);
}

////import "./IOrderMixin.sol";

interface IAmountGetter {
    /**
     * @notice View method that gets called to determine the actual making amount
     * @param order Order being processed
     * @param extension Order extension data
     * @param orderHash Hash of the order being processed
     * @param taker Taker address
     * @param takingAmount Actual taking amount
     * @param remainingMakingAmount Order remaining making amount
     * @param extraData Extra data
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256);

    /**
     * @notice View method that gets called to determine the actual making amount
     * @param order Order being processed
     * @param extension Order extension data
     * @param orderHash Hash of the order being processed
     * @param taker Taker address
     * @param makingAmount Actual taking amount
     * @param remainingMakingAmount Order remaining making amount
     * @param extraData Extra data
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256);
}

////import "./IOrderMixin.sol";

interface IPreInteraction {
    /**
     * @notice Callback method that gets called before any funds transfers
     * @param order Order being processed
     * @param extension Order extension data
     * @param orderHash Hash of the order being processed
     * @param taker Taker address
     * @param makingAmount Actual making amount
     * @param takingAmount Actual taking amount
     * @param remainingMakingAmount Order remaining making amount
     * @param extraData Extra data
     */
    function preInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external;
}

////import "./IOrderMixin.sol";

interface IPostInteraction {
    /**
     * @notice Callback method that gets called after all fund transfers
     * @param order Order being processed
     * @param extension Order extension data
     * @param orderHash Hash of the order being processed
     * @param taker Taker address
     * @param makingAmount Actual making amount
     * @param takingAmount Actual taking amount
     * @param remainingMakingAmount Order remaining making amount
     * @param extraData Extra data
     */
    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external;
}


////import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
////import { IFeeBank } from "./interfaces/IFeeBank.sol";
////import { IFeeBankCharger } from "./interfaces/IFeeBankCharger.sol";
////import { FeeBank } from "./FeeBank.sol";

/**
 * @title FeeBankCharger
 * @notice FeeBankCharger contract implements logic to increase or decrease users' credits in FeeBank.
 */
contract FeeBankCharger is IFeeBankCharger {
    error OnlyFeeBankAccess();
    error NotEnoughCredit();

    /**
     * @notice See {IFeeBankCharger-feeBank}.
     */
    IFeeBank public immutable feeBank;
    mapping(address => uint256) private _creditAllowance;

    /**
     * @dev Modifier to check if the sender is a feeBank contract.
     */
    modifier onlyFeeBank() {
        if (msg.sender != address(feeBank)) revert OnlyFeeBankAccess();
        _;
    }

    constructor(IERC20 token) {
        feeBank = new FeeBank(this, token, msg.sender);
    }

    /**
     * @notice See {IFeeBankCharger-availableCredit}.
     */
    function availableCredit(address account) external view returns (uint256) {
        return _creditAllowance[account];
    }

    /**
     * @notice See {IFeeBankCharger-increaseAvailableCredit}.
     */
    function increaseAvailableCredit(address account, uint256 amount) external onlyFeeBank returns (uint256 allowance) {
        allowance = _creditAllowance[account];
        unchecked {
            allowance += amount;  // overflow is impossible due to limited _token supply
        }
        _creditAllowance[account] = allowance;
    }

    /**
     * @notice See {IFeeBankCharger-decreaseAvailableCredit}.
     */
    function decreaseAvailableCredit(address account, uint256 amount) external onlyFeeBank returns (uint256 allowance) {
        return _creditAllowance[account] -= amount;  // checked math is needed to prevent underflow
    }

    /**
     * @notice Internal function that charges a specified fee from a given account's credit allowance.
     * @dev Reverts with 'NotEnoughCredit' if the account's credit allowance is insufficient to cover the fee.
     * @param account The address of the account from which the fee is being charged.
     * @param fee The amount of fee to be charged from the account.
     */
    function _chargeFee(address account, uint256 fee) internal virtual {
        if (fee > 0) {
            uint256 currentAllowance = _creditAllowance[account];
            if (currentAllowance < fee) revert NotEnoughCredit();
            unchecked {
                _creditAllowance[account] = currentAllowance - fee;
            }
        }
    }
}

            
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
////import { IOrderMixin } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IOrderMixin.sol";
////import { IPostInteraction } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IPostInteraction.sol";
////import { IPreInteraction } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IPreInteraction.sol";
////import { IAmountGetter } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IAmountGetter.sol";

/**
 * @title Base Extension contract
 * @notice Contract to define the basic functionality for the limit orders settlement.
 */
contract BaseExtension is IPreInteraction, IPostInteraction, IAmountGetter {
    error OnlyLimitOrderProtocol();

    uint256 private constant _BASE_POINTS = 10_000_000; // 100%

    IOrderMixin private immutable _limitOrderProtocol;

    /// @dev Modifier to check if the caller is the limit order protocol contract.
    modifier onlyLimitOrderProtocol {
        if (msg.sender != address(_limitOrderProtocol)) revert OnlyLimitOrderProtocol();
        _;
    }

    /**
     * @notice Initializes the contract.
     * @param limitOrderProtocol The limit order protocol contract.
     */
    constructor(IOrderMixin limitOrderProtocol) {
        _limitOrderProtocol = limitOrderProtocol;
    }

    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 /* orderHash */,
        address /* taker */,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external view returns (uint256) {
        uint256 rateBump = _getRateBump(extraData);
        return Math.mulDiv(order.makingAmount, takingAmount * _BASE_POINTS, order.takingAmount * (_BASE_POINTS + rateBump));
    }

    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 /* orderHash */,
        address /* taker */,
        uint256 makingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external view returns (uint256) {
        uint256 rateBump = _getRateBump(extraData);
        return Math.mulDiv(order.takingAmount, makingAmount * (_BASE_POINTS + rateBump), order.makingAmount * _BASE_POINTS);
    }

    function preInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external onlyLimitOrderProtocol {
        _preInteraction(order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData);
    }

    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external onlyLimitOrderProtocol {
        _postInteraction(order, extension, orderHash, taker, makingAmount, takingAmount, remainingMakingAmount, extraData);
    }

    /**
     * @dev Parses rate bump data from the `auctionDetails` field. Auction is represented as a
     * piecewise linear function with `N` points. Each point is represented as a pair of
     * `(rateBump, timeDelta)`, where `rateBump` is the rate bump in basis points and `timeDelta`
     * is the time delta in seconds. The rate bump is interpolated linearly between the points.
     * The last point is assumed to be `(0, auctionDuration)`.
     * @param auctionDetails AuctionDetails is a tihgtly packed struct of the following format:
     * ```
     * struct AuctionDetails {
     *     bytes4 auctionStartTime;
     *     bytes3 auctionDuration;
     *     bytes3 initialRateBump;
     *     (bytes3,bytes2)[N] pointsAndTimeDeltas;
     * }
     * ```
     * @return rateBump The rate bump.
     */
    function _getRateBump(bytes calldata auctionDetails) private view returns (uint256) {
        unchecked {
            uint256 auctionStartTime = uint32(bytes4(auctionDetails[0:4]));
            uint256 auctionFinishTime = auctionStartTime + uint24(bytes3(auctionDetails[4:7]));
            uint256 initialRateBump = uint24(bytes3(auctionDetails[7:10]));

            if (block.timestamp <= auctionStartTime) {
                return initialRateBump;
            } else if (block.timestamp >= auctionFinishTime) {
                return 0; // Means 0% bump
            }

            auctionDetails = auctionDetails[10:];
            uint256 pointsSize = auctionDetails.length / 5;
            uint256 currentPointTime = auctionStartTime;
            uint256 currentRateBump = initialRateBump;

            for (uint256 i = 0; i < pointsSize; i++) {
                uint256 nextRateBump = uint24(bytes3(auctionDetails[:3]));
                uint256 nextPointTime = currentPointTime + uint16(bytes2(auctionDetails[3:5]));
                if (block.timestamp <= nextPointTime) {
                    return ((block.timestamp - currentPointTime) * nextRateBump + (nextPointTime - block.timestamp) * currentRateBump) / (nextPointTime - currentPointTime);
                }
                currentRateBump = nextRateBump;
                currentPointTime = nextPointTime;
                auctionDetails = auctionDetails[5:];
            }
            return (auctionFinishTime - block.timestamp) * currentRateBump / (auctionFinishTime - currentPointTime);
        }
    }

    function _preInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) internal virtual {}

    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) internal virtual {}
}

////import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
////import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
////import { IOrderMixin } from "@1inch/limit-order-protocol-contract/contracts/interfaces/IOrderMixin.sol";
////import { SafeERC20 } from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";
////import { Address, AddressLib } from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
////import { BaseExtension } from "./BaseExtension.sol";
////import { FeeBankCharger } from "./FeeBankCharger.sol";

/**
 * @title Basic Settlement contract
 * @notice Contract to execute limit orders settlement, created by Fusion mode.
 */
contract BasicSettlementExtension is BaseExtension, FeeBankCharger {
    using SafeERC20 for IERC20;
    using AddressLib for Address;

    error InvalidPriorityFee();
    error ResolverIsNotWhitelisted();

    uint256 private constant _TAKING_FEE_BASE = 1e9;
    uint256 private constant _ORDER_FEE_BASE_POINTS = 1e15;

    /**
     * @notice Initializes the contract.
     * @param limitOrderProtocol The limit order protocol contract.
     * @param token The token to charge protocol fees in.
     */
    constructor(IOrderMixin limitOrderProtocol, IERC20 token)
        BaseExtension(limitOrderProtocol)
        FeeBankCharger(token) {}

    /**
     * @dev Parses fee data from the extraData field.
     * @param extraData ExtraData is a tihgtly packed struct of the following format:
     * ```
     * struct ExtraData {
     *     bytes1 feeTypes; 1 = resolverFee, 2 = integrationFee
     *     bytes4 resolverFee; optional
     *     bytes20 integrator; optional
     *     bytes4 integrationFee; optional
     *     bytes whitelist;
     * }
     * ```
     * @param orderMakingAmount The order making amount.
     * @param actualMakingAmount The actual making amount.
     * @param actualTakingAmount The actual taking amount.
     * @return resolverFee The resolver fee.
     * @return integrator The integrator address.
     * @return integrationFee The integration fee.
     * @return dataReturned The data remaining after parsing.
     */
    function _parseFeeData(
        bytes calldata extraData,
        uint256 orderMakingAmount,
        uint256 actualMakingAmount,
        uint256 actualTakingAmount
    ) internal pure virtual returns (uint256 resolverFee, address integrator, uint256 integrationFee, bytes calldata dataReturned) {
        bytes1 feeType = extraData[0];
        extraData = extraData[1:];
        if (feeType & 0x01 == 0x01) {
            // resolverFee enabled
            resolverFee = uint256(uint32(bytes4(extraData[:4]))) * _ORDER_FEE_BASE_POINTS * actualMakingAmount / orderMakingAmount;
            extraData = extraData[4:];
        }
        if (feeType & 0x02 == 0x02) {
            // integratorFee enabled
            integrator = address(bytes20(extraData[:20]));
            integrationFee = actualTakingAmount * uint256(uint32(bytes4(extraData[20:24]))) / _TAKING_FEE_BASE;
            extraData = extraData[24:];
        }
        dataReturned = extraData;
    }

    /**
     * @dev Validates whether the resolver is whitelisted.
     * @param whitelist Whitelist is tighly packed struct of the following format:
     * ```
     * struct WhitelistDetails {
     *     bytes4 auctionStartTime;
     *     (bytes10,bytes2)[N] resolversAddressesAndTimeDeltas;
     * }
     * ```
     * @param resolver The resolver to check.
     * @return Whether the resolver is whitelisted.
     */
    function _isWhitelisted(bytes calldata whitelist, address resolver) internal view virtual returns (bool) {
        unchecked {
            uint256 allowedTime = uint32(bytes4(whitelist[0:4])); // initially set to auction start time
            whitelist = whitelist[4:];
            uint256 whitelistSize = whitelist.length / 12;
            uint80 maskedResolverAddress = uint80(uint160(resolver));
            for (uint256 i = 0; i < whitelistSize; i++) {
                uint80 whitelistedAddress = uint80(bytes10(whitelist[:10]));
                allowedTime += uint16(bytes2(whitelist[10:12])); // add next time delta
                if (maskedResolverAddress == whitelistedAddress) {
                    return allowedTime <= block.timestamp;
                } else if (allowedTime > block.timestamp) {
                    return false;
                }
                whitelist = whitelist[12:];
            }
            return false;
        }
    }

    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 /* orderHash */,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) internal virtual override {
        (uint256 resolverFee, address integrator, uint256 integrationFee, bytes calldata dataReturned) = _parseFeeData(extraData, order.makingAmount, makingAmount, takingAmount);

        if (!_isWhitelisted(dataReturned, taker)) revert ResolverIsNotWhitelisted();

        _chargeFee(taker, resolverFee);
        if (integrationFee > 0) {
            IERC20(order.takerAsset.get()).safeTransferFrom(taker, integrator, integrationFee);
        }
    }
}

