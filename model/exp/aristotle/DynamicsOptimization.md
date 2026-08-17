# Optimal controls of the long-vol payoff π⁺ (DYNAMICS, closing request)

Companion to `exp/DynamicsOptimization.lean` (namespace `CFMM.DynamicsOpt`).
Answers: *given the displacement profile `α = {α_j}`, compute the optimal
controls `(Δᵢ⋆, η⋆) = arg max π⁺(Δᵢ, η; α)` and characterize `∂π⁺/∂Δᵢ` and
`∂π⁺/∂η`.*

## Setup

Using the entry law `i_j = i_μ + α_j·Δᵢ`, the signed displacement is
`i_j − i_μ = α_j·Δᵢ`, so the payoff is

  π⁺(Δᵢ, η) = Σ_j η̃_j(Δᵢ, η) (i_j − i_μ)² = Σ_j η̃_j(Δᵢ, η) (Δᵢ·α_j)².

The model's structural fact `eta_Δi_independent_in_sigma_and_L_eta`
(`exp/eta.lean`) says the inventory weights **η̃ do not depend on Δᵢ** — they
are a curve `η ↦ η̃(η)` in the probability simplex. Modelling them as
`w : ℝ → Fin N → ℝ`, the payoff **separates**:

  π⁺(Δᵢ, η) = Δᵢ² · S(η),  S(η) := Σ_j η̃_j(η) α_j² ≥ 0.

| object | Lean |
|---|---|
| raw payoff `Σ_j η̃_j(η)(Δᵢ α_j)²` | `piPlusRaw` |
| dispersion factor `S(η)` | `Sfac` |
| factored payoff `Δᵢ²·S(η)` | `piPlus` |
| factorization (`= Δᵢ² Σ η̃ α²`) | `piPlusRaw_eq` |

Under the rational-expectations restriction `Σ_j η̃_j α_j = 0`
(`RationalExpectations`, "zero expected signed displacement"), `S(η)` is the
inventory variance of the displacements, so

  π⁺(Δᵢ, η) = Δᵢ² · Varᵉᵗᵃ(α)   (`piPlus_eq_variance`).

## ∂π⁺/∂Δᵢ — boundary (corner) optimum in the spacing

  **∂π⁺/∂Δᵢ = 2·Δᵢ·S(η)**   (`piPlus_hasDerivAt_Δi`).

It is strictly positive for `Δᵢ > 0` whenever `S(η) > 0`
(`partialDeltaI_pos`, with `Sfac_pos` giving `S(η)>0` as soon as some
displacement `α_j ≠ 0` carries positive inventory mass). Hence π⁺ is strictly
increasing in Δᵢ (`piPlus_strictMonoOn_Δi`), and over the admissible box
`Δᵢ ∈ [1, 200]` the optimum is the **upper corner**

  **Δᵢ⋆ = 200**   (`piPlus_isMaxOn_Δi_corner`).

There is no interior trade-size optimum: more spacing always raises the
long-vol payoff. (This matches the project's recurring finding that the
trading optimum is a corner — cf. `pi_trader_half_strictly_increasing_in_Δi`.)

## ∂π⁺/∂η — interior optimum characterized by a first-order condition

  **∂π⁺/∂η = Δᵢ² · Σ_j η̃_j′(η) α_j²**   (`piPlus_hasDerivAt_eta`).

The curvature η redistributes inventory mass across displacements rather than
scaling the payoff monotonically, so the η-optimum is **interior** and pinned
by the stationarity condition (`foc_eta`): at an interior maximizer η⋆ (and
any non-degenerate spacing `Δᵢ ≠ 0`),

  **Σ_j η̃_j′(η⋆) α_j² = 0.**

## Optimal controls

Combining the two (`optimal_controls`): over `Δᵢ ∈ [1, 200]` and η interior,

  **(Δᵢ⋆, η⋆) = (200, η⋆),   with η⋆ solving Σ_j η̃_j′(η⋆) α_j² = 0** —

a boundary optimum in the spacing and an interior, FOC-characterized optimum
in the curvature.

All results are machine-checked with no `sorry`; the headline theorems depend
only on the standard axioms `propext`, `Classical.choice`, `Quot.sound`.
