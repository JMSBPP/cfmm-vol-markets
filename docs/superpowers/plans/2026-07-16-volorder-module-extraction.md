# VolOrder Module Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `offchain/app/Main.hs`'s domain type, calldata encoding, RPC
submit/poll orchestration, and receipt/log decoding into a `VolOrder.*` library
(`offchain/lib/`), splitting pure log-decoding from `IO`-based reporting, so `Main.hs`
shrinks to a one-line composition root and the decode logic is reusable by future
event-subscription/queue code (`todo.md` items 2–9).

**Architecture:** Five new library modules (`VolOrder.Types`, `VolOrder.Encoding`,
`VolOrder.Decode`, `VolOrder.Report`, `VolOrder.Rpc`) replace the unused `MyLib` stub.
`VolOrder.Rpc.create_order` stays a reusable `Web3 TxReceipt` action (no printing);
`create_order_and_report` is a thin `IO ()` wrapper that runs it and prints the result —
that's the only thing `Main` calls. Demo values move to an executable-local
`offchain/app/Sample.hs`, not the library.

**Tech Stack:** Haskell (GHC 9.10.3, `Haskell2010`), Cabal 3.12, the `hs-web3` library
family (`web3-provider`, `web3-solidity`, `web3-ethereum`), `memory-hexstring`, `process`
(for shelling out to `cast`), `bytestring`, `time`.

## Global Constraints

- Package: `cfmm-replicationPlank-rpc-api`, `base ^>=4.20.2.0`, `cabal-version: 3.12`,
  `default-language: Haskell2010`. Observed toolchain: GHC 9.10.3.
- Every stanza uses `import: warnings` (`ghc-options: -Wall`) — **zero warnings** is a
  hard requirement for every build check in this plan.
- Pure code-motion refactor plus one decode/report split — **no behavior change** to the
  RPC calls, the polling interval/bound (50 attempts × 200ms ≈ 10s), or the printed
  report's field order/labels.
- The error type returned by `runWeb3'` is `Web3Error` (from `Network.Web3.Provider`),
  **not** a custom error type — do not invent a different name.
- Spec: `docs/superpowers/specs/2026-07-16-volorder-module-extraction-design.md` (already
  reviewed by a Reality Checker and a Software Architect; this plan folds in both sets of
  findings).

---

### Task 1: `VolOrder.Types` — the domain record

**Files:**
- Create: `offchain/lib/VolOrder/Types.hs`
- Delete: `offchain/lib/MyLib.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library stanza only)

**Interfaces:**
- Produces: `data VolOrder = VolOrder { vol_target :: Quantity, range_width :: Quantity,
  skew :: Quantity }`, fully exported (`VolOrder(..)`) — every later task that builds or
  reads a `VolOrder` value depends on this.

- [ ] **Step 1: Delete the unused library stub**

Confirm nothing references it, then delete it:

```bash
grep -rn "MyLib\|someFunc" --include="*.hs" /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api/offchain
rm /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api/offchain/lib/MyLib.hs
```

Expected: the `grep` prints nothing (already verified during spec review — no
references anywhere in the repo, including `offchain/test/Main.hs`).

- [ ] **Step 2: Create `VolOrder.Types`**

```haskell
module VolOrder.Types
  ( VolOrder(..)
  ) where

import Network.Ethereum.Api.Types (Quantity)

data VolOrder = VolOrder
  { vol_target  :: Quantity
  , range_width :: Quantity
  , skew        :: Quantity
  }
```

- [ ] **Step 3: Update the cabal library stanza**

In `cfmm-replicationPlank-rpc-api.cabal`, change:

```cabal
library
    import:           warnings
    exposed-modules:  MyLib
    build-depends:    base ^>=4.20.2.0, web3-ethereum, web3-solidity
    hs-source-dirs:   offchain/lib/
    default-language: Haskell2010
```

to:

```cabal
library
    import:           warnings
    exposed-modules:  VolOrder.Types
    build-depends:    base ^>=4.20.2.0, web3-ethereum, web3-solidity
    hs-source-dirs:   offchain/lib/
    default-language: Haskell2010
