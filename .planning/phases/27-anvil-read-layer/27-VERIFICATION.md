---
phase: 27-anvil-read-layer
verified: 2026-08-22T16:20:00Z
status: passed
score: 6/6 must-have truths verified (CHAIN-01 correctly accounted for as an externally-blocked,
  named dependency rather than a gap)
human_verification:
  - test: "Re-run offchain/rig/capture-chain-read.sh against a freshly deployed rig and confirm chain-read-conformance.json regenerates with unpinned_differs=true"
    expected: "The capture script fails loudly (never skips) if no anvil answers, and the committed artifact's self-checks (6 of them, in the script) all pass, producing a fresh chain-read-conformance.json"
    why_human: "This exercises a live anvil chain, which this verification pass did not stand up; the committed artifact was inspected and is internally consistent (unpinned_differs, pinned_equals_block_b, write_landed_above_b all true) and the `cabal test` suite that asserts over it offline (the_pinned_read_held_while_the_unpinned_read_moved) passed, but re-generating the artifact from a live chain was not exercised in this pass"
---

# Phase 27: Anvil Read Layer Verification Report

**Phase Goal:** A shock read off a live chain is a snapshot of ONE block, or it is an error. The
decoder built in Phase 26 meets a real mined `next` event, and every pool read is pinned to the
block that event was in.

