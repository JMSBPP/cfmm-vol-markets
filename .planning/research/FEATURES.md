# Feature Research

**Domain:** Best-effort batched vol-order registry (on-chain Plank module) for an off-chain Poisson order generator
**Researched:** 2026-07-19
**Confidence:** HIGH (validation bounds cited from the actual kept types + Lean; multicall shape verified against Multicall3 source)

## Scope Framing

This module (`VolOrderManagerMod.plk`) is **not** a generic call router. It is a *single-function self-batcher*: one fixed internal operation (`create_order`) that validates a `(strike, width, skew)` tuple, constructs the kept `VolOrder` type, assigns a sequential id, and stores it. The batch entrypoint runs N of that same internal function. Every design decision below is filtered through that constraint — we borrow Multicall3's *result semantics* but reject its *arbitrary-target* surface.

The consumer is the rpc_api Haskell track's `StochasticOrderGen` (Poisson-arrival order flow, selector `0x6501fe94` cast-sig-verified both sides). That client decodes ABI return data. The result-shape recommendation is chosen for what a Haskell ABI decoder consumes most naturally, not for on-chain gas minimalism.

**Authoritative validation source** — the kept pos_spec types already define `*_is_complete` predicates. The registry MUST reuse them (do not invent bounds):

| Field | Type | `is_complete` predicate (from source) | Valid range | Source file |
|-------|------|----------------------------------------|-------------|-------------|
| `volStrike.vol` | u88 (strike) | `vol > 0` | `[1, 2^88−1]` | `TickVolatility.plk:7` |
| `rangeWidth.width` | u24 | `width > 0 & width <= 0xffffff` | `[1, 16_777_215]` | `VolRangeWidth.plk:20` |
| `rangeWidth.tickSpacing` | u24 | `tickSpacing > 0 & tickSpacing <= 0xc8` | `[1, 200]` | `VolRangeWidth.plk:21` |
| `skew.spread` | u16 | `spread > 0 & spread < 0xffff` | `[1, 65_534]` (open both ends) | `SpreadTickAssimetry.plk:11` |

`vol_order_is_complete` (`VolOrder.plk:28`) is the conjunction of all three sub-predicates. This is the registry's single validation authority.

**Lean cross-check** (`vol_markets/PosSpec.lean`): skew `s_v ∈ [0,1]` is the *closed* real interval, but the u16 encoding deliberately **excludes both endpoints** (`spread ∈ (0, 0xffff)`). This is correct and intentional: `s_v = 1` (`skewTick_one`) collapses the interpolated tick to `i_l`, `s_v = 0` (`skewTick_zero`) collapses to `i_u` — degenerate one-sided ranges. The open interval keeps the convex combination strictly interior. Requirements MUST assert `skew == 0` and `skew == 0xffff` both revert, not just `skew == 0`.

**Design nuance flagged for requirements** — the confirmed `create_order(uint88,uint24,uint16)` signature carries `(strike, width, skew)` but **not** `tickSpacing`. Yet `vol_range_width_is_complete` validates `tickSpacing`. The registry therefore must supply a default/constant `tickSpacing` (the test corpus uses `20`, `VolOrder.t.sol:102`) and validate the constructed `VolRangeWidth` against `<= 200`. Requirements must pin this default explicitly — an un-pinned tickSpacing is a silent correctness gap.

## Feature Landscape

### Table Stakes (Consumer Expects These)

