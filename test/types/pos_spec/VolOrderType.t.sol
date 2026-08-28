// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

/// @notice Entry points of test/types/pos_spec/VolOrderTypeHarness.plk.
interface IVolOrderTypeHarness {
    function roundTripNone(uint256 packed) external returns (uint256);
    function baseOfMemory(uint256 packed, bytes calldata extra) external returns (uint256, uint256, bytes32);
    function baseOfCalldata(uint256 packed, bytes calldata extra) external returns (uint256, uint256, bytes32);
    function tokenIdOfNone(uint256 packed, uint256 poolId) external returns (uint256);
    function tokenIdOfMemory(uint256 packed, uint256 poolId, bytes calldata extra) external returns (uint256);
    function tokenIdOfCalldata(uint256 packed, uint256 poolId, bytes calldata extra) external returns (uint256);
}

/// @title VolOrderTypeTest
/// @notice Tests for the VolOrder(T) TYPE (Phase 2, VORD-01) -- written RED-first, before the
///         constructor existed. The regression floor (VolOrderToPanopticTokenId.t.sol) proves the
///         OLD behaviour survived; this file proves the NEW type: every branch of the constructor
///         instantiates, `extra` is a live region view, the projection drops exactly `extra`, T does
///         not leak into the tokenId, and the two things that must NOT compile do not.
/// @dev Plank type-checks only what something instantiates, so a branch no harness reaches is text
///      the compiler has never seen. The negative cases cannot live in a green harness; they are
///      static fixtures under fixtures/plank-negative/ (outside compile-plank's src/test scan) that
///      this test builds through vm.tryFfi and expects to FAIL with the right message.
contract VolOrderTypeTest is PlankTestBase {
    IVolOrderTypeHarness internal h;

    uint256 internal constant MASK_248 = (uint256(1) << 248) - 1;

    // A valid packed VolOrder (V2 layout: skew@0 | vol@16 | tickSpacing@104 | width@128 | vega@152).
    // Same shape the differential's impl side uses: width 2000, ts 10, vol 1, skew 0x8000, vega 0.
    uint256 internal constant VO = (uint256(2000) << 128) | (uint256(10) << 104) | (uint256(1) << 16) | 0x8000;

    function setUp() public {
        h = IVolOrderTypeHarness(deployPlank("test/types/pos_spec/VolOrderTypeHarness.plk"));
    }

    // ---- VolOrder(none): the minimal instantiation IS the old struct -------------------------

    /// pack(unpack(x)) on VolOrder(none) is the identity on the 248-bit word.
    function test__fuzz__noneRoundTripsThePackedWord(uint256 x) public {
        assertEq(h.roundTripNone(x), x & MASK_248, "VolOrder(none) codec is not the identity on 248 bits");
    }

    // ---- VolOrder(memory) / VolOrder(calldata): the rich branches compile and carry a live view --

    function test__unit__memoryCarriesExtraAsALiveView() public {
        bytes memory extra = hex"deadbeef00000000000000000000000000000000000000000000000000000000cafe";
        (uint256 base, uint256 len, bytes32 first) = h.baseOfMemory(VO, extra);
        assertEq(base, VO, "vol_order_base(memory, vo) must drop exactly `extra`");
        assertEq(len, extra.length, "extra.length not carried through VolOrder(memory)");
        assertEq(first, _firstWord(extra), "first word read through the memory view differs");
    }

    function test__unit__calldataCarriesExtraAsALiveView() public {
        bytes memory extra = hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20ff";
        (uint256 base, uint256 len, bytes32 first) = h.baseOfCalldata(VO, extra);
        assertEq(base, VO, "vol_order_base(calldata, vo) must drop exactly `extra`");
        assertEq(len, extra.length, "extra.length not carried through VolOrder(calldata)");
        assertEq(first, _firstWord(extra), "first word read through the calldata view differs");
    }

    function test__unit__emptyExtraIsAValidView() public {
        (uint256 base, uint256 len,) = h.baseOfMemory(VO, "");
        assertEq(base, VO);
        assertEq(len, 0, "zero-length extra must be representable");
    }

    // ---- T does not leak into the tokenId (Phase 2's whole claim; Phase 3 breaks it on purpose) --

    function test__fuzz__tokenIdIsInvariantInTheRegionTag(uint64 poolId, bytes memory extra) public {
        uint256 n = h.tokenIdOfNone(VO, poolId);
        assertEq(h.tokenIdOfMemory(VO, poolId, extra), n, "T = memory changed the tokenId");
        assertEq(h.tokenIdOfCalldata(VO, poolId, extra), n, "T = calldata changed the tokenId");
    }

    // ---- What must NOT compile ---------------------------------------------------------------

    // VolOrder(u256) hits the constructor's @compile_error fallthrough. (Plain comment, not NatSpec:
    // solc reads a leading at-sign in NatSpec as a doc tag -- Error 6546 -- see VolOrderDecoder.sol.)
    function test__unit__badRegionTagDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolOrderBadTag.plk");
        assertTrue(r.exitCode != 0, "VolOrder(u256) compiled; the @compile_error fallthrough is dead");
        assertTrue(_contains(r.stderr, "VolOrder: T must be none, memory or calldata"), "wrong failure: not the constructor's message");
    }

    /// `.extra` on VolOrder(none) is a missing field -- the tag's entire point.
    function test__unit__noneHasNoExtraField() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolOrderNoneExtra.plk");
        assertTrue(r.exitCode != 0, "reading .extra on VolOrder(none) compiled");
        assertTrue(_contains(r.stderr, "extra"), "wrong failure: the error does not name `extra`");
    }

    // ---- helpers -----------------------------------------------------------------------------

    /// `plank build <path>` with the same roots as PlankTestBase.plankOpts(), without deploying.
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

    function _firstWord(bytes memory b) internal pure returns (bytes32 w) {
        assembly { w := mload(add(b, 32)) }
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
