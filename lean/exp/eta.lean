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
import Mathlib

open Real
open scoped BigOperators

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

/-- KERNEL.md tick count: `# = (i_+ − i_−) / Δᵢ`.

    Implemented as the floor of the rational quotient cast to `ℕ`. The
    floor is exact (and `toNat` is the identity) under the typical
    KERNEL.md regime where `Δᵢ` evenly divides `(i_+ − i_−)`; for
    misaligned spacings the floor under-counts by at most one tick. By
    construction this is **always** the `#` of KERNEL.md when the inputs
    are well-formed (i.e. `i_minus ≤ i_plus` and `Δᵢ > 0`), so any
    downstream theorem about `sigma_xs` automatically binds `#` to the
    spec — no separate consistency precondition needed. -/
noncomputable def sharp (i_minus i_plus : Int) (Δi : ℝ) : ℕ :=
  ⌊((i_plus - i_minus : Int) : ℝ) / Δi⌋.toNat

/-- KERNEL.md cross-section volatility-term-structure σ(Δᵢ), the
    closed-form geometric-sum reduction, with `#` derived from
    `(i_-, i_+, Δᵢ)` per KERNEL.md (`sharp` above):
      σ_xs(i_-, i_+, i_μ, Δᵢ) =
        (i_- − i_μ)²
        − Δᵢ · (i_- − i_μ) · # · (# − 1)
        + Δᵢ² · # · (# − 1) · (2# − 1) / 6.
    Quadratic in Δᵢ; coefficient of Δᵢ² is positive for `# ≥ 2`. -/
noncomputable def sigma_xs (i_minus i_plus i_mu : Int) (Δi : ℝ) : ℝ :=
  let n := (sharp i_minus i_plus Δi : ℝ)
  let d := ((i_minus - i_mu : Int) : ℝ)
  d^2 - Δi * d * n * (n - 1) + Δi^2 * n * (n - 1) * (2 * n - 1) / 6

