# Phase 19: Differential, Mutation Battery & Consumer Fixture - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning
**Source:** The v4.0 roadmap (Phase 19 SC 1–4) + REQUIREMENTS MVER-01..04, plus facts verified by execution during this session. Phases 16/17/18a/18b are complete and verified; this phase is the milestone acceptance bar over surfaces that already exist.

<domain>
## Phase Boundary

The acceptance bar for `VolOrderManagerMod` — nothing new is built, everything is proven:

1. An after-every-write sequence differential over `(create_order | create_orders)` against an INDEPENDENT Solidity reference mock (MVER-01).
2. The consolidated observed-RED mutation battery, re-run fresh against the current tree (MVER-02).
3. A consumer golden fixture produced by an encoder outside this repo, plus a `cast sig` test for every selector string in the interface file (MVER-03).
4. A dedicated `make` target folded into `make test`, with the comment block updated to newly MEASURED counts (MVER-04).

NOT here: any change to the module's behaviour. If this phase needs to modify `src/modules/pos_spec/VolOrderManagerMod.plk` to make a test pass, that is a finding about the module, not a licence to edit it — surface it.

Requirements: **MVER-01, MVER-02, MVER-03, MVER-04**. Roadmap Phase 19 SC 1–4 are the acceptance contract.
</domain>

<decisions>
## Implementation Decisions

### The golden fixture — `cast abi-encode` is the oracle (VERIFIED BY EXECUTION, do not re-derive)
Peer `mv15a18k` is not running and its Haskell bytes are unavailable. Rather than fall back to the
roadmap's `NOT-PEER-VERIFIED` stand-in, use **`cast abi-encode`** — alloy's encoder, a different
implementation from solc's and genuinely OUTSIDE this repo, satisfying MVER-03's independence
requirement for real.

Verified at `cast 1.5.1-stable` (commit `b0a9dd9`) during context gathering:

```
$ cast abi-encode "f((bool,uint256)[])" "[(true,1),(false,0)]"
0x0000..0020  offset
  0000..0002  length
  0000..0001  success[0] = 1   <- canonical
  0000..0001  orderId[0] = 1
  0000..0000  success[1] = 0
  0000..0000  orderId[1] = 0
= 192 bytes = 64 + 64*2

$ cast abi-encode "f((bool,uint256)[])" "[]"
0x0000..0020  offset
  0000..0000  length
= 64 bytes exactly
```

This **independently confirms 18b's pinned layout** (head `0x40`, stride `0x40`, total `64 + 64N`)
and the N=0 64-byte edge, from a third encoder. Record that confirmation in the phase summary — it
is the strongest evidence in the milestone that the encoder is right.

**Both-tracks decision:** commit the cast-generated fixture as the LIVE oracle, AND keep a clearly
marked placeholder entry for peer Haskell bytes so the cross-language gap stays VISIBLE in the
milestone exit record. alloy confirms the bytes are standard-ABI; it does NOT exercise the actual
consumer's decoder. Those are different claims and the exit record must not conflate them.

### The mutation battery — re-run ALL mutants fresh, never cite
Every mutant in MVER-02 is re-applied against the CURRENT tree with a fresh observation:
apply → `rm -rf cache/fuzz` (and `forge clean` where the prior phases did) → observe RED → record
the VERBATIM FAIL line → restore → verify sha256 byte-identical.

Rationale, and it is not ceremony: prior kills were observed against OLDER code. Phase 18b changed
the return type of `create_orders`, which is the surface several of these mutants traverse. A kill
recorded in Phase 17 is a historical fact, not evidence about today's tree. The battery is an
OBSERVATION or it is a bibliography.

The battery covers: deleted validation branch; missing strike upper bound (silent truncation);
count-advance-on-failure; ring-mask reintroduction; each of the THREE calldata guards deleted
independently; return-head `0x40`→`0x20`; non-canonical success word.

Equivalence-masked mutants are DOCUMENTED and explicitly NOT counted as kills. Known ones inherited
from prior phases, each of which must stay excluded rather than quietly re-counted:
- v3.0: h-bound `<`→`<=` and the unset-`p_risk` guard, both masked by `full_math`'s zero-denominator revert.
- Phase 17: the ring-mask mutant is a NO-OP at small ids (`1 & 0xFFFF = 1`); it only bites at 65536,
  so its sole kill site is a `vm.store`-to-65535 test.
- Phase 18a: guard-3's deletion is invisible to state assertions (`calldataload` past the end returns
  zero-padded words → the zero tuple fails validation → skipped → state stays clean). Kill it with a
  REVERT assertion on hand-truncated calldata, never a state check.
- Phase 18b: M7 (pure allocation reordering) is unconstructible at the SCOPING level
  (`error: unresolved identifier 'out'`). Excluded — 18b's count reads 6, not 7.

