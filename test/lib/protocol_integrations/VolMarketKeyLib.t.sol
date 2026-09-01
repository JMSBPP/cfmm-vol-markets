// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";
import {RegistryVerifyV4} from "test/mocks/RegistryVerifyV4.sol";

/// Minimal stand-in for BOTH SFPMs: `getPoolId(bytes memory id, uint8 vegoid) -> uint64`.
/// Lives on test state; lib verify forwards client-supplied vegoid to this contract.
contract SfpmStub {
    uint64 internal immutable ID;

    constructor(uint64 id_) {
        ID = id_;
    }

    function getPoolId(bytes calldata, uint8) external view returns (uint64) {
        return ID;
    }
}

/// VolMarketKeyLib — Panoptic pool-id derivation (RED: lib + PanopticPoolId type not implemented yet).
contract VolMarketKeyLibTest is PlankTestBase {
    address harness;
    address v4Registry;

    uint256 internal constant C0 = 0x1111;
    uint256 internal constant C1 = 0x2222;
    uint256 internal constant FEE = 3000;
    uint256 internal constant TICK_SPACING = 60;
    uint8 internal constant VEGOID = 8;

    function setUp() public {
        harness = deployPlank("test/lib/protocol_integrations/VolMarketKeyLibHarness.plk");
        v4Registry = address(new RegistryVerifyV4(address(0x1)));
    }

    function test__unit__goldenPathEndToEndPanoptic() public {
        uint64 expected = _expectedV4PoolId(VEGOID, TICK_SPACING);
        address sfpm = address(new SfpmStub(expected));
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "goldenPathPanoptic(uint256,address,uint256)", v4Registry, sfpm, uint256(VEGOID)
            )
        );
        require(ok, "goldenPathPanoptic reverted");
        assertEq(abi.decode(r, (uint256)), expected, "golden path must reach Panoptic derivation");
    }

    function test__unit__panopticOnIncompleteKeyReverts() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("panopticPoolIdOnEmpty(uint256,uint256)", v4Registry, uint256(8))
        );
        assertFalse(ok, "incomplete key must not reach Panoptic derivation");
    }

    function test__fuzz__v4PatternIsTheLowFortyBits(uint256 idV4) public {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v4Pattern(uint256)", idV4));
        require(ok, "v4Pattern reverted");
        assertEq(abi.decode(r, (uint256)), idV4 & ((uint256(1) << 40) - 1), "V4 pattern = low 40");
    }

    function test__fuzz__v3PatternIsTheHighFortyBitsOfTheAddress(address pool) public {
        uint256 a = uint256(uint160(pool));
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v3Pattern(uint256)", a));
        require(ok, "v3Pattern reverted");
        assertEq(abi.decode(r, (uint256)), (a >> 120) & ((uint256(1) << 40) - 1), "V3 = addr >> 120");
    }

    function test__unit__v3AndV4PatternsDifferForTheSameWord() public {
        uint256 w = 0x001234567890abcdef1122334455667788aabbccdd;
        (, bytes memory r4) = harness.staticcall(abi.encodeWithSignature("v4Pattern(uint256)", w));
        (, bytes memory r3) = harness.staticcall(abi.encodeWithSignature("v3Pattern(uint256)", w));
        assertTrue(
            abi.decode(r4, (uint256)) != abi.decode(r3, (uint256)),
            "the venue patterns must not be assumed identical"
        );
    }

    function test__fuzz__composePoolIdLayout(uint40 pattern, uint8 vegoid, uint16 tickSpacing) public {
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

    function test__unit__composePoolIdRejectsZeroVegoid() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("composePoolId(uint256,uint256,uint256)", uint256(1), uint256(0), uint256(60))
        );
        assertFalse(ok, "vegoid == 0 must revert at composition");
    }

    function test__unit__poolIdCandidateMatchingTheSfpmIsReturned() public {
        uint64 expected = _expectedV4PoolId(VEGOID, TICK_SPACING);
        address sfpm = address(new SfpmStub(expected));

        (bool okDerive, bytes memory rDerive) = harness.staticcall(
            abi.encodeWithSignature("panopticPoolIdV4(uint256,uint256)", v4Registry, uint256(VEGOID))
        );
        require(okDerive, "derive reverted");
        uint256 candidate = abi.decode(rDerive, (uint256));
        assertEq(candidate, expected, "derive must match expected layout");

        uint256 poolIdentity = uint256(
            keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, v4Registry))
        );
        (bool okVerify,) = harness.staticcall(
            abi.encodeWithSignature(
                "verifySfpmLegacy(uint256,address,uint256,uint256)",
                candidate,
                sfpm,
                poolIdentity,
                uint256(VEGOID)
            )
        );
        assertTrue(okVerify, "SFPM legacy verify must agree with derive");
    }

    function test__unit__poolIdCollisionMismatchReverts() public {
        uint64 incremented = _expectedV4PoolId(VEGOID, TICK_SPACING) + 1;
        address sfpm = address(new SfpmStub(incremented));

        (bool okDerive, bytes memory rDerive) = harness.staticcall(
            abi.encodeWithSignature("panopticPoolIdV4(uint256,uint256)", v4Registry, uint256(VEGOID))
        );
        require(okDerive, "derive reverted");
        uint256 candidate = abi.decode(rDerive, (uint256));

        uint256 poolIdentity = uint256(
            keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, v4Registry))
        );
        (bool okVerify,) = harness.staticcall(
            abi.encodeWithSignature(
                "verifySfpmLegacy(uint256,address,uint256,uint256)",
                candidate,
                sfpm,
                poolIdentity,
                uint256(VEGOID)
            )
        );
        assertFalse(okVerify, "collision-incremented SFPM id must revert at verify");
    }

    function test__unit__algebraKeyIntoPanopticArmDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolMarketKeyAlgebraToPanoptic.plk");
        assertTrue(r.exitCode != 0, "an Algebra key reached the Panoptic arm");
        assertTrue(
            _contains(r.stderr, "VolMarketKeyLib: Panoptic arm accepts only V4 or V3"),
            "wrong failure: not the Panoptic-arm guard"
        );
    }

    function _expectedV4PoolId(uint8 vegoid, uint256 tickSpacing) internal view returns (uint64) {
        uint256 poolIdV4 = uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, v4Registry)));
        uint256 pattern = poolIdV4 & ((uint256(1) << 40) - 1);
        return uint64(pattern | (uint256(vegoid) << 40) | (tickSpacing << 48));
    }

    function _tryBuild(string memory path) internal returns (Vm.FfiResult memory) {
        string[] memory a = new string[](17);
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
