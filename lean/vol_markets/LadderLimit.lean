import Mathlib
import vol_markets.GeomMixture
import vol_markets.LadderPrincipal
import vol_markets.VolInstrument

open scoped BigOperators Topology

set_option maxHeartbeats 4000000
set_option autoImplicit false

/-!
# LadderLimit — the hedged ladder and its continuum limit (A1)

## Intent (user ruling 2026-08-24, option (a): a Lean-only hedged-rung object)

The ladder-replication design (scratchpad spec 2026-08-24) hedges every rung in the same
LONG form: mint value minus current principal, in token1 at the current sqrt price. Rungs
below the strike are minted in token1 (`amount1`), rungs at/above it in token0 marked at
the price (`p²·amount0`). The ladder weights rungs by the LIQUIDITY-layer geometric profile
at `ξ* = λ^{−Δi/2}` (`GeomMixture.xiStar`, `GeomProfile.geomWeight`). This module carries
the hedged rung as a LEAN object (the document mints no glyph for it) and proves:

* H1 — the hedged rung is non-negative;
* H2 — it vanishes at the strike, on every rung (all legs OTM at `p*`);
* H3 — closed forms: above-strike rung `Lu(p−a)²/a` in range, `Lu(b−a)(p²−ab)/(ab)`
  once crossed; below-strike rung `Lu(p−b)²/b` in range, `Lu(b−a)(1−p²/(ab))` once crossed;
* A1 — THE LIMIT: with the strike at the MIDPOINT of a fixed tick span `S` and the grid
  refined `Δi = S/(2n)`, `n → ∞`, the normalized ladder `T1/N1` converges pointwise on the
  open span to `c · logPortfolio(p², p*²)` (Demeterfi log portfolio in PRICE coordinates,
  `VolInstrument.logPortfolio`) with a constant `c > 0` INDEPENDENT of `p`. Verified
  numerically: `T1/N1 ÷ logPortfolio → 2.6229…` uniformly across five test prices, the
  across-price spread falling 5e−3 → 5e−5 for `Δi = 200 → 20`.

Rung coordinates: rung `x` spans sqrt prices `[tickPrice Δi (x0+x), tickPrice Δi (x0+x+1)]`
(`PosSpec.tickPrice Δi t = λ^{tΔi/2}`, `t` the rung offset); the strike is the LOWER edge of
rung `xStar`, `p* = tickPrice Δi (x0 + xStar)`.

## Instructions

Prove the `sorry`'d statements. Priority **H2 > H1 > H3 > A1**. A1 is an analytic limit:
if the full statement resists, prove the strongest sub-statement you can under a NEW name
and document precisely what remains (e.g. the exact finite-sum representation of `T1` as a
sum over crossed rungs via H3, or the limit for the crossed-rung tail alone). If any
statement is FALSE as written, refute it as stated (`..._false`, explicit counterexample)
and prove the corrected form under a NEW name (`..._corrected`). A refutation is a
successful outcome. Do not modify any definition. Guards `0 < Δi`, `0 < Lu`, `0 < ΔQ`,
`0 < p`, `0 < xStar < ι` are load-bearing.
-/

namespace LadderLimit

open PosSpec LadderPrincipal GeomProfile GeomMixture VolInstrument Finset

/-- Lower sqrt-price edge of rung `x`. -/
noncomputable def aRung (Δi x0 : ℝ) (x : ℕ) : ℝ := PosSpec.tickPrice Δi (x0 + x)

/-- Upper sqrt-price edge of rung `x`. -/
noncomputable def bRung (Δi x0 : ℝ) (x : ℕ) : ℝ := PosSpec.tickPrice Δi (x0 + x + 1)

/-- Mint value `H_x(p)`: token1 received below the strike; token0 received at/above it,
marked at the price `p²`. -/
noncomputable def mintValue (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) : ℝ :=
  if x < xStar then amount1 Lu (aRung Δi x0 x) (bRung Δi x0 x)
  else p ^ 2 * amount0 Lu (aRung Δi x0 x) (bRung Δi x0 x)

/-- The hedged rung `h_x(p) = H_x(p) − principal` (LONG form). Lean-only object. -/
noncomputable def hedgedRung (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) : ℝ :=
  mintValue Lu Δi x0 xStar x p - principal Lu (aRung Δi x0 x) (bRung Δi x0 x) p

/-- Rung liquidity on the liquidity-layer profile, relative to the unit liquidity. -/
noncomputable def rungWeight (ΔQ Lu Δi : ℝ) (ι x : ℕ) : ℝ :=
  ΔQ * geomWeight (xiStar Δi) ι x / Lu

/-- The hedged ladder `T1(p) = Σ_x (L(i_x)/L_unit)·h_x(p)`. -/
noncomputable def ladderT1 (ΔQ Lu Δi x0 : ℝ) (ι xStar : ℕ) (p : ℝ) : ℝ :=
  ∑ x ∈ range ι, rungWeight ΔQ Lu Δi ι x * hedgedRung Lu Δi x0 xStar x p

/-- The token1 mint notional `N1 = Σ_x (L(i_x)/L_unit)·H_x(p*)`. -/
noncomputable def ladderN1 (ΔQ Lu Δi x0 : ℝ) (ι xStar : ℕ) : ℝ :=
  ∑ x ∈ range ι, rungWeight ΔQ Lu Δi ι x * mintValue Lu Δi x0 xStar x (aRung Δi x0 xStar)

/-! ### Basic rung facts -/

/-- Rung edges are positive sqrt prices. -/
lemma aRung_pos (Δi x0 : ℝ) (x : ℕ) : 0 < aRung Δi x0 x :=
  PosSpec.tickPrice_pos _ _

/-- The upper edge of rung `x` is the lower edge of rung `x+1`. -/
lemma bRung_eq_aRung_succ (Δi x0 : ℝ) (x : ℕ) :
    bRung Δi x0 x = aRung Δi x0 (x + 1) := by
  unfold aRung bRung
  push_cast
  ring_nf

lemma bRung_pos (Δi x0 : ℝ) (x : ℕ) : 0 < bRung Δi x0 x :=
  PosSpec.tickPrice_pos _ _

lemma aRung_lt_bRung (Δi x0 : ℝ) (x : ℕ) (hΔi : 0 < Δi) :
    aRung Δi x0 x < bRung Δi x0 x :=
  PosSpec.tickPrice_lt _ _ _ hΔi (by linarith)

lemma aRung_mono (Δi x0 : ℝ) {x y : ℕ} (hΔi : 0 < Δi) (h : x ≤ y) :
    aRung Δi x0 x ≤ aRung Δi x0 y := by
  refine PosSpec.tickPrice_le _ _ _ hΔi ?_
  have : (x : ℝ) ≤ (y : ℝ) := by exact_mod_cast h
  linarith

/-! ### Closed forms of the two rung shapes

The two hedged shapes, as functions of the rung edges `a < b` and the sqrt price `p`,
independently of the ladder indexing. -/

/-- The above-strike hedged shape `p²·amount0 − principal`. -/
lemma above_shape_closed (Lu a b p : ℝ) (ha : 0 < a) (hab : a < b) :
    (p < a → p ^ 2 * amount0 Lu a b - principal Lu a b p = 0) ∧
    (a ≤ p → p < b →
      p ^ 2 * amount0 Lu a b - principal Lu a b p = Lu * (p - a) ^ 2 / a) ∧
    (b ≤ p → p ^ 2 * amount0 Lu a b - principal Lu a b p
        = Lu * (b - a) * (p ^ 2 - a * b) / (a * b)) := by
  have hb : (0 : ℝ) < b := lt_trans ha hab
  refine ⟨?_, ?_, ?_⟩
  · intro h
    rw [principal, if_pos h, amount0]
    field_simp
    ring
  · intro h1 h2
    rw [principal, if_neg (by linarith), if_pos h2, amount0]
    field_simp
    ring
  · intro h
    rw [principal, if_neg (by linarith), if_neg (by linarith), amount0]
    field_simp

/-- The below-strike hedged shape `amount1 − principal`. -/
lemma below_shape_closed (Lu a b p : ℝ) (ha : 0 < a) (hab : a < b) :
    (p < a → amount1 Lu a b - principal Lu a b p
        = Lu * (b - a) * (1 - p ^ 2 / (a * b))) ∧
    (a ≤ p → p < b → amount1 Lu a b - principal Lu a b p = Lu * (p - b) ^ 2 / b) ∧
    (b ≤ p → amount1 Lu a b - principal Lu a b p = 0) := by
  have hb : (0 : ℝ) < b := lt_trans ha hab
  refine ⟨?_, ?_, ?_⟩
  · intro h
    rw [principal, if_pos h, amount1]
    field_simp
  · intro h1 h2
    rw [principal, if_neg (by linarith), if_pos h2, amount1]
    field_simp
    ring
  · intro h
    rw [principal, if_neg (by linarith), if_neg (by linarith), amount1]
    ring

/-- Unfolding of the hedged rung above the strike. -/
lemma hedgedRung_above (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) (h : xStar ≤ x) :
    hedgedRung Lu Δi x0 xStar x p
      = p ^ 2 * amount0 Lu (aRung Δi x0 x) (bRung Δi x0 x)
          - principal Lu (aRung Δi x0 x) (bRung Δi x0 x) p := by
  rw [hedgedRung, mintValue, if_neg (by omega)]

/-- Unfolding of the hedged rung below the strike. -/
lemma hedgedRung_below (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) (h : x < xStar) :
    hedgedRung Lu Δi x0 xStar x p
      = amount1 Lu (aRung Δi x0 x) (bRung Δi x0 x)
          - principal Lu (aRung Δi x0 x) (bRung Δi x0 x) p := by
  rw [hedgedRung, mintValue, if_pos h]

