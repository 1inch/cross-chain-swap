# Technology Stack Update

## CLI Tool Tech Stack Changes

Based on the requirements, the following technology updates have been made to the CLI tool design:

### Runtime
- **From**: Node.js
- **To**: Deno (TypeScript runtime)
- **Benefits**: 
  - Built-in TypeScript support
  - Better security model with permissions
  - No node_modules, uses URL imports
  - Built-in testing and formatting tools

### Database
- **From**: LevelDB
- **To**: Deno KV
- **Benefits**:
  - Native to Deno, no external dependencies
  - Built-in persistence
  - Simple key-value API
  - Atomic operations support

### Ethereum Library
- **From**: ethers.js v6
- **To**: viem
- **Benefits**:
  - More type-safe
  - Better performance
  - Modern API design
  - Excellent TypeScript support

## Key Code Changes

### 1. Database Operations
```typescript
// Old (LevelDB)
await this.db.put(key, value);
const value = await this.db.get(key);

// New (Deno KV)
await this.db.set(['swaps', orderId], value);
const entry = await this.db.get(['swaps', orderId]);
const value = entry.value;
```

### 2. Ethereum Client
```typescript
// Old (ethers)
const provider = new ethers.JsonRpcProvider(rpc);
const contract = new ethers.Contract(address, abi, provider);

// New (viem)
const client = createPublicClient({
    chain: mainnet,
    transport: http(rpc)
});
client.watchContractEvent({
    address,
    abi,
    eventName: 'EventName',
    onLogs: (logs) => { }
});
```

### 3. Environment Variables
```typescript
// Old (Node.js)
process.env.ETH_RPC

// New (Deno)
Deno.env.get('ETH_RPC')
```

### 4. File Operations
```typescript
// Old (Node.js)
require('./idl.json')

// New (Deno)
JSON.parse(await Deno.readTextFile('./idl.json'))
```

### 5. CLI Parsing
```typescript
// Old (Commander.js)
new Command('create').option('--eth-amount', 'Amount')

// New (Deno std)
import { parseArgs } from "https://deno.land/std/cli/parse_args.ts";
const flags = parseArgs(args, {
    string: ['eth-amount'],
});
```

## Import Changes

### Deno URL Imports
```typescript
// Standard library
import { parseArgs } from "https://deno.land/std/cli/parse_args.ts";

// NPM packages via esm.sh
import { createPublicClient } from "https://esm.sh/viem";
import { Connection } from "https://esm.sh/@solana/web3.js";
```

## Running the Application

### Development
```bash
# Run with permissions
deno run --allow-env --allow-net --allow-read --allow-write=./swap-state.db main.ts

# Or with all permissions (development only)
deno run --allow-all main.ts
```

### Production
```bash
# Compile to executable
deno compile --allow-env --allow-net --allow-read --allow-write=./swap-state.db main.ts -o eth-sol-swap

# Run compiled binary
./eth-sol-swap create --eth-amount 1.0 --sol-amount 50.0 --sol-recipient <address>
```

## Testing with Deno

```bash
# Run tests
deno test

# With permissions
deno test --allow-all

# Watch mode
deno test --watch
```

## Benefits of This Stack

1. **Type Safety**: Both viem and Deno provide excellent TypeScript support
2. **Security**: Deno's permission model ensures the app only accesses what it needs
3. **Simplicity**: No package.json, no node_modules, just code
4. **Performance**: viem is optimized for performance, Deno KV is fast
5. **Modern**: Latest tooling with best practices built-in

## Migration Notes

- The CLI_TOOL_DESIGN.md has been updated with all these changes
- The core logic remains the same, only the implementation details change
- All async operations now use Deno's built-in APIs
- Error handling patterns remain similar but use Deno's error types