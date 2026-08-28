# Submodule Gate Cascade + notes/ Removal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete `notes/`, bump four root submodule gitlinks to `d2p-finance/main`, and extend `develop-gate` with a `submodule-gates` job that verifies upstream CI on latest `main` and auto-bumps stale gitlinks on same-repo PRs.

**Architecture:** A hosted `submodule-gates` job runs `.github/scripts/sync-submodule-gates.sh` (resolve `LATEST` → verify `gh` check-runs → stage gitlink updates → optional bot push). The final `gate` job requires `forge`, `plank`, and `submodule-gates`. All implementation happens in an **isolated worktree** so the shared `vol-markets` checkout stays dirty/un touched.

**Tech Stack:** GitHub Actions (`develop-gate.yml`), `gh` CLI, bash, git submodules; no local forge/plank runs for verification.

**Spec:** `docs/superpowers/specs/2026-08-28-submodule-gates-and-notes-removal-design.md`

## Global Constraints

- **Worktree only:** create `/home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets-submodule-gates` with branch `chore/submodule-gates-notes-removal` off `origin/develop`. **Never** checkout the feature branch in `/home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets`.
- **CI is the validation gate.** Do not report success from local `forge`/`make`/`stack`. Push → read `develop-gate`.
- **Chunk approval before every commit.** Present each coherent diff in `AskUserQuestion` (approve/modify); only then `git commit`.
- **Named files only.** Never `git add -A`. Do not stage: `.planning/config.json`, `lib/*` submodule drift, `offchain`/`spec` working-tree mods, `src/modules/premium/DynamicFeeMod.plk`, untracked `TODO.md`, unrelated docs.
- **Fork → canonical:** push to `JMSBPP/cfmm-vol-markets`; use `gh … -R JMSBPP/cfmm-vol-markets`.
- **Submodule scope:** `spec`, `offchain`, `evm-spec-bridge`, `refs` only — not `lib/*`.
- **Auto-bump:** Option B — bot commit when pins stale and upstream checks green; same-repo PRs only.
- **Tracking branch:** `d2p-finance/*/main` (URLs already in `.gitmodules`).

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `.github/scripts/sync-submodule-gates.sh` | Resolve LATEST, verify check-runs, bump gitlinks, push | **Create** |
| `.github/scripts/test-sync-submodule-gates.sh` | RED-first unit tests for check-run parsing helpers | **Create** |
| `.github/workflows/develop-gate.yml` | Add `submodule-gates` job; wire `gate` needs | **Modify** |
| `notes/*` (5 files) | Legacy binding docs | **Delete** |
| `src/types/pos_spec/VolOrder.plk` | Drop `notes/` citation | **Modify** |
| `src/types/pos_spec/VegaTarget.plk` | Drop `notes/` citation | **Modify** |
| `src/lib/exposure/PanopticVegaLensLib.plk` | Drop `notes/` citation | **Modify** |
| `src/lib/ldf/GeometricDistribution.plk` | Drop `notes/` citation | **Modify** |
| `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | Drop `notes/` citation | **Modify** |
| `test/protocol_integrations/SpecHelper.sol` | Inline transport-boundary comments | **Modify** |
| `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` | Inline transport-boundary comments | **Modify** |
| `test/pos_spec/VolOrderTargetVega.t.sol` | Inline units comment | **Modify** |
| `Makefile` | Drop `notes/DIFFERENTIAL_LAYOUT.md` comment | **Modify** |
| `spec`, `offchain`, `evm-spec-bridge`, `refs` gitlinks | Initial bump to current `d2p-finance/main` | **Modify** |

## Known Blocker (read before Task 2)

**`offchain` merge commits on `d2p-finance/main` currently have zero GitHub check-runs** because `haskell.yml` is PR-only (`on: pull_request`). Verified: `b1104974` (current `main`) → `total_count: 0`.

The sync script must handle this or the gate will always fail on `offchain`. **Task 0** resolves it upstream (recommended). If Task 0 is deferred, Task 2 implements a **main-history walk** for `offchain` only (see Task 2 Step 3).

---

### Task 0 (prerequisite): Enable push CI on `gams-evm-transport` main

**Skip only if** maintainer confirms offchain history-walk fallback is acceptable without upstream fix.

**Files:**
- Modify (separate repo/worktree): `JMSBPP/gams-evm-transport` → `.github/workflows/haskell.yml`

- [ ] **Step 1: Worktree on transport repo**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt
git -C gams-evm-transport fetch origin 2>/dev/null || true
# use existing offchain submodule path OR clone JMSBPP/gams-evm-transport to a dedicated worktree
git worktree add /home/jmsbpp/cfmms-playground/cfmm-wt/gams-evm-transport-push-ci \
  -b chore/push-ci-on-main origin/main
```

