import Mathlib
import RequestProject.MevTaxControl

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# The CORRECTED MEV-tax program (M19–M24)

This module formalizes blocks **M19–M24** of `TAX2_ADDENDUM.md`.  It *corrects
the objective* of the first bundle (`MevTaxControl.lean`, M11–M18): replication
`π^σ = π̂^σ` is a **feasibility region**, not the objective, and the first-order
condition of the corrected program is

`∂π̂^σ/∂τ_MEV = 0`.

Results of the first bundle are **cited, not redone**:
`MevTaxControl.Theorem29_monoid_path_is_direct`,
`MevTaxControl.Theorem30_composed_fee_submersion_section_sum_ill_posed`,
`MevTaxControl.Theorem32_hazard_strictAntiOn_tau`,
`MevTaxControl.tau_to_nu_strictAntiOn_under_H2`,
`MevTaxControl.M18_axis_error_refuted`, and the typed hypotheses
`MevTaxControl.H1_dLbar_dpiPhi_pos`, `MevTaxControl.H2_dnu_dlamMEV_pos`.

Notation is unchanged and binding: `L_σ ≡ ΔQ_v^⋆` is the *volatility-axis*
liquidity, plain `L`, `L̄` the *price-axis* pool liquidity; the source's
composite is written out in full as `π^φ - π^LVR`; no symbol is minted.  The
`(·)^+` strike kink is **branched** (`Proposition16_closed_form_and_branch_structure`),
never differentiated through, and the `|·|` objective of the superseded framing
does not appear: the FOC is on a derivative.  Fee guards keep the composed fee
in `[0,1)` wherever a fee limit is taken.

**Deliberately unsettled, and named as such.**

* the sign of `∂²π̂^σ/∂τ_MEV²` at the FOC root under the *level* reading of
  exposure — `Proposition15_level_reading_second_order_undetermined` exhibits two
  plants with the same first-order data and opposite curvature; the hypothesis
  that settles it is single crossing from below of the total derivative
  (`Proposition15_single_crossing_gives_minimum`);
* the strict negativity of `∂ν/∂τ_MEV` at a point: the cited
  `tau_to_nu_strictAntiOn_under_H2` gives only `≤ 0`
  (`dnudtau_nonpos_of_strictAntiOn`,
  `dnudtau_strict_negativity_is_an_extra_hypothesis`), so `dnudtau < 0` is
  carried as a typed hypothesis everywhere it is used;
* (H1) and (H2) themselves are behavioural LP-supply estimands and are never
  discharged.
-/

namespace MevTaxProgram

/-! ## M19. Definition 33 — the corrected tax program -/

/-- Admissibility of the lever: `τ_MEV ∈ [0,1]` (the fee-monoid carrier). -/
def Admissible (tauMEV : ℝ) : Prop := tauMEV ∈ Set.Icc (0 : ℝ) 1

/-- The **feasibility relation** of the corrected program: the replication
relation `π^σ = π̂^σ`.  It constrains the program; it is *not* its objective. -/
def Feasible (piSigma : ℝ) (piHatOf : ℝ → ℝ) (tauMEV : ℝ) : Prop :=
  piSigma = piHatOf tauMEV

/-- The **first-order condition** of the corrected program (M19):
`∂π̂^σ/∂τ_MEV = 0`. -/
def FOC (piHatOf : ℝ → ℝ) (tauMEV : ℝ) : Prop := deriv piHatOf tauMEV = 0

/-- The **superseded** condition of bundle 1, `∂π̂^σ/∂τ_MEV = ΔQ_v^⋆`: the
artefact of the replication framing.  Kept only so that M19 can state that it is
neither the FOC nor the feasibility relation. -/
def SupersededReplicationCondition (dQvStar : ℝ) (piHatOf : ℝ → ℝ)
    (tauMEV : ℝ) : Prop := deriv piHatOf tauMEV = dQvStar

/-- **The exposure functional** `𝓔` of Definition 33: the sensitivity of the
realizable payoff `π̂^σ` to the tax lever, measured as the squared response
`(∂π̂^σ/∂τ_MEV)²`.  It is smooth — the `|·|` of the superseded framing is not
used — and its zero set is exactly the FOC. -/
noncomputable def exposure (piHatOf : ℝ → ℝ) (tauMEV : ℝ) : ℝ :=
  (deriv piHatOf tauMEV) ^ 2

/-- The feasibility region of Definition 33: admissible levers satisfying the
replication constraint. -/
def feasibleRegion (piSigma : ℝ) (piHatOf : ℝ → ℝ) : Set ℝ :=
  {t | Admissible t ∧ Feasible piSigma piHatOf t}

/-- **Definition 33 (The corrected tax program) [M19].**

`min_{τ_MEV ∈ [0,1]} 𝓔(τ_MEV)  subject to  π^σ = π̂^σ`,

i.e. `τ_MEV` is feasible and minimizes the exposure over the feasibility
region.  The constraint set is a feasibility region, not the objective. -/
def Definition33_CorrectedTaxProgram (piSigma : ℝ) (piHatOf : ℝ → ℝ)
    (tauMEV : ℝ) : Prop :=
  tauMEV ∈ feasibleRegion piSigma piHatOf ∧
    IsMinOn (exposure piHatOf) (feasibleRegion piSigma piHatOf) tauMEV

/-- **M19 (the objective, and what it is not).**

1. The FOC is exactly the vanishing of the exposure, and a lever satisfying it
   is an *unconstrained* global minimiser of `𝓔` (`𝓔 ≥ 0`).
2. A lever satisfying the FOC need **not** be feasible.
3. A feasible lever need **not** satisfy the FOC.
4. The superseded condition `∂π̂^σ/∂τ_MEV = ΔQ_v^⋆` (with `ΔQ_v^⋆ ≠ 0`) is
   **neither**: it can hold while both the FOC and feasibility fail.

Hence replication is a constraint set, not the objective, and the bundle-1
condition is an artefact of the superseded framing. -/
theorem M19_FOC_is_not_feasibility :
    (∀ (piHatOf : ℝ → ℝ) (t : ℝ),
        FOC piHatOf t ↔ exposure piHatOf t = 0) ∧
      (∀ (piHatOf : ℝ → ℝ) (t : ℝ),
        FOC piHatOf t → IsMinOn (exposure piHatOf) Set.univ t) ∧
      (∃ (piHatOf : ℝ → ℝ) (piSigma t : ℝ),
        Admissible t ∧ FOC piHatOf t ∧ ¬ Feasible piSigma piHatOf t) ∧
      (∃ (piHatOf : ℝ → ℝ) (piSigma t : ℝ),
        Admissible t ∧ Feasible piSigma piHatOf t ∧ ¬ FOC piHatOf t) ∧
      (∃ (piHatOf : ℝ → ℝ) (piSigma dQvStar t : ℝ),
        Admissible t ∧ dQvStar ≠ 0 ∧
          SupersededReplicationCondition dQvStar piHatOf t ∧
          ¬ FOC piHatOf t ∧ ¬ Feasible piSigma piHatOf t) := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro f t
    simp [FOC, exposure]
  · intro f t h
    rw [isMinOn_iff]
    intro x _
    have h0 : exposure f t = 0 := by
      simp only [exposure, FOC] at h ⊢; rw [h]; ring
    rw [h0]
    simp only [exposure]
    positivity
  · exact ⟨fun _ => 0, 1, 1 / 2, ⟨by norm_num, by norm_num⟩, by simp [FOC],
      by simp [Feasible]⟩
  · exact ⟨fun x => x, 1 / 2, 1 / 2, ⟨by norm_num, by norm_num⟩, by simp [Feasible],
      by simp [FOC]⟩
  · exact ⟨fun x => x, 0, 1, 1 / 2, ⟨by norm_num, by norm_num⟩, one_ne_zero,
      by simp [SupersededReplicationCondition], by simp [FOC], by simp [Feasible]⟩

/-! ## M20. Theorem 33 — the correct total derivative, as a sum over paths -/

/-- The **composed fee** along the `τ_MEV` fibre: Rule 12's monoid
`φ_M ⊗_φ φ_X ⊗_φ τ_MEV`, where the taker leg `φ_X` is `DOC` Definition 18's
utilization-gated schedule evaluated at the utilization `ν(τ_MEV)`.  The tax
enters **twice**: directly (the monoid slot) and through `ν`. -/
noncomputable def phiTot (phiM : ℝ) (phiX nu : ℝ → ℝ) (tauMEV : ℝ) : ℝ :=
  MevTaxControl.phiTotal phiM (phiX (nu tauMEV)) tauMEV

/-- The realizable payoff along the `τ_MEV` fibre:
`τ_MEV → φ_total → π^φ → L̄ → π̂^σ`, with `Fhat` the price-axis kernel
`L̄ ↦ π̂^σ = ∑_{i_K} L(i_K) π^l`. -/
noncomputable def piHat (Fhat Lbar piPhiOf : ℝ → ℝ) (phiM : ℝ)
    (phiX nu : ℝ → ℝ) (tauMEV : ℝ) : ℝ :=
  Fhat (Lbar (piPhiOf (phiTot phiM phiX nu tauMEV)))

/-- **(P-direct)**, the Rule 12 monoid path `τ_MEV → φ_total → … → π̂^σ`.
`A = (∂π̂^σ/∂L̄)(∂L̄/∂π^φ)(∂π^φ/∂φ)` is the outer chain factor; the monoid
factor `(1-φ_M)(1-φ_X)` is `MevTaxControl.Theorem29_monoid_path_is_direct`. -/
noncomputable def pathDirect (A phiM phiXv : ℝ) : ℝ := A * (1 - phiM) * (1 - phiXv)

