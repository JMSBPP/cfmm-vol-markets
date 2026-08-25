// SPDX-License-Identifier: MIT
// ^0.8.24: joins the v4-core (0.8.26) compilation graph. Do NOT import the @cryptoalgebra refs
// here (they pin =0.8.20 and cannot share this graph) -- see DynamicFeeHookE2E.t.sol's header.
// This is the v4 half of mev_tax_model_one: the VolumePath price-invariance replay against the
// live DynamicFeeHook rig. The Algebra north-star (writer beforeSwap phi_M) is a SEPARATE test.
pragma solidity ^0.8.24;

import {PlankTestBase} from "../../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";
import {StateLibrary} from "univ4-core/libraries/StateLibrary.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "univ4-core/types/BalanceDelta.sol";
import {PoolSwapTest} from "univ4-core/test/PoolSwapTest.sol";
import {V4StateReader} from "@libraries/V4StateReader.sol";

interface IERC20Min {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// @notice Gate B (v4): replay the GAMS solver's dQx VolumePath through the live DynamicFeeHook
/// pool and prove price invariance with a strictly-positive LP fee payoff. The fixture
/// (volume_path.json) is produced by the rpc_api bridge against the v4 rig; VOLUME_PATH.md is
/// itself v4-flavored (§3 "Suggested v4 mapping: amountSpecified = −dQx[n], zeroForOne = dQx[n]>0").
///
/// LIVE-RIG INTEGRATION test, run as: deploy-rig -> capture-loop -> forge (--fork-block-number
/// forkHeight, same rig) -> deploy-rig --stop. The rig block height is per-run, so the fixture's
/// blockNumber is meaningful ONLY on the rig that produced it; the guard forks at that height and
/// skips (fails-CLOSED, naming the arm) when no such rig is reachable -- on CI's rig-less --offline
/// forge job this self-skips. EXPLICIT EXCEPTION to #29's "never skip" rule: #29's fail-loud still
/// governs wrong-chain / attach-not-construct (both require-revert below), never the no-rig case.
contract MevTaxVolumePathV4Test is PlankTestBase {
    using PoolIdLibrary for PoolKey;
    using stdJson for string;

    string constant FIXTURE = "test/models/mev_tax_model_one/fixtures/volume_path.json";
    string constant CONF = "offchain/rig/loop-conformance.json";
    string constant MANIFEST = "offchain/rig/rig-manifest.json"; // gitignored; on-disk post-deploy-rig only
    uint24 constant DYNAMIC_FEE_FLAG = 0x800000; // LPFeeLibrary.DYNAMIC_FEE_FLAG

    function test__priceInvarianceUnderVolumePath() public {
        if (!vm.exists(FIXTURE)) {
            vm.skip(true, "awaiting volume_path.json - off-chain rpc_api bridge (#25), delegated");
            return;
        }
        string memory json = vm.readFile(FIXTURE);
        address fxPool = json.readAddress(".pool");
        uint256 fxBlock = vm.parseUint(json.readString(".blockNumber"));
        uint256 fxChainId = json.readUint(".chainId");
        uint160 fxSqrtPrice = uint160(vm.parseUint(json.readString(".sqrtPriceX96")));
        uint128 fxLiquidity = uint128(vm.parseUint(json.readString(".liquidity")));
        int256[] memory dQx = json.readIntArray(".dQx");
        uint256 nEvents = json.readUint(".nEvents");
        require(nEvents > 0, "empty path");
        require(dQx.length == nEvents, "dQx length != nEvents");

        // --- Conformance arm: the fixture must have been published by the SAME run whose forkHeight
        // we fork at (block height is per-run), and its rig.poolId is one leg of the 3-way identity.
        if (!vm.exists(CONF)) {
            vm.skip(true, string.concat("loop-conformance.json absent at ", CONF, " - run the live sequence"));
            return;
        }
        string memory conf = vm.readFile(CONF);
        uint256 forkHeight = vm.parseUint(conf.readString(".forkHeight"));
        bytes32 confPoolId = conf.readBytes32(".rig.poolId");
        if (fxBlock != forkHeight) {
            vm.skip(true, string.concat(
                "fixture.blockNumber ", vm.toString(fxBlock), " != loop-conformance forkHeight ",
                vm.toString(forkHeight), " - the fixture on disk was not produced by this run"
            ));
            return;
        }

        // --- Manifest arm: gitignored, present only after deploy-rig. Its absence means no live rig.
        if (!vm.exists(MANIFEST)) {
            vm.skip(true, string.concat(
                MANIFEST, " absent - live-rig integration test; run deploy-rig -> capture-loop -> this on the same rig"
            ));
            return;
        }

        // --- Liveness (fails-CLOSED). __rigHead forks in an EXTERNAL self-call so the cheatcode
        // revert on an unreachable/offline endpoint is a catchable external-call revert.
        string memory url = vm.envOr("ETH_RPC_URL", vm.rpcUrl("local"));
        try this.__rigHead(url) returns (uint256 head) {
            if (head < fxBlock) {
                vm.skip(true, string.concat(
                    "VolumePath: rig head ", vm.toString(head), " < fork target ", vm.toString(fxBlock),
                    " at ", url, " - run deploy-rig -> capture-loop -> this test on the SAME rig"
                ));
                return;
            }
        } catch {
            vm.skip(true, string.concat(
                "VolumePath: no node reachable at ", url,
                " - live-rig integration test; CI's --offline forge job has no rig, so it skips here."
            ));
            return;
        }
        vm.createSelectFork(url, fxBlock);
        require(block.chainid == fxChainId, "VolumePath: wrong chain (check ETH_RPC_URL)");
        require(fxPool.code.length > 0, "VolumePath: pool not deployed on fork (attach, not construct)");

        // --- Reconstruct the PoolKey from the rig manifest (its identity file, same rig).
        string memory man = vm.readFile(MANIFEST);
        address c0 = man.readAddress(".pool.currency0");
        address c1 = man.readAddress(".pool.currency1");
        int24 ts = int24(int256(man.readUint(".pool.tickSpacing")));
        address hook = man.readAddress(".contracts.DynamicFeeHook");
        bytes32 manPoolId = man.readBytes32(".pool.poolId");
        IPoolManager mgr = IPoolManager(man.readAddress(".contracts.PoolManager"));
        address swapRouter = man.readAddress(".contracts.PoolSwapTest");

        (address a0, address a1) = c0 < c1 ? (c0, c1) : (c1, c0); // v4 sorts currency0 < currency1
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(a0),
            currency1: Currency.wrap(a1),
            fee: DYNAMIC_FEE_FLAG,
            tickSpacing: ts,
            hooks: IHooks(hook)
        });
        PoolId poolId = key.toId();
        bytes32 keyId = PoolId.unwrap(poolId);
        // Three-way identity: my reconstruction == the manifest's == the artifact's.
        assertEq(keyId, manPoolId, "PoolKey.toId() != manifest .pool.poolId");
        assertEq(keyId, confPoolId, "PoolKey.toId() != loop-conformance .rig.poolId");