/-- **H2 — every hedged rung vanishes at the strike.** -/
theorem hedgedRung_atStrike (Lu Δi x0 : ℝ) (xStar x : ℕ) (hΔi : 0 < Δi) :
    hedgedRung Lu Δi x0 xStar x (aRung Δi x0 xStar) = 0 := by
  have ha : 0 < aRung Δi x0 x := aRung_pos _ _ _
  have hab : aRung Δi x0 x < bRung Δi x0 x := aRung_lt_bRung _ _ _ hΔi
  rcases lt_or_ge x xStar with h | h
  · -- below the strike: the strike is at or above the upper edge, all token1
    have hbs : bRung Δi x0 x ≤ aRung Δi x0 xStar := by
      rw [bRung_eq_aRung_succ]
      exact aRung_mono _ _ hΔi (by omega)
    rw [hedgedRung_below _ _ _ _ _ _ h]
    exact (below_shape_closed Lu _ _ _ ha hab).2.2 hbs
  · -- at or above the strike: the strike is at or below the lower edge, all token0
    have hsa : aRung Δi x0 xStar ≤ aRung Δi x0 x := aRung_mono _ _ hΔi h
    rw [hedgedRung_above _ _ _ _ _ _ h]
    rcases eq_or_lt_of_le hsa with heq | hlt
    · rw [(above_shape_closed Lu _ _ _ ha hab).2.1 heq.ge (heq ▸ hab)]
      rw [← heq]
      ring
    · exact (above_shape_closed Lu _ _ _ ha hab).1 hlt

/-- **H1 — the hedged rung is non-negative.** -/
theorem hedgedRung_nonneg (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) (hLu : 0 ≤ Lu)
    (hΔi : 0 < Δi) (hp : 0 < p) :
    0 ≤ hedgedRung Lu Δi x0 xStar x p := by
  have ha : 0 < aRung Δi x0 x := aRung_pos _ _ _
  have hab : aRung Δi x0 x < bRung Δi x0 x := aRung_lt_bRung _ _ _ hΔi
  have hb : 0 < bRung Δi x0 x := bRung_pos _ _ _
  set a := aRung Δi x0 x
  set b := bRung Δi x0 x
  rcases lt_or_ge x xStar with h | h
  · rw [hedgedRung_below _ _ _ _ _ _ h]
    obtain ⟨c1, c2, c3⟩ := below_shape_closed Lu a b p ha hab
    rcases lt_or_ge p a with h1 | h1
    · rw [c1 h1]
      have : p ^ 2 / (a * b) ≤ 1 := by
        rw [div_le_one (by positivity)]
        nlinarith
      have : 0 ≤ 1 - p ^ 2 / (a * b) := by linarith
      have : 0 ≤ b - a := by linarith
      positivity
    · rcases lt_or_ge p b with h2 | h2
      · rw [c2 h1 h2]; positivity
      · rw [c3 h2]
  · rw [hedgedRung_above _ _ _ _ _ _ h]
    obtain ⟨c1, c2, c3⟩ := above_shape_closed Lu a b p ha hab
    rcases lt_or_ge p a with h1 | h1
    · rw [c1 h1]
    · rcases lt_or_ge p b with h2 | h2
      · rw [c2 h1 h2]; positivity
      · rw [c3 h2]
        have hpab : 0 ≤ p ^ 2 - a * b := by nlinarith
        have : 0 ≤ b - a := by linarith
        positivity

/-- **H3 — closed forms.** Above-strike rung (`xStar ≤ x`): `Lu(p−a)²/a` in range and
`Lu(b−a)(p²−ab)/(ab)` once crossed (`b ≤ p`). Below-strike rung (`x < xStar`): `Lu(p−b)²/b`
in range and `Lu(b−a)(1−p²/(ab))` once crossed (`p < a`). -/
theorem hedgedRung_closed_forms (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) (hΔi : 0 < Δi)
    (hp : 0 < p) :
    (xStar ≤ x → aRung Δi x0 x ≤ p → p < bRung Δi x0 x →
      hedgedRung Lu Δi x0 xStar x p = Lu * (p - aRung Δi x0 x) ^ 2 / aRung Δi x0 x) ∧
    (xStar ≤ x → bRung Δi x0 x ≤ p →
      hedgedRung Lu Δi x0 xStar x p
        = Lu * (bRung Δi x0 x - aRung Δi x0 x) * (p ^ 2 - aRung Δi x0 x * bRung Δi x0 x)
            / (aRung Δi x0 x * bRung Δi x0 x)) ∧
    (x < xStar → aRung Δi x0 x ≤ p → p < bRung Δi x0 x →
      hedgedRung Lu Δi x0 xStar x p = Lu * (p - bRung Δi x0 x) ^ 2 / bRung Δi x0 x) ∧
    (x < xStar → p < aRung Δi x0 x →
      hedgedRung Lu Δi x0 xStar x p
        = Lu * (bRung Δi x0 x - aRung Δi x0 x) * (1 - p ^ 2 / (aRung Δi x0 x * bRung Δi x0 x))) := by
  have ha : 0 < aRung Δi x0 x := aRung_pos _ _ _
  have hab : aRung Δi x0 x < bRung Δi x0 x := aRung_lt_bRung _ _ _ hΔi
  obtain ⟨a1, a2, a3⟩ := above_shape_closed Lu (aRung Δi x0 x) (bRung Δi x0 x) p ha hab
  obtain ⟨b1, b2, b3⟩ := below_shape_closed Lu (aRung Δi x0 x) (bRung Δi x0 x) p ha hab
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro hx h1 h2
    rw [hedgedRung_above _ _ _ _ _ _ hx]
    exact a2 h1 h2
  · intro hx h1
    rw [hedgedRung_above _ _ _ _ _ _ hx]
    exact a3 h1
  · intro hx h1 h2
    rw [hedgedRung_below _ _ _ _ _ _ hx]
    exact b2 h1 h2
  · intro hx h1
    rw [hedgedRung_below _ _ _ _ _ _ hx]
    exact b1 h1

/-! ## Towards A1 — elementary logarithm inequalities

The two auxiliary functions `φ(t) = log t − (t−1) + (t−1)²/2` and
`ψ(t) = 1 − 1/t + (t−1)²/2 − log t` are monotone on `(0, ∞)` (their derivatives are
`(t−1)²/t ≥ 0` and `(t−1)²(t+1)/t² ≥ 0`) and vanish at `t = 1`. All the sharp
second-order logarithm bounds used for the rung estimates follow. -/

private lemma phi_mono :
    MonotoneOn (fun t : ℝ => Real.log t - (t - 1) + (t - 1) ^ 2 / 2) (Set.Ioi 0) := by
  have hint : interior (Set.Ioi (0:ℝ)) = Set.Ioi 0 := interior_Ioi
  have hd : ∀ t : ℝ, 0 < t →
      HasDerivAt (fun s : ℝ => Real.log s - (s - 1) + (s - 1) ^ 2 / 2) ((t-1)^2/t) t := by
    intro t ht
    have h1 : HasDerivAt Real.log t⁻¹ t := Real.hasDerivAt_log ht.ne'
    have h2 : HasDerivAt (fun s : ℝ => s - 1) 1 t := (hasDerivAt_id t).sub_const 1
    have h3 : HasDerivAt (fun s : ℝ => (s - 1) ^ 2 / 2) (t - 1) t := by
      simpa using (h2.pow 2).div_const 2
    have h4 := (h1.sub h2).add h3
    convert h4 using 1
    field_simp
    ring
  refine monotoneOn_of_deriv_nonneg (convex_Ioi 0) ?_ ?_ ?_
  · intro t ht
    exact ((hd t ht).continuousAt).continuousWithinAt
  · rw [hint]
    intro t ht
    exact ((hd t ht).differentiableAt).differentiableWithinAt
  · rw [hint]
    intro t (ht : 0 < t)
    rw [(hd t ht).deriv]
    positivity

private lemma psi_mono :
    MonotoneOn (fun t : ℝ => 1 - 1/t + (t - 1) ^ 2 / 2 - Real.log t) (Set.Ioi 0) := by
  have hint : interior (Set.Ioi (0:ℝ)) = Set.Ioi 0 := interior_Ioi
  have hd : ∀ t : ℝ, 0 < t →
      HasDerivAt (fun s : ℝ => 1 - 1/s + (s - 1) ^ 2 / 2 - Real.log s)
        ((t-1)^2*(t+1)/t^2) t := by
    intro t ht
    have h1 : HasDerivAt Real.log t⁻¹ t := Real.hasDerivAt_log ht.ne'
    have h2 : HasDerivAt (fun s : ℝ => s - 1) 1 t := (hasDerivAt_id t).sub_const 1
    have h3 : HasDerivAt (fun s : ℝ => (s - 1) ^ 2 / 2) (t - 1) t := by
      simpa using (h2.pow 2).div_const 2
    have h4 : HasDerivAt (fun s : ℝ => 1 - 1/s) (1/t^2) t := by
      have h5 : HasDerivAt (fun s : ℝ => s⁻¹) (-(t^2)⁻¹) t := hasDerivAt_inv ht.ne'
      simpa [one_div] using h5.const_sub 1
    have h6 := (h4.add h3).sub h1
    convert h6 using 1
    field_simp
    ring
  refine monotoneOn_of_deriv_nonneg (convex_Ioi 0) ?_ ?_ ?_
  · intro t ht
    exact ((hd t ht).continuousAt).continuousWithinAt
  · rw [hint]
    intro t ht
    exact ((hd t ht).differentiableAt).differentiableWithinAt
  · rw [hint]
    intro t (ht : 0 < t)
    rw [(hd t ht).deriv]
    positivity

