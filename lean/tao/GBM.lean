import Mathlib

/-!
# Lognormal price expectation under GBM (DTAO §4.2, eqns (24), (32)–(34))

Under the Geometric-Brownian-Motion price model the price `p_i(t)` is lognormal,
and the expected price is obtained from the Gaussian moment formula (eqn (32))

  `∫ e^{c·x} · (2πa)^{-1/2} · exp(-(x-d)²/(2a)) dx = exp(c·d + a·c²/2)`  (a > 0)

specialised to `c = 1`, `d = μt`, `a = σ²t`, giving (eqn (34))

  `E[p_i(t)] = p_i(0) · e^{(μ_i + σ_i²/2)·t}`.

* `DTAO.GBM.gaussian_mgf` : the Gaussian moment formula (eqn (32)).
* `DTAO.GBM.expected_price` : the expected GBM price (eqn (34)).
-/

namespace DTAO.GBM

open Real MeasureTheory
open scoped Real

/-
**Gaussian moment formula (eqn (32)).**  For `a > 0`,
`∫ e^{c·x} (2πa)^{-1/2} exp(-(x-d)²/(2a)) dx = exp(c·d + a·c²/2)`.
-/
theorem gaussian_mgf (a c d : ℝ) (ha : 0 < a) :
    (∫ x : ℝ, Real.exp (c * x)
        * ((1 / Real.sqrt (2 * π * a)) * Real.exp (-(x - d) ^ 2 / (2 * a))))
      = Real.exp (c * d + a * c ^ 2 / 2) := by
        -- Complete the square in the exponent: $c*x - (x-d)^2/(2a) = -(x - (d + a*c))^2/(2a) + (c*d + a*c^2/2)$.
        suffices h_complete_square : ∫ x, Real.exp (-(x - (d + a * c)) ^ 2 / (2 * a)) = Real.sqrt (2 * Real.pi * a) by
          convert congr_arg ( fun x : ℝ => x * Real.exp ( c * d + a * c ^ 2 / 2 ) * ( Real.sqrt ( 2 * Real.pi * a ) ) ⁻¹ ) h_complete_square using 1;
          · rw [ ← MeasureTheory.integral_mul_const, ← MeasureTheory.integral_mul_const ] ; congr ; ext x ; ring;
            norm_num [ sq, mul_assoc, mul_comm a, ha.ne', ← Real.exp_add ] ; ring;
            simpa only [ Real.exp_add ] using by ring;
          · rw [ mul_right_comm, mul_inv_cancel₀ ( by positivity ), one_mul ];
        convert integral_gaussian ( 1 / ( 2 * a ) ) using 1 <;> ring;
        · rw [ ← MeasureTheory.integral_add_right_eq_self _ ( d + a * c ) ] ; congr ; ext ; ring;
        · grind

/-
**Expected GBM price (eqn (34)).**  With change of variables `x = log(p/p₀)`,
the lognormal mean over the time-`t` density (variance `σ²t`, mean log-drift `μt`)
is `E[p(t)] = p₀ · e^{(μ + σ²/2)·t}`.
-/
theorem expected_price (p0 mu sigma t : ℝ) (ht : 0 < t) (hsig : sigma ≠ 0) :
    (p0 * ∫ x : ℝ, Real.exp x
        * ((1 / Real.sqrt (2 * π * (sigma ^ 2 * t)))
            * Real.exp (-(x - mu * t) ^ 2 / (2 * (sigma ^ 2 * t)))))
      = p0 * Real.exp ((mu + sigma ^ 2 / 2) * t) := by
        convert congr_arg ( fun x : ℝ => p0 * x ) ( gaussian_mgf ( sigma ^ 2 * t ) 1 ( mu * t ) ( by positivity ) ) using 2 ; ring;
        · exact congr_arg _ ( funext fun x => by ring );
        · ring

end DTAO.GBM