/-- **(P-gate)**, the utilization-gate path
`τ_MEV → ν → φ → π^φ → L̄ → π̂^σ`.  The monoid Jacobian `(1-φ_M)(1-τ_MEV)` is
`∂φ_total/∂φ_X`. -/
noncomputable def pathGate (A phiM tauMEV dphidnu dnudtau : ℝ) : ℝ :=
  A * (1 - phiM) * ((1 - tauMEV) * (dphidnu * dnudtau))

/-- The total derivative `∂π̂^σ/∂τ_MEV` as the **sum over paths**. -/
noncomputable def totalDeriv (A phiM tauMEV phiXv dphidnu dnudtau : ℝ) : ℝ :=
  pathDirect A phiM phiXv + pathGate A phiM tauMEV dphidnu dnudtau

/-- The source's five-factor product
`(∂π̂^σ/∂L)(∂L/∂π^φ)(∂π^φ/∂φ)(∂φ/∂ν)(∂ν/∂τ_MEV)`. -/
noncomputable def fiveFactorProduct (A dphidnu dnudtau : ℝ) : ℝ := A * dphidnu * dnudtau

/-- The composed fee's derivative in the tax is the sum of the direct monoid
contribution and the gate contribution. -/
lemma hasDerivAt_phiTot (phiM : ℝ) (phiX nu : ℝ → ℝ) (tauMEV dphidnu dnudtau : ℝ)
    (hnu : HasDerivAt nu dnudtau tauMEV)
    (hphiX : HasDerivAt phiX dphidnu (nu tauMEV)) :
    HasDerivAt (fun t => phiTot phiM phiX nu t)
      (totalDeriv 1 phiM tauMEV (phiX (nu tauMEV)) dphidnu dnudtau) tauMEV := by
  have hu : HasDerivAt (fun t => phiX (nu t)) (dphidnu * dnudtau) tauMEV :=
    hphiX.comp tauMEV hnu
  have h1 : HasDerivAt (fun t : ℝ => 1 - phiX (nu t)) (-(dphidnu * dnudtau)) tauMEV :=
    hu.const_sub 1
  have h2 : HasDerivAt (fun t : ℝ => 1 - t) (-1 : ℝ) tauMEV := by
    simpa using (hasDerivAt_id tauMEV).const_sub 1
  have h4 := ((h1.mul h2).const_mul (1 - phiM)).const_sub 1
  have hfun : (fun t => phiTot phiM phiX nu t)
      = fun t => 1 - (1 - phiM) * ((1 - phiX (nu t)) * (1 - t)) := by
    funext t
    simp only [phiTot, MevTaxControl.phiTotal_eq]
    ring
  rw [hfun]
  convert h4 using 1
  show pathDirect 1 phiM (phiX (nu tauMEV)) + pathGate 1 phiM tauMEV dphidnu dnudtau = _
  unfold pathDirect pathGate
  ring

/-- **Theorem 33 (Path decomposition of `∂π̂^σ/∂τ_MEV`) [M20].**  The tax reaches
the realizable payoff by **two** routes, and the total derivative is their
**sum**:

`∂π̂^σ/∂τ_MEV = A(1-φ_M)(1-φ_X) + A(1-φ_M)(1-τ_MEV)(∂φ/∂ν)(∂ν/∂τ_MEV)`,

with `A = (∂π̂^σ/∂L̄)(∂L̄/∂π^φ)(∂π^φ/∂φ)` the outer chain factor.  The first
summand is (P-direct) — Rule 12's monoid path,
`MevTaxControl.Theorem29_monoid_path_is_direct` — and the second is (P-gate),
the utilization path `τ_MEV → ν → φ → π^φ → L̄ → π̂^σ` carried to `π̂^σ` by the
price-axis liquidity response (H1).

**Exhaustiveness.**  For this plant the two routes are exhaustive: `τ_MEV`
reaches `π̂^σ` only through `phiTot`, and `phiTot` contains `τ_MEV` only in its
monoid slot and inside `ν`; the chain rule therefore produces exactly these two
summands and no others.  A third route would require a further occurrence of
`τ_MEV` in `Fhat`, `L̄`, `π^φ`, `φ_M` or `φ_X`, i.e. a different plant. -/
theorem Theorem33_path_decomposition
    (Fhat Lbar piPhiOf phiX nu : ℝ → ℝ) (phiM tauMEV cF cL cP dphidnu dnudtau : ℝ)
    (hnu : HasDerivAt nu dnudtau tauMEV)
    (hphiX : HasDerivAt phiX dphidnu (nu tauMEV))
    (hP : HasDerivAt piPhiOf cP (phiTot phiM phiX nu tauMEV))
    (hL : HasDerivAt Lbar cL (piPhiOf (phiTot phiM phiX nu tauMEV)))
    (hF : HasDerivAt Fhat cF (Lbar (piPhiOf (phiTot phiM phiX nu tauMEV)))) :
    HasDerivAt (fun t => piHat Fhat Lbar piPhiOf phiM phiX nu t)
      (totalDeriv (cF * cL * cP) phiM tauMEV (phiX (nu tauMEV)) dphidnu dnudtau)
      tauMEV := by
  have h0 := hasDerivAt_phiTot phiM phiX nu tauMEV dphidnu dnudtau hnu hphiX
  have h3 := hF.comp tauMEV ((hL.comp tauMEV (hP.comp tauMEV h0)))
  convert h3 using 1
  show totalDeriv (cF * cL * cP) phiM tauMEV (phiX (nu tauMEV)) dphidnu dnudtau
      = cF * (cL * (cP * totalDeriv 1 phiM tauMEV (phiX (nu tauMEV)) dphidnu dnudtau))
  simp only [totalDeriv, pathDirect, pathGate]
  ring

/-- **Theorem 33, second half [M20]: the five-factor product is exactly one
summand.**

1. Reading the source's `∂φ/∂ν` as the derivative of the **composed** fee in the
   utilization, `∂φ_total/∂ν = (1-φ_M)(1-τ_MEV)(∂φ_X/∂ν)`, the five-factor
   product is *literally* the (P-gate) summand.
2. Reading it as `DOC` Definition 18's own gate derivative `∂φ_X/∂ν`
   (the boxed form of `ENTRY_POINT_dphi_dnu.md`), the product additionally omits
   the monoid Jacobian `(1-φ_M)(1-τ_MEV)`.
3. Either way it equals the total derivative **iff** the direct path vanishes. -/
theorem Theorem33_five_factor_product_is_one_summand
    (A phiM tauMEV phiXv dphidnu dnudtau : ℝ) :
    fiveFactorProduct A ((1 - phiM) * (1 - tauMEV) * dphidnu) dnudtau
        = pathGate A phiM tauMEV dphidnu dnudtau ∧
      pathGate A phiM tauMEV dphidnu dnudtau
        = (1 - phiM) * (1 - tauMEV) * fiveFactorProduct A dphidnu dnudtau ∧
      (totalDeriv A phiM tauMEV phiXv dphidnu dnudtau
          = fiveFactorProduct A ((1 - phiM) * (1 - tauMEV) * dphidnu) dnudtau
        ↔ pathDirect A phiM phiXv = 0) := by
  simp only [fiveFactorProduct, pathGate, totalDeriv, pathDirect]
  refine ⟨by ring, by ring, ?_⟩
  constructor <;> intro h <;> linarith

/-! ## M21. The utilization gate, and the opposed signs -/

/-- The volatility surcharge `∑_j α_j/(1+exp(γ_j(β_j-σ)))` of `DOC`
Definition 18. -/
noncomputable def volSurcharge (n : ℕ) (γ β α : ℕ → ℝ) (σ : ℝ) : ℝ :=
  ∑ j ∈ Finset.range n, α j / (1 + Real.exp (γ j * (β j - σ)))

/-- `DOC` Definition 18's **utilization gate** `α_R/(1+exp(γ_R(β_R-ν)))`, as a
function of the utilization ratio `ν`. -/
noncomputable def gateFactor (alphaR gammaR betaR nu : ℝ) : ℝ :=
  alphaR / (1 + Real.exp (gammaR * (betaR - nu)))

/-- `DOC` Definition 18's fee level as a function of the utilization ratio `ν`:
`φ(σ; ν) = φ̄ + (∑_j α_j/(1+exp(γ_j(β_j-σ)))) · α_R/(1+exp(γ_R(β_R-ν)))`. -/
noncomputable def feeLevel (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu : ℝ) : ℝ :=
  phibar + volSurcharge n γ β α σ * gateFactor alphaR gammaR betaR nu

/-- The **boxed** `∂φ/∂ν` of `ENTRY_POINT_dphi_dnu.md`, transcribed:
`α_R γ_R (∑_j α_j/(1+exp(γ_j(β_j-σ)))) · exp(γ_R(β_R-ν))/[1+exp(γ_R(β_R-ν))]²`. -/
noncomputable def dphidnuBoxed (n : ℕ) (γ β α : ℕ → ℝ)
    (σ alphaR gammaR betaR nu : ℝ) : ℝ :=
  alphaR * gammaR * volSurcharge n γ β α σ *
    (Real.exp (gammaR * (betaR - nu)) / (1 + Real.exp (gammaR * (betaR - nu))) ^ 2)

/-- Definition 18's fee level is `VolInstrument.multiFee` evaluated at the gate
value: the schedule already in the project is reused, not redefined. -/
lemma feeLevel_eq_multiFee (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu : ℝ) :
    feeLevel n γ β α phibar σ alphaR gammaR betaR nu
      = VolInstrument.multiFee n γ β α phibar (gateFactor alphaR gammaR betaR nu) σ := by
  unfold feeLevel volSurcharge VolInstrument.multiFee
  congr 2
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [FeeSchedule.logistic, show -(γ j * (σ - β j)) = γ j * (β j - σ) by ring]
  ring

