# Phase 2: VolOrder(T) Minimal Instantiation - Context

**Gathered:** 2026-08-28
**Status:** Ready for planning

<domain>
## Phase Boundary

`VolOrder` becomes a comptime type constructor `VolOrder(T)` carrying an `extra: T` payload, and the
minimal instantiation reproduces today's `tokenId` bit-for-bit. The blast radius is *measured and
decided before code moves*, not discovered mid-refactor.

Requirements: VORD-01, VORD-02, VORD-03. The rich instantiation is Phase 3; the wire format is
Phase 4 and stays open by design.

</domain>

<execution_gate>
## EXECUTION GATE — read before starting any plan in this phase

**This phase is executed by the superpowers INLINE executor, in the maintainer's own session.**

`gsd-executor`, `Agent`-spawned subagents, workflows, and any other background or autonomous agent
are **BARRED** from executing Phase 2 plans. The maintainer's stated reason: this phase is heavy on
user intervention across test writing, implementation *and* design, so the decisions belong in a
session the maintainer is present in.

Every PLAN.md written for this phase MUST carry this gate at the top of the document, in terms a
background agent reads before it starts work — the gate lives in the docs, not only here.

An agent that finds itself executing a Phase 2 plan without the maintainer in the loop must stop and
say so rather than proceed.

</execution_gate>

<decisions>
## Implementation Decisions

### What `T` is

- **`T` is a REGION tag, not a payload struct.** From the maintainer's own note (`TODO.md`): *"T must
  point to a calldata and/or memory region where is guaranteed to find the (poolId, OptionRatio[4])
  types."*
- This makes `Shock(R)` a near-literal template rather than a loose analogy: `bytes(R)`,
  `region_ptr_type(R)`, and one region-branching loader.
- **`pack_vol_order` / `unpack_vol_order` stay region-agnostic.** The extra never enters the packed
  word. This is settled by the maintainer's rationale — *"In this way the unpack, pack is agnostic
  and thus is expected to have less regressions"* — and was NOT re-asked. Consequence: the 248-of-256
  packed-bit pressure is a non-issue in Phase 2 **and** in Phase 3.
- Concept being applied: a phantom type parameter used as a region index — region polymorphism
  providing a compile-time capability/witness, so a `VolOrder` that cannot reach its operands cannot
  be passed to the tokenId builder. Haskell analogue: the `s` in `ST s` / `runST`.

### The minimal instantiation

- **⚠️ STALE (superseded 2026-08-28 at the 02-04 chunk review — see `02-REGRESSION-ASSESSMENT.md` §4a).**
  Absence is now the std VALUE `Option`/`None`, not a tag type, and the payload is a tagged
  descriptor `Extra(T)` in `src/types/Extra.plk`. Original text:
  **A dedicated empty tag, decided as "a third tag `none`".** Upstream `main` already ships this
  concept as **`ctime`** (`std/regions.plk`): a fourth region whose `region_ptr_type` is
  `@compile_error("ctime region has no pointer type")` and whose `bytes(ctime)` collapses to
  `cbytes`. Planning decides whether to adopt `ctime` directly or declare a local `none`; the
  SEMANTICS are fixed either way — reaching for `extra` on the minimal instantiation must be a
  **compile error**, not a runtime check.
- Rationale for that shape: "today's callers never touch `extra`" stops being a claim the fuzzer must
  support and becomes something the compiler refuses to build otherwise — which is what makes
  criterion 3 provable rather than aspirational.

### Genericity scope

- **`comptime T` propagates ONLY where `extra` is read** — the tokenId-building path.
- Everything that never touches `extra` keeps a concrete minimal-instantiation signature:
  `pack_vol_order`, `unpack_vol_order`, `VolOrderValidationLib`, `VolEventsLib`,
  `VolOrderManagerMod`, `VegaIssuanceLib`.
