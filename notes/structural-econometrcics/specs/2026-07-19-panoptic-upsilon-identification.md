# Structural Econometric Specification: Panoptic Vol-Claim υ Identification

**Date:** 2026-07-19
**Framework:** Reiss & Wolak (2007), "Structural Econometric Modeling: Rationales and Examples from Industrial Organization", Handbook of Econometrics Vol 6A, Ch. 64 — three-stage structure (§4.1 economic model, §4.2 stochastic model, §4.3 estimation).
**Derived interactively:** every specification component below was confirmed through user questioning (GSD phase 8, plan 08-03). No component was auto-decided.
**Companion formalization:** the analytical (Lean) side of the same objects lives in `lean/vol_markets/Panoptic.lean` (payoff, θ lattice, premium sum) and `lean/vol_markets/Upsilon.lean` (υ finite difference, ATM/OTM conjecture); the pinned protocol spec is `spec/panoptic.md`.

---

## 1. Research Question

Identify the vega-like greek **υ ≡ Δπ/Δσ²** of a Panoptic vol-claim at the contract level (Panoptic: arXiv:2204.14232). The question is **parameter identification** — recover the vega profile υ(i_K, t) and its strike-tick shape from observed on-chain data — with the ATM/OTM shape claim carried as a testable parameter restriction, not an assumption.

- **Unit of observation:** position-epoch panel — one observation per Panoptic tokenId per time bucket (Panoptic subgraph; tokenId per Uniswap v3/v4 position). Within-position time variation in variance identifies the vega level; cross-position strike variation identifies the moneyness profile (identifying-variation logic per Reiss & Wolak §4.1 p.4115).
- **Primary outcome:** the **streaming premium π itself** — υ is targeted by its own definition Δπ/Δσ². The seed's collateral equation (Q_M regression) is **demoted to a robustness check** (see §6.2), a deliberate reframing of the original `spec/panoptic.md` ECONOMETRIC section made during questioning.

## 2. Economic Model (Reiss & Wolak §4.1)

### 2.1 Economic Environment
**Single Panoptic market** on one underlying Uniswap v3/v4 pool. Strike-tick variation comes from positions within this one market; cross-market heterogeneity is outside the model boundary.

### 2.2 Economic Actors
1. **Option buyer (vol taker)** — holds the tokenId, pays streaming premium θ while in range; long the vol claim whose υ we identify.
2. **Option seller / Panoptic liquidity provider (PLP)** — earns the streaming premium; posts/receives collateral.
3. **Passive Uniswap LP** — supplies the underlying AMM liquidity whose fee flow generates θ.
4. **Liquidator / risk engine** — enforces the protocol collateral schedule.

### 2.3 Information Structure
**Public chain state only** — all four actors observe exactly the on-chain state (ticks, variance estimator, premia, collateral). No private signals; information is symmetric. This choice eliminates the private-signal selection channel that would otherwise generate unobserved heterogeneity (cf. §3.1).

### 2.4 Primitives
**Tick grid + CFMM trading function only** (deliberately minimal):
- The λ = 1.0001 tick/price grid, p(i) = λ^{(i/2)·Δ_i}, and concentrated-liquidity CFMM — the technological primitive. It defines the strike tick i_K = log_λ K and gives the moneyness distance |i_K − i_t| structural meaning.
- **Deliberately NOT primitives:** the θ kernel (υ stays a free functional, not kernel-restricted — the ATM/OTM claim remains a testable conjecture, mirroring its status as a Lean `Prop` conjecture); the collateral schedule (demoted to robustness); the σ² process and buyer preferences (no structural choice model — see the no-selection caveat, §6.1).

### 2.5 Exogenous Variables
- **Realized variance σ²(t)** — pool-level realization, exogenous to any individual position.
- **Underlying pool parameters** — fee tier, tick spacing Δ_i, liquidity profile: institutional/technological givens over the sample.
- **Deliberately NOT declared exogenous:** position strikes/widths. Strike composition endogeneity is an acknowledged open concern handled by diagnostics (§6.2 position-FE) rather than assumed away.

