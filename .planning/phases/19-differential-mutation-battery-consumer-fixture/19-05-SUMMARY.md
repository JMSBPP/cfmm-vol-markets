---
phase: 19-differential-mutation-battery-consumer-fixture
plan: 05
subsystem: build-acceptance
tags: [MVER-04, make-target, measured-counts, called-green, plank-skip, roadmap-correction, milestone-exit]
requires:
  - "test/pos_spec/VolOrderManager.diff.t.sol (19-01)"
  - "test/pos_spec/VolOrderManagerFixture.t.sol (19-02)"
  - "test/pos_spec/VolOrderManagerBatch.t.sol (18a/18b)"
  - "src/modules/pos_spec/VolOrderManagerMod.plk (sha256 be196dcb...cc9b8787, READ ONLY)"
provides:
  - "Makefile: test-vol-order-diff, test-vol-order-fixture, test-vol-order-acceptance"
  - "Makefile: MEASURED AT 19-05 comment block with every red attributed"
  - "Makefile: CHECKED AT 19-05 PLANK_SKIP rescue-queue note"
  - ".planning/ROADMAP.md: Phase 19 SC-4 corrected to the gate that actually exists"
affects:
  - ".planning/ROADMAP.md"
tech-stack:
  added: []
  patterns:
    - "fold-in proven by OBSERVING contract names in output, never by adding a prerequisite"
    - "every red in the command of record attributed to a NAMED cause, not a bare count"
    - "stale acceptance criteria corrected in the DOCUMENT, never by contorting the code"
key-files:
  created:
    - .planning/phases/19-differential-mutation-battery-consumer-fixture/19-05-SUMMARY.md
  modified:
    - Makefile
    - .planning/ROADMAP.md
decisions:
  - "make test measured cold at 102 passed / 18 failed / 120 total (44 suites); compile-plank 11 ok / 2 failed — every red attributed, ZERO under test/pos_spec/"
  - "the fold-in is an OBSERVATION, not a prerequisite: make test is already a whole-tree forge run, and a prerequisite would double-run pos_spec and inflate the tally"
  - "the plan's `grep 'FAIL' | grep -c 'pos_spec'` == 0 gate is a FALSE POSITIVE — it matches the --dep pos_spec=src/types/pos_spec flag echoed in FFI failure lines, not any failing test"
  - "PLANK_SKIP verified byte-identically empty; no exit ceremony performed or invented"
metrics:
  duration_min: 5
  tasks: 3
  files_changed: 2
  completed: 2026-07-21
---

# Phase 19 Plan 05: Make Target & Re-Measured Counts Summary

MVER-04 satisfied: three new `make` targets, the stale `MEASURED AT 17-01` block replaced with counts
measured cold at execution time with every red attributed to a named cause, the real gate (CALLED-green
batch dispatch through FFI-deployed bytecode) VERIFIED rather than inferred, and the roadmap's stale
"`PLANK_SKIP` exit" wording corrected against MVER-04's own 2026-07-20 correction.

**`src/` was not modified.** Both sha256 pins are byte-identical to the pre-execution baselines.

## THE MEASUREMENT (cold `cache/fuzz`, taken at execution time — nothing carried forward)

```
make test          102 passed, 18 failed, 120 total  (44 suites)
make compile-plank  11 ok, 2 failed, 0 skipped
```

The stale block claimed `96 pass, 4 fail (100 total)` and `13 ok, 0 failed`. **Both were wrong against
the current tree.** They were replaced, not amended.

### Every red attributed — the cause NAMED, not counted

| Count | Cause | Owner |
| --- | --- | --- |
| **14** | exposure `setUp()` reverts — the uncommitted `src/lib/exposure/VegaIssuanceLib.plk` draft | ANOTHER TRACK |
| **4** | vol-type track: `SpreadTickAssimetryTest` x2, `VolRangeWidthTest` x2 | vol-type track |
| **0** | `test/pos_spec/` — **the module surface this milestone owns** | v4.0 |
| **0** | the intermittent `TickVolatility` case — did NOT surface this run | TickVolatility track |

