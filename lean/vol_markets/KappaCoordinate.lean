import Mathlib

/-!
# KappaCoordinate — the coordinate atlas: normalization, duality, and the κ-map claim

## Intent (user proposal, 2026-08-11 — "the structured idea")

The document's grid objects live on a COORDINATE ATLAS over the tick:
* the PRICE coordinate — base `λ`, map `p(i) = λ^{iΔᵢη/2}` (structural: η, Δᵢ);
* the LIQUIDITY coordinate — base `ξ = λ^{-Δᵢ/2}`, map `ξ^{(i-i₀)/Δᵢ}` (the ladder);
* the GAMMA coordinate — base `ξ`, derived, factor `3η` (proved elsewhere);
* CLAIM: a KAPPA (curvature/trading) coordinate exists in the same sense.

Since the CES curvature is tick-CONSTANT on any member, tick-dependence of curvature can
only enter through the BOOK (the liquidity density). The candidate κ-map is the log-slope
of the per-strike liquidity against the marginal price. The targets below establish:
N1 the NORMALIZATION of the gamma coordinate (the pure ratio map, liquidity factored out
as evaluation); N2 the primal-dual RECIPROCITY (gamma map × impact map = 1); N3 the κ-map
of the geometric ladder is the CONSTANT `1/(2ηΔᵢ)`, equal to `3/2` at the flatness
threshold `ηΔᵢ = 1/3`; N4 the κ-map is constant IFF the ladder is geometric — off the
geometric family it is a GENUINE coordinate.

## Notation

`lam` = λ (`1 < lam`), `eta` = η (> 0 where needed), `Di` = Δᵢ (> 0), `i0` = first
strike. All maps are ℝ → ℝ in the tick. No definition may be modified.

## Instructions

Prove the `sorry`'d statements. Priority **N4 > N3 > N1 > N2**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome.
-/

namespace KappaCoordinate

open Real Set

noncomputable def pGrid (lam eta Di i : ℝ) : ℝ := lam ^ (i * Di * eta / 2)

noncomputable def pPhiGrid (lam eta Di iK : ℝ) : ℝ :=
  1 / (pGrid lam eta Di iK * pGrid lam eta Di (iK + Di))

noncomputable def xiStar (lam Di : ℝ) : ℝ := lam ^ (-(Di / 2))

/-- The gamma VALUE at the pinned member: liquidity times the ξ-power map. -/
noncomputable def gammaVal (lam eta Di Lbar i : ℝ) : ℝ :=
  -(Lbar / 2) * xiStar lam Di ^ (-(3 * eta * (i + Di / 2)))

/-- Helper: the per-spacing ratio of the marginal-price map is the constant
`λ^{-Δᵢ²η}` (tick-independent). -/
theorem pPhiGrid_ratio (lam eta Di i : ℝ) (hlam : 0 < lam) :
    pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i = lam ^ (-(Di ^ 2 * eta)) := by
  unfold pPhiGrid pGrid
  rw [← Real.rpow_add hlam, ← Real.rpow_add hlam, one_div, one_div,
    ← Real.rpow_neg hlam.le, ← Real.rpow_neg hlam.le, ← Real.rpow_sub hlam]
  congr 1
  ring

/-- Helper: the log of the per-spacing marginal-price ratio, the κ-map denominator. -/
theorem pPhiGrid_log_ratio (lam eta Di i : ℝ) (hlam : 1 < lam) :
    Real.log (pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i)
      = -(Di ^ 2 * eta) * Real.log lam := by
  rw [pPhiGrid_ratio _ _ _ _ (lt_trans zero_lt_one hlam),
    Real.log_rpow (lt_trans zero_lt_one hlam)]

