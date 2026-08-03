# Design: `write_price` — a `PriceSetter.*` library mirroring `VolOrder.*`

**Date:** 2026-07-18
**Topic:** Resolve `offchain/todo.md` items 1 ("correct the create_order comments") and 2
(add a minimal `write_price`, same pattern as `create_order`, whose only role is to write a
price to a given address). Adds a `PriceSetter.*` library targeting the now-merged
`PriceSetterHook` contract (PR #11, `develop`), and rewrites `Main.hs` to compose
`create_order` and `write_price` in one `runWeb3'` session.
**Scope track:** rpc_api offchain (Haskell) only. `PriceSetterHook.sol` and
`foundry-scripts/PriceSetterHook.s.sol` are already merged on `develop` (Plank/Solidity
tracks) and are consumed here read-only — nothing under `src/` or `foundry-scripts/`
changes as part of this spec.
**Status:** two-step reviewed (Reality Checker + Solidity Smart Contract Engineer,
matching the pairing the original `PriceSetterHook` design spec used). Four MAJOR
findings folded in below (deploy-order fragility, address-determinism overclaim,
untested error-handling claim, no negative-path verification); two MINORs folded in
(`Sample.hs` export list, `todo.md` not updated). No BLOCKERs — the core protocol
(`eth_call` + `anvil_setStorageAt`, ABI encoding including negative ticks, return
decoding) was independently confirmed correct against the real merged contract and a
live anvil/cast test.

## Ground truth (verified, not assumed)

- **`PriceSetterHook.sol`** (`src/modules/protocol_integrations/PriceSetterHook.sol`,
  `develop@08b3d83`): `IPoolManager public immutable poolManager` (zero-arg getter
  `poolManager()`), `bytes32 public slot0Slot` (zero-arg getter `slot0Slot()`,
  `== bytes32(0)` iff unbound), `function packSlot0For(int24 newTick) external view
  returns (bytes32)` — the exact value to write. A hook **cannot** write `PoolManager`
  storage on-chain via a normal transaction; the only way to move the price is a node
  storage cheat: `setStorageAt(address(poolManager), hook.slot0Slot(),
  hook.packSlot0For(tick))`. This is why `write_price` cannot follow `create_order`'s
  `sendTransaction`-based mechanism, only its *code-shape* (a reusable `Web3 a` action +
  a thin `IO ()` wrapper, calldata-encoded via `cast`).
- **`foundry-scripts/PriceSetterHook.s.sol`** (`develop`, merged after the design
  question above was resolved): deploys `PoolManager` (plain `new PoolManager(...)`,
  nonce-dependent address), CREATE2-mines the hook to a flag-carrying address
  (`BEFORE_INITIALIZE_FLAG | AFTER_INITIALIZE_FLAG`) via `HookMiner.find(...,
  type(PriceSetterHook).creationCode, abi.encode(poolManager))`, and initializes one
  pool bound to it (no liquidity, `tick = 0` initially, `tickSpacing = 60`). Its own doc
  comment confirms the write protocol verbatim: `cast rpc --rpc-url local
  anvil_setStorageAt <PoolManager> <slot> <value>`. It also exposes a read-only
  `tick_payload(address hookAddress, int24 newTick)` entry (`forge script --sig`) that
  prints the exact `(poolManager, slot, value)` triple for a tick without writing
  anything — usable as an independent oracle to cross-check this implementation during
  verification (same role `vm.load` plays in the hook's own test suite).
- **Deploy-order dependency (found in review — not previously flagged).**
  `PriceSetterHookScript` uses the identical deployer as `VolOrderManagerScript`
  (`ANVIL_MNEMONIC`/`DEPLOYER_INDEX = 0`, same mnemonic, same index) — both scripts
  share one deployer's nonce sequence on a given chain. `Main.hs` now runs
  `create_order` (against `VolOrderManager`) and `write_price` (against
  `PriceSetterHook`) together, so whichever script deploys first on a fresh anvil chain
  determines the nonce at which the *other* script's contracts land — `PoolManager`'s
  address is nonce-dependent (plain `CREATE`), and the CREATE2-mined hook address is
  derived from `abi.encode(poolManager)`, so it shifts too if `PoolManager`'s address
  shifts. **This spec fixes the deploy order as an explicit runbook contract**: on a
  fresh chain, always run `foundry-scripts/VolOrderManager.s.sol` first, then
  `foundry-scripts/PriceSetterHook.s.sol` second (this is also the order used during
  this spec's verification — see Testing/Verification). The hardcoded `Sample.hs`
  addresses are only valid for a chain deployed in exactly this order; redeploying out
  of order, or deploying either script twice, invalidates them and requires
  re-capturing.
- **Address determinism is weaker for the hook than for `order_manager`.**
  `order_manager`'s address (`VolOrderManagerScript`, plain `CREATE`) is deterministic
  given only the deployer and nonce — invariant to the contract's compiled bytecode.
  `PriceSetterHook`'s address is CREATE2-mined against
  `type(PriceSetterHook).creationCode`, so it additionally depends on the *exact*
  compiled bytecode: solc version, optimizer settings, and the `--via-ir` flag this
  spec's own verification requires. A future recompile of `PriceSetterHook.sol` under
  different build settings would silently change the mined address and invalidate the
  hardcoded `Sample.hs` value in a way `order_manager` never would — re-capture the
  address from a live deploy any time the build settings or contract source change, not
  just once at implementation time.
- **`Network.Ethereum.Api.Eth.call :: JsonRpc m => Call -> DefaultBlock -> m HexString`**
  (`web3-ethereum`, already a library dependency) — the `eth_call` binding, reused for
  the three read-only calls (`poolManager()`, `slot0Slot()`, `packSlot0For(tick)`).
- **`Network.JsonRpc.TinyClient.remote :: (JsonRpc m, Remote m a) => MethodName -> a`**
  (`jsonrpc-tinyclient`) — the fully generic RPC-method binding `web3-ethereum` itself
  uses internally for every call (e.g. `getTransactionReceipt = remote
  "eth_getTransactionReceipt"`). `instance JsonRpc Web3` already exists
  (`Network.Web3.Provider`), so `remote "anvil_setStorageAt"` typechecks directly against
  `Web3`. **Not** currently a direct library dependency — `Network.Web3.Provider` only
  selectively re-exports `JsonRpc`/`JsonRpcClient`/`defaultSettings`/`jsonRpcManager` from
  `jsonrpc-tinyclient`, not `remote` — so `jsonrpc-tinyclient` must be added to the
  library's `build-depends` to import `remote` directly.
- **`Data.Solidity.Prim.Address.fromHexString :: HexString -> Either String Address`**
  (`web3-solidity`, already a library dependency) — constructs a real `Address` from a
  20-byte `HexString`. Needed because, unlike the `ORDER_CREATED` log owner (display-only,
  where `VolOrder.Decode` deliberately used `HexString` instead of `Address` to dodge
  EIP-55 checksum-casing in `Show`), the `poolManager()` result here is *used* — it's the
  target address of the `anvil_setStorageAt` write — so it must be a real, correctly
  constructed `Address` value, not a display string.
- **`anvil_setStorageAt`'s JSON-RPC return shape is unverified** — Anvil's docs/source
  weren't checked for its exact result type (likely a bare `true`, but not confirmed). To
  avoid a decode failure on an unverified assumption, this design decodes the result as
  a generic `Data.Aeson.Value` (always parses successfully) rather than guessing `Bool`.
  This needs `aeson` added to the library's `build-depends` (already a transitive
  dependency throughout the stack; not currently direct).

## Decisions (from brainstorming)

1. **New namespace `PriceSetter.*`**, not folded into `VolOrder.*` — different on-chain
   domain entirely (a Uniswap v4 hook, unrelated to `VolOrderManager`). Exposed from the
   same library stanza.
2. **No `PriceSetter.Types` module.** `VolOrder.Types` existed because `VolOrder` bundles
   three fields; `write_price`'s only domain input is a single scalar tick. A record
   would be premature abstraction (YAGNI) — the tick is passed as a plain `Integer`.
3. **`write_price` takes only the hook address + tick**, mirroring `create_order`'s
   "caller supplies domain inputs, function hides all plumbing" shape: it resolves
   `poolManager()` and `slot0Slot()` itself via `eth_call` rather than requiring the
   caller to already know them.
4. **`write_price` is a reusable `Web3 a` action, not `IO ()`.** Matches
   `VolOrder.Rpc.create_order`'s established pattern: the action returns its result
   (here, the `(Address, HexString, HexString)` triple it wrote) rather than printing,
   so it composes inside a single `runWeb3'` session with `create_order`.
   `write_price_and_report` is the thin `IO ()` wrapper, exactly mirroring
   `create_order_and_report`.
5. **`Main.hs` runs both actions in one `runWeb3'` session**, resolving the comment left
   on `main` ("this needs to change to create_order only for the signature") — the
   `_and_report` wrappers can't be sequenced together (each opens its own `runWeb3'`
   session against the same node for no reason); composing the bare `Web3`-returning
   actions can. This also fully resolves `todo.md` item 1: the only "create_order
   comment" anywhere in the codebase (verified by grep across `offchain/`) is this one
   placeholder, and it is deleted once `Main.hs` is rewritten to do what it describes.

## Module breakdown

Four new library modules under `offchain/lib/PriceSetter/`, alongside the existing
`VolOrder/` modules (both exposed from the same `library` stanza):

- **`PriceSetter.Encoding`** — `cast calldata`-based builders for the three calls:
  `encode_pool_manager :: IO HexString`, `encode_slot0_slot :: IO HexString`,
  `encode_pack_slot0_for :: Integer -> IO HexString`. Internally shares a small
  `encode_call :: String -> [String] -> IO HexString` helper (DRY within this new module
  only — `VolOrder.Encoding` is not touched, since generalizing it is unrelated
  refactoring outside this spec's scope). **Exports:** the three `encode_*` functions.
- **`PriceSetter.Decode`** — pure: `decode_address :: HexString -> Either String
  Address`, slicing the low 20 bytes off a 32-byte ABI-encoded word (`BS.drop 12 . toBytes`,
  the same slicing already proven in `VolOrder.Decode`) and constructing a real `Address`
  via `fromHexString`. **Exports:** `decode_address`.
- **`PriceSetter.Report`** — thin IO: `report_price_write :: (Address, HexString,
  HexString) -> IO ()`, printing the pool manager address, slot, and packed value that
  were written. **Exports:** `report_price_write`.
- **`PriceSetter.Rpc`** — the orchestration:
  - `write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)` — takes
    the hook address and tick; resolves `poolManager()` (`eth_call` → `decode_address`,
    `fail`-ing via `Web3`'s `MonadFail` on a decode error, the same mechanism
    `wait_for_receipt` already uses), `slot0Slot()`, and `packSlot0For(tick)` (both raw
    32-byte `eth_call` results, no decoding needed — a single-value ABI return **is**
    the 32-byte word, unlike the multi-word `ORDER_CREATED` log data that needed
    `data_word` slicing); calls `remote "anvil_setStorageAt"` with the resolved
    `(poolManager, slot, value)`; returns that triple. No printing.
  - `write_price_and_report :: Address -> Integer -> IO ()` — runs `write_price` via
    `runWeb3'` against `HttpProvider "http://127.0.0.1:8545"`, prints the `Web3Error` on
    `Left` or calls `report_price_write` on `Right`. Exists for standalone use /
    parity with `create_order_and_report`, even though `Main.hs` itself calls the bare
    `write_price` directly (see below).
  - A small internal `eth_call_hook :: Address -> HexString -> Web3 HexString` helper
    builds the `Call` record (`callTo = Just hook`, `callData = Just calldata`, all
    other fields `Nothing`) and calls `GlobalState.call call_record Latest`.
  - **Exports:** `write_price`, `write_price_and_report`.

## `Main.hs` and `Sample.hs`

`Sample.hs` gains two values, captured from a real deploy on a chain seeded in the fixed
order documented above (VolOrderManager first, PriceSetterHook second — see Ground
truth): a hardcoded `price_setter_hook :: Address` (the hook address printed by
`foundry-scripts/PriceSetterHook.s.sol`'s `run()`) and `sample_tick :: Integer` (a
nonzero demo tick, e.g. `60` — matching the pool's `tickSpacing` — chosen so the demo
visibly moves state away from the script's initial `tick = 0`). `Sample.hs`'s existing
explicit export list, `(account, order_manager, sample_order)`, must be extended to
`(account, order_manager, price_setter_hook, sample_order, sample_tick)` — otherwise
`Main.hs`'s import of the two new names fails to compile.

`Main.hs` becomes:

```haskell
module Main where

import Sample (account, order_manager, price_setter_hook, sample_order, sample_tick)
import VolOrder.Report (report_receipt)
import VolOrder.Rpc (create_order)
import PriceSetter.Report (report_price_write)
import PriceSetter.Rpc (write_price)
import Network.Web3.Provider (Provider (HttpProvider), runWeb3')

main :: IO ()
main = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (do receipt <- create_order account order_manager sample_order
          written <- write_price price_setter_hook sample_tick
          pure (receipt, written))

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right (receipt, written) -> do
      report_receipt receipt
      report_price_write written
```

`create_order_and_report` remains exported from `VolOrder.Rpc` (unused by `Main` now, but
not removed — it's a legitimate standalone entry point other future callers may still
want, exactly like `write_price_and_report`). The stale comment on `main` is deleted as
part of this rewrite.

`offchain/todo.md` is updated in the same change to mark both items resolved (matching
this branch's existing convention of annotating completed items in place, e.g. `todo.md`
item 1's `(done:: ...)` suffix from the earlier `VolOrder` extraction work), so the todo
file doesn't drift out of sync with what's actually shipped.

## Cabal changes

`library` stanza:
- `exposed-modules` gains `PriceSetter.Encoding, PriceSetter.Decode, PriceSetter.Report,
  PriceSetter.Rpc`.
- `build-depends` gains `jsonrpc-tinyclient` (for `remote`, not currently direct — see
  Ground truth) and `aeson` (for decoding `anvil_setStorageAt`'s result as a generic
  `Value` — also not currently direct). No other new dependencies: `web3-ethereum`,
  `web3-solidity`, `web3-provider`, `memory-hexstring`, `process`, `bytestring` already
  cover everything else `PriceSetter.*` needs.

`executable` stanza: `build-depends` gains `web3-provider` — `Main.hs` now directly
imports `Provider`/`runWeb3'` to compose the two `Web3` actions itself (see `Main.hs`
above), so the executable needs that package directly, not just transitively through the
library. `base`, `cfmm-replicationPlank-rpc-api`, and `web3-solidity` (already present,
needed for `Address` in `Sample.hs`) are unchanged.

## Error handling

`write_price`'s only realistic on-chain failure mode is `NotBound` (the `onlyBound`
modifier gating `readSlot0`, which `packSlot0For` calls internally) — if `price_setter_hook`
ever pointed at an unbound hook (wrong address, or a hook whose pool was never
initialized), `packSlot0For(tick)`'s `eth_call` reverts. (`WrongPool` and
`SlotVerificationFailed` are *not* reachable from `write_price` — both only fire inside
`beforeInitialize`/`afterInitialize`, i.e. during pool creation, which `write_price`
never calls; an earlier draft of this spec incorrectly listed `WrongPool` here.)

**How that failure actually surfaces is not fully verified, and this spec says so
explicitly rather than assuming the `VolOrder` precedent transfers cleanly.**
`Network.JsonRpc.TinyClient.remote` throws JSON-RPC-level failures as
`JsonRpcException` via `MonadThrow`, but `runWeb3'`'s implementation is `liftIO . try
. ...` where `try :: Exception e => IO a -> IO (Either e a)` is pinned to `e ~
Web3Error` by `runWeb3'`'s own type signature (`m (Either Web3Error a)`). `try`
constrained to one exception type does not catch a *different* exception type — so a
real `eth_call` revert propagating as `JsonRpcException` could come out as an uncaught
exception (crashing the process) rather than `runWeb3'`'s `Left`. This is **inherited,
pre-existing behavior**, not something `write_price` introduces — `create_order`'s own
`sendTransaction`/`getTransactionReceipt` calls go through the identical `remote`
mechanism and would have the same exposure — but neither this spec nor the `VolOrder`
work that preceded it has ever actually triggered a real revert to observe which
behavior occurs. See Testing/Verification step 6 below, added specifically to close this
gap empirically rather than leave it asserted.

**Liquidity-coherence precondition (caller obligation, not enforced by the type
system).** Per `PriceSetterHook.sol`'s own doc comment, a `slot0` write is only coherent
for pools with no liquidity or full-range-only liquidity — an imposed tick crossing an
initialized interior tick leaves liquidity/fee accounting stale. `write_price` has no
way to check this on-chain (it isn't the hook's job either); `PriceSetter.Rpc`'s
`write_price` documentation must restate this as a caller obligation, matching what the
deploy script's own pool (no liquidity, by construction) satisfies today.

## Testing / verification

No unit test framework exists in this project (same as the `VolOrder` extraction). This
is new functionality (unlike that refactor), so verification is a real, live run against
a freshly deployed rig rather than a smoke test:

1. `cabal build` succeeds with the new modules and no `-Wall` warnings.
2. Start `anvil` fresh. Deploy in the fixed order documented above: first `forge script
   foundry-scripts/VolOrderManager.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
   --ffi --via-ir` (confirm `order_manager` lands at the existing hardcoded
   `Sample.hs` address — if it doesn't, the deploy order or chain state is wrong, stop
   and fix before continuing), then `forge script foundry-scripts/PriceSetterHook.s.sol
   --rpc-url http://127.0.0.1:8545 --broadcast --ffi --via-ir`, capturing the printed
   `PoolManager`, `PriceSetterHook`, initial `tick` (expect `0`), and `slot0Slot`.
3. Independently compute the expected write via the script's own oracle:
   `forge script foundry-scripts/PriceSetterHook.s.sol --sig "tick_payload(address,int24)"
   <hookAddress> <sampleTick> --rpc-url http://127.0.0.1:8545` and record its printed
   `(poolManager, slot, value)`.
4. Run `cabal run exe:cfmm-replicationPlank-rpc-api`; confirm `write_price`'s printed
   `poolManager`/`slot`/`value` match step 3's independently computed values exactly, and
   that `create_order`'s receipt/log output is unchanged in shape from the existing
   `VolOrder` behavior (still prints `ORDER_CREATED` fields correctly).
5. Confirm the write actually landed: `cast storage <PoolManager> <slot0Slot> --rpc-url
   http://127.0.0.1:8545` (or `hook.readTick()` via `cast call`) shows the new tick, not
   the script's initial `0`.
6. **Negative-path check (closes the Error Handling gap above).** Deliberately call
   `write_price` (e.g. via `cabal repl`) with a hook address that is *not* bound — any
   address with no deployed `PriceSetterHook` code, or a freshly-`deployCodeTo`'d hook
   whose pool was never initialized — and observe what actually happens: does the
   process crash with an uncaught `JsonRpcException`, or does it come back as
   `runWeb3'`'s `Left`? Record the observed behavior in the implementation (a code
   comment on `write_price`, not a spec amendment) rather than leaving the Error
   Handling section's claim unverified.

