# Lean ↔ Haskell ↔ spec cross-walk (Panoptic υ identification)

**Purpose.** The "formal witness" claim of Phase 9 is that a fitted κ̂ > 0 makes the
estimated exponential-moneyness vega profile a witness of the Lean conjecture
`Upsilon.ATMOTMNullHypothesis`. That claim is only as good as the fidelity between
the Haskell estimator and the Lean definitions. This table is the auditable
evidence: every load-bearing object appears in all three registers — the Lean
formalization (`lean/vol_markets/*.lean`), the Haskell estimator
(`econometrics/src/…`), and the binding econometric spec
(`notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md`).

Keep this table in sync whenever any of the three sides changes.

| Lean name (`lean/vol_markets/…`) | Haskell name (`econometrics/src/…`) | spec § | Meaning / fidelity note |
|---|---|---|---|
| `Upsilon.upsilon` (vega family `υfun i = υ₀·exp(−κ·Δi·\|i−iK\|)`) | `Model.Upsilon.model [b0,u0,k] (d,s2) = b0 + u0*exp(negate k*d)*s2` | §4.3 | The estimating equation VERBATIM. Lean's `υ₀·exp(−κ·Δi·\|i−iK\|)` is the multiplicative vega; the Haskell `model` multiplies it by σ̂² and adds β₀ to give π (spec §4.3 `π = β₀ + υ₀·exp(−κ·\|i_K−i_t\|)·σ̂²`). |
| `Upsilon.upsilonTickSlope υfun Δi i = (υfun (i+1) − υfun i)/Δi` | discrete forward slope used by the ATM/κ>0 test (built in 09-08 `Model.Specification`) | §5 (test 2) | The forward-difference tick-slope whose \|·\| peaks at the money. The Haskell κ>0 Wald test is the econometric twin of asserting this slope is maximal at `iK`. |
| `\|(i:ℝ) − (iK:ℝ)\|` (inside `Upsilon.ATMOTMNullHypothesis`) | `Model.Upsilon.moneyness iK it = abs (fromIntegral (iK − it))` | §4.3 | The tick-grid moneyness distance `d = \|i_K − i_t\|`. Same absolute-tick-count metric on both sides. `Model.Upsilon.signedMoneyness` retains the sign for the κ⁺/κ⁻ split. |
| `PosSpec.lam = 1.0001`, `PosSpec.tickPrice Δi i = lam^((i/2)·Δi)` | `Model.Upsilon.tickBase = 1.0001`; `Panel.Build.strikeToTick = round (log K / log 1.0001)` | §2.4 | The λ = 1.0001 tick/price grid — the sole technological primitive. i_K = log_λ K is the strike tick; the distance lives on this grid. `tickBase` is annotated `-- mirrors PosSpec.lam`. |
| `Upsilon.ATMOTMNullHypothesis υfun Δi iK c` (the κ>0 `Prop`, conjunct 1 `0 < c`) | the one-sided κ̂ > 0 Wald/t test (`Model.Specification`, 09-08) fitting `Model.NLS.fitGSL` | §5 (test 2) | H₀: κ = 0 (flat) vs H₁: κ > 0 (ATM peak, OTM exp decay). Lean pins the statement (no proof); the Haskell test evaluates it on data. `c = κ·Δi` in the Lean witness. |
| `Upsilon.exp_family_witnesses_ATMOTM` (bridging lemma, one `sorry` → Aristotle 09-06) | `Model.NLS.fitGSL` producing κ̂ > 0 (with `Model.Upsilon.model` as the fitted family) | §4.4 | The exp family with κ > 0 witnesses `ATMOTMNullHypothesis` at `c = κ·Δi`. A fitted κ̂ > 0 instantiates the witness — hence the byte-for-byte fidelity requirement above. |
| `Upsilon.upsilon_volOption` / `upsilon_eq_deltaShares_slot` (υ = ΔQ_v slot, proved) | — (analytical, no estimator counterpart) | §1 | Dimensional bridge that υ ≡ Δπ/Δσ² occupies the ΔQ_v slot. Grounds why π is regressed on σ̂² at all; no direct Haskell object. |