Missing any of these makes the on-chain surface unusable to `StochasticOrderGen` or breaks the module-not-a-black-box rule.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `create_order(uint88,uint24,uint16)` single-call selector `0x6501fe94` | Cast-sig-verified contract with peer; the batch composes this exact internal fn | MEDIUM | Keep as its own selector even after batch ships — single-order arrival is the common Poisson case (λ small ⇒ N=1); the batch is just N-fold reuse |
| Bounds validation via `vol_order_is_complete` | A registry that stores garbage tuples is worse than none; the four predicates already exist | LOW | Reuse existing predicates verbatim; revert on zero-width, `strike==0`, `skew∈{0,0xffff}`, `width>2^24−1`, `tickSpacing>200` |
| Sequential order id, u256, from `1` | Client must reference stored orders; `0` reserved as null/sentinel | LOW | `orderCount` accumulator doubles as id source; increment-then-assign so first id = 1 |
| Persistent storage at keccak-derived slot | Registry is worthless if orders don't survive the tx | LOW | Same slot-discipline v3.0 used for the vault; one slot per order (packs into 152 bits, fits one word) |
| Best-effort batch entrypoint | The milestone's reason to exist; batches N Poisson arrivals in one tx | HIGH | Dynamic calldata array in + dynamic results array out — genuinely new Plank ground (every prior selector took fixed words); the milestone's main technical risk |
| Per-call `(success, orderId)` result, positionally aligned to input | Client must know *which* submitted orders landed and their ids | MEDIUM | See result-shape decision below — this is the load-bearing ABI choice |
| Reader: `orderCount()` | Latest id / batch progress; observability | LOW | Also the id source of truth |
| Reader: `getOrder(uint256 id)` returning packed `VolOrder` | Read back any stored tuple; module-not-a-black-box | LOW | Return the 152-bit packed word; client unpacks with the known layout (`width<<128 \| tickSpacing<<104 \| vol<<16 \| skew`) |
| Interface file with cast-sig-verified signature strings | v3.0 discipline; both tracks must agree byte-for-byte on selectors | LOW | Mirror `VolOrderHelper.plk`'s comment-documented selector style |

### Differentiators (Beyond a Naive Registry)

Aligned with the Core Value (two tracks agreeing on one authoritative kernel) and the best-effort contract.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| No-partial-state guarantee on failed calls | A rejected order leaves *zero* trace — no consumed id, no half-written slot; the batch stays clean under adversarial input | MEDIUM | Validate-before-any-write per call; only increment `orderCount` and store on success. Failure = pure skip |
| Reusing machine-checked `is_complete` predicates as the validation oracle | Validation bounds are Lean-grounded, not aspirational; same differential discipline as v3.0/oracle | LOW | The predicates already carry the `(0,1)` open-skew intent from `PosSpec.lean` |
| Batch == exact N-fold single-call composition | One internal `create_order` fn; single-call and batch share identical validation/id/store logic ⇒ one thing to prove, tested by a `single ≡ batch-of-1` differential | MEDIUM | Prevents the classic bug where batch path diverges from single path |
| Solidity reference-mock differential for the batch | Reproduces v3.0's "constructed corpus + reference mock" gate for the new dynamic-array path | MEDIUM | The mock enumerates valid/invalid tuples and asserts the `(success,id)[]` shape matches |

### Anti-Features (Explicitly NOT Built)

| Feature | Why Requested | Why Problematic | Alternative / Decision |
|---------|---------------|-----------------|------------------------|
| **Generic call router** (arbitrary `target`+`callData` multicall à la Multicall3 `aggregate3`) | "Multicall3 already does batching, just copy it" | Arbitrary-target dispatch is a large security surface (delegatecall confusion, re-entrancy into other modules, msg.value routing) this design has zero need for — we batch *one known function* | Self-batch the fixed internal `create_order`; the input array is `(strike,width,skew)` tuples, never `(address,bytes)`. Borrow only the *result semantics* |
| **Events** (`OrderCreated(...)`) | "Indexers/clients want logs" | The consumer decodes the ABI *return value* of the batch synchronously; it is not a log-subscribing indexer. Events add gas + surface with no consumer this milestone | Return `(success,id)[]` inline; add events only if a future indexer track requests them |
| **Per-owner order books / `msg.sender` auth** | "Orders should belong to someone" | No auth primitive exists in v1 — orders are anonymous by design, exactly as `setRiskPrice` is unauthenticated in v3.0. Adding owner-keying invents an access-control model the milestone explicitly excludes | Flat global id space; anonymous orders. Ownership is a later-milestone concern if ever |
| **On-chain pricing / tick computation** (`tick_bucket_from_vol_order`, `split_tick`) | "The order should know its price range" | pos_spec pricing has 4 red harness tests on the vol-type track and is explicitly out of scope; a registry that prices is a registry that can revert on arithmetic it shouldn't own | Store the raw validated tuple only. Pricing stays on the vol-type track; readers expose the packed word for off-chain pricing |
| **Atomic all-or-nothing batch** (ERC-4337 `executeBatch` model) | "Batches should be transactional" | 4337 account `executeBatch` reverts the whole batch on any single failure — wrong for Poisson flow where one malformed arrival must not drop the other N−1 valid orders | Best-effort per-call, Multicall3 `tryAggregate(false,...)` semantics: isolate failures, persist successes |
| **Batch-size unbounded** | "Let the client send as many as it wants" | Unbounded loops risk block-gas-limit DoS and non-deterministic batch success | Pin a `MAX_BATCH` bound (value TBC with peer `mv15a18k`); requirements assume a cap until confirmed |
| **Bitmap or count-only result** | "Cheaper return data" | A bitmap needs the client to know N separately and bit-index; count-only loses *which* succeeded and their ids — both break positional mapping the Poisson generator needs | `(bool success, uint256 orderId)[]` — see decision below |

