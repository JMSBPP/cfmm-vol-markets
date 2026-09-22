# [TYPE:: HISTORY](MAIN_REF# MODEL)

[TimeIndex](../WINDOW/TimeSpacing.md) · [SigmaF](../SigmaF/SigmaF.md) · [Weiner](../WeinerGenerator/WeinerGenerator.md)

Compute-only. Carrier is inductive in \(K\). `Slice(memory)` is the buffer `intro` writes into, not the series type. No Xfer.

\[
\begin{aligned}
\bar{dt}
&\in \{2,3,4,5,6,8,9,10\}
\\
K
&\le
n(\bar{dt})
\\[1em]
\mathrm{History}(\bar{dt},\,0)
&=
\varepsilon
\\
\mathrm{History}(\bar{dt},\,S\,k)
&=
\mathrm{Step}(\bar{dt})\times\mathrm{History}(\bar{dt},\,k)
\\[1em]
\mathrm{Step}(\bar{dt})
&\leftarrow
(t,\,i,\,\Delta W(\bar{dt}),\,\Delta Q_M)
\\
t_j
&=
t_{\mathrm{init}} + j\cdot\bar{dt}
\\
i_j
&=
\mathrm{lastIndex}(\bar{dt},\,t_{\mathrm{init}},\,t_j)
\\
\Delta W_j
&=
\mathrm{shock}(\bar{dt},\,j)
\\
\Delta Q_{M,j}
&=
\sigma_F \cdot \Delta W_j
\\[1em]
\mathrm{intro}
&::
\mathrm{weiner} \to \mathrm{SigmaF} \to t_{\mathrm{init}} \to K
\to \lvert \mathrm{History} \rvert
\\
\mathrm{intro}
&=
K
\quad(0 < K < n(\bar{dt}))
\\
\mathrm{intro}
&=
0
\quad(K=0 \lor K \ge n(\bar{dt}))
\\
\mathrm{step}_K
&::
\mathrm{weiner} \to \mathrm{SigmaF} \to t_{\mathrm{init}} \to K \to j
\to \mathrm{Option}\bigl(\mathrm{Step}(\bar{dt})\bigr)
\\
\mathrm{Some}
&=
0 < K < n(\bar{dt}) \land j < K
\\[1em]
\mathrm{Eff}
&=
[\mathrm{WeinerView}]
\\
\mathrm{WeinerView}
&=
\mathrm{staticcall}\ \mathrm{shock}(\bar{dt},\,j)
\end{aligned}
\]

ABI `intro` returns \(\lvert\mathrm{History}\rvert=K\). Cells are `step_K(j)`, not a fixed two-Step unpack. TokenAmount / Dir are equations on `ΔW_j`, not Step fields.
