/-
  exp/MeanVarianceEta.lean

  Formal companion to `exp/MeanVarianceEta.md`.

  Design question answered here: *how can we do mean–variance analysis WITHOUT
  introducing fees or any new objects — using ONLY the relative prices defined in
  the model — given that the expectations are discrete and the core probability
  measure is the η-measure, and how can a risk-neutral measure be introduced?*

  The whole construction reuses objects already in the repo:

    * the relative-price kernel `p_η(i) = λ^{i·Δᵢ·η}` (`exp/eta.lean`'s
      `P_half` is the η = ½ member; `priceKernel` below is the general η one);
    * the inventory weights `ηⱼ` of the agent, normalized to a discrete
      probability measure `w = η / Σ η` (the "η-measure");
    * the dispersion `σ` of `exp/eta.lean` (`sigma_xs` / `sigma_realized`),
      which is exactly a probability-weighted second moment about `i_μ`.

  No fees and no new economic primitives are added: the random variable is the
  relative price (or the tick), the measure is the η-weights, and the
  risk-neutral measure is obtained by a *change of numeraire* — an Esscher
  reweighting of the same η-measure by the same relative price.

  Everything is finite/discrete, indexed by `Fin m` (the admissible tick band),
  so all expectations are honest finite sums.
-/
import Mathlib

open scoped BigOperators

namespace CFMM.MeanVariance

variable {m : ℕ}

/-- A finite weight vector `w : Fin m → ℝ` is a **probability measure** when it
    is pointwise nonnegative and sums to one. This is the only structure the
    mean–variance machinery below needs from the "η-measure". -/
structure IsProb (w : Fin m → ℝ) : Prop where
  nonneg : ∀ j, 0 ≤ w j
  sum_one : ∑ j, w j = 1

/-- Discrete **expectation** of a random variable `X` under weights `w`:
    `E_w[X] = Σⱼ wⱼ Xⱼ`. (All model expectations are of this discrete form.) -/
def E (w X : Fin m → ℝ) : ℝ := ∑ j, w j * X j

/-- Discrete **variance** of `X` under `w`, as the central second moment
    `Var_w[X] = Σⱼ wⱼ (Xⱼ − E_w[X])²`. -/
def Var (w X : Fin m → ℝ) : ℝ := ∑ j, w j * (X j - E w X) ^ 2

/-- The **mean–variance objective** with risk-aversion `γ`:
    `MV_γ[X] = E_w[X] − (γ/2)·Var_w[X]`. No fees, no new objects — just the
    expectation and variance of the relative price `X` under the η-measure. -/
noncomputable def MV (w X : Fin m → ℝ) (γ : ℝ) : ℝ := E w X - γ / 2 * Var w X

/-- The general η relative-price kernel `p_η(i) = λ^{i·Δᵢ·η}` over a tick band
    `i : Fin m → ℤ`. The η = ½ member is `exp/eta.lean`'s `P_half`. -/
noncomputable def priceKernel (lam Δi η : ℝ) (i : Fin m → ℤ) : Fin m → ℝ :=
  fun j => lam ^ ((i j : ℝ) * Δi * η)

/-- The relative-price kernel is strictly positive whenever the base is. -/
lemma priceKernel_pos (lam Δi η : ℝ) (hlam : 0 < lam) (i : Fin m → ℤ) (j : Fin m) :
    0 < priceKernel lam Δi η i j := by
  unfold priceKernel
  exact Real.rpow_pos_of_pos hlam _

/-- **Normalization of the inventory weights into the η-measure.**
    `w = η / Σ η`. -/
noncomputable def normalize (η : Fin m → ℝ) : Fin m → ℝ :=
  fun j => η j / ∑ k, η k

/-
The normalized inventory weights form a probability measure (the η-measure):
    nonnegative and summing to one, whenever the inventories are nonnegative with
    positive total. This is the formal version of "Σⱼ η̃ⱼ = 1 by construction".
