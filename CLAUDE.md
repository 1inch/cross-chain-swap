# ETH-Solana Atomic Swap Implementation Guide

## Overview
This document contains all critical insights and implementation details for enabling atomic swaps between Ethereum and Solana using the existing cross-chain swap escrow contracts as a base.

## Implementation Status ✅
All Ethereum/Solidity changes have been completed (January 6, 2025):
- ✅ SHA-256 hash function implemented
- ✅ Non-EVM address support added
- ✅ All tests updated and passing
- ✅ Ready for Solana program development

## Key Challenges and Solutions

### 1. Address Format Incompatibility
- **Problem**: Solana addresses are 32 bytes (base58 encoded), Ethereum addresses are 20 bytes
- **Solution**: Add a new `dstRecipient` field to `ExtraDataArgs` to store full 32-byte non-EVM addresses

### 2. Hash Algorithm Compatibility
- **Problem**: Current implementation uses Keccak-256, but Solana's `sol_keccak256` syscall is unreliable
- **Solution**: Switch to SHA-256, which both chains support reliably

### 3. Non-EVM Chain Identification
- **Current Design**: MSB (bit 255) of `dstChainId` is used as a flag (1 = non-EVM, 0 = EVM)
- **Keep**: This design is good and should be retained

## Required Solidity Changes (COMPLETED ✅)

### 1. Modify BaseEscrowFactory.sol

#### Add dstRecipient to ExtraDataArgs
```solidity
struct ExtraDataArgs {
    bytes32 hashlockInfo;    // Hash of the secret or Merkle root
    uint256 dstChainId;      // MSB = non-EVM flag, lower 255 bits = chain ID
    Address dstToken;        // Token on destination (EVM format)
    uint256 deposits;        // Upper 128: src deposit, lower 128: dst deposit
    Timelocks timelocks;
    bytes32 dstRecipient;    // NEW: Full 32-byte address for non-EVM chains
}
```

#### Update postInteraction logic
In `BaseEscrowFactory._postInteraction()`, modify the logic to handle non-EVM addresses:

```solidity
// After line 75, enhance the non-EVM chain handling:
bool dstChainIsNotEVM = (extraDataArgs.dstChainId >> 255) == 1;

if (dstChainIsNotEVM) {
    // For non-EVM chains, dstRecipient must be provided
    require(extraDataArgs.dstRecipient != bytes32(0), "Invalid non-EVM recipient");
    // The receiver check at line 79 already ensures receiver is zero for non-EVM
}

// Later in the function, when setting up immutablesComplement (around line 107):
DstImmutablesComplement memory immutablesComplement = DstImmutablesComplement({
    maker: dstChainIsNotEVM ? Address.wrap(0) : (receiver.get() == address(0) ? order.maker : receiver),
    amount: takingAmount,
    token: extraDataArgs.dstToken,
    safetyDeposit: extraDataArgs.deposits & type(uint128).max,
    chainId: extraDataArgs.dstChainId & CHAIN_ID_MASK
});

// Emit additional event for non-EVM recipient if needed
if (dstChainIsNotEVM) {
    emit NonEVMRecipient(orderHash, extraDataArgs.dstRecipient, extraDataArgs.dstChainId & CHAIN_ID_MASK);
}
```

### 2. Modify BaseEscrow.sol

#### Change from Keccak-256 to SHA-256
```solidity
// Replace the existing _keccakBytes32 function
function _sha256Bytes32(bytes32 secret) private pure returns (bytes32) {
    return sha256(abi.encode(secret));
}

// Update the onlyValidSecret modifier
modifier onlyValidSecret(bytes32 secret, Immutables calldata immutables) {
    if (_sha256Bytes32(secret) != immutables.hashlock) revert InvalidSecret();
    _;
}
```

### 3. Event Updates

Add a new event or modify existing events to include the non-EVM recipient:
```solidity
event NonEVMRecipient(bytes32 indexed orderHash, bytes32 recipient, uint256 chainId);
```

### 4. Update Interface Files

Update `IEscrowFactory.sol` to reflect the new `ExtraDataArgs` structure.

### 5. Update Constants

Update `SRC_IMMUTABLES_LENGTH` in `EscrowFactoryContext.sol` from 160 to 192 (adding 32 bytes for dstRecipient).

## Test Updates

All tests must be updated to use SHA-256 instead of Keccak-256.

### Running Tests
```bash
FOUNDRY_PROFILE=default forge test -vvv
```

### Key Test Files to Update
1. `test/unit/Escrow.t.sol` - Update secret generation
2. `test/unit/EscrowFactory.t.sol` - Update ExtraDataArgs encoding
3. `test/integration/*.t.sol` - Update all integration tests
4. `test/utils/BaseSetup.sol` - Update helper functions

### Example Test Update
```solidity
// Old (Keccak-256)
bytes32 secret = bytes32(uint256(1));
bytes32 hashlock = keccak256(abi.encode(secret));

// New (SHA-256)
bytes32 secret = bytes32(uint256(1));
bytes32 hashlock = sha256(abi.encode(secret));
```

### Test Helper Function Updates
In `test/utils/libraries/CrossChainTestLib.sol`, update the `buidDynamicData` function:
```solidity
function buidDynamicData(
    bytes32 hashlock,
    uint256 chainId,
    address token,
    uint256 srcSafetyDeposit,
    uint256 dstSafetyDeposit,
    Timelocks timelocks,
    bytes32 dstRecipient  // NEW parameter
) internal pure returns (bytes memory) {
    return (
        abi.encode(
            hashlock,
            chainId,
            token,
            (srcSafetyDeposit << 128) | dstSafetyDeposit,
            timelocks,
            dstRecipient  // NEW field
        )
    );
}
```

## Gas Considerations

- SHA-256 is slightly more expensive than Keccak-256 on Ethereum
- Keccak-256: 30 gas + 6 per word
- SHA-256: 60 gas + 12 per word
- For our use case (single 32-byte hash), the difference is minimal

## Deployment Notes

1. These changes are backward-incompatible
2. New factory contracts must be deployed
3. Existing escrows will continue to work with Keccak-256
4. New escrows will use SHA-256

## Security Considerations

1. SHA-256 is cryptographically secure and widely used
2. The switch doesn't affect the security model
3. Secret must remain 32 bytes for compatibility
4. Time windows must account for cross-chain latency

## Integration Points

1. Limit Order Protocol remains unchanged
2. Resolver infrastructure needs updates for:
   - Non-EVM address handling
   - SHA-256 secret generation
   - Cross-chain monitoring

## Next Steps

See `SOLANA_IMPLEMENTATION.md` and `CLI_TOOL_DESIGN.md` for:
- Solana Anchor program implementation
- CLI tool architecture
- Cross-chain coordination logic