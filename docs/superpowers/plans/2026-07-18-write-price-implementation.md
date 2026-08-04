# write_price / PriceSetter Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `PriceSetter.*` library mirroring `VolOrder.*`'s structure that exposes
`write_price` (submit a tick to the merged `PriceSetterHook` via `eth_call` + the
`anvil_setStorageAt` node cheat), rewrite `Main.hs` to run `create_order` and
`write_price` in one `runWeb3'` session, and resolve both `offchain/todo.md` items.

**Architecture:** Four new library modules
(`offchain/lib/PriceSetter/{Encoding,Decode,Report,Rpc}.hs`) built bottom-up with a
cabal/build check after each, mirroring how `VolOrder.*` was built. `write_price`
resolves `poolManager()`/`slot0Slot()`/`packSlot0For(tick)` via three `eth_call`s, then
writes via `remote "anvil_setStorageAt"` — no `sendTransaction` involved, since a hook
cannot write `PoolManager` storage through a normal transaction. `Sample.hs` gets a
`price_setter_hook` address captured from a real, fixed-order deploy
(`VolOrderManager.s.sol` then `PriceSetterHook.s.sol`) rather than guessed.

**Tech Stack:** Haskell (GHC 9.10.3, `Haskell2010`), Cabal 3.12, `hs-web3` family
(`web3-provider`, `web3-solidity`, `web3-ethereum`, `jsonrpc-tinyclient` — new),
`memory-hexstring`, `aeson` (new), `process`, `bytestring`.

## Global Constraints

- Package: `cfmm-replicationPlank-rpc-api`, `base ^>=4.20.2.0`, `cabal-version: 3.12`,
  `default-language: Haskell2010`. Toolchain: GHC 9.10.3.
- Every stanza uses `import: warnings` (`-Wall`) — **zero warnings** required after every
  build check in this plan.
- `write_price`'s only reachable on-chain failure is `NotBound` (via `packSlot0For`'s
  internal `onlyBound` gate) — `WrongPool`/`SlotVerificationFailed` are **not** reachable
  from `write_price` (those only fire from `beforeInitialize`/`afterInitialize`).
- Deploy order is a hard constraint: `foundry-scripts/VolOrderManager.s.sol` **must**
  deploy before `foundry-scripts/PriceSetterHook.s.sol` on a given chain — both scripts
  share one deployer (`ANVIL_MNEMONIC`/`DEPLOYER_INDEX = 0`), so out-of-order or repeated
  deploys shift both scripts' addresses.
- Spec: `docs/superpowers/specs/2026-07-18-write-price-design.md` (two-step reviewed:
  Reality Checker + Solidity Smart Contract Engineer; this plan implements the
  post-review version, including the negative-path verification step and the
  documented `try`-vs-`JsonRpcException` uncertainty).

---

### Task 1: `PriceSetter.Encoding` — calldata builders

**Files:**
- Create: `offchain/lib/PriceSetter/Encoding.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`; `memory-hexstring` and `process` are already present from the
  `VolOrder` work)

**Interfaces:**
- Produces: `encode_pool_manager :: IO HexString`, `encode_slot0_slot :: IO HexString`,
  `encode_pack_slot0_for :: Integer -> IO HexString`. Task 4 (`PriceSetter.Rpc`) calls
  all three.

- [ ] **Step 1: Create `PriceSetter.Encoding`**

```haskell
module PriceSetter.Encoding
  ( encode_pool_manager
  , encode_slot0_slot
  , encode_pack_slot0_for
  ) where

import Data.ByteArray.HexString (HexString)
import Data.String (fromString)
import System.Process (readProcess)

encode_pool_manager :: IO HexString
encode_pool_manager = encode_call "poolManager()" []

encode_slot0_slot :: IO HexString
encode_slot0_slot = encode_call "slot0Slot()" []

encode_pack_slot0_for :: Integer -> IO HexString
encode_pack_slot0_for tick = encode_call "packSlot0For(int24)" [show tick]

encode_call :: String -> [String] -> IO HexString
encode_call signature args = do
  raw <- readProcess "cast" ("calldata" : signature : args) ""
  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words
```

- [ ] **Step 2: Update the cabal library stanza**

