---
phase: 12-eta-tradeoff-optimum
plan: 04
subsystem: traceability / documentation close-out
tags: [traceability, notation, back-annotation, sha-pinning, open-ledger, capponi-jia, eta, close-out]
requires:
  - phase: 12-03
    provides: "EtaCurvature.lean (51 decls, axiom-clean) and 12-03-FIDELITY.md — the ONLY source of the status words used here"
  - phase: 12-01
    provides: "The approved E0-E8 blocks, the APPROVED-ETA-SHA256 pin this plan discloses as invalidated, and the NARROWED CTX-DEGEN ruling"
  - phase: 11
    provides: "The 11-06 close-out standard, §7.1's claim-row format, and the two mechanical-criterion defects fixed here rather than repeated"
provides:
  - "LEAN_TRACEABILITY §0: ETA symbol rows (premia explicitly marked NOT probabilities), the binding Capponi remap/absorption paragraph, and the eta-identity outcome recorded as PARTIALLY discharged"
  - "LEAN_TRACEABILITY §7.2: the ETA layer entry point + the nine-item E8 OPEN ledger, cross-linked with §13 rather than duplicating it"
  - "LEAN_TRACEABILITY §6(b) AMENDED: varrho_I as a partial carrier for the demand-elasticity gap, with the remainder named"
  - "The ETA addendum's > LEAN back-annotation, mirrored byte-identical from the plank copy (a real drift, closed)"
  - "The sha-pin invalidation, DISCLOSED in the addendum header with the reason it is safe"
  - "../plank/todo.md line 227: the closing controller-law answer with its three caveats and no invented proxy (uncommitted, owner ul2inqpl)"
  - "ROADMAP Phase 12 closed with per-plan outcomes, the contingency disposition, and the no-FOC planning correction confirmed as machine-checked"
  - "REQUIREMENTS.md: the seven Phase-12 CTX-* ids adopted and marked, CTX-DEGEN as NARROWED"
affects:
  - "plank (ul2inqpl) — the controller law and the hook-mapping scope statement"
  - "any future consumer of the ETA layer — §7.2's OPEN ledger is what stops it being over-cited"
tech-stack:
  added: []
  patterns:
    - "Scope a mechanical identifier-existence check to the NEW section, so it cannot false-fail on pre-existing rows elsewhere"
    - "Un-backtick prose tokens when the identifier check catches them, rather than loosening the check"
    - "When a claim table already exists under a different section number, CROSS-LINK it and add only what is missing — never write a second copy of the same statuses"
    - "Disclose an intentional sha-pin invalidation in the artifact header, with the reason it is safe, rather than letting a later reader diagnose drift"
    - "Deliver the LAW, never invent a PROXY for an unobservable parameter"
key-files:
  created:
    - .planning/phases/12-eta-tradeoff-optimum/12-04-SUMMARY.md
  modified:
    - model/vol_markets/LEAN_TRACEABILITY.md
    - model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md
    - ../plank/todo.md (WRITTEN, NOT COMMITTED — owner ul2inqpl)
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/STATE.md
key-decisions:
  - "§7.2 is the ETA entry point + the E8 OPEN ledger, NOT a second claim table — §13 already landed with the module at b02caf7 and duplicating its statuses would create two sources of truth"
  - "The plank `## ETA` `> LEAN` annotation was VERIFIED, not rewritten; the addendum's MISSING copy was the real defect and was mirrored byte-identical"
  - "12-RESEARCH.md left UNEDITED — a dated research artifact; its three carried-forward defects are corrected where a later plan would actually read them"
  - "The seven CTX-* ids were adopted into REQUIREMENTS.md for Phase 12 ONLY; phases 8-11's ids stay declared in ROADMAP.md, recorded as a known gap rather than silently back-filled"
  - "CTX-DEGEN is marked SATISFIED AS NARROWED everywhere it appears — never as plain satisfied"
requirements-completed: [CTX-TRACE]
metrics:
  duration: 11 min
  tasks: 3
  files: 6
  completed: 2026-08-02
---

# Phase 12 Plan 04: ETA Traceability and Phase Close-Out Summary

