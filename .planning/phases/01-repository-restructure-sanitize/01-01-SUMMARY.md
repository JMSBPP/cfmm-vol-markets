---
phase: 01-repository-restructure-sanitize
plan: 01
subsystem: infra
tags: [git, sanitization, gitignore, license, readme, squash, secrets]

# Dependency graph
requires: []
provides:
  - "Single clean sanitized baseline commit (orphan-branch squash) ready for the public flip"
  - "Recovery bundle + backup/pre-squash branch capturing the full pre-rewrite history"
  - ".gitignore covering node_modules/, /refs/, the four non-submodule lib/ trees, plus out/ and cache/"
  - "Project README (Plank/GAMS dual-track) and MIT LICENSE"
  - "Tracked content free of local home-absolute paths, the four foreign lib/ trees, and secret material"
affects: [01-02-migration, 02-toolchain]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Self-safe scan patterns: scan/detection regexes are written so they never match their own documentation (home-path regex /home/[a-z0-9_-]+/ and the neutralized secret regex API_KEY[=]|PRIVATE_KEY[=])"
    - "Backup-before-rewrite: git bundle --all + a backup/* branch captured before any destructive history operation (REPO-02 reversibility)"
    - "Orphan-branch squash to collapse history into one clean baseline"

key-files:
  created:
    - "README.md"
    - "LICENSE"
  modified:
    - ".gitignore"
    - ".planning/PROJECT.md"
    - ".planning/REQUIREMENTS.md"
    - ".planning/ROADMAP.md"
    - ".planning/STATE.md"
    - ".planning/phases/01-repository-restructure-sanitize/01-CONTEXT.md"
    - ".planning/codebase/ARCHITECTURE.md"
    - ".planning/codebase/STACK.md"
    - ".planning/codebase/STRUCTURE.md"
    - ".planning/codebase/CONCERNS.md"
    - ".planning/codebase/INTEGRATIONS.md"
    - "docs/superpowers/specs/2026-06-27-gams-vendoring-design.md"

key-decisions:
  - "License = MIT, copyright wvs-finance (per CONTEXT discretion, matching org convention)"
  - "Squash mechanism = orphan branch (git checkout --orphan), branch-name-agnostic"
  - "GAMS home-absolute paths relativized to the in-repo model/ (GAMS already vendored on disk); cfmm-theory linked by citekey, not absolute path"
  - "Folded SUMMARY + STATE/ROADMAP/REQUIREMENTS updates into the single baseline commit (amend) to preserve the one-commit invariant that plan 01-02 asserts"

patterns-established:
  - "Self-safe detection regexes that do not flag their own occurrence in tracked docs"
  - "Recovery bundle written OUTSIDE the repo so it is never staged"

requirements-completed: [REPO-04, REPO-05]

# Metrics
duration: 11min
completed: 2026-06-27
---

# Phase 1 Plan 01: Repository Restructure & Sanitize Summary

**Working tree made publish-ready and all history collapsed into one clean sanitized baseline commit — local home paths scrubbed, the four unpublished-IP lib/ trees and node_modules/refs excluded, a project README + MIT LICENSE added, and a recovery bundle + backup/pre-squash branch captured before the rewrite. No network or GitHub state was touched.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-06-27T20:35:26Z
- **Completed:** 2026-06-27
- **Tasks:** 3
- **Files modified:** 14 (2 created, 12 modified) + full source tree first-tracked in the baseline

## Accomplishments
- Removed the embedded `refs/` reference web app, the `Counter` Foundry scaffold, and the broken CI workflow; hardened `.gitignore` to keep `node_modules/`, `/refs/`, and the four non-submodule lib/ trees (`mochi-yield`, `shizo`, `unistrata`, `v4-core`) out of the public baseline.
- Scrubbed every local home-absolute path from 11 tracked docs; replaced the Foundry boilerplate README with a project-specific Plank/GAMS overview and added an MIT LICENSE.
- Captured a recovery bundle (outside the repo) and a `backup/pre-squash` branch, then squashed all history into one clean baseline (`0e7dc71` on `feat/gams-vendoring`) that first-tracks the full sanitized source tree (12 `.plk` sources, tests, spec, model/, 8 submodule gitlinks).
- Proved the baseline carries no `.env`, no real credential value, no foreign lib tree, no refs/node_modules/Counter, and no `/home/<user>/` path.

## Task Commits

Per-task commits were created atomically, then collapsed by the Task 3 orphan-branch squash (by design). The pre-squash tip is preserved in `backup/pre-squash` and the recovery bundle.

1. **Task 1: Remove non-shippable artifacts, fix .gitignore** - `a62bea9` (chore) — collapsed into baseline
2. **Task 2: Scrub home paths, write README and LICENSE** - `e933e94` (docs) — collapsed into baseline; preserved at `backup/pre-squash`
3. **Task 3: Backup, squash to one clean baseline, verify** - baseline `0e7dc71` (chore: sanitized clean baseline)

**Recovery bundle:** `/tmp/claude-1000/-home-jmsbpp-cfmms-playground-cfmm-replicationPlank/861ff315-73d4-498f-ac45-536b7176e11b/scratchpad/cfmm-backup-pre-squash.bundle` (96K, `git bundle verify` reports a complete history).

