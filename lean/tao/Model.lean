import Mathlib

/-!
# The author's model — re-expression and corrections

This file restates the author's investment-market model in its own notation and
records the consistency checks and corrections.  Throughout, the notation
dictionary to the DTAO whitepaper is:

| author          | meaning                          | whitepaper |
|-----------------|----------------------------------|------------|
| `X^{(α_i)}`     | Alpha reserve of subnet `i`      | `α_i`      |
| `Y^{(τ)}`       | TAO reserve                      | `τ_i`      |
| `P_{α_i}`       | spot price `Y/X`                 | `p_i`      |
| `γ̄^{(τ)}`      | tao weight                       | `γ`        |
| `S^{(τ)}`       | root-staked TAO                  | `τ₀`       |
| `S^{(α_i)}(0)`  | initial Alpha outstanding        | `α_i⁰(0)`  |
| `ΔM̄^{(α_i)}`   | per-block Alpha emission cap     | `Δᾱ_i`     |
| `β̄`            | validator share                  | `0.41`     |

## Bonding curve

* `DTAO.Model.phi_homogeneous` : the CES/Cobb–Douglas bonding curve
  `φ(η; X, Y) = X^η · Y^{1-η}` is homogeneous of degree one.

## Root proportion `λ_i` — correction

The model defines
`λ_i = γ̄^{(τ)} / (γ̄^{(τ)}·S^{(τ)} + S^{(α_i)})`,
`1 - λ_i = S^{(α_i)} / (γ̄^{(τ)}·S^{(τ)} + S^{(α_i)})`.

* `DTAO.Model.lambda_literal_inconsistent` : as *written*, these two expressions
  sum to one **iff** `S^{(τ)} = 1`; in general they are inconsistent (the
  numerator of `λ_i` is missing a factor `S^{(τ)}`).
* `DTAO.Model.lambda_corrected_sum` : the corrected
  `λ_i = γ̄^{(τ)}·S^{(τ)} / (γ̄^{(τ)}·S^{(τ)} + S^{(α_i)})` does sum to one and
  matches the whitepaper root proportion `r_i = γτ₀/(γτ₀+α_i⁰)`.

## Risk-free rate `r_F` — same correction

The model's `r_F^{(i)}` carries a prefactor `1/S^{(τ)}` with numerator
`γ̄^{(τ)}·β̄·ΔM̄`.  To match the whitepaper APYᵣ the numerator must include the
same missing `S^{(τ)}` factor.

* `DTAO.Model.rF_corrected_reduces` : with the corrected numerator
  `γ̄^{(τ)}·S^{(τ)}·β̄·ΔM̄` the prefactor `1/S^{(τ)}` cancels and `r_F` reduces to
  the whitepaper form `Σ_t γ̄·β̄·ΔM̄ / D_t`.
* `DTAO.Model.rF_literal_ne_corrected` : the model's literal `r_F` (numerator
  `γ̄·β̄·ΔM̄`) differs from the corrected `r_F` (numerator `γ̄·S^{(τ)}·β̄·ΔM̄`)
  in general — the same missing `S^{(τ)}` factor as in `λ_i`.

## α-return `r^{(α_i)}` — consistent (no correction)

The model's `r^{(α_i)}` is term-by-term equal to the whitepaper subnet APY
(eqn (57)); its closed form is verified in `DTAO.APY.subnet_closed`.
-/

namespace DTAO.Model

open scoped BigOperators
open Real

/-
**Bonding curve homogeneity.**  `φ(η; X, Y) = X^η·Y^{1-η}` is homogeneous of
degree one: for `c, X, Y ≥ 0`, `φ(η; c·X, c·Y) = c · φ(η; X, Y)`.
-/
theorem phi_homogeneous (eta c X Y : ℝ) (hc : 0 ≤ c) (hX : 0 ≤ X) (hY : 0 ≤ Y) :
    (c * X) ^ eta * (c * Y) ^ (1 - eta) = c * (X ^ eta * Y ^ (1 - eta)) := by
      by_cases hc : c = 0;
      · by_cases he : eta = 0 <;> by_cases he' : 1 - eta = 0 <;> simp_all +decide;
      · rw [ Real.mul_rpow ( by positivity ) ( by positivity ), Real.mul_rpow ( by positivity ) ( by positivity ) ];
        rw [ mul_mul_mul_comm, ← Real.rpow_add ( by positivity ) ] ; norm_num

/-
**`λ_i` as written is inconsistent.**  The literal `λ_i` and `1-λ_i` sum to
one iff `S^{(τ)} = 1`.
-/
theorem lambda_literal_inconsistent (gbar Stau Salpha : ℝ) (hg : 0 < gbar)
    (hden : 0 < gbar * Stau + Salpha) :
    (gbar / (gbar * Stau + Salpha) + Salpha / (gbar * Stau + Salpha) = 1)
      ↔ Stau = 1 := by
        grind

/-
**Corrected `λ_i` sums to one.**  With the missing `S^{(τ)}` factor restored,
`λ_i + (1-λ_i) = 1`.
-/
theorem lambda_corrected_sum (gbar Stau Salpha : ℝ)
    (hden : 0 < gbar * Stau + Salpha) :
    gbar * Stau / (gbar * Stau + Salpha) + Salpha / (gbar * Stau + Salpha) = 1 := by
  grind +qlia

/-
**Corrected `r_F` reduces to the whitepaper APYᵣ form.**  With numerator
`γ̄·S^{(τ)}·β̄·ΔM̄`, the model prefactor `1/S^{(τ)}` cancels term-by-term.
-/
theorem rF_corrected_reduces (Stau gbar beta dM : ℝ) (Tn : ℕ) (D : ℕ → ℝ)
    (hStau : Stau ≠ 0) :
    (1 / Stau) * (∑ t ∈ Finset.range Tn, gbar * Stau * beta * dM / D t)
      = ∑ t ∈ Finset.range Tn, gbar * beta * dM / D t := by
        simp +decide [ div_eq_mul_inv, mul_assoc, mul_comm, mul_left_comm, Finset.mul_sum _ _ _, hStau ]

/-
**Literal `r_F` differs from the corrected `r_F`.**  With a common prefactor
`1/S^{(τ)}` and a single time step, the literal numerator `γ̄·β̄·ΔM̄` and the
corrected numerator `γ̄·S^{(τ)}·β̄·ΔM̄` give different values in general
(they agree only when `S^{(τ)} = 1`).
-/
theorem rF_literal_ne_corrected :
    ∃ (Stau gbar beta dM : ℝ) (D0 : ℝ),
      (1 / Stau) * (gbar * beta * dM / D0)
        ≠ (1 / Stau) * (gbar * Stau * beta * dM / D0) := by
          exact ⟨ 2, 1, 1, 1, 1, by norm_num ⟩

end DTAO.Model