### Measured counts — measure as-is and NAME the red
`make test` is currently NOT green, and not because of anything this milestone owns: an uncommitted
draft in `src/lib/exposure/VegaIssuanceLib.plk` (`error: unresolved identifier 'VolOrder'` at :44)
breaks the exposure `.plk` compile, failing 14 exposure suites at `setUp()`.

Measured 2026-07-21 after the PriceSetterHook cleanup (`8b11d73`):
```
95 passed, 18 failed, 113 total  (41 suites)
  14 = exposure setUp reverts  <- the uncommitted VegaIssuanceLib.plk draft
   4 = pre-existing vol-type track reds (SpreadTickAssimetryHelper x2, VolRangeWidth x2)
   0 = pos_spec
```
Record the REAL numbers with the cause named in the comment block. Do NOT block milestone closure on
another track's in-progress work, and do NOT scope the counts to `pos_spec` only — that would break
the "single command of record" property `make test` exists to provide. Re-measure at execution time;
the draft may have landed by then, which would change the numbers.

### PLANK_SKIP stays EMPTY (carried forward, do not re-litigate)
MVER-04's 2026-07-20 correction stands: `PLANK_SKIP` is the Makefile's RESCUE QUEUE for entrypoints
that do not yet compile. A module dispatching a subset of its declared selectors compiles fine, so
`VolOrderManagerMod` never belonged there. `PLANK_SKIP` stays empty (as Phase 15 left it) and
`make compile-plank` simply counts one more entrypoint.

**Roadmap SC-4 says "`PLANK_SKIP` exit", which is STALE against its own requirement.** There is no
exit to perform. The real gate is the CALLED batch dispatch through FFI-deployed bytecode — already
true as of 18b, so verify it rather than assume it, and correct the roadmap wording.

### Test discipline (project standard, non-negotiable)
CALLED-green only — "it compiles" is NEVER acceptance, because Plank does not type-check code
unreachable from `run{}`. Constructed corpora, NEVER `vm.assume` (it exhausts the rejection budget
and converts coverage holes into green runs). Non-fuzz anchor beside every fuzz. A `runs: 0` kill is
a cache replay, not proof. Every forge run: `--via-ir --optimize`.

**NOTE — the `--skip` flag is GONE.** As of `8b11d73` the untracked `PriceSetterHook.sol` sketch was
deleted and `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` was removed from all
nine recipes. Do NOT reintroduce it; prior phases' documented commands include it and are now stale.

**NEVER modify `src/types/pos_spec/*`** — the vol-type track owns it and 4 tests are red there,
one tracing to a real bug (`return_split_tick` writes `out_ptr +% 32` twice) that was diagnosed and
reported but must NOT be fixed here.

### Claude's Discretion
- Where the sequence differential lives (extending `VolOrderManagerBatch.t.sol` vs a new
  `VolOrderManager.diff.t.sol` — the e2e precedent used a separate file).
- The reference mock's internal structure, provided it encodes with STANDARD `abi.encode` and never
  mirrors Plank's manual writes.
- Sequence length, corpus shape, and the `VolOrderDecoder` helper's API.
- The fixture file's format and path (a `.json` or hex-per-line `.txt` under `test/fixtures/` are
  both reasonable).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The contract
