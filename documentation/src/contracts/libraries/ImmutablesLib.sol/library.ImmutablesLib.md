# ImmutablesLib
[Git Source](https://github.com/1inch/cross-chain-swap/blob/dc0ae325b453eb92201e3de6c74cc1cd6558cced/contracts/libraries/ImmutablesLib.sol)


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

