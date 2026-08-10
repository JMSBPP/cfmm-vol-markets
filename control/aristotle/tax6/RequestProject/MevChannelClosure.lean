import Mathlib
import RequestProject.MevLVRCancellation

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M26–M27 — the two channels to `∂ν/∂τ_MEV`, and arb-side closure

This module formalizes blocks **M26** (Theorem 38 (a)–(d)) and **M27**
(Theorem 39) of `TAX3_ADDENDUM.md`.

Cited, never redone:

* `MevTaxControl.Theorem29_monoid_path_is_direct` (`MevTaxControl.lean`) —
  `∂φ/∂τ_MEV|_{φ_M,φ_X} = (1-φ_M)(1-φ_X) > 0`;
* `MevTaxControl.Theorem32_hazard_strictAntiOn_tau`,
  `MevTaxControl.tau_to_nu_strictAntiOn_under_H2` (`MevTaxControl.lean`);
* `MevTaxControl.H2_dnu_dlamMEV_pos` — a **typed hypothesis**, never proved;
* `MevTaxProgram.dnudtau_nonpos_of_strictAntiOn`,
  `MevTaxProgram.dnudtau_strict_negativity_is_an_extra_hypothesis`
  (`MevTaxProgram.lean`);
* `MevTaxLVR.hasDerivAt_ptrade_phi` (`MevLVRCancellation.lean`), the closed form
  of `∂ℙ_{Δ_ARB}/∂φ`.

**Verdicts returned by this module.**

* **38(a) is FALSE as stated and TRUE on a restricted flow domain.**  The
  numerator of `ν` is `DOC` Rule 5's member `φ_{(1/2,0)}`, the geometric mean.
  Along a scaling ray of a flow with **both legs strictly positive** it is
  strictly increasing (`Theorem38a_flow_scaling_strictly_increases_nu`) — the
  property used is 1-homogeneity together with strict positivity of the trading
  function at the flow direction.  For a **one-sided** flow (`ΔQ_M = 0`) the
  geometric mean is identically zero, so `∂ν/∂ΔQ = 0`
  (`Theorem38a_one_sided_flow_refutes_strict_monotonicity`).  Which of these is
  the operative case is the OPEN flow-domain ruling **PR-REGION** (`DOC:423`).
  The `ε_{X/M}`-dependence is sharp: the boundary defect is exactly the
  `ε_{X/M} ≤ 0` phenomenon, and Rule 5's operative member is `ε_{X/M} = 0`
  (`Theorem38a_boundary_behaviour_is_epsilon_dependent`).
* **38(b), (c) hold** (`Theorem38b_route_two_sign`,
  `Theorem38c_routes_agree_in_sign`); the hazard route delivers only `≤ 0`
  without an extra strict-negativity hypothesis
  (`Theorem38c_hazard_route_only_nonpos`).
* **38(d): route (ii) genuinely does not use (H2)** — but what replaces it,
  `RouteIIPremise` = (`∂ν/∂ΔQ > 0` and `∂ΔQ/∂φ < 0`), is **logically
  independent** of (H2), not weaker
  (`Theorem38d_replacement_is_independent_of_H2`).  `∂ΔQ/∂φ` on total flow
  contains the benign demand slope, which `DOC`'s `[M8]` records as absent
  ("NO DEMAND ELASTICITY").
* **The two routes are not a decomposition of one another, and the total is not
  the plain sum**: run simultaneously they close a loop
  `φ → ΔQ → ν → φ`, and the total is the naive sum divided by `1 -` loop gain.
  Under the M26 signs the loop gain is negative, so the sign is preserved but
  the plain sum **overstates the magnitude**
  (`Theorem38_two_routes_close_a_loop`).
* **Theorem 39 is REFUTED.**  `∂ΔQ^{ARB}/∂φ` is a *level*, 1-homogeneous in the
  pool scale, while `(σ, φ, Δt, ε_{p/X})` are all scale-free; so no closed form
  in those four exists unless the response is identically zero
  (`Theorem39_arb_side_does_not_close`).  **The missing primitive is the pool
  scale** — the reserve level `L` (equivalently `π^{varphi}`, `DOC` Definition
  25), a level and not an elasticity.  What *does* close is the scale-free part:
  the participation probability and its fee-derivative
  (`Theorem39_participation_closes`) and the fee **elasticity** of arb flow
  (`Theorem39_elasticity_closes`).
-/

namespace MevTaxChannels

/-! ## M26(a). The utilization ratio and the flow -/

