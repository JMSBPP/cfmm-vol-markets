# VolMarketKey → PanopticPoolId — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract Panoptic pool-id derivation into `VolMarketKeyLib.plk`, introduce `panoptic_v2/PanopticPoolId` newtype, split SFPM legacy verify from pure derive (client-supplied `vegoid`), and relocate Panoptic tests to `test/lib/protocol_integrations/`.

**Architecture:** **Task 1–2:** RED lib harness + `PanopticPoolId.plk` type tests (compose, pattern). **Task 3:** `VolMarketKeyLib.plk` — pure `vol_market_key_to_panoptic_pool_id(V,k,vegoid)`. **Task 4:** SFPM legacy verify in harness only (`harness_verify_sfpm_legacy`). **Task 5:** Strip Panoptic symbols from `VolMarketKey.plk`; migrate tests/handlers. **Task 6:** `PanopticTokenIdSetterLib` takes `PanopticPoolId`. **Task 7:** Spec docs commit + PR ready.

**Tech Stack:** Plank (`@evm_staticcall`, `@mstore4`, `std::error::require`), Foundry (`PlankTestBase`, `Deployers`), CI via `push-build` / `develop-gate`.

**Spec:** `docs/superpowers/specs/2026-08-30-volmarketkey-panoptic-pool-id-design.md`, `.spec/VOL_MARKET_POOL_KEY_TO_PANOPTIC_POOL_ID.md`

## Global Constraints

- **Inline on `develop` fork branch** `refactor/panoptic-pool-id` (or `type/panoptic-pool-id`).
- **Issue on `develop` + draft PR** before first implementation push (`Closes #N`).
- **NO LOCAL COMPILATION as sign-off.** Verification = `git push` → `develop-gate` on GitHub Actions.
- **Chunk approval before commit.** Present each file diff; maintainer approves/modifies; then commit.
- **TDD RED first.** Lib harness + moved tests land RED before `PanopticPoolId` / `VolMarketKeyLib` bodies.
- **ABI calldata:** `@mstore4(selector)` at offset 0; dynamic `bytes` args need offset/length words (see existing `VolMarketKey.plk` SFPM encode).
- **Name every path on `git add`.** Never stage dirty submodules or unrelated WIP.
- **Scope:** PanopticPoolId + VolMarketKeyLib extract + test split + SetterLib signature only. No `Extra(T)` payload widening (Phase 3). No `sfpm_v2` verify.

---

## File structure (this phase)

| File | Responsibility | Action |
|------|----------------|--------|
| `src/types/protocol_integrations/panoptic_v2/PanopticPoolId.plk` | Newtype + compose | **Create** (Task 2) |
| `src/lib/protocol_integrations/VolMarketKeyLib.plk` | Pattern, pure derive | **Create** (Task 3) |
| `src/types/protocol_integrations/VolMarketKey.plk` | Remove Panoptic derivation | **Modify** (Task 5) |
| `test/lib/protocol_integrations/VolMarketKeyLibHarness.plk` | Lib FFI + `harness_verify_sfpm_legacy` (test only) | **Create** (Task 1, 4) |
| `test/lib/protocol_integrations/VolMarketKeyLib.t.sol` | Pattern / compose / derive / SFPM tests | **Create** (Task 1, migrate from VolMarketKey.t.sol) |
| `test/protocol_integrations/VolMarketKeyHarness.plk` | Remove Panoptic handlers | **Modify** (Task 5) |
| `test/protocol_integrations/VolMarketKey.t.sol` | Key-type tests only | **Modify** (Task 5) |
| `fixtures/plank-negative/VolMarketKeyAlgebraToPanoptic.plk` | Import lib, Algebra guard | **Modify** (Task 5) |
| `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` | `pool_id: PanopticPoolId` | **Modify** (Task 6) |
| `test/**` touching SetterLib / VolOrder golden vectors | Update `pool_id` args | **Modify** (Task 6) |
| `docs/superpowers/specs/2026-08-30-volmarketkey-panoptic-pool-id-design.md` | Design spec | **Create** (Task 7) |
| `.spec/VOL_MARKET_POOL_KEY_TO_PANOPTIC_POOL_ID.md` | Binding summary | **Modify** (Task 7) |

**Pinned selector:**

```bash
cast sig "getPoolId(bytes,uint8)"   # 0xb33eb6f3 — SFPM legacy
```

---

### Task 0: Branch + issue + PR shell

**Files:** none (git + `gh`)

- [ ] **Step 1: Branch from `develop`**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
git fetch origin develop
git checkout develop && git pull origin develop
git checkout -b refactor/panoptic-pool-id
```

- [ ] **Step 2: Open tracking issue**

```bash
gh issue create --repo JMSBPP/cfmm-vol-markets \
  --title "refactor(panoptic-pool-id): VolMarketKeyLib + PanopticPoolId newtype" \
  --body "Plan: docs/superpowers/plans/2026-08-30-volmarketkey-panoptic-pool-id.md
