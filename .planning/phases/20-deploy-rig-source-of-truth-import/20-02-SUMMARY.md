---
phase: 20-deploy-rig-source-of-truth-import
plan: 02
subsystem: rig-import
tags: [import, provenance, sha256, plank-closure, forge-delta, source-of-truth]
requires:
  - "20-01: offchain/rig/import-ref.txt (the pinned develop sha) and FORGE-BASELINE.md (the delta baseline)"
provides:
  - "the imported tree: 36 paths byte-identical to origin/develop @ 9f5ccba, none re-typed"
  - "offchain/rig/import-paths.txt — the explicit 36-path import unit read by both the checkout and the pin"
  - "offchain/rig/verify-import.sh — SC-1 as a re-runnable, FALSIFIED command (exit 0 / exit 1)"
  - "IMPORT-PIN.md — source ref + 36 mechanically generated full sha256 digests"
  - "FORGE-DELTA.md — before/after counts with all 27 reds attributed to four named causes"
  - "PROOF the Plank closure is complete: all four deploy module roots compile from this branch"
affects:
  - "20-03 (deploy rig): the four foundry-scripts/deploy/ scripts and their .plk closure are now present and PROVEN to build, so an anvil failure cannot be a closure gap"
  - "20-04 (pin tests): parses the imported interfaces; must DELIBERATELY skip IMarketStateSocket.plk's seven valueless consts"
  - "Solidity-testing session (PID 284909): inherits 27 attributed reds + 3 compile-plank failures, with C2/C3 mechanical fixes measured"
tech-stack:
  added: []
  patterns:
    - "import by checkout, never by transcription — the plan's central anti-RPIN-04 mechanism"
    - "the path list is a FILE, so the checkout and the pin file cannot drift apart"
    - "falsify the verifier before trusting it: corrupt the pin, see exit 1, restore byte-identically"
    - "prove the closure by COMPILATION, before anvil, so a gap cannot masquerade as a deploy failure"
    - "reconcile count deltas by arithmetic identity, not by narration"
key-files:
  created:
    - offchain/rig/import-paths.txt
    - offchain/rig/verify-import.sh
    - .planning/phases/20-deploy-rig-source-of-truth-import/IMPORT-PIN.md
    - .planning/phases/20-deploy-rig-source-of-truth-import/FORGE-DELTA.md
    - foundry-scripts/deploy/ (5 scripts, imported)
    - notes/DATA_CONTRACT.md, notes/UNITS_AND_SCALES.md, .planning/rpc-api-volorder-v2-HANDOFF.md (imported)
  modified:
    - "30 tracked paths moved by checkout (6 of the 36 were already byte-identical)"
    - "src/lib/TickUtils.plk DELETED as superseded -> src/types/pricing/TickUtils.plk (git: R054)"
decisions:
  - "The 36-path list stands unchanged: zero closure gaps were exposed by the four plank builds, so no path was added"
  - "Both plan-time corrections to research 2.3 independently re-verified: TickBucket.plk does not exist on the ref (it is a struct inside TickUtils.plk), and test/ helpers were correctly left out"
  - "The SC-1 verifier was FALSIFIED (two failure branches driven to exit 1) before being reported as passing — this repo's record includes criteria that passed vacuously"
  - "A missing-pin-row branch was added to the verifier (plan text would have exited silently under set -e); fails closed either way, but now with a message"
  - "27 forge reds and 3 compile-plank failures REPORTED and attributed to four named causes, never repaired — test/ is the Solidity-testing session's territory"
metrics:
  duration_min: 13
  completed: 2026-07-31
---

# Phase 20 Plan 02: Source-of-Truth Import & Closure Proof Summary

The plank workstream's V2 rig artifacts and their full transitive Plank closure are on
`feat/rpc-api` — 36 paths imported BY CHECKOUT from `origin/develop @ 9f5ccba`, byte-identical,
none re-typed — with provenance pinned as 36 sha256 digests, SC-1 reduced to a falsified
re-runnable command, the closure PROVEN complete by four green `plank build`s, and the resulting
139/5/144 → 85/27/112 test regression measured and attributed rather than repaired.

## Objective

Import the binding artifacts and their transitive closure from the recorded ref by checkout, pin
their provenance, and prove the closure is complete by compiling the four module roots.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author the explicit import path list, ref-validated | `63efa5b` | `offchain/rig/import-paths.txt` |
| 2 | Execute the import by checkout and pin its provenance | `d70e167` | 36 imported paths, `src/lib/TickUtils.plk` deleted, `IMPORT-PIN.md` |
| 3 | Verifier, closure proof, forge delta | `ba29c60` | `offchain/rig/verify-import.sh`, `FORGE-DELTA.md` |

