# MevTaxModelOne `Shock` Library — Specification

**Date:** 2026-08-16
**Milestone:** v6.0 (mev_tax_model_one on-chain VolumePath execution), Phase 23 / EXEC-03
**Status:** Design spec — two-step reviewer gate waived per the v6.0 heavy-intervention pattern (every
line under direct user approval instead).
**Consumed by:** the writer's `beforeSwap` (decode + emit) and its future `SELECTOR_NEXT` (encode).

---

## 1. Purpose

A **bidirectional** plank library for the mev_tax_model_one *shock*. It:

1. **encodes** shock components → `hookData` bytes (the outbound "→" direction: what a swap carries),
2. **decodes** `hookData` → a `Shock` (what `beforeSwap` reads), and
3. **emits** the shock event (the type owns its own event).

The encoding is **self-describing (tagged)**: which of the three components are present is read from a
`flags` word, NOT inferred from the payload length or a fixed positional order. Length is *derived*
from `flags`, not the discriminator.

## 2. The `Shock` — three sized components, one per region

| Component (accessor) | Type | Spec symbol | Writer source (`next` ABI) |
|---|---|---|---|
| `tickDiff` | `int24` | `Δp/p` as a signed tick delta (`write_price`) | `int24 tick` |
| `txlVolmNormRate` | `uint24` | `δ_trans` — returned adjusted transactional volume rate | `uint24 txlVolumeRate` |
| `txlVolmDecay` | `uint24` | `α_trans` — transactional volume decay rate | `uint24 txlDecayRate` |

Sizes are grounded in the writer's own `next` ABI
(`next(address, uint160 sqrtPrice, int24 tick, uint24 txlVolumeRate, uint24 txlDecayRate)`) and in
Algebra's fee width: both rates ultimately parametrize the dynamic-fee sigmoid whose output is
`uint24` (`feeOverride`/`pluginFee`), so carrying more bits than the fee can express is dead precision.
A normalized rate / decay in `[0,1)` fits `uint24` at a `2^24` denominator with ~6e-8 resolution.

**`tickDiff` is the pinned `priceChange`**: the spec's price shock is a pair `(p_φ, i)`, but v6.0 sends
no price at all, so `priceChange` is pinned to the signed `int24` tick delta for now. The `uint160
sqrtPrice` half stays deferred — when it lands (post-v6.0), `tickDiff`'s bit widens to carry the extra
field, and the tagged scheme absorbs that without disturbing the two rates.

`Shock` is a **comptime type constructor** parametric over the byte region `R`
(`std::regions`: `memory` | `calldata` | `code`) — the `bytes(region)` / `Option(T)` idiom. A
`Shock(R)` is a validated **view** over its packed `hookData` in region `R`; the same decode/accessor
code serves the in-memory round-trip (`Shock(memory)`) and `beforeSwap` (`Shock(calldata)`), zero-copy.

```plank
const Shock = fn (comptime R: type) type {
    return struct {
        data: bytes(R),   // packed hookData in region R (see §3)
        flags: u256,      // validated presence word (low 3 bits)
    };
};
```

## 3. Encoding — tagged / self-describing, **packed** (big-endian)

```
hookData = flags(uint8) || [ tickDiff(int24) ] || [ txlVolmNormRate(uint24) ] || [ txlVolmDecay(uint24) ]
           └ 1 byte ─┘    └──── present components only, in canonical order, 3 bytes each ────┘
```

- **`flags`** — a single leading `uint8` byte; low 3 bits mark presence:
  - `bit 0 (0b001)` = `tickDiff` present
  - `bit 1 (0b010)` = `txlVolmNormRate` present
  - `bit 2 (0b100)` = `txlVolmDecay` present
- Present values follow **in ascending component order**, each a fixed **3-byte** field
  (`int24`/`uint24`), tightly packed — no word alignment. `k = popcount(flags & 0b111)`.
- **Absent components decode to `0`.**
- Total length = `1 + 3 * k` bytes — *derived* from `flags`, never a length discriminator.
- Bits above bit 2 must be zero (reserved); `flags > 0b111` is a malformed shock → revert on decode.
- A component's byte offset = `1 + 3 * (count of present lower-order components)`. `tickDiff` is
  two's-complement in its 3 bytes; decode sign-extends via `@evm_signextend(2, x & 0xffffff)`.

### v6.0 scope — `txlVolmNormRate` only

```
flags = 0b010 = 2
hookData = flags(0x02) || txlVolmNormRate(3 bytes)     // 4 bytes total
decode -> tickDiff = 0, txlVolmNormRate = δ_trans, txlVolmDecay = 0
```

The emitted event therefore **guarantees `tickDiff == 0` and `txlVolmDecay == 0`**.

## 4. Library API (plank)