/-- The boxed `∂φ/∂ν` **is** the derivative of Definition 18's fee level in the
utilization. -/
lemma hasDerivAt_feeLevel_nu (n : ℕ) (γ β α : ℕ → ℝ)
    (phibar σ alphaR gammaR betaR nu : ℝ) :
    HasDerivAt (fun v => feeLevel n γ β α phibar σ alphaR gammaR betaR v)
      (dphidnuBoxed n γ β α σ alphaR gammaR betaR nu) nu := by
  have hz : HasDerivAt (fun v : ℝ => gammaR * (betaR - v)) (-gammaR) nu := by
    simpa using ((hasDerivAt_id nu).const_sub betaR).const_mul gammaR
  have hden : HasDerivAt (fun v : ℝ => 1 + Real.exp (gammaR * (betaR - v)))
      (Real.exp (gammaR * (betaR - nu)) * (-gammaR)) nu := by
    simpa using hz.exp.const_add 1
  have hne : (1 : ℝ) + Real.exp (gammaR * (betaR - nu)) ≠ 0 := by positivity
  have hg := (hasDerivAt_const nu alphaR).div hden hne
  have hg' : HasDerivAt (fun v => gateFactor alphaR gammaR betaR v)
      (alphaR * gammaR * (Real.exp (gammaR * (betaR - nu)) /
        (1 + Real.exp (gammaR * (betaR - nu))) ^ 2)) nu := by
    convert hg using 1
    field_simp
    ring
  have hfin := (hg'.const_mul (volSurcharge n γ β α σ)).const_add phibar
  convert hfin using 1
  unfold dphidnuBoxed
  ring

lemma volSurcharge_pos (n : ℕ) (γ β α : ℕ → ℝ) (σ : ℝ)
    (halpha : ∀ j, 0 ≤ α j) (hj : ∃ j < n, 0 < α j) : 0 < volSurcharge n γ β α σ := by
  obtain ⟨j0, hj0n, hj0⟩ := hj
  exact Finset.sum_pos' (fun j _ => div_nonneg (halpha j) (by positivity))
    ⟨j0, Finset.mem_range.mpr hj0n, div_pos hj0 (by positivity)⟩

lemma volSurcharge_nonneg (n : ℕ) (γ β α : ℕ → ℝ) (σ : ℝ) (halpha : ∀ j, 0 ≤ α j) :
    0 ≤ volSurcharge n γ β α σ :=
  Finset.sum_nonneg (fun j _ => div_nonneg (halpha j) (by positivity))

lemma volSurcharge_le (n : ℕ) (γ β α : ℕ → ℝ) (σ : ℝ) (halpha : ∀ j, 0 ≤ α j) :
    volSurcharge n γ β α σ ≤ ∑ j ∈ Finset.range n, α j := by
  refine Finset.sum_le_sum (fun j _ => ?_)
  rw [div_le_iff₀ (by positivity)]
  nlinarith [Real.exp_pos (γ j * (β j - σ)), halpha j]

/-- The boxed `∂φ/∂ν` is **strictly positive** exactly under the responsiveness
conditions of M21: `α_R, γ_R > 0` and `α_j ≥ 0` not all zero. -/
lemma dphidnuBoxed_pos (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR nu : ℝ)
    (halphaR : 0 < alphaR) (hgammaR : 0 < gammaR)
    (halpha : ∀ j, 0 ≤ α j) (hj : ∃ j < n, 0 < α j) :
    0 < dphidnuBoxed n γ β α σ alphaR gammaR betaR nu := by
  have hS : 0 < volSurcharge n γ β α σ := volSurcharge_pos n γ β α σ halpha hj
  unfold dphidnuBoxed
  positivity

lemma dphidnuBoxed_nonneg (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR nu : ℝ)
    (halphaR : 0 ≤ alphaR) (hgammaR : 0 ≤ gammaR) (halpha : ∀ j, 0 ≤ α j) :
    0 ≤ dphidnuBoxed n γ β α σ alphaR gammaR betaR nu := by
  have hS := volSurcharge_nonneg n γ β α σ halpha
  unfold dphidnuBoxed
  have hb : (0:ℝ) ≤ Real.exp (gammaR * (betaR - nu)) /
      (1 + Real.exp (gammaR * (betaR - nu))) ^ 2 := by positivity
  have hc : (0:ℝ) ≤ alphaR * gammaR * volSurcharge n γ β α σ := by positivity
  exact mul_nonneg hc hb

/-- **Exact saturation is a degeneracy of the parameters, not of the state.**
The boxed gate derivative vanishes **iff** `α_R γ_R (∑_j α_j Λ_j) = 0`; the
sigmoid factor `e^z/(1+e^z)²` is strictly positive at every utilization.  So for
a responsive gate (`α_R, γ_R > 0`, some `α_j > 0`, `dphidnuBoxed_pos`) the gate
path never dies exactly, and the operative statement of Theorem 36 is the
*quantitative* band, not exact saturation. -/
lemma dphidnuBoxed_eq_zero_iff (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR nu : ℝ) :
    dphidnuBoxed n γ β α σ alphaR gammaR betaR nu = 0
      ↔ alphaR * gammaR * volSurcharge n γ β α σ = 0 := by
  have hb : Real.exp (gammaR * (betaR - nu)) /
      (1 + Real.exp (gammaR * (betaR - nu))) ^ 2 ≠ 0 := by positivity
  unfold dphidnuBoxed
  constructor
  · intro h
    rcases mul_eq_zero.mp h with h1 | h1
    · exact h1
    · exact absurd h1 hb
  · intro h; rw [h, zero_mul]

/-- Strict antitonicity of `τ_MEV ↦ ν` — the already-proved
`MevTaxControl.tau_to_nu_strictAntiOn_under_H2` — gives `∂ν/∂τ_MEV ≤ 0` at
interior points, and **no more**. -/
lemma dnudtau_nonpos_of_strictAntiOn (nuOf : ℝ → ℝ) (tauMEV dnudtau : ℝ)
    (hanti : StrictAntiOn nuOf (Set.Icc 0 1))
    (hmem : tauMEV ∈ Set.Ioo (0 : ℝ) 1)
    (hd : HasDerivAt nuOf dnudtau tauMEV) : dnudtau ≤ 0 := by
  refine le_of_tendsto (hasDerivAt_iff_tendsto_slope.mp hd) ?_
  have hnhds : Set.Ioo (0:ℝ) 1 ∈ nhdsWithin tauMEV {tauMEV}ᶜ :=
    mem_nhdsWithin_of_mem_nhds (isOpen_Ioo.mem_nhds hmem)
  filter_upwards [hnhds, self_mem_nhdsWithin] with y hy hne
  have hyI : y ∈ Set.Icc (0:ℝ) 1 := ⟨le_of_lt hy.1, le_of_lt hy.2⟩
  have htI : tauMEV ∈ Set.Icc (0:ℝ) 1 := ⟨le_of_lt hmem.1, le_of_lt hmem.2⟩
  rw [slope_def_field]
  rcases lt_or_gt_of_ne (hne : y ≠ tauMEV) with h | h
  · exact div_nonpos_of_nonneg_of_nonpos (by linarith [hanti hyI htI h])
      (by linarith)
  · exact div_nonpos_of_nonpos_of_nonneg (by linarith [hanti htI hyI h])
      (by linarith)

/-- A cubic and its derivative, used to build the explicit witnesses below. -/
lemma hasDerivAt_cubic (a b c d t : ℝ) :
    HasDerivAt (fun s => a*s^3 + b*s^2 + c*s + d) (3*a*t^2 + 2*b*t + c) t := by
  have h3 : HasDerivAt (fun s : ℝ => s^3) (3*t^2) t := by simpa using hasDerivAt_pow 3 t
  have h2 : HasDerivAt (fun s : ℝ => s^2) (2*t) t := by simpa using hasDerivAt_pow 2 t
  have h1 : HasDerivAt (fun s : ℝ => s) 1 t := hasDerivAt_id t
  have h := (((h3.const_mul a).add (h2.const_mul b)).add (h1.const_mul c)).add_const d
  convert h using 1
  ring

/-- Strict antitonicity does **not** give strict negativity of the derivative:
`t ↦ -(t-1/2)³` is strictly antitone on `[0,1]` with vanishing derivative at the
interior point `1/2`.  So `∂ν/∂τ_MEV < 0` is an extra hypothesis, carried as a
typed argument wherever M21–M24 use it. -/
theorem dnudtau_strict_negativity_is_an_extra_hypothesis :
    ∃ (nuOf : ℝ → ℝ) (tauMEV : ℝ), StrictAntiOn nuOf (Set.Icc 0 1) ∧
      tauMEV ∈ Set.Ioo (0 : ℝ) 1 ∧ HasDerivAt nuOf 0 tauMEV := by
  refine ⟨fun t => -(t - 1/2)^3, 1/2, ?_, by norm_num, ?_⟩
  · intro a _ b _ hab
    have h3 : (a - 1/2)^3 < (b - 1/2)^3 :=
      (Odd.strictMono_pow (R := ℝ) (n := 3) ⟨1, by norm_num⟩) (by linarith)
    simpa using h3
  · have h := hasDerivAt_cubic (-1) (3/2) (-3/4) (1/8) (1/2 : ℝ)
    have hfun : (fun t : ℝ => -(t - 1/2)^3)
        = fun s : ℝ => (-1)*s^3 + (3/2)*s^2 + (-3/4)*s + (1/8) := by funext s; ring
    rw [hfun]
    convert h using 1
    norm_num

/-- **Theorem 34 (Opposed signs) [M21].**  With the outer chain factor `A > 0`
(`∂π̂^σ/∂L̄ > 0` from the ladder, `∂L̄/∂π^φ > 0` from **(H1)**,
`∂π^φ/∂φ > 0`), the composed fee in `[0,1)` (`φ_M < 1`, `φ_X < 1`, guarding
`MevOptimization.ptrade`'s Möbius pole), `τ_MEV` interior, `∂φ/∂ν > 0` (the boxed
gate form under `α_R, γ_R > 0`, `α_j ≥ 0` not all zero — `dphidnuBoxed_pos`) and
`∂ν/∂τ_MEV < 0` (`MevTaxControl.Theorem32_hazard_strictAntiOn_tau` with
**(H2)**):

* (P-direct) `> 0`,
* (P-gate) `< 0`,

and the total derivative is their sum. -/
theorem Theorem34_opposed_signs
    (A phiM tauMEV phiXv dphidnu dnudtau : ℝ)
    (hA : 0 < A) (hM : phiM < 1) (hX : phiXv < 1)
    (htau : tauMEV ∈ Set.Ioo (0 : ℝ) 1)
    (hdphi : 0 < dphidnu) (hdnu : dnudtau < 0) :
    0 < pathDirect A phiM phiXv ∧
      pathGate A phiM tauMEV dphidnu dnudtau < 0 ∧
      totalDeriv A phiM tauMEV phiXv dphidnu dnudtau
        = pathDirect A phiM phiXv + pathGate A phiM tauMEV dphidnu dnudtau := by
  have h1 : 0 < A * (1 - phiM) := mul_pos hA (by linarith)
  refine ⟨mul_pos h1 (by linarith), ?_, rfl⟩
  have h2 : (1 - tauMEV) * (dphidnu * dnudtau) < 0 :=
    mul_neg_of_pos_of_neg (by linarith [htau.2]) (mul_neg_of_pos_of_neg hdphi hdnu)
  simpa [pathGate] using mul_neg_of_pos_of_neg h1 h2

/-- **Theorem 34, the consequence [M21]: omitting (P-direct) can reverse the
sign.**  There is admissible data with the full sign structure of Theorem 34 in
which (P-gate) alone is **negative** while the true total derivative is
**positive** — and, symmetrically, data where both are negative.  So the
gate-only answer is not merely too small: it can point the controller the wrong
way.  Economically: the tax stacks mechanically onto the fee while suppressing
utilization closes the volatility gate, and which effect wins is a quantitative
question the gate-only formula cannot even pose. -/
theorem Theorem34_omitting_direct_can_reverse_sign :
    (∃ (A phiM tauMEV phiXv dphidnu dnudtau : ℝ),
        0 < A ∧ phiM < 1 ∧ phiXv < 1 ∧ tauMEV ∈ Set.Ioo (0 : ℝ) 1 ∧
          0 < dphidnu ∧ dnudtau < 0 ∧
          pathGate A phiM tauMEV dphidnu dnudtau < 0 ∧
          0 < totalDeriv A phiM tauMEV phiXv dphidnu dnudtau) ∧
      (∃ (A phiM tauMEV phiXv dphidnu dnudtau : ℝ),
        0 < A ∧ phiM < 1 ∧ phiXv < 1 ∧ tauMEV ∈ Set.Ioo (0 : ℝ) 1 ∧
          0 < dphidnu ∧ dnudtau < 0 ∧
          pathGate A phiM tauMEV dphidnu dnudtau < 0 ∧
          totalDeriv A phiM tauMEV phiXv dphidnu dnudtau < 0) := by
  constructor
  · exact ⟨1, 0, 1/2, 0, 1, -(1/10), by norm_num, by norm_num, by norm_num,
      ⟨by norm_num, by norm_num⟩, by norm_num, by norm_num,
      by norm_num [pathGate], by norm_num [totalDeriv, pathDirect, pathGate]⟩
  · exact ⟨1, 0, 1/2, 0, 1, -10, by norm_num, by norm_num, by norm_num,
      ⟨by norm_num, by norm_num⟩, by norm_num, by norm_num,
      by norm_num [pathGate], by norm_num [totalDeriv, pathDirect, pathGate]⟩

/-- **Theorem 34, the two signs read off the cited hypotheses [M21].**  With
**(H1)** and **(H2)** carried as typed arguments and never discharged:

* the price-axis factor of `A` is strictly positive — this is exactly (H1);
* `τ_MEV ↦ ν(λ_MEV(τ_MEV))` is strictly antitone on the carrier `[0,1]` by
  `MevTaxControl.tau_to_nu_strictAntiOn_under_H2` (itself
  `MevTaxControl.Theorem32_hazard_strictAntiOn_tau` composed with (H2)), whence
  `∂ν/∂τ_MEV ≤ 0` at every interior point.

Strict negativity is *not* implied (`dnudtau_strict_negativity_is_an_extra_hypothesis`)
and is therefore assumed separately in Theorem 34. -/
theorem Theorem34_signs_from_H1_H2
    (Lbar nu : ℝ → ℝ) (hH1 : MevTaxControl.H1_dLbar_dpiPhi_pos Lbar)
    (hH2 : MevTaxControl.H2_dnu_dlamMEV_pos nu)
    (n : ℕ) (γ β α : ℕ → ℝ) (phibar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hphibar : 0 ≤ phibar) (halpha : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u)
    (hfee_lt_one : ∀ t < T, VolInstrument.multiFee n γ β α phibar u (σpath t) < 1)
    (ha : ∀ t < T, 0 ≤ a t) (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hD : ∀ t < T, 0 < D t) (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt)
    (lamMEV : ℝ → ℝ)
    (hclearing : ∀ tauMEV,
      lamMEV tauMEV = MevTaxControl.mevMultiTaxed n γ β α phibar u σpath a D Δt T tauMEV)
    (piPhi cF cP : ℝ) (hcF : 0 < cF) (hcP : 0 < cP)
    (tauMEV dnudtau : ℝ) (htau : tauMEV ∈ Set.Ioo (0 : ℝ) 1)
    (hd : HasDerivAt (fun t => nu (lamMEV t)) dnudtau tauMEV) :
    0 < cF * deriv Lbar piPhi * cP ∧ dnudtau ≤ 0 := by
  refine ⟨mul_pos (mul_pos hcF (hH1 piPhi)) hcP, ?_⟩
  · exact dnudtau_nonpos_of_strictAntiOn (fun t => nu (lamMEV t)) tauMEV dnudtau
      (MevTaxControl.tau_to_nu_strictAntiOn_under_H2 nu hH2 n γ β α phibar u σpath a D Δt T
        hphibar halpha hu hfee_lt_one ha ha_pos hD hσ hΔt lamMEV hclearing)
      htau hd

/-! ## M22. The first-order condition: interior cancellation, and its domain -/

/-- The **FOC core**: the total derivative stripped of the strictly positive
common factor `A(1-φ_M)`.  Its zeros are exactly the FOC's zeros. -/
noncomputable def focCore (tauMEV phiXv dphidnu dnudtau : ℝ) : ℝ :=
  (1 - phiXv) + (1 - tauMEV) * (dphidnu * dnudtau)

lemma mul_left_eq_zero_iff' (a b : ℝ) (h : a ≠ 0) : a * b = 0 ↔ b = 0 := by
  constructor
  · intro hh
    rcases mul_eq_zero.mp hh with h1 | h1
    · exact absurd h1 h
    · exact h1
  · intro hh
    rw [hh, mul_zero]

/-- `totalDeriv` factors as `A(1-φ_M)` times the FOC core. -/
lemma totalDeriv_eq_core (A phiM tauMEV phiXv dphidnu dnudtau : ℝ) :
    totalDeriv A phiM tauMEV phiXv dphidnu dnudtau
      = A * (1 - phiM) * focCore tauMEV phiXv dphidnu dnudtau := by
  simp only [totalDeriv, pathDirect, pathGate, focCore]; ring

/-- With `A(1-φ_M) ≠ 0`, the FOC is exactly the vanishing of the core. -/
lemma totalDeriv_eq_zero_iff (A phiM tauMEV phiXv dphidnu dnudtau : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) :
    totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0
      ↔ focCore tauMEV phiXv dphidnu dnudtau = 0 := by
  rw [totalDeriv_eq_core]
  exact mul_left_eq_zero_iff' _ _ (mul_ne_zero hA (sub_ne_zero.mpr (Ne.symm hM)))

/-- The FOC core vanishes exactly at the corrected law's fixed-point equation. -/
lemma focCore_eq_zero_iff (tauMEV phiXv g : ℝ) (hg : g ≠ 0) :
    (1 - phiXv) + (1 - tauMEV) * g = 0 ↔ tauMEV = 1 + (1 - phiXv) / g := by
  constructor
  · intro h; field_simp; nlinarith [h]
  · intro h; field_simp at h; nlinarith [h]

/-- **Theorem 35 (Existence of an interior root) [M22].**

1. *Sufficiency (IVT).*  If the total-derivative function `D` is continuous on
   `[0,1]` and changes sign (`D 0 < 0 < D 1`), it has a root in `(0,1)` — the tax
   at which (P-direct) and (P-gate) cancel.  No absolute value and no
   stationarity of `|·|` is used.
2. *Necessary and sufficient.*  If in addition `D` is strictly increasing on
   `[0,1]`, an interior root exists **iff** `D 0 < 0 < D 1`.
3. *Uniqueness.*  Under strict monotonicity the interior root is unique. -/
theorem Theorem35_interior_root :
    (∀ D : ℝ → ℝ, ContinuousOn D (Set.Icc 0 1) → D 0 < 0 → 0 < D 1 →
        ∃ t ∈ Set.Ioo (0 : ℝ) 1, D t = 0) ∧
      (∀ D : ℝ → ℝ, ContinuousOn D (Set.Icc 0 1) → StrictMonoOn D (Set.Icc 0 1) →
        ((∃ t ∈ Set.Ioo (0 : ℝ) 1, D t = 0) ↔ (D 0 < 0 ∧ 0 < D 1))) ∧
      (∀ D : ℝ → ℝ, StrictMonoOn D (Set.Icc 0 1) →
        ∀ t₁ ∈ Set.Ioo (0 : ℝ) 1, ∀ t₂ ∈ Set.Ioo (0 : ℝ) 1,
          D t₁ = 0 → D t₂ = 0 → t₁ = t₂) := by
  have hIVT : ∀ D : ℝ → ℝ, ContinuousOn D (Set.Icc 0 1) → D 0 < 0 → 0 < D 1 →
      ∃ t ∈ Set.Ioo (0 : ℝ) 1, D t = 0 := by
    intro D hc h0 h1
    obtain ⟨t, ht, hDt⟩ :=
      intermediate_value_Ioo (le_of_lt (by norm_num : (0:ℝ) < 1)) hc ⟨h0, h1⟩
    exact ⟨t, ht, hDt⟩
  refine ⟨hIVT, ?_, ?_⟩
  · intro D hc hmono
    constructor
    · rintro ⟨t, ht, hDt⟩
      have h0 : (0:ℝ) ∈ Set.Icc (0:ℝ) 1 := by norm_num
      have h1 : (1:ℝ) ∈ Set.Icc (0:ℝ) 1 := by norm_num
      have htI : t ∈ Set.Icc (0:ℝ) 1 := ⟨le_of_lt ht.1, le_of_lt ht.2⟩
      exact ⟨by have := hmono h0 htI ht.1; linarith,
        by have := hmono htI h1 ht.2; linarith⟩
    · rintro ⟨h0, h1⟩
      exact hIVT D hc h0 h1
  · intro D hmono t₁ ht₁ t₂ ht₂ hD1 hD2
    have h1I : t₁ ∈ Set.Icc (0:ℝ) 1 := ⟨le_of_lt ht₁.1, le_of_lt ht₁.2⟩
    have h2I : t₂ ∈ Set.Icc (0:ℝ) 1 := ⟨le_of_lt ht₂.1, le_of_lt ht₂.2⟩
    rcases lt_trichotomy t₁ t₂ with h | h | h
    · have := hmono h1I h2I h; linarith
    · exact h
    · have := hmono h2I h1I h; linarith

/-- **Theorem 35, applied to the plant [M22]: the sign change is free at the
right endpoint, and the whole existence question is "does the gate dominate at
zero tax?".**

At `τ_MEV = 1` the gate path carries the monoid Jacobian factor `(1-τ_MEV) = 0`,
so it dies and `D(1) = A(1-φ_M)(1-φ_X) > 0` unconditionally.  Hence, given
continuity, an interior root exists as soon as `D(0) < 0`, and `D(0) < 0` is
exactly the **gate-dominance** condition

`|(∂φ/∂ν)(∂ν/∂τ_MEV)| > 1 - φ_X`   at `τ_MEV = 0`. -/
theorem Theorem35_root_iff_gate_dominates_at_zero
    (A : ℝ → ℝ) (phiM : ℝ) (phiXv dphidnu dnudtau : ℝ → ℝ)
    (hA : ∀ t, 0 < A t) (hM : phiM < 1) (hX : ∀ t, phiXv t < 1)
    (hcont : ContinuousOn
      (fun t => totalDeriv (A t) phiM t (phiXv t) (dphidnu t) (dnudtau t))
      (Set.Icc 0 1))
    (hdphi0 : 0 < dphidnu 0) (hdnu0 : dnudtau 0 < 0) :
    0 < totalDeriv (A 1) phiM 1 (phiXv 1) (dphidnu 1) (dnudtau 1) ∧
      (totalDeriv (A 0) phiM 0 (phiXv 0) (dphidnu 0) (dnudtau 0) < 0
        ↔ 1 - phiXv 0 < |dphidnu 0 * dnudtau 0|) ∧
      (1 - phiXv 0 < |dphidnu 0 * dnudtau 0| →
        ∃ t ∈ Set.Ioo (0 : ℝ) 1,
          totalDeriv (A t) phiM t (phiXv t) (dphidnu t) (dnudtau t) = 0) := by
  have habs : |dphidnu 0 * dnudtau 0| = -(dphidnu 0 * dnudtau 0) :=
    abs_of_neg (mul_neg_of_pos_of_neg hdphi0 hdnu0)
  have hpos1 : 0 < A 1 * (1 - phiM) := mul_pos (hA 1) (by linarith)
  have hpos0 : 0 < A 0 * (1 - phiM) := mul_pos (hA 0) (by linarith)
  have hD1 : 0 < totalDeriv (A 1) phiM 1 (phiXv 1) (dphidnu 1) (dnudtau 1) := by
    simp only [totalDeriv, pathDirect, pathGate]
    have : (0:ℝ) < A 1 * (1 - phiM) * (1 - phiXv 1) := mul_pos hpos1 (by linarith [hX 1])
    nlinarith
  have hiff : totalDeriv (A 0) phiM 0 (phiXv 0) (dphidnu 0) (dnudtau 0) < 0
      ↔ 1 - phiXv 0 < |dphidnu 0 * dnudtau 0| := by
    rw [habs]
    simp only [totalDeriv, pathDirect, pathGate]
    constructor
    · intro h; nlinarith
    · intro h; nlinarith
  exact ⟨hD1, hiff, fun h => Theorem35_interior_root.1 _ hcont (hiff.mpr h) hD1⟩

/-- The **responsive band** of the controller: the utilizations at which `DOC`
Definition 18's gate is still steep enough for (P-gate) to cancel (P-direct).
`W` is the log-budget of Theorem 36; the band is `|ν - β_R| < W/γ_R`, centred at
the gate midpoint `β_R` with half-width inversely proportional to the steepness
`γ_R`. -/
def responsiveBand (gammaR betaR W : ℝ) : Set ℝ := {nu | gammaR * |nu - betaR| < W}

/-- The band, written as an interval in `ν` around the gate midpoint `β_R`:
`ν ∈ (β_R - W/γ_R, β_R + W/γ_R)`. -/
lemma responsiveBand_eq_Ioo (gammaR betaR W : ℝ) (hgammaR : 0 < gammaR) :
    responsiveBand gammaR betaR W
      = Set.Ioo (betaR - W / gammaR) (betaR + W / gammaR) := by
  ext v
  simp only [responsiveBand, Set.mem_setOf_eq, Set.mem_Ioo]
  rw [← lt_div_iff₀' hgammaR, abs_lt]
  constructor
  · rintro ⟨h1, h2⟩; constructor <;> linarith
  · rintro ⟨h1, h2⟩; constructor <;> linarith

/-- The logistic bump is bounded by `exp(-|z|)`: `e^z/(1+e^z)² ≤ e^{-|z|}`.
This is what makes the gate's response die *exponentially* off its midpoint. -/
lemma logistic_bump_le (z : ℝ) :
    Real.exp z / (1 + Real.exp z) ^ 2 ≤ Real.exp (-|z|) := by
  have hE : (0:ℝ) < Real.exp z := Real.exp_pos z
  rw [div_le_iff₀ (by positivity)]
  rcases abs_cases z with ⟨h1, h2⟩ | ⟨h1, h2⟩
  · rw [h1, Real.exp_neg, inv_mul_eq_div, le_div_iff₀ hE]
    nlinarith [hE]
  · rw [h1]
    simp only [neg_neg]
    nlinarith [hE, mul_pos hE hE]

/-- Off the gate midpoint the gate derivative is exponentially small:
`∂φ/∂ν ≤ α_R γ_R (∑_j α_j) exp(-γ_R|ν - β_R|)`. -/
lemma dphidnuBoxed_le (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR nu : ℝ)
    (halphaR : 0 ≤ alphaR) (hgammaR : 0 ≤ gammaR) (halpha : ∀ j, 0 ≤ α j) :
    dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
      ≤ alphaR * gammaR * (∑ j ∈ Finset.range n, α j) *
          Real.exp (-(gammaR * |nu - betaR|)) := by
  have hS := volSurcharge_nonneg n γ β α σ halpha
  have hSle := volSurcharge_le n γ β α σ halpha
  have habs : |gammaR * (betaR - nu)| = gammaR * |nu - betaR| := by
    rw [abs_mul, abs_of_nonneg hgammaR, abs_sub_comm]
  have hbump := logistic_bump_le (gammaR * (betaR - nu))
  rw [habs] at hbump
  have hc : (0:ℝ) ≤ alphaR * gammaR := mul_nonneg halphaR hgammaR
  calc dphidnuBoxed n γ β α σ alphaR gammaR betaR nu
      ≤ alphaR * gammaR * volSurcharge n γ β α σ *
          Real.exp (-(gammaR * |nu - betaR|)) := by
        unfold dphidnuBoxed
        exact mul_le_mul_of_nonneg_left hbump (by positivity)
    _ ≤ alphaR * gammaR * (∑ j ∈ Finset.range n, α j) *
          Real.exp (-(gammaR * |nu - betaR|)) :=
        mul_le_mul_of_nonneg_right (mul_le_mul_of_nonneg_left hSle hc)
          (le_of_lt (Real.exp_pos _))

/-- **Theorem 36 (Non-existence off the responsive band) [M22].**

*Exact saturation.*  Where the gate is unresponsive — `α_R = 0`, or `γ_R = 0`,
or every `α_j = 0`; equivalently, by `dphidnuBoxed_eq_zero_iff`, wherever
`∂φ/∂ν ≡ 0` — (P-gate) vanishes identically, only the strictly positive
(P-direct) survives, `∂π̂^σ/∂τ_MEV > 0` throughout `[0,1]`, and **no interior
root exists**.  Note this is a degeneracy of the *parameters*: a responsive
sigmoid is strictly positive at every utilization (`dphidnuBoxed_pos`), so the
operative statement is the next one.

*The band.*  More sharply, the gate response is bounded by
`α_R γ_R (∑_j α_j) e^{-γ_R|ν-β_R|}` (`dphidnuBoxed_le`), so if the utilization
stays **off** the band `|ν - β_R| < W/γ_R` (`responsiveBand_eq_Ioo`) for every
admissible `τ`, with the log-budget `W` large enough that
`α_R γ_R (∑_j α_j) N e^{-W} < m` — where `m > 0` lower-bounds `1 - φ_X` and `N`
bounds `|∂ν/∂τ_MEV|` — then again `∂π̂^σ/∂τ_MEV > 0` throughout and no interior
root exists.

`{ν : γ_R|ν - β_R| < W}` is therefore the controller's **domain**: a domain
condition, not an implementation detail. -/
theorem Theorem36_no_interior_root_off_the_band
    (n : ℕ) (γ β α : ℕ → ℝ) (σ alphaR gammaR betaR : ℝ)
    (A : ℝ → ℝ) (phiM : ℝ) (phiXv nu dnudtau : ℝ → ℝ) (m N W : ℝ)
    (hA : ∀ t, 0 < A t) (hM : phiM < 1)
    (halphaR : 0 ≤ alphaR) (hgammaR : 0 ≤ gammaR) (halpha : ∀ j, 0 ≤ α j)
    (hm : 0 < m) (hmX : ∀ t, m ≤ 1 - phiXv t)
    (hN : ∀ t, |dnudtau t| ≤ N) :
    ((∀ v, dphidnuBoxed n γ β α σ alphaR gammaR betaR v = 0) →
        ∀ t ∈ Set.Icc (0 : ℝ) 1,
          0 < totalDeriv (A t) phiM t (phiXv t)
            (dphidnuBoxed n γ β α σ alphaR gammaR betaR (nu t)) (dnudtau t)) ∧
      (alphaR * gammaR * (∑ j ∈ Finset.range n, α j) * N * Real.exp (-W) < m →
        (∀ t ∈ Set.Icc (0 : ℝ) 1, nu t ∉ responsiveBand gammaR betaR W) →
        ∀ t ∈ Set.Icc (0 : ℝ) 1,
          0 < totalDeriv (A t) phiM t (phiXv t)
            (dphidnuBoxed n γ β α σ alphaR gammaR betaR (nu t)) (dnudtau t)) := by
  have hN0 : 0 ≤ N := le_trans (abs_nonneg _) (hN 0)
  constructor
  · intro hsat t ht
    have hApos : 0 < A t * (1 - phiM) := mul_pos (hA t) (by linarith)
    have hmt := hmX t
    rw [totalDeriv_eq_core]
    refine mul_pos hApos ?_
    simp only [focCore, hsat (nu t)]
    have : (0:ℝ) ≤ (1 - t) * (0 * dnudtau t) := by simp
    linarith
  · intro hbudget hoff t ht
    have hApos : 0 < A t * (1 - phiM) := mul_pos (hA t) (by linarith)
    have hmt := hmX t
    set g := dphidnuBoxed n γ β α σ alphaR gammaR betaR (nu t) with hgdef
    have hg0 : 0 ≤ g :=
      dphidnuBoxed_nonneg n γ β α σ alphaR gammaR betaR (nu t) halphaR hgammaR halpha
    have hband : W ≤ gammaR * |nu t - betaR| := by
      have hmem := hoff t ht
      simp only [responsiveBand, Set.mem_setOf_eq, not_lt] at hmem
      exact hmem
    have hexp : Real.exp (-(gammaR * |nu t - betaR|)) ≤ Real.exp (-W) :=
      Real.exp_le_exp.mpr (by linarith)
    have hgle : g ≤ alphaR * gammaR * (∑ j ∈ Finset.range n, α j) * Real.exp (-W) := by
      refine le_trans
        (dphidnuBoxed_le n γ β α σ alphaR gammaR betaR (nu t) halphaR hgammaR halpha) ?_
      have hc : (0:ℝ) ≤ alphaR * gammaR * (∑ j ∈ Finset.range n, α j) := by
        have : (0:ℝ) ≤ ∑ j ∈ Finset.range n, α j :=
          Finset.sum_nonneg (fun j _ => halpha j)
        positivity
      exact mul_le_mul_of_nonneg_left hexp hc
    have hgN : g * N < m := by nlinarith
    have hd : -N ≤ dnudtau t := (abs_le.mp (hN t)).1
    have ht1 : (1 - t) ≤ 1 := by linarith [ht.1]
    have ht0 : 0 ≤ 1 - t := by linarith [ht.2]
    rw [totalDeriv_eq_core]
    refine mul_pos hApos ?_
    simp only [focCore]
    have h1 : g * dnudtau t ≥ -(g * N) := by nlinarith
    have h2 : (1 - t) * (g * dnudtau t) ≥ -(g * N) := by
      rcases le_or_gt 0 (g * dnudtau t) with hx | hx
      · nlinarith
      · nlinarith
    linarith

/-! ## M23. Second-order condition -/

/-- **Proposition 15 (Second-order condition) [M23].**

*Under the exposure reading `𝓔 = (∂π̂^σ/∂τ_MEV)²` — Definition 33's functional:*
any FOC root is a **global minimiser** of `𝓔`; the first-order condition
`𝓔' = 0` holds there automatically, and the second-order condition is
`𝓔'' = 2(D')² ≥ 0`, **strict** iff `D'(τ*) ≠ 0`, i.e. iff the total derivative
crosses zero transversally.  So under this reading the SOC *is* settled, and all
it needs is transversality of the crossing.

*Under the level reading* — `τ*` as a stationary point of `π̂^σ` itself — the SOC
is **not settled** by the M20/M21 data; see
`Proposition15_level_reading_second_order_undetermined`. -/
theorem Proposition15_second_order_exposure
    (piHatOf D D' : ℝ → ℝ) (tstar c : ℝ)
    (hD : ∀ t, deriv piHatOf t = D t)
    (hroot : D tstar = 0)
    (hD' : ∀ t, HasDerivAt D (D' t) t)
    (hD'' : HasDerivAt D' c tstar) :
    IsMinOn (exposure piHatOf) Set.univ tstar ∧
      HasDerivAt (fun t => exposure piHatOf t) 0 tstar ∧
      HasDerivAt (fun t => 2 * D t * D' t) (2 * (D' tstar) ^ 2) tstar ∧
      (0 < 2 * (D' tstar) ^ 2 ↔ D' tstar ≠ 0) := by
  have hexp : (fun t => exposure piHatOf t) = fun t => (D t) ^ 2 := by
    funext t; simp [exposure, hD t]
  refine ⟨?_, ?_, ?_, ?_⟩
  · rw [isMinOn_iff]
    intro x _
    have h0 : exposure piHatOf tstar = 0 := by simp [exposure, hD tstar, hroot]
    rw [h0]
    simp only [exposure]
    positivity
  · rw [hexp]
    have h := (hD' tstar).pow 2
    convert h using 1
    rw [hroot]; ring
  · have h1 := ((hD' tstar).const_mul (2:ℝ)).mul hD''
    convert h1 using 1
    rw [hroot]; ring
  · constructor
    · intro h hz; rw [hz] at h; norm_num at h
    · intro h; positivity

/-- **Proposition 15, the unsettled half [M23].**  Under the *level* reading —
`τ*` as a stationary point of the realizable payoff `π̂^σ` — the sign of
`∂²π̂^σ/∂τ_MEV²` is **not determined** by the hypotheses of M20/M21.

Two plants of exactly the shape of Theorem 33 (`φ_M = 0`, identity outer chain,
so `A = 1`, with `h = φ_X ∘ ν` the gated taker leg along the fibre), both with
the M21 sign structure at the same interior root `τ* = 1/2` — `1 - φ_X = 1 > 0`
so (P-direct) `> 0`, `∂(φ_X∘ν)/∂τ = -2 < 0` so (P-gate) `= -1 < 0` — and both
with the composed fee guarded inside `[0,1)` on `[2/5, 3/5]`, have second
derivatives of **opposite sign** at `τ*`.  So the FOC root must **not** be
assumed to be the minimiser.

**The structure that would settle it** is single crossing from below of the
total derivative at the root, supplied as the hypothesis of
`Proposition15_single_crossing_gives_minimum`; nothing in this bundle proves
it. -/
theorem Proposition15_level_reading_second_order_undetermined :
    ∃ (h₁ h₂ D₁ D₂ : ℝ → ℝ) (c₁ c₂ : ℝ),
      (∀ t ∈ Set.Icc (2 / 5 : ℝ) (3 / 5),
          MevTaxControl.phiTotal 0 (h₁ t) t ∈ Set.Ico (0 : ℝ) 1) ∧
      (∀ t ∈ Set.Icc (2 / 5 : ℝ) (3 / 5),
          MevTaxControl.phiTotal 0 (h₂ t) t ∈ Set.Ico (0 : ℝ) 1) ∧
      h₁ (1 / 2) = 0 ∧ h₂ (1 / 2) = 0 ∧
      HasDerivAt h₁ (-2) (1 / 2) ∧ HasDerivAt h₂ (-2) (1 / 2) ∧
      (∀ t, HasDerivAt (fun s => MevTaxControl.phiTotal 0 (h₁ s) s) (D₁ t) t) ∧
      (∀ t, HasDerivAt (fun s => MevTaxControl.phiTotal 0 (h₂ s) s) (D₂ t) t) ∧
      D₁ (1 / 2) = 0 ∧ D₂ (1 / 2) = 0 ∧
      HasDerivAt D₁ c₁ (1 / 2) ∧ HasDerivAt D₂ c₂ (1 / 2) ∧ 0 < c₁ ∧ c₂ < 0 := by
  refine ⟨fun t => -2*t + 1, fun t => -20*t^2 + 18*t - 4,
    fun t => 4*t - 2, fun t => 60*t^2 - 76*t + 23, 4, -16, ?_, ?_,
    by norm_num, by norm_num, ?_, ?_, ?_, ?_, by norm_num, by norm_num, ?_, ?_,
    by norm_num, by norm_num⟩
  · intro t ht
    obtain ⟨ha, hb⟩ := ht
    rw [MevTaxControl.phiTotal_eq]
    constructor <;> simp <;> nlinarith [sq_nonneg (t - 1/2)]
  · intro t ht
    obtain ⟨ha, hb⟩ := ht
    rw [MevTaxControl.phiTotal_eq]
    constructor <;> simp <;>
      nlinarith [sq_nonneg (t - 1/2), mul_nonneg (sub_nonneg.2 ha) (sub_nonneg.2 hb),
        sq_nonneg (t - 2/5), sq_nonneg (3/5 - t)]
  · simpa using ((hasDerivAt_id (1/2 : ℝ)).const_mul (-2 : ℝ)).add_const 1
  · have h := hasDerivAt_cubic 0 (-20) 18 (-4) (1/2 : ℝ)
    have hfun : (fun t : ℝ => -20*t^2 + 18*t - 4)
        = fun s : ℝ => 0*s^3 + (-20)*s^2 + 18*s + (-4) := by funext s; ring
    rw [hfun]
    convert h using 1
    norm_num
  · intro t
    have h := hasDerivAt_cubic 0 2 (-2) 1 t
    have hfun : (fun s => MevTaxControl.phiTotal 0 (-2*s + 1) s)
        = fun s : ℝ => 0*s^3 + 2*s^2 + (-2)*s + 1 := by
      funext s; rw [MevTaxControl.phiTotal_eq]; ring
    rw [hfun]
    convert h using 1
    ring
  · intro t
    have h := hasDerivAt_cubic 20 (-38) 23 (-4) t
    have hfun : (fun s => MevTaxControl.phiTotal 0 (-20*s^2 + 18*s - 4) s)
        = fun s : ℝ => 20*s^3 + (-38)*s^2 + 23*s + (-4) := by
      funext s; rw [MevTaxControl.phiTotal_eq]; ring
    rw [hfun]
    convert h using 1
    ring
  · have h := hasDerivAt_cubic 0 0 4 (-2) (1/2 : ℝ)
    have hfun : (fun t : ℝ => 4*t - 2) = fun s : ℝ => 0*s^3 + 0*s^2 + 4*s + (-2) := by
      funext s; ring
    rw [hfun]
    convert h using 1
    norm_num
  · have h := hasDerivAt_cubic 0 60 (-76) 23 (1/2 : ℝ)
    have hfun : (fun t : ℝ => 60*t^2 - 76*t + 23)
        = fun s : ℝ => 0*s^3 + 60*s^2 + (-76)*s + 23 := by funext s; ring
    rw [hfun]
    convert h using 1
    norm_num

/-- **Proposition 15, the hypothesis that settles it [M23].**  If the total
derivative `D = ∂π̂^σ/∂τ_MEV` is strictly increasing on `(a,b)` — *single
crossing from below* — then a root `τ* ∈ (a,b)` of `D` is a **minimiser of
`π̂^σ` on `[a,b]`**: the payoff falls before `τ*` and rises after.  This
hypothesis is **not** implied by M20/M21 and is never discharged here. -/
theorem Proposition15_single_crossing_gives_minimum
    (piHatOf D : ℝ → ℝ) (a b tstar : ℝ)
    (hcont : ContinuousOn piHatOf (Set.Icc a b))
    (hderiv : ∀ t ∈ Set.Ioo a b, HasDerivAt piHatOf (D t) t)
    (hmono : StrictMonoOn D (Set.Ioo a b))
    (hmem : tstar ∈ Set.Ioo a b) (hroot : D tstar = 0) :
    IsMinOn piHatOf (Set.Icc a b) tstar := by
  have hanti : AntitoneOn piHatOf (Set.Icc a tstar) := by
    refine antitoneOn_of_deriv_nonpos (convex_Icc a tstar)
      (hcont.mono (Set.Icc_subset_Icc le_rfl (le_of_lt hmem.2))) ?_ ?_
    · intro x hx
      rw [interior_Icc] at hx
      exact ((hderiv x ⟨hx.1, lt_trans hx.2 hmem.2⟩).differentiableAt).differentiableWithinAt
    · intro x hx
      rw [interior_Icc] at hx
      have hxI : x ∈ Set.Ioo a b := ⟨hx.1, lt_trans hx.2 hmem.2⟩
      rw [(hderiv x hxI).deriv]
      have h := hmono hxI hmem hx.2
      rw [hroot] at h
      linarith
  have hmon : MonotoneOn piHatOf (Set.Icc tstar b) := by
    refine monotoneOn_of_deriv_nonneg (convex_Icc tstar b)
      (hcont.mono (Set.Icc_subset_Icc (le_of_lt hmem.1) le_rfl)) ?_ ?_
    · intro x hx
      rw [interior_Icc] at hx
      exact ((hderiv x ⟨lt_trans hmem.1 hx.1, hx.2⟩).differentiableAt).differentiableWithinAt
    · intro x hx
      rw [interior_Icc] at hx
      have hxI : x ∈ Set.Ioo a b := ⟨lt_trans hmem.1 hx.1, hx.2⟩
      rw [(hderiv x hxI).deriv]
      have h := hmono hmem hxI hx.1
      rw [hroot] at h
      linarith
  rw [isMinOn_iff]
  intro x hx
  rcases le_or_gt x tstar with h | h
  · exact hanti ⟨hx.1, h⟩ ⟨le_of_lt hmem.1, le_rfl⟩ h
  · exact hmon ⟨le_rfl, le_of_lt hmem.2⟩ ⟨le_of_lt h, hx.2⟩ (le_of_lt h)

/-! ## M24. Term-by-term audit of the source's boxed `τ*_MEV`, and the
corrected law -/

/-- The five admissible verdicts of the M24 audit. -/
inductive Verdict
  | survives
  | signCorrected
  | illPosed
  | missing
  | spurious
  deriving DecidableEq, Repr

/-- The factors of the boxed law at `SRC:207-234 @ 78381d4`, together with the
factors the corrected FOC requires and the box omits. -/
inductive BoxFactor
  | leadingOne
  | normalizer
  | ladderBracket
  | feeJacobianBracket
  | dphidnu
  | dnudtau
  | directMonoidPath
  | monoidJacobian
  | implicitSelfReference
  deriving DecidableEq, Repr

/-- **Proposition 16, the verdict table [M24].**  One verdict per factor of the
source's box, plus the factors the corrected FOC requires and the box omits.

| factor | verdict |
|---|---|
| leading `1 -` | SURVIVES |
| `1/ΔQ_v^⋆` | SPURIOUS |
| `[∑_{i_K} π^l ∂L(i_K)/∂π^φ]` | SPURIOUS |
| `[ΔQ_M/(1-φ_X) + p ΔQ_X/(1-φ_M)]` | ILL-POSED |
| `∂φ/∂ν` | SURVIVES |
| `∂ν/∂τ_MEV` | SIGN CORRECTED |
| `(1-φ_M)(1-φ_X)` — the direct monoid path | MISSING |
| `(1-φ_M)(1-τ_MEV)` — the monoid Jacobian on the gate path | MISSING |
| self-reference of `τ*_MEV` on the right | MISSING |

Reading of the two `SURVIVES` verdicts: the leading `1 -` survives *as the shape
of the corrected law* (`τ*_MEV = 1 - …`), though for a different reason; and
`∂φ/∂ν` survives with the same form and sign, relocated into the **denominator**.
Reading of the `SPURIOUS` verdicts: `1/ΔQ_v^⋆` and the ladder bracket are
strictly positive common factors of the total derivative, so they cancel out of
`= 0` and appear nowhere in the corrected law — the ladder bracket remains in the
*derivative*, but not in the *law*. -/
def auditTable : BoxFactor → Verdict
  | .leadingOne => .survives
  | .normalizer => .spurious
  | .ladderBracket => .spurious
  | .feeJacobianBracket => .illPosed
  | .dphidnu => .survives
  | .dnudtau => .signCorrected
  | .directMonoidPath => .missing
  | .monoidJacobian => .missing
  | .implicitSelfReference => .missing

/-- **Proposition 16 (Audit) [M24], the justifications.**

* `normalizer` — SPURIOUS: the FOC is scale-invariant, so multiplying by
  `1/ΔQ_v^⋆` changes nothing; and the corrected law
  (`Proposition16_corrected_law`) contains no `ΔQ_v^⋆`.  Once the right-hand
  side is `0` rather than `ΔQ_v^⋆`, the normalizer has nothing to normalize.
* `ladderBracket` / `feeJacobianBracket` — they are positive common factors and
  cancel out of `= 0`: any `S, B > 0` scale the FOC away.  The ladder bracket is
  strictly positive under (H1) with a nonnegative, not-identically-zero ladder
  payoff (`MevTaxControl.M18_axis_error_refuted`), so its verdict is SPURIOUS;
  the fee-Jacobian bracket has in addition **no section-independent value**
  (`MevTaxControl.Theorem30_composed_fee_submersion_section_sum_ill_posed`), so
  its verdict is the stronger ILL-POSED.
* `directMonoidPath` / `monoidJacobian` — MISSING: the box's product differs
  from the total derivative by exactly (P-direct)
  (`Theorem33_five_factor_product_is_one_summand`).
* `dnudtau` — SIGN CORRECTED: the source imports
  `Ḡ_(ν,λ_MEV) = ∂ν/∂λ_MEV > 0` and uses it where `∂ν/∂τ_MEV` is required; by
  `MevTaxControl.Theorem32_hazard_strictAntiOn_tau` with (H2)
  (`MevTaxControl.tau_to_nu_strictAntiOn_under_H2`) the correct sign is `≤ 0`,
  and strictly `< 0` under the extra typed hypothesis of Theorem 34. -/
theorem Proposition16_audit_justification
    (A phiM tauMEV phiXv dphidnu dnudtau dQvStar : ℝ)
    (hA : 0 < A) (hM : phiM < 1) (hdQv : dQvStar ≠ 0) :
    ((totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0
        ↔ (1 / dQvStar) * totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0)) ∧
      (∀ S B : ℝ, 0 < S → 0 < B →
        (S * B * totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0
          ↔ focCore tauMEV phiXv dphidnu dnudtau = 0)) ∧
      (totalDeriv A phiM tauMEV phiXv dphidnu dnudtau
        - fiveFactorProduct A ((1 - phiM) * (1 - tauMEV) * dphidnu) dnudtau
          = pathDirect A phiM phiXv) := by
  have hAM : A * (1 - phiM) ≠ 0 := ne_of_gt (mul_pos hA (by linarith))
  refine ⟨?_, ?_, ?_⟩
  · rw [mul_left_eq_zero_iff' _ _ (by simpa using one_div_ne_zero hdQv)]
  · intro S B hS hB
    rw [mul_assoc, mul_left_eq_zero_iff' _ _ (ne_of_gt hS),
      mul_left_eq_zero_iff' _ _ (ne_of_gt hB), totalDeriv_eq_core,
      mul_left_eq_zero_iff' _ _ hAM]
  · simp only [totalDeriv, pathDirect, pathGate, fiveFactorProduct]; ring

/-- **Proposition 16, the corrected law [M24].**  From the FOC of M19, with
`A(1-φ_M) ≠ 0` and a responsive gate `(∂φ/∂ν)(∂ν/∂τ_MEV) ≠ 0`:

`∂π̂^σ/∂τ_MEV = 0  ⟺  τ*_MEV = 1 + (1 - φ_X)/((∂φ/∂ν)(∂ν/∂τ_MEV))`,

equivalently, under the M21 signs (`∂φ/∂ν > 0`, `∂ν/∂τ_MEV < 0`),

`τ*_MEV = 1 - (1 - φ_X)/|(∂φ/∂ν)(∂ν/∂τ_MEV)|`.

So the leading `1 -` **survives**, `1/ΔQ_v^⋆` and both brackets are **gone**,
`∂φ/∂ν` and `∂ν/∂τ_MEV` **survive in the denominator**, and the numerator
`1 - φ_X` — the direct monoid path — is **new**.

**This is an implicit equation, not a closed form:** `φ_X`, `∂φ/∂ν` and
`∂ν/∂τ_MEV` are all evaluated at `ν(τ*_MEV)`.  It is closed exactly when they do
not depend on `τ_MEV`; existence and uniqueness in the interior are
`Theorem35_interior_root` and `Theorem35_root_iff_gate_dominates_at_zero`, and
the domain is `Theorem36_no_interior_root_off_the_band`'s responsive band.

**Domain (admissibility).**  `τ*_MEV < 1` always (the numerator `1 - φ_X > 0`),
and `τ*_MEV > 0` **iff** the gate dominates,
`1 - φ_X < |(∂φ/∂ν)(∂ν/∂τ_MEV)|` — the same condition as
`Theorem35_root_iff_gate_dominates_at_zero`.  Outside it the constrained
optimum sits at the boundary `τ_MEV = 0`, not at an interior stationary
point. -/
theorem Proposition16_corrected_law
    (A phiM tauMEV phiXv dphidnu dnudtau : ℝ)
    (hA : A ≠ 0) (hM : phiM ≠ 1) (hg : dphidnu * dnudtau ≠ 0) :
    (totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0
        ↔ tauMEV = 1 + (1 - phiXv) / (dphidnu * dnudtau)) ∧
      (0 < dphidnu → dnudtau < 0 → phiXv < 1 →
        ((totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0
            ↔ tauMEV = 1 - (1 - phiXv) / |dphidnu * dnudtau|) ∧
          (tauMEV = 1 + (1 - phiXv) / (dphidnu * dnudtau) → tauMEV < 1) ∧
          (tauMEV = 1 + (1 - phiXv) / (dphidnu * dnudtau) →
            (0 < tauMEV ↔ 1 - phiXv < |dphidnu * dnudtau|)))) := by
  have hmain : totalDeriv A phiM tauMEV phiXv dphidnu dnudtau = 0
      ↔ tauMEV = 1 + (1 - phiXv) / (dphidnu * dnudtau) := by
    rw [totalDeriv_eq_zero_iff A phiM tauMEV phiXv dphidnu dnudtau hA hM]
    simp only [focCore]
    exact focCore_eq_zero_iff tauMEV phiXv (dphidnu * dnudtau) hg
  refine ⟨hmain, ?_⟩
  intro hdphi hdnu hX
  have hgneg : dphidnu * dnudtau < 0 := mul_neg_of_pos_of_neg hdphi hdnu
  have hgpos : (0:ℝ) < -(dphidnu * dnudtau) := by linarith
  have hkey : 1 + (1 - phiXv) / (dphidnu * dnudtau)
      = 1 - (1 - phiXv) / (-(dphidnu * dnudtau)) := by rw [div_neg]; ring
  have heq : 1 + (1 - phiXv) / (dphidnu * dnudtau)
      = 1 - (1 - phiXv) / |dphidnu * dnudtau| := by
    rw [abs_of_neg hgneg]; exact hkey
  refine ⟨by rw [hmain, heq], ?_, ?_⟩
  · intro h
    rw [h]
    have : (1 - phiXv) / (dphidnu * dnudtau) < 0 :=
      div_neg_of_pos_of_neg (by linarith) hgneg
    linarith
  · intro h
    rw [h, abs_of_neg hgneg, hkey]
    constructor
    · intro hpos
      exact (div_lt_one hgpos).mp (by linarith)
    · intro hlt
      have := (div_lt_one hgpos).mpr hlt
      linarith

/-- **Proposition 16, the closed-form case and the branch structure [M24].**

1. *Closed form.*  If the gate data is constant in the tax (`φ_X`, `∂φ/∂ν`,
   `∂ν/∂τ_MEV` independent of `τ_MEV`), the corrected law is a genuine closed
   form with a unique solution.  Otherwise it is a fixed-point equation and —
   exactly as in bundle 1's `MevTaxControl.Proposition13_implicit_not_closed` —
   equations of that shape may have no solution or several; the honest statement
   is the implicit one together with the existence and uniqueness conditions of
   `Theorem35_interior_root`.

2. *ITM/OTM branch.*  The `(·)^+` kink at the strike is **branched, never
   differentiated through**: it sits in the *constraint*, not in the FOC.  On
   the OTM branch (`σ² ≤ σ_K²`) the contractual payoff is `0`, so feasibility
   forces `π̂^σ(τ) = 0`; on the ITM branch (`σ_K² < σ²`) feasibility forces
   `π̂^σ(τ) = ΔQ_v^⋆(σ² - σ_K²)`.  The FOC root does not depend on the branch at
   all — it contains neither `σ_K²` nor `ΔQ_v^⋆` — which is precisely why FOC and
   feasibility are independent conditions (M19). -/
theorem Proposition16_closed_form_and_branch_structure :
    (∀ (phiXv dphidnu dnudtau : ℝ), dphidnu * dnudtau ≠ 0 →
        ∃! t : ℝ, t = 1 + (1 - phiXv) / (dphidnu * dnudtau)) ∧
      (∀ (dQvStar sigma2 sigma2K : ℝ), sigma2 ≤ sigma2K →
        Panoptic.volOptionPayoff dQvStar sigma2 sigma2K = 0) ∧
      (∀ (dQvStar sigma2 sigma2K : ℝ), sigma2K < sigma2 →
        Panoptic.volOptionPayoff dQvStar sigma2 sigma2K
          = dQvStar * (sigma2 - sigma2K)) := by
  refine ⟨?_, ?_, ?_⟩
  · intro phiXv dphidnu dnudtau _
    exact ⟨1 + (1 - phiXv) / (dphidnu * dnudtau), rfl, fun y hy => hy⟩
  · intro dQvStar sigma2 sigma2K h
    unfold Panoptic.volOptionPayoff
    rw [max_eq_left (by linarith)]
    ring
  · intro dQvStar sigma2 sigma2K h
    unfold Panoptic.volOptionPayoff
    rw [max_eq_right (by linarith)]

end MevTaxProgram
