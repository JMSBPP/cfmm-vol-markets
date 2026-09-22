# [TYPE:: TOKEN_HISTORY](MAIN_REF# MODEL)

[TimeIndex](../WINDOW/TimeSpacing.md) · [SigmaF](../SigmaF/SigmaF.md) · [Weiner](../WeinerGenerator/WeinerGenerator.md)

Compute-only. Carrier is inductive in \(K\). `Slice(memory)` is the allocation buffer (`intro` writes the nest; `intro_k` writes a prefix of Steps). No Xfer.

\[
\begin{aligned}
\bar{dt}
&\in \{2,3,4,5,6,8,9,10\}
\\[1em]
\mathrm{TokenHistory}(\bar{dt},\,0)
&=
\varepsilon
\\
\mathrm{TokenHistory}(\bar{dt},\,S\,k)
&=
\mathrm{Step}(\bar{dt})\times\mathrm{TokenHistory}(\bar{dt},\,k)
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
\mathrm{intro\_from}
&::
\mathrm{weiner} \to \mathrm{SigmaF} \to t_{\mathrm{init}} \to K
\to \mathrm{TokenHistory}(\bar{dt},\,K)
\\
\mathrm{intro\_from}(0)
&=
\varepsilon
\\
\mathrm{intro\_from}(S\,k)
&=
\mathrm{step}(\mathrm{off})\colon\mathrm{intro\_from}(k)
\\
\mathrm{intro}
&::
\mathrm{weiner} \to \mathrm{SigmaF} \to t_{\mathrm{init}} \to K
\to \mathrm{Slice}\bigl(\mathrm{memory},\,\mathrm{TokenHistory}(\bar{dt},\,K),\,1\bigr)
\\
\mathrm{intro\_k}
&::
\mathrm{weiner} \to \mathrm{SigmaF} \to t_{\mathrm{init}} \to K
\to \mathrm{Option}\bigl(\mathrm{Slice}(\mathrm{memory},\,\mathrm{Step}(\bar{dt}))\bigr)
\\
\mathrm{Some}
&=
0 < K < n(\bar{dt})
\\[1em]
\lvert\mathrm{TokenHistory}\rvert
&=
K
\quad(0 < K < n(\bar{dt}))
\\
\lvert\mathrm{TokenHistory}\rvert
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

Nest index \(K\in\mathbb{N}\) includes \(\varepsilon\). Public prefix (`intro_k`, `step_K`, ABI length) is Some iff \(0<K<n(\bar{dt})\). ABI `intro` returns that length; cells are `step_K(j)`. TokenAmount / Dir are equations on \(\Delta W_j\), not Step fields.
