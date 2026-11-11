[\[
	\begin{aligned}
		\bigg (N_K, \Big\{ (i_K, \sigma (i_K), \mu (i_K))\Big\}_{j=1}^{N_K} \bigg)
		\, \overbrace{\leadsto}^{\texttt{LiquidityKernel}} \,
		\Big(
			\big(\Gamma_{\varphi},\; m_{\Gamma}\big),\;
			\ell,\;
			L(i_K),\;
			L(\Gamma_i)
		\Big)
	\end{aligned}
\]](../root.md)



### SemiFungiblePositionManagerV4.sol

mintTokenizedPosition                        (external)
   |   
    --- _unlockAndCreatePositionInAMM         (internal)
              |
               -- unlockCallback              (external) (only POOL_MANAGER)
                      |
                       --- createPositionInAMM  (internal)
                                  |
                                x 4 createLegInAMM  (internal)
                                 [   (i , i_j , L, isBurn) -> 
									    (LeftRightSigned moved, LeftRightUnsigned collectedSingleLeg) ]
	                              
### POOL_MANAGER_V4.modifyLiquidity

- Given the tick spacing \(\Delta_i\) we define a liquidity base \(\xi^{\star} = \lambda^{-\Delta_i/2}\) and 
- What we are given on panoptic is that once we add liquidity, \(\bar L_{1/2}\) on a chunk we have the state over the range \([i_l, i_u]\) :

\[
	\begin{aligned}
		\bar L_{1/2} \, &= \, \sum_{i_k = i_l}^{i_u} \, L(i_k) \\
		L(i_k) \, &= \, \bar L_{1/2} \cdot \ell (i_k, \iota, \xi^{\star}) ; \quad \iota > 1 \\
		\\
		\ell (i_k, \iota, \xi^{\star}) =  \frac{\xi^{i_K}}{\Big ( \frac{1 - \xi^{\iota}}{1 - \xi}\Big)} \\
		G(\iota) \, = \, \frac{\bar L_{(1/2,\,0)}}{2}\,\frac{1-\xi^{\star}}{1-(\xi^{\star})^{\iota}}
	\end{aligned}
\]

> \(\iota\) is a control parameter

Simulatenously we have defined:

\(\Gamma_{\varphi}(i) \, \equiv \, \xi^{\,-3 \,(i + \Delta_i/2)}\)

Now there is an input \(g > 0\): 

\[
	\begin{aligned}
		G(\iota) \, \ge \, g
	\end{aligned}
\]
Now over a window \(W\) we have that \(i : [i_l, i_u]\) moves and generates:

\[
	\begin{aligned}
		\sigma_{\texttt{RV}}\, (i_j) = \frac{1}{W} \, \sum_{j=1}^{W}\, (i_j - i_{\mu})^{2}
	\end{aligned}
\]
and then ping \(\pi^{\sigma}_{\mathrm{no\,fee}} (i_j)= G(\iota)\,\sigma_{\mathrm{RV}}^{2} \, (i_j)\)

where \(\pi^{\sigma}_{\mathrm{no\,fee}} = \texttt{getAccountPremium}\)


- \(\texttt{getAccountPremium}\) are sophisticated wrappers of \(\texttt{V4StateReader.getFeeGrowthInside}\)

> tokenType is fixed per call and given to filter the positionKey from where feeGrowth will be queried
> isLong is to determine if the premium is owed or accrued
> vegoid,owner, poolKey and tickBounds are fixed

Thus \(\pi^{\sigma}_{\phi} (i_j) = \texttt{getAccountPremium} (i_j)\)
modifyLiquidity(State storage self, ModifyLiquidityParams memory params) -> return (feeDelta){
    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
                    getFeeGrowthInside(self, tickLower, tickUpper) {
						getFeeGwothInside (\(i_j\))
					}
	Position.State storage position = self.positions.get(params.owner, tickLower, tickUpper, params.salt);
	(uint256 feesOwed0, uint256 feesOwed1) = position.update(
	                                                       liquidityDelta, 
														   feeGrowthInside0X128, 
														   feeGrowthInside1X128);

} feeDelta(feesOwed0,feesOwed1) 

## \(i_j \to i_{j+1}\)[GREEN.AlignTickTest](@/test/ProtocolSync/AlignTick.t.sol)
\[
	\begin{aligned}
		\texttt{TickTransitionCfg} \implies \texttt{TickTransition} \\
		\Big (X = 0 \implies \neg \, \texttt{TickTransition} \Big )\, \wedge \, \Big (\sqrt{p} (i_{j+1}) \geq \sqrt{p} (i_j) \implies \neg \texttt{TickTransition}\Big )\\
		\implies \\
		\texttt{TickTransitionCfg} := \Big ( \sqrt{p} (i_{j+1}) < \sqrt{p} (i_j)\,,\, (X \mid X  \neq 0),\,  \sqrt{p} (i_{j+1})\Big)
	\end{aligned}
\]
## \(\phi \wedge i_j \to i_{j+1}\)[GREEN.NoFeeVarianceClaimBuilderTest.test__PanopticWhenSetTickOnMainItUpdatesCfmmTickToTickCalldata](@/test/NoFeeVarianceClaimBuilderTest.t.sol)
## \(\mathrm{I}_{\sigma}\)

It is a combination between tokenId and liquidityChunk. From here
```
mintTokenizedPosition                        (external)
   |   
    --- _unlockAndCreatePositionInAMM         (internal)
```


The first to pass is 

mintTokenizedPosition    
   |   ---------------------> tokenId.validate()
    --- _unlockAndCreatePositionInAMM  
There are four legs with indices 0,1,2,3

VarianceSwapInstrument =[replicated] OptionLegs[4]
```
- if (self.optionRatio(0) == 0) revert Errors.InvalidTokenIdParameter(1);
      if (self.optionRatio(i) == 0) {
           // final leg in this position identified;
            ...
	  }		

```
> initializeInstrument should only be callable after a market has been assigned
[MarketAssigned]initializeInstrument (\(\iota_{\texttt{init}}\)) -> \(\iota (\mathrm{I}^{(0)}_{\sigma}) \leftarrow \iota_{\texttt{init}}\)
--> InstrumentInitialized
Define \(\texttt{termsIdx} = \{1,2,3\}\)
finalizeInstrument (\texttt{termsIdx}) -> \(\iota (\mathrm{I}^{(\texttt{termsIdx})}_{\sigma}) = 0\)

> From now all we now is \(\iota_{\texttt{init}} > 1\)


/// @notice AND mask to clear all bits except for the components of the chunk key (strike, width, tokenType) for each leg.
uint256 internal constant CHUNK_MASK =
        0xFFFFFFFFF200_FFFFFFFFF200_FFFFFFFFF200_FFFFFFFFF200_0000000000000000;

tokenType = PUT | CALL

