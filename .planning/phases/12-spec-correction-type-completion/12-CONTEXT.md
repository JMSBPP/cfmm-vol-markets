# Phase 12: Spec Correction & Type Completion - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning
**Source:** Inline decisions at plan time (quote convention locked by user) + the two-step review resolution baked into ROADMAP.md Phase 12 SCs (commit `4f2cb05`)

<domain>
## Phase Boundary

DOC + TYPE-DECLARATION ONLY. Two deliverable groups, nothing else:

1. `spec/protocol/entities/types/risk.md` rewritten: the Lean-refuted `price/haircut` formula removed, the H1 integer realization pinned to the operation level, the quote convention and share units stated, the ℝ-only status of `issuance_haircut_equiv` recorded.
2. `src/types/exposure/VegaExposure.plk` completed as the live-fields-only record + risk Q-type newtypes; `spec/protocol/entities/types/exposure.md` updated with the deferred-fields note and the v1 meaning of `priceVolX96`.

NO arithmetic functions, NO lib code, NO module code, NO tests — those are Phases 13–15. This phase BLOCKS them: nothing arithmetic may be written against the stale spec.

**No mutation gate in this phase** (roadmap states this explicitly): it produces no CALLED test. Type completion is compile-only and "it compiles" is NOT a success claim — the type is proven only by being imported and exercised in Phase 13.
</domain>

<decisions>
## Implementation Decisions

### Quote convention (USER-LOCKED this session)
- `p_risk` is Q64.96, LINEAR (NOT a `sqrtPriceX96`), quoted as **collateral units per 1 vega-exposure unit**.
- `oracleX96` uses the SAME convention (it is the pre-haircut risk price).
- Direction of conservatism: higher `p_risk` → fewer shares per deposit; the haircut RAISES `p_risk` (`oracle/(1−h) ≥ oracle`, per `haircutRiskPrice_ge_oracle`) so it can only reduce issuance.
- Share units: shares inherit the **collateral token's native decimals** — in `shares = mulDiv(deposit, 2^96, pRiskX96)` the Q96 scale cancels. risk.md must state this explicitly (review finding M-6/minor-6).

### Integer realization to pin in risk.md (from ROADMAP Phase 12 SC-2 — copy verbatim)
- price Q64.96 (`X96`); haircut Q0.96 (`hX96 < 2^96`) — REPLACING the draft's `Q0.64` (a second refuted convention).
- `p_risk = mulDivRoundingUp(oracleX96, 2^96, 2^96 − hX96)` with a CHECKED (non-wrapping) subtraction.
- `shares = mulDiv(deposit, 2^96, pRiskX96)` FLOOR.
- Direct path: `mulDiv(deposit, 2^96 − hX96, oracleX96)` FLOOR.
- RECORD: `issuance_haircut_equiv` (RiskDesign.lean:123) is proven over ℝ ONLY. Exact integer cross-path equality is FALSE — verified counterexample `deposit=10, oracleX96=10·2^92, hX96=3·2^92` → composed path 12 vs direct path 13; the gap scales with `deposit/2^96` (a gap of 6 was exhibited). Only the one-sided `composed ≤ direct` transfers (0 violations in 200k-sample sweep).
- Cite `issuance_haircut_equiv` and `haircutRiskPrice_ge_oracle` by name and file.

### VegaExposure type (USER-LOCKED at milestone creation)
- Live-fields-only: `exposure` (u128-bounded, the issued vega shares N_v) and `priceVolX96` (u160-bounded, carrying the exogenous `p_risk` in v1 — NOT `p_vol(σ̄)`; the tension is STATED in exposure.md, not silently renamed).
- The stub's `collateralUnits`/`priceVol` mis-naming is fixed to the spec names.
- `collateralToken`/`underlyingToken`/`riskOracleId` DO NOT appear in the .plk; exposure.md records they return with the oracle-wiring milestone.
- Additionally declare `RiskPriceX96` (Q64.96) and `Haircut` (Q0.96) newtypes so Phase 13 lib signatures are typed rather than bare `u256` (ROADMAP SC-3).

