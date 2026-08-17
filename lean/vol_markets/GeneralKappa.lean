import vol_markets.EllIntrinsic

/-!
# GeneralKappa — Definition 14 at GENERAL points: the elasticity, the benchmark, and
# the state-dependence of κ_φ

## Intent (user ruling, 2026-08-11: "Definition 14 is to be sent")

The document's Definition 14 defines the price-impact elasticity `ε_{p/X}` and the
curvature `κ_φ` by benchmark normalization AT THE SAME POINT. Only the BALANCED-point
layer is carried in-tree (`epsPX_balanced`, `kappaPhi_closed_form`). This bundle
supplies the GENERAL-point layer — and tests a finding verified numerically to machine
precision before submission (ρ = 1/2, ε = 3/10, c = 2, three states):

* the general elasticity has the closed form `(ρ−1)·c^ρ / ((1−ε)·y^ρ)` on the curve;
* the same-point benchmark (the ρ → 0 member through the same state) has the
  STATE-INDEPENDENT elasticity `−1/(1−ε)`;
* hence the general κ_φ is `(1−ρ)c^ρ / ((1−ρ)c^ρ + y^ρ)` — STATE-DEPENDENT off the
  balanced point (0.295 → 0.318 along one curve), reducing to `(1−ρ)/(2−ρ)` exactly at
  balance;
* and κ_φ is CONSTANT along the curve iff ρ = 0 — expected to be the FOURTH
  characterization of the geometric slice (field power-law; ladder realization; κ-map
  constancy; now member-curvature constancy).

The elasticity's differentiation variable is the RESERVE `x = Q_X^L` (the along-curve
derivative) — this bundle's carrier settles the document's standing `ε_{p/X}` argument
question by construction.

## Scaffolding

`EllIntrinsic` supplied, ALREADY PROVED — import, do not modify. Lean `ε` = document
share `χ_{X/M}`, `ρ` = document substitution `ε_{X/M}` (standing split). The radicand
guard `0 < (c^ρ − ε·x^ρ)/(1−ε)` is load-bearing.

## Instructions

Prove the `sorry`'d statements. Priority **K4 > K1 > K3 > K2**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome.

## Outcome

All four targets are TRUE exactly as supplied and are proved below; no refutation and no
corrected restatement was needed, and no hypothesis was strengthened or added. `EllIntrinsic`
is imported unmodified and the radicand guard `0 < (c^ρ - ε·x^ρ)/(1-ε)` is carried on every
curve-point statement (K1, K3) and produced as part of the witness data in K4.
-/

namespace GeneralKappa

open Real Set EllIntrinsic

/-- The along-curve price-impact elasticity at a GENERAL point:
`ε_{p/X}(x) = x · (dp/dx) / p` — the differentiation variable is the reserve. -/
noncomputable def epsG (ρ ε c x : ℝ) : ℝ :=
  x * deriv (pOf ρ ε c) x / pOf ρ ε c x

/-- **K1 — the general closed form.** On the curve,
`ε_{p/X}(x) = (ρ−1)·c^ρ / ((1−ε)·(yOf ρ ε c x)^ρ)`.

