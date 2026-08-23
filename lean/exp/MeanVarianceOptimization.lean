/-
  exp/MeanVarianceOptimization.lean

  Formal companion to `exp/MeanVarianceOptimization.md`.

  Design question answered here (the closing program of the latest spec note):

      « Given a risk-aversion profile `γ`, SOLVE

            sup_{Δᵢ, η}  MV_γ[π]  =  E^{η̃}[π] − (γ/2)·Var^{η̃}[π]

        subject to the admissibility restrictions of the model:
        `Δᵢ ∈ ℕ`, `Δᵢ ∈ [1, 200]`, `η ∈ (0,1)`. »

  This is the culminating mean–variance OPTIMIZATION over the two protocol /
  agent controls (tick spacing `Δᵢ` and CES curvature `η`).  The mean–variance
  functional, the η-measure, the expectation `E`, the variance `Var`, the
  objective `MV` and the relative-price kernel `priceKernel` are all reused
  verbatim from `exp/MeanVarianceEta.lean` — no new economic primitives are
  introduced.

  What is established:

    * **Continuity of the program.**  `E`, `Var` and hence `MV` are continuous
      in the control `θ` whenever the weight family `w(θ)` and the payoff family
      `X(θ)` are continuous (`continuous_E`, `continuous_Var`, `continuous_J`).
      The model's relative-price payoff `priceKernel lam Δᵢ η i` IS such a
      continuous family (`continuous_priceKernelFam`).

    * **Existence of the optimum (well-posedness of `sup`).**
        – over any compact admissible box `[1,200] × [a,b] ⊆ ℝ²`
          (`exists_max_on_compact`, `exists_mv_optimal`), so the `sup` is a
          `max`: it is ATTAINED at some admissible `(Δᵢ⋆, η⋆)`;
        – over any finite admissible menu (the integer tick menu
          `Δᵢ ∈ {1,…,200}`) with no continuity needed
          (`exists_max_on_finset`, `exists_mv_optimal_tick_menu`).

    * **Risk lowers the value.**  At the optimum the mean–variance value never
      exceeds the pure expected payoff (`mv_value_le_mean`), and at `γ = 0` the
      program collapses to maximizing the expected relative price
      (`J_risk_neutral`).

    * **Closed-form solution in the risk-neutral limit.**  With `λ > 1` and
      positive ticks, the risk-neutral objective `E^{η̃}[p]` is monotone in both
      controls, so the optimum is the **upper corner** `(Δᵢ⋆, η⋆) = (200, b)`
      (`riskNeutral_isMaxOn_corner`): maximal spacing and maximal curvature.

  Everything is finite/discrete, indexed by `Fin m` (the admissible tick band).
-/
import Mathlib
import exp.MeanVarianceEta

open scoped BigOperators Topology
open CFMM.MeanVariance

namespace CFMM.MVOpt

variable {m : ℕ} {β : Type*} [TopologicalSpace β]

/-- The **mean–variance program objective** as a function of a control `θ`,
    through a weight family `w(θ)` (the η̃-measure) and a payoff family `X(θ)`
    (the random payoff `π`): `J(θ) = MV_γ(w θ)(X θ)`. -/
noncomputable def J (w X : β → Fin m → ℝ) (γ : ℝ) (θ : β) : ℝ :=
  MV (w θ) (X θ) γ

/-
The discrete **expectation** is continuous in the control whenever the
    weight and payoff families are.
-/
theorem continuous_E (w X : β → Fin m → ℝ)
    (hw : Continuous w) (hX : Continuous X) :
    Continuous fun θ => E (w θ) (X θ) := by
  exact continuous_finset_sum _ fun i _ => Continuous.mul ( continuous_apply i |> Continuous.comp <| hw ) ( continuous_apply i |> Continuous.comp <| hX )

/-
The discrete **variance** is continuous in the control whenever the weight
    and payoff families are.
-/
theorem continuous_Var (w X : β → Fin m → ℝ)
    (hw : Continuous w) (hX : Continuous X) :
    Continuous fun θ => Var (w θ) (X θ) := by
  refine' continuous_finset_sum _ fun j _ => Continuous.mul ( continuous_apply j |> Continuous.comp <| hw ) _;
  exact Continuous.pow ( Continuous.sub ( continuous_apply j |> Continuous.comp <| hX ) ( continuous_E w X hw hX ) ) _