Spec: docs/superpowers/specs/2026-08-30-volmarketkey-panoptic-pool-id-design.md"
```

- [ ] **Step 3: Draft PR** (after Task 1 RED push or empty branch)

```bash
git push -u origin refactor/panoptic-pool-id
gh pr create --base develop --head refactor/panoptic-pool-id --draft \
  --title "refactor(panoptic-pool-id): extract VolMarketKeyLib + PanopticPoolId" \
  --body "Closes #N

## Plan
docs/superpowers/plans/2026-08-30-volmarketkey-panoptic-pool-id.md"
```

---

### Task 1: RED — lib harness + migrated tests

**Files:**
- Create: `test/lib/protocol_integrations/VolMarketKeyLibHarness.plk`
- Create: `test/lib/protocol_integrations/VolMarketKeyLib.t.sol`

**Interfaces:**
- Consumes: `panoptic_pool_pattern_v4`, `panoptic_pool_id_compose`, `vol_market_key_to_panoptic_pool_id`, `panoptic_pool_id_verify_sfpm_legacy` — **do not exist yet** (RED)
- Produces: harness selectors for Tasks 2–4 GREEN

- [ ] **Step 1: `VolMarketKeyLibHarness.plk`**

Import paths:

```plank
import lib::protocol_integrations::VolMarketKeyLib::*;
import types::protocol_integrations::panoptic_v2::PanopticPoolId::*;
import types::protocol_integrations::VolMarketKey::*;
// … Pair, Pool, Registry, Venue as needed for key builders
```

Handlers (mirror current `VolMarketKeyHarness` Panoptic section):

| Selector | Handler |
|----------|---------|
| `v4Pattern(uint256)` | `panoptic_pool_pattern_v4` |
| `v3Pattern(uint256)` | `panoptic_pool_pattern_v3` |
| `composePoolId(uint256,uint256,uint256)` | `panoptic_pool_id_word(panoptic_pool_id_compose(...))` |
| `panopticPoolIdV4(uint256,uint256)` | derive only: `vol_market_key_to_panoptic_pool_id(V4, k, vegoid)` → word |
| `verifySfpmLegacy(uint256,address,uint256,uint256)` | `panoptic_pool_id_verify_sfpm_legacy(PanopticPoolId{word:id}, sfpm, poolIdentity, vegoid)` |
| `goldenPathPanoptic(uint256,address,uint256)` | build key → derive → verify_sfpm_legacy |

Copy key-builder helpers (`K_C0`, `K_C1`, registry, `golden_path_v4_build`, etc.) from `VolMarketKeyHarness.plk` or import shared helpers if already extracted.

- [ ] **Step 2: `VolMarketKeyLib.t.sol`**

Move from `VolMarketKey.t.sol` (with `SfpmStub` on test contract):

- `test__unit__goldenPathEndToEndPanoptic` — derive then `verifySfpmLegacy`
- `test__unit__panopticOnIncompleteKeyReverts`
- `test__fuzz__v4PatternIsTheLowFortyBits`
- `test__fuzz__v3PatternIsTheHighFortyBitsOfTheAddress`
- `test__unit__v3AndV4PatternsDifferForTheSameWord`
- `test__fuzz__composePoolIdLayout`
- `test__unit__composePoolIdRejectsZeroVegoid`
- `test__unit__poolIdCandidateMatchingTheSfpmIsReturned`
- `test__unit__poolIdCollisionMismatchReverts`
- `test__unit__algebraKeyIntoPanopticArmDoesNotCompile` — update fixture path in `_tryBuild`

`setUp`:

```solidity
harness = deployPlank("test/lib/protocol_integrations/VolMarketKeyLibHarness.plk");
v4Registry = address(new RegistryVerifyV4(address(0x1)));
```

- [ ] **Step 3: Push RED** — `VolMarketKeyLibHarness` fails to compile or tests fail. Maintainer chunk approval → commit → push → confirm `develop-gate` shows new suite attempting compile.

---

### Task 2: GREEN — `PanopticPoolId.plk`

**Files:**
- Create: `src/types/protocol_integrations/panoptic_v2/PanopticPoolId.plk`

**Interfaces:**
- Produces: `PanopticPoolId`, `panoptic_pool_id_word`, `panoptic_pool_id_compose`

- [ ] **Step 1: Implement type file**

```plank
import std::error::require;

const MASK_U40 = 0xffffffffff;

const PanopticPoolId = struct { word: u256 };

const panoptic_pool_id_word = fn (id: PanopticPoolId) u256 { id.word };

