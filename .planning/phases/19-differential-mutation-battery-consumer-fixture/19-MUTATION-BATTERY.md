# Phase 19 — Observed-RED Mutation Battery (MVER-02)

**Every entry below was OBSERVED on the CURRENT tree on 2026-07-21.**
**No kill is cited from a prior phase.** Prior kills are historical facts about older code, not
evidence about this tree. Phase 18b changed the return type of `create_orders` — the surface
several of these mutants traverse — and plans 19-01 and 19-02 added new suites that are themselves
candidate kill sites. Every observation here was re-taken from scratch.

The EDIT TEXT of a mutant may be reused from a prior phase. The OBSERVATION never is.

## Protocol applied identically to every mutant

1. `sha256sum <file>` → PRE hash, confirmed equal to baseline.
2. `cp <file> /tmp/mut_backup_<name>.plk`
3. Apply the mutant edit exactly as specified.
4. `rm -rf cache/fuzz` — MANDATORY. A `runs: 0` line is a cache replay, not a kill; such an
   observation is void.
5. Run the named command, capture stdout.
6. Record the VERBATIM `[FAIL: ...]` line and the tallies.
7. Restore from backup.
8. `sha256sum <file>` → MUST equal the PRE hash.
9. Re-run and confirm GREEN.

All forge runs use `--via-ir --optimize`. There is **no `--skip` flag** — it was removed from all
nine Makefile recipes at commit `8b11d73`. Prior phases' documented commands are stale on this point.

## Baselines (measured at the start of this plan, matching 18b)

```
be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787  src/modules/pos_spec/VolOrderManagerMod.plk
5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35  src/lib/pos_spec/VolOrderValidationLib.plk
```

**GREEN BASELINE**, cold fuzz cache:

```
Ran 15 test suites in 5.57s (6.73s CPU time): 40 tests passed, 0 failed, 0 skipped (40 total tests)
```

All fuzz suites reported `runs: 256`. No `runs: 0` line appeared.

---

# PART A — The four semantic mutants

## M1a — DELETED VALIDATION BRANCH (batch path)

