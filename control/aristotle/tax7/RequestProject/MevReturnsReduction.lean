import Mathlib
import RequestProject.MevChannelClosure

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M28–M32 — the returns reduction of `τ*_MEV`

This module formalizes blocks **M28–M32** of `TAX4_ADDENDUM.md` (Theorems 40–44
and their corollaries).

## Cited, never redone

* `MevTaxControl.Theorem29_monoid_path_is_direct` (`MevTaxControl.lean`) —
  `∂φ/∂τ_MEV|_{φ_M,φ_X} = (1-φ_M)(1-φ_X) > 0`;
* `MevTaxControl.Theorem32_hazard_strictAntiOn_tau`,
  `MevTaxControl.tau_to_nu_strictAntiOn_under_H2` (`MevTaxControl.lean`);
* `MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos` —
  **typed hypotheses, never proved**; likewise
  `MevTaxChannels.ScaleHomogeneous` (`MevChannelClosure.lean`);
* `MevTaxProgram.totalDeriv`, `MevTaxProgram.focCore`,
  `MevTaxProgram.Theorem33_path_decomposition`,
  `MevTaxProgram.Proposition16_corrected_law`,
  `MevTaxProgram.Theorem34_opposed_signs`,
  `MevTaxProgram.Theorem36_no_interior_root_off_the_band`,
  `MevTaxProgram.Proposition15_level_reading_second_order_undetermined`,
  `MevTaxProgram.Proposition15_second_order_exposure`,
  `MevTaxProgram.dphidnuBoxed` (`MevTaxProgram.lean`);
* `MevTaxLVR.Theorem37_LVR_cancellation`, `MevTaxLVR.Theorem37_K_pos`,
  `MevTaxLVR.Corollary37_root_invariance` (`MevLVRCancellation.lean`);
* `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`,
  `MevTaxChannels.Theorem38_two_routes_close_a_loop`,
  `MevTaxChannels.Theorem39_arb_side_does_not_close`,
  `MevTaxChannels.Theorem39_elasticity_closes` (`MevChannelClosure.lean`).

## Reading conventions, and the one trap

`SRC` Convention 9 says the gate derivative is **composed**:
`∂φ/∂ν = (1-φ_M)(1-τ_MEV)·∂φ_X/∂ν`.  The Lean variable named `dphidnu` in
`MevTaxProgram.totalDeriv` / `MevTaxProgram.focCore` is **not** that composed
object: `MevTaxProgram.hasDerivAt_phiTot` instantiates it from
`hphiX : HasDerivAt phiX dphidnu (nu tauMEV)`, i.e. it is the **bare**
`∂φ_X/∂ν` of `DOC` Definition 18, with the monoid Jacobian `(1-φ_M)(1-τ_MEV)`
carried explicitly by `MevTaxProgram.pathGate`.  Everything below writes
`dphiXdnu` for the bare object, and the composed object is written out where it
is meant.  `Corollary40_composed_substitution_disagrees` shows the two readings
are **not** interchangeable in
`MevTaxProgram.Proposition16_corrected_law`'s slot.

## Verdicts returned by this module

* **Theorem 40 HOLDS** under M28's own premises, with the bare reading of
  `dphidnu` (`Theorem40_returns_reduction`), and **Corollary 40 HOLDS**: the
  reduced law is literally `MevTaxProgram.Proposition16_corrected_law`'s
  conjunct 1 after substitution (`Corollary40_consistency_with_Proposition16`).
  Under the *composed* reading of the same slot the two **disagree**, and the
  disagreement is exactly the factor `(1-φ_M)(1-τ_MEV)`
  (`Corollary40_composed_substitution_disagrees`,
  `Corollary40_composed_agrees_iff_monoid_jacobian_is_one`).
* **Corollary 40b is REFUTED in its stated form.**  Extracting `(1-τ_MEV)` from
  the composed denominator does make `τ_MEV` appear once *in that factor* — but
  the reduced right-hand side still carries the composed fee `φ`, which by
  `MevTaxControl.phiTotal` **is itself a function of `τ_MEV`**.  Expanding it
  gives a genuine closed form
  (`Corollary40b_endogenous_fee_closed_form`) in which `(1-φ_X)` does **not**
  cancel (`Corollary40b_phiX_does_not_cancel`).  So the self-reference is
  reduced, not an artifact.
* **The premise dies on one-sided flow**
  (`Corollary40c_one_sided_flow_leaves_no_root`), and **the loop kills `ε`**:
  run with `SRC` Theorem 34's correction the elasticity channel cancels out of
  the FOC entirely and the law is governed by the (H2) channel alone; with the
  (H2) channel switched off there is **no root at all**
  (`Theorem40d_loop_correction_removes_epsilon`).
* **Theorem 41 and Corollary 41 HOLD** (`Theorem41_scale_freeness`,
  `Corollary41_ratio_derivative_closes`).
* **Theorem 42**: the five partials of the reduced law all have settled signs
  (`Theorem42_comparative_statics`), as does the gate height
  (`Theorem42_alphaR_raises_the_gate_slope`); the gate steepness `γ_R` has **no
  global sign** (`Theorem42_gate_steepness_sign_is_ambiguous`,
  `Theorem42_gate_steepness_bracket_witnesses`).  The two `ε` limits are
  `Theorem42_epsilon_limits`.
* **Theorem 43 HOLDS** with `ε*` in closed form (`Theorem43_threshold_elasticity`);
  the endogenous-fee reading has its own threshold
  (`Theorem43_endogenous_threshold_differs`), which is the *same number* read at
  the no-tax fee (`Theorem43_endogenous_threshold_is_the_no_tax_threshold`) and
  differs from `ε*` read at any positive tax
  (`Theorem43_thresholds_differ_at_positive_tax`).
* **Theorem 44 CLOSES O2** on the reduced model
  (`Theorem44_second_order_endogenous_fee`, `Theorem44_O2_closes`,
  `Theorem44_root_is_a_minimum_of_piHat`) — conditionally on the very premise
  `∂ν/∂φ = νε/φ` that `Corollary40c` shows can fail, on the loop of `SRC`
  Theorem 34 not being applied, and on at least one leg charging
  (`(1-φ_M)(1-φ_X) < 1`, so that the composed fee is nonzero throughout `[0,1]`
  — `phiTotal_pos_on_unit_interval`).
-/

namespace MevTaxReturns

/-! ## The reduced data -/

/-- M28's premise: under `ν ∝ ΔQ` (proportional legs) the utilization responds to
the fee through the **fee elasticity of flow** `ε = ∂log ΔQ/∂log φ`:
`∂ν/∂φ = ν ε/φ`.  This is exactly the premise `SRC` Theorem 33(a) and the OPEN
PR-REGION ruling (`DOC:423`) bear on; see
`Corollary40c_one_sided_flow_leaves_no_root`. -/
noncomputable def dnudphiProp (nu eps phi : ℝ) : ℝ := nu * eps / phi

/-- `SRC` Theorem 33 route (ii) with M28's premise substituted:
`∂ν/∂τ_MEV = (∂ν/∂φ)(∂φ/∂τ_MEV)|_{φ_M,φ_X} = (νε/φ)(1-φ_M)(1-φ_X)`, the last
factor by `MevTaxControl.Theorem29_monoid_path_is_direct`. -/
noncomputable def dnudtauRouteII (nu eps phi phiM phiXv : ℝ) : ℝ :=
  dnudphiProp nu eps phi * ((1 - phiM) * (1 - phiXv))

/-- M28's boxed law: `τ*_MEV = 1 + φ/((1-φ_M)(∂φ_X/∂ν) ν ε)`. -/
noncomputable def reducedLaw (phi phiM dphiXdnu nu eps : ℝ) : ℝ :=
  1 + phi / ((1 - phiM) * dphiXdnu * nu * eps)

/-- The threshold elasticity of M31: `ε* = φ/((1-φ_M)(∂φ_X/∂ν)ν)`. -/
noncomputable def epsStar (phi phiM dphiXdnu nu : ℝ) : ℝ :=
  phi / ((1 - phiM) * dphiXdnu * nu)

/-- The threshold elasticity in the **endogenous-fee** reading, where `φ` is the
monoid fee `MevTaxControl.phiTotal φ_M φ_X τ_MEV` rather than a frozen level. -/
noncomputable def epsStarEndogenous (phiM phiXv dphiXdnu nu : ℝ) : ℝ :=
  (1 / (1 - phiM) - (1 - phiXv)) / (dphiXdnu * nu)

/-! ## M28. Theorem 40 — the returns reduction -/

/-- Elementary root form of the reduced FOC. -/
lemma affine_root (phi D tau : ℝ) (hphi : phi ≠ 0) (hD : D ≠ 0) :
    1 + (1 - tau) * D / phi = 0 ↔ tau = 1 + phi / D := by
  constructor
  · intro h; field_simp at h ⊢; linarith
  · intro h; field_simp at h ⊢; linarith

