# Project Research Summary

**Project:** VolOrderManagerMod + best-effort Multicall (milestone v4.0)
**Domain:** Plank/EVM on-chain dynamic-registry module with a best-effort batch entrypoint, consumed by the rpc_api Haskell `StochasticOrderGen` (Poisson order-arrival generator)
**Researched:** 2026-07-19
**Confidence:** HIGH

## Executive Summary

This milestone builds `VolOrderManagerMod.plk`: a single-function self-batcher that validates `(strike, width, skew)` tuples against the already machine-checked `vol_order_is_complete` predicates, assigns sequential ids, and stores a packed `VolOrder` word — plus a best-effort batch entrypoint that runs N of that same internal `create_order` in one transaction, skipping invalid tuples without reverting the batch. It is explicitly **not** a generic Multicall3-style call router: the input is always `(strike,width,skew)` tuples, never `(address,bytes)`, and there is deliberately no arbitrary-target dispatch, no auth model, and no on-chain pricing. Expert precedent for the *result semantics* (parallel `(success, payload)[]`, positional alignment, `tryAggregate(false,...)`-style best-effort) is Multicall3, but the architecture stays a closed, single-opcode-path batcher, which is what keeps reentrancy and delegatecall risk off the table entirely (verified N/A by PITFALLS).

The recommended approach, now that STACK has closed out the milestone's load-bearing unknowns: everything required is expressible in Plank v0.1.1. Loop over N tuples with a plain runtime `while` (proven via the diff-tested `merkle_airdrop.plk`); read the batch from calldata with `@evm_calldataload`/`@evm_calldatasize` at computed offsets; contain per-call failure with a **pure-validation pre-check** (branch-only bounds checks, no checked-ops, no state write on failure) rather than a self-call boundary, because `create_order` is a pure bounds-only registry with no revert-prone dependency calls; and hand-roll the dynamic `(bool,uint256)[]` return since Plank has no native array type or `T[]` ABI codec. The architecture mirrors v3.0's proven layering exactly (zero arithmetic in the module, all bounds/reverts in a pure lib, packing in the type layer, slot derivation reused verbatim from `v3::storage::array_slot`) with one adaptation: the registry's ids are monotonic and must **not** import the RealizedVolatility ring's 16-bit wraparound mask.

