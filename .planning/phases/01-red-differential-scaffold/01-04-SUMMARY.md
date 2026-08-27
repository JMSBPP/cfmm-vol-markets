---
phase: 01-red-differential-scaffold
plan: 04
subsystem: testing
tags: [differential-testing, foundry, json-rpc, haskell-spec, plank, documentation, makefile]

requires:
  - phase: 01-02
    provides: "SpecHelper.sol — the SpecOracle seam, SpecHelperProbe boundary, and the natspec cross-reference to notes/DIFFERENTIAL_LAYOUT.md that this plan makes resolve"
  - phase: 01-03
    provides: "VolOrderToPanopticTokenId.diff.t.sol — the doctrine, discipline and probe-once patterns this document points at rather than restates"
  - phase: 01.1
    provides: ".github/foundry-version + notes/TOOLCHAIN_PINS.md — the pin that closes this document's headline open risk and scopes every measurement in it"
provides:
  - "notes/DIFFERENTIAL_LAYOUT.md — the binding organization of the Haskell<->Plank differential: layout, naming, the Solidity<->spec seam, the generated-interface boundary, ten measured transport constraints each carrying its measurement, the three-outcome contract, the probe lifecycle, and per-phase extension points"
  - "make test-vol-order-tokenid-diff — the per-.diff.t.sol convenience target for the new differential"
  - "A written record that spec transport is RESOLVED (JSON-RPC) with the outside-Phase-5 override visible, and that wire format (Phase 4), oracle packaging (Phase 6) and RPC-02 (Phase 5) remain OPEN"
affects: [phase-04-wire-format, phase-05-rpc-design, phase-06-spec-oracle, phase-07-spec-transport, phase-09-guard-parity, phase-11-ci-enforcement]

tech-stack:
  added: []
  patterns:
    - "Measured constraints are recorded WITH their measurement, never as bare rules"
    - "Per-.diff.t.sol make target named test-<subject>-diff"

key-files:
  created:
    - notes/DIFFERENTIAL_LAYOUT.md
    - .planning/phases/01-red-differential-scaffold/deferred-items.md
  modified:
    - Makefile

key-decisions:
  - "RED-06 is satisfied by a notes/ document, not a .planning/ document, because both source files already cite it by that path and notes/ is this repo's binding-spec directory"
  - "The 'Foundry is UNPINNED' open risk is recorded as CLOSED by Phase 1.1 (CI-05) rather than copied forward as live — the /gsd:insert-phase candidacy it proposed already happened; the residual recorded instead is that a pin BUMP invalidates every measurement in the document"
  - "eth_rpc_timeout is named in the document as a knob that does NOT reach vm.rpc, overriding an acceptance criterion that forbade the token — the criterion's intent (record no usable knob) is met, and naming the key is what stops a future engineer rediscovering it"

patterns-established:
  - "A rule with its evidence attached survives; a bare rule gets simplified away — every transport constraint in DIFFERENTIAL_LAYOUT.md carries the measurement that produced it"
  - "Open decisions are tabled with an OWNING PHASE and a constraint any answer must satisfy, and are never pre-resolved by the document that records them"

requirements-completed: [RED-06]

duration: 23min
completed: 2026-08-27
---

# Phase 1 Plan 04: Differential Layout + Make Target Summary

**`notes/DIFFERENTIAL_LAYOUT.md` (325 lines, ten sections) now fixes the shape of the
Haskell↔Plank differential — the seam, the generated-interface boundary, ten transport
constraints each carrying its measurement, and the three-outcome contract — so Phases 6–11
extend it rather than redesign it; plus `make test-vol-order-tokenid-diff`.**

## Performance

- **Duration:** 23 min (incl. one 2 min CI run)
- **Started:** 2026-08-27T21:00Z (approx)
- **Completed:** 2026-08-27T21:23Z
- **Tasks:** 2/2
- **Files modified:** 2 source + 3 planning

## Task Commits

1. **Task 1: Write notes/DIFFERENTIAL_LAYOUT.md** — `8bdec47` (docs)
2. **Task 2: Add the test-vol-order-tokenid-diff Makefile target** — `470c916` (chore)

## CI verification — push-build run `33117651701` (`470c916`), conclusion **SUCCESS**

Every step green: skip-ledger parity, pinned toolchain install, version stamp, submodules,
plank toolchain, `npm ci`, `forge build`, `forge test`.

```
forge Version: 1.5.1-v1.5.1
Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2

Ran 10 tests for test/protocol_integrations/VolOrderToPanopticTokenId.t.sol:VolOrderToPanopticTokenIdTest
Suite result: ok. 10 passed; 0 failed; 0 skipped

Ran 75 test suites in 5.96s: 273 tests passed, 0 failed, 3 skipped (276 total tests)
```

Two things worth naming:

- The suite total is **byte-identical to `ef186ec`** (273/0/3/276). A docs-and-Makefile plan that
  moved the suite would have been the finding; it did not.
- The runner's `forge` stamped **`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`** — the exact commit
  every measurement in `DIFFERENTIAL_LAYOUT.md` is scoped to. The document's measurement scope and
  the gate's actual binary are now the same thing, verified in the same run that accepted the
  document. That is the property Phase 1.1's pin exists to provide, observed for the first time in
  service of a claim that depends on it.
- Regression floor `VolOrderToPanopticTokenId.t.sol` held at 10/10. `.github/` untouched.

## `notes/DIFFERENTIAL_LAYOUT.md` — final heading list

```
  8:## Scope
 18:## File layout and naming
 44:## The Solidity<->spec transport boundary
 79:## The generated interface boundary
112:## Transport mechanics: measured constraints
198:## Outcome contract: three states, never conflated
228:## The wiring probe and its lifecycle
250:## Doctrine and discipline
272:## Open decisions, open questions and open risks
306:## Extension points, phase by phase
```

All ten mandated H2 headings, verbatim, in the mandated order. 325 lines (floor was 140).

## The four-file branch diff plan 01-05 opens a PR for

`git diff develop HEAD --name-only`, source files only:

```
Makefile
notes/DIFFERENTIAL_LAYOUT.md
test/protocol_integrations/SpecHelper.sol
test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol
```

`git diff develop -- .github/` is EMPTY — the skip is still self-computed, not a ledger entry.
`git diff develop -- Makefile | grep -c '^-[^-]'` is `1`, the rewritten `.PHONY` line, and
`grep -c '^\.PHONY' Makefile` is `3` on both sides. No `lib/*` submodule pin was staged: the
working tree carries seven `lib/*` checkouts at non-pinned commits from an earlier local
`forge test` attempt, and every commit here named its files explicitly.

## Open, carried forward for later phases

The document records these as OPEN and picks none of them.

**Open decisions (owned):**

| Decision | Owner |
|---|---|
| `VolOrder(T)` wire format — Shock-style tagged vs per-variant | Phase 4 (VORD-06) |
| Oracle packaging — new cabal exe vs a mode on `cfmm-scratchpad-exe` | Phase 6 |
| RPC-02 — the responsibility split | Phase 5 |

**Open questions (no owner; answer before Phase 7 relies on them):**

- **Does `try`/`catch` catch a cheatcode-originated revert?** It does an `extcodesize` check
  against the cheatcode address. The LOWEST-confidence item in the transport analysis, and the
  entire three-way outcome distinction rests on catching that revert. Mitigated, not answered, by
  using a low-level `address(...).call(...)` at the boundary — which is what `SpecHelper.sol`'s
  natspec and this document both prescribe.
- **Does an end-to-end round trip against a NON-Ethereum JSON-RPC server actually work?**
  `vm.rpc` forwarding an arbitrary method string is verified from source (`raw_request`, no
  allowlist, no handshake), but a full round trip has **no known prior art**. Phase 5's RPC-03
  skeleton is what answers it.

**Open risks:** the two live ones are (a) a **pin bump** silently invalidating every measurement
in the document — mitigated in three layers, pin prevents / version stamp reveals / the Phase 5
coercion-conformance fixture fails; and (b) the CI ordering tension, since a service transport
means Phase 5 itself needs the runner to build and run a Haskell process while CI-01/CI-02 sit in
Phase 11.

## Deviations from Plan

### 1. [Rule 1 — Stale fact] The "Foundry is UNPINNED" risk was FALSE as written

- **Found during:** Task 1, while reading `.planning/STATE.md` Blockers/Concerns.
- **Issue:** The plan mandated an open-risks row asserting "no version key in `foundry.toml`, no
  `foundry-toolchain` action or `foundryup` step in `develop-gate`, no `.foundryrc`, no
  `.tool-versions`", with `/gsd:insert-phase` as the disposition. Every clause of that was true
  when it was written and is **false now**: Phase 1.1 (CI-05) landed `.github/foundry-version`
  (release + commit + foundryup installer commit), both workflows install into a per-pin directory
  and assert `forge --version` contains the commit, and `notes/TOOLCHAIN_PINS.md` documents why.
  The `/gsd:insert-phase` candidacy the plan proposed is the insertion that already happened.
  Writing it as a live risk in a BINDING document would have made the document lie on its first
  day, about the one property every other claim in it depends on.