## Key Decision: Per-Call Result Shape

**Recommendation: return `(bool success, uint256 orderId)[]`, one entry per input tuple, positionally aligned to the input array.** MEDIUM-HIGH confidence.

Grounding — Multicall3 (verified against `github.com/mds1/multicall` source):
- `aggregate3(Call3[])` returns `Result[]` where `Result = (bool success, bytes returnData)`; per-call `allowFailure` flag. This is the canonical *best-effort* shape: a parallel array of `(success, payload)` positionally matched to input.
- `tryAggregate(bool requireSuccess, Call[])` returns `(bool, bytes)[]`; `requireSuccess=false` is exactly our best-effort mode.
- `aggregate(Call[])` (the original) reverts if *any* call fails — the atomic model we reject.

Our specialization: because the batched function is fixed and its only meaningful output is the new id (a `uint256`), we replace Multicall3's opaque `bytes returnData` with a typed `uint256 orderId`. On failure, `success=false, orderId=0` (0 is the null sentinel, so it is unambiguous).

Why this beats the alternatives for a Haskell ABI decoder:
- `(bool, uint256)` is a **static tuple** (64 bytes, no inner offsets). A dynamic array of static tuples is the simplest non-trivial ABI shape to decode — `head = offset`, then `length`, then `N × 64` contiguous bytes. Any Haskell ABI lib (hs-web3-style) decodes this without recursive offset chasing.
- **Positional alignment** lets `StochasticOrderGen` map result[i] back to the i-th arrival it submitted — essential for a generator that must know which of its Poisson batch landed and re-attempt or record ids.
- A **bitmap** (`uint256`) is more compact but drops the ids entirely and forces the client to carry N out-of-band; a **count-only** `uint256` drops both which-succeeded and the ids. Both are false economies here.

## Empty-Batch and All-Fail Semantics

**Decision: never revert on empty or all-fail. Return a well-formed (possibly empty) results array.** MEDIUM confidence (aligned with Multicall3; the contract-of-record for the peer is TBC).

| Case | Behavior | Rationale |
|------|----------|-----------|
| Empty input array | Return empty `(success,id)[]` (length 0), no revert | Matches Multicall3 (no special-casing empty); a zero-arrival Poisson tick (`N=0`) is legal and must not revert the client's tx |
| All calls fail validation | Return `[(false,0), (false,0), ...]`, no revert; zero state written | Best-effort's whole point: the batch tx succeeds, the client reads which failed. Reverting would discard the diagnostic and waste the client's gas accounting |
| Mixed success/fail | Successes get real ids and persist; failures get `(false,0)` and write nothing | No-partial-state guarantee (differentiator above) |

The single-call `create_order` is the exception and **should revert** on invalid input (it has no batch to protect and its consumer expects fail-fast on a single arrival). This asymmetry is intentional: single-call = strict/revert, batch = best-effort/skip. Both route through the same internal validate step; only the failure *handling* differs (propagate vs. catch).

