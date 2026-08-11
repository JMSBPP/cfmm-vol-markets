import Mathlib
import RequestProject.MevTaxProgram

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M25 — the LVR channel: does it cancel?  (Theorem 37 + Corollary 37)

This module formalizes block **M25** of `TAX3_ADDENDUM.md`: the proposal to
carry the LVR / net-profit channel of `DOC` **Proposition 9 (the MMR split)** in
the objective, on the theory that it would restore an interior optimum.

The MMR split at fast-block small-fee leading order is

`π^ARB ≈ π^LVR·ℙ_{Δ_ARB}`,  `π^φ ≈ π^LVR·(1-ℙ_{Δ_ARB})`,  `π^ARB + π^φ ≈ π^LVR`,

with `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` (`DOC` Definition 21, in-tree
`MevOptimization.ptrade`) evaluated at the **composed** fee `φ`, and
`π^LVR = σ²(i(t))·π^{varphi}(t)·Δt/8` in the CPMM case (`DOC:946`).  The
`φ`/`varphi` split is binding: `π^{varphi}` (portfolio value, `DOC` Definition
25) is a *different object* from `π^φ` (fee income); no identification is made.

Assumption **(A1)** (`SRC` Proposition 12): `π^φ` reaches `π̂^σ` only via `L`.
It is carried by giving the composite `π^φ ↦ π̂^σ` a single derivative, the
price-axis sum `∑_{i_K} (∂L(i_K)/∂π^φ)·π^l(σ(i_K;·))` (`priceAxisSum`).

Cited, never redone:

* `MevTaxControl.Theorem29_monoid_path_is_direct` (`MevTaxControl.lean`) —
  `∂φ/∂τ_MEV|_{φ_M,φ_X} = (1-φ_M)(1-φ_X) > 0`;
* `MevTaxProgram.Theorem33_path_decomposition`,
  `MevTaxProgram.Theorem33_five_factor_product_is_one_summand`,
  `MevTaxProgram.totalDeriv`, `MevTaxProgram.focCore`,
  `MevTaxProgram.Proposition16_corrected_law` (`MevTaxProgram.lean`);
* `MevOptimization.ptrade`, `MevOptimization.ptrade_strictAntiOn`,
  `MevOptimization.arb_add_fee_eq_lvr` (`MevOptimization.lean`);
* `MevTaxControl.H1_dLbar_dpiPhi_pos` — a **typed hypothesis**, never proved.

**Verdict returned by this module.**

1. The factorization of Theorem 37 is **TRUE** when `∂φ/∂ν` is read as the
   derivative of the **composed** fee in the utilization,
   `∂φ_total/∂ν = (1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)` — `Theorem37_LVR_cancellation`.
2. It is **FALSE** when `∂φ/∂ν` is read as `DOC` Definition 18's own gate
   derivative `∂φ_X/∂ν` (the boxed form of `ENTRY_POINT_dphi_dnu.md`): the
   literal bracket omits the monoid Jacobian `(1-φ_M)(1-τ_MEV)` on the gate
   summand.  Witness in `Theorem37_literal_bracket_refuted`.
3. `K > 0` holds under (H1), `π^l > 0`, `π^LVR > 0` and `∂ℙ_{Δ_ARB}/∂φ < 0`
   (`Theorem37_K_pos`), and `∂ℙ_{Δ_ARB}/∂φ < 0` holds **exactly where `σ > 0`**:
   at `σ = 0` the map `φ ↦ ℙ_{Δ_ARB}` is constant and `K = 0`
   (`ptrade_sigma_zero_const`, `Corollary37_root_invariance_fails_at_K_zero`).
4. Hence, on `σ > 0`, `K` is a strictly positive common factor and the zero set
   is unchanged: the proposal is **futile by construction**
   (`Corollary37_root_invariance`).
-/

namespace MevTaxLVR

/-! ## The MMR split (`DOC` Proposition 9) as carried objects -/

/-- The fee-income payoff of the MMR split: `π^φ ≈ π^LVR·(1-ℙ_{Δ_ARB})`. -/
noncomputable def piPhiFromLVR (piLVR pArb : ℝ) : ℝ := piLVR * (1 - pArb)

/-- The arb-extracted payoff of the MMR split: `π^ARB ≈ π^LVR·ℙ_{Δ_ARB}`. -/
noncomputable def piARBFromLVR (piLVR pArb : ℝ) : ℝ := piLVR * pArb

