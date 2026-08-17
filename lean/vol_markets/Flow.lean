import Mathlib
import vol_markets.PosSpec

open scoped BigOperators

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Flow / liquidity / payoff / schedule module

This file formalizes the verifiable backbone of the remaining maps in the
request:

* the money→shares flow map `(ΔQ_M, p_risk) → (ΔQ_M, ΔQ_v)` (module `tbd.md`),
* the Uniswap-v3 `getLiquidityForAmounts` map
  `(ΔQ_M, ΔQ_v, p(i), p(i_l), p(i_u)) → (L, i_l, i_u)`,
* the terminal / trajectory payoff `π`,
* the optimal (bang-bang) schedule for `ΔQ_M(t)` that minimizes the trajectory
  payoff.

All quantities are over `ℝ`; the EVM images are RAY (`1e27`) accumulators, X96
prices, and `uint128` liquidity.  The prices `p`, `p_a = p(i_l)`, `p_b = p(i_u)`
are Uniswap `sqrtRatioX96`-style square-root prices.
-/

namespace Flow

/-! ## 1. money → shares flow `(ΔQ_M, p_risk) → ΔQ_v` -/

/-- The exogenous share flow produced by `∂_(M,v)` at the admissible boundary:
`ΔQ_v = ΔQ_M / p_risk`. -/
noncomputable def deltaShares (dQM prisk : ℝ) : ℝ := dQM / prisk

/-
The flow is nonnegative for a nonnegative money inflow and positive price.
-/
lemma deltaShares_nonneg (dQM prisk : ℝ) (h : 0 ≤ dQM) (hp : 0 < prisk) :
    0 ≤ deltaShares dQM prisk := by
      exact div_nonneg h hp.le

/-
The flow is monotone in the money inflow.
-/
lemma deltaShares_mono (dQM dQM' prisk : ℝ) (hp : 0 < prisk) (h : dQM ≤ dQM') :
    deltaShares dQM prisk ≤ deltaShares dQM' prisk := by
      exact div_le_div_of_nonneg_right h hp.le

/-
**Admissible region for `ΔQ_M`.**  Admissibility of the share flow,
`ΔQ_v ≤ Q_M^Σ / p_risk`, is equivalent to the clean money-side ceiling
`ΔQ_M ≤ Q_M^Σ`.  Hence the EVM-implementable admissible interval for the money
flow is exactly `[0, Q_M^Σ]`.
-/
lemma deltaShares_admissible_iff (dQM QMtot prisk : ℝ) (hp : 0 < prisk) :
    deltaShares dQM prisk ≤ QMtot / prisk ↔ dQM ≤ QMtot := by
      unfold deltaShares; rw [ div_le_div_iff_of_pos_right hp ] ;

/-! ## 2. Uniswap-v3 `getLiquidityForAmounts`

Following the reference implementation, with `sa = p(i_l)`, `sb = p(i_u)` the
range boundary sqrt-prices and `sp` the current sqrt-price:

* `liquidity0 amt0 sa sb = amt0 · (sa·sb) / (sb - sa)`  (token0 side),
* `liquidity1 amt1 sa sb = amt1 / (sb - sa)`            (token1 side).
-/

/-- token0-side liquidity. -/
noncomputable def liquidity0 (amt0 sa sb : ℝ) : ℝ := amt0 * (sa * sb) / (sb - sa)

/-- token1-side liquidity. -/
noncomputable def liquidity1 (amt1 sa sb : ℝ) : ℝ := amt1 / (sb - sa)

/-- `getLiquidityForAmounts`: pick the branch according to where the current
sqrt-price `sp` sits relative to the range `[sa, sb]`. -/
noncomputable def getLiquidity (sp sa sb amt0 amt1 : ℝ) : ℝ :=
  if sp ≤ sa then liquidity0 amt0 sa sb
  else if sp < sb then min (liquidity0 amt0 sp sb) (liquidity1 amt1 sa sp)
  else liquidity1 amt1 sa sb

/-
token1-side liquidity is nonnegative for a nonnegative amount and a proper
range.
-/
lemma liquidity1_nonneg (amt1 sa sb : ℝ) (h0 : 0 ≤ amt1) (hlt : sa < sb) :
    0 ≤ liquidity1 amt1 sa sb := by
      exact div_nonneg h0 ( sub_nonneg.mpr hlt.le )

