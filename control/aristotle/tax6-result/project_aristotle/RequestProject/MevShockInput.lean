import Mathlib
import RequestProject.MevReturnsReduction

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M33–M35 — the price-shock input (Theorems 45–47)

This module formalizes blocks **M33–M35** of `TAX5_ADDENDUM.md`: the ruling that
the plant's exogenous input is a **relative price shock** `Δp/p`, with `ΔQ` a
**response** — the quantity that moves the pool price to the edge of the fee
band, fixed by the curve's price impact.

## Cited, never redone

* `MevTaxChannels.varphiHalfZero`, `MevTaxChannels.nuRatio`,
  `MevTaxChannels.Theorem38a_flow_scaling_strictly_increases_nu`,
  `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`,
  `MevTaxChannels.Theorem38_two_routes_close_a_loop`,
  `MevTaxChannels.ScaleHomogeneous`, `MevTaxChannels.ClosesInObservables`,
  `MevTaxChannels.Theorem39_arb_side_does_not_close`,
  `MevTaxChannels.Theorem39_missing_primitive_is_the_pool_scale`
  (`MevChannelClosure.lean`);
* `MevTaxReturns.Theorem40d_loop_correction_removes_epsilon`,
  `MevTaxReturns.Corollary40c_one_sided_flow_leaves_no_root`,
  `MevTaxReturns.reducedLaw`, `MevTaxReturns.Theorem44_O2_closes`
  (`MevReturnsReduction.lean`);
* `MevTaxProgram.totalDeriv`, `MevTaxProgram.pathGate`,
  `MevTaxProgram.hasDerivAt_phiTot` — the slot fixed there is the **bare**
  `∂φ_X/∂ν` (standing ban 4) and every claim below uses that slot
  (`MevTaxProgram.lean`);
* `MevTaxControl.Theorem29_monoid_path_is_direct`,
  `MevTaxControl.Theorem32_hazard_strictAntiOn_tau`,
  `MevTaxControl.mevMultiTaxed`, `MevTaxControl.H2_dnu_dlamMEV_pos`
  (`MevTaxControl.lean`);
* `MevOptimization.ptrade` — `DOC` Definition 21 —, `MevTaxLVR.hasDerivAt_ptrade_phi`,
  `MevTaxLVR.dptrade_dphi_neg` (`MevOptimization.lean`, `MevLVRCancellation.lean`).

`MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos` and
`MevTaxChannels.ScaleHomogeneous` are used **by name only**; none is proved here.

## The model

The **price-impact response model** (`DOC` Definition 14, whose `ε_{p/X}` is
declared an observable there).  Write `a = |ε_{p/X}| > 0`.  Reserves on the
trading curve are parameterized by the marginal price `p_φ`,

`Q_X(p) = R p^{-1/a}`, `Q_M(p) = R p^{1/a}`,

so that the price-impact elasticity is the constant `-a`
(`reserveX_constant_elasticity`) and the pool capital in liquidity units — the
denominator of `DOC` Theorem 1's gate argument — is the scale `R = L̄`,
independent of the price (`liquidityUnit`).  At Rule 5's balanced Cobb–Douglas
member `a = 2` and `κ_φ = 1/2`, and the model is then *exactly* the
constant-product curve; away from `a = 2` it is the leading-order constant
price-impact reading of Definition 14, not a CES level set.

A relative shock `s = Δp/p` moves the external price to `p(1+s)`; the arbitrageur
moves the pool price to the near edge of the fee band, i.e. to `p·u` with

`u = bandRatio s φ = (1+s)(1-φ)`,

and trades iff `u > 1`, i.e. iff `s > φ/(1-φ)` (`engaged_iff`) — the same
"shock against band" comparison that `DOC` Definition 21 makes.

## Verdicts

* **Theorem 45 HOLDS, with `g` explicit** (`Theorem45_shock_driven_utilization`):
  `ΔQ = L̄·g(Δp/p, φ, κ_φ)` and `ν = g(Δp/p, φ, κ_φ)` with
  `g(s,φ,κ) = |u^{m} - u^{-m}|`, `u = (1+s)(1-φ)`, `m = (1-κ_φ)/(4κ_φ) = 1/(2a)`.
  The mandatory consistency proof against
  `MevTaxChannels.Theorem39_arb_side_does_not_close` is
  `Theorem45_consistency_with_Theorem39`: the shock flow model is scale
  1-homogeneous and does **not** close in `(σ, φ, Δt, ε_{p/X})`, exactly as that
  refutation says, **while the ratio does** — the missing primitive `L̄` is the
  explicit factor.  The benign half admits no such factorization without
  supplying the `[M8]` missing term (`Theorem45_benign_factorization_is_a_demand_elasticity`).
* **Theorem 46 HOLDS on the signed reading, and the unsigned reading is a
  further ruling** (`Theorem46_shock_flow_is_two_legged`,
  `Theorem46_sign_reading`): shock-induced legs are nonzero with **opposite
  signs**, so the one-sided configuration is unreachable
  (`Theorem46_one_sided_is_unreachable`); but Rule 5's geometric mean then needs
  the **unsigned** legs, and choosing that is a ruling, not a consequence — on
  the signed legs `ν` is not well defined and its Lean value collapses to `0`,
  reproducing the very pathology of
  `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`.  Under
  the unsigned ruling Theorem 38(a) recovers (`Theorem46_recovers_Theorem38a`).
* **Theorem 47: the two channels are ONE channel, and BOTH control laws are
  artifacts** (`Theorem47_shared_driver_is_one_edge`,
  `Theorem47_no_exogenous_hazard_input`, `Theorem47_shared_driver_leaves_no_root`).
  Under the shock input the same primitive fixes the hazard `ℙ_{Δ_ARB}(φ,σ,Δt)`
  and the per-event flow `g(s,φ,κ_φ)`; the expected utilization is their
  **product**, so routes (i) and (ii) are the two summands of one product rule
  over the single edge `∂φ/∂τ_MEV`.  The exogenous hazard input of
  `MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` is then `i = 0`,
  and that theorem's own second clause gives **no root at any tax** — the
  loop law is vacuous.  The single-channel law is not rescued: it is the FOC of
  the inconsistent system that uses the gate response in the FOC and omits it in
  the flow response (`Theorem47_single_channel_root_is_not_a_root`).  The benign
  residual does not restore an independent path
  (`Theorem47_benign_residual_is_not_an_exogenous_path`).  What *is* gained is
  that `ε` becomes a closed form (`Theorem47_epsilon_closes`), so the conditional
  reading of `MevTaxReturns.Theorem44_O2_closes` is available with a computed
  `ε < 0` rather than an empirical one.
-/

namespace MevTaxShock

/-! ## The shock, the band, and the curvature exponent -/

/-- The **band ratio** `u = (1+s)(1-φ)`: the factor by which the arbitrageur
moves the pool's marginal price when the relative shock is `s = Δp/p` and he
stops at the near edge of the fee band. -/
noncomputable def bandRatio (s phi : ℝ) : ℝ := (1 + s) * (1 - phi)

