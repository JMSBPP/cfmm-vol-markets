---
phase: 01-red-differential-scaffold
plan: 02
subsystem: test-infra
tags: [solidity, differential-testing, seam, spec-oracle, red-phase]

# Dependency graph
requires:
  - "01-01: worktree `/home/jmsbpp/cfmms-playground/cfmm-wt/red-diff-scaffold` on `feat/red-diff-scaffold`"
provides:
  - "`test/protocol_integrations/SpecHelper.sol` on `feat/red-diff-scaffold` (commit `dd83cf9`)"
  - "`library SpecOracle` — the single Solidity<->Haskell-spec seam, shaped to the interface `evm-spec-bridge` will GENERATE"
  - "`SpecOracle.Status` / `.Guard` / `.TokenIdResult` / `.Health` — the three-outcome tagged envelope, expressible before any transport exists"
  - "`SpecOracle.health()` — THE single wiring predicate, reporting `Status.TransportFailure`"
  - "`SpecOracle.volOrderToTokenId(bytes,uint64)` — the always-reverting Phase 1 stub (`SpecOracleNotWired`)"
  - "`contract SpecHelperProbe` — the hand-written external call boundary that makes the stub's revert catchable"
affects: [01-03, 01-04, 01-05, 01-06, phase-04, phase-05, phase-07, phase-09, phase-11]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fail-safe RED stub: the seam REVERTS rather than returning a zero-valued struct, so a caller who forgets to check `status` cannot silently agree on a fabricated `tokenId == 0`"
    - "One wiring mechanism: `isWired()` collapsed into `health()` — two mechanisms are two things that can drift"
    - "Library-internal seam + external probe contract, so an inlined revert becomes an observable one"
    - "Dependency-free test seam (no forge-std, no `lib/` imports) so a broken submodule checkout can never be mistaken for a broken seam"

key-files:
  created:
    - test/protocol_integrations/SpecHelper.sol
  modified: []

key-decisions:
  - "`Status` lives as a field ON `Health` rather than returning `(Status, Health)` — every generated result type is tagged uniformly, `health()` stays single-value, and the skip predicate is literally `health().status == Status.TransportFailure`, the SAME predicate Phase 7 keeps. PROVISIONAL pending generation."
  - "The Phase 1 stub REVERTS rather than returning a tagged struct. This is the stub's behaviour, NOT the interface's contract: Phase 7's real implementation returns the struct (including `TransportFailure`) and does not revert, because a revert would destroy the guard identity GUARD-05 needs."
  - "`health()` returns the full `Health` struct, never a bool/string — a simple-typed health method round-trips cleanly while the domain path is broken, which is a green that proves nothing."
  - "Mutability left unrestricted (neither `view` nor `pure`); solc warning 2018 is EXPECTED and must not be 'fixed', because Phase 7 implements these bodies over the state-mutating `vm.rpc`."

requirements-completed: [RED-04]

# Metrics
duration: 3min
completed: 2026-08-27
---

# Phase 1 Plan 02: SpecOracle Seam — Reverting Stub + health() Wiring Predicate Summary

**The one Solidity<->Haskell-spec seam now exists on `feat/red-diff-scaffold` as `test/protocol_integrations/SpecHelper.sol` (183 lines, commit `dd83cf9`): a generated-shape `library SpecOracle` carrying the `Status`/`Guard`/`TokenIdResult`/`Health` tagged envelope, a `health()` that reports `TransportFailure` as the single wiring predicate, and a `volOrderToTokenId(bytes,uint64)` whose only statement is a revert naming its input — plus the hand-written `SpecHelperProbe` boundary that makes that revert observable instead of fatal.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-27T17:20:41Z
- **Completed:** 2026-08-27T17:23:36Z
- **Tasks:** 1
- **Files modified:** 1 created

## Accomplishments

- **RED-04 satisfied in both halves.** An entrypoint that reverts when called
  (`volOrderToTokenId` → `SpecOracleNotWired(volOrderWire, poolId)`) and a wiring predicate the
  test can query first (`health()` → `Status.TransportFailure`). Only the names moved from the
  original draft, to follow the interface `evm-spec-bridge` generates.
