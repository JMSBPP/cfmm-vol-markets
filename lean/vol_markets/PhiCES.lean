import Mathlib
import vol_markets.EtaTilde
import exp.CESLongVolPayoff

open Set Filter
open scoped Topology

set_option autoImplicit false
set_option maxHeartbeats 4000000

/-!
# The two-parameter CES lock

This file fixes the convention
`phiCES ρ ε x y = (ε * x^ρ + (1-ε) * y^ρ)^(1/ρ)`.
The value at `ρ = 0` is deliberately not used: the Cobb--Douglas member is a
punctured-neighborhood limit.
-/

namespace PhiCES

/-- The two-parameter CES trading function. Its meaningful domain has
`ρ ≠ 0`, `0 < ε < 1`, and positive reserves. -/
noncomputable def phiCES (ρ ε x y : ℝ) : ℝ :=
  (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ)

/-- **A1.** CES is homogeneous of degree one on its guarded domain. -/
theorem phiCES_homogeneous {ρ ε x y a : ℝ} (hρ : ρ ≠ 0)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hy : 0 < y) (ha : 0 < a) :
    phiCES ρ ε (a * x) (a * y) = a * phiCES ρ ε x y := by
  simp only [phiCES]
  rw [Real.mul_rpow (le_of_lt ha) (le_of_lt hx), Real.mul_rpow (le_of_lt ha) (le_of_lt hy)]
  have h_factor : ε * (a ^ ρ * x ^ ρ) + (1 - ε) * (a ^ ρ * y ^ ρ) = a ^ ρ * (ε * x ^ ρ + (1 - ε) * y ^ ρ) := by ring
  rw [h_factor]
  have h_pos : 0 ≤ ε * x ^ ρ + (1 - ε) * y ^ ρ := by
    have h1 : 0 < ε * x ^ ρ := mul_pos hε.1 (Real.rpow_pos_of_pos hx ρ)
    have h2 : 0 < (1 - ε) * y ^ ρ := mul_pos (sub_pos.2 hε.2) (Real.rpow_pos_of_pos hy ρ)
    linarith
  rw [Real.mul_rpow (Real.rpow_nonneg (le_of_lt ha) ρ) h_pos]
  rw [← Real.rpow_mul (le_of_lt ha)]
  simp [hρ]

/-- **A2a.** CES is positive on the positive orthant. -/
theorem phiCES_pos {ρ ε x y : ℝ} (hρ : ρ ≠ 0)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hy : 0 < y) :
    0 < phiCES ρ ε x y := by
  by_cases hz : ρ = 0
  · exact (hρ hz).elim
  rw [phiCES]
  have h_inner_pos : ε * x ^ ρ + (1 - ε) * y ^ ρ > 0 := by
    have hxρ : x ^ ρ > 0 := Real.rpow_pos_of_pos hx ρ
    have hyρ : y ^ ρ > 0 := Real.rpow_pos_of_pos hy ρ
    have hε_pos : ε > 0 := hε.1
    have h1me_pos : 1 - ε > 0 := sub_pos.mpr hε.2
    exact add_pos (mul_pos hε_pos hxρ) (mul_pos h1me_pos hyρ)
  exact Real.rpow_pos_of_pos h_inner_pos _

