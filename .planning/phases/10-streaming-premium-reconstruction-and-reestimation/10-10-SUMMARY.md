---
phase: 10-streaming-premium-reconstruction-and-reestimation
plan: 10
subsystem: estimation
tags: [estimation, nls, clustered-se, eiv-iv, stopping-rule, anti-fishing, pivot-lock, lean-witness, haskell, cli]

# Dependency graph
requires:
  - phase: 10-streaming-premium-reconstruction-and-reestimation
    plan: 09
    provides: "panel-epoch.csv — 6,760 gate-validated position-hour rows, 55 tokenIds, 1,887 hourly epochs, sigma2 + EIV instrument joined in"
  - phase: 09-panoptic-upsilon-structural-econometrics
    plan: 09
    provides: "the certified estimator stack (fitGSL multi-start, clusterSandwich CR0, the three tests, ivFit, the four alternatives) — consumed UNCHANGED"
provides:
  - "THE TERMINAL ESTIMATION RESULT OF PHASE 10: STOPPING_RULE UNINFORMATIVE under BOTH LHS constructions — this market cannot identify upsilon"
  - "notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates-v2.md — run 1 (as-is protocol sign), FROZEN with a CORRECTIONS header"
  - "notes/structural-econometrcics/analysis/2026-07-27-upsilon-estimates-v3.md — run 2 (seller-side normalized), the terminal output"
  - "notes/structural-econometrcics/data/estimation-panel-v2.csv / estimation-panel-v3.csv — the two estimation panels (6,760 rows each)"
  - "econometrics CLI: estimate --epoch-panel / --seller-side-normalize / --pivot-lock"
  - "THE kappa FINDING: kappa-hat > 0 REJECTS H0 of a flat vega profile under BOTH constructions (p = 9.5e-3 and 7.3e-3) — the first rejection in this project"
  - "MEASURED Panoptic multiplier wedge: median 1.1125, max 1.2917 — EXCEEDS the 1.125 figure quoted as its bound"
