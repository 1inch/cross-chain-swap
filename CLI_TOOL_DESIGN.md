# CLI Tool Design for ETH-Solana Atomic Swaps

## Overview
The CLI tool coordinates atomic swaps between Ethereum and Solana, managing the entire lifecycle from order creation to completion.

## Architecture

### Technology Stack
- **Runtime**: Deno (TypeScript)
- **Ethereum**: viem
- **Solana**: @solana/web3.js, @project-serum/anchor
- **CLI Framework**: Deno's built-in CLI capabilities
- **Storage**: Deno KV for local state persistence
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
import { createPublicClient, createWalletClient, http, type PublicClient, type WalletClient } from 'viem';
import { mainnet } from 'viem/chains';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import { Program, AnchorProvider } from '@project-serum/anchor';

export class SwapCoordinator {
    private ethereumClient: PublicClient;
    private ethereumWallet: WalletClient;
    private solanaConnection: Connection;
    private db: Deno.Kv;
    
    constructor(config: SwapConfig) {
        this.ethereumClient = createPublicClient({
            chain: mainnet,
            transport: http(config.ethereumRpc)
        });
        this.ethereumWallet = createWalletClient({
            chain: mainnet,
            transport: http(config.ethereumRpc)
        });
        this.solanaConnection = new Connection(config.solanaRpc);
    }
    
    async init() {
        this.db = await Deno.openKv('./swap-state.db');
    }
    
