---
phase: 20-deploy-rig-source-of-truth-import
plan: 04
subsystem: rig-pins
tags: [pins, selectors, topic0, codegen, aeson, loud-failure, falsifiability]
requires:
  - "20-02: the 36 imported paths under src/interfaces/ — the signature strings every pin is computed from"
  - "20-01: offchain/rig/import-ref.txt — the sha stamped into rig-pins.json as generatedFrom"
provides:
  - "offchain/rig/generate-pins.sh — parses the imported .plk signature comments, computes with cast, emits the pin file; ZERO hex literals in the generator"
  - "offchain/rig/rig-pins.json — 30 selectors + 5 topic0s + 3 retired values, each naming its signature and source file"
  - "offchain/lib/Rig/Manifest.hs — ONE Rig value carrying both the static pins and the per-deploy addresses, every field mandatory"
  - "cabal wiring for this plan AND for 20-05's test-suite (web3-crypto, aeson, bytestring, text, containers, process, directory, filepath)"
affects:
  - "20-05: consumes rig-pins.json (falsifiability test over the `retired` block) and Rig.Manifest (load_rig, pin_topic0); its cabal deps are already declared"
  - "VolOrder/Decode.hs: its hardcoded stale topic0 is now recorded as retired.topic_order_created_stale, ready to be replaced by pin_topic0"
tech-stack:
  added: [web3-crypto, containers, text]
  patterns:
    - "anchor the parser on the DECLARATIONS, not on the comments — a comment-anchored parser silently emits a subset"
    - "the in-file const is the CROSS-CHECK, the computed value is the answer; a disagreement aborts rather than picking a side"
    - "balanced-paren accumulation, not a single-line regex — a truncated signature yields a valid-looking wrong hash"
    - "reject truncated (ellipsis) hex rather than expanding it from memory"
    - "falsify every guard in a scratch mirror, never in another track's files"
    - "loud means loud AND actionable: name the resolved path, the override env var, and the command that fixes it"
key-files:
  created:
    - offchain/rig/generate-pins.sh
    - offchain/rig/rig-pins.json
    - offchain/lib/Rig/Manifest.hs
  modified:
    - cfmm-replicationPlank-rpc-api.cabal
decisions:
  - "The plan's premise that all six interface files use the `// signature::` convention is FALSE — DynamicFeeInterface.plk uses a bare `// name(args)` shape. The parser accepts both, ordered by precedence, so all 30 selectors are emitted instead of 25"
  - "`contracts` stays an OPEN map (the 20-03 contract) and the loud failure is restored by a required-contract completeness check in load_rig_from, not by closing the map"
  - "The v1 E1 topic0 IS present verbatim and complete in the imported notes/DATA_CONTRACT.md, so it is PARSED rather than omitted; the truncated form in the .plk is rejected by an explicit ellipsis guard"
  - "Underscore-prefixed keys in the retired block are metadata and are dropped at decode, so a consumer iterating pin_retired cannot mistake the _note for a retired value"
metrics:
  duration_min: 14
  completed: 2026-07-31
---

# Phase 20 Plan 04: Generated Pins & the Rig Manifest Loader Summary

Every selector and topic0 the off-chain drivers will use is now COMPUTED by `cast` from a
signature string parsed out of an imported interface file and cross-checked against that file's
own declared constant — 30 selectors, 5 topic0s, 3 retired values, not one hex digit typed — and
the Haskell side gets a single `Rig` value whose every field is mandatory and whose every failure
names the resolved path and the command that fixes it.

## Objective

Generate the committed static pin file mechanically from the imported interface files, and give
the Haskell side one loud-failing loader for it and for the rig's address manifest.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write generate-pins.sh and produce the committed rig-pins.json | `3ed079f` | `offchain/rig/generate-pins.sh`, `offchain/rig/rig-pins.json` |
| 2 | Wire the cabal file and write Rig.Manifest | `13fde52` | `cfmm-replicationPlank-rpc-api.cabal`, `offchain/lib/Rig/Manifest.hs` |

## Task 1 — 35 pins, every one computed, every one cross-checked

### What the generator produced

