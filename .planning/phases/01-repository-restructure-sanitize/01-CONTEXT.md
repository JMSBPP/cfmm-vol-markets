# Phase 1: Repository Restructure & Sanitize - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Stand up the canonical public repository under the `wvs-finance` org with `JMSBPP` as a fork, and sanitize the working tree so nothing leaks or breaks at the public flip. Covers REPO-01..05. This phase is repository/ops work only — no Plank, GAMS, kernel, or bridge code (those start Phase 2+).

**Confirmed facts (scouted):** `wvs-finance` org exists and `JMSBPP` is an `admin` (can create/transfer/flip-public). The existing `JMSBPP/cfmm-replicationPlank` is **private, brand-new (2026-06-23), 0 stars, 0 forks** — nothing external to preserve, so migration is low-risk.

</domain>

<decisions>
## Implementation Decisions

### Migration mechanics — Transfer, then fork back
- **Method:** GitHub-**transfer** the existing `JMSBPP/cfmm-replicationPlank` into the `wvs-finance` org (JMSBPP is admin), make it **public**, then **fork it back** to `JMSBPP`.
- **Git history:** **Squash to one clean, sanitized baseline commit** before going public — the public repo's history must NOT contain the local `/home/jmsbpp/...` paths currently in the committed `.planning` docs.
- **Final remote topology (REPO-03):** `origin` → `JMSBPP/cfmm-replicationPlank` (the fork), `upstream` → `wvs-finance/cfmm-replicationPlank` (canonical).
- **Recommended execution sequence:**
  1. Sanitize the working tree (REPO-05): remove `refs/`, remove the `Counter` scaffold, disable CI, scrub local paths, fix `.gitignore`.
  2. Squash all current history into a single clean baseline commit (orphan branch or reset + re-commit).
  3. Force-push the clean baseline to `JMSBPP/cfmm-replicationPlank` (still private).
  4. Transfer the repo to the `wvs-finance` org.
  5. Flip it **public**.
  6. Fork `wvs-finance/cfmm-replicationPlank` back to `JMSBPP`; set local `origin`/`upstream` accordingly.
- **Outward-facing / irreversible — confirm with the user before steps 4–6 (transfer, public flip, fork).** The transfer and public flip are the points of no easy return.

### refs/ web app — Remove from the repo
- **Delete `refs/` entirely** from the tree. It is an embedded git clone (nested `.git`) of the Plank-playground Next.js app plus ~7MB `node_modules` — reference material, not part of the research deliverable. It lives in its own upstream repo / the user's local copy.
- Removing it also resolves the embedded-repo and `node_modules`-bloat concerns flagged in `CONCERNS.md` §10.

### CI disposition — Disable for now
- **Remove/disable** the broken `.github/workflows/test.yml` so the public repo shows **no misleading red check**.
- Real CI is re-introduced in **Phase 2**, after the `plank` toolchain is pinned (TOOL-01/02) so a runner can reproducibly build Plank.
- Do **not** attempt to fix `checkout` version, `[profile.ci]`, or the fork `API_KEY` secret in this phase — that work belongs with Phase 2 toolchain pinning.

