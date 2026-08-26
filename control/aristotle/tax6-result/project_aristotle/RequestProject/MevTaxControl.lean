import Mathlib
import RequestProject.TauMevAlgebra

open scoped BigOperators

set_option maxHeartbeats 1000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# MEV-tax control blocks (M11–M18)

This module formalizes blocks **M11–M18** of `TAX_ADDENDUM.md`, i.e. the
control-theoretic reading of the derivation pinned at
`SRC_VOLATILITY_INSTRUMENTS_MEV.md` (`78381d4`).

Notation is transcribed, never reassigned:

* `Lsigma` is the **volatility-axis** liquidity `L_σ ≡ ΔQ_v^⋆` (raw liquidity
  units, stored); the plain price-axis pool liquidity `L`, `L̄` is a *different*
  asset and is written separately wherever it occurs;
* `piPhi` is `π^φ` (fee income) and `piLVR` is `π^LVR`; the fourth state slot of
  Definition 32 is written out in full as `π^φ - π^LVR` — no shorthand is
  introduced for it;
* `π^σ` is the contractual variance-swap payoff and `π̂^σ` the liquidity-kernel
  payoff.

Guards observed throughout:

* `MevOptimization.ptrade` is the Möbius kernel `σ/(σ + φ√(2/Δt))`; every
  statement about a fee limit keeps the fee nonnegative, away from the pole;
* the three kinks — `(·)^+` at the strike, `|·|` in `e^σ`, and the funded cap —
  are **branched**, never differentiated through;
* sign/ordering claims are stated with `StrictMono`/`StrictAntiOn`/`IsMinOn`
  rather than by building a derivative layer, except where the source's own
  statement *is* a derivative identity (M12, M13, M14).

Two blocks refute the source: the corollary of Theorem 29 (M12) and
Proposition 12 (M14).  Both are delivered with explicit witnesses.

The behavioural responses (H1), (H2) of M18 are **hypotheses**, never proved:
they are carried as explicit typed arguments.
-/

namespace MevTaxControl

/-! ## M11. Definition 32 — the event-time plant -/

/-- **Definition 32 (Event-time plant) [M11].**  One `EventPlant` is one event
(`t → t+1` is one swap).  The fields transcribe the source's vectors:

* state `x = [φ, ν, π^φ, π^φ - π^LVR]` — fields `φ`, `ν`, `piPhi`, `piLVR`
  (the fourth slot is `piPhi - piLVR`, written out in full: `EventPlant.state`);
* exogenous input `u_ex = [ΔQ_X, ΔQ_M, σ²(i(t))]` — `dQX`, `dQM`, `sigma2`;
* endogenous input `u_en = [τ_MEV, φ_M, φ_X]` — `tauMEV`, `φM`, `φX`;
* output `y = [π^σ, π̂^σ]` — `EventPlant.piSigma`, `EventPlant.piSigmaHat`;
* `Θ_σ = [σ_K², #_σ, s_υ, ΔQ_v^⋆]` — `sigma2K`, `countSigma`, `sUpsilon`,
  `dQvStar`;
* `Θ_φ = {γ, φ̄, β, α}` — `n`, `γ`, `β`, `α`, `φbar`, `u`, carried so that the
  standing assumption "(β_j, γ_j) fixed for all t" can be *stated*;
* `Lsigma i_K` is the **volatility-axis** ladder `L_σ(i_K)`, `sigmaOf i_K` is
  `σ(i_K; Θ_σ)` and `piEll` is the leg payoff `π^l`. -/
structure EventPlant where
  /-- state slot 1: the composed trader-paid fee `φ`. -/
  φ : ℝ
  /-- state slot 2: utilization `ν`. -/
  ν : ℝ
  /-- state slot 3: the fee-income payoff `π^φ`. -/
  piPhi : ℝ
  /-- `π^LVR`; state slot 4 is `π^φ - π^LVR`, written out in full. -/
  piLVR : ℝ
  /-- exogenous input `ΔQ_X`. -/
  dQX : ℝ
  /-- exogenous input `ΔQ_M`. -/
  dQM : ℝ
  /-- exogenous input `σ²(i(t))`. -/
  sigma2 : ℝ
  /-- endogenous input `τ_MEV`. -/
  tauMEV : ℝ
  /-- endogenous input `φ_M`. -/
  φM : ℝ
  /-- endogenous input `φ_X`. -/
  φX : ℝ
  /-- `Θ_σ` slot: the strike `σ_K²`. -/
  sigma2K : ℝ
  /-- `Θ_σ` slot: the ladder length `#_σ`. -/
  countSigma : ℕ
  /-- `Θ_σ` slot: the skew `s_υ`. -/
  sUpsilon : ℝ
  /-- `Θ_σ` slot: the stored volatility-axis size `ΔQ_v^⋆`. -/
  dQvStar : ℝ
  /-- `Θ_φ`: number of sigmoids. -/
  n : ℕ
  /-- `Θ_φ`: sigmoid slopes `γ_j`. -/
  γ : ℕ → ℝ
  /-- `Θ_φ`: sigmoid centers `β_j`. -/
  β : ℕ → ℝ
  /-- `Θ_φ`: sigmoid amplitudes `α_j`. -/
  α : ℕ → ℝ
  /-- `Θ_φ`: fee floor `φ̄`. -/
  φbar : ℝ
  /-- `Θ_φ`: level `u`. -/
  u : ℝ
  /-- volatility-axis ladder liquidity `L_σ(i_K)` (raw liquidity units). -/
  Lsigma : ℕ → ℝ
  /-- the ladder volatilities `σ(i_K; Θ_σ)`. -/
  sigmaOf : ℕ → ℝ
  /-- the leg payoff `π^l`. -/
  piEll : ℝ → ℝ

namespace EventPlant

variable (P : EventPlant)

/-- The state vector `x = [φ, ν, π^φ, π^φ - π^LVR]` of Definition 32. -/
def state : ℝ × ℝ × ℝ × ℝ := (P.φ, P.ν, P.piPhi, P.piPhi - P.piLVR)

/-- The exogenous input `u_ex = [ΔQ_X, ΔQ_M, σ²(i(t))]`. -/
def uEx : ℝ × ℝ × ℝ := (P.dQX, P.dQM, P.sigma2)

/-- The endogenous input `u_en = [τ_MEV, φ_M, φ_X]`. -/
def uEn : ℝ × ℝ × ℝ := (P.tauMEV, P.φM, P.φX)

/-- `Θ_σ = [σ_K², #_σ, s_υ, ΔQ_v^⋆]`. -/
def ThetaSigma : ℝ × ℕ × ℝ × ℝ := (P.sigma2K, P.countSigma, P.sUpsilon, P.dQvStar)

/-- The contractual variance-swap payoff
`π^σ = ΔQ_v^⋆ (σ²(i(t)) - σ_K²)^+`, reusing the existing carrier
`Panoptic.volOptionPayoff`. -/
noncomputable def piSigma : ℝ := Panoptic.volOptionPayoff P.dQvStar P.sigma2 P.sigma2K

