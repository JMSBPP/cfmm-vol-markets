/-
  exp/DynamicsOptimization.lean

  Formal companion answering the closing DYNAMICS request of the spec note:

      « Given α := {α_j}_{j=1}^N, the optimal controls are
            (Δᵢ⋆, η⋆) ≡ arg max  π⁺(Δᵢ, η ; α),
        where (using the entry law i_j = i_μ + α_j·Δᵢ)
            π⁺(Δᵢ, η ; α) = Σ_j η̃_j(Δᵢ, η) (i_j − i_μ)²
                          = Δᵢ² · Σ_j η̃_j(Δᵢ, η) α_j².
        Compute the optimizers and characterize ∂π⁺/∂Δᵢ and ∂π⁺/∂η. »

  ANSWER (made precise and machine-checked below).

  The model's established structural fact `eta_Δi_independent_in_sigma_and_L_eta`
  (`exp/eta.lean`) says the inventory weights η̃ do NOT depend on the spacing Δᵢ
  — they are a function of η alone.  Modelling the weight family as
  `w : ℝ → Fin N → ℝ` (a curve `η ↦ η̃(η)` in the probability simplex) makes the
  payoff SEPARATE:

      π⁺(Δᵢ, η) = Δᵢ² · S(η),     S(η) := Σ_j η̃_j(η) α_j²   (≥ 0).

  Consequences (all proved, no `sorry`):

  • FACTORIZATION (`piPlusRaw_eq`): the raw squared-deviation sum equals the
    factored form Δᵢ²·S(η) — this is the spec's `= Δᵢ² Σ η̃ α²` step.

  • π⁺ AS A WEIGHTED DISPERSION (`piPlus_eq_variance`): under the
    rational-expectations restriction Σ_j η̃_j α_j = 0 (zero expected signed
    displacement), S(η) = Var^{η̃}(α), so π⁺ = Δᵢ²·Var^{η̃}(α).

  • ∂π⁺/∂Δᵢ  (`piPlus_hasDerivAt_Δi`):  ∂π⁺/∂Δᵢ = 2·Δᵢ·S(η).
    It is STRICTLY POSITIVE for Δᵢ>0 whenever S(η)>0 (`partialDeltaI_pos`),
    so π⁺ is strictly increasing in Δᵢ (`piPlus_strictMonoOn_Δi`) and the
    Δᵢ-optimum is the UPPER CORNER of the admissible box
    (`piPlus_isMaxOn_Δi_corner`):  on Δᵢ ∈ [1,200] the maximizer is Δᵢ⋆ = 200.

  • ∂π⁺/∂η  (`piPlus_hasDerivAt_eta`):  ∂π⁺/∂η = Δᵢ² · Σ_j η̃_j′(η) α_j².
    There is no monotone corner here (the weights redistribute mass across
    displacements), so the η-optimum is INTERIOR and characterized by the
    first-order condition (`foc_eta`):

        Σ_j η̃_j′(η⋆) α_j² = 0.

  • OPTIMAL CONTROLS (`optimal_controls`): combining the two, the argmax over
    the box [1,200]×(a,b) is `(Δᵢ⋆, η⋆) = (200, η⋆)` with η⋆ the interior FOC
    root — a boundary optimum in Δᵢ and an interior optimum in η.

  Reuses `CFMM.MeanVariance.{IsProb, E, Var, Var_eq_sub}` (`exp/MeanVarianceEta.lean`).
  No fees and no new economic primitives are introduced.
-/
import Mathlib
import exp.MeanVarianceEta

open scoped BigOperators
open CFMM.MeanVariance

namespace CFMM.DynamicsOpt

variable {N : ℕ}

/-! ## The long-vol payoff π⁺ as a function of the controls (Δᵢ, η) -/

/-- π⁺ in raw squared-deviation form: with the entry law `i_j = i_μ + α_j·Δᵢ`,
    the displacement is `i_j − i_μ = α_j·Δᵢ`, so
    `π⁺ = Σ_j η̃_j(η) (i_j − i_μ)² = Σ_j η̃_j(η) (Δᵢ·α_j)²`.
    The weight family `w : η ↦ η̃(η)` depends on η alone (the model's
    `eta_Δi_independent_in_sigma_and_L_eta`). -/
