# cfmm-vol-markets core restructure — design

**Date:** 2026-08-26
**Status:** design; two-reviewer gate PASSED (findings folded in); awaiting user review
**Repo:** `JMSBPP/cfmm-vol-markets` (renamed from `cfmm-replicationPlank`)

## 1. Goal & context

`cfmm-vol-markets` is being repositioned as the **on-chain protocol core** for typed
volatility markets. The Lean/math spec already migrated to `cfmm-vol-markets-spec`, the GAMS
numerical layer to `cfmm-numopt`, and the off-chain RPC/rig layer to `gams-evm-transport`.
This restructure removes the migrated/off-chain bodies still in the repo, replacing two with
**submodule pointers** and deleting the rest.

Delivered as **one gate-verified PR to `develop`**, after a `spec/` content-migration
prerequisite. `develop` is branch-protected with exactly one required check, `gate` (verified),
and the `develop-gate.yml` `gate` job hard-fails unless `approve` succeeded — so the gate is a
real acceptance oracle. The PR merges only on a green gate.

## 2. Scope

### 2.1 Prerequisite (cross-repo, before the PR): migrate `spec/`
`spec/` is the on-chain protocol spec. Full top-level inventory (complete):
`entities/`, `panoptic.md`, `protocol_integrations/`, `COMMUNICATION/`, `model/`,
`01_STATE_DELTA_ELASTICITY_CONTROLLER/`, `REACTIVE_PRICE_CHANGE_ORACLE.md`, `refs/`,
`REQUIREMENTS.md`. It is NOT in `cfmm-vol-markets-spec` yet.

- **Target:** `JMSBPP/cfmm-vol-markets-spec` under a `protocol/` subpath (keeps protocol spec
  distinct from the math/anchor spec at that repo's root).
- **Mechanism:** `git filter-repo` of `spec/` → `protocol/` (history preserved), then land it
  **via a PR to `cfmm-vol-markets-spec`** — its `main` is branch-protected and runs required CI
  (`stack build --pedantic` + `stack test` + `lake build`, ~7 min). A direct push is not viable;
  it must go through that repo's PR/CI. Coordinated with the spec-repo owner (peer
  `migrate-lean4-vol-markets-spec`); old→new commit map attached for traceability.
- **Low-risk confirmation:** that repo's `package.yaml` source-dirs are `src`/`app`/`test` and
  `lake` builds only its lakefile targets, so a `protocol/` tree of Solidity+markdown is NOT
  compiled by stack or lake — the spec-repo CI stays green.
- **Exit criterion:** `cfmm-vol-markets-spec` contains the full `spec/` tree under `protocol/`,
  verified by a path-prefixed tree diff (`spec/` here == `protocol/` there).

### 2.2 The PR → `develop`

**(a) Remove `model/`** — `model/mev_tax_model_one/` + `model/BUILD.md` (GAMS MEV-tax prover),
captured in `cfmm-numopt`. Verified: NO `src/`, `test/*.sol`, or `foundry-scripts/*.sol`
reference root `model/`; the kept on-chain surface (`test/models/mev_tax_model_one`,
`foundry-scripts/mev_tax_model_one`) does not depend on it. The plan re-runs these greps in the
clean clone before deleting.
- **Makefile removals (facts, not conditionals):** `VP_DIR := model/mev_tax_model_one`
  (Makefile:344); `clean-gams` rm of `model/build model/*.lst` (Makefile:342,385);
  `compile-gams` (iterates tracked `*.gms`, all of which live under `model/mev_tax_model_one`, so
  it would hit its own `exit 1` empty-guard after removal); `gams-fixtures` (Makefile:390).
  Remove these targets/lines.

**(b) Remove `tools/gamsdiff` + `test/gamsDiff` + `test/gamsUtils`** — the GAMS↔Solidity
differential-test tooling (off-chain), all self-contained. `test/gamsUtils/` is imported ONLY by
the two `test/gamsDiff/*.diff.t.sol` tests (verified), so it is orphaned by removing gamsDiff —
include it. Coupled removals in the same commit:
- `foundry.toml` `fs_permissions` entry `{ access = "read", path = "./test/gamsDiff/fixtures" }`
  (foundry.toml:30).
