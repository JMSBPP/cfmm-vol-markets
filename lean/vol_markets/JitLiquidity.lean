import Mathlib
import vol_markets.FlairOptimization
import vol_markets.MevOptimization
import vol_markets.MevJointProgram
import vol_markets.VolInstrument

open scoped Topology

set_option maxHeartbeats 8000000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# JIT liquidity specification (J0--J8)

This file formalizes the JIT addendum to `VOLATILITY_INSTRUMENTS.md`, following
Capponi--Jia--Zhu, arXiv:2311.18164.  To avoid collision with `Real.pi`, the
arrival probability is named `πJ`.  CJZ's transfer rate is `ϑ`, informed-arrival
probability is `ϖ`, fee is `φ`, and deposit multiple is `mJ`.
-/

namespace JitLiquidity

/-! ## J1: swap primitives -/

/-- Stable-token output.  The price-adjusted depth `d̃` is absorbed into `d`. -/
noncomputable def deltaS (r d p : ℝ) : ℝ := p * d * r / (d + r)

/-- Risky-token output.  The price-adjusted depth `d̃` is absorbed into `d`. -/
noncomputable def deltaR (s d p : ℝ) : ℝ := d * s / (p * d + s)

lemma deltaS_homogeneous (a r d p : ℝ) (ha : 0 ≤ a) :
    deltaS (a * r) (a * d) p = a * deltaS r d p := by
  unfold deltaS
  field_simp

lemma deltaR_homogeneous (a s d p : ℝ) (ha : 0 ≤ a) :
    deltaR (a * s) (a * d) p = a * deltaR s d p := by
  unfold deltaR
  by_cases ha0 : a = 0
  · simp [ha0]
  · field_simp

lemma deltaS_strictMono_first (d p : ℝ) (hd : 0 < d) (hp : 0 < p) :
    StrictMonoOn (fun r => deltaS r d p) (Set.Ici 0) := by
  intro r₁ hr₁ r₂ hr₂ hlt
  simp only [deltaS]
  have hdenom₁ : 0 < d + r₁ := by nlinarith [hr₁.out]
  have hdenom₂ : 0 < d + r₂ := by nlinarith [hr₂.out]
  have hnum₁ : 0 ≤ p * d * r₁ := by nlinarith [mul_pos hd hp, hr₁.out]
  have hnum₂ : 0 ≤ p * d * r₂ := by nlinarith [mul_pos hd hp, hr₂.out]
  rw [div_lt_div_iff₀ hdenom₁ hdenom₂]
  nlinarith [mul_pos hd hp, mul_pos hd (mul_pos hd hp)]

lemma deltaR_strictMono_first (d p : ℝ) (hd : 0 < d) (hp : 0 < p) :
    StrictMonoOn (fun s => deltaR s d p) (Set.Ici 0) := by
  intro s₁ hs₁ s₂ hs₂ hlt
  simp only [deltaR]
  have hdenom₁ : 0 < p * d + s₁ := by nlinarith [hs₁.out]
  have hdenom₂ : 0 < p * d + s₂ := by nlinarith [hs₂.out]
  have hnum₁ : 0 ≤ d * s₁ := by nlinarith [hs₁.out]
  have hnum₂ : 0 ≤ d * s₂ := by nlinarith [hs₂.out]
  rw [div_lt_div_iff₀ hdenom₁ hdenom₂]
  nlinarith [mul_pos hd hp, mul_pos hd (mul_pos hd hp)]

/-- Strict concavity is stated on the positive domain; positive `d,p` are necessary. -/
lemma deltaS_strictConcave_first (d p : ℝ) (hd : 0 < d) (hp : 0 < p) :
    StrictConcaveOn ℝ (Set.Ici 0) (fun r => deltaS r d p) := by
  unfold deltaS StrictConcaveOn
  refine ⟨convex_Ici 0, ?_⟩
  intro x _ y _ hxy a b ha hb hab
  simp only [smul_eq_mul]
  -- The key is that 1/(d+t) is strictly convex, so -d/(d+t) is strictly concave
  -- t/(d+t) = 1 - d/(d+t) is strictly concave
  have hpxd : 0 < p * d := mul_pos hp hd
  have h_denom_pos : ∀ t ≥ 0, 0 < d + t := fun t ht => by linarith
  have h_denom_pos' : 0 < d + (a * x + b * y) := by
    have hx : 0 ≤ x := by assumption
    have hy : 0 ≤ y := by assumption
    nlinarith [mul_nonneg ha.le hx, mul_nonneg hb.le hy]
  -- Clear the denominators and prove algebraically
  have hx_nonneg : 0 ≤ x := by assumption
  have hy_nonneg : 0 ≤ y := by assumption
  -- We need to show: a * (p*d*x/(d+x)) + b * (p*d*y/(d+y)) < p*d*(a*x+b*y)/(d+a*x+b*y)
  -- Factor out p*d: a*x/(d+x) + b*y/(d+y) < (a*x+b*y)/(d+a*x+b*y)
  -- Equivalently: (a*x/(d+x) + b*y/(d+y)) * (d+a*x+b*y) < a*x+b*y
  have key : a * x / (d + x) + b * y / (d + y) < (a * x + b * y) / (d + a * x + b * y) := by
    have hdxy : 0 < d + x := h_denom_pos x hx_nonneg
    have hdyy : 0 < d + y := h_denom_pos y hy_nonneg
    have hda : 0 < d + a * x + b * y := by linarith
    rw [div_add_div _ _ (ne_of_gt hdxy) (ne_of_gt hdyy)]
    rw [div_lt_div_iff₀ (by positivity) (by positivity)]
    -- The difference RHS - LHS = d * (a*b) * (x-y)^2 > 0
    -- Check the polynomial identity using a + b = 1
    have hab' : b = 1 - a := by linarith
    have h_diff_eq : (a * x + b * y) * ((d + x) * (d + y)) -
                     (a * x * (d + y) + (d + x) * (b * y)) * (d + a * x + b * y) =
                     d * a * b * (x - y)^2 := by
      rw [hab']
      ring
    have hxy_ne : x - y ≠ 0 := sub_ne_zero.mpr hxy
    have hxy_sq : 0 < (x - y)^2 := by apply pow_two_pos_of_ne_zero; exact hxy_ne
    have hpos : 0 < d * a * b * (x - y)^2 := by positivity
    linarith [h_diff_eq.symm ▸ hpos]
  calc a * (p * d * x / (d + x)) + b * (p * d * y / (d + y))
      = p * d * (a * x / (d + x) + b * y / (d + y)) := by ring
    _ < p * d * ((a * x + b * y) / (d + a * x + b * y)) := by nlinarith
    _ = p * d * (a * x + b * y) / (d + (a * x + b * y)) := by ring

/-- Strict concavity is stated on the positive domain; positive `d,p` are necessary. -/
lemma deltaR_strictConcave_first (d p : ℝ) (hd : 0 < d) (hp : 0 < p) :
    StrictConcaveOn ℝ (Set.Ici 0) (fun s => deltaR s d p) := by
  unfold StrictConcaveOn deltaR
  constructor
  · exact convex_Ici 0
  · intro x hx y hy hxy a b ha hb hab
    simp only [smul_eq_mul]
    have hpxd : p * d > 0 := mul_pos hp hd
    have hpxdx : p * d + x > 0 := by linarith [Set.mem_Ici.mp hx]
    have hpxdy : p * d + y > 0 := by linarith [Set.mem_Ici.mp hy]
    have hpxdaby : p * d + (a * x + b * y) > 0 := by
      have : a * x + b * y ≥ 0 := by nlinarith [Set.mem_Ici.mp hx, Set.mem_Ici.mp hy]
      linarith
    have key : a * (d * x / (p * d + x)) + b * (d * y / (p * d + y)) <
               d * (a * x + b * y) / (p * d + (a * x + b * y)) := by
      have hdx : d * p + x > 0 := by linarith
      have hdy : d * p + y > 0 := by linarith
      have hdaby : a * x + d * p + b * y > 0 := by nlinarith [Set.mem_Ici.mp hx, Set.mem_Ici.mp hy]
      have hne_x : p * d + x ≠ 0 := by linarith
      have hne_y : p * d + y ≠ 0 := by linarith
      have hne_ab : p * d + (a * x + b * y) ≠ 0 := by linarith
      field_simp [hne_x, hne_y, hne_ab]
      rw [lt_div_iff₀ (by linarith : d * p + (a * x + b * y) > 0)]
      -- Goal: (a * x * (d * p + y) + (d * p + x) * b * y) * (d * p + (a * x + b * y)) < (d * p + x) * (d * p + y) * (a * x + b * y)
      -- Expand both sides and show the inequality
      have key : (d * p + x) * (d * p + y) * (a * x + b * y) -
                 (a * x * (d * p + y) + (d * p + x) * b * y) * (d * p + (a * x + b * y)) > 0 := by
        -- LHS - RHS = (C + ax + by)(C² + bCx + aCy) where C = d*p
        have hC : d * p > 0 := mul_pos hd hp
        have hCaxby : d * p + a * x + b * y > 0 := by nlinarith [Set.mem_Ici.mp hx, Set.mem_Ici.mp hy]
        have hC2bxCaCy : (d * p)^2 + b * (d * p) * x + a * (d * p) * y > 0 := by
          have hx0 : x ≥ 0 := Set.mem_Ici.mp hx
          have hy0 : y ≥ 0 := Set.mem_Ici.mp hy
          have h1 : b * (d * p) * x ≥ 0 := mul_nonneg (mul_nonneg (le_of_lt hb) (le_of_lt hC)) hx0
          have h2 : a * (d * p) * y ≥ 0 := mul_nonneg (mul_nonneg (le_of_lt ha) (le_of_lt hC)) hy0
          linarith [sq_pos_of_pos hC]
        -- The factorization: LHS - RHS = abdpx(x-y)²
        have hfactor : (d * p + x) * (d * p + y) * (a * x + b * y) -
                       (a * x * (d * p + y) + (d * p + x) * b * y) * (d * p + (a * x + b * y)) =
                       a * b * (d * p) * (x - y)^2 := by
          have hab' : a = 1 - b := by linarith
          rw [hab']
          ring
        rw [hfactor]
        exact mul_pos (mul_pos (mul_pos ha hb) hC) (sq_pos_of_ne_zero (sub_ne_zero.mpr hxy))
      linarith
    exact key

lemma deltaS_monotone_depth (r p : ℝ) (hr : 0 ≤ r) (hp : 0 ≤ p) :
    MonotoneOn (fun d => deltaS r d p) (Set.Ioi 0) := by
  unfold deltaS MonotoneOn
  intro x hx y hy hxy
  simp only [Set.mem_Ioi] at hx hy
  by_cases hr0 : r = 0
  · simp [hr0]
  · by_cases hp0 : p = 0
    · simp [hp0]
    · rw [div_le_div_iff₀ (by linarith : x + r > 0) (by linarith : y + r > 0)]
      nlinarith [mul_nonneg hr hr, mul_nonneg (sq_nonneg r) hp]

lemma deltaR_monotone_depth (s p : ℝ) (hs : 0 ≤ s) (hp : 0 < p) :
    MonotoneOn (fun d => deltaR s d p) (Set.Ioi 0) := by
  intro d₁ hd₁ d₂ hd₂ hlt
  unfold deltaR
  by_cases hs0 : s = 0
  · simp [hs0]
  · have hp_d₁ : 0 < p * d₁ := mul_pos hp (Set.mem_Ioi.mp hd₁)
    have hp_d₂ : 0 < p * d₂ := mul_pos hp (Set.mem_Ioi.mp hd₂)
    rw [div_le_div_iff₀ (by linarith : p * d₁ + s > 0) (by linarith : p * d₂ + s > 0)]
    have hs_pos : 0 < s := lt_of_le_of_ne hs (Ne.symm hs0)
    have hs2 : 0 < s ^ 2 := sq_pos_of_pos hs_pos
    nlinarith

/-! ## J2: JIT best response and third pole -/

noncomputable def dJstar (φ dP qR : ℝ) : ℝ :=
  (φ * dP * (dP + qR) + Real.sqrt (qR * (1 + φ) * dP * (dP + qR))) /
    (qR - φ * dP)

noncomputable def MJfun (φ dP qR dJ : ℝ) : ℝ :=
  (1 + φ) * dP / (dP + dJ) ^ 2 - (dP + qR) / (dP + dJ + qR) ^ 2

lemma dJstar_pos (φ dP qR : ℝ) (hφ : 0 ≤ φ) (hdP : 0 < dP)
    (hq : φ * dP < qR) : 0 < dJstar φ dP qR := by
  unfold dJstar
  have hqR : qR > 0 := by nlinarith
  have hnum : φ * dP * (dP + qR) + Real.sqrt (qR * (1 + φ) * dP * (dP + qR)) > 0 := by
    have : Real.sqrt (qR * (1 + φ) * dP * (dP + qR)) > 0 := Real.sqrt_pos.mpr (by positivity)
    linarith [mul_nonneg (mul_nonneg hφ (le_of_lt hdP)) (le_of_lt (by linarith : dP + qR > 0))]
  have hdenom : qR - φ * dP > 0 := by linarith
  exact div_pos hnum hdenom

/-- The requested root assertion is false: the published expression as transcribed
is missing a factor `qR` under the square root.  This exact in-domain witness
records the obstruction rather than asserting an unsound theorem. -/
lemma dJstar_not_root_witness : MJfun 0 1 2 (dJstar 0 1 2) ≠ 0 := by
  norm_num [MJfun, dJstar]
  have hs : Real.sqrt 6 ≠ 0 := ne_of_gt (Real.sqrt_pos.2 (by norm_num))
  have hs2 : (Real.sqrt 6) ^ 2 = 6 := Real.sq_sqrt (by norm_num)
  field_simp
  nlinarith

/-- Corrected positive-root expression; compared with `dJstar`, the radicand has
an additional factor `qR`. -/
noncomputable def dJroot (φ dP qR : ℝ) : ℝ :=
  (φ * dP * (dP + qR) +
    Real.sqrt (qR ^ 2 * (1 + φ) * dP * (dP + qR))) / (qR - φ * dP)

lemma dJroot_root (φ dP qR : ℝ) (hφ : 0 ≤ φ) (hdP : 0 < dP)
    (hq : φ * dP < qR) : MJfun φ dP qR (dJroot φ dP qR) = 0 := by
  unfold MJfun dJroot
  have hdenom_pos : qR - φ * dP > 0 := by linarith
  have hqR_pos : qR > 0 := by nlinarith
  have hdPqR_pos : dP + qR > 0 := by nlinarith
  have hqR_sq_pos : qR ^ 2 * (1 + φ) * dP * (dP + qR) ≥ 0 := by positivity
  set sqrtPart := Real.sqrt (qR ^ 2 * (1 + φ) * dP * (dP + qR)) with h_sqrtPart
  have h_sqrtPart_sq : sqrtPart ^ 2 = qR ^ 2 * (1 + φ) * dP * (dP + qR) := Real.sq_sqrt hqR_sq_pos
  -- Need to show dP + dJroot ≠ 0 and dP + dJroot + qR ≠ 0
  have hdJroot_pos : (φ * dP * (dP + qR) + sqrtPart) / (qR - φ * dP) > 0 := by
    apply div_pos _ hdenom_pos
    have h1 : φ * dP * (dP + qR) ≥ 0 := by positivity
    have h2 : sqrtPart ≥ 0 := Real.sqrt_nonneg _
    by_cases hφ0 : φ = 0
    · subst hφ0; norm_num
      have : qR ^ 2 * dP * (dP + qR) > 0 := by positivity
      convert Real.sqrt_pos.mpr this using 2
      ring
    · have hφpos : φ > 0 := lt_of_le_of_ne hφ (Ne.symm hφ0)
      have : φ * dP * (dP + qR) > 0 := by positivity
      linarith
  have hdP_dJ_ne_zero : dP + (φ * dP * (dP + qR) + sqrtPart) / (qR - φ * dP) ≠ 0 := by linarith
  have hdP_dJ_qR_ne_zero : dP + (φ * dP * (dP + qR) + sqrtPart) / (qR - φ * dP) + qR ≠ 0 := by linarith
  have hnum_pos : dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) > 0 := by
    have : dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) = dP * qR * (1 + φ) + sqrtPart := by ring
    rw [this]
    have h1 : dP * qR * (1 + φ) > 0 := by positivity
    have h2 : sqrtPart ≥ 0 := Real.sqrt_nonneg _
    linarith
  have hnum_ne_zero : dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) ≠ 0 := ne_of_gt hnum_pos
  have hnum2_pos : dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) + qR * (qR - φ * dP) > 0 := by
    have : dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) + qR * (qR - φ * dP) = 
           qR * (dP + qR) + sqrtPart := by ring
    rw [this]
    have h1 : qR * (dP + qR) > 0 := by positivity
    have h2 : sqrtPart ≥ 0 := Real.sqrt_nonneg _
    linarith
  have hnum2_ne_zero : dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) + qR * (qR - φ * dP) ≠ 0 := ne_of_gt hnum2_pos
  field_simp [hnum_ne_zero, hnum2_ne_zero]
  -- The goal has complex expressions; let's prove the key identity needed
  -- First, let's prove both parts simplify correctly
  have key : (1 + φ) * dP * (dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart) + qR * (qR - φ * dP)) ^ 2 = 
             (dP + qR) * (dP * (qR - φ * dP) + (φ * dP * (dP + qR) + sqrtPart)) ^ 2 := by
    -- Use nlinarith with the sqrtPart squared fact
    -- Key insight: expand both sides and use sqrtPart^2 = qR^2 * (1 + φ) * dP * (dP + qR)
    nlinarith [h_sqrtPart_sq, sq_nonneg sqrtPart]
  simp [key]

