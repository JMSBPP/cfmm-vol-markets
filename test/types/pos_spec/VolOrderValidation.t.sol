// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../../PlankTestBase.sol";

// ===========================================================================================
// THE VolOrderValidationLib suite. Everything that exercises the PURE validation surface
// src/lib/pos_spec/VolOrderValidationLib.plk -- through its FFI harness
// test/types/pos_spec/VolOrderValidationHarness.plk -- lives in THIS FILE. Phases 17 and 18a
// EXTEND their own module files; do NOT fork a second validation file.
//
// GLOBAL RULE: "it compiles" is never acceptance. `plank build` does NOT type-check code
// unreachable from run{} -- deployPlank -> plankDeployFFI -> plankBuildFFI shells out to
// `plank build` over FFI AT TEST TIME, so every assertion below runs the DEPLOYED bytecode
// and a `.plk` edit reaches it on the very next `forge test`. That is why the mutation
// battery recorded at the foot of this file needs no `make compile-plank` between mutants.
//
// src/types/pos_spec/ is NEVER modified by this suite. That tree belongs to the vol-type
// track and carries 4 red harness tests of its own; this suite must not filter, hide, or
// "fix" them. Notably `pack_vol_order`/`unpack_vol_order` are consumed VERBATIM here.
// ===========================================================================================

/// @notice The harness ABI. Selectors cast-verified in the harness header
///         (0x1b6f447e / 0x87a10138 / 0x75b370cd / 0x729f096f).
///         Argument order is create_order-native throughout: (strike, width, skew).
interface IVolOrderValidation {
    function validateOrder(uint256 strike, uint256 width, uint256 skew, uint256 targetVega) external view returns (uint256);
    function validateOrderStrict(uint256 strike, uint256 width, uint256 skew, uint256 targetVega) external view returns (uint256);
    function packVolOrder(uint256 strike, uint256 width, uint256 skew, uint256 targetVega) external view returns (uint256);
    function unpackVolOrder(uint256 packed)
        external
        view
        returns (uint256 width, uint256 tickSpacing, uint256 strike, uint256 skew, uint256 targetVega);
}

/// @title VolOrderValidationBase
/// @notice One deploy site, shared by every concern-contract below. The module roots come from
///         PlankTestBase alone -- never hand-roll a local dependency array here.
///         test/types/pos_spec/VolOrder.t.sol predates PlankTestBase and declares only 5 roots
///         (no `interfaces`); do not copy that.
abstract contract VolOrderValidationBase is PlankTestBase {
    IVolOrderValidation plk;

    uint256 constant TICK_SPACING = 20; // pinned in the lib; a stored 0 would be a bug
    uint256 constant MAX_STRIKE = (1 << 88) - 1;
    uint256 constant MAX_WIDTH = 0xffffff;

    // The corpus tuple of record (test/types/pos_spec/VolOrder.t.sol:102-104): width from
    // |-120-120|/20, strike from a real Arbitrum getSingleTimepoint read, skew = uint16 max / 2.
    uint256 constant A_STRIKE = 826165723479;
    uint256 constant A_WIDTH = 120;
    uint256 constant A_SKEW = 32767;
    uint256 constant A_TARGET_VEGA = 1e18; // raw L units, valid (V2)

    function setUp() public {
        plk = IVolOrderValidation(deployPlank("test/types/pos_spec/VolOrderValidationHarness.plk"));
    }
}