/-- `DOC` Rule 5's trading-function member `φ_{(1/2,0)}` — the `χ_{X/M} = 1/2`,
`ε_{X/M} = 0` member of `DOC` Definition 13's CES family, i.e. the geometric
mean.  (The `varphi` glyph is the *trading function*; it is not the fee `φ`.) -/
noncomputable def varphiHalfZero (qX qM : ℝ) : ℝ := Real.sqrt (qX * qM)

/-- The utilization ratio `ν = φ_{(1/2,0)}(i_K; ΔQ, 0; t) / φ_{(1/2,0)}(i_K; 0, L; t)`
of `DOC` Theorem 1's gate argument, with the denominator (the endowment
evaluation) carried as a positive constant of the flow. -/
noncomputable def nuRatio (qX qM den : ℝ) : ℝ := varphiHalfZero qX qM / den

/-- 1-homogeneity of the trading function along a scaling of the flow. -/
lemma varphiHalfZero_smul (s aX aM : ℝ) (hs : 0 ≤ s) :
    varphiHalfZero (s * aX) (s * aM) = s * varphiHalfZero aX aM := by
  unfold varphiHalfZero
  rw [show s * aX * (s * aM) = s ^ 2 * (aX * aM) by ring, Real.sqrt_mul (by positivity),
    Real.sqrt_sq hs]

/-- **Theorem 38(a) [M26], the positive half.**  Scale the flow along a
direction `(a_X, a_M)` with **both legs strictly positive**.  Then the
utilization is strictly increasing in the flow: its derivative in the scale is
`φ_{(1/2,0)}(a_X,a_M)/den > 0`.

**The property required** is exactly: 1-homogeneity of the trading function in
the flow argument, together with its strict positivity at the flow direction.
`DOC` Definition 13's CES family supplies 1-homogeneity for every
`ε_{X/M}`; strict positivity at the direction is what fails on the boundary of
the flow orthant for the operative member — see the refutation below. -/
theorem Theorem38a_flow_scaling_strictly_increases_nu
    (aX aM den s : ℝ) (hX : 0 < aX) (hM : 0 < aM) (hden : 0 < den) (hs : 0 < s) :
    HasDerivAt (fun r => nuRatio (r * aX) (r * aM) den)
        (varphiHalfZero aX aM / den) s ∧
      0 < varphiHalfZero aX aM / den := by
  have hpos : 0 < varphiHalfZero aX aM := by
    unfold varphiHalfZero
    exact Real.sqrt_pos.mpr (by positivity)
  have hlin : HasDerivAt (fun r : ℝ => r * varphiHalfZero aX aM / den)
      (varphiHalfZero aX aM / den) s := by
    have h := ((hasDerivAt_id s).mul_const (varphiHalfZero aX aM)).div_const den
    simpa using h
  refine ⟨?_, div_pos hpos hden⟩
  have heq : (fun r : ℝ => r * varphiHalfZero aX aM / den)
      =ᶠ[nhds s] fun r => nuRatio (r * aX) (r * aM) den := by
    filter_upwards [isOpen_Ioi.mem_nhds (Set.mem_Ioi.mpr hs)] with r hr
    unfold nuRatio
    rw [varphiHalfZero_smul r aX aM (le_of_lt hr)]
  exact hlin.congr_of_eventuallyEq heq.symm

/-- **Theorem 38(a) [M26] is FALSE as stated: the one-sided flow.**  On a
one-legged flow (`ΔQ_M = 0`) the operative member `φ_{(1/2,0)}` — the geometric
mean — is identically zero, so the utilization does not respond to the flow at
all: `∂ν/∂ΔQ = 0`, not `> 0`.  Witness: `a_M = 0`, any `a_X`, any positive
denominator. -/
theorem Theorem38a_one_sided_flow_refutes_strict_monotonicity :
    ¬ (∀ (aX aM den s : ℝ), 0 < den → 0 < s → 0 ≤ aX → 0 ≤ aM →
        ∃ d : ℝ, 0 < d ∧ HasDerivAt (fun r => nuRatio (r * aX) (r * aM) den) d s) := by
  intro h
  obtain ⟨d, hd, hderiv⟩ := h 1 0 1 1 one_pos one_pos zero_le_one le_rfl
  have hfun : (fun r : ℝ => nuRatio (r * 1) (r * 0) 1) = fun _ : ℝ => (0 : ℝ) := by
    funext r
    simp [nuRatio, varphiHalfZero]
  rw [hfun] at hderiv
  have := hderiv.unique (hasDerivAt_const (1 : ℝ) (0 : ℝ))
  exact absurd this (ne_of_gt hd)

/-- `DOC` Definition 13's CES family, both branches: `ε_{X/M} = 0` is a
**defined case**, not an evaluation. -/
noncomputable def varphiCES (chi eps qX qM : ℝ) : ℝ :=
  if eps = 0 then qX ^ chi * qM ^ (1 - chi)
  else (chi * qX ^ eps + (1 - chi) * qM ^ eps) ^ (1 / eps)

