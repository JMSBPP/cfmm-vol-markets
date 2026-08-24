// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../../PlankTestBase.sol";
import {BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

/// @notice CHAIN-01 (#26): the deployable Shock emitter. ShockWriterMod is a thin, driveable
/// contract whose one entrypoint mines a single canonical
/// `Shock(address indexed pool, int24 tickDiff, uint24 txlVolmNormRate, uint24 txlVolmDecay)`
/// event so the rpc_api live loop (offchain/rig/capture-loop.sh) has a Shock to poll. Unlike the
/// writer's beforeSwap (swap-driven) or ShockHarness (a test harness), this is a production
/// emitter another process drives directly: `shock(address,int24,uint24,uint24)`, flags-all
/// internally so the event always carries all three data words. Values are VOLUME_PATH.md §2's.
contract ShockWriterEmitTest is PlankTestBase {
    BuildOptions model_opts;
    address writer;

    // cast sig "shock(address,int24,uint24,uint24)"
    bytes4 constant SEL_SHOCK = 0x5342da2b;
    bytes32 constant SHOCK_TOPIC0 = 0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64;

    // The values capture-loop.sh's DRIVE step carries (confirmed from Loop/Run.hs, not memory):
    // tickDiff 0; txlVolmNormRate = 490000 (δ*, 0.49 in pips, se_norm_rate); txlVolmDecay = 0
    // (26-02: decay never reaches the prover). The golden fee 6497 is NOT a shock field — the loop
    // takes the fee from the pinned pool read, never from the event.
    int24 constant V2_TICK_DIFF = 0;
    uint24 constant V2_NORM = 490000;
    uint24 constant V2_DECAY = 0;

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
        writer = plankDeployFFI("src/models/mev_tax_model_one/modules/ShockWriterMod.plk", model_opts);
    }

    /// One MINED-shaped call emits exactly one canonical Shock with the pinned topic0, the pool as
    /// the indexed topic1, and the §2 field values in data. This is what capture-loop.sh drives.
    function test__unit__shock_emitsOneCanonicalShock_liveValues() public {
        address pool = address(0xA1CE); // capture-loop drives this with contracts.PoolManager

        vm.recordLogs();
        (bool ok,) = writer.call(
            abi.encodeWithSelector(SEL_SHOCK, pool, V2_TICK_DIFF, V2_NORM, V2_DECAY)
        );
        require(ok, "shock() reverted");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "exactly one Shock log");
        assertEq(logs[0].topics.length, 2, "topic0 + indexed pool");
        assertEq(logs[0].topics[0], SHOCK_TOPIC0, "topic0 = keccak Shock(address,int24,uint24,uint24)");
        assertEq(address(uint160(uint256(logs[0].topics[1]))), pool, "indexed pool == topic1");

        (int24 tick, uint24 norm, uint24 decay) = abi.decode(logs[0].data, (int24, uint24, uint24));
        assertEq(tick, V2_TICK_DIFF, "tickDiff = 0");
        assertEq(norm, V2_NORM, "txlVolmNormRate = 490000 (delta*)");
        assertEq(decay, V2_DECAY, "txlVolmDecay = 0");
    }

    /// Flags are internal/all-present: every field round-trips even when the driver passes only
    /// scalars (no flags byte), including a negative tickDiff (sign-aware data word).
    function test__unit__shock_allFieldsPresent_signAware() public {
        address pool = address(0xB0B);
        vm.recordLogs();
        (bool ok,) = writer.call(
            abi.encodeWithSelector(SEL_SHOCK, pool, int24(-100), uint24(1), uint24(2))
        );
        require(ok, "shock() reverted");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "one Shock log");
        (int24 tick, uint24 norm, uint24 decay) = abi.decode(logs[0].data, (int24, uint24, uint24));
        assertEq(tick, int24(-100), "negative tickDiff decodes sign-aware");
        assertEq(norm, uint24(1), "norm present");
        assertEq(decay, uint24(2), "decay present");
    }
}
