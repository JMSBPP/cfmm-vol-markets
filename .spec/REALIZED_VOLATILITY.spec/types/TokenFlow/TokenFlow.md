# [TYPE:: TOKEN_FLOW](MAIN_REF# MODEL)

\[
\begin{aligned}
\mathrm{TokenFlow}(\sigma_F,\,\bar{dt},\,\mathrm{token},\,\mathrm{from},\,\mathrm{to})
&\leftarrow
(\mathrm{TokenAmount},\,\mathrm{Dir})
\\[1em]
\mathrm{intro}
&::
\mathrm{SigmaF} \to \Delta W(\bar{dt}) \to \mathrm{token} \to \mathrm{from} \to \mathrm{to}
\to \mathrm{TokenFlow}(\sigma_F,\,\bar{dt},\,\mathrm{token},\,\mathrm{from},\,\mathrm{to})
\\
\mathrm{intro}(\sigma_F,\,\Delta W,\,\mathrm{token},\,\mathrm{from},\,\mathrm{to})
&=
\left(
\frac{\sigma_F \cdot \lvert \Delta W \rvert}{\mathrm{RAY}},\,
\mathrm{sign}(\Delta W)
\right)
\\
\bar{dt}
&\subset
\Delta W
\\[1em]
\mathrm{Eff}
&=
[\mathrm{ERC20View},\,\mathrm{Xfer}]
\\
\mathrm{ERC20View}
&=
\mathrm{balanceOf}
\\
\mathrm{Xfer}
&=
\mathrm{transferFrom}
\end{aligned}
\]
