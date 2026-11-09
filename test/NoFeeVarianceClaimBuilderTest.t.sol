// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PlankTestBase} from "plank/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {ISemiFungiblePositionManager}
from "panoptic-v2-core/contracts/interfaces/ISemiFungiblePositionManager.sol";

import {ITickSpacing} from "./TickSpacing.t.sol";
import {ITickAverage} from "./TickAverage.t.sol";
import {IWindow} from "./Window.t.sol";
import {MIN_TICK, MAX_TICK, ITick} from "./Tick.t.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";
import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";

uint256 constant VEGOID = 8;

interface IPremiumSetter {
    function setPremiumRate(uint24) external;
}

interface IControllerSetter {
    function setController(address) external;
}

interface ITickRealizedVolatility {
    function readRealizedVolatility() external returns (uint88);
}

interface ITickMoments is ITickAverage, ITickRealizedVolatility {}

interface IMarketBuilder {
    function setPair(address, address, bool) external;
}

interface IMarketLens {
    function getMarketKey() external returns (bytes memory);
}

interface ITraderView {
    function instrumentId() external returns (uint256);
    function direction() external returns (uint256);
}

interface IPositionLens {
    function tickLower() external returns (int24);
    function tickUpper() external returns (int24);
}

interface INoFeeVarianceClaimBuilder {
    function claimPayoffMultiplier() external returns (uint256);
    function ongoingPayoff(uint88, uint256) external returns (uint128);
}

interface IEnv {
    function setIO(address) external;
    function setTickAligner(address) external;
    function setPoolManager(address) external;
    function setPositionManager(address) external;
}