**The ETA layer made auditable without re-derivation: §0 notation rows with the premia explicitly marked as non-probabilities, a binding Capponi remap paragraph carrying the `arbLossRatio`/`mevMulti` non-identification, a nine-item OPEN ledger at §7.2, an amended §6(b), the addendum's missing `> LEAN` annotation restored, the sha-pin invalidation disclosed, and plank's line-227 η question answered with a quotable controller law and no invented proxy.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-08-02T13:41:35Z
- **Completed:** 2026-08-02T13:52:49Z
- **Tasks:** 3 (plus one out-of-plan task: the retroactive 12-03 record)
- **Files modified:** 6 (5 in this tree, 1 in the plank worktree — written, not committed)

## Accomplishments

- **§0 now carries the ETA layer's notation**, including the single most consequential correction available here: `ϱ_I` and `ϱ_S` are declared **PREMIA, NOT PROBABILITIES** in the row text itself, because under the probability misreading (which `12-CONTEXT.md` contains) `κ_φ⋆ = 1 − √((1+φ)/(1+ϱ_I))` is uninterpretable and the demand-side link to §6(b) is lost.
- **The binding remap paragraph** records what was remapped, what was ABSORBED and why (`θ` collides with option theta, `κ` with the Phase-11 scalarization weight), that `f` is IDENTIFIED with `φ`, that **`η` is PROTECTED and the phase's notation gate INVERTS Phase-11's Rule 1**, that `ν` was avoided, that the `λ` overload (tick base vs subscripted hazard) is deliberate and neither usage was renamed, and that **`arbLossRatio` and `mevMulti` are NOT IDENTIFIED**.
- **The η-identity is recorded at exactly the strength the fidelity record supports** — exponent half PROVEN (naming `priceEta_eq_p_eta_half` / `priceEta_eq_P_half`), factor-share half OPEN, so the user's decision is **PARTIALLY discharged**, citing `exp/eta.lean`'s own `P_half` docstring ("η does not enter the tick→price map") as the reason the second half is a modelling claim rather than a rewriting.
- **§7.2 carries the nine-item E8 OPEN ledger** — the equilibrium transfer first — and names `exp/DynamicsOptimization` explicitly so the headline is never read as a duplicate of that module's hypothesized interior-η claim.
- **§6(b) was AMENDED, not deleted**: `ϱ_I` is a PARTIAL carrier for the demand-elasticity gap, with the equilibrium transfer and MMR §7.3 eq. (27) named as what remains.
- **A real drift was found and closed:** the plank copy carried the `> LEAN` back-annotation; this tree's addendum carried **none**.
- **plank's line-227 question is answered** with the law, four strict comparative statics, the carriers, and three caveats — and **no on-chain proxy for `ϱ_I` was invented**.

## Task Commits

1. **(out of plan) Retroactive 12-03 record** — `e4447ff` (docs) — `12-03-SUMMARY.md` written from git and on-disk ground truth, with a re-verification table separating what was re-run from what is inherited.
2. **Task 1: LEAN_TRACEABILITY** — `f623bd3` (docs) — §0 rows, the binding paragraph, the η-identity outcome, §7.2, the §6(b) amendment.
3. **Task 2: addendum mirror + pin disclosure + todo answer** — `dedc66f` (docs) — this tree's addendum only; `../plank/todo.md` written, not committed.
4. **Task 3: close-out** — see plan metadata commit below — ROADMAP, REQUIREMENTS, STATE.

## Files Created/Modified

- `model/vol_markets/LEAN_TRACEABILITY.md` — §0 (rows + binding paragraph + η-identity outcome), §6(b) amendment, new §7.2, §13 back-link.
- `model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md` — header sha-pin disclosure + M-block baseline; the mirrored `> LEAN` / `> AMENDED` annotation.
- `../plank/todo.md` — the closing line-227 answer. **Written, NOT committed** (owner `ul2inqpl`; plank HEAD `08039da` before and after).
- `.planning/ROADMAP.md` — Phase 12 closed: per-plan outcomes, the contingency disposition, the planning-correction confirmation, the phase-outcome block.
- `.planning/REQUIREMENTS.md` — the seven Phase-12 `CTX-*` ids adopted, with traceability rows.
- `.planning/STATE.md` — the Phase 12 close-out in the established voice.

## Verification