**`selectors` (30 keys)**, keyed by the function name taken from the parsed signature:

    beforeSwap, changeFeeConfiguration, create_order, create_orders, deposit,
    getAverageVolatility, getCurrentFee, getFeeConfig, getOrderPacked, getTickCumulative,
    getTimepointPacked, getTwapTick, initializeDynamicFee, initializeHook, initializeTWAP,
    lastIndex, oldestIndex, orderCount, owner, poolId, poolManager, previewDeposit,
    previewRiskPrice, readWindow, riskPrice, riskWeightedShares, setRiskPrice, totalDeposits,
    totalShares, writeTimepoint

**`topics` (5 keys)**: `FeeApplied`, `FeeConfigurationChanged`, `TimepointWritten`,
`VolOrderCreated`, `WindowChanged`.

**`retired` (3 values + `_note`)**: `create_order_v1`, `topic_vol_order_created_v1`,
`topic_order_created_stale`.

All five source interface files are represented. `generatedFrom` is
`9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d`, read from `import-ref.txt`.

### The cross-check confirmed ALL 35 pins — zero disagreements

The generator computes with `cast sig` / `cast keccak` and then asserts the computed value equals
the `const`'s declared value in the same file, aborting with a diff on any mismatch. **All 35
unique pins agreed.** No interface file's declared constant is wrong, and the parser truncated
nothing.

The five SC-4 named targets match the research's independently `cast`-computed table exactly:

| signature | value |
|---|---|
| `create_order(uint88,uint24,uint16,uint96)` | `0x98d950ec` |
| `create_orders(uint256,uint256[])` | `0x81357911` |
| `writeTimepoint(uint32,int24)` | `0xb09b2297` |
| `VolOrderCreated(uint256,uint88,uint24,uint16,uint96)` | `0x18bd4d46…9de4e6` |
| `TimepointWritten(bytes32,uint32,int24,uint88,int24,int56)` | `0x44d3c76a…161415` |

### The multi-line case is proven untruncated, and the truncation hazard is REAL

`TimepointWritten` wraps across `RealizedVolatilityInterface.plk` lines 61-62. The balanced-paren
accumulator lands the full six-argument signature. What a naive single-line regex would have
produced was MEASURED, not argued:

    correct (2 lines, balanced-paren) : 0x44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415
    naive   (line 61 only, closed)    : 0xc0055983...cdd2b27b

Both are valid 32-byte hashes. Nothing about the wrong one looks wrong — which is exactly
research §7.3's point and the reason the in-file cross-check exists.

### Idempotency of the normaliser is proven by CROSS-FILE AGREEMENT, not asserted

Four names are declared in two files each, in **two different comment shapes**, and the generator
requires both sides to produce an identical signature and an identical computed value:

| name | shape A | shape B |
|---|---|---|
| `TimepointWritten` | multi-line, `indexed` + param names (RealizedVolatility) | already canonical, single line (DynamicFeeHook) |
| `WindowChanged` | `indexed` + param names (RealizedVolatility) | already canonical (DynamicFeeHook) |
| `FeeConfigurationChanged` | multi-line, param names (DynamicFee) | already canonical (DynamicFeeHook) |
| `getAverageVolatility` | `signature::` (RealizedVolatility) | `signature::` (DynamicFeeHook) |

All four agreed. So the "the normaliser must be IDEMPOTENT" requirement is not a claim about the
code — it is a measured agreement between a decorated form and an already-canonical form of the
same signature, produced by two independent paths through the parser.

### The valueless-const skip is a recorded decision

    7 valueless "const NAME =" lines SKIPPED DELIBERATELY, all in
    src/interfaces/protocol_integrations/IMarketStateSocket.plk:
      SELECTOR_REACT (2), SELECTOR_SYSTEM_CONTRACT_SUBSCRIBE (3), SELECTOR_START_SOCKET (5),
      SELECTOR_STOP_SOCKET (6), SELECTOR_SET_CALLBACK (7), SELECTOR_READ_CALLBACK (8),
      TOPIC0_CALLBACK (10)

The generator prints the count, the file and each const name on every run, so the exclusion is
visible rather than inferred — 20-02's hand-off requirement.

### The retired block was parsed from evidence, and the sweep makes it self-policing

