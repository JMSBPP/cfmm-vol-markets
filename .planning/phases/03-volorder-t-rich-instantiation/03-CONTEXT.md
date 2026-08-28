# Phase 3: VolOrder(T) Rich Instantiation - Context

**Gathered:** 2026-08-28
**Status:** Ready for planning — but see the gate below

<domain>
## Phase Boundary

The `FLAG_PANOPTIC` branch of `vol_order_to_panoptic_token_id`: dereference `Extra(T)`'s offset into
region `T`, read the 40-bit payload word, write per-leg `optionRatio` and `tokenType`, set the `asset`
bit, and PROVE every redundant field against a value the builder derives independently.

Requirements: **VORD-04, VORD-05, VORD-08**.

Phase 2.5 delivers the key and the payload FORMAT; this phase consumes them. Under the data/builder
seam, **every edit to `vol_order_to_panoptic_token_id` is this phase's** — the dereference, the
per-leg writes, the asset write and its atomic single-writer commit, the two cross-checks that need a
`VolOrder`, and the Phase-2 pin, exclusively. The `asset == 0` sizing inversion is Phase 3.5; the
three missing Haskell guards are Phase 8.

</domain>

<blocking_gate>
## GATE — read before planning

**Phase 2.5 must MERGE before this phase is planned.** At the time of this discussion PR
[#69](https://github.com/JMSBPP/cfmm-vol-markets/pull/69) was open and `develop-gate` GREEN (run
`33212424542`, `event=pull_request`, `gate` SUCCESS, `mergeStateStatus: CLEAN`) but **not merged**.

Consequences for whoever plans this phase:

1. **The ROADMAP's Phase 3 criteria on `develop` are STALE.** They still describe a 28-bit payload
   and four `optionRatio`s. They are restated against the merged payload width as the first act of
   planning — the instruction is in `STATE.md`'s `stopped_at`.
2. **This document was written against the 2.5 BRANCH, not the merge.** Every signature in
   `<code_context>` was read from `origin/feat/volmarketkey` and verified, but if review changed
   anything before merge, re-verify before planning. The payload width is expected to be 40; take it
   from the merge commit, not from here.
3. This phase runs **INLINE**, in the current tree. 2.5's worktree was a phase-scoped exception (see
   `AGENTS.md`); it does not extend here.

</blocking_gate>

<decisions>
## Implementation Decisions

### What drives correctness — the golden test

- **The DRIVER is a differential against Panoptic's own `TokenId` library.** Build the expected
  tokenId with Panoptic's fluent encoder and `assertEq` it against the Plank builder's output. This
  is a true differential: independent arithmetic on both sides, over the whole fuzzed corpus.
- **Not Panoptic's test contract.** Inheriting `TokenIdTest` would re-run *their* tests against
  *their* `TokenIdHarness` and say nothing about our builder. It is their LIBRARY that is the oracle,
  not their tests.
- **A literal hardcoded tokenId is SUPPORTING evidence, not the driver.** One fully-specified anchor
  with its complete expected 256-bit word, so a catastrophic failure is legible at a glance. It
  covers one input; the differential covers the corpus.
- **Rationale for not using field decoders as the driver:** a decoder written as
  `(tid >> (64 + 48*leg + 1)) & 0x7f` is *the same bit arithmetic the implementation uses*. If the
  offset is wrong, test and implementation are wrong together and both go green. Field decoders stay
  as readable per-field assertions; they are not what proves the phase.
- **Use the REAL `validate()`**, not a hand-port, in this phase's new tests.

### The Panoptic oracle — already reachable, already precedented

- `@types/=lib/panoptic-v2-core/contracts/types/` is in `remappings.txt:10`, and
  `test/protocol_integrations/DynamicFeeHookE2E.t.sol:17` **already** does
  `import {TokenId} from "@types/TokenId.sol"`. The library compiles in our suite in CI today.
- The fluent builder is used at `DynamicFeeHookE2E.t.sol:179`:
  `TokenId.wrap(0).addPoolId(id).addLeg(0, 1, 0, 0, 0, 0, STRIKE, WIDTH)` — i.e.
  `addLeg(legIndex, optionRatio, asset, tokenType, isLong, riskPartner, strike, width)`.
  Also available: `addTickSpacing`, `addOptionRatio`, `addAsset`, `addTokenType`, `addIsLong`,
  `addRiskPartner`, `addStrike`, `addWidth`.
