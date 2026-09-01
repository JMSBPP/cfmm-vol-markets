// SPDX-License-Identifier: MIT
// ^0.8.0: the vendored Algebra config libs pin =0.8.20 (project convention).
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";
import {AlgebraFeeConfiguration} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfiguration.sol";
import {DynamicFeePluginImplementation} from "../lib/fee_volatility/refs/DynamicFeePluginImplementation.sol";
import {MarketStatisticsAlgebraRef} from "../MarketStatisticsTest.t.sol";
import {VolatilityOraclePluginImplementation} from
    "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";

// ===========================================================================================
// Task #16: DynamicFeeHook -- v4 beforeSwap dynamic-fee (premium) hook.
// Spec: .planning/dynamic-fee-hook-SPEC.md (v2 + resume plan). Locked decisions: co-located
// vol buffer + fee config; LDF params do NOT enter the fee; RESEARCH-ONLY, no owner gate
// (one-shot init, MUST NOT back a live pool); HARD one-pool-per-hook (NEW-5 resolution) --
// the poolId is bound at initializeHook and beforeSwap requires the key to hash to it.
//
// beforeSwap(sender, key, params, hookData) -> (bytes4, BeforeSwapDelta ZERO, uint24 fee):
//   caller==poolManager -> poolId=keccak(key)==bound -> tick=extsload slot0 ->
//   write own buffer (B1: same-block write is a NO-HALT no-op) -> vol=getAverageVolatility
//   -> fee=get_fee(vol,cfg) -> emit E5 FeeApplied(poolId, vol, fee) -> fee|0x400000, 96 bytes.
//
// ORACLES: the fee is diffed against the REAL vendored Algebra plugin
// (DynamicFeePluginImplementation.getCurrentFee) and the vol against the REAL Algebra
// vol-oracle ref (MarketStatisticsAlgebraRef.getAverageVolatilityLast), both fed the same
// corpus -- the hook's full chain is pinned to Algebra behavior, tolerance 0.
//
// MUTANTS killed (stated per test):
//   read-only hook (no write in beforeSwap)      -> vol/fee constant: adaptivity + diff tests
//   @evm_return-style same-block halt (B1)       -> sameBlockSecondSwapReturns96Bytes
//   wrong slot0 tick decode (no signextend)      -> negative-tick E3 assertions
//   dirty fee word (flag lost / high bytes)      -> byte-exact 96-byte return asserts
//   missing E5 / wrong E5 fields                 -> feeAppliedEmitted
//   guard drops (caller / pool binding / uninit) -> the guard tests
// ===========================================================================================

struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
}

contract MockPoolManager {
    mapping(bytes32 => bytes32) internal store;

    // StateLibrary: stateSlot = keccak256(abi.encodePacked(poolId, bytes32(POOLS_SLOT=6)));
    // Slot0 packs sqrtPriceX96 at [0,160) and the int24 tick at [160,184).
    function setSlot0(bytes32 poolId, uint160 sqrtP, int24 tick) external {
        bytes32 stateSlot = keccak256(abi.encodePacked(poolId, bytes32(uint256(6))));
        store[stateSlot] = bytes32((uint256(uint24(tick)) << 160) | uint256(sqrtP));
    }

    function extsload(bytes32 slot) external view returns (bytes32) {
        return store[slot];
    }
}

