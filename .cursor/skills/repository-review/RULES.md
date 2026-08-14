# Repository Review — rules for Solidity protocol repositories

Standard repository organization rules for Solidity-based blockchain protocols. Each rule is phrased as a checkable requirement. Findings have two severity levels:

- ❌ **Error** — the rule is violated and must be fixed.
- ⚠️ **Warning** — a strongly recommended practice is missing.

Rules unmarked with a severity are treated as errors by default; rules marked "(Recommended)" produce warnings.

Projects may use any of the supported toolchains — **Hardhat 2**, **Hardhat 3**, or **Foundry (forge)** — and the rules must be applied accordingly. Where commands differ, per-toolchain equivalents are given.

---



## 1. [README.md](http://README.md)

- [ ] `README.md` exists at the repository root and is not a placeholder.
- [ ] `README.md` may contain 1inch Logo. The logo should be text in svg format and contain 1'' or 1inch''
- [ ] Contains a short description of the protocol: what it does and what problem it solves.
- [ ] The repository structure is described (where contracts, tests, scripts, and documentation live).
- [ ] Build and test instructions are provided: required toolchain (Hardhat 2 / Hardhat 3 / Foundry), versions, commands (`npx hardhat test`, `forge build`, `forge test`, etc.).
- [ ] Deployed contract addresses are recorded in `deployments.md` (preferred), or listed in the README / linked from it. `deployments.md` uses one `## <chain name> (<chain id>)` section per network with a `| Contract | Address |` table.
- [ ] Links to protocol documentation, audits, and the bug bounty program are present.
- [ ] Badges CI status and License are present.
- [ ] Optionally, badges coverage, solidity, github (release version), tests status, npm release status are present
- [ ] The README is up to date: commands work, links are not broken, the description matches the code.



## 2. Repository structure

The repository must follow the standard top-level layout:

- [ ] `contracts/` — smart contracts.
  - ❌ Error if the contracts directory has any other name (`src/`, `solidity/`, `core/`, etc.) — any name that is not exactly `contracts` is a violation.
- [ ] `tests/` — smart contract tests.
  - ⚠️ Warning if the `tests/` folder is absent and the project has no tests at all.
  - ❌ Error if tests exist but live in a different folder (`test/`, `spec/`, etc.).
- [ ] `deploy/` — deployment scripts for the contracts.
  - May be absent — that is not a violation. But if deployment scripts exist, they must live in `deploy/`.
- [ ] `docs/` — documentation in Markdown format.
  - PDF files (e.g. whitepapers, papers with heavy math) and images referenced from the Markdown files may also be present here.
  - ❌ Error if documentation is committed as a web page or site — `.html`, `.css`, or documentation JavaScript (and the usual companions: `.htm`, bundled docs themes). Docs in the repository must be Markdown for the main body, or PDF for whitepapers and similar; generated HTML (mdBook, `forge doc`, GitBook export, etc.) must not be checked in.
- [ ] `scripts/` - any bash or hardhat or forge scripts that do not deploy
  - May be absent — that is not a violation. But if non-deployment scripts exist, they must live in `scripts/`.



## 3. LICENSE

- [ ] A `LICENSE` (or `LICENSE.md`) file exists at the root.
- [ ] The license is a standard OSI one (MIT, GPL-3.0, BUSL-1.1, AGPL-3.0, etc.), not a homegrown text with no legal weight.
- [ ] The license in `LICENSE` is consistent with the SPDX identifiers in `.sol` file headers (`// SPDX-License-Identifier: ...`).
- [ ] If BUSL or another time/usage-restricted license is used — the transition terms (Change Date, Change License) are filled in.
- [ ] If different parts of the code carry different licenses (e.g. interfaces under MIT, core under BUSL), this is explicitly documented.



## 4. [CONTRIBUTING.md](http://CONTRIBUTING.md)

- [ ] A `CONTRIBUTING.md` file exists (at the root or in `.github/`).
- [ ] The contribution process is described: fork → branch → PR, requirements for passing CI and review.
- [ ] Code standards are specified: Solidity style (the official style guide or a custom one), naming rules, NatSpec comment requirements for public functions.
- [ ] Test requirements for new changes are described (unit, fuzz, invariant — which are mandatory).
- [ ] If the repository already configures a linter (e.g. `solhint` in `package.json` / CI), CONTRIBUTING says how to run it. Do not require a linter the repo does not use.
- [ ] If the repository already configures a formatter (e.g. a `fmt` / `format` / `prettier` script in `package.json`, `prettier` config, or `forge fmt` in CI / docs), CONTRIBUTING says how to run it. Do not require or recommend `forge fmt`, Prettier, or any other formatter when the repo does not already use one.
- [ ] It is explicitly stated that vulnerabilities must not be reported via public issues/PRs (with a link to `SECURITY.md`).



## 5. [SECURITY.md](http://SECURITY.md)

For protocols managing user funds, this is one of the most critical files.

