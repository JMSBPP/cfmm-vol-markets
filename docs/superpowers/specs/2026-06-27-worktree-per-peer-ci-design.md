# Design: One Worktree Per Peer + Per-Track CI (aggregate on `develop`)

**Date:** 2026-06-27
**Topic:** Isolate the 7 concurrent Claude peers into one git worktree each, with a dedicated per-track CI and an aggregate CI on the integration branch
**Scope track:** GitHub CI workflows / version control (see memory `session-scope-ci-version-control`)
**Status:** Revised after two-step review (Reality Checker + Git Workflow Master) — awaiting user approval

## Problem

Seven Claude peer instances share a **single working tree** in `cfmm-replicationPlank`. They
stomp on each other: the checked-out branch and uncommitted files change underneath each agent
mid-task (observed repeatedly — branch flipped `feat/gams-vendoring` →
`feat/gams-solidity-difftest`, `model/PricingKernel.gms` edited by the GAMS peer mid-measure,
Phase-1 squashing history live). Committed state is non-deterministic; no CI baseline is stable.

## Goal

Each peer works in an **isolated git worktree** on its **own branch**, forked from a shared
integration branch **`develop`**, merging back via PR. Each track has a **dedicated CI** that
runs only its gate; **`develop` runs the aggregate CI**.

## The 7 peers (peer network, 2026-06-27)

| Peer ID | Track | Owns | Branch | Worktree | lib/ |
|---|---|---|---|---|---|
| `43wxo1px` | GAMS model | `model/`, `.agents/gams/` | `feat/gams` | `../cfmm-wt/gams` | uninit |
| `ezav40jg` | Lean4 + math spec | `model/spec/*.md`, Lean4 | `feat/lean4-spec` | `../cfmm-wt/lean4-spec` | uninit |
| `ul2inqpl` | Plank / Solidity | Plank, `src/` | `feat/plank` | `../cfmm-wt/plank` | **init** |
| `e0q9pae8` | Solidity testing | Foundry `test/` | `feat/sol-tests` | `../cfmm-wt/sol-tests` | **init** |
| `0hpyy1t4` | gamsdiff | `tools/gamsdiff/` (Python) | `feat/gamsdiff` | `../cfmm-wt/gamsdiff` | uninit |
| `jzs7ddmg` | CI / version-control (me) | `.github/`, repo hygiene | `feat/ci` | `../cfmm-wt/ci` | uninit |
| `p5fh8ywz` | **TBD** (messaged; no reply yet) | — | `feat/<tbd>` | `../cfmm-wt/<tbd>` | uninit |

## Decisions (from brainstorming + review correction)

1. **Integration model:** shared **`develop`** + per-peer PRs back to it.
2. **`develop` base = the post-freeze committed HEAD of the current integration branch
   (`feat/gams-solidity-difftest`, currently `cc88cde`)** — NOT `master`. *Review proved* both
   `master` refs lack the peer code: local `master` (`33516776`) is a 3-entry stub; `origin/master`
   (`f484937`) lacks `tools/` + `.github/` and is 13 commits behind HEAD. The real peer work
   (`tools/gamsdiff`, recent `model/spec`, `src/.plk`, test fixtures) exists only on HEAD. **No
   later rebase of `develop`** — it is a shared base; force-pushing it would rewrite the merge-base
   under all 7 branches. Sanitization, if needed, lands on `develop` by normal commit/merge.
3. **Worktrees: submodules left UNINITIALIZED by default** (git's default `git worktree add`
   behavior — `lib/` exists with 8 empty subdirs, `git status` clean, `git submodule status` all
   `-`). The main checkout stays the heavy host. **Exception:** the two Solidity worktrees
   (`feat/plank`, `feat/sol-tests`) **DO** `git submodule update --init` so their peers get real
   `forge` isolation in their own worktree. **Mechanics (verified, git 2.54):** submodule init in a
   *linked* worktree does NOT share objects from `.git/modules` — it does a **fresh per-worktree
   clone** (network + credentials for private submodules) into `.git/worktrees/<wt>/modules/`, so
   budget ~a full submodule-clone (~1.6G) per Solidity worktree, not a cheap local copy. To share
   objects instead, init with `--reference <main>/.git/modules/<name>` (optional optimization).
   Note: `forge` still won't fully build there until the untracked `lib/*` deps are tracked
   (Phase 1) — isolation now, working build after.
4. **CI runs the heavy builds**, not the 5 source-only worktrees.

## WIP migration (serialized commit-then-cut — first executable step)

The shared tree is dirty (uncommitted `model/PricingKernel.gms`, `test/Utils.t.sol`,
`.gitignore`, `CLAUDE.md`, untracked `model/exp/`, 5 dirty submodule gitlinks) on
`feat/gams-solidity-difftest`, with 7 agents on **one index**. Parallel stash/commit on one index
is the exact race this design kills, so migration is **serialized and announced**:

1. Announce a brief freeze over the peer network. The freeze is what makes serialization safe — it
   guarantees no other peer mutates the shared index while a given peer commits.
2. Each peer, **one at a time**, commits its own WIP scoped to its own paths
   (`git add <own paths> && git commit`, never `git add -A`), so the coordinator can't sweep another
   track's WIP into one commit. `model/exp/` (untracked) is owned by the **GAMS peer** (`43wxo1px`) —
   it commits or `.gitignore`s it. Tidy `.gitignore` first so the post-freeze HEAD is clean
   (`__pycache__/`, build artifacts, the already-tracked `docs/superpowers/` specs are fine).
3. **Submodule precondition (required for the 2 Solidity worktrees to init):** for every submodule
   whose **gitlink moves** (currently 5: `panoptic-v2-core`, `plank-foundry-deployer`,
   `plank-monorepo`, `plankified-univ3`, `protocol`), the owner must first commit *inside* the
   submodule **and push that submodule commit to its remote**, then commit the moved gitlink in the
   superproject. Otherwise the Solidity worktrees' fresh-clone `--init` cannot fetch a local-only SHA
   and success criterion #3 fails. Verify each: `git -C lib/<sub> cat-file -e <sha>^{commit}` AND the
   SHA is on a remote-tracking ref.
4. After the freeze drains, cut `develop` from the resulting committed HEAD; create the worktrees;
   each peer branch starts from `develop` with all committed code present.
5. Peers then work only in their worktrees.

This step is owned by one coordinator (the CI peer) and is a prerequisite to worktree creation.

## Worktree layout

```
cfmm-replicationPlank/     main checkout — heavy host (submodules + untracked deps); NEVER branch-switched by the script
../cfmm-wt/<peer>/         7 worktrees off feat/<track>; 5 source-only (submodules uninit), 2 Solidity submodule-init
```
Worktrees share the main `.git` for the **superproject** (observed 2026-06-27: ~1.6G, almost
entirely `.git/modules`); each source-only worktree adds only tracked source + a few KB under
`.git/worktrees/<name>/`. The 2 Solidity worktrees, by contrast, each get a **fresh per-worktree
submodule clone** (not shared — see Decision #3), so budget roughly another full submodule-set each.
Disk observed: 162G free — ample for 5 light + 2 heavy worktrees.

## CI architecture (DRY via reusable workflows)

One **reusable workflow per track**; a thin per-peer caller (path-filtered, on the peer branch)
`uses:` its own; the **aggregate on `develop`** `uses:` all. Honest runnability:

| Reusable workflow | Gate | Runnable on a clean hosted runner NOW? |
|---|---|---|
| `ci-gamsdiff.yml` | `uv sync` + `pytest` (GAMS-live tests `skipif`-gated) | **Expected** — once `develop` carries `tools/gamsdiff/`, **iff** the `gamsapi[transfer]==54.1.*` wheel installs for the runner's Linux/Python ≥3.11. Note: `skipif` gates test *execution*, but `shell.py` does a top-level `from gams import …`, so the wheel must import at pytest *collection* — confirm the wheel resolves before claiming green |
| `ci-gams.yml` | `make compile-gams` | **No** — GAMS is proprietary/absent on hosted runners (`shell.py` hardcodes `/usr/gams/...`); needs a self-hosted or container+license runner story |
| `ci-lean.yml` | Lean4 build | **No** — no Lean project exists yet (`model/spec/` is Markdown only; no `lakefile`/`*.lean`) |
| `ci-plank.yml` | `make compile-plank` | **No** — needs `plankified-univ3` + plank toolchain in CI |
| `ci-sol-tests.yml` | `forge test --via-ir` | **No** — needs the untracked `lib/*` deps tracked (Phase 1) |

**`ci-gamsdiff` is the only candidate real gate now** (green pending one-time confirmation that the
`gamsapi` wheel installs — see its row). The other four are **neutral/skipped**
(emit a GitHub *neutral* conclusion via a step that exits with the skip status — NOT a green
`success`, which would be falsely-green and invisible to required-checks), each with a one-line
reason, until its prerequisite lands. The aggregate `develop` CI therefore currently **certifies
only `ci-gamsdiff`**; it is not a full integration gate yet, and none of the neutral gates may be
marked a required check.

**Gate mechanism** (when a gate becomes real): **per-file allowlist** of known-failing files
(reds on any file outside the allowlist breaking), with a **setup phase that must succeed**
separated from the **compile phase** — a toolchain failure is a distinct red from accepted WIP.

## Setup mechanism

`scripts/wt-setup.sh` — idempotent (git ops error on re-run, so each is guarded):
```sh
git worktree prune                                   # clear stale registrations first
git show-ref --verify --quiet refs/heads/develop \
  || git branch develop <post-freeze-HEAD>           # exact ref, not "master"
# guard the push: no network on a clean re-run, no non-ff surprise
git ls-remote --exit-code origin develop >/dev/null 2>&1 || git push -u origin develop
for peer in <map>; do                                # origin = JMSBPP fork (has master); not upstream
  git show-ref --verify --quiet "refs/heads/$branch" || git branch "$branch" develop
  # resolve against the PARENT so readlink works before ../cfmm-wt exists on first run
  target="$(readlink -f "$(dirname "$path")" 2>/dev/null)/$(basename "$path")"
  if git worktree list --porcelain | grep -qx "worktree $target"; then
    :                                                # already registered — skip
  elif [ -e "$path" ]; then
    echo "WARN: $path exists but is not a registered worktree — skipping (run 'git worktree prune' / inspect)" >&2
  else
    git worktree add "$path" "$branch"
  fi
done
# for feat/plank and feat/sol-tests only (per-worktree fresh clone — network + creds):
#   (cd "$path" && git submodule update --init --recursive)
```
The script **never switches the main checkout's branch** (main is dirty; a switch would block or
drag changes). A companion `wt-teardown.sh` does `git worktree remove <path>` → `git branch -d
<branch>` → `git worktree prune`.

