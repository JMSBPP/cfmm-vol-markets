import Mathlib
import vol_markets.VolInstrument
import vol_markets.Main
import vol_markets.Flow
import vol_markets.GeomProfile

set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Vol order completion: endogenous maturity

This file formalizes the decided maturity-equivalence and auto-deleverage rules.
The final section deliberately gives several candidate joint variance-accrual laws:
none is selected as the protocol law pending an author decision.
-/

namespace EndogenousMaturity

/-- Implied maturity derived from target vega and variance notional. -/
noncomputable def tStar (dQvStar Nσ : ℝ) : ℝ := 2 * dQvStar / Nσ

/-- The inverse map: target vega represented by maturity and variance notional. -/
noncomputable def dQvStarOfMaturity (t Nσ : ℝ) : ℝ := (t / 2) * Nσ

/-- The maturity map followed by the inverse map recovers target vega; `Nσ ≠ 0`
is necessary because the maturity definition divides by `Nσ`. -/
theorem dQvStarOfMaturity_tStar (dQvStar Nσ : ℝ) (hNσ : Nσ ≠ 0) :
    dQvStarOfMaturity (tStar dQvStar Nσ) Nσ = dQvStar := by
  unfold dQvStarOfMaturity tStar
  field_simp [hNσ]

/-- The inverse map followed by the maturity map recovers maturity; `Nσ ≠ 0`
is necessary because the maturity definition divides by `Nσ`. -/
theorem tStar_dQvStarOfMaturity (t Nσ : ℝ) (hNσ : Nσ ≠ 0) :
    tStar (dQvStarOfMaturity t Nσ) Nσ = t := by
  unfold dQvStarOfMaturity tStar
  field_simp [hNσ]

/-- Exact maturity-equivalence identity; nonzero variance notional is required. -/
theorem maturity_equivalence (dQvStar Nσ : ℝ) (hNσ : Nσ ≠ 0) :
    dQvStar = (tStar dQvStar Nσ / 2) * Nσ := by
  unfold tStar
  field_simp [hNσ]

/-- Direct use of `VolInstrument.variancePortfolio_upsilon`: the unscaled dated
portfolio at derived maturity has vega `dQvStar / Nσ`.  A nonzero
finite-difference step is required. -/
theorem variancePortfolio_upsilon_at_tStar
    (p pStar sig2 dQvStar Nσ Δs : ℝ) (hΔs : Δs ≠ 0) :
    Upsilon.upsilon
      (fun s2 => VolInstrument.variancePortfolio p pStar s2 (tStar dQvStar Nσ))
      sig2 Δs = dQvStar / Nσ := by
  rw [VolInstrument.variancePortfolio_upsilon p pStar sig2 (tStar dQvStar Nσ) Δs hΔs]
  unfold tStar
  ring

/-- Vega bridge to `variancePortfolio_upsilon`: scaling the dated portfolio by
`Nσ` gives vega `dQvStar` at the derived maturity.  Both `Nσ` and the variance
finite-difference step must be nonzero. -/
theorem tStar_variancePortfolio_upsilon
    (p pStar sig2 dQvStar Nσ Δs : ℝ) (hNσ : Nσ ≠ 0) (hΔs : Δs ≠ 0) :
    Upsilon.upsilon
        (fun s2 => Nσ * VolInstrument.variancePortfolio p pStar s2
          (tStar dQvStar Nσ)) sig2 Δs = dQvStar := by
  unfold Upsilon.upsilon VolInstrument.variancePortfolio tStar
  field_simp
  ring