```

(Only `exposed-modules` changes in this task — `build-depends` is untouched since
`VolOrder.Types` only needs `web3-ethereum`, already present.)

- [ ] **Step 4: Build the library alone and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task1-build.log
grep -i warning /tmp/task1-build.log
```

Expected: build succeeds; the `grep` for "warning" finds nothing. Note: the
`executable` stanza still references the pre-refactor `Main.hs`, which is untouched and
still self-contained in this task, so `cabal build` (whole package) also still succeeds —
only the library changed.

- [ ] **Step 5: Commit**

```bash
git add offchain/lib/VolOrder/Types.hs cfmm-replicationPlank-rpc-api.cabal
git rm offchain/lib/MyLib.hs
git commit -m "refactor: extract VolOrder domain type into library, drop MyLib stub"
```

---

### Task 2: `VolOrder.Encoding` — calldata encoding

**Files:**
- Create: `offchain/lib/VolOrder/Encoding.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library stanza)

**Interfaces:**
- Consumes: `VolOrder(..)` from Task 1 (`vol_target`, `range_width`, `skew` field
  accessors).
- Produces: `encode_create_order :: VolOrder -> IO HexString` — Task 5 (`VolOrder.Rpc`)
  calls this.

- [ ] **Step 1: Create `VolOrder.Encoding`**

```haskell
module VolOrder.Encoding
  ( encode_create_order
  ) where

import Data.ByteArray.HexString (HexString)
import Data.String (fromString)
import System.Process (readProcess)

import VolOrder.Types (VolOrder(..))

encode_create_order :: VolOrder -> IO HexString
encode_create_order order = do
  raw <-
    readProcess
      "cast"
      [ "calldata"
      , "create_order(uint88,uint24,uint16)"
      , show (vol_target order)
      , show (range_width order)
      , show (skew order)
      ]
      ""

  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words
```

- [ ] **Step 2: Update the cabal library stanza**

Add the two dependencies this module needs (`process` for the subprocess call,
`memory-hexstring` for `HexString`), and add the module to `exposed-modules`:

```cabal
library
    import:           warnings
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
    build-depends:    base ^>=4.20.2.0,
                      web3-ethereum,
                      web3-solidity,
                      memory-hexstring,
                      process
    hs-source-dirs:   offchain/lib/
    default-language: Haskell2010
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task2-build.log
grep -i warning /tmp/task2-build.log
```

Expected: build succeeds, no warnings.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/VolOrder/Encoding.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "refactor: extract calldata encoding into VolOrder.Encoding"
```

---

### Task 3: `VolOrder.Decode` — pure log decoding

**Files:**
- Create: `offchain/lib/VolOrder/Decode.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library stanza)

**Interfaces:**
- Consumes: `Change(..)` from `Network.Ethereum.Api.Types` (already a library
  dependency via `web3-ethereum`).
- Produces: `data OrderCreatedEvent = OrderCreatedEvent { orderOwner :: HexString,
  orderCreatedAt :: UTCTime, orderVolTarget :: Integer, orderRangeWidth :: Integer,
  orderSkew :: Integer } deriving (Eq, Show)`; `decode_order_created :: Change -> Maybe
  OrderCreatedEvent`; `topic_order_created :: Integer`; `hex_to_integer :: HexString ->
  Integer`; `data_word :: Int -> HexString -> Integer`; `be_integer :: BS.ByteString ->
  Integer`. Task 4 (`VolOrder.Report`) consumes `OrderCreatedEvent(..)` and
  `decode_order_created`.

This is the module a future subscription/`EventQueue` consumer will import directly — it
has **no `IO`** anywhere in its types, which is the fix for the review finding that the
original design fused decoding with printing.

`orderOwner` is typed as `HexString`, not `Address`, deliberately: the pre-refactor
`Main.hs` printed the owner as a plain lowercase `0x`-prefixed hex string (via
`printf "0x%040x"`), with no quotes. `HexString`'s `Show` instance produces exactly that
format (`"0x" ++ lowercase hex`, unquoted) directly from the raw 20 address bytes — using
`Address` instead would risk EIP-55 checksum-casing on `show`, silently changing the
printed output, which the spec's success criteria forbid.

- [ ] **Step 1: Create `VolOrder.Decode`**

```haskell
module VolOrder.Decode
  ( OrderCreatedEvent(..)
  , decode_order_created
  , topic_order_created
  , hex_to_integer
  , data_word
  , be_integer
  ) where

