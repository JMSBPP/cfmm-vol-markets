# Worktree-Per-Peer (isolation + migration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each of the 7 repo peers an isolated git worktree on its own branch off a shared `develop`, migrating current shared-tree WIP safely first — so peers stop colliding on one working tree.

**Architecture:** Author two idempotent shell scripts (`wt-setup.sh`, `wt-teardown.sh`) and a coordinator-run migration runbook. Tasks 1–3 author + lint these artifacts solo (shellcheck/dry-run). Task 4 is the **coordinator-run** live phase (freeze → serialized peer commits → submodule pushes → cut `develop` → run `wt-setup.sh`) that mutates the shared repo with peer participation — it is NOT executed by an automated implementer.

**Tech Stack:** bash, git worktrees + submodules (git ≥ 2.43; verified on 2.54), the claude-peers network for coordination.

**Spec:** `docs/superpowers/specs/2026-06-27-worktree-per-peer-ci-design.md` (approved, passed two two-step review rounds). The per-track CI subsystem is deferred to a separate Plan 2.

## Global Constraints

- `develop` base = the **post-freeze committed HEAD of `feat/gams-solidity-difftest`** (currently `cc88cde`), NOT `master` (both master refs lack the peer code). Use the exact ref in scripts.
- **Never rebase or force-push `develop`** — it is the shared base for all 7 peer branches.
- Worktree home: `../cfmm-wt/<peer>` (sibling of the repo).
- 5 worktrees are **source-only** (submodules left uninitialized: `lib/` present with 8 empty subdirs, `git status` clean, `git submodule status` all `-`). The 2 Solidity worktrees (`feat/plank`, `feat/sol-tests`) **init submodules** — a fresh **per-worktree clone** (network + creds), not object-sharing.
- The script **never switches the main checkout's branch** (it is dirty).
- All git ops are **guarded** (idempotent): second run is a clean no-op.
- Remote: `origin` = `JMSBPP/cfmm-replicationPlank` (has `master`); `upstream` = `wvs-finance`. Push `develop` to `origin` only, guarded.
- Peer→branch→path map (7th TBD pending `p5fh8ywz`):
  `gams→feat/gams`, `lean4-spec→feat/lean4-spec`, `plank→feat/plank`(submodules), `sol-tests→feat/sol-tests`(submodules), `gamsdiff→feat/gamsdiff`, `ci→feat/ci`, `<tbd>→feat/<tbd>`.

---

### Task 1: Author `scripts/wt-setup.sh` (idempotent worktree creator)

**Files:**
- Create: `scripts/wt-setup.sh`
- Create: `scripts/peers.tsv` (the peer→branch→path→submodules map as data)

**Interfaces:**
- Produces: `wt-setup.sh` reads `scripts/peers.tsv`; creates `develop` (guarded), pushes it (guarded), and one worktree per row (guarded). Consumed by Task 4 (coordinator runs it after the migration).

- [ ] **Step 1: Write the peer map data file**

Create `scripts/peers.tsv` (tab-separated: name, branch, init_submodules):
```tsv
gams	feat/gams	no
lean4-spec	feat/lean4-spec	no
plank	feat/plank	yes
sol-tests	feat/sol-tests	yes
gamsdiff	feat/gamsdiff	no
ci	feat/ci	no
```
**The file MUST end with a trailing newline** (the setup script hard-fails otherwise, and the
`while read` loop would otherwise drop the last row, `ci`). After writing, confirm:
`[ -z "$(tail -c1 scripts/peers.tsv)" ] && echo OK`. (The 7th peer row is appended once
`p5fh8ywz` declares its track — the script tolerates any number of rows.)

- [ ] **Step 2: Write `scripts/wt-setup.sh`**