/-- Equivalent unit-normalized bridge: target vega times the `(2/t)` normalized
Demeterfi portfolio has vega exactly `dQvStar`.  Nonzero target vega, notional,
and finite-difference step ensure all displayed divisions are defined. -/
theorem tStar_unit_upsilon
    (p pStar sig2 dQvStar Nσ Δs : ℝ)
    (hdQv : dQvStar ≠ 0) (hNσ : Nσ ≠ 0) (hΔs : Δs ≠ 0) :
    Upsilon.upsilon
      (fun s2 => dQvStar * ((2 / tStar dQvStar Nσ) *
        VolInstrument.variancePortfolio p pStar s2 (tStar dQvStar Nσ)))
      sig2 Δs = dQvStar := by
  have ht : tStar dQvStar Nσ ≠ 0 := by
    simp [tStar, hdQv, hNσ]
  rw [show (fun s2 => dQvStar * ((2 / tStar dQvStar Nσ) *
      VolInstrument.variancePortfolio p pStar s2 (tStar dQvStar Nσ))) =
      (fun s2 => dQvStar * ((2 / tStar dQvStar Nσ) *
      VolInstrument.variancePortfolio p pStar s2 (tStar dQvStar Nσ))) from rfl]
  unfold Upsilon.upsilon VolInstrument.variancePortfolio tStar
  field_simp
  ring

/-- Positive target vega and variance notional give positive implied maturity. -/
theorem tStar_pos (dQvStar Nσ : ℝ) (hdQv : 0 < dQvStar) (hNσ : 0 < Nσ) :
    0 < tStar dQvStar Nσ := by
  exact div_pos (mul_pos (by norm_num) hdQv) hNσ

/-- At fixed positive notional, implied maturity is strictly increasing in target vega. -/
theorem tStar_strictMono_dQvStar (Nσ : ℝ) (hNσ : 0 < Nσ) :
    StrictMono (fun dQvStar => tStar dQvStar Nσ) := by
  intro a b hab
  exact div_lt_div_of_pos_right (mul_lt_mul_of_pos_left hab (by norm_num)) hNσ

/-- At fixed positive target vega, implied maturity is strictly decreasing in
positive variance notional. -/
theorem tStar_strictAnti_Nσ (dQvStar : ℝ) (hdQv : 0 < dQvStar) :
    StrictAntiOn (fun Nσ => tStar dQvStar Nσ) (Set.Ioi 0) := by
  intro a ha b hb hab
  unfold tStar
  exact (div_lt_div_iff₀ hb ha).2 (by nlinarith)

/-- Required live collateral at the current volatility price. -/
noncomputable def dMReq (dQvStar pvol : ℝ) : ℝ := dQvStar * pvol

/-- Decided funded exposure: target exposure capped at the money-to-shares flow
`QM / prisk`. -/
noncomputable def dQvFunded (QM prisk dQvStar : ℝ) : ℝ :=
  min dQvStar (Flow.deltaShares QM prisk)

/-- Recalibrated maturity derived from funded exposure. -/
noncomputable def tStarFunded (QM prisk dQvStar Nσ : ℝ) : ℝ :=
  tStar (dQvFunded QM prisk dQvStar) Nσ

/-- Funded exposure always satisfies the quotient form of admissibility. -/
theorem dQvFunded_admissible (QM prisk dQvStar : ℝ) :
    dQvFunded QM prisk dQvStar ≤ QM / prisk := by
  exact min_le_right _ _

/-- Connection to the project's division-free admissibility anchor. -/
theorem dQvFunded_admissible_iff_mul (QM prisk dQvStar : ℝ) (hprisk : 0 < prisk) :
    dQvFunded QM prisk dQvStar ≤ QM / prisk ↔
      dQvFunded QM prisk dQvStar * prisk ≤ QM := by
  exact EVMDesignSpace.admissible_iff_mul _ _ _ hprisk

/-- On a collateral violation (equality included), funded exposure is admissible
in the division-free form.  Positivity of `prisk` is required. -/
theorem dQvFunded_mul_le_of_violation (QM prisk dQvStar : ℝ)
    (hprisk : 0 < prisk) (_hviolation : QM ≤ dQvStar * prisk) :
    dQvFunded QM prisk dQvStar * prisk ≤ QM := by
  exact (EVMDesignSpace.admissible_iff_mul _ _ _ hprisk).1
    (dQvFunded_admissible QM prisk dQvStar)

