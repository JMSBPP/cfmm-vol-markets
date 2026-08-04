# POST-RE-IMPORT DELTA (Phase 22, plan 22-01 task 2)

Measured: 2026-08-02T16:05:37Z
Import ref: `2039f2783598866a337115df4a265a75e8842e82` (`origin/develop`, PR #18)
Superseded ref: `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d` (PR #15, Phase 20's import)
HEAD at measurement: `a0b5d94`
Command: `forge test --via-ir --fuzz-seed 4880` — **byte-identical to the command
`.../20-deploy-rig-source-of-truth-import/FORGE-DELTA.md` used, seed included**, so the two rows
below are comparable. The plan's `forge test` (bare) would NOT have been.
Baseline source: `.planning/phases/20-deploy-rig-source-of-truth-import/FORGE-DELTA.md`
(post-import column: **85 passed / 27 failed / 112 total / 47 suites**, `compile-plank` 13 ok / 3 failed).

## The numbers

| metric | Phase 20 post-import | Phase 22 post-re-import | delta |
|---|---|---|---|
| forge total | 112 | **112** | **0** |
| forge passed | **85** | **85** | **0** |
| forge failed | 27 | **27** | **0** |
| forge suites | 47 | **47** | **0** |
| `compile-plank` ok | 13 | **13** | **0** |
| `compile-plank` failed | 3 | **3** | **0** |
| `forge build --via-ir` | exit 0 | **exit 0** | unchanged |

Raw summary line, quoted:

```
Ran 47 test suites in 1.20s (6.66s CPU time): 85 tests passed, 27 failed, 0 skipped (112 total tests)
```

```
compile-plank: 13 ok, 3 failed, 0 skipped
make: *** [Makefile:295: compile-plank] Error 1
```

`make compile-plank` exits 2 by design (any failing entrypoint reddens the target). The three
failures are the SAME three Phase 20 attributed to causes C2/C4 — `SpreadTickAssimetryHelper.plk`,
`VolOrderHelper.plk`, `VolOrderValidationHarness.plk`. They belong to `test/`
(Solidity-testing session) and nothing here was fixed.

## Attribution — every number that moved, and why none did

**ZERO numbers moved.** That is the expected result and it has a mechanism, not a coincidence:

- **F2 (`DeployDynamicFeeHook.s.sol`, `TICK_SPACING` 10 → 20)** is a `constant` in a *deploy
  script*. `forge test` never runs `foundry-scripts/deploy/*.s.sol`; the constant reaches nothing
  in the test corpus. It reaches the CHAIN only when the script is broadcast — which is why the
  standing rig is stale and 22-03 must redeploy, and why that staleness is invisible here.
- **F1 (`VolOrderManagerMod.plk`, +14 −12)** is a comment block only. **PROVEN, not assumed** — the
  pre-import source at `9f5ccba` and the post-import source at `2039f27` were each compiled through
  the identical `make compile-plank` invocation and the emitted bytecode is byte-identical:

  ```
  78ca20408a9f7959ac90a5b053fafa1884fc27a0333c96a44c46a05aa19bc88c  hex.old  (source @ 9f5ccba)
  78ca20408a9f7959ac90a5b053fafa1884fc27a0333c96a44c46a05aa19bc88c  hex.new  (source @ 2039f27)
  ```

  The swap was temporary and the file was restored byte-identical (`git status --porcelain
  src/modules/pos_spec/VolOrderManagerMod.plk` empty afterwards). Research asserted this
  byte-identity; this is the first time it was MEASURED in this tree.
- **`InitSwappableRig.s.sol` (NEW, 199 lines)** is a script with no test in the corpus referencing
  it, so it adds compilation surface and zero tests.

Consequently the entire Phase 20 failure inventory (causes C1–C4 + P, 27 reds) carries forward
UNCHANGED. This is a RECORD, not a gate: `test/` belongs to the Solidity-testing session (PID
284909) and nothing in it was touched.

## New compilation surface — the one thing this import DOES change

`forge build --via-ir` exits 0, and for the first time the two vendored v4-core routers are inside
the build graph. Before this import, `grep -rln 'PoolSwapTest\|PoolModifyLiquidityTest' test/ src/
foundry-scripts/` returned nothing; after it, the ONLY match is the newly imported script:

```
foundry-scripts/deploy/InitSwappableRig.s.sol
```

A green `forge build` alone would not prove the routers compiled — solc could have skipped them.
The artifacts were checked directly:

| artifact | `bytecode.object` length | `deployedBytecode.object` length |
|---|---|---|
| `out/PoolSwapTest.sol/PoolSwapTest.json` | 10374 | 10072 |
| `out/PoolModifyLiquidityTest.sol/PoolModifyLiquidityTest.json` | 9370 | 9068 |
| `out/InitSwappableRig.s.sol/InitSwappableRig.json` | 32238 | 32152 |

All three carry the mtime of this build run (2026-08-02 12:05:03 −0400 = 16:05:03Z), so none is a
stale artifact from an earlier tree.

`forge script` target resolution, with every env var explicitly unset
(`env -u POOL_MANAGER -u HOOK -u TOKEN0 -u TOKEN1`):

```
[3240698] → new InitSwappableRig@0x9f7cF1d1F558E57ef88a59ac3D47214eF25B6A06
  └─ ← [Return] 16075 bytes of code

[2929] InitSwappableRig::run()
  ├─ [0] VM::envAddress("POOL_MANAGER") [staticcall]
  │   └─ ← [Revert] vm.envAddress: environment variable "POOL_MANAGER" not found
  └─ ← [Revert] vm.envAddress: environment variable "POOL_MANAGER" not found

Error: script failed: vm.envAddress: environment variable "POOL_MANAGER" not found
```

That is the PASS signal specified by the plan: the contract was deployed into the simulation
(16075 bytes of runtime code), `run()` was ENTERED, and execution died on the required environment
variable — never on a compile error and never on "no matching contract". `--via-ir` on the routers
is now a measured fact rather than the phase's lowest-confidence assumption.

## Reproduction

```bash
npm ci --ignore-scripts
git -c submodule.lib/panoptic-helper.update=none submodule update --init --recursive
forge build --via-ir
jq -r '.bytecode.object | length' out/PoolSwapTest.sol/PoolSwapTest.json
jq -r '.bytecode.object | length' out/PoolModifyLiquidityTest.sol/PoolModifyLiquidityTest.json
env -u POOL_MANAGER forge script foundry-scripts/deploy/InitSwappableRig.s.sol \
  --tc InitSwappableRig --via-ir            # expected: dies on POOL_MANAGER
forge test --via-ir --fuzz-seed 4880
make compile-plank
```
