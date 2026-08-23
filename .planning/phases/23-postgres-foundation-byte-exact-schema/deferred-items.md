# Phase 23 — deferred items

Out-of-scope discoveries logged during execution. Nothing here was fixed; each is recorded so it
is not rediscovered as a surprise.

## From 23-01

- **`225a/` is untracked at the repo root** (`gamsnext.sh`, `gmsprmun.dat`, mtime 2026-08-16
  08:12, i.e. pre-dating this plan's execution). It is GAMS solver scratch, not produced by this
  workstream and not under `offchain/` or `.planning/`. Not committed and not `.gitignore`d here
  because the ignore rule belongs with whoever runs GAMS — a rule written blind from this side
  could mask a real artifact later. **Owner: the GAMS/Phase 24 track.**
- **`CHANGELOG.md`, `Setup.hs`, `stack.yaml`, `stack.yaml.lock` are untracked** and were already
  untracked at session start. `CHANGELOG.md` in particular is named by
  `cfmm-replicationPlank-rpc-api.cabal`'s `extra-doc-files`, so an `sdist` would currently fail
  on a clean checkout. Out of scope for a plan that owns dependency wiring; flagged for whoever
  owns packaging.