/// @title VolOrderValidationBoundaryTest
/// @notice SC 1. Every test here is NON-FUZZ, which makes this contract the cache-independent
///         kill surface for the entire mutation battery recorded at the foot of this file.
contract VolOrderValidationBoundaryTest is VolOrderValidationBase {
    /// @notice SC 1. The ACCEPT witness. A validator that rejects everything satisfies every
    ///         other criterion in this phase -- and is exactly what the pre-review design would
    ///         have shipped. This test is the tripwire for that (proven live by mutant M4).
    function test__unit__anchorValidTupleAccepted() public {
        assertEq(
            plk.validateOrder(A_STRIKE, A_WIDTH, A_SKEW, A_TARGET_VEGA),
            1,
            "anchor tuple must be ACCEPTED (all-reject validator fails here)"
        );
        assertEq(
            plk.validateOrderStrict(A_STRIKE, A_WIDTH, A_SKEW, A_TARGET_VEGA), 1, "strict path must NOT revert on a valid tuple"
        );
    }

    /// @dev PosSpec.lean:56 skewTick_zero -- a zero skew collapses the position to a one-sided
    ///      range, which is degenerate, not merely unusual.
    function test__unit__skewZeroRejected() public {
        assertEq(plk.validateOrder(A_STRIKE, A_WIDTH, 0, A_TARGET_VEGA), 0, "skew 0 must be REJECTED");
        vm.expectRevert();
        plk.validateOrderStrict(A_STRIKE, A_WIDTH, 0, A_TARGET_VEGA);
    }

    /// @dev The LOW endpoint is ACCEPTED. VORD-02's earlier wording ("open interval [1,65534],
    ///      both endpoints revert") was ambiguous enough to tempt an implementer into asserting
    ///      that 1 REVERTS -- which fails against the real predicate
    ///      (SpreadTickAssimetry.plk:12 = `(spread > 0) & (spread < 0xffff)`) and then tempts a
    ///      "fix" to the vol-type track's file. It does not revert. 1 is valid.
    function test__unit__skewOneAccepted() public {
        assertEq(plk.validateOrder(A_STRIKE, A_WIDTH, 1, A_TARGET_VEGA), 1, "skew 1 must be ACCEPTED");
        assertEq(plk.validateOrderStrict(A_STRIKE, A_WIDTH, 1, A_TARGET_VEGA), 1, "strict path must NOT revert at skew 1");
    }

    /// @dev 0xfffe -- the HIGH endpoint, ACCEPTED (the predicate's `<` is strict against 0xffff).
    function test__unit__skew65534Accepted() public {
        assertEq(plk.validateOrder(A_STRIKE, A_WIDTH, 65534, A_TARGET_VEGA), 1, "skew 65534 must be ACCEPTED");
        assertEq(plk.validateOrderStrict(A_STRIKE, A_WIDTH, 65534, A_TARGET_VEGA), 1, "strict path must NOT revert at skew 65534");
    }

    /// @dev PosSpec.lean:52 skewTick_one -- the saturated endpoint is the mirror degeneracy.
    function test__unit__skew65535Rejected() public {
        assertEq(plk.validateOrder(A_STRIKE, A_WIDTH, 65535, A_TARGET_VEGA), 0, "skew 65535 must be REJECTED");
        vm.expectRevert();
        plk.validateOrderStrict(A_STRIKE, A_WIDTH, 65535, A_TARGET_VEGA);
    }

    // Width boundaries. These are what make the width conjunct falsifiable -- without them,
    // deleting `vol_range_width_is_complete` from validate_order kills nothing (mutant M6).

    function test__unit__widthZeroRejected() public {
        assertEq(plk.validateOrder(A_STRIKE, 0, A_SKEW, A_TARGET_VEGA), 0, "width 0 must be REJECTED");
        vm.expectRevert();
        plk.validateOrderStrict(A_STRIKE, 0, A_SKEW, A_TARGET_VEGA);
    }

    function test__unit__widthAbove24BitsRejected() public {
        assertEq(plk.validateOrder(A_STRIKE, MAX_WIDTH + 1, A_SKEW, A_TARGET_VEGA), 0, "width 2^24 must be REJECTED");
    }

    function test__unit__widthMaxAccepted() public {
        assertEq(plk.validateOrder(A_STRIKE, MAX_WIDTH, A_SKEW, A_TARGET_VEGA), 1, "width 0xffffff must be ACCEPTED");
    }
}

