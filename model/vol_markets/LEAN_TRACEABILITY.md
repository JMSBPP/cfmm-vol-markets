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

Three collisions with the MEV anchor (Milionis–Moallemi–Roughgarden,
arXiv:2305.14604v2) are resolved the same way, doc-side, and the resolutions are
binding: the anchor's fee `γ` is this document's `φ` (this document's `γ_j` stays
the sigmoid steepness); the anchor's Poisson block rate `λ` is written through its
own primitive `Δt ≜ λ⁻¹`, because this document's `λ` is a hazard rate; and the
anchor's composite `η ≜ γ√(2λ)/σ` is **deliberately never named** — the
root-block-rate factor is written `√(2/Δt)` throughout and no abbreviation is
introduced. Separately, `λ_ARB` and `λ_MEV` are **not interchangeable**: `λ_ARB`
is the arbitrage channel and a SUMMAND of `λ_MEV`, and no row below may substitute
one for the other.

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
| `φ`, `φ̄` | `VolInstrument.multiFee` output, `φbar` | the fee and its level ceiling (anchor's `γ`); `γ_j` remains the sigmoid steepness | MEV addendum M0 |
| `Δt` | `Δt` args | mean interblock time = the batch cadence; carries the anchor's block rate as `Δt ≜ λ⁻¹` | MEV addendum M0 · `MevOptimization.ptrade` |
| `ℙ_{Δ_ARB}` (formerly `P_trade`; probability convention `ℙ_{event}`, user 2026-07-31) | `MevOptimization.ptrade` | `σ/(σ + φ√(2/Δt))` — long-run fraction of blocks carrying a profitable arbitrage | MEV addendum M0/M1 |
| `ℙ_{L_JIT}` | `πJ` args in `JitLiquidity` | JIT-arrival probability (CJZ's `π`) | JIT addendum J0 |
| `λ̃_JIT` (tilde = incidence operator, not hazard) | `JitLiquidity` incidence lemmas | event-time incidence operator on `(λ_FLAIR, λ_ARB)` | JIT section J7 |
| `κ_{φ}` (curvature; subscript = quote function `\varphi`) | `curvIndex`, `kphiS`/`kphiI` binders | curvature index `1 − λ^(−Δi²η/2)`, Capponi's `k` | ETA block E0/E1 |
| `a_t` | the `a` argument of `MevOptimization.mevHazard` | per-step arbitrage-opportunity weight (leading-order LVR × `Δt`) — **not** `FlairOptimization.flairHazard`'s traded-flow `w_t` | MEV addendum M0/M3 |
| `λ_ARB` | `MevOptimization.mevHazard`, `MevOptimization.mevMulti` | the ARBITRAGE channel — every identification and infimum row of §7 is about this object | MEV addendum M3 |
| `λ_MEV` | `MevJointProgram.mevTotal` | the TOTAL, `λ_ARB ⊕ λ_sandwich` (plain hazard addition); equals `λ_ARB` exactly when uniform batch clearing nulls the sandwich channel | MEV addendum M7 |
| `τ`, `τ(k)` | `MevJointProgram.mevNet`, `MevJointProgram.taxFraction` | LP-rebate / auction-tax fraction, `k/(k+1)` with `k` free — a protocol parameter **outside** `Θ_φ` | MEV addendum M7(i) |

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
- The abstract `𝓖_φ` group beyond the `probOr` monoid core. **OPEN**, and it
  stays open regardless of the MEV work below. (`λ_FLAIR` is formalized and
  solved — see §7 / `FlairOptimization.lean`; the continuum path-integral
  form remains the limit of the proven discrete functional.)
- The MEV layer is **no longer unformalized**: `λ_ARB` and `λ_MEV` are proved in
  `MevOptimization.lean` and `MevJointProgram.lean` (§7). What remains **OPEN**
  there, named precisely rather than as a blanket:
  (a) the **continuum path-integral** form of `λ_ARB` — the discrete functional is
  the deliverable, exactly as for `λ_FLAIR`, and the continuum object is its limit;
  (b) the demand-elasticity / optimal-fee **equilibrium** layer, which belongs to
  `FeeSchedule` and whose exact missing term is the anchor's section 7.3 eq. (27),
  `E[delta-hedged LP P&L] = E[NT_FEE] − E[ARB]` — so every corner solution in §7 is
  a property of the formalized objective, not a market-equilibrium claim;
  (c) the anchor's **Theorem 3 / Theorem 4 asymptotics themselves**, quoted in block
  M2 but formalized nowhere — `arb_add_fee_eq_lvr` is a bridge identity, not those
  theorems;
  (d) the **exact Corollary-2 CPMM kernel** of block M3(ii) (the optional T19 object
  ARBoverV_exact was omitted), which is the only carrier of the `σ²·Δt < 8` guard;
  (e) the σ-VARYING constrained comparison **restricted to `Θ_φ`-reachable
  schedules** — the general schedule-level claim is REFUTED
  (`mev_ge_flat_under_flair_budget_false`), but the isotone sub-family that `Θ_φ`
  actually reaches is not settled by that counterexample.
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
| υ econometric API `υ(t) = υ(ī) + (Δυ/Δi)·i(t)`, ATM/OTM decay | `Upsilon.upsilonTickSlope`, `ATMOTMNullHypothesis`, `exp_family_witnesses_ATMOTM` | **PROVEN** (statement + exp-family witness) |
| The doc's ECONOMETRIC identification `Q_M = Q_M(υ=0) + υ(t)σ²` — ESTIMATED on Base (phases 09–10): `υ̂₀ = 2.27e-9` (ph.9), `0.036` SE `0.075` / `0.106` SE `0.101` (ph.10, LHS rebuilt from chain state, 6,760 obs) — both UNINFORMATIVE vs the `6.2e-5` bar | — (empirical, not formalizable) | **CLOSED — υ NOT IDENTIFIED** ("this market cannot identify υ", terminal 2026-07-27; observational estimation never reopened). Doc annotated 2026-07-31 |
| What survived that closure: `κ̂ ≈ 0.031` rejects the flat-vega-profile null ×2 (`p = 9.5e-3, 7.3e-3`) — decay EXISTS, point unvalidated; `multiplierWedge` measured (med 1.1125, p90 1.2917, max `R/N` 2.33) | `Upsilon.ATMOTMNullHypothesis` (the null the data rejects) | **PROVEN** (statement) / **MEASURED** (κ̂, wedge) — the 1.125 wedge "bound" is **REFUTED** by max 2.33 |
| Replacement route: model-implied `ΔQ_v` from position state, validity via wedge-exact cross-check + rig level test | `volOptionPayoff`, `deltaQv_of_payoff`, `variancePortfolio_upsilon` | **PROVEN** (the lens primitives); `volStrike` units contradiction (MASKED, consumed as Q64.96 sqrt-price) is the blocking trap |
| Pricing geometry `p_(η,Δ_i)`, `Θ_p = {η, Δ_i}` | `VolInstrument.priceEta` + `_pos`, `_strictMono` (η·Δi > 0), `priceEta_one` (= `tickPrice` at η = 1) | **PROVEN** |
| `ΔQ_M^L`, `ΔQ_X^L` on `(X, M)` | `deltaQM`, `deltaQX`, `deltaQM_token0`, `_nonneg` (needs `Δi ≥ 0` too — Aristotle-caught) | **CORRECTED → PROVEN** |
| Cumulatives `Q_M^L`, `Q_X^L` + inverse cumulatives | `cumulativeQM/QX` + `_succ`, `_monotone`, `_const` telescoping, `exists_least_reaching` | **PROVEN** |
| Region `φ(i_K; ΔQ, L)` | `flowRegion`, `tickFlowRegion` + `_sq`, `_mono_left/right` | **PROVEN** |
| Multi-sigmoid `φ(σ)`, `Θ_φ = {γ, φ̄, β, α}`; second factor `α_R/(1+exp(γ_R(β_R − x)))`, `x = φ(i_K;ΔQ,0)/φ(i_K;0,L)` | `sigmoidR` + `_mem` (unnamed in the doc; identifier from its subscript-R parameters — no interpretive naming), `multiFee` + `_bounds`, `_monotone` | **PROVEN** |
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
| `𝓖_φ` beyond the `probOr` monoid core | — | **OPEN** (see §6) |

### 7.1 `### MEV` — the `λ_ARB` kernel, its infimum, and the `λ_MEV` aggregate

Blocks M0–M8 of the `### MEV` section (proposal copy:
`VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md`), anchored on Milionis–Moallemi–Roughgarden
arXiv:2305.14604v2. Modules: `MevOptimization.lean` (bundle A, run `cb371ee5`) and
`MevJointProgram.lean` (bundle B, run `19f777ab`). Notation per §0: the rows below are
about `λ_ARB` unless they name `mevTotal`.

| Doc claim | Lean | Status |
|---|---|---|
| M1 `P_trade(φ,σ,Δt) = σ/(σ + φ√(2/Δt))` with all seven asserted properties: range `(0,1]`, `=1 ⟺ φ=0`, strictly antitone in `φ`, **strictly convex** in `φ`, isotone in `Δt` and in `σ`, `→ 0` as `φ → ∞` | `MevOptimization.ptrade`; `ptrade_mem_Ioc`, `ptrade_eq_one_iff`, `ptrade_strictAntiOn`, `ptrade_strictConvexOn` (+ its named weakening `ptrade_convexOn`), `ptrade_monotoneOn_dt`, `ptrade_monotoneOn_sigma`, `ptrade_tendsto_atTop` | **PROVEN** — both strict forms returned strict; neither was downgraded |
| M2 the MMR split `ARB + FEE ≈ LVR` | `MevOptimization.arb_add_fee_eq_lvr` — a **bridge identity** and nothing more: the hypothesis-free ring **tautology** `x·p + x·(1−p) = x`, which lets the anchor's Theorem 3 / Theorem 4 split be *written* in Lean notation. It is **NOT a formalization of Theorem 3/4**, which are fast-block small-fee asymptotic approximations and are formalized nowhere in this phase (§6(c)) | **PROVEN** (as the identity only) |
| M3 discrete `λ_ARB = Σ_{t<T} P_trade(φ(σ_t),σ_t,Δt)·a_t/D_t`, over the SAME `multiFee` parameter space and the SAME denominator `D_t` as `flairHazard` (commensurable by construction); CPMM weight `a_t = (σ_t²/8)·V_t·Δt` | `MevOptimization.mevHazard`, `mevMulti`, `mevMulti_nonneg`, `mevWeight_cpmm_pos` (the `·Δt` factor is carried; the `σ²Δt < 8` guard correctly NOT attached at this tier) | **PROVEN** |
| M3(ii) the exact Corollary-2 CPMM kernel — the only object carrying `σ_t²·Δt < 8` | — (optional T19 omitted; no carrier anywhere in the repo) | **OPEN** — deliberately optional, non-blocking |
| M4 identification: antitone in `φ̄` (strict), in each `α_j` and in `u`; isotone in each `β_j` ⟹ `Θ_{λ_ARB} = {φ̄, α, u}`. There is **no affine** identification analogous to `flairMulti_affine` — `ptrade` is not affine, so level and shape do not separate and M5's bound is a path SUM, not a scalar × path weight | `MevOptimization.mevMulti_anti_phibar` (strict), `mevMulti_anti_alpha`, `mevMulti_anti_u`, `mevMulti_mono_beta`, `Theta_lambdaMEV_identification` | **PROVEN** — and the **no affine** finding corrects the naive FLAIR-mirror expectation (the doc itself already records it); a second place the mirror breaks, alongside M5's admissibility constraint |
| M5 the infimum program, solved: path-SUM lower bound at the fee ceiling; bang-bang attainment at the level-corner top for fixed shape; `β_j → −∞` saturation as a boundary value that is NOT a minimum; a STRICT gap at every finite `β`; a minimizer on any nonempty admissible compact box; that minimizer strictly exceeds the displayed bound | `MevOptimization.mevMulti_ge_corner`, `mevMulti_corner_attained_levels`, `mevMulti_saturation_limit`, `mevMulti_strict_above_saturation`, `mevMulti_exists_min_compact` (`ContinuousOn` PROVED, not assumed), `mevMulti_min_gt_corner` (at `u = uMax`) | **CORRECTED → PROVEN** — the saturation limit as specified was FALSE: without `0 ≤ φ̄max + umax·αmax0` the limiting fee lands on `ptrade`'s negative-fee pole. The same pole forces the admissibility constraint on the compact-box existence statement |
| M6a the DEGENERACY of the unconstrained joint program: one admissible point simultaneously maximizes `λ_FLAIR` and minimizes `λ_ARB` in the level block; both objectives saturate along the same direction `β_j → −∞`; and no scalarization `κ ≥ 0` repairs it | `MevJointProgram.joint_corner_degeneracy`, `joint_beta_degeneracy`, `joint_scalarization_degeneracy` | **PROVEN** — and the result **is** the degenerate one: unconstrained there is NO trade-off over `Θ_φ` and the shape block `(β, γ)` is NOT essential. The phase brief's "the shape block becomes essential" expectation is thereby REFUTED, machine-checked |
| M6b, budget half: a fixed FLAIR income pins the mean fee `B/W` and leaves the path shape free; the schedule ↔ path carriers agree definitionally | `MevJointProgram.flair_budget_pins_mean_fee`, `flair_budget_mean`, `flairPath`, `mevPath`, `flairPath_schedule`, `mevPath_schedule`, `flairPath_sum`, `flairPath_budget_mean` | **PROVEN** |
| M6b, constant-σ half: at `σ_t ≡ σ_0`, over arbitrary nonnegative fee PATHS at equal FLAIR income, the FLAT path minimizes `λ_ARB`, strictly so for any path non-constant on the positive-weight steps | `MevJointProgram.mev_ge_flat_under_flair_budget_const_sigma`, `mev_gt_flat_under_flair_budget_const_sigma` (consumes `ptrade_strictConvexOn`, the strict form) | **PROVEN** — at the PATH level and at CONSTANT volatility only; the aligned-measure hypothesis `a ≡ w` is imposed by substitution and is strong |
| M6b, general σ-VARYING **schedule**-level claim (`φfun : ℝ → ℝ` arbitrary subject only to `0 ≤ φfun(σ_t)`): "the flat path is at most the tilted path" | `MevJointProgram.mev_ge_flat_under_flair_budget_false` — a machine-checked negation. Witness `T=2`, `Δt=2`, `B=2`, `σ=(1,10)`, unit `w`/`D`, evaluated fees `(2,0)`, flat fee `1`; recomputed independently in exact rationals: flat `1/2 + 10/11 = 31/22 ≈ 1.4091` vs tilted `1/3 + 1 = 4/3 ≈ 1.3333`, so the flat path is STRICTLY WORSE | **REFUTED** — block M6b had labelled this OPEN; it is FALSE. With `σ_t` varying the summands are different convex functions and ordinary Jensen never applies |
| M6b restricted to the `Θ_φ`-reachable sub-family with σ varying | — the refutation above does not settle it: its witness schedule is σ-DECREASING, whereas every `Θ_φ`-reachable schedule is isotone (`VolInstrument.multiFee_monotone`). A second refutation carrying an explicit `multiFee` witness is the named follow-up; executor float numerics point the same way and are **not** machine-checked | **OPEN** |
| M7 the aggregate `λ_MEV := λ_ARB ⊕ λ_sandwich`, `⊕` being hazard-side (plain) addition, with the `⊗_φ` correspondence held separate; reduction `λ_sandwich = 0 ⟹ λ_MEV = λ_ARB` | `MevJointProgram.mevTotal` (`:= lamARB + lamSand`, plain addition), `mevTotal_eq_arb_of_sandwich_zero`, `mevTotal_mevMulti_eq_of_sandwich_zero`, `mevTotal_probOr_hazard` (the correspondence lemma, via `VolInstrument.probOr_hazard`) | **PROVEN** — `⊗_φ` is never applied to the unbounded hazards directly |
| M7(i) the rebate is an LP-INCIDENCE object, not a reduction in extraction: `λ_MEV^{LP-net} = (1−τ)λ_MEV`, `τ(k) = k/(k+1) ∈ [0,1)` | `MevJointProgram.mevNet`, `mevNet_le_mev` (nonnegativity DISCHARGED on `mevMulti_nonneg`, not assumed), `mevNet_anti_tau`, `mevNet_eq_zero_of_tau_one`, `mevNet_argmin_invariant` (for every `τ < 1` the rebate changes the program's VALUE and not its SOLUTION), `taxFraction`, `taxFraction_mem_Ico`, `taxFraction_mono` | **PROVEN** — `τ` sits **outside** `Θ_φ`; `k` is FREE and no numeral enters a statement, because the l2-angstrom snapshot and the live documentation disagree on the constants |
| M7(ii) the batch cadence IS `Δt`: it moves `λ_ARB` monotonically and does not enter `λ_FLAIR` at all | `MevJointProgram.mev_mono_dt` (ISOTONE in `Δt`) | **PROVEN** — the second protocol lever **outside** `Θ_φ`, alongside `τ` |

## 8. `VOL ORDER COMPLETION — ENDOGENOUS MATURITY` (doc block, issue cfmm-lean4-spec#1 → `EndogenousMaturity.lean`)

Notation: `ΔQ_v★` → `dQvStar`; `t★` → `tStar`; `N_σ` → `Nσ`; `ΔM_req` → `dMReq`.

| Doc claim | Lean | Status |
|---|---|---|
| `t★ = 2·ΔQ_v★/N_σ ⟺ ΔQ_v★ = (t★/2)·N_σ` (derived, never stored) | `tStar`, `dQvStarOfMaturity`, `dQvStarOfMaturity_tStar`, `tStar_dQvStarOfMaturity`, `maturity_equivalence` | **PROVEN** (Nσ ≠ 0) |
| Bridge to the proven unit-vega layer | `variancePortfolio_upsilon_at_tStar`, `tStar_variancePortfolio_upsilon`, `tStar_unit_upsilon` | **PROVEN** |
| `t★` positive / strictly monotone in `ΔQ_v★`, anti in `N_σ` | `tStar_pos`, `tStar_strictMono_dQvStar`, `tStar_strictAnti_Nσ` | **PROVEN** |
| Auto-deleverage floor `min(ΔQ_v★, Q_M/p_risk)` admissible + division-free | `dQvFunded_admissible`, `dQvFunded_admissible_iff_mul`, `dQvFunded_mul_le_of_violation` (via `Main.admissible_iff_mul`) | **PROVEN** |
| No violation ⟹ untouched; floor is MAXIMAL among admissible | `dQvFunded_eq_of_no_violation`, `dQvFunded_maximal` | **PROVEN** |
| Maturity contracts with funding; top-up restores; liquidation = `Q_M → 0` | `tStarFunded_mono_QM`, `tStarFunded_antitone_prisk`, `tStarFunded_eq_tStar_of_topup`, `dQvFunded_zero_QM` | **PROVEN** |
| Integer-rounding conservativity (real layer) | floor-rounding min-monotonicity lemma | **PROVEN** |
| Joint recalibration law (collateral × realized-variance accrual) | **DECIDED (user, 2026-07-30): `tStarJointMult`** — `t★_joint = t★·(funding factor)·(1 − σ²_R/σ²_K)⁺`; `tStarJointMult_nonneg/_antitone/_zero/_exhausted`. Alternates remain formalized: `tStarJointSub*` (identical on `t★ ≥ 0`, floor placement per `joint_candidates_disagree`), `tStarJointQuadratic*` (REJECTED — breaks the dated-equivalent reading, pro-holder under vol clustering) | **DECIDED → PROVEN** |

## 9. `τ_MEV ENTRY ALGEBRA` (draft blocks M9–M10, `VOLATILITY_INSTRUMENTS_TAU_ADDENDUM.md` → `TauMevAlgebra.lean`)

Three entry channels formalized; **DECIDED (user, 2026-07-31): channel (A), monoid entry** `φ_total = φ_M ⊗_φ φ_X ⊗_φ τ_MEV`. Alternates NOT adopted: (B) convex separation `(1−τ)φ / τφ` (`lpShare`/`donation`); (C) auction lump-sum = the already-proven `MevJointProgram.taxFraction`/`mevNet`. Decided consequences: λ_τ is a genuine ⊕-summand; strict intensity effect (λ_ARB ↓); no leg-targeting; no compensation routed (donation would require an ORDER-SENSITIVE hybrid with (B)/(C)); φ⊗τ moves the M6a level direction.

| Doc claim | Lean | Status |
|---|---|---|
| M9(A1) monoid entry closed in `[0,1]` | `TauMevAlgebra.tau_monoid_mem` | **PROVEN** |
| M9(A2) composition raises the trader-paid fee (weak + strict) | `tau_monoid_ge`, `tau_monoid_gt` | **PROVEN** |
| M9(A3) intensity effect: monoid entry DETERS extraction through `P_trade` (weak + strict; nonneg-fee domain per the pole discipline) | `tau_intensity_effect`, `tau_intensity_effect_strict` (on `ptrade_strictAntiOn`) | **PROVEN** |
| M9(A4) NO TARGETING: the aggregate is invariant to which leg (`φ_M`/`φ_X`) carries `τ` | `tau_no_targeting` (assoc+comm of `probOr`, hypothesis-free) | **PROVEN** |
| M9(A5) three-way hazard exactness `(λ_M ⊕ λ_X ⊕ λ_τ)` under `⊗_φ` | `tau_hazard_exact` (extends `probOr_hazard`) | **PROVEN** |
| M10(B1) budget identity `lpShare + donation = φ` | `tau_split_budget` | **PROVEN** |
| M10(B2) intensity NEUTRALITY: separation leaves `P_trade` (hence `λ_ARB`) unchanged | `tau_split_intensity_neutral` | **PROVEN** |
| M10(B3) FLAIR linearity: `(1−τ)·λ_FLAIR` realizable INSIDE `Θ_φ` by scaling the level block `(φ̄,u)` | `tau_split_flair_linear` (on `flairMulti_affine`) | **PROVEN** |
| M10(B4) bridge to the auction channel: at `τ = taxFraction k`, separation of realized extraction reproduces `mevNet` + complementary donation exactly | `tau_split_mevNet_bridge` | **PROVEN** |
| M10(D1) revenue scaling is NOT a `⊗_φ`-morphism (witness `1/2 ≠ 3/4`) | `tau_scaling_not_monoid_hom` | **PROVEN** (inequivalence) |
| M10(D2) hybrid (A)∘(B) is ORDER-SENSITIVE (witness `1 ≠ 1/2`) | `tau_order_matters` | **PROVEN** (inequivalence) |
| M10(D3) separation BREAKS the hazard correspondence (witness `τ=1/2, λ=2·log 2`: `1/2 ≠ 3/8`) | `tau_split_breaks_hazard` | **PROVEN** (inequivalence) |

All 14 declarations axiom-clean (`propext, Classical.choice, Quot.sound`); deps byte-identical to the 13 submitted modules; Aristotle project `7ffb3a29`.

## 10. `λ_JIT — EVENT-TIME HAZARD` (draft blocks J0–J8, `VOLATILITY_INSTRUMENTS_JIT_ADDENDUM.md` → `JitLiquidity.lean`; CJZ arXiv:2311.18164)

Notation (J0): CJZ λ→`ϑ`, α→`ϖ`, f→`φ`, ν(π)→`mJ`; π→`πJ` (Real.pi collision).

| Doc claim | Lean | Status |
|---|---|---|
| J1 swap primitives δ_S, δ_R: 1-homogeneous, strictly increasing + strictly CONCAVE in first arg, monotone in depth | `deltaS/R`, `_homogeneous`, `_strictMono_first`, `_strictConcave_first`, `_monotone_depth` | **PROVEN** |
| J2 closed form d̃_J★ as transcribed = root of M_J | `dJstar_not_root_witness` — machine-checked witness `MJfun 0 1 2 (dJstar 0 1 2) ≠ 0`: the transcribed radicand is MISSING a factor q_R | **REFUTED (transcription)** |
| J2 corrected root: radicand `q_R²(1+φ)d̃_P(d̃_P+q_R)` | `dJroot`, `dJroot_root`, `dJroot_unique_positive_root` | **CORRECTED → PROVEN** |
| J2 THE THIRD POLE at q_R = φ·d̃_P; no positive root below | `dJstar_pole` (atTop from the right), `MJfun_no_positive_root_below_pole` | **PROVEN** |
| J3 depth fixed point: M_T strictly decreasing, boundary values, unique μ(π); threshold μ>φ ⟺ ζ_U > ζ̲(φ,π); m_J positive + FOURTH POLE at μ = φ | `MTfun_strictAnti`, `MTfun_zero_gt_target`, `MTfun_tendsto_zero`, `existsUnique_MTfun_solution`, `MTfun_solution_threshold`, `mJ_pos`, `mJ_pole` | **PROVEN** |
| J4 delegation: 𝒞 < 0 (ζ > 1+φ, ψ∈[0,1] incl. edges); 𝒰 strictly ↓ ϖ; freeze characterization | `Ccost_neg`, `Uutil_strictAnti`, `Uutil_neg_iff` | **PROVEN** |
| J5 crowding: ℛ = φ·V bridges; π=1 bridge at ζ★(φ,1) = (√φ+√(1+φ))²; crowding region widens in φ | `Rrev_eq_fee_mul_V`, `Rrev0_eq_fee_mul_V0`, `ζstar`, `V0fun_zetaStar_eq_Vfun_one`, `ζstar_strictMono` | **PROVEN** |
| J6 two-tier ϑ split: shares sum to 1, in [0,1], affine in ϑ; bridge ϑ ↦ 1−τ to `taxFraction`; welfare CORNER ϑ★ with binding U(ϑ★)=0 (monotone forces as hypotheses, unique) | `sJ`, `effective_shares_sum/_mem`, `passive_share_affine`, `passive_share_tax_bridge`, `welfare_corner` (∃!) | **PROVEN** |
| J7 λ_JIT INCIDENCE (the headline): toxicity ratio λ_ARB/(λ_FLAIR−λ_JIT) strictly ↑ λ_JIT; λ_ARB preserved; mevTotal INVARIANT (extraction intensity unchanged) while the FLAIR side falls — "incidence operator, NOT ⊕-summand" formal | `toxicity_ratio_strictMono`, `incidence_preserves_ARB`, `incidence_mevTotal_invariant`, `incidence_FLAIR_falls` | **PROVEN** |
| J8(a) conditional (β,γ) payoff-identity at ϑ = ϑ_eff (abstract; concrete ϑ_eff(β,γ) OPEN) | `conditional_payoff_identity` | **PROVEN** (conditional) |
| J8(b) without trader-fee invariance: fee raises WIDEN crowding (ζ★ ↑ φ) | `trader_fee_raises_crowding_threshold` | **PROVEN** |
| J8(c) l2-angstrom bridge: jitFactor = (3/2)·x, rates x/(x+1)-form: jitRate > swapRate (x>0), both strictly increasing + strictly CONCAVE | `jitFactor`, `swapRate/jitRate`, `jitRate_gt_swapRate`, `swapRate/jitRate_strictMono`, `swapRate/jitRate_strictConcave` | **PROVEN** (3/2 = the bridged DEFINITION, dated snapshot) |

All 62 declarations axiom-clean; 13 deps byte-identical; Aristotle project `610bb259`. The J2 refutation is a TRANSCRIPTION correction (the addendum's radicand), joining ptrade's pole (M5) and T24 (M6b) in the corrected-claims ledger.

## 11. `GREEKS` (blocks G0–G6, `VOLATILITY_INSTRUMENTS_GREEKS_ADDENDUM.md`; INSERTED into the doc 2026-07-31)

Sources: Bardoscia–Nodari 2302.11942 (LP Greeks), Maymin 2603.29763 (CEV/AMM option pricing, liquidity-adjusted Greeks), Clark SSRN 3898384, Kristensen, Demeterfi et al., Bichuch–Feinstein, Fateh–Singh. Notation: `𝒟_x[·]` sensitivity operator; probabilities `ℙ_{event}`; `τ` = τ_MEV NEVER time (maturity `t★`, remaining `t★−t`).

| Doc claim | Lean | Status |
|---|---|---|
| G1 per-tick `𝒟_p[π]`, `Γ` on the sqrt-price ladder | `GeomProfile`, `PosSpec.tickPrice`, `Flow.terminalPayoff` (carriers exist; the Greek displays themselves) | **UNFORMALIZED** (spec) |
| G1 aggregate flat dollar gamma `Γ^Σp²` — GRID-EXACT; band-modulated companion `∝ p^{1/2}` (pointwise const is FALSE) | `varswapWeight_geometric`, `logContractLiquidity_geometric` (the proven grid-level statements) | **PROVEN** (grid level) / **CORRECTED** (pointwise claim) |
| G1 `υ = t/2` vs locked-LP short vega `−(t★−t)/8·(asset leg)`; t-semantics clause (maturity param vs calendar) | `variancePortfolio_upsilon`, `tStar`, `tStarFunded` | **PROVEN** (υ) / spec (locked vega) |
| G1 both θ_fee forms: schedule-level `φ(σ_t)ν_t` (M6b-commensurable, what λ_FLAIR sums) and position-level `φ(σ_t)ν_tΔQ_M` | `VolInstrument.multiFee`, `FlairOptimization.flairHazard` | **UNFORMALIZED** — the future Aristotle statement MUST name which form |
| G2 depth/emission Greeks `𝒟_{L̄}[C]`, `𝒟_{ΔQ_M}[C]` = **CALL** Greeks (Maymin Def 2); LP-side composition `𝒟_{L̄}[π] ≥ 0` (opposite sign to the first draft) | — | **OFF-BUNDLE** (CEV pricing, noncentral χ², IV inversion beyond Mathlib v4.28) |
| G2 CEV/skew law `dp = μdt + δp^{1−η_L}dW`, `σ = δp^{−η_L}`; skew depth-invariant, function of `η_L` alone | — | **OFF-BUNDLE**; `η_L = η` is E8(6), **OPEN** (never assumed) |
| G3 CONTROL MATRIX (8 parameter blocks × 11 rows, position-level): shape Greeks fee-FREE ⟹ `(ξ,ι)` the shaping base; **`(β_j,γ_j)` control the CARRY PROFILE** via `Δθ_fee/Δσ = u Σ α_j γ_j Λ′(γ_j(σ−β_j))·ν_t` — β translates, γ scales where carry accrues in σ-space | `VolInstrument.multiFee` (the derivative structure verified against the def), `multiFee_monotone`, `multiFee_bounds` | **SPEC** — the first first-order display containing the shape block (cf. T24, J8 negative results) |
| G3 caveats: the carry static holds at FIXED `(φ̄,α,u)` — moving `(β,γ)` re-prices λ_FLAIR (weights `W_j` depend on them; β→−∞ never attained); the vega "hedge" needs the TIME-INTEGRATED `∫_t^{t★}` form (level-vega vs rate-vega) | `FlairOptimization` corner lemmas | **CORRECTED** (both over-claims caught at gate) |
| G4 underspecification: `|𝒯| = 10` targets vs `#free = 6+2n` (n ≥ 2); shape deficit **1** aggregate, **ι−2** at ladder resolution; `(β,γ)` column ZERO on every shape row | — | **SPEC** — Bunni-v2 LDF milestone needs `dim θ_LDF ≥ ι−2` |
| G5 EVM partition (exact / approximable / off-chain); `σ²(i(t))` needs an oracle hook or a new accumulator (E2/E5 feed the OFF-chain subgraph) | events layer | **SPEC** |

Gate: Reality Checker + Model QA, both NEEDS WORK → 3 BLOCKERs + 7 MAJORs resolved (commit 2460f7f). Key corrections: Maymin's Λ/E are call Greeks not LP Greeks (LP-side sign was asserted backwards); **η_L = 1 − w** (his CEV exponent is the NUMERAIRE weight — decided against his asymmetric eq (12), invisible at the w = ½ point where all specializations sit); Clark's delta display is UNNUMBERED (gamma = eq (12); eq (13) is Green–Jarrow spanning — never cite it for a Greek).

## 12. `τ_JIT — THE LIQUIDITY TAX` (block J9 → `TauJit.lean`; Aristotle project `4cb6d5ca`)

DECIDED (user, 2026-07-31): `(β,γ)` DISCARDED for JIT control; the control is `τ_JIT`, a tax on JIT liquidity provision. 25 declarations, all axiom-clean, 15 deps byte-identical.

| Doc claim | Lean | Status |
|---|---|---|
| J9 taxed payoff `u_J^τ = u_J − τ_JIT·(add+rm)`, l2-angstrom rate instance `x/(x+1)` | `uJtax`, `uJtax_jitRate`, `uJtax_strict_decrease`, `uJtax_additivity` | **PROVEN** |
| J9 the STRUCTURAL ASYMMETRY vs `τ_MEV`: liquidity carries no fee ⟹ NO monoid/split algebra exists | `uJtax_not_probOr_factor` — **no unary `f` makes the levy factor through `probOr`**; two-point witness `(1,0)`/`(0,1)`, equal `probOr = 1`, taxed payoffs `1` vs `−base` | **PROVEN** (impossibility) |
| J9 participation + THE FIFTH POLE `τ_JIT★ = u_J★/base` | `participates`, `tauStarJIT`, `participates_iff_tau_le` (exact), `participates_antitone_tau`, `participates_isotone_uJstar`, `not_participates_of_tauStar_lt`, `tauStarJIT_tendsto_atTop` (base → 0⁺) | **PROVEN** |
| J9 `λ̃_JIT = λ̃_JIT(τ_JIT)` decreasing — bang-bang at the extensive margin | `lamJITtax`, `lamJITtax_antitone_tau`, `lamJITtax_eq_of_tau_le`, `lamJITtax_eq_zero_of_tauStar_lt` | **PROVEN** |
| J9 the tax REVERSES the incidence: extraction intensity invariant, PLP FLAIR restored | `lamJITtax_mevTotal_invariant`, `flair_restored_of_tauStar_lt` | **PROVEN** |
| J9 REMEDY DIRECTION `∂ζ★/∂τ_JIT ≤ 0 ?` — answered in discrete form | `crowdingActive`, `gatedVolume`, `gatedVolume_eq_baseline_of_tauStar_lt`, `crowdingActive_antitone_tau`, and the headline contrast `tax_shrinks_while_fee_widens`: the tax weakly SHRINKS the crowding-active set while `ζstar` strictly WIDENS in the trader fee (reuses `JitLiquidity.trader_fee_raises_crowding_threshold`) | **PROVEN** — the tax is the correct remedy channel exactly where fee-raising backfires |
| J9 `τ_JIT ≠ ϑ` (tax prices the event; the split redistributes income) | `split_payoff_pos`, `split_positive_tax_negative_witness` — witness `u_J = s_J = base = 1`, `τ_JIT = 2`: split payoff `> 0` for EVERY `ϑ ∈ (0,1]` while taxed payoff `= −1` | **PROVEN** (inequivalence) |
| J9 `κ_φ`-entry (second-order statics signed by J1 concavity) | — deliberately out of this bundle's scope | **OPEN** |

## 13. `ETA — THE INTERIOR CURVATURE CONTROLLER` (blocks E0–E8 → `EtaCurvature.lean`; projects `4878ca32` + repair `c3a617f3`)

Notation: curvature `κ_{\varphi}` (Capponi's `k`; Lean `curvIndex`, branch points `kphiS`/`kphiI`, kink `kphiStar`); `ϱ_S`/`ϱ_I` = Capponi's `α`/`β`; `c₁,c₂,c₃` = his `τ₁,τ₂,τ₃` (τ is τ_MEV). 51 declarations, all axiom-clean, 18 deps byte-identical across BOTH runs.

| Doc claim | Lean | Status |
|---|---|---|
| E1 `κ_φ(η,Δi) = 1 − λ^(−Δi²η/2)` from the tick-independent step ratio; bijection `(0,∞)→(0,1)` | `curvIndex`, `priceEta_step_ratio`, `curvIndex_eq_of_priceEta`, `curvIndex_mem_Ioo`, `curvIndex_strictMono`, `curvIndex_tendsto_zero`, `curvIndex_tendsto_one` | **PROVEN** |
| E2/E3 Lemma 3(1)/(2): both branches, branch points, continuity, strict antitonicity | `arbLossRatio_branch_agree`, `arbLossRatio_strictAntiOn`, `arbLossRatio_pos`, `kphiS_mem_Ioo`, `kphiS_eq_zero_of_eq`, `arbLossRatio_eq_zero_of_kphiS_eq_zero`, `surplusRatio_strictAntiOn`, `kphiS_le_kphiI_iff` | **PROVEN** — `kphiS_eq_zero_of_eq` is the honest replacement for the FALSE-as-drafted `arbLossRatio_eq_zero_of_fee_ge` (the ϖ_A occurrence indicator is frozen into a constant and cannot express Lemma 1's zero-loss) |
| E4 **THE INTERIOR OPTIMUM** `κ_φ⋆ = κ_{φ,I} = 1 − √((1+φ)/(1+ϱ_I))`, interior ⟺ `φ < ϱ_I`; a KINK, no FOC | `lpExcess_strictMonoOn`, `lpExcess_strictAntiOn`, `lpExcess_isMaxOn`, `kphiStar_eq_kphiI`, `kphiStar_mem_Ioo_iff`, `lpPayoff_isMaxOn`, `liquidity_freeze_minimal`, branch agreements at both points | **PROVEN** — the maximum comes from TWO ONE-SIDED monotonicity results; no stationarity argument anywhere |
| E5 deposit efficiency + the zero-sum identity `surplus + LP revenue = ϱ_I/2` below `κ_{φ,I}` | `depositEfficiency_branch_agree`, `depositEfficiency_isMaxOn`, `surplus_add_revenue_const` | **PROVEN** (welfare half remains OPEN by design) |
| E6 **THE HEADLINE** `η⋆ = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)` with `κ_φ(η⋆) = κ_φ⋆`; comparative statics; the η-side transport | `curvIndex_etaStar`, `etaStar_pos_iff`, `etaStar_strictMono_premInv`, `etaStar_strictAnti_fee`, `etaStar_strictAnti_spacing`, `lpExcessEta_isMaxOn`, `lpExcessEta_strictMonoOn`, `lpExcessEta_strictAntiOn` | **PROVEN** |
| E6 η-identity claim (i), the EXPONENT half: `priceEta η Δi i = p_eta(lam,Δi,η/2,i) = P_half(lam,Δi·η/2,i)` | `priceEta_eq_p_eta_half`, `priceEta_eq_P_half` (T28'a) | **PROVEN** — the user's 2026-07-31 decision, exponent half DISCHARGED |
| E6 η-identity claim (ii), the FACTOR-SHARE half (`L_eta = X^η Y^{1−η}`) | — (T28'b absent, pre-authorized; NOT satisfied by restating T28'a) | **OPEN** (E8(6)) — and *unavailable* wherever `η⋆ ∉ (0,1)`: at `λ=1.0001, ϱ_I=0.05, φ=0.003`, `η⋆ ≈ 458/Δi²` |
| E7 the cross-model statement + the fee/curvature coupling `∂η⋆/∂φ < 0` | `eta_no_common_argmax`, `etaStar_coupled_to_fee_corner` | **PROVEN as NARROWED** (user ruling 2026-07-31): NO literal de-degeneration of the `Θ_φ` program — `mevMulti` contains no η, no κ_φ, no ϱ_I. The interior optimum lives in the Capponi-anchored model; Phase-11's degeneracy stands where it was left (E8(3): the two arbitrage objects are NOT identified) |
| E7 scalarization-impossibility as first drafted | — **FALSE beyond the first branch**: arbLoss and surplus switch branches at DIFFERENT points (`κ_{φ,S} < κ_{φ,I}`), so the weighted sum crosses zero at `κ_φ ≈ 0.2412 ∈ (0.1835, 0.5)`, no branch point | **CORRECTED in the doc 2026-07-31**; the false form was PROHIBITED in the prompt and never entered Lean |

Fidelity: 13/15 repaired statements verbatim; 2 AMENDED with added hypotheses and conclusions intact — `lpExcess_strictAntiOn` gains E0's own ordering `φ < ϱ_S ≤ ϱ_I`, and `etaStar_pos_iff` gains `−1 < ϱ_I` because **Mathlib's `Real.log` is `log|x|`** (witness `ϱ_I = −3, φ = 0`), precisely the log-sign trap the 12-02 Model QA review predicted. Zero narrowed statements. Full record: `.planning/phases/12-eta-tradeoff-optimum/12-03-FIDELITY.md`.
