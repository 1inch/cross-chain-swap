# IEscrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/interfaces/IEscrow.sol)

Interface implies locking funds initially and then unlocking them with verification of the secret presented.


## Functions
### RESCUE_DELAY


```solidity
function RESCUE_DELAY() external view returns (uint256);
```

### FACTORY


```solidity
function FACTORY() external view returns (address);
```

### PROXY_BYTECODE_HASH


```solidity
function PROXY_BYTECODE_HASH() external view returns (bytes32);
```

### withdraw

Withdraws funds to a predetermined recipient.

*Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
The safety deposit is sent to the caller.*


```solidity
function withdraw(bytes32 secret, IEscrow.Immutables calldata immutables) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|The secret that unlocks the escrow.|
|`immutables`|`IEscrow.Immutables`||


### cancel

Cancels the escrow and returns tokens to a predetermined recipient.

*The escrow can only be cancelled during the cancellation period.
The safety deposit is sent to the caller.*


```solidity
function cancel(IEscrow.Immutables calldata immutables) external;
```

### rescueFunds

Rescues funds from the escrow.

*Funds can only be rescued by the taker after the rescue delay.*


```solidity
function rescueFunds(address token, uint256 amount, IEscrow.Immutables calldata immutables) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token to rescue. Zero address for native token.|
|`amount`|`uint256`|The amount of tokens to rescue.|
|`immutables`|`IEscrow.Immutables`||


## Errors
### InvalidCaller

```solidity
error InvalidCaller();
```

### InvalidCancellationTime

```solidity
error InvalidCancellationTime();
```

### InvalidImmutables

```solidity
error InvalidImmutables();
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

## Structs
### Immutables

```solidity
struct Immutables {
    bytes32 orderHash;
    bytes32 hashlock;
    Address maker;
    Address taker;
    Address token;
    uint256 amount;
    uint256 safetyDeposit;
    Timelocks timelocks;
}
```

