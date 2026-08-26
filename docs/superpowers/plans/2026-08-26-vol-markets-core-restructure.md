# cfmm-vol-markets Core Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slim `cfmm-vol-markets` to the on-chain protocol core — remove the migrated GAMS body and gamsdiff tooling, and convert `offchain/` and `spec/` to submodule pointers — in one gate-verified PR to `develop`, after a `spec/` content migration.

**Architecture:** A cross-repo prerequisite (migrate `spec/` → `cfmm-vol-markets-spec/protocol/` via PR) then a single feature branch `chore/vol-markets-core-restructure` off `develop` carrying five coupled changes, merged only when the `develop` gate (`approve` + `forge` + `plank`) is green.

**Tech Stack:** git submodules, GitHub Actions (`develop-gate.yml`, self-hosted `forge`/`plank` jobs), Foundry (`forge`), Plank (`make compile-plank`), `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-08-26-vol-markets-core-restructure-design.md`

## Global Constraints

- **git env is broken:** `GIT_DIR`/`GIT_WORK_TREE` are empty strings in this environment. Prefix **every** git command with `env -u GIT_DIR -u GIT_WORK_TREE` and run from inside the clone. (Verify once: `env -u GIT_DIR -u GIT_WORK_TREE git -C /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets rev-parse --abbrev-ref HEAD` → `chore/vol-markets-core-restructure`.)
- **Working checkout:** `/home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets`, branch `chore/vol-markets-core-restructure` (off `develop`). NOT the orphaned `cfmm-wt/*` worktrees.
- **Classifier may block bulk `git rm`/`rm -rf`.** If a destructive shell command is denied by the auto-mode classifier, hand the exact command to the user to run with the `!` prefix; do not work around the denial.
- **Archive before delete:** push `archive/pre-restructure` = pre-change HEAD to origin before any removal (single tag captures the whole tree; migrated content also lives in its target repo).
- **Gate is the acceptance oracle.** Keep the `gate` job name unchanged (sole required branch-protection check on `develop`). The PR merges only on a green gate; a red gate is a real break — fix or recover from the archive tag, never force-merge.
- **All four repos are public:** `cfmm-vol-markets`, `cfmm-vol-markets-spec`, `gams-evm-transport`, `cfmm-numopt`.

---

### Task 0: Prerequisite — migrate `spec/` into `cfmm-vol-markets-spec/protocol/` (cross-repo)

**Files:** cross-repo; produces a commit SHA in `JMSBPP/cfmm-vol-markets-spec` (branch `main`).

**Interfaces:**
- Produces: `SPEC_SUBMODULE_SHA` — the `cfmm-vol-markets-spec` `main` commit after the protocol tree lands (consumed by Task 6, spec/ submodule pin).

- [ ] **Step 1: Coordinate with the spec-repo owner.** SendMessage peer `migrate-lean4-vol-markets-spec`: state that `spec/` (full inventory: `entities/`, `panoptic.md`, `protocol_integrations/`, `COMMUNICATION/`, `model/`, `01_STATE_DELTA_ELASTICITY_CONTROLLER/`, `REACTIVE_PRICE_CHANGE_ORACLE.md`, `refs/`, `REQUIREMENTS.md`) will be migrated into `cfmm-vol-markets-spec` under `protocol/` via `git filter-repo` + PR. Wait for acknowledgement.

- [ ] **Step 2: Filter-repo `spec/` → `protocol/` in a scratch clone.**

```bash
cd /tmp/claude-1000
env -u GIT_DIR -u GIT_WORK_TREE git clone https://github.com/JMSBPP/cfmm-vol-markets.git spec-migrate
cd spec-migrate
env -u GIT_DIR -u GIT_WORK_TREE git checkout develop
env -u GIT_DIR -u GIT_WORK_TREE git filter-repo --path spec/ --path-rename spec/:protocol/ --force
```
Expected: history rewritten to contain only `protocol/…` (was `spec/…`).

- [ ] **Step 3: Land it in cfmm-vol-markets-spec via a PR (protected `main` + required CI).**

