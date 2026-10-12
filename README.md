# 1inch Network Fusion Atomic Swaps

[![Build Status](https://github.com/1inch/cross-chain-swap/workflows/CI/badge.svg)](https://github.com/1inch/cross-chain-swap/actions)
[![Coverage Status](https://codecov.io/gh/1inch/cross-chain-swap/graph/badge.svg?token=gOb8pdfcxg)](https://codecov.io/gh/1inch/cross-chain-swap)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)
[![Solidity 0.8.23](https://img.shields.io/badge/solidity-0.8.23-363636.svg)](https://docs.soliditylang.org/)

Atomic Swap is a two-party swap mechanism, optimized for EVM-compatible chains with well-aligned incentives to ensure fair and fast execution for all participants.

This protocol implies some off-chain mechanism to verify the created escrow and distribute user defined secret.

`EscrowFactory` deploys an `EscrowSrc` clone on the source chain and an `EscrowDst` clone on the destination chain for each swap. The source escrow holds the user's tokens and the destination escrow the resolver's, and both release against a hashlock plus a set of timelocks.

## Documentation

- [Protocol design](docs/protocol.md) — the swap lifecycle, timelocks, rescue funds, partial fills, and the functions a resolver calls.
- [Fusion+ whitepaper](docs/fusion-plus-v1.pdf) — the protocol rationale.
- Per-function behaviour is documented in NatSpec next to the code. `yarn doc` renders it with `forge doc` into `documentation/`, which is gitignored and not checked in.
- Audits, the bug bounty programmes, how to report a vulnerability, and the accepted risks of this design: [SECURITY.md](SECURITY.md).

## Deployments
Production addresses per network are listed in [deployments.md](deployments.md). Raw artifacts live under [deployments/](deployments/).

## Repository structure

| Path             | Contents                                        |
| ---------------- | ----------------------------------------------- |
| `contracts/`     | Smart contracts                                 |
| `test/`          | Foundry tests                                   |
| `deploy/`        | Deployment scripts — Hardhat Ignition for EVM chains, forge for zkSync — and `config.json` |
| `foundry-deployers/` | Deployer shims for the Foundry-driven flows  |
| `docs/`          | Protocol documentation and the whitepaper       |
| `audits/`        | Audit reports                                   |
| `deployments/`   | Per-network deployment artifacts                |
| `examples/`      | Example configs, demos, and txn forge scripts   |
| `hooks/`         | Git pre-commit hooks                            |

## Local development

This project uses [Hardhat](https://hardhat.org) as the primary toolchain: compiling contracts, running the Solidity test suite, coverage, and the gas snapshot. EVM deployments run through Hardhat Ignition (`yarn deploy`). [Foundry](https://github.com/foundry-rs/foundry) is still used for the zkSync deployment script, the interaction scripts in `examples/`, and the zkSync build/test flow.

### Prerequisites

- Ensure you have [Node.js](https://nodejs.org) (v22+) and [Yarn](https://yarnpkg.com) installed, then install dependencies:

  ``` shell
  yarn install
  ```

  Solidity dependencies come from npm and git at the exact revisions recorded in `yarn.lock`. `postinstall` applies a `patch-package` patch that lets Hardhat import the `@1inch/solidity-utils` contracts.

- For the examples, lite and zkSync flows (including the zkSync deploy), [install Foundry](https://book.getfoundry.sh/getting-started/installation) (requires [Rust](https://www.rust-lang.org/tools/install)):

  ``` shell
  # Install Foundryup:
  curl -L https://foundry.paradigm.xyz | bash

  # Apply updated config to current terminal session
  source ~/.zshenv

  # Install forge, cast, anvil, and chisel
  foundryup
  ```

  CI pins Foundry to `v1.5.1`. `foundryup` with no arguments installs the current stable release instead, which is usually fine — but if a CI result will not reproduce locally, match the pin with `foundryup --install v1.5.1`.

  Every `forge` command needs the Foundry deployer shims in `dynamic-imports/`. The wrapped yarn scripts populate them for you; if you invoke `forge` directly, run `yarn deployers:foundry` beforehand. Every Hardhat build of the contracts replaces the contents of `dynamic-imports/` with Hardhat's own shims, so `yarn deployers:foundry` has to be run again after any Hardhat command. A `--no-compile` run skips that build, so it leaves whichever shims are already there.

### Build

To compile contracts run:

``` shell
yarn build
```

To typecheck the Hardhat config, the deploy scripts and the Ignition modules:

``` shell
yarn typecheck
```

It needs a build first: the deploy scripts are typed against the `artifacts.d.ts` declarations Hardhat writes during compilation.

To check that `contracts/` and `test/` still build under stock Foundry, which the lite profile and the zkSync and example flows rely on:

``` shell
yarn deployers:foundry && forge build
```

This does not compile the forge scripts in `examples/` or `deploy/`.

### Test

There are two test commands and they do different things. **Run both before committing** — neither one covers what the other checks, and CI runs both.

``` shell
yarn test       # the full suite, fuzz tests included
yarn snapshot   # refreshes .gas-snapshot, skips the fuzz tests
```

#### `yarn test` — verifies the change

Runs every test in `test/` under Hardhat, including the `testFuzz_*` tests, and writes nothing to the working tree. This is the command that tells you whether your change is correct.

#### `yarn snapshot` — refreshes the gas snapshot

Not an alias for the above. The script is `hardhat test solidity --snapshot --grep-exclude testFuzz`, which differs in two ways that matter:

- **It skips every fuzz test.** `--grep-exclude testFuzz` excludes them, because a fuzz run explores different inputs each time and so produces a different gas figure each time — there is nothing stable to record. A fuzz test that your change broke will pass here by never running.
- **It writes to a tracked file.** The gas cost of each remaining test is written to `.gas-snapshot`, which is committed to the repository. Running the command modifies your working tree, and if the diff is non-empty it belongs in your commit.

#### Why both

CI checks each side separately:

| CI job | Command | Fails when |
| ------------- | --------------------- | ------------------------------------------------------ |
| `test` | `yarn test`, then `yarn typecheck` | any test fails, fuzz tests included, or the TypeScript does not typecheck |
| `snapshot` | `yarn snapshot:check` | `.gas-snapshot` no longer matches what the code costs |
| `lint` | `yarn lint` | solhint reports anything, at `--max-warnings 0` |
| `forge-build` | `forge build` | `contracts/` or `test/` stops building under stock Foundry |

Running only `yarn snapshot` locally leaves a broken fuzz test to be found by the `test` job. Running only `yarn test` leaves `.gas-snapshot` stale, which the `snapshot` job rejects even though every test passes.

The [pre-commit hook](#how-to-setup-pre-commit-hooks) covers part of this — it runs `yarn lint` and the same snapshot check, and refuses the commit if the snapshot is stale. It does not run the test suite at all, so the fuzz tests remain yours to run. So, before committing:

``` shell
yarn test       # must pass
yarn snapshot   # then commit the .gas-snapshot diff, if there is one
yarn lint       # solhint, --max-warnings 0
yarn typecheck  # the deploy scripts and the Hardhat config
```

Two more suites exist for narrower cases: `yarn test:lite` runs the tests under Foundry with optimizer steps disabled for faster iteration, and `yarn test:zksync` runs them under the zkSync profile, which needs the zkSync fork of Foundry.

## Deploy

`yarn deploy --network mainnet` deploys `EscrowFactory`, and `yarn deploy:erc20true --network mainnet` the `ERC20True` access token stub, both through Hardhat Ignition with the addresses and CREATE3 salts in `deploy/config.json`. A hex salt must be exactly 32 bytes and is used as-is; any other text is hashed with keccak256. When `factoryOwner` is missing or the zero address, the owner is the `DEPLOYER_ADDRESS` environment variable.

Ignition records each deployment under `ignition/deployments/chain-<id>/`. Commit that folder for a real network; only the local `chain-31337` is gitignored.

The deploy scripts read their secrets — `MAINNET_RPC_URL`, `DEPLOYER_PRIVATE_KEY` and, for verification, `ETHERSCAN_API_KEY` — as Hardhat configuration variables. Store them in the encrypted keystore, which asks for its password when a value is used:

``` shell
npx hardhat keystore set DEPLOYER_PRIVATE_KEY
```

- An environment variable of the same name takes precedence over the keystore.
- A value in the development keystore (`keystore set --dev`, no password) takes precedence over the same value in the production keystore.
- When `CI` is set, to any value including `false`, Hardhat skips the keystore and only the environment is read.
- Hardhat does not read `.env`. Only the zkSync deploy script (`yarn deploy:zksync`) and the scripts under `examples/` do.

## How to setup pre-commit hooks
Run the following commands in your terminal:
```bash
chmod +x hooks/pre-commit && cp hooks/pre-commit .git/hooks/pre-commit
```
