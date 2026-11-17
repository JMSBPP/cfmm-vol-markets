import [\(\mathcal{L}\)](@spec/LiquidityChunk.spec/LiquidityChunk.md)

import [\(\pi^{c|p}\)](@spec/CoveredCall.spec/CoveredCall.md)

import [\(\pi^{\mathrm{RAN}}\)](@spec/RangeAccrual.spec/RangeAccrual.md)


# TYPE :: GOAL


\[
	\begin{aligned}
		\pi^{\sigma}_{\phi} \star (j)\, = \, G(\iota)\,\sigma_{\mathrm{RV}}^{2} \, (j)
	\end{aligned}
\]

## Premium \(\pi_{\phi}^{\sigma}\)
\(\pi_{\phi}^{\sigma}\) :  Premium = PremiumRate \(\phi\) | Utilization \(\nu\) | Exposure \(N_{\sigma}\)



### Utilization \(\nu\)
> TODO 
- import the StateViewer on the test
- have the Main readPremiumRate read from StoredPremiumRate instead of PremiumRateOnProtocol
- On the test make the assetion that IPremiumRate( ...).readPremiumRate MUST always equal and do IStateView(uniswapV4StateView).fee(marketKey)
Given \(\phi\) solving and \(\pi_{\phi}^{\sigma}\) := AssetPremiumOnProtocolWithInstrument  find  \(\nu \Big (\Delta i  ( i (j) )\Big) \) such that

\[
	\begin{aligned}
		i (j+1) = \Delta i  ( i (j) )\\
		 \pi^{\sigma}_{\phi} ( j + 1) = \phi \, \cdot \, \nu \Big (\Delta i  ( i (j) )\Big) 
	\end{aligned}
\]

Where \(\Delta i  ( i (j) )\) :=  TickDistance

Programatically 

AssetPremiumOnProtocolWithInstrument = AssetPremium (UtilizationFromTickDistance (TickDistance), PremiumRate)

where: 

AssetPremium (UtilizationFromTickDistance (TickDistance), PremiumRate) = someVariationOfMulDiv(UtilizationFromTickDistance (TickDistance), PremiumRate, FixedPoint128.Q128)


(result.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                result.sqrtPriceX96,
                SwapMath.getSqrtPriceTarget(zeroForOne, step.sqrtPriceNextX96, params.sqrtPriceLimitX96),
                result.liquidity,
                amountSpecifiedRemaining,
                swapFee
            );

feeAmount = FullMath.mulDivRoundingUp(amountIn, _feePips, MAX_SWAP_FEE - _feePips)

step.feeGrowthGlobalX128 +=
                        UnsafeMath.simpleMulDiv(step.feeAmount, FixedPoint128.Q128, result.liquidity);
						
 function crossTick(State storage self, int24 tick, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128)
        internal
        returns (int128 liquidityNet)
    {
        unchecked {
            TickInfo storage info = self.ticks[tick];
            info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
            info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
            liquidityNet = info.liquidityNet;
        }


This can be traced on the swap


###  PremiumRate \(\phi\)



# DEFINE

\[
	\begin{aligned}
		\forall\, j
		\quad
		\pi(\bar L; j)
		&=
		\pi^{c|p}(\bar L; j)
		+
		\pi^{\mathrm{RAN}}(\bar L; j)
	\end{aligned}
\]

# REFINE
