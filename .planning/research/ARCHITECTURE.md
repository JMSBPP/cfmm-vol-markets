# Architecture Research

**Domain:** Plank EVM on-chain module — dynamic-registry + best-effort multicall (VolOrderManagerMod, milestone v4.0)
**Researched:** 2026-07-19
**Confidence:** HIGH (all mechanisms transcribed from repo source; only the batch-calldata shape and tuple-array ABI depend on the parallel STACK capability audit, and are flagged not resolved)

---

## Standard Architecture

The milestone mirrors the v3.0-proven layering exactly. Nothing here is new *shape*; the two genuinely new elements are (a) a **derived-slot dynamic registry** (the ring's slot-per-index mechanism, minus the wraparound), and (b) a **best-effort batch loop** over calldata.

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│  src/interfaces/pos_spec/VolOrderManagerInterface.plk                  │
│  cast-sig-pinned SELECTOR_* strings (create_order 0x6501fe94 + batch)  │
├──────────────────────────────────────────────────────────────────────┤
│  src/modules/…/VolOrderManagerMod.plk                   (STATEFUL)     │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────────────────┐ │
│  │ dispatch   │  │ id assignment│  │ batch loop (validate-then-commit│ │
│  │ shr-224    │  │ orderCount++ │  │  per-call, best-effort skip)    │ │
│  └─────┬──────┘  └──────┬───────┘  └───────────────┬────────────────┘ │
│        │                │  sstore/sload ONLY — ZERO arithmetic         │
├────────┴────────────────┴──────────────────────────┴──────────────────┤
│  src/lib/… (PURE)                     src/types/pos_spec/VolOrder.plk  │
│  ┌───────────────────────┐            ┌──────────────────────────────┐│
│  │ validate_order bounds  │            │ pack_vol_order / unpack       ││
│  │ (compose is_complete)  │            │ (152-bit packing precedent)   ││
│  └───────────────────────┘            └──────────────────────────────┘│
│  v3::storage::array_slot  ── keccak256(base)+index  (slot derivation)  │
├────────────────────────────────────────────────────────────────────────┤
│  STORAGE  keccak-derived scalar slot + a keccak-base derived array      │
│  ┌─────────────────┐   ┌──────────────────────────────────────────────┐│
│  │ SLOT_ORDER_COUNT│   │ orders[id] @ keccak256(SLOT_ORDERS_BASE)+id   ││
│  │  (scalar u256)  │   │  one packed VolOrder word per id (128–152 bit) ││
│  └─────────────────┘   └──────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Precedent it mirrors |
|-----------|----------------|----------------------|
| `VolOrderManagerInterface.plk` | cast-sig-pinned selector strings, shared by module dispatch + Solidity test ABI | `VegaAccountInterface.plk` |
| `VolOrderManagerMod.plk` | dispatch, `orderCount` id assignment, sstore at derived slot, batch loop, best-effort skip — **no arithmetic, no pricing** | `VegaAccountMod.plk` (module) + `RealizedVolatilityMod.plk` (ring writes) |
| `validate_order` (new pure lib) | bounds check composed from the existing `*_is_complete` fns; explicit zero-width revert | `vol_order_is_complete` in `VolOrder.plk` |
| `VolOrder.plk` type | `pack_vol_order`/`unpack_vol_order`; the packed word stored per id | already exists (KEPT type) |
| `v3::storage::array_slot` | `keccak256(base)+index` slot derivation | already exists (used by the ring) |

---

## The slot-per-index mechanism (transcribed from actual source)

**Quality-gate item.** The registry stores one order per derived slot using the *exact* helper the RealizedVolatility ring uses. The helper is `array_slot`, from `lib/plankified-univ3/plank/lib/storage.plk:230-235`:

```plank
const array_slot = fn (base_slot: u256, index: u256) u256 {
    // keccak256(base_slot) + index
    let buf = @malloc_uninit(32);
    @mstore32(buf, base_slot);
    @evm_keccak256(buf, 32) + index
};
```

So the slot is `keccak256(base_slot) + index`, where `base_slot` is itself a named-string keccak constant (e.g. `SLOT_TIMEPOINT_BUFFER_BASE = 0xe4a8c01f…` = keccak of `"RealizedVolMod.TimepointBuffer"`). It is a **double keccak** at the base plus a linear offset — `@mstore32` writes the u256 as one big-endian 32-byte word, then `@evm_keccak256(buf,32)` hashes that word.

The ring reads through `load_timepoint` (`src/lib/market_state_measurements/RealizedVolatilityLib.plk:84-86`):

```plank
const load_timepoint = fn(buffer_base: u256, index: u256) Timepoint {
      unpack_timepoint(@evm_sload(array_slot(buffer_base, index & TIMEPOINT_INDEX_MASK)))
};
```

and writes through the same slot in `RealizedVolatilityMod.plk:161`:

```plank
@evm_sstore(array_slot(SLOT_TIMEPOINT_BUFFER_BASE, index_updated.current), pack_timepoint(updated));
```

**The critical difference for a registry vs. a ring.** The ring MASKS the index to 16 bits (`& TIMEPOINT_INDEX_MASK`, `& INDEX_MODULO_MASK` in `StorageIndex::next`) so it wraps at 2^16 — the mask is documented as *load-bearing, not defensive* (`StorageIndex.plk:19-34`): without it a write at index 65536 lands at `keccak(base)+65536`, OUTSIDE the ring, while reads masked back to 0 and "the oracle silently rewound to its initialization state on wrap." **The registry must NOT mask** — `orderId` is monotonic (`orderCount` only ever increments, never wraps), so `array_slot(SLOT_ORDERS_BASE, orderId)` walks `keccak(base)+0, +1, +2, …`. Because `keccak(base)` is a pseudo-random 256-bit point, linear offsets up to any realistic `orderCount` never collide with each other or with the scalar slot. **Do not import the ring's mask; that is the one line of the ring mechanism that is wrong for a registry.**

### VolOrder packing (transcribed + summed)

**Quality-gate item.** `pack_vol_order` (`src/types/pos_spec/VolOrder.plk:35-40`) packs FOUR fields:

```plank
@evm_shl(128, self.rangeWidth.width       & 0xFFFFFF)                 // 24 bits @ 128-151
| @evm_shl(104, self.rangeWidth.tickSpacing & 0xFFFFFF)               // 24 bits @ 104-127
| @evm_shl(16,  self.volStrike.vol & 0xFFFFFFFFFFFFFFFFFFFFFF)         // 88 bits @  16-103
| (self.skew.spread & 0xFFFF)                                         // 16 bits @   0- 15
```

Width sum: `24 (tickSpacing) + 24 (width) + 88 (vol) + 16 (skew) = 152 bits`. The type header comment already states "It fits on 152 bits." **Packing into ONE 256-bit word: YES**, with 104 bits to spare.

**Design tension to surface (do not silently resolve):** the KEPT `VolOrder` packs **four** fields (152 bits, includes `tickSpacing`), but the peer-confirmed `create_order(uint88,uint24,uint16)` selector `0x6501fe94` supplies **three** — strike (u88) + width (u24) + skew (u16) = **128 bits**, NO `tickSpacing`. Two options, each with a downstream consequence:

- **Store the create_order-native 128-bit subset** (`skew | volStrike | width`, offsets 0/16/104, `tickSpacing` bits 128-151 left zero). Matches exactly what the registry receives; `tickSpacing`/pricing is explicitly OUT of scope this milestone (PROJECT.md line 20). Recommended for the registry.
- **Store the full 152-bit `VolOrder`** — requires a `tickSpacing` source, and `vol_range_width_is_complete` *requires* `tickSpacing ∈ (0, 0xc8]`, so a defaulted 0 would fail the existing validator. This couples the registry to pricing bounds it should not own.

Recommendation: **store the 128-bit subset**, mirror `pack_vol_order`'s offsets for the three shared fields (16/104 unchanged), and add a test-side `VolOrderDecoder` per the `TimepointDecoder` precedent. Flag the 152-vs-128 divergence in the plan so the roadmapper decides whether `tickSpacing` re-enters when pricing lands.

---

## Layer split (the v3.0 zero-math-in-module rule)

The rule that made v3.0 cheap to prove: **the module holds ZERO arithmetic** (`VegaAccountMod.plk:39` — "ALL issuance math routes through the lib"). Applied here:

| Concern | Layer | Rationale |
|---------|-------|-----------|
| `validate_order` bounds (strike>0, width∈(0,0xffffff], skew∈(0,0xffff)), zero-width revert | **pure lib** (`src/lib/pos_spec/VolOrderManagerLib.plk`, new) | Composes the existing `tick_volatility_is_complete` / `spread_tick_assimetry_is_complete` and a **reduced** width check (NOT `vol_range_width_is_complete`, which needs `tickSpacing`). Independently fuzz-testable with no deploy. |
| `pack_vol_order` / `unpack_vol_order` | **type** (`VolOrder.plk`, exists) | Already the packing precedent. |
| Slot derivation `array_slot(base, id)` | **pure lib** (`v3::storage`, exists) | Reuse verbatim — no new slot math in the module. |
| `orders[id] = packed`, `orderCount++`, id assignment, batch loop, best-effort skip | **module** | Only `sstore`/`sload`/dispatch, exactly like the ring's write path and the vault's accumulators. |

**What made v3.0 cheap to prove and must be preserved:** every stored field has a reader (module-not-a-black-box), the module reverts through lib guards (the guard's revert "comes free"), and the differential asserts against a Solidity reference mock at tolerance 0. `validate_order` living in a pure lib means the bounds battery is a pure-function fuzz with no FFI deploy — the fastest surface to redden.

**Bounds precedents (already in the type layer, ready to compose):**
- `tick_volatility_is_complete` — `self.vol > 0` (strike must be nonzero).
- `spread_tick_assimetry_is_complete` — `spread > 0 & spread < 0xffff` (skew bounds).
- `vol_range_width_is_complete` — `width>0 & width<=0xffffff & tickSpacing>0 & tickSpacing<=0xc8`. The registry needs only the **width** half of this (the `tickSpacing` half depends on data create_order does not carry), so `validate_order` calls a *reduced* width check plus the explicit zero-width revert PROJECT.md line 20 mandates.

---

## Storage layout for the dynamic registry

```
SLOT_ORDER_COUNT   = keccak256("VolOrderManagerMod.orderCount")   // scalar u256, next id
SLOT_ORDERS_BASE   = keccak256("VolOrderManagerMod.orders")       // array base (a keccak-of-string const)

orders[id]  @  array_slot(SLOT_ORDERS_BASE, id) = keccak256(SLOT_ORDERS_BASE) + id
            holds ONE packed VolOrder word:
              bits  0- 15  skew        (u16)
              bits 16-103  volStrike   (u88)
              bits104-127  width       (u24)          } create_order supplies these three
              bits128-151  tickSpacing (u24)  ← zero this milestone (deferred with pricing)
```

The scalar slot (`SLOT_ORDER_COUNT`) follows the `VegaAccountMod` precedent verbatim (`VegaAccountMod.plk:11-17`): a keccak-of-named-string constant holding a plain u256, **preimage string restated test-side** so `vm.load` addresses are computable in Solidity. The derived array base is the same construction, consumed through `array_slot`.

---

## Best-effort multicall — the semantics that make it provable

PROJECT.md line 21: *"failed orders are skipped without reverting the batch, per-call success/order-id results returned; a failed call leaves NO partial state, successful calls persist."*

**Critical architectural decision: validate-BEFORE-commit, not write-then-rollback.** A single Plank call frame has no sub-call try/catch to roll back one order's writes. The way to guarantee "a failed call leaves NO partial state" cheaply is to **validate each order's bounds first, and only `sstore`+`orderCount++` if it passes**. A failing order never touches storage, so "no partial state" is true by construction — no rollback machinery, no self-`CALL`. This mirrors the vault's guard-then-write ordering (`VegaAccountMod.plk`: guards fire *before* the three accumulator writes) and is the reason it stayed cheap to prove.

Per-call result: accumulate a `(success, orderId)` array in memory and ABI-return it. Consumer contract (rpc_api track `mv15a18k`) has confirmed the create_order selector but the **return shape and batch-size bound are still open** (PROJECT.md line 25) — requirements assume `(success, orderId)` pairs until the peer answers.

---

## Batch entrypoint — calldata layout options (BOTH presented; capability dependency stated, not resolved)

**Quality-gate item.** Which of these is buildable depends on the STACK capability audit running in parallel (PROJECT.md line 22 names dynamic-array ABI decoding as *"the milestone's main technical risk"* — every existing module selector takes fixed words). Present both; the roadmapper resolves after STACK reports.

### Option A — head-count-then-tuples (dynamic array)

Signature candidates: `create_orders(uint256 count, bytes packed)` **or** `create_orders((uint88,uint24,uint16)[])`.

Calldata (standard ABI dynamic): `selector | offset-word | length-word | element[0] | element[1] | …`. Plank must: read the offset word, follow it to the length word, loop `length` times reading `32*i` strides.

- **Pros:** unbounded N (up to gas/calldata limit); idiomatic ABI; a Solidity/`cast`/Haskell client encodes it natively.
- **Cons:** Plank calldata decoding of a *dynamic* array is unproven in this codebase — genuinely new ground. The **`(uint88,uint24,uint16)[]` tuple-array encoding in particular may exceed what Plank-side decoding supports** (a tuple array adds head/tail indirection on top of the length prefix). **Flag, do not resolve** — pending STACK.

### Option B — fixed-max-with-count

Signature: `create_orders(uint256 count, uint256[N] packedOrders)` with a compile-time `N` (e.g. 8 or 16), `count ≤ N` valid entries, each entry a pre-packed 128-bit word.

Calldata: `selector | count | word[0] | … | word[N-1]` — **all fixed offsets, no indirection.** Plank reads `@evm_calldataload(4 + 32*i)` in a bounded loop, exactly the fixed-word access every existing selector already uses (`RealizedVolatilityMod.plk` run block, `VegaAccountMod.plk` run block).

- **Pros:** decodable with the calldata primitives already proven in-repo; no dynamic-offset arithmetic; caps gas by construction (bounds the batch-size the consumer asked about).
- **Cons:** wastes calldata for partial batches; hard N ceiling; the client must pre-pack each order into a word (moves packing off-chain, or requires a 3-arg fixed tuple `(uint88,uint24,uint16)[N]`).

**Dependency statement (unresolved):** if the STACK audit finds Plank cannot decode a dynamic array / tuple array, Option B is the fallback and the peer's batch-size bound becomes the compile-time `N`. If dynamic decoding is supported, Option A with `create_orders(uint256,bytes)` (client packs, Plank slices fixed 16-byte strides out of `bytes`) is the middle path — dynamic length, but each element is fixed-width so no per-element tuple indirection. The `(uint88,uint24,uint16)[]` fully-typed variant is the highest-risk and should not be assumed buildable. **This is the milestone's main technical risk (PROJECT.md line 22) and is deliberately left for STACK to resolve.**

---

## Test-side architecture

### Reference mock (mirror the registry)

A trivially-simple Solidity mirror: a `mapping(uint256 => VolOrder)` (or a growable array) + `uint256 count`, plus the **same** `validate_order` bounds re-expressed in Solidity. Precedent: `IssuanceRefMock` behind `VegaAccountE2EDiffTest` — "three uint256 accumulators… A mirror with any arithmetic of its OWN would be a second implementation to distrust." The registry mirror does no math beyond bounds checks and id increment.

### Driver pattern (after-every-write, from v2.0/v3.0)

From `VegaAccount.e2e.t.sol`: the assertion lives **INSIDE** the driver helper (`_depositBoth`/`_setPriceBoth`) so "after every write cannot be forgotten at a call site, and the driver aborts at the EARLIEST write a mutant can diverge." For the registry: a `_createOrderBoth(strike,width,skew)` helper that calls the module, updates the mirror, and asserts `orderCount` + the stored packed word + the returned id all match — every call, tolerance 0. For the batch: a `_batchBoth(orders[])` that runs the same sequence one-at-a-time in the mirror (skipping invalid) and asserts the surviving set + count match the module's best-effort result.

### `vm.load` raw-slot assertions for DERIVED (not constant) slots

The vault raw-loads its four **constant** scalar slots. For the registry's **derived** slots the test computes the same double-keccak the module does:

```solidity
bytes32 SLOT_ORDERS_BASE = keccak256("VolOrderManagerMod.orders"); // restate the preimage
uint256 slot = uint256(keccak256(abi.encode(SLOT_ORDERS_BASE))) + orderId; // == array_slot(base, id)
uint256 word = uint256(vm.load(address(mod), bytes32(slot)));
VolOrder memory got = VolOrderDecoder.decode(word); // TimepointDecoder-style mirror
```

Note the **double keccak**: `array_slot` hashes the base *word*, so the test side must `keccak256(abi.encode(SLOT_ORDERS_BASE))` (hash the 32-byte base again), then add `orderId`. This is exactly `@mstore32(buf, base); @evm_keccak256(buf,32)+index`. The `VolOrderDecoder` library restates `VolOrder.plk`'s offsets by hand (offsets 0/16/104[/128]) — the `TimepointDecoder` precedent: *"THE single test-side unpacker… The offsets are mirrored, not shared… If Timepoint.plk moves a field, this file must move with it — and the differential is what makes that failure loud."* The existing `test/types/pos_spec/VolOrder.t.sol` already carries `packVolOrder`/`unpackVolOrder` at these exact offsets — promote them into a shared `VolOrderDecoder` rather than a fourth copy.

Complementary reader path: expose `getOrderPacked(uint256 id) -> uint256` (mirror of `getTimepointPacked(uint16)` in `RealizedVolatilityMod.plk:275-278`), so the differential can read through the ABI *and* raw-`vm.load` the same slot — the two must agree, which kills any reader that lies about storage.

---

## Suggested build order

Each step is independently testable; the arrow marks the dependency.

1. **Type packing** — `VolOrder.plk` pack/unpack (EXISTS; only decide 128-bit subset vs 152-bit full). *Test:* `VolOrder.t.sol` already round-trips pack/unpack. Independently testable, no module.
2. **Lib validation** — `validate_order` composing `tick_volatility_is_complete` + a reduced width check + `spread_tick_assimetry_is_complete`, with the explicit zero-width revert. *Test:* pure fuzz, no FFI deploy. Independently testable.
3. **Interface** — `VolOrderManagerInterface.plk` with ALL selectors: `create_order` (`0x6501fe94`, cast-sig re-verified), readers (`getOrderPacked`, `orderCount`), and the batch selector (shape pending STACK — see below). *Test:* `cast sig` each string.
4. **Module single-call** — `create_order`: dispatch, validate via lib, pack via type, `orderCount++`, `sstore` at `array_slot(base,id)`. *Test:* selector dispatch + raw-`vm.load` at the derived slot + reader round-trip.
5. **Module batch** — best-effort loop, validate-before-commit, per-call `(success,orderId)` return. Depends on 4 and on the STACK calldata decision. *Test:* mixed valid/invalid batch, assert survivors persist, invalids leave no state.
6. **Differential + battery** — reference-mock mirror + after-every-write driver + observed-RED mutation battery, single-call then batch. *Test:* the acceptance surface.

**Independently testable without the module:** steps 1 (type), 2 (lib) — pure functions, fuzzed with no deploy. **Requires FFI deploy:** 4, 5, 6. **Blocked on STACK:** the batch signature string in 3, and step 5's calldata decoding.

---

## Data Flow

### create_order (single)

```
create_order(strike,width,skew)  [selector 0x6501fe94]
    ↓ dispatch (shr-224)
validate_order(strike,width,skew)          — pure lib, revert on zero-width / out-of-bounds
    ↓ ok
pack_vol_order(...)                          — type: one 128-bit word
    ↓
id = sload(SLOT_ORDER_COUNT)
sstore(array_slot(SLOT_ORDERS_BASE, id), packed)
sstore(SLOT_ORDER_COUNT, id + 1)
    ↓
return id
```

### create_orders (batch, best-effort)

```
create_orders(<count-then-tuples | fixed-max>)
    ↓ decode count + elements  (Option A dynamic | Option B fixed — pending STACK)
for each element:
    validate_order(...)  →  FAIL: record (false, 0), CONTINUE  (no sstore, no state)
                            OK:   pack, id=sload(count), sstore slot, sstore count+1,
                                  record (true, id)
    ↓
ABI-return [(success, orderId), …]
```

---

## Scaling Considerations

| Scale | Architecture note |
|-------|-------------------|
| tens of orders (StochasticOrderGen Poisson batches) | the intended regime; any layout works, gas is dominated by `sstore` (20k/order), not decoding |
| thousands of orders | monotonic ids never collide; no ring wrap concern; batch gas caps naturally under the block limit — Option B's `N` or Option A's implicit gas ceiling is the real bound |
| beyond one contract's storage | not a concern for a research registry; sharding is out of scope |

The only real bottleneck is **calldata decoding cost/complexity of the batch**, which is a correctness/feasibility question (Option A vs B) rather than a throughput one.

---

## Anti-Patterns

### Anti-Pattern 1: importing the ring's index mask into the registry

**What people do:** reuse `StorageIndex::next` / `& INDEX_MODULO_MASK` because the slot helper came from the ring.
**Why it's wrong:** the mask makes ids wrap at 2^16; the registry needs monotonic ids. The ring's own comments call the mask "load-bearing" *for a ring* — for a registry it silently overwrites order 0 with order 65536.
**Do this instead:** monotonic `orderCount`, no mask; `array_slot(base, id)` directly.

### Anti-Pattern 2: arithmetic in the module

**What people do:** inline the bounds check or the id-derivation math in the dispatch body.
**Why it's wrong:** breaks the zero-math-in-module rule that made v3.0's mutation battery cheap — arithmetic in the module is a surface the pure-lib fuzz can't reach.
**Do this instead:** `validate_order` in a pure lib, packing in the type, slot in `v3::storage`. Module = sstore/sload/dispatch only.

### Anti-Pattern 3: write-then-rollback for best-effort batch

**What people do:** try to `sstore` each order and undo on failure.
**Why it's wrong:** a single call frame has no partial rollback; "no partial state" becomes unprovable.
**Do this instead:** validate-before-commit — a failing order never writes.

### Anti-Pattern 4: a fourth copy of the VolOrder bit layout

**What people do:** re-inline `packVolOrder` offsets in the new differential.
**Why it's wrong:** the `TimepointDecoder` post-mortem — three copies of a bit layout is three chances to desync from the `.plk` source.
**Do this instead:** one `VolOrderDecoder` library, offsets restated once, the differential makes any future drift loud.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| module ↔ pure lib | direct `import` of `validate_order` | ALL bounds/reverts here; module holds none |
| module ↔ type | direct `import` of `pack_vol_order` | one packed word per id |
| module ↔ `v3::storage` | `array_slot(base, id)` | reuse verbatim; DO NOT re-derive, DO NOT mask |
| module ↔ Solidity test | `VolOrderManagerInterface` selector strings | pinned once, drive module dispatch AND test ABI |
| module ↔ rpc_api track (`mv15a18k`) | `create_order` selector `0x6501fe94` (confirmed) | batch return-shape + size-bound OPEN, awaiting peer |

### External / cross-track dependency (unresolved by design)

| Dependency | Status | Blocks |
|------------|--------|--------|
| Plank dynamic-array / tuple-array calldata decoding | pending STACK capability audit (parallel) | the batch calldata layout (Option A vs B) and the batch signature string |
| Peer batch-size bound + per-call return shape | open (PROJECT.md line 25) | Option B's compile-time `N`; the return ABI |

---

## Sources

- `lib/plankified-univ3/plank/lib/storage.plk:230-235` — `array_slot` = `keccak256(base)+index` — HIGH (quoted verbatim)
- `src/lib/market_state_measurements/RealizedVolatilityLib.plk:84-86` — `load_timepoint` — HIGH (quoted verbatim)
- `src/modules/market_state_measurements/RealizedVolatilityMod.plk` — ring write/read path, `getTimepointPacked` reader — HIGH (repo source)
- `src/types/StorageIndex.plk:19-34` — the load-bearing wraparound mask (the one line a registry must drop) — HIGH
- `src/types/pos_spec/VolOrder.plk:35-60` — `pack_vol_order`/`unpack_vol_order`, 152-bit sum — HIGH
- `src/types/pos_spec/{VolRangeWidth,TickVolatility,SpreadTickAssimetry}.plk` — the `*_is_complete` bounds the lib validator composes — HIGH
- `src/types/market_state_measurements/Timepoint.plk` + `test/market_state_measurements/TimepointDecoder.sol` — packing + test-decoder precedent — HIGH
- `src/modules/exposure/VegaAccountMod.plk` + `src/interfaces/exposure/VegaAccountInterface.plk` — zero-math-in-module, scalar-slot + selector-pinning pattern — HIGH
- `test/exposure/VegaAccount.e2e.t.sol` — after-every-write driver, trivially-simple mirror, tolerance-0 differential — HIGH
- `test/types/pos_spec/VolOrder.t.sol` — existing test-side `packVolOrder` offsets (promote to a shared decoder) — HIGH
- `test/PlankTestBase.sol` — `deployPlank` / module-root deps — HIGH
- `.planning/PROJECT.md` (v4.0 milestone) — best-effort semantics, dynamic-array-ABI risk flag, peer consumer contract — HIGH

---
*Architecture research for: Plank dynamic-registry + best-effort multicall module (VolOrderManagerMod, v4.0)*
*Researched: 2026-07-19*
