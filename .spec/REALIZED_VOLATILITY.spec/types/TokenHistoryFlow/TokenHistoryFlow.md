# [TYPE:: TOKEN_HISTORY_FLOW](MAIN_REF# MODEL)

[TokenHistory](../TokenHistory/TokenHistory.md) · [TokenFlow](../TokenFlow/TokenFlow.md) · [IO](../IO/IO.md)

Series command. Shared `(token, from, to)`. Each Step is one `TokenFlow`. No Approve / Mint.

Public executor is \(\mathrm{run}_K\). \(\mathrm{run\_hist}\) (K=2 nest unroll) stays in the module; it is not a public law. \(\mathrm{std{::}utils{::}fold}\) does not capture a runtime History.

\[
\begin{aligned}
\mathrm{TokenHistoryFlow}(\bar{dt},\,K)
&\leftarrow
\mathrm{TokenHistory}(\bar{dt},\,K)\times(\mathrm{token},\,\mathrm{from},\,\mathrm{to})
\\[1em]
\mathrm{run}_K
&::
\mathrm{weiner}\to\mathrm{SigmaF}\to t_{\mathrm{init}}\to K
\to\mathrm{token}\to\mathrm{from}\to\mathrm{to}
\to\mathrm{Outcome}
\\
\mathrm{run}_K
&=
\mathrm{while}\ j<K\ \mathrm{run\_step}_K(j)
\\
\mathrm{None}
&=
K=0 \lor K \ge n(\bar{dt})
\\
\mathrm{run\_step}_K(j)
&=
\mathrm{run}\bigl(\mathrm{io}(\mathrm{token\_flow}(\mathrm{step}_K(j)))\bigr)
\\
\mathrm{None}
&=
\text{prefix invalid}\lor j\ge K\text{; first None stops later }j
\\[1em]
\Delta W_j \ge 0
&\implies
\mathrm{Xfer}(\mathrm{from},\,\mathrm{to},\,\mathrm{amt}_j)
\\
\Delta W_j < 0
&\implies
\mathrm{Xfer}(\mathrm{to},\,\mathrm{from},\,\mathrm{amt}_j)
\\
\mathrm{amt}_j
&=
\frac{\sigma_F\cdot\lvert\Delta W_j\rvert}{\mathrm{RAY}}
\\[1em]
\mathrm{Eff}
&=
[\mathrm{WeinerView},\,\mathrm{Xfer}]
\\
\mathrm{WeinerView}
&=
\mathrm{staticcall}\ \mathrm{shock}(\bar{dt},\,j)
\\
\mathrm{Xfer}
&=
\mathrm{call}\ \mathrm{transferFrom}
\end{aligned}
\]

Reuse `TokenFlow`, `IO`, `run_io`, `Outcome`/`Option`, `step_k`. Fuzz: \(1\le K\le 128\) (block gas); algebra \(K<n(\bar{dt})\) does not fit a block.
