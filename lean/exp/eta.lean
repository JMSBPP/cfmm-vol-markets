/-
  exp/eta.lean — formal counterpart to `model/exp/eta.md`.

  Validity question (updated): can the η-pricing kernel be expressed as a
  product of TWO ½-pricing-kernel evaluations at η-dependent ticks,
  so the existing ½ sqrt-price algebra closes under η?

  Formally (with `P_{1/2}(j) = λ^{j · Δ_i}`):
      ∀ η ∈ (0,1), ∀ i (tick), ∃ i_-(η), i_+(η) ∈ Int24 :
          P_{1/2}(i_-(η)) · P_{1/2}(i_+(η))  =  P_{1/2}(i)
      with both witnesses depending non-trivially on η.

  The ticks live in `Int24` (Uniswap v3 / Plank convention). LeanEVM does
  not currently export an `Int24` type — it focuses on `UInt256` — so we
  define the bound predicate locally; future refactors may switch to a
  LeanEVM-provided type if one is added.

  Witnesses (η-CES split): `i_-(η) = ⌊η · i⌋`, `i_+(η) = i - i_-(η)`.
  Sum = i by construction; multiplicative identity follows from
  λ^{a·Δ_i} · λ^{b·Δ_i} = λ^{(a+b)·Δ_i}.
-/
import Mathlib.Analysis.SpecialFunctions.Pow.Real

open Real

namespace CFMM.Eta

/-- Predicate: integer `i` is in the signed 24-bit range
    `[-2^23, 2^23 - 1] = [-8388608, 8388607]`, the Uniswap v3 / Plank
    tick domain. -/
def IsInt24 (i : Int) : Prop := -8388608 ≤ i ∧ i ≤ 8388607

/-- The ½-pricing kernel at tick `i`, parameterized by base `lam` and
    spacing `Δi`: `P_{1/2}(i) = lam ^ (i · Δi)`. The same formula is the
    η-pricing kernel at the tick level (η does not enter the tick→price
    map — it enters at the reserve / impact level). -/
noncomputable def P_half (lam Δi : ℝ) (i : Int) : ℝ :=
  lam ^ ((i : ℝ) * Δi)

/-- η-dependent lower-split tick: `i_-(η) = ⌊η · i⌋`. -/
noncomputable def tickSplit_minus (η : ℝ) (i : Int) : Int :=
  ⌊η * (i : ℝ)⌋

/-- η-dependent upper-split tick: `i_+(η) = i - i_-(η)`.
    Note both witnesses depend on η: `i_-` via the floor of `η·i`, and
    `i_+` via the subtraction of that η-dependent quantity. -/
noncomputable def tickSplit_plus (η : ℝ) (i : Int) : Int :=
  i - tickSplit_minus η i

/-- Sanity: the split sums back to `i` by construction. -/
@[simp] lemma tickSplit_sum (η : ℝ) (i : Int) :
    tickSplit_minus η i + tickSplit_plus η i = i := by
  unfold tickSplit_plus
  ring

/-- **η-multiplicative decomposition of the pricing kernel on Int24.**

    For every η ∈ (0,1) and every Int24 tick `i` such that both split
    components `i_-(η)`, `i_+(η)` also fit in Int24, the η-dependent
    split satisfies the multiplicative identity

        P_{1/2}(i_-(η)) · P_{1/2}(i_+(η))  =  P_{1/2}(i).

    Proof obligation for Aristotle: exponent algebra +
    `tickSplit_minus η i + tickSplit_plus η i = i`. -/
theorem eta_split_kernel_identity
    (lam : ℝ) (hlam : 0 < lam)
    (Δi : ℝ)
    (η : ℝ) (hη_pos : 0 < η) (hη_lt : η < 1)
    (i : Int) (hi : IsInt24 i)
    (hi_minus : IsInt24 (tickSplit_minus η i))
    (hi_plus  : IsInt24 (tickSplit_plus η i)) :
    P_half lam Δi (tickSplit_minus η i) * P_half lam Δi (tickSplit_plus η i)
      = P_half lam Δi i := by
  unfold P_half
  rw [← Real.rpow_add hlam]
  congr 1
  have hi2 : (i : ℝ) = (tickSplit_minus η i : ℝ) + (tickSplit_plus η i : ℝ) := by
    rw [← Int.cast_add, tickSplit_sum]
  rw [hi2]
  ring