/-- **A2b.** CES is coordinatewise nondecreasing on the positive orthant. -/
theorem phiCES_mono {ρ ε x₁ x₂ y₁ y₂ : ℝ} (hρ : ρ ≠ 0)
    (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx₁ : 0 < x₁) (hx : x₁ ≤ x₂) (hy₁ : 0 < y₁) (hy : y₁ ≤ y₂) :
    phiCES ρ ε x₁ y₁ ≤ phiCES ρ ε x₂ y₂ := by
  unfold phiCES
  have hεpos : 0 < ε := hε.1
  have hεlt1 : ε < 1 := hε.2
  have hx₁pos : 0 < x₁ := hx₁
  have hy₁pos : 0 < y₁ := hy₁
  rcases lt_trichotomy ρ 0 with hρneg | hρzero | hρpos
  · -- Case ρ < 0
    have hx₂pos : 0 < x₂ := lt_of_lt_of_le hx₁pos hx
    have hy₂pos : 0 < y₂ := lt_of_lt_of_le hy₁pos hy
    -- For ρ < 0, x^ρ = 1/x^(-ρ), so monotonicity reverses
    have hρneg_abs : -ρ > 0 := neg_pos.mpr hρneg
    have h1rx : x₂ ^ ρ ≤ x₁ ^ ρ := by
      rw [show x₂ ^ ρ = (x₂ ^ (-ρ))⁻¹ by rw [← Real.rpow_neg hx₂pos.le]; congr 1; ring]
      rw [show x₁ ^ ρ = (x₁ ^ (-ρ))⁻¹ by rw [← Real.rpow_neg hx₁pos.le]; congr 1; ring]
      exact inv_le_inv₀ (Real.rpow_pos_of_pos hx₂pos (-ρ)) (Real.rpow_pos_of_pos hx₁pos (-ρ)) |>.mpr 
        (Real.rpow_le_rpow (le_of_lt hx₁pos) hx hρneg_abs.le)
    have h1ry : y₂ ^ ρ ≤ y₁ ^ ρ := by
      rw [show y₂ ^ ρ = (y₂ ^ (-ρ))⁻¹ by rw [← Real.rpow_neg hy₂pos.le]; congr 1; ring]
      rw [show y₁ ^ ρ = (y₁ ^ (-ρ))⁻¹ by rw [← Real.rpow_neg hy₁pos.le]; congr 1; ring]
      exact inv_le_inv₀ (Real.rpow_pos_of_pos hy₂pos (-ρ)) (Real.rpow_pos_of_pos hy₁pos (-ρ)) |>.mpr 
        (Real.rpow_le_rpow (le_of_lt hy₁pos) hy hρneg_abs.le)
    have hsum : ε * x₂ ^ ρ + (1 - ε) * y₂ ^ ρ ≤ ε * x₁ ^ ρ + (1 - ε) * y₁ ^ ρ := by
      gcongr <;> linarith
    have hsumpos : 0 < ε * x₂ ^ ρ + (1 - ε) * y₂ ^ ρ := by
      have hxp : 0 < x₂ ^ ρ := Real.rpow_pos_of_pos hx₂pos ρ
      have hyp : 0 < y₂ ^ ρ := Real.rpow_pos_of_pos hy₂pos ρ
      nlinarith
    have hx1sumpos : 0 < ε * x₁ ^ ρ + (1 - ε) * y₁ ^ ρ := by nlinarith
    have hinvρneg : 1 / ρ < 0 := div_neg_of_pos_of_neg zero_lt_one hρneg
    have hinvρneg_abs : -1 / ρ > 0 := by
      have : -1 / ρ = -(1 / ρ) := by ring
      linarith
    -- Use: a^c = 1/(a^(-c)) for c < 0
    have key : ∀ a : ℝ, 0 < a → a ^ (1 / ρ) = (a ^ (-1 / ρ))⁻¹ := fun a ha => by
      have : 1 / ρ = -(-1 / ρ) := by ring
      rw [this, Real.rpow_neg ha.le]
    rw [key _ hx1sumpos, key _ hsumpos]
    -- Now need: (left^(-1/ρ))⁻¹ ≤ (right^(-1/ρ))⁻¹
    -- Since -1/ρ > 0 and right ≤ left, we have right^(-1/ρ) ≤ left^(-1/ρ)
    -- So (left^(-1/ρ))⁻¹ ≤ (right^(-1/ρ))⁻¹
    exact inv_le_inv₀ (Real.rpow_pos_of_pos hx1sumpos (-1 / ρ)) 
      (Real.rpow_pos_of_pos hsumpos (-1 / ρ)) |>.mpr 
      (Real.rpow_le_rpow hsumpos.le hsum hinvρneg_abs.le)
  · -- Case ρ = 0 (contradiction)
    exact absurd hρzero hρ
  · -- Case ρ > 0
    have h1rx : x₁ ^ ρ ≤ x₂ ^ ρ := Real.rpow_le_rpow (le_of_lt hx₁pos) hx hρpos.le
    have h1ry : y₁ ^ ρ ≤ y₂ ^ ρ := Real.rpow_le_rpow (le_of_lt hy₁pos) hy hρpos.le
    have hsum : ε * x₁ ^ ρ + (1 - ε) * y₁ ^ ρ ≤ ε * x₂ ^ ρ + (1 - ε) * y₂ ^ ρ := by
      gcongr <;> linarith
    apply Real.rpow_le_rpow (by
      have hxp : 0 < x₁ ^ ρ := Real.rpow_pos_of_pos hx₁pos ρ
      have hyp : 0 < y₁ ^ ρ := Real.rpow_pos_of_pos hy₁pos ρ
      nlinarith) hsum (by positivity)