import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Time.Clock (UTCTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)

import Network.Ethereum.Api.Types (Change (..))

-- TOPIC_ORDER_CREATED in src/modules/VolOrderManagerMod.plk
topic_order_created :: Integer
topic_order_created = 0xa8892769

data OrderCreatedEvent = OrderCreatedEvent
  { orderOwner      :: HexString
  , orderCreatedAt  :: UTCTime
  , orderVolTarget  :: Integer
  , orderRangeWidth :: Integer
  , orderSkew       :: Integer
  } deriving (Eq, Show)

-- Log layout from log_create_order in src/modules/VolOrderManagerMod.plk:
-- topics are [TOPIC_ORDER_CREATED, owner, blockTimestamp], data is five
-- 32-byte words [32, 96, volTarget, rangeWidth, skew].
decode_order_created :: Change -> Maybe OrderCreatedEvent
decode_order_created log_entry =
  case changeTopics log_entry of
    [topic0, owner_topic, timestamp_topic]
      | hex_to_integer topic0 == topic_order_created ->
          Just OrderCreatedEvent
            { orderOwner      = fromBytes (BS.drop 12 (toBytes owner_topic))
            , orderCreatedAt  = posixSecondsToUTCTime (fromIntegral (hex_to_integer timestamp_topic))
            , orderVolTarget  = data_word 2 (changeData log_entry)
            , orderRangeWidth = data_word 3 (changeData log_entry)
            , orderSkew       = data_word 4 (changeData log_entry)
            }
    _ -> Nothing

hex_to_integer :: HexString -> Integer
hex_to_integer = be_integer . toBytes

data_word :: Int -> HexString -> Integer
data_word index = be_integer . BS.take 32 . BS.drop (32 * index) . toBytes

be_integer :: BS.ByteString -> Integer
be_integer = BS.foldl' (\acc byte -> acc * 256 + fromIntegral byte) 0
```

- [ ] **Step 2: Update the cabal library stanza**

Add `bytestring` and `time` (new), and add the module to `exposed-modules`:

```cabal
library
    import:           warnings
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
    build-depends:    base ^>=4.20.2.0,
                      web3-ethereum,
                      web3-solidity,
                      memory-hexstring,
                      process,
                      bytestring,
                      time
    hs-source-dirs:   offchain/lib/
    default-language: Haskell2010
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task3-build.log
grep -i warning /tmp/task3-build.log
```

Expected: build succeeds, no warnings.

- [ ] **Step 4: Sanity-check the decode logic in `cabal repl`**

This is a manual smoke test — no test framework exists in this project (the
`test-suite` stanza is still the unimplemented stub), and this task's job is to prove
the pure decoder round-trips a synthetic `Change` before it's wired into anything else.

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
import VolOrder.Decode
import Network.Ethereum.Api.Types (Change(..))
let topic0 = "0x00000000000000000000000000000000000000000000000000000000a8892769" :: HexString
let ownerTopic = "0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8" :: HexString
let tsTopic = "0x0000000000000000000000000000000000000000000000000000000042d4a2f1" :: HexString
let payload = "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000003c00000000000000000000000000000000000000000000000000000000000001f4" :: HexString
let change = Change Nothing Nothing Nothing Nothing Nothing "0x0000000000000000000000000000000000000000" payload [topic0, ownerTopic, tsTopic]
decode_order_created change
EOF
```

Expected: prints `Just (OrderCreatedEvent {orderOwner = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8", ..., orderVolTarget = 1000, orderRangeWidth = 60, orderSkew = 500})`
(exact timestamp will differ — the point is `Just`, not `Nothing`, and the three
numeric fields read `1000`, `60`, `500`). If `Change`'s constructor field order doesn't
match (check with `:info Change` in the same repl session first), adjust the positional
arguments accordingly — the named fields (`changeTopics`, `changeData`, etc.) are what
matters, not their positional order in this scratch test.

