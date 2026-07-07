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
    uint16 constant TOTAL_SAMPLE_SIZE = uint16(65535);

    struct MarketStatisticsUniV3RefStorage{
	    uint16 timepointIndex;
	    uint32 lastTimepointTimestamp;
	    bool isInitialized;
	    Oracle.Observation[65535] timepoints;
    }
	
    // keccak256("marketStatisticsUniV3.storage")
    bytes32 SLOT_MARKET_STATISTICS_UNIV3 = 0xd84d04cffcedae72d800d39925bfb5a8a7f96741edb2a98808d8d746a4827f7b;

    function getStorage() internal returns(MarketStatisticsUniV3RefStorage storage $){
	bytes32 s_index_base = SLOT_MARKET_STATISTICS_UNIV3;
	assembly {
	   $.slot := s_index_base
	}
    }
    
    function getTwapTick(uint32 dt, int24 tick, uint32 currentTimestamp) public returns(int24 timeWeightedAverageTick){
	    require(dt != 0, 'Period is zero');
	    MarketStatisticsUniV3RefStorage storage $ = getStorage();
	    uint16 lastIndex = $.timepointIndex;
	    (int56 old_tick_cumulative, ) = Oracle.observeSingle($.timepoints, currentTimestamp, dt, tick,lastIndex, ZERO_LIQUIDITY, UNIT_SAMPLE_SIZE);
	    (int56 current_tick_cumulative, ) = Oracle.observeSingle($.timepoints,currentTimestamp, ZERO_DT, tick,lastIndex, ZERO_LIQUIDITY,UNIT_SAMPLE_SIZE);
 	    int56 delta_tick_cumulative = current_tick_cumulative - old_tick_cumulative;
            timeWeightedAverageTick = int24(delta_tick_cumulative / int56(uint56(dt)));

            if (delta_tick_cumulative < 0 && (delta_tick_cumulative % int56(uint56(dt)) != 0)) {
		timeWeightedAverageTick--;
	    }
    }

    function initializeTWAP(uint32 blockTimestamp, int24 tick) public{
	MarketStatisticsUniV3RefStorage storage $ = getStorage();
        Oracle.initialize($.timepoints, blockTimestamp);
	$.timepointIndex = 0; 
	$.lastTimepointTimestamp = blockTimestamp;
	$.isInitialized = true;
    }

    function writeTimepoint(uint32 timestamp, int24 tick) public {
	MarketStatisticsUniV3RefStorage storage $ = getStorage();
        ($.timepointIndex, ) = Oracle.write(
					    $.timepoints,
					    $.timepointIndex,
					    timestamp,
					    tick,
					    ZERO_LIQUIDITY,
					    TOTAL_SAMPLE_SIZE,
					    TOTAL_SAMPLE_SIZE
	);

	$.lastTimepointTimestamp = timestamp;
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
 
}

contract MarketStatisticsTest is Test {


    struct TickHistory {int24[] ticks;}

    TickHistory path;
    uint32 constant DEFAULT_DELTA_SECONDS = 30 seconds;

    MarketStatisticsAlgebraRef marketStatisticsAlgebraRef;
    MarketStatisticsUniV3Ref marketStatisticsUniV3Ref;

    bool forked;
    uint256 forkId;
    
    function  setUp() public {
	try vm.rpcUrl("local") returns(string memory url) {
	     forkId = vm.createSelectFork(url);
	     marketStatisticsAlgebraRef = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
	     marketStatisticsUniV3Ref = new MarketStatisticsUniV3Ref();
	     vm.makePersistent(address(marketStatisticsAlgebraRef), address(marketStatisticsUniV3Ref));
	} catch {
	    marketStatisticsAlgebraRef = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
	    marketStatisticsUniV3Ref = new MarketStatisticsUniV3Ref();
	    forked = false;
	}

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
	int24 tickMean = marketStatisticsAlgebraRef.getTwapTick(total_delta_t, tick, uint32(vm.getBlockTimestamp()));
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
