# CLI Tool Design for ETH-Solana Atomic Swaps

## Overview
The CLI tool coordinates atomic swaps between Ethereum and Solana, managing the entire lifecycle from order creation to completion.

## Architecture

### Technology Stack
- **Language**: TypeScript/Node.js
- **Ethereum**: ethers.js v6
- **Solana**: @solana/web3.js, @project-serum/anchor
- **CLI Framework**: Commander.js
- **Storage**: LevelDB for local state persistence
- **Monitoring**: WebSocket connections to both chains

### Core Modules

```typescript
// Main structure
src/
├── cli.ts                 // CLI entry point
├── commands/             // CLI commands
│   ├── create.ts        // Create new swap
│   ├── fill.ts          // Fill as resolver
│   ├── withdraw.ts      // Withdraw with secret
│   ├── cancel.ts        // Cancel swap
│   └── monitor.ts       // Monitor active swaps
├── core/                // Core logic
│   ├── SwapCoordinator.ts
│   ├── EthereumClient.ts
│   ├── SolanaClient.ts
│   └── SecretManager.ts
├── types/               // Type definitions
├── utils/               // Utilities
└── config/              // Configuration

```

## Implementation Details

### 1. SwapCoordinator Class

```typescript
import { ethers } from 'ethers';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import { Program, AnchorProvider } from '@project-serum/anchor';

export class SwapCoordinator {
    private ethereumProvider: ethers.Provider;
    private solanaConnection: Connection;
    private db: Level;
    
    constructor(config: SwapConfig) {
        this.ethereumProvider = new ethers.JsonRpcProvider(config.ethereumRpc);
        this.solanaConnection = new Connection(config.solanaRpc);
        this.db = new Level('./swap-state');
    }
    
    async createSwap(params: CreateSwapParams): Promise<SwapOrder> {
        // 1. Validate parameters
        this.validateSwapParams(params);
        
        // 2. Generate secret and hashlock
        const secret = this.generateSecret();
        const hashlock = ethers.sha256(ethers.AbiCoder.defaultAbiCoder().encode(['bytes32'], [secret]));
        
        // 3. Encode Solana recipient address
        const solanaRecipient = this.encodeSolanaAddress(params.solanaRecipient);
        
        // 4. Create order structure
        const order = {
            salt: ethers.randomBytes(32),
            maker: params.ethereumMaker,
            receiver: ethers.ZeroAddress, // Must be zero for non-EVM
            makerAsset: params.sourceToken,
            takerAsset: DUMMY_TOKEN,
            makingAmount: params.sourceAmount,
            takingAmount: params.destAmount,
            makerTraits: this.encodeMakerTraits(params),
        };
        
        // 5. Create ExtraDataArgs with Solana recipient
        const extraDataArgs = {
            hashlockInfo: hashlock,
            dstChainId: this.encodeSolanaChainId(),
            dstToken: ethers.ZeroAddress, // Not used for Solana
            deposits: this.encodeDeposits(params.srcDeposit, params.dstDeposit),
            timelocks: params.timelocks,
            dstRecipient: solanaRecipient, // 32-byte Solana address
        };
        
        // 6. Sign order
        const signedOrder = await this.signOrder(order, extraDataArgs);
        
        // 7. Store swap state
        await this.saveSwapState({
            orderId: this.computeOrderId(order),
            order: signedOrder,
            secret,
            hashlock,
            solanaRecipient: params.solanaRecipient,
            state: 'created',
            createdAt: Date.now(),
        });
        
        return signedOrder;
    }
    
    async fillSwap(orderId: string, resolverKeys: ResolverKeys): Promise<void> {
        const swap = await this.loadSwapState(orderId);
        
        // 1. Fill on Ethereum (creates EscrowSrc)
        console.log('Filling order on Ethereum...');
        const ethTx = await this.fillEthereumOrder(swap.order, resolverKeys.ethereum);
        await ethTx.wait();
        
        // 2. Extract events and get escrow details
        const escrowAddress = await this.getEscrowAddress(ethTx);
        
        // 3. Create matching escrow on Solana
        console.log('Creating escrow on Solana...');
        const solanaTx = await this.createSolanaEscrow({
            orderHash: swap.orderId,
            hashlock: swap.hashlock,
            maker: new PublicKey(swap.solanaRecipient),
            amount: swap.order.takingAmount,
            safetyDeposit: swap.dstDeposit,
            timelocks: swap.timelocks,
        }, resolverKeys.solana);
        
        // 4. Update state
        await this.updateSwapState(orderId, {
            state: 'filled',
            ethereumEscrow: escrowAddress,
            solanaTx,
            filledAt: Date.now(),
        });
        
        // 5. Start monitoring
        this.startMonitoring(orderId);
    }
    
    async withdrawWithSecret(orderId: string, secret: string): Promise<void> {
        const swap = await this.loadSwapState(orderId);
        
        // Verify secret
        const hashlock = ethers.sha256(ethers.AbiCoder.defaultAbiCoder().encode(['bytes32'], [secret]));
        if (hashlock !== swap.hashlock) {
            throw new Error('Invalid secret');
        }
        
        // Withdraw on both chains
        await Promise.all([
            this.withdrawEthereum(swap, secret),
            this.withdrawSolana(swap, secret),
        ]);
        
        await this.updateSwapState(orderId, {
            state: 'completed',
            completedAt: Date.now(),
        });
    }
    
    private encodeSolanaAddress(address: string): string {
        const pubkey = new PublicKey(address);
        return '0x' + pubkey.toBuffer().toString('hex');
    }
    
    private encodeSolanaChainId(): bigint {
        const SOLANA_CHAIN_ID = 1399811149n;
        const NON_EVM_FLAG = 1n << 255n;
        return NON_EVM_FLAG | SOLANA_CHAIN_ID;
    }
    
    private generateSecret(): string {
        return '0x' + ethers.randomBytes(32).toString('hex');
    }
}
```

