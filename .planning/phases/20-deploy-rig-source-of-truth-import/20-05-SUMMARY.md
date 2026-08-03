---
phase: 20-deploy-rig-source-of-truth-import
plan: 05
subsystem: rig-consumption
tags: [literal-purge, pin-tests, keccak, falsifiability, sc-3, sc-4, sc-5, documentation]
requires:
  - "20-03: offchain/rig/rig-manifest.json, deploy-rig.sh, verify-rig.sh — the live rig the drivers now read"
  - "20-04: offchain/rig/rig-pins.json (30 selectors + 5 topic0s + 3 retired) and Rig.Manifest's loader"
  - "20-02: the imported src/interfaces/**/*.plk — the signature strings the tests parse as INPUT"
provides:
  - "an offchain executable surface with ZERO address/selector/topic0 literals — measured, not asserted"
  - "offchain/test/Main.hs — 44 checks; every pin recomputed from the .plk file it names, cross-checked against cast"
  - "Rig.Manifest.resolve_contract / resolve_account / parse_address — TOTAL Text -> Address, never the partial IsString"
  - "offchain/rig/README.md — SC-5's one documented sequence, run green end to end"
affects:
  - "Phase 21 (RPIN-*): inherits a green, falsifiable pin harness and the retired block intact; the encoder/decoder re-pin is the remaining work and is now DOCUMENTED as the known gap"
  - "offchain/rig/generate-pins.sh: its retired-value source moved off Decode.hs (this plan deleted that constant)"
  - "offchain/rig/check-upstream.sh: no longer carries either create_order selector as a literal"
tech-stack:
  added: []
  patterns:
    - "the FILE is the test's input: a pin test that carries its own signature string proves only that the test agrees with itself"
    - "a second INDEPENDENT implementation of a parser is the check, not a shared helper"
    - "factor the checker so the falsifiability case drives THE SAME function, never a copy of it"
    - "a check that would skip when its fixture is missing FAILS instead — a suite that goes quiet when the rig is down is worse than one that goes red"
    - "documentation-vs-grep tension resolves toward the criterion; archaeology belongs in the summary, not in a comment that trips the check"
key-files:
  created:
    - offchain/rig/README.md
  modified:
    - offchain/test/Main.hs
    - offchain/app/Sample.hs
    - offchain/app/Main.hs
    - offchain/lib/VolOrder/Decode.hs
    - offchain/lib/VolOrder/Report.hs
    - offchain/lib/VolOrder/Rpc.hs
    - offchain/lib/Rig/Manifest.hs
    - offchain/rig/check-upstream.sh
    - offchain/rig/generate-pins.sh
    - .gitignore
decisions:
  - "The plan's own prescribed Decode.hs comment contained the literal 0xa8892769 and would have FAILED the plan's own purge criterion — the SEVENTH self-contradicting criterion in this repo. The comment points at the retired block instead; no hex."
  - "generate-pins.sh's retired stale-topic0 source was re-pointed from Decode.hs (whose constant this plan deleted) to src/modules/VolOrderManagerMod.plk, the superseded duplicate module the value was ORIGINALLY transcribed from. Better provenance, still never typed, and a read-only file of another track."
  - "check-upstream.sh was in the purge scope and carried both create_order selectors; both are now read from rig-pins.json with jq. Not in the plan's file list, but the purge criterion is unsatisfiable without it."
  - "The README documents `git -c submodule.lib/panoptic-helper.update=none` rather than the plain recursive command: the plain form works only via an uncommitted local config artifact."
metrics:
  duration_min: 22
  completed: 2026-07-31
---

# Phase 20 Plan 05: Literal Purge, Pin Tests & the Documented Sequence Summary

Not one address, selector or topic0 literal survives anywhere in the offchain executable surface;
every pinned value is now recomputed **in a test, from the signature string parsed out of the
interface file the pin itself names**, agreed with `cast` as a second encoder, and the whole rig
is reproducible from one documented sequence that was run green top to bottom.

## Objective