| key | value | parsed from |
|---|---|---|
| `create_order_v1` | `0x6501fe94` | `VolOrderManagerInterface.plk:15` RETIRED comment |
| `topic_vol_order_created_v1` | `0x6a5dc726…0f9ee1a5` (full 64) | `notes/DATA_CONTRACT.md:16` |
| `topic_order_created_stale` | `0xa8892769` | `offchain/lib/VolOrder/Decode.hs:24` |

A **sweep** over every `RETIRED` line in the five interface files plus `notes/DATA_CONTRACT.md`
asserts that each full-length value found is covered by the table above — so a value retired
later cannot be silently dropped by this generator. One truncated occurrence (the `0x6a5dc726…`
prefix in the `.plk`) was rejected by the ellipsis guard and reported as deliberately excluded.

## Task 2 — one `Rig`, every field mandatory

`load_rig` / `load_rig_from` return a single `Rig` carrying both halves. `RigPins`,
`RigAddresses`, `RigAccounts`, `RigPool`, `RigSeed`, `PinEntry` all decode with the mandatory
field operator only — the optional-field operator appears **zero** times in the module, and there
is no `<|>` fallback and no defaulted address anywhere.

`cabal build -j all` exits 0 with **ZERO warnings** under `-Wall`.

### Decode demonstrations — the real manifest, not just a fixture

**20-03's `offchain/rig/rig-manifest.json` ALREADY EXISTED at execution time** (20-03 landed at
`520ecfd` earlier in this wave), so per the plan the REAL file was decoded rather than only the
fixture.

| # | input | outcome |
|---|---|---|
| A | real `rig-pins.json` + **real 20-03 manifest** | **LOADED OK** — chainId 31337, 30 selectors, 5 topics, 3 retired |
| B | real `rig-pins.json` + hand-built schema-B fixture | **LOADED OK** — identical counts |
| C | real manifest with `contracts.VolOrderManagerMod` deleted | **LOAD FAILED** — names the missing contract and lists the six present |
| D | real manifest with `accounts.deployer` deleted | **LOAD FAILED** — `Error in $.accounts: key "deployer" not found` |
| E | real manifest with `pool.tickSpacing` deleted | **LOAD FAILED** — `Error in $.pool: key "tickSpacing" not found` |
| F | manifest path that does not exist | **LOAD FAILED** — names the path and `bash offchain/rig/deploy-rig.sh` |

**No schema discrepancy with 20-03.** The real manifest matches the `<interfaces>` schema B
exactly — every key, every nesting level, all hex lowercase, `chainId`/`tickSpacing`/`initTs`/
`initTick` as JSON numbers. The wave-3 contract held; there is nothing for 20-05 task 1 to
reconcile on the manifest shape.

### Accessors

    contract_address rig "VolOrderManagerMod"  -> Right "0x5fbdb231…64180aa3"
    pin_selector     rig "create_order"        -> Right "0x98d950ec"
    pin_topic0       rig "VolOrderCreated"     -> Right 11189975784542661791637467250118308623896397784725887315143697243855835227366

`pin_topic0`'s hex→`Integer` conversion was checked against an independent computation
(`int(v,16)` in python) for both topic0s: **MATCH**. It returns `Integer` so 20-05 can compare
against `VolOrder.Decode`'s existing topic representation without writing a converter.

The `Left` path names the key AND lists the keys that ARE present, for both contracts and pins —
so a typo is a one-read fix rather than a hunt.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The `// signature::` convention is NOT used by all six files**

- **Found during:** Task 1, reading the actual interface files
- **Issue:** The plan and research §5.3 state the `// signature::` / `// event::` convention was
  "verified across all six interface files". It was not. **`DynamicFeeInterface.plk` uses a third
  shape** — bare `// name(args)` comments with no marker — for all five of its selectors
  (`initializeDynamicFee`, `changeFeeConfiguration`, `getCurrentFee`, `getFeeConfig`, `owner`).
  A marker-only parser would have emitted **25 selectors instead of 30** and exited 0, silently
  hand-picking a subset in direct contradiction of the plan's own "Emit EVERY pin the files
  declare; do not hand-pick a subset."
- **Fix:** The parser is anchored on the `const` DECLARATIONS rather than on the comments. For
  each `const NAME = <hex>;` it walks backward through the contiguous comment block and takes the
  closest signature source, with the `signature::`/`event::` marker taking precedence and the
  bare `// name(args)` form as the fallback. A const with a hex value and no derivable signature
  is a loud abort, not a skip — so a fourth shape appearing later fails rather than shrinking the
  output.