### 2. Monitoring System

```typescript
export class SwapMonitor {
    private ethereumWatcher: ethers.WebSocketProvider;
    private solanaWatcher: Connection;
    
    async startMonitoring(swapId: string): Promise<void> {
        const swap = await this.loadSwapState(swapId);
        
        // Monitor Ethereum events
        this.monitorEthereum(swap);
        
        // Monitor Solana transactions
        this.monitorSolana(swap);
        
        // Check timeouts
        this.monitorTimeouts(swap);
    }
    
    private async monitorEthereum(swap: SwapState): Promise<void> {
        const escrowContract = new ethers.Contract(
            swap.ethereumEscrow,
            ESCROW_ABI,
            this.ethereumWatcher
        );
        
        // Listen for withdrawal events
        escrowContract.on('EscrowWithdrawal', async (secret) => {
            console.log('Secret revealed on Ethereum:', secret);
            await this.handleSecretRevealed(swap, secret);
        });
        
        // Listen for cancellation
        escrowContract.on('EscrowCancelled', async () => {
            console.log('Escrow cancelled on Ethereum');
            await this.handleCancellation(swap, 'ethereum');
        });
    }
    
    private async monitorSolana(swap: SwapState): Promise<void> {
        const escrowPubkey = await this.deriveSolanaEscrowPDA(swap.orderId);
        
        // Subscribe to account changes
        this.solanaWatcher.onAccountChange(
            escrowPubkey,
            async (accountInfo) => {
                const escrow = await this.parseEscrowAccount(accountInfo);
                
                if (escrow.state === 'Withdrawn') {
                    // Extract secret from transaction logs
                    const secret = await this.extractSecretFromSolana(escrowPubkey);
                    await this.handleSecretRevealed(swap, secret);
                } else if (escrow.state === 'Cancelled') {
                    await this.handleCancellation(swap, 'solana');
                }
            }
        );
    }
    
    private async handleSecretRevealed(swap: SwapState, secret: string): Promise<void> {
        console.log('Secret revealed! Completing swap...');
        
        // If we're the resolver, withdraw on the other chain
        if (swap.role === 'resolver') {
            if (swap.secretRevealedOn === 'ethereum') {
                await this.withdrawSolana(swap, secret);
            } else {
                await this.withdrawEthereum(swap, secret);
            }
        }
        
        // Update state
        await this.updateSwapState(swap.id, {
            secret,
            secretRevealedAt: Date.now(),
            state: 'secret_revealed',
        });
    }
}
```

### 3. CLI Commands

