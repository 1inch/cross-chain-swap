# ETH-Solana Atomic Swap Quick Reference

## Critical Constants
```javascript
// Solana Chain ID with non-EVM flag
const SOLANA_CHAIN_ID = 1399811149n;
const NON_EVM_FLAG = 1n << 255n;
const DST_CHAIN_ID = NON_EVM_FLAG | SOLANA_CHAIN_ID;
```

## Hash Functions
```solidity
// Ethereum (Solidity)
function _sha256Bytes32(bytes32 secret) private pure returns (bytes32) {
    return sha256(abi.encode(secret));
}
```

```rust
// Solana (Rust)
use solana_program::hash::hashv;
let secret_hash = hashv(&[&secret]);
```

## Key Structures

### Ethereum - ExtraDataArgs
```solidity
struct ExtraDataArgs {
    bytes32 hashlockInfo;
    uint256 dstChainId;      // MSB = non-EVM flag
    Address dstToken;
    uint256 deposits;
    Timelocks timelocks;
    bytes32 dstRecipient;    // NEW: 32-byte Solana address
}
```

### Solana - Escrow Account
```rust
#[account]
pub struct Escrow {
    pub order_hash: [u8; 32],
    pub hashlock: [u8; 32],
    pub maker: Pubkey,
    pub taker: Pubkey,
    pub token_mint: Pubkey,
    pub amount: u64,
    pub safety_deposit: u64,
    pub deployment_time: i64,
    pub timelocks: Timelocks,
    pub state: EscrowState,
    pub bump: u8,
}
```

## Time Windows
```
ETH:  |--Deploy--|--Withdraw(1h)--|--Cancel(2h)--|
SOL:  |--Deploy--|--Withdraw(1h)--|--------Cancel(24h)--------|
```

## CLI Commands
```bash
# Create swap
deno run --allow-all main.ts create \
  --eth-amount 1.0 \
  --sol-amount 50.0 \
  --sol-recipient <SOLANA_ADDRESS>

# Monitor
deno run --allow-all main.ts monitor --watch

# Withdraw
deno run --allow-all main.ts withdraw \
  --order-id <ORDER_ID> \
  --secret <SECRET>
```

## Test Command
```bash
FOUNDRY_PROFILE=default forge test -vvv
```

## Key Files
- `CLAUDE.md` - Solidity changes
- `SOLANA_IMPLEMENTATION.md` - Anchor program
- `CLI_TOOL_DESIGN.md` - CLI tool
- `IMPLEMENTATION_ROADMAP.md` - Development plan

## Remember
1. **Use SHA-256, NOT Keccak-256**
2. **dstRecipient for 32-byte Solana addresses**
3. **dstCancellation > srcCancellation**
4. **32-byte secrets only**
5. **Never log secrets**