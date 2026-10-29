// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {WindowState,WINDOW_SLOT} from "./Window.t.sol";
import {ITickSpacing} from "./TickSpacing.t.sol";
import {IWindow} from "./Window.t.sol";
import {MIN_TICK,MAX_TICK,ITick} from "./Tick.t.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

bytes32 constant TICK_AVERAGE_SLOT = 0x639a68f1e2d4af32ba8134bbdb9c46e158a306a8d58cd3f92a9c3e7e5c05a6b3;

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
	uint256 windowLenCalldata = bound(windowLen, 1, 200);
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
	assertEq(SafeCastLib.toInt24(prevTickAccStored), ITick(main).read_tick());
    }

    function test_WhenTickAverageWindowStateIsInitialized() external whenTickAverageUpdatesFromTickCalldata {
        // It should set as the prevTickAcc the sum of the current prevTickLogAcc with the log2 of the tickCalldata.
        // It should set the tick average window index to tick average window index plus one
        // It should store the division of prevTickLog2Acc and tick average window index on tickAverage storage slot
    }

    function test_WhenTickAverageWindowIndexIsEqualToTickAverageWindowLen()
        external
        whenTickAverageUpdatesFromTickCalldata
    {
        // It should have tick average window state windowInitialized
        // It should store the division of prevTickLog2Acc and tick average window len on tickAverage storage slot
        // It should set the tick average window state to windowUninitialized
    }
}

