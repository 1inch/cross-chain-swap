# IEscrowFactory
[Git Source](https://github.com/byshape/cross-chain-swap/blob/e26c23ac0516aa14fa1ee0839087565b952fb4f1/contracts/interfaces/IEscrowFactory.sol)


## Functions
### createEscrow

Creates a new escrow contract for taker on the destination chain.

*The caller must send the safety deposit in the native token along with the function call
and approve the destination token to be transferred to the created escrow.*


```solidity
function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstEscrowImmutables`|`DstEscrowImmutablesCreation`|The immutables of the escrow contract that are used in deployment.|


### addressOfEscrow

Returns the deterministic address of the escrow based on the salt.


```solidity
function addressOfEscrow(bytes32 salt) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|The salt used to deploy escrow.|

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
### DstEscrowImmutablesCreation
token, amount and safetyDeposit are related to the destination chain.


```solidity
struct DstEscrowImmutablesCreation {
    bytes32 hashlock;
    address maker;
    address taker;
    address token;
    uint256 amount;
    uint256 safetyDeposit;
    IEscrow.DstTimelocks timelocks;
    uint256 srcCancellationTimestamp;
}
```

