# Design: `StochasticOrderGen` — a Poisson-driven batch order generator

**Date:** 2026-07-21
**Topic:** A new `StochasticOrderGen.*` library that draws a Poisson-distributed batch
size and drives it through a new `VolOrder.Rpc.create_orders` multicall primitive
(extending the existing `VolOrder.*` library), splitting into ≤128-order chunks as needed.
**Scope track:** rpc_api offchain (Haskell) only. `VolOrderManagerMod.plk`'s
`create_orders` entrypoint is already merged to `develop` (Plank track) — consumed here
read-only, not touched by this spec.
**Status:** two-step reviewed (Reality Checker + Solidity Smart Contract Engineer). Reality
Checker found no BLOCKER/MAJOR (spec called "unusually well-verified"), three MINORs
folded in. Solidity Smart Contract Engineer found no Critical, three Important findings
folded in — most notably a genuine silent-data-corruption risk: the packing formula as
originally specified combines fields with `|`/`<<` with no width validation, so an
out-of-range `vol_target` in `[2^88, 2^104)` would bleed into `range_width` with **zero
on-chain signal** (not a revert, not `(false, 0)`) — serious for a tool whose entire
purpose is generating trustworthy test data, even at "local dev tool" stakes.

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
  it. The standard, portable way to see it is an `eth_call` of the exact same calldata
  (a read-only simulation) either before or instead of `sendTransaction` — an earlier
  draft of this spec overstated this as "the only way" (node-specific
  `debug_traceTransaction`/trace namespaces can sometimes recover post-hoc return data,
  but aren't portable/standard, so `eth_call` remains the right choice regardless).
  **Review-corrected:** the earlier draft additionally asserted, without evidence, that
  "an `eth_call` preview immediately followed by `sendTransaction` cannot practically
  diverge" on this project's local single-writer `anvil` chain — true in the common case,
  but stated as fact rather than an assumption. Decision 9 below removes the need to rely
  on this assumption at all, by pairing the preview with a readback of what was actually
  mined.
- **`getOrderPacked(id)` returns the contract's *storage*-layout packed word, not the
  *input*-layout word `create_orders`/`pack_vol_order_input` (decision 1 below) produce.**
  Storage layout inserts the hardcoded `TICK_SPACING = 20` at bits 104–127 and shifts
  `width` to bits 128–151 (`pack_vol_order`/`unpack_vol_order` in
  `src/types/pos_spec/VolOrder.plk`) — a **third**, distinct bit layout from both the
  `create_order(uint88,uint24,uint16)` ABI-word format and the `create_orders` input-word
  format. Any code reading `getOrderPacked` back (decision 9) needs its own unpack
  function using this layout — reusing `pack_vol_order_input`'s inverse would silently
  misread every field.
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
9. **`pack_vol_order_input` validates each field's bit-width and fails clearly on
   overflow — it does not silently mask (added in review).** The contract's own decode
   deliberately leaves `width` unmasked so overflow ≥ `2^104` gets rejected by
   `vol_range_width_is_complete` — but review found this only catches large overflows: a
   `strike`/`vol_target` in `[2^88, 2^104)` shifts left by 16 and lands entirely within
   `width`'s own 24-bit slot, OR-ing in as a plausible-looking width with **no on-chain
   signal at all** (not a revert, not `(false, 0)`) — silent data corruption. Masking each
   field before combining (mirroring the contract's own storage-side `pack_vol_order`,
   which does mask each field) would only relocate the same silent-corruption risk from
   on-chain to off-chain. Instead, `pack_vol_order_input` explicitly validates
   `0 < vol_target < 2^88`, `0 < range_width < 2^24`, `0 < skew < 2^16` and fails with a
   clear, distinguishing error before ever combining the fields — mirroring
   `StochasticPriceGen.Simulate`'s "fail loudly, don't silently corrupt" domain-guard
   discipline exactly.
10. **The `eth_call` preview is paired with a post-hoc `orderCount()`-delta +
    `getOrderPacked(id)` readback, not relied on alone (added in review).** This removes
    the "preview cannot practically diverge from the mined result" assumption entirely,
    rather than merely asserting it: `create_orders` snapshots `orderCount()` immediately
    before `sendTransaction`, waits for the receipt, reads `orderCount()` again, then
    reads back every `getOrderPacked(id)` in the delta range — ground truth from what was
    actually mined, independent of whatever the `eth_call` preview predicted. The `eth_call`
    preview is kept (it's still the only way to see *which specific positions* in the
    batch failed, since a skipped order consumes no id and leaves no storage trace to read
    back), but the delta-readback is the authoritative confirmation of what landed.
    **Assumption stated plainly (PR-gate review):** the check compares the count delta
    against the preview's success *pattern* (which is preview-stable, because the
    contract's validation is stateless — a pure function of each packed word), never
    against the preview's absolute ids (which are not — any other writer landing between
    preview and send shifts the id base). Readbacks are pinned to the receipt's block,
    not `Latest`. What remains assumed is a single-writer window between the
    `orderCount()` snapshot and our own transaction: a concurrent writer inside that
    window causes a *loud* delta-mismatch failure after our transaction has already
    committed — never a silently wrong result.
