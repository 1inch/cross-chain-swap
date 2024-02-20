# IEscrowSrc
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/interfaces/IEscrowSrc.sol)

Interface implies locking funds initially and then unlocking them with verification of the secret presented.


## Functions
### escrowImmutables

Returns the immutable parameters of the escrow contract.

*The immutables are stored at the end of the proxy clone contract bytecode and
are added to the calldata each time the proxy clone function is called.*


```solidity
function escrowImmutables() external pure returns (EscrowImmutables calldata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`EscrowImmutables`|The immutables of the escrow contract.|


## Structs
### EscrowImmutables

```solidity
struct EscrowImmutables {
    bytes32 orderHash;
    uint256 srcAmount;
    uint256 dstAmount;
    bytes32 hashlock;
    PackedAddresses packedAddresses;
    uint256 dstChainId;
    Address dstToken;
    uint256 deposits;
    Timelocks timelocks;
}
```
