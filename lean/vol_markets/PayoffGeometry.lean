import vol_markets.EllIntrinsic

/-!
# PayoffGeometry — the envelope, the Γ identity, the curvature closed form, the ladder question

Promotes four PENDING propositions of the governing document from asserted to proved (or
refuted). Everything is stated on the SAME level-curve scaffolding already proved in
`EllIntrinsic` (imported, not copied): `phiCES`, `yOf`, `pOf`, `ell`, and the supporting
`pOf_eq` / `hasDerivAt_pOf` / `hasDerivAt_pOf'`.

## Notation map (the glyphs deliberately disagree with the document — do not rename)

`phiCES ρ ε x y = (ε * x^ρ + (1-ε) * y^ρ)^(1/ρ)`, where **`ε` is the SHARE coefficient** and
**`ρ` is the SUBSTITUTION exponent**. The document writes the share `χ_{X/M}` and the
substitution parameter `ε_{X/M}`, so: document `χ_{X/M}` ↔ this file's `ε`, and document
`ε_{X/M}` ↔ this file's `ρ`. The Lean names are fixed by the existing bundle and are never
renamed to follow document glyphs. `x` is the X (asset) leg, `y` the M (money) leg.

Standing guard, established by `EllIntrinsic`: statements about the level curve need the
state to lie STRICTLY INSIDE it, i.e. `0 < (c^ρ - ε*x^ρ)/(1-ε)`. The weaker `0 < yOf …`
does NOT imply this — `Real.rpow` off the positives carries a `cos(π·)` factor, and the
previous bundle refuted two statements on exactly that defect. Carry the radicand guard.

## What each target corresponds to

* **P1/P2** — document Proposition 13 ("Gamma is the intrinsic liquidity"), whose envelope
  step the document currently marks UNFORMALIZED. P1 is the envelope, P2 the Γ identity.
* **P3/P4** — document Proposition 7 (CES curvature closed form) against document
  Definition 14's normalization `κ_φ ≡ |ε_{p/X}| / (|ε_{p/X}| + |ε⁰_{p/X}|)`, where `ε⁰` is
  the same elasticity for the substitution-0 member at the same point.
* **P5** — document Proposition 12 (profile–field relation): can a GEOMETRIC ladder realize
  the intrinsic-liquidity field? A geometric ladder is a pure power of the reserve ratio.

## Instructions

Prove the `sorry`'d statements. Priority **P1 > P2 > P5 > P3 > P4**.

If a statement is FALSE as written, do NOT weaken it silently: refute it as stated with a
named explicit counterexample (`..._false`) and prove the corrected form under a NEW name
(`..._corrected`), documenting exactly what changed. **A refutation is a successful
outcome** — the previous two bundles in this project returned decisive refutations that
were integrated as results. Do not modify any imported definition.
-/

namespace PayoffGeometry

open Real Set EllIntrinsic

/-- The portfolio value along the level curve: the reserves valued at the marginal price,
`π = p·Q_X + Q_M`. This is the document's Definition 25 restricted to the curve. -/
noncomputable def piVal (ρ ε c x : ℝ) : ℝ :=
  pOf ρ ε c x * x + yOf ρ ε c x

