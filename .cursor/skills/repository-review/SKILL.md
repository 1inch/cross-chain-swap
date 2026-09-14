---
name: repository-review
description: Reviews the repository this skill is installed in against the bundled Solidity repository-organization checklist (README, directory layout, LICENSE, CONTRIBUTING, SECURITY, CI, issue and PR templates, release process, AGENTS.md, additional conventions), reporting a weighted 0-100 score, per-check results backed by evidence, and a prioritized list of what to add first; a second mode then applies the mechanically safe fixes on a branch. Use when the user asks to review, check, audit, or score the organization or structure of this Solidity or smart-contract repository, and when they ask to fix the repository structure, apply the review findings, add the missing files, or mentions repository review, repo review, repo checklist, or the repository-review rules.
---

# Repository Review

Scores this repository — the one this skill is installed in — against `RULES.md`, and reports three things: a summary score, the per-check results, and what to fix first. On request it then applies the fixes it can make safely.

Write the report in English, whatever language the request was in.

Scope stops at repository organization. Workflow quality, branch protection and required checks in depth belong to a separate GitHub review; where they surface here, record them and say which review covers them properly rather than expanding this one.

## Modes

**Review** is the default and changes nothing. Steps 1-5 below: score the repository, deliver the report, offer to save it.

**Fix** runs only on an explicit request to change the repository — "fix what you can", "apply the findings", "add the missing files". Steps F1-F6 apply the fixes catalogued in `FIXES.md` on a branch, one commit per fix after the user has reviewed that fix's diff, and explain everything they will not touch. Never enter fix mode because the score was low; a report is not permission to edit.

## Review workflow

Copy this checklist and keep it updated as you go:

```
- [ ] Step 1: Read the checklist
- [ ] Step 2: Collect repository facts
- [ ] Step 3: Read the files that need judgement
- [ ] Step 4: Score every check
- [ ] Step 5: Write the report
```

### Step 1 — Read the checklist

Read `RULES.md`, next to this file, in full. It owns the exact wording and severity of every check; this file owns only the method and the report. Never score from memory of it.

### Step 2 — Collect repository facts

The subject of the review is the repository this skill is installed in, from its root — not the directory the shell happens to start in. One read-only pass gathers everything the file system can answer:

```bash
bash .cursor/skills/repository-review/scripts/collect-facts.sh
```

Adjust the path if this skill sits elsewhere; it lives next to `RULES.md`. With no argument the script resolves the repository root itself through `git rev-parse --show-toplevel`, so it works from any working directory. Pass a path only to review a different checkout.

The output covers root entries, the directory layout, toolchain and pins, SPDX headers, `.github` contents, CI keywords per workflow, tags and changelog, `.gitignore` coverage, a secret-scan heuristic, and signals from README / CONTRIBUTING / SECURITY. It excludes `.cursor/`, so the skill does not review itself.

The script reports shape, not quality. Never score a content check from it alone.

### Step 3 — Read the files that need judgement

Determine the toolchain first — Hardhat 2, Hardhat 3, or Foundry — from `hardhat.config.*`, the `hardhat` version in `package.json`, and `foundry.toml`. Every command-level check has per-toolchain variants in the checklist; apply the ones that match. A repository may legitimately use both.