The dominant risk is not "can Plank express this" (STACK resolved that to yes) but **proving the best-effort contract is actually total**: because inline pre-validation runs in a single call frame with no sub-call to unwind, any revert path the validation didn't enumerate — a checked-add overflow, a `VolOrder` smart-constructor precondition — aborts the *entire* batch, silently converting "best-effort" into "all-or-nothing." The second-order risks are a missing `calldatasize` guard (calldata reads past `calldatasize` return zero-padded words, not a revert, so a truncated batch can validate a phantom order), an unbounded `MAX_BATCH` (out-of-gas cannot be contained by any best-effort mechanism — it unwinds the whole tx, including already-processed successes), and the batch's dynamic return encoding (this module's first-ever dynamic ABI output, no compiler-checked encoder). All four are addressed below with concrete phase-level acceptance criteria.

## Key Findings

### Recommended Stack

This milestone is a Plank v0.1.1 **language-capability audit**, not a dependency-selection task — the "stack" is the confirmed set of compiler builtins the module needs, each independently verified against `plankc` source, the grammar, and a compiled diff-test.

**Core mechanisms:**
- Runtime `while` loop (`lowerer/mod.rs:736`) — the only loop construct in the grammar; proven end-to-end by the diff-tested `merkle_airdrop.plk`. `inline while` (comptime unroll) is parsed but **not implemented** in v0.1.1 (lowering emits `error_not_yet_implemented`, locked by a regression test) — do not design around it.
- `@evm_calldataload(computed_offset)` + `@evm_calldatasize()` — both exist and are proven with a runtime-computed offset in the same diff-test; this is the mechanism for reading the i-th tuple and for the mandatory truncation guard.
- Manual return encoding (`@malloc_uninit` + `@mstore32` at computed offsets + `@evm_return(ptr,len)`) — no native array type exists and `std::abi` does not encode `T[]`, so the dynamic `(bool,uint256)[]` result must be hand-built; this is the same pattern already used for `VolOrder.plk`'s packed-word return and `merkle_airdrop.plk`'s dynamic-length return.
- Pure-validation pre-check (branch-only, `@evm_iszero`/comparisons, no checked-ops) as the best-effort containment mechanism, **not** a self-`@evm_call` boundary — sufficient and cheaper because `create_order`'s only failure modes are bounds checks, with the self-call kept as a documented fallback if a future dependency call needs it.
- `v3::storage::array_slot(base, index) = keccak256(base) + index` — reused verbatim from the RealizedVolatility ring, **without** the ring's 16-bit wraparound mask (that mask is load-bearing for a ring, corruption-causing for a monotonic-id registry).

### Expected Features

**Must have (table stakes):**
- `create_order(uint88,uint24,uint16)` — cast-sig-verified selector `0x6501fe94`, strict/revert single-call path, reusing `vol_order_is_complete`'s constituent predicates verbatim
- Sequential `uint256` id from 1 (0 reserved as null sentinel), `orderCount` accumulator doubling as id source
- Persistent storage at a keccak-derived slot per order (`array_slot`), monotonic, no wraparound
- Best-effort batch entrypoint — the milestone's reason to exist; dynamic-length calldata in, dynamic `(success, orderId)[]` results out, never reverting on empty or all-fail input
- Readers `orderCount()` and `getOrder(uint256)`/`getOrderPacked(uint256)` returning the packed word (0 for nonexistent ids, no revert)
- Interface file with cast-sig-pinned selector strings, shared byte-for-byte with the rpc_api Haskell consumer

**Should have (differentiators):**
- No-partial-state guarantee on failed calls (validate-before-any-write, proven by raw `vm.load`, not getters)
- Batch == exact N-fold composition of the same internal `create_order` (single ≡ batch-of-1 differential; prevents batch/single logic drift)
- Solidity reference-mock differential for the batch, extending v3.0's constructed-corpus + observed-red discipline to the new dynamic-array surface

**Defer (v4.x / later):**
- `MAX_BATCH` numeric value and the typed-vs-opaque return-shape decision — both pending peer confirmation (see Cross-Resolutions below); proceed with placeholders now, tune after
- Per-owner order books / `msg.sender` auth — no auth primitive in v1, orders anonymous by design
- Events for an indexer — no log-subscribing consumer this milestone
- On-chain pricing (`tick_bucket_from_vol_order`) — pos_spec pricing has 4 red harness tests and stays explicitly out of scope; registry stores the raw validated tuple only

### Architecture Approach

The module mirrors v3.0's proven layering: **zero arithmetic in the module** (dispatch, `orderCount++`, `sstore`/`sload` only), with all bounds checks in a new pure lib (`validate_order`, composing the existing `tick_volatility_is_complete` / `spread_tick_assimetry_is_complete` / a reduced width check), packing in the existing `VolOrder.plk` type, and slot derivation reused verbatim from `v3::storage`. The two genuinely new elements are a derived-slot dynamic registry (the ring's slot-per-index mechanism, minus the wraparound mask) and a best-effort batch loop over calldata.

**Major components:**
1. `VolOrderManagerInterface.plk` — cast-sig-pinned selector strings for `create_order`, the batch entrypoint, and readers; shared by module dispatch and the Solidity test ABI
2. `VolOrderManagerMod.plk` — dispatch, id assignment (`orderCount++`), `sstore` at `array_slot(SLOT_ORDERS_BASE, id)`, the best-effort batch loop (validate-before-commit, per-call skip) — no arithmetic
3. `validate_order` (new pure lib) — composes existing `*_is_complete` predicates plus the explicit zero-width revert; independently fuzz-testable with no FFI deploy
4. `VolOrder.plk` (existing type) — `pack_vol_order`/`unpack_vol_order`; stores the create_order-native **128-bit subset** (see Cross-Resolutions)
5. Test-side `VolOrderDecoder` (new, `TimepointDecoder`-precedent) — the single test-side unpacker restating the type's offsets, used by raw-`vm.load` differential assertions

### Critical Pitfalls

