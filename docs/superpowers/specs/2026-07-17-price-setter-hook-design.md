# PriceSetterHook — design spec

Date: 2026-07-17
Status: reviewed (two-step review applied: Reality Checker + Solidity Smart Contract Engineer)
Branch/PR: new branch `feat/price-setter-hook` based off `develop`, PR → `develop` (independent of `feat/plank` work)

## Purpose

Enable tick-perturbation experiments on a Uniswap v4 pool: an off-chain process imposes a
stochastic process on the pool's tick, keeping the pool's `slot0` (tick, sqrtPriceX96, fees)
internally consistent. `PriceSetterHook` is the single trusted source of
*where* the tick lives (the exact storage slot in `PoolManager`) and *what value* to write
there, so that the off-chain party's write is a dumb, verified `setStorageAt`.

**Coherence boundary (known limitation).** A `slot0` write teleports the price but does NOT
touch `Pool.State.liquidity`, `tickBitmap`, `ticks[]`, positions, or `feeGrowthGlobal`. If
the pool has LP positions and an imposed tick jump crosses an initialized tick boundary,
active-liquidity and fee accounting become stale, and subsequent swaps trade against
phantom/missing liquidity. The supported experiment regime is therefore: pools with **no
liquidity**, or **full-range-only liquidity** (no interior initialized ticks to cross).
Slot0-based reads are always coherent; liquidity-dependent operations are only coherent in
that regime.

## Ground rules (verified facts, not assumptions)

- A hook **cannot** write `PoolManager` storage on-chain. `sstore` in the hook touches the
  hook's own storage. Writes to `PoolManager._pools[id].slot0` are only possible via node
  cheatcodes: `vm.store` (forge), `anvil_setStorageAt` / `hardhat_setStorageAt` (RPC).
  Experiments therefore run on a local dev node only (per scoping decision).
- `PoolManager` declares `mapping(PoolId id => Pool.State) internal _pools;` and v4-core's
  `StateLibrary` pins it: `POOLS_SLOT = bytes32(uint256(6))`, pool-state slot =
  `keccak256(abi.encodePacked(PoolId.unwrap(poolId), POOLS_SLOT))`, `slot0` at offset 0.
  `_getPoolStateSlot` is `internal pure` — the hook reuses it verbatim.
- `Slot0` packing (v4-core `types/Slot0.sol`), from LSB:
  `uint160 sqrtPriceX96 | int24 tick | uint24 protocolFee | uint24 lpFee | 24 bits empty`.
  A consistent tick write must set **both** `tick` and
  `sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick)` and preserve the fee bits.
- Hook callbacks fire only if the hook's **address** carries the matching flag bits:
  `BEFORE_INITIALIZE_FLAG = 1 << 13`, `AFTER_INITIALIZE_FLAG = 1 << 12`. Tests deploy the
  hook code at a flag-carrying address (`deployCodeTo`, forge-std v1.16.1 has it). Use a
  namespaced address (`uint160(namespace << 20 | flags)`) per v4 test convention; only the
  low 14 bits are inspected (`ALL_HOOK_MASK = (1 << 14) - 1`).
- Hook reverts bubble out of `PoolManager` **wrapped** (ERC-7751):
  `Hooks.callHook` re-throws via `CustomRevert.bubbleUpAndRevertWith(hook, selector,
  HookCallFailed.selector)`, so tests asserting hook reverts through
  `manager.initialize(...)` must expect `CustomRevert.WrappedError`, not the raw custom
  error. Direct calls to the hook revert unwrapped.
- Vendored v4-core (`PoolManager` pragma exactly 0.8.26, uses transient storage → needs
  solc ≥ 0.8.24 and evm_version ≥ cancun; forge 1.5.1 auto-detect satisfies both) is used
  via the `univ4-core/` remapping. `origin/develop`'s foundry.toml sets `via_ir = true`,
  `optimizer = true`, `[fuzz] runs = 256`. Hook and tests use `pragma solidity ^0.8.26`.
- **Build fix required (in scope):** two `remappings.txt` lines are dead in CI.
  `solmate/=lib/v4-core/lib/solmate/` points at a nonexistent top-level `lib/v4-core`
  (`PoolManager` → `ProtocolFees` imports `solmate/src/auth/Owned.sol`, so nothing
  importing `PoolManager` compiles at all), and
  `univ4-core/=lib/panoptic-v2-core/lib/panoptic-helper/lib/v4-core/src/` routes through
  `panoptic-helper`, which the develop CI gate explicitly never initializes (the workflow
  sets `submodule.lib/panoptic-helper.update none`; the dir is empty on the runner) — it
  resolves locally but fails in CI. Both are repointed to panoptic-v2-core's DIRECT
  v4-core submodule, present on the runner and with a byte-identical `src/` tree:
  `univ4-core/=lib/panoptic-v2-core/lib/v4-core/src/` and
  `solmate/=lib/panoptic-v2-core/lib/v4-core/lib/solmate/` (verified: `Owned.sol` exists
  there; `PoolManager` compiles under via-IR at 17,151 bytes runtime — below EIP-170,
  deployable in tests). The repo builds today only because nothing imports `PoolManager`
  yet.