affects: [10-11, 10-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A pre-committed bar is compared against, never rescaled — even when the units are discovered mid-run to be incoherent. The incoherence is RECORDED; acting on it would be the goalpost move the discipline exists to catch."
    - "A verdict function takes exactly one argument (the realised half-width) so it CANNOT consult the result's direction. Result-blindness is enforced by the type, not by discipline."
    - "A construction defect found AFTER the verdict is frozen and escalated, never silently fixed inside the run. The fix becomes a NEW iteration under a NEW lock, with both results permanently on the record."
    - "A binding lock is enforced mechanically: the executor hashes it at run time and ABORTS on mismatch, because the lock's own terms void it if edited after commit."
    - "Two experimental arms are computed by ONE function in ONE process, so a side-by-side table cannot differ by anything except its input."
    - "A frozen artifact is protected in code (guardFrozen refuses to overwrite a CORRECTIONS/FROZEN header), not by convention."
    - "A quoted theoretical bound is checked against the data before being repeated: 1.125 bounds the wedge only when R <= N, and on this market R/N reaches 2.33."

key-files:
  created:
    - "notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates-v2.md"
    - "notes/structural-econometrcics/analysis/2026-07-27-upsilon-estimates-v3.md"
    - "notes/structural-econometrcics/data/estimation-panel-v2.csv"
    - "notes/structural-econometrcics/data/estimation-panel-v3.csv"
  modified:
    - "econometrics/app/Main.hs"

key-decisions:
  - "The estimator was consumed BYTE-UNCHANGED. git diff over src/Model/, src/Tests/ and Alternatives.hs is empty across every commit of this plan; the modules were last touched by bb15a96 (Phase 9). All wiring lives in app/Main.hs, which is what keeps 'only the LHS changed' a one-line audit instead of a claim."
  - "The 6.2e-5 bar was NOT moved, in either run. Mid-run it was discovered to carry Phase 9's USD/day units while the realised half-width carries this panel's ETH/hour units. That incoherence is RECORDED in both analysis outputs and repaired in neither — rescaling a pre-committed bar after seeing the number it judges is banned calibration."
  - "The mixed-sign LHS defect was NOT fixed inside run 1. It was found after the verdict was computed; the executor froze the result and escalated rather than respecifying, and declined to propose the re-run from inside the run."
  - "Run 2's witness bar was TIGHTENED, not loosened: the theorem takes hu AND hk, so both must be statistically supported. Requiring support on kappa alone would have let a significant kappa carry an unresolved upsilon0 into a machine-checked claim."
  - "Run 1's analysis is FROZEN and was never edited. guardFrozen enforces this in code."
  - "The collateral channel is formed on the same epoch grid as sigma2 via a parameterized epochOfTs; the 86400 default keeps Phase 9's construction byte-compatible."

patterns-established:
  - "An estimation plan that reaches its pre-committed bar and fails it reports the failure and stops, and a defect discovered afterwards buys exactly one pre-registered re-run under a hashed lock — not an open-ended search."

requirements-completed: [CTX-EST2]

# Metrics
duration: ~4h across one session, spanning a user-adjudicated HALT
completed: 2026-07-27
---

# Phase 10 Plan 10: Re-estimation and the Stopping Rule Summary

**The Phase-9 estimator ran byte-unchanged on the gate-validated position-epoch panel and the pre-committed stopping rule FAILED — twice, under both LHS sign constructions — so the phase reports that this market cannot identify υ and stops; but κ̂ > 0 REJECTS H₀ of a flat vega profile under both constructions (p = 9.5e-3 and 7.3e-3), the first such rejection in this project, while υ₀'s interval contains zero in both, so the Lean witness does not obtain.**

## Performance

- **Duration:** ~4h, spanning a user-adjudicated HALT and a locked second iteration
- **Tasks:** 3 (two executable, one blocking checkpoint), plus RUN 2 under the pivot lock
- **Files:** 5 (4 created, 1 modified)
- **Suite:** **215 examples, 0 failures** throughout (unchanged baseline)

## Task Commits

1. **Point the unchanged estimator at the position-epoch panel** — `eec8890` (feat)
2. **The self-describing v2 analysis output** — `ebc92fb` (docs)
3. **CHECKPOINT — user adjudication** → HALT artifacts `cda0a15` (coordinator)
4. **RUN 2 — seller-side normalized LHS, terminal run** — `2bed390` (feat)

## THE NUMBERS

```
                         RUN 1 (as-is sign)      RUN 2 (seller-side)
N_OBS                    6760                    6760
N_CLUSTERS               55                      55
BETA0_HAT                -1.635539e-8            -5.468404e-8
BETA0_SE                  4.253788e-8             4.893660e-8
UPSILON0_HAT              3.597340e-2             1.063317e-1
UPSILON0_SE_CLUSTERED     7.548636e-2             1.009984e-1
UPSILON0_CI_HALFWIDTH     1.479533e-1             1.979569e-1
KAPPA_HAT                 3.090495e-2             3.041754e-2
KAPPA_SE_CLUSTERED        1.318375e-2             1.245733e-2
TEST_UPSILON_POS_P        3.168395e-1             1.462150e-1
TEST_KAPPA_POS_P          9.534719e-3             7.308348e-3
TEST_SYMMETRY_P           2.412538e-7             6.840842e-8
PRECOMMITTED_HALFWIDTH_BAR  6.200000e-5           6.200000e-5
STOPPING_RULE            UNINFORMATIVE           UNINFORMATIVE
```

Pre-registered descriptors (declared in the lock BEFORE run 2):

```
D1 half-width/|u0|     4.112851  ->  1.861692
D2 CI excludes zero    no        ->  no
D3 |u0| ratio 2.955843 (moved AWAY from zero)   SE ratio 1.337969 (WIDENED)
KAPPA_POSITIVE_PERSISTS: True
PIVOT_LOCK_SHA256: 56044349a035221874eb93d59ab64bd94239be698e4e47363118bffd743e9998  VERIFIED
```

## Stopping Rule Verdict

**Run 1 (`2026-07-20-upsilon-estimates-v2.md`, FROZEN):**

```
PRECOMMITTED_HALFWIDTH_BAR: 6.200000e-5
UPSILON0_CI_HALFWIDTH: 1.479533e-1
STOPPING_RULE: UNINFORMATIVE
```

**USER ADJUDICATION at the Task-3 checkpoint (2026-07-27), verbatim:** **`escalate-anomaly`** — *"Treat the sign-convention divergence as a construction defect (not a respecification): one pre-registered diagnostic re-run with the seller-side-normalized LHS, under anti-fishing discipline — the single named fix, both results reported side by side, no further iterations regardless of outcome. The κ finding and the UNINFORMATIVE verdict on THIS run stay on the record either way."*

**Run 2 (`2026-07-27-upsilon-estimates-v3.md`, TERMINAL):**

```
PRECOMMITTED_HALFWIDTH_BAR: 6.200000e-5
UPSILON0_HAT: 1.063317e-1
UPSILON0_SE_CLUSTERED: 1.009984e-1
UPSILON0_CI_HALFWIDTH: 1.979569e-1
STOPPING_RULE: UNINFORMATIVE
```

Phase-9 comparison: half-width ±2.48e-4 on 61 observations / 55 clusters.

**THE CONCLUSION: this market cannot identify υ.** The bar was not met under either construction. No respecification, no subsample hunting, no alternative-estimator fishing was performed, and none is scheduled. Per the pivot lock and the user's commitment, run 2 is the TERMINAL estimation run of Phase 10.

## Checkpoint history

1. **Run 1 executed** on the as-is panel. Mechanical verdict: UNINFORMATIVE. Returned at the blocking checkpoint with the full parameter table, and with three facts recorded but **not acted on**: the LHS sign divergence from Phase 9's convention, the bar's unit incoherence, and the wedge exceeding its quoted bound. The executor explicitly declined to propose a re-run from inside the run.
2. **User adjudicated `escalate-anomaly`**, processed through the anti-fishing-replication discipline. The coordinator committed a disposition memo (trigger, what was NOT done, bug-fix exemption reasoning) and a pivot lock pinning the single change and everything held fixed.
3. **Run 2 executed** under that lock, hash-verified. Verdict: UNINFORMATIVE again.

## Accomplishments

- **Ran the certified estimator with a provably untouched source.** `git diff` over `src/Model/`, `src/Tests/` and `Alternatives.hs` is empty across every commit of this plan; run-time `git log` evidence embedded in both outputs shows the modules were last touched in Phase 9. Only the LHS differed.
- **Made the verdict structurally result-blind.** `stoppingRuleVerdict :: Double -> String` takes the half-width and nothing else — it cannot consult κ̂'s sign or a p-value even by accident.
- **Isolated the single change to exactly what the lock authorised**, and proved it: independent Python comparison of the two exports shows **0 rows differing in any regressor**, **1,735 π values flipped** (= 2,280 long rows − 545 long zeros), 5,025 identical, 0 otherwise.
- **Enforced the lock mechanically.** The run hashes the lock file and aborts on mismatch, because the lock's own closing clause voids it if edited post-commit.
- **Protected the record in code.** `guardFrozen` refuses to overwrite an analysis carrying a `CORRECTIONS`/`FROZEN` header; run 1's document is byte-identical to its committed state.
- **Recomputed every headline figure independently in Python** — clustered CR0 SEs, half-widths, SSEs, wedge distribution — all reproduce exactly.
- **Restored a diagnostic Phase 9 could not run.** Position-FE is now IDENTIFIED (6,757 obs / 52 clusters, κ_FE = 3.162e-2 vs primary 3.042e-2): no material move, so strike-composition selection does not appear to be doing the identifying work.

## What this does NOT establish

- **The κ > 0 rejection is not a substitute for the stopping rule.** It concerns the SHAPE of the profile; the rule concerns υ₀'s level. Both runs reject H₀: κ = 0 and both return UNINFORMATIVE, and those are consistent statements about different parameters.
- **Branch A obtained via ONE disjunct only.** υ̂₀ moved away from zero (×2.956) — consistent with the pre-named attenuation mechanism — but the SE **widened** (×1.338), which is expected when LHS magnitudes grow and is **not** evidence for the mechanism. One comparison on one panel is not an identified effect.
- **The formal witness does NOT obtain.** `hk` is statistically supported; `hu` is satisfied in sign only (p = 0.146, CI contains zero). The Lean theorem `exp_family_witnesses_ATMOTM` remains proved and axiom-clean and the conjecture remains OPEN — nothing here bears on the theorem's correctness, only on whether this market's data instantiates it.
- **A passing gate validated MEASUREMENT, not identification.** It certifies the LHS is what the protocol paid.
- **The row count was never the precision.** 6,760 rows in 55 clusters with 84.1% in ten positions. The sign fix corrects a bias; it cannot manufacture independent clusters, and this is the binding constraint no LHS transformation can touch.

## Deviations from Plan

### Auto-fixed / adapted

**1. [Rule 2 — Missing critical functionality] The witness criterion was tightened**
- **Found during:** Task 2, drafting the witness section.
- **Issue:** Phase 9's renderer claimed the witness on `kappaSignificant && upsilonPositive` — statistical support on κ, sign only on υ₀. With run 1's κ significant and υ₀ insignificant, that logic would have claimed the witness while the phase simultaneously reported υ₀ unidentified.
- **Fix:** Require statistical support on BOTH (the theorem takes `hu` AND `hk`). The bullets now report sign *and* test verdict together, so no internal contradiction is possible.
- **Direction:** strictly harder to assert. This is the 09-09 over-read lesson applied.
- **Commit:** `ebc92fb`.

**2. [Rule 1 — Bug] The quoted 1.125 wedge bound is false on this market**
- **Issue:** The plan and `Panoptic.Premium`'s docstring describe 1.125 as the long-side bound. Measured max is **1.291667** (long) and 1.204167 (short). `1 + ν·R/N ≤ 1 + ν` requires `R ≤ N`; here `R/N` reaches 2.33.
- **Fix:** Report both branches' maxima separately with the implied `R/N`, and state that neither branch is bounded by 1.125 in general. `Panoptic/Premium.hs` was NOT edited (out of this plan's scope); the correction lives in the analysis outputs.
- **Commits:** `ebc92fb`, `2bed390`.

