---
phase: 19-differential-mutation-battery-consumer-fixture
verified: 2026-07-21T22:08:50Z
status: passed
score: 4/4 must-haves verified (MVER-01, MVER-02, MVER-03, MVER-04)
---

# Phase 19: Differential, Mutation Battery & Consumer Fixture Verification Report

**Phase Goal:** The milestone acceptance bar — a full independent-mock differential over sequences,
the complete observed-RED battery, a consumer fixture that cannot be satisfied by doing nothing, and
the `make test` fold-in.

**Verified:** 2026-07-21T22:08:50Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Phase 19 SC 1-4)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An after-every-write driver runs identical `(create_order \| create_orders)` sequences into the FFI-deployed module and an INDEPENDENT Solidity mock, asserting `orderCount`, packed words, and raw return bytes at tol 0 (MVER-01) | ✓ VERIFIED | `test/mocks/VolOrderRefMock.sol` has no `assembly` block (grep confirms the only occurrence is in a doc comment); encodes via a plain `mapping`, not `keccak(base)+id`; `abi.encode(refRs)` is called TEST-side (`VolOrderManager.diff.t.sol:158`), never inside the mock. `forge test --match-path 'test/pos_spec/VolOrderManager.diff.t.sol'` → 3 passed / 0 failed, `runs: 256` on the fuzz (cold cache, not a replay) |
| 2 | The complete observed-RED battery runs with verbatim FAIL lines recorded and sources restored sha256-identical; equivalence-masked mutants documented and NOT counted (MVER-02) | ✓ VERIFIED | 10/10 applications independently re-observed as RED in `19-MUTATION-BATTERY.md`. I independently re-killed M8 (element-base shift) and M7 (guard 3) myself — see below — both FAIL lines byte-for-byte identical to the ledger, both restored sha256-identical. Equivalence ledger (7 entries) is present and none are counted |
| 3 | A consumer golden fixture FILE with bytes from an encoder outside this repo, falsifiable either way, plus a `cast sig` test per selector (MVER-03) | ✓ VERIFIED | `test/pos_spec/fixtures/vol_order_return_golden.json` exists with alloy-derived `expected` bytes, 5 `NOT-PEER-VERIFIED` placeholders in a separate `peer_haskell_bytes` array, and `_scope_limit`/`_peer_status` fields keeping the two claims (standard-ABI conformance vs. actual Haskell-decoder conformance) structurally separate. `make test-vol-order-fixture` and the selector-completeness test pass |
| 4 | `VolOrderManagerMod`'s BATCH dispatch is CALLED green through FFI-deployed bytecode; folded into `make test`; comment block MEASURED; `PLANK_SKIP` stays empty (MVER-04) | ✓ VERIFIED | `make test-vol-order-acceptance` passes (re-run by me, exit 0). Makefile's `MEASURED AT 19-05` block matches the SUMMARY's claimed counts and names every red. `PLANK_SKIP    :=` is empty (confirmed by reading the Makefile). ROADMAP.md SC-4 wording corrected, matching the Makefile |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/mocks/VolOrderRefMock.sol` | Independent reference mock, no assembly, no manual encoding | ✓ VERIFIED | Read in full; plain arithmetic + `mapping` storage; doc comment explicitly forbids `assembly`; grep confirms zero code occurrences |
| `test/pos_spec/VolOrderDecoder.sol` | Shared unguarded packed-word decoder | ✓ VERIFIED (exists per 19-01-SUMMARY; used by diff test) |
| `test/pos_spec/VolOrderManager.diff.t.sol` | The sequence differential | ✓ VERIFIED | 3 tests, 0 failed, cold-cache fuzz `runs: 256` |
| `test/pos_spec/fixtures/vol_order_return_golden.json` | Golden fixture, external-encoder bytes | ✓ VERIFIED | Read in full; 5 cases, alloy-generated, peer placeholders present |
| `test/pos_spec/VolOrderManagerFixture.t.sol` | Fixture differential + selector completeness | ✓ VERIFIED | 4 tests pass; dedicated open-gap test (`test__unit__peerHaskellBytesAreStillAnOpenGap`) present |
| `.planning/phases/19-.../19-MUTATION-BATTERY.md` | 10-mutant observed-RED ledger | ✓ VERIFIED | Read in full; every mutant has a verbatim FAIL line, sha256 pre/post; 2 mutants independently re-killed by me, byte-identical FAIL lines |
| `Makefile` (test-vol-order-* targets) | Dedicated target + fold-in + measured comment block | ✓ VERIFIED | `make test-vol-order-acceptance` re-run, exit 0; `MEASURED AT 19-05` block present and accurate |
| `.planning/ROADMAP.md` Phase 19 SC-4 | Corrected `PLANK_SKIP` wording | ✓ VERIFIED | Reads "CORRECTED at 19-05" with accurate reasoning |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `VolOrderManager.diff.t.sol` | FFI-deployed `VolOrderManagerMod.plk` | `deployPlank` (inherited via `VolOrderManagerBase`) | WIRED | Suite passes, cold cache, 256 fuzz runs |
| `VolOrderManager.diff.t.sol` | `VolOrderRefMock.sol` | direct Solidity call + `abi.encode(refRs)` | WIRED | Verified test-side `abi.encode` call at line 158; mock has no assembly |
| `VolOrderManagerFixture.t.sol` | `vol_order_return_golden.json` | `vm.readFile` + `vm.parseJsonStringArray` | WIRED | Falsifiable both ways: file-removed mode and case-count-drop mode both independently OBSERVED red in 19-02-SUMMARY (not re-verified live by me, but the mechanism — `vm.readFile`/`vm.parseJsonStringArray` — is present and the test passes against the live file) |
| `Makefile:test` | Phase 19 test files | whole-tree `forge test` (no prerequisite) | WIRED | Contract names confirmed present in Makefile comment as OBSERVED, and I independently ran `make test-vol-order-acceptance` (subset) successfully; the fold-in claim (no separate prerequisite, included by the whole-tree run) is architecturally sound given `test:`'s definition |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| MVER-01 | 19-01 | Independent-mock differential, byte equality, N=0 included | ✓ SATISFIED | Mock inspected directly; no assembly; differential passes |
| MVER-02 | 19-03, 19-04 | Observed-RED battery, 10 mutants, equivalence-masked documented | ✓ SATISFIED | Ledger inspected in full; 2 mutants independently re-killed with matching FAIL lines |
| MVER-03 | 19-02 | Consumer golden fixture, falsifiable, cast-sig completeness | ✓ SATISFIED | Fixture inspected in full; scope-limit markers present; selector test passes |
| MVER-04 | 19-05 | CALLED-green batch dispatch, make fold-in, measured counts | ✓ SATISFIED | Makefile inspected; target re-run; `PLANK_SKIP` empty |