/-- **The trade is engaged exactly when the shock beats the band** — the
comparison `DOC` Definition 21 already makes between a volatility-driven move
and `φ√(2/Δt)`. -/
lemma engaged_iff (s phi : ℝ) (hphi : phi < 1) :
    1 < bandRatio s phi ↔ phi / (1 - phi) < s := by
  unfold bandRatio
  rw [div_lt_iff₀ (by linarith)]
  constructor <;> intro h <;> nlinarith

/-- `DOC` Definition 14's curvature read off the price-impact elasticity
`a = |ε_{p/X}|`: `κ_φ = |ε_{p/X}|/(|ε_{p/X}| + |ε⁰_{p/X}|)` with the
constant-product benchmark `|ε⁰_{p/X}| = 2`. -/
noncomputable def curvOfImpact (a : ℝ) : ℝ := a / (a + 2)

/-- The exponent of the utilization profile, in the curvature. -/
noncomputable def expOfCurv (kap : ℝ) : ℝ := (1 - kap) / (4 * kap)

/-- The exponent of the utilization profile, in the price-impact elasticity. -/
noncomputable def impactExp (a : ℝ) : ℝ := 1 / (2 * a)

/-- The two readings of the exponent agree: `(1-κ_φ)/(4κ_φ) = 1/(2|ε_{p/X}|)`.
So `g` may be written in `κ_φ` — `DOC` Definition 14's normalized curvature — or
equivalently in the observable `ε_{p/X}`. -/
lemma expOfCurv_curvOfImpact (a : ℝ) (ha : 0 < a) :
    expOfCurv (curvOfImpact a) = impactExp a := by
  unfold expOfCurv curvOfImpact impactExp
  have h2 : a + 2 ≠ 0 := by linarith
  have ha' : a ≠ 0 := ne_of_gt ha
  field_simp
  ring

/-- Rule 5's balanced Cobb–Douglas member: `|ε_{p/X}| = 2`, `κ_φ = 1/2`,
exponent `1/4`. -/
lemma ruleFive_exponent : curvOfImpact 2 = 1 / 2 ∧ impactExp 2 = 1 / 4 := by
  constructor <;> norm_num [curvOfImpact, impactExp]

/-! ## The price-impact response model -/

/-- The asset-leg reserve at marginal price `p`: `Q_X(p) = R p^{-1/a}`. -/
noncomputable def reserveX (R a p : ℝ) : ℝ := R * p ^ (-(1 / a))

/-- The money-leg reserve at marginal price `p`: `Q_M(p) = R p^{1/a}`. -/
noncomputable def reserveM (R a p : ℝ) : ℝ := R * p ^ (1 / a)

/-- The pool capital in **liquidity units** — `φ_{(1/2,0)}(i_K; 0, L)`, the
denominator of `DOC` Theorem 1's gate argument — is the scale `R = L̄`, the same
at every price. -/
lemma liquidityUnit (R a p : ℝ) (hR : 0 ≤ R) (hp : 0 < p) :
    MevTaxChannels.varphiHalfZero (reserveX R a p) (reserveM R a p) = R := by
  unfold MevTaxChannels.varphiHalfZero reserveX reserveM
  have hprod : R * p ^ (-(1 / a)) * (R * p ^ (1 / a)) = R ^ 2 := by
    have h := (Real.rpow_add hp (-(1 / a)) (1 / a)).symm
    rw [show -(1 / a) + 1 / a = (0 : ℝ) by ring, Real.rpow_zero] at h
    calc R * p ^ (-(1 / a)) * (R * p ^ (1 / a))
        = R ^ 2 * (p ^ (-(1 / a)) * p ^ (1 / a)) := by ring
      _ = R ^ 2 := by rw [h, mul_one]
  rw [hprod, Real.sqrt_sq hR]

/-- The model realizes `DOC` Definition 14's declared observable: the
price-impact elasticity is the constant `-a`, in the exact (finite-difference in
logs) form. -/
lemma reserveX_constant_elasticity (R a p₁ p₂ : ℝ) (hR : 0 < R) (ha : a ≠ 0)
    (hp₁ : 0 < p₁) (hp₂ : 0 < p₂) :
    Real.log p₂ - Real.log p₁
      = -a * (Real.log (reserveX R a p₂) - Real.log (reserveX R a p₁)) := by
  unfold reserveX
  rw [Real.log_mul (ne_of_gt hR) (ne_of_gt (Real.rpow_pos_of_pos hp₂ _)),
    Real.log_mul (ne_of_gt hR) (ne_of_gt (Real.rpow_pos_of_pos hp₁ _)),
    Real.log_rpow hp₂, Real.log_rpow hp₁]
  field_simp
  ring

/-- The asset leg of the shock-induced trade. -/
noncomputable def legX (R a p u : ℝ) : ℝ := reserveX R a (u * p) - reserveX R a p

/-- The money leg of the shock-induced trade. -/
noncomputable def legM (R a p u : ℝ) : ℝ := reserveM R a (u * p) - reserveM R a p

lemma legX_eq (R a p u : ℝ) (hp : 0 < p) (hu : 0 < u) :
    legX R a p u = R * p ^ (-(1 / a)) * (u ^ (-(1 / a)) - 1) := by
  unfold legX reserveX
  rw [Real.mul_rpow hu.le hp.le]
  ring

lemma legM_eq (R a p u : ℝ) (hp : 0 < p) (hu : 0 < u) :
    legM R a p u = R * p ^ (1 / a) * (u ^ (1 / a) - 1) := by
  unfold legM reserveM
  rw [Real.mul_rpow hu.le hp.le]
  ring

/-- The scale-free utilization profile in the band ratio: `|u^m - u^{-m}|`. -/
noncomputable def gOfRatio (u m : ℝ) : ℝ := |u ^ m - u ^ (-m)|

/-- `g(Δp/p, φ, κ_φ)` — the profile written in the shock, the fee and `DOC`
Definition 14's curvature. -/
noncomputable def gShock (s phi kap : ℝ) : ℝ :=
  gOfRatio (bandRatio s phi) (expOfCurv kap)

/-- `g` is invariant under `u ↦ 1/u`: up-shocks and down-shocks of the same log
size give the same utilization.  (The down branch of the band is `u = (1+s)/(1-φ)`.) -/
lemma gOfRatio_inv (u m : ℝ) (hu : 0 < u) : gOfRatio u⁻¹ m = gOfRatio u m := by
  unfold gOfRatio
  rw [Real.inv_rpow hu.le, Real.inv_rpow hu.le, ← Real.rpow_neg hu.le, ← Real.rpow_neg hu.le,
    neg_neg]
  rw [abs_sub_comm]

