import Mathlib
import vol_markets.PosSpec
import vol_markets.Flow
import vol_markets.Panoptic

open scoped BigOperators
open Real

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# υ (vega) module: finite-difference vega, ΔQ_v dimensional bridge, ATM/OTM conjecture

The vega-like greek `υ ≡ Δπ/Δσ²` of the Panoptic vol-claim (`spec/panoptic.md`,
`# υ IDENTIFICATION`), formalized lattice-first as a finite difference in the
variance argument. The dimensional-bridge lemma pins the spec's load-bearing
claim that υ occupies the same slot as `ΔQ_v = ΔQ_M / p_risk` (`Flow.deltaShares`).

The ATM/OTM null hypothesis — the tick-slope of υ is maximal at the strike tick
`i_K` and exponentially dominated out of the money — is pinned as a `Prop`
VALUE with no proof: the econometric track
(`notes/structural-econometrcics/specs/2026-07-19-panoptic-upsilon-identification.md`,
where it is the parameter test κ > 0) tests it; Lean only fixes the statement.

On the EVM the vega is a Lens read over RAY/X96 accumulators; all quantities
here are over `ℝ` (real-first; EVM-image lemmas are separate, per house style).

Proof status: the two lemmas below were proved by Aristotle (project
`aristotle-panoptic-upsilon`, task 1991ca47) and integrated from the returned
archive, per the phase's Aristotle-heavy workflow.
-/

namespace Upsilon

/-- Vega-like greek υ ≡ Δπ/Δσ² as a lattice finite difference in the variance
argument, for any premium/payoff functional `pl : ℝ → ℝ` of σ². -/
noncomputable def upsilon (pl : ℝ → ℝ) (sig2 Δs : ℝ) : ℝ :=
  (pl (sig2 + Δs) - pl sig2) / Δs

/-- On the region where the vol-option is in-the-money at both endpoints, υ of
π^σ recovers the payoff's ΔQ_v coefficient. -/
lemma upsilon_volOption (dQv sig2 Δs sig2K : ℝ) (hΔ : 0 < Δs)
    (h1 : sig2K ≤ sig2) (h2 : sig2K ≤ sig2 + Δs) :
    upsilon (fun s => Panoptic.volOptionPayoff dQv s sig2K) sig2 Δs = dQv := by
  convert Panoptic.deltaQv_of_payoff dQv sig2 Δs sig2K hΔ h1 h2 using 1

/-- Dimensional bridge: υ occupies the ΔQ_v slot. On the in-the-money region,
υ(π^σ) = `Flow.deltaShares dQv 1` — the same object ΔQ_v = ΔQ_M/p_risk lives in. -/
lemma upsilon_eq_deltaShares_slot (dQv sig2 Δs sig2K : ℝ) (hΔ : 0 < Δs)
    (h1 : sig2K ≤ sig2) (h2 : sig2K ≤ sig2 + Δs) :
    upsilon (fun s => Panoptic.volOptionPayoff dQv s sig2K) sig2 Δs
      = Flow.deltaShares dQv 1 := by
  convert upsilon_volOption dQv sig2 Δs sig2K hΔ h1 h2 using 1;
  unfold Flow.deltaShares; norm_num;

/-! ## ATM/OTM null hypothesis (Prop conjecture — no proof, no axiom) -/

/-- The tick-slope of υ at tick index `i`: `(Δυ/Δi)(i) = (υ(i+1) − υ(i)) / Δi`. -/
noncomputable def upsilonTickSlope (υfun : ℤ → ℝ) (Δi : ℝ) (i : ℤ) : ℝ :=
  (υfun (i + 1) - υfun i) / Δi

/-- NULL HYPOTHESIS (Prop conjecture, no proof — tested by the econometric track).
At the strike tick `i_K` the |tick-slope of υ| is maximal (ATM peak) and, for a
decay rate `c > 0`, dominated by an exponentially decreasing envelope in
tick-distance from `i_K` (OTM exponential decay). Lean pins the statement; it is
NOT proved here. -/
def ATMOTMNullHypothesis (υfun : ℤ → ℝ) (Δi : ℝ) (iK : ℤ) (c : ℝ) : Prop :=
  (0 < c) ∧
  (∀ i : ℤ, |upsilonTickSlope υfun Δi i| ≤ |upsilonTickSlope υfun Δi iK|) ∧
  (∀ i : ℤ, |upsilonTickSlope υfun Δi i|
      ≤ |upsilonTickSlope υfun Δi iK| * Real.exp (-c * |(i : ℝ) - (iK : ℝ)|))

end Upsilon
