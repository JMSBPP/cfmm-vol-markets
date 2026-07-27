import Mathlib
import vol_markets.VolInstrument

open scoped BigOperators Topology

set_option maxHeartbeats 4000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Discrete FLAIR hazard and its parameter optimization

This file formalizes the document's FLAIR expression as a finite lattice sum,
consistent with `Panoptic.streamingPremium`.  In `flairHazard`, `w t ≥ 0` is
traded-price-flow weight: the nonnegative-weight interpretation reads `dp` as
traded volume.  `D t > 0` is deployed capital.

The resulting objective has no demand or volume response to the fee.  Thus its
corner solution is a property of the objective as written, not a market-
equilibrium claim.  The volume-response trade-off belongs to the optimal-fees
layer (`FeeSchedule`, arXiv:2508.08152).
-/

namespace FlairOptimization

/-- The discrete FLAIR hazard functional. -/
noncomputable def flairHazard (φfun : ℝ → ℝ) (σpath w D : ℕ → ℝ) (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T, φfun (σpath t) * w t / D t

/-- The FLAIR functional specialized to the project's multi-sigmoid fee. -/
noncomputable def flairMulti (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath w D : ℕ → ℝ) (T : ℕ) : ℝ :=
  flairHazard (VolInstrument.multiFee n γ β α φbar u) σpath w D T

/-- Total path weight. -/
noncomputable def pathWeight (w D : ℕ → ℝ) (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T, w t / D t

/-- Exposure weight of sigmoid component `j`. -/
noncomputable def shapeWeight (γ β : ℕ → ℝ) (j : ℕ)
    (σpath w D : ℕ → ℝ) (T : ℕ) : ℝ :=
  ∑ t ∈ Finset.range T,
    FeeSchedule.logistic (γ j * (σpath t - β j)) * w t / D t

/-- The document's denominator is `QM * (p+1)` and is positive under its
natural capital and nonnegative-price assumptions.  `QM` may in particular be
an instance of `VolInstrument.cumulativeQM`. -/
lemma capitalDenominator_pos (QM : ℝ) (p : ℕ → ℝ)
    (hQM : 0 < QM) (hp : ∀ t, 0 ≤ p t) :
    ∀ t, 0 < QM * (p t + 1) := by
  intro t
  exact mul_pos hQM (by linarith [hp t])

/-- Exact identification: FLAIR is affine in the level coordinates `φbar` and
`α`; `β,γ` occur only in the component weights. -/
theorem flairMulti_affine (n : ℕ) (γ β α : ℕ → ℝ) (φbar u : ℝ)
    (σpath w D : ℕ → ℝ) (T : ℕ) :
    flairMulti n γ β α φbar u σpath w D T =
      φbar * pathWeight w D T +
        u * ∑ j ∈ Finset.range n, α j * shapeWeight γ β j σpath w D T := by
  simp only [flairMulti, flairHazard, VolInstrument.multiFee, pathWeight, shapeWeight]
  simp only [add_mul, mul_div_assoc, mul_assoc]
  rw [Finset.sum_congr rfl fun _ _ => add_div _ _ _, Finset.sum_add_distrib]
  congr 1
  · rw [Finset.mul_sum]
    exact Finset.sum_congr rfl fun _ _ => by ring
  · simp [div_eq_mul_inv, mul_comm, mul_assoc, mul_left_comm]
    rw [← Finset.mul_sum]
    have : ∀ i ∈ Finset.range T,
        w i * ((D i)⁻¹ * ∑ j ∈ Finset.range n, α j * FeeSchedule.logistic (γ j * (σpath i - β j))) =
        ∑ j ∈ Finset.range n, w i * (D i)⁻¹ * α j * FeeSchedule.logistic (γ j * (σpath i - β j)) := by
      intro i _
      rw [mul_comm ((D i)⁻¹), ← mul_assoc, mul_comm (w i), mul_assoc]
      rw [Finset.sum_mul]
      exact Finset.sum_congr rfl fun j _ => by ring
    rw [Finset.sum_congr rfl this]
    rw [Finset.sum_comm]
    simp [mul_comm, mul_left_comm, Finset.mul_sum]

lemma pathWeight_pos (w D : ℕ → ℝ) (T t₀ : ℕ)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t)
    (ht₀ : t₀ < T) (hwt₀ : 0 < w t₀) :
    0 < pathWeight w D T := by
  unfold pathWeight
  apply Finset.sum_pos'
  · intro t ht
    exact div_nonneg (hw t (Finset.mem_range.mp ht)) (le_of_lt (hD t (Finset.mem_range.mp ht)))
  · exact ⟨t₀, Finset.mem_range.mpr ht₀, div_pos hwt₀ (hD t₀ ht₀)⟩

/-- Strict monotonicity in the fee floor whenever the path has positive flow. -/
theorem flairMulti_mono_phibar (n : ℕ) (γ β α : ℕ → ℝ) (u φbar φbar' : ℝ)
    (σpath w D : ℕ → ℝ) (T t₀ : ℕ)
    (hφ : φbar < φbar') (hD : ∀ t < T, 0 < D t)
    (hw : ∀ t < T, 0 ≤ w t) (ht₀ : t₀ < T) (hwt₀ : 0 < w t₀) :
    flairMulti n γ β α φbar u σpath w D T <
      flairMulti n γ β α φbar' u σpath w D T := by
  have hPW : 0 < pathWeight w D T := pathWeight_pos w D T t₀ hD hw ht₀ hwt₀
  rw [flairMulti_affine, flairMulti_affine]
  ring_nf
  nlinarith

/-- Coordinatewise increasing amplitudes weakly increase FLAIR. -/
theorem flairMulti_mono_alpha (n : ℕ) (γ β α α' : ℕ → ℝ) (φbar u : ℝ)
    (σpath w D : ℕ → ℝ) (T : ℕ)
    (hu : 0 ≤ u) (hα : ∀ j < n, α j ≤ α' j)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) :
    flairMulti n γ β α φbar u σpath w D T ≤
      flairMulti n γ β α' φbar u σpath w D T := by
  rw [flairMulti_affine, flairMulti_affine]
  apply add_le_add_right _ (φbar * pathWeight w D T)
  apply mul_le_mul_of_nonneg_left _ hu
  apply Finset.sum_le_sum
  intro j hj
  have hj' := Finset.mem_range.mp hj
  have hαj := hα j hj'
  have hW_nonneg : 0 ≤ shapeWeight γ β j σpath w D T := by
    unfold shapeWeight
    apply Finset.sum_nonneg
    intro t ht
    apply div_nonneg
    apply mul_nonneg
    · exact (FeeSchedule.logistic_mem_Ioo _).1.le
    · exact hw t (Finset.mem_range.mp ht)
    · exact le_of_lt (hD t (Finset.mem_range.mp ht))
  exact mul_le_mul_of_nonneg_right hαj hW_nonneg

/-- Utilization is monotone when amplitudes are nonnegative. -/
theorem flairMulti_mono_u (n : ℕ) (γ β α : ℕ → ℝ) (φbar u u' : ℝ)
    (σpath w D : ℕ → ℝ) (T : ℕ)
    (hu : u ≤ u') (hα : ∀ j < n, 0 ≤ α j)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) :
    flairMulti n γ β α φbar u σpath w D T ≤
      flairMulti n γ β α φbar u' σpath w D T := by
  rw [flairMulti_affine, flairMulti_affine]
  apply add_le_add_right
  apply mul_le_mul_of_nonneg_right hu
  apply Finset.sum_nonneg
  intro j hj
  apply mul_nonneg (hα j (Finset.mem_range.mp hj))
  unfold shapeWeight
  apply Finset.sum_nonneg
  intro t ht
  apply div_nonneg _ (le_of_lt (hD t (Finset.mem_range.mp ht)))
  apply mul_nonneg _ (hw t (Finset.mem_range.mp ht))
  exact le_of_lt (FeeSchedule.logistic_mem_Ioo _ |>.1)

/-- Raising positive-slope sigmoid centers attenuates FLAIR. -/
theorem flairMulti_anti_beta (n : ℕ) (γ β β' α : ℕ → ℝ) (φbar u : ℝ)
    (σpath w D : ℕ → ℝ) (T : ℕ)
    (hβ : ∀ j < n, β j ≤ β' j) (hγ : ∀ j < n, 0 < γ j)
    (hu : 0 ≤ u) (hα : ∀ j < n, 0 ≤ α j)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) :
    flairMulti n γ β' α φbar u σpath w D T ≤
      flairMulti n γ β α φbar u σpath w D T := by
  rw [flairMulti_affine, flairMulti_affine]
  simp only [add_le_add_iff_left]
  apply mul_le_mul_of_nonneg_left _ hu
  apply Finset.sum_le_sum
  intro j hj
  apply mul_le_mul_of_nonneg_left _ (hα j (Finset.mem_range.mp hj))
  unfold shapeWeight
  apply Finset.sum_le_sum
  intro t ht
  apply div_le_div_of_nonneg_right _ (le_of_lt (hD t (Finset.mem_range.mp ht)))
  apply mul_le_mul_of_nonneg_right _ (hw t (Finset.mem_range.mp ht))
  apply FeeSchedule.logistic_strictMono.monotone
  have h1 : β j ≤ β' j := hβ j (Finset.mem_range.mp hj)
  have h2 : σpath t - β' j ≤ σpath t - β j := by linarith
  nlinarith [hγ j (Finset.mem_range.mp hj)]

/-- Every component exposure lies between zero and total path exposure. -/
theorem W_j_le_W (γ β : ℕ → ℝ) (j : ℕ) (σpath w D : ℕ → ℝ) (T : ℕ)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) :
    0 ≤ shapeWeight γ β j σpath w D T ∧
      shapeWeight γ β j σpath w D T ≤ pathWeight w D T := by
  simp only [shapeWeight, pathWeight]
  refine ⟨Finset.sum_nonneg ?_, Finset.sum_le_sum ?_⟩
  · intro t ht
    apply div_nonneg
    · apply mul_nonneg _ (hw t (Finset.mem_range.mp ht))
      exact le_of_lt (FeeSchedule.logistic_mem_Ioo _).1
    · exact le_of_lt (hD t (Finset.mem_range.mp ht))
  · intro t ht
    have hlt : t < T := Finset.mem_range.mp ht
    have hpos : 0 < D t := hD t hlt
    have hwd : 0 ≤ w t / D t := div_nonneg (hw t hlt) (le_of_lt hpos)
    have hlog : FeeSchedule.logistic (γ j * (σpath t - β j)) ≤ 1 :=
      (FeeSchedule.logistic_mem_Ioo _).2.le
    calc FeeSchedule.logistic (γ j * (σpath t - β j)) * w t / D t
        = (FeeSchedule.logistic (γ j * (σpath t - β j))) * (w t / D t) := by ring
      _ ≤ 1 * (w t / D t) := by gcongr
      _ = w t / D t := by ring

/-- With positive flow at some step, finite logistic exposure is strictly below
saturation. -/
theorem W_j_lt_W (γ β : ℕ → ℝ) (j : ℕ) (σpath w D : ℕ → ℝ) (T t₀ : ℕ)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t)
    (ht₀ : t₀ < T) (hwt₀ : 0 < w t₀) :
    shapeWeight γ β j σpath w D T < pathWeight w D T := by
  unfold shapeWeight pathWeight
  apply Finset.sum_lt_sum
  · intro t ht
    have hlt : t < T := Finset.mem_range.mp ht
    have hpos : 0 < D t := hD t hlt
    have hwd : 0 ≤ w t / D t := div_nonneg (hw t hlt) (le_of_lt hpos)
    have hlog : FeeSchedule.logistic (γ j * (σpath t - β j)) ≤ 1 :=
      (FeeSchedule.logistic_mem_Ioo _).2.le
    calc FeeSchedule.logistic (γ j * (σpath t - β j)) * w t / D t
        = (FeeSchedule.logistic (γ j * (σpath t - β j))) * (w t / D t) := by ring
      _ ≤ 1 * (w t / D t) := by gcongr
      _ = w t / D t := by ring
  · use t₀, Finset.mem_range.mpr ht₀
    have hD_t₀ : 0 < D t₀ := hD t₀ ht₀
    have hwd_pos : 0 < w t₀ / D t₀ := div_pos hwt₀ hD_t₀
    have hlog : FeeSchedule.logistic (γ j * (σpath t₀ - β j)) < 1 :=
      (FeeSchedule.logistic_mem_Ioo _).2
    calc FeeSchedule.logistic (γ j * (σpath t₀ - β j)) * w t₀ / D t₀
        = (FeeSchedule.logistic (γ j * (σpath t₀ - β j))) * (w t₀ / D t₀) := by ring
      _ < 1 * (w t₀ / D t₀) := by gcongr
      _ = w t₀ / D t₀ := by ring

/-- Uniform solution bound: no shape choice beats full sigmoid saturation. -/
theorem flairMulti_le_corner (n : ℕ) (γ β α αmax : ℕ → ℝ)
    (φbar φbarMax u uMax : ℝ) (σpath w D : ℕ → ℝ) (T : ℕ)
    (hφ : φbar ≤ φbarMax) (hu0 : 0 ≤ u) (hu : u ≤ uMax)
    (hα0 : ∀ j < n, 0 ≤ α j) (hα : ∀ j < n, α j ≤ αmax j)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) :
    flairMulti n γ β α φbar u σpath w D T ≤
      (φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j) * pathWeight w D T := by
  -- Expand using flairMulti_affine
  rw [flairMulti_affine]
  -- pathWeight is nonnegative
  have hPW_nonneg : 0 ≤ pathWeight w D T := by
    unfold pathWeight
    apply Finset.sum_nonneg
    intro t ht
    exact div_nonneg (hw t (Finset.mem_range.mp ht)) (le_of_lt (hD t (Finset.mem_range.mp ht)))
  -- First term: φbar * pathWeight ≤ φbarMax * pathWeight
  have h1 : φbar * pathWeight w D T ≤ φbarMax * pathWeight w D T := by
    apply mul_le_mul_of_nonneg_right hφ hPW_nonneg
  -- For each j, α j * shapeWeight ≤ αmax j * pathWeight
  have h2 : ∀ j ∈ Finset.range n, α j * shapeWeight γ β j σpath w D T ≤ αmax j * pathWeight w D T := by
    intro j hj
    have hαj := hα j (Finset.mem_range.mp hj)
    have hWj := (W_j_le_W γ β j σpath w D T hD hw).2
    have hα0j := hα0 j (Finset.mem_range.mp hj)
    have hWj_nonneg := (W_j_le_W γ β j σpath w D T hD hw).1
    calc α j * shapeWeight γ β j σpath w D T
        ≤ α j * pathWeight w D T := by
          apply mul_le_mul_of_nonneg_left hWj hα0j
      _ ≤ αmax j * pathWeight w D T := by
          apply mul_le_mul_of_nonneg_right hαj hPW_nonneg
  -- Sum over j
  have h3 : ∑ j ∈ Finset.range n, α j * shapeWeight γ β j σpath w D T ≤
            (∑ j ∈ Finset.range n, αmax j) * pathWeight w D T := by
    rw [Finset.sum_mul]
    exact Finset.sum_le_sum h2
  -- Multiply by u
  have h4 : u * ∑ j ∈ Finset.range n, α j * shapeWeight γ β j σpath w D T ≤
            u * ((∑ j ∈ Finset.range n, αmax j) * pathWeight w D T) := by
    apply mul_le_mul_of_nonneg_left h3 hu0
  -- Show αmax j ≥ 0
  have hαmax_nonneg : ∀ j ∈ Finset.range n, 0 ≤ αmax j := by
    intro j hj
    exact le_trans (hα0 j (Finset.mem_range.mp hj)) (hα j (Finset.mem_range.mp hj))
  have hSumαmax_nonneg : 0 ≤ ∑ j ∈ Finset.range n, αmax j :=
    Finset.sum_nonneg hαmax_nonneg
  have hRHS_factor_nonneg : 0 ≤ (∑ j ∈ Finset.range n, αmax j) * pathWeight w D T :=
    mul_nonneg hSumαmax_nonneg hPW_nonneg
  -- u ≤ uMax times the nonnegative factor
  have h5 : u * ((∑ j ∈ Finset.range n, αmax j) * pathWeight w D T) ≤
            uMax * ((∑ j ∈ Finset.range n, αmax j) * pathWeight w D T) := by
    apply mul_le_mul_of_nonneg_right hu hRHS_factor_nonneg
  -- Combine h1 and h4, h5
  calc φbar * pathWeight w D T + u * ∑ j ∈ Finset.range n, α j * shapeWeight γ β j σpath w D T
      ≤ φbarMax * pathWeight w D T + u * ((∑ j ∈ Finset.range n, αmax j) * pathWeight w D T) := by
        apply add_le_add h1 h4
    _ ≤ φbarMax * pathWeight w D T + uMax * ((∑ j ∈ Finset.range n, αmax j) * pathWeight w D T) := by
        apply add_le_add_right h5
    _ = (φbarMax + uMax * ∑ j ∈ Finset.range n, αmax j) * pathWeight w D T := by ring

/-- For fixed shape, all admissible level choices are dominated by the upper
corner. -/
theorem flairMulti_corner_attained_levels (n : ℕ) (γ β α αmax : ℕ → ℝ)
    (φbar φbarMax u uMax : ℝ) (σpath w D : ℕ → ℝ) (T : ℕ)
    (hφ : φbar ≤ φbarMax) (hu0 : 0 ≤ u) (hu : u ≤ uMax)
    (_hα0 : ∀ j < n, 0 ≤ α j) (hαmax0 : ∀ j < n, 0 ≤ αmax j)
    (hα : ∀ j < n, α j ≤ αmax j)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t) :
    flairMulti n γ β α φbar u σpath w D T ≤
      flairMulti n γ β αmax φbarMax uMax σpath w D T := by
  rw [flairMulti_affine, flairMulti_affine]
  apply add_le_add
  · apply mul_le_mul_of_nonneg_right hφ
    unfold pathWeight
    apply Finset.sum_nonneg
    intro t ht
    exact div_nonneg (hw t (Finset.mem_range.mp ht)) (le_of_lt (hD t (Finset.mem_range.mp ht)))
  · apply le_trans _ (mul_le_mul_of_nonneg_right hu _)
    apply mul_le_mul_of_nonneg_left _ hu0
    apply Finset.sum_le_sum
    intro j hj
    apply mul_le_mul_of_nonneg_right (hα j (Finset.mem_range.mp hj))
    exact W_j_le_W γ β j σpath w D T hD hw |>.1
    apply Finset.sum_nonneg
    intro j hj
    apply mul_nonneg (hαmax0 j (Finset.mem_range.mp hj))
    exact W_j_le_W γ β j σpath w D T hD hw |>.1

/-- For one sigmoid, moving its center to `-∞` reaches saturation in the
limit.  The corresponding componentwise statement for finite `n` follows by
the same finite-sum argument. -/
theorem flairMulti_saturation_limit (γ0 φbarMax uMax αmax0 : ℝ)
    (σpath w D : ℕ → ℝ) (T : ℕ) (hγ : 0 < γ0) :
    Filter.Tendsto
      (fun β0 => flairMulti 1 (fun _ => γ0) (fun _ => β0)
        (fun _ => αmax0) φbarMax uMax σpath w D T)
      Filter.atBot
      (𝓝 ((φbarMax + uMax * αmax0) * pathWeight w D T)) := by
  have haffine : ∀ β0 : ℝ, flairMulti 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0) φbarMax uMax σpath w D T =
      φbarMax * pathWeight w D T + uMax * (αmax0 * shapeWeight (fun _ => γ0) (fun _ => β0) 0 σpath w D T) := by
    intro β0
    rw [flairMulti_affine]
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  simp_rw [haffine]
  -- Need: φbarMax * pathWeight + uMax * (αmax0 * shapeWeight ...) → (φbarMax + uMax * αmax0) * pathWeight
  -- I.e., shapeWeight → pathWeight as β0 → -∞
  unfold shapeWeight pathWeight
  -- The constant part φbarMax * pathWeight is easy
  -- Need: uMax * (αmax0 * ∑ logistic(γ0 * (σpath t - β0)) * w t / D t) → uMax * αmax0 * pathWeight
  simp only [add_mul, mul_assoc]
  -- Use Tendsto.add for the constant part + variable part
  apply Filter.Tendsto.add
  · exact tendsto_const_nhds
  · -- Pull out constants uMax and αmax0
    apply Filter.Tendsto.const_mul
    apply Filter.Tendsto.const_mul
    -- Use finset_sum for the sum
    exact tendsto_finset_sum _ fun i _ => by
      -- logistic(γ0 * (σpath i - k)) → 1 as k → -∞
      have h1 : Filter.Tendsto (fun k => σpath i - k) Filter.atBot Filter.atTop := by
        rw [Filter.tendsto_atTop]
        intro b
        rw [Filter.eventually_atBot]
        use σpath i - b
        intro k hk
        linarith
      have h2 : Filter.Tendsto (fun k => γ0 * (σpath i - k)) Filter.atBot Filter.atTop := by
        exact Filter.Tendsto.const_mul_atTop hγ h1
      have h3 : Filter.Tendsto (fun k => FeeSchedule.logistic (γ0 * (σpath i - k))) Filter.atBot (𝓝 1) := by
        exact FeeSchedule.logistic_tendsto_atTop.comp h2
      have h4 : Filter.Tendsto (fun k => FeeSchedule.logistic (γ0 * (σpath i - k)) * w i / D i) Filter.atBot (𝓝 (1 * w i / D i)) := by
        by_cases hDi : D i = 0
        · simp [hDi]
        · exact h3.mul tendsto_const_nhds |>.div tendsto_const_nhds hDi
      simp at h4
      exact h4

/-- At every finite center the one-sigmoid saturation bound is strict, provided
the active level coefficient and some path flow are strictly positive.  These
extra assumptions are mathematically necessary (the claim is false if `u=0`
or `α=0`). -/
theorem flairMulti_strict_below_saturation (γ0 β0 φbarMax uMax αmax0 : ℝ)
    (σpath w D : ℕ → ℝ) (T t₀ : ℕ) (hu : 0 < uMax) (hα : 0 < αmax0)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t)
    (ht₀ : t₀ < T) (hwt₀ : 0 < w t₀) :
    flairMulti 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0)
        φbarMax uMax σpath w D T <
      (φbarMax + uMax * αmax0) * pathWeight w D T := by
  rw [flairMulti_affine]
  have hWj_lt_W := W_j_lt_W (fun _ => γ0) (fun _ => β0) 0 σpath w D T t₀ hD hw ht₀ hwt₀
  simp only [Finset.sum_range_succ, Finset.sum_range_zero]
  have hUA : 0 < uMax * αmax0 := mul_pos hu hα
  nlinarith [pathWeight_pos w D T t₀ hD hw ht₀ hwt₀]

/-- Compact maximizer interface for the one-sigmoid parameter block
`(φbar, α, β, γ)` (with `u` fixed).  In particular compact center and slope
ranges restore attainment.  This directly reuses
`FeeSchedule.exists_optimal_params`. -/
theorem flairMulti_exists_max_compact
    (Θ : Set (ℝ × ℝ × ℝ × ℝ)) (hΘ : IsCompact Θ) (hne : Θ.Nonempty)
    (u : ℝ) (σpath w D : ℕ → ℝ) (T : ℕ) :
    ∃ θ ∈ Θ, ∀ θ' ∈ Θ,
      flairMulti 1 (fun _ => θ'.2.2.2) (fun _ => θ'.2.2.1) (fun _ => θ'.2.1)
          θ'.1 u σpath w D T ≤
      flairMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1)
          θ.1 u σpath w D T := by
  set f : ℝ × ℝ × ℝ × ℝ → ℝ := fun θ =>
      flairMulti 1 (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) (fun _ => θ.2.1) θ.1 u σpath w D T
  have hcont : Continuous f := by
    have : f = fun θ =>
        θ.1 * pathWeight w D T +
          u * (θ.2.1 * shapeWeight (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) 0 σpath w D T) := by
      ext θ
      simp [f, flairMulti_affine]
    rw [this]
    apply Continuous.add
    · exact continuous_fst.mul continuous_const
    · apply Continuous.mul continuous_const
      apply Continuous.mul continuous_snd.fst
      -- Need: shapeWeight (fun _ => θ.2.2.2) (fun _ => θ.2.2.1) 0 σpath w D T is continuous in θ
      unfold shapeWeight
      apply continuous_finset_sum
      intro t _
      apply Continuous.div_const
      apply Continuous.mul
      · have hlog : Continuous FeeSchedule.logistic := by
          unfold FeeSchedule.logistic
          exact continuous_const.div (by continuity) (by intro x; positivity)
        apply hlog.comp
        simp only
        exact (continuous_snd.snd.snd : Continuous fun x : ℝ × ℝ × ℝ × ℝ => x.2.2.2).mul (continuous_const.sub continuous_snd.snd.fst)
      · exact continuous_const
  obtain ⟨θ₀, hθ₀_mem, hθ₀_max⟩ := hΘ.exists_isMaxOn hne hcont.continuousOn
  exact ⟨θ₀, hθ₀_mem, fun θ' hθ' => hθ₀_max hθ'⟩

/-- Precise form of the document's parameter identification in the one-term
case.  The controlling block is `Θ_λ = {φbar, α, u}`: it is optimized at its
upper corner.  The shape block `{β,γ}` changes finite-center values but cannot
raise the supremum beyond saturation; the bound is approached as `β → -∞`
and, under positive level/flow assumptions, is never attained at finite `β`. -/
theorem Theta_lambda_identification (γ0 φbarMax uMax αmax0 : ℝ)
    (σpath w D : ℕ → ℝ) (T t₀ : ℕ) (hγ : 0 < γ0)
    (hu : 0 < uMax) (hα : 0 < αmax0)
    (hD : ∀ t < T, 0 < D t) (hw : ∀ t < T, 0 ≤ w t)
    (ht₀ : t₀ < T) (hwt₀ : 0 < w t₀) :
    (∀ β0,
      flairMulti 1 (fun _ => γ0) (fun _ => β0) (fun _ => αmax0)
          φbarMax uMax σpath w D T <
        (φbarMax + uMax * αmax0) * pathWeight w D T) ∧
    Filter.Tendsto
      (fun β0 => flairMulti 1 (fun _ => γ0) (fun _ => β0)
        (fun _ => αmax0) φbarMax uMax σpath w D T)
      Filter.atBot
      (𝓝 ((φbarMax + uMax * αmax0) * pathWeight w D T)) := by
  refine ⟨fun β0 => flairMulti_strict_below_saturation γ0 β0 φbarMax uMax αmax0 σpath w D T t₀ hu hα hD hw ht₀ hwt₀,
          flairMulti_saturation_limit γ0 φbarMax uMax αmax0 σpath w D T hγ⟩

end FlairOptimization