-/
theorem normalize_isProb (η : Fin m → ℝ) (hnn : ∀ j, 0 ≤ η j)
    (hS : 0 < ∑ k, η k) : IsProb (normalize η) := by
  exact ⟨ fun _ => div_nonneg ( hnn _ ) hS.le, by unfold normalize; rw [ ← Finset.sum_div, div_self hS.ne' ] ⟩

/-
**Computational form of the variance** (König–Huygens):
    `Var_w[X] = E_w[X²] − (E_w[X])²`.
-/
theorem Var_eq_sub (w X : Fin m → ℝ) (hw : IsProb w) :
    Var w X = E w (fun j => (X j) ^ 2) - (E w X) ^ 2 := by
  unfold Var E; ring;
  simp +decide [ Finset.sum_add_distrib, ← Finset.mul_sum _ _ _, ← Finset.sum_mul, hw.sum_one ] ; ring;

/-
**Bias–variance / parallel-axis decomposition.** The second moment of `X`
    about *any* point `c` splits into the variance plus the squared bias of the
    mean from `c`:
        `Σⱼ wⱼ (Xⱼ − c)² = Var_w[X] + (E_w[X] − c)²`.
    This is exactly why the model's dispersion `σ` (a second moment about the
    target tick `i_μ`) is a mean–variance object: it equals the η-variance of the
    tick plus the squared distance of the mean tick from `i_μ`.
-/
theorem second_moment_decomp (w X : Fin m → ℝ) (hw : IsProb w) (c : ℝ) :
    ∑ j, w j * (X j - c) ^ 2 = Var w X + (E w X - c) ^ 2 := by
  unfold Var E; ring; ( have := hw.sum_one; ( norm_num [ Finset.sum_add_distrib, Finset.mul_sum _ _ _, Finset.sum_mul, mul_assoc, mul_left_comm, mul_comm, pow_two, this ] ) ) ;
  simp +decide [ ← Finset.mul_sum _ _ _, ← Finset.sum_mul, ← Finset.sum_comm, this ] ; ring;
  norm_num [ ← mul_assoc, ← Finset.mul_sum _ _ _, ← Finset.sum_mul, this ]

/-
**Variance is nonnegative** under any probability measure.
-/
theorem Var_nonneg (w X : Fin m → ℝ) (hw : IsProb w) : 0 ≤ Var w X := by
  exact Finset.sum_nonneg fun i _ => mul_nonneg ( hw.nonneg i ) ( sq_nonneg _ )

/-
**The risk penalty strictly costs welfare:** with nonnegative risk-aversion
    `γ`, the mean–variance value never exceeds the mean.
-/
theorem MV_le_mean (w X : Fin m → ℝ) (hw : IsProb w) {γ : ℝ} (hγ : 0 ≤ γ) :
    MV w X γ ≤ E w X := by
  exact sub_le_self _ ( mul_nonneg ( by positivity ) ( Var_nonneg w X hw ) )

/-- **Risk-neutral collapse:** at `γ = 0` the mean–variance objective is exactly
    the (risk-neutral) expected relative price. -/
@[simp] theorem MV_risk_neutral (w X : Fin m → ℝ) : MV w X 0 = E w X := by
  unfold MV; ring

/-- **The risk-neutral measure as a change of numeraire.**
    `q = w·p / E_w[p]` — the η-measure reweighted (Esscher-tilted) by the same
    relative price `p`. No new object is introduced: `q` is built only from the
    η-weights `w` and the relative prices `p`. -/
noncomputable def riskNeutral (w p : Fin m → ℝ) : Fin m → ℝ :=
  fun j => w j * p j / ∑ k, w k * p k