Add the module to `exposed-modules` (no `build-depends` change this task):

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/wp-task1-build.log
grep -i warning /tmp/wp-task1-build.log || echo "no warnings"
```

Expected: build succeeds; "no warnings" printed.

- [ ] **Step 4: Sanity-check the negative-tick encoding**

```bash
cast calldata "packSlot0For(int24)" -60
```

Expected: a `0x` selector followed by `fffff...fc4` (two's-complement sign extension of
`-60`) — confirms `cast` handles negative `int24` literals correctly before `write_price`
relies on it in Task 4.

- [ ] **Step 5: Commit**

```bash
git add offchain/lib/PriceSetter/Encoding.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add PriceSetter.Encoding calldata builders"
```

---

### Task 2: `PriceSetter.Decode` — pure address decoding

**Files:**
- Create: `offchain/lib/PriceSetter/Decode.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`; `web3-solidity`, `memory-hexstring`, `bytestring` already present)

**Interfaces:**
- Produces: `decode_address :: HexString -> Either String Address`. Task 4
  (`PriceSetter.Rpc`) calls this on the `poolManager()` `eth_call` result.

This is the module a future caller reuses if it ever needs to decode another
address-shaped `eth_call` result — deliberately pure, no `IO`, matching
`VolOrder.Decode`'s discipline.

- [ ] **Step 1: Create `PriceSetter.Decode`**

```haskell
module PriceSetter.Decode
  ( decode_address
  ) where

import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Solidity.Prim.Address (Address, fromHexString)

-- ABI-encoded address return values are right-aligned in a 32-byte word,
-- left-padded with 12 zero bytes.
decode_address :: HexString -> Either String Address
decode_address raw = fromHexString (fromBytes (BS.drop 12 (toBytes raw)))
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/wp-task2-build.log
grep -i warning /tmp/wp-task2-build.log || echo "no warnings"
```

- [ ] **Step 4: Smoke-test the decoder in `cabal repl`**

This reuses the exact same 32-byte address-padded word already verified in the
`VolOrder.Decode` plan's smoke test (`account`'s address, zero-padded to 32 bytes):

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import PriceSetter.Decode
import Data.ByteArray.HexString (HexString)
let padded_word = "0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8" :: HexString
decode_address padded_word
:quit
EOF
```

Expected: `Right "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"` — the checksummed form of
`account`'s address from `Sample.hs` (confirming the 12-byte-drop slicing recovers the
correct 20 bytes, and `fromHexString` constructs a real `Address` whose `Show` instance
checksum-cases it, matching the address already used elsewhere in this project).

- [ ] **Step 5: Commit**

```bash
git add offchain/lib/PriceSetter/Decode.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add pure eth_call address decoding in PriceSetter.Decode"
```

---

### Task 3: `PriceSetter.Report` — thin IO formatting

**Files:**
- Create: `offchain/lib/PriceSetter/Report.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`)

**Interfaces:**
- Produces: `report_price_write :: (Address, HexString, HexString) -> IO ()`. Task 4's
  `write_price_and_report` calls this.

- [ ] **Step 1: Create `PriceSetter.Report`**

```haskell
module PriceSetter.Report
  ( report_price_write
  ) where

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

report_price_write :: (Address, HexString, HexString) -> IO ()
report_price_write (pool_manager, slot, value) = do
  putStrLn "price   WRITTEN"
  putStrLn ("  poolManager " ++ show pool_manager)
  putStrLn ("  slot        " ++ show slot)
  putStrLn ("  value       " ++ show value)
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
                    , PriceSetter.Report
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/wp-task3-build.log
grep -i warning /tmp/wp-task3-build.log || echo "no warnings"
```

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/PriceSetter/Report.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add PriceSetter.Report IO formatting"
```

---

### Task 4: `PriceSetter.Rpc` — orchestration (eth_call + anvil_setStorageAt)

**Files:**
- Create: `offchain/lib/PriceSetter/Rpc.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `build-depends` gains
  `jsonrpc-tinyclient` and `aeson` — both new; `exposed-modules` gains the module)

**Interfaces:**
- Consumes: `encode_pool_manager`, `encode_slot0_slot`, `encode_pack_slot0_for` (Task 1);
  `decode_address` (Task 2); `report_price_write` (Task 3).
- Produces: `write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)`
  (no printing — reusable); `write_price_and_report :: Address -> Integer -> IO ()`.
  Task 5's `Main.hs` calls `write_price` directly.