- The split falls exactly along the pack/unpack-agnostic line above. Phase 3 re-genericizes whichever
  of these turn out to need rich orders — accepted cost.
- Note for planning: `$T` **implicit generics exist** in Plank (`fn (data: $T)`, inferred from the
  argument, flowing into the return type — used throughout `std/abi.plk`, `std/option.plk`,
  `std/mem.plk`). Explicit `fn (comptime R: type, …)` threading as `Shock` does is NOT the only
  available shape. Planning picks between them; this was verified from upstream source, not assumed.

### Toolchain bump (plan 02-01)

- **`lib/plank-monorepo` bumps `30f3bdc` → `00c0a1a`** (main HEAD, 2026-08-17), pinned by exact SHA,
  with `.gitmodules` `branch` repointed from `feat/arrays` to `main`.
- **`feat/arrays` NO LONGER EXISTS on the remote (HTTP 404).** The submodule currently tracks a
  deleted branch, so a `--remote` update would fail and nothing would report it.
- **The bump is plan 02-01, inside this phase** — not a separate inserted phase.
- **MANDATORY ATTRIBUTION SAFEGUARD:** plan 02-01 must end with a GREEN `develop-gate` run on the
  bumped toolchain with the **existing suite unchanged**, before any refactor plan begins. Without
  that separating run, a VORD-02 bit-identity failure has two candidate causes (compiler vs refactor)
  and the criterion cannot attribute it. This is the condition the "inside Phase 2" choice rests on.

### The --skip census hole

- `test/types/pos_spec/VolRangeWidth.t.sol` and `test/types/pos_spec/SpreadTickAssimetryHelper.t.sol`
  cover two of `VolOrder`'s four field types and are masked by the gate's two surviving `--skip`
  patterns, so criterion 3 cannot observe them either way.
- **Probe once, do not commit.** One throwaway push with both patterns removed, purely to learn their
  real status. The result is recorded in the assessment as measured fact. The unskip is committed
  ONLY if they come back green.
- Precedent this follows: Phase 1.1 retired `*PriceSetterHook*` and found the masked files were clean.
- **A new, accurately-scoped issue on `develop`** is opened from whatever the probe measures — not a
  reopen of #16, whose other items are genuinely done.

### Regression assessment: classification and evidence

- **Evidence bar for "survives untouched": empty `git diff` on the file AND the file actually ran
  green in the phase's `develop-gate` run.** Both, not either.
- Anything that cannot meet both — the two `--skip`'d files — is classified separately as
  **UNVERIFIED, with the reason stated**. A masked or never-executed test must never be counted as
  evidence of survival.
- **The elimination bucket is PREDICTED EMPTY** under these decisions. `test/pos_spec/VolOrderDecoder.sol`
  and `test/mocks/VolOrderRefMock.sol` are coupled to the packed *word layout*, which does not change;
  `VolOrderRefMock` is by charter an independent Solidity oracle that must never mirror the module's
  encoding.
- **Any elimination candidate is a HARD STOP.** The executor halts and brings the maintainer the file,
  why it is coupled, and what would replace it. A non-empty bucket also falsifies the design
  prediction above, which is itself worth surfacing immediately.

### ABI edge

- **`VolOrderToPanopticTokenIdHarness.plk`'s external surface is FROZEN for Phase 2**, checked
  mechanically: the compiled ABI must be byte-identical before and after.
- That converts criterion 3's "no edits to the .sol files" from a hoped-for outcome into a proved one,
  and is the cheapest available evidence of bit-identity at the boundary.

### Claude's Discretion

