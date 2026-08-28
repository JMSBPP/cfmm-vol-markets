// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";

/// Phase 2.5 (KEY-01): VolMarketKey(V) is a comptime type constructor over a VENUE tag.
///
/// The property under test is a TYPE-LEVEL one, so the evidence is split in two:
///   - the POSITIVE side is that the harness compiles with all three venues instantiated AND
///     reachable from run{} -- plank never type-checks an unreachable branch, which is how the
///     Phase 2 negative test was caught being meaningless on gate 33181644493;
///   - the NEGATIVE side is a fixture that must FAIL to compile, asserted on the error TEXT rather
///     than the exit code, because a fixture containing a typo also fails to compile.
contract VolMarketKeyTest is PlankTestBase {
    address harness;

    function setUp() public {
        harness = deployPlank("test/protocol_integrations/VolMarketKeyHarness.plk");
    }

    // ---- what must compile ---------------------------------------------------------------------

    /// venueWitness() instantiates all three venue keys and returns a per-venue code, so the
    /// assertion is not merely "it compiled": a mis-wired comptime branch changes the value.
    ///   venue_code(V4)=1, (V3)=2, (Algebra)=3  ->  1 | 2<<2 | 3<<4 = 57
    function test__unit__allThreeVenuesInstantiate() public {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("venueWitness()"));
        require(ok, "venueWitness reverted");
        assertEq(abi.decode(r, (uint256)), 57, "venue codes wrong: a comptime branch is mis-wired");
    }

    // ---- what must NOT compile -----------------------------------------------------------------

    /// VolMarketKey.plk guards V with is_venue, so a non-venue tag is OUR error, not a stray one
    /// from deeper in std. The stderr match is what makes this test mean something: without it a
    /// typo in the fixture would produce the same non-zero exit and the test would pass vacuously.
    function test__unit__nonVenueTagDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolMarketKeyBadVenue.plk");
        assertTrue(
            r.exitCode != 0, "VolMarketKey(u256) compiled; is_venue must reject a non-venue V"
        );
        assertTrue(
            _contains(r.stderr, "VolMarketKey: V must be V4, V3 or Algebra"),
            "wrong failure: not VolMarketKey's guard"
        );
    }

    // ---- helpers -----------------------------------------------------------------------------

    /// `plank build <path>` with the same module roots as PlankTestBase.plankOpts(), no deploy.
    /// Copied from test/types/pos_spec/VolOrderType.t.sol so the two negative harnesses stay in step.
    function _tryBuild(string memory path) internal returns (Vm.FfiResult memory) {
        string[] memory a = new string[](19);
        a[0] = "plank";
        a[1] = "build";
        a[2] = path;
        a[3] = "--backend";
        a[4] = "sona";
        a[5] = "--dep";
        a[6] = "v3=lib/plankified-univ3/plank/lib";
        a[7] = "--dep";
        a[8] = "std=lib/plank-monorepo/std/";
        a[9] = "--dep";
        a[10] = "pos_spec=src/types/pos_spec";
        a[11] = "--dep";
        a[12] = "lib=src/lib";
        a[13] = "--dep";
        a[14] = "types=src/types";
        a[15] = "--dep";
        a[16] = "interfaces=src/interfaces";
        a[17] = "--dep";
        a[18] = "helpers=test/protocol_integrations/helpers";
        return vm.tryFfi(a);
    }

    function _contains(bytes memory hay, string memory needle) internal pure returns (bool) {
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > hay.length) return false;
        for (uint256 i = 0; i + n.length <= hay.length; i++) {
            bool m = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (hay[i + j] != n[j]) {
                    m = false;
                    break;
                }
            }
            if (m) return true;
        }
        return false;
    }
}
