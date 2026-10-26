

# PANOPTIC


## ORACLE PACK

- What is it ?

- A data container of 8 price observations and a time reference

//  From the LSB to the MSB:
// (0) residual0        12bits  : The last recorded residual.
// (1) residual1        12bits  : The second last recorded residual.
// (2) residual2        12bits  : The third last recorded residual.
// (3) residual3        12bits  : The forth last residual.
// (4) residual4        12bits  : The fifth last residual.
// (5) residual5        12bits  : The sixth last residual.
// (6) residual6        12bits  : The seventh last residual.
// (7) residual7        12bits  : The eight last residual.
// (8) referenceTick    22bits  : The reference tick used to reconstruce the obsercations as: last recorded tick = referenceTick + r0
// (9) lockMode         2 bits  : The externally controllable safe mode override
// (10) eonsEMA         22bits  : The value of the exponential moving average (EMA) tick determined using the longest timescale
// (11) slowEMA         22bits  : The value of the EMA tick determined using the second longest timescale
// (12) fastEMA         22bits  : The value of EMA tick determined using the shortest timescale
// (13) spotEMA         22bits  : The value of spot tick determined using the near instant timescale
// (14) orderMap        24bits  : A map of the ordered residuals (see details below)
// (15) epoch/timestamp           24bits  : The latest epoch as recorded using a 64s epoch-based timekeeping
// Total                256bits : Total bits used by a OraclePack.



Who uses it ?
RiskEngine {
	int256 constant EMA_PERIOD_SPOT = 60; // 1 minutes
	int256 constant EMA_PERIOD_FAST = 120; // 2 minutes
	int256 constant EMA_PERIOD_SLOW = 240; // 4 minutes
	int256 constant EMA_PERIOD_EONS = 960; // 16 minutes
	uint96 public constant EMA_PERIODS = uint96(60 + (120 << 24) + (240 << 48) + (960 << 72));
	/// @notice Packed EMA periods for spot, fast, and slow EMAs.
    function EMA_PERIODS() external view returns (uint96);
    /// @notice The maximum allowed cumulative delta between oracle ticks.
    function MAX_TICKS_DELTA() external view returns (int256);
	/// @notice The maximum amount of change, in ticks, permitted between internal median updates.
    function MAX_CLAMP_DELTA() external view returns (int24);
	function getOracleTicks(int24 currentTick, OraclePack _oraclePack)
        external
        view
        returns (int24 spotTick, int24 medianTick, int24 latestTick, OraclePack oraclePack);
	function twapEMA(OraclePack oraclePack) external pure returns (int24);
    function computeInternalMedian(OraclePack oraclePack,int24 currentTick)
		external
		view
		returns (int24 medianTick, OraclePack updatedOraclePack);
	
}

PanopticPool {
	OraclePack internal s_oraclePack;
	function initialize() {
		int24 currentTick = getCurrentTick();
        uint96 EMAs = OraclePackLibrary.packEMAs(
            currentTick,
            currentTick,
            currentTick,
            currentTick
        );
		s_oraclePack = OraclePackLibrary.storeOraclePack(
            block.timestamp >> 6, // LAST UPDATED BLOCK TIMESTAMP (22 bits) -> 22 bits (use 28 bits for the timestamp and truncate the lower 6 bits to create a 64s epoch-based timekeeping)
            0xf590a6, // orderMap ??
            EMAs,
            currentTick,
            0xe00200e00200e00200e00000, // current residuals ??
            0, ??
            0 ??
        );
	}
	/*
            (uint256((block.timestamp >> 6) % 2 ** 24) << 232) +
            // magic number which adds (7,5,3,1,0,2,4,6) order and minTick in positions 7, 5, 3 and maxTick in 6, 4, 2
            // see comment on s_oraclePack initialization for format of this magic number
            (uint256(0xf590a60000000000000000000000000000800e00200e00200e00000000)) +
            // eonsEMA at bits 207-186
<            (uint256(uint24(currentTick) & 0x3FFFFF) << 186) +
            // slowEMA at bits 185-164
            (uint256(uint24(currentTick) & 0x3FFFFF) << 164) +
            // fastEMA at bits 163-142
            (uint256(uint24(currentTick) & 0x3FFFFF) << 142) +
            // spotEMA at bits 141-120
            (uint256(uint24(currentTick) & 0x3FFFFF) << 120) +
            // store currentTick as the reference tick at bits 119-96
            (uint256(uint24(currentTick)) << 96);
    */
	function pokeOracle() {
	    int24 currentTick = getCurrentTick();
        (, OraclePack oraclePack) = riskEngine().computeInternalMedian(s_oraclePack, currentTick);
		if (OraclePack.unwrap(oraclePack) != 0) s_oraclePack = oraclePack;
	}
	
}



