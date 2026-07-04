// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {VolatilityOracle} from "@cryptoalgebra/volatility-oracle-plugin/libraries/VolatilityOracle.sol";
import {VolatilityOracleStorage} from "@cryptoalgebra/volatility-oracle-plugin/libraries/VolatilityOracleStorage.sol";
import {VolatilityOraclePluginImplementation} from "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";

contract MarketStatisticsUniV3Ref{

    function getTwapTick(uint32 dt, int24 tick, uint32 currentTimeStamp) public returns(int24){}
    function initializeTWAP(uint32 blockTimestamp, int24 tick) public{}
}

contract MarketStatisticsTest is Test {


    struct TickHistory {
	int24[] ticks;
    }

    TickHistory path;
    uint32 constant DEFAULT_DELTA_SECONDS = 30 seconds;

    VolatilityOraclePluginImplementation marketStatisticsAlgebraRef;
    MarketStatisticsUniV3Ref marketStatisticsUniV3Ref;

    function  setUp() public {
	marketStatisticsAlgebraRef = new VolatilityOraclePluginImplementation();
	marketStatisticsUniV3Ref = new MarketStatisticsUniV3Ref();
	
    }

    function test__fuzz__algebraOneObsTickAvgEqObs(int24 tickInit, uint32 _init_timeStamp) public {
	uint32 init_timeStamp = uint32(vm.bound(uint256(_init_timeStamp), 0 ,type(uint32).max / 2));
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
        uint32 init_timeStamp = uint32(vm.bound(uint256(_init_timeStamp), 0 ,type(uint32).max / 2));
	path.ticks = new int24[](1);
	path.ticks[0] = tickInit;
	vm.warp(init_timeStamp);
	marketStatisticsUniV3Ref.initializeTWAP(uint32(vm.getBlockTimestamp()), path.ticks[0]);
	vm.warp(init_timeStamp + DEFAULT_DELTA_SECONDS);
	int24 meanTick = marketStatisticsUniV3Ref.getTwapTick(DEFAULT_DELTA_SECONDS, tickInit, uint32(vm.getBlockTimestamp()));
	assertEq(meanTick,tickInit);
    }
}
