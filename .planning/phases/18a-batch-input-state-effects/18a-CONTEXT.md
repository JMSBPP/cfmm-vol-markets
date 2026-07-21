# Phase 18a: Batch Input & State Effects - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning
**Source:** The post-review v4.0 roadmap/requirements + the corrected 18a research (`1c26c66` — read its correction banner FIRST) + the input-word layout pinned at `8242804`.

<domain>
## Phase Boundary

**THE MULTICALL — input half only.** Extend `VolOrderManagerMod.plk`'s dispatch with `create_orders`:

1. Standard-ABI decode of `create_orders(uint256 count, uint256[] packedOrders)` behind THREE guards.
2. Bounded runtime `while` over the array, per-tuple validate-then-skip, sequential ids for successes only.
3. Returns **ONE WORD** — the success count. Deliberately: state effects must be provable without trusting any encoder, because the encoder is Phase 18b and has no in-repo precedent.

NOT here: the `(bool,uint256)[]` return encoding (18b). NOT here: the full differential, mutation battery over the whole surface, consumer fixture, `make test` fold-in (19).

Requirements: **MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06**. Roadmap Phase 18a SC 1–6 are the acceptance contract.
</domain>

<decisions>
## Locked decisions

### The calldata layout — VERIFIED BY EXECUTION, not inferred
`cast calldata "create_orders(uint256,uint256[])"` produces exactly:

```
byte   0  selector (4 bytes)      0x81357911
byte   4  count                   N
byte  36  array offset            0x40        <- GUARD 1
byte  68  array length            N           <- GUARD 2 (must == count)
byte 100  element 0
byte 100 + 32*i   element i
          calldatasize = 100 + 32*N           <- GUARD 3
```
Confirmed sizes: N=0 → 100 bytes, N=1 → 132, N=2 → 164.

### ⚠ THE TRANSCRIPTION TRAP — the most valuable thing research produced
`merkle_airdrop.plk:45` reads `let offset = 4 + @evm_calldataload(68);`. **Do NOT copy that 68.**
Its head is THREE words (address@4, amount@36, offset@68); ours is TWO (count@4, offset@36).
Copying `68` would only behave correctly when `count == 64` — a bug that passes most tests.
Our offset word is at **byte 36**.

`merkle_airdrop.plk` is the ONLY in-repo runtime-`while` + computed-offset precedent. Read it for
the loop idiom ONLY (lines ~52-64), and read it as PARTIAL: it has **no calldatasize guard and no
offset sanity check**. Transplanting its shape wholesale defeats MCAL-02, which exists to prevent
exactly that gap.

### `@evm_calldatasize` — confirmed usable
Exact form at `plankc/plank-diff-tests/src/std/abi_dynamic.plk:7`: `let size = @evm_calldatasize();`
(parens, returns a value). Five live usages across that std corpus. No compile-check task needed.

### INPUT word bit layout (pinned decision of record, `8242804`)
```
bits   0..15    skew    (u16)
bits  16..103   strike  (u88)
bits 104..127   width   (u24)
bits 128..255   MUST BE ZERO  -> dirty-high-bit rejection
packed = skew | (strike << 16) | (width << 104)
```
Deliberately identical to the STORED word for bits 0..103, so Phase 16's tested masks/shifts apply
unchanged. Only `width` differs: 104 in the input, 128 in storage, because the module inserts
`TICK_SPACING = 20` at bits 104..127 en route to `pack_vol_order`. The peer has been sent this.

### Best-effort = validate-BEFORE-write, no rollback machinery
A single Plank frame has no per-tuple rollback. An invalid tuple is SKIPPED by never writing it.
Both paths call the SAME `validate_order` (bool core) from `lib::pos_spec::VolOrderValidationLib` —
`create_order` uses `validate_order_strict` (the reverting wrapper), the batch uses the bool core.
That shared descent is what makes accept/reject agreement structural rather than tested-into-existence.

### Guards: structural failure REVERTS, semantic emptiness does not
- All three guards fail → revert the whole tx (malformed payload is not a per-call skip).
- `count > MAX_BATCH (128)` → revert BEFORE any `sstore`.
- `N = 0` → completes without reverting, touches no state (a zero-arrival Poisson tick is an
  in-distribution sample, not a client error).