| Check | Result |
|---|---|
| `### 7.2` exists, identifier list NONEMPTY | pass (guarded against a vacuous pass) |
| Every backticked identifier in §7.2 resolves to a real declaration | pass — **after** un-backticking four prose tokens (`beforeSwap`, `afterSwap`, `b02caf7`, `OPEN`) that the check caught |
| §7.2 scoped path check (`/home/`, `$HOME`) | pass |
| `OPEN` occurrences in §7.2 | 12 (≥ 4 required) |
| Phase-11 §7.1 rows not deleted | pass (`git diff` shows no removed `M6a`/`M6b`/`lambda_ARB` line) |
| §6(b) amended not deleted | pass (`demand-elasticity` retained; `partial carrier` present) |
| No FOC claimed in §7.2 | pass |
| Addendum vs plank annotation | **byte-identical** (`diff` clean) |
| plank HEAD unchanged | `08039da` → `08039da` |
| **M-blocks unchanged** | `M0 → end-of-M8` = `5fb9074512ac98c66557995f5f461ad74948976960da349aab86c1409cce1d7b` **before AND after** |
| Live ETA section hash | `54d10b5938366924974daf929bfe07609c1869fbba2c7debdfea896e2dd8ea33` (≠ pin `4f5362c1…` — disclosed) |
| `git status --porcelain lean/` | empty throughout |
| `cd lean && lake build` | exit 0, 8067 jobs |

## Decisions Made

