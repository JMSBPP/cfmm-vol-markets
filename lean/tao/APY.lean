import Mathlib

/-!
# Root vs. subnet returns ("Tao-weight" APY heuristic, DTAO §5.1, eqns (56)–(68))

Writing `D_i(t) = γ·τ₀ + α_i⁰(0) + t·Δᾱ_i` for the running denominator, the
validator-side returns are

* root staker:   `APYᵣ = Σ_i Σ_t  γ·(0.41)·Δᾱ_i / D_i(t)`        (eqns (59),(61))
* avg. subnet:   `APYₐ = (1/N)·Σ_i Σ_t (1 + t·Δᾱ_i/α_i⁰(0))·(0.41)·Δᾱ_i / D_i(t)`
                                                                   (eqns (60),(62))

* `DTAO.APY.root_le_avg` : the §5.1 heuristic — if `γ ≤ 1/N` then `APYᵣ ≤ APYₐ`
  (eqns (65)–(67)).
* `DTAO.APY.root_closed` : the integral closed form (eqn (67)) checked as a
  derivative — `d/dt [γ·0.41·log D] = γ·0.41·Δᾱ / D` (root returns grow
  logarithmically in `t`).
* `DTAO.APY.subnet_closed` : the integral closed form (eqn (68)) checked as a
  derivative; the subnet return grows linearly in `t`.
-/

namespace DTAO.APY

open scoped BigOperators

/-
**Tao-weight heuristic (eqns (65)–(67)).**  If the tao weight satisfies
`γ·N ≤ 1`, then the passive root APY is at most the average subnet APY.
-/
theorem root_le_avg {N : ℕ} (hN : 0 < N) (Tn : ℕ)
    (gamma tau0 : ℝ) (abar alpha0 : Fin N → ℝ)
    (habar : ∀ i, 0 ≤ abar i) (halpha0 : ∀ i, 0 < alpha0 i)
    (hD : ∀ (i : Fin N) (t : ℕ),
        0 < gamma * tau0 + alpha0 i + (t : ℝ) * abar i)
    (hgN : gamma * (N : ℝ) ≤ 1) :
    (∑ i, ∑ t ∈ Finset.range Tn,
        gamma * (0.41) * abar i / (gamma * tau0 + alpha0 i + (t : ℝ) * abar i))
      ≤ (1 / (N : ℝ)) * ∑ i, ∑ t ∈ Finset.range Tn,
        (1 + ((t : ℝ) * abar i) / alpha0 i) * (0.41) * abar i
          / (gamma * tau0 + alpha0 i + (t : ℝ) * abar i) := by
            -- By multiplying both sides of the inequality by $N$, we can simplify the expression.
            have h_mul_N : ∑ i : Fin N, ∑ t ∈ Finset.range Tn, gamma * (0.41 : ℝ) * abar i / (gamma * tau0 + alpha0 i + t * abar i) ≤
                             (1 / N : ℝ) * ∑ i : Fin N, ∑ t ∈ Finset.range Tn, (1 + t * abar i / alpha0 i) * (0.41 : ℝ) * abar i / (gamma * tau0 + alpha0 i + t * abar i) := by
              have h_le : ∀ i : Fin N, ∀ t : ℕ, gamma * (0.41 : ℝ) * abar i / (gamma * tau0 + alpha0 i + t * abar i) ≤
                (1 / N : ℝ) * (1 + t * abar i / alpha0 i) * (0.41 : ℝ) * abar i / (gamma * tau0 + alpha0 i + t * abar i) := by
                  intro i t; gcongr;
                  · exact le_of_lt ( hD i t );
                  · exact habar i;
                  · rw [ div_mul_eq_mul_div, le_div_iff₀ ] <;> first | positivity | nlinarith [ show ( 0 : ℝ ) ≤ t * abar i / alpha0 i by exact div_nonneg ( mul_nonneg ( Nat.cast_nonneg _ ) ( habar i ) ) ( le_of_lt ( halpha0 i ) ) ] ;
              simpa only [ Finset.mul_sum _ _ _, mul_assoc, mul_div_assoc ] using Finset.sum_le_sum fun i hi => Finset.sum_le_sum fun t ht => h_le i t;
            convert h_mul_N using 1

/-
**Root-return closed form (eqn (67)).**  The continuous-time root return
`γ·0.41·log(γτ₀ + α⁰ + t·Δᾱ)` has derivative equal to the integrand
`γ·0.41·Δᾱ / (γτ₀ + α⁰ + t·Δᾱ)`; hence root returns grow logarithmically.
-/
theorem root_closed (gamma tau0 abar alpha0 t : ℝ)
    (hpos : 0 < gamma * tau0 + alpha0 + t * abar) :
    HasDerivAt
      (fun s : ℝ => gamma * 0.41 * Real.log (gamma * tau0 + alpha0 + s * abar))
      (gamma * 0.41 * abar / (gamma * tau0 + alpha0 + t * abar)) t := by
        convert HasDerivAt.const_mul ( gamma * 0.41 ) ( HasDerivAt.log ( HasDerivAt.add ( hasDerivAt_const _ _ ) ( hasDerivAt_mul_const _ ) ) hpos.ne' ) using 1 ; ring!;
        norm_num [ add_comm, mul_comm ];
        exact Or.inl <| by ring;

/-
**Subnet-return closed form (eqn (68)).**  The continuous-time subnet return
`0.41·((Δᾱ/α⁰)·t − (γτ₀/α⁰)·log(γτ₀+α⁰+t·Δᾱ))` has derivative equal to the
integrand `(1 + t·Δᾱ/α⁰)·0.41·Δᾱ / (γτ₀+α⁰+t·Δᾱ)`; the leading term is linear
in `t`.
-/
theorem subnet_closed (gamma tau0 abar alpha0 t : ℝ) (h0 : alpha0 ≠ 0)
    (hpos : 0 < gamma * tau0 + alpha0 + t * abar) :
    HasDerivAt
      (fun s : ℝ => 0.41 * ((abar / alpha0) * s
          - (gamma * tau0 / alpha0) * Real.log (gamma * tau0 + alpha0 + s * abar)))
      ((1 + t * abar / alpha0) * 0.41 * abar / (gamma * tau0 + alpha0 + t * abar)) t := by
  convert HasDerivAt.const_mul _ <| HasDerivAt.sub ( HasDerivAt.mul ( hasDerivAt_const _ _ ) <| hasDerivAt_id t ) <| HasDerivAt.mul ( hasDerivAt_const _ _ ) <| HasDerivAt.log ( HasDerivAt.add ( hasDerivAt_const _ _ ) <| hasDerivAt_mul_const _ ) _ using 1 <;> norm_num [ hpos.ne' ] ; ring_nf;
  grind

end DTAO.APY