/// @title VolOrderValidationStrikeBoundTest
/// @notice SC 2 -- the one bound this phase AUTHORS.
contract VolOrderValidationStrikeBoundTest is VolOrderValidationBase {
    /// @notice SC 2. THE phase's sharpest falsifiability test, because the failure it prevents is
    ///         SILENT. tick_volatility_is_complete is only `vol > 0` -- no upper bound -- so
    ///         without the authored `strike <= 2^88-1`, an oversized strike PASSES validation and
    ///         pack_vol_order's `& 0xFFFFFFFFFFFFFFFFFFFFFF` mask (VolOrder.plk:38) stores a
    ///         DIFFERENT VALUE than the caller supplied. No revert, no event, nothing observable.
    ///
    /// @dev WHY 2^88 + 7 AND NOT 2^88. At exactly 2^88 the masked value is 0, which is
    ///      indistinguishable from "nothing was stored" and would let a reader mistake corruption
    ///      for rejection. 7 is unmistakably a DIFFERENT NONZERO NUMBER.
    function test__unit__strikeBoundBlocksSilentMasking() public {
        uint256 oversized = (1 << 88) + 7;

        // (a) The corruption is real and SILENT: pack does not revert, it changes the value.
        uint256 packed = plk.packVolOrder(oversized, A_WIDTH, A_SKEW, A_TARGET_VEGA);
        (,, uint256 strikeOut,,) = plk.unpackVolOrder(packed);
        assertEq(strikeOut, 7, "pack silently masks an oversized strike to its low 88 bits");
        assertTrue(strikeOut != oversized, "the corruption is a VALUE CHANGE, not a revert");

        // (b) The authored bound is what keeps that value off the store path.
        assertEq(plk.validateOrder(oversized, A_WIDTH, A_SKEW, A_TARGET_VEGA), 0, "strike >= 2^88 must be REJECTED");
        vm.expectRevert();
        plk.validateOrderStrict(oversized, A_WIDTH, A_SKEW, A_TARGET_VEGA);
    }

    /// @dev The tight boundary: 2^88-1 is the largest value pack stores FAITHFULLY, so it must be
    ///      ACCEPTED. Pairing this with the test above pins `<=` exactly -- a `<=`-to-`<` mutant
    ///      reddens here, a deleted bound reddens above.
    function test__unit__strikeMaxAcceptedAndRoundTripsExactly() public {
        assertEq(plk.validateOrder(MAX_STRIKE, A_WIDTH, A_SKEW, A_TARGET_VEGA), 1, "strike 2^88-1 must be ACCEPTED");
        (,, uint256 strikeOut,,) = plk.unpackVolOrder(plk.packVolOrder(MAX_STRIKE, A_WIDTH, A_SKEW, A_TARGET_VEGA));
        assertEq(strikeOut, MAX_STRIKE, "strike 2^88-1 round-trips with no loss");
    }

    function test__unit__strikeZeroRejected() public {
        assertEq(plk.validateOrder(0, A_WIDTH, A_SKEW, A_TARGET_VEGA), 0, "strike 0 must be REJECTED");
        vm.expectRevert();
        plk.validateOrderStrict(0, A_WIDTH, A_SKEW, A_TARGET_VEGA);
    }
}