/-- **A3 (honest weaker form).** For `ρ ≤ 1`, CES is concave along every
positive radial ray.  This is radial concavity, not a claim of full joint
concavity in `(x,y)`. -/
theorem phiCES_concave {ρ ε x y : ℝ} (hρ : ρ ≠ 0) (hρle : ρ ≤ 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hy : 0 < y) :
    ConcaveOn ℝ (Ioi (0 : ℝ)) (fun a => phiCES ρ ε (a * x) (a * y)) := by
  by_cases hrange : ρ ≤ 1
  · have h : ∀ a ∈ Ioi (0 : ℝ), phiCES ρ ε (a * x) (a * y) = a * phiCES ρ ε x y :=
      fun a ha => phiCES_homogeneous hρ hε hx hy ha
    have hlin : ConcaveOn ℝ (Ioi (0 : ℝ)) (fun a : ℝ => a * phiCES ρ ε x y) := by
      constructor
      · exact convex_Ioi 0
      · intro a ha b hb t s ht hs hts
        simp only [smul_eq_mul, mul_comm]
        ring_nf
        rfl
    exact hlin.congr (fun a ha => (h a ha).symm)
  · exact (hrange hρle).elim

/-- **B1.** The punctured `ρ → 0` CES limit is this project's share-weighted
Cobb--Douglas function. -/
theorem phiCES_tendsto_phiEps {ε x y : ℝ} (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) :
    Tendsto (fun ρ => phiCES ρ ε x y) (𝓝[≠] (0 : ℝ))
      (𝓝 (x ^ ε * y ^ (1 - ε))) := by
  simp only [phiCES]
  -- The limit (ε * x^ρ + (1-ε) * y^ρ)^(1/ρ) → x^ε * y^(1-ε) as ρ → 0
  -- is equivalent to log(ε * x^ρ + (1-ε) * y^ρ) / ρ → ε * log x + (1-ε) * log y
  have hεpos : 0 < ε := hε.1
  have hεlt1 : ε < 1 := hε.2
  -- Define the function inside the log
  let f := fun ρ : ℝ => ε * x ^ ρ + (1 - ε) * y ^ ρ
  -- f(0) = 1
  have hf0 : f 0 = 1 := by simp [f]
  -- f is positive near 0
  have hfp : ∀ ρ, 0 < f ρ := fun ρ => by simp [f]; exact add_pos (mul_pos hεpos (Real.rpow_pos_of_pos hx ρ)) (mul_pos (by linarith) (Real.rpow_pos_of_pos hy ρ))
  -- Use exp/log representation
  have h1 : ∀ ρ ≠ 0, (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ) = Real.exp ((1 / ρ) * Real.log (f ρ)) := by
    intro ρ hρ
    rw [Real.rpow_def_of_pos (hfp ρ)]
    ring_nf
  -- The target equals exp(ε * log x + (1-ε) * log y)
  have htarget : x ^ ε * y ^ (1 - ε) = Real.exp (ε * Real.log x + (1 - ε) * Real.log y) := by
    rw [Real.rpow_def_of_pos hx, Real.rpow_def_of_pos hy]
    rw [← Real.exp_add]
    ring_nf
  -- The limit (log(f ρ)) / ρ → c is equivalent to HasDerivAt (log ∘ f) c 0
  -- since (log ∘ f)(0) = log(1) = 0
  let g := Real.log ∘ f
  have hg0 : g 0 = 0 := by simp [g, f]
  suffices hderiv : HasDerivAt g (ε * Real.log x + (1 - ε) * Real.log y) 0 by
    have hderiv' := hderiv.tendsto_slope_zero
    simp only [smul_eq_mul] at hderiv'
    simp only [zero_add] at hderiv'
    have heq : (fun ρ => 1 / ρ * Real.log (f ρ)) = (fun t => t⁻¹ * (g t - g 0)) := by
      ext t
      simp only [g, hg0]
      simp only [Function.comp_apply]
      ring
    have h2 : Tendsto (fun ρ => (1 / ρ) * Real.log (f ρ)) (𝓝[≠] 0)
      (𝓝 (ε * Real.log x + (1 - ε) * Real.log y)) := by
      rw [heq]
      exact hderiv'
    rw [htarget]
    have hcont := Real.continuous_exp.tendsto (ε * Real.log x + (1 - ε) * Real.log y)
    have h3 := hcont.comp h2
    apply Filter.Tendsto.congr' _ h3
    rw [Filter.EventuallyEq, eventually_nhdsWithin_iff]
    apply Filter.Eventually.of_forall
    intro ρ hρ
    rw [h1 ρ hρ]
    rfl
  -- Now prove HasDerivAt g (ε * log x + (1-ε) * log y) 0
  -- g = Real.log ∘ f, and we use chain rule
  -- f(ρ) = ε * x^ρ + (1-ε) * y^ρ
  -- f'(ρ) = ε * x^ρ * log x + (1-ε) * y^ρ * log y
  -- f'(0) = ε * log x + (1-ε) * log y
  -- f(0) = 1
  -- By chain rule: (log ∘ f)'(0) = (log)'(f(0)) * f'(0) = 1 * f'(0) = ε * log x + (1-ε) * log y
  have hf_deriv : HasDerivAt f (ε * Real.log x + (1 - ε) * Real.log y) 0 := by
    -- f(ρ) = ε * x^ρ + (1-ε) * y^ρ
    -- Note: x^ρ = exp(ρ * log x), so d/dρ x^ρ = x^ρ * log x
    have hx_ne : x ≠ 0 := ne_of_gt hx
    have hy_ne : y ≠ 0 := ne_of_gt hy
    -- x^ρ = exp(ρ * log x)
    have hexp_x : ∀ ρ, x ^ ρ = Real.exp (ρ * Real.log x) := fun ρ => by rw [mul_comm, Real.rpow_def_of_pos hx]
    have hexp_y : ∀ ρ, y ^ ρ = Real.exp (ρ * Real.log y) := fun ρ => by rw [mul_comm, Real.rpow_def_of_pos hy]
    have hfx : HasDerivAt (fun ρ => Real.exp (ρ * Real.log x)) (Real.exp (0 * Real.log x) * Real.log x) (0 : ℝ) := by
      have h1 : HasDerivAt (fun ρ => ρ * Real.log x) (1 * Real.log x) (0 : ℝ) := by
        apply HasDerivAt.mul_const
        exact hasDerivAt_id (0 : ℝ)
      have h2 := Real.hasDerivAt_exp (0 * Real.log x)
      convert h2.comp 0 h1 using 1 <;> ring
    have hfy : HasDerivAt (fun ρ => Real.exp (ρ * Real.log y)) (Real.exp (0 * Real.log y) * Real.log y) (0 : ℝ) := by
      have h1 : HasDerivAt (fun ρ => ρ * Real.log y) (1 * Real.log y) (0 : ℝ) := by
        apply HasDerivAt.mul_const
        exact hasDerivAt_id (0 : ℝ)
      have h2 := Real.hasDerivAt_exp (0 * Real.log y)
      convert h2.comp 0 h1 using 1 <;> ring
    -- Multiply by constants and add
    have hfx' : HasDerivAt (fun ρ => ε * Real.exp (ρ * Real.log x)) (ε * (Real.exp (0 * Real.log x) * Real.log x)) (0 : ℝ) :=
      hfx.const_mul ε
    have hfy' : HasDerivAt (fun ρ => (1 - ε) * Real.exp (ρ * Real.log y)) ((1 - ε) * (Real.exp (0 * Real.log y) * Real.log y)) (0 : ℝ) :=
      hfy.const_mul (1 - ε)
    have hsum := hfx'.add hfy'
    convert hsum using 1
    · ext ρ; simp [f, hexp_x, hexp_y]
    · simp
  have hlog_deriv : HasDerivAt Real.log (1 : ℝ) (f 0) := by
    simp only [hf0]
    have := Real.hasDerivAt_log one_ne_zero
    simp at this
    exact this
  have hderiv := hlog_deriv.comp 0 hf_deriv
  convert hderiv using 1
  simp