```bash
#!/usr/bin/env bash
# Idempotent worktree-per-peer setup. Creates `develop` (from the EXACT $DEVELOP_BASE)
# and one git worktree per row of scripts/peers.tsv under ../cfmm-wt/<name>. NEVER
# switches the main checkout's branch. Re-running is a clean no-op (modulo one network
# ls-remote check). Two passes: create all worktrees first, THEN init submodules
# (non-fatal) so a Solidity-init failure never blocks the source-only peers.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "$REPO_ROOT"
WT_HOME="$REPO_ROOT/../cfmm-wt"
MAP="$REPO_ROOT/scripts/peers.tsv"

# peers.tsv MUST end in a newline, else `while read` silently drops the last row.
[ -s "$MAP" ] && [ -z "$(tail -c1 "$MAP")" ] \
  || { echo "ERROR: $MAP missing/empty or has no trailing newline (last row would be dropped)" >&2; exit 1; }

git worktree prune                                            # clear stale registrations

# --- develop: create from the EXACT pinned base, or validate an existing one ---
if git show-ref --verify --quiet refs/heads/develop; then
  if [ -n "${DEVELOP_BASE:-}" ] && \
     [ "$(git rev-parse develop)" != "$(git rev-parse "$DEVELOP_BASE")" ]; then
    echo "ERROR: develop is at $(git rev-parse --short develop) but DEVELOP_BASE=$(git rev-parse --short "$DEVELOP_BASE")" >&2
    exit 1
  fi
else
  : "${DEVELOP_BASE:?set DEVELOP_BASE to the exact post-freeze SHA, e.g. DEVELOP_BASE=\$(git rev-parse HEAD)}"
  git branch develop "$DEVELOP_BASE"
  echo "created develop from $DEVELOP_BASE ($(git rev-parse --short develop))"
fi

# push develop. ls-remote is a network call EVERY run; distinguish absent(2) from unreachable.
set +e; git ls-remote --exit-code origin develop >/dev/null 2>&1; rc=$?; set -e
case "$rc" in
  0) git rev-parse --abbrev-ref develop@{upstream} >/dev/null 2>&1 \
       || git branch --set-upstream-to=origin/develop develop ;;
  2) git push -u origin develop ;;
  *) echo "ERROR: cannot reach origin to check develop (ls-remote rc=$rc)" >&2; exit 1 ;;
esac

# --- pass 1: create every worktree (read tolerates a missing final newline) ---
while IFS=$'\t' read -r name branch init_sub || [ -n "${name:-}" ]; do
  [ -z "${name:-}" ] && continue
  case "$name" in \#*) continue;; esac                        # allow comments
  path="$WT_HOME/$name"
  git show-ref --verify --quiet "refs/heads/$branch" || git branch "$branch" develop
  target="$(readlink -f "$(dirname "$path")" 2>/dev/null)/$(basename "$path")"
  if git worktree list --porcelain | grep -qxF "worktree $target"; then
    echo "skip (registered): $path"
  elif git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"; then
    echo "WARN: $branch already checked out in another worktree — skipping $path" >&2
  elif [ -e "$path" ]; then
    echo "WARN: $path exists but is not a registered worktree — skipping (inspect / prune)" >&2
  else
    git worktree add "$path" "$branch" && echo "added: $path -> $branch"
  fi
done < "$MAP"

# --- pass 2: submodule init for flagged peers — NON-FATAL, resumable on re-run ---
while IFS=$'\t' read -r name branch init_sub || [ -n "${name:-}" ]; do
  [ -z "${name:-}" ] && continue
  case "$name" in \#*) continue;; esac
  [ "${init_sub:-no}" = "yes" ] || continue
  path="$WT_HOME/$name"
  echo "init submodules in $path (fresh per-worktree clone; network+creds)..."
  ( cd "$path" && git submodule update --init --recursive ) \
    || echo "WARN: submodule init failed for $path — worktree created; re-run after fixing creds/network" >&2
done < "$MAP"

echo "--- worktrees ---"; git worktree list
```

- [ ] **Step 3: shellcheck the script (clean)**

Run: `shellcheck scripts/wt-setup.sh; echo "exit=$?"`
Expected: `exit=0`, no warnings. (If shellcheck absent: `bash -n scripts/wt-setup.sh && echo "syntax ok"`.)

- [ ] **Step 4: Verify the data file + count rows the way the SCRIPT does (not awk)**

The `while read` loop drops a final line with no trailing newline, so verify the newline AND
count via the same read-loop the script uses (an awk count would miss the drop):
```bash
chmod +x scripts/wt-setup.sh
[ -z "$(tail -c1 scripts/peers.tsv)" ] && echo "trailing-newline OK" || echo "MISSING trailing newline"
n=0; while IFS=$'\t' read -r name _ _ || [ -n "${name:-}" ]; do
  [ -z "${name:-}" ] && continue; case "$name" in \#*) continue;; esac; n=$((n+1))
done < scripts/peers.tsv; echo "rows the script will process: $n"
bash -n scripts/wt-setup.sh && echo "script syntax ok"
```
Expected: `trailing-newline OK`, `rows the script will process: 6`, `script syntax ok`. (Full
execution is Task 4 — it needs `develop`/the migration first.)

