---
phase: 16-type-packing-validation-foundation
verified: 2026-07-20T00:00:00Z
status: passed
score: 6/6 must-haves verified
---

# Phase 16: Type Packing & Validation Foundation Verification Report

**Phase Goal:** The pure validation surface exists and is proven falsifiable in isolation — reusing the two sound predicates verbatim, authoring the one bound that is genuinely missing (strike <= 2^88-1), over the existing 152-bit packer used AS-IS, via an FFI-deployed harness (a Plank pure lib is unreachable from Foundry without one).
**Verified:** 2026-07-20
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A constructed fuzz CALLS validate_order through FFI-deployed bytecode and at least one tuple is ACCEPTED | ✓ VERIFIED | `make test-vol-order-validation` green on cleared cache with `runs: 512` real fuzz. `test__unit__anchorValidTupleAccepted` asserts ACCEPT; mutant M4 (`let res = false;`) independently re-applied by this verifier and observed RED on exactly that assertion `[FAIL: anchor tuple must be ACCEPTED (all-reject validator fails here): 0 != 1]`, proving the tripwire live. |
| 2 | Skew 0 rejected, 1 accepted, 65534 accepted, 65535 rejected, each asserted individually | ✓ VERIFIED | Four separate passing tests: `test__unit__skewZeroRejected`, `test__unit__skewOneAccepted`, `test__unit__skew65534Accepted`, `test__unit__skew65535Rejected`, all green. |
| 3 | Strike >= 2^88 rejected by the newly-authored bound; the test demonstrates the prevented corruption is SILENT (value change, not revert) | ✓ VERIFIED | `test__unit__strikeBoundBlocksSilentMasking` packs strike `2^88+7`, unpacks it to `7` (value change), then asserts `validateOrder` rejects it. Independently re-killed M1 (bound deleted) by this verifier: `[FAIL: strike >= 2^88 must be REJECTED: 1 != 0]` — a value mismatch, not a revert. |
| 4 | pack/unpack round-trip at tolerance 0 with TICK_SPACING=20, checked against an independently re-derived layout `width@128\|tickSpacing@104\|strike@16\|skew@0` | ✓ VERIFIED | `test__fuzz__validTuplesAcceptedAndRoundTrip` (512 constructed runs) and `test__unit__anchorRoundTrip` both compare against `_expectedWord` built independently in Solidity from documented shift offsets, not ported from the Plank source. |
| 5 | Every mutant OBSERVED RED against a named non-fuzz assertion; every source restored byte-identical (sha256) to green | ✓ VERIFIED | Six mutants (M1-M6) recorded in-file with verbatim FAIL lines and sha256 `5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35`. This verifier independently re-applied M1 and M4, confirmed identical FAIL lines, restored, and reconfirmed sha256 match and green suite both times. |
| 6 | No file under `src/types/pos_spec/` was modified | ✓ VERIFIED | `git diff 2699546~1 HEAD --stat -- src/types/pos_spec/` produced empty output. `git status --porcelain src/types/pos_spec/` empty at every checkpoint during this verification, including during the two independently re-run mutants. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/lib/pos_spec/VolOrderValidationLib.plk` | Pure bool-returning `validate_order` core + thin reverting wrapper + `build_vol_order` with TICK_SPACING pinned | ✓ VERIFIED | Exists, `grep -c 'const validate_order'` = 2 (core + `validate_order_strict`). `TICK_SPACING = 20` pinned, `MAX_STRIKE = 0xFFFFFFFFFFFFFFFFFFFFFF` byte-identical to `VolOrder.plk:38`'s mask. `wrap_spread_tick_assimetry` occurs only in a comment line (grep of code lines = 0). |
| `test/types/pos_spec/VolOrderValidationHarness.plk` | FFI `run{}` entrypoint, 4 selectors | ✓ VERIFIED | Contains `init { return_runtime(); }`; all four `cast sig` outputs recomputed independently and matched the constants exactly (validateOrder=0x1b6f447e, validateOrderStrict=0x87a10138, packVolOrder=0x75b370cd, unpackVolOrder=0x729f096f). `@mstore32` offsets are 0/32/64/96, all distinct — the SpreadTickAssimetry.plk:69-71 duplicate-offset bug is not reproduced (`out_ptr`, `out_ptr +% 32`, `out_ptr +% 64`, `out_ptr +% 96`). |
| `test/types/pos_spec/VolOrderValidation.t.sol` | The single test file for this surface | ✓ VERIFIED | 3 contracts, 13 tests, all passing. `deployPlank` used (no hand-rolled `Dependency[]`). `vm.assume` count = 0. Every fuzz test has a non-fuzz unit anchor beside it. |
| `Makefile` | `test-vol-order-validation` target | ✓ VERIFIED | Target present at line 137, `.PHONY` entry present at line 140, `make test-vol-order-validation` runs and passes. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `VolOrderValidationLib.plk` | `VolRangeWidth::vol_range_width_is_complete` | verbatim conjunct | ✓ WIRED | `vol_range_width_is_complete(self.rangeWidth)` present verbatim at line 68. |
| `VolOrderValidationLib.plk` | `SpreadTickAssimetry::spread_tick_assimetry_is_complete` | verbatim conjunct | ✓ WIRED | `spread_tick_assimetry_is_complete(self.skew)` present verbatim at line 68, alongside the newly-authored `strike_fits_packed(self.volStrike)` (composes rather than replaces the tick_volatility_is_complete-derived gap). |
| `VolOrderValidationHarness.plk` | `lib::pos_spec::VolOrderValidationLib` | import + selector dispatch | ✓ WIRED | `import lib::pos_spec::VolOrderValidationLib::*;` present; all four selectors dispatch to lib functions. |
| `VolOrderValidation.t.sol` | `VolOrderValidationHarness.plk` | `deployPlank` FFI | ✓ WIRED | `deployPlank("test/types/pos_spec/VolOrderValidationHarness.plk")` called in shared `setUp()`. |
| `pack_vol_order`/`unpack_vol_order` | `VolOrder.plk` | used AS-IS via `import pos_spec::VolOrder::*` | ✓ WIRED | Called verbatim in both the lib and the harness; never redefined; `src/types/pos_spec/VolOrder.plk` byte-unchanged for the whole phase. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| VORD-02 | 16-01-PLAN.md | Pure `validate_order` reuses `spread_tick_assimetry_is_complete`/`vol_range_width_is_complete` verbatim, authors `strike <= 2^88-1`, skew semantics [1,65534] with all four boundaries asserted | ✓ SATISFIED | All observable truths above hold; REQUIREMENTS.md marks `[x]` complete and traceability table shows `VORD-02 \| Phase 16 \| Complete`, consistent with observed evidence. |

No orphaned requirements found for Phase 16 — VORD-02 is the only requirement mapped and it is claimed in the plan frontmatter.

### Anti-Patterns Found

None. `grep` for TODO/FIXME/PLACEHOLDER/HACK across `src/lib/pos_spec/VolOrderValidationLib.plk`, `test/types/pos_spec/VolOrderValidationHarness.plk`, and `test/types/pos_spec/VolOrderValidation.t.sol` returns nothing load-bearing (no stubs, no empty-return handlers, no console-log-only implementations). `packVolOrder` deliberately does not validate — this is documented and intentional (needed to witness the silent masking the strike bound test exercises), not a stub.

### Human Verification Required

None. All claims in this phase are mechanically verifiable via `forge test`, `cast sig`, `sha256sum`, and `git diff`, and all were independently re-derived by this verifier rather than trusted from the SUMMARY.

### Independent Verification Performed (beyond re-reading the SUMMARY)

- Cleared `cache/fuzz` and re-ran `test/types/pos_spec/VolOrderValidation.t.sol` from scratch: 13/13 passed, fuzz test showed real `runs: 512` (never `runs: 0`).
- `make compile-plank`: `12 ok, 0 failed, 0 skipped`.
- `make test`: `87 passed, 4 failed` — the 4 failures are exactly `SpreadTickAssimetryTest` (x2) and `VolRangeWidthTest` (x2), matching the pre-existing vol-type-track failures named in the task; no new failures, none filtered.
- Recomputed all four `cast sig` selectors independently; all matched the harness constants exactly.
- `git diff 2699546~1 HEAD --stat -- src/types/pos_spec/` is empty.
- Independently applied mutant M1 (deleted the authored strike bound): observed RED `[FAIL: strike >= 2^88 must be REJECTED: 1 != 0] test__unit__strikeBoundBlocksSilentMasking() (gas: 14229)` — byte-identical to the SUMMARY's recorded verbatim line, a value mismatch not a revert. Restored via `git checkout --`; sha256 confirmed `5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35`; re-ran green (13/13).
- Independently applied mutant M4 (`validate_order` body replaced with `false`): observed RED `[FAIL: anchor tuple must be ACCEPTED (all-reject validator fails here): 0 != 1] test__unit__anchorValidTupleAccepted() (gas: 9284)` plus 5 other cascading failures — matching the SUMMARY's recorded battery entry, confirming the "at least one tuple ACCEPTED" tripwire is live, not decorative. Restored via `git checkout --`; sha256 confirmed identical; re-ran green (13/13).
- `grep -c 'vm.assume' test/types/pos_spec/VolOrderValidation.t.sol` → `0`.
- Confirmed a non-fuzz unit anchor exists beside every fuzz test (`test__fuzz__validTuplesAcceptedAndRoundTrip` ↔ `test__unit__anchorRoundTrip`).

### Gaps Summary

None. All six must-have truths, all four required artifacts, and all five key links verify against the actual codebase, not merely against the SUMMARY's claims. Every numeric/hash/selector claim in the SUMMARY was independently recomputed and matched.

---

*Verified: 2026-07-20*
*Verifier: Claude (gsd-verifier)*
