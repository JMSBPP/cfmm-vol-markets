---
phase: 18b-typed-return-encoding
plan: 01
subsystem: pos_spec / VolOrderManagerMod
tags: [abi-encoding, dynamic-array, differential-testing, mutation-gate, plank, mcal-05]
requires:
  - 18a-01 (the batch whose results this encodes; every state assertion inherited unchanged)
  - v3::storage::array_slot (per-call @malloc_uninit(32) — the allocation hazard)
provides:
  - "create_orders returning hand-rolled (bool,uint256)[] at 64 + 64N bytes"
  - "byte-level differential harness vs solc's standard abi.encode (BatchResult[] mirror)"
  - "the N=0 64-byte contract for the rpc_api Haskell consumer"
affects:
  - Phase 19 (MVER-01 raw-byte differential reuses BatchResult + expectedReturn)
  - peer mv15a18k (StochasticOrderGen decodes these bytes)
tech-stack:
  added: []
  patterns:
    - "@malloc_zeroed -> @mstore32(ptr +% off) -> @evm_return(ptr, computedLen)"
    - "solc as an INDEPENDENT encoder oracle via keccak byte-equality"
key-files:
  created: []
  modified:
    - src/modules/pos_spec/VolOrderManagerMod.plk
    - test/pos_spec/VolOrderManagerBatch.t.sol
    - Makefile
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - .planning/STATE.md
decisions:
  - "N=128 gas re-measured at 3,275,765 TOTAL (+28,313 vs 18a)"
  - "M1 base-shift mutant is blind at N=0; M3 stride mutant blind at N<=1 — both MEASURED"
  - "M5 (false,id) leak unkillable by an all-invalid fresh-registry corpus"
  - "M7 reordering unconstructible at the SCOPING level; excluded from the kill count (6, not 7)"
metrics:
  duration: 27 min
  completed: 2026-07-21
---

# Phase 18b Plan 01: Typed Return Encoding Summary

**Hand-rolled `(bool,uint256)[]` ABI return for `create_orders` — head `0x40`, stride `0x40`, total `64 + 64N` — proven byte-exact against solc's standard `abi.encode` across N = 0/1/2/3-mixed/3-all-invalid/128 plus a 256-run constructed fuzz, with six observed mutation kills.**

## What Shipped