## Order-Id Semantics

**Decision: sequential `uint256` from 1; ids assigned only on success; failures consume no id (no gaps from failure — the counter simply doesn't advance).** HIGH confidence.

- Start at 1 so that `0` is a reliable null/sentinel (used for `orderId` in failed results and for "no such order" reads).
- `orderCount` is both the accumulator and the id source: `id = ++orderCount` on each successful store. First successful order → id 1.
- **No gaps from failure.** A failed call does not touch `orderCount`, so the id space stays dense over *successful* orders. This is cleaner for the client than "ids assigned pre-validation with gaps" — a dense space means `orderCount` equals the number of live orders and equals the latest id.
- Trade-off acknowledged: with best-effort batching, the client cannot pre-compute the id of its i-th arrival (it depends on how many earlier calls in the batch succeeded). This is exactly why the result array *returns* each id — the client learns ids from the return value, not by prediction.

## Reader Surface (module-not-a-black-box)

| Reader | Signature (indicative) | Purpose |
|--------|------------------------|---------|
| `orderCount()` | `() -> uint256` | Number of stored orders = latest id (dense space); batch-progress / observability |
| `getOrder(uint256 id)` | `(uint256) -> uint256` | Return the packed 152-bit `VolOrder` word for `id`; client unpacks `(width, tickSpacing, vol, skew)` |
| latest-id | subsumed by `orderCount()` | With a dense-on-success counter, latest id ≡ `orderCount` — no separate reader needed |

Reading a nonexistent id (`id == 0` or `id > orderCount`) should return `0` (the empty packed word) rather than revert, mirroring the best-effort ethos and letting the client probe cheaply.

## Feature Dependencies

```
create_order internal fn (validate + construct VolOrder + assign id + store)
    └──requires──> vol_order_is_complete  (TickVolatility + VolRangeWidth + SpreadTickAssimetry predicates)
    └──requires──> tickSpacing default    (create_order omits it; must be pinned)
    └──requires──> pack_vol_order layout  (152-bit word)

best-effort batch entrypoint
    └──requires──> create_order internal fn      (composes it N times)
    └──requires──> dynamic calldata array decode  (NEW Plank ground — main risk)
    └──requires──> dynamic (bool,uint256)[] encode (result shape)
    └──enhanced-by──> no-partial-state guarantee   (per-call validate-before-write)

getOrder / orderCount readers
    └──requires──> the storage layout create_order writes

batch (best-effort/skip)  ──contrasts-with──>  single create_order (strict/revert)
    (same validate step, opposite failure handling — do NOT unify the handling)
```

### Dependency Notes
- **Batch requires the internal fn, not the external selector.** The batch loop calls the shared internal `create_order` directly (no self-`call`), so there is no re-entrancy or dispatch overhead and the `single ≡ batch-of-1` differential is exact.
- **Dynamic-array ABI is the critical-path unknown.** Every existing module selector takes fixed words; decoding a `(uint88,uint24,uint16)[]` input and encoding a `(bool,uint256)[]` output is new for Plank and gates the whole batch feature. Roadmap should front-load a spike proving array in/out round-trips before building batch semantics on top.
- **tickSpacing default must be pinned before validation is testable** — otherwise `vol_range_width_is_complete`'s `<= 200` check has no operand.

## MVP Definition

### Launch With (v4.0)
- [ ] `create_order(uint88,uint24,uint16)` selector `0x6501fe94` — strict/revert, reuses `vol_order_is_complete`, pinned tickSpacing default — the peer contract of record
- [ ] Sequential u256 id from 1; `orderCount` accumulator; keccak-slot storage of the 152-bit packed word — a registry that persists
- [ ] Best-effort batch entrypoint returning `(bool success, uint256 orderId)[]` positionally aligned; empty-batch and all-fail return well-formed arrays, never revert; no-partial-state on failure — the milestone's reason to exist
- [ ] Readers `orderCount()` and `getOrder(uint256)` — module-not-a-black-box
- [ ] Interface file with cast-sig-verified signature strings — both tracks agree byte-for-byte
- [ ] v3.0 test discipline: CALLED-green claims, constructed valid/invalid tuple corpus, observed-RED mutation battery, Solidity reference-mock differential incl. the new `(success,id)[]` path

### Add After Validation (v4.x)
- [ ] `MAX_BATCH` cap tuned once the peer (`mv15a18k`) confirms batch-size bound — trigger: peer answers the open semantics message
- [ ] Confirm result shape against peer's decoder — trigger: peer's Haskell decode test lands; adjust if they need e.g. an `index` field

### Future Consideration (next milestone+)
- [ ] Per-owner order books + auth — defer: no auth primitive exists in v1; orders are anonymous by design
- [ ] Events for an indexer — defer: no log-subscribing consumer this milestone
- [ ] On-chain pricing (`tick_bucket_from_vol_order`) — defer: pos_spec pricing has 4 red harness tests; registry stays pricing-free

## Feature Prioritization Matrix

| Feature | Consumer Value | Implementation Cost | Priority |
|---------|----------------|---------------------|----------|
| `create_order` single selector (strict) | HIGH | MEDIUM | P1 |
| `vol_order_is_complete` validation | HIGH | LOW | P1 |
| Sequential id + storage + `orderCount` | HIGH | LOW | P1 |
| Best-effort batch + `(success,id)[]` result | HIGH | HIGH | P1 |
| Dynamic-array ABI spike (in/out) | HIGH (enabler) | HIGH | P1 |
| `getOrder` / `orderCount` readers | MEDIUM | LOW | P1 |
| No-partial-state guarantee | HIGH | MEDIUM | P1 |
| `MAX_BATCH` cap | MEDIUM | LOW | P2 |
| Events | LOW | LOW | P3 |
| Per-owner books / auth | LOW (this milestone) | HIGH | P3 |

## Established-Practice Reference (filtered through this design)

| Convention | Source | What we borrow | What we reject |
|------------|--------|----------------|----------------|
| Best-effort batch = parallel `(success, payload)[]` positionally matched to input | Multicall3 `aggregate3`/`tryAggregate(false)` (verified) | The result shape + failure-isolation semantics | Arbitrary `(target, callData)` dispatch |
| Original `aggregate` reverts on any failure | Multicall3 `aggregate` | — | Whole-batch atomicity |
| Atomic `executeBatch` | ERC-4337 account abstraction | — | All-or-nothing (drops valid Poisson arrivals) |
| Sequential ids from 1, 0 = null | Order-book / ERC-721-style id conventions | Dense id space, 0 sentinel | Owner-keyed sub-registries |

## Sources

- `src/types/pos_spec/VolOrder.plk` — kept `VolOrder` type, 152-bit pack layout, `vol_order_is_complete` (HIGH)
- `src/types/pos_spec/VolRangeWidth.plk:20-21` — width `(0, 2^24−1]`, tickSpacing `(0, 200]` (HIGH)
- `src/types/pos_spec/SpreadTickAssimetry.plk:11` — skew open interval `(0, 0xffff)` (HIGH)
- `src/types/pos_spec/TickVolatility.plk:7` — strike `> 0` (HIGH)
- `test/types/pos_spec/VolOrder.t.sol` — corpus/state conventions, tickSpacing=20, packed-word round-trip (HIGH)
- `lean4-spec/lean/vol_markets/PosSpec.lean` — `s_v ∈ [0,1]`, `skewTick_one`/`skewTick_zero` endpoint-collapse justifying the open u16 interval (HIGH)
- `.planning/PROJECT.md` — milestone v4.0 goal, consumer contract, anti-scope (pricing, auth) (HIGH)
- Multicall3 source `github.com/mds1/multicall` — `aggregate3`/`tryAggregate`/`aggregate` signatures + allowFailure semantics (HIGH, verified)
- ERC-4337 `executeBatch` atomic-batch contrast (MEDIUM, training)

---
*Feature research for: best-effort batched vol-order registry (VolOrderManagerMod)*
*Researched: 2026-07-19*
