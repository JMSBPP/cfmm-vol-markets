# VolMarketKey → PanopticPoolId — extract lib + newtype

**Date:** 2026-08-30  
**Status:** DRAFT — pending maintainer spec review  
**Phase:** follow-on to `type/pool-verify` (merged PR #86)  
**Spec sources:** `.spec/VOL_MARKET_POOL_KEY_TO_PANOPTIC_POOL_ID.md`, `docs/superpowers/specs/2026-08-28-volmarketkey-and-extra-payload-widening-design.md` §5.1 / F3–F5  
**Branch (planned):** `refactor/panoptic-pool-id` or `type/panoptic-pool-id`

---

## 1. Problem

Panoptic derivation (40-bit pattern, 64-bit `poolId` compose, SFPM agreement) currently lives inline in
`src/types/protocol_integrations/VolMarketKey.plk` as `vol_market_key_to_panoptic_pool_id(k, sfpm, vegoid)`.
That couples the **key type** to **Panoptic-specific proof logic** and returns a bare `u256`.

This design:

1. Introduces `PanopticPoolId` as an opaque newtype under `panoptic_v2/`.
2. Extracts derivation into `src/lib/protocol_integrations/VolMarketKeyLib.plk`.
3. Splits **pure derive** (client-supplied `vegoid`, no SFPM) from **legacy SFPM verify** (test harness only).
4. Moves Panoptic lib tests from `test/protocol_integrations/VolMarketKey.t.sol` to
   `test/lib/protocol_integrations/VolMarketKeyLib.t.sol`.

`vegoid` stays **outside** `VolMarketKey` and `Pool(V)` — sourced only by the client call site
(test harness, Phase 3 `Extra(T)` reader, module). Phase 3 payload reconciliation
(`extra_payload_require_vegoid_agrees`) remains above the lib.

---

## 2. Architecture

```
Client (test / VolOrder / module)
  │  VolMarketKey(V), vegoid
  ▼
PanopticPoolId.plk + VolMarketKeyLib (pure)
  vol_market_key_to_panoptic_pool_id(V, k, vegoid) → PanopticPoolId
  │  pattern from pool_word; compose(pattern, vegoid, tick_spacing)
  ▼  optional (test harness only)
VolMarketKeyLibHarness — SFPM legacy verify
  harness_verify_sfpm_legacy(id, sfpm, pool_identity, vegoid)
  │  STATICCALL getPoolId(bytes, uint8 vegoid)
  ▼
PanopticTokenIdSetterLib — pool_id: PanopticPoolId
```

### 2.1 Module layout

| File | Responsibility |
|------|----------------|
| `src/types/protocol_integrations/panoptic_v2/PanopticPoolId.plk` | Newtype + `panoptic_pool_id_compose`; `panoptic_pool_id_word` |
| `src/lib/protocol_integrations/VolMarketKeyLib.plk` | Venue patterns; key→candidate (pure derive only) |
| `test/lib/protocol_integrations/VolMarketKeyLibHarness.plk` | Lib FFI + `harness_verify_sfpm_legacy` (test only) |
| `src/types/protocol_integrations/VolMarketKey.plk` | Key struct, `*_at`, accessors, `verify_pool`, `panoptic_asset_bit` only |
| `test/lib/protocol_integrations/VolMarketKeyLibHarness.plk` | Lib FFI surface |
| `test/lib/protocol_integrations/VolMarketKeyLib.t.sol` | Pattern / compose / derive / SFPM verify tests |
| `test/protocol_integrations/VolMarketKeyHarness.plk` | Trim Panoptic handlers |
| `test/protocol_integrations/VolMarketKey.t.sol` | Key-type tests only |

Import path: `types::protocol_integrations::panoptic_v2::PanopticPoolId::*`

### 2.2 Naming collision

`PanopticTokenId.plk` keeps `panoptic_pool_id(tid: u256) u256` as the **TokenId bitfield getter**.
The newtype `PanopticPoolId` is the **value** passed into `panoptic_add_pool_id`, not that decoder.

---

## 3. `PanopticPoolId` type

```plank
const PanopticPoolId = struct { word: u256 };  // low 64 bits meaningful

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

Layout (PanopticMath.sol:28): `[16b tickSpacing @48][8b vegoid @40][40b pattern @0]`.

---

## 4. `VolMarketKeyLib` API

### 4.1 Pure derivation (default / new API)

```plank
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
        vol_market_key_verify_pool(V, k);  // or pool_verify directly
        panoptic_pool_pattern_v3(pool_word(V3, pool))
    } else {
        @compile_error("VolMarketKeyLib: Panoptic arm accepts only V4 or V3");
    };
    panoptic_pool_id_compose(
        pattern, vegoid, vol_market_key_tick_spacing(V, k)
    )
};
```

- **No `sfpm` parameter.** `vegoid` is used only for compose; supplied by client.
- **Algebra:** compile error at `V` (KEY-04).

### 4.2 SFPM legacy verify (test harness only)

Panoptic SFPM today: `getPoolId(bytes memory id, uint8 vegoid) returns (uint64)`.
Stateful collision handling lives in SFPM storage (design F4). Verification is **not** in
`VolMarketKeyLib` — it lives in `VolMarketKeyLibHarness.plk` as `harness_verify_sfpm_legacy`,
encoding `getPoolId(bytes, uint8)` via staticcall for golden-path and collision tests only.

Production callers derive with `vol_market_key_to_panoptic_pool_id` and reconcile `vegoid` above the
lib (`extra_payload_require_vegoid_agrees`). A future on-chain SFPM verify belongs at the module
boundary, not in the pure derive lib.

### 4.3 Removed from `VolMarketKey.plk`

| Symbol | Destination |
|--------|-------------|
| `MASK_U40`, pattern helpers | `VolMarketKeyLib.plk` or `PanopticPoolId.plk` |
| `vol_market_key_compose_pool_id` | `panoptic_pool_id_compose` |
| `vol_market_key_v4_pattern` / `v3_pattern` | `panoptic_pool_pattern_*` |
| `staticcall_word`, `SEL_SFPM_GET_POOL_ID` | `VolMarketKeyLibHarness.plk` (test only) |
| `vol_market_key_to_panoptic_pool_id` | `VolMarketKeyLib.plk` (derive only) |

**No `u256` shim** — harness and `PanopticTokenIdSetterLib` update in the same phase.

---

## 5. Downstream: `PanopticTokenIdSetterLib`

```plank
const vol_order_to_panoptic_token_id =
    fn (comptime T: type, vo: VolOrder(T), pool_id: PanopticPoolId) PanopticTokenId {
    // ...
    tid = panoptic_add_pool_id(tid, panoptic_pool_id_word(pool_id));
};
```

Phase 3 caller flow:

1. Read `vegoid` from `Extra(T)` payload.
2. `let pid = vol_market_key_to_panoptic_pool_id(V, k, vegoid)`.
3. `extra_payload_require_vegoid_agrees(panoptic_pool_id_word(pid), vegoid)` (above lib).
4. Optionally SFPM verify at module boundary (not in lib; harness has legacy encode for tests).
5. `vol_order_to_panoptic_token_id(T, vo, pid)`.

---

## 6. Testing

### 6.1 `VolMarketKeyLib.t.sol` (moved from `VolMarketKey.t.sol`)

| Test | Surface |
|------|---------|
| `goldenPathEndToEndPanoptic` | derive + `verify_sfpm_legacy` with `SfpmStub` on test state |
| `panopticOnIncompleteKeyReverts` | derive on incomplete key |
| `v4Pattern` / `v3Pattern` fuzz | `panoptic_pool_pattern_*` |
| `v3AndV4PatternsDiffer` | pattern independence |
| `composePoolId` fuzz / zero vegoid | `panoptic_pool_id_compose` |
| `poolIdCandidateMatchingTheSfpmIsReturned` | derive + legacy verify agree |
| `poolIdCollisionMismatchReverts` | legacy verify disagree |
| `algebraKeyIntoPanopticArmDoesNotCompile` | negative fixture → lib import |

`SfpmStub` stays on **test contract state** (`setUp` deploys stub; tests pass `sfpm` + `vegoid` into
verify handler only).

Harness handlers (lib):

- `v4Pattern`, `v3Pattern`, `composePoolId`
- `panopticPoolIdV4(registry, vegoid)` — derive only, returns `panoptic_pool_id_word`
- `verifySfpmLegacy(idWord, sfpm, poolIdentity, vegoid)` — harness `harness_verify_sfpm_legacy`
- `goldenPathPanoptic(registry, sfpm, vegoid)` — derive then verify

### 6.2 `VolMarketKey.t.sol` (stays)

Venue witness, builder completeness, KEY-06 asset bit, pool verify / `*_at` resolve, canonical V4
PoolId through key accessors, `nonVenueTagDoesNotCompile`.

### 6.3 Negative fixtures

- `fixtures/plank-negative/VolMarketKeyAlgebraToPanoptic.plk` → import `VolMarketKeyLib`, expect
  compile error on Algebra `V`.

### 6.4 TDD / CI

- RED: lib harness + moved tests fail before extraction.
- Sign-off: `develop-gate` on PR branch.

---

## 7. Error strings

| Condition | Message |
|-----------|---------|
| `vegoid == 0` at compose | (existing) revert at `panoptic_pool_id_compose` |
| SFPM mismatch (harness) | revert at `harness_verify_sfpm_legacy` |
| Algebra at Panoptic derive | compile error (not runtime) |
| Incomplete key | existing `vol_market_key_require_complete` |

---

## 8. Deferred

| Item | Notes |
|------|-------|
| `panoptic_pool_id_verify_sfpm_v2` | when new SFPM API is pinned |
| V3 Panoptic e2e on live SFPM fixture | optional gap-fill |
| `cfmm-types` extraction of Panoptic types | post-stabilisation |

---

## 9. Acceptance criteria

- [ ] `PanopticPoolId` compiles under `types/protocol_integrations/panoptic_v2/`
- [ ] `vol_market_key_to_panoptic_pool_id(V, k, vegoid)` returns `PanopticPoolId` with **no** `sfpm` arg
- [ ] SFPM legacy verify is harness-only (`harness_verify_sfpm_legacy`); lib is pure derive
- [ ] `vegoid` only enters lib via client parameter (derive + verify forward)
- [ ] Panoptic tests live in `test/lib/protocol_integrations/VolMarketKeyLib.t.sol`
- [ ] `VolMarketKey.t.sol` retains key-type tests only; no regression on KEY-01..06
- [ ] `PanopticTokenIdSetterLib` takes `PanopticPoolId`
- [ ] `develop-gate` green on PR

---

## 10. References

- `src/types/protocol_integrations/VolMarketKey.plk` — current monolithic implementation
- `docs/superpowers/specs/2026-08-28-volmarketkey-and-extra-payload-widening-design.md` — F3–F5, KEY-02/04
- `test/protocol_integrations/VolMarketKey.t.sol` — test migration source
- `lib/panoptic-v2-core` — `PanopticMath.sol`, SFPM `getPoolId`
