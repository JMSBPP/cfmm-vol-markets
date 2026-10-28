// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";


bytes32 constant TICK_SPACING_SLOT = 0xf21ff12c997bb9e034b4c86d66ba5b6ceb2a3b177ea03c1656edb0264e54224b;

uint24 constant MIN_TICK_SPACING = 1;
uint24 constant MAX_TICK_SPACING = 500;

interface ITickSpacing {
    function set_tick_spacing(uint24) external;
}


contract TickSpacingTest is PlankTestBase {
    address main;
    
    function setUp() public {
	main = deployPlank("src/Main.plk");
	vm.makePersistent(main);
    }

    modifier whenSet_tick_spacingIsCalled() {
        _;
    }

    function test_WhenTheTickSpacingCalldataIsBetweenMIN_TICK_SPACINGAndMAX_TICK_SPACING(uint24 tickSpacing)
        external
        whenSet_tick_spacingIsCalled
    {
        uint24 tickSpacingCalldata = uint24(bound(uint256(tickSpacing),uint256(MIN_TICK_SPACING),uint256(MAX_TICK_SPACING)));
        // It should set tickSpacingVal to tickSpacingCalldata.
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	uint24 tickSpacingStoredVal = SafeCastLib.toUint24(uint256(vm.load(main,TICK_SPACING_SLOT)));
	assertEq(tickSpacingStoredVal,tickSpacingCalldata);

    }

    function test_WhenTheTickSpacingCalldataIsGreaterThanMAX_TICK_SPACING(uint24 tickSpacing) external whenSet_tick_spacingIsCalled {
        uint24 tickSpacingCalldata = uint24(bound(uint256(tickSpacing),uint256(MAX_TICK_SPACING),uint256(type(uint24).max)));
	
        // It should set the tickSpacingVal to MAX_TICK_SPACING.
	 ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	uint24 tickSpacingStoredVal = SafeCastLib.toUint24(uint256(vm.load(main,TICK_SPACING_SLOT)));
	assertEq(tickSpacingStoredVal,MAX_TICK_SPACING);
	// TODO: Below is unimplemented/untested
        // It should log "tickSpacingCalldata out of bounds:: set to MAX_TICK_SPACING".
    }

    function test_WhenTheTickSpacingCalldataIsZero(uint24 tickSpacing) external whenSet_tick_spacingIsCalled {
	uint24 tickSpacingCalldata = uint24(bound(uint256(tickSpacing),uint256(type(uint24).min),uint256(MIN_TICK_SPACING)));
	// It should set the tickSpacingVal to MIN_TICK_SPACING.
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	uint24 tickSpacingStoredVal = SafeCastLib.toUint24(uint256(vm.load(main,TICK_SPACING_SLOT)));
	assertEq(tickSpacingStoredVal,MIN_TICK_SPACING);
	// TODO: Below is unimplemented/untested

	// It should log "tickSpacingCalldata out of bounds:: set to MIN_TICK_SPACING".
	
    }
}

