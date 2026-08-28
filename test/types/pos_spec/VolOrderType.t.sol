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
///      - Extra(T) is a tagged DESCRIPTOR, flags(u8)@248 | offset(u32)@216 | len(u16)@200, whose
///        len must be the one its flags imply (76 bits under FLAG_PANOPTIC, 0 otherwise);
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
    uint256 internal constant PANOPTIC_BITS = 76; // poolId 48 + 4 x 7-bit ratios

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
        h.extraDecodeFields(_descriptor(FLAG_PANOPTIC, 0x24, 80)); // 80 != 76: len contradicts flags
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
        string[] memory a = new string[](19);
        a[0] = "plank"; a[1] = "build"; a[2] = path; a[3] = "--backend"; a[4] = "sona";
        a[5] = "--dep"; a[6] = "v3=lib/plankified-univ3/plank/lib";
        a[7] = "--dep"; a[8] = "std=lib/plank-monorepo/std/";
        a[9] = "--dep"; a[10] = "pos_spec=src/types/pos_spec";
        a[11] = "--dep"; a[12] = "lib=src/lib";
        a[13] = "--dep"; a[14] = "types=src/types";
        a[15] = "--dep"; a[16] = "interfaces=src/interfaces";
        a[17] = "--dep"; a[18] = "helpers=test/protocol_integrations/helpers";
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
