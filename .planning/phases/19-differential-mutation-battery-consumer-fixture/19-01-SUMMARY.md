---
phase: 19-differential-mutation-battery-consumer-fixture
plan: 01
subsystem: pos_spec-verification
tags: [differential, mvER-01, vol-order, mock-oracle, fuzz]
requires:
  - src/modules/pos_spec/VolOrderManagerMod.plk
  - src/lib/pos_spec/VolOrderValidationLib.plk
  - test/pos_spec/VolOrderManagerBatch.t.sol
  - test/pos_spec/VolOrderManager.t.sol
provides:
  - test/pos_spec/VolOrderDecoder.sol
  - test/mocks/VolOrderRefMock.sol
  - test/pos_spec/VolOrderManager.diff.t.sol
affects: []
tech-stack:
  added: []
  patterns:
    - after-every-write sequence differential vs an independent Solidity mock
    - unguarded shared decoder (anti-vacuity)
    - constructed corpora with bound, no rejection-sampling cheatcode
key-files:
  created:
    - test/pos_spec/VolOrderDecoder.sol
    - test/mocks/VolOrderRefMock.sol
    - test/pos_spec/VolOrderManager.diff.t.sol
  modified: []
decisions:
  - "Live-order assertions gated to ids > seedBase: vm.store seeding moves the COUNTER, not the orders"
  - "NatSpec cannot carry the field-at-bit shorthand; solc parses it as a doc tag (Error 6546)"
metrics:
  duration: 6 min
  completed: 2026-07-21
---

# Phase 19 Plan 01: Interleaved Sequence Differential Summary

An after-every-write differential over interleaved `create_order` / `create_orders` sequences,
diffing the FFI-deployed Plank module against an independent Solidity reference mock at tolerance
0 — orderCount, every stored packed word, and the raw return bytes — with a fixed anchor and a
256-run constructed fuzz.

## Headline result

**The module and the mock AGREE everywhere. No disagreement was observed.** All three tests are
green, including step 3 of the anchor — the interleave, where the strict path must resume on a
counter the batch advanced. That is the one property 18a and 18b structurally could not test, and
`VolOrderManagerMod.plk` satisfies it.

`src/` is byte-untouched by this plan (sha256 pins below).

## What was built

| File | Role |
| --- | --- |
| `test/pos_spec/VolOrderDecoder.sol` | The single shared, deliberately **unguarded** packed-word decoder. No length check, no success check, no early return — a decoder that cannot short-circuit cannot make its callers vacuous. |
| `test/mocks/VolOrderRefMock.sol` | The independent reference registry. Reimplements the *specification* (accept set, `id = count + 1`, 152-bit layout, input read semantics) from the `.plk` sources. No `assembly`, no `abi.encode` in code, and storage is a plain `mapping` rather than `keccak(base)+id` — so the differential compares behaviour, not a restatement of the module's slot arithmetic. |
| `test/pos_spec/VolOrderManager.diff.t.sol` | The differential: `test__unit__refMockSelfPin`, `test__unit__fixedAnchorSequenceDiffers`, `test__fuzz__randomSequenceDiffers`. |

## Measured results

```
Ran 3 tests for test/pos_spec/VolOrderManager.diff.t.sol:VolOrderManagerSequenceDiffTest
[PASS] test__fuzz__randomSequenceDiffers(uint256,uint8,uint16) (runs: 256, μ: 12153725, ~: 4340268)
[PASS] test__unit__fixedAnchorSequenceDiffers() (gas: 1030352)
[PASS] test__unit__refMockSelfPin() (gas: 16944)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 3.61s
```

- **Observed `runs:` figure — 256**, measured after `rm -rf cache/fuzz`. Not a `runs: 0` cache replay.
- **Anchor sequence final id — 12**, as planned, from a counter seeded to 5.
- Cold-cache fuzz wall time 3.6s. The pre-execution concern that a `seedCount` bound of 0..1000
  would make the per-step `[1, pc]` scan intractable at 256 runs was **wrong** — measured, not
  assumed, and the plan's bound was therefore left at 0..1000 rather than reduced.

### Non-regression

| Suite | Before | After |
| --- | --- | --- |
| `VolOrderManagerBatch.t.sol` (match-path, 7 suites) | 21 passed / 0 failed | 21 passed / 0 failed |
| `VolOrderManager.t.sol` (match-path, 5 suites) | — | 12 passed / 0 failed |

### `src/` is untouched

```
be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787  src/modules/pos_spec/VolOrderManagerMod.plk
5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35  src/lib/pos_spec/VolOrderValidationLib.plk
```

Both match the 18b baseline exactly. `git status --short src/types/pos_spec/` is empty.

## Harness liveness — negative control (extra, not planned)