/-- The `y` leg falls at exactly the marginal price: `dy/dx = -p` along the level curve.
This is the geometric content of the envelope step P1. -/
lemma hasDerivAt_yOf (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε0 : 0 < ε) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    HasDerivAt (yOf ρ ε c) (-(pOf ρ ε c x)) x := by
  have hU : HasDerivAt (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε))
      ((0 - ε * (ρ * x ^ (ρ - 1))) / (1 - ε)) x :=
    ((hasDerivAt_const x (c ^ ρ)).sub
      ((Real.hasDerivAt_rpow_const (x := x) (p := ρ) (Or.inl hx.ne')).const_mul ε)).div_const _
  have hg : HasDerivAt (fun z : ℝ => ((c ^ ρ - ε * z ^ ρ) / (1 - ε)) ^ (1 / ρ))
      (((0 - ε * (ρ * x ^ (ρ - 1))) / (1 - ε)) * (1 / ρ)
        * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ (1 / ρ - 1)) x := hU.rpow_const (Or.inl hu.ne')
  have hfun : (fun z : ℝ => ((c ^ ρ - ε * z ^ ρ) / (1 - ε)) ^ (1 / ρ)) = yOf ρ ε c := rfl
  rw [hfun] at hg
  convert hg using 1
  rw [pOf_eq ρ ε c x hρ hε0 hx hu, show 1 / ρ - 1 = (1 - ρ) / ρ by field_simp]
  set V : ℝ := ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ)
  field_simp
  ring

/-- **P1 — THE TARGET (the envelope relation).** Along the level curve the value function's
`x`-derivative is `Q_X` times the price's `x`-derivative. Dividing by `dp/dx` this is the
document's `𝒟_p[π] = Q_X`, the step Proposition 13 currently takes UNFORMALIZED.

Proved exactly as supplied. (The supplied guard `hρ1 : ρ < 1` turns out not to be needed
for the envelope step — it is the price-impact SIGN that needs it, not the identity — but
it is kept because it was part of the statement as supplied.) -/
theorem deriv_piVal (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (piVal ρ ε c) x = x * deriv (pOf ρ ε c) x := by
  obtain ⟨hε0, hε1⟩ := hε
  have hp := hasDerivAt_pOf' ρ ε c x hρ hε0 hε1 hx hu
  have hy := hasDerivAt_yOf ρ ε c x hρ hε0 hx hu
  have hpi : HasDerivAt (piVal ρ ε c)
      (((ε / (1 - ε)) * (ρ - 1) * x ^ (ρ - 2) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ)
          * c ^ ρ / ((1 - ε) * ((c ^ ρ - ε * x ^ ρ) / (1 - ε)))) * x + pOf ρ ε c x * 1
        + -(pOf ρ ε c x)) x :=
    (hp.mul (hasDerivAt_id x)).add hy
  rw [hpi.deriv, hp.deriv]
  ring

/-- **P2 — the Γ identity.** `Γ = 𝒟_p[Q_X] = 1/(dp/dx)` equals `-½ · ell · p^{-3/2}`.
Together with P1 this is document Proposition 13 in full: Γ IS the intrinsic liquidity,
carried by the coefficient `ell`, with NO free proportionality constant. -/
theorem gamma_eq_ell (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    1 / deriv (pOf ρ ε c) x
      = -(1/2) * ell ρ ε x (yOf ρ ε c x) * (pOf ρ ε c x) ^ (-(3 : ℝ) / 2) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hppos : 0 < pOf ρ ε c x := by
    rw [pOf_eq ρ ε c x hρ hε0 hx hu]
    have h1 : 0 < ε / (1 - ε) := div_pos hε0 hε'
    have h2 : 0 < x ^ (ρ - 1) := Real.rpow_pos_of_pos hx _
    have h3 : 0 < ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ ((1 - ρ) / ρ) := Real.rpow_pos_of_pos hu _
    positivity
  have hell := ellAt_eq_ell_corrected ρ ε c x hρ hρ1 ⟨hε0, hε1⟩ hx hu
  rw [← hell, ellAt]
  have hA : (0 : ℝ) < pOf ρ ε c x ^ ((3 : ℝ) / 2) := Real.rpow_pos_of_pos hppos _
  have hneg : pOf ρ ε c x ^ (-(3 : ℝ) / 2) = (pOf ρ ε c x ^ ((3 : ℝ) / 2))⁻¹ := by
    rw [show -(3 : ℝ) / 2 = -((3 : ℝ) / 2) by ring, Real.rpow_neg hppos.le]
  rw [hneg]
  field_simp

/-- The price-impact elasticity of the document's Definition 14:
`ε_{p/X} ≡ d ln p / d ln Q_X` along the curve. -/
noncomputable def epsPX (ρ ε c x : ℝ) : ℝ :=
  x * deriv (pOf ρ ε c) x / pOf ρ ε c x

/-- **P3 — the elasticity at balanced reserves.** At the state where the two legs are
equal, `|ε_{p/X}| = (1-ρ)/(1-ε)` — the document's Proposition 7 first display (its
`(1-ε_{X/M})/(1-χ_{X/M})`, under the notation map above). -/
theorem epsPX_balanced (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε))
    (hbal : yOf ρ ε c x = x) :
    |epsPX ρ ε c x| = (1 - ρ) / (1 - ε) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hxr : (0 : ℝ) < x ^ ρ := Real.rpow_pos_of_pos hx _
  -- the radicand equals `x ^ ρ` at a balanced state
  have hyU : (yOf ρ ε c x) ^ ρ = (c ^ ρ - ε * x ^ ρ) / (1 - ε) := by
    rw [show yOf ρ ε c x = ((c ^ ρ - ε * x ^ ρ) / (1 - ε)) ^ (1 / ρ) from rfl,
      ← Real.rpow_mul hu.le, one_div, inv_mul_cancel₀ hρ, Real.rpow_one]
  have hU : (c ^ ρ - ε * x ^ ρ) / (1 - ε) = x ^ ρ := by rw [← hyU, hbal]
  have hc : c ^ ρ = x ^ ρ := by
    have := hU
    field_simp at this
    linarith [this]
  have hpe := pOf_eq ρ ε c x hρ hε0 hx hu
  have hde := (hasDerivAt_pOf' ρ ε c x hρ hε0 hε1 hx hu).deriv
  have hxm : x ^ (ρ - 2) * x = x ^ (ρ - 1) := by
    rw [show x ^ (ρ - 1) = x ^ (ρ - 2 + 1) by ring_nf, Real.rpow_add hx, Real.rpow_one]
  have hval : epsPX ρ ε c x = (ρ - 1) / (1 - ε) := by
    rw [epsPX, hde, hpe, hU, hc]
    have h1 : (0 : ℝ) < x ^ (ρ - 1) := Real.rpow_pos_of_pos hx _
    have h2 : (0 : ℝ) < (x ^ ρ) ^ ((1 - ρ) / ρ) := Real.rpow_pos_of_pos hxr _
    rw [show ε / (1 - ε) * (ρ - 1) * x ^ (ρ - 2) * (x ^ ρ) ^ ((1 - ρ) / ρ) * x ^ ρ /
          ((1 - ε) * x ^ ρ)
        = ε / (1 - ε) * (ρ - 1) * x ^ (ρ - 2) * (x ^ ρ) ^ ((1 - ρ) / ρ) / (1 - ε) by
      field_simp]
    rw [show x * (ε / (1 - ε) * (ρ - 1) * x ^ (ρ - 2) * (x ^ ρ) ^ ((1 - ρ) / ρ) / (1 - ε))
        = (ρ - 1) / (1 - ε) * (ε / (1 - ε) * ((x ^ (ρ - 2) * x) * (x ^ ρ) ^ ((1 - ρ) / ρ)))
      by ring, hxm]
    have hne : ε / (1 - ε) * (x ^ (ρ - 1) * (x ^ ρ) ^ ((1 - ρ) / ρ)) ≠ 0 := by positivity
    field_simp
  rw [hval, abs_div, abs_of_pos hε', abs_of_neg (by linarith : ρ - 1 < 0)]
  ring

/-- The guards of P3 are simultaneously satisfiable, so `epsPX_balanced` is not vacuous:
at `(ρ, ε, c, x) = (1/2, 1/2, 1, 1)` the radicand is positive and the state is balanced. -/
lemma balanced_state_exists :
    (0 : ℝ) < ((1 : ℝ) ^ ((1 : ℝ) / 2) - (1 / 2) * (1 : ℝ) ^ ((1 : ℝ) / 2)) / (1 - 1 / 2)
      ∧ yOf (1 / 2) (1 / 2) 1 1 = 1 := by
  refine ⟨by norm_num, ?_⟩
  rw [yOf]
  norm_num

/-- Definition 14's curvature: the elasticity normalized against the substitution-0
(constant-product) member at the same point. At balanced reserves that benchmark
elasticity is `1/(1-ε)`, so the normalization is by `(1-ρ)/(1-ε)` over the sum. -/
noncomputable def kappaPhi (ρ ε : ℝ) : ℝ :=
  ((1 - ρ) / (1 - ε)) / ((1 - ρ) / (1 - ε) + 1 / (1 - ε))

/-- **P4 — the CES curvature closed form (document Proposition 7).** The share cancels
against the benchmark and the curvature is a function of the SUBSTITUTION parameter alone:
`κ_φ = (1-ρ)/(2-ρ)`, with the constant-product member at `κ_φ = 1/2`. -/
theorem kappaPhi_closed_form (ρ ε : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1) (hρ1 : ρ < 1) :
    kappaPhi ρ ε = (1 - ρ) / (2 - ρ) ∧ kappaPhi 0 ε = 1 / 2 := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hρ' : (0 : ℝ) < 2 - ρ := by linarith
  constructor
  · have h1e : (1 - ε) ≠ 0 := ne_of_gt hε'
    have h2r : (2 - ρ) ≠ 0 := ne_of_gt hρ'
    have hsum : (1 - ρ) / (1 - ε) + 1 / (1 - ε) = (2 - ρ) / (1 - ε) := by ring
    rw [kappaPhi, hsum, div_div_div_cancel_right₀]
    exact h1e
  · rw [kappaPhi]
    field_simp
    norm_num

/-- The normalized intrinsic-liquidity field as a function of the reserve RATIO `t = x/y`.
`EllIntrinsic.ell_homogeneous` makes this well posed (the normalized field is degree-0, so
it depends on the state only through `t`). -/
noncomputable def fieldRatio (ρ ε t : ℝ) : ℝ :=
  2 * Real.sqrt (ε * (1 - ε)) * t ^ (ρ / 2) / ((1 - ρ) * (ε * t ^ ρ + (1 - ε)))

/-- **P5 — document Proposition 12 (profile–field relation), the ladder question.**
A GEOMETRIC ladder assigns liquidity as a pure power of the reserve ratio. So a geometric
ladder can realize the intrinsic-liquidity field exactly when `fieldRatio` is a pure power
of `t`. Claim: for a genuine interior share this happens **iff the substitution parameter
vanishes** — i.e. only on the Cobb–Douglas slice.

Where it fails, no `(ξ,ι)` reproduces the field and a richer density is required; that is
the document's G4 ladder deficit. Expected shape of the forward direction: a sum of two
distinct powers `ε t^ρ + (1-ε)` is itself a pure power only if `ρ = 0`. -/
theorem fieldRatio_isPower_iff (ρ ε : ℝ) (hε : ε ∈ Ioo (0 : ℝ) 1) (hρ1 : ρ < 1) :
    (∃ A B : ℝ, ∀ t : ℝ, 0 < t → fieldRatio ρ ε t = A * t ^ B) ↔ ρ = 0 := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hρ' : (0 : ℝ) < 1 - ρ := by linarith
  have hs : 0 < Real.sqrt (ε * (1 - ε)) := Real.sqrt_pos.2 (by positivity)
  constructor
  · rintro ⟨A, B, h⟩
    have h1ρ : (1 - ρ) ≠ 0 := ne_of_gt hρ'
    -- normalize at `t = 1`: the prefactor `A` is forced
    have h1 := h 1 one_pos
    rw [fieldRatio] at h1
    simp only [Real.one_rpow, mul_one] at h1
    rw [show ε + (1 - ε) = 1 by ring, mul_one] at h1
    have hA : A = 2 * Real.sqrt (ε * (1 - ε)) / (1 - ρ) := h1.symm
    have hAne : 2 * Real.sqrt (ε * (1 - ε)) / (1 - ρ) ≠ 0 := by positivity
    -- comparing the value at `t` with the value at `t * t` forces `ε t^ρ + (1-ε)` to be
    -- multiplicative, hence `t ^ ρ = 1`
    have key : ∀ t : ℝ, 0 < t →
        ε * (t ^ ρ * t ^ ρ) + (1 - ε) = (ε * t ^ ρ + (1 - ε)) * (ε * t ^ ρ + (1 - ε)) := by
      intro t ht
      have ht2 : (0 : ℝ) < t * t := by positivity
      have ha : (0 : ℝ) < t ^ ρ := Real.rpow_pos_of_pos ht ρ
      have hq : (0 : ℝ) < t ^ (ρ / 2) := Real.rpow_pos_of_pos ht _
      have hden : (0 : ℝ) < ε * t ^ ρ + (1 - ε) := by positivity
      have hden2 : (0 : ℝ) < ε * (t ^ ρ * t ^ ρ) + (1 - ε) := by positivity
      have hmul : (t * t) ^ ρ = t ^ ρ * t ^ ρ := Real.mul_rpow ht.le ht.le
      have hmul2 : (t * t) ^ (ρ / 2) = t ^ (ρ / 2) * t ^ (ρ / 2) := Real.mul_rpow ht.le ht.le
      have hB : (t * t) ^ B = t ^ B * t ^ B := Real.mul_rpow ht.le ht.le
      have ht' := h t ht
      have ht2' := h (t * t) ht2
      rw [fieldRatio] at ht'
      rw [fieldRatio, hmul, hmul2, hB] at ht2'
      rw [hA] at ht' ht2'
      -- solve for `t ^ B`
      have hBv : t ^ B = t ^ (ρ / 2) / (ε * t ^ ρ + (1 - ε)) := by
        refine (mul_left_cancel₀ hAne ?_).symm
        rw [← ht']
        field_simp
      rw [hBv] at ht2'
      have e1 : 2 * Real.sqrt (ε * (1 - ε)) * (t ^ (ρ / 2) * t ^ (ρ / 2)) /
            ((1 - ρ) * (ε * (t ^ ρ * t ^ ρ) + (1 - ε)))
          = (2 * Real.sqrt (ε * (1 - ε)) / (1 - ρ)) *
            ((t ^ (ρ / 2) * t ^ (ρ / 2)) / (ε * (t ^ ρ * t ^ ρ) + (1 - ε))) := by
        field_simp
      have e2 : (2 * Real.sqrt (ε * (1 - ε)) / (1 - ρ)) *
            (t ^ (ρ / 2) / (ε * t ^ ρ + (1 - ε)) * (t ^ (ρ / 2) / (ε * t ^ ρ + (1 - ε))))
          = (2 * Real.sqrt (ε * (1 - ε)) / (1 - ρ)) *
            ((t ^ (ρ / 2) * t ^ (ρ / 2)) /
              ((ε * t ^ ρ + (1 - ε)) * (ε * t ^ ρ + (1 - ε)))) := by
        field_simp
      rw [e1, e2] at ht2'
      have hcancel := mul_left_cancel₀ hAne ht2'
      have hqq : t ^ (ρ / 2) * t ^ (ρ / 2) ≠ 0 := by positivity
      rw [div_eq_div_iff (ne_of_gt hden2) (by positivity)] at hcancel
      exact (mul_left_cancel₀ hqq hcancel).symm
    have h2 := key 2 (by norm_num)
    have ha : (0 : ℝ) < (2 : ℝ) ^ ρ := Real.rpow_pos_of_pos (by norm_num) ρ
    have hzero : ε * (1 - ε) * ((2 : ℝ) ^ ρ - 1) ^ 2 = 0 := by linear_combination h2
    have hsq : ((2 : ℝ) ^ ρ - 1) ^ 2 = 0 :=
      (mul_eq_zero.1 hzero).resolve_left (by positivity)
    have hone : (2 : ℝ) ^ ρ = 1 := by
      have := pow_eq_zero_iff (n := 2) (by norm_num) |>.1 hsq
      linarith
    have hlog := congrArg Real.log hone
    rw [Real.log_rpow (by norm_num), Real.log_one] at hlog
    exact (mul_eq_zero.1 hlog).resolve_right (ne_of_gt (Real.log_pos (by norm_num)))
  · rintro rfl
    refine ⟨2 * Real.sqrt (ε * (1 - ε)), 0, ?_⟩
    intro t ht
    rw [fieldRatio]
    norm_num

end PayoffGeometry