/-- `log t ≥ (t−1) − (t−1)²/2` for `t ≥ 1`. -/
private lemma log_lower1 {t : ℝ} (ht : 1 ≤ t) : (t - 1) - (t - 1) ^ 2 / 2 ≤ Real.log t := by
  have h := phi_mono (Set.mem_Ioi.2 (by norm_num : (0:ℝ) < 1))
    (Set.mem_Ioi.2 (by linarith : (0:ℝ) < t)) ht
  simp only [Real.log_one] at h
  linarith

/-- `log t ≤ (t−1) − (t−1)²/2` for `0 < t ≤ 1`. -/
private lemma log_upper1 {t : ℝ} (ht0 : 0 < t) (ht : t ≤ 1) :
    Real.log t ≤ (t - 1) - (t - 1) ^ 2 / 2 := by
  have h := phi_mono (Set.mem_Ioi.2 ht0) (Set.mem_Ioi.2 (by norm_num : (0:ℝ) < 1)) ht
  simp only [Real.log_one] at h
  linarith

/-- `log t ≤ 1 − 1/t + (t−1)²/2` for `t ≥ 1`. -/
private lemma log_upper2 {t : ℝ} (ht : 1 ≤ t) : Real.log t ≤ 1 - 1/t + (t - 1) ^ 2 / 2 := by
  have h := psi_mono (Set.mem_Ioi.2 (by norm_num : (0:ℝ) < 1))
    (Set.mem_Ioi.2 (by linarith : (0:ℝ) < t)) ht
  norm_num at h
  rw [one_div]
  linarith

/-- `log t ≥ 1 − 1/t + (t−1)²/2` for `0 < t ≤ 1`. -/
private lemma log_lower2 {t : ℝ} (ht0 : 0 < t) (ht : t ≤ 1) :
    1 - 1/t + (t - 1) ^ 2 / 2 ≤ Real.log t := by
  have h := psi_mono (Set.mem_Ioi.2 ht0) (Set.mem_Ioi.2 (by norm_num : (0:ℝ) < 1)) ht
  norm_num at h
  rw [one_div]
  linarith

/-- `log t ≥ 1 − 1/t` for `t > 0` (the standard bound). -/
private lemma log_lower0 {t : ℝ} (ht0 : 0 < t) : 1 - 1/t ≤ Real.log t := by
  have h := Real.log_le_sub_one_of_pos (show (0:ℝ) < 1/t by positivity)
  rw [one_div, Real.log_inv] at h
  rw [one_div]
  linarith

/-- `log t ≤ (t−1) − (1−1/t)²/2` for `t ≥ 1` (`log_lower2` read at `1/t`). -/
private lemma log_upper3 {t : ℝ} (ht : 1 ≤ t) : Real.log t ≤ (t - 1) - (1 - 1/t) ^ 2 / 2 := by
  have ht0 : (0:ℝ) < t := lt_of_lt_of_le one_pos ht
  have hs0 : (0:ℝ) < 1/t := by positivity
  have hs1 : 1/t ≤ 1 := by rw [div_le_one ht0]; exact ht
  have h := log_lower2 hs0 hs1
  have e1 : 1/(1/t) = t := one_div_one_div t
  have e2 : Real.log (1/t) = -Real.log t := by rw [one_div, Real.log_inv]
  have e3 : (1/t - 1)^2 = (1 - 1/t)^2 := by ring
  rw [e1, e2, e3] at h
  linarith

/-- `log t ≥ (1−1/t) + (1−1/t)²/2` for `t ≥ 1` (`log_upper1` read at `1/t`). -/
private lemma log_lower3 {t : ℝ} (ht : 1 ≤ t) : (1 - 1/t) + (1 - 1/t) ^ 2 / 2 ≤ Real.log t := by
  have ht0 : (0:ℝ) < t := lt_of_lt_of_le one_pos ht
  have hs0 : (0:ℝ) < 1/t := by positivity
  have hs1 : 1/t ≤ 1 := by rw [div_le_one ht0]; exact ht
  have h := log_upper1 hs0 hs1
  have e2 : Real.log (1/t) = -Real.log t := by rw [one_div, Real.log_inv]
  have e3 : (1/t - 1)^2 = (1 - 1/t)^2 := by ring
  rw [e2, e3] at h
  linarith

/-! ## The rung estimate

`Wf p t = log t + p²/(2t²)` is the primitive used to telescope the ladder: its increments
are exactly the continuum integrals `∫ (1 − p²/t²) dt/t` against which each hedged rung,
divided by its lower edge, is squeezed. -/

/-- Primitive of the log-portfolio density in sqrt-price coordinates. -/
noncomputable def Wf (p t : ℝ) : ℝ := Real.log t + p ^ 2 / (2 * t ^ 2)

/-- The increment of `Wf` is half the Demeterfi log portfolio in price coordinates. -/
lemma Wf_sub_eq_logPortfolio (p q : ℝ) (hp : 0 < p) (hq : 0 < q) :
    Wf p q - Wf p p = logPortfolio (p ^ 2) (q ^ 2) / 2 := by
  unfold Wf logPortfolio
  rw [Real.log_div (by positivity) (by positivity), Real.log_pow, Real.log_pow]
  field_simp
  ring

private lemma key_above (u q : ℝ) (hu0 : 0 < u) (hu : 1 ≤ u) (hqu : u ≤ q) :
    (0 ≤ (q^2/2)*(1-1/u^2) - Real.log u) ∧
    ((q^2/2)*(1-1/u^2) - Real.log u ≤ q^2*(1-1/u) - (u-1)) ∧
    (q^2*(1-1/u) - (u-1) ≤ u * ((q^2/2)*(1-1/u^2) - Real.log u)) := by
  have hL1 := log_lower1 hu
  have hL2 := log_upper2 hu
  have hlog : Real.log u ≤ u - 1 := Real.log_le_sub_one_of_pos hu0
  have hq0 : 0 < q := lt_of_lt_of_le hu0 hqu
  have hsq : u^2 ≤ q^2 := by nlinarith
  have h1u : (0:ℝ) ≤ 1 - 1/u^2 := by
    rw [sub_nonneg, div_le_one (by positivity)]; nlinarith
  refine ⟨?_, ?_, ?_⟩
  · have hA : (u^2/2)*(1-1/u^2) = (u^2-1)/2 := by field_simp
    have hB : (u^2/2)*(1-1/u^2) ≤ (q^2/2)*(1-1/u^2) := by nlinarith
    nlinarith
  · have hid : q^2*(1-1/u) - (q^2/2)*(1-1/u^2) = (q^2/2)*(1-1/u)^2 := by
      field_simp; ring
    have hA : (u^2/2)*(1-1/u)^2 = (u-1)^2/2 := by field_simp
    have hB : (u^2/2)*(1-1/u)^2 ≤ (q^2/2)*(1-1/u)^2 := by nlinarith [sq_nonneg (1-1/u)]
    linarith
  · have hid3 : u*((q^2/2)*(1-1/u^2) - Real.log u) - (q^2*(1-1/u) - (u-1))
        = q^2*(u-1)^2/(2*u) - (u * Real.log u - (u-1)) := by
      field_simp; ring
    have hC : u*(u-1)^2/2 ≤ q^2*(u-1)^2/(2*u) := by
      have hkey : q^2*(u-1)^2/(2*u) - u*(u-1)^2/2 = (q^2*(u-1)^2 - u^2*(u-1)^2)/(2*u) := by
        field_simp
      have hnn : 0 ≤ (q^2*(u-1)^2 - u^2*(u-1)^2)/(2*u) := by
        apply div_nonneg _ (by positivity)
        nlinarith [sq_nonneg (u-1)]
      linarith
    have hD : u * Real.log u - (u-1) ≤ u*(u-1)^2/2 := by
      have h5 := mul_le_mul_of_nonneg_left hL2 hu0.le
      have hinv : u * (1/u) = 1 := by field_simp
      nlinarith
    linarith

private lemma key_below (r Q : ℝ) (hr : 1 ≤ r) (hQ0 : 0 < Q) (hQ1 : Q ≤ 1) :
    (0 ≤ Real.log r - (Q^2/2)*(1-1/r^2)) ∧
    (0 ≤ (r-1) - Q^2*(1-1/r)) ∧
    (Real.log r - (Q^2/2)*(1-1/r^2) ≤ (r-1) - Q^2*(1-1/r)) ∧
    ((r-1) - Q^2*(1-1/r) ≤ r * (Real.log r - (Q^2/2)*(1-1/r^2))) := by
  have hr0 : (0:ℝ) < r := lt_of_lt_of_le one_pos hr
  have hlog1 := log_lower0 hr0
  have hlog3 := log_upper3 hr
  have hlog4 := log_lower3 hr
  have hinvle : 1/r ≤ 1 := by rw [div_le_one hr0]; exact hr
  have h1 : (0:ℝ) ≤ 1 - 1/r := by linarith
  have hQsq : Q^2 ≤ 1 := by nlinarith
  refine ⟨?_, ?_, ?_, ?_⟩
  · have e1 : (1:ℝ) - 1/r^2 = (1-1/r)*(1+1/r) := by field_simp; ring
    have e2 : (Q^2/2)*(1-1/r^2) ≤ (1-1/r) := by rw [e1]; nlinarith
    linarith
  · nlinarith
  · have hid : Q^2*(1-1/r) - (Q^2/2)*(1-1/r^2) = (Q^2/2)*(1-1/r)^2 := by
      field_simp; ring
    have hb : (Q^2/2)*(1-1/r)^2 ≤ (1/2)*(1-1/r)^2 := by nlinarith [sq_nonneg (1-1/r)]
    linarith
  · have hid : r * (Real.log r - (Q^2/2)*(1-1/r^2)) - ((r-1) - Q^2*(1-1/r))
        = (r * Real.log r - (r-1)) - Q^2*(r*(1-1/r^2)/2 - (1-1/r)) := by ring
    have e3 : r*(1-1/r^2)/2 - (1-1/r) = (1-1/r)^2*r/2 := by field_simp; ring
    have hnn : 0 ≤ (1-1/r)^2*r/2 := by positivity
    have hb : Q^2*(r*(1-1/r^2)/2 - (1-1/r)) ≤ (1-1/r)^2*r/2 := by rw [e3]; nlinarith
    have hc : (1-1/r)^2*r/2 ≤ r * Real.log r - (r-1) := by
      have h5 := mul_le_mul_of_nonneg_left hlog4 hr0.le
      have hinv : r * (1/r) = 1 := by field_simp
      nlinarith
    linarith