/-- The split adds up: `π^ARB + π^φ ≈ π^LVR`.  This is the in-tree bridge
identity `MevOptimization.arb_add_fee_eq_lvr` (`MevOptimization.lean`) in the
present notation; it is **not** MMR Theorem 3 formalized. -/
lemma piARB_add_piPhi_eq_piLVR (piLVR pArb : ℝ) :
    piARBFromLVR piLVR pArb + piPhiFromLVR piLVR pArb = piLVR := by
  unfold piARBFromLVR piPhiFromLVR; ring

/-- `π^LVR(t) = σ²(i(t))·π^{varphi}(t)·Δt/8`, the CPMM leading-order case
(`DOC:946`).  `π^{varphi}` is `DOC` Definition 25's **portfolio value function**
— distinct from the fee-income payoff `π^φ`. -/
noncomputable def piLVRcpmm (sigma2 piVarphi Δt : ℝ) : ℝ := sigma2 * piVarphi * Δt / 8

lemma piLVRcpmm_pos (sigma2 piVarphi Δt : ℝ) (hs : 0 < sigma2) (hp : 0 < piVarphi)
    (hΔ : 0 < Δt) : 0 < piLVRcpmm sigma2 piVarphi Δt := by
  unfold piLVRcpmm; positivity

/-- `π^LVR` vanishes identically at zero volatility — the same degeneracy that
kills `∂ℙ_{Δ_ARB}/∂φ` there. -/
lemma piLVRcpmm_sigma_zero (piVarphi Δt : ℝ) : piLVRcpmm 0 piVarphi Δt = 0 := by
  unfold piLVRcpmm; ring

/-! ## `ℙ_{Δ_ARB}` in the fee: the derivative, and where it is strict -/

/-- `∂ℙ_{Δ_ARB}/∂φ` for `ℙ_{Δ_ARB} = σ/(σ + φ√(2/Δt))` (`DOC` Definition 21,
in-tree `MevOptimization.ptrade`).  The fee is kept nonnegative, guarding the
Möbius pole at `φ = -σ/√(2/Δt)`. -/
lemma hasDerivAt_ptrade_phi (σ Δt φ : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt) (hφ : 0 ≤ φ) :
    HasDerivAt (fun f => MevOptimization.ptrade f σ Δt)
      (-(σ * Real.sqrt (2 / Δt)) / (σ + φ * Real.sqrt (2 / Δt)) ^ 2) φ := by
  have hc : 0 < Real.sqrt (2 / Δt) := Real.sqrt_pos.mpr (by positivity)
  have hden : 0 < σ + φ * Real.sqrt (2 / Δt) := by nlinarith
  have hd : HasDerivAt (fun f : ℝ => σ + f * Real.sqrt (2 / Δt))
      (Real.sqrt (2 / Δt)) φ := by
    simpa using ((hasDerivAt_id φ).mul_const (Real.sqrt (2 / Δt))).const_add σ
  have h := (hasDerivAt_const φ σ).div hd (ne_of_gt hden)
  simpa [MevOptimization.ptrade, zero_mul, zero_sub] using h

/-- Where `σ > 0`, `ℙ_{Δ_ARB}` is **strictly** decreasing in the fee: its
`φ`-derivative is strictly negative.  (Monotonicity itself is the cited
`MevOptimization.ptrade_strictAntiOn`.) -/
lemma dptrade_dphi_neg (σ Δt φ : ℝ) (hσ : 0 < σ) (hΔt : 0 < Δt) (hφ : 0 ≤ φ) :
    -(σ * Real.sqrt (2 / Δt)) / (σ + φ * Real.sqrt (2 / Δt)) ^ 2 < 0 := by
  have hc : 0 < Real.sqrt (2 / Δt) := Real.sqrt_pos.mpr (by positivity)
  have hden : 0 < σ + φ * Real.sqrt (2 / Δt) := by nlinarith
  have : 0 < (σ + φ * Real.sqrt (2 / Δt)) ^ 2 := by positivity
  apply div_neg_of_neg_of_pos _ this
  nlinarith