- [ ] **Step 5: Commit**

```bash
git add offchain/lib/VolOrder/Decode.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "refactor: extract pure ORDER_CREATED log decoding into VolOrder.Decode"
```

---

### Task 4: `VolOrder.Report` — thin IO formatting

**Files:**
- Create: `offchain/lib/VolOrder/Report.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library stanza)

**Interfaces:**
- Consumes: `OrderCreatedEvent(..)`, `decode_order_created` from Task 3.
- Produces: `report_receipt :: TxReceipt -> IO ()` — Task 5's
  `create_order_and_report` calls this. This is the module's only export; `status_text`
  and `report_log` stay internal.

- [ ] **Step 1: Create `VolOrder.Report`**

```haskell
module VolOrder.Report
  ( report_receipt
  ) where

import Network.Ethereum.Api.Types (Change (..), Quantity, TxReceipt (..))

import VolOrder.Decode (OrderCreatedEvent (..), decode_order_created)

report_receipt :: TxReceipt -> IO ()
report_receipt receipt = do
  putStrLn ("tx      " ++ show (receiptTransactionHash receipt))
  putStrLn ("status  " ++ status_text (receiptStatus receipt))
  putStrLn ("block   " ++ show (receiptBlockNumber receipt))
  putStrLn ("from    " ++ show (receiptFrom receipt))
  putStrLn ("to      " ++ maybe "(contract creation)" show (receiptTo receipt))
  putStrLn ("gas     " ++ show (receiptGasUsed receipt)
                       ++ " used @ "
                       ++ show (receiptEffectiveGasPrice receipt)
                       ++ " wei")
  case receiptLogs receipt of
    []   -> putStrLn "logs    (none)"
    logs -> mapM_ report_log logs

status_text :: Maybe Quantity -> String
status_text (Just 1) = "success"
status_text (Just 0) = "reverted"
status_text other    = "unknown " ++ show other

report_log :: Change -> IO ()
report_log log_entry =
  case decode_order_created log_entry of
    Just event -> report_order_created event
    Nothing    -> do
      putStrLn ("log     from " ++ show (changeAddress log_entry))
      mapM_ (putStrLn . ("  topic " ++) . show) (changeTopics log_entry)
      putStrLn ("  data  " ++ show (changeData log_entry))

report_order_created :: OrderCreatedEvent -> IO ()
report_order_created event = do
  putStrLn "log     ORDER_CREATED"
  putStrLn ("  owner       " ++ show (orderOwner event))
  putStrLn ("  timestamp   " ++ show (orderCreatedAt event))
  putStrLn ("  vol_target  " ++ show (orderVolTarget event))
  putStrLn ("  range_width " ++ show (orderRangeWidth event))
  putStrLn ("  skew        " ++ show (orderSkew event))
```

- [ ] **Step 2: Update the cabal library stanza**

Only `exposed-modules` changes — no new package dependencies:

```cabal
library
    import:           warnings
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
    build-depends:    base ^>=4.20.2.0,
                      web3-ethereum,
                      web3-solidity,
                      memory-hexstring,
                      process,
                      bytestring,
                      time
    hs-source-dirs:   offchain/lib/
    default-language: Haskell2010
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task4-build.log
grep -i warning /tmp/task4-build.log
```

Expected: build succeeds, no warnings.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/VolOrder/Report.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "refactor: extract IO receipt/log reporting into VolOrder.Report"
```

---

### Task 5: `VolOrder.Rpc` — reusable submission + poll orchestration

**Files:**
- Create: `offchain/lib/VolOrder/Rpc.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library stanza)

**Interfaces:**
- Consumes: `encode_create_order` (Task 2), `report_receipt` (Task 4), `VolOrder` (Task
  1).
- Produces: `create_order :: Address -> Address -> VolOrder -> Web3 TxReceipt` (no
  printing — reusable by any future caller that runs it via its own `runWeb3'`);
  `wait_for_receipt :: HexString -> Web3 TxReceipt`; `create_order_and_report ::
  Address -> Address -> VolOrder -> IO ()` (runs `create_order` against
  `HttpProvider "http://127.0.0.1:8545"` and prints the result or the RPC error). Task 6
  (`Main.hs`) calls `create_order_and_report` — nothing else.