- **CI has the sources; this working tree does not.** `develop-gate.yml:123-126` inits
  `lib/panoptic-v2-core` one level, blocks `panoptic-helper` (it contains `panoptic-v2-core` and
  recurses infinitely), then recursive-inits `lib/`. Locally only a stale 6-file partial checkout
  survives and `contracts/` is absent — so this is gate-verifiable but **not** locally runnable.

### How the payload reaches the builder

- **Free offset.** The `.sol` test appends the payload word after the fixed args and encodes its
  ACTUAL byte offset into the descriptor; the builder reads wherever it points. Only this form
  exercises `offset` as a pointer — a fixed convention leaves two of the descriptor's three fields
  decorative, and Phase 4's wire format would inherit that fiction.
- **Out-of-range offsets need no separate bounds check, but DO need an explicit test.** A read past
  `calldatasize()` yields an all-zero word, which 2.5's `extra_payload_validate` already rejects on
  the first `ratio_k == 0`. The phase must include a test that deliberately points past
  `calldatasize()` and asserts the revert — the coverage is demonstrated, not reasoned about.

### How the asset bit reaches the builder

- **The caller passes the COMPUTED asset bit as a `u256`.** The caller runs
  `vol_market_key_panoptic_asset_bit(V, k)` and hands the builder a 0-or-1.
- The builder therefore stays generic over **ONE** comptime tag (`T`) and never learns what a venue
  is. This matches how `pool_id` already arrives: a value the builder does not question.
- It also keeps the seam intact — 2.5 owns the derivation and its F1 inversion test; Phase 3 owns
  only the write. The inversion (`1 -% asset_index`) is NOT re-implemented here.

### What a redundant-field disagreement does

- **REVERT.** The spine is *the caller declares, the contract proves*, and a proof that discards its
  input is not a proof. A mis-declared `tokenType` means the caller believes something false about
  the position being opened; silently correcting it hides that.
- Accepted cost, stated so nobody rediscovers it as a bug: a caller can brick an otherwise valid
  order by mis-declaring a field the builder already knows.
- This applies only under `FLAG_PANOPTIC` — there is no payload to disagree with on the `None` path,
  so that path is untouched by construction.

### Retiring the Phase-2 pin, and what replaces it

- **CORRECTED during planning (2026-08-28).** This discussion assumed the pin goes RED when the phase
  lands. IT DOES NOT. `test__unit__phase2MapStillHardcodesRatioOneAndNoAsset` calls
  `tokenIdWithNoneExtra` — the NO-PAYLOAD path — and asserts `optionRatio == 1` and `asset == 0`.
  Criteria 3 and 4 require that path to keep emitting exactly today's bits, so the assertions stay
  true. Planning found this while measuring the signature-change blast radius: the two harnesses
  behind the floor and the pin keep their ABIs and pass a literal `0` for the new `asset_bit`
  parameter, so neither output moves.
- **The pin is therefore RENAMED, not retired, and its assertions are KEPT.** What became false is
  the NAME: `phase2MapStillHardcodes…` implies "not yet", when after this phase it is the permanent,
  intended behaviour of the no-payload path. Renamed, it expresses criteria 3 and 4 as an executing
  assertion instead of leaving them to the golden vectors alone.
- **A SUCCESSOR GAP PIN IS PLANTED.** One named test asserting that the remaining Haskell divergences
  still exist, so Phase 8 must retire it deliberately — exactly as this phase retires Phase 2's. What
  it records: no `|tick| <= uniswapMaxTick` guard, no per-leg span guard (both Phase 8), and
  `asset_index == 1` being inexpressible in the Haskell oracle. The mechanism has already worked once
  in this project; an unrecorded known gap at a phase boundary is its recurring failure mode.

### Claude's Discretion

- The read mechanism for the payload word (`std::slice::Slice(T, u256, Some(1))`,
  `std::calldata::unsafe_calldata_read`, or a raw `@evm_calldataload`). Note that
  `Slice(T, u256, Some(4))` is the WRONG shape — the payload is ONE packed 40-bit word, not four
  elements — so this morning's open question is closed by the format itself.
