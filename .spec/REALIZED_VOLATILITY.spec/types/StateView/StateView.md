# [TYPE:: STATE_VIEW](MAIN_REF# MODEL)

[TimeIndex](../WINDOW/TimeSpacing.md) · [WINDOW](../WINDOW/WINDOW.md) · [TokenFlow](../TokenFlow/TokenFlow.md) · [IO](../IO/IO.md)

Plank: `src/types/StateView.plk`. BTT: [StateViewIntroAnchor.btt](StateViewIntroAnchor.btt) (define). PRD [#134](https://github.com/JMSBPP/cfmm-vol-markets/issues/134).

**Std / host reuse (type phase):**

| Candidate | Use in StateView | Decision |
|-----------|------------------|----------|
| `std::option::Option` | `step_K` → `Option(ObsStep)`; `Outcome.inner` | **Reuse** |
| `types::IO::{IO, Outcome}` | `io_realize` / `run_swap` | **Reuse** (Swap arm only on `run_swap`, not `run_io`) |
| `types::TokenFlow` | `flow_j` slot in `RealizeCmd` | **Reuse** |
| `TokenHistory` nest | Same \(K\), \(\bar{dt}\) clock | **Reject carrier** — observed, no compute-only nest / Weiner |
| Hand-rolled `Outcome` | — | **Reject** — `Outcome` already wraps `Option` |

**Kind:** `indexed` — `StateView(\bar{dt}, K)`, `ObsStep(\bar{dt})`.

**Observed** tick/time series indexed by \(K\). Same bin clock as [TokenHistory](../TokenHistory/TokenHistory.md).
\[
\begin{aligned}
\mathrm{StateView}(\bar{dt},\,K)
&=
\mathrm{cell}_{K-1}(\bar{dt},\,t_{\mathrm{init}})
\,\colon\,
\mathrm{cell}_{K-2}(\bar{dt},\,t_{\mathrm{init}})
\,\colon\,
\cdots
\,\colon\,
\mathrm{cell}_0(\bar{dt},\,t_{\mathrm{init}})
\,\colon\,
\varepsilon
\quad(0 < K < n(\bar{dt}))
\end{aligned}
\]

\[
\begin{aligned}
\bar{dt}
&\in \{2,3,4,5,6,8,9,10\}
\\[1em]
\mathrm{StateView}(\bar{dt},\,0)
&=
\varepsilon
\\
\mathrm{StateView}(\bar{dt},\,S\,k)
&=
\mathrm{ObsStep}(\bar{dt})\times\mathrm{StateView}(\bar{dt},\,k)
\\[1em]
\mathrm{ObsStep}(\bar{dt})
&\leftarrow
(t,\,\mathrm{tick},\,\sqrt{p})
\\
t_j
&=
t_{\mathrm{init}} + j\cdot\bar{dt}
\\
i_j
&=
\mathrm{lastIndex}(\bar{dt},\,t_{\mathrm{init}},\,t_j)
\\
i(t)
&\equiv
\text{pool globalState tick at } t \quad(\mathrm{Tick}\,/spacing)
\\[1em]
\lvert\mathrm{StateView}\rvert
&=
K
\quad(0 < K < n(\bar{dt}))
\\
\lvert\mathrm{StateView}\rvert
&=
0
\quad(K=0 \lor K \ge n(\bar{dt}))
\\[1em]
\mathrm{step}_K
&::
t_{\mathrm{init}} \to K \to j
\to \mathrm{Option}\bigl(\mathrm{ObsStep}(\bar{dt})\bigr)
\end{aligned}
\]

> KEEP THIS NOTATION
### \(\mathrm{step}_K
::
t_{\mathrm{init}} \to K \to j
\to \mathrm{Option}\bigl(\mathrm{ObsStep}(\bar{dt})\bigr)
\)

\[
\begin{aligned}
\mathrm{flow}_j
&\leftarrow
\mathrm{TokenFlow}(\sigma_F,\,\bar{dt},\,\mathrm{token},\,\mathrm{from},\,\mathrm{to})
\quad\text{(slot at index } j \text{; refine fixes inputs)}
\\
\mathrm{realize}_j
&\equiv
\mathrm{run}_{\mathrm{swap}}\bigl(\mathrm{io}(\mathrm{flow}_j)\bigr)
\quad\text{(Swap only; not Xfer)}
\\
\mathrm{tick}_j
&:=
i\bigl(t_j^{+}\bigr)
\quad\text{after }\mathrm{realize}_j
\\
\sqrt{p_j}
&=
\sqrt{p}\bigl(\mathrm{tick}_j\bigr)
\quad(\mathrm{Q64.96})
\\
\mathrm{cell}_j(\bar{dt},\,t_{\mathrm{init}})
&\leftarrow
\bigl(t_j,\,\mathrm{tick}_j,\,\sqrt{p_j}\bigr)
\quad\text{as }\mathrm{ObsStep}(\bar{dt})
\\[1em]
&\forall K.\ \forall j.\ \bigl(0 < K < n(\bar{dt}) \land j < K\bigr)
\\
&\Longrightarrow
\mathrm{step}_K(t_{\mathrm{init}},\,K,\,j)
=
\mathrm{Some}\bigl(\mathrm{cell}_j(\bar{dt},\,t_{\mathrm{init}})\bigr)
\\
&\forall K.\ \forall j.\ \bigl(K=0 \lor K \ge n(\bar{dt}) \lor j \ge K\bigr)
\\
&\Longrightarrow
\mathrm{step}_K(t_{\mathrm{init}},\,K,\,j)
=
\mathrm{None}
\end{aligned}
\]

