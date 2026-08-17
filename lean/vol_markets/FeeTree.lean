import Mathlib

/-!
# FeeTree — the trading tree's resident: θ_fee moves across the κ-space (option (a))

## Intent (user ruling, 2026-08-11)

The atlas has three bases — λ (tick/price), ξ (liquidity), 1/(2ηΔᵢ) (trading) — and
three trees; the protocol materializes them as tickBitmap, liquidityNet, and
feeGrowthOutside. The first two trees have residents (the price; the premium's decay
leg, which is Γ-weighted). The user ruled option (a): the trading tree's resident is
θ_fee — the fee leg of the theta split. This bundle establishes the grid-level laws of
the FEE TREE: the per-spacing fee-growth increments per unit liquidity (Definition 9's
per-strike amounts at a constant fee — the on-chain feeGrowth is exactly per-unit-
liquidity, so the liquidity factor is already divided out).

All four targets were verified numerically to machine precision before submission
(λ = 1.0001, Δᵢ = 10, η = 0.37, i₀ = 100).

## Notation

`lam` = λ (`1 < lam`), `eta` = η, `Di` = Δᵢ, `pGrid` = Definition 8's grid map,
`pPhiGrid` = the marginal price on the grid (inverse product of adjacent grid values),
`xiStar = λ^{-Δᵢ/2}` the liquidity base. `gM f i` / `gX f i` are the money/asset-leg
fee-growth increments per unit liquidity at fee `f` (Definition 9's reciprocal and
direct differences times the fee).

## Instructions

Prove the `sorry`'d statements. Priority **F2 > F1 > F3**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. Do not modify
any definition.

## Outcome

All three statements (F1, F2, F3) are TRUE as written and are proved below; no
refutation was needed.
-/

namespace FeeTree

open Real

noncomputable def pGrid (lam eta Di i : ℝ) : ℝ := lam ^ (i * Di * eta / 2)

noncomputable def pPhiGrid (lam eta Di iK : ℝ) : ℝ :=
  1 / (pGrid lam eta Di iK * pGrid lam eta Di (iK + Di))

noncomputable def xiStar (lam Di : ℝ) : ℝ := lam ^ (-(Di / 2))

