# Research Summary — Milestone v3.0: VegaAccountMod Vault

**Synthesized:** 2026-07-16
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md (committed `7b2ae91`)

## Executive Summary

`VegaAccountMod` is a deposit-only, internal-accounting vault: `deposit(collateralAmt)` issues non-transferable shares at `shares = floor(deposit/p_risk)`, `p_risk = oracle/(1−h)` exogenous/settable. No new dependencies are needed — the 512-bit `mulDiv`, the solady reference primitive, and the Uniswap `FullMath` gold standard are all already vendored and root-resolved; this is a composition-and-verification problem, not a stack problem. The architecture is a verbatim mirror of the sibling `RealizedVolatilityMod` (types → pure lib → interface → stateful module), with the one structural wrinkle that `VegaExposure` can't be packed into one word (288+ bits) like `Timepoint` was. The primary risks are building from the Lean-refuted `risk.md` formula, silent-zero division on unset `p_risk`/`h→1`, rounding-direction over-issuance, and a naive overflowing admissibility cross-product — all four have proven, cheap, Lean-specified fixes. Famous vault attacks (first-depositor inflation, donation, share-transfer griefing) are structurally N/A given the exogenous price and non-transferable internal counters.

## Key Findings by Dimension

**Stack (compose, don't add):** `v3::math::full_math::{mulDiv, mulDivRoundingUp}` already exists at `lib/plankified-univ3/plank/lib/math/full_math.plk` — a line-for-line Uniswap FullMath port, importable today via the existing `v3` root. Reference mock composes solady `FixedPointMathLib.fullMulDiv` (vendored). No new npm/forge deps; `package-lock.json` unchanged. The admissibility guard needs NO mulDiv (plain comparison via the collapsed form).

**Features (deposit-only is coherent):** The Lean corpus formalizes only the forward `(ΔQ_M, p_risk)→ΔQ_v` map — redemption now would create an unverified surface. The solvency invariant (`totalShares·p_risk ≤ totalDeposits`-class, `admissible_state_bounds`) is fully testable on deposits. Table stakes: a pure `previewDeposit`-style view (differential reader, not ERC-4626); `setRiskPrice` validated > 0; state readers for every stored field; two mandatory revert guards — zero-deposit AND zero-shares-minted (Q64.96 floor mints 0 for dust). Anti-features: ERC-20 transferability, ERC-4626 conformance, pool-ratio pricing, per-account ledger (a dependency of v2 redemption), `@evm_log` events (repo convention is reader-based).

**Architecture (verbatim mirror of RealizedVolatilityMod):** `init{ return_runtime(); }`; `@evm_shr(224, @evm_calldataload(0))` selector dispatch; args at calldata 4/36/68; write branches end `@evm_stop()`, views `return_u256`, fallthrough reverts. `VegaExposure` is a plain record (no packed word, no Solidity decoder). Under v1 scope `riskOracleId` and the two address fields are dead; only `exposure` and `priceVolX96` are live (`priceVolX96` carries the exogenous `p_risk`). No new `PLANK_DEP` root needed. Build order: spec correction → type → pure lib (the one independently-testable unit, diffed via kernel harness + Solidity mock before any module exists) → interface → module.

**Pitfalls (four live, three structurally N/A):** Live: (1) building from the Lean-refuted `price/haircut` formula still in `spec/entities/types/risk.md`; (2) silent-zero division — unset `p_risk` slot and `hX96 = 2^96` both give `x/0 == 0` silently on EVM (same class as the catalogued dt=0 divergence) — require strict `hX96 < 2^96` and `p_risk != 0` reachable from `run{}`; (3) rounding direction — shares FLOOR (`mulX96Down_le`), `p_risk` rounds UP (divisor; larger is conservative); invariants `shares·p_risk ≤ deposit·2^96` and `p_risk ≥ oracle`; (4) the admissibility guard must be the collapsed money-side ceiling `deposit ≤ totalMoney` — the raw cross-product overflows above ~2^160 (wrapping bypass or checked-op DoS). N/A with reasoning recorded: first-depositor inflation and donation attacks (require pool-derived rate; ours is exogenous), share-transfer griefing (non-transferable). Repo-catalogued methodology failures (R11–R17: dead-module green compile, checked/wrapping ops, bitwise @evm_not, constructed corpora, quotient cancellation, cached-fuzz replay, FFI-deployed mutants) carry into every test-producing phase as gates.

## Roadmap Implications

Suggested phases: 4 (continuing existing numbering, starting at Phase 12)

1. **Phase 12 — Spec Correction & Type Completion** — must land first; corrects the Lean-refuted `risk.md` formula and completes `VegaExposure.plk` before any arithmetic is written against it.
2. **Phase 13 — Issuance Library (VegaIssuanceLib)** — the highest-value independently-testable unit; diffable via a kernel harness + Solidity mock before the module/storage exists.
3. **Phase 14 — Module Dispatch, Storage Layout & State Readers** — fills in `VegaAccountMod.plk` (dispatch, SLOTs, validated setter, readers, both zero guards), depends on 12+13.
4. **Phase 15 — Differential Verification & Mutation Battery, PLANK_SKIP Exit** — the milestone's acceptance bar: `deposit` called green (not merely compiled), full mutation-kill battery, `PLANK_SKIP` removal.

## Research Flags

Needs research: Phase 13 (narrow — resolve the exact Q64.96/WAD fixed-point convention of `haircut_risk_price`/`issue` directly against `RiskDesign.lean`; the one open item ARCHITECTURE.md couldn't pin from repo files alone).
Standard patterns: Phases 12, 14, 15 (verbatim-mirror the proven `RealizedVolatilityMod` conventions and diff-test discipline).

## Confidence

Overall: HIGH
Gaps: (1) exact fixed-point scaling of `haircut_risk_price`/`issue` — resolve against the Lean source at start of Phase 13; (2) whether `collateralToken`/`underlyingToken` address fields should be scaffolded as inert identity metadata — a product decision for the requirements step to make explicit, not a research gap.