/-- The `(χ_{X/M}, ε_{X/M}) = (1/2, 0)` member is `varphiHalfZero`, the
geometric mean (`DOC` Rule 5). -/
lemma varphiCES_half_zero (qX qM : ℝ) (hX : 0 ≤ qX) (hM : 0 ≤ qM) :
    varphiCES (1 / 2) 0 qX qM = varphiHalfZero qX qM := by
  unfold varphiCES varphiHalfZero
  rw [Real.sqrt_eq_rpow, Real.mul_rpow hX hM]
  norm_num

/-- **Theorem 38(a), the `ε_{X/M}`-dependence [M26].**  The boundary defect that
refutes 38(a) is a property of the **substitution axis**, not an accident:

* for `ε_{X/M} > 0` the CES member is **strictly increasing** in the `Q_X` leg
  even when the other leg is `0` — it is linear there, with slope
  `χ_{X/M}^{1/ε_{X/M}} > 0`;
* for `ε_{X/M} = 0` — Rule 5's **operative** member — it vanishes identically on
  that boundary.

So `DOC` Definition 13's family supplies 38(a)'s premise on the boundary only
away from the Cobb–Douglas slice, and the pool actually in use sits on that
slice.  (No identification of `ε_{X/M}` with any other curvature axis is made or
used; the CES family is the only carrier here.) -/
theorem Theorem38a_boundary_behaviour_is_epsilon_dependent
    (chi eps : ℝ) (hchi : 0 < chi) (hchi1 : chi < 1) (heps : 0 < eps) :
    (∀ qX : ℝ, 0 ≤ qX → varphiCES chi eps qX 0 = chi ^ (1 / eps) * qX) ∧
      StrictMonoOn (fun qX => varphiCES chi eps qX 0) (Set.Ici 0) ∧
      (∀ qX : ℝ, varphiCES chi 0 qX 0 = 0) := by
  have hepsne : eps ≠ 0 := ne_of_gt heps
  have hkey : ∀ qX : ℝ, 0 ≤ qX → varphiCES chi eps qX 0 = chi ^ (1 / eps) * qX := by
    intro qX hqX
    unfold varphiCES
    rw [if_neg hepsne, Real.zero_rpow hepsne]
    rw [show chi * qX ^ eps + (1 - chi) * 0 = chi * qX ^ eps by ring]
    rw [Real.mul_rpow (le_of_lt hchi) (Real.rpow_nonneg hqX eps), ← Real.rpow_mul hqX,
      mul_one_div, div_self hepsne, Real.rpow_one]
  refine ⟨hkey, ?_, ?_⟩
  · intro a ha b hb hab
    show varphiCES chi eps a 0 < varphiCES chi eps b 0
    rw [hkey a (Set.mem_Ici.mp ha), hkey b (Set.mem_Ici.mp hb)]
    have hc : 0 < chi ^ (1 / eps) := Real.rpow_pos_of_pos hchi _
    exact mul_lt_mul_of_pos_left hab hc
  · intro qX
    unfold varphiCES
    rw [if_pos rfl, Real.zero_rpow (sub_ne_zero.mpr (ne_of_lt hchi1).symm), mul_zero]

/-! ## M26(b)–(d). The two routes -/

/-- **Route (i)** — the hazard channel: `∂ν/∂τ_MEV = Ḡ·∂λ_MEV/∂τ_MEV` with
`Ḡ = ∂ν/∂λ_MEV` the (H2) gain and `∂λ/∂τ < 0` by
`MevTaxControl.Theorem32_hazard_strictAntiOn_tau`. -/
noncomputable def routeI (Gbar dlamdtau : ℝ) : ℝ := Gbar * dlamdtau

/-- **Route (ii)** — the flow channel:
`∂ν/∂τ_MEV = (∂ν/∂ΔQ)(∂ΔQ/∂φ)(∂φ/∂τ_MEV)|_{φ_M,φ_X}`. -/
noncomputable def routeII (dnudQ dQdphi dphidtau : ℝ) : ℝ := dnudQ * dQdphi * dphidtau

/-- The monoid path derivative `(1-φ_M)(1-φ_X)` of
`MevTaxControl.Theorem29_monoid_path_is_direct`. -/
noncomputable def monoidPathDeriv (phiM phiXv : ℝ) : ℝ := (1 - phiM) * (1 - phiXv)

/-- What route (ii) requires **instead of (H2)**: a strictly positive
utilization response to the flow (38(a)) and downward-sloping demand. -/
def RouteIIPremise (dnudQ dQdphi : ℝ) : Prop := 0 < dnudQ ∧ dQdphi < 0

