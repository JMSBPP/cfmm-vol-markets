import Mathlib

/-!
# The dual problem: a mapping `g` and an inner composition `⊗` for which both conditions hold

In `RequestProject/TickChangeOfVariable.lean` we showed that `g = ln` fails the separability
requirement when `⊗` is restricted to a fixed **affine** combination.  Here we solve the dual
problem: *find* a pair `(g, ⊗)` that works.

The answer is that the affine class of compositions must be abandoned, and that once it is,
the solution is forced and unique.

* **Part 1 (rigidity).**  If `g (x - y) = c₁ · g x + c₂ · g y + c₃` holds for a non-constant `g`,
  then necessarily `c₁ = 1`, `c₂ = -1`, `c₃ = g 0`; i.e. `⊗` *must* be subtraction (recentred at
  `g 0`) and `g` must be additive — affine, under continuity.  So inside the affine class no
  genuine change of variable exists: this is the structural reason `ln` cannot work there.

* **Part 2 (the dual solution).**  Enlarging `⊗` from the additive to the **multiplicative**
  group, the pair
  `g = tickMap β : i ↦ exp (β · i)`,  `u ⊗ v = u / v`
  satisfies both requirements: `g (x - y) = g x / g y` (separability) and `ln (g x) = β · x`
  (linearity — `ln ∘ g` is exactly linear in the tick), with `g` injective and inverse
  `i = ln (g i) / β`.  With `β = ln 1.0001` this `g` is nothing but the square-root price
  `√p = 1.0001^i`, so the inner composition is the ratio of square-root prices.
  Moreover `tickMap β` is the *only* such solution (`dualSolution_unique`), its composition is
  necessarily division (`isDualSolution_op_eq_div`), and it lies genuinely outside the affine
  class (`tickMap_no_affineComposition`).

* **Part 3 (the model).**  For `σ(i) = exp (α - β i)` the transformed state is exactly the
  reciprocal volatility up to scale, `σ(i) = exp α / g i`, `ln σ(i) = α - β i` is affine in the
  tick (the `C = -ln 1.0001` of the state-space representation), and the terminal condition
  `σ(N) = σ̄` pins the endpoint tick uniquely at `i(N) = (α - ln σ̄)/β`.

* **Part 4 (variance stabilisation).**  The exponential map is exactly the Lamperti transform of
  `σ(i) = exp (α - β i)`: `Λ(i) = exp (β i - α)/β` satisfies `Λ'(i) · σ(i) = 1`, so in the
  variable `Λ` the diffusion coefficient is constant — which is what makes the transformed
  recursion a state-space model with constant input matrix.  `Λ` is `tickMap β` up to an affine
  normalisation, so it carries the same multiplicative separability.
-/

namespace TickDualMapping

open Real

/-! ## Part 1: rigidity — an affine inner composition forces `⊗` to be subtraction -/

/-- `g` composes the increment through the fixed affine combination `(c₁, c₂, c₃)`. -/
def AffineComposition (g : ℝ → ℝ) (c₁ c₂ c₃ : ℝ) : Prop :=
  ∀ x y : ℝ, g (x - y) = c₁ * g x + c₂ * g y + c₃

