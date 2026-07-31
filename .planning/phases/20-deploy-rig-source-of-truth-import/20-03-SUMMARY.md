---
phase: 20-deploy-rig-source-of-truth-import
plan: 03
subsystem: rig-deploy
tags: [anvil, forge-script, manifest, create2, reproducibility, sc-2, sc-5, falsification]
requires:
  - "20-02: the imported foundry-scripts/deploy/ set and the PROVEN-complete Plank closure"
  - "20-01: offchain/rig/import-ref.txt (the pinned develop sha, copied into the manifest as generatedFrom)"
provides:
  - "offchain/rig/deploy-rig.sh — the one command that owns anvil and stands up all seven contracts"
  - "offchain/rig/verify-rig.sh — SC-2 as a re-runnable command, FALSIFIED on all five probes"
  - "offchain/rig/rig-manifest.json (GITIGNORED) — the single address source Phase 21/22 read"
  - "the rig-manifest.json schema, now REALISED and matching the 20-04 contract byte-for-byte"
  - "RIG-RUN.md — the observed run record, closing research §12.1"
affects:
  - "20-04 (pin tests / Manifest.hs): decodes this exact JSON; every contract key, nesting level and number-vs-string choice is now a measured fact, not a plan example"
  - "20-05 (reconciliation + literal purge): Sample.hs's three address literals now have live manifest homes (sender, VolOrderManagerMod, PriceSetterHook)"
  - "research §12.1 is CLOSED — future extractors must key the Plank hook on top-level CREATE2, not additionalContracts[]"
tech-stack:
  added: []
  patterns:
    - "manifest addresses come from a tool's machine-written record, then a SECOND independent source confirms them; disagreement exits 1"
    - "lowercase both sides unconditionally so the comparison is correct under EIP-55 or plain hex"
    - "delete stale broadcast records first: turns silent-wrong-address into honest file-not-found"
    - "poll, never wait: bounded cast block-number loop with a process-free read -t interval"
    - "falsify every probe before trusting it, using COPIES of our own file, then re-verify byte-identity"
    - "reproducibility is a measured diff of two from-scratch runs, not an assertion"
key-files:
  created:
    - offchain/rig/deploy-rig.sh
    - offchain/rig/verify-rig.sh
    - .planning/phases/20-deploy-rig-source-of-truth-import/RIG-RUN.md
    - offchain/rig/rig-manifest.json (generated, GITIGNORED, never committed)
  modified:
    - .gitignore
decisions:
  - "research §12.1 RESOLVED and the MEDIUM-confidence prediction REFUTED: foundry records the raw CREATE2-proxy call as a TOP-LEVEL transactionType CREATE2 attributed to the hook, with additionalContracts empty on every transaction"
  - "the fifth script (PriceSetterHook.s.sol) is IN the rig, supplying contracts.PriceSetterHook and its own second PoolManager"
  - "currency0/currency1 were upgraded from console-only to cross-checked as a SET against the two MinimalToken CREATEs; poolId remains console-primary because it exists nowhere else"
  - "DynamicFeeMod's TOFU owner is proven by an on-chain owner() read, not by a console string — the imported script prints a sentence there, not an address"
  - "the poll interval is a fifo-backed read -t rather than the sleep binary, so the script contains no fixed wait at all"
metrics:
  duration_min: 12
  completed: 2026-07-31
---

# Phase 20 Plan 03: Deploy Rig, Manifest & Reproducibility Summary

`bash offchain/rig/deploy-rig.sh` now takes a machine with no anvil running to a live seven-contract
V2 rig plus an address manifest whose every entry came out of foundry's broadcast JSON and was
independently confirmed against the deploy script's own console line — proven LIVE by
`verify-rig.sh` (five probes, all five driven to failure before being trusted) and proven
REPRODUCIBLE by two from-scratch runs whose manifests share the sha256
`197acd740685fb0860ec1f8227d95afc541985fe6d081b3fade6712f5888f354`.

## Objective

