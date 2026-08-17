---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 07
subsystem: econometrics
tags: [haskell, hmatrix-gsl, levenberg-marquardt, ad, nls, gmm, eiv, instrumental-variables, lean-mirror]

# Dependency graph
requires:
  - phase: 09-01
    provides: econometrics/ Stack project, hmatrix-gsl extra-dep (GSL 2.8), CR0 sandwich golden fixture
  - phase: 09-04
    provides: Econ.Types (Obs/Panel/Theta), Panel.Build (dailyEpoch, strikeToTick, panel.csv)
  - phase: 09-05
    provides: Panel.Variance (σ̂²_t realizedVariance, σ̃²_t instrumentVariance, variance.csv)
provides:
  - "Model.Upsilon: Lean-mirrored model function (β₀+υ₀·exp(−κ·d)·σ̂²), moneyness |i_K−i_t|, tickBase 1.0001, modelSplit κ⁺/κ⁻"
  - "Model.NLS: fitGSL/fitGSLCov (hmatrix-gsl Levenberg-Marquardt PRIMARY + covariance handle) and fitAD (ad Gauss-Newton/LM cross-check)"
  - "Model.EIV: ivFit (two-noisy-measures IV — σ̃² instruments σ̂², E[Z·v]=0)"
  - "estimate CLI subcommand: panel.csv ⋈ variance.csv → fitGSL + ivFit point estimates"
  - "lean-haskell-crosswalk.md: Lean ↔ Haskell ↔ spec § fidelity table (bridging-lemma witness evidence)"
