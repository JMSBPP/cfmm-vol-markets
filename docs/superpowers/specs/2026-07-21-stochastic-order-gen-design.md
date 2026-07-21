# Design: `StochasticOrderGen` — a Poisson-driven batch order generator

**Date:** 2026-07-21
**Topic:** A new `StochasticOrderGen.*` library that draws a Poisson-distributed batch
size and drives it through a new `VolOrder.Rpc.create_orders` multicall primitive
(extending the existing `VolOrder.*` library), splitting into ≤128-order chunks as needed.
**Scope track:** rpc_api offchain (Haskell) only. `VolOrderManagerMod.plk`'s
`create_orders` entrypoint is already merged to `develop` (Plank track) — consumed here
read-only, not touched by this spec.
**Status:** design drafted via interactive brainstorming; pending two-step review
(Reality Checker + a specialist) before being treated as ready to plan/implement.

## Motivation

`VolOrder.Rpc.create_order` submits one order per transaction. The Plank track has since
shipped a real on-chain multicall entrypoint, `create_orders(uint256,uint256[])`, that
batches up to 128 orders into a single transaction with best-effort (non-atomic)
per-order semantics. This spec adds the offchain Haskell side: a Poisson-distributed
batch-size generator (`StochasticOrderGen`, mirroring `StochasticPriceGen`'s established
generator pattern) driving the new batch primitive.

## Ground truth (verified, not assumed)

- **`create_orders` is real, merged, and tested** — `src/modules/pos_spec/VolOrderManagerMod.plk`
  on `develop` (confirmed: `git merge-base --is-ancestor origin/feat/plank origin/develop`
  succeeds as of this spec). Selector `0x81357911`, signature
  `create_orders(uint256,uint256[])` = `(count, packedOrders)`.
