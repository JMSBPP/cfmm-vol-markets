import vol_markets.EllIntrinsic

/-!
# GammaGrid — three owed riders: the grid–marginal-price relation, the degenerate
# Hessian, and the Γ-grid law (the ξ-coordinatization of gamma)

## Notation map (deliberately disagrees with the governing document — do not rename)

`lam` = the tick base λ (document constant 1.0001; kept ABSTRACT here, `1 < lam`);
`eta` = the grid exponent η > 0; `Di` = the tick spacing Δᵢ > 0; `i` = the tick.
`pGrid` is the document's Definition 8 grid map `p_(η,Δᵢ)(i) = λ^{iΔᵢη/2}`.
`xi = λ^{-Δᵢ/2}` is the pinned ladder ratio ξ*. In `phiCES` (imported, PROVED — do not
modify), `ε` is the document's share `χ_{X/M}` and `ρ` its substitution `ε_{X/M}`.

## Instructions

Prove the `sorry`'d statements. Priority **G1 > G3a > G3b > G2**.

If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome.

`Real.rpow` with a base `> 1` is strictly monotone and everywhere positive — the
`1 < lam` guard is what makes every quotient below well-defined. Do not modify any
definition.
-/

namespace GammaGrid

open Real Set EllIntrinsic

/-- Definition 8's grid map: `p_(η,Δᵢ)(i) = λ^{i·Δᵢ·η/2}`. -/
noncomputable def pGrid (lam eta Di i : ℝ) : ℝ := lam ^ (i * Di * eta / 2)

/-- The per-strike money leg (document Definition 9): `ΔQ_M^L(i_K) = L·(1/p(i_K) − 1/p(i_K+Δᵢ))`. -/
noncomputable def dQM (lam eta Di L iK : ℝ) : ℝ :=
  L * (1 / pGrid lam eta Di iK - 1 / pGrid lam eta Di (iK + Di))

/-- The per-strike asset leg (document Definition 9): `ΔQ_X^L(i_K) = L·(p(i_K+Δᵢ) − p(i_K))`. -/
noncomputable def dQX (lam eta Di L iK : ℝ) : ℝ :=
  L * (pGrid lam eta Di (iK + Di) - pGrid lam eta Di iK)

/-- **G1 — document Proposition 10 (the grid–marginal-price relation), owed twice.**
At Definition 9's reserves the marginal price is the INVERSE PRODUCT of adjacent grid
values: `ΔQ_M^L/ΔQ_X^L = 1/(p(i_K)·p(i_K+Δᵢ))`. The grid map and the marginal price are
therefore DISTINCT objects (a √price-vs-price squaring plus the inversion). Elementary
from the reciprocal difference: `1/a − 1/b = (b−a)/(ab)`. -/
theorem grid_marginal_price (lam eta Di L iK : ℝ) (hlam : 1 < lam) (hL : L ≠ 0)
    (hne : pGrid lam eta Di (iK + Di) ≠ pGrid lam eta Di iK) :
    dQM lam eta Di L iK / dQX lam eta Di L iK
      = 1 / (pGrid lam eta Di iK * pGrid lam eta Di (iK + Di)) := by
  have h0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have ha : pGrid lam eta Di iK ≠ 0 := ne_of_gt (Real.rpow_pos_of_pos h0 _)
  have hb : pGrid lam eta Di (iK + Di) ≠ 0 := ne_of_gt (Real.rpow_pos_of_pos h0 _)
  have hd : pGrid lam eta Di (iK + Di) - pGrid lam eta Di iK ≠ 0 := sub_ne_zero.mpr hne
  unfold dQM dQX
  field_simp

/-! ### G2 — the Hessian of the CES member

All three second derivatives share the factor `ε(ρ−1)(1−ε)·S^{1/ρ−2}` with
`S = ε x^ρ + (1−ε) y^ρ`, which is what makes the determinant vanish. -/

/-- The CES aggregator `S = ε x^ρ + (1−ε) y^ρ` is positive on the positive quadrant. -/
lemma ces_sum_pos (ρ ε x y : ℝ) (hε : 0 < ε) (hε1 : ε < 1) (hx : 0 < x) (hy : 0 < y) :
    0 < ε * x ^ ρ + (1 - ε) * y ^ ρ := by
  have := Real.rpow_pos_of_pos hx ρ
  have := Real.rpow_pos_of_pos hy ρ
  nlinarith

