# `Registry` interface verification — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `registry_verify(comptime V: type, r: Registry(V)) void` to `Registry.plk` (hybrid IERC165 + V3 behavioral probe) and fix Algebra `vol_market_key_verify_pool` to resolve pools via `factory().poolByPair`.

**Architecture:** `registry_v4` / `registry_v3` / `registry_algebra` stay structural. `registry_verify` is a separate comptime-dispatched proof fn in the same file. V4: no-op at `address(0)`, else `supportsInterface(IHooks)`. V3: `owner()` staticcall. Algebra: `supportsInterface(IAlgebraPluginFactory)`. `VolMarketKey.plk` Algebra branch becomes two-hop through `factory()`. Tests extend existing `Registry.t.sol` and `VolMarketKey.t.sol` — no new suite files.

**Tech Stack:** Plank (`@evm_staticcall`, `@mstore4`, `std::error::require`), Foundry (`PlankTestBase`, Solidity mocks), verification via `push-build.yml` / `develop-gate.yml`.

**Spec:** `docs/superpowers/specs/2026-08-29-registry-verify-design.md`, `.spec/.research/plank_introspection.md` §4, `.spec/POOL_KEY.md`

## Global Constraints

- **Worktree mandatory.** Branch `type/registry-verify` in `../vol-markets-registry-verify`. Never implement inline on `develop`.
- **Issue + PR before RED commits.** File issue on `develop`; open PR referencing it (`Closes #N`) before first push.
- **NO LOCAL COMPILATION as sign-off.** Verification = `git push` → read `push-build.yml` / `develop-gate` on GitHub Actions.
- **Confirm scope in CI log.** After every push, confirm `RegistryTest` / `VolMarketKeyTest` compiled and **your new tests executed** (not skipped).
- **Chunk approval before commit.** Present each file diff; maintainer approves/modifies; then commit.
- **TDD RED first.** First push intentionally fails until `registry_verify` and Algebra two-hop land.
- **ABI calldata:** `@mstore4(selector)` at offset 0; args at `+4`, `+36`, `+68` — never 32-byte-padded selector words.
- **Name every path on `git add`.** Never stage dirty submodules or unrelated WIP.
- **Scope:** registry verify + Algebra pool-verify fix only. No `cfmm-types`, no `vol_market_key` call-site wiring to invoke `registry_verify`.

---

## File structure (this phase)

| File | Responsibility | Action |
|------|----------------|---------|
| `src/types/protocol_integrations/Registry.plk` | Constants + `registry_verify` | **Modify** (Task 2) |
| `src/types/protocol_integrations/VolMarketKey.plk` | Algebra `verify_pool` two-hop | **Modify** (Task 3) |
| `test/types/protocol_integrations/RegistryHarness.plk` | `registryVerify(uint8,address)` | **Modify** (Task 1) |
| `test/types/protocol_integrations/Registry.t.sol` | Pass/reject tests per venue | **Modify** (Task 1) |
| `test/mocks/RegistryVerifyV4Hooks.sol` | IERC165 + IHooks id | **Create** (Task 1) |
| `test/mocks/RegistryVerifyV3Factory.sol` | `owner()` view | **Create** (Task 1) |
| `test/mocks/RegistryVerifyAlgebraPluginFactory.sol` | IERC165 + `factory()` | **Create** (Task 1) |
| `test/mocks/RegistryVerifyBadInterface.sol` | Wrong `supportsInterface` | **Create** (Task 1) |
| `test/protocol_integrations/VolMarketKey.t.sol` | Plugin-factory stub + algebra tests | **Modify** (Task 3) |
| `.spec/POOL_KEY.md` | Algebra registry = plugin factory | **Modify** (Task 4) |

**Not in this phase:** `cfmm-types` submodule, `registry_verify` at `vol_market_key` boundaries, shared `supports_interface` library.

---

### Task 0: Worktree, interface ids, issue, PR

**Files:** none (git + `gh` + `cast`)

- [ ] **Step 1: Create worktree**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
git fetch origin develop
git worktree add ../vol-markets-registry-verify -b type/registry-verify origin/develop
cd ../vol-markets-registry-verify
```

- [ ] **Step 2: Record interface ids (paste into Task 2 constants)**

```bash
git submodule update --init lib/panoptic-v2-core
npm ci --ignore-scripts 2>/dev/null || true

# IERC165
cast sig "supportsInterface(bytes4)"    # -> 0x01ffc9a7

# V3 behavioral
cast sig "owner()"                      # -> 0x8da5cb5b

