# PackedAddressesLib
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/libraries/PackedAddressesLib.sol)

Library to pack 3 addresses into 2 uint256 values.


## Functions
### maker

Returns the maker address from the packed addresses.


```solidity
function maker(PackedAddresses calldata packedAddresses) internal pure returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`packedAddresses`|`PackedAddresses`|Packed addresses.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The maker address.|


### taker

Returns the taker address from the packed addresses.


```solidity
function taker(PackedAddresses calldata packedAddresses) internal pure returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`packedAddresses`|`PackedAddresses`|Packed addresses.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The taker address.|


### token

Returns the taker address from the packed addresses.


```solidity
function token(PackedAddresses calldata packedAddresses) internal pure returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`packedAddresses`|`PackedAddresses`|Packed addresses.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The taker address.|


### _maker


```solidity
function _maker(uint256 addressesPart1) internal pure returns (address);
```

### _taker


```solidity
function _taker(uint256 addressesPart1, uint256 addressesPart2) internal pure returns (address);
```

### _token


```solidity
function _token(uint256 addressesPart2) internal pure returns (address);
```

