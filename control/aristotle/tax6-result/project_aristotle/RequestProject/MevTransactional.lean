import Mathlib
import RequestProject.MevShockInput

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# M36–M40 — the transactional channel (Theorems 48–52)

*This module carries the primitives and **M36 / Theorem 48**; blocks M37–M40
(Theorems 49–52) continue in `RequestProject.MevTransactionalOptimum`.  The
overview below covers both modules.*

This module formalizes blocks **M36–M40** of `TAX6_ADDENDUM.md`: the author's
ruling that a **second exogenous shock** — a private valuation shock `V`,
independent of the price shock and carried by benign (transactional) traders —
enters the model, in **shock space**: participation is a shock crossing a
protocol-set band, exactly as `ℙ_{Δ_ARB}` (`DOC` Definition 21,
`MevOptimization.ptrade`) already is.

## Cited by name and file, never redone

* `MevTaxControl.Theorem29_monoid_path_is_direct`,
  `MevTaxControl.Theorem32_hazard_strictAntiOn_tau`,
  `MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos`
  (`MevTaxControl.lean`);
* `MevTaxProgram.Proposition16_corrected_law`, `MevTaxProgram.totalDeriv`,
  `MevTaxProgram.focCore`, `MevTaxProgram.pathGate`,
  `MevTaxProgram.hasDerivAt_phiTot`,
  `MevTaxProgram.Proposition15_level_reading_second_order_undetermined`
  (`MevTaxProgram.lean`);
* `MevTaxLVR.Theorem37_LVR_cancellation`, `MevTaxLVR.Theorem37_K_pos`,
  `MevTaxLVR.Corollary37_root_invariance`, `MevTaxLVR.hasDerivAt_ptrade_phi`,
  `MevTaxLVR.dptrade_dphi_neg` (`MevLVRCancellation.lean`);
* `MevTaxChannels.Theorem38_two_routes_close_a_loop`,
  `MevTaxChannels.Theorem38a_one_sided_flow_refutes_strict_monotonicity`,
  `MevTaxChannels.Theorem39_arb_side_does_not_close`,
  `MevTaxChannels.Theorem39_elasticity_closes`,
  `MevTaxChannels.ScaleHomogeneous` (`MevChannelClosure.lean`);
* `MevTaxReturns.Theorem40_returns_reduction`,
  `MevTaxReturns.Theorem40d_loop_correction_removes_epsilon`,
  `MevTaxReturns.Theorem44_objective_reading_does_not_discriminate`
  (`MevReturnsReduction.lean`);
* `MevTaxShock.Theorem45_shock_driven_utilization`,
  `MevTaxShock.Theorem46_shock_flow_is_two_legged`,
  `MevTaxShock.Theorem47_shared_driver_is_one_edge`,
  `MevTaxShock.Theorem47_no_exogenous_hazard_input` — **the hypothesis M37
  relaxes** —, `MevTaxShock.Theorem47_shared_driver_leaves_no_root` — the
  result that must fail in the extended model —,
  `MevTaxShock.Theorem45_benign_factorization_is_a_demand_elasticity` — the slot
  filled here by author ruling (`MevShockInput.lean`).

## The four new typed assumptions

Assumed by name, never proved, never estimated:

* **(A-ind)** `V ⊥ (Δp/p)`.  Carried as `ProbabilityTheory.IndepFun` and used
  exactly once, in `Theorem48a_block_events_partition`, to factor the
  transactional block probability.  It is the load-bearing one.
* **(A-tail)** the tail of `|V|` is exponential with rate `α > 0`, so
  `h(φ) = ℙ(|V| > φ) = e^{-αφ}` (`hazTail`, grounded against Mathlib's
  exponential law in `A_tail_survival`).  **No causal estimate of `α` exists**;
  every threshold verdict below is conditional on a chosen number, and the
  results are therefore stated as sign/threshold laws in `α`, never as numbers.
* **(A-size)** the benign trade size `δ > 0` is exogenous: the *rate* responds
  to the fee, the *size* does not.  It enters only as the constant factor `δ`
  in `K`.
* **(A-route)** the `τ` share of the composed fee is **not** routed to LPs
  (`DOC` Theorem 20, monoid entry (A): *NO compensation routed*); LPs accrue leg
  fees only (`DOC` Rule 6).  Formally `Kf` is the **constant** `δ·φ_base` and
  not `δ·φ`.

## Standing bans

Ban 3 is respected: `π^{transactional}` (`piTransOpp`, `piTransBlock`,
`piTransCond`) is a **trader-side** object and is never identified with `π^φ`
or `π^{varphi}`.  Ban 6 is respected: no isoelastic demand `Q ∝ φ^{-ε}` appears;
the hazard `h` is the only demand object, and the elasticity `ε(φ) = -αφ` is a
*derived*, fee-dependent quantity (`Theorem48_derived_elasticity`), never a
primitive.  Ban 4: no claim below uses `SRC` Convention 9's composed `∂φ/∂ν`;
the loop material (M37) uses `MevTaxProgram.totalDeriv`'s bare slot, exactly as
the cited theorems do.

