---
phase: 11
slug: mev-hazard-inf-program
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-30
closed: 2026-07-31
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Filled at close-out (plan 11-06) from the executed plans, not from the draft template.**

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | lake (Lean 4 / Mathlib, toolchain `leanprover/lean4:v4.28.0`) + `aristotle` CLI |
| **Config file** | `lean/lakefile.toml` |
| **Quick run command** | `cd lean && lake build vol_markets` |
| **Full suite command** | `cd lean && lake build` + generated `#print axioms` sweep over every declaration |
| **Doc-layer command** | `bash scratch/mev-notation-gate.sh <file>` (PIT-1/2/3 notation gate) |
| **Estimated runtime** | ~11 s incremental; ~30 s for a new module's first elaboration |

Two verification layers ran in this phase, and they are not interchangeable:

1. **Machine-checked layer** — `lake build` exit code plus an axiom sweep whose input file is
   GENERATED from a grep of the module, so it cannot silently omit a declaration. Green builds are
   only meaningful once the module is registered as a lakefile root; both integration plans verified
   the `Built vol_markets.<Module>` log line for exactly that reason.
2. **Fidelity layer** — a statement-by-statement diff of every returned signature against the
   sha-pinned prompt. A quietly weakened theorem passes layer 1 and fails layer 2, which is why
   layer 2 exists and why its record (`11-03-FIDELITY.md`, `11-05-FIDELITY.md`) is a committed
   artifact rather than a transient check.

---

## Sampling Rate

- **After every task commit:** `lake build` on the touched module (integration plans only — the
  doc/prompt plans touch no `.lean` file and assert `git status --porcelain lean/` is EMPTY instead)
