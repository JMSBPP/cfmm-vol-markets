import Mathlib
import RequestProject.MevTaxProgram
import RequestProject.MevShockInput

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M42 — the explicit gate derivative (Theorem 54)

`SRC` Rule 13 fixes `φ_X = Φ(Θ_φ; σ(i(t)), ν(t))` with `Φ` the closed-form
schedule of `DOC` Definition 18, already formalized in this project as
`MevTaxProgram.feeLevel` (volatility surcharge `MevTaxProgram.volSurcharge`
times the utilization gate `MevTaxProgram.gateFactor`, the gate value `u` of
`DOC` Theorem 1).  Its `ν`-derivative is `MevTaxProgram.dphidnuBoxed`, proved to
be the derivative in `MevTaxProgram.hasDerivAt_feeLevel_nu` — nothing of that is
redone here.

This module carries **M42 / Theorem 54**:

* (a) the closed form `∂φ_X/∂ν = γ_R(φ_X - φ̄)(1 - u/α_R)`, and the composed
  form of `SRC` Convention 9, `∂φ/∂ν = (1-φ_M)(1-τ_MEV)·∂φ_X/∂ν`
  (**ban 4**: the two slots are kept apart everywhere);
* (b) the first guard conjunct of `SRC` Proposition 13 as a **theorem**, and
  what happens to `τ*_law` at gate saturation;
* (c) the second guard conjunct: `∂ν/∂φ < 0` on `SRC` Theorem 36's
  participation region (from `MevTaxShock.dgOfRatio_phi_neg`), the bare chain to
  `∂ν/∂τ_MEV < 0` through `MevTaxControl.Theorem29_monoid_path_is_direct`, and
  the behaviour of the sign under the feedback loop `ℱ_{φ→ν→φ}` of
  `SRC` Theorem 37;
* (d) the uniform bound `∂φ_X/∂ν ≤ (γ_R α_R/4)·∑_j α_j`.
-/

namespace MevTaxGate

open MevTaxProgram

/-! ## The gate value `u` of `DOC` Theorem 1 -/

/-- The gate value is strictly positive for a positive envelope `α_R`. -/
lemma gateFactor_pos (alphaR gammaR betaR nu : ℝ) (hR : 0 < alphaR) :
    0 < gateFactor alphaR gammaR betaR nu := by
  unfold gateFactor
  have : (0:ℝ) < 1 + Real.exp (gammaR * (betaR - nu)) := by positivity
  positivity

/-- The gate value is **strictly** below the fee envelope `α_R` at every finite
utilization: `DOC` Theorem 1's envelope is approached, never attained. -/
lemma gateFactor_lt_alphaR (alphaR gammaR betaR nu : ℝ) (hR : 0 < alphaR) :
    gateFactor alphaR gammaR betaR nu < alphaR := by
  unfold gateFactor
  have hE : 0 < Real.exp (gammaR * (betaR - nu)) := Real.exp_pos _
  have hden : (0:ℝ) < 1 + Real.exp (gammaR * (betaR - nu)) := by positivity
  rw [div_lt_iff₀ hden]
  nlinarith

/-- `φ_X - φ̄ = (∑_j α_j Λ_j)·u`: the schedule's surcharge times the gate. -/
lemma feeLevel_sub_phibar (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu : ℝ) :
    feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar
      = volSurcharge n γ β α σ * gateFactor alphaR gammaR betaR nu := by
  unfold feeLevel; ring

/-! ## Theorem 54(a) — the closed form, bare and composed -/

/-- **Theorem 54(a) [M42] — the closed form of the gate derivative, verified.**
Under `DOC` Definition 18 (`MevTaxProgram.feeLevel`), with `u` the gate value of
`DOC` Theorem 1 (`MevTaxProgram.gateFactor`),

`∂φ_X/∂ν = (∑_j α_j/(1+e^{γ_j(β_j-σ)}))·γ_R·u·(1-u/α_R) = γ_R(φ_X-φ̄)(1-u/α_R)`,

