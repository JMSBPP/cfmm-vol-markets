# PriceSetterHook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `PriceSetterHook` — a Uniswap v4 hook that discovers/verifies the storage slot of its pool's `slot0` in `PoolManager` and packs consistent slot0 values, so a local dev node can impose a stochastic tick process via `setStorageAt` — with forge tests, on a new `feat/price-setter-hook` branch, PR → `develop`.

**Architecture:** Standalone one-pool hook (no BaseHook). `beforeInitialize` binds and records the slot via v4-core's own `StateLibrary._getPoolStateSlot`; `afterInitialize` cross-checks the slot against the values `Pool.initialize` actually stored (fail-closed binding). Reads go through `PoolManager.extsload`; writes are done externally (`vm.store` in tests ≙ `setStorageAt` off-chain) using `packSlot0For(tick)` which keeps `tick`/`sqrtPriceX96` consistent and preserves fee bits.

**Tech Stack:** Solidity `^0.8.26`, forge (1.5.1) + forge-std v1.16.1, vendored v4-core at remapping `univ4-core/` (= `lib/panoptic-v2-core/lib/panoptic-helper/lib/v4-core/src/`).

**Spec:** `docs/superpowers/specs/2026-07-17-price-setter-hook-design.md` (approved; two-step reviewed).

## Global Constraints

- All work happens in a NEW worktree `/home/jmsbpp/cfmms-playground/cfmm-wt/price-setter` on branch `feat/price-setter-hook` cut from **`origin/develop` after `git fetch origin`** (local `develop` is ~37 commits stale — never branch from it). NEVER commit to `feat/plank` or touch the plank worktree's dirty state.
- Hook + test pragmas: `pragma solidity ^0.8.26;` (PoolManager pins exactly 0.8.26; transient storage needs evm ≥ cancun — forge 1.5.1 auto-detect handles both). `origin/develop`'s foundry.toml already sets `via_ir = true`, `optimizer = true`, `[fuzz] runs = 256`.
- The ONLY `remappings.txt` changes are the TWO lines repointed to panoptic-v2-core's DIRECT v4-core submodule (the CI gate blocks `panoptic-helper` init, so anything routed through it resolves locally but fails in CI; the direct submodule's `src/` is byte-identical and present on the runner):
  - `univ4-core/=lib/panoptic-v2-core/lib/panoptic-helper/lib/v4-core/src/` → `univ4-core/=lib/panoptic-v2-core/lib/v4-core/src/`
  - `solmate/=lib/v4-core/lib/solmate/` → `solmate/=lib/panoptic-v2-core/lib/v4-core/lib/solmate/`
  Take everything else from `origin/develop`'s committed files.
- Fuzz set-tick domain is `[TickMath.MIN_TICK, TickMath.MAX_TICK - 1]` (MAX_TICK is an unreachable pool state; round-trip only holds below it). The inline `/// forge-config: default.fuzz.runs = 256` is redundant with origin/develop's foundry.toml but harmless — keep it as a local guarantee.
- Hook reverts surfaced through `manager.initialize` are ERC-7751-wrapped: expect `CustomRevert.WrappedError(hook, hookFnSelector, innerError, abi.encodeWithSelector(Hooks.HookCallFailed.selector))`. Direct hook calls revert unwrapped.
- Gate reality: `origin/develop`'s tip suite is UNBUILDABLE in a clean checkout (tests import `@cryptoalgebra/...` from `node_modules`; no `package.json` is tracked there) — the gate currently fails for ANY PR, pre-existing and out of scope. Local validation therefore uses an untracked `node_modules` workaround (Task 6) and the PR body flags the breakage for the CI workstream. Do NOT try to fix the gate in this PR.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Worktree + branch setup, commit spec & plan docs

**Files:**
- Create (in new worktree): `docs/superpowers/specs/2026-07-17-price-setter-hook-design.md`, `docs/superpowers/plans/2026-07-17-price-setter-hook.md` (copied from the plank worktree)

**Interfaces:**
- Produces: worktree at `/home/jmsbpp/cfmms-playground/cfmm-wt/price-setter` on branch `feat/price-setter-hook`, submodules initialized, docs committed. All later tasks run inside this worktree.