`write_price` never calls `sendTransaction` — a hook cannot write `PoolManager` storage
via a normal transaction. It resolves `poolManager()`/`slot0Slot()`/`packSlot0For(tick)`
via three `eth_call`s, then writes via the JSON-RPC method `anvil_setStorageAt`, a node
storage cheat bound with `Network.JsonRpc.TinyClient.remote` — the exact same generic
mechanism `web3-ethereum` itself uses internally for every RPC call (e.g.
`getTransactionReceipt = remote "eth_getTransactionReceipt"`).

**A known, documented limitation this task does not fix:** `runWeb3'`'s `try` is typed
to catch only `Web3Error`, but `remote` throws JSON-RPC-level failures as
`JsonRpcException` (a different exception type) via `MonadThrow`. A real `eth_call`
revert (e.g. `NotBound`) might therefore propagate as an uncaught exception rather than
surface as `runWeb3'`'s `Left`. This is inherited from `create_order`'s existing use of
the same `remote` mechanism, not introduced here. Task 6's negative-path check observes
which behavior actually occurs.

- [ ] **Step 1: Create `PriceSetter.Rpc`**

```haskell
{-# LANGUAGE OverloadedStrings #-}

module PriceSetter.Rpc
  ( write_price
  , write_price_and_report
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (Value)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Ethereum.Api.Types (Call (..), DefaultBlock (Latest))
import Network.JsonRpc.TinyClient (remote)
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import PriceSetter.Decode (decode_address)
import PriceSetter.Encoding
  ( encode_pack_slot0_for
  , encode_pool_manager
  , encode_slot0_slot
  )
import PriceSetter.Report (report_price_write)

-- write_price's only reachable on-chain failure is NotBound (via packSlot0For's
-- internal onlyBound gate on readSlot0) if price_setter_hook is unbound or wrong.
-- write_price only ever reads via eth_call plus the anvil_setStorageAt node cheat;
-- it never calls sendTransaction, since a hook cannot write PoolManager storage
-- through a normal transaction.
--
-- Caller obligation (not enforced here, per PriceSetterHook.sol's own doc comment):
-- a slot0 write is only coherent for pools with no liquidity or full-range-only
-- liquidity. Do not call this against a hook bound to a pool with interior
-- initialized-tick liquidity -- an imposed tick crossing such a boundary leaves
-- liquidity/fee accounting stale.
write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)
write_price hook tick = do
  pool_manager_raw <- eth_call_hook hook =<< liftIO encode_pool_manager
  pool_manager <- either fail pure (decode_address pool_manager_raw)

  slot <- eth_call_hook hook =<< liftIO encode_slot0_slot
  value <- eth_call_hook hook =<< liftIO (encode_pack_slot0_for tick)

  _ <- anvil_set_storage_at pool_manager slot value
  pure (pool_manager, slot, value)

eth_call_hook :: Address -> HexString -> Web3 HexString
eth_call_hook hook calldata =
  GlobalState.call
    Call
      { callFrom = Nothing
      , callTo = Just hook
      , callGas = Nothing
      , callGasPrice = Nothing
      , callValue = Nothing
      , callData = Just calldata
      , callNonce = Nothing
      }
    Latest

anvil_set_storage_at :: Address -> HexString -> HexString -> Web3 Value
anvil_set_storage_at = remote "anvil_setStorageAt"

write_price_and_report :: Address -> Integer -> IO ()
write_price_and_report hook tick = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (write_price hook tick)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right written    -> report_price_write written
```

- [ ] **Step 2: Update the cabal library stanza**

```cabal
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
                    , PriceSetter.Encoding
                    , PriceSetter.Decode
                    , PriceSetter.Report
                    , PriceSetter.Rpc

    -- Other library packages from which modules are imported.
    build-depends:    base ^>=4.20.2.0,
                      web3-ethereum,
                      web3-solidity,
                      web3-provider,
                      memory-hexstring,
                      process,
                      bytestring,
                      time,
                      jsonrpc-tinyclient,
                      aeson
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/wp-task4-build.log
grep -i warning /tmp/wp-task4-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings. At this point the full library (all `VolOrder.*`
and `PriceSetter.*` modules) builds; the executable still runs the old `Main.hs`.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/PriceSetter/Rpc.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add PriceSetter.Rpc (eth_call + anvil_setStorageAt orchestration)"
```

---

### Task 5: Wire up `Sample.hs`, `Main.hs`, `todo.md`, and the executable stanza

