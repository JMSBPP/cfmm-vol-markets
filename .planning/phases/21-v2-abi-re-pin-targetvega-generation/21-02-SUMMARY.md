---
phase: 21-v2-abi-re-pin-targetvega-generation
plan: 02
subsystem: testing
tags: [anvil, foundry, cast, eth_call, abi, jq, python3, provenance, golden-fixture]

# Dependency graph
requires:
  - phase: 20-deploy-rig-source-of-truth-import
    provides: "deploy-rig.sh (anvil lifecycle + rig-manifest.json), verify-rig.sh (SC-2), generate-pins.sh / rig-pins.json, the zero-literal discipline"
  - phase: 19-differential-mutation-consumer-fixture
    provides: "test/pos_spec/fixtures/vol_order_return_golden.json — the alloy-produced external-encoder golden this capture is diffed against"
provides:
  - "offchain/rig/capture-batch-return.sh — a re-runnable, zero-hex-literal eth_call capture of the live V2 (bool,uint256)[] batch return"
  - "offchain/rig/batch-return-capture.json — four OBSERVED returndata strings with chainId / manager / blockNumber provenance and the calldata that produced each"
  - "First on-chain OBSERVATION of the V2 batch return (previously derived from emitter source only)"
  - "Live evidence that targetVega = 2^96 is SKIPPED, indistinguishable from a business rejection"
