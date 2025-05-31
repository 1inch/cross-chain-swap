# ETH-Solana Atomic Swap Implementation Roadmap

## Project Overview
This document provides the complete roadmap for implementing atomic swaps between Ethereum and Solana, based on all analysis and documentation created.

## Documentation Structure
1. **CLAUDE.md** - Ethereum contract modifications (SHA-256, dstRecipient field)
2. **SOLANA_IMPLEMENTATION.md** - Complete Anchor program specification
3. **CLI_TOOL_DESIGN.md** - Deno-based CLI tool with viem and Deno KV
4. **ATOMIC_SWAP_FLOW.md** - Detailed swap flow and security analysis
5. **TEST_MODIFICATIONS.md** - Guide for updating tests to SHA-256
6. **TECH_STACK_UPDATE.md** - Technology choices (Deno, viem, Deno KV)
7. **SOLLIGHTNING_INSIGHTS.md** - Learnings from Bitcoin-Solana implementation
8. **PROJECT_SUMMARY.md** - High-level overview
9. **IMPLEMENTATION_ROADMAP.md** - This file

## Phase 1: Ethereum Contract Updates (Week 1)

### Day 1-2: Core Contract Changes
1. **Update BaseEscrow.sol**
   - Replace `_keccakBytes32` with `_sha256Bytes32`
   - Update `onlyValidSecret` modifier
   - Test the changes locally

2. **Update BaseEscrowFactory.sol**
   - Add `bytes32 dstRecipient` to `ExtraDataArgs`
   - Modify validation logic for non-EVM chains
   - Update event emissions

### Day 3-4: Test Updates
1. Update all test files to use SHA-256
2. Run full test suite: `FOUNDRY_PROFILE=default forge test -vvv`
3. Update gas snapshots
4. Fix any failing tests

### Day 5: Deployment Preparation
1. Deploy to Sepolia testnet
2. Verify contracts
3. Test with mock transactions

## Phase 2: Solana Program Development (Week 2)

### Day 1-2: Project Setup
```bash
# Initialize Anchor project
anchor init eth-sol-escrow --solana
cd eth-sol-escrow
anchor build
```

### Day 3-4: Core Implementation
1. Implement account structures:
   - `Escrow` account with order_hash, hashlock, etc.
   - `Timelocks` struct for time windows
   - `EscrowState` enum

2. Implement instructions:
   - `create_escrow` - Initialize with tokens and safety deposit
   - `withdraw` - Claim with SHA-256 verified secret
   - `cancel` - Refund after timeout

### Day 5: Testing
1. Write comprehensive tests
2. Test on local validator
3. Deploy to devnet

## Phase 3: CLI Tool Development (Week 3)

### Day 1-2: Core Structure
```bash
# Setup Deno project
mkdir eth-sol-swap-cli
cd eth-sol-swap-cli

# Create main files
touch main.ts
touch deno.json
```

### Day 3-4: Implementation
1. Implement SwapCoordinator class
2. Add monitoring system
3. Create CLI commands (create, fill, monitor, withdraw)
4. Integrate with Deno KV for state persistence

### Day 5: Integration Testing
1. Test full swap flow on testnets
2. Handle edge cases
3. Add comprehensive error handling

## Phase 4: Integration and Testing (Week 4)

### Day 1-2: End-to-End Testing
1. Deploy all components to testnets
2. Run multiple test swaps
3. Test failure scenarios

### Day 3-4: Security Audit
1. Review all time window logic
2. Verify secret handling
3. Test edge cases and attack vectors

### Day 5: Documentation
1. Create user guide
2. Document API endpoints
3. Create troubleshooting guide

## Critical Implementation Details

### 1. Hash Algorithm
- **MUST use SHA-256** (not Keccak-256)
- Solana: `solana_program::hash::hashv`
- Ethereum: `sha256(abi.encode(secret))`

### 2. Address Handling
- Ethereum: 20-byte addresses
- Solana: 32-byte addresses
- Solution: `dstRecipient` field in `ExtraDataArgs`

### 3. Time Windows
```
Source (Ethereum):
|--Deploy--|--Withdrawal Period--|--Cancel Period--|
0          srcWithdrawal         srcCancellation

Destination (Solana):
|--Deploy--|--Withdrawal Period--|--Cancel Period--|
0          dstWithdrawal         dstCancellation

Critical: dstCancellation > srcCancellation
```

### 4. Secret Management
- 32-byte secrets only
- Never log or store plaintext
- Same secret unlocks both chains

### 5. Non-EVM Chain Flag
```javascript
// Set MSB for non-EVM chains
const NON_EVM_FLAG = 1n << 255n;
const dstChainId = NON_EVM_FLAG | SOLANA_CHAIN_ID;
```

## Testing Checklist

### Ethereum Tests
- [ ] SHA-256 hash verification
- [ ] Non-EVM address validation
- [ ] Time window enforcement
- [ ] Gas optimization tests

### Solana Tests
- [ ] Escrow creation
- [ ] Secret verification
- [ ] Timeout handling
- [ ] Account closure

### Integration Tests
- [ ] Full ETH → SOL swap
- [ ] Full SOL → ETH swap
- [ ] Timeout and refund
- [ ] Concurrent swaps

## Security Checklist

1. **Time Safety**
   - [ ] Destination timeout > Source timeout
   - [ ] Buffer for cross-chain latency
   - [ ] Clock drift handling

2. **Secret Security**
   - [ ] 32-byte entropy
   - [ ] Secure generation
   - [ ] No plaintext storage

3. **Address Validation**
   - [ ] Non-zero check for non-EVM
   - [ ] Proper encoding/decoding
   - [ ] Event emission verification

4. **Economic Security**
   - [ ] Safety deposits sufficient
   - [ ] Incentive alignment
   - [ ] Griefing protection

## Launch Checklist

### Pre-Launch
- [ ] All tests passing
- [ ] Security audit complete
- [ ] Documentation ready
- [ ] Monitoring setup

### Launch
- [ ] Deploy Ethereum contracts
- [ ] Deploy Solana program
- [ ] Release CLI tool
- [ ] Monitor first swaps

### Post-Launch
- [ ] Monitor for issues
- [ ] Gather user feedback
- [ ] Plan improvements

## Common Pitfalls to Avoid

1. **DO NOT use Keccak-256** - Solana support unreliable
2. **DO NOT allow zero addresses** for non-EVM destinations
3. **DO NOT set source timeout > destination timeout**
4. **DO NOT trust user input** without validation
5. **DO NOT deploy without comprehensive testing**

## Success Metrics

1. **Functionality**: Swaps complete atomically
2. **Reliability**: 99.9% success rate
3. **Performance**: < 5 minute total swap time
4. **Security**: Zero funds lost
5. **Usability**: Clear error messages

## Next Steps After Implementation

1. **Mainnet Deployment**
   - Gradual rollout with limits
   - Monitor closely
   - Have emergency pause ready

2. **Enhancements**
   - Add more token pairs
   - Implement meta transactions
   - Add cooperative cancellation
   - Build web interface

3. **Expansion**
   - Support more chains
   - Add liquidity pools
   - Integrate with DEXs

This roadmap provides a clear path from current state to production-ready ETH-Solana atomic swaps. Follow each phase carefully and test thoroughly at every step.