# MERGE-DEVELOP-PLAN — land feat/lean4-spec on develop (PR #10)

Status: EXECUTING — DevOps review applied; Reality Checker terminated (user ruling:
no further review rounds). EXECUTION AMENDMENT 2026-08-17: measured github git
transfer on the runner at ~33KB/s → the ~1GB mathlib clone is ~8h → option B alone
can never go green. Option A implemented IN THIS PR (77a0e52): lean job persists
Lake packages in ~/.cache/lake-packages (cache-in each run; cache-out only on
lake-manifest.json change; packages-only so the sorry-guard's compiler-warning
channel stays sound). Cache seeded on the runner from the warm local tree (6.9GB).
Executed commits: c890f2f (tarball cleanup), 41ace64 (cache-get line + timeout 45),
dc83838 (merge origin/develop, both conflicts as planned), 77a0e52 (option A).
MEASURED (rehearsal V2, CI-realistic path on the runner host): cache-in ~10s +
cache get + full 8088-job build = 10m37s wall, exit 0 — the 45-min timeout holds
with ~4x margin. Gate run 32039171794 awaits the user's environment approval.
Date: 2026-08-17

## Goal

Merge feat/lean4-spec (275 commits ahead, 6 behind origin/develop) into develop through
PR #10 with a green develop-gate, after (1) Lake tail-file cleanup, (2) full compile
verification, (3) making the gate's lean job actually able to pass.

## Verified facts (recon, this session)

- PR #10: OPEN, head=feat/lean4-spec, base=develop, **mergeable: CONFLICTING**; only
  check present is `approve` WAITING (environment gate — nothing has run yet).
- Conflicts vs origin/develop (via `git merge-tree`): exactly two —
  `.gitignore` (content) and `model/exp/eta.md` (modify/delete: develop deleted it in
  the GAMS sweep bbe0ebb; our sole change is ONE trailing-whitespace line, 9976b10).
- Local `lake build` (incremental): **clean, 8088 jobs, exit 0**; only
  unusedVariables lints. Source grep for sorry/admit: single hit at
  `lean/vol_markets/MarketMaking.lean:167`, INSIDE a `/- ... -/` block comment (the
  refuted A3 statement kept as provenance) — emits no compiler warning, so the gate's
  `declaration uses 'sorry'` grep cannot fire on it.
- `lean/lakefile.toml` roots ↔ `lean/vol_markets/*.lean`: exact match, 38/38.
- Gate lean job (`develop-gate.yml:109`): fresh checkout (`git clean -ffdx` wipes
  `lean/.lake`), elan bootstrap, plain `lake build`, **timeout-minutes: 20, NO
  `lake exe cache get`** → cold mathlib v4.28.0 clone (~1GB) + from-source build can
  never fit 20 min. Same diagnosis the CI session reported against PR #30's gate.
  Our copy of the workflow is byte-identical to origin/develop's (no fix on either).
  Our lakefile has NO LeanEVM requirement (removed 2026-07-16) — only mathlib is paid.
