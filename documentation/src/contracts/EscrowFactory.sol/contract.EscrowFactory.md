# EscrowFactory
[Git Source](https://github.com/byshape/cross-chain-swap/blob/c49176f8473d9a06db920990a07a4d8464dd4dd4/contracts/EscrowFactory.sol)

**Inherits:**
[IEscrowFactory](/contracts/interfaces/IEscrowFactory.sol/interface.IEscrowFactory.md), ExtensionBase


## State Variables
### IMPLEMENTATION

```solidity
address public immutable IMPLEMENTATION;
```


## Functions
### constructor


```solidity
constructor(address implementation, address limitOrderProtocol) ExtensionBase(limitOrderProtocol);
```

### _postInteraction

*Creates a new escrow contract for maker.*


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

*Creates a new escrow contract for taker.*


```solidity
function createEscrow(DstEscrowImmutablesCreation calldata dstEscrowImmutables) external;
```

### addressOfEscrow


```solidity
function addressOfEscrow(bytes32 salt) external view returns (address);
```

### _createEscrow


```solidity
function _createEscrow(bytes memory data, bytes32 salt) private returns (address clone);
```