/-
The risk-neutral measure is a genuine probability measure.
-/
theorem riskNeutral_isProb (w p : Fin m → ℝ) (hw : ∀ j, 0 ≤ w j)
    (hp : ∀ j, 0 ≤ p j) (hden : 0 < ∑ k, w k * p k) :
    IsProb (riskNeutral w p) := by
  constructor;
  · exact fun j => div_nonneg ( mul_nonneg ( hw j ) ( hp j ) ) hden.le;
  · unfold riskNeutral; rw [ ← Finset.sum_div _ _ _, div_self hden.ne' ] ;

/-
**Change-of-numeraire formula:** expectation under the risk-neutral measure
    `q` reweights the physical (η) expectation by the relative price:
        `E_q[X] = (Σⱼ wⱼ pⱼ Xⱼ) / (Σₖ wₖ pₖ)`.
-/
theorem E_riskNeutral (w p X : Fin m → ℝ) (hden : (∑ k, w k * p k) ≠ 0) :
    E (riskNeutral w p) X = (∑ j, w j * p j * X j) / (∑ k, w k * p k) := by
  unfold E riskNeutral; rw [ Finset.sum_div ] ; congr; ext; ring;

/-
**Fundamental risk-neutral pricing identity.** Discounting a claim `X` by the
    relative price (numeraire) and taking the risk-neutral expectation, then
    multiplying by the risk-neutral normalizer `E_w[p]`, recovers the physical
    η-expectation:
        `E_w[p] · E_q[X / p] = E_w[X]`.
    Equivalently, the relative price is a martingale change of measure between the
    η-measure and `q`. This is the precise sense in which "risk neutral can be
    introduced" using only the relative prices.
-/
theorem riskNeutral_pricing (w p X : Fin m → ℝ) (hp : ∀ j, 0 < p j)
    (hden : (∑ k, w k * p k) ≠ 0) :
    (E w p) * E (riskNeutral w p) (fun j => X j / p j) = E w X := by
  simp +decide [ E, riskNeutral ];
  simp +decide [ div_eq_mul_inv, mul_assoc, mul_comm, mul_left_comm, Finset.mul_sum _ _ _, hden, ne_of_gt ( hp _ ) ];
  exact Finset.sum_congr rfl fun _ _ => by rw [ mul_left_comm ( p _ ), mul_inv_cancel₀ ( ne_of_gt ( hp _ ) ), mul_one ] ;

/-! ## CEV volatility term structure on η (constant-weighted-product AMM)

  Connection to the CEV price process of a constant-weighted-product AMM: with
  pool weight `w` the marginal price follows the CEV SDE
      `dP = μ(P) dt + δ·P^w dW`,
  whose exponent is `β = w`. Identifying the CES curvature `η` with the weight
  `w = β`, the model's volatility term structure `σ(η,·) = δ·P^η` (the `sigmaVTS`
  of `exp/eta.lean`) is exactly the CEV LEVEL diffusion `δ·P^β`, and the
  instantaneous RETURN volatility is `σ_ret(P) = δ·P^{β−1} = δ·P^{η−1}`. So the
  η-dial chooses the whole volatility term structure (the elasticity spectrum:
  β = 0 Bachelier, β = ½ constant-product/√P, β → 1 Black–Scholes/GBM).

  The facts below record the paper's structural results (Cor. 2, Prop. 4,
  Rmk. 1–2) purely as relative-price identities — no new objects, only the
  relative price `P` and the parameters `(δ, η = β)`.
-/

/-- CEV level-diffusion coefficient `δ·P^β` (the `dW` coefficient of `dP`).
    For `β = η` this is exactly `exp/eta.lean`'s `sigmaVTS`. -/
noncomputable def cevDiffusion (delta P β : ℝ) : ℝ := delta * P ^ β

/-- CEV instantaneous **return** volatility `σ_ret(P) = δ·P^{β−1}`. -/
noncomputable def cevRetVol (delta P β : ℝ) : ℝ := delta * P ^ (β - 1)

/-
Return-vol × price = level diffusion: `σ_ret(P)·P = δ·P^β`. The two vol
    conventions agree up to one factor of the relative price.