/-- `f_x = ε x^{ρ−1} S^{1/ρ−1}`. -/
lemma hasDerivAt_slice1 (ρ ε y : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1) (x : ℝ)
    (hx : 0 < x) (hy : 0 < y) :
    HasDerivAt (fun u => phiCES ρ ε u y)
      (ε * x ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)) x := by
  have hS := ces_sum_pos ρ ε x y hε hε1 hx hy
  have h2 : HasDerivAt (fun u : ℝ => ε * u ^ ρ + (1 - ε) * y ^ ρ) (ε * (ρ * x ^ (ρ - 1))) x :=
    (((Real.hasDerivAt_rpow_const (p := ρ) (Or.inl hx.ne')).const_mul ε).add_const _)
  have h3 := h2.rpow_const (p := 1 / ρ) (Or.inl hS.ne')
  convert h3 using 1
  field_simp

/-- `f_y = (1−ε) y^{ρ−1} S^{1/ρ−1}`. -/
lemma hasDerivAt_slice2 (ρ ε x : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1) (y : ℝ)
    (hx : 0 < x) (hy : 0 < y) :
    HasDerivAt (fun u => phiCES ρ ε x u)
      ((1 - ε) * y ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)) y := by
  have hS := ces_sum_pos ρ ε x y hε hε1 hx hy
  have h2 : HasDerivAt (fun u : ℝ => ε * x ^ ρ + (1 - ε) * u ^ ρ)
      ((1 - ε) * (ρ * y ^ (ρ - 1))) y :=
    (((Real.hasDerivAt_rpow_const (p := ρ) (Or.inl hy.ne')).const_mul (1 - ε)).const_add _)
  have h3 := h2.rpow_const (p := 1 / ρ) (Or.inl hS.ne')
  convert h3 using 1
  field_simp

lemma deriv_slice1 (ρ ε y : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1) (x : ℝ)
    (hx : 0 < x) (hy : 0 < y) :
    deriv (fun u => phiCES ρ ε u y) x
      = ε * x ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1) :=
  (hasDerivAt_slice1 ρ ε y hρ hε hε1 x hx hy).deriv

lemma deriv_slice2 (ρ ε x : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1) (y : ℝ)
    (hx : 0 < x) (hy : 0 < y) :
    deriv (fun u => phiCES ρ ε x u) y
      = (1 - ε) * y ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1) :=
  (hasDerivAt_slice2 ρ ε x hρ hε hε1 y hx hy).deriv

/-- `f_xx = ε(ρ−1)(1−ε) x^{ρ−2} y^ρ S^{1/ρ−2}`. -/
lemma hessian_xx (ρ ε y : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1) (x : ℝ)
    (hx : 0 < x) (hy : 0 < y) :
    deriv (fun t => deriv (fun u => phiCES ρ ε u y) t) x
      = ε * (ρ - 1) * (1 - ε) * x ^ (ρ - 2) * y ^ ρ
          * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) := by
  have hS := ces_sum_pos ρ ε x y hε hε1 hx hy
  have hev : (fun t => deriv (fun u => phiCES ρ ε u y) t)
      =ᶠ[nhds x] (fun t => ε * t ^ (ρ - 1) * (ε * t ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)) := by
    filter_upwards [Ioi_mem_nhds hx] with t ht
    exact deriv_slice1 ρ ε y hρ hε hε1 t ht hy
  rw [hev.deriv_eq]
  have h1 : HasDerivAt (fun t : ℝ => t ^ (ρ - 1)) ((ρ - 1) * x ^ (ρ - 1 - 1)) x :=
    Real.hasDerivAt_rpow_const (Or.inl hx.ne')
  have h2 : HasDerivAt (fun u : ℝ => ε * u ^ ρ + (1 - ε) * y ^ ρ) (ε * (ρ * x ^ (ρ - 1))) x :=
    (((Real.hasDerivAt_rpow_const (p := ρ) (Or.inl hx.ne')).const_mul ε).add_const _)
  have h3 := h2.rpow_const (p := 1 / ρ - 1) (Or.inl hS.ne')
  have h4 : HasDerivAt
      (fun t : ℝ => ε * t ^ (ρ - 1) * (ε * t ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1))
      (ε * ((ρ - 1) * x ^ (ρ - 1 - 1)) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)
        + ε * x ^ (ρ - 1) * (ε * (ρ * x ^ (ρ - 1)) * (1 / ρ - 1)
            * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1 - 1))) x :=
    (h1.const_mul ε).mul h3
  rw [h4.deriv]
  have e0 : (1 : ℝ) / ρ - 1 - 1 = 1 / ρ - 2 := by ring
  have e3 : ρ - 1 - 1 = ρ - 2 := by ring
  rw [e0, e3]
  have e1 : (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)
      = (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) := by
    rw [← Real.rpow_add_one hS.ne' (1 / ρ - 2)]; congr 1; ring
  have e2 : x ^ (ρ - 1) * x ^ (ρ - 1) = x ^ (ρ - 2) * x ^ ρ := by
    rw [← Real.rpow_add hx, ← Real.rpow_add hx]; ring_nf
  have e4 : ρ * (1 / ρ - 1) = 1 - ρ := by field_simp
  rw [e1]
  set S2 := (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) with hS2
  linear_combination (ε * ε * (1 / ρ - 1) * S2 * ρ) * e2 + (ε ^ 2 * x ^ (ρ - 2) * x ^ ρ * S2) * e4

/-- `f_yy = ε(ρ−1)(1−ε) x^ρ y^{ρ−2} S^{1/ρ−2}`. -/
lemma hessian_yy (ρ ε x : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1) (y : ℝ)
    (hx : 0 < x) (hy : 0 < y) :
    deriv (fun t => deriv (fun u => phiCES ρ ε x u) t) y
      = ε * (ρ - 1) * (1 - ε) * x ^ ρ * y ^ (ρ - 2)
          * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) := by
  have hS := ces_sum_pos ρ ε x y hε hε1 hx hy
  have hev : (fun t => deriv (fun u => phiCES ρ ε x u) t)
      =ᶠ[nhds y]
        (fun t => (1 - ε) * t ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * t ^ ρ) ^ (1 / ρ - 1)) := by
    filter_upwards [Ioi_mem_nhds hy] with t ht
    exact deriv_slice2 ρ ε x hρ hε hε1 t hx ht
  rw [hev.deriv_eq]
  have h1 : HasDerivAt (fun t : ℝ => t ^ (ρ - 1)) ((ρ - 1) * y ^ (ρ - 1 - 1)) y :=
    Real.hasDerivAt_rpow_const (Or.inl hy.ne')
  have h2 : HasDerivAt (fun u : ℝ => ε * x ^ ρ + (1 - ε) * u ^ ρ)
      ((1 - ε) * (ρ * y ^ (ρ - 1))) y :=
    (((Real.hasDerivAt_rpow_const (p := ρ) (Or.inl hy.ne')).const_mul (1 - ε)).const_add _)
  have h3 := h2.rpow_const (p := 1 / ρ - 1) (Or.inl hS.ne')
  have h4 : HasDerivAt
      (fun t : ℝ => (1 - ε) * t ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * t ^ ρ) ^ (1 / ρ - 1))
      ((1 - ε) * ((ρ - 1) * y ^ (ρ - 1 - 1)) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)
        + (1 - ε) * y ^ (ρ - 1) * ((1 - ε) * (ρ * y ^ (ρ - 1)) * (1 / ρ - 1)
            * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1 - 1))) y :=
    (h1.const_mul (1 - ε)).mul h3
  rw [h4.deriv]
  have e0 : (1 : ℝ) / ρ - 1 - 1 = 1 / ρ - 2 := by ring
  have e3 : ρ - 1 - 1 = ρ - 2 := by ring
  rw [e0, e3]
  have e1 : (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1)
      = (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) := by
    rw [← Real.rpow_add_one hS.ne' (1 / ρ - 2)]; congr 1; ring
  have e2 : y ^ (ρ - 1) * y ^ (ρ - 1) = y ^ (ρ - 2) * y ^ ρ := by
    rw [← Real.rpow_add hy, ← Real.rpow_add hy]; ring_nf
  have e4 : ρ * (1 / ρ - 1) = 1 - ρ := by field_simp
  rw [e1]
  set S2 := (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) with hS2
  linear_combination ((1 - ε) * (1 - ε) * (1 / ρ - 1) * S2 * ρ) * e2
    + ((1 - ε) ^ 2 * y ^ (ρ - 2) * y ^ ρ * S2) * e4

/-- `f_xy = −ε(ρ−1)(1−ε) x^{ρ−1} y^{ρ−1} S^{1/ρ−2}`. -/
lemma hessian_xy (ρ ε x y : ℝ) (hρ : ρ ≠ 0) (hε : 0 < ε) (hε1 : ε < 1)
    (hx : 0 < x) (hy : 0 < y) :
    deriv (fun t => deriv (fun u => phiCES ρ ε u t) x) y
      = -(ε * (ρ - 1) * (1 - ε)) * x ^ (ρ - 1) * y ^ (ρ - 1)
          * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) := by
  have hS := ces_sum_pos ρ ε x y hε hε1 hx hy
  have hev : (fun t => deriv (fun u => phiCES ρ ε u t) x)
      =ᶠ[nhds y] (fun t => ε * x ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * t ^ ρ) ^ (1 / ρ - 1)) := by
    filter_upwards [Ioi_mem_nhds hy] with t ht
    exact deriv_slice1 ρ ε t hρ hε hε1 x hx ht
  rw [hev.deriv_eq]
  have h2 : HasDerivAt (fun u : ℝ => ε * x ^ ρ + (1 - ε) * u ^ ρ)
      ((1 - ε) * (ρ * y ^ (ρ - 1))) y :=
    (((Real.hasDerivAt_rpow_const (p := ρ) (Or.inl hy.ne')).const_mul (1 - ε)).const_add _)
  have h3 := h2.rpow_const (p := 1 / ρ - 1) (Or.inl hS.ne')
  have h4 : HasDerivAt
      (fun t : ℝ => ε * x ^ (ρ - 1) * (ε * x ^ ρ + (1 - ε) * t ^ ρ) ^ (1 / ρ - 1))
      (ε * x ^ (ρ - 1) * ((1 - ε) * (ρ * y ^ (ρ - 1)) * (1 / ρ - 1)
          * (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 1 - 1))) y :=
    h3.const_mul _
  rw [h4.deriv]
  have e0 : (1 : ℝ) / ρ - 1 - 1 = 1 / ρ - 2 := by ring
  rw [e0]
  have e4 : ρ * (1 / ρ - 1) = 1 - ρ := by field_simp
  set S2 := (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) with hS2
  linear_combination (ε * (1 - ε) * x ^ (ρ - 1) * y ^ (ρ - 1) * S2) * e4

/-- **G2 — the Gaussian-zero rider, owed twice.** Positive 1-homogeneity forces the
Hessian determinant of every guarded CES member to vanish identically: by Euler's
relation `x·f_x + y·f_y = f`, differentiating gives `x·f_xx + y·f_xy = 0` and
`x·f_xy + y·f_yy = 0`, hence `f_xx·f_yy − f_xy² = 0`. This is the machine content behind
the document's refutation note "the Gaussian curvature of φ's graph is identically
zero for every member". State on second derivatives of the one-variable slices. -/
theorem hessian_det_zero (ρ ε x y : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) :
    deriv (fun t => deriv (fun u => phiCES ρ ε u y) t) x *
        deriv (fun t => deriv (fun u => phiCES ρ ε x u) t) y
      - deriv (fun t => deriv (fun u => phiCES ρ ε u t) x) y ^ 2 = 0 := by
  obtain ⟨hε0, hε1⟩ := hε
  rw [hessian_xx ρ ε y hρ hε0 hε1 x hx hy, hessian_yy ρ ε x hρ hε0 hε1 y hx hy,
    hessian_xy ρ ε x y hρ hε0 hε1 hx hy]
  have e2x : x ^ (ρ - 2) * x ^ ρ = x ^ (ρ - 1) * x ^ (ρ - 1) := by
    rw [← Real.rpow_add hx, ← Real.rpow_add hx]; ring_nf
  have e2y : y ^ (ρ - 2) * y ^ ρ = y ^ (ρ - 1) * y ^ (ρ - 1) := by
    rw [← Real.rpow_add hy, ← Real.rpow_add hy]; ring_nf
  set S2 := (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ - 2) with hS2
  set c := ε * (ρ - 1) * (1 - ε) with hc
  linear_combination (c ^ 2 * S2 ^ 2 * y ^ ρ * y ^ (ρ - 2)) * e2x
    + (c ^ 2 * S2 ^ 2 * x ^ (ρ - 1) * x ^ (ρ - 1)) * e2y

/-- The marginal price on the grid (G1's inverse product), as its own object. -/
noncomputable def pPhiGrid (lam eta Di iK : ℝ) : ℝ :=
  1 / (pGrid lam eta Di iK * pGrid lam eta Di (iK + Di))

/-- The pinned ladder ratio `ξ* = λ^{-Δᵢ/2}`. -/
noncomputable def xiStar (lam Di : ℝ) : ℝ := lam ^ (-(Di / 2))

/-- The marginal price on the grid is itself a pure `λ`-power of the tick:
`pPhiGrid(i_K) = λ^{-Δᵢ·η·(i_K + Δᵢ/2)}`. -/
lemma pPhiGrid_eq (lam eta Di iK : ℝ) (hlam : 0 < lam) :
    pPhiGrid lam eta Di iK = lam ^ (-(Di * eta * (iK + Di / 2))) := by
  unfold pPhiGrid pGrid
  rw [← Real.rpow_add hlam, one_div, ← Real.rpow_neg hlam.le]
  ring_nf

/-- **G3a — the Γ-grid law (the ξ-coordinatization of gamma), LEVEL form.**
The gamma of the pinned member on the grid is a PURE ξ-POWER of the tick, exactly as the
price is a λ-power of it: `−(L/2)·pPhiGrid^{−3/2} = −(L/2)·ξ^{−3η(i_K + Δᵢ/2)}`.
(Checked numerically at `(λ,Δᵢ,η,i_K,L) = (1.0001, 10, 1, 100, 7)` and at `η = 0.37`,
agreeing to machine precision. The factor 3 is `3/2 × 2`: the `p^{3/2}` shape composed
with the marginal-price step being the SQUARE of the grid step.) -/
theorem gamma_grid_level (lam eta Di L iK : ℝ) (hlam : 1 < lam) :
    -(L / 2) * (pPhiGrid lam eta Di iK) ^ (-(3 : ℝ) / 2)
      = -(L / 2) * (xiStar lam Di) ^ (-(3 * eta * (iK + Di / 2))) := by
  have h0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  rw [pPhiGrid_eq _ _ _ _ h0, xiStar, ← Real.rpow_mul h0.le, ← Real.rpow_mul h0.le]
  ring_nf

/-- **G3b — the Γ-grid law, RATIO form.** Per spacing, gamma steps geometrically with
ratio `ξ^{−3ηΔᵢ}` — the "gamma units" statement: Γ on base ξ as p on base λ. -/
theorem gamma_grid_ratio (lam eta Di L iK : ℝ) (hlam : 1 < lam) (hL : L ≠ 0) :
    (-(L / 2) * (pPhiGrid lam eta Di (iK + Di)) ^ (-(3 : ℝ) / 2)) /
        (-(L / 2) * (pPhiGrid lam eta Di iK) ^ (-(3 : ℝ) / 2))
      = (xiStar lam Di) ^ (-(3 * eta * Di)) := by
  have h0 : (0 : ℝ) < lam := lt_trans zero_lt_one hlam
  have hc : -(L / 2) ≠ 0 := by simpa using hL
  rw [pPhiGrid_eq _ _ _ _ h0, pPhiGrid_eq _ _ _ _ h0, xiStar,
    ← Real.rpow_mul h0.le, ← Real.rpow_mul h0.le, ← Real.rpow_mul h0.le,
    mul_div_mul_left _ _ hc, ← Real.rpow_sub h0]
  ring_nf

end GammaGrid
