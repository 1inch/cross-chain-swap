# Escrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/Escrow.sol)

**Inherits:**
[IEscrow](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md)


## State Variables
### RESCUE_DELAY

```solidity
uint256 public immutable RESCUE_DELAY;
```


### FACTORY

```solidity
address public immutable FACTORY = msg.sender;
```


### PROXY_BYTECODE_HASH

```solidity
bytes32 public immutable PROXY_BYTECODE_HASH = Clones.computeProxyBytecodeHash(address(this));
```


## Functions
### constructor


```solidity
constructor(uint32 rescueDelay);
```

### onlyValidImmutables


```solidity
modifier onlyValidImmutables(Immutables calldata immutables);
```

### rescueFunds

See [IEscrow-rescueFunds](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#rescuefunds).


```solidity
function rescueFunds(address token, uint256 amount, Immutables calldata immutables) external onlyValidImmutables(immutables);
```

### _isValidSecret


```solidity
function _isValidSecret(bytes32 secret, bytes32 hashlock) internal pure returns (bool);
```

### _checkSecretAndTransfer

Checks the secret and transfers tokens to the recipient.

*The secret is valid if its hash matches the hashlock.*


```solidity
function _checkSecretAndTransfer(bytes32 secret, bytes32 hashlock, address recipient, address token, uint256 amount) internal;
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

### _ethTransfer


```solidity
function _ethTransfer(address to, uint256 amount) internal;
```

### _validateImmutables


```solidity
function _validateImmutables(Immutables calldata immutables) private view;
```