- [ ] **Step 2: Add push trigger** (keep existing `pull_request` + `workflow_dispatch`)

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:
    # … unchanged …
```

- [ ] **Step 3: Push, PR to JMSBPP, merge to canonical via normal fork flow**

- [ ] **Step 4: Confirm check-runs exist on new `d2p-finance/gams-evm-transport` `main` HEAD**

```bash
SHA=$(gh api repos/d2p-finance/gams-evm-transport/commits/main --jq .sha)
gh api "repos/d2p-finance/gams-evm-transport/commits/${SHA}/check-runs" \
  --jq '.check_runs[] | select(.name=="build-test" or .name=="gate") | "\(.name): \(.conclusion)"'
```

Expected: both `success`. Re-resolve `LATEST` for offchain in Task 4 after this lands.

---

### Task 1: RED tests for check-run verification helpers

**Files:**
- Create: `.github/scripts/test-sync-submodule-gates.sh`
- Create (stub first): `.github/scripts/sync-submodule-gates.sh` — only helper functions

**Interfaces:**
- Produces for Task 2:
  - `require_check_run_success(repo, sha, name) -> exit 0|1`
  - `check_runs_conclusion(repo, sha, name) -> prints "success"|"failure"|"missing"`

- [ ] **Step 1: Create stub helpers in `sync-submodule-gates.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

check_runs_conclusion() {
  local repo=$1 sha=$2 name=$3 token=${GH_TOKEN:-${GITHUB_TOKEN:-}}
  local conclusion
  conclusion=$(GH_TOKEN="$token" gh api "repos/${repo}/commits/${sha}/check-runs" --paginate \
    --jq "[.check_runs[] | select(.name == \"${name}\") | .conclusion] | first // \"missing\"")
  printf '%s' "$conclusion"
}

require_check_run_success() {
  local repo=$1 sha=$2 name=$3
  local c
  c=$(check_runs_conclusion "$repo" "$sha" "$name")
  if [[ "$c" != "success" ]]; then
    echo "::error::${repo}@${sha:0:7} check-run '${name}' is '${c}' (need success)"
    return 1
  fi
}
```

- [ ] **Step 2: Write failing test script**

Create `.github/scripts/test-sync-submodule-gates.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=/dev/null
source "$ROOT/.github/scripts/sync-submodule-gates.sh"

fail=0
assert_eq() {
  local got=$1 want=$2 label=$3
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $label: got '$got' want '$want'"
    fail=1
  else
    echo "OK   $label"
  fi
}

# Mock gh for unit tests
gh() {
  if [[ "${1:-}" == "api" && "${2:-}" == *"/check-runs"* ]]; then
    if [[ "${2:-}" == *"good"* ]]; then
      echo '{"check_runs":[{"name":"seam","conclusion":"success"}]}'
      return 0
    fi
    echo '{"check_runs":[]}'
    return 0
  fi
  command gh "$@"
}
export -f gh

assert_eq "$(check_runs_conclusion d2p-finance/evm-spec-bridge good seam)" "success" "happy path"
assert_eq "$(check_runs_conclusion d2p-finance/evm-spec-bridge bad seam)" "missing" "missing run"
require_check_run_success d2p-finance/evm-spec-bridge good seam || fail=1
if require_check_run_success d2p-finance/evm-spec-bridge bad seam 2>/dev/null; then
  echo "FAIL should reject missing"; fail=1
else
  echo "OK   rejects missing"
fi

exit "$fail"
```

- [ ] **Step 3: Run test — expect FAIL** (helpers incomplete or script missing)

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets-submodule-gates
bash .github/scripts/test-sync-submodule-gates.sh
```

- [ ] **Step 4: Complete helpers; re-run — expect PASS**

