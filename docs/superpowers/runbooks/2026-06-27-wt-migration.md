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
