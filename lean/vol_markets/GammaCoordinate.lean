import Mathlib

/-!
# GammaCoordinate — gamma as liquidity evaluated at a warped tick coordinate

## Intent (user proposal, 2026-08-11)

The tick `i` carries the price grid on base `λ`. The ladder carries liquidity on ratio
`ξ = λ^{-Δᵢ/2}` — ξ is the LIQUIDITY coordinate. The proposal: gamma lives on a DERIVED
coordinate, `γ(i) = -3η(i + Δᵢ/2)` — the ξ-coordinate warped by the factor 3η — and the
gamma of the pinned member is nothing but THE LIQUIDITY FUNCTION EVALUATED AT THE GAMMA
COORDINATE: `Γ_φ(i_K) = -½·L(γ(i_K))` with `L(t) = L̄·ξ^t`. This does NOT displace the
state-space closed form (`Γ_φ = -½ L̄ p_φ^{-3/2}`, machine-proved elsewhere); it is the
grid-space PRESENTATION of the same object, and K1 is the statement that they coincide.

All four targets were verified numerically to machine precision before submission
(λ = 1.0001, Δᵢ = 10, η ∈ {1, 1/(3·10)}, three strikes).

## Notation

`lam` = λ (abstract, `1 < lam`); `eta` = η > 0; `Di` = Δᵢ > 0; `i0` = the first strike;
`pGrid` = the document's Definition 8 grid `λ^{iΔᵢη/2}`; `pPhiGrid` = the marginal price
on the grid (the inverse product of adjacent grid values); `xiStar = λ^{-Δᵢ/2}`.

## Instructions

Prove the `sorry`'d statements. Priority **K1 > K3 > K2 > K4**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`). A
refutation is a successful outcome. Do not modify any definition.
-/

namespace GammaCoordinate

open Real

noncomputable def pGrid (lam eta Di i : ℝ) : ℝ := lam ^ (i * Di * eta / 2)

noncomputable def pPhiGrid (lam eta Di iK : ℝ) : ℝ :=
  1 / (pGrid lam eta Di iK * pGrid lam eta Di (iK + Di))

noncomputable def xiStar (lam Di : ℝ) : ℝ := lam ^ (-(Di / 2))

/-- The ξ-geometric liquidity as a function of the (continuous) tick coordinate. -/
noncomputable def Lxi (lam Di Lbar t : ℝ) : ℝ := Lbar * xiStar lam Di ^ t

/-- The GAMMA COORDINATE: the ξ-coordinate warped by the factor 3η, with the
half-spacing offset coming from the marginal price's adjacent product. -/
noncomputable def gammaCoord (eta Di i : ℝ) : ℝ := -(3 * eta * (i + Di / 2))

/-! ### Helper lemmas: everything is a real power of `lam`. -/

/-- A power of `xiStar` is a power of `lam`. -/
lemma xiStar_rpow (lam Di t : ℝ) (hlam : 0 < lam) :
    xiStar lam Di ^ t = lam ^ (-(Di / 2) * t) := by
  rw [xiStar, ← Real.rpow_mul hlam.le]

/-- The marginal grid price is a single power of `lam`. -/
lemma pPhiGrid_rpow (lam eta Di iK : ℝ) (hlam : 0 < lam) :
    pPhiGrid lam eta Di iK = lam ^ (-(Di * eta * (iK + Di / 2))) := by
  rw [pPhiGrid, pGrid, pGrid, ← Real.rpow_add hlam, one_div, ← Real.rpow_neg hlam.le]
  congr 1
  ring

/-- The `-3/2` power of the marginal grid price. -/
lemma pPhiGrid_rpow_neg_three_halves (lam eta Di iK : ℝ) (hlam : 0 < lam) :
    (pPhiGrid lam eta Di iK) ^ (-(3 : ℝ) / 2)
      = lam ^ ((3 / 2) * (Di * eta * (iK + Di / 2))) := by
  rw [pPhiGrid_rpow lam eta Di iK hlam, ← Real.rpow_mul hlam.le]
  congr 1
  ring

/-- **K1 — THE COMPOSITIONAL READING.** The gamma of the pinned member on the grid IS
the liquidity function evaluated at the gamma coordinate:
`-(L̄/2)·pPhiGrid^{-3/2} = -½·Lxi(γ(i_K))`. -/
theorem gamma_is_L_at_gammaCoord (lam eta Di Lbar iK : ℝ) (hlam : 1 < lam) :
    -(Lbar / 2) * (pPhiGrid lam eta Di iK) ^ (-(3 : ℝ) / 2)
      = -(1 / 2) * Lxi lam Di Lbar (gammaCoord eta Di iK) := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  rw [pPhiGrid_rpow_neg_three_halves lam eta Di iK hlam0, Lxi, gammaCoord,
    xiStar_rpow lam Di _ hlam0]
  have : -(Di / 2) * -(3 * eta * (iK + Di / 2)) = 3 / 2 * (Di * eta * (iK + Di / 2)) := by
    ring
  rw [this]
  ring

/-- Definition 7's geometric ladder at ratio ξ*: per-strike liquidity
`L̄·ξ^{(i-i₀)/Δᵢ}` (strikes are `Δᵢ` apart; the exponent counts strike POSITION). -/
noncomputable def ladderL (lam Di Lbar i0 i : ℝ) : ℝ :=
  Lbar * xiStar lam Di ^ ((i - i0) / Di)