- **Files modified:** `offchain/rig/generate-pins.sh`
- **Commit:** `3ed079f`

**2. [Rule 2 - Missing critical functionality] The parser's abort was SILENT**

- **Found during:** Task 1 falsification (fault 2)
- **Issue:** the awk `die()` printed its diagnostic on **stdout**, which the generator redirects
  into the parser TSV. An injected fault produced `exit=3` and **no message at all** on the
  console. This is the same silent-failure class 20-02 removed from `verify-import.sh` — it fails
  closed either way, but a real parse failure would have told the operator nothing.
- **Fix:** `die()` now writes to `/dev/stderr`, and the bash-side awk invocation is wrapped with
  an explicit abort message naming the file. Re-injected: the fault now prints
  `FATAL: parser: …: no signature comment above const TOPIC0_EVENT_TIMEPOINT_WRITTEN (line 66)`
  followed by `FATAL: parser aborted on … no pin file was written`.
- **Impact:** none on pass/fail semantics or on the output — `rig-pins.json` was byte-identical
  before and after the fix (verified by `diff`).
- **Files modified:** `offchain/rig/generate-pins.sh`
- **Commit:** `3ed079f`

**3. [Rule 2 - Missing critical functionality] A missing contract could not be a decode failure**

- **Found during:** Task 2, building the acceptance demonstration
- **Issue:** the plan's task-2 acceptance criterion requires that deleting
  `contracts.VolOrderManagerMod` makes the decode **FAIL**. That is not achievable as stated,
  because the plan's own `<interfaces>` block locks `contracts` as an open map ("adding a contract
  later does not require a Haskell change"). **A smaller map is still a valid map**, so aeson
  cannot distinguish a complete manifest from one missing its core contract. Taken literally the
  two halves of the plan contradict each other — the sixth instance of this repo's
  self-contradicting-criterion pattern.
- **Fix:** the map stays OPEN (the 20-03 contract is preserved and extra contracts are accepted),
  and the loudness is restored where it can actually live: a `required_contracts` completeness
  check in `load_rig_from`, running after decoding, listing the missing names and the present
  ones. Both properties now hold at once. The failure is raised by the completeness check, not by
  aeson — recorded here precisely so the distinction is not blurred.
- **Files modified:** `offchain/lib/Rig/Manifest.hs`
- **Commit:** `13fde52`

### Findings (no fix required)

**4. The v1 E1 topic0 did NOT have to be omitted.** The plan instructed: do not invent a full
64-hex expansion of the truncated `0x6a5dc726…`, and if it is not present verbatim in a source
file it does not go in the file. It **is** present verbatim and complete in the imported
`notes/DATA_CONTRACT.md:16`, marked `RETIRED-NEVER-LIVE`. It is therefore parsed from there, not
expanded from memory, and lands as `retired.topic_vol_order_created_v1`. The truncated form in
`VolOrderManagerInterface.plk:38` is rejected by an explicit ellipsis guard so a prefix can never
be mistaken for a value.

**5. `_note` is filtered out of `pin_retired` at decode.** The plan asks for the "these are not
live pins" sentence to live inside the `retired` object. It does. But a consumer iterating
`pin_retired` would then see the note as if it were a retired value. Underscore-prefixed keys are
treated as metadata and dropped during decoding — `pin_retired` has 3 entries where the JSON
object has 4 keys (measured: `retired=3`).

No Rule 1 or Rule 4 condition arose. No authentication gate. No architectural decision required.

## Falsification — every guard was driven to FAIL before being trusted

Per this repo's binding falsify-before-trust pattern, and honouring 20-02's rule that faults are
never injected into another track's files: a **scratch mirror** of the inputs was built under the
session scratchpad with the same relative layout (the generator `cd`s to its own tree root), and
the faults were injected there. `src/`, `foundry-scripts/` and `notes/` were never touched.

