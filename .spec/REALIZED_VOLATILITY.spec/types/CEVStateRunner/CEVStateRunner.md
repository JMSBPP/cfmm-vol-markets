# [TYPE:: CEV_STATE_RUNNER](MAIN_REF# MODEL)

[StateView](../StateView/StateView.md) · [CEVLocalTickVolatility](../CEVLocalTickVolatility/CEVLocalTickVolatility.md) · [TokenFlow](../TokenFlow/TokenFlow.md) · [IO](../IO/IO.md) · [LiquidityChunk](../LiquidityChunk/LiquidityChunk.md)

Plank: `src/types/CEVStateRunner.plk`. types.toml: `CEVStateRunner`.
BTT: [CEVStateRunnerRunJ.btt](CEVStateRunnerRunJ.btt) (`#139` success).
PRD: [#139](https://github.com/JMSBPP/cfmm-vol-markets/issues/139) · type [#138](https://github.com/JMSBPP/cfmm-vol-markets/issues/138) · parent [#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).

Orchestration path. One valid index \(j\). Chunk is a **pre-validated** input (LiquidityChunkMinter Eff stays off this type). CEV stays pure.

## Std / host candidates

| Candidate | Fit |
|-----------|-----|
| `TokenHistoryFlow` | Reject as carrier; reuse fold/`run_step` *pattern* only |
| `StateView` | Compose (`run_swap`, `step_k`); not the runner |
| `CEVLocalTickVolatility` | Compose pure `intro`; not the runner |
| Host `IO` / `Outcome` | Reuse wrap; swap stage uses `Outcome` internally |
| `std::option::Option` | **Reuse** as public `run_j` result (law B) |
| Hand-rolled `Result` / 3-tag | Reject under law B |

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
\to\mathrm{TokenFlow}
\to j
\to\mathrm{Option}(\mathrm{CEVLocalTickVolatility})
\\[1em]
\mathrm{run}_j(m,\,\mathrm{flow},\,j)
&=
\begin{aligned}[t]
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
[\mathrm{StateView}]
\quad(\mathrm{via}\ \mathrm{run}_{\mathrm{swap}};\ \mathrm{Xfer}\subset\mathrm{Swap})
\end{aligned}
\]

## SIDE_EFFECTS

\[
\begin{aligned}
\mathrm{Eff}
&=
[\mathrm{StateView}]
\\
\mathrm{LiquidityChunk}
&\text{ is supplied already validated; minter not on this Eff row}
\\
\mathrm{CEV}.\mathrm{intro}
&\text{ is pure (no EVM)}
\end{aligned}
\]

Holes (type phase — no bodies):

- \(\mathrm{run}_j\) — ordering + law B (`None` on any failure)
- First define locks **success** `#139`; failure branches `#140`

### \(\mathrm{run}_j
::
\mathrm{IO}(\mathrm{CEVStateRunner}(\bar{dt},\,K))
\to
\mathrm{TokenFlow}
\to j
\to
\mathrm{Option}(\mathrm{CEVLocalTickVolatility})\)

\[
\begin{aligned}
\mathrm{run}_j(m,\,\mathrm{flow},\,j)
&=
\mathrm{Some}(\mathrm{CEV}.\mathrm{intro}(\sigma_F,\,\mathrm{chunk},\,o_{\mathrm{obs}}))
\\
&\quad\text{after }\mathrm{run}_{\mathrm{swap}}(\mathrm{io}(\mathrm{realize}))=\mathrm{Some}
\\
&\quad\text{and }\mathrm{StateView}.\mathrm{step}_K=\mathrm{Some}(o_{\mathrm{obs}})
\\
\mathrm{None}
&=
K=0 \lor K\ge n(\bar{dt}) \lor j\ge K
\\
&\lor\ \mathrm{run}_{\mathrm{swap}}=\mathrm{None}
\\
&\lor\ \mathrm{step}_K=\mathrm{None}
\\
&\lor\ \mathrm{CEV}.\mathrm{intro}\ \text{would revert (law B; #140)}
\end{aligned}
\]

Define: [CEVStateRunnerRunJ.btt](CEVStateRunnerRunJ.btt) — success leaf on Integral bootstrap (`#139`).
Plank: `run_j`. Harness: `runJ(...)`.