- Gate job scope vs our diff: `gams`/`gamsdiff` are `if: false` (gate accepts
  skipped) → our `model/` changes are CI-inert. No `cabal.project` exists, so the
  haskell job's `cabal build all` covers only the root
  `cfmm-replicationPlank-rpc-api.cabal` (offchain/) — our branch touches neither
  offchain/ nor the root cabal, and `econometrics/` is NOT in the gate's build scope.
  The haskell job has NEVER executed on any run (PR #9 was admin-merged past it);
  its first real run may fail on pre-existing grounds unrelated to this branch.
- Tail files: `lean/archive/` carries 7 TRACKED Aristotle result tarballs (11MB total,
  plus untracked local extras); `lean/spec/` is an empty untracked dir; `scratch/`
  (all the *-submit/*-return bundles) is fully gitignored — local-only, zero repo
  impact. Everything under lean/ that IS tracked and built is in the roots.

## Work items

### W1 — Lake tail-file cleanup
1. `git rm` the 7 tracked tarballs in `lean/archive/` (history and the public
   cfmm-lean4-spec mirror preserve provenance; slims every CI checkout by 11MB).
   **USER DECISION POINT — default: remove.**
2. Delete the empty `lean/spec/` dir and the untracked local tarballs (local tidy).
3. `scratch/`: leave in place (gitignored Aristotle provenance) — optionally tar to
   one archive locally. No repo effect either way.
4. lakefile roots: NO change — verified in sync; explicit roots kept deliberately.

### W2 — compile verification (cold + warm rehearsal)  [rev per DevOps M2]
1. Incremental build: DONE (clean).
2. WARM rehearsal (running): `.lake` moved aside, `lake exe cache get && lake build`
   with the host's persistent `~/.cache/mathlib` (2.3GB) in place. This host IS the
   cfmm-build runner, so this is a same-machine measurement AND it pre-warms CI:
   every gate run pays mathlib git clone (~1GB, `.lake` is wiped each run) +
   cache unpack + the ~60 project modules; `~/.cache/mathlib` and `~/.elan` survive
   `git clean -ffdx`.
3. COLD rehearsal: repeat with `~/.cache/mathlib` moved aside — clone + full cache
   download + unpack + build. This is the worst case the timeout must cover.
   Move the cache back after. Size the timeout to COLD + margin; 45 is defensible
   only if cold lands ≤ ~30–35 min.
4. Cache-availability note (DevOps m1): mathlib is pinned to release tag v4.28.0
   (manifest 8f9d9cff…) matching the toolchain — release tags always have published
   cache; residual miss risk is network-only.

### W3 — gate lean-job fix (option B, coordinated with the CI session)  [rev per DevOps M1]
1. PR #30's ACTUAL patch (read from its diff) is:
   `out="$(cd lean && lake exe cache get >/dev/null 2>&1; lake build 2>&1)"; echo "$out"`
   — silent, non-fatal cache get, and NO timeout change. Adopt that `out=` line
   BYTE-IDENTICAL (identical hunks on both sides auto-merge regardless of merge
   order). Do NOT unilaterally "improve" the shared line — a divergent edit to the
   same line guarantees a conflict for whoever merges second. If the better shape
   (visible/fatal cache get) is wanted, coordinate ONE change with the CI session
   across both PRs.
2. Carry `timeout-minutes: 20 → <W2-cold-measured + margin>` as PR #10's OWN delta —
   a different line, merges cleanly in either order. This is the piece PR #30 lacks
   and our 60-module tree needs.
3. Sorry-guard: unaffected — cache get output is discarded and `out=` wraps only
   `lake build`; the compiler-warning grep still sees every project module because
   CI always compiles them fresh.
4. Provenance: `pull_request` workflows run from the PR MERGE REF (correct for
   same-repo PRs) — but PR #10 is currently CONFLICTING, so NO merge ref exists and
   no gate run can trigger until W4 lands. The first gate run after W4's push is
   also W3's first real CI test. Each push needs a fresh `develop-gate` environment
   approval from the user — budget the clicks.
5. Options A (persist `lean/.lake` outside the wiped workspace) and C (team infra)
   stay FLAGGED, NOT in this PR — scoped precisely: cache get + persistent
   `~/.cache/mathlib`/`~/.elan` already deliver ~80% of option A; the only recurring
   cost A would still remove is the ~1GB mathlib re-clone into the wiped `.lake`.

### W4 — sync with develop
1. `git merge origin/develop` into feat/lean4-spec (merge, not rebase — 275 pushed
   commits).
2. Resolve the two known conflicts:
   - `.gitignore`: hand-union both sides.
   - `model/exp/eta.md`: ACCEPT DEVELOP'S DELETION (our change is a vacuous trailing
     line; the file was superseded by the GAMS sweep).
3. `lake build` again post-merge (develop's 6 commits are GAMS-side, but verify).
4. Push; PR #10 refreshes; confirm `mergeable` flips to MERGEABLE.

### W5 — gate run + merge
1. USER approves the `develop-gate` environment (the `approve` job) — user-side.
2. Watch the run. Triage any red job:
   - caused by our diff → fix on this branch;
   - pre-existing infra (haskell first-ever run; runner contention with PR #30's
     gate — ONE self-hosted runner, jobs queue) → report + hand to CI session.
     NO admin-bypass merge without an explicit user ruling.
3. On green: merge PR #10.
4. Post-merge: push the lean tree to the cfmm-lean4-spec mirror (the ~15 new modules
   are still unpushed there — registered ledger item).

## Risks

- Runner contention: single `cfmm-build` runner shared with PR #30's gate; jobs
  queue, wall-clock can be long. Not a correctness risk.
- The mathlib CLONE (network-bound, ~1GB) is unavoidable per cold run even with
  `cache get`; if W2's measured time approaches the bumped timeout, revisit option A
  before merging rather than inflating the timeout further.
- haskell job first-run unknowns are develop's, not ours — but they can block OUR
  merge; triage path defined in W5.2.
- `econometrics/` lands on develop UNGATED (no CI covers it; the "Haskell re-pin"
  follow-up remains open). Documented, accepted.