A green differential is only evidence if it can go red. The mock's id rule was perturbed
(`orderCount + 1` → `orderCount + 2`), which reddened immediately and at the right place:

```
[FAIL: step 1 single: orderCount module vs mock, tol 0: 6 != 7] test__unit__fixedAnchorSequenceDiffers()
```

The mock was restored and `git diff --stat test/mocks/VolOrderRefMock.sol` is empty. The
perturbation was applied to the **test-side mock only**; `src/` was never touched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NatSpec cannot carry the `field@bit` shorthand**
- **Found during:** Task 1
- **Issue:** The plan's mandated `VolOrderDecoder` doc-comment contains
  `width@128 | tickSpacing@104 | ...`. solc parses a leading at-sign followed by a word in NatSpec
  as a documentation tag and rejects the file: `Error (6546): Documentation tag @128 not valid for
  contracts.` The file could not compile as written. A first fix attempt reintroduced the same
  error via the word `` `field@bit` `` in the explanatory note itself.
- **Fix:** Layout written in prose ("width at bit 128 | tickSpacing at 104 | ...") with an in-file
  note recording why. The shorthand survives in the differential's **failure-message string
  literals** (`"width@128"`, `"tickSpacing@104"`, `"strike@16"`, `"skew@0"`), which is where it is
  actually load-bearing — a field mismatch still names the field by bit offset.
- **Files modified:** `test/pos_spec/VolOrderDecoder.sol`
- **Commit:** `0da8e07`

**2. [Rule 1 - Bug in the plan's assertion design] `_assertSynced` would have failed on the seeded region**
- **Found during:** Task 2
- **Issue:** The plan's `_assertSynced` loops `id` over `[1, pc]` and asserts, for every id,
  `pw != 0` and `tickSpacing == 20`. But `_seedBoth(5)` seeds the **counter** via `vm.store`; ids
  1–5 were never written by anyone and hold zero on **both** sides. Those two assertions would have
  failed on every seeded test for a reason that says nothing about the module — and seeding is
  mandated by the anchor (step 0) and the fuzz alike, so the anchor could never have passed as
  literally specified.
- **Fix:** Word-for-word **agreement** (`pw == rw`) and the four field comparisons still run over
  the full `[1, pc]`, so the seeded region is still diffed. The live-order shape assertions are
  gated to `id > seedBase`; for `id <= seedBase` the stronger, more informative
  `assertEq(pw, 0, "seeding fabricated no order at id N")` runs instead — which catches a seeding
  bug that invented phantom orders, a check the plan's version did not have. A `seedBase` field was
  added to the base contract. Non-vacuity is unaffected: `syncChecks` still increments once per id.
- **Files modified:** `test/pos_spec/VolOrderManager.diff.t.sol`
- **Commit:** `d0f3d51`

No `src/` file was modified, and the mock was never weakened to obtain green.

## Acceptance criteria

All Task 1/2/3 criteria pass as written, including the two corrected grep gates from `379f835`
(anchored `^\s*assembly` and `abi\.encode` filtered through `grep -v '///'` — both produce no
output). The load-bearing doc-comments were left intact.

**One criterion required interpretation.** Tasks 2 and 3 specify `git diff --stat src/` produces
NO output. It produces one line:

```
 src/lib/exposure/VegaIssuanceLib.plk | 14 ++++++++++++++
```

This is the **pre-existing uncommitted draft owned by another track** — present in the working tree
before this plan began (captured as a baseline at execution start), and the documented cause of the
14 exposure `setUp()` reverts in the current `make test`. It is not this plan's, and no criterion
was contorted to hide it. The property the criterion exists to establish — *this plan modified
nothing under `src/`* — is verified instead by the two sha256 pins matching the 18b baseline
byte-for-byte, and by `git status --short src/types/pos_spec/` being empty.

## Notes for later phases

- The negative control above is a cheap, repeatable liveness proof for this harness. 19-02's
  mutation battery can reuse the same perturb/observe/restore shape against `src/` mutants.
- The differential asserts return bytes against `abi.encode(refRs)` where `refRs` comes from the
  **mock**, never the module. If a future edit ever routes that through the module's own results,
  the differential silently becomes vacuous — that line is the one to guard in review.
- `test__unit__refMockSelfPin` must be kept ahead of any accept-set change: a mock bug would
  otherwise surface as a module failure and burn the mutation evidence.

## Self-Check: PASSED

- `test/pos_spec/VolOrderDecoder.sol` — FOUND
- `test/mocks/VolOrderRefMock.sol` — FOUND
- `test/pos_spec/VolOrderManager.diff.t.sol` — FOUND
- commit `0da8e07` — FOUND
- commit `d0f3d51` — FOUND
- commit `e035679` — FOUND