/-- **B2.** The `ρ = 1` slice is the weighted linear trading function. -/
theorem phiCES_one (ε x y : ℝ) :
    phiCES 1 ε x y = ε * x + (1 - ε) * y := by
  simp [phiCES]

/-- **B3.** The equal-share Cobb--Douglas limit is the geometric mean. -/
theorem phiCES_zero_half_eq_geom {x y : ℝ} (hx : 0 < x) (hy : 0 < y) :
    Tendsto (fun ρ => phiCES ρ (1 / 2 : ℝ) x y) (𝓝[≠] (0 : ℝ))
      (𝓝 (Real.sqrt (x * y))) := by
  have h1 : (1 : ℝ) / 2 ∈ Ioo (0 : ℝ) 1 := by norm_num
  have h2 := phiCES_tendsto_phiEps h1 hx hy
  convert h2 using 1
  rw [Real.sqrt_eq_rpow]
  norm_num
  rw [← Real.mul_rpow hx.le hy.le]

/-- **C1 (two-point refutation).** Moving from the linear (`ρ=1`) equal-share
member to the harmonic (`ρ=-1`) slice cannot be achieved by changing the
share.  The two displayed positive reserve points are a finite witness. -/
theorem phiCES_rho_ne_eps_axis :
    ¬ ∃ ε' : ℝ,
      phiCES (-1) ε' 1 2 = phiCES 1 (1 / 2 : ℝ) 1 2 ∧
      phiCES (-1) ε' 2 1 = phiCES 1 (1 / 2 : ℝ) 2 1 := by
  intro ⟨ε', h1, h2⟩
  simp [phiCES] at h1 h2
  norm_num at h1 h2
  rw [Real.rpow_neg_one] at h1 h2
  rw [inv_eq_iff_eq_inv] at h1 h2
  norm_num at h1 h2
  linarith

