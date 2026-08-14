# AGENTS.md

Guidance for coding agents working in this repository.

## What this repository is

{{REPO_SUMMARY}}

## Toolchain

This project uses {{TOOLCHAIN_NAME}} (`{{TOOLCHAIN_CONFIG}}`), with solc pinned to {{SOLC_VERSION}}.

### Build and test

```bash
{{INSTALL_COMMAND}}
{{BUILD_COMMAND}}
{{TEST_COMMAND}}
{{LINT_COMMAND}}
{{FORMAT_COMMAND}}
```

Prefer the repository's own scripts and config over inventing parallel commands. Do not introduce `forge fmt`, Prettier, or another formatter unless this repository already uses one.

## Layout

| Path | Contents |
|---|---|
{{STRUCTURE_ROWS}}

Contracts live under `contracts/`, tests under `tests/`. Deployment scripts belong in `deploy/`; other automation in `scripts/`. Protocol docs are Markdown under `docs/` (PDF only for whitepapers and math-heavy papers) — never commit HTML/CSS/JS documentation sites.

## Deployments and security

- Deployed addresses: [deployments.md](deployments.md) when present.
- Vulnerability disclosure and bounty: [SECURITY.md](SECURITY.md). Never open a public issue or PR for an undisclosed vulnerability.
- Contribution process: [CONTRIBUTING.md](CONTRIBUTING.md).

## Agent constraints

- Do not commit secrets, private keys, mnemonics or API keys. Do not edit a file only to delete a leaked secret — report it for rotation instead.
- Do not rewrite `SPDX-License-Identifier` headers.
- Do not change compiler `optimizer_runs` or `evm_version` unless explicitly asked — that changes bytecode.
- Keep diffs scoped: no drive-by reformatting of files you are not changing.
- Follow existing Solidity style and NatSpec conventions; public/external functions need accurate NatSpec.

## Project-specific notes

TODO(repository-review): add anything an agent would not infer from the tree — upgradeability, privileged roles, packages that must stay in sync, intentional deviations from the standard layout.
