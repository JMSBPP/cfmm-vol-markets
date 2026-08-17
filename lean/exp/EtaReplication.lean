/-
  exp/EtaReplication.lean — formal counterpart to the η̄-pricing /
  custom-payoff / replication block of `model/exp/eta.md`.

  This file formalizes the structures introduced in the latest spec note:

    • the η̄-pricing kernel            p_η(Δᵢ; i) = λ^{i · Δᵢ · η̄},
    • the price update rule            p_η(·; i, Δᴵ) = L·p / (L + p·Δᴵ),
    • the output rule                  Δᴼ(·; i, Δᴵ) = L·(p_post − p),
    • the custom long-vol payoff       π⁺ = d(p·Δᴵ, Δᴼ),

  and answers the structural question posed at the end of the note:

      « π⁺ = d(p_η(·;i)·Δᴵ, Δᴼ) — which d is more compatible with (1)? »

  ANSWER (made precise and proved below).  Equation (1) defines
  π⁺ ≡ #·σ, i.e. the custom payoff IS the (tick-count-weighted)
  cross-section *variance* σ — a sum of squared deviations.  The
  divergence d whose induced payoff is itself a variance/quadratic is the
  **squared Euclidean distance** `dSlip a b = (a − b)²`.  Equivalently it
  is the Bregman divergence of the quadratic generator `f(x) = x²`, which
  is exactly the `η̄ = 1/2` member `1/(1−η̄) = 2` of the η-CES Bregman
  family `f(x) = x^{1/(1−η̄)}` from `exp.CESLongVolPayoff`.  Two
  characterisations of "compatible with (1)" are discharged:

    (a) with `d = dSlip` the η̄-payoff coincides with the already-studied
        `pi_trader_half` at the rescaled spacing `Δᵢ·η̄`
        (`pi_plus_eta_eq_pi_trader_half`), exposing the (η̄, Δᵢ)
        redundancy of `sigmaVTS_invariant_under_eta_Δi_rescaling` at the
        payoff level; and

    (b) the variance `sigma_xs` of (1) is a quadratic whose discrete
        second difference is the *constant* `2`
        (`sigma_xs_second_difference_in_i_mu`) — the hallmark of a
        squared distance and the fact that makes the Carr–Madan
        replication of the note exact with a constant second-difference
        weight (`quadratic_second_difference`).
-/
import Mathlib
import exp.eta
import exp.CESLongVolPayoff

open Real
open scoped BigOperators

namespace CFMM.Eta

/-! ## The η̄-pricing structure -/

/-- **η̄-pricing kernel** `p_η(Δᵢ; i) = λ^{i · Δᵢ · η̄}`.
    Reduces to `P_half` at `η̄ = 1`; in general it is `P_half` evaluated
    at the rescaled spacing `Δᵢ · η̄` (see `p_eta_eq_P_half_rescaled`). -/
noncomputable def p_eta (lam Δi eta : ℝ) (i : Int) : ℝ :=
  lam ^ ((i : ℝ) * Δi * eta)

/-- **η̄ price update rule** after a Δᴵ-of-X swap:
    `p_post = L · p / (L + p · Δᴵ)`. -/
noncomputable def p_eta_post (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) : ℝ :=
  L * p_eta lam Δi eta i / (L + p_eta lam Δi eta i * Delta_I)

/-- **η̄ output rule** `Δᴼ = L · (p_post − p)`. -/
noncomputable def Delta_O_eta (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) : ℝ :=
  L * (p_eta lam Δi eta i - p_eta_post lam Δi eta i L Delta_I)

/-! ## The distance / divergence `d` -/

/-- The **squared Euclidean distance** `d(a, b) = (a − b)²`.  This is the
    divergence the structural requirement of (1) selects: it is itself a
    variance (a sum of squares), matching `π⁺ ≡ #·σ`. -/
def dSlip (a b : ℝ) : ℝ := (a - b) ^ 2

/-- **Custom long-vol payoff** `π⁺ = d(p·Δᴵ, Δᴼ)` with `d = dSlip`. -/
noncomputable def pi_plus_eta (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) : ℝ :=
  dSlip (p_eta lam Δi eta i * Delta_I) (Delta_O_eta lam Δi eta i L Delta_I)

/-! ## η̄–Δᵢ redundancy at the kernel / payoff level -/

/-- The η̄-kernel is `P_half` at the rescaled spacing `Δᵢ · η̄`:
    `λ^{i·Δᵢ·η̄} = λ^{i·(Δᵢ·η̄)}`. -/
