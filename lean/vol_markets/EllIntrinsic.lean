import Mathlib

/-!
# EllIntrinsic — dimensionally consistent (intrinsic) liquidity, indexed by (ρ, ε)

## Source and goal

Risk–Tung–Wang, *Pricing and hedging for liquidity provision in Constant Function Market
Making* (arXiv:2603.01344v1), §2.1 "Dimensionally Consistent Liquidity", building on
Tung–Wang (arXiv:2412.18580), Appendix B. For a smooth bonding curve `f(x,y) = K` they
define the **local intrinsic liquidity**

  ℓ := -2 (f_x f_y)^{3/2} / (f_yy f_x^2 - 2 f_xy f_x f_y + f_xx f_y^2)          (their eqn 2.1)

Motivation (theirs): for the CPMM `√(xy) = K` the level `K` has physical dimension
`√(ETH × USDC)`, but for a geometric-mean market maker `x^α y^{1-α} = K` the level carries
`ETH^α × USDC^{1-α}`. The level is therefore NOT a dimensionally consistent proxy for depth
across curves. `ℓ` is: it always lands in the CPMM dimension `√(ETH × USDC)`, it is LOCAL
(a state function `ℓ(x,y)`, not a global constant), and it is INVARIANT under
reparametrization of the curve (`xy = K^2` and `√(xy) = K` give the same `ℓ`).
They record for the geometric-mean curve `ℓ = 2√(α(1-α)) √(xy)`, hence `ℓ = √(xy) = K` at
`α = 1/2` (CPMM).

GOAL of this file: obtain `ℓ` in closed form for OUR trading family (`phiCES`, below),
determine whether `ℓ/√(xy)` is state-constant, and establish the reduction of a general
member to the constant-product ("half-kernel") member that on-chain protocols instantiate.

## Notation map (READ THIS — the glyphs deliberately disagree with the source document)

* `phiCES ρ ε x y` is COPIED BYTE-IDENTICALLY from the in-tree `vol_markets/PhiCES.lean`.
  In THAT definition `ε` is the **share** coefficient and `ρ` is the **substitution
  exponent**. In the governing document the share is written `χ_{X/M}` and the substitution
  parameter is written `ε_{X/M}` — so the document's `ε_{X/M}` is this file's `ρ`, and the
  document's `χ_{X/M}` is this file's `ε`. This is the standing doc-glyph/Lean-name split:
  **do not rename anything**; the Lean names are fixed by the existing bundle.
* **The intrinsic liquidity is indexed by the PARAMETERS that characterize the family, never
  by the family's name** (binding ruling): the object is `ell ρ ε x y`, read as
  `ℓ_(ρ,ε)(x,y)` — the leading arguments ARE the subscript tuple, exactly as the governing
  document writes `φ_(χ,ε)` and `p_(η,Δᵢ)`. There is no `ellCES`, no family-name subscript.
  (`phiCES` keeps its name only because it is an EXISTING in-tree definition and Lean names
  are never renamed to follow document glyphs — the standing doc-glyph/Lean-name split.)
* The source paper's bare symbol `ℓ` collides with the document's ladder weight `ℓ(ξ,ι;i_K)`,
  a dimensionless simplex weight — a different object with a different parameter tuple. The
  two are told apart by their index tuples, and no statement below uses an unindexed `ℓ`.
* `x` is the X (asset) leg, `y` the M (money/numeraire) leg. The leg-orientation question
  is OPEN in the source document; nothing below depends on its resolution, because every
  statement is symmetric under simultaneously swapping `(x,y)` and `ε ↦ 1-ε`.

## Instructions

Prove the `sorry`'d statements. Priority **L1 > L7 > L4 > L2 > L3 > L5 > L6**.

If a statement is FALSE as written, do NOT weaken it silently: refute it as stated with a
named explicit counterexample (`..._false`), and prove the corrected form under a NEW name
(`..._corrected`). Document every added hypothesis in the docstring. Guard hypotheses that
are genuinely needed (`0 < x`, `0 < y`, `ρ < 1`, `ε ∈ Ioo 0 1`, `ρ ≠ 0`) are supplied;
if you need MORE, say so explicitly in the docstring rather than adding them quietly.

`Real.rpow` is `log |·|`-based off the positives — the positivity guards are load-bearing,
not decoration.

## OUTCOME OF THIS BUNDLE (summary; details in the individual docstrings)

* **L1 is FALSE as stated** and is refuted by `ellAt_eq_ell_false` with the explicit witness
  `(ρ, ε, c, x) = (1/2, 1/2, 1/4, 4)`. The guard `0 < yOf ρ ε c x` does NOT force the
  radicand `u := (c^ρ - ε x^ρ)/(1-ε)` to be positive: at that witness `u = -1 < 0`, yet
  `yOf = u ^ (1/ρ) = (-1) ^ (2 : ℝ) = 1 > 0`, because `Real.rpow` at a negative base is
  `|·|^· cos(π·)`-shaped and the cosine factor is `+1` here. Off the positive radicand the
  identity `(yOf)^ρ = u` fails, and with it the closed form: at the witness
  `ellAt = -8√2 < 0` while `ell = 8√2/3 > 0`.
  The corrected statement `ellAt_eq_ell_corrected` replaces the guard `0 < yOf ρ ε c x`
  (and drops `0 < c`, which the proof never uses; `c` enters only through `c ^ ρ`) by the
  **radicand guard** `hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)`, i.e. the state `x` lies
  strictly inside the level set. This is the only added hypothesis, it implies
  `0 < yOf ρ ε c x`, and on it the hand-derived closed form is proved in full.
* **L7(b) is FALSE as stated** for exactly the same reason (it is L1 in disguise): see
  `halfKernel_osculates_false`, same parameters with `xh = 16/3`. The corrected version
  `halfKernel_osculates_corrected` carries the same radicand guard `hu`.
* L2, L3, L4, L5, L6 and L7(a) are true as stated and are proved unchanged.
-/

namespace EllIntrinsic

open Real Set

