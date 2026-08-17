import Mathlib

/-!
# NuKappa — utilization walks the κ-tree: the provable spine

## Intent (user structure, 2026-08-11)

The control closure: LVR walks the Γ-tree (proved), the fee walks utilization
(Theorem 1's gate), and the wanted third leg is UTILIZATION WALKING THE κ-TREE:
`ν_φ(κ_φ; t) ≡ κ_φ^{g_φ(·; i(t))}` — the integrated depleted-reserve ratio represented
as a κ-power, making the gate `u = α_R·Λ(γ_R(κ^g − β_R))` curvature-driven and pinning
the kernel `α_R` as a function of κ. This bundle proves the SPINE; the identification of
the exponent with the fee-tree object stays the document's OPEN modelling claim.

`phiHalf x y = √(x·y)` is the pinned member (Rule 5). Targets:

* V1 — the inception ratio is IDENTICALLY 1: an on-curve trade (one preserving the
  product) cannot move the level ratio.
* V2 — depletion makes the ratio INTERIOR: strictly depleted positive reserves give a
  ratio in (0,1).
* V3 — WELL-POSEDNESS of the representation: for `ν, κ ∈ (0,1)` there is a UNIQUE
  `g > 0` with `κ^g = ν`, namely `g = log ν / log κ`.
* V4 — the ACCUMULATOR law: per-step ratios multiply, exponents ADD — the κ-power
  representation of a product of interior ratios carries the SUM of the per-step
  exponents (the `feeGrowth` accumulator type).

## Instructions

Prove the `sorry`'d statements. Priority **V3 > V4 > V1 > V2**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. Do not modify
any definition. `Real.rpow` off the positives is `log|·|`-based — the positivity guards
are load-bearing.
-/

namespace NuKappa

open Real Set

/-- The pinned member (Rule 5): `φ_{(1/2,0)}(x,y) = √(x·y)`. -/
noncomputable def phiHalf (x y : ℝ) : ℝ := Real.sqrt (x * y)

/-- **V1 — the inception ratio is identically 1.** An on-curve trade — one preserving
the product — cannot move the level ratio: if `(x+a)(y+b) = x·y` then
`φ(x+a, y+b)/φ(x,y) = 1`. (The post-trade positivity guards `hxa`, `hyb` are kept as
stated by the user, but turn out to be unnecessary: the curve constraint alone forces
the two square-root arguments to coincide.) -/
theorem inception_ratio_one (x y a b : ℝ) (hx : 0 < x) (hy : 0 < y)
    (hxa : 0 < x + a) (hyb : 0 < y + b)
    (hcurve : (x + a) * (y + b) = x * y) :
    phiHalf (x + a) (y + b) / phiHalf x y = 1 := by
  have hpos : 0 < x * y := mul_pos hx hy
  have hne : phiHalf x y ≠ 0 := by
    simp only [phiHalf]
    exact ne_of_gt (Real.sqrt_pos.mpr hpos)
  simp only [phiHalf, hcurve]
  exact div_self hne

/-- **V2 — depletion makes the ratio interior.** Strictly depleted positive reserves:
`0 < u < x`, `0 < v < y` give `φ(x−u, y−v)/φ(x,y) ∈ (0,1)`. -/
theorem depleted_ratio_interior (x y u v : ℝ) (hx : 0 < x) (hy : 0 < y)
    (hu : 0 < u) (hux : u < x) (hv : 0 < v) (hvy : v < y) :
    phiHalf (x - u) (y - v) / phiHalf x y ∈ Ioo (0 : ℝ) 1 := by
  have hxu : 0 < x - u := by linarith
  have hyv : 0 < y - v := by linarith
  have hnum : 0 < Real.sqrt ((x - u) * (y - v)) := Real.sqrt_pos.mpr (mul_pos hxu hyv)
  have hden : 0 < Real.sqrt (x * y) := Real.sqrt_pos.mpr (mul_pos hx hy)
  have hlt : (x - u) * (y - v) < x * y := by nlinarith
  simp only [phiHalf, mem_Ioo]
  refine ⟨div_pos hnum hden, ?_⟩
  rw [div_lt_one hden]
  exact Real.sqrt_lt_sqrt (by positivity) hlt

/-- **V3 — well-posedness of the κ-power representation.** For `ν, κ ∈ (0,1)` there is a
UNIQUE positive exponent with `κ^g = ν`: existence via `g = log ν / log κ` (both logs
negative, so `g > 0`), uniqueness by strict monotonicity of `g ↦ κ^g` for `κ ∈ (0,1)`. -/
theorem kappa_power_representation (ν κ : ℝ) (hν : ν ∈ Ioo (0 : ℝ) 1)
    (hκ : κ ∈ Ioo (0 : ℝ) 1) :
    ∃! g : ℝ, 0 < g ∧ κ ^ (g : ℝ) = ν := by
  obtain ⟨hν0, hν1⟩ := hν
  obtain ⟨hκ0, hκ1⟩ := hκ
  have hlogν : Real.log ν < 0 := Real.log_neg hν0 hν1
  have hlogκ : Real.log κ < 0 := Real.log_neg hκ0 hκ1
  refine ⟨Real.log ν / Real.log κ, ⟨div_pos_of_neg_of_neg hlogν hlogκ, ?_⟩, ?_⟩
  · rw [Real.rpow_def_of_pos hκ0, mul_div_cancel₀ _ (ne_of_lt hlogκ), Real.exp_log hν0]
  · rintro g ⟨-, hg⟩
    have hlog : g * Real.log κ = Real.log ν := by
      rw [← Real.log_rpow hκ0 g, hg]
    exact eq_div_of_mul_eq (ne_of_lt hlogκ) hlog

/-- **V4 — the accumulator law.** Per-step ratios multiply, exponents ADD: if
`κ^{g₁} = ν₁` and `κ^{g₂} = ν₂` then `κ^{g₁+g₂} = ν₁·ν₂` — the κ-power representation
of the accumulated utilization carries the SUM of per-step exponents, the accumulator
type of the on-chain fee-growth object. -/
theorem exponent_accumulator (κ g₁ g₂ ν₁ ν₂ : ℝ) (hκ : κ ∈ Ioo (0 : ℝ) 1)
    (h₁ : κ ^ (g₁ : ℝ) = ν₁) (h₂ : κ ^ (g₂ : ℝ) = ν₂) :
    κ ^ (g₁ + g₂ : ℝ) = ν₁ * ν₂ := by
  rw [Real.rpow_add hκ.1, h₁, h₂]

end NuKappa

