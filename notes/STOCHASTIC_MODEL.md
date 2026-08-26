# Stochastic swap-flow model

The order-flow model the protocol's proxy generators implement. Migrated from the former
root `NOTES.md` (engineering scratch) so it lives with the other binding `notes/` specs;
the scratch hook sketches and stale paths were dropped in the move.

## Canonical start state

A single LP position with a swap continuum:

```
(di = 20, i = 100, i_l = -120, i_u = 120, L(i) = 1e18, Y = 100e18)
```

## Order-flow process

Per time step `t`:

$$
\lambda_t \sim \mathcal{U}(0.6, 1.0), \qquad N_t \mid \lambda_t \sim \mathrm{Poisson}(\lambda_t)
$$

$$
\bar{\Delta y}_t \sim \mathcal{U}(19, 21), \qquad
\Delta y_{n,t} \sim \mathrm{LogNormal}(\mu_t, \sigma_{\Delta y}^2), \quad \sigma_{\Delta y} = 1.2
$$

Moment matching (so the LogNormal mean equals the drawn average):

$$
\mathbb{E}[\Delta y_{n,t}] = \exp\!\left(\mu_t + \tfrac{\sigma_{\Delta y}^2}{2}\right) = \bar{\Delta y}_t
\quad\Longrightarrow\quad
\mu_t = \ln(\bar{\Delta y}_t) - \tfrac{\sigma_{\Delta y}^2}{2}
$$

Swap direction indicator (buy `X` with `Y` vs. sell `X` for `Y`), fair coin:

$$
\mathbb{I}_{n,t} =
\begin{cases}
+1, & \text{buy } X \text{ with } Y,\\
-1, & \text{sell } X \text{ for } Y,
\end{cases}
\qquad
\mathbb{P}(\mathbb{I}_{n,t}=1) = \mathbb{P}(\mathbb{I}_{n,t}=-1) = \tfrac{1}{2}
$$

Net signed flow over the step:

$$
\Delta Y(t) = \sum_{n=1}^{N_t} \mathbb{I}_{n,t} \, \Delta y_{n,t}
$$

## Deterministic proxy (on-chain)

The EVM has no native RNG, so the process above is proxied deterministically:

$$
\Delta y(t) = 19 + 1.0001^{\eta \, t^4}
$$

For the direction coin, an on-chain binomial proxy draws from `block.prevrandao` /
`block.difficulty`.

## Implementation map

| Model object | Implementation |
|---|---|
| Direction indicator `I ∈ {−1,+1}`, `P = ½` | `src/lib/BinomialProxy.plk` (`ping() → {0,1}`) |
| Swap-amount proxy `Δy(t) = 19 + 1.0001^{η t⁴}` | `src/lib/SwapAmtGen.plk` (`swapAmount(t)`) |
| CLMM price math referenced by the above | `lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk` (`getNextSqrtPriceFromAmount0RoundingUp`) |

## Reference integrations (design sketches)

Integration surfaces explored against the reference ecosystem in `lib/`
(unpublished-IP references are path-anchored-ignored per `.gitignore`):
Unistrata (`UnistrataHook` + `VarianceLib`/`NavLib`/`WaterfallLib` → PositionManager tokenId),
Shizo, Mochi-Yield, and Centrifuge (`protocol` submodule — `BalanceSheet` deposit tests).
These are exploratory scaffolding, not committed integrations.
