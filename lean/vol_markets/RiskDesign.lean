import Mathlib
import vol_markets.Main
import vol_markets.Flow

set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Implementable alternatives for distance, risk price, and haircut

This module separates three concepts which should not be conflated in an EVM
implementation:

* `distance` is a dimensionless weight in `[0,1]`;
* `riskPrice` is a positive price in Q64.96 / X96;
* `haircut` is a dimensionless loss fraction in `[0,1]`.

The real-valued definitions specify the intended economics.  The final section
models the key X96 integer operation and its conservative rounding exactly.
-/

namespace RiskDesign

/-- Projection of a real number onto the unit interval. -/
def clamp01 (x : ℝ) : ℝ := max 0 (min 1 x)

lemma clamp01_nonneg (x : ℝ) : 0 ≤ clamp01 x := by
  exact le_max_left _ _

lemma clamp01_le_one (x : ℝ) : clamp01 x ≤ 1 := by
  exact max_le_iff.mpr ⟨ by norm_num, by norm_num ⟩

lemma clamp01_eq_self {x : ℝ} (h0 : 0 ≤ x) (h1 : x ≤ 1) : clamp01 x = x := by
  unfold clamp01; aesop;

/-- Alternative D0: no discount.  This is the only universal choice compatible
with the original exact accounting identity for strictly positive positions. -/
def distanceIdentity (_prisk _p : ℝ) : ℝ := 1

/-- Alternative D1: a two-band EVM-friendly distance.  It needs one absolute
subtraction, one comparison, and no division. -/
noncomputable def distanceBand (floor tol prisk p : ℝ) : ℝ :=
  if |p - prisk| ≤ tol then 1 else clamp01 floor

lemma distanceBand_mem (floor tol prisk p : ℝ) :
    0 ≤ distanceBand floor tol prisk p ∧ distanceBand floor tol prisk p ≤ 1 := by
      unfold distanceBand; split_ifs <;> [ simp +decide [ * ] ; exact ⟨ clamp01_nonneg _, clamp01_le_one _ ⟩ ] ;

lemma distanceBand_eq_one_of_close (floor tol prisk p : ℝ)
    (h : |p - prisk| ≤ tol) : distanceBand floor tol prisk p = 1 := by
      exact if_pos h

/-- Alternative D2: linear decay to zero at deviation `scale`.  `clamp01`
provides a total specification even for malformed parameters; production code
should additionally require `0 < scale`. -/
noncomputable def distanceLinear (scale prisk p : ℝ) : ℝ :=
  clamp01 (1 - |p - prisk| / scale)

lemma distanceLinear_mem (scale prisk p : ℝ) :
    0 ≤ distanceLinear scale prisk p ∧ distanceLinear scale prisk p ≤ 1 := by
      exact ⟨ clamp01_nonneg _, clamp01_le_one _ ⟩

lemma distanceLinear_self (scale prisk : ℝ) :
    distanceLinear scale prisk prisk = 1 := by
      exact show max 0 ( min 1 ( 1 - |prisk - prisk| / scale ) ) = 1 from by norm_num;

