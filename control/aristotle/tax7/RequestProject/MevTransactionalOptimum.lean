import Mathlib
import RequestProject.MevTransactional

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M37–M40 — the optimum of the transactional channel (Theorems 49–52)

Continuation of `RequestProject.MevTransactional` (which carries the primitives
and **M36 / Theorem 48**).  This module carries:

* the pointwise first-order sign laws at a stationary point (valid for an
  arbitrary differentiable participation probability `h`);
* **M38 / Theorem 50** — the top-up law, pro-cyclicality, the corner taxonomy,
  and the two refutations of the profitability condition read as an iff;
* **M37 / Theorem 49** — the exogenous input and the named relaxed hypothesis;
* **M39 / Theorem 51** — the incidence question, no-routing versus full routing;
* **M40 / Theorem 52** — the second-order condition and the failure of single
  crossing.
-/

namespace MevTaxTransactional

open MeasureTheory ProbabilityTheory

/-! ## The pointwise laws at a stationary point

Everything in this section holds for an **arbitrary** differentiable
participation probability `h` (only its value `hval > 0` and slope `dh` enter);
**(A-tail)** is *not* used.  This is the M40 split: the sign laws survive for
general `h`, and (A-tail) contributes only the counting of stationary points
(`Theorem52_at_most_two_stationary_points`). -/

/-- Closed form of the objective: `m = (K h cφ - Lvrσ)/(σ+cφ)`. -/
lemma mObj_eq (Kf hh : ℝ → ℝ) (phi sig c Lvr : ℝ) (hden : sig + phi * c ≠ 0) :
    mObj Kf hh phi sig c Lvr
      = (Kf phi * hh phi * (phi * c) - Lvr * sig) / (sig + phi * c) := by
  rw [mObj, ntFee, one_sub_pArb_eq phi sig c hden, pArb]
  field_simp

/-- **Theorem 50(b) [M38] — the carrier analogue of `φ* > 1/α`, under (A-route).**
At any interior stationary point of `m` with the LP-accrued fee **constant**
(`dK = 0`, the no-routing case), `-h'(φ*)φ*(σ+cφ*) > h(φ*)σ`; under **(A-tail)**
(`h' = -αh`) this reads

`αφ*(σ + cφ*) > σ`, equivalently `αφ* > ℙ_{Δ_ARB}(φ*)`,

the exact carrier analogue: the literature's `φ* > 1/α` is **weakened** by the
arb-deterrence channel, which pays for part of the fee. -/
theorem Theorem50b_carrier_analogue_noroute (Kv hval dh phi sig c Lvr : ℝ)
    (hstat : focRed Kv 0 hval dh phi sig c Lvr = 0)
    (hK : 0 < Kv) (hLvr : 0 < Lvr) (hsig : 0 < sig) :
    hval * sig < -dh * (phi * (sig + phi * c)) := by
  rw [focRed] at hstat
  nlinarith [mul_pos hLvr hsig]

/-- **Theorem 50(b) [M38], (A-tail) form.**  `αφ*(σ+cφ*) > σ`, i.e.
`αφ* > ℙ_{Δ_ARB}(φ*)`. -/
theorem Theorem50b_carrier_analogue_noroute_tail (Kv al phi sig c Lvr : ℝ)
    (hstat : focRed Kv 0 (hazTail al phi) (-al * hazTail al phi) phi sig c Lvr = 0)
    (hK : 0 < Kv) (hLvr : 0 < Lvr) (hsig : 0 < sig) (hphi : 0 < phi) (hc : 0 < c) :
    sig < al * phi * (sig + phi * c) ∧ pArb phi sig c < al * phi := by
  have h := Theorem50b_carrier_analogue_noroute Kv (hazTail al phi)
    (-al * hazTail al phi) phi sig c Lvr hstat hK hLvr hsig
  have hh : 0 < hazTail al phi := hazTail_pos al phi
  have hden : 0 < sig + phi * c := by positivity
  have h1 : sig < al * phi * (sig + phi * c) := by
    have := h
    nlinarith
  refine ⟨h1, ?_⟩
  rw [pArb, div_lt_iff₀ hden]
  nlinarith

/-- **Theorem 50(b) [M38] — the analogue under counterfactual FULL routing is the
literature's own bound.**  With `f_LP(φ) = φ` (`Kv = δφ`, `dK = δ`), any interior
stationary point satisfies `-h'(φ*)φ* > h(φ*)`, i.e. under (A-tail)
**`φ* > 1/α`** exactly. -/
theorem Theorem50b_carrier_analogue_route (delt hval dh phi sig c Lvr : ℝ)
    (hstat : focRed (delt * phi) delt hval dh phi sig c Lvr = 0)
    (hd : 0 < delt) (hphi : 0 < phi) (hc : 0 < c) (hsig : 0 < sig)
    (hh : 0 < hval) (hLvr : 0 < Lvr) :
    hval < -dh * phi := by
  rw [focRed] at hstat
  have hden : 0 < sig + phi * c := by positivity
  have hdp : 0 < delt * phi := mul_pos hd hphi
  have key : (delt * phi) * (hval * (sig + phi * c) + hval * sig + dh * (phi * (sig + phi * c)))
      = -(Lvr * sig) := by linear_combination hstat
  have h2 : hval * (sig + phi * c) + hval * sig + dh * (phi * (sig + phi * c)) < 0 := by
    by_contra hcon
    push_neg at hcon
    nlinarith [mul_nonneg hdp.le hcon, mul_pos hLvr hsig]
  have h3 : (hval + dh * phi) * (sig + phi * c) < 0 := by nlinarith [mul_pos hh hsig]
  by_contra hcon
  push_neg at hcon
  nlinarith [mul_nonneg (by linarith : (0:ℝ) ≤ hval + dh * phi) hden.le]

/-- **Theorem 50(b), (A-tail) form under full routing: `φ* > 1/α`.** -/
theorem Theorem50b_carrier_analogue_route_tail (delt al phi sig c Lvr : ℝ)
    (hstat : focRed (delt * phi) delt (hazTail al phi) (-al * hazTail al phi)
      phi sig c Lvr = 0)
    (hd : 0 < delt) (hphi : 0 < phi) (hc : 0 < c) (hsig : 0 < sig)
    (hLvr : 0 < Lvr) (hal : 0 < al) : 1 / al < phi := by
  have h := Theorem50b_carrier_analogue_route delt (hazTail al phi)
    (-al * hazTail al phi) phi sig c Lvr hstat hd hphi hc hsig (hazTail_pos al phi) hLvr
  have hh : 0 < hazTail al phi := hazTail_pos al phi
  have h1 : 1 < al * phi := by nlinarith
  rw [div_lt_iff₀ hal]
  nlinarith

/-- **Theorem 50(a) [M38] — the profitability law under (A-route), stated
exactly.**  At an interior stationary point the sign of the LP PnL drift is
decided by a **threshold on `αφ*`**, not by a separate condition:

`m(φ*) < 0 ⟺ -h'(φ*)φ* > h(φ*)`, i.e. under (A-tail) `⟺ αφ* > 1`.