- `.planning/ROADMAP.md` — Phase 19 section (SC 1–4) + the v4.0 milestone Overview's decisions of record.
- `.planning/REQUIREMENTS.md` — MVER-01/02/03/04 (note MVER-04's 2026-07-20 `PLANK_SKIP` correction).

### The surfaces under test (read; do NOT modify)
- `src/modules/pos_spec/VolOrderManagerMod.plk` — dispatch, `create_order`, `create_orders`, readers, the 18b return encoder.
- `src/interfaces/pos_spec/VolOrderManagerInterface.plk` — every selector string needing a `cast sig` test.
- `src/lib/pos_spec/VolOrderValidationLib.plk` — `validate_order`, `validate_order_strict`, `build_vol_order`.
- `src/types/pos_spec/VolOrder.plk` — `pack_vol_order`/`unpack_vol_order`, layout `width@128 | tickSpacing@104 | strike@16 | skew@0` (152 bits). NEVER modify.

### Precedents to mirror (the shape is already proven here)
- `test/exposure/VegaAccount.e2e.t.sol` — **THE after-every-write sequence driver** (VVER-01):
  `test__unit__fixedAnchorSequenceDiffers` + `test__fuzz__randomSequenceDiffers`. MVER-01 is this
  pattern applied to the order registry.
- `test/mocks/IssuanceRefMock.sol` — the independent reference-mock precedent.
- `test/pos_spec/VolOrderManagerBatch.t.sol` — 18b's byte-level differential; `expectedReturn` is
  literally `return abi.encode(rs);` (lines 138-140), the model for keeping solc an INDEPENDENT
  oracle. Also the `callBatch` low-level helper and hand-rolled calldata builders.
- `test/pos_spec/VolOrderManager.t.sol` — `VolOrderManagerBase`, slot preimages, `orderSlot()`, `expectedPacked()`.
- `test/PlankTestBase.sol` — `deployPlank` and the module roots; never hand-roll `Dependency[]`.

### Prior phase context (the decisions this phase inherits)
- `.planning/phases/18b-typed-return-encoding/18b-CONTEXT.md` — the pinned return byte layout and the N=0 reasoning.
- `.planning/phases/18a-batch-input-state-effects/18a-CONTEXT.md` — the calldata layout verified by execution, the three guards, guard-3's state-invisibility.
- `.planning/phases/17-interface-single-call-module/17-CONTEXT.md` — slot derivation, the 0-sentinel soundness argument.
- `.planning/phases/16-type-packing-validation-foundation/16-CONTEXT.md` — the composed predicates and the authored strike bound.
- `.planning/phases/18b-typed-return-encoding/18b-01-SUMMARY.md` + `18b-VERIFICATION.md` — the recorded mutant FAIL lines and the baseline sha256 `be196dcb0a524ea548480cdbd55f0f70d458fe3cbead078d9fed27d1cc9b8787`.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets
- `VegaAccount.e2e.t.sol`'s sequence driver — fixed anchor + fuzz over a constructed sequence, asserting after EVERY write. Directly transferable to MVER-01.
- `IssuanceRefMock.sol` — shows how an independent mock is structured and deployed alongside the FFI module.
- `VolOrderManagerBase` (`VolOrderManager.t.sol`) — `orderSlot()` / `expectedPacked()` already compute the raw `vm.load` addresses MVER-01 needs.
- `expectedReturn` (`VolOrderManagerBatch.t.sol:138`) — one line, `abi.encode(rs)`. Reuse rather than reinvent.

### Established patterns
- FFI deploy via `deployPlank` is the ONLY way a `.plk` surface is reachable from a test — there is no "pure lib test without FFI" path.
- Mutation gates are proven by OBSERVATION with verbatim FAIL lines + sha256 restoration, never by description.
- Slot preimage strings are restated test-side so `vm.load` addresses are computable in Solidity; a mismatch shows up loudly as a read of 0.

### Integration points
- `Makefile` — a new dedicated target beside `test-vol-order-return` (18b's), then folded into `make test`. The `--skip` flag is gone as of `8b11d73`; do not reintroduce.
- `make compile-plank` must report 0 failed for the pos_spec surfaces; the current 2 failures are the exposure draft, not this milestone.
</code_context>

<specifics>
## Specific Ideas

- The mixed batch (valid, INVALID, valid) has been the single most informative corpus point in every
  phase since 18a — it exercises positional alignment, `(false, 0)` for the middle failure, id
  contiguity, and the count-advance mutant simultaneously. Use it in the sequence differential too.
- Interleave `create_order` and `create_orders` in the SAME sequence. That is the one thing 18a/18b
  could not test in isolation, and it is where an id-allocation disagreement between the two paths
  would surface.
- The `cast sig` test should assert against the exact signature strings in the interface file's
  header comments, so a comment/constant drift fails loudly. Both selectors are already pinned:
  `create_order(uint88,uint24,uint16)` = `0x6501fe94`, `create_orders(uint256,uint256[])` = `0x81357911`.
- Watch for the self-contradicting acceptance criterion pattern — four consecutive phases (16, 17,
  18a, 18b) shipped a `grep == 0` gate whose forbidden string appeared in content the same plan
  mandated. If it recurs, verify the PROPERTY the criterion exists to establish and record the
  resolution; never contort code to satisfy a literal grep.
</specifics>

<deferred>
## Deferred Ideas

- Peer `mv15a18k`'s Haskell-produced golden bytes — the placeholder entry stays in the fixture and
  the gap stays in the milestone exit record until that track delivers. Not blocking.
- Fixing `src/lib/exposure/VegaIssuanceLib.plk` (the user's in-progress `calculate_vega_nominal`
  draft) — not this phase's file, not this milestone's scope.
- Fixing `return_split_tick`'s double `+% 32` in the vol-type track — diagnosed and reported, owned
  elsewhere.
- Syncing `feat/plank` with `develop` (72 commits, incl. the real PriceSetterHook + its test) — its
  own piece of work.
- On-chain pricing, auth, events, cancellation — out of milestone.

</deferred>

---

*Phase: 19-differential-mutation-battery-consumer-fixture*
*Context gathered: 2026-07-21 — `cast abi-encode` independence verified by execution; the stale `PLANK_SKIP` and `--skip` references corrected against source*
