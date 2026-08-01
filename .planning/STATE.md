---
gsd_state_version: 1.0
milestone: v5.0
milestone_name: VolOrder V2 Offchain Re-Pin + Stochastic Drivers (rpc_api workstream)
status: in-progress
stopped_at: Completed 21-05-PLAN.md — PHASE 21 COMPLETE
last_updated: "2026-08-01T19:52:39.399Z"
last_activity: "2026-07-31 — 20-02 executed: 36 artifacts imported by checkout from 9f5ccba,"
progress:
  total_phases: 19
  completed_phases: 10
  total_plans: 26
  completed_plans: 26
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value (v4.0):** `VolOrderManagerMod.plk` is a vol-order REGISTRY — `create_order(uint88,uint24,uint16)` (strike/width/skew, selector `0x6501fe94`) validating against the machine-checked `vol_order_is_complete` predicates, assigning a sequential id, storing a packed `VolOrder` word — plus a BEST-EFFORT batch entrypoint running N create_order calls in one tx (invalid tuples skipped, batch never reverts). Built for the rpc_api Haskell `StochasticOrderGen` consumer (PR #9 awaits this surface). Every claim is a CALLED test or an OBSERVED mutation kill; compiling is NOT evidence; the gate is the batch dispatch being CALLED green through FFI-deployed bytecode (**CORRECTED at 19-05** — `PLANK_SKIP` is the rescue queue for entrypoints that do NOT compile, so this module never belonged there; the queue is empty and there was no exit to perform).
**Current focus:** **MILESTONE v4.0 COMPLETE (2026-07-21).** All five phases (16, 17, 18a, 18b, 19) and all 15 requirements shipped. `VolOrderManagerMod.plk` is a proven vol-order registry: `create_order` and `create_orders` both CALLED green through FFI-deployed bytecode, a 10-application mutation battery with ZERO survivors, an independent-mock sequence differential at tol 0, and a consumer golden fixture from an encoder outside this repo. Next action: tag v4.0 and hand off to peer `mv15a18k`, OR resume v2.0 (`/gsd:plan-phase 10`).

**Track note:** Fifth milestone — v5.0 is the **rpc_api workstream's** (offchain Haskell, branch `feat/rpc-api`); v6.0 (subgraph, issue #14) queued behind it. v3.0 (VegaAccountMod vault, Phases 12–15) SHIPPED 2026-07-19 (tag `v3.0`). v1.0 (GAMS plumbing, Phases 1–7) PAUSED. v2.0 (vol-oracle differential, Phases 8–11) PAUSED after Phase 9 — VDIFF-05..08 (Phases 10–11) remain pending, NOT part of v4.0. Resuming v2.0 = `/gsd:plan-phase 10`. These phase ranges are separate tracks — never renumbered.

## Current Position

Phase: 21 — V2 ABI Re-Pin & targetVega Generation (RPIN-*) — **COMPLETE**
Plan: 5 of 5 complete (21-01, 21-02 wave 1; 21-03 wave 2; 21-04 wave 3; 21-05 wave 4 — all DONE).
Next action: **Phase 22 — Live Stochastic Drivers (DRIV-01, DRIV-02)** — `/gsd:plan-phase 22`.

Status: **21-05 DONE — RPIN-05 satisfied. PHASE 21 COMPLETE: all seven requirements
(RPIN-01..06 + VEGA-01) shipped.** The V2 `(bool,uint256)[]` batch return captured off the live
Phase-20 module by 21-02 is now asserted **byte-for-byte against the v4.0 alloy golden** — an
encoder outside this repo and outside this language — including `N0_empty` at **exactly 64
bytes**, the clause v4.0's exit record named as the one most likely to break a consumer. Four new
`rpin05_` checks: provenance/freshness, the golden diff (word-by-word, tolerating a difference
ONLY in order-id words and failing anything else as an encoding FINDING), a decode through the
**shipped** `decode_create_orders_result`, and canonical bool words read STRAIGHT OUT OF THE BYTES
so the check does not ride on the decoder it checks. `cabal test` = **65/65** (61 → 65), exit 0,
zero `-Wall` warnings.
**CHAIN-INDEPENDENCE PROVEN, not asserted:** `deploy-rig.sh --stop` → `pgrep anvil` EMPTY →
`cast block-number` errors → `cabal test` still exits 0 at 65/65. The suite opens no socket
(`grep -cE 'cast call|HttpProvider|8545' Main.hs` = 0); it consumes the committed,
provenance-bearing artifact instead, and checks THAT for staleness.
**THE PHASE GATE CLOSES GREEN AND `cabal run`'s DEMO ORDER NOW MINES.** 20-05 recorded it
REVERTING because `Encoding.hs` still built the retired 3-arg `create_order` — the exact defect
this phase existed to fix. Receipt **status success**, an **`ORDER_CREATED` log carrying
`target_vega 1000000000000000000`**, price + path written, and the batch **2 succeeded / 0
failed**. **Beyond plan scope, closing 21-04's carry-forward:** those two batch orders came from
`run_order_gen` → `attach_vega` → `draw_target_vega`, so DRAWN vegas were mined and read back out
of chain storage — **6.394e18 and 935.46e18**, two decades apart, both in the `[1e18, 1e21]` band.
The generator's drawn orders had never touched a chain before.
**TWO PLAN/CARRY-FORWARD CLAIMS MEASURED AND REFUTED — the headline discipline.** (1) The plan
instructed writing follow-up **#5 = ADDRESSED** into this workstream's verification record. It is
**FALSE**: `verify_mined_order` (`Rpc.hs:94-104`) is unchanged and compares the 4-field record,
so `unpack_vol_order_storage` discards tickSpacing (104..127) and junk (>= 248) BEFORE the
comparison — exactly the drift #5 asks to catch. Recorded **PARTIALLY ADDRESSED**. (2) 21-02's
carry-forward D2 named `blockNumber` a discriminating provenance field; three from-scratch deploys
of the same rig gave heights **9, 11 and 10**, so asserting it would redden the suite after any
redeploy. The check asserts `chainId` + `manager` only.
**THREE MUTATIONS, THREE REDs, all restored sha256-identical.** A flipped COUNT byte reddens the
golden diff AND the decode; a flipped OFFSET byte reddens only the golden diff — because
`decode_create_orders_result` **never reads word 0 at all**, which is the first ever demonstration
of this workstream's tracked follow-up **#2**. An altered `.manager` reddens ONLY the freshness
check, so provenance and payload fail independently and are not entangled.
**DEFERRED ITEM CLOSED:** `sc4_no_retired_value_is_live` now compares **NUMERICALLY**. 21-03
measured it staying GREEN while a retired value was live (left-padded 66-char form vs the 10-char
entry). Under 21-03's IDENTICAL injection the suite now reports **4 failures where 21-03 recorded
3**. **NEW F4:** the freshness check cannot see a module CHANGE — `manager` is a `CREATE` address,
bytecode-independent and measured identical across three deploys; code-hash pinning proposed, not
applied. Findings F1/F2 (plank track) reported, never edited; territory clean.
**Rig left RUNNING** (pid 366381, block 12, `orderCount = 3` — the gate mined three real orders;
nothing in `cabal test` depends on rig state). Stop with `bash offchain/rig/deploy-rig.sh --stop`.

### 21-04 (wave 3, kept in full)

Status: **21-04 DONE — VEGA-01 satisfied. The fourth field now comes from somewhere, and that
somewhere is written down in the type.** `StochasticOrderGen` carries
`vega_draw :: VegaDraw`, a ONE-constructor sum type whose haddock holds the whole justification:
the dimension (RAW Uniswap L, `UNITS_AND_SCALES.md` §2 — not X96, not WAD, not collateral), the
four-row `L = amount1 / (1 - 1.0001^(-w/4))` table instantiated on THE RIG'S OWN POOL
(`initTick = 0`, 18-decimal tokens) giving full-range 1.000e18 down to a ~20-tick band 2.001e21,
the u96 headroom (7.9e7x), the arXiv:2205.08904 mean/median ≈ 10 skew that makes the quantity
log-scale, the explicit rejection of linear-uniform and of a constant, and THE HONEST LIMIT —
no source pins a SAMPLING LAW; a second constructor is the extension path. The caveat is a
comment, never a hedge in the implementation. `draw_target_vega` draws log-uniformly and guards
LOUDLY at draw time, BEFORE any tx is built, so a mis-parameterised law cannot leave a
partially-sent batch behind. **`OrderShape` removes the discarded-placeholder trap
structurally:** `orders :: [OrderShape]` carries no vega for a caller to supply and the
generator to silently overwrite — `grep 'target_vega =' Sample.hs` returns exactly ONE line
(`sample_order`, the single-call demo that does not go through the generator). The draw happens
ONCE PER ORDER AT GENERATION TIME, so a retried send re-sends the same order. `cabal test` =
**61/61** (58 → 61), exit 0, zero `-Wall` warnings; **no new dependency** (`create`, not the
vector-seeded initialiser; cabal file diff EMPTY).
**THE PLAN'S OWN PREDICTED DISCRIMINATOR WAS MEASURED AND REFUTED — the headline finding.** The
plan asserts the linear-interpolation mutant is caught by the `>= 8` distinct-bit-lengths
assertion. It is NOT: a linear-uniform draw spans **9** bit-lengths (62..70) over 256 fixed-seed
draws because the smallest of 256 uniforms still reaches 4.57e18. With only the VALUE pins
neutralised the whole check **PASSES under the mutant** (59/61) — bounds, 256/256 distinct, and
the spread assertion all survive a law that is not the decided law. This is wave 2's inequality
lesson recurring one layer up. Two fixes landed: a **bottom-decade mass** assertion (77 of 256
below 1e19 under log-uniform vs **4** under linear-uniform; threshold 40) which kills the mutant
ON ITS OWN, and **two independent VALUE pins** — `log_uniform_reference` (a second
implementation checked elementwise against all 256 draws on the same uniforms) and
`vega01_first_twelve` (a golden literal pin of the RNG stream, which the reference cannot catch
because it would FOLLOW a stream change). The reference pin is what actually reddened, at draw 0.
The first 12 draws reproduce the planner's independent probe values EXACTLY, in sequence.
**NEW FINDING F3, logged not fixed:** the zero-lower-bound rejection is **INCIDENTAL**, not an
explicit guard — `v >= max 1 lo` with `lo = 0` reduces to `v >= 1`, and `LogUniform 0 1e21`
fails today only because the log transform evaluates `0 * Infinity = NaN`. MEASURED: under the
linear mutant (which does not divide by `lo`) a zero lower bound sailed straight through and
returned a value. **Whoever adds the second `VegaDraw` constructor must supply its own parameter
validation.** `cabal build -j all` confirmed VACUOUS a THIRD time (exit 0 against a test suite
that would not compile). The rig was NOT touched — no tx, no snapshot, no `cabal run` — so
21-05's block-9 / `orderCount = 0` freshness dependency is intact. Territory clean.

### 21-03 (wave 2, kept in full)

Status: **21-03 DONE — RPIN-04 and RPIN-06 satisfied. The E1 event decoder now speaks V2, and
this is the first plan in the phase whose central claim is backed by a REAL CHAIN LOG.**
`decode_order_created` was rewritten from the v1 three-topic/five-word shape to `@evm_log2`'s
two topics `[topic0, orderId]` over 128 bytes = four data words `[strike, width, skew,
targetVega]`, with a `>= 128`-byte length guard so a short payload yields `Nothing` instead of a
silent, plausible `targetVega = 0`. `OrderCreatedEvent` lost `orderOwner`/`orderCreatedAt`
outright — neither value exists in a v2 log — and gained `orderId` (from the INDEXED topic) and
`orderTargetVega`. **RPIN-04 was NOT a constant swap and that was measured first:** the TDD RED
is ASSERTION-level (unlike 21-01's compile-level one) and recorded the shipped decoder returning
`Nothing` on a v2 log, i.e. reporting every real log as "unknown" forever with no wrong value to
notice. `cabal test` = **58/58** (51 -> 58, seven new checks), exit 0, zero `-Wall` warnings;
purge grep empty; `generate-pins.sh` byte-identical.
**FIRST E1 v2 LOG EVER OBSERVED ON CHAIN.** 21-02 could not capture one (`eth_call` emits no
logs). One real `create_order` was sent inside `evm_snapshot`/`evm_revert`: **2 topics, 128
bytes / 4 data words, topic0 identical to the pin, `orderId = 1` in topic 1 ONLY (never in the
payload), data = (12345, 600, 77, 1e18)** — every source-derived structural claim confirmed. The
rig was then restored and re-verified: **block 9, `orderCount` 0, `SC-2 OK: 7 contracts live`**,
so 21-05's freshness dependency is intact. The test suite remains chain-independent.
**TWO mutants, TWO REDs, both restored sha256-identical, plus a SECOND-ORDER measurement.** The
stale-pin injection reddens `rpin04_topic0_is_recomputed`, `sc4_pin_topic0_VolOrderCreated` and
`sc4_cast_agreement` with the recomputed value CORRECT and the pin wrong; the `target_vega = 0`
mutant reddens `rpin03_storage_round_trip`, `rpin_v2_layout_behavior` and
`rpin06_perturbed_target_vega_fails_readback`. **Then the inequality doubt wave-1 raised was
MEASURED, not argued:** with rpin06's baseline round-trip assertion neutralised, the check
PASSES under that mutant (`0 /= 10^18` satisfies the inequality; the other fields are untouched).
The baseline is the SOLE discriminator — the perturbation half is a localisation argument on top
of a correctness fact it does not supply. `rpin06_target_vega_reaches_every_sender` stayed green
as predicted and is labelled STRUCTURAL in-file: it proves routing, never any value.
**NEW FINDING, logged not fixed:** `sc4_no_retired_value_is_live` STAYED GREEN while a retired
value was live — it compares pin values as STRINGS, so the left-padded 32-byte form of the
10-character `0xa8892769` does not match. The retired-value guard is defeated by zero-padding,
which is exactly the form a topic0 takes on the wire. Pre-existing (Phase 20's check);
`deferred-items.md` carries it with the fix (numeric comparison). Territory clean.

### 21-01 (wave 1, kept in full)

Status: **21-01 DONE — RPIN-01/02/03 satisfied. All three client-side wire layouts now speak V2
and the V1 3-arg path is GONE from `offchain/`.** `VolOrder` carries `target_vega` (raw Uniswap
`L`, `[1, 2^96-1]`); `encode_create_order` emits the 4-arg form and its selector is proven equal
THREE ways — the bytes the encoder emits, a keccak recomputed in the test from the signature
string PARSED OUT OF `VolOrderManagerInterface.plk`, and `rig-pins.json`'s generated pin;
`pack_vol_order_input` packs `skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223`
with bits >= 224 zero over a six-corner corpus including `2^96-1`; `unpack_vol_order_storage`
reads the 248-bit word with `targetVega` at 152..247, round-tripped against a TEST-ONLY second
implementation (`pack_storage_reference`) rather than against the library's own packer. An order
is exhibited whose input word differs from its storage word AT THE SPECIFIC BITS (104..127 holds
`width=600` vs `tickSpacing=20`; `targetVega` at 128 vs 152). `cabal test` = **51/51**, exit 0,
zero `-Wall` warnings; purge grep empty; `generate-pins.sh` re-run byte-identical.
**TWO mutants, TWO REDs, both restored sha256-identical, each with its HONEST NEGATIVE recorded**
— `shiftL 120` reddens only the layout checks (the calldata and rejection checks correctly stay
green: independent encoder path, and bounds are not positions), and `shiftR 144` reddens the
storage round-trip while `rpin03_input_word_is_not_storage_word` stays GREEN because its assertion
is an INEQUALITY. Territory clean. Findings F1 (stale V1 comment) and F2 (`TICK_SPACING = 20` vs
pool `tickSpacing = 10`) REPORTED, not fixed — plank track's files.

### 21-02 (same wave, kept in full)

Status: **21-02 DONE — RPIN-05 satisfied. The V2 `(bool,uint256)[]` batch return has been
OBSERVED on chain for the first time.** Until now its shape was derived from emitter source and
repeated through a hand-off document; anvil was down through the whole research pass. The rig was
stood up from scratch (`pgrep anvil` was EMPTY at execution start — the "anvil is already running"
context claim was STALE) and `verify-rig.sh` printed `SC-2 OK: 7 contracts live,
RealizedVolatilityMod seeded`. `offchain/rig/capture-batch-return.sh` then captured four cases by
`eth_call` into the committed `offchain/rig/batch-return-capture.json`, carrying its own
`chainId=31337` / `manager` / `blockNumber=9` provenance because `rig-manifest.json` is gitignored.
**`N0_empty` is EXACTLY 64 bytes and byte-identical to the v4.0 alloy golden — and so are
`N1_success` and `N2_success_then_fail`.** All THREE match `expected[0..2]` exactly, stronger than
the plan expected: `eth_call` never advances `orderCount`, so every case ran against a registry as
fresh as the golden's. The `differs_only_in_order_ids` comparator was built and never needed
(recorded `false` on all three). **`N1_dirty_vega` proves live that `targetVega = 2^96` comes back
`(false, 0)`** — indistinguishable from a business rejection, which is the concrete justification
for 21-01's client-side `in_range 96` guard. Five runs, one normalised sha256
`786c9506…824c0cd7`. `cabal test` exits 0 (45/45; the 44→45 move is 21-01's in-flight work, not
this plan's) and the repo-wide `offchain` hex-literal scan is still empty. **Hazard F1 CONFIRMED
and REPORTED, not fixed:** `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` is a stale V1
comment block contradicting its own file's V2 code at 229-235 — it belongs to the plank track. The
warning lives in `capture-batch-return.sh` above `input_word()`. **anvil LEFT RUNNING** (pid
222750, block 9) for 21-05's freshness assertion. Territory clean: `src/ test/ foundry-scripts/
Makefile foundry.toml remappings.txt` byte-untouched.

### Phase 20 (superseded position, kept for the record)

Phase: 20 — Deploy Rig & Source-of-Truth Import (RIG-01) — **COMPLETE**
Plan: 5 of 5 complete (20-01, 20-02, 20-03, 20-04, 20-05 all DONE — wave 4 landed)
Status: **PHASE 20 COMPLETE — RIG-01 SATISFIED and marked complete in REQUIREMENTS.md.**
The offchain executable surface holds **ZERO** address, selector or topic0 literals:
`grep -rnE '0x…{40}\b|0x…{64}\b|0x…{8}\b' offchain --include='*.hs' --include='*.sh'` produces **no
output**. Six literals were purged, not the research inventory's four — `check-upstream.sh` carried
both `create_order` selectors and is IN the decided `*.hs`/`*.sh` scope; both now come from
`rig-pins.json` via `jq`. **The purge fixed a LIVE bug, MEASURED:** `Sample.hs`'s
`price_setter_hook` literal has **zero bytecode** on the deployed rig (`cast code` returns `0x`)
while the manifest's `PriceSetterHook` has 2183 bytes — the driver's whole price-write path was
aimed at an address with no contract at it. `Main.hs` calls `load_rig` FIRST, before the RNG and
any RPC call; with the manifest moved aside it exits 1 naming the resolved path AND `deploy-rig.sh`,
with no fallback. **`cabal test` = 44/44, exit 0, zero `-Wall` warnings** — 35 per-pin checks (30
selectors + 5 topic0s), each recomputing from the signature PARSED OUT OF the `.plk` file its own
`source` field names, by a **second independent parser** anchored differently from
`generate-pins.sh`'s. **OBSERVED RED for the right reason:** a one-character pin corruption
(`0x98d950ec`→`0x98d950ed`) reddens exactly `sc4_pin_selector_create_order` and
`sc4_cast_agreement` at 42/44 exit 1 — with the recomputed value CORRECT and the pin wrong, both
`keccak256` and `cast` saying so independently — and `git checkout` restores 44/44. The wrapped
`TimepointWritten` and the already-canonical form both pass; `sc4_falsifiable` drives THE SAME
checker with the retired stale topic0 read from the pin file. **SC-5:** `offchain/rig/README.md`
was run top to bottom and every step exited 0. Territory clean: `src/ test/ foundry-scripts/
Makefile foundry.toml remappings.txt` byte-untouched. Next action: **Phase 21 (RPIN-*)** — re-pin
the encoder/decoder, which still speak v1 (documented, pre-existing).

### 20-04 (superseded position, kept for the record)

**20-04 COMPLETE — every pin is GENERATED, and the Haskell side loads both manifest halves.**
`offchain/rig/generate-pins.sh` emits `offchain/rig/rig-pins.json` — **30 selectors + 5 topic0s + 3
retired values, not one hex digit typed.** Every value is computed by `cast sig`/`cast keccak` from a
signature string PARSED out of an imported `.plk`, then asserted equal to that file's own declared
`const`; **all 35 agreed, zero disagreements.** The generator holds **zero** hex literals and the
committed file names the signature AND the source path for every pin. Idempotent (2nd run leaves
`git diff` clean). The five SC-4 targets are exact. **The multi-line case is proven untruncated and
the hazard MEASURED:** a naive single-line parse of `TimepointWritten` yields `0xc0055983…`, a
perfectly valid-looking wrong 32-byte hash — only the in-file cross-check separates them.
**Idempotency of the normaliser is proven by CROSS-FILE AGREEMENT, not asserted:** four names
(`TimepointWritten`, `WindowChanged`, `FeeConfigurationChanged`, `getAverageVolatility`) are declared
in two files in two different comment shapes — decorated (`indexed` + param names, wrapped) and
already-canonical — and both paths produced identical strings and identical values. 7 valueless
consts in `IMarketStateSocket.plk` skipped DELIBERATELY, named and counted on every run. `Rig.Manifest`
returns ONE `Rig`; **zero optional fields, zero defaulted addresses, zero `-Wall` warnings.** It
decoded **20-03's REAL manifest** (which already existed this wave) — **matching schema B with ZERO
deviation, so there is nothing for 20-05 task 1 to reconcile** — and fails loudly on a deleted
contract, a deleted `accounts.deployer`, a deleted `pool.tickSpacing` and an absent file, each naming
the resolved path and `deploy-rig.sh`. All guards FALSIFIED in a scratch mirror; `src/`,
`foundry-scripts/`, `notes/`, `test/`, `Makefile` byte-untouched. Next action: execute `20-05`
(reconciliation + literal purge).

### 20-03 (superseded position, kept for the record)

**20-03 COMPLETE — the rig is LIVE on anvil and the manifest exists.**
`bash offchain/rig/deploy-rig.sh` takes a machine with no anvil running to all SEVEN contracts plus
`offchain/rig/rig-manifest.json` (GITIGNORED). Every address came out of foundry's broadcast JSON
and was independently confirmed against the deploy script's own console line, both sides lowercased;
accounts derived with `cast wallet address`, seed a fixed literal, no `date +%s` and no nonce
arithmetic anywhere. **SC-2 green and FALSIFIED:** `verify-rig.sh` exits 0
(`7 contracts live, RealizedVolatilityMod seeded`) and all six injected faults exit 1 — including
two that a live-vs-empty check alone would have missed (pointing RealizedVolatilityMod at a LIVE
17151-byte PoolManager, and swapping the hook's PoolManager for the OTHER live PoolManager).
**SC-5 MEASURED:** two from-scratch runs give a byte-identical manifest, normalised sha256
`197acd74…5888f354`, with `generatedAt` differing (18:46:13Z vs 18:49:15Z) so run 2 provably
regenerated it. **Research §12.1 CLOSED and its MEDIUM-confidence prediction REFUTED:** the
CREATE2-proxy hook deploy is recorded as a TOP-LEVEL `transactionType: "CREATE2"` attributed to the
hook with `contractName: null`, NOT as a `CALL` with the hook in `additionalContracts[]` (which is
`[]` on all six transactions). The manifest matches the 20-04 schema contract with ZERO deviation.
Territory clean: `Makefile foundry.toml remappings.txt foundry-scripts/ src/ test/` all byte-untouched.
Next action: `20-05` (reconciliation + literal purge), once 20-04 lands.

### 20-02 (superseded position, kept for the record)

**20-02 COMPLETE — the source-of-truth import has LANDED and the Plank closure is PROVEN.**
36 paths imported BY CHECKOUT from `origin/develop @ 9f5ccba`, `git diff` against the ref EMPTY, so
every artifact is byte-identical and none was re-typed. `src/lib/TickUtils.plk` removed as
superseded (git records R054 → `src/types/pricing/TickUtils.plk`). Provenance pinned as 36
mechanically generated sha256 digests in `IMPORT-PIN.md`; SC-1 is now the re-runnable
`offchain/rig/verify-import.sh`, which was FALSIFIED (a flipped digest and a deleted pin row each
exit 1) before being reported green. **Closure PROVEN COMPLETE by compilation, not inspection:**
all four deploy module roots build with the exact `plankOpts()` flag set and emit pure hex —
`VolOrderManagerMod`'s dispatch table contains `6398d950ec`, so the V2 selector is LIVE in
bytecode. **Zero closure gaps; the 36-path list is unchanged from task 1.** Delta measured and
attributed, never repaired: forge **139/5/144 → 85/27/112**, compile-plank **14ok/0 → 13ok/3**,
`forge build` still **exit 0** (so `forge script` and 20-03 are unaffected). Next action: execute
`20-03` (stand the rig up on anvil).

### 20-01 (superseded position, kept for the record)

**20-01 COMPLETE — the upstream gate is OPEN and the phase is UNBLOCKED.** PR #15
(`feat/plank` → `develop`) MERGED at 18:17 UTC; `offchain/rig/check-upstream.sh` was RUN (not just
written) and recorded **`origin/develop` = `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d`** to
`offchain/rig/import-ref.txt`. That sha — read from disk, never retyped — is the SC-1 acceptance
target every 20-02 import diffs against, superseding the roadmap's `feat/plank @ df7088f` wording
per the 20-CONTEXT locked decision. Research §1's CLOSED measurement (`1c41935`, PR #15 OPEN) is
EXPIRED. Preflight done: `npm ci --ignore-scripts` + the submodule sequence make **`forge build`
exit 0 on the PRE-import tree**, so any later build failure is the import's. Cold baselines
recorded in `FORGE-BASELINE.md`: **139 passed / 5 failed / 144 total (47 suites)** and
**`make compile-plank` 14 ok / 0 failed / 0 skipped**, every red named verbatim and 0 under
`test/pos_spec/`. Other tracks' territory byte-untouched (`src/ test/ Makefile foundry.toml
remappings.txt` all clean). Next action: execute `20-02` (the import itself).
Last activity: 2026-07-31 — 20-02 executed: 36 artifacts imported by checkout from 9f5ccba,
provenance pinned, SC-1 verifier falsified then green, closure proven by four plank builds, forge
delta measured and attributed to four named causes

## v4.0 Closing Position (record, plank workstream)

Phase: 19 — Differential, Mutation Battery & Consumer Fixture (MVER-01..04) — **COMPLETE**
Milestone: **v4.0 COMPLETE** — all five phases (16, 17, 18a, 18b, 19) and all 15 requirements (VORD-01..05, MCAL-01..06, MVER-01..04) done.
Plan: 19-01 COMPLETE (MVER-01), 19-02 COMPLETE (MVER-03), 19-03 COMPLETE (MVER-02 part A), 19-04 COMPLETE (MVER-02 part B — **MVER-02 fully satisfied**), 19-05 COMPLETE (MVER-04).
Status: 19-05 done — MVER-04 satisfied. `test-vol-order-acceptance` (plus `test-vol-order-diff`, `test-vol-order-fixture`) exists and exits 0; the fold-in is an OBSERVATION (all three Phase 19 contract names seen in plain `make test`), not a prerequisite — `make test` is already a whole-tree `forge test`, and a prerequisite would double-run pos_spec and inflate the tally. **Counts re-MEASURED cold at execution time and every red ATTRIBUTED:** `make test` **102 passed / 18 failed / 120 total (44 suites)**, `make compile-plank` **11 ok / 2 failed** — 14 exposure `setUp()` reverts (the uncommitted `VegaIssuanceLib.plk` draft, `unresolved identifier 'VolOrder'`), 4 vol-type track under `test/types/pos_spec/`, **0 under `test/pos_spec/`**, 0 TickVolatility (did not surface). The stale `MEASURED AT 17-01` block (96 pass / 4 fail, 13 ok — both wrong) was REPLACED, not amended. The real gate is VERIFIED not inferred: `batchSelectorIsNowDispatched`, `mixedBatchFootprintAndContiguity`, `mixedBatchReturnIsByteExact` all CALLED green through `deployPlank`/FFI bytecode. `PLANK_SKIP` byte-identically empty; no exit ceremony invented. `src/` byte-untouched.
Status: 19-04 done — the consolidated MVER-02 battery is complete. **10 mutant applications across parts A and B, 10 observed REDs, SURVIVOR COUNT ZERO**, every mutated source restored sha256 byte-identical (`be196dcb…cc9b8787`, `5fe71f30…73fe8f35`). Guard 3's kill was taken from the REVERT assertion, never a state check, and its state-invisibility was RE-MEASURED (`VolOrderManagerBatchStateTest` green 2/0 under the mutant). M8's N=0 blindness re-measured GREEN; the element-base-shift (N=0-BLIND) vs head-drop (N=0-VISIBLE) mapping settled by measuring BOTH variants rather than inheriting 18b's. M9 killed by the raw-word canonicality assertion, with the `abi.decode` `EvmError: Revert` cascade recorded separately as the Haskell-consumer contract. **Four mutants have a SINGLE point of failure** (M2 outside pos_spec entirely; M4's 65536 test; M5/M6/M7's `VolOrderManagerBatchGuardTest`) — wave 1 structurally cannot cover the malformed-input or large-id surfaces.
Status: 19-01 done — the interleaved sequence differential is green and the module AGREES with an independent Solidity mock at tol 0 across mixed `(create_order | create_orders)` sequences. No disagreement observed. `src/` byte-untouched (both sha256 pins match the 18b baseline).
Status: 19-02 done — MVER-03 satisfied. The consumer golden fixture is committed with bytes produced by `cast abi-encode` (alloy), an encoder OUTSIDE this repo; the module's returndata matches it byte-for-byte across 5 cases including N=0, INDEPENDENTLY CONFIRMING 18b's 64+64N layout from a third encoder. All four interface selectors recomputed with `cast sig` and matching, plus a completeness gate that reddens on an unpinned fifth. **The cross-language gap is NOT closed:** alloy proves STANDARD-ABI conformance only; peer `mv15a18k`'s Haskell decoder remains unexercised and is marked per-case in the fixture.
Last activity: 2026-07-21 — 19-05 executed: three dedicated make targets (acceptance target exits 0); the stale `MEASURED AT 17-01` block replaced with cold-measured counts, every red attributed to a named cause; the CALLED-green batch dispatch verified by three named tests; `PLANK_SKIP` confirmed empty and the roadmap's stale exit wording corrected. `src/` byte-untouched.

Progress (v4.0): [██████████] 100% — 5/5 phases (16, 17, 18a, 18b, 19), 9 plans complete. **MILESTONE COMPLETE.**

## Performance Metrics

**Velocity:**
- Total plans completed (v4.0): 9
- Average duration: 29 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 16 — Type Packing & Validation | 1 | 118 min | 118 min |
| 17 — Interface & Single-Call Module | 1 | 11 min | 11 min |
| 18a — Batch Input & State Effects | 1 | 21 min | 21 min |
| 18b — Typed Return Encoding | 1 | 27 min | 27 min |

*Updated after each plan completion*
| Phase 19 P01 | 6 | 3 tasks | 3 files |
| Phase 19 P02 | 33 | 3 tasks | 3 files |
| Phase 19 P03 | 24 | 3 tasks | 1 files |
| Phase 19 P04 | 21 | 2 tasks | 1 files |
| Phase 19 P05 | 5 | 3 tasks | 2 files |
| Phase 20 P01 | 4 | 3 tasks | 3 files |
| Phase 20 P02 | 13 | 3 tasks | 40 files |
| Phase 20 P03 | 12 | 3 tasks | 4 files |
| Phase 20 P04 | 14 | 2 tasks | 4 files |
| Phase 20 P05 | 22 | 3 tasks | 11 files |
| Phase 21 P02 | 6 | 2 tasks | 3 files |
| Phase 21 P01 | 11 | 3 tasks | 6 files |
| Phase 21 P03 | 15 | 3 tasks | 4 files |
| Phase 21 P04 | 15 | 2 tasks | 5 files |
| Phase 21 P05 | 19min | 3 tasks | 6 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v4.0:

- [18b-01 MEASURED, supersedes 18a's number]: N=128 batch gas is now **execGas 3,231,765 + intrinsic 21,000 + EIP-2028 calldata 23,000 = 3,275,765 TOTAL**, a **+28,313 (+0.87%)** move from 18a's 3,247,452. The encoder adds 2 mstores per element plus memory expansion for the 8256-byte buffer; calldata gas is unchanged (the INPUT did not change). Still 3.05x under MCAL-01's 10,000,000 ceiling and well inside the plan's 3,400,000 stop-and-investigate band.
- [18b-01 MEASURED, the honest negatives — record these rather than the kill count alone]: (a) the **element-base-shift mutant (`base = 32 + 64*i`) is BLIND at N=0** — `test__unit__emptyReturnIsExactlySixtyFourBytes` stayed GREEN under it, because with no elements there is nothing to misplace and the total is 64 bytes either way. Killable only at N >= 1. (b) The **stride mutant (`64 + 32*i`) is blind at N <= 1** — OBSERVED directly: `test__unit__oneAndTwoElementReturnsAreByteExact` reddened at its **N=2** assertion while its N=1 assertion passed, since i=0 makes `64 + stride*i` independent of the stride. (c) The **dropped-outer-offset-word mutant IS killable at N=0** (32 bytes vs 64) — it and the base-shift mutant are COMPLEMENTARY, which is why both are run. A corpus that is N=0-only, or N<=1-only, would silently miss real encoder bugs.
- [18b-01 MEASURED, binds any future all-invalid corpus]: the `(false, id)` leak mutant is **NOT killable by an all-invalid batch on a fresh registry** — `test__unit__allInvalidBatchReturnsAllFalseZero` stayed GREEN under it, because `id` never leaves 0 there, so `(false, id)` IS `(false, 0)`. The SEEDED mixed corpus is the SOLE kill site. An all-invalid corpus alone would have recorded a fake pass.
- [18b-01 DECIDED, equivalence-checked and NOT counted as a kill]: the pure allocation-REORDERING mutant is **unconstructible**, and for a stronger reason than the bump-allocator argument the plan anticipated: moving the buffer allocation inside the loop makes the trailing `@evm_return(out, ...)` fail to compile with `error: unresolved identifier 'out'` (OBSERVED). Any reordering that keeps the return reachable requires `out` in the outer scope before the loop, so the before-the-loop ordering is enforced by SCOPING, not merely by convention. The under-allocated-buffer mutant carries the allocation-hazard evidence instead. **Kill count is 6, not 7.**
- [18b-01 CORROBORATED, HARD REQUIREMENT for the Haskell peer]: solc's `abi.decode` **REJECTS a non-canonical success word outright** — under the `success = 2` mutant the entire 18a suite reddens with `EvmError: Revert`, not with wrong values. A lenient Haskell decoder would accept a truthy 2. The two consumers would then disagree about the same bytes, which is exactly why the canonical-bool guarantee is a CONSUMER-SIDE CONTRACT and not a test detail.
- [18a-01 MEASURED, gas number SUPERSEDED at 18b-01 — see above]: N=128 batch gas is **execGas 3,203,452 + intrinsic 21,000 + EIP-2028 calldata 23,000 = 3,247,452 TOTAL**, against MCAL-01's 10,000,000 ceiling (3.08x headroom). This is 1.10x the research's UNVERIFIED ~2.94M estimate — same order of magnitude, so the loop does no unintended work. Pinned by `test__unit__maxBatchGasUnderBudget`, whose success/count/slot assertions all precede the threshold check so a passing `assertLe` cannot certify an early revert.
- [18a-01 DISCHARGED, was ACTION REQUIRED]: the M5 counter-hoist mutant is now a **REAL KILL**, exactly as 17-01 predicted. Observed RED: `id contiguity: third valid order at C+2: 0 != 2381976974094761317277030730967468670979` — slot C+2 holds ZERO because the skipped middle tuple consumed the id and pushed valid_B to C+3. The `orderCount` assertion also reddens (8 != 7) but is NOT discriminating; a count-only corpus would not have pinned where the order landed.
- [18a-01 FINDING, binds every future mutation gate]: **forge reports only the FIRST failing assertion per test**, so assertion ORDER is mutation-evidence design. The plan's original ordering had `orderCount` mask the contiguity red under M5, which would have been recorded as a count-only kill. Place the DISCRIMINATING assertion first. Fixed at `eac83f7`.
- [18a-01 EMPIRICAL, supersedes SC-6's original wording]: deleting the validation branch **cannot** produce a batch revert — `pack_vol_order` is pure shl/&/| and `@evm_sstore` cannot revert here, so an unvalidated tuple is STORED WRONG and COUNTED. Observed: `assertTrue(ok, "MCAL-04: no batch-revert observed")` stayed GREEN under M-VAL while three value assertions reddened. This also CORROBORATES the MCAL-04 structural enumeration: M-VAL drove arbitrary unvalidated tuples through the entire post-validation path and produced no revert, so no step's totality was contradicted. SC-6 was corrected at `56c4721` before execution; the correction is now backed by measurement.
- [18a-01 DECIDED, HARD REQUIREMENT for the Haskell peer]: guard 1 requires the **CANONICAL array offset `0x40` at byte 36**. The ABI spec permits a non-minimal offset, so a bespoke encoder that legally pads the head is REJECTED with an empty revert. Deliberate — it closes the PHANTOM-ORDER hole: the module reads elements at a fixed `100 + 32*i`, which is sound ONLY because the offset is pinned.
- [18a-01 DECIDED]: `width` is read UNMASKED. It is the TOP input field, so any bit >= 128 inflates it past `0xffffff` and validation rejects it — dirty-high-bit rejection with zero new arithmetic. Masking to `& 0xFFFFFF` would map two distinct calldata words onto one stored order, a malleability seam for the Phase 19 differential.
- [18a-01 DECIDED]: MAX_BATCH (128) is checked FIRST, before the three calldata guards, because Plank's `*` and `+` are CHECKED — an adversarial `count` near 2^256 would panic 0x11 inside `32 * count` before the size comparison ran, muddying MCAL-02's mutation evidence with panic data instead of an empty revert.
- [18b-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (UNCHANGED — the return type adds no entrypoint); `make test` **120 pass / 4 pre-existing fails** (was 112 / 4; +8 = the new `VolOrderManagerReturnEncodingTest`). The 4 reds are the vol-type track's `src/types/pos_spec/` harness failures, unchanged and not ours.
- [18a-01 baselines, count SUPERSEDED at 18b-01]: `make compile-plank` 13 ok / 0 failed / 0 skipped (UNCHANGED — the batch adds no new entrypoint); `make test` **112 pass / 4 pre-existing fails** (was 99 / 4).
- [17-01 MEASURED, binds 18a/19]: `v3::storage::array_slot` uses Plank's CHECKED `+`, so `keccak(base) + id` PANICS (0x11) rather than wrapping. Addressable ids cap at `2^256-1 - keccak(SLOT_ORDERS_BASE)` (~6.5e74). VORD-05's "no revert for a nonexistent id" therefore holds for every REACHABLE id (counter-assigned, +1/tx), which is the property it exists to establish. NOT worked around: `array_slot` is another track's file and masking the id module-side is exactly the ring-mask corruption M1 forbids. Boundary pinned as a VALUE instead.
- [17-01 DECIDED, ACTION REQUIRED IN 18a]: the "counter store hoisted above validation" mutant (M5) is an EQUIVALENCE-CHECKED NON-KILL in the strict path — `validate_order_strict` reverts, and a revert rolls back the prior SSTORE, so the hoist is unobservable. It becomes NON-equivalent in 18a, where the batch SKIPS instead of reverting: a hoisted store would advance the id on a skipped tuple. **18a MUST re-run this mutant and expect a RED.**
- [17-01 DECIDED]: both entrypoint selectors pinned in `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — `create_order(uint88,uint24,uint16)`=0x6501fe94 (dispatched) and `create_orders(uint256,uint256[])`=0x81357911 (DECLARED, falls through to `revert_empty()` until 18a). This is what breaks the 17<->18a circular dependency. `test__unit__batchSelectorNotYetDispatched` locks the current fall-through and must be updated when 18a dispatches it.
- [17-01 EVIDENCE]: the id-65536 test is the SOLE kill site for the ring-mask mutant — every other test stayed GREEN under it, because `& 0xFFFF` is a no-op at ids 1 and 2. Small-id tests alone were provably insufficient; this is measured, not argued.
- [17-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (was 12); `make test` 99 pass / 4 pre-existing fails (was 87 / 4), MODAL — see the nondeterminism blocker below. `PLANK_SKIP` stays EMPTY (MVER-04 corrected at af488a0: a module that compiles never enters the rescue queue).
- [16-01 DECIDED, binds 17/18a]: `validate_order` is a bool-returning CORE with `validate_order_strict` as a thin reverting wrapper. Phase 17 calls the wrapper, Phase 18a calls the core — MCAL-04's "same validation both paths" is true by construction, not by assertion. Do not collapse them.
- [16-01 DECIDED]: `TICK_SPACING = 20` pinned inside `build_vol_order` (one place). `vol_range_width_is_complete` ANDs `tickSpacing > 0`, so a zeroed field makes the composed validator IDENTICALLY FALSE — under which an all-reject validator passes a naive fuzz trivially. Mutant M5 proves this is observable. All order construction in 17/18a MUST go through `build_vol_order`.
- [16-01 MEASURED]: stored word is the FULL 152-bit `(width << 128) | (20 << 104) | (strike << 16) | skew`. NOTE this SUPERSEDES the earlier v4.0 roadmap-time assumption of a 128-bit `skew|strike|width` subset with tickSpacing deferred, and supersedes the "REDUCED width check (no tickSpacing operand)" note below — the full `vol_range_width_is_complete` is reused verbatim, tickSpacing included.
- [16-01 MEASURED]: accept sets, verified against the real predicates — skew [1, 65534] (1 and 65534 ACCEPTED, do NOT revert), width [1, 0xffffff], strike [1, 2^88-1]. The requirement's earlier "both endpoints revert" wording was wrong.
- [16-01 baselines]: `make compile-plank` 12 ok / 0 failed / 0 skipped (was 11); `make test` 87 pass / 4 pre-existing pos_spec fails (was 74 / 4).
- [16-01 pattern]: when a roadmap-named mutation site lives in another track's file, apply the identical semantic flip at OUR call site by inlining the flipped predicate, and record the substitution rationale in-file. Used for M3 (skew comparison, home is SpreadTickAssimetry.plk:12).
- [v4.0 roadmap]: 4 phases from the research SUMMARY skeleton; VORD-04 mapped to Phase 17 ALONE (Phase 16 delivers the pack/unpack layout its store consumes, but the requirement is mapped once).
- [v4.0 constraint]: runtime `while` only — `inline while` (comptime unroll) is parsed but compiler-rejected in v0.1.1; the batch loop is a plain bounded `while i < count`, not unrolled, not recursive.
- [v4.0 constraint]: best-effort containment is a pure-validation pre-check (branch-only, no self-call), NOT a self-`@evm_call` boundary — `create_order` has no revert-prone dependency call.
- [v4.0 constraint]: `array_slot(base,id) = keccak256(base)+id` reused verbatim from `v3::storage`, WITHOUT the RealizedVolatility ring's 16-bit wraparound mask (load-bearing for a ring, corruption-causing for a monotonic-id registry). Zero arithmetic in the module.
- [v4.0 constraint]: two peer-dependent placeholders (`MAX_BATCH` value; typed `(bool,uint256)[]` return shape) — NAMED placeholders with test structure written against them; never guessed, never blockers. Peer = rpc_api track `mv15a18k` (PR #9).
- [v4.0 constraint — **SUPERSEDED at 16-01, do not use**]: ~~stored word is the 128-bit create_order-native subset (`skew|strike|width` at offsets 0/16/104, bits 128–151 zeroed, `tickSpacing` deferred with pricing); width validated by the REDUCED check `width in (0,0xffffff]` (no `tickSpacing` operand).~~ Phase 16 measured the real layout: the FULL 152-bit word with `tickSpacing = 20` live in bits 104..127, and the FULL `vol_range_width_is_complete` (tickSpacing conjuncts included) reused verbatim. See the 16-01 MEASURED entries above.
- [carried, v3.0]: `make compile-plank` passing is NOT evidence — Plank does not type-check code unreachable from `run{}`. Proof = CALLING the module through FFI-deployed bytecode.
- [carried, v3.0]: `deployPlank` recompiles the `.plk` fresh on every test run via FFI — a mutation battery does NOT need `make compile-plank` between mutants; the mutant reaches the deployed bytecode as long as tests use `deployPlank` (re-check if any test ever deploys from a prebuilt artifact).
- [carried, v3.0]: observed-RED discipline — mutant applied → cache/fuzz cleared → verbatim RED recorded → restored sha256-identical → green; equivalence-masked mutants documented, never counted. Keep a NON-FUZZ unit anchor alongside each fuzz (cache-independent by construction). Reference mock must NEVER echo Plank's own output (vacuous differential).
- [carried, v3.0]: one shared decoder, not a fourth copy — `test/.../TimepointDecoder.sol` precedent; v4.0 promotes a single `VolOrderDecoder` and reuses it.
- [Phase 19]: [19-01 MEASURED] The module and the independent mock AGREE at tol 0 across interleaved (create_order | create_orders) sequences — orderCount, every stored word, and return bytes — over a seeded 8-step anchor ending at id 12 and a 256-run cold-cache fuzz. Step 3 (strict path resuming on a BATCH-advanced counter) is the property 18a/18b structurally could not test; VolOrderManagerMod satisfies it. No disagreement observed.
- [Phase 19]: [19-01 FINDING, binds every seeded differential] vm.store seeding moves the COUNTER, not the orders: ids in [1, seedBase] are legitimately EMPTY on both sides. The plan's after-every-write helper asserted 'pw != 0' and 'tickSpacing == 20' over all of [1, pc] and would have failed on every seeded test. Agreement is asserted over the full range; live-order SHAPE only for id > seedBase, with assertEq(pw, 0) below it (which also catches phantom-order seeding bugs).
- [Phase 19]: [19-01 BLOCKING, affects any test-side NatSpec] solc parses a leading at-sign + word in NatSpec as a doc tag: the field-at-bit layout shorthand triggers 'Error (6546): Documentation tag @128 not valid for contracts' and the file will not compile. Use prose in NatSpec; the shorthand survives in string literals, which is where failure messages need it.
- [Phase 19]: [19-02 CONFIRMED, the milestone's strongest encoder evidence] cast abi-encode (alloy) INDEPENDENTLY confirms 18b's pinned return layout from a THIRD encoder outside this repo: offset 0x20 at byte 0, length in ELEMENTS, static tuples at stride 0x40, total exactly 64+64N, and the N=0 case at exactly 64 bytes. Two independent encoders (solc at 18b, alloy here) now agree with the hand-rolled Plank encoder.
- [Phase 19]: [19-02 SCOPE, must NOT be blurred in the exit record] alloy proves the return bytes are STANDARD-ABI CONFORMANT. It does NOT exercise the Haskell consumer's decoder. The cross-language gap with peer mv15a18k remains OPEN and is kept visible in four places: the fixture's _scope_limit and _peer_status fields, 5 NOT-PEER-VERIFIED placeholders, and the dedicated test__unit__peerHaskellBytesAreStillAnOpenGap.
- [Phase 19]: [19-02 MEASURED, honest negative] test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes is NOT an anti-inaction gate — it stayed GREEN under a 5-to-4 fixture case-count drop because it reads expected[0] only. The count gate lives solely in the differential and the peer-gap tests. A refactor keeping only the N=0 test would silently lose falsifiability.
- [Phase 19]: [19-02 FINDING, binds remaining Phase 19 plans] the acceptance criterion 'git diff --stat src/ produces NO output' is UNSATISFIABLE at execution time — the pre-existing uncommitted src/lib/exposure/VegaIssuanceLib.plk draft (which CONTEXT itself defers) always shows. Fifth instance of the self-contradicting-criterion pattern. Scope the criterion to src/**/pos_spec instead; the real property (pos_spec byte-untouched, module sha256 be196dcb...cc9b8787) was verified directly.
- [Phase 19]: M8's N=0 blindness belongs to the ELEMENT-BASE SHIFT, not the head-drop — established by measuring BOTH variants
- [Phase 19]: M9 is also N=0-blind and all-invalid-blind; its kill needs an N>=1 corpus containing a VALID tuple
- [Phase 19]: The three calldata guards have a SINGLE point of failure in VolOrderManagerBatchGuardTest; wave 1 structurally cannot cover them
- [Phase 19]: [19-05 MEASURED, replaces the stale 17-01 record] `make test` = 102 passed / 18 failed / 120 total (44 suites); `make compile-plank` = 11 ok / 2 failed. Every red ATTRIBUTED: 14 exposure setUp() reverts (the uncommitted src/lib/exposure/VegaIssuanceLib.plk draft, `unresolved identifier 'VolOrder'`, propagating through deployPlank/FFI), 4 vol-type track under test/types/pos_spec/, **0 under test/pos_spec/**, 0 TickVolatility. The 13->11 entrypoint drop and 4->18 fail rise vs 18b are the exposure draft landing in between, NOT a Phase 19 regression: Phase 19 moved the pass count 95->102 and added zero failures.
- [Phase 19]: [19-05 FINDING, will fire on every future run] the acceptance criterion `grep 'FAIL' <output> | grep -c 'pos_spec'` == 0 is a FALSE POSITIVE — it matches the `--dep pos_spec=src/types/pos_spec` flag echoed inside `[FAIL: vm.ffi: ffi command [...]]` lines from the EXPOSURE suites, not any failing test. It measured 28 while the real count of reds under test/pos_spec/ was ZERO. Scope such gates to `test/pos_spec/`, and note that test/types/pos_spec/ is the vol-type TYPE track — a different owner.
- [Phase 19]: [19-05 VERIFIED, the real MVER-04 gate] the BATCH dispatch is CALLED green through FFI-deployed bytecode, not inferred from compile-green: batchSelectorIsNowDispatched (selector 0x81357911 reaches a dispatch branch rather than revert_empty), mixedBatchFootprintAndContiguity (the branch does real work — state effects at raw vm.load addresses from a seeded counter), mixedBatchReturnIsByteExact (the return half). All reach the module via deployPlank -> plank build over FFI AT TEST TIME.
- [Phase 19]: [19-05 CORRECTED, fourth stale-criterion fix in this milestone] roadmap SC-4, the Phase 19 Goal line and the one-line entry all asserted a `PLANK_SKIP` exit that does not exist. PLANK_SKIP is the rescue queue for entrypoints that do NOT compile; a module dispatching a subset of its declared selectors compiles fine, so VolOrderManagerMod never met the entry condition. Queue verified byte-identically empty. Like the previous three, resolved by fixing the DOCUMENT, never the code.
- [Phase 20]: [20-01 MEASURED] Upstream gate OPEN — PR #15 (feat/plank->develop) MERGED; origin/develop pinned at 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d in offchain/rig/import-ref.txt. This SUPERSEDES research §1's CLOSED measurement (origin/develop = 1c41935, PR #15 OPEN at 14:20 UTC). The gate is a re-runnable command whose sharpest discriminator is a grep for the V2 selector 0x98d950ec, not path existence — a path check cannot tell a merged V2 interface from the stale v1 file.
- [Phase 20]: [20-01 MEASURED, binds 20-02's delta] Cold PRE-IMPORT baselines on feat/rpc-api: forge test --via-ir --fuzz-seed 4880 = 139 passed / 5 failed / 144 total (47 suites); make compile-plank = 14 ok / 0 failed / 0 skipped. 19-05's 102/18/120 + 11ok/2fail were NOT carried forward — the gap is the exposure draft: src/lib/exposure/VegaIssuanceLib.plk is now TRACKED and COMPILES here, so the 14 VegaAccount*/VegaIssuance* setUp() reverts and 2 compile failures are gone. 4 of the 5 reds are the known vol-type track failures; the 5th (VolOrderManagerFuzzTest test__fuzz__logCreateOrder) is NEW to this branch record and is pre-import, so 20-02 must not mistake it for import damage. 0 reds under test/pos_spec/.
- [Phase 20]: [20-01 VERIFIED] forge build exits 0 on the PRE-import tree after npm ci --ignore-scripts (172 pkgs) + the develop-gate.yml submodule sequence with the submodule.lib/panoptic-helper.update=none recursion guard (guard OBSERVED firing: 'Skipping submodule'). Any post-import build failure is therefore unambiguously attributable to the import. No tracked file moved: git status --porcelain on src/ test/ Makefile foundry.toml remappings.txt is EMPTY.
- [Phase Phase 20]: [20-02 VERIFIED] The import LANDED byte-identical: 36 paths checked out from origin/develop @ 9f5ccba, git diff against the ref EMPTY, none re-typed. src/lib/TickUtils.plk removed as superseded (R054 -> src/types/pricing/TickUtils.plk; its only 3 importers were all in the list and switch to types::pricing::TickUtils on the ref). The V2 discriminators are LIVE not merely present: SELECTOR_CREATE_ORDER = 0x98d950ec is the sole live const and 0x6501fe94 survives only as a RETIRED-NEVER-LIVE comment.
- [Phase Phase 20]: [20-02 PROVEN] The Plank closure is COMPLETE, established by compilation before anvil was ever started: all four deploy module roots build with the exact plankOpts() flag set (7 deps, verified against the IMPORTED PlankDeployBase.s.sol, not just research) and emit pure hex bytecode. VolOrderManagerMod's bytecode contains 6398d950ec -- the V2 selector is in the compiled DISPATCH TABLE, strictly stronger than a constant in a source file. ZERO closure gaps: no path was added, the 36-path list is unchanged from task 1. A 20-03 anvil failure therefore cannot be a closure gap.
- [Phase Phase 20]: [20-02 MEASURED, binds the Solidity-testing session] Post-import delta, ATTRIBUTED not repaired: forge test --via-ir --fuzz-seed 4880 = 139/5/144 -> 85 passed / 27 failed / 112 total; make compile-plank = 14ok/0 -> 13 ok / 3 failed / 16 entrypoints. forge build STILL exit 0, confirming solc never sees .plk, so all 27 reds are runtime/FFI and forge script (20-03) is unaffected. The total FELL 32 because six suites now fail in setUp(), which forge reports as ONE failure while the rest never run. Four named causes: C1 V2 arity create_order(uint88,uint24,uint16,uint96)/0x98d950ec with the v1 3-arg RETIRED (20 tests); C2 two harnesses importing the removed lib::TickUtils; C3 per-test --dep sets lacking types=src/types; C4 harness call sites at v1 arity. By transition: 1 carried pre-existing, 2 transformed, 24 genuinely new.
- [Phase Phase 20]: [20-02 FINDING] C3 is a DEPENDENCY-ROOT problem, not a content problem, and the proof is a divergence: VolRangeWidthHelper.plk compiles OK under make compile-plank (full dep set) while the SAME file fails under forge test's FFI (narrower per-test set). Re-running the failing command with --dep types=src/types added emits bytecode and exits 0 (MEASURED, no file edited). So C2/C3 are mechanical fixes for the Solidity-testing session, not a migration. Separately, test__unit__everyInterfaceSignatureStringIsPinned is a WORKING pin, not a bug -- it reddened because it DETECTED the source-of-truth change, exactly its job.
- [Phase Phase 20]: [20-02 PATTERN, falsify-before-trust] The SC-1 verifier was driven to FAIL on purpose before being reported green: a flipped pin digest and a deleted pin row each exit 1 with a named message, and both restorations were verified byte-identical. Faults were injected into IMPORT-PIN.md (this workstream's own file), never a plank-owned one. This answers the repo's four recorded instances of criteria that passed vacuously. Also carried forward for 20-04: IMarketStateSocket.plk was imported for set-completeness and IS the broken stub (seven const NAME = lines with no values, no terminators) -- the pin parser must skip valueless consts DELIBERATELY, with the skip asserted in a test.
- [Phase 20]: [20-03 RESOLVED, closes research §12.1 and REFUTES its prediction] Foundry records DeployDynamicFeeHook's raw .call to the CREATE2 proxy as a TOP-LEVEL transactionType CREATE2 attributed to the hook (contractAddress = the mined hook, contractName null), NOT as a CALL to 0x4e59b448 with the hook in additionalContracts[] -- additionalContracts is [] on all six transactions, in both runs. The plan's PRIMARY extractor branch never fires; the FALLBACK is the real path. contractName is null for the same reason it is null on plankDeployFFI modules (Plank initcode solc never saw), so the Plank hook is keyed on transactionType while PriceSetterHook (new X{salt:...}) carries a contractName and is keyed by name. The hook address also appears a second time as a CALL (initializeHook), so keying on CREATE2 is correct by construction, not by ordering luck.
- [Phase 20]: [20-03 MEASURED, SC-5] Two from-scratch deploy-rig.sh runs produce a byte-identical manifest: jq -S 'del(.generatedAt)' diff EMPTY, both normalised files sha256 197acd740685fb0860ec1f8227d95afc541985fe6d081b3fade6712f5888f354, with generatedAt DIFFERING (18:46:13Z vs 18:49:15Z) so run 2 provably regenerated the file. Two determinism results that were NOT guaranteed: (a) BOTH CREATE2-mined addresses reproduce, which for the Plank DynamicFeeHook means plank build emitted byte-identical initcode -- stronger than 20-02's 'compiles and emits hex'; (b) the seeded packed timepoint is identical across runs (1766847064...619776), confirming it derives from the fixed INIT_TS literal and not the wall clock. A date +%s INIT_TS would still have PASSED SC-5 (the seed is not a manifest field) while silently making the rig's STATE irreproducible.
- [Phase 20]: [20-03 VERIFIED, SC-2 falsified] verify-rig.sh exits 0 with '7 contracts live, RealizedVolatilityMod seeded' and contains ZERO address literals (every target read from the manifest via jq -r). All six injected faults exit 1 with named messages, run against COPIES via a RIG_MANIFEST override with the real manifest's sha256 confirmed unchanged after. TWO faults are load-bearing beyond box-ticking: pointing RealizedVolatilityMod at the LIVE 17151-byte PoolManager passes probe 1 and is caught ONLY by probe 3 (so probe 3 does not ride on the bytecode check), and swapping contracts.PoolManager for PriceSetterPoolManager proves probe 5 discriminates between two REAL contracts, not merely live-vs-empty. A live-vs-empty-only falsification would have left both unproven.
- [Phase 20]: [20-03 FINDING, one research-table label is stale] Research §3.2 lists DeployDynamicFeeMod printing 'owner (TOFU)  : <address>'. The IMPORTED file prints 'owner (TOFU)  : the deployer, captured in-broadcast' -- a sentence, not an address -- so there is no console address to cross-check and none is attempted. TOFU ownership is instead PROVEN on chain by verify-rig.sh probe 4 (owner() == manifest accounts.deployer), which is strictly stronger than matching a printed string. Every other console label matched the imported source exactly. Separately: poolId is the ONLY console-primary field with no independent source (it is not an address in the broadcast record); currency0/currency1 were upgraded to a SET cross-check against the two MinimalToken CREATEs.
- [Phase 20]: [20-04 MEASURED] Every pin is GENERATED, never typed: 30 selectors + 5 topic0s computed by cast sig/cast keccak from signature strings parsed out of the imported .plk files, each then ASSERTED equal to that file's own declared const. All 35 agreed -- zero disagreements, so no interface constant is wrong and the parser truncated nothing. generate-pins.sh contains ZERO hex literals; rig-pins.json names the signature and the source path for every pin. The truncation hazard was MEASURED not argued: a naive single-line parse of the wrapped TimepointWritten signature yields 0xc0055983... , a valid-looking WRONG 32-byte hash. Only the in-file cross-check separates it from the correct 0x44d3c76a... value.
- [Phase 20]: [20-04 FINDING, corrects research 5.3] The // signature:: convention is NOT used by all six interface files. DynamicFeeInterface.plk uses a THIRD shape -- bare // name(args) comments with no marker -- for all five of its selectors. A marker-only parser would have emitted 25 selectors instead of 30 and EXITED 0, silently hand-picking a subset. Fixed by anchoring the parser on the const DECLARATIONS and walking backward through the contiguous comment block (marker form takes precedence, bare form is the fallback); a const with a hex value and no derivable signature is a loud abort, so a fourth shape appearing later fails rather than shrinking the output.
- [Phase 20]: [20-04 PROVEN] Normaliser idempotency is established by CROSS-FILE AGREEMENT, not by assertion. TimepointWritten, WindowChanged, FeeConfigurationChanged and getAverageVolatility are each declared in two files in two DIFFERENT comment shapes -- decorated (indexed + parameter names, one of them wrapped across two lines) and already-canonical single-line. Both paths through the parser produced identical signature strings and identical computed values, and the generator ABORTS if any duplicate disagrees.
- [Phase 20]: [20-04 DECIDED, resolves a self-contradicting criterion -- the SIXTH in this repo] The plan required that deleting contracts.VolOrderManagerMod make the decode FAIL, while its own schema locks contracts as an OPEN map so a new deployment needs no Haskell change. A smaller map is still a valid map, so aeson structurally cannot fail. Resolved by KEEPING the map open (20-03's contract preserved, extra contracts accepted) and adding a required_contracts completeness check in load_rig_from that runs after decoding and names both the missing and the present contracts. The failure is raised by the completeness check, NOT by aeson -- do not blur this.
- [Phase 20]: [20-04 VERIFIED, closes a 20-05 question early] 20-03's rig-manifest.json already existed at 20-04 execution time and Rig.Manifest decoded the REAL file, not merely the fixture. It matches the wave-3 schema B contract with ZERO deviation -- every key, every nesting level, all hex lowercase, chainId/tickSpacing/initTs/initTick as JSON numbers. There is nothing for 20-05 task 1 to reconcile on the manifest shape. Also: the v1 E1 topic0 did NOT have to be omitted -- it is present VERBATIM and complete in the imported notes/DATA_CONTRACT.md:16, so it is parsed from there rather than expanded from memory, while the truncated .plk form is rejected by an explicit ellipsis guard.
- [Phase 20]: [20-05 MEASURED, the purge fixed a LIVE bug] Sample.hs's price_setter_hook literal 0x78f77B58... has ZERO bytecode on the deployed rig (cast code returns 0x) while the manifest's PriceSetterHook 0x683ee59f... has 2183 bytes. The driver's entire price-write path was aimed at an address with no contract at it. The other two literals were still correct by nonce accident (VolOrderManagerMod landed at the same address), which is the point: a literal is right only by accident and cannot announce when it stops being right. Six literals were purged, not the research inventory's four -- check-upstream.sh carried 0x98d950ec and 0x6501fe94 and is IN the decided *.hs/*.sh scope; both are now read from rig-pins.json with jq.
- [Phase 20]: [20-05 FINDING, the SEVENTH self-contradicting criterion] The plan's own prescribed Decode.hs comment ('The RETIRED v1 value 0xa8892769 lives in rig-pins.json') contains an 8-hex literal that its OWN purge criterion matches -- written verbatim, task 1 could never pass. Resolved by pointing the comment at the retired block without the hex. Separately, two acceptance criteria measure TEXT where they mean STRUCTURE (grep -c on 'account|order_manager|price_setter_hook' in Sample.hs and on 'Rig.Manifest' in the decode chain counted explanatory COMMENTS, not code); both were satisfied by rewording, at the cost of moving the removed-binding routing table into the summary.
- [Phase 20]: [20-05 DECIDED, a working tool would have broken silently] generate-pins.sh parsed retired.topic_order_created_stale out of offchain/lib/VolOrder/Decode.hs -- the very constant this plan deletes -- so the generator would have aborted with 'matched 0 values'. Re-pointed at src/modules/VolOrderManagerMod.plk, the superseded duplicate module carrying 'const TOPIC_ORDER_CREATED = 0xa8892769' verbatim: the file the Decode.hs constant was ORIGINALLY transcribed from and the origin of the rot (research 2.2). Better provenance, still never typed, another track's file READ only. Re-run produces rig-pins.json byte-identical. CAVEAT for Phase 21: the generator now depends on that superseded file existing; plank deleting it is a loud failure needing a new recorded home, not a silent drop.
- [Phase 20]: [20-05 VERIFIED, SC-4 is falsifiable and was OBSERVED red] cabal test = 44/44 (35 per-pin + 9 named). Every pin is recomputed from the signature PARSED OUT OF the .plk file its own source field names, by a SECOND independent parser anchored differently from generate-pins.sh's (comment-block forward scan vs const-declaration backward walk). A one-character pin corruption (0x98d950ec -> 0x98d950ed) reddens exactly sc4_pin_selector_create_order and sc4_cast_agreement at 42/44 exit 1, with the recomputed value CORRECT and the pin wrong, both Haskell keccak256 and cast saying so independently; git checkout restores 44/44. The suite also caught a defect in ITSELF first: cast's trailing newline made two identical-looking hex strings compare unequal.
- [Phase 20]: [20-05 FINDING, the clean-machine trap the plan's template would have shipped] The README's submodule step needs 'git -c submodule.lib/panoptic-helper.update=none'. The plain recursive command exits 0 in this checkout ONLY because the skip is recorded in lib/panoptic-v2-core/.git/config, a machine-local artifact; upstream's committed .gitmodules points lib/panoptic-helper at an unreachable repo and this repo has no overriding stanza. A clean machine following the plain form fails at step 2. Separately documented: cabal run completes and reports a receipt but the order REVERTS -- Encoding.hs still builds the retired 3-arg create_order against a V2 module dispatching 0x98d950ec (20-02's cause C1, pre-existing, Phase 21's re-pin), recorded in the README so a reader does not read it as a rig failure.
- [Phase 21]: [21-02 MEASURED, stronger than planned] All THREE golden-comparable cases match the v4.0 alloy fixture BYTE-FOR-BYTE, not just N0_empty. The plan expected N1_success/N2_success_then_fail to differ in the order-id words because the golden was taken against a fresh registry. They do not, and structurally cannot from this script: create_orders RETURNS its array, so the capture is four eth_calls, and an eth_call does not mutate state -- every case executes against orderCount = 0, exactly the golden's condition. The differs_only_in_order_ids comparator was built and ships (it becomes load-bearing against a rig that has taken real transactions) but is recorded false on all three. COROLLARY for 21-05: the captured order ids are HYPOTHETICAL, ids the calls WOULD have assigned; an assertion hardcoding id == 1 is really asserting the rig is fresh.
- [Phase 21]: [21-02 FINDING, binds 21-05] generatedAt is NOT a regeneration witness for capture-batch-return.sh. The Phase-20 idempotence recipe (two runs, generatedAt must DIFFER) was designed around deploy-rig.sh, which takes tens of seconds. The capture takes 294 ms against a 1-second timestamp resolution, so two back-to-back runs SHARE a generatedAt -- MEASURED, both 18:30:37Z -- and the check would have passed on a stale artifact. Regeneration was re-proven by deleting the artifact before each run and gating the second on the wall-clock second rolling over (bounded until-loop, no fixed sleep): runs A/B at 18:31:02Z and 18:31:03Z, normalised diff EMPTY, same sha256 786c9506...824c0cd7 as the first pair. Five runs, one normalised sha256. Use blockNumber/manager as the discriminating provenance fields; generatedAt is a label. Caveat written into offchain/rig/README.md.
- [Phase 21]: [21-02 CONFIRMED, hazard F1 -- REPORTED to the plank track, never edited] src/modules/pos_spec/VolOrderManagerMod.plk lines 177-188 carry a V1 comment block ('width@104..127 | bits >=128 MUST BE ZERO', 'width IS DELIBERATELY UNMASKED. It is the TOP field') that its OWN file contradicts at lines 221-235, where the executing V2 code masks width to 0xFFFFFF at 104 and reads targetVega UNMASKED from bit 128. The stale block is dangerous because it is plausible and co-located: a word built from it carries targetVega = 0, the tuple is rejected, and the batch SKIPS rather than reverting, so a capture would degenerate into a legitimate-looking all-(false,0) artifact proving nothing. The warning is recorded in offchain/rig/capture-batch-return.sh immediately above input_word(), naming the line range and the failure mode.
- [Phase 21]: [21-02 SCOPE, binds 21-03] The capture emitted NO E1 VolOrderCreated v2 log and could not: these are eth_calls, which produce no logs. The v2 E1 log remains UNOBSERVED and 21-03's decode shape is still derived from emitter source alone. Closing that gap needs a real eth_sendTransaction against create_orders -- cheap now that the rig is standing and the V2 input word (skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223) is proven live -- but it is 21-03's work.
- [Phase 21]: [21-02 DECIDED, RPIN-05 deliberately left PENDING] RPIN-05 is claimed by BOTH 21-02 and 21-05, and its text is 'decode_create_orders_result is verified byte-unchanged against the V2 module's (bool,uint256)[] return'. 21-02 delivered the LIVE half -- the observed bytes with provenance -- but produced no Haskell decoder verification at all, and was explicitly scoped OUT of adding assertions to offchain/test/Main.hs (21-05 owns the suite side). Checking the box now would record a decoder verification that does not exist. Left unchecked in REQUIREMENTS.md; 21-05 closes it once decode_create_orders_result is asserted against offchain/rig/batch-return-capture.json.
- [Phase 21]: [21-01 MEASURED, invalidates a gate used in three tasks] `cabal build -j all` does NOT build the test suite -- it exited 0 with 0 warnings against a test suite carrying `Not in scope: record field 'target_vega'`. cabal only builds test components when tests are enabled. Every build/warning gate in this workstream must be `cabal build --enable-tests -j all`; the plain form certifies lib+exe only and would report a non-compiling suite as green.
- [Phase 21]: [21-01 MEASURED, honest negative that limits what RPIN-03 may claim] Under the `shiftR 152`->`shiftR 144` storage mutant, `rpin03_input_word_is_not_storage_word` stayed GREEN. Its final assertion is an INEQUALITY (`unpack_vol_order_storage input /= base`), and a WRONG offset satisfies an inequality as well as the right one. That check discriminates CONFLATION of the two layouts, never CORRECTNESS of either -- only `rpin03_storage_round_trip` establishes the 152 offset. Do not cite the former as evidence for the latter.
- [Phase 21]: [21-01 MEASURED, discrimination is specific] Under the `shiftL 128`->`shiftL 120` input-word mutant, `rpin01_encoder_argument_order` and `rpin02_field_rejections` correctly stayed GREEN: the calldata path goes through `cast calldata` and never touches `pack_vol_order_input` (genuinely independent encoders), and rejection checks assert BOUNDS not POSITIONS -- a misplaced field is still in range. Neither family covers the other; both are load-bearing.
- [Phase 21]: [21-01 FINDING, the EIGHTH self-contradicting criterion in this repo] The plan prescribed a comment stating the V1 3-arg path is deleted, while its own verification step 6 requires `grep -rn 'uint88,uint24,uint16)' offchain/` to produce NO output -- the natural comment matches that grep. Resolved by rewording the comment to omit the signature string (and to say why), never by relaxing the criterion. Same class as 20-05's prescribed Decode.hs comment.
- [Phase 21]: [21-01 FINDING, F1 CONFIRMED against the source] `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` still reads 'bits >=128 MUST BE ZERO' and 'width IS DELIBERATELY UNMASKED. It is the TOP field', both FALSE of that same file's V2 code at 229-235 (width is masked and interior; targetVega is the unmasked top field at 128). Plank track's file -- REPORTED, never edited. An implementer trusting it ships a V1 packer that passes every offchain test and is SILENTLY SKIPPED on the batch path as an ordinary `(false,0)`. The Haskell-side comment in Encoding.hs now names the block as untrustworthy.
- [Phase 21]: [21-01 FINDING, F2] The module pins TICK_SPACING = 20 into storage bits 104..127 while the rig's own deployed pool has tickSpacing = 10 (rig-manifest.json .pool.tickSpacing). REPORTED in Decode.hs and offchain/test/Main.hs; the test expectation is written against the MODULE CONSTANT so a change to it reddens rather than passing silently. Not resolved -- resolving it means editing another track's module.
- [Phase 21]: [21-01 DECIDED] `cabal run` was deliberately NOT executed: it writes live orders to the shared anvil rig that 21-02 was capturing batch-return data from in the same wave. The V2 fix is proven statically (encoder selector == module's dispatched selector, three ways); live confirmation belongs to a plan that owns the rig state.
- [Phase 21]: [21-03 MEASURED] rpin06's inequality assertions do NOT catch a decoder that destroys targetVega -- with the baseline round-trip assertion neutralised the check PASSES under the target_vega=0 mutant. The baseline is the sole discriminator; an inequality never establishes correctness of the thing it is unequal about.
- [Phase 21]: [21-03 FINDING] sc4_no_retired_value_is_live is defeated by ZERO-PADDING: it compares pin values as strings, so the left-padded 32-byte form of a retired 8-hex value stays GREEN while that value is live. Pre-existing (Phase 20's check); logged to deferred-items.md, fix = compare numerically.
- [Phase 21]: [21-03 OBSERVED] FIRST E1 VolOrderCreated v2 log ever seen on chain: 2 topics, 128 bytes/4 data words, topic0 == pin, orderId in topic 1 only, data = (12345,600,77,1e18). Captured non-destructively via evm_snapshot/evm_revert; rig restored to block 9, orderCount 0, SC-2 green.
- [Phase 21]: 21-04: the plan's predicted mutant discriminator was REFUTED by measurement -- a linear-uniform draw spans 9 distinct bit-lengths (62..70) over 256 fixed-seed draws and clears the >= 8 spread assertion; bottom-decade mass (77 vs 4 of 256) is the real shape discriminator and was added
- [Phase 21]: 21-04: draw_target_vega's zero-lower-bound rejection is INCIDENTAL (0 * Infinity = NaN in the log transform), not an explicit parameter guard -- a second VegaDraw constructor must supply its own validation
- [Phase 21]: [21-05] RPIN-05 closed: live captured bytes asserted byte-for-byte against the alloy golden inside a suite PROVEN chain-independent with anvil stopped (65/65, pgrep anvil empty)
- [Phase 21]: [21-05 REFUTED] The plan's instruction to record follow-up #5 as ADDRESSED is FALSE — verify_mined_order is unchanged and still discards tickSpacing and bits >= 248 before comparing. Recorded PARTIALLY ADDRESSED.
- [Phase 21]: [21-05 REFUTED] blockNumber is NOT a provenance discriminator — three from-scratch deploys of the same rig gave heights 9, 11, 10. Freshness asserts chainId + manager only.
- [Phase 21]: [21-05 MEASURED] decode_create_orders_result never reads the outer offset word (follow-up #2 demonstrated); and the freshness check cannot see a module change behind an unchanged CREATE address (F4).
- [Phase 21]: [21-05 CLOSED] sc4_no_retired_value_is_live now compares NUMERICALLY — under 21-03's identical injection the suite reports 4 failures where 21-03 recorded 3.

### Pending Todos

**Next action: tag `v4.0` and send the peer hand-off.** Phase 19 is COMPLETE and the milestone is closed. Phases 16 (VORD-02), 17 (VORD-01/03/04/05), 18a (MCAL-01/02/03/04/06) and 18b (MCAL-05 + MCAL-06's carried clause) are DONE — the multicall is feature-complete. Phase 19 (MVER-01..04) is a **coordination checkpoint, NOT a research gap**: proceed on the placeholder + a `NOT-PEER-VERIFIED` stand-in fixture if the peer has not answered. The 18b research question is CLOSED — `std::abi` provably cannot encode an array (`abi_encoded_size` has no array case and Plank has no array type), so the head/tail was hand-rolled and proven byte-exact against solc.

**Peer hand-off ready for `mv15a18k` — now TWO documents.** 18a-01-SUMMARY.md CARRY-FORWARD section 2 has the input-word layout, the canonical-offset hard requirement and skip-vs-revert semantics. **18b-01-SUMMARY.md adds the RETURN side**: the exact `64 + 64N` byte layout, the N=0-returns-64-bytes clause (the one most likely to break a Haskell decoder, and invisible on-chain), and the canonical-bool divergence (solc REJECTS a non-canonical success word; a lenient Haskell decoder may accept it). Send both.

### MILESTONE v4.0 EXIT RECORD — OPEN ITEMS (none blocking)

- **F1 — the strike bound is UNPROVEN at the `create_order` entrypoint.** Mutant M2 dies ONLY in the Phase-16 pure-lib harness. No pos_spec test can express `strike >= 2^88` (the whole corpus is uint88-bounded), and on the BATCH path M2 is genuinely EQUIVALENT because `create_orders` masks the strike to 88 bits BEFORE validation, making `<= MAX_STRIKE` dead code there. The STRICT path reads the strike unmasked, so it IS killable: one `create_order` call with `strike = (1 << 88) + 7` asserting a revert would close it. Reported, not fixed — Phase 19 builds nothing.
- **Four mutants have a SINGLE POINT OF FAILURE.** Survivor count is genuinely 0 of 10, but M2 (only outside `test/pos_spec/`), M4 (the 65536 test alone) and M5/M6/M7 (`VolOrderManagerBatchGuardTest` alone) each rest on one test. Wave 1 is a kill site on 5/10 (19-01) and 4/10 (19-02) — real strengthening — but structurally CANNOT cover these: a typed Solidity mock and a golden-bytes fixture cannot emit a non-canonical offset or a truncated payload, and neither reaches id 65536. Delete any one of those tests and a real mutant survives with 39/40 still green.
- **[19-02 honest negative] `test__unit__externalEncoderConfirmsTheEmptyEncodingIsSixtyFourBytes` is NOT an anti-inaction gate** — it reads `expected[0]` only and stayed GREEN under a 5-to-4 fixture case-count drop. The count gate lives solely in the differential and the peer-gap tests.
- **Cross-language gap still OPEN.** alloy proves STANDARD-ABI conformance; it does NOT exercise peer `mv15a18k`'s Haskell decoder. Two different claims — the exit record must not conflate them.

### Blockers/Concerns

- **[RESOLVED at `8b11d73`, verified again at 19-05] The `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` flag NO LONGER EXISTS.** The untracked sketch was deleted and the flag removed from all NINE Makefile recipes. Every prior phase's documented forge command is STALE on this point. Do NOT reintroduce it. Verified at 19-05: `grep -c -- '--skip' Makefile` = 0 and `grep -c 'PriceSetterHook' Makefile` = 0.
- **4 pre-existing pos_spec harness failures** (vol-type-system track) remain visible in `make test` — not v4.0 defects; the v4.0 suite must not filter them.
- **[17-01] The `make test` failure count is NOT deterministic.** A FIFTH failure, `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`, surfaces on roughly 1 cold-cache run in 4, always at counterexample `2^64-1`. PROVEN pre-existing (reproduced with all 17-01 files stashed: 86 pass / 5 fail) and owned by the TickVolatility track — it is NOT one of the 4 known `src/types/pos_spec/` reds. Re-run before treating a 5th failure as a regression. See `.planning/phases/17-interface-single-call-module/deferred-items.md` (D1); worth reporting `2^64-1` upstream as a genuine latent bug.
- **[17-01 MEASURED, binds 18a/19 and the Haskell consumer] `array_slot`'s add is CHECKED.** `v3::storage::array_slot` is `keccak256(base) + index` under Plank's checked `+`, so it PANICS (0x11) instead of wrapping. Addressable ids are capped at `2^256-1 - keccak(SLOT_ORDERS_BASE)` ≈ 6.5e74; above that `getOrderPacked` reverts rather than returning the 0 sentinel. Unreachable for counter-assigned ids, but relevant to any path accepting caller-supplied ids. Pinned by `test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates`.
- **Peer coordination:** `MAX_BATCH` value and return-shape confirmation still pending peer `mv15a18k`. 18a-01 shipped MAX_BATCH = **128** (hard admissibility ceiling 512; a peer value above it is CAPPED and reported, never silently adopted). **18b-01 shipped the return shape** as `(bool,uint256)[]` at `64 + 64N` bytes; every 18a state assertion was inherited unchanged and now flows through `abi.decode`, so they got strictly stronger. Does not block Phase 19.
- **[18b-01] The N=0 64-byte return is a HARD ENCODING REQUIREMENT on the consumer, and its failure is INVISIBLE on-chain.** A zero-arrival Poisson tick returns 64 bytes (offset `0x20`, length `0`), never 0 and never 32. A decoder that treats an empty batch as an empty returndata will revert in the Haskell client, not here. This is the single clause in the return contract most likely to break `StochasticOrderGen`.
- **[18a-01] The canonical-offset guard is a HARD ENCODING REQUIREMENT on the consumer**, not a soft convention. Solidity/`cast`/ethers/web3.py all emit `0x40` at byte 36, but a bespoke Haskell encoder that legally pads the head will be rejected with an empty revert. Flagged to the peer; if they cannot emit canonical offsets this becomes a real integration blocker rather than a test detail.

## Session Continuity

Last session: 2026-08-01T19:45:37.140Z
Stopped at: Completed 21-05-PLAN.md — PHASE 21 COMPLETE
Resume file: None