- The harness entrypoint's exact ABI and which harness hosts it.
- The anchor input's concrete values.
- Whether the fuzz corpus varies the offset as well as the payload.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The design of record for this phase's inputs
- `docs/superpowers/specs/2026-08-28-volmarketkey-and-extra-payload-widening-design.md` — Phase 2.5's
  spec. §6 the 40-bit payload and its guards; §6.2 the `tickSpacing` two-producer finding that lands
  on THIS phase; §7 the asset single-writer constraint; §9 the phase split; §9.1 the 3.5 arithmetic.
- `.planning/phases/02-volorder-t-minimal-instantiation/02-REGRESSION-ASSESSMENT.md` §4a — the Phase 2
  design of record: `Extra(T)` as a tagged descriptor, absence as `None`, and decision 7 (`pool_id`
  stays an explicit parameter).
- `.planning/ROADMAP.md` §"Phase 3" — criteria (STALE, restate first) and the scope-seam paragraph;
  §"Phase 2.5" for what this phase consumes and the seam's other half.

### The oracle
- `lib/panoptic-v2-core/contracts/types/TokenId.sol` — via the `@types/` remapping. THE differential
  oracle for this phase. Not present in this working tree; present in the gate.
- `lib/panoptic-v2-core/test/foundry/types/TokenId.t.sol` — Panoptic's own tests. Read for which
  builder calls exist and how they are exercised; do NOT inherit the contract.
- `test/protocol_integrations/DynamicFeeHookE2E.t.sol` :17, :179 — the in-repo precedent for
  importing and driving `TokenId`.
- `spec/src/Panoptic/NId.hs` :67-133 — `volOrderToTokenId`, the milestone's eventual oracle. Sets
  `asset = 1` unconditionally and rejects ratios outside 1..127; both are divergences this phase
  records rather than closes.

### The code under refactor
- `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` — `vol_order_to_panoptic_token_id`
  (the only `comptime T` signature) and its five callers, including `vol_order_to_mint` whose four
  `panoptic_add_asset` calls must be removed ATOMICALLY with the Layer-1 write.
- `src/types/Extra.plk` — the descriptor and, after 2.5, the payload accessors.
- `src/types/protocol_integrations/PanopticTokenId.plk` :26-27 — `panoptic_add_asset` and
  `panoptic_add_option_ratio` are ADDITIVE (`+%`), which is what makes a double-write silent.
- `src/types/protocol_integrations/VolMarketKey.plk` — 2.5's key; this phase calls only
  `vol_market_key_panoptic_asset_bit` (indirectly, via its caller).

### Test surfaces
- `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` — the 10/10 regression floor.
  **NO EDITS.** Its `_validate` is a hand-port of `TokenIdLibrary.validate()`; new tests use the real one.
- `test/types/pos_spec/VolOrderType.t.sol` — hosts the Phase-2 pin this phase retires, and the
  `vm.tryFfi` negative-test pattern (`_tryBuild` at :167).
- `fixtures/plank-negative/VolOrderBadRegion.plk` — the fixture pattern, including its own recorded
  lesson: a fixture must be REACHABLE from `run{}` or plank never type-checks it and the test passes
  vacuously.

