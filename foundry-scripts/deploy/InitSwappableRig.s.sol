// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {PlankDeployBase} from "./PlankDeployBase.s.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";
import {BalanceDelta} from "univ4-core/types/BalanceDelta.sol";
import {PoolSwapTest} from "univ4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "univ4-core/test/PoolModifyLiquidityTest.sol";

interface IRigToken {
    function mint(address to, uint256 amt) external;
    function approve(address s, uint256 amt) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// @notice Issue #17: takes the Phase-20 rig (DeployDynamicFeeHook.s.sol, run FIRST) to a
/// SWAPPABLE state so timepoints self-write via beforeSwap: deploys the two canonical
/// v4-core unlock-callback routers (vendored, nothing authored), funds + approves the
/// deployer, mints ONE full-range liquidity position, and proves the write path with a
/// probe swap whose assert is the hook's lastTimepointTimestamp STRICTLY ADVANCING.
///
/// ENV (REQUIRED — the deploy script's printed manifest, already sorted):
///   POOL_MANAGER, HOOK, TOKEN0, TOKEN1
///
/// USAGE (anvil running, deploy script already broadcast):
///   forge script foundry-scripts/deploy/InitSwappableRig.s.sol --tc InitSwappableRig \
///     --rpc-url local --broadcast --via-ir
/// (no --ffi: this script is pure Solidity. --broadcast is REQUIRED — the rpc_api manifest
/// workflow cross-checks broadcast JSON against the printed lines.)
///
/// FULL-RANGE-ONLY IS LOAD-BEARING (spec G4): the drivers cheat slot0, so ticks are never
/// CROSSED; any interior initialized tick boundary would leave pool.liquidity stale
/// relative to a cheated tick. One full-range position => active liquidity is uniform over
/// the whole usable range. Do NOT mint additional ranges on this rig. The cheat domain is
/// ticks STRICTLY inside [minUsableTick(20), maxUsableTick(20)] = [-887260, +887260]; the
/// TickMath-valid slivers out to +-887272 sit OUTSIDE the position.
///
/// TOKENS: ERC20-strict, no native-ETH rig. Funding is deterministic on both paths:
/// best-effort mint (MinimalToken has open mint) then a hard balance floor — a pre-funded
/// real ERC20 without mint() passes the same gate.
contract InitSwappableRig is PlankDeployBase {
    using PoolIdLibrary for PoolKey;

    uint24 constant DYNAMIC_FEE_FLAG = 0x800000;
    int24 constant TICK_SPACING = 20; // MUST match DeployDynamicFeeHook (module pin, F2)
    uint256 constant MINT_AMOUNT = 1e30;
    uint256 constant FUNDING_FLOOR = 2e21; // full-range 1e21 liquidity needs ~1e21 of each
    int256 constant LIQUIDITY = 1e21;
    int256 constant PROBE_AMOUNT = -1e6; // exact-input probe, dust vs 1e21 liquidity

    // DynamicFeeHook.plk storage: "DynamicFeeHook.RealizedVolState";
    // lastTimepointTimestamp = bits [16,48) of the packed state word.
    bytes32 constant SLOT_HOOK_VOL_STATE =
        0x91c2de35e9b1cd8617b30455b6419a0f1f09097cbab1521247ad5712c4211808;
    bytes4 constant SEL_POOL_ID = 0x3e0dc34e; // poolId() -> bytes32
    bytes4 constant SEL_AVG_VOL = 0x8171455c; // getAverageVolatility(int24,uint32) -> uint88

    function run()
        public
        returns (address swapRouter, address modifyLiquidityRouter)
    {
        address pm = vm.envAddress("POOL_MANAGER");
        address hook = vm.envAddress("HOOK");
        address t0 = vm.envAddress("TOKEN0");
        address t1 = vm.envAddress("TOKEN1");

        // Step 0: deterministic env sanity. A codeless address makes every low-level call
        // below succeed vacuously and the run would die 4 calls deep in settlement.
        require(t0 < t1, "TOKEN0/TOKEN1 must be the SORTED manifest currencies");
        require(pm.code.length > 0, "POOL_MANAGER has no code");
        require(hook.code.length > 0, "HOOK has no code");
        require(t0.code.length > 0, "TOKEN0 has no code");
        require(t1.code.length > 0, "TOKEN1 has no code");

        // Step 1: clock advance — the deploy script seeded the vol buffer at its own
        // block.timestamp and the write guard is TIMESTAMP equality (one timepoint per
        // distinct uint32 second). Back-to-back deploy+init in one wall-second would
        // B1-no-op the probe. Advance both the simulation clock and (anvil only) the node.
        uint256 target = block.timestamp + 5;
        vm.warp(target);
        if (block.chainid == 31337) {
            // low-level, NOT vm.rpc(): anvil returns the raw offset word for
            // evm_increaseTime, which fails the typed cheatcode's bytes-decode.
            (bool okRpc,) = address(vm).call(
                abi.encodeWithSignature("rpc(string,string)", "evm_increaseTime", "[5]")
            );
            require(okRpc, "evm_increaseTime rpc failed");
        }

        uint256 pk = deployerKey();
        address deployer = vm.addr(pk);

        // Reconstruct the PoolKey EXACTLY as deployed and bind-check EARLY: key drift must
        // fail here with a clear message, not as PoolNotInitialized inside modifyLiquidity.
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(t0),
            currency1: Currency.wrap(t1),
            fee: DYNAMIC_FEE_FLAG,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hook)
        });
        bytes32 pid = PoolId.unwrap(key.toId());
        (bool okPid, bytes memory ridPid) = hook.staticcall(abi.encodeWithSelector(SEL_POOL_ID));
        require(okPid && ridPid.length == 32, "hook.poolId() staticcall failed");
        require(
            abi.decode(ridPid, (bytes32)) == pid,
            "reconstructed PoolKey does not hash to the hook's bound poolId (key drift)"
        );

        uint32 tsBefore = _lastTimepointTimestamp(hook);

        vm.startBroadcast(pk);

        // Step 2: the canonical unlock-callback routers.
        PoolSwapTest swapR = new PoolSwapTest(IPoolManager(pm));
        PoolModifyLiquidityTest liqR = new PoolModifyLiquidityTest(IPoolManager(pm));

        // Step 3: fund (best-effort mint, hard balance floor) + approve BOTH routers.
        // Settlement is CurrencySettler.settle -> transferFrom(sender -> manager) pulled BY
        // THE ROUTER, so allowance goes deployer->router (NOT deployer->PoolManager).
        _fund(t0, deployer, address(swapR), address(liqR));
        _fund(t1, deployer, address(swapR), address(liqR));

        // Step 5: the ONE full-range position.
        int24 tickLower = TickMath.minUsableTick(TICK_SPACING);
        int24 tickUpper = TickMath.maxUsableTick(TICK_SPACING);
        liqR.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: LIQUIDITY,
                salt: bytes32(0)
            }),
            ""
        );

        // Step 6: probe swap — PoolManager -> hook.beforeSwap -> rv_write_timepoint -> fee
        // override. Not nested in any outer unlock (PoolSwapTest requires deltaBefore == 0).
        BalanceDelta delta = swapR.swap(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: PROBE_AMOUNT,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );

        vm.stopBroadcast();

        // THE assert: the probe PROVED the write path iff the hook's timepoint clock
        // strictly advanced (a same-second B1 no-op would leave it unchanged).
        uint32 tsAfter = _lastTimepointTimestamp(hook);
        require(
            tsAfter > tsBefore,
            "probe swap wrote NO timepoint (same-second B1 no-op?) - rig NOT proven"
        );

        // Read-back: the vol series is servable after the probe (uint88 in a 32-byte word).
        (bool okVol, bytes memory retVol) =
            hook.staticcall(abi.encodeWithSelector(SEL_AVG_VOL, int24(0), uint32(target)));
        require(okVol && retVol.length == 32, "getAverageVolatility read-back failed");

        swapRouter = address(swapR);
        modifyLiquidityRouter = address(liqR);

        console.log("swapRouter            :", swapRouter);
        console.log("modifyLiquidityRouter :", modifyLiquidityRouter);
        console.log("tickLower             :", vm.toString(int256(tickLower)));
        console.log("tickUpper             :", vm.toString(int256(tickUpper)));
        console.log("liquidity             :", vm.toString(LIQUIDITY));
        console.log("probe delta0          :", vm.toString(int256(delta.amount0())));
        console.log("probe delta1          :", vm.toString(int256(delta.amount1())));
        console.log("timepoint ts before   :", vm.toString(uint256(tsBefore)));
        console.log("timepoint ts after    :", vm.toString(uint256(tsAfter)));
    }

    function _fund(address token, address deployer, address swapR, address liqR) internal {
        try IRigToken(token).mint(deployer, MINT_AMOUNT) {} catch {}
        require(
            IRigToken(token).balanceOf(deployer) >= FUNDING_FLOOR,
            "token balance below funding floor: mint() unavailable and not pre-funded"
        );
        require(IRigToken(token).approve(swapR, type(uint256).max), "approve swapRouter failed");
        require(IRigToken(token).approve(liqR, type(uint256).max), "approve liqRouter failed");
    }

    function _lastTimepointTimestamp(address hook) internal view returns (uint32) {
        return uint32(uint256(vm.load(hook, SLOT_HOOK_VOL_STATE)) >> 16);
    }
}