So the interior stationary point is profitable exactly when `αφ* < 1`. -/
theorem Theorem50a_sign_law_noroute (Kf hh : ℝ → ℝ) (Kv hval dh phi sig c Lvr : ℝ)
    (hKv : Kf phi = Kv) (hhv : hh phi = hval)
    (hstat : focRed Kv 0 hval dh phi sig c Lvr = 0)
    (hK : 0 < Kv) (hsig : 0 < sig) (hc : 0 < c) (hphi : 0 < phi) :
    (mObj Kf hh phi sig c Lvr < 0 ↔ hval < -dh * phi) := by
  have hden : 0 < sig + phi * c := by positivity
  rw [mObj_eq Kf hh phi sig c Lvr hden.ne', hKv, hhv, div_lt_iff₀ hden, zero_mul]
  rw [focRed] at hstat
  have key : Kv * ((hval + dh * phi) * (sig + phi * c))
      = Kv * hval * (phi * c) - Lvr * sig := by linear_combination hstat
  constructor
  · intro h
    by_contra hcon
    push_neg at hcon
    nlinarith [mul_nonneg (mul_nonneg hK.le (by linarith : (0:ℝ) ≤ hval + dh * phi)) hden.le]
  · intro h
    nlinarith [mul_pos hK (mul_pos_of_neg_of_neg (by linarith : hval + dh * phi < 0)
      (by linarith : (0:ℝ) - (sig + phi * c) < 0))]

/-- **Theorem 50(a) [M38] — the same law under counterfactual FULL routing, with
threshold `2` instead of `1`.**  `m(φ*) < 0 ⟺ -h'(φ*)φ* > 2h(φ*)`, i.e. under
(A-tail) `⟺ αφ* > 2`.  Routing the tax revenue to LPs buys exactly one unit of
the threshold. -/
theorem Theorem50a_sign_law_route (Kf hh : ℝ → ℝ) (delt hval dh phi sig c Lvr : ℝ)
    (hKv : Kf phi = delt * phi) (hhv : hh phi = hval)
    (hstat : focRed (delt * phi) delt hval dh phi sig c Lvr = 0)
    (hd : 0 < delt) (hsig : 0 < sig) (hc : 0 < c) (hphi : 0 < phi) :
    (mObj Kf hh phi sig c Lvr < 0 ↔ 2 * hval < -dh * phi) := by
  have hden : 0 < sig + phi * c := by positivity
  have hdp : 0 < delt * phi := mul_pos hd hphi
  rw [mObj_eq Kf hh phi sig c Lvr hden.ne', hKv, hhv, div_lt_iff₀ hden, zero_mul]
  rw [focRed] at hstat
  have key : (delt * phi) * ((2 * hval + dh * phi) * (sig + phi * c))
      = delt * phi * hval * (phi * c) - Lvr * sig := by linear_combination hstat
  constructor
  · intro h
    by_contra hcon
    push_neg at hcon
    nlinarith [mul_nonneg (mul_nonneg hdp.le (by linarith : (0:ℝ) ≤ 2 * hval + dh * phi)) hden.le]
  · intro h
    nlinarith [mul_pos hdp (mul_pos_of_neg_of_neg (by linarith : 2 * hval + dh * phi < 0)
      (by linarith : (0:ℝ) - (sig + phi * c) < 0))]

/-! ## M38 (c)–(e).  The top-up law, pro-cyclicality, the corner taxonomy -/

/-- The monoid carrier: `1 - φ = (1-φ_base)(1-τ)` with
`φ_base = 1 - (1-φ_M)(1-φ_X)` — `MevTaxControl.Theorem29_monoid_path_is_direct`'s
composition, written as a map `τ ↦ φ`. -/
noncomputable def phiOfTau (phibase tau : ℝ) : ℝ := 1 - (1 - phibase) * (1 - tau)

lemma phiOfTau_legs (phiM phiX tau : ℝ) :
    1 - phiOfTau (1 - (1 - phiM) * (1 - phiX)) tau = (1 - phiM) * (1 - phiX) * (1 - tau) := by
  unfold phiOfTau; ring

lemma phiOfTau_zero (phibase : ℝ) : phiOfTau phibase 0 = phibase := by
  unfold phiOfTau; ring

/-- **Theorem 50(c) [M38] — THE TOP-UP LAW.**  On the monoid carrier the optimal
tax is the *top-up* from the leg fees to the optimal composed fee,

`τ* = (φ* - φ_base)/(1 - φ_base)`,

and `τ* ∈ (0,1) ⇔ φ_base < φ* < 1`.  `τ* = 0` is the honest answer when the base
fee already covers `φ*`. -/
theorem Theorem50c_top_up_law (phibase phistar : ℝ) (hb : phibase < 1) :
    phiOfTau phibase ((phistar - phibase) / (1 - phibase)) = phistar
      ∧ (0 < (phistar - phibase) / (1 - phibase) ↔ phibase < phistar)
      ∧ ((phistar - phibase) / (1 - phibase) < 1 ↔ phistar < 1) := by
  have h1 : (0:ℝ) < 1 - phibase := by linarith
  refine ⟨?_, ?_, ?_⟩
  · unfold phiOfTau
    field_simp
    ring
  · rw [div_pos_iff]
    constructor
    · rintro (⟨h, -⟩ | ⟨-, h⟩)
      · linarith
      · linarith
    · intro h; exact Or.inl ⟨by linarith, h1⟩
  · rw [div_lt_one h1]
    constructor <;> intro h <;> linarith

/-- The `σ`-partial of the reduced FOC, `∂Φ/∂σ`, with `Lvr = σ²Δt/8` carrying its
own `σ`-dependence (`∂(Lvr·σ)/∂σ = 3Lvr`). -/
noncomputable def focRedDsig (Kv dK hval dh phi Lvr : ℝ) : ℝ :=
  dK * hval * phi + Kv * (hval + dh * phi) + 3 * Lvr

/-- `focRedDsig` *is* the `σ`-derivative of the reduced FOC. -/
lemma hasDerivAt_focRed_sig (Kv dK hval dh phi c Δt sig : ℝ) :
    HasDerivAt (fun s => focRed Kv dK hval dh phi s c (lvrCoef s Δt))
      (focRedDsig Kv dK hval dh phi (lvrCoef sig Δt)) sig := by
  have h1 : HasDerivAt (fun s : ℝ => dK * hval * (phi * (s + phi * c))) (dK * hval * phi) sig := by
    have : HasDerivAt (fun s : ℝ => phi * (s + phi * c)) phi sig := by
      simpa using (((hasDerivAt_id sig).add_const (phi * c)).const_mul phi)
    simpa [mul_comm, mul_left_comm, mul_assoc] using this.const_mul (dK * hval)
  have h2 : HasDerivAt (fun s : ℝ => Kv * (hval * s + dh * (phi * (s + phi * c))))
      (Kv * (hval + dh * phi)) sig := by
    have ha : HasDerivAt (fun s : ℝ => hval * s) hval sig := by
      simpa using (hasDerivAt_id sig).const_mul hval
    have hb : HasDerivAt (fun s : ℝ => dh * (phi * (s + phi * c))) (dh * phi) sig := by
      have : HasDerivAt (fun s : ℝ => phi * (s + phi * c)) phi sig := by
        simpa using (((hasDerivAt_id sig).add_const (phi * c)).const_mul phi)
      simpa [mul_comm, mul_left_comm, mul_assoc] using this.const_mul dh
    simpa using (ha.add hb).const_mul Kv
  have h3 : HasDerivAt (fun s : ℝ => lvrCoef s Δt * s) (3 * lvrCoef sig Δt) sig := by
    have : HasDerivAt (fun s : ℝ => s ^ 3 * Δt / 8) (3 * sig ^ 2 * Δt / 8) sig := by
      have hp : HasDerivAt (fun s : ℝ => s ^ 3) (3 * sig ^ 2) sig := by
        simpa using (hasDerivAt_pow 3 sig)
      simpa [mul_comm, mul_assoc, div_eq_mul_inv] using (hp.mul_const Δt).div_const 8
    refine this.congr_deriv ?_ |>.congr_of_eventuallyEq ?_
    · rw [lvrCoef]; ring
    · filter_upwards with s
      rw [lvrCoef]; ring
  simpa [focRed, focRedDsig] using (h1.add h2).add h3

/-- **Theorem 50(d) [M38] — PRO-CYCLICALITY, the load-bearing sign.**  At *any*
interior stationary point (either routing regime, any differentiable `h > 0`),
the `σ`-partial of the reduced FOC is **strictly positive**:

`σ(σ+cφ)·∂Φ/∂σ = K h σ cφ + Lvrσ(2σ+3cφ) > 0`,

the `dK` terms cancelling identically.  Combined with `∂Φ/∂φ < 0` at a maximum
this gives `∂φ*/∂σ > 0` (`Theorem50d_procyclicality`). -/
theorem Theorem50d_focRedDsig_pos (Kv dK hval dh phi sig c Lvr : ℝ)
    (hstat : focRed Kv dK hval dh phi sig c Lvr = 0)
    (hK : 0 < Kv) (hh : 0 < hval) (hphi : 0 < phi) (hsig : 0 < sig) (hc : 0 < c)
    (hLvr : 0 < Lvr) : 0 < focRedDsig Kv dK hval dh phi Lvr := by
  have hden : 0 < sig + phi * c := by positivity
  have key : sig * (sig + phi * c) * focRedDsig Kv dK hval dh phi Lvr
      = Kv * hval * sig * (phi * c) + Lvr * sig * (2 * sig + 3 * (phi * c)) := by
    rw [focRedDsig, focRed] at *
    linear_combination sig * hstat
  have hpos : 0 < Kv * hval * sig * (phi * c) + Lvr * sig * (2 * sig + 3 * (phi * c)) := by
    have h1 : 0 < Kv * hval * sig * (phi * c) := by positivity
    have h2 : 0 < Lvr * sig * (2 * sig + 3 * (phi * c)) := by positivity
    linarith
  nlinarith [mul_pos hsig hden]

/-- **Theorem 50(d) [M38] — the controller is a volatility feedback.**  For a
differentiable selection `σ ↦ φ*(σ)` of interior maximisers (the chain rule
`Φ_φ·φ*' + Φ_σ = 0` is the typed hypothesis), `∂φ*/∂σ > 0` and hence
`∂τ*/∂σ > 0`: the tax rises with volatility. -/
theorem Theorem50d_procyclicality (dphistar Phi_phi Phi_sig phibase : ℝ)
    (hchain : Phi_phi * dphistar + Phi_sig = 0) (hmax : Phi_phi < 0) (hsig : 0 < Phi_sig)
    (hb : phibase < 1) :
    0 < dphistar ∧ 0 < dphistar / (1 - phibase) := by
  have h1 : 0 < dphistar := by
    rcases lt_trichotomy dphistar 0 with h | h | h
    · nlinarith
    · rw [h] at hchain; simp at hchain; linarith
    · exact h
  exact ⟨h1, div_pos h1 (by linarith)⟩

/-- **Theorem 50(e) [M38] — the corner `τ* = 0`.**  If the objective is strictly
decreasing above the base fee, the constrained optimum is the corner: every
positive tax is strictly worse.  This is the honest reading of `τ* = 0` — the
base fee already covers `φ*`. -/
theorem Theorem50e_corner_at_zero (m : ℝ → ℝ) (phibase : ℝ) (hb1 : phibase < 1)
    (hanti : StrictAntiOn m (Set.Ico phibase 1)) :
    ∀ tau ∈ Set.Ioo (0:ℝ) 1, m (phiOfTau phibase tau) < m (phiOfTau phibase 0) := by
  rintro tau ⟨ht0, ht1⟩
  have hlt : phibase < phiOfTau phibase tau := by
    unfold phiOfTau; nlinarith
  have hlt1 : phiOfTau phibase tau < 1 := by
    unfold phiOfTau; nlinarith
  rw [phiOfTau_zero]
  exact hanti ⟨le_refl _, hb1⟩ ⟨hlt.le, hlt1⟩ hlt

/-- **Theorem 50(e) [M38] — the shutdown regime, stated as loss minimization.**
If `m < 0` at every admissible fee then no tax makes the pool profitable: the
constrained program on `[0,1)` is a **minimization of losses**, and its solution
is not an optimum of anything but losses. -/
theorem Theorem50e_shutdown_is_loss_minimization (m : ℝ → ℝ) (phibase : ℝ)
    (hb1 : phibase < 1) (hb0 : 0 ≤ phibase)
    (hneg : ∀ phi ∈ Set.Ico (0:ℝ) 1, m phi < 0) :
    ∀ tau ∈ Set.Ico (0:ℝ) 1, m (phiOfTau phibase tau) < 0 := by
  rintro tau ⟨ht0, ht1⟩
  refine hneg _ ⟨?_, ?_⟩ <;> unfold phiOfTau <;> nlinarith

/-! ## The (A-tail) reduced FOC and the explicit witness

The witness fixes `Δt = 2` (so `c = √(2/Δt) = 1`), `σ = 1/3` (so
`Lvr = σ²Δt/8 = 1/36`), `α = 10`, and `f_LPδ = 1` — e.g. `φ_base = 1/100`,
`δ = 100` under **(A-route)**.  No claim is made that `α = 10` is estimated:
the register records that **no causal estimate of `α` exists**, and the witness
is a *witness*, not a calibration. -/

/-- The reduced FOC under **(A-tail)** and **(A-route)** (`dK = 0`, `h' = -αh`):
`Φ(φ) = K e^{-αφ}(σ - αφ(σ+cφ)) + Lvrσ`. -/
noncomputable def focTail (K al phi sig c Lvr : ℝ) : ℝ :=
  focRed K 0 (hazTail al phi) (-al * hazTail al phi) phi sig c Lvr

lemma focTail_eq (K al phi sig c Lvr : ℝ) :
    focTail K al phi sig c Lvr
      = K * hazTail al phi * (sig - al * (phi * (sig + phi * c))) + Lvr * sig := by
  rw [focTail, focRed]; ring

lemma cRate_two : cRate 2 = 1 := by
  rw [cRate]; norm_num

lemma lvrCoef_witness : lvrCoef (1/3) 2 = 1/36 := by
  rw [lvrCoef]; norm_num

lemma continuous_focTail (K al sig c Lvr : ℝ) :
    Continuous (fun phi => focTail K al phi sig c Lvr) := by
  simp only [focTail_eq, hazTail]
  fun_prop

private lemma exp_neg_nat_inv (n : ℕ) : Real.exp (-(n : ℝ)) = (Real.exp 1 ^ n)⁻¹ := by
  rw [Real.exp_neg, ← Real.exp_nat_mul]
  norm_num

private lemma exp_neg_two_gt : (1 : ℝ)/8 < Real.exp (-2 : ℝ) := by
  have h : Real.exp (-(2 : ℝ)) = (Real.exp 1 ^ 2)⁻¹ := by
    simpa using exp_neg_nat_inv 2
  rw [show (-2 : ℝ) = -(2 : ℝ) by norm_num, h]
  have hlt : Real.exp 1 ^ 2 < 8 := by
    have := Real.exp_one_lt_d9
    nlinarith [Real.exp_pos 1]
  have hpos : (0:ℝ) < Real.exp 1 ^ 2 := by positivity
  rw [lt_inv_comm₀ (by norm_num) hpos]
  linarith

private lemma exp_neg_eight_lt : Real.exp (-8 : ℝ) < 1/2000 := by
  have h : Real.exp (-(8 : ℝ)) = (Real.exp 1 ^ 8)⁻¹ := by
    simpa using exp_neg_nat_inv 8
  rw [show (-8 : ℝ) = -(8 : ℝ) by norm_num, h]
  have h1 : (2.7 : ℝ) < Real.exp 1 := by
    have := Real.exp_one_gt_d9; linarith
  have hp : (0:ℝ) < Real.exp 1 := Real.exp_pos 1
  have h2 : (7.29 : ℝ) < Real.exp 1 ^ 2 := by nlinarith
  have h4 : (53 : ℝ) < Real.exp 1 ^ 4 := by nlinarith
  have hgt : (2000 : ℝ) < Real.exp 1 ^ 8 := by nlinarith
  have hpos : (0:ℝ) < Real.exp 1 ^ 8 := by positivity
  rw [inv_lt_comm₀ hpos (by norm_num)]
  linarith

/-- The witness's reduced FOC: `Φ_w(φ) = e^{-10φ}(1/3 - 10φ(1/3+φ)) + 1/108`. -/
noncomputable def focW (phi : ℝ) : ℝ := focTail 1 10 phi (1/3) 1 (1/36)

lemma focW_pos_at_hundredth : 0 < focW (1/100) := by
  rw [focW, focTail_eq]
  have hh : 0 < hazTail 10 (1/100 : ℝ) := hazTail_pos _ _
  have hnum : (0:ℝ) < 1/3 - 10 * (1/100 * (1/3 + 1/100 * 1)) := by norm_num
  nlinarith

lemma focW_neg_at_fifth : focW (1/5) < 0 := by
  rw [focW, focTail_eq]
  have hval : hazTail 10 (1/5 : ℝ) = Real.exp (-2 : ℝ) := by
    rw [hazTail]; norm_num
  rw [hval]
  have hb := exp_neg_two_gt
  have hnum : (1:ℝ)/3 - 10 * (1/5 * (1/3 + 1/5 * 1)) = -(11/15) := by norm_num
  rw [hnum]
  nlinarith

lemma focW_pos_at_four_fifths : 0 < focW (4/5) := by
  rw [focW, focTail_eq]
  have hval : hazTail 10 (4/5 : ℝ) = Real.exp (-8 : ℝ) := by
    rw [hazTail]; norm_num
  rw [hval]
  have hb := exp_neg_eight_lt
  have hpos := Real.exp_pos (-8 : ℝ)
  have hnum : (1:ℝ)/3 - 10 * (4/5 * (1/3 + 4/5 * 1)) = -(131/15) := by norm_num
  rw [hnum]
  nlinarith

/-- **The witness has TWO interior stationary points, with sign pattern `+,-,+`.**
This single object serves M37 (the root exists), M38(a) (existence) and M40
(single crossing fails **even under (A-tail)**). -/
theorem focW_two_roots :
    ∃ phi1 ∈ Set.Ioo (1/100 : ℝ) (1/5), ∃ phi2 ∈ Set.Ioo (1/5 : ℝ) (4/5),
      focW phi1 = 0 ∧ focW phi2 = 0 ∧ phi1 < phi2 := by
  have hcont : Continuous focW := by
    unfold focW
    exact continuous_focTail 1 10 (1/3) 1 (1/36)
  have h1 : (0:ℝ) ∈ Set.Ioo (focW (1/5)) (focW (1/100)) :=
    ⟨focW_neg_at_fifth, focW_pos_at_hundredth⟩
  have hsub1 := intermediate_value_Ioo' (by norm_num : (1/100 : ℝ) ≤ 1/5)
    hcont.continuousOn
  obtain ⟨phi1, hmem1, hval1⟩ := hsub1 h1
  have h2 : (0:ℝ) ∈ Set.Ioo (focW (1/5)) (focW (4/5)) :=
    ⟨focW_neg_at_fifth, focW_pos_at_four_fifths⟩
  have hsub2 := intermediate_value_Ioo (by norm_num : (1/5 : ℝ) ≤ 4/5)
    hcont.continuousOn
  obtain ⟨phi2, hmem2, hval2⟩ := hsub2 h2
  exact ⟨phi1, hmem1, phi2, hmem2, hval1, hval2, lt_trans hmem1.2 hmem2.1⟩

/-! ## M37.  Theorem 49 — the loop gains an exogenous input

`MevTaxShock.Theorem47_no_exogenous_hazard_input` says: *two taxes producing the
same composed fee at every event produce the same hazard* — the composed fee is
a **sufficient statistic** for the tax's effect.  That is the premise M37
relaxes, and **nothing else**.  Under **(A-route)** the LP-accrued fee is the
*leg* fee, so the objective depends on `(φ_base, τ)` and not on the composed fee
alone; under counterfactual full routing it does depend on the composed fee
alone, and the premise holds.  The two results therefore stand side by side. -/

/-- The premise of `MevTaxShock.Theorem47_no_exogenous_hazard_input`, transported
from the hazard to the LP objective: **the composed fee is a sufficient
statistic** for the tax's effect. -/
def FeeSufficient (obj : ℝ → ℝ → ℝ) : Prop :=
  ∀ b1 t1 b2 t2 : ℝ, phiOfTau b1 t1 = phiOfTau b2 t2 → obj b1 t1 = obj b2 t2

/-- The LP objective under **(A-route)**: the LP accrues the *leg* fee `δ·φ_base`
(`DOC` Rule 6; `DOC` Theorem 20 monoid entry (A), *NO compensation routed*). -/
noncomputable def objNoRoute (delt al sig c Lvr : ℝ) (phibase tau : ℝ) : ℝ :=
  mObj (fun _ => delt * phibase) (hazTail al) (phiOfTau phibase tau) sig c Lvr

/-- The LP objective under the counterfactual **full routing** `f_LP(φ) = φ`. -/
noncomputable def objRoute (delt al sig c Lvr : ℝ) (phibase tau : ℝ) : ℝ :=
  mObj (fun f => delt * f) (hazTail al) (phiOfTau phibase tau) sig c Lvr

/-- **Theorem 49 [M37], the hypothesis that is NOT relaxed.**  Under full routing
the composed fee *is* a sufficient statistic — `Theorem47`'s premise holds
verbatim, and with it `Theorem47`'s verdict. -/
theorem Theorem49_full_routing_keeps_fee_sufficiency (delt al sig c Lvr : ℝ) :
    FeeSufficient (objRoute delt al sig c Lvr) := by
  intro b1 t1 b2 t2 h
  unfold objRoute
  rw [h]

/-- **Theorem 49 [M37], THE RELAXED HYPOTHESIS, named and refuted.**  Under
**(A-route)** the composed fee is **not** a sufficient statistic: two
`(φ_base, τ)` configurations with the *same* composed fee `φ = 1/2` — leg fees
`φ_base = 1/2` with `τ = 0`, versus `φ_base = 0` with `τ = 1/2` — give different
LP income, because the `τ` share is not routed to LPs.  This is exactly the
premise of `MevTaxShock.Theorem47_no_exogenous_hazard_input`, and it is the only
one relaxed. -/
theorem Theorem49_no_routing_breaks_fee_sufficiency (delt al sig c Lvr : ℝ)
    (hd : 0 < delt) (hsig : 0 < sig) (hc : 0 < c) :
    ¬ FeeSufficient (objNoRoute delt al sig c Lvr) := by
  intro hsuff
  have hphi : phiOfTau (1/2) 0 = phiOfTau 0 (1/2) := by
    unfold phiOfTau; norm_num
  have h := hsuff (1/2) 0 0 (1/2) hphi
  unfold objNoRoute at h
  have hval : phiOfTau (1/2 : ℝ) 0 = 1/2 := by unfold phiOfTau; norm_num
  have hval2 : phiOfTau (0 : ℝ) (1/2) = 1/2 := by unfold phiOfTau; norm_num
  rw [hval, hval2] at h
  have hden : sig + (1/2 : ℝ) * c ≠ 0 := by positivity
  rw [mObj_eq _ _ _ _ _ _ hden, mObj_eq _ _ _ _ _ _ hden] at h
  have hposden : (0:ℝ) < sig + (1/2 : ℝ) * c := by positivity
  have hnum : delt * (1/2) * hazTail al (1/2) * ((1/2) * c)
      = delt * 0 * hazTail al (1/2) * ((1/2) * c) := by
    field_simp at h
    linarith [h]
  have hh : 0 < hazTail al (1/2 : ℝ) := hazTail_pos _ _
  nlinarith [mul_pos (mul_pos hd hh) hc]

/-- **Theorem 49 [M37] — the loop system acquires an exogenous input `i ≠ 0`, and
the FOC then HAS a root.**  In the loop algebra of
`MevTaxChannels.Theorem38_two_routes_close_a_loop` /
`MevTaxReturns.Theorem40d_loop_correction_removes_epsilon`, the extended model's
input is `i ≠ 0`; the FOC `P = 0` is then solvable and the law is
`τ* = 1 + (1-φ_X)/((∂φ_X/∂ν)·i)`.  The witness `φ_M = 0`, `φ_X = 1/2`,
`∂φ_X/∂ν = 1`, `i = -1`, `q = 0` puts the root at `τ* = 1/2 ∈ (0,1)`, where
`MevTaxShock.Theorem47_shared_driver_leaves_no_root` (which assumes `i = 0`)
returns `P ≠ 0` at every tax. -/
theorem Theorem49_exogenous_input_admits_a_root :
    ∃ phiM phiXv dphiXdnu i q tau P N : ℝ,
      i ≠ 0 ∧ tau ∈ Set.Ioo (0:ℝ) 1 ∧
        P = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tau) * dphiXdnu * N ∧
        N = i + q * P ∧ P = 0 ∧
        tau = 1 + (1 - phiXv) / (dphiXdnu * i) := by
  refine ⟨0, 1/2, 1, -1, 0, 1/2, 0, -1, by norm_num, ⟨by norm_num, by norm_num⟩, ?_, ?_, rfl, ?_⟩
    <;> norm_num

/-- **Theorem 49 [M37], the same verdict through the cited loop theorem.**  With
`i ≠ 0` the second clause of
`MevTaxReturns.Theorem40d_loop_correction_removes_epsilon` no longer applies, and
its third clause supplies the law.  Nothing is re-derived: the extended model
supplies `i ≠ 0`, the cited theorem supplies the root. -/
theorem Theorem49_root_law_from_loop_theorem (phiM phiXv tauMEV dphiXdnu i q P N : ℝ)
    (hP : P = (1 - phiM) * (1 - phiXv) + (1 - phiM) * (1 - tauMEV) * dphiXdnu * N)
    (hN : N = i + q * P) (hM : phiM ≠ 1)
    (hden : 1 - q * ((1 - phiM) * (1 - tauMEV) * dphiXdnu) ≠ 0)
    (hbi : dphiXdnu * i ≠ 0) :
    (P = 0 ↔ tauMEV = 1 + (1 - phiXv) / (dphiXdnu * i)) :=
  (MevTaxReturns.Theorem40d_loop_correction_removes_epsilon P N phiM phiXv tauMEV
    dphiXdnu i q hP hN hM hden).2.2 hbi

/-- **Theorem 49 [M37] — `Theorem47_shared_driver_leaves_no_root`'s conclusion
FAILS in the extended model.**  With the witness parameters of `focW`
(`Δt = 2`, `σ = 1/3`, `α = 10`, `φ_base = 1/100`, `δ = 100`, so `f_LPδ = 1`)
there is an interior tax `τ* ∈ (0,1)` at which the **total** `τ`-derivative of
the LP objective vanishes, while the fee path itself is nondegenerate
(`∂φ/∂τ = 1-φ_base ≠ 0`).  Under a shared driver alone no such tax exists; the
valuation shock's edge is what creates it. -/
theorem Theorem49_extended_model_has_an_interior_root :
    ∃ tau ∈ Set.Ioo (0:ℝ) 1,
      HasDerivAt (fun t => objNoRoute 100 10 (1/3) 1 (1/36) (1/100) t) 0 tau
        ∧ (1 : ℝ) - 1/100 ≠ 0 := by
  obtain ⟨phi1, hmem1, _, _, hroot, _, _⟩ := focW_two_roots
  refine ⟨(phi1 - 1/100) / (1 - 1/100), ?_, ?_, by norm_num⟩
  · obtain ⟨hlo, hhi⟩ := hmem1
    constructor
    · apply div_pos <;> linarith
    · rw [div_lt_one (by norm_num)]; linarith
  · have hb : (1/100 : ℝ) < 1 := by norm_num
    have htop := (Theorem50c_top_up_law (1/100) phi1 hb).1
    have hphi : phiOfTau (1/100) ((phi1 - 1/100) / (1 - 1/100)) = phi1 := htop
    have hpath : HasDerivAt (fun t : ℝ => phiOfTau (1/100 : ℝ) t) (1 - 1/100)
        ((phi1 - 1/100) / (1 - 1/100)) := by
      unfold phiOfTau
      have : HasDerivAt (fun t : ℝ => (1 - (1/100 : ℝ)) * (1 - t)) (-(1 - 1/100))
          ((phi1 - 1/100) / (1 - 1/100)) := by
        simpa using ((hasDerivAt_id _).const_sub 1).const_mul (1 - (1/100 : ℝ))
      simpa using this.const_sub 1
    have hden : (1/3 : ℝ) + phi1 * 1 ≠ 0 := by
      obtain ⟨hlo, -⟩ := hmem1; positivity
    have hK : HasDerivAt (fun _ : ℝ => (100 : ℝ) * (1/100)) 0 phi1 := hasDerivAt_const _ _
    have hH : HasDerivAt (hazTail 10) (-10 * hazTail 10 phi1) phi1 :=
      (Theorem48_derived_elasticity 10 phi1).1
    have hm := hasDerivAt_mObj (fun _ => (100 : ℝ) * (1/100)) (hazTail 10) 0
      (-10 * hazTail 10 phi1) phi1 (1/3) 1 (1/36) hK hH hden
    have hzero : focRed ((100 : ℝ) * (1/100)) 0 (hazTail 10 phi1)
        (-10 * hazTail 10 phi1) phi1 (1/3) 1 (1/36) = 0 := by
      have : focW phi1 = 0 := hroot
      rw [focW, focTail] at this
      norm_num at this ⊢
      exact this
    rw [hzero, mul_zero] at hm
    have hm' : HasDerivAt (fun f => mObj (fun _ => (100 : ℝ) * (1/100)) (hazTail 10)
        f (1/3) 1 (1/36)) 0 (phiOfTau (1/100) ((phi1 - 1/100) / (1 - 1/100))) := by
      rw [hphi]; exact hm
    have hcomp := hm'.comp ((phi1 - 1/100) / (1 - 1/100)) hpath
    simpa [objNoRoute, Function.comp] using hcomp

