# Remove dead Hardhat/TS scaffold + rewrite README/AGENTS — design

**Date:** 2026-08-26
**Status:** design; awaiting two-reviewer gate
**Repo:** `JMSBPP/cfmm-vol-markets` (fork; canonical `d2p-finance/cfmm-vol-markets`)

## 1. Goal & context
cfmm-vol-markets is the on-chain protocol core; its real build is 100% Foundry
(`foundry.toml`: `src="src"`, `test="test"`, `script="foundry-scripts"`, `libs=["lib","node_modules"]`)
+ the Plank toolchain (`Makefile`: `make plank-toolchain`, `make compile-plank`). The repo still
carries the unmodified `create-hardhat` sample scaffold, which the restructure spec (PR #53) §4
explicitly deferred ("the TS/HH surface … retained unless a follow-up says otherwise"). This is
that follow-up: remove the dead scaffold and rewrite the two user-facing docs that are still the
Hardhat template. **One PR → `develop`**, gate-verified.

## 2. Remove (dead — zero references from `Makefile`, `develop-gate.yml`, `foundry.toml`, `remappings.txt`)
Evidence: `hardhat.config.ts`/`npx hardhat` appear in NO Makefile or CI step; `remappings.txt`
`@contracts/` points into `lib/panoptic-v2-core/contracts/` (a submodule), NOT root `contracts/`.
- `contracts/` (Counter.sol, Counter.t.sol) — Hardhat starter template
- `ignition/` (modules/Counter.ts) — Hardhat Ignition template
- `hardhat.config.ts`
- `test/Counter.ts` — Hardhat-3 starter test (viem/`network.create()`; not a `.t.sol`)
- `scripts/send-op-tx.ts` — imports `"hardhat"`; zero refs (grep-confirmed)
- `tsconfig.json` — only serves the TS scaffolding above (zero `.ts` remain after removal)
- `.agents/skills/hardhat/` + `.agents/skills/hardhat-toolbox-viem/` — document the deleted layout

**KEEP `NOTES.md`** (reviewer RC-M1): despite being unreferenced by the *build*, it IS referenced
by `.planning/` as a tracked source-of-record (backlog "atoms" in `backlog-coverage-ledger.md`,
spec-of-record for `BinomialProxy.plk`/`SwapAmtGen.plk` in `ARCHITECTURE.md`). NOT Hardhat scaffold;
removing it would orphan those references. Drop from the removal set — it stays.

**`package.json`:** remove devDeps `hardhat`, `@nomicfoundation/hardhat-ignition`,
`@nomicfoundation/hardhat-toolbox-viem`, `viem`, and (now-unused, zero `.ts` remain) `typescript`,
`@types/node`. **KEEP** `@cryptoalgebra/*` (hard forge dep: `remappings.txt`→`node_modules/`).
Dependency-graph verified (Sol-m1): `@cryptoalgebra/{volatility-oracle-plugin,dynamic-fee-plugin}`
and their transitive `integral-core`/`integral-periphery` (what `remappings.txt:43-44` points at)
declare deps only on other `@cryptoalgebra/*` + a nested `@openzeppelin` — ZERO reference to
hardhat/viem, so the trim cannot break resolution. **Regenerate `package-lock.json` via `npm install`
and SHIP the regenerated lock in the PR** (Sol-M2: `npm ci` hard-fails if lock and package.json are
out of sync → PR unmergeable).

**Do NOT remove:** `scripts/wt-setup.sh`, `scripts/wt-teardown.sh`, `scripts/peers.tsv` (live dev
tooling), `script/check-algebra-ref-pin.sh` (Makefile:136), `foundry-scripts/`, `.planning/`,
`todo.md`, `notes/DATA_CONTRACT.md`+`UNITS_AND_SCALES.md`, `src/`, `test/` (Foundry .t.sol), `lib/`.

## 3. Rewrite `README.md` and `AGENTS.md`
Both are the untouched Hardhat sample template. `CLAUDE.md` is a symlink → `AGENTS.md` (updates in
lockstep). New content:
- **Identity:** on-chain protocol core of cfmm-vol-markets (renamed from cfmm-replicationPlank).
- **Repo split:** `spec/`→d2p-finance/cfmm-vol-markets-spec (Lean/math), `offchain/`→d2p-finance/
  gams-evm-transport (off-chain RPC), `refs/`→d2p-finance/cfmm-refs (research shelf: text+manifest,
  not PDFs), GAMS model→cfmm-numopt.
- **Fork → PR workflow:** d2p-finance canonical / JMSBPP fork; all changes via PR fork→upstream.
- **Build:** `make plank-toolchain`, `make compile-plank`, `forge test --via-ir`; layout
  `src/ test/ foundry-scripts/ lib/`. AGENTS.md rewritten to the Foundry/Plank reality (drop the
  Hardhat "contracts/test/ignition/scripts" description and the hardhat skill pointers).

## 4. CI / build impact
Removing the scaffold changes nothing the gate builds (it's outside `src/`/`test/` Foundry paths and
unreferenced by Makefile/CI). The ONE risk is the `package.json` trim breaking `@cryptoalgebra`
resolution — mitigated by regenerating the lock and verified by the forge gate job (`npm ci
--ignore-scripts` then `forge test --via-ir --offline`). No `.gitmodules`/submodule change. No
`foundry.toml` change (its paths don't reference the removed items).

## 5. Delivery & safety
- Execute in a fresh isolated worktree off clean `origin/develop`; branch `chore/remove-hardhat-scaffold`.
- Archive-tag pre-change `develop` HEAD before merge.
- Verify locally (all before pushing): `git grep -n hardhat` returns only intentional residue;
  `npm install` (regen lock) then **`npm ci --ignore-scripts`** succeeds (Sol-M2); **`bash
  script/check-algebra-ref-pin.sh`** passes (Sol-M1 — it greps the exact `@cryptoalgebra/
  volatility-oracle-plugin` block in `package-lock.json`; the develop-gate does NOT run it, so a
  lock reformat could break `make test` locally while the gate stays green — if it breaks, minimize
  the lock diff or update the script's line-range in the SAME PR); `forge build` / `forge test
  --via-ir --offline` (skip ledger) green; `make compile-plank` green. Merge only on green gate.

## 6. Out of scope / follow-ups owed
- **`.planning/codebase/` maps drift (reviewer RC-M2):** `STRUCTURE.md`/`CONVENTIONS.md`/`STACK.md`/
  `CONCERNS.md` + two phase docs describe `test/Counter.ts` and `.agents/skills/hardhat*` as
  current-state facts; after removal those become stale. These are point-in-time GSD codebase-map
  snapshots (regenerated by map-codebase), possibly co-owned by the plank track — this PR does NOT
  rewrite the GSD tree. Follow-up: refresh the codebase map. Flagged, not fixed here.
- **`notes/VOLATILITY_INSTRUMENTS.md`** — cited by `src/lib/ldf/GeometricDistribution.plk` and
  `src/lib/exposure/PanopticVegaLensLib.plk` but absent on develop (lives on feat/plank/exp). A
  same-named file exists at `spec/notes/VOLATILITY_INSTRUMENTS.md` in the `spec` submodule but may be
  different content (RC-m4) — do NOT assume the follow-up is satisfied by it. Separate fix.
