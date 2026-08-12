#!/usr/bin/env bash
# Fact collection for the repository-review skill. Read-only: nothing is written
# to the repository under review.
#
# Usage: bash collect-facts.sh [repo-path]
#
# With no argument the repository root is resolved from the working directory, so
# the skill reports on the repository it is installed in however deep the shell
# starts.

set -u

if [ $# -ge 1 ]; then
  TARGET="$1"
else
  TARGET="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
fi

cd "$TARGET" 2>/dev/null || { echo "ERROR: cannot enter '$TARGET'"; exit 1; }
ROOT="$(pwd -P)"

hdr() { printf '\n=== %s ===\n' "$1"; }
kv() { printf '%-30s %s\n' "$1" "$2"; }
yn() { if [ -e "$1" ]; then echo "present"; else echo "MISSING"; fi; }
lines() { wc -l < "$1" | tr -d ' '; }
n() { wc -l | tr -d ' '; }

# pfind <name-glob> [find action...] — find with dependency and build dirs pruned.
# Batching forms (xargs, -exec ... {} +) need sysconf(_SC_ARG_MAX), which sandboxed
# shells may deny, so callers pass one-at-a-time actions such as -exec ... \;
pfind() {
  glob="$1"
  shift
  find . \
    \( -name .git -o -name .cursor -o -name node_modules -o -name lib -o -name out \
    -o -name cache -o -name artifacts -o -name build -o -name coverage \
    -o -name broadcast -o -name typechain -o -name typechain-types -o -name .venv \) -prune -o \
    -type f -name "$glob" "$@" 2>/dev/null
}

pf() { pfind "$1" -print | sed 's|^\./||'; }

top_dirs() { awk -F/ '{ if (NF==1) print "(root)"; else print $1 }' | sort | uniq -c | sort -rn; }

# locate_doc <label> <extended regex for the basename>
# Reports the names as they exist on disk, so a case-insensitive file system does
# not turn one README into two.
locate_doc() {
  hits="$(find . .github docs -maxdepth 1 -type f 2>/dev/null \
    | sed 's|^\./||' | grep -iE "(^|/)($2)$" | sort -u | tr '\n' ' ')"
  if [ -n "$hits" ]; then kv "$1" "$hits"; else kv "$1" "MISSING"; fi
}

doc_report() {
  f="$1"; shift
  echo "-- $f --"
  if [ ! -f "$f" ]; then echo "MISSING"; return; fi
  kv "lines" "$(lines "$f")"
  grep -nE '^#{1,4} ' "$f" 2>/dev/null
  for k in "$@"; do
    kv "  /$k/" "$(grep -ciE "$k" "$f" | tr -d ' ') hit(s)"
  done
}

hdr "REPO"
kv "path" "$ROOT"
kv "name" "$(basename "$ROOT")"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  kv "git" "yes"
  kv "remote origin" "$(git config --get remote.origin.url 2>/dev/null || echo none)"
  kv "current branch" "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  kv "origin/HEAD" "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo unknown)"
  kv "HEAD commit" "$(git log -1 --format='%h %ad %s' --date=short 2>/dev/null)"
  kv "tracked files" "$(git ls-files | n)"
  kv "commits" "$(git rev-list --count HEAD 2>/dev/null || echo unknown)"
else
  kv "git" "no"
fi

hdr "ROOT ENTRIES"
ls -A | grep -vE '^(node_modules|\.git|out|cache|artifacts|coverage|typechain(-types)?|broadcast)$'

hdr "REQUIRED DOCUMENTS (root, .github/, docs/)"
locate_doc "README" 'readme(\.md|\.rst|\.txt)?'
locate_doc "LICENSE" 'licen[cs]e(\.md|\.txt)?|copying(\.md|\.txt)?|licen[cs]e-[a-z0-9.-]+'
locate_doc "CONTRIBUTING" 'contributing(\.md)?'
locate_doc "SECURITY" 'security(\.md)?'
locate_doc "CHANGELOG" 'changelog(\.md)?|changes(\.md)?'

