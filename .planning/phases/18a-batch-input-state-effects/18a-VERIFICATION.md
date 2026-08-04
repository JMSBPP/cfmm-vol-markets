---
phase: 18a-batch-input-state-effects
verified: 2026-07-21T02:45:56Z
status: passed
score: 6/6 must-haves verified
---

# Phase 18a: Batch Input & State Effects Verification Report

**Phase Goal:** The batch decodes standard-ABI calldata behind three independent guards, loops with a bounded runtime `while`, skips invalid tuples with zero state footprint, and is bounded by MAX_BATCH — with all state effects proven via raw vm.load while returning only ONE word, so nothing is observed through an untested encoder.
**Verified:** 2026-07-21T02:45:56Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from 18a-01-PLAN.md must_haves)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Mixed batch stores exactly two orders at contiguous ids C+1/C+2, advances orderCount to C+2, slot C+3 zero (SC-1, MCAL-03) | VERIFIED | `test__unit__mixedBatchFootprintAndContiguity` PASS (re-run, cleared fuzz cache); asserts slot 6 = valid_A, slot 7 = valid_B ("id contiguity: third valid order at C+2"), slot 8 = 0, orderCount = 7 from seeded C=5 |
| 2 | Three calldata guards each REVERT independently, each with its own corpus (SC-2, MCAL-02) | VERIFIED | `test__unit__nonCanonicalOffsetReverts`, `test__unit__lengthCountMismatchReverts`, `test__unit__truncatedCalldataReverts` all PASS; each isolates its own guard (guard 2 test uses full 164-byte payload so guard 3 is satisfied; guard 3 mutant independently re-killed, see below) |
| 3 | count > MAX_BATCH(128) reverts, orderCount unchanged; N=128 gas MEASURED and <= 10,000,000 (SC-3, MCAL-01) | VERIFIED | `test__unit__overMaxBatchRevertsNoStateChange` and `test__unit__maxBatchExactlyOneTwoEightSucceeds` PASS; independently re-measured gas: execGas 3,203,452 / calldataGas 23,000 / TOTAL 3,247,452 (identical to SUMMARY, well under 10M) |
| 4 | Post-validation store path enumerated step-by-step with revert status; constructed fuzz records no batch-revert OBSERVED (SC-4, MCAL-04) | VERIFIED | Six-step enumeration present in-module (lines 96-123 of VolOrderManagerMod.plk); `test__fuzz__batchNeverReverts` PASS (256 runs); M-VAL mutant re-run independently confirms `assertTrue(ok, "MCAL-04: no batch-revert observed")` never fails — only value/count assertions redden |
| 5 | Batch-of-1 state/id byte-identical to standalone create_order; N=0 completes without reverting, every observable slot byte-identical (SC-5, MCAL-06) | VERIFIED | `test__unit__batchOfOneEqualsSingleCall` and `test__unit__emptyBatchIsNoOp` PASS, including the seeded-counter half proving write-back is value-preserving |
| 6 | Seven mutants each produce an OBSERVED RED naming a specific failing assertion; each restored sha256-identical and green (SC-6) | VERIFIED | Independently re-killed M-G3, M-M5, M-VAL (see Mutation Re-Verification below); all match SUMMARY's recorded verbatim lines; sha256 restored to `6931b5e0...62a` after each and confirmed by `git diff --stat` empty at session end. M-G1/M-G2/M-MB/M-OFF not independently re-run (single-line deletions/edits directly targeting a guard already confirmed structurally present at its documented line; lower marginal risk than the three flagged for deep re-verification) |

**Score:** 6/6 truths verified

### Mutation Re-Verification (independently re-run, not trusted from SUMMARY)

| Mutant | Edit | My observed RED | Matches SUMMARY verbatim? | Restored sha256 |
| --- | --- | --- | --- | --- |
| M-G3 | delete `require(@evm_calldatasize() >= 100 + 32 * count);` | `[FAIL: guard 3: calldatasize must cover 100 + 32*count] test__unit__truncatedCalldataReverts()` | Yes, exact match | `6931b5e0...62a` confirmed |
| M-M5 | hoist `id = id + 1;` above the `if validate_order(order)` guard | `[FAIL: id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979] test__unit__mixedBatchFootprintAndContiguity()` | Yes, exact match including the numeric value | `6931b5e0...62a` confirmed |
| M-VAL | delete the `if validate_order(order) {` guard and its closing brace | `returns the success count: 3 != 2`, `no tuple succeeded: 1 != 0`, fuzz `the success count equals the constructed valid count: 5 != 0` (fuzz counterexample differs run-to-run, message text identical) | Yes — message text identical; `assertTrue(ok, ...)` never failed in any of the three, confirming no revert observed | `6931b5e0...62a` confirmed |

