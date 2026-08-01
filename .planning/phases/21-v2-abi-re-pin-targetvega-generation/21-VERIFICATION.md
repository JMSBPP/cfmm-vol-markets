---
phase: 21-v2-abi-re-pin-targetvega-generation
verified: 2026-08-01T19:51:18Z
status: passed
score: 7/7 must-haves verified
---

# Phase 21: V2 ABI Re-Pin + targetVega Generation Verification Report

**Phase Goal:** The Haskell client speaks V2 on every byte layout that crosses the wire — call,
batch input word, storage word, and log — with each selector and topic0 pinned by a test that
COMPUTES it from the signature string, so this surface cannot rot silently again; and
`StochasticOrderGen` supplies the fourth field in the right units.

**Verified:** 2026-08-01T19:51:18Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `cabal test` is green at full count with zero `-Wall` warnings under the corrected build gate | ✓ VERIFIED | `cabal build --enable-tests -j all` exits 0, zero warning lines; `cabal test` reports **65/65 checks passed**, `SC-3 and SC-4 OK` |
| 2 | The suite is chain-independent (green with anvil down) | ✓ VERIFIED | Ran `bash offchain/rig/deploy-rig.sh --stop`, confirmed `pgrep anvil` empty, ran `cabal test` — still 65/65. Rig was then redeployed (see "Rig state left" below) |
| 3 | The four V2 wire layouts (call calldata, batch input word, storage word, E1 log) match the spec exactly | ✓ VERIFIED | Read `offchain/lib/VolOrder/{Types,Encoding,Decode}.hs` directly: input word `skew@0..15 \| strike@16..103 \| width@104..127 \| targetVega@128..223`; storage word `skew@0 \| strike@16 \| tickSpacing@104 \| width@128 \| targetVega@152..247`; 4-arg selector `create_order(uint88,uint24,uint16,uint96)`; `decode_order_created` matches exactly 2 topics and reads exactly 4 data words with a `>= 128`-byte length guard |
| 4 | The V1 3-arg `create_order` path is genuinely deleted from `offchain/` | ✓ VERIFIED | `grep -rn 'create_order(uint88,uint24,uint16)"' offchain/` — no output; only the 4-arg V2 signature exists anywhere. `orderOwner`/`orderCreatedAt` (V1 event fields) are absent everywhere |
| 5 | `VegaDraw = LogUniform{vega_min=10^18, vega_max=10^21}` with the loud draw-time guard | ✓ VERIFIED | `offchain/lib/StochasticOrderGen/{Types,Simulate}.hs` read directly: one-constructor `LogUniform` with those exact bounds, haddock carries the full derivation (v3 relation, arXiv:2205.08904), `draw_target_vega` guards `v >= max 1 lo && v <= min hi (2^96-1)` and `fail`s loudly otherwise |
| 6 | Pins are recomputed from `.plk` signature strings in the tests, not merely read from `rig-pins.json` | ✓ VERIFIED | `offchain/test/Main.hs` calls `signature_for "create_order"` / `signature_for "VolOrderCreated"` on `signatures_in (lines contents)` read from `src/interfaces/pos_spec/VolOrderManagerInterface.plk`, then `selector_of`/`topic0_of` (keccak256) recompute the pin, cross-checked against `rig-pins.json` as a second, independent assertion |
| 7 | `cabal run` demo order mines (the 20-05 revert defect is fixed) | ✓ VERIFIED | Ran `cabal run` against the standing rig: single-call demo order, tx status `success`, block 10, `log ORDER_CREATED` with `target_vega 1000000000000000000`; batch of 3 orders, `3 succeeded, 0 failed (of 3)` |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `offchain/lib/VolOrder/Types.hs` | `VolOrder` carries `target_vega` | ✓ VERIFIED | Field present, haddock states raw-L dimension, `[1, 2^96-1]` |
| `offchain/lib/VolOrder/Encoding.hs` | V2 4-arg encoder + 4-field packer, V1 deleted | ✓ VERIFIED | `encode_create_order` V2-only; `pack_vol_order_input` four attributable guards; `shiftL 128` for targetVega |
| `offchain/lib/VolOrder/Decode.hs` | V2 248-bit storage unpack + E1 v2 decoder | ✓ VERIFIED | `unpack_vol_order_storage` shifts 16/104(discarded)/128/152; `decode_order_created` 2-topic/4-word with length guard |
| `offchain/lib/VolOrder/Report.hs` | V2 field printing | ✓ VERIFIED | prints `target_vega` |
| `offchain/lib/StochasticOrderGen/Types.hs` | `VegaDraw`, `OrderShape` | ✓ VERIFIED | one-constructor `LogUniform`, `OrderShape` removes placeholder trap |
| `offchain/lib/StochasticOrderGen/Simulate.hs` | `draw_target_vega` with loud guard | ✓ VERIFIED | guard + `fail` present |
| `offchain/lib/StochasticOrderGen/Rpc.hs` | draws vega per order at generation time | ✓ VERIFIED | `attach_vega` called once per shape before chunking |
| `offchain/rig/capture-batch-return.sh` / `batch-return-capture.json` | live-captured `(bool,uint256)[]` bytes, provenance-bearing | ✓ VERIFIED | 4 cases, `N0_empty` = 64 bytes, manager/chainId/blockNumber recorded |
| `offchain/rig/peer-haskell-bytes.json` | Haskell-decoded golden bytes offered to Solidity-testing track | ✓ VERIFIED | 5 cases, `_offer_to` and `_scope` present, fixture untouched |
| `offchain/test/Main.hs` | RPIN-01..06, VEGA-01 checks | ✓ VERIFIED | All named checks present and passing (see check list below) |
| `.planning/phases/21.../21-CROSS-TRACK-FINDINGS.md` | F1–F4 filed against owners | ✓ VERIFIED | 259 lines, F1/F2 (plank), F3 (this workstream, corrected in place), F4 (freshness limitation) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `Main.hs` | `VolOrderManagerInterface.plk` | `signature_for "create_order"` recomputed selector | ✓ WIRED | `rpin01_encoder_selector_is_recomputed` PASS |
| `Main.hs` | `VolOrder.Encoding.encode_create_order` | leading 4 bytes vs recomputed selector | ✓ WIRED | `rpin01_encoder_argument_order` PASS |
| `Main.hs` | `VolOrderManagerInterface.plk` | `signature_for "VolOrderCreated"` → `topic0_of` → `decode_order_created` | ✓ WIRED | `rpin04_topic0_is_recomputed`, `rpin04_positive_v2_decode` PASS |
| `Report.hs` | `Decode.hs` | `report_log` calls `decode_order_created` with pinned topic0 | ✓ WIRED | confirmed by reading `Report.hs`; unchanged parameter-passing discipline |
| `StochasticOrderGen.Rpc` | `StochasticOrderGen.Simulate` | `run_order_gen` calls `attach_vega`/`draw_target_vega` before chunking | ✓ WIRED | confirmed by reading `Rpc.hs` |
| `Sample.hs` | `StochasticOrderGen.Types` | `sample_order_gen` supplies `vega_draw = LogUniform{...}` | ✓ WIRED | confirmed by reading `Sample.hs` |
| `Main.hs` | `offchain/rig/batch-return-capture.json` | `eitherDecodeFileStrict`, diffed against golden, fed to shipped decoder | ✓ WIRED | `rpin05_*` (4 checks) all PASS |
| `Main.hs` | `offchain/rig/rig-manifest.json` | freshness assertion, `rig_contracts` | ✓ WIRED | `rpin05_capture_is_present_and_fresh` PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| RPIN-01 | 21-01 | V2 4-arg calldata, selector pin from signature string | ✓ SATISFIED | `Encoding.hs`, `rpin01_*` checks PASS |
| RPIN-02 | 21-01 | V2 batch input word, field-width validation, bits ≥224 zero | ✓ SATISFIED | `Encoding.hs`, `rpin02_*` checks PASS |
| RPIN-03 | 21-01 | 248-bit V2 storage word unpack | ✓ SATISFIED | `Decode.hs`, `rpin03_*` checks PASS |
| RPIN-04 | 21-03 | E1 v2 `VolOrderCreated` decode, 2 topics/4 words | ✓ SATISFIED | `Decode.hs`, `rpin04_*` checks PASS, real on-chain log observed (21-03-SUMMARY) |
| RPIN-05 | 21-02, 21-05 | `decode_create_orders_result` verified against live-module bytes | ✓ SATISFIED | `batch-return-capture.json`, `rpin05_*` checks PASS, chain-independence proven |
| RPIN-06 | 21-03 | `VolOrder` carries `target_vega`, senders + readback carry it | ✓ SATISFIED | `Types.hs`, `Rpc.hs`, `rpin06_*` checks PASS — with the honest limit that the check is inequality-based and the unperturbed baseline is the sole discriminator (measured, disclosed) |
| VEGA-01 | 21-04 | `StochasticOrderGen` draws targetVega in raw-L units, `[1,2^96-1]`, realistic band | ✓ SATISFIED | `Types.hs`/`Simulate.hs`, `vega01_*` checks PASS |