1. **§7.2 is not a second claim table.** `§13` landed with the module at `b02caf7`, following the convention `§8` onward established (each later doc-block layer gets a top-level section; the file abandoned `§7.x` after `§7.1`). Writing the plan's `§7.2` as specified would have produced two tables carrying the same statuses for the same theorems — the exact failure mode this file exists to prevent. §7.2 is therefore the §7-level entry point plus the **E8 OPEN ledger that §13 genuinely lacked**, with bidirectional cross-references.
2. **The plank `> LEAN` annotation was verified, not rewritten.** It is a single consolidated block covering E1–E7 plus an `> AMENDED` line, landed at plank `08039da`. Re-splitting it per block would change bytes in a file this session does not own, for no informational gain. The addendum's *absence* of any annotation was the real defect.
3. **`12-RESEARCH.md` was left unedited.** It is a dated research artifact. Its three carried-forward defects (F8's mechanism, F8's de-degeneration framing, F3's "beyond his range") are corrected in the ROADMAP correction block, in E7's own ESC-1 line, and in §13 — where a later plan would actually read them.
4. **CTX-* ids adopted for Phase 12 only.** `REQUIREMENTS.md` carried no `CTX-` rows at all. Back-filling phases 8–11 is a roadmapper's job; doing it inside a phase close-out would invent status for work this plan did not audit.

## Deviations from Plan

### 1. [Rule 3 - Blocking] Three of the plan's four deliverables had ALREADY LANDED EARLY

- **Found during:** Task 1 and Task 2 (pre-flight verification)
- **Issue:** The plan was written assuming (a) the ESC-1/2/3 document amendments were still deferred to it, (b) `LEAN_TRACEABILITY` had no ETA section, and (c) the `## ETA` doc section had no `> LEAN` annotation. All three had landed early — ESC at `62220db` (~35 min after the 12-02 submission, at the user's direct instruction, overriding 12-02's own deferral ruling), §13 at `b02caf7`, and the plank annotation at plank `08039da`.
- **Fix:** each was **VERIFIED rather than re-applied**. ESC-1's E7 correction confirmed present and correct in BOTH copies with the recomputed crossing `≈ 0.2412 ∈ (0.1835, 0.5)` and the `κ_φ,S < κ_φ,I` reason; ESC-2 and ESC-3 confirmed present in E0. Only genuinely-missing work was written.
- **Verification:** `grep -n '0.2412'` on both copies; `grep -n 'ESC-2\|ESC-3'`; `diff` of the annotation blocks.
- **Committed in:** `f623bd3`, `dedc66f`

### 2. [Rule 1 - Bug] The addendum and the plank copy had DRIFTED

- **Found during:** Task 2
- **Issue:** The plank `## ETA` section carried `> LEAN` and `> AMENDED`; this tree's `VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md` — the declared SOURCE OF RECORD — carried neither. A reader consulting the authoritative copy would have seen an un-annotated specification for an already-proven layer.
- **Fix:** mirrored byte-identical from the plank copy.
- **Verification:** `diff` of the two annotation blocks returns clean.
- **Committed in:** `dedc66f`

### 3. [Rule 1 - Bug] The identifier-existence check caught four backticked prose tokens

- **Found during:** Task 1, step 5
- **Issue:** `beforeSwap`, `afterSwap`, `b02caf7` and `OPEN` were backticked in §7.2 and do not resolve to declarations.
- **Fix:** un-backticked all four (the plan's own rule: "names that are prose rather than identifiers must not be backticked"). The check was **not** loosened.
- **Verification:** the scoped loop now prints nothing.
- **Committed in:** `f623bd3`

### 4. [Process] `claude-peers` is not exposed to executor sub-agents — the owner handoff went through `todo.md` again

- **Found during:** Task 2, step 4
- **Issue:** the plan requires notifying `ul2inqpl` via `claude-peers send_message`. That MCP tool is not available in this context — the same condition 12-01 recorded.
- **Fix:** the notification was written into `../plank/todo.md` itself, addressed to `ul2inqpl`, carrying the uncommitted status, the pin invalidation and its reason, and the M-block proof.
- **NOT RESOLVED:** **the coordinator should re-send the live peer notification.** This is flagged, not claimed as done.

### 5. [Process] `gsd-tools state advance-plan` could not parse STATE.md

- **Found during:** Task 3
- **Issue:** `state advance-plan` returned `Cannot parse Current Plan or Total Plans in Phase from STATE.md` — this project's STATE.md does not carry those fields in the shape the tool expects.
- **Fix:** the Current Position block was updated by hand, in the established voice. `state update-progress` and `roadmap update-plan-progress` ran normally.

---

**Total deviations:** 5 (1 blocking-and-verified, 2 bugs auto-fixed, 2 process).
**Impact on plan:** the plan's *intent* was met in full; three of its four write targets had already been written by the orchestrator, so the plan's value here was as a checklist of what to verify rather than what to produce. One genuine defect (the drifted addendum) was found only because the plan demanded the two copies agree.

## Issues Encountered

- **The plan's acceptance criteria could not all be met as literally written**, because §13 had pre-empted §7.2. Specifically, the criterion "one status row per E-block in §7.2" is discharged by §13 instead, and the criterion "≥6 `> LEAN` lines in the `## ETA` section" is not met — there is **one** consolidated `> LEAN` line plus one `> AMENDED` line, which is the form the early landing chose. Both are recorded here rather than worked around.
- **Pre-existing dirt in `model/exp/`** — ` M model/exp/eta.md` and an untracked `model/exp/eta_pi_trader_delta_control.md` — was present at session start, belongs to another workstream, and was **not touched**. There is also a stray untracked file literally named `bpp@hotmail.es>` in the repo root, evidently a shell-redirection accident from an earlier session; it was left alone and is flagged here for someone with ownership to delete.

## User Setup Required

None.

## Next Phase Readiness

- **PHASE 12 IS COMPLETE.** 4/4 plans; six CTX-* requirements SATISFIED; **CTX-DEGEN SATISFIED AS NARROWED**.
- **The Aristotle queue is FREE.**
- **Carry-forwards for whatever comes next, none of them soft:** the **equilibrium transfer** is the largest OPEN item and everything in this layer rests on it; the **η-identity is only PARTIALLY discharged**, and the factor-share reading is *unavailable* on much of the tick-spacing range; the **Phase-11 `Θ_φ`-restricted σ-varying case** is still open and was not touched; **`ϱ_I` is unobservable** and estimating it — not proxying it — is the named follow-up; and `η⋆` being **σ-indexed while η is a design constant** is an unsolved structural obstacle for any hook design.
- **Outstanding action not owned by this session:** re-send the live `claude-peers` notification to `ul2inqpl`, and commit `../plank/todo.md` on their side.

---
*Phase: 12-eta-tradeoff-optimum*
*Completed: 2026-08-02*

## Self-Check: PASSED

All six modified/created files verified present on disk; all four commits
(`e4447ff`, `f623bd3`, `dedc66f`, `a5c3cea`) verified in `git log`. `git status`
is clean except for three pre-existing, out-of-scope entries that were present at
session start and were not touched: ` M model/exp/eta.md`,
`?? model/exp/eta_pi_trader_delta_control.md` (another workstream), and
`?? bpp@hotmail.es>` (a stray shell-redirection artifact in the repo root).
