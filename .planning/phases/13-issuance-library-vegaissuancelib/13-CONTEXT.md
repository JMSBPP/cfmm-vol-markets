# Phase 13: Issuance Library (VegaIssuanceLib) - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning
**Source:** Derived from locked, review-hardened artifacts (roadmap Phase 13 SCs + the Phase-12-verified risk.md). No open user decisions remained — quote convention, integer realization, rounding, and mutant list were all locked upstream.

<domain>
## Phase Boundary

The PURE issuance library and its differential proof — NOTHING stateful:

1. `VegaIssuanceLib.plk` (pure functions, no storage): `haircut_risk_price(oracleX96, hX96)` and `issue_shares(deposit, pRiskX96)`, composing the EXISTING `v3::math::full_math::{mulDiv, mulDivRoundingUp}` — never reimplemented.
2. A test-only kernel harness `.plk` (ABI-over-pure-lib, FFI-deployed) exposing both functions.
3. `IssuanceRefMock.sol` — the Solidity reference computing the IDENTICAL ceil-then-floor composition over solady `fullMulDiv`.
4. The fuzz battery (one test file) mapping each Lean lemma to a property, plus the observed-RED mutation gate.

NO module, NO storage, NO dispatch beyond the harness, NO Makefile test-suite rewiring beyond a focused target if convenient (the `make test` fold-in is Phase 15's). Phase 14 owns VegaAccountMod; do not pre-build it.

Requirements: VLIB-01, VLIB-02, VLIB-03, VLIB-04. The roadmap Phase 13 SCs (1–4) are the acceptance contract — review-hardened, do not re-litigate.
</domain>

<decisions>
## Implementation Decisions (all locked upstream)

### The spec of record
`spec/protocol/entities/types/risk.md` (rewritten + verified 6/6 in Phase 12) pins everything: the four integer operations, checked `-` (never `-%`) for `2^96 − hX96`, the revert attribution (hX96 > 2^96 → checked-subtraction revert; hX96 == 2^96 → zero-denominator revert from `full_math.plk:13–24`, an explicit `h < 1` guard is OPTIONAL and its deletion mutant is EQUIVALENT, not a kill), quote convention (collateral per vega unit, raw smallest units, LINEAR Q64.96), share units (collateral decimals, Q96 cancels), the ℝ-only status of `issuance_haircut_equiv`, the 12-vs-13 counterexample, the gap-of-6 input (deposit = 2^100), and the one-sided `composed ≤ direct`.

### The differential shape (roadmap SC-2, resolves review BLOCKER B1)
- Tolerance-0 diff is IDENTICAL-ALGORITHM ONLY: Plank composed path vs `IssuanceRefMock.sol` computing the same mulDivUp-then-mulDiv composition. NOT vs the direct path.
- The direct path `mulDiv(deposit, 2^96 − hX96, oracleX96)` appears ONLY in the one-sided fuzz `composed ≤ direct`.
- The non-fuzz unit anchor is hand-derived ≥3× independently at an INEXACT-division point — the Phase-12 counterexample point (deposit=10, oracleX96=10·2^92, hX96=3·2^92, composed=12) is pre-qualified: both hops inexact, kills both rounding-flip mutants (p_risk ceil→floor flips 12→13; shares floor→ceil flips to 13). risk.md carries the derivation.

### Typed signatures
Phase 12 created `RiskPriceX96` and `Haircut` newtypes (src/types/exposure/VegaExposure.plk) so lib signatures are typed rather than bare u256 (roadmap Phase 12 SC-3 rationale). The lib should use them; the harness unwraps whole-word calldata into them.

### The backing invariant (VLIB-03, resolves review M1)
`shares · pRisk ≤ deposit · 2^96` — a plain floor-division property, NOT `mulX96Down_le` (that's the weight-clamp lemma for the deferred distance pipeline; the mis-citation was a review finding). Assert with genuine 512-bit arithmetic on BOTH sides (each product exceeds 2^256 above deposit ≈ 2^160) — solady `fullMulDiv`/mulmod identity or equivalent; never raw `*` in the Solidity assertion.

### Reverting corpora (roadmap SC-3)
CONSTRUCTED, not assume-filtered: `hX96 ∈ {2^96, 2^96+1, 2^256−1}` all REVERT (strict h < 1); `oracleX96 == 0` REVERTS; `pRiskX96 == 0` REVERTS. Reverts asserted (vm.expectRevert), not inferred from empty returns.

### Mutation gate (roadmap SC-4, resolves review B2)
Killable mutants, EACH observed RED then restored green, cache/fuzz cleared or killed by the cache-independent unit anchor:
- p_risk ceil→floor (`mulDivRoundingUp`→`mulDiv`)
- shares floor→ceil
- `mulDiv` argument-order swap
NOT in the kill list — documented equivalence-checked instead: h-bound `<`→`<=` relaxation (masked by full_math's zero-denominator revert; both sides revert empty on the whole corpus).

### Test discipline (project standard, carried from v2.0)
ONE test file for this surface; non-fuzz unit anchor beside every fuzz; corpora constructed; forge runs --via-ir --optimize (defaulted); a runs:0 "kill" is replay not proof; "it compiles" is never acceptance — every claim is a CALLED selector outcome or an observed RED.

### Claude's Discretion
- Lib file location/name (suggest `src/lib/exposure/VegaIssuanceLib.plk`, mirroring `src/lib/market_state_measurements/`); harness location (suggest `test/exposure/VegaIssuanceKernelHarness.plk` or alongside in `test/market_state_measurements/`-style dir `test/exposure/`); test file name.
- Harness ABI: follow RealizedVolatilityKernelHarness.plk verbatim (whole-word args read at 4/36/..., selector via shr 224, header comment documenting the exact signature string + cast-sig-verified selector — the v2.0 selector-doc error is the cautionary tale: the harness header is authoritative, verify with `cast sig`).
- Solidity-side test base: PlankTestBase.deployPlank; mock in test/mocks/ (AlgebraVolatilityKernelMock pattern).
- Whether a focused `make` target is added now (fine) — the `make test` fold is Phase 15's.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The spec being implemented (verbatim authority)
- `spec/protocol/entities/types/risk.md` — the whole file; Phase 13 implements it line-for-line.
- `.planning/ROADMAP.md` Phase 13 section — the four SCs (acceptance contract).
- `.planning/REQUIREMENTS.md` — VLIB-01..04 exact statements.

### Code composed (read before writing signatures)
- `lib/plankified-univ3/plank/lib/math/full_math.plk` — `mulDiv`/`mulDivRoundingUp` signatures + the zero-denominator revert at lines 13–24.
- `src/types/exposure/VegaExposure.plk` — the `RiskPriceX96`/`Haircut` newtypes to use in signatures.
- solady `FixedPointMathLib.fullMulDiv` via the `solady/` remapping (remappings.txt → lib/panoptic-v2-core/lib/solady/src) — the mock's primitive.

### Patterns mirrored (read, then transcribe the pattern)
- `test/market_state_measurements/RealizedVolatilityKernelHarness.plk` — THE harness pattern: whole-word calldata, single commented re-order call site, header documenting exact signature + selector.
- `test/market_state_measurements/RealizedVolatility.diff.t.sol` — RealizedVolatilityKernelProbeTest + RealizedVolatilityKernelDiffTest contracts: probe-with-external-anchor + fuzz structure, repair-not-reject corpus construction.
- `test/mocks/AlgebraVolatilityKernelMock.sol` — mock shape.
- `test/PlankTestBase.sol` — deployPlank + the 6 module roots (do not hand-roll Dependency[]).

### Design authority (cited, not re-derived)
- `../cfmm-wt/lean4-spec/lean/vol_markets/RiskDesign.lean` lines 113–150 — the lemmas each fuzz property mirrors.
</canonical_refs>

<specifics>
## Specific Ideas

- The unit anchor value 12 (and the mutant-flip value 13) are already triple-derived and machine-verified — reuse the Phase-12 numbers rather than inventing a new anchor point.
- The one-sided fuzz needs its own corpus construction: hX96 ∈ [0, 2^96), oracleX96 > 0, deposit unbounded u256 is fine for the composed path but the DIRECT path's product deposit·(2^96−hX96) needs 512-bit mulDiv in the mock too — the Solidity side should compute both paths via fullMulDiv so no artificial deposit cap is imposed by the reference (a capped reference would silently shrink the corpus).
- vm.expectRevert on FFI-deployed Plank empty reverts is already exercised in RealizedVolatilitySmokeTest (zeroPeriodReverts, doubleInitReverts) — same mechanics here.
</specifics>

<deferred>
## Deferred Ideas

- VegaAccountMod module, storage, dispatch, setRiskPrice, previews — Phase 14.
- End-to-end differential vs the mock with state, `make test` fold-in, PLANK_SKIP exit — Phase 15.
- Distance pipeline D2 / P0/P2 / oracle wiring — out of milestone (REQUIREMENTS Out of Scope).
</deferred>

---

*Phase: 13-issuance-library-vegaissuancelib*
*Context gathered: 2026-07-17, derived from Phase-12-verified risk.md + review-hardened roadmap SCs*