Build the one command that owns anvil and stands up the full V2 rig, generate the manifest from
foundry's broadcast records with an independent console cross-check, prove every contract is LIVE,
and prove the whole thing reproducible twice from scratch.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | `deploy-rig.sh` — owns anvil, runs the five deploy scripts, generates the manifest | `4244258` | `offchain/rig/deploy-rig.sh`, `.gitignore` |
| 2 | `verify-rig.sh` — SC-2 liveness, falsified on every probe | `98e6a67` | `offchain/rig/verify-rig.sh` |
| 3 | SC-5 double-run and the run record | `6830116` | `RIG-RUN.md` |

## The seven contracts

Chain 31337, `generatedFrom` = `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d` (read from
`import-ref.txt`, never retyped). Identical in both runs.

| name | address |
|---|---|
| VolOrderManagerMod | `0x5fbdb2315678afecb367f032d93f642f64180aa3` |
| RealizedVolatilityMod | `0xe7f1725e7734ce288f8367e1bb143e90bb3f0512` |
| DynamicFeeMod | `0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9` |
| DynamicFeeHook | `0x233069526f587b8c8ce56c365e0449ab034e0080` |
| PoolManager | `0x5fc8d32690cc91d4c39d9d3abcbd16989f875707` |
| PriceSetterHook | `0x683ee59f069a5970dcf186f968af532b0c59b000` |
| PriceSetterPoolManager | `0xb7f8bc63bbcad18155201308c8f3540b07f84f5e` |

Accounts (derived with `cast wallet address`, never typed): deployer =
`0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` (anvil 0), sender =
`0x70997970c51812dc3a010c7d01b50e0d17dc79c8` (anvil 1). Pool: poolId
`0xc26d0c664c1503d15da31243604d1904295ccb87658aa0f62ff9966f200e272e`, currency0
`0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6`, currency1
`0xa513e6e4b8f2a923d98304ec87f64353c4d5c853`, tickSpacing 10. Seed: initTs 1700000000, initTick 0.

**Note the coincidence that must not be read as a shortcut:** `VolOrderManagerMod` landed at
`0x5fbdb231…`, the very literal `Sample.hs:24` carries. That agreement is the point — the literal
was *right* and still had to go, because it was right only by nonce accident. The manifest value
was extracted from `run-latest.json` and cross-checked against the console; the identical-looking
result is corroboration, not a licence to keep deriving addresses from nonce arithmetic.

## RESOLVED — research §12.1, and the prediction was WRONG

The one MEDIUM-confidence prediction in the research is now an observation, and it did not hold.

Research §5.4/§12.1 expected `DeployDynamicFeeHook`'s raw `.call` to the CREATE2 proxy
`0x4e59b448…` to be recorded as `transactionType: "CALL"` to the proxy with the created hook in
`additionalContracts[]`. **It is not.** Foundry attributes the deploy directly to the hook:

```
{ "transactionType": "CREATE2", "contractName": null,
  "contractAddress": "0x233069526f587b8c8ce56c365e0449ab034e0080", "additionalContracts": [] }
```

`additionalContracts` is `[]` on all six transactions, in both runs. So the plan's PRIMARY
extractor branch never fires and the FALLBACK is the real path. Keeping both was correct — the
union expression is right under either shape, and only running it revealed which is real.

Two corollaries worth carrying:

- `contractName` is `null` for the same reason it is null on the three `plankDeployFFI` modules:
  the initcode is Plank FFI output solc never saw. So the Plank hook must be keyed on
  `transactionType`, while `PriceSetterHook` (a `new X{salt:…}` deploy) *does* carry a
  `contractName` and is keyed by name. Same `transactionType`, different keying.
- The hook address appears TWICE in the record with two different types — `CREATE2` for the
  deploy and `CALL` for the `initializeHook` one-shot. An extractor keying on "first transaction
  touching the hook" would have been right here by ordering luck; keying on `CREATE2` is right by
  construction.

## SC-2 — and the falsification that makes it mean something

`bash offchain/rig/verify-rig.sh` exits 0 with
`SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded (packed=1766847064778384329583297500742918515827483896875618958121606202992619776)`.
Full verbatim output is in `RIG-RUN.md`.

The script contains **zero address literals** (`grep -cE` for a 40-hex string returns 0); every
target is read from the manifest with `jq -r`, so it cannot drift from the rig.

