import Mathlib

open scoped BigOperators
open Real

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Position spec module: `(σ̄, #_σ̄, s_v) → (p(i), p(i_l), p(i_u))`

This file formalizes the *verifiable backbone* of the position-spec map described
in the request.

A user reveals a target volatility `σ̄` (brought to Q64.96 as `σ̄₉₆`), a skew
`s_v ∈ [0,1]` and a width `#_σ̄` (in units of the tick spacing `Δ_i`).  From these
we obtain a lower tick `i_l`, an upper tick `i_u`, and the skew-interpolated tick

  `i(σ̄₉₆) = s_v · i_l + (1 - s_v) · i_u`

together with the width relation

  `Δ_i · #_σ̄ = |i_l - i_u|`.

Each tick is mapped to a price coordinate for tick spacing `Δ_i` by

  `p(i) = λ^{(i/2)·Δ_i}`,  with `λ = 1.0001`.

All quantities are modelled over `ℝ`; on the EVM the ticks are `i24`, the
volatilities `u88`, the skew a `u16` fraction and the width a `u24` count, and the
prices are `Q64.96`.  The lemmas below are exactly the order/algebraic facts a
fixed-point implementation must preserve.
-/

namespace PosSpec

/-- The base `λ = 1.0001` used by the tick/price grid. -/
noncomputable def lam : ℝ := 1.0001

lemma one_lt_lam : (1 : ℝ) < lam := by unfold lam; norm_num

lemma lam_pos : (0 : ℝ) < lam := by unfold lam; norm_num

/-- Price coordinate of a tick `i` for tick spacing `Δi`: `p(i) = λ^{(i/2)·Δi}`. -/
noncomputable def tickPrice (Δi i : ℝ) : ℝ := lam ^ ((i / 2) * Δi)

/-- Skew-interpolated tick coordinate `i(σ̄) = s_v·i_l + (1 - s_v)·i_u`. -/
def skewTick (sv il iu : ℝ) : ℝ := sv * il + (1 - sv) * iu

/-- At full skew (`s_v = 1`) the interpolated tick is the lower tick. -/
lemma skewTick_one (il iu : ℝ) : skewTick 1 il iu = il := by
  unfold skewTick; ring

/-- At zero skew (`s_v = 0`) the interpolated tick is the upper tick. -/
lemma skewTick_zero (il iu : ℝ) : skewTick 0 il iu = iu := by
  unfold skewTick; ring

/-
The interpolated tick is a convex combination and hence lies between the
endpoints (assuming `i_l ≤ i_u` and `s_v ∈ [0,1]`).
-/
lemma skewTick_mem (sv il iu : ℝ) (hsv0 : 0 ≤ sv) (hsv1 : sv ≤ 1) (h : il ≤ iu) :
    il ≤ skewTick sv il iu ∧ skewTick sv il iu ≤ iu := by
      constructor <;> unfold skewTick <;> nlinarith

/-
Distance of the interpolated tick from the upper endpoint is `s_v·(i_u - i_l)`.
-/
lemma skewTick_gap_upper (sv il iu : ℝ) :
    iu - skewTick sv il iu = sv * (iu - il) := by
      unfold skewTick; ring;

/-
Distance of the interpolated tick from the lower endpoint is
`(1 - s_v)·(i_u - i_l)`.
-/
lemma skewTick_gap_lower (sv il iu : ℝ) :
    skewTick sv il iu - il = (1 - sv) * (iu - il) := by
      unfold skewTick; ring;

/-
The width identity `Δ_i · #_σ̄ = |i_l - i_u|` gives the (oriented) tick span
`i_u - i_l = Δ_i · #_σ̄` when `i_l ≤ i_u`.
-/
lemma width_span (Δi width il iu : ℝ) (hw : Δi * width = |il - iu|) (h : il ≤ iu) :
    iu - il = Δi * width := by
      rw [ hw, abs_of_nonpos ] <;> linarith

/-
Prices are strictly positive.
-/
lemma tickPrice_pos (Δi i : ℝ) : 0 < tickPrice Δi i := by
  exact Real.rpow_pos_of_pos ( by exact lt_of_le_of_lt ( by norm_num ) ( one_lt_lam ) ) _

/-
Price is monotone in the tick (for positive tick spacing).
-/
lemma tickPrice_le (Δi i j : ℝ) (hΔ : 0 < Δi) (h : i ≤ j) :
    tickPrice Δi i ≤ tickPrice Δi j := by
      exact Real.rpow_le_rpow_of_exponent_le ( by norm_num [ PosSpec.lam ] ) ( by nlinarith )

/-
Price is strictly monotone in the tick (for positive tick spacing).
-/
lemma tickPrice_lt (Δi i j : ℝ) (hΔ : 0 < Δi) (h : i < j) :
    tickPrice Δi i < tickPrice Δi j := by
      exact Real.rpow_lt_rpow_of_exponent_lt ( by norm_num [ lam ] ) ( by nlinarith )

/-
Price ordering induced by the skew: the interpolated price lies between the
endpoint prices, `p(i_l) ≤ p(i(σ̄)) ≤ p(i_u)`.
-/
lemma tickPrice_skew_mem (Δi sv il iu : ℝ) (hΔ : 0 < Δi)
    (hsv0 : 0 ≤ sv) (hsv1 : sv ≤ 1) (h : il ≤ iu) :
    tickPrice Δi il ≤ tickPrice Δi (skewTick sv il iu) ∧
      tickPrice Δi (skewTick sv il iu) ≤ tickPrice Δi iu := by
        exact ⟨ tickPrice_le _ _ _ hΔ ( skewTick_mem _ _ _ hsv0 hsv1 h |>.1 ), tickPrice_le _ _ _ hΔ ( skewTick_mem _ _ _ hsv0 hsv1 h |>.2 ) ⟩

end PosSpec