# IEscrowFactory
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/interfaces/IEscrowFactory.sol)

Interface to deploy escrow contracts for the destination chain and to get the deterministic address of escrow on both chains.


## Functions
### createDstEscrow

Creates a new escrow contract for taker on the destination chain.

*The caller must send the safety deposit in the native token along with the function call
and approve the destination token to be transferred to the created escrow.*


```solidity
function createDstEscrow(IEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstImmutables`|`IEscrow.Immutables`|The immutables of the escrow contract that are used in deployment.|
|`srcCancellationTimestamp`|`uint256`|The start of the cancellation period for the source chain.|


### addressOfEscrowSrc

Returns the deterministic address of the source escrow based on the salt.


```solidity
function addressOfEscrowSrc(IEscrow.Immutables calldata immutables) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`immutables`|`IEscrow.Immutables`|The immutable arguments used to compute salt for escrow deployment.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The computed address of the escrow.|


### addressOfEscrowDst

Returns the deterministic address of the destination escrow based on the salt.


```solidity
function addressOfEscrowDst(IEscrow.Immutables calldata immutables) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`immutables`|`IEscrow.Immutables`|The immutable arguments used to compute salt for escrow deployment.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The computed address of the escrow.|


## Events
### CrosschainSwap

```solidity
event CrosschainSwap(IEscrow.Immutables srcImmutables, DstImmutablesComplement dstImmutablesComplement);
```

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
### ExtraDataImmutables

```solidity
struct ExtraDataImmutables {
    bytes32 hashlock;
    uint256 dstChainId;
    Address dstToken;
    uint256 deposits;
    Timelocks timelocks;
}
```

### DstImmutablesComplement

```solidity
struct DstImmutablesComplement {
    uint256 amount;
    Address token;
    uint256 safetyDeposit;
    uint256 chainId;
}
```