/-- **Theorem 38(b) [M26].**  Under downward-sloping demand `∂ΔQ/∂φ < 0` and
38(a)'s `∂ν/∂ΔQ > 0`, route (ii) gives `∂ν/∂τ_MEV < 0`.  The last factor is the
strictly positive monoid path of
`MevTaxControl.Theorem29_monoid_path_is_direct` (`MevTaxControl.lean`). -/
theorem Theorem38b_route_two_sign (dnudQ dQdphi phiM phiXv : ℝ)
    (hpre : RouteIIPremise dnudQ dQdphi) (hM : phiM < 1) (hX : phiXv < 1) :
    0 < monoidPathDeriv phiM phiXv ∧
      routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv) < 0 := by
  obtain ⟨hQ, hD⟩ := hpre
  have hmono : 0 < (1 - phiM) * (1 - phiXv) :=
    (MevTaxControl.Theorem29_monoid_path_is_direct phiM phiXv 0 hM hX).2.2.1
  refine ⟨hmono, ?_⟩
  unfold routeII monoidPathDeriv
  exact mul_neg_of_neg_of_pos (mul_neg_of_pos_of_neg hQ hD) hmono

/-- **Theorem 38(c) [M26].**  The two routes **agree in sign**: with the (H2)
gain `Ḡ > 0` and `∂λ_MEV/∂τ_MEV < 0`, route (i) is negative; with 38(a) and
downward-sloping demand, route (ii) is negative; and their product is strictly
positive, i.e. they have the same sign. -/
theorem Theorem38c_routes_agree_in_sign
    (Gbar dlamdtau dnudQ dQdphi phiM phiXv : ℝ)
    (hG : 0 < Gbar) (hlam : dlamdtau < 0)
    (hpre : RouteIIPremise dnudQ dQdphi) (hM : phiM < 1) (hX : phiXv < 1) :
    routeI Gbar dlamdtau < 0 ∧
      routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv) < 0 ∧
      0 < routeI Gbar dlamdtau * routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv) := by
  obtain ⟨hmono, hII⟩ := Theorem38b_route_two_sign dnudQ dQdphi phiM phiXv hpre hM hX
  have hI : routeI Gbar dlamdtau < 0 := mul_neg_of_pos_of_neg hG hlam
  exact ⟨hI, hII, mul_pos_of_neg_of_neg hI hII⟩

/-- **Theorem 38(c), the asymmetry [M26].**  Route (i) delivers only `≤ 0`
without an extra hypothesis: `MevTaxControl.Theorem32_hazard_strictAntiOn_tau`
gives strict *antitonicity* of the hazard, which at an interior point yields
`∂λ/∂τ ≤ 0` and no more
(`MevTaxProgram.dnudtau_nonpos_of_strictAntiOn`,
`MevTaxProgram.dnudtau_strict_negativity_is_an_extra_hypothesis`).  Route (ii),
by contrast, is strict from strict primitives (38(b)). -/
theorem Theorem38c_hazard_route_only_nonpos
    (lamOf : ℝ → ℝ) (tauMEV dlamdtau Gbar : ℝ) (hG : 0 ≤ Gbar)
    (hanti : StrictAntiOn lamOf (Set.Icc 0 1))
    (hmem : tauMEV ∈ Set.Ioo (0 : ℝ) 1)
    (hd : HasDerivAt lamOf dlamdtau tauMEV) :
    dlamdtau ≤ 0 ∧ routeI Gbar dlamdtau ≤ 0 := by
  have hle := MevTaxProgram.dnudtau_nonpos_of_strictAntiOn lamOf tauMEV dlamdtau hanti hmem hd
  exact ⟨hle, mul_nonpos_of_nonneg_of_nonpos hG hle⟩