lemma distanceLinear_eq_zero_of_far (scale prisk p : ℝ) (hs : 0 < scale)
    (hfar : scale ≤ |p - prisk|) : distanceLinear scale prisk p = 0 := by
      exact max_eq_left ( by cases min_cases ( 1 : ℝ ) ( 1 - |p - prisk| / scale ) <;> nlinarith [ mul_div_cancel₀ ( |p - prisk| ) hs.ne' ] )

/-- Alternative P0: take the conservative maximum of two positive oracle
feeds, e.g. spot and TWAP. -/
def riskPriceMax (spot twap : ℝ) : ℝ := max spot twap

lemma riskPriceMax_ge_left (spot twap : ℝ) : spot ≤ riskPriceMax spot twap := by
  exact le_max_left _ _

lemma riskPriceMax_ge_right (spot twap : ℝ) : twap ≤ riskPriceMax spot twap := by
  exact le_max_right _ _

lemma riskPriceMax_pos (spot twap : ℝ) (hs : 0 < spot) : 0 < riskPriceMax spot twap := by
  exact lt_max_of_lt_left hs

/-- Alternative P1: oracle price with a clamped multiplicative premium. -/
def riskPriceBuffered (oracle premium : ℝ) : ℝ :=
  oracle * (1 + clamp01 premium)

lemma riskPriceBuffered_bounds (oracle premium : ℝ) (ho : 0 ≤ oracle) :
    oracle ≤ riskPriceBuffered oracle premium ∧ riskPriceBuffered oracle premium ≤ 2 * oracle := by
      exact ⟨ by exact le_mul_of_one_le_right ho ( by unfold clamp01; aesop ), by exact by unfold riskPriceBuffered; nlinarith [ show clamp01 premium ≤ 1 by unfold clamp01; aesop ] ⟩

lemma riskPriceBuffered_pos (oracle premium : ℝ) (ho : 0 < oracle) :
    0 < riskPriceBuffered oracle premium := by
      exact mul_pos ho ( add_pos_of_pos_of_nonneg zero_lt_one ( le_max_left _ _ ) )

/-- A haircut is a loss fraction: `h=0` keeps all value and `h=1` keeps none. -/
def haircutFactor (h : ℝ) : ℝ := clamp01 (1 - h)

/-- Conservative collateral value under a haircut. -/
def haircutValue (amount oracle h : ℝ) : ℝ := amount * oracle * haircutFactor h

lemma haircutFactor_mem (h : ℝ) :
    0 ≤ haircutFactor h ∧ haircutFactor h ≤ 1 := by
      exact ⟨ clamp01_nonneg _, clamp01_le_one _ ⟩

lemma haircutValue_bounds (amount oracle h : ℝ) (ha : 0 ≤ amount) (ho : 0 ≤ oracle) :
    0 ≤ haircutValue amount oracle h ∧ haircutValue amount oracle h ≤ amount * oracle := by
      exact ⟨ mul_nonneg ( mul_nonneg ha ho ) (RiskDesign.haircutFactor_mem h).left, mul_le_of_le_one_right ( mul_nonneg ha ho ) (RiskDesign.haircutFactor_mem h).right ⟩

/-- Equivalent risk-price convention for issuance: dividing deposits by
`oracle/(1-h)` issues the same shares as first multiplying deposits by `(1-h)`
and then dividing by `oracle`.  This convention requires `h<1`. -/
noncomputable def haircutRiskPrice (oracle h : ℝ) : ℝ := oracle / (1 - h)

lemma haircutRiskPrice_pos (oracle h : ℝ) (ho : 0 < oracle) (hh : h < 1) :
    0 < haircutRiskPrice oracle h := by
      exact div_pos ho ( sub_pos.mpr hh )

lemma haircutRiskPrice_ge_oracle (oracle h : ℝ) (ho : 0 ≤ oracle)
    (hh0 : 0 ≤ h) (hh1 : h < 1) : oracle ≤ haircutRiskPrice oracle h := by
      exact le_div_iff₀ ( by linarith ) |>.2 ( by nlinarith )

lemma issuance_haircut_equiv (deposit oracle h : ℝ) :
    deposit / haircutRiskPrice oracle h = deposit * (1 - h) / oracle := by
  unfold haircutRiskPrice
  rw [div_div_eq_mul_div]

/-! ## Exact unsigned-X96 arithmetic model -/

/-- X96 encoding of one. -/
def X96 : ℕ := 2 ^ 96

/-- Multiplication by an X96 weight, rounded down exactly as on the EVM. -/
def mulX96Down (amount weightX96 : ℕ) : ℕ := amount * weightX96 / X96

lemma X96_pos : 0 < X96 := by
  decide +revert

/-
A clamped X96 distance cannot increase an unsigned amount, even after
integer rounding.
-/
lemma mulX96Down_le (amount weightX96 : ℕ) (hw : weightX96 ≤ X96) :
    mulX96Down amount weightX96 ≤ amount := by
      exact Nat.div_le_of_le_mul <| by nlinarith;

/-
Weight one is represented exactly and preserves the amount.
-/
lemma mulX96Down_one (amount : ℕ) : mulX96Down amount X96 = amount := by
  unfold mulX96Down; norm_num [ X96 ] ;

end RiskDesign