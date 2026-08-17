# Bonding-curve curvature, output monotonicity, cost matching, and the interior FOC

Companion to `exp/BondingCurveCurvature.lean` (namespace `CFMM.Curvature`).
This installment formalizes and *verifies* the closing curvature block of the
DYNAMICS note. Everything below is machine-checked, `sorry`-free, and uses only
the standard axioms `propext` / `Classical.choice` / `Quot.sound`. No existing
theorem or statement was modified.

## Setup

The output rule, written as a function of the (sqrt-)price `p` at fixed pool
liquidity `L̄` and input size `Δ^I`, is

```
Δ^O(p) = L̄·Δ^I·p² / (L̄ + Δ^I·p).
```

This is exactly the model's `CFMM.Eta.Delta_O_half` once the post-trade price
`P' = L̄·P / (L̄ + Δ^I·P)` is substituted (`DeltaO_eq_model`).

## ∂Δ^O/∂p and the curvature κ

* First derivative (`DeltaO_hasDerivAt`):
  ```
  ∂Δ^O/∂p = L̄·Δ^I·p·(2L̄ + Δ^I·p) / (L̄ + Δ^I·p)²  > 0   (p>0).
  ```
* Second derivative = curvature (`kappa_eq_secondDeriv`):
  ```
  κ(p) = ∂²Δ^O/∂p² = 2·Δ^I·L̄³ / (L̄ + Δ^I·p)³.
  ```

### ⚠ Correction to the note

The note writes the curvature with a **leading minus sign**,
`κ = − 2·Δ^I·L̄³/(L̄+Δ^I·p)³`. That sign is **wrong**: the constant-product
output rule is **convex** in the price, so the curvature is strictly **positive**
(`kappa_pos`). The verified statement is
```
κ(p) = + 2·Δ^I·L̄³/(L̄ + Δ^I·p)³  > 0.
```
The note's **magnitude** `|κ| = 2·Δ^I·L̄³/(L̄+Δ^I·p)³` is correct, and every
downstream conclusion of the note uses only `|κ|`, so the rest of the chain is
unaffected. We record `abs_kappa_eq : |κ| = κ`.

## ∂|κ|/∂Δᵢ < 0

`κ` is strictly decreasing in the price (`kappa_strictAntiOn_p`): a larger price
inflates the denominator while the numerator is constant. Composing with the
spacing→price map `P_half lam Δi i = λ^{i·Δᵢ}`, which is strictly increasing in
`Δᵢ` for `i>0`, `λ>1` (`CFMM.Eta.P_half_strictMono`), gives the note's
```
∂|κ|/∂Δᵢ < 0          (abs_kappa_strictAnti_in_Δi).
```
Deeper / wider spacing flattens the local bonding-curve curvature.

## ∂Δ^O/∂Δᵢ > 0

`Δ^O` is strictly increasing in the price on `p>0` (`DeltaO_strictMonoOn_p`);
composing again with `P_half` yields the note's
```
∂Δ^O/∂Δᵢ > 0          (DeltaO_strictMono_in_Δi).
```
The note motivates this via "since `∂Δ^O/∂|κ| < 0` and `∂|κ|/∂Δᵢ < 0`, then
`∂Δ^O/∂Δᵢ > 0`". That indirect chain-rule heuristic is informal (both `Δ^O` and
`|κ|` are driven by the same underlying `p`, so `∂Δ^O/∂|κ|` is not a free
partial), but the **conclusion is correct** and is what we prove directly.

## Curvature-matched cost C_κ

The note posits a cost whose curvature in the produced output matches `|κ|`,
`∂²C_κ/∂(Δ^O)² = |κ|`. The minimal such (locally quadratic) cost is
```
C_κ(x) = (|κ|/2)·x²,     C_κ'(x) = |κ|·x,     C_κ''(x) = |κ|,
```
proved as `costQuad_hasDerivAt` and `costQuad_secondDeriv` (with `k = |κ|`).

## Interior first-order condition for the trade size

Once the inventory-weight feedback `η̃(Δᵢ, η; π⁺)` makes the **variance capacity**
`Σ` depend on `Δᵢ`, the payoff is `π⁺(Δᵢ) = Δᵢ²·Σ(Δᵢ)`. Then
(`piPlusFB_hasDerivAt`)
```
∂π⁺/∂Δᵢ = 2·Δᵢ·Σ(Δᵢ) + Δᵢ²·Σ′(Δᵢ) = Δᵢ·( 2·Σ + Δᵢ·∂Σ/∂Δᵢ ).
```
At an interior maximizer `Δᵢ⋆ ≠ 0` the bracket vanishes (`foc_interior`):
```
2·Σ(Δᵢ⋆) + Δᵢ⋆·∂Σ/∂Δᵢ |_{Δᵢ⋆} = 0,
```
exactly the note's stationarity condition. This is the precise sense in which an
**interior** trade-size optimum can exist: it requires `∂Σ/∂Δᵢ < 0` (the feedback
must erode variance capacity fast enough, `Σ′(Δᵢ⋆) = −2·Σ(Δᵢ⋆)/Δᵢ⋆ < 0`).
Without feedback `Σ` is constant in `Δᵢ` (the earlier
`eta_Δi_independent_in_sigma_and_L_eta`), the bracket reduces to `2·Σ > 0`, and
the optimum is the upper **corner** — consistent with the previous installment
`exp/DynamicsOptimization.lean`.

## Theorems

`DeltaO_eq_model`, `DeltaO_hasDerivAt`, `kappa_eq_secondDeriv`, `kappa_pos`,
`abs_kappa_eq`, `kappa_strictAntiOn_p`, `abs_kappa_strictAnti_in_Δi`,
`DeltaO_strictMonoOn_p`, `DeltaO_strictMono_in_Δi`, `costQuad_hasDerivAt`,
`costQuad_secondDeriv`, `piPlusFB_hasDerivAt`, `foc_interior`.