The hypotheses `hρ1 : ρ < 1` and `hc : 0 < c` are kept because they were supplied, but the
identity holds without them: the closed form is an algebraic cancellation that needs only
`ρ ≠ 0`, `0 < ε < 1`, `0 < x` and the radicand guard. -/
theorem epsG_closed_form (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hc : 0 < c)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    epsG ρ ε c x = (ρ - 1) * c ^ ρ / ((1 - ε) * (yOf ρ ε c x) ^ ρ) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hpe := pOf_eq ρ ε c x hρ hε0 hx hu
  have hde := (hasDerivAt_pOf' ρ ε c x hρ hε0 hε1 hx hu).deriv
  have hyU : (yOf ρ ε c x) ^ ρ = (c ^ ρ - ε * x ^ ρ) / (1 - ε) := by
    rw [yOf, ← Real.rpow_mul hu.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]
  have hx1 : x ^ (ρ - 1) = x ^ ρ / x := by rw [Real.rpow_sub hx, Real.rpow_one]
  have hx2 : x ^ (ρ - 2) = x ^ ρ / x ^ 2 := by rw [Real.rpow_sub hx]; norm_num
  set m : ℝ := (1 - ρ) / ρ with hmdef
  set U : ℝ := (c ^ ρ - ε * x ^ ρ) / (1 - ε) with hUdef
  clear_value U
  have hUm : (0 : ℝ) < U ^ m := Real.rpow_pos_of_pos hu _
  have hxρ : (0 : ℝ) < x ^ ρ := Real.rpow_pos_of_pos hx _
  rw [epsG, hpe, hde, hyU, hx1, hx2]
  have hk : ε / (1 - ε) ≠ 0 := by positivity
  field_simp

/-- **K2 — the same-point benchmark is state-independent.** The ρ → 0 (Cobb–Douglas)
member WITH THE SAME SHARE `ε` through the state `(x, y)` is the curve
`y₀(t) = y·(x/t)^{ε/(1−ε)}`; its marginal price is `p₀(t) = (ε/(1−ε))·y₀(t)/t` and its
along-curve elasticity is `−1/(1−ε)` at EVERY `t > 0` — state-independent, magnitude
`1/(1−ε)`, exactly the document's benchmark. -/
theorem benchmark_state_independent (ε x y t : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) (ht : 0 < t) :
    t * deriv (fun s => (ε / (1 - ε)) * (y * (x / s) ^ (ε / (1 - ε)) / s)) t /
        ((ε / (1 - ε)) * (y * (x / t) ^ (ε / (1 - ε)) / t)) = -(1 / (1 - ε)) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  set k : ℝ := ε / (1 - ε) with hkdef
  have hk0 : 0 < k := div_pos hε0 hε'
  -- On `s > 0` the benchmark price is the pure power `C · s ^ (-(k+1))`.
  have hEq : (fun s => k * (y * (x / s) ^ k / s))
      =ᶠ[nhds t] (fun s => (k * y * x ^ k) * s ^ (-(k + 1))) := by
    have h1 : {s : ℝ | 0 < s} ∈ nhds t := (isOpen_lt continuous_const continuous_id).mem_nhds ht
    filter_upwards [h1] with s hs
    have hs' : 0 < s := hs
    rw [Real.div_rpow hx.le hs'.le, neg_add, Real.rpow_add hs', Real.rpow_neg hs'.le,
      Real.rpow_neg_one]
    field_simp
  have hderiv : HasDerivAt (fun s : ℝ => (k * y * x ^ k) * s ^ (-(k + 1)))
      ((k * y * x ^ k) * (-(k + 1) * t ^ (-(k + 1) - 1))) t :=
    (Real.hasDerivAt_rpow_const (x := t) (p := -(k + 1)) (Or.inl ht.ne')).const_mul _
  have hd : deriv (fun s => k * (y * (x / s) ^ k / s)) t
      = (k * y * x ^ k) * (-(k + 1) * t ^ (-(k + 1) - 1)) :=
    (hderiv.congr_of_eventuallyEq hEq).deriv
  have hval : k * (y * (x / t) ^ k / t) = (k * y * x ^ k) * t ^ (-(k + 1)) := hEq.eq_of_nhds
  rw [hd, hval]
  have hxk : (0 : ℝ) < x ^ k := Real.rpow_pos_of_pos hx _
  have htk : (0 : ℝ) < t ^ (-(k + 1)) := Real.rpow_pos_of_pos ht _
  have htk1 : t ^ (-(k + 1) - 1) = t ^ (-(k + 1)) / t := by
    rw [Real.rpow_sub ht, Real.rpow_one]
  have hne : (1 : ℝ) - ε ≠ 0 := ne_of_gt hε'
  rw [htk1, show k + 1 = 1 / (1 - ε) by rw [hkdef]; field_simp; ring]
  field_simp

/-- `(s ^ (1/ρ)) ^ ρ = s` for `s > 0` and `ρ ≠ 0`. -/
lemma rpow_inv_self {s ρ : ℝ} (hs : 0 < s) (hρ : ρ ≠ 0) : (s ^ (1 / ρ)) ^ ρ = s := by
  rw [← Real.rpow_mul hs.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]

/-- The map `U ↦ A / (A + U)` is injective on the positives, for `A > 0`. -/
lemma kappa_ratio_ne (A U V : ℝ) (hA : 0 < A) (hU : 0 < U) (hV : 0 < V) (hUV : U ≠ V) :
    A / (A + U) ≠ A / (A + V) := by
  intro h
  rw [div_eq_div_iff (by positivity) (by positivity)] at h
  exact hUV (mul_left_cancel₀ hA.ne' (by nlinarith))

/-- The `y` leg's `ρ`-th power on the curve is the radicand. -/
lemma yOf_rpow_self (ρ ε c x : ℝ) (hρ : ρ ≠ 0)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    (yOf ρ ε c x) ^ ρ = (c ^ ρ - ε * x ^ ρ) / (1 - ε) := by
  rw [yOf, ← Real.rpow_mul hu.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]

/-- The benchmark-normalized curvature in terms of the radicand. -/
lemma kappa_eq_radicand (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hc : 0 < c)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    |epsG ρ ε c x| / (|epsG ρ ε c x| + 1 / (1 - ε))
      = (1 - ρ) * c ^ ρ / ((1 - ρ) * c ^ ρ + (c ^ ρ - ε * x ^ ρ) / (1 - ε)) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hcρ : (0 : ℝ) < c ^ ρ := Real.rpow_pos_of_pos hc _
  have h1ρ : (0 : ℝ) < 1 - ρ := by linarith
  have hE := epsG_closed_form ρ ε c x hρ hρ1 ⟨hε0, hε1⟩ hx hc hu
  rw [yOf_rpow_self ρ ε c x hρ hu] at hE
  set U : ℝ := (c ^ ρ - ε * x ^ ρ) / (1 - ε) with hUdef
  clear_value U
  have habs : |epsG ρ ε c x| = (1 - ρ) * c ^ ρ / ((1 - ε) * U) := by
    rw [hE, show (ρ - 1) * c ^ ρ / ((1 - ε) * U) = -((1 - ρ) * c ^ ρ / ((1 - ε) * U)) by ring,
      abs_neg, abs_of_pos (by positivity)]
  rw [habs]
  have hden : (0 : ℝ) < (1 - ρ) * c ^ ρ + U := by positivity
  have hden2 : (0 : ℝ) < (1 - ρ) * c ^ ρ / ((1 - ε) * U) + 1 / (1 - ε) := by positivity
  field_simp

/-- **K3 — the general κ_φ and its balanced value.** With the benchmark magnitude
`1/(1−ε)` (K2's Cobb–Douglas elasticity carries the share factor; the DOCUMENT's
benchmark is the same-point substitution-0 member, magnitude `1/(1−ε)`), the
benchmark-normalized curvature at a general point is
`κ_φ(x) = (1−ρ)c^ρ / ((1−ρ)c^ρ + (yOf ρ ε c x)^ρ)`, and AT the balanced point
(`yOf ρ ε c x = x`) it reduces to `(1−ρ)/(2−ρ)` — Theorem 31's value is the
BALANCED-point instance. -/
theorem kappa_general_form (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hc : 0 < c)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    |epsG ρ ε c x| / (|epsG ρ ε c x| + 1 / (1 - ε))
      = (1 - ρ) * c ^ ρ / ((1 - ρ) * c ^ ρ + (yOf ρ ε c x) ^ ρ) ∧
    (yOf ρ ε c x = x →
      |epsG ρ ε c x| / (|epsG ρ ε c x| + 1 / (1 - ε)) = (1 - ρ) / (2 - ρ)) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hcρ : (0 : ℝ) < c ^ ρ := Real.rpow_pos_of_pos hc _
  have hyU := yOf_rpow_self ρ ε c x hρ hu
  have hmain := kappa_eq_radicand ρ ε c x hρ hρ1 ⟨hε0, hε1⟩ hx hc hu
  refine ⟨by rw [hmain, hyU], fun hbal => ?_⟩
  -- at the balanced point the radicand equals `x ^ ρ = c ^ ρ`
  have hxU : x ^ ρ = (c ^ ρ - ε * x ^ ρ) / (1 - ε) := by rw [← hyU, hbal]
  have hcx : c ^ ρ = x ^ ρ := by field_simp at hxU; linarith
  rw [hmain, ← hxU, ← hcx]
  have h1ρ : (0 : ℝ) < 1 - ρ := by linarith
  have h2ρ : (2 : ℝ) - ρ ≠ 0 := by intro h; linarith
  rw [div_eq_div_iff (by positivity) h2ρ]
  ring

/-- **K4 — THE FINDING: κ_φ is state-dependent off the geometric slice.** The
general-point curvature is NOT constant along the curve for `ρ ≠ 0`: two states with
different money legs give different values (the `y^ρ` term moves). Stated as: for
`ρ ≠ 0` (guards as above) there EXIST two admissible states on the same curve with
different κ_φ values. Together with the ρ → 0 limit (where the form tends to
`c⁰/(c⁰+y⁰) = 1/2` identically) this is the FOURTH characterization of the geometric
slice. Expected shape: exhibit two explicit states via the share sweep. -/
theorem kappa_state_dependent (ρ ε c : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hc : 0 < c) :
    ∃ x₁ x₂ : ℝ, 0 < x₁ ∧ 0 < x₂ ∧
      0 < (c ^ ρ - ε * x₁ ^ ρ) / (1 - ε) ∧ 0 < (c ^ ρ - ε * x₂ ^ ρ) / (1 - ε) ∧
      |epsG ρ ε c x₁| / (|epsG ρ ε c x₁| + 1 / (1 - ε))
        ≠ |epsG ρ ε c x₂| / (|epsG ρ ε c x₂| + 1 / (1 - ε)) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hcρ : (0 : ℝ) < c ^ ρ := Real.rpow_pos_of_pos hc _
  have h1ρ : (0 : ℝ) < 1 - ρ := by linarith
  -- two states on the same curve, consuming shares `1/2` and `1/4` of the budget `c ^ ρ`
  have hs1 : (0 : ℝ) < c ^ ρ / (2 * ε) := by positivity
  have hs2 : (0 : ℝ) < c ^ ρ / (4 * ε) := by positivity
  refine ⟨(c ^ ρ / (2 * ε)) ^ (1 / ρ), (c ^ ρ / (4 * ε)) ^ (1 / ρ),
    Real.rpow_pos_of_pos hs1 _, Real.rpow_pos_of_pos hs2 _, ?_, ?_, ?_⟩
  case _ =>
    rw [rpow_inv_self hs1 hρ, show c ^ ρ - ε * (c ^ ρ / (2 * ε)) = c ^ ρ / 2 by
      field_simp; ring]
    positivity
  case _ =>
    rw [rpow_inv_self hs2 hρ, show c ^ ρ - ε * (c ^ ρ / (4 * ε)) = 3 * c ^ ρ / 4 by
      field_simp; ring]
    positivity
  case _ =>
    have hU1 : (c ^ ρ - ε * ((c ^ ρ / (2 * ε)) ^ (1 / ρ)) ^ ρ) / (1 - ε)
        = c ^ ρ / 2 / (1 - ε) := by
      rw [rpow_inv_self hs1 hρ]; congr 1; field_simp; ring
    have hU2 : (c ^ ρ - ε * ((c ^ ρ / (4 * ε)) ^ (1 / ρ)) ^ ρ) / (1 - ε)
        = 3 * c ^ ρ / 4 / (1 - ε) := by
      rw [rpow_inv_self hs2 hρ]; congr 1; field_simp; ring
    have hU1pos : 0 < (c ^ ρ - ε * ((c ^ ρ / (2 * ε)) ^ (1 / ρ)) ^ ρ) / (1 - ε) := by
      rw [hU1]; positivity
    have hU2pos : 0 < (c ^ ρ - ε * ((c ^ ρ / (4 * ε)) ^ (1 / ρ)) ^ ρ) / (1 - ε) := by
      rw [hU2]; positivity
    rw [kappa_eq_radicand ρ ε c _ hρ hρ1 ⟨hε0, hε1⟩ (Real.rpow_pos_of_pos hs1 _) hc hU1pos,
      kappa_eq_radicand ρ ε c _ hρ hρ1 ⟨hε0, hε1⟩ (Real.rpow_pos_of_pos hs2 _) hc hU2pos,
      hU1, hU2]
    refine kappa_ratio_ne _ _ _ (by positivity) (by positivity) (by positivity) ?_
    intro h
    field_simp at h
    linarith

end GeneralKappa