/-- **The answer to M25's falsification question.**  `ℙ_{Δ_ARB}` is *not*
strictly decreasing in `φ` on the whole admissible domain: at `σ = 0` the map
`φ ↦ ℙ_{Δ_ARB}(φ, 0, Δt)` is **identically zero**, hence constant, with
vanishing derivative.  Strict decrease holds exactly on `σ > 0`. -/
lemma ptrade_sigma_zero_const (Δt : ℝ) :
    (∀ φ : ℝ, MevOptimization.ptrade φ 0 Δt = 0) ∧
      (∀ φ : ℝ, HasDerivAt (fun f => MevOptimization.ptrade f 0 Δt) 0 φ) := by
  have h : (fun f : ℝ => MevOptimization.ptrade f 0 Δt) = fun _ : ℝ => (0 : ℝ) := by
    funext f; simp [MevOptimization.ptrade]
  refine ⟨fun φ => by simp [MevOptimization.ptrade], fun φ => ?_⟩
  rw [h]; exact hasDerivAt_const φ 0

/-! ## The factor `K` -/

/-- The price-axis outer factor `∑_{i_K} (∂L(i_K)/∂π^φ)·π^l(σ(i_K;·))` of M25's
`K`.  Under **(A1)** this is the whole derivative of the composite
`π^φ ↦ L ↦ π̂^σ`. -/
noncomputable def priceAxisSum (m : ℕ) (dLdpiPhi piEll : ℕ → ℝ) : ℝ :=
  ∑ iK ∈ Finset.range m, dLdpiPhi iK * piEll iK

/-- M25's `K = [∑_{i_K} (∂L(i_K)/∂π^φ)π^l]·[π^LVR·(-∂ℙ_{Δ_ARB}/∂φ)]`. -/
noncomputable def Kfactor (S piLVR dPdphi : ℝ) : ℝ := S * (piLVR * (-dPdphi))

/-- Under **(H1)** (`MevTaxControl.H1_dLbar_dpiPhi_pos`, never discharged), a
ladder of strictly positive geometric weights and a nonnegative leg payoff that
is positive somewhere, the price-axis sum is strictly positive.  This is the
same reading of the axis as `MevTaxControl.M18_axis_error_refuted`. -/
lemma priceAxisSum_pos_of_H1 (Lbar : ℝ → ℝ) (hLbar : Differentiable ℝ Lbar)
    (hH1 : MevTaxControl.H1_dLbar_dpiPhi_pos Lbar) (piPhi : ℝ) (m : ℕ)
    (ell piEll : ℕ → ℝ) (hell : ∀ iK, 0 < ell iK) (hpi : ∀ iK, 0 ≤ piEll iK)
    (hpos : ∃ iK < m, 0 < piEll iK) :
    0 < priceAxisSum m (fun iK => deriv (fun q => Lbar q * ell iK) piPhi) piEll := by
  obtain ⟨iK₀, hiK₀, hp₀⟩ := hpos
  have hd : ∀ iK, 0 < deriv (fun q => Lbar q * ell iK) piPhi := by
    intro iK
    rw [deriv_mul_const (hLbar piPhi)]
    exact mul_pos (hH1 piPhi) (hell iK)
  refine Finset.sum_pos' (fun i _ => mul_nonneg (le_of_lt (hd i)) (hpi i))
    ⟨iK₀, Finset.mem_range.mpr hiK₀, mul_pos (hd iK₀) hp₀⟩

/-- **Theorem 37, the sign of `K` [M25].**  `K > 0` under: the price-axis sum
strictly positive (**(H1)** plus `π^l > 0` — `priceAxisSum_pos_of_H1`),
`π^LVR > 0`, and `ℙ_{Δ_ARB}` strictly decreasing in `φ`
(`∂ℙ_{Δ_ARB}/∂φ < 0`, which by `dptrade_dphi_neg` holds exactly where
`σ > 0`). -/
theorem Theorem37_K_pos (S piLVR dPdphi : ℝ) (hS : 0 < S) (hL : 0 < piLVR)
    (hP : dPdphi < 0) : 0 < Kfactor S piLVR dPdphi := by
  unfold Kfactor
  have : 0 < piLVR * (-dPdphi) := mul_pos hL (by linarith)
  exact mul_pos hS this

/-- At `σ = 0` the factor collapses: `∂ℙ_{Δ_ARB}/∂φ = 0` forces `K = 0`
whatever the price-axis sum and `π^LVR` are. -/
lemma Kfactor_eq_zero_of_dP_zero (S piLVR : ℝ) : Kfactor S piLVR 0 = 0 := by
  unfold Kfactor; ring

/-! ## Theorem 37 — the factorization -/

