import Mathlib

/-!
# PricePullback — the rate→price maps: the joint lives on the price base (option (b))

## Intent (user ruling, 2026-08-11)

π^φ's two legs walk different trees (the φ-leg by utilization on the curvature base;
the LVR-leg by Γ on the liquidity base). The ruled structure pulls both walkers back to
the COMMON PRICE BASE through two maps, argument-disambiguated on the `p_φ` glyph:

* GAMMA-RATE pullback: `p_φ(G) ≡ G^{-2/3}` — the inverse of the price-argument
  coordinate map `Γ_φ(p) = p^{-3/2}`;
* UTILIZATION pullback: `ν ↦ g = log ν / log κ` (unique exponent, proved elsewhere)
  `↦` tick (the fee-tree accumulator is injective) `↦ p_φ(i)`.

This bundle proves the maps well-defined and COHERENT: both pullbacks of the same tick
land on the same price. Verified numerically before submission.

## Definitions

`pPhiGrid lam eta Di i = 1/(pGrid·pGrid)` the marginal grid price; `gammaRead i` its
`-3/2` power (the pure gamma coordinate read at the tick); `pullG G = G^{-2/3}`;
`gMfee i` the money-leg fee-tree level (Definition 46's `g_M` at unit fee).

## Instructions

Prove the `sorry`'d statements. Priority **B1 > B4 > B2 > B3**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. `1 < lam` and
positive `eta`, `Di` guards are load-bearing (every base positive). Do not modify any
definition.
-/

namespace PricePullback

open Real Set

noncomputable def pGrid (lam eta Di i : ℝ) : ℝ := lam ^ (i * Di * eta / 2)

noncomputable def pPhiGrid (lam eta Di i : ℝ) : ℝ :=
  1 / (pGrid lam eta Di i * pGrid lam eta Di (i + Di))

/-- The pure gamma coordinate read at the tick: `Γ_φ(i) = p_φ(i)^{-3/2}`. -/
noncomputable def gammaRead (lam eta Di i : ℝ) : ℝ :=
  (pPhiGrid lam eta Di i) ^ (-(3 : ℝ) / 2)

/-- The gamma-rate pullback: `p_φ(G) = G^{-2/3}`. -/
noncomputable def pullG (G : ℝ) : ℝ := G ^ (-(2 : ℝ) / 3)

/-- The money-leg fee-tree level at unit fee (Definition 46's `g_M`, `f = 1`). -/
noncomputable def gMfee (lam eta Di i : ℝ) : ℝ :=
  1 / pGrid lam eta Di i - 1 / pGrid lam eta Di (i + Di)

/-- Closed form of the marginal grid price: `p_φ(i) = lam^{-(2i+Δi)·Δi·η/2}`. -/
theorem pPhiGrid_eq_rpow (lam eta Di i : ℝ) (hlam : 0 < lam) :
    pPhiGrid lam eta Di i = lam ^ (-((2 * i + Di) * Di * eta / 2)) := by
  unfold pPhiGrid pGrid
  rw [← Real.rpow_add hlam, Real.rpow_neg hlam.le, one_div]
  ring_nf

/-- Positivity of the marginal grid price. -/
theorem pPhiGrid_pos (lam eta Di i : ℝ) (hlam : 0 < lam) :
    0 < pPhiGrid lam eta Di i := by
  rw [pPhiGrid_eq_rpow _ _ _ _ hlam]
  exact Real.rpow_pos_of_pos hlam _

/-- Closed form of the gamma coordinate: `Γ_φ(i) = lam^{3(2i+Δi)·Δi·η/4}`. -/
theorem gammaRead_eq_rpow (lam eta Di i : ℝ) (hlam : 0 < lam) :
    gammaRead lam eta Di i = lam ^ (3 * (2 * i + Di) * Di * eta / 4) := by
  rw [gammaRead, pPhiGrid_eq_rpow _ _ _ _ hlam, ← Real.rpow_mul hlam.le]
  ring_nf

/-- Closed form of the fee-tree level:
`g_M(i) = lam^{-iΔiη/2}·(1 - lam^{-Δi²η/2})`. -/
theorem gMfee_eq_rpow (lam eta Di i : ℝ) (hlam : 0 < lam) :
    gMfee lam eta Di i
      = lam ^ (-(i * Di * eta / 2)) * (1 - lam ^ (-(Di * Di * eta / 2))) := by
  unfold gMfee pGrid
  rw [one_div, one_div, ← Real.rpow_neg hlam.le, ← Real.rpow_neg hlam.le]
  have h : -((i + Di) * Di * eta / 2) = -(i * Di * eta / 2) + -(Di * Di * eta / 2) := by
    ring
  rw [h, Real.rpow_add hlam]
  ring

/-- **B1 — the gamma pullback inverts, both round trips.** For `p > 0`:
`pullG (p^{-3/2}) = p`; and for `G > 0`: `(pullG G)^{-3/2} = G`. The gamma-rate map is a
bijection between prices and gamma readings. -/
theorem gamma_pullback_roundtrips (p G : ℝ) (hp : 0 < p) (hG : 0 < G) :
    pullG (p ^ (-(3 : ℝ) / 2)) = p ∧ (pullG G) ^ (-(3 : ℝ) / 2) = G := by
  constructor
  · rw [pullG, ← Real.rpow_mul hp.le]
    norm_num
  · rw [pullG, ← Real.rpow_mul hG.le]
    norm_num

/-- **B2 — the gamma coordinate is strictly monotone in the tick** (for `1 < lam`,
`0 < eta`, `0 < Di`): the tick is recoverable from a gamma reading — the map is
injective, hence the pullback of a grid gamma reading is well-defined. -/
theorem gammaRead_strictMono (lam eta Di : ℝ) (hlam : 1 < lam) (heta : 0 < eta)
    (hDi : 0 < Di) :
    StrictMono (fun i => gammaRead lam eta Di i) := by
  have hlam0 : (0:ℝ) < lam := lt_trans zero_lt_one hlam
  intro i j hij
  simp only [gammaRead_eq_rpow _ _ _ _ hlam0]
  rw [Real.rpow_lt_rpow_left_iff hlam]
  nlinarith [mul_pos hDi heta, sub_pos.mpr hij]

/-- **B3 — the fee-tree level is strictly antitone in the tick**: the utilization chain's
last link (tick from the accumulated fee-growth reading) is injective. -/
theorem gMfee_strictAnti (lam eta Di : ℝ) (hlam : 1 < lam) (heta : 0 < eta)
    (hDi : 0 < Di) :
    StrictAnti (fun i => gMfee lam eta Di i) := by
  have hlam0 : (0:ℝ) < lam := lt_trans zero_lt_one hlam
  have hc : 0 < 1 - lam ^ (-(Di * Di * eta / 2)) := by
    have h : lam ^ (-(Di * Di * eta / 2)) < lam ^ (0:ℝ) := by
      rw [Real.rpow_lt_rpow_left_iff hlam]
      nlinarith [mul_pos (mul_pos hDi hDi) heta]
    simpa using h
  intro i j hij
  simp only [gMfee_eq_rpow _ _ _ _ hlam0]
  have h2 : lam ^ (-(j * Di * eta / 2)) < lam ^ (-(i * Di * eta / 2)) := by
    rw [Real.rpow_lt_rpow_left_iff hlam]
    nlinarith [mul_pos hDi heta, sub_pos.mpr hij]
  exact mul_lt_mul_of_pos_right h2 hc

/-- **B4 — COHERENCE: the joint lives on the price base.** Pulling back the gamma
reading of a tick recovers exactly that tick's marginal price:
`pullG (gammaRead i) = pPhiGrid i`. Both walkers, pulled back, land on the same point of
the price base — the joint object needs no new algebra.

All four statements are true as written; no refutation was needed. Note: the proof of
this one only needs `1 < lam` (which already makes every base positive); the `0 < eta`
and `0 < Di` guards are kept because they were requested, but turn out to be
unnecessary here. -/
theorem pullback_coherence (lam eta Di i : ℝ) (hlam : 1 < lam) (heta : 0 < eta)
    (hDi : 0 < Di) :
    pullG (gammaRead lam eta Di i) = pPhiGrid lam eta Di i := by
  have hlam0 : (0:ℝ) < lam := lt_trans zero_lt_one hlam
  have hp : 0 < pPhiGrid lam eta Di i := pPhiGrid_pos _ _ _ _ hlam0
  exact (gamma_pullback_roundtrips _ 1 hp one_pos).1

end PricePullback