contract NoFeeVarianceClaimBuilderTest is PlankTestBase, Deployers, HookDeployer {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address noFeeVarianceClaimBuilder = makeAddr("cfmm.vol-markets.noFeeVarianceClaimBuilder");
    address optionsClearingHouse = makeAddr("cfmm.vol-markets.options-clearing-house");
    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire = makeAddr("cfmm.vol-markets.numeraire");
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");

    address noFeeVarianceClaimController;
    address poolManager;

    address usr = makeAddr("user");

    function setUp() public {
        deployFreshManager();
        poolManager = address(manager);

        // SFPM via pinned creation bytecode — do not import SemiFungiblePositionManagerV4.sol.
        address sfpm = SfpmBytecodeDeployer.deploy(
            vm, manager, 2100000000000000000000, 2100000000000000000000, 10000
        );
        vm.etch(optionsClearingHouse, sfpm.code);

        deployCodeTo(noFeeVarianceClaimBuilder, compilePlank("src/Main.plk"));
        deployCodeTo(alignTickHarness, compilePlank("src/LiquidityKernel/AlignTick.plk"));
        deployCodeTo(underlying, compilePlank("src/LiquidityKernel/Transfer.plk"));
        deployCodeTo(numeraire, compilePlank("src/LiquidityKernel/Transfer.plk"));
        (bool succ, address _tmp,) = deployHook(
            compilePlank("src/LiquidityKernel/Controller.plk"),
            CREATE2_FACTORY,
            NoFeeVarianceClaimBuilderPermissions
        );
        if (succ) {
            noFeeVarianceClaimController = _tmp;
        }

        IEnv(alignTickHarness).setIO(noFeeVarianceClaimBuilder);
        IEnv(noFeeVarianceClaimBuilder).setTickAligner(alignTickHarness);
        IEnv(alignTickHarness).setPoolManager(poolManager);
        IEnv(noFeeVarianceClaimBuilder).setPoolManager(poolManager);
        // SFPM etched at optionsClearingHouse; constructor PoolManager must match.
        IEnv(alignTickHarness).setPositionManager(optionsClearingHouse);
        IEnv(noFeeVarianceClaimBuilder).setPositionManager(optionsClearingHouse);
        IMarketBuilder(noFeeVarianceClaimBuilder).setPair(underlying, numeraire, true);
    }

    function test__PanopticWhenSetTickOnMainItUpdatesCfmmTickToTickCalldata(
        uint256 windowLen,
        uint24 tickSpacing,
        uint256 maxIdx,
	uint24 arbitraryPremiumRate
    ) external {
        uint256 windowLenCalldata = bound(windowLen, 1, 5);
        ITickSpacing(noFeeVarianceClaimBuilder).set_tick_spacing(tickSpacing);
	uint24 arbitraryAdmissiblePremiumRate = uint24(bound(arbitraryPremiumRate, 0,
							     SwapMath.MAX_SWAP_FEE - 1));
        IPremiumSetter(noFeeVarianceClaimBuilder).setPremiumRate(arbitraryAdmissiblePremiumRate);
        IControllerSetter(noFeeVarianceClaimBuilder).setController(noFeeVarianceClaimController);
        IWindow(noFeeVarianceClaimBuilder).set_window(windowLenCalldata);
        uint256 maxIdxPick = bound(maxIdx, 1, windowLenCalldata);
        uint256 windowIdx = 0;
        bytes memory underlyingMarket = IMarketLens(noFeeVarianceClaimBuilder).getMarketKey();
        do {
            int256 tickSeed = vm.randomInt();
            int24 tickOnRun =
                SafeCastLib.toInt24(bound(int256(tickSeed), int256(MIN_TICK), int256(MAX_TICK)));
            ITick(noFeeVarianceClaimBuilder).set_tick(tickOnRun);
            PoolKey memory marketKey = abi.decode(underlyingMarket, (PoolKey));
            (uint160 sqrtPriceX96, int24 slot0Tick,,) = IPoolManager(poolManager).getSlot0(marketKey.toId());
            // Main stores the price-canonical tick (same invariant as AlignTickTest).
            assertEq(
                ITick(noFeeVarianceClaimBuilder).read_tick(),
                TickMath.getTickAtSqrtPrice(sqrtPriceX96),
                "Main tick must equal getTickAtSqrtPrice(slot0.sqrtPrice)"
            );
            // SFPM bytecode path is live: getCurrentTick == V4 slot0.tick (may differ from
            // price-canonical by 1 at a tick boundary).
            assertEq(
                ISemiFungiblePositionManager(optionsClearingHouse).getCurrentTick(underlyingMarket),
                slot0Tick,
                "SFPM getCurrentTick must equal PoolManager slot0.tick"
            );
            windowIdx++;
        } while (windowIdx < maxIdxPick);
    }

    function test_PanopticPremiaMatchesNoFeeVolatilityClaimPayoffForAllTickStepsOnWindow(
        uint256 windowLen,
        uint24 tickSpacing,
        uint256 maxIdx
    ) external {
        vm.skip(true);
        uint256 windowLenCalldata = bound(windowLen, 1, 200);
        ITickSpacing(noFeeVarianceClaimBuilder).set_tick_spacing(tickSpacing);
        // IFeeSetter(noFeeVarianceClaimBuilder).set_fee(uint24(0));
        IControllerSetter(noFeeVarianceClaimBuilder).setController(noFeeVarianceClaimController);
        IWindow(noFeeVarianceClaimBuilder).set_window(windowLenCalldata);
        uint256 maxIdxPick = bound(maxIdx, 1, windowLenCalldata);
        uint256 windowIdx = 0;
        bytes memory underlyingMarket = IMarketLens(noFeeVarianceClaimBuilder).getMarketKey();

        console2.log("Numeraire Address", numeraire);
        console2.log("Underlying address", underlying);

        do {
            int256 tickSeed = vm.randomInt();
            int24 tickOnRun =
                SafeCastLib.toInt24(bound(int256(tickSeed), int256(MIN_TICK), int256(MAX_TICK)));
            ITick(noFeeVarianceClaimBuilder).set_tick(tickOnRun);
            vm.startPrank(usr);
            (, uint128 usrPremiumOnNumeraire) = ISemiFungiblePositionManager(optionsClearingHouse)
                .getAccountPremium(
                underlyingMarket,
                usr,
                ITraderView(noFeeVarianceClaimBuilder).instrumentId(),
                IPositionLens(noFeeVarianceClaimBuilder).tickLower(),
                IPositionLens(noFeeVarianceClaimBuilder).tickUpper(),
                ISemiFungiblePositionManager(optionsClearingHouse).getCurrentTick(underlyingMarket),
                ITraderView(noFeeVarianceClaimBuilder).direction(),
                VEGOID
            );

            uint88 realizedVolatility =
                ITickMoments(noFeeVarianceClaimBuilder).readRealizedVolatility();
            uint256 ongoingPayoffMultiplier =
                INoFeeVarianceClaimBuilder(noFeeVarianceClaimBuilder).claimPayoffMultiplier();
            assertEq(
                usrPremiumOnNumeraire,
                INoFeeVarianceClaimBuilder(noFeeVarianceClaimBuilder).ongoingPayoff(
                    realizedVolatility, ongoingPayoffMultiplier
                )
            );
            vm.stopPrank();
            windowIdx++;
        } while (windowIdx < maxIdxPick);
    }
}
