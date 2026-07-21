---
phase: 19-differential-mutation-battery-consumer-fixture
plan: 03
subsystem: pos_spec-verification
tags: [MVER-02, mutation-battery, observed-red, equivalence-masked, coverage-gap]
requires:
  - "src/modules/pos_spec/VolOrderManagerMod.plk (sha256 be196dcb...cc9b8787)"
  - "src/lib/pos_spec/VolOrderValidationLib.plk (sha256 5fe71f30...0d4d73fe8f35)"
  - "test/pos_spec/VolOrderManager.diff.t.sol (19-01)"
  - "test/pos_spec/VolOrderManagerFixture.t.sol (19-02)"
  - "test/types/pos_spec/VolOrderValidation.t.sol (Phase 16 harness)"
provides:
  - ".planning/phases/19-differential-mutation-battery-consumer-fixture/19-MUTATION-BATTERY.md (Part A)"
affects: []
tech-stack:
  added: []
  patterns:
    - "apply -> cold fuzz cache -> observe RED -> verbatim FAIL line -> restore -> sha256 verify"
    - "sole-kill-site claims backed by a MEASURED green elsewhere, never asserted"
    - "equivalence-masked mutants documented and excluded from the kill count"
key-files:
  created:
    - .planning/phases/19-differential-mutation-battery-consumer-fixture/19-MUTATION-BATTERY.md
  modified: []
decisions:
  - "M2's kill site is the Phase-16 pure-lib harness ONLY; the plan's prediction that 19-01's differential kills it is REFUTED and the create_order entrypoint has no oversized-strike test"
  - "M2 is genuinely EQUIVALENT on the batch path: the module masks strike to 88 bits before validation, so `<= MAX_STRIKE` is dead code there"
  - "runs: 0 under a provably absent cache is a FIRST-INPUT failure, not a replay — proven by two differing counterexamples"
  - "M4 gained no new kill site from wave 1; the 65536 test remains its single point of failure"
metrics:
  duration_min: 24
  tasks: 3
  files_changed: 1
  completed: 2026-07-21
---

# Phase 19 Plan 03: Mutation Battery Part A Summary

The four semantic mutants named by MVER-02 re-applied to the CURRENT tree, each observed RED from a
cold fuzz cache with its verbatim FAIL line recorded, each mutated source restored sha256
byte-identical. **No kill is cited from a prior phase.**

## PART A TALLY

| Outcome | Count | Mutants |
| --- | --- | --- |
| Attempted | **5** | M1a, M1b, M2, M3, M4 |
| OBSERVED RED (counted) | **5** | M1a, M1b, M2, M3, M4 |
| **SURVIVORS** | **0** | — |
| UNCONSTRUCTIBLE | **0** | — |

**The survivor count is ZERO**, stated explicitly. M1a's primary edit form (`if 1 == 1 {`) compiled,
so none of the plan's three fallback forms was needed and no mutant was unconstructible.

## Restoration hashes

```
be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787  src/modules/pos_spec/VolOrderManagerMod.plk
5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35  src/lib/pos_spec/VolOrderValidationLib.plk
```

Both EQUAL to their pre-mutation baselines. `git diff --stat src/modules/pos_spec/ src/lib/pos_spec/`
is empty; `git status --short src/types/pos_spec/` is empty. Every mutant applied was restored; none
was left in the tree. Cold-cache green afterwards: pos_spec **40 passed / 0 failed** (15 suites),
pure-lib **13 passed / 0 failed**.

## Was M1a's red a VALUE red or a REVERT? — VALUE. No MCAL-04 finding.

The plan flagged a revert here as an MCAL-04 finding (a step in the structural enumeration not being
total). **No `EvmError: Revert` appeared anywhere in M1a's output.** Every red was a value, count or
byte-comparison red; `test__unit__batchOfOneEqualsSingleCall` and `test__unit__emptyBatchIsNoOp`
stayed green, and the totality fuzz failed on a count assertion (`15 != 6`), not a revert.

