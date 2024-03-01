# EscrowSrc
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/EscrowSrc.sol)

**Inherits:**
[Escrow](/contracts/Escrow.sol/abstract.Escrow.md), [IEscrowSrc](/contracts/interfaces/IEscrowSrc.sol/interface.IEscrowSrc.md)

Contract to initially lock funds and then unlock them with verification of the secret presented.

*Funds are locked in at the time of contract deployment. For this Limit Order Protocol
calls the `EscrowFactory.postInteraction` function.
To perform any action, the caller must provide the same Immutables values used to deploy the clone contract.*


## Functions
### constructor


```solidity
constructor(uint32 rescueDelay) Escrow(rescueDelay);
```

### withdraw

See [IEscrow-withdraw](/contracts/EscrowDst.sol/contract.EscrowDst.md#withdraw).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----*


```solidity
function withdraw(bytes32 secret, Immutables calldata immutables) external onlyValidImmutables(immutables);
```

### withdrawTo

See [IEscrowSrc-withdrawTo](/contracts/interfaces/IEscrowSrc.sol/interface.IEscrowSrc.md#withdrawto).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- private cancellation --/-- public cancellation ----*


```solidity
function withdrawTo(bytes32 secret, address target, Immutables calldata immutables) external onlyValidImmutables(immutables);
```

### cancel

See [IEscrow-cancel](/contracts/EscrowDst.sol/contract.EscrowDst.md#cancel).

*The function works on the time intervals highlighted with capital letters:
---- contract deployed --/-- finality --/-- private withdrawal --/-- PRIVATE CANCELLATION --/-- PUBLIC CANCELLATION ----*


```solidity
function cancel(Immutables calldata immutables) external onlyValidImmutables(immutables);
```

### _withdrawTo


```solidity
function _withdrawTo(bytes32 secret, address target, Immutables calldata immutables) internal;
```

