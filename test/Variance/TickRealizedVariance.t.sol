// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@test/BaseTest.t.sol";
import {ITickSpacing, MAX_TICK_SPACING} from "@test/TickSpacing.t.sol";
import {IWindow} from "@test/Window.t.sol";
import {MIN_TICK,MAX_TICK,ITick,normTickVal} from "@test/Tick.t.sol";

import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {console2} from "forge-std/console2.sol";

import {ITickAverage} from "@test/TickAverage.t.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";

import {VolatilityOracle} from "volatility-oracle-plugin/libraries/VolatilityOracle.sol";

import {
    IControllerSetter,
    IPremiumSetter
} from "@test/NoFeeVarianceClaimBuilderTest.t.sol";


// cast keccak vol-markets.TickMoments.tickRealizedVariance
bytes32 constant TICK_REALIZED_VARIANCE_SLOT = 0x4d7dc81a011157c981c6066adcb913eb647dbd449622e803670aaa8e71abc7f1;

function tick2Delta (int24 tickAvg, int24 tickRef) pure returns(int48) {
    return int48(int48(tickRef - tickAvg)*int48(tickRef - tickAvg));
}

interface ITickRealizedVariance {
    function read_tick_realizedVariance() external returns(uint88);
}


contract TickRealizedVarianceTest is BaseTest {

    address controller;
    
    function setUp() public override {
	super.setUp();
    	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
        deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));

	(bool succ, address _tmp,) = deployHook(
            compilePlank("src/Controllers/Controller.plk"),
            CREATE2_FACTORY,
            NoFeeVarianceClaimBuilderPermissions
        );
	if (succ) {
            controller = _tmp;
        }
    }
    
    function ObserverTracksAlgebraIntegralVolatilityPluginForRealizedVariance(Context memory ctx) external FullContext(ctx) MarketSet(ctx) {
		uint256 windowIdx = 0;
		int80 expectedPrevTick2Accum;
		do {
		    ctx = shock(ctx);
		    ITick(ctx.io).set_tick(ctx.shock.newTick);
		    windowIdx++;
		    
		} while (windowIdx <= ctx.args.windowLen);

    }
    
    function test__fuzz__ObserverTracksAlgebraIntegralVolatilityPluginForRealizedVariance (FuzzInputsCommon memory args) external {
	Context memory ctx = globalContext();
	ctx = setMarket(args);
	
	test(
	     this.ObserverTracksAlgebraIntegralVolatilityPluginForRealizedVariance,
	     ctx
	);
	// ==============================PRE-CONDITIONS ================================
	uint256 windowIdx = 0;
	int80 expectedPrevTick2Accum;
	do {
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));
	    ITick(realizedVarianceImpl).set_tick(tickOnRun);
	    int24 stepTickAvg =  ITickAverage(realizedVarianceImpl).read_tick_average();
	    console2.log("stepTickAvg:", stepTickAvg);
	    int24 stepTick = ITick(realizedVarianceImpl).read_tick();
	    console2.log("runningTick:", stepTick);
	    // It should set the prevTick2Acc to the tickCalldata squared delta with TickAvg.
	    expectedPrevTick2Accum += int80(tick2Delta(stepTickAvg,stepTick));
	    int80 storedPrevTick2Accum = SafeCastLib.toInt80(int256(uint256(vm.load(realizedVarianceImpl, bytes32(uint256(TICK_REALIZED_VARIANCE_SLOT) + 1)))));
	    assertEq(storedPrevTick2Accum,expectedPrevTick2Accum);

	    windowIdx++;

	    uint88 storedStepTickRealizedVariance = ITickRealizedVariance(realizedVarianceImpl).read_tick_realizedVariance();
	    if (windowIdx == windowLenCalldata) {
		// It should set the tickRealizedVol to prevTick2Acc over windowIdx
		uint88 expectedWindowTickRealizedVariance = SafeCastLib.toUint88(uint256(int256(expectedPrevTick2Accum)/int256(windowLenCalldata)));
		assertEq(storedStepTickRealizedVariance,expectedWindowTickRealizedVariance);
	    } else {
		uint88 expectedStepTickRealizedVariance = SafeCastLib.toUint88(uint256(int256(expectedPrevTick2Accum)/int256(windowIdx)));
		assertEq(storedStepTickRealizedVariance,expectedStepTickRealizedVariance);
	    }
	} while (windowIdx < maxIdxPick);
    }
}

