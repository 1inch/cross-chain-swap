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
| `tests/`         | Foundry tests                                   |
| `deploy/`        | Deployment forge scripts and `deploy.sh`        |
| `scripts/`       | Shell helpers (coverage)                        |
| `docs/`          | Protocol documentation and the whitepaper       |
| `audits/`        | Audit reports                                   |
| `config/`        | Deployment parameters                           |
| `deployments/`   | Per-network deployment artifacts                |
| `examples/`      | Example configs, demos, and txn forge scripts   |
| `hooks/`         | Git pre-commit hooks                            |

## Local development
This project uses [Foundry](https://github.com/foundry-rs/foundry) for smart contract development in Solidity. Foundry is a fast, portable, and modular toolkit designed to compile, test, and deploy Solidity contracts.

### Prerequisites
- Ensure you have [Rust](https://www.rust-lang.org/tools/install) installed.
- To [install Foundry](https://book.getfoundry.sh/getting-started/installation), including the `forge` tool, follow these steps:

``` shell
# Install Foundryup:
curl -L https://foundry.paradigm.xyz | bash

# Apply updated config to current terminal session
source ~/.zshenv

# Install forge, cast, anvil, and chisel
foundryup
```

### Build
To install submodules and compile contracts run:

``` shell
forge build
```

### Test

There are two test commands and they do different things. **Run both before committing** — neither one covers what the other checks, and CI runs both.

``` shell
forge test   # the full suite, fuzz tests included
yarn test    # refreshes .gas-snapshot, skips the fuzz tests
```

#### `forge test` — verifies the change

Runs every test in `tests/`, including the `testFuzz_*` tests, and writes nothing to the working tree. This is the command that tells you whether your change is correct.

#### `yarn test` — refreshes the gas snapshot

Not an alias for the above. The script is `FOUNDRY_PROFILE=default forge snapshot --no-match-test "testFuzz_*"`, which differs in two ways that matter:

- **It skips every fuzz test.** `--no-match-test "testFuzz_*"` excludes them, because a fuzz run explores different inputs each time and so produces a different gas figure each time — there is nothing stable to record. A fuzz test that your change broke will pass here by never running.
- **It writes to a tracked file.** The gas cost of each remaining test is written to `.gas-snapshot`, which is committed to the repository. Running the command modifies your working tree, and if the diff is non-empty it belongs in your commit.

#### Why both

CI checks each side separately:

| CI job | Command | Fails when |
| ---------- | ------------------------------------------------------------ | ------------------------------------------------------ |
| `test` | `forge test -vvv --gas-report` | any test fails, fuzz tests included |
| `snapshot` | `forge snapshot --check --no-match-test "testFuzz_*"` | `.gas-snapshot` no longer matches what the code costs |
| `lint` | `yarn lint` | solhint reports anything, at `--max-warnings 0` |

Running only `yarn test` locally leaves a broken fuzz test to be found by the `test` job. Running only `forge test` leaves `.gas-snapshot` stale, which the `snapshot` job rejects even though every test passes.

The [pre-commit hook](#how-to-setup-pre-commit-hooks) covers part of this — it runs `yarn lint` and the same `forge snapshot --check`, and refuses the commit if the snapshot is stale. It does not run the test suite at all, so the fuzz tests remain yours to run. So, before committing:

``` shell
forge test   # must pass
yarn test    # then commit the .gas-snapshot diff, if there is one
yarn lint    # solhint, --max-warnings 0
```

Two more profiles exist for narrower cases: `yarn test:lite` runs the suite with optimizer steps disabled for faster iteration, and `yarn test:zksync` runs it under the zkSync profile, which needs the zkSync fork of Foundry.

## How to setup pre-commit hooks
Run the following commands in your terminal:
```bash
chmod +x hooks/pre-commit && cp hooks/pre-commit .git/hooks/pre-commit
```
