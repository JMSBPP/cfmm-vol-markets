# Deferred items — Phase 10

Out-of-scope discoveries logged (not fixed) during plan execution, per the
executor scope boundary: only issues DIRECTLY caused by a task's own changes are
auto-fixed.

## From 10-07

| Item | Where | Why deferred |
|---|---|---|
| `-Wx-partial` warning on `head rows` | `econometrics/app/Main.hs` `runIndexBuild` (~L1001) | Pre-existing (plan 10-03). Not touched by 10-07's changes. |
| `-Wincomplete-uni-patterns` on the `(seB : seU : seK : _)` binding | `econometrics/app/Main.hs` `reportToStdout` (~L1807) | Pre-existing (plan 09-08/09-09). |
| `-Wx-partial` warning on `head us > last us` | `econometrics/app/Main.hs` (~L2208, alternatives helper) | Pre-existing (plan 09-09). |
| Untracked stray file `bpp@hotmail.es>` at the repo root | worktree root | Not created by this track; belongs to another concurrent session's shell mishap. Deleting another session's file is out of bounds. |
| Untracked/modified `model/exp/eta.md`, `model/exp/eta_pi_trader_delta_control.md` | `model/` | Owned by the GAMS/model track, not the Lean4+Haskell econometrics track. |

None of the above affects the reconciliation gate path.

## From 10-11

| Item | Where | Why deferred |
|---|---|---|
| Stale wedge bound in the docstring: `multiplierWedge` documents the long-side factor as bounded by `1.125`, which the measurements refute (`1 + nu*R/N <= 1 + nu` requires `R <= N`; here `R/N` reaches 2.333333, measured long max 1.291667, short max 1.204167) | `econometrics/src/Panoptic/Premium.hs` (~L190-208) | This is a CODE change; 10-11's `files_modified` is markdown only. The correction already lives in `2026-07-20-upsilon-estimates-v2.md` §7, `2026-07-27-upsilon-estimates-v3.md` §8, and `lean-haskell-crosswalk.md`. Fixing the docstring changes no behaviour and no test. |

The two stray/foreign working-tree items logged under 10-07 (`bpp@hotmail.es>` at the repo
root; `model/exp/*`) were still present at 10-11 and were again left untouched — `model/` is
the GAMS-development session's track per `CLAUDE.md`.
