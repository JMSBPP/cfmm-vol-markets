import Mathlib
import vol_markets.RiskDesign

open scoped Topology

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Sigmoid fee schedule in realized volatility

Formalizes the parametric family behind the threshold-type dynamic fee
schedule of Campbell–Bergault–Milionis–Nutz, *Optimal Fees for Liquidity
Provision in Automated Market Makers* (arXiv:2508.08152).  The paper's
numerically characterized shape (simulation + calibration, not theorems):
the optimal AMM fee is competitive with the CEX trading cost and remarkably
stable under normal conditions, rises with volatility in the
moderate-to-high-demand regime, and becomes prohibitively high in
very-high-volatility episodes — a threshold-type dynamic schedule.  The LP
objective is profitability in the paper's own AMM-vs-CEX model, in the
spirit of fee return-on-capital (cf. FLAIR, Milionis–Wan–Adams,
arXiv:2306.09421, an ex-post competitiveness metric).  This module
*parametrizes* that shape; it does not restate the paper's results as
theorems, and nothing here constrains the floor/plateau values themselves
(only `fee_lt_cex` encodes undercutting; `feeHalt` encodes the halt jump).

We parametrize the schedule as the sigmoid family

  `fee(σ) = η_min + (η_max - η_min) · logistic ((σ - c) / s)`

with parameters `θ = (η_min, η_max, c, s)`.  The *algebraic structure* of the
parameter space, stated below:

* `(c, s)` carry a right action of the affine group `ℝ* ⋉ ℝ` of the
  volatility line — `fee_rescale` (equivariance) + `rescale_id`,
  `rescale_comp` (action laws).  Only `α ≠ 0` is required; `α < 0` stays in
  the family but reverses orientation (a positive-slope schedule maps to a
  negative-slope one), so the monotone regime is the `α > 0` sub-action;
* `(η_min, η_max)` transform under the affine reparametrization `scaleOut`
  of the output axis — `fee_scaleOut` (equivariance), `scaleOut_id`,
  `scaleOut_comp` (action laws), `scaleOut_ordered` (the ordered half-plane
  `{η_min ≤ η_max}` is preserved iff the scale is nonnegative);
* the threshold ("bang-bang fee") rule is the degenerate `s → 0⁺` boundary of
  the family — `feeRaw_tendsto_high` / `feeRaw_tendsto_low`;
* the family calibrates the optimal-fee curve at any two volatility levels,
  and the calibration is unique — `feeRaw_interpolate`,
  `feeRaw_interpolate_unique`;
* optimizer interface: a maximizing parameter choice exists on any compact
  parameter set for any continuous objective (`exists_optimal_params` — the
  generic extreme value theorem, recorded as the interface for fitting);
* the schedule plugs into the vol-instrument risk-price layer, typed
  against `RiskDesign` (`RISK_ALTERNATIVES.md` P1, and P2 by instantiating
  the oracle with `riskPriceMax`): a sigmoid fee with `η_max ≤ 1` passes
  the premium clamp unchanged, and the resulting `p_risk` is monotone in
  realized volatility — `fee_mem_unit`, `riskPriceBuffered_fee`,
  `riskPrice_sigmoid_mono`, `riskPriceP2_sigmoid_mono`.

Statements only; proofs are for Aristotle.
-/

namespace FeeSchedule

/-! ## 1. Logistic primitive -/

/-- The standard logistic sigmoid `x ↦ 1 / (1 + e^(-x))`. -/
noncomputable def logistic (x : ℝ) : ℝ := 1 / (1 + Real.exp (-x))

/-
The logistic takes values in the open unit interval.
-/
lemma logistic_mem_Ioo (x : ℝ) : logistic x ∈ Set.Ioo (0 : ℝ) 1 := by
  rw [logistic]
  constructor
  · positivity
  · rw [div_lt_one (by positivity)]
    linarith [Real.exp_pos (-x)]

/-
The logistic is strictly monotone.
-/
lemma logistic_strictMono : StrictMono logistic := by
  intro x y hxy
  rw [logistic, logistic]
  gcongr