No orphaned requirements — all 7 phase requirement IDs (RPIN-01..06, VEGA-01) appear in a plan's
`requirements:` frontmatter and are marked Complete and consistently described in
`.planning/REQUIREMENTS.md`.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | none found (`TODO`/`FIXME`/`PLACEHOLDER` grep across `VolOrder/`, `StochasticOrderGen/`, `Sample.hs`, `test/Main.hs` empty) | — | — |

`sample_order_shapes` deliberately carries **no** `target_vega` field (by type, `OrderShape` has
none) — this is the documented fix for the placeholder-discard trap, not an anti-pattern.

### Self-Reported Limitations — Judged

All six limitations named in the verification brief were checked directly against source and are
**accurately characterized, not defects being hidden**:

1. **21-03 `rpin06_perturbed_target_vega_fails_readback` is inequality-based.** Confirmed by
   reading the check (`decoded /= submitted`). The 21-03 SUMMARY records a second-order
   measurement: with the mutant (`target_vega = 0`) applied and the check's own unperturbed-baseline
   assertion neutralised, the check **passes** — i.e. the baseline assertion is the sole
   discriminator. This is disclosed plainly in-code and in the SUMMARY, not smoothed over.
2. **21-04's `>= 8` bit-length discriminator did not catch the linear-uniform mutant.** Confirmed:
   `offchain/test/Main.hs` contains a `bottom_decade >= 40` (measured 77 vs 4 of 256) assertion
   layered on top of the original spread check, added specifically because the spread check alone
   cleared under the mutant (9 distinct bit-lengths, over the `>= 8` threshold).
