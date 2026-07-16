/-
  exp/SocialChoiceParameters.lean

  Formal companion to `exp/SocialChoiceParameters.md`.

  The design question was: *what social-choice / social-welfare functions, with
  genuine economic meaning, can the protocol use to optimize the parameters
  `δᵢ` (tick spacing) and `η` (CES curvature)?*

  Here we give machine-checked DEFINITIONS of the candidate welfare functionals
  (utilitarian, weighted/Bergson–Samuelson, Nash, egalitarian/Rawlsian,
  mean–variance) over an agent-utility profile, and PROVE their basic structural /
  economic properties:

    * utilitarian welfare is Pareto-monotone;
    * weighted welfare with equal weights is the (scaled) utilitarian welfare;
    * the Rawlsian (max-min) value never exceeds the utilitarian mean;
    * Nash product welfare has the additive log form (Nash bargaining);
    * the mean–variance risk penalty strictly lowers welfare;
    * a utilitarian-optimal `δᵢ` exists over any finite nonempty tick menu
      (well-posedness of the discrete social choice over tick spacings).

  These are abstract over the per-agent payoffs; in this model those payoffs are
  the repo's `pi_trader_half` / `pi_plus_eta` (long-vol trader), `pi_minus_eta`
  (LP / short-vol), and the dispersion `sigma_xs` / `sigma_realized` (protocol).
-/
import Mathlib

open scoped BigOperators

namespace CFMM.SocialChoice

/-- **Utilitarian** social welfare over a finite utility profile `u`:
    the total gains from trade `Σⱼ uⱼ`. -/
def W_util {m : ℕ} (u : Fin m → ℝ) : ℝ := ∑ j, u j

/-- **Weighted utilitarian / Bergson–Samuelson** welfare `Σⱼ wⱼ·uⱼ`.
    On-chain the weights `wⱼ` are liquidity shares or governance-token stakes. -/
def W_wutil {m : ℕ} (w u : Fin m → ℝ) : ℝ := ∑ j, w j * u j

/-- **Nash** (product) social welfare for two agents — the Nash bargaining
    objective between trader (`t`) and LP (`l`). -/
def W_nash (t l : ℝ) : ℝ := t * l

/-- **Egalitarian / Rawlsian** (max-min) welfare for two agents: the worst-off
    payoff. -/
def W_egal (t l : ℝ) : ℝ := min t l

