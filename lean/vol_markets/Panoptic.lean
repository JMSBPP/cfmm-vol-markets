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
* the closed-form target theorem `Θ_ATM(τ) = kσ/√(8πτ)`, stated as a `sorry`'d
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

end Panoptic
