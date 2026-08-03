# Phase 21 — cross-track findings

**Filed:** 2026-08-01, by plan 21-05 (rpc_api / offchain workstream).
**Status of every item below: REPORTED, NOT FIXED.** No file belonging to another track was
edited by this phase. `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml
remappings.txt ../plank/` produced no output at every checkpoint of every plan in this phase.

This document exists because Phase 21 read a great deal of another track's source in order to
re-pin the client against it, and found three things that this track can see but must not touch.
Reporting them in a durable artifact — rather than in a commit message that scrolls away, or in a
comment inside a file the owning track does not read — is the whole point.

> **Label collision, stated once so it does not propagate.** 21-04's summary uses the label "F3"
> for a DIFFERENT finding (the incidental zero-lower-bound rejection in `draw_target_vega`; see
> `21-04-SUMMARY.md`, "Findings"). That finding is a `StochasticOrderGen` matter, it is this
> workstream's own, and it is NOT the F3 below. The numbering here is the numbering plan 21-05
> specified: F1 = the stale V1 comment, F2 = the tickSpacing discrepancy, F3 = the obsolete
> follow-up.

---

## F1 — a stale V1 comment block inside the V2 module contradicts that same file's V2 code

**File:** `src/modules/pos_spec/VolOrderManagerMod.plk`, lines **177-188**.
**Owner:** the **plank track** (agent `ul2inqpl`).
**Class:** documentation defect. **Not** a behaviour defect — see "what is unaffected" below.

Two sentences, quoted verbatim from lines 177 and 182:

```
// INPUT WORD:  skew@0..15 | strike@16..103 | width@104..127 | bits >=128 MUST BE ZERO.
```

```
// width IS DELIBERATELY UNMASKED. It is the TOP field, so any bit >= 128 inflates it past
```

Both sentences are **V1**, and both are **false of the V2 code in the same file**, at lines
221-235. The executing code (lines 229-235) says the opposite:

```
let word = @evm_calldataload(100 + i * 32);
let order = build_vol_order(
    @evm_shr(16,  word) & 0xFFFFFFFFFFFFFFFFFFFFFF,   // strike @16..103
    @evm_shr(104, word) & 0xFFFFFF,                   // width  @104..127, now MASKED
    word & 0xFFFF,                                    // skew   @0..15
    @evm_shr(128, word)                               // targetVega @128.., UNMASKED top field
);
```

So in V2: bits >= 128 are **not** required to be zero (that is where `targetVega` lives), and
`width` is **not** the top field and **is** masked. The V2 comment block immediately above the
code (lines 221-228) states the V2 truth correctly. The file therefore contains both.

**What is unaffected.** The VALUES are fine. The code, the Phase-20 handoff,
`notes/DATA_CONTRACT.md` and `notes/UNITS_AND_SCALES.md` all agree on the V2 layout, and this
phase's client-side packer was written against the CODE, never against the comment
(`offchain/test/Main.hs` says so in the header of the RPIN-01/02/03 section).

**Why it still matters, and why it is worth a track-crossing report.** An implementer who reads
lines 177-188 instead of lines 221-235 ships a V1 packer. That packer passes every off-chain test
— it is internally consistent — and is then **SILENTLY SKIPPED on chain**, because the batch path
skips invalid tuples rather than reverting. A V1 word carries `targetVega = 0`, `build_vol_order`
rejects it, and `create_orders` returns `(false, 0)` for that element with no error anywhere. This
is the exact rot class the v5.0 milestone exists to stop, one layer up: **a comment cannot be
tested**, so nothing in either track's suite will ever redden while it is wrong.

Plan 21-02 measured this concretely: its capture script would have degenerated into a
plausible-looking all-`(false, 0)` artifact "proving" the batch return works, had the input word
been built from the stale block.

**Action taken by this track.** Reported here. Warned about inline at the point of use, in
`offchain/rig/capture-batch-return.sh` (immediately above `input_word()`), in
`offchain/test/Main.hs`'s RPIN-01/02/03 header, and in every Phase 21 plan document. **The file
was not edited.** Confirmed verbatim by three separate executors (21-01, 21-02, 21-05).

**Suggested fix for the owning track:** delete lines 177-188, or mark them `V1 (SUPERSEDED)` in
place. One line of either would close it.

---

## F2 — `TICK_SPACING = 20` (module constant) vs the rig pool's `tickSpacing = 10`

**Owner:** the **plank track**. **Class:** open design question, not a bug in anything shipped.

Both values, with their sources:

| value | source |
|---|---|
| `const TICK_SPACING = 20;` | `src/lib/pos_spec/VolOrderValidationLib.plk:33` (used at line 71: `rangeWidth: VolRangeWidth { width: width, tickSpacing: TICK_SPACING }`) |
| `tickSpacing = 10` | `offchain/rig/rig-manifest.json`, `.pool.tickSpacing`, written by `offchain/rig/deploy-rig.sh` from the actually-deployed pool |

