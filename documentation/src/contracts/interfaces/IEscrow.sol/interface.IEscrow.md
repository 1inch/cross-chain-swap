# IEscrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/f45e33f855d5dd79428a1ba540d9f8df14bbb794/contracts/interfaces/IEscrow.sol)


## Functions
### withdrawSrc

Withdraws funds to the taker on the source chain.

*Withdrawal can only be made during the public unlock period and with secret
with hash matches the hashlock.
The safety deposit is sent to the caller.*


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

*Withdrawal can only be made by taker during the private unlock period or by anyone
during the public unlock period. In both cases, a secret with hash matching the hashlock must be provided.
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

*The escrow can only be cancelled during the cancel period.
The safety deposit is sent to the caller.*


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
### SrcTimelocks
Timelocks for the source chain.
finality: The duration of the chain finality period.
publicUnlock: The duration of the period when anyone with a secret can withdraw tokens for the taker.
cancel: The duration of the period when escrow can only be cancelled by the taker.


```solidity
struct SrcTimelocks {
    uint256 finality;
    uint256 publicUnlock;
    uint256 cancel;
}
```

### DstTimelocks
Timelocks for the destination chain.
finality: The duration of the chain finality period.
unlock: The duration of the period when only the taker with a secret can withdraw tokens for the maker.
publicUnlock publicUnlock: The duration of the period when anyone with a secret can withdraw tokens for the maker.


```solidity
struct DstTimelocks {
    uint256 finality;
    uint256 unlock;
    uint256 publicUnlock;
}
```

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
    uint256 srcSafetyDeposit;
    uint256 dstSafetyDeposit;
    SrcTimelocks srcTimelocks;
    DstTimelocks dstTimelocks;
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
    bytes32 hashlock;
    address maker;
    address taker;
    uint256 chainId;
    address token;
    uint256 amount;
    uint256 safetyDeposit;
    DstTimelocks timelocks;
}
```

