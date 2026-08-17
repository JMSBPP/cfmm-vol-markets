import vol_markets.EllIntrinsic
import vol_markets.MarketMaking

/-!
# ReparamSigma — is any reparameterization of φ^σ a CES member? (expected: NO)

## Intent (user question, 2026-08-11)

`phiSigma_not_CES` excluded positive MULTIPLES. The present question is stronger: is
there a REPARAMETERIZATION — a strictly monotone relabeling `F ∘ φ^σ` of the level
sets — matching some member `φ_{(χ,ε)}`? Trading functions act only through their level
curves, and the intrinsic-liquidity profile in PRICE coordinates is a
reparameterization INVARIANT of the curve. The discriminant:

* φ^σ's profile is `ℓ(p) = 4·p^{3/2}` on EVERY level curve (constant price impact);
* a CES member's profile is constant in `p` on the `ρ = 0` slice and NOT a pure power
  off it — never `∝ p^{3/2}`.

Hence the expected verdict: NO reparameterization matches, and φ^σ's true family is the
constant-impact / `p^{3/2}`-profile class — the parabolas.

## Scaffolding

`EllIntrinsic` and `MarketMaking` are supplied, ALREADY PROVED — import, do not modify.
Lean `ε` = the document's share `χ_{X/M}`, `ρ` = its substitution `ε_{X/M}` (standing
split). `phiSigma L x y = y - (L - x/2)^2` with marginal price `pSigma L x = L - x/2`.
The CES field along a level curve is `ell ρ ε x (yOf ρ ε c x)`; its price form was
proved to factor through `(c, p)` elsewhere — here only pointwise evaluations are
needed. The radicand guard `0 < (c^ρ - ε·x^ρ)/(1-ε)` is load-bearing where used.

## Instructions

Prove the `sorry`'d statements. Priority **R3 > R2 > R1 > R4**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation here IS an affirmative answer to the
user's question and would be a major finding — do not force a proof past it.

## Outcome of this pass

All four statements are TRUE as written and are proved below; no refutation was needed
(so there is no `_false` / `_corrected` pair in this file). In particular **R3 holds**:
no CES member carries φ^σ's `4·p^{3/2}` profile, so the answer to the user's question is
**NO** — no strictly monotone relabeling of `φ^σ` is a CES member.

The proof of R3 is a two-state evaluation. Along the level curve `c` of a guarded member
the field and the price satisfy (with `y = yOf ρ ε c x`, so `ε x^ρ + (1-ε) y^ρ = c^ρ`)

  `ell = 2√(ε(1-ε)) (x y)^{(ρ+1)/2} / ((1-ρ) c^ρ)`,  `p = (ε/(1-ε)) (x/y)^{ρ-1}`,

so `ell = 4 p^{3/2}` is equivalent to the *single* algebraic constraint
`x^{2-ρ} y^{2ρ-1} = K(ρ,ε,c)` — a constant along the curve (`profile_reduce`). Sweeping
the curve by the share parameter `θ ∈ (0,1)` via `x_θ = c (θ/ε)^{1/ρ}` (so that
`ε x_θ^ρ = θ c^ρ` and `y_θ = c ((1-θ)/(1-ε))^{1/ρ}`) turns the constraint into
`θ^{(2-ρ)/ρ} (1-θ)^{(2ρ-1)/ρ} = const` (`ReparamSigma.profile_log_const`). Evaluating at
the two states `θ = 1/4` and `θ = 3/4` and subtracting kills every parameter-only term
and leaves `((3 - 3ρ)/ρ) · (log(1/4) - log(3/4)) = 0`, i.e. `ρ = 1` — excluded by the
guard `ρ < 1`. The guards `ρ ≠ 0`, `ε ∈ Ioo 0 1`, `0 < c` and the radicand guard are all
used; `0 < c` enters through the two evaluation states and through `c^ρ > 0`.
-/

namespace ReparamSigma

open Real Set EllIntrinsic MarketMaking

/-- **R1 — reparameterization acts trivially on level sets.** For strictly monotone `F`,
the `F ∘ φ` level set through a point is the `φ` level set through it: relabeling
changes the level VALUE, never the CURVE. (Stated for `φ^σ`; the argument is generic.) -/
theorem reparam_level_sets (F : ℝ → ℝ) (hF : StrictMono F) (L c : ℝ) :
    {q : ℝ × ℝ | F (phiSigma L q.1 q.2) = F c}
      = {q : ℝ × ℝ | phiSigma L q.1 q.2 = c} := by
  ext q
  exact hF.injective.eq_iff

