---
phase: 18b-typed-return-encoding
verified: 2026-07-21T16:46:09Z
status: passed
score: 6/6 must-haves verified
---

# Phase 18b: Typed Return Encoding Verification Report

**Phase Goal:** `create_orders` returns `(bool success, uint256 orderId)[]` encoded as head `0x40` /
stride `0x40` / total exactly `64 + 64*N` bytes, proven byte-exact against solc's standard
`abi.encode`.

**Verified:** 2026-07-21T16:46:09Z
**Status:** passed
**Re-verification:** No — this is a fresh verification pass (a prior verifier session died on a
session limit before writing any VERIFICATION.md; no partial artifact existed to resume from). All
work below was performed independently in this pass, reusing only the facts explicitly pre-verified
in the task brief ("already established" section — the `expectedReturn` independence, the 3-commit
range, and Claim 3/M5's fresh-vs-seeded-corpus result).

## Pre-existing Build State (external, out of phase scope)

The working tree carries an UNCOMMITTED, hand-written draft in
`src/lib/exposure/VegaIssuanceLib.plk` (a future-phase `calculate_vega_nominal` stub referencing an
unimported `VolOrder` identifier). Confirmed directly:

```
compile-plank: 11 ok, 2 failed, 0 skipped
```

with FAIL on `src/modules/exposure/VegaAccountMod.plk` and
`test/exposure/VegaIssuanceKernelHarness.plk` only. **`src/modules/pos_spec/VolOrderManagerMod.plk`
compiles OK** — confirmed directly via `make compile-plank 2>&1 | grep -A1 VolOrderManagerMod`. This
is orthogonal to 18b (exposure subsystem, not pos_spec) and does not affect the verdict below. It is
recorded here as a factual condition, not as a phase defect.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `create_orders` returns `(bool,uint256)[]` at head `0x40`, stride `0x40`, total exactly `64+64N` bytes | VERIFIED | Source `src/modules/pos_spec/VolOrderManagerMod.plk:181-266`: `@malloc_zeroed(64 + 64 * count)` before the loop, head words at `+%0`/`+%32`, per-iteration writes at `base=64+64*i`/`base+32`, `@evm_return(out, 64 + 64 * count)`. `test__unit__returnBuildersMatchTheStandardEncoder`, `test__unit__oneAndTwoElementReturnsAreByteExact`, `test__unit__mixedBatchReturnIsByteExact`, `test__unit__maxBatchReturnIsByteExactAndUncorrupted` all PASS, independently re-run |
| 2 | `keccak256(plank returndata) == keccak256(abi.encode(expected))`, expected side built by SOLC'S STANDARD encoder only | VERIFIED | `expectedReturn(BatchResult[] rs)` body is `return abi.encode(rs);` — confirmed byte-for-byte, no `mstore`/`assembly`/`<<` present (`awk` scan returns 0 matches). Genuinely independent oracle |
| 3 | `N=0` returns exactly 64 bytes, never reverts, `abi.decode` succeeds | VERIFIED | `test__unit__emptyReturnIsExactlySixtyFourBytes` PASS: asserts keccak equality, `ret.length==64`, word@0==0x20, word@32==0, live `abi.decode(ret,(BatchResult[]))` yields length 0, from BOTH a fresh and a seeded (C=5) counter |
| 4 | Positional alignment; canonical 0/1 success words; failed tuple is exactly `(false,0)` | VERIFIED | `test__unit__mixedBatchReturnIsByteExact` (middle-position failure, byte-exact incl. localisation words), `test__unit__allInvalidBatchReturnsAllFalseZero`, `test__unit__successWordsAreCanonicallyZeroOrOne` (raw-word `w<2` check, not decoded via `bool`) all PASS |
| 5 | Results buffer allocated before the loop; N=128 uncorrupted | VERIFIED | Source: single `@malloc_zeroed` call at line 205, before `let mut i = 0;` (209) and `while` (211). `test__unit__maxBatchReturnIsByteExactAndUncorrupted` PASS (byte-exact at 8256 bytes, plus `vm.load(orderSlot(128))` intact) |
| 6 | Every 18a state/guard assertion stays green through the return-type change | VERIFIED | Full re-run of `test/pos_spec/VolOrderManagerBatch.t.sol`: 21/21 tests pass (13 pre-existing 18a tests + 8 new). `test/pos_spec/VolOrderManager.t.sol` (single-call surface): 12/12 pass |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/modules/pos_spec/VolOrderManagerMod.plk` | hand-rolled `(bool,uint256)[]` encoder in `create_orders` branch, `@evm_return` present | VERIFIED | Contains exactly one `@evm_return(out, 64 + 64 * count)`; `return_u256(ok)` and `let mut ok = 0` both absent (grep count 0 for both, confirmed); compiles OK independently of the pre-existing exposure-track failures |
| `test/pos_spec/VolOrderManagerBatch.t.sol` | byte-level differential vs `abi.encode`, N=0/1/2/128 corpus, migrated `callBatch` | VERIFIED | `BatchResult` struct, `expectedReturn`, `callBatchRaw`, 8-test `VolOrderManagerReturnEncodingTest` contract all present and green; `callBatch` migrated to decode `(BatchResult[])` (old `r.length==32` guard and `abi.decode(r,(uint256))` both absent, confirmed by grep) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `VolOrderManagerMod.plk` | `@evm_return(out, 64 + 64 * count)` | buffer allocated before loop, written per-iteration | WIRED | Line-order check: malloc at 205 < `while` at 211. Runtime-confirmed by all N-parametrised tests passing including N=128 |
| `VolOrderManagerBatch.t.sol` | solc's standard encoder as independent oracle | `keccak256(raw returndata) == keccak256(abi.encode(BatchResult[]))` | WIRED | `expectedReturn` is a bare `abi.encode` call with zero manual byte construction (confirmed: 0 matches for `mstore|assembly|encodePacked|<<` inside its body) |
| `test/pos_spec/VolOrderManagerBatch.t.sol :: callBatch` | live decode boundary (silent-vacuity check) | `abi.decode(r,(BatchResult[]))` unconditionally on `ok`, no try/catch | WIRED, NOT VACUOUS | Traced `test__unit__dirtyHighBitsAreSkippedNotStored` and `test__unit__emptyBatchIsNoOp`: both route through `callBatch`, which calls `abi.decode` directly (no try/catch) — a decode failure would revert the whole test rather than silently yield `ret=0`. Both tests pass, meaning `abi.decode` genuinely succeeded and `ret` was genuinely computed from a real (possibly zero-length or zero-success) decoded array, never defaulted through a caught exception |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| MCAL-05 | 18b-01-PLAN.md | Hand-rolled typed return, byte-exact vs `abi.encode` | SATISFIED | All 6 truths above; REQUIREMENTS.md line 125 marked `[x]`, traceability row `Complete` |
| MCAL-06 (carried return-bytes clause) | carried from 18a-01, discharged in 18b-01 | N=0 exactly 64 bytes, well-formed empty result | SATISFIED | REQUIREMENTS.md line 128 `[18b-01 DISCHARGED]` sub-bullet, traceability row `Complete` (caveat dropped); historical 18a-01 PARTIAL note preserved at line 127 as audit trail (not orphaned — this is the correct disposition per the plan's own D1 instructions) |

No orphaned requirements: only MCAL-05 is declared in the plan frontmatter, and MCAL-06's carried
clause is explicitly cross-referenced and discharged in both REQUIREMENTS.md and the phase CONTEXT —
accounted for, not missing.

### Mutation Gate — Independently Re-Verified

Per the project discipline requiring an independent re-kill of at least two mutants, THREE were
re-killed in this pass (M1, M3, and the M7 scoping check), each applied against the live tree,
observed RED with `forge clean && rm -rf cache/fuzz` cleared first, then restored and confirmed
sha256-identical to the SUMMARY's recorded baseline `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`.

| Mutant | Applied | Observed RED (this session) | Matches SUMMARY | Restored sha256 |
|---|---|---|---|---|
| **M1** (element base shift `64+64*i` → `32+64*i`) | yes | `test__unit__mixedBatchReturnIsByteExact`: `"N=3 mixed: returndata must be byte-exact: 0xd9063a42... != 0xddf3f6c7..."` — **byte-for-byte identical hash prefixes to the SUMMARY's recorded FAIL line**. `test__unit__emptyReturnIsExactlySixtyFourBytes` independently confirmed GREEN under this mutant | YES, exact match | `be196dcb...` (identical) |
| **M3** (stride off-by-one-word `64+64*i` → `64+32*i`) | yes | `test__unit__oneAndTwoElementReturnsAreByteExact` reddened at `"N=2: byte-exact"` — meaning the earlier N=1 assertion (lines 632-637, evaluated first in program order) passed. This directly confirms the claimed N<=1 blindness: forge reports only the first failing assertion, and the first assertion to fail was the N=2 one, not N=1 | YES, matches claimed ordering | `be196dcb...` (identical) |
| **M7** (move buffer allocation to inside the loop, off the before-the-loop position) | yes | `make compile-plank` FAILS: `error: unresolved identifier 'out' --> ...VolOrderManagerMod.plk:265:21` — **exact match to the SUMMARY's claimed scoping-level finding** ("unresolved identifier 'out'"). This is a compile-time rejection, not a runtime-killable/unkillable mutant, confirming M7 cannot be constructed as a live mutant and is correctly excluded from the kill count | YES, exact match | `be196dcb...` (identical) |

Post-restoration, the full `test/pos_spec/VolOrderManagerBatch.t.sol` suite (21 tests) and
`test/pos_spec/VolOrderManager.t.sol` (12 tests) were re-run green, and `make compile-plank` returned
to the expected `11 ok, 2 failed, 0 skipped` (the 2 pre-existing exposure-track failures, unrelated to
this phase).

**Claim 4 disposition (M7 exclusion):** the SUMMARY's characterization is CORRECT and CONFIRMED — M7
is excluded because Plank's scoping rules make the before-the-loop allocation structurally required
(a `let` inside a `while` block is not visible to the trailing `@evm_return` outside it), not because
of an allocator-semantics argument that could be debated. The kill count of 6 (not 7) is accurate.

**Claim 6 (N=0 sanity):** independently confirmed via re-run of `test__unit__emptyReturnIsExactlySixtyFourBytes`, which asserts `abi.decode(ret, (BatchResult[]))` succeeds and yields a zero-length array from both a fresh and seeded (C=5) counter.

**M6 open question (storage-vs-return corruption at N=128 under-allocation):** the SUMMARY honestly
flags this as unresolved — forge reports only the first failing assertion, the keccak check fires
before the storage check, so it could not distinguish whether M6 also corrupts `orderSlot(128)`.
Assessment: this gap is ACCEPTABLE for this phase and does not block the goal. MCAL-05's return-byte
exactness is what this phase exists to prove, and that was reddened cleanly by M6 (the keccak
mismatch at N=128 IS observed). The storage question is orthogonal information about the *severity*
of an already-detected bug class, not a gap in the encoding proof itself; it does not need to be
closed to satisfy the phase's success criteria, and the SUMMARY's honest flag (rather than a guessed
answer) is the correct disposition.

### Anti-Patterns Found

None. No `TODO`/`FIXME`/`placeholder` markers, no stub returns, no console-log-only handlers in the
files this phase modified. `git diff --stat src/types/pos_spec/` across the 3-commit range is empty
(pre-verified and re-confirmed) — the vol-type track was not touched.

### Human Verification Required

None. All success criteria are automatically verifiable through `forge test` and direct byte/hash
comparison; nothing here depends on visual, real-time, or external-service behavior.

### Gaps Summary

No gaps. All 6 observable truths verified with direct evidence (not SUMMARY-trusted); both
requirement IDs (MCAL-05, and MCAL-06's carried clause) are satisfied and correctly cross-referenced;
3 mutants independently re-killed with FAIL-line and restoration-hash matches exact to the SUMMARY;
the one open question the executor flagged (M6 storage-vs-return) is assessed as an acceptable,
honestly-documented non-blocking gap rather than a defect. The pre-existing exposure-track compile
failures (`VegaAccountMod.plk`, `VegaIssuanceKernelHarness.plk`) are a factual, orthogonal build
condition caused by an uncommitted user draft outside this phase's scope and do not affect the
verdict.

---

_Verified: 2026-07-21T16:46:09Z_
_Verifier: Claude (gsd-verifier)_