/-! ## M38 (a).  The profitability condition, REFUTED as an iff, in both directions -/

/-- Witness A's objective: `σ = c = 1` (`Δt = 2`), `α = 1/2`, `f_LPδ = 10`,
`Lvr = σ²Δt/8 = 1/4`. -/
noncomputable def mA (phi : ℝ) : ℝ := mObj (fun _ => 10) (hazTail (1/2)) phi 1 1 (1/4)

lemma focA_pos (phi : ℝ) (h0 : 0 ≤ phi) (h1 : phi < 1) :
    0 < focTail 10 (1/2) phi 1 1 (1/4) := by
  rw [focTail_eq]
  have hh : 0 < hazTail (1/2) phi := hazTail_pos _ _
  have hfac : (0:ℝ) < 1 - 1/2 * (phi * (1 + phi * 1)) := by nlinarith
  nlinarith

lemma hasDerivAt_mA (phi : ℝ) (h0 : 0 ≤ phi) :
    HasDerivAt mA (1 / (1 + phi * 1) ^ 2 * focTail 10 (1/2) phi 1 1 (1/4)) phi := by
  have hden : (1:ℝ) + phi * 1 ≠ 0 := by positivity
  have hK : HasDerivAt (fun _ : ℝ => (10:ℝ)) 0 phi := hasDerivAt_const _ _
  have hH : HasDerivAt (hazTail (1/2)) (-(1/2) * hazTail (1/2) phi) phi :=
    (Theorem48_derived_elasticity (1/2) phi).1
  have := hasDerivAt_mObj (fun _ => (10:ℝ)) (hazTail (1/2)) 0 (-(1/2) * hazTail (1/2) phi)
    phi 1 1 (1/4) hK hH hden
  simpa only [mA, focTail] using this