function computeInternalMedian(
	OraclePack oraclePack,
	int24 currentTick
	) external view returns (int24 medianTick, OraclePack updatedOraclePack) {
	     _medianTick = getMedianTick(oraclePack);
		 getMedianTick (oraclePack) {
			 oraclePack.referenceTick() + 
				 (oraclePack.residualTickOrdered(3) + oraclePack.residualTickOrdered(4))/2 
		 }
	
	}
	

> What is the referenceTick ?

- **reference tick:** used to reconstruce the observations as: last recorded tick = referenceTick + r0
 -->  int22toInt24((OraclePack.unwrap(self) >> 96) & BITMASK_UINT22);

\[
	\begin{aligned}
		t_{\texttt{64}} &:: t \mapsto t^{\star}   \\
		t_{\texttt{64}} (t) \, &= \, (t >> 6) \, \& \, \texttt{0xFFFFFF} \\
		\\
		\Delta \, t_{\texttt{64}} &:: t_{\texttt{64}} \times t_{\texttt{64}} \mapsto \Delta \, t_{\texttt{64}}  \\
		\\
		\Delta \, t_{\texttt{64}} (t_{\texttt{64},1},t_{\texttt{64},2}) &=  \Big (t_{\texttt{64},2} - t_{\texttt{64},1} \Big ) \cdot \, 64
	\end{aligned}
\]



int256 constant EMA_PERIOD_SPOT = 60; // 1 minutes
int256 constant EMA_PERIOD_FAST = 120; // 2 minutes
int256 constant EMA_PERIOD_SLOW = 240; // 4 minutes
int256 constant EMA_PERIOD_EONS = 960; // 16 minutes
uint96 public constant EMA_PERIODS = uint96(60 + (120 << 24) + (240 << 48) + (960 << 72));



int24 _eonsEMA = int22toInt24((_EMAs >> 66) & BITMASK_UINT22);
if (timeDelta > (3 * EMA_PERIOD_EONS) / 4) timeDelta = (3 * EMA_PERIOD_EONS) / 4;
_eonsEMA = int24(_eonsEMA + (timeDelta * (newTick - _eonsEMA)) / EMA_PERIOD_EONS);


\[
	\begin{aligned}
		\texttt{BT_U22} :: \texttt{0x3FFFFF}
	\end{aligned}
\]


\[
	\begin{aligned}
		\texttt{TM} := \text{TickMoments} \\ 
		\mathrm{U} :: * \mapsto \texttt{u256} \\
		
		\texttt{TM_ACTION} :: \texttt{REBASE} \mid \texttt{LOCATE} \\
		\texttt{TM} :: i_{\texttt{ref}}  \mid \cdots \\
		\texttt{TM}_{\texttt{next}} :: \texttt{TM} \, \times X \mapsto  \texttt{TM}
	\end{aligned}
\]


\[
	\begin{aligned}
		i_{\text{ref}} \, ::\,  \texttt{TM} \times \texttt{TM_ACTION} \mapsto i \\
		\\
		i_{\text{ref}} \, (\texttt{TM} , \texttt{LOCATE}) = \Big (\Big (\mathrm{U} \, (\texttt{TM}) >> 96\Big) \, \& \, \texttt{BT_uint22} \Big ) \, \& \, \texttt{BT_uint24}
	\end{aligned}
\]


    ///                   - Bits 95-12:   Previous observations as 12-bit residuals (84 bits)

> Adding order_map

\[
	\begin{aligned}
		\texttt{TM} :: i_{\text{ref}} \mid \texttt{OM} \mid \cdots \\
	\end{aligned}
\]

\[
	\begin{aligned}
		\texttt{OM} \, &:: \,  \texttt{TM} \times \texttt{TM_ACTION} \mapsto \texttt{OM} \\
		\\
		\texttt{OM} \, (\texttt{TM} , \texttt{LOCATE}) = \Big (\mathrm{U} \, (\texttt{TM}) >> 208 \Big) \, \& \, \texttt{BT_uint24}
	\end{aligned}
\]