- [ ] **Step 5: Maintainer approve → commit**

```bash
git add .github/scripts/sync-submodule-gates.sh .github/scripts/test-sync-submodule-gates.sh
git commit -m "$(cat <<'EOF'
test(ci): add RED helpers for submodule gate check-run verification

Shell tests for require_check_run_success before wiring develop-gate.
EOF
)"
```

---

### Task 2: Complete `sync-submodule-gates.sh` (manifest + auto-bump)

**Files:**
- Modify: `.github/scripts/sync-submodule-gates.sh` (full implementation)
- Modify: `.github/scripts/test-sync-submodule-gates.sh` (add manifest table test if desired)

**Interfaces:**
- Consumes: helpers from Task 1
- Produces: executable invoked by workflow with env:
  - `GITHUB_EVENT_NAME`, `GITHUB_REPOSITORY`, `GITHUB_HEAD_REF`
  - `PR_HEAD_REPO_FULL_NAME` (workflow sets from `github.event.pull_request.head.repo.full_name`)

**Manifest (exact check-run names — verified on current main):**

```bash
declare -A SUBMODULE_REPOS SUBMODULE_CHECKS
SUBMODULE_REPOS[spec]=d2p-finance/cfmm-vol-markets-spec
SUBMODULE_CHECKS[spec]="stack build && stack test"

SUBMODULE_REPOS[offchain]=d2p-finance/gams-evm-transport
SUBMODULE_CHECKS[offchain]="build-test gate"   # space-separated names

SUBMODULE_REPOS[evm-spec-bridge]=d2p-finance/evm-spec-bridge
SUBMODULE_CHECKS[evm-spec-bridge]="seam build"

SUBMODULE_REPOS[refs]=d2p-finance/cfmm-refs
SUBMODULE_CHECKS[refs]=shelf
```

- [ ] **Step 1: Implement `resolve_latest(url)` → 40-char SHA**

```bash
resolve_latest() {
  git ls-remote "$1" refs/heads/main | awk '{print $1; exit}'
}
```

- [ ] **Step 2: Implement `verify_submodule_gate path repo checks_sha`**

Loop required check names; call `require_check_run_success`.

- [ ] **Step 3: Offchain fallback (if Task 0 not merged)**

```bash
verify_with_history() {
  local repo=$1 start_sha=$2 names=$3
  local sha=$start_sha
  local i
  for i in $(seq 1 15); do
    local ok=1 name
    for name in $names; do
      [[ $(check_runs_conclusion "$repo" "$sha" "$name") == "success" ]] || ok=0
    done
    [[ $ok -eq 1 ]] && { echo "$sha"; return 0; }
    sha=$(gh api "repos/${repo}/commits/${sha}" --jq '.parents[0].sha' 2>/dev/null || echo "")
    [[ -z "$sha" || "$sha" == "null" ]] && break
  done
  echo "::error::${repo}: no commit within 15 of main head has green checks (${names})" >&2
  return 1
}
```

Use straight `LATEST` verification when check-runs exist on `LATEST`; call `verify_with_history` for offchain when `LATEST` has zero runs.

- [ ] **Step 4: Implement main loop**

For each path in `spec offchain evm-spec-bridge refs`:

1. Read URL from `.gitmodules`
2. `LATEST=$(resolve_latest "$url")`
3. Verify gates (§Step 2/3)
4. `PINNED=$(git rev-parse ":${path}")` — if path not in index yet, treat as empty
5. `git submodule update --init "$path"` then `git -C "$path" fetch origin main && git -C "$path" checkout "$LATEST"`
6. If `PINNED != LATEST`, `git add "$path"`

- [ ] **Step 5: Auto-bump push block**

```bash
if git diff --cached --quiet; then
  echo "submodule pins already at LATEST"
  exit 0
fi

if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]]; then
  echo "::error::submodule pins stale but auto-bump runs only on pull_request"
  exit 1
fi

if [[ "${PR_HEAD_REPO_FULL_NAME:-}" != "${GITHUB_REPOSITORY:-}" ]]; then
  echo "::error::submodule pins stale; open PR from a branch on ${GITHUB_REPOSITORY} (not a fork head) or bump gitlinks manually"
  exit 1
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
msg="chore(ci): auto-bump root submodule pins to d2p-finance/main

spec@$(git rev-parse :spec) offchain@$(git rev-parse :offchain) evm-spec-bridge@$(git rev-parse :evm-spec-bridge) refs@$(git rev-parse :refs)"
git commit -m "$msg"
git push origin "HEAD:${GITHUB_HEAD_REF:?}"
```

