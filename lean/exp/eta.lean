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

end CFMM.Eta