### The grep gate (review finding M2 — scope is load-bearing)
- Success gate is `git grep -nF 'price/haircut' -- spec/ src/` → empty. NOT an unscoped grep: `.planning/` deliberately retains the string as review history, so an unscoped grep contains its own needle and is unsatisfiable.
- The refuted line at risk.md:12 reads verbatim `collateralAmount* (self.price/haircut)`.

### Claude's Discretion
- Prose structure/ordering of risk.md; whether RiskDiscount/RiskMeasure sketches are rewritten or dropped (they may be replaced entirely by the H1 pipeline description — keep whatever serves Phase 13's implementer, delete what misleads).
- Whether the Q-type newtypes live in VegaExposure.plk or a sibling file under `src/types/exposure/` (follow existing `src/types/` conventions — read them first).
- Plank struct field types: Plank structs use `u256` fields; the u128/u160 BOUNDS are documented semantics (comments + spec), matching how existing types declare bounded fields. Verify against `src/types/market_state_measurements/Timepoint.plk` and `src/types/pos_spec/` conventions before choosing.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design authority (machine-checked; the content being transcribed)
- `../cfmm-wt/lean4-spec/lean/vol_markets/RiskDesign.lean` — `haircutRiskPrice` (line ~113), `haircutRiskPrice_ge_oracle` (~119), `issuance_haircut_equiv` (~123), `mulX96Down`/`mulX96Down_le`/`mulX96Down_one` (~135-150). ℝ/ℕ statements — the ℝ-only caveat comes from here.
- `../cfmm-wt/lean4-spec/protocol/model/vol_markets/RISK_ALTERNATIVES.md` — H1 recommendation (§3), typed pipeline + rounding directions (§4), the draft-formula correction narrative.

### Files being modified
- `spec/protocol/entities/types/risk.md` — 30 lines, carries the refuted formula at line 12 and `Q0.64` at line 10.
- `spec/protocol/entities/types/exposure.md` — 65 lines, the N_v = ΔM/p_vol derivation + 5-field struct sketch.
- `src/types/exposure/VegaExposure.plk` — 6-line stub with mis-named fields.

### Conventions to mirror
- `src/types/market_state_measurements/Timepoint.plk` — how existing types document bit-widths/bounds and structure pack/unpack (VegaExposure needs NO packing — 288 bits > 256, it is a plain record; but mirror the documentation style).
- `.planning/ROADMAP.md` Phase 12 section (lines ~325-345) — the four SCs are the acceptance contract; SC text was review-hardened, do not re-litigate.
- `.planning/REQUIREMENTS.md` RISK-01/RISK-02 — the requirement statements.
</canonical_refs>

<specifics>
## Specific Ideas

- The counterexample numbers (12 vs 13; gap 6; 200k-sample one-sided sweep) were verified by execution this session — they go into risk.md as stated facts with their inputs, so Phase 13's implementer can re-run them.
- risk.md should carry a small worked example of the composed path at an INEXACT-division point, since Phase 13's unit anchor must sit at one (an exact-division anchor kills no rounding mutant).
- exposure.md's existing N_v = ΔM/p_vol(σ̄) derivation stays — it is the v2+ target; the v1 note says `priceVolX96` carries exogenous `p_risk` until oracle wiring lands.
</specifics>

<deferred>
## Deferred Ideas

- Distance pipeline D2, P0/P2 composition, stateful setHaircut, oracle wiring, `p_vol(σ̄)` — all recorded in REQUIREMENTS.md Out of Scope; risk.md may reference them as future sections but must not specify them.
- Access control on setters — Phase 14 scope-boundary concern, not a risk.md topic.
</deferred>

---

*Phase: 12-spec-correction-type-completion*
*Context gathered: 2026-07-17 (quote convention user-locked; rest inherited from review-hardened roadmap)*