Free functions (no `::` method syntax in plank — the codebase idiom is `import ...::Shock::*`, calls
like `shock_decode(...)`, exactly as `LDFLib`'s `geometric_leg_weights` returns a struct). Split by
responsibility: the **type + packed codec** (`Shock(R)`, `shock_encode`, `shock_decode`, accessors)
live in `src/models/mev_tax_model_one/libraries/Shock.plk`; the **behavior layer** (`shock_emit` +
the event `topic0`) lives alongside in `ShockLib.plk`, which imports `Shock`.

- **`shock_encode(tick_diff: u256, norm_rate: u256, decay: u256, flags: u256) -> bytes(memory)`**
  Build the packed `hookData` for the components selected by `flags`, canonical order. Each present
  field is masked to 24 bits (`& 0xffffff`, two's-complement for `tick_diff`) and shifted into a single
  big-endian word stored at a 32-byte scratch buffer whose `length` is set to `1 + 3*k` — so reads only
  touch the packed prefix. Values whose bit is unset are never written. Used by the future
  `SELECTOR_NEXT` and by the TDD round-trip.

- **`shock_decode(comptime R: type, buf: bytes(R)) -> Shock(R)`**
  Read the leading `flags` byte via the region-appropriate load (`@mload32` for `memory`,
  `@evm_calldataload` for `calldata`, selected by a `comptime` branch on `R`), validate `flags <= 0b111`
  and `buf.length == 1 + 3*popcount(flags & 0b111)`, and return the view `Shock(R){ data: buf, flags }`.
  No copy, no materialization.

- **Accessors** — `shock_tick_diff / shock_txl_volm_norm_rate / shock_txl_volm_decay(comptime R, s: Shock(R)) -> u256`.
  Each returns `0` if its bit is unset; otherwise reads the 3-byte field at its computed offset
  (`@evm_shr(232, load) & 0xffffff`). `shock_tick_diff` additionally `@evm_signextend(2, …)` for the
  signed `int24`.

- **`shock_emit(comptime R: type, pool: u256, s: Shock(R)) -> void`** (in `ShockLib.plk`)
  Read all three via accessors (zeros for absent), then `@evm_log2(ptr, 96, topic0, pool)` — `pool` is
  the **indexed** topic1 so the off-chain subgraph/GAMS bridge can key by pool.
  `topic0 = 0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64`
  (`keccak256("Shock(address,int24,uint24,uint24)")`). The three non-indexed words are already
  sign-canonicalized by the accessors (per the `VolEventsLib` signed-field rule).

### Round-trip invariant

For any `(tick_diff, norm_rate, decay, flags)` (low 3 bits), decoding `shock_encode(...)` and reading
the accessors yields each selected component (masked to its width; sign-extended for `tick_diff`) and
`0` for each unselected one. This is the primary TDD property.

## 5. Event

```solidity
event Shock(address indexed pool, int24 tickDiff, uint24 txlVolmNormRate, uint24 txlVolmDecay);
// topic0 = 0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64
// topic1 = pool (indexed)
```

`pool` is indexed (topic1); the three typed fields are non-indexed data, emitted **always all three**
(zeros for absent) — this is what "guarantees the others are zero" means for the v6.0
`txlVolmNormRate`-only case. Typing the fields (`int24`/`uint24`) lets the off-chain bridge decode
`tickDiff` sign-aware for free. The off-chain rpc_api consumer is notified of this signature by issue.

## 6. `beforeSwap` integration (the consumer)

The writer's `SELECTOR_BEFORE_SWAP` branch (added under EXEC-03, gated by the `pluginConfig = 0x81`
already set in `SELECTOR_INIT`):

```
beforeSwap(sender, recipient, zeroToOne, amountRequired, limitSqrtPrice, withPaymentInAdvance, data):
    let cd    = bytes(calldata){ ptr: data_ptr, length: data_len }   // zero-copy view over calldata
    let shock = shock_decode(calldata, cd)
    shock_emit(calldata, shock)
    return (SELECTOR_BEFORE_SWAP, feeOverride = 0, pluginFee = 0)     // fee-0 (EXEC-04) via DYNAMIC_FEE
```

The `calldata` region param is what makes this zero-copy: the same `shock_decode`/accessors that the
round-trip TDD exercises over `memory` read straight from the swap's calldata here.

The `beforeSwap` return is `(bytes4 selector, uint24 feeOverride, uint24 pluginFee)`; returning
`feeOverride = 0` under the `DYNAMIC_FEE` flag is how the pool applies a zero fee (verified empirically
in Phase 24, not assumed).

## 7. Testing (TDD, PlankTestBase; differential where apt)

1. **Round-trip** (the core invariant): a plank harness that `shock_encode`s then `shock_decode`s and
   returns the three accessor words, driven for `flags ∈ {0b010 (v6.0), 0b001, 0b100, 0b101, 0b111}`;
   assert selected components survive (masked to width; `tickDiff` sign-extended) and unselected are
   `0`. A Solidity oracle builds/reads the same packed layout (Plank↔Sol differential, mirroring the
   multicall lib), so the packed tag scheme has an independent witness — including a negative `tickDiff`
   to pin sign extension.
2. **Malformed** decode reverts: `flags > 0b111`; `data_len` inconsistent with `flags`.
3. **Event**: decode a v6.0 payload, `shock_emit`, assert the log `(topic0, tickDiff=0, δ_trans, txlVolmDecay=0)`.
4. **`beforeSwap` end-to-end** (Phase 24): a swap carrying `flags(0x02)||δ_trans` hookData → `beforeSwap`
   fires, emits the event, and the swap executes at fee-0 (price moved by the full amount).

## 8. Open / deferred

- **`priceChange` arity** — pinned to a signed `int24 tickDiff` now; the `uint160 sqrtPrice` half of the
  `(p_φ, i)` pair is deferred and folds into `tickDiff`'s bit (a wider field) when price is first sent
  (post-v6.0).
- **`feeOverride = 0` semantics** — that the pool applies it as a genuine 0 fee under `DYNAMIC_FEE` is
  verified in Phase 24, not by source reading (Algebra's pool is assembly-split).
- **Encode home** — for v6.0's "test pre-encodes" design, the *test* (Solidity) produces the swap
  hookData; the plank `encode` is exercised by the round-trip TDD and used for real when
  `SELECTOR_NEXT` lands.

---

*Spec written 2026-08-16 as conversed; feeds a Phase 23 implementation plan (encode↔decode round-trip
first, then event, then `beforeSwap` integration).*
