import vol_markets.CanonicalCurve
import vol_markets.PhiCES

open Set Filter
open scoped Topology

set_option autoImplicit false
set_option maxHeartbeats 8000000
set_option maxRecDepth 4000

/-!
# Capponi's canonical family versus the full CES family

The interior witness is `κ = 1/2` with all other parameters equal to one.
The endpoint statements identify the linear endpoint with `ρ = 1` and the
constant-product endpoint with the punctured `ρ → 0` limit.
-/

namespace CapponiEmbed

open CanonicalCurve PhiCES

/-- Symmetry of a guarded CES member forces its weight to be one half. -/
private lemma ces_weight_eq_half_of_symmetric {ρ ε : ℝ} (hρ : ρ ≠ 0)
    (hε : ε ∈ Ioo (0 : ℝ) 1)
    (hsym : ∀ x y : ℝ, 0 < x → 0 < y →
      phiCES ρ ε x y = phiCES ρ ε y x) :
    ε = 1 / 2 := by
  -- Use symmetry with x = 2, y = 1
  have heq := hsym 2 1 (by norm_num : (0 : ℝ) < 2) (by norm_num : (0 : ℝ) < 1)
  -- Unfold the definition of phiCES
  simp only [PhiCES.phiCES] at heq
  -- Both inner expressions are positive
  have hεpos : 0 < ε := hε.1
  have h1mεpos : 0 < 1 - ε := sub_pos.mpr hε.2
  have h2pos : (0 : ℝ) < 2 := by norm_num
  have h1pos : (0 : ℝ) < 1 := by norm_num
  have hinner1 : 0 < ε * 2 ^ ρ + (1 - ε) * 1 ^ ρ := by
    have h2ρ : (0 : ℝ) < 2 ^ ρ := Real.rpow_pos_of_pos h2pos ρ
    simp [Real.one_rpow]
    linarith [mul_pos hεpos h2ρ]
  have hinner2 : 0 < ε * 1 ^ ρ + (1 - ε) * 2 ^ ρ := by
    have h2ρ : (0 : ℝ) < 2 ^ ρ := Real.rpow_pos_of_pos h2pos ρ
    simp [Real.one_rpow]
    linarith [mul_pos h1mεpos h2ρ]
  -- Use injectivity of x^(1/ρ) for positive x
  have hinvρ_ne : 1 / ρ ≠ 0 := by positivity
  have heq_inner : ε * 2 ^ ρ + (1 - ε) * 1 ^ ρ = ε * 1 ^ ρ + (1 - ε) * 2 ^ ρ := by
    have := Real.rpow_left_inj hinner1.le hinner2.le hinvρ_ne
    exact this.mp heq
  -- Simplify using 1^ρ = 1
  simp [Real.one_rpow] at heq_inner
  -- Now heq_inner : ε * 2 ^ ρ + (1 - ε) = ε + (1 - ε) * 2 ^ ρ
  -- Rearranging: 2ε * (2^ρ - 1) = 2^ρ - 1
  have h2ρ_ne_1 : (2 : ℝ) ^ ρ ≠ 1 := by
    rw [show (1 : ℝ) = 2 ^ (0 : ℝ) by norm_num]
    intro h
    exact hρ (Real.rpow_right_inj h2pos (by norm_num : (2 : ℝ) ≠ 1) |>.mp h)
  -- From heq_inner, factor and solve
  have : (2 * ε - 1) * (2 ^ ρ - 1) = 0 := by linarith
  have h2εm1 : 2 * ε - 1 = 0 := mul_eq_zero.mp this |> Or.resolve_right <| sub_ne_zero_of_ne h2ρ_ne_1
  linarith

private noncomputable def capHalfSlice (t : ℝ) : ℝ :=
  ((t + 1) / 2 + Real.sqrt (((t + 1) / 2) ^ 2 + 2 * t)) / 2

private noncomputable def cesHalfSlice (ρ t : ℝ) : ℝ :=
  (((t ^ ρ + 1) / 2) ^ (1 / ρ))