# Algebra two-hop (VolMarketKey Task 3)
cast sig "factory()"                    # -> 0xc45a0155
cast sig "poolByPair(address,address)"  # -> 0xd9a641e1

# Interface ids — run against vendored interfaces; record exact hex:
# IHooks (univ4-core):
#   forge inspect IHooks interfaceId --root lib/panoptic-v2-core/lib/v4-core
# IAlgebraPluginFactory (@cryptoalgebra/integral-core):
#   forge inspect IAlgebraPluginFactory interfaceId
```

Record as `IFACE_IERC165`, `IFACE_IHOOKS`, `IFACE_IALGEBRA_PLUGIN_FACTORY` in the PR description. Mocks and Plank constants must match.

- [ ] **Step 3: Open tracking issue**

```bash
gh issue create --repo JMSBPP/cfmm-vol-markets \
  --title "type(registry-verify): registry_verify + Algebra factory().poolByPair" \
  --body "Plan: docs/superpowers/plans/2026-08-29-registry-verify.md
Spec: docs/superpowers/specs/2026-08-29-registry-verify-design.md"
```

Record issue number as `ISSUE_N`.

- [ ] **Step 4: Open draft PR** (after Task 1 first commit or empty shell)

```bash
git push -u origin type/registry-verify
gh pr create --base develop --head type/registry-verify --draft \
  --title "type(registry-verify): registry_verify + Algebra factory().poolByPair" \
  --body "Closes #ISSUE_N

## Plan
docs/superpowers/plans/2026-08-29-registry-verify.md"
```

---

### Task 1: RED — mocks, harness, Registry.t.sol (no `registry_verify` yet)

**Files:**
- Create: `test/mocks/RegistryVerifyV4Hooks.sol`
- Create: `test/mocks/RegistryVerifyV3Factory.sol`
- Create: `test/mocks/RegistryVerifyAlgebraPluginFactory.sol`
- Create: `test/mocks/RegistryVerifyBadInterface.sol`
- Modify: `test/types/protocol_integrations/RegistryHarness.plk`
- Modify: `test/types/protocol_integrations/Registry.t.sol`

**Interfaces:**
- Consumes: `registry_verify(comptime V: type, r: Registry(V)) void` — **does not exist yet** (RED)
- Produces for Task 2:
  ```plank
  const registry_verify = fn (comptime V: type, r: Registry(V)) void;
  ```
- Harness ABI (new):
  - `registryVerify(uint8 venue, address addr)` — `venue`: `1=V4`, `2=V3`, `3=Algebra`; builds `registry_v*(addr)` then calls `registry_verify(V, r)`; returns `uint256 1` on success

**Venue codes (locked):** match `venue_code` in harness: V4=1, V3=2, Algebra=3.

- [ ] **Step 1: Write mocks**

`RegistryVerifyV4Hooks.sol` — implements `supportsInterface(bytes4)`; returns true for `IFACE_IERC165` and `IFACE_IHOOKS` (use bytes4 constants from Task 0).

`RegistryVerifyV3Factory.sol` — `owner() external view returns (address)` returns `address(this)`.

`RegistryVerifyAlgebraPluginFactory.sol` — `supportsInterface` for plugin-factory id; `factory() external view returns (address)` returns immutable inner factory address passed in constructor.

`RegistryVerifyBadInterface.sol` — `supportsInterface` always returns false (shared reject mock for V4/Algebra).

- [ ] **Step 2: Extend RegistryHarness.plk**

```plank
// cast sig "registryVerify(uint8,address)" -> compute before commit
const SEL_REGISTRY_VERIFY = 0x........;

// in run{}:
if selector == SEL_REGISTRY_VERIFY {
    let venue = @evm_calldataload(4);
    let a = addr_from_u256(@evm_calldataload(36));
    if venue == 1 {
        registry_verify(V4, registry_v4(a));
    } else if venue == 2 {
        registry_verify(V3, registry_v3(a));
    } else if venue == 3 {
        registry_verify(Algebra, registry_algebra(a));
    } else {
        require(false);
    }
    let out = @malloc_uninit(32);
    @mstore32(out, 1);
    @evm_return(out, 32);
}
```

- [ ] **Step 3: Extend Registry.t.sol**

Add helper:

```solidity
function _registryVerify(uint8 venue, address addr) internal {
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("registryVerify(uint8,address)", venue, addr)
    );
    require(ok, "registryVerify reverted");
}
```

Add tests:

```solidity
function test__unit__registryVerify_v4_acceptsCompliantHooks() public {
    address hooks = address(new RegistryVerifyV4Hooks());
    _registryVerify(1, hooks);
}

