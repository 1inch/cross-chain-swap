# Solana Anchor Program Implementation

## Overview
This document specifies the Solana side of the ETH-Solana atomic swap implementation using Anchor framework.

## Program Structure

### 1. Account Structures

```rust
use anchor_lang::prelude::*;
use anchor_lang::solana_program::hash::hashv;

#[account]
pub struct Escrow {
    /// Matches the orderHash from Ethereum
    pub order_hash: [u8; 32],
    
    /// SHA-256 hash of the secret
    pub hashlock: [u8; 32],
    
    /// Recipient of tokens on Solana (32-byte Pubkey)
    pub maker: Pubkey,
    
    /// Resolver's Solana address
    pub taker: Pubkey,
    
    /// SPL Token mint (use system program pubkey for native SOL)
    pub token_mint: Pubkey,
    
    /// Amount in smallest units (lamports for SOL)
    pub amount: u64,
    
    /// Safety deposit in SOL (lamports)
    pub safety_deposit: u64,
    
    /// Unix timestamp when escrow was created
    pub deployment_time: i64,
    
    /// Time windows for operations
    pub timelocks: Timelocks,
    
    /// Current state of the escrow
    pub state: EscrowState,
    
    /// Bump seed for PDA
    pub bump: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy)]
pub struct Timelocks {
    /// When maker can withdraw (relative to deployment_time)
    pub dst_withdrawal: i64,
    
    /// When taker can cancel (relative to deployment_time)
    pub dst_cancellation: i64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, PartialEq)]
pub enum EscrowState {
    Active,
    Withdrawn,
    Cancelled,
}
```

### 2. Instructions

#### Create Escrow
```rust
#[derive(Accounts)]
pub struct CreateEscrow<'info> {
    #[account(mut)]
    pub taker: Signer<'info>,
    
    #[account(
        init,
        payer = taker,
        space = 8 + 32 + 32 + 32 + 32 + 32 + 8 + 8 + 8 + 16 + 1 + 1,
        seeds = [b"escrow", order_hash.as_ref()],
        bump
    )]
    pub escrow: Account<'info, Escrow>,
    
    /// CHECK: Maker pubkey from Ethereum order
    pub maker: UncheckedAccount<'info>,
    
    pub token_mint: Account<'info, Mint>,
    
    #[account(
        mut,
        constraint = taker_token_account.owner == taker.key(),
        constraint = taker_token_account.mint == token_mint.key()
    )]
    pub taker_token_account: Account<'info, TokenAccount>,
    
    #[account(
        init_if_needed,
        payer = taker,
        associated_token::mint = token_mint,
        associated_token::authority = escrow
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,
    
    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub associated_token_program: Program<'info, AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

pub fn create_escrow(
    ctx: Context<CreateEscrow>,
    order_hash: [u8; 32],
    hashlock: [u8; 32],
    amount: u64,
    safety_deposit: u64,
    timelocks: Timelocks,
) -> Result<()> {
    let escrow = &mut ctx.accounts.escrow;
    let clock = Clock::get()?;
    
    // Initialize escrow
    escrow.order_hash = order_hash;
    escrow.hashlock = hashlock;
    escrow.maker = ctx.accounts.maker.key();
    escrow.taker = ctx.accounts.taker.key();
    escrow.token_mint = ctx.accounts.token_mint.key();
    escrow.amount = amount;
    escrow.safety_deposit = safety_deposit;
    escrow.deployment_time = clock.unix_timestamp;
    escrow.timelocks = timelocks;
    escrow.state = EscrowState::Active;
    escrow.bump = *ctx.bumps.get("escrow").unwrap();
    
    // Transfer tokens to escrow
    transfer(
        CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.taker_token_account.to_account_info(),
                to: ctx.accounts.escrow_token_account.to_account_info(),
                authority: ctx.accounts.taker.to_account_info(),
            },
        ),
        amount,
    )?;
    
    // Transfer safety deposit (in SOL)
    invoke(
        &system_instruction::transfer(
            &ctx.accounts.taker.key(),
            &escrow.key(),
            safety_deposit,
        ),
        &[
            ctx.accounts.taker.to_account_info(),
            escrow.to_account_info(),
            ctx.accounts.system_program.to_account_info(),
        ],
    )?;
    
    Ok(())
}
```

