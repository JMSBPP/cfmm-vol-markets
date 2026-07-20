---
gsd_state_version: 1.0
milestone: v4.0
milestone_name: VolOrderManagerMod + Multicall
status: executing
stopped_at: Phase 17 COMPLETE + verified (7/7; M1 independently re-killed, flake root-caused as pre-existing). Next /gsd:plan-phase 18a — THE MULTICALL
last_updated: "2026-07-20T17:25:40.408Z"
last_activity: "2026-07-20 — 17-01 executed: create_order/orderCount/getOrderPacked CALLED-green over FFI-deployed bytecode; 4 observed mutation REDs + 1 equivalence-checked non-kill; array_slot checked-add id bound MEASURED; src/types/pos_spec/ byte-untouched."
progress:
  total_phases: 16
  completed_phases: 5
  total_plans: 9
  completed_plans: 9
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-19)

**Core value (v4.0):** `VolOrderManagerMod.plk` is a vol-order REGISTRY — `create_order(uint88,uint24,uint16)` (strike/width/skew, selector `0x6501fe94`) validating against the machine-checked `vol_order_is_complete` predicates, assigning a sequential id, storing a packed `VolOrder` word — plus a BEST-EFFORT batch entrypoint running N create_order calls in one tx (invalid tuples skipped, batch never reverts). Built for the rpc_api Haskell `StochasticOrderGen` consumer (PR #9 awaits this surface). Every claim is a CALLED test or an OBSERVED mutation kill; compiling is NOT evidence; the module leaves `PLANK_SKIP` only when its batch dispatch is CALLED green.
**Current focus:** Phase 17 (VORD-01/03/04/05) COMPLETE — `create_order` is a live registry entrypoint, both entrypoint selectors pinned, four mutants observed RED. Phase 18a (Batch Input & State Effects, MCAL-01/02/03/04/06) is next. **Phase 18 NEEDS `/gsd:research-phase` before planning** (dynamic-array ABI in Plank is new ground). Next action: `/gsd:research-phase 18a`.

**Track note:** Fourth milestone. v3.0 (VegaAccountMod vault, Phases 12–15) SHIPPED 2026-07-19 (tag `v3.0`). v1.0 (GAMS plumbing, Phases 1–7) PAUSED. v2.0 (vol-oracle differential, Phases 8–11) PAUSED after Phase 9 — VDIFF-05..08 (Phases 10–11) remain pending, NOT part of v4.0. Resuming v2.0 = `/gsd:plan-phase 10`. These phase ranges are separate tracks — never renumbered.

## Current Position

Phase: 17 — Interface & Single-Call Module (VORD-01/03/04/05) — COMPLETE
Plan: 17-01 COMPLETE (17-01-SUMMARY.md)
Status: Phase 17 done — Phase 18a (Batch Input & State Effects) is next, and needs a research pass first
Last activity: 2026-07-20 — 17-01 executed: create_order/orderCount/getOrderPacked CALLED-green over FFI-deployed bytecode; 4 observed mutation REDs + 1 equivalence-checked non-kill; array_slot checked-add id bound MEASURED; src/types/pos_spec/ byte-untouched.

Progress (v4.0): [████░░░░░░] 40% — 2/5 phases (16, 17), 2 plans complete

## Performance Metrics

**Velocity:**
- Total plans completed (v4.0): 2
- Average duration: 65 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 16 — Type Packing & Validation | 1 | 118 min | 118 min |
| 17 — Interface & Single-Call Module | 1 | 11 min | 11 min |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v4.0:

- [17-01 MEASURED, binds 18a/19]: `v3::storage::array_slot` uses Plank's CHECKED `+`, so `keccak(base) + id` PANICS (0x11) rather than wrapping. Addressable ids cap at `2^256-1 - keccak(SLOT_ORDERS_BASE)` (~6.5e74). VORD-05's "no revert for a nonexistent id" therefore holds for every REACHABLE id (counter-assigned, +1/tx), which is the property it exists to establish. NOT worked around: `array_slot` is another track's file and masking the id module-side is exactly the ring-mask corruption M1 forbids. Boundary pinned as a VALUE instead.
- [17-01 DECIDED, ACTION REQUIRED IN 18a]: the "counter store hoisted above validation" mutant (M5) is an EQUIVALENCE-CHECKED NON-KILL in the strict path — `validate_order_strict` reverts, and a revert rolls back the prior SSTORE, so the hoist is unobservable. It becomes NON-equivalent in 18a, where the batch SKIPS instead of reverting: a hoisted store would advance the id on a skipped tuple. **18a MUST re-run this mutant and expect a RED.**
- [17-01 DECIDED]: both entrypoint selectors pinned in `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — `create_order(uint88,uint24,uint16)`=0x6501fe94 (dispatched) and `create_orders(uint256,uint256[])`=0x81357911 (DECLARED, falls through to `revert_empty()` until 18a). This is what breaks the 17<->18a circular dependency. `test__unit__batchSelectorNotYetDispatched` locks the current fall-through and must be updated when 18a dispatches it.
- [17-01 EVIDENCE]: the id-65536 test is the SOLE kill site for the ring-mask mutant — every other test stayed GREEN under it, because `& 0xFFFF` is a no-op at ids 1 and 2. Small-id tests alone were provably insufficient; this is measured, not argued.
- [17-01 baselines]: `make compile-plank` 13 ok / 0 failed / 0 skipped (was 12); `make test` 99 pass / 4 pre-existing fails (was 87 / 4), MODAL — see the nondeterminism blocker below. `PLANK_SKIP` stays EMPTY (MVER-04 corrected at af488a0: a module that compiles never enters the rescue queue).
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

**Next action: `/gsd:research-phase 18a`.** Phases 16 (VORD-02) and 17 (VORD-01/03/04/05) are DONE. **Phase 18 NEEDS a focused `/gsd:research-phase` pass before planning** — the dynamic-array-ABI-in-Plank surface is new ground; study `merkle_airdrop.plk` line-by-line (diff-tested `while` + computed `@evm_calldataload` offset + hand-rolled dynamic-array head/tail). Phase 19 fixture pinning is a coordination checkpoint, not a research gap.

### Blockers/Concerns

- **Untracked `src/modules/protocol_integrations/PriceSetterHook.sol` (another track)** has an empty Solidity import path that breaks bare `forge build` across the whole `src/` tree. Every `forge` invocation in v4.0 must carry the documented `--skip` for that path (as v3.0's Phase 13+ did) until the owning track fixes/removes it. `forge` runs under `--via-ir --optimize`.
- **4 pre-existing pos_spec harness failures** (vol-type-system track) remain visible in `make test` — not v4.0 defects; the v4.0 suite must not filter them.
- **[17-01] The `make test` failure count is NOT deterministic.** A FIFTH failure, `TickVolatilityLibTest::test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess`, surfaces on roughly 1 cold-cache run in 4, always at counterexample `2^64-1`. PROVEN pre-existing (reproduced with all 17-01 files stashed: 86 pass / 5 fail) and owned by the TickVolatility track — it is NOT one of the 4 known `src/types/pos_spec/` reds. Re-run before treating a 5th failure as a regression. See `.planning/phases/17-interface-single-call-module/deferred-items.md` (D1); worth reporting `2^64-1` upstream as a genuine latent bug.
- **[17-01 MEASURED, binds 18a/19 and the Haskell consumer] `array_slot`'s add is CHECKED.** `v3::storage::array_slot` is `keccak256(base) + index` under Plank's checked `+`, so it PANICS (0x11) instead of wrapping. Addressable ids are capped at `2^256-1 - keccak(SLOT_ORDERS_BASE)` ≈ 6.5e74; above that `getOrderPacked` reverts rather than returning the 0 sentinel. Unreachable for counter-assigned ids, but relevant to any path accepting caller-supplied ids. Pinned by `test__unit__getOrderPackedOverflowBoundaryIsExactlyWhereCheckedAddSaturates`.
- **Peer coordination:** `MAX_BATCH` value and return-shape confirmation pending peer `mv15a18k`. Proceed with placeholders; do not block Phase 18/19 on peer response.

## Session Continuity

Last session: 2026-07-20T17:05:57.182Z
Stopped at: Completed 17-01-PLAN.md
Resume file: None
