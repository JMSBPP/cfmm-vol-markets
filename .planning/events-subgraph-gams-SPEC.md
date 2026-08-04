# Events layer — chain → subgraph → GAMS database (todo.md:198)

**Status: v2 — two-step review round 1 done (Reality Checker + Solidity Smart Contract
Engineer, both NEEDS WORK); all BLOCKERs/MAJORs resolved below. Architecture unchanged —
both reviewers confirmed the event set, indexing, raw-scale principle and non-duplication
rule are sound against the code as it exists.**

## Goal (verbatim source, todo.md:198)

> Once we prove a panoptic tokenId is created from a volOrder and acquires premia via adaptive
> fee, the next layer is to build the events to be emitted. This needs to be designed in such a
> way that the subgraph built from these events feeds the gams database to run and solve the
> optimization problems on volatility instruments and thus build the gams CFMM.

Plan of record (user, 2026-07-30): design the events → implement them (TDD) → submit a
detailed issue on `develop` telling the GAMS agent what to build on its side (EV-06).

## What the consumer actually needs (evidence, read 2026-07-30)

The GAMS model (`~/cfmms-playground/cfmm-gams/model/`, canonical repo) has **no data
ingestion path today** — zero `$gdxIn`/`$load`/`execute_load` across all `.gms`
(verified); every exogenous symbol is a hardcoded literal or `ord()`-derived. Ingestion
is specified but unbuilt (`cfmm-gams/.planning/REQUIREMENTS.md` `DATA-01..DATA-08`,
quotes verified at :55-62):

- `DATA-01` ingest via `execute_loadDC`; model must compile with no data file present.
- `DATA-02` static capacity grid `tAll` + loaded membership `tObs(tAll)` (timestamps).
- `DATA-03/05/07` windowed `mean_tick` / `realized_variance` computed GAMS-side from a
  **tick series** (RV_log = (log λ)²·RV_tick; `rv_bar` normalization).
- `DATA-06` numeric provenance: a `seriesIdHash` (free-text labels do not survive an
  execution-time load).
- `DATA-08` a documented **data contract** separating expected symbol names + domains from
  the producer: *"Source is deliberately pluggable and follows the Plank schema, which is
  not fixed."* → **this spec fixes the producer half of that contract.**

Exogenous quantities the models/specs name (binding doc symbols — notation from
`notes/VOLATILITY_INSTRUMENTS.md` and `cfmm-gams/model/spec/*.md`; the notation-binding
rule applies — no interpretive renames):

| Doc symbol | GAMS target (existing or scheduled) | On-chain origin |
|---|---|---|
| t (timestamps) | `tObs(tAll)` | E3/E6 emitted timestamps (see D7 for which timestamp) |
| i (tick series) | observed-tick parameter over `tAll` | E3 timepoints (+ pool Swap events) |
| σ²(i(t)) | `realized_variance` (DATA-03) | reconstructible from E3's volatilityCumulative + E6's window; σ directly observable via `getAverageVolatility`/E5 |
| Θ_ℓ = {ξ, ι} | `xiVal`, `iotaVal` | E2 at mint (ξ⋆ = λ^(−Δ_i/2) in Q96, ι) |
| L(i_K), L̄ | `liquidityKernel`, `Lbar`/`LbarQ128` | E2 liquidityBar + tokenId leg decode |
| Θ_p = {η, Δ_i} | `eta_x_y`/`etaQ128`, `tickSpacingVal` | pool config (η = 1/2 on-chain), order width |
| σ²_K | (VOL-porting layer, `FeeSchedule.Params.volStrike` analog) | E1 strike |
| Θ_φ = {γ, φ̄, β, α} | (VOL-porting layer, `FeeSchedule.Params`) | E4 (AlgebraFeeConfiguration verbatim) |
| φ(σ(i(t)); t) | fee series for λ_FLAIR's w_t | E5 per swap |
| λ (basis 1.0001) | `lambda` | constant; contract-level, not event-fed |

