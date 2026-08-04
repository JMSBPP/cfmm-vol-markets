# Phase 21: V2 ABI Re-Pin & targetVega Generation - Context

**Gathered:** 2026-07-31
**Status:** Ready for planning

<domain>
## Phase Boundary

The Haskell client speaks V2 on every byte layout that crosses the wire — call calldata,
batch input word, storage word, and log — with each selector and topic0 pinned by a test
that COMPUTES it from the signature string; and `StochasticOrderGen` supplies `targetVega`
per order in raw LIQUIDITY units. Requirements: RPIN-01..06, VEGA-01.

Out of scope (Phase 22): running the live stochastic drivers end-to-end. This phase makes
the client *correct*; Phase 22 *drives* it.

</domain>

<decisions>
## Implementation Decisions

### targetVega generation — structure LOCKED, draw law is a RESEARCH TARGET
- **The draw law is NOT decided here.** The user's instruction: *"This needs to be
  researched on how empirically and in practice this is chosen."* The researcher MUST
  investigate how vega / liquidity-notional magnitudes are chosen empirically and in
  practice, then RECOMMEND a law with evidence. Candidate laws considered but explicitly
  NOT selected: log-uniform over the band, linear-uniform, fixed constant. Do not default
  to one without the research finding.
  - Local material to mine first (see canonical refs): `notes/UNITS_AND_SCALES.md` §2 —
    the vega axis / dimension decision (ii), and the origin of the "realistic pool
    liquidity 1e18–1e21" claim (§2 headroom note); `../plank/notes/VOLATILITY_INSTRUMENTS.md`;
    `../plank/refs/` (`DemeterfietalVarianceSwaps.pdf`, `greeks/`, `bunni-v2.pdf`).
  - Per the user's global rule, prefer the **arxiv MCP over web search** for academic
    sources.
  - Deliverable: a recommended draw law with its empirical justification, expressed so the
    planner can encode it as a `VegaDraw` constructor with concrete parameters.
- **Type surface (LOCKED):** `StochasticOrderGen` gains `vega_draw :: VegaDraw`, where
  `VegaDraw` is a one-constructor sum type — mirroring `ArrivalProcess` / `ProcessType`,
  the established convention for "one law today, room for another later". The constructor's
  name and fields follow from the research finding.
- **Verification (LOCKED):** belt and braces —
  (a) `cabal test` draws N orders with a **fixed seed** and asserts every drawn
  `targetVega` is within `[1, 2^96−1]` AND within the configured band; and
  (b) the generator **guards at draw time and fails loudly** on an out-of-band value,
  matching `StochasticPriceGen.Simulate`'s domain-guard discipline.

### Pin tests
- **Location (LOCKED):** extend Phase 20's `offchain/test/Main.hs` — one suite, one
  `cabal test` gate. It already carries the `.plk` signature parser, `keccak256`
  recompute, and a working falsifiability case; a second module would risk two divergent
  parsers.
- **Pin source (LOCKED):** each test **recomputes keccak from the signature string in the
  interface `.plk` file** (satisfying SC-1/SC-3's "DERIVED, never a transcribed literal"
  literally), **then cross-checks agreement with `offchain/rig/rig-pins.json`**. Either
  disagreement — stale pin file, or drifted interface file — is a loud failure.

### Field validation
- **Keep the shipped `Either String` per-field message pattern.** `pack_vol_order_input`
  extends from three fields to four with the same shape; each field rejects its own
  out-of-range value with an attributable message. This is the pattern that caught the
  v4.0 silent-corruption bug — no new error type, no smart-constructor refactor.
- `targetVega` is now the **unmasked TOP field** (bits 128..223 in the input word),
  inheriting the dirty-bit-rejection role `width` held in V1; bits ≥ 224 must be zero BY
  CONSTRUCTION.

### V1 disposition
- **Delete the V1 3-arg `create_order` path outright.** `encode_create_order` becomes
  V2-only (`create_order(uint88,uint24,uint16,uint96)` = `0x98d950ec`). V1
  (`0x6501fe94`) is RETIRED-NEVER-LIVE — nothing was ever deployed under it, so there is
  no on-chain history to stay compatible with, and a dead second encoder is precisely the
  rot this phase exists to stop.
- The retired constants (`0x6501fe94`, v1 E1 topic0 `0x6a5dc726…`, the stale
  `0xa8892769…`) remain in `rig-pins.json`'s `retired` block — they are the **subjects**
  of the RPIN-04 falsifiability test, not live values.
