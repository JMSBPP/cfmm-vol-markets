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

    // ---- KEY-06 / F1: the asset/numeraire inversion ---------------------------------------------

    /// Panoptic's `asset` bit names the CASH token that positionSize is denominated in
    /// (TokenId.sol:112-116; PanopticMath.getLiquidityChunk "in TradFi, the asset is always cash").
    /// This protocol calls that token the NUMERAIRE and calls the OTHER one the asset, so the
    /// mapping INVERTS asset_index.
    ///
    /// BOTH values are asserted deliberately: a copy instead of a NOT agrees at asset_index == 1
    /// and differs only at 0, so a single-value test would pass on the wrong implementation.
    ///
    /// This is the highest-consequence assertion in the phase. Inverted, the builder emits a
    /// STRUCTURALLY VALID tokenId denominated in the wrong token: Panoptic's validate() passes,
    /// the position mints, position_size_for_target_vega inverts the wrong formula, and nothing
    /// reverts. It survives a green gate, which is why the phase's criterion 9 singles it out.
    function test__unit__panopticAssetBitInvertsAssetIndex() public {
        (bool ok0, bytes memory r0) =
            harness.staticcall(abi.encodeWithSignature("panopticAssetBit(uint256)", uint256(0)));
        require(ok0, "panopticAssetBit(0) reverted");
        assertEq(
            abi.decode(r0, (uint256)),
            1,
            "asset_index 0 (currency0 is the asset) => numeraire is currency1 => Panoptic bit 1"
        );

        (bool ok1, bytes memory r1) =
            harness.staticcall(abi.encodeWithSignature("panopticAssetBit(uint256)", uint256(1)));
        require(ok1, "panopticAssetBit(1) reverted");
        assertEq(
            abi.decode(r1, (uint256)),
            0,
            "asset_index 1 (currency1 is the asset) => numeraire is currency0 => Panoptic bit 0"
        );
    }

    /// asset_index indexes a PAIR, so its domain is {0, 1}. Anything else is a caller error and
    /// must revert rather than be silently masked -- a masked 2 would read as 0 and pick the wrong
    /// currency, which is the same failure as the inversion with a different cause.
    function test__unit__assetIndexAboveOneReverts() public {
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("panopticAssetBit(uint256)", uint256(2)));
        assertFalse(ok, "asset_index == 2 must revert, not mask to 0");
    }

    // ---- KEY-02: the pool PATTERN is 40 bits and VENUE-SPECIFIC ---------------------------------

    /// SFPM V4: uint40(uint256(PoolId.unwrap(idV4))) -- the LOW 40 bits of the v4 PoolId.
    function test__fuzz__v4PatternIsTheLowFortyBits(uint256 idV4) public {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v4Pattern(uint256)", idV4));
        require(ok, "v4Pattern reverted");
        assertEq(abi.decode(r, (uint256)), idV4 & ((uint256(1) << 40) - 1), "V4 pattern = low 40");
    }

    /// SFPM V3: uint40(uint160(univ3pool) >> 120) -- the HIGH 40 bits of the 160-bit ADDRESS.
    /// Not the low bits. This is the half of KEY-02 most likely to be written wrong by analogy
    /// with V4, so it is asserted independently rather than derived from the V4 case.
    function test__fuzz__v3PatternIsTheHighFortyBitsOfTheAddress(address pool) public {
        uint256 a = uint256(uint160(pool));
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v3Pattern(uint256)", a));
        require(ok, "v3Pattern reverted");
        assertEq(abi.decode(r, (uint256)), (a >> 120) & ((uint256(1) << 40) - 1), "V3 = addr >> 120");
    }

    /// The two derivations must not be assumed identical. Fed the same word they disagree, which
    /// is the property a shared implementation would silently break.
    function test__unit__v3AndV4PatternsDifferForTheSameWord() public {
        // Leading 00 is REQUIRED, not cosmetic: a bare 40-hex-digit literal is parsed by solc as an
        // address literal and rejected for a bad checksum (Error 9429). Same numeric value.
        uint256 w = 0x001234567890abcdef1122334455667788aabbccdd;
        (, bytes memory r4) = harness.staticcall(abi.encodeWithSignature("v4Pattern(uint256)", w));
        (, bytes memory r3) = harness.staticcall(abi.encodeWithSignature("v3Pattern(uint256)", w));
        assertTrue(
            abi.decode(r4, (uint256)) != abi.decode(r3, (uint256)),
            "the venue patterns must not be assumed identical"
        );
    }

    /// poolId = [16b tickSpacing at 48][8b vegoid at 40][40b pattern at 0]  (PanopticMath.sol:28).
    /// The in-contract prose in both SFPMs says "most significant 48 bits"; the CODE says 40, and
    /// the code is what this mirrors.
    function test__fuzz__composePoolIdLayout(uint40 pattern, uint8 vegoid, uint16 tickSpacing)
        public
    {
        // vegoid is 1..255. CONSTRUCTED into range, not filtered with vm.assume -- the project's
        // differential discipline is that corpora are built rather than rejected, so no run is
        // discarded and the non-vacuity of the 256 runs is not silently eroded.
        uint256 v = bound(uint256(vegoid), 1, 255);

        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "composePoolId(uint256,uint256,uint256)",
                uint256(pattern),
                v,
                uint256(tickSpacing)
            )
        );
        require(ok, "composePoolId reverted");
        uint256 id = abi.decode(r, (uint256));
        assertEq(id & ((uint256(1) << 40) - 1), pattern, "pattern at 0..39");
        assertEq((id >> 40) & 0xff, v, "vegoid at 40..47");
        assertEq((id >> 48) & 0xffff, tickSpacing, "tickSpacing at 48..63");
    }

    /// vegoid == 0 is rejected at composition, not just at the payload: the poolId itself would
    /// otherwise carry a value the SFPM refuses (Errors.InvalidTokenIdParameter(0)).
    function test__unit__composePoolIdRejectsZeroVegoid() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("composePoolId(uint256,uint256,uint256)", uint256(1), uint256(0), uint256(60))
        );
        assertFalse(ok, "vegoid == 0 must revert at composition");
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
