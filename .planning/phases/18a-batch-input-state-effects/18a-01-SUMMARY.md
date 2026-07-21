---
phase: 18a-batch-input-state-effects
plan: 01
subsystem: on-chain-plank-module
tags: [plank, evm, calldata-abi, batch, multicall, mutation-testing, foundry, ffi]

requires:
  - phase: 16-type-packing-validation
    provides: "validate_order (bool core) + build_vol_order + the MEASURED accept sets"
  - phase: 17-interface-single-call-module
    provides: "VolOrderManagerMod dispatch, the two keccak slots, VolOrderManagerBase test scaffold, the pinned create_orders selector 0x81357911"
provides:
  - "create_orders(uint256,uint256[]) dispatch branch: four guards, bounded runtime while, per-tuple validate-then-skip, contiguous ids, single trailing orderCount store, one-word return"
  - "test/pos_spec/VolOrderManagerBatch.t.sol — 13 CALLED-green tests incl. hand-rolled malformed-calldata builders over low-level .call"
  - "The MCAL-01 MEASURED gas triple at N=128"
  - "The MCAL-04 six-step structural containment enumeration, written in-module"
  - "Seven OBSERVED mutation REDs incl. the Phase-17 M5 hand-off converted to a real kill"
affects: [18b-batch-return-encoding, 19-differential-and-fixture, rpc_api-haskell-peer-mv15a18k]

tech-stack:
  added: []
  patterns:
    - "Hand-rolled malformed-calldata builders (encodeBatchRaw / truncate) delivered by low-level .call — the only way to test ABI guards, since abi.encodeWithSelector cannot emit a malformed encoding"
    - "Builder self-pinning: the test's own encoders are asserted against the verified layout BEFORE they are used as a reference, so a builder bug cannot masquerade as a module bug"
    - "Assertion ORDERING as mutation-evidence design: the discriminating assertion is placed first because forge reports only the first failure"

key-files:
  created:
    - test/pos_spec/VolOrderManagerBatch.t.sol
  modified:
    - src/modules/pos_spec/VolOrderManagerMod.plk
    - test/pos_spec/VolOrderManager.t.sol
    - Makefile

key-decisions:
  - "The batch surface lives in its OWN file (VolOrderManagerBatch.t.sol), not in VolOrderManager.t.sol — it needs hand-rolled malformed calldata a typed interface cannot express, and disjoint --match-path targets keep a batch red from being misread as a single-call red"
  - "width is read UNMASKED so dirty high bits inflate it past 0xffffff and are rejected by validation — dirty-high-bit rejection with zero new arithmetic, and no malleability seam"
  - "MAX_BATCH is checked FIRST because Plank's * and + are CHECKED: an adversarial count would panic 0x11 in the size arithmetic before the calldatasize comparison, muddying MCAL-02 mutation evidence"
  - "SC-6 divergence CONFIRMED EMPIRICALLY: deleting validation stores wrong, it cannot batch-revert. The honest kill is a STATE/return red, which is strictly stronger"
  - "test__unit__batchSelectorNotYetDispatched was INVERTED in place rather than deleted, preserving a live assertion on which side of the 17/18a boundary the module sits"

patterns-established:
  - "Mutation-evidence assertion ordering: when two assertions both redden under a mutant, order the DISCRIMINATING one first so the recorded evidence is the one that pins the mechanism"
  - "A guard whose mutant is state-invisible must be killed by a REVERT assertion, and the state assertion beside it must be labelled in-file as completeness-only"

requirements-completed: [MCAL-01, MCAL-02, MCAL-03, MCAL-04, MCAL-06]

duration: 21min
completed: 2026-07-20
---

# Phase 18a Plan 01: Batch Input & State Effects Summary

**`create_orders(uint256,uint256[])` is a live, CALLED-green batch entrypoint: four guards revert structurally-malformed payloads, valid tuples land at contiguous ids while invalid ones skip without footprint, N=128 costs a MEASURED 3,247,452 gas, and all seven mutants produced observed, named REDs.**

## Performance

- **Duration:** ~21 min
- **Started:** 2026-07-20T22:26Z (local -0400)
- **Completed:** 2026-07-20T22:37Z (local -0400)
- **Tasks:** 4/4
- **Files modified:** 4 (1 created, 3 modified)

## Commits