hdr "CONVENTIONAL FILES"
for f in .gitignore .gitattributes .editorconfig .env .env.example \
  .solhint.json .solhintrc .solhintrc.json .solhintignore \
  .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.js .prettierignore \
  .solcover.js slither.config.json codecov.yml .codecov.yml \
  Makefile justfile .nvmrc .node-version .tool-versions; do
  kv "$f" "$(yn "$f")"
done
if [ -f Makefile ]; then
  echo "-- Makefile targets --"
  grep -nE '^[a-zA-Z0-9_.-]+:([^=]|$)' Makefile | sed -n '1,40p'
fi

hdr "DIRECTORIES"
for d in contracts src solidity core tests test spec deploy deployments \
  docs doc documentation script scripts audits audit .github lib node_modules; do
  if [ -d "$d" ]; then
    case "$d" in
      lib|node_modules) kv "$d/" "present (not counted)" ;;
      *) kv "$d/" "present ($(find "$d" -type f 2>/dev/null | n) files)" ;;
    esac
  else
    kv "$d/" "MISSING"
  fi
done

hdr "TOOLCHAIN"
for f in hardhat.config.js hardhat.config.ts hardhat.config.cjs hardhat.config.mjs \
  foundry.toml foundry.lock remappings.txt .gitmodules package.json \
  package-lock.json yarn.lock pnpm-lock.yaml bun.lockb; do
  kv "$f" "$(yn "$f")"
done
if [ -f package.json ]; then
  echo "-- package.json: identity, engines, scripts --"
  grep -nE '"(name|version|private|packageManager)"[[:space:]]*:' package.json
  grep -nA6 '"engines"' package.json
  sed -n '/"scripts"[[:space:]]*:/,/^[[:space:]]*}/p' package.json
  echo "-- package.json: relevant dependencies --"
  grep -nE '"(hardhat|@nomicfoundation/[a-z0-9-]+|@nomiclabs/[a-z0-9-]+|solhint[a-z-]*|prettier|prettier-plugin-solidity|solidity-coverage|hardhat-gas-reporter|hardhat-deploy|@openzeppelin/[a-z-]+|ethers|typechain)"' package.json
fi
if [ -f foundry.toml ]; then
  echo "-- foundry.toml --"
  sed -n '1,120p' foundry.toml
fi
echo "-- solc / evm / optimizer pins --"
grep -nE 'solc|solc_version|solidity|evm_version|evmVersion|optimizer|via_?IR|viaIR' \
  hardhat.config.js hardhat.config.ts hardhat.config.cjs hardhat.config.mjs foundry.toml 2>/dev/null
if [ -f .gitmodules ]; then
  echo "-- submodules --"
  sed -n '1,60p' .gitmodules
  git submodule status 2>/dev/null
fi

hdr "SOLIDITY FILES BY TOP-LEVEL DIRECTORY"
pf '*.sol' | top_dirs
kv "total .sol" "$(pf '*.sol' | n)"

hdr "TESTS"
echo "-- files inside test directories (any extension) --"
for d in tests test spec contracts/test contracts/tests src/test src/tests test/foundry; do
  [ -d "$d" ] || continue
  kv "$d/" "$(find "$d" -type f 2>/dev/null | n) files: $(find "$d" -type f 2>/dev/null | sed 's|.*/||;s|^.*\.||' | sort | uniq -c | tr '\n' ' ')"
done
echo "-- files matching test naming patterns, anywhere --"
{ pf '*.t.sol'; pf '*.test.*'; pf '*.spec.*'; pf 'test_*.sol'; } | sort -u | top_dirs
echo "-- fuzz / invariant signals --"
SRCDIRS=""
for d in tests test spec src contracts; do
  [ -d "$d" ] && SRCDIRS="$SRCDIRS $d"