## Verdicts (summary; each is a theorem below)

* **Theorem 48 (a),(b) HOLD**; **(c)** is derived **both ways** and the
  complement reading is the accounting-consistent one — the unconditional
  reading is refuted by `Theorem48c_unconditional_reading_is_not_a_partition`,
  and the second channel `(1-ℙ_{Δ_ARB})↑` is a **strictly positive** addition to
  the marginal value, pushing the root **up**
  (`Theorem48c_complement_adds_a_positive_channel`).
  **(d) is REFUTED as stated**: the complement-weighted trader payoff is
  *increasing* at `φ = 0`, and the conditional-on-participation reading is
  *strictly increasing* everywhere (memorylessness).  What is strictly
  decreasing is the per-opportunity payoff `piTransOpp`
  (`Theorem48d_*`).
* **Theorem 49 HOLDS**, with the relaxed hypothesis named: it is exactly
  `Theorem47_no_exogenous_hazard_input`'s premise — *the composed fee is a
  sufficient statistic* — which **fails under (A-route)** and **holds** under
  full routing.
* **Theorem 50 (a) is REFUTED as an iff** (two witnesses), and replaced by
  exact threshold laws; (b),(c),(d),(e) HOLD.  Notably `m(φ*) < 0 ⟺ αφ* > 1`
  under (A-route), `⟺ αφ* > 2` under full routing.
* **Theorem 51**: the interior root **survives** no-routing (the witness is a
  no-routing one); the shift is signed **conditionally** and the condition is
  sharp — no unconditional sign is available, and a witness for each direction
  is exhibited.  There is **no** discontinuous term at `τ = 0` within a regime;
  the wedge *between* regimes at `τ = 0` is strictly positive.
* **Theorem 52**: strict concavity **fails globally even under (A-tail)** —
  single crossing is refuted by an explicit witness with three sign changes —
  but the interior *maximiser* is unique (at most two stationary points), and
  the pointwise sign laws survive for **any** differentiable hazard, with
  (A-tail) contributing only the counting.
-/

namespace MevTaxTransactional

open MeasureTheory ProbabilityTheory

/-! ## Primitives -/

/-- The `DOC` Definition 21 band constant `c = √(2/Δt)`. -/
noncomputable def cRate (Δt : ℝ) : ℝ := Real.sqrt (2 / Δt)

lemma cRate_pos {Δt : ℝ} (hΔt : 0 < Δt) : 0 < cRate Δt :=
  Real.sqrt_pos.mpr (by positivity)

/-- `ℙ_{Δ_ARB}` written in the band constant: `σ/(σ + φc)`.  This is *literally*
`MevOptimization.ptrade` (`DOC` Definition 21) at `c = √(2/Δt)`
(`pArb_eq_ptrade`); the `c`-form is used so that every statement below is
algebra in `(φ, σ, c)`. -/
noncomputable def pArb (phi sig c : ℝ) : ℝ := sig / (sig + phi * c)

lemma pArb_eq_ptrade (phi sig Δt : ℝ) :
    pArb phi sig (cRate Δt) = MevOptimization.ptrade phi sig Δt := rfl

/-- The **(A-tail)** valuation-shock participation probability
`h(φ) = ℙ(|V| > φ) = e^{-αφ}` — the literature's Form A hazard, here a
*shock-space participation probability* and not a demand specification. -/
noncomputable def hazTail (al phi : ℝ) : ℝ := Real.exp (-(al * phi))

lemma hazTail_pos (al phi : ℝ) : 0 < hazTail al phi := Real.exp_pos _

/-- **(A-tail), grounded.**  If `|V|` has Mathlib's exponential law with rate
`α > 0`, its survival function at a nonnegative band is exactly `e^{-αb}`.  This
is the only place the exponential *law* is used: everywhere else `(A-tail)` is
carried through `hazTail` and its hazard rate `α`. -/
theorem A_tail_survival (al b : ℝ) (hal : 0 < al) (hb : 0 ≤ b) :
    (expMeasure al (Set.Ioi b)).toReal = hazTail al b := by
  haveI : IsProbabilityMeasure (expMeasure al) := isProbabilityMeasure_expMeasure hal
  have hcdf : cdf (expMeasure al) b = 1 - Real.exp (-(al * b)) := by
    rw [cdf_expMeasure_eq hal]; simp [hb]
  have hIic : (expMeasure al).real (Set.Iic b) = 1 - Real.exp (-(al * b)) := by
    rw [← cdf_eq_real, hcdf]
  have hcompl : Set.Ioi b = (Set.Iic b)ᶜ := by ext x; simp
  have : (expMeasure al).real (Set.Ioi b) = hazTail al b := by
    rw [hcompl, measureReal_compl measurableSet_Iic, hIic]
    simp [hazTail]
  simpa [measureReal_def] using this

