---
phase: 12-spec-correction-type-completion
plan: 01
subsystem: spec
tags: [risk-price, haircut, issuance, vega-exposure, fixed-point, lean, plank-types]

# Dependency graph
requires:
  - phase: v3.0-roadmap
    provides: RISK-01/RISK-02 requirement statements + review-hardened Phase 12 SCs
provides:
  - "risk.md: machine-checked H1 issuance spec (p_risk = oracle/(1−h), integer realization, quote convention, share units, ℝ-only caveat + counterexample)"
  - "Deletion of the refuted RiskDiscount/RiskMeasureLib .plk embodiment (concept exists nowhere under src/)"
  - "VegaExposure.plk: two-live-field record (exposure, priceVolX96) + RiskPriceX96/Haircut newtypes"
  - "exposure.md: deferred-fields note + v1 priceVolX96-carries-p_risk tension"
affects: [13-issuance-library, 14-module-dispatch, 15-differential-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Plank newtype = struct { val: u256 } with bit-width bound in comment (mirrors Numerics.plk / Timepoint.plk)"
    - "Plain (non-packed) record when live fields exceed 256 bits; bounds documented, not enforced"

key-files:
  created:
    - .planning/phases/12-spec-correction-type-completion/12-01-SUMMARY.md
  modified:
    - spec/protocol/entities/types/risk.md
    - spec/protocol/entities/types/exposure.md
    - src/types/exposure/VegaExposure.plk
  deleted:
    - src/types/risk/RiskDiscount.plk
    - src/lib/risk/RiskMeasureLib.plk

key-decisions:
  - "Deleted (not quarantined) the refuted RiskDiscount/RiskMeasureLib .plk stubs — zero live importers, empty bodies, git history is recovery path (project precedent: src/exp, src/ldf, ReferenceMarket)"
  - "RiskPriceX96/Haircut newtypes co-located in VegaExposure.plk (CONTEXT-granted discretion) to hold the phase to its named files"
  - "Named the obsolete draft haircut convention in words, not by its literal token, to avoid reintroducing a grep needle"

patterns-established:
  - "Spec math prose uses Unicode minus (−); .plk code uses ASCII hyphen-minus only"
  - "v1 field-meaning tensions are stated explicitly (priceVolX96 carries p_risk, not p_vol(σ̄)), never silently renamed"

requirements-completed: [RISK-01, RISK-02]

# Metrics
duration: 3min
completed: 2026-07-17
---

# Phase 12 Plan 01: Spec Correction & Type Completion Summary

**Corrected the Lean-refuted issuance spec to `p_risk = oracle/(1−h)` with integer-realization and ℝ-only counterexample, deleted the refuted risk-discount .plk embodiment, and completed VegaExposure as a two-live-field record with RiskPriceX96/Haircut newtypes.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-17T13:03:59Z
- **Completed:** 2026-07-17T13:08:05Z
- **Tasks:** 4 (Task 4 is verification-only, no commit)
- **Files modified:** 3 edited, 2 deleted

## Accomplishments
- Rewrote `risk.md` to the machine-checked H1 issuance spec: `p_risk = oracle/(1−h)`, lemma citations (`haircutRiskPrice_ge_oracle` with `0 ≤ oracle`, `0 ≤ h < 1`; `issuance_haircut_equiv`), the four integer operations (p_risk ceil, shares floor, direct path), correct checked-subtraction / zero-denominator revert attribution, quote convention (raw smallest units), share units, and the ℝ-only caveat with the verified 12-vs-13 counterexample plus the gap-of-6 input.
- Deleted the refuted concept's live `.plk` embodiment (`RiskDiscount.plk`, `RiskMeasureLib.plk`) — the concept now exists nowhere under `src/`.
- Completed `VegaExposure.plk` as the two-live-field record (`exposure`, `priceVolX96`) plus `RiskPriceX96`/`Haircut` newtypes, fixing the stub's `collateralUnits`/`priceVol` mis-naming; ASCII-only, no init/run block.
- Updated `exposure.md` with the plank record, the deferred-fields note (`collateralToken`/`underlyingToken`/`riskOracleId` return with oracle wiring), and the v1 `priceVolX96`-carries-`p_risk` tension; retained the `N_v = ΔM/p_vol(σ̄)` derivation as the v2+ target.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite risk.md to the machine-checked H1 issuance spec** - `f77b50e` (docs)
2. **Task 2: Delete the refuted RiskDiscount/RiskMeasureLib .plk embodiment** - `7a01862` (refactor)
3. **Task 3: Complete VegaExposure.plk record + risk newtypes, sync exposure.md** - `7ae87d6` (feat)
4. **Task 4: Final scoped-grep gate + labelled compile PRECONDITION** - verification-only, no commit

**Plan metadata:** committed separately (docs: complete plan).

## Files Created/Modified
- `spec/protocol/entities/types/risk.md` - H1 issuance spec: `oracle/(1−h)`, integer realization, quote convention, share units, ℝ-only caveat + counterexample, inexact-division anchor
- `src/types/exposure/VegaExposure.plk` - Two-live-field VegaExposure record + RiskPriceX96/Haircut newtypes
- `spec/protocol/entities/types/exposure.md` - Deferred-fields note + v1 priceVolX96-carries-p_risk tension
- `src/types/risk/RiskDiscount.plk` - DELETED (refuted-concept embodiment, empty body, zero importers)
- `src/lib/risk/RiskMeasureLib.plk` - DELETED (imports the above; refuted-concept stub)

## Deletion record (Task 2, RISK-01)

`RiskDiscount.plk` (struct + empty-bodied `factor_from_haircut_and_price` / `discounted_vega_amt_from_collateral`) and `RiskMeasureLib.plk` (imports `RiskDiscount`; malformed `risk_measure` stub) were the live `.plk` embodiment of the Lean-refuted risk-discount concept. Both have EMPTY bodies (so the `price/haircut` grep gate never caught them) and NOTHING imports them across `src/`+`test/` (re-verified at execution time: the importer grep excluding the two files themselves exited 1 with no output). RISK-01 requires the refuted concept to appear nowhere under `spec/` or `src/`, so they were DELETED via `git rm` — following project precedent (`src/exp/`, `src/ldf/`, `ReferenceMarket` were deleted, not quarantined; git history is the recovery path). Phase 13 must NOT rediscover and rebuild this concept.

## Verification gate results (Task 4)

**Gate A — scoped grep (HARD ACCEPTANCE, roadmap SC-1):**
`git grep -nF 'price/haircut' -- spec/ src/` printed nothing and exited 1. (Never run unscoped: `.planning/` deliberately retains the string as review history.)

**Gate B — labelled compile PRECONDITION (NOT acceptance):**
- **B1 (whole-tree regression):** `make compile-plank` = `10 ok, 0 failed, 1 skipped` — unchanged from the plan-time baseline (the 1 skip is `VegaAccountMod`, the Phase-14 target).
- **B2 (VegaExposure declarations parse/typecheck):** the direct `plank build` of `VegaExposure.plk` emitted EXACTLY ONE `error:` line, `error: missing init block` — EXPECTED for a pure library file (no init block), proving the record + newtype declarations parse and typecheck up to the entrypoint requirement. No parse/type error precedes it.

**Gate B is a PRECONDITION, not acceptance.** Phase 12 shipped NO CALLED test and has no mutation gate (roadmap Phase 12 note). "It compiles" is NOT a success claim — the VegaExposure type is proven only when Phase 13 imports and exercises it.

## Decisions Made
- Deleted rather than quarantined the refuted `.plk` files (zero importers, empty bodies, git-history recovery) — consistent with project precedent.
- Co-located `RiskPriceX96`/`Haircut` newtypes in `VegaExposure.plk` (CONTEXT-granted discretion) rather than a sibling file, holding the phase to its named files.
- Referred to the obsolete draft haircut convention in words, never by its literal token, to avoid reintroducing the grep needle the gate exists to prevent.
- Verified the RiskDesign.lean lemma line numbers before writing (haircutRiskPrice ~113, haircutRiskPrice_ge_oracle ~119 with hypotheses `0 ≤ oracle`/`0 ≤ h`/`h < 1`, issuance_haircut_equiv ~123) — all matched the plan's verbatim citations.

## Deviations from Plan

None - plan executed exactly as written. The plan's verbatim target content (review-hardened through a three-verifier pass) was transcribed exactly; no numbers, formulas, or lemma citations were altered.

## Issues Encountered
None. Baseline `make compile-plank` was green before and after; all acceptance criteria passed on first run.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 13 (Issuance Library) is unblocked: `risk.md` now gives a typed, verbatim-implementable integer spec with a rounding-sensitive both-hops-inexact anchor (deposit=10, oracleX96=10·2^92, hX96=3·2^92 → composed 12 vs direct 13), and `VegaExposure.plk` exposes `RiskPriceX96`/`Haircut` newtypes for typed lib signatures.
- No blockers. Phase 12 produced no CALLED test by design; the type-declaration correctness is proven only when Phase 13 imports and exercises `VegaExposure`.

## Self-Check: PASSED

- All modified files present; both refuted `.plk` files confirmed deleted.
- All three task commits present in git history (`f77b50e`, `7a01862`, `7ae87d6`).

---
*Phase: 12-spec-correction-type-completion*
*Completed: 2026-07-17*