| Commit | Task | Description |
| ------ | ---- | ----------- |
| `90aa0d2` | 1 | Dispatch branch + four guards + MCAL-04 enumeration |
| `25c1811` | 2 | Batch test surface (12 tests) + boundary-test flip + Makefile target |
| `bf7c31c` | 3 | MEASURED N=128 gas against the 10M ceiling |
| `eac83f7` | 4 | Contiguity-before-count reordering (mutation-gate finding) |

## MCAL-01 MEASURED

Recorded verbatim from `forge test --match-test test__unit__maxBatchGasUnderBudget ... -vv`.
A passing threshold assertion without these integers would NOT discharge MCAL-01.

```
MCAL-01 execGas   (N=128): 3203452
MCAL-01 calldataGas:         23000
MCAL-01 TOTAL     (N=128): 3247452
```

- **Threshold:** `<= 10,000,000` — PASSES with 3.08x headroom.
- **Total = execGas + 21,000 intrinsic + EIP-2028 calldata** (16 gas/nonzero byte, 4/zero byte), because a `.call` does not incur what a real transaction does.
- **Sanity vs the research's UNVERIFIED ~2.94M estimate:** measured is **1.10x** the estimate — same order of magnitude, so the loop is not doing unintended work. The estimate was NOT carried forward as fact; it is a sanity reference only.
- The success / return-value / `orderCount` / 128th-slot assertions all precede the `assertLe`, so a passing threshold cannot silently certify an early revert.

## Accomplishments

### Task 1 — the dispatch branch (`VolOrderManagerMod.plk`)

Four guards, ordering load-bearing:

| Guard | Line | Check |
| ----- | ---- | ----- |
| MAX_BATCH | 148 | `require(count <= MAX_BATCH)` — FIRST |
| guard 1 | 149 | `require(@evm_calldataload(36) == 0x40)` — canonical offset |
| guard 2 | 150 | `require(@evm_calldataload(68) == count)` |
| guard 3 | 151 | `require(@evm_calldatasize() >= 100 + 32 * count)` |

**The transcription trap was avoided.** Guard 1 reads byte **36**, not 68. `grep -c '@evm_calldataload(68) == 0x40'` → `0`. Every offset was derived from OUR two-word head; `merkle_airdrop.plk` was read for the `while` idiom only.

The 88-bit mask was copy-pasted from `VolOrder.plk:38` and proven byte-identical (`MASK_OK`, and zero occurrences of 23 F's).

**Module sha256 (pristine, restore target):** `6931b5e044c9e4517392888eaf54a389c53ee64b8c76b5b1e5f7c7367b36362a`

### Task 2 — the batch test surface

12 tests, all CALLED-green through FFI-deployed bytecode. Every one of the plan's ten behaviors maps to a named test. Test roster (13 including Task 3's gas test):

| Suite | Test |
| ----- | ---- |
| Encoding | `test__unit__canonicalEncodingMatchesTheVerifiedLayout` |
| Encoding | `test__unit__rawBuilderMatchesCanonicalWhenWellFormed` |
| State | `test__unit__mixedBatchFootprintAndContiguity` |
| State | `test__unit__dirtyHighBitsAreSkippedNotStored` |
| Guard | `test__unit__nonCanonicalOffsetReverts` |
| Guard | `test__unit__lengthCountMismatchReverts` |
| Guard | `test__unit__truncatedCalldataReverts` |
| Guard | `test__unit__overMaxBatchRevertsNoStateChange` |
| Guard | `test__unit__maxBatchExactlyOneTwoEightSucceeds` |
| Equivalence | `test__unit__batchOfOneEqualsSingleCall` |
| Equivalence | `test__unit__emptyBatchIsNoOp` |
| Gas | `test__unit__maxBatchGasUnderBudget` |
| Totality | `test__fuzz__batchNeverReverts` (256 runs) |

### Task 4 — the mutation gate

Discipline applied per mutant: pristine sha256 recorded once → single edit applied → **`rm -rf cache/fuzz`** (run before EACH mutant; a `runs: 0` kill must not be a replay) → suite run → verbatim RED recorded → `git checkout` restore → sha256 confirmed byte-identical → green re-verified.

## Mutation Table — 7/7 OBSERVED KILLS

