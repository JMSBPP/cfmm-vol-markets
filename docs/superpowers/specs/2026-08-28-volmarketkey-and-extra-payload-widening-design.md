# VolMarketKey(V) and the Extra(T) payload widening — design

**Date:** 2026-08-28
**Status:** DRAFT — pending maintainer approval
**Two-step review:** **WAIVED by the maintainer, 2026-08-28.** The standing rule (CLAUDE.md) requires
Reality Checker plus one specialist in parallel before a spec is committed or treated as executable.
It was offered with two candidate specialists and explicitly declined. Recorded, not inferred — the
findings below carry only this session's verification and one peer session's, with no independent
adversarial pass.
**Phase:** proposed **2.5**, inserted before Phase 3 (`feat/volorder-t-rich`)
**Requirements touched:** VORD-04 (restated), VORD-05 (restated in 3.5)

---

## 1. Problem

`VolOrder(T)` carries an `Extra(T)` descriptor pointing at four 7-bit `optionRatio`s — 28 bits.
Panoptic's `TokenId` also needs a per-leg `tokenType` (PUT/CALL) and a `vegoid`, and this protocol
needs to say which side of a pair is the **asset** and which is the **numeraire**. None of that has
a home today, and there is no type that resolves a pool key to a venue-specific pool identity.

This design adds `VolMarketKey(V)`, widens the `FLAG_PANOPTIC` payload 28 → 40 bits, and retires
`src/types/protocol_integrations/MarketId.plk`.

## 2. The spine — *the caller declares, the contract proves*

Every field this work adds is a **caller-supplied assertion checked against an independently-derived
truth**, never a new degree of freedom:

| Field | Declared in | Proved against |
|---|---|---|
| `tokenType` (per leg) | payload | the `i*` geometric split |
| `vegoid` | payload | `pool_id` bits 40..47 |
| pool address (V3/Algebra) | `key.pool` | the venue registry |
| Panoptic `poolId` | derived candidate | the SFPM's stored value |

This is why the Haskell oracle's signature survives the whole change: nothing new becomes an *input*
to the map, only a *claim about* it. Divergence surfaces as a revert on both sides, which XPORT-02
already distinguishes from transport failure.

## 3. Findings of record

Read from `panoptic-labs/panoptic-v2-core @ 5555b320663385f0ab0c8fa511c74d4f0e34cb80`,
`contracts/`. The in-tree submodule is **uninitialized** and its `test/`-only stale checkout is what
produced finding A's error below; a scratchpad sparse clone was used instead.

### F1 — Panoptic's `asset` bit names the CASH token (CONFIRMED)

`TokenId.sol:112-116` — *"Which token is the asset — can be token0 (return 0) or token1 (return 1)."*
`PanopticMath.getLiquidityChunk` — *"The asset is the 'basis' of the position. **In TradFi, the asset
is always cash** and selling a \$1000 put requires the user to lock \$1000"*, then:

```solidity
uint256 amount = positionSize * tokenId.optionRatio(legIndex);
if (tokenId.asset(legIndex) == 0) return Math.getLiquidityForAmount0(...);
else                              return Math.getLiquidityForAmount1(...);
```

This protocol calls the cash token the **numeraire** (`AlgebraIntegralShocksWriterMod.plk:214`:
`asset=pool.token0, numeraire=pool.token1`) while pinning the bit to 1 and glossing it *"token1 = the
vega numeraire"* (`PanopticTokenIdSetterLib.plk:130`). The two vocabularies use "asset" for opposite
roles. Therefore:

```
panoptic_asset_bit = 1 -% key.asset_index      // a NOT, not a copy
```

**Why it matters:** inverted, this emits a structurally valid tokenId denominated in the wrong token.
`validate()` passes, the position mints, and `position_size_for_target_vega` inverts the wrong
formula. Nothing reverts. It survives a green gate.

### F2 — Panoptic v2 supports Uniswap v3 natively (CORRECTION)

```
SemiFungiblePositionManagerV3 : initializeAMMPool(address t0, address t1, uint24 fee, uint8 vegoid) -> uint64
SemiFungiblePositionManagerV4 : initializeAMMPool(PoolKey calldata key,          uint8 vegoid) -> uint64
```

