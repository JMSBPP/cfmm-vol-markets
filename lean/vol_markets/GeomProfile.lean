import Mathlib
import vol_markets.Flow

open scoped BigOperators Topology

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Geometric liquidity profile (GDF) module

Formalizes the geometric distribution function (GDF) liquidity profile from
`tbd2.md`:

  `L(i) = L̄ · ξ^i / ((1 - ξ^ι)/(1 - ξ))`,  `ξ ∈ ℝ₊ \ {1}`, `ι : ℕ` ticks,

and its connection to the tick-grid discretization of the variance-swap
(log-contract) static-replication weighting `dK / K²`.

Main claims (statements only; proofs are for Aristotle):

* `geomWeight_sum` — the geometric weights are a partition of unity;
* `geomWeight_pos` — positivity on both branches `ξ ∈ (0,1)` and `ξ > 1`;
* `geomWeight_strictAnti` — monotone concentration for `ξ ∈ (0,1)`;
* `geomWeight_tendsto_uniform` — the `ξ → 1` limit recovers the uniform
  profile `1/ι`;
* `varswapWeight_geometric`, `varswapWeight_normalized` — on the price grid
  `K_i = 1.0001^(i·Δi)`, the discretized Carr–Madan *strike-notional* weights
  `(K_{i+1} - K_i)/K_i²` of the log contract are exactly geometric with
  ratio `1.0001^(-Δi)`, and normalize to `geomWeight (1.0001^(-Δi)) ι`.
  These are option notionals per strike, NOT per-tick v3 liquidity;
* `logContractLiquidity_geometric` — the Uniswap-v3 *liquidity* profile
  replicating the log contract, `ℓ(K) ∝ K^(-1/2)` (from the curvature
  relation `ℓ(P) = -2·P^(3/2)·V''(P)` with `V''(P) = -1/P²`), sampled on the
  price grid is geometric with ratio `ξ* = 1.0001^(-Δi/2)`.  This — not
  `1.0001^(-Δi)` — is the GDF ratio that positions the profile as a
  variance-swap-style instrument; the payoff-level curvature bridge itself
  is future work, not part of this module;
* `priceGrid_eq_tickPrice_sq` — convention bridge: `priceGrid` is the
  *price* grid, the square of the sqrt-price grid `PosSpec.tickPrice` used
  by `Flow`/`pos_spec.md`.

Cross-reference: the EVM-facing conventions (X96 prices, `uint128`
liquidity) live in `Flow.lean` / `pos_spec.md`; this module states no EVM
claims itself.
-/

namespace GeomProfile

/-! ## 1. Geometric weights -/

/-- Geometric weight `w_i = ξ^i · (1 - ξ) / (1 - ξ^ι)` over `ι` ticks. -/
noncomputable def geomWeight (ξ : ℝ) (ι : ℕ) (i : ℕ) : ℝ :=
  ξ ^ i * (1 - ξ) / (1 - ξ ^ ι)

/-- Geometric liquidity profile `L(i) = L̄ · w_i`. -/
noncomputable def geomLiquidity (Lbar ξ : ℝ) (ι : ℕ) (i : ℕ) : ℝ :=
  Lbar * geomWeight ξ ι i

/-
**Partition of unity.**  For `0 < ξ`, `ξ ≠ 1` and at least one tick, the
geometric weights sum to `1` over `Finset.range ι`.
-/
lemma geomWeight_sum (ξ : ℝ) (ι : ℕ) (hξ0 : 0 < ξ) (hξ1 : ξ ≠ 1)
    (hι : 0 < ι) :
    ∑ i ∈ Finset.range ι, geomWeight ξ ι i = 1 := by
  simp_rw [geomWeight]
  -- Factor out (1 - ξ) / (1 - ξ ^ ι) from the sum
  have h : ∑ i ∈ Finset.range ι, ξ ^ i * (1 - ξ) / (1 - ξ ^ ι)
         = (1 - ξ) / (1 - ξ ^ ι) * ∑ i ∈ Finset.range ι, ξ ^ i := by
    simp_rw [mul_comm (ξ ^ _)]
    simp_rw [mul_div_assoc]
    rw [Finset.mul_sum]
    congr 1
    ext i
    ring
  rw [h]
  rw [geom_sum_eq hξ1]
  have h1 : (ξ ^ ι - 1) / (ξ - 1) = (1 - ξ ^ ι) / (1 - ξ) := by
    rw [← neg_div_neg_eq]
    ring
  rw [h1]
  rw [div_mul_div_comm, mul_comm (1 - ξ) (1 - ξ ^ ι)]
  apply div_self
  apply mul_ne_zero
  · intro heq
    have heq' : ξ ^ ι = 1 := by linarith
    rcases Nat.eq_zero_or_pos ι with rfl | hι'
    · exact absurd rfl hι.ne'
    · exfalso
      rw [pow_eq_one_iff_of_ne_zero hι'.ne'] at heq'
      rcases heq' with rfl | ⟨rfl, _⟩
      · exact hξ1 rfl
      · linarith
  · intro heq
    exact hξ1 (by linarith : ξ = 1)