Purge every literal from the executable surface into the rig manifest, and stand up the cabal
test-suite that proves the pins are a CONSUMPTION of the interface files rather than a
transcription of them.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Purge the literals — Sample/Main/Decode/Report/Rpc (+ two scripts) | `1e49f00` | 6 `.hs`, 2 `.sh` |
| 2 | The SC-4 pin recomputation and SC-3 manifest checks | `a0c3cc8` | `offchain/test/Main.hs` |
| 3 | The one documented command sequence, run green | `13d6fb0` | `offchain/rig/README.md`, `.gitignore` |

## The purge (SC-3)

```
$ grep -rnE '0x[0-9a-fA-F]{40}\b|0x[0-9a-fA-F]{64}\b|0x[0-9a-fA-F]{8}\b' \
      offchain --include='*.hs' --include='*.sh'
(no output)
```

Six literals were removed, not the four the research inventory predicted:

| file | literal | routed to |
|---|---|---|
| `app/Sample.hs:21` | `account` | `accounts.sender` |
| `app/Sample.hs:24` | `order_manager` | `contracts.VolOrderManagerMod` |
| `app/Sample.hs:27` | `price_setter_hook` | `contracts.PriceSetterHook` |
| `lib/VolOrder/Decode.hs:24` | `topic_order_created = 0xa8892769` | parameter, from `topics.VolOrderCreated` |
| `rig/check-upstream.sh:34` | `0x98d950ec` | `jq .selectors.create_order.selector` |
| `rig/check-upstream.sh:32` | `0x6501fe94` | `jq .retired.create_order_v1` |

### The purge FIXED a live bug, and it is measured

`Sample.hs`'s `price_setter_hook` was `0x78f77B58…`. On the running rig:

```
$ cast code 0x78f77B581417489BABC51CC63091db140962B000 --rpc-url http://127.0.0.1:8545
0x
$ cast code 0x683ee59f069a5970dcf186f968af532b0c59b000 --rpc-url http://127.0.0.1:8545   # manifest
0x608060405260043610…
```

**Zero bytecode.** The driver's entire price-write path was aimed at an address with no contract
at it. This is not a hypothetical — it is CONTEXT's "went stale after a redeploy" happening, and
the manifest closed it. The other two literals happened to still be correct (`VolOrderManagerMod`
landed at the same nonce-derived address), which is exactly 20-03's point: they were right by
accident, and a literal cannot announce when it stops being right.

## The pin harness (SC-4)

`cabal test` — **44/44 checks passed**, exit 0.

```
PASS sc4_ground_truth_encoder
PASS sc4_multiline_timepoint_written
PASS sc4_idempotent_canonical_form
PASS sc4_falsifiable
PASS sc4_no_retired_value_is_live
PASS sc4_cast_agreement
PASS sc3_load_succeeds
PASS sc3_corrupted_manifest_fails
PASS sc3_literal_purge
… 35 per-pin checks (30 selectors + 5 topic0s) …

44/44 checks passed
SC-3 and SC-4 OK
```

Every per-pin check opens the `.plk` file named in **that pin's own `source` field**, parses the
signature out of it, and recomputes with `Crypto.Ethereum.Utils.keccak256`. The suite carries no
signature string of its own except the five ground-truth rows, which are not read from the pin
file — so a corrupted pin file cannot make them agree with it.

The parser is a **second, independent implementation** of `generate-pins.sh`'s two rules. It is
deliberately anchored differently: the shell generator walks backward from each `const`
declaration, while this one scans comment blocks forward. Two different traversals producing the
same 35 values is the evidence; a shared helper would have produced none.

### Red-then-green, observed

A one-character corruption (`0x98d950ec` → `0x98d950ed`) in `rig-pins.json`:

```
FAIL sc4_pin_selector_create_order: recomputed value does not match the pin
      signature parsed from the file : create_order(uint88,uint24,uint16,uint96)
      recomputed (keccak256)         : 0x98d950ec
      pinned in offchain/rig/rig-pins.json   : 0x98d950ed
      source file                    : src/interfaces/pos_spec/VolOrderManagerInterface.plk

FAIL sc4_cast_agreement: cross-encoder disagreement:
      create_order: cast sig=0x98d950ec haskell=0x98d950ec pinned=0x98d950ed

42/44 checks passed
2 FAILED: sc4_cast_agreement, sc4_pin_selector_create_order
cabal test exit: 1
```

`git checkout -- offchain/rig/rig-pins.json` restored it byte-identical (`git diff --exit-code`
clean) and the suite returned **44/44, exit 0**. Note the shape of the red: the recomputed value
is *correct* and the pin is wrong, and both the Haskell encoder and `cast` say so independently.