**File:** `src/modules/pos_spec/VolOrderManagerMod.plk:233`
**PRE sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`

**Edit applied — form (i) of the plan's fallback list was NOT needed; the primary form compiled:**

```diff
-            if validate_order(order) {
+            if 1 == 1 {
                 id = id + 1;
```

`if 1 == 1 {` COMPILED. No fallback form was required.

**Result: KILLED — 9 tests red.**

```
Ran 15 test suites in 157.47ms (916.31ms CPU time): 31 tests passed, 9 failed, 0 skipped (40 total tests)
```

VERBATIM FAIL LINE (the batch state kill site):

```
[FAIL: returns the success count: 3 != 2] test__unit__mixedBatchFootprintAndContiguity() (gas: 84139)
```

VERBATIM FAIL LINE (dirty-high-bits):

```
[FAIL: no tuple succeeded: 1 != 0] test__unit__dirtyHighBitsAreSkippedNotStored() (gas: 57515)
```

VERBATIM FAIL LINE (all-invalid return encoding):

```
[FAIL: three failures encode as three (false, 0) tuples: 0x6c24c9533ab283b90f45d4308a18871d693a1a3f83c7d68b30390777a632fc4a != 0xde4345bd42845a40a82f586395eff7b17e6581536d9ed3f4484b09fc9fb7a5d7] test__unit__allInvalidBatchReturnsAllFalseZero() (gas: 106382)
```

VERBATIM FAIL LINE — **19-01's NEW differential** (wave-1 test appearing as a kill site):

```
[FAIL: step 2 mixed batch: return bytes module vs abi.encode(mock results), tol 0: 0x9520ecea1dca5f78ac0528565d04deb5f899ca0e1ccdf09baf31a81428274894 != 0x5dddf750de5b7dba85e71aefa6e33feddf24709698be070df1e9ee502be7d26e] test__unit__fixedAnchorSequenceDiffers() (gas: 361573)
```

VERBATIM FAIL LINE — **19-02's NEW fixture** (wave-1 test appearing as a kill site):

```
[FAIL: N2_success_then_fail: module returndata vs cast(alloy) golden bytes, tol 0: 0xc3e8d18808bea2130e136e839c9663b0ea714e2c11f41041a1c21ff01b6d67f8 != 0x687b035064ddcdbbe1dc24bfff969cc988a49988bee2f455a959914c2538f359] test__unit__moduleReturnMatchesExternalEncoderFixture() (gas: 1691543)
```

Also red: `test__unit__mixedBatchReturnIsByteExact`, `test__fuzz__returnBytesMatchStandardEncoder`,
`test__fuzz__batchNeverReverts`, `test__fuzz__randomSequenceDiffers`.

### THE RED IS A VALUE/STATE RED, NOT A REVERT — 18a's prediction HELD

The plan asked this to be checked as a PREDICTION, not assumed. **CONFIRMED: no `EvmError: Revert`
appeared anywhere in the M1a output.** Every red is a value, count or byte-comparison red.
`test__unit__batchOfOneEqualsSingleCall` and `test__unit__emptyBatchIsNoOp` stayed GREEN, and the
totality fuzz failed on a COUNT assertion (`15 != 6`) rather than on a revert.

This CORROBORATES the MCAL-04 structural enumeration on the current tree: M1a drove arbitrary
unvalidated tuples through the entire post-validation store path and produced no revert, so no
step's totality was contradicted. **There is NO MCAL-04 finding here.**

### Contiguity was NOT the discriminating red, and that is expected for M1a (not for M3)

`test__unit__mixedBatchFootprintAndContiguity` reddened on its COUNT assertion (`3 != 2`), not on
contiguity. That is correct under M1a and is not the weakness 18a warned about: M1a makes *every*
tuple succeed, so the ids stay contiguous — there is no gap to detect. Contiguity is the
discriminating red for M3 (count-advance-on-failure), where a skipped tuple consumes an id. See M3.

### FINDING — `runs: 0` here is a FIRST-INPUT failure, not a cache replay

The plan voids any observation containing `runs: 0`, on the grounds that it indicates a warm-cache
replay. **That inference does not hold here, and I measured the difference rather than asserting it.**

`cache/fuzz` was removed and its absence verified (`ls: cannot access 'cache/fuzz': No such file or
directory`) before re-running the totality fuzz alone. It failed again at `runs: 0` but with a
**DIFFERENT counterexample**:

```
run 1:  args=[7, 132, 6381]
run 2:  args=[309485009821345068724781055 [3.094e26], 1759, 200]
```

A cache replay reproduces the SAME counterexample by construction. Two different counterexamples
from a provably absent cache establish that the fuzzer searched fresh and failed on its first
generated input — which is unsurprising for a mutant that makes *every* tuple succeed. `runs: 0` is
forge's index of the failing run, and index 0 is a legitimate kill.

**The acceptance criterion `grep -c 'runs: 0'` == 0 is therefore not satisfiable for any mutant broad
enough to be killed by the first fuzz input, and it conflates two distinct meanings of `runs: 0`.**
The criterion's underlying property — that no kill rests on a replayed corpus — is verified instead
by (a) the cleared-cache/different-counterexample measurement above and (b) the fact that M1a's kill
stands entirely on NON-FUZZ anchors (`test__unit__mixedBatchFootprintAndContiguity`,
`test__unit__dirtyHighBitsAreSkippedNotStored`, `test__unit__allInvalidBatchReturnsAllFalseZero`,
`test__unit__fixedAnchorSequenceDiffers`, `test__unit__moduleReturnMatchesExternalEncoderFixture`),
which are cache-independent by construction. Discard every fuzz result and M1a is still killed 5
times over.

**POST-RESTORATION sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787` — EQUAL to PRE.
**Post-restoration suite:** `40 tests passed, 0 failed, 0 skipped (40 total tests)` — GREEN.

---

## M1b — DELETED VALIDATION BRANCH (strict path)

**File:** `src/modules/pos_spec/VolOrderManagerMod.plk:77`
**PRE sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`

**Edit applied** — the line deleted:

```diff
-        validate_order_strict(order);
```

**Result: KILLED — 4 tests red.**

```
Ran 15 test suites in 193.24ms (1.20s CPU time): 36 tests passed, 4 failed, 0 skipped (40 total tests)
```

VERBATIM FAIL LINES (both predicted strict-path kill sites):

```
[FAIL: next call did not revert as expected] test__unit__invalidSkewRevertsAndLeavesStateUntouched() (gas: 53796)
```

```
[FAIL: next call did not revert as expected] test__unit__invalidSkewAfterAValidOrderDoesNotDisturbIt() (gas: 79204)
```

VERBATIM FAIL LINE — **19-01's NEW differential**, its `_singleExpectRevertBoth` step
(wave-1 test appearing as a kill site):

```
[FAIL: next call did not revert as expected] test__unit__fixedAnchorSequenceDiffers() (gas: 528945)
```

```
[FAIL: next call did not revert as expected; counterexample: calldata=0x36d6e44d000000000000000000000000000000000000000000000000000000000000520800000000000000000000000000000000000000000000000000000000000000dd00000000000000000000000000000000000000000000000000000000000008b2 args=[21000 [2.1e4], 221, 2226]] test__fuzz__randomSequenceDiffers(uint256,uint8,uint16) (runs: 3, μ: 19020427, ~: 5420045)
```

**No `runs: 0` line appeared in this observation** — the fuzz reported `runs: 3`, so no
cache-replay ambiguity arises here at all.

Note the CLEAN SEPARATION of the two halves of M1: M1b left every batch-path test GREEN (the batch
calls the bool core, not the reverting wrapper), exactly as the two-function split at 16-01 intends.
M1a and M1b are genuinely independent mutants and neither masks the other.

**POST-RESTORATION sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787` — EQUAL to PRE.
**Post-restoration suite:** `40 tests passed, 0 failed, 0 skipped (40 total tests)` — GREEN.

---

## M2 — MISSING STRIKE UPPER BOUND (silent truncation)

**File:** `src/lib/pos_spec/VolOrderValidationLib.plk:44` (a DIFFERENT file from the module —
backed up and restored separately)
**PRE sha256:** `5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35`

**Edit applied** — the AUTHORED half of the bound removed, leaving only the pre-existing `vol > 0`:

```diff
-      let res = tick_volatility_is_complete(self) & (self.vol <= MAX_STRIKE);
+      let res = tick_volatility_is_complete(self);
```

**Result: KILLED — but by ONE suite only, and NOT the one the plan predicted.**

### Observation (a) — `test/types/pos_spec/VolOrderValidation.t.sol` (Phase-16 pure-lib): RED

```
Ran 3 test suites in 45.23ms (97.81ms CPU time): 12 tests passed, 1 failed, 0 skipped (13 total tests)
```

VERBATIM FAIL LINE:

```
[FAIL: strike >= 2^88 must be REJECTED: 1 != 0] test__unit__strikeBoundBlocksSilentMasking() (gas: 14229)
```

This is a genuine CALLED kill, not a compile-level check: the suite reaches the predicate through
`deployPlank("test/types/pos_spec/VolOrderValidationHarness.plk")`, i.e. FFI-compiled deployed
bytecode. It is also NON-FUZZ, hence cache-independent by construction.

### Observation (b) — `test/pos_spec/*`: FULLY GREEN under the mutant

```
Ran 15 test suites in 3.78s (4.86s CPU time): 40 tests passed, 0 failed, 0 skipped (40 total tests)
```

**THE PLAN'S PREDICTION IS REFUTED — REPORT THIS.** The plan stated that 19-01's differential would
kill M2, on the reasoning that "the mock's `isValid` still applies `strike <= 0xFFFFFFFFFFFFFFFFFFFFFF`,
so an oversized strike makes module and mock disagree". **It does not, and cannot.** Measured causes,
both structural:

1. **No pos_spec test ever delivers an oversized strike to the module.** Every strike in the entire
   `test/pos_spec/` tree is generated as `uint88` and/or `bound(..., 1, type(uint88).max)`
   (`VolOrderManager.t.sol:151`, `VolOrderManagerBatch.t.sol:508,812`,
   `VolOrderManager.diff.t.sol:297,309,325`). The Solidity `uint88` type makes a strike ≥ 2^88
   structurally unrepresentable in the corpus. The one `2 ** 88` reference in the differential
   (`diff.t.sol:183`) is inside `test__unit__refMockSelfPin` and asserts against the **MOCK**, never
   against the module — so the mock's bound is pinned while the module is never asked the question.

2. **On the BATCH path M2 is genuinely EQUIVALENT, and no corpus could ever kill it there.** The
   module masks the strike at read time:

   ```
   let order = build_vol_order(
       @evm_shr(16, word) & 0xFFFFFFFFFFFFFFFFFFFFFF,   // <- masked to 88 bits BEFORE validation
   ```

   So `create_orders` cannot receive a strike above `MAX_STRIKE` no matter what calldata is supplied,
   and the `<= MAX_STRIKE` conjunct is **unreachable/dead code on the batch path**. This is a
   structural equivalence, not a corpus gap.

3. **On the STRICT path M2 is killable but UNKILLED.** `create_order` reads the strike with an
   unmasked whole-word `@evm_calldataload(4)` (deliberate — 18a's "dirty high bits are rejected by
   validation, not truncated" decision), so an oversized strike *does* reach validation there. No
   pos_spec test sends one.

### FINDING (coverage gap, NOT fixed here — this phase builds nothing)

**The strike bound's enforcement through the module's `create_order` ENTRYPOINT is unproven.** It is
proven only at the library predicate via the Phase-16 harness. A future regression that dropped the
bound would be caught by `test/types/pos_spec/`, but the registry's own CALLED surface has no
oversized-strike test on the strict path. Closing this needs a single `create_order` call with
`strike = (1 << 88) + 7` asserting a revert — deliberately NOT added here, since Phase 19 mutates and
observes rather than builds. Carried to the phase summary.

**M2 IS COUNTED AS A KILL** (observation (a) is a real, CALLED, non-fuzz RED). The batch-path
equivalence and the entrypoint coverage gap are recorded above rather than folded into the count.

**POST-RESTORATION sha256:** `5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35` — EQUAL to PRE.
**Post-restoration suite:** `13 tests passed, 0 failed, 0 skipped (13 total tests)` — GREEN.

---

## M3 — COUNT-ADVANCE-ON-FAILURE

**File:** `src/modules/pos_spec/VolOrderManagerMod.plk:231-234`
**PRE sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`

**Edit applied** — the id increment hoisted out of the success branch, so a SKIPPED tuple consumes an id:

```diff
             let base = 64 + 64 * i;
+            id = id + 1;
 
             if validate_order(order) {
-                id = id + 1;
                 @evm_sstore(...)
```

**Result: KILLED — 9 tests red.**

```
Ran 15 test suites in 173.11ms (922.98ms CPU time): 31 tests passed, 9 failed, 0 skipped (40 total tests)
```

VERBATIM FAIL LINE — **the CONTIGUITY red, which is the discriminating one**:

```
[FAIL: id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979] test__unit__mixedBatchFootprintAndContiguity() (gas: 66823)
```

The observation is the STRONG one, not the weak count-only variant. Slot C+2 holds ZERO because the
skipped middle tuple consumed the id and pushed valid_B to C+3. 18a's finding — forge reports only
the FIRST failing assertion per test, so `test__unit__mixedBatchFootprintAndContiguity` deliberately
orders contiguity BEFORE `orderCount` — is confirmed to still hold on the current tree: the
contiguity assertion is the one that surfaced.

Other verbatim reds:

```
[FAIL: orderCount unchanged by a skipped tuple: 1 != 0] test__unit__dirtyHighBitsAreSkippedNotStored() (gas: 36777)
```

```
[FAIL: no tuple was stored: 3 != 0] test__unit__allInvalidBatchReturnsAllFalseZero() (gas: 42483)
```

VERBATIM FAIL LINE — **19-01's NEW differential** (wave-1 kill site, as predicted):

```
[FAIL: step 2 mixed batch: return bytes module vs abi.encode(mock results), tol 0: 0x7aa8eb84742e74ce9a66d740bbc3adec72d9326fc04afd743a630a5d1bb01e91 != 0x5dddf750de5b7dba85e71aefa6e33feddf24709698be070df1e9ee502be7d26e] test__unit__fixedAnchorSequenceDiffers() (gas: 342086)
```

Its fuzz sibling reddened on the COUNT with an exact off-by-the-skip-count signature — 452 vs 450,
i.e. the module consumed 2 extra ids for 2 skipped tuples:

```
[FAIL: fuzz step 1 batch: orderCount module vs mock, tol 0: 452 != 450; counterexample: calldata=0x36d6e44d00000000000001d94f658b8fa8139a5da90ef05e297474fd31fcf6bae7abf6ba000000000000000000000000000000000000000000000000000000000000001b00000000000000000000000000000000000000000000000000000000000024f1 args=[2971015921295684745266700481383519480534277033986524747396794 [2.971e60], 27, 9457]] test__fuzz__randomSequenceDiffers(uint256,uint8,uint16) (runs: 0, μ: 0, ~: 0)
```

VERBATIM FAIL LINE — **19-02's NEW fixture, and the plan named the exact case in advance**
(`N3_mixed_seeded_C5`, whose golden bytes pin `(true,6)`, `(false,0)`, `(true,7)`; the mutant emits
`(true,6)`, `(false,0)`, `(true,8)`):

```
[FAIL: N3_mixed_seeded_C5: module returndata vs cast(alloy) golden bytes, tol 0: 0x4d1956f6a849688798be0f8aa4ceda23cbc07e92d0d17f6f87b7fa06dfc58805 != 0xddf3f6c74ec7e88090d96d277d18a346c47f3b15b7339111a1571ee3c702c5b6] test__unit__moduleReturnMatchesExternalEncoderFixture() (gas: 2291292)
```

Also red: `test__unit__mixedBatchReturnIsByteExact`, `test__fuzz__returnBytesMatchStandardEncoder`,
`test__fuzz__batchNeverReverts`. The two `runs: 0` fuzz lines are subject to the same first-input
analysis recorded under M1a; M3's kill rests entirely on NON-FUZZ anchors regardless.

**POST-RESTORATION sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787` — EQUAL to PRE.
**Post-restoration suite:** `40 tests passed, 0 failed, 0 skipped (40 total tests)` — GREEN.

---

## M4 — RING-MASK REINTRODUCTION

**File:** `src/modules/pos_spec/VolOrderManagerMod.plk:89` (strict) and `:235` (batch) — BOTH
`array_slot` call sites.
**PRE sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`

**Edit applied at both sites:**

```diff
-        @evm_sstore(array_slot(SLOT_ORDERS_BASE, id), pack_vol_order(order));
+        @evm_sstore(array_slot(SLOT_ORDERS_BASE, id & 0xFFFF), pack_vol_order(order));
```

**Result: KILLED — and the sole-kill-site claim is MEASURED, not asserted.**

### Observation (a) — the 65536 test: RED

```
[FAIL: order 65536 stored at the UNMASKED slot keccak(base)+65536: 0 != 204169420558211270151058172938006761635917] test__unit__idAt65536IsNotMaskedIntoSlotZero() (gas: 33892)
```

### Observation (b) — `VolOrderManagerBatchStateTest` under the SAME mutant: GREEN

```
Ran 2 tests for test/pos_spec/VolOrderManagerBatch.t.sol:VolOrderManagerBatchStateTest
[PASS] test__unit__dirtyHighBitsAreSkippedNotStored() (gas: 17278)
[PASS] test__unit__mixedBatchFootprintAndContiguity() (gas: 68230)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 24.39ms (299.21µs CPU time)
```

### Observation (c) — the FULL sweep under the same mutant: EXACTLY ONE RED IN FORTY

Stronger than the plan required, and worth the extra run:

```
Ran 15 test suites in 3.51s (4.43s CPU time): 39 tests passed, 1 failed, 0 skipped (40 total tests)
```

`test__unit__idAt65536IsNotMaskedIntoSlotZero` is the **only** failure. This is the measured proof
that small-id tests are provably insufficient: `1 & 0xFFFF = 1`, so the mask is a NO-OP below 65536
and only bites where an order folds onto slot 0. The test reaches id 65536 by `vm.store`-ing the
counter to 65535 rather than issuing 65536 transactions.

### HONEST NEGATIVE — wave 1 added NO new kill site for M4

Observation (c) now covers 19-01's differential and 19-02's fixture, and **both stayed GREEN**.
Unlike M1a, M1b and M3 — where wave-1 tests appeared as kill sites — neither new suite strengthens
coverage against M4, because both operate entirely at small ids. The 65536 test remains the single
point of failure for this property. Recorded so no later phase mistakes wave 1's breadth for
coverage of the ring-mask hazard.

**M4 IS COUNTED AS A KILL.** It is a real kill (the 65536 test genuinely reddens); it is only its
SMALL-ID observations that are equivalence-masked. That distinction is preserved in the ledger below
— entry 3 excludes small-id *observations*, not the mutant.

**POST-RESTORATION sha256:** `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787` — EQUAL to PRE.
**Post-restoration suite:** `40 tests passed, 0 failed, 0 skipped (40 total tests)` — GREEN.

---

</content>
</invoke>
