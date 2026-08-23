import Mathlib

/-!
# Liquidity injection / emission split (DTAO §3.2, eqns (6)–(9), (39))

The per-block TAO injection to subnet `i` is `Δτ_i = (p_i / S)·Δτ̄` with
`S = Σ_j p_j`, and the Alpha injection is capped:
`Δα_i = min(Δτ̄ / S, Δᾱ_i)`.

* `DTAO.Injection.sum_tau_inject` : eqn (8), `Σ_i Δτ_i = Δτ̄`.
* `DTAO.Injection.alpha_inject_le` : eqn (9), `Δα_i ≤ Δᾱ_i`.
* `DTAO.Injection.min_max_rewrite` : eqn (39),
  `min(Δτ̄/S, Δᾱ) = Δτ̄ / max(S, Δτ̄/Δᾱ)`.
* `DTAO.Injection.share_sum_one` : in the model's flow-based notation, the
  emission shares `s_i = z_i^p / Σ_j z_j^p` sum to one.
-/

namespace DTAO.Injection

open scoped BigOperators

/-
**Conservation of injected TAO (eqn (8)).**  With `Δτ_i = (p_i/S)·Δτ̄` and
`S = Σ_j p_j > 0`, the total injected TAO equals the block budget `Δτ̄`.
-/
theorem sum_tau_inject {n : ℕ} (p : Fin n → ℝ) (taubar : ℝ)
    (hS : 0 < ∑ j, p j) :
    (∑ i, (p i / (∑ j, p j)) * taubar) = taubar := by
      simp +decide only [div_mul_eq_mul_div, ← Finset.sum_div];
      rw [ ← Finset.sum_mul, mul_div_cancel_left₀ _ hS.ne' ]

/-- **Alpha cap (eqn (9)).** The capped Alpha injection never exceeds `Δᾱ`. -/
theorem alpha_inject_le (S taubar abar : ℝ) :
    min (taubar / S) abar ≤ abar := min_le_right _ _

/-
**min/max rewrite (eqn (39)).**  For positive `S`, `Δᾱ`, `Δτ̄`,
`min(Δτ̄/S, Δᾱ) = Δτ̄ / max(S, Δτ̄/Δᾱ)`.
-/
theorem min_max_rewrite (S taubar abar : ℝ) (hS : 0 < S) (habar : 0 < abar)
    (htau : 0 < taubar) :
    min (taubar / S) abar = taubar / (max S (taubar / abar)) := by
      rw [ min_def, max_def ] ; split_ifs <;> ring_nf at * ;
      · field_simp at *;
        linarith;
      · grind;
      · nlinarith [ mul_inv_cancel₀ hS.ne', mul_inv_cancel₀ habar.ne' ]

/-
**Emission shares sum to one (model, flow-based share `s_i`).**  With
`s_i = z_i^p / Σ_j z_j^p` and `Σ_j z_j^p > 0`, the shares form a probability
vector: `Σ_i s_i = 1`.
-/
theorem share_sum_one {n : ℕ} (zp : Fin n → ℝ) (hpos : 0 < ∑ j, zp j) :
    (∑ i, zp i / (∑ j, zp j)) = 1 := by
      rw [ ← Finset.sum_div, div_self hpos.ne' ]

end DTAO.Injection