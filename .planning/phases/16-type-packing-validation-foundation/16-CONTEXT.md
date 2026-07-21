# Phase 16: Type Packing & Validation Foundation - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning
**Source:** The post-review v4.0 roadmap + requirements (2 BLOCKERs / 6 MAJORs resolved at `7fbc371`), plus one further correction made at plan time (`c6a7dbb`). Every fact below was verified at source level during the two-step review — none is inherited from an unverified research claim.

<domain>
## Phase Boundary

The PURE validation surface and nothing else:

1. `src/lib/pos_spec/VolOrderValidationLib.plk` (name at planner's discretion) — a pure `validate_order` composing two existing predicates VERBATIM plus ONE newly-authored bound.
2. `test/types/pos_spec/VolOrderValidationHarness.plk` — an FFI harness making the pure fn reachable over the ABI. **This is a required deliverable** (see the correction below), not optional scaffolding.
3. One test file exercising accept/reject boundaries, the pack/unpack round-trip, and the mutation gate.

NOT here: the module, storage, ids, dispatch, batch, return encoding (Phases 17/18a/18b/19). No modification to any file under `src/types/pos_spec/` — those are the vol-type track's and carry 4 red harness tests of their own.

Requirement: **VORD-02** (the only one). Roadmap Phase 16 SC 1–4 are the acceptance contract.
</domain>

<decisions>
## Locked decisions (verified at source, do not re-derive)

### CORRECTION made at plan time — a pure Plank lib CANNOT be tested without FFI
The research asserted (and the pre-review roadmap repeated) that Phase 16 is "independently fuzz-testable with no FFI deploy." **False.** Verified: every `.plk`-touching test in this repo goes through `deployPlank`; the only files without it are pure-Solidity mocks/decoders. Phase 13's own harness header states the reason — "Plank does NOT type-check code unreachable from run{}, so without this entrypoint the lib is unprovable." Mirror `test/exposure/VegaIssuanceKernelHarness.plk` exactly: whole-word calldata reads, header comment documenting each exact signature string, selectors recomputed with `cast sig` (never hand-derived — the v2.0 selector-doc error is the cautionary tale). The phase ordering is still right (pure surface before module), but the cost is a harness, not zero.

### What `validate_order` composes — the exact source facts
Read these before writing a line; the review verified each:
- `spread_tick_assimetry_is_complete` (`SpreadTickAssimetry.plk:11-13`) = `(spread > 0) & (spread < 0xffff)` → **REUSE VERBATIM**. Accepts [1, 65534]; rejects 0 and 65535.
- `vol_range_width_is_complete` (`VolRangeWidth.plk:20-23`) = `(width > 0) & (width <= 0xffffff) & (tickSpacing > 0) & (tickSpacing <= 0xc8)` → **REUSE VERBATIM**, satisfiable because `TICK_SPACING = 20` is pinned (20 ≤ 200 ✓). Do NOT write a "reduced" width check — the conjuncts are inseparable and a zeroed tickSpacing would make the composed validator identically FALSE (rejecting 100% of traffic, under which this phase's own fuzz would pass trivially).
- `tick_volatility_is_complete` (`TickVolatility.plk:7-10`) = `self.vol > 0` — **NO UPPER BOUND**. This is the gap: **AUTHOR a new `strike <= 2^88-1` bound**. Load-bearing, not hygiene — without it an oversized strike passes validation and `pack_vol_order`'s `& 0xFFFFFFFFFFFFFFFFFFFFFF` mask silently stores a *different value than the caller supplied*. Silent corruption, not a revert.

### The packed layout — byte-exact, verified against `VolOrder.plk:35-40`
```
width@128..151 | tickSpacing@104..127 | strike@16..103 | skew@0..15    (152 bits)
```
Store the FULL 152-bit word; `pack_vol_order`/`unpack_vol_order` used **VERBATIM, never modified**. `TICK_SPACING = 20` occupies the tickSpacing field in v1 (corpus convention at `VolOrder.t.sol:102`). The pre-review draft had width and tickSpacing swapped and would have zeroed out `width` — the field every caller supplies.

### DO NOT TOUCH
`wrap_spread_tick_assimetry` (`SpreadTickAssimetry.plk:9`) is `rawSpread << 0xffff` — a shift by 65535 that zeroes everything. It is a real bug, it belongs to the vol-type track, and it must stay OFF the validation path. If a plan needs to construct a `SpreadTickAssimetry`, build the struct literally, never via that wrapper.

### Test discipline (project standard, non-negotiable)
CALLED-green only — "it compiles" is never acceptance. Corpora CONSTRUCTED/repaired, never `vm.assume`-filtered. Non-fuzz unit anchor beside every fuzz (cache-independent by construction). A `runs: 0` kill is a replay, not proof — clear `cache/fuzz` when proving a kill. ONE test file for this surface. Every forge invocation: `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`.

### Claude's Discretion
- Lib path/name (suggest `src/lib/pos_spec/VolOrderValidationLib.plk`, mirroring `src/lib/exposure/VegaIssuanceLib.plk`); harness and test paths.
- Whether `validate_order` returns `bool` (batch needs a non-reverting predicate) or a reverting `require` variant — NOTE Phase 17 needs BOTH behaviours from the SAME logic (strict path reverts, batch path skips), so a `bool`-returning core with a thin reverting wrapper is the shape that makes MCAL-04's by-construction agreement possible. Decide now, since Phases 17/18a depend on it.
- Harness ABI: whole-word `uint256` args like Phase 13's; propose signatures and cast-sig-verify them.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract
- `.planning/ROADMAP.md` Phase 16 section (post-review; SC 1–4 are the acceptance contract, incl. the harness correction).
- `.planning/REQUIREMENTS.md` — VORD-02 exact statement + the milestone's decisions of record.

### Source of truth for the composition (read before writing signatures)
- `src/types/pos_spec/SpreadTickAssimetry.plk` — the skew predicate (and the `<< 0xffff` wrapper bug to avoid).
- `src/types/pos_spec/VolRangeWidth.plk` — the width+tickSpacing predicate.
- `src/types/pos_spec/TickVolatility.plk` — the strike predicate with the MISSING upper bound.
- `src/types/pos_spec/VolOrder.plk` — `pack_vol_order`/`unpack_vol_order` (lines 35-46) and `vol_order_is_complete`.

### Patterns mirrored
- `src/lib/exposure/VegaIssuanceLib.plk` — the pure-lib shape proven in v3.0 (typed newtypes, composes existing primitives, zero reimplementation).
- `test/exposure/VegaIssuanceKernelHarness.plk` — THE harness pattern (whole-word calldata, documented+verified selectors, every branch reachable from `run{}`).
- `test/exposure/VegaIssuance.diff.t.sol` — probe-with-anchor + constructed-corpus fuzz structure; repair-not-reject.
- `test/PlankTestBase.sol` — `deployPlank` and the six module roots (never hand-roll `Dependency[]`).

### Design authority
- `/home/jmsbpp/cfmms-playground/cfmm-wt/lean4-spec/lean/vol_markets/PosSpec.lean:52,56` — `skewTick_one`/`skewTick_zero`: why the u16 skew endpoints are degenerate (they collapse the position to a one-sided range), justifying rejection of 0 and 65535 while 1 and 65534 are valid.
</canonical_refs>

<specifics>
## Specific Ideas

- The four skew boundary cases are the sharpest test in this phase and must be asserted individually: **0 REVERTS, 1 ACCEPTED, 65534 ACCEPTED, 65535 REVERTS**. The requirement's earlier wording ("open interval [1,65534], both endpoints revert") was ambiguous enough that an implementer could have written tests asserting 1 and 65534 revert — which would fail against the real predicate and tempt a "fix" to the vol-type track's file.
- SC 1 demands **at least one tuple ACCEPTED**. This is not filler: an all-reject validator satisfies every other criterion in the phase, and that is precisely what the pre-review design would have produced.
- The strike-bound mutant is the phase's best falsifiability test because its failure is *silent*: pick a strike ≥ 2^88 whose masked value differs, assert the stored/round-tripped value equals the input, and confirm the mutant (bound deleted) reddens with a value mismatch rather than a revert.
</specifics>

<deferred>
## Deferred Ideas

- Module, storage, ids, dispatch, readers — Phase 17.
- Batch decode/guards/loop/skip — Phase 18a. Return encoding — Phase 18b. Full differential + battery + PLANK_SKIP exit — Phase 19.
- On-chain pricing, auth, events, cancellation — out of milestone.
</deferred>

---

*Phase: 16-type-packing-validation-foundation*
*Context gathered: 2026-07-20, from the post-review roadmap + source-verified facts; harness correction applied at `c6a7dbb`*
