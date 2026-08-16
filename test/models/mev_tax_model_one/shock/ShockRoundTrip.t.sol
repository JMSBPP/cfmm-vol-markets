// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../../PlankTestBase.sol";
import {BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

/// @notice RED-first round-trip for the packed Shock hookData: shock_encode -> shock_decode ->
/// accessors, driven through a plank harness (CALLED-green, not merely compiled). v6.0 sends only
/// txlVolmNormRate (flags = 0b010); tickDiff and txlVolmDecay decode to 0 even though nonzero
/// candidate values are passed -- the "absent guarantees zero" property behind the emitted event.
/// Rates are uint24 pip-denominated ([0,1] at 1e6); tickDiff is a signed int24 tick delta.
contract ShockRoundTripTest is PlankTestBase {
    BuildOptions model_opts;
    address harness;
    bytes4 constant SEL = 0xffa8e21b; // roundtrip(uint8,int24,uint24,uint24)
    bytes4 constant SEL_ENCODE = 0xd290eec8; // encode(uint8,int24,uint24,uint24)
    bytes4 constant SEL_DECODE_RAW = 0x8270f10a; // decodeRaw(bytes)

    uint256 constant FLAG_TICK  = 0x01;
    uint256 constant FLAG_NORM  = 0x02;
    uint256 constant FLAG_DECAY = 0x04;

    function setUp() public {
        model_opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](8);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        deps[1] = Dependency("std", "lib/plank-monorepo/std/");
        deps[2] = Dependency("pos_spec", "src/types/pos_spec");
        deps[3] = Dependency("lib", "src/lib");
        deps[4] = Dependency("types", "src/types");
        deps[5] = Dependency("interfaces", "src/interfaces");
        deps[6] = Dependency("model_interfaces", "src/models/mev_tax_model_one/interfaces/");
        deps[7] = Dependency("model_libraries", "src/models/mev_tax_model_one/libraries/");
        model_opts.dependencies = deps;
        harness = plankDeployFFI("test/models/mev_tax_model_one/shock/ShockHarness.plk", model_opts);
    }

    function _roundtrip(uint8 flags, int24 tick, uint24 norm, uint24 decay)
        internal
        returns (int24 tickOut, uint24 normOut, uint24 decayOut)
    {
        (bool ok, bytes memory ret) = harness.call(abi.encodeWithSelector(SEL, flags, tick, norm, decay));
        require(ok, "roundtrip reverted");
        (tickOut, normOut, decayOut) = abi.decode(ret, (int24, uint24, uint24));
    }

    // v6.0: flags = 0b010 carries ONLY txlVolmNormRate. tickDiff=111 and txlVolmDecay=333 are passed
    // but their bits are unset -> encode must not write them -> decode returns 0.
    function test__unit__roundtrip_txlVolmNormRateOnly() public {
        (int24 tick, uint24 norm, uint24 decay) =
            _roundtrip(uint8(FLAG_NORM), int24(111), uint24(222), uint24(333));
        assertEq(tick, int24(0), "tickDiff absent -> 0");
        assertEq(norm, uint24(222), "txlVolmNormRate survives");
        assertEq(decay, uint24(0), "txlVolmDecay absent -> 0");
    }

    function test__unit__roundtrip_tickDiffOnly_negative() public {
        (int24 tick, uint24 norm, uint24 decay) =
            _roundtrip(uint8(FLAG_TICK), int24(-100), uint24(222), uint24(333));
        assertEq(tick, int24(-100), "negative tickDiff survives (sign-extended)");
        assertEq(norm, uint24(0), "txlVolmNormRate absent -> 0");
        assertEq(decay, uint24(0), "txlVolmDecay absent -> 0");
    }

    function test__unit__roundtrip_txlVolmDecayOnly() public {
        (int24 tick, uint24 norm, uint24 decay) =
            _roundtrip(uint8(FLAG_DECAY), int24(111), uint24(222), uint24(333));
        assertEq(tick, int24(0), "tickDiff absent -> 0");
        assertEq(norm, uint24(0), "txlVolmNormRate absent -> 0");
        assertEq(decay, uint24(333), "txlVolmDecay survives");
    }

    // flags = 0b101: tickDiff + txlVolmDecay, norm absent. Pins offset-skipping — decay sits at
    // byte offset 4 (1 flags + 3 tickDiff), NOT 7.
    function test__unit__roundtrip_tickDiffAndDecay_skipsAbsentNorm() public {
        (int24 tick, uint24 norm, uint24 decay) =
            _roundtrip(uint8(FLAG_TICK | FLAG_DECAY), int24(-2048), uint24(222), uint24(999));
        assertEq(tick, int24(-2048), "tickDiff survives");
        assertEq(norm, uint24(0), "txlVolmNormRate absent -> 0");
        assertEq(decay, uint24(999), "txlVolmDecay survives at the skipped offset");
    }

    // flags = 0b111: all present, offsets 1/4/7, full 10-byte layout, at the type boundaries.
    function test__unit__roundtrip_allPresent_boundaries() public {
        (int24 tick, uint24 norm, uint24 decay) = _roundtrip(
            uint8(FLAG_TICK | FLAG_NORM | FLAG_DECAY), int24(-8388608), uint24(16777215), uint24(1000000)
        );
        assertEq(tick, int24(-8388608), "min int24 tickDiff survives"); // -2^23
        assertEq(norm, uint24(16777215), "max uint24 norm survives"); // 2^24 - 1
        assertEq(decay, uint24(1000000), "decay = 1e6 (100% in pips) survives");
    }

    // ----- Packed-layout differential: plank shock_encode vs an independent Solidity oracle -----
    // The plank encoder must produce byte-exact the same tagged hookData as abi.encodePacked at the
    // native widths -- the independent witness for the tag scheme (mirrors the multicall lib diff).

    function _oracleEncode(uint8 flags, int24 tick, uint24 norm, uint24 decay)
        internal
        pure
        returns (bytes memory out)
    {
        out = abi.encodePacked(flags);
        if (flags & 0x01 != 0) out = abi.encodePacked(out, tick);
        if (flags & 0x02 != 0) out = abi.encodePacked(out, norm);
        if (flags & 0x04 != 0) out = abi.encodePacked(out, decay);
    }

    function _plankEncode(uint8 flags, int24 tick, uint24 norm, uint24 decay)
        internal
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) =
            harness.call(abi.encodeWithSelector(SEL_ENCODE, flags, tick, norm, decay));
        require(ok, "encode reverted");
        return ret;
    }

    function _popcount(uint8 f) internal pure returns (uint256 k) {
        k = (f & 1) + ((f >> 1) & 1) + ((f >> 2) & 1);
    }

    function _assertLayout(uint8 flags, int24 tick, uint24 norm, uint24 decay) internal {
        bytes memory plank = _plankEncode(flags, tick, norm, decay);
        assertEq(plank, _oracleEncode(flags, tick, norm, decay), "plank packed bytes != Solidity oracle");
        assertEq(plank.length, 1 + 3 * _popcount(flags), "packed length != 1 + 3*popcount");
    }

    function test__unit__diff_layout_v6_normOnly() public {
        _assertLayout(uint8(FLAG_NORM), int24(0), uint24(222), uint24(0));
    }

    function test__unit__diff_layout_negativeTick() public {
        _assertLayout(uint8(FLAG_TICK), int24(-100), uint24(0), uint24(0));
    }

    function test__unit__diff_layout_tickAndDecay_skipsNorm() public {
        _assertLayout(uint8(FLAG_TICK | FLAG_DECAY), int24(-2048), uint24(0), uint24(999));
    }

    function test__unit__diff_layout_allPresent_boundaries() public {
        _assertLayout(uint8(FLAG_TICK | FLAG_NORM | FLAG_DECAY), int24(-8388608), uint24(16777215), uint24(1000000));
    }

    function test__unit__diff_layout_empty() public {
        _assertLayout(uint8(0), int24(123), uint24(456), uint24(789)); // all absent -> just the flags byte
    }

    // ----- Malformed-decode reverts + a calldata-path decode witness (the beforeSwap path) -----

    function _decodeRaw(bytes memory data) internal returns (bool ok) {
        (ok,) = harness.call(abi.encodeWithSelector(SEL_DECODE_RAW, data));
    }

    function test__unit__decode_reverts_reservedFlagBit() public {
        // flags = 0x08 (bit 3) is reserved -> revert before any length check.
        assertFalse(_decodeRaw(abi.encodePacked(uint8(0x08))), "reserved flag bit must revert");
    }

    function test__unit__decode_reverts_lengthTooShort() public {
        // flags = 0x02 needs 1 + 3 = 4 bytes; give only the flags byte.
        assertFalse(_decodeRaw(abi.encodePacked(uint8(0x02))), "short length must revert");
    }

    function test__unit__decode_reverts_lengthTooLong() public {
        // flags = 0x00 needs exactly 1 byte; give 4.
        assertFalse(_decodeRaw(abi.encodePacked(uint8(0x00), uint24(123))), "long length must revert");
    }

    // Region-generic decode on the CALLDATA path (what beforeSwap uses) -- valid v6 payload.
    function test__unit__decode_calldata_valid_v6() public {
        (bool ok, bytes memory ret) =
            harness.call(abi.encodeWithSelector(SEL_DECODE_RAW, abi.encodePacked(uint8(0x02), uint24(222))));
        require(ok, "valid calldata decode reverted");
        (int24 tick, uint24 norm, uint24 decay) = abi.decode(ret, (int24, uint24, uint24));
        assertEq(tick, int24(0), "tickDiff absent -> 0");
        assertEq(norm, uint24(222), "txlVolmNormRate survives (calldata path)");
        assertEq(decay, uint24(0), "txlVolmDecay absent -> 0");
    }
}