- [ ] **Step 1: Fetch and create the worktree from origin/develop**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/plank
git fetch origin
git worktree add /home/jmsbpp/cfmms-playground/cfmm-wt/price-setter -b feat/price-setter-hook origin/develop
```

Expected: `Preparing worktree (new branch 'feat/price-setter-hook')`, HEAD at origin/develop's tip (NOT local develop — it is ~37 commits stale).

- [ ] **Step 2: Initialize submodules MIRRORING THE CI GATE (panoptic-helper blocked)**

Read the forge job's submodule steps in `.github/workflows/develop-gate.yml` in the new worktree and replicate them exactly. The known key sequence:

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/price-setter
git submodule update --init lib/panoptic-v2-core lib/forge-std
git -C lib/panoptic-v2-core config submodule.lib/panoptic-helper.update none
git submodule update --init --recursive lib/panoptic-v2-core lib/forge-std
ls lib/panoptic-v2-core/lib/v4-core/src/PoolManager.sol lib/panoptic-v2-core/lib/v4-core/lib/solmate/src/auth/Owned.sol lib/forge-std/src/Test.sol
ls lib/panoptic-v2-core/lib/panoptic-helper/ 2>&1
```

Expected: the three files listed; the panoptic-helper dir empty or absent (matching the runner). NOTE: submodule module stores are PER-WORKTREE, so this performs real network clones — it may take a while. If the gate workflow initializes additional submodules, replicate those too. If a submodule fails to fetch, report it — do not improvise URLs.

- [ ] **Step 3: Copy the two docs from the plank worktree and commit**

```bash
mkdir -p docs/superpowers/specs docs/superpowers/plans
cp /home/jmsbpp/cfmms-playground/cfmm-wt/plank/docs/superpowers/specs/2026-07-17-price-setter-hook-design.md docs/superpowers/specs/
cp /home/jmsbpp/cfmms-playground/cfmm-wt/plank/docs/superpowers/plans/2026-07-17-price-setter-hook.md docs/superpowers/plans/
git add docs/superpowers
git commit -m "docs(price-setter): add reviewed design spec and implementation plan

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Expected: 1 commit with 2 new files.

---

### Task 2: Fix the dead `solmate/` remapping (RED via probe, GREEN via fix)

**Files:**
- Modify: `remappings.txt` (the line `solmate/=lib/v4-core/lib/solmate/`)
- Create then delete: `test/modules/protocol_integrations/RemapProbe.t.sol` (temporary probe)

**Interfaces:**
- Produces: `import {PoolManager} from "univ4-core/PoolManager.sol";` compiles repo-wide. Tasks 3-5 rely on it.

- [ ] **Step 1: Write the failing probe (imports PoolManager, which imports solmate's Owned)**

```solidity
// test/modules/protocol_integrations/RemapProbe.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolManager} from "univ4-core/PoolManager.sol";

contract RemapProbe {
    function probe() external pure returns (bool) {
        return true;
    }
}
```

- [ ] **Step 2: Run build to verify it fails on the dead remappings**

First confirm the tip still has the dead lines: `grep -n "solmate/\|univ4-core/" remappings.txt`
Expected: `solmate/=lib/v4-core/lib/solmate/` and `univ4-core/=lib/panoptic-v2-core/lib/panoptic-helper/lib/v4-core/src/` (if origin/develop already fixed them, skip this task and note it).

Run: `forge build --offline 2>&1 | tail -5`
Expected: FAIL — either `"solmate/src/auth/Owned.sol": File not found` (surfaced via `ProtocolFees.sol`) or `univ4-core/PoolManager.sol` not found (panoptic-helper is blocked in this worktree, mirroring CI — this is exactly the failure the gate would have hit).

- [ ] **Step 3: Repoint BOTH remappings to the direct v4-core submodule**

In `remappings.txt` replace:

```
univ4-core/=lib/panoptic-v2-core/lib/panoptic-helper/lib/v4-core/src/
solmate/=lib/v4-core/lib/solmate/
```

with:

```
univ4-core/=lib/panoptic-v2-core/lib/v4-core/src/
solmate/=lib/panoptic-v2-core/lib/v4-core/lib/solmate/
```

- [ ] **Step 4: Run build to verify it passes, then delete the probe**

Run: `forge build --offline` → Expected: `Compiler run successful` (warnings OK). If the FULL build fails on `@cryptoalgebra` imports from pre-existing tests, apply the Task 6 Step 0 node_modules workaround first, then re-run.
Then: `rm test/modules/protocol_integrations/RemapProbe.t.sol`

- [ ] **Step 5: Commit**

```bash
git add remappings.txt
git commit -m "fix(remappings): route univ4-core and solmate through the direct v4-core submodule

