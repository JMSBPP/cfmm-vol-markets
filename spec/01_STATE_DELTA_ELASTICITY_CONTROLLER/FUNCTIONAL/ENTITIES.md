

TickGrid{
	statePartitionDelta: [1,200] 
	bounds:Bound
	size() Number{
		abs(bound.low - bound.up)/statePartitionDelta
	}
}

TickGridMetrics<TickGrid>{
	ref: TickGrid
	variance(ref,centeredTick:Tick) Number
	
	INVARIANTS (Weights) {	
	\[
	\begin{aligned}
		\#_{\bar \Delta_i} \, \sigma_{\bar \Delta_i} \, (\Delta_i;\cdot) \, &\equiv \, \sum_{j=1}^{\#_{\bar \Delta_i}-1} \, \bar \eta_j  \, (i_{-} \, + j \, \bar \Delta_i  \, - i_{\mu})^2
	\end{aligned}
\];
	}
}

VarianceMarketLens { 
	currentTick:int
     varianceTracker: Accumulator<TickGrid,step : \(j: j\, \Delta_i\)>	 
}

VarianceExpSpec {varianceStrike: Number, notional: Number }

PayoffTracker<Portafolio, VarianceMarketLens>{
	exp: /( 1/(1-\eta) /)
	
	payoff() \(		\pi_\eta^{+}
			\, &= \, (p_{\eta}(i)\Delta^I)^{1/(1-\eta)} \, - \, (\Delta^O)^{1/(1-\eta)}
				\, - \, 1/(1-\eta) \, (\Delta^O)^{\eta/(1-\eta)} \, (p_{\eta}(i)\Delta^I - \Delta^O)\)_
}

Portafolio<Asset, Cash> {
	grossOutputAmt: Asset<Quantity>
	grossInputAmt: Cash<Quantity>
	netOuputAmt: Accumulator<TickGrid, step>
	netInputAmt: Accumulator<TickGrid, step>
	exchangeRate:ExchangeRate<Cash*:Numeraire,Asset*:Underlying>
	(exchangeRate -> Weights[2])
	
	add(grossOutputAmt,grossInputAmt) {
		grossOutputAmt + exchangeRate(grossOutputAmt.assetClass(), grossInputAmt.assetClass)*grossInputAmt
	}
	
    weight(AssetClass*) {
		AssetClass == Cash ? grossInputAmt.value(exchangeRate):  grossOutputAmt
		/ add(grossOutputAmt,grossInputAmt)
	}
	
}

Weights<TickGrid>{
    stateGrid: TickGrid
	normalizer(stateGrid) => Number
	
	normalizedWeight(ExchangeRate) => NumberBetween0AndOne[2] {}

	INVARIANTS{
		sum(normalizedWeight(ExchangeRate)) == 1 
	}
}

ExchangeRate<Cash*:Numeraire,Asset*:Underlying> {
	
}
