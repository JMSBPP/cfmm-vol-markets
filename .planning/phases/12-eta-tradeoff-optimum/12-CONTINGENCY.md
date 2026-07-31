# Phase 12 — the named 5th-plan contingency

**Status:** NOT INVOKED (set at planning time, 2026-07-31). 12-03 Task 2 and 12-04 Task 3 must each
record the disposition explicitly, in both directions — "not invoked" is a result and must be
written down, not left silent.

Four plans are the baseline (12-RESEARCH F10). Six plans are not justified up front: Phase 11 needed
six because it ran two GENUINELY DEPENDENT bundles, and that dependency does not exist here —
Sections C and D consume only `priceEta` and the already-landed Phase-11 modules, all of which exist
before the single bundle is submitted.

## Triggers

Invoke the contingency if ANY of the following holds. These are the only sanctioned triggers; a
trigger that fires and is not acted on must be escalated to the user, not absorbed.

| # | Trigger | Detected at |
|---|---------|-------------|
| C1 | The 12-01 reviewer gate SPLITS the doc block — most likely at **E5** (the welfare half of Proposition 6), which is the block whose content research already judged transcribable only as a bounded statement | 12-01 Task 2 |
| C2 | The returned module OMITS Section C (the η bridge, T19'–T28') or Section D (the de-degeneration, T29'–T31') | 12-03 Task 2 |
| C3 | Any **anti-narrowing watch-list item** comes back narrowed and cannot be repaired without hand-editing a returned proof — specifically: T4'/T7'/T11'/T12' non-strict; T13' local rather than over `Set.Icc 0 1`; T24' an existence claim rather than an equality; **T27' delivered by hypothesizing a maximizer** (which would make it a restatement of `exp/DynamicsOptimization.optimal_controls` and the phase headline a duplicate); T29' weakened to a single-objective monotonicity | 12-03 Task 2 |
| C4 | The bundle fails server-side for a reason traceable to bundle composition (the import closure, the `lean-toolchain` pin, or a missing `.lake`) rather than to the mathematics | 12-02 Task 3 step 6 |

**Explicitly NOT triggers.** These are OUTCOMES and are recorded as `OPEN` or
`OMITTED (OPTIONAL)` in `12-03-FIDELITY.md`. Treating any of them as a failure would be the
softening-in-reverse error — manufacturing a second bundle to chase an item the plan already marked
optional:

- **T18'** (the reduced welfare statement) absent — marked OPTIONAL, exactly as Phase 11's T19 was.
- **T18'b** (the `τ₁ ≤ 0` refutation) absent — OPTIONAL-but-preferred.
- **T28'b** (the factor-share half of the η identity) absent — OPTIONAL. Its absence means the
  user's 2026-07-31 η-identity decision is **PARTIALLY discharged**: the exponent identity proven,
  the factor-share identification OPEN. That is recorded as such and is not chased with a second
  bundle unless the user asks for it.
- A prover-ADDED hypothesis. Expected, pre-authorized for the `1/χ` pole, and a finding rather than
  a defect — Phase 11's T15 correction was the single most valuable line in its fidelity record.
- A machine-checked REFUTATION. Phase 11's two most valuable outputs were refutations.

## Shape if invoked

Insert `12-02b` and `12-03b` as a second bundle, mirroring 12-02 and 12-03 exactly:

- **12-02b** — wave 4; `depends_on: ["12-03"]`; the second bundle is the 16 modules **plus the
  landed `EtaCurvature.lean`**, which is then itself a PROVEN artifact and off limits (the 11-04
  rule: never modify a file Aristotle has already proven). A new prompt covering only the missing or
  narrowed items, re-gated by two reviewers, submitted as a NEW project. `autonomous: false`.
- **12-03b** — wave 5; `depends_on: ["12-02b"]`; integration, byte identity across 17 modules, the
  map-driven non-uniform import rewrite (append the new module to `12-02-MODULE-MAP.txt` with origin
  `vol_markets`), axiom sweep, a fidelity record that AMENDS rather than replaces
  `12-03-FIDELITY.md`, and both remotes.
- **12-04 shifts to wave 6** and its traceability rows take their statuses from the AMENDED fidelity
  record.

For a **C1** split, the shape is different and cheaper: split the doc block at E5 within 12-01
itself, obtain approval on both halves in one checkpoint, and continue with four plans. Only escalate
to a fifth plan if the split changes what the single bundle can carry.

## The rule that governs all of this

**Do not accept a narrowed statement under a requested name, and do not hand-prove the gap locally.**
The standing workflow rule is that Aristotle authors statements and proofs; hand-editing a returned
proof voids its verification. A second bundle is the sanctioned repair. An honest `OPEN` row is the
other sanctioned outcome. Those are the only two.
