# Fix catalogue

What fix mode may do about each finding, and what it must refuse. Read this before applying anything; `SKILL.md` owns the procedure, this file owns the recipes.

Every fix names the checklist section it closes, so no fix is applied without a finding behind it.

## Two kinds of placeholder

Templates in `templates/` carry two markers, and they are not interchangeable.

- `{{NAME}}` — filled from repository facts. Never leave one in a written file; if a value cannot be resolved, the fix does not apply. A placeholder that occupies a whole line and resolves to nothing takes that line and the blank line after it, rather than leaving a hole behind — `{{STORAGE_LAYOUT_ITEM}}` in a repository without upgradeable contracts would otherwise leave an empty bullet in the checklist.
- `TODO(repository-review): <what is needed and who knows it>` — needs a human. Left in place deliberately, collected at the end of the run by `rg -n 'TODO\(repository-review\)'`.

TODO markers stay **visible** in rendered output rather than hidden in HTML comments. An unfinished `SECURITY.md` that renders as though it were complete is worse than an obviously unfinished one.

In YAML files a TODO must be a `#` comment, and any key GitHub validates — a `url:` in `config.yml`, for instance — must either hold a real value or be commented out entirely. GitHub rejects the whole file otherwise.

## Values resolved from the repository

| Placeholder | Source |
|---|---|
| `{{SLUG}}` | `git remote get-url origin`, reduced to `owner/repo` |
| `{{DEFAULT_BRANCH}}` | `git symbolic-ref --short refs/remotes/origin/HEAD`, else the current branch |
| `{{WORKFLOW_FILE}}` | the CI workflow file name under `.github/workflows/` |
| `{{LICENSE_NAME}}`, `{{LICENSE_PATH}}` | the licence file and the identifier its SPDX headers agree on |
| `{{SOLC_VERSION}}` | `solc_version` in `foundry.toml` or `solidity.version` in `hardhat.config.*` |
| `{{FOUNDRY_VERSION}}` | `foundry.lock` when present, otherwise `stable` plus a TODO to pin a release |
| `{{NODE_VERSION}}` | `.nvmrc`, `engines.node`, or the `node-version` already used in CI; else `20` |
| `{{PACKAGE_MANAGER}}`, `{{INSTALL_COMMAND}}` | the lock file present (`yarn.lock` → yarn, `package-lock.json` → npm, `pnpm-lock.yaml` → pnpm) |
| `{{BUILD_COMMAND}}`, `{{TEST_COMMAND}}` | `package.json` scripts, `Makefile` targets, or the Foundry defaults `forge build` / `forge test` — never invent a formatter default |
| `{{LINT_COMMAND}}` | only if the repo already has a linter: a `lint` / `solhint` script in `package.json`, Makefile, or CI. Empty when none — do not invent `solhint` or `forge fmt` |
| `{{FORMAT_COMMAND}}` | only if the repo already has a formatter: `fmt` / `format` / `prettier` script, Prettier config used on Solidity, or an existing `forge fmt` (or equivalent) in CI/docs. Empty when none — **never** default to `forge fmt --check` or Prettier |
| `{{CI_LINT_JOB}}`, `{{CI_FORMAT_JOB}}` | full CI job YAML when the matching command is set; empty when not — greenfield CI is build + test only. Example format job for Foundry when `forge fmt` is already used: a `format` job with `run: forge fmt --check`. Example lint job when `solhint` is configured: a `lint` job running that command |
| `{{LINT_SECTION}}` | when `{{LINT_COMMAND}}` is set, a `### Lint` heading plus a bash fence with that command; empty otherwise |
| `{{FORMAT_SECTION}}` | when `{{FORMAT_COMMAND}}` is set, a `### Format` heading plus a bash fence with that command; empty otherwise |
| `{{REPO_NAME}}` | the repository name from the remote, else the directory name |
| `{{TOOLCHAIN_NAME}}`, `{{TOOLCHAIN_CONFIG}}` | `Foundry` with `foundry.toml`, or `Hardhat 2` / `Hardhat 3` with `hardhat.config.*` |
| `{{PREREQUISITES}}` | the install steps for that toolchain — foundryup for Foundry, Node plus the package manager for Hardhat |
| `{{STRUCTURE_ROWS}}` | one `\| path \| contents \|` row per top-level directory that exists |
| `{{LICENSE_BADGE}}` | `{{LICENSE_NAME}}` with every hyphen doubled, because shields.io reads a single `-` as a separator: `BUSL-1.1` becomes `BUSL--1.1` |
| `{{SECURITY_PATH}}` | the path to `SECURITY.md` relative to the file being written |
| `{{DOCS_LINK}}` | a markdown link to the documentation — `[the docs](docs/)` when `docs/` exists, otherwise `[the README](README.md)` — phrased to read inside a sentence |
| `{{SECURITY_URL}}` | the absolute `https://github.com/{{SLUG}}/blob/{{DEFAULT_BRANCH}}/SECURITY.md`, because `config.yml` needs a resolvable URL |
| `{{GAS_HINT}}` | a parenthetical naming the repository's gas command, such as `` (`forge snapshot --check`) ``; empty when there is none |
| `{{STORAGE_LAYOUT_ITEM}}` | the storage-layout checklist line, only for repositories with upgradeable contracts; empty otherwise, leaving no blank bullet behind |
| `{{RELEASE_ENTRIES}}` | one entry per tag, newest first, dated from the tag, each carrying a TODO for the summary and the `git log a..b --oneline` range that lists its commits |
| `{{DEPLOYMENT_SECTIONS}}` | one `## <chain name> (<chain id>)` section per network, each with a `\| Contract \| Address \|` table filled from parseable deployment records |
| `{{AUDIT_LINKS}}` | a markdown bullet list of audit report links — from local `audits/`, README links, or matching folders/files under [1inch/1inch-audits](https://github.com/1inch/1inch-audits); the audits TODO sentence only when none of those yield a match |
| `{{REPO_SUMMARY}}` | two or three sentences on what the repository is, derived from the README opening and package/repo name; a TODO when that cannot be stated faithfully |

Resolve these from the facts already collected in step 2 and from the files read in step 3. Do not guess a value that is not there.

---

# Bucket 1 — mechanical, one fix at a time

Agree the list once, then apply in the order below: `deployments.md` before `SECURITY.md` (SECURITY links to it), then `SECURITY.md` before the artifacts that link to SECURITY. Each fix is written, stopped for user review, and committed only on an explicit yes — see `SKILL.md` step F3. Agreement on the list is not permission to commit.

### 1. `deployments.md` — closes §8.5, preferred for §1.6

When deployment records exist but no readable summary does, write `templates/deployments.md` with one section per chain:

```markdown
## <chain name> (<chain id>)

| Contract | Address |
|---|---|
| <name> | <0x...> |
```

Map network folder names to a human chain name and numeric chain id when known (e.g. `ethereum` / `mainnet` → `Ethereum (1)`, `arbitrum` → `Arbitrum One (42161)`). Skip any record whose address cannot be resolved rather than guessing: a raw `CREATE3` broadcast names the deployer call, not the resulting contract. Do not put version/commit/date columns in this table — Contract and Address only.

- **Precondition:** parseable deployment records exist (`deployments/`, broadcast JSON, or equivalent), and neither `deployments.md` nor a README deployment table exists. If a README table exists but `deployments.md` does not, prefer extracting into `deployments.md` and replacing the README table with a link to it when the user accepts this fix.
- **Files:** `deployments.md` (and `README.md` only when replacing an inlined table with a link)

### 2. `SECURITY.md` — closes §5

Copy `templates/SECURITY.md` to the repository root. The template already carries the org-wide disclosure channel (`security@1inch.com`), the HackenProof and Immunefi programme links (scope, payouts and SLAs), the hiring link, and a link to `deployments.md` for supported deployments — do not blank those out.

**Audits — search before leaving a TODO.** Fill `{{AUDIT_LINKS}}` in this order; stop at the first source that yields at least one report:

1. PDFs or links under local `audits/` / `docs/audits/`.
2. Audit links already in the README.
3. [1inch/1inch-audits](https://github.com/1inch/1inch-audits) — use GitHub tools to list top-level folders and match this repository by product/repo name (README title, `package.json` name, remote slug). Link the matching folder (`https://github.com/1inch/1inch-audits/tree/master/<folder>`) and, when individual PDFs are obvious, link those too.

Only if all three miss: set `{{AUDIT_LINKS}}` to `TODO(repository-review): link the audit reports, or state that the code has not been audited.`

If `deployments.md` is missing and could not be generated in fix 1, replace the Supported versions paragraph with a TODO asking for the support scope instead of a broken link.

Leave the known-limitations TODO unless the audits already document accepted risks that can be copied faithfully.

- **Precondition:** no `SECURITY.md` at the root, in `.github/` or in `docs/`.
- **Files:** `SECURITY.md`
- **Note:** this file's remaining TODOs must lead the closing list. Contact, bounty, SLAs and (when found) audits are filled; what may remain is known limitations — which is why fixes land on a branch for review rather than on the default branch.

### 3. Issue and PR templates — closes §7

Copy `templates/ISSUE_TEMPLATE/bug_report.yml`, `feature_request.yml` and `config.yml` into `.github/ISSUE_TEMPLATE/`, and `templates/PULL_REQUEST_TEMPLATE.md` into `.github/`. Fill `{{SECURITY_URL}}` in `config.yml`. `config.yml` enables blank issues and adds a security contact link so the chooser matches Foundry's layout: Bug report, Feature request, Open a blank issue, Report a security vulnerability. Drop the storage-layout checkbox from the PR template unless the repository has upgradeable contracts.

- **Precondition:** per file — write only the ones that do not exist. An existing PR template is extended with the missing checklist items rather than overwritten.
- **Files:** `.github/ISSUE_TEMPLATE/*.yml`, `.github/PULL_REQUEST_TEMPLATE.md`

### 4. `CONTRIBUTING.md` — closes §4

Copy `templates/CONTRIBUTING.md` to the root, filling the command placeholders from the toolchain and the issue links from the remote. Include `{{LINT_COMMAND}}` / `{{FORMAT_COMMAND}}` only when those tools are already configured in the repository; leave the placeholder lines empty otherwise so they drop out. The structure follows [contributing.md](https://contributing.md/), with one deliberate departure: the vulnerability warning sits at the top rather than inside the bug-reporting advice, since on contracts holding funds it is the one paragraph a reader must not miss.

The test-policy line keeps its TODO — whether fuzz and invariant tests are mandatory is a team decision.

- **Precondition:** no `CONTRIBUTING.md` at the root or in `.github/`.
- **Files:** `CONTRIBUTING.md`

### 5. README repository-structure section — closes §1.4

Insert the structure snippet from `templates/readme-sections.md`, listing the top-level directories that actually exist with one line each.

- **Precondition:** `README.md` exists and has no section describing the layout.
- **Files:** `README.md`

### 6. README build and test section — closes §1.5

Insert the build/test snippet, naming the detected toolchain and the real commands. State the pinned solc version and, for Foundry, the pinned release. Include lint/format subsections only when `{{LINT_COMMAND}}` / `{{FORMAT_COMMAND}}` resolve.

- **Precondition:** `README.md` exists and names no build or test command.
- **Files:** `README.md`

### 7. README badges — closes §1.8, §1.9

Insert the badge block: CI status from the workflow file, licence from the licence file, solidity version from the pinned compiler. Add a coverage badge only when the repository already uploads coverage — a badge for a service that is not wired up is a broken image.

- **Precondition:** `README.md` exists and is missing at least one of these badges.
- **Files:** `README.md`

### 8. Missing `README.md` — closes §1.1 partially

When there is no README at all, write the skeleton from `templates/readme-sections.md` with the structure, build and badge sections filled and a TODO for the protocol description. What the protocol does is not derivable from the file system. When `deployments.md` exists, the Deployments section is a link to it rather than a second address table.

- **Precondition:** no README at the root.
- **Files:** `README.md`

### 9. Mixed-licence note — closes §3.5

When `.sol` files carry more than one SPDX identifier, add a short licensing note to the README naming which paths carry which identifier. This documents the state; it does not change any header.

- **Precondition:** more than one SPDX identifier across `.sol` files, and no existing note explaining it.
- **Files:** `README.md`

### 10. CI workflow — closes §6.1 to §6.4

With no CI at all, copy `templates/ci-foundry.yml` or `templates/ci-hardhat.yml` to `.github/workflows/ci.yml`, filling only build and test by default. Include `{{CI_LINT_JOB}}` / `{{CI_FORMAT_JOB}}` only when `{{LINT_COMMAND}}` / `{{FORMAT_COMMAND}}` resolve — do **not** add `forge fmt --check` or Prettier to a repo that does not already format. With CI present but tests (or an already-configured lint/format check) missing, add the missing job to the existing workflow instead — a smaller and safer edit than replacing it.

- **Precondition:** no workflow runs build or tests (or, when a linter/formatter is already configured in the repo, CI does not run it). Resolve indirection first: `yarn test:ci`, `make test` and local composite actions all count.
- **Files:** `.github/workflows/ci.yml` or the existing workflow
- **Note:** the workflow is written but never proved green here. Say so in the summary; the first CI run on the branch is the real check.

### 11. Toolchain version pins in CI — closes §6.7

Add `version:` to `foundry-rs/foundry-toolchain` and a `node-version` to `actions/setup-node`. Leave `.nvmrc` where it is: the checklist does not score it, so do not create one and do not edit one that exists.

- **Precondition:** the pin is absent. Never change a pin that is already set.
- **Files:** `.github/workflows/*.yml`

### 12. `.gitignore` — closes §A.1

Append the patterns missing for the detected toolchain: `out/`, `cache/`, `broadcast/` for Foundry; `artifacts/`, `cache/`, `typechain-types/` for Hardhat; `node_modules/`, `coverage/` and `.env*` for both. Append only — never remove or reorder existing lines.

- **Precondition:** at least one pattern is missing.
- **Files:** `.gitignore`

### 13. `CHANGELOG.md` skeleton — closes §8.2

Write `templates/CHANGELOG.md` with one entry per tag, newest first, dated from the tag. Each entry carries a TODO for the summary and the `git log` range that lists the commits. Do not write release notes from commit subjects — a generated summary that reads as though someone wrote it is worse than an honest TODO.

- **Precondition:** no `CHANGELOG.md`, and the repository has tags.
- **Files:** `CHANGELOG.md`

### 14. `AGENTS.md` — closes §9

Copy `templates/AGENTS.md` to the repository root. Fill toolchain, commands and layout from repository facts (same sources as the README snippets). Derive `{{REPO_SUMMARY}}` from the README's opening description when it is substantive; otherwise leave a TODO there. Soften or drop links to `deployments.md` / `SECURITY.md` / `CONTRIBUTING.md` when those files are absent and are not being added in this fix run. Leave the project-specific-notes TODO for the team.

- **Precondition:** no `AGENTS.md` at the root (and no `AGENT.md` / `.github/AGENTS.md` equivalent already serving the same role).
- **Files:** `AGENTS.md`
- **Note:** regenerate only when missing. Do not overwrite an existing `AGENTS.md` — team edits there are intentional.

---

# Bucket 2 — mechanical but breaking, confirmed one at a time

Each item is presented with what it changes and what it breaks, applied only on an explicit yes to apply, then committed only on a second explicit yes after the user has reviewed the diff — see `SKILL.md` step F4. Never batch these.

### 15. Contracts directory renamed to `contracts/` — closes §2.1

`git mv src contracts`, then update `foundry.toml` (`src =`), `remappings.txt`, Hardhat `paths.sources`, `package.json` `files`, CI globs and any lint globs.

- **Breaks:** every downstream repository that imports this one by path, and the layout of the published npm package. For a released protocol this is a breaking change for consumers, not a tidy-up.
- **Verify:** run the build; then grep the repository for the old path.

### 16. Tests directory renamed to `test/` — closes §2.2

`git mv tests test`, then drop the override that named the old directory — `test = "tests"` in `foundry.toml`, `paths.tests` in `hardhat.config.*` — since `test/` is where both toolchains look without being told. Update `package.json` scripts, `.solcover.js`, solhint globs and CI paths in the same commit.

- **Breaks:** less than the above — consumers do not import tests — but every local script naming the old path stops working.
- **Verify:** run the test suite.

### 17. Deployment scripts moved to `deploy/` — closes §2.3

- **Judgement first:** classify each script as deployment or not by reading it, not by its name. Present the classification for confirmation before moving anything.
- **Breaks:** `Makefile` targets, `package.json` scripts and documentation that name the old paths; Foundry's `--broadcast` invocations.
- **Verify:** run the build; dry-run a deploy script only if the user asks.

### 18. Non-deployment scripts moved to `scripts/` — closes §2.5

Same as above, with the same classification step.

### 19. Documentation moved to `docs/` — closes §2.4

- **Check first:** if the directory is generator output — `forge doc --out`, a docgen target — renaming it alone is undone by the next generator run. Change the generator configuration in the same commit. If the generator emits HTML, that output must not be committed; point it at Markdown or keep HTML as a CI artifact only (see §2.4 format rule).
- **When writing docs:** new documentation files are Markdown only. Never scaffold an HTML/CSS/JS docs site as a fix.
- **Files:** the directory, plus `foundry.toml` or the docgen config.

### 20. Slither in CI — closes §6.6

Add a static-analysis job to the workflow.

- **Breaks:** the first run will almost certainly report findings and turn CI red. Adding the job is the small part; triaging the findings is the work.
- **Suggest:** land it non-blocking first, then make it required once the backlog is clear.

### 21. Fuzz and invariant tests in the CI run — closes §6.5

Remove the exclusion that keeps them out, or add a job that runs them.

- **Breaks:** CI runtime grows, and flaky invariants surface as failures.

### 22. Compiler pins in the toolchain config — closes §A.4

Add a missing `solc_version`, `optimizer` setting or `evm_version`.

- **Breaks:** changing `optimizer_runs` or `evm_version` changes the produced bytecode. For a repository with live deployments this breaks the match between sources and deployed code. Adding a pin that records what is already used is safe; changing a value is not. State which of the two the change is before asking.

### 23. `LICENSE` file when the SPDX headers are unanimous — closes §3.1, §3.2

Write the standard text of the identifier every `.sol` file already declares.

- **Needs from the user:** the copyright holder and year. Ask for both; do not infer a legal entity from the npm scope.
- **Refuse when:** headers disagree, or there are none. Choosing a licence is not a formatting decision.

---

# Bucket 3 — reported, never fixed

Say what is missing, why the skill will not supply it, and who can.

**Needs data only the team has.** Known limitations carried over from audits (§5.6); links to documentation, audits and the bounty in the README (§1.7) — bounty URLs match `SECURITY.md`, audit links should match what fix mode found under `audits/`, the README, or [1inch/1inch-audits](https://github.com/1inch/1inch-audits); the 1inch logo asset when it is not already in the repository (§1.2); the Discord or forum link in `config.yml` (§7.5). The disclosure email, bug bounty programme links and response SLAs are org-wide defaults already in `templates/SECURITY.md` (SLAs live on the linked programme pages) — do not ask for them again. Audit report links (§5.5) are searchable in fix mode; leave them for a human only when local docs, the README and `1inch/1inch-audits` all miss.

**Needs a decision by the owner.** Which licence applies (§3.1, §3.2); BUSL Change Date and Change License (§3.4); which versions and deployments are supported (§5.4); upgrade governance — timelock, multisig, who may execute (§8.7). Do not decide to adopt a formatter or linter the repository does not already use.

**Needs access outside the repository.** GitHub Releases and tags (§8.1); verification on Etherscan, Blockscout or Sourcify (§8.4); npm publication and version sync (§8.9); branch protection (§A.5); a Codecov token (§6.9); enabling GitHub Private Vulnerability Reporting (§5.2).

**Fixing it would be wrong.** Rewriting SPDX headers (§3.3): for vendored third-party files — an LGPL mock, a copied library — changing the header is a licence violation, and for the rest the correct direction is a legal question. Hardcoded secrets (§6.10, §A.2): the fix is rotating the key and rewriting history, not editing the file. Report it as an incident and stop; do not quietly delete the line, which leaves the secret live in history and hides that it leaked.

**A process or a verification, not an artifact.** Whether the README is actually up to date, its links resolve and its commands work (§1.10); deployed bytecode matching a tag (§8.3); reproducibility of deployment scripts and documented parameters (§8.6); migration guides between major versions (§8.8); the protocol description itself (§1.1, §1.3) — a draft is possible, the substance is the team's. HTML/CSS/JS documentation sites checked into the repository (§2.4): report them; converting or dropping a docs site is an editorial decision, not a mechanical fix.