/-- The per-block transactional probability, **(A-ind)**'s product form:
`ℙ_trans = (1 - ℙ_{Δ_ARB})·h(φ)`. -/
noncomputable def pTrans (al phi sig c : ℝ) : ℝ := (1 - pArb phi sig c) * hazTail al phi

/-- The per-block idle probability `ℙ_idle = (1 - ℙ_{Δ_ARB})·(1 - h(φ))`. -/
noncomputable def pIdle (al phi sig c : ℝ) : ℝ := (1 - pArb phi sig c) * (1 - hazTail al phi)

/-! ## M36.  Theorem 48 — the transactional measure -/

/-- **Theorem 48(a) [M36] — the three block events partition, numerically.**
`ℙ_arb + ℙ_trans + ℙ_idle = 1` identically: the complement structure is a
partition by construction, with no side condition. -/
theorem Theorem48a_partition (al phi sig c : ℝ) :
    pArb phi sig c + pTrans al phi sig c + pIdle al phi sig c = 1 := by
  unfold pTrans pIdle; ring

/-- **Theorem 48(a) [M36] — the three block events partition, as events, and
(A-ind) is what factors the transactional one.**  With `S` the price shock,
`Vabs = |V|`, `arbSet` the arb-triggering shock set and `band` the protocol
band: the arb event, the transactional event and the idle event are pairwise
disjoint and exhaust `Ω`, and under **(A-ind)** the transactional event's
measure is the product `ℙ(arbᶜ)·ℙ(|V| > band)` — the `1 - ℙ_{Δ_ARB}` structure.
Independence is used **here and only here**. -/
theorem Theorem48a_block_events_partition
    {Ω : Type*} [MeasurableSpace Ω] (μ : Measure Ω) (S Vabs : Ω → ℝ)
    (arbSet : Set ℝ) (band : ℝ)
    (hind : IndepFun S Vabs μ) (hA : MeasurableSet arbSet) :
    Disjoint (S ⁻¹' arbSet) ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Ioi band)
      ∧ Disjoint (S ⁻¹' arbSet) ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Iic band)
      ∧ Disjoint ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Ioi band)
          ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Iic band)
      ∧ (S ⁻¹' arbSet) ∪ ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Ioi band)
          ∪ ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Iic band) = Set.univ
      ∧ μ ((S ⁻¹' arbSet)ᶜ ∩ Vabs ⁻¹' Set.Ioi band)
          = μ ((S ⁻¹' arbSet)ᶜ) * μ (Vabs ⁻¹' Set.Ioi band) := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · exact Set.disjoint_left.mpr (fun x hx hx' => hx'.1 hx)
  · exact Set.disjoint_left.mpr (fun x hx hx' => hx'.1 hx)
  · refine Set.disjoint_left.mpr (fun x hx hx' => ?_)
    have h1 : band < Vabs x := hx.2
    have h2 : Vabs x ≤ band := hx'.2
    linarith
  · ext x
    by_cases hx : x ∈ S ⁻¹' arbSet
    · simp [hx]
    · by_cases hv : band < Vabs x
      · simp [hx, hv, Set.mem_preimage]
      · simp only [Set.mem_union, Set.mem_inter_iff, Set.mem_compl_iff, Set.mem_preimage,
          Set.mem_Ioi, Set.mem_Iic, Set.mem_univ, iff_true]
        exact Or.inr ⟨hx, not_lt.mp hv⟩
  · have := hind.measure_inter_preimage_eq_mul arbSetᶜ (Set.Ioi band) hA.compl
      measurableSet_Ioi
    simpa [Set.preimage_compl] using this

/-- `f_LP·δ` — the LP-accrued fee times the exogenous benign size **(A-size)**.
Under **(A-route)** this is the *constant* `δ·φ_base` (leg fees only); under the
counterfactual full routing it is `δ·φ`. -/
noncomputable def ntFee (Kf hh : ℝ → ℝ) (phi sig c : ℝ) : ℝ :=
  (1 - pArb phi sig c) * hh phi * Kf phi

/-- **Theorem 48(b) [M36] — the term `MMR` eq. (27) leaves unspecified.**  Under
the partition of (a), per-block expected LP income from flow is
`ℙ_arb · (arb-block leg income) + NT_FEE(φ)` with

`NT_FEE(φ) = (1 - ℙ_{Δ_ARB}(φ,σ,Δt))·h(φ)·f_LP(φ)·δ`,

the idle event contributing nothing.  This is exactly the second summand of
`DOC` Proposition 9's split, whose benign half the document leaves
unspecified. -/
theorem Theorem48b_block_income_decomposition
    (Kf hh : ℝ → ℝ) (phi sig c arbIncome : ℝ) :
    pArb phi sig c * arbIncome + pTrans (0 : ℝ) phi sig c * 0
        + (1 - pArb phi sig c) * hh phi * Kf phi + pIdle 0 phi sig c * 0
      = pArb phi sig c * arbIncome + ntFee Kf hh phi sig c := by
  unfold ntFee; ring

/-- The **derived** demand elasticity: under (A-tail) the fee elasticity of the
benign participation probability is `ε(φ) = φ·h'(φ)/h(φ) = -αφ` — *derived and
fee-dependent*, never a primitive (standing ban 6). -/
theorem Theorem48_derived_elasticity (al phi : ℝ) :
    HasDerivAt (hazTail al) (-al * hazTail al phi) phi
      ∧ phi * (-al * hazTail al phi) / hazTail al phi = -(al * phi) := by
  constructor
  · have h : HasDerivAt (fun x : ℝ => -(al * x)) (-al) phi := by
      simpa using ((hasDerivAt_id phi).const_mul al).neg
    simpa [hazTail, mul_comm] using h.exp
  · have := (hazTail_pos al phi).ne'
    field_simp [hazTail]

/-! ## The per-block LP objective `m` and its first-order condition

`m` is `MMR` eq. (27)'s per-block LP PnL drift,

`m(φ; σ²) = NT_FEE(φ) - (σ²Δt/8)·ℙ_{Δ_ARB}(φ,σ,Δt)`.

Standing note (`MevTaxReturns.Theorem44_objective_reading_does_not_discriminate`):
the objective here is `m` itself, **not** `Definition 36`'s squared-derivative
form, which that theorem showed cannot distinguish a minimum from a maximum.
-/

/-- The LVR coefficient `σ²Δt/8` of `MMR` eq. (27). -/
noncomputable def lvrCoef (sig Δt : ℝ) : ℝ := sig ^ 2 * Δt / 8

/-- The per-block LP PnL drift.  `Kf φ = f_LP(φ)·δ` carries **(A-size)** (the
constant `δ`) and the routing convention: under **(A-route)** `Kf` is the
*constant* `δ·φ_base` (leg fees only, `DOC` Rule 6, monoid entry (A)); under the
counterfactual full routing `Kf φ = δ·φ`.  `hh` is the participation
probability; under **(A-tail)** it is `hazTail α`. -/
noncomputable def mObj (Kf hh : ℝ → ℝ) (phi sig c Lvr : ℝ) : ℝ :=
  ntFee Kf hh phi sig c - Lvr * pArb phi sig c

lemma hasDerivAt_pArb (phi sig c : ℝ) (hden : sig + phi * c ≠ 0) :
    HasDerivAt (fun f => pArb f sig c) (-(sig * c) / (sig + phi * c) ^ 2) phi := by
  have hd : HasDerivAt (fun f : ℝ => sig + f * c) c phi := by
    simpa using ((hasDerivAt_id phi).mul_const c).const_add sig
  have h := (hasDerivAt_const phi sig).div hd hden
  simpa [pArb, zero_mul, zero_sub] using h

/-- `1 - ℙ_{Δ_ARB} = cφ/(σ+cφ)` — the complement factor, and it is **increasing**
in `φ`: its derivative is `+σc/(σ+cφ)² > 0`.  This is the second channel M36(c)
asks about. -/
lemma one_sub_pArb_eq (phi sig c : ℝ) (hden : sig + phi * c ≠ 0) :
    1 - pArb phi sig c = phi * c / (sig + phi * c) := by
  rw [pArb]
  field_simp
  ring

lemma hasDerivAt_one_sub_pArb (phi sig c : ℝ) (hden : sig + phi * c ≠ 0) :
    HasDerivAt (fun f => 1 - pArb f sig c) (sig * c / (sig + phi * c) ^ 2) phi := by
  have := (hasDerivAt_pArb phi sig c hden).const_sub 1
  simpa [neg_div, sub_eq_add_neg] using this

/-- The **reduced first-order condition**: `m'(φ)` cleared of the strictly
positive factor `c/(σ+cφ)²`.  `Kv = Kf φ`, `dK = Kf'(φ)`, `hval = h φ`,
`dh = h'(φ)`.  Its zeros are exactly `m`'s stationary points. -/
noncomputable def focRed (Kv dK hval dh phi sig c Lvr : ℝ) : ℝ :=
  dK * hval * (phi * (sig + phi * c))
    + Kv * (hval * sig + dh * (phi * (sig + phi * c))) + Lvr * sig

/-- **The FOC in reduced form.**  `m'(φ) = (c/(σ+cφ)²)·focRed`. -/
lemma hasDerivAt_mObj (Kf hh : ℝ → ℝ) (dK dh phi sig c Lvr : ℝ)
    (hK : HasDerivAt Kf dK phi) (hH : HasDerivAt hh dh phi)
    (hden : sig + phi * c ≠ 0) :
    HasDerivAt (fun f => mObj Kf hh f sig c Lvr)
      (c / (sig + phi * c) ^ 2
        * focRed (Kf phi) dK (hh phi) dh phi sig c Lvr) phi := by
  have hP := hasDerivAt_one_sub_pArb phi sig c hden
  have hA := hasDerivAt_pArb phi sig c hden
  have hnt : HasDerivAt (fun f => ntFee Kf hh f sig c)
      ((sig * c / (sig + phi * c) ^ 2 * hh phi + (1 - pArb phi sig c) * dh) * Kf phi
        + (1 - pArb phi sig c) * hh phi * dK) phi := (hP.mul hH).mul hK
  have hm := hnt.sub (hA.const_mul Lvr)
  have hpow : (sig + phi * c) ^ 2 ≠ 0 := pow_ne_zero 2 hden
  have hval : (sig * c / (sig + phi * c) ^ 2 * hh phi + (1 - pArb phi sig c) * dh) * Kf phi
        + (1 - pArb phi sig c) * hh phi * dK
        - Lvr * (-(sig * c) / (sig + phi * c) ^ 2)
      = c / (sig + phi * c) ^ 2 * focRed (Kf phi) dK (hh phi) dh phi sig c Lvr := by
    rw [one_sub_pArb_eq phi sig c hden, focRed]
    field_simp
    ring
  simpa [mObj, hval] using hm

/-! ## M36 (c).  The two readings of the transactional measure, derived both ways -/

/-- The **unconditional alternative** of M36(c): benign trades execute in arb
blocks too, `ℙ_trans = h(φ)`, so the LP objective is `h(φ)f_LPδ - Lvr·ℙ_{Δ_ARB}`
with no complement factor. -/
noncomputable def mObjUncond (Kf hh : ℝ → ℝ) (phi sig c Lvr : ℝ) : ℝ :=
  hh phi * Kf phi - Lvr * pArb phi sig c

lemma hasDerivAt_mObjUncond (Kf hh : ℝ → ℝ) (dK dh phi sig c Lvr : ℝ)
    (hK : HasDerivAt Kf dK phi) (hH : HasDerivAt hh dh phi)
    (hden : sig + phi * c ≠ 0) :
    HasDerivAt (fun f => mObjUncond Kf hh f sig c Lvr)
      (dh * Kf phi + hh phi * dK + Lvr * (sig * c / (sig + phi * c) ^ 2)) phi := by
  have hA := hasDerivAt_pArb phi sig c hden
  have h := (hH.mul hK).sub (hA.const_mul Lvr)
  have hval : dh * Kf phi + hh phi * dK - Lvr * (-(sig * c) / (sig + phi * c) ^ 2)
      = dh * Kf phi + hh phi * dK + Lvr * (sig * c / (sig + phi * c) ^ 2) := by
    field_simp
    ring
  simpa [mObjUncond, hval] using h

/-- **Theorem 48(c) [M36], the gap — derived both ways.**  The exact difference
between the two marginal values, complement-conditioned minus unconditional:

`m'_comp(φ) - m'_uncond(φ) = f_LPδ·(A(φ)h(φ) - ℙ_{Δ_ARB}(φ)h'(φ)) - (f_LPδ)'h(φ)ℙ_{Δ_ARB}(φ)`

with `A(φ) = σc/(σ+cφ)² = ∂(1-ℙ_{Δ_ARB})/∂φ > 0`. -/
private lemma gap_aux (Kv dK hval dh phi c Lvr u : ℝ) (hu : u ≠ 0) :
    c / u ^ 2 * (dK * hval * (phi * u) + Kv * (hval * (u - phi * c) + dh * (phi * u))
        + Lvr * (u - phi * c))
        - (dh * Kv + hval * dK + Lvr * ((u - phi * c) * c / u ^ 2))
      = Kv * ((u - phi * c) * c / u ^ 2 * hval - (u - phi * c) / u * dh)
          - dK * hval * ((u - phi * c) / u) := by
  field_simp
  ring

theorem Theorem48c_complement_marginal_gap (Kv dK hval dh phi sig c Lvr : ℝ)
    (hden : sig + phi * c ≠ 0) :
    c / (sig + phi * c) ^ 2 * focRed Kv dK hval dh phi sig c Lvr
        - (dh * Kv + hval * dK + Lvr * (sig * c / (sig + phi * c) ^ 2))
      = Kv * (sig * c / (sig + phi * c) ^ 2 * hval - pArb phi sig c * dh)
          - dK * hval * pArb phi sig c := by
  have h := gap_aux Kv dK hval dh phi c Lvr (sig + phi * c) hden
  simpa [focRed, pArb, show sig + phi * c - phi * c = sig from by ring] using h

/-- **Theorem 48(c) [M36] — the second channel is a STRICTLY POSITIVE addition to
the marginal value.**  Under **(A-route)** (`f_LPδ` constant, `dK = 0`) and any
nonincreasing participation probability (`dh ≤ 0`, in particular (A-tail)'s
`h' = -αh < 0`), the complement-conditioned reading's marginal value exceeds the
unconditional one at every `φ > 0`.  `(1-ℙ_{Δ_ARB})` is increasing in `φ`, so the
second channel **pushes the root up**. -/
theorem Theorem48c_complement_adds_a_positive_channel (Kv hval dh phi sig c Lvr : ℝ)
    (hK : 0 < Kv) (hh : 0 < hval) (hdh : dh ≤ 0) (hsig : 0 < sig) (hc : 0 < c)
    (hphi : 0 < phi) :
    (dh * Kv + hval * 0 + Lvr * (sig * c / (sig + phi * c) ^ 2))
      < c / (sig + phi * c) ^ 2 * focRed Kv 0 hval dh phi sig c Lvr := by
  have hden : sig + phi * c ≠ 0 := by positivity
  have hgap := Theorem48c_complement_marginal_gap Kv 0 hval dh phi sig c Lvr hden
  have hA : 0 < sig * c / (sig + phi * c) ^ 2 := by positivity
  have hP : 0 < pArb phi sig c := by
    have : 0 < sig + phi * c := by positivity
    exact div_pos hsig this
  have h1 : 0 < Kv * (sig * c / (sig + phi * c) ^ 2 * hval - pArb phi sig c * dh) := by
    have : 0 ≤ -(pArb phi sig c * dh) := by nlinarith
    nlinarith [mul_pos hA hh]
  have h2 : (0 : ℝ) * hval * pArb phi sig c = 0 := by ring
  linarith [hgap, h1, h2]

/-- **Theorem 48(c) [M36] — what the second channel does to the root.**  Under
the hypotheses of `Theorem48c_complement_adds_a_positive_channel`, at any
stationary point of the *unconditional* reading the *complement* reading is
still strictly increasing; hence, if the complement marginal value is antitone
(the single-crossing situation), the complement root lies **strictly to the
right**: the accounting-consistent reading asks for a **higher** fee. -/
theorem Theorem48c_root_shifts_up
    (Fcomp : ℝ → ℝ) (phi0 phi1 : ℝ)
    (hanti : ∀ x y : ℝ, x ≤ y → Fcomp y ≤ Fcomp x)
    (hpos : 0 < Fcomp phi0) (hroot : Fcomp phi1 = 0) : phi0 < phi1 := by
  by_contra hle
  push_neg at hle
  have := hanti phi1 phi0 hle
  rw [hroot] at this
  linarith

/-- **Theorem 48(c) [M36] — which reading is accounting-consistent.**  The
complement reading partitions the block (`Theorem48a_partition`, an identity).
The unconditional reading does **not**: there are admissible parameters at which
`ℙ_{Δ_ARB} + h > 1`, so "arb block" and "benign execution" cannot both be block
events — the split would double-count the arb block's flow, which is exactly
what `DOC` Proposition 9's accounting forbids.  Witness: `σ = c = φ = 1`,
`α = 1/2`. -/
theorem Theorem48c_unconditional_reading_is_not_a_partition :
    ∃ al phi sig c : ℝ, 0 < al ∧ 0 < phi ∧ 0 < sig ∧ 0 < c ∧
      1 < pArb phi sig c + hazTail al phi := by
  refine ⟨1/2, 1, 1, 1, by norm_num, by norm_num, by norm_num, by norm_num, ?_⟩
  have h1 : pArb 1 1 1 = 1/2 := by norm_num [pArb]
  have h2 : (1 : ℝ)/2 < hazTail (1/2) 1 := by
    rw [hazTail]
    have : Real.exp (-(1/2 * 1)) = (Real.exp (1/2))⁻¹ := by
      rw [← Real.exp_neg]; norm_num
    rw [this]
    have hlt : Real.exp ((1:ℝ)/2) < 2 := by
      have h := Real.exp_one_lt_d9
      have hsq : Real.exp ((1:ℝ)/2) ^ 2 = Real.exp 1 := by
        rw [← Real.exp_nat_mul]; norm_num
      nlinarith [Real.exp_pos ((1:ℝ)/2), Real.exp_pos 1]
    rw [lt_inv_comm₀ (by norm_num) (Real.exp_pos _)]
    linarith
  rw [h1]; linarith

/-! ## M36 (d).  `π^{transactional}` — the trader-side object -/

/-- The **per-opportunity** benign payoff: the expected surplus of a benign
trader whose valuation shock must clear the band, `δ·E[(|V|-φ)⁺] = δe^{-αφ}/α`
(`Theorem48d_expected_surplus`).  Trader-side object — standing ban 3:
this is **not** `π^{φ}` and **not** `π^{varphi}`. -/
noncomputable def piTransOpp (al delt phi : ℝ) : ℝ := delt * (hazTail al phi / al)

/-- The **complement-weighted per-block** benign payoff — the form written in
M36(d). -/
noncomputable def piTransBlock (al delt phi sig c : ℝ) : ℝ :=
  (1 - pArb phi sig c) * piTransOpp al delt phi

/-- The **conditional-on-participation** per-block benign payoff — M36(d)'s
literal reading `(1-ℙ_{Δ_ARB})·E[(|V|-band)⁺ | participation]·δ`.  By
memorylessness the conditional mean residual is `1/α`, independent of the
band. -/
noncomputable def piTransCond (al delt phi sig c : ℝ) : ℝ :=
  (1 - pArb phi sig c) * (delt / al)

/-- **Theorem 48(d) [M36] — the shock-space surplus is well defined and has the
closed form `e^{-αb}/α`.**  For the exponential tail of **(A-tail)**,
`E[(|V| - b)⁺] = ∫_{b}^{∞}(x-b)αe^{-αx}dx = e^{-αb}/α`; conditionally on
participation (dividing by `h(b) = e^{-αb}`) it is `1/α`, independent of the
band — memorylessness. -/
theorem Theorem48d_expected_surplus (al b : ℝ) (hal : 0 < al) :
    ∫ x in Set.Ioi b, (x - b) * (al * Real.exp (-(al * x)))
      = hazTail al b / al := by
  set g : ℝ → ℝ := fun x => (-(x - b) - 1/al) * Real.exp (-(al*x)) with hg
  have hderiv : ∀ x ∈ Set.Ioi b, HasDerivAt g ((x - b) * (al * Real.exp (-(al*x)))) x := by
    intro x _
    have h1 : HasDerivAt (fun x : ℝ => -(x - b) - 1/al) (-1) x := by
      simpa using ((hasDerivAt_id x).sub_const b).neg.sub_const (1/al)
    have h2 : HasDerivAt (fun x : ℝ => Real.exp (-(al*x))) (-al * Real.exp (-(al*x))) x := by
      have : HasDerivAt (fun x : ℝ => -(al*x)) (-al) x := by
        simpa using ((hasDerivAt_id x).const_mul al).neg
      simpa [mul_comm] using this.exp
    have h := h1.mul h2
    convert h using 1
    field_simp
    ring
  have hcont : ContinuousWithinAt g (Set.Ici b) b := by
    apply Continuous.continuousWithinAt; fun_prop
  have hnonneg : ∀ x ∈ Set.Ioi b, 0 ≤ (x - b) * (al * Real.exp (-(al*x))) := by
    intro x hx
    have : 0 ≤ x - b := le_of_lt (sub_pos.mpr hx)
    positivity
  have hlim : Filter.Tendsto g Filter.atTop (nhds 0) := by
    have h1 : Filter.Tendsto
        (fun u : ℝ => (b - 1/al) * Real.exp (-u) - (1/al) * (u^1 * Real.exp (-u)))
        Filter.atTop (nhds 0) := by
      have ha := Real.tendsto_exp_neg_atTop_nhds_zero
      have hb := Real.tendsto_pow_mul_exp_neg_atTop_nhds_zero 1
      simpa using (ha.const_mul (b - 1/al)).sub (hb.const_mul (1/al))
    have h2 : Filter.Tendsto (fun x : ℝ => al * x) Filter.atTop Filter.atTop :=
      Filter.Tendsto.const_mul_atTop hal Filter.tendsto_id
    refine (h1.comp h2).congr ?_
    intro x
    simp only [Function.comp_apply, pow_one, hg]
    field_simp
    ring
  have hmain := integral_Ioi_of_hasDerivAt_of_nonneg hcont hderiv hnonneg hlim
  rw [hmain, hg, hazTail]
  field_simp
  ring

/-- **Theorem 48(d) [M36], the half that HOLDS.**  The per-opportunity benign
payoff is strictly decreasing in the fee, on the whole carrier. -/
theorem Theorem48d_piTransOpp_strictAnti (al delt : ℝ) (hal : 0 < al) (hd : 0 < delt) :
    StrictAnti (fun phi => piTransOpp al delt phi) := by
  intro x y hxy
  have hexp : Real.exp (-(al * y)) < Real.exp (-(al * x)) := by
    apply Real.exp_lt_exp.mpr
    nlinarith
  unfold piTransOpp hazTail
  have hdiv : Real.exp (-(al * y)) / al < Real.exp (-(al * x)) / al :=
    (div_lt_div_iff_of_pos_right hal).mpr hexp
  exact mul_lt_mul_of_pos_left hdiv hd

/-- **Theorem 48(d) [M36] — REFUTED as stated, witness exhibited.**  The
complement-weighted per-block payoff written in M36(d) is **not** decreasing in
`φ`: at `σ = c = α = δ = 1` it is strictly larger at `φ = 1/2` than at
`φ = 1/10`.  The reason is structural, not numerical: the complement factor
`(1-ℙ_{Δ_ARB})` **increases** in `φ` (M36(c)'s second channel) and vanishes at
`φ = 0`, so it dominates the exponential decay near the left endpoint. -/
theorem Theorem48d_block_form_is_not_decreasing :
    ¬ ∀ (al delt sig c : ℝ), 0 < al → 0 < delt → 0 < sig → 0 < c →
      StrictAntiOn (fun phi => piTransBlock al delt phi sig c) (Set.Ico (0:ℝ) 1) := by
  intro hcon
  have h := hcon 1 1 1 1 one_pos one_pos one_pos one_pos
  have hmem1 : (1/10 : ℝ) ∈ Set.Ico (0:ℝ) 1 := by constructor <;> norm_num
  have hmem2 : (1/2 : ℝ) ∈ Set.Ico (0:ℝ) 1 := by constructor <;> norm_num
  have hlt := h hmem1 hmem2 (by norm_num)
  have hA : piTransBlock 1 1 (1/10) 1 1 ≤ 1/11 := by
    unfold piTransBlock piTransOpp hazTail pArb
    have h1 : (1 : ℝ) - 1 / (1 + 1/10 * 1) = 1/11 := by norm_num
    rw [h1]
    have : Real.exp (-(1 * (1/10 : ℝ))) ≤ 1 := by
      apply Real.exp_le_one_iff.mpr; norm_num
    nlinarith [Real.exp_pos (-(1 * (1/10 : ℝ)))]
  have hB : (1/6 : ℝ) ≤ piTransBlock 1 1 (1/2) 1 1 := by
    unfold piTransBlock piTransOpp hazTail pArb
    have h1 : (1 : ℝ) - 1 / (1 + 1/2 * 1) = 1/3 := by norm_num
    rw [h1]
    have : (1/2 : ℝ) ≤ Real.exp (-(1 * (1/2 : ℝ))) := by
      have := Real.add_one_le_exp (-(1 * (1/2 : ℝ)))
      linarith
    nlinarith
  linarith

/-- **Theorem 48(d) [M36] — the literal conditional reading is strictly
INCREASING.**  `(1-ℙ_{Δ_ARB})·E[(|V|-band)⁺ | participation]·δ = (1-ℙ_{Δ_ARB})δ/α`
by memorylessness, and `1-ℙ_{Δ_ARB}` increases in `φ`: conditioning on
participation removes the only decreasing factor.  So (d)'s conditional form is
refuted outright, and the object that is well defined **and** strictly
decreasing in `φ` is `piTransOpp`. -/
theorem Theorem48d_conditional_form_is_strictly_increasing
    (al delt sig c : ℝ) (hal : 0 < al) (hd : 0 < delt) (hsig : 0 < sig) (hc : 0 < c) :
    StrictMonoOn (fun phi => piTransCond al delt phi sig c) (Set.Ici (0:ℝ)) := by
  intro x hx y hy hxy
  have hx0 : (0:ℝ) ≤ x := hx
  have hy0 : (0:ℝ) ≤ y := le_trans hx0 hxy.le
  have hdx : 0 < sig + x * c := by positivity
  have hdy : 0 < sig + y * c := by positivity
  have hPx : 1 - pArb x sig c = x * c / (sig + x * c) := one_sub_pArb_eq x sig c hdx.ne'
  have hPy : 1 - pArb y sig c = y * c / (sig + y * c) := one_sub_pArb_eq y sig c hdy.ne'
  have hmono : x * c / (sig + x * c) < y * c / (sig + y * c) := by
    rw [div_lt_div_iff₀ hdx hdy]
    nlinarith [mul_pos (mul_pos (sub_pos.mpr hxy) hc) hsig]
  have hfrac : 0 < delt / al := div_pos hd hal
  simp only [piTransCond, hPx, hPy]
  exact mul_lt_mul_of_pos_right hmono hfrac

end MevTaxTransactional
