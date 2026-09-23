[MAIN](.spec/REALIZED_VOLATILITY.md)

\[
\begin{aligned}
	\mathrm{Window} = 24\times 60 \times 60
\end{aligned}
\]


[REF::`uint32 internal constant WINDOW = 1 days;`](node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts/libraries/VolatilityOracle.sol)

```
uint32 internal constant WINDOW = 1 days;
├ Hex: 0x15180
├ Hex (full word): 0x0000000000000000000000000000000000000000000000000000000000015180
└ Decimal: 86400
```

\[
	\begin{aligned}
		(\mathrm{Window})^{-1}
	\end{aligned}
\]


\[
\begin{aligned}
	\mathrm{Window} = 24\times 60 \times 60
\end{aligned}
\]

\[
	\begin{aligned}
		\textrm{Window} = \sum_{i=0}^{N} \bar t_i \\
		\\
		N =\frac{\text{Window}}{\bar dt}
	\end{aligned}
\]


\[
	\begin{aligned}
		\textrm{TimeSpacing }\leftarrow \bar{dt} := \{dt \in \mathrm{u8} \mid 1 \leq dt \, \leq 10\}
	\end{aligned}
\]

\[
	\begin{aligned}
		\textrm{TimeWidth} \leftarrow n_t\,:= \{n_t \in \mathrm{u24}\mid 1\leq n_t \leq \lfloor \, \rfloor\} \\
		\\
		\text{TimeCoordinate}\, \leftarrow t (t_0 \in \textrm{u32}, \bar{dt}, n_t) := \{t \mid t = t_0 + n_t \, \bar{dt}\} \, 
	\end{aligned}
\]

\[
	\begin{aligned}
		\textrm{TimeSequence} \leftarrow T(\bar{dt}) := \{\{t_j\}_{j=0}^{N = \frac{\mathrm{Window}}{\bar{dt}}} \,  \mid \, \textrm{Window} = \sum_{i=0}^{N} \bar t_i\}
	\end{aligned}
\]

\[
    \begin{aligned}
		\mathrm{TimeIndex} \leftarrow t(\bar{dt}) := \{t \in \mathrm{u32} \mid t \in T(\bar{dt})\} \\
		\mathrm{next}:: \, t (t_0,\bar{dt}, 1) \to t(\bar{dt})
 	\end{aligned}
\]

\[
	\begin{aligned}
		\mathrm{TimePeriod}\, \leftarrow \, t_p(\bar{dt})
	\end{aligned}
\]


\[
	\begin{aligned}
		t(\bar{dt})[t_0,t_p] = t_0 - t_p(\bar{dt})
	\end{aligned}
\]



# How is it used on REF ?

TimePoint \((t) = \{ \sigma (t), i(t), i_{\mu} (t) \cdots\}\)

TimeContainer = TimePoint[UINT16_MODULO]

The library defines an index `windowStartIndex`

```
uint16 windowStartIndex; // closest timepoint lte WINDOW seconds ago (or oldest timepoint), _should be used only from last timepoint_!
```

> This implies that WINDOW role is being a upper bound

- `windowStartIndex` 

Provides means to interact with:
                                                                  Number of seconds in the past to start calculating time-weighted average
///   getTwapTick(uint32,int24,uint32)            → 0x1a72d0df  (period, tick, time)
///   initializeTWAP(uint32,int24)                → 0xed64c40a  (timestamp, tick)
///   writeTimepoint(uint32,int24)                → 0xb09b2297  (timestamp, tick) 
///   canGetTwap(uint32,uint32)                   → 0x4a513c98  (period, timestamp)
e///   getSingleTimepoint(uint32,uint32,int24)     → 0xf1a0ebe5  (secondsAgo, timestamp, tick)
///   getTimepoints(uint32[],uint32,int24)        → 0x36ab33e3  (secondsAgo[],timestamp,tick)
///   getAverageVolatilityLast(uint32,int24)      → 0x59dc9384  (timestamp, lastIndex, oldestIndex,tick)


  function getTwapTick(uint32 period, int24 currentTick, uint32 currentTime) external view returns (int24 timeWeightedAverageTick) {
    require(period != 0, 'Period is zero');
	
VolatilityOracle.Timepoint memory current = layout.timepoints.getSingleTimepoint(currentTime, 0, currentTick, lastIndex, oldestIndex);

VolatilityOracle.Timepoint memory old = layout.timepoints.getSingleTimepoint(currentTime, period, currentTick, lastIndex, oldestIndex) {
	uint32 target = time - secondsAgo;

}