/-- **Theorem 50(a) [M38] — REFUTED, direction "`sup m > 0` ⇒ an interior
maximiser exists".**  With `α` small relative to the arb-deterrence gain
(`α(σ+c) ≤ σ`), `m` is **strictly increasing on the whole carrier** `[0,1)`:
there is no interior maximiser at all — indeed no maximiser — while `sup m > 0`.
The supremum is approached only at the excluded endpoint `φ = 1`, which is
exactly `arXiv:2606.21769` Prop. 4.1's boundary degeneracy reappearing for small
but nonzero `α`. -/
theorem Theorem50a_profitability_is_not_sufficient :
    StrictMonoOn mA (Set.Ico (0:ℝ) 1)
      ∧ (∃ phi ∈ Set.Ico (0:ℝ) 1, 0 < mA phi)
      ∧ (∀ phi0 ∈ Set.Ico (0:ℝ) 1, ∃ phi1 ∈ Set.Ico (0:ℝ) 1, mA phi0 < mA phi1) := by
  have hmono : StrictMonoOn mA (Set.Ico (0:ℝ) 1) := by
    refine strictMonoOn_of_deriv_pos (convex_Ico 0 1) ?_ ?_
    · intro x hx
      exact ((hasDerivAt_mA x hx.1).continuousAt).continuousWithinAt
    · intro x hx
      rw [interior_Ico] at hx
      obtain ⟨hx0, hx1⟩ := hx
      rw [(hasDerivAt_mA x hx0.le).deriv]
      have := focA_pos x hx0.le hx1
      positivity
  refine ⟨hmono, ?_, ?_⟩
  · refine ⟨1/2, ⟨by norm_num, by norm_num⟩, ?_⟩
    have hden : (1:ℝ) + (1/2 : ℝ) * 1 ≠ 0 := by norm_num
    rw [mA, mObj_eq _ _ _ _ _ _ hden]
    have hexp : (3:ℝ)/4 ≤ hazTail (1/2) (1/2 : ℝ) := by
      rw [hazTail]
      have := Real.add_one_le_exp (-(1/2 * (1/2 : ℝ)))
      norm_num at this ⊢
      linarith
    apply div_pos _ (by norm_num)
    nlinarith
  · intro phi0 hphi0
    refine ⟨(phi0 + 1)/2, ⟨by linarith [hphi0.1, hphi0.2], by linarith [hphi0.2]⟩, ?_⟩
    exact hmono hphi0 ⟨by linarith [hphi0.1, hphi0.2], by linarith [hphi0.2]⟩
      (by linarith [hphi0.2])