- **The seam is shaped to the GENERATED interface, so Phase 7 adopts it rather than redesigning
  it** — RED-06's "extend rather than redesign" made concrete. The library is
  `SpecOracle`, the entrypoint is `volOrderToTokenId(bytes,uint64)`, and the file path stayed
  `test/protocol_integrations/SpecHelper.sol` so the branch's four-file diff is unchanged.
- **The three outcomes are expressible in the type before any transport exists.**
  `Status { Ok, Rejected, TransportFailure }` — the XPORT-02 distinction that measurement showed
  cannot be recovered from selectors, since JSON-RPC error objects, HTTP 500, connection-refused,
  timeout and absent-cheatcode all revert with the same `CheatcodeError(string)` = `0xeeaa9e6f`.
- **`isWired()` is gone, collapsed into `health()`.** One wiring mechanism, verified by
  `grep -c 'function isWired'` = 0.
- **The fail-safe rationale and the assert-on-success measurement are written into the file, not
  implied.** The natspec carries `45 s`, `3.2 hours`, `1.5.1-stable` and `MUST bind its` — a rule
  with its evidence attached survives; a bare rule gets "simplified" away.
- **Nothing in the file depends on unresolved transport mechanics**, so no open question
  (RPC-02's responsibility split, VORD-06's wire format, the `try`/`catch`-vs-cheatcode question)
  can force it to be rewritten. `volOrderWire` is `bytes` precisely so that choosing the format
  changes the encoder and not this seam.

## Task Commits

1. **Task 1: Write SpecHelper.sol** — `dd83cf9` on `feat/red-diff-scaffold`
   (`test(01-02): SpecOracle seam - reverting volOrderToTokenId stub + health() wiring predicate (RED-04)`)

**Plan metadata:** see final `docs(01-02)` commit on `develop`.

## Exported Names (what plan 01-03 imports)

| Name | Kind | Role |
|------|------|------|
| `SpecOracle` | library | the seam itself; replaced by the generated artifact in Phase 7 |
| `SpecHelperProbe` | contract | hand-written external call boundary; survives Phase 7 unchanged |
| `SpecOracleNotWired(bytes,uint64)` | error | raised by the Phase 1 stub ONLY, naming the offending input |
| `Status` | enum | `Ok`, `Rejected`, `TransportFailure` — in that order |
| `Guard` | enum | `None`, `OptionRatioRange`, `LegSpanBelowSpacing`, `TickOutOfBounds` — GUARD-01/02/03 |
| `TokenIdResult` | struct | `{ Status status; uint256 tokenId; Guard guard; string detail; }` |
| `Health` | struct | `{ Status status; string specCommit; uint32 protocolVersion; string bridgeVersion; }` |
| `health()` | function | THE wiring predicate; returns `Health memory`; not `view`/`pure` |
| `volOrderToTokenId(bytes,uint64)` | function | the reverting stub; returns `TokenIdResult memory`; not `view`/`pure` |

Binding notes for 01-03's call sites: reach the probe with a low-level
`address(probe).call(...)` rather than `try`/`catch`; bind `(bool ok, bytes ret)` and assert on
`ok` BEFORE touching `ret`; probe `health()` once in `setUp` and cache; never assert on
`TokenIdResult.detail`.

## The Two Provisional Decisions This File Bakes In

1. **`Status` lives ON `Health`** (a field), not returned alongside it as `(Status, Health)`.
   Every generated result type is then tagged uniformly with the same enum, `health()` stays a
   single-value return, and the skip predicate is literally
   `health().status == Status.TransportFailure` — the SAME predicate Phase 7 keeps against a live
   endpoint. **Provisional pending generation:** if `evm-spec-bridge`'s generator emits a
   different arrangement, Phase 7 adopts the generator's and records why the two differ.
2. **The Phase 1 stub REVERTS rather than returning a tagged struct.** This is the stub's
   behaviour, deliberately fail-safe: a struct-returning stub is fail-open, because a test that
   forgot to check `status` would proceed silently with `tokenId == 0`, which is exactly the
   false-green class this milestone exists to eliminate. It is **not** the interface's contract —
   Phase 7's real implementation RETURNS the struct (including `Status.TransportFailure`) and does
   NOT revert, because a revert would make spec rejection indistinguishable from a genuine
   Solidity revert and would destroy the guard identity Phase 9's revert-vs-return assertion needs
   (GUARD-05).