3. **21-04 F3 — zero-lower-bound rejection is incidental (NaN), not an explicit guard.** Confirmed
   reasoning: `draw_target_vega`'s guard is a **range check on the returned value**, not a
   parameter-domain check; a zero lower bound only fails because the log-transform produces `NaN`
   and `round NaN` yields garbage that then fails the range check by luck, not by design. Disclosed
   in the 21-04 SUMMARY and not misrepresented as an explicit guard in the code comments.
4. **21-05 F4 — freshness check cannot see a bytecode-independent module change.** Confirmed by
   reading `rpin05_capture_is_present_and_fresh`: it asserts `chainId` + `manager` only. Since
   `manager` is a `CREATE` address (deployer, nonce)-derived and measured identical across three
   redeploys in this phase, a plank-side module change followed by redeploy would leave `manager`
   unchanged and a stale capture would still pass. This is stated as a reasoned (not fully
   demonstrated) limitation in the findings doc, with a concrete proposed fix (code-hash pinning)
   not applied — correctly scoped as out of this plan's blast radius.
5. **21-05 downgrade of tracked follow-up #5 from plan-directed "ADDRESSED" to "PARTIALLY
   ADDRESSED".** Verified as the correct call: read `offchain/lib/VolOrder/Rpc.hs:94-104`
   directly — `verify_mined_order` compares `actual_order == expected_order` where `actual_order`
   comes from `unpack_vol_order_storage`, which discards bits 104..127 (tickSpacing) and bits
   ≥248 before constructing the record. The production verifier genuinely does not perform the
   whole-word comparison follow-up #5 asked for; only the 21-01 test-side `rpin03_storage_round_trip`
   does, against a test-built reference word. The executor was right to override the plan's
   instruction and write the accurate status.
6. **Cross-track F1/F2 — plank-track findings, reported never edited.** Confirmed `git status
   --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` is clean at the
   time of this verification, and `git diff --stat HEAD -- src/` shows no phase-21 commits touching
   `src/`. F1 (stale V1 comment at `VolOrderManagerMod.plk:177-188`) and F2 (`TICK_SPACING=20` vs
   pool `tickSpacing=10`) are documented in `21-CROSS-TRACK-FINDINGS.md` with verbatim quotations
   and correct file/line citations (F2's citation was itself corrected from the plan's wrong
   pointer, `VolOrderValidationLib.plk:33` vs the plan's stated `VolOrder.plk`).

### Rig state left by this verification

Verification stopped anvil to prove chain-independence, then **redeployed the rig** via
`bash offchain/rig/deploy-rig.sh` per the brief's instruction. Current state at the end of this
verification: anvil running (fresh pid, not 366381 — the old process was killed by the stop/redeploy
cycle), `rig-manifest.json` regenerated with the same contract addresses (CREATE-address
reproducibility holds), pool `tickSpacing = 10` unchanged, chain height **11**, `orderCount = 4`
(1 from the single-call demo order + 3 from the batch demo, both run during this verification via
`cabal run`). `offchain/rig/batch-return-capture.json` (committed, from 21-02/21-05) still matches
the current manifest's `manager` address (CREATE-address reproducibility), so `rpin05_*` checks
still pass unchanged — confirmed by a final `cabal test` run after the redeploy (65/65).

### Human Verification Required

None. All must-haves were verified by direct command execution and source inspection.

### Gaps Summary

No gaps. All 7 requirements are satisfied, all four wire layouts match the specified bit ranges
exactly as read from source, the V1 path is genuinely deleted, `VegaDraw` matches the specified
`LogUniform{1e18,1e21}` parameters with a loud guard, pins are demonstrably recomputed (not merely
read) from `.plk` signature strings, the demo order mines successfully (fixing the 20-05 revert
defect), and every self-reported limitation in the phase's own SUMMARYs was checked against source
and found to be an accurate, non-hidden characterization rather than an overstated success claim.

---

_Verified: 2026-08-01T19:51:18Z_
_Verifier: Claude (gsd-verifier)_
