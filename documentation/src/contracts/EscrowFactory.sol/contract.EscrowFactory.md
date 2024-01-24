# EscrowFactory
[Git Source](https://github.com/1inch/cross-chain-swap/blob/4a7a924cfc3cdc40ce87e400e418d193236c06fb/contracts/EscrowFactory.sol)

**Inherits:**
[IEscrowFactory](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md), SimpleSettlementExtension

Contract to create escrow contracts for cross-chain atomic swap.


## State Variables
### IMPLEMENTATION

```solidity
address public immutable IMPLEMENTATION;
```


## Functions
### constructor


```solidity
constructor(address implementation, address limitOrderProtocol, IERC20 token)
    SimpleSettlementExtension(limitOrderProtocol, token);
```

### _postInteraction

Creates a new escrow contract for maker on the source chain.

*The caller must be whitelisted and pre-send the safety deposit in a native token
to a pre-computed deterministic address of the created escrow.
The external postInteraction function call will be made from the Limit Order Protocol
after all funds have been transferred. See [IPostInteraction-postInteraction](/lib/limit-order-protocol/contracts/mocks/InteractionMock.sol/contract.InteractionMock.md#postinteraction).*


```solidity
function _postInteraction(
    IOrderMixin.Order calldata order,
    bytes calldata,
    bytes32,
    address taker,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256,
    bytes calldata extraData
) internal override;
```

### createEscrow

See [IEscrowFactory-createEscrow](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#createescrow).


```solidity
function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external payable;
```

### addressOfEscrow

See [IEscrowFactory-addressOfEscrow](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md#addressofescrow).


```solidity
function addressOfEscrow(bytes memory data) public view returns (address);
```

### _createEscrow

Creates a new escrow contract with immutable arguments.

*The escrow contract is a proxy clone created using the create2 pattern.*


```solidity
function _createEscrow(bytes memory data, uint256 value) private returns (address clone);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Encoded immutable args.|
|`value`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`clone`|`address`|The address of the created escrow contract.|


