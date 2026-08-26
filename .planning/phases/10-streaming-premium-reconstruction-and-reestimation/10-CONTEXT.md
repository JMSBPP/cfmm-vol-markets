# Phase 10: streaming premium reconstruction and reestimation - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the **measurement failure** that made Phase 9's estimate uninformative. Reconstruct per-position, per-epoch streaming premium π_it from underlying Uniswap V4 pool fee growth accrued inside each position's tick range (computed from the already-cached 632,315 Base V4 Swap logs), validate it against `OptionBurn.premium` ground truth behind a hard gate, restore the approved spec's **position-epoch panel**, and re-run the **unchanged** Phase-9 estimator. Everything Phase 9 built — GSL-LM NLS, tokenId-clustered CR0 sandwich SEs, the three committed tests, the four alternatives, the proved Lean witness — is reused as-is; **only the LHS construction changes**. Lean4-track phase.

</domain>

<decisions>
## Implementation Decisions

### Reconstruction fidelity — ~~FULL V4 REPLAY~~ → **SFPM `getAccountPremium` READ** (AMENDED 2026-07-20)

**SUPERSEDED.** The original decision (full V4 replay from cached swap logs) rested on a false premise and is **withdrawn** after research (`10-RESEARCH.md`, commit `b51d58a`):
- `swap-ticks-base-v4-full.csv` is a two-column `timestamp_unix,tick` file — `Panel.Variance` discards `amount0/amount1/liquidity/fee/sqrtPriceX96/blockNumber` at decode time. **Nothing to replay from.**
- Even after a full re-pull, exact replay from events alone is **impossible**: `feeGrowthGlobal` updates per swap *step* with a step-varying liquidity divisor (`Pool.sol` L400-407), while the `Swap` event exposes only post-swap aggregates. True replay needs every `ModifyLiquidity` since pool init plus bit-exact Haskell ports of `SwapMath`/`SqrtPriceMath`/`TickMath`/`FullMath` — 3-4 weeks.

**AMENDED DECISION (user-approved):** read the exact per-liquidity Panoptic premium accumulator from the **deployed** `SemiFungiblePositionManagerV4.getAccountPremium(...)` (SFPM `0x8dcAa08c…33af`, reachable via `PanopticPool.SFPM()`) using **archive `eth_call`s** on the existing keyless Base endpoint.
- This **preserves the fidelity intent** of the original decision — exact identity, zero approximation — by evaluating the identity *inside the contract that defines it*, rather than re-deriving it off-chain. Approximation remains rejected.
- The accumulator is X64 and **already includes the utilization multiplier** (ν = 1/VEGOID = 1/8, `RiskEngine.sol` L104). The `atTick` argument extrapolates via a live `feeGrowthInside` read, which is what makes a **daily** panel possible (stored accumulators only jump at chunk touches).
- Verified live during research: `extsload` succeeds at block 44,000,000 and `getAccountPremium` returns monotone-increasing values across blocks 44.5M/47M/latest with owed > gross, matching the ν·R/N spread.
- Budget: ~8k-15k `eth_call`s, 30-60 min of RPC time.
- Full replay is **demoted to an optional narrow-window cross-check** — nice-to-have, not required for phase success.

### Premium definition — PANOPTIC PREMIUM (not raw fees)
- π_it = fee growth **× Panoptic's utilization-based multiplier/spread** — the quantity buyers actually pay, and the same object `OptionBurn.premium` aggregates. This is what makes the validation gate meaningful.
- Consequence to state explicitly in the analysis: π_it is then Panoptic's premium, **not** the bare `streamingPremium`/STREAMING_PREMIUM.md fee-revenue identity that Lean models. The multiplier is a documented wedge between the Lean object and the estimated object — the cross-walk table must record it rather than paper over it.
- The exact multiplier formula must be sourced from Panoptic's contracts/docs during research, not guessed.