Given this project's five recorded instances of criteria that passed vacuously, all five probes
were driven to FAIL on purpose, against COPIES via a `RIG_MANIFEST` path override. The real
manifest's sha256 was confirmed unchanged afterwards and the verifier re-run green.

| Injected fault | Probe | Result |
|---|---|---|
| `VolOrderManagerMod` set to `0x…dead` | 1 bytecode | `has zero-length bytecode`, exit 1 |
| `RealizedVolatilityMod` set to the LIVE `PoolManager` | 3 seed | `did not answer lastIndex()`, exit 1 |
| `accounts.deployer` set to `accounts.sender` | 4 TOFU owner | `owner()=0xf39f… but the manifest deployer is 0x7099…`, exit 1 |
| `pool.poolId` last nibble flipped | 5 pool wiring | `poolId()=…272e but the manifest pool.poolId is …272f`, exit 1 |
| `contracts.PoolManager` set to `PriceSetterPoolManager` | 5 hook-to-manager | `poolManager()=0x5fc8… but the manifest PoolManager is 0xb7f8…`, exit 1 |
| manifest path nonexistent | precondition | `manifest not found at …`, exit 1 |

**Two of these are load-bearing beyond box-ticking.** The RealizedVolatilityMod fault points at a
contract with 17151 bytes of live code, so probe 1 passes and only probe 3 catches it — probe 3 is
demonstrably not riding on the bytecode check. The PoolManager fault swaps in the OTHER, equally
live PoolManager, proving probe 5 discriminates between two real contracts rather than merely
between live and empty. A live-vs-empty-only falsification would have left both of those
unproven.

## SC-5 — reproducibility is measured, not asserted

Two from-scratch runs (the script kills the previous anvil and starts a fresh chain, so run 2 is
genuinely from scratch). `jq -S 'del(.generatedAt)'` over both: `diff -u` empty, both normalised
files sha256 `197acd740685fb0860ec1f8227d95afc541985fe6d081b3fade6712f5888f354`. The two
`generatedAt` values DIFFER (`18:46:13Z` vs `18:49:15Z`), which proves run 2 actually regenerated
the file rather than the comparison reading one file twice.

Two determinism results that were NOT guaranteed in advance:

1. **Both CREATE2-mined addresses are stable.** For the Plank `DynamicFeeHook` this means
   `plank build` emitted byte-identical initcode on both runs — had the compiler embedded
   anything run-varying, the mined salt and therefore the address would have moved. This is a
   stronger statement about the Plank toolchain than 20-02's "it compiles and emits hex".
2. **The seeded packed timepoint is identical across runs**
   (`1766847064…619776`), confirming it derives from the fixed `INIT_TS` literal and not the wall
   clock. This is the measurable payoff of refusing `date +%s`: the manifest would have matched
   either way (the seed is not an address field), so a clock-derived `INIT_TS` would have passed
   SC-5 while silently making the rig's *state* irreproducible.

## Key Findings

**One console label differs from the research table, and the fix made the check stronger.**
Research §3.2 lists `DeployDynamicFeeMod` as printing `owner (TOFU)  : …`. The imported file
prints `owner (TOFU)  : the deployer, captured in-broadcast` — a sentence, not an address. There
is nothing to cross-check, so none is attempted. Instead `verify-rig.sh` probe 4 reads `owner()`
on chain and compares it to the manifest's deployer, which is strictly stronger than matching a
printed string. Every other label matched the imported source exactly; per the plan, the FILE
wins and the research note is stale on this one row.

**`poolId` has exactly one source and that is stated rather than hidden.** It is not an address in
the broadcast record and appears nowhere else, so the console IS primary for it and there is
nothing independent to confirm it against. The script says so in a comment. `currency0`/`currency1`
were in the same position until it turned out the rig's own two `MinimalToken`s appear as named
CREATEs in the hook record — so those two were upgraded to a SET cross-check (the script sorts by
address, the broadcast keeps deploy order), leaving `poolId` as the single console-only field.

