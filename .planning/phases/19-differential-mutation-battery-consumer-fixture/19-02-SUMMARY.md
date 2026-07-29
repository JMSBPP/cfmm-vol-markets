---
phase: 19-differential-mutation-battery-consumer-fixture
plan: 02
subsystem: pos_spec / VolOrderManagerMod consumer contract
tags: [MVER-03, golden-fixture, abi-encoding, selectors, falsifiability, cross-language]
requires:
  - "src/modules/pos_spec/VolOrderManagerMod.plk (18b return encoder, sha256 be196dcb...cc9b8787)"
  - "src/interfaces/pos_spec/VolOrderManagerInterface.plk (four pinned selectors)"
  - "test/pos_spec/VolOrderManagerBatch.t.sol (VolOrderManagerBatchBase helpers)"
provides:
  - "test/pos_spec/fixtures/vol_order_return_golden.json — 5-case alloy-produced golden bytes"
  - "test/pos_spec/VolOrderManagerFixture.t.sol — 4 CALLED-green tests (differential + completeness)"
  - "An INDEPENDENT third-encoder confirmation of 18b's 64+64N return layout"
  - "A per-case, machine-asserted marker for the undelivered peer Haskell bytes"
affects:
  - "foundry.toml (two additive fs_permissions entries)"
tech-stack:
  added: []
  patterns:
    - "External-encoder golden fixture committed as data, inputs stored as semantic triples not hex words"
    - "Anti-inaction gating: case count + per-case byte length + casesChecked tally"
    - "Observed falsifiability in BOTH modes (file removed, case count dropped)"
key-files:
  created:
    - test/pos_spec/fixtures/vol_order_return_golden.json
    - test/pos_spec/VolOrderManagerFixture.t.sol
  modified:
    - foundry.toml
decisions:
  - "cast abi-encode (alloy) independently confirms 18b's pinned layout including the N=0 64-byte edge — recorded as the milestone's strongest encoder evidence"
  - "alloy proves STANDARD ABI conformance, NOT the Haskell consumer's decoder — the two claims are kept structurally separate in fixture, test and summary"
  - "The plan's `git diff --stat src/` == empty criterion is UNSATISFIABLE at execution time due to a pre-existing foreign draft; verified the underlying property instead"
  - "The completeness gate was OBSERVED firing under a transient fifth marker rather than left as an assertion"
metrics:
  duration_min: 33
  tasks: 3
  files_changed: 3
  tests_added: 4
  completed: 2026-07-21
---

# Phase 19 Plan 02: Consumer Golden Fixture & Selector Completeness Summary

A committed fixture of `(bool,uint256)[]` return bytes produced by `cast abi-encode` (alloy) — an
encoder outside this repo — against which the FFI-deployed module's returndata is byte-identical
across 5 cases including N=0, plus a completeness gate proving the interface's four `signature::`
strings are all of them.

## What Was Built

**Nothing in `src/`.** This plan is pure evidence. Three artifacts:

1. `test/pos_spec/fixtures/vol_order_return_golden.json` — 5 cases of alloy-produced bytes, their
   inputs stored as `(strike, width, skew)` triples (never pre-computed hex words, so a
   transcription error in a 64-hex-digit literal is structurally impossible), and 5 explicit
   peer placeholders.
2. `test/pos_spec/VolOrderManagerFixture.t.sol` — 4 CALLED-green tests across two contracts.
3. `foundry.toml` — two additive `fs_permissions` read entries.

## Verbatim Command Outputs

### `cast --version`

```
cast Version: 1.5.1-stable
Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2
Build Timestamp: 2025-12-22T11:39:01.425730780Z (1766403541)
Build Profile: maxperf
```

Identical to the version the plan recorded, so no cast-version finding.

### `cast abi-encode "f((bool,uint256)[])"` — the five golden byte strings

