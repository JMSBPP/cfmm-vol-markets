// SPDX-License-Identifier: MIT
// ^0.8.24: joins the v4-core (0.8.26 exact) + SFPM (^0.8.24) compilation graph. Do NOT import
// the @cryptoalgebra refs here (they pin =0.8.20 and cannot share this graph).
pragma solidity ^0.8.24;

import {PlankTestBase} from "../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

import {PoolManager} from "univ4-core/PoolManager.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

import {TokenId} from "@types/TokenId.sol";
import {V4StateReader} from "@libraries/V4StateReader.sol";
import {V4RouterSimple} from "panoptic-v2-core/test/foundry/testUtils/V4RouterSimple.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

// The SFPM is NOT imported as source: it only compiles under legacy codegen, so it is built
// in its own compilation unit (see foundry.toml compilation_restrictions + the
// e2e_legacy/SFPMLegacyAnchor.sol artifact anchor) and deployCode()'d here. This interface
// is ABI-equivalent (user-defined value types TokenId/LeftRight* are ABI-transparent).
interface ISFPM {
    function initializeAMMPool(PoolKey calldata key, uint8 vegoid) external returns (uint64 poolId);
    function mintTokenizedPosition(
        bytes calldata poolKey,
        uint256 tokenId,
        uint128 positionSize,
        int24 tickLimitLow,
        int24 tickLimitHigh
    ) external returns (uint256[4] memory, int256, int24);
    function getAccountPremium(
        bytes calldata poolKey,
        address owner,
        uint256 tokenType,
        int24 tickLower,
        int24 tickUpper,
        int24 atTick,
        uint256 isLong,
        uint256 vegoid
    ) external view returns (uint128, uint128);
}

