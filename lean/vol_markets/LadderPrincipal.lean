import Mathlib
import vol_markets.Flow

set_option maxHeartbeats 4000000
set_option autoImplicit false

/-!
# LadderPrincipal — the Uniswap-V3 per-tick principal in sqrt-price coordinates

## Intent (user rulings, 2026-08-24)

The ladder-replication design needs the value of a single range position `[sa, sb]`
(sqrt prices, `sp = p_{1/2}` the current sqrt price) held with liquidity `L`, in token1
at the current price — the PRINCIPAL — and the token amounts as the inverses of
`Flow.liquidity0 / liquidity1`. The tree carried only the width payoff
`Flow.terminalPayoff L pil piu = L·(piu − pil)`. This module supplies the objects and
proves:

* I0 — `amount0/amount1` invert `Flow.liquidity0/liquidity1` (both directions);
* P1 — the three-piece principal is CONTINUOUS in `sp` (the pieces agree at `sa`, `sb`);
* P2 — in range, the principal is `token1 held + P · token0 held`
  (`amount1 L sa sp + sp²·amount0 L sp sb`);
* P3 — the principal is CONCAVE in the PRICE `P = sp²` (NOT in `sp`: below the range it
  is `L·sp²·(1/sa − 1/sb)`, convex in `sp`). Verified numerically: concave in `P` on
  2000 random triples, NOT midpoint-concave in `sp`.

The per-tick CLMM identity (A6a, `principal = amount0·[min(P,K) + RAN(K,r)]`) is
DEFERRED to a second bundle pending the exact definition of `RAN`.

## Outcome (2026-08-24)

All four statements (I0, P1, P2, P3) are TRUE exactly as submitted and are now proved;
no refutation or restatement was needed, and no definition was altered. P3 is obtained by
exhibiting the principal, read in the price `P = sp²`, as the pointwise infimum of the
affine family `T_t(P) = L·(t − sa + P/t − P/sb)`, `t ∈ [sa, sb]` (the tangents of the
in-range branch), the infimum being attained at `t = clamp(√P, sa, sb)`; two `private`
lemmas (`principal_le_tangent`, `principal_eq_tangent`) carry that argument.

## Instructions

Prove the `sorry`'d statements. Priority **P2 > I0 > P1 > P3**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. Do not modify
any definition. `0 < sa < sb` guards are load-bearing.
-/

namespace LadderPrincipal

open Flow

/-- token0 amount held by liquidity `L` over the full range `[sa, sb]`:
`L·(sb − sa)/(sa·sb)` — the inverse of `Flow.liquidity0`. -/
noncomputable def amount0 (L sa sb : ℝ) : ℝ := L * (sb - sa) / (sa * sb)

/-- token1 amount held by liquidity `L` over the full range `[sa, sb]`: `L·(sb − sa)` —
the inverse of `Flow.liquidity1`. -/
noncomputable def amount1 (L sa sb : ℝ) : ℝ := L * (sb - sa)

/-- **I0 — the amounts invert the liquidity maps, both directions.** -/
theorem amounts_invert_liquidity (L amt0 amt1 sa sb : ℝ) (hsa : 0 < sa) (hlt : sa < sb) :
    liquidity0 (amount0 L sa sb) sa sb = L ∧ liquidity1 (amount1 L sa sb) sa sb = L ∧
    amount0 (liquidity0 amt0 sa sb) sa sb = amt0 ∧
    amount1 (liquidity1 amt1 sa sb) sa sb = amt1 := by
  have hsb : (0 : ℝ) < sb := lt_trans hsa hlt
  have hd : sb - sa ≠ 0 := by linarith
  refine ⟨?_, ?_, ?_, ?_⟩ <;>
    simp only [liquidity0, liquidity1, amount0, amount1] <;>
    field_simp

/-- The principal: value in token1, at sqrt price `sp`, of liquidity `L` on `[sa, sb]`.
Below the range all token0 (`P·amount0`); in range token1 held plus `P·`token0 held;
above the range all token1. -/
noncomputable def principal (L sa sb sp : ℝ) : ℝ :=
  if sp < sa then L * sp ^ 2 * (1 / sa - 1 / sb)
  else if sp < sb then L * (2 * sp - sa - sp ^ 2 / sb)
  else L * (sb - sa)

