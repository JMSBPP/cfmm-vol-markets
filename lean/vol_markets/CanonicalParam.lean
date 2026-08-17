import vol_markets.EllIntrinsic

/-!
# CanonicalParam — the level set as the transition channel between reserve and price coordinates

## Source and intent

Risk–Tung–Wang (arXiv:2603.01344v1) §2.2, Theorem "Canonical Parametrization": for a smooth
increasing convex bonding curve, the reserve state along a level set is determined by the
spot price `p` and the intrinsic liquidity `ℓ` via

  dx/dp = -ℓ/(2 p^{3/2}),   dy/dp = ℓ/(2 √p),

with the liquidity profile `L(q) := ℓ(q)/(2 q^{3/2})` and price impact `dp = -dx/L(p)`.
Tung–Wang (arXiv:2412.18580) §3.2.2 verify `dy/dx = -p` along the curve.

INTENT of this bundle: the governing document keeps the trading function in RESERVE
coordinates and the liquidity profile in PRICE coordinates, with the LEVEL SET as the
transition channel between the two. These targets establish that channel for our family —
the differential form only (the paper's integral form presupposes full price support with
vanishing tails, which our family does not satisfy off the Cobb–Douglas slice; nothing
below needs it).

## Scaffolding

`EllIntrinsic.lean` is supplied and ALREADY PROVED — import, do not modify or re-derive.
The level curve through level `c` is `x ↦ (x, yOf ρ ε c x)`, the price along it is
`pOf ρ ε c x`, and the intrinsic liquidity field is `ell ρ ε x y` with the closed form
established by `ellAt_eq_ell_corrected`. `pOf_eq`, `hasDerivAt_pOf`, `hasDerivAt_pOf'`
give the price's local product form and its derivative.

## Notation map (deliberately disagrees with the document — do not rename)

`ε` here = the SHARE (document `χ_{X/M}`); `ρ` here = the SUBSTITUTION exponent (document
`ε_{X/M}`); `x`/`y` = the X/M reserve legs (document `Q_X^L`, `Q_M^L` — the document's
reserve-side quantities; its bare `Q_X, Q_M` are trading-side arguments and do not appear
here). The document's price-indexed reserve pair `(Q_X^L(p_φ), Q_M^L(p_φ))` is this
file's `(x, yOf ρ ε c x)` read through `pOf`.

## Standing guard

Statements about the level curve require the state STRICTLY INSIDE it:
`0 < (c^ρ - ε*x^ρ)/(1-ε)`. The weaker `0 < yOf …` does NOT imply this (`Real.rpow` off
the positives carries a `cos(π·)` factor); a previous bundle refuted two statements on
exactly that defect. The guard is supplied where needed; do not drop it.

## Instructions

Prove the `sorry`'d statements. Priority **C1a > C1b > C2a > C2b > C3 > C4**.

If a statement is FALSE as written, refute it as stated with a named explicit
counterexample (`..._false`) and prove the corrected form under a NEW name
(`..._corrected`), documenting exactly what changed. A refutation is a successful
outcome. Do not modify any definition here or in `EllIntrinsic`.
-/

namespace CanonicalParam

open Real Set EllIntrinsic

/-! ### Basic facts along the level curve

All of these are consequences of the radicand guard `0 < (c^ρ - ε x^ρ)/(1-ε)`. -/

/-- Under the radicand guard the `y` leg is positive. -/
lemma yOf_pos (ρ ε c x : ℝ)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) : 0 < yOf ρ ε c x :=
  Real.rpow_pos_of_pos hu _

/-- Under the radicand guard the `y` leg genuinely solves the level equation:
`(yOf)^ρ` is the radicand. -/
lemma yOf_rpow (ρ ε c x : ℝ) (hρ : ρ ≠ 0)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    (yOf ρ ε c x) ^ ρ = (c ^ ρ - ε * x ^ ρ) / (1 - ε) := by
  rw [yOf, ← Real.rpow_mul hu.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]