### The suite caught a real defect in itself before it was trusted

On its first run `sc4_cast_agreement` FAILED while printing rows that looked identical
(`cast sig=0xb09b2297 haskell=0xb09b2297 pinned=0xb09b2297`). The cause was real: `cast` emits a
trailing newline and the trim helper stripped spaces/tabs/CR but not `\n`, so two identical-looking
hex strings compared unequal. Fixed with a dedicated `strip_ws`. Recorded because it is the
cheerful case of the same class of bug the whole milestone is about — a value that looks right and
compares wrong.

### The two hazard cases

- `sc4_multiline_timepoint_written` — the six-argument signature wrapped across two `//` lines in
  `RealizedVolatilityInterface.plk` parses to the full form and yields
  `44d3c76a…161415`. 20-04 MEASURED that a naive single-line parse gives `0xc0055983…`, a
  perfectly valid-looking wrong 32-byte hash; this check is the only thing between that and a
  green suite.
- `sc4_idempotent_canonical_form` — the SAME event from `DynamicFeeHookInterface.plk`, where the
  comment is already canonical, must survive the normaliser unchanged and produce the identical
  topic0. Idempotency is therefore a measured agreement between two comment shapes, not a claim.

`sc4_falsifiable` drives **the same `verify_pin` function** the 35 per-pin checks use, with the
retired stale topic0 read from `retired.topic_order_created_stale` (never typed), and requires it
to report a mismatch.

## SC-5 — the documented sequence, run green

`offchain/rig/README.md` was run top to bottom, in order, from the README. Every step exit 0
(captured in `/tmp/phase20-gate.log`):

| step | result |
|---|---|
| `npm ci --ignore-scripts` | exit 0 |
| `git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive` | exit 0, guard OBSERVED firing |
| `forge build` | exit 0 |
| `offchain/rig/check-upstream.sh` | exit 0 — `origin/develop = 9f5ccba…` carries `0x98d950ec` |
| `offchain/rig/verify-import.sh` | exit 0 — SC-1, 36 paths content-identical |
| `offchain/rig/deploy-rig.sh` | exit 0 — 7 contracts, all cross-checks OK |
| `offchain/rig/verify-rig.sh` | exit 0 — `SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded` |
| `cabal build -j all && cabal test` | exit 0, ZERO warnings, 44/44 |
| `cabal run cfmm-replicationPlank-rpc-api` | exit 0, reports a receipt |

### The submodule step is the one the README would have got wrong from memory

The plan's template said plain `git submodule update --init --recursive`. That command **does**
exit 0 in this checkout — but only because the skip is recorded in
`lib/panoptic-v2-core/.git/config`, a machine-local artifact. Upstream's committed `.gitmodules`
points `lib/panoptic-helper` at a repository that is not reachable, and this repo's own
`.gitmodules` has no stanza overriding it. A clean machine following the plain command would fail
at step 2. The README documents the `-c submodule.lib/panoptic-helper.update=none` form and
explains why, which is the whole point of a clean-machine sequence.

## Manifest-absent failure — verbatim

```
$ mv offchain/rig/rig-manifest.json /tmp/ && cabal run cfmm-replicationPlank-rpc-api
cfmm-replicationPlank-rpc-api: user error (Rig.Manifest: cannot read the rig address manifest.
  resolved path : offchain/rig/rig-manifest.json
  system error  : offchain/rig/rig-manifest.json: withBinaryFile: does not exist (No such file or directory)
  Stand the rig up (this writes the manifest) with:
      bash offchain/rig/deploy-rig.sh
  Regenerate the static pins with:
      bash offchain/rig/generate-pins.sh
  Override the path with the RIG_MANIFEST environment variable.)
exit 1
```

No fallback, no default address. The failure names the resolved path and the command that fixes it.

## Schema reconciliation — NOTHING to reconcile, verified not assumed

20-03 and 20-04 both reported zero deviation. Confirmed here independently rather than taken on
trust: `sc3_load_succeeds` runs `load_rig_from` over the REAL `rig-pins.json` and the REAL
`rig-manifest.json` and asserts 7 contracts — it passes, and it is now a permanent check rather
than a one-time observation. **No repair was needed and none was manufactured.**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `check-upstream.sh` carried two selector literals and is IN the purge scope**

