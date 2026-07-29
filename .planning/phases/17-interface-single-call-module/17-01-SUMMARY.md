---
phase: 17-interface-single-call-module
plan: 01
subsystem: pos_spec / vol-order registry
tags: [plank, evm, storage, selectors, mutation-testing, VORD-01, VORD-03, VORD-04, VORD-05]
requires:
  - lib::pos_spec::VolOrderValidationLib (build_vol_order, validate_order_strict)  # Phase 16
  - pos_spec::VolOrder::pack_vol_order                                            # vol-type track
  - v3::storage::array_slot                                                       # plankified-univ3
  - std::constructor::return_runtime, v3::util::{return_u256, revert_empty}
provides:
  - "create_order(uint88,uint24,uint16) = 0x6501fe94 -- live, CALLED-green registry entrypoint"
  - "orderCount() = 0x2453ffa8, getOrderPacked(uint256) = 0xa9bcabc1 -- CALLED-green readers"
  - "create_orders(uint256,uint256[]) = 0x81357911 -- selector PINNED, dispatch deferred to 18a"
  - "SLOT_ORDER_COUNT / SLOT_ORDERS_BASE keccak-derived slot layout"
  - "make test-vol-order-manager"
affects:
  - Phase 18a (batch composes this call chain N times; must re-run mutant M5)
  - Phase 19 (differential + consumer fixture)
  - rpc_api Haskell StochasticOrderGen consumer (PR #9) -- selector + id/slot contract
tech-stack:
  added: []
  patterns:
    - "VegaAccountMod dispatch idiom mirrored verbatim (init/return_runtime, @evm_shr(224,...) selector, else-if chain, revert_empty fallthrough)"
    - "Interface file pins signature strings consumed by module, Solidity test ABI, and the Haskell consumer"
    - "Guards asserted ON STATE via raw vm.load, never on return data"
    - "Mutation gate: apply -> clear cache/fuzz -> observe RED -> restore -> sha256-verify -> green"
key-files:
  created:
    - src/interfaces/pos_spec/VolOrderManagerInterface.plk
    - src/modules/pos_spec/VolOrderManagerMod.plk
    - test/pos_spec/VolOrderManager.t.sol
    - .planning/phases/17-interface-single-call-module/deferred-items.md
  modified:
    - Makefile
decisions:
  - "array_slot's CHECKED add caps the addressable id space at 2^256-1-keccak(base); pinned as a value rather than worked around"
  - "M5 (counter store hoisted above validation) is an equivalence-checked NON-KILL in the strict path; becomes non-equivalent in Phase 18a"
  - "PLANK_SKIP stays EMPTY -- a module that compiles never enters the rescue queue"
metrics:
  duration_min: 11
  tasks: 4
  tests_added: 12
  files_created: 4
  files_modified: 1
  completed: 2026-07-20
---

# Phase 17 Plan 01: Interface & Single-Call Module Summary

`create_order(uint88,uint24,uint16)` is a live, CALLED-green vol-order registry entrypoint over
FFI-deployed Plank bytecode — monotonic ids from 1, unmasked derived-slot storage, state-asserted
reverting guard, both readers with a sound 0-sentinel, both entrypoint selectors `cast sig`-pinned,
and a four-mutant observed-RED gate with one documented equivalence-checked non-kill.

## What Was Built

| Artifact | Role |
| --- | --- |
| `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | Four selector constants, each with its exact Solidity signature string in a `// signature::` comment |
| `src/modules/pos_spec/VolOrderManagerMod.plk` | Dispatch, id assignment, derived-slot store, two readers. ZERO domain arithmetic |
| `test/pos_spec/VolOrderManager.t.sol` | 12 tests across 5 contracts — the CALLED-green module suite |
| `Makefile` | `test-vol-order-manager` target + `.PHONY`; baseline comment updated to measured counts |

The module delegates every domain operation: `build_vol_order` (pins `TICK_SPACING = 20`),
`validate_order_strict` (reverting wrapper), `pack_vol_order` (152-bit packer), `array_slot`
(`keccak256(base) + index`, unmasked). The only arithmetic in the file is `+ 1`.

## Constants — recomputed at execution time

All six reproduced **exactly** the planner's cross-check values. **No discrepancies.**

```
$ cast sig "create_order(uint88,uint24,uint16)"
0x6501fe94
$ cast sig "create_orders(uint256,uint256[])"
0x81357911
$ cast sig "orderCount()"
0x2453ffa8
$ cast sig "getOrderPacked(uint256)"
0xa9bcabc1
$ cast keccak "VolOrderManagerMod.orderCount"
0x92967cb44e7866428adae18aad4bf59a10fb8d4c189b2b0e8bfe6f2a2469b5c7
$ cast keccak "VolOrderManagerMod.orders"
0x68fef5d6c1ef01f93bf897a4ffcaa37fbdc39061144008f6edd91f64b7b199cb
```

Each `// signature::` comment was machine-paired against the constant on the following line:

```
create_order(uint88,uint24,uint16) ||| const SELECTOR_CREATE_ORDER = 0x6501fe94;
create_orders(uint256,uint256[])   ||| const SELECTOR_CREATE_ORDERS = 0x81357911;
orderCount()                       ||| const SELECTOR_ORDER_COUNT = 0x2453ffa8;
getOrderPacked(uint256)            ||| const SELECTOR_GET_ORDER_PACKED = 0xa9bcabc1;
```

## Verbatim PASS lines (all 12, `runs: 256` on the fuzz)

```
[PASS] test__unit__scalarSlotFarFromOrdersRegion() (gas: 1309)
[PASS] test__unit__selectorsMatchTheirSignatureStrings() (gas: 1462)
[PASS] test__unit__slotConstantsMatchTheirPreimages() (gas: 1150)
[PASS] test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt() (gas: 61674)
[PASS] test__unit__invalidSkewRevertsAndLeavesStateUntouched() (gas: 16000)
[PASS] test__unit__getOrderPackedNonexistentReturnsZeroWithoutReverting() (gas: 68245)
[PASS] test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates() (gas: 11805)
[PASS] test__unit__readersReturnStoredValues() (gas: 88063)
[PASS] test__unit__batchSelectorNotYetDispatched() (gas: 8803)
[PASS] test__fuzz__validTupleStoresExactPackedWord(uint256,uint256,uint256) (runs: 256, μ: 57808, ~: 57861)
[PASS] test__unit__idAt65536IsNotMaskedIntoSlotZero() (gas: 34298)
[PASS] test__unit__sequentialIdsOneThenTwo() (gas: 88380)

Ran 5 test suites: 12 tests passed, 0 failed, 0 skipped (12 total tests)
```

## Mutation Gate

Baseline sha256 (recorded before any mutation, and re-verified after **every** restore):

```
171c840493a20c8dc6133eea281ff017055b34404032a530540c98667c31c2eb  src/modules/pos_spec/VolOrderManagerMod.plk
```

`rm -rf cache/fuzz` was run before every mutant execution. One mutant applied at a time.

### M1 — ring index mask reintroduced — **KILLED**

```diff
-        @evm_sstore(array_slot(SLOT_ORDERS_BASE, id), pack_vol_order(order));
+        @evm_sstore(array_slot(SLOT_ORDERS_BASE, id & 0xFFFF), pack_vol_order(order));
```

```
[FAIL: order 65536 stored at the UNMASKED slot keccak(base)+65536: 0 != 204169420558211270151058172938006761635917] test__unit__idAt65536IsNotMaskedIntoSlotZero() (gas: 33779)
Ran 5 test suites: 11 tests passed, 1 failed, 0 skipped (12 total tests)
```

**Killed by exactly ONE test**, and this is the load-bearing observation of the whole gate:
`test__unit__sequentialIdsOneThenTwo` stayed **GREEN** under M1, as did all 10 other tests. The
mask is a *no-op* at the ids those tests exercise (`1 & 0xFFFF == 1`, `2 & 0xFFFF == 2`); it only
bites at 65536, where it folds the order onto slot 0. Without
`test__unit__idAt65536IsNotMaskedIntoSlotZero`, M1 would have been recorded as "killed" while
nothing actually caught it. **The small-id tests alone were provably insufficient** — that is now
evidence, not an argument.

Restored: `171c8404…c2eb` (matches baseline). Post-restore: 12 passed, 0 failed.

### M2 — validation deleted — **KILLED**

```diff
-        validate_order_strict(order);
```

```
[FAIL: next call did not revert as expected] test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt() (gas: 79031)
[FAIL: next call did not revert as expected] test__unit__invalidSkewRevertsAndLeavesStateUntouched() (gas: 53736)
Ran 5 test suites: 10 tests passed, 2 failed, 0 skipped (12 total tests)
```

Both guard tests reddened, as predicted: `skew = 65535` and `skew = 0` are now ACCEPTED.

Restored: `171c8404…c2eb`. Post-restore green.

### M3 — scalar slot aliased onto the orders region — **KILLED**

`keccak(SLOT_ORDERS_BASE) = 0xfe8e58c2…1694`, so the alias used is that `+ 1` — i.e. exactly the
order slot for id 1 (aliasing to `SLOT_ORDERS_BASE` itself would NOT collide, since `array_slot`
hashes the base again).

```diff
-const SLOT_ORDER_COUNT = 0x92967cb44e7866428adae18aad4bf59a10fb8d4c189b2b0e8bfe6f2a2469b5c7;
+const SLOT_ORDER_COUNT = 0xfe8e58c293f27cda1d48e9815907ebb30cf1519a9baf0214fb75d573bc6d1695;
```

```
[FAIL: id 1 stores the exact submitted tuple: 1 != 204169420558211270151058172938006761635917] test__unit__sequentialIdsOneThenTwo() (gas: 36341)
[FAIL: the pre-existing order is untouched: 1 != 204169420558211270151058172938006761635917] test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt() (gas: 39232)
[FAIL: orderCount() == raw counter slot: 2 != 0] test__unit__readersReturnStoredValues() (gas: 64440)
[FAIL: id 65536 assigned: 1 != 65536] test__unit__idAt65536IsNotMaskedIntoSlotZero() (gas: 32589)
[FAIL: fuzz: exact packed word: 1 != 1318934454591205676457073386884479130145002; ...] test__fuzz__validTupleStoresExactPackedWord(uint256,uint256,uint256) (runs: 0, ...)
Ran 5 test suites: 7 tests passed, 5 failed, 0 skipped (12 total tests)
```

The order-1 word is written first and then **overwritten by the counter**, so the raw slot reads
`1` instead of the packed word — precisely the predicted failure.

**Stated limitation:** `test__unit__scalarSlotFarFromOrdersRegion` stayed **GREEN** under M3,
because it asserts the real preimage-derived constants rather than the module's edited literal. It
DOCUMENTS the invariant; M3 is what proves a violation is OBSERVABLE. This limitation is written
into the test's own natspec so it cannot be over-read later.

*On the fuzz `runs: 0` here:* `cache/fuzz` was removed immediately before this run, so this is not
a replay — under M3 the very first drawn input fails, and Foundry reports the count of *successful*
runs before failure. The non-fuzz anchors (`sequentialIdsOneThenTwo`) carry the kill regardless.

Restored: `171c8404…c2eb`. Post-restore green.

### M4 — id base off by one (`+ 1` dropped) — **KILLED**

```diff
-        let id = @evm_sload(SLOT_ORDER_COUNT) + 1;
+        let id = @evm_sload(SLOT_ORDER_COUNT);
```

```
[FAIL: orderCount advances 0->1: 0 != 1] test__unit__sequentialIdsOneThenTwo() (gas: 37216)
[FAIL: precondition: one live order: 0 != 1] test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt() (gas: 36312)
[FAIL: id 1 now exists and its word is nonzero] test__unit__getOrderPackedNonexistentReturnsZeroWithoutReverting() (gas: 47213)
[FAIL: order 1 tuple: 0 != 204169420558211270151058172938006761635917] test__unit__readersReturnStoredValues() (gas: 49501)
[FAIL: id 65536 assigned: 65535 != 65536] test__unit__idAt65536IsNotMaskedIntoSlotZero() (gas: 32624)
[FAIL: every in-range tuple is accepted: 0 != 1; ...] test__fuzz__validTupleStoresExactPackedWord(uint256,uint256,uint256) (runs: 0, ...)
Ran 5 test suites: 6 tests passed, 6 failed, 0 skipped (12 total tests)
```

The direct falsifier of the 0-sentinel soundness argument: the first order lands at
`orderSlot(0)` and the counter never advances.

Restored: `171c8404…c2eb`. Post-restore green.

### M5 — counter store hoisted above validation — **EQUIVALENCE-CHECKED NON-KILL (not counted)**

```diff
         // VALIDATE FIRST. ...
+        let id = @evm_sload(SLOT_ORDER_COUNT) + 1;
+        @evm_sstore(SLOT_ORDER_COUNT, id);
         validate_order_strict(order);
...
-        let id = @evm_sload(SLOT_ORDER_COUNT) + 1;
         @evm_sstore(array_slot(SLOT_ORDERS_BASE, id), pack_vol_order(order));
-        @evm_sstore(SLOT_ORDER_COUNT, id);
```

```
Ran 5 test suites: 12 tests passed, 0 failed, 0 skipped (12 total tests)
```

**The green is CORRECT, not a test weakness.** In the strict single-call path
`validate_order_strict` REVERTS on an invalid tuple, and a revert rolls back **every** prior
`SSTORE` in the same call frame. The hoisted counter store is therefore unobservable on-chain:
baseline and mutant have identical observable behaviour under every input. Not counted among the
kills; no test was weakened to manufacture one. **M2 is the non-equivalent witness of the same
property** ("orderCount must not advance on failure") and it is an observed RED.

**HAND-OFF TO PHASE 18a — this mutant becomes NON-equivalent there.** The batch calls
`validate_order` (the bool core) and **SKIPS** an invalid tuple rather than reverting, so there is
no rollback: a hoisted counter store would advance the id on a *skipped* tuple, burning ids and
creating gaps. **Phase 18a MUST re-run this exact mutant and expect a RED.**

### Gate summary

| Mutant | Target | Result | Primary kill site |
| --- | --- | --- | --- |
| M1 | ring mask on id | **RED** (1 test) | `idAt65536IsNotMaskedIntoSlotZero` — sole site |
| M2 | validation deleted | **RED** (2 tests) | both guard tests |
| M3 | scalar slot aliased | **RED** (5 tests) | `sequentialIdsOneThenTwo` |
| M4 | id `+1` dropped | **RED** (6 tests) | `sequentialIdsOneThenTwo` |
| M5 | counter store hoisted | GREEN — equivalence-checked, **NOT counted** | n/a (revert rollback) |

**4 observed kills, 1 documented equivalence.** Source restored sha256-identical after every
mutant; `git status --porcelain src/modules/pos_spec/VolOrderManagerMod.plk` is empty.

## Deviations from Plan

### 1. [Rule 1 — Bug, in the PLAN's assertion] `getOrderPacked(type(uint256).max)` does NOT return 0 — it reverts

**Found during:** Task 2.

The plan mandated `assertEq(mgr.getOrderPacked(type(uint256).max), 0, ...)`. It **FAILED**:

```
[FAIL: panic: arithmetic underflow or overflow (0x11)] test__unit__getOrderPackedNonexistentReturnsZeroWithoutReverting()
  ├─ [414] 0x5615…::getOrderPacked(115792089237316195423570985008687907853269984665640564039457584007913129639935) [staticcall]
  │   └─ ← [Revert] panic: arithmetic underflow or overflow (0x11)
```

**Cause (MEASURED, from the deployed bytecode trace, not inferred):**
`v3::storage::array_slot(base, index)` is `keccak256(base) + index`, and **Plank's `+` is CHECKED**
— it emits the Solidity `0x11` panic rather than wrapping. So the addressable id space is bounded:

```
keccak(SLOT_ORDERS_BASE) = 0xfe8e58c293f27cda1d48e9815907ebb30cf1519a9baf0214fb75d573bc6d1694
MAX_SAFE_ID = 2^256-1 - keccak(base)
            = 653120814479170674668838286535852690602904985755708879605137498879152023915
            ≈ 6.5e74   (the unreachable region is the top ~0.56% of the id space)
```

**Resolution — the property was verified, not the literal criterion.** VORD-05's real content is
"no revert path for a nonexistent id", so consumers can probe safely. That holds for **every
reachable id**: ids come from a `+1`-per-transaction counter, so nothing in this universe reaches
6.5e74 — the same compile-time-value argument that licenses the `>2^64` slot-distance claim.

**Not "fixed", deliberately.** `array_slot` belongs to the plankified-univ3 track (must not
modify), and masking the id module-side is *exactly* the ring-mask corruption M1 exists to forbid.

Instead the boundary is now **pinned as a value** by a new test,
`test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates`, which asserts
`keccak(base) + MAX_SAFE_ID == 2^256-1`, that `MAX_SAFE_ID` itself returns the 0 sentinel, and that
`MAX_SAFE_ID + 1` reverts. If `array_slot` ever switches to an unchecked add, or a preimage
changes, the change is caught rather than silently altering the module's revert surface. The
original test now probes `MAX_SAFE_ID` and `1 << 128` instead of `type(uint256).max`.
**Phase 18a/19 and the rpc_api consumer inherit this bound.**

### 2. [Plan-internal contradiction — resolved, per the Phase-16 lesson] Task 1 AC-7 arithmetic grep

The criterion asserts the grep returns `1`. It returns **`2`**. The second match is
`import interfaces::pos_spec::VolOrderManagerInterface::*;` — the `*` glob in the wildcard import,
which is **mandated by the plan's own module template**, matched by the criterion's own `[+*/-]`
character class. (The plan anticipated a possible `2` from `@evm_shr`, but `@evm_shr` is not in its
alternation — that was not the cause.)

Not silently resolved in either direction. The property AC-7 exists to establish is **zero DOMAIN
arithmetic**; a module-root glob is not an arithmetic operator. Verified with the import lines
excluded as well:

```
$ grep -vE '^[[:space:]]*//' …/VolOrderManagerMod.plk | grep -vE '^[[:space:]]*import' | grep -cE '[+*/-]|<<|>>|@evm_(add|sub|mul|div|shl)'
1
$ … same, with -n
16:        let id = @evm_sload(SLOT_ORDER_COUNT) + 1;
```

**Exactly one arithmetic line, and it is the id `+ 1`.** Both matching lines named, as required.

### 3. [Same class] Task 2 AC-4 `vm.assume` grep

Returns `2`, not `0`. Both matches are **comments stating the rule itself** (lines 24 and 145:
"no vm.assume anywhere", "never vm.assume") — content the plan mandated. With comments excluded
the count is **`0`**: there is no `vm.assume` in any executable line.

### 4. [Same class] Task 2 AC-5 preimage-derivation grep

Returns `3`, not `2`. The third occurrence is the new `MAX_SAFE_ID` constant, which derives the
orders-region address from the same preimage string rather than hardcoding it. The criterion's
intent (slot addresses derived, never hardcoded hashes) is satisfied *more* strongly, not less.

### 5. [Out of scope — logged, NOT fixed] Flaky 5th failure in another track's file

`make test` intermittently reports **5** failures rather than 4. The extra one is
`TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`, always at the
same counterexample `2^64-1`, in `test/lib/pos_spec/` — **not** `src/types/pos_spec/`, and not one
of the 4 known reds.

**Proven pre-existing.** With all three 17-01 files stashed out of the tree and a cold
`cache/fuzz`, the baseline reported **86 passed, 5 failed**, including this counterexample at
`runs: 127` (a genuine fresh discovery, not a cached replay). Measured over 4 cold-cache runs with
17-01 present: 96/4, **95/5**, 96/4, 96/4. In isolation it passed 3/3 at `runs: 256`. Foundry seeds
each campaign randomly, so whether the fuzzer reaches `2^64-1` varies run to run.

Logged to `deferred-items.md` (D1) and recorded in the Makefile baseline comment. Not fixed: it
belongs to another track and is unrelated to anything 17-01 touches.

**Consequence for the recorded baseline:** STATE.md's `87 pass / 4 fail` is the *modal* cold-cache
result, reproduced exactly by 17-01 (`87 + 12 = 99 pass / 4 fail`), but it is **not deterministic**.
Anyone gating on "exactly 4 failures" should re-run before calling a 5th a regression.

## Measured Counts

| Command | Baseline (16-01) | After 17-01 |
| --- | --- | --- |
| `make compile-plank` | 12 ok, 0 failed, 0 skipped | **13 ok, 0 failed, 0 skipped** |
| `make test` (cold cache, modal) | 87 pass, 4 fail | **99 pass, 4 fail** |
| `make test-vol-order-manager` | n/a | **12 pass, 0 fail, 0 skipped** |

`PLANK_SKIP` remains **empty** — the module compiles from the start, and a compiling module never
belongs in the rescue queue (MVER-04, corrected at `af488a0`).

`git status --porcelain src/types/pos_spec/ test/types/pos_spec/` → **empty** after every task.
The vol-type track's files, including the `return_split_tick` bug we diagnosed but must not fix,
are byte-untouched.

## Success Criteria

| SC | Status |
| --- | --- |
| SC-1 (VORD-01/04) — create_order CALLED, `orderCount` 0→1, raw `vm.load` decodes the exact tuple with `tickSpacing == 20` | MET — `sequentialIdsOneThenTwo`, field-by-field, no getter trusted |
| SC-2 (VORD-01/03) — `skew=65535` REVERTS leaving state untouched; second order gets id 2 in the same test; no 16-bit mask | MET — both guard tests + `idAt65536IsNotMaskedIntoSlotZero` |
| SC-3 (VORD-05/03) — both readers CALLED; `getOrderPacked` nonexistent → 0, no revert; sentinel soundness in-code | MET, **with the measured `MAX_SAFE_ID` bound** (Deviation 1) |
| SC-4 (VORD-04) — both entrypoint selectors `cast sig`-recomputed; `\|S - keccak(base)\| > 2^64` asserted as a value | MET — plus a third test pinning the slot literals to their preimages |
| SC-5 (VORD-03/04) — 4 observed REDs; hoisted-counter documented equivalence-checked; source restored sha256-identical | MET |

## What Phase 18a Inherits

1. **The call chain to reuse verbatim:** `build_vol_order` → `validate_order` (the **bool core**,
   not `_strict` — the batch SKIPS rather than reverts) → `pack_vol_order` → `array_slot`.
   `TICK_SPACING = 20` stays pinned in exactly one place.
2. **The pinned batch selector:** `create_orders(uint256,uint256[]) = 0x81357911`, already declared
   in the interface file and currently falling through to `revert_empty()` — a fact locked by
   `test__unit__batchSelectorNotYetDispatched`, which will need updating when 18a dispatches it.
3. **M5 becomes NON-equivalent.** Re-run the hoisted-counter mutant and **expect a RED**: with skip
   semantics there is no revert rollback, so a hoisted store advances the id on a skipped tuple.
4. **`MAX_SAFE_ID` bound:** ids are addressable only up to `2^256-1 - keccak(SLOT_ORDERS_BASE)`
   because `array_slot`'s add is checked. Unreachable in practice; relevant to any batch that
   accepts caller-supplied ids.
5. **Storage layout:** `orderCount` at `keccak("VolOrderManagerMod.orderCount")`, orders at
   `keccak(keccak("VolOrderManagerMod.orders")) + id`, ids from 1, slot `+0` permanently zero.
6. **Test-file discipline:** `test/pos_spec/VolOrderManager.t.sol` is this surface's single file;
   `--match-path` targets stay disjoint from the vol-type track's reds.

## Self-Check: PASSED

All created files verified present on disk; all commit hashes verified in `git log`.
