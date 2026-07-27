# LEAN_TRACEABILITY.md — vol-instruments markdown ↔ Aristotle-proved Lean

**Master reference: `VOLATILITY_INSTRUMENTS.md`** (plank worktree,
`notes/VOLATILITY_INSTRUMENTS.md`; a copy ships in each Aristotle bundle).
Its claim-by-claim map is §7. The supporting reference documents are the
markdowns in this directory. This file maps
every claim in them to the machine-checked Lean layer
(`lean/vol_markets/*.lean`, mirrored at `JMSBPP/cfmm-lean4-spec`), and fixes
the shared notation. Statuses: **PROVEN** (sorry-free, axiom-clean:
`propext`/`Classical.choice`/`Quot.sound` only), **CORRECTED** (doc claim was
wrong; the true statement is proven), **REFUTED** (counterexample proven),
**OPEN** (not yet formalized).

## 0. Notation dictionary (single source of truth)

Reserved project-wide: **`η` is the pricing-kernel eta** (`model/exp/eta.md`,
`exp/eta.lean`). It is never reused. The fee paper's `η⁰`/`η¹` are mapped to
Latin names below.

| Doc symbol | Lean identifier | Meaning | Defined in |
|---|---|---|---|
| `Q_v^i`, `Q_M^i` | `Qv`, `QM` args | share / money positions | tbd.md |
| `Q_v^Σ`, `Q_M^Σ` | `Qtot`/`QMtot` args | accounting totals | tbd.md |
| `ΔQ_M`, `ΔQ_v` | `dQM`, `deltaShares` | money/share flows | tbd.md · `Flow.deltaShares` |
| `p_risk` | `prisk` | risk price (Q64.96) | tbd.md |
| `d(·,·)` | `distanceBand`, `distanceLinear` | risk distance in `[0,1]` | RISK_ALTERNATIVES.md · `RiskDesign` |
| `h` | `haircut` args | haircut fraction in `[0,1]` | RISK_ALTERNATIVES.md · `RiskDesign` |
| `σ̄` | strike args | position volatility strike | tbd2.md / pos_spec.md |
| `σ(t)` | `σ` | realized volatility (trajectory) | tbd2.md / SCHEDULE.md |
| `Δ_i` | `Δi` | tick spacing | tbd.md / pos_spec.md · `PosSpec.tickPrice`, `GeomProfile` |
| `p(i)` (sqrt-price) | `PosSpec.tickPrice Δi i` | `1.0001^((i/2)·Δ_i)` | pos_spec.md |
| `K_i` (price) | `GeomProfile.priceGrid Δi i` | `1.0001^(i·Δ_i)` = `tickPrice²` | GeomProfile (`priceGrid_eq_tickPrice_sq`) |
| `s_v` | `sv` | skew | pos_spec.md · `PosSpec.skewTick` |
| `L`, `L̄` | `L`, `Lbar` | liquidity, total nominal | tbd2.md · `Flow`, `GeomProfile` |
| `ξ`, `ι` | `ξ`, `ι` | GDF ratio (`ℝ₊∖{1}`), tick count | tbd2.md · `GeomProfile.geomWeight` |
| `ξ*` | — (value `1.0001^(-Δ_i/2)`) | log-contract **liquidity** GDF ratio | GeomProfile (`logContractLiquidity_geometric`) |
| `π(σ̄)`, `π(·,t)` | `Flow.terminalPayoff`, `Flow.trajPayoff` | payoffs | tbd2.md / SCHEDULE.md |
| `x`, `X`, `k`, `w` | same | control `ΔQ_M(t)`, ceiling, slope, width | SCHEDULE.md |
| `f_min`, `f_max` | `FeeSchedule.Params.feeMin/.feeMax` | fee floor / plateau (paper's `η¹` bounds; **not** `η`) | FeeSchedule |
| `σ̄_f` | `FeeSchedule.Params.volStrike` | fee-transition volatility strike; coupling sets `σ̄_f = σ̄` | FeeSchedule |
| `s_f` | `FeeSchedule.Params.steepness` | sigmoid steepness, `> 0` | FeeSchedule |
| `η⁰` (paper) | `cexFee` | CEX effective fee benchmark | FeeSchedule (`fee_lt_cex`) |
| `f_halt` | `fHalt` | prohibitive halt fee (paper's `η¹ = ∞`) | FeeSchedule (`feeHalt`) |
| `premium` | `premium` | risk-price buffer in `[0,1]` | RISK_ALTERNATIVES.md · `RiskDesign.riskPriceBuffered` |

## 1. `tbd.md` — risk-weighted share state space

| Doc claim | Lean | Status |
|---|---|---|
| `d ∈ [0,1] ⟹ Σ Qᵥⁱ·dᵢ = Σ Qᵥⁱ` (admissibility "identity") | `Main.discounted_claim_counterexample` | **REFUTED** (N=1, Qᵥ≡1, d≡0) |
| Corrected bracket `0 ≤ Σ Qᵥⁱ·dᵢ ≤ Σ Qᵥⁱ`, equality iff `d ≡ 1` | `Main.discounted_nonneg`, `discounted_le_total`, `discounted_eq_total_iff`, `discounted_eq_total_iff_pos` | **CORRECTED → PROVEN** |
| Admissible region `ΔQᵥ^Σ ≤ Q_M^Σ/p_risk`, division-free EVM guard | `Main.admissible_iff_mul` (`Δ·p_risk ≤ Q_M^Σ`) | **PROVEN** |
| Post-update state bounds | `Main.admissible_state_bounds` | **PROVEN** |
| `(ΔQ_M, p_risk) → (ΔQ_M, ΔQ_v)` map | `Flow.deltaShares` + `_nonneg`, `_mono`, `deltaShares_admissible_iff` (money ceiling `ΔQ_M ≤ Q_M^Σ`) | **PROVEN** |
| Number-representation design questions | answered in `DESIGN_SPACE.md`, each row backed by the `Main` lemmas above | **PROVEN** (real layer; X96/RAY integer layer OPEN) |

## 2. `RISK_ALTERNATIVES.md` + `risk.md` — d, p_risk, haircut

| Doc claim | Lean | Status |
|---|---|---|
| `risk.md`: collateral value via `price/haircut` | — (singular at `h=0`, wrong monotonicity) | **REFUTED** — do not implement |
| D0 identity weight is the only exact-accounting `d` | `Main.discounted_eq_total_iff_pos` | **PROVEN** |
| D1 two-band weight in `[0,1]`, `=1` when close | `RiskDesign.distanceBand_mem`, `distanceBand_eq_one_of_close` | **PROVEN** |
| D2 clipped linear weight | `RiskDesign.distanceLinear_mem`, `_self`, `_eq_zero_of_far` | **PROVEN** |
| D3 ratio weight | — | OPEN (deliberately: convention-sensitive) |
| P0 `max(spot,TWAP)` conservative | `RiskDesign.riskPriceMax_ge_left/_right`, `riskPriceMax_pos` | **PROVEN** |
| P1 buffered `oracle·(1+premium)` | `RiskDesign.riskPriceBuffered_bounds`, `_pos` | **PROVEN** |
| H0 retained value `amount·oracle·(1-h)` | `RiskDesign.haircutFactor_mem`, `haircutValue_bounds` | **PROVEN** |
| H1 `p_risk = oracle/(1-h)` ≡ `deposit·(1-h)/oracle`, `≥ oracle` | `RiskDesign.issuance_haircut_equiv`, `haircutRiskPrice_ge_oracle`, `_pos` | **PROVEN** |
| X96 clamped weight cannot increase an amount; `1` exact | `RiskDesign.mulX96Down_le`, `mulX96Down_one` | **PROVEN** (integer floor level) |
| H2 tiered haircut governance table | — | OPEN (policy, not math) |

## 3. `pos_spec.md` — position spec `(σ̄, #_σ̄, s_v) → (p(i), p(i_l), p(i_u))`

| Doc claim | Lean | Status |
|---|---|---|
| Skew interpolation `i(σ̄) = s_v·i_l + (1-s_v)·i_u` convex, in `[i_l,i_u]`, gap identities | `PosSpec.skewTick_one/_zero/_mem/_gap_upper/_gap_lower` | **PROVEN** |
| Width identity `Δ_i·#_σ̄ = i_u − i_l` | `PosSpec.width_span` | **PROVEN** |
| `p(i) = 1.0001^((i/2)·Δ_i)` positive, increasing, `p(i_l) ≤ p(i(σ̄)) ≤ p(i_u)` | `PosSpec.tickPrice_pos/_le/_lt/_skew_mem` | **PROVEN** |
| EVM types (`u24/i24/u16/u88`, `VolOrder` builder API, `TickVolatility` X96/WAD converters) | — | OPEN (real layer only) |

## 4. `tbd2.md` + `SCHEDULE.md` — liquidity, payoff, GDF, ΔQ_M schedule

| Doc claim | Lean | Status |
|---|---|---|
| `getLiquidityForAmounts` branches | `Flow.getLiquidity`, `liquidity0/1` + `_nonneg`, `_mono` | **PROVEN** |
| `L = ΔQ_M/(p(i_u) − p(i_l))` (token1 branch) | `Flow.liquidity1_eq_div` | **PROVEN** |
| Terminal payoff `π(σ̄) = L·(p(i_u)−p(i_l)) ≥ 0` | `Flow.terminalPayoff`, `terminalPayoff_nonneg` | **PROVEN** |
| Objective linear in control `x = ΔQ_M` | `Flow.trajPayoff_control` | **PROVEN** |
| Corner/bang-bang optimal rebalancing `ΔQ_M* ∈ {0, X}` | `Flow.schedule_min_high/_low`, `schedule_isLeast` | **PROVEN** (token1 branch; mid-range branch OPEN) |
| Ceiling `ΔQ_M^max = min(Q_M^Σ, Qᵥ^Σ·p_risk/α)` | only `X = Q_M^Σ` formalized | PARTIAL — the `α`-cap term OPEN |
| GDF weights `ξ^i/((1−ξ^ι)/(1−ξ))` sum to `L̄` | `GeomProfile.geomWeight_sum`, `geomLiquidity_sum` | **PROVEN** |
| GDF positivity / concentration / uniform limit | `GeomProfile.geomWeight_pos`, `geomWeight_strictAnti`, `geomWeight_tendsto_uniform` | **PROVEN** |
| GDF payoff decomposition into `Flow.terminalPayoff` | `GeomProfile.geom_terminalPayoff_total`, `_tickPrice` (sqrt-price grid) | **PROVEN** |
| Which `ξ` gives variance-swap exposure | strike-notional `dK/K²` ratio `1.0001^(-Δ_i)`: `varswapWeight_geometric`, `_normalized`; **liquidity** ratio `ξ* = 1.0001^(-Δ_i/2)`: `logContractLiquidity_geometric`; convention bridge `priceGrid_eq_tickPrice_sq` | **PROVEN** — the two ratios differ by a square; use `ξ*` for the liquidity profile. Payoff-level curvature bridge (`ℓ(P) = -2P^{3/2}V''(P)`) OPEN |

## 5. Fee schedule layer (`FeeSchedule.lean` ← arXiv:2508.08152, 2306.09421)

Parametrizes the paper's threshold-type dynamic fee; couples into §2's P1/P2.

| Claim | Lean | Status |
|---|---|---|
| `fee(σ) ∈ [f_min, f_max]`, monotone in `σ`, undercuts `cexFee` | `fee_mem_Icc`, `fee_monotone`, `fee_lt_cex` | **PROVEN** |
| `(σ̄_f, s_f)` carry an `ℝ*⋉ℝ` right action; output affine action ordered | `fee_rescale`, `rescale_id`, `rescale_comp`; `fee_scaleOut`, `scaleOut_id/_comp/_ordered` | **PROVEN** |
| Threshold rule = `s_f → 0⁺` boundary | `feeRaw_tendsto_high/_low` (+ `logistic_*` lemmas) | **PROVEN** |
| Two-point calibration exists and is unique | `feeRaw_interpolate`, `feeRaw_interpolate_unique` | **PROVEN** |
| Optimal parameters exist on compact Θ | `exists_optimal_params` | **PROVEN** (generic EVT interface) |
| Halt regime monotone | `feeHalt_monotone` | **PROVEN** |
| Sigmoid fee is an admissible premium; `p_risk` monotone in `σ(t)` (P1 & P2) | `fee_mem_unit`, `riskPriceBuffered_fee`, `riskPrice_sigmoid_mono`, `riskPriceP2_sigmoid_mono` | **PROVEN** (typed against `RiskDesign`) |

## 6. Not covered by any Lean module yet

- `exposure.md` — `VegaExposure`, `N_v = ΔM/p_vol(σ̄)`: the `p_vol` map should
  go through `VolInstrument.priceEta` (σ → tick → Q64.96). **OPEN.**
- `pos_spec.md` EVM type layer (u24/u16/u88 builders). **OPEN.**
- Integer/rounding quantification beyond `mulX96Down_*` (accumulated floor
  error over N positions). **OPEN.**
- The abstract `𝓖_φ` group beyond the `probOr` monoid core, and the MEV
  section (empty in the doc). **OPEN.**  (`λ_FLAIR` is now formalized and
  solved — see §7 / `FlairOptimization.lean`; the continuum path-integral
  form remains the limit of the proven discrete functional.)
- `Panoptic.lean`/`Upsilon.lean` trace to the phase docs under
  `.planning/phases/08-*` and `09-*` and to §7 below.

## 7. `VOLATILITY_INSTRUMENTS.md` — master instrument doc (module `VolInstrument.lean` + bridges)

Additional notation for this doc: `p_(η,Δ_i)(i) = λ^((i/2)·Δ_i·η)` →
`VolInstrument.priceEta η Δi i` (η = pricing-kernel eta, ONLY use of η);
`Θ_φ = {γ, φ̄, β, α}` → `multiFee` arguments (`γ β α : ℕ → ℝ`, `φbar`);
`⊗_φ` → `probOr`; `Π` → `logPortfolio`/`variancePortfolio`;
`ΔQ_M^L`/`ΔQ_X^L` → `deltaQM`/`deltaQX`. `FeeSchedule`'s `s_f = 1/γ`.

| Doc claim | Lean | Status |
|---|---|---|
| `π^σ = ΔQ_v·(σ²(i(t)) − σ²_K)⁺`, `ΔQ_v` as difference quotient | `Panoptic.volOptionPayoff`, `deltaQv_of_payoff` | **PROVEN** (phase 08) |
| `p_{π^σ} = p₀ + α₁·p_call + α₂·p_put` | `Panoptic.replicationPrice` + `_call_only`, `_shift` | **PROVEN** |
| `p_call\|put = ∫θ dt` (discrete) and θ closed form | `Panoptic.streamingPremium`, `theta_atm_closed_form`, `centralBinom_isEquivalent` | **PROVEN** (ATM lattice form) |
| `υ ≡ Δπ/Δσ²` lives in the `ΔQ_v` slot | `Upsilon.upsilon`, `upsilon_volOption`, `upsilon_eq_deltaShares_slot` | **PROVEN** |
| υ econometric API `υ(t) = υ(ī) + (Δυ/Δi)·i(t)`, ATM/OTM decay | `Upsilon.upsilonTickSlope`, `ATMOTMNullHypothesis`, `exp_family_witnesses_ATMOTM` | **PROVEN** (statement + exp-family witness; estimation = phase 09) |
| Pricing geometry `p_(η,Δ_i)`, `Θ_p = {η, Δ_i}` | `VolInstrument.priceEta` + `_pos`, `_strictMono` (η·Δi > 0), `priceEta_one` (= `tickPrice` at η = 1) | **PROVEN** |
| `ΔQ_M^L`, `ΔQ_X^L` on `(X, M)` | `deltaQM`, `deltaQX`, `deltaQM_token0`, `_nonneg` (needs `Δi ≥ 0` too — Aristotle-caught) | **CORRECTED → PROVEN** |
| Cumulatives `Q_M^L`, `Q_X^L` + inverse cumulatives | `cumulativeQM/QX` + `_succ`, `_monotone`, `_const` telescoping, `exists_least_reaching` | **PROVEN** |
| Region `φ(i_K; ΔQ, L)` | `flowRegion`, `tickFlowRegion` + `_sq`, `_mono_left/right` | **PROVEN** |
| Multi-sigmoid `φ(σ)`, `Θ_φ = {γ, φ̄, β, α}` | `utilization` + `_mem`, `multiFee` + `_bounds`, `_monotone` | **PROVEN** |
| `FeeSchedule` = single-term case | `multiFee_single_bridge` (`s_f = 1/γ`) | **PROVEN** |
| `⊗_φ = 1−(1−φ_M)(1−φ_X)` abelian monoid, `[0,1]` closure | `probOr` + `_eq`, `_comm`, `_assoc`, `_zero`, `zero_probOr`, `_mem_Icc`, `_mono` | **PROVEN** (max/min semilattice rows are Mathlib instances) |
| `λ ≡ λ_M + λ_X` ↔ `⊗_φ` | `probOr_hazard` (`φ = 1 − e^{−λ}`) | **PROVEN** |
| Demeterfi `Π = (p−p*)/p* − log(p/p*)` ≥ 0, `Π(p*) = 0` | `logPortfolio` + `_nonneg`, `_atm` | **PROVEN** |
| `υ(Π + σ²t/2) = t/2` price-independent; `Id_{N_σ} = 2/t` unit vega | `variancePortfolio_upsilon`, `_unit_upsilon` (via `Upsilon.upsilon`) | **PROVEN** |
| `π^σ = (σ²_R − σ²_K)⁺` | `realizedVariancePayoff_bridge` (= `Panoptic.volOptionPayoff 1`) | **PROVEN** |
| Strike weights `ℓ(ξ,ι;i_K)` | `strikeWeight_bridge` (= `GeomProfile.geomWeight`) | **PROVEN** |
| `λ_FLAIR` functional (discrete) | `FlairOptimization.flairHazard`, `flairMulti`, `capitalDenominator_pos` | **PROVEN** |
| `∃ Θ_λ ⊂ Θ_φ, sup λ_FLAIR` — identification | `flairMulti_affine` (`λ = φ̄·W + u·Σ α_j·W_j`), `_mono_phibar` (strict), `_mono_alpha`, `_mono_u`, `_anti_beta`, `W_j_le_W`, `W_j_lt_W` ⟹ `Θ_λ = {φ̄, α, u}`; `(β, γ)` reallocation-only | **PROVEN** |
| `sup λ_FLAIR` — solved | `flairMulti_le_corner` (uniform bound `(φ̄max + umax·Σαmax)·W`), `_corner_attained_levels` (bang-bang), `_saturation_limit` (`β → −∞` Tendsto, sup not attained), `_strict_below_saturation`, `_exists_max_compact`, `Theta_lambda_identification` | **PROVEN** (no demand elasticity in this functional — caveat in module docstring) |
| `𝓖_φ` beyond the monoid core, MEV section | — | **OPEN** (see §6) |
