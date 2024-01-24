# TimelocksLib
[Git Source](https://github.com/1inch/cross-chain-swap/blob/a0032266a4f4e0c7ae999b45292f7c9116abe373/contracts/libraries/TimelocksLib.sol)


## State Variables
### _TIMESTAMP_MASK

```solidity
uint256 private constant _TIMESTAMP_MASK = (1 << 40) - 1;
```


### _SRC_FINALITY_OFFSET

```solidity
uint256 private constant _SRC_FINALITY_OFFSET = 216;
```


### _SRC_WITHDRAWAL_OFFSET

```solidity
uint256 private constant _SRC_WITHDRAWAL_OFFSET = 176;
```


### _SRC_CANCEL_OFFSET

```solidity
uint256 private constant _SRC_CANCEL_OFFSET = 136;
```


### _DST_FINALITY_OFFSET

```solidity
uint256 private constant _DST_FINALITY_OFFSET = 96;
```


### _DST_WITHDRAWAL_OFFSET

```solidity
uint256 private constant _DST_WITHDRAWAL_OFFSET = 56;
```


### _DST_PUB_WITHDRAWAL_OFFSET

```solidity
uint256 private constant _DST_PUB_WITHDRAWAL_OFFSET = 16;
```


## Functions
### getSrcFinalityDuration

Gets the duration of the finality period on the source chain.


```solidity
function getSrcFinalityDuration(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the finality duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The duration of the finality period.|


### setSrcFinalityDuration

Sets the duration of the finality period on the source chain.


```solidity
function setSrcFinalityDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the finality duration to.|
|`value`|`uint256`|The new duration of the finality period.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the finality duration set.|


### getSrcWithdrawalStart

Gets the start of the private withdrawal period on the source chain.


```solidity
function getSrcWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the finality duration from.|
|`startTimestamp`|`uint256`|The timestamp when the counting starts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private withdrawal period.|


### getSrcWithdrawalDuration

Gets the duration of the private withdrawal period on the source chain.


```solidity
function getSrcWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private withdrawal duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The duration of the private withdrawal period.|


### setSrcWithdrawalDuration

Sets the duration of the private withdrawal period on the source chain.


```solidity
function setSrcWithdrawalDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the private withdrawal duration to.|
|`value`|`uint256`|The new duration of the private withdrawal period.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the private withdrawal duration set.|


### getSrcCancellationStart

Gets the start of the private cancellation period on the source chain.


```solidity
function getSrcCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private withdrawal duration from.|
|`startTimestamp`|`uint256`|The timestamp when the counting starts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private cancellation period.|


### getSrcCancellationDuration

Gets the duration of the private cancellation period on the source chain.


```solidity
function getSrcCancellationDuration(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private cancellation duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The duration of the private cancellation period.|


### setSrcCancellationDuration

Sets the duration of the private cancellation period on the source chain.


```solidity
function setSrcCancellationDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the private cancellation duration to.|
|`value`|`uint256`|The duration of the private cancellation period.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the private cancellation duration set.|


### getSrcPubCancellationStart

Gets the start of the public cancellation period on the source chain.


```solidity
function getSrcPubCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private cancellation duration from.|
|`startTimestamp`|`uint256`|The timestamp when the counting starts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the public cancellation period.|


### getDstFinalityDuration

Gets the duration of the finality period on the destination chain.


```solidity
function getDstFinalityDuration(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the finality duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The duration of the finality period.|


### setDstFinalityDuration

Sets the duration of the finality period on the destination chain.


```solidity
function setDstFinalityDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the finality duration to.|
|`value`|`uint256`|The duration of the finality period.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the finality duration set.|


### getDstWithdrawalStart

Gets the start of the private withdrawal period on the destination chain.


```solidity
function getDstWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the finality duration from.|
|`startTimestamp`|`uint256`|The timestamp when the counting starts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private withdrawal period.|


### getDstWithdrawalDuration

Gets the duration of the private withdrawal period on the destination chain.


```solidity
function getDstWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private withdrawal duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The duration of the private withdrawal period.|


### setDstWithdrawalDuration

Sets the duration of the private withdrawal period on the destination chain.


```solidity
function setDstWithdrawalDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the private withdrawal duration to.|
|`value`|`uint256`|The new duration of the private withdrawal period.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the private withdrawal duration set.|


### getDstPubWithdrawalStart

Gets the start of the public withdrawal period on the destination chain.


```solidity
function getDstPubWithdrawalStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the private withdrawal duration from.|
|`startTimestamp`|`uint256`|The timestamp when the counting starts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the public withdrawal period.|


### getDstPubWithdrawalDuration

Gets the duration of the public withdrawal period on the destination chain.


```solidity
function getDstPubWithdrawalDuration(Timelocks timelocks) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the public withdrawal duration from.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The duration of the public withdrawal period.|


### setDstPubWithdrawalDuration

Sets the duration of the public withdrawal period on the destination chain.


```solidity
function setDstPubWithdrawalDuration(Timelocks timelocks, uint256 value) internal pure returns (Timelocks);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to set the public withdrawal duration to.|
|`value`|`uint256`|The new duration of the public withdrawal period.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Timelocks`|The timelocks with the public withdrawal duration set.|


### getDstCancellationStart

Gets the start of the private cancellation period on the destination chain.


```solidity
function getDstCancellationStart(Timelocks timelocks, uint256 startTimestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timelocks`|`Timelocks`|The timelocks to get the public withdrawal duration from.|
|`startTimestamp`|`uint256`|The timestamp when the counting starts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start of the private cancellation period.|


