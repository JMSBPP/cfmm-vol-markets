---
plan: 01-03
phase: 01-red-differential-scaffold
status: complete
requirements: [RED-01, RED-02, RED-03, RED-05]
---

# 01-03 — RED differential test

## What landed

`test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol`, 316 lines, on
`feat/red-diff-scaffold`.

| Commit | Content |
|---|---|
| `1c78102` | doctrine header, cached wiring probe, helpers, two evidence tests |
| `263f96d` | `_assertAgree` three-outcome split, non-fuzz anchor, the fuzz |

## CI verification — run 33116421403 (`263f96d`), conclusion SUCCESS

Every step green, including `forge build` and `forge test`.

```
Ran 4 tests for .../VolOrderToPanopticTokenId.diff.t.sol:VolOrderToPanopticTokenIdDiffTest
[SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05).
       Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(...)
[SKIP: ...same reason...] test_differential__volOrder__anchor()
[PASS] test_implSide_answersOnAnchor()                      (gas: 17954)
[PASS] test_specHelper_stubRevertsAndProbeReportsNotWired()  (gas: 16680)
Suite result: ok. 2 passed; 0 failed; 2 skipped; finished in 134.24ms
```

Suite total `271 passed / 1 skipped / 272` -> `273 passed / 0 failed / 3 skipped / 276`.
Delta is exactly +2 passing evidence tests and +2 skipped differentials.

Regression floor held: `VolOrderToPanopticTokenId.t.sol` untouched and green.
`.github/` untouched — the skip is self-computed, NOT a `--skip` ledger entry, so the gate
compiles this file under `--via-ir` on every run and names it as skipped for a reason the file
itself states.

## Requirements

- **RED-01** — file exists and compiles under `--via-ir`. Verified by the run, not asserted.
- **RED-02** — doctrine header present, oriented NEITHER SIDE SACROSANCT.
- **RED-03** — discipline: zero `vm.assume` in code, corpus `bound`-constructed with the margin
  arithmetic written out, non-fuzz anchor named, non-vacuity asserted via the `comparisons` counter.
- **RED-05** — real `assertEq(specTokenId, implTokenId, "spec vs impl tokenId, tol 0")`, guarded by
  `vm.skip` on the cached probe, no skip-ledger edit.

## Deviations — three acceptance criteria the mandated content could not satisfy

All three were the SAME mechanism, and all three were criteria in the plan I authored: a naive
`grep -c` for a forbidden token matches the file's own prose forbidding it.

| Criterion | Hits | Where |
|---|---|---|
| `grep -c 'SpecOracle.health('` == 0 | 2 | doctrine header + `SKIP_REASON` string literal |
| `grep -c 'vm.assume'` == 0 | 4 | the doctrine line "There is not one vm.assume in this file" |
| `grep -c 'result.detail'` == 0 | 1 | `_assertAgree` natspec forbidding assertion on it |

Resolved by checking the criteria's stated INTENT — comments and string literals stripped first —
which returns 0 for all three. **No mandated content was deleted to satisfy a regex.** The plan's
criteria were corrected in place so the next reader does not hit them.

This is the fourth, fifth and sixth occurrence of this class in this project. The generalisable
rule: a `grep`-based prohibition over a token that the file must also DISCUSS needs comment and
string-literal stripping, or it forbids its own documentation.

## Open, carried forward

- The differential has never actually COMPARED anything — it cannot until Phase 7 wires the oracle.
  `comparisons` is 0 by construction today, and `test_specHelper_stubRevertsAndProbeReportsNotWired`
  asserts exactly that.
- `_provisionalWire` is a labelled placeholder; the wire format is Phase 4's (VORD-06). Exactly one
  `abi.encode(` call site exists, so Phase 4 replaces one function.
- Whether `try`/`catch` survives a cheatcode-originated revert is measured-true at 1.5.1 but remains
  open across versions; the low-level `address(probe).call` form assumes nothing about it.