- [ ] **Step 6: Run unit tests — expect PASS**

```bash
bash .github/scripts/test-sync-submodule-gates.sh
```

- [ ] **Step 7: Dry-run against live canonical (read-only, in worktree)**

```bash
export GITHUB_EVENT_NAME=pull_request GITHUB_REPOSITORY=JMSBPP/cfmm-vol-markets
export PR_HEAD_REPO_FULL_NAME=JMSBPP/cfmm-vol-markets GITHUB_HEAD_REF=chore/submodule-gates-notes-removal
# Temporarily disable push at end OR run functions in subshell with git push stubbed
bash -x .github/scripts/sync-submodule-gates.sh || true
```

Inspect log: four LATEST SHAs resolved; check-run verification passes or documents offchain blocker.

- [ ] **Step 8: Maintainer approve → commit**

---

### Task 3: Wire `develop-gate.yml`

**Files:**
- Modify: `.github/workflows/develop-gate.yml`

- [ ] **Step 1: Add `submodule-gates` job** after `plank` job definition

```yaml
  submodule-gates:
    needs: [approve]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: write
    env:
      GIT_TERMINAL_PROMPT: "0"
      PR_HEAD_REPO_FULL_NAME: ${{ github.event.pull_request.head.repo.full_name }}
      GITHUB_HEAD_REF: ${{ github.head_ref }}
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: false
          fetch-depth: 0
          ref: ${{ github.head_ref || github.ref }}
          persist-credentials: true
      - run: git submodule sync --recursive
      - name: Install gh
        run: type gh >/dev/null 2>&1 || (sudo apt-get update && sudo apt-get install -y gh)
      - name: Sync and verify root submodule gates
        env:
          GH_TOKEN: ${{ secrets.GH_STATUS_READ || github.token }}
        run: bash .github/scripts/sync-submodule-gates.sh
```

- [ ] **Step 2: Update final `gate` job**

Change:
```yaml
needs: [approve, forge, plank, submodule-gates]
```

Add to loop:
```bash
for x in '${{ needs.forge.result }}' '${{ needs.plank.result }}' '${{ needs.submodule-gates.result }}'; do
```

- [ ] **Step 3: Fix forge job comment** (line ~33)

Replace `notes/TOOLCHAIN_PINS.md` with `.github/foundry-version`.

- [ ] **Step 4: Maintainer approve → commit**

---

### Task 4: Remove `notes/` + minimal citation edits

**Files:** per File Structure table (delete 5 under `notes/`; modify 10 live files)

- [ ] **Step 1: Delete notes directory**

```bash
git rm notes/DATA_CONTRACT.md notes/UNITS_AND_SCALES.md notes/DIFFERENTIAL_LAYOUT.md \
       notes/TOOLCHAIN_PINS.md notes/STOCHASTIC_MODEL.md
rmdir notes 2>/dev/null || true
```

- [ ] **Step 2: Edit Plank sources** — replace `notes/UNITS_AND_SCALES.md` with inline wording, e.g.:

```plank
// UNITS: DeltaQ_v / DeltaQ_v* are RAW LIQUIDITY units (dimension (ii), v2 spec).
```

Apply to: `VolOrder.plk`, `VegaTarget.plk`, `PanopticVegaLensLib.plk`, `VolOrderManagerInterface.plk`.

`GeometricDistribution.plk`: drop `notes/VOLATILITY_INSTRUMENTS.md`; keep "faithful port of Bunni's …" without notes path.

- [ ] **Step 3: Edit Solidity tests** — in `SpecHelper.sol` and `VolOrderToPanopticTokenId.diff.t.sol`, replace every `notes/DIFFERENTIAL_LAYOUT.md` with:

```solidity
/// Transport boundary (RED-06): JSON-RPC via evm-spec-bridge; vm.rpc success bit mandatory;
/// three-way outcome contract (Ok / Rejected / TransportFailure) — see SpecHelper.sol.
```