/-- Positive-root uniqueness for the corrected root.  The pole-domain hypotheses
also ensure all denominators are nonzero. -/
lemma dJroot_unique_positive_root (φ dP qR dJ : ℝ) (hφ : 0 ≤ φ) (hdP : 0 < dP)
    (hq : φ * dP < qR) (hdJ : 0 < dJ) (hroot : MJfun φ dP qR dJ = 0) :
    dJ = dJroot φ dP qR := by
  have hqR : qR > 0 := by nlinarith
  have hroot_eq : MJfun φ dP qR (dJroot φ dP qR) = 0 := dJroot_root φ dP qR hφ hdP hq
  have hdJroot_pos : dJroot φ dP qR > 0 := by
    unfold dJroot
    have hdenom : qR - φ * dP > 0 := by linarith
    have hnum : φ * dP * (dP + qR) + Real.sqrt (qR ^ 2 * (1 + φ) * dP * (dP + qR)) > 0 := by
      by_cases hφ0 : φ = 0
      · subst hφ0; norm_num; positivity
      · have hφpos : φ > 0 := lt_of_le_of_ne hφ (Ne.symm hφ0)
        positivity
    exact div_pos hnum hdenom
  -- MJfun is strictly antitone on positive dJ
  -- MJfun(dJ) = 0 means (1+φ)*dP * (dP+dJ+qR)² = (dP+qR) * (dP+dJ)²
  -- This is a quadratic equation in dJ with at most 2 roots, and exactly one positive root
  have hroot_eq : MJfun φ dP qR (dJroot φ dP qR) = 0 := dJroot_root φ dP qR hφ hdP hq
  -- Both dJ and dJroot are positive roots, so we need uniqueness
  -- MJfun = 0 iff (1+φ)*dP * (dP+dJ+qR)² = (dP+qR) * (dP+dJ)²
  have eq1 : MJfun φ dP qR dJ = 0 ↔ 
    (1 + φ) * dP * (dP + dJ + qR) ^ 2 = (dP + qR) * (dP + dJ) ^ 2 := by
    unfold MJfun
    constructor
    · intro h
      have hdP_dJ : dP + dJ > 0 := by linarith
      have hdP_dJ_qR : dP + dJ + qR > 0 := by linarith
      field_simp at h
      linarith
    · intro h
      have hdP_dJ : dP + dJ > 0 := by linarith
      have hdP_dJ_qR : dP + dJ + qR > 0 := by linarith
      field_simp
      ring_nf
      linarith [h]
  have eq2 : MJfun φ dP qR (dJroot φ dP qR) = 0 ↔ 
    (1 + φ) * dP * (dP + dJroot φ dP qR + qR) ^ 2 = (dP + qR) * (dP + dJroot φ dP qR) ^ 2 := by
    unfold MJfun
    constructor
    · intro h
      have hdP_dJ : dP + dJroot φ dP qR > 0 := by linarith
      have hdP_dJ_qR : dP + dJroot φ dP qR + qR > 0 := by linarith
      field_simp at h ⊢
      linarith
    · intro h
      have hdP_dJ : dP + dJroot φ dP qR > 0 := by linarith
      have hdP_dJ_qR : dP + dJroot φ dP qR + qR > 0 := by linarith
      field_simp
      linarith [h]
  -- The equation (1+φ)*dP*(dP+dJ+qR)² = (dP+qR)*(dP+dJ)² expands to a quadratic
  -- Let's derive both equations
  have hdJ_eq : (1 + φ) * dP * (dP + dJ + qR) ^ 2 = (dP + qR) * (dP + dJ) ^ 2 := (eq1.mp hroot)
  have hdJroot_eq : (1 + φ) * dP * (dP + dJroot φ dP qR + qR) ^ 2 = (dP + qR) * (dP + dJroot φ dP qR) ^ 2 := (eq2.mp hroot_eq)
  -- The quadratic is: (φ*dP - qR)*x² + 2*φ*dP*(dP+qR)*x + dP*(dP+qR)*(φ*(dP+qR) + qR) = 0
  -- Since φ*dP - qR < 0 and the other coefficients are ≥ 0, there's at most one positive root
  -- We prove uniqueness by showing if x, y > 0 satisfy the equation, then x = y
  have key : ∀ x y : ℝ, 0 < x → 0 < y → 
    (1 + φ) * dP * (dP + x + qR) ^ 2 = (dP + qR) * (dP + x) ^ 2 →
    (1 + φ) * dP * (dP + y + qR) ^ 2 = (dP + qR) * (dP + y) ^ 2 → x = y := by
    intro x y hx hy hx_eq hy_eq
    -- Subtract the two equations and factor
    have hsub : (1 + φ) * dP * ((dP + x + qR) ^ 2 - (dP + y + qR) ^ 2) = 
                (dP + qR) * ((dP + x) ^ 2 - (dP + y) ^ 2) := by linear_combination hx_eq - hy_eq
    -- Factor using a² - b² = (a-b)(a+b)
    have h1 : (dP + x + qR) ^ 2 - (dP + y + qR) ^ 2 = (x - y) * (2*dP + x + y + 2*qR) := by ring
    have h2 : (dP + x) ^ 2 - (dP + y) ^ 2 = (x - y) * (2*dP + x + y) := by ring
    rw [h1, h2] at hsub
    -- Factor out (x - y)
    have hfactor : (x - y) * ((1 + φ) * dP * (2*dP + x + y + 2*qR) - (dP + qR) * (2*dP + x + y)) = 0 := by
      linear_combination hsub
    -- If x ≠ y, then the coefficient must be zero
    by_contra hne
    have hxy_diff : x ≠ y := hne
    have hcoeff_zero : (1 + φ) * dP * (2*dP + x + y + 2*qR) = (dP + qR) * (2*dP + x + y) := by
      have hxy : x - y ≠ 0 := sub_ne_zero.mpr hxy_diff
      rcases mul_eq_zero.mp hfactor with hxy0 | hcoeff0
      · exact absurd hxy0 hxy
      · linarith
    -- From hcoeff_zero: 2*(1+φ)*dP*qR = (qR - φ*dP) * (2*dP + x + y)
    have hcoeff_exp : 2 * (1 + φ) * dP * qR = (qR - φ * dP) * (2*dP + x + y) := by linarith
    -- Now derive a contradiction from x, y > 0 and both satisfying the quadratic
    -- Product of roots x*y = c/a where a = φ*dP - qR < 0 and c > 0, so x*y < 0
    -- But x, y > 0 implies x*y > 0, contradiction
    have ha : φ * dP - qR < 0 := by linarith
    -- From hx_eq, derive a relationship
    -- (1+φ)*dP*(dP+x+qR)² = (dP+qR)*(dP+x)²
    -- Expand both sides
    have hx_expand : (1 + φ) * dP * (dP + x + qR) ^ 2 = 
                    (1 + φ) * dP * (dP + qR) ^ 2 + 2 * (1 + φ) * dP * (dP + qR) * x + (1 + φ) * dP * x ^ 2 := by ring
    have hy_expand : (1 + φ) * dP * (dP + y + qR) ^ 2 = 
                    (1 + φ) * dP * (dP + qR) ^ 2 + 2 * (1 + φ) * dP * (dP + qR) * y + (1 + φ) * dP * y ^ 2 := by ring
    have rhs_x : (dP + qR) * (dP + x) ^ 2 = (dP + qR) * dP ^ 2 + 2 * (dP + qR) * dP * x + (dP + qR) * x ^ 2 := by ring
    have rhs_y : (dP + qR) * (dP + y) ^ 2 = (dP + qR) * dP ^ 2 + 2 * (dP + qR) * dP * y + (dP + qR) * y ^ 2 := by ring
    -- From hx_eq and hx_expand, rhs_x
    have hx_quad : (1 + φ) * dP * (dP + qR) ^ 2 + 2 * (1 + φ) * dP * (dP + qR) * x + (1 + φ) * dP * x ^ 2 = 
                   (dP + qR) * dP ^ 2 + 2 * (dP + qR) * dP * x + (dP + qR) * x ^ 2 := by rw [hx_expand, rhs_x] at hx_eq; exact hx_eq
    have hy_quad : (1 + φ) * dP * (dP + qR) ^ 2 + 2 * (1 + φ) * dP * (dP + qR) * y + (1 + φ) * dP * y ^ 2 = 
                   (dP + qR) * dP ^ 2 + 2 * (dP + qR) * dP * y + (dP + qR) * y ^ 2 := by rw [hy_expand, rhs_y] at hy_eq; exact hy_eq
    -- Rearrange to standard quadratic form: a*x² + b*x + c = 0
    -- where a = φ*dP - qR, b = 2*φ*dP*(dP+qR), c = dP*(dP+qR)*(φ*(dP+qR) + qR)
    have hx_quad_form : (φ * dP - qR) * x ^ 2 + 2 * φ * dP * (dP + qR) * x + dP * (dP + qR) * (φ * (dP + qR) + qR) = 0 := by linarith
    have hy_quad_form : (φ * dP - qR) * y ^ 2 + 2 * φ * dP * (dP + qR) * y + dP * (dP + qR) * (φ * (dP + qR) + qR) = 0 := by linarith
    -- Multiply hx_quad_form by y and hy_quad_form by x
    have hx_mul_y : (φ * dP - qR) * x ^ 2 * y + 2 * φ * dP * (dP + qR) * x * y + dP * (dP + qR) * (φ * (dP + qR) + qR) * y = 0 := by linear_combination hx_quad_form * y
    have hy_mul_x : (φ * dP - qR) * y ^ 2 * x + 2 * φ * dP * (dP + qR) * y * x + dP * (dP + qR) * (φ * (dP + qR) + qR) * x = 0 := by linear_combination hy_quad_form * x
    -- Subtract to get (φ*dP - qR) * x * y * (x - y) + c * (y - x) = 0
    -- i.e., (x - y) * [(φ*dP - qR) * x * y - c] = 0
    have hprod : (φ * dP - qR) * x * y = dP * (dP + qR) * (φ * (dP + qR) + qR) := by
      have hdiff : (φ * dP - qR) * x ^ 2 * y - (φ * dP - qR) * y ^ 2 * x + 
                   dP * (dP + qR) * (φ * (dP + qR) + qR) * y - 
                   dP * (dP + qR) * (φ * (dP + qR) + qR) * x = 0 := by linarith
      have hfactored : (x - y) * ((φ * dP - qR) * x * y - dP * (dP + qR) * (φ * (dP + qR) + qR)) = 0 := by linarith [sq_nonneg (x - y)]
      rcases mul_eq_zero.mp hfactored with hxy0 | hcoeff0
      · exact absurd hxy0 (sub_ne_zero.mpr hxy_diff)
      · linarith
    -- Since RHS > 0 and φ*dP - qR < 0, we need x*y < 0, but x, y > 0 implies x*y > 0
    have hrhs_pos : dP * (dP + qR) * (φ * (dP + qR) + qR) > 0 := by positivity
    have hxy_neg : x * y < 0 := by nlinarith
    have hxy_pos : x * y > 0 := mul_pos hx hy
    linarith
  exact key dJ (dJroot φ dP qR) hdJ hdJroot_pos hdJ_eq hdJroot_eq