## Task 1 — The import unit is 36 paths, and every one resolves

All 36 paths validated against the recorded ref BEFORE anything was imported:

    all 36 paths resolve on 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d

No `MISSING ON` line, so no path had to be dropped or substituted from `origin/feat/plank`.
36 lines, 36 unique, zero comments, zero blank lines, zero `test/` entries, zero `TickBucket`.

**Both plan-time corrections to research 2.3 were re-verified independently, not taken on faith:**

1. `src/types/pricing/TickUtils/TickBucket.plk` does NOT exist on the ref
   (`git cat-file -e` fails); `git show <ref>:src/types/pricing/TickUtils.plk` line 3 is
   `const TickBucket = struct {`. The list is therefore **36 paths, not 37**.
2. `test/protocol_integrations/helpers/` stayed out. It is a declared `--dep helpers=` root, and
   all four module builds later exited 0 with that root nonexistent — confirming the research's
   MEASURED claim that Plank v0.1.1 does not validate unused dependency roots.

## Task 2 — Imported by checkout, byte-identical, nothing re-typed

One `xargs … git checkout <ref> --` over the explicit list. **30 of 36 paths moved; 6 were already
byte-identical** — and those 6 are exactly the set research 2.3 predicted (`StorageIndex`,
`TimeWindow`, `Timepoint`, `TickVolatility`, `TickVolatilityLib`, `VegaAccountInterface`). They
stay in the list so the file IS the closure rather than a diff of it.

**The supersede was verified before it was performed.** `src/lib/TickUtils.plk` had exactly three
local importers (`VolOrder.plk`, `SpreadTickAssimetry.plk`, `VolRangeWidth.plk`); all three are in
the import list, and on the ref all three import `types::pricing::TickUtils` instead. After the
checkout, `grep -rn 'lib::TickUtils' src/ --include='*.plk'` is empty. Git recorded the move as a
rename, **R054** — the 54% similarity research 2.3 predicted.

