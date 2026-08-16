# Repository review — cross-chain-swap (Foundry)

**Score: 97.2 / 100 — B** · 1 error · 3 warnings · 3 checks unverified

The repository is already well organized for a Foundry protocol: standard layout, strong SECURITY / CONTRIBUTING / CI / templates / AGENTS coverage, and a complete `deployments.md` plus provenance record. The grade is capped at B by one unresolved error — stale table-of-contents anchors in `deployments.md`. Fixing that TOC (and the small AGENTS wording slip about `foundry.lock`) is the cheapest way to clear the remaining gap.

## Score by section

| # | Section | Score | Weight | Errors | Warnings |
|---|---------|-------|--------|--------|----------|
| 1 | README.md | 13.6 | 14 | 0 | 1 |
| 2 | Repository structure | 14.0 | 14 | 0 | 0 |
| 3 | LICENSE | 9.0 | 9 | 0 | 0 |
| 4 | CONTRIBUTING.md | 8.0 | 8 | 0 | 0 |
| 5 | SECURITY.md | 15.0 | 15 | 0 | 0 |
| 6 | CI configuration | 13.8 | 15 | 0 | 1 |
| 7 | Issue and pull request templates | 7.0 | 7 | 0 | 0 |
| 8 | Release process | 9.3 | 10 | 1 | 0 |
| 9 | AI agent guidance | 2.5 | 3 | 0 | 1 |
| — | Additional files and conventions | 5.0 | 5 | 0 | 0 |
| — | **Total** | **97.2** | **100** | **1** | **3** |

## Findings

### 1. README.md — 13.6 / 14

- ⚠️ Optional badges incomplete: coverage and Solidity are present (`README.md:3-6`), but there is no GitHub release-version, tests-status, or npm badge. Add a release badge if you want the optional set closer to complete; skip npm unless the package is published.
- ✅ Passed: root README present and substantive; protocol description; repository layout table; Foundry build/test instructions (`forge build`, `forge test`, `yarn test` / snapshot distinction); deployments linked via `deployments.md`; links to docs, audits, and bounty through `SECURITY.md`; CI and License badges; documented commands match `package.json` / Foundry defaults.

### 2. Repository structure — 14.0 / 14

- ✅ Passed: `contracts/` (27 `.sol`), `tests/` (18), `deploy/` (forge scripts + `deploy.sh` + `config.json`), `docs/` as Markdown/PDF only (no checked-in HTML/CSS/JS docs), `scripts/` for non-deploy helpers (`coverage.sh`). `examples/` demo scripts outside `scripts/` are an intentional, documented layout exception in `AGENTS.md` and are not scored as a violation.

### 3. LICENSE — 9.0 / 9

- ✅ Passed: `LICENSE.md` is MIT; all 60 tracked `.sol` files declare `SPDX-License-Identifier: MIT`. BUSL transition and mixed-license documentation do not apply.

### 4. CONTRIBUTING.md — 8.0 / 8

- ✅ Passed: contribution flow (fork → branch → PR, CI + review); Solidity style and NatSpec requirements; unit/fuzz test policy (`testFuzz_*`); `yarn lint` documented (solhint is configured); vulnerability reporting deferred to `SECURITY.md`. Formatter guidance correctly omitted — the repo does not adopt a formatter.

### 5. SECURITY.md — 15.0 / 15

- ✅ Passed: private disclosure to `security@1inch.com`; HackenProof and Immunefi bounty links; supported release **1.1.0** with link to `deployments.md`; audit links to local `audits/` and `1inch/1inch-audits`; accepted risks / known limitations section.

### 6. CI configuration — 13.8 / 15

- ⚠️ No static analysis job (Slither or equivalent) in `.github/workflows/test.yml`. Add a Slither (or equivalent) job that fails the pipeline on critical findings if the team wants the recommended CI set complete.
- ✅ Passed: workflow on `push` to `master` and `pull_request`; `forge test` (includes fuzz); `yarn lint` → solhint; formatter CI N/A (formatter not adopted); compile covered by `forge test`; Foundry pinned to `v1.5.1` in CI and solc `0.8.23` in `foundry.toml`; `yarn.lock` + git submodules; coverage + Codecov and `forge snapshot --check` / gas report; secrets via `secrets.CODECOV_TOKEN` only.

