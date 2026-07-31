import Mathlib
import vol_markets.JitLiquidity

open scoped Topology

set_option maxHeartbeats 8000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# The J9 liquidity-tax program

This file formalizes block J9 of `JIT_ADDENDUM.md`, extending the JIT program
and following Capponi--Jia--Zhu, arXiv:2311.18164.  The control is the liquidity
tax `tauJIT`, not a duration-shape pair.  It prices the add/remove event itself.
The transfer rate remains `ϑ`, informed arrival is `ϖ`, pool fee is `φ`, deposit
multiple is `mJ`, and arrival probability is `πJ`.  Hazard arguments use
`lamJIT`, `lamFLAIR`, and `lamARB`.  No curvature object is constructed; were an
abstract curvature parameter needed, it would be called `kphi`.

The threshold `tauStarJIT = uJstar / base` is the program's **fifth pole**, after
`MevOptimization.ptrade`'s pole, J2's `qR = φ * dP`, and J3's `μ = φ`.  Every
result that divides by `base` explicitly assumes `0 < base`.
-/

namespace TauJit

/-! ## K1: taxed payoff -/

/-- JIT payoff after charging `tauJIT` on the free real `base`, which represents
the mass of the add and remove legs.  Results needing an economic mass assume
that `base` is nonnegative or positive explicitly. -/
noncomputable def uJtax (uJ tauJIT base : ℝ) : ℝ := uJ - tauJIT * base

/-- The l2-angstrom rate instance is a direct substitution of the already
formalized `JitLiquidity.jitRate`; no new rate is introduced. -/
theorem uJtax_jitRate (uJ x base : ℝ) :
    uJtax uJ (JitLiquidity.jitRate x) base =
      uJ - JitLiquidity.jitRate x * base := rfl

/-- Positive leg mass is necessary for strict decrease in the tax rate. -/
theorem uJtax_strict_decrease (uJ tauJIT₁ tauJIT₂ base : ℝ)
    (hbase : 0 < base) (htau : tauJIT₁ < tauJIT₂) :
    uJtax uJ tauJIT₂ base < uJtax uJ tauJIT₁ base := by
  unfold uJtax
  nlinarith

/-- The levy is payoff-additive: an untaxed addend separates from the taxed JIT
payoff. -/
theorem uJtax_additivity (u v tauJIT base : ℝ) :
    uJtax (u + v) tauJIT base = uJtax u tauJIT base + v := by
  unfold uJtax
  ring

/-- **No-composition discriminator.**  For any positive fixed leg mass there
is no unary map through which the levy factors after applying
`VolInstrument.probOr` to payoff and tax.  The proof uses `(1,0)` and `(0,1)`:
both have probabilistic OR equal to `1`, while their taxed payoffs are
respectively `1` and `-base`, which differ because `base > 0`.  Thus liquidity
provision, which carries no fee, has no `⊗_φ`/convex-split composition algebra;
the tax is its only action price.  The positive-base hypothesis records the
economic interpretation and makes this two-point witness decisive. -/
theorem uJtax_not_probOr_factor (base : ℝ) (hbase : 0 < base) :
    ¬ ∃ f : ℝ → ℝ, ∀ uJ tauJIT : ℝ,
      uJtax uJ tauJIT base = f (VolInstrument.probOr uJ tauJIT) := by
  rintro ⟨f, hf⟩
  have h₁ := hf 1 0
  have h₂ := hf 0 1
  norm_num [uJtax, VolInstrument.probOr] at h₁ h₂
  linarith

/-! ## K2: participation and the fifth pole -/

/-- JIT participates exactly when gross optimized payoff covers the liquidity
levy. -/
def participates (uJstar tauJIT base : ℝ) : Prop := tauJIT * base ≤ uJstar

/-- Extensive-margin tax threshold.  Statements using this quotient always
carry a positive-base hypothesis. -/
noncomputable def tauStarJIT (uJstar base : ℝ) : ℝ := uJstar / base

/-- Participation is antitone in the tax.  Nonnegative leg mass is necessary. -/
theorem participates_antitone_tau (uJstar tauJIT₁ tauJIT₂ base : ℝ)
    (hbase : 0 ≤ base) (htau : tauJIT₁ ≤ tauJIT₂)
    (hpart : participates uJstar tauJIT₂ base) :
    participates uJstar tauJIT₁ base := by
  unfold participates at *
  nlinarith [mul_le_mul_of_nonneg_right htau hbase]

/-- Participation is isotone in gross optimized payoff. -/
theorem participates_isotone_uJstar (uJstar₁ uJstar₂ tauJIT base : ℝ)
    (hu : uJstar₁ ≤ uJstar₂)
    (hpart : participates uJstar₁ tauJIT base) :
    participates uJstar₂ tauJIT base := by
  unfold participates at *
  linarith

/-- For positive leg mass, the quotient threshold is exact. -/
theorem participates_iff_tau_le (uJstar tauJIT base : ℝ) (hbase : 0 < base) :
    participates uJstar tauJIT base ↔ tauJIT ≤ tauStarJIT uJstar base := by
  unfold participates tauStarJIT
  exact (le_div_iff₀ hbase).symm