The 14 were derived by pairing each `Suite result: FAILED` with its preceding `Ran N tests for FILE:CONTRACT`
line, not estimated: `VegaAccount*` (7 suites) and `VegaIssuance*` (7 suites), each `0 passed; 1 failed`
— they die in `setUp()` before any assertion runs, because `deployPlank` shells out to `plank build`
over FFI and the draft fails to compile. The error text was read from the run:
`error: unresolved identifier 'VolOrder'`, plus `'Option'` and `'LDFParams'`.

**The exposure draft had NOT landed by execution time** (`git status --short src/lib/exposure/` shows
` M src/lib/exposure/VegaIssuanceLib.plk`). Stated explicitly, per the plan: its failures are another
track's in-progress work and **do not block milestone closure**. MVER-04's "0 failed" clause is scoped
to the pos_spec surfaces this milestone owns, and that scoping is now written into the Makefile so it
cannot be over-read.

`compile-plank`'s 2 failures are the SAME draft — `src/modules/exposure/VegaAccountMod.plk` and
`test/exposure/VegaIssuanceKernelHarness.plk` both import it (confirmed by reading both `.hex.err`
files). **`VolOrderManagerMod.plk` compiles OK**, verified in that same run.

### The trend line, and why the numbers moved

`13 ok -> 11 ok` and `4 fail -> 18 fail` between 18b and here is **NOT a Phase 19 regression**: it is
the exposure draft, which entered the working tree in between. Phase 19 itself moved the PASS count
**95 -> 102 (+7)** and added zero failures. This is recorded in the comment block so the drop cannot be
misread later as damage done by this milestone.

## The fold-in was OBSERVED, not asserted

All three Phase 19 contract names appear in plain `make test` output (1 occurrence each):
`VolOrderManagerSequenceDiffTest`, `VolOrderManagerFixtureTest`, `VolOrderManagerSelectorCompletenessTest`.

**No prerequisite was added to `test:`** — endorsed in the plan and confirmed correct by the measurement:
`make test` is a whole-tree `forge test --via-ir --optimize` with no match filter, so the new files are
already included by construction. A prerequisite would re-run every pos_spec suite a second time and
inflate the very tally this plan exists to measure honestly.

## THE REAL GATE — VERIFIED, not inferred from compile-green

Verbatim pass lines, each reaching the module through `deployPlank -> plankDeployFFI -> plankBuildFFI`,
which shells out to `plank build` over FFI **at test time** — so every assertion runs the DEPLOYED
bytecode of `src/modules/pos_spec/VolOrderManagerMod.plk`:

```
[PASS] test__unit__batchSelectorIsNowDispatched() (gas: 10252)
[PASS] test__unit__mixedBatchFootprintAndContiguity() (gas: 68212)
[PASS] test__unit__mixedBatchReturnIsByteExact() (gas: 67611)
```

Why these three constitute the gate:
- `batchSelectorIsNowDispatched` — selector `0x81357911` reaches a dispatch branch at all, rather than
  falling through to `revert_empty()`.
- `mixedBatchFootprintAndContiguity` — the branch does REAL WORK: state effects at raw `vm.load`
  addresses, from a SEEDED counter.
- `mixedBatchReturnIsByteExact` — the return half.

`deployPlank` usage confirmed by reading `test/pos_spec/VolOrderManagerBatch.t.sol:379` and
`test/pos_spec/VolOrderManager.t.sol:62`. **"It compiles" was never accepted as evidence** — this repo
has already shipped a "13 ok / 0 failed" gate that was green on an EMPTY module.

## PLANK_SKIP — empty, and no ceremony invented

`grep -c '^PLANK_SKIP    :=$' Makefile` = **1**. Byte-identical and still empty; nothing added, nothing
removed (there was nothing to remove). A `CHECKED AT 19-05 (MVER-04)` note now records in-file that the
queue was checked and why no exit was performed.

### The roadmap SC-4 correction (for the exit record)

`.planning/ROADMAP.md` asserted an exit ceremony that does not exist, in three places — all corrected:

| Location | Before | After |
| --- | --- | --- |
| Phase 19 one-liner | "`PLANK_SKIP` exit gated on CALLED-green batch dispatch" | "CALLED-green batch dispatch through FFI-deployed bytecode" |
| Phase 19 **Goal** | "...and `PLANK_SKIP` exit" | "...and a CALLED-green batch dispatch through FFI-deployed bytecode" |
| Phase 19 **SC-4** | "leaves `PLANK_SKIP` only after..." | the gate that actually exists, with `**CORRECTED at 19-05:**` and the full reasoning preserved |

