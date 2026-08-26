# Milestones

## v3.0 VegaAccountMod Vault — H1 issuance, exogenous risk price (Shipped: 2026-07-19)

**Phases completed:** 4 phases (12–15), 7 plans, 41 commits (`034f963..8f4d7eb`), 17 source/test files (+1259/−215), 2026-07-16 → 2026-07-19.
(The archive tool's "7 phases / 14 plans" count swept the v2.0 phase dirs too — corrected here.)

**Delivered:** `VegaAccountMod.plk` went from a non-compiling skeleton in `PLANK_SKIP` to a proven deposit-only vault — deposit collateral, receive vega-exposure shares at `p_risk = oracle/(1−h)` — with every claim resting on a CALLED test or an OBSERVED mutation kill, measured against the machine-checked Lean design authority (`JMSBPP/cfmm-vol-markets-spec`: `lean/vol_markets/`).

**Key accomplishments:**
- **Spec correction first (Phase 12):** the Lean-REFUTED `price/haircut` formula killed in `risk.md` and its code embodiment (`RiskDiscount.plk`/`RiskMeasureLib.plk`) deleted; the H1 integer realization pinned to the operation level (Q64.96/Q0.96, p_risk rounds UP, shares FLOOR, checked subtraction, ℝ-only counterexample 12-vs-13 recorded with reproducing inputs).
- **Issuance library proven before any module existed (Phase 13):** pure `haircut_risk_price`/`issue_shares` composing the existing `v3::math::full_math` 512-bit mulDiv, diffed tolerance-0 identical-algorithm against a solady mock, with the one-sided ℝ→ℤ transfer (`composed ≤ direct`) asserted separately after review proved exact cross-path equality FALSE in integers.
- **The module went live with zero math in it (Phase 14):** verbatim RealizedVolatilityMod dispatch, four keccak slots proven distinct by raw `vm.load` (the only observation that kills read-conflation while d≡1), guards asserted on state, the inert admissibility guard labeled honestly, deliberately-unauthenticated setter documented with its oracle-wiring tripwire.
- **The acceptance bar (Phase 15):** end-to-end `(setRiskPrice, deposit)` sequence differential — three accumulators, tolerance 0, after EVERY write, assertion inside the driver — plus the full battery: 5 killable mutants observed RED (verbatim lines recorded), 2 equivalence-masked mutants documented and never counted; `PLANK_SKIP` emptied; suites folded into `make test`.
- **Verification discipline:** every phase closed with an independent verifier that re-derived gates and RE-KILLED a mutant itself, matching recorded FAIL lines byte-for-byte (e.g. `1013 != 1012` on the e2e anchor) and restore hashes exactly.

**Commands of record at ship:** `make compile` → 11 ok / 0 failed / 0 skipped (empty skip list); `make test` → 74 pass / 4 fail (the 4 = pre-existing pos_spec harness bugs, vol-type-system track, visible and unfiltered).

**Known gaps / handoffs (not v3.0 defects):** the 4 pos_spec harness failures (vol-type track); the untracked `PriceSetterHook.sol` stray breaking bare `forge build` (PR #11's track; routed around via a documented `--skip`); deferred by design — withdraw/redeem, per-account ledger, distance pipeline D2, P0/P2 composition, stateful setHaircut, oracle wiring (with setter auth), `p_vol(σ̄)` from pos_spec.

**Archives:** `milestones/v3.0-ROADMAP.md`, `milestones/v3.0-REQUIREMENTS.md` (full multi-track snapshots).

---