/-- The trading family, byte-identical to `vol_markets/PhiCES.lean`.
`ε` = SHARE coefficient, `ρ` = substitution exponent (see the notation map above). -/
noncomputable def phiCES (ρ ε x y : ℝ) : ℝ :=
  (ε * x ^ ρ + (1 - ε) * y ^ ρ) ^ (1 / ρ)

/-- The source's eqn (2.1) as a PURELY ALGEBRAIC function of the five partial-derivative
values, so that the geometry and the analysis can be separated. -/
noncomputable def ellOf (fx fy fxx fxy fyy : ℝ) : ℝ :=
  -2 * (fx * fy) ^ ((3 : ℝ) / 2) / (fyy * fx ^ 2 - 2 * fxy * fx * fy + fxx * fy ^ 2)

/-- The level curve `phiCES ρ ε x y = c`, solved for the `y` leg. -/
noncomputable def yOf (ρ ε c x : ℝ) : ℝ :=
  ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ (1 / ρ)

/-- The marginal price `f_x / f_y` restricted to the level curve through `c`. -/
noncomputable def pOf (ρ ε c x : ℝ) : ℝ :=
  (ε / (1 - ε)) * (x / yOf ρ ε c x) ^ (ρ - 1)

/-- Intrinsic liquidity in PRICE form: `-2 p^{3/2} / (dp/dx)` along the level curve.
That this agrees with the source's `ellOf` form is target **L1**. -/
noncomputable def ellAt (ρ ε c x : ℝ) : ℝ :=
  -2 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2) / (deriv (pOf ρ ε c) x)

/-- **The claimed closed form** (derived by hand, checked numerically against a
finite-difference evaluation of eqn (2.1) at
`(ρ,ε,x,y) ∈ {(0.5,0.5,3,7), (0.5,0.5,6,14), (0.5,0.3,3,7), (-1,0.5,3,7), (-1,0.4,2,9),
(0.25,0.7,5,2)}`, agreeing to finite-difference precision). -/
noncomputable def ell (ρ ε x y : ℝ) : ℝ :=
  2 * Real.sqrt (ε * (1 - ε)) * (x * y) ^ ((ρ + 1) / 2) /
    ((1 - ρ) * (ε * x ^ ρ + (1 - ε) * y ^ ρ))

/-! ### Local form of the marginal price and its derivative

On the region where the radicand `u z = (c ^ ρ - ε * z ^ ρ) / (1 - ε)` is positive the
price `pOf` is a product of `rpow`s of positive bases, which is where all the `rpow`
algebra (and the differentiation) is valid. -/

