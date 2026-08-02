---
phase: 22-live-stochastic-drivers
verified: 2026-08-02T18:30:00Z
status: passed
score: 7/7 must-haves verified (independently re-derived, not the 22-06 self-report)
re_verification: false
---

# Phase 22: Live Stochastic Drivers — Verification Report

**Phase Goal:** Both drivers run end-to-end against the live rig under the V2 ABI and produce the
real event set — the milestone's acceptance bar, and the input the queued v6.0 subgraph will index.
**Requirements:** DRIV-01, DRIV-02
**Verified:** 2026-08-02 (independent re-verification; supersedes the 22-06 self-report, which is
treated here as a claim, not evidence)
**Status:** passed

A prior `22-VERIFICATION.md` was written by the 22-06 executor. This report does not trust it — every
row below was independently re-measured against the live codebase and, where possible, a live chain.
This report OVERWRITES the prior one.

## Method

All checks were re-run from scratch in this session:

1. `cabal build -j all` — confirmed VACUOUS (exits 0, builds only the two executables, never
   configures the test suite).
2. `cabal build --enable-tests -j all` — exit 0, zero `-Wall` warnings (grep for "warning" over the
   full build log: empty).
3. `cabal test` — **83/83**, exit 0, first with the pre-existing anvil (pid 1152682) running.
4. **Chain-independence, actually measured, not inherited:** killed the running anvil, confirmed with
   `cast block-number` erroring and `pgrep anvil` empty, then re-ran `cabal test` — still **83/83**,
   exit 0.
5. Restored the rig from scratch: `bash offchain/rig/deploy-rig.sh` (F2's `tickSpacing=20` rig,
   6 scripts, `InitSwappableRig`'s probe confirmed `lastTimepointTimestamp` strictly advanced
   `1700000003 -> 1700000011`). `offchain/rig/verify-rig.sh` — 9/9 contracts live, both routers bound
   to the right `PoolManager`. `offchain/rig/verify-import.sh` — 37/37 paths sha256-matched.
6. **Independent live re-run of the whole driver, not just replay of the committed artifact:** ran
   `RIG_SEED=999111222 cabal run cfmm-replicationPlank-rpc-api` against the freshly-deployed rig (a
   seed never used by any committed artifact). It produced 5 fresh cheat->clock->swap steps (every
   `e3.tick` equal to the submitted tick, every step status 1, one E3 + one E5 each), a single order
   (status 1, one E1), a mixed batch (`preview=[True,False,True]`, orderCount delta 2), and a
   zero-arrival batch (64-byte preview, decoded `[]`). `cabal test` was then re-run against this
   genuinely new artifact — **83/83** again. This is materially stronger evidence than re-reading the
   committed JSON: it proves the mechanism live, on demand, independent of any single captured run.
   The committed `offchain/rig/driver-run-capture.json` was restored byte-identical afterward
   (`git status --porcelain offchain/rig/` empty).
