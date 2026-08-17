import Mathlib
import vol_markets.MevJointProgram

open scoped BigOperators

set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# τ_MEV entry algebra

This module formalizes blocks M9–M10 of `TAU_ADDENDUM.md`.  It records three
author-facing alternatives without canonizing one of them:

* (A) monoid entry is hazard-additive, intensity-bearing, and non-targeting;
* (B) convex separation is revenue-linear, intensity-neutral, and targets
  incidence by routing realized revenue;
* (C), already represented by `MevJointProgram.taxFraction` and
  `MevJointProgram.mevNet`, targets the extractor through an auction channel.

The discriminator theorems show that the entries cannot be silently identified:
revenue scaling is not a `VolInstrument.probOr` morphism, composition and
splitting are order-sensitive, and revenue scaling does not preserve the exact
hazard correspondence.  Selecting among (A), (B), (C), or an ordered hybrid is
therefore an author decision.
-/

namespace TauMevAlgebra

/-- LP revenue after convex separation of a realized fee. -/
def lpShare (tauMEV φ : ℝ) : ℝ := (1 - tauMEV) * φ

/-- Donation revenue after convex separation of a realized fee. -/
def donation (tauMEV φ : ℝ) : ℝ := tauMEV * φ

/-- **A1.** Monoid entry remains in `[0,1]`.  The model-domain hypotheses
supplied here are `φ ∈ [0,1]` and `tauMEV ∈ [0,1]`. -/
theorem tau_monoid_mem (φ tauMEV : ℝ) (hφ : φ ∈ Set.Icc (0 : ℝ) 1)
    (hτ : tauMEV ∈ Set.Icc (0 : ℝ) 1) :
    VolInstrument.probOr φ tauMEV ∈ Set.Icc (0 : ℝ) 1 := by
  exact VolInstrument.probOr_mem_Icc hφ hτ

/-- **A2 (weak).** Composition never lowers the fee.  It needs exactly
`0 ≤ tauMEV` and `φ ≤ 1`; no lower bound on `φ` or upper bound on `tauMEV` is
needed for this algebraic inequality. -/
theorem tau_monoid_ge (φ tauMEV : ℝ) (hτ : 0 ≤ tauMEV) (hφ : φ ≤ 1) :
    φ ≤ VolInstrument.probOr φ tauMEV := by
  simp [VolInstrument.probOr]
  nlinarith [mul_self_nonneg tauMEV]

/-- **A2 (strict).** Composition strictly raises the fee when `0 < tauMEV` and
`φ < 1`; these are exactly the strict hypotheses used. -/
theorem tau_monoid_gt (φ tauMEV : ℝ) (hτ : 0 < tauMEV) (hφ : φ < 1) :
    φ < VolInstrument.probOr φ tauMEV := by
  unfold VolInstrument.probOr
  nlinarith [mul_pos hτ (sub_pos.mpr hφ)]

/-- **A3 (weak intensity channel).** Monoid entry deters extraction.  The
admissible-domain hypotheses are `0 ≤ φ`, `0 ≤ tauMEV`, `φ ≤ 1`, `0 < σ`, and
`0 < Δt`.  They place both fees in the nonnegative domain on which `ptrade` is
strictly decreasing; the weak conclusion also covers a zero tax. -/
theorem tau_intensity_effect (φ tauMEV σ Δt : ℝ)
    (hφ0 : 0 ≤ φ) (hτ0 : 0 ≤ tauMEV) (hφ1 : φ ≤ 1)
    (hσ : 0 < σ) (hΔt : 0 < Δt) :
    MevOptimization.ptrade (VolInstrument.probOr φ tauMEV) σ Δt ≤
      MevOptimization.ptrade φ σ Δt := by
  have hcomposed0 : 0 ≤ VolInstrument.probOr φ tauMEV := by
    unfold VolInstrument.probOr
    nlinarith
  exact (MevOptimization.ptrade_strictAntiOn σ Δt hσ hΔt).antitoneOn
    hφ0 hcomposed0 (tau_monoid_ge φ tauMEV hτ0 hφ1)