done
if [ -n "$SRCDIRS" ]; then
  for k in 'invariant_' 'testFuzz' 'vm\.assume' 'forge-std/Test' 'StdInvariant' 'fuzz'; do
    kv "  /$k/" "$(grep -rilE "$k" $SRCDIRS 2>/dev/null | n) file(s)"
  done
else
  echo "no source or test directories to scan"
fi

hdr "SPDX HEADERS IN .sol"
sol_total="$(pf '*.sol' | n)"
spdx="$(pfind '*.sol' -exec grep -m1 -ho 'SPDX-License-Identifier:[^*]*' {} \; \
  | sed 's|[[:space:]]*$||')"
spdx_files="$(printf '%s' "$spdx" | grep -c 'SPDX' | tr -d ' ')"
kv ".sol files" "$sol_total"
kv "with an SPDX header" "$spdx_files"
kv "without an SPDX header" "$((sol_total - spdx_files))"
echo "-- identifiers found --"
printf '%s\n' "$spdx" | grep 'SPDX' | sort | uniq -c | sort -rn

hdr "LICENSE"
for f in LICENSE LICENSE.md LICENSE.txt COPYING; do
  [ -f "$f" ] || continue
  kv "file" "$f ($(lines "$f") lines)"
  echo "-- first 15 lines --"
  sed -n '1,15p' "$f"
  echo "-- time/usage-restriction terms --"
  grep -niE 'change date|change license|additional use grant|business source|licensor|licensed work' "$f"
done

hdr "README SIGNALS"
README=""
for f in README.md readme.md README; do
  if [ -f "$f" ]; then README="$f"; break; fi
done
if [ -n "$README" ]; then
  kv "file" "$README"
  kv "lines" "$(lines "$README")"
  kv "words" "$(wc -w < "$README" | tr -d ' ')"
  echo "-- headings --"
  grep -nE '^#{1,3} ' "$README"
  echo "-- badges --"
  grep -noE '!\[[^]]*\]\([^)]*\)' "$README" | grep -iE 'badge|shields\.io|codecov|coveralls'
  echo "-- svg / logo references --"
  grep -niE '\.svg|<svg|logo' "$README"
  echo "-- build and test commands mentioned --"
  grep -nE '(npx hardhat|yarn hardhat|npm run|yarn (test|build)|pnpm|forge (build|test|fmt|coverage|script))' "$README"
  echo "-- unique contract addresses --"
  grep -oE '0x[a-fA-F0-9]{40}' "$README" | sort -u
  echo "-- keyword hits --"
  for k in audit 'bug bounty' bounty immunefi hackenproof documentation deploy \
    network mainnet testnet license structure install; do
    kv "  /$k/" "$(grep -ciE "$k" "$README" | tr -d ' ')"
  done
  echo "-- links, first 60 (presence only; resolve them separately) --"
  grep -noE 'https?://[^)"'"'"' >]+' "$README" | sed -n '1,60p'
else
  echo "README MISSING"
fi

hdr "CONTRIBUTING SIGNALS"
found=0
for f in CONTRIBUTING.md .github/CONTRIBUTING.md docs/CONTRIBUTING.md contributing.md; do
  if [ -f "$f" ]; then
    found=1
    doc_report "$f" 'fork' 'pull request' 'branch' 'review' 'style' \
      'natspec' 'lint' 'solhint' 'prettier' 'forge fmt' 'test' 'fuzz' 'invariant' \
      'SECURITY' 'vulnerab'
  fi
done
[ "$found" -eq 0 ] && echo "no CONTRIBUTING file"

hdr "SECURITY SIGNALS"
found=0
for f in SECURITY.md .github/SECURITY.md docs/SECURITY.md security.md; do
  if [ -f "$f" ]; then
    found=1
    doc_report "$f" 'email' '@' 'immunefi' 'hackenproof' 'bounty' \
      'scope' 'severity' 'payout' 'audit' 'version' 'disclos' \
      'private vulnerability' 'known issue'
  fi
