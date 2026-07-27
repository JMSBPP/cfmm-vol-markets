# Disposition Memo: phase10-plan10-10-run1 HALT 2026-07-27

## Pre-registration locked
- spec: `.planning/phases/10-streaming-premium-reconstruction-and-reestimation/10-10-PLAN.md` (committed `d374b44`, 2026-07-20, amended for checker warnings `5300da7` — both BEFORE any estimation)
- estimating equation: π_it = β₀ + υ₀·exp(−κ|i_K − i_t|)·σ̂²_t + v_it (approved spec §4.3, verbatim)
- stopping rule: STOPPING_RULE = (UPSILON0_CI_HALFWIDTH ≤ 6.2e-5), tokenId-clustered CR0 SE, mechanical and result-blind (never consults κ̂'s sign or any p-value)
- estimator: Phase-9 stack UNCHANGED (enforced: `git diff -- econometrics/src/Model/ econometrics/src/Tests/ econometrics/src/Alternatives.hs` empty — held)
- N floor / power: Wave-0 two-part necessary floor (≥300 joinable rows AND median ≥5 epochs/position), GO measured 2026-07-21 (hourly re-scope, thresholds unmoved)
- sign expectation (conjecture direction): υ₀ > 0, κ > 0
- locked date: 2026-07-20

## Realized (run 1, commits `eec8890`, `ebc92fb`; analysis `notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates-v2.md`)
- N: 6,760 obs / 55 clusters
- υ̂₀ = 3.597340e-2, clustered SE 7.548636e-2, CI half-width **1.479533e-1** vs bar 6.2e-5
- κ̂ = 3.090495e-2, clustered SE 1.318375e-2, p(κ>0) = 9.534719e-3 — H₀ flat-profile REJECTS (first time in project); position-FE concurs (κ_FE 3.162e-2)
- gate: **STOPPING_RULE: UNINFORMATIVE** (verdict stands on this run's record, unedited)
- Lean witness: does NOT obtain (υ₀ significant in sign only)

## Trigger fired
post-lock-temptation adjacent: a construction defect in the LHS was discovered AFTER the verdict was computed. `assembleEpochPanel` (10-09) keeps protocol sign conventions; `Panel.Build.premiumUsd` (Phase 9, pre-dating all Phase-10 results) deliberately normalizes long spells to the seller side, with the documented rationale "the same vega would enter the regression with two opposite signs and cancel." 2,280/6,760 rows (33.7%; 8/55 tokenIds) enter opposite-signed. Bias direction unambiguous: attenuates υ₀ toward zero and widens exactly the adjudicated interval.

## What was NOT done
Every post-hoc change considered and rejected, named in writing:
- The stopping bar 6.2e-5 was NOT rescaled, reinterpreted, or unit-converted (its USD/day-vs-ETH/hour incoherence is recorded in the analysis; revising it post-realization is banned calibration).
- No SE method swap (CR0 by tokenId retained; no CR1, no account-level clustering as primary).
- No test-geometry change (all tests as locked; no one-sided conversions beyond the locked forms).
- No sample filter, outlier drop, or subsample hunt (the 84%-concentration top-10 positions retained; no trimming).
- No transform change (no logs, no winsorizing), no control additions, no lag structure.
- No estimator source edit (Model/, Tests/, Alternatives.hs diffs empty — verified).
- The mixed-sign LHS was NOT silently fixed inside the run; the executor froze the verdict and escalated.

## Adjudication under the discipline's bug-fix exemption
The seller-side normalization qualifies as a **correctness fix**: (1) the defect is a post-lock implementation deviation from the locked convention (Phase 9's documented normalization, which the locked estimator was built against); (2) the fix applies identically across every locked spec (one LHS transformation); (3) it is verdict-independent — an INFORMATIVE verdict on mixed-sign data would have been equally invalid and equally in need of the same fix. It is executed as a NEW iteration under a new pivot lock, never as an edit to run 1.

## User-enumerated pivot
USER ADJUDICATION (verbatim option selected at the 10-10 checkpoint, 2026-07-27): **"escalate-anomaly"** — "Treat the sign-convention divergence as a construction defect (not a respecification): one pre-registered diagnostic re-run with the seller-side-normalized LHS, under anti-fishing discipline — the single named fix, both results reported side by side, no further iterations regardless of outcome. The κ finding and the UNINFORMATIVE verdict on THIS run stay on the record either way."

Provenance nuance, recorded for honesty: the escalation option appeared among the checkpoint's three structural adjudication outcomes; the FIX CONTENT was determined by the lock (Phase 9's documented convention — exactly one correct normalization exists), not selected from an analyst-proposed menu of specifications. The executor explicitly declined to propose the re-run from inside the run. Pivot terms: `10-10-PIVOT-LOCK.md`.
