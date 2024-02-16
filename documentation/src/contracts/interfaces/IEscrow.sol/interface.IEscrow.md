# IEscrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/interfaces/IEscrow.sol)

Interface implies locking funds initially and then unlocking them with verification of the secret presented.


## Functions
### withdraw

Withdraws funds to a predetermined recipient.

*Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
The safety deposit is sent to the caller.*


```solidity
function withdraw(bytes32 secret) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|The secret that unlocks the escrow.|


### cancel

Cancels the escrow and returns tokens to a predetermined recipient.

*The escrow can only be cancelled during the cancellation period.
The safety deposit is sent to the caller.*


```solidity
function cancel() external;
```

### rescueFunds

Rescues funds from the escrow.

*Funds can only be rescued by the taker after the rescue delay.*


```solidity
function rescueFunds(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token to rescue. Zero address for native token.|
|`amount`|`uint256`|The amount of tokens to rescue.|


## Errors
### InvalidCaller

```solidity
error InvalidCaller();
```

### InvalidCancellationTime

```solidity
error InvalidCancellationTime();
```

### InvalidRescueTime

```solidity
error InvalidRescueTime();
```

### InvalidSecret

```solidity
error InvalidSecret();
```

### InvalidWithdrawalTime

```solidity
error InvalidWithdrawalTime();
```

### NativeTokenSendingFailure

```solidity
error NativeTokenSendingFailure();
```

### InvalidRescueDelay

```solidity
error InvalidRescueDelay();
```