/-- Core estimate above the strike: the hedged shape over `[a, c]`, divided by the lower
edge `a`, is squeezed between the `Wf`-increment and `c/a` times it. -/
private lemma core_above (a c p : ℝ) (ha : 0 < a) (hac : a ≤ c) (hcp : c ≤ p) :
    (0 ≤ Wf p a - Wf p c) ∧
    (Wf p a - Wf p c ≤ (p^2*(1/a - 1/c) - (c-a))/a) ∧
    ((p^2*(1/a-1/c) - (c-a))/a ≤ (c/a) * (Wf p a - Wf p c)) := by
  have hc : 0 < c := lt_of_lt_of_le ha hac
  have hp : 0 < p := lt_of_lt_of_le hc hcp
  set u := c / a with hu_def
  set q := p / a with hq_def
  have hu0 : 0 < u := div_pos hc ha
  have hu1 : 1 ≤ u := (one_le_div ha).2 hac
  have huq : u ≤ q := by simp only [hu_def, hq_def]; gcongr
  have hcu : c = u * a := by rw [hu_def]; field_simp
  have hpq : p = q * a := by rw [hq_def]; field_simp
  have hlogc : Real.log c = Real.log u + Real.log a := by
    rw [hcu, Real.log_mul hu0.ne' ha.ne']
  have hTgt : Wf p a - Wf p c = (q^2/2)*(1-1/u^2) - Real.log u := by
    unfold Wf
    rw [hlogc, hcu, hpq]
    field_simp
    ring
  have hShape : (p^2*(1/a - 1/c) - (c-a))/a = q^2*(1-1/u) - (u-1) := by
    rw [hcu, hpq]; field_simp
  obtain ⟨k1, k2, k3⟩ := key_above u q hu0 hu1 huq
  rw [hTgt, hShape]
  exact ⟨k1, k2, k3⟩

