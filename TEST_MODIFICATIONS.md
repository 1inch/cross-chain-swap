# Test Modifications for SHA-256 Migration

## Overview
All tests must be updated to use SHA-256 instead of Keccak-256 for secret hashing.

## Key Test Files to Modify

### 1. test/utils/BaseSetup.sol
Current:
```solidity
bytes32 secret = bytes32(uint256(1));
bytes32 hashlock = keccak256(abi.encode(secret));
```

Update to:
```solidity
bytes32 secret = bytes32(uint256(1));
bytes32 hashlock = sha256(abi.encode(secret));
```

### 2. test/unit/Escrow.t.sol
All test functions using hashlock need updates:
- `test_WithdrawSrc()`
- `test_WithdrawByResolverDst()`
- `test_NoWithdrawalWithWrongSecretDst()`
- `test_NoWithdrawalWithWrongSecretSrc()`

### 3. test/unit/EscrowFactory.t.sol
Update `ExtraDataArgs` encoding in:
- `setUp()`
- `test_NoDeploymentForNotResolver()`
- All deployment tests

### 4. test/integration/EscrowFactory.t.sol
- Update merkle tree tests if they use hashlock
- Update resolver mock tests

### 5. test/integration/MerkleStorageInvalidator.t.sol
If using multiple secrets:
```solidity
// Generate leaves with SHA-256
for (uint256 i = 0; i < secretsAmount; i++) {
    secrets[i] = bytes32(i + 1);
    leaves[i] = sha256(abi.encode(secrets[i]));
}
```

## Helper Function Updates

### Add to BaseSetup.sol:
```solidity
function generateHashlock(bytes32 secret) internal pure returns (bytes32) {
    return sha256(abi.encode(secret));
}

function generateSecrets(uint256 count) internal pure returns (bytes32[] memory secrets, bytes32[] memory hashlocks) {
    secrets = new bytes32[](count);
    hashlocks = new bytes32[](count);
    
    for (uint256 i = 0; i < count; i++) {
        secrets[i] = bytes32(i + 1);
        hashlocks[i] = sha256(abi.encode(secrets[i]));
    }
}
```

## Running Tests

**Important**: You must set the `FOUNDRY_PROFILE` environment variable to run tests:

```bash
# Run all tests with verbose output
FOUNDRY_PROFILE=default forge test -vvv

# Run specific test file
FOUNDRY_PROFILE=default forge test --match-path test/unit/Escrow.t.sol -vvv

# Run single test
FOUNDRY_PROFILE=default forge test --match-test test_WithdrawSrc -vvv

# Gas report
FOUNDRY_PROFILE=default forge test --gas-report
```

**Note**: Without `FOUNDRY_PROFILE=default`, tests will fail with "environment variable not found" error.

## Expected Changes in Gas Costs

SHA-256 is more expensive than Keccak-256:
- Keccak-256: 30 gas + 6 per word
- SHA-256: 60 gas + 12 per word

For single 32-byte hash:
- Keccak-256: ~36 gas
- SHA-256: ~72 gas

Update gas expectations in tests accordingly.

## Verification Steps

1. All tests pass with SHA-256
2. Gas snapshots updated
3. Integration tests work end-to-end
4. No hardcoded Keccak-256 hashes remain
5. Documentation updated

## Common Errors to Watch For

1. **Mismatch between hash methods**: Ensure both secret generation and verification use SHA-256
2. **Hardcoded test values**: Search for any hardcoded hashlock values
3. **External test dependencies**: Mock contracts may need updates
4. **Event assertions**: Ensure emitted hashlocks match new algorithm

## Test Coverage Checklist

- [ ] Unit tests for BaseEscrow._sha256Bytes32()
- [ ] Secret validation in all escrow types
- [ ] Factory deployment with new hashlocks
- [ ] Merkle proof verification (if applicable)
- [ ] Gas optimization tests
- [ ] Failure case tests (wrong secret)
- [ ] Cross-contract integration tests