- NOTE (from Phase 20's 20-05 summary): `offchain/rig/generate-pins.sh` currently parses
  the stale topic0 out of `src/modules/VolOrderManagerMod.plk` (the superseded duplicate).
  Deleting V1 code from `Encoding.hs`/`Decode.hs` must not break that generator — verify
  `generate-pins.sh` still reproduces `rig-pins.json` byte-identically after the purge.

### Claude's Discretion
- `VegaDraw` constructor naming and field names (once the law is chosen).
- Test organization *within* `offchain/test/Main.hs` (grouping, helper extraction).
- Exact wording of the four field-validation messages.
- How the field-boundary corpus for the round-trip test is constructed (SC-2 requires it
  exhibit at least one order whose input word ≠ its storage word).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The V2 wire contract (imported in Phase 20 — read them HERE, not on another branch)
- `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — V2 selectors + E1 v2 event,
  cast/solc-verified; the source every pin is recomputed FROM
- `.planning/rpc-api-volorder-v2-HANDOFF.md` — the four byte layouts, retired constants
- `notes/DATA_CONTRACT.md` — field→scale table, emission-order guarantees
- `notes/UNITS_AND_SCALES.md` §2 — **the vega axis**: dimension decision (ii), ΔQ_v★ =
  raw L at bits 152..247, the u96 bound, and the "realistic pool liquidity 1e18–1e21"
  headroom claim the research target must ground or correct

### targetVega research inputs (draw-law investigation)
- `../plank/notes/VOLATILITY_INSTRUMENTS.md` — the vol-instrument human entry point
- `../plank/refs/DemeterfietalVarianceSwaps.pdf`, `../plank/refs/greeks/`,
  `../plank/refs/bunni-v2.pdf` — local literature
- arxiv MCP (preferred over web search per the user's global instruction)

### Phase framing
- `.planning/ROADMAP.md` — "# Milestone v5.0", Phase 21 detail (5 success criteria)
- `.planning/REQUIREMENTS.md` — "Milestone v5.0 Requirements" (RPIN-01..06, VEGA-01 +
  decisions of record)
- `.planning/phases/20-deploy-rig-source-of-truth-import/20-CONTEXT.md` — the milestone
  rules this phase inherits (consume-don't-re-derive; pins generated not typed)
- `.planning/phases/20-deploy-rig-source-of-truth-import/20-05-SUMMARY.md` — records that
  `cabal run`'s demo order REVERTS because `Encoding.hs` still builds V1; that is exactly
  this phase's fix
- `docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md` — the
  v4.0-era consumer contracts still binding (64-byte N=0 return, canonical bools, offset
  0x40) and the tracked follow-ups

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `offchain/test/Main.hs` (546 lines, 44 checks) — `.plk` signature parser, `keccak256`
  via `Crypto.Ethereum.Utils`, a proven falsifiability case. Phase 21's pin tests extend
  this.
- `offchain/rig/rig-pins.json` — 30 selectors, 5 topics, 4 retired, all generated. The
  cross-check target.
- `offchain/lib/Rig/Manifest.hs` (394 lines) — the loader; addresses come from here, so
  no new literals enter the tree.
- `offchain/lib/VolOrder/Encoding.hs:61` — the existing 3-field `pack_vol_order_input`
  (`sk .|. (target << 16) .|. (width << 104)`) and its `in_range` guard: the exact shape
  the 4-field V2 version extends.
- The live Phase-20 rig (anvil, 7 contracts) — RPIN-05 requires capturing a real
  `(bool,uint256)[]` return from it, including the N=0 case.

### Established Patterns
- Module family: `Types` / `Encoding` / `Decode` / `Report` / `Rpc` per contract surface.
- `Either String` for pure validation; `fail` in `Web3`/`IO` for orchestration failures
  (a documented characteristic: `fail` escapes `runWeb3'` as an `IOException`).
- One-constructor sum types for "one law today, room for another" (`ArrivalProcess`,
  `ProcessType`) — `VegaDraw` follows this.
- Zero `-Wall` warnings is a hard gate on every Haskell change.

### Integration Points
- `VolOrder.Types.VolOrder` gains `target_vega` — ripples to `Encoding` (both encoders),
  `Decode.unpack_vol_order_storage`, `Rpc`'s mined-order content check, `Sample`, and
  `StochasticOrderGen`.
- `Decode.decode_order_created` already takes the topic0 as a parameter (Phase 20's purge
  change) — the V2 re-pin changes its body/arity for 4 data words + indexed orderId, not
  its topic-injection style.

</code_context>

<specifics>
## Specific Ideas

- "This needs to be researched on how empirically and in practice this is chosen" — the
  user's explicit direction on the targetVega draw law. Structure was decidable from the
  codebase; the *law* must come from evidence, not from a plausible-sounding default.
- The phase's animating concern is anti-rot: every pin computed from the signature string,
  the retired values kept only as falsifiability subjects, the dead V1 encoder deleted
  rather than parked.

</specifics>

<deferred>
## Deferred Ideas

- Running the drivers live end-to-end — Phase 22 (DRIV-01/02), already roadmapped.
- The v6.0 subgraph consuming E1 v2 — queued milestone, not new scope.
- The tracked v4.0 follow-ups (decoder header hardening, shared `MAX_BATCH` constant,
  whole-word storage verification) — recorded in
  `docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md`; touch
  only if the re-pin lands on those exact lines anyway.

</deferred>

---

*Phase: 21-v2-abi-re-pin-targetvega-generation*
*Context gathered: 2026-07-31*
