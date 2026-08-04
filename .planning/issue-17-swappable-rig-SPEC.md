# Issue #17 — Swappable DynamicFeeHook rig (init script) — SPEC v2 (post two-step review)

Requestor: rpc_api workstream (issue #17). Goal: after `DeployDynamicFeeHook.s.sol`, a second
script takes the rig to a SWAPPABLE state so timepoints self-write via `beforeSwap` (no
offchain `writeTimepoint`). Plus two cross-track fixes (F1 stale comment, F2 tickSpacing
mismatch) and a written answer to the cheat-swap guard question.

v2 resolves the two-step review (Reality Checker + Solidity specialist, both parallel, no
BLOCKERs): funding failure modes made deterministic (RC-M1/S-m1), same-second seed/probe
race closed + probe assert strengthened (RC-M2/S-M1), per-timestamp granularity (S-M2),
cheat-domain pinned (S-M3), sha256 re-pin consequence added (RC-M3), plus all minors.

## Deliverable 1 — `foundry-scripts/deploy/InitSwappableRig.s.sol`

New contract `InitSwappableRig is PlankDeployBase` (deployerKey convention; NO plank FFI —
pure Solidity, so no `--ffi`). Env inputs (REQUIRED — the deploy script's printed manifest,
already sorted): `POOL_MANAGER`, `HOOK`, `TOKEN0`, `TOKEN1`. Steps:

0. Env sanity (deterministic failure at step 0, not a wrapped settlement revert 4 calls
   deep): `TOKEN0 < TOKEN1` (manifest order), both tokens + manager + hook have code
   (`code.length > 0` — a codeless address makes low-level calls succeed vacuously),
   ERC20-strict currencies only (no native-ETH rig).
1. Clock advance (closes the same-second seed/probe race): the deploy script seeds the vol
   buffer at `uint32(block.timestamp)` and the write guard is TIMESTAMP equality
   (`RealizedVolatilityStateLib.plk:114`) — back-to-back deploy+init in one wall-second
   would B1-no-op the probe. `vm.warp(now+5)` for the simulation clock AND (chainid 31337
   only) `vm.rpc("evm_increaseTime","[5]")` for the node clock. On a real node (PRIVATE_KEY
   path) time advances naturally; the assert in step 6 still catches a no-op probe.
2. Deploy `PoolSwapTest(manager)` and `PoolModifyLiquidityTest(manager)` — vendored at
   `lib/panoptic-v2-core/lib/v4-core/src/test/` (canonical `IUnlockCallback` routers; we
   author nothing).
3. Fund + approve, deterministic in both paths: best-effort `try mint(deployer, 1e30)`
   (MinimalToken has open mint; a mintless real ERC20 just fails the try), then
   `require(balanceOf(deployer) >= 2e21)` per token — so EITHER open-mint OR pre-funded
   works and the failure is explicit at this step. Approve max to BOTH routers —
   **correcting issue #17's wording**: settlement is `CurrencySettler.settle →
   transferFrom(sender → manager)` pulled BY THE ROUTER, so allowance goes deployer→router,
   NOT deployer→PoolManager.
4. Reconstruct the PoolKey EXACTLY as deployed (`fee = 0x800000`, `tickSpacing =
   TICK_SPACING = 20` post-F2, `hooks = HOOK`) and assert EARLY:
   `keccak(key) == hook.poolId()` (selector 0x3e0dc34e) — key drift fails here with a clear
   message instead of `PoolNotInitialized` inside `modifyLiquidity`.
5. Mint ONE FULL-RANGE position: `modifyLiquidity(key, (minUsableTick(20)=-887260,
   maxUsableTick(20)=+887260, +1e21, salt=0), "")`. **Full-range-only is LOAD-BEARING**
   (G4): cheat-moves never CROSS ticks, so any interior initialized boundary desyncs
   `pool.liquidity` from a cheated tick; one full-range position ⟹ active liquidity uniform
   over the usable range. 1e21 fits int128; ≈1e21 raw of each token at tick 0 < the 2e21
   funding floor.
6. PROBE SWAP + REAL assert: exact-input `zeroForOne`, `amountSpecified = -1e6`,
   `sqrtPriceLimitX96 = MIN_SQRT_PRICE + 1`, default TestSettings, empty hookData, NOT
   nested in any outer unlock (PoolSwapTest requires deltaBefore == 0). Assert the probe
   PROVED the write path: `lastTimepointTimestamp` (bits [16,48) of
   `vm.load(hook, SLOT_HOOK_VOL_STATE)`) STRICTLY ADVANCED across the probe — "staticcall
   succeeds" is a tautology; the timepoint advancing is the deliverable. Then
   `getAverageVolatility(post-probe slot0 tick, uint32 sim-now)` staticcall returns 32
   bytes (uint88).
7. `console.log` manifest lines in the established style: swapRouter,
   modifyLiquidityRouter, tick range, liquidity, probe delta0/delta1, timepoint ts
   before/after.

## Deliverable 2 — F2 fix: align the rig pool's tickSpacing to the module pin

`DeployDynamicFeeHook.s.sol`: `TICK_SPACING = 10` → `20` (module source of truth:
`VolOrderValidationLib.plk:33` pins 20 into every VolOrder; the vol-order geometry and the
rig pool must agree for the Panoptic leg mint path). The hook is tickSpacing-agnostic
(hashes whatever key it receives). Verified blast radius: the script constant's only
consumers are the script itself; `DynamicFeeHookE2E.t.sol:89` pins its own in-test `TS=10`
and INTENTIONALLY STAYS (its recorded baseline is valid; do not "align" it);
`PriceSetterHook.s.sol` ts=60 unrelated.

## Deliverable 3 — F1 fix: rewrite the stale V1 comment block

`VolOrderManagerMod.plk` (~177-188): the batch-path block comment still documents the V1
input word (`width` = unmasked TOP field, "bits >=128 MUST BE ZERO"). Rewrite to the V2
layout the code at 222-235 implements: `skew@0..15 | strike@16..103 | width@104..127
(MASKED — interior now) | targetVega@128..255 (unmasked TOP; dirty bits ≥224 → targetVega >
2^96-1 → rejected by target_vega_fits_packed; batch SKIPS, strict reverts)`. Comment-only;
compiled hex must be byte-identical (compiler comment-insensitivity verified empirically by
the reviewer; still assert by cmp of build/plank hex before/after).

## Deliverable 4 — the guard answer (issue reply, no hook change)

- G1 same-second repeats: guarded by design (B1), but the granularity is **at most ONE
  timepoint per distinct uint32 TIMESTAMP — blocks are irrelevant**. Anvil mines several
  blocks per second: two swaps in different same-second blocks still no-op the second
  write. A no-op'd swap still gets a fee + E5; E3 is the ground truth of what LANDED.
  Drivers must advance the clock (≥1s) between writes they want recorded.
- G2 non-monotonic timestamps: NOT guarded. The Algebra-ported oracle assumes a
  non-decreasing u32 clock; a backwards clock corrupts window math silently. The drivers
  own clock monotonicity.
- G3 arbitrary cheated tick jumps: safe for the hook — the oracle MEASURES tick deltas; a
  cheated jump is indistinguishable from a traded one.
- G4 the real hazard is liquidity-accounting desync: cheat-moves never cross ticks. The rig
  must hold ONLY the one full-range position — minting any additional range breaks the
  invariant silently. **Cheat domain is PINNED to ticks strictly inside
  [-887260, +887260]** (minUsableTick(20)..maxUsableTick(20)): the slivers out to ±887272
  are TickMath-valid but OUTSIDE the position, where global liquidity claims 1e21 that
  isn't there.
- G5 slot0-cheat hygiene: write sqrtPriceX96 AND tick consistently
  (sqrtPrice = getSqrtPriceAtTick(tick)) in the same word, and PRESERVE bits ≥184
  (protocolFee/lpFee — zeroing is harmless today, latent bug under any future protocol-fee
  config). Also: a cheat to the bottom of the range inverts the probe's fixed direction —
  any repeated minimal-swap pattern must choose zeroForOne/limit RELATIVE to the cheated
  price, not hardcode them.

## Verification

- Full invocation (anvil running, deploy script re-run FIRST post-F2 — ts=10 rigs are
  stale):
  `forge script foundry-scripts/deploy/DeployDynamicFeeHook.s.sol --tc DeployDynamicFeeHook --rpc-url local --broadcast --ffi --via-ir`
  then with env from its manifest:
  `forge script foundry-scripts/deploy/InitSwappableRig.s.sol --tc InitSwappableRig --rpc-url local --broadcast --via-ir`
  (no `--ffi` — pure Solidity). `--broadcast` is REQUIRED: without it nothing lands and the
  manifest workflow has no broadcast JSON.
- `cast logs` on the anvil: post-probe E3 (TimepointWritten) at the ADVANCED timestamp and
  E5 (FeeApplied), both with the real poolId. (The seed also emits an E3 — the assert is
  the NEW one, hence the timestamp check.)
- `make compile-plank` green after F1 + byte-identical VolOrderManagerMod hex (cmp).
- Forge families pinning VolOrderManagerMod (`test/pos_spec/VolOrderManager*`,
  VolOrderTargetVega) re-run green — note: NOT the develop-gate "--skip ledger" (none of
  those families touch this module).

## Cross-track consequences (issue reply MUST state)

- rpc_api pinned per-file sha256 for `src/` and `foundry-scripts/` (Phase 20): F1
  (`VolOrderManagerMod.plk`) and F2 (`DeployDynamicFeeHook.s.sol`) change SOURCE hashes
  (byte-identical hex does not preserve source sha) — re-pin both files.
- Rigs deployed with ts=10 are stale; re-run the deploy script before the init script.

## Out of scope

Owner-gating the hook init (todo.md:178, research-only invariant stands); any change to
`beforeSwap`/`RealizedVolatilityStateLib` (guard answer concluded none needed); editing
rpc_api's write_price.