/-- **P2 — in-range decomposition.** For `sa ≤ sp < sb`:
`principal = amount1 L sa sp + sp² · amount0 L sp sb`. -/
theorem principal_inRange (L sa sb sp : ℝ) (hsa : 0 < sa) (h1 : sa ≤ sp) (h2 : sp < sb) :
    principal L sa sb sp = amount1 L sa sp + sp ^ 2 * amount0 L sp sb := by
  have hsp : (0 : ℝ) < sp := lt_of_lt_of_le hsa h1
  have hsb : (0 : ℝ) < sb := lt_trans hsp h2
  rw [principal, if_neg (by linarith), if_pos h2, amount0, amount1]
  field_simp
  ring

/-- **P1 — continuity in the sqrt price.** -/
theorem principal_continuous (L sa sb : ℝ) (hsa : 0 < sa) (hlt : sa < sb) :
    Continuous (fun sp => principal L sa sb sp) := by
  have hsb : (0 : ℝ) < sb := lt_trans hsa hlt
  have hrw : (fun sp => principal L sa sb sp)
      = fun sp => if sa ≤ sp then (if sb ≤ sp then L * (sb - sa)
          else L * (2 * sp - sa - sp ^ 2 / sb)) else L * sp ^ 2 * (1 / sa - 1 / sb) := by
    funext sp
    rw [principal]
    split_ifs with h1 h2 h3 h4 h5 <;> first | rfl | (exfalso; linarith)
  rw [hrw]
  have hinner : Continuous fun sp : ℝ => if sb ≤ sp then L * (sb - sa)
      else L * (2 * sp - sa - sp ^ 2 / sb) := by
    apply Continuous.if_le continuous_const (by fun_prop) continuous_const continuous_id
    intro x hx
    subst hx
    field_simp
    ring
  apply Continuous.if_le hinner (by fun_prop) continuous_const continuous_id
  intro x hx
  subst hx
  rw [if_neg (by push_neg; linarith)]
  field_simp
  ring

/-! ### Tangent-line representation of the principal in the price variable

For `t ∈ [sa, sb]` the affine (in the price `P`) function
`T_t(P) = L·(t − sa + P/t − P/sb)` is the tangent at `P = t²` of the in-range branch.
The principal, read in the price `P = sp²`, is the pointwise infimum of this family,
which is how concavity in `P` is obtained below. -/

/-- Every member of the tangent family dominates the principal (in the price variable). -/
private lemma principal_le_tangent (L sa sb t P : ℝ) (hL : 0 ≤ L) (hsa : 0 < sa)
    (hlt : sa < sb) (ht1 : sa ≤ t) (ht2 : t ≤ sb) (hP : 0 ≤ P) :
    principal L sa sb (Real.sqrt P) ≤ L * (t - sa + P / t - P / sb) := by
  have ht0 : (0 : ℝ) < t := lt_of_lt_of_le hsa ht1
  have hsb : (0 : ℝ) < sb := lt_trans hsa hlt
  set s := Real.sqrt P with hs
  have hs0 : 0 ≤ s := Real.sqrt_nonneg P
  have hsq : s ^ 2 = P := Real.sq_sqrt hP
  rw [principal, ← hsq]
  split_ifs with h1 h2
  · -- below the range
    have key : L * (t - sa + s ^ 2 / t - s ^ 2 / sb) - L * s ^ 2 * (1 / sa - 1 / sb)
        = L * ((t - sa) * (sa * t - s ^ 2) / (sa * t)) := by
      field_simp; ring
    have hnn : 0 ≤ L * ((t - sa) * (sa * t - s ^ 2) / (sa * t)) := by
      apply mul_nonneg hL
      apply div_nonneg _ (by positivity)
      exact mul_nonneg (by linarith) (by nlinarith)
    linarith
  · -- in the range
    have key : L * (t - sa + s ^ 2 / t - s ^ 2 / sb) - L * (2 * s - sa - s ^ 2 / sb)
        = L * ((t - s) ^ 2 / t) := by
      field_simp; ring
    have hnn : 0 ≤ L * ((t - s) ^ 2 / t) := by positivity
    linarith
  · -- above the range
    have key : L * (t - sa + s ^ 2 / t - s ^ 2 / sb) - L * (sb - sa)
        = L * ((sb - t) * (s ^ 2 - sb * t) / (sb * t)) := by
      field_simp; ring
    have hnn : 0 ≤ L * ((sb - t) * (s ^ 2 - sb * t) / (sb * t)) := by
      apply mul_nonneg hL
      apply div_nonneg _ (by positivity)
      exact mul_nonneg (by linarith) (by nlinarith)
    linarith

