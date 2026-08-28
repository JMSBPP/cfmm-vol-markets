# Phase 2 / plan 02-04 gate evidence — VolOrder(T) over a region + the Extra(T) descriptor

> **This file was rewritten on 2026-08-28.** Its first version documented the `c9844d1` refactor
> (a local `none` tag, `vol_order_base`, `VolOrder(none)` everywhere). That design was REJECTED by
> the maintainer at the 02-04 chunk review and reverted by `3af40fb`; the assessment's §4 was
> superseded by §4a. Every number and identifier below comes from the design that is actually in
> the tree. The earlier runs are kept in "Superseded runs" because they are real facts about a
> design that was tried, measured and dropped — not evidence for what merges.

- **Implementation commit:** `dbc1259` (5 files) + `1dd1ce0` (negative-fixture fix)
- **Test commits (written FIRST, red):** `613ad65`, `e4f0e0d`
- **Branch:** `feat/volorder-t-minimal`  **PR:** https://github.com/JMSBPP/cfmm-vol-markets/pull/62 (draft)
- **GREEN run:** develop-gate [`33182346548`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33182346548) — approve/forge/plank/gate all success; push-build `33182342689` success
- **Baseline:** develop-gate `33168567137` (02-01 GATE_POST2), same toolchain (plank `00c0a1a`, forge `b0a9dd9`)
- **Harvested:** 2026-08-28

## The RED→GREEN sequence (AGENTS.md: tests are written RED first)

| Run | Result | What it established |
|---|---|---|
| [`33181053911`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33181053911) | RED | The tests DETECT the absence of the type: `unresolved identifier 'Extra'` ×2, `'extra_decode'` ×6, `'extra_encode'` ×2, `'vol_order_with_extra'` ×2, `unknown field` ×2. `compile-plank: 38 ok, 1 failed`; forge 76 suites / 273 passed / **1 failed**; floor still 10/10; 75 other suites ok. |
| [`33181644493`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33181644493) | plank green, forge 13/14 | The implementation compiles. **The negative test caught ITSELF being vacuous**: `test__unit__nonRegionTagDoesNotCompile` failed with *"VolOrder(u256) compiled; Extra must reject a non-region T"* — because the fixture's `bad()` was never called from `run{}`, and plank does not type-check unreachable code. Exactly the hazard `Makefile:compile-plank` documents. |
| [`33182346548`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33182346548) | **GREEN** | Fixture made reachable (`1dd1ce0`, fixture only — `Extra` unchanged). The `is_region` guard fires; 14/14. |

The middle run is the value of the order: under write-then-test that fixture would have sat green and meaningless.

## Criterion 2 — gate green; plank compiles the type; forge runs the full suite

| | 02-01 baseline `33168567137` | 02-04 `33182346548` |
|---|---|---|
| `Ran N test suites …` | `Ran 75 test suites in 6.41s (31.21s CPU time): 273 tests passed, 0 failed, 3 skipped (276 total tests)` | `Ran 76 test suites in 6.53s (32.41s CPU time): 287 tests passed, 0 failed, 3 skipped (290 total tests)` |
| `compile-plank:` | `compile-plank: 38 ok, 0 failed, 0 skipped` | `compile-plank: 39 ok, 0 failed, 0 skipped` |
| `Suite result: ok` / `FAILED` | 75 / 0 | 76 / 0 |

The deltas are exactly the new work and nothing else: **+1 suite** (`VolOrderType.t.sol`), **+14 tests**, **+1 plank entrypoint** (`test/types/pos_spec/VolOrderTypeHarness.plk`; `src/types/Extra.plk` has no `init` block so it is compiled transitively, not as an entrypoint). No pre-existing count moved.

## Criterion 3 — regression floor untouched and green (VORD-02 bit-identity)

`git diff origin/develop -- test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` → **0 bytes**.

    Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest
    Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 285.63ms (230.69ms CPU time)

Reinforced directly by a new fuzz test rather than only by the floor: `test__fuzz__tokenIdIsBitIdenticalOnTheNoPayloadPath(uint64)` (256 runs) compares the generic builder's id against the pre-refactor harness's `tokenIdFromVolOrder` for the same packed order and pool id.