/-- The **core identity**: the signed product of the two legs is
`-(L̄·(u^m - u^{-m}))²`, with `m = 1/(2|ε_{p/X}|)`. -/
lemma legs_product (R a p u : ℝ) (hp : 0 < p) (hu : 0 < u) :
    legX R a p u * legM R a p u
      = -(R * (u ^ impactExp a - u ^ (-impactExp a))) ^ 2 := by
  have hpp : p ^ (-(1 / a)) * p ^ (1 / a) = 1 := by
    have h := (Real.rpow_add hp (-(1 / a)) (1 / a)).symm
    rw [show -(1 / a) + 1 / a = (0 : ℝ) by ring, Real.rpow_zero] at h
    exact h
  have e1 : u ^ (1 / a) = (u ^ impactExp a) ^ 2 := by
    rw [← Real.rpow_natCast (u ^ impactExp a) 2, ← Real.rpow_mul hu.le]
    norm_num [impactExp]
    ring_nf
  have e2 : u ^ (-(1 / a)) = (u ^ (-impactExp a)) ^ 2 := by
    rw [← Real.rpow_natCast (u ^ (-impactExp a)) 2, ← Real.rpow_mul hu.le]
    norm_num [impactExp]
    ring_nf
  have e3 : u ^ impactExp a * u ^ (-impactExp a) = 1 := by
    rw [← Real.rpow_add hu]
    simp
  have key : (u ^ (-(1 / a)) - 1) * (u ^ (1 / a) - 1)
      = -(u ^ impactExp a - u ^ (-impactExp a)) ^ 2 := by
    rw [e1, e2]
    linear_combination (u ^ impactExp a * u ^ (-impactExp a) - 1) * e3
  rw [legX_eq R a p u hp hu, legM_eq R a p u hp hu]
  calc R * p ^ (-(1 / a)) * (u ^ (-(1 / a)) - 1) * (R * p ^ (1 / a) * (u ^ (1 / a) - 1))
      = R ^ 2 * (p ^ (-(1 / a)) * p ^ (1 / a))
          * ((u ^ (-(1 / a)) - 1) * (u ^ (1 / a) - 1)) := by ring
    _ = R ^ 2 * (-(u ^ impactExp a - u ^ (-impactExp a)) ^ 2) := by rw [hpp, key]; ring
    _ = -(R * (u ^ impactExp a - u ^ (-impactExp a))) ^ 2 := by ring

/-- Rule 5's geometric mean, evaluated on the **unsigned** legs of the
shock-induced trade, is `L̄` times the scale-free profile. -/
lemma varphi_unsigned_legs (R a p u : ℝ) (hR : 0 ≤ R) (hp : 0 < p) (hu : 0 < u) :
    MevTaxChannels.varphiHalfZero |legX R a p u| |legM R a p u|
      = R * gOfRatio u (impactExp a) := by
  have hprod : |legX R a p u| * |legM R a p u|
      = (R * (u ^ impactExp a - u ^ (-impactExp a))) ^ 2 := by
    rw [← abs_mul, legs_product R a p u hp hu, abs_neg, abs_of_nonneg (sq_nonneg _)]
  unfold MevTaxChannels.varphiHalfZero gOfRatio
  rw [hprod, Real.sqrt_sq_eq_abs, abs_mul, abs_of_nonneg hR]

/-! ## M33.  Theorem 45 — shock-driven utilization -/

/-- **Theorem 45 (Shock-driven utilization) [M33] — HOLDS, with `g` explicit.**

With the price shock as driver and `ΔQ` the response that moves the pool price to
the edge of the fee band:

1. the traded volume in liquidity units — Rule 5's geometric mean of the two legs
   — factorizes as `ΔQ = L̄ · g(Δp/p, φ, κ_φ)`;
2. hence the utilization `ν = ΔQ/L̄` **is** `g(Δp/p, φ, κ_φ)`: scale-free and
   closed-form;
3. explicitly, with `u = (1+s)(1-φ)` the band ratio and
   `m = (1-κ_φ)/(4κ_φ) = 1/(2|ε_{p/X}|)`,

   `g(s, φ, κ_φ) = | u^m − u^{−m} |`.

`κ_φ` is `DOC` Definition 14's curvature and `ε_{p/X}` its price-impact
elasticity, declared an observable there; nothing else enters.  The legs are read
**unsigned** — see `Theorem46_sign_reading`, where that reading is shown to be a
further ruling. -/
theorem Theorem45_shock_driven_utilization (R a p s phi : ℝ)
    (hR : 0 ≤ R) (ha : 0 < a) (hp : 0 < p) (hu : 0 < bandRatio s phi) :
    MevTaxChannels.varphiHalfZero |legX R a p (bandRatio s phi)|
          |legM R a p (bandRatio s phi)|
        = R * gShock s phi (curvOfImpact a)
      ∧ (0 < R →
          MevTaxChannels.nuRatio |legX R a p (bandRatio s phi)|
            |legM R a p (bandRatio s phi)| R = gShock s phi (curvOfImpact a))
      ∧ gShock s phi (curvOfImpact a)
        = |((1 + s) * (1 - phi)) ^ (1 / (2 * a))
            - ((1 + s) * (1 - phi)) ^ (-(1 / (2 * a)))| := by
  have hexp : expOfCurv (curvOfImpact a) = impactExp a := expOfCurv_curvOfImpact a ha
  have h1 : MevTaxChannels.varphiHalfZero |legX R a p (bandRatio s phi)|
      |legM R a p (bandRatio s phi)| = R * gShock s phi (curvOfImpact a) := by
    rw [varphi_unsigned_legs R a p _ hR hp hu]
    unfold gShock
    rw [hexp]
  refine ⟨h1, ?_, ?_⟩
  · intro hRpos
    unfold MevTaxChannels.nuRatio
    rw [h1, mul_comm, mul_div_assoc, div_self (ne_of_gt hRpos), mul_one]
  · unfold gShock gOfRatio bandRatio
    rw [hexp]
    unfold impactExp
    ring_nf

/-! ### The mandatory consistency proof against Theorem 39 -/

/-- The shock-driven arb-flow model in the coordinates of
`MevTaxChannels.ArbFlow`: the pool scale `S = L̄`, the `σ`-slot carrying the
relative shock `s = Δp/p`, the `ε_{p/X}`-slot carrying the price-impact
elasticity `a` (the `Δt`-slot is not used by the response). -/
noncomputable def shockArbFlow : MevTaxChannels.ArbFlow :=
  fun S s phi _Δt a => S * gOfRatio (bandRatio s phi) (impactExp a)

