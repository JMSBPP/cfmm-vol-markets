import Mathlib
import vol_markets.LadderPrincipal

set_option maxHeartbeats 4000000
set_option autoImplicit false

/-!
# ClmmIdentity — the per-tick CLMM identity (A6a) and the principal payoff's gamma

## Intent (peer specification 2026-08-24, scratchpad `RangeAccrualNote.hs` / `CLMMPosition.hs`)

A range position's principal (`LadderPrincipal.principal`, sqrt-price coordinates) factors
as the unit chunk's TOKEN0 AMOUNT times a UNIT CLMM PAYOFF `U(k, r; p) = min(p², k²) + RAN`,
where `k = √(a·b)` is the sqrt strike, `r = b/a` the SQRT-PRICE ratio, and `RAN` the range
accrual note (two arms, `≤ 0` on `[a, b)`, `0` outside). Hand proof (three pieces) and a
Haskell witness (45 grid points, 1e−6) exist on the scratchpad side (PR #53). This bundle
machine-checks:

* A6a — `principal L a b p = amount0 L a b · U(√(ab), b/a; p)` for ALL `p > 0`;
* R1–R3 — RAN riders: vanishes at `a` and `b`, non-positive on `[a, b)`, value at `k`;
* P17 — Proposition 17 of the document: in range, the SECOND DERIVATIVE of the principal
  in the PRICE `P = p²` is `−½·L·P^{−3/2}` — Definition 38's `Γ_φ` carrier.

All verified numerically before submission (A6a: max relative error 1.3e−13 over 3000
random `(L, a, b, p)` across all four regions; P17: finite differences agree to 1e−7).

## Outcome (2026-08-24)

All five statements (A6a, R1, R2, R3, P17) are TRUE exactly as submitted and are now proved;
no refutation or restatement was needed, and no definition was altered. A6a is obtained from
`k/√r = a`, `k·√r = b`, `k² = ab` (with `k = √(ab)`, `r = b/a`), which turn the two RAN arms
into `−b(p−a)²/(b−a)` and `a(2pb − p² − b²)/(b−a)` and make all four regions rational
identities. R2 needs only `1 < r` (see its docstring). P17 uses the local (on the open price
range `(a², b²)`) identification of `P ↦ principal L a b √P` with `L(2√P − a − P/b)`, carried
by the `private` lemma `principal_sqrt_deriv_inRange` for the first derivative.

## Instructions

Prove the `sorry`'d statements. Priority **A6a > P17 > R2 > R1 > R3**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. Do not modify
any definition. `0 < a < b`, `0 < p` guards are load-bearing (`Real.sqrt`, division).
-/

namespace ClmmIdentity

open LadderPrincipal Real

/-- The range accrual note in sqrt-price coordinates: sqrt strike `k`, sqrt-price ratio
`r > 1` (range `[k/√r, k·√r]`), current sqrt price `p`. Two arms meeting at `k`. -/
noncomputable def ran (k r p : ℝ) : ℝ :=
  if p < k / Real.sqrt r then 0
  else if p < k then (2 * p * k * Real.sqrt r - p ^ 2 * r - k ^ 2) / (r - 1)
  else if p < k * Real.sqrt r then (2 * p * k * Real.sqrt r - p ^ 2 - k ^ 2 * r) / (r - 1)
  else 0

/-- The unit CLMM payoff: covered call `min(p², k²)` plus the range accrual note. -/
noncomputable def unitPayoff (k r p : ℝ) : ℝ := min (p ^ 2) (k ^ 2) + ran k r p

/-- **A6a — the per-tick CLMM identity.** With `k = √(a·b)` and `r = b/a`:
`principal L a b p = amount0 L a b · unitPayoff k r p` for every `p > 0`. The
normalization is the unit chunk's token0 amount — a function of `(a, b)`, not a constant
per spacing. -/
theorem principal_eq_amount0_mul_unit (L a b p : ℝ) (ha : 0 < a) (hab : a < b) (hp : 0 < p) :
    principal L a b p = amount0 L a b * unitPayoff (Real.sqrt (a * b)) (b / a) p := by
  have hb : (0:ℝ) < b := ha.trans hab
  have hsa : 0 < Real.sqrt a := Real.sqrt_pos.mpr ha
  set k := Real.sqrt (a * b) with hkdef
  have hk2 : k ^ 2 = a * b := Real.sq_sqrt (by positivity)
  have hkpos : 0 < k := Real.sqrt_pos.mpr (by positivity)
  -- `a < k = √(ab) < b`
  have hak : a < k := by nlinarith
  have hkb : k < b := by nlinarith
  -- `√r = k/a`, hence the range endpoints `k/√r = a` and `k·√r = b`
  have hsr : Real.sqrt (b / a) = k / a := by
    rw [hkdef, Real.sqrt_div' _ ha.le, Real.sqrt_mul ha.le,
      div_eq_div_iff (ne_of_gt hsa) (ne_of_gt ha)]
    linear_combination (-(Real.sqrt b)) * Real.mul_self_sqrt ha.le
  have hkhi : k * Real.sqrt (b / a) = b := by
    rw [hsr]; field_simp; nlinarith
  have hklo : k / Real.sqrt (b / a) = a := by
    rw [hsr]; field_simp
  have hmul : 2 * p * k * Real.sqrt (b / a) = 2 * p * b := by
    rw [mul_assoc, hkhi]
  have hden : b / a - 1 = (b - a) / a := by field_simp
  have hba : b - a ≠ 0 := by intro h; nlinarith
  rw [unitPayoff, ran, principal, amount0, hklo, hkhi, hmul, hk2, hden]
  split_ifs with h1 h2 h3
  · -- below the range: `U = p²`
    rw [min_eq_left (by nlinarith)]
    field_simp; ring
  · -- lower arm `a ≤ p < k`: `U = a(2pb − p² − ab)/(b − a)`
    rw [min_eq_left (show p ^ 2 ≤ a * b by nlinarith)]
    field_simp; ring
  · -- upper arm `k ≤ p < b`: same closed form
    rw [min_eq_right (show a * b ≤ p ^ 2 by nlinarith)]
    field_simp; ring
  · exfalso; linarith
  · -- above the range: `U = ab`
    rw [min_eq_right (show a * b ≤ p ^ 2 by nlinarith)]
    field_simp; ring

/-- **R1 — RAN vanishes at both range endpoints.** -/
theorem ran_endpoints (k r : ℝ) (hk : 0 < k) (hr : 1 < r) :
    ran k r (k / Real.sqrt r) = 0 ∧ ran k r (k * Real.sqrt r) = 0 := by
  have hr0 : (0:ℝ) < r := by linarith
  have hs : Real.sqrt r > 1 := by
    rw [show (1:ℝ) = Real.sqrt 1 by simp]
    exact Real.sqrt_lt_sqrt (by norm_num) hr
  have hs2 : Real.sqrt r ^ 2 = r := Real.sq_sqrt hr0.le
  have hlt : k / Real.sqrt r < k := by
    rw [div_lt_iff₀ (by linarith)]; nlinarith
  constructor
  · rw [ran, if_neg (lt_irrefl _), if_pos hlt]
    field_simp
    rw [hs2]
    ring
  · rw [ran, if_neg (by nlinarith), if_neg (by nlinarith), if_neg (lt_irrefl _)]

/-- **R2 — RAN is non-positive on the range.** True as stated; in fact `ran k r p ≤ 0` for
every `p` (both arms have numerator `−(p√r − k)²`, resp. `−(p − k√r)²`), so the hypotheses
`0 < k` and `0 < p` turn out not to be needed — they are kept as submitted. -/
theorem ran_nonpos (k r p : ℝ) (hk : 0 < k) (hr : 1 < r) (hp : 0 < p) :
    ran k r p ≤ 0 := by
  have hr0 : (0:ℝ) < r := by linarith
  have hs2 : Real.sqrt r ^ 2 = r := Real.sq_sqrt hr0.le
  rw [ran]
  split_ifs
  · exact le_rfl
  · -- lower arm: the numerator is `−(p√r − k)²`
    refine div_nonpos_of_nonpos_of_nonneg ?_ (by linarith)
    nlinarith [sq_nonneg (p * Real.sqrt r - k)]
  · -- upper arm: the numerator is `−(p − k√r)²`
    refine div_nonpos_of_nonpos_of_nonneg ?_ (by linarith)
    nlinarith [sq_nonneg (p - k * Real.sqrt r)]
  · exact le_rfl

/-- **R3 — RAN at the strike.** `ran k r k = −k²(√r − 1)²/(r − 1)`. -/
theorem ran_at_strike (k r : ℝ) (hk : 0 < k) (hr : 1 < r) :
    ran k r k = -(k ^ 2 * (Real.sqrt r - 1) ^ 2 / (r - 1)) := by
  have hr0 : (0:ℝ) < r := by linarith
  have hs : Real.sqrt r > 1 := by
    rw [show (1:ℝ) = Real.sqrt 1 by simp]
    exact Real.sqrt_lt_sqrt (by norm_num) hr
  have hs2 : Real.sqrt r ^ 2 = r := Real.sq_sqrt hr0.le
  have hlt : k / Real.sqrt r < k := by
    rw [div_lt_iff₀ (by linarith)]; nlinarith
  have hsq : (Real.sqrt r - 1) ^ 2 = r - 2 * Real.sqrt r + 1 := by nlinarith
  rw [ran, if_neg (by linarith), if_neg (lt_irrefl _), if_pos (by nlinarith), hsq]
  field_simp
  ring

/-- The first derivative in the price, in range: `d/dP [L(2√P − a − P/b)] = L(P^{−1/2} − 1/b)`. -/
private lemma principal_sqrt_deriv_inRange (L a b : ℝ) (ha : 0 < a) (hab : a < b)
    {Q : ℝ} (hQ1 : a ^ 2 < Q) (hQ2 : Q < b ^ 2) :
    deriv (fun R => principal L a b (Real.sqrt R)) Q = L * ((Real.sqrt Q)⁻¹ - 1 / b) := by
  have hb : (0:ℝ) < b := ha.trans hab
  have hmem : ∀ R ∈ Set.Ioo (a ^ 2) (b ^ 2),
      principal L a b (Real.sqrt R) = L * (2 * Real.sqrt R - a - R / b) := by
    intro R hR
    have hR0 : (0:ℝ) < R := lt_of_le_of_lt (by positivity) hR.1
    have h1 : a < Real.sqrt R := by
      rw [show a = Real.sqrt (a ^ 2) by rw [Real.sqrt_sq ha.le]]
      exact Real.sqrt_lt_sqrt (by positivity) hR.1
    have h2 : Real.sqrt R < b := by
      rw [show b = Real.sqrt (b ^ 2) by rw [Real.sqrt_sq hb.le]]
      exact Real.sqrt_lt_sqrt hR0.le hR.2
    rw [principal, if_neg (by linarith), if_pos h2, Real.sq_sqrt hR0.le]
  have hQ0 : (0:ℝ) < Q := lt_of_le_of_lt (by positivity) hQ1
  have hev : (fun R => principal L a b (Real.sqrt R)) =ᶠ[nhds Q]
      (fun R => L * (2 * Real.sqrt R - a - R / b)) := by
    filter_upwards [(isOpen_Ioo.mem_nhds ⟨hQ1, hQ2⟩ : Set.Ioo (a ^ 2) (b ^ 2) ∈ nhds Q)] with R hR
    exact hmem R hR
  rw [hev.deriv_eq]
  have hs : HasDerivAt Real.sqrt (1 / (2 * Real.sqrt Q)) Q := Real.hasDerivAt_sqrt (ne_of_gt hQ0)
  have hd : HasDerivAt (fun R => L * (2 * Real.sqrt R - a - R / b))
      (L * (2 * (1 / (2 * Real.sqrt Q)) - 0 - 1 / b)) Q := by
    have h := ((hs.const_mul 2).sub_const a).sub ((hasDerivAt_id Q).div_const b)
    simpa using h.const_mul L
  rw [hd.deriv]
  have hsq : 0 < Real.sqrt Q := Real.sqrt_pos.mpr hQ0
  field_simp
  ring

/-- **P17 — the principal payoff is Definition 38's carrier.** In range (`a² < P < b²`),
the second derivative in the PRICE of `P ↦ principal L a b (√P)` is `−½·L·P^{−3/2}`. -/
theorem principal_price_second_deriv (L a b P : ℝ) (ha : 0 < a) (hab : a < b)
    (hP1 : a ^ 2 < P) (hP2 : P < b ^ 2) :
    deriv (fun Q => deriv (fun R => principal L a b (Real.sqrt R)) Q) P
      = -(1 / 2) * L * P ^ (-(3 : ℝ) / 2) := by
  have hb : (0:ℝ) < b := ha.trans hab
  have hP0 : (0:ℝ) < P := lt_of_le_of_lt (by positivity) hP1
  have hsq : 0 < Real.sqrt P := Real.sqrt_pos.mpr hP0
  have hev : (fun Q => deriv (fun R => principal L a b (Real.sqrt R)) Q) =ᶠ[nhds P]
      (fun Q => L * ((Real.sqrt Q)⁻¹ - 1 / b)) := by
    filter_upwards [(isOpen_Ioo.mem_nhds ⟨hP1, hP2⟩ : Set.Ioo (a ^ 2) (b ^ 2) ∈ nhds P)] with Q hQ
    exact principal_sqrt_deriv_inRange L a b ha hab hQ.1 hQ.2
  rw [hev.deriv_eq]
  have hs : HasDerivAt Real.sqrt (1 / (2 * Real.sqrt P)) P := Real.hasDerivAt_sqrt (ne_of_gt hP0)
  have hd : HasDerivAt (fun Q => L * ((Real.sqrt Q)⁻¹ - 1 / b))
      (L * (-(1 / (2 * Real.sqrt P)) / (Real.sqrt P) ^ 2 - 0)) P := by
    have h1 : HasDerivAt (fun Q => (Real.sqrt Q)⁻¹)
        (-(1 / (2 * Real.sqrt P)) / (Real.sqrt P) ^ 2) P := hs.inv (ne_of_gt hsq)
    simpa using (h1.sub_const (1 / b)).const_mul L
  rw [hd.deriv]
  have hPs : Real.sqrt P ^ 2 = P := Real.sq_sqrt hP0.le
  have hrp : P ^ (-(3 : ℝ) / 2) = (P * Real.sqrt P)⁻¹ := by
    rw [show (-(3:ℝ)/2) = -(1 + 1/2) by ring, Real.rpow_neg hP0.le, Real.rpow_add hP0,
      Real.rpow_one, ← Real.sqrt_eq_rpow]
  rw [hrp, hPs]
  field_simp
  ring

end ClmmIdentity