### The M5 hand-off from Phase 17 — MUST become a real kill here
Hoisting the `orderCount` store above validation was EQUIVALENT in Phase 17 (the strict path's
revert rolls back the SSTORE). In the batch it is NOT: a skipped tuple leaves the counter advanced,
so ids gap and a later order lands at the wrong slot. **Re-run that mutant here and expect RED.**
Research proposes the discriminating shape: the invalid tuple must sit in the MIDDLE of the batch,
and the load-bearing assertion is **contiguity** (`orderSlot(C+2)` holds the third valid order),
not the count.

### Guard-3's mutant is invisible to state assertions — kill it with a revert assertion
Deleting the `calldatasize` guard does NOT corrupt state on a truncated payload: `calldataload`
past the end returns zero-padded words, the zero tuple fails validation, and it gets skipped —
leaving state clean. It must be killed by asserting a REVERT on hand-truncated calldata via a
low-level `.call`, not by any state check.

### Gas / allocator — UNVERIFIED, re-derive if load-bearing
Research's gas model (~2.94M at N=128 vs the 10M budget) and its allocator disassembly sat beside
fabricated citations. The MCAL-01 criterion is `measured N=MAX_BATCH ≤ 10,000,000 gas` — MEASURE it
in the test, do not carry the estimate forward as fact.

### Test discipline
CALLED-green only. Every dispatch branch exercised. Guards asserted ON STATE (`orderCount`
unchanged) except guard 3, which needs the revert assertion above. Constructed corpora, no
`vm.assume`. Non-fuzz anchor beside every fuzz. Clear `cache/fuzz` when proving a kill. Every forge
run: `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`.
NEVER modify `src/types/pos_spec/*`.

### Claude's Discretion
- Whether the batch test lives in `test/pos_spec/VolOrderManager.t.sol` (extending Phase 17's) or a
  new `VolOrderManagerBatch.t.sol` — the batch is arguably its own surface; choose and justify.
- The one-word return's semantic: success count is the roadmap's suggestion; anything single-word
  and CALLED-verifiable is acceptable if justified.
- Loop idiom details, provided the offset arithmetic is derived from OUR layout, never copied.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract
- `.planning/ROADMAP.md` Phase 18a section (SC 1–6) + the milestone Overview's decisions of record.
- `.planning/REQUIREMENTS.md` — MCAL-01/02/03/04/06 + the pinned input-word layout.
- `.planning/phases/18a-batch-input-state-effects/18a-RESEARCH.md` — **read the correction banner
  first**; the `mock_time_pool.plk` citations throughout are fabricated (no such file).

### Code extended / consumed
- `src/modules/pos_spec/VolOrderManagerMod.plk` — Phase 17's module; you ADD a dispatch branch.
- `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — `create_orders` selector already pinned
  (`0x81357911`); recompute with `cast sig` and use your own value.
- `src/lib/pos_spec/VolOrderValidationLib.plk` — `validate_order` (bool core) and `build_vol_order`.
- `src/types/pos_spec/VolOrder.plk` — `pack_vol_order` (CALL it; never modify the file).
- `lib/plankified-univ3/plank/lib/storage.plk:230` — `array_slot`; note its `+` is CHECKED.

### Idiom precedents (read critically, not for copying)
- `lib/plank-monorepo/plankc/plank-diff-tests/src/examples/merkle_airdrop.plk` — runtime `while` +
  computed-offset `calldataload` (lines ~52-64). PARTIAL: no guards, three-word head.
- `lib/plank-monorepo/plankc/plank-diff-tests/src/std/abi_dynamic.plk` — `@evm_calldatasize()` in
  use (line 7).
- `test/pos_spec/VolOrderManager.t.sol` — Phase 17's test structure, raw `vm.load` slot assertions.
</canonical_refs>

<specifics>
## Specific Ideas

- The id-65536 non-masking test from Phase 17 must keep passing — the batch shares the same slot
  derivation, and a mask reintroduced here would be just as invisible at small ids.
- A mixed batch (valid, INVALID, valid) is the single most informative corpus point in this phase:
  it exercises skip-without-footprint, id contiguity, and the M5 kill simultaneously.
- Guard 1 deserves a hostile test, not just a wrong-value test: an offset pointing far past the
  array (e.g. 0x2000) is the phantom-order attack the guard exists to stop.
</specifics>

<deferred>
## Deferred Ideas

- `(bool,uint256)[]` return encoding, N=0 return bytes, byte-level encoder differential — Phase 18b.
- Full reference-mock differential, complete mutation battery, consumer golden fixture, `make test`
  fold-in — Phase 19.
</deferred>

---

*Phase: 18a-batch-input-state-effects*
*Context gathered: 2026-07-20 — calldata layout verified by execution; research fabrications quarantined*