### Project doctrine
- `AGENTS.md` (= `CLAUDE.md`) — inline phases (2.5's worktree is a scoped exception), chunk approval
  before commit, tests RED first, CI as the only validation gate, fork → PR.
- `.planning/STATE.md` §`stopped_at` — the restatement instruction and the rulings this phase inherits.
- `notes/DATA_CONTRACT.md`, `notes/UNITS_AND_SCALES.md` — binding spec, cited from `src/*.plk`.

</canonical_refs>

<code_context>
## Existing Code Insights

### What Phase 2.5 hands over (read from `origin/feat/volmarketkey`, verified)

All payload accessors take an **already-read `u256` word**. Nothing in 2.5 touches region `T` — the
dereference is entirely this phase's.

```
src/types/Extra.plk
  EXTRA_PANOPTIC_BITS = 40 ; PAYLOAD_LEG_STRIDE = 8 ; PAYLOAD_OFF_VEGOID = 32
  extra_payload_option_ratio(p: u256, leg: u256) u256      // (p >> 8k) & 0x7f
  extra_payload_token_type(p: u256, leg: u256) u256        // (p >> (8k+7)) & 1
  extra_payload_vegoid(p: u256) u256                       // (p >> 32) & 0xff
  extra_payload_validate(p: u256) void                     // vegoid != 0 AND every ratio != 0
  extra_payload_require_vegoid_agrees(p: u256, pool_id: u256) void
  extra_decode(comptime T, word) Extra(T)                  // now REQUIRES len == 40, REJECTS 28

src/types/protocol_integrations/VolMarketKey.plk
  vol_market_key_panoptic_asset_bit(comptime V, k) u256    // 1 -% asset_index  (F1)
  vol_market_key_to_panoptic_pool_id(comptime V, k, sfpm, vegoid) u256
```

Leg `k` occupies `[8k..8k+7]`: `optionRatio` 7b at `8k`, `tokenType` 1b at `8k+7`. **The stride is 8,
not 7** — a stride of 7 would make each leg's `tokenType` read as the next leg's ratio LSB.

### The builder as it stands

`vol_order_to_panoptic_token_id(comptime T, vo: VolOrder(T), pool_id: u256)` — the ONLY `comptime T`
signature in its file. Today it hardcodes `optionRatio = 1` on four legs, derives `tokenType`
`(0,0,1,1)` from the i\* split, sets `isLong = 1`, self-partners every leg, masks `pool_id` to 48
bits and writes `tickSpacing` once at `[48..63]`. Five callers, all concrete on `VolOrder(calldata)`.

### Established patterns this phase must follow

- **Plank only type-checks what something instantiates.** Every comptime branch and every negative
  fixture must be reachable from `run{}` — the defect gate `33181644493` caught.
- **Negative tests must match the error TEXT**, not just a non-zero exit: a fixture with a typo also
  fails to compile. `test__unit__nonRegionTagDoesNotCompile` is the strong form to copy;
  `test__unit__extraFieldsNeedUnwrap` two lines below it is the weak form to avoid.
- Corpora are **constructed with `bound`**, never filtered with `vm.assume`; every fuzz gets a
  non-fuzz anchor; non-vacuity is asserted rather than assumed.
- Solidity reaches Plank through packed `u256` words and a `.plk` harness, so the harness ABI is the
  only coupling surface that matters.

### Integration points

- `vol_order_to_mint` — must lose its four `panoptic_add_asset` calls in the SAME commit that adds
  the Layer-1 asset write (VORD-08). `panoptic_add_asset` is additive; a surviving second write
  carries into `optionRatio`'s LSB, and the golden vectors cannot see it because they exercise
  Layer 1 only.
- `VolOrderToPanopticTokenIdHarness.plk` — the frozen-in-Phase-2 ABI edge; the freeze has expired but
  the floor test that sits behind it has not.

</code_context>

<specifics>
## Specific Ideas

- The maintainer's framing of the whole split, worth preserving: **2.5 is "the poolId formalized and
  derived from a key"; Phase 3 is "the tokenId built from the VolOrder."**
- On the oracle, verbatim intent: *"explore the TokenId.t.sol from the panoptic-v2-core test suite,
  ideally even inherit that contract and run differential tests for each of the cases they do."* The
  investigation redirected "inherit the contract" to "drive their library" — inheriting would test
  Panoptic's code, not ours — but the intent, an oracle that is neither our implementation nor a
  hand-derived constant, is what the decision preserves.
- The structural novelty worth naming: Phase 3 is **the first code in this project that follows a
  pointer into a region** rather than receiving its operands directly. Two distinct calldata regions
  now exist — the `VolOrder` word, and the payload word the descriptor points at.

</specifics>

<deferred>
## Deferred Ideas

- **Retiring the hand-ported Panoptic decoders elsewhere.** `VolOrderToPanopticTokenId.t.sol`'s
  `_validate` is a verbatim port of `TokenIdLibrary.validate()`, and `PanopticTokenId.t.sol:8` says
  its decoders are "inlined verbatim". Now that `@types/TokenId.sol` is known reachable, those copies
  could call the real library. NOT this phase — criterion 3 forbids editing the floor file.
- **`asset == 0` sizing inversion** — Phase 3.5, with the §9.1 underflow as a known BLOCKER: the
  inner `mulDiv96` floors to zero for every leg below tick ≈ −665455 (25% of the negative range).
- **The three missing Haskell guards** — Phase 8 (GUARD-01/02/03). This phase only RECORDS them via
  the successor gap pin.
- **Cleaning the stale local checkouts** so a developer can re-verify Panoptic findings without a
  scratchpad clone — attached to 2.5's planning questions, unresolved.

</deferred>

---

*Phase: 03-volorder-t-rich-instantiation*
*Context gathered: 2026-08-28*
