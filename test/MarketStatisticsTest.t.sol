// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {VolatilityOracle} from "@cryptoalgebra/volatility-oracle-plugin/libraries/VolatilityOracle.sol";
import {VolatilityOracleStorage} from "@cryptoalgebra/volatility-oracle-plugin/libraries/VolatilityOracleStorage.sol";
import {VolatilityOraclePluginImplementation} from "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";
import {LibCall} from "@solady/utils/LibCall.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Oracle} from "v3-core/libraries/Oracle.sol";
import {ExpMath} from "bunni-v2/src/lib/ExpMath.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";



contract MarketStatisticsUniV3Ref{
    uint128 constant ZERO_LIQUIDITY = uint128(0);
    uint16 constant UNIT_SAMPLE_SIZE = uint16(1);
    uint32 constant ZERO_DT = uint32(0);

    /// @dev Ring capacity to grow to at init.
    ///
    ///      This used to be `TOTAL_SAMPLE_SIZE = 65535`, passed straight to Oracle.write as
    ///      BOTH cardinality and cardinalityNext, while the value Oracle.write RETURNS was
    ///      discarded. That is not how the UniV3 oracle works: it claimed a full 65535-slot
    ///      ring while only a handful of slots were ever written, so observeSingle's binary
    ///      search walked uninitialized slots and reverted. It only ever "passed" because the
    ///      one test that would have caught it was reading the wrong contract (see the
    ///      uniV3EqTickNObs test).
    ///
    ///      A real pool grows the ring explicitly and threads cardinality through write().
    ///      We grow to 512, which comfortably covers the <=100 writes the suite performs;
    ///      growing to 65535 would cost ~65k SSTOREs and is not needed to exercise the
    ///      no-wrap regime the differential test targets.
    uint16 constant CARDINALITY_TARGET = uint16(512);

    struct MarketStatisticsUniV3RefStorage{
	    uint16 timepointIndex;
	    uint16 cardinality;
	    uint16 cardinalityNext;
	    uint32 lastTimepointTimestamp;
	    bool isInitialized;
	    Oracle.Observation[65535] timepoints;
    }
	
    // keccak256("marketStatisticsUniV3.storage")
    // `constant`: it is a fixed namespaced slot, and as a plain state variable it forced every
    // reader of getStorage() to be non-pure, which is what blocked the view getters below.
    bytes32 constant SLOT_MARKET_STATISTICS_UNIV3 = 0xd84d04cffcedae72d800d39925bfb5a8a7f96741edb2a98808d8d746a4827f7b;

    function getStorage() internal pure returns(MarketStatisticsUniV3RefStorage storage $){
	bytes32 s_index_base = SLOT_MARKET_STATISTICS_UNIV3;
	assembly {
	   $.slot := s_index_base
	}
    }
    
    /// @dev observeSingle must be handed the ACTUAL cardinality. It was previously given
    ///      UNIT_SAMPLE_SIZE (1), which claims a one-slot ring and makes every lookback
    ///      resolve against a single observation.
    function getTwapTick(uint32 dt, int24 tick, uint32 currentTimestamp) public view returns(int24 timeWeightedAverageTick){
	    require(dt != 0, 'Period is zero');
	    MarketStatisticsUniV3RefStorage storage $ = getStorage();
	    uint16 lastIndex = $.timepointIndex;
	    uint16 cardinality = $.cardinality;
	    (int56 old_tick_cumulative, ) = Oracle.observeSingle($.timepoints, currentTimestamp, dt, tick,lastIndex, ZERO_LIQUIDITY, cardinality);
	    (int56 current_tick_cumulative, ) = Oracle.observeSingle($.timepoints,currentTimestamp, ZERO_DT, tick,lastIndex, ZERO_LIQUIDITY,cardinality);
 	    int56 delta_tick_cumulative = current_tick_cumulative - old_tick_cumulative;
            timeWeightedAverageTick = int24(delta_tick_cumulative / int56(uint56(dt)));

	    // Floor toward -inf. Algebra's plugin applies the IDENTICAL correction
	    // (VolatilityOraclePluginImplementation.getTwapTick), so all three implementations --
	    // including Plank -- must agree here EXACTLY, for every dt. There is no
	    // "expected divergence" regime on this path.
            if (delta_tick_cumulative < 0 && (delta_tick_cumulative % int56(uint56(dt)) != 0)) {
		timeWeightedAverageTick--;
	    }
    }

    /// @dev Raw accumulator at `currentTimestamp - dt`, the most primitive quantity shared with
    ///      Algebra and Plank, and therefore the sharpest differential surface.
    function getTickCumulative(uint32 dt, int24 tick, uint32 currentTimestamp) public view returns(int56){
	MarketStatisticsUniV3RefStorage storage $ = getStorage();
	(int56 c, ) = Oracle.observeSingle(
	    $.timepoints, currentTimestamp, dt, tick, $.timepointIndex, ZERO_LIQUIDITY, $.cardinality
	);
	return c;
    }

    function initializeTWAP(uint32 blockTimestamp, int24 tick) public{
	MarketStatisticsUniV3RefStorage storage $ = getStorage();
        ($.cardinality, $.cardinalityNext) = Oracle.initialize($.timepoints, blockTimestamp);
	// Grow the ring, exactly as a pool does. Without this, cardinality stays 1 and every
	// subsequent write overwrites slot 0.
	$.cardinalityNext = Oracle.grow($.timepoints, $.cardinality, CARDINALITY_TARGET);
	$.timepointIndex = 0;
	$.lastTimepointTimestamp = blockTimestamp;
	$.isInitialized = true;
    }

    function writeTimepoint(uint32 timestamp, int24 tick) public {
	MarketStatisticsUniV3RefStorage storage $ = getStorage();
	// Thread cardinality through: Oracle.write RETURNS the updated cardinality (it grows as
	// the ring fills). The previous code discarded it and hardcoded 65535 for both args.
        ($.timepointIndex, $.cardinality) = Oracle.write(
					    $.timepoints,
					    $.timepointIndex,
					    timestamp,
					    tick,
					    ZERO_LIQUIDITY,
					    $.cardinality,
					    $.cardinalityNext
	);

	$.lastTimepointTimestamp = timestamp;
    }

    /// @notice Raw observation at `index`, for differential assertions.
    /// @dev Only (blockTimestamp, tickCumulative, initialized) are comparable against Algebra
    ///      and Plank; UniV3's Observation carries secondsPerLiquidityCumulativeX128 instead of
    ///      Algebra's volatility/tick/averageTick/windowStartIndex fields.
    /// @dev NOTE the ring sizes DIFFER: this ref passes TOTAL_SAMPLE_SIZE = 65535 as cardinality
    ///      to Oracle.write, so UniV3 indexes mod 65535, while Algebra and Plank use
    ///      UINT16_MODULO = 65536. The three necessarily diverge at wrap. Unreachable in fuzz,
    ///      but it is a real semantic difference, not a port bug.
    function getTimepoint(uint16 index)
	public
	view
	returns (uint32 blockTimestamp, int56 tickCumulative, bool initialized)
    {
	MarketStatisticsUniV3RefStorage storage $ = getStorage();
	Oracle.Observation memory o = $.timepoints[index];
	return (o.blockTimestamp, o.tickCumulative, o.initialized);
    }

    function lastIndex() public view returns (uint16) {
	return getStorage().timepointIndex;
    }
}