| injected fault | result |
|---|---|
| control (unmodified mirror) | exit 0 |
| one hex digit of `SELECTOR_CREATE_ORDER`'s declared const flipped | **exit 1**, prints signature, declared, computed and the "both are findings" instruction |
| the `TimepointWritten` continuation line made a non-comment | **exit 3**, names the file, the const and the line (after deviation 2's fix) |
| the hook's `TimepointWritten` topic0 made to disagree with the module's | **exit 1**, cross-check fires before the duplicate check |
| mirror restored | exit 0 again |

The retired-value guards were exercised by construction: the ellipsis guard rejected the one
truncated occurrence, and the sweep confirmed coverage of both full-length RETIRED values.

## Verification

| Check | Result |
|---|---|
| `bash offchain/rig/generate-pins.sh` | exit 0 |
| idempotent: 2nd run + `git diff --exit-code offchain/rig/rig-pins.json` | clean, byte-identical |
| the five SC-4 values | all exact |
| `grep -cE '0x[0-9a-fA-F]{8}' generate-pins.sh` | **0** |
| `grep -c 'cast sig\|cast keccak' generate-pins.sh` | 2 |
| `TimepointWritten.signature` is the full 6-arg form | pass |
| `VolOrderCreated.signature` has no `indexed` / param name / whitespace | pass |
| every pin's `source` starts with `src/interfaces/` | pass |
| `selectors >= 5 and topics >= 5` | 30 and 5 |
| all hex lowercase | pass |
| `retired.create_order_v1` / `retired.topic_order_created_stale` | `0x6501fe94` / `0xa8892769` |
| no retired value leaked into `selectors` | pass |
| `generatedFrom == import-ref.txt` | pass |
| `cabal build -j all` | exit 0, **ZERO warnings** |
| `Rig.Manifest` in library `exposed-modules` | pass |
| `grep -c 'web3-crypto'` in cabal | exactly 2 |
| test-suite has `process` / `directory` / `aeson` / `bytestring` | pass |
| optional-field operator count in `Manifest.hs` | **0** |
| `RIG_PINS` / `RIG_MANIFEST` / `deploy-rig.sh` named in `Manifest.hs` | pass |
| `grep -cE '0x[0-9a-fA-F]{8}' Manifest.hs` | **0** |
| env-var overrides actually resolve | measured, both default and overridden |
| `git status --porcelain src/ test/ foundry-scripts/ Makefile` | **empty** |

## Territory Compliance (CLAUDE.md)

`git status --porcelain src/ test/ foundry-scripts/ Makefile` produces **NO output**. The
interface files were READ only; every falsification fault was injected into a scratch mirror
outside the repo. `notes/DATA_CONTRACT.md` was read, never modified. Only this workstream's
territory changed: `offchain/` and the cabal file.

Parallel-plan discipline held: none of 20-03's files (`deploy-rig.sh`, `verify-rig.sh`,
`.gitignore`, `RIG-RUN.md`) was touched.

## What 20-05 Inherits

1. **A committed, regenerable pin file** whose every value names its signature and source file,
   so the pin check can re-derive rather than trust.
2. **A `retired` block of 3 values** for the falsifiability test, explicitly fenced off from the
   live pin maps in three places: outside `selectors`/`topics`, the `_note` key, and the
   generator's header comment.
3. **`Rig.Manifest` already building warning-free**, with `pin_topic0` returning `Integer` so the
   `VolOrder.Decode` rewire needs no converter.
4. **All test-suite cabal deps already declared** — 20-05 needs no cabal edit, so there is no
   wave-4 collision.
5. **`required_contracts` is a live gate.** If a later rig deploys fewer than the seven schema-B
   contracts, `load_rig` fails at startup. That is intended, but it is a coupling 20-05 should
   know about.

## Requirement Status — RIG-01 deliberately NOT marked complete

RIG-01 spans 20-01 through 20-05 and is satisfiable only at phase end. This plan generated pins
and a loader; it started no anvil and captured nothing from one. Consistent with 20-01's and
20-02's decisions, RIG-01 stays UNCHECKED in `REQUIREMENTS.md`.

## Self-Check: PASSED

All claimed files exist (`offchain/rig/generate-pins.sh`, `offchain/rig/rig-pins.json`,
`offchain/lib/Rig/Manifest.hs`, `cfmm-replicationPlank-rpc-api.cabal`) and both claimed commits
(`3ed079f`, `13fde52`) resolve in `git log`.
