// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "@test/BaseTest.t.sol";
import {DifferentialTest} from "@test/DifferentialTest.sol";

import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";

import {ISemiFungiblePositionManager}
from "panoptic-v2-core/contracts/interfaces/ISemiFungiblePositionManager.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

import {
    IControllerSetter
} from "./NoFeeVarianceClaimBuilderTest.t.sol";

uint24 constant LOCKED_TICK_SPACING = 60;
uint256 constant LOCKED_WINDOW_LEN = 5;
uint160 constant DEFAULT_INIT_PRICE = Constants.SQRT_PRICE_1_1;
uint8 constant DEFAULT_VEGOID = 2;
uint256 constant CALL = 0;
uint256 constant SHORT = 0;

interface IPremiumReader {
    function assetPremiumTrackedOnOptionClearingHouseWithInstrument(address) external returns (uint128);
    function assetPremium(address) external returns(uint128);
}

interface IPremiumRateSetter {
    function setPremiumRate(uint24) external;
}

interface IPremiumRate {
    function readPremiumRate() external returns (uint24);
}

interface IInstrumentEngine {
    function startReplication() external;
}

contract PremiumTest is BaseTest, DifferentialTest {
    using PoolIdLibrary for PoolKey;

    // todo: This is to be replaced by sys
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");
    // todo: This is to be replaced by premiumController
    address noFeeVarianceClaimController;
 
    function setUp() public override {
	super.setUp();
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
	globalContext.target = alignTickHarness;

    }

    modifier AlignTickContext(Context memory ctx) {
	IEnv(ctx.io).setTickAligner(alignTickHarness);
	IControllerSetter(ctx.io).setController(noFeeVarianceClaimController);
	_;
    }

    modifier FixedTickSpacing(Context memory ctx){
	ITickSpacing(ctx.io).set_tick_spacing(LOCKED_TICK_SPACING);
	ctx.args.tickSpacing = LOCKED_TICK_SPACING;
	_;
    }

    modifier FixedWindowLen(Context memory ctx) {
	IWindow(ctx.io).set_window(LOCKED_WINDOW_LEN);
	ctx.args.windowLen = LOCKED_WINDOW_LEN;
	_;
    }


    function ForAllPremiumRatesOnReplicationStartedPremiumSensorTracksOptionClearingHouseRealizedPremium(Context memory ctx) external {
	  (uint128 optionClearingHouseReturnedPremium0, uint128 optionClearingHouseReturnedPremium1) = ISemiFungiblePositionManager(ctx.positionManager)
                .getAccountPremium(
				   abi.encode(ctx.marketKey),
                    ctx.io,
                    CALL,
                    ctx.args.lowerBound,
                    ctx.args.upperBound,
                    ctx.shock.newTick,
                    SHORT,
                    DEFAULT_VEGOID
                );


	  (,,, uint24 lpFee) = IStateView(ctx.poolManagerLens).getSlot0(ctx.marketKey.toId());
            assertEq(IPremiumRate(ctx.io).readPremiumRate(), lpFee);
	    

	    assertEq(IPremiumReader(ctx.io).assetPremiumTrackedOnOptionClearingHouseWithInstrument(Currency.unwrap(ctx.marketKey.currency0)),optionClearingHouseReturnedPremium0);
	    assertEq(IPremiumReader(ctx.io).assetPremiumTrackedOnOptionClearingHouseWithInstrument(Currency.unwrap(ctx.marketKey.currency1)),optionClearingHouseReturnedPremium1);
   }

    
    // Premium --> Instrument
    function test__fuzz__ForAllPremiumRatesOnReplicationStartedPremiumSensorTracksOptionClearingHouseRealizedPremium(FuzzInputsCommon memory args)
	external

	FullContext(globalContext)
	AlignTickContext(globalContext)
	FixedTickSpacing(globalContext)
	FixedWindowLen(globalContext)
    {
	Context memory ctx = globalContext;
	args.premiumRate = uint24(bound(args.premiumRate, 0, SwapMath.MAX_SWAP_FEE - 1));
	IPremiumRateSetter(ctx.io).setPremiumRate(args.premiumRate);
	args.premiumRate = IPremiumRate(ctx.io).readPremiumRate();
	args.tickSpacing = ITickSpacing(ctx.io).read_tick_spacing();
	ctx.marketKey.tickSpacing = int24(args.tickSpacing);
	ctx.marketKey.hooks =  IHooks(noFeeVarianceClaimController);
	ctx.marketKey.fee = args.premiumRate;
	ctx.marketKeyPeriphery.tickSpacing = int24(args.tickSpacing);
	ctx.marketKeyPeriphery.fee = args.premiumRate;
	ctx.marketKeyPeriphery.hooks = IHooksPeriphery(noFeeVarianceClaimController);
	
	int24 initTick = TickMath.getTickAtSqrtPrice(DEFAULT_INIT_PRICE);
        ITick(ctx.io).set_tick(initTick);
	
        IInstrumentEngine(ctx.io).startReplication();
	args.windowLen = LOCKED_WINDOW_LEN;
	args.windowIdx = 0;
	args.lowerBound = int24(-27060);
	args.upperBound = int24(27060);
	ctx.args = args;
        // Strike unset (=0). Width = NormAbsTick(usableMax, usableMin) % 4096
        //   = ((887220 - (-887220)) / 60) % 4096 = 29574 % 4096 = 902.
        // asTicks(0, 902, 60) → [-(902*60)/2, +ceil(902*60/2)] = [-27060, 27060].
        do {
	    ctx = shock(ctx);
            ITick(ctx.io).set_tick(ctx.shock.newTick);
	    test(
		 this.ForAllPremiumRatesOnReplicationStartedPremiumSensorTracksOptionClearingHouseRealizedPremium,
		 ctx
	    );
	    ctx.args.windowIdx++;
         } while (ctx.args.windowIdx < ctx.args.windowLen);

    }

    function ForAllPremiumRatesOnReplicationStartedPremiumControllerOnUtilizationEstimatorTracksOptionClearingHouseRealizedPremium(Context memory ctx) external {
	console2.log("Asset0PremiumOnInstrument: ",IPremiumReader(ctx.io).assetPremiumTrackedOnOptionClearingHouseWithInstrument(Currency.unwrap(ctx.marketKey.currency0)));
	console2.log("Asset1PremiumOnInstrument:", IPremiumReader(ctx.io).assetPremiumTrackedOnOptionClearingHouseWithInstrument(Currency.unwrap(ctx.marketKey.currency1)));
	console2.log("Asset0PremiumFromUtilization:", IPremiumReader(ctx.io).assetPremium(Currency.unwrap(ctx.marketKey.currency0)));
        console2.log("Asset1PremiumFromUtilization:", IPremiumReader(ctx.io).assetPremium(Currency.unwrap(ctx.marketKey.currency1)));
 /* 	    assertEq(IPremiumReader(premiumImpl).assetPremiumTrackedOnOptionClearingHouseWithInstrument(Currency.unwrap(marketKey.currency0)),IPremiumReader(premiumImpl).assetPremium(Currency.unwrap(marketKey.currency0))); */
	    
 /* assertEq(IPremiumReader(premiumImpl).assetPremiumTrackedOnOptionClearingHouseWithInstrument(Currency.unwrap(marketKey.currency1)),IPremiumReader(premiumImpl).assetPremium(Currency.unwrap(marketKey.currency1))); */   
    }
    
    function test__fuzz__ForAllPremiumRatesOnReplicationStartedPremiumControllerOnUtilizationEstimatorTracksOptionClearingHouseRealizedPremium(FuzzInputsCommon memory args)
	external
        FullContext(globalContext)
	AlignTickContext(globalContext)
	FixedTickSpacing(globalContext)
	FixedWindowLen(globalContext)
    {
	Context memory ctx = globalContext;
	args.premiumRate = uint24(bound(args.premiumRate, 0, SwapMath.MAX_SWAP_FEE - 1));
	IPremiumRateSetter(ctx.io).setPremiumRate(args.premiumRate);
	args.premiumRate = IPremiumRate(ctx.io).readPremiumRate();
	args.tickSpacing = ITickSpacing(ctx.io).read_tick_spacing();
	ctx.marketKey.tickSpacing = int24(args.tickSpacing);
	ctx.marketKey.hooks =  IHooks(noFeeVarianceClaimController);
	ctx.marketKey.fee = args.premiumRate;
	ctx.marketKeyPeriphery.tickSpacing = int24(args.tickSpacing);
	ctx.marketKeyPeriphery.fee = args.premiumRate;
	ctx.marketKeyPeriphery.hooks = IHooksPeriphery(noFeeVarianceClaimController);
	
	int24 initTick = TickMath.getTickAtSqrtPrice(DEFAULT_INIT_PRICE);
        ITick(ctx.io).set_tick(initTick);
	
        IInstrumentEngine(ctx.io).startReplication();
	args.windowLen = LOCKED_WINDOW_LEN;
	args.windowIdx = 0;
	args.lowerBound = int24(-27060);
	args.upperBound = int24(27060);
	ctx.args = args;
        // Strike unset (=0). Width = NormAbsTick(usableMax, usableMin) % 4096
        //   = ((887220 - (-887220)) / 60) % 4096 = 29574 % 4096 = 902.
        // asTicks(0, 902, 60) → [-(902*60)/2, +ceil(902*60/2)] = [-27060, 27060].
        do {
	    ctx = shock(ctx);
            ITick(ctx.io).set_tick(ctx.shock.newTick);
	    test(
		 this.ForAllPremiumRatesOnReplicationStartedPremiumControllerOnUtilizationEstimatorTracksOptionClearingHouseRealizedPremium,
		 ctx
	    );
	    ctx.args.windowIdx++;
         } while (ctx.args.windowIdx < ctx.args.windowLen);

    }
}