/-
**Total liquidity.**  The geometric profile allocates exactly `L̄` in total.
-/
lemma geomLiquidity_sum (Lbar ξ : ℝ) (ι : ℕ) (hξ0 : 0 < ξ) (hξ1 : ξ ≠ 1)
    (hι : 0 < ι) :
    ∑ i ∈ Finset.range ι, geomLiquidity Lbar ξ ι i = Lbar := by
  simp_rw [geomLiquidity, ← Finset.mul_sum]
  rw [geomWeight_sum ξ ι hξ0 hξ1 hι, mul_one]

/-
**Positivity.**  Every geometric weight is strictly positive for `0 < ξ`,
`ξ ≠ 1`, `0 < ι` (both branches `ξ < 1` and `ξ > 1`: numerator and
denominator share their sign).
-/
lemma geomWeight_pos (ξ : ℝ) (ι : ℕ) (i : ℕ) (hξ0 : 0 < ξ) (hξ1 : ξ ≠ 1)
    (hι : 0 < ι) :
    0 < geomWeight ξ ι i := by
  unfold geomWeight
  by_cases hξlt : ξ < 1
  · have hξι : ξ ^ ι < 1 := pow_lt_one₀ hξ0.le hξlt (by omega : ι ≠ 0)
    apply div_pos
    · exact mul_pos (pow_pos hξ0 i) (sub_pos.mpr hξlt)
    · linarith
  · push_neg at hξlt
    have hξgt : ξ > 1 := lt_of_le_of_ne' hξlt hξ1
    have hξι : ξ ^ ι > 1 := one_lt_pow₀ hξgt (by omega : ι ≠ 0)
    rw [← neg_div_neg_eq]
    apply div_pos
    · have : -(ξ ^ i * (1 - ξ)) = ξ ^ i * (ξ - 1) := by ring
      rw [this]
      exact mul_pos (pow_pos hξ0 i) (sub_pos.mpr hξgt)
    · linarith

/-
**Monotone concentration.**  For `ξ ∈ (0,1)` the weights are strictly
decreasing in the tick index: liquidity concentrates toward tick `0`.
-/
lemma geomWeight_strictAnti (ξ : ℝ) (ι : ℕ) (hξ0 : 0 < ξ) (hξlt : ξ < 1)
    (hι : 0 < ι) :
    StrictAnti (geomWeight ξ ι) := by
  unfold StrictAnti
  intro i j hij
  unfold geomWeight
  have hden_pos : 0 < 1 - ξ ^ ι := by
    have hξι : ξ ^ ι < 1 := pow_lt_one₀ hξ0.le hξlt (by omega : ι ≠ 0)
    linarith
  have hnum_pos : 0 < 1 - ξ := by linarith
  have hξij : ξ ^ j < ξ ^ i := by
    apply pow_lt_pow_right_of_lt_one₀ hξ0 hξlt
    exact hij
  calc ξ ^ j * (1 - ξ) / (1 - ξ ^ ι)
      < ξ ^ i * (1 - ξ) / (1 - ξ ^ ι) := by
        apply div_lt_div_of_pos_right _ hden_pos
        gcongr

