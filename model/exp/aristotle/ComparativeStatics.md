# Parameterizing the environment: comparative statics of `MV_γ(Δᵢ, η; θ)`

This note answers the recommendation to **parameterize the environment**: bundle
the exogenous market data into a single *market state vector*

> θ = (λ, L̄, ξ, δ, γ, …),

write the mean–variance objective as a function of the two **controls** `(Δᵢ, η)`
**and** the state,

> MV_γ(Δᵢ, η; θ),

and read off the **solution map**

> (Δᵢ⋆, η⋆) = g(θ),

which is exactly the object comparative statics studies. The formal companion is
`exp/ComparativeStatics.lean` (namespace `CFMM.ComparativeStatics`), which reuses
the existing `E`, `Var`, `MV`, `priceKernel` (from `exp/MeanVarianceEta.lean`) and
the program-existence theory of `exp/MeanVarianceOptimization.lean` — no new
economic primitives, only the *bundling* and the solution map.

## 1. The state vector and where each coordinate already lives

The state is the record `MarketState`. Every coordinate maps to a formula that
already exists in the repository:

| coord. | field   | role / existing formula |
|--------|---------|--------------------------|
| λ      | `lam`   | pricing base of the relative-price kernel `priceKernel λ Δᵢ η i = λ^{i·Δᵢ·η}`. |
| L̄     | `L_bar` | total liquidity, `L̄ = Σᵢ L(i)` (`liqAt_sum`). |
| ξ      | `xi`    | geometric liquidity-distribution base; the per-tick share `ℓ(ξ,#;i) = ξ^i / Σⱼ ξ^j` is a probability distribution over the interior ticks (`liqShare_sum_one`), and `L(i) = L̄·ℓ(ξ,#;i)`. |
| δ      | `delta` | volatility scale of the CEV return vol `σ_ret = δ·P^{η−1}` (`retVol`, `retVol_half`). |
| γ      | `gamma` | risk aversion of the mean–variance objective. |
| —      | `a,b`   | admissible curvature band `[a,b] ⊆ (0,1)` for the control `η`. |
| —      | `tick`, `w` | the discrete tick band `i : Fin m → ℤ` and the η̃-measure `w`. |

Well-formedness (`0 < λ`, `a ≤ b`, `w` a probability measure) is carried as
fields, so the solution map `g` below is a genuine function of `θ` alone.

### Why σ is not a free coordinate

The informal vector lists a dispersion `σ`. In this model `σ` is **not** an
independent coordinate: it is the realized return-vol term structure
`σ_ret = δ·P^{η−1}` (`retVol`, `retVol_eq`), so it is pinned by `(δ, η, P)`. At
the constant-product curvature `η = ½` this is `σ_ret = δ/√P` (`retVol_half`).
Hence the free environment coordinates are `(λ, L̄, ξ, δ, γ)` (plus the band and
the tick/measure data); `σ` is a function of them and of the control `η`.

### Why ξ enters through the liquidity distribution

Per the clarification, `L̄ = Σᵢ L(i)` with `L(i) = L̄·ℓ(ξ,#;i)` and the geometric
profile `ℓ(ξ,#;i) = ξ^i / Σ_{j=1}^{#} ξ^j` (for `ξ ≠ 1`). Two facts make this a
genuine liquidity *distribution* in Lean:

- `liqShare_sum_one`: `Σ_{i=1}^{#} ℓ(ξ,#;i) = 1` (a probability distribution over
  the interior ticks, for `ξ > 0` and at least one tick).
- `liqAt_sum`: `Σ_{i=1}^{#} L(i) = L̄` (total liquidity is conserved).

This is the same "price-invariant region" geometry used by the LP payoff
`pi_minus_eta_liq` in `exp/EtaLiquidityPayoff.lean`, where the LP's participation
ratio is `ΔL̄/L̄`.

## 2. The state-parameterized objective

```
payoff θ (Δᵢ, η)        = priceKernel θ.lam Δᵢ η θ.tick           -- the relative price π
MVobj θ (Δᵢ, η)         = MV θ.w (payoff θ (Δᵢ, η)) θ.gamma        -- = MV_γ(Δᵢ, η; θ)
                        = E^{η̃}[π] − (θ.gamma/2)·Var^{η̃}[π]
```

`MVobj_eq_J` records that this is *definitionally* the program objective `J` of
`exp/MeanVarianceOptimization.lean` with the (constant) η̃-measure family and the
relative-price payoff family — so the existence theory transfers verbatim.

The admissible **control box** is `box θ = [1,200] × [a,b]`.

## 3. The solution map g(θ) and the value function

- `exists_optimizer`: over `box θ` the objective attains its maximum (extreme-value
  theorem on a compact box, via `exists_mv_optimal`). This is exactly the
  well-posedness needed for `g` to be defined.
- `g θ = (Δᵢ⋆, η⋆)`: a maximizer for each state, with `g_mem` (admissibility) and
  `g_isMax` (optimality over the box).
- `value θ = MV_γ(g(θ); θ) = sup_{(Δᵢ,η) ∈ box} MV_γ(Δᵢ, η; θ)` (`value_isMax`).

`g` is the comparative-statics object: it sends the environment `θ` to the
optimal controls.

## 4. Comparative statics results proved

**In the risk aversion γ.**
- `MVobj_antitone_gamma`: for a fixed control, raising γ never raises the
  objective (variance is nonnegative).
- `value_antitone_gamma`: the value function `V(θ)` is **antitone in γ** — a more
  risk-averse market never achieves a higher mean–variance optimum. (Proof: the
  box is independent of γ, the objective is pointwise antitone in γ, and the max
  of a pointwise-smaller function over the same set is smaller.)
- `value_le_mean`: with γ ≥ 0 the optimal value is bounded above by the expected
  relative price at the optimizer.

**In the risk-neutral limit (γ = 0).**
- `riskNeutral_corner`: with `λ > 1`, strictly positive ticks and `a ≥ 0`, the
  optimum is the **upper corner** `g(θ) = (Δᵢ⋆, η⋆) = (200, b)` — maximal spacing
  and curvature. This is the closed form of `g` in the corner regime; the risk
  penalty `−(γ/2)Var` pulls the optimizer back toward lower dispersion as `γ`
  grows.

## 5. What this buys you

The parameterization turns ad-hoc per-instance optimization into a *map*
`θ ↦ g(θ)` whose monotonicity/limit behavior is now a theorem. The proved
comparative statics — value antitone in γ, corner solution at `γ = 0` — are the
first entries of the `∂g/∂θ` table this framing is designed to populate; further
coordinates (`λ, L̄, ξ, δ`) enter the objective and constraints through the
formulas tabulated in §1, ready for the same treatment.

All declarations build without `sorry` and depend only on the standard axioms
`propext`, `Classical.choice`, `Quot.sound`. The original task theorem
`pi_trader_half_strictly_increasing_in_Δi` and every other prior `exp/*` result
are unchanged.