/-
The **mean–variance objective** `J` is continuous in the control.
-/
theorem continuous_J (w X : β → Fin m → ℝ) (γ : ℝ)
    (hw : Continuous w) (hX : Continuous X) :
    Continuous (J w X γ) := by
  convert Continuous.sub ( continuous_E w X hw hX ) ( continuous_const.mul ( continuous_Var w X hw hX ) ) using 1

/-
**Existence of the optimum over a compact admissible set.**  Over any compact
    nonempty admissible region `K` of controls the supremum of the mean–variance
    objective is ATTAINED — there is a maximizing control `θ⋆ ∈ K`.  This is the
    well-posedness of `sup_{(Δᵢ,η) ∈ K} MV_γ[π]`.
-/
theorem exists_max_on_compact (w X : β → Fin m → ℝ) (γ : ℝ)
    (hw : Continuous w) (hX : Continuous X)
    {K : Set β} (hK : IsCompact K) (hne : K.Nonempty) :
    ∃ θ ∈ K, ∀ θ' ∈ K, J w X γ θ' ≤ J w X γ θ := by
  -- Since $J$ is continuous on the compact set $K$, it attains its maximum on $K$.
  have h_cont : ContinuousOn (fun θ => J w X γ θ) K := by
    exact Continuous.continuousOn ( continuous_J w X γ hw hX );
  exact hK.exists_isMaxOn hne h_cont

omit [TopologicalSpace β] in
/-- **Existence of the optimum over a finite admissible menu.**  Over any finite
    nonempty menu of controls (e.g. the integer tick menu `Δᵢ ∈ {1,…,200}`) the
    mean–variance objective attains its maximum.  No continuity is needed. -/
theorem exists_max_on_finset (w X : β → Fin m → ℝ) (γ : ℝ)
    (S : Finset β) (hS : S.Nonempty) :
    ∃ θ ∈ S, ∀ θ' ∈ S, J w X γ θ' ≤ J w X γ θ :=
  S.exists_max_image (J w X γ) hS

omit [TopologicalSpace β] in
/-- **Risk never raises the value:** with nonnegative risk-aversion the
    mean–variance objective is everywhere bounded above by the pure expected
    payoff, under any probability-measure weight family. -/
theorem mv_value_le_mean (w X : β → Fin m → ℝ) {γ : ℝ} (hγ : 0 ≤ γ)
    (θ : β) (hw : IsProb (w θ)) :
    J w X γ θ ≤ E (w θ) (X θ) :=
  MV_le_mean (w θ) (X θ) hw hγ

omit [TopologicalSpace β] in
/-- **Risk-neutral collapse:** at `γ = 0` the program is exactly maximization of
    the expected payoff `E^{η̃}[π]`. -/
@[simp] theorem J_risk_neutral (w X : β → Fin m → ℝ) (θ : β) :
    J w X 0 θ = E (w θ) (X θ) := MV_risk_neutral (w θ) (X θ)

/-! ## Instantiation with the model's relative-price payoff -/

/-- The relative-price payoff family as a function of the control `θ = (Δᵢ, η)`:
    `X(Δᵢ, η)_j = λ^{i_j · Δᵢ · η}`.  This is the `priceKernel` of
    `exp/MeanVarianceEta.lean` with the two controls exposed. -/
noncomputable def priceKernelFam (lam : ℝ) (i : Fin m → ℤ) :
    (ℝ × ℝ) → Fin m → ℝ :=
  fun θ => priceKernel lam θ.1 θ.2 i

/--
The relative-price payoff family is continuous in the control `(Δᵢ, η)`
    whenever the base `λ` is positive.
-/
theorem continuous_priceKernelFam (lam : ℝ) (hlam : 0 < lam) (i : Fin m → ℤ) :
    Continuous (priceKernelFam lam i) := by
  refine' continuous_pi fun j => _;
  exact Continuous.rpow continuous_const ( by continuity ) ( by continuity )

