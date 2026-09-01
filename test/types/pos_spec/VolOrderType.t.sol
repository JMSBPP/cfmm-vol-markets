// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Entry points of test/types/pos_spec/VolOrderTypeHarness.plk.
interface IVolOrderTypeHarness {
    function roundTripNone(uint256 packed) external returns (uint256);
    function extraIsNoneAfterUnpack(uint256 packed) external returns (uint256);
    function tokenIdWithNoneExtra(uint256 packed, uint256 poolId) external returns (uint256);
    function extraDecodeFields(uint256 word) external returns (uint256, uint256, uint256);
    function extraEncodeRoundTrip(uint256 word) external returns (uint256);
    function packIgnoresExtra(uint256 packed, uint256 word) external returns (uint256);
    function unwrapNoneReverts(uint256 packed) external returns (uint256);
    // Phase 2.5 (VORD-07): the 40-bit FLAG_PANOPTIC payload.
    function payloadOptionRatio(uint256 payload, uint256 leg) external returns (uint256);
    function payloadTokenType(uint256 payload, uint256 leg) external returns (uint256);
    function payloadVegoid(uint256 payload) external returns (uint256);
    function payloadValidate(uint256 payload) external returns (uint256);
    function payloadRequireVegoidAgrees(uint256 payload, uint256 poolId) external returns (uint256);
}

/// @notice The pre-refactor tokenId map, for the bit-identity comparison.
interface IVolOrderToPanopticTokenIdHarness {
    function tokenIdFromVolOrder(uint256 packed, uint256 poolId) external returns (uint256);
}