### 2.6 Objectives and Decision Variables
**Mechanical accrual, no first-order conditions.** Premium accrual and collateral are deterministic protocol rules given positions; no behavioral optimization equation enters estimation. The premium equation is a protocol law, not a FOC.

### 2.7 Equilibrium Concept
**Protocol-law closure (no strategic equilibrium).** Positions are given; premium and collateral follow deterministic protocol rules; "equilibrium" is the accounting identity holding state-by-state. Identification is purely statistical. (Equilibrium-concept discipline per Reiss & Wolak §4.1 p.4110.)

## 3. Stochastic Model (Reiss & Wolak §4.2)

### 3.1 Unobserved Heterogeneity
**None.** Under protocol-law closure with symmetric public information, everything payoff-relevant is on-chain: the researcher observes what participants observe. η ≡ 0.

### 3.2 Agent Uncertainty
**None in the estimating equation.** The premium equation is ex-post accounting; ex-ante vol uncertainty affects position choices but never enters the accrual law being estimated. u ≡ 0.

### 3.3 Optimization and Measurement Error
No optimization error (mechanical accrual). Measurement error — the **entire** error term — has four modeled components:

| # | Source | Side | Econometric consequence |
|---|--------|------|------------------------|
| M1 | **σ² estimator error** (realized variance estimated from discrete tick observations) | RHS | **Errors-in-variables → attenuation bias in υ̂₀** — the load-bearing threat (RHS measurement error biases coefficients; Reiss & Wolak §4.2 p.4116) |
| M2 | Premium accrual discretization (θ accrues continuously, subgraph reports snapshots) | LHS | Inflates SEs, no coefficient bias |
| M3 | Subgraph indexing gaps/lag | Both | Potentially regime-correlated (non-classical) — flagged for the estimator-window sensitivity |
| M4 | Position leg aggregation (a tokenId bundles legs; per-position υ mixes leg vegas) | Mapping | Aggregation error between theory object and data object |

### 3.4 Implied Error Structure
ε_it = v_it (measurement error only): v = v^{M2} + v^{M3} + v^{M4}, with M1 entering through the mismeasured regressor σ̂² = σ² + e. No η, no u — the model is a deterministic protocol law measured with noise.

## 4. Estimation Strategy (Reiss & Wolak §4.3)