## Criterion 5 — differential still compiles and skips; Phase 1 state preserved

    [SKIP: loop-conformance.json absent at offchain/rig/loop-conformance.json - run the live sequence] test__priceInvarianceUnderVolumePath()
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test__fuzz_differential__volOrder(...)
    [SKIP: spec oracle not wired: SpecOracle.health() reports TransportFailure (RED-05). Wired in Phase 7, enforced in Phase 11 (CI-04).] test_differential__volOrder__anchor()

Three `[SKIP` lines, identical to the baseline. `git diff origin/develop -- …diff.t.sol …SpecHelper.sol` → **0 bytes**.

## The 14 type tests (all passing)

`test__fuzz__packUnpackIsUnchangedByTheOptionField` · `test__unit__unpackYieldsANoneExtra` ·
`test__unit__readingThroughANoneExtraReverts` · `test__unit__panopticDescriptorDecodesToItsThreeFields` ·
`test__unit__emptyDescriptorDecodes` · `test__unit__panopticFlagWithTheWrongLengthReverts` ·
`test__unit__unflaggedDescriptorWithAPayloadLengthReverts` · `test__unit__reservedFlagBitsRevert` ·
`test__fuzz__descriptorSurvivesEncodeDecode` · `test__fuzz__packIgnoresExtraEntirely` ·
`test__fuzz__tokenIdIsBitIdenticalOnTheNoPayloadPath` · `test__unit__phase2MapStillHardcodesRatioOneAndNoAsset` ·
`test__unit__nonRegionTagDoesNotCompile` · `test__unit__extraFieldsNeedUnwrap`

    Ran 14 tests for test/types/pos_spec/VolOrderType.t.sol:VolOrderTypeTest
    Suite result: ok. 14 passed; 0 failed; 0 skipped; finished in 479.43ms (220.45ms CPU time)

## ABI edge — frozen surface (CONTEXT.md)

PRE (02-02, run `33169215017`) vs POST (02-04, run `33182342689`):

    abi-edge sha256: e801b0e1dea74b1316ce8991663c914da64b31ab359127c67f56a788689077d9   (pre)
    abi-edge sha256: 3bca10fc733de57182329d8b543ec850256cd7e29fce9bd20beaa2e598bf5b2b   (post)
    abi-edge selector: 0x08c379a0  0x4e487b71  0x728ebb96  0xa00af595
    abi-edge selector: 0xed7143d4  0xfe7ebf55  0xffffffff
    abi-edge selector-count: 7   (both)

**Selector set: IDENTICAL** — all 7, including the four dispatch selectors `0xfe7ebf55` `0xa00af595`
`0xed7143d4` `0x728ebb96`. **sha256: DIFFERENT** — the harness now passes `calldata` to a builder
whose signature gained a `comptime T`, so the compiled bytes moved while the dispatch surface did
not. The surface claim rests on the selector set plus the untouched golden vectors passing 10/10,
which is what the 02-02 baseline said would be judged either way.

## Superseded runs (kept as history, NOT evidence for what merges)

- `33171200236` / `33171197208` — green on `c9844d1`, the local-`none`-tag design. Real measurements
  (75 suites / 273 / 0 / 3; `compile-plank: 38 ok`; selector set identical; sha256 `eb063608…`), but
  of code the maintainer rejected at chunk review and `3af40fb` removed. Nothing in the merged tree
  corresponds to them.
- `33176185381`, `33178710089`, `33180603688` — earlier RED legs of superseded test drafts.

## Anomalies

1. **The negative test was vacuous until `1dd1ce0`** — see the RED→GREEN table. Second instance in
   this phase of "unreachable Plank code is never type-checked"; the first was the `compile-plank`
   note it is derived from.
2. **`@248` in NatSpec is solc Error 6546**, hit TWICE in `VolOrderType.t.sol` (first with
   `@compile_error`, then with the bit offsets). `test/pos_spec/VolOrderDecoder.sol` already
   documented the trap; the reference is now in this file's NatSpec too.
3. **`std::slice::Slice(R, T, arity)` exists at plank `00c0a1a`** (absent at the old pin) and is the
   typed region-generic view a Phase 3 dereference should build over the four ratios —
   `Slice(T, u256, Some(4))`. Recorded so Phase 3 does not reinvent it.
4. **sha256 moved with the selector set fixed** — internals only, as in the superseded run.
5. Backticks in a `git commit -m` string were executed by bash, silently deleting two spans from
   `dbc1259`'s message; amended from a file (`--force-with-lease`). Use `-F` for messages containing
   backticks.
