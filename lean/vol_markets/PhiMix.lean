import Mathlib

/-!
# PhiMix — the anchor's curvature family written entirely in the φ-family

Doc context (VOLATILITY_INSTRUMENTS.md, # BEHAVIOR_WELFARE_UTILIZATION, E1): the anchor
(Capponi–Jia §5.1) mixes a linear component `F₀ = p·Q_X + p_B·Q_M` and a constant-product
component `F₁ = Q_X·Q_M` by a curvature weight ς ∈ [0,1]:
`F_ς = (1−ς)·A·F₀ + ς·F₁`. The document is CONSTRAINED to its own trading-function family
(Definition 13): `φ_(χ,1)(x,y) = χx + (1−χ)y` (linear CES member) and
`φ_(1/2,0)(x,y) = √(xy)` (balanced Cobb–Douglas member). GOAL: eliminate `F` — express the
whole family in φ-terms. Priority: M3 > M1 > M2 > M4. If a statement is false, refute it
as stated (named counterexample) and prove the corrected form under a new name. No silent
hypothesis-weakening: document every added hypothesis.
-/

namespace PhiMix

/-- Definition 13's ε = 1 (linear) member: `χ` on the `x` leg. -/
noncomputable def phiLin (χ x y : ℝ) : ℝ := χ * x + (1 - χ) * y

/-- Definition 13's (χ, ε) = (1/2, 0) balanced Cobb–Douglas member. -/
noncomputable def phiGeom (x y : ℝ) : ℝ := Real.sqrt (x * y)

/-- The anchor's mixed family, as in the paper (A the scaling coefficient,
`p` the numeraire-relative price of X, p_B = 1). -/
noncomputable def Fmix (ς A p x y : ℝ) : ℝ :=
  (1 - ς) * A * (p * x + y) + ς * (x * y)

/-- **M1 (linear component).** The anchor's `F₀` IS the rescaled ε = 1 member:
`p·x + y = (p+1)·φ_(p/(p+1),1)(x,y)` for `p > 0`. -/
theorem F0_eq_phiLin (p x y : ℝ) (hp : 0 < p) :
    p * x + y = (p + 1) * phiLin (p / (p + 1)) x y := by
  simp [phiLin]
  field_simp
  ring

/-- **M2 (constant-product component).** The anchor's `F₁` IS the square of the balanced
member: `(φ_(1/2,0)(x,y))² = x·y` for `0 ≤ x`, `0 ≤ y`. -/
theorem F1_eq_phiGeom_sq (x y : ℝ) (hx : 0 ≤ x) (hy : 0 ≤ y) :
    (phiGeom x y) ^ 2 = x * y := by
  simp [phiGeom]
  exact Real.sq_sqrt (mul_nonneg hx hy)

/-- **M3 — THE TARGET (the family in φ-terms; eliminates F).**
`F_ς = (1−ς)·A·(p+1)·φ_(p/(p+1),1) + ς·(φ_(1/2,0))²` — the anchor's curvature family is a
convex separation across the ε-axis ENDPOINT members of Definition 13's family (the ε = 1
member rescaled, and the SQUARE of the ε = 0 balanced member; the square is the homogeneity
mismatch that makes interior members non-CES). -/
theorem Fmix_eq_phi (ς A p x y : ℝ) (hp : 0 < p) (hx : 0 ≤ x) (hy : 0 ≤ y) :
    Fmix ς A p x y
      = (1 - ς) * A * ((p + 1) * phiLin (p / (p + 1)) x y)
        + ς * (phiGeom x y) ^ 2 := by
  unfold Fmix
  rw [F0_eq_phiLin p x y hp, F1_eq_phiGeom_sq x y hx hy]

/-- **M4 (the homogeneity obstruction, complementing the proven family refutation).**
`Fmix ς A p` is positively 1-homogeneous in `(x,y)` iff the mix is degenerate:
for `A, p > 0`, `(∀ t > 0, ∀ x y ≥ 0, Fmix ς A p (t*x) (t*y) = t * Fmix ς A p x y) ↔ ς = 0`.
The statement is TRUE exactly as given, so no correction (`Fmix_homogeneous_iff_corrected`)
is needed: scaling gives `Fmix ς A p (t*x) (t*y) = t·(1−ς)·A·(p·x+y) + ς·t²·x·y`, and the
quadratic term forces `ς = 0` (take `t = 2`, `x = y = 1`).

Hypothesis note: the supplied hypotheses `hA : 0 < A` and `hp : 0 < p` are retained because
they are part of the requested statement, but the proof does not need them — the
equivalence holds for all real `A`, `p`. No hypotheses were added. -/
theorem Fmix_homogeneous_iff (ς A p : ℝ) (hA : 0 < A) (hp : 0 < p) :
    (∀ t : ℝ, 0 < t → ∀ x y : ℝ, 0 ≤ x → 0 ≤ y →
      Fmix ς A p (t * x) (t * y) = t * Fmix ς A p x y) ↔ ς = 0 := by
  constructor
  · intro h
    -- Use t=2, x=1, y=1 to derive a contradiction unless ς=0
    have := h 2 (by norm_num) 1 1 (by norm_num) (by norm_num)
    simp [Fmix] at this
    linarith
  · intro hς t ht x y hx hy
    simp [hς, Fmix]
    ring

end PhiMix