## Coordination

- Each peer `cd`s to its worktree and works only there; main is the reserved build host.
- Peers PR `feat/<track>` → `develop`; the dedicated CI gates the PR; merge runs the aggregate.
- The peer→branch→path map is published here and announced over the peer network.
- **Do not `git submodule update --init` inside a source-only worktree** (only the 2 Solidity ones).

## Out of scope

- **Fixing the untracked `lib/*` deps** — Phase 1 (this design only un-stubs the dependent CIs later).
- **Standing up GAMS/Lean CI runners** and authoring the Lean project — separate work; those gates stay neutral until then.
- **Branch-protection / required-checks** — repo-settings, later; must account for path-filter/skipped-check interaction and must not require any neutral gate.

## Success criteria

1. `develop` exists, forked from the **named post-freeze HEAD of `feat/gams-solidity-difftest`** (a
   commit that contains `tools/gamsdiff/`, `model/`, `Makefile`, `src/`, `test/`), and is pushed to
   `origin`. Verified: `git ls-tree develop tools/gamsdiff` and `git ls-tree develop Makefile` are
   non-empty **before** any worktree is created.
2. `scripts/wt-setup.sh` is idempotent (second run is a clean no-op) and creates one worktree per
   declared peer at `../cfmm-wt/<name>` on `feat/<track>` off `develop`.
3. The 5 source-only worktrees: `git -C <wt> status --porcelain` empty AND `git -C <wt> submodule
   status` all lines start with `-` (uninitialized). The 2 Solidity worktrees: their submodules are
   initialized (`git submodule status` non-`-` for the needed ones).
4. A reusable workflow exists per track; each declared peer branch has a path-filtered caller; `develop` has an aggregate calling all.
5. `ci-gamsdiff` passes on a clean runner **once the `gamsapi==54.1.*` wheel is confirmed to install
   for the runner's OS/Python** (evidenced by a run URL; until then it is "expected green", not
   asserted green); the other four gates report a **neutral/skipped** conclusion (not green), each
   with a reason; no neutral gate is a required check.
6. The peer→branch→worktree map is documented and announced.

## Verification

- `bash scripts/wt-setup.sh` twice → second run clean no-op.
- `git ls-tree develop tools/gamsdiff` non-empty (B1 guard).
- `git -C ../cfmm-wt/gams status --porcelain` empty; `git -C ../cfmm-wt/gams submodule status` all `-`.
- In a Solidity worktree, `git submodule update --init` **completes** (network + creds available),
  then `git -C ../cfmm-wt/sol-tests submodule status` shows non-`-` (initialized) AND the submodule
  working trees are populated (e.g. `ls ../cfmm-wt/sol-tests/lib/forge-std/src` non-empty) — proving
  the fresh-clone init succeeded, not just that a gitlink exists.
- `actionlint .github/workflows/*.yml` clean.
- Push to a peer branch → only that track's caller runs (path filter); the `ci-gamsdiff` run is green, the four neutral gates report skipped with reasons.

## Open items

- 7th peer (`p5fh8ywz`) track — messaged, awaiting reply; reserved slot filled on response.
- GAMS-in-CI runner story (self-hosted vs container+license) and a real Lean project — prerequisites to un-stub `ci-gams`/`ci-lean`.
- Un-stub `ci-plank`/`ci-sol-tests` when the untracked deps are tracked (Phase 1).
- Confirm the `gamsapi==54.1.*` wheel exists for the runner OS/Python (else `uv sync` fails).