## EIV remedy (spec §4.3) — not a Lean object, recorded for completeness

| Object | Haskell name | spec § | Note |
|---|---|---|---|
| Second-window variance instrument σ̃²_t | `Panel.Variance.instrumentVariance` (`Obs.obsSigma2Instr`); consumed by `Model.EIV.ivFit` | §4.3 | Two-noisy-measures IV: σ̂²_t is EIV-mismeasured (M1 → attenuation on υ̂₀); σ̃²_t (disjoint even-swap sub-window) instruments it. Hand-rolled; no Lean twin. |

## Phase 10 measurement wedge — Panoptic premium vs. bare streaming premium

**The object Phase 10 estimated is not the object Lean models.** They differ by Panoptic's
utilization multiplier. This section records that wedge rather than papering over it, because
the witness claim above rests on the fidelity of the correspondence, and an undocumented
wedge would quietly weaken the very thing this file exists to support.

| Lean object (`lean/vol_markets/…`) | Haskell object (`econometrics/src/…`) | spec § | Fidelity note |
|---|---|---|---|
| `Panoptic.streamingPremium θ Δt N = ∑_{j<N} θ(j)·Δt` — the LP fee-revenue identity (`Δ feeGrowthInside · L`) per unit liquidity, with `θ` the lattice dt-leg `Panoptic.latticeTheta` read at the strike-tick centre column (`Panoptic.thetaAtm`). **NO multiplier.** | `Panoptic.Premium.premiumWei` on deltas of `Panoptic.Sfpm.getAccountPremium`, which **already includes** the utilization multiplier — it is applied inside the contract's X64 accumulator, upstream of anything this repo computes | §4.3 | **WEDGE — the one imperfect row in this table.** The estimated `π_it` is Panoptic's premium, not the bare fee-revenue identity Lean models. Factor: `(1 + ν·R/N)` on long legs, `(1 + ν·R²/(N·T))` on short legs, with `ν = 1/VEGOID = 1/8 = 0.125`, `R` = removed (long) liquidity, `N` = net liquidity, `T = N + R`. Exactly `1` when `R = 0`. **`1 + ν = 1.125` bounds it only when `R ≤ N`, which is FALSE on this market** — see the measured distribution below. `Panoptic.Premium.multiplierWedge` exists solely to REPORT the factor; it is never applied (that would double-count). |

Sources: `SemiFungiblePositionManagerV4._getPremiaDeltas` L1129-1214; `RiskEngine.sol` L104
(`uint8 public constant VEGOID = 8`), confirmed against the live RiskEngine at
`0x8bbCE8B1eB64118CFE6c1eAb0afe13b80EA41481`. The bare identity is
`spec/refs/cfmm-discrete/STREAMING_PREMIUM.md`.

### The MEASURED distribution (not the bound)

Computed by `Panoptic.Premium.multiplierWedge` over all **8,910** rows of
`notes/structural-econometrcics/data/premium-accumulators.csv` — the accumulator readings that
back the estimation panel — using each row's own `removed_liquidity`, `net_liquidity` and
`is_long`. Exact rational arithmetic; percentiles by linear interpolation on the sorted values.
54 rows carry `net_liquidity = 0` (`ChunkEmpty`); all 54 also carry `R = 0`, so the `R = 0`
branch returns `1` and no division by zero arises.

| statistic | value |
|---|---|
| N (readings) | 8910 |
| min | 1.000000 |
| p25 | 1.000000 |
| **median** | **1.112500** |
| mean | 1.117256 |
| p75 | 1.204167 |
| **p90** | **1.291667** |
| max | 1.291667 |
| share with `R = 0` (**wedge exactly 1**) | 3467 / 8910 = 0.389113 |
| long readings (n = 2839): median / max | 1.222222 / 1.291667 |
| short readings (n = 6071): median / max | 1.000000 / 1.204167 |
| implied max `R/N` on long readings, `8·(wedge − 1)` | 2.333333 |
| `1 + ν`, the figure the phase context quoted as the bound | 1.125 |

