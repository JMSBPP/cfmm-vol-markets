import Mathlib

/-!
# No change of variable `g` is simultaneously *linear* and *separable* on tick increments

Setting.  A tick path is a sequence of ticks `i(t_0), i(t_1), …` and its increment is
`Δi(t_j) = i(t_j) - i(t_{j-1})`.  One looks for an injective change of variable
`g` (with recoverable inverse) such that, writing `x = i(t_j)` and `y = i(t_{j-1})`,

* **(1) Linearity**    `g (x - y) = a + β * x`,
* **(2) Separability** `g (x - y) = g x ⊗ g y` for a *fixed affine* combination `⊗`,
  i.e. `g (x - y) = c₁ * g x + c₂ * g y + c₃`.

Requiring `⊗` to be affine is exactly what makes the resulting representation a linear
state-space model; without that restriction (2) is vacuous for any injective `g`, since
one may simply take `u ⊗ v := g (g⁻¹ u - g⁻¹ v)`.

Results.

* `TickChangeOfVariable.log_satisfies_linearity_pathwise`: along a path whose increments are
  log-affine in the state, `g = Real.log` does satisfy (1).  This is the sense in which
  "`ln` fulfils 1".
* `TickChangeOfVariable.log_not_affinelySeparable`: `g = Real.log` does **not** satisfy (2).
  This is the sense in which "`ln` does not fulfil 2".
* `TickChangeOfVariable.linearity_forces_constant` and
  `TickChangeOfVariable.no_injective_linearity`: as a *functional identity* on all admissible
  pairs, (1) is already fatal — it forces `β = 0` and `g` constant on `(0, ∞)`, so no injective
  `g` can satisfy it.  In particular `Real.log` does not satisfy (1) as a functional identity
  (`TickChangeOfVariable.log_not_linearity`); it only satisfies it pathwise.

The *dual* problem — exhibiting a mapping and an inner composition for which both requirements
do hold — is solved in `RequestProject/TickDualMapping.lean`.
-/

namespace TickChangeOfVariable

open Real

/-- Admissible pairs `(x, y) = (i(t_j), i(t_{j-1}))`: the previous tick and the increment
`x - y` are both positive, so that `Real.log` is meaningful at `x`, `y` and `x - y`. -/
def IncrPairs : Set (ℝ × ℝ) := {p : ℝ × ℝ | 0 < p.2 ∧ p.2 < p.1}

lemma mem_IncrPairs {x y : ℝ} (hy : 0 < y) (hxy : y < x) : (x, y) ∈ IncrPairs := ⟨hy, hxy⟩

/-- Condition (1): `g` applied to the increment is affine in the *current* tick alone. -/
def Linearity (g : ℝ → ℝ) (a β : ℝ) : Prop :=
  ∀ p ∈ IncrPairs, g (p.1 - p.2) = a + β * p.1

/-- Condition (2) with `⊗` a fixed affine combination: `g` turns the increment into a
fixed affine function of the transformed endpoints. -/
def AffinelySeparable (g : ℝ → ℝ) : Prop :=
  ∃ c₁ c₂ c₃ : ℝ, ∀ p ∈ IncrPairs, g (p.1 - p.2) = c₁ * g p.1 + c₂ * g p.2 + c₃

/-! ## `ln` satisfies the linearity requirement along a log-affine path -/

/-- If the increments of the tick path are log-affine in the state,
`Δi(t_j) = exp (a + β * i(t_j))`, then `g = ln` linearises them: `ln (Δi(t_j)) = a + β i(t_j)`.
This is condition (1) in its pathwise form. -/
theorem log_satisfies_linearity_pathwise (i Δi : ℕ → ℝ) (a β : ℝ)
    (h : ∀ j, Δi j = Real.exp (a + β * i j)) :
    ∀ j, Real.log (Δi j) = a + β * i j := by
  intro j
  rw [h j, Real.log_exp]