/-- **Theorem 38(c), route (i) reached by name [M26].**  With (H2) —
`MevTaxControl.H2_dnu_dlamMEV_pos`, a typed hypothesis, never discharged — and
the uniform-clearing identification of `λ_MEV` with the taxed arbitrage hazard
(`hclearing`, a modelling assumption), `MevTaxControl.tau_to_nu_strictAntiOn_under_H2`
gives that `τ_MEV ↦ ν(λ_MEV(τ_MEV))` is strictly antitone on the carrier, hence
that route (i)'s value at an interior point is `≤ 0`.  This is the whole of what
the hazard route delivers without a further strict-negativity hypothesis. -/
theorem Theorem38c_route_one_from_H2
    (nu : ℝ → ℝ) (hH2 : MevTaxControl.H2_dnu_dlamMEV_pos nu)
    (n : ℕ) (γ β α : ℕ → ℝ) (phibar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hphibar : 0 ≤ phibar) (halpha : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u)
    (hfee_lt_one : ∀ t < T, VolInstrument.multiFee n γ β α phibar u (σpath t) < 1)
    (ha : ∀ t < T, 0 ≤ a t) (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hD : ∀ t < T, 0 < D t) (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt)
    (lamMEV : ℝ → ℝ)
    (hclearing : ∀ tauMEV,
      lamMEV tauMEV = MevTaxControl.mevMultiTaxed n γ β α phibar u σpath a D Δt T tauMEV)
    (tauMEV dnudtau : ℝ) (htau : tauMEV ∈ Set.Ioo (0 : ℝ) 1)
    (hd : HasDerivAt (fun t => nu (lamMEV t)) dnudtau tauMEV) :
    StrictAntiOn (fun t => nu (lamMEV t)) (Set.Icc 0 1) ∧ dnudtau ≤ 0 := by
  have hanti := MevTaxControl.tau_to_nu_strictAntiOn_under_H2 nu hH2 n γ β α phibar u
    σpath a D Δt T hphibar halpha hu hfee_lt_one ha ha_pos hD hσ hΔt lamMEV hclearing
  exact ⟨hanti, MevTaxProgram.dnudtau_nonpos_of_strictAntiOn (fun t => nu (lamMEV t))
    tauMEV dnudtau hanti htau hd⟩

/-- **Theorem 38(d) [M26].**  Three statements.

1. The sign result of route (ii) is proved with **no (H2) binder**: its
   hypotheses are exactly `RouteIIPremise` and the fee guards
   (this is literally `Theorem38b_route_two_sign`, restated here).
2. `RouteIIPremise` does **not imply** (H2): there is a `ν` violating
   `MevTaxControl.H2_dnu_dlamMEV_pos` (indeed strictly *decreasing* in the
   hazard) alongside a route (ii) that still delivers the negative sign.
3. (H2) does **not imply** `RouteIIPremise`: there is a `ν` satisfying (H2)
   while demand slopes *upward*, and there route (ii) delivers the **opposite**
   sign.

So what replaces (H2) is the pair (`∂ν/∂ΔQ > 0`, `∂ΔQ/∂φ < 0`), and it is
**not weaker** — the two premise sets are logically independent.  In estimation
terms route (ii) trades the behavioural gain `Ḡ` for a demand slope on total
flow, whose benign component `DOC`'s `[M8]` records as missing ("NO DEMAND
ELASTICITY"). -/
theorem Theorem38d_replacement_is_independent_of_H2 :
    (∀ (dnudQ dQdphi phiM phiXv : ℝ), RouteIIPremise dnudQ dQdphi → phiM < 1 → phiXv < 1 →
        routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv) < 0) ∧
      (∃ (nu : ℝ → ℝ) (dnudQ dQdphi : ℝ),
        ¬ MevTaxControl.H2_dnu_dlamMEV_pos nu ∧ RouteIIPremise dnudQ dQdphi ∧
          routeII dnudQ dQdphi (monoidPathDeriv 0 0) < 0) ∧
      (∃ (nu : ℝ → ℝ) (dnudQ dQdphi : ℝ),
        MevTaxControl.H2_dnu_dlamMEV_pos nu ∧ ¬ RouteIIPremise dnudQ dQdphi ∧
          0 < routeII dnudQ dQdphi (monoidPathDeriv 0 0)) := by
  refine ⟨fun dnudQ dQdphi phiM phiXv hpre hM hX =>
    (Theorem38b_route_two_sign dnudQ dQdphi phiM phiXv hpre hM hX).2, ?_, ?_⟩
  · refine ⟨fun x => -x, 1, -1, ?_, ⟨one_pos, by norm_num⟩, by norm_num [routeII, monoidPathDeriv]⟩
    intro hH2
    have h := hH2 0
    rw [show (fun x : ℝ => -x) = fun x : ℝ => -1 * x by funext x; ring] at h
    simp at h
    linarith
  · refine ⟨fun x => x, 1, 1, ?_, ?_, by norm_num [routeII, monoidPathDeriv]⟩
    · intro l; simp
    · rintro ⟨-, h⟩; norm_num at h

/-- **The falsification target of M26, answered: route (ii) is not a
decomposition of route (i), and running both does not give the plain sum.**

If both channels are live, the tax reaches `ν` directly through the hazard and
indirectly through the fee, while the fee itself responds to `ν` through the
Rule 12 monoid and `DOC` Definition 18's gate.  The two unknowns
`P = ∂φ_total/∂τ_MEV` and `N = ∂ν/∂τ_MEV` therefore solve a **linear system**
with a feedback loop `φ → ΔQ → ν → φ`:

`P = (1-φ_M)(1-φ_X) + (1-φ_M)(1-τ)(∂φ_X/∂ν)·N`,
`N = Ḡ·(∂λ/∂τ) + (∂ν/∂ΔQ)(∂ΔQ/∂φ)·P`.

Write `loop = (∂ν/∂ΔQ)(∂ΔQ/∂φ)(1-φ_M)(1-τ)(∂φ_X/∂ν)` (the loop gain) and
`naive = routeI + routeII` (the plain sum).  Then:

1. `(1 - loop)·N = naive` — the total is `naive/(1-loop)`, **not** `naive`;
2. under the M26 signs the loop gain is strictly negative, so `1 - loop > 1`;
3. consequently `naive < N < 0`: adding the two routes gets the **sign right**
   but **overstates the magnitude** — that is exactly the double count. -/
theorem Theorem38_two_routes_close_a_loop
    (P N Gbar dlamdtau dnudQ dQdphi dphiXdnu phiM phiXv tauMEV : ℝ)
    (hP : P = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tauMEV) * dphiXdnu * N)
    (hN : N = Gbar * dlamdtau + dnudQ * dQdphi * P)
    (hG : 0 < Gbar) (hlam : dlamdtau < 0) (hpre : RouteIIPremise dnudQ dQdphi)
    (hgate : 0 < dphiXdnu) (hM : phiM < 1) (hX : phiXv < 1) (htau : tauMEV < 1) :
    (1 - dnudQ * dQdphi * ((1 - phiM) * (1 - tauMEV) * dphiXdnu)) * N
        = routeI Gbar dlamdtau + routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv) ∧
      dnudQ * dQdphi * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) < 0 ∧
      routeI Gbar dlamdtau + routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv) < N ∧
      N < 0 := by
  obtain ⟨hQ, hD⟩ := hpre
  have hloop : dnudQ * dQdphi * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) < 0 := by
    have h1 : dnudQ * dQdphi < 0 := mul_neg_of_pos_of_neg hQ hD
    have h2 : 0 < (1 - phiM) * (1 - tauMEV) * dphiXdnu := by
      have : 0 < (1 - phiM) * (1 - tauMEV) := mul_pos (by linarith) (by linarith)
      exact mul_pos this hgate
    exact mul_neg_of_neg_of_pos h1 h2
  have hsum : routeI Gbar dlamdtau + routeII dnudQ dQdphi (monoidPathDeriv phiM phiXv)
      = Gbar * dlamdtau + dnudQ * dQdphi * ((1 - phiM) * (1 - phiXv)) := by
    unfold routeI routeII monoidPathDeriv; ring
  have hlin : (1 - dnudQ * dQdphi * ((1 - phiM) * (1 - tauMEV) * dphiXdnu)) * N
      = Gbar * dlamdtau + dnudQ * dQdphi * ((1 - phiM) * (1 - phiXv)) := by
    linear_combination hN + dnudQ * dQdphi * hP
  have hnaive_neg : Gbar * dlamdtau + dnudQ * dQdphi * ((1 - phiM) * (1 - phiXv)) < 0 := by
    have h1 : Gbar * dlamdtau < 0 := mul_neg_of_pos_of_neg hG hlam
    have h2 : dnudQ * dQdphi * ((1 - phiM) * (1 - phiXv)) < 0 :=
      mul_neg_of_neg_of_pos (mul_neg_of_pos_of_neg hQ hD)
        (mul_pos (by linarith) (by linarith))
    linarith
  have hden : (1 : ℝ) < 1 - dnudQ * dQdphi * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) := by
    linarith
  have hNneg : N < 0 := by nlinarith
  have hgap : N - (Gbar * dlamdtau + dnudQ * dQdphi * ((1 - phiM) * (1 - phiXv)))
      = dnudQ * dQdphi * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) * N := by
    linear_combination hlin
  refine ⟨by rw [hsum]; exact hlin, hloop, ?_, hNneg⟩
  rw [hsum]
  nlinarith [mul_pos_of_neg_of_neg hloop hNneg]

/-! ## M27. Arb-side closure -/

/-- An **arb-flow model**: the arbitrageur's traded quantity as a function of
the pool **scale** `S` (the reserve level `L`, equivalently `π^{varphi}` of
`DOC` Definition 25) and the four candidate observables
`(σ(i(t)), φ, Δt, ε_{p/X})`. -/
abbrev ArbFlow := ℝ → ℝ → ℝ → ℝ → ℝ → ℝ