- **Found during:** Task 1, running the purge grep
- **Issue:** the plan's file list names only five `.hs` files, but the purge scope it DECIDED is
  `*.hs` **and `*.sh`** under `offchain/`. `check-upstream.sh` carries `0x98d950ec` (its V1-vs-V2
  discriminator) and `0x6501fe94` (in a comment). The acceptance criterion "produces NO output" is
  unreachable without touching it.
- **Fix:** both values are now read from `rig-pins.json` with `jq` —
  `.selectors.create_order.selector` and `.retired.create_order_v1` — with a `jq` guard, a file
  guard, and a `0x`-prefix sanity check on both. This also makes the gate strictly better: a
  hand-copied selector would keep passing after the pins moved, which is the failure mode the
  milestone exists to remove.
- **Files modified:** `offchain/rig/check-upstream.sh`
- **Commit:** `1e49f00`

**2. [Rule 3 - Blocking] Deleting `Decode.hs`'s constant broke `generate-pins.sh`**

- **Found during:** Task 1
- **Issue:** 20-04's generator parses `retired.topic_order_created_stale` out of
  `offchain/lib/VolOrder/Decode.hs` using the anchor `topic_order_created =`. Task 1 deletes that
  line, so the generator would have aborted with "matched 0 values" — a working tool broken by
  this plan, discoverable only by running it.
- **Fix:** the spec now points at `src/modules/VolOrderManagerMod.plk`, the superseded duplicate
  module that carries `const TOPIC_ORDER_CREATED = 0xa8892769;` verbatim — the file the Decode.hs
  constant was ORIGINALLY transcribed from, and the origin of the rot research §2.2 identified.
  Strictly better provenance, still never typed, and it is another track's file which is only READ.
  A comment records the move and notes that a future deletion of that file is a loud failure by
  design, not a silently dropped entry.
- **Verified:** `generate-pins.sh` re-run produces `rig-pins.json` **byte-identical**
  (`git diff --exit-code` clean).
- **Files modified:** `offchain/rig/generate-pins.sh`
- **Commit:** `1e49f00`

**3. [Rule 2 - Missing critical functionality] No total `Text -> Address` conversion existed**

- **Found during:** Task 1
- **Issue:** `Address`'s `IsString` instance is `either error id . fromHexString`. Using it in
  `Main.hs` would turn a malformed manifest entry into a bottom thrown wherever the value is first
  forced — a quiet, mislocated crash, which is the same class of failure the manifest exists to
  prevent.
- **Fix:** `Rig.Manifest.parse_address` (total, `Either`, error names WHICH entry is bad) plus
  `resolve_contract` / `resolve_account`, and `account_address` so `Main.hs` never reaches into the
  accounts record inline. Every one is loud at startup.
- **Files modified:** `offchain/lib/Rig/Manifest.hs`
- **Commit:** `1e49f00`

**4. [Rule 1 - Bug] `sc4_cast_agreement` compared a value against itself-plus-a-newline**

- **Found during:** Task 2, first run
- **Issue:** the check failed while printing rows whose three values were visibly identical. The
  trim helper handled space/tab/CR but not `\n`, and `cast` emits one.
- **Fix:** dedicated `strip_ws` for subprocess output.
- **Files modified:** `offchain/test/Main.hs`
- **Commit:** `a0c3cc8`

### Findings (no code fix)

**5. The plan's own prescribed comment would have failed the plan's own criterion — the SEVENTH
self-contradicting criterion in this repo.** Task 1 §2 dictates a `Decode.hs` comment reading
"The RETIRED v1 value `0xa8892769` lives in rig-pins.json's `retired` block". That string contains
an 8-hex literal and the purge grep matches it. Written verbatim, the task's own acceptance
criterion could never pass. The comment points at the `retired` block without the hex; the value's
recorded homes are `rig-pins.json` and the plank module, both unaffected. **Phase 21's
falsifiability demo keeps its subject** — `retired.topic_order_created_stale` is untouched and
`sc4_falsifiable` already exercises it.