7. Read every `driv01_*` / `driv02_*` / `sc4_pin_*` check body in `offchain/test/Main.hs` directly —
   not the SUMMARY's description of them — to confirm the assertions actually test what the
   VERIFICATION brief claims (configuredSize vs length(steps), the wrong-pool composition-vs-
   destination split, the 64-byte preview provenance, the F22-8/F22-9 honesty).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | The hook self-writes timepoints on `beforeSwap` (DRIV-01's corrected mechanism); no offchain `writeTimepoint` client exists | ✓ VERIFIED | `grep -rn writeTimepoint offchain/lib` finds no client call; `DynamicFeeHook.plk:129` is the write site; `InitSwappableRig`'s probe and every driver run below confirm it fires live |
| 2 | A stochastic price path produces one E3 per step, carrying the submitted tick and timestamp, over the whole configured run (not just the steps that exist) | ✓ VERIFIED | `driver-run-capture.json` 5/5 steps `e3.tick == tick`, `e3.timestamp == expected_ts`; `driv01_e3_per_step_matches_submitted` and `driv01_no_same_second_noop` both compare `length(steps)` against `configuredSize`, closing the truncation-blindness gap 22-05 found |
| 3 | A single `create_order` mines live with one E1 v2 and a receipt-block-pinned readback carrying `targetVega` | ✓ VERIFIED | `orders.single` in the artifact; re-derived live in the independent re-run (order id 1, status 1) |
| 4 | A genuinely MIXED batch is exercised live (best-effort skip, not assumed) | ✓ VERIFIED | `orders.mixed`: `skew=65535` WIDTH-valid/DOMAIN-invalid, preview `[[true,6],[false,0],[true,7]]`, `orderCount` delta == success count == 2, reproduced independently in the fresh re-run (`[True,False,True]`, delta 2) |
| 5 | A zero-arrival batch completes cleanly: preview is exactly 64 bytes, decodes to `[]`, and the check is honest about where the fact is observable (a mined tx has no returndata) | ✓ VERIFIED | `orders.n0.preview_byte_length == 64`; `offchain/test/Main.hs:3546-3558` states plainly the fact is only observable via `preview_create_orders`, never off a mined tx |
| 6 | The whole chain is chain-independent at test time and reproducible from a recorded seed | ✓ VERIFIED | `cabal test` 83/83 with anvil killed (measured live, this session); README's replay section states honestly which fields replay and which (`vegas`, `t0`) do not |
| 7 | The blocker (two-PoolManager confusion) was discharged by measurement, not argued | ✓ VERIFIED | `cheat-swap-proof.json` measurement A `e3.tick==5000`; measurement B `slot0_tick_of word_written == 7000` (composition correct) while `e3_tick == 4999 != 7000` (destination wrong) — exactly reproduced in `driv01_cheated_tick_reaches_e3` / `driv01_wrong_pool_is_silent` |

**Score:** 7/7 truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `offchain/lib/RealizedVol/Decode.hs` | E3/E5 decoders, signed | ✓ VERIFIED | `signed_word` applied to `tw_tick`, `tw_avg_tick`, `tw_tick_cum`; negative-pin fix confirmed live in source (`driv01_e3_tick_negative = -3145`) |
| `offchain/lib/CheatSwap/Types.hs`, `Encoding.hs`, `Rpc.hs` | slot0 composition, extsload/swap encoding, live loop | ✓ VERIFIED | present, exported, exercised by `driv01_*` checks and by the independent live re-run |
| `offchain/rig/cheat-swap-proof.json` | 6 committed live measurements | ✓ VERIFIED | present, `generatedFrom` matches `2039f27...`, all 6 measurements match the checks that assert over them |
| `offchain/rig/driver-run-capture.json` | 5-step DRIV-01 path + 3 DRIV-02 order shapes | ✓ VERIFIED | present; independently reproduced with a different seed and a fresh rig in this session, then restored byte-identical |
| `offchain/lib/Driver/Capture.hs`, `Seed.hs` | provenance record + exception-safe writer, seed resolution | ✓ VERIFIED | exports present; `dr_complete`/`orders.complete` semantics confirmed in the artifact |
| `offchain/lib/VolOrder/Rpc.hs preview_create_orders` | observability for the 64-byte empty return | ✓ VERIFIED | exported, used by `orders.n0`, and the check's own haddock states why it is the only place the 64 bytes are observable |
| `offchain/rig/README.md` | one documented clean-machine command sequence | ✓ VERIFIED | 10-step sequence present and internally consistent with every script actually run this session (`check-upstream.sh`/`verify-import.sh`/`deploy-rig.sh`/`verify-rig.sh` all re-run, all exit 0) |
| `foundry-scripts/deploy/InitSwappableRig.s.sol` | swappable-rig init script, imported verbatim | ✓ VERIFIED | present, ran successfully this session, probe timepoint strictly advanced |
| `offchain/lib/Rig/Manifest.hs` | 9-contract requirement, `RIG_MANIFEST` honoured | ✓ VERIFIED | `verify-rig.sh` confirms 9/9 live; `RIG_MANIFEST` fix confirmed live in `rig_manifest_path` (22-03's fix, not merely logged) |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `DynamicFeeHook.beforeSwap` | `RealizedVolatilityStateLib` | `rv_write_timepoint` on the pre-swap tick | ✓ WIRED | live: every cheated tick reaches E3 exactly, 10/10 across the two committed proof files plus the fresh independent run |
| `CheatSwap.Rpc` | `RealizedVol.Decode` | receipt log filtered on `changeAddress == DynamicFeeHook` | ✓ WIRED | `cheat-swap-proof.json` measurement B proves the filter matters: the module's own E3 (poolId sentinel) would otherwise be indistinguishable |
| `offchain/app/Main.hs` | `Driver/Capture.hs` | `Control.Exception.finally` | ✓ WIRED | `dr_complete: true` on every committed and freshly-generated run in this session; no partial-run artifact was produced during verification, consistent with clean exits |
| `offchain/test/Main.hs` | `offchain/rig/driver-run-capture.json` | `driv01_*`/`driv02_*` checks read the committed artifact | ✓ WIRED | 83/83 pass against both the pre-existing committed artifact and a freshly-regenerated one |
| `offchain/rig/deploy-rig.sh` | `InitSwappableRig.s.sol` | `forge script --tc InitSwappableRig --broadcast --via-ir` with manifest-sourced env | ✓ WIRED | re-ran this session; probe swap succeeded, cross-checks all OK |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| DRIV-01 | 22-01, 22-02, 22-03, 22-04, 22-05 | Stochastic price path produces E3 per step against the live rig (mechanism corrected per user decision: hook self-writes, no offchain `writeTimepoint` client) | ✓ SATISFIED | 5/5 steps in the committed artifact plus an independently-reproduced 5/5 in this session; blocker discharge (`cheat-swap-proof.json`) measured, not argued |
| DRIV-02 | 22-01, 22-03, 22-06 | Stochastic V2 VolOrder creation against the live rig, single + batch, preview/readback incl. targetVega, E1 v2 under pinned topic0 | ✓ SATISFIED | `orders.single`/`orders.mixed`/`orders.n0` in the committed artifact, all reproduced independently this session |

No orphaned requirements: `.planning/REQUIREMENTS.md`'s Phase 22 rows are exactly DRIV-01/DRIV-02,
both declared and closed across the six plans above.

Note: `.planning/REQUIREMENTS.md`'s DRIV-01 prose still reads "drives
`RealizedVolatilityMod.writeTimepoint(uint32,int24)` per step" — this is the roadmap's original,
now-superseded wording. `22-CONTEXT.md` records the user's explicit architecture override (the hook
self-writes; the offchain side only observes) and states the required OUTCOME — one E3 per step
carrying the submitted tick — is unchanged. This is a stale requirement-text artifact, not a gap:
the outcome it exists to test is verified above by direct measurement.

### Anti-Patterns Found

None. `grep -rn -E "TODO|FIXME|XXX|HACK|PLACEHOLDER"` and `grep -rn -E "return null|return \{\}|=> \{\}"`
over `offchain/lib/CheatSwap`, `offchain/lib/RealizedVol`, `offchain/lib/Driver`, `offchain/lib/VolOrder`,
`offchain/app/Main.hs`, `offchain/app/CheatSwapProof.hs` — empty.

### Self-Reported Limitations — Judged

All six items named in the verification brief were checked directly against source, not against the
SUMMARY's description of them:

1. **F22-8 (skew=65535 exclusivity unverified)** — accurately characterized. `offchain/test/Main.hs:82`
   (`Position 1 is the discriminator...`) and the `driv02_mixed_batch_live` haddock both state the
   exclusivity is NOT claimed, and the check models exactly one business rule
   (`skew_is_in_domain`), stating so explicitly. Not hidden.
2. **F22-9 (replay projection's `vegas` field cannot discriminate)** — accurately characterized.
   `offchain/rig/README.md`'s "Replaying a run" section states in bold that projecting
   `.orders.mixed.submitted[].targetVega` and calling it a seed check is a trap, names the measured
   falsification (`RIG_SEED+1` moved ticks/ids and left `vegas` unchanged), and the actual replay `PROJ`
   in the README does not include `vegas`, so the trap is not live in the shipped procedure.
3. **22-05 `driv01_no_same_second_noop` was green under its own mutant until fixed (truncation
   blindness)** — confirmed real. The check now compares `length(steps)` against `configuredSize`
   (`offchain/test/Main.hs:3236-3243`, with the exact refutation narrated in-haddock at :3212-3223),
   and the fix is present in both `driv01_e3_per_step_matches_submitted` and `driv01_no_same_second_noop`.
4. **22-04 bits>=184 assertion doesn't discriminate on this rig** — confirmed real and honestly
   labelled. `offchain/test/Main.hs:2560-2565` states plainly the assertion HOLDS WITHOUT
   DISCRIMINATING on this rig (both high words are 0), and a genuinely discriminating assertion
   (`slot0_tick_of word_written == 5000`, ruling out a 160-bit-mask composition) is present beside
   it at :2619-2623.
5. **Phase 21 follow-up #5 (readback discards tickSpacing 104..127 and bits>=248)** — confirmed still
   open and honestly carried forward: `offchain/test/Main.hs:3433-3435` and `:3450-3453` both restate
   the limit verbatim at the point it is relied on, rather than only in a phase-21 document nobody
   would re-read.
6. **F22-1/F22-5 (`notes/DATA_CONTRACT.md:25` "same-block" wording refuted by execution)** —
   confirmed reported, not edited. `git log --oneline -- notes/DATA_CONTRACT.md` shows the file's
   last touch is the Phase 20 import commit (`d70e167`); `git status --porcelain notes/DATA_CONTRACT.md`
   is empty. The file still reads "A same-block second write emits NOTHING" — untouched by this
   workstream, exactly as the discipline in `22-CROSS-TRACK-FINDINGS.md` requires (plank-owned
   territory, REPORT never EDIT).

### The six refuted-discriminator findings — confirmed real and FIXED (not merely noted)

| id | finding | fix confirmed in current source |
|---|---|---|
| 21-03 | inequality-based `rpin06_perturbed_target_vega_fails_readback` could pass for the wrong reason | `offchain/test/Main.hs:1213-1216` — an unperturbed-baseline round-trip assertion was added FIRST and is load-bearing (21-03-SUMMARY.md: "the baseline assertion is the SOLE discriminator," fixed by asserting it) |
| 21-04 | `>= 8` bit-length-spread assertion cleared under a linear-uniform mutant | `offchain/test/Main.hs:1438-1440` — `bottom_decade >= 40` mass assertion added on top, MEASURED (77 vs 4 of 256) as the real shape discriminator |
| 22-02 | sign-extension decoder pinned only by a positive tick (37), couldn't distinguish signed from unsigned | `offchain/test/Main.hs:2001-2002` — `driv01_e3_tick_negative = -3145` added, re-verified RED under the mutant, GREEN after the fix (22-02-SUMMARY.md deviation 1) |
| 22-03 | `cabal test` silently ignored `RIG_MANIFEST` | `offchain/test/Main.hs:111-119` — `rig_manifest_path` now honours the env var; commit `585a2c2`; re-verified this session via `verify-rig.sh`/`verify-import.sh` passing against the live manifest |
| 22-04 | omitting the clock-advance call raced wall time rather than reliably reproducing the G1 collision | `CheatSwap.Rpc`'s `ForceTimestamp` constructs the collision deterministically instead of hoping for it (F22-7); `cheat-swap-proof.json`'s `same_second_repeat_step2` (`e3_count=0, e5_count=1, status=1`) is the constructed, reproducible measurement |
| 22-05 | `count(E5)==count(E3)==length(steps)` was blind to a truncated run | `driv01_e3_per_step_matches_submitted` and `driv01_no_same_second_noop` both additionally assert `length(steps) == configuredSize` (Main.hs:3146-3150, 3236-3243) |

All six are genuine source-level fixes, independently located and read in this session — not
inferred from SUMMARY prose.

### Human Verification Required

None. Every check in this report was reproduced by direct command execution against the live
codebase and, for the on-chain claims, against a freshly redeployed rig and an independently seeded
driver run in this session.

## Gaps Summary

None found. All 7 derived observable truths verified, all required artifacts present and wired, all
6 carried-forward findings from prior phases confirmed genuinely fixed (not merely disclosed), all 6
self-reported limitations in the 22-06 brief independently confirmed as accurate characterizations
rather than hidden defects, and the phase gate (build, 83/83 tests, chain-independence, territory
cleanliness, literal purge) was re-measured live rather than trusted from the prior self-report.

The one item worth carrying forward without blocking the phase: `.planning/REQUIREMENTS.md`'s
DRIV-01 prose still quotes the superseded `writeTimepoint` mechanism rather than the corrected
hook-self-write architecture recorded in `22-CONTEXT.md`. Cosmetic — the requirement's OUTCOME is
verified — but a future reader of REQUIREMENTS.md alone (without the phase context) would be misled
about the mechanism.

## Session housekeeping

Anvil was stopped mid-verification (to measure chain-independence with `pgrep anvil` truly empty)
and was restarted via `bash offchain/rig/deploy-rig.sh` before this report was written. The rig is
currently UP (pid 1167645, chain at block 20+, 9/9 contracts live). The committed
`offchain/rig/driver-run-capture.json` and `offchain/rig/cheat-swap-proof.json` were temporarily
overwritten by an independent live re-run (`RIG_SEED=999111222`) as additional evidence and then
restored to their original committed bytes; `git status --porcelain offchain/rig/` is empty.

---
*Phase: 22-live-stochastic-drivers*
*Verification closed: 2026-08-02*
*Verifier: Claude (gsd-verifier), independent re-derivation — supersedes the 22-06 self-report*