This re-confirms 18a's measurement on the current tree — including post-18b, where the return type
changed: M1a drove arbitrary unvalidated tuples through the entire post-validation store path and
produced no revert, so no step's totality was contradicted. **MCAL-04's structural enumeration
stands.**

## Did wave 1's new tests appear as kill sites? — YES, on three of five mutants.

| Mutant | 19-01 differential | 19-02 fixture |
| --- | --- | --- |
| M1a | **KILL SITE** (`fixedAnchorSequenceDiffers`, step 2) | **KILL SITE** (`N2_success_then_fail`) |
| M1b | **KILL SITE** (`_singleExpectRevertBoth`) | green |
| M2 | green — structurally cannot kill (see finding F1) | green |
| M3 | **KILL SITE** (anchor step 2; fuzz `orderCount 452 != 450`) | **KILL SITE** (`N3_mixed_seeded_C5`) |
| M4 | green (small ids) | green (small ids) |

**Direct evidence that 19-01 and 19-02 strengthened the suite rather than merely adding green.**
19-02's `N3_mixed_seeded_C5` reddened under M3 exactly as the plan predicted in advance — its golden
bytes pin `(true,6),(false,0),(true,7)` and the mutant emitted `(true,6),(false,0),(true,8)`.

**Honest counterpart: neither wave-1 plan added any coverage against M4.** Both operate at small ids,
where the ring mask is a no-op. Measured: under M4 the full sweep is 39 passed / 1 failed.

## Findings

### F1 — M2's kill site is narrower than the plan predicted (coverage gap; REPORTED, NOT fixed)

The plan predicted 19-01's differential would kill M2 because "the mock's `isValid` still applies
`strike <= 0xFFFFFFFFFFFFFFFFFFFFFF`". **Refuted by measurement:** under M2 the entire pos_spec suite
stayed green (40/0). Two structural causes:

1. **No pos_spec test ever delivers an oversized strike to the module.** Every strike is generated as
   `uint88` or `bound(..., 1, type(uint88).max)`, making a strike ≥ 2^88 unrepresentable in the
   corpus. The one `2 ** 88` reference (`diff.t.sol:183`) asserts against the **MOCK** inside
   `test__unit__refMockSelfPin` — the mock's bound is pinned while the module is never asked.
2. **On the batch path M2 is genuinely EQUIVALENT.** `create_orders` reads the strike as
   `@evm_shr(16, word) & 0xFFFFFFFFFFFFFFFFFFFFFF` — masked to 88 bits *before* validation — so an
   oversized strike is undeliverable and `<= MAX_STRIKE` is dead code there. No corpus could kill it.

M2 is killed only by `test__unit__strikeBoundBlocksSilentMasking` in the Phase-16 harness (a genuine
CALLED kill through `deployPlank`, and non-fuzz). **Consequence: the strike bound's enforcement
through the `create_order` ENTRYPOINT is unproven.** The strict path reads the strike unmasked
(`@evm_calldataload(4)`), so it *is* killable there — one `create_order` call with
`strike = (1 << 88) + 7` asserting a revert would close it. **Deliberately not added:** this phase
mutates and observes, it builds nothing. Carried to the phase exit record.

### F2 — the `runs: 0` acceptance criterion conflates two distinct conditions

`grep -c 'runs: 0'` == 0 is unsatisfiable for any mutant broad enough to be killed by the first fuzz
input. Rather than accept or discard it, I measured the distinction: with `cache/fuzz` provably
absent (`ls: cannot access 'cache/fuzz': No such file or directory`), two runs of the same fuzz test
produced two **different** counterexamples (`args=[7, 132, 6381]` vs
`args=[309485009821345068724781055, 1759, 200]`). A replay reproduces the same counterexample by
construction; a fresh search does not. `runs: 0` is forge's index of the failing run, and index 0 is
a legitimate first-input kill.

The criterion's real property — no kill rests on a replayed corpus — holds, and is independently
secured: **every kill in Part A stands on NON-FUZZ anchors.** Discard every fuzz result and all five
mutants remain killed.