/-- Core estimate below the strike. -/
private lemma core_below (a c b p : ℝ) (ha : 0 < a) (hac : a ≤ c) (hcb : c ≤ b) (hpc : p ≤ c)
    (hp0 : 0 < p) :
    (0 ≤ Wf p b - Wf p c) ∧
    (Wf p b - Wf p c ≤ ((b - c) - p^2*(1/c - 1/b))/a) ∧
    (((b - c) - p^2*(1/c - 1/b))/a ≤ (b/a) * (Wf p b - Wf p c)) := by
  have hc : 0 < c := lt_of_lt_of_le hp0 hpc
  have hb : 0 < b := lt_of_lt_of_le hc hcb
  set v := c / a with hv_def
  set rr := b / c with hr_def
  set Q := p / c with hQ_def
  have hv0 : 0 < v := div_pos hc ha
  have hv1 : 1 ≤ v := (one_le_div ha).2 hac
  have hr1 : 1 ≤ rr := (one_le_div hc).2 hcb
  have hr0 : 0 < rr := lt_of_lt_of_le one_pos hr1
  have hQ0 : 0 < Q := div_pos hp0 hc
  have hQ1 : Q ≤ 1 := (div_le_one hc).2 hpc
  have hca : c = v * a := by rw [hv_def]; field_simp
  have hbc : b = rr * c := by rw [hr_def]; field_simp
  have hpc' : p = Q * c := by rw [hQ_def]; field_simp
  have hlogb : Real.log b = Real.log rr + Real.log c := by
    rw [hbc, Real.log_mul hr0.ne' hc.ne']
  have hTgt : Wf p b - Wf p c = Real.log rr - (Q^2/2)*(1-1/rr^2) := by
    unfold Wf
    rw [hlogb, hbc, hpc']
    field_simp
    ring
  have hShape : ((b - c) - p^2*(1/c - 1/b))/a = v * ((rr-1) - Q^2*(1-1/rr)) := by
    rw [hbc, hpc', hca]; field_simp
  have hba : b / a = v * rr := by rw [hbc, hca]; field_simp
  obtain ⟨k1, k2, k3, k4⟩ := key_below rr Q hr1 hQ0 hQ1
  rw [hTgt, hShape, hba]
  exact ⟨k1, by nlinarith, by nlinarith⟩

/-- Per-rung squeeze, above-strike shape: the hedged rung divided by its lower edge lies
between the `Wf`-increment `Wf p (min p a) − Wf p (min p b)` and `b/a` times it. -/
lemma rung_bound_above (a b p : ℝ) (ha : 0 < a) (hab : a < b) (hp : 0 < p) :
    (0 ≤ Wf p (min p a) - Wf p (min p b)) ∧
    (Wf p (min p a) - Wf p (min p b) ≤ (p^2 * amount0 1 a b - principal 1 a b p)/a) ∧
    ((p^2 * amount0 1 a b - principal 1 a b p)/a
      ≤ (b/a) * (Wf p (min p a) - Wf p (min p b))) := by
  obtain ⟨c1, c2, c3⟩ := above_shape_closed 1 a b p ha hab
  have hb : (0:ℝ) < b := lt_trans ha hab
  rcases lt_or_ge p a with h | h
  · have m1 : min p a = p := min_eq_left h.le
    have m2 : min p b = p := min_eq_left (h.le.trans hab.le)
    rw [m1, m2, c1 h]
    norm_num
  · have m1 : min p a = a := min_eq_right h
    have hac : a ≤ min p b := le_min h hab.le
    have hcp : min p b ≤ p := min_le_left _ _
    have hcb : min p b ≤ b := min_le_right _ _
    have hshape : p^2 * amount0 1 a b - principal 1 a b p
        = p^2*(1/a - 1/(min p b)) - (min p b - a) := by
      rcases lt_or_ge p b with h2 | h2
      · rw [c2 h h2, min_eq_left h2.le]
        field_simp
      · rw [c3 h2, min_eq_right h2]
        field_simp
    obtain ⟨k1, k2, k3⟩ := core_above a (min p b) p ha hac hcp
    rw [m1, hshape]
    refine ⟨k1, k2, k3.trans ?_⟩
    have : min p b / a ≤ b / a := by gcongr
    exact mul_le_mul_of_nonneg_right this k1

/-- Per-rung squeeze, below-strike shape. -/
lemma rung_bound_below (a b p : ℝ) (ha : 0 < a) (hab : a < b) (hp : 0 < p) :
    (0 ≤ Wf p (max p b) - Wf p (max p a)) ∧
    (Wf p (max p b) - Wf p (max p a) ≤ (amount1 1 a b - principal 1 a b p)/a) ∧
    ((amount1 1 a b - principal 1 a b p)/a
      ≤ (b/a) * (Wf p (max p b) - Wf p (max p a))) := by
  obtain ⟨c1, c2, c3⟩ := below_shape_closed 1 a b p ha hab
  have hb : (0:ℝ) < b := lt_trans ha hab
  rcases le_or_gt b p with h | h
  · have m1 : max p b = p := max_eq_left h
    have m2 : max p a = p := max_eq_left (hab.le.trans h)
    rw [m1, m2, c3 h]
    norm_num
  · have m1 : max p b = b := max_eq_right h.le
    have hac : a ≤ max p a := le_max_right _ _
    have hcb : max p a ≤ b := max_le h.le hab.le
    have hpc : p ≤ max p a := le_max_left _ _
    have hshape : amount1 1 a b - principal 1 a b p
        = (b - max p a) - p^2*(1/(max p a) - 1/b) := by
      rcases lt_or_ge p a with h2 | h2
      · rw [c1 h2, max_eq_right h2.le]
        field_simp
      · rw [c2 h2 h, max_eq_left h2]
        field_simp
        ring
    obtain ⟨k1, k2, k3⟩ := core_below a (max p a) b p ha hac hcb hpc hp
    rw [m1, hshape]
    exact ⟨k1, k2, k3⟩

/-! ## The geometric grid

On a fixed tick spacing the rung edges form a geometric sequence of ratio
`r = λ^{Δi/2}`, and the liquidity-profile base is exactly `ξ* = 1/r`. -/

/-- The rung ratio `r = λ^{Δi/2}`: `b_x = r·a_x` and `a_{x+1} = r·a_x`. -/
noncomputable def rungRatio (Δi : ℝ) : ℝ := PosSpec.lam ^ (Δi / 2)

lemma rungRatio_pos (Δi : ℝ) : 0 < rungRatio Δi :=
  Real.rpow_pos_of_pos PosSpec.lam_pos _

lemma one_lt_rungRatio (Δi : ℝ) (hΔi : 0 < Δi) : 1 < rungRatio Δi :=
  Real.one_lt_rpow_iff_of_pos PosSpec.lam_pos |>.2 (Or.inl ⟨PosSpec.one_lt_lam, by linarith⟩)

lemma aRung_succ (Δi x0 : ℝ) (x : ℕ) :
    aRung Δi x0 (x + 1) = rungRatio Δi * aRung Δi x0 x := by
  unfold aRung rungRatio PosSpec.tickPrice
  rw [← Real.rpow_add PosSpec.lam_pos]
  push_cast
  ring_nf

lemma bRung_eq_ratio_mul (Δi x0 : ℝ) (x : ℕ) :
    bRung Δi x0 x = rungRatio Δi * aRung Δi x0 x := by
  rw [bRung_eq_aRung_succ, aRung_succ]

lemma aRung_eq_pow (Δi x0 : ℝ) (x : ℕ) :
    aRung Δi x0 x = aRung Δi x0 0 * rungRatio Δi ^ x := by
  induction x with
  | zero => simp
  | succ k ih => rw [aRung_succ, ih]; ring

lemma xiStar_eq_inv_rungRatio (Δi : ℝ) : xiStar Δi = (rungRatio Δi)⁻¹ := by
  unfold xiStar rungRatio PosSpec.lam
  rw [← Real.rpow_neg_one, ← Real.rpow_mul (by norm_num)]
  ring_nf

/-- `ξ*^x` is exactly the ratio of the first rung edge to the `x`-th. -/
lemma xiStar_pow_mul_aRung (Δi x0 : ℝ) (x : ℕ) :
    xiStar Δi ^ x * aRung Δi x0 x = aRung Δi x0 0 := by
  have hr : (rungRatio Δi) ^ x ≠ 0 := (pow_pos (rungRatio_pos Δi) x).ne'
  rw [xiStar_eq_inv_rungRatio, aRung_eq_pow, inv_pow]
  field_simp

/-! ## Linearity in the unit liquidity -/

lemma mintValue_smul (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) :
    mintValue Lu Δi x0 xStar x p = Lu * mintValue 1 Δi x0 xStar x p := by
  unfold mintValue amount0 amount1
  split_ifs <;> ring

lemma principal_smul (Lu a b sp : ℝ) : principal Lu a b sp = Lu * principal 1 a b sp := by
  unfold principal
  split_ifs <;> ring

lemma hedgedRung_smul (Lu Δi x0 : ℝ) (xStar x : ℕ) (p : ℝ) :
    hedgedRung Lu Δi x0 xStar x p = Lu * hedgedRung 1 Δi x0 xStar x p := by
  unfold hedgedRung
  rw [mintValue_smul, principal_smul Lu]
  ring

/-! ## The ladder sums

The weighted hedged rung `ξ*^x·h_x(p)` is squeezed, rung by rung, between `a_0` times a
telescoping `Wf`-increment and `r` times that; the increments sum to
`Wf p p* − Wf p p = ½ logPortfolio(p², p*²)`. -/

/-- The telescoping target attached to rung `x`. -/
noncomputable def rungTarget (Δi x0 p : ℝ) (xStar x : ℕ) : ℝ :=
  if x < xStar then Wf p (max p (aRung Δi x0 (x+1))) - Wf p (max p (aRung Δi x0 x))
  else Wf p (min p (aRung Δi x0 x)) - Wf p (min p (aRung Δi x0 (x+1)))

/-- Per-rung squeeze of the weighted hedged rung. -/
lemma rung_squeeze (Δi x0 p : ℝ) (xStar x : ℕ) (hΔi : 0 < Δi) (hp : 0 < p) :
    (0 ≤ rungTarget Δi x0 p xStar x) ∧
    (aRung Δi x0 0 * rungTarget Δi x0 p xStar x
      ≤ xiStar Δi ^ x * hedgedRung 1 Δi x0 xStar x p) ∧
    (xiStar Δi ^ x * hedgedRung 1 Δi x0 xStar x p
      ≤ rungRatio Δi * (aRung Δi x0 0 * rungTarget Δi x0 p xStar x)) := by
  have ha : 0 < aRung Δi x0 x := aRung_pos _ _ _
  have ha0 : 0 < aRung Δi x0 0 := aRung_pos _ _ _
  have hab : aRung Δi x0 x < bRung Δi x0 x := aRung_lt_bRung _ _ _ hΔi
  have hxi : xiStar Δi ^ x = aRung Δi x0 0 / aRung Δi x0 x := by
    rw [eq_div_iff ha.ne']
    exact xiStar_pow_mul_aRung _ _ _
  have hratio : bRung Δi x0 x / aRung Δi x0 x = rungRatio Δi := by
    rw [bRung_eq_ratio_mul]
    field_simp
  have hsucc : bRung Δi x0 x = aRung Δi x0 (x+1) := bRung_eq_aRung_succ _ _ _
  rcases lt_or_ge x xStar with h | h
  · obtain ⟨k1, k2, k3⟩ := rung_bound_below (aRung Δi x0 x) (bRung Δi x0 x) p ha hab hp
    rw [hratio] at k3
    rw [rungTarget, if_pos h, hedgedRung_below _ _ _ _ _ _ h, hxi, ← hsucc]
    refine ⟨k1, ?_, ?_⟩
    · have := mul_le_mul_of_nonneg_left k2 ha0.le
      calc aRung Δi x0 0 * (Wf p (max p (bRung Δi x0 x)) - Wf p (max p (aRung Δi x0 x)))
          ≤ aRung Δi x0 0 * ((amount1 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p) / aRung Δi x0 x) := this
        _ = aRung Δi x0 0 / aRung Δi x0 x * (amount1 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p) := by ring
    · have := mul_le_mul_of_nonneg_left k3 ha0.le
      calc aRung Δi x0 0 / aRung Δi x0 x * (amount1 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p)
          = aRung Δi x0 0 * ((amount1 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p) / aRung Δi x0 x) := by ring
        _ ≤ aRung Δi x0 0 * (rungRatio Δi
              * (Wf p (max p (bRung Δi x0 x)) - Wf p (max p (aRung Δi x0 x)))) := this
        _ = rungRatio Δi * (aRung Δi x0 0
              * (Wf p (max p (bRung Δi x0 x)) - Wf p (max p (aRung Δi x0 x)))) := by ring
  · obtain ⟨k1, k2, k3⟩ := rung_bound_above (aRung Δi x0 x) (bRung Δi x0 x) p ha hab hp
    rw [hratio] at k3
    rw [rungTarget, if_neg (by omega), hedgedRung_above _ _ _ _ _ _ h, hxi, ← hsucc]
    refine ⟨k1, ?_, ?_⟩
    · have := mul_le_mul_of_nonneg_left k2 ha0.le
      calc aRung Δi x0 0 * (Wf p (min p (aRung Δi x0 x)) - Wf p (min p (bRung Δi x0 x)))
          ≤ aRung Δi x0 0 * ((p ^ 2 * amount0 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p) / aRung Δi x0 x) := this
        _ = aRung Δi x0 0 / aRung Δi x0 x * (p ^ 2 * amount0 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p) := by ring
    · have := mul_le_mul_of_nonneg_left k3 ha0.le
      calc aRung Δi x0 0 / aRung Δi x0 x * (p ^ 2 * amount0 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p)
          = aRung Δi x0 0 * ((p ^ 2 * amount0 1 (aRung Δi x0 x) (bRung Δi x0 x)
              - principal 1 (aRung Δi x0 x) (bRung Δi x0 x) p) / aRung Δi x0 x) := by ring
        _ ≤ aRung Δi x0 0 * (rungRatio Δi
              * (Wf p (min p (aRung Δi x0 x)) - Wf p (min p (bRung Δi x0 x)))) := this
        _ = rungRatio Δi * (aRung Δi x0 0
              * (Wf p (min p (aRung Δi x0 x)) - Wf p (min p (bRung Δi x0 x)))) := by ring

/-- The rung targets telescope to `Wf p p* − Wf p p`. -/
lemma rungTarget_sum (Δi x0 p : ℝ) {ι : ℕ} (xStar : ℕ) (hxs : xStar ≤ ι)
    (h1 : aRung Δi x0 0 ≤ p) (h2 : p ≤ aRung Δi x0 ι) :
    ∑ x ∈ range ι, rungTarget Δi x0 p xStar x = Wf p (aRung Δi x0 xStar) - Wf p p := by
  classical
  have hsplit : ∑ x ∈ range xStar, rungTarget Δi x0 p xStar x
      + ∑ x ∈ Finset.Ico xStar ι, rungTarget Δi x0 p xStar x
      = ∑ x ∈ range ι, rungTarget Δi x0 p xStar x := by
    rw [range_eq_Ico]
    exact Finset.sum_Ico_consecutive _ (Nat.zero_le _) hxs
  have hlow : ∑ x ∈ range xStar, rungTarget Δi x0 p xStar x
      = Wf p (max p (aRung Δi x0 xStar)) - Wf p (max p (aRung Δi x0 0)) := by
    have : ∀ x ∈ range xStar, rungTarget Δi x0 p xStar x
        = (fun k : ℕ => Wf p (max p (aRung Δi x0 k))) (x+1)
          - (fun k : ℕ => Wf p (max p (aRung Δi x0 k))) x := by
      intro x hx
      rw [rungTarget, if_pos (Finset.mem_range.1 hx)]
    rw [Finset.sum_congr rfl this]
    exact Finset.sum_range_sub (fun k : ℕ => Wf p (max p (aRung Δi x0 k))) xStar
  have hhigh : ∑ x ∈ Finset.Ico xStar ι, rungTarget Δi x0 p xStar x
      = Wf p (min p (aRung Δi x0 xStar)) - Wf p (min p (aRung Δi x0 ι)) := by
    rw [Finset.sum_Ico_eq_sum_range]
    have : ∀ x ∈ range (ι - xStar), rungTarget Δi x0 p xStar (xStar + x)
        = (fun k : ℕ => Wf p (min p (aRung Δi x0 (xStar + k)))) x
          - (fun k : ℕ => Wf p (min p (aRung Δi x0 (xStar + k)))) (x+1) := by
      intro x hx
      rw [rungTarget, if_neg (by omega)]
      rfl
    rw [Finset.sum_congr rfl this,
      Finset.sum_range_sub' (fun k : ℕ => Wf p (min p (aRung Δi x0 (xStar + k)))) (ι - xStar)]
    have hxi : xStar + (ι - xStar) = ι := by omega
    simp only [Nat.add_zero, hxi]
  have hmaxmin : ∀ u v : ℝ, Wf p (max u v) + Wf p (min u v) = Wf p u + Wf p v := by
    intro u v
    rcases le_total u v with huv | huv
    · rw [max_eq_right huv, min_eq_left huv]; ring
    · rw [max_eq_left huv, min_eq_right huv]
  have e0 : max p (aRung Δi x0 0) = p := max_eq_left h1
  have eι : min p (aRung Δi x0 ι) = p := min_eq_left h2
  rw [← hsplit, hlow, hhigh, e0, eι]
  have := hmaxmin p (aRung Δi x0 xStar)
  linarith

/-- The hedged-ladder sum is squeezed between `a₀·½·logPortfolio` and `r` times it. -/
lemma ladderSum_squeeze (Δi x0 p : ℝ) (ι xStar : ℕ) (hΔi : 0 < Δi) (hp : 0 < p)
    (hxs : xStar ≤ ι) (h1 : aRung Δi x0 0 ≤ p) (h2 : p ≤ aRung Δi x0 ι) :
    aRung Δi x0 0 * (Wf p (aRung Δi x0 xStar) - Wf p p)
        ≤ ∑ x ∈ range ι, xiStar Δi ^ x * hedgedRung 1 Δi x0 xStar x p ∧
      ∑ x ∈ range ι, xiStar Δi ^ x * hedgedRung 1 Δi x0 xStar x p
        ≤ rungRatio Δi * (aRung Δi x0 0 * (Wf p (aRung Δi x0 xStar) - Wf p p)) := by
  constructor
  · rw [← rungTarget_sum Δi x0 p xStar hxs h1 h2, Finset.mul_sum]
    exact Finset.sum_le_sum fun x _ => (rung_squeeze Δi x0 p xStar x hΔi hp).2.1
  · rw [← rungTarget_sum Δi x0 p xStar hxs h1 h2, Finset.mul_sum, Finset.mul_sum]
    exact Finset.sum_le_sum fun x _ => (rung_squeeze Δi x0 p xStar x hΔi hp).2.2

/-- Exact closed form of the token1 mint notional of the midpoint ladder: the geometric
sums evaluate to `a₀·[(r−1)·n + (1 − r^{−2n})·r/(r+1)]`. -/
lemma mintSum_eq (Δi x0 : ℝ) (n : ℕ) (hΔi : 0 < Δi) :
    ∑ x ∈ range (2*n), xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n)
      = aRung Δi x0 0 * ((rungRatio Δi - 1) * n
          + (1 - (rungRatio Δi ^ (2*n))⁻¹) * (rungRatio Δi / (rungRatio Δi + 1))) := by
  have hr1 : 1 < rungRatio Δi := one_lt_rungRatio Δi hΔi
  have hr0 : 0 < rungRatio Δi := rungRatio_pos Δi
  set r := rungRatio Δi with hr_def
  set A := aRung Δi x0 0 with hA_def
  have hA0 : 0 < A := aRung_pos _ _ _
  have hrn : (0:ℝ) < r ^ (2*n) := pow_pos hr0 _
  have hsplit : ∑ x ∈ range n, xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n)
      + ∑ x ∈ Finset.Ico n (2*n), xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n)
      = ∑ x ∈ range (2*n), xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n) := by
    rw [range_eq_Ico]
    exact Finset.sum_Ico_consecutive _ (Nat.zero_le _) (by omega)
  have hterm1 : ∀ x ∈ range n,
      xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n) = (r - 1) * A := by
    intro x hx
    rw [mintValue, if_pos (Finset.mem_range.1 hx), amount1, bRung_eq_ratio_mul]
    have hxa := xiStar_pow_mul_aRung Δi x0 x
    calc xiStar Δi ^ x * (1 * (r * aRung Δi x0 x - aRung Δi x0 x))
        = (r - 1) * (xiStar Δi ^ x * aRung Δi x0 x) := by ring
      _ = (r - 1) * A := by rw [hxa]
  have hpart1 : ∑ x ∈ range n, xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n)
      = (n : ℝ) * ((r - 1) * A) := by
    rw [Finset.sum_congr rfl hterm1, Finset.sum_const, Finset.card_range, nsmul_eq_mul]
  have hterm2 : ∀ j ∈ range n,
      xiStar Δi ^ (n + j) * mintValue 1 Δi x0 n (n + j) (aRung Δi x0 n)
        = (A * (r - 1) / r) * ((r^2)⁻¹)^j := by
    intro j _
    have hne : ¬ (n + j < n) := by omega
    rw [mintValue, if_neg hne, amount0, bRung_eq_ratio_mul, ← hr_def]
    have e1 : xiStar Δi ^ (n + j) = (r ^ n * r ^ j)⁻¹ := by
      rw [xiStar_eq_inv_rungRatio, inv_pow, pow_add]
    have e2 : aRung Δi x0 (n + j) = A * (r ^ n * r ^ j) := by
      rw [aRung_eq_pow, pow_add]
    have e3 : aRung Δi x0 n = A * r ^ n := aRung_eq_pow _ _ _
    have e4 : ((r^2)⁻¹)^j = ((r^j)^2)⁻¹ := by
      rw [inv_pow, ← pow_mul, ← pow_mul, Nat.mul_comm]
    have hrj : (0:ℝ) < r ^ j := pow_pos hr0 j
    have hrnn : (0:ℝ) < r ^ n := pow_pos hr0 n
    rw [e1, e2, e3, e4]
    field_simp
  have hpart2 : ∑ x ∈ Finset.Ico n (2*n), xiStar Δi ^ x * mintValue 1 Δi x0 n x (aRung Δi x0 n)
      = (A * (r - 1) / r) * ((((r^2)⁻¹)^n - 1) / ((r^2)⁻¹ - 1)) := by
    rw [Finset.sum_Ico_eq_sum_range]
    have hn : 2 * n - n = n := by omega
    rw [hn, Finset.sum_congr rfl hterm2, ← Finset.mul_sum]
    congr 1
    exact geom_sum_eq (by
      intro hcon
      have : (r:ℝ)^2 = 1 := by
        field_simp at hcon
        linarith [hcon]
      nlinarith) n
  rw [← hsplit, hpart1, hpart2]
  have e5 : ((r^2)⁻¹)^n = (r ^ (2*n))⁻¹ := by
    rw [inv_pow, ← pow_mul]
  rw [e5]
  have hsq : (1:ℝ) < r ^ 2 := by nlinarith
  have hne1 : r + 1 ≠ 0 := by positivity
  have hne2 : r ^ 2 - 1 ≠ 0 := by intro hc; nlinarith
  have hne4 : (1:ℝ) - r ^ 2 ≠ 0 := by intro hc; nlinarith
  have hne3 : (r ^ 2)⁻¹ - 1 ≠ 0 := by
    have hlt : (r ^ 2)⁻¹ < 1 := by
      rw [inv_lt_one₀ (by positivity)]
      nlinarith
    intro hc
    linarith
  field_simp
  ring

