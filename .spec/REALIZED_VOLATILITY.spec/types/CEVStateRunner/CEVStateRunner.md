# [TYPE:: CEV_STATE_RUNNER](MAIN_REF# MODEL)

[StateView](../StateView/StateView.md) · [CEVLocalTickVolatility](../CEVLocalTickVolatility/CEVLocalTickVolatility.md) · [TokenFlow](../TokenFlow/TokenFlow.md) · [WeinerGenerator](../WeinerGenerator/WeinerGenerator.md) · [IO](../IO/IO.md) · [LiquidityChunk](../LiquidityChunk/LiquidityChunk.md)

Plank: `src/types/CEVStateRunner.plk`. types.toml: `CEVStateRunner` (`refined = true`).
BTT: [CEVStateRunnerRunJ.btt](CEVStateRunnerRunJ.btt) (`#147` success + `#140` failure).
PRD: [#141](https://github.com/JMSBPP/cfmm-vol-markets/issues/141) · define [#147](https://github.com/JMSBPP/cfmm-vol-markets/issues/147) / [#140](https://github.com/JMSBPP/cfmm-vol-markets/issues/140) · type [#138](https://github.com/JMSBPP/cfmm-vol-markets/issues/138) · parent [#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).

Orchestration path. Channel-built \(\Delta W\) → `token_flow` → Algebra Swap → `step_K` → `CEV.try_intro`.
Chunk is a **pre-validated** input. \(\mu_F=0\) (deferred). WeinerView deferred (Timestamp is the live atom).

## Std / host candidates

| Candidate | Fit |
|-----------|-----|
| `TokenHistoryFlow` | Reject as carrier; reuse fold/`run_step` *pattern* only |
| `StateView` | Compose (`run_swap`, `step_k`); not the runner |
| `WeinerGenerator` | Compose (`run_weiner`); Timestamp Eff |
| `CEVLocalTickVolatility` | Compose pure `try_intro`; not the runner |
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
&\mathrm{CEV}.\mathrm{try\_intro}(\sigma_F,\,\mathrm{chunk},\,o_{\mathrm{obs}})
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
&\lor\ \mathrm{CEV}.\mathrm{try\_intro}=\mathrm{None}
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
\quad(\sigma_F^{\mathrm{RAY}}=\sigma_F\cdot\mathrm{RAY};\ \text{success leaf})
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
\mathrm{CEV}.\mathrm{try\_intro}
&\text{ is pure (no EVM); }\mathrm{intro}\ \text{still reverts for the CEV suite}
\\
\mu_F
&=
0
\quad(\text{deferred})
\\
\mathrm{WeinerView}
&\text{ deferred — Timestamp via Shock/Weiner is the live atom}
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
\mathrm{CEV}.\mathrm{try\_intro}(\sigma_F,\,\mathrm{chunk},\,o_{\mathrm{obs}})
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
&\lor\ \mathrm{CEV}.\mathrm{try\_intro}=\mathrm{None}
\\
\text{BTT:}&\ \mathtt{CEVStateRunnerRunJ.btt}
\\
\text{laws:}&\ \text{Some across }j\in[0,10];\ \text{cells differ};\ \text{fuzz }\sigma_F+\mathrm{prevrandao}
\\
&\quad\text{fail leaves: }j\ge K;\ \mathrm{pool}=0;\ \text{CEV try\_intro None (out-of-band }\sigma_F\text{)}
\\
&\quad\text{deferred inducible: Weiner None; distinct step\_k None}
\end{aligned}
\]

Refine `#141`: `refined = true`; Eff and law B match harness evidence. No new behavior.
