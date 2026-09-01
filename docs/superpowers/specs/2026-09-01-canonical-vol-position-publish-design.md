# Canonical vol-position publish + production gate — design

**Date:** 2026-09-01  
**Status:** approved in chat; awaiting spec review before implementation plan  
**Repos:** `JMSBPP/cfmm-vol-markets` (fork) → `d2p-finance/cfmm-vol-markets` (canonical)

## 1. Goal & context

The fork (`JMSBPP/cfmm-vol-markets`) has outpaced canonical (`d2p-finance/cfmm-vol-markets`)
since the Aug-26 sync (PR #1). Vol-position work merged to fork `develop` via PR #101; the
`feat/vol-position` branch is a **persistent integration branch** with its own worktree
(`../vol-markets-vol-position`).

This design establishes:

1. **`main` on canonical** as the production mirror of fork `develop`, gated by **`prod.yml`**
   (successor to `develop-gate` on that branch).
2. **`vol-position` on canonical** as the upstream entry point for vol-position track updates
   **before** they reach `main`.

All changes reach canonical **only via fork → upstream PRs** — never direct pushes to
`d2p-finance/*`.

### Current state (2026-09-01)

| Branch | Repo | Tip | Notes |
|--------|------|-----|-------|
| `develop` | JMSBPP | `fe5fdfe` | Post PR #101; day-to-day integration |
| `feat/vol-position` | JMSBPP | `fe5fdfe` | Same tip as `develop` today; diverges later |
| `develop` | d2p-finance | `9acedd9` | Last sync PR #1 |
| `master` | d2p-finance | `f484937` | Legacy public baseline |
| `main` | d2p-finance | — | **Does not exist** |
| `vol-position` | d2p-finance | — | **Does not exist** |

Fork `develop` is **302 commits** ahead of canonical `develop`.

## 2. Branch topology

```
JMSBPP (fork)                         d2p-finance (canonical)
─────────────                         ──────────────────────

develop ─────────────────────────────► main          (production mirror)
  │                                      ▲
  │ merge slices                         │ promote when ready
  ▼                                      │
feat/vol-position ────────────────────► vol-position  (integration / review)
```

| Branch | Role |
|--------|------|
| `JMSBPP:develop` | Day-to-day integration; keeps `develop-gate` |
| `d2p-finance:main` | **Must track** `JMSBPP:develop`; production mirror |
| `JMSBPP:feat/vol-position` | Persistent vol-position worktree branch |
| `d2p-finance:vol-position` | Upstream review entry for vol-position updates |

**`main` is a new branch**, not a rename of stale `master` @ `f484937`. Legacy `master` and
`develop` on canonical may remain; **`main` becomes the default branch** once bootstrapped and
verified.

## 3. CI workflows

Add workflows **alongside** existing ones; fork `develop` keeps `develop-gate.yml`.

| Workflow file | `on:` trigger | Environment | Purpose |
|---------------|---------------|-------------|---------|
| `develop-gate.yml` | PR → `develop` | `develop-gate` | Fork day-to-day (unchanged) |
| `prod.yml` | PR → `main` | `prod` | Canonical production gate |
| `vol-position-gate.yml` | PR → `vol-position` | `vol-position-gate` | Canonical vol-position review |
| `push-build.yml` | push to feature branches (excl. `develop`, `main`) | none | Fork fast feedback |

### `prod.yml` (from `develop-gate.yml`)

- Workflow `name: prod`
- `pull_request.branches: [main]`
- `environment: prod` (new GitHub Environment on canonical — approval + same runner/secrets as `develop-gate`)
- `concurrency.group: prod-${{ github.ref }}`
- Jobs: `approve` → `forge` + `plank` + `submodule-gates` → `gate` (same structure as `develop-gate`)
- Same forge command + skip ledger as `develop-gate` / `push-build`

### `vol-position-gate.yml`

- Same job structure as `prod.yml`
- `pull_request.branches: [vol-position]`
- `environment: vol-position-gate`
- Separate approval so vol-position review does not consume production approval

### Skip-ledger parity

Update `scripts/check-ci-skip-ledger.sh` to enforce parity between:

- `push-build.yml` ↔ `develop-gate.yml` (existing)
- Optionally extend parity checks if `prod.yml` / `vol-position-gate.yml` carry identical skip lines

### Canonical GitHub setup (one-time, maintainer)

- Create Environments: `prod`, `vol-position-gate` on `d2p-finance/cfmm-vol-markets`
- Configure approval + secrets (`API_KEY`, runner labels) mirroring `develop-gate`
- Set default branch to `main` after bootstrap PR merges

## 4. Publish sequence

Because canonical branches must exist before fork PRs can target them:

### Step 0 — Maintainer bootstrap (one-time)

Create on `d2p-finance/cfmm-vol-markets`:

- `main` — initial tip may be `9acedd9` (current canonical `develop`) or empty; first sync PR
  replaces content with fork `develop`
- `vol-position` — initial tip from `main` after step 1, or same as fork `feat/vol-position`

*(GitHub requires the base branch to exist for cross-repo PRs.)*

### Step 1 — Production sync PR

| Field | Value |
|-------|-------|
| Head | `JMSBPP:develop` @ `fe5fdfe` (ongoing: latest green `develop`) |
| Base | `d2p-finance:main` |
| Includes | `prod.yml`, `vol-position-gate.yml`, skip-ledger updates |
| Gate | `prod` on canonical |

Delivers ~302 commits since last canonical sync + new production workflows.

### Step 2 — Vol-position integration PR

| Field | Value |
|-------|-------|
| Head | `JMSBPP:feat/vol-position` |
| Base | `d2p-finance:vol-position` |
| Gate | `vol-position-gate` on canonical |

Today head equals `develop` @ `fe5fdfe`; branches diverge as vol-position work continues in
`../vol-markets-vol-position`.

### Step 3 — Promote to production (recurring, later)

| Field | Value |
|-------|-------|
| Head | `d2p-finance:vol-position` |
| Base | `d2p-finance:main` |
| Gate | `prod` |

Run when vol-position track is ready for production mirror update.

### Ongoing fork workflow

1. Vol-position slices land on `JMSBPP:feat/vol-position` → PR to `d2p-finance:vol-position`
2. Broader integration merges to `JMSBPP:develop` → PR to `d2p-finance:main`
3. `feat/vol-position` is **not** deleted after merges (persistent branch + worktree)

## 5. Fork-side code changes (minimal)

On `JMSBPP:develop` (ships to canonical via sync PR):

| Change | Path |
|--------|------|
| Add production gate | `.github/workflows/prod.yml` |
| Add vol-position gate | `.github/workflows/vol-position-gate.yml` |
| Skip-ledger parity | `scripts/check-ci-skip-ledger.sh` (if extended) |
| **No rename** of `develop-gate.yml` on fork `develop` | — |

No changes to vol-position source in this publish phase unless gate files are the only diff.

## 6. Out of scope

- Renaming canonical `master` → `main` (use new `main` branch instead)
- Deleting canonical legacy `develop` / `master`
- Test/skip-ledger cleanup (issue #16) — separate from publish
- Submodule realignment beyond what `submodule-gates` already enforces
- Direct pushes to `d2p-finance/*`

## 7. Success criteria

- [ ] `d2p-finance:main` tip matches `JMSBPP:develop` after step 1 merge
- [ ] PRs to `main` on canonical run `prod` gate (not `develop-gate`)
- [ ] `d2p-finance:vol-position` exists and accepts `JMSBPP:feat/vol-position` PRs
- [ ] `vol-position-gate` passes on step 2 PR
- [ ] Fork `develop` still uses `develop-gate` unchanged
- [ ] Default branch on canonical is `main`

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Large step-1 PR (~302 commits) | Single gate run on canonical; fork already green on `develop-gate` |
| Base branches don't exist on canonical | Step 0 maintainer bootstrap before opening PRs |
| Environment `prod` not configured | Step 0; gate hard-fails until approval env exists |
| `feat/vol-position` == `develop` today | Expected; branches diverge after bootstrap |