- ⚠️ STALE — resolved differently: neither. Absence is std `Option`/`None`. Original text:
  Whether to adopt upstream `ctime` or declare a local `none` tag (semantics are fixed; the choice is
  planning's).
- Whether the tokenId path uses `$T` implicit generics or explicit `comptime T` threading.
- ⚠️ STALE — resolved as neither: `extra: Option(Extra(T))`, where `Extra(T)` is a tagged
  descriptor (`flags | offset | len`). Original text:
  The concrete shape of `extra` on the type (`bytes(T)` view vs bare `region_ptr_type(T)`).
- Where the regression assessment document lives and what it is called.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The design intent for `T`
- `TODO.md` §"TokenId == VolOrder" (~lines 48-75) — the maintainer's own statement that `T` is a
  region pointing at where `(poolId, OptionRatio[4])` are found, and that pack/unpack stay agnostic
  *because* that is what keeps regressions low. **This is the governing design note for the phase.**

### The in-repo pattern to follow
- `src/models/mev_tax_model_one/libraries/Shock.plk` — the only comptime type constructor in this
  repo's `src/`. Region-generic view over packed bytes: `Shock(R)`, `shock_load_word` as the single
  region-branching site, `region_ptr_type(R)`, `bytes(R)`.
- `src/models/mev_tax_model_one/libraries/ShockLib.plk` — how consumers thread the region:
  `fn (comptime R: type, pool: u256, s: Shock(R))`.

### The type under refactor and its consumers
- `src/types/pos_spec/VolOrder.plk` — the struct, `pack_vol_order` / `unpack_vol_order`, the V2
  248-bit layout comment, and the setters.
- `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` — hosts all three named callers:
  `vol_order_leg_split` (:99), `position_size_for_target_vega` (:124), `vol_order_to_mint` (:141).
- `test/pos_spec/VolOrderDecoder.sol` — the single test-side decoder for the packed word; NatSpec
  explains why it is deliberately unguarded and total.
- `test/mocks/VolOrderRefMock.sol` — the independent Solidity reference registry; its charter forbids
  mirroring the module's encoding.

### Upstream toolchain (verified 2026-08-28 against github.com/plankevm/plank-monorepo)
- `std/regions.plk` @ `main` — regions are empty structs (`memory`, `code`, `calldata`, `ctime`);
  `region_ptr_type` `@compile_error`s on anything unrecognized; `bytes(ctime)` → `cbytes`.
- `std/option.plk` @ `30f3bdc` — `Option(T)` / `const Some = fn (value: $T) Option(T)`: the payload
  type-constructor precedent, and `$T` implicit generic inference.
- `std/abi.plk`, `std/mem.plk`, `std/membytes.plk`, `std/utils.plk` — further `$T` usage;
  `utils.plk` has `fold(comptime n, comptime f: function, …)` for comptime loops.
- Upstream commits relevant to this phase: `#267` (adds `ctime`, removes `memptr`), `#238`
  (`@type_index` — a VORD-06 candidate), `#240` (`@typename`/`@fieldname`/`@fieldindex`), `#307`
  (fixes a frontend panic when a generic function shadows an imported type), `#292` (methods).

### Phase and project doctrine
- `.planning/ROADMAP.md` §"Phase 2" — the five success criteria; the regression assessment comes first.
- `.planning/STATE.md` §Blockers/Concerns — the standing rules: CI is the only build environment,
  never trust `update-plan-progress`, never rename the `gate` job, re-measure branch protection
  before every merge.
- `notes/DIFFERENTIAL_LAYOUT.md` — the Phase 1 transport boundary that Phase 2 must leave intact.
- `notes/TOOLCHAIN_PINS.md` — establishes that a toolchain bump is a reviewed event carrying
  re-measurement, which is the model plan 02-01 follows for the plank pin.
- `.planning/phases/FEATURES/README.md` — the numbered-dir + symlink convention used by this phase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Blast radius (measured 2026-08-28)

12 `.plk` files reference `VolOrder`/`vol_order_`:

| File | refs |
|---|---|
| `src/types/pos_spec/VolOrder.plk` | 20 |
| `src/modules/pos_spec/VolOrderManagerMod.plk` | 19 |
| `src/lib/protocol_integrations/PanopticTokenIdSetterLib.plk` | 17 |
| `src/lib/pos_spec/VolOrderValidationLib.plk` | 10 |
| `src/lib/events/VolEventsLib.plk` | 5 |
| `src/interfaces/pos_spec/VolOrderManagerInterface.plk` | 5 |
| `src/types/pos_spec/VegaTarget.plk` | 3 |
| `src/lib/exposure/VegaIssuanceLib.plk` | 3 |
| `src/types/protocol_integrations/PanopticTokenId.plk` | 2 |
| `src/types/pricing/TickUtils.plk` | 2 |
| `src/modules/VolOrderManagerMod.plk` | 2 |
| `src/lib/ldf/LDFLib.plk` | 1 |

19 `.sol` files consume it, including the regression floor
`test/protocol_integrations/VolOrderToPanopticTokenId.t.sol` (no edits permitted) and the Phase 1
differential `VolOrderToPanopticTokenId.diff.t.sol` (must still compile and still skip).

### Reusable assets

- `Shock(R)` / `ShockLib` — the region-generic template, in-repo and compiling today.
- `std/regions.plk` — `is_region`, `region_ptr_type`, `bytes(region)`, `slice_bytes`, `keccak256`
  over any region. Regions are plain empty structs, so a new tag costs nothing structurally.
- `std/option.plk` `Option(T)` — payload type-constructor precedent with `$T` inference.

### Established patterns

- One region-branching site per type (`shock_load_word`), everything else region-agnostic.
- Validation lives in a separate lib; masks in `pack_*` are mechanical truncation AFTER validation,
  and the mask-identity property is pinned by fuzz in `VolOrderTargetVega.t.sol`.
- Solidity tests reach Plank through packed `u256` words and a `.plk` harness — so the ABI edge is
  the only coupling surface that matters to the 19 `.sol` files.

### Integration points

- `VolOrderToPanopticTokenIdHarness.plk` — the frozen ABI edge.
- `test/protocol_integrations/SpecHelper.sol` — the Phase 1 spec seam; Phase 2 must not disturb it.

### Toolchain migration cost (measured)

- `memptr` removed upstream by `#267`: **0** occurrences in `src/` and `test/` — no cost.
- `std::addr` → `std::core::addr`: 3 import lines.
- `std::core_ops::bool_to_u256` → builtin `@bool_to_u256` (no longer a std function): 5 imports +
  7 call sites.

</code_context>

<specifics>
## Specific Ideas

- The maintainer asked for the type-driven-development concept behind this to be named explicitly:
  a **phantom type parameter used as a region index** — region polymorphism supplying a compile-time
  capability/witness, in service of making illegal states unrepresentable. The Haskell analogue is
  `ST s` / `runST :: (forall s. ST s a) -> a`, where `s` is a phantom region tag with no runtime
  representation that prevents a reference escaping its region. Worth keeping in the phase's own
  documentation, since the spec side is Haskell and the analogy is exact.
- Distinguish from "parse, don't validate": that pulls data *into* the type. This pushes *provenance*
  into the type and leaves the data where it lies — which is why `pack`/`unpack` stay agnostic.

</specifics>

<deferred>
## Deferred Ideas

- **`@type_index` / `@typename` as the `T`-tag mechanism for VORD-06** — Phase 4 (wire format).
  Available only after the toolchain bump; noted so Phase 4 does not re-derive it.
- **Retiring the `*VolRangeWidth*` / `*SpreadTickAssimetryHelper*` skip patterns for good** — the
  probe measures, a new issue tracks; the actual fix (a seed-dependent width-type fuzz bug) is not
  Phase 2 scope.
- **`✨ methods (#292)`** — upstream method syntax arrives with the bump. Not used in Phase 2;
  a possible ergonomics pass later.
- **Whether `develop` should require reviews at all** — open decision from Phase 1, unrelated to this
  phase but still unowned.

</deferred>

---

*Phase: 02-volorder-t-minimal-instantiation*
*Context gathered: 2026-08-28*