- `TickMath.getSqrtPriceAtTick` accepts the full inclusive range `[MIN_TICK, MAX_TICK]`,
  but the live-pool price domain is half-open: `getTickAtSqrtPrice` reverts at
  `sqrtPriceX96 >= MAX_SQRT_PRICE`, so `tick == MAX_TICK` is a state no real pool can
  occupy and price→tick round-trips only hold on `[MIN_TICK, MAX_TICK - 1]`.
- `PoolManager`'s constructor takes `address initialOwner` (needed for `setProtocolFee`
  in tests).

## Scope

In scope (this PR):
1. `src/modules/protocol_integrations/PriceSetterHook.sol` — written per below (new file
   from git's perspective: the current sketch is untracked and exists in no commit).
2. Forge tests under `test/modules/protocol_integrations/` against a **real** `PoolManager`,
   including a test-side write helper that uses `vm.store` — byte-for-byte what
   `setStorageAt` will do in later off-chain tooling.
3. `remappings.txt` fix: repoint the dead `solmate/` and CI-dead `univ4-core/` remappings
   to panoptic-v2-core's direct v4-core (see Ground rules) — without them nothing in this
   PR compiles locally (solmate) or in CI (both).

Out of scope (follow-ups): the TypeScript off-chain setter script (note: hardhat compiles
`contracts/`, not `src/`, so that follow-up must consume the forge artifact or adjust
hardhat paths); swap/liquidity integration tests; the stochastic process driver itself.
Shared-node front-running of `beforeInitialize` (an attacker's pool key capturing an
unbound hook first) is also out of scope: experiments run on a private local dev node
(single trusted operator). If that assumption ever changes, add an immutable deployer
gate (`sender == deployer`) in `beforeInitialize`.

## Contract design

`PriceSetterHook` — standalone (no BaseHook inheritance), bound to exactly one pool.

State:
- `IPoolManager public immutable poolManager` (constructor arg).
- `PoolId public poolId` — the bound pool.
- `bytes32 public slot0Slot` — verified storage slot of the bound pool's `slot0` inside
  `PoolManager`. `slot0Slot == bytes32(0)` ⇔ unbound (sentinel relies on keccak256 never
  producing zero in practice — document with a one-line comment in the contract).

Errors: `NotPoolManager()`, `AlreadyBound()`, `NotBound()`, `WrongPool()`,
`SlotVerificationFailed(int24 expected, int24 actual)`.

Hook callbacks (both revert unless `msg.sender == poolManager`):
- `beforeInitialize(address, PoolKey calldata key, uint160) → bytes4`
  - revert `AlreadyBound` if already bound (one pool per hook instance);
  - `poolId = key.toId()`; `slot0Slot = StateLibrary._getPoolStateSlot(poolId)`;
  - return `IHooks.beforeInitialize.selector`.
- `afterInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick) → bytes4`
  - revert `WrongPool` if `key.toId() != poolId`;
  - **self-verification**: read `bytes32 raw = poolManager.extsload(slot0Slot)`, decode via
    `Slot0Library`; revert `SlotVerificationFailed` unless decoded tick == `tick` param and
    decoded sqrtPriceX96 == `sqrtPriceX96` param. A wrong slot computation aborts pool
    creation, so **a successfully bound hook is a proven slot**;
  - return `IHooks.afterInitialize.selector`.

No other IHooks callbacks are implemented; `PoolManager` only calls the ones whose flag
bits the address carries.

Read/encode surface (all revert `NotBound` when unbound):
- `readSlot0() → Slot0` — raw `extsload` of `slot0Slot`.
- `readTick() → int24`, `readSqrtPriceX96() → uint160` — decoded from `readSlot0()`.
- `packSlot0For(int24 newTick) → bytes32` — the value an off-chain party (or `vm.store`)
  writes: current `readSlot0()` with tick := `newTick`,
  sqrtPriceX96 := `TickMath.getSqrtPriceAtTick(newTick)` (which itself reverts on
  out-of-bounds ticks), protocolFee/lpFee bits preserved.

Off-chain write protocol (documented in natspec): `setStorageAt(address(poolManager),
hook.slot0Slot(), hook.packSlot0For(t))`, then optionally confirm via `hook.readTick() == t`.

## Testing design

`test/modules/protocol_integrations/PriceSetterHook.t.sol` (+ small `TickCheat` helper
library wrapping `vm.store(address(manager), hook.slot0Slot(), hook.packSlot0For(t))`).

Setup: deploy real `PoolManager(initialOwner = address(this))`; `deployCodeTo` the hook at
a namespaced flag address carrying bits `(1 << 13) | (1 << 12)`; initialize a pool
(`currency0 < currency1` arbitrary sorted addresses — `initialize` performs no token calls,
`fee = 3000`, `tickSpacing = 60`, hook) at a known tick. Seed **nonzero protocolFee** bits
before the fuzz round (`setProtocolFee` as owner, or pre-write via `vm.store`) so that
fee-bit preservation is observable for BOTH fee fields (`initialize` leaves protocolFee at
0, and asserting 0 == 0 would be vacuous); `fee = 3000` makes the lpFee bits a nonzero
sentinel from the start.

Tests:
1. **Binding**: after initialize, `slot0Slot != 0`, `poolId` matches, and — because
   `afterInitialize` self-verifies against the values `Pool.initialize` actually stored —
   initialization succeeding proves the slot math.
2. **readTick/readSqrtPriceX96** equal the values `initialize` set.
3. **Fuzz set-tick** over `t ∈ [TickMath.MIN_TICK, TickMath.MAX_TICK - 1]` (MAX_TICK
   excluded: unreachable pool state, see Ground rules): after `TickCheat.setTick(t)`:
   `readTick() == t`, `readSqrtPriceX96() == TickMath.getSqrtPriceAtTick(t)`, round-trip
   `getTickAtSqrtPrice(readSqrtPriceX96()) == t`, and `vm.load(address(manager),
   hook.slot0Slot())` equals the extsload read — `vm.load` is the genuinely independent
   oracle here (it bypasses the extsload path entirely; `StateLibrary.getSlot0` would be
   circular since it uses the identical slot math and extsload); lpFee AND the seeded
   nonzero protocolFee bits unchanged.
4. **AlreadyBound**: initializing a second pool with the same hook reverts — expect the
   ERC-7751 `CustomRevert.WrappedError` wrapping `AlreadyBound` (see Ground rules), i.e.
   one hook instance ⇔ one pool.
5. **NotBound**: fresh hook — `readTick`, `readSqrtPriceX96`, `packSlot0For` revert
   (direct calls: raw `NotBound`, unwrapped).
6. **NotPoolManager**: direct EOA calls to `beforeInitialize`/`afterInitialize` revert
   (raw `NotPoolManager`, unwrapped).
7. **packSlot0For bounds**: reverts for `t` outside `[MIN_TICK, MAX_TICK]`
   (via TickMath's own revert).

## Error handling

All failure modes are explicit reverts (custom errors above). The critical safety property
is fail-closed binding: if the slot formula ever drifts from the deployed `PoolManager`
layout (e.g. a future v4 version moves `_pools`), `afterInitialize`'s cross-check makes
pool creation revert instead of leaving a hook pointing at a garbage slot.

## Delivery

- The current sketch at `src/modules/protocol_integrations/PriceSetterHook.sol` is
  untracked (exists in no commit on any branch), does not compile, and its slot math is
  unrelated to the correct formula — it is replaced wholesale; on the new branch this is a
  **new file**.
- New branch `feat/price-setter-hook` cut from **`origin/develop` after `git fetch`**
  (local `develop` is stale — 37 commits behind); PR targets `develop` per repo gate flow.
  Committed to the new branch: the hook, its tests, the two-line remappings fix, and the
  spec + plan docs — nothing else. All work happens in a dedicated worktree for the new
  branch so the `feat/plank` dirty state is never mixed in; the branch takes
  `origin/develop`'s files plus the remappings fix only. The worktree mirrors the CI
  gate's submodule sequence (panoptic-helper blocked) so local runs predict CI.
- **Pre-existing gate breakage (out of scope, flagged in the PR):** `origin/develop`'s tip
  suite is unbuildable in a clean checkout — three tests import `@cryptoalgebra/...` from
  `node_modules` but no `package.json` is tracked on `origin/develop`, and the gate's
  forge job never actually ran on the PR that merged that state. Any PR into `develop`
  fails the gate today for reasons unrelated to this work. Local validation uses an
  untracked `node_modules` workaround; the fix belongs to the CI workstream and the PR
  body says so explicitly.
