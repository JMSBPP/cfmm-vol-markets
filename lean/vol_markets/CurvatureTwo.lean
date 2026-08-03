import Mathlib
import vol_markets.PhiCES

open Set Filter
open scoped Topology

set_option autoImplicit false
set_option maxHeartbeats 4000000

/-!
# A two-argument curvature index for the CES family

The index chosen here is
`curvTwo ρ ε Δi = (1 - ρ) / (2 - ρ)` on the economically relevant CES domain
`ρ ≤ 1`.  Equivalently, when `ρ < 1`, it is one minus the bounded transform
`subElast ρ / (1 + subElast ρ)`.  Thus it is zero exactly at the linear member,
is positive below it, decreases strictly as substitutability rises, and has
range `[0,1)`.  The share `ε` and spacing `Δi` are retained as two design
arguments for compatibility with the surrounding model, but this normalized
curvature deliberately does not depend on either: CES substitution curvature
is controlled by `ρ`, whereas `ε` controls share asymmetry.

The test below gives a negative verdict on the landed `curvOfTilde` as a CES
curvature measure.  At equal shares it vanishes both for the `ρ = 0`
constant-product limit and for the `ρ = 1` linear member, although the former
has positive `curvTwo`.  Accordingly, `curvOfTilde` measures share asymmetry
(or the associated grid-price tilt), not curvature across the CES `ρ` family.
-/

namespace CurvatureTwo

/-- The CES marginal price (marginal rate of substitution), on the guarded
positive-reserve domain used by `margPrice_pos`. -/
noncomputable def margPrice (ρ ε x y : ℝ) : ℝ :=
  (ε * x ^ (ρ - 1)) / ((1 - ε) * y ^ (ρ - 1))

/-- **A1.** The CES marginal price is positive when the CES parameters and
reserves are in their explicit admissible domains. -/
theorem margPrice_pos {ρ ε x y : ℝ} (hρ : ρ ≠ 0)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hy : 0 < y) :
    0 < margPrice ρ ε x y := by
  unfold margPrice
  apply div_pos
  · exact mul_pos hε.1 (Real.rpow_pos_of_pos hx _)
  · exact mul_pos (sub_pos.mpr hε.2) (Real.rpow_pos_of_pos hy _)

/-- **A2.** On a punctured neighborhood of `ρ = 0`, the CES marginal price
converges to the Cobb--Douglas marginal price.  Positivity of reserves and an
interior share explicitly guard all real powers and the denominator. -/
theorem margPrice_rho_zero_limit {ε x y : ℝ} (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) :
    Tendsto (fun ρ => margPrice ρ ε x y) (𝓝[≠] (0 : ℝ))
      (𝓝 ((ε / (1 - ε)) * (y / x))) := by
  have h : (ε / (1 - ε)) * (y / x) = margPrice 0 ε x y := by
    simp [margPrice]
    rw [Real.rpow_neg_one, Real.rpow_neg_one]
    field_simp
  rw [h]
  have hcont : Continuous fun ρ => margPrice ρ ε x y := by
    have hxpos : 0 < x := hx
    have hypos : 0 < y := hy
    have h1 : 1 - ε ≠ 0 := by linarith [hε.1, hε.2]
    have hnum : Continuous fun (ρ : ℝ) => ε * x ^ (ρ - 1) := by
      have heq : ((fun (ρ : ℝ) => ε * x ^ (ρ - 1)) : ℝ → ℝ) = fun ρ => ε * Real.exp (Real.log x * (ρ - 1)) := by
        ext ρ
        rw [Real.rpow_def_of_pos hxpos]
      rw [heq]
      exact continuous_const.mul (Real.continuous_exp.comp (continuous_const.mul (continuous_id.sub continuous_const)))
    have hden : Continuous fun (ρ : ℝ) => (1 - ε) * y ^ (ρ - 1) := by
      have heq : ((fun (ρ : ℝ) => (1 - ε) * y ^ (ρ - 1)) : ℝ → ℝ) = fun ρ => (1 - ε) * Real.exp (Real.log y * (ρ - 1)) := by
        ext ρ
        rw [Real.rpow_def_of_pos hypos]
      rw [heq]
      exact continuous_const.mul (Real.continuous_exp.comp (continuous_const.mul (continuous_id.sub continuous_const)))
    have hden_ne : ∀ (ρ : ℝ), (1 - ε) * y ^ (ρ - 1) ≠ 0 := by
      intro ρ
      have h2 : y ^ (ρ - 1) ≠ 0 := ne_of_gt (Real.rpow_pos_of_pos hy (ρ - 1))
      exact mul_ne_zero h1 h2
    have heq2 : ((fun (ρ : ℝ) => margPrice ρ ε x y) : ℝ → ℝ) = fun ρ => ε * x ^ (ρ - 1) / ((1 - ε) * y ^ (ρ - 1)) := by
      ext ρ
      exact rfl
    rw [heq2]
    exact Continuous.div hnum hden hden_ne
  exact (hcont.tendsto 0).mono_left nhdsWithin_le_nhds