### Validation gate — HARD, median relative error ≤ 1%, in ETH WEI, stratified (TIGHTENED 2026-07-20)
- **Estimation does not run** until reconstructed-Σ-over-spell reconciles with observed `OptionBurn.premium` across the 61 Phase-9 spells at **median relative error ≤ 1%** (tightened from 10% on research recommendation: the reconstructed panel *telescopes into* the ground truth rather than independently estimating it, so 10% would let real errors through).
- **Units: ETH wei, not USD** — no price-conversion noise in the gate.
- **Stratified short vs long** — `_getAvailablePremium` caps settled long premium, so the two strata must be reported separately rather than pooled.
- The full error distribution (not just the median) is reported: quantiles, worst cases, and any systematic sign bias.
- If the gate fails: diagnose and fix the reconstruction — do NOT proceed to estimation, and do NOT relax the tolerance to pass. A failed gate is a legitimate phase outcome.
- Rationale: this is the discipline Phase 9 lacked; it converts "did we measure the right thing?" from a post-hoc audit question into a pre-estimation blocker.

### Power / stopping rule — PRE-COMMITTED, result-independent
- **Success = an informative υ₀ interval**, defined as clustered-CI half-width **≤ ~6.2e-5** (≤ ¼ of Phase 9's ±2.48e-4) — **regardless of κ̂'s sign or significance**. Success is explicitly NOT contingent on the result's direction.
- If κ̂ > 0 with adequate precision: state that the fitted profile satisfies the hypotheses of the **proved, axiom-clean** `Upsilon.exp_family_witnesses_ATMOTM` and therefore witnesses `ATMOTMNullHypothesis` at c = κ̂·Δi.
- If the interval remains uninformative after a passing validation gate: **report that this market cannot identify υ, and STOP.** No respecification, no subsample hunting, no alternative-estimator fishing. (See `anti-fishing-replication` skill — invoke it if anyone, human or agent, proposes moving the goalposts mid-run.)

### WAVE-0 BLOCKER — the `width == 0` sample-gain risk (ADDED 2026-07-20)
- `_getPremia` **skips legs with `width == 0`**, and many sampled legs in this market have width 0. The phase's premise — a ~×100 sample gain (≈55 positions × ~119 epochs vs. 61 spells) — is therefore **UNVERIFIED**.
- **Wave 0 must measure this before any estimation work is planned or run:** count legs/positions with `width ≠ 0`, and derive the achievable panel size. If the usable panel is not materially larger than Phase 9's 61 observations, the phase cannot deliver its power goal and must **stop and report** rather than proceed — same discipline as the stopping rule below.

### Claude's Discretion
- Haskell module layout for the SFPM read path (`eth_call` batching, block-height schedule, caching/checkpointing of accumulator reads); the optional replay cross-check if attempted.
- Whether the reconciliation runs on all 61 spells or a stratified subsample first (as a fast pre-check) before the full gate.
- Epoch alignment details, so long as `Panel.Build.dailyEpoch` remains the single source of truth for the join (the 40587-offset trap 09-05 caught).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### What went wrong and why this phase exists
- `notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates.md` — Phase 9's live run: the null, the CI width, §1 "What the data actually supports" documenting why the position-epoch panel was not constructible
- `notes/structural-econometrcics/data/DATA-SOURCES.md` §4 (resolved market/route) and §5 (live subgraph schema findings: no `TokenId.snapshots`, empty `premiumSettleds`, zero `premiaSettled*Total`, `Leg.strike` is a tick)
- `.planning/phases/09-.../09-09-SUMMARY.md` — including the tick-scale optimizer trap (fixed start κ=0.2 makes exp(−κ·d) ≈ 5e-14 at median d=153; produced a spurious κ=0.384 before the data-scaled multi-start fix)

### The contract (unchanged)
- `notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md` — the approved spec; §1 position-epoch unit is RESTORED by this phase, §4.3 equation, §5 tests, §6.2 alternatives all unchanged

### Theory of the object being reconstructed
- `spec/protocol/refs/cfmm-discrete/STREAMING_PREMIUM.md` — streaming premium ≡ LP fee revenue per unit liquidity (the identity motivating the reconstruction)
- `lean/vol_markets/Panoptic.lean` — `streamingPremium` (Finset.sum of θ·Δt), `latticeTheta`, `thetaAtm`, proved `theta_atm_closed_form`
- `lean/vol_markets/Upsilon.lean` — `ATMOTMNullHypothesis`, **proved** `exp_family_witnesses_ATMOTM` (axiom-clean); the witness target
- `notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md` — must be EXTENDED with the Panoptic-multiplier wedge

### Reusable machinery (do not re-derive)
- `econometrics/src/Panel/Variance.hs` (σ̂² + EIV instrument, RPC ingestion), `Panel/Build.hs` (`dailyEpoch` — the join's source of truth), `Model/{Upsilon,NLS,EIV,SandwichSE}.hs`, `Tests/Specification.hs`, `Alternatives.hs`
- Cached raw data: the Base V4 swap-log caches under `notes/structural-econometrcics/data/` — **reuse, do not refetch** (the full pull cost ~3h)

### External
- Panoptic contracts/docs for the premium multiplier formula — source it, don't guess (arXiv:2204.14232 for the mechanism; the deployed contracts for the exact parameterization)
- Uniswap V4 fee-growth accounting (`feeGrowthGlobal`, `feeGrowthOutside`, `feeGrowthInside` identity)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The entire Phase-9 estimation stack is sound and stays untouched: only the LHS changes
- 632,315 cached Base V4 Swap logs already on disk with block ranges recorded — the replay engine's input
- `OptionBurn.premium{0,1}` per spell (61 spells) — the validation ground truth
- Aristotle recipe available if any new Lean statement is needed (unlikely this phase — the witness is already proved)

### Established Patterns
- Haskell only (user directive); Stack project at `econometrics/`, LTS-24.50, hmatrix-gsl linked
- TDD with golden fixtures at 1e-9 (the sandwich SE precedent); full suite currently 59/0 and must stay green
- Self-describing analysis outputs with full data lineage (required by the audit gate)
- No `/home/`, `$HOME`, `~/` in tracked files; no keys committed

### Integration Points
- New replay module under `econometrics/src/` feeding `Panel.Build`
- `notes/structural-econometrcics/{data,analysis}/` for outputs
- Phase 9's unrun plans 09-10 (GAMS cross-check handoff) and 09-11 (audit-econ gate) remain available — likely re-targeted at Phase 10's results rather than Phase 9's null

</code_context>

<specifics>
## Specific Ideas

- The user's reasoning for this phase: Phase 9's null was **uninformative, not evidence of absence** — υ₀'s CI [−2.48e-4, +2.48e-4] was wider than β₀ itself, so a vega as large as the entire observed premium sits inside it.
- The reconstruction is not a workaround but the **theoretically correct** move: Panoptic's premium IS the underlying LP fee revenue, which is exactly what the project's own `STREAMING_PREMIUM.md` asserts and what Lean's `streamingPremium` models.
- Expected sample gain: ≈55 positions × ~119 epochs, versus 61 lifetime spells — roughly two orders of magnitude, with within-position variation restored (which also revives the position-FE selection diagnostic that Phase 9 could not run).

</specifics>

<deferred>
## Deferred Ideas

- Re-running the GAMS cross-check (09-10) and audit-econ gate (09-11) against Phase 10's results rather than Phase 9's null — sequence after this phase produces an informative estimate
- Multi-market / mainnet extension — still no live mainnet Panoptic deployment exists
- Amending the approved econometric spec text — unnecessary if the position-epoch panel is genuinely restored
- Estimating on raw fee growth (the bare Lean object without the Panoptic multiplier) as an additional specification

</deferred>

---

*Phase: 10-streaming-premium-reconstruction-and-reestimation*
*Context gathered: 2026-07-20*
