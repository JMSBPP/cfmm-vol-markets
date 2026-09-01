// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";

/// RED-first: PoolId.plk does not exist until Task 2 GREEN.
contract PoolIdTest is PlankTestBase {
    address internal harness;

    uint256 internal constant C0 = 0x1111;
    uint256 internal constant C1 = 0x2222;
    uint256 internal constant FEE = 3000;
    uint256 internal constant TICK_SPACING = 60;
    uint256 internal constant HOOKS = 0x3333;

    function setUp() public {
        harness = deployPlank("test/types/protocol_integrations/PoolIdHarness.plk");
    }

    function test__unit__allThreeVenuesInstantiate() public {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("venueWitness()"));
        require(ok, "venueWitness reverted");
        assertEq(abi.decode(r, (uint256)), 57, "venue codes wrong");
    }

    function test__unit__poolIdV4FromKeyMatchesSolidityPoolIdLibrary() public {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "poolIdV4FromKey(uint256,uint256,uint256,uint256,uint256)",
                C0,
                C1,
                FEE,
                TICK_SPACING,
                HOOKS
            )
        );
        require(ok, "poolIdV4FromKey reverted");
        assertEq(
            abi.decode(r, (uint256)),
            uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, HOOKS))),
            "must equal PoolIdLibrary.toId encoding"
        );
    }

    function test__unit__nonVenueTagDoesNotCompile() public {
        Vm.FfiResult memory res = _tryBuild("fixtures/plank-negative/PoolIdBadVenue.plk");
        assertTrue(res.exitCode != 0, "PoolId(u256) compiled");
        assertTrue(
            _contains(res.stderr, "PoolId: V must be V4, V3 or Algebra"),
            "wrong failure: not PoolId guard"
        );
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