/-- **R2 — φ^σ's invariant profile, curve-independent.** Along EVERY level curve
`y(x) = c + (L - x/2)²`, the intrinsic-liquidity form evaluates to `4·p^{3/2}` at the
price `p = pSigma L x` — independent of BOTH `L` and `c`: one profile for the whole
family, the signature of constant price impact.

(The supplied guard `hp : 0 < pSigma L x` is kept, as it is part of the requested
statement, but the identity is pure arithmetic in the constant impact `-1/2` and holds
without it.) -/
theorem phiSigma_profile (L c x : ℝ) (hp : 0 < pSigma L x) :
    -2 * (pSigma L x) ^ ((3 : ℝ) / 2) / (-(1 / 2))
      = 4 * (pSigma L x) ^ ((3 : ℝ) / 2) := by
  ring

/-! ### The reduction behind R3

Two auxiliary steps, both stated for a guarded CES member. They are proof scaffolding for
`no_CES_matches_phiSigma_profile`. -/

/-- Along a level curve of a guarded member — i.e. at a reserve state `(X, Y)` with
`ε X^ρ + (1-ε) Y^ρ = S` — the matching condition `ell = 4 p^{3/2}` is EQUIVALENT to the
single monomial constraint `X^{2-ρ} Y^{2ρ-1} = K`, with `K` depending only on the
parameters and the level. -/
private theorem profile_reduce (ρ ε X Y S : ℝ) (hρ1 : ρ < 1) (hε0 : 0 < ε) (hε1 : ε < 1)
    (hX : 0 < X) (hY : 0 < Y) (hS : 0 < S)
    (hsum : ε * X ^ ρ + (1 - ε) * Y ^ ρ = S)
    (H : ell ρ ε X Y = 4 * ((ε / (1 - ε)) * (X / Y) ^ (ρ - 1)) ^ ((3 : ℝ) / 2)) :
    X ^ (2 - ρ) * Y ^ (2 * ρ - 1)
      = 2 * (1 - ρ) * S * (ε / (1 - ε)) ^ ((3 : ℝ) / 2) / Real.sqrt (ε * (1 - ε)) := by
  have h1ρ : (0 : ℝ) < 1 - ρ := by linarith
  have hB : 0 < ε / (1 - ε) := div_pos hε0 (by linarith)
  have hq : 0 < Real.sqrt (ε * (1 - ε)) := Real.sqrt_pos.mpr (by nlinarith)
  rw [ell, hsum] at H
  rw [Real.mul_rpow hB.le (Real.rpow_nonneg (by positivity) _),
      ← Real.rpow_mul (by positivity), Real.div_rpow hX.le hY.le,
      Real.mul_rpow hX.le hY.le] at H
  have hXe : X ^ ((ρ + 1) / 2) = X ^ (2 - ρ) * X ^ ((ρ - 1) * ((3 : ℝ) / 2)) := by
    rw [← Real.rpow_add hX]; ring_nf
  have hYe : Y ^ (2 * ρ - 1) = Y ^ ((ρ + 1) / 2) * Y ^ ((ρ - 1) * ((3 : ℝ) / 2)) := by
    rw [← Real.rpow_add hY]; ring_nf
  have hA2 : (0 : ℝ) < X ^ ((ρ - 1) * ((3 : ℝ) / 2)) := Real.rpow_pos_of_pos hX _
  have hB1 : (0 : ℝ) < Y ^ ((ρ + 1) / 2) := Real.rpow_pos_of_pos hY _
  have hB2 : (0 : ℝ) < Y ^ ((ρ - 1) * ((3 : ℝ) / 2)) := Real.rpow_pos_of_pos hY _
  rw [hXe] at H
  rw [hYe]
  field_simp at H ⊢
  linarith

