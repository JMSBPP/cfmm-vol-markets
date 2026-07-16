# Mean–variance under the η-measure, the CEV vol term structure, and the Hodl benchmark

*Answer to three linked design questions, grounded in the objects already in this
repo and kept **discrete, fee-free, and EVM-implementable**. Every claim below has
a machine-checked counterpart in `exp/MeanVarianceEta.lean` (builds with no
`sorry`).*

The three questions:

1. **How to do mean–variance using ONLY the relative prices already defined —
   expectations discrete, core measure the η-measure — and how to introduce a
   risk-neutral measure?**
2. **How does the CEV / constant-weighted-product price-process material help
   "introduce a vol term structure on η"?**
3. **To what extent does the Bergault–Bertucci–Bouba–Guéant mean–variance LP
   paper (arXiv:2212.00336) help?**

---

## 1. Mean–variance with only the relative prices, under the η-measure

No fees and no new primitives are needed. The three ingredients you already have
are enough:

* **the random variable** is the relative price itself, `p_η(i) = λ^{i·Δᵢ·η}`
  (`priceKernel` in the Lean file; its `η = ½` member is `eta.lean`'s `P_half`);
* **the measure** is the inventory weights `ηⱼ` normalized to a probability
  vector `w = η / Ση` — this is the "η-measure" (`normalize`, proved a genuine
  probability measure in `normalize_isProb`: `wⱼ ≥ 0` and `Σⱼ wⱼ = 1`, the formal
  version of your "Σ η̃ⱼ = 1 by construction");
* **the expectation is a finite sum** `E_w[X] = Σⱼ wⱼ Xⱼ` (`E`), and the
  **variance** is the central second moment `Var_w[X] = Σⱼ wⱼ(Xⱼ − E_w[X])²`
  (`Var`).

The **mean–variance objective** is then just `MV_γ[X] = E_w[X] − (γ/2)·Var_w[X]`
(`MV`), with `γ` the risk-aversion / Markowitz Lagrange multiplier. Proven facts:

| fact | Lean name |
|---|---|
| η-weights are a probability measure | `normalize_isProb` |
| König–Huygens `Var = E[X²] − (E[X])²` | `Var_eq_sub` |
| parallel-axis `Σ wⱼ(Xⱼ−c)² = Var + (E[X]−c)²` | `second_moment_decomp` |
| `Var ≥ 0` | `Var_nonneg` |
| risk strictly costs welfare, `MV_γ ≤ E[X]` for `γ ≥ 0` | `MV_le_mean` |
| at `γ = 0` mean–variance = expected price | `MV_risk_neutral` |

The parallel-axis identity is the bridge to your dispersion `σ`: the model's `σ`
is a second moment of the tick about the target `i_μ`, so
`σ = Var_η(tick) + (E_η[tick] − i_μ)²` — an honest mean–variance decomposition
(variance + squared bias) of the existing `sigma_xs` / `sigma_realized`, with **no
extra objects**.

### Introducing the risk-neutral measure (no new objects)

The risk-neutral measure is obtained by a **change of numeraire**: reweight the
η-measure by the relative price (an Esscher tilt),
`qⱼ = wⱼ·pⱼ / Σₖ wₖ pₖ` (`riskNeutral`). Then:

* `q` is again a probability measure (`riskNeutral_isProb`);
* **change-of-numeraire formula** `E_q[X] = (Σ wⱼ pⱼ Xⱼ)/(Σ wₖ pₖ)`
  (`E_riskNeutral`);
* **fundamental pricing identity** `E_w[p]·E_q[X/p] = E_w[X]` (`riskNeutral_pricing`):
  discounting a claim by the relative-price numeraire and taking the risk-neutral
  expectation recovers the physical η-expectation. This is the precise discrete
  sense in which the relative price is the martingale density between the
  η-measure and `q` — "risk neutral can be introduced" using only the prices.

---

## 2. The CEV material: a vol term structure indexed by η

For a constant-weighted-product AMM with pool weight `w`, the marginal price
follows the CEV SDE `dP = μ(P)dt + δ·P^w dW`, exponent `β = w`. **Identifying the
CES curvature `η` with the weight `w = β`** turns the η-dial into a selector of the
entire volatility term structure. Concretely the repo's `σ(η,·) = δ·P^η`
(`eta.lean`'s `sigmaVTS`) is exactly the CEV **level** diffusion `δ·P^β`
(`cevDiffusion`), and the **return** volatility is `σ_ret(P) = δ·P^{β−1} = δ·P^{η−1}`
(`cevRetVol`). Proven structural facts (the paper's Cor. 2 / Prop. 4 / Rmk. 1–2):

| regime | statement | Lean name |
|---|---|---|
| return-vol vs level diffusion | `σ_ret(P)·P = δ·P^β` | `cevRetVol_mul_self` |
| constant-product `β = ½` | `σ_ret(P) = δ/√P` | `cevRetVol_half` |
| Black–Scholes/GBM `β = 1` | `σ_ret = δ` (price-independent) | `cevRetVol_one` |
| Bachelier `β = 0` | level vol `= δ` (price-independent) | `cevDiffusion_zero` |
| leverage effect `β < 1` | `σ_ret(P)` strictly **decreasing** in `P` | `cevRetVol_strictAnti` |

So η is not just a curvature for the pricing kernel: through `β = η` it pins the
**elasticity spectrum** of volatility — Bachelier (`η=0`) → constant-product
(`η=½`, `1/√P`) → Black–Scholes (`η→1`). The leverage effect (`cevRetVol_strictAnti`)
gives a microstructure-grounded reason volatility rises as price falls. **To what
extent it helps:** it supplies the closed-form, relative-price-only law for the
volatility term structure as a function of η, so the vol surface used in the
mean–variance objective above is itself a function of the same η you are tuning.

---

## 3. The Bergault–Bertucci–Bouba–Guéant paper: extent of usefulness

The paper builds a **mean–variance comparison of LP PnL against the Hodl
benchmark**, derives that fee-free CFMM liquidity provision has a nonpositive,
concave payoff (impermanent loss / LVR), and then designs oracle-based pricing
functions with an efficient frontier parameterized by the risk-aversion `γ`.

**What transfers directly to our discrete, fee-free, EVM setting:**

* The **mean–variance objective with `γ` as risk-aversion / Lagrange multiplier**
  is exactly our `MV` above; the efficient-frontier idea is `argmax MV_γ` over the
  admissible parameter menu (`exp/SocialChoiceParameters.lean`'s
  `exists_optimal_tick` already gives well-posedness of that discrete argmax).
* The **Hodl benchmark and impermanent loss** is a *static convex-analysis*
  statement — no SDE, fully discrete and EVM-computable. The LP excess PnL over
  Hodl is `ψ*(−S₀) − ψ*(−Sₜ) − (Sₜ−S₀)·ψ*'(−S₀)`, the **negative Bregman
  divergence** of the convex conjugate `ψ*` (`excessPnL`, `bregman`,
  `excessPnL_eq_neg_bregman`). Hence:

| statement | Lean name |
|---|---|
| tangent/gradient inequality of a convex `ψ*` | `tangent_of_convexOn` |
| Bregman divergence `≥ 0` | `bregman_nonneg_of_tangent` |
| **impermanent loss `≤ 0`** (no-fee CFMM ≤ Hodl) | `excessPnL_nonpos` |
| loss vanishes if price returns to `S₀` ("impermanent") | `excessPnL_self` |
| **no-fee LP underperforms Hodl in mean under ANY η-measure** | `expected_excessPnL_nonpos` |

The last line is the bridge to Part 1: averaging the pointwise impermanent loss
under the η-measure gives a nonpositive *expected* excess PnL, i.e. the discrete
mean–variance statement of the paper's headline — *fee-free liquidity provision
cannot beat Hodl in expectation*, hence "a minimal amount of fees is necessary".

**What does NOT transfer (yet), by design:** the paper's quantitative efficient
frontier requires (i) a price SDE `dS = μS dt + σS dW`, (ii) logistic LT demand
intensities `Λ^{i,j}`, (iii) the markup controls `δ^{0,1}, δ^{1,0}` and the HJB
equation (2). Those introduce **fees/markups and continuous-time stochastic
control**, which are explicitly out of scope here (discrete, no fees). They are
the natural next layer once fees are added: the markups become the control, the
HJB value function `θ` is the object to approximate, and the Bregman/impermanent-
loss term above is exactly the fee-free baseline the markups must overcome.

**Bottom line on extent:** the paper helps *conceptually and structurally* — it
justifies (a) using `MV` with `γ` as the LP objective, (b) the Hodl benchmark as
the right zero, and (c) the impermanent-loss convexity inequality, all of which we
formalize discretely and fee-free. It does *not* (and is not meant to) give a
closed-form on-chain frontier; that needs the fee/oracle/control layer.

---

## Files

* `exp/MeanVarianceEta.lean` — all definitions and proofs referenced above
  (no `sorry`).
* Builds on `exp/eta.lean` (`P_half`, `sigmaVTS`, `sigma_xs`, `sigma_realized`)
  and complements `exp/SocialChoiceParameters.lean` (welfare functionals,
  `W_meanvar`, discrete argmax well-posedness).
