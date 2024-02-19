# EscrowFactory
[Git Source](https://github.com/1inch/cross-chain-swap/blob/ebb85c41907258c27b301dda207e13dd189a6048/contracts/EscrowFactory.sol)

**Inherits:**
[IEscrowFactory](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md), SimpleSettlementExtension

Contract to create escrow contracts for cross-chain atomic swap.


## State Variables
### _EXTRA_DATA_PARAMS_OFFSET

```solidity
uint256 internal constant _EXTRA_DATA_PARAMS_OFFSET = 4;
```


### _WHITELIST_OFFSET

```solidity
uint256 internal constant _WHITELIST_OFFSET = 228;
```


### IMPL_SRC

```solidity
address public immutable IMPL_SRC;
```


### IMPL_DST

```solidity
address public immutable IMPL_DST;
```


## Functions
### constructor


```solidity
constructor(address implSrc, address implDst, address limitOrderProtocol, IERC20 token)
    SimpleSettlementExtension(limitOrderProtocol, token);
```

### _postInteraction

Creates a new escrow contract for maker on the source chain.

*The caller must be whitelisted and pre-send the safety deposit in a native token
to a pre-computed deterministic address of the created escrow.
The external postInteraction function call will be made from the Limit Order Protocol
after all funds have been transferred. See [IPostInteraction-postInteraction](/lib/limit-order-protocol/contracts/mocks/InteractionMock.sol/contract.InteractionMock.md#postinteraction).
`extraData` consists of:
- 4 bytes for the fee
- 7 * 32 bytes for hashlock, packedAddresses (2 * 32), dstChainId, dstToken, deposits and timelocks
- whitelist*


```solidity
function _postInteraction(
    IOrderMixin.Order calldata order,
    bytes calldata,
    bytes32 orderHash,
    address taker,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256,
    bytes calldata extraData
) internal override;
```

### createDstEscrow

See [IEscrowFactory-createDstEscrow](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#createdstescrow).


```solidity
function createDstEscrow(EscrowImmutablesCreation calldata dstImmutables) external payable;
```

### addressOfEscrowSrc

See [IEscrowFactory-addressOfEscrowSrc](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#addressofescrowsrc).


```solidity
function addressOfEscrowSrc(bytes memory data) public view returns (address);
```

### addressOfEscrowDst

See [IEscrowFactory-addressOfEscrowDst](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#addressofescrowdst).


```solidity
function addressOfEscrowDst(bytes memory data) public view returns (address);
```

### _createEscrow

Creates a new escrow contract with immutable arguments.

*The escrow contract is a proxy clone created using the create2 pattern.*


```solidity
function _createEscrow(address implementation, bytes memory data, uint256 value) private returns (address clone);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|The address of the escrow contract implementation.|
|`data`|`bytes`|Encoded immutable args.|
|`value`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`clone`|`address`|The address of the created escrow contract.|