**Files:**
- Modify: `offchain/app/Sample.hs` (add `price_setter_hook`, `sample_tick`)
- Modify: `offchain/app/Main.hs` (full replacement)
- Modify: `offchain/todo.md` (mark items 1–2 resolved)
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (executable `build-depends` gains
  `web3-provider`)

**Interfaces:**
- Consumes: `create_order` (`VolOrder.Rpc`), `report_receipt` (`VolOrder.Report`),
  `write_price` (Task 4), `report_price_write` (Task 3).
- Produces: nothing further downstream — Task 6 verifies this task's output live.

This task needs a **real** `price_setter_hook` address, captured from a live deploy in
the fixed order (`VolOrderManager.s.sol` first, `PriceSetterHook.s.sol` second) — do not
guess or reuse an address from any other source; the CREATE2-mined hook address depends
on the exact deployer nonce sequence and compiled bytecode at deploy time.

- [ ] **Step 1: Check for an already-running anvil node**

```bash
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
```

If this returns an `anvil/...` result, **stop and start fresh** — this task's addresses
depend on a chain deployed in the fixed order from genesis. Kill any running anvil
(`pkill anvil` or the specific PID) before continuing, unless you can independently
confirm the currently-running chain was itself seeded via
`VolOrderManager.s.sol` → `PriceSetterHook.s.sol` in that exact order with no other
transactions in between.

- [ ] **Step 2: Start a fresh anvil**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
anvil --silent > /tmp/wp-anvil.log 2>&1 &
sleep 2
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
```

Expected: an `anvil/vX.Y.Z` result.

- [ ] **Step 3: Deploy `VolOrderManager.s.sol` first**

```bash
forge script foundry-scripts/VolOrderManager.s.sol \
  --rpc-url http://127.0.0.1:8545 --broadcast --ffi --via-ir 2>&1 | tail -15
```

Expected: `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.` Then confirm it landed at the
address already hardcoded in `Sample.hs`:

```bash
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x5FbDB2315678afecb367f032d93F642f64180aa3","latest"]}'
```

Expected: a non-`"0x"` `result`. If it's `"0x"`, the deploy failed or landed elsewhere —
stop and investigate before continuing (a wrong `order_manager` address here means
Task 6's `create_order` half of `Main.hs` will fail too).

- [ ] **Step 4: Deploy `PriceSetterHook.s.sol` second**

```bash
forge script foundry-scripts/PriceSetterHook.s.sol \
  --rpc-url http://127.0.0.1:8545 --broadcast --ffi --via-ir 2>&1 | tail -20
```

Expected output includes four `console.log` lines:
```
PoolManager     : 0x...
PriceSetterHook : 0x...
tick            : 0
slot0Slot       : 0x...
```

Record the `PriceSetterHook` address exactly as printed — this is what goes into
`Sample.hs` in Step 5. (`PoolManager` and `slot0Slot` are not needed in `Sample.hs`;
`write_price` resolves both itself via `eth_call`.)

- [ ] **Step 5: Update `offchain/app/Sample.hs`**

Replace `<hookAddressFromStep4>` below with the exact address recorded in Step 4:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_tick
  ) where

import Data.Solidity.Prim.Address (Address)

import VolOrder.Types (VolOrder (..))

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

price_setter_hook :: Address
price_setter_hook = "<hookAddressFromStep4>"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }

-- Nonzero and a multiple of the deployed pool's tickSpacing (60), so the demo
-- visibly moves state away from PriceSetterHookScript's initial tick = 0.
sample_tick :: Integer
sample_tick = 60
```

- [ ] **Step 6: Replace `offchain/app/Main.hs` entirely**

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

- [ ] **Step 7: Update `offchain/todo.md`**

```markdown
1. Correct the create_order comments (done:: stale placeholder comment on Main.hs's
   `main` resolved by composing create_order/write_price in one runWeb3' session)
2. We need a minimal funciton named write_price and using the same pattern as create_order it abstracst all the implementation adn onyl role is to write a price to a given address (done:: PriceSetter.Rpc.write_price)
```

- [ ] **Step 8: Update the cabal executable stanza**

`Main.hs` now directly imports `Provider`/`runWeb3'`, so the executable needs
`web3-provider` directly (not just transitively through the library):