/-- Elementary root form of the reduced FOC once the fee is the monoid fee. -/
lemma one_sub_mul_eq_zero_iff (t D : ℝ) (hD : D ≠ 0) :
    1 - (1 - t) * D = 0 ↔ t = 1 - 1 / D := by
  constructor
  · intro h
    have h1 : (1 - t) = 1 / D := by field_simp; linarith
    linarith
  · intro h
    rw [h]; field_simp; ring

/-- **Theorem 40, the bracket factorisation [M28].**  Substituting `SRC`
Convention 9 and route (ii) with `∂ν/∂φ = νε/φ` into `SRC` Theorem 32's bracket,
the direct monoid path `(1-φ_M)(1-φ_X)` factors out:

`∂π̂^σ/∂τ = A(1-φ_M)(1-φ_X)·[1 + (1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)νε/φ]`.

This is M28's displayed algebra, machine-checked. -/
theorem Theorem40_bracket_factorisation
    (A phiM tauMEV phiXv dphiXdnu nu eps phi : ℝ) (hphi : phi ≠ 0) :
    MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu
        (dnudtauRouteII nu eps phi phiM phiXv)
      = A * ((1 - phiM) * (1 - phiXv)) *
          (1 + (1 - phiM) * (1 - tauMEV) * dphiXdnu * nu * eps / phi) := by
  unfold MevTaxProgram.totalDeriv MevTaxProgram.pathDirect MevTaxProgram.pathGate
    dnudtauRouteII dnudphiProp
  field_simp

/-- **Theorem 40 (Returns reduction) [M28] — HOLDS.**  With `φ_M, φ_X < 1`
(so that `(1-φ_M)(1-φ_X) > 0` divides out, by
`MevTaxControl.Theorem29_monoid_path_is_direct`), a nonzero fee level and a
responsive gate-times-elasticity, the corrected FOC is **explicit** in the
extracted `(1-τ_MEV)`:

`∂π̂^σ/∂τ_MEV = 0 ⟺ τ*_MEV = 1 + φ/((1-φ_M)(∂φ_X/∂ν)νε)`.

