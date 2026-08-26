# cfmm-vol-markets core restructure — design

**Date:** 2026-08-26
**Status:** design; awaiting two-reviewer gate + user review
**Repo:** `JMSBPP/cfmm-vol-markets` (renamed from `cfmm-replicationPlank`)

## 1. Goal & context

`cfmm-vol-markets` is being repositioned as the **on-chain protocol core** for typed
volatility markets. The Lean/math spec already migrated to `cfmm-vol-markets-spec`, the GAMS
numerical layer to `cfmm-numopt`, and the off-chain RPC/rig layer to `gams-evm-transport`.
This restructure removes the migrated/off-chain bodies still sitting in the repo, replacing
two of them with **submodule pointers** to their now-canonical homes and deleting the rest,
so the repo is just: Plank/Solidity contracts (`src/`, `test/`), their deps (`lib/`, incl.
`cfmm-types`), deploy scripts (`foundry-scripts/`), and submodule references to the spec and
off-chain repos.

Delivered as **one gate-verified PR to `develop`**, after a `spec/` content-migration
prerequisite. The `develop` gate (forge + plank jobs) is the acceptance oracle: the PR merges
only if the gate is green.

## 2. Scope

### 2.1 Prerequisite (cross-repo, before the PR): migrate `spec/`
`spec/` is the on-chain protocol spec (`entities/`, `panoptic.md`, `protocol_integrations/`,
`COMMUNICATION/`, `model/`). It is NOT in `cfmm-vol-markets-spec` yet. Before it can become a
submodule, its content must live in the target repo.

- **Target:** `JMSBPP/cfmm-vol-markets-spec` under a `protocol/` subpath (keeps protocol spec
  distinct from the math/anchor spec at that repo's root).
- **Mechanism:** `git filter-repo` of `spec/` → `protocol/` (history preserved), then
  `git merge --allow-unrelated-histories` into cfmm-vol-markets-spec — mirroring the lean
  migration. Coordinated with the spec-repo owner (peer `migrate-lean4-vol-markets-spec`);
  the old→new commit map is attached so any in-doc "integrated <sha>" citations stay traceable.
- **Exit criterion:** `cfmm-vol-markets-spec` contains the full `spec/` tree under `protocol/`,
  verified by a tree diff (`spec/` here == `protocol/` there, modulo the path prefix).

### 2.2 The single PR → `develop` (four changes)

**(a) Remove `model/`** — `model/mev_tax_model_one/` + `model/BUILD.md` (the GAMS MEV-tax
prover). Already captured in `cfmm-numopt` (verified per-branch by that peer). On-chain tests
reference `test/models/…` (KEPT), not `model/`.
- Precondition check (in the plan): `git grep` confirms zero references to `model/` from
  `src/`, `test/`, `foundry-scripts/`, `foundry.toml`, `Makefile` on the PR branch. Run this
  IN the clean clone (earlier greps in the orphaned worktree returned false-empty — see §5).
- If any `Makefile` GAMS targets reference `model/`, remove them too.

**(b) Remove `tools/gamsdiff` + `test/gamsDiff`** — the GAMS↔Solidity differential-test
tooling (off-chain). Coupled bits to remove in the same commit:
- `foundry.toml` `fs_permissions` entry `{ access = "read", path = "./test/gamsDiff/fixtures" }`.
- Any `Makefile` gamsdiff target and `tools/gamsdiff` references.
- Note: this reverses the earlier "keep on develop" decision from the lean cleanup; that's
  intentional per the repositioning.

**(c) `offchain/` → submodule to `gams-evm-transport`** — root correspondence confirmed
(`offchain/{app,lib,migrations,rig,spec}` ↔ gams-evm-transport root `app/lib/migrations/rig/spec/test`).
- Mechanism: `git rm -r offchain/` (content is in gams-evm-transport), then
  `git submodule add https://github.com/JMSBPP/gams-evm-transport.git offchain`.
- Coupling policy (user decision): rig-dependent on-chain tests **self-skip when the submodule
  is not initialized** (they already skip on absent `PLANK_ROOT`/fixtures). No submodule-init
  is added to the gate, so `offchain/rig/`-reading tests run only where the submodule is
  present. The plan verifies the gate stays green with `offchain/` uninitialized (skips, not
  failures) — and lists exactly which tests move to skipped, so the coverage change is explicit.
- `foundry.toml` `fs_permissions` reading `offchain/…` (if any) stay valid through the
  submodule mount (path unchanged); confirm at plan time.

**(d) `spec/` → submodule to `cfmm-vol-markets-spec`** (after §2.1) —
- Mechanism: `git rm -r spec/`, then `git submodule add … spec` pinned at the migration commit.
  Because the content lives under `protocol/` in the target, the submodule root is the repo and
  in-repo references to `spec/entities/…` become `spec/protocol/entities/…` — the plan enumerates
  and repoints every such reference (e.g. `spec/entities/types/risk.md`, `.planning` cites).
- If keeping the exact `spec/<x>` paths is required by consumers, the alternative is a sparse/path
  layout in the spec repo mirroring `spec/` at its root; the plan picks one and states it. Default:
  `protocol/` prefix + repoint refs.

## 3. Safety rails
- **Archive-tag before delete:** every removed path (`model/`, `tools/gamsdiff`, `test/gamsDiff`,
  `offchain/`, `spec/`) archived as an `archive/<name>` origin tag before removal (recoverable),
  consistent with the branch/dir cleanups already done.
- **Gate is the arbiter:** PR merges only on a green `develop` gate. A red gate means a real
  break — fix or revert, never force-merge.
- **`feat/gams-solidity-difftest` + the old main checkout:** obsolete after this work; the fresh
  clone (`cfmm-wt/vol-markets`) is the working checkout. That branch is already archived
  (`archive/feat-gams-solidity-difftest`) and can be deleted once nothing references it.

## 4. End state (boundaries after)
`cfmm-vol-markets/` = `src/` + `test/` (Plank/Solidity contracts) + `lib/` (deps incl.
`cfmm-types`) + `foundry-scripts/` + `spec/` ↦ submodule (cfmm-vol-markets-spec) +
`offchain/` ↦ submodule (gams-evm-transport) + `.planning/`, `docs/`, `notes/`, `Makefile`,
`foundry.toml`. Gone: `model/` (→ cfmm-numopt), `tools/gamsdiff` + `test/gamsDiff`, and the
lean/GAMS/econometrics bodies removed earlier.

## 5. Risks & open items
- **False-empty greps (verification hazard):** the pre-flight reference checks MUST run in the
  clean clone, not the orphaned worktree that returned empty results during design (its `.git`
  was broken — see §6). Treat any empty grep as suspect until re-run in a healthy checkout.
- **Single-PR blast radius:** four coupled changes in one PR (user's chosen sequencing). Mitigated
  by the gate + archive tags; the plan should stage the commits within the PR so a bisect is possible.
- **offchain/ coverage drop:** self-skip means rig/contract tests don't run in CI unless the
  submodule is inited. Accepted; logged explicitly. Revisit if rig coverage must be enforced.
- **spec/ migration is a separate cross-repo effort** and gates the whole PR; it needs the
  spec-repo owner's coordination and its own verification before this PR starts.

## 6. Provenance note
Authored in a fresh clone at `cfmms-playground/cfmm-wt/vol-markets` after the prior local main
checkout (`cfmm-replicationPlank/`) was removed by an external workspace change on 2026-08-26
(all work was safe on origin: 5 branches + 22 `archive/*` tags). The orphaned `cfmm-wt/*`
worktrees are unrelated to this design and out of scope.