/-- The `φ`-derivative of the scale-free profile on the **engaged** branch
`u > 1`, where the absolute value is inert. -/
lemma hasDerivAt_gOfRatio_phi (s phi m : ℝ) (hm : 0 < m) (hphi : phi < 1)
    (hu : 1 < bandRatio s phi) :
    HasDerivAt (fun f => gOfRatio (bandRatio s f) m)
      (-((1 + s) * m * (bandRatio s phi ^ (m - 1) + bandRatio s phi ^ (-m - 1)))) phi := by
  have hs : 0 < 1 + s := by
    by_contra hcon
    push_neg at hcon
    have h1 : 0 < 1 - phi := by linarith
    have hle : bandRatio s phi ≤ 0 := by unfold bandRatio; nlinarith
    linarith
  have hband : HasDerivAt (fun f : ℝ => bandRatio s f) (-(1 + s)) phi := by
    have : HasDerivAt (fun f : ℝ => (1 + s) * (1 - f)) ((1 + s) * (-1)) phi := by
      simpa using (((hasDerivAt_id phi).const_sub 1).const_mul (1 + s))
    simpa [bandRatio, mul_comm] using this
  have hupos : 0 < bandRatio s phi := lt_trans zero_lt_one hu
  have hpow1 : HasDerivAt (fun f : ℝ => bandRatio s f ^ m)
      (m * bandRatio s phi ^ (m - 1) * -(1 + s)) phi :=
    (Real.hasDerivAt_rpow_const (p := m) (Or.inl (ne_of_gt hupos))).comp phi hband
  have hpow2 : HasDerivAt (fun f : ℝ => bandRatio s f ^ (-m))
      (-m * bandRatio s phi ^ (-m - 1) * -(1 + s)) phi :=
    (Real.hasDerivAt_rpow_const (p := -m) (Or.inl (ne_of_gt hupos))).comp phi hband
  have hdiff : HasDerivAt (fun f : ℝ => bandRatio s f ^ m - bandRatio s f ^ (-m))
      (m * bandRatio s phi ^ (m - 1) * -(1 + s)
        - -m * bandRatio s phi ^ (-m - 1) * -(1 + s)) phi := hpow1.sub hpow2
  -- on a neighbourhood of `phi` the band ratio exceeds `1`, so the profile is the difference
  have hnbhd : (fun f => gOfRatio (bandRatio s f) m)
      =ᶠ[nhds phi] fun f => bandRatio s f ^ m - bandRatio s f ^ (-m) := by
    have hcont : ContinuousAt (fun f : ℝ => bandRatio s f) phi := hband.continuousAt
    have hset : {f : ℝ | 1 < bandRatio s f} ∈ nhds phi :=
      hcont (isOpen_Ioi.mem_nhds (Set.mem_Ioi.mpr hu))
    filter_upwards [hset] with f hf
    have hf1 : 1 < bandRatio s f := hf
    have hfpos : 0 < bandRatio s f := lt_trans zero_lt_one hf1
    have hgt : bandRatio s f ^ (-m) < bandRatio s f ^ m := by
      have h1 : bandRatio s f ^ (-m) < 1 := by
        rw [Real.rpow_neg hfpos.le]
        rw [inv_lt_one_iff₀]
        exact Or.inr (Real.one_lt_rpow_iff_of_pos hfpos |>.mpr (Or.inl ⟨hf1, hm⟩))
      have h2 : (1 : ℝ) < bandRatio s f ^ m :=
        Real.one_lt_rpow_iff_of_pos hfpos |>.mpr (Or.inl ⟨hf1, hm⟩)
      linarith
    unfold gOfRatio
    rw [abs_of_pos (by linarith)]
  have hres := hdiff.congr_of_eventuallyEq hnbhd
  convert hres using 1
  ring

/-- On the engaged branch the profile is **strictly decreasing** in the fee: a
larger fee widens the band and shortens the arbitrageur's trip. -/
lemma dgOfRatio_phi_neg (s phi m : ℝ) (hm : 0 < m) (hphi : phi < 1)
    (hu : 1 < bandRatio s phi) :
    -((1 + s) * m * (bandRatio s phi ^ (m - 1) + bandRatio s phi ^ (-m - 1))) < 0 := by
  have hs : 0 < 1 + s := by
    by_contra hcon
    push_neg at hcon
    have h1 : 0 < 1 - phi := by linarith
    have hle : bandRatio s phi ≤ 0 := by unfold bandRatio; nlinarith
    linarith
  have hupos : 0 < bandRatio s phi := lt_trans zero_lt_one hu
  have h1 : 0 < bandRatio s phi ^ (m - 1) := Real.rpow_pos_of_pos hupos _
  have h2 : 0 < bandRatio s phi ^ (-m - 1) := Real.rpow_pos_of_pos hupos _
  have : 0 < (1 + s) * m * (bandRatio s phi ^ (m - 1) + bandRatio s phi ^ (-m - 1)) := by
    have := mul_pos hs hm
    nlinarith
  linarith

/-- **Theorem 45, the mandatory consistency proof [M33].**  The factorization
**confirms** `MevTaxChannels.Theorem39_arb_side_does_not_close`; it does not
overturn it.

1. The shock-driven flow model is scale 1-homogeneous — the hypothesis of that
   refutation — because the pool scale `L̄` is an explicit factor.
2. It therefore does **not** close in `(σ, φ, Δt, ε_{p/X})`: it has a nonzero fee
   response (on the engaged branch), so by the cited refutation closure is
   impossible.  The missing primitive is exactly the factor `L̄`.
3. What closes is the **ratio**: `ν = ΔQ/L̄ = g(s, φ, κ_φ)` is one and the same
   function of the observables for every pool scale.

There is no conflict: (2) is about a quantity and (3) about a scale-free ratio,
which is precisely the dimensional obstruction the refutation identified. -/
theorem Theorem45_consistency_with_Theorem39 :
    MevTaxChannels.ScaleHomogeneous shockArbFlow
      ∧ ¬ MevTaxChannels.ClosesInObservables shockArbFlow
      ∧ (∃ F : ℝ → ℝ → ℝ → ℝ → ℝ, ∀ S s phi Δt a : ℝ, S ≠ 0 →
          shockArbFlow S s phi Δt a / S = F s phi Δt a) := by
  have hhom : MevTaxChannels.ScaleHomogeneous shockArbFlow := by
    intro c S σ φ Δt e
    show c * S * gOfRatio (bandRatio σ φ) (impactExp e)
        = c * (S * gOfRatio (bandRatio σ φ) (impactExp e))
    ring
  refine ⟨hhom, ?_, ⟨fun s phi _ a => gOfRatio (bandRatio s phi) (impactExp a), ?_⟩⟩
  · -- a point with a nonzero fee response: `S = 1`, `s = 3`, `φ = 0`, `a = 2`
    intro hclose
    have hzero := MevTaxChannels.Theorem39_arb_side_does_not_close shockArbFlow hhom hclose
      1 3 0 1 2
    have hm : (0 : ℝ) < impactExp 2 := by norm_num [impactExp]
    have hu : (1 : ℝ) < bandRatio 3 0 := by norm_num [bandRatio]
    have hd := hasDerivAt_gOfRatio_phi 3 0 (impactExp 2) hm (by norm_num) hu
    have hd1 : HasDerivAt (fun f => shockArbFlow 1 3 f 1 2)
        (-((1 + 3) * impactExp 2
          * (bandRatio 3 0 ^ (impactExp 2 - 1) + bandRatio 3 0 ^ (-impactExp 2 - 1)))) 0 := by
      have := hd.const_mul (1 : ℝ)
      simpa [shockArbFlow] using this
    have hne := dgOfRatio_phi_neg 3 0 (impactExp 2) hm (by norm_num) hu
    rw [MevTaxChannels.dArbFlow_dphi, hd1.deriv] at hzero
    linarith
  · intro S s phi Δt a hS
    show S * gOfRatio (bandRatio s phi) (impactExp a) / S = _
    field_simp

