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
