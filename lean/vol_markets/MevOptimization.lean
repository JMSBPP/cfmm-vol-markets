import Mathlib
import vol_markets.VolInstrument
import vol_markets.FlairOptimization

open scoped BigOperators Topology

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Arbitrage-channel hazard minimization

This module formalizes blocks M0--M5 of the MEV section of
`VOLATILITY_INSTRUMENTS.md`.  Except for the optional exact kernel (which is not
needed by the optimization program), the model uses the leading-order,
fast-block, small-fee factorization `ARB ≈ LVR · P_trade` from the anchor's
equation (12).  It is an asymptotic approximation, not an exact identity at
finite `Δt`.

The `lambda_ARB` objective formalized here has no demand response to the fee.
Its corner solution is consequently a property of the stated objective, not a
market-equilibrium claim.  The omitted term is the anchor's section 7.3,
equation (27): `E[delta-hedged LP P&L] = E[NT_FEE] - E[ARB]`.

Finally, `P_trade` is a steady-state quantity derived for constant parameters.
Applying it stepwise along a path with varying volatility is the document's
quasi-static extension, not a claim of the anchor paper, and "is legitimate
only if the parameters move slowly relative to mixing of the mispricing
process".
-/

namespace MevOptimization

/-- The steady-state probability that a block carries a profitable arbitrage. -/
noncomputable def ptrade (φ σ Δt : ℝ) : ℝ :=
  σ / (σ + φ * Real.sqrt (2 / Δt))

/-- The discrete arbitrage-channel hazard.  Here `a t ≥ 0` is the per-step
(per-block) arbitrage-opportunity weight: a MODELLED STEADY-STATE EXPECTATION,
the leading-order LVR, and not realized arbitrage profit.  LVR itself is the
Milionis-Angeris-Roughgarden-Moallemi [2022] rate `(σ²/8)·V(P)` quoted just
before the anchor's equation (12); equation (12) is the SPLIT
`ARB ≈ LVR · P_trade`, not LVR's definition.  The explicit `Δt` in the CPMM
weight converts that rate per unit time into the per-block amount required by
this sum (block M3(i)).  `D t > 0` is the SAME deployed-capital denominator as
`FlairOptimization.flairHazard`, making the hazards commensurable.  The split
is only the fast-block, small-fee asymptotic, not an exact finite-`Δt` identity.