`(1-φ_X)` cancels and `K` (`MevTaxLVR.Theorem37_K_pos`) never enters — it is the
`A` of `MevTaxProgram.totalDeriv`, a nonzero common factor. -/
theorem Theorem40_returns_reduction
    (A phiM tauMEV phiXv dphiXdnu nu eps phi : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) (hX : phiXv ≠ 1) (hphi : phi ≠ 0)
    (hE : (1 - phiM) * dphiXdnu * nu * eps ≠ 0) :
    MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu
        (dnudtauRouteII nu eps phi phiM phiXv) = 0
      ↔ tauMEV = reducedLaw phi phiM dphiXdnu nu eps := by
  rw [Theorem40_bracket_factorisation A phiM tauMEV phiXv dphiXdnu nu eps phi hphi]
  have hne : A * ((1 - phiM) * (1 - phiXv)) ≠ 0 :=
    mul_ne_zero hA (mul_ne_zero (sub_ne_zero.mpr (Ne.symm hM)) (sub_ne_zero.mpr (Ne.symm hX)))
  rw [MevTaxProgram.mul_left_eq_zero_iff' _ _ hne]
  have hrw : (1 + (1 - phiM) * (1 - tauMEV) * dphiXdnu * nu * eps / phi)
      = 1 + (1 - tauMEV) * ((1 - phiM) * dphiXdnu * nu * eps) / phi := by ring
  rw [hrw, affine_root phi _ tauMEV hphi hE, reducedLaw]

/-- **Corollary 40 (Consistency) [M28] — HOLDS.**  Under M28's substitution the
boxed reduced law is *literally* `MevTaxProgram.Proposition16_corrected_law`'s
conjunct 1: the right-hand sides are equal as real numbers, and the FOC
equivalence is obtained by invoking that theorem, not by re-deriving it. -/
theorem Corollary40_consistency_with_Proposition16
    (A phiM tauMEV phiXv dphiXdnu nu eps phi : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) (hX : phiXv ≠ 1) (hphi : phi ≠ 0)
    (hE : (1 - phiM) * dphiXdnu * nu * eps ≠ 0) :
    (1 + (1 - phiXv) / (dphiXdnu * dnudtauRouteII nu eps phi phiM phiXv)
        = reducedLaw phi phiM dphiXdnu nu eps) ∧
      (MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu
          (dnudtauRouteII nu eps phi phiM phiXv) = 0
        ↔ tauMEV = reducedLaw phi phiM dphiXdnu nu eps) := by
  have hM' : (1 : ℝ) - phiM ≠ 0 := sub_ne_zero.mpr (Ne.symm hM)
  have hX' : (1 : ℝ) - phiXv ≠ 0 := sub_ne_zero.mpr (Ne.symm hX)
  have hb : dphiXdnu ≠ 0 := by intro h; apply hE; rw [h]; ring
  have hnu : nu ≠ 0 := by intro h; apply hE; rw [h]; ring
  have heps : eps ≠ 0 := by intro h; apply hE; rw [h]; ring
  have h1 : 1 + (1 - phiXv) / (dphiXdnu * dnudtauRouteII nu eps phi phiM phiXv)
      = reducedLaw phi phiM dphiXdnu nu eps := by
    unfold dnudtauRouteII dnudphiProp reducedLaw
    field_simp
  refine ⟨h1, ?_⟩
  have hg : dphiXdnu * dnudtauRouteII nu eps phi phiM phiXv ≠ 0 := by
    unfold dnudtauRouteII dnudphiProp
    exact mul_ne_zero hb (mul_ne_zero (div_ne_zero (mul_ne_zero hnu heps) hphi)
      (mul_ne_zero hM' hX'))
  rw [← h1]
  exact (MevTaxProgram.Proposition16_corrected_law A phiM tauMEV phiXv dphiXdnu
    (dnudtauRouteII nu eps phi phiM phiXv) hA hM hg).1

/-- **Corollary 40, the reading that fails.**  If the slot `dphidnu` of
`MevTaxProgram.Proposition16_corrected_law` is filled with the `SRC` Convention 9
**composed** gate derivative `(1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)` instead of the bare
`∂φ_X/∂ν`, the resulting law agrees with M28's box **iff the monoid Jacobian is
`1`**. -/
theorem Corollary40_composed_agrees_iff_monoid_jacobian_is_one
    (phiM tauMEV phiXv dphiXdnu nu eps phi : ℝ)
    (hM : phiM ≠ 1) (hX : phiXv ≠ 1) (hphi : phi ≠ 0) (hg : dphiXdnu * nu * eps ≠ 0)
    (hJ : (1 - phiM) * (1 - tauMEV) ≠ 0) :
    (1 + (1 - phiXv) /
          (((1 - phiM) * (1 - tauMEV) * dphiXdnu) * dnudtauRouteII nu eps phi phiM phiXv)
        = reducedLaw phi phiM dphiXdnu nu eps)
      ↔ (1 - phiM) * (1 - tauMEV) = 1 := by
  have hM' : (1 : ℝ) - phiM ≠ 0 := sub_ne_zero.mpr (Ne.symm hM)
  have hX' : (1 : ℝ) - phiXv ≠ 0 := sub_ne_zero.mpr (Ne.symm hX)
  have hb : dphiXdnu ≠ 0 := by intro h; apply hg; rw [h]; ring
  have hnu : nu ≠ 0 := by intro h; apply hg; rw [h]; ring
  have heps : eps ≠ 0 := by intro h; apply hg; rw [h]; ring
  have hK : (1 - phiM) * dphiXdnu * nu * eps ≠ 0 :=
    mul_ne_zero (mul_ne_zero (mul_ne_zero hM' hb) hnu) heps
  have hT : (1 : ℝ) - tauMEV ≠ 0 := by intro h; apply hJ; rw [h]; ring
  have hXeq : (1 - phiXv) /
      (((1 - phiM) * (1 - tauMEV) * dphiXdnu) * dnudtauRouteII nu eps phi phiM phiXv)
      = phi / (((1 - phiM) * (1 - tauMEV)) * ((1 - phiM) * dphiXdnu * nu * eps)) := by
    unfold dnudtauRouteII dnudphiProp
    field_simp
  rw [hXeq, reducedLaw, add_right_inj, div_eq_div_iff (mul_ne_zero hJ hK) hK]
  constructor
  · intro h
    have hz : phi * ((1 - phiM) * dphiXdnu * nu * eps) * ((1 - phiM) * (1 - tauMEV) - 1) = 0 := by
      nlinarith [h]
    rcases mul_eq_zero.mp hz with h1 | h1
    · exact absurd h1 (mul_ne_zero hphi hK)
    · linarith
  · intro h; rw [h]; ring

/-- **Corollary 40, the witness.**  A concrete admissible configuration on which
the composed substitution and M28's box disagree. -/
theorem Corollary40_composed_substitution_disagrees :
    ∃ phi phiM phiXv tauMEV dphiXdnu nu eps : ℝ,
      0 < phi ∧ phiM < 1 ∧ phiXv < 1 ∧ 0 < tauMEV ∧ tauMEV < 1 ∧
        0 < dphiXdnu ∧ 0 < nu ∧ eps < 0 ∧
        1 + (1 - phiXv) /
            (((1 - phiM) * (1 - tauMEV) * dphiXdnu) *
              dnudtauRouteII nu eps phi phiM phiXv)
          ≠ reducedLaw phi phiM dphiXdnu nu eps := by
  refine ⟨1, 0, 0, 1 / 2, 1, 1, -1, by norm_num, by norm_num, by norm_num, by norm_num,
    by norm_num, by norm_num, by norm_num, by norm_num, ?_⟩
  norm_num [dnudtauRouteII, dnudphiProp, reducedLaw]

/-- **Corollary 40b, the half that survives [M28].**  With the fee level `φ`, the
gate slope, `ν` and `ε` treated as data *not* depending on the tax, the reduced
FOC is affine in `τ_MEV`: `τ_MEV` occurs exactly once and the root is unique and
explicit. -/
theorem Corollary40b_unique_explicit_root
    (A phiM phiXv dphiXdnu nu eps phi : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) (hX : phiXv ≠ 1) (hphi : phi ≠ 0)
    (hE : (1 - phiM) * dphiXdnu * nu * eps ≠ 0) :
    ∃! t : ℝ, MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu
      (dnudtauRouteII nu eps phi phiM phiXv) = 0 := by
  refine ⟨reducedLaw phi phiM dphiXdnu nu eps, ?_, ?_⟩
  · exact (Theorem40_returns_reduction A phiM _ phiXv dphiXdnu nu eps phi hA hM hX hphi hE).mpr rfl
  · intro y hy
    exact (Theorem40_returns_reduction A phiM y phiXv dphiXdnu nu eps phi hA hM hX hphi hE).mp hy

/-- **Corollary 40b — REFUTED in its stated form [M28].**  The composed fee is
`φ = MevTaxControl.phiTotal φ_M φ_X τ_MEV = 1-(1-φ_M)(1-φ_X)(1-τ_MEV)`, so the
`φ` in the numerator of the boxed law is itself a function of the tax.  Feeding
it in, the FOC is still solvable in closed form, but the closed form is a
**different** expression:

`τ*_MEV = 1 - 1/((1-φ_M)[(1-φ_X) - (∂φ_X/∂ν)νε])`. -/
theorem Corollary40b_endogenous_fee_closed_form
    (A phiM tauMEV phiXv dphiXdnu nu eps : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) (hX : phiXv ≠ 1)
    (hphi : MevTaxControl.phiTotal phiM phiXv tauMEV ≠ 0)
    (hD : (1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps) ≠ 0) :
    MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu
        (dnudtauRouteII nu eps (MevTaxControl.phiTotal phiM phiXv tauMEV) phiM phiXv) = 0
      ↔ tauMEV = 1 - 1 / ((1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps)) := by
  rw [Theorem40_bracket_factorisation A phiM tauMEV phiXv dphiXdnu nu eps _ hphi]
  have hne : A * ((1 - phiM) * (1 - phiXv)) ≠ 0 :=
    mul_ne_zero hA (mul_ne_zero (sub_ne_zero.mpr (Ne.symm hM)) (sub_ne_zero.mpr (Ne.symm hX)))
  rw [MevTaxProgram.mul_left_eq_zero_iff' _ _ hne]
  have hnum : MevTaxControl.phiTotal phiM phiXv tauMEV
      + (1 - phiM) * (1 - tauMEV) * dphiXdnu * nu * eps
      = 1 - (1 - tauMEV) * ((1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps)) := by
    rw [MevTaxControl.phiTotal_eq]; ring
  have hsum : 1 + (1 - phiM) * (1 - tauMEV) * dphiXdnu * nu * eps
        / MevTaxControl.phiTotal phiM phiXv tauMEV
      = (1 - (1 - tauMEV) * ((1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps)))
        / MevTaxControl.phiTotal phiM phiXv tauMEV := by
    rw [← hnum]; field_simp
  rw [hsum, div_eq_zero_iff]
  simp only [hphi, or_false]
  exact one_sub_mul_eq_zero_iff tauMEV _ hD

/-- **Corollary 40b, the witness: `(1-φ_X)` does not cancel.**  Two
configurations differing only in `φ_X` have different roots once the fee is the
monoid fee.  So M28's "note what vanishes" holds only for a fee level frozen in
the tax. -/
theorem Corollary40b_phiX_does_not_cancel :
    ∃ phiM dphiXdnu nu eps phiX₁ phiX₂ : ℝ,
      phiM < 1 ∧ phiX₁ < 1 ∧ phiX₂ < 1 ∧ 0 < dphiXdnu ∧ 0 < nu ∧ eps < 0 ∧
        1 - 1 / ((1 - phiM) * ((1 - phiX₁) - dphiXdnu * nu * eps))
          ≠ 1 - 1 / ((1 - phiM) * ((1 - phiX₂) - dphiXdnu * nu * eps)) := by
  refine ⟨0, 1, 1, -1, 0, 1 / 2, by norm_num, by norm_num, by norm_num, by norm_num,
    by norm_num, by norm_num, ?_⟩
  norm_num

/-- **Corollary 40c (the premise dies on one-sided flow) [M28, falsification
target (a)].**  `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`
gives `∂ν/∂ΔQ = 0` on a one-sided flow; route (ii) then vanishes identically
whatever the elasticity is, and the FOC has **no** solution at all: the total
derivative is `A(1-φ_M)(1-φ_X) ≠ 0` at every tax.  On that flow domain M28's
reduced law is not merely unlicensed, there is nothing for it to describe. -/
theorem Corollary40c_one_sided_flow_leaves_no_root
    (A phiM phiXv dphiXdnu dQdphi dphidtau : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) (hX : phiXv ≠ 1) :
    MevTaxChannels.routeII 0 dQdphi dphidtau = 0 ∧
      ∀ tauMEV : ℝ, MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu
        (MevTaxChannels.routeII 0 dQdphi dphidtau) ≠ 0 := by
  have h0 : MevTaxChannels.routeII 0 dQdphi dphidtau = 0 := by
    unfold MevTaxChannels.routeII; ring
  refine ⟨h0, ?_⟩
  intro t
  rw [h0, MevTaxProgram.totalDeriv_eq_core]
  simp only [MevTaxProgram.focCore, mul_zero, add_zero]
  exact mul_ne_zero (mul_ne_zero hA (sub_ne_zero.mpr (Ne.symm hM)))
    (by simpa using sub_ne_zero.mpr (Ne.symm hX))

/-- **Theorem 40d (the loop removes `ε`) [M28, falsification target (c)].**  Run
both channels simultaneously, in the loop-consistent form of
`MevTaxChannels.Theorem38_two_routes_close_a_loop`
(`P = ∂φ/∂τ|total`, `N = ∂ν/∂τ|total`, `q = ∂ν/∂φ = νε/φ`, `i = route (i)`):

1. the FOC `P = 0` is equivalent to `(1-φ_X) + (1-τ_MEV)(∂φ_X/∂ν)·i = 0` — the
   **elasticity channel `q` has cancelled out entirely**;
2. with the (H2) channel off (`i = 0`) there is **no root**;
3. with `(∂φ_X/∂ν)·i ≠ 0` the law is `τ*_MEV = 1 + (1-φ_X)/((∂φ_X/∂ν)·i)`, in
   which `ε` does not appear.

So M28's "the surviving unknown is `ε` alone" is exactly backwards once the loop
correction of `SRC` Theorem 34 is applied. -/
theorem Theorem40d_loop_correction_removes_epsilon
    (P N phiM phiXv tauMEV dphiXdnu i q : ℝ)
    (hP : P = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tauMEV) * dphiXdnu * N)
    (hN : N = i + q * P)
    (hM : phiM ≠ 1)
    (hden : 1 - q * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) ≠ 0) :
    (P = 0 ↔ (1 - phiXv) + (1 - tauMEV) * dphiXdnu * i = 0) ∧
      (i = 0 → phiXv ≠ 1 → P ≠ 0) ∧
      (dphiXdnu * i ≠ 0 → (P = 0 ↔ tauMEV = 1 + (1 - phiXv) / (dphiXdnu * i))) := by
  have hM' : (1 : ℝ) - phiM ≠ 0 := sub_ne_zero.mpr (Ne.symm hM)
  have key : P * (1 - q * ((1 - phiM) * (1 - tauMEV) * dphiXdnu))
      = (1 - phiM) * ((1 - phiXv) + (1 - tauMEV) * dphiXdnu * i) := by
    linear_combination hP + ((1 - phiM) * (1 - tauMEV) * dphiXdnu) * hN
  have main : P = 0 ↔ (1 - phiXv) + (1 - tauMEV) * dphiXdnu * i = 0 := by
    constructor
    · intro h
      rw [h, zero_mul] at key
      rcases mul_eq_zero.mp key.symm with h1 | h1
      · exact absurd h1 hM'
      · exact h1
    · intro h
      rw [h, mul_zero] at key
      rcases mul_eq_zero.mp key with h1 | h1
      · exact h1
      · exact absurd h1 hden
  refine ⟨main, ?_, ?_⟩
  · intro hi hX hP0
    rw [hi, mul_zero, add_zero] at main
    exact (sub_ne_zero.mpr (Ne.symm hX)) (main.mp hP0)
  · intro hbi
    rw [main, ← MevTaxProgram.focCore_eq_zero_iff tauMEV phiXv (dphiXdnu * i) hbi]
    constructor <;> intro h <;> linarith [h]

/-! ## M29. Theorem 41 — scale-freeness -/

/-- **Theorem 41 (Scale-freeness of the control law) [M29].**

1. The level `K` of `SRC` Theorem 32 (`MevTaxLVR.Theorem37_K_pos`) enters
   `MevTaxProgram.totalDeriv` as the factor `A`, and rescaling it rescales the
   whole derivative — the **root set is invariant**
   (compare `MevTaxLVR.Corollary37_root_invariance`).
2. The fee elasticity of flow is invariant under `ΔQ → cΔQ`.
3. The ratio derivative `∂ν/∂φ` is invariant under the joint rescaling
   `ΔQ → cΔQ`, `L̄ → cL̄`: the scale cancels between the two factors.
4. Hence `reducedLaw` — built only from `(φ, φ_M, ∂φ_X/∂ν, ν, ε)` — is
   unchanged, i.e. `τ*` is invariant under `L̄ → cL̄`. -/
theorem Theorem41_scale_freeness
    (c A phiM tauMEV phiXv dphiXdnu dnudtau : ℝ) (hc : c ≠ 0)
    (Q : ℝ → ℝ) (phi Lbar : ℝ) :
    (MevTaxProgram.totalDeriv (c * A) phiM tauMEV phiXv dphiXdnu dnudtau
        = c * MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu dnudtau) ∧
      (MevTaxProgram.totalDeriv (c * A) phiM tauMEV phiXv dphiXdnu dnudtau = 0
        ↔ MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu dnudtau = 0) ∧
      (phi * deriv (fun f => c * Q f) phi / (c * Q phi)
        = phi * deriv Q phi / Q phi) ∧
      (deriv (fun f => (c * Q f) / (c * Lbar)) phi = deriv (fun f => Q f / Lbar) phi) := by
  have h1 : MevTaxProgram.totalDeriv (c * A) phiM tauMEV phiXv dphiXdnu dnudtau
      = c * MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu dnudtau := by
    unfold MevTaxProgram.totalDeriv MevTaxProgram.pathDirect MevTaxProgram.pathGate; ring
  refine ⟨h1, ?_, ?_, ?_⟩
  · rw [h1]; exact MevTaxProgram.mul_left_eq_zero_iff' _ _ hc
  · rw [deriv_const_mul_field, mul_comm c (deriv Q phi), ← mul_assoc,
      mul_comm (phi * deriv Q phi) c, mul_div_mul_left _ _ hc]
  · have hfun : (fun f => (c * Q f) / (c * Lbar)) = fun f => Q f / Lbar := by
      funext f; rw [mul_div_mul_left _ _ hc]
    rw [hfun]

/-- **Corollary 41 (M27's obstruction does not reach the control law) [M29].**
`MevTaxChannels.Theorem39_arb_side_does_not_close` names the pool scale as the
missing primitive for the **quantity** `∂ΔQ^{ARB}/∂φ`.  For a product-shape flow
`ΔQ = S·h(φ)` on a pool of scale `S·λ`, the **ratio** derivative
`∂ν/∂φ = h'(φ)/λ` is independent of `S`, while `∂ΔQ/∂φ = S·h'(φ)` is not.  The
controller asks only for the ratio derivative, so the missing primitive is
missing from a question the control law does not ask. -/
theorem Corollary41_ratio_derivative_closes
    (h : ℝ → ℝ) (S lam phi : ℝ) (hS : S ≠ 0) :
    deriv (fun f => (S * h f) / (S * lam)) phi = deriv h phi / lam ∧
      deriv (fun f => S * h f) phi = S * deriv h phi := by
  refine ⟨?_, deriv_const_mul_field S⟩
  have hfun : (fun f => (S * h f) / (S * lam)) = fun f => h f / lam := by
    funext f; rw [mul_div_mul_left _ _ hS]
  rw [hfun, deriv_div_const]

/-! ## M30. Theorem 42 — comparative statics -/

/-- Derivative of `t ↦ 1 + C/t`, the shape every partial of the reduced law
takes. -/
lemma hasDerivAt_one_add_const_div (C x : ℝ) (hx : x ≠ 0) :
    HasDerivAt (fun t => 1 + C / t) (-(C / x ^ 2)) x := by
  have h := ((hasDerivAt_inv hx).const_mul C).const_add 1
  have hfun : (fun t : ℝ => 1 + C * t⁻¹) = fun t => 1 + C / t := by
    funext t; rw [div_eq_mul_inv]
  rw [hfun] at h
  convert h using 1
  field_simp

/-- **Theorem 42 (Comparative statics of `τ*`) [M30].**  On the M26/M21 sign
domain — `0 < φ`, `φ_M < 1`, `0 < ∂φ_X/∂ν` (`MevTaxProgram.dphidnuBoxed_pos`),
`0 < ν`, and `ε < 0` (`SRC` Theorem 33(ii)'s `∂ΔQ/∂φ < 0`) — the boxed law's
partials have these signs:

* `∂τ*/∂ε < 0` — a *more* elastic flow (`ε` more negative) **raises** `τ*`;
* `∂τ*/∂ν > 0`;
* `∂τ*/∂φ < 0`;
* `∂τ*/∂φ_M < 0`;
* `∂τ*/∂(∂φ_X/∂ν) > 0`, hence `∂τ*/∂α_R > 0` and, since
  `∂φ/∂φ̄ = (1-φ_M)(1-τ_MEV) > 0`, also `∂τ*/∂φ̄ < 0`. -/
theorem Theorem42_comparative_statics
    (phi phiM dphiXdnu nu eps : ℝ)
    (hphi : 0 < phi) (hM : phiM < 1) (hb : 0 < dphiXdnu) (hnu : 0 < nu) (heps : eps < 0) :
    (HasDerivAt (fun e => reducedLaw phi phiM dphiXdnu nu e)
        (-(phi / ((1 - phiM) * dphiXdnu * nu)) / eps ^ 2) eps ∧
      -(phi / ((1 - phiM) * dphiXdnu * nu)) / eps ^ 2 < 0) ∧
    (HasDerivAt (fun v => reducedLaw phi phiM dphiXdnu v eps)
        (-(phi / ((1 - phiM) * dphiXdnu * eps)) / nu ^ 2) nu ∧
      0 < -(phi / ((1 - phiM) * dphiXdnu * eps)) / nu ^ 2) ∧
    (HasDerivAt (fun f => reducedLaw f phiM dphiXdnu nu eps)
        (1 / ((1 - phiM) * dphiXdnu * nu * eps)) phi ∧
      1 / ((1 - phiM) * dphiXdnu * nu * eps) < 0) ∧
    (HasDerivAt (fun m => reducedLaw phi m dphiXdnu nu eps)
        (phi / (dphiXdnu * nu * eps) / (1 - phiM) ^ 2) phiM ∧
      phi / (dphiXdnu * nu * eps) / (1 - phiM) ^ 2 < 0) ∧
    (HasDerivAt (fun b => reducedLaw phi phiM b nu eps)
        (-(phi / ((1 - phiM) * nu * eps)) / dphiXdnu ^ 2) dphiXdnu ∧
      0 < -(phi / ((1 - phiM) * nu * eps)) / dphiXdnu ^ 2) := by
  have hM1 : (0:ℝ) < 1 - phiM := by linarith
  have heps' : eps ≠ 0 := ne_of_lt heps
  have hnu' : nu ≠ 0 := ne_of_gt hnu
  have hb' : dphiXdnu ≠ 0 := ne_of_gt hb
  have hM1' : (1 - phiM) ≠ 0 := ne_of_gt hM1
  refine ⟨⟨?_, ?_⟩, ⟨?_, ?_⟩, ⟨?_, ?_⟩, ⟨?_, ?_⟩, ?_, ?_⟩
  · have hfun : (fun e => reducedLaw phi phiM dphiXdnu nu e)
        = fun e => 1 + (phi / ((1 - phiM) * dphiXdnu * nu)) / e := by
      funext e; unfold reducedLaw; rw [div_div]
    rw [hfun]
    have h := hasDerivAt_one_add_const_div (phi / ((1 - phiM) * dphiXdnu * nu)) eps heps'
    convert h using 1
    ring
  · have h1 : 0 < phi / ((1 - phiM) * dphiXdnu * nu) := by positivity
    exact div_neg_of_neg_of_pos (by linarith) (by positivity)
  · have hfun : (fun v => reducedLaw phi phiM dphiXdnu v eps)
        = fun v => 1 + (phi / ((1 - phiM) * dphiXdnu * eps)) / v := by
      funext v; unfold reducedLaw
      rw [show (1 - phiM) * dphiXdnu * v * eps = (1 - phiM) * dphiXdnu * eps * v by ring, div_div]
    rw [hfun]
    have h := hasDerivAt_one_add_const_div (phi / ((1 - phiM) * dphiXdnu * eps)) nu hnu'
    convert h using 1
    ring
  · have hd : (1 - phiM) * dphiXdnu * eps < 0 := mul_neg_of_pos_of_neg (by positivity) heps
    have h1 : phi / ((1 - phiM) * dphiXdnu * eps) < 0 := div_neg_of_pos_of_neg hphi hd
    exact div_pos (by linarith) (by positivity)
  · have hfun : (fun f => reducedLaw f phiM dphiXdnu nu eps)
        = fun f => 1 + f / ((1 - phiM) * dphiXdnu * nu * eps) := by
      funext f; unfold reducedLaw; rfl
    rw [hfun]
    exact ((hasDerivAt_id phi).div_const ((1 - phiM) * dphiXdnu * nu * eps)).const_add 1
  · have hd : (1 - phiM) * dphiXdnu * nu * eps < 0 :=
      mul_neg_of_pos_of_neg (by positivity) heps
    exact div_neg_of_pos_of_neg one_pos hd
  · have hfun : (fun m => reducedLaw phi m dphiXdnu nu eps)
        = fun m => 1 + (phi / (dphiXdnu * nu * eps)) / (1 - m) := by
      funext m; unfold reducedLaw
      rw [show (1 - m) * dphiXdnu * nu * eps = dphiXdnu * nu * eps * (1 - m) by ring, div_div]
    rw [hfun]
    have hin : HasDerivAt (fun m : ℝ => 1 - m) (-1) phiM := by
      simpa using (hasDerivAt_id phiM).const_sub 1
    have hout := hasDerivAt_one_add_const_div (phi / (dphiXdnu * nu * eps)) (1 - phiM) hM1'
    have h := hout.comp phiM hin
    convert h using 1
    ring
  · have hd : dphiXdnu * nu * eps < 0 := mul_neg_of_pos_of_neg (by positivity) heps
    have h1 : phi / (dphiXdnu * nu * eps) < 0 := div_neg_of_pos_of_neg hphi hd
    exact div_neg_of_neg_of_pos h1 (by positivity)
  · have hfun : (fun b => reducedLaw phi phiM b nu eps)
        = fun b => 1 + (phi / ((1 - phiM) * nu * eps)) / b := by
      funext b; unfold reducedLaw
      rw [show (1 - phiM) * b * nu * eps = (1 - phiM) * nu * eps * b by ring, div_div]
    rw [hfun]
    have h := hasDerivAt_one_add_const_div (phi / ((1 - phiM) * nu * eps)) dphiXdnu hb'
    convert h using 1
    ring
  · have hd : (1 - phiM) * nu * eps < 0 := mul_neg_of_pos_of_neg (by positivity) heps
    have h1 : phi / ((1 - phiM) * nu * eps) < 0 := div_neg_of_pos_of_neg hphi hd
    exact div_pos (by linarith) (by positivity)

/-- **Theorem 42, the gate parameters [M30].**  With `∂φ_X/∂ν` expanded from
`DOC` Definition 18's gate (`MevTaxProgram.dphidnuBoxed`), the response to the
gate **height** `α_R` is unambiguous: `∂(∂φ_X/∂ν)/∂α_R > 0`, hence
`∂τ*/∂α_R > 0` on the sign domain of `Theorem42_comparative_statics`. -/
theorem Theorem42_alphaR_raises_the_gate_slope
    (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR nu : ℝ)
    (hγ : 0 < gammaR) (hV : 0 < MevTaxProgram.volSurcharge n γ β α σ) :
    HasDerivAt (fun a => MevTaxProgram.dphidnuBoxed n γ β α σ a gammaR betaR nu)
        (gammaR * MevTaxProgram.volSurcharge n γ β α σ *
          (Real.exp (gammaR * (betaR - nu)) / (1 + Real.exp (gammaR * (betaR - nu))) ^ 2))
        alphaR ∧
      0 < gammaR * MevTaxProgram.volSurcharge n γ β α σ *
        (Real.exp (gammaR * (betaR - nu)) / (1 + Real.exp (gammaR * (betaR - nu))) ^ 2) := by
  constructor
  · have hfun : (fun a => MevTaxProgram.dphidnuBoxed n γ β α σ a gammaR betaR nu)
        = fun a => a * (gammaR * MevTaxProgram.volSurcharge n γ β α σ *
            (Real.exp (gammaR * (betaR - nu)) / (1 + Real.exp (gammaR * (betaR - nu))) ^ 2)) := by
      funext a; unfold MevTaxProgram.dphidnuBoxed; ring
    rw [hfun]
    simpa using (hasDerivAt_id alphaR).mul_const _
  · have hpos : (0:ℝ) < Real.exp (gammaR * (betaR - nu)) /
        (1 + Real.exp (gammaR * (betaR - nu))) ^ 2 := by positivity
    positivity

/-- **Theorem 42, the gate steepness [M30] — the sign is NOT settled.**  The
derivative of `MevTaxProgram.dphidnuBoxed` in the steepness `γ_R` is

`α_R V e^z[(1+e^z) + γ_R(β_R-ν)(1-e^z)]/(1+e^z)^3`, `z = γ_R(β_R-ν)`,

whose sign is that of the bracket and therefore **depends on where the pool
operates relative to the gate centre `β_R`**.  At `ν = β_R` it is positive; for
`ν` far above `β_R` with a steep gate it is negative.  Both witnesses are
exhibited, so `∂τ*/∂γ_R` is `OPEN` as a global sign: it is a domain statement,
not a sign. -/
theorem Theorem42_gate_steepness_sign_is_ambiguous
    (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR nu : ℝ) :
    HasDerivAt (fun g => MevTaxProgram.dphidnuBoxed n γ β α σ alphaR g betaR nu)
        (alphaR * MevTaxProgram.volSurcharge n γ β α σ *
          (Real.exp (gammaR * (betaR - nu)) *
              ((1 + Real.exp (gammaR * (betaR - nu))) +
                gammaR * (betaR - nu) * (1 - Real.exp (gammaR * (betaR - nu)))) /
            (1 + Real.exp (gammaR * (betaR - nu))) ^ 3))
        gammaR := by
  have hcalc1 : ∀ E m : ℝ, 0 < 1 + E →
      (E * m * (1 + E) ^ 2 - E * (2 * (1 + E) * (E * m))) / ((1 + E) ^ 2) ^ 2
        = E * m * (1 - E) / (1 + E) ^ 3 := by
    intro E m hE
    have : (1 + E) ≠ 0 := ne_of_gt hE
    field_simp
    ring
  have hcalc2 : ∀ E m a V : ℝ, 0 < 1 + E →
      a * V * (E / (1 + E) ^ 2) + a * gammaR * V * (E * m * (1 - E) / (1 + E) ^ 3)
        = a * V * (E * ((1 + E) + gammaR * m * (1 - E)) / (1 + E) ^ 3) := by
    intro E m a V hE
    have : (1 + E) ≠ 0 := ne_of_gt hE
    field_simp
  set m := betaR - nu with hm
  set V := MevTaxProgram.volSurcharge n γ β α σ with hV
  have hpos : (0:ℝ) < 1 + Real.exp (gammaR * m) := by positivity
  have hE : HasDerivAt (fun g : ℝ => Real.exp (g * m)) (Real.exp (gammaR * m) * m) gammaR := by
    have h1 : HasDerivAt (fun g : ℝ => g * m) m gammaR := by
      simpa using (hasDerivAt_id gammaR).mul_const m
    simpa using h1.exp
  have hden : HasDerivAt (fun g : ℝ => (1 + Real.exp (g * m)) ^ 2)
      (2 * (1 + Real.exp (gammaR * m)) * (Real.exp (gammaR * m) * m)) gammaR := by
    have h := (hE.const_add (1:ℝ)).pow 2
    convert h using 1
    norm_num
  have hne : (1 + Real.exp (gammaR * m)) ^ 2 ≠ 0 := by positivity
  have hw : HasDerivAt (fun g : ℝ => Real.exp (g * m) / (1 + Real.exp (g * m)) ^ 2)
      (Real.exp (gammaR * m) * m * (1 - Real.exp (gammaR * m))
        / (1 + Real.exp (gammaR * m)) ^ 3) gammaR := by
    rw [← hcalc1 _ m hpos]
    exact hE.div hden hne
  have hlin : HasDerivAt (fun g : ℝ => alphaR * g * V) (alphaR * V) gammaR := by
    have h1 : HasDerivAt (fun g : ℝ => alphaR * g) alphaR gammaR := by
      simpa using (hasDerivAt_id gammaR).const_mul alphaR
    simpa using h1.mul_const V
  have hfun : (fun g => MevTaxProgram.dphidnuBoxed n γ β α σ alphaR g betaR nu)
      = fun g => (alphaR * g * V) * (Real.exp (g * m) / (1 + Real.exp (g * m)) ^ 2) := by
    funext g; unfold MevTaxProgram.dphidnuBoxed; rw [← hV, ← hm]
  rw [hfun, ← hcalc2 _ m alphaR V hpos]
  exact hlin.mul hw

/-- **Theorem 42, the two witnesses for the `γ_R` bracket.**  The bracket
`(1+e^z) + γ_R(β_R-ν)(1-e^z)` is positive at the gate centre (`ν = β_R`) and
negative for a steep gate operated above the centre (`γ_R = 10`, `β_R - ν = -1`). -/
theorem Theorem42_gate_steepness_bracket_witnesses :
    (0 < (1 + Real.exp ((1 : ℝ) * (0 : ℝ))) +
        (1 : ℝ) * (0 : ℝ) * (1 - Real.exp ((1 : ℝ) * (0 : ℝ)))) ∧
      ((1 + Real.exp ((10 : ℝ) * (-1 : ℝ))) +
        (10 : ℝ) * (-1 : ℝ) * (1 - Real.exp ((10 : ℝ) * (-1 : ℝ))) < 0) := by
  refine ⟨by norm_num, ?_⟩
  have h1 : Real.exp ((10:ℝ) * (-1)) = (Real.exp 10)⁻¹ := by
    rw [show (10:ℝ) * (-1) = -10 by norm_num, Real.exp_neg]
  have h2 : (11:ℝ) ≤ Real.exp 10 := by
    have := Real.add_one_le_exp (10:ℝ)
    linarith
  have h3 : (Real.exp 10)⁻¹ ≤ 1 / 11 := by
    rw [inv_le_comm₀ (by linarith) (by norm_num)]
    linarith
  rw [h1]
  nlinarith [h3]

/-- **Theorem 42, the two `ε` limits [M30].**

* `ε → 0⁻` (inelastic flow): `τ* → -∞`.  Below the threshold of Theorem 43 the
  interior root leaves the admissible set entirely and the constrained optimum is
  the corner `τ_MEV = 0`.
* `|ε| → ∞` (perfectly elastic flow): `τ* → 1⁻`, the confiscatory limit — the
  admissible set is exhausted from below but never reached. -/
theorem Theorem42_epsilon_limits
    (phi phiM dphiXdnu nu : ℝ)
    (hphi : 0 < phi) (hM : phiM < 1) (hb : 0 < dphiXdnu) (hnu : 0 < nu) :
    Filter.Tendsto (fun e => reducedLaw phi phiM dphiXdnu nu e)
        (nhdsWithin 0 (Set.Iio 0)) Filter.atBot ∧
      Filter.Tendsto (fun e => reducedLaw phi phiM dphiXdnu nu e)
        Filter.atBot (nhds 1) := by
  have hM1 : (0:ℝ) < 1 - phiM := by linarith
  have hC : 0 < phi / ((1 - phiM) * dphiXdnu * nu) := by positivity
  set C := phi / ((1 - phiM) * dphiXdnu * nu) with hCdef
  have hfun : (fun e => reducedLaw phi phiM dphiXdnu nu e) = fun e => 1 + C * e⁻¹ := by
    funext e
    unfold reducedLaw
    rw [hCdef, ← div_div, div_eq_mul_inv]
  rw [hfun]
  refine ⟨?_, ?_⟩
  · have h1 : Filter.Tendsto (fun e : ℝ => e⁻¹) (nhdsWithin 0 (Set.Iio 0)) Filter.atBot :=
      tendsto_inv_nhdsLT_zero
    exact Filter.tendsto_atBot_add_const_left _ 1 (h1.const_mul_atBot hC)
  · have h1 : Filter.Tendsto (fun e : ℝ => e⁻¹) Filter.atBot (nhds 0) := tendsto_inv_atBot_zero
    have h2 : Filter.Tendsto (fun e : ℝ => C * e⁻¹) Filter.atBot (nhds 0) := by
      simpa using h1.const_mul C
    simpa using h2.const_add 1

/-! ## M31. Theorem 43 — the threshold elasticity -/

/-- **Theorem 43 (Threshold elasticity) [M31].**  On the sign domain,
`Proposition 13`'s admissibility condition
`1 - φ_X < |(∂φ/∂ν)(∂ν/∂τ_MEV)|` — carried with its guard
(`MevTaxProgram.Proposition16_corrected_law`, conjunct 2) — becomes a threshold
on the elasticity **alone**:

`τ* > 0 ⟺ |ε| > ε* = φ/((1-φ_M)(∂φ_X/∂ν)ν)`,

and `ε*` does not involve `φ_X`.  Below the threshold no interior tax is
optimal and the constrained optimum is the corner `τ_MEV = 0`. -/
theorem Theorem43_threshold_elasticity
    (phi phiM phiXv dphiXdnu nu eps : ℝ)
    (hphi : 0 < phi) (hM : phiM < 1) (hX : phiXv < 1) (hb : 0 < dphiXdnu)
    (hnu : 0 < nu) (heps : eps < 0) :
    (0 < reducedLaw phi phiM dphiXdnu nu eps ↔ epsStar phi phiM dphiXdnu nu < |eps|) ∧
      (1 - phiXv < |dphiXdnu * dnudtauRouteII nu eps phi phiM phiXv|
        ↔ epsStar phi phiM dphiXdnu nu < |eps|) ∧
      (reducedLaw phi phiM dphiXdnu nu eps < 1) := by
  have hM1 : (0:ℝ) < 1 - phiM := by linarith
  have hX1 : (0:ℝ) < 1 - phiXv := by linarith
  have hX0 : (0:ℝ) < (1 - phiM) * dphiXdnu * nu := by positivity
  have hne : (0:ℝ) < -eps := by linarith
  have habs : |eps| = -eps := abs_of_neg heps
  have hden : (0:ℝ) < (1 - phiM) * dphiXdnu * nu * (-eps) := by positivity
  have hrl : reducedLaw phi phiM dphiXdnu nu eps
      = 1 - phi / ((1 - phiM) * dphiXdnu * nu * (-eps)) := by
    unfold reducedLaw
    rw [show (1 - phiM) * dphiXdnu * nu * eps = -((1 - phiM) * dphiXdnu * nu * (-eps)) by ring,
      div_neg]
    ring
  have hkey : epsStar phi phiM dphiXdnu nu < |eps|
      ↔ phi < (1 - phiM) * dphiXdnu * nu * (-eps) := by
    rw [habs, epsStar, div_lt_iff₀ hX0]
    constructor <;> intro h <;> nlinarith [h]
  refine ⟨?_, ?_, ?_⟩
  · rw [hrl, hkey]
    constructor
    · intro h
      exact (div_lt_one hden).mp (by linarith)
    · intro h
      have : phi / ((1 - phiM) * dphiXdnu * nu * (-eps)) < 1 := (div_lt_one hden).mpr h
      linarith
  · have hval : dphiXdnu * dnudtauRouteII nu eps phi phiM phiXv
        = -((1 - phiXv) * ((1 - phiM) * dphiXdnu * nu * (-eps)) / phi) := by
      unfold dnudtauRouteII dnudphiProp
      field_simp
    have hpos : (0:ℝ) < (1 - phiXv) * ((1 - phiM) * dphiXdnu * nu * (-eps)) / phi := by positivity
    rw [hval, abs_neg, abs_of_pos hpos, hkey, lt_div_iff₀ hphi]
    constructor <;> intro h <;> nlinarith [h]
  · rw [hrl]
    have : 0 < phi / ((1 - phiM) * dphiXdnu * nu * (-eps)) := by positivity
    linarith

/-- **Theorem 43, the endogenous-fee threshold [M31].**  In the reading of
`Corollary40b_endogenous_fee_closed_form`, where `φ` is the monoid fee, the same
admissibility question has the threshold
`ε*_endo = (1/(1-φ_M) - (1-φ_X))/((∂φ_X/∂ν)ν)`, which is written in terms of
`φ_X` rather than of an operating fee level.  It is the same number as `ε*` read
at the no-tax fee — see
`Theorem43_endogenous_threshold_is_the_no_tax_threshold`. -/
theorem Theorem43_endogenous_threshold_differs
    (phiM phiXv dphiXdnu nu eps : ℝ)
    (hM : phiM < 1) (hX : phiXv < 1) (hb : 0 < dphiXdnu)
    (hnu : 0 < nu) (heps : eps < 0) :
    (0 < 1 - 1 / ((1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps))
        ↔ epsStarEndogenous phiM phiXv dphiXdnu nu < |eps|) := by
  have hM1 : (0:ℝ) < 1 - phiM := by linarith
  have hX1 : (0:ℝ) < 1 - phiXv := by linarith
  have hbn : (0:ℝ) < dphiXdnu * nu := by positivity
  have hpos : (0:ℝ) < -(dphiXdnu * nu * eps) := by
    have : dphiXdnu * nu * eps < 0 := mul_neg_of_pos_of_neg hbn heps
    linarith
  have hD : (0:ℝ) < (1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps) := by
    apply mul_pos hM1; linarith
  have hu : 1 / (1 - phiM) * (1 - phiM) = 1 := by field_simp
  rw [abs_of_neg heps, epsStarEndogenous, div_lt_iff₀ hbn]
  constructor
  · intro h
    have h1 : 1 / ((1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps)) < 1 := by linarith
    have h2 : (1:ℝ) < (1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps) := (div_lt_one hD).mp h1
    have h3 : 1 / (1 - phiM) < (1 - phiXv) - dphiXdnu * nu * eps := by
      rw [div_lt_iff₀ hM1]; nlinarith [h2]
    nlinarith [h3]
  · intro h
    have h3 : 1 / (1 - phiM) < (1 - phiXv) - dphiXdnu * nu * eps := by nlinarith [h]
    have h2 : (1:ℝ) < (1 - phiM) * ((1 - phiXv) - dphiXdnu * nu * eps) := by
      nlinarith [mul_lt_mul_of_pos_right h3 hM1, hu]
    have h1 := (div_lt_one hD).mpr h2
    linarith

/-- **Theorem 43, how the two thresholds are related [M31].**  The
endogenous-fee threshold is exactly the frozen threshold **evaluated at the
no-tax fee** `φ(0) = φ_M ⊗_φ φ_X`: the design number is the same object read at
different operating points, and it does differ as soon as the fee is read at a
positive tax.  So M31's number is well posed, but it must be quoted with the fee
it is evaluated at. -/
theorem Theorem43_endogenous_threshold_is_the_no_tax_threshold
    (phiM phiXv dphiXdnu nu : ℝ) (hM : phiM ≠ 1) :
    epsStarEndogenous phiM phiXv dphiXdnu nu
        = epsStar (MevTaxControl.phiTotal phiM phiXv 0) phiM dphiXdnu nu := by
  have hM' : (1:ℝ) - phiM ≠ 0 := sub_ne_zero.mpr (Ne.symm hM)
  unfold epsStar epsStarEndogenous
  rw [MevTaxControl.phiTotal_eq]
  by_cases hbn : dphiXdnu * nu = 0
  · rw [hbn, div_zero, show (1 - phiM) * dphiXdnu * nu = (1 - phiM) * (dphiXdnu * nu) by ring,
      hbn, mul_zero, div_zero]
  · field_simp
    ring

/-- Read at a positive tax the two thresholds are different numbers. -/
theorem Theorem43_thresholds_differ_at_positive_tax :
    ∃ phiM phiXv dphiXdnu nu tauMEV : ℝ,
      phiM < 1 ∧ phiXv < 1 ∧ 0 < dphiXdnu ∧ 0 < nu ∧ 0 < tauMEV ∧ tauMEV < 1 ∧
        epsStar (MevTaxControl.phiTotal phiM phiXv tauMEV) phiM dphiXdnu nu
          ≠ epsStarEndogenous phiM phiXv dphiXdnu nu := by
  refine ⟨0, 0, 1, 1, 1 / 2, by norm_num, by norm_num, by norm_num, by norm_num, by norm_num,
    by norm_num, ?_⟩
  norm_num [epsStar, epsStarEndogenous, MevTaxControl.phiTotal_eq]

/-! ## M32. Theorem 44 — the second-order condition, and O2 -/

/-- **Theorem 44 (Second-order condition, frozen fee) [M32].**  With the gate
data frozen in the tax, the total derivative is affine in `τ_MEV` with slope
`-A(1-φ_M)(∂φ_X/∂ν)(∂ν/∂τ_MEV)`, strictly positive under the M21 signs
(`A > 0` by `MevTaxLVR.Theorem37_K_pos`, `∂φ_X/∂ν > 0`, `∂ν/∂τ_MEV < 0`).  So
`∂²π̂^σ/∂τ² > 0`: the root is a **minimum** of `π̂^σ`. -/
theorem Theorem44_second_order_frozen_fee
    (A phiM phiXv dphiXdnu dnudtau tauMEV : ℝ)
    (hA : 0 < A) (hM : phiM < 1) (hb : 0 < dphiXdnu) (hd : dnudtau < 0) :
    HasDerivAt (fun t => MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau)
        (-(A * (1 - phiM) * (dphiXdnu * dnudtau))) tauMEV ∧
      0 < -(A * (1 - phiM) * (dphiXdnu * dnudtau)) := by
  constructor
  · have hfun : (fun t => MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau)
        = fun t => A * (1 - phiM) * (1 - phiXv)
            + A * (1 - phiM) * ((1 - t) * (dphiXdnu * dnudtau)) := by
      funext t
      unfold MevTaxProgram.totalDeriv MevTaxProgram.pathDirect MevTaxProgram.pathGate
      rfl
    rw [hfun]
    have h1 : HasDerivAt (fun t : ℝ => 1 - t) (-1) tauMEV := by
      simpa using (hasDerivAt_id tauMEV).const_sub 1
    have h2 := ((h1.mul_const (dphiXdnu * dnudtau)).const_mul (A * (1 - phiM))).const_add
      (A * (1 - phiM) * (1 - phiXv))
    convert h2 using 1
    ring
  · have h1 : (0:ℝ) < A * (1 - phiM) := by
      apply mul_pos hA; linarith
    have h2 : dphiXdnu * dnudtau < 0 := mul_neg_of_pos_of_neg hb hd
    nlinarith [mul_pos h1 (neg_pos.mpr h2)]

/-- **Theorem 44 (Second-order condition, endogenous fee) [M32] — O2 CLOSES on
the reduced model.**  With the fee the monoid fee `MevTaxControl.phiTotal` and
route (ii) supplying `∂ν/∂τ_MEV`, the total derivative has derivative

`∂²π̂^σ/∂τ² = -A(1-φ_M)²(1-φ_X)(∂φ_X/∂ν)νε/φ(τ)²`,

whose sign is `-sign(ε)` — settled by `(ε, ν, Θ_φ, φ_M)` exactly as M32 hoped.
On the M26 domain (`ε < 0`) it is **strictly positive at every tax**, so `π̂^σ`
is strictly convex in the tax: the root is a minimum, it is unique, and single
crossing holds.  This is conditional on the premise `∂ν/∂φ = νε/φ`, which
`Corollary40c_one_sided_flow_leaves_no_root` shows can fail. -/
theorem Theorem44_second_order_endogenous_fee
    (A phiM phiXv dphiXdnu nu eps tauMEV : ℝ)
    (hA : 0 < A) (hM : phiM < 1) (hX : phiXv < 1) (hb : 0 < dphiXdnu)
    (hnu : 0 < nu) (heps : eps < 0)
    (hphi : MevTaxControl.phiTotal phiM phiXv tauMEV ≠ 0) :
    HasDerivAt (fun t => MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu
          (dnudtauRouteII nu eps (MevTaxControl.phiTotal phiM phiXv t) phiM phiXv))
        (-(A * (1 - phiM) ^ 2 * (1 - phiXv) * dphiXdnu * nu * eps /
            MevTaxControl.phiTotal phiM phiXv tauMEV ^ 2)) tauMEV ∧
      0 < -(A * (1 - phiM) ^ 2 * (1 - phiXv) * dphiXdnu * nu * eps /
            MevTaxControl.phiTotal phiM phiXv tauMEV ^ 2) := by
  have hM1 : (0:ℝ) < 1 - phiM := by linarith
  have hX1 : (0:ℝ) < 1 - phiXv := by linarith
  constructor
  · have hfun : (fun t => MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu
          (dnudtauRouteII nu eps (MevTaxControl.phiTotal phiM phiXv t) phiM phiXv))
        = fun t => A * (1 - phiM) * (1 - phiXv)
            + (A * (1 - phiM) * (1 - phiXv) * ((1 - phiM) * dphiXdnu * nu * eps))
              * ((1 - t) / MevTaxControl.phiTotal phiM phiXv t) := by
      funext t
      unfold MevTaxProgram.totalDeriv MevTaxProgram.pathDirect MevTaxProgram.pathGate
        dnudtauRouteII dnudphiProp
      simp only [div_eq_mul_inv]
      ring
    rw [hfun]
    have h1 : HasDerivAt (fun t : ℝ => 1 - t) (-1) tauMEV := by
      simpa using (hasDerivAt_id tauMEV).const_sub 1
    have hphiT := MevTaxControl.hasDerivAt_phiTotal_tau phiM phiXv tauMEV
    have hg := h1.div hphiT hphi
    have hnum : (-1 * MevTaxControl.phiTotal phiM phiXv tauMEV
        - (1 - tauMEV) * ((1 - phiM) * (1 - phiXv))) = -1 := by
      rw [MevTaxControl.phiTotal_eq]; ring
    rw [hnum] at hg
    have h3 := (hg.const_mul (A * (1 - phiM) * (1 - phiXv) *
      ((1 - phiM) * dphiXdnu * nu * eps))).const_add (A * (1 - phiM) * (1 - phiXv))
    convert h3 using 1
    field_simp
  · have hnumneg : A * (1 - phiM) ^ 2 * (1 - phiXv) * dphiXdnu * nu * eps < 0 := by
      have : 0 < A * (1 - phiM) ^ 2 * (1 - phiXv) * dphiXdnu * nu := by positivity
      exact mul_neg_of_pos_of_neg this heps
    have hsq : (0:ℝ) < MevTaxControl.phiTotal phiM phiXv tauMEV ^ 2 := by positivity
    have := div_neg_of_neg_of_pos hnumneg hsq
    linarith

/-- **Theorem 44, the reading that does not discriminate [M32].**  `SRC`
Definition 36 minimizes `(∂π̂^σ/∂τ)²`; by
`MevTaxProgram.Proposition15_second_order_exposure` **every** root of the total
derivative minimizes that objective, whatever the curvature of `π̂^σ`.  So the
objective reading cannot settle O2 by itself; what settles it here is the sign
of the slope, `Theorem44_second_order_endogenous_fee`. -/
theorem Theorem44_objective_reading_does_not_discriminate
    (piHatOf D D' : ℝ → ℝ) (tstar c : ℝ)
    (hD : ∀ t, deriv piHatOf t = D t) (hroot : D tstar = 0)
    (hD' : ∀ t, HasDerivAt D (D' t) t) (hD'' : HasDerivAt D' c tstar) :
    IsMinOn (MevTaxProgram.exposure piHatOf) Set.univ tstar :=
  (MevTaxProgram.Proposition15_second_order_exposure piHatOf D D' tstar c hD hroot hD' hD'').1

/-- **Theorem 44, the payoff reading [M32].**  A total derivative that is
strictly increasing on `[0,1]` and vanishes at `t*` makes `t*` a minimizer of
`π̂^σ` on `[0,1]`: the open item **O2** closes in the direction "the root is a
minimum of `π̂^σ`", given `Theorem44_O2_closes`'s strict monotonicity. -/
theorem Theorem44_root_is_a_minimum_of_piHat
    (piHatOf D : ℝ → ℝ) (tstar : ℝ)
    (hD : ∀ t ∈ Set.Icc (0:ℝ) 1, HasDerivAt piHatOf (D t) t)
    (hmono : StrictMonoOn D (Set.Icc (0:ℝ) 1)) (hmem : tstar ∈ Set.Icc (0:ℝ) 1)
    (hroot : D tstar = 0) :
    IsMinOn piHatOf (Set.Icc (0:ℝ) 1) tstar := by
  rw [isMinOn_iff]
  intro x hx
  have hsubL : ∀ y ∈ Set.Icc x tstar, y ∈ Set.Icc (0:ℝ) 1 := fun y hy =>
    ⟨le_trans hx.1 hy.1, le_trans hy.2 hmem.2⟩
  have hsubR : ∀ y ∈ Set.Icc tstar x, y ∈ Set.Icc (0:ℝ) 1 := fun y hy =>
    ⟨le_trans hmem.1 hy.1, le_trans hy.2 hx.2⟩
  rcases lt_trichotomy x tstar with hlt | heq | hgt
  · have hcont : ContinuousOn piHatOf (Set.Icc x tstar) := fun y hy =>
      ((hD y (hsubL y hy)).continuousAt).continuousWithinAt
    have hanti : StrictAntiOn piHatOf (Set.Icc x tstar) := by
      apply strictAntiOn_of_deriv_neg (convex_Icc x tstar) hcont
      intro t ht
      rw [interior_Icc] at ht
      have htI : t ∈ Set.Icc (0:ℝ) 1 := hsubL t ⟨le_of_lt ht.1, le_of_lt ht.2⟩
      rw [(hD t htI).deriv, ← hroot]
      exact hmono htI hmem ht.2
    exact le_of_lt (hanti (Set.left_mem_Icc.mpr (le_of_lt hlt))
      (Set.right_mem_Icc.mpr (le_of_lt hlt)) hlt)
  · rw [heq]
  · have hcont : ContinuousOn piHatOf (Set.Icc tstar x) := fun y hy =>
      ((hD y (hsubR y hy)).continuousAt).continuousWithinAt
    have hmo : StrictMonoOn piHatOf (Set.Icc tstar x) := by
      apply strictMonoOn_of_deriv_pos (convex_Icc tstar x) hcont
      intro t ht
      rw [interior_Icc] at ht
      have htI : t ∈ Set.Icc (0:ℝ) 1 := hsubR t ⟨le_of_lt ht.1, le_of_lt ht.2⟩
      rw [(hD t htI).deriv, ← hroot]
      exact hmono hmem htI ht.1
    exact le_of_lt (hmo (Set.left_mem_Icc.mpr (le_of_lt hgt))
      (Set.right_mem_Icc.mpr (le_of_lt hgt)) hgt)

/-- On the admissible tax interval the composed fee is strictly positive as soon
as the monoid factor `(1-φ_M)(1-φ_X)` is `< 1` — i.e. as soon as at least one leg
charges. -/
lemma phiTotal_pos_on_unit_interval (phiM phiXv t : ℝ)
    (hM : phiM < 1) (hX : phiXv < 1) (hm : (1 - phiM) * (1 - phiXv) < 1)
    (ht : t ∈ Set.Icc (0:ℝ) 1) : 0 < MevTaxControl.phiTotal phiM phiXv t := by
  obtain ⟨h0, h1⟩ := ht
  rw [MevTaxControl.phiTotal_eq]
  have hmpos : 0 < (1 - phiM) * (1 - phiXv) := mul_pos (by linarith) (by linarith)
  nlinarith

/-- **Theorem 44 — O2 CLOSES [M32].**  On the admissible interval `[0,1]`, with at
least one leg charging (`(1-φ_M)(1-φ_X) < 1`, so the composed fee never
vanishes) and on the M26 sign domain, the total derivative `∂π̂^σ/∂τ_MEV` is
**strictly increasing**.  Hence: single crossing holds (it is a theorem here, not
the unproved hypothesis of
`MevTaxProgram.Proposition15_single_crossing_gives_minimum`), the interior root is
unique, and by `Theorem44_root_is_a_minimum_of_piHat` it is a **minimum** of
`π̂^σ`.  Conditional, as everything in M28 is, on `∂ν/∂φ = νε/φ` and on the loop
of `SRC` Theorem 34 not being applied — see
`Corollary40c_one_sided_flow_leaves_no_root` and
`Theorem40d_loop_correction_removes_epsilon`. -/
theorem Theorem44_O2_closes
    (A phiM phiXv dphiXdnu nu eps : ℝ)
    (hA : 0 < A) (hM : phiM < 1) (hX : phiXv < 1) (hm : (1 - phiM) * (1 - phiXv) < 1)
    (hb : 0 < dphiXdnu) (hnu : 0 < nu) (heps : eps < 0) :
    StrictMonoOn (fun t => MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu
        (dnudtauRouteII nu eps (MevTaxControl.phiTotal phiM phiXv t) phiM phiXv))
      (Set.Icc (0:ℝ) 1) := by
  have hall : ∀ t ∈ Set.Icc (0:ℝ) 1,
      HasDerivAt (fun s => MevTaxProgram.totalDeriv A phiM s phiXv dphiXdnu
          (dnudtauRouteII nu eps (MevTaxControl.phiTotal phiM phiXv s) phiM phiXv))
        (-(A * (1 - phiM) ^ 2 * (1 - phiXv) * dphiXdnu * nu * eps /
            MevTaxControl.phiTotal phiM phiXv t ^ 2)) t ∧
      0 < -(A * (1 - phiM) ^ 2 * (1 - phiXv) * dphiXdnu * nu * eps /
            MevTaxControl.phiTotal phiM phiXv t ^ 2) := by
    intro t ht
    exact Theorem44_second_order_endogenous_fee A phiM phiXv dphiXdnu nu eps t hA hM hX hb hnu
      heps (ne_of_gt (phiTotal_pos_on_unit_interval phiM phiXv t hM hX hm ht))
  apply strictMonoOn_of_deriv_pos (convex_Icc 0 1)
  · exact fun y hy => ((hall y hy).1.continuousAt).continuousWithinAt
  · intro t ht
    rw [interior_Icc] at ht
    have htI : t ∈ Set.Icc (0:ℝ) 1 := ⟨le_of_lt ht.1, le_of_lt ht.2⟩
    rw [(hall t htI).1.deriv]
    exact (hall t htI).2

end MevTaxReturns
