import Mathlib

/-!
# SandwichTol — is the slippage limit `tol_slip` a functional of already-defined protocol parameters?

Doc context (VOLATILITY_INSTRUMENTS.md, Definitions 27–28): the sandwich attack on the
CPMM member (χ = 1/2, ε = 0) of the trading-function family. The user conjecture
(2026-08-04): the slippage limit `tol_slip` — currently a FREE tolerance — is embedded in a
functional relationship of parameters the protocol already defines:
  (a) the FEE φ (the attacker pays the fee on both sandwich legs), and/or
  (b) the per-spacing grid step `lam ^ (η·Δi/2)` (a sandwich that binds a large tolerance
      must move the price across a tick spacing).

DERIVE OR REFUTE. Priority order: S4 (fee hurdle) > S5 (grid step) > S3 > S2 > S1.
If a stated candidate form is FALSE, prove the corrected closed form under a NEW name and
keep the refutation as a named counterexample lemma. Do not silently add hypotheses:
document every added hypothesis in the docstring of the theorem it lands on.

Model (self-contained; integration rewires to the project's PosSpec/VolInstrument later):
reserves (qM, qX) with qM, qX > 0; money-leg input Δ > 0; CPMM forward exchange
`fwd qM qX Δ = qX·Δ/(qM+Δ)` (invariant (qM+Δ)(qX − fwd) = qM·qX). Front-run size a ≥ 0;
the attacker's three-step sandwich is front-run `a`, user trade `Δ`, back-run selling the
front-run's output. Marginal price `price qM qX = qM/qX`.

## Outcome of this run

* S1, S2, S3, S5 are TRUE as stated and are proved below.
* S4 as stated is **FALSE**: `sandwich_fee_hurdle_false` exhibits a fee-realistic
  counterexample (φ = 0.3%, qM = qX = Δ = 1, a = 1/250) with realized slippage under the
  candidate hurdle `2φ/(1−φ)` and a strictly profitable fee-paying sandwich.
  The exact closed form (`pnlFee_eq`, `pnlFee_pos_iff`) shows the profitability frontier does
  **not** involve `tol_slip` at all: it is a condition on the *user's* trade size relative to
  the money reserve, `Δ ≤ (φ/(1−φ))·qM` (`sandwich_fee_hurdle_corrected`).
  So the fee schedule Θ_φ does *not* pin `tol_slip`; it pins an admissible *trade size*.
-/

namespace SandwichTol

/-- CPMM forward exchange (Definition 28's `𝒮` on the constant-product member):
money-leg input `Δ`, asset-leg output, at reserves `(qM, qX)`. -/
noncomputable def fwd (qM qX Δ : ℝ) : ℝ := qX * Δ / (qM + Δ)

/-- Asset output of the front-run of size `a`. -/
noncomputable def sA (qM qX a : ℝ) : ℝ := fwd qM qX a

/-- The user's realized output when their trade `Δ` executes AFTER a front-run of size `a`. -/
noncomputable def userOut (qM qX a Δ : ℝ) : ℝ :=
  fwd (qM + a) (qX - sA qM qX a) Δ

/-- Realized user slippage relative to the un-sandwiched execution:
`slip = 1 − userOut/fwd`. The slippage-binding equation of Definition 27 is
`slip qM qX a Δ = tol_slip`. -/
noncomputable def slip (qM qX a Δ : ℝ) : ℝ :=
  1 - userOut qM qX a Δ / fwd qM qX Δ

/-- Money received by the back-run: after the front-run and the user trade, the attacker
sells the `sA` asset units acquired in the front-run. -/
noncomputable def backOut (qM qX a Δ : ℝ) : ℝ :=
  let qM2 := qM + a + Δ
  let qX2 := qX - sA qM qX a - userOut qM qX a Δ
  qM2 * sA qM qX a / (qX2 + sA qM qX a)

/-- Feeless sandwich payoff (Definition 27's `π^sandwich` at the binding front-run,
parameterized directly by the front-run size `a`). -/
noncomputable def pnl (qM qX a Δ : ℝ) : ℝ := backOut qM qX a Δ - a

/-- Fee-aware sandwich payoff: the fee `φ ∈ [0,1)` is charged on the INPUT of each
attacker leg (the curve is quoted on the net flow — doc Rule 6): the front-run's curve
input is `(1−φ)·a`, and the back-run sells `(1−φ)·` of the assets into the curve. -/
noncomputable def pnlFee (qM qX a Δ φ : ℝ) : ℝ :=
  let sA' := fwd qM qX ((1 - φ) * a)
  let uOut := fwd (qM + (1 - φ) * a) (qX - sA') Δ
  let qM2 := qM + (1 - φ) * a + Δ
  let qX2 := qX - sA' - uOut
  qM2 * ((1 - φ) * sA') / (qX2 + (1 - φ) * sA') - a

/-- CPMM marginal price (money per asset). -/
noncomputable def price (qM qX : ℝ) : ℝ := qM / qX

/-- Post-sandwich reserves' price ratio relative to inception. -/
noncomputable def priceRatio (qM qX a Δ : ℝ) : ℝ :=
  price (qM + a + Δ) (qX - sA qM qX a - userOut qM qX a Δ) / price qM qX

/-! ### Closed forms

Every quantity of the model has an elementary rational closed form; these are the workhorses
for S1–S5. -/

/-- Closed form of the user's sandwiched output: `qX·qM·Δ / ((qM+a)(qM+a+Δ))`. -/
lemma userOut_eq (qM qX a Δ : ℝ) (hM : 0 < qM) (hΔ : 0 < Δ) (ha : 0 ≤ a) :
    userOut qM qX a Δ = qX * qM * Δ / ((qM + a) * (qM + a + Δ)) := by
  simp only [sA, userOut, fwd]
  field_simp
  ring

/-- Closed form of the residual asset reserve after the whole sandwich:
`qX − sA − userOut = qX·qM/(qM+a+Δ)`; in particular it is strictly positive, so the
admissibility hypothesis `hadm` used below is automatic. -/
lemma resX_eq (qM qX a Δ : ℝ) (hM : 0 < qM) (hΔ : 0 < Δ) (ha : 0 ≤ a) :
    qX - sA qM qX a - userOut qM qX a Δ = qX * qM / (qM + a + Δ) := by
  simp only [sA, userOut, fwd]
  field_simp
  ring

/-- Closed form of realized slippage: `slip = 1 − qM(qM+Δ)/((qM+a)(qM+a+Δ))`. -/
lemma slip_eq (qM qX a Δ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) (ha : 0 ≤ a) :
    slip qM qX a Δ = 1 - qM * (qM + Δ) / ((qM + a) * (qM + a + Δ)) := by
  unfold slip
  rw [userOut_eq qM qX a Δ hM hΔ ha]
  unfold fwd
  have hqXΔ : qX * Δ ≠ 0 := by nlinarith
  have hden : (qM + a) * (qM + a + Δ) ≠ 0 := by nlinarith
  have hMad : qM + Δ ≠ 0 := by linarith
  field_simp

/-- Closed form of the feeless sandwich payoff:
`pnl = a·Δ·(2qM + a + Δ) / ((qM+a)² + a·Δ)` — note the asset reserve `qX` cancels. -/
lemma pnl_eq (qM qX a Δ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) (ha : 0 ≤ a) :
    pnl qM qX a Δ = a * Δ * (2 * qM + a + Δ) / ((qM + a) ^ 2 + a * Δ) := by
  simp only [pnl, backOut]
  have hresX : qX - sA qM qX a - userOut qM qX a Δ = qX * qM / (qM + a + Δ) := resX_eq qM qX a Δ hM hΔ ha
  have hMa : qM + a > 0 := by linarith
  have hMad : qM + a + Δ > 0 := by linarith
  have hdenom_pos : (qM + a) ^ 2 + a * Δ > 0 := by nlinarith
  have hden : qX - sA qM qX a - userOut qM qX a Δ + sA qM qX a = qX * qM / (qM + a + Δ) + sA qM qX a := by linarith [hresX]
  rw [hden]
  simp only [sA, fwd]
  field_simp
  ring

/-- Closed form of the post-sandwich price ratio: `((qM+a+Δ)/qM)²`. -/
lemma priceRatio_eq (qM qX a Δ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) (ha : 0 ≤ a) :
    priceRatio qM qX a Δ = ((qM + a + Δ) / qM) ^ 2 := by
  simp [priceRatio, price, resX_eq qM qX a Δ hM hΔ ha]
  field_simp

/-- **Closed form of the fee-aware payoff.** With `c = 1−φ`, `b = c·a`, `P = qM + b + Δ`:
`pnlFee = a·(c·P − qM − b)·(c·P + qM) / (qM·(qM+b) + c·b·P)`.
The asset reserve `qX` cancels, and the denominator is strictly positive, so the SIGN of
`pnlFee` is the sign of the first factor `c·P − qM − b = (1−φ)(qM+Δ) − qM − φ(1−φ)a`. -/
lemma pnlFee_eq (qM qX a Δ φ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) (ha : 0 ≤ a)
    (hφ : φ ∈ Set.Ico (0 : ℝ) 1) :
    pnlFee qM qX a Δ φ =
      a * (((1 - φ) * (qM + (1 - φ) * a + Δ) - qM - (1 - φ) * a) *
            ((1 - φ) * (qM + (1 - φ) * a + Δ) + qM)) /
        (qM * (qM + (1 - φ) * a) + (1 - φ) ^ 2 * a * (qM + (1 - φ) * a + Δ)) := by
  have h1φa : qM + (1 - φ) * a > 0 := by nlinarith [hφ.1, hφ.2]
  have hMad : qM + (1 - φ) * a + Δ > 0 := by linarith
  have hresXFee : qX - fwd qM qX ((1 - φ) * a) - fwd (qM + (1 - φ) * a) (qX - fwd qM qX ((1 - φ) * a)) Δ =
                  qX * qM / (qM + (1 - φ) * a + Δ) := by
    simp only [fwd]
    field_simp
    ring
  have hden : qX - fwd qM qX ((1 - φ) * a) - fwd (qM + (1 - φ) * a) (qX - fwd qM qX ((1 - φ) * a)) Δ +
              (1 - φ) * fwd qM qX ((1 - φ) * a) =
              qX * qM / (qM + (1 - φ) * a + Δ) + (1 - φ) * fwd qM qX ((1 - φ) * a) := by
    linarith [hresXFee]
  simp only [pnlFee]
  rw [hden]
  simp only [fwd]
  field_simp
  ring_nf

/-- Positivity of the denominator appearing in `pnlFee_eq`. -/
lemma pnlFee_den_pos (qM a Δ φ : ℝ) (hM : 0 < qM) (hΔ : 0 < Δ) (ha : 0 ≤ a)
    (hφ : φ ∈ Set.Ico (0 : ℝ) 1) :
    0 < qM * (qM + (1 - φ) * a) + (1 - φ) ^ 2 * a * (qM + (1 - φ) * a + Δ) := by
  have h1φ : 0 < 1 - φ := by linarith [hφ.2]
  have ht1 : qM + (1 - φ) * a > 0 := by nlinarith
  have ht2 : qM + (1 - φ) * a + Δ > 0 := by nlinarith
  have hterm1 : qM * (qM + (1 - φ) * a) > 0 := mul_pos hM ht1
  have hterm2 : (1 - φ) ^ 2 * a * (qM + (1 - φ) * a + Δ) ≥ 0 := by positivity
  linarith

/-! ### S1–S3 -/

/-- **S1 (sanity).** No front-run, no payoff. -/
theorem pnl_zero (qM qX Δ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) :
    pnl qM qX 0 Δ = 0 := by
  simp [pnl, backOut, sA, fwd, userOut]

/-- **S2 (binding bijection).** Slippage is strictly increasing in the front-run size, so
the binding equation `slip = tol_slip` pins a unique front-run for each attainable
tolerance. -/
theorem slip_strictMono (qM qX Δ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) :
    StrictMonoOn (fun a => slip qM qX a Δ) (Set.Ici (0 : ℝ)) := by
  intro a ha b hb hab
  simp only
  rw [slip_eq qM qX a Δ hM hX hΔ ha, slip_eq qM qX b Δ hM hX hΔ hb]
  have hqMd : 0 < qM + Δ := by linarith
  have hqMa : 0 < qM + a := by linarith [Set.mem_Ici.mp ha]
  have hqMb : 0 < qM + b := by linarith [Set.mem_Ici.mp hb]
  have hdenA : 0 < (qM + a) * (qM + a + Δ) := by positivity
  have hdenB : 0 < (qM + b) * (qM + b + Δ) := by positivity
  have hden_lt : (qM + a) * (qM + a + Δ) < (qM + b) * (qM + b + Δ) := by nlinarith
  have hnum_pos : 0 < qM * (qM + Δ) := by positivity
  have hfrac_gt : qM * (qM + Δ) / ((qM + a) * (qM + a + Δ)) > qM * (qM + Δ) / ((qM + b) * (qM + b + Δ)) := by
    exact div_lt_div_of_pos_left hnum_pos hdenA hden_lt
  linarith

/-- **S3 (feeless profitability).** Without fees every positive front-run profits —
this is what makes `tol_slip` a live protocol concern at all. DERIVE OR REFUTE; if it
fails for large `a` (reserve exhaustion), prove the corrected version with the natural
admissibility bound under a new name.

TRUE as stated. (The hypothesis `hadm` is in fact automatic — see `resX_eq` — but it is
kept because it is part of the user-supplied statement.) -/
theorem pnl_pos (qM qX a Δ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ) (ha : 0 < a)
    (hadm : sA qM qX a + userOut qM qX a Δ < qX) :
    0 < pnl qM qX a Δ := by
  rw [pnl_eq qM qX a Δ hM hX hΔ (le_of_lt ha)]
  apply div_pos
  · -- numerator: a * Δ * (2 * qM + a + Δ) > 0
    apply mul_pos (mul_pos ha hΔ)
    linarith
  · -- denominator: (qM + a)^2 + a * Δ > 0
    nlinarith

/-! ### S4 — the fee hurdle -/

/- **S4 — THE TARGET (fee hurdle: `tol_slip` as a functional of the fee).**
CANDIDATE form: if the realized slippage of the binding front-run is at most
`2·φ/(1−φ)`, the fee on the two attacker legs eats the sandwich: `pnlFee ≤ 0`.

This candidate is **FALSE** — see `sandwich_fee_hurdle_false` for the counterexample and
`sandwich_fee_hurdle_corrected` for the correct hurdle. The user-supplied statement is kept
here, commented out, for the record.

theorem sandwich_fee_hurdle (qM qX a Δ φ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ)
    (ha : 0 ≤ a) (hφ : φ ∈ Set.Ico (0 : ℝ) 1)
    (hadm : sA qM qX a + userOut qM qX a Δ < qX)
    (hbind : slip qM qX a Δ ≤ 2 * φ / (1 - φ)) :
    pnlFee qM qX a Δ φ ≤ 0 := by
  sorry
-/

/-- **S4, refutation.** The candidate fee hurdle `H(φ) = 2φ/(1−φ)` is FALSE.
Counterexample (fee-realistic): `qM = qX = Δ = 1`, `φ = 3/1000` (a 30 bp fee) and a
front-run `a = 1/250`. Realized slippage is `751/125751 ≈ 0.005972`, which is below the
candidate hurdle `6/997 ≈ 0.006018`, yet the fee-paying sandwich is strictly profitable
(`pnlFee ≈ 0.0118 > 0`). The reason is structural: by `pnlFee_eq` the payoff's sign is
governed by `(1−φ)(qM+Δ) − qM − φ(1−φ)a`, which is bounded away from `0` as `a → 0⁺`
whenever `Δ > (φ/(1−φ))·qM`, while the realized slippage tends to `0` as `a → 0⁺`. -/
theorem sandwich_fee_hurdle_false :
    ¬ (∀ qM qX a Δ φ : ℝ, 0 < qM → 0 < qX → 0 < Δ → 0 ≤ a → φ ∈ Set.Ico (0 : ℝ) 1 →
        sA qM qX a + userOut qM qX a Δ < qX →
        slip qM qX a Δ ≤ 2 * φ / (1 - φ) →
        pnlFee qM qX a Δ φ ≤ 0) := by
  push_neg
  use 1, 1, 1 / 250, 1, 3 / 1000
  norm_num [sA, userOut, slip, pnlFee, fwd]

/-- **S4, the exact frontier.** For a strictly positive front-run the fee-paying sandwich is
profitable **iff** `φ(1−φ)·a < (1−φ)(qM+Δ) − qM`. In particular the frontier involves only
the fee `φ`, the money reserve `qM` and the *user's* trade size `Δ`: the realized slippage
`tol_slip` does not enter, which is exactly why the candidate S4 fails. -/
theorem pnlFee_pos_iff (qM qX a Δ φ : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ)
    (ha : 0 < a) (hφ : φ ∈ Set.Ico (0 : ℝ) 1) :
    0 < pnlFee qM qX a Δ φ ↔ φ * (1 - φ) * a < (1 - φ) * (qM + Δ) - qM := by
  rw [pnlFee_eq qM qX a Δ φ hM hX hΔ (le_of_lt ha) hφ]
  have hden : 0 < qM * (qM + (1 - φ) * a) + (1 - φ) ^ 2 * a * (qM + (1 - φ) * a + Δ) :=
    pnlFee_den_pos qM a Δ φ hM hΔ (le_of_lt ha) hφ
  have hac : 0 < a := ha
  -- The second factor in the numerator is positive
  have hsf : 0 < (1 - φ) * (qM + (1 - φ) * a + Δ) + qM := by
    have h1φ : 0 < 1 - φ := by linarith [hφ.2]
    nlinarith
  -- The first factor simplifies to (1 - φ) * (qM + Δ) - qM - φ * (1 - φ) * a
  have hff : (1 - φ) * (qM + (1 - φ) * a + Δ) - qM - (1 - φ) * a =
             (1 - φ) * (qM + Δ) - qM - φ * (1 - φ) * a := by ring
  have h1φ : 0 < 1 - φ := by linarith [hφ.2]
  rw [div_pos_iff]
  have hden_pos : qM * (qM + (1 - φ) * a) + (1 - φ) ^ 2 * a * (qM + (1 - φ) * a + Δ) < 0 → False :=
    fun h => by linarith
  set f := (1 - φ) * (qM + (1 - φ) * a + Δ) - qM - (1 - φ) * a with hf_def
  set s := (1 - φ) * (qM + (1 - φ) * a + Δ) + qM with hs_def
  constructor
  · intro h
    rcases h with ⟨hnum, _⟩ | ⟨hn, hd⟩
    · rw [mul_pos_iff] at hnum
      cases hnum with
      | inl hnum' =>
        rcases mul_pos_iff.mp hnum'.2 with hfpos | hfns <;> linarith
      | inr hnum' => linarith
    · linarith
  · intro h
    have hf : 0 < f := by rw [hf_def]; linarith
    exact Or.inl ⟨mul_pos hac (mul_pos hf hsf), hden⟩

/-- **S4, corrected (the true fee hurdle).** The fee kills EVERY sandwich — for every
front-run size `a ≥ 0` — exactly when the user's trade is small relative to the money
reserve:
  `Δ ≤ (φ/(1−φ))·qM  ⟹  pnlFee ≤ 0`.
Added hypothesis (documented, replacing the false `hbind`): `hhurdle : Δ ≤ φ/(1-φ) * qM`.
The user-supplied `hadm` is dropped since it is automatic (`resX_eq`) and unused.
Doc consequence: the fee schedule Θ_φ does NOT determine `tol_slip`; it determines an
admissible user trade size. Conversely, by `pnlFee_pos_iff`, if `Δ > (φ/(1−φ))·qM` then
every sufficiently small front-run is profitable no matter how tight `tol_slip` is, so no
choice of `tol_slip > 0` can shut the sandwich channel down. -/
theorem sandwich_fee_hurdle_corrected (qM qX a Δ φ : ℝ) (hM : 0 < qM) (hX : 0 < qX)
    (hΔ : 0 < Δ) (ha : 0 ≤ a) (hφ : φ ∈ Set.Ico (0 : ℝ) 1)
    (hhurdle : Δ ≤ φ / (1 - φ) * qM) :
    pnlFee qM qX a Δ φ ≤ 0 := by
  rw [pnlFee_eq qM qX a Δ φ hM hX hΔ ha hφ]
  apply div_nonpos_of_nonpos_of_nonneg
  · -- numerator ≤ 0
    -- The second factor is positive, so we need (first factor) ≤ 0
    -- First factor = (1 - φ) * Δ - φ * qM - φ * (1 - φ) * a
    have h1φ : 0 < 1 - φ := by linarith [hφ.2]
    have h1φ_nonneg : 0 ≤ 1 - φ := by linarith
    have hφqM : 0 ≤ φ * qM := mul_nonneg hφ.1 (le_of_lt hM)
    -- From hhurdle: (1 - φ) * Δ ≤ φ * qM
    have hhurdle' : (1 - φ) * Δ ≤ φ * qM := by
      calc (1 - φ) * Δ ≤ (1 - φ) * (φ / (1 - φ) * qM) := by nlinarith
        _ = φ * qM := by field_simp
    -- First factor = (1 - φ) * Δ - φ * qM - φ * (1 - φ) * a
    have hfirst_expand : (1 - φ) * (qM + (1 - φ) * a + Δ) - qM - (1 - φ) * a =
                         (1 - φ) * Δ - φ * qM - φ * (1 - φ) * a := by ring
    have hφ1φa : 0 ≤ φ * (1 - φ) * a := by apply mul_nonneg; apply mul_nonneg hφ.1 h1φ_nonneg; exact ha
    have hfirst : (1 - φ) * (qM + (1 - φ) * a + Δ) - qM - (1 - φ) * a ≤ 0 := by linarith
    -- Second factor = (1 - φ) * (qM + (1 - φ) * a + Δ) + qM > 0
    have hpos : 0 < qM + (1 - φ) * a + Δ := by nlinarith
    have hsecond : 0 ≤ (1 - φ) * (qM + (1 - φ) * a + Δ) + qM := by nlinarith
    have hprod : a * (((1 - φ) * (qM + (1 - φ) * a + Δ) - qM - (1 - φ) * a) * ((1 - φ) * (qM + (1 - φ) * a + Δ) + qM)) ≤ 0 := by
      apply mul_nonpos_of_nonneg_of_nonpos ha
      apply mul_nonpos_of_nonpos_of_nonneg hfirst hsecond
    exact hprod
  · -- denominator ≥ 0
    exact le_of_lt (pnlFee_den_pos qM a Δ φ hM hΔ ha hφ)

/-! ### S5 — the grid-step cap -/

/-- **S5 (grid step: `tol_slip` against the per-spacing price step).**
CANDIDATE form: a sandwich whose realized slippage exceeds `1 − r⁻¹` (with
`r > 1` the per-spacing price step, doc value `lam^(η·Δi/2)`, `lam = 1.0001`)
must move the marginal price beyond one spacing: `priceRatio > r`.
Contrapositive: within one spacing (`priceRatio ≤ r`), the binding tolerance is
capped by `1 − r⁻¹` — the conjectured functional relationship tol_slip ↔ Θ_p.

TRUE as stated (proved below): with `priceRatio = ((qM+a+Δ)/qM)²` and
`slip = 1 − qM(qM+Δ)/((qM+a)(qM+a+Δ))`, the inequality reduces to
`qM(qM+a) ≤ (qM+Δ)(qM+a+Δ)`. No hypothesis was added; the user-supplied `hadm` is kept
though it is automatic (`resX_eq`) and unused in the proof. -/
theorem sandwich_grid_cap (qM qX a Δ r : ℝ) (hM : 0 < qM) (hX : 0 < qX) (hΔ : 0 < Δ)
    (ha : 0 ≤ a) (hr : 1 < r)
    (hadm : sA qM qX a + userOut qM qX a Δ < qX)
    (hin : priceRatio qM qX a Δ ≤ r) :
    slip qM qX a Δ ≤ 1 - r⁻¹ := by
  rw [slip_eq qM qX a Δ hM hX hΔ ha]
  rw [priceRatio_eq qM qX a Δ hM hX hΔ ha] at hin
  -- Goal: 1 - qM * (qM + Δ) / ((qM + a) * (qM + a + Δ)) ≤ 1 - r⁻¹
  -- Equivalent to: r⁻¹ ≤ qM * (qM + Δ) / ((qM + a) * (qM + a + Δ))
  have hMA : 0 < qM + a := by linarith
  have hMAΔ : 0 < qM + a + Δ := by linarith
  have hMΔ : 0 < qM + Δ := by linarith
  have h_den : 0 < (qM + a) * (qM + a + Δ) := by positivity
  have h_den2 : 0 < qM * (qM + Δ) := by positivity
  -- Key inequality: (qM + a) * qM ≤ (qM + Δ) * (qM + a + Δ)
  have hkey : (qM + a) * qM ≤ (qM + Δ) * (qM + a + Δ) := by nlinarith [sq_nonneg Δ]
  -- Therefore ((qM + a) * (qM + a + Δ)) / (qM * (qM + Δ)) ≤ ((qM + a + Δ) / qM)^2
  have hratio : (qM + a) * (qM + a + Δ) / (qM * (qM + Δ)) ≤ ((qM + a + Δ) / qM) ^ 2 := by
    have hqM2 : 0 < qM ^ 2 := pow_pos hM 2
    rw [div_pow]
    rw [div_le_div_iff₀ h_den2 hqM2]
    nlinarith [sq_nonneg qM, sq_nonneg (qM + a + Δ), mul_pos hM hMAΔ, hkey]
  -- Now: hratio ≤ hin, so (qM+a)*(qM+a+Δ)/(qM*(qM+Δ)) ≤ r
  have hr' : (qM + a) * (qM + a + Δ) / (qM * (qM + Δ)) ≤ r := le_trans hratio hin
  -- Invert: r⁻¹ ≤ qM*(qM+Δ)/((qM+a)*(qM+a+Δ))
  have hinv : r⁻¹ ≤ qM * (qM + Δ) / ((qM + a) * (qM + a + Δ)) := by
    have hr'2 : (qM + a) * (qM + a + Δ) ≤ r * (qM * (qM + Δ)) := by
      rwa [div_le_iff₀ h_den2] at hr'
    rw [le_div_iff₀ h_den]
    calc r⁻¹ * ((qM + a) * (qM + a + Δ))
        ≤ r⁻¹ * (r * (qM * (qM + Δ))) := by nlinarith [inv_pos.mpr (by linarith : 0 < r)]
      _ = qM * (qM + Δ) := by field_simp
  linarith

end SandwichTol