/-! ## The normalized ladder -/

lemma ladderT1_eq (ΔQ Lu Δi x0 p : ℝ) (ι xStar : ℕ) (hLu : Lu ≠ 0) :
    ladderT1 ΔQ Lu Δi x0 ι xStar p
      = ΔQ * (1 - xiStar Δi) / (1 - xiStar Δi ^ ι)
        * ∑ x ∈ range ι, xiStar Δi ^ x * hedgedRung 1 Δi x0 xStar x p := by
  unfold ladderT1 rungWeight
  rw [Finset.mul_sum]
  refine Finset.sum_congr rfl fun x _ => ?_
  rw [hedgedRung_smul, geomWeight]
  field_simp

lemma ladderN1_eq (ΔQ Lu Δi x0 : ℝ) (ι xStar : ℕ) (hLu : Lu ≠ 0) :
    ladderN1 ΔQ Lu Δi x0 ι xStar
      = ΔQ * (1 - xiStar Δi) / (1 - xiStar Δi ^ ι)
        * ∑ x ∈ range ι, xiStar Δi ^ x * mintValue 1 Δi x0 xStar x (aRung Δi x0 xStar) := by
  unfold ladderN1 rungWeight
  rw [Finset.mul_sum]
  refine Finset.sum_congr rfl fun x _ => ?_
  rw [mintValue_smul, geomWeight]
  field_simp