## Files Created/Modified

- `test/protocol_integrations/SpecHelper.sol` (created, 183 lines) — byte-identical to the
  content the plan mandated verbatim. No imports, no cheatcode calls, no `isWired`, no
  low-level call in code.

## Verification Performed

All verification was **static** (grep / awk / file read / git plumbing), by design. **No local
build was run** — `forge`, `make`, `npm ci` and `cabal` were never invoked; submodules remain
uninitialized and `develop-gate` (which triggers on `pull_request` only) is the sole build
environment. The claim "this file compiles" is NOT made here; it belongs to the gate, at wave 5
when plan 01-05 opens the PR.

| Criterion | Result |
|-----------|--------|
| Plan's `<automated>` verify block | PASS (`OK`) |
| File exists, `wc -l` >= 120 | PASS (183) |
| `grep -c '^import'` == 0 | PASS |
| No `vm.ffi` / `vm.readFile` / `vm.envOr` | PASS |
| `vm.rpc` as a call == 0 (prose only, 2 natspec mentions) | PASS |
| Exact lines: `library SpecOracle {`, `    enum Status {`, `    enum Guard {`, `    struct TokenIdResult {`, `    struct Health {` | PASS (1 each) |
| `Status` members in order `Ok`, `Rejected`, `TransportFailure` | PASS |
| `Guard` members in order `None`, `OptionRatioRange`, `LegSpanBelowSpacing`, `TickOutOfBounds` | PASS |
| `GUARD-01` / `GUARD-02` / `GUARD-03` mapped in the `Guard` natspec | PASS |
| `Health`'s first field is exactly `        Status status;` | PASS |
| Exact line `    error SpecOracleNotWired(bytes volOrderWire, uint64 poolId);` | PASS |
| `grep -c 'SpecOracleNotWired'` >= 2 | PASS (3) |
| Exact line `    function health() internal returns (Health memory) {` + body `            status: Status.TransportFailure,` | PASS |
| Exact line `        revert SpecOracleNotWired(volOrderWire, poolId);` | PASS |
| Stub has NO return path (`grep -c 'return '` inside its body == 0) | PASS |
| `grep -c 'function isWired'` == 0 | PASS |
| No `view`/`pure` on `health` or `volOrderToTokenId` | PASS |
| `health()` not simple-typed (`bool`/`string`) | PASS |
| Required literals: `RED-04`, `RED-06`, `GENERATES`, `evm-spec-bridge`, `PROVISIONAL`, `FAIL-SAFE`, `FAIL-OPEN`, `Phase 4/5/7/9/11`, `GUARD-05`, `notes/DIFFERENTIAL_LAYOUT.md` | PASS (all) |
| Assert-on-success rule with evidence: `MUST bind its`, `45 s`, `3.2 hours`, `1.5.1-stable` | PASS |
| `health()` natspec: `NOT A BARE-STRING PING`, `SAME tagged envelope` | PASS |
| `detail diagnostics ONLY` present | PASS |
| `grep -c '\.call('` == 0 | **See deviation 1** — 1 match, natspec prose only; 0 in code |
| File byte-identical to the plan's mandated block (`diff` clean) | PASS |
| `git log -1 --name-only` lists the file; branch is `feat/red-diff-scaffold` | PASS |
| Branch diff vs branch point touches ONLY `SpecHelper.sol` | PASS (1 file, +183) |
| Nothing in `src/`, `.github/`, or `VolOrderToPanopticTokenId.t.sol` changed | PASS |
| No `out/` and no `cache/` in the worktree | PASS |

## Decisions Made

- **Committed only the one named file.** `git add test/protocol_integrations/SpecHelper.sol`
  explicitly; no `git add -A` / `git add .`. The worktree was otherwise clean, so none of the
  main checkout's pre-existing dirty entries were at risk here.
- **Did not push.** Plan 01-05 owns the push and the PR; `develop-gate` triggers on
  `pull_request` only, so pushing now would start no run.
