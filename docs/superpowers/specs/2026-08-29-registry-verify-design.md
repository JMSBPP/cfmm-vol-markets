# Registry interface verification — design spec

**Date:** 2026-08-29  
**Status:** DRAFT — awaiting maintainer review  
**Phase:** Pair follow-on (registry proof layer)  
**Spec source:** `.spec/POOL_KEY.md` § PREREQ `Registry(V)`; `.spec/.research/plank_introspection.md` §4 (IERC165)  
**Depends on:** `type/registry` merged (`Registry.plk`, PR #74); `pair_verify_erc20` pattern (PR #80)

---

## 1. Problem

`Registry(V)` today is **structural only**: a venue-tagged wrapper around a raw `addr`. Callers can
pass any 160-bit address — including EOAs or contracts that are not the expected registry surface
for that venue.

The protocol spine says typed prerequisites are **declared and proved**. `pair_verify_erc20` added
the ERC20 proof layer for `Pair`; this design adds the analogous proof layer for `Registry(V)`.

Additionally, **Algebra registry semantics were wrong** in `vol_market_key_verify_pool`: the code
called `poolByPair` directly on `registry_addr`, but the registry word is an
**`IAlgebraPluginFactory`**, not an `IAlgebraFactory`. Pool lookup must be
`registry.factory().poolByPair(c0, c1)`.

---

## 2. Decisions (locked)

| Topic | Decision |
|-------|----------|
| Algebra registry `addr` | `IAlgebraPluginFactory` (not pool factory) |
| Pool lookup (Algebra) | `factory().poolByPair(...)` — fix `vol_market_key_verify_pool` in same phase |
| Verification style | **Hybrid C:** IERC165 `supportsInterface` where available; behavioral fingerprint for V3 |
| V4 `address(0)` hooks | **Skip verify** — no-op when `addr == 0`; `supportsInterface(IHooks)` when non-zero |
| Phase scope | Registry verify **and** Algebra pool-verify path fix (not registry-only) |
| API shape | Single comptime dispatch: `registry_verify(comptime V: type, r: Registry(V)) void` |
| Placement | **Inline** in `Registry.plk` (mirror `pair_verify_erc20`; extract to `cfmm-types` later) |
| Tests | Extend existing `Registry.t.sol` + `VolMarketKey.t.sol` suites (no new test files) |

---

## 3. Approach

**Recommended (and approved):** inline proof in `Registry.plk`, harness extension, Algebra
two-hop pool verify in `VolMarketKey.plk`, RED-first tests in existing suites.

**Rejected for this phase:**

- `cfmm-types` first (blocks Algebra fix; parallel ERC20 extraction already tracked separately).
- Intermediate `src/lib/Introspect.plk` in vol-markets (extra churn; defer to `cfmm-types`).

---

## 4. API

### 4.1 Structural (unchanged)

```plank
const registry_v4      = fn (hooks: addr) Registry(V4);
const registry_v3      = fn (factory: addr) Registry(V3);
const registry_algebra = fn (factory: addr) Registry(Algebra);
> it returns addr not u256
const registry_addr = fn (comptime V: type, r: Registry(V)) u256 { ... };
```

Constructors remain address-only. **No probes inside ctors.**

### 4.2 Proof (new)

```plank
const registry_verify = fn (comptime V: type, r: Registry(V)) void {
    if V == V4 {
        registry_verify_v4_body(r);
    } else if V == V3 {
        registry_verify_v3_body(r);
    } else if V == Algebra {
        registry_verify_algebra_body(r);
    } else {
        @compile_error("Registry: V must be V4, V3 or Algebra");
    }
};
```

Venue bodies may be inline in the `if` branches or private `const` helpers in the same file — no
shared library extraction in this phase.

### 4.3 Registry address semantics (updated)

| Venue | `Registry(V).addr` | Proof |
|-------|-------------------|-------|
| V4 | hooks contract | IERC165 → `IHooks` when non-zero; no-op at `address(0)` |
| V3 | Uniswap V3 factory | Behavioral: `owner()` staticcall succeeds |
| Algebra | Algebra **plugin** factory | IERC165 → `IAlgebraPluginFactory` |

---

## 5. Per-venue verification

### 5.1 Plank introspection primitives

- Plank has no Solidity `interface` type; proofs use `@evm_staticcall` + returndata checks.
- **ABI calldata:** `@mstore4(selector)` at offset 0; arguments at `+4`, `+36`, `+68` (not
  32-byte-padded selector words — see `pair_verify_erc20` ABI fix, commit on `develop`).
- IERC165 probe pattern (from `.spec/.research/plank_introspection.md` §4):

| Field | Value |
|-------|-------|
| Selector | `supportsInterface(bytes4)` → `0x01ffc9a7` |
| Calldata length | 36 bytes (4 + 32) |
| Success | `staticcall` returns `ok == true` and bool word non-zero |

### 5.2 V4 — `registry_verify` when `V == V4`

```
if cast_addr(r.addr, u256) == 0:
    return   // no hooks — no contract to probe
else:
    staticcall supportsInterface(IHooks_interface_id) on r.addr
    require ok && ret != 0
```

`IHooks_interface_id`: `const` at top of `Registry.plk`, computed from Solidity
`type(IHooks).interfaceId` at implementation time (record value in PR description).

### 5.3 V3 — `registry_verify` when `V == V3`

Uniswap V3 factory does **not** implement IERC165. Behavioral fingerprint:

| Field | Value |
|-------|-------|
| Selector | `owner()` → `0x8da5cb5b` |
| Calldata length | 4 bytes |
| Success | `staticcall` returns `ok == true` |

This proves the address responds as a factory-like contract; it is not a full interface-id check.

### 5.4 Algebra — `registry_verify` when `V == Algebra`

```
staticcall supportsInterface(IAlgebraPluginFactory_interface_id) on r.addr
require ok && ret != 0
```

`IAlgebraPluginFactory_interface_id`: `const` at top of `Registry.plk`, from Solidity
`type(IAlgebraPluginFactory).interfaceId`.

**Not in `registry_verify`:** calling `factory()` or validating the returned pool factory —
that belongs in `vol_market_key_verify_pool` (§6).

---

## 6. `vol_market_key_verify_pool` — Algebra fix

### 6.1 Current (incorrect for plugin-factory registry)

```plank
staticcall_word(registry_addr, poolByPair(c0, c1), 68)
```

### 6.2 Correct (two-hop)

```plank
let plugin_factory = vol_market_key_registry_word(V, k);
let factory_addr = staticcall_word(plugin_factory, factory(), 4);   // SEL_FACTORY TBD
staticcall_word(factory_addr, poolByPair(c0, c1), 68);
require(resolved == vol_market_key_pool_word(V, k));
```

Add `SEL_FACTORY` for `factory()` on `IAlgebraPluginFactory` (compute via `cast sig` at
implementation time).

V3 path **unchanged**: `getPool(c0, c1, fee)` on `registry_addr` directly.

---

## 7. Files

| File | Action |
|------|--------|
| `src/types/protocol_integrations/Registry.plk` | Add selector/interface-id constants + `registry_verify` |
| `src/types/protocol_integrations/VolMarketKey.plk` | Algebra `verify_pool` two-hop via `factory()` |
| `test/types/protocol_integrations/RegistryHarness.plk` | Expose `registryVerify(...)` |
| `test/types/protocol_integrations/Registry.t.sol` | RED/GREEN: pass + reject cases per venue |
| `test/mocks/RegistryVerify*.sol` | Compliant / bad-interface stubs per venue |
| `test/protocol_integrations/VolMarketKey.t.sol` | `AlgebraPluginFactoryStub` + updated algebra pool-verify test |
| `.spec/POOL_KEY.md` | Algebra registry = plugin factory; note `registry_verify` |

**Not in this phase:** `cfmm-types` submodule, `vol_market_key` wiring to call `registry_verify`
at boundaries, IERC165 helper library extraction.

---

## 8. Testing

### 8.1 `Registry.t.sol` (extend existing suite)

| Test | Expect |
|------|--------|
| `registry_verify` V4 compliant hooks stub | pass |
| `registry_verify` V4 `address(0)` | pass (no-op) |
| `registry_verify` V4 non-zero without IHooks | fail |
| `registry_verify` V3 factory stub with `owner()` | pass |
| `registry_verify` V3 EOA | fail |
| `registry_verify` Algebra plugin-factory stub | pass |
| `registry_verify` Algebra wrong interface | fail |

Harness calls use `call` where mutable context is required; all registry probes are expected to be
`staticcall`-safe.

Optional: `test__unit__*InterfaceId_matchSolidity` (mirror `compliantErc20Errors_matchOz`) to pin
interface ids in Foundry before Plank constants are set.

### 8.2 `VolMarketKey.t.sol` (extend existing suite)

- Replace registry-side `AlgebraFactoryStub` with **`AlgebraPluginFactoryStub`**:
  - `supportsInterface(IAlgebraPluginFactory_id)` → true
  - `factory()` → inner `AlgebraFactoryStub` with `poolByPair`
- Existing algebra pool-verify test must still pass with two-hop resolution.

### 8.3 TDD / CI

- RED harness + mocks + tests before `registry_verify` body lands.
- Verification gate: `push-build` / `develop-gate` on feature branch (not local sign-off).
- Worktree branch per `.spec/README.md` (e.g. `type/registry-verify`).

---

## 9. Deferred

| Item | Notes |
|------|-------|
| `supports_interface(addr, id)` in `cfmm-types` | Extract after inline stabilises (cfmm-types #5 parallel) |
| `registry_verify` at `vol_market_key` boundaries | Separate wiring phase |
| Legacy factories without IERC165 beyond V3 `owner()` | Broader compatibility pass |
| V4 hooks permission / callback behavioural probes | IERC165 sufficient for this phase |
| Update upstream `d2p-finance/cfmm-vol-markets-spec` research doc | After vol-markets PR merges |

---

## 10. Acceptance criteria

- [ ] `registry_verify(V, r)` compiles for V4, V3, Algebra; rejects non-venue at comptime
- [ ] V4 zero-address no-op; non-zero requires `IHooks` interface id
- [ ] V3 requires successful `owner()` staticcall
- [ ] Algebra requires `IAlgebraPluginFactory` interface id
- [ ] `vol_market_key_verify_pool(Algebra, k)` uses `factory().poolByPair`
- [ ] All new tests in `Registry.t.sol` and updated `VolMarketKey.t.sol` tests pass on CI
- [ ] `.spec/POOL_KEY.md` updated for Algebra registry semantics

---

## 11. References

- `src/types/Pair.plk` — `pair_verify_erc20` inline probe pattern
- `src/types/protocol_integrations/Registry.plk` — current structural API
- `src/types/protocol_integrations/VolMarketKey.plk` — `vol_market_key_verify_pool`
- `.spec/.research/plank_introspection.md` — IERC165 + ABI calldata notes
- `docs/superpowers/specs/2026-08-29-pool-market-key-design.md` §4 (superseded for Algebra registry row)
- `lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol` — V3 `owner()` fingerprint