```cabal
executable cfmm-replicationPlank-rpc-api
    import:           warnings
    main-is:          Main.hs
    other-modules:    Sample
    build-depends:
        base ^>=4.20.2.0,
        cfmm-replicationPlank-rpc-api,
        web3-solidity,
        web3-provider
    hs-source-dirs:   offchain/app
    default-language: Haskell2010
```

- [ ] **Step 9: Build the whole package and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/wp-task5-build.log
grep -i warning /tmp/wp-task5-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings. **Leave the anvil node from Step 2 running** —
Task 6 reuses this exact already-deployed, already-bound chain rather than redeploying.

- [ ] **Step 10: Commit**

```bash
git add offchain/app/Sample.hs offchain/app/Main.hs offchain/todo.md \
  cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: wire up write_price in Main.hs, resolve todo.md items 1-2"
```

---

### Task 6: End-to-end verification (including the negative-path check)

**Files:** none (verification only).

**Interfaces:** none.

Uses the anvil node and deployed rig from Task 5 — do not redeploy unless it was
stopped, in which case repeat Task 5 Steps 1–4 first (fresh chain, same fixed order)
before continuing here.

- [ ] **Step 1: Independently compute the expected write via the deploy script's own oracle**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
forge script foundry-scripts/PriceSetterHook.s.sol \
  --sig "tick_payload(address,int24)" <hookAddressFromTask5Step4> 60 \
  --rpc-url http://127.0.0.1:8545 2>&1 | tail -10
```

Expected output includes:
```
PoolManager     : 0x...
tick            : 60
slot            : 0x...
value           : 0x...
```

Record the `PoolManager`/`slot`/`value` triple — this is what `write_price` must produce.

- [ ] **Step 2: Run the executable**

```bash
cabal run -v0 exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/wp-task6-run.log
```

Expected: the `create_order` receipt block (unchanged shape from the existing `VolOrder`
behavior — `tx`/`status`/`block`/`from`/`to`/`gas`/`ORDER_CREATED` log fields), followed
by:
```
price   WRITTEN
  poolManager 0x...
  slot        0x...
  value       0x...
```

- [ ] **Step 3: Confirm the printed values match Step 1's independent computation**

```bash
grep -E "poolManager|slot |value" /tmp/wp-task6-run.log
```

Expected: the `poolManager`, `slot`, and `value` lines match Step 1's recorded values
exactly (`poolManager`/`slot` match byte-for-byte; `value` matches byte-for-byte since
both come from the identical `packSlot0For(60)` computation on the same chain state).

- [ ] **Step 4: Confirm the write actually landed on-chain**

```bash
cast call <hookAddressFromTask5Step4> "readTick()(int24)" --rpc-url http://127.0.0.1:8545
```

Expected: `60` — not the script's initial `0`.

- [ ] **Step 5: Negative-path check — observe the actual failure behavior**

Call `write_price` against a hook address with no deployed code (any address that was
never used by `PriceSetterHookScript`, e.g. `0x0000000000000000000000000000000000dEaD`)
and record whether the process crashes or returns `Left`:

```bash
cabal repl exe:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import PriceSetter.Rpc (write_price_and_report)
write_price_and_report "0x000000000000000000000000000000000000dEaD" 60
:quit
EOF
```

Expected: one of two outcomes — either a printed `rpc error: ...` line (confirms
`runWeb3'`'s `Left` catches it, i.e. `NotBound`/`eth_call` failures surface as
`Web3Error` after all), or an uncaught exception / GHCi error trace (confirms the
`try`-vs-`JsonRpcException` type-mismatch risk flagged in the spec is real). Either way,
this is a genuine observation, not a pass/fail gate — record which one occurred.

- [ ] **Step 6: Record the observed negative-path behavior as a code comment**

Add one line above `write_price`'s type signature in
`offchain/lib/PriceSetter/Rpc.hs` documenting exactly what Step 5 observed, e.g.:

```haskell
-- Observed (2026-07-18, against a hook address with no deployed code): <fill in
-- with the actual outcome from Step 5 — "returns Left (Web3Error ...)" or "throws
-- an uncaught JsonRpcException, crashing the process">.
write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)
```

Then rebuild to confirm the comment doesn't break anything, and commit:

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tail -5
git add offchain/lib/PriceSetter/Rpc.hs
git commit -m "docs: record observed write_price negative-path behavior"
```

No other commit for this task — Steps 1–5 are verification only.
