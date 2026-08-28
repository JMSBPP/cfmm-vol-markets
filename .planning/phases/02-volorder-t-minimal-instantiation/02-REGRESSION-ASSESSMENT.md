# Phase 2 regression assessment — VolOrder → VolOrder(T)

**Status:** FINAL 2026-08-28 — every row evidenced from develop-gate [`33182346548`](https://github.com/JMSBPP/cfmm-vol-markets/actions/runs/33182346548). Approved 2026-08-28 at the plan 02-03 checkpoint; **§4 DESIGN SUPERSEDED 2026-08-28 at the 02-04 re-apply chunk review — see §4a and §7** — FINAL evidence to be filled by 02-05
**Tree assessed:** `703e7449ffd0bd7fcd37f8d9e5426a8864943b35` on `feat/volorder-t-minimal` (plank `00c0a1aa3cb40b63de81c6ca4f92bec392b423c3`, forge `1.5.1` / `b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`). Source diff vs `origin/develop` is the 02-01 std moves only (9 files, +22/−43); no VolOrder-shaped file has changed.
**Frame (ROADMAP Phase 2, verbatim):**
> **Regression assessment comes first.** Before the refactor is written, enumerate every test and dependency coupled to the concrete `VolOrder` shape and classify each one: *survives untouched*, *needs a mechanical call-site update*, or *is tightly coupled to the old format and should be eliminated*. The elimination candidates are a brainstorm-and-decide step with the user, not a judgement call made mid-refactor — and the decisions are recorded with their rationale before any code moves. This assessment is what makes the "no edits" criterion below meaningful rather than aspirational: it establishes *which* files were expected to be untouched in the first place.
>
> 1. A recorded regression assessment enumerates every test and dependency coupled to the old `VolOrder` shape, classifies each into the three buckets above, and carries a user-agreed decision plus rationale for every elimination candidate.
> 3. Every test classified *survives untouched* — including the golden vectors and fuzz cases in `VolOrderToPanopticTokenId.t.sol` — passes in that gate run with **no edits to those files**, making the minimal instantiation's `tokenId` bit-identical to today's `vol_order_to_panoptic_token_id`.
> 4. Every eliminated or rewritten test is traceable to a decision from criterion 1. Nothing is deleted, weakened or `--skip`-ed merely to make the gate green; a coupled test that would have caught a real regression is replaced, not dropped.

## 1. Evidence bar
- **survives untouched** = `git diff origin/develop -- <file>` is EMPTY **and** the file's suite (or the entrypoint that reaches it) ran GREEN in the phase gate run — BOTH. Filled by 02-05 with the run id and the quoted `Suite result` / `OK` line. A masked or never-executed file never counts.
- **mechanical call-site update** = the file's diff consists ONLY of the enumerated edits in §4 (type annotation `VolOrder` → `VolOrder(none)`, struct literal `VolOrder {` → `VolOrder(none) {`, import additions, and the ONE `vol_order_to_panoptic_token_id(none, …)` call-site change) and its suite is green in the gate run.
- **elimination candidate** = a test whose assertions depend on the OLD concrete shape in a way no mechanical update preserves. **PREDICTED EMPTY.** Any entry here is a HARD STOP: the executor halts and brings the maintainer (a) the file, (b) why it is coupled, (c) what would replace it. A non-empty bucket also falsifies §4's design prediction and is reported as such.
- **UNVERIFIED (reason)** = cannot meet the bar because the gate never runs it (the two `--skip` entries) — classified from the 02-02 probe, never from being masked.

## 2. Classification — `.plk` (17 files)
| File | Coupling (what it touches) | Predicted class | Evidence (filled 02-05 from gate `33182346548`) |
|---|---|---|---|
| `src/types/pos_spec/VolOrder.plk` | the definition (`:17`) + 16 type/literal sites (`:27,34,39,44,50,58,65,83,84,93,94,103,104,112,113,122`) | mechanical | **8244 B** (refactor); compiled via `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` |
| `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` | import `:2`; 6 signatures `:21,99,124,141,161,176`; the tokenId path | mechanical (+ the ONE generic signature, `:21`) | **5331 B** (refactor); compiled via `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` |
| `src/lib/pos_spec/VolOrderValidationLib.plk` | `build_vol_order` `:69-70`, `validate_order` `:86`, `validate_order_strict` `:93` | mechanical | **2582 B** (refactor); compiled via `src/modules/pos_spec/VolOrderManagerMod.plk` |
| `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` | ONE call site `:38`; external surface FROZEN (02-02 stamp, 7 selectors) | mechanical (internal only; ABI edge stamp equal) | **1247 B** (refactor); `OK test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` |
| `src/modules/pos_spec/VolOrderManagerMod.plk` | imports `pack_vol_order`, `build_vol_order`, `validate_order*` — types inferred, never named | survives untouched | **0 bytes**; `OK src/modules/pos_spec/VolOrderManagerMod.plk` |
| `test/protocol_integrations/VolOrderMintSizingHarness.plk` | imports `unpack_vol_order` + `PanopticTokenIdSetterLib::*`; calls `vol_order_to_mint` / `induced_leg_liquidities` / `average_density_chunks` (all stay `VolOrder(none)`) | survives untouched | **0 bytes**; `OK test/protocol_integrations/VolOrderMintSizingHarness.plk` |
| `test/types/pos_spec/VolOrderHelper.plk` | `import pos_spec::VolOrder::*`; setters / pack / unpack | survives untouched | **0 bytes**; `OK test/types/pos_spec/VolOrderHelper.plk` |
| `test/types/pos_spec/VolOrderValidationHarness.plk` | wildcard imports; `build_vol_order` / `validate_order` | survives untouched | 1119 B vs `develop`, **0 B vs `5ccefd6`** (02-01 std move only); `OK test/types/pos_spec/VolOrderValidationHarness.plk` |
| `src/lib/events/VolEventsLib.plk` | comment mention only | survives untouched (trivial) | **0 bytes**; compiled via `src/modules/pos_spec/VolOrderManagerMod.plk` |
| `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | comment mention only | survives untouched (trivial) | **0 bytes**; compiled via `src/modules/pos_spec/VolOrderManagerMod.plk` |
| `src/types/pos_spec/VegaTarget.plk` | comment mention only | survives untouched (trivial) | **0 bytes**; compiled via `src/modules/pos_spec/VolOrderManagerMod.plk` |
| `src/lib/exposure/VegaIssuanceLib.plk` | commented-out sketch only | survives untouched (trivial) | **0 bytes**; compiled via `(comment-only; no importer)` |
| `src/types/protocol_integrations/PanopticTokenId.plk` | comment mention only | survives untouched (trivial) | **0 bytes**; compiled via `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` |
| `src/types/pricing/TickUtils.plk` | comment mention only (`vol_order_split_points` is a name, not the type) | survives untouched (trivial) | **0 bytes**; compiled via `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` |
| `src/lib/ldf/LDFLib.plk` | comment mention only | survives untouched (trivial) | **0 bytes**; compiled via `test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk` |
| `test/lib/ldf/GeometricWeightsHarness.plk` | comment mention only | survives untouched (trivial) | **0 bytes**; `OK test/lib/ldf/GeometricWeightsHarness.plk` |
| `src/modules/VolOrderManagerMod.plk` | defines its OWN unrelated `const VolOrder = struct { volTarget, rangeWidth, skew }`; does not import `pos_spec::VolOrder` | OUT OF SCOPE — do not touch | 782 B vs `develop`, **0 B vs `5ccefd6`** (02-01 std move only); `OK src/modules/VolOrderManagerMod.plk` |

## 3. Classification — `.sol` (19 files + 2 masked)
Every `.sol` reaches Plank only through packed `u256` words and a `.plk` harness (the ABI edge); none names a Plank type.

| File | Reaches Plank via | Predicted class | Evidence (filled 02-05 from gate `33182346548`) |
|---|---|---|---|
| `test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` | harness ABI (4 dispatch selectors) | survives untouched — **NO EDITS (criterion 3)** | **0 bytes**; `Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 285.63ms (230.69ms CPU time)` |
| `test/protocol_integrations/VolOrderToPanopticTokenId.diff.t.sol` | same harness + SpecHelper | survives untouched; must still compile AND skip on `SKIP_REASON` | **0 bytes**; `Suite result: ok. 2 passed; 0 failed; 2 skipped; finished in 170.99ms (1.38ms CPU time)` |
| `test/protocol_integrations/SpecHelper.sol` | none (the Phase 1 seam) | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `test/protocol_integrations/VolOrderMintSizing.t.sol` | VolOrderMintSizingHarness.plk | survives untouched | **0 bytes**; `Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 394.06ms (228.62ms CPU time)` |
| `test/protocol_integrations/DynamicFeeHookE2E.t.sol` | DynamicFeeHook.plk (packed words only) | survives untouched | **0 bytes**; `Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 294.99ms (14.55ms CPU time)` |
| `test/events/VolOrderCreatedEvent.t.sol` | VolOrderManagerMod.plk event | survives untouched | **0 bytes**; `Suite result: ok. 6 passed; 0 failed; 0 skipped; finished in 71.86ms (930.68µs CPU time)` |
| `test/pos_spec/VolOrderDecoder.sol` | the packed WORD layout — unchanged by design (the extra never enters the word); NatSpec: "THE single test-side decoder for the packed VolOrder word … decode() is total on all of uint256" | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `test/mocks/VolOrderRefMock.sol` | independent Solidity oracle of the registry SPEC; NatSpec: "IT MUST NEVER MIRROR THE MODULE'S MANUAL ENCODING" | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `test/pos_spec/VolOrderManager.diff.t.sol` | VolOrderManagerMod.plk vs RefMock | survives untouched | **0 bytes**; `Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 5.84s (5.74s CPU time)` |
| `test/pos_spec/VolOrderTargetVega.t.sol` | VolOrderManagerMod.plk (mask-identity fuzz) | survives untouched | **0 bytes**; `Suite result: ok. 10 passed; 0 failed; 0 skipped; finished in 155.50ms (35.29ms CPU time)` |
| `test/pos_spec/VolOrderManagerBatch.t.sol` | VolOrderManagerMod.plk | survives untouched | **0 bytes**; `Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 81.01ms (112.63µs CPU time)` / `Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 150.20ms (74.35ms CPU time)` / `Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 145.96ms (17.94ms CPU time)` / `Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 145.72ms (14.04ms CPU time)` / `Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 105.48ms (421.02µs CPU time)` / `Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 254.40ms (180.51ms CPU time)` / `Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 304.14ms (210.54ms CPU time)` |
| `test/pos_spec/VolOrderManager.t.sol` | VolOrderManagerMod.plk | survives untouched | **0 bytes**; `Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 97.85ms (96.28µs CPU time)` / `Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 303.17µs (104.44µs CPU time)` / `Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 72.09ms (469.02µs CPU time)` / `Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 66.20ms (305.93µs CPU time)` / `Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 311.03ms (263.31ms CPU time)` |
| `test/pos_spec/VolOrderManagerFixture.t.sol` | VolOrderManagerMod.plk + Interface | survives untouched | **0 bytes**; `Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 535.06ms (454.10ms CPU time)` / `Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 20.05ms (19.87ms CPU time)` |
| `test/types/pos_spec/VolOrder.t.sol` | VolOrderHelper.plk | survives untouched | **0 bytes**; `Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 270.66ms (112.61ms CPU time)` |
| `test/types/pos_spec/VolOrderValidation.t.sol` | VolOrderValidationHarness.plk | survives untouched | **0 bytes**; `Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 83.40ms (749.88µs CPU time)` / `Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 202.91ms (86.00ms CPU time)` / `Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 123.03ms (395.58µs CPU time)` |
| `src/modules/VolOrderManager.s.sol` | deploy script (bytecode via deployer) | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `foundry-scripts/VolOrderManager.s.sol` | deploy script | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` | deploy script | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `foundry-scripts/deploy/DeployVolOrderManagerMod.s.sol` | deploy script | survives untouched | **0 bytes**; compiled in the 33182346548 forge job (non-test source) |
| `test/types/pos_spec/VolRangeWidth.t.sol` | masked by `*VolRangeWidth*` (also masks `src/types/pos_spec/VolRangeWidth.plk`, `VolRangeWidthHelper.plk`) | UNVERIFIED — red on seed 4880: 2 failing (`volWidthRangeBuildVolRangeWidth_valid`, `volWidthRangeSub_valid`), see #63 | probe run `33169585831` (02-02-SKIP-PROBE.md) |
| `test/types/pos_spec/SpreadTickAssimetryHelper.t.sol` | masked by `*SpreadTickAssimetryHelper*` (also masks `SpreadTickAssimetryHelper.plk`) | UNVERIFIED — red on seed 4880: 2 failing (`spreadTickAssimetrySplitTick__Valid`, `tickFromSplittedTickBucket__Valid`), see #63 | probe run `33169585831` (02-02-SKIP-PROBE.md) |

Note on the two UNVERIFIED rows: 16/18 and 1/3 of their tests DID pass on the bumped toolchain (02-02-SKIP-PROBE.md). Those named passes may be cited as partial evidence in 02-05, but the FILES stay UNVERIFIED because the gate cannot run them. The refactor does not touch `VolRangeWidth` or `SpreadTickAssimetry` (they remain plain fields of the struct), so their status is independent of Phase 2 either way.

## 4. The refactor design that makes §2-3 true by construction — ⚠️ STALE, SUPERSEDED BY §4a

> Rejected at the 02-04 chunk review (2026-08-28). Implemented as `c9844d1`, green on gate
> `33171200236`, reverted by `3af40fb`. **Read §4a instead.** Kept verbatim: it is what the
> maintainer approved at the 02-03 checkpoint, and the record of why it changed is the point.

**Governing note (maintainer, `TODO.md`, verbatim):** "T must point to a calldata and/or memory region where is guaranteed to find the (poolId, OptionRatio[4]) types." and "In this way the unpack, pack is agnostic and thus is expected to have less regressions."

**Upstream facts read from std at the pin `00c0a1a` (not assumed):** regions are empty structs (`const memory = struct {}; const code = struct {}; const calldata = struct {}; const ctime = struct {};`); `region_ptr_type` ends in `@compile_error("unrecognized region")` and `ctime` in `@compile_error("ctime region has no pointer type")`; `bytes(ctime)` returns `cbytes`; `Option(T)` is `fn (comptime T: type) type` with `Some = fn (value: $T) Option(T)` and `unwrap = fn (opt: $T)` recovering `T`'s shape via `@field_index` / `@field_count` / `@field_type`.

### Decisions (Claude's discretion per CONTEXT.md, exercised here for approval)
1. **Local `none` tag, not upstream `ctime`.** `bytes(ctime)` collapses to `cbytes`, a comptime-only type; carrying it as a runtime struct field is an unverified corner. A local `const none = struct {};` in `VolOrder.plk` is structurally identical to how `std/regions.plk` declares every region, costs nothing, and lets `VolOrder(none)` simply OMIT the `extra` field — so `.extra` on the minimal instantiation is a missing-field COMPILE error with no `@compile_error` plumbing to get wrong. `ctime` is recorded as the upstream synonym; Phase 4 may map `none` ↔ `ctime` if `@type_index` wants it.
2. **Explicit `comptime T: type` threading, not `$T` inference.** VORD-01 says "following the in-repo `Shock(R)` pattern", and `Shock`/`ShockLib` thread `comptime R` explicitly. `$T` on a struct-typed argument infers the WHOLE `VolOrder(none)` type; recovering `T` from it needs the `@field_index`/`@field_type` gymnastics `std/option.plk:unwrap` does — more surface for #307-class shadowing bugs, for no gain on a path with exactly one instantiation this phase.
3. **`extra: bytes(T)`** — the `Shock(R)` shape (a `{ptr, length}` view into region `T`) for `T ∈ {memory, calldata}`; ABSENT for `none`. Phase 3 defines the payload layout inside the view.
4. **`vol_order_base(comptime T: type, vo: VolOrder(T)) VolOrder(none)`** — the ONE region-agnostic projection (identity for `none`), so the generic tokenId body reads the four fields through it and the only `T`-dependent read in the future is `extra`. Mirrors `shock_load_word` being the single region-branching site.
5. **Genericity boundary (locked by CONTEXT.md):** only `vol_order_to_panoptic_token_id` takes `comptime T`. `vol_order_to_mint`, `vol_order_leg_split`, `position_size_for_target_vega`, `induced_leg_liquidities`, `average_density_chunks`, `pack`/`unpack`, the four setters, `tick_bucket_from_vol_order`, `VolOrderValidationLib`, `VolOrderManagerMod`, `VolEventsLib`, `VegaIssuanceLib` are all `VolOrder(none)`.
6. **The concept, named (maintainer asked):** a **phantom type** parameter used as a region index — region polymorphism supplying a compile-time capability/witness. Haskell analogue: the `s` in `ST s` / `runST :: (forall s. ST s a) -> a`, a phantom region tag with no runtime representation whose only job is to stop a reference escaping its region. Distinguished from "parse, don't validate": provenance goes into the type, the data stays where it lies — which is exactly why `pack`/`unpack` stay agnostic.

### Exact edit list plan 02-04 executes (4 files, ONE commit)

**`src/types/pos_spec/VolOrder.plk`**
- After the imports, add:
  ```
  // Region tag for the EMPTY instantiation. Structurally what std/regions.plk does for every
  // region (an empty struct). VolOrder(none) carries no `extra` field at all, so reading
  // `.extra` on it is a missing-field compile error. Upstream synonym: std::regions::ctime.
  const none = struct {};
  ```
- Replace `:17-22` (`const VolOrder = struct { … };`) with the constructor:
  ```
  const VolOrder = fn (comptime T: type) type {
      if T == none {
          return struct {
              rangeWidth: VolRangeWidth,
              volStrike: TickVolatility,
              skew: SpreadTickAssimetry,
              targetVega: VegaTarget
          };
      }
      if T == memory or T == calldata {
          return struct {
              rangeWidth: VolRangeWidth,
              volStrike: TickVolatility,
              skew: SpreadTickAssimetry,
              targetVega: VegaTarget,
              extra: bytes(T)
          };
      }
      @compile_error("VolOrder: T must be none, memory or calldata");
  };
  ```
  (import `std::regions::{memory, calldata, bytes}` at the top.)
- Add the projection:
  ```
  // The ONE region-agnostic projection: the four packed fields, whatever T. Identity for none.
  const vol_order_base = fn (comptime T: type, vo: VolOrder(T)) VolOrder(none) {
      if T == none { return vo; }
      VolOrder(none) { rangeWidth: vo.rangeWidth, volStrike: vo.volStrike, skew: vo.skew, targetVega: vo.targetVega }
  };
  ```
- Every remaining `VolOrder` type annotation and every `VolOrder {` literal (`:27,34,39,44,50,58,65,83,84,93,94,103,104,112,113,122`) → `VolOrder(none)` / `VolOrder(none) {`. The packed layout comment (`:9-16`) is unchanged: the word is 248 bits and `extra` never enters it.

**`src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk`**
- `:2` → `import types::pos_spec::VolOrder::{VolOrder, none, vol_order_base, tick_bucket_from_vol_order};`
- `:21` → `const vol_order_to_panoptic_token_id = fn (comptime T: type, vo: VolOrder(T), pool_id: u256) PanopticTokenId {` with `let base = vol_order_base(T, vo);` as the first statement and `vo.` → `base.` on `:22,23,24` (`base.rangeWidth.tickSpacing`, `base.volStrike`, `tick_bucket_from_vol_order(base)`). Nothing after `:24` reads `vo`.
- `:99,124,141,161,176` → `vo: VolOrder(none)`.
- `:142` → `let base = vol_order_to_panoptic_token_id(none, vo, pool_id);`

**`src/lib/pos_spec/VolOrderValidationLib.plk`**
- `:69` return type `VolOrder` → `VolOrder(none)`; `:70` literal `VolOrder {` → `VolOrder(none) {`; `:86`, `:93` `self: VolOrder` → `self: VolOrder(none)`. (Its import of `pos_spec::VolOrder::*` already brings `none`.)

**`test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk`**
- `:3` → `import types::pos_spec::VolOrder::{unpack_vol_order, tick_bucket_from_vol_order, none};`
- `:38` → `let res = vol_order_to_panoptic_token_id(none, vo, @evm_calldataload(36));`
- Nothing else: the four `SEL_*` constants, the `run{}` dispatch, every `@evm_return` shape are untouched, so the ABI-edge stamp's selector set must come back identical (7 entries) and the hex is expected byte-identical.

Files that must show a 0-byte diff after 02-04 (the "no edits" set): every row in §2 classified survives untouched (and the out-of-scope row), and every row in §3.

## 4a. DESIGN OF RECORD — supersedes §4 decisions 1, 3, 4 (maintainer, 02-04 chunk review, 2026-08-28)

The `c9844d1` refactor was presented for re-apply as four chunks (approve/modify). Chunk A came back
with a design correction, verbatim:

> "There is None(T) already, regardless of the T different than None. The VolOrder extra contains
> tokenId for the panoptic case, This is once oit understand there is a region the data on that
> region has structure, and in this case the strucutre is an "address space" like first flag
> indicating is panoptic and if panoptic it points to a region on such refgion where the poolId and
> 4 option rastios nare in calldata to BUILD the tokenId and put it on the extra field"

Chunks B, C and D: `modify` (they follow from A). **The refactor is NOT re-applied.** Four follow-up
questions settled the shape; answers verbatim: `calldata (Recommended)`, `Pointer into calldata
(Recommended)`, `The updated VolOrder(T) (Recommended)`, `Type + None path now; build path Phase 3
(Recommended)`. On being asked whether `Extra(T)` already exists the maintainer replied *"Is tehre
such Extra(T) ? I am aware there is Option and None ?"* — answered: no, std supplies only
`Option`/`Some`/`None`; `Extra(T)` is ours, defined the way `Shock(R)` is.

1. **No local `none` tag.** Absence is std's `Option` / `None(T)` — a runtime VALUE, not a type.
   `VolOrder(T)` is ONE type per region; the minimal instantiation is `extra = None(Extra(T))`.
   (Upstream `std/option.plk` at the pin: `Option = fn (comptime T: type) type { struct { inner: T,
   is_some: bool } }`, `None = fn (comptime T: type) Option(T)`, `unwrap` reverts on `None`.)
2. **`Extra(T)` is ours**, in `VolOrder.plk`, Shock-shaped:
   `struct { data: bytes(T), flags: u256, token_id: Option(PanopticTokenId) }`.
   The region's data has STRUCTURE — a tagged **address space**: `flags(u8) || [ptr(u256) if
   FLAG_PANOPTIC]`, with `FLAG_PANOPTIC = 0x01` and reserved bits rejected on decode (Shock's rule:
   length derived from flags, mismatch reverts).
3. **Pointer, not copy.** Under `FLAG_PANOPTIC` the data holds an OFFSET into region `T` where the
   operands live; the builder dereferences it. Phase 3.
   **AMENDED 2026-08-28 (maintainer: "keep it"):** the operands are the **four optionRatios ONLY**.
   `pool_id` STAYS an explicit parameter of `vol_order_to_panoptic_token_id` — see decision 7.
4. **The tokenId LANDS in `extra`.**
   `vol_order_to_panoptic_token_id = fn (comptime T: type, vo: VolOrder(T), pool_id: u256) VolOrder(T)`
   returns `vo` with `extra = Some(Extra { …, token_id: Some(tid) })`. `PanopticTokenId` stops being
   the return type; callers read it back out of `extra`.
5. **Every existing caller is `VolOrder(calldata)`** with `extra: None(Extra(calldata))` in Phase 2 —
   `unpack_vol_order`, `build_vol_order`, the four setters, `VolOrderValidationLib`,
   `VolOrderManagerMod`, both harnesses. `pack_vol_order` ignores `extra`: region-agnostic, unchanged.
6. **Scope split.** Phase 2 = the type, `Extra(T)` decode for `flags ∈ {0, FLAG_PANOPTIC}` (structure
   only), the `None` path of the builder (geometry exactly as today, `pool_id` still a parameter),
   and RED→GREEN tests for all of it. Phase 3 = the `FLAG_PANOPTIC` dereference — the four ratios
   read through the pointer. Phase 4 = the wire format of `data` beyond the flag byte.

7. **`pool_id` STAYS AN EXPLICIT PARAMETER (maintainer, 2026-08-28: "keep it").** An earlier draft of
   this section said the parameter "retires" once the descriptor could reach `(poolId, ratios)`.
   That was the executor's inference, not a maintainer decision, and it was written here as settled —
   corrected on being questioned. **Reason to keep it:** the Haskell oracle keeps it explicit —
   `volOrderToTokenId :: VolOrder -> Integer -> (Integer,Integer,Integer,Integer) -> PanopticTokenId`
   — and `spec/` is the authority for this milestone; matching its shape is worth more than removing a
   parameter. Retiring it would also have been the only way to avoid a dual source for one datum,
   which is now moot: poolId is not in the descriptor at all.
   **Consequence, APPLIED (PR #65 / issue #64, merged as `b2868cc`):** the `FLAG_PANOPTIC` payload is
   the **four optionRatios only — 4 × 7 = 28 bits**, not 76. `EXTRA_PANOPTIC_BITS` (`src/types/Extra.plk`)
   and `PANOPTIC_BITS` (`VolOrderType.t.sol`) are now **28**, and the stale "…retire the pool_id
   parameter" comment at `PanopticTokenIdSetterLib.plk` is gone. `extra_decode` now REQUIRES `len == 28`
   and REJECTS 76 — a behaviour change, verified by gate `33186747172`: 76 suites / 287 passed / 0
   failed / 3 skipped, `compile-plank 39 ok`, and all four descriptor tests green against the new value
   (`panopticDescriptorDecodesToItsThreeFields`, `panopticFlagWithTheWrongLengthReverts`,
   `unflaggedDescriptorWithAPayloadLengthReverts`, `descriptorSurvivesEncodeDecode`).

**Consequences for §2-3.** The four rows classified *mechanical* stay mechanical, but their edit is
larger than §4's: every `VolOrder` struct literal gains `extra: None(Extra(calldata))`, and both
`.plk` harnesses read the tokenId back out of `extra`. Their `.sol` consumers still see a frozen ABI
(the 02-02 stamp is the check). Criterion 3 (bit-identity, floor untouched) is unchanged as a claim.
The elimination-bucket prediction stands: **NONE**.

**Order of work** (AGENTS.md, set the same day): the tests in `test/types/pos_spec/VolOrderTypeHarness.plk`,
`test/types/pos_spec/VolOrderType.t.sol` and `fixtures/plank-negative/` are REWRITTEN to this design
and go RED — proving they detect the type's absence — before the implementation is written, and every
code chunk is approved in an `AskUserQuestion` approve/modify block before it is committed.

## 4b. Evidence baseline, and what the two halves mean

**Diff half.** `origin/develop` is `a623b97` — it predates plan 02-01, so a file touched by 02-01's
std moves shows a non-zero diff against it while being untouched by the *refactor*. Two census
files are in that position, and both are reported with **both** numbers above:

| File | vs `origin/develop` | vs `5ccefd6` (post-02-01) | Touched by |
|---|---|---|---|
| `src/modules/VolOrderManagerMod.plk` | 782 B | **0 B** | `8872eca`, `5ccefd6` — `std::core::addr` + `cast_addr`, 02-01 only |
| `test/types/pos_spec/VolOrderValidationHarness.plk` | 1119 B | **0 B** | `8872eca` — `@bool_to_u256`, 02-01 only |

Their §2 prediction ("survives untouched" / "OUT OF SCOPE — do not touch") is therefore **correct
about the refactor**, and the assessment says so rather than reporting a bare non-zero and leaving
a reader to guess. Every other census file is **0 bytes against `origin/develop` itself** — 30 of
the 39 paths measured, the four mechanical rows and the five additions below accounting for the rest.

**Run half.** Quoted from gate `33182346548`: the `Suite result:` line for each `.sol` suite (26
suites, all `ok`), and the `OK <path>` line from the plank job for each `.plk` entrypoint. A `.plk`
library or type has no entrypoint of its own, so its run half names the entrypoint that imports it —
`compile-plank` compiles those transitively, which is the only way they are type-checked at all.

## 4c. Files this phase ADDED (no §2/§3 row predicted them)

The assessment classified *existing* coupling, so additions need their own record:

| File | What it is | Evidence |
|---|---|---|
| `src/types/Extra.plk` | the tagged slice descriptor (§4a) | new; compiled transitively via `test/types/pos_spec/VolOrderTypeHarness.plk` |
| `test/types/pos_spec/VolOrderTypeHarness.plk` | type/descriptor harness, 7 entrypoints | new; `OK test/types/pos_spec/VolOrderTypeHarness.plk` |
| `test/types/pos_spec/VolOrderType.t.sol` | the 14 type tests | new; `Suite result: ok. 14 passed; 0 failed; 0 skipped` |
| `fixtures/plank-negative/VolOrderBadRegion.plk` | negative: non-region `T` | new; built via `vm.tryFfi`, asserted to FAIL |
| `fixtures/plank-negative/VolOrderExtraNeedsUnwrap.plk` | negative: `Option` payload not a field | new; built via `vm.tryFfi`, asserted to FAIL |

`compile-plank` went 38 → **39 ok**; the forge suite 75 → **76 suites**, 273 → **287 passed**. The
deltas are exactly these additions.

## 5. Elimination candidates
NONE PREDICTED. **NONE FOUND (02-04).** The refactor touched exactly the four files §2 classified
mechanical; no test was deleted, weakened or `--skip`-ed to make the gate green, and the executor
never had to invoke the HARD STOP rule. Criterion 4's traceability requirement is satisfied
vacuously — there is nothing to trace. Both files CONTEXT.md flagged as the likeliest candidates (`VolOrderDecoder.sol`, `VolOrderRefMock.sol`) are coupled to the packed WORD layout, which does not change; each row in §3 cites the file's own NatSpec for why.

## 6. Decisions for the checkpoint
1. Approve the classification in §2-3 (or name the row that is wrong).
2. Approve design decisions 1-6 in §4 (or name the one to change).
3. `--skip` retirement: **MOOT** — both probe results are RED (02-02-SKIP-PROBE.md, #63). Both entries stay on the ledger; nothing to re-apply.
4. Confirm the HARD STOP rule: any elimination candidate found during 02-04 halts the plan.

## 7. Decision log (maintainer, verbatim)
- **2026-08-28 — 02-04 re-apply chunk review.** `c9844d1` presented as four chunks. Chunk A: the
  design correction quoted in §4a. Chunks B/C/D: `modify`. The refactor is NOT re-applied; the branch
  holds `3af40fb` (revert of `c9844d1`) plus the RED tests. Design of record is §4a.
- **2026-08-28 — checkpoint 02-03.** Presented: §2-3 tables, §5 (NONE), §4 decisions 1-6 + the exact edit list, the 02-02 probe result (both RED), the four questions. Maintainer's resume signal, verbatim: **`approve`** (selected from approve / amend / halt; no annotation).
- Question 1 (classification §2-3): approved. Question 2 (design 1-6, edit list): approved. Question 3 (`--skip` retirement): **MOOT (red)** — both probe results red, both entries stay on the ledger, #63 owns them. Question 4 (HARD STOP rule): confirmed — any elimination candidate found during 02-04 halts the plan.

## Appendix A — census as measured (2026-08-28, tree `703e744`)
- `.plk` files referencing `VolOrder|vol_order_` in `src/` + `test/`: **17** (CONTEXT.md's "12" was a `src/`-only grep; the plan's own context already enumerated all 17 — the delta is scope, not content).
- Non-comment type/literal sites (`VolOrder([^a-zA-Z_(]|$)`, `//`-lines stripped, `src/modules/VolOrderManagerMod.plk` excluded): **34** — `VolOrder.plk` 17, `PanopticTokenIdSetterLib.plk` 7, `VolOrderValidationLib.plk` 5, and 1 each in `pos_spec/VolOrderManagerMod.plk`, `VolOrderMintSizingHarness.plk`, `VolOrderToPanopticTokenIdHarness.plk`, `VolOrderHelper.plk`, `VolOrderValidationHarness.plk` (those five single hits are `import … VolOrder::…` module-path lines, not type uses).
- `.sol` files referencing `VolOrder|volOrder|vol_order`: **19**, as predicted.
- `.sol` → `.plk` harness map (relevant rows): `VolOrder.t.sol → VolOrderHelper.plk`; `VolOrderValidation.t.sol → VolOrderValidationHarness.plk`; `VolOrderToPanopticTokenId(.diff).t.sol → VolOrderToPanopticTokenIdHarness.plk`; `VolOrderMintSizing.t.sol → VolOrderMintSizingHarness.plk`; `VolOrderManager{,Batch,Fixture}.t.sol`, `VolOrderTargetVega.t.sol → src/modules/pos_spec/VolOrderManagerMod.plk`; `VolRangeWidth.t.sol → VolRangeWidthHelper.plk`; `SpreadTickAssimetryHelper.t.sol → SpreadTickAssimetryHelper.plk`.
- Masked by the two ledger globs (`git ls-files`): `src/types/pos_spec/VolRangeWidth.plk`, `test/types/pos_spec/VolRangeWidth.t.sol`, `test/types/pos_spec/VolRangeWidthHelper.plk`, `test/types/pos_spec/SpreadTickAssimetryHelper.plk`, `test/types/pos_spec/SpreadTickAssimetryHelper.t.sol`.
