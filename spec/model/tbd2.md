 import [\(\Delta Q_M, \Delta Q_{v}\)](./tbd.md)
import [\((p (i), p (i_l), p(i_u))\)](./pos_spec.md)

```
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
```

\[
	\begin{aligned}
		\Big (\Delta Q_M, \Delta Q_{v}, p(i), p(i_l), p(i_u)\Big )\, \to \, (L, i_l, i_u)
	\end{aligned}
\]

Define:
\[
	\begin{aligned}
		\Delta Q_M^{\text{max}} \, (t) = \min\Big(Q_M^{\Sigma}\, (t), \frac{ Q_{v}^{\Sigma}(t) p_{\text{risk}}(t)}{\alpha}\Big)
	\end{aligned}
\]



From quantity and pricing flows we define the nominal structure \(L\) in such way that the terminal payoff:

\[
	\begin{aligned}
		\pi \, (\bar \sigma)\, = \, L\, (i (\bar \sigma)) \,  \Big ( p ( i_u (\bar\sigma )) \, - \, p (i_l \, (\bar \sigma)) \Big ) 
	\end{aligned}
\]

```
    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        unchecked {
            return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, Constants.Q96);
        }

```
Under GDF

    function cumulativeAmount1(
        int24 roundedTick,
        uint256 totalLiquidity,
        int24 tickSpacing,
        int24 minTick,
        int24 length,
        uint256 alphaX96
    ) internal pure returns (uint256 amount1) {

```
This is:

\[
	\begin{aligned}
		\frac{\pi (\bar \sigma)}{p ( i_u (\bar\sigma )) \, - \, p (i_l \, (\bar \sigma))} \, \equiv \, L(i (\bar \sigma)) \, \equiv \, \bar L \, \frac{\xi^{i}}{\Big (\frac{1\, - \, \xi^{\iota}}{1\, - \, \xi}\Big)} \\
		\\
		\xi \in \, \mathbb{R}_+ / \{1\} \\
		\iota :: \text{u24} \\
		\bar L = \sum_{i} \, L(i\, (\bar \sigma)) 
	\end{aligned}
\]

Thus:

\[
	\begin{aligned}
		\pi \, (\bar \sigma) \, = \, \bar L \, \Big (p ( i_u (\bar\sigma )) \, - \, p (i_l \, (\bar \sigma))\Big) \, \frac{\xi^{i}}{\Big (\frac{1\, - \, \xi^{\iota}}{1\, - \, \xi}\Big)}
	\end{aligned}
\]

<
Since: 

\[
	\begin{aligned}
		L\, ( \Delta Q_M \, ;\, i (\bar \sigma)) \, &= \, \frac{\Delta Q_M}{\Big (p ( i_u (\bar\sigma )) \, - \, p (i_l \, (\bar \sigma))\Big)}
	\end{aligned}
\]


Define for a time trajectory \(T = \{t_0, \cdots ,t,\cdots, T\}\):

> This is event-driven **reactive-architecture**

\[
	\begin{aligned}
		\pi ( \bar \sigma, \xi, \iota ;\sigma (t),t) \, = \, L (i) \, ( p (i (\bar \sigma)) \, - \, p (i (\sigma \, (t)))) \, \frac{\xi^{i}}{\Big (\frac{1\, - \, \xi^{\iota}}{1\, - \, \xi}\Big)}
	\end{aligned}
\]


Then: 

\[
	\begin{aligned}
		\pi \, (\cdot , t) \, = \, \frac{\Delta Q_M}{\Big (p ( i_u (\bar\sigma )) \, - \, p (i_l \, (\bar \sigma))\Big)} \, ( p (i (\bar \sigma)) \, - \, p (i (\sigma \, (t)))) \, \frac{\xi^{i}}{\Big (\frac{1\, - \, \xi^{\iota}}{1\, - \, \xi}\Big)}
	\end{aligned}
\]

The agent objective is assuming a fixed \(\forall_t \, p_{\text{risk}}\):

\[
	\begin{aligned}
		\min_{\Delta Q_{M} (t)} \, \pi ( \cdot,t)
	\end{aligned}
\]

which is linear on \(p (i (\sigma (t)))\); thus yielding corner optimal collateral rebalancing; Thus yielding a corner optimal collateral rebalancing policy:

\[
	\begin{aligned}
		\Delta Q_M^{\star} \, (t) \, = \, \Big \{ p (i (\bar \sigma)) \, \leq  \, p (i (\sigma \, (t))):: \, 0 \, ,p (i (\bar \sigma)) \, > \, p (i (\sigma \, (t))) :: \Delta Q_M^{\text{max}} \, (t) \Big \}
	\end{aligned}
\]

> Drawback: Extremely expensive


subject to the restrictions implied by the other modules:

Help get the evm implementable schedule for \Delta Q_M