solmate/ pointed at nonexistent top-level lib/v4-core (PoolManager ->
ProtocolFees imports solmate/src/auth/Owned.sol, so nothing importing
PoolManager compiled at all), and univ4-core/ routed through
panoptic-helper, which the develop gate never initializes (empty on the
runner) -- resolved locally, dead in CI. panoptic-v2-core's direct
v4-core submodule has a byte-identical src/ tree and is present in CI.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: PriceSetterHook contract + binding/read tests

**Files:**
- Create: `src/modules/protocol_integrations/PriceSetterHook.sol`
- Create: `test/modules/protocol_integrations/PriceSetterHook.t.sol`

**Interfaces:**
- Consumes: `univ4-core/` remapping (Task 2).
- Produces (contract, used by Tasks 4-5):
  - `constructor(IPoolManager _poolManager)`
  - `poolManager() → IPoolManager`, `poolId() → PoolId`, `slot0Slot() → bytes32`
  - `beforeInitialize(address, PoolKey calldata, uint160) → bytes4`
  - `afterInitialize(address, PoolKey calldata, uint160, int24) → bytes4`
  - `readSlot0() → Slot0`, `readTick() → int24`, `readSqrtPriceX96() → uint160`
  - `packSlot0For(int24 newTick) → bytes32`
  - errors `NotPoolManager()`, `AlreadyBound()`, `NotBound()`, `WrongPool()`, `SlotVerificationFailed(int24,int24)`
- Produces (test fixture, extended by Tasks 4-5): `PriceSetterHookTest` with `manager`, `hook`, `key`, `HOOK_ADDRESS`, `INIT_TICK = 1000`, `SEEDED_PROTOCOL_FEE`.

- [ ] **Step 1: Write the failing tests (binding + reads)**

```solidity
// test/modules/protocol_integrations/PriceSetterHook.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolManager} from "univ4-core/PoolManager.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {Slot0, Slot0Library} from "univ4-core/types/Slot0.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";
import {CustomRevert} from "univ4-core/libraries/CustomRevert.sol";
import {PriceSetterHook} from "../../../src/modules/protocol_integrations/PriceSetterHook.sol";

contract PriceSetterHookTest is Test {
    using Slot0Library for Slot0;

    PoolManager internal manager;
    PriceSetterHook internal hook;
    PoolKey internal key;

    // Namespaced flag address: only bits 13 (beforeInitialize) and 12 (afterInitialize)
    // of the low 14 are set; 0x4444 << 20 keeps it clear of precompiles.
    address internal constant HOOK_ADDRESS = address(
        uint160(0x4444 << 20) | uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG)
    );

    int24 internal constant INIT_TICK = 1000;
    uint24 internal constant LP_FEE = 3000;
    // (oneForZero = 500) << 12 | (zeroForOne = 400); both <= MAX_PROTOCOL_FEE (1000)
    uint24 internal constant SEEDED_PROTOCOL_FEE = uint24((500 << 12) | 400);

    function setUp() public {
        manager = new PoolManager(address(this));
        deployCodeTo(
            "src/modules/protocol_integrations/PriceSetterHook.sol:PriceSetterHook",
            abi.encode(IPoolManager(address(manager))),
            HOOK_ADDRESS
        );
        hook = PriceSetterHook(HOOK_ADDRESS);
        key = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: LP_FEE,
            tickSpacing: 60,
            hooks: IHooks(HOOK_ADDRESS)
        });
        manager.initialize(key, TickMath.getSqrtPriceAtTick(INIT_TICK));
        // Seed nonzero protocolFee bits so fee-bit preservation is observable (initialize
        // leaves protocolFee = 0, and asserting 0 == 0 would be vacuous).
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, SEEDED_PROTOCOL_FEE);
    }

    function test_binding_recordsPoolIdAndVerifiedSlot() public view {
        assertEq(PoolId.unwrap(hook.poolId()), PoolId.unwrap(key.toId()), "poolId mismatch");
        // Independent recomputation of the slot formula: _pools mapping sits at slot 6.
        bytes32 expectedSlot = keccak256(abi.encodePacked(PoolId.unwrap(key.toId()), uint256(6)));
        assertEq(hook.slot0Slot(), expectedSlot, "slot0Slot mismatch");
        assertTrue(hook.slot0Slot() != bytes32(0), "unbound");
    }

    function test_reads_matchInitializeValues() public view {
        assertEq(hook.readTick(), INIT_TICK, "tick");
        assertEq(hook.readSqrtPriceX96(), TickMath.getSqrtPriceAtTick(INIT_TICK), "sqrtPrice");
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (hook source does not exist yet)**

Run: `forge test --offline --match-contract PriceSetterHookTest -vv 2>&1 | tail -5`
Expected: FAIL — compile error, `PriceSetterHook.sol` not found. (The existing plank-worktree sketch is untracked; it does not exist on this branch.)

- [ ] **Step 3: Write the hook contract**

```solidity
// src/modules/protocol_integrations/PriceSetterHook.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId} from "univ4-core/types/PoolId.sol";
import {Slot0, Slot0Library} from "univ4-core/types/Slot0.sol";
import {StateLibrary} from "univ4-core/libraries/StateLibrary.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