/-- **Theorem 45, the benign half [M33, falsification target].**  The benign
component admits **no** such factorization for free: positing
`ΔQ^{ben} = L̄ · B(Δp/p, φ)` with a differentiable, nonvanishing `B` is
*equivalent* to positing a shock elasticity of benign demand — the log-derivative
exists and equals it — which is exactly the term `DOC` `[M8]` records as MISSING
(`MMR` §7.3 eq. (27)).  Noise traders have no profit function and no stopping
condition, so nothing in the shock ruling supplies `B`; a claim that it does is a
claim to have supplied the missing primitive.  No demand elasticity is supplied
here. -/
theorem Theorem45_benign_factorization_is_a_demand_elasticity
    (B : ℝ → ℝ → ℝ) (s phi c : ℝ) (hB : HasDerivAt (fun x => B x phi) c s)
    (hne : B s phi ≠ 0) :
    HasDerivAt (fun x => Real.log |B x phi|) (c / B s phi) s
      ∧ s * c / B s phi = s * deriv (fun x => Real.log |B x phi|) s := by
  have hlog : HasDerivAt (fun x => Real.log |B x phi|) (c / B s phi) s := by
    simpa using (hB.log hne)
  exact ⟨hlog, by rw [hlog.deriv]; ring⟩

/-! ## M34.  Theorem 46 — shock-driven flow is two-legged -/

/-- **Theorem 46 (Shock-driven flow is two-legged) [M34] — HOLDS.**  A trade
induced by a price shock is a **swap**: whenever the shock moves the price at all
(`u ≠ 1`) both legs are nonzero and their **signed** product is strictly
negative — one leg in, one leg out.  The one-sided configuration is therefore not
reachable from a shock driver; it arises from a one-sided *deposit*, which is not
a swap and is not in the plant's input. -/
theorem Theorem46_shock_flow_is_two_legged (R a p u : ℝ)
    (hR : 0 < R) (ha : 0 < a) (hp : 0 < p) (hu : 0 < u) (hne : u ≠ 1) :
    legX R a p u ≠ 0 ∧ legM R a p u ≠ 0 ∧ legX R a p u * legM R a p u < 0 := by
  have hm : 0 < impactExp a := by
    unfold impactExp; positivity
  have hdne : u ^ impactExp a - u ^ (-impactExp a) ≠ 0 := by
    intro h
    have h1 : u ^ impactExp a = u ^ (-impactExp a) := by linarith
    rcases lt_trichotomy u 1 with hlt | heq | hgt
    · have hA : u ^ impactExp a < 1 := Real.rpow_lt_one hu.le hlt hm
      have hB : (1 : ℝ) < u ^ (-impactExp a) := by
        rw [Real.rpow_neg hu.le, one_lt_inv_iff₀]
        exact ⟨Real.rpow_pos_of_pos hu _, Real.rpow_lt_one hu.le hlt hm⟩
      linarith
    · exact hne heq
    · have hA : (1 : ℝ) < u ^ impactExp a := Real.one_lt_rpow_iff_of_pos hu |>.mpr (Or.inl ⟨hgt, hm⟩)
      have hB : u ^ (-impactExp a) < 1 := by
        rw [Real.rpow_neg hu.le, inv_lt_one_iff₀]
        exact Or.inr (Real.one_lt_rpow_iff_of_pos hu |>.mpr (Or.inl ⟨hgt, hm⟩))
      linarith
  have hprod : legX R a p u * legM R a p u
      = -(R * (u ^ impactExp a - u ^ (-impactExp a))) ^ 2 := legs_product R a p u hp hu
  have hne0 : R * (u ^ impactExp a - u ^ (-impactExp a)) ≠ 0 :=
    mul_ne_zero (ne_of_gt hR) hdne
  have hsq : 0 < (R * (u ^ impactExp a - u ^ (-impactExp a))) ^ 2 :=
    lt_of_le_of_ne (sq_nonneg _) (Ne.symm (pow_ne_zero 2 hne0))
  have hneg : legX R a p u * legM R a p u < 0 := by rw [hprod]; linarith
  refine ⟨?_, ?_, hneg⟩
  · intro h; rw [h, zero_mul] at hneg; exact lt_irrefl 0 hneg
  · intro h; rw [h, mul_zero] at hneg; exact lt_irrefl 0 hneg

/-- **Theorem 46, the one-sided configuration is unreachable [M34].**  On the
shock-driven response the two legs vanish **together** — the no-trade case
`u = 1`, the shock inside the band.  There is no shock and no pool at which one
leg moves and the other does not, which is exactly the configuration
`MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity` used as
its witness. -/
theorem Theorem46_one_sided_is_unreachable (R a p u : ℝ)
    (hR : 0 < R) (ha : 0 < a) (hp : 0 < p) (hu : 0 < u) :
    (legX R a p u = 0 ↔ legM R a p u = 0)
      ∧ ¬ (legX R a p u ≠ 0 ∧ legM R a p u = 0)
      ∧ ¬ (legX R a p u = 0 ∧ legM R a p u ≠ 0) := by
  have hiff : legX R a p u = 0 ↔ legM R a p u = 0 := by
    constructor
    · intro h
      by_cases hne : u = 1
      · simp [legM, hne]
      · exact absurd h (Theorem46_shock_flow_is_two_legged R a p u hR ha hp hu hne).1
    · intro h
      by_cases hne : u = 1
      · simp [legX, hne]
      · exact absurd h (Theorem46_shock_flow_is_two_legged R a p u hR ha hp hu hne).2.1
  exact ⟨hiff, fun h => h.1 (hiff.mpr h.2), fun h => h.2 (hiff.mp h.1)⟩

/-- **Theorem 46, the sign reading [M34] — the unsigned reading is a FURTHER
RULING, not a consequence.**

Rule 5's operative member is the geometric mean, which needs a **nonnegative**
product of legs.  Shock-induced legs have a **negative** signed product
(`Theorem46_shock_flow_is_two_legged`), so:

1. on the **signed** legs the geometric mean has no real value; in Lean
   `Real.sqrt` of the negative product is `0`, so `ν = 0` at *every* shock —
   reproducing exactly the degeneracy of
   `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`, and
   with it the no-root verdict of
   `MevTaxReturns.Corollary40c_one_sided_flow_leaves_no_root`;
2. on the **unsigned** legs the product is strictly positive and `ν = g > 0`.