```bash
cd /tmp/claude-1000
env -u GIT_DIR -u GIT_WORK_TREE git clone https://github.com/JMSBPP/cfmm-vol-markets-spec.git spec-target
cd spec-target
env -u GIT_DIR -u GIT_WORK_TREE git checkout -b chore/import-protocol-spec
env -u GIT_DIR -u GIT_WORK_TREE git remote add plank ../spec-migrate
env -u GIT_DIR -u GIT_WORK_TREE git fetch plank
env -u GIT_DIR -u GIT_WORK_TREE git merge --allow-unrelated-histories --no-ff plank/develop -m "chore: import cfmm-vol-markets protocol spec under protocol/"
env -u GIT_DIR -u GIT_WORK_TREE git push -u origin chore/import-protocol-spec
gh pr create --repo JMSBPP/cfmm-vol-markets-spec --base main --head chore/import-protocol-spec --title "chore: import protocol spec under protocol/" --body "Migrated from cfmm-vol-markets spec/ via filter-repo (history preserved). protocol/ is markdown/Solidity; stack/lake do not compile it (package.yaml src-dirs = src/app/test)."
```

- [ ] **Step 4: Verify the spec-repo CI is green, then merge the PR.**

Run: `gh pr checks <PR#> --repo JMSBPP/cfmm-vol-markets-spec --watch`
Expected: `stack build`/`stack test`/`lake build` all pass (they ignore `protocol/`). Then `gh pr merge <PR#> --repo JMSBPP/cfmm-vol-markets-spec --merge`.

- [ ] **Step 5: Capture the pin + verify tree parity.**

```bash
SPEC_SUBMODULE_SHA=$(gh api repos/JMSBPP/cfmm-vol-markets-spec/commits/main --jq .sha)
echo "$SPEC_SUBMODULE_SHA"   # record for Task 6
# parity: every spec/ path here must exist as protocol/<same> there
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
comm -23 \
  <(env -u GIT_DIR -u GIT_WORK_TREE git ls-tree -r --name-only develop -- spec | sed 's#^spec/#protocol/#' | sort) \
  <(gh api "repos/JMSBPP/cfmm-vol-markets-spec/git/trees/$SPEC_SUBMODULE_SHA?recursive=1" --jq '.tree[].path' | sort)
```
Expected: empty output (every `spec/` file present as `protocol/…` in the target).

---

### Task 1: Remove `model/` (GAMS prover) + its Makefile targets

**Files:**
- Delete: `model/mev_tax_model_one/`, `model/BUILD.md`
- Modify: `Makefile` (remove `VP_DIR`, `compile-gams`, `test-gams`, `clean-gams`, `gams-fixtures` targets/vars)

**Interfaces:**
- Consumes: nothing. Produces: nothing (later tasks independent).

- [ ] **Step 1: Verify no on-chain code references root `model/` (pre-flight, in the clean clone).**

Run:
```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/vol-markets
env -u GIT_DIR -u GIT_WORK_TREE git grep -nI -e 'model/mev_tax' -e '(^|[^s])model/' -- 'src' 'test/**/*.sol' 'foundry-scripts' 'foundry.toml' | grep -v 'test/models/'
```
Expected: only `Makefile` and `test/gamsDiff/*` hits (the latter removed in Task 2); NO `src`/`test/*.sol`/`foundry-scripts`/`foundry.toml` hit referencing root `model/`. If anything else appears, STOP and reassess.

- [ ] **Step 2: Archive the pre-restructure HEAD (once, guards all tasks).**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git push origin refs/heads/chore/vol-markets-core-restructure:refs/tags/archive/pre-restructure
```
Expected: `[new tag] … archive/pre-restructure`.

- [ ] **Step 3: Remove `model/`.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git rm -r model/
```
(If classifier-blocked, hand to user via `!`.) Expected: `model/mev_tax_model_one/*` + `model/BUILD.md` staged for deletion.

- [ ] **Step 4: Remove the GAMS Makefile targets.** Edit `Makefile`: delete `VP_DIR := model/mev_tax_model_one` (line ~344) and the `compile-gams`, `test-gams`, `clean-gams`, `gams-fixtures` targets (they reference `model/` and `tools/gamsdiff`). Leave all `plank`/`forge`/`compile-plank` targets intact.

- [ ] **Step 5: Verify the Makefile still parses and no dangling model/ refs remain.**

Run: `make -n compile-plank >/dev/null && echo PARSE_OK` and `grep -nE 'model/|compile-gams|gams-fixtures' Makefile || echo NO_MODEL_REFS`
Expected: `PARSE_OK` and `NO_MODEL_REFS`.

