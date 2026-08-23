import Mathlib
import vol_markets.VolInstrument
import exp.EtaReplication
import vol_markets.MevJointProgram

open scoped Topology
open Set Filter

set_option autoImplicit false
set_option maxHeartbeats 4000000

/-!
# The η curvature controller

This module formalizes the displayed E0–E7 curvature-controller functions.  The identification
made here is a modelling step, not a definition: `curvIndex η Δi` is a per-tick relative price
step with no liquidity term, whereas the anchor's curvature parameter is the mixing weight in
`F = (1-curv) A F₀ + curv F₁` and enters its trading constraints structurally.  Equal price steps
with different per-tick liquidity need not have equal slippage per unit traded.  Putting
`curvIndex` into that parameter slot is therefore an assumption.

The equilibrium transfer is likewise assumed, not derived.  Deriving it would require solving
the anchor's arbitrageur and investor constraints on the discrete grid with per-tick liquidity.
Every result below concerns the displayed real functions and their compositions with `curvIndex`;
it is not a theorem about this project's AMM.

The two arbitrage objects are not identified: `arbLossRatio` is not
`MevOptimization.mevMulti`.  They belong to different models and units.  Welfare remains open:
only deposit efficiency is transcribed.  In particular, below the peak LP payoff rises while
investor surplus falls, and the anchor's welfare ranking also treats arbitrage rent as deadweight
because miners are outside its agent set, unlike rent-recycling MEV premises.  Gas is absorbed,
not modelled (the anchor's Assumption 3).

The `Θ_φ`-restricted, volatility-varying MEV comparison remains an inherited open item and is
untouched.  A pointwise fee path would make `etaStar` volatility-indexed while grid η is a design
constant; reconciling these is open.  Every strict peak result is explicitly bounded by the
condition `0 < cOne`; in the complementary freeze region no such strict peak is claimed.
-/

namespace EtaCurvature

noncomputable def kphiS (premShock fee : ℝ) : ℝ :=
  1 - Real.sqrt ((1 + fee) / (1 + premShock))

noncomputable def arbLossRatio (probArb premShock fee curv : ℝ) : ℝ :=
  probArb / 2 * (if curv ≤ kphiS premShock fee then
    (1 + premShock) - (1 + fee) / (1 - curv)
  else (1 + premShock) * (kphiS premShock fee) ^ 2 / curv)

noncomputable def kphiI (premInv fee : ℝ) : ℝ :=
  1 - Real.sqrt ((1 + fee) / (1 + premInv))

noncomputable def surplusRatio (premInv fee curv : ℝ) : ℝ :=
  1 / 2 * (if curv ≤ kphiI premInv fee then
    (1 + premInv) - (1 + fee) / (1 - curv)
  else (1 + premInv) * (kphiI premInv fee) ^ 2 / curv)

private lemma sqrt_ratio_bounds {prem fee : ℝ} (hfee : 0 ≤ fee) (h : fee < prem) :
    0 < Real.sqrt ((1 + fee) / (1 + prem)) ∧
      Real.sqrt ((1 + fee) / (1 + prem)) < 1 := by
  have h1 : 0 < 1 + fee := by linarith
  have h2 : 0 < 1 + prem := by linarith
  have h3 : (1 + fee) / (1 + prem) > 0 := div_pos h1 h2
  have h4 : (1 + fee) / (1 + prem) < 1 ^ 2 := by
    simp only [one_pow]
    rw [div_lt_one h2]
    linarith
  constructor
  · exact Real.sqrt_pos.mpr h3
  · exact Real.sqrt_lt' one_pos |>.mpr h4

/-- T2': the shock branch point is strictly interior. -/
theorem kphiS_mem_Ioo (premShock fee : ℝ) (hfee : 0 ≤ fee) (h : fee < premShock) :
    kphiS premShock fee ∈ Ioo (0 : ℝ) 1 := by
  unfold kphiS
  have hb := sqrt_ratio_bounds hfee h
  constructor <;> linarith

/-- T3': the two arbitrage-loss formulas agree at their branch point. -/
theorem arbLossRatio_branch_agree (probArb premShock fee : ℝ)
    (hfee : 0 ≤ fee) (h : fee < premShock) :
    probArb / 2 * ((1 + premShock) - (1 + fee) / (1 - kphiS premShock fee)) =
      probArb / 2 * ((1 + premShock) * (kphiS premShock fee) ^ 2 /
        kphiS premShock fee) ∧
    probArb / 2 * ((1 + premShock) - (1 + fee) / (1 - kphiS premShock fee)) =
      probArb / 2 * (1 + premShock) *
        (1 - Real.sqrt ((1 + fee) / (1 + premShock))) := by
  have hp : 0 < 1 + premShock := by linarith
  have hfr : (1 + fee) / (1 + premShock) > 0 := div_pos (by linarith : 0 < 1 + fee) hp
  have hf1 : (1 + fee) / (1 + premShock) < 1 := by
    rw [div_lt_one hp]
    linarith
  set r := Real.sqrt ((1 + fee) / (1 + premShock)) with hr_def
  have hr_pos : 0 < r := Real.sqrt_pos.mpr hfr
  have hr_lt_1 : r < 1 := by
    nlinarith [Real.sq_sqrt (le_of_lt hfr)]
  have hk_ne_zero : kphiS premShock fee ≠ 0 := by
    simp [kphiS]
    linarith
  have h1_minus_kphiS : 1 - kphiS premShock fee = r := by simp [kphiS, hr_def]
  have hr_sq : r ^ 2 = (1 + fee) / (1 + premShock) := Real.sq_sqrt (le_of_lt hfr)
  -- Key identity: (1 + premShock) - (1 + fee) / r = (1 + premShock) * (1 - r)
  have hfee_eq : (1 + fee) = r ^ 2 * (1 + premShock) := by
    rw [hr_sq]; field_simp
  have key : (1 + premShock) - (1 + fee) / r = (1 + premShock) * (1 - r) := by
    rw [hfee_eq]
    field_simp [hr_pos.ne']
  rw [h1_minus_kphiS]
  constructor
  · rw [key]
    field_simp [hk_ne_zero]
    rw [← h1_minus_kphiS]
    ring
  · rw [key]
    ring

/-- T4': arbitrage loss is strictly antitone on the guarded curvature domain. -/
theorem arbLossRatio_strictAntiOn (probArb premShock fee : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hA : 0 < probArb) :
    StrictAntiOn (arbLossRatio probArb premShock fee) (Ioc (0 : ℝ) 1) := by
  unfold StrictAntiOn
  intro x hx y hy hxy
  unfold arbLossRatio
  have hpos : 0 < probArb / 2 := by linarith
  rw [mul_lt_mul_iff_of_pos_left hpos]
  set k := kphiS premShock fee with hk_def
  have hk_mem : k ∈ Ioo (0 : ℝ) 1 := kphiS_mem_Ioo premShock fee hfee hS
  have hfee_pos : 0 < 1 + fee := by linarith
  -- Case analysis on x and y relative to k
  by_cases hxk : x ≤ k
  by_cases hyk : y ≤ k
  · -- Both x, y ≤ k: first branch
    simp only [hyk, hxk, ite_true]
    -- Goal: 1 + premShock - (1 + fee) / (1 - y) < 1 + premShock - (1 + fee) / (1 - x)
    -- Equiv: (1 + fee) / (1 - x) < (1 + fee) / (1 - y)
    have hk_lt_1 := hk_mem.2
    have hx_lt_1 : x < 1 := lt_of_le_of_lt hxk hk_lt_1
    have hy_lt_1 : y < 1 := lt_of_le_of_lt hyk hk_lt_1
    have hx_pos : 0 < x := hx.1
    have hy_pos : 0 < y := hy.1
    have h1mx : 0 < 1 - x := by linarith
    have h1my : 0 < 1 - y := by linarith
    rw [sub_lt_sub_iff_left]
    rw [div_lt_div_iff₀ h1mx h1my]
    nlinarith
  · -- x ≤ k, y > k: cross boundary
    simp only [hyk, hxk, ite_true, ite_false]
    -- Strategy:
    -- 1. (1 + premShock) * k^2 / y < (1 + premShock) * k^2 / k = (1 + premShock) * k
    -- 2. 1 + premShock - (1 + fee)/(1 - x) ≥ 1 + premShock - (1 + fee)/(1 - k) (since x ≤ k)
    -- 3. By arbLossRatio_branch_agree, value at k is (1 + premShock) * k
    have hk_pos := hk_mem.1
    have hy_gt_k := not_le.mp hyk
    -- LHS: (1 + premShock) * k^2 / y < (1 + premShock) * k
    have hLHS : (1 + premShock) * k ^ 2 / y < (1 + premShock) * k := by
      rw [div_lt_iff₀ (hy.1)]
      have h1p_pos : 0 < 1 + premShock := by linarith
      have hky : k * y > k ^ 2 := by nlinarith
      nlinarith
    -- By arbLossRatio_branch_agree, at curv = k:
    -- (1 + premShock) - (1 + fee) / (1 - k) = (1 + premShock) * k
    have hbranch := arbLossRatio_branch_agree probArb premShock fee hfee hS
    -- The second component says: probArb / 2 * (...) = probArb / 2 * (1 + premShock) * (1 - sqrt(...))
    -- where 1 - sqrt(...) = k
    -- So: (1 + premShock) - (1 + fee) / (1 - k) = (1 + premShock) * k
    have h1p_k : 1 + premShock - (1 + fee) / (1 - k) = (1 + premShock) * k := by
      have := hbranch.2
      have hk_eq : k = 1 - Real.sqrt ((1 + fee) / (1 + premShock)) := by simp [hk_def, kphiS]
      have heq : (1 + premShock) - (1 + fee) / (1 - kphiS premShock fee) = (1 + premShock) * (1 - Real.sqrt ((1 + fee) / (1 + premShock))) := by
        have hne : probArb / 2 ≠ 0 := hpos.ne'
        nlinarith [this, sq_nonneg (probArb / 2)]
      simp_all
    -- Now: (1 + premShock) * k^2 / y < (1 + premShock) * k = 1 + premShock - (1 + fee) / (1 - k)
    -- And since x ≤ k: 1 + premShock - (1 + fee) / (1 - x) ≥ 1 + premShock - (1 + fee) / (1 - k)
    have hx_lt_1 : x < 1 := lt_of_le_of_lt hxk hk_mem.2
    have h1mx : 0 < 1 - x := by linarith
    have h1mk : 0 < 1 - k := by linarith [hk_mem.2]
    have hdiv_le : (1 + fee) / (1 - x) ≤ (1 + fee) / (1 - k) := by
      rw [div_le_div_iff₀ h1mx h1mk]
      nlinarith
    linarith
  · -- x > k
    have hyk' : ¬(y ≤ k) := not_le.mpr (lt_trans (not_le.mp hxk) hxy)
    simp only [hyk', hxk, ite_false, ite_false]
    -- Case: both x, y > k, show const / y < const / x
    have hk_sq_pos : 0 < (1 + premShock) * k ^ 2 := by
      have := hk_mem.1
      nlinarith
    have hx_pos : 0 < x := hx.1
    have hy_pos : 0 < y := hy.1
    rw [div_lt_div_iff₀ hy_pos hx_pos]
    nlinarith

/-- T5': arbitrage loss is positive in the trade-occurrence region.

For `premShock < fee`, Lemma 1's zero-loss economics lives in the occurrence indicator frozen
into the free constant `ϖ_A` and is NOT expressible in the transcribed formula — recorded,
not claimed. -/
theorem arbLossRatio_pos (probArb premShock fee curv : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hA : 0 < probArb)
    (hc : curv ∈ Ioc (0 : ℝ) 1) :
    0 < arbLossRatio probArb premShock fee curv := by
  unfold arbLossRatio
  have hpos : 0 < probArb / 2 := by linarith
  have hk_mem : kphiS premShock fee ∈ Ioo (0 : ℝ) 1 := kphiS_mem_Ioo premShock fee hfee hS
  rw [mul_pos_iff]
  left
  refine ⟨hpos, ?_⟩
  have hc1 : 0 < curv := hc.1
  have hc2 : curv ≤ 1 := hc.2
  have hfee_lt : fee < premShock := hS
  have h1p_pos : 0 < 1 + premShock := by linarith
  by_cases hcurv_le_k : curv ≤ kphiS premShock fee
  · -- Case: curv ≤ kphiS premShock fee
    simp [hcurv_le_k]
    -- Use branch agreement: value at kphiS = (1 + premShock) * kphiS
    have hbranch := arbLossRatio_branch_agree probArb premShock fee hfee hS
    have hval_at_k : (1 + premShock) - (1 + fee) / (1 - kphiS premShock fee) =
      (1 + premShock) * kphiS premShock fee := by
      have hbranch2 := hbranch.2
      have hne : probArb / 2 ≠ 0 := hpos.ne'
      -- kphiS = 1 - √((1 + fee) / (1 + premShock)), so 1 - √(...) = kphiS
      have hk_def : kphiS premShock fee = 1 - Real.sqrt ((1 + fee) / (1 + premShock)) := rfl
      have h1sqrt : 1 - Real.sqrt ((1 + fee) / (1 + premShock)) = kphiS premShock fee := by linarith [hk_def]
      -- From hbranch2: probArb/2 * (...) = probArb/2 * (1+premShock) * (1 - √(...))
      -- Since 1 - √(...) = kphiS, RHS = probArb/2 * (1+premShock) * kphiS
      rw [h1sqrt] at hbranch2
      have heq : probArb / 2 * (1 + premShock) * kphiS premShock fee =
        probArb / 2 * ((1 + premShock) * kphiS premShock fee) := by ring
      rw [heq] at hbranch2
      exact mul_left_cancel₀ hne hbranch2
    -- Since curv ≤ kphiS, we have 1 - curv ≥ 1 - kphiS > 0
    -- So (1 + fee) / (1 - curv) ≤ (1 + fee) / (1 - kphiS)
    -- Thus (1 + premShock) - (1 + fee) / (1 - curv) ≥ (1 + premShock) * kphiS > 0
    have hk_pos := hk_mem.1
    have hk_lt_1 := hk_mem.2
    have h1mk : 0 < 1 - kphiS premShock fee := by linarith
    have hcurv_lt_1 : curv < 1 := lt_of_le_of_lt hcurv_le_k hk_lt_1
    have h1mc : 0 < 1 - curv := by linarith
    have hdiv_le : (1 + fee) / (1 - curv) ≤ (1 + fee) / (1 - kphiS premShock fee) := by
      rw [div_le_div_iff₀ h1mc h1mk]
      have h1f_pos : 0 < 1 + fee := by linarith
      nlinarith
    -- From hval_at_k: (1 + fee) / (1 - kphiS) = (1 + premShock) * (1 - kphiS)
    have hfee_kphi_eq : (1 + fee) / (1 - kphiS premShock fee) = (1 + premShock) * (1 - kphiS premShock fee) := by
      linarith
    -- So (1 + fee) / (1 - curv) ≤ (1 + premShock) * (1 - kphiS) < 1 + premShock
    have hkphi_pos : 0 < kphiS premShock fee := hk_pos
    have h1mk_lt_1 : 1 - kphiS premShock fee < 1 := by linarith
    have hfee_bound : (1 + fee) / (1 - curv) ≤ (1 + premShock) * (1 - kphiS premShock fee) := by
      linarith
    have hfee_lt_1p : (1 + fee) / (1 - curv) < 1 + premShock := by
      calc (1 + fee) / (1 - curv) ≤ (1 + premShock) * (1 - kphiS premShock fee) := hfee_bound
        _ < (1 + premShock) * 1 := by nlinarith
        _ = 1 + premShock := by ring
    linarith
  · -- Case: curv > kphiS premShock fee
    push_neg at hcurv_le_k
    have hk_pos : 0 < kphiS premShock fee := hk_mem.1
    have hif : (if curv ≤ kphiS premShock fee then (1 + premShock) - (1 + fee) / (1 - curv)
      else (1 + premShock) * kphiS premShock fee ^ 2 / curv) =
      (1 + premShock) * kphiS premShock fee ^ 2 / curv := by simp [hcurv_le_k]
    rw [hif]
    exact div_pos (mul_pos h1p_pos (sq_pos_of_pos hk_pos)) hc1

theorem kphiS_eq_zero_of_eq (premShock fee : ℝ) (hfee : 0 ≤ fee)
    (h : premShock = fee) : kphiS premShock fee = 0 := by
  subst premShock
  unfold kphiS
  have hpos : 0 < 1 + fee := by linarith
  rw [div_self (ne_of_gt hpos), Real.sqrt_one]
  norm_num

theorem arbLossRatio_eq_zero_of_kphiS_eq_zero (probArb premShock fee : ℝ)
    (hfee : 0 ≤ fee) (h : premShock = fee) :
    arbLossRatio probArb premShock fee 0 = 0 := by
  rw [h]
  unfold arbLossRatio kphiS
  simp

/-- T7': per-investor surplus is strictly antitone. -/
theorem surplusRatio_strictAntiOn (premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hI : fee < premInv) :
    StrictAntiOn (surplusRatio premInv fee) (Ioc (0 : ℝ) 1) := by
  simpa [surplusRatio, arbLossRatio, kphiI, kphiS] using
    (arbLossRatio_strictAntiOn 1 premInv fee hfee hI (by norm_num))

/-- T8': premium ordering is exactly branch-point ordering, with both sqrt guards explicit. -/
theorem kphiS_le_kphiI_iff {premShock premInv fee : ℝ}
    (hfee : 0 ≤ fee) (hS : -1 < premShock) (hI : -1 < premInv) :
    premShock ≤ premInv ↔ kphiS premShock fee ≤ kphiI premInv fee := by
  simp only [kphiS, kphiI]
  rw [sub_le_sub_iff_left]
  have h1S : 0 < 1 + premShock := by linarith
  have h1I : 0 < 1 + premInv := by linarith
  have h1f : 0 < 1 + fee := by linarith
  have hposS : 0 ≤ (1 + fee) / (1 + premShock) := div_nonneg (by linarith) (by linarith)
  rw [Real.sqrt_le_sqrt_iff hposS]
  rw [div_le_div_iff₀ h1I h1S]
  constructor <;> intro h <;> nlinarith

noncomputable def cThree (probInv probArb premShock fee curv : ℝ) : ℝ :=
  probInv / 2 * ((1 + fee) / (1 - curv) - 1) -
    probArb / 2 * ((1 + premShock) - (1 + fee) / (1 - curv))

noncomputable def cTwo (probInv probArb premShock fee curv : ℝ) : ℝ :=
  probInv / 2 * ((1 + fee) / (1 - curv) - 1) -
    probArb / 2 * ((1 + premShock) * (kphiS premShock fee) ^ 2 / curv)

noncomputable def cOne (probInv probArb premShock premInv fee : ℝ) : ℝ :=
  probInv / 2 * (1 + fee - Real.sqrt ((1 + fee) / (1 + premInv))) *
      (Real.sqrt ((1 + premInv) / (1 + fee)) - 1) -
    probArb / 2 * ((1 + premShock) * (kphiS premShock fee) ^ 2)

noncomputable def lpExcess
    (probInv probArb coefD premShock premInv fee curv : ℝ) : ℝ :=
  (if curv ≤ kphiS premShock fee then cThree probInv probArb premShock fee curv
   else if curv ≤ kphiI premInv fee then cTwo probInv probArb premShock fee curv
   else cOne probInv probArb premShock premInv fee / curv) - coefD * premShock

/-- T10'a: the lower LP-return branches agree at `kphiS`. -/
theorem lpExcess_branch_agree_kphiS (probInv probArb premShock fee : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) :
    cThree probInv probArb premShock fee (kphiS premShock fee) =
      cTwo probInv probArb premShock fee (kphiS premShock fee) := by
  unfold cThree cTwo
  have h := (arbLossRatio_branch_agree probArb premShock fee hfee hS).1
  linarith

/-- T10'b: the middle and upper LP-return branches agree at `kphiI`. -/
theorem lpExcess_branch_agree_kphiI (probInv probArb premShock premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hI : fee < premInv) :
    cTwo probInv probArb premShock fee (kphiI premInv fee) =
      cOne probInv probArb premShock premInv fee / kphiI premInv fee := by
  unfold cTwo cOne kphiI
  set r := Real.sqrt ((1 + fee) / (1 + premInv)) with hr_def
  have h1p_pos : 0 < 1 + premInv := by linarith
  have h1f_pos : 0 < 1 + fee := by linarith
  have hr_pos : 0 < r := Real.sqrt_pos.mpr (div_pos h1f_pos h1p_pos)
  have hr_lt_1 : r < 1 := by
    have h : (1 + fee) / (1 + premInv) < 1 := by rw [div_lt_one h1p_pos]; linarith
    nlinarith [Real.sq_sqrt (le_of_lt (div_pos h1f_pos h1p_pos))]
  have hkphiI_ne_zero : 1 - r ≠ 0 := by linarith
  have h1mr_pos : 0 < 1 - r := by linarith
  have hinv_sqrt : Real.sqrt ((1 + premInv) / (1 + fee)) = 1 / r := by
    rw [one_div, ← Real.sqrt_inv]
    congr 1; field_simp
  -- Simplify 1 - (1 - r) = r
  have h1_sub_1_sub_r : 1 - (1 - r) = r := by ring
  rw [h1_sub_1_sub_r]
  -- Investor term identity
  have hinv_eq : (1 + fee) / r - 1 = (1 + fee - r) * (1 / r - 1) / (1 - r) := by
    field_simp [hr_pos.ne', h1mr_pos.ne']
  rw [hinv_eq, hinv_sqrt]
  field_simp [hkphiI_ne_zero]

/-- T11': strict increase up to the investor regime switch. -/
theorem lpExcess_strictMonoOn (probInv probArb coefD premShock premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hI : 0 < probInv) :
    StrictMonoOn (lpExcess probInv probArb coefD premShock premInv fee)
      (Icc (0 : ℝ) (kphiI premInv fee)) := by
  have hk_order : kphiS premShock fee ≤ kphiI premInv fee := by
    have h1S : -1 < premShock := by linarith
    have h1I : -1 < premInv := by linarith
    exact (kphiS_le_kphiI_iff hfee h1S h1I).mp hord
  intro x hx y hy hxy
  -- Case split on whether y is in first or second branch
  by_cases hy_le_kphiS : y ≤ kphiS premShock fee
  · -- Case: y ≤ kphiS, so x < y ≤ kphiS, both in first branch
    have hx_le_kphiS : x ≤ kphiS premShock fee := le_trans (le_of_lt hxy) hy_le_kphiS
    simp [lpExcess, hx_le_kphiS, hy_le_kphiS]
    unfold cThree
    -- Key: cThree = ((probInv + probArb) / 2) * (1 + fee) / (1 - curv) - const
    -- So it's strictly increasing when 1 - curv > 0
    have hfee_pos : 0 < 1 + fee := by linarith
    have hprob_pos : 0 < probInv + probArb := by linarith
    have hkphiI_lt_1 : kphiI premInv fee < 1 := by
      unfold kphiI
      have h1p_pos : 0 < 1 + premInv := by linarith
      have h1f_pos : 0 < 1 + fee := hfee_pos
      have h_sqrt_pos : 0 < Real.sqrt ((1 + fee) / (1 + premInv)) :=
        Real.sqrt_pos.mpr (div_pos h1f_pos h1p_pos)
      linarith
    have hx_lt_1 : x < 1 := lt_of_le_of_lt hx.2 hkphiI_lt_1
    have hy_lt_1 : y < 1 := lt_of_le_of_lt hy.2 hkphiI_lt_1
    have h1mx_pos : 0 < 1 - x := by linarith
    have h1my_pos : 0 < 1 - y := by linarith
    have h1my_lt_1mx : 1 - y < 1 - x := by linarith
    -- A = ((probInv + probArb) / 2) * (1 + fee) > 0
    set A := (probInv + probArb) / 2 * (1 + fee) with hA_def
    have hA_pos : 0 < A := by exact mul_pos (by linarith : 0 < (probInv + probArb) / 2) hfee_pos
    -- Goal equivalent to A / (1 - x) < A / (1 - y)
    have heq : probInv / 2 * ((1 + fee) / (1 - x) - 1) - probArb / 2 * (1 + premShock - (1 + fee) / (1 - x)) =
      A / (1 - x) - (probInv / 2 + probArb / 2 * (1 + premShock)) := by ring
    have heq2 : probInv / 2 * ((1 + fee) / (1 - y) - 1) - probArb / 2 * (1 + premShock - (1 + fee) / (1 - y)) =
      A / (1 - y) - (probInv / 2 + probArb / 2 * (1 + premShock)) := by ring
    rw [heq, heq2]
    exact sub_lt_sub_right (div_lt_div_of_pos_left hA_pos h1my_pos h1my_lt_1mx) _
  · -- Case: y > kphiS
    push_neg at hy_le_kphiS
    by_cases hx_le_kphiS2 : x ≤ kphiS premShock fee
    · -- Subcase: x ≤ kphiS < y, cross boundary
      -- Strategy: cThree x ≤ cThree kphiS = cTwo kphiS < cTwo y
      have hx_le_kphiI : x ≤ kphiI premInv fee := hx.2
      have hy_le_kphiI : y ≤ kphiI premInv fee := hy.2
      simp only [lpExcess, if_pos hx_le_kphiS2, if_neg (not_le.mpr hy_le_kphiS), hx_le_kphiI, hy_le_kphiI, ite_true]
      -- lpExcess x = cThree x - coefD * premShock
      -- lpExcess y = cTwo y - coefD * premShock
      -- Need: cThree x < cTwo y
      -- Use: cThree x ≤ cThree kphiS = cTwo kphiS < cTwo y
      have hcThree_kphi : cThree probInv probArb premShock fee (kphiS premShock fee) =
                          cTwo probInv probArb premShock fee (kphiS premShock fee) :=
        lpExcess_branch_agree_kphiS probInv probArb premShock fee hfee hS
      -- Need cThree x < cTwo y
      -- Case: x < kphiS → cThree x < cThree kphiS = cTwo kphiS
      -- Case: x = kphiS → cThree x = cThree kphiS = cTwo kphiS
      -- Then cTwo kphiS < cTwo y since kphiS < y and cTwo is increasing
      -- Common setup for both branches
      have hkphi_mem : kphiS premShock fee ∈ Ioo (0 : ℝ) 1 := kphiS_mem_Ioo premShock fee hfee hS
      have hkphi_pos : 0 < kphiS premShock fee := hkphi_mem.1
      have hkphi_lt_1 : kphiS premShock fee < 1 := hkphi_mem.2
      have h1mk_pos : 0 < 1 - kphiS premShock fee := by linarith
      have hkphiI_lt_1 : kphiI premInv fee < 1 := by
        unfold kphiI
        have h1p_pos : 0 < 1 + premInv := by linarith
        have h1f_pos : 0 < 1 + fee := by linarith
        have h_sqrt_pos : 0 < Real.sqrt ((1 + fee) / (1 + premInv)) :=
          Real.sqrt_pos.mpr (div_pos h1f_pos h1p_pos)
        linarith
      have hy_lt_1 : y < 1 := lt_of_le_of_lt hy.2 hkphiI_lt_1
      have h1my_pos : 0 < 1 - y := by linarith
      by_cases hx_eq_kphiS : x = kphiS premShock fee
      · -- x = kphiS
        rw [hx_eq_kphiS, hcThree_kphi]
        -- Need cTwo kphiS < cTwo y
        have hkphi_pos : 0 < kphiS premShock fee := hkphi_mem.1
        have hkphi_lt_1 : kphiS premShock fee < 1 := hkphi_mem.2
        have h1mx_pos : 0 < 1 - kphiS premShock fee := by linarith
        have hkphiI_lt_1 : kphiI premInv fee < 1 := by
          unfold kphiI
          have h1p_pos : 0 < 1 + premInv := by linarith
          have h1f_pos : 0 < 1 + fee := by linarith
          have h_sqrt_pos : 0 < Real.sqrt ((1 + fee) / (1 + premInv)) :=
            Real.sqrt_pos.mpr (div_pos h1f_pos h1p_pos)
          linarith
        have hy_lt_1 : y < 1 := lt_of_le_of_lt hy.2 hkphiI_lt_1
        have h1my_pos : 0 < 1 - y := by linarith
        -- cTwo kphiS < cTwo y iff probInv/2 * ((1+fee)/(1-kphiS) - 1) - probArb/2 * (const/kphiS) <
        --                              probInv/2 * ((1+fee)/(1-y) - 1) - probArb/2 * (const/y)
        -- First term: (1+fee)/(1-curv) is decreasing in curv, so (1+fee)/(1-kphiS) < (1+fee)/(1-y)
        -- Second term: const/curv is decreasing in curv, so const/kphiS > const/y, hence -const/kphiS < -const/y
        -- Both terms increase, so cTwo is increasing
        simp only [cTwo]
        have hterm1 : probInv / 2 * ((1 + fee) / (1 - kphiS premShock fee) - 1) <
                      probInv / 2 * ((1 + fee) / (1 - y) - 1) := by
          apply mul_lt_mul_of_pos_left _ (by linarith : 0 < probInv / 2)
          have h1my_pos : 0 < 1 - y := by linarith
          have h1my_lt_1mk : 1 - y < 1 - kphiS premShock fee := by linarith
          have hdiv_lt : (1 + fee) / (1 - kphiS premShock fee) < (1 + fee) / (1 - y) := by
            rw [div_lt_div_iff₀ h1mk_pos h1my_pos]
            nlinarith
          linarith
        have hterm2 : probArb / 2 * ((1 + premShock) * kphiS premShock fee ^ 2 / kphiS premShock fee) >
                      probArb / 2 * ((1 + premShock) * kphiS premShock fee ^ 2 / y) := by
          apply mul_lt_mul_of_pos_left _ (by linarith : 0 < probArb / 2)
          have hconst_pos : 0 < (1 + premShock) * (kphiS premShock fee) ^ 2 := by
            have h1p_pos : 0 < 1 + premShock := by linarith
            exact mul_pos h1p_pos (sq_pos_of_pos hkphi_pos)
          exact div_lt_div_of_pos_left hconst_pos hkphi_pos hy_le_kphiS
        linarith
      · -- x < kphiS
        have hx_lt_kphiS : x < kphiS premShock fee := lt_of_le_of_ne hx_le_kphiS2 hx_eq_kphiS
        -- cThree x < cThree kphiS < cTwo kphiS < cTwo y
        have hx_pos : 0 ≤ x := hx.1
        have hy_lt_1 : y < 1 := lt_of_le_of_lt hy.2 hkphiI_lt_1
        have hx_lt_1 : x < 1 := lt_trans hx_lt_kphiS hkphi_lt_1
        have h1mx_pos : 0 < 1 - x := by linarith
        have h1my_pos : 0 < 1 - y := by linarith
        have h1my_lt_1mk : 1 - y < 1 - kphiS premShock fee := by linarith
        have h1mk_lt_1mx : 1 - kphiS premShock fee < 1 - x := by linarith
        -- cThree is strictly increasing: cThree x < cThree kphiS
        have hcThree_x_lt : cThree probInv probArb premShock fee x <
                            cThree probInv probArb premShock fee (kphiS premShock fee) := by
          unfold cThree
          have hfee_pos : 0 < 1 + fee := by linarith
          have hprobInv_pos : 0 < probInv / 2 := by linarith
          have hprobArb_pos : 0 < probArb / 2 := by linarith
          -- cThree = probInv/2 * ((1+fee)/(1-curv) - 1) - probArb/2 * ((1+premShock) - (1+fee)/(1-curv))
          --       = ((probInv + probArb)/2) * (1+fee)/(1-curv) - const
          -- So cThree is strictly increasing iff (1+fee)/(1-curv) is strictly increasing
          have hterm1_x : probInv / 2 * ((1 + fee) / (1 - x) - 1) <
                          probInv / 2 * ((1 + fee) / (1 - kphiS premShock fee) - 1) := by
            apply mul_lt_mul_of_pos_left _ hprobInv_pos
            have hdiv_lt : (1 + fee) / (1 - x) < (1 + fee) / (1 - kphiS premShock fee) := by
              rw [div_lt_div_iff₀ h1mx_pos h1mk_pos]
              nlinarith
            linarith
          have hterm2_x : probArb / 2 * ((1 + premShock) - (1 + fee) / (1 - x)) >
                          probArb / 2 * ((1 + premShock) - (1 + fee) / (1 - kphiS premShock fee)) := by
            apply mul_lt_mul_of_pos_left _ hprobArb_pos
            have hdiv_lt : (1 + fee) / (1 - x) < (1 + fee) / (1 - kphiS premShock fee) := by
              rw [div_lt_div_iff₀ h1mx_pos h1mk_pos]
              nlinarith
            linarith
          linarith
        -- cTwo kphiS < cTwo y (from x = kphiS case)
        have hkphiI_lt_1 : kphiI premInv fee < 1 := hkphiI_lt_1
        have hcTwo_kphi_lt : cTwo probInv probArb premShock fee (kphiS premShock fee) <
                             cTwo probInv probArb premShock fee y := by
          simp only [cTwo]
          have hconst_pos : 0 < (1 + premShock) * (kphiS premShock fee) ^ 2 := by
            have h1p_pos : 0 < 1 + premShock := by linarith
            exact mul_pos h1p_pos (sq_pos_of_pos hkphi_pos)
          have hterm1 : probInv / 2 * ((1 + fee) / (1 - kphiS premShock fee) - 1) <
                        probInv / 2 * ((1 + fee) / (1 - y) - 1) := by
            apply mul_lt_mul_of_pos_left _ (by linarith : 0 < probInv / 2)
            have h1my_lt_1mk : 1 - y < 1 - kphiS premShock fee := by linarith
            have hdiv_lt : (1 + fee) / (1 - kphiS premShock fee) < (1 + fee) / (1 - y) := by
              rw [div_lt_div_iff₀ h1mk_pos h1my_pos]
              nlinarith
            linarith
          have hterm2 : probArb / 2 * ((1 + premShock) * kphiS premShock fee ^ 2 / kphiS premShock fee) >
                        probArb / 2 * ((1 + premShock) * kphiS premShock fee ^ 2 / y) := by
            apply mul_lt_mul_of_pos_left _ (by linarith : 0 < probArb / 2)
            exact div_lt_div_of_pos_left hconst_pos hkphi_pos hy_le_kphiS
          linarith
        linarith
    · -- Subcase: kphiS < x < y, both in second branch
      push_neg at hx_le_kphiS2
      have hx_le_kphiI : x ≤ kphiI premInv fee := hx.2
      have hy_le_kphiI : y ≤ kphiI premInv fee := hy.2
      simp only [lpExcess, if_neg (not_le.mpr hx_le_kphiS2), if_neg (not_le.mpr hy_le_kphiS), hx_le_kphiI, hy_le_kphiI, ite_true]
      -- Goal: cTwo x < cTwo y
      -- cTwo = probInv/2 * ((1+fee)/(1-curv) - 1) - probArb/2 * (const/curv)
      -- First term increases with curv, second term (subtracted) decreases with curv
      -- So cTwo is strictly increasing
      have hfee_pos : 0 < 1 + fee := by linarith
      have hprobInv_pos : 0 < probInv / 2 := by linarith
      have hprobArb_pos : 0 < probArb / 2 := by linarith
      have hx_pos : 0 < x := by
        have hkphiS_pos : 0 < kphiS premShock fee := (kphiS_mem_Ioo premShock fee hfee hS).1
        linarith
      have hy_pos : 0 < y := lt_trans hx_pos hxy
      have hkphiS_lt_1 : kphiS premShock fee < 1 := (kphiS_mem_Ioo premShock fee hfee hS).2
      have hkphiI_lt_1 : kphiI premInv fee < 1 := by
        unfold kphiI
        have h1p_pos : 0 < 1 + premInv := by linarith
        have h1f_pos : 0 < 1 + fee := hfee_pos
        have h_sqrt_pos : 0 < Real.sqrt ((1 + fee) / (1 + premInv)) :=
          Real.sqrt_pos.mpr (div_pos h1f_pos h1p_pos)
        linarith
      have hy_lt_1 : y < 1 := lt_of_le_of_lt hy.2 hkphiI_lt_1
      have hx_lt_1 : x < 1 := lt_trans hxy hy_lt_1
      have h1mx_pos : 0 < 1 - x := by linarith
      have h1my_pos : 0 < 1 - y := by linarith
      have h1my_lt_1mx : 1 - y < 1 - x := by linarith
      have hconst_pos : 0 < (1 + premShock) * (kphiS premShock fee) ^ 2 := by
        have h1p_pos : 0 < 1 + premShock := by linarith
        have hkphiS_pos : 0 < kphiS premShock fee := (kphiS_mem_Ioo premShock fee hfee hS).1
        exact mul_pos h1p_pos (sq_pos_of_pos hkphiS_pos)
      -- Now show cTwo x < cTwo y
      -- cTwo = probInv/2 * ((1+fee)/(1-curv) - 1) - probArb/2 * (const/curv)
      simp only [cTwo]
      -- The first term: probInv/2 * ((1+fee)/(1-curv) - 1) is strictly increasing
      -- The second term: probArb/2 * (const/curv) is strictly decreasing, so -second is increasing
      have hterm1_x : probInv / 2 * ((1 + fee) / (1 - x) - 1) < probInv / 2 * ((1 + fee) / (1 - y) - 1) := by
        apply mul_lt_mul_of_pos_left _ hprobInv_pos
        have : (1 + fee) / (1 - x) < (1 + fee) / (1 - y) := by
          rw [div_lt_div_iff₀ h1mx_pos h1my_pos]
          nlinarith
        linarith
      have hterm2_x : probArb / 2 * ((1 + premShock) * kphiS premShock fee ^ 2 / x) >
                      probArb / 2 * ((1 + premShock) * kphiS premShock fee ^ 2 / y) := by
        apply mul_lt_mul_of_pos_left _ hprobArb_pos
        exact div_lt_div_of_pos_left hconst_pos hx_pos hxy
      linarith

/-- T12': strict decrease after the switch; positivity of the defined `cOne` is load-bearing.

The ordering hypothesis is necessary to ensure the shock branch point does not lie above the
investor switch; without it the function can still be increasing immediately after `kphiI`. -/
theorem lpExcess_strictAntiOn (probInv probArb coefD premShock premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hpi : fee < premInv)
    (hord : premShock ≤ premInv)
    (hcOne : 0 < cOne probInv probArb premShock premInv fee) :
    StrictAntiOn (lpExcess probInv probArb coefD premShock premInv fee)
      (Icc (kphiI premInv fee) 1) := by
  intro x hx y hy hxy
  have hki := kphiS_mem_Ioo premInv fee hfee hpi
  have hks : kphiS premShock fee ≤ kphiI premInv fee :=
    (kphiS_le_kphiI_iff hfee (by linarith) (by linarith)).mp hord
  have hyI : ¬ y ≤ kphiI premInv fee := not_le.mpr (lt_of_le_of_lt hx.1 hxy)
  have hyS : ¬ y ≤ kphiS premShock fee := fun h => hyI (h.trans hks)
  by_cases hxI : x ≤ kphiI premInv fee
  · have hxeq : x = kphiI premInv fee := le_antisymm hxI hx.1
    subst x
    have hiagree := lpExcess_branch_agree_kphiI probInv probArb premShock premInv fee hfee hpi
    have hxval : lpExcess probInv probArb coefD premShock premInv fee (kphiI premInv fee) =
        cOne probInv probArb premShock premInv fee / kphiI premInv fee - coefD * premShock := by
      unfold lpExcess
      by_cases heq : kphiI premInv fee ≤ kphiS premShock fee
      · have eq : kphiS premShock fee = kphiI premInv fee := le_antisymm hks heq
        have hsagree := lpExcess_branch_agree_kphiS probInv probArb premShock fee hfee hS
        rw [if_pos heq, ← eq, hsagree, eq, hiagree]
      · simp [heq, hiagree]
    rw [hxval]
    unfold lpExcess
    simp [hyI, hyS]
    apply div_lt_div_of_pos_left hcOne hki.1 hxy
  · have hxS : ¬ x ≤ kphiS premShock fee := fun h => hxI (h.trans hks)
    unfold lpExcess
    simp [hxI, hyI, hxS, hyS]
    apply div_lt_div_of_pos_left hcOne (lt_of_lt_of_le hki.1 hx.1) hxy

/-- T13': the global maximum on the whole curvature interval is the kink/regime switch. -/
theorem lpExcess_isMaxOn (probInv probArb coefD premShock premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hInv : 0 < probInv)
    (hcOne : 0 < cOne probInv probArb premShock premInv fee) :
    IsMaxOn (lpExcess probInv probArb coefD premShock premInv fee) (Icc (0 : ℝ) 1)
      (kphiI premInv fee) := by
  have hk : kphiI premInv fee ∈ Icc (0 : ℝ) 1 :=
    ⟨(kphiS_mem_Ioo premInv fee hfee (lt_of_lt_of_le hS hord)).1.le,
     (kphiS_mem_Ioo premInv fee hfee (lt_of_lt_of_le hS hord)).2.le⟩
  intro x hx
  by_cases hle : x ≤ kphiI premInv fee
  · exact (lpExcess_strictMonoOn probInv probArb coefD premShock premInv fee hfee hS hord hA hInv).monotoneOn
      ⟨hx.1, hle⟩ ⟨hk.1, le_rfl⟩ hle
  · exact (lpExcess_strictAntiOn probInv probArb coefD premShock premInv fee hfee hS
      (lt_of_lt_of_le hS hord) hord hcOne).antitoneOn
      ⟨le_rfl, hk.2⟩ ⟨le_of_not_ge hle, hx.2⟩ (le_of_not_ge hle)

noncomputable def kphiStar (premInv fee : ℝ) : ℝ :=
  1 - Real.sqrt ((1 + fee) / (1 + premInv))

/-- T14'a: this is an rfl-grade naming identity.  The substantive claim that the LP argmax lands
at the investor switch is `lpExcess_isMaxOn`, not this identity. -/
theorem kphiStar_eq_kphiI (premInv fee : ℝ) : kphiStar premInv fee = kphiI premInv fee := rfl

/-- T14'b: exact interiority criterion for the named optimum. -/
theorem kphiStar_mem_Ioo_iff {premInv fee : ℝ} (hfee : 0 ≤ fee) :
    kphiStar premInv fee ∈ Ioo (0 : ℝ) 1 ↔ fee < premInv := by
  simp only [kphiStar, mem_Ioo]
  constructor
  · intro ⟨h1, h2⟩
    -- h1: 0 < 1 - √((1 + fee) / (1 + premInv)), so √(...) < 1
    have hsqrt_lt_1 : Real.sqrt ((1 + fee) / (1 + premInv)) < 1 := by linarith
    -- h2: 1 - √(...) < 1, so √(...) > 0
    have hsqrt_pos : 0 < Real.sqrt ((1 + fee) / (1 + premInv)) := by linarith
    -- From sqrt > 0, the ratio is positive
    have h_ratio_pos : 0 < (1 + fee) / (1 + premInv) := by rwa [Real.sqrt_pos] at hsqrt_pos
    -- From sqrt < 1 and ratio positive, ratio < 1
    have h_ratio_lt_1 : (1 + fee) / (1 + premInv) < 1 := by
      nlinarith [Real.mul_self_sqrt (le_of_lt h_ratio_pos)]
    -- From ratio < 1 and ratio > 0, and 1 + fee ≥ 1 > 0, we get 1 + premInv > 0 and 1 + fee < 1 + premInv
    have h_denom_pos : 0 < 1 + premInv := by
      rw [div_pos_iff] at h_ratio_pos
      cases h_ratio_pos with
      | inl h => linarith
      | inr h => linarith
    rw [div_lt_one h_denom_pos] at h_ratio_lt_1
    linarith
  · intro h
    have h1 : 0 < premInv := by linarith
    have hpos : 0 < 1 + premInv := by linarith
    have h_ratio_pos : 0 < (1 + fee) / (1 + premInv) := by positivity
    have h_ratio_lt_1 : (1 + fee) / (1 + premInv) < 1 := by
      rw [div_lt_one hpos]
      linarith
    have hsqrt_pos : 0 < Real.sqrt ((1 + fee) / (1 + premInv)) := Real.sqrt_pos.mpr h_ratio_pos
    have hsqrt_lt_1 : Real.sqrt ((1 + fee) / (1 + premInv)) < 1 := by
      have : Real.sqrt ((1 + fee) / (1 + premInv)) < Real.sqrt 1 :=
        Real.sqrt_lt_sqrt h_ratio_pos.le h_ratio_lt_1
      rwa [Real.sqrt_one] at this
    exact ⟨by linarith, by linarith⟩

/-- T15': taking the maximum with a curvature-independent hold return preserves the peak. -/
theorem lpPayoff_isMaxOn (probInv probArb coefD premShock premInv fee holdReturn : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hInv : 0 < probInv)
    (hcOne : 0 < cOne probInv probArb premShock premInv fee) :
    IsMaxOn (fun curv => max
      (lpExcess probInv probArb coefD premShock premInv fee curv + holdReturn) holdReturn)
      (Icc (0 : ℝ) 1) (kphiStar premInv fee) := by
  intro x hx
  have hle := lpExcess_isMaxOn probInv probArb coefD premShock premInv fee
    hfee hS hord hA hInv hcOne hx
  rw [← kphiStar_eq_kphiI] at hle
  change lpExcess probInv probArb coefD premShock premInv fee x ≤
    lpExcess probInv probArb coefD premShock premInv fee (kphiStar premInv fee) at hle
  change max (lpExcess probInv probArb coefD premShock premInv fee x + holdReturn) holdReturn ≤
    max (lpExcess probInv probArb coefD premShock premInv fee (kphiStar premInv fee) + holdReturn) holdReturn
  apply max_le_max _ le_rfl
  simpa [add_comm] using add_le_add_left hle holdReturn

/-- T16': freeze everywhere follows if even the global peak is negative.  This proof uses the
explicit `cOne > 0` peak regime and is correspondingly stronger than the anchor's unconditional
wording. -/
theorem liquidity_freeze_minimal (probInv probArb coefD premShock premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hInv : 0 < probInv)
    (hcOne : 0 < cOne probInv probArb premShock premInv fee)
    (hpeak : lpExcess probInv probArb coefD premShock premInv fee
      (kphiStar premInv fee) < 0) :
    ∀ curv ∈ Icc (0 : ℝ) 1,
      lpExcess probInv probArb coefD premShock premInv fee curv < 0 := by
  intro curv hcurv
  have hle := lpExcess_isMaxOn probInv probArb coefD premShock premInv fee
    hfee hS hord hA hInv hcOne hcurv
  rw [← kphiStar_eq_kphiI] at hle
  exact lt_of_le_of_lt hle hpeak

noncomputable def depositEfficiency (wA wB premInv fee curv : ℝ) : ℝ :=
  if curv ≤ kphiStar premInv fee then
    (wA / (1 - curv) + wB) / (wA + wB)
  else ((Real.sqrt ((1 + premInv) / (1 + fee)) - 1) / curv) *
    (wA + wB / Real.sqrt ((1 + premInv) / (1 + fee))) / (wA + wB)

/-- T17'a: deposit-efficiency branches agree at the peak. -/
theorem depositEfficiency_branch_agree (wA wB premInv fee : ℝ)
    (hwA : 0 < wA) (hwB : 0 < wB) (hfee : 0 ≤ fee) (hI : fee < premInv) :
    (wA / (1 - kphiStar premInv fee) + wB) / (wA + wB) =
      ((Real.sqrt ((1 + premInv) / (1 + fee)) - 1) / kphiStar premInv fee) *
        (wA + wB / Real.sqrt ((1 + premInv) / (1 + fee))) / (wA + wB) := by
  set s := Real.sqrt ((1 + premInv) / (1 + fee)) with hs_def
  have hpremInv_pos : 0 < 1 + premInv := by linarith
  have hfee_pos : 0 < 1 + fee := by linarith
  have hs_pos : 0 < s := Real.sqrt_pos.mpr (div_pos hpremInv_pos hfee_pos)
  have hs_ne_zero : s ≠ 0 := hs_pos.ne'
  have hs_inv : Real.sqrt ((1 + fee) / (1 + premInv)) = 1 / s := by
    rw [hs_def]
    rw [Real.sqrt_div hfee_pos.le, Real.sqrt_div hpremInv_pos.le]
    field_simp
  have hkphiStar : kphiStar premInv fee = (s - 1) / s := by
    unfold kphiStar
    rw [hs_inv]
    field_simp
  have h1_mkphiStar : 1 - kphiStar premInv fee = 1 / s := by
    rw [hkphiStar]
    field_simp
    ring
  -- First establish s ≠ 1
  have hs_ne_one : s ≠ 1 := by
    rw [hs_def]
    have hdiv_gt_1 : (1 + premInv) / (1 + fee) > 1 := by
      rw [gt_iff_lt, one_lt_div hfee_pos]
      linarith
    have hsqrt_gt_1 : Real.sqrt ((1 + premInv) / (1 + fee)) > 1 := by
      rw [gt_iff_lt, Real.lt_sqrt (by linarith : (0 : ℝ) ≤ 1)]
      simp only [one_pow]
      exact hdiv_gt_1
    exact ne_of_gt hsqrt_gt_1
  -- Now simplify both sides
  rw [h1_mkphiStar, hkphiStar]
  field_simp [hs_ne_zero, sub_ne_zero.mpr hs_ne_one]

/-- T17'b: deposit efficiency is globally maximized at the common branch point. -/
theorem depositEfficiency_isMaxOn (wA wB premInv fee : ℝ)
    (hwA : 0 < wA) (hwB : 0 < wB) (hfee : 0 ≤ fee) (hI : fee < premInv) :
    IsMaxOn (depositEfficiency wA wB premInv fee) (Icc (0 : ℝ) 1)
      (kphiStar premInv fee) := by
  -- First establish kphiStar ∈ Ioo 0 1
  have hk_mem : kphiStar premInv fee ∈ Ioo (0 : ℝ) 1 := by
    simp only [kphiStar, mem_Ioo]
    constructor
    · -- 0 < 1 - sqrt((1 + fee) / (1 + premInv))
      have h_ratio_lt_1 : (1 + fee) / (1 + premInv) < 1 := by
        rw [div_lt_one (by linarith : 0 < 1 + premInv)]
        linarith
      have h_sqrt_lt_1 : Real.sqrt ((1 + fee) / (1 + premInv)) < 1 := by
        have h1f : 0 < 1 + fee := by linarith
        have h1p : 0 < 1 + premInv := by linarith
        have hpos : 0 ≤ (1 + fee) / (1 + premInv) := by positivity
        have h := Real.sqrt_lt_sqrt hpos h_ratio_lt_1
        simp at h
        exact h
      linarith
    · -- 1 - sqrt(...) < 1
      have h_ratio_pos : 0 < (1 + fee) / (1 + premInv) := by
        apply div_pos; linarith; linarith
      linarith [Real.sqrt_pos.mpr h_ratio_pos]
  -- Unfold IsMaxOn: need to show ∀ y ∈ Icc 0 1, depositEfficiency ... y ≤ depositEfficiency ... (kphiStar ...)
  unfold IsMaxOn
  intro y hy
  unfold depositEfficiency
  -- Set up useful constants
  set s := Real.sqrt ((1 + premInv) / (1 + fee)) with hs_def
  set k := kphiStar premInv fee with hk_def
  have h1p_pos : 0 < 1 + premInv := by linarith
  have h1f_pos : 0 < 1 + fee := by linarith
  have hs_pos : 0 < s := Real.sqrt_pos.mpr (div_pos h1p_pos h1f_pos)
  have hs_ne_zero : s ≠ 0 := hs_pos.ne'
  -- kphiStar = (s - 1) / s
  have hk_eq : k = (s - 1) / s := by
    show kphiStar premInv fee = (s - 1) / s
    simp [kphiStar, hs_def]
    have h_frac1_pos : 0 < (1 + premInv) / (1 + fee) := div_pos h1p_pos h1f_pos
    have h_frac2_pos : 0 < (1 + fee) / (1 + premInv) := div_pos h1f_pos h1p_pos
    have h_sqrt_prod : Real.sqrt ((1 + fee) / (1 + premInv)) *
                       Real.sqrt ((1 + premInv) / (1 + fee)) = 1 := by
      rw [← Real.sqrt_mul (le_of_lt h_frac2_pos)]
      field_simp
      norm_num
    field_simp
    linarith [h_sqrt_prod]
  -- 1 - k = 1/s
  have h1mk : 1 - k = 1 / s := by rw [hk_eq]; field_simp; ring
  -- Simplify RHS: k ≤ k is true
  have hk_le_k : k ≤ k := le_refl k
  simp [hk_le_k]
  -- Case analysis on y ≤ k
  by_cases hyk : y ≤ k
  · -- Case y ≤ k: need to show (wA / (1 - y) + wB) / (wA + wB) ≤ (wA / (1 - k) + wB) / (wA + wB)
    simp [hyk]
    -- Need: wA / (1 - y) + wB ≤ wA / (1 - k) + wB
    have hy_mem : y ∈ Icc (0 : ℝ) 1 := hy
    have hk_mem' : k ∈ Ioo (0 : ℝ) 1 := hk_mem
    have h1my_pos : 0 < 1 - y := by linarith [hk_mem'.2]
    have h1mk_pos : 0 < 1 - k := by linarith [hk_mem'.2]
    have hAB_pos : 0 < wA + wB := by linarith
    apply div_le_div_of_nonneg_right _ hAB_pos.le
    -- Goal: wA / (1 - y) + wB ≤ wA / (1 - k) + wB
    -- Equiv: wA / (1 - y) ≤ wA / (1 - k)
    have h_wA_div : wA / (1 - y) ≤ wA / (1 - k) := by
      rw [div_le_div_iff₀ h1my_pos h1mk_pos]
      nlinarith [hwA]
    linarith
  · -- Case y > k: need to show ((s - 1) / y * (wA + wB / s) / (wA + wB)) ≤ (wA / (1 - k) + wB) / (wA + wB)
    simp [hyk]
    have hy_mem : y ∈ Icc (0 : ℝ) 1 := hy
    have hy_pos : 0 < y := by
      have : k < y := lt_of_not_ge hyk
      linarith [hk_mem.1]
    have hAB_pos : 0 < wA + wB := by linarith
    -- s > 1 because premInv > fee
    have hs_gt_1 : s > 1 := by
      have h_ratio_gt_1 : (1 + premInv) / (1 + fee) > 1 := by
        rw [gt_iff_lt, one_lt_div h1f_pos]
        linarith
      rw [hs_def, gt_iff_lt, Real.lt_sqrt (by linarith : (0 : ℝ) ≤ 1)]
      norm_num
      exact h_ratio_gt_1
    have hs_1_pos : s - 1 > 0 := by linarith
    -- 1 - k = 1/s, so wA / (1 - k) = wA * s
    have hwA_div : wA / (1 - k) = wA * s := by rw [h1mk]; field_simp
    -- Since y > k = (s-1)/s, we have y * s > s - 1, so (s-1)/y < s
    have hyk' : y > k := not_le.mp hyk
    have hy_gt_k_eq : y > (s - 1) / s := by rwa [← hk_eq]
    have hy_s : y * s > s - 1 := by
      have := mul_lt_mul_of_pos_right hy_gt_k_eq hs_pos
      rwa [div_mul_cancel₀ _ hs_ne_zero] at this
    have h_div_lt_s : (s - 1) / y < s := by
      rw [div_lt_iff₀ hy_pos]
      linarith
    -- LHS numerator: (s - 1) / y * (wA + wB / s) < s * (wA + wB / s) = wA * s + wB
    have h_wA_wB_s_pos : wA + wB / s > 0 := by
      apply add_pos_of_pos_of_nonneg hwA
      exact div_nonneg (le_of_lt hwB) hs_pos.le
    have h_prod_lt : (s - 1) / y * (wA + wB / s) < s * (wA + wB / s) := by
      apply mul_lt_mul_of_pos_right h_div_lt_s h_wA_wB_s_pos
    have h_s_prod : s * (wA + wB / s) = wA * s + wB := by field_simp [hs_ne_zero]
    rw [hwA_div]
    apply div_le_div_of_nonneg_right _ hAB_pos.le
    linarith

/-- T17'c: below the peak, surplus plus LP revenue per investor is a zero-sum constant.  This,
not a weighting of objectives, describes the transfer before investor volume starts shrinking. -/
theorem surplus_add_revenue_const (premInv fee curv : ℝ)
    (h0 : 0 ≤ curv) (h : curv ≤ kphiI premInv fee) :
    surplusRatio premInv fee curv + 1 / 2 * ((1 + fee) / (1 - curv) - 1) =
      premInv / 2 := by
  unfold surplusRatio
  simp [h]
  ring

noncomputable def curvIndex (η Δi : ℝ) : ℝ :=
  1 - PosSpec.lam ^ (-(Δi ^ 2 * η) / 2)

/-- T19': the adjacent-grid price ratio is independent of the tick `i`. -/
theorem priceEta_step_ratio (η Δi i : ℝ) :
    VolInstrument.priceEta η Δi (i + Δi) / VolInstrument.priceEta η Δi i =
      PosSpec.lam ^ (Δi ^ 2 * η / 2) := by
  unfold VolInstrument.priceEta
  rw [← Real.rpow_sub (by exact PosSpec.lam_pos)]
  congr 1
  ring

/-- T20': the index is the tick-independent relative price step. -/
theorem curvIndex_eq_of_priceEta (η Δi i : ℝ) :
    curvIndex η Δi =
      1 - VolInstrument.priceEta η Δi i /
        VolInstrument.priceEta η Δi (i + Δi) := by
  simp only [curvIndex, VolInstrument.priceEta]
  rw [← Real.rpow_sub (by exact PosSpec.lam_pos)]
  congr 1
  ring_nf

/-- T21': positive η and spacing map into the open anchor interval. -/
theorem curvIndex_mem_Ioo {η Δi : ℝ} (hη : 0 < η) (hΔ : 0 < Δi) :
    curvIndex η Δi ∈ Ioo (0 : ℝ) 1 := by
  unfold curvIndex
  have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
  have hlam_gt1 : 1 < PosSpec.lam := PosSpec.one_lt_lam
  have hsq : 0 < Δi ^ 2 := sq_pos_of_pos hΔ
  have hprod : 0 < Δi ^ 2 * η := mul_pos hsq hη
  have hexp_neg : -(Δi ^ 2 * η) / 2 < 0 := by linarith
  have hr_pos : 0 < PosSpec.lam ^ (-(Δi ^ 2 * η) / 2) := Real.rpow_pos_of_pos hlam_pos _
  have hr_lt1 : PosSpec.lam ^ (-(Δi ^ 2 * η) / 2) < 1 := by
    have := Real.rpow_lt_rpow_of_exponent_lt hlam_gt1 hexp_neg
    simp at this
    exact this
  constructor <;> linarith

/-- T22': the curvature proxy is strictly increasing in η. -/
theorem curvIndex_strictMono {Δi : ℝ} (hΔ : 0 < Δi) :
    StrictMono (fun η => curvIndex η Δi) := by
  intro η₁ η₂ hlt
  unfold curvIndex
  have hlam : 1 < PosSpec.lam := PosSpec.one_lt_lam
  have hΔ2 : 0 < Δi ^ 2 := sq_pos_of_pos hΔ
  have hexp : -(Δi ^ 2 * η₂) / 2 < -(Δi ^ 2 * η₁) / 2 := by nlinarith
  linarith [Real.rpow_lt_rpow_of_exponent_lt hlam hexp]

/-- T23'a: η approaching zero from above approaches the zero-curvature grid. -/
theorem curvIndex_tendsto_zero (Δi : ℝ) :
    Tendsto (fun η => curvIndex η Δi) (nhdsWithin 0 (Ioi 0)) (nhds 0) := by
  have key : ∀ η, curvIndex η Δi = 1 - PosSpec.lam ^ (-(Δi ^ 2 * η) / 2) := fun _ => rfl
  simp_rw [key]
  have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
  have hlam_log_cont : Continuous (fun η : ℝ => Real.exp (Real.log PosSpec.lam * (-(Δi ^ 2 * η) / 2))) := by
    exact Real.continuous_exp.comp (continuous_const.mul (
      Continuous.div_const (Continuous.neg (continuous_const.mul continuous_id')) _))
  have h2 : Tendsto (fun η => PosSpec.lam ^ (-(Δi ^ 2 * η) / 2)) (nhds 0) (nhds 1) := by
    have heq : ∀ η, PosSpec.lam ^ (-(Δi ^ 2 * η) / 2) = Real.exp (Real.log PosSpec.lam * (-(Δi ^ 2 * η) / 2)) :=
      fun η => Real.rpow_def_of_pos hlam_pos _
    simp_rw [heq]
    have hexp : Real.exp (Real.log PosSpec.lam * (-(Δi ^ 2 * 0) / 2)) = 1 := by simp
    simpa [hexp] using hlam_log_cont.tendsto 0
  have h3 : Tendsto (fun η => 1 - PosSpec.lam ^ (-(Δi ^ 2 * η) / 2)) (nhdsWithin 0 (Ioi 0)) (nhds (1 - 1)) :=
    (h2.const_sub 1).mono_left nhdsWithin_le_nhds
  simp only [sub_self] at h3
  exact h3

/-- T23'b: η tending to infinity approaches, but never reaches, curvature one. -/
theorem curvIndex_tendsto_one {Δi : ℝ} (hΔ : 0 < Δi) :
    Tendsto (fun η => curvIndex η Δi) atTop (nhds 1) := by
  unfold curvIndex
  have hlam : 1 < PosSpec.lam := PosSpec.one_lt_lam
  have hlam_pos : 0 < PosSpec.lam := PosSpec.lam_pos
  have hlog_lam : 0 < Real.log PosSpec.lam := Real.log_pos hlam
  -- lam ^ exponent = exp(exponent * log lam)
  -- exponent * log lam → -∞ as η → ∞
  have hexp : Tendsto (fun η => -(Δi ^ 2 * η) / 2 * Real.log PosSpec.lam) atTop atBot := by
    have h1 : Tendsto (fun η => Δi ^ 2 * η) atTop atTop :=
      Filter.Tendsto.const_mul_atTop (sq_pos_of_pos hΔ) Filter.tendsto_id
    have hn : Tendsto (fun x : ℝ => -x) atTop atBot := Filter.tendsto_neg_atTop_atBot
    have h2 : Tendsto (fun η => -(Δi ^ 2 * η)) atTop atBot := hn.comp h1
    have h3 : Tendsto (fun η => -(Δi ^ 2 * η) / 2) atTop atBot := by
      have := Filter.Tendsto.atBot_mul_const (by norm_num : (0:ℝ) < 2⁻¹) h2
      simp_rw [div_eq_mul_inv] at this ⊢
      exact this
    exact Filter.Tendsto.atBot_mul_const hlog_lam h3
  have hexp_neg : Tendsto (fun η => Real.exp (-(Δi ^ 2 * η) / 2 * Real.log PosSpec.lam)) atTop (nhds 0) := by
    have h := Real.tendsto_exp_neg_atTop_nhds_zero
    have hn : Tendsto (fun η => -(-(Δi ^ 2 * η) / 2 * Real.log PosSpec.lam)) atTop atTop := by
      exact Filter.tendsto_neg_atBot_atTop.comp hexp
    have := h.comp hn
    simp only [Function.comp_def, neg_neg] at this
    exact this
  have hconvert : (fun η => PosSpec.lam ^ (-(Δi ^ 2 * η) / 2)) =
      (fun η => Real.exp (-(Δi ^ 2 * η) / 2 * Real.log PosSpec.lam)) := by
    ext η
    rw [Real.rpow_def_of_pos hlam_pos]
    congr 1
    ring
  have hgoal : (fun η => 1 - PosSpec.lam ^ (-(Δi ^ 2 * η) / 2)) =
      (fun η => 1 - Real.exp (-(Δi ^ 2 * η) / 2 * Real.log PosSpec.lam)) := by
    ext η; exact congr_arg _ (congrFun hconvert η)
  rw [hgoal]
  have := hexp_neg.const_sub 1
  simpa using this

noncomputable def etaStar (premInv fee Δi : ℝ) : ℝ :=
  Real.log ((1 + premInv) / (1 + fee)) / (Δi ^ 2 * Real.log PosSpec.lam)

/-- T24': the headline closed-form inversion of the curvature bijection. -/
theorem curvIndex_etaStar {premInv fee Δi : ℝ}
    (hfee : 0 ≤ fee) (hpi : fee < premInv) (hΔ : 0 < Δi) :
    curvIndex (etaStar premInv fee Δi) Δi = kphiStar premInv fee := by
  unfold curvIndex etaStar kphiStar
  have hlam_pos : (0 : ℝ) < PosSpec.lam := PosSpec.lam_pos
  have hlam_gt1 : 1 < PosSpec.lam := PosSpec.one_lt_lam
  have hlog_lam_pos : 0 < Real.log PosSpec.lam := Real.log_pos hlam_gt1
  have hfee_denom_pos : 0 < 1 + fee := by linarith
  have hpremInv_pos : 0 < 1 + premInv := by linarith
  have hratio_pos : 0 < (1 + premInv) / (1 + fee) := by positivity
  have hratio_inv_pos : 0 < (1 + fee) / (1 + premInv) := by positivity
  -- Simplify the exponent
  have hΔ2_ne_zero : Δi ^ 2 ≠ 0 := pow_ne_zero 2 hΔ.ne'
  have hdenom_ne_zero : Δi ^ 2 * Real.log PosSpec.lam ≠ 0 := mul_ne_zero hΔ2_ne_zero hlog_lam_pos.ne'
  -- The exponent simplifies to Real.log (ratio_inv) / 2
  have exponent_eq : -(Δi ^ 2 * (Real.log ((1 + premInv) / (1 + fee)) / (Δi ^ 2 * Real.log PosSpec.lam))) / 2 =
      Real.log ((1 + fee) / (1 + premInv)) / (2 * Real.log PosSpec.lam) := by
    have h1 : Δi ^ 2 * (Real.log ((1 + premInv) / (1 + fee)) / (Δi ^ 2 * Real.log PosSpec.lam)) =
              Real.log ((1 + premInv) / (1 + fee)) / Real.log PosSpec.lam := by
      field_simp
    rw [h1]
    have h2 : Real.log ((1 + fee) / (1 + premInv)) = -Real.log ((1 + premInv) / (1 + fee)) := by
      rw [← Real.log_inv, inv_div]
    rw [h2]
    ring
  rw [exponent_eq]
  congr 1
  -- Goal: PosSpec.lam ^ (Real.log ((1 + fee) / (1 + premInv)) / (2 * Real.log PosSpec.lam)) = √((1 + fee) / (1 + premInv))
  have hlog_lam_ne_zero : Real.log PosSpec.lam ≠ 0 := hlog_lam_pos.ne'
  rw [Real.sqrt_eq_rpow]
  -- Goal: PosSpec.lam ^ (Real.log ratio / (2 * log lam)) = ratio ^ (1/2)
  have hexp_eq : Real.log ((1 + fee) / (1 + premInv)) / (2 * Real.log PosSpec.lam) =
      Real.log ((1 + fee) / (1 + premInv)) / Real.log PosSpec.lam * (1/2) := by ring
  -- Use the identity: lam ^ (log(ratio) / (2 * log lam)) = ratio ^ (1/2)
  -- This is because lam ^ (log(ratio) / log lam) = ratio, so lam ^ (log(ratio) / (2 * log lam)) = ratio ^ (1/2)
  have hchange_base : ∀ x : ℝ, 0 < x → PosSpec.lam ^ (Real.log x / Real.log PosSpec.lam) = x := by
    intro x hx
    have h := Real.rpow_logb hlam_pos (ne_of_gt hlam_gt1) hx
    exact h
  -- Now use: lam ^ (log(ratio) / (2 * log lam)) = (lam ^ (log(ratio) / log lam)) ^ (1/2) = ratio ^ (1/2)
  have h1 : Real.log ((1 + fee) / (1 + premInv)) / (2 * Real.log PosSpec.lam) =
      Real.log ((1 + fee) / (1 + premInv)) / Real.log PosSpec.lam * (1/2) := by ring
  rw [h1]
  have h2 : PosSpec.lam ^ (Real.log ((1 + fee) / (1 + premInv)) / Real.log PosSpec.lam * (1/2)) =
      (PosSpec.lam ^ (Real.log ((1 + fee) / (1 + premInv)) / Real.log PosSpec.lam)) ^ (1/2 : ℝ) := by
    rw [Real.rpow_mul (le_of_lt hlam_pos)]
  rw [h2]
  rw [hchange_base ((1 + fee) / (1 + premInv)) hratio_inv_pos]

/-- T25': exact positivity criterion for the closed-form controller.

The hypothesis `-1 < premInv` is necessary: `Real.log` on a negative argument is the logarithm
of its absolute value, so, for example, `premInv = -3` and `fee = 0` falsify the unguarded
criterion. -/
theorem etaStar_pos_iff {premInv fee Δi : ℝ} (hfee : 0 ≤ fee) (hprem : -1 < premInv)
    (hΔ : 0 < Δi) :
    0 < etaStar premInv fee Δi ↔ fee < premInv := by
  unfold etaStar
  have hlam : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hden : 0 < Δi ^ 2 * Real.log PosSpec.lam := mul_pos (sq_pos_of_pos hΔ) hlam
  have hf : 0 < 1 + fee := by linarith
  have hp : 0 < 1 + premInv := by linarith
  have hr : 0 < (1 + premInv) / (1 + fee) := div_pos hp hf
  constructor
  · intro h
    have hn : 0 < Real.log ((1 + premInv) / (1 + fee)) := by
      exact (div_pos_iff.mp h).elim (fun q => q.1)
        (fun q => (not_lt_of_ge hden.le q.2).elim)
    have hv : 1 < (1 + premInv) / (1 + fee) := (Real.log_pos_iff hr.le).mp hn
    rw [one_lt_div hf] at hv
    linarith
  · intro h
    apply div_pos
    · apply (Real.log_pos_iff hr.le).mpr
      rw [one_lt_div hf]
      linarith
    · exact hden

/-- T26'a: the controller strictly increases with the investor premium. -/
theorem etaStar_strictMono_premInv (fee Δi : ℝ) (hfee : 0 ≤ fee) (hΔ : 0 < Δi) :
    StrictMonoOn (fun premInv => etaStar premInv fee Δi) (Ioi fee) := by
  intro x hx y hy hxy
  change fee < x at hx
  change fee < y at hy
  unfold etaStar
  have hlam : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hden : 0 < Δi ^ 2 * Real.log PosSpec.lam := mul_pos (sq_pos_of_pos hΔ) hlam
  apply div_lt_div_of_pos_right _ hden
  apply Real.log_lt_log
  · exact div_pos (by linarith) (by linarith)
  · exact div_lt_div_of_pos_right (by linarith) (by linarith)

/-- T26'b: the controller strictly decreases with fee on its admissible interval. -/
theorem etaStar_strictAnti_fee (premInv Δi : ℝ) (hΔ : 0 < Δi) :
    StrictAntiOn (fun fee => etaStar premInv fee Δi) (Ico 0 premInv) := by
  unfold StrictAntiOn
  intro fee₁ hfee₁ fee₂ hfee₂ hlt
  unfold etaStar
  have hlam_pos : (0 : ℝ) < PosSpec.lam := PosSpec.lam_pos
  have hlam_gt1 : (1 : ℝ) < PosSpec.lam := PosSpec.one_lt_lam
  have hlog_lam_pos : 0 < Real.log PosSpec.lam := Real.log_pos hlam_gt1
  have hdenom_pos : 0 < Δi ^ 2 * Real.log PosSpec.lam := mul_pos (sq_pos_of_pos hΔ) hlog_lam_pos
  have hfee₁_lt : fee₁ < premInv := hfee₁.2
  have hfee₂_lt : fee₂ < premInv := hfee₂.2
  have hfee₁_nonneg : 0 ≤ fee₁ := hfee₁.1
  have hfee₂_nonneg : 0 ≤ fee₂ := hfee₂.1
  have h1_fee₁_pos : 0 < 1 + fee₁ := by linarith
  have h1_fee₂_pos : 0 < 1 + fee₂ := by linarith
  have h1_premInv_pos : 0 < 1 + premInv := by linarith
  have hratio₁_pos : 0 < (1 + premInv) / (1 + fee₁) := div_pos h1_premInv_pos h1_fee₁_pos
  have hratio₂_pos : 0 < (1 + premInv) / (1 + fee₂) := div_pos h1_premInv_pos h1_fee₂_pos
  have hfee_lt : 1 + fee₁ < 1 + fee₂ := by linarith
  have hratio_lt : (1 + premInv) / (1 + fee₂) < (1 + premInv) / (1 + fee₁) := by
    apply div_lt_div_of_pos_left h1_premInv_pos h1_fee₁_pos hfee_lt
  have hlog_lt : Real.log ((1 + premInv) / (1 + fee₂)) < Real.log ((1 + premInv) / (1 + fee₁)) :=
    Real.log_lt_log hratio₂_pos hratio_lt
  simp only
  rw [div_lt_div_iff₀ hdenom_pos hdenom_pos]
  nlinarith

/-- T26'c: spacing dependence is a normalization identity, not an economic comparative static:
`etaStar` scales as the reciprocal square needed to reproduce spacing-independent `kphiStar`. -/
theorem etaStar_strictAnti_spacing (premInv fee : ℝ)
    (hfee : 0 ≤ fee) (hI : fee < premInv) :
    StrictAntiOn (fun Δi => etaStar premInv fee Δi) (Ioi 0) := by
  intro x hx y hy hxy
  unfold etaStar
  have hp : 0 < 1 + premInv := by linarith
  have hf : 0 < 1 + fee := by linarith
  have hr : 1 < (1 + premInv) / (1 + fee) := by
    rw [one_lt_div hf]
    linarith
  have hl : 0 < Real.log ((1 + premInv) / (1 + fee)) := Real.log_pos hr
  have hlam : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hdx : 0 < x ^ 2 * Real.log PosSpec.lam := mul_pos (sq_pos_of_pos hx) hlam
  have hdy : 0 < y ^ 2 * Real.log PosSpec.lam := mul_pos (sq_pos_of_pos hy) hlam
  rw [div_lt_div_iff₀ hdy hdx]
  have hs : x ^ 2 < y ^ 2 := by
    nlinarith [mul_self_lt_mul_self (le_of_lt hx) hxy]
  have hmul : x ^ 2 * Real.log PosSpec.lam < y ^ 2 * Real.log PosSpec.lam :=
    mul_lt_mul_of_pos_right hs hlam
  nlinarith

noncomputable def lpExcessEta
    (probInv probArb coefD premShock premInv fee Δi η : ℝ) : ℝ :=
  lpExcess probInv probArb coefD premShock premInv fee (curvIndex η Δi)

/-- T27': the constructed closed form globally maximizes the η-parametrized return. -/
theorem lpExcessEta_isMaxOn (probInv probArb coefD premShock premInv fee Δi : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hInv : 0 < probInv) (hΔ : 0 < Δi)
    (hcOne : 0 < cOne probInv probArb premShock premInv fee) :
    IsMaxOn (fun η => lpExcessEta probInv probArb coefD premShock premInv fee Δi η)
      (Ioi (0 : ℝ)) (etaStar premInv fee Δi) := by
  have hpi : fee < premInv := lt_of_lt_of_le hS hord
  intro η hη
  change lpExcess probInv probArb coefD premShock premInv fee (curvIndex η Δi) ≤
    lpExcess probInv probArb coefD premShock premInv fee (curvIndex (etaStar premInv fee Δi) Δi)
  rw [curvIndex_etaStar hfee hpi hΔ, kphiStar_eq_kphiI]
  apply lpExcess_isMaxOn probInv probArb coefD premShock premInv fee hfee hS hord hA hInv hcOne
  have hm := curvIndex_mem_Ioo hη hΔ
  exact ⟨hm.1.le, hm.2.le⟩

/-- T28': strict increase on the left side of the η peak. -/
theorem lpExcessEta_strictMonoOn (probInv probArb coefD premShock premInv fee Δi : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hInv : 0 < probInv) (hΔ : 0 < Δi) :
    StrictMonoOn (fun η => lpExcessEta probInv probArb coefD premShock premInv fee Δi η)
      (Ioc (0 : ℝ) (etaStar premInv fee Δi)) := by
  intro x hx y hy hxy
  unfold lpExcessEta
  apply lpExcess_strictMonoOn probInv probArb coefD premShock premInv fee hfee hS hord hA hInv
  · have hm := curvIndex_mem_Ioo hx.1 hΔ
    refine ⟨hm.1.le, ?_⟩
    rw [← kphiStar_eq_kphiI, ← curvIndex_etaStar hfee (lt_of_lt_of_le hS hord) hΔ]
    exact (curvIndex_strictMono hΔ).monotone hx.2
  · have hm := curvIndex_mem_Ioo (lt_trans hx.1 hxy) hΔ
    refine ⟨hm.1.le, ?_⟩
    rw [← kphiStar_eq_kphiI, ← curvIndex_etaStar hfee (lt_of_lt_of_le hS hord) hΔ]
    exact (curvIndex_strictMono hΔ).monotone hy.2
  · exact curvIndex_strictMono hΔ hxy

/-- T28': strict decrease on the right side of the η peak, under the peak-regime guard. -/
theorem lpExcessEta_strictAntiOn (probInv probArb coefD premShock premInv fee Δi : ℝ)
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hInv : 0 < probInv) (hΔ : 0 < Δi)
    (hcOne : 0 < cOne probInv probArb premShock premInv fee) :
    StrictAntiOn (fun η => lpExcessEta probInv probArb coefD premShock premInv fee Δi η)
      (Ici (etaStar premInv fee Δi)) := by
  intro x hx y hy hxy
  unfold lpExcessEta
  apply lpExcess_strictAntiOn probInv probArb coefD premShock premInv fee hfee hS
    (lt_of_lt_of_le hS hord) hord hcOne
  · refine ⟨?_, (curvIndex_mem_Ioo ?_ hΔ).2.le⟩
    · rw [← kphiStar_eq_kphiI, ← curvIndex_etaStar hfee (lt_of_lt_of_le hS hord) hΔ]
      exact (curvIndex_strictMono hΔ).monotone hx
    · exact lt_of_lt_of_le ((etaStar_pos_iff hfee (by linarith) hΔ).2
        (lt_of_lt_of_le hS hord)) hx
  · refine ⟨?_, (curvIndex_mem_Ioo ?_ hΔ).2.le⟩
    · rw [← kphiStar_eq_kphiI, ← curvIndex_etaStar hfee (lt_of_lt_of_le hS hord) hΔ]
      exact (curvIndex_strictMono hΔ).monotone hy
    · exact lt_of_lt_of_le ((etaStar_pos_iff hfee (by linarith) hΔ).2
        (lt_of_lt_of_le hS hord)) hy
  · exact curvIndex_strictMono hΔ hxy

/-- T28'a: the factor two is exactly `priceEta`'s sqrt-price `i/2` normalization.  This equality
is the entire formal content of “the same parameter under different normalizations”; it makes no
factor-share identification. -/
theorem priceEta_eq_p_eta_half (η Δi : ℝ) (i : Int) :
    VolInstrument.priceEta η Δi (i : ℝ) =
      CFMM.Eta.p_eta PosSpec.lam Δi (η / 2) i := by
  unfold VolInstrument.priceEta CFMM.Eta.p_eta
  congr 1
  ring

/-- T28'a corollary, using the existing rescaling theorem. -/
theorem priceEta_eq_P_half (η Δi : ℝ) (i : Int) :
    VolInstrument.priceEta η Δi (i : ℝ) =
      CFMM.Eta.P_half PosSpec.lam (Δi * (η / 2)) i := by
  rw [priceEta_eq_p_eta_half, CFMM.Eta.p_eta_eq_P_half_rescaled]

/-- T29': both displayed ratios strictly fall as η rises.

This contrasts with `MevJointProgram.joint_corner_degeneracy`: its FLAIR maximum and arbitrage
minimum share a `Θ_φ` corner, while these non-identified objectives run toward opposite η ends.
`arbLossRatio` is not the MEV arbitrage objective and `surplusRatio` is not FLAIR.

This does NOT produce the interior optimum of T13'/T27'. Per block E4 the LP excess return
`lpExcess` does not combine `arbLossRatio` and `surplusRatio` at all — the investor's surplus
is not a term of it — and its peak comes from the LP revenue term's corner-to-interior regime
switch at `kphiI`, not from any weighting of two antitone objectives. What distinguishes the
two is WEIGHT-INVARIANCE: `lpExcess` peaks at `kphiI` for every admissible parameter vector,
whereas a nonnegative weighting `w1 * (-arbLossRatio) + w2 * surplusRatio` has a peak whose
location DEPENDS ON THE WEIGHTS and may sit strictly inside the middle region
`[kphiS, kphiI]`, at no branch point at all. A scalarized interior peak, where one exists, is
an artifact of the weights and carries none of the model content that `kphiI` carries.

This is NOT a de-degeneration of the `Θ_φ` program. `MevOptimization.mevMulti` contains no
`η`; the Phase-11 degeneracy is untouched by this module. -/
theorem eta_no_common_argmax {probArb premShock premInv fee Δi η₁ η₂ : ℝ}
    (hfee : 0 ≤ fee) (hS : fee < premShock) (hord : premShock ≤ premInv)
    (hA : 0 < probArb) (hΔ : 0 < Δi) (h₀ : 0 < η₁) (h : η₁ < η₂) :
    arbLossRatio probArb premShock fee (curvIndex η₂ Δi) <
        arbLossRatio probArb premShock fee (curvIndex η₁ Δi) ∧
      surplusRatio premInv fee (curvIndex η₂ Δi) <
        surplusRatio premInv fee (curvIndex η₁ Δi) := by
  have h₁ := curvIndex_mem_Ioo h₀ hΔ
  have h₂ := curvIndex_mem_Ioo (by linarith : 0 < η₂) hΔ
  have h₁_mem : curvIndex η₁ Δi ∈ Ioc (0 : ℝ) 1 := ⟨h₁.1, le_of_lt h₁.2⟩
  have h₂_mem : curvIndex η₂ Δi ∈ Ioc (0 : ℝ) 1 := ⟨h₂.1, le_of_lt h₂.2⟩
  have hcurv_lt : curvIndex η₁ Δi < curvIndex η₂ Δi := curvIndex_strictMono hΔ h
  exact ⟨arbLossRatio_strictAntiOn probArb premShock fee hfee hS hA h₁_mem h₂_mem hcurv_lt,
    surplusRatio_strictAntiOn premInv fee hfee (lt_of_lt_of_le hS hord) h₁_mem h₂_mem hcurv_lt⟩

/-- T31': raising a fixed scalar fee toward its admissible corner strictly lowers `etaStar`.
Fee and curvature are substitute frictions, so a higher fee ends pool draining at lower curvature.
Boundaries: (a) `cOne` depends on fee and may become nonpositive, where the LP payoff is in the
freeze region and `etaStar` is not an argmax; (b) as fee approaches `premInv` from below, both
`kphiStar` and `etaStar` approach zero and switch the controller off; (c) fee-floor `φ̄` is not the
realized fee—`multiFee` gives a volatility-indexed path while η is a grid design constant, and
reconciling these is open. -/
theorem etaStar_coupled_to_fee_corner {premInv fee feeCorner Δi : ℝ}
    (hΔ : 0 < Δi) (hfee : 0 ≤ fee) (hcorner : fee < feeCorner)
    (hadm : feeCorner < premInv) :
    etaStar premInv feeCorner Δi < etaStar premInv fee Δi := by
  unfold etaStar
  have h1p_fee : 0 < 1 + fee := by linarith
  have h1p_feeCorner : 0 < 1 + feeCorner := by linarith
  have h1p_premInv : 0 < 1 + premInv := by linarith
  have h_ratio_lt : (1 + premInv) / (1 + feeCorner) < (1 + premInv) / (1 + fee) := by
    apply div_lt_div_of_pos_left h1p_premInv h1p_fee
    linarith
  have h_log_lt : Real.log ((1 + premInv) / (1 + feeCorner)) < Real.log ((1 + premInv) / (1 + fee)) := by
    apply Real.log_lt_log
    · positivity
    · exact h_ratio_lt
  have hlam_pos : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hdenom_pos : 0 < Δi ^ 2 * Real.log PosSpec.lam := by positivity
  rw [div_lt_div_iff₀ hdenom_pos hdenom_pos]
  nlinarith

end EtaCurvature