## SIDE_EFFECTS
\[
\begin{aligned}
\mathrm{Eff}^{\mathrm{StateView}}
&=
[\mathrm{ERC20View},\,\mathrm{Xfer},\,\mathrm{Swap}]
\\
\mathrm{Xfer}
&\subset
\mathrm{Swap}
\\
\mathrm{run}_{\mathrm{swap}}
&::
\mathrm{IO}(\mathrm{RealizeCmd})
\to
\mathrm{Outcome}
\\
\mathrm{run}_{\mathrm{swap}}(\mathrm{io}(\mathrm{realize}_j))
&=
\mathrm{Swap}(\mathrm{pool},\,\mathrm{encode}(\mathrm{flow}_j))
\end{aligned}
\]

### intro

Unlike [TokenHistory](../TokenHistory/TokenHistory.md) `intro` (Weiner nest into `Slice(memory)`), StateView **intro** only fixes the **observation anchor**: Integral **pool** + **time origin** \(t_{\mathrm{init}}\). No cells, no `realize_j`, no Eff on this op (define slice [#134](https://github.com/JMSBPP/cfmm-vol-markets/issues/134)).

\[
\begin{aligned}
\mathrm{intro}_{\mathrm{anchor}}
&::
\mathrm{Pool}(\mathrm{Algebra})
\to
\mathrm{StateViewAnchor}
\\
\mathrm{StateViewAnchor}
&\leftarrow
(\mathrm{pool},\,t_{\mathrm{init}})
\\
\mathrm{intro}_{\mathrm{anchor}}(\mathrm{pool})
&=
\bigl(
\mathrm{pool},\;
t_{\mathrm{init}} \leftarrow \mathrm{timestamp}
\bigr)
\\
\mathrm{pool\_word}(\mathrm{pool}) = 0
&\Longrightarrow
\mathrm{revert}\ \mathtt{ZeroPool}
\end{aligned}
\]

Plank: `intro_anchor`. BTT: [StateViewIntroAnchor.btt](StateViewIntroAnchor.btt). Harness: `introAnchor(address,uint256,uint256)` returns pool fields + `tInit`.

**Later intro API (holes):** `intro_len(\bar{dt}, K)` and `step_K(\mathrm{anchor}, K, j)` reuse `anchor.t_{\mathrm{init}}` and `anchor.pool`; they do not re-call `intro_{\mathrm{anchor}}`. Materializing `cell_j` still requires `realize_j` (Swap Eff).

### IO algebra (Plank names)

\[
\begin{aligned}
\mathrm{RealizeCmd}
&\leftarrow
(\mathrm{pool},\,\mathrm{flow},\,\mathrm{bin\_j})
\\
\mathrm{io}_{\mathrm{realize}}
&::
\mathrm{RealizeCmd} \to \mathrm{IO}(\mathrm{RealizeCmd})
\\
\mathrm{run}_{\mathrm{swap}}
&::
\mathrm{IO}(\mathrm{RealizeCmd}) \to \mathrm{Outcome}
\\
\mathrm{Outcome}.\mathrm{inner}
&::
\mathrm{Option}(u256)
\quad\text{(reuse \texttt{types::IO::Outcome}; \texttt{None}=revert)}
\end{aligned}
\]

> NOTE: For this, note there is not yet need for volatility-oracle, it is only a state update integragteds with token flow, one way to solve for this is to include on TokenFlow Eff [Swap] along with xFer
>
> pool_swap semanics are not fully clear yet, becuase recall the tokenFlow retutrnd the signed, unsigned quantity

> DO NOT ERASE THIS
But internally t_j and i_j, j indexes them and is pointing somewhere where time and tick dynamics are

i_j --> tick(j)

and now the fllowing happens: Use tokenFlow at index j and swap it. This realized i_j. The pool needs the RealizedVolatility.plk plugin. WE NEED TO DESIGN THIS CAREFULLY STEP BY STEOP WUTH HEVY CHUNK APPORACALS JUDICIOSLYY USING TYPE/define/refine Brady's approach