/-
Right-tail limit: `logistic x → 1` as `x → +∞`.
-/
lemma logistic_tendsto_atTop :
    Filter.Tendsto logistic Filter.atTop (𝓝 (1 : ℝ)) := by
  unfold logistic
  have h0 : Filter.Tendsto (fun _ : ℝ => (1 : ℝ)) Filter.atTop (𝓝 1) :=
    tendsto_const_nhds
  have h : Filter.Tendsto (fun x : ℝ => 1 + Real.exp (-x)) Filter.atTop
      (𝓝 (1 : ℝ)) := by
    convert h0.add Real.tendsto_exp_neg_atTop_nhds_zero using 1 <;> norm_num
  simpa [one_div] using h.inv₀ (by norm_num)

/-
Left-tail limit: `logistic x → 0` as `x → -∞`.
-/
lemma logistic_tendsto_atBot :
    Filter.Tendsto logistic Filter.atBot (𝓝 (0 : ℝ)) := by
  unfold logistic
  have hn : Filter.Tendsto (fun x : ℝ => -x) Filter.atBot Filter.atTop :=
    Filter.tendsto_neg_atBot_atTop
  have he : Filter.Tendsto (fun x : ℝ => Real.exp (-x)) Filter.atBot Filter.atTop :=
    Real.tendsto_exp_atTop.comp hn
  have h1 : Filter.Tendsto (fun _ : ℝ => (1 : ℝ)) Filter.atBot (𝓝 1) :=
    tendsto_const_nhds
  have ha : Filter.Tendsto (fun x : ℝ => Real.exp (-x) + 1) Filter.atBot
      Filter.atTop := he.atTop_add h1
  have hb : Filter.Tendsto (fun x : ℝ => 1 + Real.exp (-x)) Filter.atBot
      Filter.atTop := by simpa [add_comm] using ha
  simpa [one_div] using hb.inv_tendsto_atTop

/-! ## 2. The sigmoid fee family -/

/-- Parameter vector `θ = (η_min, η_max, c, s)` of the sigmoid fee family:
fee floor, fee plateau, volatility center, and steepness. -/
structure Params where
  etaMin : ℝ
  etaMax : ℝ
  center : ℝ
  slope : ℝ

/-- Raw sigmoid fee schedule (explicit parameters). -/
noncomputable def feeRaw (ηmin ηmax c s σ : ℝ) : ℝ :=
  ηmin + (ηmax - ηmin) * logistic ((σ - c) / s)

/-- Sigmoid fee schedule of a parameter vector. -/
noncomputable def fee (P : Params) (σ : ℝ) : ℝ :=
  feeRaw P.etaMin P.etaMax P.center P.slope σ

/-
**Range.**  For an ordered parameter pair the fee stays in
`[η_min, η_max]`.
-/
lemma fee_mem_Icc (P : Params) (σ : ℝ) (hle : P.etaMin ≤ P.etaMax) :
    fee P σ ∈ Set.Icc P.etaMin P.etaMax := by
  obtain ⟨hl, hu⟩ := logistic_mem_Ioo ((σ - P.center) / P.slope)
  rw [fee, feeRaw]
  constructor <;> nlinarith

/-
**Monotonicity in realized volatility.**  For `s > 0` and an ordered pair,
the fee is monotone increasing in `σ` — the moderate-to-high-demand shape of
the optimal-fee curve.
-/
lemma fee_monotone (P : Params) (hle : P.etaMin ≤ P.etaMax)
    (hs : 0 < P.slope) :
    Monotone (fee P) := by
  intro x y hxy
  rw [fee, fee, feeRaw, feeRaw]
  have harg : (x - P.center) / P.slope ≤ (y - P.center) / P.slope :=
    div_le_div_of_nonneg_right (sub_le_sub_right hxy _) (le_of_lt hs)
  have hlog := logistic_strictMono.monotone harg
  nlinarith

/-
**Undercutting.**  If the plateau is strictly below the CEX fee `η⁰`, the
schedule undercuts the CEX at every volatility level.
-/
lemma fee_lt_cex (P : Params) (η0 σ : ℝ) (hle : P.etaMin ≤ P.etaMax)
    (hmax : P.etaMax < η0) :
    fee P σ < η0 := by
  exact lt_of_le_of_lt (fee_mem_Icc P σ hle).2 hmax

/-! ## 3. Algebraic structure: affine actions on the parameter space -/

/-- Pullback of the schedule along the affine reparametrization
`σ ↦ α·σ + β` of the volatility line: `(c, s) ↦ ((c - β)/α, s/α)`. -/
noncomputable def rescale (P : Params) (α β : ℝ) : Params :=
  ⟨P.etaMin, P.etaMax, (P.center - β) / α, P.slope / α⟩

