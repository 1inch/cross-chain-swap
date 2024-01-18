# EscrowFactory
[Git Source](https://github.com/1inch/cross-chain-swap/blob/f45e33f855d5dd79428a1ba540d9f8df14bbb794/contracts/EscrowFactory.sol)

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
    bytes32 orderHash,
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
function addressOfEscrow(bytes32 salt) public view returns (address);
```

### _createEscrow

Creates a new escrow contract with immutable arguments.

*The escrow contract is a proxy clone created using the create3 pattern.*


```solidity
function _createEscrow(bytes memory data, bytes32 salt, uint256 value) private returns (address clone);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Encoded immutable args.|
|`salt`|`bytes32`|The salt that influences the contract address in deterministic deployment.|
|`value`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`clone`|`address`|The address of the created escrow contract.|