- **Input packing, verified against `test/pos_spec/VolOrderManagerBatch.t.sol`'s own
  reference `packInput` helper** (not just read from the dispatch/decode logic — cross-checked
  against the test suite's independent implementation, byte-for-byte identical):
  ```
  packed = skew | (strike << 16) | (width << 104)
  ```
  where `strike` (= `vol_target`) is the 88-bit field, `width` (= `range_width`) is the
  24-bit field, `skew` is the 16-bit field — the same three `VolOrder` fields
  `create_order` already uses, just packed into one `uint256` instead of three separate
  ABI words. **This is a different bit layout than the contract's internal storage
  packing** (`pack_vol_order`, which inserts a hardcoded `TICK_SPACING = 20` at bits
  104–127 and shifts `width` to 128+) — the offchain encoder must replicate the *input*
  layout above, not the storage one.
- **Semantics: best-effort, not atomic** — confirmed in the Plank source's own extensive
  comments ("`MCAL-03`: BEST-EFFORT = VALIDATE BEFORE WRITE... an invalid tuple is
  skipped by never being written"). A failing tuple returns exactly `(false, 0)` at its
  position; results stay positionally aligned to the input, no shifting.
- **Return shape**: `(bool success, uint256 orderId)[]`, ABI-encoded as a static-tuple
  array: offset word `0x20`, length word (= `count`, in elements), then inline
  `(bool, uint256)` pairs at stride `0x40`. Total size `64 + 64*count` bytes; `count = 0`
  is a well-formed 64-byte empty result, not 0 or 32 bytes.
- **`MAX_BATCH = 128`, hard on-chain revert above it** — `require(count <= MAX_BATCH)` in
  the Plank source; a caller sending more than 128 packed orders in one call gets the
  whole transaction reverted, not a silent truncation. The offchain side must split into
  multiple `create_orders` transactions itself if it wants to send more than 128 orders
  in one run.
- **`create_orders`'s return value is not in the transaction receipt.** A receipt only
  carries logs/status/gas — a state-changing function's ABI return value is never part of
  it. To actually decode the per-order `(bool, orderId)` results, the offchain side must
  `eth_call` the exact same calldata (a read-only simulation) either before or instead of
  `sendTransaction`. On this project's local single-writer `anvil` dev chain, an `eth_call`
  preview immediately followed by `sendTransaction` cannot practically diverge.
- **`System.Random.MWC.Distributions.poisson :: StatefulGen g m => Double -> g -> m Int`**
  (verified against the real `mwc-random-0.15.3.0` source, same package/version already a
  dependency via `StochasticPriceGen`) — draws a Poisson-distributed count given rate
  `λ`. It already guards its own domain: negative `λ` or `λ` too large to fit in `Int`
  both raise a clear, distinguishable `pkgError` — no NaN-cascade risk like the one found
  and fixed in `StochasticPriceGen.Simulate`; this library function's guard is sufficient
  as-is, nothing to add on top.
- **A significant, separately-tracked regression was discovered while investigating this
  spec, out of scope for this spec itself**: the merged `VolOrderManagerMod.plk` no
  longer emits an `OrderCreated` event at all (confirmed: zero `evm_log`/`OrderCreated`
  references anywhere in the merged module) — replaced by `orderCount()`/
  `getOrderPacked(id)` storage reads. `create_order`'s selector is unchanged, so existing
  `VolOrder.Rpc.create_order` calls still succeed, but the already-shipped
  `VolOrder.Decode.decode_order_created`/`VolOrder.Report.report_receipt` event-based
  reporting is now silently dead (falls through to printing `logs (none)`, no crash). Per
  discussion, this is filed as its own follow-up spec after this one — not addressed here.

## Decisions (from brainstorming)

1. **`Poisson` is the arrival-process type**, structurally analogous to `ProcessType`
   (`GBM`/`CEV`) but for a fundamentally different kind of process (event arrivals/counts,
   not a continuous price path) — it cannot be a third `ProcessType` constructor.
2. **A single Poisson-distributed batch count, not a real arrival-time process.** One
   `poisson λ gen` draw determines `N`, the number of orders to submit in this run; all
   `N` are sent immediately (split into `⌈N/128⌉` sequential `create_orders` calls if
   `N > 128`) — no real-time waiting between individual orders. `λ` means "expected batch
   size" here, not "orders per second." Mirrors `StochasticPriceGen`'s "generate
   everything before any RPC call" simplicity; a true point-process (real inter-arrival
   delays) is a materially bigger feature, deferred.
3. **`StochasticOrderGen` does not generate `VolOrder` content itself.** The actual
   `vol_target`/`range_width`/`skew` values for each order are supplied by the caller as
   a `[VolOrder]` list — this keeps the module narrowly scoped to arrival-count-driven
   orchestration, and composes cleanly with a future integration module connecting order
   content to `StochasticPriceGen` or other models (explicitly out of scope here).
4. **No silent truncation if the Poisson draw exceeds the supplied order list.** If
   `N > length orders`, the run fails clearly rather than silently sending only
   `length orders` — mirrors `StochasticPriceGen`'s "no clamping, fail loudly" precedent
   rather than hiding a caller bug (not supplying enough orders) behind a quietly smaller
   batch.
5. **Best-effort semantics are inherited from the contract, not re-decided here** — the
   on-chain entrypoint is already best-effort by design (decision made and implemented on
   the Plank side); this spec's Haskell types just surface the resulting per-order
   `(Bool, Integer)` outcomes to the caller, they don't add a second error-handling layer.
6. **`eth_call` preview + `sendTransaction`**, not fire-and-forget — the only way to
   actually decode per-order results, given a receipt alone carries no return value.
7. **Two-layer module split**: extend `VolOrder.*` with the new on-chain batch primitive
   (same contract, a second entrypoint — belongs in the existing family), and add a new
   `StochasticOrderGen.*` family (mirroring `StochasticPriceGen.*`'s
   `Types`/`Simulate`/`Report`/`Rpc` shape) for the Poisson-driven orchestration that
   consumes it. Not a single combined module — the two concerns (a new RPC primitive on
   an existing contract vs. a new generator) are genuinely separate, matching how
   `StochasticPriceGen` was kept separate from `PriceSetter`.
8. **Sequential, non-concurrent chunk sends** when `N > 128` requires multiple
   `create_orders` calls — simplest default, consistent with every other RPC orchestration
   module in this codebase; no strong reason for concurrency here either.

## Module breakdown

### Layer 1 — extend `VolOrder.*` (existing library, `offchain/lib/VolOrder/`)

- **`VolOrder.Encoding`** gains:
  - `pack_vol_order_input :: VolOrder -> Integer` — pure, `skew | (strike << 16) | (width
    << 104)`, exactly matching the verified `packInput` reference. (Lives in `Encoding`
    rather than a new module — it's a small pure helper feeding directly into calldata
    construction, matching this module's existing scope.)
  - `encode_create_orders :: [VolOrder] -> IO HexString` — packs every order via
    `pack_vol_order_input`, then shells out to `cast calldata
    "create_orders(uint256,uint256[])" <count> "[<packed1>,<packed2>,...]"` (same
    `readProcess "cast"` pattern already used throughout this codebase).
- **`VolOrder.Decode`** gains a pure decoder for the `(bool,uint256)[]` return blob:
  `decode_create_orders_result :: HexString -> [(Bool, Integer)]` — reads the offset/length
  header then walks `count` stride-`0x40` `(bool, uint256)` pairs. (Separate from the
  existing `decode_order_created`/event-decoding code in the same module — different
  concern, same file, since both are "pure decode of raw returned bytes.")
- **`VolOrder.Rpc`** gains:
  - `create_orders :: Address -> Address -> [VolOrder] -> Web3 (TxReceipt, [(Bool,
    Integer)])` — validates `length orders <= 128` (fails clearly, mirroring
    `StochasticPriceGen`'s domain-guard discipline, otherwise the on-chain `require`
    would revert anyway but with a less specific message); builds calldata via
    `encode_create_orders`; does the `eth_call` preview via the same `Call` record shape
    already used in `PriceSetter.Rpc.eth_call_hook` and decodes it via
    `decode_create_orders_result`; then `sendTransaction` + `wait_for_receipt` (reusing
    the existing function) to actually commit; returns both the receipt and the
    eth_call-previewed per-order outcomes.
  - **Not** a `create_orders_and_report` wrapper in this layer — reporting happens at the
    `StochasticOrderGen.Report` layer instead, since the batch-splitting orchestration
    (layer 2) is what actually decides how many `create_orders` calls happen per run.

### Layer 2 — new `StochasticOrderGen.*` (`offchain/lib/StochasticOrderGen/`)

- **`StochasticOrderGen.Types`**:
  ```haskell
  data ArrivalProcess = Poisson { lambda :: Double }

  data StochasticOrderGen = StochasticOrderGen
    { arrival_process :: ArrivalProcess
    , orders          :: [VolOrder]
    }
  ```
  `ArrivalProcess` is a one-constructor sum type (not a bare `Double` field) deliberately
  mirroring `ProcessType`'s shape, for the same reason `ProcessType` is a sum type — room
  to add another arrival model later without breaking the interface. `orders` is the
  caller-supplied source of order content (decision 3); its length is the hard ceiling on
  how many orders this run can ever send (decision 4).
- **`StochasticOrderGen.Simulate`**: `simulate_batch_count :: GenIO -> ArrivalProcess ->
  IO Int` — `poisson lambda gen` (decision 2), no additional guard needed (Ground truth —
  `poisson` already guards its own domain).
- **`StochasticOrderGen.Report`**: thin IO, prints per-chunk `(success, orderId)` counts
  (how many of this chunk succeeded/failed) once each chunk's `eth_call` preview is
  decoded — batch-level summary, not full trajectory detail (mirrors
  `StochasticPriceGen.Report`'s "once per logical unit of work" shape, here that unit is
  a chunk rather than a whole run, since a run can be multiple chunks).
- **`StochasticOrderGen.Rpc`**:
  - `run_order_gen :: Address -> Address -> StochasticOrderGen -> GenIO -> Web3
    [(TxReceipt, [(Bool, Integer)])]` — draws `N` via `simulate_batch_count`; fails
    clearly if `N > length (orders config)` (decision 4); splits `take N (orders config)`
    into `⌈N/128⌉` chunks of ≤128; folds `VolOrder.Rpc.create_orders` sequentially over
    the chunks (decision 8), returning each chunk's `(TxReceipt, [(Bool, Integer)])`. No
    printing — reusable.
  - `run_order_gen_and_report :: Address -> Address -> StochasticOrderGen -> GenIO -> IO
    ()` — the thin `IO` wrapper, mirroring `write_price_and_report`/`run_price_gen`'s
    established two-tier pattern.

## Data flow

`StochasticOrderGen` config → `Simulate.simulate_batch_count` (one `poisson` draw → `N`)
→ (fail if `N > length orders`, else `take N orders`, chunked into `≤128`-sized groups) →
`Rpc.run_order_gen` folds `VolOrder.Rpc.create_orders` sequentially over the chunks
(each chunk: pack → `eth_call` preview → decode → `sendTransaction` → receipt) → `Report`
prints a per-chunk summary.

## Error handling

`create_orders`'s own on-chain best-effort semantics mean an individual bad order never
reverts its chunk — that's already handled by the contract, not something this spec's
Haskell needs to re-implement. What *can* fail at the Haskell layer: the `N > length
orders` guard (decision 4, fails immediately, no RPC calls made yet); a chunk exceeding
128 (structurally impossible given the chunking logic, but if it ever happened the
on-chain `require` would revert — inherits the same partially-unknown
`Left`-vs-uncaught-exception characteristic already documented for `write_price` and
`StochasticPriceGen`, not re-litigated here); and ordinary RPC-level failures
(`eth_call`/`sendTransaction` errors), which propagate the same way they already do
throughout this codebase.

## Testing / verification

No unit-test framework exists in this project (consistent with every other library here).
Verification plan:
1. `cabal build` clean, zero `-Wall` warnings.
2. A `cabal repl` smoke test of `pack_vol_order_input` against a known `VolOrder`,
   cross-checked by hand against `packInput`'s formula (or, if `cast` is available,
   against `cast calldata`'s own encoding of an equivalent call) — confirms the packing
   bit-shifts are exactly right before any live call depends on them.
3. A `cabal repl` smoke test of `simulate_batch_count` with a fixed-seed `Gen` (two
   independent `create` calls, matching `StochasticPriceGen`'s established reproducibility
   pattern) — confirms determinism.
4. A live end-to-end run against the deployed `VolOrderManager` rig: a small
   `StochasticOrderGen` config (`Poisson { lambda = <small N> }`, a matching-length
   `orders` list including at least one deliberately-invalid order to exercise best-effort
   behavior) — confirm the `eth_call`-previewed `(Bool, Integer)` results match what
   actually landed on-chain (via `orderCount()`/`getOrderPacked` reads), and that the
   invalid order in the mix comes back `(false, 0)` without the batch reverting.
5. A deliberate `N > length orders` case, confirming the clear failure from decision 4
   fires before any RPC call.
6. A deliberate `> 128`-order config, confirming the chunking logic actually splits into
   multiple `create_orders` calls rather than attempting one oversized call.

## Out of scope (explicit)

- No real arrival-time point process (decision 2) — single batch-count draw only.
- No `VolOrder` content generation inside `StochasticOrderGen` (decision 3) — the future
  integration module connecting this to `StochasticPriceGen`/other models is separate,
  unscoped work.
- No fix for the dead `VolOrder.Decode`/`Report` event-based reporting (Ground truth) —
  filed as its own follow-up spec.
- No changes to `VolOrderManagerMod.plk` or any other Plank/Solidity source — consumed
  read-only, already merged.
- No atomic-batch mode — the contract is best-effort only; this spec doesn't add an
  offchain-simulated atomicity layer on top.

## Success criteria (what must be TRUE)

1. `offchain/lib/VolOrder/{Encoding,Decode,Rpc}.hs` gain `pack_vol_order_input`,
   `encode_create_orders`, `decode_create_orders_result`, `create_orders` respectively,
   with the exact signatures described above.
2. `offchain/lib/StochasticOrderGen/{Types,Simulate,Report,Rpc}.hs` exist with the exports
   described above, including `run_order_gen_and_report`.
3. `pack_vol_order_input`'s bit layout is verified against `packInput`'s reference formula
   before any live call depends on it (Testing step 2).
4. A Poisson draw exceeding `length orders` fails clearly, with zero RPC calls made
   (decision 4, Testing step 5).
5. A batch exceeding 128 orders is split into multiple sequential `create_orders` calls,
   never one oversized call (decision 8, Testing step 6).
6. `create_orders`'s `eth_call`-previewed per-order results match what actually landed
   on-chain, including at least one deliberately-invalid order surfacing as `(false, 0)`
   without reverting the rest of the chunk (Testing step 4).
7. `cabal build` succeeds cleanly (no warnings).
