# Phase 14: Module Dispatch, Storage Layout & State Readers - Context

**Gathered:** 2026-07-18
**Status:** Ready for planning
**Source:** Derived from locked artifacts — the review-hardened roadmap Phase 14 SCs (five SCs, reworked during the two-step review), the Phase-12-verified risk.md, and the Phase-13-proven VegaIssuanceLib. No open user decisions.

<domain>
## Phase Boundary

`VegaAccountMod.plk` becomes a LIVE vault module — but stays in `PLANK_SKIP` until Phase 15:

1. Fill the skeleton at `src/modules/exposure/VegaAccountMod.plk`: selector dispatch (verbatim `RealizedVolatilityMod` mirror), FOUR keccak-derived storage slots (`totalDeposits`, `totalShares`, `riskWeightedShares`, `riskPrice`), `deposit`, `setRiskPrice`, `previewDeposit`, `previewRiskPrice`, and readers for every stored field. The module holds ZERO math — every computation routes through `lib::exposure::VegaIssuanceLib`.
2. An `interfaces/exposure/` Plank interface file declaring EVERY selector with its EXACT Solidity signature string (the `RealizedVolatilityInterface` pattern) — module constants AND the test-side ABI both computed from the SAME strings.
3. The module smoke/guard test suite (extend the ONE file per surface — `test/exposure/VegaIssuance.diff.t.sol` OR a new single module file `test/exposure/VegaAccount.t.sol`; planner picks ONE and says why), with the Phase 14 mutation gate.

NOT here: the end-to-end differential vs the mock with state sequences, `PLANK_SKIP` removal, `make test` fold-in — all Phase 15. Requirements: VMOD-01..05. The roadmap Phase 14 SCs (1–5) are the acceptance contract — review-hardened, do not re-litigate.
</domain>

<decisions>
## Implementation Decisions (all locked upstream)

### Dispatch + module shape (SC-1)
Verbatim `RealizedVolatilityMod.plk` mirror: `init{ return_runtime(); }`; `let selector = @evm_shr(224, @evm_calldataload(0));` if/else-if chain over `const SELECTOR_*`; args at calldata 4/36/68; write branches end `@evm_stop()`; views `return_u256`; unknown selector falls through to `revert_empty()`. Module composes `VegaIssuanceLib` — no arithmetic in the module body.

### Interface pinning (SC-1, review finding M-3)
`src/interfaces/exposure/` file with exact signature strings; selectors verified with `cast sig` (never hand-derived — the v2.0 selector-doc error precedent). Signature types: follow the `RealizedVolatilityInterface` convention (natural Solidity types in the string; whole-word calldata reads module-side). The Phase-13 harness precedent used `uint256` everywhere — for the MODULE, pick per the RealizedVolatility convention and document; consistency between the interface strings and the Solidity test ABI is what matters and is grep-testable.

### Storage (SC-1, review finding M-1)
FOUR distinct keccak-derived slots. Slot distinctness proven by raw `vm.load` at the precomputed slot addresses after a deposit — reader-level assertions CANNOT prove it (read-conflation is behaviorally invisible when d ≡ 1). The keccak preimages are declared in the module as SLOT_* consts (RealizedVolatilityMod pattern) and restated in the test at the SAME preimage strings so `vm.load` addresses are computable test-side.

### Guards (SC-2), all asserted ON STATE (totalDeposits unchanged), never on return value
- `deposit(0)` reverts.
- `sharesMinted == 0` (dust floor) reverts — collateral cannot be banked for zero shares.
- `deposit` before any `setRiskPrice` reverts. DOCUMENTED COUPLING: the deposit-time `storedRiskPrice != 0` check means "set at least once" ONLY because `setRiskPrice` rejects 0 — one comment sentence in the module.
- Guards via `@evm_iszero` (never bitwise `@evm_not` — the catalogued trap).

### setRiskPrice + previews (SC-3)
- `setRiskPrice(pRiskX96)` stores, reverts on 0. Deliberately UNAUTHENTICATED in v1 — the module carries the scope-boundary comment (no custody, no redemption; auth arrives with oracle wiring).
- `previewDeposit(amt)`: pure issuance via the SAME lib call as deposit, no state change; test asserts `previewDeposit(amt) == totalShares delta of an immediately following deposit(amt)` (preview/action divergence is the canonical vault bug).
- `previewRiskPrice(oracleX96, hX96)`: the H1 computation with h < 1 enforced on-chain — via the lib's haircut_risk_price (its reverts come free).

### Accumulator semantics (SC-1)
`deposit` updates all three accumulators: `totalDeposits += collateral`, `totalShares += shares`, `riskWeightedShares += shares` (d ≡ 1 in v1 — scaffolded, never conflated; Lean `discounted_claim_counterexample` is why they are distinct slots).

### The admissibility guard (SC-4, review finding M-2) — HONESTY REQUIRED
Collapsed money-side form, `Q_M^Σ` instantiated as POST-deposit `totalDeposits`. In deposit-only v1 it is TRIVIALLY SATISFIED — it can never fire; it is INERT SCAFFOLDING for the deferred flow milestone and the module comment SAYS so. No "boundary match" criterion (would be vacuous). Its presence/form verified ONLY by the SC-5 cross-product mutation.

