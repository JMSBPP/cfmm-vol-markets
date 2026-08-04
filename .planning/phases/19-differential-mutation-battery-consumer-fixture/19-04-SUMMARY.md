---
phase: 19-differential-mutation-battery-consumer-fixture
plan: 04
subsystem: pos_spec-verification
tags: [MVER-02, mutation-battery, observed-red, calldata-guards, return-encoder, consumer-contract]
requires:
  - "src/modules/pos_spec/VolOrderManagerMod.plk (sha256 be196dcb...cc9b8787)"
  - "test/pos_spec/VolOrderManagerBatch.t.sol (18a/18b guard + return-encoding suites)"
  - "test/pos_spec/VolOrderManager.diff.t.sol (19-01)"
  - "test/pos_spec/VolOrderManagerFixture.t.sol (19-02)"
  - ".planning/phases/19-differential-mutation-battery-consumer-fixture/19-MUTATION-BATTERY.md (Part A, from 19-03)"
provides:
  - ".planning/phases/19-differential-mutation-battery-consumer-fixture/19-MUTATION-BATTERY.md (Part B + consolidated MVER-02 tally)"
affects: []
tech-stack:
  added: []
  patterns:
    - "apply -> cold fuzz cache -> observe RED -> verbatim FAIL line -> restore -> sha256 verify"
    - "blindness claims re-measured on the current tree, never cited from a prior phase"
    - "kill site chosen by assertion, not by test: a state assertion inside the right test can still be a fake kill"
key-files:
  created: []
  modified:
    - .planning/phases/19-differential-mutation-battery-consumer-fixture/19-MUTATION-BATTERY.md
decisions:
  - "M8's N=0 blindness belongs to the ELEMENT-BASE SHIFT, not the head-drop — established by measuring BOTH variants rather than inheriting 18b's mapping"
  - "M9 is also N=0-blind and all-invalid-blind; its kill needs an N>=1 corpus containing a VALID tuple (third blindness entry, not previously recorded)"
  - "the three calldata guards each have a SINGLE point of failure in VolOrderManagerBatchGuardTest; wave 1 structurally cannot cover them"
  - "M9's abi.decode revert cascade is corroboration, never the kill — the pinned property is word canonicality, not decoder rejection"
metrics:
  duration_min: 21
  tasks: 2
  files_changed: 1
  completed: 2026-07-21
---

# Phase 19 Plan 04: Mutation Battery Part B Summary

The three calldata guards deleted INDEPENDENTLY plus the two return-encoder mutants, each
re-applied to the CURRENT tree, each observed RED from a cold fuzz cache with its verbatim FAIL line
recorded, each restored sha256 byte-identical. **No kill is cited from a prior phase.**

## CONSOLIDATED MVER-02 TALLY (parts A + B)

| # | Mutant | Part | Status | Killed by |
| --- | --- | --- | --- | --- |
| 1 | Deleted validation branch — BATCH (M1a) | A | **RED** | `mixedBatchFootprintAndContiguity` + both wave-1 suites |
| 2 | Deleted validation branch — STRICT (M1b) | A | **RED** | `invalidSkewRevertsAndLeavesStateUntouched` |
| 3 | Missing strike upper bound (M2) | A | **RED** | `strikeBoundBlocksSilentMasking` (Phase-16 harness ONLY) |
| 4 | Count-advance-on-failure (M3) | A | **RED** | `mixedBatchFootprintAndContiguity` (CONTIGUITY assertion) |
| 5 | Ring-mask reintroduction (M4) | A | **RED** | `idAt65536IsNotMaskedIntoSlotZero` (sole site) |
| 6 | Guard 1 — offset (M5) | B | **RED** | `nonCanonicalOffsetReverts` (1 red in 40) |
| 7 | Guard 2 — length (M6) | B | **RED** | `lengthCountMismatchReverts` (1 red in 40) |
| 8 | Guard 3 — calldatasize (M7) | B | **RED** | `truncatedCalldataReverts`, **REVERT assertion only** |
| 9 | Return element-base shift (M8) | B | **RED** | `oneAndTwoElementReturnsAreByteExact` (keccak, N=1) |
| 10 | Non-canonical success word (M9) | B | **RED** | `successWordsAreCanonicallyZeroOrOne` (raw words) |

Ten applications for nine named mutants — M1 was applied independently to the batch and strict paths.

## SURVIVOR COUNT: ZERO (0 of 10)

Stated explicitly. Every mutant produced an observed RED. **No test was weakened, reshaped or added
to manufacture a kill.**

The zero is real but does NOT mean the suite is complete. Four mutants have a SINGLE point of failure
— delete one test and a real mutant survives silently:

- **M2** — killed only OUTSIDE `test/pos_spec/`, by the Phase-16 harness (19-03's finding F1 stands).
- **M4** — the 65536 test alone.
- **M5/M6/M7** — the three tests in `VolOrderManagerBatchGuardTest` alone.

## Restoration hash

```
be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787  src/modules/pos_spec/VolOrderManagerMod.plk
5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35  src/lib/pos_spec/VolOrderValidationLib.plk
```

EQUAL to baseline. Seven applications were made in this plan (M5, M6, M7, M8, the M8 head-drop
variant, M9) and **every one was restored and verified by sha256, not by eye**. `git status --short`
on `src/modules/pos_spec`, `src/lib/pos_spec`, `src/types/pos_spec` is empty. Final suite: **40
passed / 0 failed** (15 suites), cold cache, exit 0. `src/types/pos_spec/` untouched.

## Guard 3's kill came from the REVERT assertion, and the state-invisibility was RE-MEASURED

The single most falsifiable claim in this plan. Under M7 the recorded FAIL line is

```
[FAIL: guard 3: calldatasize must cover 100 + 32*count] test__unit__truncatedCalldataReverts() (gas: 39217)
```

— the `assertFalse(ok, ...)` revert assertion, **not** the `"completeness only -- NOT the kill site"`
orderCount assertion that follows it in the same test. Being in the right test is not sufficient
here; the assertion choice is what separates a real kill from a fake one.

The invisibility itself was measured rather than repeated from the ledger: **with M7 applied**,

```
Ran 1 test suite: 2 tests passed, 0 failed, 0 skipped (VolOrderManagerBatchStateTest)
```

GREEN. A `calldataload` past the end returns zero-padded words, `build_vol_order(0,0,0)` fails
validation, the tuple is skipped, state stays clean. This is the one mutant in the battery where a
state assertion would have recorded a green-looking kill.

## Divergences from 18b's recorded measurements

**None on M8's N=0 blindness — it is still blind, and now for a measured reason.**
`test__unit__emptyReturnIsExactlySixtyFourBytes` stayed **GREEN** under M8 (1 passed / 0 failed),
while the full sweep produced 13 reds. 18b's measurement holds on this tree.

**One correction to the plan's naming, resolved by measurement.** The plan heads M8 "RETURN HEAD
`0x40` -> `0x20`" but specifies the ELEMENT-BASE SHIFT edit. The execution constraints required the
blindness be attached to whichever mutant actually needs it, verified rather than inherited — so
BOTH variants were applied and measured:

| Formulation | Total at N=0 | N=0 test | Verdict |
| --- | --- | --- | --- |
| Element-base shift (`64+64*i` -> `32+64*i`) = M8 | 64 (unchanged) | **GREEN** | **N=0-BLIND** |
| Head-drop (outer offset removed, total `32+64N`) | 32 | **RED** | **N=0-VISIBLE** |

Ledger entry 6's mapping is CORRECT and now rests on measurement. The N >= 1 requirement belongs to
the element-base shift and only to it. The head-drop variant is a measurement instrument, **not
counted** in any tally.

**New finding — M9 is ALSO N=0-blind**, which was not previously recorded anywhere.
`emptyReturnIsExactlySixtyFourBytes` did not appear among M9's 13 reds: at N=0 the success branch
never executes, so no success word is written. M9 additionally needs the N >= 1 corpus to contain at
least one **VALID** tuple — an all-invalid batch is blind to it too, since the mutated line sits in
the success branch. A third blindness entry for the ledger.

## M9 as a consumer-side contract (peer hand-off, not a test detail)

M9's kill is `test__unit__successWordsAreCanonicallyZeroOrOne`, which reads RAW WORDS and asserts
`w < 2`. Recorded **separately as corroboration**: the `EvmError: Revert` cascade across every test
that decodes through `callBatch` (`batchOfOneEqualsSingleCall`, `maxBatchExactlyOneTwoEightSucceeds`,
`maxBatchGasUnderBudget`, `mixedBatchFootprintAndContiguity`, `batchNeverReverts`), re-confirming
18b-01's finding that solc's `abi.decode` rejects a non-canonical bool outright.

Keeping these separate matters: "solc refuses to decode our bytes" would still hold for some *other*
malformed word and would stop holding the moment a consumer used a lenient decoder. Only the raw-word
test pins the actual invariant.

**The hand-off item.** A lenient Haskell decoder accepts a truthy `2` as `True` while `abi.decode`
reverts — so the two consumers would disagree about the same bytes: one sees a successful order, the
other a malformed payload. That is a consensus-relevant disagreement, not a decoder preference. Peer
`mv15a18k`'s decoder should assert `w < 2` rather than coercing truthiness, so a future encoder
regression fails loudly on BOTH sides instead of only in solc.

## Did wave 1's new tests appear as kill sites? — YES on 5 of 10, and the gap is structural

| Mutant | 19-01 differential | 19-02 fixture |
| --- | --- | --- |
| M1a | **KILL SITE** | **KILL SITE** (`N2_success_then_fail`) |
| M1b | **KILL SITE** | green |
| M2 | green (cannot kill — F1) | green |
| M3 | **KILL SITE** | **KILL SITE** (`N3_mixed_seeded_C5`) |
| M4 | green (small ids) | green (small ids) |
| M5 / M6 / M7 | green | green |
| M8 | **KILL SITE** | **KILL SITE** (`N1_success`) |
| M9 | **KILL SITE** | **KILL SITE** (`N1_success`) |

**19-01 is a kill site on 5 of 10 mutants, 19-02 on 4 of 10.** Both plans added genuine mutation
coverage, not merely green tests. 19-02's `N1_success` reddened under M8 exactly as the plan
predicted in advance.

**The honest counterpart — a clean structural boundary, not an oversight.** Neither wave-1 suite
kills M4 or ANY of the three calldata guards. Both drive the module through WELL-FORMED calldata at
SMALL IDS. A differential against a typed Solidity mock and a golden-bytes fixture are structurally
incapable of expressing a malformed encoding — you cannot ask a typed encoder for a non-canonical
offset — and neither reaches id 65536. **Wave 1 strengthened the return-encoding and
sequence-semantics surfaces and left the malformed-input and large-id surfaces exactly as they were.**
Breadth on the happy path is not coverage of the hostile path.

Treating the plan's predictions as hypotheses paid off in both directions: it was right about
`N1_success` and about guard 3's assertion trap, and wrong about the M8 naming.

## Deviations from Plan

### Strengthened beyond the plan

**1. [Rule 2 - Missing critical evidence] Measured BOTH M8 formulations rather than inheriting the mapping**
- **Found during:** Task 2
- **Issue:** The plan names M8 "return head `0x40` -> `0x20`" while specifying the element-base-shift
  edit. Recording the observation under the plan's name would have propagated an ambiguity about
  which mutant the N >= 1 requirement attaches to — exactly what the execution constraints warned
  against inheriting.
- **Fix:** Applied the head-drop variant as well and measured its N=0 behaviour (RED, vs M8's GREEN),
  settling the mapping by observation. Documented as a supplementary measurement and explicitly NOT
  counted in any tally. Restored like every other mutant.
- **Commit:** `3f0f8ea`

**2. [Rule 2] Recorded M9's N=0 and all-invalid blindness, which no prior phase had**
- **Found during:** Task 2
- **Issue:** `emptyReturnIsExactlySixtyFourBytes` was absent from M9's red list. Left unremarked,
  a later phase could build an N=0 or all-invalid corpus and read its green as coverage.
- **Fix:** Traced it to the mutated line sitting inside the success branch, and recorded it as a
  third blindness entry.
- **Commit:** `3f0f8ea`

**3. [Rule 2] Recorded the guards' single-point-of-failure structure as an explicit finding**
- **Found during:** Task 1
- **Issue:** All three guard mutants produced exactly 1 red in 40. The plan asked only for the kill
  to be recorded; the *narrowness* is the more useful result.
- **Fix:** Recorded that `VolOrderManagerBatchGuardTest` is the sole protection for all three guards,
  with the structural reason wave 1 cannot help. Reported, not fixed.
- **Commit:** `0a5b2f9`

### Known plan defect, resolved by the established precedent

The acceptance criterion `git diff --stat src/` produces NO output is **UNSATISFIABLE** — the user's
uncommitted `src/lib/exposure/VegaIssuanceLib.plk` draft always shows, and `19-CONTEXT.md` explicitly
defers it. Resolved per the 19-01/19-02/19-03 precedent by verifying the PROPERTY instead:
`git status --short` on all three pos_spec trees is empty, plus the two sha256 pins. **The draft was
not touched.** This is the seventh instance of the self-contradicting-criterion pattern; future plans
should scope the criterion to `src/**/pos_spec`.

The `grep -c 'runs: 0'` == 0 criterion: Part A's finding F2 applies unchanged. **No guard mutant
(M5/M6/M7) produced any `runs: 0` line at all** — all three kills are non-fuzz and cache-independent
by construction. M8 and M9 did produce `runs: 0` fuzz lines, but both kills rest entirely on non-fuzz
keccak and raw-word anchors; discard every fuzz result and both remain killed.

### No source was improved

`src/` was mutated and restored only. Every mutant that revealed a narrow kill site was REPORTED, not
fixed. No test was added to close F1, the guard single-point-of-failure, or the M4 gap.

## Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `0a5b2f9` | M5, M6, M7 — the three calldata guards, deleted independently |
| 2 | `3f0f8ea` | M8, M9 + Part B tally, consolidated tally, survivors, wave-1 kill sites |

## Self-Check: PASSED

- `19-04-SUMMARY.md` — FOUND
- `19-MUTATION-BATTERY.md` (Part A + Part B) — FOUND
- commit `0a5b2f9` — FOUND
- commit `3f0f8ea` — FOUND
- module sha256 `be196dcb...cc9b8787` — MATCHES baseline
- lib sha256 `5fe71f30...73fe8f35` — MATCHES baseline
- `git status --short` on all three pos_spec trees — EMPTY
- pos_spec suite 40 passed / 0 failed, cold cache, exit 0