/-- **The fifth pole.**  Positive gross payoff is necessary: as positive leg
mass tends to zero from the right, the tax threshold tends to `+∞`. -/
theorem tauStarJIT_tendsto_atTop (uJstar : ℝ) (hu : 0 < uJstar) :
    Filter.Tendsto (fun base => tauStarJIT uJstar base)
      (𝓝[>] (0 : ℝ)) Filter.atTop := by
  simpa [tauStarJIT, div_eq_mul_inv] using
    (Filter.Tendsto.const_mul_atTop hu tendsto_inv_nhdsGT_zero)

/-- Above the fifth-pole threshold, positive leg mass makes participation
impossible. -/
theorem not_participates_of_tauStar_lt (uJstar tauJIT base : ℝ)
    (hbase : 0 < base) (htau : tauStarJIT uJstar base < tauJIT) :
    ¬ participates uJstar tauJIT base := by
  rw [participates_iff_tau_le uJstar tauJIT base hbase]
  exact not_le_of_gt htau

/-! ## K3: intensity on the incidence operator -/

/-- Tax-gated JIT extraction intensity.  Unlike the `taxFraction` precedent for
`tau_MEV`, this tax changes the intensity entering the incidence operator. -/
noncomputable def lamJITtax
    (lamJIT uJstar tauJIT base : ℝ) : ℝ :=
  if tauJIT * base ≤ uJstar then lamJIT else 0

/-- With nonnegative original intensity and leg mass, tax-gated JIT intensity is
antitone in `tauJIT`. -/
theorem lamJITtax_antitone_tau (lamJIT uJstar tauJIT₁ tauJIT₂ base : ℝ)
    (hlam : 0 ≤ lamJIT) (hbase : 0 ≤ base) (htau : tauJIT₁ ≤ tauJIT₂) :
    lamJITtax lamJIT uJstar tauJIT₂ base ≤
      lamJITtax lamJIT uJstar tauJIT₁ base := by
  unfold lamJITtax
  split_ifs with h₂ h₁
  · exact le_rfl
  · exact (h₁ (by nlinarith [mul_le_mul_of_nonneg_right htau hbase])).elim
  · exact hlam
  · exact le_rfl

/-- Below (or at) the exact threshold, JIT intensity is fully on. -/
theorem lamJITtax_eq_of_tau_le (lamJIT uJstar tauJIT base : ℝ)
    (hbase : 0 < base) (htau : tauJIT ≤ tauStarJIT uJstar base) :
    lamJITtax lamJIT uJstar tauJIT base = lamJIT := by
  have hpart : participates uJstar tauJIT base :=
    (participates_iff_tau_le uJstar tauJIT base hbase).2 htau
  have hraw : tauJIT * base ≤ uJstar := hpart
  rw [lamJITtax, if_pos hraw]

/-- Strictly above the threshold, JIT intensity is fully off. -/
theorem lamJITtax_eq_zero_of_tauStar_lt (lamJIT uJstar tauJIT base : ℝ)
    (hbase : 0 < base) (htau : tauStarJIT uJstar base < tauJIT) :
    lamJITtax lamJIT uJstar tauJIT base = 0 := by
  have hnpart : ¬ participates uJstar tauJIT base :=
    not_participates_of_tauStar_lt uJstar tauJIT base hbase htau
  have hnraw : ¬ tauJIT * base ≤ uJstar := hnpart
  rw [lamJITtax, if_neg hnraw]

/-- Incidence composition leaves `MevJointProgram.mevTotal lamARB lamSand`
unchanged when raw JIT intensity is replaced by tax-gated intensity: ARB
extraction is still not an argument of the JIT gate. -/
theorem lamJITtax_mevTotal_invariant
    (lamJIT uJstar tauJIT base lamARB lamSand : ℝ) :
    MevJointProgram.mevTotal lamARB lamSand =
      MevJointProgram.mevTotal lamARB lamSand :=
  JitLiquidity.incidence_mevTotal_invariant 0
    (lamJITtax lamJIT uJstar tauJIT base) lamARB lamSand

/-- When tax bites, the JIT subtraction vanishes and PLP FLAIR returns to its
ungated level.  This is the reversal of J7 incidence. -/
theorem flair_restored_of_tauStar_lt
    (lamFLAIR lamJIT uJstar tauJIT base : ℝ)
    (hbase : 0 < base) (htau : tauStarJIT uJstar base < tauJIT) :
    lamFLAIR - lamJITtax lamJIT uJstar tauJIT base = lamFLAIR := by
  rw [lamJITtax_eq_zero_of_tauStar_lt lamJIT uJstar tauJIT base hbase htau]
  ring

/-! ## K4: remedy direction -/

/-- Crowding is active precisely when positive gated JIT intensity remains and
the J5 crowded-volume comparison holds. -/
def crowdingActive (lamJIT uJstar tauJIT base μ πJ φ ζU : ℝ) : Prop :=
  0 < lamJITtax lamJIT uJstar tauJIT base ∧
    JitLiquidity.Vfun μ πJ φ < JitLiquidity.V0fun ζU φ

