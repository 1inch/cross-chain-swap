# ETH-Solana Atomic Swap Complete Flow

## Critical Summary

### Hash Algorithm Change
- **MUST change from Keccak-256 to SHA-256**
- Solana's `sol_keccak256` is unreliable with unresolved symbol errors
- Both chains support SHA-256 natively and reliably
- Update all tests to use SHA-256

### Address Handling
- Solana addresses: 32 bytes (Base58 encoded like `8HjcrJkGHfq1rq4BLKL9LGpHE2o6qYdGk7mRzCF6YKBg`)
- Ethereum addresses: 20 bytes (hex encoded like `0x742d35Cc6634C0532925a3b844Bc9e7595f06E0`)
- Solution: Add `dstRecipient` field (bytes32) to ExtraDataArgs for non-EVM addresses

### Non-EVM Flag
- MSB (bit 255) of `dstChainId`: 1 = non-EVM, 0 = EVM
- Actual chain ID uses lower 255 bits
- Solana chain ID: 1399811149
- With flag: `0x8000000000000000000000000000000000000000000000000000000537A8C2D`

## Complete Swap Flow

### Phase 1: Order Creation (Maker)
1. **User Action**: Wants to swap 1 ETH for 50 SOL
2. **CLI generates**:
   - 32-byte secret
   - SHA-256 hashlock = `sha256(abi.encode(secret))`
3. **Order structure**:
   ```javascript
   {
     maker: "0xEthereumUserAddress",
     receiver: "0x0000...0000", // MUST be zero for non-EVM
     makerAsset: "0xWETH_ADDRESS",
     takingAmount: "50000000000", // 50 SOL in lamports
     // ... other fields
   }
   ```
4. **ExtraDataArgs**:
   ```javascript
   {
     hashlockInfo: hashlock,
     dstChainId: 0x8000000000...537A8C2D, // Non-EVM flag + Solana ID
     dstRecipient: "0x" + base58ToHex(solanaAddress), // 32 bytes
     deposits: srcDeposit << 128 | dstDeposit,
     timelocks: { /* time windows */ }
   }
   ```
5. **Sign with EIP-712**
6. **Share order with resolver**

### Phase 2: Order Filling (Resolver)

#### 2.1 Ethereum Side
1. Resolver calls LimitOrderProtocol.fillOrder()
2. EscrowFactory.postInteraction() is triggered
3. Contract validates non-EVM recipient is not zero
4. EscrowSrc is deployed with:
   - Maker's ETH locked
   - SHA-256 hashlock stored
   - Time windows activated
5. Event emitted with Solana recipient in dstRecipient

#### 2.2 Solana Side
1. Resolver detects Ethereum escrow creation
2. Creates matching Solana escrow:
   - PDA: `[b"escrow", orderHash]`
   - 50 SOL locked
   - Same SHA-256 hashlock
   - Maker = decoded Solana address from dstRecipient
3. Escrow active on both chains

### Phase 3: Secret Revelation

#### Option A: Maker Withdraws First (Solana)
1. Maker calls `withdraw(secret)` on Solana
2. Solana verifies: `sha256(&[&secret]) == hashlock`
3. Maker receives 50 SOL
4. CLI detects secret from Solana logs
5. Resolver uses same secret on Ethereum
6. Resolver receives 1 ETH

#### Option B: Resolver Withdraws First (Ethereum)
1. Resolver calls `withdrawTo(secret, recipient)` on Ethereum
2. Ethereum verifies: `sha256(abi.encode(secret)) == hashlock`
3. Resolver receives 1 ETH
4. CLI detects secret from Ethereum events
5. Maker uses same secret on Solana
6. Maker receives 50 SOL

### Phase 4: Failure Scenarios

#### Timeout Without Secret
1. If no withdrawal before timeout:
   - Ethereum: Maker can cancel after `srcCancellation`
   - Solana: Resolver can cancel after `dstCancellation`
2. Funds returned to original owners
3. Safety deposits returned

#### Partial Failure
- If secret revealed on one chain but withdrawal fails on other:
- Use rescued secret to complete on remaining chain
- If impossible, use rescue function after delay

## Time Window Design

```
Ethereum (Source):
|----Deployment----|----Withdrawal Period----|----Cancel Period----|
0                  srcWithdrawal            srcCancellation

Solana (Destination):
|----Deployment----|----Withdrawal Period----|----Cancel Period----|
0                  dstWithdrawal            dstCancellation

Critical: dstCancellation > srcCancellation (prevents resolver griefing)
```

## Security Model

1. **Atomicity**: Same secret unlocks both sides
2. **Time Safety**: Destination timeout > Source timeout
3. **No Trust Required**: Cryptographic guarantees
4. **Incentive Alignment**: Safety deposits ensure good behavior

## Implementation Checklist

### Ethereum Changes
- [ ] Add `dstRecipient` field to ExtraDataArgs
- [ ] Change `_keccakBytes32` to `_sha256Bytes32`
- [ ] Update secret validation to use SHA-256
- [ ] Add validation for non-EVM recipients
- [ ] Update all tests to use SHA-256
- [ ] Deploy new factory contract

### Solana Program
- [ ] Implement Anchor program with SHA-256 verification
- [ ] Create PDA derivation from orderHash
- [ ] Implement withdraw/cancel with proper timeouts
- [ ] Add comprehensive error handling
- [ ] Deploy to devnet for testing

### CLI Tool
- [ ] Implement order creation with Solana address encoding
- [ ] Add cross-chain monitoring
- [ ] Handle secret extraction from both chains
- [ ] Implement automatic withdrawal coordination
- [ ] Add comprehensive error recovery

### Testing
- [ ] Unit test SHA-256 changes
- [ ] Integration test full swap flow
- [ ] Test all failure scenarios
- [ ] Stress test with multiple concurrent swaps
- [ ] Test on testnets (Sepolia + Devnet)

## Common Pitfalls to Avoid

1. **DO NOT** use Keccak-256 - Solana support is broken
2. **DO NOT** allow zero addresses for non-EVM destinations
3. **DO NOT** set source timeout > destination timeout
4. **DO NOT** store secrets in logs or databases
5. **DO NOT** trust block.timestamp without buffer time

## Success Criteria

A successful implementation will:
1. Complete swaps atomically without trust
2. Handle all failure cases gracefully
3. Work reliably on mainnet
4. Support both maker and resolver flows
5. Provide clear user feedback throughout

This is a complex but achievable system. The key is careful attention to the cross-chain coordination and robust error handling.