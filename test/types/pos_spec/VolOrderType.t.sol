// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Entry points of test/types/pos_spec/VolOrderTypeHarness.plk.
interface IVolOrderTypeHarness {
    function roundTripNone(uint256 packed) external returns (uint256);
    function extraIsNoneAfterUnpack(uint256 packed) external returns (uint256);
    function tokenIdViaExtra(uint256 packed, uint256 poolId) external returns (uint256);
    function extraDecodeFlags(bytes calldata data) external returns (uint256);
    function packIgnoresExtra(uint256 packed, bytes calldata data) external returns (uint256);
    function unwrapNoneReverts(uint256 packed) external returns (uint256);
}

/// @notice The pre-refactor tokenId map, for the bit-identity comparison.
interface IVolOrderToPanopticTokenIdHarness {
    function tokenIdFromVolOrder(uint256 packed, uint256 poolId) external returns (uint256);
}

/// @title VolOrderTypeTest
/// @notice Tests for the VolOrder(T) TYPE (Phase 2, VORD-01), written to
///         .planning/phases/02-volorder-t-minimal-instantiation/02-REGRESSION-ASSESSMENT.md §4a and
///         RED-first: they are pushed against a tree WITHOUT the type and must fail, proving they
///         detect its absence, before the implementation is written.
/// @dev What §4a makes testable, and what each test pins:
///      - absence is std Option/None, a VALUE -- so `extra` is None after unpack, and reading
///        through it REVERTS at runtime rather than yielding zero;
///      - Extra(T).data is a tagged ADDRESS SPACE (flags byte, plus a pointer word under
///        FLAG_PANOPTIC) whose length must be the one the flags imply -- Shock's rule;
///      - pack/unpack stay region-agnostic: `extra` never enters the 248-bit word;
///      - the builder RETURNS the updated VolOrder(T) with the tokenId landed in `extra`, and that
///        tokenId is bit-identical to the pre-refactor map's.
///      Plank type-checks only what something instantiates, so the negatives cannot live in a green
///      harness: they are static fixtures under fixtures/plank-negative/ built through vm.tryFfi.
contract VolOrderTypeTest is PlankTestBase {
    IVolOrderTypeHarness internal h;
    IVolOrderToPanopticTokenIdHarness internal ref;

    uint256 internal constant MASK_248 = (uint256(1) << 248) - 1;
    uint256 internal constant FLAG_PANOPTIC = 0x01;

    // A valid packed VolOrder: width 2000, tickSpacing 10, volStrike 1, skew 0x8000, targetVega 0.
    uint256 internal constant VO =
        (uint256(2000) << 128) | (uint256(10) << 104) | (uint256(1) << 16) | 0x8000;

    function setUp() public {
        h = IVolOrderTypeHarness(deployPlank("test/types/pos_spec/VolOrderTypeHarness.plk"));
        ref = IVolOrderToPanopticTokenIdHarness(
            deployPlank("test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk")
        );
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

    // ---- Extra(T).data is a tagged address space ----------------------------------------------

    function test__unit__flagsZeroAcceptsExactlyTheFlagByte() public {
        assertEq(h.extraDecodeFlags(hex"00"), 0, "flags=0 with a 1-byte payload must decode");
    }

    function test__unit__panopticFlagRequiresThePointerWord() public {
        bytes memory withPtr = abi.encodePacked(uint8(FLAG_PANOPTIC), uint256(0x1234));
        assertEq(h.extraDecodeFlags(withPtr), FLAG_PANOPTIC, "flags=PANOPTIC with a pointer must decode");
    }

    function test__unit__panopticFlagWithoutThePointerReverts() public {
        vm.expectRevert();
        h.extraDecodeFlags(hex"01"); // FLAG_PANOPTIC but no pointer word: length contradicts flags
    }

    function test__unit__reservedFlagBitsRevert() public {
        vm.expectRevert();
        h.extraDecodeFlags(hex"02"); // nothing but FLAG_PANOPTIC is defined in Phase 2
    }

    // ---- pack/unpack stay region-agnostic -----------------------------------------------------

    function test__fuzz__packIgnoresExtraEntirely(uint256 x) public {
        bytes memory withPtr = abi.encodePacked(uint8(FLAG_PANOPTIC), uint256(0xdeadbeef));
        assertEq(
            h.packIgnoresExtra(x, withPtr),
            x & MASK_248,
            "carrying Some(Extra) changed the packed word"
        );
    }

    // ---- the builder returns VolOrder(T) with the tokenId landed in `extra` --------------------

    function test__fuzz__tokenIdLandsInExtraAndIsBitIdentical(uint64 poolId) public {
        assertEq(
            h.tokenIdViaExtra(VO, poolId),
            ref.tokenIdFromVolOrder(VO, poolId),
            "tokenId read out of `extra` differs from the pre-refactor map"
        );
    }

    // Phase 2's map is NOT the Haskell map yet: the Haskell volOrderToTokenId takes a 4-tuple of
    // optionRatios (1..127) and sets asset = 1 on every leg, while the Plank Layer-1 map hardcodes
    // optionRatio = 1 and leaves asset unset (vol_order_to_mint adds it). Pinned here so Phase 3
    // (VORD-04/05, the FLAG_PANOPTIC dereference) has to flip it deliberately and this test reddens
    // when it does -- rather than the difference living only in prose.
    function test__unit__phase2MapStillHardcodesRatioOneAndNoAsset() public {
        uint256 tid = h.tokenIdViaExtra(VO, 42);
        for (uint256 leg = 0; leg < 4; leg++) {
            uint256 base = 64 + 48 * leg;
            assertEq((tid >> (base + 1)) & 0x7f, 1, "optionRatio is not the Haskell tuple yet (VORD-04)");
            assertEq((tid >> base) & 0x1, 0, "asset is not set by the Layer-1 map yet (VORD-05)");
        }
    }

    // ---- what must NOT compile ----------------------------------------------------------------

    // VolOrder(u256) is rejected transitively: Extra(T) holds bytes(T), and std's region_ptr_type
    // ends in a compile error for an unrecognised region. (Plain comment, not NatSpec: solc reads a
    // leading at-sign in /// as a doc tag -- Error 6546.)
    function test__unit__nonRegionTagDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolOrderBadRegion.plk");
        assertTrue(r.exitCode != 0, "VolOrder(u256) compiled; nothing rejects a non-region T");
    }

    /// `extra` is an Option, so its payload is not a directly reachable field.
    function test__unit__extraPayloadNeedsUnwrap() public {
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
}
