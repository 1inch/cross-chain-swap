# ImmutablesLib
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/libraries/ImmutablesLib.sol)


## State Variables
### ESCROW_IMMUTABLES_SIZE

```solidity
uint256 internal constant ESCROW_IMMUTABLES_SIZE = 0x100;
```


## Functions
### hash


```solidity
function hash(IEscrow.Immutables calldata immutables) internal pure returns (bytes32 ret);
```

### hashMem


```solidity
function hashMem(IEscrow.Immutables memory immutables) internal pure returns (bytes32 ret);
```