        // --- State read via extsload (the PoolManager is a v4 singleton; IAlgebraPool calls revert).
        assertEq(uint256(V4StateReader.getSqrtPriceX96(mgr, poolId)), uint256(fxSqrtPrice), "sqrtPrice != fixture");
        assertEq(uint256(StateLibrary.getLiquidity(mgr, poolId)), uint256(fxLiquidity), "liquidity != fixture");

        int24 tickBefore = V4StateReader.getTick(mgr, poolId);
        (uint256 fg0Before, uint256 fg1Before) = StateLibrary.getFeeGrowthGlobals(mgr, poolId);

        // --- Fund address(this) and approve the router (rig tokens are ERC20 on the fork).
        deal(a0, address(this), 1e30);
        deal(a1, address(this), 1e30);
        IERC20Min(a0).approve(swapRouter, type(uint256).max);
        IERC20Min(a1).approve(swapRouter, type(uint256).max);

        // --- Replay the dQx path. §3 v4 mapping: amountSpecified = −dQx[n], zeroForOne = dQx[n] > 0.
        // No vm.warp: the DynamicFeeHook records one timepoint per uint32 timestamp, so all legs at
        // the fork block's timestamp see the fixture's single fee -- exactly what the golden was
        // solved against. Full-range liquidity (L = fixture) so non-terminal legs limit at the band
        // edge and consume fully; the LAST leg limits at the start sqrtPrice to halt at the start
        // tick (§3), which the closure assertion then confirms.
        for (uint256 i = 0; i < nEvents; i++) {
            bool zeroForOne = dQx[i] > 0;
            int256 amountSpecified = -dQx[i];
            uint160 limit = (i == nEvents - 1)
                ? fxSqrtPrice
                : (zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1);
            BalanceDelta delta = PoolSwapTest(swapRouter).swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: amountSpecified,
                    sqrtPriceLimitX96: limit
                }),
                PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
                bytes("")
            );
            // The X (token0/dQx) axis is amount0 in both directions: exact-input zeroForOne pays
            // amount0 == amountSpecified (<0); exact-output oneForZero receives amount0 ==
            // amountSpecified (>0). Full consumption on non-terminal legs (terminal leg is limited).
            if (i < nEvents - 1) {
                assertEq(int256(BalanceDeltaLibrary.amount0(delta)), amountSpecified, "leg under-filled (left the band?)");
            }
        }

        // --- Price invariance: the round-trip (dQx sums to ~0, last leg pinned at start) closes the tick.
        assertEq(V4StateReader.getTick(mgr, poolId), tickBefore, "tick did not return to start (price not invariant)");

        // --- Strictly-positive LP payoff: at the invariant price the whole delta is fees from phi_M > 0.
        (uint256 fg0After, uint256 fg1After) = StateLibrary.getFeeGrowthGlobals(mgr, poolId);
        assertTrue(fg0After > fg0Before || fg1After > fg1Before, "LP fee payoff must be strictly positive (phiMpips > 0)");
    }

    /// @dev External so a fork against an unreachable/offline endpoint reverts as a CATCHABLE
    /// external-call revert (a same-contract cheatcode revert cannot be try/catch-ed). Returns the
    /// reachable rig's head; _the caller compares it to the fork target and skips if below.
    function __rigHead(string calldata url) external returns (uint256) {
        uint256 forkId = vm.createFork(url); // reverts (caught by the test) if unreachable/offline
        vm.selectFork(forkId);
        return block.number;
    }
}
