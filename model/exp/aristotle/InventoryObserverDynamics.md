# Inventory-implied observer, the Gibbs weights, and the interior program

Companion to `exp/InventoryObserverDynamics.lean` (namespace
`CFMM.InventoryObserver`). Everything below is machine-checked, `sorry`-free, and
uses only the standard axioms `propext` / `Classical.choice` / `Quot.sound`. No
previously existing theorem or statement was modified; this installment only
adds new declarations and reuses primitives from `exp/eta.lean`,
`exp/BondingCurveCurvature.lean`, and `exp/DynamicsOptimization.lean`.

The DYNAMICS note closes the loop on the latent inventory weights `η̃` by giving
an *observer* for them, then solves the trade-size / curvature program

```
(Δᵢ⋆, η⋆) ≡ arg max [ π⁺(Δᵢ, η ; α) − C(Δᵢ) ].
```

There are four pieces; each is made precise and verified.

## 1. The inventory-implied observer

Since `η̃_j` is latent, the note approximates it by an inventory-implied observer
built from the pool's `O`-side inventory and the implied branch price
`p_{(Δᵢ,η)}(j)`:

```
η̃_j  ∝  g(j) / Σ_{m≠j} g(m),    g(j) = O / (O + p(j)·I).
```

* `obsRaw O I p = O / (O + p·I)` — the raw branch weight `g`.
* `obsImplied O I p j` — the normalized leave-one-out observer as written.

Verified facts:

* `obsRaw_pos`: `g(p) > 0` for `O > 0`, `I ≥ 0`, `p ≥ 0`.
* `obsRaw_strictAnti`: **`g` is strictly decreasing in the branch price `p`.**
  The observer downweights branches whose implied price is high (their `O`-side
  inventory is relatively scarce) — the qualitative content of the inventory
  observer.

## 2. The curvature-matched / composite cost

The curvature target is `∂²C_κ/∂(Δ^O)² = |κ|`. The minimal such cost,
`C_κ(x) = (|κ|/2)x²`, was verified in the previous installment as
`CFMM.Curvature.costQuad |κ|` (`costQuad_secondDeriv`).

The note also writes the explicit composite

```
C_κ(Δᵢ; j, η⋆) = 2κ(Δᵢ)·(Δ^O(Δᵢ))² + χ·(η_j(Δᵢ) − η_j⋆)².
```

* `costComposite_hasDerivAt_DO`: `∂C_κ/∂(Δ^O) = 4κ·Δ^O`.
* `costComposite_secondDeriv_DO`: `∂²C_κ/∂(Δ^O)² = 4κ`.

> ⚠ **Correction.** The literal leading coefficient `2κ` gives curvature `4κ`,
> not the target `|κ|`. To curvature-match exactly, the coefficient must be
> `|κ|/2` (i.e. use `CFMM.Curvature.costQuad |κ|`). We record the literal
> computation and the discrepancy. The `χ·(η_j − η_j⋆)²` anchor term is a pure
> reference-tracking penalty and does not affect the `Δ^O`-curvature.

## 3. The Gibbs (Boltzmann) observer and `∂η̃_i/∂Δᵢ < 0`

Setting the observer by the Boltzmann/Gibbs rule `η̃_i ∝ exp(−β·C_κ(Δᵢ; i))`:

```
η̃_i = exp(−β·C_i) / Σ_k exp(−β·C_k)      (gibbs)
```

* `gibbs_pos`, `gibbs_sum_eq_one`: the observer is a strictly positive
  probability vector.
* `gibbs_hasDerivAt`: the **exact softmax derivative**

  ```
  ∂η̃_i/∂Δᵢ = −β·η̃_i·( C_i′ − Σ_k η̃_k C_k′ ),
  ```

  i.e. `gibbsDeriv β C·(Δᵢ) C′ i`.
* `gibbs_deriv_neg`: hence, with `β > 0`, **`∂η̃_i/∂Δᵢ < 0` exactly when branch
  `i`'s marginal cost exceeds the observer-average marginal cost**,
  `C_i′ > Σ_k η̃_k C_k′`. In particular, a branch whose own cost rises with the
  spacing loses observer mass — the note's `∂η̃_i/∂Δᵢ < 0`.

This is the precise sign characterization the note asserts: monotone decay of
`η̃_i` is not automatic, it is the statement that branch `i` is becoming
*relatively* more expensive as the spacing grows.

## 4. Variance capacity, the interior trade-size program, and the two partials

With the feedback weights, the variance capacity is

```
Σ(Δᵢ) = Σ_j η̃_j(Δᵢ)·α_j²        (SigmaGibbs)
```

* `SigmaGibbs_nonneg`: `Σ(Δᵢ) ≥ 0`.
* `SigmaGibbs_hasDerivAt`: `Σ′(Δᵢ) = Σ_j (∂η̃_j/∂Δᵢ)·α_j²` — the capacity
  inherits the Gibbs feedback derivative.

The long-vol payoff is `π⁺(Δᵢ) = Δᵢ²·Σ(Δᵢ)` (`CFMM.Curvature.piPlusFB`) and the
net objective is

```
J(Δᵢ) = π⁺(Δᵢ) − C(Δᵢ) = Δᵢ²·Σ(Δᵢ) − C(Δᵢ).        (netObjective)
```

* `netObjective_hasDerivAt`:
  ```
  ∂J/∂Δᵢ = 2Δᵢ·Σ(Δᵢ) + Δᵢ²·Σ′(Δᵢ) − C′(Δᵢ).
  ```
* `foc_net_interior`: **the interior trade-size optimum.** At an interior
  maximizer `Δᵢ⋆ ≠ 0`,
  ```
  ∂π⁺/∂Δᵢ = 2Δᵢ⋆·Σ(Δᵢ⋆) + Δᵢ⋆²·Σ′(Δᵢ⋆) = C′(Δᵢ⋆),
  ```
  i.e. **marginal long-vol payoff equals marginal cost.** This is the genuinely
  *interior* optimum the program `arg max[π⁺ − C]` yields once the cost `C` is
  present — in contrast to the feedback-free corner solution of
  `exp/DynamicsOptimization.lean`.

### Characterization of `∂π⁺/∂Δᵢ` and `∂π⁺/∂η`

* **`∂π⁺/∂Δᵢ = 2Δᵢ·Σ(Δᵢ) + Δᵢ²·Σ′(Δᵢ)`** (from `netObjective_hasDerivAt`),
  with `Σ′` supplied by the Gibbs feedback (`SigmaGibbs_hasDerivAt`). Strictly
  positive without cost feedback (corner), but balanced against `C′` at the
  interior optimum.
* **`∂π⁺/∂η = Δᵢ²·Σ_j η̃_j′(η)·α_j²`** (`piPlus_partial_eta`, reusing the
  separable payoff of `CFMM.DynamicsOpt`), and an interior `η`-optimum solves
  ```
  Σ_j η̃_j′(η⋆)·α_j² = 0        (piPlus_foc_eta).
  ```

## Theorems

`obsRaw_pos`, `obsRaw_strictAnti`, `costComposite_hasDerivAt_DO`,
`costComposite_secondDeriv_DO`, `gibbs_denom_pos`, `gibbs_pos`,
`gibbs_sum_eq_one`, `gibbs_hasDerivAt`, `gibbs_deriv_neg`, `SigmaGibbs_nonneg`,
`SigmaGibbs_hasDerivAt`, `netObjective_hasDerivAt`, `foc_net_interior`,
`piPlus_partial_eta`, `piPlus_foc_eta`.
