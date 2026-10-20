# [TYPE:: CEV_LOCAL_TICK_VOLATILITY](MAIN_REF# MODEL)

[SigmaF](../SigmaF/SigmaF.md) · [LiquidityChunk](../LiquidityChunk/LiquidityChunk.md) · [StateView](../StateView/StateView.md) · [WINDOW](../WINDOW/TimeSpacing.md)

Plank: `src/types/CEVLocalTickVolatility.plk`. Behaviors:
[CEVLocalTickVolatility.btt](CEVLocalTickVolatility.btt) and
[CEVHistory.btt](CEVHistory.btt). Refinement: [#135](https://github.com/JMSBPP/cfmm-vol-markets/issues/135).

\[
\begin{aligned}
\mathrm{CEVLocalTickVolatility}
&\leftarrow
\{\mathrm{tick}:\mathrm{Tick},\,\sigma:\mathrm{u88}_{\mathrm{tick}^{2}}\}
\\
\mathrm{kind}
&=
\mathrm{dependent}
\quad(\sigma_F,\,\mathrm{LiquidityChunk},\,\mathrm{ObsStep}(\bar{dt}))
\\[1em]
L_{1/2}
&:=
\mathrm{LiquidityChunk}.\mathrm{liquidity}
:
\mathrm{u128}
\\
\sqrt{p_j}
&:=
\mathrm{ObsStep}(\bar{dt}).\sqrt{p}
:
\mathrm{Q64.96}
\\
\mathrm{tick}_j
&:=
\mathrm{ObsStep}(\bar{dt}).\mathrm{tick}
\\
\mathrm{LN\_10001}
&:
\mathrm{RAY}
\\[1em]
\mathrm{ratio}_j
&=
\left\lfloor
\frac{\sigma_F}
{L_{1/2}\,\mathrm{LN\_10001}\,\sqrt{p_j}}
\right\rfloor
\\
\sigma_j
&=
\mathrm{ratio}_j^2
\in
\mathrm{u88}_{\mathrm{tick}^{2}}
\end{aligned}
\]

The raw scales cancel before the unscaled tick result:

\[
\begin{aligned}
\sigma_{F,\mathrm{raw}}
&=
\sigma_F\cdot 10^{27}
&
\mathrm{LN\_10001}_{\mathrm{raw}}
&=
\ln(1.0001)\cdot 10^{27}
\\
\sqrt{p}_{\mathrm{raw}}
&=
\sqrt{p}\cdot 2^{96}
&
\mathrm{ratio}_j
&=
\left\lfloor
\frac{\sigma_{F,\mathrm{raw}}\cdot 2^{96}}
{\sqrt{p}_{\mathrm{raw}}}
\right\rfloor
\mathbin{/}L_{1/2}
\mathbin{/}\mathrm{LN\_10001}_{\mathrm{raw}}
\end{aligned}
\]

The factored evaluation avoids constructing
\(L_{1/2}\cdot\mathrm{LN\_10001}\cdot\sqrt{p}\) in one `u256`.
A log/exp rewrite is not used: it is algebraically equivalent and does not
remove any dependence between liquidity and price.

### \(\mathrm{intro}
::
\mathrm{SigmaF}
\to
\mathrm{LiquidityChunk}
\to
\mathrm{ObsStep}(\bar{dt})
\to
\mathrm{CEVLocalTickVolatility}\)

\[
\begin{aligned}
\mathrm{intro}(\sigma_F,\,c,\,o)
&=
\bigl(
\mathrm{tick}\leftarrow o.\mathrm{tick},\,
\sigma\leftarrow
\mathrm{u88}\bigl(\mathrm{ratio}(\sigma_F,c.\mathrm{liquidity},o.\sqrt p)^2\bigr)
\bigr)
\\
c.\mathrm{liquidity}=0
&\Longrightarrow
\mathrm{revert}\ \mathtt{ZeroLiquidity}
\\
o.\sqrt p=0
&\Longrightarrow
\mathrm{revert}\ \mathtt{ZeroSqrtPrice}
\\
\mathrm{ratio}^2\notin\mathrm{u88}
&\Longrightarrow
\mathrm{revert}\ \mathtt{SigmaOverflowU88}
\end{aligned}
\]

The observed pool tick is authoritative. Algebra explicitly permits
\(o.\mathrm{tick}\ne\mathrm{Tick}(o.\sqrt p)\) on an initialized tick boundary.

### \(\mathrm{intro\_len}
::
\bar{dt}\to K\to\mathbb{N}\)

\[
\mathrm{intro\_len}(\bar{dt},K)
=
\begin{cases}
K & 0<K<n(\bar{dt})\\
0 & K=0\lor K\ge n(\bar{dt})
\end{cases}
\]

### \(\mathrm{step}_K
::
\mathrm{SigmaF}
\to
\mathrm{LiquidityChunk}
\to
\mathrm{ObsStep}(\bar{dt})
\to K\to j
\to
\mathrm{Option}(\mathrm{CEVLocalTickVolatility})\)

\[
\begin{aligned}
0<K<n(\bar{dt})\land j<K
&\Longrightarrow
\mathrm{step}_K(\sigma_F,c,o_j,K,j)
=
\mathrm{Some}(\mathrm{intro}(\sigma_F,c,o_j))
\\
K=0\lor K\ge n(\bar{dt})\lor j\ge K
&\Longrightarrow
\mathrm{step}_K(\sigma_F,c,o_j,K,j)
=
\mathrm{None}
\end{aligned}
\]

\[
\begin{aligned}
\mathrm{CEVHistory}(\bar{dt},0)
&=
\varepsilon
\\
\mathrm{CEVHistory}(\bar{dt},S\,k)
&=
\mathrm{CEVLocalTickVolatility}
\times
\mathrm{CEVHistory}(\bar{dt},k)
\end{aligned}
\]

## SIDE_EFFECTS

\[
\begin{aligned}
\mathrm{Eff}^{\mathrm{CEV}}
&=
[\mathrm{StateView},\,\mathrm{LiquidityChunkMinter}]
\\
\mathrm{StateView}
&\Longrightarrow
\mathrm{ObsStep}(\bar{dt})\ \text{is supplied before }\mathrm{intro}
\\
\mathrm{LiquidityChunkMinter}
&\Longrightarrow
\mathrm{LiquidityChunk}\ \text{is supplied before }\mathrm{intro}
\end{aligned}
\]

These are discharged prerequisites. `intro` and `step_K` perform no EVM call.
The effectful order
`run_swap → StateView.step_k → CEV intro` belongs to
[#136](https://github.com/JMSBPP/cfmm-vol-markets/issues/136).