/-- **K2 — the ladder-gamma single-power law.** With the geometric ladder in place of
the constant `L̄`, the per-strike gamma is a single ξ-power:
`-(ladder(i)/2)·pPhiGrid(i)^{-3/2} = -(L̄/2)·ξ^{(i-i₀)/Δᵢ - 3η(i+Δᵢ/2)}`. -/
theorem ladder_gamma_power (lam eta Di Lbar i0 iK : ℝ) (hlam : 1 < lam) :
    -(ladderL lam Di Lbar i0 iK / 2) * (pPhiGrid lam eta Di iK) ^ (-(3 : ℝ) / 2)
      = -(Lbar / 2) * xiStar lam Di ^ ((iK - i0) / Di - 3 * eta * (iK + Di / 2)) := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  rw [ladderL, pPhiGrid_rpow_neg_three_halves lam eta Di iK hlam0,
    xiStar_rpow lam Di _ hlam0, xiStar_rpow lam Di _ hlam0]
  have hsplit : lam ^ (-(Di / 2) * ((iK - i0) / Di - 3 * eta * (iK + Di / 2)))
      = lam ^ (-(Di / 2) * ((iK - i0) / Di)) * lam ^ (3 / 2 * (Di * eta * (iK + Di / 2))) := by
    rw [← Real.rpow_add hlam0]
    congr 1
    ring
  rw [hsplit]
  ring

/-- **K3 — the flatness threshold.** The ladder gamma is strike-independent iff
`η·Δᵢ = 1/3`: the forward direction compares two strikes and forces the exponent's
`i`-coefficient to vanish; the converse evaluates it. (`1 < lam` and `0 < Di` make the
ξ-power injective in the exponent.) -/
theorem ladder_gamma_flat_iff (lam eta Di Lbar i0 : ℝ) (hlam : 1 < lam)
    (hDi : 0 < Di) (hL : Lbar ≠ 0) :
    (∀ i j : ℝ,
        -(ladderL lam Di Lbar i0 i / 2) * (pPhiGrid lam eta Di i) ^ (-(3 : ℝ) / 2)
          = -(ladderL lam Di Lbar i0 j / 2) * (pPhiGrid lam eta Di j) ^ (-(3 : ℝ) / 2))
      ↔ eta * Di = 1 / 3 := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have hlog : Real.log lam ≠ 0 :=
    Real.log_ne_zero_of_pos_of_ne_one hlam0 (ne_of_gt hlam)
  have key : ∀ i : ℝ,
      -(ladderL lam Di Lbar i0 i / 2) * (pPhiGrid lam eta Di i) ^ (-(3 : ℝ) / 2)
        = -(Lbar / 2) * lam ^ (-(Di / 2) * ((i - i0) / Di - 3 * eta * (i + Di / 2))) := by
    intro i
    rw [ladder_gamma_power lam eta Di Lbar i0 i hlam, xiStar_rpow lam Di _ hlam0]
  constructor
  · intro h
    have h01 := h 0 Di
    rw [key 0, key Di] at h01
    have hpow : lam ^ (-(Di / 2) * ((0 - i0) / Di - 3 * eta * (0 + Di / 2)))
        = lam ^ (-(Di / 2) * ((Di - i0) / Di - 3 * eta * (Di + Di / 2))) := by
      have hne : -(Lbar / 2) ≠ 0 := by
        simpa using hL
      exact mul_left_cancel₀ hne h01
    have hexp := congrArg Real.log hpow
    rw [Real.log_rpow hlam0, Real.log_rpow hlam0] at hexp
    have hcoef : -(Di / 2) * ((0 - i0) / Di - 3 * eta * (0 + Di / 2))
        = -(Di / 2) * ((Di - i0) / Di - 3 * eta * (Di + Di / 2)) :=
      mul_right_cancel₀ hlog hexp
    have hDine : Di ≠ 0 := ne_of_gt hDi
    field_simp at hcoef
    nlinarith [hcoef, hDi, sq_nonneg Di]
  · intro h i j
    rw [key i, key j]
    have hDine : Di ≠ 0 := ne_of_gt hDi
    congr 2
    field_simp
    linear_combination (6 * (i - j)) * h

/-- **K4 — the flat value.** At the threshold `η·Δᵢ = 1/3` the constant ladder gamma is
`-(L̄/2)·ξ^{-(i₀/Δᵢ + 1/2)}` — the closed form of the emulated constant-gamma level
(the vol-market trading function φ^σ of the parallel bundle is the constant-gamma CURVE;
this is the grid+ladder emulating it). -/
theorem ladder_gamma_flat_value (lam eta Di Lbar i0 iK : ℝ) (hlam : 1 < lam)
    (hDi : 0 < Di) (hflat : eta * Di = 1 / 3) :
    -(ladderL lam Di Lbar i0 iK / 2) * (pPhiGrid lam eta Di iK) ^ (-(3 : ℝ) / 2)
      = -(Lbar / 2) * xiStar lam Di ^ (-(i0 / Di + 1 / 2)) := by
  rw [ladder_gamma_power lam eta Di Lbar i0 iK hlam]
  congr 2
  have hDine : Di ≠ 0 := ne_of_gt hDi
  field_simp
  linear_combination (-3 * (2 * iK + Di)) * hflat

end GammaCoordinate