**The measured wedge median is 1.112500 — the wedge BINDS, and it is not near-degenerate at 1.**
Only 38.9% of readings sit at exactly 1; the typical reading carries ~11.25% more premium than
the bare fee-revenue quantity. **The measured maximum EXCEEDS 1.125**: `1 + ν·R/N ≤ 1 + ν`
requires `R ≤ N`, and here `R/N` reaches 2.333333. The short branch likewise passes `1 + ν`
once `R ≳ 1.62·N`. Neither branch is bounded by 1.125 in general — cite the measured figures,
not that number. (The same figures appear in `2026-07-20-upsilon-estimates-v2.md` §7 and
`2026-07-27-upsilon-estimates-v3.md` §8; median/min/max and the long/short maxima reproduce
exactly. p25, p75, p90 and the mean are computed here for the first time, by the method stated
above.)

### Consequence for the witness claim — level vs. shape

`Upsilon.exp_family_witnesses_ATMOTM` concerns the **shape** of the vega profile
(`υ₀·exp(−κ·Δi·|i − i_K|)`). The multiplier enters as a positive scale factor on π. So:

- **Level.** `υ̂₀` is unambiguously the vega of **Panoptic's** premium, not of the bare
  fee-revenue quantity `Panoptic.streamingPremium` models. Any comparison of `υ̂₀` against a
  Lean `streamingPremium` quantity must carry a factor whose measured centre is 1.1125 and
  whose measured range is [1.000000, 1.291667]. This is a documented reinterpretation of what
  `υ₀` denotes, not a correction to be applied.
- **Shape.** The wedge contaminates `κ̂` only to the extent that `R/N` co-varies with
  moneyness. **It is not demonstrably negligible, and it is flagged as a threat to validity.**
  Using each reading's own chunk centre `(tick_lower + tick_upper)/2` against its `at_tick` as a
  chunk-level moneyness proxy `d`, over the same 8,910 readings: Pearson `corr(wedge, d) =
  0.143545`, Spearman `0.122141`, and the per-quintile median wedge is **non-monotone** —
  1.125000, 1.000000, 1.000000, 1.112500, 1.187500 across `d`-quintiles with cut points
  266 / 554 / 909 / 1089 ticks. Small, positive, and not zero.

  **Direction, stated once and not over-read.** A wedge rising in `d` inflates far-OTM premia
  relative to ATM, which flattens the observed decay and therefore biases `κ̂` **towards zero**.
  The Phase-10 rejection of H₀: κ = 0 (p = 7.308348e-3 on the terminal run) is, under this
  proxy, conservative with respect to this contamination rather than manufactured by it. That
  is a directional argument on a proxy, **not** a bias correction and not a bound: the proxy is
  chunk-level while the panel's moneyness is position-level `|i_K − i_t|`, and no attempt was
  made to convert it into an adjustment to `κ̂`.

### Witness status — TERMINAL as of Phase 10 plan 10-10

| item | status |
|---|---|
| `Upsilon.exp_family_witnesses_ATMOTM` | **PROVED**, sorry-free, `#print axioms` = `[propext, Classical.choice, Quot.sound]`. Untouched by Phase 10 (no Lean file was modified, no Aristotle task run). |
| `hk : 0 < κ` | **STATISTICALLY SUPPORTED.** `κ̂ = 3.041754e-2`, clustered CR0 SE 1.245733e-2, one-sided p = 7.308348e-3 — H₀ of a flat vega profile REJECTS, under BOTH LHS constructions (run 1 p = 9.534719e-3). |
| `hu : 0 < υ₀` | **SIGN ONLY — NOT supported.** `υ̂₀ = 0.106332`, clustered SE 0.100998, 95% CI [−9.162517e-2, 0.304289] contains zero, p = 0.146215. |
| `hΔ : 0 < Δi` | SATISFIED (`Δi = 10`, the pool tickSpacing). |
| **The witness** | **DOES NOT OBTAIN.** The theorem takes `hu` AND `hk`; instantiating it at a `υ₀` the data cannot distinguish from zero would assert more than the data supports. |
| `Upsilon.ATMOTMNullHypothesis` | **CONJECTURE OPEN.** Nothing in Phase 10 bears on the theorem's correctness — only on whether this market's data instantiates it, and it does not. |