/// @title VolOrderValidationPackingTest
/// @notice SC 3 -- the 152-bit layout and the tolerance-0 round-trip.
contract VolOrderValidationPackingTest is VolOrderValidationBase {
    /// @dev The layout, re-derived INDEPENDENTLY from VolOrder.plk:35-40 (the shifts are read
    ///      from the documented layout, NOT ported from a Plank expression, so this assertion is
    ///      a genuine cross-check rather than a restatement):
    ///      width bits 128..151 | tickSpacing bits 104..127 | strike bits 16..103 |
    ///      skew bits 0..15  (152 bits total). Offsets are spelled "bits N" rather than with
    ///      an at-sign, which solc's natspec parser would read as an unknown doc tag.
    ///      The pre-review draft had width and tickSpacing SWAPPED, which would have zeroed out
    ///      `width` -- the field every caller supplies. This function is the guard against that.
    function _expectedWord(uint256 strike, uint256 width, uint256 skew) internal pure returns (uint256) {
        // V2: targetVega joins at bit 152 (the call sites pack with A_TARGET_VEGA appended).
        return (A_TARGET_VEGA << 152) | (width << 128) | (TICK_SPACING << 104) | (strike << 16) | skew;
    }

    /// @notice SC 3 + SC 1 totality. Corpus is CONSTRUCTED so EVERY tuple is valid by
    ///         construction -- so `validateOrder == 1` on every run is a live totality assertion,
    ///         not a filtered one. Nothing in this file rejection-filters its corpus: every
    ///         input is repaired into range with `bound`, never discarded by an assume.
    /// forge-config: default.fuzz.runs = 512
    function test__fuzz__validTuplesAcceptedAndRoundTrip(uint256 sRaw, uint256 wRaw, uint256 kRaw) public {
        uint256 strike = bound(sRaw, 1, MAX_STRIKE);
        uint256 width = bound(wRaw, 1, MAX_WIDTH);
        uint256 skew = bound(kRaw, 1, 65534);

        assertEq(plk.validateOrder(strike, width, skew, A_TARGET_VEGA), 1, "every constructed-valid tuple must be ACCEPTED");

        uint256 packed = plk.packVolOrder(strike, width, skew, A_TARGET_VEGA);
        assertEq(
            packed, _expectedWord(strike, width, skew), "layout: width@128 | tickSpacing@104 | strike@16 | skew@0"
        );
        assertLt(packed, 1 << 248, "packed word must fit 248 bits (V2: targetVega at 152..247)");

        (uint256 wOut, uint256 tsOut, uint256 sOut, uint256 kOut, uint256 tvOut) = plk.unpackVolOrder(packed);
        assertEq(wOut, width, "round-trip width, tolerance 0");
        assertEq(
            tsOut, TICK_SPACING, "round-trip tickSpacing == 20 (a stored 0 fails any future full width validation)"
        );
        assertEq(sOut, strike, "round-trip strike, tolerance 0");
        assertEq(kOut, skew, "round-trip skew, tolerance 0");
    }

    /// @notice The cache-independent anchor beside the fuzz. A `runs: 0` kill is a replay, not
    ///         proof -- this test carries the same claims at one fixed point.
    function test__unit__anchorRoundTrip() public {
        uint256 packed = plk.packVolOrder(A_STRIKE, A_WIDTH, A_SKEW, A_TARGET_VEGA);
        assertEq(packed, _expectedWord(A_STRIKE, A_WIDTH, A_SKEW), "anchor layout word");
        (uint256 wOut, uint256 tsOut, uint256 sOut, uint256 kOut, uint256 tvOut) = plk.unpackVolOrder(packed);
        assertEq(wOut, A_WIDTH, "anchor width");
        assertEq(tsOut, TICK_SPACING, "anchor tickSpacing == 20");
        assertEq(sOut, A_STRIKE, "anchor strike");
        assertEq(kOut, A_SKEW, "anchor skew");
    }
}