/-
token0-side liquidity is nonnegative for a nonnegative amount, positive
boundary prices and a proper range.
-/
lemma liquidity0_nonneg (amt0 sa sb : ℝ) (h0 : 0 ≤ amt0) (hsa : 0 < sa)
    (hlt : sa < sb) : 0 ≤ liquidity0 amt0 sa sb := by
      exact div_nonneg ( mul_nonneg h0 ( mul_nonneg hsa.le ( by linarith ) ) ) ( by linarith )

/-
token1-side liquidity is monotone in the token1 amount.
-/
lemma liquidity1_mono (amt1 amt1' sa sb : ℝ) (hlt : sa < sb) (h : amt1 ≤ amt1') :
    liquidity1 amt1 sa sb ≤ liquidity1 amt1' sa sb := by
      exact div_le_div_of_nonneg_right h ( by linarith )

/-
On the EVM, `L = ΔQ_M / (p(i_u) - p(i_l))` in the token1 (below-range) branch;
this records that this liquidity is exactly `liquidity1 (ΔQ_M) (p_il) (p_iu)`.
-/
lemma liquidity1_eq_div (dQM pil piu : ℝ) :
    liquidity1 dQM pil piu = dQM / (piu - pil) := by
      rfl

/-! ## 3. Terminal and trajectory payoff -/

/-- Terminal payoff `π(σ̄) = L·(p(i_u) - p(i_l))`. -/
noncomputable def terminalPayoff (L pil piu : ℝ) : ℝ := L * (piu - pil)

/-- Trajectory payoff `π(σ̄; σ(t), t) = L·(p(i(σ̄)) - p(σ(t)))`. -/
noncomputable def trajPayoff (L pTarget pSigma : ℝ) : ℝ := L * (pTarget - pSigma)

/-
The terminal payoff is nonnegative for nonnegative liquidity and an ordered
range `p(i_l) ≤ p(i_u)`.
-/
lemma terminalPayoff_nonneg (L pil piu : ℝ) (hL : 0 ≤ L) (h : pil ≤ piu) :
    0 ≤ terminalPayoff L pil piu := by
      exact mul_nonneg hL ( sub_nonneg_of_le h )

/-! ## 4. Optimal schedule for `ΔQ_M(t)`

With `L = ΔQ_M / w`, `w = p(i_u) - p(i_l) > 0`, the trajectory payoff as a
function of the control `x = ΔQ_M ∈ [0, X]` (where `X = Q_M^Σ`) is

  `π(x) = (k / w) · x`,  with `k = p(i(σ̄)) - p(σ(t))`.

This is linear in `x`, so the minimizer over `[0, X]` is bang-bang:
* if `k < 0` (realized vol price above target), minimize by `x = X`;
* if `k ≥ 0`, minimize by `x = 0`.
-/

/-
Payoff as a function of the money control, `π(x) = (k/w)·x` with
`L = x / w`.
-/
lemma trajPayoff_control (x w k : ℝ) :
    trajPayoff (x / w) (k) 0 = (k / w) * x := by
      unfold trajPayoff; ring;

/-
**Bang-bang, `k < 0` branch.**  When `k < 0` the payoff `(k/w)·x` is minimized
over `[0, X]` at the upper boundary `x = X`.
-/
lemma schedule_min_high (w k X x : ℝ) (hw : 0 < w) (hk : k < 0)
    (hxX : x ≤ X) :
    (k / w) * X ≤ (k / w) * x := by
      exact mul_le_mul_of_nonpos_left hxX ( div_nonpos_of_nonpos_of_nonneg hk.le hw.le )

/-
**Bang-bang, `k ≥ 0` branch.**  When `k ≥ 0` the payoff `(k/w)·x` is minimized
over `[0, X]` at the lower boundary `x = 0` (value `0`).
-/
lemma schedule_min_low (w k x : ℝ) (hw : 0 < w) (hk : 0 ≤ k)
    (hx0 : 0 ≤ x) :
    (k / w) * 0 ≤ (k / w) * x := by
      gcongr

/-
**Optimal value of the schedule.**  Over the admissible interval `[0, X]`
(with `X ≥ 0`), the minimum of `π(x) = (k/w)·x` equals `min 0 ((k/w)·X)`, and it
is attained (bang-bang) at an endpoint.
-/
lemma schedule_isLeast (w k X : ℝ) (hX : 0 ≤ X) :
    IsLeast ((fun x => (k / w) * x) '' Set.Icc 0 X) (min 0 ((k / w) * X)) := by
      refine' ⟨ _, fun x hx => _ ⟩ <;> norm_num at * ; ring_nf at *;
      · grind +splitImp;
      · cases le_or_gt 0 ( k / w ) <;> [ left; right ] <;> nlinarith [ hx.choose_spec ]

end Flow