/-- Without a collateral violation, exposure remains exactly at its target.
Positivity of `prisk` is required to pass between quotient and product forms. -/
theorem dQvFunded_eq_of_no_violation (QM prisk dQvStar : ℝ)
    (hprisk : 0 < prisk) (h : dQvStar * prisk ≤ QM) :
    dQvFunded QM prisk dQvStar = dQvStar := by
  apply min_eq_left
  exact (EVMDesignSpace.admissible_iff_mul _ _ _ hprisk).2 h

/-- The funded exposure is the greatest nonnegative exposure bounded by both the
target and the division-free collateral constraint.  `prisk > 0` is required. -/
theorem dQvFunded_maximal (QM prisk dQvStar x : ℝ) (hprisk : 0 < prisk)
    (_hx0 : 0 ≤ x) (hxTarget : x ≤ dQvStar) (hxQM : x * prisk ≤ QM) :
    x ≤ dQvFunded QM prisk dQvStar := by
  exact le_min hxTarget ((EVMDesignSpace.admissible_iff_mul _ _ _ hprisk).2 hxQM)

/-- Funded maturity is monotone in available money when `Nσ > 0`. -/
theorem tStarFunded_mono_QM (prisk dQvStar Nσ : ℝ)
    (hprisk : 0 < prisk) (hNσ : 0 < Nσ) :
    Monotone (fun QM => tStarFunded QM prisk dQvStar Nσ) := by
  intro a b hab
  unfold tStarFunded tStar dQvFunded Flow.deltaShares
  exact div_le_div_of_nonneg_right
    (mul_le_mul_of_nonneg_left (min_le_min_left _ (div_le_div_of_nonneg_right hab hprisk.le)) (by norm_num))
    hNσ.le

/-- Funded maturity is antitone in a positive risk price when money is
nonnegative.  This global statement includes, and is stronger than, the
floor-binding region requested in the decided law. -/
theorem tStarFunded_antitone_prisk (QM dQvStar Nσ : ℝ)
    (hQM : 0 ≤ QM) (hNσ : 0 < Nσ) :
    AntitoneOn (fun prisk => tStarFunded QM prisk dQvStar Nσ) (Set.Ioi 0) := by
  intro a ha b hb hab
  unfold tStarFunded tStar dQvFunded Flow.deltaShares
  apply div_le_div_of_nonneg_right _ hNσ.le
  apply mul_le_mul_of_nonneg_left _ (by norm_num)
  exact min_le_min_left _ (div_le_div_of_nonneg_left hQM ha hab)

/-- A sufficient top-up restores the original implied maturity.  Positive risk
price is required for the no-violation conversion. -/
theorem tStarFunded_eq_tStar_of_topup (QM prisk dQvStar Nσ : ℝ)
    (hprisk : 0 < prisk) (h : dQvStar * prisk ≤ QM) :
    tStarFunded QM prisk dQvStar Nσ = tStar dQvStar Nσ := by
  simp [tStarFunded, dQvFunded_eq_of_no_violation QM prisk dQvStar hprisk h]

/-- Zero money liquidates nonnegative target exposure.  The explicitly requested
`prisk > 0` domain condition is retained, although totalized real division makes
this particular equality true without it. -/
theorem dQvFunded_zero_QM (prisk dQvStar : ℝ)
    (hprisk : 0 < prisk) (hdQv : 0 ≤ dQvStar) :
    dQvFunded 0 prisk dQvStar = 0 := by
  simp [dQvFunded, Flow.deltaShares, hdQv]

/-- In the zero-money liquidation case recalibrated maturity is zero. -/
theorem tStarFunded_zero_QM (prisk dQvStar Nσ : ℝ)
    (hprisk : 0 < prisk) (hdQv : 0 ≤ dQvStar) :
    tStarFunded 0 prisk dQvStar Nσ = 0 := by
  simp [tStarFunded, dQvFunded_zero_QM prisk dQvStar hprisk hdQv, tStar]

/-- Real-layer floor-rounding conservativity: replacing the funded cap by any
smaller rounded-down cap can only decrease the resulting funded exposure. -/
theorem dQvFunded_roundDown (dQvStar capRounded QM prisk : ℝ)
    (hround : capRounded ≤ QM / prisk) :
    min dQvStar capRounded ≤ dQvFunded QM prisk dQvStar := by
  exact min_le_min_left dQvStar hround

