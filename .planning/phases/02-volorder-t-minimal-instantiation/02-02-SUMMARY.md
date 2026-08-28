---
phase: 02-volorder-t-minimal-instantiation
plan: 02
status: complete
completed: 2026-08-28
executor: superpowers inline (maintainer session) — per the phase EXECUTION GATE
requirements: [VORD-02, VORD-03]
duration: ~55 min wall-clock (four gate/push cycles)
---

# 02-02 — ABI-edge stamp + the one-time `--skip` probe

## Identifiers

| | |
|---|---|
| Stamp commit | `f626408` (Makefile `abi-edge-stamp` + additive push-build step, +16/−0) |
| RUN_STAMP (push-build) | `33169215017`, job `98841958358`, step "Harness ABI edge stamp" = success |
| Same-push gate | `33169217185` success, 75 / 273 / 0 / 3 |
| **Stamp sha256** | `e801b0e1dea74b1316ce8991663c914da64b31ab359127c67f56a788689077d9` |
| **Selector set (7)** | `0x08c379a0 0x4e487b71 0x728ebb96 0xa00af595 0xed7143d4 0xfe7ebf55 0xffffffff` |
| Baseline record | `02-02-ABI-EDGE-BASELINE.md` (`3880164`) |
| PROBE_SHA | `f815e25260ad1ddc1a0e47a9527c4bf1ace86807` (THROWAWAY, both workflows, parity 1 pattern) |
| GATE_PROBE / PUSH_PROBE | `33169585831` (forge FAILED as expected) / `33169580954` (failure, corroborates) |
| REVERT_SHA | `7e32678a4daa61da3080cec0181f1170cfae2931` |
| GATE_REVERT | `33169960869` success, `Ran 75 test suites … 273 passed, 0 failed, 3 skipped` |
| Probe record | `02-02-SKIP-PROBE.md` |
| **PROBE_ISSUE** | **#63** — #16 untouched (CLOSED) |

## Measured status of the two masked suites (plank `00c0a1a`, forge `b0a9dd9`, seed 4880)

- `VolRangeWidth.t.sol` — **RED**: 16 passed / 2 failed (`volWidthRangeBuildVolRangeWidth_valid` args=[23,0,0] runs:0; `volWidthRangeSub_valid` args=[3445,1,0] runs:39)
- `SpreadTickAssimetryHelper.t.sol` — **RED**: 1 passed / 2 failed (`spreadTickAssimetrySplitTick__Valid` args=[7,0,…] runs:0; `tickFromSplittedTickBucket__Valid` runs:0)
- Whole suite 77 / 290 / 4 / 3 vs 75 / 273 / 0 / 3 — delta is exactly the two suites. Consistent with
  the ledger comment's "seed-dependent (2/3/6)"; 4 is a new count. → both files **UNVERIFIED** in 02-03.

## Deviations / anomalies

- `git revert -q` is not a flag; the first revert did nothing and pushed nothing. Caught by the
  plan's own 0-byte diff check (read 570), re-run correctly. No wrong state was ever pushed.
- Three of four probe failures fail at `runs: 0` on inputs with a literal `0` in a tick-spacing slot —
  recorded on #63 as an observation about the tests' input bounds, explicitly not a conclusion.
- Stamp selector set carries 3 non-dispatch PUSH4s (`Error(string)`, `Panic(uint256)`, `0xffffffff`) —
  part of the frozen set; 02-04 must match all 7.

## Untouched, proved

`develop-gate.yml` → 0 bytes vs `origin/develop` after the revert; `push-build.yml` 0 deletions;
parity `3 patterns, seed 4880`; harness and `VolOrder.plk` 0 bytes vs `develop` when the stamp was taken.