Then read, in full: `README.md`, `deployments.md` when present, `AGENTS.md` when present, the `LICENSE` header, `CONTRIBUTING.md`, `SECURITY.md`, every file in `.github/workflows/`, the issue and PR templates, the toolchain config, and `CHANGELOG.md`. Prefer `deployments.md` over README address tables when judging deployment checks. For the SECURITY audits check, also look for a matching folder under [1inch/1inch-audits](https://github.com/1inch/1inch-audits) when local `audits/` and README links are empty.

**Resolve CI indirection before judging any CI check.** Workflow steps rarely name the underlying tool: `run: yarn test:ci`, `run: make test`, or a local composite action under `.github/actions/` all satisfy the test check. Follow each `run:` line through `package.json` scripts, the `Makefile`, and any local action's `action.yml` before recording a step as absent. A repository whose CI runs `yarn lint` where `lint` is `solhint --max-warnings 0` passes the linter check.

**Formatters and linters are opt-in from the repo.** Detect whether the tree already uses a formatter (`fmt`/`format`/`prettier` scripts, Prettier config applied to Solidity, or an existing `forge fmt` in CI/docs) or a linter (`solhint`, a `lint` script). Score and scaffold those checks only when present. Never treat missing `forge fmt` or Prettier as a finding, and never add them when generating CI or docs for a repo that does not already format.

For "the README is up to date", check that documented commands exist as `package.json` scripts, Foundry defaults, or config targets. Do not run builds or tests unless the user asks for a deep check.

### Step 4 — Score every check

**Severity.** The checklist marks items ❌ Error or ⚠️ Warning; an explicit mark always wins. Otherwise:

- An unmarked item is an error.
- An item marked "(Recommended)", or hedged with "may" or "optionally", is a warning.
- Section-level exceptions in the checklist text win over both: no CI at all, no tests at all, missing templates, and a missing `audits/` are warnings.

An item phrased "X, or Y" — addresses listed per network *or* a link to a deployments file, the bounty described *or* stated not to exist — offers two ways to satisfy one check. Either satisfies it; neither lowers its severity.

**Absent required files.** When a required document does not exist, every item in its section fails and the section scores zero — but report it as one finding naming the checks that fall with it, and count it once in the header tally. Six errors for one missing `CONTRIBUTING.md` makes the tally useless.

**Conditional items.** Several checks apply only when something exists — deployment scripts must live in `deploy/` *if there are any*, upgrade documentation is required *for upgradeable contracts*, npm versioning matters *if a package is published*, linter/formatter checks and docs apply *only if the repository already configures those tools*. When the condition does not hold, drop the item from the section's possible points. Do not score it as a pass and do not penalize the repository for it.

**Per-item points.** Error items are worth 2 points, warning items 1. Award full points for a pass, half for a partial pass, zero for a fail.

**Per-section score.** `weight × earned points ÷ possible points`, rounded to one decimal.

| # | Section | Weight |
|---|---------|--------|
| 1 | README.md | 14 |
| 2 | Repository structure | 14 |
| 3 | LICENSE | 9 |
| 4 | CONTRIBUTING.md | 8 |
| 5 | SECURITY.md | 15 |
| 6 | CI configuration | 15 |
| 7 | Issue and pull request templates | 7 |
| 8 | Release process | 10 |
| 9 | AI agent guidance | 3 |
| — | Additional files and conventions | 5 |
| — | **Total** | **100** |

Worked example — section 3 has five items, all errors. Two do not apply because the license is MIT: the BUSL transition terms and the mixed-license documentation drop out, leaving three items and 6 possible points. Two pass, and SPDX consistency is half-met because one contract declares `LGPL-3.0-only` where `LICENSE` says MIT. Earned is 5, so the section scores `9 × 5 ÷ 6 = 7.5` out of 9.

**Unverifiable checks.** Some checks need access the file system does not have: branch protection, GitHub Releases, Etherscan verification, whether links resolve. Try the available tools first — the GitHub tools for tags, releases, templates and branch protection; the Etherscan tools to spot-check verification for at most three of the addresses the README lists. What remains unchecked is excluded from that section's possible points and listed under "Unverified". Never score it as a pass.

**Grade.** 90-100 → A, 75-89 → B, 60-74 → C, 40-59 → D, below 40 → F. A repository with any unresolved error cannot get an A; cap it at B.

### Step 5 — Write the report

Use this structure exactly:

```markdown
# Repository review — <repo name> (<toolchain>)

**Score: 63.4 / 100 — C** · 5 errors · 8 warnings · 3 checks unverified

<Two to four sentences: the state of the repository's organization, the gap that matters most, and the cheapest thing that would move the score.>

## Score by section

| # | Section | Score | Weight | Errors | Warnings |
|---|---------|-------|--------|--------|----------|
| 1 | README.md | 9.0 | 14 | 1 | 2 |
| … | … | … | … | … | … |
| — | **Total** | **63.4** | **100** | **5** | **8** |

## Findings

### 1. README.md — 9.0 / 14

- ❌ No build or test instructions. The project is Foundry (`foundry.toml:1`) and `README.md` names no commands.
- ⚠️ No coverage badge (`README.md:1-6` has CI and license only).
- ✅ Passed: root README present and substantive, protocol description, repository layout, deployed addresses per network, links to docs and audits.

### 2. Repository structure — 7.0 / 14

- ❌ Contracts live in `src/`, not `contracts/` (34 `.sol` files under `src/`).
- …

## Fix first

1. **Add `SECURITY.md` at the root** — the protocol holds user funds and there is no private disclosure channel, so a reporter's only option today is a public issue. Needs a contact address, the bounty scope or an explicit statement that there is none, supported deployments, and audit links. Worth 15 points. ~30 min.
2. …

## Then

- <Next tier, one line each.>

## Fixable now

7 of these findings can be applied automatically — issue and PR templates, `CONTRIBUTING.md`, the README structure and build sections, badges, `.gitignore`. Ask and they land on a branch one at a time, each committed only after you have reviewed it.

## Unverified

- Branch protection on the default branch — needs repository admin access.

---
Reviewed at 837c8f8 on master, working tree clean.
```

Rules for the body:

- **Every ❌ and ⚠️ carries evidence** — a path, a line number where one applies, or the command that produced it. A check you did not perform is unverified, not a pass.
- **List failures individually, collapse passes.** One bullet per error and warning; a single `✅ Passed:` bullet per section naming what was satisfied.
- **Order within a section:** errors, then warnings, then the passed line.
- **Say what to do, not just what is wrong.** Each failure bullet ends in the concrete change: the file to add, the section to write, the directory to rename.
- **Fix first holds at most five items**, ordered by score impact per unit of effort, errors before warnings when impact ties. Each gives the change, why it matters for this repository specifically, the points at stake, and rough effort.
- **Fixable now** counts the findings that fall in bucket 1 of `FIXES.md` and names them in a sentence. Omit the section when there are none. It exists so the user learns fix mode is available without reading the skill.
- **The closing stamp** records `git rev-parse --short HEAD`, the branch, and whether the tree was clean. It says what was actually examined, survives into a saved report, and lets fix mode decide later whether this review still holds.
- **No score without the findings behind it.** Do not deliver the number alone.

### Saving the report

Deliver the report in chat first, then ask whether to save it. Offer `repository-review.md` at the repository root as the default name and accept another path. On no, save nothing — the chat copy is the deliverable.

Saving is the one write review mode may perform, and only after that answer. Everything else in steps 1-5 is read-only.

## Fix workflow

Only on an explicit request to change the repository. Copy this checklist and keep it updated:

```
- [ ] Step F1: Establish the findings
- [ ] Step F2: Preflight and branch
- [ ] Step F3: Bucket 1 — one fix at a time, review then commit
- [ ] Step F4: Bucket 2 — one item at a time, review then commit
- [ ] Step F5: Verify
- [ ] Step F6: Summarise
```

Read `FIXES.md` before touching anything. It holds the recipe for every fix, the values each template needs, and the reasons behind every refusal.

Four rules hold for the whole run:

- **Never touch `.cursor/`.** The skill is not part of the protocol and does not edit itself.
- **Never rewrite an SPDX header.** In a vendored third-party file changing it is a licence violation, and elsewhere the correct direction is a legal question. Report the mismatch; document it if asked.
- **Never edit a file to remove a hardcoded secret.** Deleting the line leaves the key live in history and hides that it leaked. Stop, report it as an incident, say that it needs rotating.
- **Append, do not rewrite.** Existing files get missing pieces added — a `.gitignore` pattern, a checklist item, a CI job. Overwrite only a file that does not exist yet.
- **Write, stop, review, then commit.** Never commit in the same turn as the write. After each fix is applied, stop: name the files changed, show a short diff summary, propose the commit subject, and ask the user to review. Commit only on an explicit yes to that commit. If they want edits, change the files and ask again. If they decline, revert that fix's uncommitted changes and move on — do not leave a half-applied fix sitting uncommitted while starting the next one. The same gate applies after F5 if verification produced further edits.
- **Documentation is Markdown or PDF, never a web page.** Anything this skill writes as documentation is a `.md` file (root or `docs/`). Do not create or commit `.html`, `.htm`, `.css`, or documentation JavaScript, and do not check in HTML output from mdBook, `forge doc`, or similar. Whitepapers and math-heavy papers may be PDF; the skill does not author PDFs — link an existing one or leave a TODO.

Stop between stages as well. After F2 (branch ready), after the last bucket 1 commit, and after the last bucket 2 commit, say what the next stage will do and wait for a go-ahead before starting it. Do not chain F3 → F4 → F5 → F6 in one turn.

### Step F1 — Establish the findings

Fix mode acts on findings, never on a hunch. If a review already ran in this session, reuse it rather than repeating it — the expensive part is steps 3-4, and repeating them because the user typed "now fix it" is pure waste.

Reuse when all three hold: a review exists in this session, `git rev-parse --short HEAD` still matches its closing stamp, and the tree is clean. Run the full review first when there is no review in this session, `HEAD` moved, the tree was dirty when the review ran, or the user edited files in between. When in doubt, re-run — a stale finding produces a wrong edit.

### Step F2 — Preflight and branch

```bash
git status --porcelain
```

Anything in the output stops fix mode: report what is uncommitted and let the user commit or stash first. Mixing generated fixes into someone's work in progress makes both impossible to review.

Then branch from the current commit:

```bash
git switch -c chore/repository-review-fixes
```

If the branch already exists, say so and ask whether to continue on it or pick another name.

When the branch is ready, stop and ask before starting F3.

### Step F3 — Bucket 1, one fix at a time

List every bucket 1 fix that applies, each as one line naming the file it writes and the checklist section it closes. Ask once for the whole list; the user may strike individual items before agreeing. That agreement is permission to *start* the list, not to commit anything.

Then apply them in the order given in `FIXES.md`, and for each one:

1. Re-check the precondition immediately before writing. Reuse or not, the file may have appeared since the review, and fixes inside one run affect each other — `deployments.md` before `SECURITY.md` (SECURITY links to it), then `SECURITY.md` before `CONTRIBUTING.md` and the PR template.
2. Fill every `{{NAME}}` from repository facts. A template written with an unresolved `{{NAME}}` is a bug; skip the fix and report why instead.
3. Leave `TODO(repository-review)` markers exactly where the template puts them.
4. Stop. Show the changed paths, a short diff summary, and the proposed commit subject (e.g. `chore(repo-review): add SECURITY.md skeleton`). Wait for an explicit yes before committing. On edits requested, apply them and ask again. On no, revert this fix's uncommitted changes and continue to the next item.
5. Only after that yes: commit on its own. Then continue to the next item in a later turn — do not write the next fix in the same turn as the commit.

After the last bucket 1 item is done or skipped, stop and ask before starting F4.

### Step F4 — Bucket 2 one item at a time

Never batch these. For each, state in one short block: what changes, what it breaks, and how it will be verified. Then ask whether to apply it. A no moves to the next item and is recorded in the summary, not argued with.

Two of them need work before the question can even be asked. Moving scripts into `deploy/` or `scripts/` requires classifying each script by reading it rather than by its name — present that classification for confirmation first. Adding a compiler pin requires knowing whether it records what is already used or changes it, because changing `optimizer_runs` or `evm_version` changes the bytecode; say which of the two it is.

On yes to apply: make the change (renames through `git mv` so history follows the file), then stop for the same review-then-commit gate as F3 — show the diff summary and proposed subject, commit only on an explicit yes, revert on no. Do not start the next bucket 2 item in the same turn as a commit.

After the last bucket 2 item, stop and ask before starting F5.

### Step F5 — Verify

After any change to the layout, the toolchain config or CI, run the build and the test suite — `forge build` and `forge test`, or the repository's own `package.json` scripts. Grep for the old path after a rename; a passing build does not prove that a `Makefile` target or a documentation link still resolves.

Report a red build as a red build. Do not repair it by reverting quietly, and do not describe an unverified change as done: a generated CI workflow has never run, and the first push is its real test.

If verification produces further edits, stop for the review-then-commit gate before those edits become a commit. When verification is finished, stop and ask before F6.

### Step F6 — Summarise

Close with four things:

- **Applied** — one line per commit, with its subject and the section it closes.
- **Left for a human** — the output of `rg -n 'TODO\(repository-review\)'`, grouped by file, `SECURITY.md` first. Each line says what value is missing and who would know it.
- **Declined or skipped** — bucket 1 or 2 items the user said no to (apply or commit), and fixes whose precondition had changed.
- **Not fixable here** — the bucket 3 findings from this repository with their reasons, in one or two sentences each.

Then say what the score would become once the applied fixes are merged and the TODOs filled in, and offer to open a pull request. Do not re-run the review to produce that number; it is an estimate from the findings already in hand, and say so. Opening a PR also waits for an explicit yes.

## Additional resources

- `RULES.md` — the checklist itself, read in step 1.
- `FIXES.md` — the fix catalogue, read before step F3.
- `templates/` — the artifacts fix mode writes.
- `scripts/collect-facts.sh` — the fact-collection pass from step 2. Read it if you need to know exactly what a line of its output means.