/-- Witness B's objective: `σ = c = 1` (`Δt = 2`), `α = 10`, `f_LPδ = 5`,
`Lvr = 1/4`. -/
noncomputable def mB (phi : ℝ) : ℝ := mObj (fun _ => 5) (hazTail 10) phi 1 1 (1/4)

lemma focB_pos_at_tenth : 0 < focTail 5 10 (1/10 : ℝ) 1 1 (1/4) := by
  rw [focTail_eq]
  have hval : hazTail 10 (1/10 : ℝ) = Real.exp (-1 : ℝ) := by rw [hazTail]; norm_num
  rw [hval]
  have hlt : Real.exp (-1 : ℝ) < 1/2 := by
    rw [Real.exp_neg]
    have h1 : (2:ℝ) < Real.exp 1 := by have := Real.exp_one_gt_d9; linarith
    rw [inv_lt_comm₀ (Real.exp_pos 1) (by norm_num)]
    linarith
  have hnum : (1:ℝ) - 10 * (1/10 * (1 + 1/10 * 1)) = -(1/10) := by norm_num
  rw [hnum]
  nlinarith [Real.exp_pos (-1 : ℝ)]

lemma focB_neg_at_fifth : focTail 5 10 (1/5 : ℝ) 1 1 (1/4) < 0 := by
  rw [focTail_eq]
  have hval : hazTail 10 (1/5 : ℝ) = Real.exp (-2 : ℝ) := by rw [hazTail]; norm_num
  rw [hval]
  have hb := exp_neg_two_gt
  have hnum : (1:ℝ) - 10 * (1/5 * (1 + 1/5 * 1)) = -(7/5) := by norm_num
  rw [hnum]
  nlinarith