- [ ] **Step 5: Commit**

```bash
git add scripts/wt-setup.sh scripts/peers.tsv
git commit -m "feat(wt): idempotent worktree-per-peer setup script + peer map

scripts/wt-setup.sh creates develop from the post-freeze HEAD and one source-only
worktree per peer (2 Solidity peers init submodules). Guarded/idempotent; never
switches the main checkout's branch.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Author `scripts/wt-teardown.sh`

**Files:**
- Create: `scripts/wt-teardown.sh`

**Interfaces:**
- Consumes: the same `scripts/peers.tsv` map.
- Produces: safe removal of a peer's worktree + branch (`-d`, refuses unmerged).

- [ ] **Step 1: Write `scripts/wt-teardown.sh`**

```bash
#!/usr/bin/env bash
# Remove one peer's worktree and its branch safely. Usage: wt-teardown.sh <peer-name>
# Uses `git branch -d` (refuses unmerged branches — keep that safety).
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "$REPO_ROOT"
name="${1:?usage: wt-teardown.sh <peer-name>}"
path="$REPO_ROOT/../cfmm-wt/$name"
branch="$(awk -F'\t' -v n="$name" '$1==n{print $2}' scripts/peers.tsv)"
[ -n "$branch" ] || { echo "no map row for '$name'" >&2; exit 1; }

target="$(readlink -f "$(dirname "$path")" 2>/dev/null)/$(basename "$path")"
if git worktree list --porcelain | grep -qxF "worktree $target"; then   # -qxF: exact line, no substring/regex (gams vs gamsdiff)
  git worktree remove "$path"
  echo "removed worktree: $path"
fi
git worktree prune
if git show-ref --verify --quiet "refs/heads/$branch"; then
  git branch -d "$branch" && echo "deleted branch: $branch" \
    || echo "branch $branch not fully merged — left in place (use -D to force)" >&2
fi
```

- [ ] **Step 2: shellcheck (clean), with a `bash -n` fallback if shellcheck is absent**

```bash
if command -v shellcheck >/dev/null; then shellcheck scripts/wt-teardown.sh && echo "shellcheck clean"; \
else bash -n scripts/wt-teardown.sh && echo "shellcheck absent — bash -n syntax ok"; fi
```
Expected: `shellcheck clean` OR `shellcheck absent — bash -n syntax ok`.

- [ ] **Step 3: Commit**

```bash
git add scripts/wt-teardown.sh
git commit -m "feat(wt): safe worktree teardown script (remove + prune + branch -d)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Write the migration runbook

**Files:**
- Create: `docs/superpowers/runbooks/2026-06-27-wt-migration.md`

**Interfaces:**
- Produces: the step-by-step coordinator procedure Task 4 executes. No code; a gated runbook.

- [ ] **Step 1: Write the runbook with these exact sections**

