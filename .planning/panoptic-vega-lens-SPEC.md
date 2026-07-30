# PanopticVegaLens — per-strike vega computation + the υ experiment (task #10 / Phase 23; todo.md T12→T13)

**Status: v2 — two-step review round 1 done (Reality Checker + Model QA Specialist, both
NEEDS WORK); all BLOCKERs/MAJORs resolved below. Both reviewers verified the motivating
econometric numbers and the Lean lemma substrate as accurate; the findings concentrated on
the L2/L3 falsification design and on this repo's code being described optimistically —
all corrected in this revision.**

## Goal (todo.md §14 — quoted as-is, typos included)

> Once you mint an option and price/ tick starts moving with time, volatility starts
> realizing and the payoff which is gained via trading fees has a sensitivity to such
> volatility. After idenifying the panoptic adapter payoff form and its relation with
> nreLIAED VOLATILITY, we need to build a module 'PanopticVegaLens' that tracks this and
> offers services to connect per strike, etc

The backlog orders this deliberately: **T12 (research: HOW to track vega from Panoptic)
precedes T13 (the lens module; Phase 23 of the v5.0 "Experiment Rig" milestone, Phases
20–23 per the backlog coverage ledger)**. This spec is T12's answer, grounded in the
terminal econometric evidence, and the build plan for T13.

## Motivating evidence — the υ estimation program and its terminal verdict

lean4-spec phases 09 (`upsilon-econometric-estimation-lean-aware`) + 10
(`streaming-premium-reconstruction-and-reestimation`), terminal 2026-07-27
(10-10-SUMMARY / 10-10-DISPOSITION-MEMO / 10-11-SUMMARY; all figures below verified
against source by both reviewers):

- Estimating equation (locked): `π_it = β₀ + υ₀·exp(−κ|i_K − i_t|)·σ̂²_t + v_it`.
- Phase 9 on real Base data (632,315 v4 Swap logs → 119 daily σ² epochs; 61 accrual spells /
  55 tokenIds / 4 accounts): υ̂₀ = 2.27e-9 (SE 1.26e-4) — numerically ZERO; κ structurally
  unidentified (enters only through υ₀·exp(−κd)).
- Phase 10 rebuilt the premium series from CHAIN STATE (1%-wei-gated) → 6,760 position-epoch
  obs / 55 clusters. Run 1: υ̂₀ = 0.036, SE 0.075, CI half-width 0.148 vs the pre-committed
  bar 6.2e-5 → `STOPPING_RULE: UNINFORMATIVE`. Run 2 (seller-side-normalized LHS, single
  pivot-locked re-run): υ̂₀ = 0.106, SE 0.101, half-width 0.198 → `UNINFORMATIVE` again.
  **Terminal conclusion, verbatim: "this market cannot identify υ."**
- What SURVIVED: (i) **κ̂ ≈ 0.031 rejected the flat-vega-profile null in BOTH runs**
  (p = 9.5e-3, 7.3e-3; clustered SE 0.0125, so the 95% interval is roughly [0.006, 0.055])
  — the EXISTENCE and SIGN of moneyness decay is real in market data; the point 0.031 is
  NOT validated (one market, 55 clusters at 84% top-10 concentration, wedge bias toward
  zero fenced as proxy-level); (ii) the **Panoptic utilization-multiplier wedge was
  MEASURED** (10-10/10-11, over `premium-accumulators.csv` chunk-level readings: median
  1.1125, p90 1.2917, 38.9% of 8,910 readings exactly 1; R/N is UNBOUNDED — the observed
  max implied R/N 2.33 refuted the 1.125 figure previously quoted as a bound) — the one
  Lean↔chain fidelity gap, whose shape contamination is small-but-nonzero (Pearson 0.1435
  vs moneyness, non-monotone quintiles) and was explicitly NOT declared negligible.

Diagnosis (why the LEVEL failed, design-bound not sample-bound): 55 clusters / 4 accounts
put a ~1e-1 floor under the clustered SE against a 6.2e-5 bar; one market's σ² path is
endogenous with no exogenous variation; the LHS carries the utilization wedge and a
deposited-vs-required-margin collateral caveat. The parallel η_D record
(btt-subnet-calibration, external to these worktrees) reached the same class of verdict
from observational chain data — its lesson: *an experiment must manufacture the exogenous
variation the protocol does not supply.*

## Design principles (each traces to a failure mode above)