/-- **A3 (strict intensity channel).** Under `0 ≤ φ`, `0 < tauMEV`, `φ < 1`,
`0 < σ`, and `0 < Δt`, monoid entry strictly deters extraction.  No upper bound
on `tauMEV` is required because nonnegativity of the composed fee suffices for
the kernel's strict-antitonicity domain. -/
theorem tau_intensity_effect_strict (φ tauMEV σ Δt : ℝ)
    (hφ0 : 0 ≤ φ) (hτ : 0 < tauMEV) (hφ1 : φ < 1)
    (hσ : 0 < σ) (hΔt : 0 < Δt) :
    MevOptimization.ptrade (VolInstrument.probOr φ tauMEV) σ Δt <
      MevOptimization.ptrade φ σ Δt := by
  have h_gt : φ < VolInstrument.probOr φ tauMEV := tau_monoid_gt φ tauMEV hτ hφ1
  have h_probOr_nonneg : 0 ≤ VolInstrument.probOr φ tauMEV := by
    unfold VolInstrument.probOr
    nlinarith
  exact MevOptimization.ptrade_strictAntiOn σ Δt hσ hΔt hφ0 h_probOr_nonneg h_gt

/-- **A4 (no targeting).** The aggregate is invariant to which fee leg carries
the tax.  This is purely associativity and commutativity of `probOr` and needs
no interval hypotheses. -/
theorem tau_no_targeting (φM φX tauMEV : ℝ) :
    VolInstrument.probOr (VolInstrument.probOr φM tauMEV) φX =
      VolInstrument.probOr φM (VolInstrument.probOr φX tauMEV) := by
  unfold VolInstrument.probOr
  ring

/-- **A5 (hazard exactness).** Three-way monoid entry adds hazards exactly.
This algebraic exponential identity needs no sign hypotheses on the hazards. -/
theorem tau_hazard_exact (lamM lamX lamTau : ℝ) :
    VolInstrument.probOr
        (VolInstrument.probOr (1 - Real.exp (-lamM)) (1 - Real.exp (-lamX)))
        (1 - Real.exp (-lamTau)) =
      1 - Real.exp (-(lamM + lamX + lamTau)) := by
  rw [VolInstrument.probOr_eq, VolInstrument.probOr_eq]
  simp [Real.exp_add]
  ring

/-- **B1 (budget identity).** This is definitional accounting, not a deep
result.  It needs no interval hypothesis; `[0,1]` is the economic domain rather
than an algebraic requirement for the identity. -/
theorem tau_split_budget (tauMEV φ : ℝ) :
    lpShare tauMEV φ + donation tauMEV φ = φ := by
  simp [lpShare, donation]
  ring

/-- **B2 (intensity neutrality).** Convex separation routes the realized fee
between the `lpShare`/`donation` pair while preserving their sum as the
trader-facing fee.  Consequently every object depending on this occurrence of
`MevOptimization.ptrade` is unchanged.  No positivity or interval hypotheses
are needed for this definitional identity. -/
theorem tau_split_intensity_neutral (tauMEV φ σ Δt : ℝ) :
    MevOptimization.ptrade (lpShare tauMEV φ + donation tauMEV φ) σ Δt =
      MevOptimization.ptrade φ σ Δt := by
  rw [tau_split_budget]

/-- **B3 (FLAIR linearity).** Revenue-side scaling by `1 - tauMEV` distributes
over the affine FLAIR identification and is realizable inside `Θ_φ` by jointly
scaling the level block `(φbar,u)`.  This is not substitution of the tax for a
shape parameter.  No interval or positivity hypotheses are algebraically
needed. -/
theorem tau_split_flair_linear (tauMEV : ℝ) (n : ℕ) (γ β α : ℕ → ℝ)
    (φbar u : ℝ) (σpath w D : ℕ → ℝ) (T : ℕ) :
    (1 - tauMEV) * FlairOptimization.flairMulti n γ β α φbar u σpath w D T =
      FlairOptimization.flairMulti n γ β α ((1 - tauMEV) * φbar)
        ((1 - tauMEV) * u) σpath w D T := by
  rw [FlairOptimization.flairMulti_affine, FlairOptimization.flairMulti_affine]
  ring

