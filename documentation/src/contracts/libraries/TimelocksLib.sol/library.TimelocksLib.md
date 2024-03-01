# TimelocksLib
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/libraries/TimelocksLib.sol)


## State Variables
### _TIMELOCK_MASK

```solidity
uint256 internal constant _TIMELOCK_MASK = type(uint32).max;
```


### _SRC_FINALITY_OFFSET

```solidity
uint256 internal constant _SRC_FINALITY_OFFSET = 224;
```


### _SRC_WITHDRAWAL_OFFSET

```solidity
uint256 internal constant _SRC_WITHDRAWAL_OFFSET = 192;
```


### _SRC_CANCELLATION_OFFSET

```solidity
uint256 internal constant _SRC_CANCELLATION_OFFSET = 160;
```


### _DST_FINALITY_OFFSET

```solidity
uint256 internal constant _DST_FINALITY_OFFSET = 128;
```


### _DST_WITHDRAWAL_OFFSET

```solidity
uint256 internal constant _DST_WITHDRAWAL_OFFSET = 96;
```


### _DST_PUB_WITHDRAWAL_OFFSET

```solidity
uint256 internal constant _DST_PUB_WITHDRAWAL_OFFSET = 64;
```


## Functions
### setDeployedAt

Sets the Escrow deployment timestamp.


```solidity
function setDeployedAt(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the deployment timestamp to.|
|`value`|`uint256`|The new Escrow deployment timestamp.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the deployment timestamp set.|


### rescueStart

Returns the start of the rescue period.


```solidity
function rescueStart(Timelocks timelocks, uint256 rescueDelay) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the rescue delay from.|
|`rescueDelay`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the rescue period.|


### srcWithdrawalStart

Returns the start of the private withdrawal period on the source chain.


```solidity
function srcWithdrawalStart(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the finality duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private withdrawal period.|


### srcCancellationStart

Returns the start of the private cancellation period on the source chain.


```solidity
function srcCancellationStart(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private withdrawal duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private cancellation period.|


### srcPubCancellationStart

Returns the start of the public cancellation period on the source chain.


```solidity
function srcPubCancellationStart(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private cancellation duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the public cancellation period.|


### dstWithdrawalStart

Returns the start of the private withdrawal period on the destination chain.


```solidity
function dstWithdrawalStart(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the finality duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private withdrawal period.|


### dstPubWithdrawalStart

Returns the start of the public withdrawal period on the destination chain.


```solidity
function dstPubWithdrawalStart(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private withdrawal duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the public withdrawal period.|


### dstCancellationStart

Returns the start of the private cancellation period on the destination chain.


```solidity
function dstCancellationStart(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the public withdrawal duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private cancellation period.|


### _get


```solidity
function _get(Timelocks timelocks, uint256 offset) private pure returns (uint256);
```