/-- **Scale 1-homogeneity of the arb quantity.**  Carried as a typed hypothesis,
never proved here.  Its ground: `DOC` Definition 13's CES family is
1-homogeneous, so rescaling the reserves rescales the trading curve without
moving the marginal price; the no-arb band — hence the arbitrageur's stopping
condition — is therefore scale-free, and the *quantity* he trades to reach it
scales linearly with the reserves.  `ε_{p/X}` is an elasticity and is likewise
scale-free (`DOC` Definition 14). -/
def ScaleHomogeneous (Q : ArbFlow) : Prop :=
  ∀ c S σ φ Δt e : ℝ, Q (c * S) σ φ Δt e = c * Q S σ φ Δt e

/-- `∂ΔQ^{ARB}/∂φ` — the object M27 asks about. -/
noncomputable def dArbFlow_dphi (Q : ArbFlow) (S σ φ Δt e : ℝ) : ℝ :=
  deriv (fun f => Q S σ f Δt e) φ

/-- **Closure in observables**: `∂ΔQ^{ARB}/∂φ` is a function of
`(σ, φ, Δt, ε_{p/X})` alone — no dependence on anything else, in particular no
free behavioural parameter and no pool-level datum. -/
def ClosesInObservables (Q : ArbFlow) : Prop :=
  ∃ F : ℝ → ℝ → ℝ → ℝ → ℝ, ∀ S σ φ Δt e : ℝ, dArbFlow_dphi Q S σ φ Δt e = F σ φ Δt e

/-- **Theorem 39 (Arb-side closure) [M27] — REFUTED.**  For any scale
1-homogeneous arb-flow model, closure of `∂ΔQ^{ARB}/∂φ` in
`(σ, φ, Δt, ε_{p/X})` forces the fee-response to vanish identically.  So a model
with any nonzero fee response does **not** close in those four observables.