/// @notice Bound to exactly one v4 pool. Discovers and self-verifies the storage slot of
/// that pool's slot0 inside PoolManager so an off-chain party on a LOCAL DEV NODE can
/// impose a tick trajectory via setStorageAt. The hook itself cannot write PoolManager
/// storage on-chain; it is the trusted source of WHERE to write and WHAT value:
///
///   setStorageAt(address(poolManager), hook.slot0Slot(), hook.packSlot0For(tick))
///
/// packSlot0For keeps tick and sqrtPriceX96 consistent and preserves the fee bits, so
/// slot0-based reads stay coherent. Liquidity structures (liquidity, tickBitmap, ticks,
/// feeGrowthGlobal) are NOT maintained: only use pools with no liquidity or with
/// full-range-only liquidity, so an imposed tick never crosses an initialized tick.
///
/// The hook address must carry BEFORE_INITIALIZE_FLAG (1 << 13) and
/// AFTER_INITIALIZE_FLAG (1 << 12).
contract PriceSetterHook {
    using Slot0Library for Slot0;

    IPoolManager public immutable poolManager;

    /// @notice The bound pool. Set once in beforeInitialize.
    PoolId public poolId;
    /// @notice Verified storage slot of the bound pool's slot0 inside PoolManager.
    /// slot0Slot == 0 <=> unbound (keccak256 output is never zero in practice).
    bytes32 public slot0Slot;

    error NotPoolManager();
    error AlreadyBound();
    error NotBound();
    error WrongPool();
    error SlotVerificationFailed(int24 expected, int24 actual);

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    modifier onlyBound() {
        if (slot0Slot == bytes32(0)) revert NotBound();
        _;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /// @notice Binds this hook to the first pool initialized with it (one pool per instance).
    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        onlyPoolManager
        returns (bytes4)
    {
        if (slot0Slot != bytes32(0)) revert AlreadyBound();
        PoolId id = poolKey.toId();
        poolId = id;
        slot0Slot = StateLibrary._getPoolStateSlot(id);
        return IHooks.beforeInitialize.selector;
    }

    /// @notice Cross-checks the recorded slot against the values Pool.initialize actually
    /// stored. A wrong slot computation aborts pool creation, so a successfully bound
    /// hook is a proven slot.
    function afterInitialize(address, PoolKey calldata poolKey, uint160 sqrtPriceX96, int24 tick)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        if (PoolId.unwrap(poolKey.toId()) != PoolId.unwrap(poolId)) revert WrongPool();
        Slot0 slot0 = readSlot0();
        if (slot0.tick() != tick || slot0.sqrtPriceX96() != sqrtPriceX96) {
            revert SlotVerificationFailed(tick, slot0.tick());
        }
        return IHooks.afterInitialize.selector;
    }

    /// @notice Raw slot0 of the bound pool, read through PoolManager.extsload.
    function readSlot0() public view onlyBound returns (Slot0) {
        return Slot0.wrap(poolManager.extsload(slot0Slot));
    }

    function readTick() external view returns (int24) {
        return readSlot0().tick();
    }

    function readSqrtPriceX96() external view returns (uint160) {
        return readSlot0().sqrtPriceX96();
    }

    /// @notice The exact bytes32 an off-chain party writes at slot0Slot to impose newTick:
    /// current slot0 with tick := newTick, sqrtPriceX96 := getSqrtPriceAtTick(newTick)
    /// (reverts InvalidTick outside [MIN_TICK, MAX_TICK]), fee bits preserved.
    function packSlot0For(int24 newTick) external view returns (bytes32) {
        Slot0 current = readSlot0();
        uint160 newSqrtPriceX96 = TickMath.getSqrtPriceAtTick(newTick);
        return Slot0.unwrap(current.setTick(newTick).setSqrtPriceX96(newSqrtPriceX96));
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `forge test --offline --match-contract PriceSetterHookTest -vv`
Expected: PASS — 2 tests. Note: setUp succeeding is itself the slot-math proof (afterInitialize's cross-check ran inside `manager.initialize`).

- [ ] **Step 5: Commit**

```bash
git add src/modules/protocol_integrations/PriceSetterHook.sol test/modules/protocol_integrations/PriceSetterHook.t.sol
git commit -m "feat(price-setter): PriceSetterHook with fail-closed slot binding + reads

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: TickCheat helper + fuzz set-tick + packSlot0For bounds

**Files:**
- Create: `test/modules/protocol_integrations/TickCheat.sol`
- Modify: `test/modules/protocol_integrations/PriceSetterHook.t.sol` (append tests)

**Interfaces:**
- Consumes: `PriceSetterHook.slot0Slot()/packSlot0For(int24)` (Task 3 signatures).
- Produces: `TickCheat.setTick(Vm, IPoolManager, PriceSetterHook, int24)` — byte-for-byte what `setStorageAt` does off-chain later.

- [ ] **Step 1: Write TickCheat and the failing tests**

```solidity
// test/modules/protocol_integrations/TickCheat.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {PriceSetterHook} from "../../../src/modules/protocol_integrations/PriceSetterHook.sol";

/// @notice Test-side twin of the off-chain write protocol:
/// setStorageAt(manager, hook.slot0Slot(), hook.packSlot0For(tick)) == vm.store(...).
library TickCheat {
    function setTick(Vm vm, IPoolManager manager, PriceSetterHook hook, int24 newTick) internal {
        vm.store(address(manager), hook.slot0Slot(), hook.packSlot0For(newTick));
    }
}
```

Append to `PriceSetterHookTest` (add `import {TickCheat} from "./TickCheat.sol";` at the top of the test file):

```solidity
    /// forge-config: default.fuzz.runs = 256
    function testFuzz_setTick_slot0ConsistentAndFeesPreserved(int24 t) public {
        // MAX_TICK excluded: price domain is half-open, tick == MAX_TICK is unreachable
        // for a real pool and getTickAtSqrtPrice reverts at MAX_SQRT_PRICE.
        t = int24(bound(int256(t), int256(TickMath.MIN_TICK), int256(TickMath.MAX_TICK - 1)));

        TickCheat.setTick(vm, IPoolManager(address(manager)), hook, t);

        assertEq(hook.readTick(), t, "tick");
        assertEq(hook.readSqrtPriceX96(), TickMath.getSqrtPriceAtTick(t), "sqrtPrice");
        // Round-trip: the imposed slot0 is a price a real pool could hold.
        assertEq(TickMath.getTickAtSqrtPrice(hook.readSqrtPriceX96()), t, "round-trip");

        // vm.load is the independent oracle: it bypasses the extsload path entirely
        // (StateLibrary.getSlot0 would be circular -- same slot math, same extsload).
        bytes32 raw = vm.load(address(manager), hook.slot0Slot());
        assertEq(raw, Slot0.unwrap(hook.readSlot0()), "extsload vs vm.load");

        Slot0 slot0 = Slot0.wrap(raw);
        assertEq(slot0.protocolFee(), SEEDED_PROTOCOL_FEE, "protocolFee bits clobbered");
        assertEq(slot0.lpFee(), LP_FEE, "lpFee bits clobbered");
    }

    function test_packSlot0For_revertsOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidTick.selector, TickMath.MAX_TICK + 1));
        hook.packSlot0For(TickMath.MAX_TICK + 1);
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidTick.selector, TickMath.MIN_TICK - 1));
        hook.packSlot0For(TickMath.MIN_TICK - 1);
    }
