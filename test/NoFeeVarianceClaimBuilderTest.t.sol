// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PlankTestBase} from "plank/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {CreateLegHarness} from "../src/CreateLegHarness.sol";
import {LeftRightSigned, LeftRightUnsigned} from "panoptic-v2-core/contracts/types/LeftRight.sol";
import {SemiFungiblePositionManagerV4} from "panoptic-v2-core/contracts/SemiFungiblePositionManagerV4.sol";
import {ISemiFungiblePositionManager}
from "panoptic-v2-core/contracts/interfaces/ISemiFungiblePositionManager.sol";

import {ITickSpacing} from "./TickSpacing.t.sol";
import {ITickAverage} from "./TickAverage.t.sol";
import {IWindow} from "./Window.t.sol";
import {MIN_TICK,MAX_TICK,ITick,normTickVal} from "./Tick.t.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

uint256 constant VEGOID = 8;


interface ITickRealizedVolatility {
    function readRealizedVolatility() external returns(uint88);
}

interface ITickMoments is ITickAverage, ITickRealizedVolatility{}

interface IMarketLens {

    function getMarketKey() external returns(bytes memory);
}

interface ITraderView {
    function instrumentId() external returns(uint256);
    function direction() external returns(uint256);
}

interface IPositionLens {
    function tickLower() external returns(int24);
    function tickUpper() external returns(int24);
}

interface INoFeeVarianceClaimBuilder {
    function claimPayoffMultiplier() external returns(uint256);
    function ongoingPayoff(uint88,uint256) external returns(uint128);
}

contract NoFeeVarianceClaimBuilderTest is PlankTestBase, Deployers {
    address noFeeVarianceClaimBuilder =  makeAddr("cfmm.vol-markets.noFeeVarianceClaimBuilder");
    address optionsClearingHouse = makeAddr("options-clearing-house");
    address usr = makeAddr("user");
    
    function setUp() public {
        deployFreshManager();
	vm.etch(optionsClearingHouse,
		abi.encodePacked(vm.getCode("panoptic-v2-core/contracts/SemiFungiblePositionManagerV4.sol"),manager, uint256(2100000000000000000000), uint256(2100000000000000000000), uint256(10000)));
	vm.etch(noFeeVarianceClaimBuilder, plankBuildFFI("src/Main.plk", plankOpts()));
	
    }

    function test_PanopticPremiaMatchesNoFeeVolatilityClaimPayoffForAllTickStepsOnWindow(
	        uint256 windowLen,
							  uint24 tickSpacing,
							  uint256 maxIdx

    ) external {
	uint256 windowLenCalldata = bound(windowLen, 1, 200);
	ITickSpacing(noFeeVarianceClaimBuilder).set_tick_spacing(tickSpacing);
        IWindow(noFeeVarianceClaimBuilder).set_window(windowLenCalldata);
	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
	uint256 windowIdx = 0;
	bytes memory underlyingMarket = IMarketLens(noFeeVarianceClaimBuilder).getMarketKey();
	do {
	    vm.startPrank(usr);
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));
	    ITick(noFeeVarianceClaimBuilder).set_tick(tickOnRun);
	  
	    (,uint128 usrPremiumOnNumeraire) = ISemiFungiblePositionManager(optionsClearingHouse).getAccountPremium(
	        underlyingMarket,
	        usr,
	        ITraderView(noFeeVarianceClaimBuilder).instrumentId(),
	        IPositionLens(noFeeVarianceClaimBuilder).tickLower(),
	        IPositionLens(noFeeVarianceClaimBuilder).tickUpper(),
		ISemiFungiblePositionManager(optionsClearingHouse).getCurrentTick(underlyingMarket),			  ITraderView(noFeeVarianceClaimBuilder).direction(),
	        VEGOID
	    );

	    uint88 realizedVolatility = ITickMoments(noFeeVarianceClaimBuilder).readRealizedVolatility();
	    uint256 ongoingPayoffMultiplier = INoFeeVarianceClaimBuilder(noFeeVarianceClaimBuilder).claimPayoffMultiplier();
	    assertEq(usrPremiumOnNumeraire,INoFeeVarianceClaimBuilder(noFeeVarianceClaimBuilder).ongoingPayoff(realizedVolatility, ongoingPayoffMultiplier));
	    vm.stopPrank();
        } while (windowIdx < maxIdxPick);
	    
    }
}
