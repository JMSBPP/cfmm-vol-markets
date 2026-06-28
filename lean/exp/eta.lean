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

end CFMM.Eta