```

- [ ] **Step 2: Run new tests to verify current state**

Run: `forge test --offline --match-test "setTick_slot0|packSlot0For_reverts" -vv`
Expected: PASS (Task 3 already implemented `packSlot0For`; these tests verify behavior — if anything fails, fix the CONTRACT, not the assertions, unless the assertion contradicts the spec).

- [ ] **Step 3: Commit**

```bash
git add test/modules/protocol_integrations/TickCheat.sol test/modules/protocol_integrations/PriceSetterHook.t.sol
git commit -m "test(price-setter): fuzz slot0 consistency, fee-bit preservation, tick bounds

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Guard tests — AlreadyBound (wrapped), NotBound, NotPoolManager

**Files:**
- Modify: `test/modules/protocol_integrations/PriceSetterHook.t.sol` (append tests)

**Interfaces:**
- Consumes: error types from Task 3; `CustomRevert.WrappedError`, `Hooks.HookCallFailed`, `IHooks.beforeInitialize.selector`.

- [ ] **Step 1: Append the failing/verifying tests**

```solidity
    function test_secondInitialize_revertsAlreadyBound_wrapped() public {
        PoolKey memory key2 = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: LP_FEE,
            tickSpacing: 10, // different key, same hook
            hooks: IHooks(HOOK_ADDRESS)
        });
        // ERC-7751: PoolManager wraps hook reverts; second field is the hook FUNCTION
        // selector (bytes4 of the call payload), inner reason is the raw custom error.
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                HOOK_ADDRESS,
                IHooks.beforeInitialize.selector,
                abi.encodeWithSelector(PriceSetterHook.AlreadyBound.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        manager.initialize(key2, TickMath.getSqrtPriceAtTick(0));
    }

    function test_unboundHook_readsAndPackRevert_NotBound() public {
        PriceSetterHook fresh = new PriceSetterHook(IPoolManager(address(manager)));
        vm.expectRevert(PriceSetterHook.NotBound.selector);
        fresh.readTick();
        vm.expectRevert(PriceSetterHook.NotBound.selector);
        fresh.readSqrtPriceX96();
        vm.expectRevert(PriceSetterHook.NotBound.selector);
        fresh.packSlot0For(0);
    }

    function test_directCalls_revertNotPoolManager() public {
        vm.expectRevert(PriceSetterHook.NotPoolManager.selector);
        hook.beforeInitialize(address(this), key, 0);
        vm.expectRevert(PriceSetterHook.NotPoolManager.selector);
        hook.afterInitialize(address(this), key, 0, 0);
    }

    // Defensive branches unreachable through manager.initialize (AlreadyBound fires
    // first); exercised via direct pranked calls for branch coverage.
    function test_afterInitialize_wrongKey_revertsWrongPool() public {
        PoolKey memory other = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: LP_FEE,
            tickSpacing: 10,
            hooks: IHooks(HOOK_ADDRESS)
        });
        vm.prank(address(manager));
        vm.expectRevert(PriceSetterHook.WrongPool.selector);
        hook.afterInitialize(address(this), other, 0, 0);
    }

    function test_afterInitialize_mismatchedValues_revertsSlotVerificationFailed() public {
        // Bound pool's stored tick is INIT_TICK; claim a different tick/price.
        vm.prank(address(manager));
        vm.expectRevert(
            abi.encodeWithSelector(
                PriceSetterHook.SlotVerificationFailed.selector, INIT_TICK + 1, INIT_TICK
            )
        );
        hook.afterInitialize(address(this), key, TickMath.getSqrtPriceAtTick(INIT_TICK + 1), INIT_TICK + 1);
    }
```