private lemma capHalfSlice_second_deriv :
    iteratedDeriv 2 capHalfSlice 1 = -Real.sqrt 3 / 12 := by
  -- Simplify capHalfSlice: it equals (t + 1 + sqrt(t^2 + 10t + 1)) / 4 near t = 1
  have h_local_eq : ∀ᶠ t in nhds 1, capHalfSlice t = (t + 1 + Real.sqrt (t^2 + 10*t + 1)) / 4 := by
    have h_bound : ∀ t : ℝ, |t - 1| < 1 → t^2 + 10*t + 1 > 0 := by
      intro t ht
      have h1 : -1 < t - 1 := neg_lt_of_abs_lt ht
      have h2 : t - 1 < 1 := abs_lt.mp ht |>.2
      have : t < 2 := by linarith
      nlinarith
    filter_upwards [Metric.ball_mem_nhds 1 (by norm_num : (0 : ℝ) < 1)] with t ht
    unfold capHalfSlice
    have hpos : 0 < t^2 + 10*t + 1 := h_bound t ht
    rw [show ((t + 1) / 2) ^ 2 + 2 * t = (t^2 + 10*t + 1) / 4 by ring]
    rw [Real.sqrt_div' _ (by norm_num : (0 : ℝ) ≤ 4)]
    rw [show Real.sqrt 4 = 2 by rw [show (4 : ℝ) = 2^2 by norm_num, Real.sqrt_sq (by norm_num : (0 : ℝ) ≤ 2)]]
    ring
  -- Use that the derivatives agree since the functions agree locally
  simp only [iteratedDeriv_succ', iteratedDeriv_zero]
  -- The functions agree on an open set, so their derivatives agree there too
  let f := fun t : ℝ => (t + 1 + Real.sqrt (t^2 + 10*t + 1)) / 4
  -- t^2 + 10t + 1 > 0 for t > -5 + 2*sqrt(6) ≈ -0.1
  -- We use interval (0, 2) which is safe
  have h_local_eq' : ∀ t : ℝ, 0 < t ∧ t < 2 → capHalfSlice t = f t := by
    intro t ⟨ht1, ht2⟩
    have hpos : t^2 + 10*t + 1 > 0 := by nlinarith
    unfold capHalfSlice
    rw [show ((t + 1) / 2) ^ 2 + 2 * t = (t^2 + 10*t + 1) / 4 by ring]
    rw [Real.sqrt_div' _ (by norm_num : (0 : ℝ) ≤ 4)]
    rw [show Real.sqrt 4 = 2 by rw [show (4 : ℝ) = 2^2 by norm_num, Real.sqrt_sq (by norm_num : (0 : ℝ) ≤ 2)]]
    ring
  have h_deriv_eventuallyEq : deriv capHalfSlice =ᶠ[nhds 1] deriv f := by
    have h_mem : {t : ℝ | 0 < t ∧ t < 2} ∈ nhds 1 := isOpen_Ioo.mem_nhds ⟨by norm_num, by norm_num⟩
    filter_upwards [h_mem] with t ht
    have ht_mem : {t : ℝ | 0 < t ∧ t < 2} ∈ nhds t := isOpen_Ioo.mem_nhds ht
    exact Filter.EventuallyEq.deriv_eq (Filter.eventually_of_mem ht_mem h_local_eq')
  have h_second_deriv_eq : deriv (deriv capHalfSlice) 1 = deriv (deriv f) 1 := 
    Filter.EventuallyEq.deriv_eq h_deriv_eventuallyEq
  rw [h_second_deriv_eq]
  -- Define helper functions
  let g : ℝ → ℝ := fun t => t^2 + 10*t + 1
  let h : ℝ → ℝ := fun t => Real.sqrt (g t)
  -- f t = (t + 1 + h t) / 4
  
  -- Key values at t = 1
  have hg1 : g 1 = 12 := by norm_num
  have hh1 : h 1 = 2 * Real.sqrt 3 := by
    simp [h, g]
    norm_num
    rw [show (12 : ℝ) = 4 * 3 by norm_num, Real.sqrt_mul (by norm_num : (0 : ℝ) ≤ 4)]
    norm_num
  have hg1_pos : 0 < g 1 := by norm_num
  
  -- g is differentiable
  have hg_deriv : ∀ t, HasDerivAt g (2*t + 10) t := by
    intro t
    have h1 : HasDerivAt (fun t => t^2) (2*t) t := by
      simpa [pow_succ'] using hasDerivAt_pow 2 t
    have h2 : HasDerivAt (fun t => 10*t) 10 t := by
      have := (hasDerivAt_id t).const_mul (10 : ℝ)
      simp at this ⊢
      exact this
    have h3 : HasDerivAt (fun _ : ℝ => (1 : ℝ)) 0 t := hasDerivAt_const t 1
    have := (h1.add h2).add h3
    simp only [g] at this ⊢
    convert this using 1
    ring
  
  -- h t = sqrt(g t), so h' t = g' t / (2 * sqrt(g t)) = (2t + 10) / (2 * sqrt(t^2 + 10t + 1))
  have hh_deriv : ∀ t : ℝ, 0 < g t → HasDerivAt h ((2*t + 10) / (2 * Real.sqrt (g t))) t := by
    intro t ht
    have hsqrt : HasDerivAt Real.sqrt (1 / (2 * Real.sqrt (g t))) (g t) := by
      apply Real.hasDerivAt_sqrt
      exact ht.ne'
    have := hsqrt.comp t (hg_deriv t)
    simp at this
    convert this using 1
    ring
  
  -- f t = (t + 1 + h t) / 4
  have hf_deriv : ∀ t : ℝ, 0 < g t → HasDerivAt f ((1 + (2*t + 10) / (2 * Real.sqrt (g t))) / 4) t := by
    intro t ht
    have h1 : HasDerivAt (fun t => t + 1) 1 t := by
      convert (hasDerivAt_id t).add (hasDerivAt_const t 1) using 1
      ring
    have h2 := hh_deriv t ht
    have h3 : HasDerivAt (fun t => t + 1 + h t) (1 + (2*t + 10) / (2 * Real.sqrt (g t))) t := h1.add h2
    have h4 : HasDerivAt (fun t => (t + 1 + h t) / 4) ((1 + (2*t + 10) / (2 * Real.sqrt (g t))) / 4) t := 
      h3.div_const 4
    exact h4
  
  -- deriv f t = (1 + (t+5)/sqrt(t^2+10t+1)) / 4
  have h_deriv_f_eq : ∀ t : ℝ, 0 < g t → deriv f t = (1 + (t + 5) / Real.sqrt (g t)) / 4 := by
    intro t ht
    rw [HasDerivAt.deriv (hf_deriv t ht)]
    congr 1
    field_simp
    ring
  
  -- Define k(t) = 1 + (t + 5) / sqrt(g(t))
  let k : ℝ → ℝ := fun t => 1 + (t + 5) / Real.sqrt (g t)
  
  -- deriv f = k / 4 on the interval (0, 2)
  have h_deriv_f_eventuallyEq : deriv f =ᶠ[nhds 1] (fun t => k t / 4) := by
    have h_mem : {t : ℝ | 0 < t ∧ t < 2} ∈ nhds 1 := isOpen_Ioo.mem_nhds ⟨by norm_num, by norm_num⟩
    filter_upwards [h_mem] with t ht
    rw [h_deriv_f_eq t (by simp [g]; nlinarith)]
  
  -- deriv (deriv f) 1 = deriv (k/4) 1 = k'(1) / 4
  have h_second_deriv' : deriv (deriv f) 1 = deriv (fun t => k t / 4) 1 := by
    exact Filter.EventuallyEq.deriv_eq h_deriv_f_eventuallyEq
  
  rw [h_second_deriv', deriv_div_const]
  
  -- k t = 1 + (t + 5) / sqrt(g t)
  -- k'(t) = (sqrt(g) - (t+5) * g'/(2*sqrt(g))) / g = (2g - (t+5)*g') / (2*g^(3/2))
  -- At t = 1: g = 12, g' = 12, (t+5) = 6
  -- k'(1) = (2*12 - 6*12) / (2*12^(3/2)) = (24 - 72) / (2*24*sqrt(3)) = -48 / (48*sqrt(3)) = -1/sqrt(3) = -sqrt(3)/3
  
  have hk_deriv : HasDerivAt k (-Real.sqrt 3 / 3) 1 := by
    -- k = 1 + u/v where u(t) = t + 5, v(t) = sqrt(g t)
    -- Use quotient rule: (u/v)' = (u'v - uv') / v^2
    
    have hu_at_1 : HasDerivAt (fun t : ℝ => t + 5) 1 (1 : ℝ) := by
      have := (hasDerivAt_id (1 : ℝ)).add_const (5 : ℝ)
      simp at this ⊢
      exact this
    
    have hv_val : Real.sqrt (g 1) = 2 * Real.sqrt 3 := hh1
    have hv_ne : Real.sqrt (g 1) ≠ 0 := by rw [hv_val]; positivity
    
    have hv_at_1 : HasDerivAt (fun t => Real.sqrt (g t)) (Real.sqrt 3) 1 := by
      have := hh_deriv 1 hg1_pos
      rw [hv_val] at this
      convert this using 1
      field_simp
      rw [Real.sq_sqrt (by norm_num : (0 : ℝ) ≤ 3)]
      norm_num
    
    have huv_at_1 : HasDerivAt (fun t : ℝ => (t + 5) / Real.sqrt (g t)) 
        ((1 * Real.sqrt (g 1) - (1 + 5) * Real.sqrt 3) / (Real.sqrt (g 1))^2) 1 := by
      apply HasDerivAt.div hu_at_1 hv_at_1 hv_ne
    
    have := huv_at_1.add_const 1
    rw [hv_val] at this
    convert this using 1
    · ext t; ring
    · norm_num [hg1]
      field_simp
      rw [Real.sq_sqrt (by norm_num : (0 : ℝ) ≤ 3)]
      ring
  
  rw [HasDerivAt.deriv hk_deriv]
  ring

private lemma cesHalfSlice_second_deriv {ρ : ℝ} (hρ : ρ ≠ 0) :
    iteratedDeriv 2 (cesHalfSlice ρ) 1 = (ρ - 1) / 4 := by
  simp only [iteratedDeriv_succ, iteratedDeriv_zero]
  -- First compute the derivative of cesHalfSlice ρ
  have hderiv : ∀ t : ℝ, 0 < t →
      deriv (cesHalfSlice ρ) t = ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2 := by
    intro t ht
    unfold cesHalfSlice
    have hu : 0 < (t ^ ρ + 1) / 2 := by positivity
    have hinner : HasDerivAt (fun t => t ^ ρ + 1) (ρ * t ^ (ρ - 1)) t := by
      have h1 : HasDerivAt (fun t => t ^ ρ) (ρ * t ^ (ρ - 1)) t := Real.hasDerivAt_rpow_const (Or.inl ht.ne')
      exact h1.add_const 1
    have hu' : HasDerivAt (fun t => (t ^ ρ + 1) / 2) (ρ * t ^ (ρ - 1) / 2) t := by
      exact hinner.div_const 2
    have h_outer : HasDerivAt (fun u => u ^ (1 / ρ)) ((1 / ρ) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1)) ((t ^ ρ + 1) / 2) :=
      Real.hasDerivAt_rpow_const (Or.inl hu.ne')
    have hchain := h_outer.comp t hu'
    have : deriv (fun t => ((t ^ ρ + 1) / 2) ^ (1 / ρ)) t = 1 / ρ * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * (ρ * t ^ (ρ - 1) / 2) := by
      exact hchain.deriv
    rw [this]
    field_simp
  -- The first derivative function
  set f' : ℝ → ℝ := fun t => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2
  -- The derivative matches on (0, ∞)
  have hderiv_eq : ∀ᶠ t in nhds 1, deriv (cesHalfSlice ρ) t = f' t := by
    filter_upwards [Ioi_mem_nhds (by norm_num : (0 : ℝ) < 1)] with t ht
    exact hderiv t ht
  -- Now compute deriv f' at 1
  have hf'_deriv : deriv f' 1 = (ρ - 1) / 4 := by
    -- f' t = ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2
    -- We compute deriv f' at t = 1 using HasDerivAt
    have h1ne : (1 : ℝ) ≠ 0 := by norm_num
    have hval : ((1 : ℝ) ^ ρ + 1) / 2 = 1 := by norm_num [Real.one_rpow]
    -- Derivative of inner u(t) = (t^ρ + 1)/2 at t=1
    have hu : HasDerivAt (fun t : ℝ => t ^ ρ + 1) (ρ * 1 ^ (ρ - 1)) 1 := by
      have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) (ρ * 1 ^ (ρ - 1)) 1 :=
        Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (Or.inl h1ne)
      exact h1.add_const 1
    have hu' : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ / 2) 1 := by
      convert hu.div_const 2 using 1
      simp [Real.one_rpow]
    -- Derivative of g(t) = u(t)^(1/ρ - 1) at t=1
    have hg : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1)) ((1 / ρ - 1) * (ρ / 2)) 1 := by
      have hexp := Real.hasDerivAt_rpow_const (x := ((1 : ℝ) ^ ρ + 1) / 2) (p := 1 / ρ - 1) (Or.inl (by norm_num : ((1 : ℝ) ^ ρ + 1) / 2 ≠ 0))
      convert hexp.comp 1 hu' using 1
      simp [Real.one_rpow]
    -- Derivative of h(t) = t^(ρ - 1) at t=1
    have hh : HasDerivAt (fun t : ℝ => t ^ (ρ - 1)) (ρ - 1) 1 := by
      have := Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ - 1) (Or.inl h1ne)
      simp [Real.one_rpow] at this
      exact this
    -- f' = g * h / 2
    have hf' : HasDerivAt f' (((1 / ρ - 1) * (ρ / 2) + (ρ - 1)) / 2) 1 := by
      have hgh := hg.mul hh
      convert hgh.div_const 2 using 1
      simp [Real.one_rpow]
    rw [hf'.deriv]
    field_simp
    ring
  rw [Filter.EventuallyEq.deriv_eq hderiv_eq]
  exact hf'_deriv

private lemma capHalfSlice_fourth_deriv :
    iteratedDeriv 4 capHalfSlice 1 = -7 * Real.sqrt 3 / 24 := by
  -- Need to prove: iteratedDeriv 4 capHalfSlice 1 = -7 * √3 / 24
  simp [iteratedDeriv_succ]
  -- Compute the actual derivative and show it's different
  -- Define u, g, f as helper functions
  let u : ℝ → ℝ := fun t => t^2 + 10*t + 1
  let g : ℝ → ℝ := fun t => Real.sqrt (u t)
  let f : ℝ → ℝ := fun t => (t + 1) / 4 + g t / 4
  have hcap_eq_f : capHalfSlice = f := by
    funext t
    simp [capHalfSlice, f, g, u]
    have hsimp : ((t + 1) / 2) ^ 2 + 2 * t = (t^2 + 10*t + 1) / 4 := by ring
    rw [hsimp]
    rw [Real.sqrt_div' _ (by norm_num : (0 : ℝ) ≤ 4)]
    ring
  rw [hcap_eq_f]
  -- Need to compute iteratedDeriv 4 f 1 = -11/8
  -- and show -11/8 ≠ -7*sqrt(3)/24
  
  -- First, establish HasDerivAt facts for the derivatives
  
  -- u(t) = t^2 + 10t + 1, u'(t) = 2t + 10, u''(t) = 2, u'''(t) = 0, u''''(t) = 0
  have hu_deriv : ∀ t, HasDerivAt u (2*t + 10) t := fun t => by
    simp [u]
    have := ((hasDerivAt_pow 2 t).add ((hasDerivAt_id t).const_mul 10)).add_const 1
    simpa using this
  
  have hu_deriv2 : ∀ t, HasDerivAt (deriv u) 2 t := fun t => by
    have : deriv u = fun t => 2*t + 10 := funext (fun t => (hu_deriv t).deriv)
    rw [this]
    have := ((hasDerivAt_id t).const_mul 2).add_const 10
    simpa using this
  
  -- g(t) = sqrt(u(t)), need u(t) > 0 near t = 1
  have hu_pos : ∀ t ∈ Set.Icc 0 2, 0 < u t := by
    intro t ⟨ht0, ht2⟩
    simp [u]
    nlinarith
  
  have hg_pos_at_1 : 0 < g 1 := by
    simp [g]
    norm_num
  
  -- g'(t) = u'(t) / (2 * g(t)) = (2t + 10) / (2 * sqrt(u(t))) = (t + 5) / g(t)
  have hg_deriv : ∀ t ∈ Set.Ioo 0 2, HasDerivAt g ((t + 5) / g t) t := fun t ht => by
    have hu_pos_t : 0 < u t := hu_pos t ⟨ht.1.le, ht.2.le⟩
    have hg_eq : g = Real.sqrt ∘ u := rfl
    have hg_deriv := Real.hasDerivAt_sqrt hu_pos_t.ne' |>.comp t (hu_deriv t)
    simp [hg_eq] at hg_deriv ⊢
    have : (2 * t + 10) / (2 * Real.sqrt (u t)) = (t + 5) / Real.sqrt (u t) := by ring
    convert hg_deriv using 1
    ring
  
  -- At t = 1: g'(1) = (1 + 5) / g(1) = 6 / (2*sqrt(3)) = 3/sqrt(3) = sqrt(3)
  have hg_deriv_at_1 : HasDerivAt g (Real.sqrt 3) 1 := by
    have h1 : HasDerivAt g ((1 + 5) / g 1) 1 := hg_deriv 1 ⟨by norm_num, by norm_num⟩
    convert h1 using 1
    simp [g]
    norm_num
    rw [show (12 : ℝ) = 4 * 3 by norm_num, Real.sqrt_mul (by norm_num : (0 : ℝ) ≤ 4)]
    norm_num
    field_simp
    ring_nf
    norm_num
  
  -- f(t) = (t+1)/4 + g(t)/4
  -- f'(t) = 1/4 + g'(t)/4
  -- f''(t) = g''(t)/4
  -- f'''(t) = g'''(t)/4
  -- f''''(t) = g''''(t)/4
  
  have hf_deriv : ∀ t ∈ Set.Ioo 0 2, HasDerivAt f (1/4 + (t + 5) / (4 * g t)) t := fun t ht => by
    have hgf := hg_deriv t ht
    have hid : HasDerivAt (fun t : ℝ => (t + 1) / 4) (1/4) t := by
      have := (hasDerivAt_id t).add_const 1
      convert this.div_const 4 using 1 <;> ring
    have hgf4 : HasDerivAt (fun t => g t / 4) ((t + 5) / (4 * g t)) t := by
      have := hgf.div_const 4
      convert this using 1 <;> ring
    simpa using hid.add hgf4
  
  have hf_deriv_at_1 : HasDerivAt f (1/4 + Real.sqrt 3 / 4) 1 := by
    have h1 := hf_deriv 1 ⟨by norm_num, by norm_num⟩
    convert h1 using 1
    have hg1_eq : g 1 = 2 * Real.sqrt 3 := by
      simp [g]
      norm_num
      rw [show (12 : ℝ) = 4 * 3 by norm_num, Real.sqrt_mul (by norm_num : (0 : ℝ) ≤ 4)]
      norm_num
    rw [hg1_eq]
    field_simp
    ring_nf
    norm_num
    ring
  
  simp [show f = fun t => (t + 1) / 4 + g t / 4 by rfl]
  
  -- g''(t) = -24 / g(t)^3
  have hg_deriv2 : ∀ t ∈ Set.Ioo 0 2, HasDerivAt (deriv g) (-24 / g t ^ 3) t := fun t ht => by
    have hg := hg_deriv t ht
    have hu_pos_t : 0 < u t := hu_pos t ⟨ht.1.le, ht.2.le⟩
    have hg_ne : g t ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr hu_pos_t)
    -- g'(t) = (t+5)/g(t)
    have hg'_eq : deriv g t = (t + 5) / g t := hg.deriv
    -- Need HasDerivAt for g' = (t+5)/g
    have hnum : HasDerivAt (fun t => t + 5) 1 t := by
      have := hasDerivAt_id t |>.add_const 5
      simpa using this
    have hden : HasDerivAt g ((t + 5) / g t) t := hg
    have hg'_deriv := hnum.div hden hg_ne
    have hderiv_g_eq : deriv g t = (t + 5) / g t := hg.deriv
    have hg'_deriv' : HasDerivAt (deriv g) (-24 / g t ^ 3) t := by
      have hIoo : Set.Ioo 0 2 ∈ nhds t := Ioo_mem_nhds ht.1 ht.2
      have heventually : ∀ᶠ s in nhds t, deriv g s = (s + 5) / g s := Filter.eventually_of_mem hIoo (fun s hs => (hg_deriv s hs).deriv)
      have hg''_deriv := hg'_deriv.congr_of_eventuallyEq heventually
      have hderiv_eq : (1 * g t - (t + 5) * ((t + 5) / g t)) / g t ^ 2 = -24 / g t ^ 3 := by
        field_simp
        ring_nf
        rw [Real.sq_sqrt hu_pos_t.le]
        ring
      rwa [hderiv_eq] at hg''_deriv
    exact hg'_deriv'
  
  -- g'''(t) = 72 * (t + 5) / g(t)^5
  have hg_deriv3 : ∀ t ∈ Set.Ioo 0 2, HasDerivAt (deriv (deriv g)) (72 * (t + 5) / g t ^ 5) t := by
    intro t ht
    have hg2 := hg_deriv2 t ht
    have hg := hg_deriv t ht
    have hg_ne : g t ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr (hu_pos t ⟨ht.1.le, ht.2.le⟩))
    have hu_pos_t : 0 < u t := hu_pos t ⟨ht.1.le, ht.2.le⟩
    have hIoo : Set.Ioo 0 2 ∈ nhds t := Ioo_mem_nhds ht.1 ht.2
    have heventually : ∀ᶠ s in nhds t, deriv (deriv g) s = -24 / g s ^ 3 := by
      apply Filter.eventually_of_mem hIoo
      intro s hs
      exact (hg_deriv2 s hs).deriv
    -- g''(t) = -24 / g(t)^3, g'''(t) = d/dt[-24/g(t)^3] = 72*g'(t)/g(t)^4 = 72(t+5)/g(t)^5
    have hnum : HasDerivAt (fun _ => (-24 : ℝ)) 0 t := hasDerivAt_const t (-24)
    have hden : HasDerivAt (fun t => g t ^ 3) (3 * g t ^ 2 * ((t + 5) / g t)) t := by
      have := hg.pow 3
      convert this using 1 <;> ring
    have hg''_deriv := hnum.div hden (pow_ne_zero 3 hg_ne)
    have hsimp : (0 * g t ^ 3 - -24 * (3 * g t ^ 2 * ((t + 5) / g t))) / (g t ^ 3) ^ 2 = 
                 72 * (t + 5) / g t ^ 5 := by
      field_simp
      have hg2 : g t ^ 2 = u t := Real.sq_sqrt hu_pos_t.le
      rw [hg2]
      ring
    rw [hsimp] at hg''_deriv
    exact hg''_deriv.congr_of_eventuallyEq heventually
  
  -- g''''(t) = 72 * (u(t) - 5*(t+5)^2) / g(t)^7 = 72 * (-4*t^2 - 40*t - 124) / g(t)^7 = -288 * (t^2 + 10*t + 31) / g(t)^7
  have hg_deriv4 : ∀ t ∈ Set.Ioo 0 2, HasDerivAt (deriv (deriv (deriv g))) 
      (-288 * (t^2 + 10*t + 31) / g t ^ 7) t := by
    intro t ht
    have hg3 := hg_deriv3 t ht
    have hg_ne : g t ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr (hu_pos t ⟨ht.1.le, ht.2.le⟩))
    have hu_pos_t : 0 < u t := hu_pos t ⟨ht.1.le, ht.2.le⟩
    have hIoo : Set.Ioo 0 2 ∈ nhds t := Ioo_mem_nhds ht.1 ht.2
    have heventually : ∀ᶠ s in nhds t, deriv (deriv (deriv g)) s = 72 * (s + 5) / g s ^ 5 := by
      apply Filter.eventually_of_mem hIoo
      intro s hs
      exact (hg_deriv3 s hs).deriv
    -- g'''(t) = 72 * (t + 5) / g(t)^5
    -- g''''(t) = d/dt[72*(t+5)/g(t)^5] = 72 * (g(t) - 5*(t+5)*(t+5)/g(t)) / g(t)^6 
    --         = 72 * (g(t)^2 - 5*(t+5)^2) / g(t)^7
    --         = 72 * (u(t) - 5*(t+5)^2) / g(t)^7
    --         = 72 * (t^2+10t+1 - 5*(t^2+10t+25)) / g(t)^7
    --         = 72 * (-4t^2 - 40t - 124) / g(t)^7
    --         = -288 * (t^2 + 10t + 31) / g(t)^7
    have hg := hg_deriv t ht
    have hnum : HasDerivAt (fun s => 72 * (s + 5)) (72 * 1) t := by
      have := (hasDerivAt_id t).add_const 5
      convert this.const_mul 72 using 1 <;> ring
    have hden : HasDerivAt (fun s => g s ^ 5) (5 * g t ^ 4 * ((t + 5) / g t)) t := by
      have := hg.pow 5
      convert this using 1 <;> ring
    have hg'''_deriv := hnum.div hden (pow_ne_zero 5 hg_ne)
    have hsimp : (72 * 1 * g t ^ 5 - 72 * (t + 5) * (5 * g t ^ 4 * ((t + 5) / g t))) / (g t ^ 5) ^ 2 = 
                 -288 * (t^2 + 10*t + 31) / g t ^ 7 := by
      have hg2 : g t ^ 2 = u t := Real.sq_sqrt hu_pos_t.le
      field_simp
      rw [hg2]
      ring
    rw [hsimp] at hg'''_deriv
    have heventually' : deriv (deriv (deriv g)) =ᶠ[nhds t] (fun s => 72 * (s + 5) / g s ^ 5) := by
      apply Filter.eventually_of_mem hIoo
      intro s hs
      exact (hg_deriv3 s hs).deriv
    exact hg'''_deriv.congr_of_eventuallyEq heventually'
  
  -- At t = 1: g''''(1) = -288 * 42 / (2√3)^7 = -12096 / (3456√3) = -3.5/√3 = -7√3/6
  have hg_deriv4_at_1 : deriv (deriv (deriv (deriv g))) 1 = -(7/2) * Real.sqrt 3 / 3 := by
    have h1 := hg_deriv4 1 ⟨by norm_num, by norm_num⟩
    have hg1_eq : g 1 = 2 * Real.sqrt 3 := by simp [g]; norm_num; rw [show (12:ℝ) = 4*3 by norm_num, Real.sqrt_mul (by norm_num)] ; norm_num
    rw [h1.deriv]
    simp [hg1_eq]
    have h2 : (2 * Real.sqrt 3) ^ 7 = 3456 * Real.sqrt 3 := by
      have h3 : Real.sqrt 3 ^ 7 = 27 * Real.sqrt 3 := by
        rw [show Real.sqrt 3 ^ 7 = (Real.sqrt 3 ^ 2) ^ 3 * Real.sqrt 3 by ring]
        rw [Real.sq_sqrt (by norm_num : (0 : ℝ) ≤ 3)]
        norm_num
      calc (2 * Real.sqrt 3) ^ 7 = 2^7 * (Real.sqrt 3)^7 := by ring
        _ = 128 * (27 * Real.sqrt 3) := by rw [h3]; norm_num
        _ = 3456 * Real.sqrt 3 := by ring_nf
    rw [h2]
    field_simp
    ring_nf
    rw [Real.sq_sqrt (by norm_num : (0:ℝ) ≤ 3)]
    ring
  
  -- f''''(1) = g''''(1) / 4 = -7√3/24
  -- deriv f = fun t => 1/4 + (t + 5) / (4 * g t) on (0, 2)
  have hdg_eq : ∀ t ∈ Set.Ioo 0 2, deriv g t = (t + 5) / g t := fun t ht => (hg_deriv t ht).deriv
  have hdf : ∀ t ∈ Set.Ioo 0 2, deriv f t = 1/4 + deriv g t / 4 := by
    intro t ht
    have hf' := (hf_deriv t ht).deriv
    rw [hdg_eq t ht]
    convert hf' using 1
    ring
  -- deriv (deriv f) = deriv (deriv g) / 4
  have hdf2 : ∀ t ∈ Set.Ioo 0 2, HasDerivAt (deriv f) (deriv (deriv g) t / 4) t := by
    intro t ht
    have hg2 := hg_deriv2 t ht
    have hconst : HasDerivAt (fun _ : ℝ => (1 : ℝ)/4) 0 t := hasDerivAt_const t (1/4)
    have hdiv4 : HasDerivAt (fun s => deriv g s / 4) (deriv (deriv g) t / 4) t := by
      convert hg2.div_const 4 using 1 <;> rw [hg2.deriv]
    have hderiv_f_loc : (fun s => deriv f s) =ᶠ[nhds t] (fun s => (1 : ℝ)/4 + deriv g s / 4) := 
      Filter.eventually_of_mem (Ioo_mem_nhds ht.1 ht.2) (fun s hs => hdf s hs)
    have h := (hconst.add hdiv4).congr_of_eventuallyEq hderiv_f_loc
    simp at h
    exact h
  -- deriv (deriv (deriv f)) = deriv (deriv (deriv g)) / 4
  have hdf3 : ∀ t ∈ Set.Ioo 0 2, HasDerivAt (deriv (deriv f)) (deriv (deriv (deriv g)) t / 4) t := by
    intro t ht
    have hg3 := hg_deriv3 t ht
    have hdiv4 : HasDerivAt (fun s => deriv (deriv g) s / 4) (deriv (deriv (deriv g)) t / 4) t := by
      convert hg3.div_const 4 using 1 <;> rw [hg3.deriv]
    have hderiv_df_loc : (fun s => deriv (deriv f) s) =ᶠ[nhds t] (fun s => deriv (deriv g) s / 4) := 
      Filter.eventually_of_mem (Ioo_mem_nhds ht.1 ht.2) (fun s hs => (hdf2 s hs).deriv)
    exact hdiv4.congr_of_eventuallyEq hderiv_df_loc
  -- deriv (deriv (deriv (deriv f))) = deriv (deriv (deriv (deriv g))) / 4
  have hdf4 : HasDerivAt (deriv (deriv (deriv f))) (deriv (deriv (deriv (deriv g))) 1 / 4) 1 := by
    have hg4 := hg_deriv4 1 ⟨by norm_num, by norm_num⟩
    have hdiv4 : HasDerivAt (fun s => deriv (deriv (deriv g)) s / 4) (deriv (deriv (deriv (deriv g))) 1 / 4) 1 := by
      convert hg4.div_const 4 using 1 <;> rw [hg4.deriv]
    have hderiv_df2_loc : (fun s => deriv (deriv (deriv f)) s) =ᶠ[nhds (1 : ℝ)] (fun s => deriv (deriv (deriv g)) s / 4) := 
      Filter.eventually_of_mem (Ioo_mem_nhds (by norm_num : (0:ℝ) < 1) (by norm_num : (1:ℝ) < 2)) (fun s hs => (hdf3 s hs).deriv)
    exact hdiv4.congr_of_eventuallyEq hderiv_df2_loc
  -- f''''(1) = g''''(1) / 4 = -7√3/24
  have hf_deriv4_at_1 : deriv (deriv (deriv (deriv f))) 1 = -(7 * Real.sqrt 3) / 24 := by
    rw [hdf4.deriv, hg_deriv4_at_1]
    field_simp
    ring_nf
  show deriv (deriv (deriv (deriv f))) 1 = -(7 * √3) / 24
  exact hf_deriv4_at_1

private lemma cesHalfSlice_fourth_deriv {ρ : ℝ} (hρ : ρ ≠ 0) :
    iteratedDeriv 4 (cesHalfSlice ρ) 1 =
      -(ρ - 3) * (ρ - 1) * (2 * ρ + 5) / 16 := by
  simp [iteratedDeriv_succ, iteratedDeriv_zero]
  -- Define symbolic derivatives
  let F : ℝ → ℝ := cesHalfSlice ρ
  let F1 : ℝ → ℝ := fun t => t ^ (ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) / 2
  let F2 : ℝ → ℝ := fun t => (ρ - 1) / 4 * t ^ (ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2)
  let F3 : ℝ → ℝ := fun t => (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
      ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ)
  let F4 : ℝ → ℝ := fun t => (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
      ((ρ - 2) * ρ * t ^ (ρ - 1) / 2 + (1 / 2 - ρ) * ρ * t ^ (ρ - 1)) +
      (ρ - 1) / 4 * t ^ (ρ - 3) * (1 / ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 4) * (ρ * t ^ (ρ - 1) / 2) *
      ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) +
      (ρ - 1) / 4 * (ρ - 3) * t ^ (ρ - 4) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
      ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ)
  -- Values at t = 1
  have hF1_at_1 : F1 1 = 1 / 2 := by simp [F1, Real.one_rpow]
  have hF2_at_1 : F2 1 = (ρ - 1) / 4 := by simp [F2, Real.one_rpow]
  have hF3_at_1 : F3 1 = -3 * (ρ - 1) / 8 := by simp [F3, Real.one_rpow]; field_simp; ring
  have hF4_at_1 : F4 1 = -(ρ - 3) * (ρ - 1) * (2 * ρ + 5) / 16 := by
    simp [F4, Real.one_rpow]
    field_simp
    ring
  have hgoal : (3 - ρ) * (ρ - 1) * (2 * ρ + 5) / 16 = -(ρ - 3) * (ρ - 1) * (2 * ρ + 5) / 16 := by ring
  rw [hgoal, ← hF4_at_1]
  -- Now I need to show deriv (deriv (deriv (deriv F))) 1 = F4 1
  -- Since F = cesHalfSlice ρ
  have hF_eq : F = cesHalfSlice ρ := rfl
  -- Prove HasDerivAt for F at t = 1
  -- F(t) = ((t^ρ + 1) / 2) ^ (1/ρ)
  -- At t = 1: F(1) = 1, F'(1) = 1/2
  have hF_deriv : HasDerivAt F (1 / 2) 1 := by
    -- F(t) = ((t^ρ + 1) / 2) ^ (1/ρ)
    -- Use chain rule: F = (fun v => v^(1/ρ)) ∘ (fun u => (u + 1) / 2) ∘ (fun t => t^ρ)
    have h_u : HasDerivAt (fun t : ℝ => t ^ ρ) ρ 1 := by
      simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ)
    have h_v_at : HasDerivAt (fun u : ℝ => (u + 1) / 2) (1 / 2) (1 ^ ρ) := by
      rw [Real.one_rpow]
      exact ((hasDerivAt_id (1 : ℝ)).add_const 1).div_const 2
    have h_w_at : HasDerivAt (fun v : ℝ => v ^ (1 / ρ)) (1 / ρ) (((fun u => (u + 1) / 2) ∘ fun t => t ^ ρ) 1) := by
      simp [Real.one_rpow]
      simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := 1 / ρ)
    have h_comp1 := h_v_at.comp 1 h_u
    have h_comp2 := h_w_at.comp 1 h_comp1
    have hF_eq2 : (fun v : ℝ => v ^ (1 / ρ)) ∘ (fun u : ℝ => (u + 1) / 2) ∘ (fun t : ℝ => t ^ ρ) = F := by
      funext t
      simp only [Function.comp_apply]
      rfl
    rw [hF_eq2] at h_comp2
    have h_simp : 1 / ρ * (1 / 2 * ρ) = 1 / 2 := by field_simp [hρ]
    rw [h_simp] at h_comp2
    exact h_comp2
  have hF1_deriv : HasDerivAt F1 (F2 1) 1 := by
    rw [hF2_at_1]
    simp only [F1]
    -- F1(t) = t^(ρ-1) * ((t^ρ + 1)/2)^(1/ρ-1) / 2
    -- derivative at t=1 is (ρ-1)/4
    -- Let u = t^(ρ-1), v = ((t^ρ + 1)/2)^(1/ρ-1)
    -- du/dt(1) = ρ-1, dv/dt(1) = (1/ρ-1) * ρ/2 = (1-ρ)/2
    -- d(u*v)/dt(1) = (ρ-1)*1 + 1*(1-ρ)/2 = (ρ-1)/2
    -- d(u*v/2)/dt(1) = (ρ-1)/4
    have hu : HasDerivAt (fun t : ℝ => t ^ (ρ - 1)) (ρ - 1) 1 := by
      simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ - 1)
    have hv_inner : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ / 2) 1 := by
      have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) ρ 1 := by
        simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ)
      have h2 : HasDerivAt (fun t : ℝ => t ^ ρ + 1) ρ 1 := by simpa using h1.add_const 1
      convert h2.div_const 2 using 1 <;> ring
    have hv : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1)) ((1 / ρ - 1) * (ρ / 2)) 1 := by
      have h1rho : (1 : ℝ) / ρ - 1 = ρ⁻¹ - 1 := by ring
      rw [h1rho]
      have hv_rpow := HasDerivAt.rpow hv_inner (hasDerivAt_const (1 : ℝ) (ρ⁻¹ - 1)) (by simp [Real.one_rpow])
      convert hv_rpow using 1
      simp [Real.one_rpow]
      ring
    have huv : HasDerivAt (fun t : ℝ => t ^ (ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1)) ((ρ - 1) * 1 + 1 * ((1 / ρ - 1) * (ρ / 2))) 1 := by
      have := hu.mul hv
      simp [Real.one_rpow] at this ⊢
      exact this
    have h_simp : (ρ - 1) * 1 + 1 * ((1 / ρ - 1) * (ρ / 2)) = (ρ - 1) / 2 := by field_simp [hρ]; ring
    rw [h_simp] at huv
    convert huv.div_const 2 using 1
    ring
  have hF2_deriv : HasDerivAt F2 (F3 1) 1 := by
    rw [hF3_at_1]
    simp only [F2]
    -- F2(t) = (ρ - 1) / 4 * t ^ (ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2)
    -- This is a constant times a product of two functions
    -- Let u = t^(ρ-2), v = ((t^ρ + 1)/2)^(1/ρ - 2)
    -- du/dt(1) = ρ-2, dv/dt(1) = (1/ρ - 2) * ρ/2 = (1-2ρ)/2
    -- d(u*v)/dt(1) = (ρ-2)*1 + 1*(1-2ρ)/2 = (2ρ - 4 + 1 - 2ρ)/2 = -3/2
    -- (ρ-1)/4 * (-3/2) = -3(ρ-1)/8
    have hu : HasDerivAt (fun t : ℝ => t ^ (ρ - 2)) (ρ - 2) 1 := by
      simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ - 2)
    have hv_inner : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ / 2) 1 := by
      have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) ρ 1 := by
        simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ)
      have h2 : HasDerivAt (fun t : ℝ => t ^ ρ + 1) ρ 1 := by simpa using h1.add_const 1
      convert h2.div_const 2 using 1 <;> ring
    have hv : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2)) ((1 / ρ - 2) * (ρ / 2)) 1 := by
      have h1rho : (1 : ℝ) / ρ - 2 = ρ⁻¹ - 2 := by ring
      rw [h1rho]
      have hv_rpow := HasDerivAt.rpow hv_inner (hasDerivAt_const (1 : ℝ) (ρ⁻¹ - 2)) (by simp [Real.one_rpow])
      convert hv_rpow using 1
      simp [Real.one_rpow]
      ring
    have huv : HasDerivAt (fun t : ℝ => t ^ (ρ - 2) * ((t ^ ρ + 1) / 2) ^ (ρ⁻¹ - 2)) ((ρ - 2) + (ρ⁻¹ - 2) * (ρ / 2)) 1 := by
      have := hu.mul hv
      simp at this
      exact this
    have h_simp : (ρ - 2) + (ρ⁻¹ - 2) * (ρ / 2) = -3 / 2 := by field_simp [hρ]; ring
    rw [h_simp] at huv
    convert huv.const_mul ((ρ - 1) / 4) using 1 <;> ring_nf
  have hF3_deriv : HasDerivAt F3 (F4 1) 1 := by
    rw [hF4_at_1]
    simp only [F3]
    -- F3(t) = (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
    --         ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ)
    -- 4 factors: constant * u * v * w
    -- At t=1: u=1, v=1, w=(-ρ-1)/2
    -- u'(1)=ρ-3, v'(1)=(1/ρ-3)*ρ/2, w'(1)=ρ*(-ρ-1)/2
    -- Product rule: c * (u'vw + uv'w + uvw')
    have hu : HasDerivAt (fun t : ℝ => t ^ (ρ - 3)) (ρ - 3) 1 := by
      simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ - 3)
    have hv_inner : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ / 2) 1 := by
      have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) ρ 1 := by
        simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ)
      have h2 : HasDerivAt (fun t : ℝ => t ^ ρ + 1) ρ 1 := by simpa using h1.add_const 1
      convert h2.div_const 2 using 1 <;> ring
    have hv : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3)) ((1 / ρ - 3) * (ρ / 2)) 1 := by
      have h1rho : (1 : ℝ) / ρ - 3 = ρ⁻¹ - 3 := by ring
      rw [h1rho]
      have hv_rpow := HasDerivAt.rpow hv_inner (hasDerivAt_const (1 : ℝ) (ρ⁻¹ - 3)) (by simp [Real.one_rpow])
      convert hv_rpow using 1
      simp [Real.one_rpow]
      ring
    have hw : HasDerivAt (fun t : ℝ => (ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) (-ρ * (ρ + 1) / 2) 1 := by
      have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) ρ 1 := by
        simpa [Real.rpow_one] using Real.hasDerivAt_rpow_const (x := (1 : ℝ)) (p := ρ)
      have h2 : HasDerivAt (fun t : ℝ => t ^ ρ + 1) ρ 1 := by simpa using h1.add_const 1
      have h3 : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ / 2) 1 := by simpa using h2.div_const 2
      have h4 : HasDerivAt (fun t : ℝ => (ρ - 2) * ((t ^ ρ + 1) / 2)) ((ρ - 2) * (ρ / 2)) 1 := h3.const_mul (ρ - 2)
      have h5 : HasDerivAt (fun t : ℝ => (1 / 2 - ρ) * t ^ ρ) ((1 / 2 - ρ) * ρ) 1 := h1.const_mul (1 / 2 - ρ)
      have h6 := h4.add h5
      convert h6 using 1
      ring
    -- w(1) = (ρ - 2) * 1 + (1/2 - ρ) = -3/2
    have hw_at_1 : (ρ - 2) * ((1 : ℝ) ^ ρ + 1) / 2 + (1 / 2 - ρ) * 1 ^ ρ = -3 / 2 := by simp; ring
    -- Now use product rule for 4 factors
    have huv : HasDerivAt (fun t : ℝ => t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (ρ⁻¹ - 3)) ((ρ - 3) + (ρ⁻¹ - 3) * (ρ / 2)) 1 := by
      have := hu.mul hv
      simp at this
      exact this
    have huvw : HasDerivAt (fun t : ℝ => t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (ρ⁻¹ - 3) *
        ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ))
        ((ρ - 3) * 1 * (-3/2) + 1 * ((ρ⁻¹ - 3) * (ρ / 2)) * (-3/2) + 1 * 1 * (-ρ * (ρ + 1) / 2)) 1 := by
      have huv_const := huv
      have := huv_const.mul hw
      simp_all [Real.one_rpow]
      convert this using 1 <;> ring
    have hF3' : HasDerivAt (fun t : ℝ => (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (ρ⁻¹ - 3) *
        ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ))
        ((ρ - 1) / 4 * ((ρ - 3) * (-3/2) + (ρ⁻¹ - 3) * (ρ / 2) * (-3/2) + (-ρ * (ρ + 1) / 2))) 1 := by
      have := huvw.const_mul ((ρ - 1) / 4)
      simpa [mul_assoc] using this
    have h_inv : (1 : ℝ) / ρ = ρ⁻¹ := by ring
    have h_eq : -(ρ - 3) * (ρ - 1) * (2 * ρ + 5) / 16 =
        (ρ - 1) / 4 * ((ρ - 3) * (-3 / 2) + (ρ⁻¹ - 3) * (ρ / 2) * (-3 / 2) + (-ρ * (ρ + 1) / 2)) := by
      field_simp [hρ]
      ring
    have hF3_eq : (fun t : ℝ => (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
        ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ)) =
        (fun t : ℝ => (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (ρ⁻¹ - 3) *
        ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ)) := by
      funext t; simp [h_inv]
    rw [hF3_eq, h_eq]
    exact hF3'
  -- Chain the derivatives together
  -- deriv F 1 = 1/2 = F1 1
  have hderiv_F : deriv F 1 = F1 1 := by rw [hF_deriv.deriv, hF1_at_1]
  -- deriv F1 1 = (ρ-1)/4 = F2 1
  have hderiv_F1 : deriv F1 1 = F2 1 := by rw [hF1_deriv.deriv, hF2_at_1]
  -- deriv F2 1 = -3*(ρ-1)/8 = F3 1
  have hderiv_F2 : deriv F2 1 = F3 1 := by rw [hF2_deriv.deriv, hF3_at_1]
  -- deriv F3 1 = F4 1
  have hderiv_F3 : deriv F3 1 = F4 1 := by rw [hF3_deriv.deriv]
  -- The goal is: iteratedDeriv 4 F 1 = F4 1
  -- Chain using Filter.EventuallyEq.deriv_eq
  -- We prove that deriv F =ᶠ[𝓝 1] F1, etc., by showing the functions agree on (0, ∞)
  -- F1 t = deriv F t for all t > 0
  -- For now, we use the hypothesis that deriv F = F1, etc.
  -- This follows from the chain rule computations
  have hF_deriv_eq_F1 : (fun t => deriv F t) =ᶠ[𝓝 (1 : ℝ)] F1 := by
    filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
    have h_tρ_pos : 0 < (t : ℝ) ^ ρ := Real.rpow_pos_of_pos ht ρ
    have h_inner_pos : 0 < ((t : ℝ) ^ ρ + 1) / 2 := by linarith
    have h_inner_ne : ((t : ℝ) ^ ρ + 1) / 2 ≠ 0 := h_inner_pos.ne'
    -- HasDerivAt for F at t
    have hF_at : HasDerivAt F (t ^ (ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) / 2) t := by
      have hu : HasDerivAt (fun t : ℝ => t ^ ρ) (ρ * t ^ (ρ - 1)) t := by
        exact Real.hasDerivAt_rpow_const (Or.inl ht.ne')
      have hv : HasDerivAt (fun u : ℝ => (u + 1) / 2) (1 / 2) ((t : ℝ) ^ ρ) := by
        have h := hasDerivAt_id ((t : ℝ) ^ ρ)
        exact (h.add_const 1).div_const 2
      have hw : HasDerivAt (fun v : ℝ => v ^ (1 / ρ)) ((1 / ρ) * (((t : ℝ) ^ ρ + 1) / 2) ^ (1 / ρ - 1))
          (((t : ℝ) ^ ρ + 1) / 2) := by
        exact Real.hasDerivAt_rpow_const (Or.inl h_inner_ne)
      have h_comp1 := hv.comp t hu
      have h_comp2 := hw.comp t h_comp1
      have h_eq : ((fun v => v ^ (1 / ρ)) ∘ (fun u => (u + 1) / 2) ∘ fun t => t ^ ρ) = F := rfl
      rw [h_eq] at h_comp2
      convert h_comp2 using 1 <;> field_simp [hρ] <;> ring
    simpa [F1] using hF_at.deriv
  -- Similarly for F1 =ᶠ[𝓝 1] F2
  have hF1_deriv_eq_F2 : (fun t => deriv F1 t) =ᶠ[𝓝 (1 : ℝ)] F2 := by
    filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
    have h_tρ_pos : 0 < (t : ℝ) ^ ρ := Real.rpow_pos_of_pos ht ρ
    have h_inner_pos : 0 < ((t : ℝ) ^ ρ + 1) / 2 := by linarith
    have h_inner_ne : ((t : ℝ) ^ ρ + 1) / 2 ≠ 0 := h_inner_pos.ne'
    have h_tF1 : HasDerivAt F1 (F2 t) t := by
      simp only [F1, F2]
      -- F1(t) = t^(ρ-1) * ((t^ρ + 1)/2)^(1/ρ-1) / 2
      have hu : HasDerivAt (fun t : ℝ => t ^ (ρ - 1)) ((ρ - 1) * t ^ (ρ - 1 - 1)) t := by
        exact Real.hasDerivAt_rpow_const (Or.inl ht.ne')
      have hv_inner : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ * t ^ (ρ - 1) / 2) t := by
        have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) (ρ * t ^ (ρ - 1)) t :=
          Real.hasDerivAt_rpow_const (Or.inl ht.ne')
        have h2 : HasDerivAt (fun t : ℝ => t ^ ρ + 1) (ρ * t ^ (ρ - 1)) t := h1.add_const 1
        convert h2.div_const 2 using 1 <;> ring
      have hv : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1))
          ((1 / ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1 - 1) * (ρ * t ^ (ρ - 1) / 2)) t := by
        have := HasDerivAt.rpow hv_inner (hasDerivAt_const t (1 / ρ - 1)) (by linarith)
        convert this using 1
        ring
      have huv : HasDerivAt (fun t : ℝ => t ^ (ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1))
          (((ρ - 1) * t ^ (ρ - 1 - 1)) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) +
           t ^ (ρ - 1) * ((1 / ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1 - 1) * (ρ * t ^ (ρ - 1) / 2))) t := by
        exact hu.mul hv
      have h_deriv : HasDerivAt (fun x => x ^ (ρ - 1) * ((x ^ ρ + 1) / 2) ^ (1 / ρ - 1) / 2)
          (((ρ - 1) * t ^ (ρ - 1 - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) +
            t ^ (ρ - 1) * ((1 / ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1 - 1) * (ρ * t ^ (ρ - 1) / 2))) /
          2) t := huv.div_const 2
      have h_eq : (((ρ - 1) * t ^ (ρ - 1 - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) +
          t ^ (ρ - 1) * ((1 / ρ - 1) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1 - 1) * (ρ * t ^ (ρ - 1) / 2))) /
        2) = (ρ - 1) / 4 * t ^ (ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2) := by
        have h1 : ρ - 1 - 1 = ρ - 2 := by ring
        have h2 : 1 / ρ - 1 - 1 = 1 / ρ - 2 := by ring
        have h_inner_pos' : (0 : ℝ) < (t ^ ρ + 1) / 2 := by positivity
        rw [h1, h2]
        simp only [Real.rpow_sub ht, Real.rpow_sub h_inner_pos']
        have ht' : 0 < t := ht
        field_simp [ne_of_gt ht', ne_of_gt h_inner_pos']
        simp [pow_succ, mul_assoc]
        ring
      exact h_deriv.congr_deriv h_eq
    exact h_tF1.deriv
  -- Similarly for F2 =ᶠ[𝓝 1] F3
  have hF2_deriv_eq_F3 : (fun t => deriv F2 t) =ᶠ[𝓝 (1 : ℝ)] F3 := by
    filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
    have h_tρ_pos : 0 < (t : ℝ) ^ ρ := Real.rpow_pos_of_pos ht ρ
    have h_inner_pos : 0 < ((t : ℝ) ^ ρ + 1) / 2 := by linarith
    have h_inner_ne : ((t : ℝ) ^ ρ + 1) / 2 ≠ 0 := h_inner_pos.ne'
    have h_tF2 : HasDerivAt F2 (F3 t) t := by
      simp only [F2, F3]
      -- F2(t) = (ρ - 1) / 4 * t ^ (ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2)
      have hu : HasDerivAt (fun t : ℝ => t ^ (ρ - 2)) ((ρ - 2) * t ^ (ρ - 2 - 1)) t := by
        exact Real.hasDerivAt_rpow_const (Or.inl ht.ne')
      have hv_inner : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ * t ^ (ρ - 1) / 2) t := by
        have h1 : HasDerivAt (fun t : ℝ => t ^ ρ) (ρ * t ^ (ρ - 1)) t :=
          Real.hasDerivAt_rpow_const (Or.inl ht.ne')
        have h2 : HasDerivAt (fun t : ℝ => t ^ ρ + 1) (ρ * t ^ (ρ - 1)) t := h1.add_const 1
        convert h2.div_const 2 using 1 <;> ring
      have hv : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2))
          ((1 / ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2 - 1) * (ρ * t ^ (ρ - 1) / 2)) t := by
        have := HasDerivAt.rpow hv_inner (hasDerivAt_const t (1 / ρ - 2)) (by linarith)
        convert this using 1
        ring
      have huv : HasDerivAt (fun t : ℝ => t ^ (ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2))
          (((ρ - 2) * t ^ (ρ - 2 - 1)) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2) +
           t ^ (ρ - 2) * ((1 / ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2 - 1) * (ρ * t ^ (ρ - 1) / 2))) t := by
        exact hu.mul hv
      have h_deriv : HasDerivAt (fun x => (ρ - 1) / 4 * x ^ (ρ - 2) * ((x ^ ρ + 1) / 2) ^ (1 / ρ - 2))
          ((ρ - 1) / 4 * (((ρ - 2) * t ^ (ρ - 2 - 1)) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2) +
            t ^ (ρ - 2) * ((1 / ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2 - 1) * (ρ * t ^ (ρ - 1) / 2)))) t := by
        have h_const := huv.const_mul ((ρ - 1) / 4)
        convert h_const using 1 <;> ring_nf
      have h_eq : (ρ - 1) / 4 * (((ρ - 2) * t ^ (ρ - 2 - 1)) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2) +
            t ^ (ρ - 2) * ((1 / ρ - 2) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 2 - 1) * (ρ * t ^ (ρ - 1) / 2))) =
        (ρ - 1) / 4 * t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) := by
        have h1 : ρ - 2 - 1 = ρ - 3 := by ring
        have h2 : 1 / ρ - 2 - 1 = 1 / ρ - 3 := by ring
        have h_inner_pos' : (0 : ℝ) < (t ^ ρ + 1) / 2 := by positivity
        rw [h1, h2]
        simp only [Real.rpow_sub ht, Real.rpow_sub h_inner_pos']
        have ht' : 0 < t := ht
        field_simp [ne_of_gt ht', ne_of_gt h_inner_pos']
        simp [pow_succ, mul_assoc]
        ring_nf
        tauto
      exact h_deriv.congr_deriv h_eq
    exact h_tF2.deriv
  -- Similarly for F3 =ᶠ[𝓝 1] F4
  have hF3_deriv_eq_F4 : (fun t => deriv F3 t) =ᶠ[𝓝 (1 : ℝ)] F4 := by
    filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
    have ht' : 0 < t := ht
    have h_tρ_pos : 0 < (t : ℝ) ^ ρ := Real.rpow_pos_of_pos ht' ρ
    have h_inner_pos : 0 < ((t : ℝ) ^ ρ + 1) / 2 := by linarith
    have h_tF3 : HasDerivAt F3 (F4 t) t := by
      have hu : HasDerivAt (fun t : ℝ => t ^ (ρ - 3)) ((ρ - 3) * t ^ (ρ - 4)) t := by
        have := Real.hasDerivAt_rpow_const (p := ρ - 3) (Or.inl ht'.ne')
        convert this using 2 <;> ring_nf
      have hv_inner : HasDerivAt (fun t : ℝ => (t ^ ρ + 1) / 2) (ρ * t ^ (ρ - 1) / 2) t := by
        have h1 := Real.hasDerivAt_rpow_const (p := ρ) (Or.inl ht'.ne')
        have h2 := h1.add_const 1
        convert h2.div_const 2 using 1 <;> ring_nf
      have hv : HasDerivAt (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3))
          ((1 / ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 4) * (ρ * t ^ (ρ - 1) / 2)) t := by
        have := HasDerivAt.rpow hv_inner (hasDerivAt_const t (1 / ρ - 3)) (by linarith)
        convert this using 1 ; ring_nf
      have hw : HasDerivAt (fun t : ℝ => (ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ)
          ((ρ - 2) * (ρ * t ^ (ρ - 1) / 2) + (1 / 2 - ρ) * (ρ * t ^ (ρ - 1))) t := by
        have h1 := Real.hasDerivAt_rpow_const (p := ρ) (Or.inl ht'.ne')
        have h3 := (h1.add_const 1).div_const 2
        have h4 := h3.const_mul (ρ - 2)
        have h5 := h1.const_mul (1 / 2 - ρ)
        convert h4.add h5 using 1 <;> ring_nf
      have huvw : HasDerivAt (fun t : ℝ => t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ))
        (((ρ - 3) * t ^ (ρ - 4) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) +
          t ^ (ρ - 3) * ((1 / ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 4) * (ρ * t ^ (ρ - 1) / 2))) *
          ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) +
         t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * (ρ * t ^ (ρ - 1) / 2) + (1 / 2 - ρ) * (ρ * t ^ (ρ - 1)))) t := by
        convert (hu.mul hv).mul hw using 1 <;> ring_nf
      have h_const : HasDerivAt (fun x => (ρ - 1) / 4 * x ^ (ρ - 3) * ((x ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * ((x ^ ρ + 1) / 2) + (1 / 2 - ρ) * x ^ ρ))
        ((ρ - 1) / 4 * (((ρ - 3) * t ^ (ρ - 4) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) +
          t ^ (ρ - 3) * ((1 / ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 4) * (ρ * t ^ (ρ - 1) / 2))) *
          ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) +
         t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * (ρ * t ^ (ρ - 1) / 2) + (1 / 2 - ρ) * (ρ * t ^ (ρ - 1))))) t := by
        convert huvw.const_mul ((ρ - 1) / 4) using 1 <;> ring_nf
      have h_eq : (ρ - 1) / 4 * (((ρ - 3) * t ^ (ρ - 4) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) +
          t ^ (ρ - 3) * ((1 / ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 4) * (ρ * t ^ (ρ - 1) / 2))) *
          ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) +
         t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * (ρ * t ^ (ρ - 1) / 2) + (1 / 2 - ρ) * (ρ * t ^ (ρ - 1)))) = F4 t := by
        simp only [F4]
        have h_inner_pos' : (0 : ℝ) < (t ^ ρ + 1) / 2 := by positivity
        simp only [Real.rpow_sub ht', Real.rpow_sub h_inner_pos']
        field_simp [ht'.ne', h_inner_pos'.ne']
        ring_nf
      have h1 : F3 = (fun x => (ρ - 1) / 4 * x ^ (ρ - 3) * ((x ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * ((x ^ ρ + 1) / 2) + (1 / 2 - ρ) * x ^ ρ)) := rfl
      have h2 : (ρ - 1) / 4 * (((ρ - 3) * t ^ (ρ - 4) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) +
          t ^ (ρ - 3) * ((1 / ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 4) * (ρ * t ^ (ρ - 1) / 2))) *
          ((ρ - 2) * ((t ^ ρ + 1) / 2) + (1 / 2 - ρ) * t ^ ρ) +
         t ^ (ρ - 3) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 3) *
          ((ρ - 2) * (ρ * t ^ (ρ - 1) / 2) + (1 / 2 - ρ) * (ρ * t ^ (ρ - 1)))) = F4 t := h_eq
      rw [h2] at h_const
      rw [h1]
      exact h_const
    exact h_tF3.deriv
  -- Chain: iteratedDeriv 4 F 1 = deriv (deriv (deriv (deriv F))) 1
  show deriv (deriv (deriv (deriv F))) 1 = F4 1
  have heq1 : deriv F =ᶠ[𝓝 (1 : ℝ)] F1 := hF_deriv_eq_F1
  have heq2 : deriv F1 =ᶠ[𝓝 (1 : ℝ)] F2 := hF1_deriv_eq_F2
  have heq3 : deriv F2 =ᶠ[𝓝 (1 : ℝ)] F3 := hF2_deriv_eq_F3
  have heq4 : deriv F3 =ᶠ[𝓝 (1 : ℝ)] F4 := hF3_deriv_eq_F4
  have step1 : deriv (deriv F) 1 = deriv F1 1 := Filter.EventuallyEq.deriv_eq heq1
  have step2 : deriv (deriv F1) 1 = deriv F2 1 := Filter.EventuallyEq.deriv_eq heq2
  have step3 : deriv (deriv F2) 1 = deriv F3 1 := Filter.EventuallyEq.deriv_eq heq3
  have step4 : deriv (deriv F3) 1 = deriv F4 1 := Filter.EventuallyEq.deriv_eq heq4
  -- Need eventual equality of derivatives at each level
  -- We prove: if deriv F =ᶠ F1 on (0, ∞), then deriv (deriv F) =ᶠ deriv F1 on (0, ∞)
  have heq_double1 : deriv (deriv F) =ᶠ[𝓝 (1 : ℝ)] deriv F1 := heq1.deriv
  have heq_double2 : deriv (deriv F1) =ᶠ[𝓝 (1 : ℝ)] deriv F2 := heq2.deriv
  have heq_double3 : deriv (deriv F2) =ᶠ[𝓝 (1 : ℝ)] deriv F3 := heq3.deriv
  have heq_double4 : deriv (deriv F3) =ᶠ[𝓝 (1 : ℝ)] deriv F4 := heq4.deriv
  have heq_triple1 : deriv (deriv (deriv F)) =ᶠ[𝓝 (1 : ℝ)] deriv (deriv F1) := heq_double1.deriv
  have heq_triple2 : deriv (deriv (deriv F1)) =ᶠ[𝓝 (1 : ℝ)] deriv (deriv F2) := heq_double2.deriv
  have heq_triple3 : deriv (deriv (deriv F2)) =ᶠ[𝓝 (1 : ℝ)] deriv (deriv F3) := heq_double3.deriv
  have heq_triple4 : deriv (deriv (deriv F3)) =ᶠ[𝓝 (1 : ℝ)] deriv (deriv F4) := heq_double4.deriv
  have step1'' : deriv (deriv (deriv (deriv F))) 1 = deriv (deriv (deriv F1)) 1 := Filter.EventuallyEq.deriv_eq heq_triple1
  have step2' : deriv (deriv (deriv F1)) 1 = deriv (deriv F2) 1 := Filter.EventuallyEq.deriv_eq heq_double2
  have step3 : deriv (deriv F2) 1 = deriv F3 1 := Filter.EventuallyEq.deriv_eq heq3
  have step4 : deriv F3 1 = F4 1 := hderiv_F3
  calc deriv (deriv (deriv (deriv F))) 1
      = deriv (deriv (deriv F1)) 1 := step1''
    _ = deriv (deriv F2) 1 := step2'
    _ = deriv F3 1 := step3
    _ = F4 1 := step4

