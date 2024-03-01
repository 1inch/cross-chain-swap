# IEscrowSrc
[Git Source](https://github.com/1inch/cross-chain-swap/blob/dc0ae325b453eb92201e3de6c74cc1cd6558cced/contracts/interfaces/IEscrowSrc.sol)

Interface implies locking funds initially and then unlocking them with verification of the secret presented.


## Functions
### withdrawTo

Withdraws funds to a specified target.

*Withdrawal can only be made during the withdrawal period and with secret with hash matches the hashlock.
The safety deposit is sent to the caller.*


```solidity
function withdrawTo(bytes32 secret, address target, IEscrow.Immutables calldata immutables) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`secret`|`bytes32`|The secret that unlocks the escrow.|
|`target`|`address`||
|`immutables`|`IEscrow.Immutables`||