/-- Sweeping a guarded level curve by the share parameter `θ ∈ (0,1)` — the state
`x_θ = c (θ/ε)^{1/ρ}` is the one at which `ε x^ρ` is the fraction `θ` of `c^ρ` — the
matching condition `ell = 4 p^{3/2}` says, in logarithms, that
`((2-ρ)/ρ)·log θ + ((2ρ-1)/ρ)·log (1-θ)` is INDEPENDENT of `θ`. -/
private theorem profile_log_const (ρ ε c : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε0 : 0 < ε) (hε1 : ε < 1) (hc : 0 < c)
    (H : ∀ x : ℝ, 0 < x → 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε) →
      ell ρ ε x (yOf ρ ε c x) = 4 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2)) :
    ∀ θ : ℝ, 0 < θ → θ < 1 →
      ((2 - ρ) / ρ) * Real.log θ + ((2 * ρ - 1) / ρ) * Real.log (1 - θ)
        = Real.log (2 * (1 - ρ) * c ^ ρ * (ε / (1 - ε)) ^ ((3 : ℝ) / 2)
              / Real.sqrt (ε * (1 - ε)))
          - (2 - ρ) * Real.log c - (2 * ρ - 1) * Real.log c
          + ((2 - ρ) / ρ) * Real.log ε + ((2 * ρ - 1) / ρ) * Real.log (1 - ε) := by
  intro θ hθ0 hθ1
  have hε' : (1 : ℝ) - ε ≠ 0 := by linarith
  have hu0 : 0 < (1 - θ) / (1 - ε) := div_pos (by linarith) (by linarith)
  have hcr : (0 : ℝ) < c ^ ρ := Real.rpow_pos_of_pos hc _
  set s : ℝ := (θ / ε) ^ (1 / ρ) with hs
  set u : ℝ := ((1 - θ) / (1 - ε)) ^ (1 / ρ) with hu
  have hs0 : 0 < s := Real.rpow_pos_of_pos (div_pos hθ0 hε0) _
  have hu0' : 0 < u := Real.rpow_pos_of_pos hu0 _
  have hX : 0 < c * s := by positivity
  have hY : 0 < c * u := by positivity
  have hXρ : (c * s) ^ ρ = c ^ ρ * (θ / ε) := by
    rw [Real.mul_rpow hc.le hs0.le, hs, ← Real.rpow_mul (div_pos hθ0 hε0).le,
      one_div_mul_cancel hρ, Real.rpow_one]
  have hYρ : (c * u) ^ ρ = c ^ ρ * ((1 - θ) / (1 - ε)) := by
    rw [Real.mul_rpow hc.le hu0'.le, hu, ← Real.rpow_mul hu0.le,
      one_div_mul_cancel hρ, Real.rpow_one]
  have hrad : (c ^ ρ - ε * (c * s) ^ ρ) / (1 - ε) = c ^ ρ * ((1 - θ) / (1 - ε)) := by
    rw [hXρ]; field_simp
  have hradpos : 0 < (c ^ ρ - ε * (c * s) ^ ρ) / (1 - ε) := by rw [hrad]; positivity
  have hyOf : yOf ρ ε c (c * s) = c * u := by
    rw [yOf, hrad, Real.mul_rpow hcr.le hu0.le, ← Real.rpow_mul hc.le,
      mul_one_div_cancel hρ, Real.rpow_one]
  have hsum : ε * (c * s) ^ ρ + (1 - ε) * (c * u) ^ ρ = c ^ ρ := by
    rw [hXρ, hYρ]; field_simp; ring
  have HH := H (c * s) hX hradpos
  rw [hyOf, pOf, hyOf] at HH
  have hred := profile_reduce ρ ε (c * s) (c * u) (c ^ ρ) hρ1 hε0 hε1 hX hY hcr hsum HH
  have hlog := congrArg Real.log hred
  rw [Real.log_mul (by positivity) (by positivity), Real.log_rpow hX, Real.log_rpow hY,
    Real.log_mul hc.ne' hs0.ne', Real.log_mul hc.ne' hu0'.ne', hs, hu,
    Real.log_rpow (div_pos hθ0 hε0), Real.log_rpow (div_pos (by linarith) (by linarith)),
    Real.log_div hθ0.ne' hε0.ne', Real.log_div (by linarith) (by linarith)] at hlog
  linear_combination hlog

/-- **R3 — THE ANSWER: no CES level curve carries the `4·p^{3/2}` profile.** There is no
guarded member `(ρ, ε)` and level `c` whose field matches φ^σ's profile at every
admissible state: matching at all states forces the field's log-slope in the reserve
ratio to be that of a pure power, which `ρ ≠ 0` forbids (the field is a non-power,
`fieldRatio`-style) and `ρ → 0`-slice constancy contradicts the strictly-varying
`4·p^{3/2}`. Since the profile is a reparameterization invariant (R1), NO monotone
relabeling of φ^σ is a CES member — strictly stronger than `phiSigma_not_CES`.

