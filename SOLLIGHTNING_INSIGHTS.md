# SolLightning Program Insights for ETH-Solana Atomic Swaps

## Overview
The SolLightning program is a Bitcoin-Solana atomic swap implementation that provides valuable patterns and insights for our ETH-Solana atomic swap design. This document captures the key learnings.

## Key Architecture Insights

### 1. Hash Algorithm
**They use SHA-256 for HTLC verification**:
```rust
// In check_claim_htlc function
let hash_result = hash::hash(&secret[..32]).to_bytes();
```
This confirms our decision to switch to SHA-256 for better cross-chain compatibility.

### 2. Swap Types
The program supports multiple swap types:
```rust
pub enum SwapType {
    Htlc = 0,        // Hash Time Locked Contract (standard atomic swap)
    Chain = 1,       // Bitcoin transaction proof via BTCRelay
    ChainNonced = 2, // Bitcoin tx proof with nonce for uniqueness
    ChainTxhash = 3  // Bitcoin tx hash verification
}
```

For ETH-Solana, we only need the HTLC type.

### 3. Account Structure Design

#### EscrowState (Main swap contract):
```rust
pub struct EscrowState {
    pub data: SwapData,
    pub offerer: Pubkey,      // Party offering tokens
    pub offerer_ata: Pubkey,  // Token account (empty for internal)
    pub claimer: Pubkey,      // Party claiming tokens
    pub claimer_ata: Pubkey,  // Token account (ignored for internal)
    pub mint: Pubkey,         // Token mint
    pub claimer_bounty: u64,  // Incentive for watchtowers
    pub security_deposit: u64 // Compensation for failed swaps
}
```

#### SwapData Structure:
```rust
pub struct SwapData {
    pub kind: SwapType,
    pub confirmations: u16,
    pub nonce: u64,
    pub hash: [u8; 32],      // Payment hash for HTLC
    pub pay_in: bool,        // External deposit
    pub pay_out: bool,       // External withdrawal
    pub amount: u64,
    pub expiry: u64,         // Unix timestamp or blockheight
    pub sequence: u64        // Unique identifier
}
```

### 4. Meta Transactions Pattern
**Brilliant design for gas optimization**:
- Offerer signs initialization message off-chain
- Claimer pays transaction fees to create the escrow
- This incentivizes timely completion

We could adapt this for ETH-Solana:
- Maker signs order (already done)
- Resolver pays Solana fees (good incentive alignment)

### 5. Time Handling

**Dual Time Support**:
```rust
const BLOCKHEIGHT_EXPIRY_THRESHOLD: u64 = 1000000000;

// In verify_timeout:
if escrow_state.data.expiry < BLOCKHEIGHT_EXPIRY_THRESHOLD {
    // Expiry is bitcoin blockheight
    verify_blockheight_ix(&ix, escrow_state.data.expiry);
} else {
    // Expiry is UNIX timestamp
    require!(escrow_state.data.expiry < now_ts()?);
}
```

For ETH-Solana, we should use Unix timestamps on both chains.

### 6. Security Deposits and Bounties

**Two-tier incentive system**:
1. **Security Deposit**: Paid by claimer, goes to offerer if swap fails
2. **Claimer Bounty**: Incentive for watchtowers to claim swaps

Key insight:
```rust
// Only need max(security_deposit, claimer_bounty) in escrow
// because only one can be paid out
let required_lamports = cmp::max(security_deposit, claimer_bounty);
```

### 7. Cooperative Cancellation

**Elegant signature-based refunds**:
```rust
// Claimer can sign a "refund" message for early cooperative close
let mut msg = Vec::with_capacity(6+8+8+8+32+8);
msg.extend_from_slice(b"refund");
msg.extend_from_slice(&escrow_state.data.amount.to_le_bytes());
msg.extend_from_slice(&escrow_state.data.expiry.to_le_bytes());
// ... other fields
```

This allows friendly cancellation without waiting for timeout.

### 8. PDA Seeds Pattern

```rust
const AUTHORITY_SEED: &[u8] = b"authority";
const USER_DATA_SEED: &[u8] = b"uservault";

// For escrow PDA, they likely use:
// [b"escrow", offerer.key, sequence]
```

### 9. Claim Verification Flow

**Clean separation of concerns**:
1. `process_claim` - Main entry point
2. `check_claim` - Routes to appropriate verification
3. `check_claim_htlc` - Verifies SHA-256 hash
4. Event emission with secret revealed