**P1 — COMPUTE the model-implied level; establish external validity separately.** υ and
ΔQ_v are structurally pinned, machine-proven quantities:
- `Panoptic.volOptionPayoff` / `deltaQv_of_payoff` (PROVEN): π^σ = ΔQ_v·(σ²(i(t)) − σ²_K)⁺,
  and the ITM difference quotient in σ² IS ΔQ_v.
- `Upsilon.variancePortfolio_upsilon` (PROVEN): υ = t/2 for the log-contract portfolio,
  independent of p; `variancePortfolio_unit_upsilon`: the Id_{N_σ} = 2/t scaling gives unit
  vega.
- The replication weights are pinned: Σℓ = 1 (`GeomProfile.geomWeight_sum`); the doc-weight
  ↔ geometric-profile bridge (`VolInstrument.strikeWeight_bridge`); the STRIKE-NOTIONAL
  grid ratio 1.0001^(−Δᵢ) (`varswapWeight_geometric`) vs the LIQUIDITY ratio
  ξ⋆ = λ^(−Δᵢ/2) (`logContractLiquidity_geometric` — the tranche-gamma Jacobian separates
  the two; cite per object, notation binding); the Q_M^L/Q_X^L closed forms (ported
  diff-exact in the LDF work).
The lens COMPUTES per-strike ΔQ_v from position state through these forms. **This is
model-implied vega, not a measurement of the market** (review F-MQA7): L0/L1 are
internal-consistency checks; the lens's claim to describe the market is established ONLY
by L2 (wedge-exact premium cross-check) and L3 (experimental level estimate). A lens that
never met L2/L3 would be tautological.

