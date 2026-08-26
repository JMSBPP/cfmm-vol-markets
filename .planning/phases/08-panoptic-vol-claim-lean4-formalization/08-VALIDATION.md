---
phase: 8
slug: panoptic-vol-claim-lean4-formalization
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-19
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> For a Lean formalization the "test" is compilation: a theorem is validated iff its file builds with no `sorry` (and no `axiom` leak). `lake build` is the test runner; `#print axioms <thm>` is the "no cheating" assertion.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Lean 4 elaborator + Lake (`~/.elan/bin/lake`), toolchain v4.28.0, Mathlib v4.28.0 prebuilt |
| **Config file** | `lean/lakefile.toml` (+ `lean/lean-toolchain`, `lean/lake-manifest.json`) |
| **Quick run command** | `cd lean && lake build vol_markets` |
| **Full suite command** | `cd lean && lake build` (defaultTargets = exp, vol_markets, tao) |
| **Estimated runtime** | incremental: seconds–minutes (Mathlib cached; baseline GREEN 2026-07-19, 8030 jobs, exit 0) |

---

## Sampling Rate

- **After every task commit:** Run `cd lean && lake build vol_markets`
- **After every plan wave:** Run `cd lean && lake build`
- **Before `/gsd:verify-work`:** Full suite green AND the θ theorem carries no `sorry`/no unexpected axiom (`#print axioms` shows only `propext`/`Classical.choice`/`Quot.sound`)
- **Max feedback latency:** ~300 seconds (incremental vol_markets build)

---

## Per-Task Verification Map

(No formal REQ-IDs; decisions from 08-CONTEXT.md are the requirements. Task IDs firm up at planning.)

| Task ID | Plan | Wave | Requirement (decision) | Test Type | Automated Command | File Exists | Status |
|---------|------|------|------------------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 0 | Spec hygiene: θ sign fixed, refs de-pathed, notes vendored, spec committed | build+grep | `git ls-files --error-unmatch spec/protocol/panoptic.md && ! grep -rn '\$HOME\|/home/' spec/` | ❌ W0 | ⬜ pending |
| TBD | TBD | 1 | π^σ payoff + ΔQ_v identity lemmas compile | unit | `cd lean && lake build vol_markets` | ❌ W0 (Panoptic.lean new) | ⬜ pending |
| TBD | TBD | 1 | Replication decomposition (structural def + consistency/dimension lemmas) | unit | `cd lean && lake build vol_markets` | ❌ W0 | ⬜ pending |
| TBD | TBD | 1 | Premium `Finset.sum` def + telescoping lemma | unit | `cd lean && lake build vol_markets` | ❌ W0 | ⬜ pending |
| TBD | TBD | 1 | υ finite-difference def + ΔQ_v bridge lemma | unit | `cd lean && lake build vol_markets` | ❌ W0 (Upsilon.lean new) | ⬜ pending |
| TBD | TBD | 1 | ATM/OTM null hypothesis pinned as Prop conjecture | typecheck | `cd lean && lake build vol_markets` | ❌ W0 | ⬜ pending |
| TBD | TBD | 2 | θ_ATM = kσ/√(8πτ) lattice→closed-form theorem, sorry-free | proof (Aristotle) | `cd lean && lake build vol_markets` + `#print axioms` check | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `spec/protocol/panoptic.md` — correct θ sign, replace Demeterfi PDF link with citekey/URL, remove `~/` NOTE path, then commit (currently untracked)
- [ ] `spec/protocol/refs/cfmm-discrete/` — create; vendor FINANCE.md, STREAMING_PREMIUM.md, DIFFERENTIATION.md, BINARY_TREES.md; neutralize dangling sibling links
- [ ] `lean/vol_markets/Panoptic.lean` — new module (payoff, replication, premium, CRR lattice, θ)
- [ ] `lean/vol_markets/Upsilon.lean` — new module (υ, ΔQ_v bridge, conjecture)
- [ ] `lean/lakefile.toml` — add both new files to the `vol_markets` `roots`
- [ ] Aristotle bundle scaffold — `lakefile.toml`/`lean-toolchain`/`lake-manifest.json` + source subdir mirroring the reference archive layout (Stage-2 submission)
- [ ] `#print axioms` check step asserting the θ proof is sorry-free after Aristotle returns

Framework install: none needed (toolchain, Mathlib `.lake` prebuilt, aristotlelib 2.1.0 all present).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aristotle submission round-trip | Staged-serial workflow (08-CONTEXT.md) | Server-side task; no local automation may queue/parallel submits | `aristotle show <task>` until landed; download; re-run `lake build vol_markets`; confirm no `sorry` remains in the returned file |
| Vendored notes fidelity | cfmm-discrete vendoring | Content copy of user's own notes; correctness is editorial | Diff vendored files against KB source at vendoring time; verify in-tree links resolve |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (plan-checker verified: every non-checkpoint task carries an automated verify)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (checker check 8c: no gap window in any wave)
- [x] Wave 0 covers all MISSING references (checker check 8d: no MISSING-tagged automated refs)
- [x] No watch-mode flags
- [x] Feedback latency < 300s — **known exception**: `lake build vol_markets` incremental builds run up to ~300s (Mathlib-backed Lean project; inherent, accepted per checker warning #3)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-19 (plan-checker: 0 blockers; 6 warnings resolved in-place)
