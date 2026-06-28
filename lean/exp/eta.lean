/-
  exp/eta.lean — formal counterpart to `model/exp/eta.md`.

  Validity question (from the markdown spec): can the η-CES price-impact
  function be reproduced as a finite ℝ-linear combination of ½-CES (Uniswap v3)
  price-impact evaluations, so that the existing sqrt-price algebra
  (e.g. `getNextSqrtPriceFromAmount0RoundingUp`) can be reused for generic η?

  This file states the simplest formal refutation: even the single-coefficient
  case (which subsumes every fixed finite linear combination evaluated at the
  same trade state) fails for any η ≠ 1/2.

  Source math (model/exp/eta.md):
    P_new / P_old  =  (X / (X + Δx))^{1/(1-η)}      -- η-CES impact
    P_new / P_old  =  (X / (X + Δx))^{2}            -- η = 1/2 (sqrt-price)
-/
import Mathlib.Analysis.SpecialFunctions.Pow.Real

open Real

namespace CFMM.Eta

/-- η-CES marginal-price-impact ratio after selling `Δx` of token X into a pool
    with reserve `X`. The exponent `1/(1-η)` is the η-CES curvature. -/
noncomputable def impactEta (η X Δx : ℝ) : ℝ :=
  (X / (X + Δx)) ^ (1 / (1 - η))

/-- ½-CES (constant-product / Uniswap v3 sqrt-price) impact ratio.
    Specialization of `impactEta` at η = 1/2 (exponent collapses to 2). -/
noncomputable def impactHalf (X Δx : ℝ) : ℝ :=
  (X / (X + Δx)) ^ (2 : ℝ)

/-- **Refutation of the linear-combination-of-½ proposal.**

    There is no real constant `C` such that the η-CES impact equals
    `C · (½-CES impact)` identically in `(X, Δx)` for η ≠ 1/2.

    Why this kills the broader proposal: any finite sum
    `Σ_k ζ_k · impactHalf X Δx` of ½-impacts evaluated at the *same* trade
    state collapses to a single scalar `(Σ_k ζ_k) · impactHalf X Δx`, i.e. the
    constant-`C` case below. So if `C` does not exist, neither does any such
    state-aligned linear combination.

    Proof sketch (for the prover): evaluating the proposed identity at two
    distinct trade states (e.g. u = Δx/(X+Δx) ∈ {1/2, 3/4}) gives two equations
    in `C` that force `1/(1-η) = 2`, i.e. η = 1/2, contradicting `hη_ne`. -/
theorem eta_impact_not_constant_scaling_of_half
    (η : ℝ) (hη_pos : 0 < η) (hη_lt : η < 1) (hη_ne : η ≠ (1 : ℝ) / 2) :
    ¬ ∃ C : ℝ, ∀ X Δx : ℝ, 0 < X → 0 < Δx →
      impactEta η X Δx = C * impactHalf X Δx := by
  sorry

end CFMM.Eta