const panoptic_pool_id_compose = fn (
    pattern: u256,
    vegoid: u256,
    tick_spacing: u256,
) PanopticPoolId {
    require(vegoid != 0);
    PanopticPoolId {
        word: (pattern & MASK_U40)
            | @evm_shl(40, vegoid & 0xff)
            | @evm_shl(48, tick_spacing & 0xffff)
    }
};
```

- [ ] **Step 2: Wire harness compose/pattern tests** — pattern fns still in lib (Task 3); compose tests GREEN after Task 2 if harness imports `PanopticPoolId` for compose handler only.

- [ ] **Step 3: Chunk approval → commit → push**

---

### Task 3: GREEN — `VolMarketKeyLib.plk` (pure derive)

**Files:**
- Create: `src/lib/protocol_integrations/VolMarketKeyLib.plk`

**Interfaces:**
- Consumes: `PanopticPoolId`, `VolMarketKey`, `pool_word`, `vol_market_key_verify_pool`, `vol_market_key_tick_spacing`
- Produces: `panoptic_pool_pattern_v4`, `panoptic_pool_pattern_v3`, `vol_market_key_to_panoptic_pool_id`

- [ ] **Step 1: Implement patterns + derive** (no SFPM yet)

```plank
import std::core::addr::cast_addr;
import std::error::require;
import types::protocol_integrations::panoptic_v2::PanopticPoolId::*;
import types::protocol_integrations::VolMarketKey::*;
import types::protocol_integrations::Pool::*;
import types::protocol_integrations::Venue::*;

const MASK_U40 = 0xffffffffff;
const MASK_U160 = 0xffffffffffffffffffffffffffffffffffffffff;

const panoptic_pool_pattern_v4 = fn (pool_id_v4: u256) u256 {
    pool_id_v4 & MASK_U40
};

const panoptic_pool_pattern_v3 = fn (pool_addr: u256) u256 {
    @evm_shr(120, pool_addr & MASK_U160) & MASK_U40
};

const vol_market_key_to_panoptic_pool_id = fn (
    comptime V: type,
    k: VolMarketKey(V),
    vegoid: u256,
) PanopticPoolId {
    vol_market_key_require_complete(V, k);
    let pool = unwrap(k.pool);
    let pattern = if V == V4 {
        panoptic_pool_pattern_v4(pool_word(V4, pool))
    } else if V == V3 {
        vol_market_key_verify_pool(V, k);
        panoptic_pool_pattern_v3(pool_word(V3, pool))
    } else {
        @compile_error("VolMarketKeyLib: Panoptic arm accepts only V4 or V3");
    };
    panoptic_pool_id_compose(
        pattern, vegoid, vol_market_key_tick_spacing(V, k)
    )
};
```

- [ ] **Step 2: GREEN** — pattern fuzz + `panopticPoolIdV4` + golden derive (without SFPM step) pass.

- [ ] **Step 3: Chunk approval → commit → push**

---

### Task 4: GREEN — SFPM legacy verify

**Files:**
- Modify: `src/lib/protocol_integrations/VolMarketKeyLib.plk`

**Interfaces:**
- Produces: `panoptic_pool_id_verify_sfpm_legacy(id, sfpm, pool_identity, vegoid)`

- [ ] **Step 1: Add verify fn** (lift encode from current `VolMarketKey.plk:176-184`)

```plank
const SEL_SFPM_GET_POOL_ID = 0xb33eb6f3;

const staticcall_word = fn (target: u256, args_ptr: u256, args_len: u256) u256 {
    let ret = @malloc_uninit(32);
    require(@evm_staticcall(@evm_gas(), target, args_ptr, args_len, ret, 32));
    @mload32(ret)
};