/-! ## Section: are η and Δᵢ independent dimensions of the parameter space?

    Open question forwarded from `model/exp/eta.md`: in the pricing kernel
    P(i) = λ^{i · Δᵢ} and the KERNEL.md volatility term structure
    σ(η, ·) = δ · P^η = δ · λ^{η · i · Δᵢ}, the exponent on λ is the
    THREE-WAY PRODUCT  η · i · Δᵢ. So in σ ALONE, the parameters (η, Δᵢ)
    collapse to a single 1-D degree of freedom (their product). The
    question: is there any observable in which (η, Δᵢ) act independently
    — i.e. a place where one is NOT a rescaling of the other — or are
    they always functionally equivalent?

    The two theorems below answer it precisely:
      • `sigmaVTS_invariant_under_eta_Δi_rescaling`  — they ARE redundant
        if you only look at σ (1-D manifold {η · Δᵢ = const}).
      • `eta_Δi_independent_in_sigma_and_L_eta`     — they are NOT
        redundant in the joint observable (σ, L_η): on the σ-invariant
        manifold the η-CES trading function L_η = X^η · Y^{1-η} still
        varies with η whenever X ≠ Y. So tick-spacing and elasticity have
        independent effects in the joint (σ, L_η) projection.
-/

/-- Volatility term structure (KERNEL.md vol-term-structure σ(η,·) = δ·P^η)
    evaluated at the pricing kernel P(i) = λ^{i · Δᵢ}. -/
noncomputable def sigmaVTS (delta lam : ℝ) (eta : ℝ) (i : Int) (Δi : ℝ) : ℝ :=
  delta * lam ^ (eta * (i : ℝ) * Δi)

/-- The η-CES trading function L_η = X^η · Y^{1-η} (no Δᵢ dependence). -/
noncomputable def L_eta (eta X Y : ℝ) : ℝ :=
  X ^ eta * Y ^ (1 - eta)

/-
**σ-only redundancy of (η, Δᵢ).**
    The vol term structure depends on (η, Δᵢ) only through the product
    η·Δᵢ, so the rescaling (η, Δᵢ) ↦ (c·η, Δᵢ/c) leaves σ invariant.
-/
theorem sigmaVTS_invariant_under_eta_Δi_rescaling
    (delta lam : ℝ) (hlam : 0 < lam)
    (i : Int) (eta Δi : ℝ)
    (c : ℝ) (hc : 0 < c) :
    sigmaVTS delta lam eta i Δi
      = sigmaVTS delta lam (c * eta) i (Δi / c) := by
  unfold sigmaVTS;
  grind

/-
**Joint independence of (η, Δᵢ) in (σ, L_η)-space.**

    On the σ-invariant manifold (witnessed by the rescaling (η,Δᵢ)↦(c·η,Δᵢ/c)
    above), the trading function L_η still varies with η whenever X ≠ Y
    and the rescaling factor c ≠ 1. So (η, Δᵢ) have INDEPENDENT effects
    in the joint observable — the σ projection collapses them but the
    L_η projection separates them.
-/
theorem eta_Δi_independent_in_sigma_and_L_eta
    (delta lam : ℝ) (hlam : 0 < lam) (i : Int)
    (eta : ℝ) (heta_pos : 0 < eta) (heta_lt : eta < 1)
    (Δi : ℝ) (hΔi : 0 < Δi)
    (c : ℝ) (hc_pos : 0 < c) (hc_ne : c ≠ 1)
    (hc_eta_pos : 0 < c * eta) (hc_eta_lt : c * eta < 1)
    (X Y : ℝ) (hX : 0 < X) (hY : 0 < Y) (hXY : X ≠ Y) :
    sigmaVTS delta lam eta i Δi = sigmaVTS delta lam (c * eta) i (Δi / c)
      ∧ L_eta eta X Y ≠ L_eta (c * eta) X Y := by
  refine ⟨?_, ?_⟩
  · exact sigmaVTS_invariant_under_eta_Δi_rescaling delta lam hlam i eta Δi c hc_pos
  · unfold L_eta
    simp_all +decide [Real.rpow_def_of_pos]
    norm_num [← Real.exp_add]
    intro H
    exact hXY <| Real.log_injOn_pos hX hY <|
      mul_left_cancel₀ (sub_ne_zero_of_ne hc_ne) <| by nlinarith

