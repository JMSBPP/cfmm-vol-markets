import Mathlib

/-!
# Constant-product subnet AMM identities (DTAO §3.1)

This file formalizes the elementary constant-product AMM relations used as the
foundation of the DTAO model, restated in the author's notation where the pool
reserves are `X` (Alpha, the `α`-token) and `Y` (TAO, the `τ`-token), with spot
price `P = Y / X`.

* `DTAO.AMM.reserve_X` / `reserve_Y` : reconstruction of reserves from the
  liquidity scale `L = √(X·Y)` and the spot price `P = Y/X`, i.e. `X = L/√P`,
  `Y = L·√P`.
* `DTAO.AMM.price_preserving` : a liquidity injection at the current spot price
  preserves the spot price.  This is the substantive content behind the model's
  "price-preserving injection" `dL^{(α_i)} = dL^{(τ_i)} / P_{α_i}` and the
  whitepaper price-impact identity `P + dP ≡ (Y+dY)/(X+dX)`.
* `DTAO.AMM.invariant_grows` : a price-preserving injection strictly grows the
  constant-product invariant `K = X·Y`.
-/

namespace DTAO.AMM

open Real

/-
Reconstruction of the Alpha reserve: with liquidity `L = √(X·Y)` and spot
price `P = Y/X`, the Alpha reserve is `X = L / √P`.
-/
theorem reserve_X (X Y : ℝ) (hX : 0 < X) (hY : 0 < Y) :
    X = Real.sqrt (X * Y) / Real.sqrt (Y / X) := by
      rw [ eq_div_iff, mul_comm ];
      · rw [ show X * Y = ( Y / X ) * X ^ 2 by rw [ div_mul_eq_mul_div, eq_div_iff ] <;> linarith, Real.sqrt_mul ( by positivity ), Real.sqrt_sq hX.le ];
      · positivity

/-
Reconstruction of the TAO reserve: with liquidity `L = √(X·Y)` and spot
price `P = Y/X`, the TAO reserve is `Y = L · √P`.
-/
theorem reserve_Y (X Y : ℝ) (hX : 0 < X) (hY : 0 < Y) :
    Y = Real.sqrt (X * Y) * Real.sqrt (Y / X) := by
      field_simp;
      rw [ ← Real.sqrt_mul ( by positivity ), mul_assoc, mul_comm Y, mul_div_cancel₀ _ ( by positivity ), Real.sqrt_mul_self ( by positivity ) ]

/-
**Price-preserving injection.**  If the pool sits at spot price `P`
(`Y = P · X`) and we inject reserves `(dX, dY)` at the same ratio
(`dY = P · dX`), then the post-injection spot price is unchanged:
`(Y + dY)/(X + dX) = P`.
-/
theorem price_preserving (X Y dX dY P : ℝ) (hX : 0 < X) (hdX : 0 < dX)
    (hY : Y = P * X) (hdY : dY = P * dX) :
    (Y + dY) / (X + dX) = P := by
      rw [ div_eq_iff ] <;> nlinarith

/-
A price-preserving injection of strictly positive size strictly increases
the constant-product invariant `K = X · Y`.
-/
theorem invariant_grows (X Y dX dY P : ℝ) (hX : 0 < X)
    (hdX : 0 < dX) (hP : 0 < P) (hY : Y = P * X) (hdY : dY = P * dX) :
    X * Y < (X + dX) * (Y + dY) := by
      nlinarith [ mul_pos hX hP, mul_pos hX hdX, mul_pos hP hdX ]

end DTAO.AMM