Create `docs/superpowers/runbooks/2026-06-27-wt-migration.md`:
```markdown
# Runbook: Worktree migration (freeze → cut develop → worktrees)

Coordinator: the CI peer. Requires participation from all repo peers. Run top-to-bottom; do
not proceed past a gate that fails.

## 0. Preconditions
- `git -C <repo> rev-parse --abbrev-ref HEAD` == `feat/gams-solidity-difftest`.
- All peers reachable on the claude-peers network.

## 1. Announce freeze
Broadcast (send_message to each repo peer): "FREEZE: do not edit/commit/switch branches in the
shared checkout. Commit your own WIP one at a time when I call you; I'll cut `develop` after."

## 2. Tidy .gitignore (CI peer)
Ensure `__pycache__/`, GAMS scratch, and build artifacts are ignored so the post-freeze HEAD is
clean. Commit with own paths only.

## 3. Serialized WIP commit (one peer at a time)
For each peer in turn (coordinator calls them by ID):
- Peer runs `git add <its own paths>` (NEVER `git add -A`) and commits.
- `model/exp/` (untracked) is the GAMS peer's (43wxo1px) — commit or gitignore.

## 4. Submodule precondition (REQUIRED before cut — else Solidity worktrees can't init)
For each of the 5 moved-gitlink submodules (panoptic-v2-core, plank-foundry-deployer,
plank-monorepo, plankified-univ3, protocol):
- Owner commits INSIDE the submodule and **pushes that commit to the submodule's remote**.
- Then commits the moved gitlink in the superproject.
- GATE (a fresh per-worktree clone fetches from the .gitmodules URL, so the gitlink SHA must be
  an ancestor of the LIVE upstream — not just present in a stale remote-tracking ref):
  ```sh
  sha=$(git -C lib/<sub> rev-parse HEAD)          # the gitlink being recorded
  git -C lib/<sub> fetch origin                   # refresh remote-tracking refs FIRST
  def=$(git -C lib/<sub> symbolic-ref --short refs/remotes/origin/HEAD | sed 's#origin/##')
  git -C lib/<sub> merge-base --is-ancestor "$sha" "origin/$def"   # exit 0 = fetchable by a fresh clone
  ```
  If `merge-base --is-ancestor` is non-zero for any submodule, STOP — push the submodule commit
  to `origin/$def` (or the branch `.gitmodules` tracks) before cutting.

## 5. Cut develop + create worktrees (CI peer)
- Pin the exact post-freeze SHA verified in §4 (do not re-read HEAD, which could move):
  ```sh
  BASE=$(git rev-parse HEAD)                       # capture once, after §4 gate passes
  echo "cutting develop from $BASE"
  DEVELOP_BASE="$BASE" bash scripts/wt-setup.sh
  ```
- GATE: `git ls-tree develop tools/gamsdiff` and `git ls-tree develop Makefile` non-empty, AND
  `git rev-parse develop` == `$BASE`.

## 6. Announce the map
Broadcast each peer its worktree path + branch; peers `cd` there and resume.

## Rollback
Worktrees are additive; to undo, `scripts/wt-teardown.sh <name>` per peer and `git branch -d develop`
(only if unpushed/unused). The main checkout is never branch-switched, so it is unaffected.
```

- [ ] **Step 2: Verify the runbook references only real scripts/paths**

Run: `grep -E 'wt-setup.sh|wt-teardown.sh|peers.tsv' docs/superpowers/runbooks/2026-06-27-wt-migration.md && ls scripts/wt-setup.sh scripts/wt-teardown.sh scripts/peers.tsv`
Expected: grep matches; all three files exist.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/runbooks/2026-06-27-wt-migration.md
git commit -m "docs(wt): migration runbook (freeze, submodule-push gate, cut develop)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Coordinator-run live migration + worktree creation  ⚠️ NOT an automated-implementer task

**This task mutates the shared repo and requires the other 6 peers to participate. It is run by the coordinator (CI peer) WITH the user, following `docs/superpowers/runbooks/2026-06-27-wt-migration.md` — not by a fire-and-forget subagent.** A subagent-driven run stops here and hands control back.

- [ ] **Step 1: Execute the runbook sections 1–6 in order**, honoring every GATE.
- [ ] **Step 2: Verify worktrees**

```bash
git worktree list                                  # main + N peer worktrees
git -C ../cfmm-wt/gams status --porcelain          # empty (clean)
git -C ../cfmm-wt/gams submodule status | grep -c '^-'   # 8 (uninitialized)
# Solidity worktree: assert NO needed submodule is left uninitialized (a creds failure on a
# private submodule could leave a partial init even though forge-std (public) is populated):
git -C ../cfmm-wt/sol-tests submodule status | grep -c '^-'   # 0 (all initialized)
ls ../cfmm-wt/sol-tests/lib/forge-std/src 2>/dev/null | head  # populated
```
Expected: main + 6 (or 7) worktrees; gams clean + 8 uninitialized; sol-tests `^-` count **0** and forge-std populated. If sol-tests `^-` > 0, a submodule init failed (creds/network) — re-run `wt-setup.sh`.

- [ ] **Step 3: Announce the peer→worktree map over the peer network.**

---

## Deferred to Plan 2 (separate)

The per-track CI subsystem (reusable workflows `ci-*.yml`, per-peer callers, aggregate on
`develop`, `ci-gamsdiff` wheel confirmation, the 4 neutral gates) — most of it is blocked
(Phase-1 deps, GAMS/Lean runner stories), so it gets its own plan once `develop` exists and the
blockers clear.