lemma xiStar_lt_one' (Δi : ℝ) (hΔi : 0 < Δi) : xiStar Δi < 1 := by
  rw [xiStar_eq_inv_rungRatio, inv_lt_one₀ (rungRatio_pos Δi)]
  exact one_lt_rungRatio Δi hΔi

lemma xiStar_pos' (Δi : ℝ) : 0 < xiStar Δi := by
  rw [xiStar_eq_inv_rungRatio]
  exact inv_pos.2 (rungRatio_pos Δi)

/-- The normalizing prefactor cancels: the normalized ladder is the ratio of the two
weighted sums. -/
lemma ladder_ratio_eq (ΔQ Lu Δi x0 p : ℝ) (ι xStar : ℕ) (hΔQ : 0 < ΔQ) (hLu : 0 < Lu)
    (hΔi : 0 < Δi) (hι : 0 < ι) :
    ladderT1 ΔQ Lu Δi x0 ι xStar p / ladderN1 ΔQ Lu Δi x0 ι xStar
      = (∑ x ∈ range ι, xiStar Δi ^ x * hedgedRung 1 Δi x0 xStar x p)
        / ∑ x ∈ range ι, xiStar Δi ^ x * mintValue 1 Δi x0 xStar x (aRung Δi x0 xStar) := by
  have h1 : xiStar Δi < 1 := xiStar_lt_one' Δi hΔi
  have h0 : 0 < xiStar Δi := xiStar_pos' Δi
  have hpow : xiStar Δi ^ ι < 1 := pow_lt_one₀ h0.le h1 (by omega)
  have hP : ΔQ * (1 - xiStar Δi) / (1 - xiStar Δi ^ ι) ≠ 0 := by
    apply div_ne_zero
    · have : 0 < ΔQ * (1 - xiStar Δi) := by nlinarith
      exact this.ne'
    · linarith
  rw [ladderT1_eq _ _ _ _ _ _ _ hLu.ne', ladderN1_eq _ _ _ _ _ _ hLu.ne',
    mul_div_mul_left _ _ hP]

/-! ## The refining midpoint grid

`Δi = S/(2n)`, `x0 = iL·(2n)/S`: the ladder covers the tick span `[iL, iL+S]` with the
strike at its midpoint. -/

lemma aRung_eq_rpow (Δi x0 : ℝ) (x : ℕ) :
    aRung Δi x0 x = PosSpec.lam ^ (((x0 + x) / 2) * Δi) := rfl

lemma grid_aRung (S iL : ℝ) (hS : 0 < S) (n x : ℕ) (hn : 0 < n) :
    aRung (S / (2 * n)) (iL * (2 * n) / S) x
      = PosSpec.lam ^ ((iL + x * (S / (2 * n))) / 2) := by
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 (by omega)
  rw [aRung_eq_rpow]
  congr 1
  field_simp

lemma grid_aRung_zero (S iL : ℝ) (hS : 0 < S) (n : ℕ) (hn : 0 < n) :
    aRung (S / (2 * n)) (iL * (2 * n) / S) 0 = PosSpec.lam ^ (iL / 2) := by
  rw [grid_aRung S iL hS n 0 hn]
  norm_num

lemma grid_aRung_mid (S iL : ℝ) (hS : 0 < S) (n : ℕ) (hn : 0 < n) :
    aRung (S / (2 * n)) (iL * (2 * n) / S) n = PosSpec.lam ^ ((iL + S / 2) / 2) := by
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 (by omega)
  rw [grid_aRung S iL hS n n hn]
  congr 1
  field_simp

lemma grid_aRung_top (S iL : ℝ) (hS : 0 < S) (n : ℕ) (hn : 0 < n) :
    aRung (S / (2 * n)) (iL * (2 * n) / S) (2 * n) = PosSpec.lam ^ ((iL + S) / 2) := by
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 (by omega)
  rw [grid_aRung S iL hS n (2 * n) hn]
  congr 1
  push_cast
  field_simp

lemma grid_rungRatio_pow (S : ℝ) (n : ℕ) (hn : 0 < n) :
    rungRatio (S / (2 * n)) ^ (2 * n) = PosSpec.lam ^ (S / 2) := by
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 (by omega)
  rw [rungRatio, ← Real.rpow_natCast (PosSpec.lam ^ (S / (2 * n) / 2)) (2 * n),
    ← Real.rpow_mul PosSpec.lam_pos.le]
  congr 1
  push_cast
  field_simp

/-- On the refining grid the rung ratio is `exp(κ·S/(4n))`, `κ = log λ`. -/
lemma grid_rungRatio_exp (S : ℝ) (n : ℕ) (hn : 0 < n) :
    rungRatio (S / (2 * n)) = Real.exp (Real.log PosSpec.lam * S / 4 / n) := by
  have hn' : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.2 (by omega)
  rw [rungRatio, Real.rpow_def_of_pos PosSpec.lam_pos]
  congr 1
  field_simp
  ring

/-- The rung ratio tends to `1` as the grid is refined. -/
lemma tendsto_grid_rungRatio (S : ℝ) :
    Filter.Tendsto (fun n : ℕ => rungRatio (S / (2 * n))) Filter.atTop (𝓝 1) := by
  have h1 : Filter.Tendsto (fun n : ℕ => Real.log PosSpec.lam * S / 4 / (n : ℝ))
      Filter.atTop (𝓝 0) := tendsto_const_div_atTop_nhds_zero_nat _
  have h2 : Filter.Tendsto (fun n : ℕ => Real.exp (Real.log PosSpec.lam * S / 4 / (n : ℝ)))
      Filter.atTop (𝓝 1) := by
    have := (Real.continuous_exp.tendsto 0).comp h1
    simpa using this
  refine h2.congr' ?_
  filter_upwards [Filter.eventually_gt_atTop 0] with n hn
  exact (grid_rungRatio_exp S n hn).symm

/-- The refined rung increments accumulate: `(r_n − 1)·n → κ·S/4`. -/
lemma tendsto_grid_rungRatio_sub (S : ℝ) (hS : 0 < S) :
    Filter.Tendsto (fun n : ℕ => (rungRatio (S / (2 * n)) - 1) * n) Filter.atTop
      (𝓝 (Real.log PosSpec.lam * S / 4)) := by
  set κ := Real.log PosSpec.lam with hκ
  have hκ0 : 0 < κ := Real.log_pos PosSpec.one_lt_lam
  have hlim : Filter.Tendsto (fun n : ℕ => κ * S / 4 * rungRatio (S / (2 * n)))
      Filter.atTop (𝓝 (κ * S / 4)) := by
    have := (tendsto_grid_rungRatio S).const_mul (κ * S / 4)
    simpa using this
  refine tendsto_of_tendsto_of_tendsto_of_le_of_le' tendsto_const_nhds hlim ?_ ?_
  · filter_upwards [Filter.eventually_gt_atTop 0] with n hn
    have hn' : (0:ℝ) < n := by exact_mod_cast hn
    have hx : (0:ℝ) < κ * S / 4 / n := by positivity
    rw [grid_rungRatio_exp S n hn]
    have hexp := Real.add_one_le_exp (κ * S / 4 / (n:ℝ))
    have : κ * S / 4 / (n:ℝ) * n = κ * S / 4 := by field_simp
    nlinarith
  · filter_upwards [Filter.eventually_gt_atTop 0] with n hn
    have hn' : (0:ℝ) < n := by exact_mod_cast hn
    set x := κ * S / 4 / (n:ℝ) with hx_def
    have hxn : x * n = κ * S / 4 := by rw [hx_def]; field_simp
    rw [grid_rungRatio_exp S n hn, ← hx_def]
    have hexp : Real.exp x - 1 ≤ x * Real.exp x := by
      have h1 := Real.add_one_le_exp (-x)
      have h2 : (0:ℝ) < Real.exp x := Real.exp_pos x
      have h3 : Real.exp (-x) * Real.exp x = 1 := by
        rw [← Real.exp_add]; simp
      nlinarith
    calc (Real.exp x - 1) * n ≤ (x * Real.exp x) * n := by
          apply mul_le_mul_of_nonneg_right hexp hn'.le
      _ = κ * S / 4 * Real.exp x := by rw [← hxn]; ring