/-- On a neighbourhood of a state with positive radicand, `pOf` is
`(ε/(1-ε)) · z^(ρ-1) · u(z)^((1-ρ)/ρ)`. -/
lemma pOf_eventuallyEq (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε0 : 0 < ε) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    pOf ρ ε c =ᶠ[nhds x]
      (fun z => (ε / (1 - ε)) * (z ^ (ρ - 1) * ((c ^ ρ - ε * z ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ))) := by
  have hUc : ContinuousAt (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε)) x := by
    apply ContinuousAt.div_const
    exact continuousAt_const.sub (continuousAt_const.mul
      (Real.continuousAt_rpow_const _ _ (Or.inl hx.ne')))
  have h1 : {z : ℝ | 0 < z} ∈ nhds x := (isOpen_lt continuous_const continuous_id).mem_nhds hx
  have h2 : (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε)) ⁻¹' (Ioi 0) ∈ nhds x :=
    hUc.preimage_mem_nhds (Ioi_mem_nhds hu)
  filter_upwards [h1, h2] with z hz hzu
  have hz' : 0 < z := hz
  have hzu' : 0 < (c ^ ρ - ε * z ^ ρ) / (1 - ε) := hzu
  have hy : yOf ρ ε c z = ((c ^ ρ - ε * z ^ ρ) / (1 - ε)) ^ (1 / ρ) := rfl
  have hypos : 0 < yOf ρ ε c z := by rw [hy]; exact Real.rpow_pos_of_pos hzu' _
  rw [pOf, Real.div_rpow hz'.le hypos.le, hy, ← Real.rpow_mul hzu'.le]
  rw [show (1 / ρ) * (ρ - 1) = -((1 - ρ) / ρ) by field_simp; ring]
  rw [Real.rpow_neg hzu'.le]
  field_simp

/-- Pointwise version of `pOf_eventuallyEq`. -/
lemma pOf_eq (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε0 : 0 < ε) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    pOf ρ ε c x
      = (ε / (1 - ε)) * (x ^ (ρ - 1) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ)) :=
  (pOf_eventuallyEq ρ ε c x hρ hε0 hx hu).eq_of_nhds

/-- Raw chain-rule form of the price impact `dp/dx`. -/
lemma hasDerivAt_pOf (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε0 : 0 < ε) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    HasDerivAt (pOf ρ ε c)
      ((ε / (1 - ε)) * (((ρ - 1) * x ^ (ρ - 2)) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ)
        + x ^ (ρ - 1) * ((-(ε * (ρ * x ^ (ρ - 1))) / (1 - ε)) * ((1 - ρ) / ρ)
            * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ - 1)))) x := by
  have hf : HasDerivAt (fun z : ℝ => z ^ (ρ - 1)) ((ρ - 1) * x ^ (ρ - 2)) x := by
    have h := Real.hasDerivAt_rpow_const (x := x) (p := ρ - 1) (Or.inl hx.ne')
    rw [show ρ - 1 - 1 = ρ - 2 by ring] at h
    exact h
  have hU : HasDerivAt (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε))
      ((0 - ε * (ρ * x ^ (ρ - 1))) / (1 - ε)) x :=
    ((hasDerivAt_const x (c ^ ρ)).sub
      ((Real.hasDerivAt_rpow_const (x := x) (p := ρ) (Or.inl hx.ne')).const_mul ε)).div_const _
  have hg : HasDerivAt (fun z : ℝ => ((c ^ ρ - ε * z ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ))
      (((0 - ε * (ρ * x ^ (ρ - 1))) / (1 - ε)) * ((1 - ρ) / ρ)
        * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ - 1)) x := hU.rpow_const (Or.inl hu.ne')
  have hmain := (hf.mul hg).const_mul (ε / (1 - ε))
  have h := hmain.congr_of_eventuallyEq (pOf_eventuallyEq ρ ε c x hρ hε0 hx hu)
  convert h using 1
  ring_nf

/-- Closed form of the price impact `dp/dx` along the level curve. -/
lemma hasDerivAt_pOf' (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε0 : 0 < ε) (hε1 : ε < 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    HasDerivAt (pOf ρ ε c)
      ((ε / (1 - ε)) * (ρ - 1) * x ^ (ρ - 2) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ)
          * c ^ ρ / ((1 - ε) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)))) x := by
  have h := hasDerivAt_pOf ρ ε c x hρ hε0 hx hu
  convert h using 1
  have hε' : (1 - ε) ≠ 0 := by linarith
  have hmr : ((1 - ρ) / ρ) * ρ = 1 - ρ := by field_simp
  have hc : c ^ ρ = (1 - ε) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) + ε * x ^ ρ := by field_simp; ring
  set m : ℝ := (1 - ρ) / ρ with hmdef
  set U : ℝ := (c ^ ρ - ε * x ^ ρ) / (1 - ε) with hUdef
  clear_value m U
  have hU0 : U ≠ 0 := ne_of_gt hu
  have hUm : U ^ (m - 1) = U ^ m / U := by rw [Real.rpow_sub hu, Real.rpow_one]
  have hx1 : x ^ (ρ - 1) = x ^ ρ / x := by rw [Real.rpow_sub hx, Real.rpow_one]
  have hx2 : x ^ (ρ - 2) = x ^ ρ / x ^ 2 := by rw [Real.rpow_sub hx]; norm_num
  rw [hUm, hx1, hx2, hc]
  field_simp
  linear_combination (ε * x ^ ρ) * hmr

/-! ### L1 — the closed form -/

/-
**L1 as originally stated is FALSE**; it is refuted by `ellAt_eq_ell_false` below and
corrected in `ellAt_eq_ell_corrected`.  The original statement is preserved here, commented
out, exactly as supplied:

/-- **L1 — THE TARGET. Closed form of the intrinsic liquidity for the CES family.**
The price-form intrinsic liquidity along the level curve equals `ell` evaluated at the
corresponding reserve state. -/
theorem ellAt_eq_ell (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hc : 0 < c)
    (hy : 0 < yOf ρ ε c x) :
    ellAt ρ ε c x = ell ρ ε x (yOf ρ ε c x) := by
  sorry
-/

/-- **L1 (corrected) — THE TARGET. Closed form of the intrinsic liquidity for the CES
family.** The price-form intrinsic liquidity along the level curve equals `ell` evaluated at
the corresponding reserve state.

CHANGES relative to the statement supplied as L1 (see `ellAt_eq_ell_false` for why they are
necessary):
* the guard `hy : 0 < yOf ρ ε c x` is REPLACED by the strictly stronger **radicand guard**
  `hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)` (the state `x` lies strictly inside the level
  set). `hu` implies `hy`, but not conversely: `Real.rpow` at a negative base can be
  positive, and there the identity `(yOf ρ ε c x) ^ ρ = (c^ρ - ε x^ρ)/(1-ε)` — on which the
  whole closed form rests — breaks down.
* the guard `hc : 0 < c` is DROPPED: it is never used, `c` entering only through `c ^ ρ`.

No other hypothesis was added; `hρ`, `hρ1`, `hε`, `hx` are as supplied. -/
theorem ellAt_eq_ell_corrected (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    ellAt ρ ε c x = ell ρ ε x (yOf ρ ε c x) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have h1ρ : (0 : ℝ) < 1 - ρ := by linarith
  have hk : 0 < ε / (1 - ε) := div_pos hε0 hε'
  have hcrho : c ^ ρ = (1 - ε) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) + ε * x ^ ρ := by
    field_simp; ring
  have hyeq : yOf ρ ε c x = ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ (1 / ρ) := rfl
  have hpe := pOf_eq ρ ε c x hρ hε0 hx hu
  have hde := (hasDerivAt_pOf' ρ ε c x hρ hε0 hε1 hx hu).deriv
  have hsq : Real.sqrt (ε * (1 - ε)) = (ε / (1 - ε)) ^ ((1 : ℝ) / 2) * (1 - ε) := by
    rw [← Real.sqrt_eq_rpow, show ε * (1 - ε) = (ε / (1 - ε)) * (1 - ε) ^ 2 by field_simp,
      Real.sqrt_mul hk.le, Real.sqrt_sq hε'.le]
  set k : ℝ := ε / (1 - ε) with hkdef
  set m : ℝ := (1 - ρ) / ρ with hmdef
  set U : ℝ := (c ^ ρ - ε * x ^ ρ) / (1 - ε) with hUdef
  clear_value U
  have hU0 : U ≠ 0 := ne_of_gt hu
  have hcpos : 0 < c ^ ρ := by
    rw [hcrho]; have := Real.rpow_pos_of_pos hx ρ; nlinarith
  have hcrho2 : ε * x ^ ρ + (1 - ε) * U = c ^ ρ := by rw [hcrho]; ring
  have hy0 : 0 < yOf ρ ε c x := by rw [hyeq]; exact Real.rpow_pos_of_pos hu _
  have hyU : (yOf ρ ε c x) ^ ρ = U := by
    rw [hyeq, ← Real.rpow_mul hu.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]
  have hyhalf : (yOf ρ ε c x) ^ ((ρ + 1) / 2) = U ^ ((ρ + 1) / (2 * ρ)) := by
    rw [hyeq, ← Real.rpow_mul hu.le]; congr 1; field_simp
  have hp32 : (pOf ρ ε c x) ^ ((3 : ℝ) / 2)
      = k ^ ((3 : ℝ) / 2) * x ^ ((ρ - 1) * (3 / 2)) * U ^ (m * (3 / 2)) := by
    rw [hpe, Real.mul_rpow hk.le (by positivity), Real.mul_rpow (by positivity) (by positivity),
      ← Real.rpow_mul hx.le, ← Real.rpow_mul hu.le, mul_assoc]
  have hkk : k ^ ((3 : ℝ) / 2) = k ^ ((1 : ℝ) / 2) * k := by
    rw [show (3 : ℝ) / 2 = 1 / 2 + 1 by norm_num, Real.rpow_add hk, Real.rpow_one]
  have hxx : x ^ ((ρ - 1) * (3 / 2)) = x ^ ((ρ + 1) / 2) * x ^ (ρ - 2) := by
    rw [← Real.rpow_add hx]; ring_nf
  have hUU : U ^ (m * (3 / 2)) = U ^ ((ρ + 1) / (2 * ρ)) * U ^ m * U⁻¹ := by
    rw [← Real.rpow_neg_one U, ← Real.rpow_add hu, ← Real.rpow_add hu]
    congr 1
    rw [hmdef]; field_simp; ring
  rw [ellAt, ell, hp32, hde, Real.mul_rpow hx.le hy0.le, hyhalf, hyU, hcrho2, hsq, hkk, hxx, hUU]
  have hxp : (0 : ℝ) < x ^ ((ρ + 1) / 2) := Real.rpow_pos_of_pos hx _
  have hxq : (0 : ℝ) < x ^ (ρ - 2) := Real.rpow_pos_of_pos hx _
  have hUp : (0 : ℝ) < U ^ ((ρ + 1) / (2 * ρ)) := Real.rpow_pos_of_pos hu _
  have hUq : (0 : ℝ) < U ^ m := Real.rpow_pos_of_pos hu _
  have hρ' : ρ - 1 ≠ 0 := by intro h; apply absurd hρ1; simp; linarith
  have h1ρ' : (1 : ℝ) - ρ ≠ 0 := ne_of_gt h1ρ
  field_simp
  ring

/-! ### The counterexample to L1 (and to L7(b))

At `(ρ, ε, c, x) = (1/2, 1/2, 1/4, 4)` the radicand is
`u = ((1/4)^(1/2) - (1/2)·4^(1/2))/(1/2) = -1 < 0`,
so the level curve does not pass through this state in the intended sense; nevertheless
`yOf = u ^ (1/ρ) = (-1) ^ (2 : ℝ) = 1 > 0`, so the supplied guard `0 < yOf ρ ε c x` is
satisfied.  There `pOf` is the honest function `z ↦ 1 - z^(-1/2)`, which is INCREASING, so
`ellAt < 0`, while `ell = 8√2/3 > 0`. -/

/-- The `y` leg at the counterexample parameters, as an explicit elementary function. -/
lemma yOf_cex (z : ℝ) : yOf (1 / 2) (1 / 2) (1 / 4) z = (1 - Real.sqrt z) ^ 2 := by
  rw [yOf]; norm_num
  rw [← Real.sqrt_eq_rpow,
    show ((1 : ℝ) / 2 - 1 / 2 * Real.sqrt z) / (1 / 2) = 1 - Real.sqrt z by ring]

/-- The marginal price at the counterexample parameters, for `z > 1`. -/
lemma pOf_cex (z : ℝ) (hz : 1 < z) : pOf (1 / 2) (1 / 2) (1 / 4) z = 1 - z ^ (-(1 / 2) : ℝ) := by
  have hz0 : (0 : ℝ) < z := by linarith
  have hs : 1 < Real.sqrt z := by
    have h := Real.sqrt_lt_sqrt (by norm_num : (0 : ℝ) ≤ 1) hz
    simpa using h
  have hsz : Real.sqrt z ^ 2 = z := Real.sq_sqrt hz0.le
  rw [pOf, yOf_cex]
  have h1 : z / (1 - Real.sqrt z) ^ 2 = (Real.sqrt z / (Real.sqrt z - 1)) ^ 2 := by
    rw [div_pow, hsz, show (1 - Real.sqrt z) ^ 2 = (Real.sqrt z - 1) ^ 2 by ring]
  rw [h1]
  have hpos : (0 : ℝ) < Real.sqrt z / (Real.sqrt z - 1) := div_pos (by linarith) (by linarith)
  rw [show ((1 : ℝ) / 2 - 1) = -(1 / 2) by norm_num,
    show (Real.sqrt z / (Real.sqrt z - 1)) ^ 2 = (Real.sqrt z / (Real.sqrt z - 1)) ^ ((2 : ℕ) : ℝ)
      by rw [Real.rpow_natCast],
    ← Real.rpow_mul hpos.le]
  norm_num
  rw [Real.rpow_neg_one, Real.rpow_neg hz0.le, ← Real.sqrt_eq_rpow]
  have h : Real.sqrt z ≠ 0 := by linarith
  field_simp

/-- The price impact at the counterexample state: strictly POSITIVE. -/
lemma deriv_pOf_cex : deriv (pOf (1 / 2) (1 / 2) (1 / 4)) 4 = 1 / 16 := by
  have hev : pOf (1 / 2) (1 / 2) (1 / 4) =ᶠ[nhds (4 : ℝ)] fun z => 1 - z ^ (-(1 / 2) : ℝ) := by
    have hmem : {z : ℝ | 1 < z} ∈ nhds (4 : ℝ) :=
      (isOpen_lt continuous_const continuous_id).mem_nhds (by norm_num)
    filter_upwards [hmem] with z hz using pOf_cex z hz
  rw [hev.deriv_eq]
  have hd : HasDerivAt (fun z : ℝ => 1 - z ^ (-(1 / 2) : ℝ))
      (-((-(1 / 2) : ℝ) * (4 : ℝ) ^ ((-(1 / 2) : ℝ) - 1))) 4 :=
    (Real.hasDerivAt_rpow_const (x := (4 : ℝ)) (p := (-(1 / 2) : ℝ))
      (Or.inl (by norm_num))).const_sub 1
  rw [hd.deriv]
  rw [show (-(1 / 2) - 1 : ℝ) = -(3 / 2) by norm_num,
    show (4 : ℝ) = 2 ^ ((2 : ℕ) : ℝ) by rw [Real.rpow_natCast]; norm_num,
    ← Real.rpow_mul (by norm_num)]
  rw [show ((2 : ℕ) : ℝ) * (-(3 / 2)) = -((3 : ℕ) : ℝ) by push_cast; ring,
    Real.rpow_neg (by norm_num), Real.rpow_natCast]
  norm_num

/-- The `y` leg at the counterexample state. -/
lemma yOf_cex_four : yOf (1 / 2) (1 / 2) (1 / 4) 4 = 1 := by
  rw [yOf_cex, show (4 : ℝ) = 2 ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]; norm_num

/-- The marginal price at the counterexample state. -/
lemma pOf_cex_four : pOf (1 / 2) (1 / 2) (1 / 4) 4 = 1 / 2 := by
  rw [pOf_cex 4 (by norm_num), Real.rpow_neg (by norm_num), ← Real.sqrt_eq_rpow,
    show (4 : ℝ) = 2 ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]
  norm_num

/-- The closed-form value at the counterexample state: strictly positive. -/
lemma ell_cex : ell (1 / 2) (1 / 2) 4 1 = 8 * Real.sqrt 2 / 3 := by
  have h4 : (4 : ℝ) ^ ((1 : ℝ) / 2) = 2 := by
    rw [← Real.sqrt_eq_rpow, show (4 : ℝ) = 2 ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]
  rw [ell, h4, Real.one_rpow]
  rw [show Real.sqrt ((1 : ℝ) / 2 * (1 - 1 / 2)) = 1 / 2 by
    rw [show (1 : ℝ) / 2 * (1 - 1 / 2) = (1 / 2) ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]]
  rw [show ((4 : ℝ) * 1) = 2 ^ ((2 : ℕ) : ℝ) by rw [Real.rpow_natCast]; norm_num,
    ← Real.rpow_mul (by norm_num),
    show ((2 : ℕ) : ℝ) * (((1 : ℝ) / 2 + 1) / 2) = 1 + 1 / 2 by push_cast; ring,
    Real.rpow_add (by norm_num), Real.rpow_one, ← Real.sqrt_eq_rpow]
  norm_num
  ring

lemma ell_cex_pos : 0 < ell (1 / 2) (1 / 2) 4 1 := by
  rw [ell_cex]
  have : 0 < Real.sqrt 2 := Real.sqrt_pos.2 (by norm_num)
  positivity

/-- **L1 is FALSE as stated.** Explicit counterexample: `(ρ, ε, c, x) = (1/2, 1/2, 1/4, 4)`.
All the supplied guards hold there — `ρ ≠ 0`, `ρ < 1`, `ε ∈ Ioo 0 1`, `0 < x`, `0 < c`, and
`0 < yOf ρ ε c x` (indeed `yOf = 1`) — yet `ellAt = -8√2 < 0 < 8√2/3 = ell`.
The reason is that the radicand `(c^ρ - ε x^ρ)/(1-ε) = -1` is negative: `Real.rpow` off the
positives is `|·|^· cos(π ·)`-shaped, so `yOf = (-1) ^ (2 : ℝ) = 1` is positive even though
`(yOf) ^ ρ = 1 ≠ -1` is not the radicand. See `ellAt_eq_ell_corrected` for the repaired
statement. -/
theorem ellAt_eq_ell_false :
    ¬ (∀ ρ ε c x : ℝ, ρ ≠ 0 → ρ < 1 → ε ∈ Ioo (0 : ℝ) 1 → 0 < x → 0 < c → 0 < yOf ρ ε c x →
        ellAt ρ ε c x = ell ρ ε x (yOf ρ ε c x)) := by
  intro h
  have hneg : ellAt (1 / 2) (1 / 2) (1 / 4) 4 < 0 := by
    rw [ellAt, pOf_cex_four, deriv_pOf_cex]
    have : (0 : ℝ) < ((1 : ℝ) / 2) ^ ((3 : ℝ) / 2) := Real.rpow_pos_of_pos (by norm_num) _
    nlinarith
  have hcontra := h (1 / 2) (1 / 2) (1 / 4) 4 (by norm_num) (by norm_num)
    (by constructor <;> norm_num) (by norm_num) (by norm_num) (by rw [yOf_cex_four]; norm_num)
  rw [yOf_cex_four] at hcontra
  have := ell_cex_pos
  linarith

/-! ### L2–L6 -/

/-- **L2 — the geometric-mean slice reproduces the source's stated value.**
As `ρ → 0` the closed form tends to `2√(ε(1-ε))·√(xy)` — the value the source records for
`x^α y^{1-α}` with `α = ε`. -/
theorem ell_tendsto_geom (ε x y : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hy : 0 < y) :
    Filter.Tendsto (fun ρ => ell ρ ε x y) (nhdsWithin 0 {(0 : ℝ)}ᶜ)
      (nhds (2 * Real.sqrt (ε * (1 - ε)) * Real.sqrt (x * y))) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hxy : (0 : ℝ) < x * y := by positivity
  have hval : ell 0 ε x y = 2 * Real.sqrt (ε * (1 - ε)) * Real.sqrt (x * y) := by
    unfold ell
    rw [Real.rpow_zero, Real.rpow_zero]
    norm_num [← Real.sqrt_eq_rpow]
  have hcont : ContinuousAt (fun ρ : ℝ => ell ρ ε x y) 0 := by
    unfold ell
    apply ContinuousAt.div
    · exact continuousAt_const.mul
        ((Real.continuousAt_const_rpow (ne_of_gt hxy)).comp (by fun_prop))
    · exact (by fun_prop : ContinuousAt (fun ρ : ℝ => (1 - ρ)) 0).mul
        ((continuousAt_const.mul (Real.continuousAt_const_rpow (ne_of_gt hx))).add
          (continuousAt_const.mul (Real.continuousAt_const_rpow (ne_of_gt hy))))
    · simp
  rw [← hval]
  exact hcont.tendsto.mono_left nhdsWithin_le_nhds

/-- **L3 — the CPMM (half-kernel) point.** At the balanced share `ε = 1/2`, the `ρ → 0`
limit is exactly `√(xy)`: intrinsic liquidity coincides with the CPMM level, which is the
source's dimensional normalization. -/
theorem ell_tendsto_cpmm (x y : ℝ) (hx : 0 < x) (hy : 0 < y) :
    Filter.Tendsto (fun ρ => ell ρ (1/2) x y) (nhdsWithin 0 {(0 : ℝ)}ᶜ)
      (nhds (Real.sqrt (x * y))) := by
  have h := ell_tendsto_geom (1 / 2) x y (by constructor <;> norm_num) hx hy
  have hval : 2 * Real.sqrt ((1 / 2 : ℝ) * (1 - 1 / 2)) * Real.sqrt (x * y)
      = Real.sqrt (x * y) := by
    rw [show (1 / 2 : ℝ) * (1 - 1 / 2) = (1 / 2) ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]
    ring
  rwa [hval] at h

/-- Ratio form of `ell` at a state with `y = 1`, in terms of `a ^ ρ`. -/
lemma ell_ratio_one (ρ ε a : ℝ) (ha : 0 < a) :
    ell ρ ε a 1 / Real.sqrt (a * 1)
      = 2 * Real.sqrt (ε * (1 - ε)) * Real.sqrt (a ^ ρ) / ((1 - ρ) * (ε * a ^ ρ + (1 - ε))) := by
  have h1 : a ^ ((ρ + 1) / 2) = a ^ (ρ / 2) * a ^ ((1 : ℝ) / 2) := by
    rw [← Real.rpow_add ha]; ring_nf
  have h2 : a ^ (ρ / 2) = Real.sqrt (a ^ ρ) := by
    rw [Real.sqrt_eq_rpow, ← Real.rpow_mul ha.le]; ring_nf
  have h3 : Real.sqrt a = a ^ ((1 : ℝ) / 2) := Real.sqrt_eq_rpow a
  unfold ell
  rw [mul_one, Real.one_rpow, h1, h2, mul_one, h3]
  have : a ^ ((1 : ℝ) / 2) ≠ 0 := by positivity
  field_simp

/-- **L4 — state-constancy holds ONLY on the Cobb–Douglas slice.**
`ell ρ ε x y / √(xy)` is independent of the reserve state iff `ρ = 0`. Numerically the
forward direction fails visibly at `ρ = 1/2, ε = 3/10`, where the ratio moves from
`≈ 1.2968` at `(x,y) = (1,10)` to `≈ 1.9771` at `(10,1)`; use that as the witness shape.
NOTE `ρ = 0` is not in `phiCES`'s domain (`1/ρ`), so state the `ρ = 0` side through the
`ρ → 0` limit of L2 rather than by evaluation.

The proof compares three states with `y = 1`: `x` with `x ^ ρ = 1, 4, 9` respectively.
State-constancy would force `√k = ε k + (1 - ε)` for every `k > 0`, hence `ε = 1/3` (from
`k = 4`) and `ε = 1/4` (from `k = 9`). -/
theorem ell_ratio_const_iff (ε : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1) (ρ : ℝ) (hρ : ρ ≠ 0)
    (hρ1 : ρ < 1) :
    (∀ x y x' y' : ℝ, 0 < x → 0 < y → 0 < x' → 0 < y' →
        ell ρ ε x y / Real.sqrt (x * y) = ell ρ ε x' y' / Real.sqrt (x' * y'))
      ↔ False := by
  obtain ⟨hε0, hε1⟩ := hε
  constructor
  · intro h
    have hs : 0 < Real.sqrt (ε * (1 - ε)) := Real.sqrt_pos.2 (by nlinarith)
    have hρ0 : (0 : ℝ) < 1 - ρ := by linarith
    have key : ∀ k : ℝ, 0 < k → Real.sqrt k * (1 : ℝ) = 1 * (ε * k + (1 - ε)) := by
      intro k hk
      set a : ℝ := k ^ (1 / ρ) with hadef
      have ha : 0 < a := Real.rpow_pos_of_pos hk _
      have hak : a ^ ρ = k := by
        rw [hadef, ← Real.rpow_mul hk.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]
      have h11 := h 1 1 a 1 one_pos one_pos ha one_pos
      rw [ell_ratio_one ρ ε 1 one_pos, ell_ratio_one ρ ε a ha, hak, Real.one_rpow] at h11
      simp only [Real.sqrt_one] at h11
      have hd : ε * k + (1 - ε) ≠ 0 := by
        have : 0 < ε * k + (1 - ε) := by nlinarith
        exact ne_of_gt this
      rw [show ε * 1 + (1 - ε) = 1 by ring] at h11
      field_simp at h11
      nlinarith [h11, hs, hρ0, Real.sq_sqrt hk.le, Real.sqrt_nonneg k]
    have k4 := key 4 (by norm_num)
    have k9 := key 9 (by norm_num)
    rw [show Real.sqrt 4 = 2 by
      rw [show (4 : ℝ) = 2 ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]] at k4
    rw [show Real.sqrt 9 = 3 by
      rw [show (9 : ℝ) = 3 ^ 2 by norm_num, Real.sqrt_sq (by norm_num)]] at k9
    linarith
  · exact fun h => h.elim

/-- **L5 — scale invariance.** `ell` is positively homogeneous of degree one in the
reserves, so the normalized ratio `ell/√(xy)` is scale-free (degree zero) and can depend
on the reserve state only through the ratio `x/y`.

(The supplied guards `hε` and `hρ1` turn out not to be needed for this identity; they are
kept because they were part of the statement as supplied.) -/
theorem ell_homogeneous (ρ ε x y a : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) (ha : 0 < a) (hρ1 : ρ < 1) :
    ell ρ ε (a * x) (a * y) = a * ell ρ ε x y := by
  have harho : (0 : ℝ) < a ^ ρ := Real.rpow_pos_of_pos ha ρ
  unfold ell
  rw [show a * x * (a * y) = a ^ (2 : ℕ) * (x * y) by ring]
  rw [Real.mul_rpow (by positivity) (by positivity), Real.mul_rpow ha.le hx.le,
    Real.mul_rpow ha.le hy.le]
  rw [← Real.rpow_natCast a 2, ← Real.rpow_mul ha.le]
  rw [show ((2 : ℕ) : ℝ) * ((ρ + 1) / 2) = ρ + 1 by push_cast; ring, Real.rpow_add ha,
    Real.rpow_one]
  rw [show 2 * Real.sqrt (ε * (1 - ε)) * (a ^ ρ * a * (x * y) ^ ((ρ + 1) / 2))
      = (a * (2 * Real.sqrt (ε * (1 - ε)) * (x * y) ^ ((ρ + 1) / 2))) * a ^ ρ by ring,
    show (1 - ρ) * (ε * (a ^ ρ * x ^ ρ) + (1 - ε) * (a ^ ρ * y ^ ρ))
      = ((1 - ρ) * (ε * x ^ ρ + (1 - ε) * y ^ ρ)) * a ^ ρ by ring]
  rw [mul_div_mul_right _ _ (ne_of_gt harho), mul_div_assoc]

/-- **L6 — the linear pole.** As `ρ → 1⁻` (the linear member) intrinsic liquidity diverges:
a linear curve has no price impact, hence unbounded depth. This is why `ρ < 1` is a guard
and not a convenience — it is the same boundary as `phiCES_concave`'s `ρ ≤ 1`. -/
theorem ell_tendsto_atTop_rho_one (ε x y : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hy : 0 < y) :
    Filter.Tendsto (fun ρ => ell ρ ε x y) (nhdsWithin 1 (Iio 1)) Filter.atTop := by
  obtain ⟨hε0, hε1⟩ := hε
  have hxy : (0 : ℝ) < x * y := by positivity
  have hsq : 0 < Real.sqrt (ε * (1 - ε)) := Real.sqrt_pos.2 (by nlinarith)
  set N : ℝ → ℝ := fun ρ => 2 * Real.sqrt (ε * (1 - ε)) * (x * y) ^ ((ρ + 1) / 2) with hN
  set D : ℝ → ℝ := fun ρ => (1 - ρ) * (ε * x ^ ρ + (1 - ε) * y ^ ρ) with hD
  have hNc : Filter.Tendsto N (nhdsWithin 1 (Iio 1))
      (nhds (2 * Real.sqrt (ε * (1 - ε)) * (x * y))) := by
    have hca : ContinuousAt N 1 := by
      apply continuousAt_const.mul
      exact (Real.continuousAt_const_rpow (ne_of_gt hxy)).comp (by fun_prop)
    have h2 : Filter.Tendsto N (nhdsWithin 1 (Iio 1)) (nhds (N 1)) :=
      hca.tendsto.mono_left nhdsWithin_le_nhds
    simpa [hN, Real.rpow_one] using h2
  have hDc : Filter.Tendsto D (nhdsWithin 1 (Iio 1)) (nhdsWithin 0 (Ioi 0)) := by
    apply tendsto_nhdsWithin_of_tendsto_nhds_of_eventually_within
    · have hca : ContinuousAt D 1 := by
        apply ContinuousAt.mul (by fun_prop)
        exact ((continuousAt_const.mul (Real.continuousAt_const_rpow (ne_of_gt hx))).add
          (continuousAt_const.mul (Real.continuousAt_const_rpow (ne_of_gt hy))))
      have h2 : Filter.Tendsto D (nhdsWithin 1 (Iio 1)) (nhds (D 1)) :=
        hca.tendsto.mono_left nhdsWithin_le_nhds
      simpa [hD] using h2
    · filter_upwards [self_mem_nhdsWithin] with ρ hρ
      have hρ' : ρ < 1 := hρ
      have h1 := Real.rpow_pos_of_pos hx ρ
      have h2 := Real.rpow_pos_of_pos hy ρ
      have : 0 < ε * x ^ ρ + (1 - ε) * y ^ ρ := by nlinarith
      exact mul_pos (by linarith) this
  have hfin : Filter.Tendsto (fun ρ => N ρ * (D ρ)⁻¹) (nhdsWithin 1 (Iio 1)) Filter.atTop := by
    apply Filter.Tendsto.pos_mul_atTop (by positivity) hNc
    exact tendsto_inv_nhdsGT_zero.comp hDc
  simpa [ell, hN, hD, div_eq_mul_inv] using hfin

/-! ### L7 — the half-kernel reduction -/

/-- The constant-product ("half-kernel") pool of liquidity `L`: reserves `(x, L^2/x)`,
marginal price `L^2/x^2`. This is the member on-chain protocols instantiate
(`sqrtPriceX96` + a per-tick `L`). -/
noncomputable def pHalfKernel (L x : ℝ) : ℝ := L ^ 2 / x ^ 2

/-- **L7 — THE HALF-KERNEL REDUCTION (the implementation-facing statement).**
For the constant-product pool the price impact is exactly `-2 p^{3/2} / L`. Consequently a
general CES member and the constant-product pool carrying liquidity `L = ell` agree at a
reserve state on BOTH the marginal price and its first-order price impact: the half-kernel
is the osculating instrument at every state, and every quantity that factors through
`(p, dp/dx)` is computable in half-kernel form with `L ← ell`. -/
theorem halfKernel_price_impact (L x : ℝ) (hL : 0 < L) (hx : 0 < x) :
    deriv (pHalfKernel L) x = -2 * (pHalfKernel L x) ^ ((3 : ℝ) / 2) / L := by
  have hx2 : (x : ℝ) ^ 2 ≠ 0 := by positivity
  have hd : HasDerivAt (fun z : ℝ => L ^ 2 / z ^ 2)
      ((0 * x ^ 2 - L ^ 2 * (2 * x ^ (2 - 1))) / (x ^ 2) ^ 2) x :=
    (hasDerivAt_const x (L ^ 2)).div (hasDerivAt_pow 2 x) hx2
  have h1 : deriv (pHalfKernel L) x = (0 * x ^ 2 - L ^ 2 * (2 * x ^ (2 - 1))) / (x ^ 2) ^ 2 := by
    simpa [pHalfKernel] using hd.deriv
  rw [h1]
  have h2 : pHalfKernel L x = (L / x) ^ (2 : ℕ) := by rw [pHalfKernel, div_pow]
  rw [h2, ← Real.rpow_natCast (L / x) 2, ← Real.rpow_mul (by positivity)]
  rw [show ((2 : ℕ) : ℝ) * ((3 : ℝ) / 2) = ((3 : ℕ) : ℝ) by push_cast; ring, Real.rpow_natCast]
  field_simp
  ring

/-
**L7(b) as originally stated is FALSE** — it is L1 in disguise, and fails at the same
witness; see `halfKernel_osculates_false` and the corrected
`halfKernel_osculates_corrected`. The original statement is preserved here, commented out,
exactly as supplied:

/-- **L7(b).** The osculating statement: at a state where the two curves share the marginal
price, setting the half-kernel liquidity to `ell` makes their price impacts agree. -/
theorem halfKernel_osculates (ρ ε c x xh : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hxh : 0 < xh) (hc : 0 < c)
    (hy : 0 < yOf ρ ε c x)
    (hL : 0 < ell ρ ε x (yOf ρ ε c x))
    (hprice : pHalfKernel (ell ρ ε x (yOf ρ ε c x)) xh = pOf ρ ε c x) :
    deriv (pHalfKernel (ell ρ ε x (yOf ρ ε c x))) xh = deriv (pOf ρ ε c) x := by
  sorry
-/

/-- **L7(b) (corrected).** The osculating statement: at a state where the two curves share
the marginal price, setting the half-kernel liquidity to `ell` makes their price impacts
agree.

CHANGES relative to the statement supplied as L7(b), for exactly the reason recorded at
`ellAt_eq_ell_corrected` (this statement contains L1):
* the guard `hy : 0 < yOf ρ ε c x` is REPLACED by the radicand guard
  `hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)`, which implies it;
* the unused guard `hc : 0 < c` is DROPPED.
Everything else, including `hL` (which is what rules out a degenerate zero price impact),
is as supplied; no further hypothesis beyond agreement of `p` is needed. -/
theorem halfKernel_osculates_corrected (ρ ε c x xh : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hxh : 0 < xh)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε))
    (hL : 0 < ell ρ ε x (yOf ρ ε c x))
    (hprice : pHalfKernel (ell ρ ε x (yOf ρ ε c x)) xh = pOf ρ ε c x) :
    deriv (pHalfKernel (ell ρ ε x (yOf ρ ε c x))) xh = deriv (pOf ρ ε c) x := by
  set L : ℝ := ell ρ ε x (yOf ρ ε c x) with hLdef
  have hkey : ellAt ρ ε c x = L := ellAt_eq_ell_corrected ρ ε c x hρ hρ1 hε hx hu
  have hp32 : (0 : ℝ) < (pOf ρ ε c x) ^ ((3 : ℝ) / 2) := by
    obtain ⟨hε0, hε1⟩ := hε
    have hppos : 0 < pOf ρ ε c x := by
      rw [pOf_eq ρ ε c x hρ hε0 hx hu]
      have h1 := Real.rpow_pos_of_pos hx (ρ - 1)
      have h2 := Real.rpow_pos_of_pos hu ((1 - ρ) / ρ)
      have h3 : 0 < ε / (1 - ε) := div_pos hε0 (by linarith)
      positivity
    exact Real.rpow_pos_of_pos hppos _
  have hd0 : deriv (pOf ρ ε c) x ≠ 0 := by
    intro h0
    rw [ellAt, h0, div_zero] at hkey
    exact absurd hkey.symm (ne_of_gt hL)
  have hLeq : -2 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2) = L * deriv (pOf ρ ε c) x := by
    rw [ellAt] at hkey
    field_simp at hkey
    linarith [hkey]
  rw [halfKernel_price_impact L xh hL hxh, hprice, hLeq]
  field_simp