/-- The bracket that the corrected FOC actually carries:
`(1-φ_M)(1-φ_X) + (1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)(∂ν/∂τ_MEV)`, i.e. `(1-φ_M)` times
`MevTaxProgram.focCore`.  The first summand is (P-direct)
(`MevTaxControl.Theorem29_monoid_path_is_direct`), the second (P-gate). -/
noncomputable def bracketTrue (phiM tauMEV phiXv dphiXdnu dnudtau : ℝ) : ℝ :=
  (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tauMEV) * (dphiXdnu * dnudtau)

/-- M25's bracket read **literally**, with `∂φ/∂ν` the bare gate derivative
`∂φ_X/∂ν` of `DOC` Definition 18: `(1-φ_M)(1-φ_X) + (∂φ_X/∂ν)(∂ν/∂τ_MEV)`. -/
noncomputable def bracketLiteral (phiM phiXv dphidnu dnudtau : ℝ) : ℝ :=
  (1 - phiM) * (1 - phiXv) + dphidnu * dnudtau

lemma bracketTrue_eq_focCore (phiM tauMEV phiXv dphiXdnu dnudtau : ℝ) :
    bracketTrue phiM tauMEV phiXv dphiXdnu dnudtau
      = (1 - phiM) * MevTaxProgram.focCore tauMEV phiXv dphiXdnu dnudtau := by
  unfold bracketTrue MevTaxProgram.focCore; ring

/-- Under the **composed-fee** reading of `∂φ/∂ν`, i.e.
`∂φ_total/∂ν = (1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)` — the reading of
`MevTaxProgram.Theorem33_five_factor_product_is_one_summand`(1) — M25's literal
bracket **is** the true bracket. -/
lemma bracketLiteral_composed_eq_bracketTrue (phiM tauMEV phiXv dphiXdnu dnudtau : ℝ) :
    bracketLiteral phiM phiXv ((1 - phiM) * (1 - tauMEV) * dphiXdnu) dnudtau
      = bracketTrue phiM tauMEV phiXv dphiXdnu dnudtau := by
  unfold bracketLiteral bracketTrue; ring

/-- **Theorem 37 (LVR cancellation) [M25].**  Carry the LVR channel in the
objective: `π^φ = π^LVR·(1-ℙ_{Δ_ARB}(φ_total))` (`DOC` Proposition 9), with the
composed fee `φ_total = φ_M ⊗_φ φ_X(ν(τ_MEV)) ⊗_φ τ_MEV` (Rule 12) and, by
**(A1)**, a single outer derivative `S = ∑_{i_K}(∂L(i_K)/∂π^φ)π^l` for the
composite `π^φ ↦ L ↦ π̂^σ`.  Then

`∂π̂^σ/∂τ_MEV = K·[(1-φ_M)(1-φ_X) + (1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)(∂ν/∂τ_MEV)]`,
`K = S·[π^LVR·(-∂ℙ_{Δ_ARB}/∂φ)]`.

The bracket is exactly `MevTaxProgram.totalDeriv 1 φ_M τ_MEV φ_X (∂φ_X/∂ν)
(∂ν/∂τ_MEV)` — the two-path sum of
`MevTaxProgram.Theorem33_path_decomposition`, with (P-direct) the monoid path of
`MevTaxControl.Theorem29_monoid_path_is_direct`.  So the LVR channel enters
**only** through the scalar `K`; it does not change the bracket. -/
theorem Theorem37_LVR_cancellation
    (Fhat : ℝ → ℝ) (m : ℕ) (dLdpiPhi piEll : ℕ → ℝ)
    (piLVR σ Δt phiM : ℝ) (phiX nu : ℝ → ℝ)
    (tauMEV dphiXdnu dnudtau dPdphi : ℝ)
    (hnu : HasDerivAt nu dnudtau tauMEV)
    (hphiX : HasDerivAt phiX dphiXdnu (nu tauMEV))
    (hP : HasDerivAt (fun f => MevOptimization.ptrade f σ Δt) dPdphi
      (MevTaxProgram.phiTot phiM phiX nu tauMEV))
    (hF : HasDerivAt Fhat (priceAxisSum m dLdpiPhi piEll)
      (piPhiFromLVR piLVR
        (MevOptimization.ptrade (MevTaxProgram.phiTot phiM phiX nu tauMEV) σ Δt))) :
    HasDerivAt
        (fun t => Fhat (piPhiFromLVR piLVR
          (MevOptimization.ptrade (MevTaxProgram.phiTot phiM phiX nu t) σ Δt)))
        (Kfactor (priceAxisSum m dLdpiPhi piEll) piLVR dPdphi *
          bracketTrue phiM tauMEV (phiX (nu tauMEV)) dphiXdnu dnudtau) tauMEV ∧
      bracketTrue phiM tauMEV (phiX (nu tauMEV)) dphiXdnu dnudtau
        = MevTaxProgram.totalDeriv 1 phiM tauMEV (phiX (nu tauMEV)) dphiXdnu dnudtau := by
  have hphi := MevTaxProgram.hasDerivAt_phiTot phiM phiX nu tauMEV dphiXdnu dnudtau hnu hphiX
  have hPc := hP.comp tauMEV hphi
  have hpiPhi : HasDerivAt
      (fun t => piPhiFromLVR piLVR
        (MevOptimization.ptrade (MevTaxProgram.phiTot phiM phiX nu t) σ Δt))
      (piLVR * (-(dPdphi *
        MevTaxProgram.totalDeriv 1 phiM tauMEV (phiX (nu tauMEV)) dphiXdnu dnudtau)))
      tauMEV := by
    have h := ((hPc.const_sub 1).const_mul piLVR)
    simpa [piPhiFromLVR] using h
  have hchain := hF.comp tauMEV hpiPhi
  constructor
  · convert hchain using 1
    unfold Kfactor bracketTrue MevTaxProgram.totalDeriv MevTaxProgram.pathDirect
      MevTaxProgram.pathGate
    ring
  · unfold bracketTrue MevTaxProgram.totalDeriv MevTaxProgram.pathDirect
      MevTaxProgram.pathGate
    ring

