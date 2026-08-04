# Phase 17: Interface & Single-Call Module - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning
**Source:** The post-review v4.0 roadmap/requirements (`7fbc371`) + the API Phase 16 actually shipped (read from source at `5ab41e0`, not inferred).

<domain>
## Phase Boundary

`create_order` becomes a live, CALLED-green registry entrypoint — the base case the batch composes N times:

1. `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — selector constants for BOTH entrypoints (single + batch) and the readers, each with its exact Solidity signature string in a header comment.
2. `src/modules/pos_spec/VolOrderManagerMod.plk` — dispatch, `orderCount` id assignment, derived-slot store, readers. ZERO domain arithmetic.
3. One test file proving every branch CALLED-green, plus this phase's mutation gate.

NOT here: the batch loop, calldata guards, `MAX_BATCH`, return encoding (18a/18b), the full differential + consumer fixture + `PLANK_SKIP` exit (19).

Requirements: **VORD-01, VORD-03, VORD-04, VORD-05**. Roadmap Phase 17 SC 1–5 are the acceptance contract.
</domain>

<decisions>
## Locked decisions

### The Phase-16 API this phase consumes (read from source — use verbatim, do not re-derive)
`src/lib/pos_spec/VolOrderValidationLib.plk` exports:
- `build_vol_order(strike: u256, width: u256, skew: u256) VolOrder` — constructs the struct with `TICK_SPACING = 20` already filled in. **Use this**; do not hand-build the struct in the module (that would put domain knowledge in the module).
- `validate_order(self: VolOrder) bool` — the non-reverting CORE. Phase 18a's batch calls this.
- `validate_order_strict(self: VolOrder) void` — the reverting wrapper (`require`, empty revert). **This phase's `create_order` calls THIS.**
- `TICK_SPACING = 20`, `MAX_STRIKE = 0xFFFFFFFFFFFFFFFFFFFFFF`.

That both paths descend from the same `validate_order` is what makes MCAL-04's "strict and batch agree by construction" true rather than aspirational — preserve it.

### Storage
`array_slot(base_slot, index)` from `v3::storage` (`lib/plankified-univ3/plank/lib/storage.plk:230`) = `keccak256(base_slot) + index`, used VERBATIM. The ring's 16-bit index mask lives in a DIFFERENT file (`src/types/StorageIndex.plk`) and must NOT be imported — it is load-bearing for a 2^16 ring and corrupting for a monotonic registry.

Scalar slots follow `VegaAccountMod`'s idiom: keccak-derived constants with the preimage string in a comment (e.g. `"VolOrderManagerMod.orderCount"`), restated test-side so `vm.load` addresses are computable in Solidity. Compute every one with `cast keccak` — never hand-derive.

### Ids and the sentinel
Sequential `uint256` from 1; `orderCount` advances ONLY on success and doubles as the id source. Slot `keccak(base)+0` is never written and stays zero. The 0-sentinel is SOUND, not lucky: a valid order always has `strike > 0` and `skew > 0`, so a validly packed word is never 0 — therefore `packed == 0 ⟺ nonexistent`. State that reasoning in-code; VORD-05's "returns 0 for nonexistent, no revert" depends on it.

### Both selectors pinned HERE
`create_order(uint88,uint24,uint16)` = `0x6501fe94` AND `create_orders(uint256,uint256[])` = `0x81357911` — both `cast sig`-verified, both decisions of record in the milestone Overview. Pinning the batch selector now breaks the 17↔18a circular dependency the review caught (Phase 17 could not pin a signature Phase 18a had not yet designed). Phase 18a implements it; this phase declares it.

### "Zero arithmetic in the module" — the precise meaning
No DOMAIN arithmetic. The only permitted operations are the id increment, the `array_slot` call, and (in 18a) the loop counter. All bounds live in the lib, all packing in the type. This was ambiguous in the pre-review draft and is now defined — do not re-litigate it at verification time.

### DO NOT TOUCH
`src/types/pos_spec/*` — the vol-type track owns it, 4 tests are red there, and one of those reds traces to a real bug we diagnosed and reported (`return_split_tick` writes `out_ptr +% 32` twice) but must not fix. Also never call `wrap_spread_tick_assimetry` (`rawSpread << 0xffff` — zeroes any input).

### Test discipline
CALLED-green only; every dispatch branch exercised by a test (plank does not type-check code unreachable from `run{}`). Guards asserted ON STATE (`orderCount` unchanged), never on return data — a silent-zero write and a revert look identical from the return value. Constructed corpora, no `vm.assume`. Non-fuzz anchor beside every fuzz. Clear `cache/fuzz` when proving a kill. ONE test file for this surface. Every forge run: `--via-ir --optimize --skip 'src/modules/protocol_integrations/PriceSetterHook.sol'`.

### Claude's Discretion
- Exact file paths (suggest `src/modules/pos_spec/` and `src/interfaces/pos_spec/`, mirroring the `exposure/` layout).
- Reader signatures (`orderCount()`, `getOrderPacked(uint256)` are named in the requirements; propose exact strings and cast-sig-verify).
- Whether the test file is new or extends Phase 16's — the module is a new surface, so a new file matching the `VegaAccount.t.sol` precedent is the likely answer; justify the choice.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract
- `.planning/ROADMAP.md` Phase 17 section (post-review SC 1–5).
- `.planning/REQUIREMENTS.md` — VORD-01/03/04/05 + the v4.0 decisions of record.

### The API consumed (read before writing any call)
- `src/lib/pos_spec/VolOrderValidationLib.plk` — `build_vol_order`, `validate_order`, `validate_order_strict`, `TICK_SPACING`, `MAX_STRIKE`.
- `src/types/pos_spec/VolOrder.plk` — `pack_vol_order`/`unpack_vol_order` (layout `width@128 | tickSpacing@104 | strike@16 | skew@0`, 152 bits).
- `lib/plankified-univ3/plank/lib/storage.plk:230` — `array_slot`.

### Patterns mirrored (transcribe the idioms, don't invent)
- `src/modules/exposure/VegaAccountMod.plk` — THE module pattern: `init{ return_runtime(); }`, `@evm_shr(224, @evm_calldataload(0))` dispatch, calldata args at 4/36/68, write branches `@evm_stop()`, views `return_u256`, fallthrough `revert_empty()`, keccak slot constants with preimage comments.
- `src/interfaces/exposure/VegaAccountInterface.plk` — the interface-file shape (signature strings + provenance).
- `test/exposure/VegaAccount.t.sol` — module test structure incl. raw `vm.load` slot assertions and state-based guard assertions.
- `test/types/pos_spec/VolOrderValidationHarness.plk` (Phase 16) — harness idioms if any additional surface needs exposing.
- `test/PlankTestBase.sol` — `deployPlank`, six module roots.
</canonical_refs>

<specifics>
## Specific Ideas

- The slot-distinctness assertion needs the scalar slot addresses computable test-side: declare the same preimage strings in Solidity and `keccak256(bytes(...))` them. A preimage mismatch shows up as `vm.load` reading 0 where a value was written — loud, which is what we want.
- A second order must get id 2 in the same test that proves the first got id 1 — that is what demonstrates monotonicity and rules out the ring mask having been imported.
- The invalid-tuple revert test should use a tuple that fails EXACTLY ONE conjunct (e.g. skew = 65535, everything else valid) so the test names which guard fired rather than passing for a compound reason.
</specifics>

<deferred>
## Deferred Ideas

- Batch decode/guards/loop/skip/MAX_BATCH — Phase 18a. Return encoding — Phase 18b. Full differential, mutation battery over the whole surface, consumer golden fixture, `PLANK_SKIP` exit — Phase 19.
- Pricing, auth, events, cancellation — out of milestone.
</deferred>

---

*Phase: 17-interface-single-call-module*
*Context gathered: 2026-07-20 — Phase 16's shipped API read from source, not inferred*
