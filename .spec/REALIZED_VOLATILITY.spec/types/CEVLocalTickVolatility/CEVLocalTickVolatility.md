# [TYPE:: CEV_LOCAL_TICK_VOLATILITY](MAIN_REF# MODEL)

[SigmaF](../SigmaF/SigmaF.md) · [WINDOW](../WINDOW/TimeSpacing.md)

Compute-only cell this slice. \(\sqrt{p}\) is an intro argument; refine adds `StateView`. `LiquidityChunkMinter` is a named Eff / prereq — no mint body here. Generic `History(A)` is a later TODO refactor, not this type.

\[
\begin{aligned}
\mathrm{CEVLocalTickVolatility}
&\leftarrow
\{\mathrm{tick}:\mathrm{Tick},\,\sigma:\mathrm{u88}_{\mathrm{tick}^{2}}\}
\\
\mathrm{kind}
&=
\mathrm{dependent}
\quad(\sigma_F,\,L_{1/2},\,\sqrt{p})
\\[1em]
L_{1/2}
&:
\mathrm{u128}
\\
\sqrt{p}
&:
\mathrm{Q64.96}
\\
\mathrm{LN\_10001}
&:
\mathrm{RAY}
\\[1em]
\mathrm{ratio}
&=
\frac{\sigma_F}{L_{1/2}\,\mathrm{LN\_10001}\,\sqrt{p}}
\\
\sigma
&=
(\mathrm{ratio})^{2}
\in
\mathrm{u88}_{\mathrm{tick}^{2}}
\\
\mathrm{tick}
&=
\mathrm{Tick}(\sqrt{p})
\\[1em]
\mathrm{intro}
&::
\mathrm{SigmaF}\to L_{1/2}\to\sqrt{p}
\to\mathrm{CEVLocalTickVolatility}
\\[1em]
L_{1/2}=0
&\implies
\mathrm{revert}\ \mathtt{ZeroLiquidity}
\\
\sqrt{p}=0
&\implies
\mathrm{revert}\ \mathtt{ZeroSqrtPrice}
\\
\sigma\notin\mathrm{u88}
&\implies
\mathrm{revert}\ \mathtt{SigmaOverflowU88}
\\[1em]
\mathrm{CEVHistory}(\bar{dt},\,0)
&=
\varepsilon
\\
\mathrm{CEVHistory}(\bar{dt},\,S\,k)
&=
\mathrm{CEVLocalTickVolatility}\times\mathrm{CEVHistory}(\bar{dt},\,k)
\\[1em]
\mathrm{io}
&::
T\to\mathrm{IO}(T)
\\
\mathrm{run}
&::
\mathrm{IO}(T)\to\cdot
\\
\mathrm{Eff}
&=
[\mathrm{StateView},\,\mathrm{LiquidityChunkMinter}]
\\
\mathrm{StateView}
&=
\mathrm{staticcall}\ \sqrt{p}
\quad(\mathrm{hole};\ \mathrm{intro}\ \mathrm{takes}\ \sqrt{p}\ \mathrm{as}\ \mathrm{arg})
\\
\mathrm{LiquidityChunkMinter}
&=
\mathrm{call}\ \mathrm{mint}
\quad(\mathrm{prereq};\ \mathrm{no}\ \mathrm{body})
\end{aligned}
\]

Define: `intro` filled. Behavior tree: [CEVLocalTickVolatility.btt](CEVLocalTickVolatility.btt). \(\sigma\) via `try_cast_uint(_, u88)`. `LN_10001` from ExpMath `HALF_LN`·2·1e9.
