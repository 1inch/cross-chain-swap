# [AGENTS.md](http://AGENTS.md)

Guidance for coding agents working in this repository.

## What this repository is

1inch cross-chain atomic swap contracts. `EscrowFactory` deploys an `EscrowSrc` clone on the source chain and an `EscrowDst` clone on the destination chain for each swap; the source escrow holds the user's tokens and the destination escrow the resolver's, and both release against a hashlock plus a set of timelocks. Source-chain escrows are created by filling a user-signed order through the 1inch Limit Order Protocol. The secret that unlocks a swap is distributed off-chain, which the contracts assume rather than enforce.

## Toolchain

This project uses Foundry (`foundry.toml`), with solc pinned to 0.8.23 and the toolchain release pinned in `foundry.lock`.

### Build and test

```bash
yarn          # installs dependencies; postinstall runs forge install for the submodules
forge build
forge test    # the full suite, and what CI runs
yarn lint     # solhint with --max-warnings 0
```

`yarn test` is not `forge test`. It runs `forge snapshot --no-match-test "testFuzz_*"`, which rewrites `.gas-snapshot` and skips the fuzz tests. Run `forge test` before pushing: CI runs the full suite including `testFuzz_*`, plus `forge snapshot --check`, so a stale snapshot or a failing fuzz test surfaces there rather than locally.

Prefer the repository's own scripts and Makefile targets over inventing parallel commands. `make help` lists the targets.

## Layout


| Path           | Contents                                              |
| -------------- | ----------------------------------------------------- |
| `contracts/`   | Smart contracts                                       |
| `tests/`       | Foundry tests                                         |
| `deploy/`      | Deployment forge scripts and `deploy.sh`              |
| `scripts/`     | Shell helpers (coverage)                              |
| `config/`      | Deployment parameters (`constants.json`)              |
| `deployments/` | Per-network deployment artifacts                      |
| `examples/`    | Example configs, demos, and interaction forge scripts |
| `hooks/`       | Git pre-commit hooks                                  |
| `lib/`         | Git submodule dependencies                            |


There is no `docs/` directory: protocol documentation lives in `README.md`. `yarn doc` runs `forge doc` into `documentation/`, which is gitignored — never commit generated HTML.

## Deployments and security

- Deployed addresses: [deployments.md](deployments.md), with the exceptions described below.
- Vulnerability disclosure and bounty: [SECURITY.md](SECURITY.md). Never open a public issue or pull request for an undisclosed vulnerability.
- Contribution process: [CONTRIBUTING.md](CONTRIBUTING.md).



## Agent constraints

- Do not commit secrets, private keys, mnemonics or API keys. Do not edit a file only to delete a leaked secret — report it for rotation instead.
- Do not rewrite `SPDX-License-Identifier` headers.
- Do not change compiler `optimizer_runs`, `via-ir` or `evm_version` unless explicitly asked — that changes bytecode. See below.
- Keep diffs scoped: no drive-by reformatting of files you are not changing.
- Do not use a formatter in this repository. Do not run `forge fmt` / `make format`, do not add a format CI job, and do not document or require formatting in CONTRIBUTING. A `[fmt]` table in `foundry.toml` or a `format` Makefile target is leftover tooling, not an adopted workflow — treat the repo as having no formatter.
- Follow existing Solidity style and NatSpec conventions; public and external functions need accurate NatSpec.



## Project-specific notes



### Compiler settings are load-bearing

`foundry.toml` sets `via-ir = true`, `optimizer_runs = 1000000` and `evm_version = 'shanghai'`. The live factories are verified on block explorers with exactly these settings, so changing any of them breaks the match between the sources here and the deployed bytecode. Treat them as frozen.

### Deployment records

`deployments.md` is the source of truth for deployed addresses. It deliberately does not correspond one-to-one with the `deployments/` directory:

- **Aurora, Fantom and Klaytn are no longer supported.** The leftover records under `deployments/aurora/`, `deployments/fantom/` and `deployments/klaytn/` are historical. Do not add these chains to `deployments.md`, and do not report their absence from it as an omission.

### Privileged roles, and what is not upgradeable

Nothing here is an upgradeable proxy. `EscrowSrc` and `EscrowDst` clones are minimal proxies over fixed implementations with immutable arguments, so there is no storage layout to preserve across releases and no upgrade path to document.

`EscrowFactory` does take an `owner`, passed through `SimpleSettlement` to `FeeTaker` in limit-order-settlement. Its only privileged power is `rescueFunds`, which retrieves tokens sent directly to the factory by mistake. `ResolverExample` in `contracts/mocks/` is `Ownable` and carries `arbitraryCalls`; it is a reference implementation and not production code.

### Deployment parameters

`EscrowFactory` takes `(limitOrderProtocol, accessToken, owner, rescueDelaySrc, rescueDelayDst)`. Both rescue delays are deployed as 691200 seconds (8 days), encoded in the `constructor-args` target in the `Makefile` rather than in a config file. `config/constants.json` holds the per-chain addresses and CREATE3 salts for chain ids 1 and 31337 only; the other live networks were deployed elsewhere and their parameters are not in this repository.

### zkSync is a separate build

zkSync uses its own contract (`EscrowFactoryZkSync`), its own deploy script, and the `zksync` Foundry profile. Commands need `FOUNDRY_PROFILE=zksync` and `--zksync`; the default profile's output does not apply to it.

### Layout exception: `examples/`

Scripts under `examples/` are **example / demo scripts**, not repository tooling. They belong in `examples/` and must **not** be moved into `scripts/`. `scripts/` is only for non-demo helpers such as coverage.

`examples/onchain/` holds interaction forge scripts (create order, deploy escrow, withdraw, cancel) and `examples/scripts/` a shell driver. They are documented in `examples/README.md`, and Makefile targets reference those exact paths. Moving them breaks those targets and the `fs_permissions` entry in `foundry.toml`. Their presence outside `scripts/` is intentional — not a layout error, and not something a repository-organization review should flag.

### Secrets

Deployment and demo runs read private keys and RPC URLs from `.env`, which is gitignored. `examples/config/config.json` is checked in and must stay free of keys — the `deployer` and `maker` values in it are the well-known public Anvil test accounts.