So the input ruling alone does **not** decide `PR-REGION`: it removes the
one-sided *domain* but leaves the sign *reading*, and only the unsigned reading
makes `ν` well defined.  Adopting it is a second ruling by the author. -/
theorem Theorem46_sign_reading (R a p u : ℝ)
    (hR : 0 < R) (ha : 0 < a) (hp : 0 < p) (hu : 0 < u) (hne : u ≠ 1) :
    MevTaxChannels.varphiHalfZero (legX R a p u) (legM R a p u) = 0
      ∧ MevTaxChannels.nuRatio (legX R a p u) (legM R a p u) R = 0
      ∧ 0 < MevTaxChannels.varphiHalfZero |legX R a p u| |legM R a p u|
      ∧ MevTaxChannels.nuRatio |legX R a p u| |legM R a p u| R
          = gOfRatio u (impactExp a) := by
  obtain ⟨hXne, hMne, hprod⟩ := Theorem46_shock_flow_is_two_legged R a p u hR ha hp hu hne
  have hsigned : MevTaxChannels.varphiHalfZero (legX R a p u) (legM R a p u) = 0 := by
    unfold MevTaxChannels.varphiHalfZero
    exact Real.sqrt_eq_zero_of_nonpos hprod.le
  have hunsigned : MevTaxChannels.varphiHalfZero |legX R a p u| |legM R a p u|
      = R * gOfRatio u (impactExp a) := varphi_unsigned_legs R a p u hR.le hp hu
  have hgpos : 0 < gOfRatio u (impactExp a) := by
    have habs : |legX R a p u| * |legM R a p u| > 0 :=
      mul_pos (abs_pos.mpr hXne) (abs_pos.mpr hMne)
    have : 0 < MevTaxChannels.varphiHalfZero |legX R a p u| |legM R a p u| := by
      unfold MevTaxChannels.varphiHalfZero
      exact Real.sqrt_pos.mpr habs
    rw [hunsigned] at this
    by_contra hcon
    push_neg at hcon
    nlinarith
  refine ⟨hsigned, ?_, ?_, ?_⟩
  · unfold MevTaxChannels.nuRatio
    rw [hsigned, zero_div]
  · rw [hunsigned]; positivity
  · unfold MevTaxChannels.nuRatio
    rw [hunsigned, mul_comm, mul_div_assoc, div_self (ne_of_gt hR), mul_one]

/-- **Theorem 46, Theorem 38(a) recovers on the reachable domain [M34].**  Under
the unsigned ruling the shock-induced flow has two strictly positive legs, which
is exactly the premise of
`MevTaxChannels.Theorem38a_flow_scaling_strictly_increases_nu`; so along the
scaling ray of a shock-induced flow the utilization is strictly increasing,
`∂ν/∂ΔQ > 0`, and the refuting witness of
`MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity` is not
reachable from a shock driver. -/
theorem Theorem46_recovers_Theorem38a (R a p u den r : ℝ)
    (hR : 0 < R) (ha : 0 < a) (hp : 0 < p) (hu : 0 < u) (hne : u ≠ 1)
    (hden : 0 < den) (hr : 0 < r) :
    HasDerivAt (fun t => MevTaxChannels.nuRatio (t * |legX R a p u|) (t * |legM R a p u|) den)
        (MevTaxChannels.varphiHalfZero |legX R a p u| |legM R a p u| / den) r
      ∧ 0 < MevTaxChannels.varphiHalfZero |legX R a p u| |legM R a p u| / den := by
  obtain ⟨hXne, hMne, -⟩ := Theorem46_shock_flow_is_two_legged R a p u hR ha hp hu hne
  exact MevTaxChannels.Theorem38a_flow_scaling_strictly_increases_nu _ _ den r
    (abs_pos.mpr hXne) (abs_pos.mpr hMne) hden hr

/-! ## M35.  Theorem 47 — the shared driver -/

/-- The **expected arb utilization** under the shock input: the long-run fraction
of blocks carrying an arb trade (`DOC` Definition 21,
`MevOptimization.ptrade`) times the per-event utilization the shock induces
(Theorem 45).  Both factors are functions of the **same** primitive — the shock —
and of the fee. -/
noncomputable def sharedNuArb (sig Δt s kap phi : ℝ) : ℝ :=
  MevOptimization.ptrade phi sig Δt * gShock s phi kap

/-- **Theorem 47 (Shared driver) [M35], part 1 — routes (i) and (ii) are two
summands over ONE edge.**  With the shock as driver the hazard and the flow are
factors of a single object `ν = ℙ_{Δ_ARB}(φ,σ,Δt)·g(s,φ,κ_φ)`, and the tax reaches
it only through the fee.  The chain rule therefore produces

`∂ν/∂τ_MEV = [ (∂ℙ/∂φ)·g + ℙ·(∂g/∂φ) ] · ∂φ/∂τ_MEV`,

a **product rule** whose first summand is route (i)'s primitive and whose second
is route (ii)'s — multiplied by the *same* `∂φ/∂τ_MEV`.  They are not two
independent inputs. -/
theorem Theorem47_shared_driver_is_one_edge
    (phiOf : ℝ → ℝ) (sig Δt s kap tau dphidtau dP dg : ℝ)
    (hphi : HasDerivAt phiOf dphidtau tau)
    (hP : HasDerivAt (fun f => MevOptimization.ptrade f sig Δt) dP (phiOf tau))
    (hg : HasDerivAt (fun f => gShock s f kap) dg (phiOf tau)) :
    HasDerivAt (fun t => sharedNuArb sig Δt s kap (phiOf t))
      ((dP * gShock s (phiOf tau) kap
        + MevOptimization.ptrade (phiOf tau) sig Δt * dg) * dphidtau) tau := by
  have hmul : HasDerivAt (fun f => sharedNuArb sig Δt s kap f)
      (dP * gShock s (phiOf tau) kap
        + MevOptimization.ptrade (phiOf tau) sig Δt * dg) (phiOf tau) := hP.mul hg
  exact hmul.comp tau hphi

/-- **Theorem 47, part 2 — the tax reaches the hazard only through the fee.**
The project's own taxed hazard `MevTaxControl.mevMultiTaxed` — the object behind
`MevTaxControl.Theorem32_hazard_strictAntiOn_tau` — depends on `τ_MEV` only
through the per-event composed fee: two taxes producing the same fee at every
event produce the same hazard.  So route (i) carries **no** `τ_MEV`-edge that
bypasses `φ`; there is no exogenous hazard input. -/
theorem Theorem47_no_exogenous_hazard_input
    (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (t₁ t₂ : ℝ)
    (hfee : ∀ k, VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) t₁
        = VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) t₂) :
    MevTaxControl.mevMultiTaxed n γ β α φbar u σpath a D Δt T t₁
      = MevTaxControl.mevMultiTaxed n γ β α φbar u σpath a D Δt T t₂ := by
  unfold MevTaxControl.mevMultiTaxed MevOptimization.mevHazard
  exact Finset.sum_congr rfl (fun k _ => by simp only [hfee k])

