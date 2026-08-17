import Mathlib
import vol_markets.EtaTilde

open Set

set_option maxHeartbeats 8000000
set_option maxRecDepth 4000
set_option relaxedAutoImplicit false
set_option autoImplicit false

/-!
# Canonical forms for the Capponi and weighted-geometric curve families

We use the supremum definition of the canonical trading function from equation
(6) of Angeris–Chitra–Diamandis–Evans–Kulkarni.  The supremum calculations
below prove an `IsGreatest` characterization of each feasible set; in
particular, neither emptiness nor unboundedness is hidden behind the behavior of
`sSup`.
-/

namespace CanonicalCurve

/-- The project's weighted-geometric trading function.  Exponentiation is
`Real.rpow`; positivity assumptions are therefore explicit in its theorems. -/
noncomputable def phiEps (ε x y : ℝ) : ℝ := x ^ ε * y ^ (1 - ε)

/-- Capponi's linear-to-constant-product curvature family. -/
noncomputable def Fcap (κ A pA pB x y : ℝ) : ℝ :=
  (1 - κ) * A * (pA * x + pB * y) + κ * (x * y)

/-- The canonical trading function at level `k`. -/
noncomputable def canon (ψ : ℝ → ℝ → ℝ) (k x y : ℝ) : ℝ :=
  sSup {l : ℝ | 0 < l ∧ k ≤ ψ (x / l) (y / l)}

