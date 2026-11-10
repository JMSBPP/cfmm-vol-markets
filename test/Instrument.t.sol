// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PlankTestBase} from "plank/PlankTestBase.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";
import {ISemiFungiblePositionManager}
from "panoptic-v2-core/contracts/interfaces/ISemiFungiblePositionManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TokenId, TokenIdLibrary} from "panoptic-types/TokenId.sol";
import {Errors} from "panoptic-libraries/Errors.sol";

import {MIN_TICK, MAX_TICK, ITick} from "./Tick.t.sol";
import {ITickSpacing} from "./TickSpacing.t.sol";
import {IWindow} from "./Window.t.sol";
import {
    IEnv,
    IMarketBuilder,
    IMarketLens,
    IControllerSetter,
    IPremiumSetter
} from "./NoFeeVarianceClaimBuilderTest.t.sol";

uint8 constant DEFAULT_VEGOID = 2;

event TokenizedPositionMinted(address indexed caller,TokenId indexed tokenId,uint128 positionSize);

function panopticPoolId(PoolId idV4, int24 tickSpacing, uint256 vegoid) pure returns (uint64) {
    unchecked {
        return uint40(uint256(PoolId.unwrap(idV4))) + (uint64(uint8(vegoid)) << 40)
            + (uint64(uint24(tickSpacing)) << 48);
    }
}

interface IInstrument {
    event MarketAssigned(uint64);
    error MarketNotAssigned();
    function instrument() external returns (uint256);
}

interface IInstrumentEngine {
    error FailedToStartReplication();
    function startReplication () external;
}

contract InstrumentTest is PlankTestBase, Deployers, HookDeployer {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address instrumentImpl = makeAddr("cfmm.vol-markets.instrumentImpl");
    address optionsClearingHouse = makeAddr("cfmm.vol-markets.options-clearing-house");
    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire = makeAddr("cfmm.vol-markets.numeraire");
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");

    address usr = makeAddr("cfmm-vol-markets-user");
    address noFeeVarianceClaimController;
    address poolManager;


    function setUp() public {
        deployFreshManager();
        poolManager = address(manager);

        address sfpm = SfpmBytecodeDeployer.deploy(
            vm, manager, 2100000000000000000000, 2100000000000000000000, 10000
        );
        vm.etch(optionsClearingHouse, sfpm.code);

        deployCodeTo(instrumentImpl, compilePlank("src/Main.plk"));
        deployCodeTo(alignTickHarness, compilePlank("src/ProtocolSync/AlignTick.plk"));
        deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
        deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
        (bool succ, address _tmp,) = deployHook(
            compilePlank("src/Controllers/Controller.plk"),
            CREATE2_FACTORY,
            NoFeeVarianceClaimBuilderPermissions
        );
        if (succ) {
            noFeeVarianceClaimController = _tmp;
        }

        IEnv(alignTickHarness).setIO(instrumentImpl);
        IEnv(instrumentImpl).setTickAligner(alignTickHarness);
        IEnv(alignTickHarness).setPoolManager(poolManager);
        IEnv(instrumentImpl).setPoolManager(poolManager);
        IEnv(alignTickHarness).setPositionManager(optionsClearingHouse);
        IEnv(instrumentImpl).setPositionManager(optionsClearingHouse);
        IMarketBuilder(instrumentImpl).setPair(underlying, numeraire, true);
        IControllerSetter(instrumentImpl).setController(noFeeVarianceClaimController);
    }

    modifier whenSet_tickIsCalled() {
        _;
    }

    function test_WhenWindow_idxIsZero(
        int24 initTick,
        uint24 tickSpacing,
        uint256 windowLen,
        uint24 premiumRate
    ) external whenSet_tickIsCalled {
	// ======================= PRE-CONDITIONS =====================
        uint256 windowLenCalldata = bound(windowLen, 1, 5);
        ITickSpacing(instrumentImpl).set_tick_spacing(tickSpacing);
        IPremiumSetter(instrumentImpl).setPremiumRate(
            uint24(bound(premiumRate, 0, SwapMath.MAX_SWAP_FEE - 1))
        );
        IWindow(instrumentImpl).set_window(windowLenCalldata);
	//==============================================================================
        bytes memory underlyingMarket = IMarketLens(instrumentImpl).getMarketKey();
        PoolKey memory marketKey = abi.decode(underlyingMarket, (PoolKey));
        uint64 expectedPoolId =
            panopticPoolId(marketKey.toId(), marketKey.tickSpacing, DEFAULT_VEGOID);
        assertGt(expectedPoolId, 0);

        int24 initTickCalldata =
            SafeCastLib.toInt24(bound(int256(initTick), int256(MIN_TICK), int256(MAX_TICK)));

        // It should emit MarketAssigned
        vm.expectEmit(false, false, false, true, instrumentImpl);
        emit IInstrument.MarketAssigned(expectedPoolId);

        ITick(instrumentImpl).set_tick(initTickCalldata);

	uint64 realizedPoolId = ISemiFungiblePositionManager(optionsClearingHouse).getPoolId(
            abi.encode(marketKey.toId()), DEFAULT_VEGOID
        );
        assertEq(realizedPoolId, expectedPoolId);
        assertEq(
            IInstrument(instrumentImpl).instrument(),
            TokenId.unwrap(TokenIdLibrary.addPoolId(TokenId.wrap(0), realizedPoolId))
        );
    }

    function test_WhenStartReplicationIsCalled(
        int24 initTick,
        uint24 tickSpacing,
        uint256 windowLen,
        uint24 premiumRate
    ) external {
	// ======================= PRE-CONDITIONS =====================
        uint256 windowLenCalldata = bound(windowLen, 1, 5);
        ITickSpacing(instrumentImpl).set_tick_spacing(tickSpacing);
        IPremiumSetter(instrumentImpl).setPremiumRate(
            uint24(bound(premiumRate, 0, SwapMath.MAX_SWAP_FEE - 1))
        );
        IWindow(instrumentImpl).set_window(windowLenCalldata);
	//============================================================
        // It should revert if MarketNotAssigned
	vm.expectRevert(IInstrument.MarketNotAssigned.selector);
	
	IInstrumentEngine(instrumentImpl).startReplication();
	// It should assign arbitraryInstrumentInitializer to instrument
	
	int24 initTickCalldata =
            SafeCastLib.toInt24(bound(int256(initTick), int256(MIN_TICK), int256(MAX_TICK)));
	ITick(instrumentImpl).set_tick(initTickCalldata);
	
	//   vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTokenIdParameter.selector, N), optionsClearingHouse);
	IInstrumentEngine(instrumentImpl).startReplication();
    }
}
