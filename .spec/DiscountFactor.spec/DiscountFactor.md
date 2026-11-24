Represents for the user how much it discounts (symetrically) a reference price \(\sqrt{p_k}\) with respect. This is, it defines: \([\frac{\sqrt{p_K}}{m} ,  m \cdot \sqrt{p_k}]\). Then:

\[
	\begin{aligned}
		m_{ij} \equiv \frac{\sqrt{p_j}}{\sqrt{p_i}}
	\end{aligned}
\]

Given [\(\Delta_{\texttt{tick}}\)](.spec/cfmm_types.spec/TickSpacing.spec). From [\(\texttt{tick} (\Delta_{\texttt{tick}} ; {\sqrt{p}})\)](.spec/cfmm_types.spec/Tick.spec).

Define:


\[
	\begin{aligned}
		m^{\texttt{tick}}_{ij} = \texttt{tick} (\Delta_{\texttt{tick}} ; {\sqrt{p_j}}) - \texttt{tick} (\Delta_{\texttt{tick}} ; {\sqrt{p_i}})
	\end{aligned}
\]

Take[\( \iota (\Delta_{\texttt{tick}})\)](.spec/Iota.spec)

Define now:

\[
	\begin{aligned}
		\iota_{ij} (\Delta_{\texttt{tick}}\, ; \, m^{\texttt{tick}}_{ij}) = \frac{m^{\texttt{tick}}_{ij}}{\Delta_{\texttt{tick}}}
	\end{aligned}
\]

From [\(\pi^{\texttt{L}} \, \bigg (L_{1/2} \Big (\sqrt{p_k} , \iota (\Delta_{\texttt{tick}}\Big )\bigg)\)](.spec/cfmm_types.spec/Payoff.spec) and [\(\pi^{c | p} \, (\sqrt{p_k})\)](.spec/cfmm_types.spec/Payoff.spec)


Given/provided [\(\sigma_K\)](.spec/Variance.spec/InputVariance.spec) and [\(W\)](.spec/TickMoments.spec/Window.spec)

Define:

\[
	\begin{aligned}
		m^{\texttt{L} \to c|p} : \pi^{\texttt{L}} \, \bigg (L_{1/2} \Big (\sqrt{p_k} , \iota_{ij} (\Delta_{\texttt{tick}}\, ; \,m^{\texttt{L} \to c|p})\bigg) \overbrace{=}^{\texttt{replicates}} \, \pi^{c | p} \, (\sqrt{p_k})
		\\
		\\
		m^{\texttt{L} \to c|p} \, \Big (\sigma_K , W_{\texttt{idx}}\Big) = \Big ( \frac{1\, + \, \sigma_K \, \sqrt{\frac{W_{\texttt{idx}}}{2\pi}}}{1\, - \, \sigma_K \, \sqrt{\frac{W_{\texttt{idx}}}{2\pi}}}\Big )^{2}
	\end{aligned}
\]


This is the discount factor that replicates a long call or short put payoff by providing liquidity on a constant product market maker from an input variance and window idx 


We have two constructors of discount factor and some mappings to iota , b

## NEXT...
### How does it map to the instruments on panoptic ? optionRatio ? width ? ...
	> optionRatio MUST be between 1 and 127. Thus it actually fits 8 bits
    > width MUST be between 1 and 2048. Thus it fits 16 bits   

#### **optionRatio** \(o (\texttt{legIdx})\)

lib/panoptic-v2-core/lib/panoptic-helper/test/PanopticQuery.t.sol
```
struct Leg {
	...
    uint256 optionRatio;
	...
}
```

lib/panoptic-v2-core/test/foundry/libraries/PanopticMath.t.sol
uint256 optionRatio = bound(optionRatioSeed, 1, 127);

lib/panoptic-v2-core/test/foundry/coreV3/CollateralTracker.t.sol:       
```
uint128 contractLegSize = positionSize * uint128(tokenId.optionRatio(i));
```
\[
	\begin{aligned}
		\bar L_{1/2} (\texttt{legIdx}) = N_{\sigma} \cdot \, o (\texttt{legIdx}) \\
	\end{aligned}
\]

lib/panoptic-v2-core/test/foundry/coreV3/SemiFungiblePositionManager.t.sol
```	
positionSize = positionSize / uint128(shortRatio);
```
lib/panoptic-v2-core/test/foundry/types/TokenId.t.sol
```
// the optionRatio is 7 bits so mask it:
uint16 MASK = 0x7F; // takes first 7 bits of the uint16
optionRatio = optionRatio & MASK;
```

lib/panoptic-v2-core/lib/panoptic-helper/src/StrategyBuilder.sol
    \(\pi\)
  |
  |     (iron condor)
  |         -----
  |        /     \
  |---------------------  \(\sqrt{p}\)
         /         \
      ----          ----
    |-\(\iota_1\) -|      
   |----------\(\iota_2\)-----------|


\[
	\begin{aligned}
		\texttt{ironCondor} (\iota_1, i^c_K (i^p_K)), \iota_2 )
	\end{aligned}
\]

#### **width** \(\iota (\texttt{legIdx})\)

lib/panoptic-v2-core/test/foundry/libraries/PanopticMath.t.sol
```
width = int24(bound(width, 1, 2048));
(rangeDown, rangeUp) = PanopticMath.getRangesFromStrike(width, int24(tickSpacing));
```

/// @dev Given `r = (width * tickSpacing) / 2`, `tickLower = strike - floor(r)` and `tickUpper = strike + ceil(r)`.
> strike belongs to the domain of calls and puts whereas low and up is on the domain of providing liquidity
\[
	\begin{aligned}
		\texttt{tickLow} (\Delta_{\texttt{tick}} , \texttt{tickStrike} (\Delta_{\texttt{tick}}), \iota (\Delta_i))= \texttt{tickStrike} (\Delta_{\texttt{tick}}) \, - \, \frac{\Delta_{\texttt{tick}}}{2} \, \cdot \iota (\Delta_{\texttt{tick}}) \\
			\texttt{tickUp} (\Delta_{\texttt{tick}} , \texttt{tickStrike} (\Delta_{\texttt{tick}}), \iota (\Delta_i))= \texttt{tickStrike} (\Delta_{\texttt{tick}}) \, + \, \frac{\Delta_{\texttt{tick}}}{2} \, \cdot \iota (\Delta_{\texttt{tick}})		
	\end{aligned}
\]



lib/panoptic-v2-core/test/foundry/coreV3/CollateralTracker.t.sol: 

```
uint256 widthSeed = int24(uint24(bound(widthSeed, 1, 4095)))
```


> Notice how variance always has time related multipliers. Above is not the execption

> How to represent 2 pi on solidity what patterns are out there.