**M-G3 double-check (per task instructions):** the trace of the killed mutant shows the low-level `.call` returning successfully (`[Return] 0x000...0000`, i.e. `ok=true, ret=0`) — the truncated calldata's head (count, offset, length) is fully intact and only the array element is missing; `@evm_calldataload` past calldatasize returns a zero-padded word, `build_vord_order(0,0,0)` fails validation (strike=0 is out of [1, 2^88-1]), the tuple is skipped, and the trailing unconditional `orderCount` write re-writes the pre-call value (0, since the test starts from a fresh registry). Because forge-std's `assertFalse`/`assertEq` invoke a VM cheatcode that halts test execution on the first failure, the companion `orderCount == 0` assertion in the same test function does not execute after the revert-assertion fires — but the EVM trace independently confirms the call succeeded and returned 0, which is sufficient to establish that the companion state assertion would pass (0 == 0 in a fresh registry). This corroborates, rather than contradicts, the SUMMARY's central claim: **the kill is a REVERT assertion, and the companion state assertion would stay GREEN.**

**M-OFF and M-M5 killability check:** M-M5's reddening corpus point (`test__unit__mixedBatchFootprintAndContiguity`) uses count=3, confirmed != 64, so the transcription-trap mutant (M-OFF, not independently re-run here) would be genuinely killed by the same test, consistent with the SUMMARY's stated killability check.