/-- The realized liquidity-kernel payoff
`π̂^σ = ∑_{i_K} L_σ(i_K) π^l(σ(i_K; Θ_σ))` — the sum is on the
**volatility axis**. -/
noncomputable def piSigmaHat : ℝ :=
  ∑ iK ∈ Finset.range P.countSigma, P.Lsigma iK * P.piEll (P.sigmaOf iK)

/-- The output vector `y = [π^σ, π̂^σ]`. -/
noncomputable def output : ℝ × ℝ := (P.piSigma, P.piSigmaHat)

/-- The trader-paid composed fee of Rule 12,
`φ_total ← φ_M ⊗_φ φ_X ⊗_φ τ_MEV`. -/
def phiTotal : ℝ :=
  VolInstrument.probOr (VolInstrument.probOr P.φM P.φX) P.tauMEV

/-- The signed replication residual `π^σ - π̂^σ` (Proposition 14's object). -/
noncomputable def signedResidual : ℝ := P.piSigma - P.piSigmaHat

/-- The feedback error `e^σ = |π^σ - π̂^σ|` (`SRC:28 @ 78381d4`). -/
noncomputable def errorSigma : ℝ := |P.piSigma - P.piSigmaHat|

/-- ITM branch of the strike kink: `σ_K² < σ²(i(t))` ⟹ the `(·)^+` is
inactive. -/
lemma piSigma_itm (h : P.sigma2K < P.sigma2) :
    P.piSigma = P.dQvStar * (P.sigma2 - P.sigma2K) := by
  unfold piSigma Panoptic.volOptionPayoff
  rw [max_eq_right (by linarith)]

/-- OTM branch of the strike kink: `σ²(i(t)) ≤ σ_K²` ⟹ `π^σ = 0`. -/
lemma piSigma_otm (h : P.sigma2 ≤ P.sigma2K) : P.piSigma = 0 := by
  unfold piSigma Panoptic.volOptionPayoff
  rw [max_eq_left (by linarith)]
  ring

end EventPlant

/-- The standing assumptions of Definition 32, **declared and never derived**:
`φ_M ≡ φ̄_M` for all `t`; `(β_j, γ_j)` fixed for all `t`; and
`φ_X(t) = Φ(Θ_φ; σ²(i(t)))`.  No theorem in the tree licenses freezing
`(β_j, γ_j)` — `MevOptimization.mevMulti_mono_beta` proves the opposite
direction for `β` — so these are carried as hypotheses. -/
structure StandingAssumptions (P : ℕ → EventPlant) (phiBarM : ℝ) (Phi : ℝ → ℝ) : Prop where
  /-- `∀ t, φ_M(t) = φ̄_M`. -/
  fee_money_leg_constant : ∀ t, (P t).φM = phiBarM
  /-- `(β_j)` frozen along the event path. -/
  centers_frozen : ∀ t, (P t).β = (P 0).β
  /-- `(γ_j)` frozen along the event path. -/
  slopes_frozen : ∀ t, (P t).γ = (P 0).γ
  /-- `φ_X(t) = Φ(Θ_φ; σ²(i(t)))`. -/
  fee_asset_leg_schedule : ∀ t, (P t).φX = Phi ((P t).sigma2)

/-! ## M12. Theorem 29 — the direct monoid path -/

/-- Rule 12's composed fee `φ_M ⊗_φ φ_X ⊗_φ τ_MEV` as a function of its three
arguments. -/
def phiTotal (φM φX tauMEV : ℝ) : ℝ :=
  VolInstrument.probOr (VolInstrument.probOr φM φX) tauMEV

lemma phiTotal_eq (φM φX tauMEV : ℝ) :
    phiTotal φM φX tauMEV = 1 - (1 - φM) * (1 - φX) * (1 - tauMEV) := by
  unfold phiTotal VolInstrument.probOr
  ring

lemma hasDerivAt_phiTotal_tau (φM φX tauMEV : ℝ) :
    HasDerivAt (fun t => phiTotal φM φX t) ((1 - φM) * (1 - φX)) tauMEV := by
  have h : (fun t => phiTotal φM φX t)
      = fun t => 1 - (1 - φM) * (1 - φX) * (1 - t) := by
    funext t; exact phiTotal_eq φM φX t
  rw [h]
  have h1 : HasDerivAt (fun t : ℝ => 1 - t) (-1) tauMEV := by
    simpa using (hasDerivAt_id tauMEV).const_sub 1
  have h2 := (h1.const_mul ((1 - φM) * (1 - φX))).const_sub 1
  simpa using h2

/-- **Theorem 29 (The monoid path is direct) [M12].**  Under Rule 12's
`φ_total = φ_M ⊗_φ φ_X ⊗_φ τ_MEV`, holding `φ_M` and `φ_X` fixed,

`∂φ_total/∂τ_MEV = (1 - φ_M)(1 - φ_X) > 0`   (`φ_M, φ_X < 1`),

and the map `τ_MEV ↦ φ_total` is strictly increasing.  Nothing in this channel
mentions `ν`: it is a path from `τ_MEV` to `φ_total` that does not factor
through the utilization. -/
theorem Theorem29_monoid_path_is_direct (φM φX tauMEV : ℝ) (hM : φM < 1) (hX : φX < 1) :
    HasDerivAt (fun t => phiTotal φM φX t) ((1 - φM) * (1 - φX)) tauMEV ∧
      deriv (fun t => phiTotal φM φX t) tauMEV = (1 - φM) * (1 - φX) ∧
      0 < (1 - φM) * (1 - φX) ∧
      StrictMono (fun t => phiTotal φM φX t) := by
  refine ⟨hasDerivAt_phiTotal_tau φM φX tauMEV,
    (hasDerivAt_phiTotal_tau φM φX tauMEV).deriv,
    mul_pos (by linarith) (by linarith), ?_⟩
  intro s t hst
  simp only [phiTotal_eq]
  have : 0 < (1 - φM) * (1 - φX) := mul_pos (by linarith) (by linarith)
  nlinarith

/-- **Corollary of Theorem 29 (the five-factor product is not the total
derivative) [M12].**  The source's boxed channel

`∂π̂^σ/∂τ = (∂π̂^σ/∂L)(∂L/∂π^φ)(∂π^φ/∂φ)(∂φ/∂ν)(∂ν/∂τ)`

asserts that `τ_MEV` reaches the output through **no other path**.  Rule 12's
monoid puts `τ_MEV` directly in the composed fee, so with two forward paths the
total derivative is the *sum* over paths and the boxed product is at most the
`ν`-mediated summand.  The universally quantified identity is therefore FALSE.

Witness (all five outer factors are the identity, the utilization does not
respond): `π̂^σ ∘ L ∘ π^φ = id`, `φ_X = id`, `ν ≡ 0`, `φ_M = 0`, `τ_MEV = 0`.
There the total derivative is `1` while the five-factor product is `0`. -/
theorem Corollary29_five_factor_product_not_total_derivative :
    ¬ (∀ (Fhat Lof piPhiOf phiXOf nuOf : ℝ → ℝ) (φM tauMEV : ℝ),
        Differentiable ℝ Fhat → Differentiable ℝ Lof → Differentiable ℝ piPhiOf →
        Differentiable ℝ phiXOf → Differentiable ℝ nuOf →
        deriv (fun t => Fhat (Lof (piPhiOf
              (VolInstrument.probOr (VolInstrument.probOr φM (phiXOf (nuOf t))) t)))) tauMEV
          = deriv Fhat (Lof (piPhiOf (VolInstrument.probOr
                (VolInstrument.probOr φM (phiXOf (nuOf tauMEV))) tauMEV)))
            * deriv Lof (piPhiOf (VolInstrument.probOr
                (VolInstrument.probOr φM (phiXOf (nuOf tauMEV))) tauMEV))
            * deriv piPhiOf (VolInstrument.probOr
                (VolInstrument.probOr φM (phiXOf (nuOf tauMEV))) tauMEV)
            * deriv (fun v => VolInstrument.probOr
                (VolInstrument.probOr φM (phiXOf v)) tauMEV) (nuOf tauMEV)
            * deriv nuOf tauMEV) := by
  intro h
  have hid : Differentiable ℝ (fun x : ℝ => x) := differentiable_id
  have hzero : Differentiable ℝ (fun _ : ℝ => (0 : ℝ)) := differentiable_const 0
  have hspec := h (fun x => x) (fun x => x) (fun x => x) (fun x => x) (fun _ => 0) 0 0
    hid hid hid hid hzero
  have hlhs : deriv (fun t : ℝ =>
      VolInstrument.probOr (VolInstrument.probOr 0 ((0 : ℝ))) t) 0 = 1 := by
    have : (fun t : ℝ => VolInstrument.probOr (VolInstrument.probOr 0 ((0 : ℝ))) t)
        = fun t : ℝ => t := by
      funext t; simp [VolInstrument.probOr]
    rw [this]
    simp
  simp only [] at hspec
  rw [hlhs] at hspec
  simp at hspec

/-- **M12, second question.**  The source boxes its objective as the partial
`∂π̂^σ/∂τ_MEV |_{λ_MEV}`, conditioned on `λ_MEV`, while the last factor of its
chain is `∂ν/∂τ_MEV`.  If `ν` reaches `τ_MEV` only through `λ_MEV`, the
conditioning sets that factor to zero and the whole product vanishes — while
the unrestricted total derivative of the composed fee channel is
`(1-φ_M)(1-φ_X)` times the outer derivative, which is nonzero.  So the
conditioned partial and the unrestricted total derivative cannot both satisfy
the boxed identity. -/
theorem M12_conditioned_partial_and_total_derivative_incompatible
    (Fhat : ℝ → ℝ) (φM φX tauMEV c dphidnu : ℝ) (hM : φM < 1) (hX : φX < 1)
    (hF : HasDerivAt Fhat c (phiTotal φM φX tauMEV)) (hc : c ≠ 0)
    (nuOf : ℝ → ℝ) (hnu : HasDerivAt nuOf 0 tauMEV) :
    deriv (fun t => Fhat (phiTotal φM φX t)) tauMEV
      ≠ c * dphidnu * deriv nuOf tauMEV := by
  have hcomp : HasDerivAt (fun t => Fhat (phiTotal φM φX t))
      (c * ((1 - φM) * (1 - φX))) tauMEV :=
    hF.comp tauMEV (hasDerivAt_phiTotal_tau φM φX tauMEV)
  rw [hcomp.deriv, hnu.deriv]
  have hpos : 0 < (1 - φM) * (1 - φX) := mul_pos (by linarith) (by linarith)
  simp only [mul_zero]
  exact mul_ne_zero hc (ne_of_gt hpos)

/-! ## M13. Theorem 30 — the composed fee is a submersion -/

/-- The composed-fee map `(φ_M, φ_X, τ_MEV) ↦ φ_total` as a map `ℝ³ → ℝ`. -/
def phiTotalMap (q : ℝ × ℝ × ℝ) : ℝ := phiTotal q.1 q.2.1 q.2.2

/-- The differential of the composed-fee map at a point, as a continuous linear
functional on `ℝ³`. -/
noncomputable def phiTotalFDeriv (φM φX tauMEV : ℝ) : (ℝ × ℝ × ℝ) →L[ℝ] ℝ :=
  ((1 - φX) * (1 - tauMEV)) • (ContinuousLinearMap.fst ℝ ℝ (ℝ × ℝ)) +
    (((1 - φM) * (1 - tauMEV)) •
        ((ContinuousLinearMap.fst ℝ ℝ ℝ).comp (ContinuousLinearMap.snd ℝ ℝ (ℝ × ℝ))) +
      ((1 - φM) * (1 - φX)) •
        ((ContinuousLinearMap.snd ℝ ℝ ℝ).comp (ContinuousLinearMap.snd ℝ ℝ (ℝ × ℝ))))

lemma phiTotalFDeriv_apply (φM φX tauMEV : ℝ) (q : ℝ × ℝ × ℝ) :
    phiTotalFDeriv φM φX tauMEV q =
      (1 - φX) * (1 - tauMEV) * q.1 + (1 - φM) * (1 - tauMEV) * q.2.1
        + (1 - φM) * (1 - φX) * q.2.2 := by
  simp only [phiTotalFDeriv, ContinuousLinearMap.add_apply, ContinuousLinearMap.smul_apply,
    ContinuousLinearMap.coe_comp', Function.comp_apply, ContinuousLinearMap.coe_fst',
    ContinuousLinearMap.coe_snd', smul_eq_mul]
  ring

lemma hasFDerivAt_phiTotalMap (φM φX tauMEV : ℝ) :
    HasFDerivAt phiTotalMap (phiTotalFDeriv φM φX tauMEV) (φM, φX, tauMEV) := by
  have h1 : HasFDerivAt (fun q : ℝ × ℝ × ℝ => 1 - q.1)
      (-(ContinuousLinearMap.fst ℝ ℝ (ℝ × ℝ))) (φM, φX, tauMEV) := by
    simpa using (hasFDerivAt_fst (p := ((φM, (φX, tauMEV)) : ℝ × ℝ × ℝ))).const_sub 1
  have h2 : HasFDerivAt (fun q : ℝ × ℝ × ℝ => 1 - q.2.1)
      (-((ContinuousLinearMap.fst ℝ ℝ ℝ).comp
          (ContinuousLinearMap.snd ℝ ℝ (ℝ × ℝ)))) (φM, φX, tauMEV) := by
    have hs : HasFDerivAt (fun q : ℝ × ℝ × ℝ => q.2.1)
        ((ContinuousLinearMap.fst ℝ ℝ ℝ).comp
          (ContinuousLinearMap.snd ℝ ℝ (ℝ × ℝ))) (φM, φX, tauMEV) :=
      (hasFDerivAt_fst (p := ((φX, tauMEV) : ℝ × ℝ))).comp _
        (hasFDerivAt_snd (p := ((φM, (φX, tauMEV)) : ℝ × ℝ × ℝ)))
    simpa using hs.const_sub 1
  have h3 : HasFDerivAt (fun q : ℝ × ℝ × ℝ => 1 - q.2.2)
      (-((ContinuousLinearMap.snd ℝ ℝ ℝ).comp
          (ContinuousLinearMap.snd ℝ ℝ (ℝ × ℝ)))) (φM, φX, tauMEV) := by
    have hs : HasFDerivAt (fun q : ℝ × ℝ × ℝ => q.2.2)
        ((ContinuousLinearMap.snd ℝ ℝ ℝ).comp
          (ContinuousLinearMap.snd ℝ ℝ (ℝ × ℝ))) (φM, φX, tauMEV) :=
      (hasFDerivAt_snd (p := ((φX, tauMEV) : ℝ × ℝ))).comp _
        (hasFDerivAt_snd (p := ((φM, (φX, tauMEV)) : ℝ × ℝ × ℝ)))
    simpa using hs.const_sub 1
  have hmul := ((h1.mul h2).mul h3).const_sub 1
  have hfun : phiTotalMap
      = fun q : ℝ × ℝ × ℝ => 1 - (1 - q.1) * (1 - q.2.1) * (1 - q.2.2) := by
    funext q
    exact phiTotal_eq q.1 q.2.1 q.2.2
  rw [hfun]
  refine hmul.congr_fderiv ?_
  refine ContinuousLinearMap.ext fun q => ?_
  simp only [ContinuousLinearMap.neg_apply, ContinuousLinearMap.add_apply,
    ContinuousLinearMap.smul_apply, ContinuousLinearMap.coe_comp', Function.comp_apply,
    ContinuousLinearMap.coe_fst', ContinuousLinearMap.coe_snd', smul_eq_mul, Pi.mul_apply,
    phiTotalFDeriv_apply]
  ring

/-- **Theorem 30 (Composed fee is a submersion; the section sum is ill-posed)
[M13].**  Three claims:

1. at every point with `φ_M, φ_X, τ_MEV < 1` the differential of
   `(φ_M, φ_X, τ_MEV) ↦ φ_total` is a surjection `ℝ³ → ℝ`, i.e. the map is a
   submersion there;
2. the map admits no inverse — it is not injective;
3. `∂φ_M/∂φ` and `∂φ_X/∂φ` are directional derivatives along *different*
   sections of one level set: two sections that agree at a point induce
   different values of `(∂φ_M/∂φ) ΔQ_M + p_{(η,Δi)} (∂φ_X/∂φ) ΔQ_X`, so that
   sum is not a derivative of `π^φ` along any single section.

The witness for (3) is the pair of coordinate sections `φ ↦ (φ, 0, 0)` and
`φ ↦ (0, φ, 0)`, which agree at `φ = 0`, evaluated at `ΔQ_M = 1`,
`p_{(η,Δi)} = 0`, `ΔQ_X = 0`. -/
theorem Theorem30_composed_fee_submersion_section_sum_ill_posed :
    (∀ φM φX tauMEV : ℝ, φM < 1 → φX < 1 → tauMEV < 1 →
        HasFDerivAt phiTotalMap (phiTotalFDeriv φM φX tauMEV) (φM, φX, tauMEV) ∧
          Function.Surjective (phiTotalFDeriv φM φX tauMEV)) ∧
      ¬ Function.Injective phiTotalMap ∧
      (∃ (s₁ s₂ : ℝ → ℝ × ℝ × ℝ) (φ0 dQM dQX p : ℝ),
        (∀ φ, phiTotalMap (s₁ φ) = φ) ∧ (∀ φ, phiTotalMap (s₂ φ) = φ) ∧
          s₁ φ0 = s₂ φ0 ∧
          deriv (fun φ => (s₁ φ).1) φ0 * dQM + p * (deriv (fun φ => (s₁ φ).2.1) φ0 * dQX) ≠
            deriv (fun φ => (s₂ φ).1) φ0 * dQM +
              p * (deriv (fun φ => (s₂ φ).2.1) φ0 * dQX)) := by
  refine ⟨?_, ?_, ?_⟩
  · intro φM φX tauMEV hM hX hτ
    refine ⟨hasFDerivAt_phiTotalMap φM φX tauMEV, ?_⟩
    intro y
    have hc : (0 : ℝ) < (1 - φX) * (1 - tauMEV) :=
      mul_pos (by linarith) (by linarith)
    refine ⟨(y / ((1 - φX) * (1 - tauMEV)), 0, 0), ?_⟩
    rw [phiTotalFDeriv_apply]
    simp only [mul_zero, add_zero]
    rw [mul_div_cancel₀ _ (ne_of_gt hc)]
  · intro hinj
    have h : phiTotalMap (1, 0, 0) = phiTotalMap (0, 1, 0) := by
      simp [phiTotalMap, phiTotal, VolInstrument.probOr]
    have := hinj h
    simp at this
  · refine ⟨fun φ => (φ, 0, 0), fun φ => (0, φ, 0), 0, 1, 0, 0, ?_, ?_, rfl, ?_⟩
    · intro φ; simp [phiTotalMap, phiTotal, VolInstrument.probOr]
    · intro φ; simp [phiTotalMap, phiTotal, VolInstrument.probOr]
    · norm_num

/-! ## M14. Propositions 12 and 13 — what the boxed law solves -/

/-- The boxed optimal-tax law of `SRC:207-234 @ 78381d4`, written out in full:

`τ*_MEV = 1 - (1/ΔQ_v^⋆) [∑_{i_K} π^l(σ(i_K;·)) ∂L(i_K)/∂π^φ]
             [ΔQ_M/(1-φ_X) + p_{(η,Δi)} ΔQ_X/(1-φ_M)] (∂φ/∂ν)(∂ν/∂τ_MEV)`.

`dLdpiPhi i_K` is the **price-axis** response `∂L(i_K)/∂π^φ`; `dphidnu` and
`dnudtau` are `∂φ/∂ν` and `∂ν/∂τ_MEV`. -/
def BoxedTauStarLaw (tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau : ℝ)
    (countSigma : ℕ) (piEll dLdpiPhi : ℕ → ℝ) : Prop :=
  tauMEV = 1 - (1 / dQvStar) *
    (∑ iK ∈ Finset.range countSigma, piEll iK * dLdpiPhi iK) *
      (dQM / (1 - φX) + p * dQX / (1 - φM)) * dphidnu * dnudtau

/-- The source's five-factor chain value for `∂π̂^σ/∂τ_MEV`, with the
`(1-τ_MEV)` factors produced at `SRC:110 @ 78381d4` still in place. -/
noncomputable def chainDerivative (tauMEV dQM dQX φM φX p dphidnu dnudtau : ℝ)
    (countSigma : ℕ) (piEll dLdpiPhi : ℕ → ℝ) : ℝ :=
  (∑ iK ∈ Finset.range countSigma, piEll iK * dLdpiPhi iK) *
    (dQM / ((1 - tauMEV) * (1 - φX)) + p * dQX / ((1 - tauMEV) * (1 - φM))) *
      dphidnu * dnudtau

/-- **Proposition 12 (The boxed law solves a different equation) [M14].**

1. The boxed `τ*_MEV` is *algebraically equivalent* to `∂π̂^σ/∂τ_MEV = ΔQ_v^⋆`
   — the source's own chain value equated with `ΔQ_v^⋆`, not with anything
   containing the contractual payoff.
2. The factor `(σ²(i(t)) - σ_K²)^+` of `π^σ` is **absent**: two states that
   differ only in the strike `σ_K²`, hence have different `π^σ`, satisfy the
   boxed law with the *same* `τ_MEV`, and at that `τ_MEV` the replication
   relation `π^σ ≡^R π̂^σ` fails.

Hence the boxed law is not the stated replication relation. -/
theorem Proposition12_boxed_law_solves_a_different_equation :
    (∀ (tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau : ℝ) (countSigma : ℕ)
        (piEll dLdpiPhi : ℕ → ℝ), dQvStar ≠ 0 → tauMEV ≠ 1 → φX ≠ 1 → φM ≠ 1 →
        (BoxedTauStarLaw tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau
            countSigma piEll dLdpiPhi ↔
          chainDerivative tauMEV dQM dQX φM φX p dphidnu dnudtau
            countSigma piEll dLdpiPhi = dQvStar)) ∧
      (∃ (tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau : ℝ) (countSigma : ℕ)
          (piEll dLdpiPhi : ℕ → ℝ) (sigma2 sigma2K₁ sigma2K₂ piSigmaHat : ℝ),
        BoxedTauStarLaw tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau
            countSigma piEll dLdpiPhi ∧
          Panoptic.volOptionPayoff dQvStar sigma2 sigma2K₁ ≠
            Panoptic.volOptionPayoff dQvStar sigma2 sigma2K₂ ∧
          Panoptic.volOptionPayoff dQvStar sigma2 sigma2K₁ ≠ piSigmaHat) := by
  constructor
  · intro tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau countSigma piEll dLdpiPhi
      hQ hτ hX hM
    unfold BoxedTauStarLaw chainDerivative
    have hτ' : (1 : ℝ) - tauMEV ≠ 0 := sub_ne_zero.mpr (Ne.symm hτ)
    have hX' : (1 : ℝ) - φX ≠ 0 := sub_ne_zero.mpr (Ne.symm hX)
    have hM' : (1 : ℝ) - φM ≠ 0 := sub_ne_zero.mpr (Ne.symm hM)
    constructor
    · intro h
      field_simp at h ⊢
      nlinarith [h]
    · intro h
      field_simp at h ⊢
      nlinarith [h]
  · refine ⟨0, 1, 1, 0, 0, 0, 0, 1, 1, 1, fun _ => 1, fun _ => 1, 1, 0, 1, 0, ?_, ?_, ?_⟩
    · unfold BoxedTauStarLaw
      norm_num
    · unfold Panoptic.volOptionPayoff
      norm_num
    · unfold Panoptic.volOptionPayoff
      norm_num

/-- The boxed law once it is admitted that `∂φ/∂ν` itself carries `τ_MEV`
(the composed fee contains the tax): `τ_MEV = 1 - K · (∂φ/∂ν)(τ_MEV)`. -/
def BoxedTauStarLawImplicit (tauMEV K : ℝ) (dphidnuOf : ℝ → ℝ) : Prop :=
  tauMEV = 1 - K * dphidnuOf tauMEV

/-- **Proposition 13 (Implicit, not closed) [M14].**

1. The boxed form is genuinely **closed** exactly when the trailing factor does
   not depend on `τ_MEV`: if `∂φ/∂ν` is constant in `τ_MEV`, the equation has
   the unique explicit solution `τ_MEV = 1 - K c`.
2. Without that condition the object is a fixed-point equation, and
   existence/uniqueness must be stated separately: there is data with **no**
   solution, and data with **more than one** solution. -/
theorem Proposition13_implicit_not_closed :
    (∀ (K c : ℝ) (dphidnuOf : ℝ → ℝ), (∀ t, dphidnuOf t = c) →
        ∃! tauMEV : ℝ, BoxedTauStarLawImplicit tauMEV K dphidnuOf) ∧
      (∃ (K : ℝ) (dphidnuOf : ℝ → ℝ),
        ¬ ∃ tauMEV : ℝ, BoxedTauStarLawImplicit tauMEV K dphidnuOf) ∧
      (∃ (K : ℝ) (dphidnuOf : ℝ → ℝ) (t₁ t₂ : ℝ), t₁ ≠ t₂ ∧
        BoxedTauStarLawImplicit t₁ K dphidnuOf ∧
          BoxedTauStarLawImplicit t₂ K dphidnuOf) := by
  refine ⟨?_, ?_, ?_⟩
  · intro K c dphidnuOf hconst
    refine ⟨1 - K * c, ?_, ?_⟩
    · show (1 : ℝ) - K * c = 1 - K * dphidnuOf (1 - K * c)
      rw [hconst]
    · intro t ht
      have ht' : t = 1 - K * dphidnuOf t := ht
      rw [hconst] at ht'
      exact ht'
  · refine ⟨1, fun t => 2 - t, ?_⟩
    rintro ⟨t, ht⟩
    unfold BoxedTauStarLawImplicit at ht
    linarith
  · refine ⟨1, fun t => 1 - t, 0, 1, by norm_num, ?_, ?_⟩ <;>
      · unfold BoxedTauStarLawImplicit
        ring

/-! ## M15. Proposition 14 — root, not argmin -/

/-- **Proposition 14 (No stationarity at the minimum) [M15]; the correct
object.**  The minimiser of `e^σ = |π^σ - π̂^σ|` is characterised as the **root
of the signed residual** `π^σ - π̂^σ = 0`.  Under continuity and *strict
monotonicity in `τ_MEV`* on the carrier `[0,1]` (the monotonicity hypothesis
this requires — supplied here as `hmono`, and delivered for the hazard channel
by Theorem 32), the root exists by IVT, is unique, and is the global minimiser
of `e^σ` on `[0,1]`.  No first-order condition is used. -/
theorem Proposition14_signed_residual_root
    (piSigma : ℝ) (piSigmaHat : ℝ → ℝ)
    (hcont : ContinuousOn piSigmaHat (Set.Icc 0 1))
    (hmono : StrictMonoOn piSigmaHat (Set.Icc 0 1))
    (hlo : piSigmaHat 0 ≤ piSigma) (hhi : piSigma ≤ piSigmaHat 1) :
    ∃! tauMEV : ℝ, tauMEV ∈ Set.Icc (0 : ℝ) 1 ∧ piSigma - piSigmaHat tauMEV = 0 := by
  have hsub := intermediate_value_Icc (by norm_num : (0 : ℝ) ≤ 1) hcont
  obtain ⟨t, ht, hval⟩ := hsub ⟨hlo, hhi⟩
  refine ⟨t, ⟨ht, by rw [hval]; ring⟩, ?_⟩
  rintro s ⟨hs, hsval⟩
  have hseq : piSigmaHat s = piSigmaHat t := by
    rw [hval]; linarith
  exact hmono.injOn hs ht hseq

/-- **Proposition 14 (No stationarity at the minimum) [M15]; the kink.**  The
absolute value attains its minimum where it is not differentiable, so no
first-order condition characterises the minimiser.  Witness: `π^σ = 1/2` and
`π̂^σ = id` (differentiable and strictly increasing), whose error
`e^σ(τ) = |1/2 - τ|` is minimised at the interior point `τ = 1/2` of the
carrier `[0,1]` and is not differentiable there. -/
theorem Proposition14_error_not_differentiable_at_minimiser :
    ∃ (piSigma : ℝ) (piSigmaHat : ℝ → ℝ) (tauMEV : ℝ),
      Differentiable ℝ piSigmaHat ∧ StrictMono piSigmaHat ∧
        tauMEV ∈ Set.Ioo (0 : ℝ) 1 ∧
        piSigma - piSigmaHat tauMEV = 0 ∧
        IsMinOn (fun t => |piSigma - piSigmaHat t|) Set.univ tauMEV ∧
        ¬ DifferentiableAt ℝ (fun t => |piSigma - piSigmaHat t|) tauMEV := by
  refine ⟨1 / 2, fun t => t, 1 / 2, differentiable_id, strictMono_id, by norm_num,
    by norm_num, ?_, ?_⟩
  · intro t _
    simp only [Set.mem_setOf_eq]
    norm_num
  · intro hd
    have hd' : DifferentiableAt ℝ (fun t : ℝ => |1 / 2 - t|) (1 / 2) := hd
    have hshift : DifferentiableAt ℝ (fun s : ℝ => s + 1 / 2) 0 :=
      (differentiable_id.add_const (1 / 2 : ℝ)).differentiableAt
    have hcomp : DifferentiableAt ℝ
        ((fun t : ℝ => |1 / 2 - t|) ∘ (fun s : ℝ => s + 1 / 2)) 0 := by
      refine DifferentiableAt.comp 0 ?_ hshift
      have hpt : (0 : ℝ) + 1 / 2 = 1 / 2 := by norm_num
      show DifferentiableAt ℝ (fun t : ℝ => |1 / 2 - t|) ((0 : ℝ) + 1 / 2)
      rw [hpt]
      exact hd'
    have heq : ((fun t : ℝ => |1 / 2 - t|) ∘ (fun s : ℝ => s + 1 / 2))
        = fun s : ℝ => |s| := by
      funext s
      simp only [Function.comp_apply]
      rw [show (1 : ℝ) / 2 - (s + 1 / 2) = -s by ring, abs_neg]
    rw [heq] at hcomp
    exact not_differentiableAt_abs_zero hcomp

/-! ## M16. Theorem 31 — admissibility on the carrier `[0,1]` -/

/-- **Theorem 31 (Admissibility and projection) [M16].**  `τ_MEV` lives in the
fee-monoid carrier `[0,1]` (`TauMevAlgebra.tau_monoid_mem`).  With `π̂^σ`
continuous and strictly increasing in `τ_MEV` on `[0,1]`:

1. **necessary and sufficient**: an admissible root of the signed residual
   exists iff `π̂^σ(0) ≤ π^σ ≤ π̂^σ(1)`;
2. **ITM branch** `σ_K² < σ²(i(t))` with the target above the carrier: the
   replication target is **infeasible** — the error is strictly positive at
   every admissible `τ_MEV` — and the admissible control is the projection
   `τ_MEV = 1`, which is a projection, not an attained corner solution;
3. **OTM branch** `σ²(i(t)) ≤ σ_K²`: `π^σ = 0`, so with a strictly positive
   kernel payoff there is no solution at all (in particular none interior), and
   the projection is the other endpoint `τ_MEV = 0`. -/
theorem Theorem31_admissibility_and_projection
    (dQvStar sigma2 sigma2K : ℝ) (piSigmaHat : ℝ → ℝ)
    (hcont : ContinuousOn piSigmaHat (Set.Icc 0 1))
    (hmono : StrictMonoOn piSigmaHat (Set.Icc 0 1)) :
    ((∃ tauMEV ∈ Set.Icc (0 : ℝ) 1,
        piSigmaHat tauMEV = Panoptic.volOptionPayoff dQvStar sigma2 sigma2K) ↔
      (piSigmaHat 0 ≤ Panoptic.volOptionPayoff dQvStar sigma2 sigma2K ∧
        Panoptic.volOptionPayoff dQvStar sigma2 sigma2K ≤ piSigmaHat 1)) ∧
    (sigma2K < sigma2 → piSigmaHat 1 < dQvStar * (sigma2 - sigma2K) →
      (∀ tauMEV ∈ Set.Icc (0 : ℝ) 1,
          0 < |Panoptic.volOptionPayoff dQvStar sigma2 sigma2K - piSigmaHat tauMEV|) ∧
        IsMinOn (fun t => |Panoptic.volOptionPayoff dQvStar sigma2 sigma2K - piSigmaHat t|)
          (Set.Icc 0 1) 1) ∧
    (sigma2 ≤ sigma2K →
      Panoptic.volOptionPayoff dQvStar sigma2 sigma2K = 0 ∧
        (0 < piSigmaHat 0 →
          (∀ tauMEV ∈ Set.Icc (0 : ℝ) 1, piSigmaHat tauMEV ≠ 0) ∧
            IsMinOn (fun t => |Panoptic.volOptionPayoff dQvStar sigma2 sigma2K - piSigmaHat t|)
              (Set.Icc 0 1) 0)) := by
  have h0mem : (0 : ℝ) ∈ Set.Icc (0 : ℝ) 1 := by constructor <;> norm_num
  have h1mem : (1 : ℝ) ∈ Set.Icc (0 : ℝ) 1 := by constructor <;> norm_num
  refine ⟨?_, ?_, ?_⟩
  · constructor
    · rintro ⟨tauMEV, hmem, hval⟩
      refine ⟨?_, ?_⟩
      · rw [← hval]
        exact hmono.monotoneOn h0mem hmem hmem.1
      · rw [← hval]
        exact hmono.monotoneOn hmem h1mem hmem.2
    · rintro ⟨hlo, hhi⟩
      obtain ⟨t, ht, hval⟩ :=
        intermediate_value_Icc (by norm_num : (0 : ℝ) ≤ 1) hcont ⟨hlo, hhi⟩
      exact ⟨t, ht, hval⟩
  · intro hitm habove
    have hpi : Panoptic.volOptionPayoff dQvStar sigma2 sigma2K
        = dQvStar * (sigma2 - sigma2K) := by
      unfold Panoptic.volOptionPayoff
      rw [max_eq_right (by linarith)]
    have hlt : ∀ tauMEV ∈ Set.Icc (0 : ℝ) 1,
        piSigmaHat tauMEV < Panoptic.volOptionPayoff dQvStar sigma2 sigma2K := by
      intro tauMEV hmem
      have := hmono.monotoneOn hmem h1mem hmem.2
      rw [hpi]
      linarith
    refine ⟨fun tauMEV hmem => ?_, ?_⟩
    · have := hlt tauMEV hmem
      rw [abs_pos]
      intro hzero
      linarith [sub_eq_zero.mp hzero]
    · rw [isMinOn_iff]
      intro x hx
      have hx1 := hmono.monotoneOn hx h1mem hx.2
      have hxlt := hlt x hx
      have h1lt := hlt 1 h1mem
      rw [abs_of_pos (by linarith), abs_of_pos (by linarith)]
      linarith
  · intro hotm
    have hpi : Panoptic.volOptionPayoff dQvStar sigma2 sigma2K = 0 := by
      unfold Panoptic.volOptionPayoff
      rw [max_eq_left (by linarith)]
      ring
    refine ⟨hpi, fun hpos => ⟨fun tauMEV hmem => ?_, ?_⟩⟩
    · have := hmono.monotoneOn h0mem hmem hmem.1
      intro hzero
      rw [hzero] at this
      linarith
    · rw [isMinOn_iff]
      intro x hx
      have hx0 := hmono.monotoneOn h0mem hx hx.1
      rw [hpi]
      rw [abs_of_nonpos (by linarith), abs_of_nonpos (by linarith)]
      linarith

/-! ## M17. Theorem 32 — the `τ → λ` bridge -/

/-- The arbitrage-channel hazard `λ_ARB` when the trader-paid fee carries the
monoid tax entry of Rule 12: at each event the fee is
`probOr (multiFee ...) τ_MEV`.  This is the hazard **sum**, not a pointwise
`ptrade` statement. -/
noncomputable def mevMultiTaxed (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (tauMEV : ℝ) : ℝ :=
  MevOptimization.mevHazard
    (fun σ => VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u σ) tauMEV)
    σpath a D Δt T

/-- The **joint action** of `probOr · τ_MEV` on `multiFee`'s output: it moves
`φ̄ ↦ φ̄(1-τ_MEV) + τ_MEV` **and** `α ↦ α(1-τ_MEV)` simultaneously.  It is not a
pure `φ̄`-shift. -/
lemma probOr_multiFee_joint (n : ℕ) (γ β α : ℕ → ℝ) (φbar u σ tauMEV : ℝ) :
    VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u σ) tauMEV =
      VolInstrument.multiFee n γ β (fun j => α j * (1 - tauMEV))
        (φbar * (1 - tauMEV) + tauMEV) u σ := by
  unfold VolInstrument.probOr VolInstrument.multiFee
  have hsum : ∑ j ∈ Finset.range n,
      α j * (1 - tauMEV) * FeeSchedule.logistic (γ j * (σ - β j))
      = (∑ j ∈ Finset.range n, α j * FeeSchedule.logistic (γ j * (σ - β j)))
        * (1 - tauMEV) := by
    rw [Finset.sum_mul]
    exact Finset.sum_congr rfl (fun j _ => by ring)
  rw [hsum]
  ring

/-- The taxed hazard is the untaxed hazard at the jointly moved parameters. -/
lemma mevMultiTaxed_eq_mevMulti (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ) (tauMEV : ℝ) :
    mevMultiTaxed n γ β α φbar u σpath a D Δt T tauMEV =
      MevOptimization.mevMulti n γ β (fun j => α j * (1 - tauMEV))
        (φbar * (1 - tauMEV) + tauMEV) u σpath a D Δt T := by
  unfold mevMultiTaxed MevOptimization.mevMulti MevOptimization.mevHazard
  refine Finset.sum_congr rfl (fun t _ => ?_)
  simp only [probOr_multiFee_joint]

/-- **Theorem 32 (Hazard monotonicity in the tax) [M17].**  The arbitrage
hazard `λ_ARB` is **strictly decreasing** in `τ_MEV` on the fee-monoid carrier
`[0,1]`, under the joint action of `probOr · τ_MEV` on `multiFee`'s output
(`φ̄ ↦ φ̄(1-τ_MEV) + τ_MEV` and `α ↦ α(1-τ_MEV)` simultaneously).

This is a statement about the hazard **sum**, not about a single `ptrade`
evaluation.  Guards: the fee is kept in `[0,1)` at every event (`hfee_lt_one`,
`hφbar`, `hα`, `hu`), which keeps `MevOptimization.ptrade` away from its
negative-fee pole and makes the composed fee strictly increase in the tax. -/
theorem Theorem32_hazard_strictAntiOn_tau
    (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hφbar : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u)
    (hfee_lt_one : ∀ t < T, VolInstrument.multiFee n γ β α φbar u (σpath t) < 1)
    (ha : ∀ t < T, 0 ≤ a t) (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hD : ∀ t < T, 0 < D t) (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt) :
    StrictAntiOn (fun tauMEV => mevMultiTaxed n γ β α φbar u σpath a D Δt T tauMEV)
      (Set.Icc 0 1) := by
  intro s hs t ht hst
  obtain ⟨t₀, ht₀T, ha₀⟩ := ha_pos
  -- the untaxed fee is nonnegative at every event (guards `ptrade` off its pole)
  have hfee0 : ∀ k, 0 ≤ VolInstrument.multiFee n γ β α φbar u (σpath k) := by
    intro k
    have := (VolInstrument.multiFee_bounds n γ β α φbar u (σpath k)
      (fun j hj => hα j (Finset.mem_range.mp hj)) hu).1
    linarith
  -- the taxed fee is nonnegative for a tax in the carrier `[0,1]`
  have hcomp0 : ∀ (x : ℝ), x ∈ Set.Icc (0 : ℝ) 1 → ∀ k,
      0 ≤ VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) x := by
    intro x hx k
    have h1 := hfee0 k
    unfold VolInstrument.probOr
    nlinarith [hx.1, hx.2]
  -- the joint action strictly raises the fee at every event with fee `< 1`
  have hfee_lt : ∀ k < T,
      VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) s <
        VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) t := by
    intro k hk
    have h1 := hfee_lt_one k hk
    unfold VolInstrument.probOr
    nlinarith
  -- hence `ptrade` strictly falls at every such event
  have hptrade : ∀ k < T,
      MevOptimization.ptrade
          (VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) t)
          (σpath k) Δt <
        MevOptimization.ptrade
          (VolInstrument.probOr (VolInstrument.multiFee n γ β α φbar u (σpath k)) s)
          (σpath k) Δt := by
    intro k hk
    exact MevOptimization.ptrade_strictAntiOn (σpath k) Δt (hσ k hk) hΔt
      (Set.mem_Ici.mpr (hcomp0 s hs k)) (Set.mem_Ici.mpr (hcomp0 t ht k)) (hfee_lt k hk)
  simp only [mevMultiTaxed, MevOptimization.mevHazard]
  refine Finset.sum_lt_sum (fun k hk => ?_) ⟨t₀, Finset.mem_range.mpr ht₀T, ?_⟩
  · have hk' : k < T := Finset.mem_range.mp hk
    exact div_le_div_of_nonneg_right
      (mul_le_mul_of_nonneg_right (le_of_lt (hptrade k hk')) (ha k hk'))
      (le_of_lt (hD k hk'))
  · exact div_lt_div_of_pos_right
      (mul_lt_mul_of_pos_right (hptrade t₀ ht₀T) ha₀) (hD t₀ ht₀T)

/-! ## M18. The behavioural hypotheses (never proved) and the axis error -/

/-- **(H1) [M18].**  `∂L̄/∂π^φ > 0`: the **price-axis** pool liquidity responds
to fee income.  This is an LP-supply estimand, not a proposition; it is carried
as a hypothesis and never discharged. -/
def H1_dLbar_dpiPhi_pos (Lbar : ℝ → ℝ) : Prop := ∀ piPhi : ℝ, 0 < deriv Lbar piPhi

/-- **(H2) [M18].**  `Ḡ_(ν, λ_MEV) := ∂ν/∂λ_MEV > 0`: utilization responds to
the MEV hazard.  This is an LP-supply estimand, not a proposition; it is
carried as a hypothesis and never discharged. -/
def H2_dnu_dlamMEV_pos (nu : ℝ → ℝ) : Prop := ∀ lamMEV : ℝ, 0 < deriv nu lamMEV

/-- **Corollary of Theorem 32 under (H2) [M17].**  The source assumes
`Ḡ_(ν, λ_MEV) := ∂ν/∂λ_MEV > 0` and then uses it where the channel requires
`∂ν/∂τ_MEV`.  The substitution is not licensed, and it flips the sign: with the
uniform-clearing identification of `λ_MEV` with the taxed arbitrage hazard
carried as an explicit hypothesis (`hclearing`, a modelling assumption, not a
cited result), Theorem 32 plus (H2) give that `ν` is strictly **decreasing** in
`τ_MEV` on the carrier `[0,1]`.

(H2) is carried as a typed argument and never discharged. -/
theorem tau_to_nu_strictAntiOn_under_H2
    (nu : ℝ → ℝ) (hH2 : H2_dnu_dlamMEV_pos nu)
    (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hφbar : 0 ≤ φbar) (hα : ∀ j < n, 0 ≤ α j) (hu : 0 ≤ u)
    (hfee_lt_one : ∀ t < T, VolInstrument.multiFee n γ β α φbar u (σpath t) < 1)
    (ha : ∀ t < T, 0 ≤ a t) (ha_pos : ∃ t₀ < T, 0 < a t₀)
    (hD : ∀ t < T, 0 < D t) (hσ : ∀ t < T, 0 < σpath t) (hΔt : 0 < Δt)
    (lamMEV : ℝ → ℝ)
    (hclearing : ∀ tauMEV,
      lamMEV tauMEV = mevMultiTaxed n γ β α φbar u σpath a D Δt T tauMEV) :
    StrictAntiOn (fun tauMEV => nu (lamMEV tauMEV)) (Set.Icc 0 1) := by
  have hnu : StrictMono nu := strictMono_of_deriv_pos hH2
  intro s hs t ht hst
  simp only [hclearing]
  exact hnu (Theorem32_hazard_strictAntiOn_tau n γ β α φbar u σpath a D Δt T
    hφbar hα hu hfee_lt_one ha ha_pos hD hσ hΔt hs ht hst)

/-- The ladder factorization on the **volatility axis**:
`L_σ(i_K) = L_σ ℓ(ξ^⋆, ι; i_K)` with `ℓ` a pure geometric weight summing to one,
so `∑_{i_K} L_σ(i_K) = ΔQ_v^⋆` when `L_σ = ΔQ_v^⋆`. -/
lemma ladder_sum_eq_dQvStar (Lsigma dQvStar : ℝ) (ell : ℕ → ℝ) (countSigma : ℕ)
    (hell : ∑ iK ∈ Finset.range countSigma, ell iK = 1) (hL : Lsigma = dQvStar) :
    ∑ iK ∈ Finset.range countSigma, Lsigma * ell iK = dQvStar := by
  rw [← Finset.mul_sum, hell, hL, mul_one]

/-- **M18 (the axis error, refuted).**  The volatility-axis ladder `L_σ(i_K)`
is invariant to the fee payoff — `ℓ` is a pure geometric weight and `L_σ` is the
stored `ΔQ_v^⋆` — but this says **nothing** about the price-axis pool liquidity
`L̄`, which under (H1) responds strictly.  Consequently the price-axis sum
`∑_{i_K} π^l ∂L(i_K)/∂π^φ` is strictly positive, and the boxed law's
`τ*_MEV = 1` conclusion (drawn from `∂L(i_K)/∂π^φ ≡ 0`) fails: the boxed
`τ*_MEV` is different from `1`.

(H1) is carried as a typed argument and is never discharged; (H2) is carried
the same way by `tau_to_nu_strictAntiOn_under_H2` above. -/
theorem M18_axis_error_refuted
    (Lbar : ℝ → ℝ) (hLbar : Differentiable ℝ Lbar)
    (hH1 : H1_dLbar_dpiPhi_pos Lbar)
    (piPhi Lsigma dQvStar dQM dQX φM φX p dphidnu dnudtau tauMEV : ℝ)
    (countSigma : ℕ) (ell piEll : ℕ → ℝ)
    (hell : ∀ iK, 0 < ell iK)
    (hpiEll : ∀ iK, 0 ≤ piEll iK) (hpiEll_pos : ∃ iK < countSigma, 0 < piEll iK)
    (hdQv : 0 < dQvStar)
    (hbracket : 0 < dQM / (1 - φX) + p * dQX / (1 - φM))
    (hdphidnu : 0 < dphidnu) (hdnudtau : dnudtau ≠ 0)
    (hbox : BoxedTauStarLaw tauMEV dQvStar dQM dQX φM φX p dphidnu dnudtau
      countSigma piEll (fun iK => deriv (fun q => Lbar q * ell iK) piPhi)) :
    (∀ iK, deriv (fun _ : ℝ => Lsigma * ell iK) piPhi = 0) ∧
      (∀ iK, 0 < deriv (fun q => Lbar q * ell iK) piPhi) ∧
      tauMEV ≠ 1 := by
  have hprice : ∀ iK, 0 < deriv (fun q => Lbar q * ell iK) piPhi := by
    intro iK
    rw [deriv_mul_const (hLbar piPhi)]
    exact mul_pos (hH1 piPhi) (hell iK)
  refine ⟨fun iK => deriv_const piPhi (Lsigma * ell iK), hprice, ?_⟩
  have hS : 0 < ∑ iK ∈ Finset.range countSigma,
      piEll iK * deriv (fun q => Lbar q * ell iK) piPhi := by
    obtain ⟨iK₀, hiK₀, hpos⟩ := hpiEll_pos
    refine Finset.sum_pos' (fun i _ => mul_nonneg (hpiEll i) (le_of_lt (hprice i)))
      ⟨iK₀, Finset.mem_range.mpr hiK₀, mul_pos hpos (hprice iK₀)⟩
  have hb : tauMEV = 1 - (1 / dQvStar) *
      (∑ iK ∈ Finset.range countSigma,
        piEll iK * deriv (fun q => Lbar q * ell iK) piPhi) *
      (dQM / (1 - φX) + p * dQX / (1 - φM)) * dphidnu * dnudtau := hbox
  intro htau
  rw [htau] at hb
  have hzero : (1 / dQvStar) *
      (∑ iK ∈ Finset.range countSigma,
        piEll iK * deriv (fun q => Lbar q * ell iK) piPhi) *
      (dQM / (1 - φX) + p * dQX / (1 - φM)) * dphidnu * dnudtau = 0 := by linarith
  have hne : (1 / dQvStar) *
      (∑ iK ∈ Finset.range countSigma,
        piEll iK * deriv (fun q => Lbar q * ell iK) piPhi) *
      (dQM / (1 - φX) + p * dQX / (1 - φM)) * dphidnu * dnudtau ≠ 0 := by
    refine mul_ne_zero (mul_ne_zero (mul_ne_zero (mul_ne_zero ?_ ?_) ?_) ?_) hdnudtau
    · exact ne_of_gt (by positivity)
    · exact ne_of_gt hS
    · exact ne_of_gt hbracket
    · exact ne_of_gt hdphidnu
  exact hne hzero

end MevTaxControl