and this expression **is** the derivative (the boxed form of
`ENTRY_POINT_dphi_dnu.md`, `MevTaxProgram.dphidnuBoxed`, restated in the gate
value).  The author's hand form is confirmed. -/
theorem Theorem54a_gate_derivative_closed_form (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu : ℝ) (hR : alphaR ≠ 0) :
    dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
        = volSurcharge n γ β α σ * (gammaR * gateFactor alphaR gammaR betaR nu *
            (1 - gateFactor alphaR gammaR betaR nu / alphaR))
      ∧ dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
        = gammaR * (feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar) *
            (1 - gateFactor alphaR gammaR betaR nu / alphaR)
      ∧ HasDerivAt (fun v => feeLevel n γ β α phibar σ alphaR gammaR betaR v)
          (gammaR * (feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar) *
            (1 - gateFactor alphaR gammaR betaR nu / alphaR)) nu := by
  have hden : (0:ℝ) < 1 + Real.exp (gammaR * (betaR - nu)) := by positivity
  have h1 : dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
      = volSurcharge n γ β α σ * (gammaR * gateFactor alphaR gammaR betaR nu *
          (1 - gateFactor alphaR gammaR betaR nu / alphaR)) := by
    unfold dphidnuBoxed gateFactor
    field_simp
    ring
  have h2 : dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
      = gammaR * (feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar) *
          (1 - gateFactor alphaR gammaR betaR nu / alphaR) := by
    rw [h1, feeLevel_sub_phibar]; ring
  exact ⟨h1, h2, h2 ▸ hasDerivAt_feeLevel_nu n γ β α phibar σ alphaR gammaR betaR nu⟩

/-- **Theorem 54(a) [M42] — the composed form of `SRC` Convention 9.**  The
**composed** gate derivative carries the monoid Jacobian explicitly:

`∂φ/∂ν = ∂φ/∂φ_X · ∂φ_X/∂ν = (1-φ_M)(1-τ_MEV)·γ_R(φ_X-φ̄)(1-u/α_R)`,

and that product is the derivative of the *composed* fee
`MevTaxControl.phiTotal` in the utilization.  This is **ban 4**'s distinction:
`MevTaxProgram.hasDerivAt_phiTot`'s slot is the bare `∂φ_X/∂ν`, this one is not. -/
theorem Theorem54a_composed_form (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu phiM tau : ℝ) (hR : alphaR ≠ 0) :
    HasDerivAt (fun v => MevTaxControl.phiTotal phiM
        (feeLevel n γ β α phibar σ alphaR gammaR betaR v) tau)
      ((1 - phiM) * (1 - tau) *
        (gammaR * (feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar) *
          (1 - gateFactor alphaR gammaR betaR nu / alphaR))) nu := by
  obtain ⟨-, -, hd⟩ :=
    Theorem54a_gate_derivative_closed_form n γ β α phibar σ alphaR gammaR betaR nu hR
  have hfun : (fun v => MevTaxControl.phiTotal phiM
      (feeLevel n γ β α phibar σ alphaR gammaR betaR v) tau)
      = fun v => 1 - (1 - phiM) * (1 - feeLevel n γ β α phibar σ alphaR gammaR betaR v)
          * (1 - tau) := by
    funext v; rw [MevTaxControl.phiTotal_eq]
  rw [hfun]
  have h1 := ((hd.const_sub 1).const_mul (1 - phiM)).mul_const (1 - tau)
  have h2 := h1.const_sub 1
  convert h2 using 1
  ring

/-! ## Theorem 54(b) — the first guard conjunct is a theorem -/

/-- **Theorem 54(b) [M42] — `SRC` Proposition 13's first guard conjunct is a
THEOREM under Rule 13.**  For a responsive gate (`α_R > 0`, `γ_R > 0`),

`0 < ∂φ_X/∂ν  ⟺  φ̄ < φ_X  ∧  u < α_R`,