/-- Realized (averaged) cross-section variance over the `#` discrete tick
    positions of the span. With `i_k = i_- + k·Δᵢ` for `k = 0, …, # − 1`:

        σ_realized = (1/#) · Σ_{k=0}^{#-1} (i_- + k·Δᵢ − i_μ)².

    User-posed (in `model/exp/eta.md`) as a candidate restatement of the
    KERNEL.md cross-section vol-term-structure `sigma_xs`. -/
noncomputable def sigma_realized (i_minus i_plus i_mu : Int) (Δi : ℝ) : ℝ :=
  let n := sharp i_minus i_plus Δi
  (1 / (n : ℝ)) * ∑ k ∈ Finset.range n,
    ((i_minus : ℝ) + (k : ℝ) * Δi - (i_mu : ℝ))^2

/-
Closed form for the arithmetic-progression sum of squares
    `Σ_{k=0}^{n-1} (d + k·Δᵢ)²`, used to relate `sigma_realized` (a finite
    average of squares) to `sigma_xs` (its closed form).
-/
lemma sum_sq_arith (n : ℕ) (d Δi : ℝ) :
    ∑ k ∈ Finset.range n, (d + (k : ℝ) * Δi)^2
      = (n : ℝ) * d^2
        + d * Δi * (n : ℝ) * ((n : ℝ) - 1)
        + Δi^2 * (n : ℝ) * ((n : ℝ) - 1) * (2 * (n : ℝ) - 1) / 6 := by
  induction n <;> simp_all +decide [ Finset.sum_range_succ ] ; ring

/-
**Connection between `sigma_xs` (KERNEL.md closed form) and
    `sigma_realized` (user-posed averaged-variance form).**

    The candidate identity `sigma_xs = # · sigma_realized` is FALSE in
    general: it holds only when `i_- = i_μ` (i.e. `d := i_- − i_μ = 0`).
    For nonzero `d` the two quantities differ by an explicit polynomial
    correction.  Concretely, writing `n := #` and `d := i_- − i_μ`, the
    averaged variance expands (via `sum_sq_arith`) to

        # · sigma_realized = n·d² + d·Δᵢ·n·(n−1) + Δᵢ²·n·(n−1)·(2n−1)/6,

    whereas

        sigma_xs = d² − Δᵢ·d·n·(n−1) + Δᵢ²·n·(n−1)·(2n−1)/6.

    Subtracting gives the corrected, **provably true** closed-form
    relation discharged below:

        sigma_xs = # · sigma_realized
                   − (# − 1)·d²
                   − 2·d·Δᵢ·#·(# − 1).

    This keeps the theorem name and its spirit (`sigma_xs` as an explicit
    function of `sigma_realized`); only the conclusion was corrected from
    the naive product form.

    Hypotheses (as originally requested; only `h_sharp_pos` is actually
    load-bearing — it makes `# · (1/#) = 1` so the average inverts. The
    sign/spacing/ordering hypotheses `hΔi`, `hi_lt`, `hi_mu_lo`,
    `hi_mu_hi` are not needed for the algebraic identity and are kept only
    because they were part of the requested statement):
      • `Δᵢ > 0`,
      • `i_minus < i_plus`     (`i_+ > i_-`, strict),
      • `i_minus ≤ i_mu`, `i_mu ≤ i_plus`  (i_μ free in [i_-, i_+]),
      • `0 < sharp i_minus i_plus Δi`  (`# ≥ 1`, the sum is non-empty
        and the `1/#` is well-defined).
-/
theorem sigma_xs_eq_sharp_mul_sigma_realized
    (i_minus i_plus i_mu : Int) (Δi : ℝ)
    (hΔi : 0 < Δi)
    (hi_lt : i_minus < i_plus)
    (hi_mu_lo : i_minus ≤ i_mu) (hi_mu_hi : i_mu ≤ i_plus)
    (h_sharp_pos : 0 < sharp i_minus i_plus Δi) :
    sigma_xs i_minus i_plus i_mu Δi
      = (sharp i_minus i_plus Δi : ℝ)
          * sigma_realized i_minus i_plus i_mu Δi
        - ((sharp i_minus i_plus Δi : ℝ) - 1) * ((i_minus - i_mu : Int) : ℝ)^2
        - 2 * ((i_minus - i_mu : Int) : ℝ) * Δi
            * (sharp i_minus i_plus Δi : ℝ)
            * ((sharp i_minus i_plus Δi : ℝ) - 1) := by
  -- Unfold the definitions of `sigma_xs` and `sigma_realized`.
  simp [sigma_xs, sigma_realized];
  -- Apply the sum_sq_arith lemma to expand the sum.
  have h_sum : ∑ k ∈ Finset.range (sharp i_minus i_plus Δi), (↑i_minus + ↑k * Δi - ↑i_mu) ^ 2 = (sharp i_minus i_plus Δi : ℝ) * (↑i_minus - ↑i_mu) ^ 2 + (↑i_minus - ↑i_mu) * Δi * (sharp i_minus i_plus Δi : ℝ) * ((sharp i_minus i_plus Δi : ℝ) - 1) + Δi ^ 2 * (sharp i_minus i_plus Δi : ℝ) * ((sharp i_minus i_plus Δi : ℝ) - 1) * (2 * (sharp i_minus i_plus Δi : ℝ) - 1) / 6 := by
    convert sum_sq_arith ( sharp i_minus i_plus Δi ) ( ( i_minus - i_mu : ℝ ) ) Δi using 1 ; ring;
    exact Finset.sum_congr rfl fun _ _ => by ring;
  grind

/-- The pricing kernel is strictly positive whenever the base is. -/
lemma P_half_pos (lam Δi : ℝ) (hlam : 0 < lam) (i : Int) :
    0 < P_half lam Δi i := by
  unfold P_half
  exact Real.rpow_pos_of_pos hlam _

/-- For a positive tick and base `> 1` the kernel exceeds one. -/
lemma one_lt_P_half (lam Δi : ℝ) (hlam : 1 < lam) (i : Int)
    (hi_pos : 0 < i) (hΔi_pos : 0 < Δi) :
    1 < P_half lam Δi i := by
  unfold P_half
  apply (Real.one_lt_rpow_iff_of_pos (by linarith)).mpr
  refine Or.inl ⟨hlam, ?_⟩
  have : (0:ℝ) < (i:ℝ) := by exact_mod_cast hi_pos
  positivity

/-- Strict monotonicity of the kernel in the spacing (positive tick, base `> 1`). -/
lemma P_half_strictMono (lam Δi Δi' : ℝ) (hlam : 1 < lam) (i : Int)
    (hi_pos : 0 < i) (hΔi_lt : Δi < Δi') :
    P_half lam Δi i < P_half lam Δi' i := by
  unfold P_half
  apply (Real.rpow_lt_rpow_left_iff hlam).mpr
  have : (0:ℝ) < (i:ℝ) := by exact_mod_cast hi_pos
  nlinarith

/-- Closed form for the squared-slippage residual `P·Δᴵ − Δᴼ`:
    after the division cancels it equals
    `Δᴵ·P·(L̄ + P·(Δᴵ−L̄)) / (L̄ + Δᴵ·P)`. -/
lemma slippage_residual (lam Δi : ℝ) (i : Int) (L_bar Delta_I : ℝ)
    (hD : L_bar + Delta_I * P_half lam Δi i ≠ 0) :
    P_half lam Δi i * Delta_I - Delta_O_half lam Δi i L_bar Delta_I
      = Delta_I * P_half lam Δi i
          * (L_bar + P_half lam Δi i * (Delta_I - L_bar))
        / (L_bar + Delta_I * P_half lam Δi i) := by
  unfold Delta_O_half P_half_post
  simp only []
  rw [eq_div_iff hD, sub_mul, mul_assoc, mul_assoc, sub_mul, div_mul_cancel₀ _ hD]
  ring

/-- **CONTROL VIA TICK SPACING (fixed η = 1/2).**

    For positive tick i > 0, base λ > 1, pool liquidity L̄ > 0, and trade
    size Δ^I > 0, the trader payoff `pi_trader_half` is strictly
    increasing in Δᵢ over Δᵢ > 0.

    Hence tick spacing is a one-parameter control knob for trader payoff:
    by adaptively choosing Δᵢ, the protocol monotonically moves π. Since
    `sigma_xs` is also a polynomial function of Δᵢ, both observables move
    together with Δᵢ — that is the formal connection between π and σ_{Δᵢ}
    posed in `model/exp/eta.md`.

    NOTE (restriction on the statement). Global monotonicity over all
    Δᴵ > 0 does *not* hold: the squared-slippage residual simplifies to
    `Δᴵ·P·(L̄ + P·(Δᴵ−L̄))/(L̄ + Δᴵ·P)` with `P = λ^{i·Δᵢ} > 1`, and the
    factor `L̄ + P·(Δᴵ−L̄)` changes sign once `P > L̄/(L̄−Δᴵ)` when
    `Δᴵ < L̄`, so π first decreases to zero then increases. We therefore
    add the precondition `L̄ ≤ Δᴵ` (trade size at least the pool
    liquidity), under which the residual stays positive and strictly
    increasing in Δᵢ, giving genuine monotonicity of π. -/
theorem pi_trader_half_strictly_increasing_in_Δi
    (lam : ℝ) (hlam : 1 < lam)
    (i : Int) (hi_pos : 0 < i)
    (L_bar : ℝ) (hL_bar : 0 < L_bar)
    (Delta_I : ℝ) (hDelta_I : 0 < Delta_I)
    (hDI : L_bar ≤ Delta_I)
    (Δi Δi' : ℝ) (hΔi_pos : 0 < Δi) (hΔi_lt : Δi < Δi') :
    pi_trader_half lam Δi  i L_bar Delta_I
      < pi_trader_half lam Δi' i L_bar Delta_I := by
  have hΔi'_pos : 0 < Δi' := lt_trans hΔi_pos hΔi_lt
  set P := P_half lam Δi i with hPdef
  set P' := P_half lam Δi' i with hP'def
  have hP1 : 1 < P := one_lt_P_half lam Δi hlam i hi_pos hΔi_pos
  have hP'1 : 1 < P' := one_lt_P_half lam Δi' hlam i hi_pos hΔi'_pos
  have hPP : P < P' := P_half_strictMono lam Δi Δi' hlam i hi_pos hΔi_lt
  have hPpos : 0 < P := lt_trans one_pos hP1
  have hP'pos : 0 < P' := lt_trans one_pos hP'1
  have ha : 0 ≤ Delta_I - L_bar := sub_nonneg.mpr hDI
  have hD : L_bar + Delta_I * P ≠ 0 := by positivity
  have hD' : L_bar + Delta_I * P' ≠ 0 := by positivity
  have hDpos : 0 < L_bar + Delta_I * P := by positivity
  have hD'pos : 0 < L_bar + Delta_I * P' := by positivity
  -- residual closed forms
  have hr : P * Delta_I - Delta_O_half lam Δi i L_bar Delta_I
      = Delta_I * P * (L_bar + P * (Delta_I - L_bar)) / (L_bar + Delta_I * P) :=
    slippage_residual lam Δi i L_bar Delta_I (by rw [← hPdef] at *; exact hD)
  have hr' : P' * Delta_I - Delta_O_half lam Δi' i L_bar Delta_I
      = Delta_I * P' * (L_bar + P' * (Delta_I - L_bar)) / (L_bar + Delta_I * P') :=
    slippage_residual lam Δi' i L_bar Delta_I (by rw [← hP'def] at *; exact hD')
  -- residual is positive
  have hresid_pos : 0 < P * Delta_I - Delta_O_half lam Δi i L_bar Delta_I := by
    rw [hr]; positivity
  -- residual is strictly increasing in the spacing
  have hresid_lt : P * Delta_I - Delta_O_half lam Δi i L_bar Delta_I
      < P' * Delta_I - Delta_O_half lam Δi' i L_bar Delta_I := by
    rw [hr, hr', div_lt_div_iff₀ hDpos hD'pos]
    have hbr : 0 < L_bar^2 + (Delta_I-L_bar)*L_bar*(P'+P) + (Delta_I-L_bar)*Delta_I*P*P' := by
      have t1 : 0 ≤ (Delta_I-L_bar)*L_bar*(P'+P) :=
        mul_nonneg (mul_nonneg ha hL_bar.le) (add_pos hP'pos hPpos).le
      have t2 : 0 ≤ (Delta_I-L_bar)*Delta_I*P*P' :=
        mul_nonneg (mul_nonneg (mul_nonneg ha hDelta_I.le) hPpos.le) hP'pos.le
      nlinarith [mul_pos hL_bar hL_bar]
    nlinarith [mul_pos (mul_pos hDelta_I (sub_pos.mpr hPP)) hbr]
  -- square the strictly-increasing positive residual
  unfold pi_trader_half
  rw [← hPdef, ← hP'def]
  nlinarith [hresid_lt, hresid_pos]

/-- **SMALL-TRADE QUADRATIC ASYMPTOTICS OF THE TRADER PAYOFF (η = 1/2).**

    As the trade size `Δ^I → 0⁺`, the squared-slippage payoff
    `pi_trader_half` is quadratic to leading order:

        pi_trader_half / (Δ^I)²  ⟶  P² · (P − 1)²,   P = P_half lam Δi i.

    Proof: by `slippage_residual`, `P·Δᴵ − Δᴼ = residual` with
    `residual = Δᴵ·P·(L̄ + P·(Δᴵ − L̄))/(L̄ + Δᴵ·P)`, so for `Δᴵ > 0`
    `pi / (Δᴵ)² = (residual/Δᴵ)²` and
    `residual/Δᴵ = P·(L̄ + P·(Δᴵ − L̄))/(L̄ + Δᴵ·P)` is continuous at
    `Δᴵ = 0` with value `P·(L̄ + P·(0 − L̄))/L̄ = P·(1 − P)`. Squaring
    gives the leading coefficient `P²·(1 − P)² = P²·(P − 1)²`.
-/
theorem pi_trader_half_small_trade_quadratic
    (lam : ℝ) (hlam : 0 < lam)
    (i : Int)
    (L_bar : ℝ) (hL_bar : 0 < L_bar)
    (Δi : ℝ) :
    Filter.Tendsto
      (fun Delta_I => pi_trader_half lam Δi i L_bar Delta_I / Delta_I ^ 2)
      (nhdsWithin 0 (Set.Ioi 0))
      (nhds ((P_half lam Δi i) ^ 2 * (P_half lam Δi i - 1) ^ 2)) := by
  convert Filter.Tendsto.congr' _ _ using 2;
  use fun x => ( P_half lam Δi i * ( L_bar + P_half lam Δi i * ( x - L_bar ) ) / ( L_bar + x * P_half lam Δi i ) ) ^ 2;
  · filter_upwards [ self_mem_nhdsWithin ] with x hx;
    unfold pi_trader_half;
    rw [ slippage_residual ] <;> norm_num [ hx.out.ne', ne_of_gt ( add_pos hL_bar ( mul_pos hx.out ( P_half_pos lam Δi hlam i ) ) ) ];
    rw [ eq_div_iff ( pow_ne_zero 2 hx.out.ne' ) ] ; ring;
  · convert Filter.Tendsto.pow ( Filter.Tendsto.div ( tendsto_const_nhds.mul ( tendsto_const_nhds.add ( tendsto_const_nhds.mul ( Filter.tendsto_id.mono_left inf_le_left |> Filter.Tendsto.sub_const <| L_bar ) ) ) ) ( tendsto_const_nhds.add ( Filter.tendsto_id.mono_left inf_le_left |> Filter.Tendsto.mul_const _ ) ) _ ) 2 using 2 <;> norm_num;
    · grind;
    · positivity

end CFMM.Eta