### 7. Issue and pull request templates — 7.0 / 7

- ✅ Passed: bug and feature issue forms; bug form asks for network, contract address, tx hash, version, reproduction; vulnerability warnings in templates and `config.yml` contact link to `SECURITY.md`; PR template checklist covers tests, docs, and gas (`forge snapshot --check`). Storage-layout item correctly absent (nothing is upgradeable).

### 8. Release process — 9.3 / 10

- ❌ `deployments.md` table of contents links to missing sections `#verification-status` and `#build-provenance` (`deployments.md:24-25`), and the intro still points at `[Build provenance](#build-provenance)` (`deployments.md:3`). Those topics live in `deployments/provenance.md`. Retarget or remove the dead anchors so the TOC matches the file.
- ✅ Passed: semver tags locally (`1.0.0`, `1.1.0`, …) and Keep a Changelog `CHANGELOG.md`; production factories record `provenance.sourceTag` (e.g. `deployments/mainnet/EscrowFactory-v1.1.0.json`); explorer verification documented in `deployments/provenance.md` (zkSync Blockscout mismatch called out as expected); per-chain `| Contract | Address |` tables; deploy scripts under `deploy/` with rescue delay and constructor args documented in `AGENTS.md` / provenance; upgrade path N/A; 1.1.0 changes documented; npm package sync N/A (tooling `package.json`, not a published SDK).

### 9. AI agent guidance — 2.5 / 3

- ⚠️ `AGENTS.md:11` says the Foundry toolchain release is pinned in `foundry.lock`, but `foundry.lock` only records submodule revisions. The Foundry binary is pinned in CI (`version: v1.5.1` in `.github/workflows/test.yml:19`). Correct the sentence so agents do not look in the wrong file.
- ✅ Passed: `AGENTS.md` present with protocol summary, Foundry toolchain, build/test/lint commands, layout, agent constraints (secrets, SPDX, frozen compiler flags, no formatter), and project-specific hazards (non-upgradeable clones, factory `owner` / `rescueFunds`, zkSync profiles, `examples/` exception, deployment-parameter gaps).

### Additional files and conventions — 5.0 / 5

- ✅ Passed: `.gitignore` covers `out/`, `cache`, `node_modules`, `broadcast`, `documentation`, `.env*`; secret-scan heuristic clean on tracked files; `audits/` present with reports and README; `foundry.toml` pins `solc_version`, `optimizer_runs`, `evm_version`.

## Fix first

1. **Repair `deployments.md` TOC and intro anchors** — retarget Verification status / Build provenance to `deployments/provenance.md` (or restore short summary sections). Clears the only scoring error (~0.7 points toward an A once merged). ~10 min.
2. **Fix the `foundry.lock` claim in `AGENTS.md`** — point at CI’s Foundry `v1.5.1` pin instead. Small warning, high agent-confusion cost. ~5 min.
3. **Resolve `audits/README.md` TODO** — confirm what the `v1` / `v2` report filename groups mean and which commits each round reviewed (`audits/README.md:20`). Protocol-team knowledge; documentation completeness, not score-critical.
4. **Optional: add Slither (or equivalent) to CI** — closes the remaining recommended CI gap. Half day including triage of findings.
5. **Optional: GitHub release badge on the README** — cosmetic completeness of the optional badge set.

## Then

- Pin the zkSync CI checkout of `matter-labs/foundry-zksync` to a tag/commit instead of `ref: 'main'` (`.github/workflows/test.yml:58`) for reproducibility of that job.
- Keep `deployments/provenance.md` as the live verification ledger; do not expect `zksync.blockscout.com` to match EVM builds (already documented).

## Unverified

- Branch protection and required checks on `master` — GitHub admin/API access unavailable in this review pass (belongs to the separate GitHub review checklist).
- Live confirmation of GitHub Releases pages (CHANGELOG links them; tags exist locally).
- Live Etherscan/Blockscout spot-check of deployed addresses (verification status taken from `deployments/provenance.md` as of 15 August 2026).

---
Reviewed at 091d643 on fix/repo, working tree clean.