// ===========================================================================================
// Task #16 GOAL increment (dynamic-fee-hook-SPEC.md section 7.6) -- the vol->fee->premium E2E
// the Reality Checker REQUIRED: prove the hook CONTROLS Panoptic premia.
//
// Full REAL stack, no mocks on the money path:
//   REAL v4 PoolManager x2 DYNAMIC_FEE pools -> the Plank DynamicFeeHook vm.etch'd at
//   BEFORE_SWAP_FLAG(1<<7) addresses -> REAL SemiFungiblePositionManagerV4 -> a short
//   (premium-selling) position whose liquidity chunk straddles the current tick.
//
// Two pools, IDENTICAL except the hook's fee config:
//   LOW  = {alphas 0, baseFee 100}          -> constant   100 pips (the alphas-disabled
//                                              short-circuit: vol-INsensitive control pool)
//   HIGH = {alpha1 30000, alpha2 20000, ...} -> vol-driven ~50k pips under the same corpus
// Equal swap volume (same amounts, same timestamps, same directions) is pushed through both;
// the SFPM premium accumulator of the identical position MUST be strictly higher in the
// HIGH pool -- premia ARE the pool swap fees x the position-side multiplier (SFPM V4
// _getPremiaDeltas, verified in spec section 0), so the vol-driven fee override is the lever.
//
// The position is minted through the SAME SFPM path a full LDF-shaped (xi*, iota) portfolio
// uses; task #14's Layer-2 sizing adds the 4-leg weighting on top of exactly this rail --
// the premium-control assertion is leg-shape-independent.
//
// DE-HEDGES: (i) the E5 FeeApplied pair of the final swap proves the fee levels actually
// diverged (feeHigh > feeLow) -- the premium gap is attributed, not assumed; (ii) mutation:
// swapping the two configs must FLIP the premium inequality (run recorded in the file
// history); (iii) the LOW pool's premium must itself be nonzero -- the position genuinely
// accrues, the comparison is between two live premium streams, not against a dead pool.
// ===========================================================================================
contract DynamicFeeHookE2ETest is PlankTestBase {
    using PoolIdLibrary for PoolKey;

    bytes32 internal constant TOPIC0_FEE_APPLIED =
        0x25ea110aac3c0d92bd950f999d2fafed41a751afe912d690a3e721a6eb5a84df;
    bytes4 internal constant SEL_INITIALIZE_HOOK = 0xf8a75ae6;
    uint24 internal constant DYNAMIC_FEE_FLAG = 0x800000;

    // BEFORE_SWAP_FLAG = 1 << 7 is the ONLY flag bit set (ALL_HOOK_MASK = 14 bits); the
    // upper address bits differ so the two hooks are distinct deployments.
    address internal constant HOOK_LOW = address(uint160(0x4444000000000000000000000000000000000080));
    address internal constant HOOK_HIGH = address(uint160(0x8888000000000000000000000000000000000080));

    uint8 internal constant VEGOID = 8;
    int24 internal constant TS = 10; // tickSpacing
    int24 internal constant STRIKE = 0;
    int24 internal constant WIDTH = 2; // chunk = strike +/- (WIDTH*TS)/2 = [-10, +10]
    int24 internal constant CHUNK_LOWER = -10;
    int24 internal constant CHUNK_UPPER = 10;
    uint128 internal constant POS_SIZE = 1e15;

    uint32 internal constant T0 = 1_000_000;

    PoolManager internal manager;
    V4RouterSimple internal router;
    ISFPM internal sfpm;
    MockERC20 internal tokenA;
    MockERC20 internal tokenB;

    PoolKey internal keyLow;
    PoolKey internal keyHigh;
    uint64 internal sfpmPoolIdLow;
    uint64 internal sfpmPoolIdHigh;
    TokenId internal tokenIdLow;
    TokenId internal tokenIdHigh;

    address internal Alice = address(0xA11CE); // the premium seller
    address internal Swapper = address(0x5A55); // pushes the volume

    function setUp() public {
        vm.warp(T0);
        manager = new PoolManager(address(this));
        router = new V4RouterSimple(IPoolManager(address(manager)));
        // the vendored harness's parameters (1e13, 1e13, 0), deployed from the
        // legacy-codegen artifact (see the import-site note). The artifact JSON is read
        // directly because vm.getCode/deployCode only consult the CURRENT run's artifact
        // registry, which sparse test compilation starves of the e2e_legacy anchor's output.
        // Prerequisite: `forge build` has produced out/SemiFungiblePositionManagerV4.sol/
        // (any full build does; the anchor forces it).
        bytes memory creation = bytes.concat(
            vm.parseJsonBytes(
                vm.readFile("out/SemiFungiblePositionManagerV4.sol/SemiFungiblePositionManagerV4.json"),
                ".bytecode.object"
            ),
            abi.encode(address(manager), uint256(1e13), uint256(1e13), uint256(0))
        );
        address sfpmAddr;
        assembly {
            sfpmAddr := create(0, add(creation, 32), mload(creation))
        }
        require(sfpmAddr != address(0), "SFPM deploy failed");
        sfpm = ISFPM(sfpmAddr);

        MockERC20 x = new MockERC20("T0", "T0", 18);
        MockERC20 y = new MockERC20("T1", "T1", 18);
        (tokenA, tokenB) = address(x) < address(y) ? (x, y) : (y, x);

        // the SAME Plank hook bytecode at both flagged addresses
        address plankHook = deployPlank("src/modules/protocol_integrations/DynamicFeeHook.plk");
        vm.etch(HOOK_LOW, plankHook.code);
        vm.etch(HOOK_HIGH, plankHook.code);

        keyLow = PoolKey(
            Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)), DYNAMIC_FEE_FLAG, TS, IHooks(HOOK_LOW)
        );
        keyHigh = PoolKey(
            Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)), DYNAMIC_FEE_FLAG, TS, IHooks(HOOK_HIGH)
        );

        // LOW: vol-INsensitive (alphas 0 -> constant baseFee 100). HIGH: vol-driven, steep
        // sigmoids saturating well above baseFee. Both valid per validate_fee_configuration
        // (alpha1+alpha2+baseFee <= 65535, gammas >= 1).
        _initHook(HOOK_LOW, keyLow, 0, 0, 360, 60000, 60, 500, 100);
        _initHook(HOOK_HIGH, keyHigh, 30000, 20000, 360, 60000, 60, 500, 100);

        manager.initialize(keyLow, uint160(1) << 96); // sqrtPrice 1:1, tick 0
        manager.initialize(keyHigh, uint160(1) << 96);

        // token supply + approvals: the test provides ambient liquidity; Alice mints the
        // option; Swapper pushes volume. Router + SFPM both settle via transferFrom.
        _fund(address(this));
        _fund(Alice);
        _fund(Swapper);

        // ambient depth around tick 0 so swaps do not exhaust the option chunk
        router.modifyLiquidity(address(this), keyLow, -TS * 1000, TS * 1000, 1e21);
        router.modifyLiquidity(address(this), keyHigh, -TS * 1000, TS * 1000, 1e21);

        sfpmPoolIdLow = sfpm.initializeAMMPool(keyLow, VEGOID);
        sfpmPoolIdHigh = sfpm.initializeAMMPool(keyHigh, VEGOID);

        // the identical short (premium-selling) leg in both pools: 1 contract-leg,
        // optionRatio 1, asset 0, isLong 0 (SELL), tokenType 0, riskPartner self,
        // chunk [-10, +10] straddling the current tick -> in-range, accrues swap fees.
        tokenIdLow = TokenId.wrap(0).addPoolId(sfpmPoolIdLow).addLeg(0, 1, 0, 0, 0, 0, STRIKE, WIDTH);
        tokenIdHigh = TokenId.wrap(0).addPoolId(sfpmPoolIdHigh).addLeg(0, 1, 0, 0, 0, 0, STRIKE, WIDTH);

        vm.startPrank(Alice);
        sfpm.mintTokenizedPosition(
            abi.encode(keyLow), TokenId.unwrap(tokenIdLow), POS_SIZE, TickMath.MIN_TICK, TickMath.MAX_TICK
        );
        sfpm.mintTokenizedPosition(
            abi.encode(keyHigh), TokenId.unwrap(tokenIdHigh), POS_SIZE, TickMath.MIN_TICK, TickMath.MAX_TICK
        );
        vm.stopPrank();
    }

    function _initHook(
        address hook,
        PoolKey memory k,
        uint16 a1,
        uint16 a2,
        uint32 b1,
        uint32 b2,
        uint16 g1,
        uint16 g2,
        uint16 bf
    ) internal {
        (bool ok,) = hook.call(
            abi.encodeWithSelector(
                SEL_INITIALIZE_HOOK,
                address(manager),
                PoolId.unwrap(k.toId()),
                a1, a2, b1, b2, g1, g2, bf, // the config struct: 7 static words inlined
                int24(0),
                uint32(block.timestamp)
            )
        );
        require(ok, "initializeHook failed");
    }

    function _fund(address who) internal {
        tokenA.mint(who, 1e27);
        tokenB.mint(who, 1e27);
        vm.startPrank(who);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        // The SFPM settles in ERC6909 CLAIM tokens: it burns claims from the minter for the
        // tokens owed. Pre-mint claims (router pulls the ERC20s into the manager) and let
        // the SFPM operate the account -- the vendored SFPM tests' own funding pattern.
        router.mintCurrency(who, Currency.wrap(address(tokenA)), 1e24);
        router.mintCurrency(who, Currency.wrap(address(tokenB)), 1e24);
        manager.setOperator(address(sfpm), true);
        vm.stopPrank();
    }

    /// @dev EQUAL swap volume through both pools: same amount, same direction, same block.
    function _swapBoth(int256 amountIn, bool zeroForOne) internal {
        vm.startPrank(Swapper);
        router.swap(Swapper, keyLow, amountIn, zeroForOne);
        router.swap(Swapper, keyHigh, amountIn, zeroForOne);
        vm.stopPrank();
    }

    function _premia(PoolKey memory k, TokenId, /*id*/ uint64 /*pid*/ ) internal view returns (uint128 p0, uint128 p1) {
        int24 atTick = V4StateReader.getTick(IPoolManager(address(manager)), k.toId());
        (p0, p1) = sfpm.getAccountPremium(abi.encode(k), Alice, 0, CHUNK_LOWER, CHUNK_UPPER, atTick, 0, VEGOID);
    }

    function _filterFee(Vm.Log[] memory logs) internal pure returns (uint256[] memory fees) {
        uint256 n;
        for (uint256 i = 0; i < logs.length; i++) if (logs[i].topics[0] == TOPIC0_FEE_APPLIED) n++;
        fees = new uint256[](n);
        uint256 j;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TOPIC0_FEE_APPLIED) {
                (, uint24 fee) = abi.decode(logs[i].data, (uint88, uint24));
                fees[j++] = fee;
            }
        }
    }

    // THE GOAL: equal volume, vol-driven fee vs flat low fee -> strictly higher premium
    // accumulator for the identical short position under the adaptive (HIGH) hook.
    function test__goal__premiumHigherUnderVolDrivenFee() public {
        // an oscillating corpus: price whipsaws around tick 0, realized vol builds in both
        // hook buffers identically (same swaps, same clocks)
        int256 amt = 2e18;
        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + 600);
            _swapBoth(amt, i % 2 == 0);
        }

        // final swap pair instrumented: the fee levels must have actually diverged (the
        // attribution de-hedge -- the premium gap is caused by the fee, not asserted blind)
        vm.warp(block.timestamp + 600);
        vm.recordLogs();
        _swapBoth(amt, true);
        uint256[] memory fees = _filterFee(vm.getRecordedLogs());
        assertEq(fees.length, 2, "one E5 per pool on the final pair");
        uint256 feeLow = fees[0];
        uint256 feeHigh = fees[1];
        assertGt(feeHigh, feeLow, "the HIGH config's vol-driven fee exceeds the LOW flat fee");

        (uint128 low0, uint128 low1) = _premia(keyLow, tokenIdLow, sfpmPoolIdLow);
        (uint128 high0, uint128 high1) = _premia(keyHigh, tokenIdHigh, sfpmPoolIdHigh);

        // the LOW pool is alive (fees at 100 pips still accrue) -- this is a comparison of
        // two live premium streams, not a live-vs-dead tautology
        assertGt(uint256(low0) + uint256(low1), 0, "control pool accrues nonzero premium");

        // THE claim of todo.md: the tokenId minted from a volOrder acquires premia
        // CONTROLLED by the adaptive fee.
        assertGt(uint256(high0), uint256(low0), "premium0: vol-driven fee > flat fee, equal volume");
        assertGt(uint256(high1), uint256(low1), "premium1: vol-driven fee > flat fee, equal volume");
    }

    // Volume-degenerate control: with NO swaps, both premia are zero -- the accumulator
    // measures fee flow, not time. (Guards against a premium source unrelated to swaps.)
    function test__unit__noSwapsNoPremium() public view {
        (uint128 low0, uint128 low1) = _premia(keyLow, tokenIdLow, sfpmPoolIdLow);
        (uint128 high0, uint128 high1) = _premia(keyHigh, tokenIdHigh, sfpmPoolIdHigh);
        assertEq(uint256(low0) + uint256(low1) + uint256(high0) + uint256(high1), 0, "no volume, no premium");
    }
}