1. **Incomplete validation silently converts best-effort into all-or-nothing** — inline pre-validation runs in one call frame with no sub-call to unwind, so any store-path revert the validation didn't enumerate (checked-add overflow, a `VolOrder` constructor precondition) aborts the whole batch. Avoid by proving **totality**: full-width-`uint256` fuzz that the batch entrypoint never reverts at the batch level, plus a `multicall_flag(tuple) == fail ⟺ standalone create_order reverts` completeness differential. A deleted validation branch must redden the totality fuzz with a *batch revert*, not a wrong value.
2. **Partial state on a skipped call** — a write (id allocation, slot write) that precedes the failure check persists because there is no frame to unwind. Avoid by enforcing validate-completely-before-any-write in source, and proving no-footprint with raw `vm.load` on the touched slot set (not getters — getters miss slot aliasing).
3. **Calldata-length lies** — `calldataload` past `calldatasize` returns zero-padded words silently; a truncated batch can validate a phantom `(0,0,0)`-ish tuple. Avoid with a mandatory `calldatasize >= HEADER + N*STRIDE` guard that **reverts the whole tx** on a malformed batch — this is a structural failure, not a per-call skip, and supersedes any reliance on the zero-width guard as truncation defence.
4. **Unbounded N cannot be best-effort'd** — OOG unwinds the entire transaction including already-processed successes; no containment mechanism catches resource exhaustion. `MAX_BATCH`, checked before any work, is load-bearing, not hygiene — `N=MAX_BATCH+1` must revert before any `sstore`, and `N=MAX_BATCH` must be gas-measured under the block limit.
5. **Return-data encoding bugs** — the module's first-ever dynamic ABI return (offset word → length word → elements); off-by-one in length/offset/index is the classic footgun with no compiler-checked encoder. Avoid via a differential against an independently-simple Solidity reference mock (never one that echoes Plank's own output), corpus including `N=0` (trickiest edge) and mixed success/failure.

## Cross-Resolutions (research files disagreed or left open — resolved here so requirements does not inherit ambiguity)

1. **Plank loop mechanics — PITFALLS flagged MEDIUM/LOW-confidence open ("Plank v0.1.1 loop/recursion constructs unverified"); STACK resolved it with compiler citations.** Resolution: runtime `while` EXISTS and is fully lowered (`lowerer/mod.rs:736`), proven end-to-end by the diff-tested `merkle_airdrop.plk`. There is no `for`/`loop`/`break`/`continue` in the grammar, and `inline while` (comptime unroll) is parsed but **not implemented** — do not design around it. The multicall is a plain bounded `while i < count { ... }`, not unrolled and not recursive. PITFALLS' gap note is superseded; carry its off-by-one/OOG test discipline forward against this confirmed mechanism.

2. **tickSpacing 152-bit vs 128-bit tension.** FEATURES frames this as "pin a default so the width validator has an operand"; ARCHITECTURE frames it as "store the 128-bit subset." **These compose, they do not conflict:** `create_order(uint88,uint24,uint16)` supplies strike/width/skew only (128 bits), no `tickSpacing`. The registry (a) **stores** the 128-bit subset (`skew | volStrike | width` at offsets 0/16/104; bits 128-151 zeroed, `tickSpacing` deferred with pricing) and (b) **validates** width against a reduced check (`width>0 & width<=0xffffff`) that does not need a `tickSpacing` operand at all — so no default value is actually consumed by validation. **Flag as a decision of record:** if a future caller path needs the full `vol_range_width_is_complete` (unlikely this milestone, since pricing is out of scope), the test corpus's `tickSpacing=20` convention (`VolOrder.t.sol:102`) is the candidate default — pin it explicitly if that path is ever exercised.

3. **Truncation defence — PITFALLS' calldatasize-guard-REVERT supersedes FEATURES' zero-width-catches-it framing.** FEATURES did not treat truncation as a distinct case; PITFALLS shows the zero-width backstop is insufficient on its own (a truncation that zeroes only the `skew` field can still produce a plausibly-valid tuple). Resolution: a malformed/short batch (`calldatasize < HEADER + N*STRIDE`) **reverts the whole transaction**, it does not silently skip or fall through to zero-width validation. Zero-width remains a backstop for genuinely-submitted zero-width tuples, not the truncation defence.

4. **Batch shape — STACK's verdict resolves ARCHITECTURE's open Option A vs B.** ARCHITECTURE presented both a head-count-then-dynamic-tuples layout (Option A) and a fixed-max-with-count layout (Option B) without resolving between them, pending the capability audit. STACK confirms both are technically expressible (loops and computed calldata offsets both exist) but recommends, and this summary adopts, **shape B: bounded max-N batch with an explicit `count` argument** — a pure guard `count <= MAX_BATCH` before the loop, `while i < count`, results buffer sized `head + count*stride`. This bounds gas deterministically, gives a clean early revert on oversized batches instead of an OOG surprise, and matches the pending peer batch-size-cap expectation. Requirements should specify shape B, not present both as still-open.