**Not consumed by GAMS today**: fees, vega, premia have no GAMS symbol yet; the port is
scheduled (`VOL-01..VOL-09`). The events still carry them: the λ_FLAIR discrete form
needs the per-observation fee/flow series and υ identification is econometric
(VOLATILITY_INSTRUMENTS.md §υ IDENTIFICATION) — an event schema that omits them cannot
be retrofitted onto historical blocks.

## Design decisions

### D1 — Events carry RAW on-chain scales; conversion is the subgraph's job

Fields are emitted in their native representations (int24 tick, uint88 volatility in
Algebra's units, uint128 liquidity, Q96 for ξ⋆, uint24 pips fee). The subgraph mapping
layer converts to GAMS scales (WAD, Q128, dimensionless). On-chain conversion costs gas,
loses precision, and duplicates a pure transformation the consumer does losslessly.

**Signed-field rule (review F-SE1, BLOCKER, resolved):** raw scale ≠ raw storage word.
ABI encoding of a non-indexed `intN` is the full 32-byte sign-extended two's complement,
while the stored Timepoint masks ticks to 24 bits (`Timepoint.plk:56-58`) and the
write-path inputs arrive as raw calldata words. The emit helpers therefore MUST
canonicalize every signed field as `@evm_signextend(2, x & MASK_I24)` (generically:
signextend after mask, for any signed width) before writing it to the log buffer. Test
corpora MUST contain negative-tick and negative-averageTick vectors; "emit masked instead
of sign-extended" is a mandatory mutant in every battery touching a signed field.

### D2 — `seriesIdHash` (DATA-06) and series identity

Series-bearing events (E2–E6) are indexed by `poolId` (bytes32, v4 PoolId). E1 is
market-agnostic at creation and carries NO poolId (review F-RC5): an order row joins a
pool series only via E2's (orderId, poolId) pair; until task #14 ships E2, σ²_K rows are
unjoined — stated in the data contract, not papered over.

`seriesIdHash` must survive a GAMS numeric load (IEEE double, 53-bit mantissa — a uint256
silently loses ~200 bits; review F-SE4, resolved):

```
seriesIdHash = uint48(keccak256(abi.encode(chainId, emitter, poolId)))
```

uint48 < 2^53, computed identically subgraph-side and GAMS-side. Derived off-chain; no
on-chain field.

**Permanent sentinel, not mutable topic (review F-SE3, resolved):** `poolId =
bytes32(0)` is a first-class, PERMANENT series meaning "module-global: applies to every
pool bound to this emitter". The currently deployed module-keyed emitters
(RealizedVolatilityMod, DynamicFeeMod) emit poolId = 0 forever. The pool-keyed hook
(task #16) is a DIFFERENT emitter address and emits real poolIds from its first block —
and since `seriesIdHash` includes `emitter`, the two series are distinct by construction;
no topic ever changes meaning mid-history. The subgraph materializes per-pool config rows
from a module-global series at pool-binding time.

### D3 — Solidity-ABI-compatible layout, hand-packed in Plank

Standard Solidity event ABI: topic0 = keccak256 of the canonical signature; indexed
params as topics; non-indexed abi-encoded in data. All types used (`uint88 uint24 uint16
uint32 int24 int56 bytes32 uint160 uint128 uint256`) are already-canonical — no alias
normalization pitfalls. Plank emits via `@evm_log2` (topic0 + 1 indexed) and `@evm_log3`
(E2 only); log4 is NOT used by this event set — do not promote fields to topics (review
F-SE9). Topic0 constants precomputed with `cast keccak`, restated test-side, and
independently verified by the solc-encoded reference (D8). Buffer discipline: the emit
helper's log buffer must provably not disturb any pre-allocated return buffer (the
project's documented aliasing hazard, `VolOrderManagerMod.plk:183-199`);
`VolOrderManagerReturnEncodingTest` stays in the regression set as the aliasing sentinel
(review F-SE10).

### D4 — The event set (one event per state transition, no synthetic aggregates)

**E1 `VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew)`**
- Emitter: `VolOrderManagerMod` — `create_order` (after `validate_order_strict` + sstore)
  and per-success inside `create_orders` (a skipped tuple emits nothing; successors'
  events, like their return tuples, do not shift).
- Feeds: σ²_K (strike), width, skew. No poolId (D2). Field widths verified against
  `VolOrder.plk:35-40`.

**E2 `PortafolioMinted(uint256 indexed orderId, bytes32 indexed poolId, uint256 tokenId, uint160 xi, uint24 iota, uint128 liquidityBar)`**
- Emitter: the mint/replication module (task #14). SPEC-ONLY here; its tests are written
  in that increment. xi is ξ⋆ in Q96 (verified: `GeometricDistribution.plk` xi_x96).
- Strikes i_K / widths are decoded subgraph-side from `tokenId` — the data contract pins
  the exact TokenId layout to the vendored panoptic-v2-core commit, notes that int24
  strikes inside the 48-bit leg packing need MANUAL sign extension in AssemblyScript, and
  requires the subgraph decoder to validate against golden vectors exported from the
  existing Plank/Solidity TokenId tests (review F-SE8).

**E3 `TimepointWritten(bytes32 indexed poolId, uint32 timestamp, int24 tick, uint88 volatilityCumulative, int24 averageTick, int56 tickCumulative)`**
- Emitter: `RealizedVolatilityMod`. poolId = 0 permanent sentinel (D2; review F-RC1,
  BLOCKER, resolved).
- **Emit site is pinned (review F-RC3, resolved): inside `write_timepoint`, immediately
  after the state sstores** — NOT at the dispatcher. This is load-bearing: the reactive
  `on_price_update` path invokes `write_timepoint` as a function value inside
  `store_price_update_timepoint` (RealizedVolatilityMod.plk:348) and would silently never
  emit under dispatcher-level placement. The same-block early-out (`return_u256(EMPTY)`,
  :133) exits before the emit → a same-block second write emits nothing (no state
  transition), which is the intended semantics. NOTE: the hook spec's B1 resume item
  strips that `return_u256` early-out; when B1 lands, the early-out branch must still
  bypass the emit (guard, not fall-through) — recorded here so B1 cannot silently break
  the no-transition-no-event rule.
- **Also fires on `initializeTWAP`** (review F-RC4/F-SE5, resolved): the seed Timepoint
  written by `initialize_timepoint_buffer` (:106-118) is a genuine buffer write and the
  origin of `tObs`; excluding it would start every series one observation late.
- Fields are the emitted PROJECTION of the stored Timepoint (review F-RC2/F-SE7,
  resolved — the v1 "mirror of the sstore" claim was false): timestamp, tick, avg_tick,
  realizedVolatility.vol, tick_cumulative are emitted; `time_window_start_index` and
  `initialized` are internal ring bookkeeping and deliberately excluded. tickCumulative
  (int56) is included so the DB can cross-check its own tick-series integration. Signed
  fields (tick, averageTick, tickCumulative) follow the D1 signextend rule.
- The state↔log equivalence test is field-SUBSET equality: each emitted field equals the
  canonical (unpacked, sign-extended) value of the corresponding stored field, tolerance 0.

**E4 `FeeConfigurationChanged(bytes32 indexed poolId, uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee)`**
- Emitter: `DynamicFeeMod` — `initialize_dynamic_fee` and `change_fee_configuration`,
  after validate + store; a reverted (invalid/unauthorized) change emits nothing.
- Field names and widths are Algebra's `AlgebraFeeConfiguration` verbatim (verified
  u16/u16/u32/u32/u16/u16/u16); doc-symbol mapping (α_j, β_j, γ_j, φ̄ = baseFee) lives in
  the data contract. poolId = 0 permanent sentinel per D2 — this module NEVER emits a
  real poolId; the future hook is a new emitter with its own signature instance.

**E5 `FeeApplied(bytes32 indexed poolId, uint88 sigma, uint24 fee)`**
- Emitter: `DynamicFeeHook` beforeSwap (task #16). SPEC-ONLY here. sigma is the uint88
  `getAverageVolatility` value used for this swap's fee (verified width).
- **Join rule (review F-SE2, resolved):** the E5↔`Swap` join is NOT "by poolId". The
  well-defined key: same transaction, same poolId, `FeeApplied.logIndex <
  Swap.logIndex`, nearest-preceding adjacency. Guaranteed by v4-core's emit ordering:
  the hook emits inside beforeSwap; PoolManager emits `Swap` after the swap math and
  deliberately before afterSwap ("to ensure events are always emitted in order",
  PoolManager.sol:238), and the manager is locked during the swap. Integrity invariant
  the subgraph MUST assert on every joined pair: `FeeApplied.fee == Swap.fee` (v4's Swap
  already carries the fee actually used incl. hook override — a wrong join is instantly
  detected). Under SFPM multi-swap blocks, several E5 share one E3 (the same-block
  early-out) — carrying sigma in E5 is exactly what keeps the per-swap series complete.
- E5's battery includes the hook-return byte-exactness check (exactly 96 bytes after the
  LOG; review F-SE10).

**E6 `WindowChanged(bytes32 indexed poolId, uint32 window)`** *(added — review F-SE5)*
- Emitter: `RealizedVolatilityMod` — from `write_window` (:31-33) and from the default
  window write inside `initialize_timepoint_buffer` (:117). poolId = 0 sentinel.
- Feeds: the window is a normalization parameter of the σ² series (divides directly into
  `get_average_volatility`, :262; DATA-03/07's rv_bar) — without its history the DB
  cannot reconstruct windowed σ² from volatilityCumulative.

### D5 — What is deliberately NOT emitted

- Swap flows, reserves X/Y, sqrt price: PoolManager's `Swap`/`ModifyLiquidity`/
  `Initialize` all carry `PoolId indexed id` (verified, IPoolManager.sol:59-99) and
  Panoptic's contracts emit their own — the subgraph indexes those directly. Duplication
  is gas waste plus a divergence risk. (`FeeApplied.fee` nominally duplicates `Swap.fee`
  — kept deliberately AS the join-integrity check, D4/E5.)
- Premia: Panoptic SFPM/PanopticPool events are the source (premia ARE pool swap fees,
  verified in the hook spec); this layer contributes the σ and φ series that explain them.
- λ, W, W_j, υ regressions: derived — DB/GAMS-side, never on-chain.

### D6 — Data contract artifact

`notes/DATA_CONTRACT.md` (producer side) mapping every event field → GAMS symbol → scale
conversion, mirroring DATA-08. Must additionally pin (review F-RC5/6, F-SE2/4/8/11):
- which timestamp `tObs` loads (D7),
- the seriesIdHash uint48 derivation (D2),
- the E5↔Swap join key + fee-equality invariant,
- the TokenId layout commit + golden-vector requirement for the subgraph decoder,
- the order→pool association closure (E1 rows join series via E2's orderId+poolId),
- that σ²_K rows are unjoined until E2 ships,
- the rows sourced from PoolManager/Panoptic events (the D5 non-emitted quantities).

### D7 — Which timestamp is `tObs` (review F-RC6, resolved)

E3/E6 emit the CALLER-SUPPLIED `blockTimestamp` argument (harness-drivable by design),
which can diverge from `event.block.timestamp` under direct calls. The subgraph loads the
EMITTED field into `tObs` — it is what the σ² kernel actually consumed — and records
`block.timestamp` alongside as provenance, flagging rows where they diverge.

### D8 — Test oracle: solc-encoded reference, never hand-bytes (review F-SE6, resolved)

Hand-assembled expected bytes can share the implementation's packing bug. Every event
test declares the event in the Solidity test contract with the exact spec signature and
uses `vm.expectEmit(true, true, true, true)` + `emit EventName(typedValues…)` with
properly-typed values (`int24 tick = -100`), so solc's own encoder produces the expected
log — topic0 (independently verifying the `cast keccak` constants), topics, data, and
sign extension all come from the reference compiler. `vm.recordLogs` + raw-byte asserts
may supplement (e.g., counting emissions), never serve as the sole oracle.

## Increment plan (TDD, tolerance-zero discipline)

Implements E1, E3, E4, E6 (modules exist); E2/E5 are forward-specced for tasks #14/#16.

1. **EV-01 topic constants + emit helpers**: `src/lib/events/VolEventsLib.plk` — one
   `emit_*` fn per event, hand-packed buffer, `@evm_log2/3`, the D1 signextend rule
   applied to every signed field. Topic0 via `cast keccak`, verified by D8 tests.
2. **EV-02 E1 in VolOrderManagerMod**: RED — D8-style expectEmit for create_order; batch
   semantics (per-success emit, failed tuple emits nothing, successors unshifted, N=0
   emits nothing); `VolOrderManagerReturnEncodingTest` stays green (aliasing sentinel).
   GREEN — wire emit after sstore.
3. **EV-03 E3+E6 in RealizedVolatilityMod**: RED — expectEmit on initializeTWAP (seed E3
   + default-window E6), write_timepoint golden + fuzz corpus WITH negative ticks
   (reuse the vol diff corpus), state↔log subset-equality (canonical unpacked values,
   tolerance 0), same-block second write emits nothing, `onPriceUpdate` selector ALSO
   emits (kills the dispatcher-placement mutant), write_window emits E6. GREEN — wire
   inside `write_timepoint` after the sstores + the two E6 sites.
4. **EV-04 E4 in DynamicFeeMod**: RED — expectEmit on initialize + change_fee_configuration
   (Algebra widths, typed); reverted config change emits nothing. GREEN — wire.
5. **EV-05 data contract doc**: `notes/DATA_CONTRACT.md` per D6 (incl. E2/E5 forward
   rows).
6. **EV-06 GAMS handoff issue (plan of record)**: file a detailed issue on `develop`
   addressed to the GAMS agent: the consumer half of DATA-08 — expected symbols/domains
   (`tObs(tAll)`, tick series, window, Θ_ℓ, Θ_φ, σ² reconstruction from
   volatilityCumulative + window), the event→symbol→scale table, seriesIdHash (uint48),
   and the DATA-01..07 obligations it implements in cfmm-gams. Link the data contract +
   this spec.
7. **Mutation battery** (each test states its mutant): wrong topic0 / signature-string
   drift; field-order swap; **masked-not-signextended tick (the highest-value mutant)**;
   missing emit on the batch path; missing emit on the on_price_update path; emit before
   validate; emit on same-block write; missing seed emit.

Regression baseline (`forge test --skip '*PriceSetterHook*' --via-ir --optimize`,
recorded 2026-07-30 before EV-01, review F-RC7): **186 passed / 19 failed**. The 19 are
pre-existing and outside this increment's blast radius: ~15 FFI build failures in the
exposure track (VegaAccountMod skeleton = todo #13; PanopticVegaLensHarness.plk missing —
untracked in-progress peer test; VegaIssuanceKernelHarness), plus 4 latent pos_spec fuzz
counterexamples (volWidthRangeSub / spreadTickAssimetrySplitTick /
tickFromSplittedTickBucket / volWidthRangeBuildVolRangeWidth — the already-backlogged
negative-tick/sdiv latent-bug family). Gate for this increment: the touched suites
(VolOrderManager*, RealizedVolatility diff, GetAverageVolatility, premium) stay at their
current 100% pass, and the failure set does not grow beyond the recorded 19; the
byte-exact differential suites (vol, fee) are the no-state-change sentinels.

## Non-goals

- The subgraph implementation itself (manifest/mappings) — separate deliverable; its
  obligations are pinned in DATA_CONTRACT.md.
- The GAMS-side `execute_loadDC` reader — cfmm-gams repo, delegated via EV-06.
- Any change to cfmm-gams model files.
- Gas golf: research-only invariant (E5's ~1.6k gas/swap accepted).