\[
	\begin{aligned}
		\texttt{OM_idx}:: \texttt{TM} \, \times \, \texttt{pos_idx} \mapsto \texttt{idx} \\
		\texttt{OM_idx} (\texttt{TM}, \texttt{pos_idx}) = \Big (\texttt{OM} \, (\texttt{TM} , \texttt{LOCATE}) >> (\texttt{pos_Idx}\, \cdot \, 3) \Big ) \, \& \, 7
	\end{aligned}
\]

> why 3, why 7 why the operations ?

\[
	\begin{aligned}
		i_{\texttt{res}} \, :: \texttt{TM} \, \times \texttt{pos_idx} \mapsto i \\
		i_{\texttt{res}} \, (\texttt{TM} \, , \, \texttt{pos_idx}) = (\mathrm{U} \, (\mathrm{TM})\, >> \,(\texttt{pos_idx} \cdot 12) )\, \& \, \texttt{0x0FFF}
	\end{aligned} 
\]


            int24 _eonsEMA = int22toInt24((_EMAs >> 66) & BITMASK_UINT22);
            if (timeDelta > (3 * EMA_PERIOD_EONS) / 4) timeDelta = (3 * EMA_PERIOD_EONS) / 4;
            _eonsEMA = int24(_eonsEMA + (timeDelta * (newTick - _eonsEMA)) / EMA_PERIOD_EONS);



order map. 