`VolOrderTargetVega.t.sol`: `// Units: DeltaQ_v* RAW LIQUIDITY (dimension (ii), v2 spec).`

- [ ] **Step 4: Makefile line ~217** — shorten to:

```make
# Transport-boundary target: see test/protocol_integrations/SpecHelper.sol (RED-06).
```

- [ ] **Step 5: Grep guard**

```bash
git grep -n 'notes/' -- src test Makefile .github/workflows/develop-gate.yml \
  && echo "FAIL: live surface still cites notes/" && exit 1 || echo "OK"
```

- [ ] **Step 6: Maintainer approve → commit**

---

### Task 5: Initial gitlink bump to current `d2p-finance/main`

**Files:** gitlinks for `spec`, `offchain`, `evm-spec-bridge`, `refs`

- [ ] **Step 1: Resolve SHAs at execution time (do not hardcode stale table)**

```bash
for p in spec offchain evm-spec-bridge refs; do
  url=$(git config -f .gitmodules --get submodule.$p.url)
  echo "$p $(git ls-remote "$url" refs/heads/main | awk '{print $1}')"
done
```

- [ ] **Step 2: Bump each submodule**

```bash
git submodule update --init "$path"
git -C "$path" fetch origin main
git -C "$path" checkout "$LATEST"
git add "$path"
```

- [ ] **Step 3: Verify status**

```bash
git submodule status spec offchain evm-spec-bridge refs
# expect no leading '-' ; SHAs match ls-remote
```

- [ ] **Step 4: Maintainer approve → commit**

```bash
git commit -m "$(cat <<'EOF'
chore: bump root submodule pins to d2p-finance/main

spec, offchain, evm-spec-bridge, refs — initial sync for submodule-gates cascade.
EOF
)"
```

---

### Task 6: Push, PR, read `develop-gate`

- [ ] **Step 1: Push branch**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets-submodule-gates
git push -u origin chore/submodule-gates-notes-removal
```

- [ ] **Step 2: Open PR**

```bash
gh pr create -R JMSBPP/cfmm-vol-markets --base develop \
  --head chore/submodule-gates-notes-removal \
  --title "chore: submodule gate cascade and remove notes/" \
  --body "$(cat <<'EOF'
## Summary
- Remove notes/; minimal live citation cleanup
- Add submodule-gates job with auto-bump to d2p-finance/main
- Bump spec/offchain/evm-spec-bridge/refs gitlinks

## Spec
docs/superpowers/specs/2026-08-28-submodule-gates-and-notes-removal-design.md

## Test plan
- [ ] develop-gate: approve → forge, plank, submodule-gates → gate all green
- [ ] submodule-gates logs four LATEST SHAs + check-run verification
- [ ] If pins drift later, bot commit on same-repo PR

EOF
)"
```

- [ ] **Step 3: Approve environment; read checks**

```bash
gh pr checks <N> -R JMSBPP/cfmm-vol-markets --watch
```

- [ ] **Step 4: If `submodule-gates` fails on offchain check-runs → complete Task 0 or confirm history-walk fired**

- [ ] **Step 5: After merge — teardown worktree**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
git fetch origin develop && git pull origin develop
git worktree remove --force /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets-submodule-gates
git branch -d chore/submodule-gates-notes-removal
git fetch origin --prune
```

Main checkout stays on `develop`; only fast-forward after merge.

---

## Plan Self-Review

| Spec section | Task |
|---|---|
| Delete notes/ + minimal citations | Task 4 |
| Submodule-gates job | Task 3 |
| sync script + check-runs | Tasks 1–2 |
| Auto-bump Option B | Task 2 Step 5 |
| Initial gitlink bump | Task 5 |
| Worktree isolation | Global Constraints + Task 6 teardown |
| CI-only validation | Global Constraints |
| offchain no check-runs on main | Task 0 + Task 2 Step 3 |
| Out of scope (README, lib/*) | Not included |

No TBD placeholders. Check-run names match live API verification.

---

**Plan complete and saved to `docs/superpowers/plans/2026-08-28-submodule-gates-and-notes-removal.md`.**

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — execute tasks in this session with checkpoints (`executing-plans`)

**Which approach?**

Also: **Task 0** (offchain push CI) is a prerequisite unless you accept the 15-commit history walk — say which before starting implementation.