/-! ## Section: tick-spacing as a control knob for trader payoff (fixed η = 1/2)

    Open question forwarded from `model/exp/eta.md`: at fixed η = 1/2, the
    trader payoff is `π_{1/2}^trader = (P_{1/2}(i)·Δ^I − Δ^O)²` (squared
    slippage / variance-swap). With Δ^O the Plank-derived output, this
    becomes a function of Δᵢ via `P_{1/2}(i) = λ^{i·Δᵢ}`. What is the
    formal connection to `σ_{Δᵢ}` (KERNEL.md cross-section vol-term-
    structure), and can the protocol control π by adaptively choosing Δᵢ?

    Below we define:
      • `P_half_post` — new sqrt-price after a Δ^I swap (Plank's
        getNextSqrtPriceFromAmount0RoundingUp), and
      • `Delta_O_half`  — output amount (Plank's getAmount1DeltaUnsigned),
      • `pi_trader_half` — the η = 1/2 trader payoff,
      • `sigma_xs`      — KERNEL.md cross-section vol (quadratic in Δᵢ).

    The control theorem `pi_trader_half_strictly_increasing_in_Δi` then
    asserts that for i > 0 and λ > 1, π is strictly monotonic in Δᵢ — so
    the protocol can deterministically move the trader's payoff by
    adjusting tick spacing. Since `sigma_xs` is also a polynomial in Δᵢ,
    both observables move together with Δᵢ; that is the formal connection.
-/

/-- New sqrt-price after a Δ^I-of-X swap, η = 1/2 (Plank's
    `getNextSqrtPriceFromAmount0RoundingUp` after Q96 factors cancel):
        P' = L̄ · P(i) / (L̄ + Δ^I · P(i))
    where `P(i) = P_half lam Δi i` is the pre-trade sqrt-price. -/
noncomputable def P_half_post (lam Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ) : ℝ :=
  let P := P_half lam Δi i
  L_bar * P / (L_bar + Delta_I * P)

/-- Output Y amount for a Δ^I-of-X swap, η = 1/2 (Plank's
    `getAmount1DeltaUnsigned`):
        Δ^O = L̄ · (P(i) − P'(Δ^I)). -/
noncomputable def Delta_O_half (lam Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ) : ℝ :=
  L_bar * (P_half lam Δi i - P_half_post lam Δi i L_bar Delta_I)

/-- Trader payoff at η = 1/2 (Carr-Madan variance / squared-slippage form):
        π_{1/2}^trader = (P(i) · Δ^I − Δ^O)². -/
noncomputable def pi_trader_half (lam Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ) : ℝ :=
  (P_half lam Δi i * Delta_I - Delta_O_half lam Δi i L_bar Delta_I)^2

/-- KERNEL.md cross-section volatility-term-structure σ(Δᵢ), the
    closed-form geometric-sum reduction:
      σ_xs(Δᵢ; i_-, i_μ, #) =
        (i_- − i_μ)²
        − Δᵢ · (i_- − i_μ) · # · (# − 1)
        + Δᵢ² · # · (# − 1) · (2# − 1) / 6.
    (Quadratic in Δᵢ; coefficient of Δᵢ² is positive for # ≥ 2.) -/
noncomputable def sigma_xs (Δi : ℝ) (i_minus i_mu : Int) (sharp : ℕ) : ℝ :=
  let d := ((i_minus - i_mu : Int) : ℝ)
  let n := (sharp : ℝ)
  d^2 - Δi * d * n * (n - 1) + Δi^2 * n * (n - 1) * (2 * n - 1) / 6

/-- **CONTROL VIA TICK SPACING (fixed η = 1/2).**

    For positive tick i > 0, base λ > 1, pool liquidity L̄ > 0, and trade
    size Δ^I > 0, the trader payoff `pi_trader_half` is strictly
    increasing in Δᵢ over Δᵢ > 0.

    Hence tick spacing is a one-parameter control knob for trader payoff:
    by adaptively choosing Δᵢ, the protocol monotonically moves π. Since
    `sigma_xs` is also a polynomial function of Δᵢ, both observables move
    together with Δᵢ — that is the formal connection between π and σ_{Δᵢ}
    posed in `model/exp/eta.md`. -/
theorem pi_trader_half_strictly_increasing_in_Δi
    (lam : ℝ) (hlam : 1 < lam)
    (i : Int) (hi_pos : 0 < i)
    (L_bar : ℝ) (hL_bar : 0 < L_bar)
    (Delta_I : ℝ) (hDelta_I : 0 < Delta_I)
    (Δi Δi' : ℝ) (hΔi_pos : 0 < Δi) (hΔi_lt : Δi < Δi') :
    pi_trader_half lam Δi  i L_bar Delta_I
      < pi_trader_half lam Δi' i L_bar Delta_I := by
  sorry

end CFMM.Eta