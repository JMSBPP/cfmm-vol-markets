/-
  exp/ComparativeStatics.lean

  Formal companion to `exp/ComparativeStatics.md`.

  Design question answered here (the user's recommendation):

      « Parameterize the environment.  Introduce a *market state vector*
            θ = (λ, L̄, ξ, δ, γ, …).
        Then write the mean–variance objective as a function of the two
        controls and the state,
            MV_γ(Δᵢ, η; θ),
        so that the solution is a *map* of the state,
            (Δᵢ⋆, η⋆) = g(θ).
        This is exactly what comparative statics studies. »

  Everything reuses the existing infrastructure: the η-measure `IsProb`,
  the expectation `E`, the variance `Var`, the mean–variance objective `MV`,
  and the relative-price kernel `priceKernel` from `exp/MeanVarianceEta.lean`,
  plus the program existence theory of `exp/MeanVarianceOptimization.lean`.
  No new economic primitives are introduced — only the *bundling* of the
  exogenous parameters into a single state record `MarketState`, and the
  comparative-statics solution map `g`.

  Mapping of the state coordinates to the existing formulas:

    * `lam`   = λ : pricing base of the relative-price kernel
                `priceKernel λ Δᵢ η i = λ^{i·Δᵢ·η}`.
    * `L_bar` = L̄ : total liquidity, `L̄ = Σᵢ L(i)` (`liqAt_sum`).
    * `xi`    = ξ : geometric liquidity-distribution base; the per-tick share
                `ℓ(ξ,#;i) = ξ^i / Σⱼ ξ^j` is a probability distribution over the
                interior ticks (`liqShare_sum_one`), and `L(i) = L̄·ℓ`.
    * `delta` = δ : volatility scale of the CEV return vol
                `σ_ret = δ·P^{η−1}` (`retVol`, `retVol_half`).  This pins the
                dispersion coordinate `σ`: it is *not* a free coordinate of θ
                but the realized vol term structure determined by `(δ, η, P)`.
    * `gamma` = γ : risk aversion of the mean–variance objective.

  The two CONTROLS are `(Δᵢ, η)`, ranging over the admissible box
  `[1,200] × [a,b]` (with `[a,b] ⊆ (0,1)` the curvature sub-band recorded in θ).

  What is established:

    * `MVobj θ (Δᵢ, η) = MV_γ(Δᵢ, η; θ)` — the state-parameterized objective,
      defeq to the program objective `J` of `exp/MeanVarianceOptimization.lean`.
    * `exists_optimizer` — the optimum is attained, so the solution map is
      well-defined; `g θ`, `g_mem`, `g_isMax` package the optimizer
      `(Δᵢ⋆, η⋆) = g(θ)` and the value function `value θ = MV_γ(g θ; θ)`.
    * Comparative statics in γ: `MVobj_antitone_gamma`, `value_antitone_gamma`
      (more risk aversion never raises the optimal value) and `value_le_mean`.
    * Closed-form corner in the risk-neutral limit: `riskNeutral_corner`
      (with `λ>1`, positive ticks and `γ=0` the optimum is the upper corner
      `g(θ) = (200, b)`).
    * Liquidity-distribution grounding of `(L̄, ξ)`: `liqShare_sum_one`,
      `liqAt_sum`; volatility grounding of `δ`: `retVol`, `retVol_half`.
-/
import Mathlib
import exp.MeanVarianceEta
import exp.MeanVarianceOptimization

open scoped BigOperators Topology
open CFMM.MeanVariance CFMM.MVOpt

namespace CFMM.ComparativeStatics

variable {m : ℕ}

/-- **Market state vector** `θ = (λ, L̄, ξ, δ, γ, …)` together with the discrete
    tick band `tick`, the η-measure weights `w`, and the admissible curvature
    band `[a,b]`.  The well-formedness proofs (`0 < λ`, `a ≤ b`, `w` a
    probability measure) are carried as fields so that the solution map `g` is a
    genuine function of `θ` alone. -/
structure MarketState (m : ℕ) where
  /-- pricing base `λ` of the relative-price kernel. -/
  lam : ℝ
  /-- total liquidity `L̄ = Σᵢ L(i)`. -/
  L_bar : ℝ
  /-- geometric liquidity-distribution base `ξ`. -/
  xi : ℝ
  /-- volatility scale `δ` of the CEV return-vol term structure. -/
  delta : ℝ
  /-- risk aversion `γ` of the mean–variance objective. -/
  gamma : ℝ
  /-- lower endpoint of the admissible curvature band `[a,b] ⊆ (0,1)`. -/
  a : ℝ
  /-- upper endpoint of the admissible curvature band `[a,b] ⊆ (0,1)`. -/
  b : ℝ
  /-- the discrete tick band `i : Fin m → ℤ`. -/
  tick : Fin m → ℤ
  /-- the η-measure weights `w`. -/
  w : Fin m → ℝ
  /-- the base is positive. -/
  hlam : 0 < lam
  /-- the curvature band is nonempty. -/
  hab : a ≤ b
  /-- the weights form a probability measure. -/
  hw : IsProb w

/-- The relative-price payoff `π` under the controls `c = (Δᵢ, η)`:
    `π_j = λ^{i_j·Δᵢ·η}`.  This is the model's `priceKernel`. -/
noncomputable def payoff (θ : MarketState m) (c : ℝ × ℝ) : Fin m → ℝ :=
  priceKernel θ.lam c.1 c.2 θ.tick

/-- **The state-parameterized mean–variance objective** `MV_γ(Δᵢ, η; θ)`:
    `MV_γ(Δᵢ, η; θ) = E^{η̃}[π] − (γ/2)·Var^{η̃}[π]`, with everything but the
    two controls `(Δᵢ, η)` fixed by the state `θ`. -/
noncomputable def MVobj (θ : MarketState m) (c : ℝ × ℝ) : ℝ :=
  MV θ.w (payoff θ c) θ.gamma

/-- The admissible **control box** `[1,200] × [a,b]` recorded in `θ`. -/
def box (θ : MarketState m) : Set (ℝ × ℝ) :=
  Set.Icc (1 : ℝ) 200 ×ˢ Set.Icc θ.a θ.b

/-- `MVobj` is, by definition, the program objective `J` of
    `exp/MeanVarianceOptimization.lean` with the (constant) η̃-measure family and
    the relative-price payoff family. -/
theorem MVobj_eq_J (θ : MarketState m) (c : ℝ × ℝ) :
    MVobj θ c = J (fun _ => θ.w) (priceKernelFam θ.lam θ.tick) θ.gamma c := rfl

/-! ## Existence of the optimum — the solution map is well-defined -/

/-
**The optimum is attained.**  Over the admissible box the
    state-parameterized objective attains its maximum, so the solution map
    `g(θ)` below is well-defined.
-/
theorem exists_optimizer (θ : MarketState m) :
    ∃ c ∈ box θ, ∀ c' ∈ box θ, MVobj θ c' ≤ MVobj θ c := by
  convert exists_mv_optimal θ.lam θ.hlam θ.tick ( fun _ => θ.w ) continuous_const θ.gamma θ.a θ.b θ.hab using 1

/-- **The comparative-statics solution map** `(Δᵢ⋆, η⋆) = g(θ)`: a maximizer of
    `MV_γ(·; θ)` over the admissible box, chosen for each state `θ`. -/
noncomputable def g (θ : MarketState m) : ℝ × ℝ :=
  (exists_optimizer θ).choose

/-- The solution `g(θ)` is admissible. -/
theorem g_mem (θ : MarketState m) : g θ ∈ box θ :=
  (exists_optimizer θ).choose_spec.1

/-- The solution `g(θ)` maximizes the objective over the admissible box. -/
theorem g_isMax (θ : MarketState m) :
    ∀ c' ∈ box θ, MVobj θ c' ≤ MVobj θ (g θ) :=
  (exists_optimizer θ).choose_spec.2

/-- **The value function** `V(θ) = MV_γ(g(θ); θ) = sup_{(Δᵢ,η)} MV_γ(Δᵢ, η; θ)`. -/
noncomputable def value (θ : MarketState m) : ℝ := MVobj θ (g θ)

/-- The optimal value is the supremum: every admissible control is dominated. -/
theorem value_isMax (θ : MarketState m) :
    ∀ c ∈ box θ, MVobj θ c ≤ value θ := g_isMax θ

/-! ## Comparative statics in the risk aversion γ -/

/-- Override the risk-aversion coordinate of the state. -/
def setGamma (θ : MarketState m) (γ : ℝ) : MarketState m := { θ with gamma := γ }

@[simp] theorem setGamma_lam (θ : MarketState m) (γ : ℝ) : (setGamma θ γ).lam = θ.lam := rfl
@[simp] theorem setGamma_tick (θ : MarketState m) (γ : ℝ) : (setGamma θ γ).tick = θ.tick := rfl
@[simp] theorem setGamma_w (θ : MarketState m) (γ : ℝ) : (setGamma θ γ).w = θ.w := rfl
@[simp] theorem setGamma_a (θ : MarketState m) (γ : ℝ) : (setGamma θ γ).a = θ.a := rfl
@[simp] theorem setGamma_b (θ : MarketState m) (γ : ℝ) : (setGamma θ γ).b = θ.b := rfl
@[simp] theorem setGamma_gamma (θ : MarketState m) (γ : ℝ) : (setGamma θ γ).gamma = γ := rfl

/-- The admissible box does not depend on the risk aversion. -/
theorem box_setGamma (θ : MarketState m) (γ : ℝ) : box (setGamma θ γ) = box θ := rfl

/-- The payoff family does not depend on the risk aversion. -/
theorem payoff_setGamma (θ : MarketState m) (γ : ℝ) (c : ℝ × ℝ) :
    payoff (setGamma θ γ) c = payoff θ c := rfl

/-
**Pointwise monotonicity in γ.**  For a fixed control, raising the risk
    aversion never raises the objective (variance is nonnegative).
-/
theorem MVobj_antitone_gamma (θ : MarketState m) {γ₁ γ₂ : ℝ} (h : γ₁ ≤ γ₂)
    (c : ℝ × ℝ) :
    MVobj (setGamma θ γ₂) c ≤ MVobj (setGamma θ γ₁) c := by
  simp +decide only [MVobj, MV, setGamma_w, payoff_setGamma, setGamma_gamma];
  nlinarith [ CFMM.MeanVariance.Var_nonneg θ.w ( payoff θ c ) θ.hw ]

/-
**Comparative statics of the value in γ.**  The optimal value `V(θ)` is
    antitone in the risk aversion: a more risk-averse market never achieves a
    higher mean–variance optimum.
-/
theorem value_antitone_gamma (θ : MarketState m) {γ₁ γ₂ : ℝ} (h : γ₁ ≤ γ₂) :
    value (setGamma θ γ₂) ≤ value (setGamma θ γ₁) := by
  refine' le_trans _ ( g_isMax _ _ _ );
  convert MVobj_antitone_gamma θ h _;
  convert g_mem ( setGamma θ γ₂ ) using 1

/-- **Risk never raises the value.**  With nonnegative risk aversion the optimal
    mean–variance value is bounded above by the expected relative price at the
    optimizer. -/
theorem value_le_mean (θ : MarketState m) (hγ : 0 ≤ θ.gamma) :
    value θ ≤ E θ.w (payoff θ (g θ)) :=
  MV_le_mean θ.w (payoff θ (g θ)) θ.hw hγ

/-! ## Closed-form corner solution in the risk-neutral limit -/

/-
**Risk-neutral corner solution.**  When `γ = 0`, `λ > 1`, the ticks are
    strictly positive and the curvature band is nonnegative, the optimum is the
    upper corner of the box: `g(θ) = (Δᵢ⋆, η⋆) = (200, b)` (maximal spacing and
    curvature).
-/
theorem riskNeutral_corner (θ : MarketState m) (hlam1 : 1 < θ.lam)
    (hi : ∀ j, 0 < θ.tick j) (ha : 0 ≤ θ.a) (hγ0 : θ.gamma = 0) :
    ∀ c ∈ box θ, MVobj θ c ≤ MVobj θ (200, θ.b) := by
  -- Apply the risk-neutral corner solution lemma with the given hypotheses.
  intros c hc
  have := CFMM.MVOpt.riskNeutral_isMaxOn_corner θ.lam hlam1 θ.tick hi θ.w θ.hw θ.a θ.b ha c hc
  simp [hγ0, MVobj, payoff] at this ⊢
  exact this

/-! ## Liquidity-distribution grounding of `(L̄, ξ)` -/

/-- The **geometric liquidity share** `ℓ(ξ,#;i) = ξ^i / Σ_{j=1}^{#} ξ^j` over
    the interior ticks `i ∈ {1,…,#}`. -/
noncomputable def liqShare (xi : ℝ) (sharp i : ℕ) : ℝ :=
  xi ^ i / ∑ j ∈ Finset.Icc 1 sharp, xi ^ j

/-
The liquidity shares form a probability distribution over the interior
    ticks: `Σ_{i=1}^{#} ℓ(ξ,#;i) = 1` (for `ξ > 0` and at least one tick).
-/
theorem liqShare_sum_one (xi : ℝ) (sharp : ℕ) (hxi : 0 < xi) (hsharp : 0 < sharp) :
    ∑ i ∈ Finset.Icc 1 sharp, liqShare xi sharp i = 1 := by
  unfold liqShare;
  rw [ ← Finset.sum_div, div_self <| ne_of_gt <| Finset.sum_pos ( fun _ _ => pow_pos hxi _ ) <| Finset.nonempty_Icc.mpr hsharp ]

/-- The **per-tick liquidity** `L(i) = L̄·ℓ(ξ,#;i)`. -/
noncomputable def liqAt (θ : MarketState m) (sharp i : ℕ) : ℝ :=
  θ.L_bar * liqShare θ.xi sharp i

/-
**Total liquidity is conserved:** `Σ_{i=1}^{#} L(i) = L̄`.
-/
theorem liqAt_sum (θ : MarketState m) {sharp : ℕ} (hxi : 0 < θ.xi)
    (hsharp : 0 < sharp) :
    ∑ i ∈ Finset.Icc 1 sharp, liqAt θ sharp i = θ.L_bar := by
  unfold liqAt;
  rw [ ← Finset.mul_sum _ _ _, liqShare_sum_one _ _ hxi hsharp, mul_one ]

/-! ## Volatility grounding of `δ` (the σ coordinate is determined) -/

/-- The **realized return volatility** `σ_ret = δ·P^{η−1}` of the state, the CEV
    return-vol term structure (`cevRetVol`).  The dispersion coordinate `σ` of
    the informal state vector is this quantity — pinned by `(δ, η, P)`, not a
    free coordinate. -/
noncomputable def retVol (θ : MarketState m) (P η : ℝ) : ℝ :=
  cevRetVol θ.delta P η

/-- `σ_ret = δ·P^{η−1}` by definition. -/
theorem retVol_eq (θ : MarketState m) (P η : ℝ) :
    retVol θ P η = θ.delta * P ^ (η - 1) := rfl

/-- **Constant-product limit (η = ½):** the realized return vol is
    `σ_ret = δ/√P`. -/
theorem retVol_half (θ : MarketState m) (P : ℝ) (hP : 0 < P) :
    retVol θ P (1 / 2) = θ.delta / Real.sqrt P :=
  cevRetVol_half θ.delta P hP

end CFMM.ComparativeStatics