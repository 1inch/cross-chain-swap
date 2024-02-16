# Escrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/Escrow.sol)

**Inherits:**
Clone, [IEscrow](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md)


## State Variables
### RESCUE_DELAY

```solidity
uint256 public immutable RESCUE_DELAY;
```


## Functions
### constructor


```solidity
constructor(uint256 rescueDelay);
```

### _isValidSecret


```solidity
function _isValidSecret(bytes32 secret, bytes32 hashlock) internal pure returns (bool);
```

### _checkSecretAndTransfer

Checks the secret and transfers tokens to the recipient.

*The secret is valid if its hash matches the hashlock.*


```solidity
function _checkSecretAndTransfer(bytes32 secret, bytes32 hashlock, address recipient, address token, uint256 amount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|Provided secret to verify.|
|`hashlock`|`bytes32`|Hashlock to compare with.|
|`recipient`|`address`|Address to transfer tokens to.|
|`token`|`address`|Address of the token to transfer.|
|`amount`|`uint256`|Amount of tokens to transfer.|


### _rescueFunds


```solidity
function _rescueFunds(Timelocks timelocks, address token, uint256 amount) internal;
```

### _uniTransfer


```solidity
function _uniTransfer(address token, address to, uint256 amount) internal;
```