-/
theorem cevRetVol_mul_self (delta P β : ℝ) (hP : 0 < P) :
    cevRetVol delta P β * P = cevDiffusion delta P β := by
  unfold cevRetVol cevDiffusion; ring;
  rw [ mul_assoc, ← Real.rpow_add_one hP.ne' ] ; ring

/-
**Constant-product AMM (β = ½):** the return volatility is inversely
    proportional to the square root of the relative price, `σ_ret(P) = δ/√P`
    (Prop. 4).
-/
theorem cevRetVol_half (delta P : ℝ) (hP : 0 < P) :
    cevRetVol delta P (1 / 2) = delta / Real.sqrt P := by
  unfold cevRetVol;
  norm_num [ div_eq_mul_inv, Real.sqrt_eq_rpow, Real.rpow_neg hP.le ]

/-
**Black–Scholes / GBM limit (β = 1):** the return volatility is
    price-independent, `σ_ret = δ`.
-/
@[simp] theorem cevRetVol_one (delta P : ℝ) :
    cevRetVol delta P 1 = delta := by
  -- By definition of $cevRetVol$, we have $cevRetVol delta P 1 = delta * P ^ (1 - 1) = delta * P ^ 0 = delta$.
  simp [cevRetVol]

/-
**Bachelier limit (β = 0):** the absolute (level) volatility is
    price-independent, `= δ`.
-/
@[simp] theorem cevDiffusion_zero (delta P : ℝ) :
    cevDiffusion delta P 0 = delta := by
  -- By definition of cevDiffusion, we have cevDiffusion delta P 0 = delta * P^0.
  simp [cevDiffusion]

/-
**Leverage effect (β < 1):** with `δ > 0` the return volatility is strictly
    DECREASING in the relative price — as `P` falls, `σ_ret(P)` rises (Rmk. 2).
    This is the structural, microstructure-grounded leverage effect of the
    constant-weighted-product AMM.
-/
theorem cevRetVol_strictAnti (delta : ℝ) (hδ : 0 < delta) (β : ℝ) (hβ : β < 1)
    {P₁ P₂ : ℝ} (hP₁ : 0 < P₁) (hlt : P₁ < P₂) :
    cevRetVol delta P₂ β < cevRetVol delta P₁ β := by
  convert mul_lt_mul_of_pos_left ( Real.rpow_lt_rpow_of_neg ( by linarith ) hlt ( by linarith : β - 1 < 0 ) ) hδ using 1

/-! ## Hodl benchmark and impermanent loss (Bergault–Bertucci–Bouba–Guéant)

  Mean–variance LP analysis à la Bergault–Bertucci–Bouba–Guéant (arXiv:2212.00336)
  benchmarks an LP against the **Hodl** (buy-and-hold) strategy. For a no-fee
  CFMM with convex level-set function `ψ` (Legendre–Fenchel conjugate `ψ*`), the
  excess PnL over Hodl at terminal exchange-rate `Sₜ` vs initial `S₀` is
      `ψ*(−S₀) − ψ*(−Sₜ) − (Sₜ − S₀)·ψ*'(−S₀)`,
  which is exactly the **negative of the Bregman divergence** of the convex `ψ*`,
  hence `≤ 0` (impermanent loss), with equality iff `Sₜ = S₀`.

  We keep everything **discrete and fee-free** (a static convex-analysis
  inequality — no SDE, directly EVM-computable): the only inputs are the value
  function, its initial marginal `g = ψ*'(−S₀) = q¹₀` (the Hodl sensitivity),
  and the prices. Taking the η-measure expectation then shows the no-fee LP
  underperforms Hodl *in mean* under ANY probability measure — the precise
  formal sense in which "a minimal amount of fees is necessary". -/

/-- **Bregman divergence** of `f` with subgradient/slope `g` at base point `b`,
    evaluated at `a`:  `D_f(a,b) = f a − f b − g·(a − b)`. Nonnegative for convex
    `f`. Computable (no fees, no SDE) — EVM-implementable. -/
def bregman (f : ℝ → ℝ) (g a b : ℝ) : ℝ := f a - f b - g * (a - b)

/-- **LP excess PnL over Hodl** in a no-fee CFMM: `ψ*(−S₀) − ψ*(−Sₜ) −
    (Sₜ − S₀)·g`, with `g = ψ*'(−S₀)` the initial reserve / Hodl sensitivity. -/
def excessPnL (f : ℝ → ℝ) (g S0 St : ℝ) : ℝ :=
  f (-S0) - f (-St) - (St - S0) * g

/-- The excess PnL is exactly the **negative Bregman divergence** of `ψ*`. -/
theorem excessPnL_eq_neg_bregman (f : ℝ → ℝ) (g S0 St : ℝ) :
    excessPnL f g S0 St = - bregman f g (-St) (-S0) := by
  unfold excessPnL bregman; ring

/-- **Bregman divergence is nonnegative** given the tangent (subgradient)
    inequality `f b + g·(x − b) ≤ f x` characterizing convexity at `b`. -/
theorem bregman_nonneg_of_tangent (f : ℝ → ℝ) (g a b : ℝ)
    (htangent : ∀ x, f b + g * (x - b) ≤ f x) : 0 ≤ bregman f g a b := by
  have := htangent a; unfold bregman; linarith

/-
The tangent (gradient) inequality holds for any differentiable convex `f`:
    `f b + f'(b)·(x − b) ≤ f x` for all `x`.
-/
theorem tangent_of_convexOn (f : ℝ → ℝ) (hf : ConvexOn ℝ Set.univ f) (b g : ℝ)
    (hg : HasDerivAt f g b) (x : ℝ) : f b + g * (x - b) ≤ f x := by
  by_cases h_cases : x < b;
  · have h_slope : Filter.Tendsto (fun h => (f (b + h) - f b) / h) (nhdsWithin 0 (Set.Ioi 0)) (nhds g) := by
      simpa [ div_eq_inv_mul ] using hg.tendsto_slope_zero_right;
    have h_slope_le : ∀ h > 0, (f (b + h) - f b) / h ≥ (f b - f x) / (b - x) := by
      intros h h_pos; have := hf.slope_mono_adjacent ( Set.mem_univ x ) ( Set.mem_univ ( b + h ) ) h_cases ( by linarith ) ; aesop;
    have h_slope_le : g ≥ (f b - f x) / (b - x) := by
      exact le_of_tendsto_of_tendsto tendsto_const_nhds h_slope ( Filter.eventually_of_mem self_mem_nhdsWithin fun h hh => h_slope_le h hh );
    rw [ ge_iff_le, div_le_iff₀ ] at h_slope_le <;> linarith;
  · by_cases h_cases : x > b;
    · have := hf.le_slope_of_hasDerivAt ( Set.mem_univ b ) ( Set.mem_univ x ) h_cases hg;
      rw [ slope_def_field ] at this ; nlinarith [ mul_div_cancel₀ ( f x - f b ) ( sub_ne_zero_of_ne h_cases.ne' ) ];
    · norm_num [ show x = b by linarith ]

/-- **Impermanent loss is nonpositive** (no-fee CFMM): the LP excess PnL over
    Hodl is `≤ 0`, given the convexity (tangent) inequality of `ψ*` at `−S₀`. -/
theorem excessPnL_nonpos (f : ℝ → ℝ) (g S0 St : ℝ)
    (htangent : ∀ x, f (-S0) + g * (x - (-S0)) ≤ f x) :
    excessPnL f g S0 St ≤ 0 := by
  rw [excessPnL_eq_neg_bregman]
  have : 0 ≤ bregman f g (-St) (-S0) := bregman_nonneg_of_tangent f g (-St) (-S0) htangent
  linarith

/-- **No loss when the price is unchanged** (`Sₜ = S₀`): impermanent loss
    vanishes, recovering the "impermanent" character of the loss. -/
@[simp] theorem excessPnL_self (f : ℝ → ℝ) (g S0 : ℝ) :
    excessPnL f g S0 S0 = 0 := by
  unfold excessPnL; ring

/-
**The no-fee LP underperforms Hodl in mean under ANY η-measure.** If `w` is a
    probability measure over the discrete terminal exchange-rates `St`, the
    expected excess PnL over Hodl is `≤ 0`. This is the discrete mean–variance
    statement of the impossibility of profitable fee-free liquidity provision.
-/
theorem expected_excessPnL_nonpos (w : Fin m → ℝ) (hw : IsProb w)
    (f : ℝ → ℝ) (g S0 : ℝ) (St : Fin m → ℝ)
    (htangent : ∀ x, f (-S0) + g * (x - (-S0)) ≤ f x) :
    E w (fun k => excessPnL f g S0 (St k)) ≤ 0 := by
  exact Finset.sum_nonpos fun i _ => mul_nonpos_of_nonneg_of_nonpos ( hw.nonneg i ) ( by linarith [ excessPnL_nonpos f g S0 ( St i ) htangent ] )

end CFMM.MeanVariance