/-- **Theorem 47, part 3 — with a shared driver the loop system has NO ROOT.**
Because both routes run through the fee, the loop system of
`MevTaxChannels.Theorem38_two_routes_close_a_loop` has **no exogenous input**:
`N = q·P` with `q = ∂ν/∂φ` the *total* fee response (arb and benign alike).  Then

`P·(1 − q(1-φ_M)(1-τ)(∂φ_X/∂ν)) = (1-φ_M)(1-φ_X) ≠ 0`,

so `P ≠ 0` at every tax — whatever the sign or size of `q`, including the
resonant case where the loop gain reaches `1` (there the system has no solution
at all, which is again not a root).  This is
`MevTaxReturns.Theorem40d_loop_correction_removes_epsilon`'s second clause,
`i = 0 → P ≠ 0`, reached from the input ruling instead of by assumption.

Under the M26 signs (`q ≤ 0`, `0 < ∂φ_X/∂ν`) more is true: `P > 0` on the whole
admissible interval, so `∂π̂^σ/∂τ_MEV > 0` throughout — there is no interior
stationary point at all and the constrained optimum is a boundary point of
`[0,1]` (which boundary depends on the objective reading, and is not decided
here). -/
theorem Theorem47_shared_driver_leaves_no_root
    (A phiM phiXv dphiXdnu : ℝ) (q P N : ℝ → ℝ)
    (hP : ∀ t, P t = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - t) * dphiXdnu * N t)
    (hN : ∀ t, N t = q t * P t)
    (hM : phiM < 1) (hX : phiXv < 1) :
    (∀ t, MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu (N t) = A * P t)
      ∧ (∀ t, P t ≠ 0)
      ∧ (A ≠ 0 → ∀ t, MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu (N t) ≠ 0)
      ∧ (0 < A → 0 < dphiXdnu → (∀ t, q t ≤ 0) →
          ∀ t ∈ Set.Icc (0 : ℝ) 1,
            0 < MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu (N t)) := by
  have hMpos : 0 < 1 - phiM := by linarith
  have hXpos : 0 < 1 - phiXv := by linarith
  have hkey : ∀ t, P t * (1 - q t * ((1 - phiM) * (1 - t) * dphiXdnu))
      = (1 - phiM) * (1 - phiXv) := by
    intro t
    have h1 := hP t
    have h2 := hN t
    linear_combination h1 + ((1 - phiM) * (1 - t) * dphiXdnu) * h2
  have htot : ∀ t, MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu (N t) = A * P t := by
    intro t
    rw [MevTaxProgram.totalDeriv, MevTaxProgram.pathDirect, MevTaxProgram.pathGate, hP t]
    ring
  have hPne : ∀ t, P t ≠ 0 := by
    intro t h
    have := hkey t
    rw [h, zero_mul] at this
    nlinarith
  refine ⟨htot, hPne, ?_, ?_⟩
  · intro hA t
    rw [htot t]
    exact mul_ne_zero hA (hPne t)
  · rintro hA hb hq t ⟨ht0, ht1⟩
    have hloop : q t * ((1 - phiM) * (1 - t) * dphiXdnu) ≤ 0 := by
      have h1 : 0 ≤ (1 - phiM) * (1 - t) * dphiXdnu := by
        have : 0 ≤ (1 - phiM) * (1 - t) := mul_nonneg hMpos.le (by linarith)
        positivity
      exact mul_nonpos_of_nonpos_of_nonneg (hq t) h1
    have hden : 1 ≤ 1 - q t * ((1 - phiM) * (1 - t) * dphiXdnu) := by linarith
    have hPpos : 0 < P t := by
      have hnum : 0 < (1 - phiM) * (1 - phiXv) := mul_pos hMpos hXpos
      nlinarith [hkey t]
    rw [htot t]
    exact mul_pos hA hPpos

/-- **Theorem 47, part 3′ — the same verdict reached through the cited theorem.**
The shared driver sets the exogenous hazard input of
`MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` to `i = 0`; that
theorem's own second clause then returns `P ≠ 0`.  Nothing is re-derived here:
the input ruling supplies `i = 0` and the cited result supplies the verdict. -/
theorem Theorem47_loop_law_is_vacuous (phiM phiXv tauMEV dphiXdnu q P N : ℝ)
    (hP : P = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tauMEV) * dphiXdnu * N)
    (hN : N = 0 + q * P) (hM : phiM ≠ 1) (hX : phiXv ≠ 1)
    (hden : 1 - q * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) ≠ 0) :
    P ≠ 0 :=
  (MevTaxReturns.Theorem40d_loop_correction_removes_epsilon P N phiM phiXv tauMEV
    dphiXdnu 0 q hP hN hM hden).2.1 rfl hX

/-- **Theorem 47, part 4 — the benign residual is not an escape [M35,
falsification target].**  Benign flow is *not* shock-driven: noise traders have
no profit function, so the tax reaches them only through the fee they pay.  A
benign utilization `B(φ)` therefore contributes its fee response `B'(φ)` to the
loop gain `q`, and **not** an exogenous input `i`.  The loop correction has
nothing to apply to on its own: the residual is an addend of `q`, which enters
only the denominator `1 − loop`, and `Theorem47_shared_driver_leaves_no_root`
still gives no root.

No demand elasticity is supplied: `B` is arbitrary and `B'` is left free, of
either sign. -/
theorem Theorem47_benign_residual_is_not_an_exogenous_path
    (Bof : ℝ → ℝ) (phiOf : ℝ → ℝ) (sig Δt s kap tau dphidtau dP dg dB : ℝ)
    (hphi : HasDerivAt phiOf dphidtau tau)
    (hP : HasDerivAt (fun f => MevOptimization.ptrade f sig Δt) dP (phiOf tau))
    (hg : HasDerivAt (fun f => gShock s f kap) dg (phiOf tau))
    (hB : HasDerivAt Bof dB (phiOf tau)) :
    HasDerivAt (fun t => sharedNuArb sig Δt s kap (phiOf t) + Bof (phiOf t))
      ((dP * gShock s (phiOf tau) kap
        + MevOptimization.ptrade (phiOf tau) sig Δt * dg + dB) * dphidtau) tau := by
  have h1 : HasDerivAt (fun f => sharedNuArb sig Δt s kap f + Bof f)
      (dP * gShock s (phiOf tau) kap
        + MevOptimization.ptrade (phiOf tau) sig Δt * dg + dB) (phiOf tau) :=
    (hP.mul hg).add hB
  exact h1.comp tau hphi

/-- **Theorem 47, part 5 — the single-channel law is not rescued.**  M28's law
`MevTaxReturns.reducedLaw` is the FOC of the system that computes the flow
response with the **partial** fee derivative `(1-φ_M)(1-φ_X)` while using the gate
response `∂φ_X/∂ν` in the FOC itself.  Under a shared driver the consistent flow
response is `N = q·P` with the **total** `P`, and at the very tax M28 calls
optimal the consistent derivative is nonzero.