/-- Elasticity of substitution of the CES member.  Results evaluating its
finite formula explicitly exclude `ρ = 1`. -/
noncomputable def subElast (ρ : ℝ) : ℝ := 1 / (1 - ρ)

/-- **A3a.** CES substitution elasticity is strictly increasing below the
linear endpoint. -/
theorem subElast_strictMonoOn_Iio :
    StrictMonoOn subElast (Iio (1 : ℝ)) := by
  intro ρ₁ hρ₁ ρ₂ hρ₂ h_lt
  simp only [subElast, mem_Iio] at *
  exact one_div_lt_one_div_of_lt (by linarith) (by linarith)

/-- **A3b.** The Cobb--Douglas member has unit substitution elasticity. -/
theorem subElast_zero : subElast 0 = 1 := by
  simp [subElast]

/-- **A3c.** Substitution elasticity diverges at the linear endpoint, whose
members are perfect substitutes. -/
theorem subElast_tendsto_one :
    Tendsto subElast (𝓝[<] (1 : ℝ)) atTop := by
  unfold subElast
  have h : Tendsto (fun ρ : ℝ => 1 - ρ) (𝓝[<] (1 : ℝ)) (𝓝[>] (0 : ℝ)) := by
    apply Filter.Tendsto.inf
    · exact Continuous.tendsto' (by continuity) 1 _ (by norm_num)
    · exact Filter.eventually_principal.mpr (fun x hx => by simpa using hx)
  exact tendsto_inv_nhdsGT_zero.comp h |> fun h => h.congr (by intro; simp [one_div])

/-- The normalized genuine CES curvature index.  It is the rational bounded
normalization `(1-ρ)/(2-ρ)`; `ε` and `Δi` are intentionally inert because they
encode share and grid scale rather than substitution curvature. -/
noncomputable def curvTwo (ρ ε Δi : ℝ) : ℝ := (1 - ρ) / (2 - ρ)

/-- **B1.** Every admissible-share linear CES member has zero curvature. -/
theorem curvTwo_linear_zero {ε Δi : ℝ} (hε : ε ∈ Ioo (0 : ℝ) 1) :
    curvTwo 1 ε Δi = 0 := by
  simp [curvTwo]

/-- **B2.** Every CES member strictly below the linear exponent has positive
curvature. -/
theorem curvTwo_pos_of_lt_one {ρ ε Δi : ℝ} (hρ : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hΔi : 0 < Δi) :
    0 < curvTwo ρ ε Δi := by
  unfold curvTwo
  apply div_pos _ _
  · linarith
  · linarith

/-- **B3.** On the admissible CES exponent domain, curvature is strictly
antitone in `ρ`: greater substitutability means a flatter curve. -/
theorem curvTwo_strictAnti_rho {ε Δi : ℝ} (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hΔi : 0 < Δi) :
    StrictAntiOn (fun ρ => curvTwo ρ ε Δi) (Iic (1 : ℝ)) := by
  intro ρ₁ hρ₁ ρ₂ hρ₂ hlt
  simp [curvTwo]
  rw [div_lt_div_iff₀]
  · nlinarith
  · linarith [hρ₂.out]
  · linarith [hρ₁.out]

/-- **B4.** On `ρ ≤ 1`, genuine curvature uses the same `[0,1)` range
convention as the landed eta curvature index. -/
theorem curvTwo_mem_Ico {ρ ε Δi : ℝ} (hρ : ρ ≤ 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hΔi : 0 < Δi) :
    curvTwo ρ ε Δi ∈ Ico (0 : ℝ) 1 := by
  unfold curvTwo
  constructor
  · exact div_nonneg (by linarith) (by linarith)
  · rw [div_lt_one (by linarith : 2 - ρ > 0)]
    linarith