/-- A nonnegative rounded-down cap preserves the division-free invariant when
`prisk > 0`. -/
theorem roundDown_preserves_invariant (dQvStar capRounded QM prisk : ℝ)
    (hprisk : 0 < prisk) (hround : capRounded ≤ QM / prisk) :
    min dQvStar capRounded * prisk ≤ QM := by
  apply (EVMDesignSpace.admissible_iff_mul _ _ _ hprisk).1
  exact (min_le_right _ _).trans hround

/-! ## Candidate joint recalibration laws — no protocol law is selected -/

/-- **CANDIDATE pending author decision.** Multiplicative remaining-variance-budget
law. Decision point: whether realized variance should contract maturity by the
positive part of the unused strike fraction. -/
noncomputable def tStarJointMult
    (QM prisk dQvStar Nσ sig2K sig2R : ℝ) : ℝ :=
  tStarFunded QM prisk dQvStar Nσ * max 0 (1 - sig2R / sig2K)

/-- **CANDIDATE pending author decision.** Subtractive variance-budget-time law.
Decision point: whether budget consumption is represented as time subtracted at
the funded rate, before flooring at zero. -/
noncomputable def tStarJointSub
    (QM prisk dQvStar Nσ sig2K sig2R : ℝ) : ℝ :=
  max 0 (tStarFunded QM prisk dQvStar Nσ -
    (tStarFunded QM prisk dQvStar Nσ / sig2K) * sig2R)

/-- **CANDIDATE pending author decision.** Quadratic budget law, included to make
explicit a different plausible response to accrued realized variance. Decision
point: linear versus nonlinear contraction in the used budget fraction. -/
noncomputable def tStarJointQuadratic
    (QM prisk dQvStar Nσ sig2K sig2R : ℝ) : ℝ :=
  tStarFunded QM prisk dQvStar Nσ * max 0 (1 - (sig2R / sig2K)^2)

/-- Multiplicative candidate is nonnegative when funded maturity is nonnegative. -/
theorem tStarJointMult_nonneg (QM prisk dQvStar Nσ sig2K sig2R : ℝ)
    (ht : 0 ≤ tStarFunded QM prisk dQvStar Nσ) :
    0 ≤ tStarJointMult QM prisk dQvStar Nσ sig2K sig2R := by
  exact mul_nonneg ht (le_max_left _ _)

/-- Multiplicative candidate contracts monotonically as realized variance rises;
positive strike variance and nonnegative funded maturity are required. -/
theorem tStarJointMult_antitone (QM prisk dQvStar Nσ sig2K : ℝ)
    (ht : 0 ≤ tStarFunded QM prisk dQvStar Nσ) (hK : 0 < sig2K) :
    Antitone (tStarJointMult QM prisk dQvStar Nσ sig2K) := by
  intro a b hab
  unfold tStarJointMult
  exact mul_le_mul_of_nonneg_left (max_le_max_left 0 (sub_le_sub_left
    (div_le_div_of_nonneg_right hab hK.le) 1)) ht

/-- Multiplicative candidate agrees with funded maturity at zero accrual. -/
theorem tStarJointMult_zero (QM prisk dQvStar Nσ sig2K : ℝ) :
    tStarJointMult QM prisk dQvStar Nσ sig2K 0 =
      tStarFunded QM prisk dQvStar Nσ := by
  simp [tStarJointMult]

/-- Multiplicative candidate reaches zero at strike-budget exhaustion. -/
theorem tStarJointMult_exhausted (QM prisk dQvStar Nσ sig2K : ℝ) (hK : sig2K ≠ 0) :
    tStarJointMult QM prisk dQvStar Nσ sig2K sig2K = 0 := by
  simp [tStarJointMult, hK]

/-- Subtractive candidate is nonnegative by construction. -/
theorem tStarJointSub_nonneg (QM prisk dQvStar Nσ sig2K sig2R : ℝ) :
    0 ≤ tStarJointSub QM prisk dQvStar Nσ sig2K sig2R := by
  exact le_max_left _ _