/-- The third program pole, approached from the right. -/
lemma dJstar_pole (φ dP : ℝ) (hφ : 0 ≤ φ) (hdP : 0 < dP) :
    Filter.Tendsto (fun qR => dJstar φ dP qR) (𝓝[>] (φ * dP)) Filter.atTop := by
  unfold dJstar
  -- Define numerator and denominator
  let num := fun qR => φ * dP * (dP + qR) + Real.sqrt (qR * (1 + φ) * dP * (dP + qR))
  let den := fun qR => qR - φ * dP
  -- The denominator tends to 0+
  have hden : Filter.Tendsto den (𝓝[>] (φ * dP)) (𝓝[>] 0) := by
    apply Filter.Tendsto.inf
    · exact Continuous.tendsto' (by continuity : Continuous den) _ _ (by simp [den])
    · apply Filter.le_principal_iff.mpr
      simp [den]
  -- The numerator is continuous
  have hnum_cont : Continuous num := by continuity
  -- Case split: when φ > 0, the numerator at the pole is positive
  -- When φ = 0, we need a different argument
  by_cases hφ0 : φ = 0
  · -- Case φ = 0: num qR = sqrt(qR * dP * (dP + qR)) for qR > 0
    simp [hφ0] at *
    -- Simplify dJstar when φ = 0
    suffices h : Filter.Tendsto (fun qR => Real.sqrt (qR * dP * (dP + qR)) / qR) (𝓝[>] 0) Filter.atTop by
      exact h
    -- For qR > 0, sqrt(qR * dP * (dP + qR)) / qR = sqrt(dP * (dP + qR) / qR)
    -- ≥ sqrt(dP² / qR) = dP / sqrt(qR)
    -- And dP / sqrt(qR) → +∞ as qR → 0+
    -- First, show dP / sqrt(qR) → +∞
    have hpos : ∀ᶠ x in 𝓝[>] (0 : ℝ), 0 < x := by
      apply Filter.Eventually.mono (Ioo_mem_nhdsGT (by linarith : (0 : ℝ) < 1))
      intro x hx
      linarith [hx.1]
    have hsqrt_tendsto : Filter.Tendsto (fun qR => (Real.sqrt qR)⁻¹) (𝓝[>] (0 : ℝ)) Filter.atTop := by
      have hsqrts_to_nhds0 : Filter.Tendsto (fun qR : ℝ => Real.sqrt qR) (𝓝[>] (0 : ℝ)) (𝓝 (0 : ℝ)) := by
        have : Filter.Tendsto Real.sqrt (𝓝 (0 : ℝ)) (𝓝 (Real.sqrt 0)) := Real.continuous_sqrt.continuousAt
        simp [Real.sqrt_zero] at this
        exact this.mono_left nhdsWithin_le_nhds
      have hsqrts_to_Ioi : Filter.Tendsto (fun qR : ℝ => Real.sqrt qR) (𝓝[>] (0 : ℝ)) (𝓝[>] 0) := by
        exact Filter.tendsto_inf.2 ⟨hsqrts_to_nhds0,
          Filter.tendsto_principal.2 (hpos.mono fun x hx => Set.mem_Ioi.mpr (Real.sqrt_pos.mpr hx))⟩
      exact tendsto_inv_nhdsGT_zero.comp hsqrts_to_Ioi
    have hlower_bound : Filter.Tendsto (fun qR => dP / Real.sqrt qR) (𝓝[>] 0) Filter.atTop := by
      exact hsqrt_tendsto.const_mul_atTop hdP
    -- Show the expression is eventually ≥ dP / √qR
    rw [Filter.tendsto_atTop] at *
    intro b
    have hs := hlower_bound b
    filter_upwards [hs, hpos] with qR hsqR hqR
    -- Need: b ≤ √(qR * dP * (dP + qR)) / qR
    -- We have: b ≤ dP / √qR
    -- It suffices: dP / √qR ≤ √(qR * dP * (dP + qR)) / qR
    apply hsqR.trans
    -- Show: dP / √qR ≤ √(qR * dP * (dP + qR)) / qR
    have hqR_sqrt : 0 < Real.sqrt qR := Real.sqrt_pos.mpr hqR
    rw [div_le_div_iff₀ (by positivity : 0 < Real.sqrt qR) (by positivity : 0 < qR)]
    -- Need: dP * qR ≤ √(qR * dP * (dP + qR)) * √qR
    -- Square both sides to verify the inequality
    have hsq : (dP * qR) ^ 2 ≤ (Real.sqrt (qR * dP * (dP + qR)) * Real.sqrt qR) ^ 2 := by
      simp only [mul_pow]
      rw [Real.sq_sqrt (by positivity : 0 ≤ qR * dP * (dP + qR)), Real.sq_sqrt (le_of_lt hqR)]
      ring_nf
      nlinarith [sq_nonneg dP, sq_nonneg qR, mul_pos hdP hqR]
    have hlhs_nn : 0 ≤ dP * qR := by positivity
    have hrhs_nn : 0 ≤ Real.sqrt (qR * dP * (dP + qR)) * Real.sqrt qR := by positivity
    have hsq' := Real.sqrt_le_sqrt hsq
    rw [Real.sqrt_sq hlhs_nn, Real.sqrt_sq hrhs_nn] at hsq'
    exact hsq'
  · -- Case φ > 0: num(φ * dP) > 0, so num/den → +∞
    have hφ_pos : 0 < φ := lt_of_le_of_ne hφ (Ne.symm hφ0)
    have hφdP_pos : 0 < φ * dP := mul_pos hφ_pos hdP
    have hnum_at_pole : 0 < num (φ * dP) := by
      simp [num]
      have h1 : 0 ≤ φ * dP * (dP + φ * dP) := mul_nonneg (le_of_lt hφdP_pos) (by linarith)
      have h2 : 0 < φ * dP * (1 + φ) * dP * (dP + φ * dP) := by
        apply mul_pos; apply mul_pos; apply mul_pos hφdP_pos
        · linarith
        · exact hdP
        · linarith
      exact add_pos_of_nonneg_of_pos h1 (Real.sqrt_pos.mpr h2)
    -- num is continuous, so it's eventually bounded below by a positive constant
    have hnum_bound : ∀ᶠ qR in 𝓝[>] (φ * dP), num qR > num (φ * dP) / 2 := by
      have h1 := hnum_cont.continuousAt.eventually (Ioi_mem_nhds (by linarith : num (φ * dP) / 2 < num (φ * dP)))
      exact h1.filter_mono nhdsWithin_le_nhds
    -- Get 1/den → +∞
    have hinv_den : Filter.Tendsto (fun qR => (den qR)⁻¹) (𝓝[>] (φ * dP)) Filter.atTop :=
      tendsto_inv_nhdsGT_zero.comp hden
    -- num/den ≥ (num(φ*dP)/2) * (1/den) eventually
    have hc : (0 : ℝ) < num (φ * dP) / 2 := half_pos hnum_at_pole
    have hprod : Filter.Tendsto (fun qR => (num (φ * dP) / 2) * (den qR)⁻¹) (𝓝[>] (φ * dP)) Filter.atTop :=
      Filter.Tendsto.const_mul_atTop hc hinv_den
    -- We show num/den ≥ c * (1/den) eventually, which → +∞
    -- Use comparison: if f → +∞ and g ≥ f eventually, then g → +∞
    apply Filter.tendsto_atTop.mpr
    intro s
    -- Get that s ≤ (num (φ * dP) / 2) * (den qR)⁻¹ eventually from hprod
    rw [Filter.tendsto_atTop] at hprod
    have hs_le : ∀ᶠ qR in 𝓝[>] (φ * dP), s ≤ (num (φ * dP) / 2) * (den qR)⁻¹ := hprod s
    -- Get den > 0 eventually
    have hden_pos : ∀ᶠ qR in 𝓝[>] (φ * dP), 0 < den qR := by
      simp [den]
      exact Filter.eventually_of_mem (Ioo_mem_nhdsGT (by linarith : φ * dP < φ * dP + 1)) fun x hx => by linarith [hx.1]
    -- Combine with hnum_bound
    filter_upwards [hs_le, hnum_bound, hden_pos] with qR hsqR hqR_num hqR_den
    rw [div_eq_mul_inv]
    exact hsqR.trans (mul_le_mul_of_nonneg_right hqR_num.le (inv_nonneg.mpr (le_of_lt hqR_den)))

