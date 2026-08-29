# Pool key requirements

## VolMarketKey(V) — restructured

**Struct fields** (incremental assembly via `Option` slots):

```
const VolMarketKey = fn (comptime V: type) type {
    return struct V {
        pair: Option(Pair),
        registry: Option(Registry(V)),
        pool: Option(Pool(V)),
    };
};
```

**Value constructor** — sole ctor; pass `None` for absent slots, re-pass prior fields when filling:

```
const vol_market_key = fn (
    comptime V: type,
    pair: Option(Pair),
    registry: Option(Registry(V)),
    pool: Option(Pool(V))
) VolMarketKey(V);
```

**Completeness:** `vol_market_key_is_complete` / `vol_market_key_require_complete` / `vol_market_key_finalize`.
Resolve ctors (`vol_market_key_v3_at`, `vol_market_key_algebra_at`, `vol_market_key_v4_at`) build a
complete key in one step. `vol_market_key_verify_pool` delegates to `pool_verify`.

---

## POOL

`Pool(V)` is venue-tagged pool identity with **on-chain resolve** and **registry cross-check verify**.
Structural ctors (`pool_v3`, `pool_algebra`, `pool_v4`) remain for harness migration; canonical path
is `pool_*_at` + `pool_verify`.

Implementation: `src/types/protocol_integrations/Pool.plk`, `PoolId.plk`.

### `PoolId(V)`

| Venue | Representation | Constructor |
|-------|----------------|-------------|
| V4 | `keccak256(PoolKey)` word | `pool_id_v4_from_context(pair, registry, fee_key, tick_spacing)` |
| V3 | pool contract address | `pool_id_v3(pool_addr)` |
| Algebra | pool contract address | `pool_id_algebra(pool_addr)` |

`pool_id_word(V, id)` projects the polymorphic word. V4 hash matches `PoolIdLibrary.toId` in v4-core.

### `Pool(V)` struct

```
struct V {
    pool_id: PoolId(V),
    fee: u256,
    tick_spacing: u256,
}
```

Accessors: `pool_fee`, `pool_tick_spacing`, `pool_word` (= `pool_id_word(V, p.pool_id)`).

**V4 `fee` semantics:** after `pool_v4_at`, `p.fee` is the **current lp fee** read from PoolManager
slot0 (bits 208..231), not the PoolKey fee field. PoolKey fee for dynamic pools is `0x800000`
(`POOL_V4_DYNAMIC_FEE_KEY`).

### Resolve constructors (`pool_*_at`)

| Function | Inputs | On-chain reads | Fills |
|----------|--------|----------------|-------|
| `pool_v3_at(pool)` | pool `addr` | `fee()` `0xddca3f43`, `tickSpacing()` `0xd0c93a7c` | `pool_id`, `fee`, `tick_spacing` |
| `pool_algebra_at(pool)` | pool `addr` | `globalState()` `0xe76c01e4` (fee), `tickSpacing()` | same |
| `pool_v4_at(pair, registry, tick_spacing)` | context + tick anchor | `registry_pool_manager` → `extsload` slot0 | `pool_id` from context hash with dynamic fee key; `fee` = lpFee; `tick_spacing` anchor |
| `pool_v4_at_keyed(..., fee_key)` | explicit PoolKey fee | same as above | same, with caller-supplied fee key |

V4 resolve requires `registry_pool_manager(registry) != 0` and initialized pool (`sqrtPriceX96 != 0`).

Plank calldata: `@mstore4(selector)` at offset 0; args at `+4`, … — same rule as `registry_verify`.

### `pool_verify`

```plank
const pool_verify = fn (
    comptime V: type,
    p: Pool(V),
    pair: Pair,
    registry: Registry(V)
) void;
```

| Venue | Steps |
|-------|-------|
| **V3** | Re-read `fee` / `tickSpacing` from `pool_id` address; `require` match `p`. `factory.getPool(c0,c1,fee)` on registry → `require == pool_id_word`. |
| **Algebra** | Re-read fee/tick from pool; `require` match `p`. `plugin_factory.factory()` then `poolByPair(c0,c1)` → `require == pool_id_word`. |
| **V4** | `require registry_pool_manager != 0`. `extsload` slot0 for `pool_id_word` → `sqrtPriceX96 != 0` and `lpFee == p.fee`. **Does not** re-hash PoolKey with `p.fee` (lp fee ≠ PoolKey fee on dynamic pools). |

Selectors: `getPool` `0x1698ee82`, `poolByPair` `0xd9a641e1`, `factory()` `0xc45a0155`,
`extsload(bytes32)` `0x1e2eaeaf`. Slot0 decode: sqrtPriceX96 low 160 bits; lpFee bits 208..231
(`StateLibrary.getSlot0` layout).

### Error strings

| Condition | Message |
|-----------|---------|
| V4 pool not initialized | `Pool: v4 pool not initialized` |
| Registry lookup mismatch | `Pool: pool_id mismatch` |
| Re-read fee mismatch | `Pool: fee mismatch` |
| Re-read tick_spacing mismatch | `Pool: tick_spacing mismatch` |
| V4 manager zero | `Pool: manager required for V4` |

### VolMarketKey integration

- `vol_market_key_verify_pool(V, k)` → `pool_verify(V, unwrap(k.pool), unwrap(k.pair), unwrap(k.registry))`.
- `vol_market_key_pool_word` → `pool_word`; Panoptic V4 pattern uses real PoolId hash.
- Deleted: `vol_market_key_pool_key_hash`, `vol_market_key_v4_pool_id`.

### Test fixtures (this phase)

| Venue | Deploy / stub |
|-------|----------------|
| V4 | `Deployers` + mined `RegistryVerifyV4` via cfmm-types `Hook.plk`; init with dynamic fee `0x800000` |
| V3 | `PoolVerifyV3Pool` stub (`fee()` / `tickSpacing()` immutables) |
| Algebra | `AlgebraIntegralDeployer` integration pool |

**Deferred:** V3 factory bytecode deployer (`type/volmarketkey-cross`); `cfmm-types` Pool extraction;
quote-orientation helpers.







## `vegoid` — not in `Pair` or `VolMarketKey`

`vegoid` is deliberately outside both types. The same pool key can be initialized under multiple
vegoids in Panoptic.

| Where | Role |
|-------|------|
| `Extra(T)` payload bits 32..39 | Caller declares vegoid in the `FLAG_PANOPTIC` descriptor (40-bit payload) |
| `vol_market_key_to_panoptic_pool_id(..., vegoid)` | Composes candidate Panoptic `poolId` |
| `extra_payload_require_vegoid_agrees(p, pool_id)` | Phase 3 reconciles payload vegoid vs `pool_id` bits 40..47 |

Per-leg `tokenType` also lives in the `Extra(T)` payload (bits `8k+7` per leg), not in `Pair` or
`VolMarketKey`. See `src/types/Extra.plk` and Phase 2.5 design doc.

---

## Spine

**The caller declares, the contract proves.**

| Field | Declared in | Proved against |
|-------|-------------|----------------|
| sorted tokens + asset | `Pair` (embedded in `VolMarketKey`) | sort + remap guards |
| registry | `Registry(V)` (embedded in `VolMarketKey`) | venue tag + `vol_market_key_verify_pool` |
| `tokenType` (per leg) | `Extra(T)` payload | geometric split |
| `vegoid` | `Extra(T)` payload | `pool_id` bits 40..47 |
| fee / tick_spacing / pool | `Pool(V)` (embedded in `VolMarketKey`) | venue rules + `vol_market_key_verify_pool` |
| Panoptic `poolId` | derived candidate | SFPM `getPoolId` |