/-- **Theorem 50(a) [M38] — REFUTED, direction "an interior maximiser exists ⇒
`sup m > 0`".**  With `α = 10`, `f_LPδ = 5`, `σ = c = 1`: the marginal value
crosses from `+` to `-` inside `(1/10, 1/5)`, so an interior local maximiser
exists — while `m < 0` at **every** admissible fee.  The interior optimum is a
loss minimiser, exactly the shutdown regime of (e), and the profitability
condition `sup m > 0` is neither necessary nor sufficient for it.

(The sign law `Theorem50a_sign_law_noroute` explains why: at that stationary
point `αφ* > 1`, and `m(φ*) < 0 ⇔ αφ* > 1`.) -/
theorem Theorem50a_profitability_is_not_necessary :
    (∃ phi ∈ Set.Ioo (1/10 : ℝ) (1/5), focTail 5 10 phi 1 1 (1/4) = 0)
      ∧ 0 < focTail 5 10 (1/10 : ℝ) 1 1 (1/4)
      ∧ focTail 5 10 (1/5 : ℝ) 1 1 (1/4) < 0
      ∧ (∀ phi ∈ Set.Ico (0:ℝ) 1, mB phi < 0) := by
  have hcont : Continuous (fun phi => focTail 5 10 phi 1 1 (1/4)) :=
    continuous_focTail 5 10 1 1 (1/4)
  refine ⟨?_, focB_pos_at_tenth, focB_neg_at_fifth, ?_⟩
  · have hmem : (0:ℝ) ∈ Set.Ioo (focTail 5 10 (1/5 : ℝ) 1 1 (1/4))
        (focTail 5 10 (1/10 : ℝ) 1 1 (1/4)) := ⟨focB_neg_at_fifth, focB_pos_at_tenth⟩
    obtain ⟨phi, hmem', hval⟩ := intermediate_value_Ioo' (by norm_num : (1/10 : ℝ) ≤ 1/5)
      hcont.continuousOn hmem
    exact ⟨phi, hmem', hval⟩
  · rintro phi ⟨h0, h1⟩
    have hden : (1:ℝ) + phi * 1 ≠ 0 := by positivity
    rw [mB, mObj_eq _ _ _ _ _ _ hden]
    have hquad : 1 + 10 * phi + (10 * phi)^2/2 ≤ Real.exp (10 * phi) := by
      have hx : (0:ℝ) ≤ 10 * phi := by linarith
      have := Real.sum_le_exp_of_nonneg hx 3
      simp [Finset.sum_range_succ] at this
      linarith
    have hexp : hazTail 10 phi * (1 + 10 * phi + 50 * phi^2) ≤ 1 := by
      rw [hazTail, Real.exp_neg, inv_mul_eq_div, div_le_one (Real.exp_pos _)]
      nlinarith
    have hq : (0:ℝ) < 50 * phi^2 - 10 * phi + 1 := by nlinarith [sq_nonneg (10 * phi - 1)]
    have hnum : 5 * hazTail 10 phi * (phi * 1) - 1/4 * 1 < 0 := by
      nlinarith [hexp, mul_pos (hazTail_pos 10 phi) hq]
    exact div_neg_of_neg_of_pos hnum (by positivity)

/-! ## M39.  Theorem 51 — the incidence question -/

/-- **Theorem 51 [M39], the exact wedge between the two FOCs.**  At the same fee
`φ`, with the same `δ` and leg fees, the full-routing reduced FOC exceeds the
no-routing one by

`δ·[ hφ(σ+cφ) + (φ-φ_base)(hσ + h'φ(σ+cφ)) ]`.

Everything M39 asks is read off this identity. -/
theorem Theorem51_routing_wedge (delt hval dh phi phibase sig c Lvr : ℝ) :
    focRed (delt * phi) delt hval dh phi sig c Lvr
        - focRed (delt * phibase) 0 hval dh phi sig c Lvr
      = delt * (hval * (phi * (sig + phi * c))
          + (phi - phibase) * (hval * sig + dh * (phi * (sig + phi * c)))) := by
  rw [focRed, focRed]; ring

