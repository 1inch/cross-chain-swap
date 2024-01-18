# IEscrowFactory
[Git Source](https://github.com/byshape/cross-chain-swap/blob/c49176f8473d9a06db920990a07a4d8464dd4dd4/contracts/interfaces/IEscrowFactory.sol)


## Errors
### InsufficientEscrowBalance

```solidity
error InsufficientEscrowBalance();
```

### InvalidCreationTime

```solidity
error InvalidCreationTime();
```

## Structs
### DstEscrowImmutablesCreation

```solidity
struct DstEscrowImmutablesCreation {
    uint256 hashlock;
    address maker;
    address taker;
    address token;
    uint256 amount;
    uint256 safetyDeposit;
    IEscrow.DstTimelocks timelocks;
    uint256 srcCancellationTimestamp;
}
```

