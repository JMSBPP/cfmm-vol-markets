// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;
import {PlankTestBase} from "plank/PlankTestBase.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";
import {ITickSpacing, MAX_TICK_SPACING, MIN_TICK_SPACING} from "./TickSpacing.t.sol";

interface ITick {
    function set_tick(int24) external;
    function read_tick() external returns(int24);
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

/// @dev Mirrors Tick.plk minTick: spacing-aligned MIN_TICK, inset +tickSpacing when equal.
function usableMin(int24 tickSpacing) pure returns (int24) {
    int24 lo = (MIN_TICK / tickSpacing) * tickSpacing;
    if (lo == MIN_TICK) {
        lo = lo + tickSpacing;
    }
    return lo;
}

/// @dev Mirrors Tick.plk maxTick: spacing-aligned MAX_TICK, inset -tickSpacing when equal.
function usableMax(int24 tickSpacing) pure returns (int24) {
    int24 hi = (MAX_TICK / tickSpacing) * tickSpacing;
    if (hi == MAX_TICK) {
        hi = hi - tickSpacing;
    }
    return hi;
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

contract TickTest is PlankTestBase, Deployers {

    address main;
    address poolManager;
    address positionManager;
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");
    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire = makeAddr("cfmm.vol-markets.numeraire");
    
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
        // Align-safe extremes live in Tick.plk minTick/maxTick (mirrored by usableMin/Max).
        uint24 tickSpacingCalldata = uint24(
            bound(uint256(tickSpacingOnStorage), uint256(MIN_TICK_SPACING), uint256(MAX_TICK_SPACING))
        );
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	uint24 ts = ITickSpacing(main).read_tick_spacing();
	int24 lo = usableMin(SafeCastLib.toInt24(uint256(ts)));
	int24 hi = usableMax(SafeCastLib.toInt24(uint256(ts)));
	int24 tickCalldata = int24(bound(int256(tick), int256(lo), int256(hi)));

        // It should set tickVal to normTickVal.
	ITick(main).set_tick(tickCalldata);	
	int24 tickStoredVal = SafeCastLib.toInt24(int256(uint256(vm.load(main,TICK_SLOT))));
	assertEq(tickStoredVal, normTickVal(tickCalldata, ts));
        
    }

    function test__ReadTickLoadsTickFromStorage(uint24 tickSpacing, int24 tick) external {
	uint24 tickSpacingCalldata = uint24(
            bound(uint256(tickSpacing), uint256(MIN_TICK_SPACING), uint256(MAX_TICK_SPACING))
        );
	ITickSpacing(main).set_tick_spacing(tickSpacingCalldata);
	uint24 ts = ITickSpacing(main).read_tick_spacing();
	int24 lo = usableMin(SafeCastLib.toInt24(uint256(ts)));
	int24 hi = usableMax(SafeCastLib.toInt24(uint256(ts)));
	int24 tickCalldata = int24(bound(int256(tick), int256(lo), int256(hi)));
	ITick(main).set_tick(tickCalldata);

	int24 tickStoredVal = SafeCastLib.toInt24(int256(uint256(vm.load(main,TICK_SLOT))));
	assertEq(ITick(main).read_tick(),tickStoredVal);
    }
}