Re-run by me at execution time. **All five matched the plan's recorded values character for
character**, and each was additionally re-derived from `cast` and diffed against the committed
file programmatically (`ALL 5 FIXTURE ENTRIES RE-DERIVED FROM cast, byte-identical`).

```
--- [] ---
0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
hexdigits=128 bytes=64
--- [(true,1)] ---
0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001
hexdigits=256 bytes=128
--- [(true,1),(false,0)] ---
0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
hexdigits=384 bytes=192
--- [(true,6),(false,0),(true,7)] ---
0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000007
hexdigits=512 bytes=256
--- [(false,0),(false,0),(false,0)] ---
0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
hexdigits=512 bytes=256
```

### `cast sig` — all four selectors, recomputed, never hand-derived

```
create_order(uint88,uint24,uint16)       -> 0x6501fe94
create_orders(uint256,uint256[])         -> 0x81357911
orderCount()                             -> 0x2453ffa8
getOrderPacked(uint256)                  -> 0xa9bcabc1
```

All four agree with the constants pinned in `VolOrderManagerInterface.plk`. **No divergence, so no
finding.** `grep -c 'signature::'` on the interface outputs `4`.

## The Independent-Encoder Confirmation (the headline result)

`cast`'s ABI coder is **alloy's** — a different implementation, by different authors, outside this
repository, consumed here as a committed file of bytes rather than as a library call. It
**INDEPENDENTLY CONFIRMS the exact layout Phase 18b pinned against solc**:

| Layout claim (18b) | alloy's bytes |
| --- | --- |
| outer offset `0x20` at byte 0 | confirmed, all 5 cases |
| length in **ELEMENTS** at byte 32 | confirmed (`0x02` for N=2, not `0x40`) |
| static `(bool,uint256)` tuples inlined, stride `0x40`, from byte 64 | confirmed at N=1,2,3 |
| total exactly `64 + 64N` | confirmed: 64 / 128 / 192 / 256 / 256 bytes |
| **N=0 is 64 bytes**, not 0 and not 32 | confirmed |
| canonical `success` word is exactly `1` | confirmed |

Two independent encoders (solc at 18b, alloy here) agreeing with the hand-rolled Plank encoder is
the strongest evidence in this milestone that the encoder is correct.

## SCOPE LIMIT — for the milestone exit record, do not blur these

- **(a) PROVEN here:** the module's return bytes are **STANDARD-ABI conformant**, confirmed by an
  encoder outside this repo.
- **(b) NOT PROVEN here:** that the **actual Haskell consumer's decoder accepts them**.