plus `PanopticFactoryV3.sol` and `PanopticFactoryV4.sol`. An earlier draft of this design asserted
"Panoptic v2 is Uniswap-v4-only" and built a two-codomain taxonomy on it. **That was wrong**, and it
was wrong because it reasoned over a `test/`-only checkout that exercises solely the V4 path. It is
recorded here rather than quietly fixed: this is the same class of error as the `pool_id` retirement
and the 76-bit payload, both of which this project has already had to correct.

V4 **and** V3 reach a Panoptic poolId. Only **Algebra** sits outside Panoptic — there is no
`PanopticFactoryAlgebra`.

SFPM V3 resolves its pool as `FACTORY.getPool(token0, token1, fee)` — the same registry lookup this
design chose over CREATE2 (§5.3), independently.

### F3 — the pool pattern is 40 bits and venue-specific

`PanopticMath.sol:28` is authoritative: `[16-bit tickspacing][8-bit vegoid][40-bit poolPattern]`.
The prose comment in both SFPMs says *"most significant 48 bits"*; the code says 40. Trust the code.

| Venue | pattern, bits 0..39 |
|---|---|
| V4 | `uint40(uint256(PoolId.unwrap(idV4)))` — **low** 40 of the v4 PoolId |
| V3 | `uint40(uint160(univ3pool) >> 120)` — **high** 40 of the pool address |

Both then `+ (uint64(uint8(vegoid)) << 40) + (uint64(uint24(tickSpacing)) << 48)`.

### F4 — the Panoptic poolId is STATEFUL, not a pure function of the key

```solidity
while (s_poolIdToKey[poolId].tickSpacing != 0) {          // V4:364; V3:380 vs s_poolIdToAddress
    poolId = PanopticMath.incrementPoolPattern(poolId);
}
```

Panoptic's rationale: *"There are 1,099,511,627,776 possible pool patterns. A modern GPU can generate
a collision in such a space relatively quickly."* On collision the SFPM increments the pattern until
unique, so the final poolId depends on SFPM storage.