/-- **L7(b) is FALSE as stated**, for the same reason as L1: it contains L1. Explicit
counterexample: `(ρ, ε, c, x, xh) = (1/2, 1/2, 1/4, 4, 16/3)`. All supplied guards hold
(`yOf = 1`, `ell = 8√2/3 > 0`, and `pHalfKernel (8√2/3) (16/3) = 1/2 = pOf`), yet the
half-kernel price impact is negative while `deriv (pOf ρ ε c) x = 1/16 > 0`. -/
theorem halfKernel_osculates_false :
    ¬ (∀ ρ ε c x xh : ℝ, ρ ≠ 0 → ρ < 1 → ε ∈ Ioo (0 : ℝ) 1 → 0 < x → 0 < xh → 0 < c →
        0 < yOf ρ ε c x → 0 < ell ρ ε x (yOf ρ ε c x) →
        pHalfKernel (ell ρ ε x (yOf ρ ε c x)) xh = pOf ρ ε c x →
        deriv (pHalfKernel (ell ρ ε x (yOf ρ ε c x))) xh = deriv (pOf ρ ε c) x) := by
  intro h
  have hs2 : (0 : ℝ) < Real.sqrt 2 := Real.sqrt_pos.2 (by norm_num)
  have hs2sq : Real.sqrt 2 ^ 2 = 2 := Real.sq_sqrt (by norm_num)
  have hLpos : 0 < ell (1 / 2) (1 / 2) 4 1 := ell_cex_pos
  have hprice : pHalfKernel (ell (1 / 2) (1 / 2) 4 1) (16 / 3) = pOf (1 / 2) (1 / 2) (1 / 4) 4 := by
    rw [pOf_cex_four, ell_cex, pHalfKernel]
    rw [div_pow, mul_pow, hs2sq]
    norm_num
  have hcontra := h (1 / 2) (1 / 2) (1 / 4) 4 (16 / 3) (by norm_num) (by norm_num)
    (by constructor <;> norm_num) (by norm_num) (by norm_num) (by norm_num)
    (by rw [yOf_cex_four]; norm_num)
    (by rw [yOf_cex_four]; exact hLpos)
    (by rw [yOf_cex_four]; exact hprice)
  rw [yOf_cex_four, deriv_pOf_cex,
    halfKernel_price_impact _ _ hLpos (by norm_num), hprice, pOf_cex_four] at hcontra
  have hp32 : (0 : ℝ) < ((1 : ℝ) / 2) ^ ((3 : ℝ) / 2) := Real.rpow_pos_of_pos (by norm_num) _
  have hneg : -2 * ((1 : ℝ) / 2) ^ ((3 : ℝ) / 2) / ell (1 / 2) (1 / 2) 4 1 < 0 := by
    apply div_neg_of_neg_of_pos (by nlinarith) hLpos
  linarith

end EllIntrinsic