/-- **Theorem 37, the literal reading is REFUTED [M25].**  If `∂φ/∂ν` in M25's
display is read as `DOC` Definition 18's own gate derivative `∂φ_X/∂ν` (the
boxed form of `ENTRY_POINT_dphi_dnu.md`), the displayed bracket
`(1-φ_M)(1-φ_X) + (∂φ_X/∂ν)(∂ν/∂τ_MEV)` is **not** the bracket of the total
derivative: it omits the monoid Jacobian `(1-φ_M)(1-τ_MEV)` on the gate
summand.

Witness: `φ_M = 1/2`, `τ_MEV = 0`, `φ_X = 0`, `∂φ_X/∂ν = 1`,
`∂ν/∂τ_MEV = -1`.  There the true bracket is `1/2 + 1/2·1·(-1) = 0` while the
literal one is `1/2 + (-1) = -1/2`: the true FOC holds and the literal one does
not.  The two agree for **all** data iff the gate summand is read with the
composed fee (`bracketLiteral_composed_eq_bracketTrue`). -/
theorem Theorem37_literal_bracket_refuted :
    (¬ ∀ (phiM tauMEV phiXv dphiXdnu dnudtau : ℝ),
        bracketLiteral phiM phiXv dphiXdnu dnudtau
          = bracketTrue phiM tauMEV phiXv dphiXdnu dnudtau) ∧
      (∃ (phiM tauMEV phiXv dphiXdnu dnudtau : ℝ),
        0 < dphiXdnu ∧ dnudtau < 0 ∧ phiXv < 1 ∧ phiM < 1 ∧
          bracketTrue phiM tauMEV phiXv dphiXdnu dnudtau = 0 ∧
          bracketLiteral phiM phiXv dphiXdnu dnudtau ≠ 0) ∧
      (∀ (phiM tauMEV phiXv dphiXdnu dnudtau : ℝ),
        bracketLiteral phiM phiXv ((1 - phiM) * (1 - tauMEV) * dphiXdnu) dnudtau
          = bracketTrue phiM tauMEV phiXv dphiXdnu dnudtau) := by
  refine ⟨?_, ⟨1/2, 0, 0, 1, -1, by norm_num, by norm_num, by norm_num, by norm_num, ?_, ?_⟩,
    bracketLiteral_composed_eq_bracketTrue⟩
  · intro h
    have := h (1/2) 0 0 1 (-1)
    unfold bracketLiteral bracketTrue at this
    norm_num at this
  · unfold bracketTrue; norm_num
  · unfold bracketLiteral; norm_num

/-! ## Corollary 37 — root invariance, and where it fails -/

/-- **Corollary 37 (Root invariance) [M25].**  With `K ≠ 0` the LVR channel is a
nonzero common factor and the zero set of `∂π̂^σ/∂τ_MEV` is **unchanged** by
carrying `π^LVR` in the objective.  Under the M21 signs the root is exactly
`MevTaxProgram.Proposition16_corrected_law`'s

