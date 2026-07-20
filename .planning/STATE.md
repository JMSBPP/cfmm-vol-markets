---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: VolOrderManagerMod + Multicall
status: roadmap-complete
stopped_at: v4.0 roadmap POST-REVIEW complete (5 phases 16/17/18a/18b/19, 15/15 mapped); 2 BLOCKERs + 6 MAJORs resolved before commit. Next /gsd:plan-phase 16
last_updated: "2026-07-19T00:00:00.000Z"
last_activity: "2026-07-19 — created the v4.0 roadmap section (appended to ROADMAP.md, preserving v1.0/v2.0/v3.0 verbatim): 4 phases derived from the research SUMMARY skeleton — 16 Type Packing & Validation Foundation (VORD-02), 17 Interface & Single-Call Module (VORD-01/03/04/05), 18 Best-Effort Batch Entrypoint (MCAL-01..06), 19 Differential/Mutation Battery/Consumer Fixture (MVER-01..04). 15/15 mapped, VORD-04 assigned to 17 alone. Mutation-falsifiability gate embedded in EVERY phase (16–19); Phase 18 SC set carries the five critical pitfalls (totality fuzz, calldatasize revert, MAX_BATCH placeholder N=MAX+1/N=MAX gas, zero-footprint vm.load skip, N=0 return edge). REQUIREMENTS.md traceability appended (66/66)."
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value (v4.0):** `VolOrderManagerMod.plk` is a vol-order REGISTRY — `create_order(uint88,uint24,uint16)` (strike/width/skew, selector `0x6501fe94`) validating against the machine-checked `vol_order_is_complete` predicates, assigning a sequential id, storing a packed `VolOrder` word — plus a BEST-EFFORT batch entrypoint running N create_order calls in one tx (invalid tuples skipped, batch never reverts). Built for the rpc_api Haskell `StochasticOrderGen` consumer (PR #9 awaits this surface). Every claim is a CALLED test or an OBSERVED mutation kill; compiling is NOT evidence; the module leaves `PLANK_SKIP` only when its batch dispatch is CALLED green.
**Current focus:** v4.0 roadmap COMPLETE. Phase 16 (Type Packing & Validation Foundation, VORD-02) is next and UNBLOCKED. Next action: `/gsd:plan-phase 16`.

**Track note:** Fourth milestone. v3.0 (VegaAccountMod vault, Phases 12–15) SHIPPED 2026-07-19 (tag `v3.0`). v1.0 (GAMS plumbing, Phases 1–7) PAUSED. v2.0 (vol-oracle differential, Phases 8–11) PAUSED after Phase 9 — VDIFF-05..08 (Phases 10–11) remain pending, NOT part of v4.0. Resuming v2.0 = `/gsd:plan-phase 10`. These phase ranges are separate tracks — never renumbered.

## Current Position

Phase: 16 — Type Packing & Validation Foundation (VORD-02) — NOT STARTED
Plan: none yet (roadmap just created)
Status: Roadmap complete — ready to plan Phase 16
Last activity: 2026-07-19 — v4.0 roadmap section appended to ROADMAP.md; REQUIREMENTS.md traceability updated (15 rows, 66/66 total).

Progress (v4.0): [░░░░░░░░░░] 0% — 0/4 phases, 0 plans complete

## Performance Metrics

**Velocity:**
- Total plans completed (v4.0): 0
- Average duration: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v4.0:

- [v4.0 roadmap]: 4 phases from the research SUMMARY skeleton; VORD-04 mapped to Phase 17 ALONE (Phase 16 delivers the pack/unpack layout its store consumes, but the requirement is mapped once).
- [v4.0 constraint]: runtime `while` only — `inline while` (comptime unroll) is parsed but compiler-rejected in v0.1.1; the batch loop is a plain bounded `while i < count`, not unrolled, not recursive.
- [v4.0 constraint]: best-effort containment is a pure-validation pre-check (branch-only, no self-call), NOT a self-`@evm_call` boundary — `create_order` has no revert-prone dependency call.
- [v4.0 constraint]: `array_slot(base,id) = keccak256(base)+id` reused verbatim from `v3::storage`, WITHOUT the RealizedVolatility ring's 16-bit wraparound mask (load-bearing for a ring, corruption-causing for a monotonic-id registry). Zero arithmetic in the module.
- [v4.0 constraint]: two peer-dependent placeholders (`MAX_BATCH` value; typed `(bool,uint256)[]` return shape) — NAMED placeholders with test structure written against them; never guessed, never blockers. Peer = rpc_api track `mv15a18k` (PR #9).
- [v4.0 constraint]: stored word is the 128-bit create_order-native subset (`skew|strike|width` at offsets 0/16/104, bits 128–151 zeroed, `tickSpacing` deferred with pricing); width validated by the REDUCED check `width in (0,0xffffff]` (no `tickSpacing` operand).
- [carried, v3.0]: `make compile-plank` passing is NOT evidence — Plank does not type-check code unreachable from `run{}`. Proof = CALLING the module through FFI-deployed bytecode.
- [carried, v3.0]: `deployPlank` recompiles the `.plk` fresh on every test run via FFI — a mutation battery does NOT need `make compile-plank` between mutants; the mutant reaches the deployed bytecode as long as tests use `deployPlank` (re-check if any test ever deploys from a prebuilt artifact).
- [carried, v3.0]: observed-RED discipline — mutant applied → cache/fuzz cleared → verbatim RED recorded → restored sha256-identical → green; equivalence-masked mutants documented, never counted. Keep a NON-FUZZ unit anchor alongside each fuzz (cache-independent by construction). Reference mock must NEVER echo Plank's own output (vacuous differential).
- [carried, v3.0]: one shared decoder, not a fourth copy — `test/.../TimepointDecoder.sol` precedent; v4.0 promotes a single `VolOrderDecoder` and reuses it.

### Pending Todos

**Next action: `/gsd:plan-phase 16`.** Phase 16 (VORD-02) is the pure packing + validation layer — standard pattern, SKIP `/gsd:research-phase`. So is Phase 17 (near-verbatim `VegaAccountMod.plk` mirror). **Phase 18 NEEDS a focused `/gsd:research-phase` pass before planning** — the dynamic-array-ABI-in-Plank surface is new ground; study `merkle_airdrop.plk` line-by-line (diff-tested `while` + computed `@evm_calldataload` offset + hand-rolled dynamic-array head/tail). Phase 19 fixture pinning is a coordination checkpoint, not a research gap.

### Blockers/Concerns

- **Untracked `src/modules/protocol_integrations/PriceSetterHook.sol` (another track)** has an empty Solidity import path that breaks bare `forge build` across the whole `src/` tree. Every `forge` invocation in v4.0 must carry the documented `--skip` for that path (as v3.0's Phase 13+ did) until the owning track fixes/removes it. `forge` runs under `--via-ir --optimize`.
- **4 pre-existing pos_spec harness failures** (vol-type-system track) remain visible in `make test` — not v4.0 defects; the v4.0 suite must not filter them.
- **Peer coordination:** `MAX_BATCH` value and return-shape confirmation pending peer `mv15a18k`. Proceed with placeholders; do not block Phase 18/19 on peer response.

## Session Continuity

Last session: 2026-07-19
Stopped at: Created v4.0 roadmap (ROADMAP.md v4.0 section + REQUIREMENTS.md traceability)
Resume file: None
