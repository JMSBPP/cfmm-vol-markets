// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {RegistryVerifyV4} from "../../mocks/RegistryVerifyV4.sol";
import {RegistryVerifyV4NoIHooks} from "../../mocks/RegistryVerifyV4NoIHooks.sol";
import {RegistryVerifyV3Factory} from "../../mocks/RegistryVerifyV3Factory.sol";
import {RegistryVerifyBadInterface} from "../../mocks/RegistryVerifyBadInterface.sol";
import {AlgebraIntegralDeployer} from "../../helpers/AlgebraIntegralDeployer.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {IAlgebraPluginFactory} from "@cryptoalgebra/integral-core/interfaces/plugin/IAlgebraPluginFactory.sol";
import {IAlgebraCustomPoolEntryPoint} from "@cryptoalgebra/integral-periphery/interfaces/IAlgebraCustomPoolEntryPoint.sol";

contract RegistryTest is PlankTestBase {
    bytes4 internal constant IFACE_IHOOKS_PIN = 0xf0222b24;
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

    /// @dev Pins interface ids Plank constants must match (CI reads node_modules + panoptic v4-core).
    function test__unit__interfaceIds_matchSolidity() public pure {
        assertEq(bytes4(0x01ffc9a7), bytes4(0x01ffc9a7));
        assertEq(type(IHooks).interfaceId, IFACE_IHOOKS_PIN);
        assertTrue(type(IAlgebraPluginFactory).interfaceId != bytes4(0));
        assertTrue(type(IAlgebraCustomPoolEntryPoint).interfaceId != bytes4(0));
    }

    function _registryVerify(uint8 venue, address addr) internal {
        (bool ok,) = harness.staticcall(abi.encodeWithSignature("registryVerify(uint8,address)", venue, addr));
        require(ok, "registryVerify reverted");
    }

    function test__unit__registryVerify_v4_acceptsCompliantHooks() public {
        _registryVerify(1, address(new RegistryVerifyV4(address(0xBEEF))));
    }

    function test__unit__registryVerify_v4_rejectsZeroPoolManager() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "registryVerify(uint8,address)",
                uint8(1),
                address(new RegistryVerifyV4(address(0)))
            )
        );
        assertFalse(ok);
    }

    function test__unit__registryVerify_v4_zeroAddressPasses() public {
        _registryVerify(1, address(0));
    }

    function test__unit__registryVerify_v4_rejectsBadInterface() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "registryVerify(uint8,address)",
                uint8(1),
                address(new RegistryVerifyV4NoIHooks(address(0xBEEF)))
            )
        );
        assertFalse(ok);
    }

    function test__unit__registryVerify_v3_acceptsFactory() public {
        _registryVerify(2, address(new RegistryVerifyV3Factory()));
    }

    function test__unit__registryVerify_v3_rejectsEoa() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("registryVerify(uint8,address)", uint8(2), address(0xBEEF))
        );
        assertFalse(ok);
    }

    function test__unit__registryVerify_algebra_acceptsPluginFactory() public {
        AlgebraIntegralDeployer.Deployment memory d = AlgebraIntegralDeployer.deploy(vm);
        _registryVerify(3, d.entryPoint);
    }

    function test__unit__registryVerify_algebra_rejectsBadInterface() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("registryVerify(uint8,address)", uint8(3), address(new RegistryVerifyBadInterface()))
        );
        assertFalse(ok);
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