## Out of scope (explicit)

- No changes to `PriceSetterHook.sol` or `foundry-scripts/PriceSetterHook.s.sol` — both
  already merged and treated as a frozen, read-only interface here.
- No changes to `VolOrder.Encoding`'s `encode_create_order`/`trim`, even though
  `PriceSetter.Encoding` duplicates a similar `cast calldata` shape — unifying them is an
  unrelated refactor, not required by this feature.
- No generalized "any RPC error handling" abstraction — `write_price` and `create_order`
  each surface failures the same way they already did individually; only `Main`'s
  `runWeb3'` composition is new.
- No stochastic tick-driver / repeated `write_price` loop — `todo.md` item 2 asks for the
  minimal single-call function; a driver loop is future scope, not this spec.

## Success criteria (what must be TRUE)

1. `offchain/lib/PriceSetter/{Encoding,Decode,Report,Rpc}.hs` exist with the exports
   described above; `PriceSetter.Decode.decode_address` has no `IO` in its type.
2. The stale `create_order` comment on `main` is gone (`grep -rn "this needs to change"
   offchain/` finds nothing), and `offchain/todo.md` marks both items 1 and 2 resolved.
3. `Main.hs` runs `create_order` and `write_price` inside one `runWeb3'` call as shown
   above, with a single `Left`/`Right` match reporting both on success.
4. `Sample.hs`'s export list includes `price_setter_hook` and `sample_tick` alongside
   the existing three names.
5. `cabal build` succeeds cleanly (no warnings) with the cabal diff described above
   (library gains `jsonrpc-tinyclient` and `aeson`; executable gains `web3-provider`).
6. A live run — chain deployed in the fixed order (`VolOrderManager.s.sol` then
   `PriceSetterHook.s.sol`) — shows `write_price`'s written `(poolManager, slot, value)`
   exactly matching the script's own `tick_payload`-computed values, and the storage
   write is independently confirmed via `cast storage`/`hook.readTick()`.
7. The negative-path check (Testing/Verification step 6) has been run at least once and
   its observed behavior (crash vs. `Left`) is recorded as a comment on `write_price`.
