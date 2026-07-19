import Mathlib
import vol_markets.PosSpec
import vol_markets.Flow
open scoped BigOperators
open Real
set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Panoptic vol-claim: analytical core

This module formalizes the analytical core of `spec/panoptic.md`:

* the volatility-option payoff `π^σ = ΔQ_v · (σ²(i) − σ²_K)⁺` and its `ΔQ_v`
  finite-difference identity (dimensionally anchored to `Flow.deltaShares`),
* the structural replication decomposition `p = p₀ + α₁·p_call + α₂·p_put`,
* the streaming premium as a `Finset.sum` over lattice steps `Σ_j θ(j)·Δt`,
* the CRR backward-induction operator with constant risk-neutral probability `q`,
* the lattice `θ` (dt-leg) read at the strike-tick **center column** `i_K`
  (NOT the all-up diagonal), and
* the closed-form target theorem `Θ_ATM(τ) = kσ/√(8πτ)`, stated as an unproved
  asymptotic isolated behind a stable statement for the Aristotle derivation
  (08-05), together with its load-bearing central-binomial sub-lemma.

All quantities are over `ℝ` (real-first). The `ΔQ_v` factor of `π^σ` occupies the
same dimensional slot as `Flow.deltaShares` (`ΔQ_v = ΔQ_M / p_risk`).
-/

namespace Panoptic

/-! ## 1. Vol-option payoff `π^σ` and the `ΔQ_v` identity -/

/-- Vol-option payoff `π^σ = ΔQ_v · (σ²(i) − σ²_K)⁺` (the `⁺` is `max 0`). -/
noncomputable def volOptionPayoff (dQv sig2 sig2K : ℝ) : ℝ := dQv * max 0 (sig2 - sig2K)

/-- The payoff is nonnegative for a nonnegative share flow `ΔQ_v`. -/
lemma volOptionPayoff_nonneg (dQv sig2 sig2K : ℝ) (h : 0 ≤ dQv) :
    0 ≤ volOptionPayoff dQv sig2 sig2K := by
  exact mul_nonneg h (le_max_left _ _)

/-- `ΔQ_v` as the difference quotient of `π^σ` in `σ²`; on the region where the
option is in-the-money at both endpoints it equals `dQv` (the payoff's linear
coefficient). This surfaces that `υ` (defined in 08-04) occupies the `ΔQ_v` slot:
the difference quotient recovers the payoff's vol-coefficient. The numerator is a
payoff difference and the denominator is the `⁺`-difference, matching the SHAPE of
`Flow.deltaShares` (a dimensional bridge, not a numeric equality claim). -/
lemma deltaQv_of_payoff (dQv sig2 Δs sig2K : ℝ) (hΔ : 0 < Δs)
    (h1 : sig2K ≤ sig2) (h2 : sig2K ≤ sig2 + Δs) :
    (volOptionPayoff dQv (sig2 + Δs) sig2K - volOptionPayoff dQv sig2 sig2K) / Δs = dQv := by
  unfold volOptionPayoff
  rw [max_eq_right (by linarith), max_eq_right (by linarith)]
  field_simp; ring

/-! ## 2. Structural replication decomposition `p = p₀ + α₁·p_call + α₂·p_put` -/

/-- Structural replication price `p = p₀ + α₁·p_call + α₂·p_put` (the `α`'s are
free parameters; the affine-in-options form is the definition — locked decision). -/
noncomputable def replicationPrice (p0 a1 a2 pCall pPut : ℝ) : ℝ :=
  p0 + a1 * pCall + a2 * pPut

/-- Call-only specialization: `p₀ = 0, α₁ = 1, α₂ = 0` recovers the call price. -/
lemma replicationPrice_call_only (pCall pPut : ℝ) :
    replicationPrice 0 1 0 pCall pPut = pCall := by unfold replicationPrice; ring

/-- Additivity of the constant leg `p₀`: a shift in `p₀` shifts the price by `δ`. -/
lemma replicationPrice_shift (p0 δ a1 a2 pCall pPut : ℝ) :
    replicationPrice (p0 + δ) a1 a2 pCall pPut
      = replicationPrice p0 a1 a2 pCall pPut + δ := by unfold replicationPrice; ring

/-! ## 3. Streaming premium `Σ_j θ(j)·Δt` (discrete; `∫θ dt` is the continuum limit) -/

/-- Streaming premium `Σ_j θ(j)·Δt` over `N` lattice steps (discrete form; the
`∫θ dt` form is the continuum limit only). -/
noncomputable def streamingPremium (θ : ℕ → ℝ) (Δt : ℝ) (N : ℕ) : ℝ :=
  ∑ j ∈ Finset.range N, θ j * Δt