/-- Subtractive candidate contracts monotonically in realized variance when
strike variance is positive and funded maturity is nonnegative. -/
theorem tStarJointSub_antitone (QM prisk dQvStar Nσ sig2K : ℝ)
    (ht : 0 ≤ tStarFunded QM prisk dQvStar Nσ) (hK : 0 < sig2K) :
    Antitone (tStarJointSub QM prisk dQvStar Nσ sig2K) := by
  intro a b hab
  unfold tStarJointSub
  apply max_le_max_left
  exact sub_le_sub_left (mul_le_mul_of_nonneg_left hab (div_nonneg ht hK.le)) _

/-- Subtractive candidate agrees with funded maturity at zero accrual, provided
funded maturity is nonnegative. -/
theorem tStarJointSub_zero (QM prisk dQvStar Nσ sig2K : ℝ)
    (ht : 0 ≤ tStarFunded QM prisk dQvStar Nσ) :
    tStarJointSub QM prisk dQvStar Nσ sig2K 0 =
      tStarFunded QM prisk dQvStar Nσ := by
  simp [tStarJointSub, ht]

/-- Subtractive candidate reaches zero at exhaustion; nonzero strike variance is required. -/
theorem tStarJointSub_exhausted (QM prisk dQvStar Nσ sig2K : ℝ) (hK : sig2K ≠ 0) :
    tStarJointSub QM prisk dQvStar Nσ sig2K sig2K = 0 := by
  simp [tStarJointSub, hK]

/-- Quadratic candidate is nonnegative when funded maturity is nonnegative. -/
theorem tStarJointQuadratic_nonneg (QM prisk dQvStar Nσ sig2K sig2R : ℝ)
    (ht : 0 ≤ tStarFunded QM prisk dQvStar Nσ) :
    0 ≤ tStarJointQuadratic QM prisk dQvStar Nσ sig2K sig2R := by
  exact mul_nonneg ht (le_max_left _ _)

/-- On the economically relevant nonnegative-realized-variance domain, the
quadratic candidate contracts monotonically; positive strike and nonnegative
funded maturity are required. -/
theorem tStarJointQuadratic_antitone (QM prisk dQvStar Nσ sig2K : ℝ)
    (ht : 0 ≤ tStarFunded QM prisk dQvStar Nσ) (hK : 0 < sig2K) :
    AntitoneOn (tStarJointQuadratic QM prisk dQvStar Nσ sig2K) (Set.Ici 0) := by
  intro a ha b hb hab
  unfold tStarJointQuadratic
  apply mul_le_mul_of_nonneg_left _ ht
  apply max_le_max_left
  apply sub_le_sub_left
  exact (sq_le_sq₀ (div_nonneg ha hK.le)
    (div_nonneg hb hK.le)).2 (div_le_div_of_nonneg_right hab hK.le)

/-- Quadratic candidate agrees with funded maturity at zero accrual. -/
theorem tStarJointQuadratic_zero (QM prisk dQvStar Nσ sig2K : ℝ) :
    tStarJointQuadratic QM prisk dQvStar Nσ sig2K 0 =
      tStarFunded QM prisk dQvStar Nσ := by
  simp [tStarJointQuadratic]

/-- Quadratic candidate reaches zero at strike-budget exhaustion. -/
theorem tStarJointQuadratic_exhausted (QM prisk dQvStar Nσ sig2K : ℝ) (hK : sig2K ≠ 0) :
    tStarJointQuadratic QM prisk dQvStar Nσ sig2K sig2K = 0 := by
  simp [tStarJointQuadratic, hK]

/-- The author decision is substantive: at an explicit funded position and
half-consumed variance budget, the linear multiplicative and quadratic candidates
give different maturities. -/
theorem joint_candidates_disagree :
    tStarJointMult 2 1 2 2 2 1 ≠ tStarJointQuadratic 2 1 2 2 2 1 := by
  norm_num [tStarJointMult, tStarJointQuadratic, tStarFunded, tStar,
    dQvFunded, Flow.deltaShares]

end EndogenousMaturity