**P2 — The Experiment Rig supplies the exogenous σ² variation the market cannot.** The
pieces: PriceSetterHook + the delegated ExchangeRateDiffusion (haskell_rpc_api; the
in-repo price-imposition fallback is the `TickCheat`/PriceSetterHook.t.sol slot0-write
mechanism — NOT the task-16 E2E, whose driver is real router swaps) give
experimenter-controlled price paths; the events layer (E3/E5/E6 live; E2 owed by task #14)
emits the (tObs, σ², φ, position) panel with uint48 seriesIdHash provenance for the GAMS
estimator (cfmm-gams issue #1 pipeline). **Characterization correction (review F-RC4): the
task-16 GOAL E2E is a FEE-regime experiment — one vol path, two fee configs, premium
ordering by fee. It does NOT demonstrate σ²→premium ordering. The two-σ²-regime υ finite
difference is a NEW claim that L3 must establish with its own RED test.**

**P3 — Carry forward the two salvaged empirical facts, correctly fenced.**
- κ: a DIRECTIONAL stylized fact (decay exists, κ > 0) plus an attenuated market-specific
  interval (~[0.006, 0.055]) — never the bare point 0.031, and **never a lens parameter**:
  the structural ΔQ_v(i_K) profile already implies a moneyness decay through the
  replication weights, and injecting an empirical κ would double-count it (review F-MQA4).
  κ's role: L3 re-estimates κ wedge-free in the rig and compares it BOTH to the structural
  profile implied by ΔQ_v(i_K) AND to the observational interval.
- The wedge: in the rig it is EXACTLY COMPUTABLE per reading from SFPM state
  (`multiplierWedge`: 1 + ν·R/N long, 1 + ν·R²/(N·T) short, ν = 1/8, from
  removed/net liquidity) — so L2 strips it deterministically per observation. The measured
  Base DISTRIBUTION is used ONLY as a descriptive sanity band on the driven corpus, never
  as a correction, bound, or tolerance — matching 10-11's own fencing of it (reviews
  F-RC1/F-MQA2, convergent BLOCKERs).

**P4 — Notation is binding.** υ, ΔQ_v, σ², σ²_K, i_K, ξ, ι, L(i_K), π^σ, κ, and the
"wedge" keep the docs' own symbols. Lemma citations name the exact object they pin.

## Architecture — four increments (TDD each)

### L0 — the payoff kernel harness (un-RED the drafted test)

`src/lib/exposure/PanopticVegaLensHarness.plk` — the missing FFI entry the drafted
`test/exposure/PanopticVegaLens.t.sol` already targets:
`volOptionPayoff(uint256 dQv, uint256 sig2, uint256 sig2K) -> uint256` =
`dQv * max(0, sig2 - sig2K)`. Unit-agnostic pure kernel. The drafted fuzzes bound inputs
to uint128 (formula/OTM) and uint120 (difference quotient) — no overflow inside those
bounds; the harness states its envelope explicitly (checked mul or documented bound) and
a new test pins the outside-envelope behavior (revert vs wrap — decision recorded in the
harness header).

### L1 — the per-strike ΔQ_v reader (the lens core)

`src/lib/exposure/PanopticVegaLensLib.plk`: given position state — the PanopticTokenId
legs (strikes i_K, widths, isLong, tokenType; layout pinned to panoptic-v2-core
`5555b320`) and the LDF parameterization (ξ⋆ Q96, ι, L̄; per-leg LiquidityChunks) —
compute:

- **`vega_for_liquidity` — NEW CODE (review F-RC2): the chunk→exposure inverse does NOT
  exist today.** `LiquidityAmounts.plk` has only the forward maps (`liquidity_for_vega`:
  exposure → ΔM → chunk, flooring twice). The inverse is therefore inexact; L1 defines its
  rounding direction (DOWN — conservative: never report more vega than the chunk funds)
  and the tolerance-zero differential oracle restates the IDENTICAL rounding order, or the
  test is not tolerance-zero. A round-trip test pins the one-sided inequality
  `vega_for_liquidity(liquidity_for_vega(x)) <= x` with the measured maximum gap.
- `delta_q_v(i_K)` per leg from the chunk via the inverse + the Q_M^L/Q_X^L cumulatives.
- `pi_sigma(i_K, sig2)` per leg: L0's kernel at the leg's σ²_K, long/short signed per
  `𝕀_{long|short}`.
- Portfolio aggregation: Σ over legs; the Demeterfi price-insensitivity test (aggregate
  ΔQ_v invariant to i_t over the replication range) is the sharpest mutant kill for a
  wrong per-leg weight.

DEPENDENCY NOTE: full per-leg sizing (size_k = L̄·w_k/n_k) is task #14 (in progress). L1
is written against the LiquidityChunk/LegWeights types that EXIST; the L1 differentials
use hand-built chunks so they do not block on #14.

### L2 — the σ² join: live π^σ and the wedge-exact premium cross-check

**Entry condition (BLOCKING deliverable, reviews F-RC3/F-MQA3): the units-and-scales
table.** The v1 claim "σ²_K is uint88 in the same tick²·s units" was FALSE as stated:
`tick_volatility_is_complete` checks only `vol > 0`; `pack_vol_order` silently MASKS to
88 bits (no revert on overflow); and `TickVolatilityLib.plk:80-88` consumes `volStrike`
as a Q64.96 sqrt-price-like coordinate (shift-left 96 → `getTickAtSqrtRatio`) to place
the order's tick bucket — a SECOND interpretation of the same field. Before any L2 code:
- resolve the volStrike unit question (one field, one unit, or an explicit conversion
  between the order-placement view and the σ²-comparison view), recorded in the table;
- trace σ² end-to-end: Algebra tick²·s uint88 (`getAverageVolatility`) → the kernel
  input; ΔQ_v's Q64.96 collateral/vega scale; the FULL conversion chain from
  ΔQ_v·(σ²−σ²_K) to SFPM's X64 token-unit premium accumulator — the phase-10 program
  burned itself once on exactly this class of incoherence (the USD/day-vs-ETH/hour bar);
- add a range check on the strike (revert, in scope) OR document the 88-bit mask as an
  explicit invariant with a test;
- a hand-computed golden AT REAL SCALES (the drafted `_vop(1e18, 30, 20)` toy golden does
  not discharge this).

Then:
- `pi_sigma_live(position, tick, ts)` = L1 ∘ `RealizedVolatilityMod.getAverageVolatility`
  (the same series and clock the DynamicFeeHook consumes).
- **The cross-check (the falsification instrument):** over a driven corpus on the task-16
  stack, for EACH observation i compute `wedge_i` EXACTLY from the corpus's own SFPM
  accumulator state (removed/net liquidity, is_long; the `multiplierWedge` formulas) and
  assert `SFPM_premium_i / wedge_i` vs the lens's `pi_sigma_i` within a tolerance derived
  from ROUNDING ANALYSIS ONLY (X64 truncation + integer-division floors along the declared
  conversion chain) — a pinned numeric bound, not a distributional band. The measured Base
  distribution appears only as a descriptive sanity report on the corpus.
- **Failure semantics + tie-breaker (review F-MQA2):** with the wedge stripped exactly, a
  residual discrepancy indicts either the lens's weights/sizing or the structural
  π = ΔQ_v·(σ²−σ²_K)⁺ form itself. Disambiguation: vary σ² holding the position fixed —
  weight/sizing errors scale with the position, structural-form errors scale with the σ²
  path shape. The L2 battery includes both variations.

### L3 — the υ experiment (the econometric redemption; GAMS-side estimation)

**Entry conditions:**
1. **Task #14 dependency is HARD (review F-RC5):** the panel's position rows come from E2
   `PortafolioMinted`, which has NO emitter until #14 ships. The L3 fixture can be drafted
   and the σ²/fee legs of the panel tested, but the panel-export test cannot go green
   before #14 (no interim position source is defined — better to wait than to fork the
   schema).
