# VolMarketKey → PanopticPoolId

Binding summary. Full design:
`docs/superpowers/specs/2026-08-30-volmarketkey-panoptic-pool-id-design.md`.

Prerequisite: complete `VolMarketKey(V)` with resolved `Pool(V)` (`type/pool-verify` merged).

---

## Types

```
types/protocol_integrations/panoptic_v2/PanopticPoolId.plk
```

```plank
const PanopticPoolId = struct { word: u256 };

const panoptic_pool_id_word    = fn (id: PanopticPoolId) u256;
const panoptic_pool_id_compose = fn (pattern, vegoid, tick_spacing) PanopticPoolId;
```

`vegoid != 0` at compose. Layout: `[tickSpacing @48][vegoid @40][pattern @0]` (64 bits).

---

## Lib

```
lib/protocol_integrations/VolMarketKeyLib.plk
```

### Pure derive (new API)

```plank
const vol_market_key_to_panoptic_pool_id =
    fn (comptime V: type, k: VolMarketKey(V), vegoid: u256) PanopticPoolId;
```

- `vegoid` from **client only** — not on `VolMarketKey`, not read from `Extra(T)` inside lib.
- V4: `pattern = low 40 of pool_word`. V3: `pattern = pool_addr >> 120`; `pool_verify` first.
- Algebra: `@compile_error` (no PanopticFactoryAlgebra).

### SFPM legacy verify (test harness only)

Not in `VolMarketKeyLib`. `VolMarketKeyLibHarness.plk` defines `harness_verify_sfpm_legacy`,
encoding `getPoolId(bytes, uint8 vegoid)` via staticcall for golden-path and collision tests.

- `sfpm` is external (test state); not part of derive API.
- Production callers derive only; reconcile `vegoid` above lib (`extra_payload_require_vegoid_agrees`).
- Future on-chain SFPM verify belongs at module boundary, not in the pure derive lib.

---

## Panoptic compose (V4 reference)

Equivalent Solidity (pattern source differs by venue):

```solidity
poolId = uint40(uint256(PoolId.unwrap(poolKey.toId())));
poolId += uint64(uint256(vegoid) << 40);
poolId += uint64(uint24(tickSpacing) << 48);
```

V3 pattern: `uint40(uint160(pool) >> 120)` instead of low 40 of PoolId hash.

---

## Tests

| Suite | Location | Covers |
|-------|----------|--------|
| Lib | `test/lib/protocol_integrations/VolMarketKeyLib.t.sol` | pattern, compose, derive |
| Harness | `VolMarketKeyLibHarness.plk` | SFPM legacy verify (`verifySfpmLegacy`, `goldenPathPanoptic`) |
| Type | `test/protocol_integrations/VolMarketKey.t.sol` | key struct, `*_at`, verify_pool, asset bit |

`SfpmStub` lives on test state; SFPM tests call harness `verifySfpmLegacy` after derive.

---

## Phase 3 handoff

1. Client reads `vegoid` from `Extra(T)` payload.
2. `vol_market_key_to_panoptic_pool_id(V, k, vegoid)`.
3. `extra_payload_require_vegoid_agrees` above lib (payload vs `pool_id` bits 40..47).
4. Optional SFPM verify at module boundary (harness encodes legacy path for tests).
5. `vol_order_to_panoptic_token_id(..., pool_id: PanopticPoolId)`.
