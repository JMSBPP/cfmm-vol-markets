// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {WindowState,WINDOW_SLOT} from "./Window.t.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

bytes32 constant TICK_AVERAGE_SLOT = 0x639a68f1e2d4af32ba8134bbdb9c46e158a306a8d58cd3f92a9c3e7e5c05a6b3;

interface ITickAverage {
    function set_tick(int24) external;
}

contract TickAverageTest is PlankTestBase{
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;
    
    address main;
    
    WindowState tickAverageWindowState;

    function setUp() public {
	main = deployPlank("src/Main.plk");
	vm.makePersistent(main);
    }

    
    modifier whenTickAverageUpdatesFromTickCalldata() {
        _;
    }
    function test__int256(int256 x, uint256  y) external {
	/****************************************************/
	/* vm.assume(x < 0 && x > type(int256).max);	    */
	/* vm.assume(y  == uint256(-x));		    */
	/****************************************************/
	console2.logBytes32(bytes32(uint256(type(int256).min)));
	console2.logBytes32(bytes32(type(uint256).min));
	console2.logBytes32(bytes32(uint256(type(int256).max)));
	console2.logBool(bytes32(type(uint256).max -1) >> 1 == bytes32(uint256(type(int256).max)));
	console2.logBytes32(bytes32(uint256(int256(type(int24).max))));
       
    }

    function test_WhenTickAverageWindowStateIsNotInitialized(int24 tick) external whenTickAverageUpdatesFromTickCalldata {
	vm.assume(tick < 0);
	console2.logBytes32(bytes32(uint256(int256(tick))));
	// As a pre-req we have that the windowState is not initialized
	vm.store(main,bytes32(uint256(WINDOW_SLOT) + 2),bytes32(uint256(WindowState.WindowNotInitialized)));
	int24 tickCalldata = tick;
	{
	    if (tick > MAX_TICK) {
		tickCalldata = MAX_TICK;
	    } else if (tick < MIN_TICK) {
		tickCalldata = MIN_TICK;
	    }
	}
	
	ITickAverage(main).set_tick(tickCalldata);
	// TODO: A comptime property is that the the tick_window_slot is the window_slot
        // It should set the tick average window state to windowInitialized.
	uint256 tickAverageWindowStateStored = uint256(vm.load(main, bytes32(uint256(WINDOW_SLOT) + 2)));
	assertEq(uint256(WindowState.WindowInitialized),tickAverageWindowStateStored);
        // It should set the tick average window index to one.
	uint256 tickAverageWindowIdxStored = uint256(vm.load(main, bytes32(uint256(WINDOW_SLOT) + 1)));
	assertEq(tickAverageWindowIdxStored,1);
	// It should set the prevTickAcc to tickCalldata.
	uint256 prevTickAccStored = uint256(vm.load(main,bytes32(uint256(TICK_AVERAGE_SLOT)+1))) ;
	assertEq(SafeCastLib.toInt24(prevTickAccStored), tickCalldata);
    }

    function test_WhenTickAverageWindowStateIsInitialized() external whenTickAverageUpdatesFromTickCalldata {
        // It should set as the prevTickLog2Acc the sum of the current prevTickLogAcc with the log2 of the tickCalldata.
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

