// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PlankTestBase} from "plank/PlankTestBase.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {Constants} from "v4-core-test/utils/Constants.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";
import {ISemiFungiblePositionManager}
from "panoptic-v2-core/contracts/interfaces/ISemiFungiblePositionManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {console2} from "forge-std/console2.sol";

import {ITick} from "./Tick.t.sol";
import {ITickSpacing} from "./TickSpacing.t.sol";
import {IWindow} from "./Window.t.sol";
import {
    IEnv,
    IMarketBuilder,
    IMarketLens,
    IControllerSetter
} from "./NoFeeVarianceClaimBuilderTest.t.sol";

uint24 constant LOCKED_TICK_SPACING = 60;
uint256 constant LOCKED_WINDOW_LEN = 5;
uint160 constant DEFAULT_INIT_PRICE = Constants.SQRT_PRICE_1_1;
uint8 constant DEFAULT_VEGOID = 2;
uint256 constant CALL = 0;
uint256 constant SHORT = 0;

interface IPremiumRateSetter {
    function setPremiumRate(uint24) external;
}

interface IPremiumRateReader {
    function readPremiumRate() external returns (uint24);
}

interface IInstrumentEngine {
    function startReplication() external;
}

contract PremiumTest is PlankTestBase, Deployers, HookDeployer {
    using PoolIdLibrary for PoolKey;

    address premiumImpl = makeAddr("cfmm.vol-markets.premiumImpl");
    address optionsClearingHouse = makeAddr("cfmm.vol-markets.options-clearing-house");
    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire = makeAddr("cfmm.vol-markets.numeraire");
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");

    address noFeeVarianceClaimController;
    address poolManager;

    PoolKey marketKey;

    function setUp() public {
        deployFreshManager();
        poolManager = address(manager);

        address sfpm = SfpmBytecodeDeployer.deploy(
            vm, manager, 2100000000000000000000, 2100000000000000000000, 10000
        );
        vm.etch(optionsClearingHouse, sfpm.code);

        deployCodeTo(premiumImpl, compilePlank("src/Main.plk"));
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

        IEnv(alignTickHarness).setIO(premiumImpl);
        IEnv(premiumImpl).setTickAligner(alignTickHarness);
        IEnv(alignTickHarness).setPoolManager(poolManager);
        IEnv(premiumImpl).setPoolManager(poolManager);
        IEnv(alignTickHarness).setPositionManager(optionsClearingHouse);
        IEnv(premiumImpl).setPositionManager(optionsClearingHouse);
        IMarketBuilder(premiumImpl).setPair(underlying, numeraire, true);
        IControllerSetter(premiumImpl).setController(noFeeVarianceClaimController);

        ITickSpacing(premiumImpl).set_tick_spacing(LOCKED_TICK_SPACING);
        IWindow(premiumImpl).set_window(LOCKED_WINDOW_LEN);
    }

    function test__WhenStartReplication(uint24 premiumRate) external {
        uint24 someFixedPremiumRate = uint24(bound(premiumRate, 0, SwapMath.MAX_SWAP_FEE - 1));
        IPremiumRateSetter(premiumImpl).setPremiumRate(someFixedPremiumRate);

        int24 initTick = TickMath.getTickAtSqrtPrice(DEFAULT_INIT_PRICE);
        ITick(premiumImpl).set_tick(initTick);

        bytes memory underlyingMarket = IMarketLens(premiumImpl).getMarketKey();
        marketKey = abi.decode(underlyingMarket, (PoolKey));

        IInstrumentEngine(premiumImpl).startReplication();

        // Strike unset (=0). Width = NormAbsTick(usableMax, usableMin) % 4096
        //   = ((887220 - (-887220)) / 60) % 4096 = 29574 % 4096 = 902.
        // asTicks(0, 902, 60) → [-(902*60)/2, +ceil(902*60/2)] = [-27060, 27060].
        int24 lo = -27060;
        int24 hi = 27060;

        uint256 windowIdx = 0;
        do {
            int256 tickSeed = vm.randomInt();
            int24 nextTick =
                SafeCastLib.toInt24(bound(int256(tickSeed), int256(lo), int256(hi)));
            ITick(premiumImpl).set_tick(nextTick);

            (uint128 premium0, uint128 premium1) = ISemiFungiblePositionManager(optionsClearingHouse)
                .getAccountPremium(
                    underlyingMarket,
                    premiumImpl,
                    CALL,
                    lo,
                    hi,
                    nextTick,
                    SHORT,
                    DEFAULT_VEGOID
                );
            console2.log("windowIdx", windowIdx);
            console2.log("nextTick", int256(nextTick));
            console2.log("lo", int256(lo));
            console2.log("hi", int256(hi));
            console2.log("getAccountPremium SHORT CALL premium0", uint256(premium0));
            console2.log("getAccountPremium SHORT CALL premium1", uint256(premium1));

            windowIdx++;
        } while (windowIdx < LOCKED_WINDOW_LEN);

        assertEq(marketKey.tickSpacing, SafeCastLib.toInt24(uint256(LOCKED_TICK_SPACING)));
        assertEq(marketKey.fee, someFixedPremiumRate);
    }
}