### Mutation gate (SC-5) — killable mutants only
- (a) SLOT-CONSTANT aliasing (`SLOT_RISK_WEIGHTED_SHARES := SLOT_TOTAL_SHARES`): the shared slot double-increments → readers AND `vm.load` redden. The READ-conflation variant is BEHAVIORALLY UNKILLABLE in v1 (d ≡ 1) — killed ONLY by the raw `vm.load` on the never-written slot; STATED in the test docs, not hidden.
- (b) Dust-guard deletion (via `@evm_iszero`) — killed on state.
- (c) Collapsed guard replaced with raw CHECKED cross-product `deposit · pRisk` — killed by overflow revert at a `deposit ≈ 2^200` corpus point (u128 exposure bound is type-level, not enforced on u256 accumulator slots — path unobstructed).
- NOT kills, documented equivalence-checked: unset-`p_risk` guard deletion (masked by the lib's zero-price revert — both revert empty, state unchanged).
- Each kill: cache/fuzz cleared or killed by a non-fuzz unit anchor; restored byte-identical (sha256); observed RED verbatim lines in the SUMMARY.

### Test discipline (project standard)
CALLED green only; ONE test file for the module surface; non-fuzz anchor beside every fuzz; constructed corpora, no vm.assume; `--via-ir --optimize`; `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` on every forge run (untracked broken file, another track's — do NOT modify it); focused make target allowed, `make test` fold-in is Phase 15's.

### Claude's Discretion
- Whether module tests extend `test/exposure/VegaIssuance.diff.t.sol` as a new contract or open `test/exposure/VegaAccount.t.sol` (one file per surface — the module IS a new surface; a separate file matching the RealizedVolatility layout is acceptable; choose and justify in the plan).
- SLOT_* preimage strings (follow RealizedVolatilityMod's naming, e.g. keccak of a descriptive string constant — read it first).
- Exact selector signature strings/types (pin in the interface file; cast-sig-verify; mirror into the test ABI).
- VegaAccountMod stays in PLANK_SKIP this phase (exit is Phase 15's VVER-02) — but `make compile-plank` should still be green with the module SKIPPED; the module is proven by CALLED tests through deployPlank, which does not consult PLANK_SKIP.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract being implemented
- `.planning/ROADMAP.md` Phase 14 section — five review-hardened SCs (the acceptance contract).
- `.planning/REQUIREMENTS.md` — VMOD-01..05 exact statements.
- `spec/protocol/entities/types/risk.md` — the H1 spec (the module exposes what the lib computes; no new math).

### Code composed / mirrored (read before writing)
- `src/modules/market_state_measurements/RealizedVolatilityMod.plk` — THE dispatch/storage/init pattern, mirrored verbatim (selector chain, SLOT_* consts, state word packing conventions, readers).
- `src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk` — the interface-file pattern (exact signature strings + selector constants + provenance comments).
- `src/lib/exposure/VegaIssuanceLib.plk` — the proven lib the module calls (typed by RiskPriceX96/Haircut).
- `src/types/exposure/VegaExposure.plk` — the newtypes.
- `test/exposure/VegaIssuance.diff.t.sol` + `test/exposure/VegaIssuanceKernelHarness.plk` — Phase 13's proven test surface (do not duplicate its properties; the module suite tests DISPATCH/STORAGE/GUARDS, not re-tests the arithmetic).
- `test/PlankTestBase.sol` — deployPlank.
- `test/mocks/IssuanceRefMock.sol` — exists; Phase 15 drives it with state. Phase 14 may use its pure functions for expected values.

### Failure modes already catalogued (STATE.md Accumulated Context)
- Dead-module green compile; `@evm_not` bitwise trap; quotient cancellation; cached-fuzz replay; sign-extension; checked-vs-wrapping ops; the ring-wrap slot-aliasing bug class (RealizedVolatilitySmokeTest test__unit__ringWrapWritesInsideTheRing shows the vm.store/vm.load technique).
</canonical_refs>

<specifics>
## Specific Ideas

- The vm.load slot-distinctness assertion needs the four slot ADDRESSES computable in Solidity: declare the same preimage strings test-side and compute keccak256 there — a mismatch between module preimage and test preimage shows up as vm.load reading 0 where a value was written (loud, good).
- For the 2^200 corpus point in the cross-product mutant kill: baseline must ACCEPT deposit ≈ 2^200 (u256 accumulators, shares ≈ 2^200 with p_risk near 2^96) — the kill is mutant-reverts-where-baseline-passes, asserted on state.
- The unset-price revert test doubles as the equivalence documentation site for the unset-guard-deletion mutant: same observable either way — write that in the test's docblock.
</specifics>

<deferred>
## Deferred Ideas

- End-to-end (setRiskPrice, deposit)-sequence differential vs the mock, three accumulators tolerance-0 after EVERY write, assertion inside the driver — Phase 15 (VVER-01).
- PLANK_SKIP exit + make test fold-in — Phase 15 (VVER-02).
- Access control, oracle wiring, D2/P0/P2, withdraw — out of milestone.
</deferred>

---

*Phase: 14-module-dispatch-storage-layout-state-readers*
*Context gathered: 2026-07-18, derived from review-hardened roadmap SCs + Phase 12/13 verified artifacts*