```typescript
// create.ts
export const createCommand = new Command('create')
    .description('Create a new ETH to Solana swap')
    .requiredOption('--eth-amount <amount>', 'Amount of ETH to swap')
    .requiredOption('--sol-amount <amount>', 'Amount of SOL to receive')
    .requiredOption('--sol-recipient <address>', 'Solana recipient address')
    .requiredOption('--eth-key <key>', 'Ethereum private key')
    .option('--timeout <hours>', 'Swap timeout in hours', '24')
    .action(async (options) => {
        const coordinator = new SwapCoordinator(config);
        
        const swap = await coordinator.createSwap({
            ethereumMaker: deriveAddress(options.ethKey),
            sourceToken: WETH_ADDRESS,
            sourceAmount: ethers.parseEther(options.ethAmount),
            destAmount: parseFloat(options.solAmount) * LAMPORTS_PER_SOL,
            solanaRecipient: options.solRecipient,
            timelocks: calculateTimelocks(options.timeout),
            srcDeposit: ethers.parseEther('0.1'),
            dstDeposit: 0.1 * LAMPORTS_PER_SOL,
        });
        
        console.log('Swap created!');
        console.log('Order ID:', swap.orderId);
        console.log('Share this with the resolver to fill the swap');
    });

// monitor.ts
export const monitorCommand = new Command('monitor')
    .description('Monitor active swaps')
    .option('--watch', 'Continuously watch for updates')
    .action(async (options) => {
        const coordinator = new SwapCoordinator(config);
        const swaps = await coordinator.getActiveSwaps();
        
        if (options.watch) {
            // Real-time monitoring
            for (const swap of swaps) {
                coordinator.startMonitoring(swap.id);
            }
            
            // Keep process alive
            setInterval(() => {
                console.log('Monitoring', swaps.length, 'active swaps...');
            }, 10000);
        } else {
            // One-time status check
            console.table(swaps.map(s => ({
                id: s.id.slice(0, 8) + '...',
                state: s.state,
                created: new Date(s.createdAt).toLocaleString(),
                ethAmount: ethers.formatEther(s.order.makingAmount),
                solAmount: s.order.takingAmount / LAMPORTS_PER_SOL,
            })));
        }
    });
```

### 4. Configuration

```typescript
// config/index.ts
export interface SwapConfig {
    ethereumRpc: string;
    solanaRpc: string;
    ethereumChainId: number;
    contracts: {
        limitOrderProtocol: string;
        escrowFactory: string;
    };
    solanaProgram: {
        programId: string;
        idl: any;
    };
}

// Load from environment
export const config: SwapConfig = {
    ethereumRpc: process.env.ETH_RPC || 'http://localhost:8545',
    solanaRpc: process.env.SOLANA_RPC || 'http://localhost:8899',
    ethereumChainId: parseInt(process.env.ETH_CHAIN_ID || '1'),
    contracts: {
        limitOrderProtocol: process.env.LIMIT_ORDER_PROTOCOL || '0x...',
        escrowFactory: process.env.ESCROW_FACTORY || '0x...',
    },
    solanaProgram: {
        programId: process.env.SOLANA_PROGRAM_ID || '...',
        idl: require('./idl.json'),
    },
};
```

## Usage Examples

```bash
# Create a swap (as maker)
eth-sol-swap create \
    --eth-amount 1.0 \
    --sol-amount 50.0 \
    --sol-recipient 8HjcrJkGHfq1rq4BLKL9LGpHE2o6qYdGk7mRzCF6YKBg \
    --eth-key $PRIVATE_KEY

# Fill a swap (as resolver)
eth-sol-swap fill \
    --order-id 0x123... \
    --eth-key $RESOLVER_ETH_KEY \
    --sol-key $RESOLVER_SOL_KEY

# Monitor swaps
eth-sol-swap monitor --watch

# Withdraw with secret
eth-sol-swap withdraw \
    --order-id 0x123... \
    --secret 0xabc...

# Cancel expired swap
eth-sol-swap cancel --order-id 0x123...
```

## Error Handling

1. **Network Failures**: Automatic retry with exponential backoff
2. **Transaction Failures**: Detailed error messages with recovery suggestions
3. **Time Synchronization**: Warning if system time differs significantly
4. **State Corruption**: Backup and recovery mechanisms

## Security Considerations

1. **Private Key Management**: 
   - Never store keys in config files
   - Support hardware wallets
   - Encrypt local storage

2. **Secret Protection**:
   - Generate cryptographically secure secrets
   - Clear from memory after use
   - Never log secrets

3. **Transaction Verification**:
   - Verify all amounts and addresses
   - Check chain IDs
   - Confirm transaction success

## Testing Strategy

1. **Unit Tests**: Test each module independently
2. **Integration Tests**: Test full swap flows on testnets
3. **Stress Tests**: Handle multiple concurrent swaps
4. **Failure Tests**: Simulate network issues, timeouts

## Deployment

1. Build: `npm run build`
2. Package: `npm pack`
3. Install globally: `npm install -g eth-sol-swap`
4. Configure: Set environment variables
5. Test on testnet first

## Future Enhancements

1. GUI interface
2. Mobile app support
3. Multi-signature support
4. Batch swap operations
5. Advanced routing algorithms