| # | Mutant | Exact edit | OBSERVED RED (verbatim) |
|---|--------|-----------|--------------------------|
| M-G1 | guard 1 deleted | delete line 149 `require(@evm_calldataload(36) == 0x40);` | `[FAIL: guard 1: non-canonical offset must revert the whole tx] test__unit__nonCanonicalOffsetReverts()` |
| M-G2 | guard 2 deleted | delete line 150 `require(@evm_calldataload(68) == count);` | `[FAIL: guard 2: array length must agree with count] test__unit__lengthCountMismatchReverts()` |
| M-G3 | guard 3 deleted | delete line 151 `require(@evm_calldatasize() >= 100 + 32 * count);` | `[FAIL: guard 3: calldatasize must cover 100 + 32*count] test__unit__truncatedCalldataReverts()` |
| M-MB | MAX_BATCH deleted | delete line 148 `require(count <= MAX_BATCH);` | `[FAIL: count > MAX_BATCH must revert before any sstore] test__unit__overMaxBatchRevertsNoStateChange()` |
| M-OFF | THE TRANSCRIPTION TRAP | guard 1's `36` → `68` | `[FAIL: a mixed batch never reverts] test__unit__mixedBatchFootprintAndContiguity()` (+6 more) |
| M-M5 | THE PHASE-17 HAND-OFF | `id = id + 1;` hoisted above the `if` | `[FAIL: id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979] test__unit__mixedBatchFootprintAndContiguity()` |
| M-VAL | validation branch deleted | delete `if validate_order(order) {` + its closing `}` | `[FAIL: returns the success count: 3 != 2] test__unit__mixedBatchFootprintAndContiguity()` (+2 more) |

**Post-restore sha256, verified after every single mutant and again at the end:**
`6931b5e044c9e4517392888eaf54a389c53ee64b8c76b5b1e5f7c7367b36362a` — identical to the Task 1 digest.

### M-G3 — the kill is a REVERT, explicitly NOT a state assertion

The recorded kill is `assertFalse(ok, "guard 3: calldatasize must cover 100 + 32*count")`.

**Why a state assertion would have been a FAKE kill, now empirically confirmed:** with guard 3 deleted, `@evm_calldataload` past the end of calldata returns ZERO-PADDED words, `build_vol_order(0,0,0)` fails validation, the tuple is SKIPPED, and state stays clean. The proof is in the run itself — the same test's companion assertion `assertEq(mgr.orderCount(), 0, "guard 3: completeness only -- NOT the kill site")` stayed **GREEN** under the mutant. Only the revert assertion discriminated. The completeness assertion is labelled as such in-file so a future reader cannot mistake it for the kill site.

### M-OFF — killability check, stated as a number

This mutant is EQUIVALENT for any corpus point with `count == 64`, and only there (at count 64 the length word at byte 68 coincidentally equals 0x40). **The reddening corpus point is the mixed batch, which has `count = 3`. 3 != 64.** Had every corpus point used count 64, this mutant would have survived silently. Seven tests reddened in total, none of which uses count 64.

### M-M5 — the Phase-17 hand-off is now a REAL kill (STATE.md:58 discharged)

Both assertions redden. Observed across two runs of the same mutant:

1. `[FAIL: orderCount advances by the success count, not by N: 8 != 7]`
2. `[FAIL: id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979]` ← **LOAD-BEARING**

**Mechanism, confirmed by the observed value:** slot C+2 holds **ZERO**. The skipped middle tuple consumed id C+2 and pushed valid_B to C+3. A count-only corpus would NOT have discriminated this — it would report "8 != 7" without pinning WHERE the misplaced order landed.

**A finding surfaced here and was fixed (commit `eac83f7`).** forge reports only the FIRST failing assertion per test. With the plan's original assertion ordering, the `orderCount` check fired first and MASKED the contiguity red — the recorded evidence would have read as a count-only kill, exactly the non-discriminating shape this corpus exists to avoid. The contiguity assertion was moved ABOVE the count assertion so the discriminating red is the one reported. Nothing was removed; both still run.

### M-VAL — the SC-6 DIVERGENCE, now empirically confirmed

**ROADMAP SC-6's original wording** (corrected at `56c4721` before execution) demanded that deleting the validation branch redden the totality fuzz **as a BATCH REVERT, not a wrong value**. That is mechanically unachievable, and this run proves it:

Observed reds under M-VAL:
- `[FAIL: returns the success count: 3 != 2] test__unit__mixedBatchFootprintAndContiguity()`
- `[FAIL: no tuple succeeded: 1 != 0] test__unit__dirtyHighBitsAreSkippedNotStored()`
- `[FAIL: the success count equals the constructed valid count: 1 != 0] test__fuzz__batchNeverReverts()`

**Decisively: `assertTrue(ok, "MCAL-04: no batch-revert observed")` did NOT fail.** The batch SUCCEEDED and stored the invalid tuple. No revert was observed anywhere in the battery.

This is the honest, strictly stronger observation: it pins that the unvalidated tuple was *stored wrong* and *counted*, rather than merely reporting that something failed. **No revert was manufactured to satisfy the old wording.**

**This also independently CORROBORATES the MCAL-04 structural enumeration.** M-VAL forces arbitrary unvalidated tuples down the full post-validation store path — exactly the path the enumeration claims is total. Had any step been non-total, a revert would have appeared here. None did. Per the plan's instruction, an observed revert would have been an MCAL-04 finding requiring escalation; **none occurred, so no MCAL-04 step's totality was contradicted.**

## MCAL-04 structural enumeration — location

`src/modules/pos_spec/VolOrderManagerMod.plk`, lines **95–126**, at the top of the `SELECTOR_CREATE_ORDERS` branch. All six steps present with revert status: `build_vol_order` (no revert), `validate_order` (no revert), `id + 1` (checked, unreachable), `pack_vol_order` (no revert — the fact that makes pre-validation containment viable), `array_slot` (checked, documented-unreachable), `@evm_sstore` (no revert).

**Placement resolution (recorded, not silently chosen):** the plan said "immediately above the `create_orders` branch". Placing a comment block between the previous branch's `}` and its `else if` is a parse hazard in Plank, so the enumeration sits as the FIRST thing inside the branch. This is semantically "immediately above the branch body", satisfies the acceptance grep (`MCAL-04 CONTAINMENT` → 1), and keeps the file compiling.

## Deviations from Plan

### Resolved plan-internal contradictions (the Phase 16/17 lesson applied)

**1. `grep -c 'vm.assume'` expected `0`, initially returned `2`.**
Both occurrences were COMMENT PROSE describing the no-`vm.assume` discipline — there was never an executable `vm.assume`. Rather than silently accept a red grep or weaken the criterion, the comments were reworded to "assumption-based input filtering is banned outright". The criterion now holds **literally** (`0`) and the discipline is still documented. Verified: the corpora are constructed with `bound` throughout.

**2. `grep -c 'address(mgr).call('` expected `>= 5`, returns `1`.**
The same plan mandates (section A) a `callBatch` helper that funnels every low-level call through ONE site — so the two criteria are mutually unsatisfiable. **Resolved in favour of the helper**, because the property the criterion exists to establish is *"the guards are exercised through low-level calls rather than the typed interface"*, and that property is verified TRUE and in fact stronger here: **11 call sites** route through `callBatch`, and `grep -n 'mgr\.create_order('` in the batch file returns **nothing** — there is no typed batch entrypoint to accidentally use. Inlining the call five times to satisfy a string count would have duplicated code to weaken the design. The resolution is recorded in-file on `callBatch`'s docstring so it is not re-litigated.

### Task-quality change (commit `eac83f7`)

Assertion reordering in `test__unit__mixedBatchFootprintAndContiguity` — see M-M5 above. Discovered BY the mutation gate; it strengthens the evidence rather than the code.

### Note on Task 2's `tdd="true"` flag

The plan's own task ordering places the module (Task 1) before the tests (Task 2), which is not a RED-GREEN-REFACTOR sequence. A genuine RED phase nonetheless occurred and was honoured: Phase 17's `test__unit__batchSelectorNotYetDispatched` was a pre-existing locked assertion that went RED the moment Task 1 landed (as STATE.md flagged it would), and Task 2 flipped it green. No test was written to pass a mutant.

## Verification

| Check | Result |
| ----- | ------ |
| `make compile-plank` | **13 ok, 0 failed, 0 skipped** (unchanged — no new entrypoint) |
| `make test-vol-order-batch` | **13 passed, 0 failed** |
| `make test-vol-order-manager` | **12 passed, 0 failed** (boundary test flipped, not deleted) |
| `make test` | **112 passed / 4 pre-existing pos_spec fails** (was 99/4) |
| Known TickVolatilityLib flake | did NOT appear; no 5th failure |
| `git diff --stat src/types/pos_spec/` | **EMPTY** — byte-untouched |
| Module sha256 after battery | **identical** to pristine |

