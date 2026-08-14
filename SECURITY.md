# Security Policy

## Reporting a vulnerability

Do not report security vulnerabilities through public GitHub issues, pull requests or discussions. A public report gives an attacker the same information it gives us, before there is a fix.

Report privately to [security@1inch.com](mailto:security@1inch.com).

Acknowledgement times and response SLAs change the same way programme rules do — read them on the bug bounty pages linked below rather than trusting a copy here.

Please include the affected contract and network, the commit or tag the deployment was built from, and the steps or a test that reproduces the problem.

## Bug bounty

Smart-contract findings go through the 1inch bug bounty programmes. Scope, severity levels, payout ranges and response SLAs live on the programme pages — they change, so this file links them rather than copying them:

- [HackenProof — 1inch Smart Contract](https://hackenproof.com/programs/1inch-smart-contract)
- [Immunefi — 1inch Smart Contracts](https://immunefi.com/bug-bounty/1inch-SmartContracts/resources/#top)



## Supported versions and deployments

The supported release is **1.1.0**. Deployment addresses are listed in [deployments.md](deployments.md).

## Audits

Copies of every report are kept in [audits/](audits/), which lists them by auditor and release. They are published in [1inch/1inch-audits](https://github.com/1inch/1inch-audits), which remains the source of truth:

- **v1.0** — [Cross-chain Protocol](https://github.com/1inch/1inch-audits/tree/master/Cross-chain%20Protocol), locally in [audits/cross-chain-protocol/](audits/cross-chain-protocol)
- **v1.1** — [Crosschain fees v1.1](https://github.com/1inch/1inch-audits/tree/master/Crosschain%20fees%20v1.1), locally in [audits/crosschain-fees-v1.1/](audits/crosschain-fees-v1.1)



## Accepted risks and known limitations

The properties below are known and accepted consequences of the design rather than defects, and a report describing one of them as a vulnerability will be closed as such. If you can show that one of them is exploitable beyond what is described here, that is a finding — report it through the channel above.

### The secret is distributed off-chain

The escrows verify that `keccak256(secret)` equals the hashlock and nothing more. Generating the secret, holding it, and deciding when to release it to a resolver all happen off-chain, in a system these contracts neither implement nor constrain. A swap is only as safe as that process: if the secret reaches a resolver before both escrows are funded with the agreed parameters, the on-chain code will not stop it from being used. See [Protocol design](docs/protocol.md#security-considerations).

### Any withdrawal publishes the secret on-chain

Both escrows emit `EscrowWithdrawal(secret)` on a successful withdrawal (`contracts/EscrowSrc.sol`, `contracts/EscrowDst.sol`). From the first withdrawal on either chain, the secret is public and anyone can read it from the logs. This is deliberate — it is how a resolver that never received the secret off-chain can still recover it and withdraw on the source chain before cancellation — but it means a secret must be treated as single-use and as public the moment it is used anywhere.

### The "public" phases are gated by the access token

`publicWithdraw` and `publicCancel` are restricted by `onlyAccessTokenHolder`, which requires a non-zero balance of the access token configured at deployment (`contracts/BaseEscrow.sol`). They are open to any holder of that token rather than to the general public, and the illustrative comment in `contracts/libraries/TimelocksLib.sol` that describes these periods as available to "anyone" should be read with that qualification. If no access-token holder acts during a public period, the escrow simply waits for the next stage.

### Timelock values are trusted input, not validated relationships

`Timelocks` is a packed `uint256` supplied in the immutables and read back by offset; the library adds a stage's `uint32` duration to the deployment timestamp and returns it (`contracts/libraries/TimelocksLib.sol`). Nothing on-chain checks that the stages are ordered sensibly, or that the source-chain and destination-chain schedules line up so that the user is paid before the resolver can reclaim. Those relationships are the responsibility of whoever builds the order. The stages are also ordinary `block.timestamp` comparisons, so they inherit the small amount of validator discretion over that value, and the finality period is a chosen constant rather than a chain-verified guarantee.

### Stuck funds are recoverable only by the taker, and only after the rescue delay

`rescueFunds` is callable by `immutables.taker` alone, and only after `RESCUE_DELAY` has elapsed since deployment (`contracts/BaseEscrow.sol`). The delay is deployed as 691200 seconds — 8 days. Tokens sent to an escrow clone by mistake, including tokens sent to a computed clone address before it is deployed, are recoverable on those terms and no others.

### The taking token on the source chain is a stub

The taking token in a Fusion order is a contract whose `transfer` and `transferFrom` return `true` without moving anything and whose `balanceOf` returns zero (`contracts/mocks/ERC20True.sol`). The source-chain fill therefore records a taking amount that never changes any balance, because the real compensation reaches the user on the destination chain. A source-chain fill observed in isolation is not evidence that the user was paid.

### Nothing is upgradeable

`EscrowSrc` and `EscrowDst` clones are minimal proxies over fixed implementations with immutable arguments, and `EscrowFactory` is not behind a proxy. There is no way to patch a deployed escrow: a fix means deploying a new factory and migrating integrations to it, and escrows already created continue to run the old code until they are withdrawn or cancelled.

### Privileged roles are narrow

`EscrowFactory` takes an `owner`, passed through `SimpleSettlement` to `FeeTaker`. Its only privileged power is `rescueFunds` on the factory itself, which retrieves tokens sent to the factory by mistake; it confers nothing over escrow clones or user funds. `ResolverExample` in `contracts/mocks/` is `Ownable` and exposes `arbitraryCalls` to its owner — it is a reference implementation for resolvers to adapt, not a deployed part of the protocol.

### Timelock encoding expires in 2106

Stage offsets and the deployment timestamp are stored as `uint32` seconds, which overflows in 2106, as noted in `contracts/libraries/TimelocksLib.sol`.

## Hiring

Security-related roles are listed at [1inch open positions](https://1inch.com/open-positions).