**This falsifies the premise this work opened with** ("PoolKey resolves to PanopticPoolId where it
already has a derivable form"). It resolves to a *candidate*. The authoritative value is
`s_V4toSFPMIdData[idV4][vegoid].poolId()` (V4) / `s_addressToPoolData[univ3pool][vegoid].poolId()` (V3).

SFPM V4:787 enforces `if (poolData.poolId() != tokenId.poolId() || !poolData.initialized()) revert`,
so a stale-pattern tokenId reverts at mint rather than minting against the wrong pool — fail-safe,
but a purely-derived key would emit unmintable tokenIds after any collision.

**Corollary — an independent justification for §4a decision 7.** `pool_id` stays an explicit
parameter of `vol_order_to_panoptic_token_id`. Its previous justification was "the Haskell oracle
keeps it explicit" (argument from authority). F4 supplies a mechanical one: *a value that depends on
SFPM storage cannot be derived inside a pure builder.* Derivation and verification live in the
key/adapter layer; the builder still receives a `u256` it does not question, which also preserves the
differential test's shape — both sides are fed the same value and neither derives it.

### F5 — `vegoid ∈ 1..255`

Both SFPMs: `if (vegoid == 0) revert Errors.InvalidTokenIdParameter(0);`

At 8 bits, values above the max are unrepresentable, so **zero is the only reachable invalid value** —
identically true of `optionRatio` at 7 bits. A tidy, testable guard pair.

## 4. `VolMarketKey(V)`

Verified buildable: Plank's `struct <tag>` accepts arbitrary comptime values — `std/slice.plk` tags
with `struct (R, T, arity.inner)` whose third element is a u256 *value*, and `is_region` is an
ordinary `fn … bool` in `std/regions.plk`, not a language rule. `Extra(T)`'s region restriction is a
library choice in that file, not a constraint on this one.

```plank
const V4 = struct {}; const V3 = struct {}; const Algebra = struct {};

const VolMarketKey = fn (comptime V: type) type {
    if !is_venue(V) { @compile_error("VolMarketKey: V must be V4, V3 or Algebra"); }
    return struct V {
        currency0:    u256,   // sorted: currency0 < currency1
        currency1:    u256,
        asset_index:  u256,   // 0 => currency0 is the ASSET; the other is the numeraire
        fee:          u256,   // V4/V3; unused on Algebra (dynamic fee)
        tick_spacing: u256,   // V4 explicit; V3/Algebra read from the pool
        registry:     u256,   // V4: hooks | V3: univ3 factory | Algebra: algebra factory
        pool:         u256    // V3/Algebra: the asserted pool address. V4: 0
    };
};
```

`VolMarketKey(Algebra)` at a `VolMarketKey(V4)` call site is a **compile error**, not a runtime
revert — the same guarantee `Extra(T)` gives for calldata vs memory.

## 5. Resolution

### 5.1 Panoptic arm (V4 and V3) — derive candidate, verify against SFPM

```
candidate = pattern(key) | (vegoid << 40) | (tick_spacing << 48)
authoritative = STATICCALL sfpm.getPoolId(...)
require(candidate == authoritative)
```

A collision-incremented pool therefore fails **in our builder, with our error, at tokenId-build
time**, instead of inside Panoptic at mint with `InvalidTokenIdParameter`.

### 5.2 V4 pattern subsumes `MarketId.plk`

`market_id_from_pool_key` already mallocs 160 bytes, `mstore32`s
`(currency0, currency1, fee, tick_spacing, hooks)` and returns `@evm_keccak256(buf, 160)` — that **is**
the v4 PoolId the SFPM unwraps. `VolMarketKey(V4)` needs that existing keccak plus a 40-bit
truncation. The migration **subsumes** the function rather than discarding it.

### 5.3 V3 / Algebra — registry-verified address, no CREATE2

| Venue | check |
|---|---|
| V3 | `factory.getPool(c0, c1, fee) == key.pool` |
| Algebra | `factory.poolByPair(c0, c1) == key.pool` |

No `POOL_INIT_CODE_HASH` is pinned anywhere, so the same contract works across forks and chains; a
patched pool contract cannot silently yield a wrong address. **Flagged for explicit maintainer review:
this has consequences past Phase 3 and should not ride as settled.**

### 5.4 Two codomains, and the Algebra arm stops at the address

Ruled 2026-08-28: **all three venues land in 2.5.** F2's reversal means the type has two codomains,
and this is stated rather than left implicit:

| Venue | terminates at | consumed by |
|---|---|---|
| V4 | Panoptic `poolId` (pattern → SFPM-verified) | `vol_order_to_panoptic_token_id` |
| V3 | Panoptic `poolId` (address → pattern → SFPM-verified) | `vol_order_to_panoptic_token_id` |
| Algebra | verified pool **address**, full stop | `DynamicFeeHook`, `RealizedVolatilityMod`, `AlgebraIntegralShocksWriterMod` |

There is no `PanopticFactoryAlgebra`, so the Algebra arm has no Panoptic continuation and must not be
given a synthetic one. `vol_market_key_to_panoptic_pool_id` is typed for `V4` and `V3` only —
`VolMarketKey(Algebra)` at that call site is a **compile error**, which is decision 5's guarantee
doing real work rather than ceremony.

Shipping all three now is also what makes the venue tag honest: a comptime tag with one inhabitant is
a struct with ceremony, and retrofitting the second codomain onto a merged type would repeat the
shape of the 28 → 40 change this phase is already paying for once.

Plank has no general external-call helper — across `std/` at `00c0a1a` only `std/precompile.plk`
makes calls, hardcoded to precompiles `0x01–0x05`. The idiom is: malloc buffer → `mstore32` args →
`@evm_staticcall` → `require(success)` → `mload32`, with the selector from `std/abi.plk`'s
`compute_selector` rather than a pasted constant. A small in-repo `staticcall_word` helper is
warranted since V3 and Algebra are two call sites of one shape.

## 6. The 40-bit `FLAG_PANOPTIC` payload

```
bits  0.. 6   leg0 optionRatio (1..127)      bits 16..23  leg2
bit      7    leg0 tokenType                 bits 24..31  leg3
bits  8..15   leg1                           bits 32..39  vegoid (1..255)
```

Leg *k* at `[8k .. 8k+7]`: `ratio_k = (p >> 8k) & 0x7f`, `tt_k = (p >> (8k+7)) & 1`,
`vegoid = (p >> 32) & 0xff`.

**Leg stride goes 7 → 8 — every offset moves.** This is a change to merged work, not a free re-pick:
`EXTRA_PANOPTIC_BITS = 28` was itself the 76 → 28 correction (PR #65 / `b2868cc`). Three sites move
together, RED-first:

- `EXTRA_PANOPTIC_BITS` — `src/types/Extra.plk:50`
- `require(len == EXTRA_PANOPTIC_BITS)` — `src/types/Extra.plk:65`
- `PANOPTIC_BITS` + its wrong-length revert test — `test/types/pos_spec/VolOrderType.t.sol`

### 6.1 Guards

```
require(vegoid_payload != 0)                              // F5: 0 is the only reachable invalid
require(((pool_id >> 40) & 0xff) == vegoid_payload)       // decision 2
require(ratio_k != 0)  for k in 0..3                      // 7-bit field, same shape
require(tt_k == tt_geometric_k)  for k in 0..3            // (0,0,1,1) from the i* split
```

The `!= 0` check is **not redundant** with the equality: `require(a == b)` passes when both are zero.

### 6.2 `tickSpacing` has two sources and must be reconciled

Surfaced in spec self-review. `tickSpacing` reaches the tokenId **twice**:

- the builder writes `vo.rangeWidth.tickSpacing` into tokenId bits 48..63 via `panoptic_add_tick_spacing`;
- the poolId candidate (§5.1) puts `tick_spacing << 48` into the same bits.

Two producers, one datum — the shape §3's spine exists to forbid. It gets the same treatment:

```
require(vo.rangeWidth.tickSpacing == key.tick_spacing)
```

and on V3/Algebra, `key.tick_spacing` is itself verified against the pool
(`IUniswapV3Pool(pool).tickSpacing()`), which is what SFPM V3 reads when it builds its own poolId.
Unreconciled, a VolOrder whose `tickSpacing` disagrees with its pool's yields a tokenId whose
`poolId` field and whose `tickSpacing` field describe different pools — and F4's SFPM check would
reject it at mint with an error pointing at Panoptic rather than at the disagreement.

## 7. The `asset` bit — exactly one writer

`asset` is key-driven on **both** branches: `panoptic_add_asset(tid, 1 -% key.asset_index, leg)`.

`panoptic_add_asset` is **additive** (`tid +% @evm_shl(64 +% leg*48, v & 1)`), and
`vol_order_to_mint` already adds `asset = 1` on all four legs
(`PanopticTokenIdSetterLib.plk:155-158`). If the Layer-1 map sets asset, **those four adds must be
deleted in the same commit** — a surviving second add carries out of bit `64+48k` into `64+48k+1`,
which is `optionRatio`'s LSB. Silent wrong answer, not a revert.

**Detection asymmetry that makes this need its own test:** the golden vectors call
`tokenIdFromVolOrder` (Layer 1 only), so they would not catch a double-add. Only the mint path's
single `_optionRatio` assert would.

**Constraint:** *asset is written in exactly one place*, pinned by a dedicated test.

### 7.1 The Phase-2 pin is RENAMED, not retired — CORRECTED 2026-08-28

> **An earlier version of this section was titled "The Phase-2 pin is retired deliberately" and
> claimed the pin "goes RED the moment Layer 1 sets asset."** That premise was **wrong**. It is
> corrected here rather than swapped out, so the same treatment the roadmap and `03-CONTEXT.md`
> received applies to this document too and none of the three pretends the belief was never held.
> Found by a peer session measuring the signature-change blast radius rather than reasoning about it.

`test__unit__phase2MapStillHardcodesRatioOneAndNoAsset` (`VolOrderType.t.sol`) asserts
`optionRatio == 1` and `asset == 0` on all four legs — and it calls `tokenIdWithNoneExtra`, the
**no-payload path**. Phase 3 leaves that path alone by design: its criteria 3 and 4 **require**
`optionRatio == 1` and `asset == 0` to stay true there. The harnesses behind the pin and the floor
keep their ABIs and pass a literal `0` for the new asset-bit parameter, so neither output moves.

**The assertions stay byte-identical. What became false is the NAME.**
`…MapStillHardcodes…` implies *not yet* — a temporary state awaiting correction. After Phase 3 it is
the permanent, intended behaviour of the no-payload path. So it is renamed, not retired.

**The requirement is unchanged.** §7's demand that the pin be handled as a *"traceable, argued change
with the reason recorded"* survives intact: a rename is both traceable and argued. Only the **reason**
this section gave for it was wrong. A reader meeting a correction usually assumes the requirement
moved too; here it did not.

Silently deleting the assertion to get green remains the failure the criterion was written to catch.

### 7.2 Why the 10/10 floor is not breached

`test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` was audited assertion-by-assertion. All
27 asserts target decoded fields — `_optionRatio` (+1..+7), `_isLong` (+8), `_tokenType` (+9),
`_legStrike` (+12), `_legWidth` (+36), `_tickSpacing` (@48) — plus bucket bounds and revert
behaviour. There is **no whole-word `assertEq(tid, …)` and no `_asset` decoder**. The asset bit lives
at leg offset **+0**, which is outside both `OPTION_RATIO_MASK` (per-leg bits {1..7}) and
`CHUNK_MASK` ({9, 12..47}). The floor survives untouched, with no edits to that file.

## 8. `MarketId.plk` migration

`VolMarketKey` **replaces** `src/types/protocol_integrations/MarketId.plk` entirely. Full consumer
census (verified independently by two sessions):

| File | refs |
|---|---|
| `src/types/protocol_integrations/MarketId.plk` | 4 |
| `test/protocol_integrations/MarketId.t.sol` | 3 |
| `test/protocol_integrations/MarketIdHarness.plk` | 3 |
| `test/protocol_integrations/MarketStateSocket.t.sol` | 1 — a **comment** at line 22 |

Three real files plus one comment. Nothing outside `src/types/` and `test/` touches it.

## 9. Phase structure

| Phase | Scope |
|---|---|
| **2.5** | `VolMarketKey(V)`, the three resolutions, SFPM verification, payload 28 → 40, the guard set, the asset single-writer constraint, `MarketId.plk` retirement. VORD-04 restated to 40 bits. |
| **3** | The `FLAG_PANOPTIC` dereference (unchanged goal; criteria restated by the Phase-3 owner against the merged payload width). Currently **paused** — no directory, no CONTEXT.md, no plans, so 2.5 unpicks nothing. |
| **3.5** | `asset == 0` sizing inversion: `getLiquidityForAmount0` branch in `position_size_for_target_vega`, `induced_leg_liquidities`, `average_density_chunks`; new golden vectors; VORD-05 restated. |

### 9.1 The 3.5 arithmetic, and its hazard

Today (`asset == 1`): `ps = mulDiv(target, Q96, S)`, `S = Σ mulDiv(Q96, Q96, dsqrt_k)`.

For `asset == 0`, `getLiquidityForAmount0` gives `L_k = ps · (√hi_k·√lo_k / Q96) / dsqrt_k`, so the
same-shaped inversion is `ps = mulDiv(target, Q96, S0)` with

```
S0 = Σ mulDiv(mulDiv(√hi_k, √lo_k, Q96), Q96, dsqrt_k)
```

#### Overflow — BOUNDED, no guard needed

An earlier draft claimed the outer `mulDiv` could overflow `u256` for narrow legs. **It cannot.** The
`Q96`s cancel: `term_k` is algebraically `√hi·√lo / dsqrt_k`, and the 2²²⁴ intermediate never survives
into the result. Since `dsqrt` scales *with* `√` (`dsqrt ≈ √·ε·n`, `ε = ln(1.0001)/2 ≈ 2⁻¹⁴·²⁹`):

```
term_k  ≈  √/(ε·n)  ≤  MAX_SQRT_RATIO/ε  =  2¹⁶⁰ · 2¹⁴·²⁹  =  2¹⁷⁴·³
```

Narrow legs do not help — shrinking `n` shrinks `dsqrt` proportionally, and `n ≥ 1` caps it. `S0` over
four legs is ~2¹⁷⁶, leaving **~80 bits of headroom** against the `u256` cap. Recorded as a closed form
rather than a measured constant so it stays checkable.

#### Underflow — REAL, and it is the silent one

`mulDiv96(a, b) = floor(a·b / 2⁹⁶)` is a **floored intermediate**, and Panoptic's own
`Math.getLiquidityForAmount0` passes it as the numerator multiplicand:

```solidity
uint256 liquidity = mulDiv(amount0, mulDiv96(highPriceX96, lowPriceX96), highPriceX96 - lowPriceX96);
```

At the bottom of the range `√ ≈ 2³²` (`Constants.MIN_POOL_SQRT_RATIO = 4295128739`), so
`√hi·√lo ≈ 2⁶⁴ ≪ 2⁹⁶` and the inner term **floors to zero**. The zero band runs from
`MIN_POOL_TICK = -887272` up to roughly tick −665455 — about **25% of the negative range**.

Two consequences, neither loud:

| Case | Effect |
|---|---|
| All four legs in the band | `S0 == 0` → `ps = mulDiv(target, Q96, 0)` — **division by zero** |
| Some legs in the band | Those contribute 0 → `S0` silently too small → `positionSize` too **large** |

The second is the dangerous one: no revert, a plausible number, an over-sized position. It is the
mirror image of the asset-double-add trap in §7 — same silent-wrong-answer shape, different
arithmetic.

**And Panoptic degenerates identically.** `getLiquidityForAmount0` returns liquidity 0 for those legs
regardless of how they were sized, so this is a genuine domain restriction on `asset == 0` positions,
not merely a numerical artifact of the inversion.

**Guard (3.5):** `require(inner_k != 0)` per leg — equivalently `√hi_k·√lo_k >= Q96`. The tick
boundary is recorded as a *derived* constant with its derivation, never a pasted `-665455`, since it
moves if `Q96` or the sqrt encoding ever does.

**2.5 is not blocked by this.** `getLiquidityForAmount1` is `mulDiv(amount1, FP96, hi - lo)` — no
inner product, no underflow. Today's `asset == 1` path is unaffected; the hazard is specific to the
`asset == 0` branch and lands entirely in 3.5, which is why the sizing inversion was split out rather
than riding along.

## 10. Test plan — RED first

Per project rule, every new type or behaviour gets a harness + test exercising **every branch**
before implementation, and the first push is red on purpose. Plank only type-checks a comptime branch
something instantiates, so an un-instantiated branch is text the compiler has never seen — each of
`VolMarketKey(V4)`, `(V3)`, `(Algebra)` must be instantiated.

1. `VolMarketKey(V)` constructed for all three venues, each **reachable from `run{}`**. Plank only
   type-checks an instantiated *and reachable* comptime branch — an unreferenced fixture is text the
   compiler never sees, which is how a Phase 2 negative test was caught passing vacuously.
2. A cross-venue call site fails to **compile**, via the established `vm.tryFfi` harness
   (`test/types/pos_spec/VolOrderType.t.sol:167` `_tryBuild` + `fixtures/plank-negative/`;
   `foundry.toml:7` sets `ffi = true`). **The assertion must match the error TEXT, not just the exit
   code.** `test__unit__nonRegionTagDoesNotCompile` is the pattern to copy —
   `assertTrue(_contains(r.stderr, "Extra: T must be a region"), "wrong failure: not Extra's guard")`
   — because a fixture with a typo also fails to compile, and an exit-code-only assertion would pass
   while proving nothing. (`test__unit__extraFieldsNeedUnwrap`, two lines below it, omits the stderr
   match and is the weaker form; do not copy that one.) `VolMarketKey` therefore needs a **named,
   distinctive** compile error for the cross-venue case, so there is something specific to match on.
3. `panoptic_asset_bit == 1 -% asset_index` for both values of `asset_index`.
4. Payload round-trip at 40 bits, all four legs, ratio and tokenType independently recovered.
5. `extra_decode` accepts 40, **rejects 28** (the inverse of today's test).
6. Each guard reverts: `vegoid == 0`; `vegoid_payload != pool_id[40..47]`; `ratio_k == 0`;
   `tt_k != tt_geometric_k`; `vo.rangeWidth.tickSpacing != key.tick_spacing` (§6.2).
   Including the pair that a naive equality check would let through: `vegoid_payload == 0` **and**
   `pool_id[40..47] == 0`, which satisfies the equality and must still revert.
7. SFPM verification: candidate matching passes; a mismatched (collision-incremented) poolId reverts.
8. V3 pattern is `>> 120`, V4 pattern is the low 40 — asserted separately, not assumed identical.
9. **Asset single-writer**: a double-add is detectable and pinned.
10. `VolOrderToPanopticTokenId.t.sol` still 10/10 with **no edits to that file**.

## 10a. The 2.5 / Phase 3 seam — DATA vs BUILDER

Ruled 2026-08-28 after a scope-collision audit found 2.5 and Phase 3 both claiming the Phase-2 pin
and the asset write. **The cut is at the function boundary:**

| | owns |
|---|---|
| **2.5** | `VolMarketKey(V)` incl. the SFPM-verified `poolId` and `asset_index`; the 40-bit payload **format**; every guard decidable from *the key and the descriptor alone* |
| **Phase 3** | **every edit to `vol_order_to_panoptic_token_id`** — the dereference, the per-leg writes, the asset write, the cross-checks needing a `VolOrder`, and the Phase-2 pin, exclusively |

Each phase is then testable without the other's code, and neither session edits a function the other
owns.

**The deciding property is a `VolOrder` dependency, not "touches the builder".** Applying it:

- `panoptic_asset_bit == 1 -% asset_index` (§3 F1) is a **pure function of the key** — it stays in 2.5
  and is tested there for both values. This is deliberate: F1 is the single `NOT` with the worst
  failure mode in the design, and 2.5 is where criterion 9's independent check should reach it.
- `vegoid_payload` vs `pool_id[40..47]` (§6.1) **stays in 2.5.** Both operands are 2.5-owned — `pool_id`
  is `VolMarketKey`'s verified output, the payload is `Extra(T)`'s format — and `Extra(T)` is
  independent of `VolOrder`. It is exposed as a standalone `(pool_id, payload)` reconciliation. This
  keeps the **both-zero** case (§6.1: equality alone passes when both sides are zero) in the phase
  that found it.
- `tt_k` vs the geometric split, and `vo.rangeWidth.tickSpacing` vs `key.tick_spacing` (**§6.2**),
  both need a `VolOrder` and therefore **cross to Phase 3**. §6.2 is flagged explicitly because it
  was a self-review catch that exists only because this spec was written — nothing in Phase 3's
  current text would reproduce it, and findings evaporate at boundaries.
- §7's asset single-writer commit lands in **Phase 3**, because that is where the Layer-1 write is
  added and the two edits must be atomic.

**VORD-08's ownership was a coverage question, not a wording one, and is RESOLVED** (`4e4f7cd`). A
requirement owned by 2.5 but satisfiable only by Phase 3 would close either as Pending with nothing
to point at, or Done on another phase's evidence. So:

- **VORD-08 moved to Phase 3 whole**, restated with the atomicity as the requirement *text* —
  *"the removal of `vol_order_to_mint`'s four `panoptic_add_asset` calls is ATOMIC with the addition
  of the Layer-1 write — one commit, not two."* The atomicity **is** the requirement, and it is the
  first thing lost at a handoff, which is why it is not left to the plan.
- **KEY-06 is new and belongs to 2.5**, covering what this phase actually ships: the key derives
  `panoptic_asset_bit == 1 -% asset_index` as a standalone function, tested for both values, with the
  failure mode in the requirement text (a valid position on the **wrong side of the pair**).

Final allocation — 2.5: `KEY-01..06`, `VORD-07`. Phase 3: `VORD-04`, `VORD-05`, `VORD-08`. Nothing is
claimed twice, and every requirement is demonstrable by its owning phase.

A second property of this seam worth keeping: it puts F1's verification in 2.5 and §9.1's in 3.5, so
criterion 9's two highest-risk findings are checked in different phases, and neither is checked by
the phase that would most want it to pass.

## 11. Open risks

1. **Decision 6 (registry over CREATE2)** has consequences past Phase 3 — explicit maintainer review.
2. **Both submodule checkouts are broken LOCALLY ONLY — the evidence base IS reproducible in CI.**
   `lib/panoptic-v2-core` holds a stale partial checkout (6 test files) that blocks
   `git submodule update --init`, so F1–F5 were read from a scratchpad clone of the pinned SHA;
   `lib/plank-monorepo`'s working dir is empty (objects intact), so std was read via
   `git -C lib/plank-monorepo cat-file -p 00c0a1a:<path>` and `make plank-toolchain` cannot run here.
   **Neither limits the gate.** `.github/workflows/develop-gate.yml:118-127` runs
   `git submodule update --init lib/panoptic-v2-core`, then `--init --recursive -- lib/`, then
   `make plank-toolchain` — so `contracts/` and the Plank compiler are both present in CI and every
   finding above is re-checkable there. This is a local developer-ergonomics problem, not a
   validation gap; cleaning the stale checkout is separate work.
4. **The `asset == 0` underflow** (§9.1) is a 3.5 BLOCKER: over ~25% of the tick range the inner
   `mulDiv96` floors to zero, producing either a division by zero or a silently over-sized position.
   The overflow originally feared here does not exist (bounded, ~80 bits of headroom). 2.5 is not
   affected — `getLiquidityForAmount1` has no inner product.
5. The Haskell oracle sets `asset = 1` unconditionally inside `volOrderToTokenId`. Key-driven asset
   on both branches **shrinks** the gap Phase 7 must reconcile, but a residual divergence remains for
   `asset_index == 1`, which the Haskell cannot currently express.

---

## Provenance

Findings F1–F5 read from `panoptic-labs/panoptic-v2-core @ 5555b32`, `contracts/`, with file and line
citations above so any reader can re-check them against the quotes rather than trusting "confirmed".
The Plank capability result (§4) was read from `lib/plank-monorepo @ 00c0a1a` via the object store.
Finding A's refutation and the `vegoid == 0` guard hole were surfaced in review with a peer session,
as was §9.1's correction — the overflow bound and the underflow band were derived there from the
standard Uniswap form and are re-verified above against Panoptic's actual `Math.getLiquidityForAmount0`
and `mulDiv96`.

**The empirical case for in-phase verification.** Phase 2.5's criterion 9 requires F1 and §9.1 to be
independently verified *inside* the phase, by something other than the two sessions that produced
them. The roadmap argues that from risk. The stronger argument is the track record: across four
consecutive exchanges between the two sessions that wrote this spec, **every one was a correction,
and they alternated** —

| # | Claim | Corrected by |
|---|---|---|
| 1 | Phase-3 criterion 3 is breached by key-driven asset | this session, via an assertion census |
| 2 | The `asset == 0` hazard is an overflow needing a guard | peer — it is bounded; the real hazard is an *underflow* |
| 3 | The phase's evidence base is not reproducible in CI | this session — the gate inits the submodule explicitly |
| 4 | Criterion 2 is satisfied by a non-zero exit code | this session — a typo also fails to compile |

Two corrections each way, in one afternoon, on a spec neither session could build locally. **None was
caught by its author.** Two independent sessions producing that rate is a property of the setup — see
risk 2: neither could compile, so every structural claim was inference until a source read or the gate
confirmed it — not a coincidence, and the review waiver removes the pass that would ordinarily catch
the residue.

**Decision provenance.** Eight of the nine decisions were given by the maintainer directly. One —
*asset key-driven on both branches*, with its two conditions — reached this session only as a peer
relay, and the peer has confirmed the relay was **not verbatim**: the maintainer selected an option
whose supporting prose the peer had authored. The choice and the two conditions are the maintainer's;
the argument for them is not. The same applies to the Algebra ruling, which this session additionally
holds directly. Recorded as asymmetric rather than smoothed over; the cheapest fix is one line of
maintainer confirmation at spec review.