done
[ "$found" -eq 0 ] && echo "no SECURITY file"

hdr ".github CONTENTS"
if [ -d .github ]; then
  find .github -type f | sed 's|^\./||' | sort
else
  echo "MISSING"
fi

hdr "ISSUE AND PR TEMPLATES"
PRT="$(find . .github docs -maxdepth 1 -type f 2>/dev/null | sed 's|^\./||' \
  | grep -iE '(^|/)pull_request_template(\.md|\.txt)?$' | sort -u | tr '\n' ' ')"
kv "PR template" "${PRT:-MISSING}"
ITD="$(find . -maxdepth 3 \( -name node_modules -o -name .git -o -name .cursor -o -name lib \) -prune -o \
  -type d -iname 'ISSUE_TEMPLATE' -print 2>/dev/null | sed 's|^\./||' | head -1)"
kv "issue template dir" "${ITD:-MISSING}"
if [ -n "$ITD" ]; then
  echo "-- $ITD entries --"
  ls -A "$ITD"
fi
echo "-- security / vulnerability warnings in templates --"
if [ -n "$PRT$ITD" ]; then
  grep -rilE 'vulnerab|security' $PRT $ITD 2>/dev/null || echo "none"
else
  echo "no templates to scan"
fi
echo "-- environment fields in bug templates --"
if [ -n "$ITD" ]; then
  grep -rilE 'network|tx hash|transaction hash|contract address|version|reproduc' "$ITD" 2>/dev/null || echo "none"
else
  echo "no issue templates"
fi
echo "-- PR checklist items --"
if [ -n "$PRT" ]; then
  grep -rnE '^[[:space:]]*-[[:space:]]*\[[ xX]\]' $PRT 2>/dev/null || echo "none"
else
  echo "no PR template"
fi

