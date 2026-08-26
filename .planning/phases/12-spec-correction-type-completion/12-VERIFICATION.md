---
phase: 12-spec-correction-type-completion
verified: 2026-07-17T13:13:18Z
status: passed
score: 6/6 must-haves verified
---

# Phase 12: Spec Correction & Type Completion Verification Report

**Phase Goal:** The Lean-refuted `price/haircut` formula is gone from the tree and replaced by the machine-checked `p_risk = oracle/(1−h)` with the fixed-point and quote conventions pinned, and `VegaExposure.plk` is the live-fields-only record carrying typed risk Q-types — so no arithmetic is ever written against a refuted spec or an untyped stub.
**Verified:** 2026-07-17T13:13:18Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A reader of risk.md sees `p_risk = oracle/(1−h)` and the per-operation integer realization (ceil p_risk, floor shares), not the refuted price-over-haircut formula | ✓ VERIFIED | `spec/protocol/entities/types/risk.md` §1–3 contain the exact formula, all four integer operations, and correct revert attribution (zero-denominator from `full_math`, not the subtraction) |
| 2 | The refuted expression `collateralAmount* (self.price/haircut)` appears nowhere under spec/ or src/ (scoped grep is empty) | ✓ VERIFIED | `git grep -nF 'price/haircut' -- spec/ src/` exits 1, no output |
| 3 | The refuted-concept .plk files (RiskDiscount.plk, RiskMeasureLib.plk) are DELETED, so the concept exists nowhere in src/ | ✓ VERIFIED | Both files absent; `src/types/risk/` and `src/lib/risk/` directories no longer exist; `git grep -n 'RiskDiscount\|RiskMeasureLib' -- src/ test/` exits 1 |
| 4 | risk.md records `issuance_haircut_equiv` holds over ℝ ONLY, with the verified integer counterexample (deposit=10, oracleX96=10·2^92, hX96=3·2^92 → composed 12 vs direct 13) and only composed ≤ direct transfers | ✓ VERIFIED | §4 states this exactly; arithmetic independently recomputed in Python and matches risk.md verbatim (pRiskX96 = 60944740395587951995033807951, composed=12, direct=13, gap-of-6 at deposit=2^100 confirmed) |
| 5 | VegaExposure.plk is a two-live-field record (`exposure`, `priceVolX96`) plus `RiskPriceX96`/`Haircut` newtypes, with the stub's `collateralUnits`/`priceVol` mis-naming fixed | ✓ VERIFIED | File contains exactly these fields/newtypes; no `collateralUnits`, no init/run block, ASCII-only (no U+2212) |
| 6 | exposure.md records deferred-fields note + v1 note that priceVolX96 carries exogenous p_risk, with N_v derivation retained | ✓ VERIFIED | §3 contains both notes verbatim; `N_v = ΔM/p_vol(σ̄)` derivation (§2) untouched |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `spec/protocol/entities/types/risk.md` | H1 issuance spec: oracle/(1−h), integer realization, quote convention, share units, ℝ-only caveat + counterexample | ✓ VERIFIED | All 13 required literal substrings present (formula, three integer ops, lemma names, `0 ≤ oracle`, counterexample numbers, gap-of-6 input, quote convention, share units, zero-denominator attribution) |
| `src/types/exposure/VegaExposure.plk` | Two-live-field VegaExposure record + RiskPriceX96/Haircut newtypes | ✓ VERIFIED | `exposure: u256`, `priceVolX96: u256`, `const RiskPriceX96`, `const Haircut` all present; no `collateralUnits`; no init block; fully ASCII (`grep -P '[^\x00-\x7F]'` finds nothing) |
| `spec/protocol/entities/types/exposure.md` | Deferred-fields note + v1 priceVolX96-carries-p_risk tension | ✓ VERIFIED | `oracle-wiring`, `carries the EXOGENOUS`, `N_v`, and all three deferred field names (`collateralToken`, `underlyingToken`, `riskOracleId`) present |
| `src/types/risk/RiskDiscount.plk` (deletion) | Must not exist | ✓ VERIFIED | File and parent directory absent |
| `src/lib/risk/RiskMeasureLib.plk` (deletion) | Must not exist | ✓ VERIFIED | File and parent directory absent |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `spec/protocol/entities/types/risk.md` | `RiskDesign.lean` | lemma citation by name and file | ✓ WIRED | `haircutRiskPrice_ge_oracle` and `issuance_haircut_equiv` both cited; cross-checked against `../cfmm-wt/lean4-spec/lean/vol_markets/RiskDesign.lean` — `haircutRiskPrice` def at line 113, `haircutRiskPrice_ge_oracle` at line 119 (hypotheses `0 ≤ oracle`, `0 ≤ h`, `h < 1` match risk.md exactly), `issuance_haircut_equiv` at line 123. All line numbers and lemma names in risk.md are accurate. |
| `src/types/exposure/VegaExposure.plk` | `spec/protocol/entities/types/exposure.md` | field names match the spec record | ✓ WIRED | Both files declare identical field names/types/comments for `exposure: u256`/`priceVolX96: u256` — verbatim match |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| RISK-01 | 12-01-PLAN.md | risk.md states `p_risk = oracle/(1−h)`, cites lemmas, pins integer realization, records ℝ-only caveat + counterexample, refuted expression gone | ✓ SATISFIED | All acceptance criteria verified directly against `risk.md`; grep gate empty; REQUIREMENTS.md marks `[x]` — consistent with reality |
| RISK-02 | 12-01-PLAN.md | VegaExposure.plk is live-fields-only record with typed Q-types; exposure.md records deferred fields | ✓ SATISFIED | Verified directly against `VegaExposure.plk` and `exposure.md`; REQUIREMENTS.md marks `[x]` — consistent with reality |