### F3 — the `git diff --stat src/` criterion is UNSATISFIABLE (sixth instance of the pattern)

The user's uncommitted `src/lib/exposure/VegaIssuanceLib.plk` draft always shows. `19-CONTEXT.md`
both names it as the cause of the 14 exposure `setUp()` reverts and explicitly defers it. Resolved
per the 19-01/19-02 precedent by verifying the property instead: pos_spec trees clean in
`git status --short`, plus the two sha256 pins. Nothing contorted; the draft untouched. Future plans
should scope the criterion to `src/**/pos_spec`. Also present and not ours: untracked
`src/lib/protocol_integrations/` and `src/types/protocol_integrations/`.

## The equivalence-masked ledger

Seven entries written to `19-MUTATION-BATTERY.md`, all explicitly NOT COUNTED: the two v3.0 mutants
masked by `full_math`'s zero-denominator revert; the ring mask at small ids; guard-3's invisibility
to state assertions; 18b's unconstructible M7 (count reads 6, not 7); 18b's N=0/N≤1 blind spots; and
the `(false, id)` leak's all-invalid-on-fresh blindness.

**Entry 3 preserves a distinction that is easy to lose:** M4 the *mutant* is a real, counted kill;
what is excluded is any *small-id observation* of it. A later phase may not claim an M4 kill from a
small-id test.

## Deviations from Plan

### Strengthened beyond the plan

**1. [Rule 2 - Missing critical evidence] Measured the `runs: 0` question instead of voiding or accepting**
- **Found during:** Task 1, M1a
- **Issue:** The plan voids any observation containing `runs: 0` as a cache replay. Applying that
  literally would have discarded a legitimate kill; ignoring it would have accepted a possible
  replay. Neither is evidence.
- **Fix:** Re-ran with the cache's absence verified, obtained a different counterexample, and
  recorded the reasoning. See F2.
- **Commit:** `7337459`

**2. [Rule 2 - Missing critical evidence] Ran a FULL sweep under M4, not just the named contract**
- **Found during:** Task 2
- **Issue:** The plan asked for one contract to be shown green under M4. That supports the
  sole-kill-site claim weakly — it leaves 38 other tests unmeasured, including wave 1's new ones.
- **Fix:** Full `test/pos_spec/*` sweep under the mutant: 39 passed / 1 failed. This both proves the
  claim properly and surfaced the honest negative that wave 1 adds no M4 coverage.
- **Commit:** `6a80ba5`

**3. [Rule 2] Investigated M2's green rather than recording it as a bare non-kill**
- **Found during:** Task 1
- **Issue:** The pos_spec suite staying green under M2 contradicted the plan's stated prediction.
  Recording "green" without a cause would have left it ambiguous between a corpus gap and an
  equivalence.
- **Fix:** Traced it to two distinct structural causes (uint88-bounded corpus; pre-validation
  masking on the batch path), which separates the genuinely-equivalent batch path from the
  genuinely-uncovered strict path. See F1.
- **Commit:** `7337459`

### No source was improved

`src/` was mutated and restored only. No test was weakened or reshaped to manufacture a kill, and no
test was added to close F1. M2's narrow kill site is reported as a finding, which is the point.

## Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `7337459` | M1a, M1b, M2 observed fresh |
| 2 | `6a80ba5` | M3, M4 observed fresh |
| 3 | `5c5ac67` | ledger, tally, restoration audit |

## Self-Check: PASSED

- `.planning/phases/19-differential-mutation-battery-consumer-fixture/19-MUTATION-BATTERY.md` — FOUND
- commit `7337459` — FOUND
- commit `6a80ba5` — FOUND
- commit `5c5ac67` — FOUND
- module sha256 `be196dcb...cc9b8787` — MATCHES baseline
- lib sha256 `5fe71f30...73fe8f35` — MATCHES baseline
- pos_spec 40/0 green, pure-lib 13/0 green, both cold-cache
</content>