Concretely: refute the existence of `(ρ, ε, c)` (guards `ρ ≠ 0`, `ρ < 1`,
`ε ∈ Ioo 0 1`, `0 < c`) with
`ell ρ ε x (yOf ρ ε c x) = 4 * (pOf ρ ε c x) ^ ((3:ℝ)/2)` for all `x > 0` satisfying
the radicand guard. Two well-chosen evaluation states suffice. -/
theorem no_CES_matches_phiSigma_profile :
    ¬ ∃ (ρ ε c : ℝ), ρ ≠ 0 ∧ ρ < 1 ∧ ε ∈ Ioo (0 : ℝ) 1 ∧ 0 < c ∧
      ∀ x : ℝ, 0 < x → 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε) →
        ell ρ ε x (yOf ρ ε c x) = 4 * (pOf ρ ε c x) ^ ((3 : ℝ) / 2) := by
  rintro ⟨ρ, ε, c, hρ, hρ1, ⟨hε0, hε1⟩, hc, H⟩
  have key := profile_log_const ρ ε c hρ hρ1 hε0 hε1 hc H
  -- the two evaluation states: the shares `θ = 1/4` and `θ = 3/4` of the level
  have h1 := key (1 / 4) (by norm_num) (by norm_num)
  have h2 := key (3 / 4) (by norm_num) (by norm_num)
  rw [show (1 : ℝ) - 1 / 4 = 3 / 4 by norm_num] at h1
  rw [show (1 : ℝ) - 3 / 4 = 1 / 4 by norm_num] at h2
  have hbal : ((2 - ρ) / ρ) * Real.log (1 / 4) + ((2 * ρ - 1) / ρ) * Real.log (3 / 4)
      = ((2 - ρ) / ρ) * Real.log (3 / 4) + ((2 * ρ - 1) / ρ) * Real.log (1 / 4) := by
    linarith
  have hfac : ((2 - ρ) / ρ - (2 * ρ - 1) / ρ) * (Real.log (1 / 4) - Real.log (3 / 4)) = 0 := by
    linear_combination hbal
  have hlt : Real.log (1 / 4 : ℝ) < Real.log (3 / 4 : ℝ) :=
    Real.log_lt_log (by norm_num) (by norm_num)
  have hcoef : (2 - ρ) / ρ - (2 * ρ - 1) / ρ = 0 := by
    rcases mul_eq_zero.1 hfac with h | h
    · exact h
    · linarith
  have : (3 : ℝ) - 3 * ρ = 0 := by
    field_simp at hcoef
    linarith
  linarith

/-- **R4 — the positive classification: constant impact ⟺ parabola.** If a price path
along a curve has CONSTANT impact `dp/dx = k ≠ 0`, the curve is a parabola:
`y(x) = y(0) - k·x²/2 - p(0)·... ` — stated as: `p` affine and `y'' = -k` constant,
so `y` is quadratic. φ^σ's family (the parabolas) is EXACTLY the constant-impact class,
i.e. exactly the `p^{3/2}`-profile class.

(The supplied guard `hk : k ≠ 0` is kept, as it is part of the requested statement, but
the integration goes through for every `k`; `k = 0` is just the degenerate — affine —
member of the family.) -/
theorem constant_impact_is_parabola (p y : ℝ → ℝ) (k : ℝ) (hk : k ≠ 0)
    (himpact : ∀ x, HasDerivAt p k x)
    (hslope : ∀ x, HasDerivAt y (-(p x)) x) :
    ∀ x, y x = y 0 - p 0 * x - k * x ^ 2 / 2 := by
  have hp : ∀ x, p x = p 0 + k * x := by
    intro x
    have hg : ∀ t : ℝ, HasDerivAt (fun s : ℝ => p s - (p 0 + k * s)) 0 t := by
      intro t
      simpa using (himpact t).sub (((hasDerivAt_id t).const_mul k).const_add (p 0))
    have := is_const_of_deriv_eq_zero (f := fun s : ℝ => p s - (p 0 + k * s))
      (fun t => (hg t).differentiableAt) (fun t => (hg t).deriv) x 0
    simp at this
    linarith
  intro x
  have hg : ∀ t : ℝ, HasDerivAt (fun s : ℝ => y s - (y 0 - p 0 * s - k * s ^ 2 / 2)) 0 t := by
    intro t
    have h1 : HasDerivAt (fun s : ℝ => y 0 - p 0 * s - k * s ^ 2 / 2) (-(p 0) - k * t) t := by
      have h2 : HasDerivAt (fun s : ℝ => y 0 - p 0 * s - k * s ^ 2 / 2)
          (0 - p 0 * 1 - k * (2 * t ^ 1) / 2) t :=
        ((hasDerivAt_const t (y 0)).sub ((hasDerivAt_id t).const_mul (p 0))).sub
          (((hasDerivAt_pow 2 t).const_mul k).div_const 2)
      convert h2 using 1; ring
    have h3 := (hslope t).sub h1
    rw [hp t, show -(p 0 + k * t) - (-(p 0) - k * t) = 0 by ring] at h3
    exact h3
  have := is_const_of_deriv_eq_zero (f := fun s : ℝ => y s - (y 0 - p 0 * s - k * s ^ 2 / 2))
    (fun t => (hg t).differentiableAt) (fun t => (hg t).deriv) x 0
  simp at this
  linarith

end ReparamSigma