Naming caveat: this object is `λ_ARB`, a SUMMAND of `λ_MEV` and not a sibling of it; it equals `λ_MEV` only under block M7's uniform-clearing reduction (`λ_sandwich = 0`), which is NOT formalized in this bundle. -/
noncomputable def mevHazard (φfun : ℝ → ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ)
    (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T, ptrade (φfun (σpath t)) (σpath t) Δt * a t / D t

/-- The arbitrage-channel hazard specialized to the multi-sigmoid fee.  Here
`a t ≥ 0` is a MODELLED STEADY-STATE EXPECTATION (leading-order LVR), not
realized profit; its CPMM per-step form is `(σ_t²/8)·V_t·Δt` because LVR is a
rate.  `D t > 0` is the SAME deployed-capital denominator as in
`FlairOptimization.flairHazard`.  The factorization is the anchor's
fast-block, small-fee approximation and is not exact at finite `Δt`.

Naming caveat: this object is `λ_ARB`, a SUMMAND of `λ_MEV` and not a sibling of it; it equals `λ_MEV` only under block M7's uniform-clearing reduction (`λ_sandwich = 0`), which is NOT formalized in this bundle. -/
noncomputable def mevMulti (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) : ℝ :=
  mevHazard (VolInstrument.multiFee n γ β α φbar u) σpath a D Δt T

private lemma sqrt_factor_pos (Δt : ℝ) (hΔt : 0 < Δt) :
    0 < Real.sqrt (2 / Δt) := by
  apply Real.sqrt_pos.mpr
  exact div_pos zero_lt_two hΔt

/-- T1. For nonnegative fees and positive volatility and block time,
`P_trade ∈ (0,1]`. -/
theorem ptrade_mem_Ioc (φ σ Δt : ℝ) (hφ : 0 ≤ φ) (hσ : 0 < σ)
    (hΔt : 0 < Δt) : ptrade φ σ Δt ∈ Set.Ioc 0 1 := by
  unfold ptrade
  constructor
  · apply div_pos hσ
    apply add_pos_of_pos_of_nonneg hσ
    apply mul_nonneg hφ
    exact Real.sqrt_nonneg (2 / Δt)
  · rw [div_le_one (by linarith [mul_nonneg hφ (Real.sqrt_nonneg (2 / Δt))])]
    linarith [mul_nonneg hφ (Real.sqrt_nonneg (2 / Δt))]

/-- T2. A nonnegative fee gives trade probability one exactly when it is zero. -/
theorem ptrade_eq_one_iff (φ σ Δt : ℝ) (hφ : 0 ≤ φ) (hσ : 0 < σ)
    (hΔt : 0 < Δt) : ptrade φ σ Δt = 1 ↔ φ = 0 := by
  unfold ptrade
  have hsqrt_pos : 0 < Real.sqrt (2 / Δt) := sqrt_factor_pos Δt hΔt
  constructor
  · intro h
    have hdenom_pos : 0 < σ + φ * Real.sqrt (2 / Δt) := by
      nlinarith
    rw [div_eq_one_iff_eq] at h <;> try linarith
    nlinarith
  · intro hφ0
    simp [hφ0, hσ.ne']

/-- T3. Trade probability is strictly decreasing in the nonnegative fee. -/
theorem ptrade_strictAntiOn (σ Δt : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt) :
    StrictAntiOn (fun φ => ptrade φ σ Δt) (Set.Ici 0) := by
  intro x hx y hy hxy
  simp only [ptrade]
  apply div_lt_div_of_pos_left hσ (by
    have hsqrt_pos : 0 < Real.sqrt (2 / Δt) := Real.sqrt_pos.mpr (div_pos zero_lt_two hΔt)
    have : 0 ≤ x * Real.sqrt (2 / Δt) := mul_nonneg hx (le_of_lt hsqrt_pos)
    linarith) (by
    have hsqrt_pos : 0 < Real.sqrt (2 / Δt) := Real.sqrt_pos.mpr (div_pos zero_lt_two hΔt)
    nlinarith)

/-- T4. Longer mean interblock time weakly raises trade probability. -/
theorem ptrade_monotoneOn_dt (φ σ : ℝ) (hφ : 0 ≤ φ) (hσ : 0 < σ) :
    MonotoneOn (fun Δt => ptrade φ σ Δt) (Set.Ioi 0) := by
  intro Δt₁ hΔt₁ Δt₂ hΔt₂ hle
  simp only [Set.mem_Ioi] at hΔt₁ hΔt₂
  simp only [ptrade]
  apply div_le_div_of_nonneg_left _ _ _
  · exact le_of_lt hσ
  · exact add_pos_of_pos_of_nonneg hσ (mul_nonneg hφ (Real.sqrt_nonneg _))
  · have h1 : 2 / Δt₂ ≤ 2 / Δt₁ := by gcongr
    have h2 : φ * Real.sqrt (2 / Δt₂) ≤ φ * Real.sqrt (2 / Δt₁) := mul_le_mul_of_nonneg_left (Real.sqrt_le_sqrt h1) hφ
    linarith

/-- T4 companion. Trade probability is weakly increasing in volatility. -/
theorem ptrade_monotoneOn_sigma (φ Δt : ℝ) (hφ : 0 ≤ φ) (hΔt : 0 < Δt) :
    MonotoneOn (fun σ => ptrade φ σ Δt) (Set.Ioi 0) := by
  intro σ₁ h₁ σ₂ h₂ hle
  simp only [Set.mem_Ioi] at h₁ h₂
  simp only [ptrade]
  have hc : 0 ≤ φ * Real.sqrt (2 / Δt) := mul_nonneg hφ (Real.sqrt_nonneg _)
  have denom1_pos : 0 < σ₁ + φ * Real.sqrt (2 / Δt) := by linarith
  have denom2_pos : 0 < σ₂ + φ * Real.sqrt (2 / Δt) := by linarith
  rw [div_le_div_iff₀ denom1_pos denom2_pos]
  nlinarith [sq_nonneg (σ₁ - σ₂)]

/-- T5. Trade probability vanishes as the fee tends to infinity. -/
theorem ptrade_tendsto_atTop (σ Δt : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt) :
    Filter.Tendsto (fun φ => ptrade φ σ Δt) Filter.atTop (nhds 0) := by
  unfold ptrade
  have hsq : 0 < Real.sqrt (2 / Δt) := sqrt_factor_pos Δt hΔt
  -- The denominator σ + φ * sqrt(2/Δt) → ∞ as φ → ∞
  have hdenom : Filter.Tendsto (fun φ => σ + φ * Real.sqrt (2 / Δt)) Filter.atTop Filter.atTop := by
    have h1 : Filter.Tendsto (fun φ : ℝ => φ * Real.sqrt (2 / Δt)) Filter.atTop Filter.atTop :=
      Filter.tendsto_id.atTop_mul_const hsq
    exact Filter.Tendsto.add_atTop (tendsto_const_nhds) h1
  exact hdenom.const_div_atTop σ

/-- T6. Trade probability is strictly convex on nonnegative fees.  This is the
load-bearing strict form used by downstream strict Jensen arguments. -/
theorem ptrade_strictConvexOn (σ Δt : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt) :
    StrictConvexOn ℝ (Set.Ici 0) (fun φ => ptrade φ σ Δt) := by
  let c := Real.sqrt (2 / Δt)
  have hc : 0 < c := Real.sqrt_pos.mpr (div_pos zero_lt_two hΔt)
  have h_denom_pos : ∀ φ ∈ Set.Ici (0 : ℝ), 0 < σ + φ * c := by
    intro φ hφ
    exact add_pos_of_pos_of_nonneg hσ (mul_nonneg hφ.out hc.le)
  -- ptrade φ σ Δt = σ / (σ + φ * c)
  have h_eq : (fun φ => ptrade φ σ Δt) = fun φ => σ * (σ + φ * c)⁻¹ := by
    ext φ
    rw [ptrade, div_eq_mul_inv]
  rw [h_eq]
  refine ⟨convex_Ici 0, ?_⟩
  intro x hx y hy hxy a b ha hb hab
  simp only [smul_eq_mul]
  -- Let X = σ + x * c, Y = σ + y * c
  set X := σ + x * c with hXdef
  set Y := σ + y * c with hYdef
  have hX : 0 < X := h_denom_pos x hx
  have hY : 0 < Y := h_denom_pos y hy
  have hXY : X ≠ Y := by
    intro h
    apply hxy
    have : x * c = y * c := by linarith
    exact mul_right_cancel₀ hc.ne' this
  -- Key: σ + (a * x + b * y) * c = a * X + b * Y
  have h_comb : σ + (a * x + b * y) * c = a * X + b * Y := by
    rw [hXdef, hYdef]
    have : b = 1 - a := by linarith
    rw [this]
    ring
  rw [h_comb]
  -- Need: σ * (a * X + b * Y)⁻¹ < a * (σ * X⁻¹) + b * (σ * Y⁻¹)
  have h_rhs : a * (σ * X⁻¹) + b * (σ * Y⁻¹) = σ * (a * X⁻¹ + b * Y⁻¹) := by ring
  rw [h_rhs]
  apply mul_lt_mul_of_pos_left _ hσ
  -- Need: (a * X + b * Y)⁻¹ < a * X⁻¹ + b * Y⁻¹
  have h_prod_pos : 0 < a * X + b * Y := add_pos (mul_pos ha hX) (mul_pos hb hY)
  have h_rhs_pos : 0 < a * X⁻¹ + b * Y⁻¹ := add_pos (mul_pos ha (inv_pos.mpr hX)) (mul_pos hb (inv_pos.mpr hY))
  rw [inv_eq_one_div, div_lt_iff₀ h_prod_pos]
  -- Need: 1 < (a * X⁻¹ + b * Y⁻¹) * (a * X + b * Y)
  -- Expand: = a² + b² + ab*(X/Y + Y/X) = 1 + ab*(X-Y)²/(XY) > 1
  have hXY_pos : 0 < X * Y := mul_pos hX hY
  have h_ab_pos : 0 < a * b := mul_pos ha hb
  have h_diff_sq : 0 < (X - Y) ^ 2 := sq_pos_of_ne_zero (sub_ne_zero.mpr hXY)
  -- (a * X⁻¹ + b * Y⁻¹) * (a * X + b * Y) = a² + b² + ab*(X/Y + Y/X)
  have h_expand : (a * X⁻¹ + b * Y⁻¹) * (a * X + b * Y) = a^2 + b^2 + a * b * (X / Y + Y / X) := by
    field_simp
    ring
  rw [h_expand]
  -- a² + b² = (a+b)² - 2ab = 1 - 2ab
  have h_sq_sum : a^2 + b^2 = 1 - 2 * a * b := by
    have : a + b = 1 := hab
    nlinarith [sq_nonneg a, sq_nonneg b]
  rw [h_sq_sum]
  -- Need: 1 < 1 - 2ab + ab*(X/Y + Y/X) = 1 + ab*((X/Y + Y/X) - 2)
  -- It suffices to show X/Y + Y/X > 2 when X ≠ Y
  have h_am_gm : X / Y + Y / X > 2 := by
    have h1 : X / Y > 0 := div_pos hX hY
    have h2 : Y / X > 0 := div_pos hY hX
    have h3 : X / Y ≠ 1 := by
      intro heq
      apply hXY
      rw [div_eq_one_iff_eq] at heq <;> linarith
    have h5 : X / Y * (Y / X) = 1 := by field_simp
    have h4 : 0 < (X / Y - 1) ^ 2 := by
      apply sq_pos_of_ne_zero
      exact sub_ne_zero.mpr h3
    nlinarith [sq_nonneg (X / Y - 1)]
  nlinarith

/-- T6 weakening, named explicitly for non-strict consumers. -/
theorem ptrade_convexOn (σ Δt : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt) :
    ConvexOn ℝ (Set.Ici 0) (fun φ => ptrade φ σ Δt) := by
  exact (ptrade_strictConvexOn σ Δt hσ hΔt).convexOn

/-- T7. This is a **bridge identity** — a ring tautology that lets the anchor's
Theorem 3 / Theorem 4 split be quoted in Lean notation — and it is NOT a
formalization of those theorems, which are asymptotic approximations and are
not formalized here. -/
theorem arb_add_fee_eq_lvr (lvr φ σ Δt : ℝ) :
    lvr * ptrade φ σ Δt + lvr * (1 - ptrade φ σ Δt) = lvr := by
  ring

/-- T8. Positivity of the CPMM leading-order per-block opportunity weight.
The `Δt` factor is essential: LVR is a rate per unit time, while the hazard sum
requires a per-block amount.  No exact-kernel finiteness guard is needed. -/
theorem mevWeight_cpmm_pos (σpath V : ℕ → ℝ) (Δt : ℝ) (t : ℕ)
    (hσ : 0 < σpath t) (hV : 0 < V t) (hΔt : 0 < Δt) :
    0 < σpath t ^ 2 / 8 * V t * Δt := by positivity

private theorem mevMulti_fee_nonneg (n : ℕ) (γ β α : ℕ → ℝ) (φbar u σ : ℝ)
    (hφ : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u) :
    0 ≤ VolInstrument.multiFee n γ β α φbar u σ := by
  have hα' : ∀ j ∈ Finset.range n, 0 ≤ α j := fun j hj => hα j (Finset.mem_range.mp hj)
  have := VolInstrument.multiFee_bounds n γ β α φbar u σ hα' hu
  linarith

/-- T8 companion. Under the model's positivity assumptions, the specialized
arbitrage hazard is nonnegative. -/
theorem mevMulti_nonneg (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt)
    (hφ : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u) :
    0 ≤ mevMulti n γ β α φbar u σpath a D Δt T := by
  unfold mevMulti mevHazard
  apply Finset.sum_nonneg
  intro t ht
  -- Need to show ptrade * a t / D t ≥ 0
  apply div_nonneg
  apply mul_nonneg
  · -- ptrade ≥ 0 when fee ≥ 0 and σ > 0
    have hterm_nonneg : ∀ j < n, 0 ≤ α j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
      intro j hj
      apply mul_nonneg (hα j hj)
      exact le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
    have hsum_nonneg : 0 ≤ ∑ j ∈ Finset.range n, α j * FeeSchedule.logistic (γ j * (σpath t - β j)) :=
      Finset.sum_nonneg (fun j hj => hterm_nonneg j (Finset.mem_range.mp hj))
    have hfee_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
      rw [VolInstrument.multiFee]
      exact add_nonneg hφ (mul_nonneg hsum_nonneg hu)
    exact le_of_lt (ptrade_mem_Ioc (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt hfee_nonneg (hσ t (Finset.mem_range.mp ht)) hΔt).1
  · -- a t ≥ 0
    exact ha t (Finset.mem_range.mp ht)
  · -- D t > 0 implies D t ≥ 0
    exact le_of_lt (hD t (Finset.mem_range.mp ht))

private theorem mevMulti_antitone_of_fee_le
    (n : ℕ) (γ β α α' : ℕ → ℝ) (φbar φbar' u u' : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hfee : ∀ t < T,
      VolInstrument.multiFee n γ β α φbar u (σpath t) ≤
        VolInstrument.multiFee n γ β α' φbar' u' (σpath t))
    (hfee0 : ∀ t < T, 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t))
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    mevMulti n γ β α' φbar' u' σpath a D Δt T ≤
      mevMulti n γ β α φbar u σpath a D Δt T := by
  unfold mevMulti mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have hfee_le := hfee t ht'
  have hfee0' := hfee0 t ht'
  have hσ_t := hσ t ht'
  have hD_t := hD t ht'
  have ha_t := ha t ht'
  -- fee₁ ≤ fee₂ and fee₁ ≥ 0, so fee₂ ≥ 0
  have hfee2_nonneg : 0 ≤ VolInstrument.multiFee n γ β α' φbar' u' (σpath t) := le_trans hfee0' hfee_le
  -- ptrade is strictly antitone, so ptrade fee₂ ≤ ptrade fee₁
  have hanti := ptrade_strictAntiOn (σpath t) Δt hσ_t hΔt
  -- Since fee₁ ≤ fee₂, we have ptrade fee₂ ≤ ptrade fee₁
  by_cases h_eq : VolInstrument.multiFee n γ β α φbar u (σpath t) = 
                 VolInstrument.multiFee n γ β α' φbar' u' (σpath t)
  · rw [h_eq]
  · have h_lt : VolInstrument.multiFee n γ β α φbar u (σpath t) < 
                VolInstrument.multiFee n γ β α' φbar' u' (σpath t) := lt_of_le_of_ne hfee_le h_eq
    have hptrade_lt : ptrade (VolInstrument.multiFee n γ β α' φbar' u' (σpath t)) (σpath t) Δt < 
                      ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt := 
      hanti hfee0' hfee2_nonneg h_lt
    have hle : ptrade (VolInstrument.multiFee n γ β α' φbar' u' (σpath t)) (σpath t) Δt ≤ 
               ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt := le_of_lt hptrade_lt
    have hmul : ptrade (VolInstrument.multiFee n γ β α' φbar' u' (σpath t)) (σpath t) Δt * a t ≤ 
                ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt * a t := 
      mul_le_mul_of_nonneg_right hle ha_t
    exact div_le_div_of_nonneg_right hmul (le_of_lt hD_t)

/-- T9. Raising the fee floor strictly lowers the hazard whenever at least one
step has strictly positive opportunity weight. -/
theorem mevMulti_anti_phibar (n : ℕ) (γ β α : ℕ → ℝ)
    (φbar φbar' u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hφlt : φbar < φbar') (hD : ∀ t < T, 0 < D t)
    (ha : ∀ t < T, 0 ≤ a t) (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt)
    (hφ : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u) :
    mevMulti n γ β α φbar' u σpath a D Δt T <
      mevMulti n γ β α φbar u σpath a D Δt T := by
  unfold mevMulti
  -- First show multiFee is strictly increasing in φbar
  have hfee_lt : ∀ t < T,
      VolInstrument.multiFee n γ β α φbar u (σpath t) <
        VolInstrument.multiFee n γ β α φbar' u (σpath t) := by
    intro t ht
    unfold VolInstrument.multiFee
    linarith
  -- Get the t₀ where a t₀ > 0
  obtain ⟨t₀, ht₀T, ha_pos₀⟩ := ha_pos
  -- Each ptrade term with φbar' is ≤ the term with φbar
  have hterm_le : ∀ t < T,
      ptrade (VolInstrument.multiFee n γ β α φbar' u (σpath t)) (σpath t) Δt * a t / D t ≤
      ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt * a t / D t := by
    intro t ht
    have hf := hfee_lt t ht
    have hptrade_le : ptrade (VolInstrument.multiFee n γ β α φbar' u (σpath t)) (σpath t) Δt ≤
        ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt := by
      have hanti := ptrade_strictAntiOn (σpath t) Δt (hσ t ht) hΔt
      have hfee_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
        have := VolInstrument.multiFee_bounds n γ β α φbar u (σpath t) (fun j hj => hα j (Finset.mem_range.mp hj)) hu
        linarith
      have hfee_nonneg' : 0 ≤ VolInstrument.multiFee n γ β α φbar' u (σpath t) := by
        have hφ' : 0 ≤ φbar' := by linarith
        exact VolInstrument.multiFee_bounds n γ β α φbar' u (σpath t) (fun j hj => hα j (Finset.mem_range.mp hj)) hu |>.1.trans' hφ'.ge
      exact le_of_lt (hanti hfee_nonneg hfee_nonneg' hf)
    apply div_le_div_of_nonneg_right (mul_le_mul_of_nonneg_right hptrade_le (ha t ht)) (le_of_lt (hD t ht))
  -- At t₀, the term is strictly smaller because a t₀ > 0 and ptrade is strictly decreasing
  have hterm_lt₀ : ptrade (VolInstrument.multiFee n γ β α φbar' u (σpath t₀)) (σpath t₀) Δt * a t₀ / D t₀ <
      ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t₀)) (σpath t₀) Δt * a t₀ / D t₀ := by
    have hf₀ := hfee_lt t₀ ht₀T
    have hanti := ptrade_strictAntiOn (σpath t₀) Δt (hσ t₀ ht₀T) hΔt
    have hfee_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t₀) :=
      VolInstrument.multiFee_bounds n γ β α φbar u (σpath t₀) (fun j hj => hα j (Finset.mem_range.mp hj)) hu |>.1.trans' hφ.ge
    have hfee_nonneg' : 0 ≤ VolInstrument.multiFee n γ β α φbar' u (σpath t₀) :=
      VolInstrument.multiFee_bounds n γ β α φbar' u (σpath t₀) (fun j hj => hα j (Finset.mem_range.mp hj)) hu |>.1.trans' (hφ.trans_lt hφlt).le
    have hptrade_lt : ptrade (VolInstrument.multiFee n γ β α φbar' u (σpath t₀)) (σpath t₀) Δt <
        ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t₀)) (σpath t₀) Δt := hanti hfee_nonneg hfee_nonneg' hf₀
    have hD_pos : 0 < D t₀ := hD t₀ ht₀T
    exact div_lt_div_of_pos_right (mul_lt_mul_of_pos_right hptrade_lt ha_pos₀) hD_pos
  exact Finset.sum_lt_sum (fun t ht => hterm_le t (Finset.mem_range.mp ht)) ⟨t₀, Finset.mem_range.mpr ht₀T, hterm_lt₀⟩

/-- T10. Coordinatewise larger nonnegative amplitudes weakly lower the
arbitrage hazard. -/
theorem mevMulti_anti_alpha (n : ℕ) (γ β α α' : ℕ → ℝ)
    (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hαle : ∀ j < n, α j ≤ α' j) (hu : 0 ≤ u)
    (hφ : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    mevMulti n γ β α' φbar u σpath a D Δt T ≤
      mevMulti n γ β α φbar u σpath a D Δt T := by
  unfold mevMulti mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have hfee_le : VolInstrument.multiFee n γ β α φbar u (σpath t) ≤
      VolInstrument.multiFee n γ β α' φbar u (σpath t) := by
    unfold VolInstrument.multiFee
    apply add_le_add_right
    apply mul_le_mul_of_nonneg_right _ hu
    · apply Finset.sum_le_sum
      intro j hj
      apply mul_le_mul_of_nonneg_right _ (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
      exact hαle j (Finset.mem_range.mp hj)
  have hfee0 : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
    unfold VolInstrument.multiFee
    apply add_nonneg hφ
    apply mul_nonneg _ hu
    apply Finset.sum_nonneg
    intro j hj
    apply mul_nonneg (hα j (Finset.mem_range.mp hj))
    exact le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
  have hfee0' : 0 ≤ VolInstrument.multiFee n γ β α' φbar u (σpath t) := le_trans hfee0 hfee_le
  have hptrade : ptrade (VolInstrument.multiFee n γ β α' φbar u (σpath t))
      (σpath t) Δt ≤ ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t))
      (σpath t) Δt := by
    have h := ptrade_strictAntiOn (σpath t) Δt (hσ t ht') hΔt
    exact h.antitoneOn (Set.mem_Ici.mpr hfee0) (Set.mem_Ici.mpr hfee0') hfee_le
  exact div_le_div_of_nonneg_right (mul_le_mul_of_nonneg_right hptrade (ha t ht')) (le_of_lt (hD t ht'))

/-- T11. Raising the nonnegative R-sigmoid factor weakly lowers the hazard. -/
theorem mevMulti_anti_u (n : ℕ) (γ β α : ℕ → ℝ)
    (φbar u u' : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hu : u ≤ u') (hu0 : 0 ≤ u) (hφ : 0 ≤ φbar)
    (hα : ∀ j < n, 0 ≤ α j)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    mevMulti n γ β α φbar u' σpath a D Δt T ≤
      mevMulti n γ β α φbar u σpath a D Δt T := by
  unfold mevMulti mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have ha_t : 0 ≤ a t := ha t ht'
  have hD_t : 0 < D t := hD t ht'
  have hσ_t : 0 < σpath t := hσ t ht'
  -- Need to show multiFee u' σpath t ≥ multiFee u σpath t
  have hfee_le : VolInstrument.multiFee n γ β α φbar u (σpath t) ≤
                 VolInstrument.multiFee n γ β α φbar u' (σpath t) := by
    unfold VolInstrument.multiFee
    have hsum_nonneg : 0 ≤ ∑ j ∈ Finset.range n, α j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
      apply Finset.sum_nonneg
      intro j hj
      apply mul_nonneg (hα j (Finset.mem_range.mp hj))
      exact le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
    nlinarith
  have hu'_nonneg : 0 ≤ u' := hu0.trans hu
  have h_fee_u'_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u' (σpath t) := by
      unfold VolInstrument.multiFee
      apply add_nonneg hφ
      apply mul_nonneg _ hu'_nonneg
      apply Finset.sum_nonneg
      intro j hj
      apply mul_nonneg (hα j (Finset.mem_range.mp hj))
      exact le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
  have h_fee_u_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
      unfold VolInstrument.multiFee
      apply add_nonneg hφ
      apply mul_nonneg _ hu0
      apply Finset.sum_nonneg
      intro j hj
      apply mul_nonneg (hα j (Finset.mem_range.mp hj))
      exact le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
  have h_ptrade_le : ptrade (VolInstrument.multiFee n γ β α φbar u' (σpath t)) (σpath t) Δt ≤
                     ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt := by
    rcases hfee_le.lt_or_eq with hfee_lt | hfee_eq
    · exact le_of_lt (ptrade_strictAntiOn (σ := σpath t) (Δt := Δt) hσ_t hΔt h_fee_u_nonneg h_fee_u'_nonneg hfee_lt)
    · rw [hfee_eq]
  have hweight_nonneg : 0 ≤ a t / D t := div_nonneg ha_t (le_of_lt hD_t)
  calc ptrade (VolInstrument.multiFee n γ β α φbar u' (σpath t)) (σpath t) Δt * a t / D t
      = ptrade (VolInstrument.multiFee n γ β α φbar u' (σpath t)) (σpath t) Δt * (a t / D t) := by ring
    _ ≤ ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt * (a t / D t) := by
        apply mul_le_mul_of_nonneg_right h_ptrade_le hweight_nonneg
    _ = ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt * a t / D t := by ring

/-- T12. Raising positive-slope sigmoid centers raises the arbitrage hazard. -/
theorem mevMulti_mono_beta (n : ℕ) (γ β β' α : ℕ → ℝ)
    (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hβ : ∀ j < n, β j ≤ β' j) (hγ : ∀ j < n, 0 < γ j)
    (hu : 0 ≤ u) (hα : ∀ j < n, 0 ≤ α j) (hφ : 0 ≤ φbar)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    mevMulti n γ β α φbar u σpath a D Δt T ≤
      mevMulti n γ β' α φbar u σpath a D Δt T := by
  unfold mevMulti mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  -- Key: multiFee with β ≥ multiFee with β' when β ≤ β'
  have hfee_le : VolInstrument.multiFee n γ β α φbar u (σpath t) ≥
      VolInstrument.multiFee n γ β' α φbar u (σpath t) := by
    unfold VolInstrument.multiFee
    simp only [ge_iff_le]
    have hsum_le : ∑ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β' j)) ≤
      ∑ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
      apply Finset.sum_le_sum
      intro j hj
      apply mul_le_mul_of_nonneg_left _ (hα j (Finset.mem_range.mp hj))
      apply FeeSchedule.logistic_strictMono.monotone
      nlinarith [hβ j (Finset.mem_range.mp hj), hγ j (Finset.mem_range.mp hj)]
    gcongr
  -- ptrade is anti-monotone, so higher fee means lower ptrade
  have hptrade_le : ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt ≤
      ptrade (VolInstrument.multiFee n γ β' α φbar u (σpath t)) (σpath t) Δt := by
    have hfee2_mem : VolInstrument.multiFee n γ β' α φbar u (σpath t) ∈ Set.Ici 0 := by
      have := VolInstrument.multiFee_bounds n γ β' α φbar u (σpath t)
        (fun j hj => hα j (Finset.mem_range.mp hj)) hu
      exact Set.mem_Ici.mpr (le_trans hφ this.1)
    have hfee1_mem : VolInstrument.multiFee n γ β α φbar u (σpath t) ∈ Set.Ici 0 := by
      have := VolInstrument.multiFee_bounds n γ β α φbar u (σpath t)
        (fun j hj => hα j (Finset.mem_range.mp hj)) hu
      exact Set.mem_Ici.mpr (le_trans hφ this.1)
    cases' (hfee_le.lt_or_eq) with hlt heq
    · exact le_of_lt (ptrade_strictAntiOn (σpath t) Δt (hσ t ht') hΔt hfee2_mem hfee1_mem hlt)
    · rw [heq]
  -- Now multiply by a t / D t ≥ 0
  have hrat_nonneg : 0 ≤ a t / D t := div_nonneg (ha t ht') (le_of_lt (hD t ht'))
  convert mul_le_mul_of_nonneg_right hptrade_le hrat_nonneg using 1 <;> ring

/-- T13. Uniform lower bound at the fee ceiling.  Unlike the affine FLAIR
bound, the right-hand side remains a path sum. -/
theorem mevMulti_ge_corner (n : ℕ) (γ β α αmax : ℕ → ℝ)
    (φbar φbarMax u uMax : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hφ : φbar ≤ φbarMax) (hφ0 : 0 ≤ φbar) (hu0 : 0 ≤ u)
    (hu : u ≤ uMax) (hα0 : ∀ j < n, 0 ≤ α j)
    (hα : ∀ j < n, α j ≤ αmax j)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    mevMulti n γ β α φbar u σpath a D Δt T ≥
      ∑ t ∈ Finset.range T,
        ptrade (φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j)
          (σpath t) Δt * a t / D t := by
  -- First establish that multiFee is bounded above by the corner value
  have hfee_le : ∀ t < T,
      VolInstrument.multiFee n γ β α φbar u (σpath t) ≤
        φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j := by
    intro t ht
    unfold VolInstrument.multiFee
    -- The sum term is bounded by ∑ α j since logistic ∈ (0,1) and α j ≥ 0
    have hterm_le : ∀ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j)) ≤ αmax j := by
      intro j hj
      have hj' : j < n := Finset.mem_range.mp hj
      have hαj : 0 ≤ α j := hα0 j hj'
      obtain ⟨hlog0, hlog1⟩ := FeeSchedule.logistic_mem_Ioo (γ j * (σpath t - β j))
      nlinarith [hα j hj']
    have hsum_le : ∑ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j)) ≤ ∑ j ∈ Finset.range n, αmax j :=
      Finset.sum_le_sum hterm_le
    -- Since sum is nonneg (logistic > 0, α ≥ 0), and u ≥ 0
    have hsum_nonneg : 0 ≤ ∑ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
      apply Finset.sum_nonneg
      intro j hj
      have hj' : j < n := Finset.mem_range.mp hj
      have hαj : 0 ≤ α j := hα0 j hj'
      exact mul_nonneg hαj (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
    nlinarith
  -- Now use ptrade_strictAntiOn to get the ptrade inequality
  have hptrade_ge : ∀ t < T,
      ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt ≥
        ptrade (φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j) (σpath t) Δt := by
    intro t ht
    have hσt : 0 < σpath t := hσ t ht
    have hΔt' : 0 < Δt := hΔt
    -- The multiFee is nonnegative
    have hfee_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
      unfold VolInstrument.multiFee
      have hsum_nonneg : 0 ≤ ∑ j ∈ Finset.range n,
          α j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
        apply Finset.sum_nonneg
        intro j hj
        have hj' : j < n := Finset.mem_range.mp hj
        exact mul_nonneg (hα0 j hj') (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
      nlinarith
    -- The corner fee is also nonnegative
    have hcorner_nonneg : 0 ≤ φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j := by
      have hαmax_nonneg : ∀ j ∈ Finset.range n, 0 ≤ αmax j := by
        intro j hj
        have hj' : j < n := Finset.mem_range.mp hj
        linarith [hα0 j hj', hα j hj']
      have hsum_max_nonneg : 0 ≤ ∑ j ∈ Finset.range n, αmax j :=
        Finset.sum_nonneg hαmax_nonneg
      have huMax_nonneg : 0 ≤ uMax := by linarith
      have hφbarMax_nonneg : 0 ≤ φbarMax := by linarith
      nlinarith
    -- Apply the antitone property of ptrade
    have hanti := ptrade_strictAntiOn (σpath t) Δt hσt hΔt'
    have hle := hfee_le t ht
    have ha₁ : (0 : ℝ) ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := hfee_nonneg
    have ha₂ : (0 : ℝ) ≤ φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j := hcorner_nonneg
    exact hanti.antitoneOn ha₁ ha₂ hle
  -- Now sum the term-by-term inequalities
  unfold mevMulti mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have hptr := hptrade_ge t ht'
  have ha_t := ha t ht'
  have hD_t := hD t ht'
  calc ptrade (φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j) (σpath t) Δt * a t / D t
      ≤ ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt * a t / D t := by
        gcongr

/-- T14. For a fixed shape block, the upper corner of the admissible level box
attains the minimum. -/
theorem mevMulti_corner_attained_levels (n : ℕ) (γ β α αmax : ℕ → ℝ)
    (φbar φbarMax u uMax : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hφ : φbar ≤ φbarMax) (hφ0 : 0 ≤ φbar) (hu0 : 0 ≤ u)
    (hu : u ≤ uMax) (hα0 : ∀ j < n, 0 ≤ α j)
    (hαmax0 : ∀ j < n, 0 ≤ αmax j) (hα : ∀ j < n, α j ≤ αmax j)
    (ha : ∀ t < T, 0 ≤ a t) (hD : ∀ t < T, 0 < D t)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    mevMulti n γ β αmax φbarMax uMax σpath a D Δt T ≤
      mevMulti n γ β α φbar u σpath a D Δt T := by
  -- multiFee is monotone in α, φbar, u
  have hfee_mono : ∀ t < T,
      VolInstrument.multiFee n γ β α φbar u (σpath t) ≤
        VolInstrument.multiFee n γ β αmax φbarMax uMax (σpath t) := by
    intro t ht
    unfold VolInstrument.multiFee
    -- φbar ≤ φbarMax
    have hφ_le : φbar ≤ φbarMax := hφ
    -- Each α j ≤ αmax j, and logistic ≥ 0, so α j * logistic ≤ αmax j * logistic
    have hterm_le : ∀ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j)) ≤
        αmax j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
      intro j hj
      have hj' : j < n := Finset.mem_range.mp hj
      have hαj : 0 ≤ α j := hα0 j hj'
      have hαmaxj : 0 ≤ αmax j := hαmax0 j hj'
      have hlog_nonneg : 0 ≤ FeeSchedule.logistic (γ j * (σpath t - β j)) :=
        le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
      exact mul_le_mul_of_nonneg_right (hα j hj') hlog_nonneg
    have hsum_le : ∑ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j)) ≤
        ∑ j ∈ Finset.range n, αmax j * FeeSchedule.logistic (γ j * (σpath t - β j)) :=
      Finset.sum_le_sum hterm_le
    -- The sum with αmax is nonnegative
    have hsum_max_nonneg : 0 ≤ ∑ j ∈ Finset.range n,
        αmax j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
      apply Finset.sum_nonneg
      intro j hj
      have hj' : j < n := Finset.mem_range.mp hj
      exact mul_nonneg (hαmax0 j hj') (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
    -- u ≤ uMax and both sums are nonneg, so sum * u ≤ sum * uMax
    have hu_le : u ≤ uMax := hu
    have hprod_le : (∑ j ∈ Finset.range n,
        α j * FeeSchedule.logistic (γ j * (σpath t - β j))) * u ≤
        (∑ j ∈ Finset.range n, αmax j * FeeSchedule.logistic (γ j * (σpath t - β j))) * uMax := by
      apply mul_le_mul hsum_le hu_le (by linarith) hsum_max_nonneg
    linarith
  -- Now use ptrade_strictAntiOn to get the ptrade inequality
  have hptrade_le : ∀ t < T,
      ptrade (VolInstrument.multiFee n γ β αmax φbarMax uMax (σpath t)) (σpath t) Δt ≤
        ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt := by
    intro t ht
    have hσt : 0 < σpath t := hσ t ht
    have hΔt' : 0 < Δt := hΔt
    have hanti := ptrade_strictAntiOn (σpath t) Δt hσt hΔt'
    -- Need nonnegativity of both fees
    have hfee1_nonneg : 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath t) := by
      unfold VolInstrument.multiFee
      have hsum_nonneg : 0 ≤ ∑ j ∈ Finset.range n,
          α j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
        apply Finset.sum_nonneg
        intro j hj
        exact mul_nonneg (hα0 j (Finset.mem_range.mp hj))
          (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
      nlinarith
    have hfee2_nonneg : 0 ≤ VolInstrument.multiFee n γ β αmax φbarMax uMax (σpath t) := by
      unfold VolInstrument.multiFee
      have hsum_nonneg : 0 ≤ ∑ j ∈ Finset.range n,
          αmax j * FeeSchedule.logistic (γ j * (σpath t - β j)) := by
        apply Finset.sum_nonneg
        intro j hj
        exact mul_nonneg (hαmax0 j (Finset.mem_range.mp hj))
          (le_of_lt (FeeSchedule.logistic_mem_Ioo _).1)
      nlinarith
    exact hanti.antitoneOn hfee1_nonneg hfee2_nonneg (hfee_mono t ht)
  -- Now sum the term-by-term inequalities
  unfold mevMulti mevHazard
  apply Finset.sum_le_sum
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have hptr := hptrade_le t ht'
  have ha_t := ha t ht'
  have hD_t := hD t ht'
  calc ptrade (VolInstrument.multiFee n γ β αmax φbarMax uMax (σpath t)) (σpath t) Δt * a t / D t
      ≤ ptrade (VolInstrument.multiFee n γ β α φbar u (σpath t)) (σpath t) Δt * a t / D t := by
        gcongr

/-- T15. In the one-sigmoid case, moving the center to `-∞` approaches the
uniform saturation bound.  The additional nonnegativity of the limiting fee is
necessary to keep the limit away from `ptrade`'s negative-fee pole. -/
theorem mevMulti_saturation_limit (γ0 φbarMax uMax αmax0 : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (hγ : 0 < γ0)
    (hfee : 0 ≤ φbarMax + uMax * αmax0)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    Filter.Tendsto
      (fun β0 => mevMulti 1 (fun _ => γ0) (fun _ => β0)
        (fun _ => αmax0) φbarMax uMax σpath a D Δt T)
      Filter.atBot
      (nhds (∑ t ∈ Finset.range T,
        ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t)) := by
  unfold mevMulti mevHazard
  -- The fee multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax σ
  -- = φbarMax + (αmax0 * logistic(γ0 * (σ - β0))) * uMax
  -- As β0 → -∞, logistic(γ0 * (σ - β0)) → 1, so fee → φbarMax + uMax * αmax0
  apply tendsto_finset_sum _
  intro t ht
  have ht' : t < T := Finset.mem_range.mp ht
  have hσt : 0 < σpath t := hσ t ht'
  -- Show that logistic(γ0 * (σpath t - β0)) → 1 as β0 → -∞
  have h1 : Filter.Tendsto (fun β0 => σpath t - β0) Filter.atBot Filter.atTop := by
    rw [Filter.tendsto_atTop]
    intro b
    rw [Filter.eventually_atBot]
    use σpath t - b
    intro β0 hβ0
    linarith
  have h2 : Filter.Tendsto (fun β0 => γ0 * (σpath t - β0)) Filter.atBot Filter.atTop := by
    exact Filter.Tendsto.const_mul_atTop hγ h1
  have h3 : Filter.Tendsto (fun β0 => FeeSchedule.logistic (γ0 * (σpath t - β0))) Filter.atBot (𝓝 1) := by
    exact FeeSchedule.logistic_tendsto_atTop.comp h2
  -- multiFee = φbarMax + αmax0 * logistic(...) * uMax → φbarMax + αmax0 * 1 * uMax
  have hfee_tends : Filter.Tendsto
      (fun β0 => VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0)
        (fun _ => αmax0) φbarMax uMax (σpath t)) Filter.atBot
      (𝓝 (φbarMax + uMax * αmax0)) := by
    unfold VolInstrument.multiFee
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
    have : Filter.Tendsto
        (fun β0 => φbarMax + αmax0 * FeeSchedule.logistic (γ0 * (σpath t - β0)) * uMax)
        Filter.atBot (𝓝 (φbarMax + αmax0 * 1 * uMax)) := by
      apply Filter.Tendsto.add tendsto_const_nhds
      exact Filter.Tendsto.mul (Filter.Tendsto.mul tendsto_const_nhds h3) tendsto_const_nhds
    convert this using 2 <;> ring
  -- ptrade is continuous in the fee when fee stays positive
  have hdenom_pos : 0 < σpath t + (φbarMax + uMax * αmax0) * Real.sqrt (2 / Δt) := by
    apply add_pos_of_pos_of_nonneg hσt
    apply mul_nonneg hfee
    exact Real.sqrt_nonneg _
  have hptrade_cont : ContinuousAt (fun φ => ptrade φ (σpath t) Δt) (φbarMax + uMax * αmax0) := by
    unfold ptrade
    apply ContinuousAt.div tendsto_const_nhds
    apply ContinuousAt.add tendsto_const_nhds
    exact continuousAt_id.mul continuousAt_const
    linarith
  have := hptrade_cont.tendsto.comp hfee_tends
  convert this.mul_const (a t / D t) using 2 <;> try ring_nf
  simp only [Function.comp]
  ring

/-- T16. This is the `n = 1`, corner-levels mirror of
`FlairOptimization.flairMulti_strict_below_saturation`, with the inequality
reversed.  Positive levels and a positive path-weight witness are necessary.
Thus the M5 displayed bound is a boundary value, not a minimum. -/
theorem mevMulti_strict_above_saturation (γ0 β0 φbarMax uMax αmax0 : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hu : 0 < uMax) (hα : 0 < αmax0) (hφ : 0 ≤ φbarMax)
    (hD : ∀ t < T, 0 < D t) (ha : ∀ t < T, 0 ≤ a t)
    (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    (∑ t ∈ Finset.range T,
      ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t) <
    mevMulti 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0)
      φbarMax uMax σpath a D Δt T := by
  have h_multiFee_lt : ∀ σ, VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax σ < φbarMax + uMax * αmax0 := by
    intro σ
    unfold VolInstrument.multiFee
    simp only [Finset.sum_range_one]
    have hlogistic : FeeSchedule.logistic (γ0 * (σ - β0)) < 1 := (FeeSchedule.logistic_mem_Ioo _).2
    nlinarith [mul_pos hu hα]
  unfold mevMulti mevHazard
  apply Finset.sum_lt_sum
  · -- For all t in range T, show ptrade(bound) ≤ ptrade(multiFee)
    intro i hi
    have hi' : i < T := Finset.mem_range.mp hi
    have hmulti_lt : VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath i) < φbarMax + uMax * αmax0 := h_multiFee_lt (σpath i)
    have hmulti_nonneg : 0 ≤ VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath i) := by
      have h1 := VolInstrument.multiFee_bounds 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath i)
        (fun j hj => le_of_lt hα) (le_of_lt hu)
      linarith
    have hbound_nonneg : 0 ≤ φbarMax + uMax * αmax0 := by nlinarith
    have hptrade : ptrade (φbarMax + uMax * αmax0) (σpath i) Δt ≤ ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath i)) (σpath i) Δt := by
      exact le_of_lt (ptrade_strictAntiOn (σpath i) Δt (hσ i hi') hΔt hmulti_nonneg hbound_nonneg hmulti_lt)
    gcongr
    · exact le_of_lt (hD i hi')
    · exact ha i hi'
  · -- There exists t in range T where ptrade(bound) < ptrade(multiFee)
    obtain ⟨t₀, ht₀_lt, ha_t₀⟩ := ha_pos
    refine ⟨t₀, Finset.mem_range.mpr ht₀_lt, ?_⟩
    have hmulti_lt : VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t₀) < φbarMax + uMax * αmax0 := h_multiFee_lt (σpath t₀)
    have hmulti_nonneg : 0 ≤ VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t₀) := by
      have h1 := VolInstrument.multiFee_bounds 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t₀)
        (fun j hj => le_of_lt hα) (le_of_lt hu)
      linarith
    have hbound_nonneg : 0 ≤ φbarMax + uMax * αmax0 := by nlinarith
    have hptrade : ptrade (φbarMax + uMax * αmax0) (σpath t₀) Δt < ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t₀)) (σpath t₀) Δt := by
      exact ptrade_strictAntiOn (σpath t₀) Δt (hσ t₀ ht₀_lt) hΔt hmulti_nonneg hbound_nonneg hmulti_lt
    have hD_t₀ : 0 < D t₀ := hD t₀ ht₀_lt
    gcongr

/-- T17. A compact, nonempty one-sigmoid parameter set has a minimizer when
its level coordinates are admissible.  The explicit nonnegative-level region
is essential: compactness alone does not avoid the pole of `ptrade` at a
negative fee. -/
theorem mevMulti_exists_min_compact
    (Θ : Set (ℝ × ℝ × ℝ × ℝ)) (hΘ : IsCompact Θ) (hne : Θ.Nonempty)
    (hadm : ∀ θ ∈ Θ, 0 ≤ θ.1 ∧ 0 ≤ θ.2.1)
    (u : ℝ) (hu : 0 ≤ u) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hΔt : 0 < Δt) (hσ : ∀ t < T, 0 < σpath t) :
    ∃ θ ∈ Θ, ∀ θ' ∈ Θ,
      mevMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1)
          θ.1 u σpath a D Δt T ≤
      mevMulti 1 (fun _ => θ'.2.2.2) (fun _ => θ'.2.2.1) (fun _ => θ'.2.1)
          θ'.1 u σpath a D Δt T := by
  classical
  let f := fun θ : ℝ × ℝ × ℝ × ℝ =>
    mevMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1) θ.1 u σpath a D Δt T
  have hcont : ContinuousOn f Θ := by
    have hf_eq : f = fun θ => ∑ t ∈ Finset.range T,
      ptrade (VolInstrument.multiFee 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1) θ.1 u (σpath t)) (σpath t) Δt * a t / D t := by
      rfl
    rw [hf_eq]
    apply continuousOn_finset_sum
    intro t ht
    by_cases hDt : D t = 0
    · -- If D t = 0, function is constant 0
      simp [hDt]
      exact continuousOn_const
    · -- If D t ≠ 0, prove ContinuousOn
      apply ContinuousOn.div _ continuousOn_const (by intro x _; exact hDt)
      apply ContinuousOn.mul _ continuousOn_const
      simp only [MevOptimization.ptrade]
      apply ContinuousOn.div continuousOn_const _ _
      · apply Continuous.continuousOn
        apply Continuous.add continuous_const
        apply Continuous.mul _ continuous_const
        simp only [VolInstrument.multiFee]
        apply Continuous.add continuous_fst
        apply Continuous.mul _ continuous_const
        apply continuous_finset_sum
        intro j _
        apply Continuous.mul _ _
        exact continuous_snd.fst
        simp only [FeeSchedule.logistic]
        apply Continuous.div continuous_const _ _
        · apply Continuous.add continuous_const
          exact Real.continuous_exp.comp (continuous_neg.comp
            (continuous_snd.snd.snd.mul (continuous_const.sub (continuous_snd.snd.fst))))
        · intro x; positivity
      · intro x hx
        have ht' : t < T := Finset.mem_range.mp ht
        have hσt_pos : 0 < σpath t := hσ t ht'
        have hsqrt_pos : 0 < Real.sqrt (2 / Δt) := Real.sqrt_pos.mpr (div_pos zero_lt_two hΔt)
        have hφ_nonneg : 0 ≤ x.1 := (hadm x hx).1
        have hmultiFee_nonneg : 0 ≤ VolInstrument.multiFee 1 (fun _ => x.2.2.2) (fun _ => x.2.2.1) (fun _ => x.2.1) x.1 u (σpath t) := by
          have hα_nonneg : 0 ≤ x.2.1 := (hadm x hx).2
          rw [VolInstrument.multiFee]
          apply add_nonneg hφ_nonneg
          apply mul_nonneg _ hu
          apply Finset.sum_nonneg
          intro j _
          apply mul_nonneg hα_nonneg
          exact le_of_lt (FeeSchedule.logistic_mem_Ioo _ |>.1)
        linarith [mul_nonneg hmultiFee_nonneg hsqrt_pos.le]
  exact hΘ.exists_isMinOn hne hcont

/-- T18. The controlling block is `{φbar, α, u}` at its upper corner, while
finite shape parameters cannot attain the saturation infimum.  Naming caveat:
this object is `λ_ARB`, a SUMMAND of `λ_MEV` and not a sibling of it; it equals
`λ_MEV` only under block M7's uniform-clearing reduction (`λ_sandwich = 0`),
which is NOT formalized in this bundle. -/
theorem Theta_lambdaMEV_identification (γ0 φbarMax uMax αmax0 : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (hγ : 0 < γ0)
    (hu : 0 < uMax) (hα : 0 < αmax0) (hφ : 0 ≤ φbarMax)
    (hD : ∀ t < T, 0 < D t) (ha : ∀ t < T, 0 ≤ a t)
    (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    (∀ β0,
      (∑ t ∈ Finset.range T,
        ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t) <
      mevMulti 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0)
        φbarMax uMax σpath a D Δt T) ∧
    Filter.Tendsto
      (fun β0 => mevMulti 1 (fun _ => γ0) (fun _ => β0)
        (fun _ => αmax0) φbarMax uMax σpath a D Δt T)
      Filter.atBot
      (nhds (∑ t ∈ Finset.range T,
        ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t)) := by
  refine ⟨fun β0 => ?_, ?_⟩
  · -- Part 1: strict inequality for all β0
    obtain ⟨t₀, ht₀_lt, ht₀_pos⟩ := ha_pos
    have ht₀_range : t₀ ∈ Finset.range T := Finset.mem_range.mpr ht₀_lt
    -- multiFee < φbarMax + uMax * αmax0
    have hfee_lt : VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t₀) < φbarMax + uMax * αmax0 := by
      unfold VolInstrument.multiFee
      simp only [Finset.sum_range_one]
      have hlog : FeeSchedule.logistic (γ0 * (σpath t₀ - β0)) < 1 := (FeeSchedule.logistic_mem_Ioo _).2
      have hαu : 0 < αmax0 * uMax := mul_pos hα hu
      nlinarith [hlog]
    -- For all t, multiFee t < target fee
    have hfee_lt_all : ∀ t < T, VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t) < φbarMax + uMax * αmax0 := by
      intro t ht
      unfold VolInstrument.multiFee
      simp only [Finset.sum_range_one]
      have hlog : FeeSchedule.logistic (γ0 * (σpath t - β0)) < 1 := (FeeSchedule.logistic_mem_Ioo _).2
      have hαu : 0 < αmax0 * uMax := mul_pos hα hu
      nlinarith [mul_lt_mul_of_pos_left hlog hαu]
    -- ptrade is strictly decreasing, so ptrade(multiFee t) > ptrade(target)
    have hptrade_gt_all : ∀ t < T, ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t)) (σpath t) Δt >
        ptrade (φbarMax + uMax * αmax0) (σpath t) Δt := by
      intro t ht
      have hmultiFee_nonneg : 0 ≤ VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t) := by
        have := VolInstrument.multiFee_bounds 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t) (fun j hj => le_of_lt hα) (le_of_lt hu)
        linarith [this.1, hφ]
      have htarget_nonneg : 0 ≤ φbarMax + uMax * αmax0 := by nlinarith [hφ, mul_nonneg (le_of_lt hu) (le_of_lt hα)]
      exact ptrade_strictAntiOn (σpath t) Δt (hσ t ht) hΔt hmultiFee_nonneg htarget_nonneg (hfee_lt_all t ht)
    -- Now prove the sum inequality using Finset.sum_lt_sum
    have hterm_ge : ∀ t ∈ Finset.range T,
        ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t ≤
        ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t)) (σpath t) Δt * a t / D t := by
      intro t ht
      have ht' := Finset.mem_range.mp ht
      apply div_le_div_of_nonneg_right _ (le_of_lt (hD t ht'))
      apply mul_le_mul_of_nonneg_right _ (ha t ht')
      exact le_of_lt (hptrade_gt_all t ht')
    have hterm_gt_at_t₀ :
        ptrade (φbarMax + uMax * αmax0) (σpath t₀) Δt * a t₀ / D t₀ <
        ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t₀)) (σpath t₀) Δt * a t₀ / D t₀ := by
      apply div_lt_div_of_pos_right _ (hD t₀ ht₀_lt)
      apply mul_lt_mul_of_pos_right _ ht₀_pos
      exact hptrade_gt_all t₀ ht₀_lt
    refine Finset.sum_lt_sum ?_ ⟨t₀, ht₀_range, hterm_gt_at_t₀⟩
    exact hterm_ge
  · -- Part 2: tendsto as β0 → -∞
    -- As β0 → -∞, multiFee → φbarMax + uMax * αmax0
    -- since logistic(γ0 * (σ - β0)) → 1 as β0 → -∞
    -- First show that for each t, logistic(γ0 * (σpath t - β0)) → 1 as β0 → -∞
    have hlog_tendsto : ∀ t < T, Filter.Tendsto (fun β0 => FeeSchedule.logistic (γ0 * (σpath t - β0))) Filter.atBot (𝓝 1) := by
      intro t ht
      apply FeeSchedule.logistic_tendsto_atTop.comp
      apply Filter.Tendsto.const_mul_atTop hγ
      exact Filter.tendsto_atBot_atTop.mpr (fun x => ⟨σpath t - x, fun β0 hβ0 => by linarith⟩)
    -- multiFee → φbarMax + uMax * αmax0
    have hfee_tendsto : ∀ t < T, Filter.Tendsto (fun β0 => VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t)) Filter.atBot (𝓝 (φbarMax + uMax * αmax0)) := by
      intro t ht
      unfold VolInstrument.multiFee
      simp only [Finset.sum_range_one]
      have h1 := (hlog_tendsto t ht).const_mul αmax0
      have h2 := h1.const_mul uMax
      simp only [mul_one] at h2
      convert Filter.Tendsto.const_add φbarMax h2 using 2 <;> ring
    -- ptrade is continuous in φ, so ptrade(multiFee t) → ptrade(target)
    have hptrade_tendsto : ∀ t < T, Filter.Tendsto (fun β0 => ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t)) (σpath t) Δt) Filter.atBot (𝓝 (ptrade (φbarMax + uMax * αmax0) (σpath t) Δt)) := by
      intro t ht
      unfold ptrade
      have htarget_nonneg : 0 ≤ φbarMax + uMax * αmax0 := by nlinarith
      have hdenom_pos : 0 < σpath t + (φbarMax + uMax * αmax0) * Real.sqrt (2 / Δt) := by
        apply add_pos_of_pos_of_nonneg (hσ t ht)
        exact mul_nonneg htarget_nonneg (Real.sqrt_nonneg _)
      have hnum : Filter.Tendsto (fun _ : ℝ => σpath t) Filter.atBot (𝓝 (σpath t)) := tendsto_const_nhds
      have hdenom : Filter.Tendsto (fun β0 => σpath t + VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t) * Real.sqrt (2 / Δt)) Filter.atBot (𝓝 (σpath t + (φbarMax + uMax * αmax0) * Real.sqrt (2 / Δt))) := by
        have := Filter.Tendsto.mul_const (Real.sqrt (2 / Δt)) (hfee_tendsto t ht)
        simpa using Filter.Tendsto.const_add _ this
      exact Filter.Tendsto.div hnum hdenom (ne_of_gt hdenom_pos)
    -- Each term tends to its limit
    have hterm_tendsto : ∀ t < T, Filter.Tendsto (fun β0 => ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t)) (σpath t) Δt * a t / D t) Filter.atBot (𝓝 (ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t)) := by
      intro t ht
      have h1 := Filter.Tendsto.mul_const (a t) (hptrade_tendsto t ht)
      have h2 := Filter.Tendsto.div_const h1 (D t)
      exact h2
    -- Now combine into a sum
    have heq : ∀ β0, mevMulti 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax σpath a D Δt T =
        ∑ t ∈ Finset.range T, ptrade (VolInstrument.multiFee 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax (σpath t)) (σpath t) Δt * a t / D t := by
      intro β0
      rfl
    simp_rw [heq]
    exact tendsto_finset_sum _ (fun t ht => hterm_tendsto t (Finset.mem_range.mp ht))

