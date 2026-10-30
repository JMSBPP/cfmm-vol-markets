/*****************************************************************************************************************************************************************/
/* SPDX-License-Identifier: UNLICENSED																 */
/* pragma solidity 0.8.26;																	 */
/* 																				 */
/* import {PlankTestBase} from "plank/PlankTestBase.sol";													 */
/* import {ITickSpacing} from "./TickSpacing.t.sol";														 */
/* import {IWindow} from "./Window.t.sol";															 */
/* import {MIN_TICK,MAX_TICK,ITick,normTickVal} from "./Tick.t.sol";												 */
/* import {ITickAverage} from "./TickAverage.t.sol";														 */
/* import {SafeCastLib} from "solady/utils/SafeCastLib.sol";													 */
/* 																				 */
/* 																				 */
/* 																				 */
/* cast keccak vol-markets.TickMoments.tickRealizedVolatility													 */
/* bytes32 constant TICK_REALIZED_VOLATILITY_SLOT = 0xf69e753063c9a37dc7169cc2d90bb6795545b8db9f6c22f3d499d73437f5553a;						 */
/* 																				 */
/* function tick2Delta (int24 tickAvg, int24 tickRef) pure returns(int48) {											 */
/*     return int48(int48(tickRef - tickAvg)*int48(tickRef - tickAvg));												 */
/* }																				 */
/* 																				 */
/* interface ITickRealizedVolatility {																 */
/*     function read_tick_realizedVolatility() external returns(uint88);											 */
/* }																				 */
/* 																				 */
/* 																				 */
/* contract TickRealizedVolatilityTest is PlankTestBase {													 */
/* 																				 */
/*     address main;																		 */
/* 																				 */
/*     function setUp() public {																 */
/* 	main = deployPlank("src/Main.plk");															 */
/* 	vm.makePersistent(main);																 */
/*     }																			 */
/* 																				 */
/*     modifier whenSetTickIsCalledWithTickCalldata() {														 */
/*         _;																			 */
/*     }																			 */
/* 																				 */
/*     function test_WhenTickAverageStateIsInitialized(														 */
/* 						          uint256 windowLen,											 */
/* 							  uint24 tickSpacing,											 */
/* 							  uint256 maxIdx											 */
/* 																				 */
/*     ) external whenSetTickIsCalledWithTickCalldata {														 */
/* 	==============================PRE-CONDITIONS ================================										 */
/* 	TODO: 200 is somewhat arbitrary and does not lead OOG													 */
/* 																				 */
/* 	uint256 windowLenCalldata = bound(windowLen, 1, 200);													 */
/* 	ITickSpacing(main).set_tick_spacing(tickSpacing);													 */
/* 	uint24 tickSpacingCalldata =  ITickSpacing(main).read_tick_spacing();											 */
/* 	IWindow(main).set_window(windowLenCalldata);														 */
/* 	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);													 */
/* 	uint256 windowIdx = 0;																	 */
/* 	int80 expectedPrevTick2Accum;																 */
/* 	do {																			 */
/* 	    int256 tickSeed = vm.randomInt();															 */
/* 	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));							 */
/* 	    ITick(main).set_tick(tickOnRun);															 */
/* 	    int24 stepTickAvg =  ITickAverage(main).read_tick_average();											 */
/* 	    int24 stepTick = ITick(main).read_tick();														 */
/* 	    It should set the prevTick2Acc to the tickCalldata squared delta with TickAvg.									 */
/* 	    expectedPrevTick2Accum += int80(tick2Delta(stepTickAvg,stepTick));											 */
/* 	    int80 storedPrevTick2Accum = SafeCastLib.toInt80(int256(uint256(vm.load(main, bytes32(uint256(TICK_REALIZED_VOLATILITY_SLOT) + 1)))));		 */
/* 	    assertEq(storedPrevTick2Accum,expectedPrevTick2Accum);												 */
/* 	   																			 */
/* 	    windowIdx++;																	 */
/* 																				 */
/* 	    uint88 storedStepTickRealizedVolatility = ITickRealizedVolatility(main).read_tick_realizedVolatility();						 */
/* 	    if (windowIdx == windowLenCalldata) {														 */
/* 		It should set the tickRealizedVol to prevTick2Acc over windowIdx										 */
/* 		uint88 expectedWindowTickRealizedVolatility = SafeCastLib.toUint88(uint256(int256(expectedPrevTick2Accum)/int256(windowLenCalldata)));		 */
/* 		assertEq(storedStepTickRealizedVolatility,expectedWindowTickRealizedVolatility);								 */
/* 	    } else {																		 */
/* 		uint88 expectedStepTickRealizedVolatility = SafeCastLib.toUint88(uint256(int256(expectedPrevTick2Accum)/int256(windowIdx)));			 */
/* 		assertEq(storedStepTickRealizedVolatility,expectedStepTickRealizedVolatility);									 */
/* 	    }																			 */
/* 	} while (windowIdx < maxIdxPick);															 */
/*     }																			 */
/* }																				 */
/*****************************************************************************************************************************************************************/

