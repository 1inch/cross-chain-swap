# Escrow
[Git Source](https://github.com/1inch/cross-chain-swap/blob/a0032266a4f4e0c7ae999b45292f7c9116abe373/contracts/Escrow.sol)

**Inherits:**
Clone, [IEscrow](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md)

Contract to initially lock funds on both chains and then unlock with verification of the secret presented.

*Funds are locked in at the time of contract deployment. On both chains this is done by calling `EscrowFactory`
functions. On the source chain Limit Order Protocol calls the `postInteraction` function and on the destination
chain taker calls the `createEscrow` function.
Withdrawal and cancellation functions for the source and destination chains are implemented separately.*


## Functions
### withdrawSrc

See [IEscrow-withdrawSrc](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#withdrawsrc).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancel --/-- public cancel ----*


```solidity
function withdrawSrc(bytes32 secret) external;
```

### cancelSrc

See [IEscrow-cancelSrc](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#cancelsrc).

*The function works on the time intervals highlighted with capital letters:
---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCEL --/-- PUBLIC CANCEL ----*


```solidity
function cancelSrc() external;
```

### withdrawDst

See [IEscrow-withdrawDst](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#withdrawdst).

*The function works on the time intervals highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancel ----*


```solidity
function withdrawDst(bytes32 secret) external;
```

### cancelDst

See [IEscrow-cancelDst](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#canceldst).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCEL ----*


```solidity
function cancelDst() external;
```

### srcEscrowImmutables

See [IEscrow-srcEscrowImmutables](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#srcescrowimmutables).


```solidity
function srcEscrowImmutables() public pure returns (SrcEscrowImmutables calldata data);
```

### dstEscrowImmutables

See [IEscrow-dstEscrowImmutables](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#dstescrowimmutables).


```solidity
function dstEscrowImmutables() public pure returns (DstEscrowImmutables calldata data);
```

### _isValidSecret

Verifies the provided secret.

*The secret is valid if its hash matches the hashlock.*


```solidity
function _isValidSecret(bytes32 secret, bytes32 hashlock) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|Provided secret to verify.|
|`hashlock`|`bytes32`|Hashlock to compare with.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the secret is valid, false otherwise.|


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


