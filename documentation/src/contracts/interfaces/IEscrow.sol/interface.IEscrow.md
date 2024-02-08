# IEscrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/4a7a924cfc3cdc40ce87e400e418d193236c06fb/contracts/interfaces/IEscrow.sol)


## Functions
### withdrawSrc

Withdraws funds to the taker on the source chain.

*Withdrawal can only be made by the taker during the withdrawal period and with secret
with hash matches the hashlock.
The safety deposit is sent to the caller (taker).*


```solidity
function withdrawSrc(bytes32 secret) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|The secret that unlocks the escrow.|


### cancelSrc

Cancels the escrow on the source chain and returns tokens to the maker.

*The escrow can only be cancelled by taker during the private cancel period or
by anyone during the public cancel period.
The safety deposit is sent to the caller.*


```solidity
function cancelSrc() external;
```

### withdrawDst

Withdraws funds to the maker on the destination chain.

*Withdrawal can only be made by taker during the private withdrawal period or by anyone
during the public withdrawal period. In both cases, a secret with hash matching the hashlock must be provided.
The safety deposit is sent to the caller.*


```solidity
function withdrawDst(bytes32 secret) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|The secret that unlocks the escrow.|


### cancelDst

Cancels the escrow on the destination chain and returns tokens to the taker.

*The escrow can only be cancelled by the taker during the cancel period.
The safety deposit is sent to the caller (taker).*


```solidity
function cancelDst() external;
```

### srcEscrowImmutables

Returns the immutable parameters of the escrow contract on the source chain.

*The immutables are stored at the end of the proxy clone contract bytecode and
are added to the calldata each time the proxy clone function is called.*


```solidity
function srcEscrowImmutables() external pure returns (SrcEscrowImmutables calldata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`SrcEscrowImmutables`|The immutables of the escrow contract.|


### dstEscrowImmutables

Returns the immutable parameters of the escrow contract on the destination chain.

*The immutables are stored at the end of the proxy clone contract bytecode and
are added to the calldata each time the proxy clone function is called.*


```solidity
function dstEscrowImmutables() external pure returns (DstEscrowImmutables calldata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`DstEscrowImmutables`|The immutables of the escrow contract.|


## Errors
### InvalidCaller

```solidity
error InvalidCaller();
```

### InvalidCancellationTime

```solidity
error InvalidCancellationTime();
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
### InteractionParams

```solidity
struct InteractionParams {
    address maker;
    address taker;
    uint256 srcChainId;
    address srcToken;
    uint256 srcAmount;
    uint256 dstAmount;
}
```

### ExtraDataParams

```solidity
struct ExtraDataParams {
    bytes32 hashlock;
    uint256 dstChainId;
    address dstToken;
    uint256 deposits;
    Timelocks timelocks;
}
```

### SrcEscrowImmutables

```solidity
struct SrcEscrowImmutables {
    uint256 deployedAt;
    InteractionParams interactionParams;
    ExtraDataParams extraDataParams;
}
```

### DstEscrowImmutables
Data for the destination chain order immutables.
chainId, token, amount and safetyDeposit relate to the destination chain.


```solidity
struct DstEscrowImmutables {
    uint256 deployedAt;
    uint256 chainId;
    bytes32 hashlock;
    address maker;
    address taker;
    address token;
    uint256 amount;
    uint256 safetyDeposit;
    Timelocks timelocks;
}
```

