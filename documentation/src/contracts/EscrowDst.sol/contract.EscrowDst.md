# EscrowDst
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/EscrowDst.sol)

**Inherits:**
[Escrow](/contracts/Escrow.sol/abstract.Escrow.md), [IEscrowDst](/contracts/interfaces/IEscrowDst.sol/interface.IEscrowDst.md)

Contract to initially lock funds and then unlock them with verification of the secret presented.

*Funds are locked in at the time of contract deployment. For this taker calls the `EscrowFactory.createDstEscrow` function.*


## Functions
### constructor


```solidity
constructor(uint256 rescueDelay) Escrow(rescueDelay);
```

### withdraw

See [IEscrow-withdraw](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#withdraw).

*The function works on the time intervals highlighted with capital letters:
---- contract deployed --/-- finality --/-- PRIVATE WITHDRAWAL --/-- PUBLIC WITHDRAWAL --/-- private cancellation ----*


```solidity
function withdraw(bytes32 secret) external;
```

### cancel

See [IEscrow-cancel](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#cancel).

*The function works on the time interval highlighted with capital letters:
---- contract deployed --/-- finality --/-- private withdrawal --/-- public withdrawal --/-- PRIVATE CANCELLATION ----*


```solidity
function cancel() external;
```

### rescueFunds

See [IEscrow-rescueFunds](/contracts/interfaces/IEscrow.sol/interface.IEscrow.md#rescuefunds).


```solidity
function rescueFunds(address token, uint256 amount) external;
```

### escrowImmutables

See [IEscrowDst-escrowImmutables](/contracts/interfaces/IEscrowSrc.sol/interface.IEscrowSrc.md#escrowimmutables).


```solidity
function escrowImmutables() public pure returns (EscrowImmutables calldata data);
```