/-- Money-leg fee-growth increment per unit liquidity at fee `f`:
`f · (1/p(i) − 1/p(i+Δᵢ))` (Definition 9's reciprocal difference). -/
noncomputable def gM (lam eta Di f i : ℝ) : ℝ :=
  f * (1 / pGrid lam eta Di i - 1 / pGrid lam eta Di (i + Di))

/-- Asset-leg fee-growth increment per unit liquidity at fee `f`:
`f · (p(i+Δᵢ) − p(i))`. -/
noncomputable def gX (lam eta Di f i : ℝ) : ℝ :=
  f * (pGrid lam eta Di (i + Di) - pGrid lam eta Di i)

/-! ### Preliminaries: one-step ratios of the two fee trees and of the marginal price -/

private lemma one_lt_step (lam eta Di : ℝ) (hlam : 1 < lam) (heta : 0 < eta) (hDi : 0 < Di) :
    (1 : ℝ) < lam ^ (Di * Di * eta / 2) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  exact (Real.one_lt_rpow_iff_of_pos hlam0).mpr (Or.inl ⟨hlam, by positivity⟩)

/-- The money-leg fee-growth increment is nonzero (its bracket is strictly positive). -/
lemma gM_bracket_pos (lam eta Di i : ℝ) (hlam : 1 < lam) (heta : 0 < eta) (hDi : 0 < Di) :
    0 < 1 / pGrid lam eta Di i - 1 / pGrid lam eta Di (i + Di) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  unfold pGrid
  have e1 : (i + Di) * Di * eta / 2 = i * Di * eta / 2 + Di * Di * eta / 2 := by ring
  rw [e1, Real.rpow_add hlam0, sub_pos]
  have hA : (0:ℝ) < lam ^ (i * Di * eta / 2) := Real.rpow_pos_of_pos hlam0 _
  have hB := one_lt_step lam eta Di hlam heta hDi
  exact one_div_lt_one_div_of_lt hA (by nlinarith)

/-- The asset-leg fee-growth increment is nonzero (its bracket is strictly positive). -/
lemma gX_bracket_pos (lam eta Di i : ℝ) (hlam : 1 < lam) (heta : 0 < eta) (hDi : 0 < Di) :
    0 < pGrid lam eta Di (i + Di) - pGrid lam eta Di i := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  unfold pGrid
  have e1 : (i + Di) * Di * eta / 2 = i * Di * eta / 2 + Di * Di * eta / 2 := by ring
  rw [e1, Real.rpow_add hlam0, sub_pos]
  have hA : (0:ℝ) < lam ^ (i * Di * eta / 2) := Real.rpow_pos_of_pos hlam0 _
  have hB := one_lt_step lam eta Di hlam heta hDi
  nlinarith

/-- Per-spacing ratio of the money-leg fee tree: `λ^{-ηΔᵢ²/2}`. -/
lemma gM_ratio (lam eta Di f i : ℝ) (hlam : 1 < lam) (heta : 0 < eta) (hDi : 0 < Di)
    (hf : f ≠ 0) :
    gM lam eta Di f (i + Di) / gM lam eta Di f i = lam ^ (-(Di * Di * eta / 2)) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  have hne : gM lam eta Di f i ≠ 0 :=
    mul_ne_zero hf (ne_of_gt (gM_bracket_pos lam eta Di i hlam heta hDi))
  have hp : ∀ j : ℝ, pGrid lam eta Di (j + Di) = pGrid lam eta Di j * lam ^ (Di * Di * eta / 2) := by
    intro j
    unfold pGrid
    rw [← Real.rpow_add hlam0]
    congr 1
    ring
  have hP : ∀ j : ℝ, 0 < pGrid lam eta Di j := by
    intro j; unfold pGrid; exact Real.rpow_pos_of_pos hlam0 _
  have step : gM lam eta Di f (i + Di) = lam ^ (-(Di * Di * eta / 2)) * gM lam eta Di f i := by
    unfold gM
    rw [hp i, hp (i + Di), hp i, Real.rpow_neg hlam0.le]
    have := hP i
    field_simp
  rw [step, mul_div_assoc, div_self hne, mul_one]

/-- Per-spacing ratio of the asset-leg fee tree: `λ^{ηΔᵢ²/2}`. -/
lemma gX_ratio (lam eta Di f i : ℝ) (hlam : 1 < lam) (heta : 0 < eta) (hDi : 0 < Di)
    (hf : f ≠ 0) :
    gX lam eta Di f (i + Di) / gX lam eta Di f i = lam ^ (Di * Di * eta / 2) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  have hne : gX lam eta Di f i ≠ 0 :=
    mul_ne_zero hf (ne_of_gt (gX_bracket_pos lam eta Di i hlam heta hDi))
  have hp : ∀ j : ℝ, pGrid lam eta Di (j + Di) = pGrid lam eta Di j * lam ^ (Di * Di * eta / 2) := by
    intro j
    unfold pGrid
    rw [← Real.rpow_add hlam0]
    congr 1
    ring
  have step : gX lam eta Di f (i + Di) = lam ^ (Di * Di * eta / 2) * gX lam eta Di f i := by
    unfold gX
    rw [hp i, hp (i + Di), hp i]
    ring
  rw [step, mul_div_assoc, div_self hne, mul_one]

/-- The marginal price on the grid is positive. -/
lemma pPhiGrid_pos (lam eta Di iK : ℝ) (hlam : 1 < lam) : 0 < pPhiGrid lam eta Di iK := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  unfold pPhiGrid pGrid
  positivity

/-- Closed form of the marginal price on the grid. -/
lemma pPhiGrid_eq (lam eta Di iK : ℝ) (hlam : 1 < lam) :
    pPhiGrid lam eta Di iK = lam ^ (-((2 * iK + Di) * Di * eta / 2)) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  unfold pPhiGrid pGrid
  rw [← Real.rpow_add hlam0, one_div, ← Real.rpow_neg hlam0.le]
  congr 1
  ring

/-- Per-spacing ratio of the marginal price: `λ^{-ηΔᵢ²}` — exactly the square of the
money-leg fee tree's ratio. -/
lemma pPhiGrid_ratio (lam eta Di i : ℝ) (hlam : 1 < lam) :
    pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i = lam ^ (-(Di * Di * eta)) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  rw [pPhiGrid_eq _ _ _ _ hlam, pPhiGrid_eq _ _ _ _ hlam, ← Real.rpow_sub hlam0]
  congr 1
  ring

/-! ### F1, F2, F3 -/

/-- **F1 — the fee tree's bases, and fee-independence.** The per-spacing ratios of the
two fee-growth trees are pure ξ-powers — `ξ^{ηΔᵢ}` (money leg) and `ξ^{-ηΔᵢ}` (asset
leg) — and the FEE CANCELS in both: the tree structure is fee-independent, the fee only
scales the levels. -/
theorem feeTree_bases (lam eta Di f i : ℝ) (hlam : 1 < lam) (heta : 0 < eta)
    (hDi : 0 < Di) (hf : f ≠ 0) :
    gM lam eta Di f (i + Di) / gM lam eta Di f i = xiStar lam Di ^ (eta * Di) ∧
    gX lam eta Di f (i + Di) / gX lam eta Di f i = xiStar lam Di ^ (-(eta * Di)) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  have hxi : ∀ z : ℝ, xiStar lam Di ^ z = lam ^ (-(Di / 2) * z) := by
    intro z
    unfold xiStar
    exact (Real.rpow_mul hlam0.le _ _).symm
  refine ⟨?_, ?_⟩
  · rw [gM_ratio lam eta Di f i hlam heta hDi hf, hxi]
    ring_nf
  · rw [gX_ratio lam eta Di f i hlam heta hDi hf, hxi]
    ring_nf

/-- **F2 — THE RESIDENCY: the fee tree's κ-reading is ±1/2, the CPMM curvature,
INDEPENDENT of η and Δᵢ.** The log-slope of each fee-growth tree against the marginal
price is `1/2` (money leg) and `-1/2` (asset leg) — the balanced member's `κ_φ`,
regardless of the grid parameters. The trading tree's resident reads the CPMM curvature
off the book unconditionally: the fee legs sit AT the benchmark member on the κ-axis. -/
theorem feeTree_kappa_reading (lam eta Di f i : ℝ) (hlam : 1 < lam) (heta : 0 < eta)
    (hDi : 0 < Di) (hf : 0 < f) :
    Real.log (gM lam eta Di f (i + Di) / gM lam eta Di f i) /
        Real.log (pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i) = 1 / 2 ∧
    Real.log (gX lam eta Di f (i + Di) / gX lam eta Di f i) /
        Real.log (pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i) = -(1 / 2) := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  have hlog : 0 < Real.log lam := Real.log_pos hlam
  have hden : Real.log (pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i)
      = -(Di * Di * eta) * Real.log lam := by
    rw [pPhiGrid_ratio lam eta Di i hlam, Real.log_rpow hlam0]
  have hnumM : Real.log (gM lam eta Di f (i + Di) / gM lam eta Di f i)
      = -(Di * Di * eta / 2) * Real.log lam := by
    rw [gM_ratio lam eta Di f i hlam heta hDi hf.ne', Real.log_rpow hlam0]
  have hnumX : Real.log (gX lam eta Di f (i + Di) / gX lam eta Di f i)
      = (Di * Di * eta / 2) * Real.log lam := by
    rw [gX_ratio lam eta Di f i hlam heta hDi hf.ne', Real.log_rpow hlam0]
  have hpos : 0 < Di * Di * eta * Real.log lam := by positivity
  constructor
  · rw [hnumM, hden]
    field_simp
  · rw [hnumX, hden]
    field_simp

/-- **F3 — the two premium legs are grid-commensurable.** The θ_decay dollar tree
(`Γ-coordinate × p_φ²`, the decay leg's per-tick shape) steps with EXACTLY the money-leg
fee tree's ratio `ξ^{ηΔᵢ}`: the theta split's two legs move on their two trees with THE
SAME per-spacing base — the split is coherent across the atlas. -/
theorem theta_legs_commensurable (lam eta Di f i : ℝ) (hlam : 1 < lam)
    (heta : 0 < eta) (hDi : 0 < Di) (hf : f ≠ 0) :
    ((pPhiGrid lam eta Di (i + Di)) ^ (-(3 : ℝ) / 2) * (pPhiGrid lam eta Di (i + Di)) ^ (2 : ℝ)) /
        ((pPhiGrid lam eta Di i) ^ (-(3 : ℝ) / 2) * (pPhiGrid lam eta Di i) ^ (2 : ℝ))
      = gM lam eta Di f (i + Di) / gM lam eta Di f i := by
  have hlam0 : (0:ℝ) < lam := lt_trans one_pos hlam
  have h1 : 0 < pPhiGrid lam eta Di (i + Di) := pPhiGrid_pos lam eta Di (i + Di) hlam
  have h0 : 0 < pPhiGrid lam eta Di i := pPhiGrid_pos lam eta Di i hlam
  have hcollapse : ∀ x : ℝ, 0 < x → x ^ (-(3 : ℝ) / 2) * x ^ (2 : ℝ) = x ^ ((1 : ℝ) / 2) := by
    intro x hx
    rw [← Real.rpow_add hx]
    norm_num
  rw [hcollapse _ h1, hcollapse _ h0, ← Real.div_rpow h1.le h0.le,
    pPhiGrid_ratio lam eta Di i hlam, gM_ratio lam eta Di f i hlam heta hDi hf,
    ← Real.rpow_mul hlam0.le]
  congr 1
  ring

end FeeTree