- [ ] **Step 2: Run the full hook suite**

Run: `forge test --offline --match-contract PriceSetterHookTest -vv`
Expected: PASS — all 9 tests (2 from Task 3, 2 from Task 4, 5 here).
Note on `vm.expectRevert` + `vm.prank` ordering: `expectRevert` must be armed AFTER
`prank` so it applies to the hook call, as written above. If the WrappedError encoding assertion fails, print the actual revert with `-vvvv` and fix the EXPECTATION only if the actual wrapper differs structurally from the spec's Ground rules (then update the spec note too).

- [ ] **Step 3: Commit**

```bash
git add test/modules/protocol_integrations/PriceSetterHook.t.sol
git commit -m "test(price-setter): guard paths -- wrapped AlreadyBound, NotBound, NotPoolManager

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Full-suite validation, push, PR → develop

**Files:** none (verification + delivery)

- [ ] **Step 0 (if needed): node_modules workaround for origin/develop's pre-existing breakage**

Pre-existing tests on origin/develop import `@cryptoalgebra/...` from `node_modules`, but no `package.json` is tracked there — a clean checkout cannot build the full suite (this is the pre-existing gate breakage; do NOT fix it in this PR). To validate locally, copy the untracked deps from the plank worktree:

```bash
cp /home/jmsbpp/cfmms-playground/cfmm-wt/plank/package.json /home/jmsbpp/cfmms-playground/cfmm-wt/plank/package-lock.json /home/jmsbpp/cfmms-playground/cfmm-wt/price-setter/ 2>/dev/null || true
cd /home/jmsbpp/cfmms-playground/cfmm-wt/price-setter && npm ci
```

(If `npm ci` fails, `cp -r .../plank/node_modules` the `@cryptoalgebra` packages instead.) These files stay UNTRACKED — never `git add` them.

- [ ] **Step 1: Run the gate's exact command over the whole suite**

Run (in `/home/jmsbpp/cfmms-playground/cfmm-wt/price-setter`): `forge test --via-ir --offline`
Expected: PASS — all pre-existing origin/develop tests plus the 9 new ones. If a PRE-EXISTING test fails (not compile-breaks — fails), record it, verify it is unrelated to our diff (our files + 2 remapping lines), and do not "fix" it in this PR. Known caveat: even with everything green locally, the CI gate itself will fail on the `@cryptoalgebra`/`node_modules` gap until the CI workstream lands `package.json` tracking — the PR body says so.

- [ ] **Step 2: Push the branch**

```bash
git push -u origin feat/price-setter-hook
```

- [ ] **Step 3: Open the PR against develop**

```bash
gh pr create --base develop --title "feat: PriceSetterHook -- verified slot0 entry point for tick experiments" --body "$(cat <<'EOF'
## What