const panoptic_pool_id_verify_sfpm_legacy = fn (
    id: PanopticPoolId,
    sfpm: addr,
    pool_identity: u256,
    vegoid: u256,
) void {
    let candidate = panoptic_pool_id_word(id);
    let p = @malloc_uninit(132);
    @mstore4(p, SEL_SFPM_GET_POOL_ID);
    @mstore32(p +% 4, 0x40);
    @mstore32(p +% 36, vegoid);
    @mstore32(p +% 68, 32);
    @mstore32(p +% 100, pool_identity);
    require(candidate == staticcall_word(cast_addr(sfpm, u256), p, 132));
};
```

- [ ] **Step 2: Update `goldenPathPanoptic` harness** — derive then `verifySfpmLegacy`.

- [ ] **Step 3: SFPM agree/disagree tests GREEN**

- [ ] **Step 4: Chunk approval → commit → push**

---

### Task 5: Trim `VolMarketKey.plk` + test split cleanup

**Files:**
- Modify: `src/types/protocol_integrations/VolMarketKey.plk`
- Modify: `test/protocol_integrations/VolMarketKeyHarness.plk`
- Modify: `test/protocol_integrations/VolMarketKey.t.sol`
- Modify: `fixtures/plank-negative/VolMarketKeyAlgebraToPanoptic.plk`

**Interfaces:**
- VolMarketKey retains: struct, `vol_market_key`, `*_at`, accessors, `verify_pool`, `panoptic_asset_bit`
- Removes: all Panoptic derivation symbols moved to lib

- [ ] **Step 1: Delete from `VolMarketKey.plk`**

Remove: `MASK_U40` (if only used for Panoptic), `POOL_ID_OFF_*`, `vol_market_key_v4_pattern`, `vol_market_key_v3_pattern`, `vol_market_key_compose_pool_id`, `SEL_SFPM_GET_POOL_ID`, `staticcall_word`, `vol_market_key_to_panoptic_pool_id`.

- [ ] **Step 2: Strip Panoptic handlers from `VolMarketKeyHarness.plk`**

Remove selectors: `v4Pattern`, `v3Pattern`, `composePoolId`, `panopticPoolIdV4`, `goldenPathPanoptic`, `panopticPoolIdOnEmpty` (move incomplete-key test to lib harness).

- [ ] **Step 3: Remove migrated tests from `VolMarketKey.t.sol`**

Delete moved tests; keep KEY-01/03/03b/06 and V4 PoolId canonical tests.

- [ ] **Step 4: Update negative fixture**

```plank
import lib::protocol_integrations::VolMarketKeyLib::*;
// … build Algebra key, call vol_market_key_to_panoptic_pool_id(Algebra, k, 1)
```

Expect compile error text updated to `VolMarketKeyLib: Panoptic arm accepts only V4 or V3`.

- [ ] **Step 5: Chunk approval → commit → push** — full `VolMarketKeyTest` + `VolMarketKeyLibTest` green on `develop-gate`.

---

### Task 6: `PanopticTokenIdSetterLib` + downstream tests

**Files:**
- Modify: `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk`
- Modify: any harness/solidity test passing `pool_id` as `u256` to SetterLib

**Interfaces:**
- Consumes: `PanopticPoolId`, `panoptic_pool_id_word`
- `vol_order_to_panoptic_token_id(T, vo, pool_id: PanopticPoolId)`

- [ ] **Step 1: Change signature + `panoptic_add_pool_id` call**

```plank
import types::protocol_integrations::panoptic_v2::PanopticPoolId::*;

const vol_order_to_panoptic_token_id =
    fn (comptime T: type, vo: VolOrder(T), pool_id: PanopticPoolId) PanopticTokenId {
    // ...
    tid = panoptic_add_pool_id(tid, panoptic_pool_id_word(pool_id));
```

- [ ] **Step 2: Grep and update call sites**

```bash
rg "vol_order_to_panoptic_token_id" test/ src/
```

Wrap literals: `PanopticPoolId { word: poolIdU256 }` in harnesses.

- [ ] **Step 3: Chunk approval → commit → push** — `VolOrderToPanopticTokenId` / related suites on gate.

---

### Task 7: Docs + PR ready

**Files:**
- Create: `docs/superpowers/specs/2026-08-30-volmarketkey-panoptic-pool-id-design.md`
- Modify: `.spec/VOL_MARKET_POOL_KEY_TO_PANOPTIC_POOL_ID.md`
- Modify: this plan file (checkboxes if executed)

- [ ] **Step 1: Commit specs** (force-add `.spec` if needed)

```bash
git add docs/superpowers/specs/2026-08-30-volmarketkey-panoptic-pool-id-design.md \
        docs/superpowers/plans/2026-08-30-volmarketkey-panoptic-pool-id.md
git add -f .spec/VOL_MARKET_POOL_KEY_TO_PANOPTIC_POOL_ID.md
git commit -m "docs(panoptic-pool-id): design spec + implementation plan"
```

- [ ] **Step 2: Mark PR ready** after `develop-gate` green on latest push.

---

## Spec self-review (plan ↔ spec)

| Spec requirement | Task |
|------------------|------|
| `panoptic_v2/PanopticPoolId.plk` | 2 |
| Pure derive, no `sfpm` param | 3 |
| `panoptic_pool_id_verify_sfpm_legacy` | 4 |
| `vegoid` client-only | 3–4 |
| Test split to `test/lib/...` | 1, 5 |
| Trim `VolMarketKey.plk` | 5 |
| `PanopticTokenIdSetterLib` newtype | 6 |
| Algebra compile guard | 1, 5 |
| `develop-gate` | all pushes |

---

## Execution handoff

**Plan saved to** `docs/superpowers/plans/2026-08-30-volmarketkey-panoptic-pool-id.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — execute in this session with chunk approvals per project rules

Which approach?