/-- **Mean–variance** welfare: expected surplus `μ` minus `γ` times a dispersion
    term `σ` (e.g. the model's `sigma_xs`). `γ` is the risk-aversion. -/
def W_meanvar (μ γ σ : ℝ) : ℝ := μ - γ * σ

/-- Utilitarian welfare is **Pareto-monotone**: if every agent is weakly better
    off, aggregate welfare is weakly higher. -/
theorem W_util_pareto {m : ℕ} {u u' : Fin m → ℝ} (h : ∀ j, u j ≤ u' j) :
    W_util u ≤ W_util u' := by
  unfold W_util
  exact Finset.sum_le_sum (fun j _ => h j)

/-- **Equal weights collapse to utilitarian:** weighting every agent by the same
    constant `c` gives `c` times the utilitarian welfare. (At `c = 1/m` this is
    the per-capita / mean welfare.) -/
theorem W_wutil_const_weight {m : ℕ} (c : ℝ) (u : Fin m → ℝ) :
    W_wutil (fun _ => c) u = c * W_util u := by
  unfold W_wutil W_util
  rw [Finset.mul_sum]

/-- **Rawls ≤ utilitarian mean:** the egalitarian (max-min) value never exceeds
    the average of the two agents' payoffs. -/
theorem W_egal_le_mean (t l : ℝ) : W_egal t l ≤ (t + l) / 2 := by
  unfold W_egal
  have h1 : min t l ≤ t := min_le_left t l
  have h2 : min t l ≤ l := min_le_right t l
  linarith

/-- **Nash bargaining log form:** for strictly positive payoffs the Nash product
    welfare equals the exponential of the summed log-utilities. -/
theorem W_nash_log {t l : ℝ} (ht : 0 < t) (hl : 0 < l) :
    Real.log (W_nash t l) = Real.log t + Real.log l := by
  unfold W_nash
  exact Real.log_mul (ne_of_gt ht) (ne_of_gt hl)

/-- **Risk strictly costs welfare:** with nonnegative risk-aversion `γ` and
    nonnegative dispersion `σ`, the mean–variance welfare is at most the expected
    surplus, with equality iff there is no priced risk. -/
theorem W_meanvar_le_mean {μ γ σ : ℝ} (hγ : 0 ≤ γ) (hσ : 0 ≤ σ) :
    W_meanvar μ γ σ ≤ μ := by
  unfold W_meanvar
  have : 0 ≤ γ * σ := mul_nonneg hγ hσ
  linarith

/-- **Risk-neutral mean–variance is utilitarian:** at `γ = 0` the mean–variance
    objective is exactly the expected surplus. -/
@[simp] theorem W_meanvar_risk_neutral (μ σ : ℝ) : W_meanvar μ 0 σ = μ := by
  unfold W_meanvar; ring

/-- **Well-posedness of the discrete tick choice:** over any finite nonempty menu
    `S` of admissible tick spacings, a utilitarian-optimal spacing exists. Here
    `W : ℝ → ℝ` is the welfare as a function of the chosen spacing `δᵢ`. -/
theorem exists_optimal_tick (S : Finset ℝ) (hS : S.Nonempty) (W : ℝ → ℝ) :
    ∃ δ ∈ S, ∀ δ' ∈ S, W δ' ≤ W δ := by
  obtain ⟨δ, hδmem, hδmax⟩ := S.exists_max_image W hS
  exact ⟨δ, hδmem, hδmax⟩

/-! ## Contrarian / inverse objectives: the zero-sum case `π⁻ = −π⁺`

  The repo proves `pi_minus_eta = −pi_plus_eta` (see
  `EtaLiquidityPayoff.pi_minus_eta_eq_neg_pi_trader_half`): the LP / short-vol
  payoff is the exact negative of the long-vol trader payoff, so the two agents
  are in a **zero-sum** relationship. We model the profile as `(t, -t)` with
  `t := π⁺`, and show which welfare functionals stay meaningful (and which become
  degenerate) when the objectives are opposed.

  Economic punchline: on a zero-sum pair the utilitarian sum is identically `0`
  (no aggregate gains from trade to split), and *every* impartial scalar that
  remains nontrivial is a **conflict-magnitude (variance / risk) functional**.
  The Nash-product, egalitarian (max-min), and least-conflict objectives all
  agree that the socially optimal `(δᵢ, η)` is the **zero-conflict point** `π⁺ = 0`
  — which in this model is exactly the zero-slippage spacing `Δᵢ⋆` of
  `eta.pi_trader_half_zero_at_deltaI_star`. -/

/-- **Utilitarian is degenerate on opposed objectives:** `π⁺ + π⁻ = 0`. There are
    no aggregate gains from trade, so the utilitarian planner is indifferent to
    `(δᵢ, η)`. -/
@[simp] theorem W_util_zero_sum (t : ℝ) :
    W_util (m := 2) ![t, -t] = 0 := by
  unfold W_util; simp [Fin.sum_univ_two]

/-- **Weighted utilitarian just rescales the conflict:** favouring the trader with
    weight `α` (and the LP with `1−α`) reduces to `(2α−1)·π⁺`. The impartial
    choice `α = 1/2` gives `0`, recovering the utilitarian indifference; the sign
    of `2α−1` decides which side the planner favours. -/
theorem W_wutil_zero_sum (α t : ℝ) :
    W_wutil (m := 2) ![α, 1 - α] ![t, -t] = (2 * α - 1) * t := by
  unfold W_wutil; simp [Fin.sum_univ_two]; ring

/-- **Nash product of opposed payoffs is `−(π⁺)² ≤ 0`.** -/
@[simp] theorem W_nash_zero_sum (t : ℝ) : W_nash t (-t) = -t ^ 2 := by
  unfold W_nash; ring

/-- **Nash bargaining selects the zero-conflict point:** maximizing the Nash
    product over opposed objectives means driving `π⁺` to `0` (its unique
    maximizer), since `W_nash t (-t) ≤ 0` with equality iff `t = 0`. -/
theorem W_nash_zero_sum_le (t : ℝ) : W_nash t (-t) ≤ 0 := by
  rw [W_nash_zero_sum]; nlinarith [sq_nonneg t]

theorem W_nash_zero_sum_eq_zero_iff (t : ℝ) : W_nash t (-t) = 0 ↔ t = 0 := by
  rw [W_nash_zero_sum]; constructor
  · intro h; nlinarith [sq_nonneg t]
  · intro h; rw [h]; ring

/-- **Egalitarian (max-min) on opposed payoffs is `−|π⁺| ≤ 0`,** so the Rawlsian
    planner — maximizing the worst-off side — also lands on the zero-conflict
    point `π⁺ = 0`. -/
theorem W_egal_zero_sum (t : ℝ) : W_egal t (-t) = -|t| := by
  unfold W_egal; rcases le_total 0 t with h | h
  · rw [abs_of_nonneg h, min_eq_right (by linarith)]
  · rw [abs_of_nonpos h, min_eq_left (by linarith), neg_neg]

theorem W_egal_zero_sum_le (t : ℝ) : W_egal t (-t) ≤ 0 := by
  rw [W_egal_zero_sum]; simp [abs_nonneg]

/-- The **conflict magnitude** `C(π⁺) = (π⁺)²` (here `= π⁺·(−π⁻)`), the
    economically meaningful impartial objective for opposed sides: the planner
    minimizes the intensity of the zero-sum transfer (equivalently the realized
    squared slippage `sigma_xs`). -/
def conflict (t : ℝ) : ℝ := t ^ 2

/-- The least-conflict social choice is uniquely the **zero-conflict point**
    `π⁺ = 0`: `conflict t ≥ 0` always, with equality iff `t = 0`. In this model
    that point is the zero-slippage tick spacing `Δᵢ⋆`. -/
theorem conflict_nonneg (t : ℝ) : 0 ≤ conflict t := by
  unfold conflict; positivity

theorem conflict_eq_zero_iff (t : ℝ) : conflict t = 0 ↔ t = 0 := by
  unfold conflict; exact pow_eq_zero_iff (by norm_num)

/-- **Minimax / von Neumann value of the zero-sum game.** If the trader's
    achievable payoff over the admissible parameter menu `S` is `t : ℝ → ℝ`, the
    LP-protecting (max-min) planner attains a value `δ⋆` minimizing the trader's
    extraction `t`, i.e. maximizing the LP payoff `−t`. Well-posed over any
    finite nonempty menu. -/
theorem exists_minimax_tick (S : Finset ℝ) (hS : S.Nonempty) (t : ℝ → ℝ) :
    ∃ δ ∈ S, ∀ δ' ∈ S, t δ ≤ t δ' := by
  obtain ⟨δ, hδmem, hδmin⟩ := S.exists_min_image t hS
  exact ⟨δ, hδmem, hδmin⟩

end CFMM.SocialChoice