**The two `PoolManager` console labels differ only in padding** — `PoolManager    :` (four spaces)
in `DeployDynamicFeeHook` versus `PoolManager     :` (five) in `PriceSetterHook.s.sol`, because
the scripts align to different label widths. They live in separate log files so nothing depends on
it, but it is why the labels are stored with exact spacing rather than trimmed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `lsof` is not installed in this environment**
- **Found during:** Task 1
- **Issue:** The plan's step 1 names `lsof -ti tcp:8545` (or `fuser`) to kill the stale anvil by
  port. `which lsof` fails here; only `fuser` is present.
- **Fix:** `kill_rpc_listener()` prefers `lsof`, falls back to `fuser`, and exits 1 with a named
  message if neither exists — rather than silently skipping the kill and then colliding with a
  stale chain. Kill is still by PORT, never a blanket `pkill anvil`, so another peer's worktree
  anvil on a different port is untouched.
- **Files modified:** `offchain/rig/deploy-rig.sh`
- **Commit:** `4244258`

**2. [Rule 2 - Missing critical functionality] The poll interval had to exist without the `sleep` binary**
- **Found during:** Task 1
- **Issue:** The plan requires a bounded poll at roughly 0.2s intervals AND that
  `grep -c 'sleep ' deploy-rig.sh` be 0. A pure busy-loop of 50 `cast block-number` calls against
  a closed port returns "connection refused" almost instantly, burning all 50 attempts in well
  under the time anvil needs to bind — a guaranteed flake, and exactly the CI failure the
  poll-never-sleep rule exists to prevent.
- **Fix:** A `pause()` helper doing `read -t <n>` on a fifo nothing ever writes to. It is an exact,
  process-free timeout, so the script has a real 0.2s poll interval and contains no `sleep` call
  and no fixed pre-deploy wait. Both the letter and the intent of the criterion hold.
- **Files modified:** `offchain/rig/deploy-rig.sh`
- **Commit:** `4244258`

**3. [Rule 2 - Missing critical functionality] `currency0`/`currency1` had no second source**
- **Found during:** Task 1
- **Issue:** The plan routes all four pool fields through the console. But the phase's success
  criterion is that *every manifest address* was confirmed against a second independent source,
  and `currency0`/`currency1` ARE manifest addresses — leaving them console-only would have
  contradicted that criterion for two of the eleven addresses shipped.
- **Fix:** When the rig deploys its own tokens (no `TOKEN0`/`TOKEN1` env), the two `MinimalToken`
  CREATEs in the hook broadcast record are compared as a sorted SET against the console pair;
  mismatch exits 1. Guarded so an env-supplied token pair skips the check rather than failing.
  `poolId` and `tickSpacing` remain console-primary, which is now a genuinely single-address
  exception instead of a three-address one.
- **Files modified:** `offchain/rig/deploy-rig.sh`
- **Commit:** `4244258`

**4. [Rule 2 - Missing critical functionality] `verify-rig.sh` needed a manifest-path override**
- **Found during:** Task 2
- **Issue:** The plan's falsifiability spot-check requires running the verifier against a doctored
  manifest. Doing that by temporarily overwriting the real file risks leaving a corrupted manifest
  behind if anything aborts mid-check.
- **Fix:** `RIG_MANIFEST=<path>` override, defaulting to the real path. All six faults ran against
  COPIES; the real manifest's sha256 was verified unchanged afterwards. This also makes the
  falsification re-runnable by anyone, rather than a one-time claim in a summary.
- **Files modified:** `offchain/rig/verify-rig.sh`
- **Commit:** `98e6a67`

No Rule 1 (no bug surfaced — every deploy script ran green first time) and no Rule 4 condition
arose. No auth gate. No architectural decision needed.

### Acceptance criterion that needed judgement

`grep -c 'rig-manifest.json' offchain/rig/verify-rig.sh` must be at least 4; the first draft had
2, because the path is held in a variable (which is *better* engineering than repeating a literal).
Rather than keyword-stuff to hit the number, two genuinely informative references were added: the
missing-manifest error now names the file `deploy-rig.sh` writes, and a comment above the `m()`
helper records that every probe target is read from it and that the file contains no literal
address. Count is now 4 and both additions carry real information.

## Interface Contract Note for 20-04 and 20-05