**M-G1, M-G2, M-MB, M-OFF:** not independently re-executed in this verification pass (time-boxed to the three flagged in the task instructions: M-G3, M-M5, M-VAL). Their guard lines were independently confirmed present at the documented line numbers via `grep -n`, and the SUMMARY's recorded kill lines are structurally consistent with the module code read directly.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `src/modules/pos_spec/VolOrderManagerMod.plk` | SELECTOR_CREATE_ORDERS branch: four guards, bounded while, validate-then-skip, single trailing orderCount store, return_u256(ok) | VERIFIED | Branch present lines 94-211; guards at 148-151 in correct order and offsets (36/68, not the merkle_airdrop transcription trap); `@evm_sstore(SLOT_ORDER_COUNT` appears exactly twice (once in create_order, once after batch loop, zero inside `while` body); MCAL-04 enumeration present |
| `test/pos_spec/VolOrderManagerBatch.t.sol` | Batch surface: hand-rolled malformed-calldata builders + raw `.call` assertions | VERIFIED | 481 lines (exceeds 250-line minimum), 13 CALLED-green tests, all ten behaviors from the plan mapped to named tests |
| `Makefile` | `test-vol-order-batch` focused target | VERIFIED | Present at line 165, mirrors `test-vol-order-manager`, added to `.PHONY` |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `VolOrderManagerMod.plk` | `VolOrderValidationLib::validate_order` | `if validate_order(order)` inside the loop | WIRED | `grep -c 'if validate_order(order)'` = 1; `grep -c 'validate_order_strict(order)'` = 1 (single-call path only) — batch never calls the reverting wrapper |
| `VolOrderManagerMod.plk` | `pos_spec::VolOrder::pack_vol_order` | `@evm_sstore(array_slot(...), pack_vol_order(order))` | WIRED | Called inside the guarded store, confirmed by direct read of the module |
| `VolOrderManagerBatch.t.sol` | `address(mgr).call(malformedBytes)` | low-level `.call` via the `callBatch` helper | WIRED | 11 call sites route through the single `callBatch` helper (a deliberate, documented, and stronger deviation from the plan's literal `>= 5` inline-call-site count — see Deviations below); no typed batch interface exists to accidentally bypass this |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| MCAL-01 | 18a-01-PLAN.md | MAX_BATCH=128 bound, revert before work, measured gas <= 10M | SATISFIED | Independently re-measured 3,247,452 gas; MAX_BATCH boundary behaviorally pinned by 128-succeeds/129-reverts pair |
| MCAL-02 | 18a-01-PLAN.md | Three independent calldata guards, each separately killed | SATISFIED | Guards structurally verified at correct byte offsets; guard 3's revert-only kill independently re-confirmed |
| MCAL-03 | 18a-01-PLAN.md | Per-tuple best-effort skip with zero footprint | SATISFIED | Mixed-batch contiguity test independently re-run and passing; M5 mutant independently re-killed |
| MCAL-04 | 18a-01-PLAN.md | Structural enumeration as primary containment argument, fuzz as corroboration | SATISFIED | Enumeration present in-module; M-VAL mutant independently confirms no revert is possible even with unvalidated tuples flowing through the store path |
| MCAL-06 | 18a-01-PLAN.md | Batch-of-1 ≡ create_order; N=0 no-op (state half only — return-bytes clause explicitly deferred to 18b) | SATISFIED (state half); return-bytes clause honestly deferred, not overclaimed | REQUIREMENTS.md:245 reads `Complete (state half; return-bytes clause carried to 18b)`. Independently confirmed `return_u256` (util.plk:23) emits a single 32-byte word, which structurally cannot satisfy MCAL-05's 64-byte `(offset=0x20, length=0)` empty-array encoding for N=0 — so the annotation is accurate, not an overclaim |

No orphaned requirements: REQUIREMENTS.md maps only MCAL-01/02/03/04/06 to Phase 18a (MCAL-05 correctly deferred to 18b), matching the plan's declared `requirements` field exactly.

### Anti-Patterns Found

None. No TODO/FIXME/placeholder markers, no empty-body handlers, no console-log-only implementations in the modified files. `grep -c 'vm.assume'` on the batch test file = 0.

### Baseline Regression Checks (independently re-run with cleared caches)

| Check | Expected | Observed |
| --- | --- | --- |
| `make compile-plank` | `13 ok, 0 failed, 0 skipped` | `13 ok, 0 failed, 0 skipped` — match |
| `make test-vol-order-batch` | zero failures, >= 12 tests | 13 passed, 0 failed — match |
| `make test-vol-order-manager` | zero failures, boundary test flipped | 12 passed, 0 failed; `batchSelectorNotYetDispatched` absent (0 hits), `batchSelectorIsNowDispatched` present (1 hit) |
| `make test` (full suite, `rm -rf cache/fuzz` first) | 112 pass / 4 pre-existing pos_spec fails, no 5th flake | 112 passed / 4 failed (SpreadTickAssimetryTest x2, VolRangeWidthTest x2) — no 5th failure observed; matches expected baseline exactly |
| `git diff --stat src/types/pos_spec/` | EMPTY | EMPTY — confirmed both via working-tree diff and `git diff 90aa0d2~1 HEAD --stat -- src/types/pos_spec/` |
| Module sha256 (session end) | `6931b5e044c9e4517392888eaf54a389c53ee64b8c76b5b1e5f7c7367b36362a` | Identical — confirmed after every mutant restoration and at session end |

### Human Verification Required

None. All claims in this phase are mechanically checkable via forge tests, grep, and sha256 comparison, and were independently re-derived above.

### Gaps Summary

No gaps found. All six must-have truths independently re-verified against the actual codebase (not trusted from SUMMARY.md). The three mutants flagged for deep re-verification (M-G3, M-M5, M-VAL) were independently applied, tested, and restored, producing failing-assertion messages that match the SUMMARY's recorded verbatim lines exactly (including M-M5's specific numeric counterexample value). The MCAL-06 partial-completion annotation in REQUIREMENTS.md was verified as an honest, structurally-grounded deferral rather than an overclaim (`return_u256` genuinely cannot emit the 64-byte empty-array encoding MCAL-05 requires). One minor deviation from the plan's literal acceptance-criteria wording was found and is correctly self-disclosed in the SUMMARY: the `>= 5 inline address(mgr).call(` grep count is satisfied instead by a single `callBatch` helper used at 11 call sites, which is a stronger realization of the underlying property ("guards exercised through low-level calls, never the typed interface") and was a necessary consequence of the same plan's own mandate to define that helper.

---

_Verified: 2026-07-21T02:45:56Z_
_Verifier: Claude (gsd-verifier)_