Rationale, recorded so it is not re-litigated: `PLANK_SKIP` is the Makefile's rescue queue for
entrypoints that do NOT compile (`Makefile:186-198`). A module dispatching a subset of its declared
selectors compiles fine, so `VolOrderManagerMod` never met the entry condition and never entered it.
**This is the fourth stale-criterion correction in this milestone, and like the previous three it was
resolved by fixing the DOCUMENT, never the code.**

Also added: the missing `19-04` and `19-05` plan entries, and the progress table row `4/5 In Progress`
-> `5/5 Complete`.

## Historical note — the `--skip` flag was NOT reintroduced

`--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` was removed from all nine Makefile
recipes at `8b11d73` when the untracked sketch was deleted. Every prior phase's documented forge command
is stale on this point. **Verified after all edits:** `grep -c -- '--skip' Makefile` = **0**, and
`grep -c 'PriceSetterHook' Makefile` = **0**. The note lives here, in the SUMMARY, and deliberately not
in the build file.

## Deviations from Plan

### Two plan-level acceptance-criteria defects, both resolved by verifying the PROPERTY

**1. [Rule 3] `grep 'FAIL' /tmp/...cold.txt | grep -c 'pos_spec'` == 0 is a FALSE POSITIVE — it measured 28**

- **Found during:** Task 2
- **Issue:** Taken literally this reads as 28 pos_spec failures and a STOP. It is not. The matched lines
  are `[FAIL: vm.ffi: ffi command ["plank", "build", ...]` strings from the **exposure** suites, which
  echo the full plank command line — including the dependency flag `--dep pos_spec=src/types/pos_spec`.
  **The grep matches a build flag, not a failing test.**
- **Fix:** Measured the actual property two independent ways: `grep 'FAIL' ... | grep -c 'test/pos_spec/'`
  = **0**, and `grep -c 'Encountered .* failing tests in test/pos_spec/'` = **0**. Cross-checked by
  pairing every `Suite result: FAILED` with its file — all 16 failing suites are under `test/exposure/`
  or `test/types/pos_spec/`, none under `test/pos_spec/`. **No pos_spec regression exists; the phase
  closes.** Reported rather than papered over, because the naive grep would fire on every future run.
- **Commit:** `1d28146`

Note the separate distinction this surfaced: the 4 vol-type reds live under `test/types/pos_spec/` —
the vol-type TYPE track (`src/types/pos_spec`, which CONTEXT forbids modifying), NOT the pos_spec MODULE
surface. A criterion saying "pos_spec" without a path prefix conflates two different owners. The comment
block now names the paths.

**2. [Rule 3] The `test-vol-order-acceptance` occurrence counts are off by one**

- **Found during:** Task 1
- **Issue:** The plan predicted `2` after Task 1 and `3` after Task 2. Measured `3` and `4`. The plan's
  arithmetic omitted the target's own doc-comment header line — which the same plan separately mandated
  ("Each comment must say what the target owns").
- **Fix:** Verified the property instead: the target is defined exactly once (`grep -c '^test-vol-order-acceptance:'`
  = 1), declared `.PHONY` once, documented at its definition, and pointed to from the `test:` comment
  block. All four occurrences are intended.
- **Commit:** `e6855d2`

### Known plan defect, resolved by the established precedent

`git diff --stat src/` produces NO output is **UNSATISFIABLE** — the user's uncommitted
`src/lib/exposure/VegaIssuanceLib.plk` draft always shows (`1 file changed, 18 insertions(+)`), and
CONTEXT.md explicitly defers it. Resolved per the 19-01/19-02/19-03/19-04 precedent by verifying the
PROPERTY: `git status --short` on all three pos_spec trees is EMPTY, plus both sha256 pins. **The draft
was not touched.** Eighth instance of the self-contradicting-criterion pattern.

### Nothing new was built

No test was added to close any coverage gap. The two open findings below are REPORTED, not fixed.

## Restoration pins

```
be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787  src/modules/pos_spec/VolOrderManagerMod.plk
5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35  src/lib/pos_spec/VolOrderValidationLib.plk
```