These are different claims. Peer `mv15a18k` (rpc_api / `StochasticOrderGen`, PR #9) has not
delivered Haskell-produced bytes. The gap is kept visible in four places so it cannot be quietly
absorbed by the alloy result: the fixture's `_scope_limit` field, its `_peer_status` field, five
`PLACEHOLDER -- NOT-PEER-VERIFIED` entries, and the dedicated machine-asserted test
`test__unit__peerHaskellBytesAreStillAnOpenGap`. **The cross-language gap remains OPEN.**

## Falsifiability — OBSERVED in both modes, not asserted

### Mode 1: fixture removed (mandated by the plan)

`mv test/pos_spec/fixtures/vol_order_return_golden.json /tmp/fx.json` then the suite. Verbatim:

```
[FAIL: vm.readFile: failed to open file "/home/jmsbpp/cfmms-playground/cfmm-wt/plank/test/pos_spec/fixtures/vol_order_return_golden.json": No such file or directory (os error 2)] test__unit__moduleReturnMatchesExternalEncoderFixture() (gas: 3595)
Suite result: FAILED. 0 passed; 3 failed; 0 skipped; finished in 25.96ms (498.49µs CPU time)
```

Middle command exit code **1**. File restored; suite green again.

### Mode 2: case count dropped 5 -> 4 (added by me — see Deviations)

The missing-file run fails at `vm.readFile` and therefore never reaches the anti-inaction *count*
gate. Since the plan's own truth claim says the test must fail "if the file is missing, empty, **or
its case count drops**", I exercised the second mode too. Verbatim:

```
[PASS] test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes() (gas: 10951)
[FAIL: MVER-03: the fixture must carry exactly 5 cases: 4 != 5] test__unit__moduleReturnMatchesExternalEncoderFixture() (gas: 21919)
[FAIL: one peer slot per case, so the gap is per-case visible: 4 != 5] test__unit__peerHaskellBytesAreStillAnOpenGap() (gas: 9608)
Suite result: FAILED. 1 passed; 2 failed; 0 skipped; finished in 21.84ms (877.14µs CPU time)
```

Fixture restored and confirmed byte-identical to the committed version (`git diff --quiet` clean,
sha256 `d1715a554e4e896f002e460cb3e2a40522022b01049b56076fb809160d6a629d`).

### Mode 3: an unpinned FIFTH selector (added by me)

The completeness claim was otherwise an assertion about a hypothetical future. Transiently appended
one extra `// signature:: cancel_order(uint256)` comment line to the interface. Verbatim:

```
[FAIL: MVER-03: all interface signature strings are pinned: 5 != 4] test__unit__everyInterfaceSignatureStringIsPinned() (gas: 941563)
Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 4.19ms (3.96ms CPU time)
```

Restored **sha256-identical** (`26950ff43ba429c3ea9bfe19179497ca8157a185d85721408a3864426fc70fc3`
before and after); `git diff --quiet` confirms the interface is unmodified vs HEAD; test green
again. This follows the project's standing observed-RED protocol, comment-only, sub-second window.

## Honest Negatives (record these, not just the pass count)

- **`test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes` is NOT an anti-inaction
  gate.** It stayed **GREEN** under the 5→4 case-count drop, because it reads `expected[0]` only
  and never consults `names.length`. MEASURED, above. The count gate lives solely in
  `test__unit__moduleReturnMatchesExternalEncoderFixture` and
  `test__unit__peerHaskellBytesAreStillAnOpenGap`. A future refactor that keeps only the N=0 test
  would silently lose the anti-inaction property.
- **The differential's `assertEq(got.length, want.length)` is a localisation aid, not a kill
  site.** The keccak comparison precedes it and subsumes it; per 18a's finding that forge reports
  only the first failing assertion per test, the discriminating assertion is deliberately first.

## Deviations from Plan

### Auto-fixed / strengthened

**1. [Rule 2 - Missing critical evidence] Observed the count-drop falsifiability mode**
- **Found during:** Task 2, after the mandated missing-file run
- **Issue:** The missing-file run fails at `vm.readFile`, so it does not exercise the
  `assertEq(names.length, 5)` gate at all. The plan's truth claim ("fails if the file is missing,
  empty, **or its case count drops**") would have shipped one third observed and two thirds
  asserted.
- **Fix:** Ran a 4-case variant, observed the verbatim red, restored byte-identically.
- **Commit:** `54720a6`

**2. [Rule 2 - Missing critical evidence] Observed the fifth-selector completeness gate**
- **Found during:** Task 3
- **Issue:** "Adding a fifth `signature::` without pinning it fails loudly" is the *entire* reason
  this contract exists beyond the pre-existing conformance test, and it was left unobserved.
- **Fix:** Transient comment-only mutant, verbatim red recorded, restored sha256-identical.
- **Commit:** `739b260`

### Findings (NOT fixed — reported)

**3. [FINDING] The `git diff --stat src/` == empty acceptance criterion is UNSATISFIABLE**

All three tasks carry the criterion "`git diff --stat src/` produces NO output". It cannot pass at
execution time, and **not because of anything this plan did**:

```
 src/lib/exposure/VegaIssuanceLib.plk | 14 ++++++++++++++
 1 file changed, 14 insertions(+)
```

This is the pre-existing uncommitted draft that `19-CONTEXT.md` itself names as the cause of the 14
exposure `setUp()` reverts, and which the same CONTEXT explicitly defers ("not this phase's file,
not this milestone's scope"). The criterion is therefore contradicted by a condition the plan is
forbidden to remedy. This is a new instance of the self-contradicting-criterion pattern
`19-CONTEXT.md` `<specifics>` warns about — the previous four instances were `grep == 0` gates
contradicted by mandated content; this one is a cleanliness gate contradicted by a pre-existing
foreign file.

**Resolution, per CONTEXT's instruction to verify the PROPERTY rather than contort code:** the
property the criterion exists to establish is *this plan touched no `pos_spec` source*. VERIFIED:

```
$ git status --short src/modules/pos_spec src/types/pos_spec src/interfaces/pos_spec src/lib/pos_spec
(no output)
$ sha256sum src/modules/pos_spec/VolOrderManagerMod.plk
be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787
```

Matching the pinned 18b baseline exactly. Future plans in this phase should scope the criterion to
`src/**/pos_spec` rather than all of `src/`.

## Verification Results

| Check | Result |
| --- | --- |
| `forge test --match-path test/pos_spec/VolOrderManagerFixture.t.sol` | **4 passed, 0 failed** (exit 0) |
| `forge test --match-contract VolOrderManagerSelectorCompletenessTest` | **1 passed** (exit 0) |
| `forge test --match-contract VolOrderManagerConformanceTest` | **3 passed** (pre-existing, undisturbed) |
| `forge test --match-path test/gamsDiff/PricingKernelPlank.diff.t.sol` | **1 passed** — fs_permissions edit is additive |
| `forge test --match-path 'test/pos_spec/*'` | **40 passed, 0 failed** (15 suites, incl. sibling 19-01's work) |
| python3 fixture structure check | `fixture OK` |
| 5 entries re-derived from `cast` | byte-identical |
| `grep -c 'cast abi-encode'` fixture | 1 |
| `grep -c 'NOT-PEER-VERIFIED'` fixture | 5 |
| `grep -c './test/gamsDiff/fixtures'` foundry.toml | 1 (survived) |
| `grep -c './test/pos_spec/fixtures'` foundry.toml | 1 |
| `grep -c 'assertEq(casesChecked, 5'` | 1 |
| module sha256 | `be196dcb...cc9b8787` — unchanged |
| interface sha256 | `26950ff4...c70fc3` — unchanged after mutant |
| `git status --short src/**/pos_spec` | clean |

All forge runs used `--via-ir --optimize`. The removed `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`
flag was **not** reintroduced.

## Carry-Forward for the Peer (`mv15a18k`)

The alloy fixture is now a **committed, machine-checkable contract document** the peer can encode
against directly: `test/pos_spec/fixtures/vol_order_return_golden.json`. When Haskell-produced bytes
arrive, replace the five `PLACEHOLDER -- NOT-PEER-VERIFIED` entries and **invert**
`test__unit__peerHaskellBytesAreStillAnOpenGap` into a real cross-language byte check (the way
`test__unit__batchSelectorNotYetDispatched` was inverted when 18a landed) rather than deleting it.
The hard requirements already flagged still stand: canonical offset `0x40` at byte 36 on input, the
N=0 **64-byte** return, and the canonical `success` word (solc *rejects* a truthy `2`).

## Commits

| Task | Commit | Description |
| --- | --- | --- |
| 1 | `6846db7` | cast-produced consumer golden fixture + fs_permissions |
| 2 | `54720a6` | fixture differential, both falsifiability modes observed |
| 3 | `739b260` | selector completeness, fifth-selector gate observed |

## Self-Check: PASSED

- `test/pos_spec/fixtures/vol_order_return_golden.json` — FOUND
- `test/pos_spec/VolOrderManagerFixture.t.sol` — FOUND
- `foundry.toml` — FOUND
- commits `6846db7`, `54720a6`, `739b260` — all FOUND in `git log`