/-- **Rigidity.**  For a non-constant `g`, an affine inner composition is forced to be
`u ⊗ v = u - v + g 0`, and `g` is forced to be additive up to the constant `g 0`. -/
theorem affineComposition_rigidity {g : ℝ → ℝ} {c₁ c₂ c₃ : ℝ}
    (h : AffineComposition g c₁ c₂ c₃) (hnc : ∃ x₀ : ℝ, g x₀ ≠ g 0) :
    c₁ = 1 ∧ c₂ = -1 ∧ c₃ = g 0 ∧
      ∀ x y : ℝ, g (x - y) - g 0 = (g x - g 0) - (g y - g 0) := by
  obtain ⟨x₀, hx₀⟩ := hnc
  -- taking `y = x` gives `g 0 = (c₁ + c₂) * g x + c₃` for every `x`
  have hdiag : ∀ x : ℝ, g 0 = (c₁ + c₂) * g x + c₃ := by
    intro x
    have hx := h x x
    rw [sub_self] at hx
    linear_combination hx
  have hsum : c₁ + c₂ = 0 := by
    have h1 := hdiag x₀
    have h2 := hdiag 0
    have hfac : (c₁ + c₂) * (g x₀ - g 0) = 0 := by linear_combination h2 - h1
    rcases mul_eq_zero.1 hfac with h' | h'
    · exact h'
    · exact absurd (by linarith : g x₀ = g 0) hx₀
  have hc₃ : c₃ = g 0 := by
    have h0 := hdiag 0
    rw [hsum, zero_mul, zero_add] at h0
    exact h0.symm
  have hc₂ : c₂ = -c₁ := by linarith
  -- taking `y = 0` gives `(1 - c₁) * (g x - g 0) = 0`
  have hzero : ∀ x : ℝ, (1 - c₁) * (g x - g 0) = 0 := by
    intro x
    have hx := h x 0
    rw [sub_zero, hc₃, hc₂] at hx
    linear_combination hx
  have hc₁ : c₁ = 1 := by
    rcases mul_eq_zero.1 (hzero x₀) with h' | h'
    · linarith
    · exact absurd (by linarith : g x₀ = g 0) hx₀
  refine ⟨hc₁, by rw [hc₂, hc₁], hc₃, fun x y => ?_⟩
  have hxy := h x y
  rw [hc₁, hc₂, hc₁, hc₃] at hxy
  linarith

/-- Under continuity, rigidity says that the only non-constant `g` admitting an affine inner
composition is an affine function. -/
theorem affineComposition_forces_affine {g : ℝ → ℝ} {c₁ c₂ c₃ : ℝ}
    (hg : Continuous g) (h : AffineComposition g c₁ c₂ c₃) (hnc : ∃ x₀ : ℝ, g x₀ ≠ g 0) :
    ∀ x : ℝ, g x = g 0 + (g 1 - g 0) * x := by
  obtain ⟨-, -, -, hadd⟩ := affineComposition_rigidity h hnc
  have hmap : ∀ x y : ℝ, g (x + y) - g 0 = (g x - g 0) + (g y - g 0) := by
    intro x y
    have hneg : g (-y) - g 0 = -(g y - g 0) := by
      have h1 := hadd 0 y
      rw [zero_sub] at h1
      linarith
    have h2 := hadd x (-y)
    rw [sub_neg_eq_add] at h2
    linarith
  let H : ℝ →+ ℝ := AddMonoidHom.mk' (fun x => g x - g 0) hmap
  have hHc : Continuous ⇑H := hg.sub continuous_const
  intro x
  have hsmul : H (x • (1 : ℝ)) = x • H 1 := map_real_smul H hHc x 1
  simp only [smul_eq_mul, mul_one] at hsmul
  have hHx : g x - g 0 = x * (g 1 - g 0) := hsmul
  linarith

/-! ## Part 2: the dual solution — exponential mapping with multiplicative composition -/

/-- The change of variable `g : i ↦ exp (β · i)`.  For `β = ln 1.0001` this is the square-root
price `√p = 1.0001^i` attached to the tick `i`. -/
noncomputable def tickMap (β : ℝ) : ℝ → ℝ := fun i => Real.exp (β * i)

@[simp] theorem tickMap_apply (β i : ℝ) : tickMap β i = Real.exp (β * i) := rfl

theorem tickMap_pos (β i : ℝ) : 0 < tickMap β i := Real.exp_pos _

/-- **Separability** with the inner composition `u ⊗ v = u / v`. -/
theorem tickMap_separable (β x y : ℝ) : tickMap β (x - y) = tickMap β x / tickMap β y := by
  simp [tickMap, mul_sub, Real.exp_sub]

