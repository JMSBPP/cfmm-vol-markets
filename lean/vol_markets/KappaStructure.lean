import vol_markets.CanonicalParam
import vol_markets.PayoffGeometry

/-!
# KappaStructure — what κ_φ structurally IS: level-curve curvature, benchmark-normalized

## Intent (user question, 2026-08-11)

The document's Definition 14 defines the curvature `κ_φ` through the price-impact
elasticity. The structural question: is it the Gaussian curvature of `φ`? The Gaussian
curvature of the GRAPH is identically zero (proved elsewhere: `hessian_det_zero`), so it
cannot be that. The claim under proof here: `κ_φ` is curvature-typed OF THE LEVEL CURVE —
the level set's planar curvature is `|dp/dx| / (1+p²)^{3/2}`, whose Euclidean factor
`(1+p²)^{3/2}` needs a metric that reserve space does not have (the axes carry different
units); the metric-free part is the PRICE IMPACT, and the missing normalization is
supplied by the BENCHMARK MEMBER at the same point instead — which recovers Definition 14
exactly. Chain: level-curve curvature → strip the metric factor → price impact →
scale-free elasticity → benchmark ratio → `κ_φ = (1-ρ)/(2-ρ)`.

## Scaffolding

`EllIntrinsic`, `CanonicalParam`, `PayoffGeometry` are supplied and ALREADY PROVED —
import, do not modify. `CanonicalParam.hasDerivAt_yOf`/`tangent_slope` give the curve's
slope `y' = -p`; `hasDerivAt_pOf'`/`deriv_pOf_neg` give `dp/dx`; `PayoffGeometry.epsPX`
and `epsPX_balanced` give the elasticity. Notation: Lean `ε` = the document's share
`χ_{X/M}`, Lean `ρ` = the document's substitution `ε_{X/M}` (standing split; do not
rename). The radicand guard `0 < (c^ρ - ε·x^ρ)/(1-ε)` is load-bearing.

## Instructions

Prove the `sorry`'d statements. Priority **S1 > S3 > S2**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. Do not modify
any definition.
-/

namespace KappaStructure

open Real Set EllIntrinsic CanonicalParam PayoffGeometry

/-- The planar curvature of the level curve `x ↦ (x, yOf ρ ε c x)` in the reserve plane:
`|y''| / (1 + y'²)^{3/2}`. -/
noncomputable def curveCurv (ρ ε c x : ℝ) : ℝ :=
  |deriv (fun t => deriv (yOf ρ ε c) t) x| /
    (1 + (deriv (yOf ρ ε c) x) ^ 2) ^ ((3 : ℝ) / 2)