- `Makefile` `gams-fixtures` (`uv run --project tools/gamsdiff …`, Makefile:390) — already listed in (a).
- Reverses the earlier lean-cleanup "keep gamsdiff on develop" decision; intentional here.

**(c) `offchain/` → submodule to `gams-evm-transport`**
- **Content check (plan-time, replaces the earlier "confirmed"):** the dir NAMES match
  (`offchain/{app,lib,migrations,rig,spec}` ↔ gams-evm-transport root), but gams-evm-transport
  ALSO has `LICENSE` + `cfmm-replicationPlank-rpc-api.cabal` that `offchain/` lacks — the submodule
  mounts a superset. Run a tree diff (offchain/ ⊆ gams-evm-transport root) before `git rm`.
- **Mechanism:** `git rm -r offchain/`, **then `rm -rf offchain`** (git rm removes only tracked
  files; ignored artifacts like `offchain/rig/rig-manifest.json` (foundry.toml:45) or
  `offchain/app/node_modules` would otherwise make `git submodule add` refuse a non-empty path —
  clean in the pristine clone today, but do the `rm -rf` defensively), then
  `git submodule add https://github.com/JMSBPP/gams-evm-transport.git offchain`.
- **CI-init reality (was a BLOCKER):** the `forge` gate job runs an UNSCOPED
  `git submodule update --init --recursive` (develop-gate.yml:38), which WILL clone `offchain/`
  (and `spec/`) on every run. cfmm-vol-markets-spec is a heavy Lean/Haskell repo — cloning it in
  the 25-min forge job for zero forge benefit is waste. **Fix (part of this PR): scope line 38 to
  `lib/` paths** — matching how the `plank` job already scopes (`git submodule update --init
  --recursive lib/plank-monorepo`). After scoping, `offchain/`/`spec/` stay uninitialized in CI.
- **Skip correctness (was a wrong claim):** with `offchain/` uninitialized, the VolumePath test
  `test/models/mev_tax_model_one/MevTaxVolumePathV4.t.sol` self-skips at its real guards —
  `vm.exists(CONF=offchain/rig/loop-conformance.json)` (line 66), `vm.exists(MANIFEST=
  offchain/rig/rig-manifest.json)` (line 82), the `forkHeight` mismatch (line 73), and the
  live-rig `try/catch` (line 92) — NOT at "absent fixtures" (`volume_path.json` and
  `loop-conformance.json` are both committed/tracked, so those guards pass). This test is NOT on
  the forge `--skip` ledger (develop-gate.yml:59-62), so its guards are load-bearing; the plan
  must verify it lands in `skipped`, not `failure`, with `offchain/` uninitialized. Empty
  submodule dirs do not break `forge build` (offchain/spec are not in `foundry.toml:6`
  `libs=["lib","node_modules"]`) and `fs_permissions` reads on `./offchain/rig` stay valid.

**(d) `spec/` → submodule to `cfmm-vol-markets-spec`** (after 2.1)
- **Build impact: none.** Verified ZERO references to `spec/…` from `src`, `test`,
  `foundry-scripts`, `foundry.toml`, `Makefile`. The `pos_spec` fs_permissions
  (`./src/interfaces/pos_spec`, `./test/pos_spec/fixtures`, foundry.toml:31-32) are under `src/`
  and `test/`, NOT `spec/` — unaffected. So the `protocol/` prefix (submodule root mounts at
  `spec/`, content lives at `spec/protocol/…`) is CI-irrelevant; mirror-at-root is needless.
- **Doc blast radius:** ~38 files under `.planning/` + 1 under `docs/` reference `spec/…` paths.
  The plan enumerates and repoints these to `spec/protocol/…` (docs-only; non-blocking).
- **Mechanism:** `git rm -r spec/`, `rm -rf spec`, `git submodule add … spec` pinned at the 2.1
  migration commit.

### 2.3 `develop-gate.yml` edits (in this PR)
Adding this file to the edit set is REQUIRED (it is the acceptance oracle and it references
deleted paths):
- **Scope the forge submodule init** (line 38) to `lib/` paths so the new submodules aren't
  cloned in CI (see 2.2c).
