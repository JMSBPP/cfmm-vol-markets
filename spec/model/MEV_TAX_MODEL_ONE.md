


1. Have L, v, phi, i as the kernel where variation will be realized


A pool with the dynamic FeePlugin where one can write prices freely


UniswapV4MevTaxModelOneShocksWriter::

- interface :: 
		
	write_price (poolId, tick, sqrtPrice) -> \(\frac{\Delta p}{p}\)
	write_returned_adj_txl_volume_rate(poolId, vol_rate) -> \(\delta_{\text{trans}}\)
	write_txl_volume_decay_rate(poolId, decay_rate) -> \(\alpha_{\text{trans}}\)
	
		-->  As a router it unblocks the poolManager, sends a swap wtih fixed calldata such that hookData has



\[
	\begin{aligned}
		\text{shocks} := (p_{\varphi} (i_{t+1}), i_{t+1})
	\end{aligned}
\]

- How algebra keeps track of \(\nu\) on the Dynamic Fee sigmoid plugin ?



(liquidity, volumePerLiquidityInBlock) 
	= (currentLiquidity,
	   cache.volumePerLiquidityInBlock + IDataStorageOperator(dataStorageOperator).calculateVolumePerLiquidity(currentLiquidity, amount0, amount1)
	  



UniswapV4MevTaxModelOneShocksExecutor:: 

library :: before_swap
  ---> *executes* base hook guards
  ---> *receives*  \((p, i ,\delta_{\text{trans}}, \alpha_{\text{trans}})\) from `hook_data`
 
  ---> *stores* the tick and sqrt price optimistically on pool storage
  ---> `MevTaxModelOneInputParamsLib` to *calculate* and *emit* \(\epsilon, \nu_{\text{trans}}\)
  ---> `DynamicFeeHook` *updates* and *emits* -> \((\sigma^2 (i(t)) , \phi_X (\sigma^2 (i(t)))\) 
  
**--(1)--> (state -> ouput)**
  ---> `MevTaxModelOneFees` *reads* and *emits*\(\phi_M\) 
  ---> `MevTaxModelOneTaxMod` *reads* and *emits* \(\tau_{\text{MEV}}\)
  ---> `MevTaxModelOneFees` *calculate*, *emits* and *store* \(\phi\)
  ---> `MevTaxModelOnePayoffReturnsMod` *calculates* \(\frac{\Delta r^{\text{LVR}}}{\Delta t}, \frac{\Delta r^{\phi}}{\Delta t}\); *accumulates* and *stores* \(r^{\text{LVR}}, r^{\phi}\)
  ---> `MevTaxModelOneOrderEndogOrderFlowProbabilitiesLib` *calculates* and *emits* \((\mathbb{P}_{\text{ARB}}, \mathbb{P}_{\text{TRANS}})\)
  
  --> `MevTaxModelOneUtilizationMod` *calculates* \(\frac{\Delta \nu_{\text{arb}}}{\Delta t}\) and *accumulates* and *emits* \(\nu_{\text{arb}}\)
  --> `MevTaxModelOneUtilizationMod` *calculates*, *emits and *stores* \(\nu\)
  


**--(1)--> (state -> ouput)**

  --> `ContractualVolPayoffTracker` *calculates* \(\frac{\Delta \pi^{\sigma}}{\Delta \sigma}\); *accumulates* and *stores* \(\pi^{\sigma}\)
  
  --> `RealizedPayoffMod`*calculates* \(i (\sigma^2 (i (t))) \to k_{\sigma} (\sigma^2 (i (t)))\), *mints/burns* \(L (i_k)\) to match contractual vol payoff
  
  --> `RealizedPayoffMod` *calculates*, *emits* and *stores* \(\hat \pi^{\sigma}\)