/-- Honest no-root statement below the pole.  Positivity of `qR` is necessary for the
financial domain; the endpoint `qR = φ*dP` is included. -/
lemma MJfun_no_positive_root_below_pole (φ dP qR dJ : ℝ) (hφ : 0 ≤ φ)
    (hdP : 0 < dP) (hqR : 0 < qR) (hq : qR ≤ φ * dP) (hdJ : 0 < dJ) :
    MJfun φ dP qR dJ ≠ 0 := by
  unfold MJfun
  -- First fraction has larger numerator and smaller denominator
  have hnum : (1 + φ) * dP ≥ dP + qR := by nlinarith
  have hdenom1 : dP + dJ > 0 := by linarith
  have hdenom2 : dP + dJ + qR > dP + dJ := by linarith
  have hdenom1_sq : (dP + dJ) ^ 2 > 0 := by positivity
  have hdenom2_sq : (dP + dJ + qR) ^ 2 > (dP + dJ) ^ 2 := by nlinarith
  have hnum2_pos : dP + qR > 0 := by linarith
  -- First term ≥ (dP+qR)/(dP+dJ)^2 > (dP+qR)/(dP+dJ+qR)^2
  have h1 : (1 + φ) * dP / (dP + dJ) ^ 2 ≥ (dP + qR) / (dP + dJ) ^ 2 := by
    apply div_le_div_of_nonneg_right hnum (le_of_lt hdenom1_sq)
  have h2 : (dP + qR) / (dP + dJ) ^ 2 > (dP + qR) / (dP + dJ + qR) ^ 2 := by
    apply div_lt_div_of_pos_left hnum2_pos (by positivity) hdenom2_sq
  linarith

/-! ## J3: uninformed depth fixed point and fourth pole -/

noncomputable def MTfun (μ πJ φ : ℝ) : ℝ :=
  (1 - πJ) / (1 + μ) ^ 2 +
    πJ * (2 + μ) * Real.sqrt ((1 + φ) * (1 + μ)) / (2 * (1 + μ) ^ 2)

lemma MTfun_strictAnti (πJ φ : ℝ) (hπ0 : 0 ≤ πJ) (hπ1 : πJ ≤ 1) (hφ : 0 ≤ φ) :
    StrictAntiOn (fun μ => MTfun μ πJ φ) (Set.Ici 0) := by
  -- Rewrite MTfun with common denominator
  have hMT_eq : ∀ μ ≥ 0, MTfun μ πJ φ = (2 * (1 - πJ) + πJ * (2 + μ) * Real.sqrt ((1 + φ) * (1 + μ))) / (2 * (1 + μ) ^ 2) := by
    intro μ _
    unfold MTfun
    field_simp
  -- Use the fact that MTfun can be rewritten and apply calculus
  -- MTfun μ = [2(1-πJ) + πJ(2+μ)√((1+φ)(1+μ))] / [2(1+μ)²]
  -- Both terms are strictly decreasing, so sum is strictly decreasing
  intro μ₁ hμ₁ μ₂ hμ₂ hlt
  simp only [Set.mem_Ici] at hμ₁ hμ₂
  simp only [hMT_eq μ₁ hμ₁, hMT_eq μ₂ hμ₂]
  -- Need to show: N(μ₂)/D(μ₂) < N(μ₁)/D(μ₁)
  -- Cross-multiply: N(μ₂) * D(μ₁) < N(μ₁) * D(μ₂)
  have hdenom1_pos : 0 < 2 * (1 + μ₁) ^ 2 := by positivity
  have hdenom2_pos : 0 < 2 * (1 + μ₂) ^ 2 := by positivity
  rw [div_lt_div_iff₀ hdenom2_pos hdenom1_pos]
  -- Let's define key quantities
  set c := 1 + φ with hc_def
  have hc_pos : 0 < c := by linarith
  set s₁ := Real.sqrt (c * (1 + μ₁)) with hs₁_def
  set s₂ := Real.sqrt (c * (1 + μ₂)) with hs₂_def
  have hs₁_nonneg : 0 ≤ s₁ := Real.sqrt_nonneg _
  have hs₂_nonneg : 0 ≤ s₂ := Real.sqrt_nonneg _
  have hs₁_pos : 0 < s₁ := Real.sqrt_pos.mpr (mul_pos hc_pos (by linarith : 0 < 1 + μ₁))
  have hs₂_pos : 0 < s₂ := Real.sqrt_pos.mpr (mul_pos hc_pos (by linarith : 0 < 1 + μ₂))
  -- s₁ < s₂ because μ₁ < μ₂ and sqrt is strictly increasing
  have hs_lt : s₁ < s₂ := by
    rw [hs₁_def, hs₂_def]
    apply Real.sqrt_lt_sqrt (by nlinarith : 0 ≤ c * (1 + μ₁))
    nlinarith
  -- Define m₁ = 1 + μ₁, m₂ = 1 + μ₂
  set m₁ := 1 + μ₁ with hm₁_def
  set m₂ := 1 + μ₂ with hm₂_def
  have hm₁_pos : 0 < m₁ := by linarith
  have hm₂_pos : 0 < m₂ := by linarith
  have hm_lt : m₁ < m₂ := by linarith
  -- s₁² = c * m₁, s₂² = c * m₂
  have hs₁_sq : s₁ ^ 2 = c * m₁ := by rw [hs₁_def]; exact Real.sq_sqrt (by nlinarith : 0 ≤ c * m₁)
  have hs₂_sq : s₂ ^ 2 = c * m₂ := by rw [hs₂_def]; exact Real.sq_sqrt (by nlinarith : 0 ≤ c * m₂)
  -- Define x₁ = m₁ + 1, x₂ = m₂ + 1 (which are 2 + μ₁ and 2 + μ₂)
  set x₁ := m₁ + 1 with hx₁_def
  set x₂ := m₂ + 1 with hx₂_def
  have hx₁_pos : 0 < x₁ := by linarith
  have hx₂_pos : 0 < x₂ := by linarith
  have hx_lt : x₁ < x₂ := by linarith
  -- The goal in terms of x₁, x₂: (2*(1-πJ) + πJ*x₂*s₂) * (2*m₁²) < (2*(1-πJ) + πJ*x₁*s₁) * (2*m₂²)
  -- Factor out 2: (2*(1-πJ) + πJ*x₂*s₂) * m₁² < (2*(1-πJ) + πJ*x₁*s₁) * m₂²
  suffices h : (2 * (1 - πJ) + πJ * x₂ * s₂) * m₁ ^ 2 < (2 * (1 - πJ) + πJ * x₁ * s₁) * m₂ ^ 2 by
    linarith
  -- Let a = 2*(1-πJ) and k = πJ
  set a := 2 * (1 - πJ) with ha_def
  set k := πJ with hk_def
  have ha_nonneg : 0 ≤ a := by linarith
  have hk_nonneg : 0 ≤ k := hπ0
  -- Goal: (a + k * x₂ * s₂) * m₁² < (a + k * x₁ * s₁) * m₂²
  -- Rearranging: a*(m₁² - m₂²) + k*(x₂*s₂*m₁² - x₁*s₁*m₂²) < 0
  have h1 : m₁ ^ 2 < m₂ ^ 2 := by nlinarith
  have h_m_sq_neg : a * (m₁ ^ 2 - m₂ ^ 2) ≤ 0 := mul_nonpos_of_nonneg_of_nonpos ha_nonneg (by linarith)
  -- Need: x₂ * s₂ * m₁² < x₁ * s₁ * m₂²
  -- x₁ = m₁ + 1, x₂ = m₂ + 1, s₁² = c*m₁, s₂² = c*m₂
  -- So: (m₂+1) * s₂ * m₁² < (m₁+1) * s₁ * m₂²
  -- Squaring both sides (both positive): (m₂+1)² * s₂² * m₁⁴ < (m₁+1)² * s₁² * m₂⁴
  -- Substitute: (m₂+1)² * c*m₂ * m₁⁴ < (m₁+1)² * c*m₁ * m₂⁴
  -- Simplify: (m₂+1)² * m₂ * m₁⁴ < (m₁+1)² * m₁ * m₂⁴
  -- Divide by m₁*m₂: (m₂+1)² * m₁³ < (m₁+1)² * m₂³
  -- Prove the polynomial inequality
  have hpoly : (m₂ + 1) ^ 2 * m₁ ^ 3 < (m₁ + 1) ^ 2 * m₂ ^ 3 := by
    have h_diff : (m₁ + 1) ^ 2 * m₂ ^ 3 - (m₂ + 1) ^ 2 * m₁ ^ 3 =
                  (m₂ - m₁) * (m₁ ^ 2 * m₂ ^ 2 + 2 * m₁ * m₂ ^ 2 + 2 * m₁ ^ 2 * m₂ + m₂ ^ 2 + m₂ * m₁ + m₁ ^ 2) := by ring
    have hbracket_pos : m₁ ^ 2 * m₂ ^ 2 + 2 * m₁ * m₂ ^ 2 + 2 * m₁ ^ 2 * m₂ + m₂ ^ 2 + m₂ * m₁ + m₁ ^ 2 > 0 := by positivity
    have h_diff_pos : (m₁ + 1) ^ 2 * m₂ ^ 3 - (m₂ + 1) ^ 2 * m₁ ^ 3 > 0 := by
      rw [h_diff]; exact mul_pos (by linarith : m₂ - m₁ > 0) hbracket_pos
    linarith
  -- x₂ = m₂ + 1 = x₂, x₁ = m₁ + 1 = x₁
  -- hpoly says: x₂² * m₁³ < x₁² * m₂³
  have hxpoly : x₂ ^ 2 * m₁ ^ 3 < x₁ ^ 2 * m₂ ^ 3 := by simpa [hx₁_def, hx₂_def] using hpoly
  -- Now show: x₂ * s₂ * m₁² < x₁ * s₁ * m₂²
  -- Squaring both sides: (x₂ * s₂ * m₁²)² < (x₁ * s₁ * m₂²)²
  -- i.e., x₂² * s₂² * m₁⁴ < x₁² * s₁² * m₂⁴
  -- Using s₂² = c * m₂ and s₁² = c * m₁:
  -- x₂² * c * m₂ * m₁⁴ < x₁² * c * m₁ * m₂⁴
  -- Divide by c * m₁ * m₂ (positive): x₂² * m₁³ < x₁² * m₂³ (which is hxpoly)
  have hxs_lt : x₂ * s₂ * m₁ ^ 2 < x₁ * s₁ * m₂ ^ 2 := by
    have lhs_pos : 0 < x₂ * s₂ * m₁ ^ 2 := by positivity
    have rhs_pos : 0 < x₁ * s₁ * m₂ ^ 2 := by positivity
    have lhs_sq : (x₂ * s₂ * m₁ ^ 2) ^ 2 = x₂ ^ 2 * s₂ ^ 2 * m₁ ^ 4 := by ring
    have rhs_sq : (x₁ * s₁ * m₂ ^ 2) ^ 2 = x₁ ^ 2 * s₁ ^ 2 * m₂ ^ 4 := by ring
    have hsq_eq1 : x₂ ^ 2 * s₂ ^ 2 * m₁ ^ 4 = x₂ ^ 2 * (c * m₂) * m₁ ^ 4 := by rw [hs₂_sq]
    have hsq_eq2 : x₁ ^ 2 * s₁ ^ 2 * m₂ ^ 4 = x₁ ^ 2 * (c * m₁) * m₂ ^ 4 := by rw [hs₁_sq]
    have hsq_simp : x₂ ^ 2 * (c * m₂) * m₁ ^ 4 < x₁ ^ 2 * (c * m₁) * m₂ ^ 4 := by
      have hc_pos' : 0 < c := hc_pos
      have h1 : x₂ ^ 2 * m₂ * m₁ ^ 4 < x₁ ^ 2 * m₁ * m₂ ^ 4 := by
        have h2 : x₂ ^ 2 * m₁ ^ 3 < x₁ ^ 2 * m₂ ^ 3 := hxpoly
        nlinarith [sq_nonneg m₁, sq_nonneg m₂, mul_pos hm₁_pos hm₂_pos]
      have h2 : 0 < c * (x₁ ^ 2 * m₁ * m₂ ^ 4) := by positivity
      nlinarith
    nlinarith [sq_nonneg (x₂ * s₂ * m₁ ^ 2), sq_nonneg (x₁ * s₁ * m₂ ^ 2)]
  -- Final goal: (a + k * x₂ * s₂) * m₁² < (a + k * x₁ * s₁) * m₂²
  -- Expand: a * m₁² + k * x₂ * s₂ * m₁² < a * m₂² + k * x₁ * s₁ * m₂²
  -- Rearrange: a * (m₁² - m₂²) + k * (x₂ * s₂ * m₁² - x₁ * s₁ * m₂²) < 0
  have h_diff_neg : x₂ * s₂ * m₁ ^ 2 - x₁ * s₁ * m₂ ^ 2 < 0 := by linarith
  -- Case analysis: either k = 0 or k > 0
  by_cases hk : k = 0
  · -- When k = 0, term2 = 0, so we need a * m₁² < a * m₂²
    -- a = 2*(1 - 0) = 2 > 0, and m₁² < m₂²
    simp [hk]
    have ha_pos : a > 0 := by simp [ha_def]; linarith
    nlinarith
  · -- When k > 0, term2 < 0, so sum < 0
    have hk_pos : 0 < k := lt_of_le_of_ne hk_nonneg (Ne.symm hk)
    have h_term2_neg : k * (x₂ * s₂ * m₁ ^ 2 - x₁ * s₁ * m₂ ^ 2) < 0 := by nlinarith
    nlinarith