contract DynamicFeeHookTest is PlankTestBase {
    event FeeApplied(bytes32 indexed poolId, uint88 sigma, uint24 fee);
    event TimepointWritten(
        bytes32 indexed poolId,
        uint32 timestamp,
        int24 tick,
        uint88 volatilityCumulative,
        int24 averageTick,
        int56 tickCumulative
    );

    bytes32 internal constant TOPIC0_FEE_APPLIED =
        0x25ea110aac3c0d92bd950f999d2fafed41a751afe912d690a3e721a6eb5a84df;
    bytes32 internal constant TOPIC0_TIMEPOINT_WRITTEN =
        0x44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415;

    bytes4 internal constant SEL_BEFORE_SWAP = 0x575e24b4;
    bytes4 internal constant SEL_INITIALIZE_HOOK = 0xf8a75ae6; // initializeHook(address,bytes32,(uint16,uint16,uint32,uint32,uint16,uint16,uint16),int24,uint32)
    bytes4 internal constant SEL_GET_AVG_VOL = 0x8171455c; // getAverageVolatility(int24,uint32)
    bytes4 internal constant SEL_POOL_MANAGER = 0xdc4c90d3;
    bytes4 internal constant SEL_POOL_ID = 0x3e0dc34e;
    uint256 internal constant OVERRIDE_FEE_FLAG = 0x400000;

    address internal hook;
    MockPoolManager internal pm;
    DynamicFeePluginImplementation internal feeOracle; // vendored Algebra plugin (fee reference)
    MarketStatisticsAlgebraRef internal volRef; // real Algebra vol oracle (vol reference)

    PoolKey internal key;
    bytes32 internal poolIdBound;

    uint32 internal constant T0 = 1_000_000;
    int24 internal constant TICK0 = 100;

    AlgebraFeeConfiguration internal CFG =
        AlgebraFeeConfiguration({alpha1: 2900, alpha2: 12000, beta1: 360, beta2: 60000, gamma1: 59, gamma2: 8500, baseFee: 100});

    function setUp() public {
        hook = deployPlank("src/modules/protocol_integrations/DynamicFeeHook.plk");
        pm = new MockPoolManager();
        feeOracle = new DynamicFeePluginImplementation();
        feeOracle.initializeDynamicFee(CFG);
        volRef = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());

        key = PoolKey({currency0: address(0xA), currency1: address(0xB), fee: 0x800000, tickSpacing: 60, hooks: hook});
        poolIdBound = keccak256(abi.encode(key));
    }

    // ------------------------------------------------------------------ helpers

    function _init() internal {
        (bool ok,) = hook.call(
            abi.encodeWithSelector(SEL_INITIALIZE_HOOK, address(pm), poolIdBound, CFG, TICK0, T0)
        );
        assertTrue(ok, "initializeHook succeeds");
        volRef.initializeTWAP(T0, TICK0);
    }

    function _beforeSwapCalldata(PoolKey memory k) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            SEL_BEFORE_SWAP, address(this), k, SwapParams({zeroForOne: true, amountSpecified: 1e18, sqrtPriceLimitX96: 0}), bytes("")
        );
    }

    /// @dev One "swap": warp to ts, point the mock pool at `tick`, call beforeSwap AS the
    ///      PoolManager, mirror the write into the Algebra vol reference.
    function _swap(uint32 ts, int24 tick) internal returns (bytes memory ret) {
        vm.warp(ts);
        pm.setSlot0(poolIdBound, uint160(1) << 96, tick);
        vm.prank(address(pm));
        (bool ok, bytes memory r) = hook.call(_beforeSwapCalldata(key));
        assertTrue(ok, "beforeSwap succeeds");
        volRef.writeTimepoint(ts, tick);
        return r;
    }

    function _hookVol(int24 tick, uint32 ts) internal view returns (uint256) {
        (bool ok, bytes memory r) = hook.staticcall(abi.encodeWithSelector(SEL_GET_AVG_VOL, tick, ts));
        require(ok, "getAverageVolatility reverted");
        return abi.decode(r, (uint256));
    }

    function _word(bytes memory b, uint256 i) internal pure returns (uint256 w) {
        assembly { w := mload(add(add(b, 32), mul(i, 32))) }
    }

    function _filter(Vm.Log[] memory logs, bytes32 topic0) internal pure returns (Vm.Log[] memory out) {
        uint256 n;
        for (uint256 i = 0; i < logs.length; i++) if (logs[i].topics[0] == topic0) n++;
        out = new Vm.Log[](n);
        uint256 j;
        for (uint256 i = 0; i < logs.length; i++) if (logs[i].topics[0] == topic0) out[j++] = logs[i];
    }

    // ------------------------------------------------------------------ init + bindings

    event FeeConfigurationChanged(
        bytes32 indexed poolId,
        uint16 alpha1,
        uint16 alpha2,
        uint32 beta1,
        uint32 beta2,
        uint16 gamma1,
        uint16 gamma2,
        uint16 baseFee
    );

    function test__unit__initializeHookStoresBindingsAndIsOneShot() public {
        // the hook is the POOL-KEYED Theta_phi emitter (data contract D2): its E4 carries the
        // REAL bound poolId, unlike the module's permanent 0 sentinel.
        vm.expectEmit(true, true, true, true, hook);
        emit FeeConfigurationChanged(
            poolIdBound, CFG.alpha1, CFG.alpha2, CFG.beta1, CFG.beta2, CFG.gamma1, CFG.gamma2, CFG.baseFee
        );
        _init();
        (bool ok, bytes memory r) = hook.staticcall(abi.encodeWithSelector(SEL_POOL_MANAGER));
        assertTrue(ok, "poolManager()");
        assertEq(abi.decode(r, (address)), address(pm), "poolManager bound");
        (ok, r) = hook.staticcall(abi.encodeWithSelector(SEL_POOL_ID));
        assertTrue(ok, "poolId()");
        assertEq(abi.decode(r, (bytes32)), poolIdBound, "poolId bound");

        // one-shot: a second initializeHook reverts (research-only front-run surface is
        // accepted per spec; the invariant is no RE-initialization).
        (ok,) = hook.call(abi.encodeWithSelector(SEL_INITIALIZE_HOOK, address(pm), poolIdBound, CFG, TICK0, T0));
        assertFalse(ok, "double init reverts");
    }

    // ------------------------------------------------------------------ the fee composition

    // Return = (beforeSwap.selector, ZERO delta, plugin_fee | OVERRIDE_FEE_FLAG), EXACTLY 96
    // bytes, all three words byte-clean. Fee reference = the REAL Algebra plugin at the
    // hook's own vol. Kills: dirty fee word, missing flag, wrong selector alignment.
    function test__diff__beforeSwapFeeMatchesAlgebraPlugin() public {
        _init();
        _swap(T0 + 600, 500);
        _swap(T0 + 1200, -300);

        uint32 ts = T0 + 1800;
        int24 tick = 900;
        bytes memory ret = _swap(ts, tick);

        assertEq(ret.length, 96, "exactly 96 bytes");
        assertEq(bytes4(uint32(_word(ret, 0) >> 224)), SEL_BEFORE_SWAP, "word0 = beforeSwap.selector left-aligned");
        assertEq(_word(ret, 0) & ((1 << 224) - 1), 0, "word0 low 28 bytes clean");
        assertEq(_word(ret, 1), 0, "word1 = ZERO BeforeSwapDelta");

        // the vol the hook consumed for THIS swap (post-write, at (tick, ts))
        uint256 vol = _hookVol(tick, ts);
        uint256 expectedFee = uint256(feeOracle.getCurrentFee(uint88(vol)));
        assertEq(_word(ret, 2), expectedFee | OVERRIDE_FEE_FLAG, "word2 = plugin fee | OVERRIDE_FEE_FLAG");
        assertLt(_word(ret, 2), 1 << 24, "word2 high 29 bytes clean (uint24 + flag only)");
    }

    // The hook's vol == the REAL Algebra vol oracle over the same corpus, tolerance 0.
    // Kills: read-only hook (vol frozen at seed), wrong buffer binding, wrong clock.
    function test__diff__hookVolMatchesAlgebraRef() public {
        _init();
        int24[5] memory ticks = [int24(500), int24(-1200), int24(2000), int24(-800), int24(1500)];
        uint32 t = T0;
        for (uint256 i = 0; i < 5; i++) {
            t += 900;
            _swap(t, ticks[i]);
        }
        uint32 nowTs = t + 7;
        int24 nowTick = 1234;
        assertEq(
            _hookVol(nowTick, nowTs),
            uint256(volRef.getAverageVolatilityLast(nowTick, nowTs)),
            "hook vol == Algebra vol, tolerance 0"
        );
    }

    // DE-HEDGED adaptivity (resume plan): the fee tracks the regime DIRECTION. A violent
    // corpus then a long calm stretch: fee(high-var regime) > fee(calm regime). Kills the
    // read-only mutant AND any monotone-ratchet reader.
    function test__unit__feeTracksRegimeDirection() public {
        _init();
        // violent regime: big tick jumps, short dts
        uint32 t = T0;
        int24[6] memory wild = [int24(4000), int24(-4000), int24(3500), int24(-3500), int24(3000), int24(-3000)];
        bytes memory retHigh;
        for (uint256 i = 0; i < 6; i++) {
            t += 300;
            retHigh = _swap(t, wild[i]);
        }
        uint256 feeHigh = _word(retHigh, 2) ^ OVERRIDE_FEE_FLAG;

        // calm regime: constant tick, long stretch (window flushes the variance out)
        bytes memory retLow;
        for (uint256 i = 0; i < 8; i++) {
            t += 21600; // 6h steps: > WINDOW after 4 steps
            retLow = _swap(t, 0);
        }
        uint256 feeLow = _word(retLow, 2) ^ OVERRIDE_FEE_FLAG;

        assertLt(feeLow, feeHigh, "fee falls when the vol regime calms (adaptive, not a ratchet)");
    }

    // ------------------------------------------------------------------ B1

    // A second swap in the SAME block must still return the full 96-byte tuple (the old
    // module write path @evm_return-halted the frame -> 32 zero-bytes; SFPM swapInAMM does
    // >1 swap/block). Also: the no-transition write emits NO second E3.
    function test__unit__sameBlockSecondSwapReturns96Bytes() public {
        _init();
        _swap(T0 + 600, 500);

        vm.recordLogs();
        bytes memory ret = _swap(T0 + 600, 700); // same timestamp: buffer no-op, fee still served
        assertEq(ret.length, 96, "B1: same-block second swap returns the full tuple");
        assertEq(bytes4(uint32(_word(ret, 0) >> 224)), SEL_BEFORE_SWAP, "selector intact");
        assertTrue(_word(ret, 2) & OVERRIDE_FEE_FLAG != 0, "fee still overridden");

        Vm.Log[] memory e3 = _filter(vm.getRecordedLogs(), TOPIC0_TIMEPOINT_WRITTEN);
        assertEq(e3.length, 0, "no-transition write emits no E3");
    }

    // ------------------------------------------------------------------ tick read (slot0)

    // The tick consumed is the pool's slot0 tick, sign-extended: drive a NEGATIVE tick via
    // the mock and read it back out of the E3 log. NOTE (mutation run, 2026-07-30): a masked
    // (non-signextended) slot0 decode SURVIVES this test -- the emit helper's own signextend
    // canonicalization re-derives the correct log word from the 24-bit pattern. The mutant is
    // killed by test__diff__hookVolMatchesAlgebraRef instead (the vol kernel consumes the
    // full-word SIGNED tick: masked -8123 becomes 16769093 and the vol diverges by ~7 orders).
    // This test still pins the E3 poolId topic + the log's sign extension.
    function test__unit__readsNegativeSlot0Tick() public {
        _init();
        vm.recordLogs();
        _swap(T0 + 600, -8123);
        Vm.Log[] memory e3 = _filter(vm.getRecordedLogs(), TOPIC0_TIMEPOINT_WRITTEN);
        assertEq(e3.length, 1, "one E3");
        (, int24 tick,,,) = abi.decode(e3[0].data, (uint32, int24, uint88, int24, int56));
        assertEq(tick, int24(-8123), "slot0 tick decoded sign-extended");
        assertEq(e3[0].topics[1], poolIdBound, "E3 carries the REAL bound poolId (hook emitter)");
    }

    // ------------------------------------------------------------------ E5

    function test__unit__feeAppliedEmitted() public {
        _init();
        _swap(T0 + 600, 500);

        uint32 ts = T0 + 1200;
        int24 tick = -300;
        vm.recordLogs();
        bytes memory ret = _swap(ts, tick);
        Vm.Log[] memory e5 = _filter(vm.getRecordedLogs(), TOPIC0_FEE_APPLIED);
        assertEq(e5.length, 1, "exactly one E5 per swap");
        assertEq(e5[0].topics[1], poolIdBound, "E5 poolId topic = bound pool");
        (uint88 sigma, uint24 fee) = abi.decode(e5[0].data, (uint88, uint24));
        assertEq(uint256(sigma), _hookVol(tick, ts), "E5 sigma = the vol used for this swap");
        assertEq(uint256(fee), _word(ret, 2) ^ OVERRIDE_FEE_FLAG, "E5 fee = returned fee sans flag (== Swap.fee join invariant)");
        assertEq(FeeApplied.selector, TOPIC0_FEE_APPLIED, "pinned topic0 == solc canonical");
    }

    // Same-block second swap: buffer no-op but E5 STILL emitted (per-swap series stays
    // complete -- several E5 share one E3, exactly the data contract's expectation).
    function test__unit__sameBlockSecondSwapStillEmitsE5() public {
        _init();
        _swap(T0 + 600, 500);
        vm.recordLogs();
        _swap(T0 + 600, 700);
        assertEq(_filter(vm.getRecordedLogs(), TOPIC0_FEE_APPLIED).length, 1, "E5 per swap, even buffer no-ops");
    }

    // ------------------------------------------------------------------ guards

    function test__unit__nonPoolManagerCallerReverts() public {
        _init();
        pm.setSlot0(poolIdBound, uint160(1) << 96, 0);
        (bool ok,) = hook.call(_beforeSwapCalldata(key)); // caller = this test, not the PM
        assertFalse(ok, "non-PoolManager caller reverts");
    }

    function test__unit__uninitializedBeforeSwapReverts() public {
        // no _init(); even a zero-address caller must not reach a silent 0% override
        vm.prank(address(0));
        (bool ok,) = hook.call(_beforeSwapCalldata(key));
        assertFalse(ok, "uninitialized hook reverts (no silent 0% fee)");
    }

    function test__unit__wrongPoolReverts() public {
        _init();
        PoolKey memory other =
            PoolKey({currency0: address(0xC), currency1: address(0xD), fee: 0x800000, tickSpacing: 60, hooks: hook});
        vm.warp(T0 + 600);
        pm.setSlot0(keccak256(abi.encode(other)), uint160(1) << 96, 0);
        vm.prank(address(pm));
        (bool ok,) = hook.call(_beforeSwapCalldata(other));
        assertFalse(ok, "one-pool-per-hook: a different PoolKey reverts");
    }
}
