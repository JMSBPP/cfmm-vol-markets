---
phase: 01-red-differential-scaffold
plan: 01
subsystem: infra
tags: [git-worktree, github-issues, gsd-planning, symlink, process]

# Dependency graph
requires: []
provides:
  - "`.planning/phases/FEATURES/` layout tracked on `develop` (README + `feat-red-diff-scaffold` symlink, mode 120000)"
  - "Tracking issue JMSBPP/cfmm-vol-markets#57 for Phase 1"
  - "Git worktree at `/home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold` on branch `feat/red-diff-scaffold`, pushed to `origin`"
affects: [01-02, 01-03, 01-04, 01-05, 01-06, all-phase-1-plans, feature-phases-2-through-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FEATURES phase-directory layout via git-tracked symlink into the numbered GSD phase dir"
    - "Worktree + tracking issue opens every phase"

key-files:
  created:
    - .planning/phases/FEATURES/README.md
    - .planning/phases/FEATURES/feat-red-diff-scaffold (symlink -> ../01-red-differential-scaffold)
  modified: []

key-decisions:
  - "FEATURES entries are git-tracked symlinks (mode 120000), not real directories, because gsd-tools.cjs' phase scan does not follow symlinks — the numbered path stays tool-facing, the FEATURES path human-facing"
  - "`feat/red-diff-scaffold` is branched from the pushed `develop` tip carrying the FEATURES layout, so PROC-01 evidence is an ancestor of every Phase 1 code commit"
  - "The new worktree is left with submodules uninitialized and no `out/`/`cache/` — CI is the only build environment"

patterns-established:
  - "Phase opening ritual: commit layout to develop -> open tracking issue -> create worktree branched from the pushed develop tip -> push branch"
  - "FEATURES README carries the full 11-phase branch roster, so later phases have a canonical slug/branch mapping"

requirements-completed: [PROC-01]

# Metrics
duration: 3min
completed: 2026-08-27
---

# Phase 1 Plan 01: Phase Opening — FEATURES Layout, Tracking Issue, Worktree Summary

**Phase 1 opened per the milestone's binding ritual: the `.planning/phases/FEATURES/` layout is now a tracked, pushed path on `develop` (README + mode-120000 symlink), tracking issue #57 is open on the JMSBPP fork, and the `feat/red-diff-scaffold` worktree exists locally and on `origin` at the `develop` tip with nothing built locally.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-27T16:44:58Z
- **Completed:** 2026-08-27T16:47:30Z
- **Tasks:** 3
- **Files modified:** 2 created (1 regular file, 1 symlink)

## Accomplishments

- **PROC-01 satisfied on `develop`.** `.planning/phases/FEATURES/README.md` documents the
  `feat-<slug>/` convention, explains why the entries are symlinks, and carries the full
  11-phase roster mapping phase number → FEATURES path → `feat/…` branch.
- **The FEATURES path is real, not aspirational.** `git ls-files -s` reports mode `120000` for
  `feat-red-diff-scaffold`, and `.planning/phases/FEATURES/feat-red-diff-scaffold/01-01-PLAN.md`
  resolves through the symlink to the actual plan files on both `develop` and the feature branch.
- **Tracking issue #57 opened** on `JMSBPP/cfmm-vol-markets`, naming the branch, the worktree
  path, the plans directory, all seven requirement IDs (RED-01…06, PROC-01) and the five
  success criteria as checkboxes — exactly one open issue matches the title.
- **Feature worktree live.** `/home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold` on
  `feat/red-diff-scaffold`, HEAD `04dea0a` == `origin/develop`, pushed to `origin` with an
  upstream tracking ref. Plans 01-02 through 01-06 now have a worktree to write into.

## Task Commits

1. **Task 1: Commit the FEATURES layout to develop** — `04dea0a` (docs), pushed to `origin/develop`
2. **Task 2: Open the Phase 1 tracking issue** — no repo commit (GitHub artifact: issue #57)
3. **Task 3: Create the feat/red-diff-scaffold worktree** — no repo commit (git worktree +
   branch `feat/red-diff-scaffold` pushed to `origin`)

**Plan metadata:** see final `docs(01-01)` commit.

## Key Artifacts

| Artifact | Value |
|----------|-------|
| Tracking issue | [JMSBPP/cfmm-vol-markets#57](https://github.com/JMSBPP/cfmm-vol-markets/issues/57) |
| Feature worktree | `/home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold` |
| Feature branch | `feat/red-diff-scaffold` (tracking `origin/feat/red-diff-scaffold`) |
| `develop` SHA carrying FEATURES layout | `04dea0a653d92fb049492097db3ac18d051624ce` |
| Main/planning worktree | `/home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets` (`develop`) |

## Files Created/Modified

- `.planning/phases/FEATURES/README.md` — written statement of the FEATURES phase-directory
  layout, the symlink rationale (gsd-tools does not follow symlinks), the v2 deferral (V2-05),
  and the 11-phase branch roster. PROC-01 evidence.
- `.planning/phases/FEATURES/feat-red-diff-scaffold` — git-tracked symlink (mode `120000`) to
  `../01-red-differential-scaffold`, making the FEATURES path address the real plan files.

## Verification Performed

All verification was static (git plumbing, filesystem, `gh` API). **No local build was run** —
per the project's binding constraint, CI (`develop-gate`) is the only build environment.

| Criterion | Result |
|-----------|--------|
| `git ls-files -s …/feat-red-diff-scaffold` begins with `120000` | PASS |
| `readlink …/feat-red-diff-scaffold` == `../01-red-differential-scaffold` | PASS |
| `test -f …/FEATURES/feat-red-diff-scaffold/01-01-PLAN.md` | PASS |
| `grep -c 'feat-' FEATURES/README.md` >= 11 | PASS (13) |
| `grep -q 'PROC-01' FEATURES/README.md` | PASS |
| `git log origin/develop -1 --name-only` lists `FEATURES/README.md` | PASS |
| `git status --porcelain .planning/phases/FEATURES` empty | PASS |
| Exactly one open issue titled `Phase 1: RED Differential Scaffold (feat/red-diff-scaffold)` | PASS (#57) |
| Issue body contains `RED-0` and `feat/red-diff-scaffold` | PASS |
| `worktree list` shows `red-diff-scaffold [feat/red-diff-scaffold]` | PASS |
| Worktree HEAD == `origin/develop` (`04dea0a…`) | PASS |
| `git ls-remote --heads origin feat/red-diff-scaffold` → 1 ref | PASS |
| Worktree contains `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` | PASS |
| Worktree has no `out/` and no `cache/` | PASS |
| Worktree `lib/forge-std` empty (submodules uninitialized) | PASS |

## Decisions Made

- **No commits for Tasks 2 and 3.** Both produce artifacts outside the git tree (a GitHub issue;
  a worktree and a branch ref). Their evidence lives in the issue number and the pushed branch,
  recorded above rather than manufactured as an empty commit.
- **Left the pre-existing dirty working tree untouched.** `AGENTS.md`, the `offchain`/`spec`
  submodule pointers, `src/modules/premium/DynamicFeeMod.plk`, `TODO.md` and the
  `docs/superpowers/specs/…` file were already modified/untracked before execution and belong to
  other work. Every `git add` in this plan named explicit paths; no `git add -A`/`git add .` was
  used.
- **`.planning/config.json` deliberately not committed.** Its only diff is the
  `workflow._auto_chain_active: false` key written by `gsd-tools init`, which is tooling state,
  not plan output.

## Deviations from Plan

No deviations occurred inside the three plan tasks — Tasks 1–3 executed exactly as written.
One blocking fix was required in the post-task bookkeeping:

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repaired STATE.md so `gsd-tools state advance-plan` can parse it**
- **Found during:** post-task state updates (not a plan task)
- **Issue:** `state advance-plan` failed with
  `Cannot parse Current Plan or Total Plans in Phase from STATE.md`. `bin/lib/state.cjs`
  reads discrete `Current Plan:` / `Total Plans in Phase:` fields, but STATE.md carried only
  the prose line `Plan: 0 of TBD in current phase`. The plan counter could not advance.
- **Fix:** Added the two canonical fields to `## Current Position` alongside the human-readable
  `Plan: N of 6` line, then re-ran `advance-plan` (0 → 1). Also corrected two cosmetic
  tool-output defects: `state record-metric` appended its row *after* the
  `*Updated after each plan completion*` line instead of into a table (moved into a new
  `**Per-plan:**` table), and `state add-decision` appended below the
  `Open by design — do not pre-resolve` block (moved above it, where resolved decisions belong).
  `roadmap update-plan-progress 01` reported `updated: true` but produced no diff, so the
  `1. RED Differential Scaffold | 1/6 | In Progress` row and the `01-01-PLAN.md` checkbox were
  set directly.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Verification:** `state advance-plan` now returns
  `{"advanced": true, "previous_plan": 0, "current_plan": 1, "total_plans": 6}`;
  `git diff .planning/ROADMAP.md` shows both intended edits.
- **Committed in:** final plan-metadata commit

---

**Total deviations:** 1 auto-fixed (1 blocking). Confined to `.planning/` bookkeeping; no
protocol source, test, or CI file was touched. No scope creep.

### Note on the plan's context block

One documented difference from the plan's *context* block (not a deviation in execution): the
plan stated `.planning/phases/` was entirely untracked. By execution time the six `01-*-PLAN.md`
files were already tracked from commit `72cfe99`, so the `git add
.planning/phases/01-red-differential-scaffold/` step in Task 1 was a no-op. The FEATURES
directory was untracked as described and was added by this plan. No corrective action was
needed and no criterion changed.

## Issues Encountered

- The push to `origin develop` reported `Bypassed rule violations … Required status check "gate"
  is expected.` The branch protection rule on `develop` expects a `gate` check that a
  `.planning/`-only push does not trigger (`develop-gate` runs on `pull_request` only). The push
  succeeded via the bypass allowance. This is expected for planning-artifact pushes and does not
  affect code work, which lands via PR from `feat/red-diff-scaffold` in plan 01-05.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Ready.** Plan 01-02 can begin immediately:

- Write all code artifacts inside `/home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold`
  (branch `feat/red-diff-scaffold`), never in the main worktree.
- Keep planning artifacts (`PLAN`/`SUMMARY`/`STATE`/`ROADMAP`) in
  `/home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets` on `develop`.
- Reference issue **#57** in the plan 01-05 PR body.
- Do not run `forge`, `make`, `npm ci` or `cabal` in the feature worktree; submodules are
  intentionally uninitialized. Gate evidence arrives with the PR in plan 01-05, since
  `develop-gate` triggers on `pull_request` only.

---
*Phase: 01-red-differential-scaffold*
*Completed: 2026-08-27*

## Self-Check: PASSED

All claimed artifacts verified to exist:
- `.planning/phases/FEATURES/README.md` — FOUND
- `.planning/phases/FEATURES/feat-red-diff-scaffold` — FOUND (symlink, mode 120000 in index)
- `.planning/phases/01-red-differential-scaffold/01-01-SUMMARY.md` — FOUND
- `/home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold` — FOUND (worktree on `feat/red-diff-scaffold`)
- Commit `04dea0a` — FOUND (on `develop` and `origin/develop`)
- Issue JMSBPP/cfmm-vol-markets#57 — FOUND (OPEN)