function test__unit__registryVerify_v4_zeroAddressPasses() public {
    _registryVerify(1, address(0));
}

function test__unit__registryVerify_v4_rejectsBadInterface() public {
    address bad = address(new RegistryVerifyBadInterface());
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("registryVerify(uint8,address)", uint8(1), bad)
    );
    assertFalse(ok);
}

function test__unit__registryVerify_v3_acceptsFactory() public {
    address factory = address(new RegistryVerifyV3Factory());
    _registryVerify(2, factory);
}

function test__unit__registryVerify_v3_rejectsEoa() public {
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("registryVerify(uint8,address)", uint8(2), address(0xBEEF))
    );
    assertFalse(ok);
}

function test__unit__registryVerify_algebra_acceptsPluginFactory() public {
    address inner = address(new AlgebraFactoryStub(address(0xCAFE))); // reuse from VolMarketKey.t.sol or duplicate minimal stub
    address plugin = address(new RegistryVerifyAlgebraPluginFactory(inner));
    _registryVerify(3, plugin);
}

function test__unit__registryVerify_algebra_rejectsBadInterface() public {
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("registryVerify(uint8,address)", uint8(3), address(new RegistryVerifyBadInterface()))
    );
    assertFalse(ok);
}
```

Optional pin test:

```solidity
function test__unit__interfaceIds_matchSolidity() public {
    assertEq(type(IERC165).interfaceId, bytes4(0x01ffc9a7));
    // assertEq(type(IHooks).interfaceId, IFACE_IHOOKS);
    // assertEq(type(IAlgebraPluginFactory).interfaceId, IFACE_IALGEBRA_PLUGIN_FACTORY);
}
```

- [ ] **Step 4: Present chunk → approve → commit → push**

```bash
git add test/mocks/RegistryVerifyV4Hooks.sol \
        test/mocks/RegistryVerifyV3Factory.sol \
        test/mocks/RegistryVerifyAlgebraPluginFactory.sol \
        test/mocks/RegistryVerifyBadInterface.sol \
        test/types/protocol_integrations/RegistryHarness.plk \
        test/types/protocol_integrations/Registry.t.sol
git commit -m "test(registry-verify): RED harness and mocks for registry_verify"
git push
```

Expected CI: harness compile **fails** or tests **fail** until Task 2 (intentional RED).

---

### Task 2: GREEN — `registry_verify` in Registry.plk

**Files:**
- Modify: `src/types/protocol_integrations/Registry.plk`

**Interfaces:**
- Consumes: selector/interface-id constants from Task 0
- Produces:
  ```plank
  const registry_verify = fn (comptime V: type, r: Registry(V)) void;
  ```

- [ ] **Step 1: Add constants and helper**

```plank
import std::error::require;

const SEL_SUPPORTS_INTERFACE = 0x01ffc9a7;
const SEL_OWNER = 0x8da5cb5b;
const IFACE_IERC165 = 0x01ffc9a7;           // from Task 0
const IFACE_IHOOKS = 0x........;            // from Task 0
const IFACE_IALGEBRA_PLUGIN_FACTORY = 0x........;

const supports_interface = fn (target: u256, interface_id: u256) void {
    let cd = @malloc_uninit(36);
    @mstore4(cd, SEL_SUPPORTS_INTERFACE);
    @mstore32(cd +% 4, interface_id);
    let ret = @malloc_uninit(32);
    require(@evm_staticcall(@evm_gas(), target, cd, 36, ret, 32));
    require(@mload32(ret) != 0);
};