/-- The tangent-slope identity `y' = -p` holds not only at the given point but on a whole
neighbourhood of it: the radicand guard and positivity of the abscissa are open
conditions. -/
lemma deriv_yOf_eventuallyEq (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (yOf ρ ε c) =ᶠ[nhds x] fun z => -(pOf ρ ε c z) := by
  have hUc : ContinuousAt (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε)) x := by
    apply ContinuousAt.div_const
    exact continuousAt_const.sub (continuousAt_const.mul
      (Real.continuousAt_rpow_const _ _ (Or.inl hx.ne')))
  have h1 : {z : ℝ | 0 < z} ∈ nhds x := (isOpen_lt continuous_const continuous_id).mem_nhds hx
  have h2 : (fun z : ℝ => (c ^ ρ - ε * z ^ ρ) / (1 - ε)) ⁻¹' (Ioi 0) ∈ nhds x :=
    hUc.preimage_mem_nhds (Ioi_mem_nhds hu)
  filter_upwards [h1, h2] with z hz hzu
  exact (CanonicalParam.hasDerivAt_yOf ρ ε c z hρ hε hz hzu).deriv

/-- The second derivative of the level curve is minus the price impact: `y'' = -dp/dx`. -/
lemma deriv_deriv_yOf (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hx : 0 < x) (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    deriv (fun t => deriv (yOf ρ ε c) t) x = -deriv (pOf ρ ε c) x := by
  have h := (deriv_yOf_eventuallyEq ρ ε c x hρ hε hx hu).deriv_eq
  simpa using h

/-- **S1 — the metric-free part of the level-curve curvature IS the price impact.**
Stripping the Euclidean factor: `curveCurv · (1 + p²)^{3/2} = |dp/dx|`. (Via the proved
tangent slope `y' = -p`, so `y'' = -dp/dx`.) The factor `(1+p²)^{3/2}` is the part that
needs a metric on reserve space — unavailable, the axes carry different units — and is
exactly what the benchmark normalization replaces.

(The supplied hypothesis `hρ1 : ρ < 1` is kept as given, although the proof does not need
it: the identity holds for every `ρ ≠ 0` under the radicand guard — it is the SIGN of the
price impact, not this identity, that needs `ρ < 1`.) -/
theorem curveCurv_metric_free (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    curveCurv ρ ε c x * (1 + (pOf ρ ε c x) ^ 2) ^ ((3 : ℝ) / 2)
      = |deriv (pOf ρ ε c) x| := by
  have hslope : deriv (yOf ρ ε c) x = -(pOf ρ ε c x) :=
    (CanonicalParam.hasDerivAt_yOf ρ ε c x hρ hε hx hu).deriv
  have hsecond : deriv (fun t => deriv (yOf ρ ε c) t) x = -deriv (pOf ρ ε c) x :=
    deriv_deriv_yOf ρ ε c x hρ hε hx hu
  have hpos : (0 : ℝ) < (1 + (pOf ρ ε c x) ^ 2) ^ ((3 : ℝ) / 2) :=
    Real.rpow_pos_of_pos (by positivity) _
  rw [curveCurv, hsecond, hslope, abs_neg, neg_sq]
  field_simp

/-- **S2 — the scale-free elasticity is the metric-free curvature dressed by the state.**
`|ε_{p/X}| = (x / p) · |dp/dx|` — the price-impact elasticity (Definition 14's raw
observable) is the metric-free curvature times the dimension-cancelling state ratio. -/
theorem epsPX_from_curvature (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε)) :
    |epsPX ρ ε c x|
      = (x / pOf ρ ε c x) *
          (curveCurv ρ ε c x * (1 + (pOf ρ ε c x) ^ 2) ^ ((3 : ℝ) / 2)) := by
  have hp : 0 < pOf ρ ε c x := CanonicalParam.pOf_pos ρ ε c x hρ hε hx hu
  rw [curveCurv_metric_free ρ ε c x hρ hρ1 hε hx hu, epsPX, abs_div, abs_mul,
    abs_of_pos hx, abs_of_pos hp]
  ring

/-- The substitution-0 (constant-product) benchmark elasticity at the same point:
`1/(1-ε)` (share `ε`, the balanced-point value the family's `ρ → 0` member attains). -/
noncomputable def benchEps (ε : ℝ) : ℝ := 1 / (1 - ε)

/-- **S3 — the benchmark ratio recovers Definition 14.** At balanced reserves (where the
proved `epsPX_balanced` gives `|ε_{p/X}| = (1-ρ)/(1-ε)`), the member-against-member
normalization — the elasticity over itself-plus-benchmark — is the CES curvature closed
form: `κ_φ = (1-ρ)/(2-ρ)`, the share cancelling. This completes the chain: level-curve
curvature, metric factor stripped (S1), state-dressed to the elasticity (S2), normalized
against the benchmark member in place of the unavailable metric — Definition 14. -/
theorem benchmark_ratio_recovers_kappa (ρ ε c x : ℝ) (hρ : ρ ≠ 0) (hρ1 : ρ < 1)
    (hε : ε ∈ Ioo (0 : ℝ) 1) (hx : 0 < x)
    (hu : 0 < (c ^ ρ - ε * x ^ ρ) / (1 - ε))
    (hbal : yOf ρ ε c x = x) :
    |epsPX ρ ε c x| / (|epsPX ρ ε c x| + benchEps ε) = (1 - ρ) / (2 - ρ) := by
  obtain ⟨hε0, hε1⟩ := hε
  have hε' : (0 : ℝ) < 1 - ε := by linarith
  have hρ' : (0 : ℝ) < 2 - ρ := by linarith
  rw [epsPX_balanced ρ ε c x hρ hρ1 ⟨hε0, hε1⟩ hx hu hbal, benchEps,
    show (1 - ρ) / (1 - ε) + 1 / (1 - ε) = (2 - ρ) / (1 - ε) by ring,
    div_div_div_cancel_right₀]
  exact hε'.ne'

end KappaStructure