The `Either` in the original `Main.hs` came from `runWeb3'`'s own signature
(`runWeb3' :: MonadIO m => Provider -> Web3 a -> m (Either Web3Error a)`), not from
`wait_for_receipt` — confirmed by reading `web3-provider`'s
`Network.Web3.Provider` source. `create_order` and `wait_for_receipt` keep the exact
same `Web3 TxReceipt` type the original functions had; only `create_order_and_report`
handles the `Either Web3Error TxReceipt` that `runWeb3'` produces.

- [ ] **Step 1: Create `VolOrder.Rpc`**

```haskell
module VolOrder.Rpc
  ( create_order
  , create_order_and_report
  , wait_for_receipt
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (Call (..), TxReceipt)
import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import VolOrder.Encoding (encode_create_order)
import VolOrder.Report (report_receipt)
import VolOrder.Types (VolOrder)

create_order :: Address -> Address -> VolOrder -> Web3 TxReceipt
create_order owner manager vol_order = do
  calldata <- liftIO (encode_create_order vol_order)

  let create_order_call :: Call
      create_order_call =
        Call
          { callFrom = Just owner
          , callTo = Just manager
          , callGas = Nothing
          , callGasPrice = Nothing
          , callValue = Nothing
          , callData = Just calldata
          , callNonce = Nothing
          }

  GlobalState.sendTransaction create_order_call >>= wait_for_receipt

wait_for_receipt :: HexString -> Web3 TxReceipt
wait_for_receipt tx_hash = go (50 :: Int)
  where
    go 0 = fail ("no receipt after 10s for " ++ show tx_hash)
    go attempts_left = do
      pending <- GlobalState.getTransactionReceipt tx_hash
      case pending of
        Just receipt -> pure receipt
        Nothing      -> do
          liftIO (threadDelay 200000)
          go (attempts_left - 1)

create_order_and_report :: Address -> Address -> VolOrder -> IO ()
create_order_and_report owner manager vol_order = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (create_order owner manager vol_order)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right receipt   -> report_receipt receipt
```

- [ ] **Step 2: Update the cabal library stanza**

Add `web3-provider` (new); `web3-solidity` is already present:

```cabal
library
    import:           warnings
    exposed-modules:  VolOrder.Types
                    , VolOrder.Encoding
                    , VolOrder.Decode
                    , VolOrder.Report
                    , VolOrder.Rpc
    build-depends:    base ^>=4.20.2.0,
                      web3-ethereum,
                      web3-solidity,
                      web3-provider,
                      memory-hexstring,
                      process,
                      bytestring,
                      time
    hs-source-dirs:   offchain/lib/
    default-language: Haskell2010
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task5-build.log
grep -i warning /tmp/task5-build.log
```

Expected: build succeeds, no warnings. At this point the full library (all five
`VolOrder.*` modules) builds; the executable still runs the old, untouched `Main.hs`.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/VolOrder/Rpc.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "refactor: extract reusable submit+poll orchestration into VolOrder.Rpc"
```

---

### Task 6: Thin `Main.hs` + executable-local `Sample.hs`

**Files:**
- Create: `offchain/app/Sample.hs`
- Modify: `offchain/app/Main.hs` (full replacement)
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (executable stanza)

**Interfaces:**
- Consumes: `create_order_and_report` (Task 5).
- Produces: nothing further downstream — this is the terminal task before verification.

- [ ] **Step 1: Create `offchain/app/Sample.hs`**

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Sample
  ( account
  , order_manager
  , sample_order
  ) where

import Data.Solidity.Prim.Address (Address)

import VolOrder.Types (VolOrder (..))

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }
```

- [ ] **Step 2: Replace `offchain/app/Main.hs` entirely**

```haskell
module Main where

import Sample (account, order_manager, sample_order)
import VolOrder.Rpc (create_order_and_report)

main :: IO ()
main = create_order_and_report account order_manager sample_order
```

- [ ] **Step 3: Update the cabal executable stanza**