/-- The infimum of the tangent family is attained: at `t = clamp(√P, sa, sb)`. -/
private lemma principal_eq_tangent (L sa sb P : ℝ) (hsa : 0 < sa) (hlt : sa < sb)
    (hP : 0 ≤ P) :
    ∃ t, sa ≤ t ∧ t ≤ sb ∧
      principal L sa sb (Real.sqrt P) = L * (t - sa + P / t - P / sb) := by
  have hsb : (0 : ℝ) < sb := lt_trans hsa hlt
  set s := Real.sqrt P with hs
  have hs0 : 0 ≤ s := Real.sqrt_nonneg P
  have hsq : s ^ 2 = P := Real.sq_sqrt hP
  by_cases h1 : s < sa
  · refine ⟨sa, le_rfl, hlt.le, ?_⟩
    rw [principal, if_pos h1, ← hsq]
    field_simp
    ring
  · push_neg at h1
    by_cases h2 : s < sb
    · refine ⟨s, h1, h2.le, ?_⟩
      have hs0' : (0 : ℝ) < s := lt_of_lt_of_le hsa h1
      rw [principal, if_neg (by linarith), if_pos h2, ← hsq]
      field_simp
      ring
    · push_neg at h2
      refine ⟨sb, hlt.le, le_rfl, ?_⟩
      rw [principal, if_neg (by push_neg; linarith), if_neg (by push_neg; linarith)]
      field_simp
      ring

/-- **P3 — concavity in the PRICE.** `P ↦ principal L sa sb (√P)` is concave on
`P ≥ 0` for `L ≥ 0` (linear below the range, `2√P − sa − P/sb` in range, constant
above). It is NOT concave in `sp` itself. -/
theorem principal_concaveOn_price (L sa sb : ℝ) (hL : 0 ≤ L) (hsa : 0 < sa)
    (hlt : sa < sb) :
    ConcaveOn ℝ (Set.Ici (0 : ℝ)) (fun P => principal L sa sb (Real.sqrt P)) := by
  refine ⟨convex_Ici 0, ?_⟩
  intro x hx y hy a b ha hb hab
  simp only [Set.mem_Ici] at hx hy
  have hQ : (0 : ℝ) ≤ a * x + b * y := by positivity
  obtain ⟨t, ht1, ht2, hEq⟩ :=
    principal_eq_tangent L sa sb (a * x + b * y) hsa hlt hQ
  have hx' := principal_le_tangent L sa sb t x hL hsa hlt ht1 ht2 hx
  have hy' := principal_le_tangent L sa sb t y hL hsa hlt ht1 ht2 hy
  have ht0 : (0 : ℝ) < t := lt_of_lt_of_le hsa ht1
  have hsb : (0 : ℝ) < sb := lt_trans hsa hlt
  have hb' : b = 1 - a := by linarith
  subst hb'
  have hlin : L * (t - sa + (a * x + (1 - a) * y) / t - (a * x + (1 - a) * y) / sb)
      = a * (L * (t - sa + x / t - x / sb)) + (1 - a) * (L * (t - sa + y / t - y / sb)) := by
    field_simp
    ring
  simp only [smul_eq_mul]
  rw [hEq, hlin]
  exact add_le_add (mul_le_mul_of_nonneg_left hx' ha) (mul_le_mul_of_nonneg_left hy' hb)

end LadderPrincipal
