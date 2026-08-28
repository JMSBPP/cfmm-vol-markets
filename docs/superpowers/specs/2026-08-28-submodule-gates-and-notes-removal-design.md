# Submodule gate cascade + notes/ removal — design

**Date:** 2026-08-28  
**Status:** design — awaiting maintainer review before implementation plan  
**Repo:** `JMSBPP/cfmm-vol-markets` (fork; canonical `d2p-finance/cfmm-vol-markets`)

## 1. Goal

Three coupled changes on `develop`:

1. **Delete `notes/`** from the parent repo (no relocation).
2. **Keep root submodule gitlinks current** with `d2p-finance/*/main` HEAD — not stale SHA pins.
3. **Extend `develop-gate`** so merges require the four root submodules’ own CI to be green on the **latest** commits, and the gate **auto-bumps** gitlinks when they drift.

`lib/*` submodules stay as today (forge/plank deps only; third-party; not part of this cascade).

## 2. Decisions (locked)

| Topic | Decision |
|---|---|
| `notes/` relocation | **None** — delete directory outright |
| Citation cleanup | **Minimal live surface** — `src/`, `test/`, `Makefile`, `develop-gate.yml` comment only; `.planning/`, README, CLAUDE/AGENTS stay historical |
| Submodule scope | All four root submodules: `spec/`, `offchain/`, `evm-spec-bridge/`, `refs/` |
| Tracking branch | **`main` on each canonical URL already in `.gitmodules`** (`d2p-finance/*`) |
| Pin enforcement | **Option B — gate auto-bump** (not fail-if-stale) |
| Validation gate | **`develop-gate` on PR** (unchanged authority); implementation in isolated **worktree** |
| Local verification | **CI only** — do not treat local compile/test as proof |

## 3. Current drift (why static pins fail)

At spec time, every root gitlink lags `d2p-finance/main`:

| Path | Pinned on `develop` | `d2p-finance/main` HEAD |
|---|---|---|
| `spec/` | `68812cf` | `f2736e0` |
| `offchain/` | `e849a767` | `b1104974` |
| `evm-spec-bridge/` | `6cef43b` | `b4c7f17` |
| `refs/` | `d00a723` | `3a35f7c` |

The first implementation PR must land with gitlinks at (or auto-synced to) these heads. There is **no** init-pin exemption for `evm-spec-bridge`.

## 4. `develop-gate` — new `submodule-gates` job

### 4.1 Placement

- **Job name:** `submodule-gates` (fixed string — consumed by final `gate` aggregation).
- **`needs:`** `[approve]` — parallel with `forge` and `plank`.
- **`runs-on:`** `ubuntu-latest` (hosted; no self-hosted secrets).
- **`timeout-minutes:`** `15`.
- **`permissions:`** `contents: write` **for this job only** (auto-bump push). All other jobs keep `contents: read`.

Final `gate` job:

```yaml
needs: [approve, forge, plank, submodule-gates]
```

Loop must accept `submodule-gates.result` as `success` (same pattern as `forge`/`plank`).

### 4.2 Algorithm (scripted)

Add `.github/scripts/sync-submodule-gates.sh` (single source of truth; workflow calls it).

For each entry in the manifest below:

1. **`LATEST`** — `git ls-remote "${url}" refs/heads/main | awk '{print $1}'` (40-char SHA; fail if empty).
2. **`PINNED`** — gitlink SHA at repo root for that path (from `git rev-parse :path` after checkout).
3. **Verify upstream gate on `LATEST`** (§4.3). If any required check is missing or not `success`, **fail the job** — do not bump.
4. **Checkout submodule content at `LATEST`** — init if needed, `git -C "$path" fetch origin main && git -C "$path" checkout "$LATEST"`.
5. **If `PINNED` ≠ `LATEST`** — stage gitlink (`git add "$path"`).
6. After all four: if the index changed, **commit and push** (§4.4).

Manifest (path → canonical repo → required green check-run **names**):

| Path | Canonical repo | Required `check-runs` names (exact match) |
|---|---|---|
| `spec` | `d2p-finance/cfmm-vol-markets-spec` | `stack build && stack test` |
| `offchain` | `d2p-finance/gams-evm-transport` | `build-test`, `gate` |
| `evm-spec-bridge` | `d2p-finance/evm-spec-bridge` | `seam`, `build` |
| `refs` | `d2p-finance/cfmm-refs` | `shelf` |

Verification uses:

```bash
gh api "repos/${repo}/commits/${LATEST}/check-runs" --paginate \
  --jq '.check_runs[] | select(.name == $name) | .conclusion' -f name=...
```

Rules:

- Every required name must exist **at least once** with `conclusion == "success"`.
- Any `failure`, `cancelled`, `timed_out`, or **missing** name → job fails with a named error (`::error::submodule spec: LATEST b4c7f17 missing green check "seam"`).
- **`offchain`:** do not re-run `transport-gate` / self-hosted work in the parent; trust check-runs already recorded on canonical `main` at `LATEST`.
- Public canonical repos: default `GITHUB_TOKEN` + `gh` should suffice. If cross-org check-run reads fail in practice, add optional secret `GH_STATUS_READ` (read-only PAT) — script tries default first, falls back to secret.

### 4.3 Auto-bump commit (Option B)

**Preconditions for push:**

