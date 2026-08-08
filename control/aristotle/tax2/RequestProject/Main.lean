import Mathlib

open scoped BigOperators
open scoped Real
open scoped Nat
open scoped Classical
open scoped Pointwise

set_option maxHeartbeats 8000000
set_option maxRecDepth 4000
set_option synthInstance.maxHeartbeats 20000
set_option synthInstance.maxSize 128

set_option relaxedAutoImplicit false
set_option autoImplicit false

set_option grind.warning false

/-!
# EVM-aware design space: distance `d` and flow operator `∂_(M,v)`

This file formalizes the *verifiable mathematical backbone* behind the design
question.  All quantities are modelled over `ℝ`; on the EVM they are the images
of fixed-point encodings (Q64.96 / X96 = scale `2^96`, RAY = scale `1e27`), and
the theorems below are exactly the order/algebraic facts a fixed-point
implementation must preserve.

Notation used below:
* `Qv i`  ≙ `Q_v^i`      (per-tranche shares, `> 0`)
* `d i`   ≙ `d(p_risk, p(i(σ_x96)))`  (per-tranche distance, in `[0,1]`)
* `QvΣ`   ≙ `Q_v^Σ = ∑ Qv i`         (`totalShares`, the accounting identity)
* the *discounted* sum is `∑ Qv i * d i`.
-/

namespace EVMDesignSpace

/-
**Nonnegativity of the discounted sum.**
If every share is nonnegative and every distance is nonnegative, the discounted
sum `∑ Qv i * d i` is nonnegative.
-/
theorem discounted_nonneg (N : ℕ) (Qv d : ℕ → ℝ)
    (hQ : ∀ i, 0 ≤ Qv i) (hd0 : ∀ i, 0 ≤ d i) :
    0 ≤ ∑ i ∈ Finset.range N, Qv i * d i := by
  exact Finset.sum_nonneg fun i _ => mul_nonneg ( hQ i ) ( hd0 i )

/-
**Upper bound of the discounted sum (the true "admissibility" fact).**
With `d ∈ [0,1]` and nonnegative shares, the discounted sum is bounded above by
the accounting identity `Q_v^Σ = ∑ Qv i`.  This is the *inequality* the informal
note asserts as an equality.
-/
theorem discounted_le_total (N : ℕ) (Qv d : ℕ → ℝ)
    (hQ : ∀ i, 0 ≤ Qv i) (hd1 : ∀ i, d i ≤ 1) :
    ∑ i ∈ Finset.range N, Qv i * d i ≤ ∑ i ∈ Finset.range N, Qv i := by
  exact Finset.sum_le_sum fun i _ => mul_le_of_le_one_right ( hQ i ) ( hd1 i )

/-
**Equality characterization.**
The discounted sum equals the accounting identity iff, term by term,
`Qv i * d i = Qv i` on the active range (i.e. `d i = 1` wherever `Qv i > 0`).
-/
theorem discounted_eq_total_iff (N : ℕ) (Qv d : ℕ → ℝ)
    (hQ : ∀ i, 0 ≤ Qv i) (hd1 : ∀ i, d i ≤ 1) :
    (∑ i ∈ Finset.range N, Qv i * d i = ∑ i ∈ Finset.range N, Qv i)
      ↔ (∀ i ∈ Finset.range N, Qv i * d i = Qv i) := by
  constructor <;> intro h;
  · exact fun i hi => le_antisymm ( mul_le_of_le_one_right ( hQ i ) ( hd1 i ) ) ( by simpa [ * ] using Finset.single_le_sum ( fun i _ => sub_nonneg_of_le ( mul_le_of_le_one_right ( hQ i ) ( hd1 i ) ) ) hi );
  · exact Finset.sum_congr rfl h

/-
**Equality with strictly positive shares forces `d ≡ 1`.**
If all shares are strictly positive, the accounting identity is recovered exactly
iff the distance is identically `1` on the range.  Hence a distance valued in
`[0,1]` does *not* in general reproduce `∑ Qv i`.
-/
theorem discounted_eq_total_iff_pos (N : ℕ) (Qv d : ℕ → ℝ)
    (hQ : ∀ i, 0 < Qv i) (hd1 : ∀ i, d i ≤ 1) :
    (∑ i ∈ Finset.range N, Qv i * d i = ∑ i ∈ Finset.range N, Qv i)
      ↔ (∀ i ∈ Finset.range N, d i = 1) := by
  convert discounted_eq_total_iff N Qv d ( fun i => le_of_lt ( hQ i ) ) hd1 using 1;
  exact ⟨ fun h i hi => by rw [ h i hi, mul_one ], fun h i hi => by nlinarith [ h i hi, hQ i ] ⟩

/-
**The informal claim is false.**
There is an instance with `N ≥ 1`, strictly positive shares, and `d ∈ [0,1]`,
for which the discounted sum is *not* equal to `∑ Qv i`.  (Take `N = 1`,
`Qv ≡ 1`, `d ≡ 0`.)
-/
theorem discounted_claim_counterexample :
    ∃ (N : ℕ) (Qv d : ℕ → ℝ),
      (∀ i, 0 < Qv i) ∧ (∀ i, 0 ≤ d i) ∧ (∀ i, d i ≤ 1) ∧
      (∑ i ∈ Finset.range N, Qv i * d i ≠ ∑ i ∈ Finset.range N, Qv i) := by
  exact ⟨ 1, fun _ => 1, fun _ => 0, by norm_num ⟩

/-!
## Admissible region for the flow operator `∂_(M,v)`

The exogenous flow `ΔQvΣ = ∂_(M,v) Q_M^Σ` lives in the RAY (1e27) state update
`(QvΣ)_next = QvΣ + ΔQvΣ`, and is constrained by the admissible region
`ΔQvΣ ≤ Q_M^Σ / p_risk`.
-/

/-
**Division-free reformulation of the admissible region (EVM form).**
For a strictly positive risk price `prisk`, the admissible constraint
`Δ ≤ Q_M^Σ / prisk` is equivalent to the cross-multiplied form
`Δ * prisk ≤ Q_M^Σ`.  On the EVM this lets an implementation avoid a division
(and its rounding) by testing a single multiplication.
-/
theorem admissible_iff_mul (Δ QMtot prisk : ℝ) (hp : 0 < prisk) :
    Δ ≤ QMtot / prisk ↔ Δ * prisk ≤ QMtot := by
  rw [ le_div_iff₀ hp ]

/-
**The admissible flow is bounded.**
A nonnegative flow in the admissible region is confined to
`0 ≤ Δ ≤ Q_M^Σ / prisk`; hence the post-update state
`QvΣ + Δ` lies in `[QvΣ, QvΣ + Q_M^Σ / prisk]`.
-/
theorem admissible_state_bounds (Δ Qvtot QMtot prisk : ℝ)
    (hΔ0 : 0 ≤ Δ) (hΔ : Δ ≤ QMtot / prisk) :
    Qvtot ≤ Qvtot + Δ ∧ Qvtot + Δ ≤ Qvtot + QMtot / prisk := by
  constructor <;> linarith

end EVMDesignSpace