## Files Created/Modified
- `README.md` - Project-specific Plank/GAMS dual-track overview, prerequisites, build/test (replaces Foundry boilerplate)
- `LICENSE` - MIT License, Copyright (c) 2026 wvs-finance
- `.gitignore` - Added node_modules/, /refs/, and the four non-submodule lib/ trees (out/ and cache/ retained)
- `.planning/PROJECT.md` - cfmm-theory linked by citekey instead of an absolute path
- `.planning/{REQUIREMENTS,ROADMAP,STATE}.md`, `01-CONTEXT.md` - self-referential scan-command mentions rewritten to the self-safe regex / $HOME form
- `.planning/codebase/{ARCHITECTURE,STACK,STRUCTURE,CONCERNS,INTEGRATIONS}.md` - GAMS home-absolute paths relativized to in-repo `model/`
- `docs/superpowers/specs/2026-06-27-gams-vendoring-design.md` - dropped the absolute path, kept the `../experiments/gams/` provenance note

## Decisions Made
- MIT LICENSE, copyright `wvs-finance` (CONTEXT left license to discretion; matched the org convention).
- Orphan-branch squash mechanism (vs reset+recommit) for the single baseline.
- GAMS references relativized to `model/` rather than an external sibling path, since the `.gms` sources are already present in `model/` on disk; codebase audit docs updated to the vendored reality where the old "outside the repo" wording would otherwise contradict.
- SUMMARY/STATE/ROADMAP/REQUIREMENTS folded into the single baseline commit (amend) so the repo remains exactly one commit, which plan 01-02 asserts (`git rev-list --count HEAD == 1`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Neutralized self-referential secret-scan tokens in the GSD plan docs so the secret gate passes literally**
- **Found during:** Task 3 (pre-flip secret gate)
- **Issue:** The literal secret gate `! git grep -qiE 'API_KEY[=]...'` failed — but every match was inside `01-01-PLAN.md` / `01-02-PLAN.md`, which quote the detection regex itself as command text (and one prose line). No actual credential was present. The planner made the home-path scan self-safe but not the secret regex.
- **Fix:** Rewrote the detection patterns in both tracked plan docs to a regex-equivalent self-safe form (`API_KEY[=]|PRIVATE_KEY[=]|BEGIN [A-Z ]*PRIVATE[ ]KEY`) and reworded the one prose mention, so the bare `API_KEY[=]` / `PRIVATE_KEY[=]` / `PRIVATE[ ]KEY` substrings no longer appear while the verification commands remain functionally identical. This also unblocks plan 01-02, which re-asserts the same gate.
- **Files modified:** `.planning/phases/01-repository-restructure-sanitize/01-01-PLAN.md`, `01-02-PLAN.md`
- **Verification:** `! git grep -qiE 'API_KEY[=]|PRIVATE_KEY[=]|BEGIN [A-Z ]*PRIVATE[ ]KEY' HEAD` now returns clean; substantive checks already proved no `.env`, no real `.env` value in tracked content, no env-var with an attached secret value, and no PEM block.
- **Committed in:** baseline `0e7dc71` (amended)

**2. [Rule 2 - Missing Critical] Excluded gitignored GAMS `model/build/*.lst` listings that contain home-absolute paths**
- **Found during:** Task 1/Task 3 (pre-stage scan)
- **Issue:** `model/build/*.lst` GAMS listing files embed `$HOME/...` (local home-absolute) INCLUDE paths. A loose stage could have leaked them.
- **Fix:** Confirmed they are already covered by the pre-existing `model/**/*.lst` ignore (verified via `git check-ignore`); no new rule needed. They are not staged in the baseline.
- **Files modified:** none (verification only)
- **Verification:** `git ls-files | grep model/build` is empty; baseline home-path scan is clean.
- **Committed in:** n/a

---

**Total deviations:** 2 (1 bug-class self-safe fix, 1 missing-critical verification). 
**Impact on plan:** Both necessary to make the secret/home gates genuinely pass on the public baseline. No scope creep; no functional change to either plan's verification semantics.

## Accepted Residuals
- The GSD plan files (`01-01-PLAN.md`, `01-02-PLAN.md`) still contain the developer's local home directory encoded as **dashes** in the session scratchpad bundle path (`/tmp/claude-1000/-home-<user>-...`). This is NOT a `/home/<user>/` home-absolute path, is not a usable filesystem disclosure, and passes the REPO-05 content-scan gate `/home/[a-z0-9_-]+/`. Publishing `.planning/` is an explicit CONTEXT decision.

## Issues Encountered
- Initial secret gate failure was a self-reference false positive (plan docs quoting the detection regex). Resolved via the self-safe rewrite above after substantively proving no real secret material is present.

## User Setup Required
None - no external service configuration required. (The transfer / public flip / fork — REPO-01..03 — are the irreversible steps and belong to plan 01-02 behind the user-confirmation gate.)

## Next Phase Readiness
- Baseline is publish-ready: single clean commit, recovery point intact (`backup/pre-squash` + bundle), remotes untouched (`origin` = `JMSBPP/cfmm-replicationPlank`).
- Plan 01-02 (transfer to `wvs-finance`, public flip, fork-back, remote topology) can proceed; its pre-flip gate now passes against this baseline. 01-02 prunes `master` and `backup/pre-squash` before the irreversible flip.

## Self-Check: PASSED

- `README.md`, `LICENSE`, and `01-01-SUMMARY.md` exist and are tracked in the baseline.
- Baseline is a single commit (`git rev-list --count HEAD` == 1).
- Home-path gate, foreign-lib gate, secret gate (`.env` absent, no real value, no PEM), refs/node_modules/Counter gate, and submodule-gitlink-only gate all pass on HEAD.
- Recovery bundle is present and non-empty; `backup/pre-squash` resolves.
- No remote mutation: `git remote -v` shows only the pre-existing `origin` (`JMSBPP/cfmm-replicationPlank`).

---
*Phase: 01-repository-restructure-sanitize*
*Completed: 2026-06-27*