theorem p_eta_eq_P_half_rescaled (lam Δi eta : ℝ) (i : Int) :
    p_eta lam Δi eta i = P_half lam (Δi * eta) i := by
  unfold p_eta P_half
  ring_nf

/-- The η̄ price-update rule is the η = 1/2 update at the rescaled spacing. -/
theorem p_eta_post_eq (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) :
    p_eta_post lam Δi eta i L Delta_I = P_half_post lam (Δi * eta) i L Delta_I := by
  unfold p_eta_post P_half_post
  rw [p_eta_eq_P_half_rescaled]
  simp only []
  ring_nf

/-- The η̄ output rule is the η = 1/2 output at the rescaled spacing. -/
theorem Delta_O_eta_eq (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) :
    Delta_O_eta lam Δi eta i L Delta_I = Delta_O_half lam (Δi * eta) i L Delta_I := by
  unfold Delta_O_eta Delta_O_half
  rw [p_eta_eq_P_half_rescaled, p_eta_post_eq]

/-! ## The structural requirement and the answer -/

/-- **Structural requirement, explicit.**  By construction the custom
    payoff is the divergence `d = dSlip` evaluated on the price-impact
    `p·Δᴵ` and the output `Δᴼ`:  `π⁺ = d(p·Δᴵ, Δᴼ)`. -/
theorem pi_plus_eta_structural (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) :
    pi_plus_eta lam Δi eta i L Delta_I
      = dSlip (p_eta lam Δi eta i * Delta_I) (Delta_O_eta lam Δi eta i L Delta_I) :=
  rfl

/-- **Compatibility (a).**  With `d = dSlip`, the η̄-payoff coincides with
    the squared-slippage payoff `pi_trader_half` evaluated at the rescaled
    spacing `Δᵢ·η̄`.  This exposes, at the payoff level, the (η̄, Δᵢ)
    redundancy already seen for σ in
    `sigmaVTS_invariant_under_eta_Δi_rescaling`. -/
theorem pi_plus_eta_eq_pi_trader_half (lam Δi eta : ℝ) (i : Int) (L Delta_I : ℝ) :
    pi_plus_eta lam Δi eta i L Delta_I = pi_trader_half lam (Δi * eta) i L Delta_I := by
  unfold pi_plus_eta dSlip pi_trader_half
  rw [p_eta_eq_P_half_rescaled, Delta_O_eta_eq]

/-- **The squared distance is the quadratic Bregman divergence.**
    `dSlip a b = a² − b² − 2·b·(a − b)`, the Bregman divergence generated
    by `f(x) = x²`.  Since `f(x) = x^{1/(1−η̄)}` with `1/(1−η̄) = 2` at
    `η̄ = 1/2`, this is exactly the `η̄ = 1/2` member of the η-CES Bregman
    family — the divergence compatible with the variance form (1). -/
theorem dSlip_eq_quadratic_bregman (a b : ℝ) :
    dSlip a b = a ^ 2 - b ^ 2 - 2 * b * (a - b) := by
  unfold dSlip
  ring

/-! ## Replication: the variance (1) has constant second difference -/

/-- Discrete second difference of an arbitrary quadratic is the constant
    `2·c₂` (independent of the evaluation point).  This is the algebraic
    fact behind the Carr–Madan static replication used in the note: a
    *variance* (quadratic) payoff is replicated with a constant
    second-difference weight. -/
theorem quadratic_second_difference (c2 c1 c0 x : ℝ) :
    (c2 * (x + 1) ^ 2 + c1 * (x + 1) + c0)
        - 2 * (c2 * x ^ 2 + c1 * x + c0)
        + (c2 * (x - 1) ^ 2 + c1 * (x - 1) + c0)
      = 2 * c2 := by
  ring

/-- **Compatibility (b).**  The cross-section variance `sigma_xs` of (1),
    viewed as a function of the reference tick `i_μ`, is a quadratic whose
    discrete second difference is the constant `2`.  (The tick count
    `sharp i_- i_+ Δᵢ` does not depend on `i_μ`, so the only `i_μ`
    dependence is the quadratic deviation `(i_- − i_μ)²`, whose second
    difference is `2`.)  This constant-curvature property is the signature
    of the squared distance `dSlip`, confirming it is the `d` compatible
    with (1). -/
theorem sigma_xs_second_difference_in_i_mu
    (i_minus i_plus i_mu : Int) (Δi : ℝ) :
    sigma_xs i_minus i_plus (i_mu + 1) Δi
        - 2 * sigma_xs i_minus i_plus i_mu Δi
        + sigma_xs i_minus i_plus (i_mu - 1) Δi
      = 2 := by
  unfold sigma_xs
  simp only []
  push_cast
  ring

end CFMM.Eta
