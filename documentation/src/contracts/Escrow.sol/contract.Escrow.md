# Escrow
[Git Source](https://github.com/byshape/cross-chain-swap/blob/c49176f8473d9a06db920990a07a4d8464dd4dd4/contracts/Escrow.sol)

**Inherits:**
Clone, [IEscrow](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md)


## Functions
### withdrawSrc


```solidity
function withdrawSrc(bytes32 secret) external;
```

### cancelSrc


```solidity
function cancelSrc() external;
```

### withdrawDst


```solidity
function withdrawDst(bytes32 secret) external;
```

### cancelDst


```solidity
function cancelDst() external;
```

### srcEscrowImmutables


```solidity
function srcEscrowImmutables() public pure returns (SrcEscrowImmutables calldata);
```

### dstEscrowImmutables


```solidity
function dstEscrowImmutables() public pure returns (DstEscrowImmutables calldata);
```

### _isValidSecret


```solidity
function _isValidSecret(bytes32 secret, uint256 hashlock) internal pure returns (bool);
```

### _checkSecretAndTransfer


```solidity
function _checkSecretAndTransfer(bytes32 secret, uint256 hashlock, address recipient, address token, uint256 amount)
    internal;
```