/-- **Theorem 51(c) [M39] — is there a discontinuous term at `τ = 0`?  NO within a
regime, YES between regimes.**  At `τ = 0` (i.e. `φ = φ_base`) the wedge equals
`δ·h(φ_base)·φ_base(σ+cφ_base) > 0`: the two regimes' marginal values do **not**
agree at zero tax, so there is no smooth pasting between them.  Within the
no-routing regime, however, the objective is differentiable in `τ` at `τ = 0`
(`Theorem49_extended_model_has_an_interior_root` uses the same derivative), so
`∂m/∂τ` picks up **no** discontinuous term there: the first unit of tax destroys
benign surplus smoothly. -/
theorem Theorem51c_wedge_at_zero_tax (delt hval dh phibase sig c Lvr : ℝ)
    (hd : 0 < delt) (hh : 0 < hval) (hb : 0 < phibase) (hsig : 0 < sig) (hc : 0 < c) :
    focRed (delt * phibase) delt hval dh phibase sig c Lvr
        - focRed (delt * phibase) 0 hval dh phibase sig c Lvr
      = delt * (hval * (phibase * (sig + phibase * c)))
    ∧ 0 < delt * (hval * (phibase * (sig + phibase * c))) := by
  constructor
  · have := Theorem51_routing_wedge delt hval dh phibase phibase sig c Lvr
    simpa using this
  · positivity

/-- **Theorem 51(b) [M39] — the shift, SIGNED, under an explicit and sharp
condition.**  Under (A-tail), if `α(φ - φ_base) < 1` then the full-routing
marginal value strictly exceeds the no-routing one at `φ`.  Consequently (with
`Theorem48c_root_shifts_up`) at any no-routing stationary point the routing
regime still wants **more** tax: `τ*_no-route < τ*_route` there. -/
theorem Theorem51b_shift_sign_under_threshold (delt al phi phibase sig c Lvr : ℝ)
    (hd : 0 < delt) (hphi : 0 < phi) (hsig : 0 < sig) (hc : 0 < c)
    (hle : phibase ≤ phi) (hthr : al * (phi - phibase) < 1) :
    focRed (delt * phibase) 0 (hazTail al phi) (-al * hazTail al phi) phi sig c Lvr
      < focRed (delt * phi) delt (hazTail al phi) (-al * hazTail al phi) phi sig c Lvr := by
  have hw := Theorem51_routing_wedge delt (hazTail al phi) (-al * hazTail al phi)
    phi phibase sig c Lvr
  have hh : 0 < hazTail al phi := hazTail_pos al phi
  have hden : 0 < sig + phi * c := by positivity
  have hgap : 0 < delt * (hazTail al phi * (phi * (sig + phi * c))
      + (phi - phibase) * (hazTail al phi * sig
          + (-al * hazTail al phi) * (phi * (sig + phi * c)))) := by
    have hkey : hazTail al phi * (phi * (sig + phi * c))
        + (phi - phibase) * (hazTail al phi * sig
          + (-al * hazTail al phi) * (phi * (sig + phi * c)))
        = hazTail al phi * ((phi * (sig + phi * c)) * (1 - al * (phi - phibase))
            + (phi - phibase) * sig) := by ring
    rw [hkey]
    have h1 : 0 < (phi * (sig + phi * c)) * (1 - al * (phi - phibase)) := by
      have : 0 < 1 - al * (phi - phibase) := by linarith
      positivity
    have h2 : 0 ≤ (phi - phibase) * sig := by nlinarith
    have : 0 < (phi * (sig + phi * c)) * (1 - al * (phi - phibase)) + (phi - phibase) * sig := by
      linarith
    positivity
  linarith [hw, hgap]

/-- **Theorem 51(b) [M39] — NO unconditional sign: the domination FAILS at large
fees.**  With `α = 10`, `σ = 1/3`, `c = 1`, `φ_base = 1/100`, `δ = 1`, at
`φ = 9/10` the **no-routing** marginal value strictly exceeds the full-routing
one.  So the shift `τ*_no-route - τ*_route` has no sign valid across the
carrier; the threshold `α(φ-φ_base) < 1` of
`Theorem51b_shift_sign_under_threshold` is what carries it, and it is sharp in
the sense that the wedge changes sign once the threshold is violated. -/
theorem Theorem51b_no_unconditional_sign :
    focRed (1 * (9/10 : ℝ)) 1 (hazTail 10 (9/10)) (-10 * hazTail 10 (9/10))
        (9/10) (1/3) 1 (1/36)
      < focRed (1 * (1/100 : ℝ)) 0 (hazTail 10 (9/10)) (-10 * hazTail 10 (9/10))
        (9/10) (1/3) 1 (1/36) := by
  have hw := Theorem51_routing_wedge 1 (hazTail 10 (9/10)) (-10 * hazTail 10 (9/10))
    (9/10) (1/100) (1/3) 1 (1/36)
  have hh : 0 < hazTail 10 (9/10 : ℝ) := hazTail_pos _ _
  have hneg : (1:ℝ) * (hazTail 10 (9/10) * ((9/10) * (1/3 + (9/10) * 1))
      + ((9/10) - 1/100) * (hazTail 10 (9/10) * (1/3)
        + (-10 * hazTail 10 (9/10)) * ((9/10) * (1/3 + (9/10) * 1)))) < 0 := by
    nlinarith
  linarith [hw, hneg]

/-- **Theorem 51(a) [M39] — the interior root SURVIVES no-routing.**  The witness
of `Theorem49_extended_model_has_an_interior_root` is a no-routing instance
(`Kf` constant `= δφ_base`): both sides of the trade-off survive (LVR retention
is kept, benign attrition is paid), so the root does not disappear when the
revenue goes elsewhere. -/
theorem Theorem51a_interior_root_survives_no_routing :
    ∃ tau ∈ Set.Ioo (0:ℝ) 1,
      HasDerivAt (fun t => objNoRoute 100 10 (1/3) 1 (1/36) (1/100) t) 0 tau :=
  let ⟨tau, hmem, hderiv, _⟩ := Theorem49_extended_model_has_an_interior_root
  ⟨tau, hmem, hderiv⟩

/-! ## M40.  Theorem 52 — second order -/

/-- The quadratic `q(φ) = 2σ + 2cφ - ασφ - αcφ²` whose sign is the second-order
condition: `Φ'(φ) = -Kαh(φ)q(φ)`. -/
noncomputable def qPoly (al sig c phi : ℝ) : ℝ :=
  2 * sig + 2 * c * phi - al * sig * phi - al * c * phi ^ 2

lemma hasDerivAt_focTail (K al phi sig c Lvr : ℝ) :
    HasDerivAt (fun f => focTail K al f sig c Lvr)
      (-(K * al * hazTail al phi * qPoly al sig c phi)) phi := by
  have hH : HasDerivAt (hazTail al) (-al * hazTail al phi) phi :=
    (Theorem48_derived_elasticity al phi).1
  have hpoly : HasDerivAt (fun f : ℝ => sig - al * (f * (sig + f * c)))
      (-(al * sig) - al * (2 * c * phi)) phi := by
    have h1 : HasDerivAt (fun f : ℝ => f * (sig + f * c)) (sig + 2 * c * phi) phi := by
      have ha : HasDerivAt (fun f : ℝ => sig + f * c) c phi := by
        simpa using ((hasDerivAt_id phi).mul_const c).const_add sig
      have h2 : HasDerivAt (fun f : ℝ => f * (sig + f * c))
          (1 * (sig + phi * c) + phi * c) phi := (hasDerivAt_id phi).mul ha
      convert h2 using 1
      ring
    have := (h1.const_mul al).const_sub sig
    convert this using 1
    ring
  have hmul := (hH.mul hpoly).const_mul K
  have hfin := hmul.add_const (Lvr * sig)
  refine hfin.congr_deriv ?_ |>.congr_of_eventuallyEq ?_
  · rw [qPoly]; ring
  · filter_upwards with f
    rw [focTail_eq]
    simp only [Pi.mul_apply]
    ring