- **Scope check performed against the merge-base, not against `develop` directly.** A raw
  `git diff develop --stat` shows ~10 `.planning/` files, which is `develop` having advanced past
  the branch point (`04dea0a`) with planning-doc commits — not this plan's edits. Measured from
  the merge-base, the branch changes exactly one file. Verified that every one of develop's 10
  extra commits is `.planning/`-only, so the branch carries no code drift.

## Deviations from Plan

### Documented Criterion Conflict (no code change)

**1. [Rule 1 - Plan-internal contradiction] The `grep -c '\.call('` == 0 criterion cannot hold
against the plan's own mandated content**

- **Found during:** Task 1 acceptance-criteria verification
- **Issue:** The plan mandates the file's content **verbatim** ("Create ... with EXACTLY this
  content"), and that content includes the natspec line
  `///      CALLERS SHOULD REACH THIS WITH A LOW-LEVEL \`address(probe).call(...)\` RATHER THAN`
  (line 168). The acceptance criterion `grep -c '\.call(' … returns 0` does not exclude comment
  lines, so it returns 1 against the very content the plan requires.
- **Analysis:** The criterion states its own intent inline — "Phase 1's seam makes no low-level
  call; the assert-on-success rule below is documented, not exercised." That intent is satisfied:
  the single match is `///` natspec prose, and stripping comment lines gives **0**. The criterion
  is simply written more loosely than its sibling `vm.rpc` criterion, which explicitly matches
  call-shaped lines only (`^\s*(\(bool|bytes).*vm\.rpc`) precisely because the plan anticipated
  the same prose-vs-call distinction there.
- **Fix:** **None applied to the file.** Verbatim mandated content wins over a derived regex, and
  the offending line is load-bearing — it records the open `try`/`catch`-vs-cheatcode question
  that STATE.md flags as the lowest-confidence transport item. Deleting it to satisfy a grep would
  destroy real information. Verified the intent instead:
  `grep -vE '^\s*(///|//|\*|/\*)' SpecHelper.sol | grep -c '\.call('` returns `0`, and the file
  `diff`s clean against the plan's mandated block.
- **Files modified:** none
- **Recommendation for plan 01-06:** if it re-asserts this criterion on `develop`, tighten it to
  the comment-stripped form so it matches its stated intent.

---

**Total deviations:** 1, documentation-level only. No code deviated from the plan; the file is
byte-identical to the mandated block. No architectural change, no scope creep, no auto-fix
attempts consumed.

## Issues Encountered

None. No auth gates, no blockers, no checkpoints.

## User Setup Required

None.

## Next Phase Readiness

**Ready.** Plan 01-03 can begin immediately:

- `SpecOracle` and `SpecHelperProbe` exist and are importable from
  `test/protocol_integrations/SpecHelper.sol` on `feat/red-diff-scaffold`.
- 01-03 reuses the existing suite's `_packVO` helper and `harness.staticcall(...)` pattern from
  `VolOrderToPanopticTokenId.t.sol` (the regression floor) — this file neither duplicates nor
  contradicts them.
- 01-03's wiring probe must decode the **full `Health` struct**, not a bool or a string — that is
  the Solidity-level exercise of the tagged envelope.
- Call sites must bind `(bool ok, bytes ret)` and assert `ok` before touching `ret`, and use a
  low-level call rather than `try`/`catch`.
- Still no local builds. Gate evidence arrives with the PR in plan 01-05.

---
*Phase: 01-red-differential-scaffold*
*Completed: 2026-08-27*

## Self-Check: PASSED

All claimed artifacts verified to exist:
- `test/protocol_integrations/SpecHelper.sol` on `feat/red-diff-scaffold` — FOUND (183 lines)
- Commit `dd83cf9` — FOUND (`git log --oneline --all`)
- `.planning/phases/01-red-differential-scaffold/01-02-SUMMARY.md` — FOUND
- `grep -c 'SpecOracleNotWired'` == 3 — CONFIRMED (matches the summary's stated count)
- comment-stripped `grep -c '\.call('` == 0 — CONFIRMED (deviation 1's intent check)

No build claim is made: `develop-gate` has not run against this commit, by design.