2. **GAMS-side pre-registration is an entry condition, not an afterthought (review
   F-MQA5).** Before the first driven path is generated, the cfmm-gams side commits a lock
   containing: the estimand AND ITS UNITS (unit-coherent with the exported panel — the
   phase-10 bar incoherence must be impossible by construction); the finite-difference
   formula and the regression specification; the sign convention fixed to the seller-side
   normalization (per the 10-11 sign-convention note); SEED-REPLICATION design replacing
   clustering (tokenId clustering is meaningless in a rig — precision comes from N
   independent RNG-seeded σ² paths, with a PATH-COUNT POWER ANALYSIS: N paths × path
   length → target half-width, computed before running); and a result-blind stopping rule.
   The Plank-side fixture asserts the lock's hash is embedded in the exported panel
   metadata.

The experiment:
- Drive N controlled σ² paths over the hook+SFPM stack with LDF-shaped positions across a
  strike grid (driver: ExchangeRateDiffusion via PriceSetterHook when the haskell side
  lands; in-repo fallback: the TickCheat/slot0-imposition mechanism).
- Panel assembles FROM OUR EVENTS (E3 timepoints, E5 fee/σ per swap, E2 positions, SFPM
  premium reads per epoch), seriesIdHash provenance.
- **Acceptance (the level test — review F-MQA1, BLOCKER resolution):**
  `|υ̂_FD − ΔQ_v^lens| / ΔQ_v^lens ≤ ε_level`, with ε_level pre-registered in the GAMS
  lock, in the panel's declared units. Sign-and-order alone is NOT acceptance — it would
  pass a lens wrong by 2^96. Secondary: the wedge-free κ̂ compared to the structural
  ΔQ_v(i_K) profile and the observational interval (P3).
- **Anti-fabrication teeth (review F-MQA6):** the panel-export test (a) recomputes σ² for
  ≥1 sampled epoch independently from the raw E3 events and asserts equality with the
  panel row; (b) re-reads ≥1 sampled SFPM premium from contract state in a second pass;
  (c) derives the υ finite difference from the EXPORTED FILE, never from in-memory values.
- Plank-side deliverables: the fixture + the export test. The estimator is cfmm-gams
  scope, delegated by an issue amendment referencing this spec and the lock requirements.

## Test plan summary (RED first, per increment)

- **L0**: drafted lemma battery green unmodified + the overflow-envelope test. Mutants:
  drop the max (OTM), swap sig2/sig2K, off-by-one on the quotient.
- **L1**: tolerance-zero differentials with rounding-order-pinned oracles; the round-trip
  one-sided inequality; long/short sign test; the Demeterfi price-insensitivity test.
- **L2**: the units table + real-scale golden (entry condition); live-join test; the
  per-observation wedge-exact cross-check with rounding-derived tolerance; the two
  tie-breaker variations.
- **L3**: the pre-registration lock-hash assertion; the two-σ²-regime ordering RED test
  (a NEW claim, not "already demonstrated"); the level acceptance vs ε_level; the three
  anti-fabrication checks.
- Mutation battery per increment, each mutant named; regression gate = recorded baseline
  discipline (touched suites 100%, failure set does not grow; VolRangeWidth's
  seed-dependent latent family stays excluded from the gate).

## Non-goals

- Re-running observational estimation of υ₀ on market data (terminally closed by the
  phase-10 pivot lock; cited, never reopened).
- The GAMS estimator implementation (cfmm-gams repo, delegated with the lock requirements).
- Task #14's sizing math (consumed when it lands, not duplicated).
- VegaAccountMod (#13) wiring — the lens is read-only.
- Any change to the Lean substrate (all cited lemmas are proven; nothing new is assumed).