/-- **B4 (auction/net bridge).** If the recycling share is the landed auction
fraction `taxFraction k`, then convex separation of realized extraction `X`
produces exactly the `mevNet`-shaped LP-net term and its complementary donation.
The only hypothesis is the requested identification
`tauMEV = taxFraction k`; no sign or interval assumptions are needed for these
exact identities. -/
theorem tau_split_mevNet_bridge (tauMEV k : ℝ) (n : ℕ)
    (γ β α : ℕ → ℝ) (φbar u : ℝ) (σpath a D : ℕ → ℝ) (Δt : ℝ) (T : ℕ)
    (hτ : tauMEV = MevJointProgram.taxFraction k) :
    lpShare tauMEV
        (MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T) =
      MevJointProgram.mevNet (MevJointProgram.taxFraction k)
        n γ β α φbar u σpath a D Δt T ∧
    donation tauMEV
        (MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T) =
      MevJointProgram.taxFraction k *
        MevOptimization.mevMulti n γ β α φbar u σpath a D Δt T := by
  simp [hτ, lpShare, donation, MevJointProgram.mevNet]

/-- **D1.** At `a=b=1` and `tauMEV=1/2`, convex revenue scaling is not a
`probOr` homomorphism: the two sides are respectively `1/2` and `3/4`. -/
theorem tau_scaling_not_monoid_hom :
    (1 - (1 / 2 : ℝ)) * VolInstrument.probOr 1 1 ≠
      VolInstrument.probOr ((1 - (1 / 2 : ℝ)) * 1)
        ((1 - (1 / 2 : ℝ)) * 1) := by
  unfold VolInstrument.probOr
  norm_num

/-- **D2.** At `φ=1`, `tauX=1`, and split share `tauMEV=1/2`, tax-then-compose
is not compose-then-split: the two sides are respectively `1` and `1/2`.
Thus the hybrid (A)∘(B) is order-sensitive. -/
theorem tau_order_matters :
    VolInstrument.probOr ((1 - (1 / 2 : ℝ)) * 1) 1 ≠
      (1 - (1 / 2 : ℝ)) * VolInstrument.probOr 1 1 := by
  unfold VolInstrument.probOr
  norm_num

/-- **D3.** Revenue separation does not preserve the hazard correspondence.
The explicit witness is `tauMEV=1/2`, `λ=2*log 2`; exact exponential/logarithm
identities reduce the two sides to `1/2` and `3/8`. -/
theorem tau_split_breaks_hazard :
    1 - Real.exp (-((1 / 2 : ℝ) * (2 * Real.log 2))) ≠
      (1 / 2 : ℝ) * (1 - Real.exp (-(2 * Real.log 2))) := by
  have lhs : 1 - Real.exp (-((1 / 2 : ℝ) * (2 * Real.log 2))) = 1 / 2 := by
    have : (1 / 2 : ℝ) * (2 * Real.log 2) = Real.log 2 := by ring
    rw [this, Real.exp_neg, Real.exp_log (by norm_num : (2 : ℝ) > 0)]
    norm_num
  have rhs : (1 / 2 : ℝ) * (1 - Real.exp (-(2 * Real.log 2))) = 3 / 8 := by
    have h2 : Real.exp (-(2 * Real.log 2)) = 1 / 4 := by
      rw [two_mul, Real.exp_neg, Real.exp_add, Real.exp_log (by norm_num : (2 : ℝ) > 0)]
      norm_num
    rw [h2]
    norm_num
  rw [lhs, rhs]
  norm_num

end TauMevAlgebra
