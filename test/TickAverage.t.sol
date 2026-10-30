// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {WindowState,WINDOW_SLOT} from "./Window.t.sol";
import {ITickSpacing} from "./TickSpacing.t.sol";
import {IWindow} from "./Window.t.sol";
import {MIN_TICK,MAX_TICK,ITick,normTickVal} from "./Tick.t.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

bytes32 constant TICK_AVERAGE_SLOT = 0x639a68f1e2d4af32ba8134bbdb9c46e158a306a8d58cd3f92a9c3e7e5c05a6b3;


// todo: Test running OOG on 86400 window size, this needs fix
interface ITickAverage {
    function read_tick_average() external returns(int24);
}

contract TickAverageTest is PlankTestBase{
    
    address main;
    
    WindowState tickAverageWindowState;

    function setUp() public {
	main = deployPlank("src/Main.plk");
	vm.makePersistent(main);
    }

    
    modifier whenTickAverageUpdatesFromTickCalldata() {
        _;
    }
    function test_WhenTickAverageWindowStateIsNotInitialized(uint256 windowLen,uint24 tickSpacing,int24 tick) external whenTickAverageUpdatesFromTickCalldata {

	// =================================PRE-CONDITIONS============================================
	uint24 tickSpacingCalldata = tickSpacing;
	// TODO: 200 is arbitrary, to be refined
	// 2 is so the windowLen does not equal the indx. This case is handled on the test below
	uint256 windowLenCalldata = bound(windowLen, 2, 200);
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	IWindow(main).set_window(windowLenCalldata);
	int24 tickCalldata = tick;

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
	// TODO: 86400 is somewhat arbitrary is a day WINDOW, to be refined
	uint256 windowLenCalldata = bound(windowLen, 1, 200);
	ITickSpacing(main).set_tick_spacing(tickSpacing);
	uint24 tickSpacingCalldata =  ITickSpacing(main).read_tick_spacing();
	IWindow(main).set_window(windowLenCalldata);
	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
	uint256 windowIdx = 0;
	int56 expectedPrevTickAccum;
	do {
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));
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

