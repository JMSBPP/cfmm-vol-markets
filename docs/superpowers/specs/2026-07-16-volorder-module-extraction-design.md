# Design: Extract `Main.hs` into a `VolOrder` library

**Date:** 2026-07-16
**Topic:** Refactor `offchain/app/Main.hs` — currently a single ~140-line module mixing
domain types, config constants, calldata encoding, RPC send/poll orchestration, and
receipt/log decoding/reporting — into a small `VolOrder.*` library plus a thin `Main`.
**Scope track:** rpc_api offchain (Haskell) — no GAMS, Lean4, Plank `.plk`, or Foundry test
files touched.
**Status:** approved design, behavior-preserving refactor (no new functionality).

## Motivation

`Main.hs` currently does everything: it defines the `VolOrder` domain type, the demo
account/manager addresses, calldata encoding via a `cast` subprocess, transaction
submission + bounded receipt polling, and receipt/log reporting (including low-level
hex/byte decoding for the `ORDER_CREATED` event). Nothing else in the project imports it —
the project's actual library (`exposed-modules: MyLib` in the `.cabal` file) is an unused
stub (`someFunc = putStrLn "someFunc"`).

`todo.md` items 2–9 (live event subscription, an `EventQueue`, Postgres integration, a
Haskell↔GAMS API) will all need the same `VolOrder` type and the same log-decoding logic
`Main.hs` already has. Left as-is, that code would either get duplicated per new module or
force this exact extraction later, under more time pressure. This refactor does it now,
while the surface is small, and leaves `Main.hs` as the thinnest possible entry point.

## Decisions (from brainstorming)

1. **Promote to the library, not just multiple executable-only modules.** Reusable pieces
   move into `offchain/lib/`, replacing the `MyLib` stub, so they are available as a real
   library dependency to future executables/modules (subscription listener, event queue,
   etc.) without re-extraction.
2. **Hierarchical namespace `VolOrder.*`** (not flat `Types`/`Encoding`/`Rpc`/`Report`
   modules at the library root) — scales better as more modules get added for the
   subscription/queue/DB work in later todo items.
3. **Thinnest possible `Main`.** The demo values (`account`, `order_manager`,
   `sample_order`) move into the library too, as `VolOrder.Sample`. `Main.hs` only imports
   `VolOrder.Sample` and `VolOrder.Rpc.create_order` and calls
   `main = create_order account order_manager sample_order` — it never touches the
   `Either`/`Web3` machinery directly.

## Module breakdown

All five new modules live under `offchain/lib/VolOrder/`, replacing
`offchain/lib/MyLib.hs`.

- **`VolOrder.Types`** — the `VolOrder` domain record: `vol_target`, `range_width`, `skew`
  (all `Quantity`).
- **`VolOrder.Encoding`** — `encode_create_order :: VolOrder -> IO HexString` (the
  `cast calldata create_order(uint88,uint24,uint16) ...` subprocess call) and the `trim`
  helper it uses.
- **`VolOrder.Report`** — everything receipt/log-shaped and its supporting decode helpers:
  `report_receipt`, `status_text`, `report_log`, `report_order_created`,
  `hex_to_integer`, `data_word`, `be_integer`, and the `topic_order_created` constant
  (`0xa8892769`, matching `TOPIC_ORDER_CREATED` in
  `src/modules/VolOrderManagerMod.plk`) they decode against.
- **`VolOrder.Rpc`** — the orchestration: `create_order` (builds the `Call`, calls
  `sendTransaction`, awaits the receipt via `wait_for_receipt`, and — on `Right` — hands the
  `TxReceipt` to `VolOrder.Report.report_receipt`; on `Left`, prints the RPC error) and
  `wait_for_receipt` (the bounded ~10s / 200ms-interval poll loop over
  `GlobalState.getTransactionReceipt`). This module is `Main`'s only entry point.
- **`VolOrder.Sample`** — the concrete demo values: `account`, `order_manager`,
  `sample_order`.