5. **Still genuinely open (peer-dependent — do not resolve, do not block on):**
   - **`MAX_BATCH` numeric value** — pending confirmation from peer `mv15a18k`. Requirements should carry a **named placeholder constant** (not a guessed number) with the acceptance criteria from PITFALLS Pitfall 4 (`N=MAX_BATCH+1` early-reverts, `N=MAX_BATCH` gas-measured) written against the placeholder so the value can be substituted without touching test structure.
   - **Typed `(bool,uint256)[]` vs opaque `membytes` blob** for the batch return — STACK flags this as an open ABI decision affecting how much manual array encoding the module carries; FEATURES recommends the typed pair on Haskell-ABI-decoder-ergonomics grounds (a static-tuple array needs no recursive offset chasing) with MEDIUM-HIGH confidence. **Requirements should proceed with the typed `(bool success, uint256 orderId)[]` pair** as the working design, flagged for peer confirmation rather than left undecided — this is the FEATURES recommendation and it is architecturally compatible with everything else resolved above.

## Implications for Roadmap

Based on combined research, four phases (continuing numbering from 16 — v3.0 ended at phase 15):

### Phase 16: Type Packing & Validation Foundation
**Rationale:** Pure functions, independently fuzz-testable with no FFI deploy — the cheapest surface to get right first, and everything downstream (module, batch) depends on it. Resolves the 128-bit-subset packing decision (Cross-Resolution 2) up front.
**Delivers:** `VolOrder.plk` pack/unpack confirmed for the 128-bit create_order-native subset (offsets 0/16/104, bits 128-151 zeroed); new `validate_order` pure lib composing `tick_volatility_is_complete`, a reduced width check (`width>0 & width<=0xffffff`, no `tickSpacing` operand needed), and `spread_tick_assimetry_is_complete`, with explicit zero-width revert and dirty-high-bit rejection.
**Addresses:** FEATURES table-stakes "bounds validation via `vol_order_is_complete`."
**Avoids:** PITFALLS Security Mistake (unmasked/unvalidated dirty high bits on u88/u24/u16 fields); lays the groundwork for Pitfall 1 (validation completeness) by keeping the guard set enumerable from day one.

