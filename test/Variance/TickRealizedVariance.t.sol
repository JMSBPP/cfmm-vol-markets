// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PlankTestBase} from "plank/PlankTestBase.sol";
import {ITickSpacing, MAX_TICK_SPACING} from "@test/TickSpacing.t.sol";
import {IWindow} from "@test/Window.t.sol";
import {MIN_TICK,MAX_TICK,ITick,normTickVal} from "@test/Tick.t.sol";

import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {console2} from "forge-std/console2.sol";

import {ITickAverage} from "@test/TickAverage.t.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";

import {
    IEnv,
    IMarketBuilder,
    IMarketLens,
    IControllerSetter,
    IPremiumSetter
} from "@test/NoFeeVarianceClaimBuilderTest.t.sol";


// cast keccak vol-markets.TickMoments.tickRealizedVariance
bytes32 constant TICK_REALIZED_VOLATILITY_SLOT = 0xf69e753063c9a37dc7169cc2d90bb6795545b8db9f6c22f3d499d73437f5553a;

function tick2Delta (int24 tickAvg, int24 tickRef) pure returns(int48) {
    return int48(int48(tickRef - tickAvg)*int48(tickRef - tickAvg));
}

interface ITickRealizedVariance {
    function read_tick_realizedVariance() external returns(uint88);
}


contract TickRealizedVarianceTest is PlankTestBase, Deployers, HookDeployer {

    address realizedVarianceImpl = makeAddr("cfmm.vol-markets.realizedVarianceImpl");

    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire = makeAddr("cfmm.vol-markets.numeraire");
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");

    address controller;
    address poolManager;

    function setUp() public {
	deployFreshManager();
	poolManager = address(manager);
        deployCodeTo(realizedVarianceImpl, compilePlank("src/Main.plk"));
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
        deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(alignTickHarness, compilePlank("src/ProtocolSync/AlignTick.plk"));
	(bool succ, address _tmp,) = deployHook(
            compilePlank("src/Controllers/Controller.plk"),
            CREATE2_FACTORY,
            NoFeeVarianceClaimBuilderPermissions
        );
	if (succ) {
            controller = _tmp;
        }

	IEnv(alignTickHarness).setIO(realizedVarianceImpl);
        IEnv(realizedVarianceImpl).setTickAligner(alignTickHarness);
        IEnv(alignTickHarness).setPoolManager(poolManager);
        IEnv(realizedVarianceImpl).setPoolManager(poolManager);

	IMarketBuilder(realizedVarianceImpl).setPair(underlying, numeraire, true);
	IControllerSetter(realizedVarianceImpl).setController(controller);
    }

    modifier whenSetTickIsCalledWithTickCalldata() {
        _;
    }

    function test_WhenTickAverageStateIsInitialized(
						          uint256 windowLen,
							  uint24 tickSpacing,
							  uint256 maxIdx

    ) external whenSetTickIsCalledWithTickCalldata {
	// ==============================PRE-CONDITIONS ================================
	// TODO: 200 is somewhat arbitrary and does not lead OOG

	uint256 windowLenCalldata = bound(windowLen, 1, 200);
	// AlignTick swap sizing OOGs on unit spacing across large tick jumps.
	uint24 tickSpacingCalldata = uint24(bound(tickSpacing, 60, MAX_TICK_SPACING));
	ITickSpacing(realizedVarianceImpl).set_tick_spacing(tickSpacingCalldata);
	tickSpacingCalldata = ITickSpacing(realizedVarianceImpl).read_tick_spacing();
	IWindow(realizedVarianceImpl).set_window(windowLenCalldata);
	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
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
	    int80 storedPrevTick2Accum = SafeCastLib.toInt80(int256(uint256(vm.load(realizedVarianceImpl, bytes32(uint256(TICK_REALIZED_VOLATILITY_SLOT) + 1)))));
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

