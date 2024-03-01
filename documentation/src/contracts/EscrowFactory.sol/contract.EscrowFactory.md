# EscrowFactory
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/EscrowFactory.sol)

**Inherits:**
[IEscrowFactory](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md), WhitelistExtension, ResolverFeeExtension

Contract to create escrow contracts for cross-chain atomic swap.


## State Variables
### _SRC_IMMUTABLES_LENGTH

```solidity
uint256 private constant _SRC_IMMUTABLES_LENGTH = 160;
```


### ESCROW_SRC_IMPLEMENTATION

```solidity
address public immutable ESCROW_SRC_IMPLEMENTATION;
```


### ESCROW_DST_IMPLEMENTATION

```solidity
address public immutable ESCROW_DST_IMPLEMENTATION;
```


### _PROXY_SRC_BYTECODE_HASH

```solidity
bytes32 private immutable _PROXY_SRC_BYTECODE_HASH;
```


### _PROXY_DST_BYTECODE_HASH

```solidity
bytes32 private immutable _PROXY_DST_BYTECODE_HASH;
```


## Functions
### constructor


```solidity
constructor(
    address limitOrderProtocol,
    IERC20 token,
    uint32 rescueDelaySrc,
    uint32 rescueDelayDst
) BaseExtension(limitOrderProtocol) ResolverFeeExtension(token);
```

### _postInteraction

Creates a new escrow contract for maker on the source chain.

*The caller must be whitelisted and pre-send the safety deposit in a native token
to a pre-computed deterministic address of the created escrow.
The external postInteraction function call will be made from the Limit Order Protocol
after all funds have been transferred. See [IPostInteraction-postInteraction](/lib/limit-order-protocol/contracts/mocks/InteractionMock.sol/contract.InteractionMock.md#postinteraction).
`extraData` consists of:
- ExtraDataImmutables struct
- whitelist
- 0 / 4 bytes for the fee
- 1 byte for the bitmap*


```solidity
function _postInteraction(
    IOrderMixin.Order calldata order,
    bytes calldata extension,
    bytes32 orderHash,
    address taker,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256 remainingMakingAmount,
    bytes calldata extraData
) internal override(WhitelistExtension, ResolverFeeExtension);
```

### createDstEscrow

See [IEscrowFactory-createDstEscrow](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#createdstescrow).


```solidity
function createDstEscrow(IEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external payable;
```

### addressOfEscrowSrc

See [IEscrowFactory-addressOfEscrowSrc](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#addressofescrowsrc).


```solidity
function addressOfEscrowSrc(IEscrow.Immutables calldata immutables) external view returns (address);
```

### addressOfEscrowDst

See [IEscrowFactory-addressOfEscrowDst](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#addressofescrowdst).


```solidity
function addressOfEscrowDst(IEscrow.Immutables calldata immutables) external view returns (address);
```

