// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {SpecOracle, SpecHelperProbe} from "./SpecHelper.sol";

// ===========================================================================================
// WHAT THIS FILE IS. It drives ONE input into two implementations of the SAME map --
//   spec/src/Panoptic/NId.hs :: volOrderToTokenId          (the Haskell executable spec)
//   src/lib/protocol_integrations/panoptic_v2/VolPositionId.plk
//       :: vol_order_to_panoptic_token_id                  (the on-chain implementation,
//       reached through test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk)
// -- and asserts the two tokenIds are equal at tolerance 0. That is the milestone's core
// value: a fuzzed input producing a different tokenId in Haskell than in Plank must fail the
// build.
//
// THIS FILE BUILDS NOTHING. Not one line of src/ or spec/ is created, modified or "adjusted"
// by it. It also does not touch test/protocol_integrations/VolOrderToPanopticTokenId.t.sol,
// which is this milestone's REGRESSION FLOOR and must stay green in every gate run.
//
// NEITHER SIDE SACROSANCT. This is the doctrine, and it is exactly where this file departs
// from test/pos_spec/VolOrderManager.diff.t.sol. There, the oracle is a disposable Solidity
// restatement and a red is always a finding about the module. Here BOTH sides are
// load-bearing, independently maintained artifacts. A divergence is therefore a finding about
// EITHER implementation -- the Haskell may be wrong, the Plank may be wrong, or the two may be
// answering subtly different questions -- and which it is gets adjudicated case by case, on
// the evidence, with the triggering input recorded before anything is changed. Neither side is
// ever bent merely to restore green. The forbidden move is picking a winner by default and
// editing the loser to match: that converts a real finding into a silent agreement.
//
// KNOWN ASYMMETRY, NOT A DIVERGENCE. Today the two are not yet the same function: the Haskell
// takes a 4-tuple of optionRatios and sets asset = 1 on every leg, while the Plank map
// hardcodes optionRatio = 1 and leaves asset unset. Closing that is Phase 2/3 work
// (VolOrder(T)), NOT something to be papered over here. This file is written against the
// eventual shape so the closure has a test waiting for it.
//
// DISCIPLINE, inherited from the .diff.t.sol family and non-negotiable:
//   - corpora are CONSTRUCTED with bound, never filtered with vm.assume. There is not one
//     vm.assume in this file and there must never be. Two reasons, each sufficient. A filtered
//     corpus silently shrinks toward the cases that already agree, which is the one failure
//     mode a differential test cannot survive. And max_test_rejects is 65536 and SHARED across
//     the run, so routing a spec rejection through vm.assume would burn a global budget and
//     HIDE the rejection instead of observing it -- rejection parity is Phase 9's subject
//     (GUARD-05) and it needs rejections visible, not filtered away.
//   - every fuzz names a non-fuzz anchor. test__fuzz_differential__volOrder's anchor is
//     test_differential__volOrder__anchor, the golden geometry from
//     VolOrderToPanopticTokenId.t.sol (width=1000, ts=10, vol=1, spread=0x8000).
//   - non-vacuity is ASSERTED via a live counter (`comparisons`), never assumed. A test whose
//     assertions never ran must FAIL, not pass.
//
// THE SEAM IS SHAPED TO A GENERATED INTERFACE. The transport is RESOLVED -- JSON-RPC, decided
// at evm-spec-bridge initialization, outside Phase 5 -- and the bridge GENERATES the Solidity
// interface from the same schema as its Haskell protocol types, so the two sides cannot drift
// silently. SpecHelper.sol hand-writes that shape as a PROVISIONAL stand-in; Phase 7 replaces
// it with the generated artifact. Everything this file touches -- SpecOracle.Status,
// TokenIdResult, Health, the skip predicate -- is the shape Phase 7 keeps. No transport
// mechanics appear here; RED-06 transport boundary rules bind every vm.rpc call site.
//
// WHY IT SKIPS TODAY (RED-05; the skip is REMOVED in Phase 11 / CI-04). There is no oracle
// yet: SpecOracle.volOrderToTokenId is a stub that reverts, and SpecOracle.health() reports
// Status.TransportFailure. setUp probes the wiring ONCE, caches it, and the differential tests
// skip on the CACHED value -- so the reverting stub is never reached on that path. That is
// what lets this branch push clean through develop-gate WITHOUT an entry in the gate's --skip
// ledger (.github/workflows/develop-gate.yml). The distinction matters: a ledger entry excludes
// the file from compilation and execution entirely, so nobody would notice it rotting. A
// self-computed skip means the gate COMPILES this file under --via-ir on every run and reports
// it, by name, as skipped for a reason this file stated.
//
// PROBE ONCE, CHECK EVERY SUCCESS FLAG. No test body calls health(); the skip reads a cached
// Status. And every low-level call here binds its bool and checks it before touching the
// returned bytes. Measured at forge 1.5.1-stable: a server that accepts a connection and never
// answers costs a hardcoded 45 s per call, and the test PASSED because the call site ignored
// success -- at fuzz.runs = 256 that is 3.2 hours of green CI meaning nothing. Phase 1 can hit
// neither hazard; the patterns are established now, while they are free, because Phase 7
// inherits whatever this file establishes.
//
// LAYOUT, NAMING AND THE Solidity<->spec TRANSPORT BOUNDARY (RED-06). Phases 6-11 extend
// that organization; they do not redesign it.
// ===========================================================================================
contract VolOrderToPanopticTokenIdDiffTest is PlankTestBase {
    /// @dev FFI-deployed Plank harness. Same entrypoint the structural suite uses.
    address internal harness;

    /// @dev The external boundary around the spec seam. See SpecHelper.sol for why it exists.
    SpecHelperProbe internal probe;

    /// @dev THE CACHED WIRING STATUS. Probed exactly ONCE, in setUp. Every skip reads this, and
    ///      no test body calls health(). See the header for why this is structural.
    SpecOracle.Status internal s_wiring;

    // --- THE NON-FUZZ ANCHOR GEOMETRY ---------------------------------------------------
    // The golden vector from VolOrderToPanopticTokenId.t.sol: width=1000, ts=10, vol=1 (=> i*=0),
    // spread=0x8000 (~0.5) => bucket [-500,500], legs [-500,-250],[-250,0],[0,250],[250,500].
    // Chosen deliberately: it is already known-feasible on the Plank side and already pinned by
    // the regression floor, so if the anchor ever disagrees, the disagreement is about the spec
    // half and not about a geometry nobody had checked.
    uint256 internal constant ANCHOR_WIDTH = 1000;
    uint256 internal constant ANCHOR_TS = 10;
    uint256 internal constant ANCHOR_VOL = 1;
    uint256 internal constant ANCHOR_SPREAD = 0x8000;
    uint64 internal constant ANCHOR_POOL_ID = 0;

    /// @dev THE NON-VACUITY COUNTER. Incremented once per spec-vs-impl comparison and asserted
    ///      strictly positive at the end of every differential test that actually ran. Without
    ///      it, "the oracle answered for zero inputs" and "the oracle agreed on every input"
    ///      are the same green.
    uint256 internal comparisons;

    string internal constant SKIP_REASON =
        "spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).";

    function setUp() public {
        harness = deployPlank("test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk");
        probe = new SpecHelperProbe();
        // PROBE ONCE. Every skip below reads this cached value.
        s_wiring = _probeWiring();
    }

    /// @notice THE WIRING PROBE (RED-04/RED-05). Called EXACTLY ONCE, from setUp.
    /// @dev Three things here are deliberate and must survive into Phase 7:
    ///      (1) It goes through the EXTERNAL boundary with a LOW-LEVEL call rather than
    ///          try/catch. From Phase 7 a transport fault arrives as a cheatcode revert, and
    ///          whether try/catch behaves against a cheatcode-originated revert is an OPEN
    ///          question (it performs an extcodesize check against the cheatcode address). The
    ///          low-level form sidesteps it.
    ///      (2) It BINDS the success flag and checks it BEFORE touching the returned bytes.
    ///          Anything unexpected -- reverted, empty -- resolves to TransportFailure, which is
    ///          fail-safe: the tests skip rather than compare against nothing.
    ///      (3) It decodes the FULL Health struct, not a bool and not a string. A simple-typed
    ///          health check round-trips cleanly even when the domain payload path is broken, so
    ///          it would be a green that proves nothing. "Wired" must mean the real envelope
    ///          round-trips.
    function _probeWiring() internal returns (SpecOracle.Status) {
        (bool ok, bytes memory ret) =
            address(probe).call(abi.encodeWithSelector(SpecHelperProbe.health.selector));
        if (!ok || ret.length == 0) {
            return SpecOracle.Status.TransportFailure;
        }
        SpecOracle.Health memory h = abi.decode(ret, (SpecOracle.Health));
        return h.status;
    }

    /// @notice The skip predicate, read from the CACHE. Identical in Phase 7 -- only the value
    ///         behind it changes. An unreachable oracle is NEVER a spec rejection.
    function _specWired() internal view returns (bool) {
        return s_wiring != SpecOracle.Status.TransportFailure;
    }

    // VolOrder packing (pack_vol_order layout): width@128, tickSpacing@104, vol@16, spread@0.
    // Reproduced from VolOrderToPanopticTokenId.t.sol rather than shared, so the regression
    // floor stays a file this branch does not touch.
    function _packVO(uint256 width, uint256 tickSpacing, uint256 vol, uint256 spread)
        internal
        pure
        returns (uint256)
    {
        return (width << 128) | (tickSpacing << 104) | (vol << 16) | spread;
    }

    function _anchorPackedVO() internal pure returns (uint256) {
        return _packVO(ANCHOR_WIDTH, ANCHOR_TS, ANCHOR_VOL, ANCHOR_SPREAD);
    }

    /// @dev Fixed-size arrays cannot be `constant` in Solidity, hence a function.
    function _anchorRatios() internal pure returns (uint256[4] memory r) {
        r = [uint256(1), uint256(1), uint256(1), uint256(1)];
    }

    /// @notice PLACEHOLDER ENCODING -- THIS IS NOT THE WIRE FORMAT.
    /// @dev The VolOrder(T) wire format is Phase 4's decision (VORD-06) and is OPAQUE to this
    ///      phase. `bytes` is the seam's parameter type precisely so that choosing the format
    ///      changes THIS ONE FUNCTION and nothing else. Nothing asserts on these bytes, and no
    ///      reader may treat this encoding as a commitment to a layout.
    function _provisionalWire(uint256 packedVO, uint256[4] memory ratios)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(packedVO, ratios);
    }

    /// @notice The IMPL half. Phase 9 replaces the bare `require` here with revert-vs-return
    ///         parity against the spec (GUARD-05); until then a Plank-side revert is a test
    ///         error, not a comparison. Note the success flag is bound and checked, per the rule
    ///         in the header.
    function _implTokenId(uint256 packedVO, uint64 poolId) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("tokenIdFromVolOrder(uint256,uint256)", packedVO, uint256(poolId))
        );
        require(ok, "impl: tokenIdFromVolOrder reverted");
        return abi.decode(r, (uint256));
    }

    // --- EVIDENCE: these two run in every gate run and must PASS -------------------------

    /// @notice RED-04 evidence. The seam is a STUB that reverts, and the cached wiring status
    ///         reports exactly that. The revert is FAIL-SAFE by design: a stub that returned a
    ///         zero-valued TokenIdResult would be fail-open, and a test that forgot to check
    ///         `status` would "agree" on a fabricated tokenId == 0. Asserting the revert is what
    ///         rules that out. The external boundary is what makes it assertable at all -- a
    ///         library's internal functions inline, so an unguarded revert would kill this test
    ///         rather than be observed by it.
    function test_specHelper_stubRevertsAndProbeReportsNotWired() public {
        bytes memory wire = _provisionalWire(_anchorPackedVO(), _anchorRatios());

        vm.expectRevert(
            abi.encodeWithSelector(SpecOracle.SpecOracleNotWired.selector, wire, ANCHOR_POOL_ID)
        );
        probe.volOrderToTokenId(wire, ANCHOR_POOL_ID);

        assertTrue(
            s_wiring == SpecOracle.Status.TransportFailure,
            "cached wiring must be TransportFailure while the oracle is a stub"
        );
        assertFalse(_specWired(), "the skip predicate must agree with the cached probe");
        assertEq(comparisons, 0, "no spec-vs-impl comparison can have run without an oracle");
    }

    /// @notice The IMPL half of the seam is LIVE today even though the spec half is not: the
    ///         Plank harness deploys and answers on the anchor geometry. Without this, a broken
    ///         FFI deploy and a missing oracle would look identical in the gate log.
    function test_implSide_answersOnAnchor() public {
        uint256 tid = _implTokenId(_anchorPackedVO(), ANCHOR_POOL_ID);
        assertTrue(tid != 0, "impl tokenId is non-zero on the anchor geometry");
    }

    // --- THE DIFFERENTIAL --------------------------------------------------------------

    /// @notice The whole point of the file. Tolerance 0, both sides named in the message.
    /// @dev The three outcomes are separated BEFORE any comparison. A transport failure is not
    ///      agreement and not a rejection; a rejection is not agreement. Conflating any two of
    ///      them is how a differential test goes silently green (XPORT-02).
    ///      `result.detail` is diagnostics only and is NEVER asserted on.
    function _assertAgree(uint256 packedVO, uint64 poolId, uint256[4] memory ratios) internal {
        SpecOracle.TokenIdResult memory result =
            SpecOracle.volOrderToTokenId(_provisionalWire(packedVO, ratios), poolId);

        assertTrue(
            result.status != SpecOracle.Status.TransportFailure,
            "spec oracle transport failure - this is not a comparison and must never pass as one"
        );
        // This corpus is CONSTRUCTED so that no spec guard can fire (see the bound arithmetic in
        // the fuzz). A rejection here means the CORPUS is wrong, not that the two sides
        // disagree. Rejection PARITY -- revert-vs-return, over result.guard -- is Phase 9's
        // subject (GUARD-05); mixing it in here would make a future red ambiguous.
        assertTrue(
            result.status != SpecOracle.Status.Rejected,
            "spec rejected an input this corpus constructed to be legal"
        );

        uint256 specTokenId = result.tokenId;
        uint256 implTokenId = _implTokenId(packedVO, poolId);
        assertEq(specTokenId, implTokenId, "spec vs impl tokenId, tol 0");
        comparisons++;
    }

    /// @notice THE NON-FUZZ ANCHOR for test__fuzz_differential__volOrder. One fixed, known-good
    ///         geometry -- the regression floor's golden vector -- so that a fuzz failure can be
    ///         localised to the input rather than to the whole map, and so that a fuzz that
    ///         mysteriously passes has a fixed case to be checked against.
    function test_differential__volOrder__anchor() public {
        if (!_specWired()) {
            vm.skip(true, SKIP_REASON);
            return;
        }
        _assertAgree(_anchorPackedVO(), ANCHOR_POOL_ID, _anchorRatios());
        assertGt(comparisons, 0, "anchor: non-vacuity - at least one comparison must have run");
    }

    /// @notice THE ASSERTION THIS PHASE IS FOR. Skipped until Phase 7 wires the oracle and
    ///         Phase 11 removes the guard; written now, in full, against the real assertion.
    function test__fuzz_differential__volOrder(
        uint256 widthR,
        uint256 spreadR,
        uint256 poolIdR,
        uint256 r0R,
        uint256 r1R,
        uint256 r2R,
        uint256 r3R
    ) public {
        // THE CACHED WIRING STATUS IS READ FIRST. Everything below this point would reach the
        // reverting stub; vm.skip fires before any of it runs. This is a state read, NOT a
        // health() call -- the probe ran once, in setUp, and that is deliberate.
        if (!_specWired()) {
            vm.skip(true, SKIP_REASON);
            return;
        }

        // CORPUS CONSTRUCTION (RED-03). Not one vm.assume: every bound below is chosen so the
        // map's preconditions hold BY CONSTRUCTION. The arithmetic, stated so a later reader
        // can check it rather than trust it:
        //   ts = 10 and vol = 1 pin i* = 0 with the bucket centred there (the golden geometry).
        //   width in [1000, 40000] and spread in [0x2000, 0xE000] (0.125 .. 0.875) give
        //     putSide, callSide >= 0.125 * 1000 = 125 ticks, vs the required 2*ts = 20;
        //     max leg span     <= 0.875 * 40000 / 2 = 17500 ticks = 1750*ts, vs the 12-bit
        //                         width field's 4096*ts ceiling;
        //     max |tick|       <= 0.875 * 40000 = 35000, vs uniswapMaxTick = 887272.
        //   Bucket rounding contributes at most one tickSpacing (10 ticks) of slack against a
        //   125-tick margin, so no bound here is marginal.
        //   ratios in [1,127] is the spec's own optionRatio guard, so no input is constructed
        //   that the Haskell would reject -- rejection PARITY is Phase 8/9's subject, not this
        //   file's, and mixing the two would make a red ambiguous.
        uint256 width = bound(widthR, 1000, 40000);
        uint256 spread = bound(spreadR, 0x2000, 0xE000);
        uint64 poolId = uint64(bound(poolIdR, 0, type(uint64).max));
        uint256[4] memory ratios = [
            bound(r0R, 1, 127),
            bound(r1R, 1, 127),
            bound(r2R, 1, 127),
            bound(r3R, 1, 127)
        ];

        _assertAgree(_packVO(width, ANCHOR_TS, ANCHOR_VOL, spread), poolId, ratios);
        assertGt(comparisons, 0, "fuzz: non-vacuity - at least one comparison must have run");
    }
}