### Sanitization scope (REPO-05)
- Remove the default Foundry scaffold `src/Counter.sol` and `script/Counter.s.sol` (`CONCERNS.md` §9).
- Ensure `.gitignore` covers `node_modules/`, Foundry build artifacts (`out/`, `cache/`), and other local junk.
- **Scrub local absolute paths from tracked file contents** — replace `/home/jmsbpp/learning/cfmm-theory` references with the cfmm-theory **URL** (per the link-by-URL decision) and `/home/jmsbpp/.../experiments/gams` with the in-repo `model/` path. (Note: GAMS is actually vendored in Phase 2 per the roadmap; in Phase 1, at minimum the `.planning` docs should not embed local user paths. The squash baseline means history won't carry them either.)

### README (REPO-04)
- Replace the Foundry boilerplate `README.md` with project-specific content: the Plank/GAMS dual-track overview, the open-loop-plumbing milestone goal, prerequisites (Foundry, `plank`, GAMS), and how to run. Keep it honest about early/research maturity.

### Claude's Discretion
- **License & repo metadata:** default to matching the `wvs-finance` org's existing-repo license convention; add a repo description from PROJECT.md's "What This Is" and reasonable topics. Confirm the specific license at execution.
- Exact squash mechanism (orphan branch vs `git reset` + recommit).
- `.gitignore` exact entries and whether to keep `.planning/` tracked (default: keep tracked + public, paths scrubbed).
- Submodule handling: keep the existing `.gitmodules` submodules as-is; pinning floating submodules is a Phase 2 (TOOL-02) concern, not Phase 1.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements & scope
- `.planning/REQUIREMENTS.md` — REPO-01..05 (the five acceptance criteria for this phase)
- `.planning/ROADMAP.md` — Phase 1 details + the "Deferred Review Findings" note (REPO-05 should use a content scan `git grep -I '/home/jmsbpp'`, and vendor GAMS before the flip)
- `.planning/PROJECT.md` — Constraints: "Repository ownership" (wvs-finance canonical public + JMSBPP fork) and the link-by-URL cfmm-theory decision

### Repo state / what to sanitize
- `.planning/codebase/CONCERNS.md` — §7 (broken CI), §9 (`Counter` scaffold), §10 (`refs/` embedded web app), §6 (submodule sprawl / floating `heads/main` pins), §1 (commit-history note)
- `.planning/codebase/STACK.md` and `STRUCTURE.md` — current toolchain/layout for the README

[No external specs/ADRs — repository conventions are captured in the decisions above.]

</canonical_refs>

<code_context>
## Existing Code Insights

### Assets to act on
- `.github/workflows/test.yml` — the broken CI workflow to disable/remove this phase
- `refs/` — embedded Plank-playground app (nested `.git` + `node_modules`) to remove
- `src/Counter.sol`, `script/Counter.s.sol` — Foundry scaffold to delete
- `README.md` — Foundry boilerplate to replace
- `.gitignore` (156 bytes, minimal), `.gitmodules` (8 tracked submodules) — to update/leave per decisions
- `.planning/PROJECT.md`, `.planning/codebase/*.md` — tracked docs currently containing `/home/jmsbpp/...` paths to scrub

### Established patterns
- Git ops via `gh` CLI (authed as `JMSBPP`, scopes include `repo`, `delete_repo`, `read:org`, `workflow`); `JMSBPP` is `admin` on `wvs-finance`.
- GSD commits go through `node .../gsd-tools.cjs commit` — but the squash baseline will rewrite/replace this history at the public flip.

### Integration points
- `git remote` (currently `origin` = `JMSBPP/cfmm-replicationPlank`) → re-point to fork + add `upstream` after transfer.
- The squash baseline interacts with the GSD `.planning` commit history — functionally fine (GSD reads files, not history).

</code_context>

<specifics>
## Specific Ideas

- Public repo must be **honest**: no green CI badge that doesn't actually test Plank; README states research/early maturity rather than overclaiming.
- The transfer + public flip are the irreversible moments — explicit user confirmation gate there.

</specifics>

<deferred>
## Deferred Ideas

- Real, reproducible CI (pinned `plank`, `[profile.ci]`, fork `API_KEY`) — **Phase 2** (TOOL-01/02).
- GAMS vendoring into `model/` — **Phase 2** (GAMS-01) per the roadmap (a review finding suggested pulling it earlier; left in Phase 2 per "ignore blockers").
- Pinning floating `heads/main` submodules — **Phase 2** (TOOL-02).
- The other deferred review findings (selector `0xd9c112ef`, quantization boundary, exact round-trip, etc.) — recorded in `ROADMAP.md`, addressed in Phases 3–7.

</deferred>

---

*Phase: 01-repository-restructure-sanitize*
*Context gathered: 2026-06-27*