11. **`create_orders` uses `callGas = Nothing` (dynamic node gas estimation), never a
    fixed/reused gas limit (clarified in review).** A full 128-order chunk measures ~10M
    gas in the Plank track's own test suite — roughly two orders of magnitude more than a
    single `create_order`. Reusing a fixed gas limit tuned for one order would silently
    under-provision a full batch, causing an out-of-gas failure independent of what the
    `eth_call` preview (which typically gets a much higher default gas cap from the node
    than a real `sendTransaction` would use) showed. `callGas = Nothing` on the
    `sendTransaction` `Call` record — same field, same value, `create_order` already uses
    today — defers gas selection to the node's own estimation for every call, single or
    batched, so this isn't new complexity, just confirming the existing pattern is safe to
    keep unchanged for `create_orders` too.
12. **`decode_create_orders_result` enforces strict bool canonicality (added in review).**
    The contract always emits canonical `0`/`1` success words (never a truthy nonzero) —
    confirmed by its own dedicated test and an explicit "named mutant" comment warning
    that a lenient decoder accepting non-canonical truthy words would silently disagree
    with what a real `abi.decode` (which rejects non-canonical bools) reports for the same
    bytes. The Haskell decoder matches that strictness: exactly `0` or `1`, anything else
    is a decode failure, not a lenient "nonzero = true."

## Module breakdown

### Layer 1 — extend `VolOrder.*` (existing library, `offchain/lib/VolOrder/`)

