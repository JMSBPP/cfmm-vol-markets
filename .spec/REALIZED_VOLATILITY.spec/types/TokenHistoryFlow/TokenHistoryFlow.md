# [TYPE:: TOKEN_HISTORY_FLOW](MAIN_REF# MODEL)

[TokenHistory](../TokenHistory/TokenHistory.md) · [TokenFlow](../TokenFlow/TokenFlow.md) · [IO](../IO/IO.md)

Series command. Shared `(token, from, to)`. Each Step is one `TokenFlow`. No Approve / Mint.

\[
\begin{aligned}
\mathrm{TokenHistoryFlow}(\bar{dt},\,K)
&\leftarrow
\mathrm{TokenHistory}(\bar{dt},\,K)\times(\mathrm{token},\,\mathrm{from},\,\mathrm{to})
\\[1em]
\mathrm{io}
&::
\mathrm{TokenHistory}(\bar{dt},\,K)\to\mathrm{token}\to\mathrm{from}\to\mathrm{to}
\to\mathrm{IO}\bigl(\mathrm{TokenHistoryFlow}(\bar{dt},\,K)\bigr)
\\[1em]
\mathrm{run}
&::
\mathrm{IO}\bigl(\mathrm{TokenHistoryFlow}(\bar{dt},\,K)\bigr)\to\mathrm{Outcome}
\\
\mathrm{run}
&=
\mathrm{fold}_{j<K}\ \mathrm{run}\bigl(\mathrm{io}(\mathrm{token\_flow}(\mathrm{Step}_j))\bigr)
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
\mathrm{None}
&=
\text{first failing Xfer; later }j\text{ not run}
\\[1em]
K\text{ comptime}
&\implies
\mathrm{std{::}utils{::}fold}
\\
K\text{ runtime}
&\implies
\mathrm{run}_K=\mathrm{while}\ j<K\ \mathrm{run}(\mathrm{io}(\mathrm{Step}_j))
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

Reuse `TokenFlow`, `IO`, `run_io`, `Outcome`/`Option`, `step_k`. First define: `K=2`, `+ΔW` then `−ΔW`.