/--
**Well-posedness of the mean–variance program over the admissible box.**
    With the model's relative-price payoff and any continuous η̃-measure family
    `w`, the program `sup_{(Δᵢ,η) ∈ [1,200]×[a,b]} MV_γ[π]` attains its supremum:
    there is an optimal admissible control `(Δᵢ⋆, η⋆)`.  Here `[a,b] ⊆ (0,1)` is
    any closed sub-band of the open curvature interval.
-/
theorem exists_mv_optimal (lam : ℝ) (hlam : 0 < lam) (i : Fin m → ℤ)
    (w : (ℝ × ℝ) → Fin m → ℝ) (hw : Continuous w) (γ : ℝ)
    (a b : ℝ) (hab : a ≤ b) :
    ∃ θ ∈ Set.Icc (1 : ℝ) 200 ×ˢ Set.Icc a b,
      ∀ θ' ∈ Set.Icc (1 : ℝ) 200 ×ˢ Set.Icc a b,
        J w (priceKernelFam lam i) γ θ' ≤ J w (priceKernelFam lam i) γ θ := by
  refine exists_max_on_compact w (priceKernelFam lam i) γ hw
    (continuous_priceKernelFam lam hlam i)
    (CompactIccSpace.isCompact_Icc.prod CompactIccSpace.isCompact_Icc)
    ⟨⟨1, a⟩, by norm_num, by norm_num [hab]⟩

/--
**Well-posedness over the integer tick menu.**  Over the finite admissible
    tick menu `Δᵢ ∈ {1,…,200}` (at any fixed curvature `η`) the mean–variance
    program attains its maximum.
-/
theorem exists_mv_optimal_tick_menu (lam : ℝ) (i : Fin m → ℤ)
    (w : (ℝ × ℝ) → Fin m → ℝ) (γ : ℝ) (η : ℝ) :
    ∃ d ∈ Finset.Icc (1 : ℤ) 200,
      ∀ d' ∈ Finset.Icc (1 : ℤ) 200,
        J w (priceKernelFam lam i) γ ((d' : ℝ), η)
          ≤ J w (priceKernelFam lam i) γ ((d : ℝ), η) := by
  convert Finset.exists_max_image _ _ _ ; norm_num

/-! ## Closed-form solution in the risk-neutral limit -/

/--
**Monotone corner solution (risk-neutral).**  With base `λ > 1`, strictly
    positive ticks `i_j > 0`, a fixed η̃-probability measure `w`, and curvature
    band `[a,b]` with `0 ≤ a ≤ b`, the risk-neutral objective `E^{η̃}[p]` is
    maximized over the admissible box `[1,200]×[a,b]` at the **upper corner**
    `(Δᵢ⋆, η⋆) = (200, b)`: maximal spacing and maximal curvature.  (This solves
    the program in the `γ = 0` limit; the risk penalty `−(γ/2)Var` pulls the
    interior optimum back toward lower dispersion for `γ > 0`.)
-/
theorem riskNeutral_isMaxOn_corner (lam : ℝ) (hlam : 1 < lam) (i : Fin m → ℤ)
    (hi : ∀ j, 0 < i j) (w : Fin m → ℝ) (hw : IsProb w)
    (a b : ℝ) (ha : 0 ≤ a) :
    ∀ θ ∈ Set.Icc (1 : ℝ) 200 ×ˢ Set.Icc a b,
      E w (priceKernel lam θ.1 θ.2 i) ≤ E w (priceKernel lam 200 b i) := by
  intros θ hθ
  have h_price_le : ∀ j, priceKernel lam θ.1 θ.2 i j ≤ priceKernel lam 200 b i j := by
    intros j
    have h_exp : (i j : ℝ) * θ.1 * θ.2 ≤ (i j : ℝ) * 200 * b := by
      gcongr <;> nlinarith [ Set.mem_Icc.mp hθ.1, Set.mem_Icc.mp hθ.2, show ( i j : ℝ ) ≥ 1 by exact_mod_cast hi j ];
    exact Real.rpow_le_rpow_of_exponent_le hlam.le h_exp;
  exact Finset.sum_le_sum fun j _ => mul_le_mul_of_nonneg_left ( h_price_le j ) ( hw.nonneg j )

end CFMM.MVOpt