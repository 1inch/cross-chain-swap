# IEscrow
[Git Source](https://github.com/byshape/cross-chain-swap/blob/c49176f8473d9a06db920990a07a4d8464dd4dd4/contracts/interfaces/IEscrow.sol)


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

## Structs
### SrcTimelocks

```solidity
struct SrcTimelocks {
    uint256 finality;
    uint256 publicUnlock;
}
```

### DstTimelocks

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
    uint256 hashlock;
    uint256 dstChainId;
    address dstToken;
    uint256 safetyDeposit;
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

```solidity
struct DstEscrowImmutables {
    uint256 deployedAt;
    uint256 hashlock;
    address maker;
    address taker;
    uint256 chainId;
    address token;
    uint256 amount;
    uint256 safetyDeposit;
    DstTimelocks timelocks;
}
```