### 4.1 Functional Form
**Exponential-moneyness parametric vega profile** (chosen over the seed's linear interaction because the null hypothesis is about shape — an ATM maximum with exponential OTM decay — which a local linear term cannot express):

υ(i_K, t) = υ₀ · exp(−κ·|i_K − i_t|)

### 4.2 Distributional Assumptions
**None — moment-based.** Nonlinear least squares / GMM with heteroskedasticity-robust standard errors **clustered by tokenId**. No likelihood is specified for v (its four components are too heterogeneous to defend a parametric family).

### 4.3 Implied Econometric Equation

**π_it = β₀ + υ₀ · exp(−κ·|i_K(i) − i_t|) · σ̂²_t + v_it**

- π_it: streaming premium accrued by tokenId i over epoch t (subgraph snapshots)
- i_K(i): position strike tick; i_t: pool tick at epoch t; distance on the tick-grid primitive
- ⚠ σ̂²_t: estimated realized variance — **EIV-flagged regressor**. Remedy: instrument σ̂² with a second, independently-windowed variance estimator (or its lag) — the classical two-noisy-measures IV for errors-in-variables
- v_it: measurement error per §3.4

The seed's tick linearization υ(t) = υ(ī) + (Δυ/Δi)·i(t) is recovered as the first-order expansion of the exponential around ī and is estimated as an alternative specification (§6.2).

### 4.4 Identification
- **υ₀** — identified from within-position covariation of accrued premium with realized variance across epochs.
- **κ** — identified from cross-position variation in moneyness |i_K − i_t| at common t (the panel's cross-section), plus within-position moneyness drift as i_t moves.
- Both variation sources exist by construction at the position-epoch unit (§1).
- **Threat:** M1 attenuation on υ̂₀ (addressed by the IV remedy above); strike-composition selection contaminating κ̂ (addressed by the position-FE diagnostic, §6.2).

### The null hypothesis as a parameter restriction
**H₀: κ = 0** (flat vega profile) vs **H₁: κ > 0** (maximal at the money, exponentially decaying out of the money) — the `spec/panoptic.md` ECONOMETRIC-section hypothesis, and the econometric twin of the Lean conjecture pinned in `lean/vol_markets/Upsilon.lean`. υ₀ > 0 is required for υ to be a vega at all.

## 5. Specification Tests

| # | Implication | Type | Mathematical statement | Test |
|---|-------------|------|----------------------|------|
| 1 | υ is a vega | Sign restriction | υ₀ > 0 | One-sided t/Wald on υ̂₀ (robust, clustered) |
| 2 | ATM max + exponential OTM decay | Sign restriction | κ > 0 | One-sided t/Wald on κ̂ — **this is the null-hypothesis test** |
| 3 | Symmetric decay | Equality restriction | κ⁺ = κ⁻ (decay above vs below the money, estimated separately) | Wald test; rejection = put/call-side skew, evidence against the symmetric exponential form |

(Tests deliberately NOT committed, per questioning: EIV overidentification J-test; zero-intercept protocol-law test β₀ = 0.)

## 6. Sensitivity Analysis

### 6.1 Sensitive Assumptions (targets)
1. **Exponential-moneyness form** — κ̂'s meaning is form-dependent; a Gaussian-in-moneyness or power-law truth would misstate the decay. The §5 symmetry test catches asymmetry but not shape.
2. **No-selection (strike composition)** — strikes were neither modeled (§2.4) nor declared exogenous (§2.5); if position composition co-moves with σ² regimes, κ̂ blends selection with the true profile.

### 6.2 Alternative Specifications (all scheduled)
1. **Semiparametric υ(moneyness)** — spline/kernel vega profile, σ² linear: the form-sensitivity check; the null becomes a shape read-off from the estimated curve.
2. **Seed linear interaction** — π = β₀ + υ(ī)·σ² + γ·(i_K·σ²) + v: the original `spec/panoptic.md` tick-linearization as reduced-form benchmark.
3. **Position-FE / within estimator** — add tokenId fixed effects: the no-selection diagnostic; a material move in κ̂ indicates strike composition was doing work.
4. **Collateral-side robustness** — the demoted seed equation Q_M = Q_M(υ=0) + υ·σ² re-run on the collateral channel; compare υ̂ across the premium and collateral channels (the schedule is protocol code, so its form is known exactly).

## 7. Scope and Deferred Work

Per the phase plan (GSD 08-03) this document is the **specification only**: no estimation, no subgraph data pull, no regression run. The data pipeline (subgraph extraction, variance-estimator construction) and estimation are deferred. Aristotle formalization of identification assertions was deliberately not run — this GSD phase reserves its single serial Aristotle slot for the θ_ATM derivation (plan 08-05).

## 8. References

- Reiss, P. & Wolak, F. (2007). "Structural Econometric Modeling: Rationales and Examples from Industrial Organization." *Handbook of Econometrics*, Vol 6A, Ch. 64. §4.1 (economic model, equilibrium concept p.4110, unit of observation p.4115), §4.2 (error decomposition pp.4113–4116), §4.3 (functional forms p.4118, specification tests p.4120).
- Panoptic protocol: Lambert & collaborators, "Panoptic: perpetual options on Uniswap" — arXiv:2204.14232. Streaming-premium mechanism and tokenId position structure.
- Demeterfi, K., Derman, E., Kamal, M., Zou, J. (1999). "More Than You Ever Wanted To Know About Volatility Swaps." Goldman Sachs Quantitative Strategies Research Notes. Replication-cost pricing of vol claims (citekey: demeterfi1999volswaps).
- In-tree: `spec/panoptic.md` (pinned protocol spec; ECONOMETRIC section is this document's seed); `spec/refs/cfmm-discrete/` (lattice calculus notes: FINANCE, STREAMING_PREMIUM); `lean/vol_markets/Panoptic.lean`, `lean/vol_markets/Upsilon.lean` (analytical twins).

---

*Derived 2026-07-19 via the structural-econometrics skill's interactive questioning (Phases 0–4; spec-only scope per GSD plan 08-03). Every decision above was user-confirmed one question at a time.*