The pre-committed stopping rule returned `UNINFORMATIVE` under both LHS constructions
(half-widths 1.479533e-1 and 1.979569e-1 against the never-moved 6.2e-5 bar): **this market
cannot identify υ.** The binding constraint is the 55-cluster ceiling, not the LHS.

### Convention note — the seller-side sign normalization

Recorded for any future consumer of these panels, because it is a silent trap.

`Panel.Build.premiumUsd` applies `sign = if isLong then -1 else 1`, normalizing every spell to
the **seller side**. The stated rationale is that otherwise *"the same vega would enter the
regression with two opposite signs and cancel"* — long and short legs of the same vega must
enter with ONE sign or they attenuate each other. 10-09's `assembleEpochPanel` instead kept the
protocol's own emitted sign, which left 2,280 / 6,760 rows (33.7%, 8 of 55 tokenIds)
opposite-signed. That was found **after** run 1's verdict was computed, was frozen and escalated
rather than fixed in place, and was repaired only under a hashed pivot lock as run 2's single
authorised change.

**The convention, stated plainly:** in `panel-epoch.csv` the `premium_wei` column is the
protocol's own sign (canonical — summing it over a tokenId reproduces that spell's
gate-validated `recon_wei` exactly). The **regression LHS** requires the seller-side
normalization, applied by the `--seller-side-normalize` flag downstream of the variance join.
`estimation-panel-v2.csv` is the un-normalized arm; `estimation-panel-v3.csv` is the normalized
one. Neither is wrong; they answer to different conventions, and mixing them silently is the
defect this note exists to prevent.

## Fidelity checklist (grep-able anchors)

- `Model.Upsilon.model` body is `b0 + u0 * exp (negate k * d) * s2` — matches spec §4.3 term-for-term.
- `Model.Upsilon.tickBase == 1.0001` and `Panel.Build.strikeToTick` uses `log 1.0001` — both mirror `PosSpec.lam`.
- `Model.Upsilon.moneyness` is `abs (fromIntegral (iK − it))` — the `|i_K − i_t|` distance.
- The bridging lemma's fitted family is exactly `Model.Upsilon.model`'s vega part `υ₀·exp(−κ·d)`.
- `Panoptic.Premium.multiplierWedge` implements `1 + ν·R/N` (long) and `1 + ν·R²/(N·T)` (short)
  with `nu = 1 % 8` and the `removedLiq == 0 ⇒ 1` branch first — the Panoptic-vs-Lean wedge,
  REPORTED and never applied.
- `Panoptic.Sfpm.vegoidConst == 8`, matching `RiskEngine.VEGOID`; it is the value written into
  slot 7 of `getAccountPremiumCalldata` and echoed in the accumulator artifact's banner.
- `Panoptic.Premium.premiumWei` divides by `2 ^ (64 :: Int)` — the X64 accumulator scale, NOT
  `2^128` (feeGrowth) and NOT `2^96` (sqrtPrice) — matching `PanopticPool._getPremia`
  L2272-2298, and negates long legs (L2296-2298).
- `Panoptic.Premium.decomposePremium`, not `telescope`, is what the panel is built from:
  `sum (decomposePremium [a0..aN] L s) == premiumWei aN a0 L s` holds for ANY `L`, whereas
  per-interval flooring undershoots by up to `N − 1` wei.
- `Panel.Build.premiumUsd` carries `sign = if isLong then -1 else 1` — the seller-side
  normalization the regression LHS requires (see the convention note above).
