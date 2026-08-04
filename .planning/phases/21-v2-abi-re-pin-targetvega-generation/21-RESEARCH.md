# Phase 21: V2 ABI Re-Pin & targetVega Generation — Research

**Researched:** 2026-08-01
**Domain:** Haskell EVM ABI client re-pinning (web3-ethereum) + a stochastic draw law for a
liquidity-dimensioned order parameter
**Confidence:** HIGH on the four byte layouts and the code delta (measured against the imported
interface/module/type files and re-verified with `cast`); MEDIUM-HIGH on the `targetVega` draw law
(the band is derived exactly; the *shape* rests on one strong empirical source, not many)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**targetVega generation — structure LOCKED, draw law is a RESEARCH TARGET**
- **The draw law is NOT decided here.** The user's instruction: *"This needs to be
  researched on how empirically and in practice this is chosen."* The researcher MUST
  investigate how vega / liquidity-notional magnitudes are chosen empirically and in
  practice, then RECOMMEND a law with evidence. Candidate laws considered but explicitly
  NOT selected: log-uniform over the band, linear-uniform, fixed constant. Do not default
  to one without the research finding.
  - Local material to mine first (see canonical refs): `notes/UNITS_AND_SCALES.md` §2 —
    the vega axis / dimension decision (ii), and the origin of the "realistic pool
    liquidity 1e18–1e21" claim (§2 headroom note); `../plank/notes/VOLATILITY_INSTRUMENTS.md`;
    `../plank/refs/` (`DemeterfietalVarianceSwaps.pdf`, `greeks/`, `bunni-v2.pdf`).
  - Per the user's global rule, prefer the **arxiv MCP over web search** for academic
    sources.
  - Deliverable: a recommended draw law with its empirical justification, expressed so the
    planner can encode it as a `VegaDraw` constructor with concrete parameters.
- **Type surface (LOCKED):** `StochasticOrderGen` gains `vega_draw :: VegaDraw`, where
  `VegaDraw` is a one-constructor sum type — mirroring `ArrivalProcess` / `ProcessType`,
  the established convention for "one law today, room for another later". The constructor's
  name and fields follow from the research finding.
- **Verification (LOCKED):** belt and braces —
  (a) `cabal test` draws N orders with a **fixed seed** and asserts every drawn
  `targetVega` is within `[1, 2^96−1]` AND within the configured band; and
  (b) the generator **guards at draw time and fails loudly** on an out-of-band value,
  matching `StochasticPriceGen.Simulate`'s domain-guard discipline.

**Pin tests**
- **Location (LOCKED):** extend Phase 20's `offchain/test/Main.hs` — one suite, one
  `cabal test` gate. It already carries the `.plk` signature parser, `keccak256`
  recompute, and a working falsifiability case; a second module would risk two divergent
  parsers.
- **Pin source (LOCKED):** each test **recomputes keccak from the signature string in the
  interface `.plk` file** (satisfying SC-1/SC-3's "DERIVED, never a transcribed literal"
  literally), **then cross-checks agreement with `offchain/rig/rig-pins.json`**. Either
  disagreement — stale pin file, or drifted interface file — is a loud failure.

**Field validation**
- **Keep the shipped `Either String` per-field message pattern.** `pack_vol_order_input`
  extends from three fields to four with the same shape; each field rejects its own
  out-of-range value with an attributable message. This is the pattern that caught the
  v4.0 silent-corruption bug — no new error type, no smart-constructor refactor.
- `targetVega` is now the **unmasked TOP field** (bits 128..223 in the input word),
  inheriting the dirty-bit-rejection role `width` held in V1; bits ≥ 224 must be zero BY
  CONSTRUCTION.

**V1 disposition**
- **Delete the V1 3-arg `create_order` path outright.** `encode_create_order` becomes
  V2-only (`create_order(uint88,uint24,uint16,uint96)` = `0x98d950ec`). V1
  (`0x6501fe94`) is RETIRED-NEVER-LIVE — nothing was ever deployed under it, so there is
  no on-chain history to stay compatible with, and a dead second encoder is precisely the
  rot this phase exists to stop.
- The retired constants (`0x6501fe94`, v1 E1 topic0 `0x6a5dc726…`, the stale
  `0xa8892769…`) remain in `rig-pins.json`'s `retired` block — they are the **subjects**
  of the RPIN-04 falsifiability test, not live values.