/-
**Uniform limit.**  As `ξ → 1` (from either side), each weight tends to the
uniform allocation `1/ι`.
-/
lemma geomWeight_tendsto_uniform (ι : ℕ) (i : ℕ) (hι : 0 < ι) :
    Filter.Tendsto (fun ξ : ℝ => geomWeight ξ ι i)
      (𝓝[≠] (1 : ℝ)) (𝓝 (1 / (ι : ℝ))) := by
  unfold geomWeight
  -- Rewrite using geometric series: (1 - ξ^ι) = (1 - ξ) * (∑ j in range ι, ξ^j)
  suffices h : Filter.Tendsto (fun ξ : ℝ => ξ ^ i / ∑ j ∈ Finset.range ι, ξ ^ j)
      (𝓝[≠] (1 : ℝ)) (𝓝 (1 / (ι : ℝ))) by
    refine h.congr' ?_
    filter_upwards [self_mem_nhdsWithin, mem_nhdsWithin_of_mem_nhds (Ioi_mem_nhds (by norm_num : (0:ℝ) < 1))] with ξ hξ hξpos
    have hξ' : ξ ≠ 1 := hξ
    have hξpos' : 0 < ξ := hξpos
    have hsum : (∑ j ∈ Finset.range ι, ξ ^ j) = (ξ ^ ι - 1) / (ξ - 1) := by
      rw [geom_sum_eq hξ']
    rw [hsum, div_div_eq_mul_div]
    have hξι : ξ ^ ι ≠ 1 := by
      have := pow_eq_one_iff_of_nonneg (le_of_lt hξpos') (by omega : ι ≠ 0)
      simp_all
    have heq : (ξ - 1) / (ξ ^ ι - 1) = (1 - ξ) / (1 - ξ ^ ι) := by
      rw [show (ξ : ℝ) - 1 = - (1 - ξ) by ring, show (ξ : ℝ) ^ ι - 1 = - (1 - ξ ^ ι) by ring, neg_div_neg_eq]
    rw [mul_div_assoc, heq, mul_div_assoc]
  -- Numerator tends to 1^i = 1
  have hnum : Filter.Tendsto (fun ξ : ℝ => ξ ^ i) (𝓝[≠] (1 : ℝ)) (𝓝 (1 : ℝ)) := by
    have := Filter.Tendsto.pow (Filter.tendsto_id.mono_left inf_le_left : Filter.Tendsto (fun ξ : ℝ => ξ) (𝓝[≠] (1 : ℝ)) (𝓝 (1 : ℝ))) i
    simp at this
    exact this
  -- Denominator tends to ι
  have hden : Filter.Tendsto (fun ξ : ℝ => ∑ j ∈ Finset.range ι, ξ ^ j) (𝓝[≠] (1 : ℝ)) (𝓝 ι) := by
    have hpow : ∀ j : ℕ, Filter.Tendsto (fun ξ : ℝ => ξ ^ j) (𝓝[≠] (1 : ℝ)) (𝓝 1) := by
      intro j
      have := Filter.Tendsto.pow (Filter.tendsto_id.mono_left inf_le_left : Filter.Tendsto (fun ξ : ℝ => ξ) (𝓝[≠] (1 : ℝ)) (𝓝 (1 : ℝ))) j
      simp at this
      exact this
    convert tendsto_finset_sum _ fun j _ => hpow j using 1
    simp
  -- Combine: 1 / ι
  have hpos : (ι : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hι.ne'
  exact Filter.Tendsto.div hnum hden hpos

/-! ## 2. Tick-grid log-contract weights

The Carr–Madan static replication of the log contract weights each strike
`K` by the option *notional* `dK / K²`.  On the price grid
`K_i = 1.0001^(i·Δi)` the discretized strike weight of tick `i` is
`(K_{i+1} - K_i) / K_i²`, exactly geometric with ratio `1.0001^(-Δi)`.

Separately, the Uniswap-v3 per-tick *liquidity* replicating the log
contract is `ℓ(K) ∝ K^(-1/2)` (curvature relation
`ℓ(P) = -2·P^(3/2)·V''(P)` applied to `V''(P) = -1/P²`), which sampled on
the same grid is geometric with ratio `ξ* = 1.0001^(-Δi/2)`.  The two ratios
differ by the tranche-gamma Jacobian; do not conflate them.
-/

/-- Price grid `K_i = 1.0001^(i·Δi)` (real-exponent power).  NOTE the
convention change: this is the *price* grid, the square of the sqrt-price
grid `PosSpec.tickPrice` used by `Flow` (`priceGrid_eq_tickPrice_sq`). -/
noncomputable def priceGrid (Δi : ℝ) (i : ℕ) : ℝ :=
  (1.0001 : ℝ) ^ ((i : ℝ) * Δi)

/-
**Convention bridge.**  `priceGrid Δi i = (PosSpec.tickPrice Δi i)²`: the
price grid is the square of the sqrt-price grid of `pos_spec.md`.
-/
lemma priceGrid_eq_tickPrice_sq (Δi : ℝ) (i : ℕ) :
    priceGrid Δi i = (PosSpec.tickPrice Δi (i : ℝ)) ^ 2 := by
  unfold priceGrid PosSpec.tickPrice PosSpec.lam
  rw [← Real.rpow_natCast, ← Real.rpow_mul (by norm_num : (0 : ℝ) ≤ 1.0001)]
  ring_nf

/-- Discretized variance-swap weight of tick `i`: `(K_{i+1} - K_i)/K_i²`. -/
noncomputable def varswapWeight (Δi : ℝ) (i : ℕ) : ℝ :=
  (priceGrid Δi (i + 1) - priceGrid Δi i) / (priceGrid Δi i) ^ 2

/-
**Exact geometricity of the strike weights.**  The discretized Carr–Madan
strike-notional weights satisfy
`w_i^varswap = (1.0001^Δi - 1) · (1.0001^(-Δi))^i` — a geometric sequence in
`i` with ratio `1.0001^(-Δi)`.  (Strike notionals, not v3 liquidity; see
`logContractLiquidity_geometric` for the liquidity-profile ratio.)
-/
lemma varswapWeight_geometric (Δi : ℝ) (i : ℕ) :
    varswapWeight Δi i
      = ((1.0001 : ℝ) ^ Δi - 1) * ((1.0001 : ℝ) ^ (-Δi)) ^ i := by
  simp [varswapWeight, priceGrid]
  rw [show ((i : ℝ) + 1) * Δi = (i : ℝ) * Δi + Δi by ring]
  rw [Real.rpow_add (by norm_num : (1.0001 : ℝ) > 0)]
  have hpos : (0 : ℝ) < (1.0001 : ℝ) ^ ((i : ℝ) * Δi) := Real.rpow_pos_of_pos (by norm_num) _
  have hrewrite : ((1.0001 : ℝ) ^ (-Δi)) ^ i = (1.0001 : ℝ) ^ (-Δi * (i : ℝ)) := by
    rw [← Real.rpow_natCast]
    rw [← Real.rpow_mul (by norm_num : (0 : ℝ) ≤ 1.0001)]
  rw [hrewrite]
  field_simp
  rw [Real.rpow_neg (by norm_num : (0 : ℝ) ≤ 1.0001)]
  field_simp [hpos.ne']

/-
**Normalization identification (strike weights).**  For `Δi > 0`, the
normalized strike-notional weights over `ι` ticks coincide with the GDF
weights at ratio `1.0001^(-Δi)`.  This identifies the GDF family with the
discretized `dK/K²` strike density — the option-notional layer of the
replication, not the per-tick liquidity layer.
-/
lemma varswapWeight_normalized (Δi : ℝ) (hΔi : 0 < Δi) (ι : ℕ) (hι : 0 < ι)
    (i : ℕ) :
    varswapWeight Δi i / (∑ j ∈ Finset.range ι, varswapWeight Δi j)
      = geomWeight ((1.0001 : ℝ) ^ (-Δi)) ι i := by
  -- Let ξ = 1.0001 ^ (-Δi)
  set ξ := (1.0001 : ℝ) ^ (-Δi) with hξ_def
  -- Rewrite varswapWeight using varswapWeight_geometric
  simp [varswapWeight_geometric]
  -- Rewrite geomWeight
  rw [geomWeight]
  -- ξ = 1.0001 ^ (-Δi) is positive and not equal to 1
  have hξ0 : 0 < ξ := by positivity
  have hξ1 : ξ ≠ 1 := by
    simp [hξ_def]
    rw [Real.rpow_def_of_pos] <;> norm_num
    linarith
  -- 1.0001 ^ Δi - 1 ≠ 0
  have hfact : (1.0001 : ℝ) ^ Δi - 1 ≠ 0 := by
    have : (1.0001 : ℝ) ^ Δi > 1 := Real.one_lt_rpow (by norm_num : (1 : ℝ) < 1.0001) (by linarith)
    linarith
  -- Factor out (1.0001 ^ Δi - 1) from the sum
  rw [← Finset.mul_sum]
  -- Use geometric series formula: ∑ j in range ι, ξ^j = (1 - ξ^ι) / (1 - ξ)
  rw [geom_sum_eq hξ1]
  -- (ξ^ι - 1) / (ξ - 1) = (1 - ξ^ι) / (1 - ξ)
  have hgeo : (ξ ^ ι - 1) / (ξ - 1) = (1 - ξ ^ ι) / (1 - ξ) := by
    rw [← neg_div_neg_eq]
    ring
  rw [hgeo]
  -- Cancel (1.0001 ^ Δi - 1) from numerator and denominator
  rw [mul_div_mul_left _ _ hfact]
  -- Now we need: ξ^i / ((1 - ξ^ι) / (1 - ξ)) = ξ^i * (1 - ξ) / (1 - ξ^ι)
  field_simp
  ring

/-
**Log-contract liquidity profile.**  The v3 liquidity density replicating
the log contract, `ℓ(K) = K^(-1/2)` up to a constant, sampled on the price
grid, is geometric with ratio `ξ* = 1.0001^(-(Δi/2))`.  This is the GDF
ratio that positions the profile as a variance-swap-style instrument (the
payoff-level curvature bridge `ℓ(P) = -2·P^(3/2)·V''(P)` is future work).
-/
lemma logContractLiquidity_geometric (Δi : ℝ) (i : ℕ) :
    (priceGrid Δi i) ^ (-(1 / 2 : ℝ))
      = ((1.0001 : ℝ) ^ (-(Δi / 2))) ^ i := by
  unfold priceGrid
  norm_cast
  simp only [← Real.rpow_natCast, ← Real.rpow_mul (by norm_num : (0 : ℝ) ≤ 1.0001)]
  congr 1
  ring

/-! ## 3. Payoff of the geometric profile -/

/-
**Total terminal payoff of the GDF profile.**  Tranche `i` holds liquidity
`L̄·w_i` on the price range `[p_i, p_{i+1}]`; the total terminal payoff is the
`w`-weighted sum of range widths, scaled by `L̄` (cf. `Flow.terminalPayoff`).
-/
lemma geom_terminalPayoff_total (Lbar ξ : ℝ) (ι : ℕ) (p : ℕ → ℝ) :
    ∑ i ∈ Finset.range ι,
        Flow.terminalPayoff (geomLiquidity Lbar ξ ι i) (p i) (p (i + 1))
      = Lbar * ∑ i ∈ Finset.range ι, geomWeight ξ ι i * (p (i + 1) - p i) := by
  simp_rw [Flow.terminalPayoff, geomLiquidity, Finset.mul_sum]
  ring

/-
**Pipeline instantiation.**  The same total payoff with the tranche
boundaries on the `PosSpec.tickPrice` sqrt-price grid — the convention
`Flow.terminalPayoff` expects.  This is the named bridge into the
`Flow`/`SCHEDULE.md` pipeline; use this, not `geom_terminalPayoff_total`
with `p := priceGrid Δi`, which would feed prices where sqrt-prices are
expected.
-/
lemma geom_terminalPayoff_total_tickPrice (Lbar ξ Δi : ℝ) (ι : ℕ) :
    ∑ i ∈ Finset.range ι,
        Flow.terminalPayoff (geomLiquidity Lbar ξ ι i)
          (PosSpec.tickPrice Δi (i : ℝ)) (PosSpec.tickPrice Δi ((i : ℝ) + 1))
      = Lbar * ∑ i ∈ Finset.range ι,
          geomWeight ξ ι i
            * (PosSpec.tickPrice Δi ((i : ℝ) + 1) - PosSpec.tickPrice Δi (i : ℝ)) := by
  simp_rw [Flow.terminalPayoff, geomLiquidity, Finset.mul_sum]
  ring

end GeomProfile
