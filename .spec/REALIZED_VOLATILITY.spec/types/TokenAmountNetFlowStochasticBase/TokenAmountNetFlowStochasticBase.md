# [TYPE:: TOKEN_AMOUNT_NET_FLOW_STOCHASTIC_BASE](MAIN_REF# MODEL)

`-- types.toml: TokenAmountNetFlowStochasticBase` · [#151](https://github.com/JMSBPP/cfmm-vol-markets/issues/151)  
TokenFlow consumer: [#152](https://github.com/JMSBPP/cfmm-vol-markets/issues/152) (deferred)

Semantics: \(\sigma_F\Delta W\) is the stochastic token-amount leg of \(\Delta Q_M\) (`REALIZED_VOLATILITY.md`). Drift \(\mu_F\bar{dt}\) is out of scope.

\[
\begin{aligned}
\mathrm{TokenAmountNetFlowStochasticBase}(C,\,N,\,\bar{dt})
&\leftarrow
\{\,\sigma : C,\;\Delta W : \Delta W(\bar{dt})\,\}
\\
C
&=
\mathrm{SigmaF}(N)
\quad\text{(only }C\text{ this slice)}
\\
N
&=
\mathrm{Ray}
\quad\text{(only scale this slice)}
\\
\Delta W(\bar{dt})
&\equiv
\mathrm{Weiner}(\bar{dt})
\quad(\mathtt{WeinerGenerator::DeltaW})
\\[1em]
\mathrm{intro\_base}
&::
\mathrm{SigmaF}(N) \to \Delta W(\bar{dt})
\to \mathrm{TokenAmountNetFlowStochasticBase}(\mathrm{SigmaF}(N),\,N,\,\bar{dt})
\\
\mathrm{intro\_base}(\sigma,\,\Delta W)
&=
\{\,\sigma,\,\Delta W\,\}
\\[1em]
\mathrm{TokenAmountStock}(T)
&\leftarrow
\mathrm{u256}_{\mathrm{signed}}
\quad(T = \mathrm{TokenAmountNetFlowStochasticBase}(\ldots))
\\
\mathrm{stock}
&::
T \to \mathrm{TokenAmountStock}(T)
\\
\mathrm{stock}(b)
&=
\frac{\sigma \cdot \Delta W}{\mathrm{unit}(N)}
\\
\mathrm{unit}(\mathrm{Ray})
&=
\mathrm{rayVal}(\mathrm{rayMulId}())
\\[1em]
\mathrm{magnitude}
&::
\mathrm{TokenAmountStock}(T) \to \mathrm{u256}
\\
\mathrm{direction}
&::
\mathrm{TokenAmountStock}(T) \to \mathrm{Dir}
\\[1em]
\mathrm{Eff}
&=
[\,]
\\[1em]
&\text{holes (define): }\mathtt{stock},\;\mathtt{magnitude},\;\mathtt{direction}
\\
&\text{overflow: checked mul/div }\Rightarrow\mathrm{revert}
\end{aligned}
\]

## Std / host reuse

| Candidate | Fit |
|-----------|-----|
| `cfmm_types::Ray` (`rayVal`, `rayMulId`) | **Reuse** — `unit(Ray)` |
| `SigmaF(N)` | **Reuse** — coeff `C` |
| `WeinerGenerator::DeltaW(dt)` | **Reuse** — Wiener leg |
| `std::option::Option` for stock | **Reject** — checked revert |
| SigmaF-owned `token_amount` | **Reject** — this module owns product |
| TokenFlow amount head | **Defer** — #152 |

Plank module: `types::TokenAmountNetFlowStochasticBase`.