**Verified:** 2026-08-22
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal has two halves, and they resolve differently. The half this workstream owns
("every pool read is pinned to the block that event was in") is fully built, tested against a
live rig, and green. The other half ("the decoder meets a real mined `next` event") depends on an
external workstream (plank/mev-migrate, issue #26) that has not yet emitted a mined `Shock`; this
is CHAIN-01, and it is correctly recorded as BLOCKED rather than silently dropped or falsely
claimed complete. `Chain.Shock`'s decoder (CHAIN-04, done in Phase 26) is ready and unaffected;
`Chain.Read`'s pinning is what stands between it and a real event once one exists.

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Every endpoint consumer resolves `ETH_RPC_URL` if set, else the default — one resolver, not N copies | VERIFIED | `offchain/lib/Chain/Endpoint.hs::resolve_endpoint`/`endpoint_from`, `offchain/rig/endpoint.sh`; census checks `every_endpoint_site_resolves_rather_than_hardcodes` and `the_endpoint_site_census_grows_with_the_tree` PASS in the live `cabal test` run (205/205) |
| 2 | The producer (`deploy-rig.sh`) binds the same endpoint as the consumers, and asserts chain id before any broadcast | VERIFIED | `deploy-rig.sh:54` sources `endpoint.sh`; `--host "$RPC_HOST" --port "$RPC_PORT"` at line 306; `cast chain-id` assertion at lines 341-360, strictly before the first `run_deploy`/`--broadcast` at line 495. Check `the_producer_and_the_consumers_bind_one_endpoint` PASSES |
| 3 | Every read function requires a `BlockRef` — no arity omits it | VERIFIED | `offchain/lib/Chain/Read.hs`: `newtype BlockRef = AtBlock Integer` (single constructor by construction), every exported read (`read_raw_word_token`, `read_pool_field`, `read_pool_state_word`, `read_sqrt_price_x96`, `read_liquidity`, `read_lp_fee`) takes `BlockRef` as a required positional argument. Check `no_read_can_omit_its_block` PASSES |
| 4 | `Latest`/moving-head appears nowhere in the read layer, with a proven positive control | VERIFIED | Check `latest_appears_nowhere_in_the_read_layer` seeds a positive control (`moving_head_positive_control`) before asserting absence, and PASSES |
| 5 | A pinned read returns the event-block value while an unpinned read is OBSERVED returning a different one | VERIFIED | Committed `offchain/rig/chain-read-conformance.json`: `pinned_equals_block_b: true`, `unpinned_differs: true`, `pinned_and_unpinned_disagree: true`, `write_landed_above_b: true`, produced against the live rig (poolManager `0x5fc8d3269...`, chainId 31337) via `offchain/app/ChainReadConformance.hs`. Offline check `the_pinned_read_held_while_the_unpinned_read_moved` asserts over this artifact and PASSES |
| 6 | An absent, zero or unparseable read is an error naming the field, never a value that reaches a key | VERIFIED | `Chain.Read.refuse_or_value`/`decode_word_token`/`refusal_naming_of` implement 5 distinct refusal diagnoses (negative height, absent, unparseable in 4 sub-shapes, all-zero word, per-field decoded zero via `zero_is_refused`), each naming the field DELIMITED (`decoy_field_name = "liquidityNet"` used to prove the delimiter matters). Check `a_zero_or_absent_read_is_refused_by_field_name` PASSES with 12 refusal rows and 4 acceptance rows |
| 7 | The published fixture records `pool`, `blockNumber` (string) and `chainId` so a consumer can attach | VERIFIED | `Chain.Read.FixtureIdentity`/`render_fixture_identity`; check `the_fixture_carries_the_pool_identity_it_was_solved_for` parses the rendered JSON with a real parser and asserts key set, address shape, non-zero address, string-of-digits blockNumber, numeric chainId — PASSES |
| 8 | `blockNumber` as a JSON number is OBSERVED losing precision above 2^53 | VERIFIED | Check `a_block_number_above_two_to_the_fifty_three_is_OBSERVED_losing_precision_as_a_number` drives `2^53+1` through a `Double` decode and shows it come back `9007199254740992` (short by 1), asserting the witness is strictly above the ceiling first — PASSES |
| 9 | CHAIN-01 is recorded BLOCKED by name with its dependency, not silently omitted | VERIFIED | `27-SUMMARY.md` names the dependency (plank/mev-migrate, issue #26, `SELECTOR_NEXT 0xd3827b0b`), states there is no deploy script for the Shock writer, and states what would discharge it (a driver emitting one mined `Shock`). `REQUIREMENTS.md`'s per-requirement CHAIN-01 row and the roadmap-time phase table both carry the BLOCKED status |
| 10 | CHAIN-01's stale "`next` event" wording is corrected | VERIFIED | `REQUIREMENTS.md:145-153` — the checkbox item now reads "The `Shock` event is decoded..." with a correction note explaining `next(...)` is a function selector, never an event, with the topic0 verified against `cast keccak` |

**Score:** 10/10 truths verified (9 requirement-level truths plus the CHAIN-01 disposition truth;
all pass).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `offchain/lib/Chain/Endpoint.hs` | the one resolver, and the site manifest | VERIFIED | Exports `resolve_endpoint`, `endpoint_from`, `default_endpoint`, `endpoint_sites` (18 entries, counted on disk), `endpoint_census_terms`, `chain_reaching_terms`. Substantive, not a stub — 380 lines with load-bearing haddock explaining measured defects |
| `offchain/rig/endpoint.sh` | shell half of the resolver | VERIFIED | Sourced (not executed) by `deploy-rig.sh` and both capture scripts; states `ETH_RPC_URL_DEFAULT` once, parses host/port, fails loudly on malformed input |
| `offchain/lib/Chain/Read.hs` | `BlockRef`-required pool reads; refusals naming the field; `FixtureIdentity` | VERIFIED | 638 lines. `newtype BlockRef`, `refuse_or_value` total function with 5 refusal diagnoses, `FixtureIdentity`/`render_fixture_identity` for CHAIN-05 |
| `offchain/rig/capture-chain-read.sh` | out-of-band capture, CHAIN-02's observational half | VERIFIED | Fails loudly (never skips) on missing manifest/import-ref/pool/chain answer; 6 self-checks over the produced artifact before accepting it, including the load-bearing `unpinned_differs == true` gate |
| `offchain/rig/chain-read-conformance.json` | committed artifact, measured not fabricated | VERIFIED | Present, well-formed, `generatedFrom` points at a real commit (`2039f27`, confirmed via `git cat-file`), `unpinned_differs: true`, refusal messages match `Chain.Read`'s actual text |
| `deploy-rig.sh` | producer binds the same endpoint (CHAIN-07) | VERIFIED | Sources `endpoint.sh`; `--host`/`--port` derived from it; `cast chain-id` asserted before the first `--broadcast` |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `deploy-rig.sh` (producer) | `Chain.Endpoint`/`endpoint.sh` (resolver) | sourced shell variable, asserted byte-equal to the Haskell literal | WIRED | Check `the_producer_and_the_consumers_bind_one_endpoint` PASSES |
| `Chain.Read` reads | `BlockRef` | required positional argument, no default, no `Maybe` | WIRED | Type-level; `no_read_can_omit_its_block` PASSES |
| `offchain/app/ChainReadConformance.hs` | `Chain.Read` | the only executable that exercises `read_pool_field`/`read_raw_word_token`/`block_param` (advertised-and-dead surface otherwise) | WIRED | Confirmed by `EndpointSite` manifest entry and the committed artifact's contents |
| `chain-read-conformance.json` | `cabal test` | offline assertion, not a live socket | WIRED | `the_pinned_read_held_while_the_unpinned_read_moved` reads the committed file; `the_suite_never_reaches_a_chain` (3rd structural grep, with proven positive control) asserts `Main.hs` opens no socket of its own |
| `Chain.Shock` (CHAIN-04) | `Chain.Read`/`FixtureIdentity` | `fi_pool` takes the 160-bit value `Chain.Shock` hands over | WIRED | `render_fixture_identity` test uses `se_pool` from a decoded corpus member — the pool is explicitly labelled SYNTHETIC pending CHAIN-01 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| CHAIN-01 | (context, not shippable this phase) | The `Shock` event decoded from a mined transaction's logs | **BLOCKED, correctly named** | `27-SUMMARY.md` names the dependency (plank/mev-migrate, issue #26) and what would discharge it; `REQUIREMENTS.md` checkbox unchecked, wording corrected |
| CHAIN-02 | 27-02 | Pool reads pinned to a single block, not `latest` | SATISFIED | `no_read_can_omit_its_block`, `latest_appears_nowhere_in_the_read_layer`, `the_pinned_read_held_while_the_unpinned_read_moved` all PASS; live-rig artifact confirms divergence |
| CHAIN-03 | 27-02 | Absent/zero/unparseable read is a named error | SATISFIED | `a_zero_or_absent_read_is_refused_by_field_name` PASSES, 12 refusal rows + 4 acceptance rows, delimited naming proven against a real prefix collision (`liquidity`/`liquidityNet`) |
| CHAIN-04 | (26-02, prior phase) | Decoding exercised against synthetic logs | SATISFIED (pre-existing, unaffected) | Not re-verified in depth here; out of this phase's scope per ROADMAP |
| CHAIN-05 | 27-03 | Fixture records `pool`, `blockNumber` (string), `chainId` | SATISFIED | `the_fixture_carries_the_pool_identity_it_was_solved_for` and the precision-witness check both PASS |
| CHAIN-06 | 27-01 | Every endpoint consumer resolves `ETH_RPC_URL`/default — one rule | SATISFIED, text corrected | Manifest holds 18 entries (verified by direct count); "nine sites" wording corrected to state the measured 10/11/0 history in `REQUIREMENTS.md:166-179` |
| CHAIN-07 | 27-01 | Producer binds the same endpoint as consumers | SATISFIED | `the_producer_and_the_consumers_bind_one_endpoint` PASSES; chain-id assertion precedes first broadcast, confirmed by direct file inspection |

No orphaned requirements: all seven CHAIN-* IDs are accounted for in `REQUIREMENTS.md`'s
traceability table, cross-referenced against the three plans' `requirements:` frontmatter
(27-01: CHAIN-06/07; 27-02: CHAIN-02/03; 27-03: CHAIN-05), plus CHAIN-01 (context-blocked) and
CHAIN-04 (prior phase).

### Executor-Reported Corrections — Verified Landed

| Correction | Verified? | Where |
|---|---|---|
| CHAIN-01 `next`-event wording corrected | YES | `REQUIREMENTS.md:145-153` — checkbox item now says "The `Shock` event is decoded...", with a correction note explaining `next(...)` is a function selector never an event, topic0 verified against `cast keccak`, status left unchecked/BLOCKED |
| CHAIN-06 "nine sites" text corrected | YES | `REQUIREMENTS.md:166-179` — states the measured TEN/ELEVEN/ZERO history and points at `Chain.Endpoint.endpoint_sites` (18 entries) as the durable form |
| ROADMAP phase-27 line corrected | YES | `.planning/ROADMAP.md:771` — states "CHAIN-02, CHAIN-03, CHAIN-05, CHAIN-06, CHAIN-07 shipped; CHAIN-04 landed at 26-02", explicitly flags "TEXT CORRECTED AT CLOSE" noting the old line wrongly implied CHAIN-02/03 were blocked |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `.planning/REQUIREMENTS.md` | ~284-301 | A second, roadmap-time "Phase | Requirements | Count | Blocked?" table still reads "27 — Anvil Read Layer \| CHAIN-01, CHAIN-02, CHAIN-03 \| 3 \| Yes — plank worktree must emit `next`", contradicting the corrected per-requirement traceability table 20 lines above it (which correctly shows CHAIN-02/03/05/06/07 complete and only CHAIN-01 blocked) | ℹ️ Info | Not a functional gap and not one of the three corrections this verification was asked to check, but it is a genuine internal inconsistency in `REQUIREMENTS.md` that a future reader skimming only that table would be misled by. Worth a follow-up edit, not a phase-blocking issue |

No blocker or warning-level anti-patterns found in the code artifacts (`Chain/Endpoint.hs`,
`Chain/Read.hs`, `deploy-rig.sh`, `capture-chain-read.sh`, `endpoint.sh`): no TODO/FIXME/
PLACEHOLDER markers, no empty-body handlers, no vacuous `return null`/`return []` shapes. Every
Check registered in `core_checks` (9 phase-27 checks plus the pre-existing `the_pinned_read_held_
while_the_unpinned_read_moved`) is present, non-trivial, and observed passing in a live
`cabal test` run.

### Measured Independently (this verification pass)

- `cabal build --enable-tests -j all` → exit 0, 0 warnings
- `cabal test` → **205/205 checks passed**, exit 0, wall time 2m50s (SUMMARY claimed 205/205 and
  ~3m15s; both match within normal variance)
- `purge_file_floor`: `find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \) -type f | wc -l` → **72** (matches SUMMARY)
- `credential_scan_floor`: same plus `-o -name '*.json'` → **83** (matches SUMMARY)
- DB-free structural grep (`grep -cE 'Store\.Postgres|CFMM_REQUIRE_DB|connectPostgreSQL' offchain/test/Main.hs`) → **0**
- `endpoint_sites` manifest → **18** entries (counted directly in `Chain/Endpoint.hs`, matches SUMMARY)
- `chain-read-conformance.json`'s `generatedFrom` commit (`2039f27`) → confirmed a real commit in this repo's history
- All 10 commit SHAs listed in `27-SUMMARY.md`'s commit table → confirmed present via `git cat-file -t`
- Territory grep (`git status --porcelain src test foundry-scripts Makefile foundry.toml .github`) → empty
- `STATE.md` frontmatter → intact, `milestone: v6.0`, consistent with the 24-03 warning (only the three `state` subcommands rewrite it)

### Human Verification Required

1. **Re-run the live capture and confirm reproducibility**
   **Test:** `bash offchain/rig/deploy-rig.sh && bash offchain/rig/capture-chain-read.sh`
   **Expected:** The rig stands up, the capture regenerates `chain-read-conformance.json` with
   `unpinned_differs: true` and all 6 of the script's self-checks passing, and `cabal test` still
   reports 205/205 against the freshly regenerated artifact.
   **Why human:** This verification pass inspected the committed artifact and the offline check
   that asserts over it (both consistent and passing), but did not stand up a live anvil to
   regenerate the artifact from scratch — that is an out-of-band, non-idempotent, stateful
   operation per the script's own documentation ("this MUTATES the chain... it must not be run
   against a rig whose state another measurement depends on").

### Gaps Summary

No gaps. All must-haves from the three plans' frontmatter are verified against the actual
codebase and a live `cabal test` run (205/205, exit 0). CHAIN-01 is the one requirement not
shipped, and it is correctly and consistently recorded as externally BLOCKED — with the
dependency named (plank/mev-migrate workstream, issue #26, `SELECTOR_NEXT 0xd3827b0b`) and what
would discharge it stated (one driver emitting a single mined `Shock`) — in `27-SUMMARY.md`,
`REQUIREMENTS.md`'s per-requirement table, and `ROADMAP.md`'s phase-27 line. All three
executor-reported text corrections (CHAIN-01 wording, CHAIN-06 "nine sites", ROADMAP phase-27
line) are confirmed landed. The only issue found is a minor, pre-existing internal inconsistency
in a second, older summary table inside `REQUIREMENTS.md` that was not in scope for this phase's
corrections and does not affect the shipped code or the per-requirement traceability that
downstream tooling and readers actually consult.

---

*Verified: 2026-08-22*
*Verifier: Claude (gsd-verifier)*
