// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";
import {WindowState,WINDOW_SLOT} from "./Window.t.sol";
import {ITickSpacing, MIN_TICK_SPACING, MAX_TICK_SPACING} from "./TickSpacing.t.sol";
import {IWindow} from "./Window.t.sol";
import {MIN_TICK, MAX_TICK, ITick, normTickVal, usableMin, usableMax} from "./Tick.t.sol";

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

bytes32 constant TICK_AVERAGE_SLOT = 0x639a68f1e2d4af32ba8134bbdb9c46e158a306a8d58cd3f92a9c3e7e5c05a6b3;


// todo: Test running OOG on 86400 window size, this needs fix
interface ITickAverage {
    function read_tick_average() external returns(int24);
}

interface IEnv {
    function setIO(address) external;
    function setTickAligner(address) external;
    function setPoolManager(address) external;
    function setPositionManager(address) external;
}

interface IMarketBuilder {
    function setPair(address, address, bool) external;
}

contract TickAverageTest is PlankTestBase, Deployers {
    
    address main;
    address poolManager;
    address positionManager;
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");
    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire = makeAddr("cfmm.vol-markets.numeraire");
    
    WindowState tickAverageWindowState;

    function setUp() public {
	deployFreshManager();
	poolManager = address(manager);
	positionManager = SfpmBytecodeDeployer.deploy(
	    vm, manager, 2100000000000000000000, 2100000000000000000000, 10000
	);
	main = deployPlank("src/Main.plk");
	deployCodeTo(alignTickHarness, compilePlank("src/ProtocolSync/AlignTick.plk"));
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
	IEnv(alignTickHarness).setIO(main);
	IEnv(main).setTickAligner(alignTickHarness);
	IEnv(alignTickHarness).setPoolManager(poolManager);
	IEnv(main).setPoolManager(poolManager);
	IEnv(alignTickHarness).setPositionManager(positionManager);
	IEnv(main).setPositionManager(positionManager);
	IMarketBuilder(main).setPair(underlying, numeraire, true);
	vm.makePersistent(main);
    }

    
    modifier whenTickAverageUpdatesFromTickCalldata() {
        _;
    }
    function test_WhenTickAverageWindowStateIsNotInitialized(uint256 windowLen,uint24 tickSpacing,int24 tick) external whenTickAverageUpdatesFromTickCalldata {

	// =================================PRE-CONDITIONS============================================
	// Same V4-init-safe bounds as Tick.t.sol (exclude exact MAX_TICK sqrt).
	uint24 tickSpacingCalldata = uint24(
	    bound(uint256(tickSpacing), uint256(MIN_TICK_SPACING), uint256(MAX_TICK_SPACING))
	);
	// Cap matches AlignTick/NoFee: large tick-range aligns are multi-million gas each.
	// 2 is so the windowLen does not equal the indx. This case is handled on the test below
	uint256 windowLenCalldata = bound(windowLen, 2, 5);
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	IWindow(main).set_window(windowLenCalldata);
	uint24 ts = ITickSpacing(main).read_tick_spacing();
	int24 lo = usableMin(SafeCastLib.toInt24(uint256(ts)));
	int24 hi = usableMax(SafeCastLib.toInt24(uint256(ts)));
	if (hi == MAX_TICK) {
	    hi = hi - SafeCastLib.toInt24(uint256(ts));
	}
	int24 tickCalldata = int24(bound(int256(tick), int256(lo), int256(hi)));

	//================================TEST ==================================================
	ITick(main).set_tick(tickCalldata);
	// TODO: A comptime property is that the the tick_average_window_slot is the window_slot
        // It should set the tick average window state to windowInitialized.
	uint256 tickAverageWindowStateStored = uint256(vm.load(main, bytes32(uint256(WINDOW_SLOT) + 2)));

	assertEq(uint256(WindowState.WindowInitialized),tickAverageWindowStateStored);
        // It should set the tick average window index to one.
	uint256 tickAverageWindowIdxStored = uint256(vm.load(main, bytes32(uint256(WINDOW_SLOT) + 1)));
	assertEq(tickAverageWindowIdxStored,1);
	// It should set the prevTickAcc to tickCalldata.
	uint256 prevTickAccStored = uint256(vm.load(main,bytes32(uint256(TICK_AVERAGE_SLOT)+1))) ;
	assertEq(SafeCastLib.toInt24(int256(prevTickAccStored)), ITick(main).read_tick());
    }

    function test__ReadTickAverageLoadsFromStorage () external {
	int24 readTickAverage = ITickAverage(main).read_tick_average();
	int24 storedTickAverage = SafeCastLib.toInt24(int256(uint256(vm.load(main,TICK_AVERAGE_SLOT))));
	assertEq(storedTickAverage,readTickAverage);
    }
    /// forge-config :default.fuzz.show-logs = true
    function test_WhenTickAverageWindowStateIsInitializedAndWindowIdxReachesWindowLen(
							  uint256 windowLen,
							  uint24 tickSpacing,
							  uint256 maxIdx
    ) external whenTickAverageUpdatesFromTickCalldata {
        // ==============================PRE-CONDITIONS ================================
	// Cap matches AlignTick/NoFee: large tick-range aligns are multi-million gas each;
	// windowLen up to 200 OOGs mid-loop and surfaces as FailedToAlignTicks.
	uint256 windowLenCalldata = bound(windowLen, 1, 5);
	uint24 tickSpacingCalldata = uint24(
	    bound(uint256(tickSpacing), uint256(MIN_TICK_SPACING), uint256(MAX_TICK_SPACING))
	);
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	tickSpacingCalldata = ITickSpacing(main).read_tick_spacing();
	int24 lo = usableMin(SafeCastLib.toInt24(uint256(tickSpacingCalldata)));
	int24 hi = usableMax(SafeCastLib.toInt24(uint256(tickSpacingCalldata)));
	// Align swap limits reject exact MIN/MAX_SQRT_PRICE; inset when usable extremes hit them.
	int24 ts = SafeCastLib.toInt24(uint256(tickSpacingCalldata));
	if (hi == MAX_TICK) {
	    hi = hi - ts;
	}
	if (lo == MIN_TICK) {
	    lo = lo + ts;
	}
	IWindow(main).set_window(windowLenCalldata);
	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
	uint256 windowIdx = 0;
	int56 expectedPrevTickAccum;
	do {
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = int24(bound(int256(tickSeed), int256(lo), int256(hi)));
	    ITick(main).set_tick(tickOnRun);
	    
	    expectedPrevTickAccum+= int56(int256(ITick(main).read_tick()));
            // It should set as the prevTickAcc the sum of the current prevTickLogAcc with the tickCalldata.
	    int56 storedPrevTickAccum = SafeCastLib.toInt56(int256(uint256(vm.load(main, bytes32(uint256(TICK_AVERAGE_SLOT) + 1)))));
            assertEq(storedPrevTickAccum,expectedPrevTickAccum);
	    // It should set the tick average window index to tick average window index plus one
	    uint256 storedWindowIdx = uint256(vm.load(main,bytes32(uint256(WINDOW_SLOT) + 1)));
	    windowIdx++;

	    int24 storedRunningTickAvg = ITickAverage(main).read_tick_average();
	    uint256 tickAverageWindowStateStored = uint256(vm.load(main, bytes32(uint256(WINDOW_SLOT) + 2)));

	    if (windowIdx == windowLenCalldata) {
		int24 expectedWindowTickAvg = normTickVal(
		    SafeCastLib.toInt24(int256(expectedPrevTickAccum)/int256(windowLenCalldata)),
		    tickSpacingCalldata
		);
		assertEq(storedRunningTickAvg, expectedWindowTickAvg);
		assertEq(tickAverageWindowStateStored, uint256(WindowState.WindowNotInitialized));
		assertEq(storedWindowIdx, 0);
	    } else {
		assertEq(storedWindowIdx, windowIdx);
		int24 expectedRunningTickAvg = normTickVal(
		    SafeCastLib.toInt24(int256(expectedPrevTickAccum)/int256(windowIdx)),
		    tickSpacingCalldata
		);
		assertEq(storedRunningTickAvg, expectedRunningTickAvg);
		assertEq(tickAverageWindowStateStored, uint256(WindowState.WindowInitialized));
	    }
	} while (windowIdx < maxIdxPick);
    }

}