`τ* = 1 + (1-φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))`,

and the guarded domain lines of `Proposition 13` — the `|·|` form, `τ* < 1`, and
the `τ* > 0` iff — are restated **only under their antecedent**
`0 < ∂φ/∂ν`, `∂ν/∂τ_MEV < 0`, `φ_X < 1`, exactly as in the cited theorem.

Hence adding the LVR / net-profit channel to the objective cannot create,
destroy or move an interior optimum: the proposal is futile by construction. -/
theorem Corollary37_root_invariance
    (K A phiM tauMEV phiXv dphiXdnu dnudtau : ℝ)
    (hK : K ≠ 0) (hA : A ≠ 0) (hM : phiM ≠ 1) (hg : dphiXdnu * dnudtau ≠ 0) :
    ({t : ℝ | K * MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau = 0}
        = {t : ℝ | MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau = 0}) ∧
      (K * MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu dnudtau = 0
        ↔ tauMEV = 1 + (1 - phiXv) / (dphiXdnu * dnudtau)) ∧
      (0 < dphiXdnu → dnudtau < 0 → phiXv < 1 →
        ((K * MevTaxProgram.totalDeriv A phiM tauMEV phiXv dphiXdnu dnudtau = 0
            ↔ tauMEV = 1 - (1 - phiXv) / |dphiXdnu * dnudtau|) ∧
          (tauMEV = 1 + (1 - phiXv) / (dphiXdnu * dnudtau) → tauMEV < 1) ∧
          (tauMEV = 1 + (1 - phiXv) / (dphiXdnu * dnudtau) →
            (0 < tauMEV ↔ 1 - phiXv < |dphiXdnu * dnudtau|)))) := by
  obtain ⟨hmain, hguard⟩ :=
    MevTaxProgram.Proposition16_corrected_law A phiM tauMEV phiXv dphiXdnu dnudtau hA hM hg
  have hcancel : ∀ t : ℝ,
      K * MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau = 0
        ↔ MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau = 0 := by
    intro t
    constructor
    · intro h
      rcases mul_eq_zero.mp h with h1 | h1
      · exact absurd h1 hK
      · exact h1
    · intro h; rw [h, mul_zero]
  refine ⟨Set.ext (fun t => hcancel t), (hcancel tauMEV).trans hmain, ?_⟩
  intro h1 h2 h3
  obtain ⟨habs, hlt, hiff⟩ := hguard h1 h2 h3
  exact ⟨(hcancel tauMEV).trans habs, hlt, hiff⟩

/-- **Corollary 37, the boundary case [M25].**  Root invariance needs `K ≠ 0`,
and `K = 0` is *not* vacuous: at `σ = 0` the trade probability is constant in
the fee (`ptrade_sigma_zero_const`) and `π^LVR = σ²π^{varphi}Δt/8 = 0`
(`piLVRcpmm_sigma_zero`), so `K = 0` on both factors.  There the LVR-carrying
objective has **every** tax as a root while the un-carried FOC has at most one:
the zero set is not invariant.  The `σ = 0` slice is therefore excluded from
Corollary 37, and this is the precise answer to M25's falsification question —
`ℙ_{Δ_ARB}` is strictly decreasing in `φ` only where `σ > 0`. -/
theorem Corollary37_root_invariance_fails_at_K_zero :
    ∃ (K A phiM phiXv dphiXdnu dnudtau : ℝ),
      K = 0 ∧ A ≠ 0 ∧ phiM ≠ 1 ∧ dphiXdnu * dnudtau ≠ 0 ∧
        {t : ℝ | K * MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau = 0}
          = Set.univ ∧
        {t : ℝ | MevTaxProgram.totalDeriv A phiM t phiXv dphiXdnu dnudtau = 0}
          ≠ Set.univ := by
  refine ⟨0, 1, 0, 0, 1, -1, rfl, one_ne_zero, by norm_num, by norm_num, ?_, ?_⟩
  · ext t; simp
  · intro h
    have h1 : (1 : ℝ) ∈ {t : ℝ | MevTaxProgram.totalDeriv 1 0 t 0 1 (-1) = 0} := by
      rw [h]; trivial
    simp only [Set.mem_setOf_eq, MevTaxProgram.totalDeriv, MevTaxProgram.pathDirect,
      MevTaxProgram.pathGate] at h1
    norm_num at h1

end MevTaxLVR