/-- `tickMap β` is a homomorphism from `(ℝ, +)` to `(ℝ_{>0}, ×)`. -/
theorem tickMap_add (β x y : ℝ) : tickMap β (x + y) = tickMap β x * tickMap β y := by
  simp [tickMap, mul_add, Real.exp_add]

/-- **Linearity**: `ln ∘ g` is exactly linear in the tick. -/
theorem tickMap_log_linear (β i : ℝ) : Real.log (tickMap β i) = β * i := by
  simp [tickMap, Real.log_exp]

/-- The inverse of the change of variable is recoverable. -/
theorem tickMap_leftInverse (β : ℝ) (hβ : β ≠ 0) (i : ℝ) :
    Real.log (tickMap β i) / β = i := by
  rw [tickMap_log_linear]
  field_simp

theorem tickMap_injective (β : ℝ) (hβ : β ≠ 0) : Function.Injective (tickMap β) := by
  intro x y hxy
  have hlog := congrArg Real.log hxy
  rw [tickMap_log_linear, tickMap_log_linear] at hlog
  exact mul_left_cancel₀ hβ hlog

theorem tickMap_range (β : ℝ) (hβ : β ≠ 0) : Set.range (tickMap β) = Set.Ioi (0 : ℝ) := by
  ext z
  constructor
  · rintro ⟨i, rfl⟩
    exact tickMap_pos β i
  · intro hz
    refine ⟨Real.log z / β, ?_⟩
    simp only [tickMap]
    rw [mul_div_cancel₀ _ hβ, Real.exp_log (Set.mem_Ioi.1 hz)]

/-- The requirements the dual problem asks for: a separable, linearising, injective mapping. -/
structure IsDualSolution (g : ℝ → ℝ) (op : ℝ → ℝ → ℝ) (β : ℝ) : Prop where
  /-- Separability: `g` turns the tick increment into the inner composition `op` of the
  transformed endpoints. -/
  separable : ∀ x y : ℝ, g (x - y) = op (g x) (g y)
  /-- Linearity: after the transform, the tick is read off linearly. -/
  logLinear : ∀ x : ℝ, Real.log (g x) = β * x
  /-- The transform is injective, hence invertible on its range. -/
  injective : Function.Injective g

/-- **The dual problem is solved by `(g, ⊗) = (exp (β ·), /)`.** -/
theorem tickMap_isDualSolution (β : ℝ) (hβ : β ≠ 0) :
    IsDualSolution (tickMap β) (fun u v => u / v) β where
  separable := tickMap_separable β
  logLinear := tickMap_log_linear β
  injective := tickMap_injective β hβ

/-- **Uniqueness of the mapping.**  Any positive solution of the dual problem is `tickMap β`. -/
theorem dualSolution_unique {g : ℝ → ℝ} {op : ℝ → ℝ → ℝ} {β : ℝ}
    (hpos : ∀ x, 0 < g x) (h : IsDualSolution g op β) : g = tickMap β := by
  funext x
  have hx : Real.exp (Real.log (g x)) = Real.exp (β * x) := by rw [h.logLinear x]
  rwa [Real.exp_log (hpos x)] at hx

/-- **Uniqueness of the inner composition.**  On the range of a positive solution the
composition is forced to be division. -/
theorem isDualSolution_op_eq_div {g : ℝ → ℝ} {op : ℝ → ℝ → ℝ} {β : ℝ}
    (hpos : ∀ x, 0 < g x) (h : IsDualSolution g op β) (x y : ℝ) :
    op (g x) (g y) = g x / g y := by
  have hg := dualSolution_unique hpos h
  have hdiv : g (x - y) = g x / g y := by
    rw [hg]; exact tickMap_separable β x y
  rw [h.separable x y] at hdiv
  exact hdiv