No orphaned requirements: REQUIREMENTS.md traceability table maps only RISK-01 and RISK-02 to Phase 12, both declared in the plan's frontmatter `requirements:` field, both marked `Complete`.

### Compile Precondition (labelled, not acceptance)

- `make compile-plank` → `10 ok, 0 failed, 1 skipped` (unchanged from plan-time baseline; the 1 skip is `VegaAccountMod`, the Phase-14 target).
- Direct `plank build src/types/exposure/VegaExposure.plk --dep v3=... --dep std=... --dep pos_spec=... --dep lib=... --dep types=... --dep interfaces=... --backend sona` emits EXACTLY ONE `error:` line: `error: missing init block` — confirmed by direct execution, byte-for-byte.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | none found | — | No TODO/FIXME/PLACEHOLDER/stub markers in any of the three modified files |

### Human Verification Required

None. This phase is DOC + type-declaration only, verifiable entirely by grep/read/compile — no UI, no runtime behavior, no external service.

### Gaps Summary

No gaps found. All must-haves from the plan frontmatter were independently re-verified against the actual codebase (not trusted from SUMMARY.md):

- The scoped grep gate is empty, confirmed with a fresh `git grep` run.
- The forbidden `Q0.64` token is absent from risk.md.
- Both refuted `.plk` files and their parent directories are gone; zero references anywhere in `src/` or `test/`.
- All required literal strings in risk.md are present verbatim, including the correct revert attribution (zero-denominator from `full_math.plk`, not the subtraction) and the lemma citations with the `0 ≤ oracle` hypothesis.
- The counterexample arithmetic was independently recomputed in Python: `pRiskX96 = ceil(10·2^96·2^96/(13·2^92)) = 60944740395587951995033807951`, composed shares = 12, direct shares = 13, gap at `deposit = 2^100` = 6 — all match risk.md exactly.
- The Lean lemma names and line numbers cited in risk.md were cross-checked directly against `RiskDesign.lean` and are accurate.
- VegaExposure.plk has exactly the two live fields with correct spec names, the two newtypes, no init/run block, and is fully ASCII (no U+2212).
- exposure.md carries both required notes and retains the N_v derivation.
- The compile precondition (`make compile-plank` = 0 failed; direct build = exactly one `error: missing init block`) was re-run directly and matches the labelled expectation.
- REQUIREMENTS.md checkbox state for RISK-01/RISK-02 (`[x]` Complete) is consistent with the verified reality, and ROADMAP.md's Phase 12 entry is marked `[x]` complete.

---

_Verified: 2026-07-17T13:13:18Z_
_Verifier: Claude (gsd-verifier)_