- **`VolOrder.Encoding`** gains:
  - `pack_vol_order_input :: VolOrder -> Either String Integer` — pure, validates each
    field's bit-width first (decision 9: `0 < vol_target < 2^88`, `0 < range_width <
    2^24`, `0 < skew < 2^16`, failing with a specific message identifying which field and
    why), then combines exactly as `packInput` does: `skew | (strike << 16) | (width <<
    104)`. Returns `Either` rather than a bare `Integer` specifically so a caller must
    handle the validation failure rather than it being silently possible to ignore.
    (Lives in `Encoding` rather than a new module — it's a small pure helper feeding
    directly into calldata construction, matching this module's existing scope.)
  - `encode_create_orders :: [VolOrder] -> IO HexString` — packs every order via
    `pack_vol_order_input` (propagating any field-validation failure as a clear `IO`
    failure, same `fail`-in-`IO` idiom used throughout this codebase), then shells out to
    `cast calldata "create_orders(uint256,uint256[])" <count>
    "[<packed1>,<packed2>,...]"` (same `readProcess "cast"` pattern already used
    throughout this codebase).
- **`VolOrder.Decode`** gains two pure decoders, distinct in purpose from the existing
  event-decoding code in the same module (different call sites — `eth_call` return
  values vs. log topics/data — sharing the file for its existing byte-slicing helpers,
  not because they're conceptually the same kind of decode):
  - `decode_create_orders_result :: HexString -> Either String [(Bool, Integer)]` — reads
    the offset/length header then walks `count` stride-`0x40` `(bool, uint256)` pairs,
    enforcing strict bool canonicality (decision 12: exactly `0`/`1`, anything else is a
    decode failure, not a lenient "nonzero = true").
  - `unpack_vol_order_storage :: Integer -> VolOrder` — the storage-layout unpacker
    (decision 10's readback path needs this): `width` at bits 128–151, `tickSpacing` at
    104–127 (read and discarded — it's always the contract's hardcoded `20`, not part of
    `VolOrder`), `vol_target` at bits 16–103, `skew` at bits 0–15. **Not** the same
    function as `pack_vol_order_input`'s inverse — a third, distinct bit layout (Ground
    truth) from both the single-order ABI-word format and the `create_orders` input-word
    format; conflating them would silently misread every field.
- **`VolOrder.Rpc`** gains:
  - `create_orders :: Address -> Address -> [VolOrder] -> Web3 (TxReceipt, [(Bool,
    Integer)])` — validates `length orders <= 128` (fails clearly, mirroring
    `StochasticPriceGen`'s domain-guard discipline, otherwise the on-chain `require`
    would revert anyway but with a less specific, empty-data message — Error handling
    below); builds calldata via `encode_create_orders` (which itself fails clearly on any
    field-width violation, decision 9); does the `eth_call` preview via the same `Call`
    record shape already used in `PriceSetter.Rpc.eth_call_hook` and decodes it via
    `decode_create_orders_result`; reads `orderCount()` before `sendTransaction`
    (`callGas = Nothing`, decision 11) and `wait_for_receipt` (reusing the existing
    function); reads `orderCount()` again and `getOrderPacked(id)` for every id in the
    delta range, decoding each via `unpack_vol_order_storage` (decision 10); returns the
    receipt and the eth_call-previewed per-order outcomes. The delta-readback isn't part
    of this function's return type — it exists to let the implementation *assert*
    consistency between preview and mined result (Testing step 7), not to add a second
    return channel the caller must reconcile.
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
Haskell needs to re-implement. What *can* fail at the Haskell layer: field-width
validation in `pack_vol_order_input` (decision 9, fails before any calldata is even
built); the `N > length orders` guard (decision 4, fails immediately, no RPC calls made
yet); a chunk exceeding 128 (structurally impossible given the chunking logic, but if it
ever happened the on-chain `require` would revert — inherits the same partially-unknown
`Left`-vs-uncaught-exception characteristic already documented for `write_price` and
`StochasticPriceGen`, not re-litigated here); and ordinary RPC-level failures
(`eth_call`/`sendTransaction` errors), which propagate the same way they already do
throughout this codebase.

**All four of the contract's structural guards (`count <= MAX_BATCH`, the calldata
offset/length/size checks) are empty-data reverts with no distinguishing reason string
(review finding).** An `eth_call` preview failing against any of them is detectable (the
call reverts) but not attributable to a specific guard from the revert alone. This
spec's own pre-flight `length orders <= 128` check (and correct-by-construction calldata
from `cast calldata`) means these guards should never actually fire in practice — but if
`encode_create_orders` ever produces malformed calldata some other way, the resulting
failure will be undifferentiated. Worth knowing, not worth building reason-string
recovery for at this stage.

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
7. **Field-width validation test (added in review, closes the silent-corruption gap):**
   a deliberate `vol_target` in `[2^88, 2^104)` (e.g. `2^88 + 1`) passed to
   `pack_vol_order_input`, confirming it fails clearly with a field-specific message
   **before** any calldata is built — not that it produces a plausible-looking-but-wrong
   packed word. This is the one test that would have caught the review's central finding;
   it must exist before this spec is considered verified, not merely designed correctly.
8. **Preview-vs-mined consistency test (added in review, closes the "cannot practically
   diverge" assumption gap):** in the same live run as step 4, confirm the
   `orderCount()`-delta + `getOrderPacked` readback (decoded via
   `unpack_vol_order_storage`) matches the `eth_call` preview's successful entries
   exactly — this is what actually verifies decision 10's readback path is correct, not
   just present.
9. A deliberate non-canonical bool word (e.g. hand-constructed `HexString` with a success
   field of `2` instead of `0`/`1`) fed to `decode_create_orders_result`, confirming it
   fails rather than lenient-accepting it as truthy (decision 12).

## Out of scope (explicit)

- No real arrival-time point process (decision 2) — single batch-count draw only.
- No `VolOrder` content generation inside `StochasticOrderGen` (decision 3) — the future
  integration module connecting this to `StochasticPriceGen`/other models is separate,
  unscoped work.
- No fix for the dead `VolOrder.Decode`/`Report` event-based reporting (Ground truth) —
  filed as its own follow-up spec. That follow-up should reuse `unpack_vol_order_storage`
  (this spec introduces it for the delta-readback, decision 10) rather than re-deriving
  the storage bit layout independently.
- No reason-string recovery for the contract's four empty-data structural-guard reverts
  (Error handling) — an undifferentiated failure is acceptable at this stage.
- No changes to `VolOrderManagerMod.plk` or any other Plank/Solidity source — consumed
  read-only, already merged.
- No atomic-batch mode — the contract is best-effort only; this spec doesn't add an
  offchain-simulated atomicity layer on top.

## Success criteria (what must be TRUE)

1. `offchain/lib/VolOrder/{Encoding,Decode,Rpc}.hs` gain `pack_vol_order_input`,
   `encode_create_orders`, `decode_create_orders_result`, `unpack_vol_order_storage`,
   `create_orders` respectively, with the exact signatures described above.
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
7. An out-of-range `vol_target` (specifically in `[2^88, 2^104)`) fails clearly in
   `pack_vol_order_input`, before any calldata is built — never silently corrupts
   `range_width` (decision 9, Testing step 7). This is the review's central finding and
   the most load-bearing criterion in this spec.
8. The `orderCount()`-delta + `getOrderPacked` readback (via `unpack_vol_order_storage`)
   matches the `eth_call` preview's successful entries exactly in a live run (decision 10,
   Testing step 8).
9. `decode_create_orders_result` rejects a non-canonical bool word rather than
   lenient-accepting it (decision 12, Testing step 9).
10. `cabal build` succeeds cleanly (no warnings).