`PriceSetterHook`: a Uniswap v4 hook bound to one pool that discovers and self-verifies the storage slot of the pool's `slot0` in `PoolManager`, and packs consistent `(tick, sqrtPriceX96, fees)` values — the single trusted entry point for off-chain parties to impose a stochastic tick process on a local dev node via `setStorageAt`.

- Fail-closed binding: `afterInitialize` cross-checks the computed slot against what `Pool.initialize` stored; wrong slot math aborts pool creation.
- `packSlot0For(tick)` keeps `tick`/`sqrtPriceX96` consistent (`getSqrtPriceAtTick`) and preserves fee bits.
- Fixes two CI-dead remappings: `solmate/` pointed at nonexistent top-level `lib/v4-core` (nothing importing `PoolManager` compiled at all), and `univ4-core/` routed through `panoptic-helper`, which the develop gate never initializes — both now go through panoptic-v2-core's direct v4-core submodule (byte-identical `src/`).
- 9 forge tests against a real `PoolManager`, incl. fuzzed slot0 consistency over `[MIN_TICK, MAX_TICK-1]` with `vm.store` as the byte-for-byte twin of the off-chain `setStorageAt` protocol and `vm.load` as the independent read oracle.
- Note: `remappings.txt` still has one other dead `lib/v4-core` line (`ds-test/`), currently harmless (nothing imports `ds-test/`) — left out of scope.

## Known limitation (by design)

A slot0 write does not maintain liquidity structures. Supported regime: pools with no liquidity or full-range-only liquidity. See `docs/superpowers/specs/2026-07-17-price-setter-hook-design.md`.

## Heads-up: pre-existing gate breakage (NOT this PR)

The gate's forge job currently fails for ANY PR into develop: tests on develop's tip import `@cryptoalgebra/...` from `node_modules`, but no `package.json` is tracked on develop and the runner has no `node_modules` (the PR that merged that state never ran the forge job). This PR's suite passes locally under the gate's exact command with the deps present. Needs the CI workstream to land `package.json` tracking + `npm ci` in the gate.

## Follow-ups

TypeScript `setStorageAt` driver (hardhat compiles `contracts/`, not `src/` — will consume the forge artifact); stochastic process driver; swap/liquidity integration tests.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed; gate check starts on the self-hosted runner.

- [ ] **Step 4: Report back**

Relay to the user: PR URL, test count, the solmate remapping fix, and the known-limitation note.