lemma MTfun_zero_gt_target (πJ φ ζU : ℝ) (hπ0 : 0 ≤ πJ) (hπ1 : πJ ≤ 1)
    (hφ : 0 ≤ φ) (hζ : 1 + φ < ζU) :
    (1 + φ) / ζU < MTfun 0 πJ φ := by
  have hζU_pos : 0 < ζU := by linarith
  have h1pφ_pos : 0 < 1 + φ := by linarith
  -- Compute MTfun 0 πJ φ
  simp [MTfun]
  -- Goal: (1 + φ) / ζU < (1 - πJ) + πJ * sqrt(1 + φ)
  have htarget_lt_1 : (1 + φ) / ζU < 1 := by
    rw [div_lt_one hζU_pos]
    linarith
  have hsqrt_ge_1 : Real.sqrt (1 + φ) ≥ 1 := by
    rw [ge_iff_le, Real.le_sqrt] <;> linarith
  have hMTfun_ge_1 : (1 - πJ) + πJ * Real.sqrt (1 + φ) ≥ 1 := by
    nlinarith
  linarith

lemma MTfun_tendsto_zero (πJ φ : ℝ) :
    Filter.Tendsto (fun μ => MTfun μ πJ φ) Filter.atTop (𝓝 0) := by
  unfold MTfun
  have h1 : Filter.Tendsto (fun μ => (1 - πJ) / (1 + μ) ^ 2) Filter.atTop (𝓝 0) := by
    have h_lim : Filter.Tendsto (fun μ : ℝ => (1 + μ) ^ 2) Filter.atTop Filter.atTop := by
      rw [Filter.tendsto_atTop_atTop]
      intro b
      use max b 1
      intro a ha
      have ha1 : a ≥ 1 := le_trans (le_max_right _ _) ha
      calc b ≤ a := le_trans (le_max_left _ _) ha
        _ ≤ 1 + a := by linarith
        _ ≤ (1 + a) ^ 2 := by nlinarith
    exact Filter.Tendsto.div_atTop (tendsto_const_nhds) h_lim
  have h2 : Filter.Tendsto (fun μ => πJ * (2 + μ) * Real.sqrt ((1 + φ) * (1 + μ)) / (2 * (1 + μ) ^ 2)) Filter.atTop (𝓝 0) := by
    by_cases h_nonneg : 0 ≤ 1 + φ
    · -- Case: 1 + φ ≥ 0
      -- sqrt((1+φ)*(1+μ)) = sqrt(1+φ) * sqrt(1+μ) when both are nonneg
      have h_sqrt_eq : ∀ μ ≥ 0, Real.sqrt ((1 + φ) * (1 + μ)) = Real.sqrt (1 + φ) * Real.sqrt (1 + μ) := by
        intro μ hμ
        exact Real.sqrt_mul h_nonneg _
      -- Rewrite the expression using the equality
      have h_rewrite : ∀ μ ≥ 0,
        πJ * (2 + μ) * Real.sqrt ((1 + φ) * (1 + μ)) / (2 * (1 + μ) ^ 2) =
        πJ * Real.sqrt (1 + φ) * (2 + μ) * Real.sqrt (1 + μ) / (2 * (1 + μ) ^ 2) := by
        intro μ hμ
        rw [h_sqrt_eq μ hμ]
        ring
      -- Rewrite: we need (2+μ)*sqrt(1+μ)/(1+μ)^2 → 0
      -- Note: (2+μ)*sqrt(1+μ)/(1+μ)^2 = (2+μ)/(1+μ)^(3/2)
      have h_simplify : ∀ μ > 0,
        πJ * Real.sqrt (1 + φ) * (2 + μ) * Real.sqrt (1 + μ) / (2 * (1 + μ) ^ 2) =
        (πJ * Real.sqrt (1 + φ) / 2) * ((2 + μ) / (1 + μ) ^ (3/2 : ℝ)) := by
        intro μ hμ
        have h1 : (1 + μ) ^ (3/2 : ℝ) = (1 + μ) * Real.sqrt (1 + μ) := by
          rw [show (3/2 : ℝ) = 1 + 1/2 by norm_num, Real.rpow_add (by linarith : 0 < 1 + μ)]
          simp [Real.sqrt_eq_rpow]
        rw [h1]
        have h_sqrt_sq : Real.sqrt (1 + μ) ^ 2 = 1 + μ := Real.sq_sqrt (by linarith : 0 ≤ 1 + μ)
        field_simp
        rw [h_sqrt_sq]
      have h_lim : Filter.Tendsto (fun μ : ℝ => (2 + μ) / (1 + μ) ^ (3/2 : ℝ)) Filter.atTop (𝓝 0) := by
        -- For μ ≥ 1: (2 + μ) / (1 + μ)^(3/2) ≤ 3 / μ^(1/2)
        have h_bound : ∀ μ ≥ 1, (2 + μ) / (1 + μ) ^ (3/2 : ℝ) ≤ 3 / Real.sqrt μ := by
          intro μ hμ
          have hμ_pos : 0 < μ := by linarith
          have h1μ_pos : 0 < 1 + μ := by linarith
          have hμ_sqrt : 0 < Real.sqrt μ := Real.sqrt_pos.mpr hμ_pos
          -- (2 + μ) ≤ 3μ for μ ≥ 1
          have hnum : 2 + μ ≤ 3 * μ := by linarith
          -- (1 + μ)^(3/2) ≥ μ^(3/2)
          have hdenom : (1 + μ) ^ (3/2 : ℝ) ≥ μ ^ (3/2 : ℝ) := by
            apply Real.rpow_le_rpow (by linarith) (by linarith) (by norm_num : (0 : ℝ) ≤ 3/2)
          -- μ^(3/2) = μ * sqrt(μ)
          have h_sqrt_eq : μ ^ (3/2 : ℝ) = μ * Real.sqrt μ := by
            rw [show (3/2 : ℝ) = 1 + 1/2 by norm_num, Real.rpow_add hμ_pos]
            norm_num [Real.sqrt_eq_rpow]
          -- Chain the inequalities
          calc (2 + μ) / (1 + μ) ^ (3/2 : ℝ)
              ≤ (3 * μ) / (1 + μ) ^ (3/2 : ℝ) := by gcongr
            _ ≤ (3 * μ) / μ ^ (3/2 : ℝ) := by gcongr
            _ = 3 / Real.sqrt μ := by rw [h_sqrt_eq]; field_simp
        -- Now use squeeze theorem
        have h_nonneg : ∀ μ : ℝ, μ ≥ 0 → 0 ≤ (2 + μ) / (1 + μ) ^ (3/2 : ℝ) := by
          intro μ hμ
          apply div_nonneg <;> have := Real.rpow_nonneg (by linarith : 0 ≤ 1 + μ) (3/2 : ℝ) <;> linarith
        have h_upper : Filter.Tendsto (fun μ : ℝ => 3 / Real.sqrt μ) Filter.atTop (𝓝 0) := by
          have h_sqrt_atTop : Filter.Tendsto Real.sqrt Filter.atTop Filter.atTop := by
            rw [Filter.tendsto_atTop_atTop]
            intro b
            use b^2
            intro a ha
            exact Real.le_sqrt_of_sq_le ha
          exact Filter.Tendsto.div_atTop tendsto_const_nhds h_sqrt_atTop
        exact tendsto_of_tendsto_of_tendsto_of_le_of_le' tendsto_const_nhds h_upper
          (Filter.eventually_atTop.mpr ⟨0, h_nonneg⟩)
          (Filter.eventually_atTop.mpr ⟨1, h_bound⟩)
      exact Filter.Tendsto.congr' (by filter_upwards [Filter.eventually_gt_atTop 0] with μ hμ; rw [h_rewrite μ (le_of_lt hμ), h_simplify μ hμ]) (by simpa using h_lim.const_mul (πJ * Real.sqrt (1 + φ) / 2))
    · -- Case: 1 + φ < 0, so sqrt((1+φ)*(1+μ)) = 0 for μ ≥ 0
      push_neg at h_nonneg
      have h_zero : ∀ μ ≥ 0, Real.sqrt ((1 + φ) * (1 + μ)) = 0 := by
        intro μ hμ
        apply Real.sqrt_eq_zero_of_nonpos
        have : 1 + μ > 0 := by linarith
        nlinarith
      have h_eq : ∀ μ ≥ 0, πJ * (2 + μ) * Real.sqrt ((1 + φ) * (1 + μ)) / (2 * (1 + μ) ^ 2) = 0 := by
        intro μ hμ
        simp [h_zero μ hμ]
      exact tendsto_const_nhds.congr' (by filter_upwards [Filter.eventually_ge_atTop 0] with μ hμ; rw [h_eq μ hμ])
  simpa using h1.add h2