contract MarketStatisticsAlgebraRef {
    
    VolatilityOraclePluginImplementation volClient;
    constructor (VolatilityOraclePluginImplementation _volClient) {
	volClient = _volClient;
    }
    
    function initializeTWAP(uint32 blockTimestamp, int24 tick) public {
	LibCall.delegateCallContract(address(volClient), abi.encodeWithSelector(0xed64c40a, blockTimestamp, tick));
    }

    function getTwapTick(uint32 dt, int24 tick, uint32 currentTimestamp) public returns(int24 timeWeightedAverageTick) {
	
	timeWeightedAverageTick = abi.decode(LibCall.delegateCallContract(address(volClient), abi.encodeWithSelector(0x1a72d0df, dt,tick,currentTimestamp)), (int24));
    }

    function writeTimepoint(uint32 timestamp, int24 tick) public {
	LibCall.delegateCallContract(address(volClient), abi.encodeWithSignature("writeTimepoint(uint32,int24)", timestamp, tick));
    }

    function getAverageVolatilityLast(int24 tick, uint32 blockTimestamp) public view returns(uint88){
	VolatilityOracleStorage.Layout storage layout = VolatilityOracleStorage.layout();
	 uint16 lastIndex = layout.timepointIndex;
	 uint16 oldestIndex = VolatilityOracle.getOldestIndex(layout.timepoints,lastIndex);
	 return VolatilityOracle.getAverageVolatility(layout.timepoints, blockTimestamp, tick ,lastIndex, oldestIndex);
    }

    /// @notice Full timepoint at `index`, for differential assertions.
    /// @dev The scalar getTwapTick is a QUOTIENT: two compensating internal errors (say a
    ///      truncated accumulator against a wrong oldest-index) cancel and a TWAP-only
    ///      assertion passes. Diffing the stored timepoint field-by-field is what actually
    ///      pins the implementation down.
    function getTimepoint(uint16 index)
	public
	view
	returns (
	    bool initialized,
	    uint32 blockTimestamp,
	    int56 tickCumulative,
	    uint88 volatilityCumulative,
	    int24 tick,
	    int24 averageTick,
	    uint16 windowStartIndex
	)
    {
	VolatilityOracle.Timepoint storage t = VolatilityOracleStorage.layout().timepoints[index];
	return (
	    t.initialized,
	    t.blockTimestamp,
	    t.tickCumulative,
	    t.volatilityCumulative,
	    t.tick,
	    t.averageTick,
	    t.windowStartIndex
	);
    }

    function lastIndex() public view returns (uint16) {
	return VolatilityOracleStorage.layout().timepointIndex;
    }

    function oldestIndex() public view returns (uint16) {
	VolatilityOracleStorage.Layout storage layout = VolatilityOracleStorage.layout();
	return VolatilityOracle.getOldestIndex(layout.timepoints, layout.timepointIndex);
    }
}