- **Remove the now-dead `gams` and `gamsdiff` jobs** (their inputs — `model/`, `tools/gamsdiff` —
  are deleted; both are already `if: false`), and drop `gams`/`gamsdiff` from the `gate` job's
  `needs:` list and its result-collector loop. Keep the `gate` job name unchanged (sole required
  check). Net gate jobs after: `approve, forge, plank`.

## 3. Safety rails
- **Archive-tag before delete:** tag `HEAD` on origin as `archive/<name>` before each removal
  (a tag captures the whole tree at that commit, not a single path — so in practice: one tag at
  the pre-restructure HEAD is the recovery point; the migrated content also lives in its target
  repo). `archive/feat-gams-solidity-difftest` and 22 other `archive/*` tags already exist.
- **Gate is the arbiter:** merge only on green `gate`. Red = real break; fix or, if needed,
  recover from the archive tag. Do NOT rely on `git revert -m 1` of the merge: it restores trees
  and drops gitlinks but leaves `.git/modules/{offchain,spec}` cached, snagging re-adds — recover
  via the archive tag / re-clone instead.
- **Fresh clone is the working checkout:** `cfmm-wt/vol-markets` (this clone). The obsolete
  `feat/gams-solidity-difftest` (archived) can be deleted once nothing references it.

## 4. End state (complete boundary)
KEEP: `src/`, `test/` (Plank/Solidity contracts, incl. `test/models/`, `test/pos_spec/`),
`lib/` (deps incl. `cfmm-types`), `foundry-scripts/`, `foundry.toml`, `remappings.txt`,
`Makefile` (GAMS targets removed), `.github/`, `.planning/`, `docs/`, `notes/`, and the TS/HH
surface (`hardhat.config.ts`, `ignition/`, `scripts/`, `contracts/`, `script/` — retained unless
a follow-up says otherwise).
SUBMODULES: `spec/` → cfmm-vol-markets-spec, `offchain/` → gams-evm-transport.
REMOVE: `model/`, `tools/gamsdiff`, `test/gamsDiff`, `test/gamsUtils`, and the dead gams/gamsdiff
gate jobs.
OPEN (decide in plan): the orphaned `cfmm-replicationPlank-rpc-api.cabal` at repo root (37 KB,
duplicated in gams-evm-transport) — remove or keep? Not on-chain; leaning remove.

## 5. Risks & open items
- **Verification must run in the clean clone.** Earlier greps in the orphaned worktree returned
  false-empty (its `.git` was broken — §6). Every reference check re-runs here with
  `env -u GIT_DIR -u GIT_WORK_TREE`.
- **spec/ migration gates the whole PR** and needs the spec-repo owner + that repo's PR/CI.
- **Single-PR blast radius (5 changes).** Mitigated by gate + archive tag. NOTE: the gate runs
  `on: pull_request` (validates only the PR head), so intra-PR commit staging gives a *local*
  bisect, not a gate-backed one.
- **Pre-existing dangling remappings** (`remappings.txt:37-39`: `shizo/`, `unistrata/`,
  `reactive-lib/` → absent `lib/` paths) resolve lazily and are green today; the plan explicitly
  re-confirms the gate is green rather than assuming, and does not touch them (out of scope).
- **offchain/ coverage:** after scoping line 38, rig/contract tests self-skip in CI (as today);
  accepted and logged.

## 6. Provenance note
Authored in a fresh clone at `cfmms-playground/cfmm-wt/vol-markets` after the prior local main
checkout (`cfmm-replicationPlank/`) was removed by an external workspace change on 2026-08-26
(all work was safe on origin: 5 branches + 22 `archive/*` tags). The orphaned `cfmm-wt/*`
worktrees are unrelated to this design and out of scope. Two-reviewer gate (Reality Checker +
DevOps Automator) run 2026-08-26; B1 (unscoped submodule init), the skip-mechanism correction,
the spec-repo-PR requirement, the `rm -rf` gotcha, `test/gamsUtils`, and the `develop-gate.yml`
edit set are all folded in above.