/-- **N1 — normalization: the PURE coordinate is the ratio; liquidity is evaluation.**
`gammaVal(i)/gammaVal(i₀) = ξ^{-3η(i-i₀)}` — dimensionless, independent of `L̄`; the
`-(L̄/2)` factor cancels. (The document's Definition 41 normalization clause.) -/
theorem gamma_ratio_pure (lam eta Di Lbar i i0 : ℝ) (hlam : 1 < lam) (hL : Lbar ≠ 0) :
    gammaVal lam eta Di Lbar i / gammaVal lam eta Di Lbar i0
      = xiStar lam Di ^ (-(3 * eta * (i - i0))) := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have hxi : 0 < xiStar lam Di := Real.rpow_pos_of_pos hlam0 _
  unfold gammaVal
  rw [mul_div_mul_left _ _ (by simpa using hL : -(Lbar / 2) ≠ 0), ← Real.rpow_sub hxi]
  congr 1
  ring

/-- **N2 — primal-dual reciprocity.** The gamma map (`∂Q_X^L/∂p_φ`, base ξ) and the
price-impact map (`∂p_φ/∂Q_X^L`, base ξ⁻¹) are RECIPROCAL: their product is `1`.
Stated on the closed forms: `gammaVal · (-(2/L̄)·ξ^{+3η(i+Δᵢ/2)}) = 1`. -/
theorem gamma_impact_reciprocal (lam eta Di Lbar i : ℝ) (hlam : 1 < lam)
    (hL : Lbar ≠ 0) :
    gammaVal lam eta Di Lbar i *
      (-(2 / Lbar) * xiStar lam Di ^ (3 * eta * (i + Di / 2))) = 1 := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have hxi : 0 < xiStar lam Di := Real.rpow_pos_of_pos hlam0 _
  have hcancel : xiStar lam Di ^ (-(3 * eta * (i + Di / 2)))
      * xiStar lam Di ^ (3 * eta * (i + Di / 2)) = 1 := by
    rw [← Real.rpow_add hxi]; simp
  unfold gammaVal
  calc -(Lbar / 2) * xiStar lam Di ^ (-(3 * eta * (i + Di / 2))) *
        (-(2 / Lbar) * xiStar lam Di ^ (3 * eta * (i + Di / 2)))
      = ((Lbar / 2) * (2 / Lbar)) * (xiStar lam Di ^ (-(3 * eta * (i + Di / 2)))
          * xiStar lam Di ^ (3 * eta * (i + Di / 2))) := by ring
    _ = 1 := by rw [hcancel]; field_simp

/-- The geometric ladder: per-strike liquidity `L̄·ξ^{(i-i₀)/Δᵢ}`. -/
noncomputable def ladderL (lam Di Lbar i0 i : ℝ) : ℝ :=
  Lbar * xiStar lam Di ^ ((i - i0) / Di)

/-- The κ-map candidate: the LOG-SLOPE of the per-strike liquidity against the marginal
price, taken per spacing (the discrete log-derivative). -/
noncomputable def kappaMap (lam eta Di Lbar i0 i : ℝ) : ℝ :=
  Real.log (ladderL lam Di Lbar i0 (i + Di) / ladderL lam Di Lbar i0 i) /
    Real.log (pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i)

/-- **N3 — the geometric ladder's κ-map is CONSTANT `1/(2ηΔᵢ)`,** and at the flatness
threshold `ηΔᵢ = 1/3` it equals `3/2` — the gamma shape's own exponent. Curvature
tick-dependence is therefore ABSENT on the geometric book. -/
theorem kappaMap_geometric_const (lam eta Di Lbar i0 i : ℝ) (hlam : 1 < lam)
    (heta : 0 < eta) (hDi : 0 < Di) (hL : 0 < Lbar) :
    kappaMap lam eta Di Lbar i0 i = 1 / (2 * eta * Di) ∧
    (eta * Di = 1 / 3 → kappaMap lam eta Di Lbar i0 i = 3 / 2) := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have hxi : 0 < xiStar lam Di := Real.rpow_pos_of_pos hlam0 _
  have hlog : Real.log lam ≠ 0 := ne_of_gt (Real.log_pos hlam)
  have hnum : ladderL lam Di Lbar i0 (i + Di) / ladderL lam Di Lbar i0 i = xiStar lam Di := by
    unfold ladderL
    rw [mul_div_mul_left _ _ hL.ne', ← Real.rpow_sub hxi,
      show (i + Di - i0) / Di - (i - i0) / Di = 1 by field_simp; ring]
    exact Real.rpow_one _
  have hk : kappaMap lam eta Di Lbar i0 i = 1 / (2 * eta * Di) := by
    unfold kappaMap
    rw [hnum, pPhiGrid_log_ratio _ _ _ _ hlam]
    unfold xiStar
    rw [Real.log_rpow hlam0]
    field_simp
  refine ⟨hk, fun h => ?_⟩
  rw [hk, show 2 * eta * Di = 2 * (eta * Di) by ring, h]
  norm_num

/-- **N4 — THE CLAIM: the κ-map is a GENUINE coordinate exactly off the geometric
family.** For a positive per-strike liquidity `f`, the log-slope of `f` against the
marginal price is tick-constant IFF `f`'s per-spacing ratio is tick-constant (i.e. `f`
is geometric). So on the geometric book the κ-coordinate DEGENERATES to a constant, and
any non-geometric density makes it a genuine tick map — the trading/curvature axis gets
its coordinate from the BOOK, not from the member. -/
theorem kappaMap_const_iff_geometric (lam eta Di : ℝ) (f : ℝ → ℝ)
    (hlam : 1 < lam) (heta : 0 < eta) (hDi : 0 < Di) (hf : ∀ i, 0 < f i) :
    (∃ c : ℝ, ∀ i : ℝ,
        Real.log (f (i + Di) / f i) /
            Real.log (pPhiGrid lam eta Di (i + Di) / pPhiGrid lam eta Di i) = c)
      ↔ (∃ r : ℝ, 0 < r ∧ ∀ i : ℝ, f (i + Di) / f i = r) := by
  have hlam0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have hlog : Real.log lam ≠ 0 := ne_of_gt (Real.log_pos hlam)
  set D : ℝ := -(Di ^ 2 * eta) * Real.log lam with hD
  have hDne : D ≠ 0 := by
    have h1 : Di ^ 2 * eta ≠ 0 := by positivity
    simpa [hD, neg_mul, neg_eq_zero, mul_eq_zero] using mul_ne_zero h1 hlog
  constructor
  · rintro ⟨c, hc⟩
    refine ⟨Real.exp (c * D), Real.exp_pos _, fun i => ?_⟩
    have h1 := hc i
    rw [pPhiGrid_log_ratio _ _ _ _ hlam] at h1
    have h2 : Real.log (f (i + Di) / f i) = c * D := by
      field_simp at h1; linarith [h1]
    rw [← h2, Real.exp_log (div_pos (hf _) (hf _))]
  · rintro ⟨r, hr, hrr⟩
    refine ⟨Real.log r / D, fun i => ?_⟩
    rw [pPhiGrid_log_ratio _ _ _ _ hlam, hrr i]

end KappaCoordinate
