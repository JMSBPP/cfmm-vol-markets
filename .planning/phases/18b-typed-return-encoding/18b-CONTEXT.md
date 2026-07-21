# Phase 18b: Typed Return Encoding - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning
**Source:** The post-review v4.0 roadmap/requirements + facts verified at source during this session. The roadmap's one open research question for this phase is RESOLVED below.

<domain>
## Phase Boundary

The `(bool success, uint256 orderId)[]` return encoder — the ONLY surface in this milestone with no in-repo precedent, which is why it is its own phase.

1. Replace 18a's one-word return from `create_orders` with the hand-rolled dynamic-array encoding.
2. The N=0 edge, positional alignment, canonical bools, `(false, 0)` for failures.
3. Byte-level differential against Solidity's standard `abi.encode`, plus this phase's mutation gate.

NOT here: anything about decode/guards/loop/state (18a, done and verified). NOT here: the full reference-mock differential over sequences, the consumer golden fixture, `PLANK_SKIP`/`make test` fold-in (Phase 19).

Requirement: **MCAL-05** — plus the carried clause from MCAL-06 (see below). Roadmap Phase 18b SC 1–5 are the acceptance contract.
</domain>

<decisions>
## Locked decisions

### RESOLVED: `std::abi` CANNOT encode this — hand-rolling is required
The roadmap flagged as an open question whether `std::abi`'s comptime machinery (`abi_encoded_size`,
`unsafe_abi_encode`, `is_abi_dynamic`) is a partial reuse path. **It is not.** Verified at
`lib/plank-monorepo/std/abi.plk:22-58`: `abi_encoded_size` branches on exactly
`void | u256 | bool | membytes | @is_struct(T)`, and every other type falls to
`let _sizeof_unsupported_type: u256 = true;` — a deliberate compile-time type error. **There is no
array case**, and Plank has no native array type to pass it regardless.

A `membytes`-shaped workaround does NOT work either: `bytes` encodes its length in BYTES while
`T[]` encodes it in ELEMENTS, so for N=2 the length word must read `2`, not `128`. The layouts
diverge at exactly the word that matters.

What the precedent DOES prove is the mechanism: `abi_dynamic.plk:6-15` — `@malloc_zeroed(size)`,
write, `@evm_return(out, written)` with a computed length. Use that shape; supply the array
semantics by hand.

### The byte layout (pinned during the roadmap review, do not re-derive)
```
offset 0x00   0x20        <- outer offset word to the array
offset 0x20   N           <- element count
offset 0x40   success[0]  (canonically 0 or 1)
offset 0x60   orderId[0]
offset 0x80   success[1]
offset 0xA0   orderId[1]
...
head = 0x40, stride = 0x40, TOTAL = 64 + 64*N
```
`(bool,uint256)` is a STATIC tuple, so elements are inlined in the tail with no per-element offsets.
**The single likeliest bug in this phase is writing head `0x20`** — emitting the length word but
forgetting the outer offset word. That is a named mutant.

### N = 0 is the trickiest edge, and its failure is invisible on-chain
A correct empty return is exactly **64 bytes**: offset `0x20`, length `0`. Returning 0 bytes, or 32
(length only), makes the consumer's `abi.decode` revert — a failure that surfaces in the Haskell
client, not here. Governing principle, already recorded in the milestone: **structurally impossible
→ revert; semantically empty → well-formed empty result.** A zero-arrival Poisson tick is an
in-distribution sample, not a client error.

### The differential must compare BYTES, not decoded values
The Solidity side encodes with the STANDARD `abi.encode` while Plank hand-rolls, and the assertion
is `keccak256(plankReturndata) == keccak256(abi.encode(expected))`. A decoded-value comparison
compares semantics and leaves the encoder unconstrained — a consistent head/stride error might not
even surface. Byte equality makes solc an independent oracle for the one surface with no precedent.
Include N=0 in the differential corpus.