**3. [Rule 3 — Blocking] The frozen run-1 output was overwritable**
- **Issue:** Re-running the non-normalized path would have clobbered the CORRECTIONS header the coordinator added.
- **Fix:** `guardFrozen` aborts on a `CORRECTIONS`/`FROZEN` header; run 2 writes to distinct v3 paths.
- **Commit:** `2bed390`.

### Recorded, deliberately NOT acted on

- **The bar's unit incoherence** (Phase 9 USD/day vs this panel's ETH/hour). Recorded in both outputs; not rescaled in either. The pivot lock froze this explicitly.
- **The LHS sign divergence, during run 1.** Found after the verdict; frozen and escalated rather than fixed in place.

### Not done (correctly)

- No Lean file touched, no Aristotle task run — `git status --porcelain lean/` empty throughout.
- No estimator source edit.
- No filters, trims, outlier drops, re-fetches, SE-method swaps, test-geometry changes, transforms or control additions.
- The Phase-9 `estimation-panel.csv` and `2026-07-20-upsilon-estimates.md` retained unchanged.

## Authentication Gates

None. The estimation path makes zero network calls; every input was a committed local artifact.

## Issues Encountered

- The data-scaled multi-start anchors `υ₀` at `median(π)/median(σ̂²)`, and the hourly panel's median π is exactly 0 (1,657 rows accrue nothing; long rows are negative). The anchor is therefore 0 in run 1. The fit is not stuck — the `υ₀` gradient is non-zero at a zero start and the multi-start beat the dead fixed start in both arms — but the margin was small (0.012%) and is recorded rather than smoothed over.