hdr "CI WORKFLOWS"
if [ -d .github/workflows ]; then
  for w in .github/workflows/*; do
    [ -f "$w" ] || continue
    echo "-- $w ($(lines "$w") lines) --"
    grep -nE '^(name|on|jobs)|^[[:space:]]{2,4}(push|pull_request|schedule|workflow_dispatch|workflow_call|branches)' "$w"
    grep -nE '(uses|run):' "$w"
  done
else
  echo "no .github/workflows"
fi

hdr "CI KEYWORD MATRIX"
if [ -d .github/workflows ]; then
  for k in 'hardhat test' 'forge test' 'hardhat compile' 'forge build' 'solhint' \
    'prettier' 'forge fmt' 'slither' 'mythril' 'coverage' 'codecov' \
    'forge snapshot' 'gas' 'secrets\.' 'setup-node' 'foundry-toolchain' \
    'nightly' '@latest' 'cache' \
    'yarn test' 'npm test' 'npm run' 'yarn lint' 'yarn build' 'make '; do
    files="$(grep -rilE "$k" .github/workflows 2>/dev/null | tr '\n' ' ')"
    if [ -n "$files" ]; then kv "/$k/" "$files"; else kv "/$k/" "-"; fi
  done
  echo "-- unpinned action versions (uses: ...@main / @master / no ref) --"
  grep -rnE 'uses:[[:space:]]*[^@]+@(main|master)[[:space:]]*$' .github/workflows 2>/dev/null || echo "none"
else
  echo "no workflows to scan"
fi

hdr "RELEASES AND VERSIONING"
kv "git tags" "$(git tag 2>/dev/null | n)"
echo "-- 10 most recent tags --"
git tag --sort=-creatordate 2>/dev/null | sed -n '1,10p'
kv "CHANGELOG.md" "$(yn CHANGELOG.md)"
if [ -f CHANGELOG.md ]; then
  kv "CHANGELOG lines" "$(lines CHANGELOG.md)"
  sed -n '1,25p' CHANGELOG.md
fi
echo "-- release-related workflows --"
grep -rilE 'release|npm publish|tag' .github/workflows 2>/dev/null || echo "none"

hdr "DEPLOYMENT RECORDS"
find . -maxdepth 3 \
  \( -name .git -o -name .cursor -o -name node_modules -o -name lib -o -name out \
  -o -name cache -o -name artifacts -o -name broadcast \) -prune -o \
  \( -iname '*deployment*' -o -iname '*address*' \) -print 2>/dev/null | sed 's|^\./||'
for d in deployments deploy; do
  if [ -d "$d" ]; then
    echo "-- $d/ entries --"
    ls -A "$d" | sed -n '1,40p'
  fi
done

hdr "GITIGNORE COVERAGE"
if [ -f .gitignore ]; then
  for p in node_modules artifacts cache out coverage typechain broadcast '\.env'; do
    if grep -qE "(^|/)$p" .gitignore; then kv "$p" "ignored"; else kv "$p" "NOT ignored"; fi
  done
else
  echo ".gitignore MISSING"
fi

hdr "TRACKED SENSITIVE-LOOKING FILES (heuristic)"
git ls-files 2>/dev/null \
  | grep -iE '(^|/)(\.env($|\.)|.*\.(key|pem|p12|keystore)$|id_rsa|secrets?\.(json|ya?ml|ts|js))' \
  || echo "none"

hdr "SECRET-LIKE STRINGS IN TRACKED FILES (heuristic, confirm by hand)"
git grep -nIE '(PRIVATE_KEY|MNEMONIC|SECRET_KEY)[[:space:]]*[:=][[:space:]]*.{0,2}(0x)?[a-zA-Z0-9]{24,}' -- . ':!.cursor' 2>/dev/null \
  | grep -vE 'process\.env|vm\.env|\$\{\{|\.example|dotenv|<|your_|xxx' \
  | sed -n '1,20p' || true
git grep -nIE '(alchemy|infura|quicknode|ankr)[a-z.]*\.(com|io)/[A-Za-z0-9/_-]{20,}' -- . ':!.cursor' 2>/dev/null \
  | sed -n '1,20p' || true
echo "(empty above means no heuristic match)"

hdr "AUDITS"
for d in audits audit docs/audits docs/audit; do
  if [ -d "$d" ]; then
    kv "$d/" "present"
    ls -A "$d"
  else
    kv "$d/" "MISSING"
  fi
done

hdr "DOCS"
if [ -d docs ]; then
  find docs -type f | sed 's|^\./||' | sort | sed -n '1,60p'
  kv "docs .md files" "$(find docs -type f -name '*.md' 2>/dev/null | n)"
  kv "docs .pdf files" "$(find docs -type f -name '*.pdf' 2>/dev/null | n)"
  kv "docs .html/.htm files" "$(find docs -type f \( -name '*.html' -o -name '*.htm' \) 2>/dev/null | n)"
  kv "docs .css files" "$(find docs -type f -name '*.css' 2>/dev/null | n)"
  kv "docs .js files" "$(find docs -type f -name '*.js' 2>/dev/null | n)"
else
  echo "docs/ MISSING — markdown found elsewhere:"
  { pf '*.md'; pf '*.pdf'; } | top_dirs
fi
echo "documentation-shaped HTML/CSS/JS outside docs/ (heuristic; exclude tooling):"
find . -type f \( -name '*.html' -o -name '*.htm' -o -name '*.css' \) \
  ! -path './.cursor/*' ! -path './node_modules/*' ! -path './lib/*' \
  ! -path './out/*' ! -path './cache/*' ! -path './artifacts/*' \
  ! -path './coverage/*' ! -path './typechain-types/*' \
  ! -path './.git/*' 2>/dev/null | sed 's|^\./||' | sort | sed -n '1,40p' || true
echo "(empty above means no heuristic match)"

hdr "END OF FACTS"
