import Mathlib

/-!
# Halving schedule (DTAO §3.5, §5.2, eqns (70)–(77))

The block emission halves at fixed supply thresholds.  Summing the resulting
geometric series gives the asymptotic supply `S* = 2N`, and the current halving
index `k` is recovered from the cumulative supply via a base-2 logarithm.

* `DTAO.Halving.total_supply` : `Σ_{k≥0} N·(1/2)^k = 2N` (eqn (70)).
* `DTAO.Halving.accumulated_supply` : `Σ_{n<k} N·(1/2)^n = 2N·(1 - (1/2)^k)`
  (eqn (72), `S↓`).
* `DTAO.Halving.k_formula` : consistency of `k = -log₂(1 - S↓/S*)` with the
  geometric accumulation (eqns (74), (77)).
-/

namespace DTAO.Halving

open scoped BigOperators

/-
**Asymptotic total supply (eqn (70)).**  Summing the halving geometric
series gives `S* = 2N`.
-/
theorem total_supply (N : ℝ) : (∑' k : ℕ, N * (1 / 2 : ℝ) ^ k) = 2 * N := by
  rw [ tsum_mul_left, tsum_geometric_two ] ; ring

/-
**Accumulated supply up to the `k`-th halving (eqn (72), `S↓`).**
-/
theorem accumulated_supply (N : ℝ) (k : ℕ) :
    (∑ n ∈ Finset.range k, N * (1 / 2 : ℝ) ^ n) = 2 * N * (1 - (1 / 2 : ℝ) ^ k) := by
  rw [ ← Finset.mul_sum _ _ _, geom_sum_eq ] <;> ring ; norm_num

/-
**Recovery of the halving index (eqns (74), (77)).**  If `S↓ = S*·(1 - 2^{-k})`
with `S* = 2N > 0`, then `-log₂(1 - S↓/S*) = k`.
-/
theorem k_formula (N : ℝ) (k : ℕ) (hN : 0 < N) :
    -Real.logb 2 (1 - (2 * N * (1 - (1 / 2 : ℝ) ^ k)) / (2 * N)) = k := by
      norm_num [ hN.ne', mul_div_cancel_left₀ ];
      norm_num [ Real.logb, Real.log_div, Real.log_pow ];
      norm_num [ neg_div ]

end DTAO.Halving