Both EQUAL to the pre-execution baselines. `src/types/pos_spec/` untouched.

---

# MILESTONE v4.0 EXIT RECORD — OPEN ITEMS

Carried forward. **None of these is closed by this plan, and none blocks closure — they are the honest
boundary of what the suite proves.**

## OPEN FINDING 1 (F1, from 19-03) — the strike bound is UNPROVEN at the `create_order` entrypoint

Mutant M2 (missing strike upper bound / silent truncation) dies **only** in the Phase-16 pure-lib
harness (`test__unit__strikeBoundBlocksSilentMasking`) — outside `test/pos_spec/` entirely.

- **No pos_spec test can express `strike >= 2^88`**: every strike in the corpus is generated as `uint88`
  or `bound(..., 1, type(uint88).max)`, making an oversized strike unrepresentable.
- **On the batch path M2 is genuinely EQUIVALENT**: `create_orders` masks the strike to 88 bits
  (`@evm_shr(16, word) & 0xFF...FF`) BEFORE validation, so `<= MAX_STRIKE` is dead code there. No corpus
  could kill it.
- **The strict path IS killable**: it reads the strike unmasked via `@evm_calldataload(4)`. One
  `create_order` call with `strike = (1 << 88) + 7` asserting a revert would close it.

## OPEN FINDING 2 (from 19-04) — four mutants have a SINGLE POINT OF FAILURE

Survivor count is genuinely ZERO (10 applications, 10 observed REDs), but the zero is thinner than it
looks. Wave 1 is a kill site on 5/10 (19-01) and 4/10 (19-02) mutants — real strengthening — yet neither
kills **M4** (ring-mask) nor **any of the three calldata guards (M5/M6/M7)**, and *structurally cannot*:
a typed Solidity mock and a golden-bytes fixture cannot emit a non-canonical offset or a truncated
payload, and neither reaches id 65536.

Delete `VolOrderManagerBatchGuardTest`, the 65536 test, or the Phase-16 harness and a real mutant
survives **with 39/40 still green**. Breadth on the happy path is not coverage of the hostile path.

## HONEST NEGATIVE (from 19-02) — one fixture test is not an anti-inaction gate

`test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes` reads `expected[0]` ONLY, and
stayed GREEN under a 5-to-4 fixture case-count drop. It is **not** a falsifiability gate. The count gate
lives solely in the differential and the peer-gap tests; a refactor keeping only the N=0 test would
silently lose falsifiability.

## CROSS-LANGUAGE GAP (from 19-02) — still OPEN

`cast abi-encode` (alloy) proves the return bytes are STANDARD-ABI CONFORMANT. It does **not** exercise
peer `mv15a18k`'s Haskell decoder. Two different claims; the exit record must not conflate them. Tracked
in the fixture's `_scope_limit` / `_peer_status` fields, 5 `NOT-PEER-VERIFIED` placeholders, and
`test__unit__peerHaskellBytesAreStillAnOpenGap`.

**Consumer-side contract for the peer** (from 19-04): a lenient Haskell decoder accepts a truthy `2` as
`True` while solc's `abi.decode` reverts — the two consumers would disagree about the same bytes. The
peer's decoder should assert `w < 2` rather than coercing truthiness.

## Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `e6855d2` | three targets + `.PHONY` append; fold-in observed |
| 2 | `1d28146` | cold re-measurement; `MEASURED AT 19-05` block, every red attributed |
| 3 | `b64af30` | CALLED-green gate verified; `PLANK_SKIP` checked; roadmap SC-4 corrected |

## Self-Check: PASSED

- `Makefile` — FOUND, parses (`make -n test` OK)
- `.planning/ROADMAP.md` — FOUND
- `.planning/phases/19-.../19-05-SUMMARY.md` — FOUND
- commits `e6855d2`, `1d28146`, `b64af30` — FOUND
- `make test-vol-order-acceptance` exit **0** (re-run after all edits)
- `MEASURED AT 19-05` = 1; `MEASURED AT 17-01` = 0; placeholders surviving = 0
- `^PLANK_SKIP    :=$` = 1; `--skip` = 0; `PriceSetterHook` = 0
- reds under `test/pos_spec/` = **0**
- both sha256 pins MATCH baseline; pos_spec `git status --short` EMPTY
