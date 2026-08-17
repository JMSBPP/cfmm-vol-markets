# Solving the mean–variance program `sup_{Δᵢ, η} MV_γ[π]`

Companion to `exp/MeanVarianceOptimization.lean`. This note answers the closing
program of the latest spec: *given a risk-aversion profile `γ`, solve*

```
sup_{Δᵢ, η}  MV_γ[π]  =  E^{η̃}[π] − (γ/2)·Var^{η̃}[π]
```

*subject to the model's admissibility restrictions* `Δᵢ ∈ ℕ`, `Δᵢ ∈ [1,200]`,
`η ∈ (0,1)`.

All objects are reused verbatim from `exp/MeanVarianceEta.lean`: the η-measure
weights `w` (a probability vector, `IsProb`), the discrete expectation `E`, the
variance `Var`, the mean–variance objective `MV`, and the relative-price kernel
`priceKernel lam Δᵢ η i = λ^{i·Δᵢ·η}`. No new economic primitives are added; the
random payoff `π` is taken to be the model's relative price (the canonical
continuous observable established in `MeanVarianceEta`), and the controls
`(Δᵢ, η)` are exposed as the optimization variables.

## Answer in brief

The program is **well-posed** and its `sup` is **attained**:

- Over the admissible box `[1,200] × [a,b] ⊆ ℝ²` (with `[a,b] ⊆ (0,1)` any closed
  curvature sub-band) the objective is continuous and the box compact, so the
  supremum is a maximum — there exists an optimal admissible `(Δᵢ⋆, η⋆)`.
- Over the integer tick menu `Δᵢ ∈ {1,…,200}` (at any fixed `η`) the maximum is
  attained by a purely finite argument (no continuity needed), which is the most
  literal reading of `Δᵢ ∈ ℕ, Δᵢ ∈ [1,200]`.

The **risk penalty never raises the value** (`MV_γ[π] ≤ E^{η̃}[π]` for `γ ≥ 0`),
and at `γ = 0` the program collapses to maximizing the expected relative price.
In that **risk-neutral limit** the objective is monotone in both controls
(for base `λ > 1` and positive ticks), so the solution is the explicit **upper
corner** `(Δᵢ⋆, η⋆) = (200, b)`: maximal spacing and maximal curvature. For
`γ > 0` the `−(γ/2)Var` term pulls the interior optimum back toward lower
dispersion, but existence of the optimizer is guaranteed in all cases.

## Map from claims to Lean names

Continuity of the program (the analytic backbone of existence):

- `continuous_E` — the discrete expectation `θ ↦ E (w θ) (X θ)` is continuous
  whenever the weight family `w(θ)` and payoff family `X(θ)` are.
- `continuous_Var` — likewise for the variance.
- `continuous_J` — hence the mean–variance objective `J = MV` is continuous in
  the control.
- `continuous_priceKernelFam` — the model's relative-price payoff
  `θ = (Δᵢ, η) ↦ λ^{i·Δᵢ·η}` is a continuous family (base `λ > 0`).

Existence of the optimum (well-posedness of `sup`):

- `exists_max_on_compact` — over any compact nonempty admissible region the
  supremum of `J` is attained (extreme-value theorem).
- `exists_max_on_finset` — over any finite nonempty menu of controls the maximum
  is attained.
- `exists_mv_optimal` — the headline existence result for the program with the
  model's relative-price payoff over the box `[1,200] × [a,b]`.
- `exists_mv_optimal_tick_menu` — existence over the integer tick menu
  `Δᵢ ∈ {1,…,200}`.

Structure of the value / solution:

- `mv_value_le_mean` — risk-aversion never raises the value: `J ≤ E^{η̃}[π]`.
- `J_risk_neutral` — at `γ = 0` the program is exactly `max E^{η̃}[π]`.
- `riskNeutral_isMaxOn_corner` — closed-form solution in the risk-neutral limit:
  the maximizer is the corner `(Δᵢ⋆, η⋆) = (200, b)`.

All declarations build with no `sorry` and use only the standard axioms
`propext`, `Classical.choice`, `Quot.sound`.

## Scope notes

- The curvature interval `(0,1)` is open, so an unconstrained `sup` over `η ∈
  (0,1)` need not be attained at an interior point; the faithful statement is
  existence over any closed sub-band `[a,b] ⊆ (0,1)` (and over the finite tick
  menu in `Δᵢ`). This is exactly how the existence theorems are phrased.
- The payoff `X` is kept generic (instantiated with the relative-price kernel);
  any continuous payoff family — including the trader payoff `pi_trader_half`,
  which `eta.lean` shows is continuous — satisfies the same hypotheses, so the
  existence results apply unchanged to other admissible payoff choices.
