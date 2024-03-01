# EscrowDst
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/EscrowDst.sol)

**Inherits:**
[Escrow](/contracts/Escrow.sol/abstract.Escrow.md)

Contract to initially lock funds and then unlock them with verification of the secret presented.

*Funds are locked in at the time of contract deployment. For this taker calls the `EscrowFactory.createDstEscrow` function.
To perform any action, the caller must provide the same Immutables values used to deploy the clone contract.*


## Functions
### constructor


```solidity
constructor(uint32 rescueDelay) Escrow(rescueDelay);
```

### withdraw

See [IEscrow-withdraw](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#withdraw).

*The function works on the time intervals highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----*


```solidity
function withdraw(bytes32 secret, Immutables calldata immutables) external onlyValidImmutables(immutables);
```

### cancel

See [IEscrow-cancel](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#cancel).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCELLATION ----*


```solidity
function cancel(Immutables calldata immutables) external onlyValidImmutables(immutables);
```