**Provenance.** `IMPORT-PIN.md` carries the ref, its subject
(`Merge pull request #15 from JMSBPP/feat/plank` — corroborating 20-01's gate result), and 36 rows
of full 64-char sha256. Rows were generated mechanically from `git show <ref>:<path> | sha256sum`;
the three header values written by hand were then MACHINE-CHECKED against ground truth
(`grep -q "$REF" $PIN` and a `git log -1 --format=%s` comparison), so a typo could not survive.

The digests independently corroborate research 2.1 — all fourteen recorded 16-char prefixes match
(`911a9a32…`, `e4a6ab88…`, `5907e8d5…`, `2283fe37…`, `b99d6b80…`, `5628b982…`, …), confirming the
develop merge carried plank's content unchanged.

### The V2 content discriminators are live, not merely present

    src/interfaces/pos_spec/VolOrderManagerInterface.plk:16: const SELECTOR_CREATE_ORDER = 0x98d950ec;
    src/interfaces/pos_spec/VolOrderManagerInterface.plk:15: // 0x6501fe94 is RETIRED-NEVER-LIVE (nothing was deployed).

The v1 selector survives ONLY as a comment; the sole live const is V2. E1 topic0
`0x18bd4d46…9de4e6` present. This is the value RPIN-04 exists to protect and the reason
`Decode.hs`'s stale `0xa8892769` topic0 must be re-derived from here in a later plan.

## Task 3 — Verifier, closure proof, delta

### SC-1 is a command, and it was FALSIFIED before being trusted

    SC-1 OK: 36 imported paths content-identical to 9f5ccba… and sha256-matched to IMPORT-PIN.md

Given this project's four recorded instances of criteria that passed vacuously, the verifier was
driven to FAIL on purpose — using `IMPORT-PIN.md` (this workstream's own file), never a
plank-owned one:

| Injected fault | Result |
|---|---|
| one hex char of the `VolOrderManagerMod` digest flipped | `SC-1 FAIL sha256 …: pinned=a05c… actual=b05c…`, exit 1 |
| the pin row deleted entirely | `SC-1 FAIL: no pin row in … for …`, exit 1 |

Both restorations verified byte-identical against a backup before proceeding. **A deviation
(Rule 2):** the plan's script text would have exited SILENTLY on a missing pin row (`set -e`
killing the command substitution with no message); an explicit empty-`want` branch was added. It
failed closed before and still does — the change is diagnostic quality, not pass/fail semantics.

### The closure is complete — proven by compilation, not inspection

All four module roots built with the exact flag set, verified against the IMPORTED
`PlankDeployBase.plankOpts()` rather than only the research text (7 deps, same order):

| Module root | exit | bytecode |
|---|---|---|
| `src/modules/pos_spec/VolOrderManagerMod.plk` | 0 | 4341 bytes |
| `src/modules/market_state_measurements/RealizedVolatilityMod.plk` | 0 | 28849 bytes |
| `src/modules/premium/DynamicFeeMod.plk` | 0 | 4623 bytes |
| `src/modules/protocol_integrations/DynamicFeeHook.plk` | 0 | 31015 bytes |

**Zero closure gaps — no path was added to the 36-line list.** Each output was further confirmed
to be pure hex, not an exit-0 diagnostic: `VolOrderManagerMod`'s bytecode contains
`6398d950ec8114`, i.e. **the V2 selector is live in the compiled dispatch table**, which is
strictly stronger evidence than the constant appearing in a source file.

### The delta: measured, reconciled, attributed

| metric | pre | post | delta |
|---|---|---|---|
| forge total / passed / failed | 144 / 139 / 5 | 112 / 85 / 27 | −32 / −54 / **+22** |
| compile-plank ok / failed | 14 / 0 | 13 / 3 | −1 / +3 |
| `forge build` | exit 0 | **exit 0** | unchanged |

`forge build` still exits 0, CONFIRMING research 7.5's mechanism: solc never sees `.plk`, so all
27 reds are runtime/FFI. **`forge script` — what 20-03 actually runs — is unaffected.**

The `forge total` fall of 32 is not lost tests: six suites now fail in `setUp()`, which forge
reports as ONE failure while the suite's remaining tests never run and are never counted.

All 27 reds attributed to four named causes in `FORGE-DELTA.md`: **C1** the V2 arity change
(`create_order(uint88,uint24,uint16,uint96)` / `0x98d950ec`; the v1 3-arg form is RETIRED),
**C2** two harnesses importing the removed `lib::TickUtils`, **C3** per-test `--dep` sets lacking
`types=src/types`, **C4** harness call sites at v1 arity. By transition: 1 carried pre-existing,
2 transformed, **24 genuinely new**.

compile-plank reconciles by exact arithmetic: 14 ok − 3 now-failing + 2 newly imported
(`DynamicFeeMod`, `DynamicFeeHook`) = **13 ok / 3 failed / 16 entrypoints**.

## Key Findings

**C3 is a dependency-root problem, and the proof is a divergence.** `VolRangeWidthHelper.plk`
compiles **OK** under `make compile-plank` (full dep set) while the SAME file fails under
`forge test`'s FFI (narrower per-test set). Re-running the failing command with
`--dep types=src/types` added emits bytecode and exits 0 — measured, no file edited. So C3 is a
one-flag fix, not a content migration, and the hand-off says so with evidence.

**`test__unit__everyInterfaceSignatureStringIsPinned` is a WORKING pin, not a bug.** It asserts the
interface carries `create_order(uint88,uint24,uint16)` and reddened because the file now carries
the 4-arg V2 string. It DETECTED the source-of-truth change — exactly its job. Recording it as
"just another red" would invert its meaning.

**The pre-existing red is now over-determined.** `VolOrderManagerFuzzTest::test__fuzz__logCreateOrder`
was already red pre-import (20-01 recorded it precisely so it would not be mistaken for import
damage). It is still red, but the V2 arity change would independently redden any v1
`create_order` fuzz — so it can no longer be used as an independent signal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Silent-failure branch in the SC-1 verifier**
- **Found during:** Task 3
- **Issue:** The plan's script computes `want=$(grep … | head -1)` under `set -euo pipefail`. When
  a pin row is absent the pipeline fails, so the assignment fails, so `set -e` aborts the script
  with NO diagnostic — a real failure mode (a hand-edited pin file) would report nothing.
- **Fix:** Added an explicit `if [ -z "$want" ]` branch printing
  `SC-1 FAIL: no pin row in <PIN> for <path>` and setting `fail=1`.
- **Impact:** None on pass/fail semantics — it failed closed before and still does. Verified by
  injection: the branch fires with exit 1.
- **Files modified:** `offchain/rig/verify-import.sh` (this workstream's own file)
- **Commit:** `ba29c60`

**2. [Rule 3 - Blocking/stale document] ROADMAP SC-1 still named a ref that was never used**
- **Found during:** state updates after Task 3
- **Issue:** Phase 20's "Depends on" line and SC-1 both judged the phase against
  `origin/feat/plank @ df7088f`. The import was performed and verified against
  `origin/develop @ 9f5ccba` per the 20-CONTEXT locked decision and 20-01's recorded ref. Left
  alone, 20-03/04/05 and the phase-end verifier would measure SC-1 against a ref this phase never
  touched — the fifth instance of this repo's stale-criterion pattern.
- **Fix:** Both spots corrected to name the recorded ref, with the supersession stated explicitly
  rather than silently overwritten. Content equivalence noted (all 14 binding-path sha256 prefixes
  measured on `df7088f` match the develop ref), so this is a wording correction, not a scope change.
- **Files modified:** `.planning/ROADMAP.md` (this workstream's own planning territory)
- **Commit:** the final metadata commit

No other deviation. No Rule 1 or 4 condition arose, no auth gate, no architectural decision.
**No closure gap surfaced**, so the plan's "add the missing path and re-pin" branch was never
taken and the 36-path list is unchanged from Task 1.

## Territory Compliance (CLAUDE.md)

`git status --porcelain test/ Makefile foundry.toml remappings.txt` produces **NO output**.

The import touched `src/` and `foundry-scripts/` — plank-owned, but the phase EXPLICITLY authorises
a verbatim checkout of those paths from the recorded ref. The distinction was honoured exactly:
every one of the 36 files is byte-identical to the ref (`git diff --exit-code` empty), so nothing
was hand-edited. `foundry.toml` / `remappings.txt` / `Makefile` needed no change, as research 2.4
predicted. The 27 test reds and 3 compile-plank failures are REPORTED with mechanical fixes
described, never repaired.

## Verification

| Check | Result |
|---|---|
| `bash offchain/rig/verify-import.sh` | exit 0, `SC-1 OK` |
| verifier falsifiability (2 injected faults) | both exit 1 with named messages |
| `git diff --exit-code <ref> -- <36 paths>` | no output |
| four `plank build` module roots | 4/4 exit 0, all pure hex, non-empty |
| `grep -cE '^\| \`[0-9a-f]{64}\` \|' IMPORT-PIN.md` | 36 |
| `ls foundry-scripts/deploy \| wc -l` | 5 |
| `test ! -e src/lib/TickUtils.plk` + no `lib::TickUtils` in `src/` | pass |
| `forge build` | exit 0 |
| `git status --porcelain test/ Makefile foundry.toml remappings.txt` | empty |
| `FORGE-DELTA.md` empty cells / unfilled placeholders | 0 / 0 |

## What 20-03 Inherits

1. **A present, buildable rig.** All five `foundry-scripts/deploy/` scripts plus a closure PROVEN
   to compile. An anvil-time failure in 20-03 therefore cannot be a closure gap — that class is
   eliminated before the rig is ever started.
2. **`forge build` exit 0**, so `forge script` is unaffected by the 27 test reds.
3. **The exact FFI command** (research 3.4, re-verified against the imported `plankOpts()`) for
   diagnosing a script failure the FFI would otherwise bury.
4. **Two operational traps already documented** and not yet consumed: `INIT_TS = 0` silently skips
   the seed (script still exits 0), and `DeployDynamicFeeHook.s.sol` needs `--tc` because it
   declares two contracts.

## Note for 20-04

`src/interfaces/protocol_integrations/IMarketStateSocket.plk` was imported for set-completeness
and IS the broken stub research 2.1 warned about — seven `const NAME =` lines with no values and
no terminators. The pin parser must skip valueless consts **DELIBERATELY, with the skip asserted
in a test**, so the exclusion is a decision rather than an accident.

## Requirement Status — RIG-01 deliberately NOT marked complete

RIG-01 requires the four deploy scripts to stand up the full rig on a local anvil with printed
addresses, selectors and topic0s captured. This plan started no anvil and captured no addresses —
it delivered an import, a pin, a verifier, a closure proof and a delta record. RIG-01 spans 20-01
through 20-05 and is satisfiable only at phase end; it stays UNCHECKED in `REQUIREMENTS.md`,
consistent with 20-01's decision.

## Self-Check: PASSED

All claimed files exist (`offchain/rig/import-paths.txt`, `offchain/rig/verify-import.sh`,
`IMPORT-PIN.md`, `FORGE-DELTA.md`, the five `foundry-scripts/deploy/` scripts, `notes/*.md`,
`src/types/pricing/TickUtils.plk`) and `src/lib/TickUtils.plk` correctly does NOT.
All three claimed commits (`63efa5b`, `d70e167`, `ba29c60`) resolve in `git log`.