- [ ] A `SECURITY.md` file exists (at the root or in `.github/`).
- [ ] A channel for private vulnerability disclosure is specified: email, Immunefi/HackenProof, GitHub Private Vulnerability Reporting.
- [ ] The bug bounty program is described: scope (which contracts/networks), severity levels, payout ranges — or it is explicitly stated that there is no program.
- [ ] It is specified which versions/deployments are in the support scope (prefer a link to `deployments.md`).
- [ ] There are links to completed audits (reports in the repository — usually `audits/` — external links, or the matching folder under [1inch/1inch-audits](https://github.com/1inch/1inch-audits)).
- [ ] Known limitations / accepted risks (known issues from audits) are documented, if applicable.



## 6. CI configuration

CI is strongly recommended. ⚠️ Warning if the repository has no CI at all.
The minimal acceptable CI set is **tests** (and a compile/build job when practical). Linters and formatters belong in CI only when the repository already uses them — do not add `forge fmt`, Prettier, or a new linter as part of a greenfield CI scaffold.

Minimal set:

- [ ] CI is set up (GitHub Actions in `.github/workflows/` or an equivalent) and runs on PRs and pushes to the main branch.
- [ ] CI runs the test suite:
  - Hardhat 2 / Hardhat 3: `npx hardhat test`
  - Foundry: `forge test`
- [ ] If the repository already configures a linter (`solhint`, a `lint` script, etc.), CI runs it.
- [ ] If the repository already configures a formatter (`forge fmt`, Prettier / `prettier-plugin-solidity`, a `fmt`/`format` script, etc.), CI runs a check mode for it. ⚠️ Warning only when a formatter is configured in the repo but CI does not run it — absence of any formatter is not a finding.

Extended set (recommended):

- [ ] CI builds the contracts and fails on compilation errors/warnings (`npx hardhat compile` / `forge build`).
- [ ] Fuzz/invariant tests are included in the CI run, if present.
- [ ] Static analysis is enabled in CI (Slither and/or equivalents); critical findings fail the pipeline.
- [ ] Toolchain versions are pinned, the build is reproducible:
  - Hardhat: Node.js and Hardhat versions pinned (lock file, `engines`, `.nvmrc`), solc version pinned in `hardhat.config.*`.
  - Foundry: Foundry release pinned (not `nightly`/`latest`), solc version pinned in `foundry.toml`.
- [ ] Dependencies are pinned: a lock file (`package-lock.json`/`yarn.lock` — Hardhat) or pinned git submodules / remappings (Foundry).
- [ ] A test coverage report (`solidity-coverage` for Hardhat / `forge coverage`) and gas tracking (`hardhat-gas-reporter` / `forge snapshot`).
- [ ] Secrets (RPC keys, private keys) are not hardcoded in workflows — GitHub Secrets are used.

Workflow quality, branch protection, and required checks in detail belong to the separate GitHub review checklist, not to this one.

## 7. Issue and pull request templates

Templates are strongly recommended. ⚠️ Warning if issue templates or the PR template are missing.

- [ ] Issue templates exist (`.github/ISSUE_TEMPLATE/`): at minimum a bug report and a feature request.
- [ ] The bug report template asks for the environment: network, contract address, version, tx hash / reproduction steps.
- [ ] The templates carry an explicit warning: vulnerabilities go only through the channel in `SECURITY.md`, not through public issues.
- [ ] A PR template exists (`.github/PULL_REQUEST_TEMPLATE.md`) with a checklist: tests added, documentation updated, gas effects assessed, storage layout not broken (for upgradeable contracts).
- [ ] (Recommended) A `config.yml` for issue templates: blank issues enabled, a security contact link to `SECURITY.md`, and optionally Discord/forum for questions.



## 8. Release process

- [ ] Releases are versioned: git tags + GitHub Releases, semver (or a documented alternative).
- [ ] A `CHANGELOG.md` is maintained (or release notes in GitHub Releases) describing the changes in each version.
- [ ] Every contract deployed to production corresponds to a tag/commit in the repository — bytecode can be unambiguously matched to sources.
- [ ] Contracts are verified on Etherscan/Blockscout/Sourcify for all production deployments (at least once).
- [ ] Deployment addresses are recorded in `deployments.md` (preferred) with one section per chain (`## <chain name> (<chain id>)` and a `| Contract | Address |` table). A `deployments/` directory of raw records, or an equivalent README table, is acceptable only when `deployments.md` is absent.
- [ ] Deployment scripts live in the repository (in `deploy/`, see section 2) and are reproducible; deployment parameters (constructors, roles, owners) are documented.
- [ ] For upgradeable contracts: the upgrade process is documented (timelock, multisig, governance), and a storage layout compatibility check is part of the release process.
- [ ] Breaking changes and migration guides are described for major releases.
- [ ] If an npm package is published (interfaces/SDK) — the package version is synchronized with the repository tags.

---

## 9. AI agent guidance

Coding agents (Cursor and similar) should get a short, repo-specific brief so they do not invent a toolchain or touch the wrong paths.

- [ ] (Recommended) An `AGENTS.md` file exists at the repository root.
- [ ] (Recommended) It states what the repository is, which toolchain to use, how to build and test (and lint/format only if the repo already configures those), where contracts, tests, scripts and docs live, and any agent constraints (secrets, SPDX, bytecode-affecting compiler flags).
- [ ] (Recommended) Project-specific hazards an agent would not infer from the tree alone are called out (upgradeability, privileged roles, intentional layout exceptions).

---

## Additional files and conventions

- [ ] `.gitignore` — build artifacts are excluded (`out/`, `cache/`, `artifacts/`, `node_modules/`), along with `.env` and any keys.
- [ ] No secrets in git history or in the repository: private keys, mnemonics, API keys (including in tests and scripts — only well-known public test keys).
- [ ] `audits/` — audit reports are stored in the repository (in addition to the mandatory layout from section 2).
  - May be absent — it is a warning.
- [ ] Toolchain configuration at the root: `hardhat.config.*` (Hardhat 2/3) / `foundry.toml` (Foundry) with a pinned solc version, optimizer settings, and evm_version.
- [ ] The default branch is protected: branch protection, mandatory reviews, and required checks (covered in detail by the separate GitHub review checklist, but their absence is a signal at the repository organization level too).