/-- **C1.** The landed share index vanishes at equal shares. -/
theorem curvOfTilde_zero_at_half {Δi : ℝ} (hΔi : 0 < Δi) :
    EtaTilde.curvOfTilde (1 / 2 : ℝ) Δi = 0 := by
  unfold EtaTilde.curvOfTilde
  norm_num

/-- **C2 (verdict).** The equal-share `ρ → 0` CES limit is the geometric-mean
constant-product curve and differs from the equal-share linear member already
at reserves `(1,4)`.  Nevertheless `curvOfTilde` assigns the same zero to the
equal-share input in both cases, while `curvTwo` assigns respectively `1/2`
and `0`.  Hence no strictly monotone zero-preserving reparameterization can
make the landed index consistently represent both CES curvatures.

This proves that `curvOfTilde` measures share asymmetry/grid tilt, not CES
substitution curvature. -/
theorem curvOfTilde_not_curvature {Δi : ℝ} (hΔi : 0 < Δi) :
    Tendsto (fun ρ => PhiCES.phiCES ρ (1 / 2 : ℝ) 1 4)
        (𝓝[≠] (0 : ℝ)) (𝓝 (Real.sqrt (1 * 4))) ∧
    Real.sqrt (1 * 4) ≠ PhiCES.phiCES 1 (1 / 2 : ℝ) 1 4 ∧
    CurvatureTwo.curvTwo 0 (1 / 2) Δi = (1 / 2 : ℝ) ∧
    CurvatureTwo.curvTwo 1 (1 / 2) Δi = 0 ∧
    ¬ ∃ f : ℝ → ℝ, StrictMono f ∧ f 0 = 0 ∧
      f (EtaTilde.curvOfTilde (1 / 2) Δi) = CurvatureTwo.curvTwo 0 (1 / 2) Δi ∧
      f (EtaTilde.curvOfTilde (1 / 2) Δi) = CurvatureTwo.curvTwo 1 (1 / 2) Δi := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · exact PhiCES.phiCES_zero_half_eq_geom (by norm_num : (0:ℝ) < 1) (by norm_num : (0:ℝ) < 4)
  · simp [PhiCES.phiCES_one]; norm_num
  · simp [curvTwo]
  · simp [curvTwo]
  intro ⟨f, hf_mono, hf0, hf1, hf2⟩
  have hct_zero : EtaTilde.curvOfTilde (1 / 2) Δi = 0 := curvOfTilde_zero_at_half hΔi
  rw [hct_zero] at hf1 hf2
  simp [curvTwo] at hf1 hf2
  linarith

/-- The design dial inverse: the CES exponent producing target normalized
curvature `c`.  As with `curvTwo`, the share and spacing arguments are inert. -/
noncomputable def rhoOfCurv (c ε Δi : ℝ) : ℝ := (1 - 2 * c) / (1 - c)

/-- **D1a.** Inverting an admissible target curvature and then evaluating the
index recovers that target. -/
theorem curvTwo_rhoOfCurv {c ε Δi : ℝ} (hc : c ∈ Ico (0 : ℝ) 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hΔi : 0 < Δi) :
    curvTwo (rhoOfCurv c ε Δi) ε Δi = c := by
  simp only [curvTwo, rhoOfCurv]
  have h1 : 1 - c ≠ 0 := by linarith [hc.2]
  field_simp
  ring

/-- **D1b.** Evaluating curvature and then using the design dial recovers every
admissible CES exponent `ρ ≤ 1`. -/
theorem rhoOfCurv_curvTwo {ρ ε Δi : ℝ} (hρ : ρ ≤ 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hΔi : 0 < Δi) :
    rhoOfCurv (curvTwo ρ ε Δi) ε Δi = ρ := by
  simp only [curvTwo, rhoOfCurv]
  have h1 : 2 - ρ ≠ 0 := by linarith
  field_simp [h1]
  ring

/-- **D2.** The design dial is strictly decreasing in target curvature on
`[0,1)`: requesting more curvature produces a smaller CES exponent. -/
theorem rhoOfCurv_strictAnti {ε Δi : ℝ} (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hΔi : 0 < Δi) :
    StrictAntiOn (fun c => rhoOfCurv c ε Δi) (Ico (0 : ℝ) 1) := by
  intro c1 hc1 c2 hc2 hlt
  simp only [rhoOfCurv]
  have h1 : 1 - c1 > 0 := by linarith [hc1.2]
  have h2 : 1 - c2 > 0 := by linarith [hc2.2]
  rw [div_lt_div_iff₀ h2 h1]
  linarith

end CurvatureTwo