- Event is `pull_request`.
- **`github.event.pull_request.head.repo.full_name == github.repository`** (same-repo PR on `JMSBPP/cfmm-vol-markets`). Fork-head PRs **cannot** auto-bump → fail with: *"submodule pins stale; open PR from a branch on JMSBPP/cfmm-vol-markets (not a fork head) or bump gitlinks manually."*
- Index has staged gitlink changes after step 5.
- All four `LATEST` SHAs passed §4.3 before staging.

**Commit:**

```
chore(ci): auto-bump root submodule pins to d2p-finance/main

spec@… offchain@… evm-spec-bridge@… refs@…
```

**Push:** to `github.head_ref` using the workflow token (`git push origin HEAD:"${HEAD_REF}"`).

**Idempotency:** second gate run on the same PR should find `PINNED == LATEST`, make no commit, exit 0. A new push to upstream `main` between runs may produce a second bot commit — acceptable.

**Concurrency:** existing `develop-gate` concurrency (`develop-gate-${{ github.ref }}`, cancel-in-progress) limits overlapping auto-bumps on one PR.

### 4.4 Checkout requirements for the job

```yaml
- uses: actions/checkout@v4
  with:
    submodules: false
    fetch-depth: 0
    ref: ${{ github.head_ref || github.ref }}
    persist-credentials: true   # push enabled via job permissions
```

Then `git submodule sync --recursive` before the script runs.

## 5. Remove `notes/`

### 5.1 Delete

Remove the entire `notes/` directory (5 files):

- `DATA_CONTRACT.md`
- `UNITS_AND_SCALES.md`
- `DIFFERENTIAL_LAYOUT.md`
- `TOOLCHAIN_PINS.md`
- `STOCHASTIC_MODEL.md`

### 5.2 Minimal citation edits

Replace or shorten `notes/…` references — **do not** introduce a replacement binding-spec tree.

| File | Action |
|---|---|
| `src/types/pos_spec/VolOrder.plk` | Drop `notes/UNITS_AND_SCALES.md`; keep inline unit intent |
| `src/types/pos_spec/VegaTarget.plk` | Same |
| `src/lib/exposure/PanopticVegaLensLib.plk` | Point math prose at `spec/` or inline; drop `notes/VOLATILITY_INSTRUMENTS.md` path |
| `src/lib/ldf/GeometricDistribution.plk` | Drop `notes/VOLATILITY_INSTRUMENTS.md` path |
| `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | Drop `notes/UNITS_AND_SCALES.md` path |
| `test/protocol_integrations/SpecHelper.sol` | Replace `notes/DIFFERENTIAL_LAYOUT.md` refs with inline transport-boundary wording (RED-06 semantics preserved in comments) |
| `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` | Same |
| `test/pos_spec/VolOrderTargetVega.t.sol` | Inline units comment |
| `Makefile` | Remove or shorten DIFFERENTIAL_LAYOUT comment |
| `.github/workflows/develop-gate.yml` | Replace `notes/TOOLCHAIN_PINS.md` comment with `.github/foundry-version` |

**Explicitly out of scope:** README, CLAUDE.md, AGENTS.md, `.planning/**`, `docs/superpowers/specs/2026-08-28-logo-design.md`.

### 5.3 Accepted risk

Phase plans that grep `notes/DIFFERENTIAL_LAYOUT.md` or `notes/TOOLCHAIN_PINS.md` will drift until those phases are updated. That is intentional deferral, not part of this PR.

## 6. Initial PR contents (implementation)

Single PR from worktree branch (e.g. `chore/submodule-gates-notes-removal`) off clean `origin/develop`:

1. Delete `notes/` + minimal citation edits (§5).
2. Add `.github/scripts/sync-submodule-gates.sh`.
3. Extend `.github/workflows/develop-gate.yml` (`submodule-gates` job + `gate` needs).
4. **Initial gitlink bump** to current `d2p-finance/main` SHAs (§3 table) so the first gate run is not blocked waiting for its own bot commit — bot path remains for **future** drift.

**Do not** stage unrelated dirty paths (`.planning/config.json`, `lib/*` drift, `offchain`/`spec` working tree mods, `DynamicFeeMod.plk`, untracked `TODO.md`, etc.).

## 7. Out of scope

- Rewriting README / agent guides to remove `notes/` mentions.
- Pinning or gating `lib/*` submodules.
- Inline re-running Stack/Cairo/Docker builds in the parent workflow (check-runs on `LATEST` only).
- Changing child-repo workflows.
- Bumping `spec` pin side effects (cabal renames at `f2736e0`) beyond what the submodule bump carries — follow-up if parent build breaks.

## 8. Test plan (CI)

- [ ] `develop-gate` green on the PR (approve → forge, plank, submodule-gates → gate).
- [ ] `submodule-gates` logs four `LATEST` SHAs and confirms required check-runs green.
- [ ] With artificially stale gitlink on a test branch, bot commit updates four gitlinks and re-run goes green (manual spot-check once).
- [ ] Fork-head PR fails with the documented message (no silent skip).
- [ ] `forge`/`plank` jobs unchanged in behavior (still `lib/*` only).

## 9. Self-review

| Check | Result |
|---|---|
| Placeholders / TBD | None |
| Internal consistency | Auto-bump only after upstream checks green; fork PRs excluded |
| Scope | One PR + ongoing gate behavior; no README/agent rewrite |
| Ambiguity | Tracking = canonical `main`; enforcement = Option B auto-bump |
| Contradictions with fork→canonical model | Submodule URLs unchanged; latest read from canonical `main` |

---

**Next step after maintainer approval:** invoke `writing-plans` for the implementation plan (worktree, chunk approvals, red-first only if new behavior warrants tests — here CI script + workflow is the test surface).