#### Withdraw (with secret)
```rust
#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub maker: Signer<'info>,
    
    #[account(
        mut,
        seeds = [b"escrow", escrow.order_hash.as_ref()],
        bump = escrow.bump,
        constraint = escrow.state == EscrowState::Active,
        constraint = escrow.maker == maker.key()
    )]
    pub escrow: Account<'info, Escrow>,
    
    #[account(
        mut,
        constraint = escrow_token_account.owner == escrow.key()
    )]
    pub escrow_token_account: Account<'info, TokenAccount>,
    
    #[account(
        mut,
        constraint = maker_token_account.owner == maker.key()
    )]
    pub maker_token_account: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
}

pub fn withdraw(ctx: Context<Withdraw>, secret: [u8; 32]) -> Result<()> {
    let escrow = &mut ctx.accounts.escrow;
    let clock = Clock::get()?;
    
    // Verify timing
    let current_time = clock.unix_timestamp;
    let withdrawal_start = escrow.deployment_time + escrow.timelocks.dst_withdrawal;
    let cancellation_time = escrow.deployment_time + escrow.timelocks.dst_cancellation;
    
    require!(
        current_time >= withdrawal_start,
        ErrorCode::TooEarly
    );
    require!(
        current_time < cancellation_time,
        ErrorCode::TooLate
    );
    
    // Verify secret using SHA-256
    let secret_hash = hashv(&[&secret]);
    require!(
        secret_hash.to_bytes() == escrow.hashlock,
        ErrorCode::InvalidSecret
    );
    
    // Transfer tokens to maker
    let seeds = &[
        b"escrow",
        escrow.order_hash.as_ref(),
        &[escrow.bump],
    ];
    let signer_seeds = &[&seeds[..]];
    
    transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.escrow_token_account.to_account_info(),
                to: ctx.accounts.maker_token_account.to_account_info(),
                authority: escrow.to_account_info(),
            },
            signer_seeds,
        ),
        escrow.amount,
    )?;
    
    // Mark as withdrawn
    escrow.state = EscrowState::Withdrawn;
    
    // Emit event (logs)
    msg!("Escrow withdrawn with secret: {:?}", secret);
    
    Ok(())
}
```

#### Cancel
```rust
pub fn cancel(ctx: Context<Cancel>) -> Result<()> {
    let escrow = &mut ctx.accounts.escrow;
    let clock = Clock::get()?;
    
    // Verify timing
    let current_time = clock.unix_timestamp;
    let cancellation_time = escrow.deployment_time + escrow.timelocks.dst_cancellation;
    
    require!(
        current_time >= cancellation_time,
        ErrorCode::TooEarly
    );
    
    // Return tokens to taker
    // ... (similar transfer logic)
    
    escrow.state = EscrowState::Cancelled;
    
    Ok(())
}
```

### 3. Error Codes
```rust
#[error_code]
pub enum ErrorCode {
    #[msg("Operation attempted too early")]
    TooEarly,
    
    #[msg("Operation attempted too late")]
    TooLate,
    
    #[msg("Invalid secret provided")]
    InvalidSecret,
    
    #[msg("Escrow is not active")]
    NotActive,
}
```

## Key Implementation Details

### 1. PDA Derivation
- Escrow accounts are PDAs derived from: `[b"escrow", order_hash]`
- This ensures deterministic addresses matching the Ethereum order

### 2. Time Handling
- Use Unix timestamps (i64) for cross-chain compatibility
- All timelocks are relative to deployment_time

### 3. Token Handling
- Support both SPL tokens and native SOL
- For SOL, use System Program transfers
- For SPL tokens, use Token Program

### 4. Secret Verification
- Use `solana_program::hash::hashv` for SHA-256
- Compare 32-byte arrays directly

### 5. Safety Deposits
- Always in SOL (not SPL tokens)
- Transferred to caller on successful withdrawal
- Returned to taker on cancellation

## Testing

### Local Testing
```bash
# Start local validator
solana-test-validator

# Build and deploy
anchor build
anchor deploy

# Run tests
anchor test
```

### Test Scenarios
1. Create escrow with SPL tokens
2. Create escrow with native SOL
3. Withdraw with correct secret
4. Fail withdrawal with wrong secret
5. Cancel after timeout
6. Fail operations outside time windows

## Security Considerations

1. **Reentrancy**: Anchor's account constraints prevent reentrancy
2. **Time Manipulation**: Rely on Solana's clock sysvar
3. **Authority Checks**: Enforce maker/taker signatures
4. **State Transitions**: Use enum to prevent invalid states

## Gas Optimization

1. Use bumps stored in account to avoid recalculation
2. Minimize account size (pack structs efficiently)
3. Use native SOL transfers when possible (cheaper than SPL)

## Deployment Checklist

1. Set correct program ID in Anchor.toml
2. Deploy to devnet first
3. Verify all PDAs derive correctly
4. Test with mainnet-beta fork
5. Audit time handling logic
6. Verify secret hash compatibility with Ethereum