/-- **Theorem 52 [M40] — the second-order condition, exactly.**  At an interior
stationary point the marginal value's slope is `(c/(σ+cφ)²)·Φ'(φ*)` with
`Φ'(φ*) = -Kαh(φ*)q(φ*)`; hence

* `q(φ*) > 0` ⇒ `m''(φ*) < 0`: strict local **maximum**;
* `q(φ*) < 0` ⇒ `m''(φ*) > 0`: strict local **minimum**.

Strict concavity of `m` therefore holds **at** the first root, but not globally
(`Theorem52_single_crossing_fails`). -/
theorem Theorem52_second_order (K al phi sig c Lvr : ℝ)
    (hden : sig + phi * c ≠ 0) (hstat : focTail K al phi sig c Lvr = 0) :
    HasDerivAt (fun f => c / (sig + f * c) ^ 2 * focTail K al f sig c Lvr)
      (c / (sig + phi * c) ^ 2 * (-(K * al * hazTail al phi * qPoly al sig c phi))) phi := by
  have hg : HasDerivAt (fun f : ℝ => c / (sig + f * c) ^ 2)
      (-(c * (2 * (sig + phi * c) * c)) / ((sig + phi * c) ^ 2) ^ 2) phi := by
    have hb : HasDerivAt (fun f : ℝ => (sig + f * c) ^ 2) (2 * (sig + phi * c) * c) phi := by
      have ha : HasDerivAt (fun f : ℝ => sig + f * c) c phi := by
        simpa using ((hasDerivAt_id phi).mul_const c).const_add sig
      simpa [mul_comm, mul_assoc] using ha.pow 2
    have := (hasDerivAt_const phi c).div hb (pow_ne_zero 2 hden)
    simpa using this
  have hprod := hg.mul (hasDerivAt_focTail K al phi sig c Lvr)
  rw [hstat] at hprod
  simpa using hprod

/-- **Theorem 52 [M40] — strict local maximum at a stationary point with
`q(φ*) > 0`.** -/
theorem Theorem52_strict_local_max (K al phi sig c : ℝ)
    (hK : 0 < K) (hal : 0 < al) (hc : 0 < c) (hsig : 0 < sig) (hphi : 0 < phi)
    (hq : 0 < qPoly al sig c phi) :
    c / (sig + phi * c) ^ 2 * (-(K * al * hazTail al phi * qPoly al sig c phi)) < 0 := by
  have hh : 0 < hazTail al phi := hazTail_pos al phi
  have hg : 0 < c / (sig + phi * c) ^ 2 := by positivity
  have : 0 < K * al * hazTail al phi * qPoly al sig c phi := by positivity
  nlinarith

/-- **Theorem 52 [M40] — what (A-tail) contributes: AT MOST TWO stationary
points.**  Under **(A-tail)** the reduced FOC has at most two zeros on
`(0,∞)`: three would force, by Rolle, two distinct positive roots of the
concave quadratic `q`, whose product of roots is `-2σ/(αc) < 0`.  Hence the sign
pattern can only be `+,-,+`, so there is at most one interior **local
maximiser** (the first stationary point); the second is a local minimum.  This
bounds the *local* maximisers only — the *global* maximiser over `[0,1)` may sit
at the excluded endpoint, as `Theorem50a_profitability_is_not_sufficient`
shows.  This is the only place (A-tail) is load-bearing; every sign law above
holds for a general differentiable hazard. -/
theorem Theorem52_at_most_two_stationary_points (K al sig c Lvr : ℝ)
    (hK : 0 < K) (hal : 0 < al) (hsig : 0 < sig) (hc : 0 < c)
    (x y z : ℝ) (hx : 0 < x) (hxy : x < y) (hyz : y < z)
    (hfx : focTail K al x sig c Lvr = 0) (hfy : focTail K al y sig c Lvr = 0)
    (hfz : focTail K al z sig c Lvr = 0) : False := by
  have hcont : Continuous (fun f => focTail K al f sig c Lvr) := continuous_focTail K al sig c Lvr
  obtain ⟨u, hu, hu0⟩ := exists_hasDerivAt_eq_zero (f := fun f => focTail K al f sig c Lvr)
    (f' := fun f => -(K * al * hazTail al f * qPoly al sig c f)) hxy hcont.continuousOn
    (by simpa using hfx.trans hfy.symm) (fun t _ => hasDerivAt_focTail K al t sig c Lvr)
  obtain ⟨v, hv, hv0⟩ := exists_hasDerivAt_eq_zero (f := fun f => focTail K al f sig c Lvr)
    (f' := fun f => -(K * al * hazTail al f * qPoly al sig c f)) hyz hcont.continuousOn
    (by simpa using hfy.trans hfz.symm) (fun t _ => hasDerivAt_focTail K al t sig c Lvr)
  have hqu : qPoly al sig c u = 0 := by
    have hh : 0 < hazTail al u := hazTail_pos al u
    have : K * al * hazTail al u * qPoly al sig c u = 0 := by linarith [hu0]
    have hne : K * al * hazTail al u ≠ 0 := by positivity
    rcases mul_eq_zero.mp this with h | h
    · exact absurd h hne
    · exact h
  have hqv : qPoly al sig c v = 0 := by
    have hh : 0 < hazTail al v := hazTail_pos al v
    have : K * al * hazTail al v * qPoly al sig c v = 0 := by linarith [hv0]
    have hne : K * al * hazTail al v ≠ 0 := by positivity
    rcases mul_eq_zero.mp this with h | h
    · exact absurd h hne
    · exact h
  have huv : u < v := lt_trans hu.2 hv.1
  have hu0' : 0 < u := lt_trans hx hu.1
  have hv0' : 0 < v := lt_trans hu0' huv
  rw [qPoly] at hqu hqv
  have hsum : 2 * c - al * sig = al * c * (u + v) := by
    have hd : (u - v) * (2 * c - al * sig - al * c * (u + v)) = 0 := by
      linear_combination hqu - hqv
    have hne : u - v ≠ 0 := by linarith
    rcases mul_eq_zero.mp hd with h | h
    · exact absurd h hne
    · linarith
  have hkey : 2 * sig + al * c * (u * v) = 0 := by linear_combination hqu - u * hsum
  nlinarith [mul_pos (mul_pos hal hc) (mul_pos hu0' hv0')]

/-- **Theorem 52 [M40] — SINGLE CROSSING FAILS, even under (A-tail), witness
exhibited.**  `Φ_w` is positive at `φ = 1/100`, negative at `φ = 1/5` and
positive again at `φ = 4/5`: `m` rises, falls, and rises again on `[0,1)`, so it
is **not** concave and **not** single-crossing, and it has two distinct interior
stationary points.  Since `e^{-αφ}` is log-concave, this also answers M40's last
question: uniqueness of the *stationary point* already fails inside the
log-concave class — no further generality is needed to break it.  What survives
is `Theorem52_at_most_two_stationary_points`: at most two stationary points,
hence at most one interior **local maximiser**. -/
theorem Theorem52_single_crossing_fails :
    0 < focW (1/100) ∧ focW (1/5) < 0 ∧ 0 < focW (4/5)
      ∧ ∃ phi1 ∈ Set.Ioo (1/100 : ℝ) (1/5), ∃ phi2 ∈ Set.Ioo (1/5 : ℝ) (4/5),
          focW phi1 = 0 ∧ focW phi2 = 0 ∧ phi1 ≠ phi2 := by
  obtain ⟨phi1, hm1, phi2, hm2, h1, h2, hlt⟩ := focW_two_roots
  exact ⟨focW_pos_at_hundredth, focW_neg_at_fifth, focW_pos_at_four_fifths,
    phi1, hm1, phi2, hm2, h1, h2, ne_of_lt hlt⟩

end MevTaxTransactional