/-- Affine action on the output (fee) axis:
`(η_min, η_max) ↦ (a·η_min + b, a·η_max + b)`. -/
noncomputable def scaleOut (P : Params) (a b : ℝ) : Params :=
  ⟨a * P.etaMin + b, a * P.etaMax + b, P.center, P.slope⟩

/-
**Equivariance.**  The rescaled parameters implement precisely the affine
change of volatility variable: `fee_{θ·(α,β)}(σ) = fee_θ(α·σ + β)`.
-/
lemma fee_rescale (P : Params) (α β σ : ℝ) (hα : α ≠ 0) :
    fee (rescale P α β) σ = fee P (α * σ + β) := by
  have heq : (σ - (P.center - β) / α) / (P.slope / α) =
      (α * σ + β - P.center) / P.slope := by
    field_simp
    ring
  simp only [fee, rescale, feeRaw]
  rw [heq]

/-
**Action law: identity.**
-/
lemma rescale_id (P : Params) : rescale P 1 0 = P := by
  cases P
  simp [rescale]

/-
**Action law: composition.**  Composing two affine reparametrizations acts
through the group law of `Aff(ℝ) = ℝ₊ ⋉ ℝ`:
`(θ·(α,β))·(α',β') = θ·(α·α', β + α·β')`.
-/
lemma rescale_comp (P : Params) (α β α' β' : ℝ) (hα : α ≠ 0) (hα' : α' ≠ 0) :
    rescale (rescale P α β) α' β' = rescale P (α * α') (β + α * β') := by
  cases P with
  | mk emin emax center slope =>
    simp only [rescale]
    have hc : ((center - β) / α - β') / α' =
        (center - (β + α * β')) / (α * α') := by
      field_simp
      ring
    have hs : slope / α / α' = slope / (α * α') := by
      field_simp
    rw [hc, hs]

/-
**Output equivariance.**  The output action rescales the schedule affinely:
`fee_{scaleOut θ a b}(σ) = a · fee_θ(σ) + b`.
-/
lemma fee_scaleOut (P : Params) (a b σ : ℝ) :
    fee (scaleOut P a b) σ = a * fee P σ + b := by
  rw [fee, fee, feeRaw, feeRaw, scaleOut]
  ring

/-
**Output action law: identity.**
-/
lemma scaleOut_id (P : Params) : scaleOut P 1 0 = P := by
  cases P
  simp [scaleOut]

/-
**Output action law: composition.**  Composing two output affine maps acts
through the group law: `scaleOut (scaleOut θ a b) a' b' =
scaleOut θ (a'·a) (a'·b + b')`.
-/
lemma scaleOut_comp (P : Params) (a b a' b' : ℝ) :
    scaleOut (scaleOut P a b) a' b' = scaleOut P (a' * a) (a' * b + b') := by
  cases P with
  | mk emin emax center slope =>
    simp only [scaleOut]
    congr 1 <;> ring

/-
**Order preservation.**  A nonnegative output scale preserves the ordered
half-plane `{η_min ≤ η_max}` of admissible parameter pairs.
-/
lemma scaleOut_ordered (P : Params) (a b : ℝ) (ha : 0 ≤ a)
    (hle : P.etaMin ≤ P.etaMax) :
    (scaleOut P a b).etaMin ≤ (scaleOut P a b).etaMax := by
  simp only [scaleOut]
  have := mul_le_mul_of_nonneg_left hle ha
  linarith

/-! ## 4. The threshold schedule as the `s → 0⁺` boundary -/

/-
**High branch.**  Above the center (`c < σ`) the fee tends to the plateau
`η_max` as the steepness degenerates, `s → 0⁺`.
-/
lemma feeRaw_tendsto_high (ηmin ηmax c σ : ℝ) (h : c < σ) :
    Filter.Tendsto (fun s => feeRaw ηmin ηmax c s σ)
      (𝓝[>] (0 : ℝ)) (𝓝 ηmax) := by
  have harg : Filter.Tendsto (fun s => (σ - c) / s) (𝓝[>] (0 : ℝ)) Filter.atTop := by
    have h1 : Filter.Tendsto (fun s : ℝ => s⁻¹) (𝓝[>] 0) Filter.atTop := by
      refine Filter.tendsto_atTop.mpr ?_
      intro b
      by_cases hb : b ≤ 0
      · filter_upwards [self_mem_nhdsWithin] with x hx
        exact le_trans hb (inv_nonneg.mpr hx.out.le)
      · push_neg at hb
        have : ∀ᶠ x in 𝓝[>] (0 : ℝ), b ≤ x⁻¹ := by
          filter_upwards [Ioo_mem_nhdsGT (by positivity : (0 : ℝ) < 1 / b)] with x hx
          have hx_pos : 0 < x := hx.1
          have hx_lt : x < 1 / b := hx.2
          calc b = (1 / b)⁻¹ := by field_simp
            _ ≤ x⁻¹ := inv_anti₀ hx_pos (le_of_lt hx_lt)
        exact this
    have h2 : ∀ᶠ s in 𝓝[>] (0 : ℝ), s ≠ 0 := by
      filter_upwards [self_mem_nhdsWithin] with x hx
      exact ne_of_gt hx.out
    simpa [div_eq_mul_inv] using Filter.Tendsto.const_mul_atTop (by linarith : 0 < σ - c) h1
  have hlog : Filter.Tendsto logistic Filter.atTop (𝓝 (1 : ℝ)) := logistic_tendsto_atTop
  have hcomp : Filter.Tendsto (fun s => logistic ((σ - c) / s)) (𝓝[>] (0 : ℝ)) (𝓝 1) :=
    hlog.comp harg
  have hfee : Filter.Tendsto (fun s => feeRaw ηmin ηmax c s σ) (𝓝[>] (0 : ℝ)) (𝓝 (ηmin + (ηmax - ηmin) * 1)) :=
    Filter.Tendsto.add tendsto_const_nhds (hcomp.const_mul (ηmax - ηmin))
  convert hfee using 1
  ring_nf

/-
**Low branch.**  Below the center (`σ < c`) the fee tends to the floor
`η_min` as `s → 0⁺`.  Together with `feeRaw_tendsto_high` this exhibits the
threshold-type fee rule as the degenerate boundary of the sigmoid family.
-/
lemma feeRaw_tendsto_low (ηmin ηmax c σ : ℝ) (h : σ < c) :
    Filter.Tendsto (fun s => feeRaw ηmin ηmax c s σ)
      (𝓝[>] (0 : ℝ)) (𝓝 ηmin) := by
  have harg : Filter.Tendsto (fun s => (σ - c) / s) (𝓝[>] (0 : ℝ)) Filter.atBot := by
    have h1 : Filter.Tendsto (fun s : ℝ => s⁻¹) (𝓝[>] 0) Filter.atTop := by
      refine Filter.tendsto_atTop.mpr ?_
      intro b
      by_cases hb : b ≤ 0
      · filter_upwards [self_mem_nhdsWithin] with x hx
        exact le_trans hb (inv_nonneg.mpr hx.out.le)
      · push_neg at hb
        have : ∀ᶠ x in 𝓝[>] (0 : ℝ), b ≤ x⁻¹ := by
          filter_upwards [Ioo_mem_nhdsGT (by positivity : (0 : ℝ) < 1 / b)] with x hx
          have hx_pos : 0 < x := hx.1
          have hx_lt : x < 1 / b := hx.2
          calc b = (1 / b)⁻¹ := by field_simp
            _ ≤ x⁻¹ := inv_anti₀ hx_pos (le_of_lt hx_lt)
        exact this
    have h2 : ∀ᶠ s in 𝓝[>] (0 : ℝ), s ≠ 0 := by
      filter_upwards [self_mem_nhdsWithin] with x hx
      exact ne_of_gt hx.out
    simpa [div_eq_mul_inv] using Filter.Tendsto.const_mul_atTop_of_neg (by linarith : σ - c < 0) h1
  have hlog : Filter.Tendsto logistic Filter.atBot (𝓝 (0 : ℝ)) := logistic_tendsto_atBot
  have hcomp : Filter.Tendsto (fun s => logistic ((σ - c) / s)) (𝓝[>] (0 : ℝ)) (𝓝 0) :=
    hlog.comp harg
  have hfee : Filter.Tendsto (fun s => feeRaw ηmin ηmax c s σ) (𝓝[>] (0 : ℝ)) (𝓝 (ηmin + (ηmax - ηmin) * 0)) :=
    Filter.Tendsto.add tendsto_const_nhds (hcomp.const_mul (ηmax - ηmin))
  convert hfee using 1
  ring_nf

/-! ## 5. Calibration and optimal parameter choice -/

/-
**Two-point calibration.**  The family is rich enough to match the optimal
fee at any two volatility levels: for any `σ₁ < σ₂` and target fees strictly
inside `(η_min, η_max)`, some `(c, s)` with `s > 0` interpolates both.
-/
lemma feeRaw_interpolate (ηmin ηmax σ₁ σ₂ y₁ y₂ : ℝ) (hσ : σ₁ < σ₂)
    (h1 : ηmin < y₁) (h12 : y₁ < y₂) (h2 : y₂ < ηmax) :
    ∃ c s : ℝ, 0 < s ∧
      feeRaw ηmin ηmax c s σ₁ = y₁ ∧ feeRaw ηmin ηmax c s σ₂ = y₂ := by
  -- Define the target logistic values (normalized fees)
  have hdiff : ηmax - ηmin > 0 := by linarith
  let r₁ := (y₁ - ηmin) / (ηmax - ηmin)
  let r₂ := (y₂ - ηmin) / (ηmax - ηmin)
  -- Show r₁, r₂ ∈ (0, 1)
  have hr1_pos : 0 < r₁ := div_pos (by linarith) hdiff
  have hr1_lt_one : r₁ < 1 := by rw [div_lt_one hdiff]; linarith
  have hr2_pos : 0 < r₂ := div_pos (by linarith) hdiff
  have hr2_lt_one : r₂ < 1 := by rw [div_lt_one hdiff]; linarith
  have hr1_lt_r2 : r₁ < r₂ := by
    exact div_lt_div_of_pos_right (by linarith) hdiff
  -- Define the inverse logistic (logit) function
  let logit := fun r : ℝ => Real.log (r / (1 - r))
  have hlogit1 : logistic (logit r₁) = r₁ := by
    simp only [logistic, logit]
    have h1mr : 1 - r₁ > 0 := by linarith
    have hdiv_pos : r₁ / (1 - r₁) > 0 := div_pos hr1_pos h1mr
    rw [Real.exp_neg, Real.exp_log hdiv_pos]
    field_simp
    ring
  have hlogit2 : logistic (logit r₂) = r₂ := by
    simp only [logistic, logit]
    have h1mr : 1 - r₂ > 0 := by linarith
    have hdiv_pos : r₂ / (1 - r₂) > 0 := div_pos hr2_pos h1mr
    rw [Real.exp_neg, Real.exp_log hdiv_pos]
    field_simp
    ring
  -- Since r₁ < r₂ and logit is strictly monotone on (0, 1), logit r₁ < logit r₂
  have hz_lt : logit r₁ < logit r₂ := by
    simp only [logit]
    have h1 : r₁ / (1 - r₁) > 0 := div_pos hr1_pos (by linarith)
    have h2 : r₂ / (1 - r₂) > 0 := div_pos hr2_pos (by linarith)
    have hlt : r₁ / (1 - r₁) < r₂ / (1 - r₂) := by
      have h1r1 : 1 - r₁ > 0 := by linarith
      have h1r2 : 1 - r₂ > 0 := by linarith
      have : r₁ * (1 - r₂) < r₂ * (1 - r₁) := by nlinarith
      nlinarith [mul_pos hr1_pos h1r2, mul_pos hr2_pos h1r1, 
                 mul_pos hr1_pos h1r1, mul_pos hr2_pos h1r2,
                 div_mul_cancel₀ r₁ (ne_of_gt h1r1),
                 div_mul_cancel₀ r₂ (ne_of_gt h1r2)]
    exact Real.log_lt_log h1 hlt
  -- Solve for s and c
  -- (σ₁ - c) / s = logit r₁  =>  σ₁ - c = s * logit r₁
  -- (σ₂ - c) / s = logit r₂  =>  σ₂ - c = s * logit r₂
  -- Subtract: σ₂ - σ₁ = s * (logit r₂ - logit r₁)
  -- So s = (σ₂ - σ₁) / (logit r₂ - logit r₁)
  let s := (σ₂ - σ₁) / (logit r₂ - logit r₁)
  have hs_pos : 0 < s := by
    apply div_pos <;> linarith
  let c := σ₁ - s * logit r₁
  use c, s
  refine ⟨hs_pos, ?_, ?_⟩
  · -- Verify feeRaw ηmin ηmax c s σ₁ = y₁
    simp only [feeRaw]
    have hne : ηmax - ηmin ≠ 0 := ne_of_gt hdiff
    have harg : (σ₁ - c) / s = logit r₁ := by
      simp only [c]
      field_simp
      ring
    rw [harg, hlogit1]
    simp only [r₁]
    field_simp [hne]
    ring
  · -- Verify feeRaw ηmin ηmax c s σ₂ = y₂
    simp only [feeRaw]
    have hne : ηmax - ηmin ≠ 0 := ne_of_gt hdiff
    have harg : (σ₂ - c) / s = logit r₂ := by
      simp only [c]
      have hsne : s ≠ 0 := ne_of_gt hs_pos
      have hdiff_logit : logit r₂ - logit r₁ ≠ 0 := by linarith
      field_simp [hsne, hdiff_logit]
      simp only [s]
      field_simp [hdiff_logit]
      ring
    rw [harg, hlogit2]
    simp only [r₂]
    field_simp [hne]
    ring

/-
**Calibration is exactly identified.**  The two-point calibration of the
previous lemma is unique: with the floor/plateau fixed and strictly
interior targets, exactly one `(c, s)` with `s > 0` fits.  (Targets *equal*
to `η_min`/`η_max` are unreachable — the open-interval constraint is
inherent to the sigmoid family, not incidental.)
-/
lemma feeRaw_interpolate_unique (ηmin ηmax σ₁ σ₂ y₁ y₂ : ℝ) (hσ : σ₁ < σ₂)
    (h1 : ηmin < y₁) (h12 : y₁ < y₂) (h2 : y₂ < ηmax) :
    ∃! cs : ℝ × ℝ, 0 < cs.2 ∧
      feeRaw ηmin ηmax cs.1 cs.2 σ₁ = y₁ ∧
      feeRaw ηmin ηmax cs.1 cs.2 σ₂ = y₂ := by
  -- Define the target logistic values
  let r₁ := (y₁ - ηmin) / (ηmax - ηmin)
  let r₂ := (y₂ - ηmin) / (ηmax - ηmin)
  have hdiff : ηmax - ηmin > 0 := by linarith
  have hr1_pos : 0 < r₁ := div_pos (by linarith) hdiff
  have hr1_lt_one : r₁ < 1 := by rw [div_lt_one hdiff]; linarith
  have hr2_pos : 0 < r₂ := div_pos (by linarith) hdiff
  have hr2_lt_one : r₂ < 1 := by rw [div_lt_one hdiff]; linarith
  have hr1_lt_r2 : r₁ < r₂ := by
    have : (y₁ - ηmin) / (ηmax - ηmin) < (y₂ - ηmin) / (ηmax - ηmin) :=
      div_lt_div_of_pos_right (by linarith : y₁ - ηmin < y₂ - ηmin) hdiff
    exact this
  -- Get existence from feeRaw_interpolate
  obtain ⟨c, s, hs, hσ1, hσ2⟩ := feeRaw_interpolate ηmin ηmax σ₁ σ₂ y₁ y₂ hσ h1 h12 h2
  use (c, s)
  constructor
  · exact ⟨hs, hσ1, hσ2⟩
  · -- Prove uniqueness
    intro ⟨c', s'⟩ ⟨hs', hσ1', hσ2'⟩
    -- From feeRaw definition: feeRaw ηmin ηmax c s σ = ηmin + (ηmax - ηmin) * logistic((σ - c) / s)
    have hr1_eq : logistic ((σ₁ - c) / s) = r₁ := by
      have h := hσ1
      simp only [feeRaw] at h
      have hne : ηmax - ηmin ≠ 0 := ne_of_gt hdiff
      have h2 : (ηmax - ηmin) * logistic ((σ₁ - c) / s) = y₁ - ηmin := by linarith
      rw [mul_comm] at h2
      exact eq_div_of_mul_eq hne h2
    have hr1_eq' : logistic ((σ₁ - c') / s') = r₁ := by
      have h := hσ1'
      simp only [feeRaw] at h
      have hne : ηmax - ηmin ≠ 0 := ne_of_gt hdiff
      have h2 : (ηmax - ηmin) * logistic ((σ₁ - c') / s') = y₁ - ηmin := by linarith
      rw [mul_comm] at h2
      exact eq_div_of_mul_eq hne h2
    have hr2_eq : logistic ((σ₂ - c) / s) = r₂ := by
      have h := hσ2
      simp only [feeRaw] at h
      have hne : ηmax - ηmin ≠ 0 := ne_of_gt hdiff
      have h2 : (ηmax - ηmin) * logistic ((σ₂ - c) / s) = y₂ - ηmin := by linarith
      rw [mul_comm] at h2
      exact eq_div_of_mul_eq hne h2
    have hr2_eq' : logistic ((σ₂ - c') / s') = r₂ := by
      have h := hσ2'
      simp only [feeRaw] at h
      have hne : ηmax - ηmin ≠ 0 := ne_of_gt hdiff
      have h2 : (ηmax - ηmin) * logistic ((σ₂ - c') / s') = y₂ - ηmin := by linarith
      rw [mul_comm] at h2
      exact eq_div_of_mul_eq hne h2
    -- By injectivity of logistic (from strict monotonicity)
    have heq1 : (σ₁ - c) / s = (σ₁ - c') / s' := logistic_strictMono.injective (hr1_eq.trans hr1_eq'.symm)
    have heq2 : (σ₂ - c) / s = (σ₂ - c') / s' := logistic_strictMono.injective (hr2_eq.trans hr2_eq'.symm)
    -- Subtract: (σ₂ - σ₁) / s = (σ₂ - σ₁) / s'
    have hs_eq_hs' : s = s' := by
      have hne_s : s ≠ 0 := ne_of_gt hs
      have hne_s' : s' ≠ 0 := ne_of_gt hs'
      have hne_diff : σ₂ - σ₁ ≠ 0 := by linarith
      -- Cross-multiply: s' * (σ₁ - c) = s * (σ₁ - c') and s' * (σ₂ - c) = s * (σ₂ - c')
      have eq1 := heq1
      have eq2 := heq2
      rw [div_eq_div_iff hne_s hne_s'] at eq1 eq2
      -- eq1: s' * (σ₁ - c) = s * (σ₁ - c')
      -- eq2: s' * (σ₂ - c) = s * (σ₂ - c')
      -- Subtracting: s' * (σ₂ - σ₁) = s * (σ₂ - σ₁)
      have key : s' * (σ₂ - σ₁) = s * (σ₂ - σ₁) := by linarith
      exact mul_left_injective₀ hne_diff key.symm
    -- Now derive c = c' from heq1 and s = s'
    have hc_eq_hc' : c = c' := by
      have hne_s : s ≠ 0 := ne_of_gt hs
      rw [← hs_eq_hs'] at heq1
      -- heq1 : (σ₁ - c) / s = (σ₁ - c') / s
      have heq2' := div_mul_cancel₀ (σ₁ - c) hne_s
      have heq2'' := div_mul_cancel₀ (σ₁ - c') hne_s
      have h1 : σ₁ - c = σ₁ - c' := by
        calc σ₁ - c = (σ₁ - c) / s * s := by rw [heq2']
          _ = (σ₁ - c') / s * s := by rw [heq1]
          _ = σ₁ - c' := by rw [heq2'']
      linarith
    simp [hs_eq_hs', hc_eq_hc']

/-
**Optimizer interface (generic extreme value theorem).**  For any
continuous objective `J` on a nonempty compact parameter set `Θ ⊆ ℝ⁴`, a
maximizing parameter choice exists.  This is deliberately generic — it
mentions neither `Params` nor `fee`; it records the interface under which
an estimated LP objective (expected PnL / fee return-on-capital) is fitted
over a compact box of schedule parameters.
-/
lemma exists_optimal_params (Θ : Set (ℝ × ℝ × ℝ × ℝ)) (hΘ : IsCompact Θ)
    (hne : Θ.Nonempty) (J : ℝ × ℝ × ℝ × ℝ → ℝ) (hJ : ContinuousOn J Θ) :
    ∃ θ ∈ Θ, ∀ θ' ∈ Θ, J θ' ≤ J θ := by
  obtain ⟨θ, hθ, hmax⟩ := hΘ.exists_isMaxOn hne hJ
  exact ⟨θ, hθ, fun θ' hθ' => hmax hθ'⟩

/-! ## 6. Halt extension and the bridge to the risk-price layer -/

/-- Fee schedule with a halt threshold: past `σ_halt` the fee jumps to the
prohibitive level `η_halt` (the paper's `η¹ = ∞` regime, encoded finitely). -/
noncomputable def feeHalt (P : Params) (σhalt ηhalt : ℝ) (σ : ℝ) : ℝ :=
  if σ < σhalt then fee P σ else ηhalt

/-
**Monotone halt schedule.**  If the prohibitive level dominates the plateau,
the halted schedule remains monotone in `σ`.
-/
lemma feeHalt_monotone (P : Params) (σhalt ηhalt : ℝ)
    (hle : P.etaMin ≤ P.etaMax) (hs : 0 < P.slope)
    (hhalt : P.etaMax ≤ ηhalt) :
    Monotone (feeHalt P σhalt ηhalt) := by
  intro x y hxy
  by_cases hx : x < σhalt
  · by_cases hy : y < σhalt
    · simp only [feeHalt, hx, hy, if_true]
      exact fee_monotone P hle hs hxy
    · simp only [feeHalt, hx, hy, if_true, if_false]
      exact (fee_mem_Icc P x hle).2.trans hhalt
  · have hy : ¬ y < σhalt := fun h => hx (hxy.trans_lt h)
    simp only [feeHalt, hx, hy, if_false]
    exact le_rfl

/-
**Admissible premium.**  A sigmoid fee with `0 ≤ η_min` and `η_max ≤ 1` takes
values in `[0,1]`, hence is an admissible premium for the buffered risk price
(`RISK_ALTERNATIVES.md`, P1: `p_risk = oracle · (1 + premium)`).
-/
lemma fee_mem_unit (P : Params) (σ : ℝ) (h0 : 0 ≤ P.etaMin)
    (hle : P.etaMin ≤ P.etaMax) (h1 : P.etaMax ≤ 1) :
    fee P σ ∈ Set.Icc (0 : ℝ) 1 := by
  obtain ⟨hl, hu⟩ := fee_mem_Icc P σ hle
  exact ⟨h0.trans hl, hu.trans h1⟩

/-
**Typed bridge to the formalized P1.**  For a unit-interval sigmoid fee the
`RiskDesign.riskPriceBuffered` premium clamp is the identity, so the
schedule composes with the *formalized* risk price, not a lookalike:
`riskPriceBuffered oracle (fee P σ) = oracle · (1 + fee P σ)`.
-/
lemma riskPriceBuffered_fee (P : Params) (oracle σ : ℝ) (h0 : 0 ≤ P.etaMin)
    (hle : P.etaMin ≤ P.etaMax) (h1 : P.etaMax ≤ 1) :
    RiskDesign.riskPriceBuffered oracle (fee P σ)
      = oracle * (1 + fee P σ) := by
  rw [RiskDesign.riskPriceBuffered,
    RiskDesign.clamp01_eq_self (fee_mem_unit P σ h0 hle h1).1
      (fee_mem_unit P σ h0 hle h1).2]

/-
**Risk price responds monotonically to realized volatility (P1).**  Feeding
the sigmoid fee as the premium of the formalized buffered risk price yields
a `p_risk` monotone in `σ` — the vol-instrument coupling of the schedule.
(No unit-interval hypotheses needed: the clamp `clamp01` is itself
monotone.)
-/
lemma riskPrice_sigmoid_mono (P : Params) (oracle : ℝ) (h0 : 0 ≤ oracle)
    (hle : P.etaMin ≤ P.etaMax) (hs : 0 < P.slope) :
    Monotone (fun σ => RiskDesign.riskPriceBuffered oracle (fee P σ)) := by
  intro x y hxy
  simp only [RiskDesign.riskPriceBuffered]
  apply mul_le_mul_of_nonneg_left _ h0
  apply add_le_add_right _ 1
  unfold RiskDesign.clamp01
  exact max_le_max_left 0 (min_le_min_left 1 (fee_monotone P hle hs hxy))

/-
**P2 coupling.**  The conservative composition P2 of `RISK_ALTERNATIVES.md`
is P1 with the oracle instantiated at `riskPriceMax spot twap`; the
monotone response to realized volatility carries over.
-/
lemma riskPriceP2_sigmoid_mono (P : Params) (spot twap : ℝ) (h0 : 0 ≤ spot)
    (hle : P.etaMin ≤ P.etaMax) (hs : 0 < P.slope) :
    Monotone (fun σ =>
      RiskDesign.riskPriceBuffered (RiskDesign.riskPriceMax spot twap)
        (fee P σ)) := by
  apply riskPrice_sigmoid_mono P (RiskDesign.riskPriceMax spot twap)
  · exact h0.trans (le_max_left _ _)
  · exact hle
  · exact hs

end FeeSchedule