// ===========================================================================================
// MUTATION BATTERY -- SC 4. OBSERVED RED, not reasoned about.
//
// Six mutants, applied ONE AT A TIME to src/lib/pos_spec/VolOrderValidationLib.plk. For each:
// sha256 recorded -> single-line edit applied -> `rm -rf cache/fuzz` -> `make
// test-vol-order-validation` RUN and its RED READ -> verbatim [FAIL] line(s) pasted below ->
// `git checkout --` -> sha256 re-verified byte-identical -> target re-run GREEN (13/13).
// Every kill below is carried by a NON-FUZZ `test__unit__*` assertion, so no kill depends on a
// fuzz seed; a `runs: 0` kill would be a replay, not proof. All six mutants were killed; none
// was equivalence-masked.
//
// PRE-MUTATION / RESTORED sha256 of src/lib/pos_spec/VolOrderValidationLib.plk (identical for
// all six restorations):
//   5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35
//
// WHY M3 IS APPLIED AT OUR CALL SITE. ROADMAP Phase 16 SC 4 names "flipping either skew
// boundary comparison (`>` <-> `>=`)". That comparison's home is SpreadTickAssimetry.plk:12 --
// the vol-type track's file, which this phase must not modify, not even transiently. M3 applies
// the identical semantic flip inside OUR validate_order by inlining the flipped predicate. It
// has exactly the same falsification power (it admits both degenerate endpoints, skew 0 and
// 65535) while leaving their tree byte-untouched. `git status --porcelain src/types/pos_spec/`
// was checked during M3 and produced no output.
//
// -------------------------------------------------------------------------------------------
// M1 -- delete the authored strike bound (ROADMAP SC 4, first named mutant)
//   in strike_fits_packed:
//     -  let res = tick_volatility_is_complete(self) & (self.vol <= MAX_STRIKE);
//     +  let res = tick_volatility_is_complete(self);
//   OBSERVED RED (1 failed, 12 passed):
//     [FAIL: strike >= 2^88 must be REJECTED: 1 != 0] test__unit__strikeBoundBlocksSilentMasking() (gas: 14229)
//   Killed by: test__unit__strikeBoundBlocksSilentMasking, "strike >= 2^88 must be REJECTED".
//   Restored sha256 5fe71f30... (identical); target green 13/13.
//
// -------------------------------------------------------------------------------------------
// M2 -- tighten the strike bound off its endpoint (`<=` -> `<`)
//     -  (self.vol <= MAX_STRIKE);
//     +  (self.vol < MAX_STRIKE);
//   OBSERVED RED (2 failed, 11 passed):
//     [FAIL: strike 2^88-1 must be ACCEPTED: 0 != 1] test__unit__strikeMaxAcceptedAndRoundTripsExactly() (gas: 10499)
//     [FAIL: every constructed-valid tuple must be ACCEPTED: 0 != 1; counterexample: args=[115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77], 3, 1424282538433016240232290851766794577237363 [1.424e42]]] test__fuzz__validTuplesAcceptedAndRoundTrip(uint256,uint256,uint256) (runs: 116)
//   Killed by (non-fuzz): test__unit__strikeMaxAcceptedAndRoundTripsExactly,
//   "strike 2^88-1 must be ACCEPTED". This is the companion that pins the bound to the exact
//   value pack stores faithfully -- M1 alone leaves `<` and `<=` indistinguishable.
//   Restored sha256 5fe71f30... (identical); target green 13/13.
//
// -------------------------------------------------------------------------------------------
// M3 -- flip BOTH skew boundary comparisons, at our call site (ROADMAP SC 4, second named)
//   in validate_order:
//     -  & spread_tick_assimetry_is_complete(self.skew) &
//     +  & ((self.skew.spread >= 0) & (self.skew.spread <= 0xffff)) &
//   OBSERVED RED (2 failed, 11 passed):
//     [FAIL: skew 0 must be REJECTED: 1 != 0] test__unit__skewZeroRejected() (gas: 10760)
//     [FAIL: skew 65535 must be REJECTED: 1 != 0] test__unit__skew65535Rejected() (gas: 10631)
//   Killed by: both named tests, as required. Restored sha256 5fe71f30...; target green 13/13.
//
// -------------------------------------------------------------------------------------------
// M4 -- the all-reject sentinel (THE most important mutant in this phase)
//   in validate_order:
//     -  let res = vol_range_width_is_complete(self.rangeWidth) & spread_tick_assimetry_is_complete(self.skew) & strike_fits_packed(self.volStrike);
//     +  let res = false;
//   OBSERVED RED (6 failed, 7 passed):
//     [FAIL: anchor tuple must be ACCEPTED (all-reject validator fails here): 0 != 1] test__unit__anchorValidTupleAccepted() (gas: 9284)
//     [FAIL: every constructed-valid tuple must be ACCEPTED: 0 != 1; ...] test__fuzz__validTuplesAcceptedAndRoundTrip(uint256,uint256,uint256)
//     [FAIL: skew 1 must be ACCEPTED: 0 != 1] test__unit__skewOneAccepted() (gas: 9588)
//     [FAIL: skew 65534 must be ACCEPTED: 0 != 1] test__unit__skew65534Accepted() (gas: 9477)
//     [FAIL: strike 2^88-1 must be ACCEPTED: 0 != 1] test__unit__strikeMaxAcceptedAndRoundTripsExactly() (gas: 9456)
//     [FAIL: width 0xffffff must be ACCEPTED: 0 != 1] test__unit__widthMaxAccepted() (gas: 9265)
//   Killed by: test__unit__anchorValidTupleAccepted, "anchor tuple must be ACCEPTED
//   (all-reject validator fails here)". An all-reject validator satisfies every OTHER criterion
//   in this phase -- it is precisely what the pre-review design would have shipped. This
//   observation is the proof that SC 1's ACCEPT criterion is live rather than decorative.
//   Restored sha256 5fe71f30... (identical); target green 13/13.
//
// -------------------------------------------------------------------------------------------
// M5 -- unpin TICK_SPACING
//     -  const TICK_SPACING = 20;
//     +  const TICK_SPACING = 0;
//   OBSERVED RED (7 failed, 6 passed):
//     [FAIL: anchor layout word: 40833884030512615615605007035409039327231 != 40833884436160807688638415514354065047551] test__unit__anchorRoundTrip() (gas: 10126)
//     [FAIL: anchor tuple must be ACCEPTED (all-reject validator fails here): 0 != 1] test__unit__anchorValidTupleAccepted() (gas: 10356)
//     [FAIL: skew 1 must be ACCEPTED: 0 != 1] test__unit__skewOneAccepted() (gas: 10660)
//     [FAIL: skew 65534 must be ACCEPTED: 0 != 1] test__unit__skew65534Accepted() (gas: 10549)
//     [FAIL: strike 2^88-1 must be ACCEPTED: 0 != 1] test__unit__strikeMaxAcceptedAndRoundTripsExactly() (gas: 10528)
//     [FAIL: width 0xffffff must be ACCEPTED: 0 != 1] test__unit__widthMaxAccepted() (gas: 10337)
//     [FAIL: every constructed-valid tuple must be ACCEPTED: 0 != 1; ...] test__fuzz__validTuplesAcceptedAndRoundTrip(uint256,uint256,uint256)
//   Killed by TWO independent mechanisms, as designed:
//     (i)  SATISFIABILITY -- vol_range_width_is_complete ANDs `tickSpacing > 0`, so a zeroed
//          constant makes validate_order identically FALSE:
//          test__unit__anchorValidTupleAccepted.
//     (ii) LAYOUT -- test__unit__anchorRoundTrip reddens. NOTE: it fails one assertion EARLIER
//          than the plan predicted, on "anchor layout word" rather than on "anchor tickSpacing
//          == 20", because _expectedWord composes the Solidity-side TICK_SPACING (20) into bits
//          104..127 while the mutated pack writes 0 there. The word differs by exactly
//          20 << 104 = 405648192073033408478945025720320 (the two numbers above differ by
//          precisely that; verified). The tickSpacing assertion is unreachable in the same run because
//          Foundry stops the test at the first failing assertion. Recorded as observed, not as
//          predicted.
//   Restored sha256 5fe71f30... (identical); target green 13/13.
//
// -------------------------------------------------------------------------------------------
// M6 -- drop the width conjunct (proves the FULL predicate is reused, not a reduced check)
//   in validate_order:
//     -  let res = vol_range_width_is_complete(self.rangeWidth) & spread_tick_assimetry_is_complete(self.skew) & strike_fits_packed(self.volStrike);
//     +  let res = spread_tick_assimetry_is_complete(self.skew) & strike_fits_packed(self.volStrike);
//   OBSERVED RED (2 failed, 11 passed):
//     [FAIL: width 0 must be REJECTED: 1 != 0] test__unit__widthZeroRejected() (gas: 10355)
//     [FAIL: width 2^24 must be REJECTED: 1 != 0] test__unit__widthAbove24BitsRejected() (gas: 10080)
//   Killed by: test__unit__widthZeroRejected, "width 0 must be REJECTED".
//   Restored sha256 5fe71f30... (identical); target green 13/13.
// ===========================================================================================