- [ ] **Step 6: Commit.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git add -A
env -u GIT_DIR -u GIT_WORK_TREE git commit -m "chore(restructure): remove model/ GAMS prover (now in cfmm-numopt) + Makefile GAMS targets"
```

---

### Task 2: Remove `tools/gamsdiff` + `test/gamsDiff` + `test/gamsUtils` + foundry.toml entry

**Files:**
- Delete: `tools/gamsdiff/`, `test/gamsDiff/`, `test/gamsUtils/`
- Modify: `foundry.toml` (remove `{ access = "read", path = "./test/gamsDiff/fixtures" }`)

**Interfaces:** Consumes/Produces: none.

- [ ] **Step 1: Verify `test/gamsUtils` is imported ONLY by `test/gamsDiff` (so removal orphans nothing kept).**

Run: `env -u GIT_DIR -u GIT_WORK_TREE git grep -lI 'gamsUtils' -- 'test/**/*.sol' | grep -v 'test/gamsDiff/'`
Expected: empty (no kept test imports gamsUtils).

- [ ] **Step 2: Remove the three paths.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git rm -r tools/gamsdiff test/gamsDiff test/gamsUtils
```
(If classifier-blocked, hand to user via `!`.)

- [ ] **Step 3: Remove the foundry.toml fs_permissions entry.** Edit `foundry.toml`: delete the line `{ access = "read", path = "./test/gamsDiff/fixtures" },` from `fs_permissions`.

- [ ] **Step 4: Verify no dangling gamsdiff/gamsUtils references remain.**

Run: `env -u GIT_DIR -u GIT_WORK_TREE git grep -nI -e 'gamsdiff' -e 'gamsDiff' -e 'gamsUtils' -- ':!docs' ':!.planning' || echo CLEAN`
Expected: `CLEAN` (only historical docs/.planning may still mention it; those are left as history).

- [ ] **Step 5: Commit.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git add -A
env -u GIT_DIR -u GIT_WORK_TREE git commit -m "chore(restructure): remove GAMS<->Solidity diff tooling (tools/gamsdiff, test/gamsDiff, test/gamsUtils)"
```

---

### Task 3: Fix `develop-gate.yml` — scope submodule init + drop dead gams/gamsdiff jobs

**Files:** Modify `.github/workflows/develop-gate.yml`

**Interfaces:** Produces the workflow the PR's own gate run executes (Task 6 depends on it being green).

- [ ] **Step 1: Scope the forge job's recursive submodule init to `lib/`.** In `.github/workflows/develop-gate.yml`, the `forge` job step (line ~38) currently ends with `git submodule update --init --recursive`. Change that line to restrict it so the new `offchain`/`spec` submodules are NOT cloned in CI:

```yaml
          git submodule update --init lib/panoptic-v2-core
          git -C lib/panoptic-v2-core config submodule.lib/panoptic-helper.update none
          git submodule update --init --recursive -- lib/