/-- On the curve, the CES aggregate of the state is `c ^ ρ`. -/
lemma sum_eq_cpow (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    ε * x ^ ρ + (1 - ε) * (yOf ρ ε c x) ^ ρ = c ^ ρ := by
  have hε' : (0 : ℝ) < 1 - ε := by linarith [hε.2]
  rw [yOf_rpow ρ ε c x hρ hu]
  field_simp
  ring

/-- The marginal price is positive along the curve. -/
lemma pOf_pos (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) : 0 < pOf ρ ε c x := by
  have hε' : (0 : ℝ) < 1 - ε := by linarith [hε.2]
  rw [pOf_eq ρ ε c x hρ hε.1 hx hu]
  have h1 : (0 : ℝ) < x ^ (ρ - 1) := Real.rpow_pos_of_pos hx _
  have h2 : (0 : ℝ) < ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ) :=
    Real.rpow_pos_of_pos hu _
  have h3 : (0 : ℝ) < ε / (1 - ε) := div_pos hε.1 hε'
  positivity

/-- `c ^ ρ` is positive along the curve (`c` itself need not be assumed positive). -/
lemma cpow_pos (ρ ε c x : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) : 0 < c ^ ρ := by
  have hε' : (0 : ℝ) < 1 - ε := by linarith [hε.2]
  have hxr : (0 : ℝ) < x ^ ρ := Real.rpow_pos_of_pos hx _
  have key : (1 - ε) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) = c ^ ρ - ε * x ^ ρ := by
    field_simp
  nlinarith [mul_pos hε' hu, mul_pos hε.1 hxr]

/-- The price impact is strictly negative: the price falls as the `x` leg grows. -/
lemma deriv_pOf_neg (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (pOf ρ ε c) x < 0 := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  rw [(hasDerivAt_pOf' ρ ε c x hρ hε0 hε1 hx hu).deriv]
  have h1 : (0 : ℝ) < x ^ (ρ - 2) := Real.rpow_pos_of_pos hx _
  have h2 : (0 : ℝ) < ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ) :=
    Real.rpow_pos_of_pos hu _
  have h3 : (0 : ℝ) < ε / (1 - ε) := div_pos hε0 hε'
  have h4 : (0 : ℝ) < c ^ ρ := cpow_pos ρ ε c x ⟨hε0, hε1⟩ hx hu
  have h5 : (0 : ℝ) < (1 - ε) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) := mul_pos hε' hu
  have hnum : ε / (1 - ε) * (ρ - 1) * x ^ (ρ - 2) *
      ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ) * c ^ ρ < 0 := by
    have hlt : (ρ - 1) < 0 := by linarith
    nlinarith [mul_pos (mul_pos h3 h1) (mul_pos h2 h4)]
  exact div_neg_of_neg_of_pos hnum h5

/-- The derivative of the `y` leg along the curve: the tangent slope is `-p`. -/
lemma hasDerivAt_yOf (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    HasDerivAt (yOf ρ ε c) (-(pOf ρ ε c x)) x := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hU : HasDerivAt (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε))
      ((0 - ε * (ρ * x ^ (ρ - 1))) / (1 - ε)) x :=
    ((hasDerivAt_const x (c ^ ρ)).sub
      ((Real.hasDerivAt_rpow_const (x := x) (p := ρ) (Or.inl hx.ne')).const_mul ε)).div_const _
  have h := hU.rpow_const (p := 1 / ρ) (Or.inl hu.ne')
  have hfun : (yOf ρ ε c) = fun z : ℝ => ((c ^ ρ - ε * z ^ ρ) / (1 - ε)) ^ (1 / ρ) := rfl
  rw [hfun]
  convert h using 1
  rw [pOf_eq ρ ε c x hρ hε0 hx hu,
    show (1 : ℝ) / ρ - 1 = (1 - ρ) / ρ by field_simp]
  field_simp
  ring

/-- **C1a — the x-half of the canonical parametrization (differential form).**
`dx/dp = -ℓ/(2 p^{3/2})`, stated reciprocally: the price has nonzero impact and
`1/(dp/dx) = -ℓ/(2 p^{3/2})`. (This is also the Γ identity: `dx/dp = Γ`.) -/
theorem canonical_x (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (pOf ρ ε c) x ≠ 0 ∧
      1 / deriv (pOf ρ ε c) x
        = -(ell ρ ε x (yOf ρ ε c x)) / (2 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2)) := by
  have hD : deriv (pOf ρ ε c) x < 0 := deriv_pOf_neg ρ ε c x hρ hρ1 hε hx hu
  refine ⟨hD.ne, ?_⟩
  have hP : 0 < (pOf ρ ε c x) ^ ((3 : ℝ) / 2) :=
    Real.rpow_pos_of_pos (pOf_pos ρ ε c x hρ hε hx hu) _
  have hkey : -2 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2) / deriv (pOf ρ ε c) x
      = ell ρ ε x (yOf ρ ε c x) := ellAt_eq_ell_corrected ρ ε c x hρ hρ1 hε hx hu
  field_simp at hkey ⊢
  linarith [hkey]

/-- **C1b — the y-half of the canonical parametrization (differential form).**
`dy/dp = ℓ/(2 √p)`, via the chain rule along the curve. -/
theorem canonical_y (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (yOf ρ ε c) x / deriv (pOf ρ ε c) x
      = ell ρ ε x (yOf ρ ε c x) / (2 * Real.sqrt (pOf ρ ε c x)) := by
  obtain ⟨hD, hrec⟩ := canonical_x ρ ε c x hρ hρ1 hε hx hu
  have hp : 0 < pOf ρ ε c x := pOf_pos ρ ε c x hρ hε hx hu
  have hsq : 0 < Real.sqrt (pOf ρ ε c x) := Real.sqrt_pos.2 hp
  have h32 : (pOf ρ ε c x) ^ ((3 : ℝ) / 2)
      = pOf ρ ε c x * Real.sqrt (pOf ρ ε c x) := by
    rw [Real.sqrt_eq_rpow, ← Real.rpow_one_add' hp.le (by norm_num)]
    norm_num
  rw [(hasDerivAt_yOf ρ ε c x hρ hε hx hu).deriv, div_eq_mul_one_div, hrec, h32]
  field_simp

/-- **C2a — the tangent-slope identity (cohesion, first half).** Along the level curve the
marginal price is the negative tangent slope: `dy/dx = -p`. This connects `pOf` (defined
as the quotient-of-partials formula) with the curve's actual geometry — Tung–Wang's
verification step.

(The supplied hypothesis `hρ1 : ρ < 1` is kept as given, although the proof does not need
it: the tangent slope identity holds for every `ρ ≠ 0` under the radicand guard.) -/
theorem tangent_slope (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (yOf ρ ε c) x = -(pOf ρ ε c x) :=
  (hasDerivAt_yOf ρ ε c x hρ hε hx hu).deriv

/-- **C2b — the on-curve identity (cohesion, second half).** The parametrized state
actually lies on the level set: `φ(x, yOf x) = c`. Together with C2a this is the round
trip — the pair (price, profile) and the level set are the same data.

(The supplied hypotheses `hρ1 : ρ < 1` and `hx : 0 < x` are kept as given, although the
proof does not need them.) -/
theorem on_curve (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hc : 0 < c)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    phiCES ρ ε x (yOf ρ ε c x) = c := by
  rw [phiCES, sum_eq_cpow ρ ε c x hρ hε hu, ← Real.rpow_mul hc.le,
    mul_one_div, div_self hρ, Real.rpow_one]

/-- The liquidity profile in price coordinates: `L(p) = ℓ/(2 p^{3/2})`, evaluated along
the curve. -/
noncomputable def Lprofile (ρ ε c x : ℝ) : ℝ :=
  ell ρ ε x (yOf ρ ε c x) / (2 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2))

/-- **C3 — profile = −Γ, and the price-impact law.** The price-coordinate profile is minus
the reciprocal price impact (`L(p) = -dx/dp = -Γ`), equivalently `dp/dx = -1/L(p)` —
the source's `dp = -dx/L(p)`. -/
theorem profile_eq_neg_gamma (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    Lprofile ρ ε c x = -(1 / deriv (pOf ρ ε c) x) ∧
      deriv (pOf ρ ε c) x = -(1 / Lprofile ρ ε c x) := by
  obtain ⟨hD, hrec⟩ := canonical_x ρ ε c x hρ hρ1 hε hx hu
  have hL : Lprofile ρ ε c x = -(1 / deriv (pOf ρ ε c) x) := by
    rw [Lprofile, hrec]; ring
  refine ⟨hL, ?_⟩
  rw [hL]
  field_simp

/-- The intrinsic-liquidity field written as a function of (level, price) ALONE:
with `r(p) = ((1-ε) p / ε)^{1/(ρ-1)}` the reserve ratio at price `p`,

  `ellP ρ ε c p = 2 √(ε(1-ε)) · (r(p) · c² / (ε r(p)^ρ + 1-ε)^{2/ρ})^{(ρ+1)/2} / ((1-ρ) c^ρ)`.

(Derived by inverting the price for the reserve ratio and using that ON the curve the
closed form's denominator sum collapses to the level: `ε x^ρ + (1-ε) y^ρ = c^ρ`.
Checked numerically at `(ρ,ε,c,x) = (1/2, 1/2, 2, 1)`: both sides `≈ 3.48682`.) -/
noncomputable def ellP (ρ ε c p : ℝ) : ℝ :=
  2 * Real.sqrt (ε * (1 - ε)) *
      (((1 - ε) * p / ε) ^ (1 / (ρ - 1)) * c ^ 2 /
          (ε * (((1 - ε) * p / ε) ^ (1 / (ρ - 1))) ^ ρ + (1 - ε)) ^ (2 / ρ)) ^
        ((ρ + 1) / 2) /
    ((1 - ρ) * c ^ ρ)

/-- **C4 — the pushforward: the field factors through the price.** Along the level curve
the intrinsic liquidity is a function of the LEVEL and the PRICE alone — the
coordinate-change statement itself: reserve-coordinate field = price-coordinate profile
through the channel.

The hand-derived exponent bookkeeping in `ellP` is CORRECT: no refutation is needed. The
proof inverts the price for the reserve ratio `r = x / yOf = ((1-ε) p / ε)^{1/(ρ-1)}`,
uses `ε r^ρ + (1-ε) = c^ρ / (yOf)^ρ` (the on-curve collapse of the CES aggregate), whence
`r c² / (ε r^ρ + 1-ε)^{2/ρ} = x · yOf`, and finally `ell`'s denominator sum equals `c^ρ`. -/
theorem field_factors_through_price (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x) (hc : 0 < c)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    ell ρ ε x (yOf ρ ε c x) = ellP ρ ε c (pOf ρ ε c x) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hρ' : ρ - 1 ≠ 0 := sub_ne_zero_of_ne (ne_of_lt hρ1)
  have hsum : ε * x ^ ρ + (1 - ε) * (yOf ρ ε c x) ^ ρ = c ^ ρ :=
    sum_eq_cpow ρ ε c x hρ ⟨hε0, hε1⟩ hu
  have hy : 0 < yOf ρ ε c x := yOf_pos ρ ε c x hu
  set y := yOf ρ ε c x with hydef
  have hyr : (0 : ℝ) < y ^ ρ := Real.rpow_pos_of_pos hy _
  have hxy : (0 : ℝ) < x / y := div_pos hx hy
  -- invert the price for the reserve ratio
  have hA : (1 - ε) * pOf ρ ε c x / ε = (x / y) ^ (ρ - 1) := by
    rw [pOf, ← hydef]; field_simp
  have hB : ((1 - ε) * pOf ρ ε c x / ε) ^ (1 / (ρ - 1)) = x / y := by
    rw [hA, ← Real.rpow_mul hxy.le, mul_one_div, div_self hρ', Real.rpow_one]
  -- on the curve the aggregate collapses to the level
  have hC : ε * (x / y) ^ ρ + (1 - ε) = c ^ ρ / y ^ ρ := by
    rw [Real.div_rpow hx.le hy.le]
    field_simp
    linarith [hsum]
  have hD : (c ^ ρ / y ^ ρ) ^ (2 / ρ) = (c / y) ^ 2 := by
    rw [← Real.div_rpow hc.le hy.le, ← Real.rpow_mul (div_pos hc hy).le,
      show ρ * (2 / ρ) = ((2 : ℕ) : ℝ) by push_cast; field_simp, Real.rpow_natCast]
  have hE : x / y * c ^ 2 / (c / y) ^ 2 = x * y := by
    field_simp
  rw [ellP, hB, hC, hD, hE, ell, hsum]

end CanonicalParam