/// @title VolOrderTypeTest
/// @notice Tests for the VolOrder(T) TYPE and the Extra(T) DESCRIPTOR (Phase 2, VORD-01), written
///         RED-first against a tree without them, per
///         .planning/phases/02-volorder-t-minimal-instantiation/02-REGRESSION-ASSESSMENT.md §4a.
/// @dev What these pin:
///      - absence is std Option/None, a VALUE -- `extra` is None after unpack, and reading through
///        it REVERTS rather than yielding zero;
///      - Extra(T) is a tagged DESCRIPTOR: flags in bits 248..255, offset in 216..247, len in
///        200..215. (Bit positions in prose, never with a leading at-sign: solc parses that in
///        NatSpec as a documentation tag and rejects the file with Error 6546 -- the same trap
///        test/pos_spec/VolOrderDecoder.sol documents.) Its len must be the one its flags
///        imply: 40 bits under FLAG_PANOPTIC, 0 otherwise. WIDENED from 28 in Phase 2.5: leg k
///        occupies bits 8k..8k+7 (optionRatio 7 bits at 8k, tokenType 1 bit at 8k+7) and vegoid
///        occupies bits 32..39. The leg STRIDE moved from 7 to 8, so every offset moved;
///      - Extra carries NO tokenId: the builder still returns PanopticTokenId, and Phase 2 walks
///        the no-payload path only, so the id stays bit-identical to the pre-refactor map;
///      - pack/unpack never touch `extra`.
///      Plank type-checks only what something instantiates, so the negatives are static fixtures
///      under fixtures/plank-negative/ built through vm.tryFfi.
contract VolOrderTypeTest is PlankTestBase {
    IVolOrderTypeHarness internal h;
    IVolOrderToPanopticTokenIdHarness internal ref;

    uint256 internal constant MASK_248 = (uint256(1) << 248) - 1;
    uint256 internal constant FLAG_PANOPTIC = 0x01;
    // 4 legs x (7-bit optionRatio + 1-bit tokenType) = 32, plus an 8-bit vegoid = 40.
    // WIDENED from 28 in Phase 2.5 (VORD-07). poolId remains a parameter, not payload.
    uint256 internal constant PANOPTIC_BITS = 40;

    // A valid packed VolOrder: width 2000, tickSpacing 10, volStrike 1, skew 0x8000, targetVega 0.
    uint256 internal constant VO =
        (uint256(2000) << 128) | (uint256(10) << 104) | (uint256(1) << 16) | 0x8000;

    function setUp() public {
        h = IVolOrderTypeHarness(deployPlank("test/types/pos_spec/VolOrderTypeHarness.plk"));
        ref = IVolOrderToPanopticTokenIdHarness(
            deployPlank("test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk")
        );
    }

    function _descriptor(uint256 flags, uint256 offset, uint256 len) internal pure returns (uint256) {
        return (flags << 248) | (offset << 216) | (len << 200);
    }

    // ---- absence is a VALUE (Option/None), not a tag type -------------------------------------

    function test__fuzz__packUnpackIsUnchangedByTheOptionField(uint256 x) public {
        assertEq(h.roundTripNone(x), x & MASK_248, "the 248-bit codec moved");
    }

    function test__unit__unpackYieldsANoneExtra() public {
        assertEq(h.extraIsNoneAfterUnpack(VO), 1, "unpack_vol_order must leave `extra` None");
    }

    function test__unit__readingThroughANoneExtraReverts() public {
        vm.expectRevert();
        h.unwrapNoneReverts(VO);
    }

    // ---- Extra(T) is a validated tagged descriptor --------------------------------------------

    function test__unit__panopticDescriptorDecodesToItsThreeFields() public {
        (uint256 flags, uint256 offset, uint256 len) =
            h.extraDecodeFields(_descriptor(FLAG_PANOPTIC, 0x24, PANOPTIC_BITS));
        assertEq(flags, FLAG_PANOPTIC, "flags");
        assertEq(offset, 0x24, "offset");
        assertEq(len, PANOPTIC_BITS, "len");
    }

    function test__unit__emptyDescriptorDecodes() public {
        (uint256 flags, uint256 offset, uint256 len) = h.extraDecodeFields(0);
        assertEq(flags, 0);
        assertEq(offset, 0);
        assertEq(len, 0, "an unflagged descriptor must carry no payload");
    }

    function test__unit__panopticFlagWithTheWrongLengthReverts() public {
        vm.expectRevert();
        h.extraDecodeFields(_descriptor(FLAG_PANOPTIC, 0x24, 80)); // 80 != 40: len contradicts flags
    }

    /// 28 was the Phase 2 width (four 7-bit optionRatios, nothing else). It is now REJECTED.
    /// This assertion is the INVERSE of the pre-2.5 one and is changed deliberately: the payload
    /// widened to 40 to carry per-leg tokenType and vegoid. 28 was itself the 76 -> 28 correction
    /// (PR #65 / b2868cc), so this reopens a recent decision -- with approval, not by drift.
    function test__unit__extraDecodeRejectsTheOldTwentyEightBitWidth() public {
        vm.expectRevert();
        h.extraDecodeFields(_descriptor(FLAG_PANOPTIC, 0x24, 28));
    }

    // ---- the 40-bit FLAG_PANOPTIC payload (VORD-07) --------------------------------------------

    /// Leg k occupies [8k..8k+7]: optionRatio 7 bits at 8k, tokenType 1 bit at 8k+7.
    /// Every leg gets a DISTINCT ratio and an alternating tokenType, so neither a stride bug
    /// (7 vs 8) nor a leg-index swap can pass this.
    function test__unit__payloadAccessorsPerLeg() public {
        uint256 p = _payload(1, 127, 64, 13, 200);
        p |= (uint256(1) << 15); // leg1 tokenType
        p |= (uint256(1) << 31); // leg3 tokenType

        assertEq(h.payloadOptionRatio(p, 0), 1, "leg0 ratio");
        assertEq(h.payloadOptionRatio(p, 1), 127, "leg1 ratio");
        assertEq(h.payloadOptionRatio(p, 2), 64, "leg2 ratio");
        assertEq(h.payloadOptionRatio(p, 3), 13, "leg3 ratio");
        assertEq(h.payloadTokenType(p, 0), 0, "leg0 tokenType");
        assertEq(h.payloadTokenType(p, 1), 1, "leg1 tokenType");
        assertEq(h.payloadTokenType(p, 2), 0, "leg2 tokenType");
        assertEq(h.payloadTokenType(p, 3), 1, "leg3 tokenType");
        assertEq(h.payloadVegoid(p), 200, "vegoid");
    }

    /// A leg's tokenType bit must not bleed into the NEXT leg's optionRatio. With stride 8 the
    /// tokenType is the top bit of the leg's byte, so an off-by-one stride would show up here.
    function test__unit__tokenTypeDoesNotBleedIntoTheNextLegsRatio() public {
        uint256 p = _payload(1, 1, 1, 1, 9);
        p |= (uint256(1) << 7);  // leg0 tokenType only
        assertEq(h.payloadOptionRatio(p, 1), 1, "leg0 tokenType leaked into leg1 ratio");
        assertEq(h.payloadTokenType(p, 0), 1, "leg0 tokenType");
    }

    /// vegoid is 1..255 -- both SFPMs revert InvalidTokenIdParameter(0) on zero. At 8 bits,
    /// anything above the max is unrepresentable, so ZERO is the only reachable invalid value.
    function test__unit__payloadRejectsZeroVegoid() public {
        vm.expectRevert();
        h.payloadValidate(_payload(1, 1, 1, 1, 0));
    }

    /// optionRatio is 1..127, and by the same argument zero is its only reachable invalid value.
    function test__unit__payloadRejectsZeroOptionRatio() public {
        vm.expectRevert();
        h.payloadValidate(_payload(1, 1, 0, 1, 9)); // leg2 == 0
    }

    function test__unit__payloadAcceptsTheBoundaryValues() public {
        assertEq(h.payloadValidate(_payload(1, 127, 1, 127, 1)), 1, "min/max ratios and vegoid 1");
        assertEq(h.payloadValidate(_payload(127, 1, 127, 1, 255)), 1, "vegoid 255");
    }

    // ---- the payload's vegoid must agree with pool_id[40..47] (VORD-07) ----------------------

    /// poolId layout is [16b tickSpacing at 48][8b vegoid at 40][40b pattern at 0]
    /// (PanopticMath.sol:28). The payload declares a vegoid; the poolId carries one; they must
    /// agree. Both operands belong to this phase -- poolId comes from VolMarketKey, the payload
    /// from Extra(T) -- and Extra(T) has no VolOrder dependency, which is why this guard is here
    /// and not in Phase 3.
    function test__unit__vegoidAgreesWithPoolId() public {
        uint256 poolId = (uint256(200) << 40) | 0x1122334455;
        assertEq(
            h.payloadRequireVegoidAgrees(_payload(1, 1, 1, 1, 200), poolId), 1, "agreeing pair"
        );
    }

    function test__unit__vegoidMismatchReverts() public {
        uint256 poolId = (uint256(201) << 40) | 0x1122334455;
        vm.expectRevert();
        h.payloadRequireVegoidAgrees(_payload(1, 1, 1, 1, 200), poolId);
    }

    /// THE HOLE. `require(a == b)` passes happily when BOTH sides are zero, and vegoid == 0 is
    /// invalid (both SFPMs revert InvalidTokenIdParameter(0)). So a zero-vegoid payload checked
    /// against a poolId whose bits 40..47 are also zero satisfies the equality and would sail
    /// through on the equality alone. The separate `!= 0` check is what stops it, and this test
    /// is the reason that check is not redundant.
    function test__unit__vegoidZeroOnBothSidesStillReverts() public {
        uint256 poolId = 0x1122334455; // bits 40..47 are zero
        vm.expectRevert();
        h.payloadRequireVegoidAgrees(_payload(1, 1, 1, 1, 0), poolId);
    }

    /// The check must read ONLY bits 40..47 of the poolId. A tickSpacing in the high bits or a
    /// pattern in the low bits must not perturb it.
    function test__fuzz__vegoidCheckIgnoresTheRestOfThePoolId(uint40 pattern, uint16 tickSpacing)
        public
    {
        uint256 poolId = (uint256(tickSpacing) << 48) | (uint256(77) << 40) | uint256(pattern);
        assertEq(
            h.payloadRequireVegoidAgrees(_payload(1, 1, 1, 1, 77), poolId),
            1,
            "the check is reading bits outside 40..47"
        );
    }

    function _payload(uint256 r0, uint256 r1, uint256 r2, uint256 r3, uint256 vegoid)
        internal
        pure
        returns (uint256)
    {
        return r0 | (r1 << 8) | (r2 << 16) | (r3 << 24) | (vegoid << 32);
    }

    function test__unit__unflaggedDescriptorWithAPayloadLengthReverts() public {
        vm.expectRevert();
        h.extraDecodeFields(_descriptor(0, 0x24, PANOPTIC_BITS));
    }

    function test__unit__reservedFlagBitsRevert() public {
        vm.expectRevert();
        h.extraDecodeFields(_descriptor(0x02, 0, 0)); // only FLAG_PANOPTIC is defined in Phase 2
    }

    function test__fuzz__descriptorSurvivesEncodeDecode(uint32 offset) public {
        uint256 word = _descriptor(FLAG_PANOPTIC, offset, PANOPTIC_BITS);
        assertEq(h.extraEncodeRoundTrip(word), word, "the packed layout is not a bijection");
    }

    // ---- pack/unpack never touch `extra` ------------------------------------------------------

    function test__fuzz__packIgnoresExtraEntirely(uint256 x) public {
        assertEq(
            h.packIgnoresExtra(x, _descriptor(FLAG_PANOPTIC, 0x24, PANOPTIC_BITS)),
            x & MASK_248,
            "carrying Some(Extra) changed the packed word"
        );
    }

    // ---- the builder: generic over T, still returns PanopticTokenId, bit-identical -------------

    function test__fuzz__tokenIdIsBitIdenticalOnTheNoPayloadPath(uint64 poolId) public {
        assertEq(
            h.tokenIdWithNoneExtra(VO, poolId),
            ref.tokenIdFromVolOrder(VO, poolId),
            "the generic builder changed the tokenId"
        );
    }

    // Phase 2's map is NOT the Haskell map yet: the Haskell volOrderToTokenId takes a 4-tuple of
    // optionRatios (1..127) and sets asset = 1 on every leg, while the Plank Layer-1 map hardcodes
    // optionRatio = 1 and leaves asset unset (vol_order_to_mint adds it). Pinned here so Phase 3
    // (VORD-04/05, the FLAG_PANOPTIC dereference) has to flip it deliberately.
    function test__unit__phase2MapStillHardcodesRatioOneAndNoAsset() public {
        uint256 tid = h.tokenIdWithNoneExtra(VO, 42);
        for (uint256 leg = 0; leg < 4; leg++) {
            uint256 base = 64 + 48 * leg;
            assertEq((tid >> (base + 1)) & 0x7f, 1, "optionRatio is not the Haskell tuple yet (VORD-04)");
            assertEq((tid >> base) & 0x1, 0, "asset is not set by the Layer-1 map yet (VORD-05)");
        }
    }

    // ---- what must NOT compile ----------------------------------------------------------------

    /// Extra.plk guards T with std::regions::is_region, so a non-region T is our error, not a
    /// stray one from deeper in std.
    function test__unit__nonRegionTagDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolOrderBadRegion.plk");
        assertTrue(r.exitCode != 0, "VolOrder(u256) compiled; Extra must reject a non-region T");
        assertTrue(_contains(r.stderr, "Extra: T must be a region"), "wrong failure: not Extra's guard");
    }

    /// `extra` is an Option, so the descriptor's fields are not directly reachable.
    function test__unit__extraFieldsNeedUnwrap() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolOrderExtraNeedsUnwrap.plk");
        assertTrue(r.exitCode != 0, "vo.extra.flags compiled; Option's payload must need unwrap");
    }

    // ---- helpers -----------------------------------------------------------------------------

    /// `plank build <path>` with the same module roots as PlankTestBase.plankOpts(), no deploy.
    function _tryBuild(string memory path) internal returns (Vm.FfiResult memory) {
        string[] memory a = new string[](17);
        a[0] = "plank"; a[1] = "build"; a[2] = path; a[3] = "--backend"; a[4] = "sona";
        a[5] = "--dep"; a[6] = "v3=lib/plankified-univ3/plank/lib";
        a[7] = "--dep"; a[8] = "std=lib/plank-monorepo/std/";
        a[9] = "--dep"; a[10] = "pos_spec=src/types/pos_spec";
        a[11] = "--dep"; a[12] = "lib=src/lib";
        a[13] = "--dep"; a[14] = "types=src/types";
        a[15] = "--dep"; a[16] = "interfaces=src/interfaces";
        return vm.tryFfi(a);
    }

    function _contains(bytes memory hay, string memory needle) internal pure returns (bool) {
        bytes memory n = bytes(needle);
        if (n.length > hay.length) return false;
        for (uint256 i = 0; i + n.length <= hay.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (hay[i + j] != n[j]) { ok = false; break; }
            }
            if (ok) return true;
        }
        return false;
    }
}