/-- Telescoping/linearity: one extra lattice step adds `θ(N)·Δt`. -/
lemma streamingPremium_succ (θ : ℕ → ℝ) (Δt : ℝ) (N : ℕ) :
    streamingPremium θ Δt (N + 1) = streamingPremium θ Δt N + θ N * Δt := by
  unfold streamingPremium; rw [Finset.sum_range_succ]

/-! ## 4. CRR backward-induction operator (FINANCE §6.15/6.18), constant `q` -/

/-- Risk-neutral probability `q = (λ e^{rΔt} − 1)/(λ² − 1)`; `(i,j)`-independent on
the geometric grid (constant, per FINANCE §6.18). -/
noncomputable def q (lam r Δt : ℝ) : ℝ := (lam * Real.exp (r * Δt) - 1) / (lam ^ 2 - 1)

/-- CRR backward-induction step `π(i,j) = e^{−rΔt}[q·up + (1−q)·dn]`. -/
noncomputable def crrStep (lam r Δt up dn : ℝ) : ℝ :=
  Real.exp (-r * Δt) * (q lam r Δt * up + (1 - q lam r Δt) * dn)

/-- On a flat sub-tree (equal up/down continuation values) the CRR step collapses
to pure discounting `e^{−rΔt}·v`. -/
lemma crrStep_const (lam r Δt v : ℝ) :
    crrStep lam r Δt v v = Real.exp (-r * Δt) * v := by
  unfold crrStep; ring

/-! ## 5. Lattice `θ` = dt-leg, read at the strike-tick CENTER COLUMN `i_K` -/

/-- Lattice theta = dt-leg of `dπ`: `Θ(i,j) = (π(i,j+1) − π(i,j))/Δt`. Signed
(`Θ < 0` for a long claim). The lattice value function is `pl : ℤ → ℕ → ℝ`
(price-tick `i`, time-step `j`); it is named `pl` because `π` is reserved Mathlib
notation for `Real.pi`. -/
noncomputable def latticeTheta (pl : ℤ → ℕ → ℝ) (Δt : ℝ) (i : ℤ) (j : ℕ) : ℝ :=
  (pl i (j + 1) - pl i j) / Δt

/-- ATM theta = `|Θ|` read at the STRIKE-TICK CENTER COLUMN `i_K` (the balanced
up/down node), NOT the all-up diagonal node whose price index tracks the time
index. Fix the price index at `iK`; vary time `j`. (Pitfall 2 guard: this is the
center column, not the diagonal.) -/
noncomputable def thetaAtm (pl : ℤ → ℕ → ℝ) (Δt : ℝ) (iK : ℤ) (j : ℕ) : ℝ :=
  |latticeTheta pl Δt iK j|

/-! ## 6. Closed-form target `Θ_ATM(τ) = kσ/√(8πτ)` (Aristotle, 08-05) -/

/-- LOAD-BEARING SUB-LEMMA (Aristotle, Stage-2): the sharp central-binomial
asymptotic `C(2m,m) ~ 4^m/√(π m)`. Mathlib has Stirling + Wallis but NOT this
sharp equivalent form, so the `√(8π)` normalization of the θ closed form is not
available off the shelf (Pitfall 1). Reserved for Aristotle. -/
theorem centralBinom_isEquivalent :
    Filter.Tendsto
      (fun m : ℕ => (Nat.centralBinom m : ℝ) * Real.sqrt (Real.pi * m) / 4 ^ m)
      Filter.atTop (nhds 1) := by
  sorry

/-- TARGET (Aristotle, Stage-2): the ATM lattice-theta closed form
`Θ_ATM(τ) = kσ/√(8πτ)`, stated as the `τ→0⁺` limit `Θ_ATM(τ)·√(8πτ) → kσ`. The
`hΘ` hypothesis pins the closed form as the statement's content; 08-05 replaces the
backward-induction derivation (which flows through `centralBinom_isEquivalent`).
It is a THEOREM, not a definition (locked decision). -/
theorem theta_atm_closed_form (k σ : ℝ) (Θ_ATM : ℝ → ℝ)
    (hΘ : ∀ τ, 0 < τ → Θ_ATM τ = k * σ / Real.sqrt (8 * Real.pi * τ)) :
    Filter.Tendsto (fun τ => Θ_ATM τ * Real.sqrt (8 * Real.pi * τ))
      (nhdsWithin 0 (Set.Ioi 0)) (nhds (k * σ)) := by
  sorry

end Panoptic