## Next Phase Readiness

- **10-11 (cross-walk + lineage close-out):** carry the **measured** wedge figures (median 1.1125, long max 1.2917, short max 1.2042, implied max R/N 2.33), not the 1.125 bound, into the cross-walk table. Both analysis outputs are self-describing with full lineage.
- **10-12:** the phase's substantive result is terminal. What remains is documentation, not estimation.
- **Carry-forward for any future work on this question:** the binding constraint is the **55-cluster ceiling**, not the LHS. More hours on existing positions cannot help; more independent positions would be required.

---
*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Completed: 2026-07-27*

## Self-Check: PASSED

- All 5 claimed files exist on disk (4 created, 1 modified).
- All 4 claimed commits exist in history (`eec8890`, `ebc92fb`, `cda0a15`, `2bed390`).
- Both estimation panels carry **6,760** data rows, re-counted from the files.
- **Every headline figure was recomputed independently in Python** — a different
  language from the one that produced them — from the committed artifacts:
  clustered CR0 SEs for both arms (run 1 `7.548636e-2`, run 2 `1.009984e-1`),
  both half-widths, both SSEs, D1/D2, and the full wedge distribution in exact
  rational arithmetic. All reproduce exactly.
- **The single change was verified, not asserted:** comparing the two exports
  row by row gives **0 rows differing in any regressor**, **1,735 π values
  flipped**, 5,025 identical, 0 otherwise — exactly the long-row sign flip the
  pivot lock authorised, and 1,735 = 2,280 long rows − 545 long zero rows.
- `git diff ddf649e..HEAD -- econometrics/src/Model/ econometrics/src/Tests/
  econometrics/src/Alternatives.hs` is **EMPTY**; `git diff -- econometrics/src/`
  is empty.
- `git status --porcelain lean/` is **empty**; no Lean file was touched and no
  Aristotle task was run.
- Run 1's analysis is byte-identical to its committed state at `cda0a15`.
- The pivot lock hashes to `56044349a035221874eb93d59ab64bd94239be698e4e47363118bffd743e9998`,
  matching the pin the run verified before executing.
- `grep '6.2e-5' econometrics/app/Main.hs` still matches — the bar was not edited.
- No home-absolute path and no credential in either analysis output.
- Suite **215 examples, 0 failures**.
