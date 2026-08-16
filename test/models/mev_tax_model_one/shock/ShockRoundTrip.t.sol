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
}
