# Design: Extract `Main.hs` into a `VolOrder` library

**Date:** 2026-07-16 (revised after two-agent review)
**Topic:** Refactor `offchain/app/Main.hs` — currently a single ~155-line module mixing
domain types, config constants, calldata encoding, RPC send/poll orchestration, and
receipt/log decoding/reporting — into a small `VolOrder.*` library plus a thin `Main`.
**Scope track:** rpc_api offchain (Haskell) — no GAMS, Lean4, Plank `.plk`, or Foundry test
files touched.
**Status:** approved design, revised post-review, behavior-preserving refactor (no new
functionality).

## Review history

Reviewed in parallel by a Reality Checker and a Software Architect against the actual
current `Main.hs` and `.cabal` file (not just this spec's claims). Two BLOCKERs and three
MAJORs were raised and are folded into this revision:

1. **[Reality Checker, BLOCKER]** The spec's original module breakdown never accounted for
   `Main.hs`'s `{-# LANGUAGE OverloadedStrings #-}` pragma, required for the `Address`
   string literals (`account`, `order_manager`). Fixed: the pragma now travels with the
   module that keeps those literals (see "Demo values location" below).
2. **[Software Architect, BLOCKER]** The original `VolOrder.Report` fused pure log-decoding
   with `IO`-based printing (`report_order_created` decoded and `putStrLn`'d in the same
   function), which defeats the spec's own stated motivation: a future subscription/queue
   consumer (todo items 2–3) couldn't reuse the decode logic without dragging in console
   output. Fixed: decode and report are now separate modules (see "Module breakdown").
3. **[Reality Checker, MAJOR]** The original cabal-diff wording claimed `web3-ethereum` and
   `web3-solidity` move from the executable to the library stanza. They don't move — they
   are **already** in the library stanza. Fixed: the cabal-changes section below lists only
   the genuinely new library dependencies.
4. **[Software Architect, MAJOR]** `VolOrder.Rpc.create_order` calling
   `VolOrder.Report.report_receipt` directly welds the reusable submission path to console
   printing. Fixed: `create_order` now returns the RPC result; a separate thin wrapper does
   the printing (see "Module breakdown").
5. **[Software Architect, MAJOR]** Putting hardcoded demo values in an *exposed library
   module* (`VolOrder.Sample`) blurs "reusable API" vs. "this one demo's fixture data."
   Fixed: demo values move to an executable-local module instead (see "Demo values
   location").

The remaining findings (process/`cast` as a leaky library dependency; export-list
guidance; `VolOrder.Rpc` likely needing a further split when the subscription transport
arrives) are addressed as explicit notes below rather than requiring a different module
layout — see "Known liabilities" and "Out of scope."

## Motivation

`Main.hs` currently does everything: it defines the `VolOrder` domain type, the demo
account/manager addresses, calldata encoding via a `cast` subprocess, transaction
submission + bounded receipt polling, and receipt/log reporting (including low-level
hex/byte decoding for the `ORDER_CREATED` event). Nothing else in the project imports it —
the project's actual library (`exposed-modules: MyLib` in the `.cabal` file) is an unused
stub (`someFunc = putStrLn "someFunc"`).

`todo.md` items 2–9 (live event subscription, an `EventQueue`, Postgres integration, a
Haskell↔GAMS API) will all need the same `VolOrder` type and the same log-decoding logic
`Main.hs` already has — as *data*, not as printed text. Left as-is, that code would either
get duplicated per new module or force this exact extraction later, under more time
pressure. This refactor does it now, while the surface is small, and keeps the decode logic
reusable in the form those future consumers will actually need: pure functions returning
structured data, not `IO ()` print statements.

## Decisions (from brainstorming + review)

1. **Promote to the library, not just multiple executable-only modules.** Reusable pieces
   move into `offchain/lib/`, replacing the `MyLib` stub, so they are available as a real
   library dependency to future executables/modules (subscription listener, event queue,
   etc.) without re-extraction.
2. **Hierarchical namespace `VolOrder.*`** (not flat `Types`/`Encoding`/`Rpc`/`Report`
   modules at the library root) — scales better as more modules get added for the
   subscription/queue/DB work in later todo items.
3. **Thinnest possible `Main`**, without welding the reusable submission path to printing.
   `Main.hs` calls one function that submits an order and reports the result — it never
   pattern-matches the RPC `Either` itself — but the *reusable* `create_order` function
   underneath returns its result rather than printing, so a future caller (e.g. an
   `EventQueue` consumer) can use it without console output.
4. **Decode is pure; report is IO.** Log decoding (`ORDER_CREATED` topics/data → a
   structured event value) lives in a pure module with no `IO`. Printing that value is a
   separate, thin formatting module. This is what makes the decode logic actually reusable
   by todo items 2–3, per review finding 2 above.
5. **Demo values are executable-local, not library-exposed.** `account`, `order_manager`,
   and `sample_order` live in `offchain/app/Sample.hs` (part of the `executable` stanza),
   not in the library — per review finding 5, a library module full of one demo's hardcoded
   addresses is not reusable API surface.

## Module breakdown

Six modules total: five in the library (`offchain/lib/VolOrder/`, replacing
`offchain/lib/MyLib.hs`) and one executable-local module
(`offchain/app/Sample.hs`).

### Library — `offchain/lib/VolOrder/`

- **`VolOrder.Types`** — the `VolOrder` domain record: `vol_target`, `range_width`, `skew`
  (all `Quantity`). **Exports:** the `VolOrder` type, its constructor, and all three field
  accessors (`Encoding` and `Sample` both need direct field access).
- **`VolOrder.Encoding`** — `encode_create_order :: VolOrder -> IO HexString` (the
  `cast calldata create_order(uint88,uint24,uint16) ...` subprocess call) and the `trim`
  helper it uses. **Exports:** `encode_create_order` only (`trim` stays internal).
- **`VolOrder.Decode`** *(new — split out of the original `Report` module per review
  finding 2)* — pure decoding, no `IO`: the low-level hex/byte helpers `hex_to_integer`,
  `data_word`, `be_integer`; the `topic_order_created` constant (`0xa8892769`, matching
  `TOPIC_ORDER_CREATED` in `src/modules/VolOrderManagerMod.plk`); and a decoder from a raw
  `Change` log into a structured `OrderCreatedEvent` record (`orderOwner :: Address`,
  `orderCreatedAt :: UTCTime`, `orderVolTarget`, `orderRangeWidth`, `orderSkew ::
  Integer`), e.g. `decode_order_created :: Change -> Maybe OrderCreatedEvent`. **Exports:**
  `OrderCreatedEvent` (record + fields), `decode_order_created`, `topic_order_created`.
  This is the module a future subscription/queue consumer imports — it never touches `IO`.
- **`VolOrder.Report`** — thin `IO` formatting only: `report_receipt`, `status_text`,
  `report_log` (calls `VolOrder.Decode.decode_order_created`; on `Just event` prints its
  fields, on `Nothing` falls back to raw topic/data printing). **Exports:**
  `report_receipt` (the only entry point `Rpc`'s wrapper needs).
- **`VolOrder.Rpc`** — the reusable orchestration: `create_order :: Address -> Address ->
  VolOrder -> Web3 (Either RpcError TxReceipt)`, which builds the `Call`, calls
  `sendTransaction`, and awaits the receipt via `wait_for_receipt` (the bounded ~10s /
  200ms-interval poll loop over `GlobalState.getTransactionReceipt`) — **it does not
  print anything**. Also exports `create_order_and_report :: Address -> Address ->
  VolOrder -> IO ()`, a thin wrapper that runs `create_order` via `runWeb3'` and either
  prints the RPC error (`Left`) or calls `VolOrder.Report.report_receipt` (`Right`). This
  wrapper is what `Main` calls. **Exports:** `create_order`, `create_order_and_report`,
  `wait_for_receipt`.

### Executable-local — `offchain/app/`

- **`Sample`** *(new file, `offchain/app/Sample.hs`, listed in the executable stanza's
  `other-modules`)* — the concrete demo values: `account`, `order_manager`,
  `sample_order`. Carries `{-# LANGUAGE OverloadedStrings #-}` (needed for the `Address`
  string literals — this is where that pragma now lives, resolving review finding 1).
  Imports `Data.Solidity.Prim.Address` and `VolOrder.Types` directly.
- **`Main`** (`offchain/app/Main.hs`) — imports `Sample` and
  `VolOrder.Rpc.create_order_and_report`:

  ```haskell
  module Main where

  import Sample (account, order_manager, sample_order)
  import VolOrder.Rpc (create_order_and_report)

  main :: IO ()
  main = create_order_and_report account order_manager sample_order
  ```

## Data flow

`Sample` values flow into `VolOrder.Rpc.create_order_and_report`, which calls
`create_order` (builds calldata via `VolOrder.Encoding.encode_create_order`, submits the
transaction, polls for the receipt via `wait_for_receipt`) to get an `Either RpcError
TxReceipt`, then either prints the error or calls `VolOrder.Report.report_receipt` with the
`TxReceipt`. `report_receipt` prints status/block/from/to/gas, and for each log calls
`VolOrder.Decode.decode_order_created`; a decoded `ORDER_CREATED` log is printed as owner /
UTC timestamp / `vol_target` / `range_width` / `skew`, and any other log falls back to raw
topic/data printing. A future subscription/queue consumer calls
`VolOrder.Decode.decode_order_created` directly on logs it receives from its own transport,
without touching `VolOrder.Report` or any `IO`.

## Cabal changes

In `cfmm-replicationPlank-rpc-api.cabal`:

- **`library` stanza:** `exposed-modules` changes from `MyLib` to `VolOrder.Types,
  VolOrder.Encoding, VolOrder.Decode, VolOrder.Report, VolOrder.Rpc`. `build-depends` gains
  the dependencies those modules need that aren't already present: `web3-provider`,
  `memory-hexstring`, `process`, `bytestring`, `time`. (**Correction from the original
  draft:** `web3-ethereum` and `web3-solidity` are already in the library's
  `build-depends` — they are not moving, only staying.)
- **`executable` stanza:** `main-is: Main.hs`, `other-modules: Sample`. `build-depends`
  becomes `base`, the library (`cfmm-replicationPlank-rpc-api`), and `web3-solidity` (
  `Sample.hs` imports `Data.Solidity.Prim.Address` directly, so the executable component
  needs that package even though it doesn't touch RPC/encoding/decoding itself).
- `offchain/lib/MyLib.hs` is deleted (its one export, `someFunc`, is unused dead code —
  confirmed no references anywhere in the repo, including `offchain/test/Main.hs`).

## Known liabilities (not resolved by this refactor)

- **`process`/`cast` in the library.** `VolOrder.Encoding.encode_create_order` shells out
  to the `cast` CLI. Moving it into the library means anything depending on the library
  now implicitly requires a `cast` binary on `PATH` at runtime — a hidden, non-portable
  side channel unlike the library's other (RPC/network) dependencies. This liability
  already existed in `Main.hs`; this refactor does not fix it, only relocates it. A cleaner
  long-term fix (e.g. encoding calldata via `web3-solidity`'s own ABI support instead of
  shelling out) is out of scope here and left as a follow-up.
- **`VolOrder.Rpc` will likely need a further split later.** The subscription transport
  (todo item 2) is structurally different from one-shot submit-and-poll (a persistent
  stream vs. a bounded poll loop) and may not fit cleanly alongside `create_order` in the
  same module. Expect a future `VolOrder.Rpc.Submit` / `VolOrder.Rpc.Subscribe` split; not
  needed for this refactor.

## Error handling

`VolOrder.Rpc.create_order` returns `Either RpcError TxReceipt` rather than handling it —
callers decide what to do with a failure. The demo path
(`create_order_and_report`) preserves today's behavior exactly: `Left` prints the RPC
error, `Right` reports the receipt. `Main` itself never sees the `Either` — it only calls
`create_order_and_report`, matching decision 3 above. `wait_for_receipt`'s bounded-retry
`fail` on exhaustion is unchanged.

## Testing / verification

This is a behavior-preserving move, not new functionality — no new tests are in scope.
Verification is:

1. `cabal build` succeeds with the new module layout and no `-Wall` warnings.
2. Re-run the same manual end-to-end check used when `Main.hs`'s receipt reporting was
   first built: start `anvil`, deploy `VolOrderManager` via
   `forge script foundry-scripts/VolOrderManager.s.sol --broadcast --ffi --via-ir`, then
   `cabal run exe:cfmm-replicationPlank-rpc-api` and confirm the printed output has
   identical field values, in the same order, to the pre-refactor `Main.hs`'s output: tx
   hash, status, block number, from/to addresses, gas used and effective gas price, and —
   for the `ORDER_CREATED` log — owner, UTC timestamp, `vol_target`, `range_width`, `skew`.

## Out of scope (explicit)

- No behavior changes to the RPC calls, polling interval/bound, or the printed report
  format — this is a pure code-motion (plus one internal decode/print split) refactor.
- No new modules for todo items 2–9 (subscription, `EventQueue`, Postgres, GAMS API) — this
  spec only prepares the library home (specifically `VolOrder.Decode`) they'll build on
  later.
- No fix for the `process`/`cast` dependency liability — noted above, not resolved here.
- No changes to `src/modules/VolOrderManagerMod.plk`, `foundry-scripts/`, or any Solidity
  source.

## Success criteria (what must be TRUE)

1. `offchain/lib/MyLib.hs` no longer exists; `offchain/lib/VolOrder/{Types,Encoding,
   Decode,Report,Rpc}.hs` exist with the module contents and exports described above.
2. `offchain/app/Sample.hs` exists with the `OverloadedStrings` pragma and the three demo
   values; `offchain/app/Main.hs` is exactly the `main = create_order_and_report account
   order_manager sample_order` shape (plus imports) — no domain logic, no `Either`
   handling, no printing.
3. `VolOrder.Decode.decode_order_created` is a pure function (no `IO` in its type) callable
   independently of `VolOrder.Report`.
4. `VolOrder.Rpc.create_order` returns `Web3 (Either RpcError TxReceipt)` and performs no
   printing; `create_order_and_report` is the only function that calls
   `VolOrder.Report.report_receipt`.
5. `cabal build` succeeds cleanly (no warnings) with the `library`/`executable`
   `build-depends` split described above (library gains only `web3-provider`,
   `memory-hexstring`, `process`, `bytestring`, `time`; executable ends up with `base`,
   the library, and `web3-solidity`).
6. `cabal run exe:cfmm-replicationPlank-rpc-api` against a freshly deployed
   `VolOrderManager` on `anvil` produces output with identical field values, in the same
   order, to the pre-refactor `Main.hs`.