### 10. Account Closure Pattern

**Efficient lamport recovery**:
```rust
// Transfer all lamports to recipient
let mut acc_balance = escrow_state.to_account_info().try_borrow_mut_lamports()?;
let balance: u64 = **acc_balance;
**acc_balance = 0;

// Reassign to system program and reallocate to 0
escrow_state.to_account_info().assign(&system_program::ID);
escrow_state.to_account_info().realloc(0, false).unwrap();
```

## Patterns to Adopt for ETH-Solana

### 1. Internal Balance System
They use a `UserAccount` PDA to track internal balances:
- Reduces transaction costs
- Enables batch operations
- Tracks reputation on-chain

For our MVP, we can skip this but it's good for production.

### 2. Ed25519 Signature Verification
Used for meta transactions and cooperative cancellation:
- Offchain message signing
- On-chain verification via Ed25519 program
- Gas-efficient authorization

### 3. Flexible Payment Routes
```rust
pub pay_in: bool,   // Deposit from external
pub pay_out: bool,  // Withdraw to external
```
This allows four combinations:
- External → External (full atomic swap)
- External → Internal (deposit + swap)
- Internal → External (swap + withdraw)
- Internal → Internal (internal swap)

### 4. Reputation Tracking
```rust
pub struct UserAccount {
    pub success_volume: [u64; SWAP_TYPE_COUNT],
    pub success_count: [u64; SWAP_TYPE_COUNT],
    pub fail_volume: [u64; SWAP_TYPE_COUNT],
    pub fail_count: [u64; SWAP_TYPE_COUNT],
    pub coop_close_volume: [u64; SWAP_TYPE_COUNT],
    pub coop_close_count: [u64; SWAP_TYPE_COUNT],
}
```

## Implementation Recommendations

### 1. Escrow Account Structure
```rust
#[account]
pub struct EthSolEscrow {
    pub order_hash: [u8; 32],
    pub hashlock: [u8; 32],    // SHA-256 hash
    pub maker: Pubkey,          // Recipient on Solana
    pub taker: Pubkey,          // Resolver
    pub token_mint: Pubkey,
    pub amount: u64,
    pub safety_deposit: u64,
    pub expiry: i64,            // Unix timestamp
    pub withdrawal_start: i64,   // When withdrawal allowed
    pub state: EscrowState,
    pub bump: u8,
}
```

### 2. State Machine
```rust
pub enum EscrowState {
    Active,
    Withdrawn,
    Cancelled,
}
```

### 3. Time Validation
Always use Unix timestamps for cross-chain compatibility:
```rust
let clock = Clock::get()?;
require!(
    clock.unix_timestamp >= self.withdrawal_start,
    ErrorCode::TooEarly
);
require!(
    clock.unix_timestamp < self.expiry,
    ErrorCode::TooLate
);
```

### 4. Secret Size
They use 32-byte secrets consistently, which aligns with our design.

### 5. Event Structure
```rust
#[event]
pub struct WithdrawEvent {
    pub order_hash: [u8; 32],
    pub secret: [u8; 32],
    pub recipient: Pubkey,
}
```

## Security Considerations from Their Design

1. **No Reentrancy**: Anchor's account constraints prevent this
2. **Time Buffer**: They use BTCRelay with safety buffer for blockheight
3. **Signature Verification**: Rigorous checks on Ed25519 instructions
4. **Account Validation**: Explicit writability checks
5. **Overflow Protection**: Using saturating_add for reputation

## Differences from Our Design

1. **Bitcoin Specific**: Much complexity for Bitcoin verification we don't need
2. **Internal Balances**: We use direct transfers, simpler for MVP
3. **Multiple Swap Types**: We only need HTLC
4. **BTCRelay Integration**: Not needed for Ethereum

## Key Takeaways

1. **SHA-256 is the right choice** - Confirmed by their implementation
2. **Meta transactions are powerful** - Consider for V2
3. **Security deposits work well** - Already in our design
4. **Cooperative cancellation is valuable** - Consider adding
5. **Unix timestamps are standard** - Stick with this
6. **32-byte secrets are standard** - Maintain compatibility
7. **PDA patterns are clean** - Use order hash as seed
8. **Event emission is crucial** - For monitoring

This implementation validates many of our design choices and provides excellent patterns for the Solana side of our atomic swap system.