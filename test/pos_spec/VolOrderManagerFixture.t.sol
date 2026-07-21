// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VolOrderManagerBatchBase} from "./VolOrderManagerBatch.t.sol";

// ===========================================================================================
// MVER-03: THE CONSUMER GOLDEN FIXTURE.
//
// THIS FILE BUILDS NOTHING. It contains no production code, mutates no `.plk` surface, and
// exists purely to compare bytes the module already produces against bytes produced elsewhere.
// A RED HERE IS A FINDING ABOUT src/modules/pos_spec/VolOrderManagerMod.plk -- NEVER a licence
// to edit that module, and never a licence to regenerate the fixture until it agrees. If the
// module and the fixture disagree, report BOTH byte strings and stop.
//
// WHY THIS IS NOT A SECOND LOOK AT THE SAME ENCODER. Phase 18b diffed the module's returndata
// against `abi.encode(BatchResult[])` -- that is solc. The oracle HERE is `cast abi-encode`,
// which is ALLOY's ABI coder: a different implementation, by different authors, living outside
// this repository, invoked as a committed FILE of recorded bytes rather than as a library call.
// Two independent encoders agreeing on the layout Phase 18b pinned -- outer offset 0x20, length
// in ELEMENTS, static (bool,uint256) tuples inlined at stride 0x40, total exactly 64 + 64N --
// is the strongest evidence in this milestone that the hand-rolled Plank encoder is correct.
//
// SCOPE LIMIT, STATED PLAINLY AND NOT TO BE BLURRED IN ANY SUMMARY OR EXIT RECORD:
//   (a) alloy confirms the bytes are STANDARD-ABI conformant.   <- what this file proves
//   (b) the actual Haskell consumer's decoder accepts them.     <- NOT proven here.
// Peer mv15a18k has not delivered Haskell-produced bytes. That gap is asserted, per case, by
// test__unit__peerHaskellBytesAreStillAnOpenGap below, so it stays VISIBLE rather than being
// quietly absorbed by the alloy result.
//
// DISCIPLINE: no vm.assume; the corpus is CONSTRUCTED and committed; every case is driven
// through FFI-deployed bytecode, because "it compiles" is never acceptance.
// ===========================================================================================