The obstruction is dimensional, not asymptotic: `∂ΔQ^{ARB}/∂φ` is a **quantity**
(1-homogeneous in the pool scale) while `σ`, `φ`, `Δt` and the elasticity
`ε_{p/X}` are all **scale-free**.  It is therefore untouched by `[M8]`'s LEADING
ORDER and QUASI-STATIC caveats — neither caveat is what blocks closure. -/
theorem Theorem39_arb_side_does_not_close (Q : ArbFlow) (hhom : ScaleHomogeneous Q) :
    ClosesInObservables Q → ∀ S σ φ Δt e : ℝ, dArbFlow_dphi Q S σ φ Δt e = 0 := by
  rintro ⟨F, hF⟩ S σ φ Δt e
  have hscale : ∀ (c S' : ℝ), dArbFlow_dphi Q (c * S') σ φ Δt e
      = c * dArbFlow_dphi Q S' σ φ Δt e := by
    intro c S'
    unfold dArbFlow_dphi
    have hfun : (fun f => Q (c * S') σ f Δt e) = fun f => c * Q S' σ f Δt e := by
      funext f; exact hhom c S' σ f Δt e
    rw [hfun, deriv_const_mul_field]
  have h2 : F σ φ Δt e = 2 * F σ φ Δt e := by
    have := hscale 2 S
    rw [hF (2 * S) σ φ Δt e, hF S σ φ Δt e] at this
    exact this
  have hF0 : F σ φ Δt e = 0 := by linarith
  rw [hF S σ φ Δt e, hF0]

/-- **Theorem 39, the refutation with a witness [M27].**  Every arb-flow model
of the leading-order product shape `ΔQ^{ARB} = S · h(σ, φ, Δt, ε_{p/X})` — the
scale times a scale-free profile — is scale 1-homogeneous, and it fails to close
as soon as the profile responds to the fee at one point.  A concrete instance is
supplied, so the refuting hypothesis set is not vacuous.

**The named missing primitive: the POOL SCALE** — the reserve level `L`,
equivalently the portfolio value `π^{varphi}` (`DOC` Definition 25).  It is a
*level*, and none of `(σ, φ, Δt, ε_{p/X})` carries one: `ε_{p/X}` is by
construction an elasticity (`DOC` Definition 14, "an observable of any member"),
`σ` and `φ` are rates and fractions, `Δt` a time.  The estimation burden
therefore does **not** collapse to benign flow alone; it collapses to benign flow
**plus one pool-level observable**, which — unlike `Ḡ` — the pool already
measures. -/
theorem Theorem39_missing_primitive_is_the_pool_scale :
    (∀ h : ℝ → ℝ → ℝ → ℝ → ℝ,
        ScaleHomogeneous (fun S σ φ Δt e => S * h σ φ Δt e)) ∧
      (∀ h : ℝ → ℝ → ℝ → ℝ → ℝ,
        (∃ S σ φ Δt e : ℝ, dArbFlow_dphi (fun S σ φ Δt e => S * h σ φ Δt e) S σ φ Δt e ≠ 0) →
          ¬ ClosesInObservables (fun S σ φ Δt e => S * h σ φ Δt e)) ∧
      (∃ h : ℝ → ℝ → ℝ → ℝ → ℝ,
        ¬ ClosesInObservables (fun S σ φ Δt e => S * h σ φ Δt e)) := by
  have hhom : ∀ h : ℝ → ℝ → ℝ → ℝ → ℝ,
      ScaleHomogeneous (fun S σ φ Δt e => S * h σ φ Δt e) := by
    intro h c S σ φ Δt e
    show c * S * h σ φ Δt e = c * (S * h σ φ Δt e)
    ring
  have hfail : ∀ h : ℝ → ℝ → ℝ → ℝ → ℝ,
      (∃ S σ φ Δt e : ℝ, dArbFlow_dphi (fun S σ φ Δt e => S * h σ φ Δt e) S σ φ Δt e ≠ 0) →
        ¬ ClosesInObservables (fun S σ φ Δt e => S * h σ φ Δt e) := by
    rintro h ⟨S, σ, φ, Δt, e, hne⟩ hclose
    exact hne (Theorem39_arb_side_does_not_close _ (hhom h) hclose S σ φ Δt e)
  refine ⟨hhom, hfail, ?_⟩
  -- a stand-in scale-free profile, used only to show the hypotheses are satisfiable
  refine ⟨fun σ φ _ _ => σ * (1 - φ), hfail _ ⟨1, 1, 0, 1, 0, ?_⟩⟩
  have hd : dArbFlow_dphi (fun S σ φ _ _ => S * (σ * (1 - φ))) 1 1 0 1 0 = -1 := by
    unfold dArbFlow_dphi
    have hfun : (fun f : ℝ => (1 : ℝ) * ((1 : ℝ) * (1 - f))) = fun f : ℝ => 1 - f := by
      funext f; ring
    rw [hfun]
    simpa using ((hasDerivAt_id (0 : ℝ)).const_sub 1).deriv
  rw [hd]; norm_num

/-- **What DOES close, (i): the participation probability [M27].**
`ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` (`DOC` Definition 21) and its fee-derivative are
closed forms in `(σ, φ, Δt)` alone — no scale, no behavioural parameter.  This
is the half of M27's grounds that survives; it is the *quantity*, not the
participation, that fails to close. -/
theorem Theorem39_participation_closes (σ Δt φ : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt)
    (hφ : 0 ≤ φ) :
    HasDerivAt (fun f => MevOptimization.ptrade f σ Δt)
        (-(σ * Real.sqrt (2 / Δt)) / (σ + φ * Real.sqrt (2 / Δt)) ^ 2) φ ∧
      -(σ * Real.sqrt (2 / Δt)) / (σ + φ * Real.sqrt (2 / Δt)) ^ 2 < 0 :=
  ⟨MevTaxLVR.hasDerivAt_ptrade_phi σ Δt φ hσ hΔt hφ,
    MevTaxLVR.dptrade_dphi_neg σ Δt φ hσ hΔt hφ⟩

/-- **What DOES close, (ii): the fee ELASTICITY of arb flow [M27].**  For a
product-shape model `ΔQ^{ARB} = S·h(σ,φ,Δt,ε_{p/X})` the elasticity
`(φ/ΔQ^{ARB})·∂ΔQ^{ARB}/∂φ` is independent of the scale `S`, hence closes in
`(σ, φ, Δt, ε_{p/X})`.  So the arbitrage side of the controller is available in
observables **up to one multiplicative pool-level constant** — which is the
precise content of the refutation above. -/
theorem Theorem39_elasticity_closes (h : ℝ → ℝ → ℝ → ℝ → ℝ) (S σ φ Δt e : ℝ)
    (hS : S ≠ 0) (hh : h σ φ Δt e ≠ 0) :
    (φ * dArbFlow_dphi (fun S σ φ Δt e => S * h σ φ Δt e) S σ φ Δt e)
        / ((fun S σ φ Δt e => S * h σ φ Δt e) S σ φ Δt e)
      = (φ * dArbFlow_dphi (fun _ σ φ Δt e => h σ φ Δt e) S σ φ Δt e) / h σ φ Δt e := by
  have hd : dArbFlow_dphi (fun S σ φ Δt e => S * h σ φ Δt e) S σ φ Δt e
      = S * dArbFlow_dphi (fun _ σ φ Δt e => h σ φ Δt e) S σ φ Δt e := by
    unfold dArbFlow_dphi
    exact deriv_const_mul_field S
  rw [hd]
  field_simp

end MevTaxChannels
