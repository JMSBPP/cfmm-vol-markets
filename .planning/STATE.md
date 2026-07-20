---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: VolOrderManagerMod + Multicall
status: in-progress
stopped_at: Completed 16-01-PLAN.md (Phase 16 COMPLETE — VORD-02). Next /gsd:plan-phase 17
last_updated: "2026-07-20T16:28:00.190Z"
last_activity: 2026-07-20 — executed 16-01: pure VolOrderValidationLib (bool core + reverting wrapper + authored strike<=2^88-1 bound), 4-selector FFI harness, 13 CALLED-green tests, six-mutant battery all observed RED and restored sha256-identical.
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value (v4.0):** `VolOrderManagerMod.plk` is a vol-order REGISTRY — `create_order(uint88,uint24,uint16)` (strike/width/skew, selector `0x6501fe94`) validating against the machine-checked `vol_order_is_complete` predicates, assigning a sequential id, storing a packed `VolOrder` word — plus a BEST-EFFORT batch entrypoint running N create_order calls in one tx (invalid tuples skipped, batch never reverts). Built for the rpc_api Haskell `StochasticOrderGen` consumer (PR #9 awaits this surface). Every claim is a CALLED test or an OBSERVED mutation kill; compiling is NOT evidence; the module leaves `PLANK_SKIP` only when its batch dispatch is CALLED green.
**Current focus:** Phase 16 (VORD-02) COMPLETE — the pure validation surface exists and is falsifiable. Phase 17 (Interface & Single-Call Module, VORD-01/03/04/05) is next and UNBLOCKED. Next action: `/gsd:plan-phase 17`.

**Track note:** Fourth milestone. v3.0 (VegaAccountMod vault, Phases 12–15) SHIPPED 2026-07-19 (tag `v3.0`). v1.0 (GAMS plumbing, Phases 1–7) PAUSED. v2.0 (vol-oracle differential, Phases 8–11) PAUSED after Phase 9 — VDIFF-05..08 (Phases 10–11) remain pending, NOT part of v4.0. Resuming v2.0 = `/gsd:plan-phase 10`. These phase ranges are separate tracks — never renumbered.

## Current Position

Phase: 16 — Type Packing & Validation Foundation (VORD-02) — COMPLETE
Plan: 16-01 COMPLETE (16-01-SUMMARY.md)
Status: Phase 16 done — ready to plan Phase 17 (Interface & Single-Call Module)
Last activity: 2026-07-20 — 16-01 executed: pure validation surface CALLED-green through FFI-deployed bytecode; six-mutant battery observed RED; src/types/pos_spec/ byte-untouched.

Progress (v4.0): [██░░░░░░░░] 25% — 1/4 phases, 1 plan complete

## Performance Metrics

**Velocity:**
- Total plans completed (v4.0): 1
- Average duration: 118 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 16 — Type Packing & Validation | 1 | 118 min | 118 min |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v4.0:

- [16-01 DECIDED, binds 17/18a]: `validate_order` is a bool-returning CORE with `validate_order_strict` as a thin reverting wrapper. Phase 17 calls the wrapper, Phase 18a calls the core — MCAL-04's "same validation both paths" is true by construction, not by assertion. Do not collapse them.
- [16-01 DECIDED]: `TICK_SPACING = 20` pinned inside `build_vol_order` (one place). `vol_range_width_is_complete` ANDs `tickSpacing > 0`, so a zeroed field makes the composed validator IDENTICALLY FALSE — under which an all-reject validator passes a naive fuzz trivially. Mutant M5 proves this is observable. All order construction in 17/18a MUST go through `build_vol_order`.
- [16-01 MEASURED]: stored word is the FULL 152-bit `(width << 128) | (20 << 104) | (strike << 16) | skew`. NOTE this SUPERSEDES the earlier v4.0 roadmap-time assumption of a 128-bit `skew|strike|width` subset with tickSpacing deferred, and supersedes the "REDUCED width check (no tickSpacing operand)" note below — the full `vol_range_width_is_complete` is reused verbatim, tickSpacing included.
- [16-01 MEASURED]: accept sets, verified against the real predicates — skew [1, 65534] (1 and 65534 ACCEPTED, do NOT revert), width [1, 0xffffff], strike [1, 2^88-1]. The requirement's earlier "both endpoints revert" wording was wrong.
- [16-01 baselines]: `make compile-plank` 12 ok / 0 failed / 0 skipped (was 11); `make test` 87 pass / 4 pre-existing pos_spec fails (was 74 / 4).
- [16-01 pattern]: when a roadmap-named mutation site lives in another track's file, apply the identical semantic flip at OUR call site by inlining the flipped predicate, and record the substitution rationale in-file. Used for M3 (skew comparison, home is SpreadTickAssimetry.plk:12).
- [v4.0 roadmap]: 4 phases from the research SUMMARY skeleton; VORD-04 mapped to Phase 17 ALONE (Phase 16 delivers the pack/unpack layout its store consumes, but the requirement is mapped once).
- [v4.0 constraint]: runtime `while` only — `inline while` (comptime unroll) is parsed but compiler-rejected in v0.1.1; the batch loop is a plain bounded `while i < count`, not unrolled, not recursive.
- [v4.0 constraint]: best-effort containment is a pure-validation pre-check (branch-only, no self-call), NOT a self-`@evm_call` boundary — `create_order` has no revert-prone dependency call.
- [v4.0 constraint]: `array_slot(base,id) = keccak256(base)+id` reused verbatim from `v3::storage`, WITHOUT the RealizedVolatility ring's 16-bit wraparound mask (load-bearing for a ring, corruption-causing for a monotonic-id registry). Zero arithmetic in the module.
- [v4.0 constraint]: two peer-dependent placeholders (`MAX_BATCH` value; typed `(bool,uint256)[]` return shape) — NAMED placeholders with test structure written against them; never guessed, never blockers. Peer = rpc_api track `mv15a18k` (PR #9).
- [v4.0 constraint — **SUPERSEDED at 16-01, do not use**]: ~~stored word is the 128-bit create_order-native subset (`skew|strike|width` at offsets 0/16/104, bits 128–151 zeroed, `tickSpacing` deferred with pricing); width validated by the REDUCED check `width in (0,0xffffff]` (no `tickSpacing` operand).~~ Phase 16 measured the real layout: the FULL 152-bit word with `tickSpacing = 20` live in bits 104..127, and the FULL `vol_range_width_is_complete` (tickSpacing conjuncts included) reused verbatim. See the 16-01 MEASURED entries above.
- [carried, v3.0]: `make compile-plank` passing is NOT evidence — Plank does not type-check code unreachable from `run{}`. Proof = CALLING the module through FFI-deployed bytecode.
- [carried, v3.0]: `deployPlank` recompiles the `.plk` fresh on every test run via FFI — a mutation battery does NOT need `make compile-plank` between mutants; the mutant reaches the deployed bytecode as long as tests use `deployPlank` (re-check if any test ever deploys from a prebuilt artifact).
- [carried, v3.0]: observed-RED discipline — mutant applied → cache/fuzz cleared → verbatim RED recorded → restored sha256-identical → green; equivalence-masked mutants documented, never counted. Keep a NON-FUZZ unit anchor alongside each fuzz (cache-independent by construction). Reference mock must NEVER echo Plank's own output (vacuous differential).
- [carried, v3.0]: one shared decoder, not a fourth copy — `test/.../TimepointDecoder.sol` precedent; v4.0 promotes a single `VolOrderDecoder` and reuses it.

### Pending Todos

**Next action: `/gsd:plan-phase 17`.** Phase 16 (VORD-02) is DONE. Phase 17 (near-verbatim `VegaAccountMod.plk` mirror). **Phase 18 NEEDS a focused `/gsd:research-phase` pass before planning** — the dynamic-array-ABI-in-Plank surface is new ground; study `merkle_airdrop.plk` line-by-line (diff-tested `while` + computed `@evm_calldataload` offset + hand-rolled dynamic-array head/tail). Phase 19 fixture pinning is a coordination checkpoint, not a research gap.

### Blockers/Concerns

- **Untracked `src/modules/protocol_integrations/PriceSetterHook.sol` (another track)** has an empty Solidity import path that breaks bare `forge build` across the whole `src/` tree. Every `forge` invocation in v4.0 must carry the documented `--skip` for that path (as v3.0's Phase 13+ did) until the owning track fixes/removes it. `forge` runs under `--via-ir --optimize`.
- **4 pre-existing pos_spec harness failures** (vol-type-system track) remain visible in `make test` — not v4.0 defects; the v4.0 suite must not filter them.
- **Peer coordination:** `MAX_BATCH` value and return-shape confirmation pending peer `mv15a18k`. Proceed with placeholders; do not block Phase 18/19 on peer response.

## Session Continuity

Last session: 2026-07-20T16:28:00.187Z
Stopped at: Completed 16-01-PLAN.md
Resume file: None