/// @title VolOrderManagerFixtureTest
/// @notice The MVER-03 differential: module returndata vs bytes from an encoder outside this repo.
contract VolOrderManagerFixtureTest is VolOrderManagerBatchBase {
    string internal constant FIXTURE = "test/pos_spec/fixtures/vol_order_return_golden.json";

    /// @notice THE MVER-03 DIFFERENTIAL. Drives the FFI-deployed module with each fixture case's
    ///         recorded inputs and asserts the returndata is byte-identical to bytes produced by
    ///         cast (alloy), an encoder OUTSIDE this repo.
    ///
    ///         FALSIFIABLE BY CONSTRUCTION, NEVER SATISFIABLE BY INACTION: the case count, the
    ///         per-case byte lengths and the final casesChecked tally are all asserted, so a
    ///         deleted, emptied or truncated fixture FAILS this test rather than vacuously
    ///         passing over zero cases.
    function test__unit__moduleReturnMatchesExternalEncoderFixture() public {
        string memory json = vm.readFile(FIXTURE);

        string[] memory names = vm.parseJsonStringArray(json, ".names");
        uint256[] memory seeds = vm.parseJsonUintArray(json, ".seedCounts");
        uint256[] memory ns = vm.parseJsonUintArray(json, ".ns");
        uint256[] memory strikes = vm.parseJsonUintArray(json, ".strikes");
        uint256[] memory widths = vm.parseJsonUintArray(json, ".widths");
        uint256[] memory skews = vm.parseJsonUintArray(json, ".skews");
        string[] memory expected = vm.parseJsonStringArray(json, ".expected");

        // THE ANTI-INACTION GATE. An empty or shrunken fixture must FAIL here, loudly.
        assertEq(names.length, 5, "MVER-03: the fixture must carry exactly 5 cases");
        assertEq(expected.length, 5, "MVER-03: one expected byte string per case");
        assertEq(seeds.length, 5, "seedCounts parallel to names");
        assertEq(ns.length, 5, "ns parallel to names");

        uint256 flat = 0;
        for (uint256 i = 0; i < ns.length; i++) {
            flat += ns[i];
        }
        assertEq(flat, strikes.length, "flat tuple arrays agree with ns");
        assertEq(strikes.length, widths.length, "strikes/widths parallel");
        assertEq(strikes.length, skews.length, "strikes/skews parallel");

        uint256 casesChecked = 0;
        uint256 cursor = 0;

        for (uint256 i = 0; i < names.length; i++) {
            bytes memory want = vm.parseBytes(expected[i]);
            // A well-formed (bool,uint256)[] encoding is NEVER shorter than 64 bytes.
            assertEq(
                want.length, 64 + 64 * ns[i], string.concat(names[i], ": fixture bytes are 64 + 64N")
            );

            // A FRESH module per case, so cases cannot contaminate each other's id sequence.
            address m = deployPlank("src/modules/pos_spec/VolOrderManagerMod.plk");
            vm.store(m, SLOT_ORDER_COUNT, bytes32(seeds[i]));

            uint256[] memory words = new uint256[](ns[i]);
            for (uint256 j = 0; j < ns[i]; j++) {
                words[j] = packInput(strikes[cursor + j], widths[cursor + j], skews[cursor + j]);
            }
            cursor += ns[i];

            (bool ok, bytes memory got) = m.call(encodeBatch(words));

            assertTrue(ok, string.concat(names[i], ": the batch must not revert"));
            // THE KILL SITE, first among the discriminating assertions.
            assertEq(
                keccak256(got),
                keccak256(want),
                string.concat(names[i], ": module returndata vs cast(alloy) golden bytes, tol 0")
            );
            assertEq(got.length, want.length, string.concat(names[i], ": length (localisation aid)"));
            casesChecked++;
        }

        assertEq(casesChecked, 5, "MVER-03: every fixture case was actually driven");
    }

    /// @notice The N=0 case, called out separately because its failure is INVISIBLE on-chain and
    ///         lands in the Haskell client. cast independently agrees the empty encoding is
    ///         EXACTLY 64 bytes -- offset 0x20 then a zero length -- not 0 and not 32.
    function test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes() public view {
        string memory json = vm.readFile(FIXTURE);
        string[] memory expected = vm.parseJsonStringArray(json, ".expected");
        bytes memory empty = vm.parseBytes(expected[0]);
        assertEq(empty.length, 64, "cast agrees: the empty (bool,uint256)[] is 64 bytes");
        assertEq(wordAt(empty, 0), 0x20, "cast agrees: outer offset word is 0x20");
        assertEq(wordAt(empty, 32), 0, "cast agrees: length word is zero ELEMENTS");
    }

    /// @notice The peer gap, asserted rather than merely commented. This test PASSES while the
    ///         placeholders stand and its message names the gap; when peer mv15a18k delivers,
    ///         replace the placeholders and INVERT this assertion into a real cross-language
    ///         byte check -- the same way test__unit__batchSelectorNotYetDispatched was inverted
    ///         when 18a landed, rather than deleted.
    function test__unit__peerHaskellBytesAreStillAnOpenGap() public view {
        string memory json = vm.readFile(FIXTURE);
        string[] memory peer = vm.parseJsonStringArray(json, ".peer_haskell_bytes");
        assertEq(peer.length, 5, "one peer slot per case, so the gap is per-case visible");
        for (uint256 i = 0; i < peer.length; i++) {
            assertEq(
                peer[i],
                "PLACEHOLDER -- NOT-PEER-VERIFIED",
                "peer bytes undelivered: alloy confirms STANDARD ABI, not the consumer's decoder"
            );
        }
    }
}
