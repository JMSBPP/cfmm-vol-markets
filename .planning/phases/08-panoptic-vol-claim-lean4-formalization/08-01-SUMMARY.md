---
phase: 08-panoptic-vol-claim-lean4-formalization
plan: 01
subsystem: spec
tags: [spec-hygiene, panoptic, cfmm-discrete, theta-kernel, vendoring, references]

# Dependency graph
requires:
  - phase: 01-repository-restructure-sanitize
    provides: "Sanitization rule — no home-absolute/user-directory paths in tracked files"
provides:
  - "Pinned, git-tracked spec/protocol/panoptic.md with corrected negative-exponent θ kernel"
  - "URL/citekey Demeterfi (1999) volatility-swaps reference (no vendored PDF)"
  - "Vendored load-bearing cfmm-discrete proof-source notes under spec/protocol/refs/cfmm-discrete/"
  - "spec/protocol/refs/README.md provenance note (cfmm-theory KB citekey remains canonical)"
affects: [08-02, 08-03, 08-04, 08-05, panoptic-lean-formalization, aristotle-theta-derivation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Vendored proof-source notes cited-as-source, canonical citekey retained (not vendored-as-authority)"
    - "Cross-tree dangling links neutralized to plain-text citekeys on vendoring"

key-files:
  created:
    - spec/protocol/refs/cfmm-discrete/FINANCE.md
    - spec/protocol/refs/cfmm-discrete/STREAMING_PREMIUM.md
    - spec/protocol/refs/cfmm-discrete/DIFFERENTIATION.md
    - spec/protocol/refs/cfmm-discrete/BINARY_TREES.md
    - spec/protocol/refs/cfmm-discrete/INTEGRATION.md
    - spec/protocol/refs/cfmm-discrete/COORDINATES.md
    - spec/protocol/refs/README.md
  modified:
    - spec/protocol/panoptic.md

key-decisions:
  - "θ kernel exponent negated (Gaussian must decay) — consistent with STREAMING_PREMIUM θ_ATM(τ)=kσ/√(8πτ)"
  - "Demeterfi reference as URL + citekey, not a vendored PDF (public repo, redistribution rights unclear)"
  - "Six cfmm-discrete notes vendored (four named load-bearing + INTEGRATION/COORDINATES to keep sibling links live)"

patterns-established:
  - "Vendored-as-source, cited-as-canonical: in-tree copies for reproducibility, KB keeps authority"
  - "On vendoring, cross-tree links outside the vendored set become plain-text citekeys; in-tree sibling links kept"

requirements-completed: [CTX-HYGIENE, CTX-VENDOR]

# Metrics
duration: 12min
completed: 2026-07-19
---

# Phase 8 Plan 01: Spec Hygiene & cfmm-discrete Vendoring Summary

**Pinned spec/protocol/panoptic.md with the corrected negative-exponent θ kernel and URL/citekey Demeterfi reference, and vendored the six load-bearing cfmm-discrete proof-source notes in-tree with dangling cross-tree links neutralized.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-19T12:50:00Z
- **Completed:** 2026-07-19T13:02:00Z
- **Tasks:** 2
- **Files modified:** 8 (1 modified, 7 created)

## Accomplishments
- Corrected the θ streaming-premium kernel sign typo: the `exp` exponent is now negative, so the Gaussian decays — the only form consistent with STREAMING_PREMIUM.md's `Θ_ATM(τ)=kσ/√(8πτ)` and `∫₀ᵀ Θ_ATM dτ = kσ√(T/2π)`.
- Replaced the dangling `../refs/DemeterfietalVarianceSwaps.pdf` link with a URL + full citekey (Demeterfi, Derman, Kamal, Zou 1999, Goldman Sachs QS Research Notes).
- Removed the `~/`-absolute NOTE path, re-pointing it at the in-tree `refs/cfmm-discrete/` with the cfmm-theory KB retained as the canonical citekey.
- Committed the previously-untracked `spec/protocol/panoptic.md` as the phase's pinned source of truth.
- Vendored six cfmm-discrete notes (FINANCE, STREAMING_PREMIUM, DIFFERENTIATION, BINARY_TREES, INTEGRATION, COORDINATES) into `spec/protocol/refs/cfmm-discrete/`, neutralizing cross-tree links to `../lp-derivatives/*` and `../cfmm-options/*` while keeping in-tree sibling links live.
- Added `spec/protocol/refs/README.md` provenance note.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix θ sign, Demeterfi citekey, and ~/ NOTE path in spec/protocol/panoptic.md; commit** — `4316306` (docs)
2. **Task 2: Vendor cfmm-discrete notes, neutralize dangling links, commit** — `304fb83` (docs)

**Plan metadata:** pending final metadata commit (docs: complete plan)

## Files Created/Modified
- `spec/protocol/panoptic.md` — pinned/tracked; negative-exponent θ kernel, URL/citekey Demeterfi ref, de-pathed NOTE
- `spec/protocol/refs/cfmm-discrete/FINANCE.md` — CRR backward-induction operator + σ-bridge source
- `spec/protocol/refs/cfmm-discrete/STREAMING_PREMIUM.md` — lattice θ_ATM derivation (center-column, kσ/√(8πτ))
- `spec/protocol/refs/cfmm-discrete/DIFFERENTIATION.md` — discrete Itô ∂_t/∂_i² operator
- `spec/protocol/refs/cfmm-discrete/BINARY_TREES.md` — Δt=(Δi)² heat-operator collapse, geometric-grid ⟹ CRR
- `spec/protocol/refs/cfmm-discrete/INTEGRATION.md` — base forms/incidence-weight primitives (keeps ./INTEGRATION.md links live)
- `spec/protocol/refs/cfmm-discrete/COORDINATES.md` — reserve 0-form / trading-flow lattice calculus
- `spec/protocol/refs/README.md` — provenance note; cfmm-theory KB citekey remains canonical

## Decisions Made
- θ exponent negated per the Gaussian-decay requirement and the STREAMING_PREMIUM closed form (Pitfall 3 from research).
- Demeterfi cited by URL + citekey rather than vendored (public repo; redistribution rights unclear).
- Six notes vendored: the four named load-bearing notes plus INTEGRATION.md and COORDINATES.md so their in-tree sibling links resolve after vendoring.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reworded provenance README to avoid tripping the home-path guard**
- **Found during:** Task 2 (vendoring + verification)
- **Issue:** The first draft of `spec/protocol/refs/README.md` used the literal example strings `~/`, `$HOME`, and `/home/...` when explaining the Phase-1 sanitization rule. The plan's own acceptance check `grep -rnE '/home/|\$HOME|~/' spec/protocol/refs/` cannot distinguish an explanatory mention from a real path, so the draft failed the "no home-absolute paths" gate (exit 0 instead of 1).
- **Fix:** Reworded the sentence to describe the rule ("no home-relative or absolute filesystem targets in tracked files") without embedding the forbidden substrings.
- **Files modified:** spec/protocol/refs/README.md
- **Verification:** `grep -rnE '/home/|\$HOME|~/' spec/protocol/refs/` now returns nothing (exit 1).
- **Committed in:** 304fb83 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary to satisfy the plan's own sanitization acceptance criterion. No scope creep.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `spec/protocol/panoptic.md` is pinned, tracked, and sign-corrected — downstream Lean plans (08-02+) can reference it as the frozen source of truth.
- The load-bearing lattice calculus notes are in-tree at `spec/protocol/refs/cfmm-discrete/`; the Aristotle θ_ATM(τ)=kσ/√(8πτ) derivation (the phase's heaviest proof) can cite STREAMING_PREMIUM.md and FINANCE.md via stable in-tree paths.
- No home-absolute paths remain under `spec/` (Phase-1 rule satisfied).

---
*Phase: 08-panoptic-vol-claim-lean4-formalization*
*Completed: 2026-07-19*

## Self-Check: PASSED

All 8 claimed files exist on disk; both task commits (`4316306`, `304fb83`) exist in git history.