```
(The `-- lib/` pathspec limits recursion to `lib/*`, matching the `plank` job's scoped init.)

- [ ] **Step 2: Remove the dead `gams` and `gamsdiff` jobs.** Delete both job blocks (they run `make compile-gams` / `cd tools/gamsdiff && … pytest` — inputs now gone; both were `if: false`).

- [ ] **Step 3: Drop `gams`/`gamsdiff` from the gate collector.** In the `gate` job, change `needs: [approve, forge, gams, plank, gamsdiff]` → `needs: [approve, forge, plank]`, and remove `'${{ needs.gams.result }}'` and `'${{ needs.gamsdiff.result }}'` from the result-collector `for` loop. **Do NOT rename the `gate` job.**

- [ ] **Step 4: Verify the workflow parses.**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/develop-gate.yml')); print('YAML_OK')"` (and `actionlint .github/workflows/develop-gate.yml` if available).
Expected: `YAML_OK`; `gate` job present with `needs: [approve, forge, plank]`; no `gams`/`gamsdiff` references.

- [ ] **Step 5: Commit.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git add .github/workflows/develop-gate.yml
env -u GIT_DIR -u GIT_WORK_TREE git commit -m "ci(restructure): scope forge submodule init to lib/; drop dead gams/gamsdiff jobs"
```

---

### Task 4: Convert `offchain/` → submodule to `gams-evm-transport`

**Files:**
- Delete then re-add: `offchain/` (tracked dir → submodule)
- Modify: `.gitmodules` (new entry, created by `git submodule add`)

**Interfaces:** Consumes: Task 3's scoped init (so offchain isn't cloned in the gate). Produces: `offchain/` gitlink.

- [ ] **Step 1: Tree-diff `offchain/` ⊆ gams-evm-transport root (content parity before delete).**

```bash
comm -23 \
  <(env -u GIT_DIR -u GIT_WORK_TREE git ls-tree -r --name-only HEAD -- offchain | sed 's#^offchain/##' | sort) \
  <(gh api "repos/JMSBPP/gams-evm-transport/git/trees/main?recursive=1" --jq '.tree[].path' | sort)
```
Expected: empty (every `offchain/` file exists at gams-evm-transport root). If not empty, STOP — content isn't fully captured.

- [ ] **Step 2: Remove `offchain/` (tracked + on-disk).**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git rm -r offchain/
rm -rf offchain
```
(If `git rm` is classifier-blocked, hand to user via `!`. The `rm -rf` is required so the next step's `submodule add` doesn't hit a non-empty path.)

- [ ] **Step 3: Add `offchain/` as a submodule.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git submodule add https://github.com/JMSBPP/gams-evm-transport.git offchain
```
Expected: `.gitmodules` gains `submodule "offchain"`; `offchain` gitlink staged.

- [ ] **Step 4: Verify forge build is unaffected + the VolumePath test self-skips with offchain uninit.**

Run:
```bash
# simulate CI: deinit offchain so it's empty, then confirm the test skips (not fails)
env -u GIT_DIR -u GIT_WORK_TREE git submodule deinit -f offchain
forge build --via-ir --offline 2>&1 | tail -3
forge test --via-ir --offline --match-path 'test/models/mev_tax_model_one/MevTaxVolumePathV4.t.sol' -vv 2>&1 | tail -15
env -u GIT_DIR -u GIT_WORK_TREE git submodule update --init offchain   # restore locally
```
Expected: `forge build` succeeds (offchain not in `libs`); the VolumePath test reports `[SKIP]`/0 failing (guarded by `vm.exists(offchain/rig/loop-conformance.json)` line ~66, `vm.exists(offchain/rig/rig-manifest.json)` line ~82, forkHeight line ~73, live-rig try/catch line ~92), NOT a failure.

- [ ] **Step 5: Commit.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git add .gitmodules offchain
env -u GIT_DIR -u GIT_WORK_TREE git commit -m "chore(restructure): offchain/ -> submodule (JMSBPP/gams-evm-transport)"
```

---

### Task 5: Convert `spec/` → submodule to `cfmm-vol-markets-spec` + repoint doc refs

**Files:**
- Delete then re-add: `spec/` (tracked dir → submodule at `SPEC_SUBMODULE_SHA` from Task 0)
- Modify: `.gitmodules`; ~38 `.planning/**` files + 1 `docs/**` file (repoint `spec/…` → `spec/protocol/…`)

**Interfaces:** Consumes: `SPEC_SUBMODULE_SHA` (Task 0).

- [ ] **Step 1: Confirm no build refs to `spec/` (only docs).**

Run: `env -u GIT_DIR -u GIT_WORK_TREE git grep -lI -E 'spec/(entities|panoptic|protocol_integrations|COMMUNICATION|model|refs|REQUIREMENTS|01_STATE)' -- 'src' 'test' 'foundry-scripts' 'foundry.toml' 'Makefile' || echo NO_BUILD_REFS`
Expected: `NO_BUILD_REFS`.

- [ ] **Step 2: Remove `spec/` (tracked + on-disk) and add the submodule pinned at the migration commit.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git rm -r spec/
rm -rf spec
env -u GIT_DIR -u GIT_WORK_TREE git submodule add https://github.com/JMSBPP/cfmm-vol-markets-spec.git spec
env -u GIT_DIR -u GIT_WORK_TREE bash -c 'cd spec && git checkout <SPEC_SUBMODULE_SHA>'
env -u GIT_DIR -u GIT_WORK_TREE git add spec
```
(Replace `<SPEC_SUBMODULE_SHA>` with Task 0's value. If `git rm` blocked, hand to user via `!`.)

- [ ] **Step 3: Repoint doc references `spec/…` → `spec/protocol/…`.**

```bash
# list them first
env -u GIT_DIR -u GIT_WORK_TREE git grep -lI -E '\bspec/(entities|panoptic|protocol_integrations|COMMUNICATION|model|refs|REQUIREMENTS|01_STATE)' -- '.planning' 'docs'
# then edit each with sed (review the diff before committing)
env -u GIT_DIR -u GIT_WORK_TREE git grep -lI -E '\bspec/(entities|panoptic|protocol_integrations|COMMUNICATION|model|refs|REQUIREMENTS|01_STATE)' -- '.planning' 'docs' \
  | xargs sed -i -E 's#\bspec/(entities|panoptic|protocol_integrations|COMMUNICATION|model|refs|REQUIREMENTS|01_STATE)#spec/protocol/\1#g'
```
Expected: ~38 `.planning` files + 1 `docs` file updated. (If `sed -i` is blocked, hand the one-liner to the user via `!`.)

- [ ] **Step 4: Verify repoint complete.**

Run: `env -u GIT_DIR -u GIT_WORK_TREE git grep -nI -E '\bspec/(entities|panoptic|protocol_integrations|COMMUNICATION|model|refs|REQUIREMENTS|01_STATE)' -- '.planning' 'docs' | grep -v 'spec/protocol/' || echo ALL_REPOINTED`
Expected: `ALL_REPOINTED`.

- [ ] **Step 5: Commit.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git add -A
env -u GIT_DIR -u GIT_WORK_TREE git commit -m "chore(restructure): spec/ -> submodule (cfmm-vol-markets-spec, protocol/ subpath); repoint doc refs"
```

---

### Task 6: Open the PR, verify the gate, merge

**Files:** none (git/PR operations).

**Interfaces:** Consumes: all prior tasks committed on `chore/vol-markets-core-restructure`.

- [ ] **Step 1: Push the branch.**

```bash
env -u GIT_DIR -u GIT_WORK_TREE git push -u origin chore/vol-markets-core-restructure
```

- [ ] **Step 2: Pre-flight the develop gate is currently green** (so a red is ours, not pre-existing), and hold the self-hosted runner awake (`systemd-inhibit`; forge job timeout 25 min). Confirm the latest `develop` gate run / merged PR was green.

- [ ] **Step 3: Open the PR → develop.**

```bash
gh pr create --repo JMSBPP/cfmm-vol-markets --base develop --head chore/vol-markets-core-restructure \
  --title "chore(restructure): slim to on-chain core (submodule offchain/spec, drop model/gamsdiff)" \
  --body "Implements docs/superpowers/specs/2026-08-26-vol-markets-core-restructure-design.md. offchain/ + spec/ -> submodules; model/ + gamsdiff removed; gate forge init scoped to lib/, dead gams/gamsdiff jobs dropped. Recovery: archive/pre-restructure + archive/* tags."
```

- [ ] **Step 4: Watch the gate; it must be green.**

Run: `gh pr checks <PR#> --repo JMSBPP/cfmm-vol-markets --watch`
Expected: `gate` = success (approve+forge+plank all success/skipped). The forge job must NOT clone offchain/spec (init scoped to lib/); the VolumePath test must be `[SKIP]`. If red: diagnose from the job log, fix on the branch, do not force-merge.

- [ ] **Step 5: Merge.**

```bash
gh pr merge <PR#> --repo JMSBPP/cfmm-vol-markets --merge
```
Expected: merged to develop; restructure complete.

- [ ] **Step 6: Post-merge sanity.**

Run: `env -u GIT_DIR -u GIT_WORK_TREE git ls-tree develop -- model spec offchain tools/gamsdiff` (after `git fetch origin develop`).
Expected: `model` and `tools/gamsdiff` absent; `spec` and `offchain` show as `commit` (gitlink) entries.

---

## Self-Review

- **Spec coverage:** §2.1 → Task 0; §2.2a → Task 1; §2.2b → Task 2; §2.3 → Task 3; §2.2c → Task 4; §2.2d → Task 5; §3/§5 gate verification → Task 6. All spec sections mapped.
- **Placeholders:** `<SPEC_SUBMODULE_SHA>` (Task 5) and `<PR#>` are intentional runtime values produced by Task 0 / Task 6 Step 3 — documented in the Interfaces blocks, not TBDs.
- **Type/name consistency:** `archive/pre-restructure` tag created Task 1 Step 2, referenced in Task 6 body; `SPEC_SUBMODULE_SHA` produced Task 0, consumed Task 5; `gate` job name preserved throughout.
- **Ordering:** Task 0 (cross-repo) must complete before Task 5; Task 3 (scoped init) before Task 4/6 so the gate doesn't clone the new submodules. Tasks 1–3 are independent and may run in any order on the branch.