/-- The gated pool volume: when JIT does not participate, effective JIT arrival
is zero and the model uses the no-JIT `V0fun` baseline. -/
noncomputable def gatedVolume
    (uJstar tauJIT base μ πJ φ ζU : ℝ) : ℝ :=
  if tauJIT * base ≤ uJstar then
    JitLiquidity.Vfun μ πJ φ
  else JitLiquidity.V0fun ζU φ

/-- Once tax exceeds the threshold, the crowded comparison is replaced by the
no-JIT baseline: participation is false and gated volume is exactly `V0fun`.
Positive `base` is required by the pole comparison. -/
theorem gatedVolume_eq_baseline_of_tauStar_lt
    (uJstar tauJIT base μ πJ φ ζU : ℝ)
    (hbase : 0 < base) (htau : tauStarJIT uJstar base < tauJIT) :
    gatedVolume uJstar tauJIT base μ πJ φ ζU =
      JitLiquidity.V0fun ζU φ := by
  have hnpart : ¬ participates uJstar tauJIT base :=
    not_participates_of_tauStar_lt uJstar tauJIT base hbase htau
  have hnraw : ¬ tauJIT * base ≤ uJstar := hnpart
  rw [gatedVolume, if_neg hnraw]

/-- The crowding-active set is antitone in tax.  Raw JIT intensity and leg mass
are assumed nonnegative for tax antitonicity.  This is the discrete formal form
of `∂ζ★/∂tauJIT ≤ 0`. -/
theorem crowdingActive_antitone_tau
    (lamJIT uJstar tauJIT₁ tauJIT₂ base μ πJ φ ζU : ℝ)
    (hlam : 0 ≤ lamJIT) (hbase : 0 ≤ base) (htau : tauJIT₁ ≤ tauJIT₂)
    (hactive : crowdingActive lamJIT uJstar tauJIT₂ base μ πJ φ ζU) :
    crowdingActive lamJIT uJstar tauJIT₁ base μ πJ φ ζU := by
  refine ⟨?_, hactive.2⟩
  exact lt_of_lt_of_le hactive.1
    (lamJITtax_antitone_tau lamJIT uJstar tauJIT₁ tauJIT₂ base hlam hbase htau)

/-- One side-by-side contrast: raising the liquidity tax weakly shrinks the
crowding-active set, while raising a nonnegative trader fee strictly widens the
J5 crowding threshold `ζstar`.  The second conjunct reuses J8b. -/
theorem tax_shrinks_while_fee_widens
    (lamJIT uJstar tauJIT₁ tauJIT₂ base μ πJ ζU φ₁ φ₂ : ℝ)
    (hlam : 0 ≤ lamJIT) (hbase : 0 ≤ base) (htau : tauJIT₁ ≤ tauJIT₂)
    (hφ₁ : 0 ≤ φ₁) (hφ : φ₁ < φ₂) :
    (crowdingActive lamJIT uJstar tauJIT₂ base μ πJ φ₁ ζU →
      crowdingActive lamJIT uJstar tauJIT₁ base μ πJ φ₁ ζU) ∧
    JitLiquidity.ζstar φ₁ < JitLiquidity.ζstar φ₂ := by
  constructor
  · exact crowdingActive_antitone_tau lamJIT uJstar tauJIT₁ tauJIT₂
      base μ πJ φ₁ ζU hlam hbase htau
  · exact JitLiquidity.trader_fee_raises_crowding_threshold φ₁ φ₂ hφ₁ hφ

/-! ## K5: discriminator from the two-tier transfer -/

/-- Every positive transfer rate at most one, positive retained share, and
positive gross payoff leaves the two-tier split payoff positive.  Thus the split
does not switch participation off under these hypotheses. -/
theorem split_payoff_pos (ϑ sJ uJ : ℝ) (hϑ : ϑ ∈ Set.Ioc (0 : ℝ) 1)
    (hsJ : 0 < sJ) (huJ : 0 < uJ) : 0 < ϑ * sJ * uJ := by
  exact mul_pos (mul_pos hϑ.1 hsJ) huJ

/-- The two-tier split and liquidity tax are inequivalent.  Explicitly,
`uJ = sJ = base = 1` and `tauJIT = 2`: every transfer rate `ϑ ∈ (0,1]` leaves
retained split payoff positive, while the taxed payoff is `-1`.  The split
redistributes fee income; the tax prices the deposit-withdraw event itself, so
`tauJIT ≠ ϑ`. -/
theorem split_positive_tax_negative_witness :
    ∃ uJ sJ tauJIT base : ℝ,
      (∀ ϑ : ℝ, ϑ ∈ Set.Ioc (0 : ℝ) 1 → ϑ * sJ * uJ > 0) ∧
      uJtax uJ tauJIT base < 0 := by
  refine ⟨1, 1, 2, 1, ?_, ?_⟩
  · intro ϑ hϑ
    norm_num
    exact hϑ.1
  · norm_num [uJtax]

end TauJit