/-- The compact-box minimum exists and strictly exceeds the M5 saturation
bound.  The upper-box hypotheses allow comparison with the corner levels;
the strict gap then follows because every center in the compact box is finite. -/
theorem mevMulti_min_gt_corner
    (Θ : Set (ℝ × ℝ × ℝ × ℝ)) (hΘ : IsCompact Θ) (hne : Θ.Nonempty)
    (φbarMax uMax αmax0 : ℝ)
    (hadm : ∀ θ ∈ Θ, 0 ≤ θ.1 ∧ 0 ≤ θ.2.1)
    (hupper : ∀ θ ∈ Θ, θ.1 ≤ φbarMax ∧ θ.2.1 ≤ αmax0)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hu : 0 < uMax) (hα : 0 < αmax0) (hφ : 0 ≤ φbarMax)
    (hD : ∀ t < T, 0 < D t) (ha : ∀ t < T, 0 ≤ a t)
    (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    ∃ θ ∈ Θ,
      (∀ θ' ∈ Θ,
        mevMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1)
            θ.1 uMax σpath a D Δt T ≤
        mevMulti 1 (fun _ => θ'.2.2.2) (fun _ => θ'.2.2.1) (fun _ => θ'.2.1)
            θ'.1 uMax σpath a D Δt T) ∧
      (∑ t ∈ Finset.range T,
        ptrade (φbarMax + uMax * αmax0) (σpath t) Δt * a t / D t) <
        mevMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1)
          θ.1 uMax σpath a D Δt T := by
  have h_exists := mevMulti_exists_min_compact Θ hΘ hne hadm uMax (le_of_lt hu) σpath a D Δt T hΔt hσ
  obtain ⟨θ_star, hθ_star_mem, hθ_star_min⟩ := h_exists
  use θ_star
  refine ⟨hθ_star_mem, ⟨hθ_star_min, ?_⟩⟩
  -- Now prove the strict inequality
  -- First get the bounds on θ_star
  have hstar_adm := hadm θ_star hθ_star_mem
  have hstar_upper := hupper θ_star hθ_star_mem
  -- Case split on whether θ_star is at the corner
  by_cases hφ_eq : θ_star.1 = φbarMax
  · by_cases hα_eq : θ_star.2.1 = αmax0
    · -- Corner case: φbar = φbarMax, α = αmax0
      -- Use mevMulti_strict_above_saturation
      have hstrict := mevMulti_strict_above_saturation θ_star.2.2.2 θ_star.2.2.1 φbarMax uMax αmax0
        σpath a D Δt T hu hα hφ hD ha ha_pos hσ hΔt
      rw [hφ_eq, hα_eq]
      exact hstrict
    · -- α < αmax0
      have hα_lt : θ_star.2.1 < αmax0 := lt_of_le_of_ne hstar_upper.2 hα_eq
      -- Define the corner point with same β, γ as θ_star
      let θ_corner : ℝ × ℝ × ℝ × ℝ := (φbarMax, αmax0, θ_star.2.2.1, θ_star.2.2.2)
      -- Step 1: By mevMulti_strict_above_saturation at corner: sum < mevMulti(θ_corner)
      have h1 := mevMulti_strict_above_saturation θ_star.2.2.2 θ_star.2.2.1 φbarMax uMax αmax0
        σpath a D Δt T hu hα hφ hD ha ha_pos hσ hΔt
      -- h1: sum < mevMulti(φbarMax, αmax0, β, γ)
      -- Step 2: By mevMulti_anti_alpha: mevMulti(θ_corner) ≤ mevMulti(θ_star)
      have h2 := mevMulti_anti_alpha 1 (fun _ => θ_star.2.2.2) (fun _ => θ_star.2.2.1)
        (fun _ => θ_star.2.1) (fun _ => αmax0) φbarMax uMax σpath a D Δt T
        (fun j hj => le_of_lt hα_lt) (le_of_lt hu) (by linarith) (fun j hj => hstar_adm.2)
        ha hD hσ hΔt
      -- Chain: sum < corner ≤ θ_star
      rw [hφ_eq]
      linarith
  · -- φbar < φbarMax
    have hφ_lt : θ_star.1 < φbarMax := lt_of_le_of_ne hstar_upper.1 (fun h => hφ_eq h)
    -- Define an intermediate point with φbarMax but same α, β, γ as θ_star
    let θ_int : ℝ × ℝ × ℝ × ℝ := (φbarMax, θ_star.2.1, θ_star.2.2.1, θ_star.2.2.2)
    -- Step 1: Apply mevMulti_ge_corner at θ_int
    have h1 := mevMulti_ge_corner 1 (fun _ => θ_int.2.2.2) (fun _ => θ_int.2.2.1)
      (fun _ => θ_int.2.1) (fun _ => αmax0) θ_int.1 φbarMax uMax uMax σpath a D Δt T
      (le_refl φbarMax) (by linarith) (le_of_lt hu) (le_refl uMax)
      (fun j hj => hstar_adm.2) (fun j hj => hstar_upper.2) ha hD hσ hΔt
    simp only [Finset.sum_range_one] at h1
    -- h1: sum ≤ mevMulti(θ_int)
    -- Step 2: By mevMulti_anti_phibar: mevMulti(θ_int) < mevMulti(θ_star)
    have h2 := mevMulti_anti_phibar 1 (fun _ => θ_star.2.2.2) (fun _ => θ_star.2.2.1) (fun _ => θ_star.2.1)
      θ_star.1 φbarMax uMax σpath a D Δt T hφ_lt hD ha ha_pos hσ hΔt hstar_adm.1 (fun j hj => hstar_adm.2) (le_of_lt hu)
    -- Chain: sum ≤ θ_int < θ_star
    linarith

end MevOptimization
