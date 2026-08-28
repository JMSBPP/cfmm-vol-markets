---
phase: 02-volorder-t-minimal-instantiation
plan: 05
status: complete
completed: 2026-08-28
executor: superpowers inline (maintainer session) — per the phase EXECUTION GATE
requirements: [VORD-01, VORD-02, VORD-03]
---

# 02-05 — Phase 2 closed: merged to develop as `790c413`

## Branch protection, re-measured immediately before merging (verbatim)

```json
{"contexts":["gate"],"enforce_admins":false,"reviews":null,"strict":false}
```

`reviews: null` — **no review requirement**, so `gh pr merge --merge` was used plain and **no admin
bypass was exercised**. Third phase in a row this reading has held; Phase 1 wrote two plans against
a review requirement the API does not report, and this plan measured rather than carrying that
forward. `gate` is the branch's only enforced protection.

`mergeStateStatus` was `UNSTABLE` at first read — solely because `build` (push-build, **not** a
required check) was still in flight. It was allowed to finish (`33184226937`, success) before
merging rather than merging past an in-flight build.

## The merge

| | |
|---|---|
| PR | **#62**, `MERGED` |
| Merge commit | **`790c413eb8c0ef00593b034a98a79984bbb354d9`** |
| Subject | `Merge pull request #62 from JMSBPP/feat/volorder-t-minimal` |
| Style | merge commit, matching `#54/#55/#56/#59/#60` |
| `MERGE^2` | `56b3c4d` — the branch head the gate ran on |
| `git diff MERGE^2 origin/develop -- src/ test/ .github/ Makefile` | **0 bytes** → run `33184231798` describes the merged source byte-for-byte |
| History | merge commit chosen by the maintainer over squash, so the rejected `c9844d1` and its revert `3af40fb` stay visible; their docs are banner-marked STALE |

## Criteria 1–5, verified against `origin/develop` (not the branch)

| # | Check | Result |
|---|---|---|
| C1 | `git show origin/develop:…/02-REGRESSION-ASSESSMENT.md \| grep -c '^**Status:** FINAL'` | **1** |
| C1 | …`grep -c '(02-05 fills)'` | **0** |
| C1 | …`grep -c 'NONE FOUND (02-04)'` | **1** |
| C2 | …`VolOrder.plk \| grep -c '^const VolOrder = fn (comptime T: type) type {'` | **1** |
| C2 | …`PanopticTokenIdSetterLib.plk \| grep -c 'fn (comptime T: type, vo: VolOrder(T), pool_id: u256)'` | **1** |
| C2 | …`Extra.plk \| grep -c '^const Extra = fn (comptime T: type) type {'` | **1** |
| C3 | `git diff b090b2e origin/develop -- …/VolOrderToPanopticTokenId.t.sol \| wc -c` | **0 bytes** |
| C4 | `git diff b090b2e origin/develop --diff-filter=D --name-only -- test/ \| wc -l` | **0** |
| C4 | `--skip` patterns on develop (comments stripped) | **3** — never widened |
| C5 | `git diff b090b2e origin/develop -- …diff.t.sol …SpecHelper.sol notes/DIFFERENTIAL_LAYOUT.md \| wc -c` | **0 bytes** |

Run-time half for C2/C3/C5: gate [`33184231798`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33184231798)
— 76 suites / 287 passed / 0 failed / 3 skipped; `compile-plank: 39 ok, 0 failed`; floor
`Suite result: ok. 10 passed`; differential 2× `[SKIP: spec oracle not wired…]` + 2× PASS.

## `--skip` decision

**MOOT (red)** — both masked suites measured RED in the 02-02 probe (#63), so nothing was retired.
No workflow edit: `git diff origin/develop -- .github/workflows/develop-gate.yml` → 0 bytes,
`check-ci-skip-ledger.sh` → `skip-ledger parity OK: 3 patterns, seed 4880`.

## Branch teardown

```
git log origin/develop..feat/volorder-t-minimal --oneline | wc -l   → 0
git branch -d feat/volorder-t-minimal                              → Deleted branch (was 56b3c4d)
git push origin --delete feat/volorder-t-minimal                   → [deleted]
local 0, remote 0
```

**`-d` succeeded on the first try; `-D` was never used.**

## Issue

**#61 CLOSED** (auto-closed by the PR's `Closes #61`), with [comment `5454339417`](https://github.com/JMSBPP/cfmm-vol-markets/issues/61#issuecomment-5454339417)
naming the merge SHA and quoting the live protection JSON.

## Planning edits (by hand — no gsd-tools state verb was called)

```
 .planning/REQUIREMENTS.md | 12 ++++++------      VORD-01..03 → [x] + Complete ×3
 .planning/ROADMAP.md      | 11 ++++++++---       Phase 2 [x], 5/5 Complete, 5 VERIFIED lines
 .planning/STATE.md        | 37 +++++++++++++---   phase-complete, 3 phases, 17/17, 7 decisions
```

`grep -c '^milestone: v1.0$' .planning/STATE.md` → **1** before and after.

## Note on the close-out push

This `.planning/`-only commit goes straight to `develop` and lands on `enforce_admins: false`
(`remote: - Required status check "gate" is expected`). It carries no source, so nothing compilable
skipped the gate — but it is an exemption, not a pass, stated here rather than glossed.