## Self-Check: PASSED

- `src/modules/pos_spec/VolOrderManagerMod.plk` — FOUND, sha256 matches pristine
- `test/pos_spec/VolOrderManagerBatch.t.sol` — FOUND (418+ lines, exceeds the 250 min)
- `Makefile` `test-vol-order-batch` target — FOUND
- Commits `90aa0d2`, `25c1811`, `bf7c31c`, `eac83f7` — all FOUND in `git log`

---

## CARRY-FORWARD (Phases 18b / 19 and the Haskell peer depend on these)

### 1. The return shape — ONE WORD

18a returns **a single `uint256`: the success count**, via `return_u256(ok)`. This was deliberate: every 18a claim is asserted against raw `vm.load` slots and a scalar the test computes itself, with no untested encoder in between.

**Phase 18b replaces this return with `(bool,uint256)[]` and inherits every state assertion in `VolOrderManagerBatch.t.sol` unchanged** — the state effects are already pinned, so 18b only needs to prove the encoding. A real dynamic-length return precedent exists at `plank-diff-tests/src/std/abi_dynamic.plk:14` (`@evm_return(out, written)` via `abi_encoded_size` + `unsafe_abi_encode`).

### 2. PEER NOTE for `mv15a18k` (rpc_api Haskell `StochasticOrderGen`)

**HARD ENCODING REQUIREMENT — guard 1 requires the CANONICAL array offset `0x40` at byte 36.**
Solidity, `cast`, ethers and web3.py all emit it. A bespoke Haskell encoder that *legally* pads the head (the ABI spec permits a non-minimal offset) will be **REJECTED with an empty revert**. This is deliberate, not an oversight: it closes the PHANTOM-ORDER hole MCAL-02 exists to prevent — the module reads elements at a fixed `100 + 32*i`, which is sound *only* because the offset is pinned. Killed by `test__unit__nonCanonicalOffsetReverts` with a hostile `0x2000` offset.

**INPUT WORD layout** (differs from the STORED word only in `width`'s offset):

```
bits   0..15    skew    (u16)   accept set [1, 65534]   -- 0 and 65535 REJECTED
bits  16..103   strike  (u88)   accept set [1, 2^88-1]
bits 104..127   width   (u24)   accept set [1, 0xffffff]
bits 128..255   MUST BE ZERO    -- any bit set here inflates the UNMASKED width
                                   past 0xffffff and the tuple is SKIPPED (not reverted)
packed_input = skew | (strike << 16) | (width << 104)
```

The STORED word is `width@128 | tickSpacing@104 | strike@16 | skew@0` — `width` moves from 104 to 128 because the module inserts `TICK_SPACING = 20` at bits 104..127.

**Calldata contract:** `create_orders(uint256 count, uint256[] packedOrders)`, selector `0x81357911`.
`calldatasize` must be exactly/at least `100 + 32*count`; the length word at byte 68 must equal `count`; `count <= 128` (MAX_BATCH).

**Semantics:** invalid tuples are SKIPPED, not reverted — the batch is best-effort and never reverts on a semantically bad tuple. Structural malformation DOES revert the whole tx. `N = 0` succeeds and is a no-op (a zero-arrival Poisson tick is in-distribution, not a client error).

**MAX_BATCH is 128.** The hard admissibility ceiling is 512; a peer value above it will be CAPPED and reported, never silently adopted.

### 3. Baselines for Phase 18b

- `make test`: **112 pass / 4 pre-existing pos_spec fails**
- `make compile-plank`: **13 ok / 0 failed / 0 skipped**
- Every forge invocation still requires `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`
- The `TickVolatilityLibTest` flake (~1 cold run in 4 at counterexample `2^64-1`) remains pre-existing and owned by another track — re-run once before treating a 5th failure as a regression.

### 4. MCAL-04 status

No step of the six-step enumeration had its totality contradicted. The M-VAL mutant drove arbitrary unvalidated tuples through the entire post-validation store path and produced **no revert** — the strongest available corroboration short of a proof.