/-- **A1, explicit form.** With the tick span `[iL, iL+S]`, strike at the midpoint
`p* = λ^{(iL+S/2)/2}` and the refining grid `Δi = S/(2n)`, `ι = 2n`, `xStar = n`,
`x0 = iL/Δi`, the normalized hedged ladder converges to `c · logPortfolio (p²) (p*²)` with the
explicit, `p`-independent constant
`c = 1 / (2·(κ·S/4 + (1 − λ^{−S/2})/2))`, `κ = log λ`. (Numerically, for `S = 4000` this evaluates to `≈ 2.6229`; that evaluation is
an informal check, not part of the formal statement.) -/
theorem ladder_tendsto_logPortfolio_explicit (ΔQ Lu S iL : ℝ) (hΔQ : 0 < ΔQ) (hLu : 0 < Lu)
    (hS : 0 < S) (p : ℝ) (hp1 : PosSpec.lam ^ (iL / 2) < p)
    (hp2 : p < PosSpec.lam ^ ((iL + S) / 2)) :
    Filter.Tendsto
      (fun n : ℕ =>
        ladderT1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n p /
          ladderN1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n)
      Filter.atTop
      (𝓝 (1 / (2 * (Real.log PosSpec.lam * S / 4 + (1 - (PosSpec.lam ^ (S / 2))⁻¹) * (1 / 2)))
            * logPortfolio (p ^ 2) ((PosSpec.lam ^ ((iL + S / 2) / 2)) ^ 2))) := by
  have hkappa0 : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hLampos : (0:ℝ) < PosSpec.lam ^ (S / 2) := Real.rpow_pos_of_pos PosSpec.lam_pos _
  have hLam1 : (1:ℝ) < PosSpec.lam ^ (S / 2) :=
    (Real.one_lt_rpow_iff_of_pos PosSpec.lam_pos).2 (Or.inl ⟨PosSpec.one_lt_lam, by linarith⟩)
  have hLaminv : (PosSpec.lam ^ (S / 2))⁻¹ < 1 := by
    rw [inv_lt_one₀ hLampos]; exact hLam1
  have hLaminv0 : 0 < (PosSpec.lam ^ (S / 2))⁻¹ := inv_pos.2 hLampos
  set Dinf : ℝ :=
    Real.log PosSpec.lam * S / 4 + (1 - (PosSpec.lam ^ (S / 2))⁻¹) * (1 / 2) with hDinf_def
  have hDinf : 0 < Dinf := by
    have h1 : 0 < Real.log PosSpec.lam * S / 4 := by positivity
    have h2 : 0 < 1 - (PosSpec.lam ^ (S / 2))⁻¹ := by linarith
    rw [hDinf_def]; nlinarith
  have ha0pos : (0:ℝ) < PosSpec.lam ^ (iL / 2) := Real.rpow_pos_of_pos PosSpec.lam_pos _
  have hp0 : 0 < p := lt_trans ha0pos hp1
  set pStar : ℝ := PosSpec.lam ^ ((iL + S / 2) / 2) with hpStar_def
  have hpStar0 : 0 < pStar := Real.rpow_pos_of_pos PosSpec.lam_pos _
  set L : ℝ := logPortfolio (p ^ 2) (pStar ^ 2) with hL_def
  set D : ℕ → ℝ := fun n => (rungRatio (S / (2 * n)) - 1) * n
      + (1 - (PosSpec.lam ^ (S / 2))⁻¹)
          * (rungRatio (S / (2 * n)) / (rungRatio (S / (2 * n)) + 1)) with hD_def
  have hDtend : Filter.Tendsto D Filter.atTop (𝓝 Dinf) := by
    have h1 := tendsto_grid_rungRatio_sub S hS
    have hA := tendsto_grid_rungRatio S
    have hB : Filter.Tendsto (fun n : ℕ => rungRatio (S / (2 * n)) + 1) Filter.atTop (𝓝 2) := by
      have h := hA.add_const 1
      norm_num at h
      exact h
    have h2 : Filter.Tendsto (fun n : ℕ => rungRatio (S / (2 * n)) / (rungRatio (S / (2 * n)) + 1))
        Filter.atTop (𝓝 (1 / 2)) := hA.div hB (by norm_num)
    have h3 := h1.add (h2.const_mul (1 - (PosSpec.lam ^ (S / 2))⁻¹))
    rw [hD_def, hDinf_def]
    exact h3
  have hlow : Filter.Tendsto (fun n : ℕ => L / 2 / D n) Filter.atTop
      (𝓝 (1 / (2 * Dinf) * L)) := by
    have h := (tendsto_const_nhds (α := ℕ) (x := L / 2) (f := Filter.atTop)).div hDtend hDinf.ne'
    have he : L / 2 / Dinf = 1 / (2 * Dinf) * L := by field_simp
    rwa [he] at h
  have hup : Filter.Tendsto (fun n : ℕ => rungRatio (S / (2 * n)) * (L / 2) / D n)
      Filter.atTop (𝓝 (1 / (2 * Dinf) * L)) := by
    have h := (((tendsto_grid_rungRatio S).mul
      (tendsto_const_nhds (α := ℕ) (x := L / 2) (f := Filter.atTop))).div hDtend hDinf.ne')
    have he : 1 * (L / 2) / Dinf = 1 / (2 * Dinf) * L := by field_simp
    rwa [he] at h
  have key : ∀ n : ℕ, 0 < n →
      L / 2 / D n ≤ ladderT1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n p /
          ladderN1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n ∧
      ladderT1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n p /
          ladderN1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n
        ≤ rungRatio (S / (2 * n)) * (L / 2) / D n := by
    intro n hn
    have hnR : (0:ℝ) < n := by exact_mod_cast hn
    have hDi : 0 < S / (2 * n) := by positivity
    have hr1 : 1 < rungRatio (S / (2 * n)) := one_lt_rungRatio _ hDi
    have hDn : 0 < D n := by
      have h2 : 0 < 1 - (PosSpec.lam ^ (S / 2))⁻¹ := by linarith
      have h3 : 0 < rungRatio (S / (2 * n)) / (rungRatio (S / (2 * n)) + 1) := by positivity
      have h4 : 0 < (rungRatio (S / (2 * n)) - 1) * n := by nlinarith
      rw [hD_def]
      simp only
      nlinarith
    have hmint : ∑ x ∈ range (2 * n), xiStar (S / (2 * n)) ^ x *
        mintValue 1 (S / (2 * n)) (iL * (2 * n) / S) n x
          (aRung (S / (2 * n)) (iL * (2 * n) / S) n)
        = PosSpec.lam ^ (iL / 2) * D n := by
      rw [mintSum_eq _ _ n hDi, grid_aRung_zero S iL hS n hn, grid_rungRatio_pow S n hn, hD_def]
    have hspan1 : aRung (S / (2 * n)) (iL * (2 * n) / S) 0 ≤ p := by
      rw [grid_aRung_zero S iL hS n hn]; exact hp1.le
    have hspan2 : p ≤ aRung (S / (2 * n)) (iL * (2 * n) / S) (2 * n) := by
      rw [grid_aRung_top S iL hS n hn]; exact hp2.le
    obtain ⟨k1, k2⟩ := ladderSum_squeeze (S / (2 * n)) (iL * (2 * n) / S) p (2 * n) n hDi hp0
      (by omega) hspan1 hspan2
    have hmidW : Wf p (aRung (S / (2 * n)) (iL * (2 * n) / S) n) - Wf p p = L / 2 := by
      rw [grid_aRung_mid S iL hS n hn, ← hpStar_def, Wf_sub_eq_logPortfolio p pStar hp0 hpStar0,
        hL_def]
    rw [hmidW, grid_aRung_zero S iL hS n hn] at k1 k2
    rw [ladder_ratio_eq ΔQ Lu _ _ p (2 * n) n hΔQ hLu hDi (by omega), hmint]
    have hden : 0 < PosSpec.lam ^ (iL / 2) * D n := by positivity
    constructor
    · rw [div_le_div_iff₀ hDn hden]
      nlinarith [mul_le_mul_of_nonneg_right k1 hDn.le]
    · rw [div_le_div_iff₀ hden hDn]
      nlinarith [mul_le_mul_of_nonneg_right k2 hDn.le]
  refine tendsto_of_tendsto_of_tendsto_of_le_of_le' hlow hup ?_ ?_
  · filter_upwards [Filter.eventually_gt_atTop 0] with n hn using (key n hn).1
  · filter_upwards [Filter.eventually_gt_atTop 0] with n hn using (key n hn).2


/-- **A1 — the continuum limit of the hedged ladder.** Fix a tick span `S > 0` starting at
tick `iL`, strike at its midpoint `p* = λ^{(iL + S/2)/2}`. Refining with `Δi = S/(2n)`,
`ι = 2n`, `xStar = n`, `x0 = iL/Δi`: there is a constant `c > 0`, INDEPENDENT of `p`, such
that for every `p` strictly inside the span the normalized ladder converges to
`c · logPortfolio (p²) (p*²)`. -/
theorem ladder_tendsto_logPortfolio (ΔQ Lu S iL : ℝ) (hΔQ : 0 < ΔQ) (hLu : 0 < Lu)
    (hS : 0 < S) :
    ∃ c : ℝ, 0 < c ∧ ∀ p : ℝ, PosSpec.lam ^ (iL / 2) < p → p < PosSpec.lam ^ ((iL + S) / 2) →
      Filter.Tendsto
        (fun n : ℕ =>
          ladderT1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n p /
            ladderN1 ΔQ Lu (S / (2 * n)) (iL * (2 * n) / S) (2 * n) n)
        Filter.atTop
        (𝓝 (c * logPortfolio (p ^ 2) ((PosSpec.lam ^ ((iL + S / 2) / 2)) ^ 2))) := by
  have hkappa0 : 0 < Real.log PosSpec.lam := Real.log_pos PosSpec.one_lt_lam
  have hLampos : (0:ℝ) < PosSpec.lam ^ (S / 2) := Real.rpow_pos_of_pos PosSpec.lam_pos _
  have hLam1 : (1:ℝ) < PosSpec.lam ^ (S / 2) :=
    (Real.one_lt_rpow_iff_of_pos PosSpec.lam_pos).2 (Or.inl ⟨PosSpec.one_lt_lam, by linarith⟩)
  have hLaminv : (PosSpec.lam ^ (S / 2))⁻¹ < 1 := by
    rw [inv_lt_one₀ hLampos]; exact hLam1
  refine ⟨1 / (2 * (Real.log PosSpec.lam * S / 4 + (1 - (PosSpec.lam ^ (S / 2))⁻¹) * (1 / 2))), ?_,
    fun p hp1 hp2 => ladder_tendsto_logPortfolio_explicit ΔQ Lu S iL hΔQ hLu hS p hp1 hp2⟩
  have h1 : 0 < Real.log PosSpec.lam * S / 4 := by positivity
  have h2 : 0 < 1 - (PosSpec.lam ^ (S / 2))⁻¹ := by linarith
  exact div_pos one_pos (by nlinarith)

end LadderLimit