affects: [21-03, 21-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Chain-touching work isolated to one script; the committed JSON keeps the Haskell suite chain-independent"
    - "Provenance travels WITH the artifact because the manifest it came from is gitignored"
    - "python3 for >64-bit bit-packing, emitting DECIMAL that cast calldata accepts — bash arithmetic cannot hold a 224-bit word"

key-files:
  created:
    - offchain/rig/capture-batch-return.sh
    - offchain/rig/batch-return-capture.json
  modified:
    - offchain/rig/README.md

key-decisions:
  - "[21-02 MEASURED] All THREE golden comparisons match byte-for-byte, not just N0_empty — eth_call never advances orderCount, so every case sees a registry as fresh as the golden's. The plan's differs_only_in_order_ids escape hatch was built and never needed."
  - "[21-02 FINDING] generatedAt has 1-second resolution and the capture takes ~294 ms, so two back-to-back runs SHARE a timestamp. The Phase-20 idempotence recipe inherited from deploy-rig.sh (tens of seconds) does not transfer. Regeneration was proven by deleting the artifact first."
  - "[21-02 CONFIRMED F1] src/modules/pos_spec/VolOrderManagerMod.plk:177-188 is a STALE V1 comment contradicting its own file's V2 code at 229-235. REPORTED to the plank track, never edited."

patterns-established:
  - "Falsify-before-trust carried forward: the capture script's four self-checks would each exit 1 on the F1 trap rather than emitting a plausible all-invalid artifact"
  - "Hard-failure vs finding is decided IN the script: N0_empty mismatch exits 1; a golden difference confined to orderId words is recorded, anything else exits 1 naming it a FINDING"

requirements-completed: []  # RPIN-05 deliberately NOT marked — see "RPIN-05 left pending" below
requirements-advanced: [RPIN-05]

# Metrics
duration: 6min
completed: 2026-08-01
---

# Phase 21 Plan 02: Live V2 Batch-Return Capture Summary

**The V2 `(bool,uint256)[]` batch return has now been OBSERVED on chain for the first time — four cases captured off a live anvil rig into a provenance-bearing committed artifact, with all three golden-comparable cases byte-identical to the v4.0 alloy fixture and the out-of-band `targetVega` proven to skip silently.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-08-01T18:27:01Z
- **Completed:** 2026-08-01T18:32:52Z
- **Tasks:** 2
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- Stood the Phase-20 rig up from a machine with **no anvil running** (the `<current_facts>` claim that anvil was already up was STALE — `pgrep anvil` was empty at execution start) and passed the SC-2 gate.
- Captured four real returndata strings through `eth_call`, ending the "derived from emitter source, never observed" status of the V2 batch return.
- Proved `N0_empty` is **exactly 64 bytes** and byte-identical to an encoder outside this repo.
- Proved on a live chain that `targetVega = 2^96` returns `(false, 0)` — the concrete justification for the client-side `in_range 96` guard that plan 21-01 is building.
- Five capture runs produced one normalised sha256; the artifact is reproducible.
- Confirmed hazard F1 empirically and left the plank track's file untouched.

## Task Commits

1. **Task 1: Stand the rig up and write `capture-batch-return.sh`** — `bc8414a` (feat)
2. **Task 2: Run the capture, prove idempotence, diff against the v4.0 golden, document it** — `bc58f32` (feat)

## Files Created/Modified

- `offchain/rig/capture-batch-return.sh` — 285 lines. Reads the manager from `rig-manifest.json` with `jq`, builds V2 input words in `python3`, issues four `cast call`s, runs four self-checks, folds the golden comparison in, and emits the artifact with `jq -n`. **Zero 8/40/64-hex literals.**
- `offchain/rig/batch-return-capture.json` — the committed capture: `generatedAt`, `chainId`, `manager`, `blockNumber`, `signature`, `_provenance`, `_scope_limit`, `_golden_diff`, and four `cases`.
- `offchain/rig/README.md` — new "Capturing the batch return" section under the clean-machine sequence.

---

## Verbatim record (required by the plan's `<output>`)

### 1. `verify-rig.sh` — the hard-stop gate

```
SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded (packed=1766847064778384329583297500742918515827483896875618958121606202992619776)
```
exit 0. The rig deployed to `VolOrderManagerMod = 0x5fbdb2315678afecb367f032d93f642f64180aa3`, chainId 31337 — the same address 20-03 measured as reproducible across from-scratch deploys, read from the manifest rather than carried.

### 2. The four captured returndata strings

Captured at **block 9**, `orderCount = 0` (probe 2 of `verify-rig.sh`).

| name | n | bytes | returndata |
|---|---|---|---|
| `N0_empty` | 0 | **64** | `0x0000…0020` `0000…0000` |
| `N1_success` | 1 | 128 | `0x0000…0020` `0000…0001` `0000…0001` `0000…0001` |
| `N2_success_then_fail` | 2 | 192 | `0x0000…0020` `0000…0002` `0000…0001` `0000…0001` `0000…0000` `0000…0000` |
| `N1_dirty_vega` | 1 | 128 | `0x0000…0020` `0000…0001` `0000…0000` `0000…0000` |

Full, unelided strings (the table above is word-abbreviated for reading; these are the bytes):

```
N0_empty
0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000

N1_success
0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001

N2_success_then_fail
0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

N1_dirty_vega
0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```

Byte lengths: **64, 128, 192, 128** — each exactly `64 + 64*n`.

### 3. Idempotence — both `generatedAt` values

The plan's recipe required two runs whose `generatedAt` DIFFER. **The first attempt did not produce that**, and the reason is a finding, not an accident:

- **Attempt 1 (runs 1 and 2, back to back):** normalised diff EMPTY, both sha256 `786c9506f7a30acf284311f5022540198eaf78d3393d292272df59d7824c0cd7` — but `generatedAt` was **`2026-08-01T18:30:37Z` for BOTH**. One capture run takes **294 ms**; `generatedAt` has 1-second resolution. So the equal-timestamp case is the NORMAL case for this script, and a stale artifact would have passed that check silently.
- **Attempt 2 (runs A and B), re-measured properly:** the artifact was `rm`'d before each run — a stale file structurally cannot survive that — and the second run was gated on the wall-clock second rolling over.
  - run A `generatedAt` = **`2026-08-01T18:31:02Z`**
  - run B `generatedAt` = **`2026-08-01T18:31:03Z`**
  - normalised diff (`jq -S 'del(.generatedAt, .blockNumber)'`): **EMPTY**
  - both sha256 `786c9506f7a30acf284311f5022540198eaf78d3393d292272df59d7824c0cd7`
- **Run C** (after folding `_golden_diff` in and re-running per STEP 4): same sha256 `786c9506…824c0cd7`.

Five runs, one normalised sha256. **The returndata did not move between runs against the same rig** — no averaging, nothing to report as a disagreement.

### 4. Golden comparison — each pair side by side

Compared positionally against `test/pos_spec/fixtures/vol_order_return_golden.json` `expected[0..2]`.

```
[0] N0_empty
golden : 0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
live   : 0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000

[1] N1_success
golden : 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001
live   : 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001

[2] N2_success_then_fail
golden : 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
live   : 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```

`_golden_diff` as recorded in the artifact:

```json
{
  "N0_empty":             { "matches_golden": true, "differs_only_in_order_ids": false },
  "N1_success":           { "matches_golden": true, "differs_only_in_order_ids": false },
  "N2_success_then_fail": { "matches_golden": true, "differs_only_in_order_ids": false }
}
```

**Zero disagreements.** Nothing was reconciled and the golden was not touched.

### 5. anvil

**LEFT RUNNING** — pid `222750`, `cast block-number` = 9, for plan 21-05's freshness assertion. Stop it with `bash offchain/rig/deploy-rig.sh --stop` when the phase closes.

---

## Decisions Made

### D1 — All three golden cases match exactly; the order-id escape hatch was never needed

The plan anticipated that `N1_success` / `N2_success_then_fail` "may differ in the ORDER-ID WORDS ONLY, because the golden was generated against a fresh registry while the live rig's `orderCount` has already advanced." **It has not advanced, and structurally cannot from this script**: `create_orders` returns its array, so the capture is four `eth_call`s, and an `eth_call` does not mutate state. Every case therefore executes against `orderCount = 0`, exactly the condition the golden was generated under. `N1_success` returns id 1; `N2_success_then_fail` returns id 1 then `(false, 0)`.

This makes the diff **stronger than planned** — a three-case exact match against an encoder outside this repo, not a structural near-match. The `differs_only_in_order_ids` comparator was still built and still ships, because it becomes load-bearing the moment anyone captures against a rig that has taken real transactions. It is recorded as `false` on all three cases, which is the honest reading: they did not differ at all.

Recorded in the artifact's `_scope_limit` so a later reader does not mistake the captured ids for ids that exist on chain.

### D2 — `generatedAt` is NOT a regeneration witness for this script

See the verbatim record above. The Phase-20 idempotence idiom was designed around `deploy-rig.sh`, which takes tens of seconds; `capture-batch-return.sh` takes 294 ms, so the check it inherits is vacuous roughly always. Regeneration was instead proven by **deleting the artifact before each run**. The README records the caveat, so the next person running the documented two-run recipe is not misled by two equal timestamps.

**Binds plan 21-05:** do not assert artifact freshness on `generatedAt` alone. `blockNumber` and `manager` are the discriminating provenance fields; `generatedAt` is a label.

### D3 — Hard failure vs finding is decided inside the script, not by the operator

`N0_empty` mismatching the golden exits 1 with both byte strings printed ("the empty encoding has no order ids in it"). A difference on `N1_success` / `N2_success_then_fail` confined to orderId words is recorded as data; **anything else** exits 1 with a message naming it a FINDING and explicitly forbidding adjustment of the golden (`test/` is the Solidity-testing track's). The judgement is in the artifact-producing code, so a future run cannot quietly make a different call.

### D4 — RPIN-05 left PENDING in REQUIREMENTS.md, deliberately

RPIN-05 is claimed by the frontmatter of **both** 21-02 and 21-05, and its text reads:
*"`decode_create_orders_result` is verified byte-unchanged against the V2 module's
`(bool, uint256)[]` return (verify against the live module, don't assume from the handoff)."*

This plan delivered the **live half** — the observed bytes, with provenance. It produced **no
Haskell decoder verification at all**, and was explicitly scoped out of adding assertions to
`offchain/test/Main.hs` (21-05 owns the suite side). Checking the box now would record a decoder
verification that does not exist — exactly the class of vacuous completion this repo has recorded
seven prior instances of. The box stays unchecked; **21-05 closes it** once
`decode_create_orders_result` is asserted against `offchain/rig/batch-return-capture.json`.

`ROADMAP.md` was updated normally (`roadmap update-plan-progress 21` → 1 of 5 summaries, Phase 21
In Progress).

### D5 — The N=0 self-check asserts a NUMBER, never a byte string

`returndata_bytes == 64`, not a comparison against a pasted expected string. Pasting it would put a 64-hex literal into a `.sh` file and redden `sc3_literal_purge` — the constraint that shapes this whole plan. The byte-string comparison for N=0 does happen, but against `jq -r '.expected[0]' <golden>`, read from disk.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `<current_facts>` said anvil was already running; it was not**

- **Found during:** Task 1, Step 1
- **Issue:** The execution context asserted "anvil IS currently running with the Phase 20 rig (7 contracts) from earlier session work". `pgrep anvil` at execution start returned **empty**. The plan's own `<interfaces>` block said the opposite ("ANVIL IS DOWN") and was correct.
- **Fix:** Ran `bash offchain/rig/deploy-rig.sh` as the plan's Step 1 instructs, which owns the lifecycle (kill stale listener → fresh chain → five deploy scripts → rewrite manifest → leave anvil up). Then `verify-rig.sh`.
- **Verification:** `SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded`, exit 0.
- **Committed in:** `bc8414a` (no file change — this was environment work; the gate output is recorded above)
- **Note:** The plan's instruction to *verify rather than assume* is exactly what caught this. Had the capture been attempted against the asserted-live chain, every `cast call` would have failed to connect.

**2. [Rule 1 - Bug] The plan's idempotence check could not distinguish a regenerated artifact from a stale one**

- **Found during:** Task 2, Step 2
- **Issue:** The plan required `generatedAt` to DIFFER between two runs as proof that run 2 regenerated the file. Two back-to-back runs produced the SAME `generatedAt` (`18:30:37Z`), because the script completes in 294 ms against a 1-second timestamp resolution. As written, the check would pass on a stale artifact.
- **Fix:** Re-measured with the artifact `rm`'d before each run (a stale file cannot survive deletion) and with the second run gated on the wall-clock second rolling over via a bounded `until` loop — no fixed `sleep`, matching `deploy-rig.sh`'s stance on fixed waits. Both facts recorded verbatim above and the caveat written into the README.
- **Files modified:** `offchain/rig/README.md`
- **Verification:** run A `18:31:02Z`, run B `18:31:03Z`, normalised diff empty, same sha256 as the first pair.
- **Committed in:** `bc58f32`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug in the plan's own verification method)
**Impact on plan:** Neither changed scope. Deviation 1 was the plan's Step 1 executed as written against a stale context claim. Deviation 2 strengthened a check the plan specified in a form that could not fail.

## Issues Encountered

### F1 CONFIRMED — reported to the plank track, not fixed

`src/modules/pos_spec/VolOrderManagerMod.plk` lines **177-188** carry a V1 comment block asserting `INPUT WORD: skew@0..15 | strike@16..103 | width@104..127 | bits >=128 MUST BE ZERO` and `width IS DELIBERATELY UNMASKED. It is the TOP field`. Lines **221-235** of the same file are the executing V2 code and say the opposite:

```
let word = @evm_calldataload(100 + i * 32);
let order = build_vol_order(
    @evm_shr(16,  word) & 0xFFFFFFFFFFFFFFFFFFFFFF,   // strike @16..103
    @evm_shr(104, word) & 0xFFFFFF,                   // width  @104..127, now MASKED
    word & 0xFFFF,                                    // skew   @0..15
    @evm_shr(128, word)                               // targetVega @128.., UNMASKED top field
);
```

The stale block is dangerous precisely because it is *plausible* and *co-located*: a word built from it carries `targetVega = 0`, the tuple is rejected, and the batch **skips rather than reverts**, so the capture would have degenerated into a legitimate-looking all-`(false, 0)` artifact proving nothing.

**Action taken:** the file was **not edited** — it belongs to the plank track (agent `ul2inqpl`). The warning is recorded in `offchain/rig/capture-batch-return.sh` immediately above `input_word()`, naming the line range and the failure mode, so the next person to build an input word in this repo reads it there.

### `cabal test` is green but 45/45, not Phase 20's 44/44

`cabal test` exits **0** with `45/45 checks passed` / `SC-3 and SC-4 OK`, so the new `.sh` does not redden `sc3_literal_purge` (the suite runs the identical grep, which produces no output repo-wide across `offchain --include='*.hs' --include='*.sh'`).

The count moved 44 → 45 because **plan 21-01 is executing in parallel in the same worktree** and has uncommitted edits to `offchain/app/Sample.hs`, `offchain/lib/VolOrder/{Types,Encoding,Decode}.hs`. That extra check is theirs, not this plan's. No file owned by 21-01 was touched here, and no assertion was added to `offchain/test/Main.hs` (21-05 owns the suite-side assertions over this artifact).

### Territory

`git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` produces **no output** at every checkpoint. `test/pos_spec/fixtures/vol_order_return_golden.json` was read with `jq` and never written.

## Verification Results

| # | check | result |
|---|---|---|
| 1 | `verify-rig.sh` exit 0, "7 contracts live" | PASS |
| 2 | `capture-batch-return.sh` exit 0, four self-checks pass | PASS |
| 3 | `N0_empty.returndata_bytes` == 64 | PASS |
| 4 | `cabal test` exit 0 | PASS (45/45) |
| 5 | repo-wide hex-literal scan over `offchain/*.hs,*.sh` | PASS (no output) |
| 6 | other tracks' territory untouched | PASS (no output) |
| — | `.cases \| length` == 4 | PASS |
| — | lowercased `N0_empty` == golden `expected[0]` | PASS |
| — | `.manager` == manifest `contracts.VolOrderManagerMod` lowercased | PASS |
| — | `N1_dirty_vega` is 128 bytes with success word 0 | PASS |
| — | two runs identical modulo `generatedAt`/`blockNumber`, timestamps differing | PASS (after deviation 2) |
| — | `README.md` references `capture-batch-return.sh` | PASS |

## User Setup Required

None.

## Next Phase Readiness

**Ready for 21-05.** `offchain/rig/batch-return-capture.json` is committed with four cases, full provenance and a recorded golden reading. 21-05 can assert against it with no chain. Anvil is **left running** (pid 222750, block 9) for 21-05's freshness assertion.

**Ready for 21-03.** The plan hoped a capture run might emit a real E1 `VolOrderCreated` v2 log, which has never been observed. **It did not, and could not:** these are `eth_call`s, which produce no logs. 21-03's decode shape remains derived from emitter source. Closing that gap needs a real `eth_sendTransaction` against `create_orders` — cheap now that the rig is standing and the V2 input word is proven, but it is 21-03's work, not this plan's.

**Carry-forwards:**
1. **`generatedAt` is not a freshness witness at this script's runtime** (D2). Use `blockNumber` / `manager`.
2. **The order ids in the artifact are hypothetical** — `eth_call` results against `orderCount = 0`. An assertion that hardcodes `id == 1` is really asserting the rig is fresh; say so where it is written.
3. **F1 is open in the plank track's file.** Report it to `ul2inqpl`; the stale block will mislead again.
4. **`N1_dirty_vega` has no golden counterpart** and is deliberately not a diff target. Do not let a future fixture regeneration silently adopt it as one.

---
*Phase: 21-v2-abi-re-pin-targetvega-generation*
*Completed: 2026-08-01*

## Self-Check: PASSED

All claimed files exist on disk (`capture-batch-return.sh`, `batch-return-capture.json`,
`README.md`, this summary). Both claimed commits resolve (`bc8414a`, `bc58f32`). The script is
285 lines (plan minimum 60), the artifact carries `chainId`, and both declared key_links are
present: `jq -r '.contracts.VolOrderManagerMod'` and `cast call`.
