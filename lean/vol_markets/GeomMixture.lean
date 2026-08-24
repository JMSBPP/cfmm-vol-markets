import Mathlib
import vol_markets.GeomProfile

open scoped BigOperators

set_option maxHeartbeats 4000000
set_option autoImplicit false

/-!
# GeomMixture — the two-kernel geometric profile (Bunni `DoubleGeometric` semantics)

## Intent (user rulings, 2026-08-24)

The ladder-replication design (scratchpad spec 2026-08-24) instantiates the document's
declared-but-undefined LDF parameter `θ_LDF` as `(ξ_P, ξ_C, ω)`: a PUT kernel with base
`ξ_P` on rungs `[0, ι_P)`, a CALL kernel with base `ξ_C` on rungs `[ι_P, ι)`, EACH
normalized on its own sub-span, mixed with weight `ω` on the put side. `ι_P` is derived
from the strike tick (never free). This module is the profile's home; it extends
`GeomProfile.geomWeight` (the single geometric profile) and proves:

* M0 — the mixture is a partition of unity;
* A4 — the double-geometric profile with a COMMON base `ξ` collapses to the single
  geometric profile over `[0, ι)` iff `ω = (1 − ξ^{ι_P})/(1 − ξ^{ι})` (the single
  profile's put-side mass);
* A3 — the `c`-weighted bin mean is the finite weighted-L² minimizer over a fixed bin
  (Finset sums; no measure theory) — the binning loss of the Panoptic leg map;
* A2 — `ξ* = λ^{−Δi/2}` is the L²-argmin over the geometric family against the
  LIQUIDITY-layer target (the log-contract profile `K^{−1/2}` sampled on the price grid,
  normalized), with distance exactly 0 and uniqueness for `ι ≥ 2`. This is the ratio of
  `logContractLiquidity_geometric` — NOT the strike-notional ratio `λ^{−Δi}` of
  `varswapWeight_normalized`; the two layers are distinct (GeomProfile header).

All four verified numerically before submission (ξ = 0.93, ι = 7, ι_P = 3; Δi = 10,
ι = 6: A4 exact at ω*, 3.6e−3 off it; A2 distance 3.5e−32 at ξ*, 7.6e−9 at
ξ*·λ^{±Δi/8}).

## Outcome (2026-08-24)

All five statements (M0, A4, A3, A2a, A2b) are TRUE exactly as submitted and are now
proved; no refutation or restatement was needed, and no definition was altered. The only
additions are three `private` auxiliary lemmas (`pow_ne_one_aux`, `xiStar_pos`,
`xiStar_lt_one`/`xiStar_ne_one`). `geomWeight_sum`, `geomWeight_pos` and
`logContractLiquidity_geometric` are cited, not re-proved.

## Instructions

Prove the `sorry`'d statements. Priority **A4 > M0 > A3 > A2**.
If a statement is FALSE as written, refute it as stated with a named counterexample
(`..._false`) and prove the corrected form under a NEW name (`..._corrected`),
documenting exactly what changed. A refutation is a successful outcome. Do not modify
any definition. Cite `GeomProfile.geomWeight_sum`, `GeomProfile.geomWeight_pos`,
`GeomProfile.logContractLiquidity_geometric` rather than re-proving them.
-/

namespace GeomMixture

open GeomProfile Finset

/-- The two-kernel profile: put kernel `ξP` on `[0, ιP)`, call kernel `ξC` on `[ιP, ι)`,
each normalized on its own sub-span, mixing weight `ω` on the put side. -/
noncomputable def mixWeight (ξP ξC ω : ℝ) (ιP ι : ℕ) (x : ℕ) : ℝ :=
  if x < ιP then ω * geomWeight ξP ιP x else (1 - ω) * geomWeight ξC (ι - ιP) (x - ιP)

/-- Auxiliary: a positive base different from `1` has all its positive powers different
from `1`. -/
private lemma pow_ne_one_aux (ξ : ℝ) (n : ℕ) (h0 : 0 < ξ) (h1 : ξ ≠ 1) (hn : 0 < n) :
    ξ ^ n ≠ 1 := by
  rcases lt_or_gt_of_ne h1 with h | h
  · exact ne_of_lt (pow_lt_one₀ h0.le h hn.ne')
  · exact ne_of_gt (one_lt_pow₀ h hn.ne')

/-- **M0 — partition of unity.** Over `Finset.range ι` the mixture sums to `1` for any
`ω` (each kernel sums to `1` on its own sub-span by `geomWeight_sum`). -/
theorem mixWeight_sum (ξP ξC ω : ℝ) (ιP ι : ℕ) (hP0 : 0 < ξP) (hP1 : ξP ≠ 1)
    (hC0 : 0 < ξC) (hC1 : ξC ≠ 1) (hιP : 0 < ιP) (hlt : ιP < ι) :
    ∑ x ∈ range ι, mixWeight ξP ξC ω ιP ι x = 1 := by
  obtain ⟨k, hk0, rfl⟩ : ∃ k, 0 < k ∧ ι = ιP + k := ⟨ι - ιP, by omega, by omega⟩
  have hsub : ιP + k - ιP = k := by omega
  rw [Finset.sum_range_add]
  have h1 : ∑ x ∈ range ιP, mixWeight ξP ξC ω ιP (ιP + k) x
      = ω * ∑ x ∈ range ιP, geomWeight ξP ιP x := by
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun x hx => ?_
    rw [mixWeight, if_pos (Finset.mem_range.mp hx)]
  have h2 : ∑ x ∈ range k, mixWeight ξP ξC ω ιP (ιP + k) (ιP + x)
      = (1 - ω) * ∑ x ∈ range k, geomWeight ξC k x := by
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl fun x _ => ?_
    rw [mixWeight, if_neg (by omega), hsub, Nat.add_sub_cancel_left]
  rw [h1, h2, geomWeight_sum ξP ιP hP0 hP1 hιP, geomWeight_sum ξC k hC0 hC1 hk0]
  ring

/-- **A4 — collapse to the single geometric profile.** With a common base `ξ`, the
mixture equals `geomWeight ξ ι` on every rung iff `ω = (1 − ξ^{ιP})/(1 − ξ^{ι})`. -/
theorem mix_eq_single_iff (ξ ω : ℝ) (ιP ι : ℕ) (hξ0 : 0 < ξ) (hξ1 : ξ ≠ 1)
    (hιP : 0 < ιP) (hlt : ιP < ι) :
    (∀ x, x < ι → mixWeight ξ ξ ω ιP ι x = geomWeight ξ ι x) ↔
      ω = (1 - ξ ^ ιP) / (1 - ξ ^ ι) := by
  have hι0 : 0 < ι := lt_trans hιP hlt
  have hk0 : 0 < ι - ιP := by omega
  have hne : (1 : ℝ) - ξ ≠ 0 := fun h => hξ1 (by linarith)
  have hpιP : (1 : ℝ) - ξ ^ ιP ≠ 0 := fun h =>
    pow_ne_one_aux ξ ιP hξ0 hξ1 hιP (by linarith)
  have hpι : (1 : ℝ) - ξ ^ ι ≠ 0 := fun h =>
    pow_ne_one_aux ξ ι hξ0 hξ1 hι0 (by linarith)
  have hpk : (1 : ℝ) - ξ ^ (ι - ιP) ≠ 0 := fun h =>
    pow_ne_one_aux ξ (ι - ιP) hξ0 hξ1 hk0 (by linarith)
  have hsplit : ξ ^ ι = ξ ^ ιP * ξ ^ (ι - ιP) := by
    rw [← pow_add]; congr 1; omega
  constructor
  · intro h
    have h0 := h 0 hι0
    rw [mixWeight, if_pos hιP, geomWeight, geomWeight] at h0
    field_simp at h0
    field_simp
    linarith [h0]
  · rintro rfl
    intro x hx
    rw [mixWeight]
    split_ifs with hxP
    · rw [geomWeight, geomWeight]
      field_simp
    · have hxe : ξ ^ x = ξ ^ ιP * ξ ^ (x - ιP) := by
        rw [← pow_add]; congr 1; omega
      have hpι' : (1 : ℝ) - ξ ^ ιP * ξ ^ (ι - ιP) ≠ 0 := by rw [← hsplit]; exact hpι
      rw [geomWeight, geomWeight, hxe, hsplit]
      field_simp
      ring

/-- The `c`-weighted mean of `L` over a bin `B`. -/
noncomputable def wMean (B : Finset ℕ) (c L : ℕ → ℝ) : ℝ :=
  (∑ x ∈ B, c x * L x) / (∑ x ∈ B, c x)

/-- **A3 — the bin mean is the finite weighted-L² minimizer.** For positive weights on a
nonempty bin, the `c`-weighted mean minimizes `∑ c_x (L_x − m)²` over all `m`. -/
theorem wMean_minimizes (B : Finset ℕ) (c L : ℕ → ℝ) (hB : B.Nonempty)
    (hc : ∀ x ∈ B, 0 < c x) (m : ℝ) :
    ∑ x ∈ B, c x * (L x - wMean B c L) ^ 2 ≤ ∑ x ∈ B, c x * (L x - m) ^ 2 := by
  have hS : 0 < ∑ x ∈ B, c x := Finset.sum_pos hc hB
  have hμ : (∑ x ∈ B, c x) * wMean B c L = ∑ x ∈ B, c x * L x := by
    rw [wMean, mul_div_assoc']
    field_simp
  have expand : ∀ t : ℝ, ∑ x ∈ B, c x * (L x - t) ^ 2
      = (∑ x ∈ B, c x * (L x) ^ 2) - 2 * t * (∑ x ∈ B, c x * L x)
        + t ^ 2 * ∑ x ∈ B, c x := by
    intro t
    have hpt : ∀ x : ℕ, c x * (L x - t) ^ 2
        = c x * (L x) ^ 2 - 2 * t * (c x * L x) + t ^ 2 * c x := by
      intro x; ring
    simp_rw [hpt]
    rw [Finset.sum_add_distrib, Finset.sum_sub_distrib, ← Finset.mul_sum, ← Finset.mul_sum]
  rw [expand (wMean B c L), expand m, ← hμ]
  nlinarith [mul_nonneg hS.le (sq_nonneg (wMean B c L - m))]

/-- The log-contract LIQUIDITY profile `K^{−1/2}` sampled on the price grid, normalized
over `ι` rungs (the liquidity layer of `logContractLiquidity_geometric`). -/
noncomputable def logLiqWeight (Δi : ℝ) (ι : ℕ) (i : ℕ) : ℝ :=
  (priceGrid Δi i) ^ (-(1 / 2 : ℝ)) / ∑ j ∈ range ι, (priceGrid Δi j) ^ (-(1 / 2 : ℝ))

/-- The liquidity base `ξ* = λ^{−Δi/2}`. -/
noncomputable def xiStar (Δi : ℝ) : ℝ := (1.0001 : ℝ) ^ (-(Δi / 2))

/-- `ξ*` is positive. -/
private lemma xiStar_pos (Δi : ℝ) : 0 < xiStar Δi :=
  Real.rpow_pos_of_pos (by norm_num) _

/-- For a positive tick spacing, `ξ* < 1`, in particular `ξ* ≠ 1`. -/
private lemma xiStar_lt_one (Δi : ℝ) (hΔi : 0 < Δi) : xiStar Δi < 1 :=
  Real.rpow_lt_one_of_one_lt_of_neg (by norm_num) (by linarith)

private lemma xiStar_ne_one (Δi : ℝ) (hΔi : 0 < Δi) : xiStar Δi ≠ 1 :=
  ne_of_lt (xiStar_lt_one Δi hΔi)

/-- Finite-sum L² distance between the geometric profile at base `ξ` and the sampled
log-contract liquidity profile. -/
noncomputable def l2dist (Δi ξ : ℝ) (ι : ℕ) : ℝ :=
  ∑ i ∈ range ι, (geomWeight ξ ι i - logLiqWeight Δi ι i) ^ 2

/-- **A2a — the sampled liquidity profile IS the geometric profile at `ξ*`.** -/
theorem logLiqWeight_eq_geom (Δi : ℝ) (hΔi : 0 < Δi) (ι : ℕ) (hι : 0 < ι) (i : ℕ) :
    logLiqWeight Δi ι i = geomWeight (xiStar Δi) ι i := by
  have hξ0 : 0 < xiStar Δi := xiStar_pos Δi
  have hξ1 : xiStar Δi ≠ 1 := xiStar_ne_one Δi hΔi
  have hne : (1 : ℝ) - xiStar Δi ≠ 0 := fun h => hξ1 (by linarith)
  have hpι : (1 : ℝ) - xiStar Δi ^ ι ≠ 0 := fun h =>
    pow_ne_one_aux _ ι hξ0 hξ1 hι (by linarith)
  have hgrid : ∀ j : ℕ, (priceGrid Δi j) ^ (-(1 / 2 : ℝ)) = (xiStar Δi) ^ j := by
    intro j
    rw [xiStar]
    exact logContractLiquidity_geometric Δi j
  have hden : (xiStar Δi ^ ι - 1) / (xiStar Δi - 1)
      = (1 - xiStar Δi ^ ι) / (1 - xiStar Δi) := by
    rw [← neg_div_neg_eq]; ring_nf
  rw [logLiqWeight, geomWeight]
  simp_rw [hgrid]
  rw [geom_sum_eq hξ1, hden, div_div_eq_mul_div]

/-- **A2b — `ξ*` is the L²-argmin over the geometric family, uniquely for `ι ≥ 2`.**
The distance at `ξ*` is a lower bound for every admissible base, and it vanishes only
at `ξ*` (the rung ratio `w₁/w₀ = ξ` identifies the base). -/
theorem xiStar_argmin (Δi : ℝ) (hΔi : 0 < Δi) (ι : ℕ) (hι : 2 ≤ ι) (ξ : ℝ)
    (hξ0 : 0 < ξ) (hξ1 : ξ ≠ 1) :
    l2dist Δi (xiStar Δi) ι ≤ l2dist Δi ξ ι ∧ (l2dist Δi ξ ι = 0 ↔ ξ = xiStar Δi) := by
  have hι0 : 0 < ι := by omega
  have hzero : l2dist Δi (xiStar Δi) ι = 0 := by
    refine Finset.sum_eq_zero fun i _ => ?_
    rw [logLiqWeight_eq_geom Δi hΔi ι hι0 i]
    ring
  have hnn : ∀ ξ' : ℝ, 0 ≤ l2dist Δi ξ' ι :=
    fun ξ' => Finset.sum_nonneg fun i _ => sq_nonneg _
  refine ⟨by rw [hzero]; exact hnn ξ, ?_, ?_⟩
  · intro hz
    have hterm : ∀ i ∈ range ι, (geomWeight ξ ι i - logLiqWeight Δi ι i) ^ 2 = 0 := by
      have := (Finset.sum_eq_zero_iff_of_nonneg
        (fun i (_ : i ∈ range ι) => sq_nonneg (geomWeight ξ ι i - logLiqWeight Δi ι i))).mp hz
      exact this
    have e0 : geomWeight ξ ι 0 = geomWeight (xiStar Δi) ι 0 := by
      have := hterm 0 (Finset.mem_range.mpr (by omega))
      rw [logLiqWeight_eq_geom Δi hΔi ι hι0 0] at this
      have := pow_eq_zero_iff (n := 2) (by norm_num) |>.mp this
      linarith
    have e1 : geomWeight ξ ι 1 = geomWeight (xiStar Δi) ι 1 := by
      have := hterm 1 (Finset.mem_range.mpr (by omega))
      rw [logLiqWeight_eq_geom Δi hΔi ι hι0 1] at this
      have := pow_eq_zero_iff (n := 2) (by norm_num) |>.mp this
      linarith
    have hpos0 : 0 < geomWeight ξ ι 0 := geomWeight_pos ξ ι 0 hξ0 hξ1 hι0
    have rξ : geomWeight ξ ι 1 = ξ * geomWeight ξ ι 0 := by
      rw [geomWeight, geomWeight]; ring
    have rstar : geomWeight (xiStar Δi) ι 1 = xiStar Δi * geomWeight (xiStar Δi) ι 0 := by
      rw [geomWeight, geomWeight]; ring
    rw [rξ, rstar, ← e0] at e1
    exact mul_right_cancel₀ hpos0.ne' e1
  · rintro rfl
    exact hzero

end GeomMixture