**The emitted manifest matches the plan's `<interfaces>` schema EXACTLY — no deviation.** All seven
`contracts` keys at the specified nesting, `accounts.{deployer,sender}`,
`pool.{poolId,currency0,currency1,tickSpacing}`, `seed.{initTs,initTick}`, `chainId`,
`generatedAt`, `generatedFrom`. `chainId`, `tickSpacing`, `initTs`, `initTick` are JSON numbers;
every hex string is lowercase (`jq -e '[.. | strings | select(startswith("0x"))] | map(test("^0x[0-9a-f]+$")) | all'`
exits 0); no key is absent and no value is null. 20-04's embedded copy should decode this file
unchanged, and 20-05 task 1's reconciliation should find nothing to reconcile on the schema.

## Verification

| Check | Result |
|---|---|
| `bash offchain/rig/deploy-rig.sh` from no-anvil state | exit 0, anvil left RUNNING (`cast block-number` answers) |
| `bash offchain/rig/verify-rig.sh` | exit 0, `SC-2 OK: 7 contracts live` |
| verifier falsifiability (6 injected faults) | all 6 exit 1 with named messages; real manifest sha256 unchanged |
| SC-5 `jq -S 'del(.generatedAt)'` diff over 2 runs | empty; both sha256 `197acd74…5888f354` |
| the two runs' `generatedAt` | DIFFER (18:46:13Z vs 18:49:15Z) |
| manifest schema jq gate (7 keys, all lowercase 40-hex, poolId 64-hex, initTs nonzero) | exits 0 |
| `git status --porcelain offchain/rig/rig-manifest.json` | empty (ignored, `.gitignore:58`) |
| `git status --porcelain Makefile foundry.toml remappings.txt foundry-scripts/ src/ test/` | **NO output** |
| `grep -c 'date +%s'` / `'sleep '` in `deploy-rig.sh` | 0 / 0 |
| `grep -c -- '--tc'` in `deploy-rig.sh` | exactly 2 |
| 40-hex literals in `verify-rig.sh` | 0 |
| `RIG-RUN.md` unfilled `<` placeholders | 0 |
| `RIG-RUN.md` contract rows vs manifest | 7/7 match |

## Territory Compliance (CLAUDE.md)

`git status --porcelain Makefile foundry.toml remappings.txt foundry-scripts/ src/ test/` produces
**NO output**. The five deploy scripts are plank's files: they were RUN, never edited — including
`foundry-scripts/PriceSetterHook.s.sol`, whose contract name (`PriceSetterHookScript`) differs from
its file name, handled with `--tc` rather than by touching the file. Everything written lives under
`offchain/rig/` and `.planning/`.

## What 20-05 Inherits

1. **A live rig and a real manifest**, regenerable with one command, with all three of
   `Sample.hs`'s address literals now having manifest homes: `account` → `accounts.sender`,
   `order_manager` → `contracts.VolOrderManagerMod`, `price_setter_hook` →
   `contracts.PriceSetterHook`.
2. **Research §12.1 is closed**, so no plan downstream needs to hedge on the CREATE2 shape.
3. **A schema with zero drift** from the 20-04 contract, so reconciliation should be a
   confirmation rather than a repair.

## Requirement Status — RIG-01 still NOT marked complete

RIG-01 requires the deploy scripts to stand up the full rig on a local anvil *with printed
addresses, selectors and topic0s captured*. This plan delivers the rig and the ADDRESSES; the
selector and topic0 pins are 20-04's `rig-pins.json`. RIG-01 spans 20-01 through 20-05 and is
satisfiable only at phase end, so it stays UNCHECKED in `REQUIREMENTS.md`, consistent with the
20-01 and 20-02 decisions.

## Self-Check: PASSED

All claimed files exist (`offchain/rig/deploy-rig.sh`, `offchain/rig/verify-rig.sh`, the generated
`offchain/rig/rig-manifest.json`, `RIG-RUN.md`, the `.gitignore` entry at line 58). All three
claimed commits (`4244258`, `98e6a67`, `6830116`) resolve in `git log`. The SC-5 sha256
`197acd74…5888f354` was re-verified against `/tmp/rig-run1.norm.json` after the summary was
written, and both scripts were re-run green at self-check time.