const registry_verify = fn (comptime V: type, r: Registry(V)) void {
    let target = cast_addr(r.addr, u256);
    if V == V4 {
        if target == 0 { return; }
        supports_interface(target, IFACE_IHOOKS);
    } else if V == V3 {
        let cd = @malloc_uninit(4);
        @mstore4(cd, SEL_OWNER);
        let ret = @malloc_uninit(32);
        require(@evm_staticcall(@evm_gas(), target, cd, 4, ret, 32));
    } else if V == Algebra {
        supports_interface(target, IFACE_IALGEBRA_PLUGIN_FACTORY);
    } else {
        @compile_error("Registry: V must be V4, V3 or Algebra");
    }
};
```

- [ ] **Step 2: Present chunk → approve → commit → push**

```bash
git add src/types/protocol_integrations/Registry.plk
git commit -m "feat(registry-verify): add registry_verify with hybrid IERC165 + V3 owner probe"
git push
```

Expected CI: `RegistryTest` registry-verify tests **PASS**.

---

### Task 3: Algebra pool verify — VolMarketKey.plk + VolMarketKey.t.sol

**Files:**
- Modify: `src/types/protocol_integrations/VolMarketKey.plk`
- Modify: `test/protocol_integrations/VolMarketKey.t.sol`

**Interfaces:**
- Consumes: `SEL_FACTORY = 0xc45a0155`, existing `SEL_POOL_BY_PAIR = 0xd9a641e1`, `staticcall_word`
- Produces: Algebra branch of `vol_market_key_verify_pool` resolves via `factory().poolByPair`

- [ ] **Step 1: Add `AlgebraPluginFactoryStub` to VolMarketKey.t.sol**

Move/replace inline `AlgebraFactoryStub` usage in algebra pool tests:

```solidity
contract AlgebraPluginFactoryStub {
    address internal immutable INNER;

    constructor(address innerFactory_) {
        INNER = innerFactory_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == IFACE_IALGEBRA_PLUGIN_FACTORY;
    }

    function factory() external view returns (address) {
        return INNER;
    }
}
```

Update tests:

```solidity
function test__unit__algebraPoolAddressVerifiedAgainstTheFactory() public {
    address pool = address(0xCAFE);
    address inner = address(new AlgebraFactoryStub(pool));
    address plugin = address(new AlgebraPluginFactoryStub(inner));
    (bool ok,) = harness.staticcall(
        abi.encodeWithSignature("verifyPoolAlgebra(address,address)", plugin, pool)
    );
    assertTrue(ok, "algebra pool matching factory().poolByPair must verify");
}
```

Mismatch test passes **plugin factory** as registry, wrong pool address — unchanged assertion.

- [ ] **Step 2: Update VolMarketKey.plk Algebra branch**

```plank
const SEL_FACTORY = 0xc45a0155;

// inside vol_market_key_verify_pool, Algebra arm:
let plugin_factory = vol_market_key_registry_word(V, k);
let factory_addr = staticcall_word(plugin_factory, factory_cd, 4);  // factory() calldata: @mstore4(cd, SEL_FACTORY)
let p = @malloc_uninit(68);
@mstore4(p, SEL_POOL_BY_PAIR);
@mstore32(p +% 4, vol_market_key_currency0(V, k));
@mstore32(p +% 36, vol_market_key_currency1(V, k));
let resolved = staticcall_word(factory_addr, p, 68);
```

- [ ] **Step 3: Present chunks → approve → commit → push**

```bash
git add src/types/protocol_integrations/VolMarketKey.plk \
        test/protocol_integrations/VolMarketKey.t.sol
git commit -m "fix(registry-verify): Algebra verify_pool via factory().poolByPair"
git push
```

Expected CI: `VolMarketKeyTest` algebra pool tests **PASS**; full suite green.

---

### Task 4: Spec doc + merge gate

**Files:**
- Modify: `.spec/POOL_KEY.md`

- [ ] **Step 1: Update POOL_KEY.md**

Under PREREQ `Registry(V)` add:

- `registry_verify(comptime V, r)` — hybrid proof (V4 zero no-op + IHooks; V3 `owner()`; Algebra `IAlgebraPluginFactory`)
- Algebra `registry.addr` = **plugin factory**; pool lookup = `factory().poolByPair`

- [ ] **Step 2: Present chunk → approve → commit → push**

```bash
git add .spec/POOL_KEY.md
git commit -m "docs(registry-verify): POOL_KEY registry proof + Algebra plugin factory"
git push
```

- [ ] **Step 3: Mark PR ready; wait for develop-gate**

```bash
gh pr ready
gh pr checks --watch
```

- [ ] **Step 4: Merge, teardown worktree, delete branch**

Per `.spec/README.md`: merge PR → `git worktree remove` → `git branch -d type/registry-verify` → delete origin branch.

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| `registry_verify` comptime dispatch | Task 2 |
| V4 zero no-op | Task 2 |
| V3 `owner()` behavioral | Task 2 |
| Algebra IERC165 plugin factory | Task 2 |
| Algebra `factory().poolByPair` | Task 3 |
| Extend Registry.t.sol | Task 1 |
| Extend VolMarketKey.t.sol | Task 3 |
| POOL_KEY.md update | Task 4 |
| No cfmm-types / no vol_market_key wiring | Global constraints |
| ABI `@mstore4` layout | Tasks 2–3 |
| RED-first TDD | Tasks 1 → 2 → 3 |

No placeholder tasks remain; interface id hex filled in at Task 0 from vendored interfaces.