`create_orders` previously returned ONE WORD (18a's success count), deliberately, so batch state effects could be proven without trusting an untested encoder. It now emits the real typed return:

```
0x00  0x20        outer offset word
0x20  N           length in ELEMENTS (not bytes)
0x40  success[0]  canonically 0 or 1
0x60  orderId[0]
...                stride 0x40, static tuples inlined, no per-element offsets
TOTAL = 64 + 64*N
```

The results buffer is `@malloc_zeroed(64 + 64 * count)` in ONE call **before** the loop — load-bearing, because `array_slot` calls `@malloc_uninit(32)` on every iteration and interleaving those with the results region under a bump allocator is a live aliasing path. Both branches of the validation `if` write a result slot at `64 + 64*i`, so positional alignment holds **by construction** rather than by accumulation; a failed tuple is exactly `(false, 0)` and does not shift its successors.

The 18a decode path was migrated **in the same task, not a later one**. `callBatch`'s old `if (ok && r.length == 32)` guard would have left `ret` at 0 the instant the return widened past 32 bytes — silently zeroing seven existing assertions, two of which (`assertEq(ret, 0, ...)`) would have passed **vacuously**. `callBatch` keeps its `(bool, uint256)` signature but now decodes `(BatchResult[])` and counts successes, so every 18a test body is byte-unedited while its `ret` assertion now only holds if `abi.decode` accepts the hand-rolled bytes. The 18a assertions got strictly stronger for free.

## Verification

| Check | Result |
|---|---|
| `make compile-plank` | 13 ok, 0 failed, 0 skipped |
| `make test-vol-order-return` | 8 passed, 0 failed |
| `make test-vol-order-batch` | 21 passed, 0 failed (18a bodies unedited) |
| `make test-vol-order-manager` | 12 passed, 0 failed |
| `make test` | **120 passed / 4 pre-existing fails** (was 112/4; +8 new tests) |
| `git diff --stat src/types/pos_spec/` | empty — byte-untouched |
| `vm.assume` in `test/pos_spec/` | none |

The 4 reds are the vol-type track's known `src/types/pos_spec/` harness failures. The known ~1-in-4 `TickVolatilityLibTest` cold-run flake did **not** surface this run.

### Re-measured gas (N = 128)

| | 18a | 18b | Delta |
|---|---|---|---|
| execGas | 3,203,452 | **3,231,765** | +28,313 |
| calldataGas (EIP-2028) | 23,000 | **23,000** | 0 |
| intrinsic | 21,000 | 21,000 | 0 |
| **TOTAL** | 3,247,452 | **3,275,765** | **+28,313 (+0.87%)** |

Calldata gas is unchanged because the INPUT did not change. The +28,313 is the encoder's 2 mstores per element plus memory expansion for the 8256-byte buffer — proportionate, and well inside the plan's 3,400,000 stop-and-investigate band. `assertLe(total, 10_000_000)` remains the only hard assertion; headroom is 3.05x.

## The Mutation Gate — 6 observed kills

Protocol per mutant: apply → `forge clean && rm -rf cache/fuzz` → observe and record the verbatim FAIL → restore → confirm `sha256` identical → re-run green. Baseline hash `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`; **every mutant restored to that exact hash**, verified each time.

| # | One-line diff | Named failing assertion (verbatim) | Kill |
|---|---|---|---|
| M1 | `base = 64 + 64*i` → `32 + 64*i` | `N=3 mixed: returndata must be byte-exact: 0xd9063a42... != 0xddf3f6c7...` | YES |
| M2 | outer offset word dropped (`malloc_zeroed(32+64*count)`, single head write, `evm_return(out, 32+64*count)`) | `N=0 bytes must equal abi.encode of an empty BatchResult[]: 0x290decd9... != 0x569e75fc...` | YES |
| M3 | `base = 64 + 64*i` → `64 + 32*i` | `N=3 mixed: returndata must be byte-exact: 0x5fa364a6... != 0xddf3f6c7...` | YES |
| M3′ | `base = 64 + 64*i` → `64 + 96*i` | `N=3 mixed: returndata must be byte-exact: 0x9ac67ebe... != 0xddf3f6c7...` | YES |
| M4 | `@mstore32(out +% base, 1)` → `, 2` | `success word must be canonically 0 or 1, never a truthy nonzero` | YES |
| M5 | else-branch `@mstore32(out +% (base+32), 0)` → `, id` | `N=3 mixed: returndata must be byte-exact: 0x6ee8ff29... != 0xddf3f6c7...` | YES |
| M6 | `@malloc_zeroed(64 + 64*count)` → `@malloc_zeroed(64)` | `N=128: returndata must be byte-exact: 0x34c5d15e... != 0x71bd6c0c...` | YES |
| M7 | move the allocation off the before-the-loop position | — | **EQUIVALENCE-CHECKED, NOT COUNTED** |

**Kill count: 6.** (M3′ is a variant of the same stride mutant, not a seventh distinct one.)

M3′ note, as the plan asked: the `96*i` variant writes past the allocated buffer and the observed failure is the **keccak mismatch, not a revert** — Plank's memptr writes expand memory silently, and `@evm_return` returns only the declared length, so the overflow lands outside the returned window.

M4 note: the mutant also reddens `make test-vol-order-batch` broadly with `EvmError: Revert` — that is solc's `abi.decode` **rejecting** the non-canonical bool outright. Recorded as corroboration of the silent-disagreement thesis, not as extra kills.

## The Three Honest Negatives

Stated plainly, because they are the load-bearing part of this gate:

**1. M1 (element base shift) is BLIND at N=0.** `test__unit__emptyReturnIsExactlySixtyFourBytes` stayed **GREEN** under M1 — observed, not predicted. With zero elements there is nothing to misplace and the total is 64 bytes either way. M1 is killable only at N ≥ 1. This is exactly why the corpus is not allowed to be N=0-only. Conversely M2 (dropped outer offset word) **is** killable at N=0 (32 bytes vs 64) and reddens that same test. The two are complementary; running only one would leave a real gap.

**2. M3 (stride) is BLIND at N ≤ 1 — and this was MEASURED, not argued.** Under M3, `test__unit__oneAndTwoElementReturnsAreByteExact` reddened at its **N=2** assertion while its N=1 assertion **passed**, because `i = 0` makes `64 + stride*i` independent of the stride. That test was added beyond the plan's 7 (see Deviations) and it is what turned this blindness from a claim into an observation.

**3. M7 is unconstructible, and for a stronger reason than anticipated.** The plan expected a bump-allocator argument. The actual finding is at the **scoping** level: moving the allocation inside the loop makes the trailing `@evm_return(out, ...)` fail to compile with `error: unresolved identifier 'out'` (observed). Any reordering that keeps the return reachable requires `out` in the outer scope before the loop — so the before-the-loop ordering is enforced by the language, not by convention. Documented as equivalence-checked and **excluded from the kill count**. M6 carries the allocation-hazard evidence instead.

**A fourth negative, not in the plan's list but found:** M5's `(false, id)` leak is **not killable by an all-invalid batch on a fresh registry**. `test__unit__allInvalidBatchReturnsAllFalseZero` stayed **GREEN** under M5, because `id` never leaves 0 there, so `(false, id)` *is* `(false, 0)`. The SEEDED mixed corpus is the sole kill site. An all-invalid-only corpus would have recorded a fake pass.

**Unresolved, stated rather than guessed:** under M6 the plan asked whether the storage assertion also reddens, to separate results-corruption from slot-derivation-corruption. It could not be determined from these runs — forge reports only the first failing assertion, the keccak fires first, and the 18a state tests revert at the `abi.decode` boundary before reaching their storage assertions. What *is* known: at N=1 storage is provably uncorrupted (`test__unit__batchOfOneEqualsSingleCall` passed under M6). M6's primary observable is return corruption.

## Deviations from Plan

**1. [Rule 2 — missing critical coverage] Added an 8th test, `test__unit__oneAndTwoElementReturnsAreByteExact`.** The plan's `<behavior>` block specifies N=1 → 128 bytes and N=2 → 192 bytes against the module, but its 7 named tests pinned 128/192 only on the **oracle** side (`abi.encode(...).length`), which pins solc rather than the encoder. The fuzz covered N=1/N=2 only probabilistically, with no named anchor. Added a module-side test covering both. It immediately earned its keep: it is what produced the direct measurement of M3's N≤1 blindness. Suite is 8 tests, not 7.

**2. [Self-contradicting acceptance criteria — the 4th consecutive phase]** Three criteria were unsatisfiable as literals against content the same plan mandates:

- `grep -c 'abi.decode(r, (uint256))' == 0` — the only remaining occurrence is inside a comment the plan's own step B3 motivates, warning that this decode would now silently read the outer offset word. Resolved by verifying the **property**: both live decodes of `r` are `(BatchResult[])`; there is no live one-word decode path. The comment was kept, as it names the exact hazard for a future reader.
- `grep -c 'vm.assume' == 0` — the only occurrence was in a docstring *denying* the use of `vm.assume`. Here the file's own 18a header already avoids the literal string ("assumption-based input filtering is banned outright"), so the docstring was reworded to that established in-file idiom. Now genuinely 0, with no loss of meaning.
- `grep -c 'return-bytes clause carried to 18b' == 1` — this one contradicts its **own task**. The phrase existed on exactly one line: the MCAL-06 traceability row, which step D1.4 of the same task explicitly orders changed to `Complete`. Satisfying the grep would require disobeying D1.4. Resolved in favour of the stated property — *"the historical 18a-01 PARTIAL note is PRESERVED (it is the audit trail); only the traceability TABLE row loses the caveat."* Verified: the `[18a-01 PARTIAL — read before closing this in 18b]` note and its "Phase 18b owns that clause" wording are both intact, with an `[18b-01 DISCHARGED]` sub-bullet appended beneath. The audit trail is richer than before, not diminished.

None was resolved by contorting code to satisfy a grep.

**3. [Toolchain] `gsd-tools` not used for the doc updates.** As the plan warned, it cannot parse the `18b` phase suffix and `update-progress` clobbers STATE.md's frontmatter to milestone `v2.0`. D1–D3 were made by hand with Edit; `milestone: v4.0` verified intact after committing.

**4. NatSpec collision (minor, fixed inline).** `@malloc_zeroed` / `@malloc_uninit` inside `///` comments are parsed by solc as documentation tags — `Error (6546): Documentation tag @malloc_zeroed. not valid for functions`. Dropped the leading `@` in those two prose references.

## Requirements Discharged

- **MCAL-05** → Complete. Traceability row updated.
- **MCAL-06's carried return-bytes clause** → **DISCHARGED**. `N = 0` returns exactly 64 bytes (offset `0x20`, length `0`), never reverts, `abi.decode` yields a zero-length array — verified from both a fresh and a seeded (C=5) counter, and falsifiable (M2 reddens it). The traceability row drops its caveat; the historical 18a-01 PARTIAL note is **preserved** as audit trail, with an `[18b-01 DISCHARGED]` sub-bullet appended beneath it.

## CARRY-FORWARD — Phase 19 and peer `mv15a18k` (rpc_api / StochasticOrderGen)

**This is a consumer-side contract, not a test detail.** `create_orders(uint256,uint256[])` → `0x81357911` returns:

```
byte   0   0x20              outer offset word to the array
byte  32   N                 length in ELEMENTS (never in bytes)
byte  64   success[0]        EXACTLY 0 or 1
byte  96   orderId[0]        0 when success[0] is 0
byte 128   success[1]        ... stride 0x40, static tuples, NO per-element offsets
TOTAL = 64 + 64*N            N=0 -> 64, N=1 -> 128, N=2 -> 192, N=3 -> 256, N=128 -> 8256
```

Two clauses most likely to break a Haskell decoder:

1. **N = 0 RETURNS 64 BYTES, NOT ZERO AND NOT 32.** A zero-arrival Poisson tick is an in-distribution sample, not an error — the governing principle is *structurally impossible → revert; semantically empty → well-formed empty result*. A decoder that equates "empty batch" with "empty returndata" will revert **in the client**, and this failure is **invisible on-chain**: nothing reddens here. This is the single clause most likely to break `StochasticOrderGen`.

2. **CANONICAL BOOLS ARE A DIVERGENCE RISK, MEASURED.** Success words are exactly 0 or 1. Under the `success = 2` mutant, solc's `abi.decode` **reverts outright** (observed: the whole 18a suite went `EvmError: Revert`), while a lenient Haskell decoder would accept a truthy 2 and proceed. The two consumers would then disagree about identical bytes. If the Haskell side decodes bools leniently, that leniency is a latent integration bug even though the Plank side is currently canonical.

Also still binding from 18a: the **canonical array offset `0x40` at byte 36** is a hard requirement on the *input* side — a bespoke encoder that legally pads the head is rejected with an empty revert.

For Phase 19 (MVER-01): the `BatchResult` struct and `expectedReturn()` helper in `VolOrderManagerBatch.t.sol` are the reusable oracle surface. **`expectedReturn` must stay a bare `abi.encode` call** — the moment it grows a manual mstore or a hand-computed offset, the differential compares the module against a restatement of itself and becomes vacuous.

## Self-Check: PASSED

- `src/modules/pos_spec/VolOrderManagerMod.plk` — FOUND, sha256 `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787` (restored identical after all 7 mutation attempts)
- `test/pos_spec/VolOrderManagerBatch.t.sol` — FOUND, 8-test `VolOrderManagerReturnEncodingTest` present
- `Makefile` — FOUND, `test-vol-order-return` target present and in `.PHONY`
- Commits `84c7af2`, `cf72c41` — verified present in `git log`
- `.planning/STATE.md` — `milestone: v4.0` intact after hand edits
</content>
</invoke>
