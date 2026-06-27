# Design: Compile-gate GitHub Action (GAMS + Plank + Forge)

**Date:** 2026-06-27
**Topic:** The repo's first GitHub Actions workflow — runs the GAMS, Plank, and Forge compile gates on push with a baseline-count policy
**Scope track:** GitHub CI workflows / version control (see memory `session-scope-ci-version-control`)
**Status:** ⛔ BLOCKED — pending repository reproducibility (see "Blocking prerequisite" below). YAML mechanics reviewed sound across two two-step passes; the gate cannot be calibrated until the repo builds from a clean clone. Gate mechanism decided: **per-file allowlist** (not count baseline).

## Blocking prerequisite (decided 2026-06-27): make the repo CI-reproducible first

Two review passes proved the repository does **not** build from a clean checkout, so no gate
can be calibrated yet. Resolve these version-control gaps before resuming this CI work:

1. **Untracked, non-submodule lib deps** — `lib/v4-core`, `lib/unistrata`, `lib/shizo`,
   `lib/mochi-yield` exist only in the local working tree (absent from `.gitmodules`, not
   tracked). `remappings.txt` routes `@openzeppelin/`, `ds-test/`, `openzeppelin-contracts/`,
   `hookmate/`, `shizo/`, `mochi-yield/`, `reactive-lib/` through them — so a fresh clone
   cannot resolve imports and `forge build --via-ir` fails in CI. **Handed to Phase 1
   (2026-06-27)** — too large for a CI-slice. Detail for whoever resolves it:
   - All four are **loose files with no top-level `.git`** → no recoverable origin URL or
     pinned commit; submodule registration needs the exact upstream repo+commit supplied.
   - `lib/v4-core` = **27M**, has 3 *nested* `.git` dirs (its own sub-deps), no `node_modules`
     (so the `@ensdomains/`/`hardhat/` `node_modules` remappings are dead — not in the compile
     closure). Clearly `Uniswap/v4-core` but at an unknown pin.
   - `lib/unistrata` 568K (hint `Uniswap/v4-template`), `lib/shizo` 376K (hint
     `uniswapfoundation/v4-template`), `lib/mochi-yield` 348K (hint `karar189/mochitrade`) —
     origins ambiguous (the hints are forked-from templates, not necessarily the real repos).
   - Resolution = register as submodules (needs origins+commits) **or** vendor+commit
     (strip v4-core's nested `.git`, ~28M repo growth). Owner's call.
2. **Dirty tracked submodules** — `lib/plankified-univ3` (and others) are locally modified;
   CI checks out the pinned SHA, not the working-tree contents the baselines were measured
   against. Commit/pin a coherent state.
3. **Uncommitted model fixes** — `model/PricingKernel.gms` is modified and `model/exp/` is
   untracked (peer GAMS agent's in-flight work); committed `HEAD` and the working tree
   disagree (`HEAD` gams = 1 fail; working tree = 0). Baselines must come from a committed SHA.

This is Phase 1 "Repository Restructure & Sanitize" / version-control territory and overlaps
concurrent work by the user (GSD Phase 1) and a peer GAMS agent — coordinate ownership before
acting.

## Resume conditions

When the repo builds from a clean `git clone … && git submodule update --init --recursive`:
- Re-measure all three baselines from that clean checkout at a named commit SHA.
- Implement the gate as a **per-file allowlist** (job reds if any file outside the named
  known-failing set breaks — catches fix-one/break-one substitutions a count gate misses).
- Apply the deferred review fixes: drop `paths-ignore` on `pull_request` (or use a sentinel)
  to avoid the required-checks deadlock; pin the plank compiler binary (not just the
  installer script); note the GAMS-cache EULA concern; harden the parse block
  (`failed=${failed:-999}`).

## Overview

This adds the repository's **first** CI workflow: three independent jobs that compile-gate
the three build tracks on every push.

- **`compile-gams`** — `make compile-gams`: compile-checks every `.gms` under `model/` with
  GAMS `action=c` (compile/syntax only; no `Model`/`Solve` exists, so no license/solver).
- **`compile-plank`** — `make compile-plank`: auto-discovers `.plk` entrypoints (files with an
  `init` block) under `src/`+`test/`, compiles each with `plank build … --backend sona`.
- **`forge`** — `forge build --via-ir`: compiles the Solidity/Foundry tree.

> **Repository context (changed mid-design):** A prior GitHub Actions workflow
> (`.github/workflows/test.yml`, Foundry) existed earlier but was **intentionally removed**
> during the roadmap's Phase 1 "Repository Restructure & Sanitize" (REPO-05: "the broken CI
> is fixed or explicitly disabled"). As of this writing `.github/` does not exist. Therefore
> this workflow is the repo's first CI and replaces nothing. This spec was corrected from an
> earlier draft that wrongly assumed `test.yml` still existed.

## Ground truth (measured 2026-06-27, locally)

Each gate's current failure count is the **baseline** (see gating policy):

| Gate | Command | Result | Baseline failures |
|---|---|---|---|
| gams | `make compile-gams` | 3 ok, **3 failed** (`dynamic/InitState`, `LiquidityKernel`, `PricingKernel`) | **3** |
| plank | `make compile-plank` | 4 ok, **2 failed** (`DynamicCFMM`, `ReferenceMarket`) | **2** |
| forge | `forge build --via-ir` | exit 0 (**clean**) | **0** |

Notes: `forge build` *without* `--via-ir` fails (`test/Utils.t.sol` needs the IR pipeline);
`--via-ir` is required and matches the Makefile's forge targets. `src/` currently has no
`.sol` files (Counter scaffold removed in Phase 1). Toolchain: `plank v0.1.1`, GAMS `54.1.0`,
`forge 1.5.1`.

## Decisions (from brainstorming)

1. **Targets:** three jobs — gams, plank, forge — independent and parallel.
2. **Gating policy: baseline-count gate.** A gate is GREEN while its failure count stays at or
   below the recorded baseline (gams ≤ 3, plank ≤ 2, forge ≤ 0). It reds **only when a new
   break raises the count**. This accepts current WIP while preserving regression signal
   (chosen over plain "start red", which hides new regressions among accepted ones).
3. **GAMS in CI:** install the full GAMS distribution running in demo/community mode (no
   license file); `action=c` consumes no license. No GitHub secret.
4. **Gate logic lives in the workflow YAML, not the Makefile** — keeps this change isolated to
   `.github/` (the Makefile is under concurrent Phase 1 edits; do not touch it).

## Workflow design

**File:** `.github/workflows/compile-gates.yml` (new — the only file this change adds besides docs).

**Triggers:**
```yaml
on:
  push:
    branches: [main, master]
    paths-ignore: ['docs/**', '.planning/**', 'refs/**', 'spec/**', '**/*.md']
  pull_request:
    paths-ignore: ['docs/**', '.planning/**', 'refs/**', 'spec/**', '**/*.md']
  workflow_dispatch:
```
Rationale: `push` scoped to the integration branches + `pull_request` for feature branches
avoids the same-repo double-run; `paths-ignore` skips the heavy toolchain installs on
docs/planning-only commits. (Per-job path filtering — gams↔`model/`, plank↔`src/test`, 
forge↔`lib/foundry.toml` — is a later optimization, not v1.)

**Top-level:**
```yaml
permissions: { contents: read }
concurrency:
  group: compile-gates-${{ github.ref }}
  cancel-in-progress: true
```

**Infra-vs-compile separation (applies to every job).** Each job has a **setup phase that
MUST succeed** and a **compile phase that is baseline-gated**. This is what makes a red
meaningful: a toolchain-install failure is a *different* failed step than an over-baseline
compile failure.
- Setup ends with a hard gate: `command -v gams` / `command -v plank` / `command -v forge`
  (fail the job loudly if the tool is not on PATH).
- The compile step runs the gate, captures output, and applies the baseline comparison:
  ```bash
  set -o pipefail
  make compile-gams | tee gate.log || true
  line=$(grep -oE 'compile-gams: [0-9]+ ok, [0-9]+ failed' gate.log || true)
  test -n "$line" || { echo "::error::compile-gams summary missing — the gate did not run (setup/tooling failure)"; exit 1; }
  failed=$(echo "$line" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+')
  echo "### compile-gams: $line (baseline $GAMS_BASELINE)" >> "$GITHUB_STEP_SUMMARY"
  test "$failed" -le "$GAMS_BASELINE"
  ```
  The **missing-summary check** distinguishes "the gate ran and WIP is within baseline" from
  "the toolchain/build failed before the gate ran" — resolving the review's infra-vs-compile
  conflation. Baselines are workflow `env`: `GAMS_BASELINE: "3"`, `PLANK_BASELINE: "2"`.
  Forge is binary (`forge build --via-ir` passes/fails); its gate is "must pass" (baseline 0).

### Job `compile-gams`
- `actions/checkout@v4` (`persist-credentials: false`). No submodules.
- Restore cache of the GAMS install dir, key `gams-${{ runner.os }}-x64-54.1.0-<installer-sha256-prefix>`.
- If cache miss: download the pinned GAMS 54.1.0 `linux_x64_64_sfx` installer, **verify
  `sha256sum -c`**, run unattended, add to `PATH`. (See risk 1.)
- Setup gate: `command -v gams`.
- Compile step: baseline-gated `make compile-gams` (baseline 3) with the missing-summary guard.

### Job `compile-plank`
- `actions/checkout@v4` (`persist-credentials: false`), then targeted **non-shallow**
  `git submodule update --init lib/plankified-univ3` (no `--depth 1`: the superproject pins a
  SHA that may not be the remote branch tip, which a shallow fetch cannot retrieve).
- Install plank: **download a pinned plank release artifact and checksum it** (preferred over
  `curl -L install.plankevm.org | bash`, an unpinned pipe-to-shell). If only the installer
  path works headlessly, download it to a file, checksum/pin, then run. Record `plank --version`.
- Cache `~/.plank` keyed on the **resolved** `plank --version` output (not an assumed pin).
- Setup gate: `command -v plank`.
- Compile step: baseline-gated `make compile-plank` (baseline 2) with the missing-summary guard.

### Job `forge`
- `actions/checkout@v4` with **recursive submodules** (the Solidity test tree imports across
  several `lib/*` submodules — bunni-v2, etc.; forge needs them all).
- `foundry-rs/foundry-toolchain@v1` (pin forge to `1.5.1` if the action supports it).
- Setup gate: `command -v forge`.
- Compile step: `forge build --via-ir` — must pass (baseline 0).

## Implementation risks to verify (flagged honestly — not assumed)

1. **GAMS installer URL + headless install + license.** GAMS has no apt package and no
   official setup-action; it ships a self-extracting installer via a CloudFront CDN. Must
   confirm: the pinned 54.1.0 `linux_x64_64_sfx` URL resolves, installs non-interactively
   (no EULA prompt), and that the distribution running with **no license file** permits
   `action=c`. **Assumption, not yet proven on the CDN package:** local no-license evidence is
   from a full `/usr/gams/...` install, not the CDN download. **Fallback** if the demo mode
   does not cover compile in a clean runner: full install + license via GitHub secret (the
   approach this spec otherwise supersedes). Pin URL **and** sha256.
2. **plank install headless + pinning.** Confirm a pinned plank `v0.1.1` release artifact is
   downloadable, or that `plankup` honors a version flag/`.plank-version` non-interactively. If
   only "latest" is installable, record the resolved version and note bytecode reproducibility
   is not yet pinned (a separate TOOL-01 concern). Pipe-to-shell must be replaced or checksum-pinned.
3. **forge submodule weight.** Recursive checkout of ~8 submodules is heavy; confirm CI minutes
   are acceptable, or later scope forge to only the submodules its imports need.

## Out of scope (explicit)

- **No Makefile edits** — the baseline gate lives in YAML; the Makefile is under concurrent
  Phase 1 edits.
- **No fixing of the failing `.gms`/`.plk` files** — owned by the GAMS-model track / peer agent;
  CI accepts them at baseline.
- **No branch-protection / required-check config** — a repo-settings decision for later.
- **No GAMS license/solve job** — compile-only.

## Success criteria (what must be TRUE)

1. `.github/workflows/compile-gates.yml` exists with three jobs `compile-gams`, `compile-plank`,
   `forge`, no `needs` between them, triggered on scoped `push` + `pull_request` + `workflow_dispatch`.
2. Each job separates a **setup phase that must succeed** (tool-on-PATH gate) from a
   **compile phase**; a missing gate-summary line fails the job with a distinct error
   (toolchain failure ≠ over-baseline failure).
3. `compile-gams` is green iff its failed count ≤ 3; `compile-plank` green iff ≤ 2; `forge`
   green iff `forge build --via-ir` exits 0. A NEW break (count above baseline) reds the job.
4. The workflow references **no** secrets and grants only `contents: read`; it sets a
   `concurrency` group with `cancel-in-progress`.
5. GAMS and plank installers are checksum-pinned (or pinned release artifacts); actions are
   pinned to a verified major/SHA.
6. The workflow YAML passes `actionlint`.

## Verification

- `actionlint .github/workflows/compile-gates.yml` → clean (run as a real step/check, not "if available").
- A pushed run shows three parallel jobs. With today's baselines, **all three are GREEN**
  (gams 3≤3, plank 2≤2, forge passes) — the gate proves itself by being green at baseline and
  red only when a job's `$GITHUB_STEP_SUMMARY` shows a count above baseline.
- Deliberately introduce a 4th gams failure locally (e.g. a syntax error in a currently-ok
  `.gms`) and confirm the baseline math would red the job (count 4 > 3) — design-level check,
  not committed.
- `git diff` shows only the new workflow file (+ these docs); nothing under `model/`, the
  `Makefile`, or other tracked code changes.
