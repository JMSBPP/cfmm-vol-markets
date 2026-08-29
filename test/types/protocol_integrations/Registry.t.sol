// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";

contract RegistryTest is PlankTestBase {
    address internal harness;
    address internal constant HOOKS_ADDR = address(0x00000000000000000000000000000000000000AB);

    function setUp() public {
        harness = deployPlank("test/types/protocol_integrations/RegistryHarness.plk");
    }

    function test__unit__allThreeVenuesInstantiate() public {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("venueWitness()"));
        require(ok, "venueWitness reverted");
        assertEq(abi.decode(r, (uint256)), 57, "venue codes wrong: a comptime branch is mis-wired");
    }

    function test__unit__registryAddrRoundTrip() public {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("registryAddr(address)", HOOKS_ADDR));
        require(ok, "registryAddr reverted");
        assertEq(abi.decode(r, (uint256)), uint256(uint160(HOOKS_ADDR)), "registry_addr round-trip");
    }

    function test__unit__nonVenueTagDoesNotCompile() public {
        Vm.FfiResult memory res = _tryBuild("fixtures/plank-negative/RegistryBadVenue.plk");
        assertTrue(res.exitCode != 0, "Registry(u256) compiled; is_venue must reject a non-venue V");
        assertTrue(
            _contains(res.stderr, "Registry: V must be V4, V3 or Algebra"),
            "wrong failure: not Registry's guard"
        );
    }

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