    async createSwap(params: CreateSwapParams): Promise<SwapOrder> {
        // 1. Validate parameters
        this.validateSwapParams(params);
        
        // 2. Generate secret and hashlock
        const secret = this.generateSecret();
        const hashlock = keccak256(encodeAbiParameters(
            [{ type: 'bytes32' }],
            [secret as `0x${string}`]
        ));
        // Note: Will be updated to sha256 in contract changes
        
        // 3. Encode Solana recipient address
        const solanaRecipient = this.encodeSolanaAddress(params.solanaRecipient);
        
        // 4. Create order structure
        const order = {
            salt: `0x${[...crypto.getRandomValues(new Uint8Array(32))].map(b => b.toString(16).padStart(2, '0')).join('')}` as `0x${string}`,
            maker: params.ethereumMaker,
            receiver: zeroAddress, // Must be zero for non-EVM
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
            dstToken: zeroAddress, // Not used for Solana
            deposits: this.encodeDeposits(params.srcDeposit, params.dstDeposit),
            timelocks: params.timelocks,
            dstRecipient: solanaRecipient, // 32-byte Solana address
        };
        
        // 6. Sign order
        const signedOrder = await this.signOrder(order, extraDataArgs);
        
        // 7. Store swap state in Deno KV
        const orderId = this.computeOrderId(order);
        await this.db.set(['swaps', orderId], {
            orderId,
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
        const swapEntry = await this.db.get(['swaps', orderId]);
        if (!swapEntry.value) throw new Error('Swap not found');
        const swap = swapEntry.value;
        
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
        
        // 4. Update state in Deno KV
        const currentEntry = await this.db.get(['swaps', orderId]);
        await this.db.set(['swaps', orderId], {
            ...currentEntry.value,
            state: 'filled',
            ethereumEscrow: escrowAddress,
            solanaTx,
            filledAt: Date.now(),
        });
        
        // 5. Start monitoring
        this.startMonitoring(orderId);
    }
    
    async withdrawWithSecret(orderId: string, secret: string): Promise<void> {
        const swapEntry = await this.db.get(['swaps', orderId]);
        if (!swapEntry.value) throw new Error('Swap not found');
        const swap = swapEntry.value;
        
        // Verify secret
        const hashlock = keccak256(encodeAbiParameters(
            [{ type: 'bytes32' }],
            [secret as `0x${string}`]
        ));
        // Note: Will be updated to sha256 in contract changes
        if (hashlock !== swap.hashlock) {
            throw new Error('Invalid secret');
        }
        
        // Withdraw on both chains
        await Promise.all([
            this.withdrawEthereum(swap, secret),
            this.withdrawSolana(swap, secret),
        ]);
        
        const currentEntry = await this.db.get(['swaps', orderId]);
        await this.db.set(['swaps', orderId], {
            ...currentEntry.value,
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
        const bytes = crypto.getRandomValues(new Uint8Array(32));
        return '0x' + [...bytes].map(b => b.toString(16).padStart(2, '0')).join('');
    }
}
```

### 2. Monitoring System

```typescript
export class SwapMonitor {
    private ethereumClient: PublicClient;
    private solanaWatcher: Connection;
    private db: Deno.Kv;
    
    async startMonitoring(swapId: string): Promise<void> {
        const swapEntry = await this.db.get(['swaps', swapId]);
        if (!swapEntry.value) throw new Error('Swap not found');
        const swap = swapEntry.value;
        
        // Monitor Ethereum events
        this.monitorEthereum(swap);
        
        // Monitor Solana transactions
        this.monitorSolana(swap);
        
        // Check timeouts
        this.monitorTimeouts(swap);
    }
    
    private async monitorEthereum(swap: SwapState): Promise<void> {
        // Watch for withdrawal events using viem
        const unwatch = this.ethereumClient.watchContractEvent({
            address: swap.ethereumEscrow,
            abi: ESCROW_ABI,
            eventName: 'EscrowWithdrawal',
            onLogs: async (logs) => {
                for (const log of logs) {
                    console.log('Secret revealed on Ethereum:', log.args.secret);
                    await this.handleSecretRevealed(swap, log.args.secret);
                }
            },
        });
        
        // Watch for cancellation events
        const unwatchCancel = this.ethereumClient.watchContractEvent({
            address: swap.ethereumEscrow,
            abi: ESCROW_ABI,
            eventName: 'EscrowCancelled',
            onLogs: async () => {
                console.log('Escrow cancelled on Ethereum');
                await this.handleCancellation(swap, 'ethereum');
            },
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
        
        // Update state in Deno KV
        const currentEntry = await this.db.get(['swaps', swap.id]);
        await this.db.set(['swaps', swap.id], {
            ...currentEntry.value,
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
import { parseArgs } from "https://deno.land/std/cli/parse_args.ts";
import { parseEther } from 'viem';

export async function createCommand(args: string[]) {
    const flags = parseArgs(args, {
        string: ['eth-amount', 'sol-amount', 'sol-recipient', 'eth-key', 'timeout'],
        default: { timeout: '24' },
    });
    
    if (!flags['eth-amount'] || !flags['sol-amount'] || !flags['sol-recipient'] || !flags['eth-key']) {
        console.error('Missing required arguments');
        Deno.exit(1);
    }
    
    const coordinator = new SwapCoordinator(config);
    await coordinator.init();
    
    const swap = await coordinator.createSwap({
        ethereumMaker: deriveAddress(flags['eth-key']),
        sourceToken: WETH_ADDRESS,
        sourceAmount: parseEther(flags['eth-amount']),
        destAmount: parseFloat(flags['sol-amount']) * LAMPORTS_PER_SOL,
        solanaRecipient: flags['sol-recipient'],
        timelocks: calculateTimelocks(flags.timeout),
        srcDeposit: parseEther('0.1'),
        dstDeposit: 0.1 * LAMPORTS_PER_SOL,
    });
    
    console.log('Swap created!');
    console.log('Order ID:', swap.orderId);
    console.log('Share this with the resolver to fill the swap');
}

// monitor.ts
import { parseArgs } from "https://deno.land/std/cli/parse_args.ts";
import { formatEther } from 'viem';

export async function monitorCommand(args: string[]) {
    const flags = parseArgs(args, {
        boolean: ['watch'],
    });
    
    const coordinator = new SwapCoordinator(config);
    await coordinator.init();
    const swaps = await coordinator.getActiveSwaps();
    
    if (flags.watch) {
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
            ethAmount: formatEther(s.order.makingAmount),
            solAmount: s.order.takingAmount / LAMPORTS_PER_SOL,
        })));
    }
}
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
    ethereumRpc: Deno.env.get('ETH_RPC') || 'http://localhost:8545',
    solanaRpc: Deno.env.get('SOLANA_RPC') || 'http://localhost:8899',
    ethereumChainId: parseInt(Deno.env.get('ETH_CHAIN_ID') || '1'),
    contracts: {
        limitOrderProtocol: Deno.env.get('LIMIT_ORDER_PROTOCOL') || '0x...',
        escrowFactory: Deno.env.get('ESCROW_FACTORY') || '0x...',
    },
    solanaProgram: {
        programId: Deno.env.get('SOLANA_PROGRAM_ID') || '...',
        idl: JSON.parse(await Deno.readTextFile('./idl.json')),
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

1. Install Deno: https://deno.land/manual/getting_started/installation
2. Set permissions in deno.json:
   ```json
   {
     "permissions": {
       "env": true,
       "net": true,
       "read": true,
       "write": ["./swap-state.db"]
     }
   }
   ```
3. Run directly: `deno run --allow-all main.ts`
4. Or compile: `deno compile --allow-all main.ts -o eth-sol-swap`
5. Configure: Set environment variables
6. Test on testnet first

## Future Enhancements

1. GUI interface
2. Mobile app support
3. Multi-signature support
4. Batch swap operations
5. Advanced routing algorithms