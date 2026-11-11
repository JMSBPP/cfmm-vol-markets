node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracle.sol:      
last.volatilityCumulative 
+= uint88(_volatilityOnRange(int256(uint256(delta)), tick, tick, last.averageTick, averageTick));
// always fits 88 bits
node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracle.sol:  function _volatilityOnRange(
node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracle.sol:
uint88(
_volatilityOnRange(
int256(uint256(target - timestampBefore)), tick, tick, beforeOrAt.averageTick, avgTick)));
node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/test/VolatilityOracleTest.sol:    
return VolatilityOracle._volatilityOnRange(int256(uint256(dt)), tick0, tick1, avgTick0, avgTick1);

# TYPE

\[
	\begin{aligned}
		\sigma_{\texttt{rv}} = \frac{1}{W} \, \sum_{j=1}^{W}\, \Big (i_j - i_{\mu} \, (j) \Big)^{2}
	\end{aligned}
\]

Define a tick constrcutor DeltaTick(ts): tick1(ts) x tick2(ts)  -> Tick(ts)

And then we have an untyped Tick^{2} type which from now we simply encode as int48

Then this number enters the TickAcc which needs to be renamed to a more general purpose accumualtor since now is not accumulattic ticks but whatever tick^{2} type is given name to




# DEFINE 

# REFINE