A witness is supplied (`φ_M = 0`, `φ_X = 1/2`, `∂φ_X/∂ν = 1`, `q = -1`,
`A = 1`): the single-channel FOC vanishes at `τ = 0` while the shared-driver
system has `P = 1/4 ≠ 0` there.  So the two "control laws" of the fork are not
two readings that can both be operated: one is vacuous and the other is the FOC
of an inconsistent system. -/
theorem Theorem47_single_channel_root_is_not_a_root :
    ∃ A phiM phiXv dphiXdnu q tau P N : ℝ,
      MevTaxProgram.totalDeriv A phiM tau phiXv dphiXdnu
          (q * ((1 - phiM) * (1 - phiXv))) = 0
        ∧ P = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tau) * dphiXdnu * N
        ∧ N = q * P
        ∧ MevTaxProgram.totalDeriv A phiM tau phiXv dphiXdnu N ≠ 0 := by
  refine ⟨1, 0, 1/2, 1, -1, 0, 1/4, -(1/4), ?_, ?_, ?_, ?_⟩ <;>
    norm_num [MevTaxProgram.totalDeriv, MevTaxProgram.pathDirect, MevTaxProgram.pathGate]

/-- **Theorem 47, part 6 — what the shared driver DOES buy: `ε` closes.**  On the
engaged branch the fee elasticity of the utilization,
`ε = (φ/ν)·∂ν/∂φ`, is a closed form in `(Δp/p, φ, σ, Δt, κ_φ)` with no pool-level
datum, and it is **strictly negative** for `φ > 0`: both factors of
`ν = ℙ_{Δ_ARB}·g` fall in the fee.  So `ε` stops being an empirical primitive for
the arb half, and the conditional closure
`MevTaxReturns.Theorem44_O2_closes` — which needs exactly `ε < 0` — is available
with a computed elasticity.  (It remains conditional on the single-channel
reading, which `Theorem47_single_channel_root_is_not_a_root` shows is not the
consistent system.) -/
theorem Theorem47_epsilon_closes (sig Δt s kap phi : ℝ)
    (hsig : 0 < sig) (hΔt : 0 < Δt) (hphi0 : 0 < phi) (hphi1 : phi < 1)
    (hm : 0 < expOfCurv kap) (hu : 1 < bandRatio s phi) :
    ∃ D : ℝ, HasDerivAt (fun f => sharedNuArb sig Δt s kap f) D phi
      ∧ D < 0 ∧ 0 < sharedNuArb sig Δt s kap phi
      ∧ phi * D / sharedNuArb sig Δt s kap phi < 0 := by
  have hband : 0 < bandRatio s phi := lt_trans zero_lt_one hu
  have hPd := MevTaxLVR.hasDerivAt_ptrade_phi sig Δt phi hsig hΔt hphi0.le
  have hPneg := MevTaxLVR.dptrade_dphi_neg sig Δt phi hsig hΔt hphi0.le
  have hgd : HasDerivAt (fun f => gShock s f kap)
      (-((1 + s) * expOfCurv kap
        * (bandRatio s phi ^ (expOfCurv kap - 1)
          + bandRatio s phi ^ (-expOfCurv kap - 1)))) phi :=
    hasDerivAt_gOfRatio_phi s phi (expOfCurv kap) hm hphi1 hu
  have hgneg := dgOfRatio_phi_neg s phi (expOfCurv kap) hm hphi1 hu
  -- the participation probability is strictly positive
  have hc : 0 < Real.sqrt (2 / Δt) := Real.sqrt_pos.mpr (by positivity)
  have hPpos : 0 < MevOptimization.ptrade phi sig Δt := by
    unfold MevOptimization.ptrade
    have : 0 < sig + phi * Real.sqrt (2 / Δt) := by nlinarith
    exact div_pos hsig this
  -- the profile is strictly positive on the engaged branch
  have hgpos : 0 < gShock s phi kap := by
    unfold gShock gOfRatio
    rw [abs_pos]
    have hA : (1 : ℝ) < bandRatio s phi ^ expOfCurv kap :=
      Real.one_lt_rpow_iff_of_pos hband |>.mpr (Or.inl ⟨hu, hm⟩)
    have hB : bandRatio s phi ^ (-expOfCurv kap) < 1 := by
      rw [Real.rpow_neg hband.le, inv_lt_one_iff₀]
      exact Or.inr hA
    intro h
    have : bandRatio s phi ^ expOfCurv kap = bandRatio s phi ^ (-expOfCurv kap) := by linarith
    linarith [this ▸ hA]
  refine ⟨_, hPd.mul hgd, ?_, ?_, ?_⟩
  · have h1 : -(sig * Real.sqrt (2 / Δt)) / (sig + phi * Real.sqrt (2 / Δt)) ^ 2
        * gShock s phi kap < 0 := mul_neg_of_neg_of_pos hPneg hgpos
    have h2 : MevOptimization.ptrade phi sig Δt
        * -((1 + s) * expOfCurv kap
          * (bandRatio s phi ^ (expOfCurv kap - 1)
            + bandRatio s phi ^ (-expOfCurv kap - 1))) < 0 :=
      mul_neg_of_pos_of_neg hPpos hgneg
    linarith
  · exact mul_pos hPpos hgpos
  · have hnum : phi * (-(sig * Real.sqrt (2 / Δt)) / (sig + phi * Real.sqrt (2 / Δt)) ^ 2
        * gShock s phi kap
        + MevOptimization.ptrade phi sig Δt
          * -((1 + s) * expOfCurv kap
            * (bandRatio s phi ^ (expOfCurv kap - 1)
              + bandRatio s phi ^ (-expOfCurv kap - 1)))) < 0 := by
      have h1 : -(sig * Real.sqrt (2 / Δt)) / (sig + phi * Real.sqrt (2 / Δt)) ^ 2
          * gShock s phi kap < 0 := mul_neg_of_neg_of_pos hPneg hgpos
      have h2 : MevOptimization.ptrade phi sig Δt
          * -((1 + s) * expOfCurv kap
            * (bandRatio s phi ^ (expOfCurv kap - 1)
              + bandRatio s phi ^ (-expOfCurv kap - 1))) < 0 :=
        mul_neg_of_pos_of_neg hPpos hgneg
      have : (-(sig * Real.sqrt (2 / Δt)) / (sig + phi * Real.sqrt (2 / Δt)) ^ 2
          * gShock s phi kap
          + MevOptimization.ptrade phi sig Δt
            * -((1 + s) * expOfCurv kap
              * (bandRatio s phi ^ (expOfCurv kap - 1)
                + bandRatio s phi ^ (-expOfCurv kap - 1)))) < 0 := by linarith
      exact mul_neg_of_pos_of_neg hphi0 this
    exact div_neg_of_neg_of_pos hnum (mul_pos hPpos hgpos)

end MevTaxShock