### Allocation ordering — a live corruption path
`array_slot` calls `@malloc_uninit(32)` on EVERY invocation (`storage.plk:232`), i.e. once per loop
iteration. The results buffer MUST be allocated BEFORE the loop; interleaving buffer growth with
per-iteration allocations under a bump allocator corrupts it. Test at `N = MAX_BATCH` (128).
NOTE: 18a's research claimed disassembly showing a static malloc address, but that claim sat beside
fabricated citations and is UNVERIFIED — treat the ordering rule as binding regardless.

### Canonical bools
`success` words must be exactly 0 or 1. Solidity's `abi.decode` rejects a non-canonical bool; a
Haskell decoder may silently accept it — the two consumers would then disagree about the same bytes.
Named mutant.

### MCAL-06's carried clause comes due here
18a marked MCAL-06 "Complete (state half; return-bytes clause carried to 18b)" because
`return_u256` emits one 32-byte word and structurally cannot satisfy the N=0 64-byte encoding. This
phase discharges that clause — update MCAL-06's annotation to fully Complete once the N=0 return is
byte-verified.

### Test discipline
CALLED-green only. Constructed corpora, no `vm.assume`. Non-fuzz anchor beside every fuzz. Clear
`cache/fuzz` when proving a kill. Every forge run:
`--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`.
NEVER modify `src/types/pos_spec/*`. The 18a state/guard tests must all stay green — changing the
return type must not disturb any state behaviour.

### Claude's Discretion
- Whether the encoder lives inline in the module's batch branch or in a small pure helper.
- Where the byte-level differential tests live (extending `VolOrderManagerBatch.t.sol` is the
  likely answer — same surface, now returning real data).
- Additional mutants beyond the named three, with justification. If one proves equivalent, document
  it as equivalence-checked rather than counting it.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract
- `.planning/ROADMAP.md` Phase 18b section (SC 1–5) + the milestone Overview's decisions of record.
- `.planning/REQUIREMENTS.md` — MCAL-05 and MCAL-06's carried clause.

### Code modified / consumed
- `src/modules/pos_spec/VolOrderManagerMod.plk` — 18a's batch branch; you replace its one-word
  return. Everything else in that branch is verified and must not regress.
- `v3::util::return_u256` (`lib/plankified-univ3/plank/lib/util.plk:23`) — what you replace, and the
  reason 18a could not satisfy the N=0 clause.
- `lib/plankified-univ3/plank/lib/storage.plk:232` — `array_slot`'s per-call `@malloc_uninit(32)`.

### The mechanism precedent (shape only — its TYPE handling does not apply)
- `lib/plank-monorepo/plankc/plank-diff-tests/src/std/abi_dynamic.plk:6-15` — `@malloc_zeroed` →
  write → `@evm_return(ptr, computedLength)`.
- `lib/plank-monorepo/std/abi.plk:22-58` — read the `abi_encoded_size` branches yourself to confirm
  the no-array finding rather than taking it on faith.

### Test patterns
- `test/pos_spec/VolOrderManagerBatch.t.sol` — 18a's batch surface incl. the `callBatch` low-level
  helper and hand-rolled calldata construction.
- `test/pos_spec/VolOrderManager.t.sol` — `VolOrderManagerBase` (slot preimages, `orderSlot()`,
  `expectedPacked()`).
</canonical_refs>

<specifics>
## Specific Ideas

- The mixed batch (valid, INVALID, valid) from 18a is the best differential corpus point here too:
  it exercises positional alignment AND `(false, 0)` for the middle failure in one assertion.
- Compute the expected bytes Solidity-side as `abi.encode(resultsArray)` where the array is built
  from the same inputs — never by mirroring Plank's manual writes, which would make the differential
  vacuous.
- A head-`0x20` mutant should be checked for killability at N=0 specifically: with N=0 the total is
  64 bytes either way, so the corpus must include N≥1 for that mutant to be distinguishable.
</specifics>

<deferred>
## Deferred Ideas

- Full reference-mock differential over `(create_order | create_orders)` sequences, the complete
  cross-phase mutation battery, the consumer golden fixture, `PLANK_SKIP`/`make test` fold-in —
  Phase 19.
</deferred>

---

*Phase: 18b-typed-return-encoding*
*Context gathered: 2026-07-21 — the std::abi open question resolved at source; byte layout inherited from the roadmap review*