`offchain/app/Main.hs` shrinks to:

```haskell
module Main where

import VolOrder.Sample (account, order_manager, sample_order)
import VolOrder.Rpc (create_order)

main :: IO ()
main = create_order account order_manager sample_order
```

## Data flow

Unchanged from the current implementation — only the code's location moves:
`VolOrder.Sample` values flow into `VolOrder.Rpc.create_order`, which calls
`VolOrder.Encoding.encode_create_order` to build calldata, submits the transaction, polls
for the receipt via `wait_for_receipt`, and passes the resulting `TxReceipt` to
`VolOrder.Report.report_receipt`, which prints status/block/from/to/gas and decodes any
`ORDER_CREATED` log (owner, UTC timestamp, `vol_target`, `range_width`, `skew`) using the
`hex_to_integer`/`data_word`/`be_integer` helpers.

## Cabal changes

In `cfmm-replicationPlank-rpc-api.cabal`:

- **`library` stanza:** `exposed-modules` changes from `MyLib` to `VolOrder.Types,
  VolOrder.Encoding, VolOrder.Report, VolOrder.Rpc, VolOrder.Sample`. `build-depends` gains
  everything those modules need: `web3-provider`, `web3-solidity`, `web3-ethereum`,
  `memory-hexstring`, `process`, `bytestring`, `time` (moved from the executable stanza,
  since the library now owns this code).
- **`executable` stanza:** `build-depends` shrinks to `base` + the library
  (`cfmm-replicationPlank-rpc-api`) only — it no longer needs any of the above directly,
  since `Main.hs` only calls library functions.
- `offchain/lib/MyLib.hs` is deleted (its one export, `someFunc`, is unused dead code with
  no callers anywhere in the repo).

## Error handling

Preserved exactly as today: `VolOrder.Rpc.create_order` pattern-matches the
`Either RpcError TxReceipt` from `runWeb3'` itself (`Left` → prints the RPC error, `Right`
→ calls `report_receipt`). `Main` never sees the `Either` — this is what "thinnest Main"
means per the approved design. `wait_for_receipt`'s bounded-retry `fail` on exhaustion is
unchanged.

## Testing / verification

This is a behavior-preserving move, not new functionality — no new tests are in scope.
Verification is:

1. `cabal build` succeeds with the new module layout and no `-Wall` warnings.
2. Re-run the same manual end-to-end check used when `Main.hs`'s receipt reporting was
   first built: start `anvil`, deploy `VolOrderManager` via
   `forge script foundry-scripts/VolOrderManager.s.sol --broadcast --ffi --via-ir`, then
   `cabal run exe:cfmm-replicationPlank-rpc-api` and confirm the printed receipt/log output
   is byte-for-byte the same shape as before the refactor (tx hash, status, block, from/to,
   gas, decoded `ORDER_CREATED` fields).

## Out of scope (explicit)

- No behavior changes to the RPC calls, polling interval/bound, or the printed report
  format — this is a pure code-motion refactor.
- No new modules for todo items 2–9 (subscription, `EventQueue`, Postgres, GAMS API) — this
  spec only prepares the library home they'll land in later.
- No changes to `src/modules/VolOrderManagerMod.plk`, `foundry-scripts/`, or any Solidity
  source.

## Success criteria (what must be TRUE)

1. `offchain/lib/MyLib.hs` no longer exists; `offchain/lib/VolOrder/{Types,Encoding,
   Report,Rpc,Sample}.hs` exist with the module contents described above.
2. `offchain/app/Main.hs` is exactly the four-line `main = create_order account
   order_manager sample_order` shape (plus imports) — no domain logic, no `Either`
   handling, no printing.
3. `cabal build` succeeds cleanly (no warnings) with the `library`/`executable`
   `build-depends` split described above.
4. `cabal run exe:cfmm-replicationPlank-rpc-api` against a freshly deployed
   `VolOrderManager` on `anvil` produces the same receipt/log report as the
   pre-refactor `Main.hs` did.