- **Fix:** The row is recorded as **CLOSED as an open risk by Phase 1.1 (CI-05)**, with the
  history preserved (it names `UNPINNED` and `insert-phase` verbatim, satisfying the acceptance
  criterion's letter as well as its intent) and with the genuine RESIDUAL named instead: a pin
  BUMP invalidates every measurement in the document, which `notes/TOOLCHAIN_PINS.md` §6 makes
  part of the bump procedure. A second row was added for the pin-bump reclassification risk and
  its three-layer mitigation.
- **Files:** `notes/DIFFERENTIAL_LAYOUT.md`
- **Commit:** `8bdec47`
- **Also stale, NOT fixed here:** the same bullet is still live in `.planning/STATE.md`
  Blockers/Concerns. Corrected in this plan's STATE.md update.

### 2. [Criterion defect] `eth_rpc_timeout` — mandated content vs a criterion forbidding it

- **Found during:** Task 1 verification.
- **Issue:** The plan's mandated text for constraint 5 says "neither `eth_rpc_timeout` nor a
  per-endpoint `retries` key reaches it", while the plan's own acceptance criteria require
  `grep -qi 'eth_rpc_timeout' "$F"` to **FAIL**. The two cannot both hold. This is the **seventh**
  occurrence of the class 01-03 hit three times: a `grep`-based prohibition over a token the
  document must also DISCUSS forbids its own documentation.
- **Fix:** The criterion's stated intent is "no non-existent tuning knob is recorded". The
  document records the opposite of a knob — it names `eth_rpc_timeout` explicitly as a key that
  does NOT reach `vm.rpc`'s code path, followed by "**There is no tuning knob; do not go looking
  for one.**" Naming the key is the whole value: it is exactly what a future engineer would reach
  for. **No mandated content was deleted to satisfy a regex.** The literal grep criterion is
  recorded here as not-met, deliberately.
- **Files:** `notes/DIFFERENTIAL_LAYOUT.md`
- **Commit:** `8bdec47`

### 3. [Criterion defect] "exactly four paths" in the branch diff

- **Issue:** Task 2's criterion required `git diff develop --name-only` to return exactly four
  paths. It returns nine, because `.planning/ROADMAP.md`, `.planning/STATE.md`,
  `.planning/phases/01-red-differential-scaffold/01-03-SUMMARY.md`, `01-04-PLAN.md` and
  `docs/superpowers/plans/2026-08-27-*.md` are committed on this branch — required by the
  inline-tree workflow, which lands planning artifacts on `feat/red-diff-scaffold` and merges them
  at 01-06. The criterion predates that workflow change.
- **Fix:** Verified the criterion's intent — the SOURCE diff is exactly the four named files, and
  `git diff develop -- .github/` is empty. Recorded above.

### 4. [Process] Two commits, not one

The plan's Task 2 block committed both files together. The executor's task-commit protocol
requires one commit per task, so this landed as `8bdec47` (document) then `470c916` (Makefile).

### 5. [Process] Pushed, contrary to the plan's "Do NOT push"

The plan reserved the push for 01-05. The orchestrator prompt overrides this: local `forge`/`make`
cannot run here (submodules deliberately uninitialized), so `push-build` is the ONLY way to verify
the Makefile edit broke nothing. Pushing a branch is not opening the PR — 01-05 still owns the PR
and the `develop-gate` run, which is the evidence Phase 1 criteria 1–3 are actually stated against.

### 6. [Out of scope, logged not fixed] RED-01/02/03/05 still `Pending` in REQUIREMENTS.md

Plan 01-03 satisfied and CI-verified all four but did not tick them (it ran via the superpowers
path). This executor ticked **RED-06 only** — its own. Logged in
`.planning/phases/01-red-differential-scaffold/deferred-items.md` for 01-05/01-06.

## Requirements

- **RED-06** — SATISFIED. The organization is documented at `notes/DIFFERENTIAL_LAYOUT.md`, the
  path both `SpecHelper.sol` (5 citations) and `VolOrderToPanopticTokenId.diff.t.sol`
  (2 citations) already point at; those cross-references now resolve to a real file. Ticked in
  `REQUIREMENTS.md` and in the ROADMAP's Phase 1 plan list.

## Self-Check: PASSED

- `notes/DIFFERENTIAL_LAYOUT.md` — FOUND (325 lines, all ten headings verbatim in order)
- `Makefile` — FOUND (`test-vol-order-tokenid-diff` target, tab-indented, in `.PHONY`)
- `.planning/phases/01-red-differential-scaffold/01-04-SUMMARY.md` — FOUND
- `.planning/phases/01-red-differential-scaffold/deferred-items.md` — FOUND
- Commit `8bdec47` — FOUND
- Commit `470c916` — FOUND
- push-build run `33117651701` on `470c916` — conclusion SUCCESS, verified via `gh run view`
- `grep -c '^milestone: v1.0$' .planning/STATE.md` → `1` (state-writing verbs were NOT used; every
  STATE.md / ROADMAP.md / REQUIREMENTS.md change was made by hand and proven with `git diff`)
- No `lib/*` submodule, `spec`, `offchain` or `.planning/config.json` staged in any commit