The executable no longer touches `web3-provider`, `web3-ethereum`, `memory-hexstring`,
`process`, `bytestring`, or `time` directly — only `Sample.hs`'s use of
`Data.Solidity.Prim.Address` needs `web3-solidity` on top of the library itself:

```cabal
executable cfmm-replicationPlank-rpc-api
    import:           warnings
    main-is:          Main.hs
    other-modules:    Sample
    build-depends:
        base ^>=4.20.2.0,
        cfmm-replicationPlank-rpc-api,
        web3-solidity
    hs-source-dirs:   offchain/app
    default-language: Haskell2010
```

- [ ] **Step 4: Build the whole package and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task6-build.log
grep -i warning /tmp/task6-build.log
```

Expected: build succeeds, no warnings. If GHC reports `Sample` or any `VolOrder.*`
module not found, re-check the cabal stanza edits from Tasks 1–6 above before proceeding
— do not paper over a missing-module error by re-adding old code to `Main.hs`.

- [ ] **Step 5: Commit**

```bash
git add offchain/app/Sample.hs offchain/app/Main.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "refactor: shrink Main.hs to a composition root over VolOrder.Rpc"
```

---

### Task 7: End-to-end verification against a live chain

**Files:** none (verification only).

**Interfaces:** none — this task only observes behavior, it does not change code.

This proves the refactor is behavior-preserving. Note what "identical" means here:
transaction hash, block number, gas price, and nonce are inherently different on every
run (fresh chain state, incrementing nonce) — those are not the comparison target.
What must match the pre-refactor baseline is the **shape**: the same field labels in
the same order, correctly formatted, with the `ORDER_CREATED` log decoding to the
`sample_order` values (`1000`, `60`, `500`) and an unquoted lowercase owner address.

- [ ] **Step 1: Check whether an anvil node from a prior session is still running**

```bash
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
```

If this returns `{"jsonrpc":"2.0","id":1,"result":"anvil/..."}`, skip Step 2. If it
fails to connect, proceed to Step 2.

- [ ] **Step 2: Start anvil (only if Step 1 showed no running node)**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
anvil --silent > /tmp/anvil-task7.log 2>&1 &
sleep 2
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
```

Expected: an `anvil/vX.Y.Z` result.

- [ ] **Step 3: Deploy `VolOrderManager` (skip if it's already deployed at
      `0x5FbDB2315678afecb367f032d93F642f64180aa3` on the running chain)**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x5FbDB2315678afecb367f032d93F642f64180aa3","latest"]}'
```

If the `result` is `"0x"` (no code), deploy it:

```bash
forge script foundry-scripts/VolOrderManager.s.sol \
  --rpc-url http://127.0.0.1:8545 --broadcast --ffi --via-ir 2>&1 | tail -15
```

Expected: `ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.`

- [ ] **Step 4: Run the refactored executable**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal run -v0 exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/task7-run.log
```

Expected output shape (11 lines, this exact label order — values will differ per run
except the three decoded order fields):

```
tx      0x<64 hex chars>
status  success
block   <N>
from    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
to      "0x5FbDB2315678afecb367f032d93F642f64180aa3"
gas     <N> used @ <N> wei
log     ORDER_CREATED
  owner       0x70997970c51812dc3a010c7d01b50e0d17dc79c8
  timestamp   <UTC timestamp>
  vol_target  1000
  range_width 60
  skew        500
```

- [ ] **Step 5: Confirm the decoded order fields are exactly right**

```bash
grep -E "vol_target  1000|range_width 60|skew        500" /tmp/task7-run.log
```

Expected: all three lines present. If any is missing or shows a different number, the
`Decode`/`Report` split introduced a bug — do not proceed; re-check Task 3/4 against
this plan's code before re-running.

- [ ] **Step 6: Confirm `status  success` and no `rpc error:` line**

```bash
grep -c "^status  success$" /tmp/task7-run.log
grep -c "rpc error:" /tmp/task7-run.log
```

Expected: first command prints `1`, second prints `0`.

No commit for this task — it's verification only. If any step fails, fix the
implementation in the relevant earlier task and re-run this task from Step 4.