### Phase 17: Interface & Single-Call Module
**Rationale:** The single-call path is the peer-confirmed contract of record (`0x6501fe94`) and the base case the batch will compose N times — get it CALLED-green and differentially tested before building the batch on top.
**Delivers:** `VolOrderManagerInterface.plk` with cast-sig-pinned `create_order` selector plus reader selectors; `VolOrderManagerMod.plk` single-call dispatch — validate via lib, pack via type, `orderCount++`, `sstore` at `array_slot(SLOT_ORDERS_BASE, id)` (monotonic, no ring mask); readers `orderCount()`/`getOrderPacked(uint256)`.
**Uses:** `v3::storage::array_slot` reused verbatim; `@evm_sload`/`@evm_sstore`/`@evm_iszero` from the STACK builtin audit.
**Implements:** the module/lib/type layer split from ARCHITECTURE (zero arithmetic in the module).
**Avoids:** Anti-Pattern 1 (importing the ring's wraparound mask); Pitfall 6 groundwork (id/count on the correct side of validation); Pitfall 7 (selector drift — cast-sig test from day one).

### Phase 18: Best-Effort Batch Entrypoint
**Rationale:** The milestone's stated main technical risk and reason to exist; depends on Phases 16-17 (the internal `create_order` fn and validation lib it composes N times) and on the batch-shape decision now resolved (Cross-Resolution 4: shape B).
**Delivers:** batch selector decoding `count` + bounded `while i < count` over fixed-stride tuples (`@evm_calldataload(base + i*STRIDE)`); a **mandatory `calldatasize` guard** that reverts the whole tx on a malformed/short batch (Cross-Resolution 3); a `MAX_BATCH` placeholder constant with `count <= MAX_BATCH` checked before any work; validate-before-commit per tuple (pure-validation skip, no self-call); manual `(bool success, uint256 orderId)[]` ABI encoding built in the same loop, `@malloc_uninit` + `@mstore32` + `@evm_return`.
**Addresses:** FEATURES "best-effort batch entrypoint," "per-call `(success, orderId)` result."
**Avoids:** PITFALLS Pitfall 1 (containment leak — totality fuzz + completeness differential as this phase's acceptance property, not hygiene), Pitfall 2 (partial state — validate-before-write, raw `vm.load` footprint battery), Pitfall 3 (calldata-length lies), Pitfall 4 (unbounded N/OOG), Pitfall 5 (return-encoding off-by-one, especially the `N=0` edge).

### Phase 19: Differential, Mutation Battery & Consumer Fixture
**Rationale:** Closes the milestone against v3.0's acceptance discipline — every prior phase's claims must be CALLED-green through FFI and mutation-killed, not merely "compiles." This is also where the peer-open items (Cross-Resolution 5) get pinned against a real fixture.
**Delivers:** independently-simple Solidity reference mock (not an echo of Plank output) mirroring both single-call and batch semantics; after-every-write driver (`_createOrderBoth`/`_batchBoth`) asserting `orderCount` + stored packed word + returned id/results at tolerance 0; raw-`vm.load` derived-slot assertions via a new `VolOrderDecoder` (promoted from `VolOrder.t.sol`'s existing pack/unpack, not a fourth copy); observed-RED mutation battery per PITFALLS §Pitfall-to-Phase Mapping (id-density, checked-vs-wrapping, `@evm_iszero`-vs-`@evm_not`, cached-fuzz-replay-with-unit-anchor); captured golden calldata/return fixture from the peer's PR #9 to close out `0x6501fe94` + the `Result` ABI shape; `PLANK_SKIP` exit gated on CALLED-green multicall dispatch.
**Addresses:** FEATURES "v3.0 test discipline" MVP item; resolves the two peer-dependent open items from Cross-Resolution 5 against real peer data if available by this point.
**Avoids:** PITFALLS Pitfall 8 (repo-catalogued loop failure modes — `vm.assume` exhaustion, cached-fuzz replay, checked-vs-wrapping, `@evm_not` bitwise trap, dead-module green compile), Technical Debt Pattern "reuse Plank output in the Solidity mock" (vacuous differential).

### Phase Ordering Rationale

- Pure-function phases (16) precede FFI-deploy phases (17-19) — cheapest, fastest-to-redden surface first, matching ARCHITECTURE's "independently testable without the module" split.
- Single-call (17) precedes batch (18) because the batch is an exact N-fold composition of the same internal fn (FEATURES differentiator) — proving the base case first makes the `single ≡ batch-of-1` differential meaningful rather than aspirational.
- Batch (18) is isolated as its own phase because it carries the milestone's five critical pitfalls and its own STACK-resolved calldata/loop mechanics — bundling it with 17 would mix a well-precedented pattern (single-call, mirrors `VegaAccountMod.plk` almost exactly) with the genuinely novel one (dynamic calldata + dynamic return).
- The acceptance/battery phase (19) is deliberately last and separate, not folded into 18, because PITFALLS treats totality-proof and mutation-kill as *the* acceptance property of the whole milestone, not incidental hygiene — it needs the full module (16-18) in place to run the cross-batch stateful invariant and the consumer fixture.

### Research Flags

Needs deeper research during planning:
- **Phase 18 (Best-Effort Batch Entrypoint):** the dynamic-array-ABI-in-Plank surface is genuinely new ground for this codebase (no existing selector takes anything but fixed words). Even with STACK's capability audit confirming the underlying builtins, the exact `while`-loop + computed-offset idiom and the hand-rolled ABI dynamic-array head/tail encoding should get a focused `/gsd:research-phase` pass before implementation, using `merkle_airdrop.plk` as the primary precedent to study line-by-line.
- **Phase 19 (fixture pinning):** if the peer (`mv15a18k`) has not yet answered the open semantics message (MAX_BATCH value, return-shape confirmation) by the time this phase starts, treat it as a coordination checkpoint, not a research gap — proceed with the placeholder constant and typed-pair design per Cross-Resolution 5, and do not block phase completion on peer response.

Standard patterns (skip research-phase):
- **Phase 16 (Type & Validation):** directly mirrors existing `*_is_complete` predicates and `VolOrder.plk`'s existing packing precedent; no new mechanism.
- **Phase 17 (Interface & Single-Call Module):** near-verbatim mirror of `VegaAccountMod.plk`'s dispatch/scalar-slot/reader pattern, already proven in v3.0.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every claim in STACK.md cites `plankc` source line numbers, the grammar doc, or a compiled+diff-tested example (`merkle_airdrop.plk`); the loop-mechanics gap PITFALLS flagged is fully closed by this. |
| Features | HIGH | Validation bounds cited from actual kept `.plk` types and cross-checked against the Lean spec (`PosSpec.lean`); multicall result-shape verified against real Multicall3 source, not inference. |
| Architecture | HIGH | Slot derivation, packing layout, and layer-split rules are transcribed verbatim from existing repo source (`storage.plk`, `RealizedVolatilityMod.plk`, `VegaAccountMod.plk`); the one item ARCHITECTURE itself left open (batch shape A vs B) is resolved by Cross-Resolution 4 above. |
| Pitfalls | HIGH | On repo-specific/EVM semantics (grounded in `.planning/STATE.md` catalogued kills and standard `calldataload`/OOG/revert-frame behavior); the one flagged gap (Plank loop semantics) is resolved by Cross-Resolution 1. |

**Overall confidence:** HIGH

### Gaps to Address

- **`MAX_BATCH` numeric value** — not yet confirmed by peer `mv15a18k`. Handle in Phase 18/19 by using a named placeholder constant with test structure written against it (per PITFALLS Pitfall 4's acceptance criteria), so the value substitutes cleanly once confirmed.
- **Typed `(bool,uint256)[]` vs opaque `membytes` return** — FEATURES recommends typed pairs (MEDIUM-HIGH confidence) but this is not yet peer-confirmed. Handle by building the typed-pair design in Phase 18 and treating peer disagreement as a late Phase 19 adjustment, not a blocker — the underlying loop/validation/storage logic is unaffected either way.
- **Batch selector string** — depends on the finalized signature once the count/tuple layout (shape B) is locked; pin it in Phase 17's interface file alongside `create_order`, then cast-sig-verify again in Phase 19 once the peer confirms.

## Sources

### Primary (HIGH confidence)
- `plankc/frontend/session/src/builtins.rs:180-289` — complete builtin registration table
- `plankc/frontend/hir/src/lowerer/mod.rs:725-736` — `while` lowered, `inline while` rejected
- `plankc/frontend/hir/src/tests.rs:779` — `test_inline_while_not_yet_supported` locking test
- `plankc/docs/Grammar.md:45` — `while` is the sole loop rule
- `plankc/plank-diff-tests/src/examples/merkle_airdrop.plk` + paired `MerkleAirdrop.sol` — compiled+diff-tested runtime `while` + computed `@evm_calldataload` offset
- `lib/plankified-univ3/plank/lib/storage.plk:230-235` — `array_slot` slot derivation
- `src/types/pos_spec/VolOrder.plk`, `VolRangeWidth.plk`, `TickVolatility.plk`, `SpreadTickAssimetry.plk` — kept types and `*_is_complete` bounds
- `src/modules/exposure/VegaAccountMod.plk` + `src/interfaces/exposure/VegaAccountInterface.plk` — zero-math-in-module, scalar-slot + selector-pinning precedent
- `src/modules/market_state_measurements/RealizedVolatilityMod.plk`, `src/types/StorageIndex.plk:19-34` — ring write/read path and the wraparound mask that must NOT be imported
- `test/exposure/VegaAccount.e2e.t.sol`, `test/types/pos_spec/VolOrder.t.sol` — after-every-write driver, differential discipline, existing pack/unpack test conventions
- `lean4-spec/lean/vol_markets/PosSpec.lean` — skew open-interval justification
- Multicall3 source `github.com/mds1/multicall` — `aggregate3`/`tryAggregate`/`aggregate` semantics (verified)
- `.planning/PROJECT.md` — milestone goal, consumer contract, anti-scope
- `.planning/STATE.md` Accumulated Context — catalogued kills (checked-vs-wrapping, `@evm_not` trap, `vm.assume` exhaustion, cached-fuzz replay, slot-aliasing, vacuous-mock discipline)
- EVM semantics — `calldataload` zero-padding past `calldatasize`, OOG/revert frame-unwind behavior, 63/64 gas rule (standard)

### Secondary (MEDIUM confidence)
- ERC-4337 `executeBatch` atomic-batch contrast (training-derived, used only to justify rejecting atomicity)

---
*Research completed: 2026-07-19*
*Ready for roadmap: yes*