contract MarketStatisticsTest is Test {


    struct TickHistory {int24[] ticks;}

    TickHistory path;
    uint32 constant DEFAULT_DELTA_SECONDS = 30 seconds;

    MarketStatisticsAlgebraRef marketStatisticsAlgebraRef;
    MarketStatisticsUniV3Ref marketStatisticsUniV3Ref;

    bool forked;
    uint256 forkId;
    
    /// @dev No fork. The previous setUp did:
    ///        try vm.rpcUrl("local") returns (string memory url) {
    ///            forkId = vm.createSelectFork(url); ...
    ///        } catch { ...deploy locally... }
    ///      `local` IS defined in foundry.toml, so vm.rpcUrl SUCCEEDS and the try-block runs
    ///      `vm.createSelectFork` -- whose cheatcode failure the `catch` cannot catch. The whole
    ///      suite therefore reverted in setUp() unless an anvil happened to be listening on
    ///      127.0.0.1:8545. None of these tests read fork state: both refs are freshly deployed
    ///      and driven purely by vm.warp. The fork was gratuitous, so it is gone.
    function  setUp() public {
	marketStatisticsAlgebraRef = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
	marketStatisticsUniV3Ref = new MarketStatisticsUniV3Ref();
    }

    function test__fuzz__algebraOneObsTickAvgEqObs(int24 tickInit, uint32 _init_timeStamp) public {
	uint32 init_timeStamp = uint32(bound(uint256(_init_timeStamp), 0 ,type(uint32).max / 2));
	path.ticks = new int24[](1);
	path.ticks[0] = tickInit;
	vm.warp(init_timeStamp);
	marketStatisticsAlgebraRef.initializeTWAP(uint32(vm.getBlockTimestamp()), path.ticks[0]);
	vm.warp(init_timeStamp + DEFAULT_DELTA_SECONDS);
	int24 meanTick = marketStatisticsAlgebraRef.getTwapTick(DEFAULT_DELTA_SECONDS, tickInit, uint32(vm.getBlockTimestamp()));
	assertEq(meanTick,tickInit);
    }

    // todo: This needs refactoring to use the seaport pattern to avoid code duplication
    function test__fuzz__uniV3OneObsTickAvgEqObs(int24 tickInit, uint32 _init_timeStamp) public {
        uint32 init_timeStamp = uint32(bound(uint256(_init_timeStamp), 0 ,type(uint32).max / 2));
	path.ticks = new int24[](1);
	path.ticks[0] = tickInit;
	vm.warp(init_timeStamp);
	marketStatisticsUniV3Ref.initializeTWAP(uint32(vm.getBlockTimestamp()), path.ticks[0]);
	vm.warp(init_timeStamp + DEFAULT_DELTA_SECONDS);
	int24 meanTick = marketStatisticsUniV3Ref.getTwapTick(DEFAULT_DELTA_SECONDS, tickInit, uint32(vm.getBlockTimestamp()));
	assertEq(meanTick,tickInit);
    }

    function test__fuzz__algebraEqTickNObsReturnsTickAsAvg(uint32 _init_timestamp,
							   uint16 numberOfTicksToWrite, int24 tick, uint32 _deltaT) public {
	numberOfTicksToWrite = uint16(bound(numberOfTicksToWrite, 2, 100));
        uint32 init_timestamp = uint32(bound(uint256(_init_timestamp), 0 ,type(uint32).max / 2));
	uint32 deltaT = uint32(bound(uint256(_deltaT), 0, uint256(init_timestamp)));
	path.ticks = new int24[](numberOfTicksToWrite);
	uint256 index = 0;

	unchecked {
	    do {
		vm.warp(init_timestamp + index*DEFAULT_DELTA_SECONDS);
		if (index == 0) { marketStatisticsAlgebraRef.initializeTWAP(uint32(vm.getBlockTimestamp()),tick);}
	        marketStatisticsAlgebraRef.writeTimepoint(uint32(vm.getBlockTimestamp()),tick);		  
	        index++;
	    } while (index < numberOfTicksToWrite);}

	uint32 total_delta_t = uint32(bound(deltaT, uint256(DEFAULT_DELTA_SECONDS), uint256(uint32(vm.getBlockTimestamp()) - init_timestamp)));
	int24 tickMean = marketStatisticsAlgebraRef.getTwapTick(total_delta_t, tick, uint32(vm.getBlockTimestamp()));
	assertEq(tickMean, tick);

    }

    function test__fuzz__uniV3EqTickNObsReturnsTickAsAvg(uint32 _init_timestamp,
							 uint16 numberOfTicksToWrite, int24 tick, uint32 _deltaT) public {
	numberOfTicksToWrite = uint16(bound(numberOfTicksToWrite, 2, 100));
        uint32 init_timestamp = uint32(bound(uint256(_init_timestamp), 0 ,type(uint32).max / 2));
	uint32 deltaT = uint32(bound(uint256(_deltaT), 0, uint256(init_timestamp)));
	path.ticks = new int24[](numberOfTicksToWrite);
	uint256 index = 0;

	unchecked {
	    do {
		vm.warp(init_timestamp + index*DEFAULT_DELTA_SECONDS);
		if (index == 0) { marketStatisticsUniV3Ref.initializeTWAP(uint32(vm.getBlockTimestamp()),tick);}
	        marketStatisticsUniV3Ref.writeTimepoint(uint32(vm.getBlockTimestamp()),tick);		  
	        index++;
	    } while (index < numberOfTicksToWrite);}

	uint32 total_delta_t = uint32(bound(deltaT, uint256(DEFAULT_DELTA_SECONDS), uint256(uint32(vm.getBlockTimestamp()) - init_timestamp)));
	// FIXED: this read `marketStatisticsAlgebraRef` while writing to the UniV3 ref above --
	// and the Algebra oracle is never initialized in this test, so it was asserting against
	// zeroed storage that happens to divide out to `tick` on a constant path. The test passed
	// even though it exercised nothing; it would have passed with writeTimepoint as a no-op.
	int24 tickMean = marketStatisticsUniV3Ref.getTwapTick(total_delta_t, tick, uint32(vm.getBlockTimestamp()));
	assertEq(tickMean, tick);


    }


     function test__fuzz__algebraNMinusOneEqTicksAndOutlierTickSuccess(uint32 _init_timestamp,
								      uint16 numberOfTicksToWrite, int24 tick, int24 tickOutlier,uint32 _deltaT) public {
	numberOfTicksToWrite = uint16(bound(numberOfTicksToWrite, 2, 100));
        uint32 init_timestamp = uint32(bound(uint256(_init_timestamp), 0 ,type(uint32).max / 2));
        uint256 index = 0;
	vm.assume(tickOutlier != tick);
	unchecked {
	    do {
		vm.warp(init_timestamp + index*DEFAULT_DELTA_SECONDS);
		if (index == 0) { marketStatisticsAlgebraRef.initializeTWAP(uint32(vm.getBlockTimestamp()),tick);}
	        marketStatisticsAlgebraRef.writeTimepoint(uint32(vm.getBlockTimestamp()),tick);		  
	        index++;
	    } while (index < numberOfTicksToWrite);
	}
        vm.warp(uint32(vm.getBlockTimestamp()) + DEFAULT_DELTA_SECONDS);

	uint32 total_delta_t = uint32(vm.getBlockTimestamp()) - init_timestamp;
	int24 tickMean = marketStatisticsAlgebraRef.getTwapTick(total_delta_t, tickOutlier , uint32(vm.getBlockTimestamp()));

	int256 expectedMean =
    (
        int256(tick) * int256(uint256(total_delta_t - DEFAULT_DELTA_SECONDS))
        + int256(tickOutlier) * int256(uint256(DEFAULT_DELTA_SECONDS))
    ) / int256(uint256(total_delta_t));

        assertApproxEqAbs(
			  int256(tickMean),
			  expectedMean,
			  1
	);
        
    }

    function test__fuzz__uniV3NMinusOneEqTicksAndOutlierTickSuccess(
								    uint32 _init_timestamp,
								    uint16 numberOfTicksToWrite,
								    int24 tick,
								    int24 tickOutlier,
								    uint32 _deltaT
    ) public {
	numberOfTicksToWrite = uint16(bound(numberOfTicksToWrite, 2, 100));
        uint32 init_timestamp = uint32(bound(uint256(_init_timestamp), 0 ,type(uint32).max / 2));
        uint256 index = 0;
	vm.assume(tickOutlier != tick);
	unchecked {
	    do {
		vm.warp(init_timestamp + index*DEFAULT_DELTA_SECONDS);
		if (index == 0) { marketStatisticsUniV3Ref.initializeTWAP(uint32(vm.getBlockTimestamp()),tick);}
	        marketStatisticsUniV3Ref.writeTimepoint(uint32(vm.getBlockTimestamp()),tick);		  
	        index++;
	    } while (index < numberOfTicksToWrite);
	}
        vm.warp(uint32(vm.getBlockTimestamp()) + DEFAULT_DELTA_SECONDS);

	uint32 total_delta_t = uint32(vm.getBlockTimestamp()) - init_timestamp;
	int24 tickMean = marketStatisticsUniV3Ref.getTwapTick(total_delta_t, tickOutlier , uint32(vm.getBlockTimestamp()));

	int256 expectedMean =
    (
        int256(tick) * int256(uint256(total_delta_t - DEFAULT_DELTA_SECONDS))
        + int256(tickOutlier) * int256(uint256(DEFAULT_DELTA_SECONDS))
    ) / int256(uint256(total_delta_t));

        assertApproxEqAbs(
			  int256(tickMean),
			  expectedMean,
			  1
	);
    
    }

    function test__unit__algebraGenVolTermStructure() public {
	uint16 numberOfTicksToWrite = uint16(100);
        uint32 init_timestamp = uint32(20_000_000);
	uint256 index = 0;
	path.ticks = new int24[](numberOfTicksToWrite);
	int24 initTick = int24(200);
	path.ticks[0] = initTick;

	
        unchecked {
	    do {
		vm.warp(init_timestamp + index*DEFAULT_DELTA_SECONDS);
		if (index == 0) { marketStatisticsAlgebraRef.initializeTWAP(uint32(vm.getBlockTimestamp()),initTick);}
		// note: This is vol = (\delta = 1 p** (\eta =1))
		uint88 _realizedTickVol = marketStatisticsAlgebraRef.getAverageVolatilityLast(path.ticks[index],uint32(vm.getBlockTimestamp()));
		uint88 realizedTickVol = _realizedTickVol;
		//  todo realizedTickVol in this condition must equal the number that makes the price p(200)
		if (_realizedTickVol == 0 ) { realizedTickVol = uint88(TickMath.getSqrtRatioAtTick(initTick));}

		int256 ln_vol_WAD = FixedPointMathLib.lnWad(int256(uint256(realizedTickVol)));
	        index++;
		int24 tick =  int24(ln_vol_WAD / ExpMath.HALF_LN_TICK_BASE);
		console2.log(tick);
	        marketStatisticsAlgebraRef.writeTimepoint(uint32(vm.getBlockTimestamp()),tick);		  
	       
	    } while (index < numberOfTicksToWrite);
	}

	
	
    }

    
    
}