/-- With a multiplicative noise factor `w j > 0` the same computation gives condition (1)
up to the additive noise term `ln (w j)`. -/
theorem log_satisfies_linearity_pathwise_noise (i Δi w : ℕ → ℝ) (a β : ℝ)
    (hw : ∀ j, 0 < w j) (h : ∀ j, Δi j = Real.exp (a + β * i j) * w j) :
    ∀ j, Real.log (Δi j) = a + β * i j + Real.log (w j) := by
  intro j
  rw [h j, Real.log_mul (Real.exp_ne_zero _) (hw j).ne', Real.log_exp]

/-! ## `ln` fails the separability requirement -/

private lemma log_nine_ne_log_eight : 2 * Real.log 3 ≠ 3 * Real.log 2 := by
  have h9 : Real.log 9 = 2 * Real.log 3 := by
    rw [show (9 : ℝ) = 3 ^ (2 : ℕ) by norm_num, Real.log_pow]
    push_cast
    ring
  have h8 : Real.log 8 = 3 * Real.log 2 := by
    rw [show (8 : ℝ) = 2 ^ (3 : ℕ) by norm_num, Real.log_pow]
    push_cast
    ring
  have hlt : Real.log 8 < Real.log 9 :=
    Real.log_lt_log (by norm_num) (by norm_num)
  rw [h8, h9] at hlt
  exact fun h => absurd h (ne_of_gt hlt)

/-- **`ln` is not affinely separable.**  There is no fixed affine combination `⊗` with
`ln (x - y) = ln x ⊗ ln y` for all admissible pairs. -/
theorem log_not_affinelySeparable : ¬ AffinelySeparable Real.log := by
  rintro ⟨c₁, c₂, c₃, h⟩
  have hL2 : 0 < Real.log 2 := Real.log_pos (by norm_num)
  -- instantiate at four admissible pairs
  have e1 := h (2, 1) (mem_IncrPairs (by norm_num) (by norm_num))
  have e2 := h (3, 1) (mem_IncrPairs (by norm_num) (by norm_num))
  have e3 := h (3, 2) (mem_IncrPairs (by norm_num) (by norm_num))
  have e4 := h (4, 2) (mem_IncrPairs (by norm_num) (by norm_num))
  norm_num [Real.log_one] at e1 e2 e3 e4
  rw [show (4 : ℝ) = 2 ^ (2 : ℕ) by norm_num, Real.log_pow] at e4
  push_cast at e4
  -- e1 : 0 = c₁ * log 2 + c₃
  -- e2 : log 2 = c₁ * log 3 + c₃
  -- e3 : 0 = c₁ * log 3 + c₂ * log 2 + c₃
  -- e4 : log 2 = c₁ * (2 * log 2) + c₂ * log 2 + c₃
  have hc₁ : c₁ * (2 * Real.log 3 - 3 * Real.log 2) = 0 := by linarith
  have hc₁0 : c₁ = 0 := by
    rcases mul_eq_zero.1 hc₁ with h' | h'
    · exact h'
    · exact absurd (by linarith : 2 * Real.log 3 = 3 * Real.log 2) log_nine_ne_log_eight
  subst hc₁0
  -- now e1 gives c₃ = 0 and e2 gives log 2 = 0
  linarith

/-! ## The linearity requirement alone is incompatible with injectivity -/

/-- Condition (1), read as a functional identity over all admissible pairs, forces the slope
`β` to vanish and `g` to be constant on `(0, ∞)`. -/
theorem linearity_forces_constant {g : ℝ → ℝ} {a β : ℝ} (h : Linearity g a β) :
    β = 0 ∧ ∀ z : ℝ, 0 < z → g z = a := by
  have key : ∀ z : ℝ, 0 < z → ∀ c : ℝ, 0 < c → g z = a + β * (z + c) := by
    intro z hz c hc
    have := h (z + c, c) (mem_IncrPairs hc (by linarith))
    simpa using this
  have hβ : β = 0 := by
    have h1 := key 1 (by norm_num) 1 (by norm_num)
    have h2 := key 1 (by norm_num) 2 (by norm_num)
    linarith
  refine ⟨hβ, fun z hz => ?_⟩
  have := key z hz 1 (by norm_num)
  rw [hβ] at this
  simpa using this

/-- **No-go.**  No injective change of variable satisfies condition (1). -/
theorem no_injective_linearity :
    ¬ ∃ (g : ℝ → ℝ) (a β : ℝ), Linearity g a β ∧ Set.InjOn g (Set.Ioi (0 : ℝ)) := by
  rintro ⟨g, a, β, hlin, hinj⟩
  obtain ⟨-, hconst⟩ := linearity_forces_constant hlin
  have h12 : g 1 = g 2 := by rw [hconst 1 (by norm_num), hconst 2 (by norm_num)]
  have : (1 : ℝ) = 2 :=
    hinj (Set.mem_Ioi.2 (by norm_num)) (Set.mem_Ioi.2 (by norm_num)) h12
  norm_num at this

/-- In particular `Real.log` does not satisfy condition (1) as a functional identity:
its pathwise validity (`log_satisfies_linearity_pathwise`) cannot be upgraded to an identity
on all admissible pairs. -/
theorem log_not_linearity : ¬ ∃ a β : ℝ, Linearity Real.log a β := by
  rintro ⟨a, β, h⟩
  obtain ⟨-, hconst⟩ := linearity_forces_constant h
  have h1 : Real.log 1 = a := hconst 1 (by norm_num)
  have h2 : Real.log 2 = a := hconst 2 (by norm_num)
  rw [Real.log_one] at h1
  have : (0 : ℝ) < Real.log 2 := Real.log_pos (by norm_num)
  rw [h2, ← h1] at this
  exact lt_irrefl _ this

/-- **Summary no-go.**  There is no injective change of variable `g` satisfying both
requirement (1) (linearity) and requirement (2) (affine separability). -/
theorem no_injective_linear_and_separable :
    ¬ ∃ (g : ℝ → ℝ) (a β : ℝ),
      Linearity g a β ∧ AffinelySeparable g ∧ Set.InjOn g (Set.Ioi (0 : ℝ)) := by
  rintro ⟨g, a, β, hlin, -, hinj⟩
  exact no_injective_linearity ⟨g, a, β, hlin, hinj⟩

end TickChangeOfVariable
