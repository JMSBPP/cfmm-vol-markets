// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {ITickSpacing, MAX_TICK_SPACING, MIN_TICK_SPACING} from "./TickSpacing.t.sol";

interface ITick {
    function set_tick(int24) external;
    function read_tick() external returns(int24);
}

// cast keccak vol-markets.Tick
bytes32 constant TICK_SLOT = 0x62b50c96ec7c8db111173d139b431c4ef72820d773cfe40f8537db4c663ab7e6;
int24 constant MIN_TICK = -887272;
int24 constant MAX_TICK = 887272;


function roundTick(int24 currentTick, int24 tickSpacing) pure returns (int256 roundedTick) {
    int256 tick = int256(currentTick);
    int256 ts = int256(tickSpacing);
    int256 compressed = tick / ts;
    if (tick < 0 && tick % ts != 0) compressed--; // round towards negative infinity
    roundedTick = compressed * ts;
}

function usableMin(int24 tickSpacing) pure returns (int24) {
    return (MIN_TICK / tickSpacing) * tickSpacing;
}

function usableMax(int24 tickSpacing) pure returns (int24) {
    return (MAX_TICK / tickSpacing) * tickSpacing;
}

function normTickVal(int24 tick, uint24 tickSpacing) pure returns (int24) {
    int24 ts = SafeCastLib.toInt24(uint256(tickSpacing));
    int256 rounded = roundTick(tick, ts);
    int256 lo = int256(usableMin(ts));
    int256 hi = int256(usableMax(ts));
    if (rounded < lo) return int24(lo);
    if (rounded > hi) return int24(hi);
    return int24(rounded);
}

contract TickTest is PlankTestBase {

    address main;
    
    function setUp() public {
	main = deployPlank("src/Main.plk");
	vm.makePersistent(main);
    }

    modifier whenSet_tickIsCalled() {
        _;
    }

    function test_RevertWhen_TickSpacingOnStorageIsNotSet(int24 tick) external whenSet_tickIsCalled {
	int24 tickCalldata = tick;
	// It should revert.
	vm.expectRevert(ITickSpacing.TickSpacingNotOnStorage.selector);
	ITick(main).set_tick(tickCalldata);
    }

    function test_WhenTickSpacingOnStorageIsSet(uint24 tickSpacingOnStorage, int24 tick) external whenSet_tickIsCalled {
        uint24 tickSpacingCalldata = tickSpacingOnStorage;
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	
       
        // It should set tickVal to normTickVal.
	int24 tickCalldata = tick;
	ITick(main).set_tick(tickCalldata);	
	int24 tickStoredVal = SafeCastLib.toInt24(int256(uint256(vm.load(main,TICK_SLOT))));	assertEq(tickStoredVal, normTickVal(tickCalldata,ITickSpacing(main).read_tick_spacing()));
        
    }

    function test__ReadTickLoadsTickFromStorage(uint24 tickSpacing, int24 tick) external {
	uint24 tickSpacingCalldata = tickSpacing;
	int24 tickCalldata = tick;
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	ITick(main).set_tick(tickCalldata);

	int24 tickStoredVal = SafeCastLib.toInt24(int256(uint256(vm.load(main,TICK_SLOT))));
	assertEq(ITick(main).read_tick(),tickStoredVal);
    }
}