Let:
\[
	\begin{aligned}
	    X := (i, t_{\texttt{64}} , \Delta t_{\texttt{64}} )
	\end{aligned}
\]




    function insertObservation(
        OraclePack oraclePack,
        int24 newTick,
        uint256 currentEpoch,
        int256 timeDelta,
        uint96 EMAperiods
    ) internal pure returns (OraclePack newOraclePack) {
        unchecked {
            int24 _referenceTick = oraclePack.referenceTick();
            int24 lastResidual = newTick - _referenceTick;

            // update oracle pack and reference tick if the move is beyond residual threshold
            if (
                (lastResidual > Constants.MAX_RESIDUAL_THRESHOLD) ||
                (lastResidual < -Constants.MAX_RESIDUAL_THRESHOLD)
            ) {
                (_referenceTick, oraclePack) = rebaseOraclePack(oraclePack);
                lastResidual = newTick - _referenceTick;
            }

            uint24 _newOrderMap;
            {
                uint24 _orderMap = oraclePack.orderMap();
                uint256 _oraclePack = OraclePack.unwrap(oraclePack);
                uint24 shift = 1;
                bool below = true;
                uint24 rank;
                int24 entry;
                for (uint8 i; i < 8; ++i) {
                    // read the rank from the existing ordering
                    rank = (_orderMap >> (3 * i)) & 7; // mod 2**3

                    if (rank == 7) {
                        shift -= 1;
                        continue;
                    }

                    // read the corresponding entry
                    entry = int12toInt24((_oraclePack >> (rank * 12)) & 0x0FFF); // mod 2**12
                    if ((below) && (lastResidual > entry)) {
                        shift += 1;
                        below = false;
                    }

                    _newOrderMap = _newOrderMap + ((rank + 1) << (3 * (i + shift - 1)));


\[
	\begin{aligned}
		
	\end{aligned}
\]

> What is the residualTickOrdered, 3,4 and other positions?




    function updateEMAs(
        OraclePack oraclePack,
        int256 timeDelta,
        int24 newTick,
        uint96 EMAperiods
    ) internal pure returns (uint256 updatedEMAs) {
        unchecked {
            int256 EMA_PERIOD_SPOT = int24(uint24(EMAperiods));
            int256 EMA_PERIOD_FAST = int24(uint24(EMAperiods >> 24));
            int256 EMA_PERIOD_SLOW = int24(uint24(EMAperiods >> 48));
            int256 EMA_PERIOD_EONS = int24(uint24(EMAperiods >> 72));

            // Extract current EMAs from oraclePack (88 bits starting at bit 120)
            uint256 _EMAs = oraclePack.EMAs();

            // Update eons EMA (bits 87-66)
            int24 _eonsEMA = int22toInt24((_EMAs >> 66) & BITMASK_UINT22);
            if (timeDelta > (3 * EMA_PERIOD_EONS) / 4) timeDelta = (3 * EMA_PERIOD_EONS) / 4;
            _eonsEMA = int24(_eonsEMA + (timeDelta * (newTick - _eonsEMA)) / EMA_PERIOD_EONS);

            // Update slow EMA (bits 65-44)
            int24 _slowEMA = int22toInt24((_EMAs >> 44) & BITMASK_UINT22);
            if (timeDelta > (3 * EMA_PERIOD_SLOW) / 4) timeDelta = (3 * EMA_PERIOD_SLOW) / 4;
            _slowEMA = int24(_slowEMA + (timeDelta * (newTick - _slowEMA)) / EMA_PERIOD_SLOW);

            // Update fast EMA (bits 43-22)
            int24 _fastEMA = int22toInt24((_EMAs >> 22) & BITMASK_UINT22);
            if (timeDelta > (3 * EMA_PERIOD_FAST) / 4) timeDelta = (3 * EMA_PERIOD_FAST) / 4;
            _fastEMA = int24(_fastEMA + (timeDelta * (newTick - _fastEMA)) / EMA_PERIOD_FAST);

            // Update spot EMA (bits 21-0)
            int24 _spotEMA = int22toInt24(_EMAs & BITMASK_UINT22);
            if (timeDelta > (3 * EMA_PERIOD_SPOT) / 4) timeDelta = (3 * EMA_PERIOD_SPOT) / 4;
            _spotEMA = int24(_spotEMA + (timeDelta * (newTick - _spotEMA)) / EMA_PERIOD_SPOT);

            // Pack updated EMAs back into 88-bit format
            updatedEMAs = packEMAs(_spotEMA, _fastEMA, _slowEMA, _eonsEMA);
        }
    }

### ORDER_MAP

// ORDERING of tick indices least --> greatest (24 bits)
// The value of the bit codon ([#]) is a pointer to a tick index in the tick array.
// The position of the bit codon from most to least significant is the ordering of the
// tick index it points to from least to greatest.
//
// rank:  0   1   2   3   4   5   6   7
// slot: [7] [5] [3] [1] [0] [2] [4] [6]
//       111 101 011 001 000 010 100 110




# ALGEBRA

\[
	\begin{aligned}
		\texttt{TimepointState} = \texttt{NotInitialized} \mid \texttt{Initialized}\\
		\\
		\texttt{Timepoint} = \Big (\texttt{TimepointState},t^{\star}, i^{\Sigma} \, (t^{\star}) =  \int_{t_0}^{t^{\star}} \, i(t) \, \mathcal{d} \, t , i (t^{\star}),i_{\mu} (t^{\star}), j-1 \, \Big) \\
		\\
		\{0, \cdots , j-1, j, \cdots , M\} \mapsto \texttt{Timepoint} [M]
	\end{aligned}
\]


The start ONLY writes time, tick and tickAccumulated the rest are still zero. This is ONLY when the state is not initialized and then moves it to initialized


\[
	\begin{aligned}
		(j-1, t^{\star} , i (t^{\star})) \to (j, j_0) \\
		\\
		( \texttt{Timepoint} [M] ,   t^{\star} , i (t^{\star}) , j-1, t^{\star} - \Delta t , i^{\Sigma} \, (t^{\star})) \to (i_{\mu} (t^{\star}), ...) \\
		\\
		\Delta t \leftarrow t^{\star} - (t^{\star} - \Delta t)\\
		\\
	   i^{\Sigma} \, (t^{\star}) \leftarrow  i^{\Sigma} \, (t^{\star} - \Delta \, t) \, + \,  i (t^{\star}) \, \Delta t
	\end{aligned}
\]



!_lteConsideringOverflow(oldestTimestamp, currentTime - WINDOW, currentTime)

\[
	\begin{aligned}
		(t^{\star} - \Delta \, t , t^{\star} - W, t^{\star})
	\end{aligned}
\]


- \( (t^{\star} - \Delta t > t^{\star})\, \wedge \, (t^{\star} - W \geq t^{\star}) \, \implies \, (t^{\star} - \Delta t \leq t^{\star})\)

- \(\neg \Big ( (t^{\star} - \Delta t > t^{\star})\, \wedge \, (t^{\star} - W \geq t^{\star}) \, \implies \, (t^{\star} - \Delta t \leq t^{\star})\Big)\)

                \(t^{\star} - W\)            \(t^{\star} - \Delta t\)                 \(t^{\star}\)
        _________*_____________________*______________________*_
                 ||||||||||||||||||||||||||||||||||||||||||||||


- \(\frac{i^{\Sigma} \, (t^{\star} - \Delta \, t) - i^{\Sigma} \, (t_0)}{W}\)


# UNISWAP V3