affects: [09-08, 09-09, 09-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GSL fitModel as PRIMARY NLS; ad-based hand-rolled LM retained only as a synthetic cross-check golden"
    - "Floating-generic model function so the SAME code is fit by GSL and differentiated by ad"
    - "Two-step nonlinear IV: κ̂ from NLS (identified off moneyness), then just-identified IV (ZᵀX)⁻¹Zᵀy for (β₀,υ₀)"
    - "Deterministic LCG noise (fixed seed) for reproducible synthetic-recovery tests"

key-files:
  created:
    - econometrics/src/Model/Upsilon.hs
    - econometrics/src/Model/NLS.hs
    - econometrics/src/Model/EIV.hs
    - econometrics/test/Model/UpsilonSpec.hs
    - econometrics/test/Model/NLSSpec.hs
    - notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md
  modified:
    - econometrics/app/Main.hs
    - econometrics/package.yaml
    - econometrics/test/Spec.hs

key-decisions:
  - "GSL fitModel jacobian supplied analytically ([1, e·σ̂², −d·υ₀·e·σ̂²], e=exp(−κ·d)); returns GSL covariance matrix for 09-08 SE"
  - "modelSplit κ⁺/κ⁻ uses (exp(−κ⁺·d⁺)+exp(−κ⁻·d⁻)−1) so it stays Floating-only (ad-differentiable, no Ord) and does not double-count at the money"
  - "ivFit conditions on κ̂ from fitGSL (κ identified from cross-sectional moneyness, not the EIV-threatened variance level), then IV-corrects the level"
  - "estimate CLI degrades gracefully when the σ̂² join is empty (placeholder panel) — full history join deferred to 09-09"

patterns-established:
  - "Pattern: PRIMARY optimizer + independent cross-check share one Floating-generic model; agreement is the correctness witness"
  - "Pattern: cross-walk table is the auditable fidelity artifact backing the 'formal witness' claim"

requirements-completed: [CTX-EST]

# Metrics
duration: 9min
completed: 2026-07-20
---

# Phase 9 Plan 07: Estimator Core (CTX-EST) Summary

**GSL Levenberg-Marquardt NLS (primary) + ad Gauss-Newton cross-check + two-noisy-measures EIV-IV fitting π = β₀ + υ₀·exp(−κ·|i_K−i_t|)·σ̂², byte-for-byte mirroring the Lean υ definitions with an auditable cross-walk table.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-20T02:37:28Z
- **Completed:** 2026-07-20T02:46:16Z
- **Tasks:** 2
- **Files modified:** 9 (6 created, 3 modified)

## Accomplishments
- `Model.Upsilon` encodes the estimating equation VERBATIM from spec §4.3 (`b0 + u0 * exp (negate k * d) * s2`), the tick-grid moneyness distance `|i_K − i_t|`, and the λ = 1.0001 tick base — all mirroring the Lean `Upsilon.upsilon` / `PosSpec.lam` forms; generic over `Floating` so `ad` differentiates the same code GSL fits.
- `Model.NLS.fitGSL` is the PRIMARY optimizer (hmatrix-gsl `Numeric.GSL.Fitting.fitModel` Levenberg-Marquardt) with an analytic Jacobian and a returned covariance handle; `fitAD` is the hand-rolled `ad` Gauss-Newton/LM cross-check. On seeded synthetic data both recover the planted (β₀,υ₀,κ) within 1e-2 and agree to 1e-3.
- `Model.EIV.ivFit` implements the LOCKED two-noisy-measures IV remedy: instruments the mismeasured σ̂² with the disjoint-window σ̃² (`E[Z·v]=0`), demonstrably reducing υ̂₀ attenuation vs the naive fit.
- The `estimate` CLI subcommand joins panel.csv and variance.csv on the shared daily epoch and prints the GSL + IV estimates; it degrades gracefully on the placeholder panel (full-history join is 09-09).
- `lean-haskell-crosswalk.md` documents every load-bearing object across Lean / Haskell / spec — the auditable evidence for the "fitted κ̂ witnesses `ATMOTMNullHypothesis`" claim.
- Full suite green: 31 examples, 0 failures (was 18 pre-plan; +8 Upsilon, +5 NLS/EIV).

## Task Commits

Each task was committed atomically:

1. **Task 1: Model/Upsilon.hs — Lean-mirrored model + moneyness + tick grid + cross-walk** - `af84dc1` (feat)
2. **Task 2: NLS (GSL-LM + ad cross-check), EIV (two-noisy-measures IV), estimate CLI** - `2de090a` (feat)

_TDD note: both tasks were built test-first; the model function and its behaviours were pinned before the optimizers consumed them._

## Files Created/Modified
- `econometrics/src/Model/Upsilon.hs` - Lean-mirrored `model`, `modelSplit`, `moneyness`, `signedMoneyness`, `tickBase`
- `econometrics/src/Model/NLS.hs` - `fitGSL`/`fitGSLCov` (GSL LM primary + covariance) and `fitAD` (ad cross-check); `designPoints`
- `econometrics/src/Model/EIV.hs` - `ivFit` two-noisy-measures IV
- `econometrics/test/Model/UpsilonSpec.hs` - verbatim-form, distance, λ=1.0001 behaviours
- `econometrics/test/Model/NLSSpec.hs` - seeded synthetic recovery (GSL, ad, IV attenuation)
- `notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md` - Lean↔Haskell↔spec fidelity table
- `econometrics/app/Main.hs` - `estimate` subcommand + panel/variance CSV loaders + epoch join
- `econometrics/package.yaml` - registered new test modules; added cassava/vector to the exe
- `econometrics/test/Spec.hs` - wired `Model.UpsilonSpec` and `Model.NLSSpec`

## Decisions Made
- **GSL Jacobian supplied analytically** rather than GSL-numeric: the 3-column gradient `[1, e·σ̂², −d·υ₀·e·σ̂²]` is exact and cheap, and `fitModel` returns the covariance matrix that 09-08 turns into clustered sandwich SEs.
- **`modelSplit` folds the sign split into two distances** `(d⁺,d⁻)` with the `exp(−κ⁺d⁺)+exp(−κ⁻d⁻)−1` form, keeping it `Floating`-only (ad-differentiable, no `Ord`) and avoiding double counting at the money — ready for the 09-08 symmetry test.
- **`ivFit` is a two-step nonlinear IV**: κ̂ comes from NLS (κ is identified from cross-sectional moneyness, not the EIV-threatened σ² level), then a just-identified IV corrects the attenuated level — matching spec §4.3's "linearized moment / 2-step GMM" guidance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Panel CSV placeholder `NaN` rejected by the cassava Double reader**
- **Found during:** Task 2 (wiring the `estimate` CLI end-to-end)
- **Issue:** panel.csv's `sigma2_placeholder` column is the literal string `NaN` (09-04's loud placeholder); decoding the 6-tuple with a `Double` last field made `Csv.decode` fail before the row could be used, so the `estimate` stage crashed instead of running.
- **Fix:** decode the discarded placeholder column as `Text` (`(Text,Int,Double,Int,Int,Text)`); the real σ̂²/σ̃² arrive via `joinVariance` from variance.csv, so the placeholder value is never needed.
- **Files modified:** econometrics/app/Main.hs
- **Verification:** `econometrics estimate` now runs to completion on the live panel.csv/variance.csv, reporting `3 panel rows, 2 variance epochs, 0 usable observations` and the graceful "run 09-09 join first" message (epoch mismatch expected until the 09-09 full-history join).
- **Committed in:** 2de090a (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for the `estimate` stage to be runnable end-to-end. No scope creep — behaviour matches the plan's "print/emit estimates; full analysis is 09-09".

## Issues Encountered
- **GSL `fitModel` data shape:** `fitModel` expects `[(x, [output])]` (a list of outputs per point), not a scalar; wrapped the single response as `[y]` inside `fitGSLCov` while keeping `designPoints` scalar for `fitAD`/`ivFit`. Resolved within Task 2 before commit.

## User Setup Required
None - no external service configuration required. GSL 2.8 was installed in 09-01; hmatrix-gsl builds and links.

## Next Phase Readiness
- **09-08 (specification tests + sandwich SEs):** `fitGSLCov` exposes the GSL covariance handle; `modelSplit` (κ⁺/κ⁻) is ready for the symmetry Wald test; the CR0 golden fixture from 09-01 is still green.
- **09-09 (live estimation):** the `estimate` CLI and the panel⋈variance epoch join are wired; 09-09 need only widen the variance window to full history and populate panel.csv's σ̂² column so the join yields usable observations.
- **09-10 (GAMS differential cross-check):** `Model.Upsilon.model` is the verbatim NLS objective to hand to the GAMS session.
- No blockers. The one `sorry` in `lean/vol_markets/Upsilon.lean` (bridging lemma) is out of this plan's scope and untouched.

---
*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Completed: 2026-07-20*

## Self-Check: PASSED

- All 6 created files present on disk.
- Both task commits (af84dc1, 2de090a) exist in the git log.
- Full suite green: 31 examples, 0 failures.