/-- Any positive continuous `g` satisfying multiplicative separability is an exponential:
the multiplicative composition already determines the mapping. -/
theorem mulSeparable_unique {g : ℝ → ℝ} (hpos : ∀ x, 0 < g x) (hg : Continuous g)
    (h : ∀ x y : ℝ, g (x - y) = g x / g y) :
    g = tickMap (Real.log (g 1)) := by
  have hLsub : ∀ x y : ℝ, Real.log (g (x - y)) = Real.log (g x) - Real.log (g y) := by
    intro x y
    rw [h x y, Real.log_div (hpos x).ne' (hpos y).ne']
  have hLc : Continuous fun x => Real.log (g x) :=
    Real.continuousOn_log.comp_continuous hg fun x => by simpa using (hpos x).ne'
  have hLadd : ∀ x y : ℝ, Real.log (g (x + y)) = Real.log (g x) + Real.log (g y) := by
    intro x y
    have h0 : Real.log (g 0) = 0 := by
      have := hLsub 0 0
      simpa using this
    have hneg : Real.log (g (-y)) = -Real.log (g y) := by
      have h1 := hLsub 0 y
      rw [zero_sub, h0] at h1
      linarith
    have h2 := hLsub x (-y)
    rw [sub_neg_eq_add, hneg] at h2
    linarith
  let H : ℝ →+ ℝ := AddMonoidHom.mk' (fun x => Real.log (g x)) hLadd
  have hHc : Continuous ⇑H := hLc
  funext x
  have hsmul : H (x • (1 : ℝ)) = x • H 1 := map_real_smul H hHc x 1
  simp only [smul_eq_mul, mul_one] at hsmul
  have hLx : Real.log (g x) = x * Real.log (g 1) := hsmul
  have hx : Real.exp (Real.log (g x)) = Real.exp (Real.log (g 1) * x) := by
    rw [hLx, mul_comm]
  rwa [Real.exp_log (hpos x)] at hx

/-- The dual solution is genuinely outside the affine class: `tickMap β` admits no affine inner
composition when `β ≠ 0`.  This is why requirement (2) had to be read multiplicatively. -/
theorem tickMap_no_affineComposition (β : ℝ) (hβ : β ≠ 0) (c₁ c₂ c₃ : ℝ) :
    ¬ AffineComposition (tickMap β) c₁ c₂ c₃ := by
  intro h
  have e0 : tickMap β 0 = 1 := by simp [tickMap]
  have e1 : tickMap β 1 = Real.exp β := by simp [tickMap]
  have e2 : tickMap β 2 = Real.exp β * Real.exp β := by
    rw [tickMap, ← Real.exp_add]
    ring_nf
  have hnc : ∃ x₀ : ℝ, tickMap β x₀ ≠ tickMap β 0 := by
    refine ⟨1, ?_⟩
    rw [e0, e1]
    intro hcon
    exact hβ ((Real.exp_eq_one_iff β).1 hcon)
  have hcont : Continuous (tickMap β) :=
    Real.continuous_exp.comp (continuous_const.mul continuous_id)
  have haff := affineComposition_forces_affine hcont h hnc
  have h2 := haff 2
  rw [e0, e1, e2] at h2
  have hE : Real.exp β = 1 := by nlinarith [h2]
  exact hβ ((Real.exp_eq_one_iff β).1 hE)

/-! ## Part 3: the volatility model in the transformed variable -/

/-- The tick-dependent volatility `σ(i) = exp (α - β i)`; with `α = ln (σ_F / (L · ln 1.0001))`
and `β = ln 1.0001` this is the `σ(i) = e^{α - β i}` of the derivation. -/
noncomputable def vol (α β : ℝ) (i : ℝ) : ℝ := Real.exp (α - β * i)

theorem vol_pos (α β i : ℝ) : 0 < vol α β i := Real.exp_pos _

/-- `ln σ` is affine in the tick: the output equation `ln σ = C · i + α` with `C = -β`. -/
theorem log_vol_affine (α β i : ℝ) : Real.log (vol α β i) = α - β * i := by
  simp [vol, Real.log_exp]

