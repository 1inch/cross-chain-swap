# EscrowSrc
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/EscrowSrc.sol)

**Inherits:**
[Escrow](/contracts/Escrow.sol/abstract.Escrow.md), [IEscrowSrc](/contracts/interfaces/IEscrowSrc.sol/interface.IEscrowSrc.md)

Contract to initially lock funds and then unlock them with verification of the secret presented.

*Funds are locked in at the time of contract deployment. For this Limit Order Protocol
calls the `EscrowFactory.postInteraction` function.*


## Functions
### constructor


```solidity
constructor(uint256 rescueDelay) Escrow(rescueDelay);
```

### withdraw

See [IEscrow-withdraw](/contracts/EscrowDst.sol/contract.EscrowDst.md#withdraw).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----*


```solidity
function withdraw(bytes32 secret) external;
```

### cancel

See [IEscrow-cancel](/contracts/EscrowDst.sol/contract.EscrowDst.md#cancel).

*The function works on the time intervals highlighted with capital letters:
---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCELLATION --/-- PUBLIC CANCELLATION ----*


```solidity
function cancel() external;
```

### rescueFunds

See [IEscrow-rescueFunds](/contracts/EscrowDst.sol/contract.EscrowDst.md#rescuefunds).


```solidity
function rescueFunds(address token, uint256 amount) external;
```

### escrowImmutables

See [IEscrowSrc-escrowImmutables](/contracts/EscrowDst.sol/contract.EscrowDst.md#escrowimmutables).


```solidity
function escrowImmutables() public pure returns (EscrowImmutables calldata data);
```

