# [TYPE:: CEV_STATE_RUNNER](MAIN_REF# MODEL)

[StateView](../StateView/StateView.md) · [CEVLocalTickVolatility](../CEVLocalTickVolatility/CEVLocalTickVolatility.md) · [TokenFlow](../TokenFlow/TokenFlow.md) · [WeinerGenerator](../WeinerGenerator/WeinerGenerator.md) · [IO](../IO/IO.md) · [LiquidityChunk](../LiquidityChunk/LiquidityChunk.md)

Plank: `src/types/CEVStateRunner.plk`. types.toml: `CEVStateRunner`.
BTT: [CEVStateRunnerRunJ.btt](CEVStateRunnerRunJ.btt) (`#147` B2).
PRD: [#147](https://github.com/JMSBPP/cfmm-vol-markets/issues/147) · type [#138](https://github.com/JMSBPP/cfmm-vol-markets/issues/138) · parent [#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).

Orchestration path. Channel-built \(\Delta W\) → `token_flow` → Algebra Swap → `step_K` → pure CEV.
Chunk is a **pre-validated** input. \(\mu_F=0\) this slice.

## Std / host candidates

| Candidate | Fit |
|-----------|-----|
| `TokenHistoryFlow` | Reject as carrier; reuse fold/`run_step` *pattern* only |
| `StateView` | Compose (`run_swap`, `step_k`); not the runner |
| `WeinerGenerator` | Compose (`run_weiner`); Timestamp Eff |
| `CEVLocalTickVolatility` | Compose pure `intro`; not the runner |
| Host `IO` / `Outcome` | Reuse wrap; swap stage uses `Outcome` internally |
| `std::option::Option` | **Reuse** as public `run_j` result (law B) |
| Hand-rolled `Result` / 3-tag | Reject under law B |

> KEEP THIS NOTATION

\[
\begin{aligned}
\mathrm{CEVStateRunner}(\bar{dt},\,K)
&\leftarrow
\mathrm{SigmaF}\times\mathrm{LiquidityChunk}\times\mathrm{StateViewAnchor}
\\[1em]
\mathrm{io}
&::
\mathrm{SigmaF}\to\mathrm{LiquidityChunk}\to\mathrm{StateViewAnchor}
\to\mathrm{IO}\bigl(\mathrm{CEVStateRunner}(\bar{dt},\,K)\bigr)
\\[1em]
\mathrm{run}_j
&::
\mathrm{IO}\bigl(\mathrm{CEVStateRunner}(\bar{dt},\,K)\bigr)
\to\mathrm{token}\to\mathrm{from}\to j
\to\mathrm{Option}(\mathrm{CEVLocalTickVolatility})
\\[1em]
\mathrm{run}_j(m,\,\mathrm{token},\,\mathrm{from},\,j)
&=
\begin{aligned}[t]
&\mathrm{let}\ \Delta W=\mathrm{run}_{\mathrm{weiner}}(\mathrm{io}(\mathrm{WeinerCmd}\{j\})) \\
&\mathrm{let}\ \mathrm{flow}=\mathrm{token\_flow}(\sigma_F,\Delta W,\mathrm{token},\mathrm{from},\mathrm{to}=\mathrm{pool}) \\
&\mathrm{let}\ o_{\mathrm{swap}}=\mathrm{run}_{\mathrm{swap}}(\mathrm{io}(\mathrm{realize}(\mathrm{flow},\,\mathrm{pool},\,j))) \\
&\mathrm{let}\ o_{\mathrm{obs}}=\mathrm{StateView}.\mathrm{step}_K(t_{\mathrm{init}},\,K,\,j) \\
&\mathrm{let}\ c=\mathrm{CEV}.\mathrm{intro}(\sigma_F,\,\mathrm{chunk},\,o_{\mathrm{obs}}) \\
&\mathrm{Some}(c)\ \text{iff all stages succeed}
\end{aligned}
\\[1em]
\mathrm{None}
&=
K=0 \lor K\ge n(\bar{dt}) \lor j\ge K
\\
&\lor\ \Delta W=\mathrm{None}
\\
&\lor\ o_{\mathrm{swap}}=\mathrm{Outcome.None}
\\
&\lor\ o_{\mathrm{obs}}=\mathrm{None}
\\
&\lor\ \mathrm{CEV\ intro\ would\ revert}
\\[1em]
&\text{(law B: collapse — stages not distinguishable in the return type)}
\\[1em]
\mathrm{Eff}^{\mathrm{CEVStateRunner}}
&=
[\mathrm{StateView},\,\mathrm{Timestamp}]
\quad(\mathrm{WeinerView\ deferred})
\\[1em]
\sigma_F
&\in
[10^{-6},\,10^{-3}]
\quad(\sigma_F^{\mathrm{RAY}}=\sigma_F\cdot\mathrm{RAY})
\end{aligned}
\]

## SIDE_EFFECTS

\[
\begin{aligned}
\mathrm{Eff}
&=
[\mathrm{StateView},\,\mathrm{Timestamp}]
\\
\mathrm{LiquidityChunk}
&\text{ is supplied already validated; minter not on this Eff row}
\\
\mathrm{CEV}.\mathrm{intro}
&\text{ is pure (no EVM)}
\\
\mu_F
&=
0
\quad(\text{deferred})
\end{aligned}
\]

### \(\mathrm{run}_j
::
\mathrm{IO}(\mathrm{CEVStateRunner}(\bar{dt},\,K))
\to
\mathrm{token}
\to
\mathrm{from}
\to j
\to
\mathrm{Option}(\mathrm{CEVLocalTickVolatility})\)

\[
\begin{aligned}
\mathrm{run}_j(m,\,\mathrm{token},\,\mathrm{from},\,j)
&=
\mathrm{Some}(\mathrm{CEV}.\mathrm{intro}(\sigma_F,\,\mathrm{chunk},\,o_{\mathrm{obs}}))
\\
&\quad\text{after }\mathrm{run}_{\mathrm{weiner}}=\mathrm{Some}
\\
&\quad\text{and }\mathrm{run}_{\mathrm{swap}}(\mathrm{io}(\mathrm{realize}))=\mathrm{Some}
\\
&\quad\text{and }\mathrm{StateView}.\mathrm{step}_K=\mathrm{Some}(o_{\mathrm{obs}})
\\
\mathrm{None}
&=
K=0 \lor K\ge n(\bar{dt}) \lor j\ge K
\\
&\lor\ \mathrm{run}_{\mathrm{weiner}}=\mathrm{None}
\\
&\lor\ \mathrm{run}_{\mathrm{swap}}=\mathrm{None}
\\
&\lor\ \mathrm{step}_K=\mathrm{None}
\\
&\lor\ \mathrm{CEV}.\mathrm{intro}\ \text{would revert (law B; #140)}
\\
\text{BTT:}&\ \mathtt{CEVStateRunnerRunJ.btt}
\\
\text{laws:}&\ \text{Some across }j\in[0,10];\ \text{cells differ};\ \text{fuzz }\sigma_F+\mathrm{prevrandao}
\end{aligned}
\]

Define: [CEVStateRunnerRunJ.btt](CEVStateRunnerRunJ.btt) — B2 success (`#147`). Failure branches `#140`.