/-- In the transformed variable the volatility becomes a *linear* output map: the transformed
state is the reciprocal volatility up to the scale `exp α`. -/
theorem vol_eq_div_tickMap (α β i : ℝ) : vol α β i = Real.exp α / tickMap β i := by
  simp [vol, tickMap, Real.exp_sub]

theorem tickMap_eq_div_vol (α β i : ℝ) : tickMap β i = Real.exp α / vol α β i := by
  rw [vol_eq_div_tickMap]
  have h1 : Real.exp α ≠ 0 := (Real.exp_pos α).ne'
  have h2 : tickMap β i ≠ 0 := (tickMap_pos β i).ne'
  field_simp

/-- **Terminal condition.**  `σ(N) = σ̄` determines the endpoint tick uniquely, and it is the
`i(N) = (α - ln σ̄)/β` of the derivation (with `β = ln 1.0001`). -/
theorem terminal_tick_unique (α β σbar : ℝ) (hβ : β ≠ 0) (hσ : 0 < σbar) (i : ℝ) :
    vol α β i = σbar ↔ i = (α - Real.log σbar) / β := by
  constructor
  · intro hv
    have hlog := congrArg Real.log hv
    rw [log_vol_affine] at hlog
    rw [eq_div_iff hβ]
    linear_combination -hlog
  · intro hi
    subst hi
    rw [vol, mul_div_cancel₀ _ hβ,
      show α - (α - Real.log σbar) = Real.log σbar by ring, Real.exp_log hσ]

/-! ## Part 4: the exponential map is the Lamperti (variance-stabilising) transform -/

/-- The Lamperti transform of the diffusion coefficient `σ(i) = exp (α - β i)`:
`Λ(i) = ∫ dz / σ(z)`, normalised as `exp (β i - α)/β`. -/
noncomputable def lamperti (α β : ℝ) : ℝ → ℝ := fun i => Real.exp (β * i - α) / β

theorem lamperti_hasDerivAt (α β : ℝ) (hβ : β ≠ 0) (i : ℝ) :
    HasDerivAt (lamperti α β) (Real.exp (β * i - α)) i := by
  have h1 : HasDerivAt (fun x : ℝ => β * x - α) β i := by
    simpa using ((hasDerivAt_id i).const_mul β).sub_const α
  have h2 := (h1.exp).div_const β
  have hEq : Real.exp (β * i - α) * β / β = Real.exp (β * i - α) := by
    field_simp
  rwa [hEq] at h2

/-- **Variance stabilisation.**  `Λ'(i) · σ(i) = 1`: in the variable `Λ` the diffusion
coefficient is identically `1`, so the noise enters the transformed recursion with a constant
input matrix — this is precisely the state-space form sought. -/
theorem lamperti_stabilises_variance (α β : ℝ) (hβ : β ≠ 0) (i : ℝ) :
    deriv (lamperti α β) i * vol α β i = 1 := by
  rw [(lamperti_hasDerivAt α β hβ i).deriv, vol, ← Real.exp_add,
    show β * i - α + (α - β * i) = 0 by ring, Real.exp_zero]

/-- The Lamperti transform is `tickMap β` up to the affine normalisation
`Λ = (exp (-α) / β) · tickMap β`, so it carries the same multiplicative separability. -/
theorem lamperti_eq_tickMap (α β : ℝ) (i : ℝ) :
    lamperti α β i = Real.exp (-α) / β * tickMap β i := by
  simp only [lamperti, tickMap, Real.exp_sub, Real.exp_neg]
  field_simp

theorem lamperti_strictMono (α β : ℝ) (hβ : 0 < β) : StrictMono (lamperti α β) := by
  intro x y hxy
  have hlt : Real.exp (β * x - α) < Real.exp (β * y - α) := by
    apply Real.exp_lt_exp.2
    nlinarith
  simpa [lamperti, div_eq_mul_inv] using mul_lt_mul_of_pos_right hlt (inv_pos.2 hβ)

end TickDualMapping