the second conjunct being automatic (`gateFactor_lt_alphaR`): the state is
always in the strict interior of `DOC` Theorem 1's fee envelope.  So the guard
reduces to a **protocol-known** inequality on the schedule, not a behavioral
assumption. -/
theorem Theorem54b_first_guard_conjunct (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu : ℝ) (hR : 0 < alphaR) (hg : 0 < gammaR) :
    (0 < dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
        ↔ (phibar < feeLevel n γ β α phibar σ alphaR gammaR betaR nu
            ∧ gateFactor alphaR gammaR betaR nu < alphaR))
      ∧ gateFactor alphaR gammaR betaR nu < alphaR
      ∧ 0 < gateFactor alphaR gammaR betaR nu := by
  have hu : 0 < gateFactor alphaR gammaR betaR nu := gateFactor_pos _ _ _ _ hR
  have hlt : gateFactor alphaR gammaR betaR nu < alphaR := gateFactor_lt_alphaR _ _ _ _ hR
  have hsub : feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar
      = volSurcharge n γ β α σ * gateFactor alphaR gammaR betaR nu :=
    feeLevel_sub_phibar n γ β α phibar σ alphaR gammaR betaR nu
  have hbox : dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
      = volSurcharge n γ β α σ * (gammaR * gateFactor alphaR gammaR betaR nu *
          (1 - gateFactor alphaR gammaR betaR nu / alphaR)) :=
    (Theorem54a_gate_derivative_closed_form n γ β α phibar σ alphaR gammaR betaR nu hR.ne').1
  have hfac : 0 < gammaR * gateFactor alphaR gammaR betaR nu *
      (1 - gateFactor alphaR gammaR betaR nu / alphaR) := by
    have h1 : gateFactor alphaR gammaR betaR nu / alphaR < 1 := (div_lt_one hR).mpr hlt
    have h2 : 0 < 1 - gateFactor alphaR gammaR betaR nu / alphaR := by linarith
    positivity
  refine ⟨?_, hlt, hu⟩
  constructor
  · intro h
    refine ⟨?_, hlt⟩
    have hS : 0 < volSurcharge n γ β α σ := by
      rw [hbox] at h
      by_contra hcon
      push_neg at hcon
      nlinarith
    have : 0 < feeLevel n γ β α phibar σ alphaR gammaR betaR nu - phibar := by
      rw [hsub]; positivity
    linarith
  · rintro ⟨hphi, -⟩
    have hS : 0 < volSurcharge n γ β α σ := by
      have hp : 0 < volSurcharge n γ β α σ * gateFactor alphaR gammaR betaR nu := by
        rw [← hsub]; linarith
      by_contra hcon
      push_neg at hcon
      nlinarith
    rw [hbox]
    positivity

/-- Gate saturation `u ∈ {0, α_R}` is an **unattained limit**: `u → 0` as the
utilization falls without bound and `u → α_R` as it grows without bound
(`γ_R > 0`), while `0 < u < α_R` at every finite `ν`. -/
theorem Theorem54b_saturation_is_a_limit (alphaR gammaR betaR : ℝ)
    (hR : 0 < alphaR) (hg : 0 < gammaR) :
    Filter.Tendsto (fun v => gateFactor alphaR gammaR betaR v) Filter.atBot (nhds 0)
      ∧ Filter.Tendsto (fun v => gateFactor alphaR gammaR betaR v) Filter.atTop (nhds alphaR)
      ∧ ∀ v : ℝ, 0 < gateFactor alphaR gammaR betaR v ∧
          gateFactor alphaR gammaR betaR v < alphaR := by
  have harg_bot : Filter.Tendsto (fun v : ℝ => gammaR * (betaR - v)) Filter.atBot
      Filter.atTop :=
    Filter.tendsto_atTop.mpr (fun b => by
      filter_upwards [Filter.eventually_le_atBot (betaR - b / gammaR)] with v hv
      have hle : b / gammaR ≤ betaR - v := by linarith
      have : gammaR * (b / gammaR) ≤ gammaR * (betaR - v) :=
        mul_le_mul_of_nonneg_left hle hg.le
      rw [mul_div_cancel₀ _ hg.ne'] at this
      linarith)
  have harg_top : Filter.Tendsto (fun v : ℝ => gammaR * (betaR - v)) Filter.atTop
      Filter.atBot :=
    Filter.tendsto_atBot.mpr (fun b => by
      filter_upwards [Filter.eventually_ge_atTop (betaR - b / gammaR)] with v hv
      have hle : betaR - v ≤ b / gammaR := by linarith
      have : gammaR * (betaR - v) ≤ gammaR * (b / gammaR) :=
        mul_le_mul_of_nonneg_left hle hg.le
      rw [mul_div_cancel₀ _ hg.ne'] at this
      linarith)
  refine ⟨?_, ?_, fun v => ⟨gateFactor_pos _ _ _ _ hR, gateFactor_lt_alphaR _ _ _ _ hR⟩⟩
  · have hE : Filter.Tendsto (fun v : ℝ => 1 + Real.exp (gammaR * (betaR - v)))
        Filter.atBot Filter.atTop :=
      Filter.tendsto_atTop_add_const_left _ 1 (Real.tendsto_exp_atTop.comp harg_bot)
    have := hE.inv_tendsto_atTop
    have h2 := this.const_mul alphaR
    simpa [gateFactor, div_eq_mul_inv] using h2
  · have hE : Filter.Tendsto (fun v : ℝ => 1 + Real.exp (gammaR * (betaR - v)))
        Filter.atTop (nhds 1) := by
      have := Real.tendsto_exp_atBot.comp harg_top
      simpa using this.const_add 1
    have := (tendsto_const_nhds (x := alphaR) (f := Filter.atTop (α := ℝ))).div hE one_ne_zero
    simpa [gateFactor] using this

/-- **Theorem 54(b) [M42] — what happens to `τ*_law` at gate saturation.**  If
the gate derivative vanishes (`∂φ_X/∂ν = 0`, the saturation limit), then with
`φ_X < 1` and `A(1-φ_M) ≠ 0` the total derivative of `SRC` Proposition 13's
objective is **nowhere zero**: the FOC has *no* root at all, at any tax.  The
law's own formula returns the boundary value `τ = 1` (Lean's `x/0 = 0`
convention), which is not a stationary point either.  So at saturation
Proposition 13's law does not "degenerate to a value" — it ceases to have a
solution, and the constrained optimum is the corner. -/
theorem Theorem54b_law_degenerates_at_saturation
    (A phiM phiXv dnudtau : ℝ) (hA : A ≠ 0) (hM : phiM ≠ 1) (hX : phiXv < 1) :
    (∀ tau : ℝ, totalDeriv A phiM tau phiXv 0 dnudtau ≠ 0)
      ∧ 1 + (1 - phiXv) / (0 * dnudtau) = 1 := by
  constructor
  · intro tau h
    rw [totalDeriv_eq_core] at h
    rcases mul_eq_zero.mp h with h1 | h1
    · rcases mul_eq_zero.mp h1 with h2 | h2
      · exact hA h2
      · exact hM (by linarith [sub_eq_zero.mp h2])
    · rw [focCore] at h1
      simp at h1
      linarith
  · simp

/-! ## Theorem 54(c) — the second guard conjunct, and the feedback loop -/

/-- **Theorem 54(c) [M42], step 1 — `∂ν/∂φ < 0` on the participation region.**
`SRC` Theorem 36's utilization `ν = |u^m - u^{-m}|`, `u = (1+Δp/p)(1-φ)`,
`m = 1/(2|ε_{p/X}|)`, is strictly decreasing in the composed fee on the
participation region `(1+Δp/p)(1-φ) > 1`.  Both the derivative and its sign are
`MevTaxShock.hasDerivAt_gOfRatio_phi` / `MevTaxShock.dgOfRatio_phi_neg`; nothing
is re-derived. -/
theorem Theorem54c_dnu_dphi_neg (s phi m : ℝ) (hm : 0 < m) (hphi : phi < 1)
    (hu : 1 < MevTaxShock.bandRatio s phi) :
    ∃ dnudphi : ℝ, HasDerivAt (fun f => MevTaxShock.gOfRatio (MevTaxShock.bandRatio s f) m)
        dnudphi phi ∧ dnudphi < 0 :=
  ⟨_, MevTaxShock.hasDerivAt_gOfRatio_phi s phi m hm hphi hu,
    MevTaxShock.dgOfRatio_phi_neg s phi m hm hphi hu⟩

/-- **Theorem 54(c) [M42], step 2 — the bare chain.**  Composing step 1 with the
**direct** monoid path `∂φ/∂τ_MEV|_{φ_M,φ_X} = (1-φ_M)(1-φ_X) > 0`
(`MevTaxControl.Theorem29_monoid_path_is_direct`, here through
`MevTaxControl.hasDerivAt_phiTotal_tau`) gives the second guard conjunct of
`SRC` Proposition 13 along the bare chain: `∂ν/∂τ_MEV < 0`. -/
theorem Theorem54c_bare_chain_dnudtau_neg (nuOf : ℝ → ℝ) (phiM phiXv tau dnudphi : ℝ)
    (hM : phiM < 1) (hX : phiXv < 1)
    (hnu : HasDerivAt nuOf dnudphi (MevTaxControl.phiTotal phiM phiXv tau))
    (hneg : dnudphi < 0) :
    HasDerivAt (fun t => nuOf (MevTaxControl.phiTotal phiM phiXv t))
        (dnudphi * ((1 - phiM) * (1 - phiXv))) tau
      ∧ dnudphi * ((1 - phiM) * (1 - phiXv)) < 0 := by
  refine ⟨hnu.comp tau (MevTaxControl.hasDerivAt_phiTotal_tau phiM phiXv tau), ?_⟩
  have h1 : 0 < (1 - phiM) * (1 - phiXv) := by
    have : (0:ℝ) < 1 - phiM := by linarith
    have : (0:ℝ) < 1 - phiXv := by linarith
    positivity
  exact mul_neg_of_neg_of_pos hneg h1

/-- `SRC` Theorem 37's feedback factor
`ℱ_{φ→ν→φ} = 1 - (∂ν/∂φ)(1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)`.  Note the **composed**
slot: the monoid Jacobian is carried explicitly (ban 4). -/
noncomputable def feedback (phiM tau dnudphi dphiXdnu : ℝ) : ℝ :=
  1 - dnudphi * ((1 - phiM) * (1 - tau) * dphiXdnu)

/-- With the two guard signs of Theorem 54(b)–(c) the feedback factor is
`> 1`: the loop is **damping**, never resonant. -/
lemma feedback_gt_one (phiM tau dnudphi dphiXdnu : ℝ)
    (hM : phiM < 1) (htau : tau < 1) (hnu : dnudphi < 0) (hgate : 0 < dphiXdnu) :
    1 < feedback phiM tau dnudphi dphiXdnu := by
  unfold feedback
  have h1 : (0:ℝ) < 1 - phiM := by linarith
  have h2 : (0:ℝ) < 1 - tau := by linarith
  have : 0 < (1 - phiM) * (1 - tau) * dphiXdnu := by positivity
  nlinarith

/-- **The loop resolution.**  If the utilization is generated by the composed
fee (Rule 13's `ν(t)` read through `SRC` Theorem 36, so that
`dν/dτ = (∂ν/∂φ)·dφ/dτ` with the *same* `dφ/dτ` that the gate feeds back into),
then the total fee response solves the self-consistency equation and equals
`(1-φ_M)(1-φ_X)/ℱ_{φ→ν→φ}` — `SRC` Theorem 37's identity. -/
lemma loop_total_dphi_dtau (phiM phiXv tau dnudphi dphiXdnu dphidtau : ℝ)
    (hself : dphidtau
      = (1 - phiM) * ((1 - phiXv) + (1 - tau) * (dphiXdnu * (dnudphi * dphidtau)))) :
    dphidtau * feedback phiM tau dnudphi dphiXdnu = (1 - phiM) * (1 - phiXv) := by
  unfold feedback
  nlinarith [hself]

/-- **Theorem 54(c) [M42] — the sign SURVIVES the loop.**  Under the two guard
signs, the loop-resolved total fee response is strictly positive and the
loop-resolved total utilization response is strictly negative:

`dφ/dτ_MEV = (1-φ_M)(1-φ_X)/ℱ > 0`,  `dν/dτ_MEV = (∂ν/∂φ)·dφ/dτ_MEV < 0`.

So `SRC` Proposition 13's second guard conjunct holds not only along the bare
chain but for the **total** derivative through `ℱ_{φ→ν→φ}`.  The obstruction is
elsewhere — see `MevLawEquating.Theorem53b_generically_false`: the same identity
that preserves the sign makes the FOC core strictly positive, so the law it
guards has no root in the price-shock-only model. -/
theorem Theorem54c_sign_survives_the_loop (phiM phiXv tau dnudphi dphiXdnu dphidtau : ℝ)
    (hM : phiM < 1) (hX : phiXv < 1) (htau : tau < 1)
    (hnu : dnudphi < 0) (hgate : 0 < dphiXdnu)
    (hself : dphidtau
      = (1 - phiM) * ((1 - phiXv) + (1 - tau) * (dphiXdnu * (dnudphi * dphidtau)))) :
    1 < feedback phiM tau dnudphi dphiXdnu
      ∧ dphidtau = (1 - phiM) * (1 - phiXv) / feedback phiM tau dnudphi dphiXdnu
      ∧ 0 < dphidtau
      ∧ dnudphi * dphidtau < 0 := by
  have hF : 1 < feedback phiM tau dnudphi dphiXdnu :=
    feedback_gt_one phiM tau dnudphi dphiXdnu hM htau hnu hgate
  have hFne : feedback phiM tau dnudphi dphiXdnu ≠ 0 := by linarith
  have hid := loop_total_dphi_dtau phiM phiXv tau dnudphi dphiXdnu dphidtau hself
  have heq : dphidtau = (1 - phiM) * (1 - phiXv) / feedback phiM tau dnudphi dphiXdnu := by
    field_simp
    linarith [hid]
  have hnum : 0 < (1 - phiM) * (1 - phiXv) := by
    have h1 : (0:ℝ) < 1 - phiM := by linarith
    have h2 : (0:ℝ) < 1 - phiXv := by linarith
    positivity
  have hpos : 0 < dphidtau := by
    rw [heq]; exact div_pos hnum (by linarith)
  exact ⟨hF, heq, hpos, mul_neg_of_neg_of_pos hnu hpos⟩

/-! ## Theorem 54(d) — the uniform bound for fixed-point arithmetic -/

/-- **Theorem 54(d) [M42] — the uniform bound.**  For `α_j ≥ 0`, `α_R ≥ 0`,
`γ_R ≥ 0`,

`∂φ_X/∂ν ≤ (γ_R α_R/4)·∑_j α_j`,

the sigmoid factor `e^z/(1+e^z)² ≤ 1/4` being attained exactly at `u = α_R/2`
and the surcharge being bounded by `∑_j α_j` (approached as `σ → ∞`).  This is
the constant an EVM fixed-point implementation must scale against. -/
theorem Theorem54d_uniform_bound (n : ℕ) (γ β α : ℕ → ℝ)
    (σ alphaR gammaR betaR nu : ℝ) (hR : 0 ≤ alphaR) (hg : 0 ≤ gammaR)
    (halpha : ∀ j, 0 ≤ α j) :
    dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
      ≤ gammaR * alphaR / 4 * ∑ j ∈ Finset.range n, α j := by
  have hE : 0 < Real.exp (gammaR * (betaR - nu)) := Real.exp_pos _
  have hden : (0:ℝ) < (1 + Real.exp (gammaR * (betaR - nu))) ^ 2 := by positivity
  have hsig : Real.exp (gammaR * (betaR - nu)) / (1 + Real.exp (gammaR * (betaR - nu))) ^ 2
      ≤ 1 / 4 := by
    rw [div_le_div_iff₀ hden (by norm_num)]
    nlinarith [sq_nonneg (1 - Real.exp (gammaR * (betaR - nu)))]
  have hsig0 : 0 ≤ Real.exp (gammaR * (betaR - nu)) /
      (1 + Real.exp (gammaR * (betaR - nu))) ^ 2 := by positivity
  have hS0 : 0 ≤ volSurcharge n γ β α σ := volSurcharge_nonneg n γ β α σ halpha
  have hSle : volSurcharge n γ β α σ ≤ ∑ j ∈ Finset.range n, α j :=
    volSurcharge_le n γ β α σ halpha
  unfold dphidnuBoxed
  have hc : 0 ≤ alphaR * gammaR := by positivity
  calc alphaR * gammaR * volSurcharge n γ β α σ *
        (Real.exp (gammaR * (betaR - nu)) / (1 + Real.exp (gammaR * (betaR - nu))) ^ 2)
      ≤ alphaR * gammaR * volSurcharge n γ β α σ * (1 / 4) := by
        exact mul_le_mul_of_nonneg_left hsig (by positivity)
    _ ≤ alphaR * gammaR * (∑ j ∈ Finset.range n, α j) * (1 / 4) := by
        have : alphaR * gammaR * volSurcharge n γ β α σ
            ≤ alphaR * gammaR * ∑ j ∈ Finset.range n, α j :=
          mul_le_mul_of_nonneg_left hSle hc
        linarith
    _ = gammaR * alphaR / 4 * ∑ j ∈ Finset.range n, α j := by ring

/-- The bound of Theorem 54(d) is **attained in the limit**: at `u = α_R/2`
(i.e. `ν = β_R`) the sigmoid factor is exactly `1/4`, so the gate derivative
equals `(γ_R α_R/4)·(∑_j α_j Λ_j(σ))` there — only the surcharge's own bound
`∑_j α_j` is a limit (`σ → ∞`). -/
theorem Theorem54d_bound_attained (n : ℕ) (γ β α : ℕ → ℝ)
    (σ alphaR gammaR : ℝ) :
    gateFactor alphaR gammaR (0:ℝ) 0 = alphaR / 2
      ∧ dphidnuBoxed n γ β α σ alphaR gammaR 0 0
        = gammaR * alphaR / 4 * volSurcharge n γ β α σ := by
  constructor
  · unfold gateFactor; norm_num
  · unfold dphidnuBoxed; norm_num; ring

end MevTaxGate