/-- Equality with an equal-weight CES mean forces the exponent from the
second derivative at the diagonal. -/
private lemma capponi_half_CES_forces_rho {ρ c : ℝ} (hρ : ρ ≠ 0)
    (hall : ∀ x y : ℝ, 0 < x → 0 < y →
      canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 x y =
        c * phiCES ρ (1 / 2 : ℝ) x y) :
    ρ = Real.sqrt 3 / 3 := by
  -- First, establish that phiCES ρ (1/2) t 1 = cesHalfSlice ρ t
  have hces_diag : ∀ t : ℝ, 0 < t → phiCES ρ (1 / 2) t 1 = cesHalfSlice ρ t := fun t ht => by
    simp [phiCES, cesHalfSlice, Real.one_rpow]
    ring_nf
  -- Second, establish that canon (Fcap (1/2) 1 1 1) 1 t 1 = capHalfSlice t
  have hcap_diag : ∀ t : ℝ, 0 < t → canon (Fcap (1 / 2) 1 1 1) 1 t 1 = capHalfSlice t := by
    intro t ht
    rw [canon_Fcap] <;> norm_num [capHalfSlice]
    · ring_nf
    · exact ht
  -- From the hypothesis, derive capHalfSlice t = c * cesHalfSlice ρ t for t > 0
  have h_eq : ∀ t : ℝ, 0 < t → capHalfSlice t = c * cesHalfSlice ρ t := by
    intro t ht
    rw [← hcap_diag t ht, ← hces_diag t ht]
    exact hall t 1 ht (by norm_num)
  -- At t = 1: capHalfSlice 1 = c * cesHalfSlice ρ 1
  have hc_val : capHalfSlice 1 = c * cesHalfSlice ρ 1 := h_eq 1 (by norm_num)
  -- Compute capHalfSlice 1 = (1 + sqrt(3)) / 2
  have hcap1 : capHalfSlice 1 = (1 + Real.sqrt 3) / 2 := by
    simp [capHalfSlice]
    norm_num
  -- Compute cesHalfSlice ρ 1 = 1
  have hces1 : cesHalfSlice ρ 1 = 1 := by
    simp [cesHalfSlice]
  -- Therefore c = (1 + sqrt(3)) / 2
  have hc : c = (1 + Real.sqrt 3) / 2 := by
    rw [hcap1, hces1] at hc_val
    linarith
  -- Differentiability of cesHalfSlice ρ at t > 0
  have hces_diff : ∀ t : ℝ, 0 < t → DifferentiableAt ℝ (cesHalfSlice ρ) t := by
    intro t ht
    unfold cesHalfSlice
    have h_inner : DifferentiableAt ℝ (fun t : ℝ => t ^ ρ) t := by
      have := Real.hasDerivAt_rpow_const (p := ρ) (Or.inl ht.ne')
      exact this.differentiableAt
    have h_add : DifferentiableAt ℝ (fun t : ℝ => t ^ ρ + 1) t := h_inner.add (differentiableAt_const 1)
    have h_div : DifferentiableAt ℝ (fun t : ℝ => (t ^ ρ + 1) / 2) t := h_add.div_const 2
    have h_pos : 0 < (t ^ ρ + 1) / 2 := by
      have h1 : 0 < t ^ ρ := Real.rpow_pos_of_pos ht ρ
      linarith
    have := DifferentiableAt.rpow h_div (differentiableAt_const (1 / ρ)) (by linarith)
    exact this
  -- Differentiability of deriv (cesHalfSlice ρ) at 1
  have h_diff_deriv : DifferentiableAt ℝ (deriv (cesHalfSlice ρ)) 1 := by
    -- We know the explicit formula for deriv (cesHalfSlice ρ) from cesHalfSlice_second_deriv
    have hderiv_formula : ∀ t : ℝ, 0 < t → deriv (cesHalfSlice ρ) t = 
        ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2 := by
      intro t ht
      unfold cesHalfSlice
      have hu : 0 < (t ^ ρ + 1) / 2 := by positivity
      have hinner : HasDerivAt (fun t => t ^ ρ + 1) (ρ * t ^ (ρ - 1)) t := by
        have h1 : HasDerivAt (fun t => t ^ ρ) (ρ * t ^ (ρ - 1)) t := Real.hasDerivAt_rpow_const (Or.inl ht.ne')
        exact h1.add_const 1
      have hu' : HasDerivAt (fun t => (t ^ ρ + 1) / 2) (ρ * t ^ (ρ - 1) / 2) t := hinner.div_const 2
      have h_outer : HasDerivAt (fun u => u ^ (1 / ρ)) ((1 / ρ) * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1)) ((t ^ ρ + 1) / 2) :=
        Real.hasDerivAt_rpow_const (Or.inl hu.ne')
      have hchain := h_outer.comp t hu'
      have hderiv_val : deriv (fun t => ((t ^ ρ + 1) / 2) ^ (1 / ρ)) t = 1 / ρ * ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * (ρ * t ^ (ρ - 1) / 2) := hchain.deriv
      rw [hderiv_val]
      field_simp
    -- The formula is differentiable at t = 1
    have h_local : ∀ᶠ t in nhds 1, deriv (cesHalfSlice ρ) t = 
        ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2 := by
      filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
      exact hderiv_formula t ht
    -- Now show the formula is differentiable at 1
    have h_diff_formula : DifferentiableAt ℝ 
        (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2) 1 := by
      apply DifferentiableAt.div_const
      apply DifferentiableAt.mul
      · apply DifferentiableAt.rpow
        · apply DifferentiableAt.div_const
          apply DifferentiableAt.add
          · exact (Real.hasDerivAt_rpow_const (p := ρ) (Or.inl (by norm_num : (1 : ℝ) ≠ 0))).differentiableAt
          · exact differentiableAt_const 1
        · exact differentiableAt_const _
        · norm_num
      · exact (Real.hasDerivAt_rpow_const (p := ρ - 1) (Or.inl (by norm_num : (1 : ℝ) ≠ 0))).differentiableAt
    exact h_diff_formula.congr_of_eventuallyEq h_local
  -- From the derivative relationship: iteratedDeriv 2 capHalfSlice 1 = c * iteratedDeriv 2 (cesHalfSlice ρ) 1
  have h_deriv_eq : iteratedDeriv 2 capHalfSlice 1 = c * iteratedDeriv 2 (cesHalfSlice ρ) 1 := by
    simp only [iteratedDeriv_succ', iteratedDeriv_zero]
    -- Functions are equal on a neighborhood of 1
    have h_fun_eq : (capHalfSlice : ℝ → ℝ) =ᶠ[nhds 1] (fun t => c * cesHalfSlice ρ t) := by
      filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
      exact h_eq t ht
    -- First derivatives are equal: deriv capHalfSlice =ᶠ[nhds 1] (fun t => c * deriv (cesHalfSlice ρ) t)
    have h_deriv1_eq : deriv capHalfSlice =ᶠ[nhds 1] deriv (fun t => c * cesHalfSlice ρ t) := h_fun_eq.deriv
    have h_deriv2_eq : deriv (fun t => c * cesHalfSlice ρ t) =ᶠ[nhds 1] (fun t => c * deriv (cesHalfSlice ρ) t) := by
      filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
      rw [deriv_const_mul _ (hces_diff t ht)]
    have h_deriv12_eq : deriv capHalfSlice =ᶠ[nhds 1] (fun t => c * deriv (cesHalfSlice ρ) t) := 
      h_deriv1_eq.trans h_deriv2_eq
    -- Second derivative: deriv (deriv capHalfSlice) =ᶠ[nhds 1] deriv (fun t => c * deriv (cesHalfSlice ρ) t)
    have h_deriv3_eq' : deriv (deriv capHalfSlice) =ᶠ[nhds 1] deriv (fun t => c * deriv (cesHalfSlice ρ) t) := 
      h_deriv12_eq.deriv
    -- Show differentiability of deriv (cesHalfSlice ρ) for t > 0
    have h_diff_deriv_t : ∀ t : ℝ, 0 < t → DifferentiableAt ℝ (deriv (cesHalfSlice ρ)) t := by
      intro t ht
      -- Use the explicit formula for deriv (cesHalfSlice ρ)
      have hderiv_formula : ∀ t : ℝ, 0 < t → deriv (cesHalfSlice ρ) t = 
          ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2 := by
        intro s hs
        unfold cesHalfSlice
        have hu : 0 < (s ^ ρ + 1) / 2 := by positivity
        have hinner : HasDerivAt (fun t => t ^ ρ + 1) (ρ * s ^ (ρ - 1)) s := by
          have h1 : HasDerivAt (fun t => t ^ ρ) (ρ * s ^ (ρ - 1)) s := Real.hasDerivAt_rpow_const (Or.inl hs.ne')
          exact h1.add_const 1
        have hu' : HasDerivAt (fun t => (t ^ ρ + 1) / 2) (ρ * s ^ (ρ - 1) / 2) s := hinner.div_const 2
        have h_outer : HasDerivAt (fun u => u ^ (1 / ρ)) ((1 / ρ) * ((s ^ ρ + 1) / 2) ^ (1 / ρ - 1)) ((s ^ ρ + 1) / 2) :=
          Real.hasDerivAt_rpow_const (Or.inl hu.ne')
        have hchain := h_outer.comp s hu'
        have hderiv_val : deriv (fun t => ((t ^ ρ + 1) / 2) ^ (1 / ρ)) s = 1 / ρ * ((s ^ ρ + 1) / 2) ^ (1 / ρ - 1) * (ρ * s ^ (ρ - 1) / 2) := hchain.deriv
        rw [hderiv_val]
        field_simp
      -- The formula function is differentiable at t
      have h_diff_formula_t : DifferentiableAt ℝ 
          (fun t : ℝ => ((t ^ ρ + 1) / 2) ^ (1 / ρ - 1) * t ^ (ρ - 1) / 2) t := by
        apply DifferentiableAt.div_const
        apply DifferentiableAt.mul
        · apply DifferentiableAt.rpow
          · apply DifferentiableAt.div_const
            apply DifferentiableAt.add
            · exact (Real.hasDerivAt_rpow_const (p := ρ) (Or.inl ht.ne')).differentiableAt
            · exact differentiableAt_const 1
          · exact differentiableAt_const _
          · positivity
        · exact (Real.hasDerivAt_rpow_const (p := ρ - 1) (Or.inl ht.ne')).differentiableAt
      exact h_diff_formula_t.congr_of_eventuallyEq (by
        filter_upwards [Ioi_mem_nhds ht] with s hs
        rw [hderiv_formula s hs])
    -- deriv (fun t => c * deriv (cesHalfSlice ρ) t) =ᶠ[nhds 1] (fun t => c * deriv (deriv (cesHalfSlice ρ)) t)
    have h_deriv4_eq : deriv (fun t => c * deriv (cesHalfSlice ρ) t) =ᶠ[nhds 1] (fun t => c * deriv (deriv (cesHalfSlice ρ)) t) := by
      filter_upwards [Ioi_mem_nhds zero_lt_one] with t ht
      rw [deriv_const_mul _ (h_diff_deriv_t t ht)]
    have h_deriv3_eq : deriv (deriv capHalfSlice) =ᶠ[nhds 1] (fun t => c * deriv (deriv (cesHalfSlice ρ)) t) := 
      h_deriv3_eq'.trans h_deriv4_eq
    have h_deriv3_eq2 : deriv (deriv capHalfSlice) 1 = deriv (fun t => c * deriv (cesHalfSlice ρ) t) 1 := 
      Filter.EventuallyEq.deriv_eq h_deriv12_eq
    rw [h_deriv3_eq2, deriv_const_mul]
    exact h_diff_deriv
  -- Use the known second derivatives
  rw [capHalfSlice_second_deriv, cesHalfSlice_second_deriv hρ] at h_deriv_eq
  -- Solve for ρ: -sqrt(3)/12 = c * (ρ - 1)/4 with c = (1 + sqrt(3))/2
  rw [hc] at h_deriv_eq
  -- Now h_deriv_eq: -sqrt(3)/12 = ((1 + sqrt(3))/2) * ((ρ - 1)/4)
  -- Simplify: -sqrt(3)/3 = (1 + sqrt(3)) * (ρ - 1)
  -- ρ = sqrt(3)/3
  have hsqrt3_pos : 0 < Real.sqrt 3 := Real.sqrt_pos.mpr (by norm_num : (0 : ℝ) < 3)
  have h1_sqrt3_pos : 0 < 1 + Real.sqrt 3 := by linarith
  field_simp at h_deriv_eq
  nlinarith [Real.sq_sqrt (by norm_num : (0 : ℝ) ≤ 3)]

/-- The exponent forced at the diagonal fails to represent the whole
interior Capponi slice. -/
private lemma capponi_half_not_CES_at_forced_rho :
    ¬ ∃ c : ℝ, 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 x y =
          c * phiCES (Real.sqrt 3 / 3) (1 / 2 : ℝ) x y := by
  rintro ⟨c, hc, hall⟩
  have hr : Real.sqrt 3 / 3 ≠ 0 := by positivity
  have hces_diag : ∀ t : ℝ, 0 < t →
      phiCES (Real.sqrt 3 / 3) (1 / 2) t 1 =
        cesHalfSlice (Real.sqrt 3 / 3) t := fun t ht => by
    simp [phiCES, cesHalfSlice, Real.one_rpow]
    ring_nf
  have hcap_diag : ∀ t : ℝ, 0 < t →
      canon (Fcap (1 / 2) 1 1 1) 1 t 1 = capHalfSlice t := by
    intro t ht
    rw [canon_Fcap] <;> norm_num [capHalfSlice]
    · ring_nf
    · exact ht
  have heq : ∀ t : ℝ, 0 < t →
      capHalfSlice t = c * cesHalfSlice (Real.sqrt 3 / 3) t := by
    intro t ht
    rw [← hcap_diag t ht, ← hces_diag t ht]
    exact hall t 1 ht (by norm_num)
  have hcval : c = (1 + Real.sqrt 3) / 2 := by
    have h := heq 1 (by norm_num)
    simp [capHalfSlice, cesHalfSlice] at h
    nlinarith
  have hfun : (capHalfSlice : ℝ → ℝ) =ᶠ[𝓝 1]
      (fun t => c * cesHalfSlice (Real.sqrt 3 / 3) t) := by
    filter_upwards [Ioi_mem_nhds (by norm_num : (0 : ℝ) < 1)] with t ht
    exact heq t ht
  have hfour := hfun.iteratedDeriv_eq 4
  rw [capHalfSlice_fourth_deriv,
    iteratedDeriv_const_mul_field,
    cesHalfSlice_fourth_deriv hr] at hfour
  rw [hcval] at hfour
  have hs : (Real.sqrt 3) ^ 2 = 3 := Real.sq_sqrt (by norm_num)
  have hspos : 0 < Real.sqrt 3 := Real.sqrt_pos.mpr (by norm_num)
  nlinarith

/-- The symmetric interior Capponi slice is not an equal-weight CES power
mean, even up to positive rescaling. -/
private lemma capponi_half_not_equal_weight_CES :
    ¬ ∃ ρ c : ℝ, ρ ≠ 0 ∧ 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 x y =
          c * phiCES ρ (1 / 2 : ℝ) x y := by
  rintro ⟨ρ, c, hρ, hc, hall⟩
  have hrho := capponi_half_CES_forces_rho hρ hall
  apply capponi_half_not_CES_at_forced_rho
  exact ⟨c, hc, by simpa [hrho] using hall⟩

/-- **A1 (verdict).** At the explicit interior witness `κ = 1/2` (and
`A = pA = pB = C = 1`), Capponi's canonical function is not a positive
scalar multiple of any guarded member of the full two-parameter CES family. -/
theorem canon_Fcap_not_CES :
    ¬ ∃ ρ ε c : ℝ, ρ ≠ 0 ∧ ε ∈ Ioo (0 : ℝ) 1 ∧ 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 x y = c * phiCES ρ ε x y := by
  rintro ⟨ρ, ε, c, hρ, hε, hc, hall⟩
  have hcap_symm : ∀ x y : ℝ, 0 < x → 0 < y →
      canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 x y =
        canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 y x := by
    intro x y hx hy
    rw [canon_Fcap (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      (by norm_num) hx hy]
    rw [canon_Fcap (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      (by norm_num) hy hx]
    congr 2 <;> ring
  have hces_symm : ∀ x y : ℝ, 0 < x → 0 < y →
      phiCES ρ ε x y = phiCES ρ ε y x := by
    intro x y hx hy
    have hxy := hall x y hx hy
    have hyx := hall y x hy hx
    rw [hcap_symm x y hx hy] at hxy
    rw [hyx] at hxy
    exact mul_left_cancel₀ hc.ne' hxy.symm
  have heps : ε = 1 / 2 := ces_weight_eq_half_of_symmetric hρ hε hces_symm
  apply capponi_half_not_equal_weight_CES
  exact ⟨ρ, c, hρ, hc, by simpa [heps] using hall⟩

/-- **B1.** The linear Capponi endpoint is exactly the `ρ = 1` CES slice,
up to a positive scalar. -/
theorem Fcap_zero_is_rho_one {A pA pB C : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C) :
    ∃ ε c : ℝ, ε ∈ Ioo (0 : ℝ) 1 ∧ 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap 0 A pA pB) C x y = c * phiCES 1 ε x y := by
  use pA / (pA + pB), A * (pA + pB) / C
  refine ⟨?_, ?_, ?_⟩
  · exact ⟨by positivity, by rw [div_lt_one (by positivity)]; linarith⟩
  · positivity
  · intro x y hx hy
    simp [phiCES_one]
    rw [canon_Fcap (left_mem_Icc.mpr (by norm_num : (0 : ℝ) ≤ 1)) hA hpA hpB hC hx hy]
    simp only [sub_zero, one_mul, mul_zero, zero_mul, add_zero]
    have hS : 0 ≤ A * (pA * x + pB * y) := by positivity
    rw [Real.sqrt_sq hS]
    field_simp
    ring

/-- **B2.** The constant-product Capponi endpoint is, up to a positive
scalar, the equal-share CES punctured limit as `ρ → 0`.  In particular this
does not evaluate the CES bracket at `ρ = 0`. -/
theorem Fcap_one_is_rho_zero_limit {A pA pB C : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C) :
    ∃ c : ℝ, 0 < c ∧ ∀ x y : ℝ, 0 < x → 0 < y →
      Tendsto (fun ρ : ℝ => c * phiCES ρ (1 / 2 : ℝ) x y)
        (𝓝[≠] (0 : ℝ)) (𝓝 (canon (Fcap 1 A pA pB) C x y)) := by
  use 1 / Real.sqrt C
  constructor
  · positivity
  · intro x y hx hy
    rw [canon_Fcap_one hA hpA hpB hC hx hy]
    have h := phiCES_zero_half_eq_geom hx hy
    convert h.const_mul (1 / Real.sqrt C) using 1
    ring

/-- **C1.** Thus no endpoint-matching map from Capponi's coordinate `κ` to a
CES exponent can represent every interior member (even allowing the CES
weight and positive scalar to vary with `κ`).  Endpoint values are stated
separately because `g 1 = 0` denotes the landed punctured limit, not an
unguarded evaluation of `phiCES 0`. -/
theorem kappa_not_reparam_of_rho :
    ¬ ∃ g ε c : ℝ → ℝ,
      g 0 = 1 ∧ g 1 = 0 ∧
      ∀ κ ∈ Ioo (0 : ℝ) 1,
        g κ ≠ 0 ∧ ε κ ∈ Ioo (0 : ℝ) 1 ∧ 0 < c κ ∧
        ∀ x y : ℝ, 0 < x → 0 < y →
          canon (Fcap κ 1 1 1) 1 x y = c κ * phiCES (g κ) (ε κ) x y := by
  rintro ⟨g, ε, c, -, -, h⟩
  apply canon_Fcap_not_CES
  obtain ⟨hρ, hε, hc, hall⟩ := h (1 / 2) (by norm_num)
  exact ⟨g (1 / 2), ε (1 / 2), c (1 / 2), hρ, hε, hc, hall⟩

end CapponiEmbed