/-- **C2 (sharp two-point/evaluation form).** On the Cobb--Douglas share axis,
the positive test point `(4,1)` agrees with the CPMM geometric mean exactly
at equal shares.  Together with B3 this gives the unique intersection visible
on this evaluation; it does not turn the undefined `ρ=0` formula into a value. -/
theorem phiCES_agreement_point {ε : ℝ} :
    (4 : ℝ) ^ ε * (1 : ℝ) ^ (1 - ε) = Real.sqrt (4 * 1) ↔ ε = 1 / 2 := by
  simp [Real.one_rpow]
  have hsqrt4 : Real.sqrt 4 = 2 := by norm_num
  rw [hsqrt4]
  refine ⟨fun h => ?_, fun h => ?_⟩
  · have h4pos : (0 : ℝ) < 4 := by norm_num
    have h2pos : (0 : ℝ) < 2 := by norm_num
    have := congr_arg Real.log h
    rw [Real.log_rpow h4pos] at this
    have hlog4 : Real.log 4 = 2 * Real.log 2 := by
      rw [show (4 : ℝ) = 2 ^ 2 by norm_num]
      rw [Real.log_pow]
      ring
    rw [hlog4] at this
    have hlog2ne : Real.log 2 ≠ 0 := ne_of_gt (Real.log_pos (by norm_num))
    field_simp at this
    linarith
  · rw [h]
    norm_num

/-- **C3.** After converting a recovered share back to the landed grid
exponent, the landed curvature index is exactly `curvOfTilde` of that share.
Thus this composition factors through one share argument (the Cobb--Douglas,
`ρ→0`, axis); it contains no independently varying CES `ρ`. -/
theorem curvIndex_is_rho_zero_slice {c Δi : ℝ}
    (hshare : EtaTilde.tildeOfCurv c Δi ∈ Ioo (0 : ℝ) 1) (hΔi : 0 < Δi) :
    EtaCurvature.curvIndex
        (EtaTilde.etaOfTilde (EtaTilde.tildeOfCurv c Δi) Δi) Δi =
      EtaTilde.curvOfTilde (EtaTilde.tildeOfCurv c Δi) Δi := by
  have := EtaTilde.tildeOfCurv_curvOfTilde hshare hΔi
  linarith

/-- **D1.** The payoff-layer exponent `p = 1/(1-η)` has the same algebraic
shape as the standard CES substitution elasticity `1/(1-ρ)`, and the
associated `q` is `p-1`.  Equality of those elasticities forces `ρ=η` away
from the poles.  This is only an algebraic conditional: it does not identify
the payoff parameter with the trading-function parameter. -/
theorem phiCES_rho_vs_pi_eta_trader {ρ η : ℝ} (hρ : ρ ≠ 1) (hη : η ≠ 1) :
    ((1 / (1 - ρ) = 1 / (1 - η)) ↔ ρ = η) ∧
      η / (1 - η) = 1 / (1 - η) - 1 := by
  constructor
  · rw [div_eq_div_iff (sub_ne_zero.mpr hρ.symm) (sub_ne_zero.mpr hη.symm)]
    constructor
    · intro h; linarith
    · intro h; rw [h]
  · rw [div_sub_one (sub_ne_zero.mpr hη.symm)]
    ring

end PhiCES
