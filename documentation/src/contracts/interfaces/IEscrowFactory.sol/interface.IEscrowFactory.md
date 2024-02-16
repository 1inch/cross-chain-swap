# IEscrowFactory
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/interfaces/IEscrowFactory.sol)


## Functions
### createDstEscrow

Creates a new escrow contract for taker on the destination chain.

*The caller must send the safety deposit in the native token along with the function call
and approve the destination token to be transferred to the created escrow.*


```solidity
function createDstEscrow(EscrowImmutablesCreation calldata dstImmutables) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstImmutables`|`EscrowImmutablesCreation`|The immutables of the escrow contract that are used in deployment.|


### addressOfEscrowSrc

Returns the deterministic address of the source escrow based on the salt.


```solidity
function addressOfEscrowSrc(bytes memory data) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The immutable arguments used to deploy escrow.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The computed address of the escrow.|


### addressOfEscrowDst

Returns the deterministic address of the destination escrow based on the salt.


```solidity
function addressOfEscrowDst(bytes memory data) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The immutable arguments used to deploy escrow.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The computed address of the escrow.|


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
### EscrowImmutablesCreation
token, amount and safetyDeposit are related to the destination chain.


```solidity
struct EscrowImmutablesCreation {
    IEscrowDst.EscrowImmutables args;
    uint256 srcCancellationTimestamp;
}
```