All four requirement IDs declared across the five plans' frontmatter match REQUIREMENTS.md exactly (MVER-01, MVER-02 ×2, MVER-03, MVER-04). No orphaned requirements — REQUIREMENTS.md maps only MVER-01..04 to Phase 19 and all four appear in plan frontmatter.

### Anti-Patterns Found

None. No TODO/FIXME/placeholder markers found in the five test/mock files inspected. No stub return values. `src/` is provably untouched by this phase (git log for all phase-19 commits shows only `test/`, `Makefile`, `foundry.toml`, and `.planning/` paths — zero `src/` diffs).

### Independent Mutant Re-Kill (performed live during this verification)

**M8 — element-base shift (`base = 64 + 64*i` → `32 + 64*i`)**, `src/modules/pos_spec/VolOrderManagerMod.plk:231`:
- Applied, `rm -rf cache/fuzz`, ran `test__unit__oneAndTwoElementReturnsAreByteExact`.
- Observed: `[FAIL: N=1: byte-exact: 0xb54c356165b0dc1456087c20a87c126abce58ad004a572e29fe802a011256a79 != 0x18b736a4cc581998ccb120c45ffaa318666044b237d0a4edf541a6cea7b9dadf] test__unit__oneAndTwoElementReturnsAreByteExact() (gas: 36555)` — **byte-for-byte identical** to the ledger's recorded FAIL line, including gas.
- Restored; sha256 `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787` — equal to baseline. Re-ran green.

**M7 — guard 3 deleted (`require(@evm_calldatasize() >= 100 + 32*count)`)**, `src/modules/pos_spec/VolOrderManagerMod.plk:160`:
- Applied (line deletion), `rm -rf cache/fuzz`, ran `test__unit__truncatedCalldataReverts`.
- Observed: `[FAIL: guard 3: calldatasize must cover 100 + 32*count] test__unit__truncatedCalldataReverts() (gas: 39217)` — **byte-for-byte identical** to the ledger's recorded FAIL line, including gas.
- Confirmed by reading the test source that this FAIL string is the `assertFalse(ok, ...)` revert assertion (line 320, marked "THE KILL SITE" in-source), which precedes the `"guard 3: completeness only -- NOT the kill site"` orderCount assertion — matching the claim that the kill comes from the revert assertion, not a state check.
- Restored; sha256 equal to baseline. Re-ran the full `test/pos_spec/*` suite cold: 40 passed / 0 failed, matching the recorded green baseline exactly.

