# RIG RUN RECORD (Phase 20, plan 20-03)

Run: 2026-07-31T18:49:44Z (run #1 manifest generatedAt 2026-07-31T18:46:13Z, run #2 2026-07-31T18:49:15Z)
Import ref: 9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d
anvil / forge / cast: anvil Version 1.5.1-stable, forge Version 1.5.1-stable, cast Version 1.5.1-stable
plank / jq: plank v0.1.1, jq-1.8.1
Command: `bash offchain/rig/deploy-rig.sh` (owns anvil, keep-alive default), then `bash offchain/rig/verify-rig.sh`

## Contracts (run #1)

Every address below was taken from foundry's broadcast record and then independently
confirmed against the deploy script's own printed console line. Both sides are
lowercased unconditionally, so the comparison is correct whether the source rendered
EIP-55 mixed case (console) or plain lowercase (broadcast JSON).

| name | address | broadcast source |
|---|---|---|
| VolOrderManagerMod | 0x5fbdb2315678afecb367f032d93f642f64180aa3 | `broadcast/DeployVolOrderManagerMod.s.sol/31337/run-latest.json` — `[.transactions[] \| select(.transactionType=="CREATE")][0].contractAddress` |
| RealizedVolatilityMod | 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 | `broadcast/DeployRealizedVolatilityMod.s.sol/31337/run-latest.json` — `[.transactions[] \| select(.transactionType=="CREATE")][0].contractAddress` |
| DynamicFeeMod | 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9 | `broadcast/DeployDynamicFeeMod.s.sol/31337/run-latest.json` — `[.transactions[] \| select(.transactionType=="CREATE")][0].contractAddress` |
| DynamicFeeHook | 0x233069526f587b8c8ce56c365e0449ab034e0080 | `broadcast/DeployDynamicFeeHook.s.sol/31337/run-latest.json` — top-level `[.transactions[] \| select(.transactionType=="CREATE2")][0].contractAddress` (see the RESOLVED section below) |
| PoolManager | 0x5fc8d32690cc91d4c39d9d3abcbd16989f875707 | `broadcast/DeployDynamicFeeHook.s.sol/31337/run-latest.json` — `[.transactions[] \| select(.contractName=="PoolManager")][0].contractAddress` |
| PriceSetterHook | 0x683ee59f069a5970dcf186f968af532b0c59b000 | `broadcast/PriceSetterHook.s.sol/31337/run-latest.json` — `[.transactions[] \| select(.contractName=="PriceSetterHook")][0].contractAddress` |
| PriceSetterPoolManager | 0xb7f8bc63bbcad18155201308c8f3540b07f84f5e | `broadcast/PriceSetterHook.s.sol/31337/run-latest.json` — `[.transactions[] \| select(.contractName=="PoolManager")][0].contractAddress` |

Accounts, derived with `cast wallet address --mnemonic ... --mnemonic-index N`, never typed:

| role | anvil index | address |
|---|---|---|
| deployer (`PlankDeployBase.deployerKey()`) | 0 | 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 |
| sender (the ORDER sender, `Sample.hs:21`'s literal) | 1 | 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 |

Pool, from the hook script's console log (`poolId` exists nowhere in the broadcast record,
so for that one field the console IS the primary source and there is nothing independent
to cross-check it against):

| field | value |
|---|---|
| poolId | 0xc26d0c664c1503d15da31243604d1904295ccb87658aa0f62ff9966f200e272e |
| currency0 | 0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6 |
| currency1 | 0xa513e6e4b8f2a923d98304ec87f64353c4d5c853 |
| tickSpacing | 10 |

`currency0`/`currency1` DO have a second source: the rig deploys its own two `MinimalToken`s,
which appear as named CREATEs in the hook broadcast record. They are confirmed as a SET
(the script sorts the pair by address; the broadcast keeps deploy order), so these two are
cross-checked like the seven contracts rather than trusted from stdout alone.

## RESOLVED — research §12.1: how the CREATE2-proxy hook deploy is recorded

Observed shape for `broadcast/DeployDynamicFeeHook.s.sol/31337/run-latest.json`
(identical in both runs):

```
[
  { "transactionType": "CREATE",  "contractName": "PoolManager",   "contractAddress": "0x5fc8d32690cc91d4c39d9d3abcbd16989f875707", "additionalContracts": [] },
  { "transactionType": "CREATE2", "contractName": null,            "contractAddress": "0x233069526f587b8c8ce56c365e0449ab034e0080", "additionalContracts": [] },
  { "transactionType": "CREATE",  "contractName": "MinimalToken",  "contractAddress": "0xa513e6e4b8f2a923d98304ec87f64353c4d5c853", "additionalContracts": [] },
  { "transactionType": "CREATE",  "contractName": "MinimalToken",  "contractAddress": "0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6", "additionalContracts": [] },
  { "transactionType": "CALL",    "contractName": null,            "contractAddress": "0x233069526f587b8c8ce56c365e0449ab034e0080", "additionalContracts": [] },
  { "transactionType": "CALL",    "contractName": "PoolManager",   "contractAddress": "0x5fc8d32690cc91d4c39d9d3abcbd16989f875707", "additionalContracts": [] }
]
```

**The branch that fired is the TOP-LEVEL `transactionType == "CREATE2"` transaction.**
`additionalContracts` is the empty array on every one of the six transactions.

This CLOSES the MEDIUM-confidence prediction in research §5.4 / §12.1 — and **the
prediction was WRONG**. The research expected foundry to record the raw `.call` to the
CREATE2 proxy `0x4e59b44847b379578588920cA78FbF26c0B4956C` as a `CALL` to the proxy with
the created hook in `additionalContracts[]`. It does not. Foundry attributes the deploy
directly to the hook: `transactionType: "CREATE2"`, `contractAddress` = the mined hook
address, `contractName: null` (null because the initcode is Plank FFI output that solc
never saw, the same reason the three `plankDeployFFI` modules cannot be keyed by name).

Consequences worth carrying forward:

- The plan's PRIMARY extractor branch (`additionalContracts[]` first) never fires here;
  the FALLBACK is the real path. Both branches are kept — the union expression is correct
  under either shape, and only running it revealed which one is real.
- The `initializeHook` one-shot is the fifth transaction, recorded as a `CALL` to the hook
  address. So the hook address appears twice with two different `transactionType`s; an
  extractor keying only on "first transaction touching the hook" would have been fine here
  by luck of ordering, but keying on `CREATE2` is what makes it correct by construction.
- A raw `.call` CREATE2 and a `new X{salt: ...}` CREATE2 are recorded the SAME way as far
  as `transactionType` goes; they differ only in whether `contractName` is populated.
  `PriceSetterHook.s.sol` uses `new X{salt: ...}` and does carry `contractName`, which is
  why that one is keyed by name and the Plank hook is keyed by type.

## SC-2

Verbatim output of `bash offchain/rig/verify-rig.sh` against the run #2 rig (exit 0):

```
PASS bytecode DynamicFeeHook: 0x233069526f587b8c8ce56c365e0449ab034e0080 has 15484 bytes of code
PASS bytecode DynamicFeeMod: 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9 has 2288 bytes of code
PASS bytecode PoolManager: 0x5fc8d32690cc91d4c39d9d3abcbd16989f875707 has 17151 bytes of code
PASS bytecode PriceSetterHook: 0x683ee59f069a5970dcf186f968af532b0c59b000 has 2183 bytes of code
PASS bytecode PriceSetterPoolManager: 0xb7f8bc63bbcad18155201308c8f3540b07f84f5e has 17151 bytes of code
PASS bytecode RealizedVolatilityMod: 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 has 14401 bytes of code
PASS bytecode VolOrderManagerMod: 0x5fbdb2315678afecb367f032d93f642f64180aa3 has 2147 bytes of code
PASS orderCount VolOrderManagerMod: decoded 0
PASS seeded RealizedVolatilityMod: lastIndex=0 getTimepointPacked=1766847064778384329583297500742918515827483896875618958121606202992619776
PASS owner DynamicFeeMod: owner()=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 == manifest accounts.deployer
PASS poolManager DynamicFeeHook: poolManager()=0x5fc8d32690cc91d4c39d9d3abcbd16989f875707 == manifest contracts.PoolManager
PASS poolId DynamicFeeHook: poolId()=0xc26d0c664c1503d15da31243604d1904295ccb87658aa0f62ff9966f200e272e == manifest pool.poolId
SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded (packed=1766847064778384329583297500742918515827483896875618958121606202992619776)
```

### The verifier was FALSIFIED before it was trusted

Six faults were injected into COPIES of the manifest (via the `RIG_MANIFEST` path
override); the real manifest's sha256 was checked byte-identical afterwards and the
verifier re-run green. Every branch fires with a named message and exit 1:

| Injected fault | Probe exercised | Result |
|---|---|---|
| `contracts.VolOrderManagerMod` set to `0x000000000000000000000000000000000000dead` | 1 (bytecode) | `SC-2 FAIL: VolOrderManagerMod at 0x...dead has zero-length bytecode`, exit 1 |
| `contracts.RealizedVolatilityMod` set to the LIVE `PoolManager` address | 3 (seed) | `SC-2 FAIL: RealizedVolatilityMod at 0x5fc8...5707 did not answer lastIndex()`, exit 1 |
| `accounts.deployer` set to `accounts.sender` | 4 (TOFU owner) | `SC-2 FAIL: DynamicFeeMod owner()=0xf39f... but the manifest deployer is 0x7099...`, exit 1 |
| `pool.poolId` last nibble flipped | 5 (pool wiring) | `SC-2 FAIL: DynamicFeeHook poolId()=...272e but the manifest pool.poolId is ...272f`, exit 1 |
| `contracts.PoolManager` set to `contracts.PriceSetterPoolManager` | 5 (hook to manager) | `SC-2 FAIL: DynamicFeeHook poolManager()=0x5fc8...5707 but the manifest PoolManager is 0xb7f8...4f5e`, exit 1 |
| manifest path pointed at a nonexistent file | precondition | `SC-2 FAIL: manifest not found at ...`, exit 1 |

Two of these matter more than the rest. The RealizedVolatilityMod fault points at a
contract that is LIVE and has 17151 bytes of code, so probe 1 passes and only probe 3
catches it — probe 3 is therefore not riding on the bytecode check. The PoolManager fault
swaps in the OTHER, equally live PoolManager, proving probe 5 discriminates between two
real contracts rather than merely between live and empty.

## SC-5 — double-run reproducibility

Command: `deploy-rig.sh` twice from scratch (it kills the previous anvil and starts a fresh
chain, so run #2 is genuinely from scratch), compared with `jq -S 'del(.generatedAt)'`.

Result: **IDENTICAL.** `diff -u` produced no output; the normalised files share the sha256
`197acd740685fb0860ec1f8227d95afc541985fe6d081b3fade6712f5888f354`.

The two `generatedAt` values DIFFER — `2026-07-31T18:46:13Z` versus `2026-07-31T18:49:15Z` —
which proves run #2 actually regenerated the file rather than the comparison reading one
file twice.

Seed used: INIT_TS=1700000000 INIT_TICK=0 (fixed literals in `deploy-rig.sh`; the script
contains no `date +%s`).

Two determinism results worth recording, because neither was guaranteed in advance:

1. **The CREATE2-mined addresses are stable across runs.** Both the Plank
   `DynamicFeeHook` (0x2330...0080, mined by `HookMiner.find` over `plank build` output)
   and the Solidity `PriceSetterHook` (0x683e...b000) reproduce exactly. For the Plank hook
   this means `plank build` emitted byte-identical initcode on both runs — had the
   compiler embedded anything run-varying, the mined salt and therefore the address would
   have moved.
2. **The seeded packed timepoint is identical across runs**
   (`1766847064778384329583297500742918515827483896875618958121606202992619776`), which
   confirms it is derived from the fixed `INIT_TS` literal and not from the wall clock.
   Had `INIT_TS` been taken from `date +%s` as the naive version of this script would, the
   manifest would still have matched (the seed is not a manifest field) but the SC-2 probe
   value would drift, and the seed itself would stop being reproducible.

## Console cross-check

Every contract address above was independently confirmed against its deploy script's
printed console line, case-normalised on both sides, with a mismatch exiting 1 rather than
warning. Labels checked, read out of the imported deploy sources rather than the research
table:

- `VolOrderManagerMod :` in `/tmp/rig-logs/01-vom.log`
- `RealizedVolatilityMod :` in `/tmp/rig-logs/02-rvm.log`
- `DynamicFeeMod :` in `/tmp/rig-logs/03-dfm.log`
- `DynamicFeeHook :` in `/tmp/rig-logs/04-hook.log`
- `PoolManager    :` in `/tmp/rig-logs/04-hook.log` (four spaces before the colon)
- `PriceSetterHook :` in `/tmp/rig-logs/05-psh.log`
- `PoolManager     :` in `/tmp/rig-logs/05-psh.log` (five spaces before the colon)

plus the `currency0      :` / `currency1      :` pair in `/tmp/rig-logs/04-hook.log`,
cross-checked as a set against the two `MinimalToken` CREATEs in the hook broadcast record.

The two `PoolManager` labels differ only in their internal padding, because the two scripts
align their columns to different label widths. They live in different log files, so the
distinction is not load-bearing for correctness, but it is the reason the labels are stored
with their exact spacing rather than trimmed.

### One console label differs from the research table

Research §3.2 lists `DeployDynamicFeeMod` as printing `owner (TOFU)  : ...`. The imported
file prints the literal string `owner (TOFU)  : the deployer, captured in-broadcast` — a
sentence, not an address. There is therefore no console address to cross-check the TOFU
owner against, and none is attempted; `DynamicFeeMod`'s own address is cross-checked from
its `DynamicFeeMod :` line, and the TOFU ownership claim is instead PROVEN on chain by
`verify-rig.sh` probe 4, which reads `owner()` and compares it to the manifest's deployer.
That is strictly stronger than matching a printed string. Every other label in the research
table matched the imported source exactly.

## Seed assertion

`deploy-rig.sh` greps `/tmp/rig-logs/02-rvm.log` for `seeded : true` and fails loudly if it
is absent, because `DeployRealizedVolatilityMod` SKIPS `initializeTWAP` when `INIT_TS` is 0
and still exits 0. Observed in both runs:

```
  seeded                : true
```

Without that assertion, an unset `INIT_TS` would surface later as an SC-2 nonzero-timepoint
failure that looks like a deployment failure but is really a configuration failure.

## Territory

`git status --porcelain Makefile foundry.toml remappings.txt foundry-scripts/ src/ test/`
produced NO output across the whole plan. `foundry-scripts/PriceSetterHook.s.sol` and the
four `foundry-scripts/deploy/` scripts are plank's files: they were RUN, never edited.
`offchain/rig/rig-manifest.json` is gitignored and never committed.