**6. Two acceptance criteria measure TEXT where they mean STRUCTURE, and the documentation lost.**
`grep -c 'account\|order_manager\|price_setter_hook' Sample.hs == 0` and
`grep -c 'Rig.Manifest' <decode chain> == 0` both counted my explanatory comments, not code. Both
were satisfiable by rewording, and both were reworded — the criteria now pass literally. Recorded
because the resolution cost real information: the routing table for the three removed bindings now
lives in this summary (see "The purge") rather than in `Sample.hs` where a future reader would
find it first. The structural properties were also verified directly: no such bindings exist and
no module in the decode chain imports the rig loader.

**7. `cabal run` completes but the order REVERTS, and this is pre-existing.** `VolOrder/Encoding.hs`
still builds `create_order(uint88,uint24,uint16)` — the RETIRED v1 3-arg form — while the deployed
V2 module dispatches `0x98d950ec`. This is 20-02's recorded cause C1, not purge damage: the manager
address the driver now uses is byte-identical to the literal it replaced. Re-pinning the encoder
and the decoder is Phase 21's work and is explicitly out of this plan's scope ("this task purges a
literal; it does not re-pin a decoder"). It is documented in the README so a reader does not read
it as a rig failure.

No Rule 4 condition arose. No authentication gate.

## Verification

| Check | Result |
|---|---|
| purge grep over `offchain/**/*.{hs,sh}` | **no output** |
| `cabal build -j all` | exit 0, **0 warnings** |
| `cabal test` | exit 0, **44/44** |
| `cabal test` PASS line for all 8 named SC-3/SC-4 checks | present (9 with the ground-truth row) |
| M >= 8 + 35 pins | 44 >= 43 |
| red-then-green on a 1-char pin corruption | 42/44 exit 1, then 44/44 exit 0 |
| `cabal run` against the live rig | exit 0, receipt reported |
| `cabal run` with the manifest moved aside | exit 1, names the path AND `deploy-rig.sh` |
| README sequence top to bottom | every step exit 0 |
| `grep -c 'keccak256'` / `'Keccak_256\|sha3'` in the test | 4 / **0** |
| `grep -Fc 'create_order(uint88,uint24,uint16,uint96)'` in the test | **1** (ground truth only) |
| `grep -c 'readFile\|source'` in the test | 9 |
| `grep -c '.planning'` in the README | **0** |
| `git ls-files` rig-pins.json / rig-manifest.json | tracked / **empty** |
| `git status --porcelain offchain/rig/rig-manifest.json` | empty (ignored) |
| `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` | **NO output** |
| `generate-pins.sh` re-run after the purge | exit 0, pin file byte-identical |

## Territory Compliance (CLAUDE.md)

`git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` produces
**NO output**. `src/modules/VolOrderManagerMod.plk` and the five `src/interfaces/**/*.plk` files
are READ by the generator and the tests and were never modified. Everything written lives under
`offchain/`, plus two lines in `.gitignore` (this workstream's build output) and this file.

## What Phase 21 Inherits

1. **A green, falsifiable pin harness.** Adding the v2 log-shape decode work means adding checks
   to a suite that has already been OBSERVED going red for the right reason.
2. **The retired block intact**, with `sc4_falsifiable` and `sc4_no_retired_value_is_live` already
   fencing it off from the live maps.
3. **The one remaining gap named and documented**: the encoder/decoder still speak v1. RPIN-04's
   demonstration subject (`0xa8892769`) survives as data in two places, never as a constant.
4. **A caveat**: `generate-pins.sh` now depends on `src/modules/VolOrderManagerMod.plk` existing.
   It is a superseded duplicate and plank may delete it; that would be a loud generator failure
   needing a new recorded home for the retired value, not a silent drop.

## Self-Check: PASSED

All claimed files exist: `offchain/rig/README.md`, `offchain/test/Main.hs`, `offchain/app/Sample.hs`,
`offchain/app/Main.hs`, `offchain/lib/VolOrder/{Decode,Report,Rpc}.hs`, `offchain/lib/Rig/Manifest.hs`,
`offchain/rig/{check-upstream,generate-pins}.sh`, `.gitignore`. All three claimed commits
(`1e49f00`, `a0c3cc8`, `13d6fb0`) resolve in `git log`. The 44/44 result, the zero-warning build,
the empty purge grep and the empty foreign-track `git status` were all re-run at self-check time.