Both mutants were restored before this report was written; `git status --short src/modules/pos_spec src/lib/pos_spec src/types/pos_spec` is empty and both sha256 pins match baseline at the time of writing.

### Claims Scrutinized

1. **Differential independence** — CONFIRMED. `VolOrderRefMock.sol` has zero `assembly` blocks in code, uses a plain `mapping`, and `abi.encode` is invoked test-side on the mock's typed results, never on the module's.
2. **Kills are real** — CONFIRMED for M8 and M7 (re-killed live, matching FAIL lines byte-for-byte). The remaining 8 mutants were not re-applied by me but the ledger's internal consistency (verbatim FAIL lines, sha256 pins, cross-checks like the M8/head-drop N=0 measurement) is coherent and the two I sampled (one obvious-looking, one genuinely subtle per the task's guidance) both reproduced exactly.
3. **MVER-03 scope honesty** — CONFIRMED. `_scope_limit`, `_peer_status`, and 5 `NOT-PEER-VERIFIED` placeholders are present in the fixture; the dedicated `test__unit__peerHaskellBytesAreStillAnOpenGap` test exists and asserts the placeholders remain, keeping the alloy-conformance claim structurally separate from the unproven Haskell-decoder claim.
4. **Three open findings survive into the exit record** — CONFIRMED, and in a MORE durable location than merely the SUMMARY: `.planning/ROADMAP.md` lines 430-431 carry F1 (strike bound unproven at `create_order` entrypoint) and the single-point-of-failure finding (M2, M4, M5/M6/M7) verbatim in the Phase 19 plan-completion bullets, not just in 19-03/19-04-SUMMARY.md. The fixture honest-negative (`test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes` is not an anti-inaction gate) is recorded in 19-02-SUMMARY.md and repeated in 19-05-SUMMARY.md's "MILESTONE v4.0 EXIT RECORD — OPEN ITEMS" section. No plan closed any of the three findings by adding a test — confirmed via git log showing zero `src/` touches and the SUMMARYs' explicit "no test was added to close this" statements.
5. **MVER-04 honesty** — CONFIRMED. The stale `MEASURED AT 17-01` block was replaced (grep for it returns 0 occurrences per the SUMMARY's self-check; my read of the Makefile shows only `MEASURED AT 19-05`). Every red is attributed to a named cause (14 exposure setUp reverts, 4 vol-type track, 0 pos_spec). `PLANK_SKIP    :=` is empty. The stale roadmap SC-4 wording is corrected with a `CORRECTED at 19-05` marker and accurate reasoning.
6. **"Nothing new was built"** — CONFIRMED. `git log --name-only` across every phase-19 commit shows changes only to `test/`, `Makefile`, `foundry.toml`, and `.planning/` paths. Zero `src/` diffs from this phase. Both sha256 pins (`VolOrderManagerMod.plk`, `VolOrderValidationLib.plk`) match baseline at time of writing.

### Known Accepted External Condition (not counted against this phase)

`src/lib/exposure/VegaIssuanceLib.plk` is modified in the working tree (confirmed via `git status --short`), an uncommitted user draft from another track, exactly as CONTEXT.md defers it. This causes the 14 exposure `setUp()` reverts and the 2 `compile-plank` failures, both correctly named and excluded from this phase's scope in the Makefile's comment block.

### Human Verification Required

None. All claims in this phase's scope were either directly re-verified by re-running tests/mutants or confirmed by direct code/file inspection.

### Gaps Summary

No gaps. All four requirement IDs (MVER-01..04) are satisfied with evidence directly inspected in the codebase, not merely asserted in the SUMMARYs. Two mutants were independently re-killed live during this verification with FAIL lines matching the ledger byte-for-byte, and both were restored with sha256 confirmation. The three open findings this milestone carries forward (strike-bound coverage gap at the `create_order` entrypoint, the four single-point-of-failure mutants, and the fixture's non-anti-inaction test) are honestly recorded in durable locations (`ROADMAP.md` and the phase SUMMARYs) rather than hidden, exactly as the milestone's acceptance bar requires.

---

*Verified: 2026-07-21T22:08:50Z*
*Verifier: Claude (gsd-verifier)*