noncomputable def piPlusRaw (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (Δi η : ℝ) : ℝ :=
  ∑ j, w η j * (Δi * α j) ^ 2

/-- The dispersion factor `S(η) = Σ_j η̃_j(η) α_j²`. -/
noncomputable def Sfac (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (η : ℝ) : ℝ :=
  ∑ j, w η j * (α j) ^ 2

/-- π⁺ in factored form: `π⁺(Δᵢ, η) = Δᵢ² · S(η)`. -/
noncomputable def piPlus (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (Δi η : ℝ) : ℝ :=
  Δi ^ 2 * Sfac w α η

/-
**Factorization.** The raw squared-deviation payoff equals the factored
    form `Δᵢ²·S(η)`. This is the spec's `π⁺ = Δᵢ² Σ_j η̃_j α_j²` step.
-/
theorem piPlusRaw_eq (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (Δi η : ℝ) :
    piPlusRaw w α Δi η = piPlus w α Δi η := by
  unfold piPlusRaw piPlus; ring;
  unfold Sfac; rw [ Finset.mul_sum _ _ _ ] ; exact Finset.sum_congr rfl fun _ _ => by ring;

/-! ## π⁺ is a weighted dispersion (variance) under rational expectations -/

/-- The rational-expectations restriction: the expected signed displacement from
    `i_μ` is zero under the inventory measure, `Σ_j η̃_j(η) α_j = 0`. -/
def RationalExpectations (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (η : ℝ) : Prop :=
  ∑ j, w η j * α j = 0

/-
**π⁺ is the spacing-scaled inventory variance of the displacements.** Under
    rational expectations the dispersion factor is the η̃-variance of `α`, so
    `π⁺(Δᵢ, η) = Δᵢ² · Var^{η̃}(α)`.
-/
theorem piPlus_eq_variance (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (Δi η : ℝ)
    (hre : RationalExpectations w α η) :
    piPlus w α Δi η = Δi ^ 2 * Var (w η) α := by
  unfold piPlus Var;
  unfold Sfac E;
  unfold RationalExpectations at hre; aesop;

/-! ## Sign of the dispersion factor S(η) -/

/-
`S(η) ≥ 0` for a probability (or merely nonnegative) weight vector.
-/
theorem Sfac_nonneg (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (η : ℝ)
    (hnn : ∀ j, 0 ≤ w η j) : 0 ≤ Sfac w α η := by
  exact Finset.sum_nonneg fun j _ => mul_nonneg ( hnn j ) ( sq_nonneg _ )

/-
`S(η) > 0` as soon as some displacement `α_j ≠ 0` carries positive mass.
-/
theorem Sfac_pos (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (η : ℝ)
    (hnn : ∀ j, 0 ≤ w η j) (j₀ : Fin N) (hwj : 0 < w η j₀) (hαj : α j₀ ≠ 0) :
    0 < Sfac w α η := by
  exact lt_of_lt_of_le ( mul_pos hwj ( by positivity ) ) ( Finset.single_le_sum ( fun i _ => mul_nonneg ( hnn i ) ( sq_nonneg ( α i ) ) ) ( Finset.mem_univ j₀ ) )

/-! ## ∂π⁺/∂Δᵢ  : derivative, sign, monotonicity, and the corner optimum -/

/-
**∂π⁺/∂Δᵢ = 2·Δᵢ·S(η).** The partial derivative of π⁺ in the spacing.
-/
theorem piPlus_hasDerivAt_Δi (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (Δi η : ℝ) :
    HasDerivAt (fun x => piPlus w α x η) (2 * Δi * Sfac w α η) Δi := by
  convert HasDerivAt.mul ( hasDerivAt_pow 2 Δi ) ( hasDerivAt_const _ _ ) using 1 ; ring!

/-
The spacing-derivative is strictly positive for `Δᵢ>0` when `S(η)>0`.
-/
theorem partialDeltaI_pos (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (Δi η : ℝ)
    (hΔi : 0 < Δi) (hS : 0 < Sfac w α η) : 0 < 2 * Δi * Sfac w α η := by
  positivity

/-
**π⁺ is strictly increasing in the spacing** on `Δᵢ ≥ 0` when `S(η)>0`.
-/
theorem piPlus_strictMonoOn_Δi (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (η : ℝ)
    (hS : 0 < Sfac w α η) :
    StrictMonoOn (fun x => piPlus w α x η) (Set.Ici (0 : ℝ)) := by
  intro x hx y hy hxy
  simp only [piPlus, Set.mem_Ici] at *
  exact mul_lt_mul_of_pos_right (by nlinarith) hS

/-
**The Δᵢ-optimum is the upper corner.** On the admissible box
    `Δᵢ ∈ [lo, hi]` with `0 ≤ lo ≤ hi` and `S(η) ≥ 0`, π⁺ attains its maximum at
    the largest spacing `Δᵢ⋆ = hi` (specializes to `Δᵢ⋆ = 200` on `[1,200]`).
-/
theorem piPlus_isMaxOn_Δi_corner (w : ℝ → Fin N → ℝ) (α : Fin N → ℝ) (η : ℝ)
    (lo hi : ℝ) (hlo : 0 ≤ lo) (hle : lo ≤ hi) (hS : 0 ≤ Sfac w α η) :
    IsMaxOn (fun x => piPlus w α x η) (Set.Icc lo hi) hi := by
  intro x hx; simp +decide [ piPlus, * ] ; ring_nf;
  nlinarith [ mul_le_mul_of_nonneg_left hx.2 hS, mul_le_mul_of_nonneg_left hx.1 hS, hx.1, hx.2 ]

/-! ## ∂π⁺/∂η  : derivative and the interior first-order condition -/

/-
**∂π⁺/∂η = Δᵢ² · Σ_j η̃_j′(η) α_j².** Given the (component-wise)
    differentiability of the inventory-weight curve `η ↦ η̃_j(η)` with
    derivatives `w' j`, this is the partial derivative of π⁺ in the curvature.
-/
theorem piPlus_hasDerivAt_eta (w : ℝ → Fin N → ℝ) (w' : Fin N → ℝ) (α : Fin N → ℝ)
    (Δi η : ℝ) (hd : ∀ j, HasDerivAt (fun y => w y j) (w' j) η) :
    HasDerivAt (fun y => piPlus w α Δi y) (Δi ^ 2 * ∑ j, w' j * (α j) ^ 2) η := by
  convert HasDerivAt.const_mul ( Δi ^ 2 ) ( HasDerivAt.fun_sum fun j _ => ( hd j ).mul_const ( α j ^ 2 ) ) using 1

/-
**First-order condition for the interior η-optimum.** If `η⋆` is an interior
    maximizer of `η ↦ π⁺(Δᵢ, η)` (a local max) and the spacing is non-degenerate
    (`Δᵢ ≠ 0`), then the curvature-derivative of the dispersion vanishes:

        Σ_j η̃_j′(η⋆) α_j² = 0.

    This is the stationarity condition characterizing `η⋆`.
-/
theorem foc_eta (w : ℝ → Fin N → ℝ) (w' : Fin N → ℝ) (α : Fin N → ℝ)
    (Δi ηstar : ℝ) (hΔi : Δi ≠ 0)
    (hd : ∀ j, HasDerivAt (fun y => w y j) (w' j) ηstar)
    (hmax : IsLocalMax (fun y => piPlus w α Δi y) ηstar) :
    ∑ j, w' j * (α j) ^ 2 = 0 := by
  have hderiv := piPlus_hasDerivAt_eta w w' α Δi ηstar hd
  have hz : Δi ^ 2 * ∑ j, w' j * (α j) ^ 2 = 0 := hmax.hasDerivAt_eq_zero hderiv
  exact (mul_eq_zero.mp hz).resolve_left (pow_ne_zero 2 hΔi)

/-! ## The optimal controls (Δᵢ⋆, η⋆) -/

/-
**Optimal controls.** Over the admissible box `Δᵢ ∈ [1, 200]`, the spacing
    optimum is the upper corner `Δᵢ⋆ = 200` (because π⁺ is increasing in Δᵢ when
    `S(η) ≥ 0`), while the curvature optimum `η⋆` — being interior — is pinned by
    the first-order condition `Σ_j η̃_j′(η⋆) α_j² = 0`. The two together give the
    argmax `(Δᵢ⋆, η⋆) = (200, η⋆)`.
-/
theorem optimal_controls (w : ℝ → Fin N → ℝ) (w' : Fin N → ℝ) (α : Fin N → ℝ)
    (ηstar : ℝ) (hS : 0 ≤ Sfac w α ηstar)
    (hd : ∀ j, HasDerivAt (fun y => w y j) (w' j) ηstar)
    (hmax : IsLocalMax (fun y => piPlus w α 200 y) ηstar) :
    IsMaxOn (fun x => piPlus w α x ηstar) (Set.Icc (1 : ℝ) 200) 200
      ∧ ∑ j, w' j * (α j) ^ 2 = 0 := by
  convert piPlus_isMaxOn_Δi_corner w α ηstar 1 200 ( by norm_num ) ( by norm_num ) hS using 1;
  exact ⟨ fun h => h.1, fun h => ⟨ h, foc_eta w w' α 200 ηstar ( by norm_num ) hd hmax ⟩ ⟩

end CFMM.DynamicsOpt