# Clones
[Git Source](https://github.com/1inch/cross-chain-swap/blob/953335457652894d3aa7caf6353d8c55f2e2a675/contracts/libraries/Clones.sol)

*https://eips.ethereum.org/EIPS/eip-1167[ERC-1167] is a standard for
deploying minimal proxy contracts, also known as "clones".
> To simply and cheaply clone contract functionality in an immutable way, this standard specifies
> a minimal bytecode implementation that delegates all calls to a known, fixed address.
The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
(salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
deterministic method.*


## Functions
### cloneDeterministic

*Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
This function uses the create2 opcode and a `salt` to deterministically deploy
the clone. Using the same `implementation` and `salt` multiple time will revert, since
the clones cannot be deployed twice at the same address.*


```solidity
function cloneDeterministic(address implementation, bytes32 salt, uint256 value) internal returns (address instance);
```

### computeProxyBytecodeHash


```solidity
function computeProxyBytecodeHash(address implementation) internal pure returns (bytes32 bytecodeHash);
```

## Errors
### ERC1167FailedCreateClone
*A clone instance deployment failed.*


```solidity
error ERC1167FailedCreateClone();
```