- NOTE (from Phase 20's 20-05 summary): `offchain/rig/generate-pins.sh` currently parses
  the stale topic0 out of `src/modules/VolOrderManagerMod.plk` (the superseded duplicate).
  Deleting V1 code from `Encoding.hs`/`Decode.hs` must not break that generator — verify
  `generate-pins.sh` still reproduces `rig-pins.json` byte-identically after the purge.

### Claude's Discretion
- `VegaDraw` constructor naming and field names (once the law is chosen).
- Test organization *within* `offchain/test/Main.hs` (grouping, helper extraction).
- Exact wording of the four field-validation messages.
- How the field-boundary corpus for the round-trip test is constructed (SC-2 requires it
  exhibit at least one order whose input word ≠ its storage word).

### Deferred Ideas (OUT OF SCOPE)
- Running the drivers live end-to-end — Phase 22 (DRIV-01/02), already roadmapped.
- The v6.0 subgraph consuming E1 v2 — queued milestone, not new scope.
- The tracked v4.0 follow-ups (decoder header hardening, shared `MAX_BATCH` constant,
  whole-word storage verification) — recorded in
  `docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md`; touch
  only if the re-pin lands on those exact lines anyway.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RPIN-01 | `encode_create_order` emits V2 4-arg calldata, selector `0x98d950ec`, pin derived from the signature string | §2.1 (layout verified + `cast sig` re-run at research time); §4.1 (exact code delta in `Encoding.hs`); §7.1 (pin test extends the existing `verify_pin`, ground-truth row already present) |
| RPIN-02 | `pack_vol_order_input` packs the V2 batch input word with strict 4-field validation, bits ≥224 zero | §2.2 (layout read from the module's *code*, not its comments — see **F1**); §4.1 (the `in_range`/`Either String` extension); §3.2 (the top-field/interior-field role swap) |
| RPIN-03 | `unpack_vol_order_storage` unpacks the 248-bit V2 storage word | §2.3 (layout read from `VolOrder.plk` shifts/masks); §4.2; §3.3 (why input ≠ storage — the SC-2 discriminator) |
| RPIN-04 | `decode_order_created` re-pins to E1 v2, topic0 pinned from the signature, data = 4 words | §2.4 — this is a **STRUCTURAL** log-shape change (3 topics/5 words → 2 topics/4 words), the largest single delta in the phase; §4.3; §7.2 (falsifiability harness already exists) |
| RPIN-05 | `decode_create_orders_result` verified byte-unchanged against the LIVE V2 module, incl. N=0 at 64 bytes | §5 — live-capture mechanics, the exact `cast` command, the v4.0 golden fixture to diff against, and the **chain-dependence design tension** the planner must resolve |
| RPIN-06 | `VolOrder` record gains `target_vega`; single + batch senders and the mined-order readback carry it end-to-end | §4.4 — the full ripple inventory (7 modules, every construction site); §4.5 (`verify_mined_order` already compares by `Eq VolOrder`, so the new field is compared *for free* — and §4.5 explains why SC-5's "deliberately mismatched value" demo is still required) |
| VEGA-01 | `StochasticOrderGen` draws a `targetVega` per order in raw L units, `[1, 2^96−1]`, realistic 1e18–1e21 | §6 — **the headline finding**: the band is *derived exactly* (§6.2), the *shape* is grounded in Heimbach et al. AFT'22 (§6.3), and the recommendation is **`LogUniform`** with the reasoning, the rejected alternatives, and the concrete parameters (§6.4–§6.6) |
</phase_requirements>

---

## Summary

The four byte layouts are **given** and every one of them was re-verified in this pass against
the *imported source files on this branch* — not against the handoff text. All four agree with
the handoff. `cast sig` / `cast keccak` were re-run at research time and reproduce
`0x98d950ec`, `0x81357911`, the E1 v2 topic0 `0x18bd4d46…` and the retired v1 topic0
`0x6a5dc726…` exactly. **One disagreement was found and it is a comment, not a value** (finding
**F1**, §2.2): `src/modules/pos_spec/VolOrderManagerMod.plk` still carries its *V1* input-word
block comment at lines 177–188, directly above the V2 comment at 221–228 that contradicts it. The
executable code at 229–235 implements V2 and matches the handoff. That file belongs to the plank
track — report, never edit.

The code delta is larger than "add a field". `decode_order_created` is not a re-pin, it is a
**structural log-shape change**: v1 was `@evm_log3` (3 topics `[topic0, owner, blockTimestamp]`,
160 bytes = 5 data words); v2 is `@evm_log2` (2 topics `[topic0, orderId]`, 128 bytes = 4 data
words). `OrderCreatedEvent` *loses* `orderOwner` and `orderCreatedAt` and *gains* `orderId` and
`orderTargetVega`, and `Report.hs::report_order_created` changes with it. Two Phase-20 caveats
resolve cleanly: `generate-pins.sh` **no longer touches `Decode.hs` at all** (re-verified by
running it — the pin file came back byte-identical), and the existing 44-check suite is
**chain-independent** today, which is the one property RPIN-05's live capture threatens.

On the headline question — how `targetVega` magnitudes are chosen in practice — the honest
answer in two halves. **The band is not a guess, and it is not merely stated: it is exactly
derivable**, and this pass derived it. Under dimension decision (ii), `ΔQ_v★ = Σ L(i_K)` is a
Uniswap-`L` total. For the rig's own pool (tickSpacing 10, tick 0, both tokens 18 decimals — read
from `rig-manifest.json`), depositing **one whole token** yields `L = 1.0e18` full-range,
`4.1e19` over 1000 ticks, `6.7e20` over 60 ticks and `4.0e21` over 10 ticks. `[1e18, 1e21]` is
therefore precisely "one whole 18-decimal token, from full-range down to a ~20-tick concentrated
band" — the exact regime this instrument targets. `UNITS_AND_SCALES.md` §2's claim is **GROUNDED,
not corrected**. **The shape, by contrast, is not pinned by any source.** Demeterfi et al. is
about dimension *(i)* (dollars per squared vol point), not `L`, so it cannot pin this. What the
literature *does* pin is the empirical *skew*: Heimbach, Schertenleib & Wattenhofer (AFT'22)
measure real Uniswap v3 LP position sizes and report the **mean is ~10× the median** in both the
USDC-WETH and WBTC-WETH 0.3% pools (~100× in DAI-USDC), with single positions above US$100M in a
US$300M pool. A distribution whose mean and median differ by an order of magnitude is a
log-scale object; a linear-uniform draw on `[1e18, 1e21]` puts ~90% of its mass in the top decade
and would essentially never emit a small position.

**Primary recommendation:** re-pin all four layouts from the *code* of the imported files (not
the comments), treat `decode_order_created` as a rewrite rather than a constant swap, capture
RPIN-05's live bytes with a committed, provenance-bearing capture script rather than by making
`cabal test` chain-dependent, and draw `targetVega` **log-uniformly on `[10^18, 10^21]`** —
`VegaDraw = LogUniform { vega_min, vega_max }` — because that is the scale-invariant
(maximum-entropy) law on a positive quantity whose only established feature is its
order-of-magnitude range, and it is the only one of the three candidates whose shape is
consistent with the measured mean/median ≈ 10 skew of real LP positions.

---

## Standard Stack

No new libraries. This phase is a refactor of an existing, working Haskell client; every
dependency it needs is already in `build-depends`. **Adding a dependency here would be a
finding, not a convenience.**

### Core (already present — versions resolved from `dist-newstyle/cache/plan.json`)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `mwc-random` | **0.15.3.0** | the RNG behind both generators | already drives `StochasticPriceGen`/`StochasticOrderGen`; `uniformR` on `Double` is exactly the primitive a log-uniform draw needs |
| `web3-crypto` | (in test deps) | `Crypto.Ethereum.Utils.keccak256` for pin recomputation | the suite's existing hasher; **never** hand-roll — keccak-256 ≠ SHA3-256 (padding differs) and a wrong one produces 32 plausible bytes |
| `web3-ethereum` / `web3-provider` | (lib deps) | `Change`, `TxReceipt`, `Call`, `runWeb3'` | the shipped RPC surface; unchanged by this phase |
| `aeson` + `containers` + `text` | (lib + test deps) | `rig-pins.json` / `rig-manifest.json` decode | `Rig.Manifest` is the sole loader; §7 |
| `process` | (lib + test deps) | `readProcess "cast" …` in `Encoding.hs`; `cast` cross-check in the test | calldata is built by shelling out to `cast calldata` — an *external encoder*, which is what makes the encoder independently checkable |

### Version verification

`mwc-random 0.15.3.0` and `random 1.2.1.3` were read from the resolved build plan, not from
training data. `cabal build -j all` was run in this pass: **exit 0, zero warnings**.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `mwc-random`'s `create` (fixed default seed) | `initialize :: Vector Word32 -> …` | `initialize` needs the `vector` package, which is **not** in `build-depends`. `create` gives a deterministic default-seeded generator with **zero new dependencies** — verified by compiling and running a probe in this pass (§6.6). Use `create` for the fixed-seed test. |
| shelling out to `cast calldata` | a pure Haskell ABI encoder (`web3-solidity`) | The `cast` dependency is *load-bearing evidence*, not laziness: an external encoder makes `encode_create_order` checkable against something that is not itself. Keep it. |
| extending `offchain/test/Main.hs` | a second test module | LOCKED by CONTEXT, and correct: a second `.plk` signature parser is exactly the divergence this milestone exists to prevent. |

**Installation:** none. `cabal build && cabal test` is the whole toolchain.

---

## 1. Where the sources of truth actually live (verified on this branch)

| Artifact | Path | Verified |
|---|---|---|
| V2 selectors + E1 v2 topic0 | `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | read in full; 39 lines |
| Live V2 module (input word, calldata offsets, return buffer) | `src/modules/pos_spec/VolOrderManagerMod.plk` | read lines 60–270 |
| Storage word layout | `src/types/pos_spec/VolOrder.plk` | read; `pack_vol_order`/`unpack_vol_order` shifts+masks |
| Event emitter (topic count, data length) | `src/lib/events/VolEventsLib.plk:47-54` | read |
| `targetVega` bound | `src/lib/pos_spec/VolOrderValidationLib.plk:49-61`, `src/types/pos_spec/VegaTarget.plk` | read |
| Handoff | `.planning/rpc-api-volorder-v2-HANDOFF.md` | read in full |
| Field→symbol→scale | `notes/DATA_CONTRACT.md` §1, §4 | read in full |
| Units | `notes/UNITS_AND_SCALES.md` §2 | read in full |

**Precedence rule (from the milestone constraints): interface `.plk` > handoff > DATA_CONTRACT >
UNITS_AND_SCALES. Where two disagree, the higher wins and the disagreement is REPORTED.** One
disagreement was found (F1, §2.2) and it does not change any value.

---

## 2. The four V2 byte layouts — verified against the files, not the handoff

### 2.1 Call calldata (RPIN-01)

```
create_order(uint88 strike, uint24 width, uint16 skew, uint96 targetVega)
selector 0x98d950ec
```

- `VolOrderManagerInterface.plk:13-16` declares the signature and the constant.
- `VolOrderManagerMod.plk:74-76` reads **whole 32-byte words, unmasked**, at calldata offsets
  `4 / 36 / 68 / 100`, in the order `(strike, width, skew, targetVega)`.
- Dirty high bits are **rejected by `validate_order_strict`, not truncated**
  (`VolOrderManagerInterface.plk:6-11` states this explicitly).

**Re-verified at research time:**

```
$ cast sig "create_order(uint88,uint24,uint16,uint96)"
0x98d950ec
$ cast sig "create_orders(uint256,uint256[])"
0x81357911
```

`rig-pins.json` already carries `create_order` → `0x98d950ec` with source
`src/interfaces/pos_spec/VolOrderManagerInterface.plk`, and the existing suite's
`sc4_pin_selector_create_order` **already passes**. RPIN-01's pin work is therefore *additive*:
the pin is proven; what is missing is the encoder that uses it.

### 2.2 Batch input word (RPIN-02) — and **FINDING F1**

**The layout, read from the executable code** (`VolOrderManagerMod.plk:229-235`):

```
let word = @evm_calldataload(100 + i * 32);
build_vol_order(
    @evm_shr(16,  word) & 0xFFFFFFFFFFFFFFFFFFFFFF,   -- strike     bits  16..103  (u88, MASKED)
    @evm_shr(104, word) & 0xFFFFFF,                   -- width      bits 104..127  (u24, MASKED)
    word & 0xFFFF,                                    -- skew       bits   0.. 15  (u16, MASKED)
    @evm_shr(128, word)                               -- targetVega bits 128..TOP  (UNMASKED)
)
```

| Field | Bits | Masked on-chain? | Consequence |
|---|---|---|---|
| `skew` | 0..15 | yes | a field sits above it |
| `strike` | 16..103 | yes | a field sits above it |
| `width` | 104..127 | **yes (NEW in V2)** | now INTERIOR; lost its dirty-bit-rejection role |
| `targetVega` | 128..223 | **no** | TOP field; any bit ≥ 224 inflates it past `2^96−1` and `target_vega_fits_packed` rejects it (batch: SKIP, strict: REVERT) |

Matches the handoff item 2 exactly. **Bits ≥ 224 must be zero by construction on the client
side** — the client must not rely on the chain to reject them, because on the batch path
rejection is a silent skip.

> **FINDING F1 — a stale V1 comment survives inside the V2 module, and it contradicts the V2
> comment 40 lines below it.** `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` still reads
> *"INPUT WORD: skew@0..15 | strike@16..103 | width@104..127 | bits >=128 MUST BE ZERO"* and
> *"width IS DELIBERATELY UNMASKED. It is the TOP field"*. Both sentences are **V1** and both are
> **false of this file's own V2 code**: lines 221–228 say the opposite (width interior and masked,
> targetVega the unmasked top field) and lines 229–235 implement the V2 form.
> **The values are unaffected** — the code, the handoff, `DATA_CONTRACT.md` and
> `UNITS_AND_SCALES.md` all agree. This is exactly the rot class this milestone exists to stop,
> one layer up (a comment that cannot be tested). The file is the **plank track's territory**:
> REPORT it to that track, do not edit it. A planner or implementer who reads that block instead
> of the code will ship a V1 packer that passes every off-chain test and is silently skipped
> on-chain.

### 2.3 Storage word (RPIN-03)

248 bits, from `src/types/pos_spec/VolOrder.plk:9-14` (declaration) and `:50-63` (the actual
shifts):

| Field | Bits | Note |
|---|---|---|
| `skew` | 0..15 | u16 |
| `volStrike` | 16..103 | u88, Algebra vol units, raw |
| `tickSpacing` | 104..127 | u24 — **read and DISCARDED** by the client; the module pins `TICK_SPACING = 20` |
| `width` | 128..151 | u24 |
| `targetVega` | 152..247 | u96, `OFF_TARGET_VEGA = 152`, `MASK_U96_VO = 0xFFFFFFFFFFFFFFFFFFFFFFFF` |

Matches the handoff item 3 exactly. The 0-sentinel still holds: a valid order has `strike > 0`
and `skew > 0`, so a validly packed word is never 0 regardless of `targetVega`.

### 2.4 E1 v2 log (RPIN-04) — a **structural** change, not a constant swap

```
VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew, uint96 targetVega)
topic0 0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6
```

Re-verified at research time:

```
$ cast keccak "VolOrderCreated(uint256,uint88,uint24,uint16,uint96)"
0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6      <- V2, LIVE
$ cast keccak "VolOrderCreated(uint256,uint88,uint24,uint16)"
0x6a5dc72627af2833e83e355ac3f2217c1ebee6afe8249d81d035bd1e0f9ee1a5      <- v1, RETIRED-NEVER-LIVE
```

**The emitter, verbatim** (`src/lib/events/VolEventsLib.plk:47-54`):

```
const emit_vol_order_created = fn(order_id, strike, width, skew, target_vega) void {
    let buf = @malloc_uninit(128);
    @mstore32(buf,       strike      & MASK_U88_EV);
    @mstore32(buf +% 32, width       & MASK_U24_EV);
    @mstore32(buf +% 64, skew        & MASK_U16_EV);
    @mstore32(buf +% 96, target_vega & MASK_U96_EV);
    @evm_log2(buf, 128, TOPIC0_VOL_ORDER_CREATED, order_id);
};
```

**`@evm_log2` ⇒ exactly TWO topics. 128 bytes ⇒ exactly FOUR data words.**

| | v1 (what `Decode.hs` implements today) | v2 (what it must implement) |
|---|---|---|
| emitter | `@evm_log3` (`src/modules/VolOrderManagerMod.plk:38`) | `@evm_log2` |
| topics | 3 — `[topic0, owner, blockTimestamp]` | 2 — `[topic0, orderId]` |
| data | 160 bytes = 5 words `[32, 96, volTarget, rangeWidth, skew]` | 128 bytes = 4 words `[strike, width, skew, targetVega]` |
| word indices read | 2, 3, 4 | **0, 1, 2, 3** |

The shipped `decode_order_created` pattern-matches on a **three-element** topic list and reads
data words **2/3/4** (`Decode.hs:49-58`). Against a v2 log it does not decode wrongly — it
returns `Nothing` and the log is silently reported as "unknown". That is the failure mode
`Decode.hs:29-46` already documents for the wrong topic0, and it is why RPIN-04 needs a real
decode test and not just a constant change.

**Consequence for `OrderCreatedEvent`:** `orderOwner` and `orderCreatedAt` **do not exist in
V2** and must be deleted; `orderId` (from topic 1) and `orderTargetVega` (data word 3) are added.
`Report.hs::report_order_created` prints owner + timestamp today and must be rewritten. There is
no way to keep the record shape.

> Note also that the v4.0 verification record's tracked follow-up **#7 is now obsolete**: it says
> *"the deployed pos_spec module emits no logs"* and proposes deleting the decoder as legacy. V2
> added `emit_vol_order_created` on both the strict and batch paths, so the decoder is live again.
> Worth a one-line correction in that doc while Phase 21 is in the file.

### 2.5 Batch return (RPIN-05) — genuinely unchanged, verified at the source

`VolOrderManagerMod.plk:214-216, 249, 265-269`:

```
let out = @malloc_zeroed(64 + 64 * count);
@mstore32(out +% 0,  0x20);      -- outer offset
@mstore32(out +% 32, count);     -- length in ELEMENTS
...
let base = 64 + 64 * i;          -- stride 0x40, positionally aligned
@mstore32(out +% base,        1 or 0);   -- CANONICAL bool
@mstore32(out +% (base + 32), id or 0);
```

`targetVega` never enters the return. Total `64 + 64N`; `N = 0` is exactly 64 bytes. The shipped
`decode_create_orders_result` (`Decode.hs:81-102`) already matches this and already rejects
non-canonical bools. **RPIN-05 is a verification task, not a code task** — unless the live capture
disagrees, which is a FINDING to report (§5).

---

## 3. Architecture Patterns

### 3.1 The module family, unchanged

`Types` / `Encoding` / `Decode` / `Report` / `Rpc` per contract surface. `Either String` for pure
validation; `fail` in `Web3`/`IO` for orchestration (documented characteristic: `fail` escapes
`runWeb3'` as an `IOException`, not as a `Left`). One-constructor sum types for "one law today,
room for another later" — `ArrivalProcess`, `ProcessType`, and now `VegaDraw`.

### 3.2 Pattern: the unmasked top field carries dirty-bit rejection

**What:** in a packed word, exactly one field is left unmasked on-chain — the top one — so that
any bit above the word's declared width inflates that field past its bound and is rejected by
validation, with zero extra arithmetic.

**When to use:** every packed-word client encoder in this repo.

**Why it matters to Phase 21:** the role **moved** from `width` (V1) to `targetVega` (V2). The
client-side consequence is asymmetric and easy to get wrong:

- On the **strict** path a dirty word REVERTS — loud.
- On the **batch** path a dirty word is **SKIPPED** — it returns `(false, 0)` and looks exactly
  like an ordinary business rejection.

So the client must guarantee bits ≥ 224 are zero **by construction**, and `pack_vol_order_input`'s
`targetVega ≤ 2^96−1` check is the only thing standing between a silent skip and a correct batch.
This is the same class of bug as the v1 comment in `Encoding.hs:32-39` describes (a `vol_target`
in `[2^88, 2^104)` OR-ing into `range_width`'s slot with zero on-chain signal).

### 3.3 Pattern: input word ≠ storage word, and SC-2 requires exhibiting it

The two layouts differ in exactly one place — `width` at 104 (input) vs 128 (storage) — because
`build_vol_order` inserts `TICK_SPACING = 20` at bits 104..127 on the way to `pack_vol_order`.
`targetVega` also moves (128 → 152). So **for any order with `width > 0`, input word ≠ storage
word**, which makes SC-2's "exhibit at least one order whose input word ≠ its storage word"
satisfiable by *every* valid order — but the test must assert it, not assume it. A concrete
worked pair the planner can lift:

```
strike = 12345, width = 600, skew = 77, targetVega = 10^18
input word   = 77 | (12345 << 16) | (600 << 104) | (10^18 << 128)
storage word = 77 | (12345 << 16) | ( 20 << 104) | (600 << 128) | (10^18 << 152)
```

### 3.4 Anti-patterns to avoid

- **Reading a layout from a comment.** F1 (§2.2) is a live instance in this very phase's input
  files. Read the shifts and masks.
- **Keeping a V1 encoder "for compatibility".** There is no on-chain history under `0x6501fe94`.
  A second encoder is the rot.
- **Carrying a signature string inside the test.** The suite's own header states the rule: a test
  carrying its own signature proves only that it agrees with itself. The five `ground_truth` rows
  are the deliberate, bounded exception (and they are written *without* the `0x` prefix precisely
  so the purge grep does not match them — §7.3).
- **Treating a `Nothing` from `decode_order_created` as "no event".** A shape mismatch and an
  absent event are indistinguishable in the current return type. RPIN-04's test must assert a
  *positive* decode of a real v2 log, not merely that nothing crashed.

---

## 4. The exact code delta (RPIN-01/02/03/06)

Measured against the files as they stand on `feat/rpc-api` today.

### 4.1 `offchain/lib/VolOrder/Encoding.hs` (89 lines)

| Site | Today | Phase 21 |
|---|---|---|
| `encode_create_order:17-24` | `"create_order(uint88,uint24,uint16)"`, 3 args | 4-arg signature + `show (target_vega order)` |
| `pack_vol_order_input:50-66` | 3 guards, `sk .\|. (target << 16) .\|. (width << 104)` | 4 guards, `sk .\|. (target << 16) .\|. (width << 104) .\|. (vega << 128)`; add `in_range 96 vega` |
| header comment `:26-49` | describes the V1 word and the `width`-unmasked rationale | rewrite: `targetVega` is now the top field; **the skew-65534-vs-65535 seam note at :43-49 stays** (it is still the only client-passing/contract-rejected input, and it is the best-effort test vector) |

`in_range bits value = value > 0 && value < (1 shiftL bits)` extends verbatim — note it already
enforces `> 0`, which matches `vega_target_is_complete` (`self.vega > 0`) and
`target_vega_fits_packed` (`> 0 && ≤ 2^96−1`) exactly. **No new predicate is needed; the shipped
`in_range 96` *is* the contract's bound.**

### 4.2 `offchain/lib/VolOrder/Decode.hs` (119 lines)

| Site | Change |
|---|---|
| `OrderCreatedEvent:21-27` | drop `orderOwner`, `orderCreatedAt`; add `orderId`, `orderTargetVega`; rename `orderVolTarget`→`orderStrike` if desired (discretionary) |
| `decode_order_created:47-59` | match **two** topics; read `orderId` from topic 1; read data words **0..3** |
| imports | `Data.Time.Clock`, `Data.Time.Clock.POSIX`, `Data.ByteArray.HexString(fromBytes)` and `qualified Data.ByteString as BS`'s `drop 12` usage become dead — **`-Wall` will fail the build on unused imports, which is the gate doing its job** |
| `unpack_vol_order_storage:111-119` | add `target_vega = mask_bits 96 (packed shiftR 152)` |
| `decode_create_orders_result:81-102` | **no change** (§2.5) |
| header comments `:44-46`, `:104-110` | both explicitly say "v1 shape, Phase 21's work" — rewrite both |

### 4.3 `offchain/lib/VolOrder/Report.hs` (48 lines)

`report_order_created:41-48` prints `owner` / `timestamp` / `vol_target` / `range_width` / `skew`.
Becomes `order_id` / `strike` / `width` / `skew` / `target_vega`. `report_receipt`'s topic0
threading (`:12-25`) is unchanged.

### 4.4 The `VolOrder` record ripple (RPIN-06)

`VolOrder.Types` gains `target_vega :: Quantity`. Every **construction** site (not just every
consumer) must supply it. Full inventory, grepped:

| File | Site | Nature |
|---|---|---|
| `VolOrder/Types.hs:7-11` | the record | add field |
| `VolOrder/Encoding.hs` | 2 readers (`encode_create_order`, `pack_vol_order_input`) | read the field |
| `VolOrder/Decode.hs:112-117` | `unpack_vol_order_storage` **constructs** a `VolOrder` | must set `target_vega` |
| `VolOrder/Rpc.hs:97` | `verify_mined_order` compares via `Eq` | see §4.5 |
| `app/Sample.hs:25-43` | `sample_order` and `sample_orders` **construct** `VolOrder`s | see §6.7 — this is where the generator/static-data tension lands |
| `StochasticOrderGen/Types.hs:13-17` | `orders :: [VolOrder]` | see §6.7 |
| `offchain/test/Main.hs` | no current `VolOrder` use | new tests will construct them |

### 4.5 `verify_mined_order` — the new field is compared *for free*, and SC-5 still needs its demo

`VolOrder.Rpc.hs:94-104` compares `actual_order == expected_order` using the derived `Eq`. Once
`target_vega` is a field of the record, **a targetVega mismatch fails the readback automatically**
— no code change is required to satisfy RPIN-06's comparison clause.

That is precisely why SC-5's "prove it by feeding a deliberately mismatched value and observing
the failure" is **not** ceremony: the change is invisible in a diff, so the only evidence that
the field is genuinely compared (rather than, say, dropped by a hand-written `Eq` or an
`unpack` that forgets to set it) is an observed RED. Recommended demo shape: unpack a storage
word, perturb only bits 152..247, assert the comparison fails. This can be done as a **pure**
test — no chain needed — which keeps it inside the chain-independent suite.

**Related (deferred, but note the overlap):** tracked follow-up #5 asks for *whole-word* storage
verification including `tickSpacing = 20`. Phase 21's storage round-trip test lands on exactly
those lines. CONTEXT permits touching a deferred item "only if the re-pin lands on those exact
lines anyway" — this one does. Planner's call; it is cheap here and expensive later.

---

## 5. RPIN-05 — capturing a real `(bool,uint256)[]` from the live rig

### 5.1 Rig state, measured now

- **anvil is NOT running** (`pgrep anvil` empty; `cast block-number` errors). The rig must be
  re-stood-up: `bash offchain/rig/deploy-rig.sh` (it owns anvil, kills a stale listener, runs the
  five deploy scripts, rewrites the manifest, and **leaves anvil running**).
- `offchain/rig/rig-manifest.json` is **still on disk** from the 2026-07-31 deploy —
  `VolOrderManagerMod` at `0x5fbd…0aa3`, chainId 31337, pool tickSpacing 10, seed
  `initTs=1700000000 / initTick=0`. A redeploy is deterministic (20-03 MEASURED byte-identical
  manifests across two from-scratch runs, modulo `generatedAt`), so the addresses should
  reproduce — but the plan must not assume it; read them from the manifest.

### 5.2 The capture is an `eth_call`, not a transaction

`create_orders` returns its `(bool,uint256)[]` from a plain `eth_call` — no state change, no gas
management, no receipt polling. That makes the capture cheap and repeatable:

```bash
MGR=$(jq -r .contracts.VolOrderManagerMod offchain/rig/rig-manifest.json)

# N = 0 — must be EXACTLY 64 bytes (2 + 128 hex chars)
cast call "$MGR" $(cast calldata "create_orders(uint256,uint256[])" 0 '[]') \
     --rpc-url http://127.0.0.1:8545

# N >= 1 mixed — one valid tuple and one contract-rejected tuple (skew = 65535)
# input word = skew | strike<<16 | width<<104 | targetVega<<128
```

Expected N=0 bytes (from the committed v4.0 golden, `test/pos_spec/fixtures/vol_order_return_golden.json`,
case `N0_empty`):

```
0x0000…0020   (outer offset 0x20)
  0000…0000   (length 0 ELEMENTS)
```
— 64 bytes total.

### 5.3 The golden fixture to diff against

`test/pos_spec/fixtures/vol_order_return_golden.json` — 5 cases (`N0_empty`, `N1_success`,
`N2_success_then_fail`, `N3_mixed_seeded_C5`, `N3_all_invalid`), bytes generated by
`cast abi-encode` (alloy, cast 1.5.1-stable), i.e. **an encoder outside this repo**.

Two facts the planner must hold together:

1. The fixture's *inputs* are **3-field** (`strikes`/`widths`/`skews`, no targetVega) — it predates
   V2. Its **`expected` return bytes are still valid**, because the return encoding is a function
   of `(success, id)` only and `targetVega` never enters it. Diffing live V2 bytes against these
   `expected` strings is therefore a legitimate cross-version check, and *that* is what makes
   RPIN-05's "verified byte-unchanged" claim meaningful.
2. The fixture's `peer_haskell_bytes` array is **five `PLACEHOLDER -- NOT-PEER-VERIFIED` entries**
   with `_peer_status` recording that this rpc_api track never delivered Haskell-produced bytes.
   Phase 21 is the moment that gap could close — but `test/` is the **Solidity-testing track's
   territory** and this session must not write there. **Recommendation: produce the bytes, record
   them in an `offchain/`-side artifact, and REPORT to that track that the placeholders can now
   be filled.** Do not edit the fixture.

### 5.4 The design tension the planner must resolve: `cabal test` is chain-independent today

**Measured in this pass:** `cabal test` returns **44/44, exit 0, with anvil down.** `sc3_load_succeeds`
reads the manifest *file*; it never pings the chain. So the entire existing gate runs on a machine
with no rig.

RPIN-05 says "verify against the live module, don't assume from the handoff". Two honest ways to
satisfy it:

| Option | Shape | Cost |
|---|---|---|
| **(a) RECOMMENDED — capture script + committed artifact** | `offchain/rig/capture-batch-return.sh` performs the `cast call`s against the live rig and writes `offchain/rig/batch-return-capture.json` carrying, per case: the raw returndata, the manager address, the block number, and the calldata used. `cabal test` then (i) diffs the captured bytes against the v4.0 golden `expected`, (ii) feeds them through `decode_create_orders_result`, (iii) asserts the N=0 case is exactly 64 bytes. | Keeps the suite chain-independent; the capture is auditable and re-runnable; provenance is recorded so a stale capture is visible. Costs one new script + one committed artifact. |
| **(b) live call inside `cabal test`** | matches 20-05's "fail, don't skip" discipline literally | **Regresses** today's chain-independence: every future `cabal test` needs a running rig. Given the whole point of the pin suite is that it is cheap and always-runnable, this is a real loss. |

Option (a) preserves both properties and still satisfies "verify against the live module" — the
bytes genuinely came off the chain, and the artifact says which chain, which address, which block.
Add a freshness assertion (the capture's `generatedFrom` / manager address must match the current
`rig-pins.json` / `rig-manifest.json`) so a stale capture reddens rather than passing quietly.

---

## 6. **VEGA-01 — how `targetVega` magnitudes are chosen, and the recommended draw law**

> This is the section the user asked for by name. It is written to be falsifiable: every number
> below is either derived here (with the derivation shown) or quoted from a named source with the
> quote reproduced.

### 6.0 Source availability — an honest note up front

**The arxiv MCP is not available in this research session.** The prompt states it is, and the
user's global instruction prefers it over web search for academic papers; this agent's toolset
contains no `mcp__arxiv__*` tool. The substitute used is **direct retrieval from arxiv.org**
(`WebFetch`/`curl` on `arxiv.org/abs/…` and `arxiv.org/pdf/…`) — the same corpus, reached
differently — plus targeted web search only to *locate* papers, never to source claims. Every
empirical number in §6.3 was read out of the paper's own PDF text, which was downloaded and
extracted in this pass. **No citation below is second-hand.**

### 6.1 What the *local* material does and does not pin

| Source | What it establishes | What it does NOT establish |
|---|---|---|
| `notes/UNITS_AND_SCALES.md` §2 | dimension decision (ii): `ΔQ_v★` = **raw Uniswap-`L`**, u96 at storage bits 152..247, "realistic pool liquidity 1e18–1e21 — ≥1e7× headroom" | the claim is **stated**, with no derivation shown in the file. §6.2 supplies the derivation. |
| `../plank/notes/VOLATILITY_INSTRUMENTS.md` :428-454 | the sizing identity `L(i_K) = ΔQ_v★·ℓ(ξ★,ι;i_K)`, `Σ L(i_K) = ΔQ_v★` (exact, `Σℓ = 1`); the maturity bijection `t★ = 2·ΔQ_v★/N_σ` | any magnitude at all. Every relation is scale-free. |
| `../plank/refs/DemeterfietalVarianceSwaps.pdf` | variance-swap notional conventions: *"the notional amount can be expressed as $100,000/(one volatility point)²"*, *"N is the notional amount of the swap in dollars per annualized volatility point"* | **nothing about `L`.** These are dimension **(i)** quantities — collateral per vol unit, the *lens readout* that `UNITS_AND_SCALES.md` §2 explicitly says is **never stored**. Using a Demeterfi notional to size `targetVega` would be exactly the unit slip the milestone constraints warn is "invisible on-chain". **This source cannot pin the draw law and must not be cited as if it does.** |
| `../plank/refs/bunni-v2.pdf`, `../plank/refs/greeks/maymin-…pdf` | LDF shape / liquidity Greeks | no position-size magnitudes. Maymin's empirics are about CEV variance elasticity across 90 Bittensor subnets, not LP sizing. |

**Honest conclusion from the local corpus: nothing here pins a draw law.** The band is pinned by
arithmetic (§6.2); the shape has to come from outside (§6.3).

### 6.2 The band `[1e18, 1e21]` is DERIVABLE — and it checks out exactly

Under dimension (ii), `ΔQ_v★ = Σ L(i_K)` is a total Uniswap-`L`. For an in-range concentrated
position at price `P` over `[Pa, Pb]`, the standard v3 relation is `amount1 = L·(√P − √Pa)`.

Instantiate it on **the rig's own pool**, read from `offchain/rig/rig-manifest.json` and
`foundry-scripts/deploy/DeployDynamicFeeHook.s.sol`: `tickSpacing = 10`, `initTick = 0` (so
`P = 1`), and **both tokens are 18 decimals** (`MinimalToken.decimals = 18`). Depositing
**one whole token** (`10^18` wei) of token1 over a symmetric width `w` ticks about tick 0:

| range width `w` (ticks ≡ bps) | `L` for 1 whole token | `L` for 1000 tokens |
|---|---|---|
| full range (±887272) | **1.000e18** | 1.000e21 |
| 100 000 | 1.089e18 | 1.089e21 |
| 20 000 | 2.542e18 | 2.542e21 |
| 4 000 | 1.051e19 | 1.051e22 |
| 1 000 | 4.050e19 | 4.050e22 |
| 200 | 2.005e20 | 2.005e23 |
| 60 | 6.672e20 | 6.672e23 |
| 20 | 2.001e21 | 2.001e24 |
| 10 | 4.001e21 | 4.001e24 |

*(Computed in this pass; `L = amount1 / (1 − 1.0001^(−w/4))` at `P = 1`. Reproducible in three
lines of Python.)*

**Reading the table:** `[1e18, 1e21]` is exactly *"one whole 18-decimal token, from full-range down
to a ~20-tick concentrated band"*. That is the concentrated-liquidity regime this instrument
targets, and it lands on the same order as Heimbach et al.'s measured median position widths
(§6.3: ~4 bps for stable pairs, ~4000 bps for volatile pairs — both inside the table's rows).

`UNITS_AND_SCALES.md` §2's headroom claim also checks: `u96 max = 7.923e28`, so `1e21` leaves
**7.9e7×** headroom — the file says "≥1e7×", which is correct. And `1e18 = 2^59.8`,
`1e21 = 2^69.8`, `2^96−1 = 7.9e28` — the band occupies bit-lengths **60..70** of a 96-bit field.

> **§2's "realistic pool liquidity 1e18–1e21" is GROUNDED, not corrected.** The research target
> asked whether the claim was merely stated; it was stated without a derivation, and the
> derivation now exists and confirms it. Recommend adding the one-line derivation to the units
> table so the next reader does not have to re-do this.

**Two caveats the planner should carry:**
1. `L` is a **per-pool** dimension (the units table says so explicitly). This band is derived for
   an 18/18-decimal pair at price ≈ 1. A pool with a 6-decimal token (USDC) or a price far from 1
   shifts the band. For the rig — the only pool v5.0 drives — the derivation is exact.
2. The module pins `TICK_SPACING = 20` in the stored word while the **rig pool's tickSpacing is
   10**. This does not affect `targetVega` (the stored tickSpacing is read-and-discarded by the
   client), but it is a real inconsistency between the module constant and the deployed pool, and
   it will matter when placement lands. **Report; out of scope here.**

### 6.3 The empirical shape: real LP positions are log-scale and right-skewed

**Source (retrieved and text-extracted in this pass):** Lioba Heimbach, Eric Schertenleib, Roger
Wattenhofer, *"Risks and Returns of Uniswap V3 Liquidity Providers"*, **ACM AFT 2022**,
arXiv:2205.08904 — the canonical empirical study of real Uniswap v3 LP positions
(USDC-WETH 0.3%, WBTC-WETH 0.3%, DAI-USDC 0.01%, whole-pool-lifetime data).

Direct quotes from the paper (Figure 9 and its discussion):

> *"Figure 9: Median (lighter lines) and mean (darker lines) position size over time in three
> Uniswap V3 pools. Observe the **large difference (factor ten) between the median and mean**."*

> *"we observe that the mean is significantly **(around ten times) larger than the median** in both
> pools, indicating a **highly unequal distribution of liquidity provider funds**."*

> *"Until February 2022, the difference between the median and mean liquidity position size is also
> around a factor of ten but then **increases to a factor of 100** … the presence of single
> liquidity positions worth **more than US$ 100'000'000**. There are only around 60 active liquidity
> positions in the pool … while the pool holds around **US$ 300'000'000**."*

And on widths (which is what converts a USD size into an `L`):

> *"for the stable pair … the median position size is tiny with **4bps** … For the two normal pairs,
> the median width of a liquidity position is significantly larger by a **factor of around 1000**."*

**What this establishes, precisely:**

- Position sizes are **right-skewed by an order of magnitude between two central-tendency
  statistics.** For a log-normal, `mean/median = exp(σ²/2)`; `mean/median = 10` ⇒ `σ ≈ 2.15` in
  natural log, i.e. **`σ ≈ 0.93` in decades (log₁₀)**. A ±2σ interval is then ~3.7 decades wide.
  The proposed band is 3 decades. **The band's width is the right order for the measured spread.**
- Position **widths** span ~3 orders of magnitude across pool types (4 bps → ~4000 bps), and by the
  §6.2 table width alone moves `L` by ~2.5 decades for a fixed deposit. So even at *constant* USD
  size, `L` is a multi-decade quantity.
- **What this does NOT establish:** the paper reports median/mean *in USD*, from figures, not a
  fitted parametric family. It does **not** state "position sizes are log-normal with σ = X". The
  log-normal reading of mean/median = 10 is *my* inference, and it is offered as an
  order-of-magnitude sanity check on the band width, not as a fitted law. **Confidence: MEDIUM.**

**Corroborating (weaker, not load-bearing):** Risk, Tung & Wang, *"Dynamics of Liquidity Surfaces
in Uniswap v3"* (arXiv:2509.05013) find the liquidity-surface factor coefficients exhibit
GARCH-type heteroskedasticity and **heavy-tailed innovations** — consistent with, but not a
measurement of, position-size skew. Cited for direction only.

### 6.4 The three candidate laws, judged against that evidence

| Law | Verdict | Reasoning |
|---|---|---|
| **Fixed constant** | **REJECT** | Zero variation. It cannot exercise the u96 field at more than one bit-length, cannot produce the SC-2 field-boundary variety, and cannot surface a magnitude-dependent bug (which is the whole class of bug the milestone exists to catch). It also makes VEGA-01's "asserted over the generator's output" vacuous — one value asserted once. |
| **Linear-uniform on `[1e18, 1e21]`** | **REJECT** | It is *not* a neutral choice; it is a strong and wrong one. 90% of a uniform draw on `[1e18, 1e21]` lies in `[1e20, 1e21]` and **99.9% lies above 1e18**; the "one whole token full-range" end of the band would essentially never be sampled. Concretely: drawn values would sit at bit-length 69–70 almost always, never at 60. That contradicts the measured shape (mean ≈ 10× median means most positions are *small*), and it produces a degenerate packing corpus. |
| **Log-uniform on `[1e18, 1e21]`** | **RECOMMEND** | (i) It is the scale-invariant / maximum-entropy law on a positive quantity whose only established feature is its order-of-magnitude range — i.e. the **least-assuming** choice, and the Jeffreys prior for a scale parameter. (ii) It is the only candidate whose shape is qualitatively consistent with mean/median ≈ 10. (iii) It commits to **no fitted parameter we have not measured** — unlike a log-normal, which would require asserting a `σ` no source gives for *our* pool. (iv) It sweeps bit-lengths 60–70 roughly evenly, which is the packing corpus a u96 field wants. |

> **The honest framing, and the user asked for it:** *the literature does not pin this.* No source
> — local or academic — specifies a sampling distribution for a variance-instrument target vega in
> raw `L` units. What the evidence supports is (a) the band, exactly, and (b) that the quantity is
> log-scale rather than linear-scale. Log-uniform is the **most defensible default** given both,
> and it is defensible *because* it adds nothing beyond them. If a later phase measures the actual
> `L` distribution of the rig's pool, `VegaDraw` gains a second constructor and nothing else
> changes — which is exactly why CONTEXT locked it as a one-constructor sum type.

### 6.5 The recommended `VegaDraw`

```haskell
-- | How a per-order targetVega (DeltaQ_v*, RAW LIQUIDITY units -- the Uniswap L
-- dimension, notes/UNITS_AND_SCALES.md section 2) is drawn.
--
-- One constructor today, room for another later -- same convention as ArrivalProcess
-- and ProcessType.
data VegaDraw
  = LogUniform
      { vega_min :: Integer   -- inclusive lower bound, raw L
      , vega_max :: Integer   -- inclusive upper bound, raw L
      }
  deriving (Eq, Show)
```

**Recommended parameters** (and the reason each is what it is):

| Parameter | Value | Why |
|---|---|---|
| `vega_min` | `10^18` | one whole 18-decimal token, full range, on the rig's own pool (§6.2). Also comfortably `> 0`, satisfying `vega_target_is_complete`. |
| `vega_max` | `10^21` | one whole token concentrated into a ~20-tick band, or ~1000 tokens full range (§6.2). `7.9e7×` below the u96 ceiling, so no draw can approach the packing bound by accident. |

Sample-side default (`Sample.hs`): `LogUniform { vega_min = 10^18, vega_max = 10^21 }` — the same
"safe by default, unlikely to trip a guard on a demo run" convention `sample_price_gen` and
`sample_order_gen` already follow.

### 6.6 Implementation shape, and a precision characteristic that must be recorded

```haskell
draw_target_vega :: GenIO -> VegaDraw -> IO Integer
draw_target_vega gen (LogUniform lo hi) = do
  u <- uniformR (0, 1) gen :: IO Double
  let v = round (fromIntegral lo * (fromIntegral hi / fromIntegral lo) ** u) :: Integer
  if v >= max 1 lo && v <= min hi (2 ^ (96 :: Int) - 1)
    then pure v
    else fail ("targetVega draw out of band: " ++ show v
                ++ " not in [" ++ show lo ++ ", " ++ show hi ++ "]")
```

The trailing guard is CONTEXT's locked requirement (b) — the same **fail-loudly-at-the-step-that-
went-wrong** discipline as `StochasticPriceGen.Simulate.euler_step`'s
`p_next > 0 && not (isNaN …) && not (isInfinite …)` check. It is not dead code: `round` on a
`Double` at the top of the band can land one ulp above `hi`, and a mis-parameterised
`lo`/`hi` (e.g. swapped) must not silently produce nonsense.

**Verified by compiling and running a probe in this pass** (GHC 9.10.3, `mwc-random 0.15.3.0`,
`create` = fixed default seed, 12 draws):

```
1186946348279245568    bits=61      37052572198576381952   bits=66
166952222113890402304  bits=68      2315392034344841216    bits=62
3006703757638344704    bits=62      37999405005355057152   bits=66
121844603607608246272  bits=67      1475274689841291776    bits=61
4798878527208134656    bits=63      546508318830051721216  bits=69
22362718531875102720   bits=65      181491393322483220480  bits=68
```

All 12 in `[1e18, 1e21]`, bit-lengths spread over **61–69** — the sweep a linear-uniform draw
cannot produce.

> **Two implementation facts the planner needs:**
>
> 1. **Use `System.Random.MWC.create`, not `initialize`, for the fixed-seed test.** `initialize`
>    takes a `Vector Word32` and would add **`vector`** to `build-depends`; `create` gives a
>    deterministic default-seeded generator with **zero new dependencies**. Confirmed by compiling
>    the probe above against the project's existing package environment.
> 2. **`Double` has 53 significand bits; the top of the band needs 70.** So a draw near `1e21`
>    carries ~17 forced-zero low bits. This is **fine for VEGA-01** (which is about units and
>    magnitude) but it means the generator's output is a **weak field-boundary corpus** — the low
>    bits of the `targetVega` field are rarely exercised. **Do not let the generator double as
>    RPIN-02/03's packing corpus.** SC-2 already requires a *constructed* field-boundary corpus;
>    keep the two separate and say why in-file. (Corners worth constructing: `1`, `2^96−1`,
>    `2^96` → must be REJECTED, `2^95`, and a value with alternating low bits such as
>    `0xAAAAAAAAAAAAAAAAAAAAAAAA`.)

### 6.7 The generator/static-data tension the planner must resolve

`StochasticOrderGen` today holds a **static `orders :: [VolOrder]`** list plus a Poisson
`arrival_process`; `run_order_gen` draws `N` and takes the first `N` of the list
(`StochasticOrderGen/Rpc.hs:34-40`). Once `VolOrder` carries `target_vega`, "the generator draws a
targetVega per order" collides with "the orders are supplied ready-made".

Three shapes, with the trap named:

| Shape | Verdict |
|---|---|
| Keep `orders :: [VolOrder]` and **overwrite** each `target_vega` with a draw | **Avoid.** `Sample.hs` would have to supply a placeholder `target_vega` that is silently discarded — a value that looks meaningful and is not. That is the same class of defect as a stale address literal. |
| Introduce a partial type (e.g. `OrderShape { vol_target, range_width, skew }`) and have the generator **build** `VolOrder`s by attaching a drawn `target_vega` | **RECOMMENDED.** The types then say what is true: `Θ_ord = {σ²_K, w, s}` is the scale-free shape (VOLATILITY_INSTRUMENTS :399-407) and `ΔQ_v★` *completes* it. Cost: one new small type + `Sample.sample_orders` returns shapes. |
| Keep `orders :: [VolOrder]` with a real `target_vega` and make `vega_draw` optional | **Avoid.** Two sources of truth for one field, and `vega_draw` becomes untested on the default path. |

Either way `StochasticOrderGen` gains `vega_draw :: VegaDraw` (LOCKED) and the draw happens **once
per order at generation time**, not per send.

---

## 7. What Phase 21 inherits from Phase 20, verified

### 7.1 The pin harness is green, falsifiable, and already carries the V2 ground truth

`cabal test` measured in this pass: **44/44, exit 0** — 35 per-pin checks (30 selectors + 5
topic0s) plus 9 named. Crucially, `offchain/test/Main.hs:224-237`'s `ground_truth` table
**already** contains:

```
("selector", "create_order(uint88,uint24,uint16,uint96)", "98d950ec")
("topic0",   "VolOrderCreated(uint256,uint88,uint24,uint16,uint96)",
             "18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6")
```

and `sc4_pin_selector_create_order` / `sc4_pin_topic0_VolOrderCreated` already pass. **RPIN-01's
and RPIN-04's *pin* halves are already satisfied by the Phase-20 suite.** What Phase 21 adds is
the *encoder/decoder that consumes them* plus tests that the consumption is correct.

Reuse `verify_pin` (`Main.hs:194-213`) — it is deliberately factored so the falsifiability case
drives the same function, not a copy.

### 7.2 RPIN-04's falsifiability demo has a working precedent and a preserved subject

`sc4_falsifiable` (`Main.hs:347-363`) already feeds `verify_pin` the retired stale topic0 read from
`retired.topic_order_created_stale` (**never typed**) and requires a mismatch. `sc4_no_retired_value_is_live`
fences the retired block off from the live maps. `rig-pins.json`'s `retired` block is intact:

```json
"create_order_v1": "0x6501fe94",
"topic_vol_order_created_v1": "0x6a5dc726…",
"topic_order_created_stale":  "0xa8892769"
```

SC-3's "shown FALSIFIABLE by observing it go RED when the constant is set to the stale
`0xa8892769…`" therefore has its subject already on disk, already used, already proven to redden.

### 7.3 **The purge grep constrains every new line of test code**

`sc3_literal_purge` (`Main.hs:483-501`) greps `offchain/**/*.{hs,sh}` for
`0x[0-9a-fA-F]{40}\b | 0x[0-9a-fA-F]{64}\b | 0x[0-9a-fA-F]{8}\b` and **fails on any match**.
Consequences for Phase 21, and they are easy to trip:

- Any new expected selector/topic0 in a test must be written **without the `0x` prefix**, exactly
  as `ground_truth` does. The existing table's comment says so verbatim.
- The comment `-- targetVega mask 0xFFFFFFFFFFFFFFFFFFFFFFFF` is **24 hex digits** — safe (the
  pattern matches 8, 40 or 64). But `-- selector 0x98d950ec` in a comment **is 8 hex digits and
  WILL fail the purge.** 20-05 already hit exactly this (its own prescribed `Decode.hs` comment
  contained `0xa8892769` and could not have passed the plan's own criterion — recorded as the
  "seventh self-contradicting criterion").
- **Write no 8/40/64-hex literal anywhere under `offchain/`, in code or in comments.** Name the
  pin instead (`selectors.create_order`, `topics.VolOrderCreated`, `retired.…`).

### 7.4 `generate-pins.sh` — **the 20-05 trap is already defused. VERIFIED, not assumed.**

The CONTEXT caveat asks whether deleting V1 code from `Encoding.hs`/`Decode.hs` breaks pin
regeneration. **It does not.** Measured in this pass:

- `grep -n "offchain/lib\|Encoding.hs\|Decode.hs" offchain/rig/generate-pins.sh` → **one hit, and
  it is a historical comment** (line 40: *"Until plan 20-05 this value was parsed out of
  offchain/lib/VolOrder/Decode.hs…"*). No executable dependency remains.
- The stale topic0 is read from `STALE_TOPIC_SRC="src/modules/VolOrderManagerMod.plk"` (line 51),
  which **still exists** and still carries `const TOPIC_ORDER_CREATED = 0xa8892769;` at line 15.
- `bash offchain/rig/generate-pins.sh` was **run**: exit 0, `30 selectors / 5 topics / 3 retired`,
  and `git diff --exit-code offchain/rig/rig-pins.json` → **clean. Byte-identical.**

**Conclusion: the V1 purge in `Encoding.hs`/`Decode.hs` is safe for pin regeneration.** The
surviving caveat from 20-05 stands and should be carried forward, unchanged: the generator now
depends on the *superseded* `src/modules/VolOrderManagerMod.plk` existing. If the plank track
deletes it, `generate-pins.sh` aborts loudly (`count != 1`) — which is correct behaviour, but the
retired value would then need a new recorded home. Phase 21 should **not** re-home it
pre-emptively; a loud failure is the design.

---

## 8. Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| keccak-256 for a pin | a hash by hand, or `Crypto.Hash.SHA3` | `Crypto.Ethereum.Utils.keccak256` (already imported) | keccak-256 ≠ SHA3-256 (padding differs). A wrong one emits 32 bytes that look exactly like a hash and match nothing. The suite's header says this explicitly. |
| ABI calldata | a Haskell head/tail encoder | `readProcess "cast" ["calldata", sig, args…]` (shipped) | the external encoder is *evidence*, not convenience — it lets the pin test compare two independent implementations |
| a `.plk` signature parser | a second parser | `signatures_in` / `signature_for` / `canonicalise` in `offchain/test/Main.hs` | CONTEXT LOCKED one suite for exactly this reason. Two parsers is the divergence risk. (Note the existing one is *already* a deliberate second implementation of the awk generator's rules — that duplication is the check; a third would not be.) |
| a `Text -> Address` conversion | `fromString` / the `IsString` instance | `Rig.Manifest.parse_address` / `resolve_contract` / `resolve_account` | `Address`'s `IsString` is `either error id . fromHexString` — a malformed entry becomes a bottom thrown wherever the value is first forced, i.e. a quiet, mislocated crash. 20-05 added the total versions precisely for this. |
| a fixed-seed RNG | `initialize` + a `Vector Word32` | `System.Random.MWC.create` | adds no dependency; verified working in this pass |
| the `(bool,uint256)[]` return decode | anything new | the shipped `decode_create_orders_result` | it is correct against V2 (§2.5) and already rejects non-canonical bools |

**Key insight:** almost every "build" instinct in this phase is wrong. Phase 20 deliberately left
behind a parser, a hasher, a loader, a falsifiability harness and a generated pin file. Phase 21's
job is to *consume* them from four more places.

---

## 9. Common Pitfalls

### Pitfall 1 — reading a byte layout from a comment
**What goes wrong:** you implement a V1 packer that passes every off-chain test.
**Why it happens:** `VolOrderManagerMod.plk:177-188` is a stale V1 block comment sitting *inside*
the V2 module, directly above the correct V2 comment (F1, §2.2).
**How to avoid:** derive every layout from the shifts and masks in the executable code, and
cross-check against the handoff + `DATA_CONTRACT.md`. Three independent agreements or it is not
settled.
**Warning signs:** the phrase "bits ≥ 128 must be zero" (V1) instead of "bits ≥ 224 must be zero"
(V2); "width is the top field" instead of "targetVega is the top field".

### Pitfall 2 — a dirty `targetVega` is SILENT on the batch path
**What goes wrong:** an order with `targetVega ≥ 2^96` is skipped, returns `(false, 0)`, and is
indistinguishable from an ordinary business rejection.
**Why it happens:** best-effort semantics; only the strict path reverts.
**How to avoid:** `pack_vol_order_input` must reject it client-side with an attributable message.
`in_range 96` does exactly this.
**Warning signs:** a preview success-pattern with unexplained `False` entries.

### Pitfall 3 — treating RPIN-04 as a constant swap
**What goes wrong:** you change the topic0 and stop. The decoder still matches 3 topics and reads
words 2/3/4, so it returns `Nothing` on every v2 log and reports "unknown log" forever.
**Why it happens:** the requirement's wording ("re-pins to E1 v2, topic0 …") reads like a constant
change; the emitter changed from `@evm_log3`/160-byte to `@evm_log2`/128-byte.
**How to avoid:** rewrite the pattern match and the word indices; assert a **positive** decode of a
real v2 log.
**Warning signs:** `report_log` falling through to the raw-topics branch; `OrderCreatedEvent` still
having `orderOwner`.

### Pitfall 4 — an `0x`-prefixed 8/40/64-hex literal anywhere under `offchain/`
**What goes wrong:** `sc3_literal_purge` reddens, including on a *comment*. 20-05 shipped a plan
whose own prescribed comment could not satisfy its own criterion.
**How to avoid:** §7.3. Write hex without `0x`, or name the pin.

### Pitfall 5 — making `cabal test` chain-dependent
**What goes wrong:** the always-runnable 44-check gate now needs a live anvil, and every future
contributor's first `cabal test` is red for an unrelated reason.
**Why it happens:** RPIN-05 says "verify against the live module" and 20-05's discipline is
"fail, don't skip" — read together they push toward a live call in the suite.
**How to avoid:** §5.4 option (a) — capture once into a provenance-bearing artifact; assert in the
suite.

### Pitfall 6 — letting the generator serve as the packing corpus
**What goes wrong:** the low ~17 bits of `targetVega` are never exercised (§6.6 note 2), so a
low-bit masking bug survives a green suite.
**How to avoid:** SC-2's *constructed* corpus stays separate from VEGA-01's *drawn* values, and the
in-file comment says why.

### Pitfall 7 — `-Wall` on newly-dead imports
**What goes wrong:** deleting `orderOwner`/`orderCreatedAt` orphans `Data.Time.Clock`,
`Data.Time.Clock.POSIX` and part of the `HexString`/`ByteString` usage in `Decode.hs`; zero
warnings is a **hard gate**.
**How to avoid:** expect it, and treat it as the gate working. Run `cabal build -j all` and read
the warning list before declaring a task done. (Baseline measured in this pass: **exit 0, zero
warnings**.)

---

## 10. Code Examples

### 10.1 The V2 input word (client side)
```haskell
-- skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223; bits >= 224 zero.
-- Source: src/modules/pos_spec/VolOrderManagerMod.plk:229-235 (the CODE, not the comment above it)
pack_vol_order_input :: VolOrder -> Either String Integer
pack_vol_order_input order
  | not (in_range 88 target) = Left ("vol_target out of range for its 88-bit field ...")
  | not (in_range 24 width)  = Left ("range_width out of range for its 24-bit field ...")
  | not (in_range 16 sk)     = Left ("skew out of range for its 16-bit field ...")
  | not (in_range 96 vega)   = Left ("target_vega out of range for its 96-bit field ...")
  | otherwise = Right ( sk
                    .|. (target `shiftL` 16)
                    .|. (width  `shiftL` 104)
                    .|. (vega   `shiftL` 128) )
```

### 10.2 The V2 storage unpack
```haskell
-- skew@0 | strike@16 | tickSpacing@104 (read, discarded) | width@128 | targetVega@152..247
-- Source: src/types/pos_spec/VolOrder.plk:50-63 (OFF_TARGET_VEGA = 152, MASK_U96_VO)
unpack_vol_order_storage :: Integer -> VolOrder
unpack_vol_order_storage packed = VolOrder
  { vol_target  = fromInteger (mask_bits 88 (packed `shiftR` 16))
  , range_width = fromInteger (mask_bits 24 (packed `shiftR` 128))
  , skew        = fromInteger (mask_bits 16 packed)
  , target_vega = fromInteger (mask_bits 96 (packed `shiftR` 152))
  }
```

### 10.3 The V2 event decode (2 topics, 4 data words)
```haskell
-- VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew, uint96 targetVega)
-- Source: src/lib/events/VolEventsLib.plk:47-54 -- @evm_log2 => 2 topics; 128 bytes => 4 words
decode_order_created :: Integer -> Change -> Maybe OrderCreatedEvent
decode_order_created expected_topic0 log_entry =
  case changeTopics log_entry of
    [topic0, order_id_topic]
      | hex_to_integer topic0 == expected_topic0 ->
          Just OrderCreatedEvent
            { orderId         = hex_to_integer order_id_topic
            , orderStrike     = data_word 0 (changeData log_entry)
            , orderRangeWidth = data_word 1 (changeData log_entry)
            , orderSkew       = data_word 2 (changeData log_entry)
            , orderTargetVega = data_word 3 (changeData log_entry)
            }
    _ -> Nothing
```

### 10.4 The pin test, reusing the existing checker
```haskell
-- Source: offchain/test/Main.hs:194-213 -- verify_pin is factored so the falsifiability
-- case drives THIS function, never a copy. Both pins already pass in the Phase-20 suite;
-- Phase 21 adds tests that the ENCODER/DECODER consume them correctly.
sc_create_order_selector :: RigPins -> Check
sc_create_order_selector pins = ...  -- verify_pin selector_of "create_order" ...
```

---

## 11. State of the Art

| Old approach | Current approach | When changed | Impact on this phase |
|---|---|---|---|
| `create_order(uint88,uint24,uint16)` = `0x6501fe94` | `create_order(uint88,uint24,uint16,uint96)` = `0x98d950ec` | vol-order-v2 spec, imported at 20-02 | RPIN-01 — delete V1, do not park it |
| E1 `VolOrderCreated(uint256,uint88,uint24,uint16)` topic0 `0x6a5dc726…`, 3 topics + 5 data words | E1 v2 `…,uint96` topic0 `0x18bd4d46…`, **2 topics + 4 data words** | same | RPIN-04 — a rewrite, not a constant swap |
| `Decode.hs` topic0 `0xa8892769…` | (deleted; now a parameter from `rig-pins.json`) | 20-05 | already done; survives only as the RPIN-04 falsifiability subject |
| addresses/selectors as `.hs` literals | `Rig.Manifest` + `rig-pins.json` + `rig-manifest.json` | 20-05 | binds every new line of Phase-21 code (§7.3) |
| `width` unmasked / top field | `targetVega` unmasked / top field; `width` interior + masked | vol-order-v2 | §3.2 — the dirty-bit-rejection role moved |
| `ΔQ_v★` ambiguous between greek and quantity | dimension decision (ii): **raw `L`, the stored quantity**; the collateral-per-vol-unit greek is a lens readout, never stored | 2026-07-30, `UNITS_AND_SCALES.md` §2 | VEGA-01 — and it is why Demeterfi's dollar-per-vol-point notional cannot size this field (§6.1) |

**Deprecated / obsolete:**
- v4.0 verification record follow-up **#7** ("the deployed pos_spec module emits no logs; delete
  the decoder as legacy") — **premise no longer holds**; V2 emits E1 on both paths.
- `VolOrderManagerMod.plk:177-188`'s input-word comment — stale V1 (F1). Plank's file; report only.

---

## 12. Open Questions

1. **How should RPIN-05's live capture be wired without regressing `cabal test`'s chain-independence?**
   - What we know: the suite is 44/44 green with anvil down (measured); the return encoding is
     unchanged at the source; the capture is a plain `eth_call`.
   - What's unclear: whether the planner prefers a committed capture artifact or a live call.
   - **Recommendation:** §5.4 option (a) — a `capture-batch-return.sh` writing a provenance-bearing
     JSON, with a freshness assertion so a stale capture reddens.

2. **`StochasticOrderGen`'s static `orders` list vs a per-order draw.**
   - What we know: the current shape supplies whole `VolOrder`s; VEGA-01 requires the generator to
     draw the fourth field.
   - What's unclear: whether the planner accepts a new small "order shape" type.
   - **Recommendation:** §6.7 — introduce the shape type; the alternative (a discarded placeholder
     `target_vega` in `Sample.hs`) is the stale-literal defect class in a new costume.

3. **Should Phase 21 close the `peer_haskell_bytes` gap in the v4.0 golden fixture?**
   - What we know: the fixture has 5 `NOT-PEER-VERIFIED` placeholders explicitly waiting on *this*
     track; Phase 21 will, for the first time, have Haskell-decoded live bytes.
   - What's unclear: `test/` is the Solidity-testing track's territory.
   - **Recommendation:** produce the bytes in an `offchain/`-side artifact and REPORT; do not edit
     `test/`.

4. **`TICK_SPACING = 20` (module constant) vs the rig pool's `tickSpacing = 10`.**
   - What we know: both values are real and both were read from source/manifest in this pass. The
     client reads-and-discards the stored tickSpacing, so nothing in Phase 21 breaks.
   - What's unclear: which is intended once placement lands.
   - **Recommendation:** REPORT to the plank track. Out of scope. But if the planner adopts
     follow-up #5 (whole-word storage verification, §4.5), the test will assert `tickSpacing == 20`
     against a pool whose spacing is 10 — write that expectation against the **module constant**,
     with a comment naming the discrepancy, so a future change reddens loudly.

5. **The exact per-field validation messages.** Discretionary per CONTEXT. The only constraint that
   matters: each of the four must name **its own** field (that attributability is what caught the
   v4.0 silent-corruption bug).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | **none by design** — a plain `exitcode-stdio-1.0` runner (`offchain/test/Main.hs`, 546 lines, 44 checks). A check is a named `IO (Either String ())`; every check runs, the process exits nonzero if any failed. No test framework is in `build-depends` and none is needed. |
| Config file | `cfmm-replicationPlank-rpc-api.cabal`, `test-suite cfmm-replicationPlank-rpc-api-test` stanza (`hs-source-dirs: offchain/test`, `main-is: Main.hs`) |
| Quick run command | `cabal test` — **measured in this pass: 44/44, exit 0, ~seconds, no chain required** |
| Full suite command | `cabal build -j all && cabal test` (the build is part of the gate: **zero `-Wall` warnings is a hard requirement**) |
| Live-rig commands (not part of `cabal test`) | `bash offchain/rig/deploy-rig.sh` (stands up anvil + 7 contracts), `bash offchain/rig/verify-rig.sh` (liveness), `bash offchain/rig/generate-pins.sh` (idempotent pin regeneration) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| RPIN-01 | selector `0x98d950ec` recomputed from the signature in the `.plk` and matched against `rig-pins.json` | unit (pin) | `cabal test` → `sc4_pin_selector_create_order`, `sc4_cast_agreement`, `sc4_ground_truth_encoder` | ✅ **already passing** (`offchain/test/Main.hs`) |
| RPIN-01 | `encode_create_order` emits 4 args that decode back to `(strike,width,skew,targetVega)` | unit | `cabal test` → new check; leading 4 bytes compared to the *recomputed* keccak, args re-decoded via `cast --abi-decode` or by slicing 32-byte words | ❌ Wave 0 — new check in `offchain/test/Main.hs` |
| RPIN-02 | 4-field input word; each field rejects its own out-of-range value; bits ≥224 zero | unit | `cabal test` → new checks over a **constructed** corner corpus (`1`, `2^96−1`, `2^96` REJECT, `2^95`, alternating-bit) | ❌ Wave 0 |
| RPIN-03 | 248-bit storage round-trip; **≥1 order exhibited with input word ≠ storage word** | unit | `cabal test` → new check; `unpack_vol_order_storage . build_storage_word == id` over the same corpus, plus the §3.3 worked pair | ❌ Wave 0 |
| RPIN-04 | topic0 recomputed from the signature; **retired topic0s REJECTED**; pin shown RED on the stale value | unit (pin + falsifiability) | `cabal test` → `sc4_pin_topic0_VolOrderCreated`, `sc4_falsifiable`, `sc4_no_retired_value_is_live` | ✅ **already passing** — reuse `verify_pin` verbatim |
| RPIN-04 | `decode_order_created` positively decodes a synthetic **v2** `Change` (2 topics, 4 data words) and returns `Nothing` for a v1-shaped one | unit | `cabal test` → new check over a hand-built `Change` value (pure, no chain) | ❌ Wave 0 |
| RPIN-05 | live `(bool,uint256)[]` bytes byte-match the v4.0 golden, incl. N=0 at exactly 64 bytes | integration (captured) | capture: `bash offchain/rig/capture-batch-return.sh` (needs live rig); assert: `cabal test` → new check diffing the capture against `test/pos_spec/fixtures/vol_order_return_golden.json` and feeding it through `decode_create_orders_result` | ❌ Wave 0 — see §5.4; **the capture step is the only chain-dependent work in the phase** |
| RPIN-06 | `target_vega` survives encode → chain → storage readback; a mismatched value FAILS the readback | unit (pure demo) + integration | `cabal test` → new check perturbing bits 152..247 of a storage word and asserting `verify_mined_order`'s comparison fails; live confirmation deferred to Phase 22 (DRIV-02) | ❌ Wave 0 |
| VEGA-01 | fixed-seed draw of N orders; every `targetVega ∈ [1, 2^96−1]` **and** ∈ the configured band | unit (deterministic) | `cabal test` → new check using `System.Random.MWC.create` (default seed, no `vector` dep) | ❌ Wave 0 |
| VEGA-01 | generator **guards at draw time and fails loudly** out of band | unit (negative) | `cabal test` → new check driving `draw_target_vega` with an inverted/degenerate `VegaDraw` and requiring the loud failure | ❌ Wave 0 |
| — (regression) | no address/selector/topic0 literal survives under `offchain/` | unit | `cabal test` → `sc3_literal_purge` | ✅ already passing — **will redden on a careless comment (§7.3)** |
| — (regression) | pin regeneration is unaffected by the V1 purge | script | `bash offchain/rig/generate-pins.sh && git diff --exit-code offchain/rig/rig-pins.json` | ✅ **VERIFIED in this pass: byte-identical** |
| — (regression) | zero `-Wall` warnings | build | `cabal build -j all` | ✅ baseline measured: exit 0, 0 warnings |

### Sampling Rate

- **Per task commit:** `cabal build -j all && cabal test` — full 44+N checks, seconds, no chain.
- **Per wave merge:** the above **plus** `bash offchain/rig/generate-pins.sh && git diff --exit-code offchain/rig/rig-pins.json`.
- **Phase gate:** `bash offchain/rig/deploy-rig.sh` → `bash offchain/rig/verify-rig.sh` →
  `bash offchain/rig/capture-batch-return.sh` → `cabal build -j all && cabal test` green, plus the
  observed-RED demos (RPIN-04's stale-topic0 pin, RPIN-06's perturbed-targetVega readback) recorded
  verbatim before any green is reported.

### Wave 0 Gaps

- [ ] New checks in `offchain/test/Main.hs` — covers RPIN-01 (encoder half), RPIN-02, RPIN-03,
      RPIN-04 (decoder half), RPIN-06, VEGA-01. **No new file**; CONTEXT locks one suite.
- [ ] `offchain/rig/capture-batch-return.sh` + `offchain/rig/batch-return-capture.json` — covers
      RPIN-05. **The only new chain-touching artifact.**
- [ ] Shared constructed field-boundary corpus (a helper inside `Main.hs`) — RPIN-02/03 SC-2, kept
      **separate** from VEGA-01's drawn values (§6.6 note 2).
- [ ] Framework install: **none** — the runner exists and no dependency is added. If a plan
      proposes adding `vector`, `tasty` or `hspec`, that is a deviation to justify, not a default.

---

## Sources

### Primary (HIGH confidence) — read in full in this pass, on this branch

- `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — V2 selectors, E1 v2 topic0 constant
- `src/modules/pos_spec/VolOrderManagerMod.plk:60-270` — calldata offsets, input-word shifts/masks,
  batch guards, return buffer (**and finding F1**)
- `src/types/pos_spec/VolOrder.plk` — `pack_vol_order` / `unpack_vol_order`, `OFF_TARGET_VEGA = 152`
- `src/types/pos_spec/VegaTarget.plk`, `src/lib/pos_spec/VolOrderValidationLib.plk:49-61` —
  `vega_target_is_complete` (`> 0`), `MAX_TARGET_VEGA`, `target_vega_fits_packed`
- `src/lib/events/VolEventsLib.plk:47-54` — `@evm_log2`, 128-byte data buffer
- `src/modules/VolOrderManagerMod.plk:15,38` — the superseded v1 module: `TOPIC_ORDER_CREATED = 0xa8892769`, `@evm_log3`
- `.planning/rpc-api-volorder-v2-HANDOFF.md`, `notes/DATA_CONTRACT.md`, `notes/UNITS_AND_SCALES.md`
- `offchain/lib/VolOrder/{Types,Encoding,Decode,Report,Rpc}.hs`,
  `offchain/lib/StochasticOrderGen/{Types,Simulate,Rpc,Report}.hs`,
  `offchain/lib/StochasticPriceGen/{Types,Simulate}.hs`, `offchain/lib/Rig/Manifest.hs`,
  `offchain/app/{Main,Sample}.hs`, `offchain/test/Main.hs`
- `offchain/rig/{generate-pins.sh,deploy-rig.sh,rig-pins.json,rig-manifest.json}`
- `test/pos_spec/fixtures/vol_order_return_golden.json` (READ ONLY — other track's territory)
- `docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md` §"Tracked follow-ups"

### Commands EXECUTED in this pass (measurements, not claims)

| Command | Result |
|---|---|
| `cast sig "create_order(uint88,uint24,uint16,uint96)"` | `0x98d950ec` |
| `cast sig "create_orders(uint256,uint256[])"` | `0x81357911` |
| `cast keccak "VolOrderCreated(uint256,uint88,uint24,uint16,uint96)"` | `0x18bd4d46…de4e6` |
| `cast keccak "VolOrderCreated(uint256,uint88,uint24,uint16)"` | `0x6a5dc726…ee1a5` (retired) |
| `cabal build -j all` | exit 0, **0 warnings** |
| `cabal test` | **44/44, exit 0 — with anvil DOWN** |
| `bash offchain/rig/generate-pins.sh` + `git diff --exit-code` | exit 0, **byte-identical** |
| `pgrep anvil` / `cast block-number` | anvil **not running** |
| GHC probe: `create` + `uniformR` log-uniform draw × 12 | all in band, bit-lengths 61–69 |
| `L` derivation over 9 range widths at `P=1`, 18/18 decimals | §6.2 table |

### Secondary (MEDIUM-HIGH) — retrieved and text-extracted in this pass

- **Heimbach, Schertenleib & Wattenhofer, "Risks and Returns of Uniswap V3 Liquidity Providers",
  ACM AFT 2022, arXiv:2205.08904.** PDF downloaded and `pdftotext`-extracted; §6.3's quotes are
  verbatim from that text (Figure 9 caption and discussion; Figure 12 discussion). **Load-bearing
  for the draw law's SHAPE.**

### Tertiary (LOW — direction only, not load-bearing)

- Risk, Tung & Wang, "Dynamics of Liquidity Surfaces in Uniswap v3", arXiv:2509.05013 — abstract
  only (heavy-tailed innovations, GARCH-type heteroskedasticity in liquidity-surface factors).
  **Cited for direction; no number in this document depends on it.**
- "Liquidity provider position analysis and pricing in AMM systems", *Digital Finance* (Springer,
  2026) — surfaced by search, abstract-level only (heavy-tailed ETH-USDC returns). **Not used.**

### Explicitly NOT usable, and why (recorded so it is not re-tried)

- `../plank/refs/DemeterfietalVarianceSwaps.pdf` — variance-swap notional in **dollars per squared
  vol point**; dimension **(i)**, the lens readout that is *never stored*. Cannot size a raw-`L`
  `targetVega`. Using it would be the exact unit slip the milestone constraints warn about.
- `../plank/refs/bunni-v2.pdf`, `../plank/refs/greeks/maymin-…pdf` — LDF shape and CEV elasticity;
  no position-size magnitudes.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Four byte layouts | **HIGH** | read from the executable code of the imported files, cross-checked against three documents, `cast` re-run at research time; one comment-level disagreement found and reported (F1) |
| Code delta / ripple inventory | **HIGH** | every affected file read in full; the `-Wall` consequences enumerated from the actual import lists |
| `generate-pins.sh` safety | **HIGH** | the generator was RUN and the pin file diffed — byte-identical. Not inferred. |
| RPIN-05 mechanics | **HIGH** on the byte contract (read at the source); **MEDIUM** on the wiring, since the chain-independence tension (§5.4) is a genuine open design choice for the planner |
| `targetVega` **band** `[1e18, 1e21]` | **HIGH** | derived exactly from the v3 liquidity relation on the rig's own pool parameters (read from the manifest and the deploy script), reproducible in three lines |
| `targetVega` **draw law** (log-uniform) | **MEDIUM-HIGH** | rests on one strong empirical source (Heimbach et al., quotes verbatim) plus a maximum-entropy argument. **No source states a sampling law for this quantity; the recommendation is reasoned, and the reasoning is shown so it can be attacked.** The log-normal σ ≈ 0.93-decades inference from mean/median = 10 is mine, offered as a sanity check on the band width, not as a fitted law. |
| Pitfalls | **HIGH** | five of the seven are instances already recorded as having occurred in this repo (F1, the purge-grep comment, the stale-criterion pattern, the `IsString` bottom, the mask-vs-validate seam) |

**What I might have missed:**
- The E1 v2 log has not been *observed on chain* in this pass (anvil is down). The decode shape is
  derived from the emitter source, which is strong, but a real captured log would be stronger —
  and Phase 21's RPIN-04 test should capture one if the rig is up anyway for RPIN-05.
- No numeric distribution of `L` for the **rig's** pool was measured (the rig has no LP positions;
  it is a bare deploy). The band is derived, not observed. A future phase could measure it.

**Research date:** 2026-08-01
**Valid until:** ~2026-08-31 for the layouts and the code delta (they change only if the plank
track re-imports); ~7 days for the *rig state* facts (anvil up/down, manifest addresses) — re-run
`verify-rig.sh` at plan time rather than trusting §5.1.