> Correction to plan 21-05's own reading list, recorded because it is the kind of pointer that
> rots: the plan says to read `TICK_SPACING` out of `src/types/pos_spec/VolOrder.plk`. It is not
> there. `grep -rn TICK_SPACING src/` puts the only declaration in
> `src/lib/pos_spec/VolOrderValidationLib.plk:33`.

**Nothing in Phase 21 breaks because of this.** `unpack_vol_order_storage` reads the stored
`tickSpacing` out of bits 104..127 and **discards** it — it is the module's constant, not part of
`VolOrder`. So the client never compares the two numbers and cannot be wrong about them.

**Where the discrepancy is nonetheless pinned.** 21-01's `rpin03_storage_round_trip` asserts the
tickSpacing slot holds `20`, i.e. it is written against the **module constant**, deliberately, so
that a change to `TICK_SPACING` reddens loudly here rather than drifting. The expectation is
`module_tick_spacing` in `offchain/test/Main.hs` and carries an in-file comment naming the
discrepancy. `offchain/lib/VolOrder/Decode.hs` also records it in the `unpack_vol_order_storage`
header.

**The open question, which is the plank track's to answer:** once order placement actually lands
against a pool, which of the two is intended — should the module take the pool's spacing rather
than pinning its own constant, or should the rig deploy a spacing-20 pool? A vol order whose
`rangeWidth` is expressed in units of a spacing the pool does not have is a silent unit error of
exactly the kind `notes/UNITS_AND_SCALES.md` exists to prevent.

**Action taken by this track:** reported, out of scope, expectation pinned to the module constant.

---

## F3 — this workstream's own tracked follow-up #7 is OBSOLETE, and #5 is only PARTIALLY addressed

**File:** `docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md`.
**Owner:** **this workstream** (rpc_api). Corrected in place by this plan — see below.

### #7 is OBSOLETE — its premise is false and acting on it would have deleted live code

Follow-up #7 reads, verbatim:

> **Dead event decoder**: `VolOrder.Decode.decode_order_created` / `Report.report_order_created`
> target the legacy module's event; the deployed pos_spec module emits no logs. Already filed as
> its own follow-up spec (spec Out of scope); delete or mark legacy when that lands.

**"The deployed pos_spec module emits no logs" is now false.** V2 added `emit_vol_order_created`
on BOTH the strict and the batch path, at **`src/lib/events/VolEventsLib.plk:47-54`**:

```
const emit_vol_order_created = fn(order_id: u256, strike: u256, width: u256, skew: u256, target_vega: u256) void {
    let buf = @malloc_uninit(128);
    @mstore32(buf,        strike & MASK_U88_EV);
    @mstore32(buf +% 32,  width  & MASK_U24_EV);
    @mstore32(buf +% 64,  skew   & MASK_U16_EV);
    @mstore32(buf +% 96,  target_vega & MASK_U96_EV);
    @evm_log2(buf, 128, TOPIC0_VOL_ORDER_CREATED, order_id);
};
```

The decoder is therefore **live, not dead**, and it was re-pinned to the V2 shape by plan 21-03
(two topics, four data words, `orderId` from the indexed topic). 21-03 additionally captured a
**real E1 v2 log off a real chain** — the first ever observed — confirming every structural claim.
Had #7 been actioned as written, the decoder would have been deleted the same week the module
started emitting.

**Marked OBSOLETE in place**, original text preserved, per Part C of this plan.

### #5 is PARTIALLY addressed — and the plan's claim that it was ADDRESSED is wrong

Plan 21-05 instructed this document to record follow-up #5 as "ADDRESSED by plan 21-01's storage
round-trip check". **That was checked rather than transcribed, and as stated it is false.**
Follow-up #5 reads:

> **Whole-word storage verification** in `verify_mined_order`: recompute the full expected storage
> word (incl. `tickSpacing = 20` at bits 104–127) and compare whole words, catching tickSpacing
> drift and junk high bits the 3-field unpack ignores.

The follow-up is about **`verify_mined_order`**, the production verifier. That function is at
`offchain/lib/VolOrder/Rpc.hs:94-104` and is **unchanged by this phase**. It still does:

```haskell
  packed <- read_order_packed manager block order_id
  let actual_order = unpack_vol_order_storage packed
  if actual_order == expected_order
```

That is a comparison of the **4-field record**, after unpacking. `unpack_vol_order_storage` reads
bits 0..15, 16..103, 128..151 and 152..247 — so bits **104..127 (tickSpacing)** and bits
**248..255 (junk high bits)** are discarded before the comparison happens. A mined word carrying a
drifted tickSpacing, or junk above bit 247, would still be **ACCEPTED**. That is precisely and
exactly what #5 asked to catch, and it is not caught.

**What 21-01 genuinely did deliver**, and it is worth having: `rpin03_storage_round_trip` asserts
the tickSpacing slot equals the module constant and that bits >= 248 are zero, over six
`vega_corners`. But it does so against a word built by the test's own `pack_storage_reference`,
not against a word read from a chain, and not inside `verify_mined_order`.