- **After every plan wave:** full suite command
- **Before `/gsd:verify-work`:** full suite must be green
- **Max feedback latency:** ~11 s (incremental), ~30 s (cold module)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | CTX-MEVDOC | doc gate | notation gate PASS on the addendum + `grep` for the M0–M8 block headers | ✅ | ✅ green |
| 11-01-02 | 01 | 1 | CTX-REVIEW | review gate | both reviewer reports exist; every BLOCKER/MAJOR row has a disposition line | ✅ | ✅ green |
| 11-01-03 | 01 | 1 | CTX-MEVDOC | checkpoint + doc gate | `sha256sum` pins recorded; extracted `### MEV` section gated PASS; `git status --porcelain lean/` empty | ✅ | ✅ green (blocking checkpoint: USER APPROVED) |
| 11-02-01 | 02 | 2 | CTX-PTRADE, CTX-MEVHAZ, CTX-INF | fidelity gate | `BUNDLED-DOC-SHA256` == `APPROVED-DOC-SHA256`; M-block byte diff empty; bundle module count | ✅ | ✅ green |
| 11-02-02 | 02 | 2 | CTX-REVIEW | review gate | both reviewer reports exist; 2 BLOCKERs + 3 MAJORs dispositioned before submit | ✅ | ✅ green |
| 11-02-03 | 02 | 2 | CTX-PTRADE, CTX-MEVHAZ, CTX-INF | submit gate | `aristotle projects --status RUNNING` empty before submit; prompt sha re-pinned at submit time | ✅ | ✅ green (task `IN_PROGRESS` at close, by design) |
| 11-03-01 | 03 | 3 | CTX-PTRADE, CTX-MEVHAZ, CTX-INF | build | `cd lean && lake build vol_markets` (8038 jobs) and `lake build` (8062 jobs), both exit 0; 10/10 bundled modules byte-identical | ✅ | ✅ green |
| 11-03-02 | 03 | 3 | CTX-PTRADE, CTX-MEVHAZ, CTX-INF | axiom + fidelity | generated `#print axioms` sweep, 25/25 clean; T1–T19 diff table; `git push` to both remotes | ✅ | ✅ green |
| 11-04-01 | 04 | 4 | CTX-JOINT, CTX-ANGSTROM | fidelity gate | doc sha re-verified against all three copies; M-block diffs empty (approved-vs-bundled AND approved-vs-live) | ✅ | ✅ green |
| 11-04-02 | 04 | 4 | CTX-REVIEW | review gate | both reviewer reports exist; the shared `probOr`-vs-addition BLOCKER dispositioned doc-over-plan | ✅ | ✅ green |
| 11-04-03 | 04 | 4 | CTX-JOINT, CTX-ANGSTROM | submit gate | queue-empty check; prompt sha pinned in `11-04-RUN-RECORD.md` | ✅ | ✅ green (task `IN_PROGRESS` at close, by design) |
| 11-05-01 | 05 | 5 | CTX-JOINT, CTX-ANGSTROM | build | `lake build vol_markets` (8039 jobs) and `lake build` (8063 jobs), both exit 0; 11/11 bundled modules byte-identical; `Built vol_markets.MevJointProgram` present | ✅ | ✅ green |
| 11-05-02 | 05 | 5 | CTX-JOINT, CTX-ANGSTROM | axiom + fidelity | generated `#print axioms` sweep, 27/27 clean; T20–T30 diff table with the explicit T24 verdict; comment-aware tax-constant scan; push both remotes | ✅ | ✅ green (verdict: **REFUTED**) |
| 11-06-01 | 06 | 6 | CTX-TRACE | doc + link gate | `grep -q MevOptimization/MevJointProgram/ptrade/'bridge identity'`; `! grep 'section (empty in the doc)'`; every backticked identifier resolves to a `^theorem`/`^noncomputable def` line in one of the two modules; `git status --porcelain lean/` empty | ✅ | ✅ green |
| 11-06-02 | 06 | 6 | CTX-TRACE | roadmap/state gate | all eight `CTX-*` ids present in the Phase-11 ROADMAP block and no `Requirements.*TBD`; six plan lines; `>= 6` `[Phase 11]` decisions in STATE; the T24 verdict and the bridge-identity caveat present; `cd lean && lake build` exit 0 | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Two mechanical criteria in this phase were themselves defective and are recorded as such rather
than satisfied by editing the artifact:** 11-05's tax-constant regex could not recognise Lean block
docstring continuation lines (re-verified with a comment-aware scanner — PASS), and 11-06's
identifier-existence loop reaches into §8's pre-existing `joint_candidates_disagree`, an
`EndogenousMaturity.lean` name outside this phase's two modules (verified present there instead).
11-06's `! grep '/home/'` criterion likewise false-fails on ROADMAP's own Phase-1 rows, which QUOTE
the home-path scrub command. Same class as 11-02's `ptradeCPMM`, 11-03's axiom-name grep and
11-04's phantom `lean`.

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No Wave 0 was needed: the Lean project, the
Mathlib pin, the `lake` build and the `aristotle` CLI were all in place from the FLAIR phase, and
this phase added modules to an existing `lean_lib` rather than standing up a framework.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Approval of the λ_MEV LaTeX block set (M0–M8) before it entered the plank-owned document | CTX-MEVDOC | The document is a human interface (minimal prose, maximal math) and belongs to another agent's worktree; no script can judge whether a transcription faithfully represents the user's intent | Read `VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` M0–M8 against the anchor PDF, then approve or reject at the blocking checkpoint in 11-01 (APPROVED 2026-07-30, verbatim reply recorded) |
| Aristotle task completion | CTX-PTRADE…CTX-ANGSTROM | The prover is an external service; completion is polled, not asserted locally (and `aristotle show` streams and blocks — poll with `aristotle tasks`) | `aristotle tasks` until `COMPLETE`, then hand to the integration plan |

Everything else in this phase has automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — 15/15 tasks carry one
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — none were missing
- [x] No watch-mode flags
- [x] Feedback latency < 11 s (incremental)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-31 (at phase close-out, plan 11-06)
