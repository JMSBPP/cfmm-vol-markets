---
phase: 27
slug: anvil-read-layer
kind: context
status: measured
created: 2026-08-17
---

# Phase 27 — Context, measured before planning

## What the phase inherits

| Requirement | State |
|---|---|
| **CHAIN-04** | ✅ **DONE** in 26-02 — `Chain.Shock` decodes a 21-member synthetic corpus, 12 checks |
| CHAIN-01 | ⛔ **externally blocked** — see below |
| CHAIN-02 | ⬜ real construction, not a tweak |
| CHAIN-03 | ⬜ |
| CHAIN-05 | ⬜ |
| CHAIN-06, CHAIN-07 | ⬜ config work, no chain needed |

## MEASURED 2026-08-17

**1. This worktree has NO `mev_tax_model_one` contracts.** `find src test -path '*mev_tax_model_one*'`
returns nothing. PR #30 merged them to `develop` (17 files), but `feat/rpc-api` is **84 ahead /
293 behind** and does not carry them.

**2. Two other worktrees DO have them** — `cfmm-wt/mev-migrate` (on PR #30's branch
`feat/mev-tax-model-one`) and `cfmm-wt/plank` (on `exp/mev_tax_model_one`), 7 `.plk` files each,
including `modules/AlgebraIntegralShocksWriterMod.plk`.

**→ A 293-commit merge is NOT required.** The bridge reads an anvil endpoint over RPC; it does not
care which worktree deployed. Another worktree stands the chain up; this one reads it. That also
keeps `src/`, `test/` and `foundry-scripts/` untouched, which is the territory rule.

**3. CHAIN-01 has a real external dependency.** There is **no deploy script for the Shock writer** —
`foundry-scripts/mev_tax_model_one/` holds only `DeployAlgebraFactory.s.sol`. The event is emitted
from a forge **test** (`AlgebraIntegralMevTaxModelOneShocks.t.sol`), not from a deployed contract
something else can drive. So "a `Shock` event in a **mined** transaction's logs" requires the plank /
mev-migrate workstream to drive the emitter against an anvil endpoint. **Not this workstream's to
build.** Everything else in the phase proceeds without it.

**4. `deploy-rig.sh` already stands up an anvil with a real v4 pool** — VolOrderManagerMod,
RealizedVolatilityMod, DynamicFeeMod, DynamicFeeHook, PriceSetterHook, InitSwappableRig. **None of
them is the Shock writer**, but a pool is all CHAIN-02/03/05 need.

**5. Block pinning is essentially ABSENT.** One `"latest"` tree-wide; no `BlockRef` type anywhere;
`CheatSwap/Rpc.hs:151` reads `GlobalState.blockNumber` with no pin. CHAIN-02 is construction.

**6. The endpoint sites are real and countable** — ten files name `ETH_RPC_URL` or
`127.0.0.1:8545`: four `*/Rpc.hs` providers, `app/Main.hs`, `app/CheatSwapProof.hs`,
`rig/deploy-rig.sh`, two `capture-*.sh`, and `spec/types.md`. CHAIN-06 says "nine sites, one rule" —
**re-count at execution; the tenth is a spec document, and prose is inside a grep's blast radius.**

**7. No anvil is running** (`eth_chainId` on 8545 refused).

## CHAIN-01's wording is STALE — same class as FEE-01's "exactly"

CHAIN-01 says *"The **`next`** event is decoded…"*. **`next(address,uint160,int24,uint24,uint24)` is
a FUNCTION SELECTOR** on `AlgebraIntegralShocksWriterInterface.plk`, **never an event** — 26-02
established this against the merged source and demoted it to a negative fixture. The event is
`Shock(address indexed pool, int24, uint24, uint24)`, topic0
`0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64`, verified equal to
`cast keccak` of that signature. **Correct the requirement text at phase close.**

## Carried from the end-to-end spike (`.planning/SPIKE-end-to-end.md`)

**S1 binds phase 28, not 27, but decide it before 28 plans:** a `KeyIdentity` can only be obtained
from a COMPLETED RUN — `key_identity` needs a `ToolchainIdentity` whose only producer is
`run_prover`'s `Produced` arm, yet `decide` needs the identity *before* the first solve. The loop
either bootstraps with a throwaway solve or the library gains a `detect_toolchain`.

**S3 touches CHAIN-03's spirit:** `Store.Cache.Decision` drops `CapturedStreams`, so a caller cannot
distinguish an inadmissible shock (abort line 109) from an unsolvable one (171/173).

## Plan shape

Three plans, serial (all edit the single-file suite `offchain/test/Main.hs`):

| Plan | Scope | Requirements | Needs a chain? |
|---|---|---|---|
| **27-01** | one endpoint rule across every site, producer included | CHAIN-06, CHAIN-07 | no |
| **27-02** | the pinned read layer — `BlockRef` required by construction; absent/zero/unparseable is an error | CHAIN-02, CHAIN-03 | Tier-C capture only |
| **27-03** | fixture records pool identity; phase close; CHAIN-01 recorded blocked | CHAIN-05 | Tier-C capture only |

Discipline follows phase 26 (mutation tables, observed firings) for the read layer, since CHAIN-02's
whole content is a guard that must be impossible to omit. Zero new `cabal test` dependencies on a
chain: both structural greps stay 0 and a third joins them for the chain.