So: **test-side coverage of the property, production-side gap unchanged.** #5 is annotated
PARTIALLY ADDRESSED, not ADDRESSED.

### #2 — newly MEASURED by this plan, still open

Follow-up #2 asks to "check the offset word against `0x20`" in `decode_create_orders_result`,
noting it is "currently unexploitable against this contract". Plan 21-05 **measured** that
leniency for the first time: flipping the last hex character of the outer offset word in the
committed capture (`0x20` -> `0x21`) leaves `decode_create_orders_result` decoding the bytes
**successfully and silently**, while a Solidity `abi.decode` would follow the corrupted pointer.
`rpin05_live_bytes_match_the_external_golden` DOES redden on it, so the suite is not blind — but
the decoder is. The "currently unexploitable" assessment still holds (the module hardcodes the
canonical offset); the follow-up is now backed by a measurement rather than an inspection.
Annotated in place, not fixed: hardening the decoder is a behaviour change and was outside this
plan's scope, which names the decoder as "unchanged by this phase and to be REUSED".

---

## F4 (added by 21-05) — what the capture's freshness assertion does NOT catch

**Owner:** this workstream (rpc_api). **Class:** stated limitation of a check this plan shipped,
recorded so it is not over-read later.

`rpin05_capture_is_present_and_fresh` asserts the capture's `chainId` and `manager` against the
live manifest. Two things were MEASURED while building it:

1. **`generatedAt` is not a witness** — 21-02's finding, inherited. The capture script completes in
   ~294 ms against a 1-second timestamp resolution, so two runs share a label.
2. **`blockNumber` is not a witness either — this is NEW, and it refutes half of 21-02's
   carry-forward D2**, which recommended "`blockNumber` / `manager` are the discriminating
   provenance fields". Three from-scratch deploys of the *same* rig during this phase produced
   chain heights **9, 11 and 10**. Asserting `blockNumber` would have reddened the suite after an
   ordinary redeploy, for no defect. The check deliberately does not assert it.

**What the check therefore establishes:** the committed capture describes the same chain and the
same contract address the current manifest describes. A capture taken against a fork, a different
chain, or a rig whose deploy order changed will redden — demonstrated by an observed RED on a
one-character change to `.manager`.

**What it does NOT establish, and this is the honest limit.** The manager is a `CREATE` address,
derived from `(deployer, nonce)` and therefore **independent of the deployed bytecode** — measured
here as three separate from-scratch deploys all yielding the identical address
`0x5fbd…aa3`. So if the plank track **changes `VolOrderManagerMod.plk` and redeploys**, the
address is unchanged, and a capture taken from the *previous* module version would still pass this
check while describing bytecode that no longer exists. (This is reasoned from `CREATE` semantics
plus the measured address stability, not demonstrated end to end — demonstrating it would require
editing another track's source.)

**Proposed fix, for whoever needs the stronger guarantee:** record the deployed manager's code
hash in the capture and assert it. At the time of writing, the live manager's code is 2147 bytes
with `keccak(code) = 0x6356ea165c3e5790ee71801a9c74a535f4d7719165b8291e4057cf26d72b19a4`. Nothing
asserts that today. This was not added by 21-05 because it changes
`offchain/rig/capture-batch-return.sh`'s artifact schema, which is 21-02's deliverable and would
invalidate the committed capture this plan's assertions are built on — a change worth making
deliberately, not as a late edit in the phase's final plan.

---

## How to consume this

- **plank track (`ul2inqpl`):** your items are **F1** and **F2**. F1 is a two-minute deletion with
  a real silent-failure mode behind it. F2 is a design question only you can answer.
- **Solidity-testing track:** your item is not a defect but an **offer**. The
  `peer_haskell_bytes` array in `test/pos_spec/fixtures/vol_order_return_golden.json` still holds
  five `PLACEHOLDER -- NOT-PEER-VERIFIED` entries, and `_peer_status` records that this rpc_api
  track never delivered Haskell-produced bytes. It now has: **`offchain/rig/peer-haskell-bytes.json`**
  carries the shipped Haskell decoder's output for all five golden cases, regenerable with
  `cabal exec -- runghc offchain/rig/gen-peer-bytes.hs`. All five decode; all five agree with the
  golden's declared element counts. **The fixture was not edited by this track** — the values are
  offered, and copying them across (or pointing the fixture test at this file) is yours to do.
  Note the scope limit recorded in the artifact's `_scope`: this closes the cross-language gap for
  the **RETURN** side only, and exercises no Haskell **encoder**, so the canonical-array-offset
  requirement on the INPUT side remains unexercised from our side.
- **this workstream (rpc_api):** **F3**, actioned in place in the verification record — #7 marked
  OBSOLETE, #5 corrected to PARTIALLY ADDRESSED, #2 annotated with the new measurement.
