---
phase: 09-upsilon-econometric-estimation-lean-aware
plan: 03
subsystem: lean4-formalization
tags: [lean4, mathlib, upsilon, vega, bridging-lemma, aristotle, econometrics]

# Dependency graph
requires:
  - phase: 08-panoptic-vol-claim-lean4-formalization
    provides: "lean/vol_markets/Upsilon.lean (upsilon, upsilonTickSlope, ATMOTMNullHypothesis Prop, two proved υ lemmas)"
provides:
  - "Corrected ATMOTMNullHypothesis conjunct 3 (slope-centered envelope) — now a PROVABLE Prop"
  - "Sorry'd bridging-lemma statement exp_family_witnesses_ATMOTM over the exp-moneyness family with c = κ·Δi"
affects: [09-06-aristotle-bridge-proof, 09-08-haskell-estimation, 09-crosswalk]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Slope-centered discrete envelope: forward-difference asymmetry corrected by centering the OTM-decay bound on the peak-pair {iK−1, iK} via g(i)=max(i−iK, −(i−iK)−1)"
    - "Statement-first Aristotle discipline: pin a PROVABLE goal locally (sorry'd) before any serial Aristotle submission"

key-files:
  created:
    - ".planning/phases/09-upsilon-econometric-estimation-lean-aware/09-03-SUMMARY.md"
  modified:
    - "lean/vol_markets/Upsilon.lean"

key-decisions:
  - "Corrected ATMOTMNullHypothesis conjunct 3 to the slope-centered (Option B, tight) envelope exp(-c·max(i-iK, -(i-iK)-1)); the committed exp(-c|i-iK|) form was parameter-independently false on the whole left branch because the forward-difference slope is symmetric about iK-½"
  - "Recorded the Option A fallback envelope exp(-c·max(0,|i-iK|-1)) as a comment for use only if Aristotle balks at Option B in plan 09-06"
  - "Left exactly one new sorry (the bridging lemma); did NOT hand-prove it (Aristotle-heavy rule; plan 09-06 owns the single serial submission)"

patterns-established:
  - "Pattern: correct discrete envelopes for forward-difference asymmetry by centering on the peak-pair, not the strike tick"
  - "Pattern: bridging lemma stated with binders υ₀ κ Δi (π reserved under open Real; payoff binders use pl elsewhere)"

requirements-completed: [CTX-BRIDGE]

# Metrics
duration: 2min
completed: 2026-07-19
---

# Phase 9 Plan 03: Lean-Aware Bridging-Lemma Statement Correction Summary

**Corrected `ATMOTMNullHypothesis` conjunct 3 to a slope-centered envelope (fixing a parameter-independent falsity) and pinned the sorry'd witness theorem `exp_family_witnesses_ATMOTM` over the exp-moneyness family with `c = κ·Δi` — the exact goal the single Aristotle task (09-06) will discharge.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-19T18:15:28Z
- **Completed:** 2026-07-19T18:17:37Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Replaced conjunct 3's exponent `exp(-c·|i−iK|)` with the slope-centered distance `max(i−iK, −(i−iK)−1)`, making `ATMOTMNullHypothesis` witnessable by the symmetric exponential forward-difference family (the prior form was false on the entire left branch for every `c > 0`).
- Expanded the docstring to explain the forward-difference right-shift obstruction and the peak-pair `{iK−1, iK}` centering; recorded the Option A fallback envelope as a comment.
- Stated the sorry'd witness theorem `exp_family_witnesses_ATMOTM (υ₀ κ Δi : ℝ) (iK : ℤ) …` instantiating the corrected `ATMOTMNullHypothesis` at `c = κ·Δi`.
- `lake build vol_markets` stays green with exactly one new sorry (the bridging lemma); the two proved υ lemmas and all other modules are untouched.

## Task Commits

Each task was committed atomically:

1. **Task 1: Correct conjunct 3 to the slope-centered envelope** - `267b5b6` (fix)
2. **Task 2: State the sorry'd bridging lemma over the exponential-moneyness family** - `460110e` (feat)

**Plan metadata:** (docs commit — this SUMMARY + STATE + ROADMAP)

## Files Created/Modified
- `lean/vol_markets/Upsilon.lean` - corrected `ATMOTMNullHypothesis` conjunct 3 (slope-centered envelope + expanded docstring + Option A fallback comment) and added the sorry'd `exp_family_witnesses_ATMOTM` witness theorem.

## Decisions Made
- **Option B (tight, slope-centered) over Option A (loose):** used `exp(-c·max(i-iK, -(i-iK)-1))` as the committed conjunct-3 envelope — it is the exact envelope (`|slope| = peak·β^{g(i)}`), matching RESEARCH's verified fix. Option A recorded as a comment fallback only.
- **No hand-proof of the bridging lemma:** per the Aristotle-heavy rule, the single serial submission is owned by plan 09-06; this plan leaves the goal `sorry`'d.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. The `π` reserved-notation caveat (under `open Real`) did not bite: the bridging lemma uses binders `υ₀ κ Δi`, none of which collide with `Real.pi`.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `ATMOTMNullHypothesis` is now a PROVABLE `Prop`; `exp_family_witnesses_ATMOTM` is the pinned, locally-typechecked goal for the single serial Aristotle task (plan 09-06).
- The Option A fallback envelope is recorded in-file should Aristotle balk at Option B.
- Blocker/reminder: exactly one in-flight Aristotle task at a time (aristotle-no-queue) when 09-06 submits.

---
*Phase: 09-upsilon-econometric-estimation-lean-aware*
*Completed: 2026-07-19*

## Self-Check: PASSED

- Upsilon.lean: FOUND
- 09-03-SUMMARY.md: FOUND
- Commit 267b5b6 (Task 1): FOUND
- Commit 460110e (Task 2): FOUND