/-- Existence and uniqueness of equilibrium depth.  `ζU > 1+φ` is the sufficient-side
condition used to put the target strictly between the endpoint and limiting values. -/
lemma existsUnique_MTfun_solution (πJ φ ζU : ℝ) (hπ0 : 0 ≤ πJ) (hπ1 : πJ ≤ 1)
    (hφ : 0 ≤ φ) (hζ : 1 + φ < ζU) :
    ∃! μ : ℝ, 0 < μ ∧ MTfun μ πJ φ = (1 + φ) / ζU := by
  -- The target value
  let tgt := (1 + φ) / ζU
  -- MTfun at 0 is strictly greater than target
  have h0 : tgt < MTfun 0 πJ φ := MTfun_zero_gt_target πJ φ ζU hπ0 hπ1 hφ hζ
  -- MTfun tends to 0 as μ → ∞
  have htend : Filter.Tendsto (fun μ => MTfun μ πJ φ) Filter.atTop (𝓝 0) := MTfun_tendsto_zero πJ φ
  -- Since tgt > 0 and MTfun → 0, eventually MTfun < tgt
  have htgt_pos : 0 < tgt := by
    unfold tgt
    apply div_pos (by linarith : 0 < 1 + φ)
    linarith
  -- There exists some M where MTfun M < tgt
  have hM : ∃ M : ℝ, 0 ≤ M ∧ MTfun M πJ φ < tgt := by
    have := htend.eventually (gt_mem_nhds htgt_pos)
    rw [Filter.eventually_atTop] at this
    obtain ⟨M, hM⟩ := this
    exact ⟨max M 0, le_max_right _ _, hM _ (le_max_left _ _)⟩
  obtain ⟨M, hM0, hMtgt⟩ := hM
  -- MTfun is continuous on [0, M]
  have hMTcont : ContinuousOn (fun μ => MTfun μ πJ φ) (Set.Icc 0 M) := by
    have h1 : ContinuousOn (fun μ => (1 - πJ) / (1 + μ) ^ 2) (Set.Icc 0 M) := by
      apply ContinuousOn.div continuousOn_const
      · apply ContinuousOn.pow
        apply ContinuousOn.add continuousOn_const continuousOn_id
      · intro x hx
        have h : 1 + x > 0 := by linarith [hx.1]
        exact (pow_ne_zero 2 h.ne')
    have h2 : ContinuousOn (fun μ => πJ * (2 + μ) * Real.sqrt ((1 + φ) * (1 + μ)) / (2 * (1 + μ) ^ 2)) (Set.Icc 0 M) := by
      apply ContinuousOn.div
      · exact ContinuousOn.mul (ContinuousOn.mul continuousOn_const (continuousOn_const.add continuousOn_id))
          (Real.continuous_sqrt.comp_continuousOn (continuousOn_const.mul (continuousOn_const.add continuousOn_id)))
      · apply ContinuousOn.mul continuousOn_const
        apply ContinuousOn.pow
        apply ContinuousOn.add continuousOn_const continuousOn_id
      · intro x hx
        have h : 1 + x > 0 := by linarith [hx.1]
        exact mul_ne_zero two_ne_zero (pow_ne_zero 2 h.ne')
    exact h1.add h2
  -- Apply intermediate value theorem
  -- MTfun 0 > tgt and MTfun M < tgt, so there exists μ ∈ [0, M] with MTfun μ = tgt
  have h_ivt := intermediate_value_Icc' hM0 hMTcont
  have htgt_in_range : tgt ∈ Set.Icc (MTfun M πJ φ) (MTfun 0 πJ φ) := by
    constructor <;> linarith
  obtain ⟨μ, hμ_mem, hμ_eq⟩ := h_ivt htgt_in_range
  -- Since MTfun is strictly decreasing and MTfun 0 > tgt = MTfun μ, we have μ > 0
  have hμ_pos : 0 < μ := by
    by_contra hμ_nonpos
    push_neg at hμ_nonpos
    have hμ_eq0 : μ = 0 := le_antisymm hμ_nonpos hμ_mem.1
    rw [hμ_eq0] at hμ_eq
    linarith
  -- Existence: we have μ > 0 with MTfun μ = tgt
  use μ
  constructor
  · exact ⟨hμ_pos, hμ_eq⟩
  -- Uniqueness: MTfun is strictly decreasing
  intro y ⟨hy_pos, hy_eq⟩
  -- y must be in [0, M] since MTfun y = tgt > MTfun M
  have hy_lt_M : y < M := by
    by_contra hy_ge_M
    push_neg at hy_ge_M
    have hle : MTfun y πJ φ ≤ MTfun M πJ φ := by
      have hanti := MTfun_strictAnti πJ φ hπ0 hπ1 hφ
      by_cases heq : y = M
      · rw [heq]
      · have hlt : M < y := lt_of_le_of_ne hy_ge_M (Ne.symm heq)
        have hMy : M ∈ Set.Ici (0 : ℝ) := by simp; linarith
        have hy0 : y ∈ Set.Ici (0 : ℝ) := by simp; linarith
        exact le_of_lt (hanti hMy hy0 hlt)
    linarith
  have hy_mem : y ∈ Set.Icc 0 M := ⟨le_of_lt hy_pos, le_of_lt hy_lt_M⟩
  have hμ_mem' : μ ∈ Set.Icc 0 M := hμ_mem
  -- Both have MTfun = tgt
  have heq_val : MTfun y πJ φ = MTfun μ πJ φ := by rw [hy_eq]; exact hμ_eq.symm
  -- By strict anti-monotonicity, y = μ
  have hanti := MTfun_strictAnti πJ φ hπ0 hπ1 hφ
  have hy0 : y ∈ Set.Ici (0 : ℝ) := by simp; linarith
  have hμ0 : μ ∈ Set.Ici (0 : ℝ) := by simp; linarith
  exact (hanti.eq_iff_eq hy0 hμ0 |>.mp heq_val).symm

/-- Algebraic threshold equivalence, conditional on the fixed-point relation. -/
lemma MTfun_solution_threshold (μ πJ φ ζU : ℝ) (hμ : 0 ≤ μ)
    (hπ0 : 0 ≤ πJ) (hπ1 : πJ ≤ 1) (hφ : 0 ≤ φ) (hζ : 0 < ζU)
    (hsol : MTfun μ πJ φ = (1 + φ) / ζU) :
    μ > φ ↔ ζU > 2 * (1 + φ) ^ 3 / (2 + πJ * φ * (3 + φ)) := by
  have hφ_pos : 0 < 1 + φ := by linarith
  have hφ2 : 0 < (1 + φ) ^ 2 := sq_pos_of_pos hφ_pos
  have h2pφ : 0 < 2 + πJ * φ * (3 + φ) := by positivity
  -- Compute MTfun φ πJ φ
  have hMT_at_phi : MTfun φ πJ φ = (2 + πJ * φ * (3 + φ)) / (2 * (1 + φ) ^ 2) := by
    unfold MTfun
    have hsqrt : Real.sqrt ((1 + φ) ^ 2) = 1 + φ := Real.sqrt_sq hφ_pos.le
    field_simp
    rw [hsqrt]
    ring
  -- Use strict anti property: μ > φ ↔ MTfun μ πJ φ < MTfun φ πJ φ
  have hanti := MTfun_strictAnti πJ φ hπ0 hπ1 hφ
  have hφ_mem : φ ∈ Set.Ici (0 : ℝ) := by simp [hφ]
  have hμ_mem : μ ∈ Set.Ici (0 : ℝ) := by simp [hμ]
  -- μ > φ ↔ MTfun μ πJ φ < MTfun φ πJ φ
  have h_equiv : μ > φ ↔ MTfun μ πJ φ < MTfun φ πJ φ := by
    rw [StrictAntiOn] at hanti
    constructor
    · intro h
      apply hanti hφ_mem hμ_mem h
    · intro h
      by_contra hle
      push_neg at hle
      cases hle.eq_or_lt with
      | inl heq => rw [heq] at h; exact lt_irrefl _ h
      | inr hlt => exact lt_asymm h (hanti hμ_mem hφ_mem hlt)
  rw [hsol, hMT_at_phi] at h_equiv
  rw [h_equiv]
  -- Now need: (1 + φ) / ζU < (2 + πJ * φ * (3 + φ)) / (2 * (1 + φ) ^ 2) ↔ ζU > 2 * (1 + φ) ^ 3 / (2 + πJ * φ * (3 + φ))
  have hζU_pos : 0 < ζU := hζ
  have hφ1_pos : 0 < (1 + φ) := hφ_pos
  have h2phi2_pos : 0 < 2 * (1 + φ) ^ 2 := by positivity
  -- Cross multiply: (1 + φ) / ζU < RHS ↔ (1 + φ) * (2 * (1 + φ)^2) < ζU * (2 + πJ * φ * (3 + φ))
  rw [div_lt_div_iff₀ hζU_pos h2phi2_pos]
  rw [gt_iff_lt, div_lt_iff₀ h2pφ]
  constructor <;> intro <;> linarith

noncomputable def mJ (μ φ : ℝ) : ℝ :=
  (φ * (1 + μ) + μ * Real.sqrt ((1 + φ) * (1 + μ))) / (μ - φ)

lemma mJ_pos (μ φ : ℝ) (hφ : 0 ≤ φ) (hμ : φ < μ) : 0 < mJ μ φ := by
  unfold mJ
  apply div_pos
  · -- numerator is positive
    have hμ_pos : 0 < μ := by linarith
    have h1μ_pos : 0 < 1 + μ := by linarith
    have h1φ_pos : 0 < 1 + φ := by linarith
    have hprod_pos : 0 < (1 + φ) * (1 + μ) := mul_pos h1φ_pos h1μ_pos
    have hsqrt_pos : 0 < Real.sqrt ((1 + φ) * (1 + μ)) := Real.sqrt_pos.mpr hprod_pos
    have term1_nonneg : 0 ≤ φ * (1 + μ) := mul_nonneg hφ (le_of_lt h1μ_pos)
    have term2_pos : 0 < μ * Real.sqrt ((1 + φ) * (1 + μ)) := mul_pos hμ_pos hsqrt_pos
    linarith
  · -- denominator is positive
    linarith

/-- The fourth program pole, approached from the right. -/
lemma mJ_pole (φ : ℝ) (hφ : 0 < φ) :
    Filter.Tendsto (fun μ => mJ μ φ) (𝓝[>] φ) Filter.atTop := by
  unfold mJ
  -- The numerator is positive at μ = φ, denominator tends to 0 from above
  have hnum_pos : 0 < φ * (1 + φ) + φ * Real.sqrt ((1 + φ) * (1 + φ)) := by
    have h1 : Real.sqrt ((1 + φ) * (1 + φ)) = 1 + φ := Real.sqrt_mul_self (by linarith : 0 ≤ 1 + φ)
    rw [h1]
    positivity
  -- Numerator is continuous, tends to hnum_pos value
  have hnum_tendsto : Filter.Tendsto (fun μ => φ * (1 + μ) + μ * Real.sqrt ((1 + φ) * (1 + μ))) (𝓝[>] φ) (𝓝 (φ * (1 + φ) + φ * Real.sqrt ((1 + φ) * (1 + φ)))) := by
    have : Filter.Tendsto (fun μ => φ * (1 + μ) + μ * Real.sqrt ((1 + φ) * (1 + μ))) (𝓝 φ) (𝓝 (φ * (1 + φ) + φ * Real.sqrt ((1 + φ) * (1 + φ)))) :=
      Filter.Tendsto.add (tendsto_const_nhds.mul (tendsto_const_nhds.add Filter.tendsto_id))
        (Filter.tendsto_id.mul (Real.continuous_sqrt.continuousAt.tendsto.comp ((continuous_const.mul (continuous_const.add continuous_id')).continuousAt)))
    exact this.mono_left nhdsWithin_le_nhds
  -- numerator is eventually ≥ c > 0  
  let hc_val : ℝ := φ * (1 + φ) + φ * Real.sqrt ((1 + φ) * (1 + φ))
  have hc : 0 < hc_val := hnum_pos
  have hnum_bdd : ∀ᶠ μ in 𝓝[>] φ, φ * (1 + μ) + μ * Real.sqrt ((1 + φ) * (1 + μ)) ≥ (hc_val / 2) := by
    have hlt : hc_val / 2 < hc_val := half_lt_self hc
    have hmem : Set.Ioi (hc_val / 2) ∈ 𝓝 hc_val := Ioi_mem_nhds hlt
    have hmem' := hnum_tendsto hmem
    filter_upwards [hmem'] with μ hμ
    simp only [Set.mem_preimage, Set.mem_Ioi] at hμ
    exact le_of_lt hμ
  -- denominator (μ - φ) → 0⁺, so 1/(μ - φ) → +∞
  have hinv : Filter.Tendsto (fun μ => (μ - φ)⁻¹) (𝓝[>] φ) Filter.atTop := by
    refine Filter.tendsto_atTop.mpr ?_
    intro b
    by_cases hb : b ≤ 0
    · filter_upwards [self_mem_nhdsWithin] with x hx
      exact le_trans hb (inv_nonneg.mpr (sub_nonneg.mpr hx.out.le))
    · push_neg at hb
      have h1b : 0 < 1 / b := div_pos one_pos hb
      filter_upwards [Ioo_mem_nhdsGT (show φ < φ + 1 / b by linarith)] with x hx
      have hx_gt : φ < x := hx.1
      have hx_lt : x < φ + 1 / b := hx.2
      have hsub_pos : 0 < x - φ := by linarith
      calc b = (1 / b)⁻¹ := by field_simp
        _ ≤ (x - φ)⁻¹ := inv_anti₀ hsub_pos (le_of_lt (by linarith : x - φ < 1 / b))
  -- Combine: numerator ≥ c/2 > 0 and (μ - φ)⁻¹ → +∞ implies product → +∞
  have hprod : Filter.Tendsto (fun μ => (hc_val / 2) * (μ - φ)⁻¹) (𝓝[>] φ) Filter.atTop :=
    Filter.Tendsto.const_mul_atTop (by linarith : 0 < hc_val / 2) hinv
  -- hprod : Filter.Tendsto ... Filter.atTop
  -- Goal: ∀ᶠ a in 𝓝[>] φ, s ≤ ...
  rw [Filter.tendsto_atTop] at hprod
  -- Now hprod : ∀ b : ℝ, ∀ᶠ a in 𝓝[>] φ, b ≤ hc_val / 2 * (a - φ)⁻¹
  -- Goal: ∀ᶠ a in 𝓝[>] φ, s ≤ ... where s comes from the filter definition
  simp only [Filter.tendsto_atTop] at *
  intro b
  filter_upwards [hprod b, hnum_bdd, self_mem_nhdsWithin] with a hb ha_num a_gt
  rw [div_eq_mul_inv]
  calc b ≤ hc_val / 2 * (a - φ)⁻¹ := hb
    _ ≤ (φ * (1 + a) + a * Real.sqrt ((1 + φ) * (1 + a))) * (a - φ)⁻¹ := by
        apply mul_le_mul_of_nonneg_right ha_num
        exact inv_nonneg.mpr (le_of_lt (sub_pos.mpr a_gt))

/-! ## J4: delegation -/

noncomputable def Ccost (ψ ζ φ : ℝ) : ℝ :=
  -(ψ * (1 - (1 + φ) / ζ) ^ 2 +
    (1 - ψ) * (Real.sqrt ζ - Real.sqrt (1 + φ)) ^ 2)

lemma Ccost_neg (ψ ζ φ : ℝ) (hψ0 : 0 ≤ ψ) (hψ1 : ψ ≤ 1)
    (hφ : 0 ≤ φ) (hζ : 1 + φ < ζ) : Ccost ψ ζ φ < 0 := by
  unfold Ccost
  suffices h : ψ * (1 - (1 + φ) / ζ) ^ 2 + (1 - ψ) * (Real.sqrt ζ - Real.sqrt (1 + φ)) ^ 2 > 0 by
    linarith
  have hζ_pos : ζ > 0 := by linarith
  have h1pφ_pos : 1 + φ > 0 := by linarith
  have hsq_diff_pos : (Real.sqrt ζ - Real.sqrt (1 + φ)) ^ 2 > 0 := by
    apply sq_pos_of_ne_zero
    intro h_eq
    have := sub_eq_zero.mp h_eq
    have : ζ = 1 + φ := Real.sqrt_inj hζ_pos.le h1pφ_pos.le |>.mp this
    linarith
  have hfrac_lt_one : (1 + φ) / ζ < 1 := by
    rw [div_lt_one hζ_pos]
    exact hζ
  have h_first_sq_pos : (1 - (1 + φ) / ζ) ^ 2 > 0 := by
    apply sq_pos_of_ne_zero
    intro h_eq
    have := sub_eq_zero.mp h_eq
    linarith
  rcases eq_or_lt_of_le hψ1 with rfl | hψ1'
  · simp
    exact h_first_sq_pos
  · have h_second_pos : (1 - ψ) * (Real.sqrt ζ - Real.sqrt (1 + φ)) ^ 2 > 0 := by
      apply mul_pos _ hsq_diff_pos
      linarith
    have h_nonneg : ψ * (1 - (1 + φ) / ζ) ^ 2 ≥ 0 := mul_nonneg hψ0 (sq_nonneg _)
    linarith

noncomputable def Uutil (ϖ C R : ℝ) : ℝ := ϖ * C + (1 - ϖ) * R

lemma Uutil_strictAnti (C R : ℝ) (hCR : C < R) : StrictAnti (fun ϖ => Uutil ϖ C R) := by
  intro ϖ₁ ϖ₂ hlt
  simp only [Uutil]
  have : ϖ₁ * C + (1 - ϖ₁) * R - (ϖ₂ * C + (1 - ϖ₂) * R) = (ϖ₁ - ϖ₂) * (C - R) := by ring
  linarith [mul_pos_of_neg_of_neg (sub_neg.mpr hlt) (sub_neg.mpr hCR)]

/-- Freeze characterization.  `C < 0 ≤ R` makes `R-C` positive and places the
cutoff in `[0,1)`. -/
lemma Uutil_neg_iff (ϖ C R : ℝ) (hC : C < 0) (hR : 0 ≤ R) :
    Uutil ϖ C R < 0 ↔ R / (R - C) < ϖ := by
  unfold Uutil
  have hRC : 0 < R - C := by linarith
  rw [div_lt_iff₀ hRC]
  constructor <;> intro h <;> linarith

/-! ## J5: crowding -/

noncomputable def V0fun (ζU φ : ℝ) : ℝ :=
  Real.sqrt (ζU / (1 + φ)) - Real.sqrt ((1 + φ) / ζU)

noncomputable def Vfun (μ πJ φ : ℝ) : ℝ :=
  (1 - πJ) * (μ + μ / (1 + μ)) +
    πJ * (Real.sqrt ((1 + μ) / (1 + φ)) - Real.sqrt ((1 + φ) / (1 + μ)))

noncomputable def Rrev (φ μ πJ : ℝ) : ℝ := φ * Vfun μ πJ φ
noncomputable def Rrev0 (φ ζU : ℝ) : ℝ := φ * V0fun ζU φ

lemma Rrev_eq_fee_mul_V (φ μ πJ : ℝ) : Rrev φ μ πJ = φ * Vfun μ πJ φ := rfl
lemma Rrev0_eq_fee_mul_V0 (φ ζU : ℝ) : Rrev0 φ ζU = φ * V0fun ζU φ := rfl

noncomputable def ζstar (φ : ℝ) : ℝ := (Real.sqrt φ + Real.sqrt (1 + φ)) ^ 2

/-- The clean π=1 bridge at corresponding depth `μ = ζstar-1`: both volume
expressions coincide. -/
lemma V0fun_zetaStar_eq_Vfun_one (φ : ℝ) (hφ : 0 < φ) :
    V0fun (ζstar φ) φ = Vfun (ζstar φ - 1) 1 φ := by
  simp [V0fun, Vfun]

lemma ζstar_strictMono : StrictMonoOn ζstar (Set.Ici 0) := by
  intro x₁ hx₁ x₂ hx₂ hlt
  simp only [ζstar]
  have hsqrt1_pos : 0 ≤ Real.sqrt x₁ := Real.sqrt_nonneg _
  have hsqrt2_pos : 0 ≤ Real.sqrt (1 + x₁) := Real.sqrt_nonneg _
  have hsum_pos : 0 < Real.sqrt x₁ + Real.sqrt (1 + x₁) := by
    have : 0 < Real.sqrt (1 + x₁) := Real.sqrt_pos.mpr (by linarith [hx₁.out])
    linarith
  have hsqrt1_lt : Real.sqrt x₁ < Real.sqrt x₂ := Real.sqrt_lt_sqrt hx₁.out hlt
  have hsqrt2_lt : Real.sqrt (1 + x₁) < Real.sqrt (1 + x₂) :=
    Real.sqrt_lt_sqrt (by linarith [hx₁.out]) (by linarith)
  nlinarith [sq_nonneg (Real.sqrt x₁ + Real.sqrt (1 + x₁)), sq_nonneg (Real.sqrt x₂ + Real.sqrt (1 + x₂))]

/-! ## J6: two-tier split and welfare corner -/

noncomputable def sJ (dP dJ : ℝ) : ℝ := dJ / (dP + dJ)

lemma effective_shares_sum (ϑ share : ℝ) : (1 - ϑ * share) + ϑ * share = 1 := by ring

lemma effective_shares_mem (ϑ share : ℝ) (hϑ : ϑ ∈ Set.Icc (0 : ℝ) 1)
    (hs : share ∈ Set.Icc (0 : ℝ) 1) :
    1 - ϑ * share ∈ Set.Icc (0 : ℝ) 1 ∧ ϑ * share ∈ Set.Icc (0 : ℝ) 1 := by
  have hϑ0 : 0 ≤ ϑ := hϑ.1
  have hϑ1 : ϑ ≤ 1 := hϑ.2
  have hshare0 : 0 ≤ share := hs.1
  have hshare1 : share ≤ 1 := hs.2
  have hprod0 : 0 ≤ ϑ * share := mul_nonneg hϑ0 hshare0
  have hprod1 : ϑ * share ≤ 1 := mul_le_one₀ hϑ1 hshare0 hshare1
  exact ⟨⟨by linarith, by linarith⟩, ⟨hprod0, hprod1⟩⟩

lemma passive_share_affine (ϑ₁ ϑ₂ a share : ℝ) :
    1 - (a * ϑ₁ + (1 - a) * ϑ₂) * share =
      a * (1 - ϑ₁ * share) + (1 - a) * (1 - ϑ₂ * share) := by ring

/-- Thin incidence bridge: `ϑ` corresponds to `1-taxFraction` in the rebate algebra. -/
lemma passive_share_tax_bridge (ϑ share : ℝ) :
    1 - ϑ * share = 1 - (1 - (1 - ϑ)) * share := by ring

/-- Clean compact-interval welfare corner.  Strict decrease and opposite endpoint signs
are necessary to derive a unique binding point; continuity supplies existence. -/
lemma welfare_corner (Wwelf U : ℝ → ℝ)
    (hW : MonotoneOn Wwelf (Set.Icc (0 : ℝ) 1))
    (hU : StrictAntiOn U (Set.Icc (0 : ℝ) 1))
    (hcont : ContinuousOn U (Set.Icc (0 : ℝ) 1))
    (hU0 : 0 ≤ U 0) (hU1 : U 1 ≤ 0) :
    ∃! ϑstar ∈ Set.Icc (0 : ℝ) 1,
      U ϑstar = 0 ∧
      (∀ ϑ ∈ Set.Icc (0 : ℝ) 1, 0 ≤ U ϑ → Wwelf ϑ ≤ Wwelf ϑstar) := by
  -- Use IVT: U is continuous on [0,1] with U 0 ≥ 0 and U 1 ≤ 0
  have hU_nonneg : U 0 ≥ 0 := hU0
  have hU_nonpos : U 1 ≤ 0 := hU1
  have h_ivt : ∃ ϑstar ∈ Set.Icc (0 : ℝ) 1, U ϑstar = 0 := by
    have := intermediate_value_Icc' zero_le_one hcont
    have h0_mem : (0 : ℝ) ∈ Set.Icc (U 1) (U 0) := Set.mem_Icc.mpr ⟨hU_nonpos, hU_nonneg⟩
    have := this h0_mem
    exact this
  -- Extract ϑstar from IVT
  obtain ⟨ϑstar, hϑstar_mem, hϑstar_root⟩ := h_ivt
  -- Uniqueness: U is strictly antitone, so U x = U y = 0 implies x = y
  have h_unique : ∀ x y : ℝ, x ∈ Set.Icc 0 1 → y ∈ Set.Icc 0 1 → U x = 0 → U y = 0 → x = y := by
    intro x y hx hy hx0 hy0
    by_contra hne
    rcases lt_trichotomy x y with hlt | rfl | hgt
    · have := hU hx hy hlt
      linarith
    · exact hne rfl
    · have := hU hy hx hgt
      linarith
  -- Welfare condition: if U ϑ ≥ 0 then ϑ ≤ ϑstar, so Wwelf ϑ ≤ Wwelf ϑstar by monotonicity
  have h_welfare : ∀ ϑ ∈ Set.Icc (0 : ℝ) 1, 0 ≤ U ϑ → Wwelf ϑ ≤ Wwelf ϑstar := by
    intro ϑ hϑ_mem hϑ_nonneg
    have hϑ_le : ϑ ≤ ϑstar := by
      by_contra hlt
      push_neg at hlt
      have := hU hϑstar_mem hϑ_mem hlt
      linarith
    exact hW hϑ_mem hϑstar_mem hϑ_le
  exact ExistsUnique.intro ϑstar ⟨hϑstar_mem, hϑstar_root, h_welfare⟩
    (fun y ⟨hy_mem, hy_root, hy_welfare⟩ => h_unique y ϑstar hy_mem hϑstar_mem hy_root hϑstar_root)

/-! ## J7: lambda-JIT incidence -/

lemma toxicity_ratio_strictMono (lamFLAIR lamARB : ℝ) (hF : 0 < lamFLAIR)
    (hA : 0 < lamARB) :
    StrictMonoOn (fun lamJIT => lamARB / (lamFLAIR - lamJIT))
      (Set.Ico (0 : ℝ) lamFLAIR) := by
  intro x₁ hx₁ x₂ hx₂ hlt
  simp only [Set.mem_Ico] at hx₁ hx₂
  have hdenom_pos : lamFLAIR - x₂ > 0 := by linarith
  have hdenom_lt : lamFLAIR - x₂ < lamFLAIR - x₁ := by linarith
  exact div_lt_div_of_pos_left hA hdenom_pos hdenom_lt

lemma incidence_preserves_ARB (lamFLAIR lamJIT lamARB : ℝ) :
    (lamFLAIR - lamJIT, lamARB).2 = lamARB := rfl

/-- `lamJIT` changes the FLAIR incidence coordinate but is not passed to
`mevTotal`: extraction intensity, whose first coordinate is `lamARB`, is invariant. -/
lemma incidence_mevTotal_invariant (lamFLAIR lamJIT lamARB lamSand : ℝ) :
    MevJointProgram.mevTotal lamARB lamSand = MevJointProgram.mevTotal lamARB lamSand := rfl

lemma incidence_FLAIR_falls (lamFLAIR lamJIT : ℝ) (hJ : 0 < lamJIT) :
    lamFLAIR - lamJIT < lamFLAIR := by linarith

/-! ## J8: conditional shape block and l2 bridge -/

/-- Conditional payoff substitution.  `shape` may in particular be the reused
`VolInstrument.multiFee` parameter block `(β_j,γ_j)`.  Existence of a concrete
`ϑeff(β,γ)` satisfying duration-sensitive accrual and trader-fee invariance is OPEN;
a duration observable is required.  The l2-angstrom `afterRemoveLiquidity` path
is implementation evidence of feasibility, not a premise of this theorem. -/
lemma conditional_payoff_identity {Shape : Type} (ϑeff : Shape → ℝ)
    (shape : Shape) (φ proRata subAccrual totalFee : ℝ)
    (heff : ϑeff shape ∈ Set.Icc (0 : ℝ) 1)
    (hacc : subAccrual = ϑeff shape * φ * proRata)
    (hfee : totalFee = φ) :
    (φ * proRata - subAccrual, subAccrual, totalFee) =
    ((1 - ϑeff shape) * φ * proRata,
      ϑeff shape * φ * proRata, φ) := by
  rw [hacc, hfee]
  congr 1
  ring

/-- Without trader-fee invariance, the formal widening content is precisely J5's
strict increase of the crowding threshold. -/
lemma trader_fee_raises_crowding_threshold (φ₁ φ₂ : ℝ)
    (hφ₁ : 0 ≤ φ₁) (hlt : φ₁ < φ₂) : ζstar φ₁ < ζstar φ₂ :=
  ζstar_strictMono hφ₁ (le_of_lt (lt_of_le_of_lt hφ₁ hlt)) hlt

/-- Dated l2-angstrom bridge: the structural JIT factor is `3/2` times the swap
factor.  Rates are protocol-kept, not rebated, unlike CJZ's remedy.  The `3/2`
ratio is the dated snapshot's structural constant (the add/remove-liquidity tax
path), not a calibrated numeral. -/
noncomputable def jitFactor (x : ℝ) : ℝ := (3 / 2 : ℝ) * x

noncomputable def swapRate (x : ℝ) : ℝ := MevJointProgram.taxFraction x
noncomputable def jitRate (x : ℝ) : ℝ := MevJointProgram.taxFraction (jitFactor x)

lemma jitRate_gt_swapRate (x : ℝ) (hx : 0 < x) : swapRate x < jitRate x := by
  unfold swapRate jitRate jitFactor
  unfold MevJointProgram.taxFraction
  rw [div_lt_div_iff₀ (by linarith : 0 < x + 1) (by linarith : 0 < (3 / 2) * x + 1)]
  nlinarith

lemma swapRate_strictMono : StrictMonoOn swapRate (Set.Ici 0) := by
  intro x hx y hy hxy
  simp only [swapRate, MevJointProgram.taxFraction, Set.mem_Ici] at *
  rw [div_lt_div_iff₀ (by linarith : 0 < x + 1) (by linarith : 0 < y + 1)]
  linarith
lemma jitRate_strictMono : StrictMonoOn jitRate (Set.Ici 0) := by
  intro x hx y hy hxy
  simp only [jitRate, jitFactor, MevJointProgram.taxFraction, Set.mem_Ici] at *
  rw [div_lt_div_iff₀ (by linarith : 0 < (3 / 2) * x + 1) (by linarith : 0 < (3 / 2) * y + 1)]
  linarith

lemma swapRate_strictConcave : StrictConcaveOn ℝ (Set.Ici 0) swapRate := by
  unfold swapRate StrictConcaveOn
  refine ⟨convex_Ici 0, ?_⟩
  intro x _ y _ hxy a b ha hb hab
  simp only [smul_eq_mul]
  -- swapRate x = taxFraction x = x / (x + 1) = 1 - 1/(x+1)
  -- Since 1/(x+1) is strictly convex for x >= 0, swapRate is strictly concave
  have hx_nonneg : 0 ≤ x := by assumption
  have hy_nonneg : 0 ≤ y := by assumption
  have hx_denom : 0 < x + 1 := by linarith
  have hy_denom : 0 < y + 1 := by linarith
  have hab_denom : 0 < a * x + b * y + 1 := by nlinarith
  have key : a * (x / (x + 1)) + b * (y / (y + 1)) < (a * x + b * y) / (a * x + b * y + 1) := by
    have hne_x : x + 1 ≠ 0 := by linarith
    have hne_y : y + 1 ≠ 0 := by linarith
    have hne_ab : a * x + b * y + 1 ≠ 0 := by linarith
    simp_rw [mul_div_assoc']
    rw [div_add_div _ _ hne_x hne_y]
    rw [div_lt_div_iff₀ (by positivity) hab_denom]
    -- The difference RHS - LHS = a * b * (x - y)^2 > 0
    have hab' : b = 1 - a := by linarith
    have h_diff_eq : (a * x + b * y) * ((x + 1) * (y + 1)) -
                     (a * x * (y + 1) + (x + 1) * (b * y)) * (a * x + b * y + 1) =
                     a * b * (x - y)^2 := by
      rw [hab']
      ring
    have hxy_ne : x - y ≠ 0 := sub_ne_zero.mpr hxy
    have hxy_sq : 0 < (x - y)^2 := by apply pow_two_pos_of_ne_zero; exact hxy_ne
    have hpos : 0 < a * b * (x - y)^2 := by positivity
    linarith [h_diff_eq.symm ▸ hpos]
  simp only [MevJointProgram.taxFraction]
  linarith
lemma jitRate_strictConcave : StrictConcaveOn ℝ (Set.Ici 0) jitRate := by
  refine ⟨convex_Ici _, ?_⟩
  intro x hx y hy hxy a b ha hb hab
  simp only [smul_eq_mul]
  unfold jitRate jitFactor MevJointProgram.taxFraction
  have hx' : 0 ≤ x := hx
  have hy' : 0 ≤ y := hy
  have hu_eq : (3/2 : ℝ) * (a * x + b * y) = a * ((3/2)*x) + b * ((3/2)*y) := by ring
  rw [hu_eq]
  set u := (3/2 : ℝ) * x with hu_def
  set v := (3/2 : ℝ) * y with hv_def
  have hu_pos : 0 ≤ u := by rw [hu_def]; positivity
  have hv_pos : 0 ≤ v := by rw [hv_def]; positivity
  have huv_ne : u ≠ v := by rw [hu_def, hv_def]; intro h; apply hxy; linarith
  have hu1 : 0 < u + 1 := by linarith
  have hv1 : 0 < v + 1 := by linarith
  have hab_uv : 0 ≤ a * u + b * v := by positivity
  have hab_uv1 : 0 < a * u + b * v + 1 := by positivity
  have lhs_eq : a * (u / (u + 1)) + b * (v / (v + 1)) =
                (a * u * (v + 1) + (u + 1) * (b * v)) / ((u + 1) * (v + 1)) := by
    field_simp
  rw [lhs_eq]
  rw [div_lt_div_iff₀ (mul_pos hu1 hv1) hab_uv1]
  have hab' : b = 1 - a := by linarith
  have hkey : (a * u + b * v) * ((u + 1) * (v + 1)) -
              (a * u * (v + 1) + (u + 1) * (b * v)) * (a * u + b * v + 1) = a * b * (u - v)^2 := by
    rw [hab']; ring
  have huv_ne' : u - v ≠ 0 := sub_ne_zero.mpr huv_ne
  have huv_sq : 0 < (u - v)^2 := by nlinarith [sq_nonneg (u - v), mul_self_pos.mpr huv_ne']
  linarith [hkey.symm ▸ mul_pos (mul_pos ha hb) huv_sq]

end JitLiquidity