/-- **A1.** On the positive orthant and for a share in `[0,1]`, the weighted
geometric function is homogeneous of degree one, including scale `a = 0`. -/
theorem phiEps_homogeneous {ε a x y : ℝ} (hx : 0 < x) (hy : 0 < y)
    (hε : ε ∈ Icc (0 : ℝ) 1) (ha : 0 ≤ a) :
    phiEps ε (a * x) (a * y) = a * phiEps ε x y := by
  rcases eq_or_lt_of_le ha with rfl | ha'
  · simp [phiEps]
    rcases hε.1.eq_or_lt with rfl | hεpos
    · simp
    · rw [Real.zero_rpow hεpos.ne']
      simp
  · unfold phiEps
    rw [Real.mul_rpow (le_of_lt ha') (le_of_lt hx),
        Real.mul_rpow (le_of_lt ha') (le_of_lt hy)]
    have h := Real.rpow_add ha' ε (1 - ε)
    simp at h
    calc a ^ ε * x ^ ε * (a ^ (1 - ε) * y ^ (1 - ε))
        = a ^ ε * a ^ (1 - ε) * (x ^ ε * y ^ (1 - ε)) := by ring
      _ = a * (x ^ ε * y ^ (1 - ε)) := by rw [← h]

/-- **A2.** The weighted-geometric function is already canonical, up to the
positive level scale `k`. -/
theorem canon_phiEps {ε k x y : ℝ} (hx : 0 < x) (hy : 0 < y)
    (hε : ε ∈ Icc (0 : ℝ) 1) (hk : 0 < k) :
    canon (phiEps ε) k x y = phiEps ε x y / k := by
  unfold canon
  -- The key candidate is l = phiEps ε x y / k
  let val := phiEps ε x y / k
  -- We need to show val is the supremum
  apply csSup_eq_of_forall_le_of_forall_lt_exists_gt
  · -- Nonemptiness
    use val
    constructor
    · -- 0 < val
      unfold val phiEps
      exact div_pos (mul_pos (Real.rpow_pos_of_pos hx ε) (Real.rpow_pos_of_pos hy (1 - ε))) hk
    · -- k ≤ phiEps ε (x / val) (y / val)
      -- Use homogeneity: phiEps ε (x/val) (y/val) = (1/val) * phiEps ε x y
      have hval_pos : 0 < val := by
        unfold val phiEps
        exact div_pos (mul_pos (Real.rpow_pos_of_pos hx ε) (Real.rpow_pos_of_pos hy (1 - ε))) hk
      have hval_ne : val ≠ 0 := ne_of_gt hval_pos
      rw [show x / val = (1 / val) * x by ring, show y / val = (1 / val) * y by ring]
      rw [phiEps_homogeneous hx hy hε (le_of_lt (by positivity : 0 < 1 / val))]
      -- Now need: k ≤ (1/val) * phiEps ε x y
      -- Since val = phiEps ε x y / k, we have 1/val * phiEps ε x y = k
      have hphi_pos : 0 < phiEps ε x y := by
        unfold phiEps; exact mul_pos (Real.rpow_pos_of_pos hx ε) (Real.rpow_pos_of_pos hy (1 - ε))
      unfold val
      field_simp
      norm_num
  · -- Every element is ≤ val
    intro a ha
    obtain ⟨ha_pos, ha_cond⟩ := ha
    -- phiEps ε (x/a) (y/a) = (1/a) * phiEps ε x y by homogeneity
    have h1a_pos : 0 < 1 / a := by positivity
    rw [show x / a = (1 / a) * x by ring, show y / a = (1 / a) * y by ring] at ha_cond
    rw [phiEps_homogeneous hx hy hε (le_of_lt h1a_pos)] at ha_cond
    -- ha_cond : k ≤ (1/a) * phiEps ε x y
    -- So a * k ≤ phiEps ε x y, hence a ≤ phiEps ε x y / k
    have hphi_pos : 0 < phiEps ε x y := by
      unfold phiEps; exact mul_pos (Real.rpow_pos_of_pos hx ε) (Real.rpow_pos_of_pos hy (1 - ε))
    -- From ha_cond: k ≤ (1/a) * phiEps ε x y means a * k ≤ phiEps ε x y
    have hak : a * k ≤ phiEps ε x y := by
      have h := mul_le_mul_of_nonneg_left ha_cond (le_of_lt ha_pos)
      field_simp [ha_pos.ne'] at h ⊢
      linarith
    rw [le_div_iff₀ hk]
    linarith
  · -- For any w < val, there exists element > w
    intro w hw
    use val
    refine ⟨?_, ?_⟩
    · -- val ∈ {l | 0 < l ∧ k ≤ phiEps ε (x / l) (y / l)}
      constructor
      · -- 0 < val
        unfold val phiEps
        exact div_pos (mul_pos (Real.rpow_pos_of_pos hx ε) (Real.rpow_pos_of_pos hy (1 - ε))) hk
      · -- k ≤ phiEps ε (x / val) (y / val)
        have hphi_pos : 0 < phiEps ε x y := by
          unfold phiEps; exact mul_pos (Real.rpow_pos_of_pos hx ε) (Real.rpow_pos_of_pos hy (1 - ε))
        rw [show x / val = (1 / val) * x by ring, show y / val = (1 / val) * y by ring]
        rw [phiEps_homogeneous hx hy hε (le_of_lt (by positivity : 0 < 1 / val))]
        unfold val
        field_simp
        norm_num
    · -- w < val
      exact hw

/-- **A3.** Closed form of the canonical Capponi family. -/
theorem canon_Fcap {κ A pA pB C x y : ℝ}
    (hκ : κ ∈ Icc (0 : ℝ) 1) (hA : 0 < A) (hpA : 0 < pA)
    (hpB : 0 < pB) (hC : 0 < C) (hx : 0 < x) (hy : 0 < y) :
    canon (Fcap κ A pA pB) C x y =
      ((1 - κ) * A * (pA * x + pB * y) +
        Real.sqrt (((1 - κ) * A * (pA * x + pB * y)) ^ 2 +
          4 * C * κ * x * y)) / (2 * C) := by
  unfold canon
  set S := (1 - κ) * A * (pA * x + pB * y) with hS
  set P := x * y with hP
  set k := S ^ 2 + 4 * C * κ * x * y with hk_def
  set l_star := (S + Real.sqrt k) / (2 * C) with hl_star_def
  -- Show k > 0
  have hk_pos : 0 < k := by
    simp only [hk_def]
    by_cases hκ0 : κ = 0
    · -- When κ = 0, k = S^2 and S > 0
      simp [hκ0]
      have hS_pos : 0 < S := by rw [hS]; simp [hκ0]; positivity
      nlinarith [sq_nonneg S]
    · have hκ_pos : 0 < κ := lt_of_le_of_ne hκ.1 (Ne.symm hκ0)
      positivity
  -- Show S ≥ 0
  have hS_nn : 0 ≤ S := by
    simp only [hS]
    apply mul_nonneg (mul_nonneg (sub_nonneg.mpr (hκ.2)) (le_of_lt hA))
    apply add_nonneg (mul_nonneg (le_of_lt hpA) (le_of_lt hx)) (mul_nonneg (le_of_lt hpB) (le_of_lt hy))
  -- Show l_star > 0
  have hl_star_pos : 0 < l_star := by
    rw [hl_star_def]
    apply div_pos _ (by positivity : 0 < 2 * C)
    linarith [Real.sqrt_pos.mpr hk_pos]
  -- Key identity: C * l_star² = S * l_star + κ * x * y
  have hl_star_quad : C * l_star ^ 2 = S * l_star + κ * x * y := by
    rw [hl_star_def]
    have hC_ne : C ≠ 0 := ne_of_gt hC
    field_simp
    ring_nf
    rw [Real.sq_sqrt (le_of_lt hk_pos)]
    ring
  -- Show l_star is in the set
  have hl_star_mem : l_star ∈ {l | 0 < l ∧ C ≤ Fcap κ A pA pB (x / l) (y / l)} := by
    constructor
    · exact hl_star_pos
    · unfold Fcap
      have hl_star_ne : l_star ≠ 0 := ne_of_gt hl_star_pos
      have h1 : (1 - κ) * A * (pA * (x / l_star) + pB * (y / l_star)) = S / l_star := by
        rw [hS]
        field_simp
      have h2 : κ * (x / l_star * (y / l_star)) = κ * x * y / l_star ^ 2 := by
        field_simp
      rw [h1, h2]
      have : S / l_star + κ * x * y / l_star ^ 2 = C := by
        field_simp
        linarith [hl_star_quad]
      linarith
  -- Show l_star is an upper bound
  have hl_star_ub : ∀ l ∈ {l | 0 < l ∧ C ≤ Fcap κ A pA pB (x / l) (y / l)}, l ≤ l_star := by
    intro l hl
    obtain ⟨hl_pos, hl_cond⟩ := hl
    unfold Fcap at hl_cond
    -- C ≤ S/l + κ*x*y/l² means C*l² ≤ S*l + κ*x*y
    have hquad : C * l ^ 2 ≤ S * l + κ * x * y := by
      have : C ≤ (1 - κ) * A * (pA * (x / l) + pB * (y / l)) + κ * (x / l * (y / l)) := hl_cond
      have hl_ne : l ≠ 0 := ne_of_gt hl_pos
      have h1 : (1 - κ) * A * (pA * (x / l) + pB * (y / l)) = S / l := by
        rw [hS]; field_simp
      have h2 : κ * (x / l * (y / l)) = κ * x * y / l ^ 2 := by field_simp
      rw [h1, h2] at hl_cond
      have hlsq_pos : 0 < l ^ 2 := sq_pos_of_pos hl_pos
      calc C * l ^ 2 ≤ (S / l + κ * x * y / l ^ 2) * l ^ 2 := mul_le_mul_of_nonneg_right hl_cond (le_of_lt hlsq_pos)
        _ = S * l + κ * x * y := by field_simp
    -- Now show l ≤ l_star using the quadratic inequality
    have hl_le : l ≤ l_star := by
      by_contra h
      push_neg at h
      -- Factor: C*l² - S*l - κ*x*y = (l - l_star) * (C*(l + l_star) - S)
      have factor : C * l ^ 2 - S * l - κ * x * y = (l - l_star) * (C * (l + l_star) - S) := by
        have h := hl_star_quad
        nlinarith [sq_nonneg l, sq_nonneg l_star]
      -- l - l_star > 0
      have h1 : l - l_star > 0 := sub_pos.mpr h
      -- C * (l + l_star) - S > 0 because l_star = (S + √k)/(2*C) implies 2*C*l_star = S + √k ≥ S
      have h2 : C * (l + l_star) - S > 0 := by
        have h3 : 2 * C * l_star = S + Real.sqrt k := by
          rw [hl_star_def]
          field_simp
        nlinarith [Real.sqrt_nonneg k]
      -- Therefore C*l² - S*l - κ*x*y > 0
      have hpos : C * l ^ 2 - S * l - κ * x * y > 0 := by
        rw [factor]
        exact mul_pos h1 h2
      -- But hquad says C*l² ≤ S*l + κ*x*y, contradiction
      linarith
    exact hl_le
  -- Conclude sSup = l_star
  apply le_antisymm
  · exact csSup_le ⟨l_star, hl_star_mem⟩ hl_star_ub
  · exact le_csSup ⟨l_star, hl_star_ub⟩ hl_star_mem

/-- **A4.** The canonical Capponi function is homogeneous of degree one. -/
theorem canon_Fcap_homogeneous {κ A pA pB C a x y : ℝ}
    (hκ : κ ∈ Icc (0 : ℝ) 1) (hA : 0 < A) (hpA : 0 < pA)
    (hpB : 0 < pB) (hC : 0 < C) (hx : 0 < x) (hy : 0 < y)
    (ha : 0 < a) :
    canon (Fcap κ A pA pB) C (a * x) (a * y) =
      a * canon (Fcap κ A pA pB) C x y := by
  rw [canon_Fcap hκ hA hpA hpB hC (mul_pos ha hx) (mul_pos ha hy), canon_Fcap hκ hA hpA hpB hC hx hy]
  -- Simplify pA * (a * x) + pB * (a * y) = a * (pA * x + pB * y)
  have hlin : pA * (a * x) + pB * (a * y) = a * (pA * x + pB * y) := by ring
  -- Simplify (a * x) * (a * y) = a^2 * x * y
  have hprod : (a * x) * (a * y) = a ^ 2 * x * y := by ring
  rw [hlin]
  -- Rewrite (a * x) * (a * y) = a^2 * x * y in the goal
  have hprod' : 4 * C * κ * (a * x) * (a * y) = a^2 * (4 * C * κ * x * y) := by ring
  -- Rewrite the squared term
  have hsq : ((1 - κ) * A * (a * (pA * x + pB * y))) ^ 2 = a^2 * ((1 - κ) * A * (pA * x + pB * y)) ^ 2 := by ring
  rw [hsq, hprod']
  -- Factor out a^2 from the sqrt argument
  have hfactors : a^2 * ((1 - κ) * A * (pA * x + pB * y)) ^ 2 + a^2 * (4 * C * κ * x * y) = 
                  a^2 * (((1 - κ) * A * (pA * x + pB * y)) ^ 2 + 4 * C * κ * x * y) := by ring
  rw [hfactors]
  -- Rewrite the linear term: (1 - κ) * A * (a * (pA * x + pB * y)) = a * ((1 - κ) * A * (pA * x + pB * y))
  have hlin' : (1 - κ) * A * (a * (pA * x + pB * y)) = a * ((1 - κ) * A * (pA * x + pB * y)) := by ring
  rw [hlin']
  -- sqrt(a^2 * k) = a * sqrt(k) for a > 0
  have hsqrt : Real.sqrt (a^2 * (((1 - κ) * A * (pA * x + pB * y)) ^ 2 + 4 * C * κ * x * y)) = 
               a * Real.sqrt (((1 - κ) * A * (pA * x + pB * y)) ^ 2 + 4 * C * κ * x * y) := by
    rw [Real.sqrt_mul (sq_nonneg a), Real.sqrt_sq (le_of_lt ha)]
  rw [hsqrt]
  ring

/-- **B1.** Capponi's `κ = 1` endpoint canonically is the geometric mean. -/
theorem canon_Fcap_one {A pA pB C x y : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C)
    (hx : 0 < x) (hy : 0 < y) :
    canon (Fcap 1 A pA pB) C x y = Real.sqrt (x * y) / Real.sqrt C := by
  simp only [canon, Fcap, sub_self, zero_mul, zero_add, one_mul]
  set val := Real.sqrt (x * y) / Real.sqrt C with hval_def
  have hval_pos : 0 < val := div_pos (Real.sqrt_pos.mpr (mul_pos hx hy)) (Real.sqrt_pos.mpr hC)
  have hval_in_set : val ∈ {l : ℝ | 0 < l ∧ C ≤ x / l * (y / l)} := by
    constructor
    · exact hval_pos
    · rw [hval_def]
      have hC_ne : Real.sqrt C ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr hC)
      have hxy_ne : Real.sqrt (x * y) ≠ 0 := ne_of_gt (Real.sqrt_pos.mpr (mul_pos hx hy))
      field_simp
      rw [Real.sq_sqrt (le_of_lt (mul_pos hx hy)), Real.sq_sqrt (le_of_lt hC)]
      linarith
  have hub : ∀ l ∈ {l : ℝ | 0 < l ∧ C ≤ x / l * (y / l)}, l ≤ val := by
    intro l hl
    obtain ⟨hl_pos, hl_cond⟩ := hl
    have hprod : x / l * (y / l) = x * y / l ^ 2 := by field_simp
    rw [hprod] at hl_cond
    have hsq : l ^ 2 ≤ x * y / C := by
      have hl_sq_pos : 0 < l ^ 2 := sq_pos_of_pos hl_pos
      rw [le_div_iff₀ hl_sq_pos] at hl_cond
      rwa [le_div_iff₀ hC, mul_comm]
    have h := Real.le_sqrt_of_sq_le hsq
    rw [Real.sqrt_div (le_of_lt (mul_pos hx hy))] at h
    exact h
  exact csSup_eq_of_forall_le_of_forall_lt_exists_gt ⟨val, hval_in_set⟩ hub (fun w hw => ⟨val, hval_in_set, hw⟩)

/-- **B2.** Capponi's `κ = 0` endpoint canonically is linear. -/
theorem canon_Fcap_zero {A pA pB C x y : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C)
    (hx : 0 < x) (hy : 0 < y) :
    canon (Fcap 0 A pA pB) C x y = A * (pA * x + pB * y) / C := by
  unfold canon
  set S := A * (pA * x + pB * y) with hS
  have hS_pos : 0 < S := by rw [hS]; positivity
  -- Fcap 0 A pA pB a b = A * (pA * a + pB * b)
  have hf : ∀ a b : ℝ, Fcap 0 A pA pB a b = A * (pA * a + pB * b) := by
    intro a b; unfold Fcap; ring
  -- So the set is {l | 0 < l ∧ C ≤ A * (pA * (x/l) + pB * (y/l))}
  -- = {l | 0 < l ∧ C ≤ S / l} = {l | 0 < l ∧ l ≤ S / C}
  -- The supremum is S / C
  set l_star := S / C with hl_star_def
  have hl_star_pos : 0 < l_star := div_pos hS_pos hC
  -- Simplify the membership condition
  have hcond : ∀ l : ℝ, l > 0 → (C ≤ Fcap 0 A pA pB (x / l) (y / l) ↔ l ≤ l_star) := by
    intro l hl_pos
    rw [hf]
    have hsl : A * (pA * (x / l) + pB * (y / l)) = S / l := by
      rw [hS]; field_simp
    rw [hsl]
    rw [le_div_iff₀ hl_pos]
    rw [hl_star_def, le_div_iff₀ hC]
    ring_nf
  -- The set equals {l | 0 < l ∧ l ≤ l_star}
  have hset_eq : {l : ℝ | 0 < l ∧ C ≤ Fcap 0 A pA pB (x / l) (y / l)} = Set.Ioc 0 l_star := by
    ext l
    simp [Set.mem_Ioc]
    by_cases hl : l > 0
    · simp [hl, hcond l hl]
    · simp [hl]
  rw [hset_eq]
  exact csSup_Ioc hl_star_pos

/-- **C1.** At `κ = 1`, the canonical Capponi curve is a positive scalar
multiple of the equal-weight geometric function. -/
theorem canon_Fcap_one_eq_phiEps_half {A pA pB C x y : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C)
    (hx : 0 < x) (hy : 0 < y) :
    canon (Fcap 1 A pA pB) C x y =
      (1 / Real.sqrt C) * phiEps (1 / 2 : ℝ) x y := by
  rw [canon_Fcap_one hA hpA hpB hC hx hy]
  have h_phi : phiEps (1 / 2 : ℝ) x y = Real.sqrt (x * y) := by
    rw [phiEps]
    norm_num
    rw [← Real.mul_rpow (le_of_lt hx) (le_of_lt hy)]
    rw [Real.sqrt_eq_rpow]
  rw [h_phi]
  ring

/-- **C2.** Refutation at the explicit interior witness
`κ = 1/2`, `A = pA = pB = C = 1`: no exponent and positive scale identify
its canonical form with the weighted-geometric family on the positive orthant. -/
theorem canon_Fcap_not_phiEps :
    ¬ ∃ ε c : ℝ, 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 x y = c * phiEps ε x y := by
  intro ⟨ε, c, hc, h⟩
  -- Use x = y = 1 first
  have h1 : canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 1 1 = c * phiEps ε 1 1 := h 1 1 one_pos one_pos
  -- phiEps ε 1 1 = 1
  have hphi1 : phiEps ε 1 1 = 1 := by simp [phiEps]
  rw [hphi1, mul_one] at h1
  -- Now use x = 2, y = 1
  have h2 : canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 2 1 = c * phiEps ε 2 1 := h 2 1 (by norm_num) (by norm_num)
  -- phiEps ε 2 1 = 2^ε
  have hphi2 : phiEps ε 2 1 = (2 : ℝ) ^ ε := by simp [phiEps]
  rw [hphi2] at h2
  -- Use x = 1, y = 2
  have h3 : canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 1 2 = c * phiEps ε 1 2 := h 1 2 (by norm_num) (by norm_num)
  -- phiEps ε 1 2 = 2^(1-ε)
  have hphi3 : phiEps ε 1 2 = (2 : ℝ) ^ (1 - ε) := by simp [phiEps]
  rw [hphi3] at h3
  -- Now compute using canon_Fcap
  have hc1 : canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 1 1 = (1 + Real.sqrt 3) / 2 := by
    have := @canon_Fcap (1/2 : ℝ) 1 1 1 1 1 1 (by norm_num) (by norm_num) (by norm_num)
      (by norm_num) (by norm_num) (by norm_num) (by norm_num)
    convert this using 2 <;> ring
  have hc2 : canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 2 1 = 2 := by
    have := @canon_Fcap (1/2 : ℝ) 1 1 1 1 2 1 (by norm_num) (by norm_num) (by norm_num)
      (by norm_num) (by norm_num) (by norm_num) (by norm_num)
    convert this using 2 <;> ring
  -- canon with (1, 2) is also 2 by symmetry
  have hc3 : canon (Fcap (1 / 2 : ℝ) 1 1 1) 1 1 2 = 2 := by
    have := @canon_Fcap (1/2 : ℝ) 1 1 1 1 1 2 (by norm_num) (by norm_num) (by norm_num)
      (by norm_num) (by norm_num) (by norm_num) (by norm_num)
    convert this using 2 <;> ring
  -- From h1 and hc1: c = (1 + √3) / 2
  have hc_eq : c = (1 + Real.sqrt 3) / 2 := by rw [← h1, hc1]
  -- From h2 and hc2: c * 2^ε = 2
  have h2' : c * (2 : ℝ) ^ ε = 2 := by rw [← h2, hc2]
  -- From h3 and hc3: c * 2^(1-ε) = 2
  have h3' : c * (2 : ℝ) ^ (1 - ε) = 2 := by rw [← h3, hc3]
  -- Dividing h2' by h3': 2^(2ε-1) = 1, so ε = 1/2
  have h_div : (2 : ℝ) ^ (2 * ε - 1) = 1 := by
    have hpos : 0 < c := hc
    have h2'' : (2 : ℝ) ^ ε = 2 / c := by field_simp [hpos.ne'] at h2' ⊢; linarith
    have h3'' : (2 : ℝ) ^ (1 - ε) = 2 / c := by field_simp [hpos.ne'] at h3' ⊢; linarith
    have : (2 : ℝ) ^ ε / (2 : ℝ) ^ (1 - ε) = 1 := by rw [h2'', h3'', div_self (div_ne_zero two_ne_zero hpos.ne')]
    rw [← Real.rpow_sub (by norm_num : (0 : ℝ) < 2)] at this
    convert this using 2; ring
  have hε : ε = 1 / 2 := by
    have := Real.rpow_def_of_pos (by norm_num : (0 : ℝ) < 2)
    rw [this] at h_div
    simp at h_div
    rcases h_div with h | h
    · linarith
    · linarith
  -- With ε = 1/2, from h2': c * √2 = 2, so c = √2
  have hc_sqrt2 : c = Real.sqrt 2 := by
    have h2_half : (2 : ℝ) ^ (1 / 2 : ℝ) = Real.sqrt 2 := by rw [Real.sqrt_eq_rpow]
    rw [hε, h2_half] at h2'
    field_simp at h2'
    nlinarith [Real.sqrt_nonneg 2, Real.mul_self_sqrt (by norm_num : (0 : ℝ) ≤ 2)]
  -- But hc_eq says c = (1 + √3)/2, contradiction with c = √2
  rw [hc_sqrt2] at hc_eq
  -- Need to show √2 ≠ (1 + √3)/2, i.e., 2√2 ≠ 1 + √3, i.e., 8 ≠ (1 + √3)² = 4 + 2√3
  have h_sqrt2_pos : 0 < Real.sqrt 2 := Real.sqrt_pos.mpr (by norm_num : (0 : ℝ) < 2)
  have h_sqrt3_pos : 0 < Real.sqrt 3 := Real.sqrt_pos.mpr (by norm_num : (0 : ℝ) < 3)
  have h_sqrt2_sq : Real.sqrt 2 * Real.sqrt 2 = 2 := Real.mul_self_sqrt (by norm_num : (0 : ℝ) ≤ 2)
  have h_sqrt3_sq : Real.sqrt 3 * Real.sqrt 3 = 3 := Real.mul_self_sqrt (by norm_num : (0 : ℝ) ≤ 3)
  -- From √2 = (1 + √3)/2, we get 2√2 = 1 + √3
  have h1 : 2 * Real.sqrt 2 = 1 + Real.sqrt 3 := by linarith
  -- Squaring: 8 = 1 + 2√3 + 3 = 4 + 2√3, so 4 = 2√3, so √3 = 2
  have h2 : (2 * Real.sqrt 2) * (2 * Real.sqrt 2) = (1 + Real.sqrt 3) * (1 + Real.sqrt 3) := by rw [h1]
  nlinarith [Real.sqrt_nonneg 2, Real.sqrt_nonneg 3, h_sqrt2_sq, h_sqrt3_sq]

/-- **D1.** The landed curvature-to-share bridge sends zero curvature to the
equal share, when spacing is positive. -/
theorem tildeOfCurv_zero {Δi : ℝ} (hΔi : 0 < Δi) :
    EtaTilde.tildeOfCurv 0 Δi = (1 / 2 : ℝ) := by
  unfold EtaTilde.tildeOfCurv
  simp
  norm_num

/-- **D2.** A positive linear trading function is not a positive scalar
multiple of the equal-weight geometric function. -/
theorem linear_not_phiEps_half {A pA pB C : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C) :
    ¬ ∃ c : ℝ, 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        A * (pA * x + pB * y) / C = c * phiEps (1 / 2 : ℝ) x y := by
  intro ⟨c, hc, h_eq⟩
  -- phiEps (1/2) x y = x^(1/2) * y^(1/2) = sqrt(x * y)
  have h1 : phiEps (1 / 2 : ℝ) 1 1 = 1 := by simp [phiEps]
  have h2 : phiEps (1 / 2 : ℝ) 1 4 = 2 := by simp [phiEps]; norm_num
  have h3 : phiEps (1 / 2 : ℝ) 4 1 = 2 := by simp [phiEps]; norm_num
  -- From h_eq at (1, 1): A * (pA + pB) / C = c
  have eq1 : A * (pA + pB) / C = c := by
    have := h_eq 1 1 (by norm_num) (by norm_num)
    rw [h1] at this; ring_nf at this ⊢; linarith
  -- From h_eq at (1, 4): A * (pA + 4*pB) / C = 2*c
  have eq2 : A * (pA + 4 * pB) / C = 2 * c := by
    have := h_eq 1 4 (by norm_num) (by norm_num)
    rw [h2] at this; ring_nf at this ⊢; linarith
  -- From h_eq at (4, 1): A * (4*pA + pB) / C = 2*c
  have eq3 : A * (4 * pA + pB) / C = 2 * c := by
    have := h_eq 4 1 (by norm_num) (by norm_num)
    rw [h3] at this; ring_nf at this ⊢; linarith
  -- From eq2 = eq3: pA + 4*pB = 4*pA + pB, so pA = pB
  have hp_eq : pA = pB := by
    have : A * (pA + 4 * pB) / C = A * (4 * pA + pB) / C := by linarith
    field_simp at this
    linarith
  -- Substitute pB = pA into eq1 and eq2
  rw [hp_eq] at eq1 eq2
  -- eq1: A * (2*pA) / C = c
  -- eq2: A * (5*pA) / C = 2*c
  -- So 5 * A * pA / C = 2 * c and 2 * A * pA / C = c
  -- Multiplying eq1 by 2: 4 * A * pA / C = 2 * c = eq2
  -- But eq2 says 5 * A * pA / C = 2 * c, so 4 = 5, contradiction
  field_simp at eq1 eq2
  -- eq1: A * pB * 2 = C * c
  -- eq2: A * pB * 5 = C * c * 2
  -- From eq1: C * c = 2 * A * pB
  -- Substituting into eq2: 5 * A * pB = 2 * (2 * A * pB) = 4 * A * pB
  -- So 5 * A * pB = 4 * A * pB, meaning A * pB = 0, contradicting A > 0 and pB > 0
  have : A * pB * 5 = 4 * A * pB := by linarith
  have : A * pB = 0 := by linarith
  nlinarith [mul_pos hA hpA, mul_pos hA hpB]

/-- **D3.** The proposed same-orientation composite identification fails at
zero: Capponi's zero endpoint is not the curve selected by the project's zero
curvature index. -/
theorem curvIndex_orientation_inconsistent {A pA pB C Δi : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C)
    (hΔi : 0 < Δi) :
    ¬ ∃ c : ℝ, 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap 0 A pA pB) C x y =
          c * phiEps (EtaTilde.tildeOfCurv 0 Δi) x y := by
  rw [tildeOfCurv_zero hΔi]
  intro ⟨c, hc, h_eq⟩
  have h_eq' : ∀ x y : ℝ, 0 < x → 0 < y → A * (pA * x + pB * y) / C = c * phiEps (1 / 2) x y := by
    intro x y hx hy
    rw [← canon_Fcap_zero hA hpA hpB hC hx hy]
    exact h_eq x y hx hy
  exact linear_not_phiEps_half hA hpA hpB hC ⟨c, hc, h_eq'⟩

/-- **D4.** The agreement point is Capponi `κ = 1` but project curvature zero:
the first conjunct gives the positive canonical identification, while the
second refutes it at Capponi `κ = 0`. -/
theorem cpmm_sits_at_curvIndex_zero {A pA pB C Δi : ℝ}
    (hA : 0 < A) (hpA : 0 < pA) (hpB : 0 < pB) (hC : 0 < C)
    (hΔi : 0 < Δi) :
    (∃ c : ℝ, 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap 1 A pA pB) C x y =
          c * phiEps (EtaTilde.tildeOfCurv 0 Δi) x y) ∧
    (¬ ∃ c : ℝ, 0 < c ∧
      ∀ x y : ℝ, 0 < x → 0 < y →
        canon (Fcap 0 A pA pB) C x y =
          c * phiEps (EtaTilde.tildeOfCurv 0 Δi) x y) := by
  rw [tildeOfCurv_zero hΔi]
  refine ⟨?_, ?_⟩
  · -- For Fcap 1: use canon_Fcap_one_eq_phiEps_half
    use 1 / Real.sqrt C
    constructor
    · exact one_div_pos.mpr (Real.sqrt_pos.mpr hC)
    · intro x y hx hy
      rw [canon_Fcap_one_eq_phiEps_half hA hpA hpB hC hx hy]
  · -- For Fcap 0: use linear_not_phiEps_half
    intro ⟨c, hc, h_eq⟩
    have h_eq' : ∀ x y : ℝ, 0 < x → 0 < y → A * (pA * x + pB * y) / C = c * phiEps (1 / 2) x y := by
      intro x y hx hy
      rw [← canon_Fcap_zero hA hpA hpB hC hx hy]
      exact h_eq x y hx hy
    exact linear_not_phiEps_half hA hpA hpB hC ⟨c, hc, h_eq'⟩

/-- **E1.** Numeraire specialization of the closed form.  A single pair on one
price grid has only one independent grid price: choosing the money asset as
numeraire sets `pB = 1`, while `pA = p²`. -/
theorem canon_Fcap_numeraire {κ A p C x y : ℝ}
    (hκ : κ ∈ Icc (0 : ℝ) 1) (hA : 0 < A) (hp : 0 < p)
    (hC : 0 < C) (hx : 0 < x) (hy : 0 < y) :
    canon (Fcap κ A (p ^ 2) 1) C x y =
      ((1 - κ) * A * (p ^ 2 * x + y) +
        Real.sqrt (((1 - κ) * A * (p ^ 2 * x + y)) ^ 2 +
          4 * C * κ * x * y)) / (2 * C) := by
  convert canon_Fcap hκ hA (sq_pos_of_pos hp) (by norm_num : (0 : ℝ) < 1) hC hx hy using 2 <;> ring

end CanonicalCurve
