# StochasticOrderGen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `VolOrder.*` with a `create_orders` multicall primitive (packing,
decoding, and RPC orchestration for the on-chain `create_orders(uint256,uint256[])`
batch entrypoint), and add a new `StochasticOrderGen.*` library that draws a
Poisson-distributed batch count and drives it through that primitive, splitting into
≤128-order chunks as needed.

**Architecture:** Two layers. Layer 1 extends the existing `VolOrder.{Encoding,Decode,
Rpc}` modules with a second on-chain entrypoint (same contract, new calldata shape).
Layer 2 adds four new modules (`offchain/lib/StochasticOrderGen/{Types,Simulate,Report,
Rpc}.hs`) mirroring `StochasticPriceGen`'s established `Types`/`Simulate`/`Report`/`Rpc`
shape, consuming Layer 1's `create_orders` the same way `StochasticPriceGen.Rpc` consumes
`PriceSetter.Rpc.write_price`. `VolOrder.Rpc.create_orders` performs its own
preview-vs-mined consistency check internally (reading `orderCount()` and
`getOrderPacked` before/after the send) rather than surfacing that as a second return
channel — the caller only ever sees `(TxReceipt, [(Bool, Integer)])`.

**Tech Stack:** Haskell (GHC 9.10.3, `Haskell2010`), Cabal 3.12, `mwc-random` (already a
dependency, `System.Random.MWC.Distributions.poisson`), reusing the existing `hs-web3`
stack. No new packages.

## Global Constraints

- Package: `cfmm-replicationPlank-rpc-api`, `base ^>=4.20.2.0`, `cabal-version: 3.12`,
  `default-language: Haskell2010`. Toolchain: GHC 9.10.3.
- Every stanza uses `import: warnings` (`-Wall`) — **zero warnings** required after every
  build check.
- **`create_orders` input packing formula (verified against
  `test/pos_spec/VolOrderManagerBatch.t.sol`'s own `packInput` helper):**
  `packed = skew | (vol_target << 16) | (range_width << 104)`. This is the *input* word
  layout, distinct from the contract's *storage* layout (below).
- **Field-width validation is mandatory before combining, not optional (spec decision
  9 — the review's central finding):** `0 < vol_target < 2^88`, `0 < range_width <
  2^24`, `0 < skew < 2^16`. An out-of-range `vol_target` in `[2^88, 2^104)` must fail
  clearly, never silently bleed into `range_width`'s bit-slot.
- **Storage-layout unpacking (a THIRD, distinct bit layout from both the single-order
  ABI format and the `create_orders` input format):** `range_width` at bits 128–151,
  a hardcoded `tickSpacing` at bits 104–127 (read and discarded, not part of `VolOrder`),
  `vol_target` at bits 16–103, `skew` at bits 0–15.
- **`MAX_BATCH = 128`, hard on-chain revert above it** — the Haskell side must pre-check
  and split into `⌈N/128⌉` sequential chunks itself; never send an oversized batch.
- **`create_orders` return shape**: `(bool success, uint256 orderId)[]`, ABI-encoded as
  offset word `0x20`, length word (= count), then `count` inline `(bool, uint256)` pairs
  at stride `0x40`. `count = 0` is a well-formed 64-byte result.
- **Strict bool canonicality (spec decision 12):** exactly `0` or `1`; any other value at
  a result's bool position is a decode failure, not a lenient "nonzero = true".
- **`callGas = Nothing` always (spec decision 11)** — dynamic node gas estimation, never
  a fixed/reused gas limit, for both the `eth_call` preview and the real
  `sendTransaction`.
- **`eth_call` preview is paired with an `orderCount()`-delta + `getOrderPacked`
  readback (spec decision 10)** — the preview alone is never treated as ground truth for
  what actually landed.
- **No real arrival-time process (spec decision 2)** — `StochasticOrderGen` draws a
  single Poisson-distributed batch count `N`; all `N` orders are sent immediately (no
  real-time waiting between individual orders).
- **`StochasticOrderGen` does not generate `VolOrder` content (spec decision 3)** — the
  caller supplies `orders :: [VolOrder]`; the module only decides *how many* and *when*.
- **No silent truncation (spec decision 4):** if the Poisson draw `N` exceeds
  `length orders`, fail clearly with zero RPC calls made — never silently send fewer.
- **Sequential, non-concurrent chunk sends (spec decision 8).**
- Spec: `docs/superpowers/specs/2026-07-21-stochastic-order-gen-design.md` (two-step
  reviewed: Reality Checker + Solidity Smart Contract Engineer; this plan implements the
  post-review version, including decisions 9–12).
- Current `VolOrder.Rpc.create_order` signature (consumed as-is, refactored internally
  but not changed in signature): `create_order :: Address -> Address -> VolOrder ->
  Web3 TxReceipt`.
- Deployed rig reused from prior work: `order_manager = Sample.order_manager =
  "0x5FbDB2315678afecb367f032d93F642f64180aa3"`, anvil at `http://127.0.0.1:8545`.

---

### Task 1: `VolOrder.Encoding` — packing and calldata for the batch entrypoint

**Files:**
- Modify: `offchain/lib/VolOrder/Encoding.hs`

**Interfaces:**
- Consumes: `VolOrder(..)` (existing, `VolOrder.Types`).
- Produces: `pack_vol_order_input :: VolOrder -> Either String Integer`,
  `encode_create_orders :: [VolOrder] -> IO HexString`, `encode_order_count :: IO
  HexString`, `encode_get_order_packed :: Integer -> IO HexString`. Task 3 (`VolOrder.
  Rpc`) consumes all four.

This task also refactors the existing `encode_create_order` to share a private
`encode_call` helper (mirroring `PriceSetter.Encoding`'s shape exactly) instead of
duplicating the `cast calldata` + trim pattern for every new read-only call added here.

- [ ] **Step 1: Replace `offchain/lib/VolOrder/Encoding.hs` entirely**

```haskell
module VolOrder.Encoding
  ( encode_create_order
  , pack_vol_order_input
  , encode_create_orders
  , encode_order_count
  , encode_get_order_packed
  ) where

import Data.Bits (shiftL, (.|.))
import Data.ByteArray.HexString (HexString)
import Data.List (intercalate)
import Data.String (fromString)
import System.Process (readProcess)

import VolOrder.Types (VolOrder (..))

encode_create_order :: VolOrder -> IO HexString
encode_create_order order =
  encode_call
    "create_order(uint88,uint24,uint16)"
    [ show (vol_target order)
    , show (range_width order)
    , show (skew order)
    ]

-- Packs a VolOrder into the create_orders INPUT word layout, verified against
-- test/pos_spec/VolOrderManagerBatch.t.sol's own packInput helper:
--   packed = skew | (vol_target << 16) | (range_width << 104)
-- This is NOT the contract's internal storage layout -- see
-- VolOrder.Decode.unpack_vol_order_storage for that (a third, distinct layout).
--
-- Each field is validated strictly in-range before combining. The contract's own
-- decode deliberately leaves range_width unmasked so overflow >= 2^104 is caught
-- on-chain by vol_range_width_is_complete -- but a vol_target in [2^88, 2^104)
-- shifts left by 16 and lands entirely inside range_width's own 24-bit slot,
-- OR-ing in as a plausible-looking width with ZERO on-chain signal (not a revert,
-- not (false, 0)). Masking each field before combining (like the contract's own
-- storage-side pack_vol_order does) would only relocate this silent-corruption
-- risk from on-chain to off-chain -- so this validates and fails clearly instead.
pack_vol_order_input :: VolOrder -> Either String Integer
pack_vol_order_input order
  | not (in_range 88 target) =
      Left ("vol_target out of range for its 88-bit field (must be > 0 and < 2^88): "
             ++ show target)
  | not (in_range 24 width) =
      Left ("range_width out of range for its 24-bit field (must be > 0 and < 2^24): "
             ++ show width)
  | not (in_range 16 sk) =
      Left ("skew out of range for its 16-bit field (must be > 0 and < 2^16): "
             ++ show sk)
  | otherwise = Right (sk .|. (target `shiftL` 16) .|. (width `shiftL` 104))
  where
    target = toInteger (vol_target order)
    width  = toInteger (range_width order)
    sk     = toInteger (skew order)
    in_range bits value = value > 0 && value < (1 `shiftL` bits)

encode_create_orders :: [VolOrder] -> IO HexString
encode_create_orders orders = do
  packed <- either fail pure (traverse pack_vol_order_input orders)
  encode_call
    "create_orders(uint256,uint256[])"
    [ show (length orders)
    , "[" ++ intercalate "," (map show packed) ++ "]"
    ]

encode_order_count :: IO HexString
encode_order_count = encode_call "orderCount()" []

encode_get_order_packed :: Integer -> IO HexString
encode_get_order_packed order_id = encode_call "getOrderPacked(uint256)" [show order_id]

encode_call :: String -> [String] -> IO HexString
encode_call signature args = do
  raw <- readProcess "cast" ("calldata" : signature : args) ""
  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words
```

- [ ] **Step 2: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task1-build.log
grep -i warning /tmp/sog-task1-build.log || echo "no warnings"
```

- [ ] **Step 3: `cabal repl` smoke test — packing formula and field-width validation**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
import Data.Bits (shiftL)
import VolOrder.Encoding (pack_vol_order_input)
import VolOrder.Types (VolOrder(..))

let order = VolOrder { vol_target = 1000, range_width = 60, skew = 500 }
let expected = 500 + (1000 `shiftL` 16) + (60 `shiftL` 104)
print (pack_vol_order_input order == Right expected)

let bad_order = VolOrder { vol_target = 2^88 + 1, range_width = 60, skew = 500 }
pack_vol_order_input bad_order
:quit
EOF
```

Expected: first `print` prints `True` (confirms the bit-shift amounts are exactly
right, cross-checked against the reference formula computed independently in the same
session). `pack_vol_order_input bad_order` prints `Left "vol_target out of range for
its 88-bit field (must be > 0 and < 2^88): ..."` — confirms the review's central
finding is closed: an out-of-range `vol_target` in `[2^88, 2^104)` fails clearly
*before* any calldata is built, rather than silently corrupting `range_width`.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/VolOrder/Encoding.hs
git commit -m "feat: add create_orders packing/calldata to VolOrder.Encoding"
```

---

### Task 2: `VolOrder.Decode` — decoding the batch result and storage readback

**Files:**
- Modify: `offchain/lib/VolOrder/Decode.hs`

**Interfaces:**
- Consumes: `VolOrder(..)` (existing, `VolOrder.Types`), `data_word`/`hex_to_integer`
  (existing, same module).
- Produces: `decode_create_orders_result :: HexString -> Either String [(Bool,
  Integer)]`, `unpack_vol_order_storage :: Integer -> VolOrder`. Task 3 (`VolOrder.Rpc`)
  consumes both.

- [ ] **Step 1: Replace `offchain/lib/VolOrder/Decode.hs` entirely**

```haskell
module VolOrder.Decode
  ( OrderCreatedEvent(..)
  , decode_order_created
  , topic_order_created
  , hex_to_integer
  , data_word
  , be_integer
  , decode_create_orders_result
  , unpack_vol_order_storage
  ) where

import Data.Bits (shiftL, shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Time.Clock (UTCTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)

import Network.Ethereum.Api.Types (Change (..))

import VolOrder.Types (VolOrder (..))

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

-- create_orders returns (bool success, uint256 orderId)[], ABI-encoded as a
-- static-tuple array: offset word (0x20), length word (= count, in elements),
-- then inline (bool, uint256) pairs at stride 0x40. count = 0 is a well-formed
-- 64-byte empty result, not 0 or 32 bytes.
--
-- The contract always emits canonical 0/1 success words (never a truthy
-- nonzero, confirmed by its own dedicated test and an explicit "named mutant"
-- comment) -- this decoder matches that strictness: exactly 0 or 1, anything
-- else is a decode failure, not a lenient "nonzero = true" (a lenient decoder
-- would silently disagree with what a real abi.decode, which rejects
-- non-canonical bools, reports for the same bytes).
decode_create_orders_result :: HexString -> Either String [(Bool, Integer)]
decode_create_orders_result raw
  | byte_length < 64 =
      Left ("create_orders result too short: " ++ show byte_length ++ " bytes")
  | byte_length /= expected_length =
      Left ("create_orders result length mismatch: expected " ++ show expected_length
             ++ " bytes for count " ++ show count ++ ", got " ++ show byte_length)
  | otherwise = traverse decode_pair [0 .. count - 1]
  where
    byte_length     = BS.length (toBytes raw)
    count           = fromIntegral (data_word 1 raw) :: Int
    expected_length = 64 + 64 * count

    decode_pair index =
      let pair_base = 2 + 2 * index
          bool_word = data_word pair_base raw
          order_id  = data_word (pair_base + 1) raw
      in case bool_word of
           0     -> Right (False, order_id)
           1     -> Right (True, order_id)
           other -> Left ("create_orders result: non-canonical bool word at index "
                            ++ show index ++ ": " ++ show other)

-- The contract's *storage*-layout packed word (from getOrderPacked), a THIRD
-- distinct bit layout from both the create_order(uint88,uint24,uint16) ABI-word
-- format and the create_orders input-word format (pack_vol_order_input's
-- layout). Storage layout inserts a hardcoded tickSpacing at bits 104-127 and
-- shifts range_width to bits 128-151 (pack_vol_order/unpack_vol_order in
-- src/types/pos_spec/VolOrder.plk). tickSpacing is read and discarded here --
-- it is always the contract's hardcoded constant, not part of VolOrder.
unpack_vol_order_storage :: Integer -> VolOrder
unpack_vol_order_storage packed =
  VolOrder
    { vol_target  = fromInteger (mask_bits 88 (packed `shiftR` 16))
    , range_width = fromInteger (mask_bits 24 (packed `shiftR` 128))
    , skew        = fromInteger (mask_bits 16 packed)
    }
  where
    mask_bits bits value = value .&. ((1 `shiftL` bits) - 1)
```

- [ ] **Step 2: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task2-build.log
grep -i warning /tmp/sog-task2-build.log || echo "no warnings"
```

- [ ] **Step 3: `cabal repl` smoke test — non-canonical bool rejection**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import Data.ByteArray.HexString (HexString)
import Data.String (fromString)
import Numeric (showHex)
import VolOrder.Decode (decode_create_orders_result)

let pad_word n = let h = showHex (n :: Integer) "" in replicate (64 - length h) '0' ++ h
let good_hex = "0x" ++ pad_word 0x20 ++ pad_word 1 ++ pad_word 1 ++ pad_word 5
let bad_hex  = "0x" ++ pad_word 0x20 ++ pad_word 1 ++ pad_word 2 ++ pad_word 5
let good_result = fromString good_hex :: HexString
let bad_result  = fromString bad_hex  :: HexString
decode_create_orders_result good_result
decode_create_orders_result bad_result
:quit
EOF
```

Expected: `decode_create_orders_result good_result` prints `Right [(True,5)]` (a
well-formed single-entry, canonical-bool result). `decode_create_orders_result
bad_result` prints `Left "create_orders result: non-canonical bool word at index 0:
2"` — confirms decision 12: a `2` in the bool position is rejected, not
lenient-accepted as truthy.

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/VolOrder/Decode.hs
git commit -m "feat: add create_orders result decoding and storage unpacking to VolOrder.Decode"
```

---

### Task 3: `VolOrder.Rpc` — the `create_orders` orchestration

**Files:**
- Modify: `offchain/lib/VolOrder/Rpc.hs`
- Modify: `offchain/lib/VolOrder/Types.hs` (add `deriving (Eq, Show)` — needed by this
  task's mined-order consistency check; `Quantity` already derives both, so this is a
  free addition)

**Interfaces:**
- Consumes: `pack_vol_order_input`, `encode_create_orders`, `encode_order_count`,
  `encode_get_order_packed` (Task 1); `decode_create_orders_result`,
  `unpack_vol_order_storage`, `hex_to_integer` (Task 2).
- Produces: `create_orders :: Address -> Address -> [VolOrder] -> Web3 (TxReceipt,
  [(Bool, Integer)])`. Task 7 (`StochasticOrderGen.Rpc`) consumes this.

`create_orders` enforces `MAX_BATCH = 128` itself before building any calldata (the
on-chain `require` would revert anyway, but with an undifferentiated empty-data reason
per the spec's Error handling section — failing here gives a specific message). After
the transaction is mined, it reads `orderCount()` before and after the send and reads
back `getOrderPacked` for every id in the delta range, decoded via
`unpack_vol_order_storage` (decision 10). Two things are asserted from this readback,
both failing loudly on mismatch rather than returning results that quietly disagree
with what was actually mined:

1. The ids of the `eth_call` preview's successful entries, in order, are exactly the
   ids that landed (`[before_count + 1 .. after_count]`). Ids are **1-based**: the
   contract mints `id = orderCount + 1` and then advances the count to that id
   (`VolOrderManagerMod.plk`, "Ids are sequential from 1 and orderCount IS the id
   source" — slot 0 is never written and stays permanently zero as the
   nonexistent-order sentinel). The plan originally wrote this range 0-based
   (`[before_count .. after_count - 1]`) on an `orderCount++`-style assumption; the
   contract source disproved that before the first live run, and the range above is
   the corrected one. If a live run in Task 9 shows even the corrected assumption
   wrong, that is a real finding to bring back to this plan/spec, not something to
   route around with a fallback.
2. Each mined order's unpacked content (`VolOrder`) matches the input order that was
   submitted for it.

- [ ] **Step 1: Add `deriving (Eq, Show)` to `offchain/lib/VolOrder/Types.hs`**

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
  deriving (Eq, Show)
```

- [ ] **Step 2: Replace `offchain/lib/VolOrder/Rpc.hs` entirely**

```haskell
module VolOrder.Rpc
  ( create_order
  , create_order_and_report
  , create_orders
  , wait_for_receipt
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (Call (..), DefaultBlock (Latest), TxReceipt)
import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import VolOrder.Decode (decode_create_orders_result, hex_to_integer, unpack_vol_order_storage)
import VolOrder.Encoding
  ( encode_create_order
  , encode_create_orders
  , encode_get_order_packed
  , encode_order_count
  )
import VolOrder.Report (report_receipt)
import VolOrder.Types (VolOrder)

create_order :: Address -> Address -> VolOrder -> Web3 TxReceipt
create_order owner manager vol_order = do
  calldata <- liftIO (encode_create_order vol_order)
  send_and_wait owner manager calldata

-- MAX_BATCH = 128 is enforced here first, before any calldata is built: the
-- on-chain require(count <= MAX_BATCH) would revert anyway, but with an
-- undifferentiated empty-data reason (spec Error handling) -- failing here
-- gives a specific, attributable message instead.
create_orders :: Address -> Address -> [VolOrder] -> Web3 (TxReceipt, [(Bool, Integer)])
create_orders owner manager orders
  | length orders > 128 =
      fail ("create_orders: batch of " ++ show (length orders) ++ " orders exceeds MAX_BATCH = 128")
  | otherwise = do
      calldata <- liftIO (encode_create_orders orders)

      preview_raw <- eth_call_manager manager calldata
      preview <- either fail pure (decode_create_orders_result preview_raw)

      before_count <- read_order_count manager
      receipt <- send_and_wait owner manager calldata
      after_count <- read_order_count manager

      -- Ids are 1-based: the contract mints id = orderCount + 1, then advances the
      -- count to that id (VolOrderManagerMod.plk, "Ids are sequential from 1 and
      -- orderCount IS the id source"). Slot 0 is never written. So a batch that
      -- moves orderCount from B to A minted exactly the ids [B+1 .. A].
      let mined_ids           = [before_count + 1 .. after_count]
          successful_entries  = [ (input_order, order_id)
                                 | (input_order, (success, order_id)) <- zip orders preview
                                 , success
                                 ]
          preview_success_ids = map snd successful_entries

      if preview_success_ids /= mined_ids
        then fail
               ("create_orders: eth_call preview predicted successful order ids "
                 ++ show preview_success_ids
                 ++ " but orderCount() only advanced over " ++ show mined_ids
                 ++ " (before=" ++ show before_count ++ ", after=" ++ show after_count ++ ")")
        else do
          mapM_ (verify_mined_order manager) successful_entries
          pure (receipt, preview)

verify_mined_order :: Address -> (VolOrder, Integer) -> Web3 ()
verify_mined_order manager (expected_order, order_id) = do
  packed <- read_order_packed manager order_id
  let actual_order = unpack_vol_order_storage packed
  if actual_order == expected_order
    then pure ()
    else fail
           ("create_orders: mined order " ++ show order_id
             ++ " does not match the input submitted for it -- expected "
             ++ show expected_order ++ ", read back " ++ show actual_order)

read_order_count :: Address -> Web3 Integer
read_order_count manager = do
  calldata <- liftIO encode_order_count
  hex_to_integer <$> eth_call_manager manager calldata

read_order_packed :: Address -> Integer -> Web3 Integer
read_order_packed manager order_id = do
  calldata <- liftIO (encode_get_order_packed order_id)
  hex_to_integer <$> eth_call_manager manager calldata

eth_call_manager :: Address -> HexString -> Web3 HexString
eth_call_manager manager calldata =
  GlobalState.call
    Call
      { callFrom = Nothing
      , callTo = Just manager
      , callGas = Nothing
      , callGasPrice = Nothing
      , callValue = Nothing
      , callData = Just calldata
      , callNonce = Nothing
      }
    Latest

send_and_wait :: Address -> Address -> HexString -> Web3 TxReceipt
send_and_wait owner manager calldata =
  GlobalState.sendTransaction
    Call
      { callFrom = Just owner
      , callTo = Just manager
      , callGas = Nothing
      , callGasPrice = Nothing
      , callValue = Nothing
      , callData = Just calldata
      , callNonce = Nothing
      }
    >>= wait_for_receipt

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

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task3-build.log
grep -i warning /tmp/sog-task3-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings. Live verification of `create_orders` against
the deployed rig is deferred to Task 9 (needs the rig up and, for the best-effort
path, a deliberately on-chain-invalid order).

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/VolOrder/Rpc.hs offchain/lib/VolOrder/Types.hs
git commit -m "feat: add create_orders RPC orchestration with mined-order readback"
```

---

### Task 4: `StochasticOrderGen.Types` — the domain types

**Files:**
- Create: `offchain/lib/StochasticOrderGen/Types.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only)

**Interfaces:**
- Consumes: `VolOrder` (existing, `VolOrder.Types`).
- Produces: `data ArrivalProcess = Poisson { lambda :: Double }` and `data
  StochasticOrderGen = StochasticOrderGen { arrival_process :: ArrivalProcess, orders ::
  [VolOrder] }`, both fully exported. Task 5 (`Simulate`), Task 7 (`Rpc`), and Task 8
  (`Sample.hs`) all construct/pattern-match these directly.

`ArrivalProcess` is a one-constructor sum type (not a bare `Double` field) deliberately
mirroring `ProcessType`'s shape — room to add another arrival model later without
breaking the interface (spec decision 1).

- [ ] **Step 1: Create `StochasticOrderGen.Types`**

```haskell
module StochasticOrderGen.Types
  ( ArrivalProcess (..)
  , StochasticOrderGen (..)
  ) where

import VolOrder.Types (VolOrder)

data ArrivalProcess = Poisson
  { lambda :: Double
  }
  deriving (Eq, Show)

data StochasticOrderGen = StochasticOrderGen
  { arrival_process :: ArrivalProcess
  , orders          :: [VolOrder]
  }
  deriving (Eq, Show)
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
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate
                    , StochasticPriceGen.Report
                    , StochasticPriceGen.Rpc
                    , StochasticOrderGen.Types
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task4-build.log
grep -i warning /tmp/sog-task4-build.log || echo "no warnings"
```

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/StochasticOrderGen/Types.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticOrderGen.Types (ArrivalProcess, StochasticOrderGen)"
```

---

### Task 5: `StochasticOrderGen.Simulate` — the Poisson batch-count draw

**Files:**
- Create: `offchain/lib/StochasticOrderGen/Simulate.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only — no new
  `build-depends`; `mwc-random` already present from `StochasticPriceGen`)

**Interfaces:**
- Consumes: `ArrivalProcess(..)` (Task 4).
- Produces: `simulate_batch_count :: GenIO -> ArrivalProcess -> IO Int`. Task 7 (`Rpc`)
  consumes this.

`System.Random.MWC.Distributions.poisson` already guards its own domain (negative or
too-large `λ` raises a clear, distinguishable `pkgError`) — unlike
`StochasticPriceGen.Simulate`'s Euler-Maruyama step, no additional domain guard is
needed here (spec Ground truth).

- [ ] **Step 1: Create `StochasticOrderGen.Simulate`**

```haskell
module StochasticOrderGen.Simulate
  ( simulate_batch_count
  ) where

import System.Random.MWC (GenIO)
import System.Random.MWC.Distributions (poisson)

import StochasticOrderGen.Types (ArrivalProcess (..))

simulate_batch_count :: GenIO -> ArrivalProcess -> IO Int
simulate_batch_count gen (Poisson lambda_value) = poisson lambda_value gen
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
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate
                    , StochasticPriceGen.Report
                    , StochasticPriceGen.Rpc
                    , StochasticOrderGen.Types
                    , StochasticOrderGen.Simulate
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task5-build.log
grep -i warning /tmp/sog-task5-build.log || echo "no warnings"
```

- [ ] **Step 4: `cabal repl` smoke test — determinism**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
import StochasticOrderGen.Simulate (simulate_batch_count)
import StochasticOrderGen.Types (ArrivalProcess(..))
import System.Random.MWC (create)

gen1 <- create
n1 <- simulate_batch_count gen1 (Poisson { lambda = 3.0 })
gen2 <- create
n2 <- simulate_batch_count gen2 (Poisson { lambda = 3.0 })
print n1
print (n1 == n2)
:quit
EOF
```

Expected: `n1` prints a non-negative `Int`, and `n1 == n2` prints `True` — confirms two
**independent** `create` calls (fresh `Gen`s, not one shared `Gen` reused) reproduce
identically, matching `StochasticPriceGen`'s established reproducibility pattern.

- [ ] **Step 5: Commit**

```bash
git add offchain/lib/StochasticOrderGen/Simulate.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticOrderGen.Simulate (Poisson batch-count draw)"
```

---

### Task 6: `StochasticOrderGen.Report` — thin IO formatting

**Files:**
- Create: `offchain/lib/StochasticOrderGen/Report.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only)

**Interfaces:**
- Produces: `report_batch_result :: (TxReceipt, [(Bool, Integer)]) -> IO ()`. Task 7's
  `run_order_gen_and_report` and `offchain/app/Main.hs` (Task 8) call this.

Prints a per-chunk summary once each chunk's `eth_call` preview is decoded — a run can
be multiple chunks, so this reports once per chunk rather than once per whole run
(mirrors `StochasticPriceGen.Report`'s "once per logical unit of work" shape, here that
unit is a chunk).

- [ ] **Step 1: Create `StochasticOrderGen.Report`**

```haskell
module StochasticOrderGen.Report
  ( report_batch_result
  ) where

import Network.Ethereum.Api.Types (TxReceipt (..))

report_batch_result :: (TxReceipt, [(Bool, Integer)]) -> IO ()
report_batch_result (receipt, results) = do
  putStrLn ("batch   tx " ++ show (receiptTransactionHash receipt))
  putStrLn ("        " ++ show succeeded ++ " succeeded, " ++ show failed
                       ++ " failed (of " ++ show total ++ ")")
  mapM_ report_entry (zip [1 :: Int ..] results)
  where
    total     = length results
    succeeded = length (filter fst results)
    failed    = total - succeeded

report_entry :: (Int, (Bool, Integer)) -> IO ()
report_entry (position, (True, order_id)) =
  putStrLn ("  order " ++ show position ++ " OK      id " ++ show order_id)
report_entry (position, (False, _)) =
  putStrLn ("  order " ++ show position ++ " SKIPPED")
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
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate
                    , StochasticPriceGen.Report
                    , StochasticPriceGen.Rpc
                    , StochasticOrderGen.Types
                    , StochasticOrderGen.Simulate
                    , StochasticOrderGen.Report
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task6-build.log
grep -i warning /tmp/sog-task6-build.log || echo "no warnings"
```

- [ ] **Step 4: Commit**

```bash
git add offchain/lib/StochasticOrderGen/Report.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticOrderGen.Report IO formatting"
```

---

### Task 7: `StochasticOrderGen.Rpc` — orchestration and chunking

**Files:**
- Create: `offchain/lib/StochasticOrderGen/Rpc.hs`
- Modify: `cfmm-replicationPlank-rpc-api.cabal` (library `exposed-modules` only)

**Interfaces:**
- Consumes: `create_orders :: Address -> Address -> [VolOrder] -> Web3 (TxReceipt,
  [(Bool, Integer)])` (Task 3); `simulate_batch_count` (Task 5); `report_batch_result`
  (Task 6); `ArrivalProcess(..)`, `StochasticOrderGen(..)` (Task 4).
- Produces: `run_order_gen :: Address -> Address -> StochasticOrderGen -> GenIO -> Web3
  [(TxReceipt, [(Bool, Integer)])]` (no printing — reusable); `run_order_gen_and_report
  :: Address -> Address -> StochasticOrderGen -> GenIO -> IO ()`. Task 8's `Main.hs`
  calls the bare `run_order_gen`.

`run_order_gen` draws `N` via `simulate_batch_count`, fails clearly if `N > length
(orders config)` (decision 4, zero RPC calls made before this check), otherwise takes
the first `N` orders and splits them into `≤128`-sized chunks, folding
`VolOrder.Rpc.create_orders` sequentially over the chunks via `mapM` (decision 8 — `mapM`
in the `Web3` monad executes left-to-right, exactly the strict sequential fold the
design requires, never concurrent).

- [ ] **Step 1: Create `StochasticOrderGen.Rpc`**

```haskell
module StochasticOrderGen.Rpc
  ( run_order_gen
  , run_order_gen_and_report
  ) where

import Control.Monad.IO.Class (liftIO)

import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (TxReceipt)
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')
import System.Random.MWC (GenIO)

import StochasticOrderGen.Report (report_batch_result)
import StochasticOrderGen.Simulate (simulate_batch_count)
import StochasticOrderGen.Types (StochasticOrderGen (..))
import VolOrder.Rpc (create_orders)

max_batch :: Int
max_batch = 128

run_order_gen
  :: Address
  -> Address
  -> StochasticOrderGen
  -> GenIO
  -> Web3 [(TxReceipt, [(Bool, Integer)])]
run_order_gen owner manager config gen = do
  batch_count <- liftIO (simulate_batch_count gen (arrival_process config))

  if batch_count > length (orders config)
    then fail ("run_order_gen: Poisson draw requested " ++ show batch_count
                ++ " orders but only " ++ show (length (orders config)) ++ " were supplied")
    else mapM (create_orders owner manager) (chunk max_batch (take batch_count (orders config)))

chunk :: Int -> [a] -> [[a]]
chunk _ [] = []
chunk n xs = take n xs : chunk n (drop n xs)

run_order_gen_and_report :: Address -> Address -> StochasticOrderGen -> GenIO -> IO ()
run_order_gen_and_report owner manager config gen = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (run_order_gen owner manager config gen)

  case result of
    Left web3_error     -> putStrLn ("rpc error: " ++ show web3_error)
    Right chunk_results -> mapM_ report_batch_result chunk_results
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
                    , StochasticPriceGen.Types
                    , StochasticPriceGen.Simulate
                    , StochasticPriceGen.Report
                    , StochasticPriceGen.Rpc
                    , StochasticOrderGen.Types
                    , StochasticOrderGen.Simulate
                    , StochasticOrderGen.Report
                    , StochasticOrderGen.Rpc
```

- [ ] **Step 3: Build and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build lib:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task7-build.log
grep -i warning /tmp/sog-task7-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings. At this point the full library (`VolOrder.*`,
`PriceSetter.*`, `StochasticPriceGen.*`, `StochasticOrderGen.*`) builds; the executable
still runs the old `Main.hs`.

- [ ] **Step 4: `cabal repl` smoke test — `N > length orders` guard, zero RPC calls**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import Data.Solidity.Prim.Address (Address)
import Network.Web3.Provider (Provider(HttpProvider), runWeb3')
import StochasticOrderGen.Rpc (run_order_gen)
import StochasticOrderGen.Types (ArrivalProcess(..), StochasticOrderGen(..))
import System.Random.MWC (create)
import VolOrder.Types (VolOrder(..))

let owner = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" :: Address
let manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3" :: Address
let one_order = [ VolOrder { vol_target = 1000, range_width = 60, skew = 500 } ]
let over_config = StochasticOrderGen { arrival_process = Poisson { lambda = 50.0 }, orders = one_order }
gen <- create
result <- runWeb3' (HttpProvider "http://127.0.0.1:8545") (run_order_gen owner manager over_config gen)
print result
:quit
EOF
```

Expected: `Left (something mentioning "Poisson draw requested ... but only 1 were
supplied")` — with `λ = 50.0` against a single-element `orders` list, the Poisson draw
is virtually certain to exceed 1, so the guard should fire on essentially every run.
This confirms the failure happens with no RPC calls made (the guard runs before
`create_orders` is ever reached — no anvil node needs to be live for this check to
either pass or fail correctly, since `runWeb3'` only opens a connection lazily when an
actual RPC action executes). If it unexpectedly prints `Right [...]` instead (the rare
case the draw came back `<= 1`), re-run — `λ = 50.0` makes this effectively never
happen twice in a row.

- [ ] **Step 5: Commit**

```bash
git add offchain/lib/StochasticOrderGen/Rpc.hs cfmm-replicationPlank-rpc-api.cabal
git commit -m "feat: add StochasticOrderGen.Rpc orchestration and chunking"
```

---

### Task 8: Wire `Sample.hs`, `Main.hs`, and the executable stanza

**Files:**
- Modify: `offchain/app/Sample.hs` (add `sample_orders`, `sample_order_gen`)
- Modify: `offchain/app/Main.hs` (extend the composition)

**Interfaces:**
- Consumes: `run_order_gen` (Task 7), `report_batch_result` (Task 6),
  `ArrivalProcess(..)`/`StochasticOrderGen(..)` (Task 4), plus the existing
  `create_order`, `write_price`, `run_price_gen`, and their `Report` functions.
- Produces: nothing further downstream — Task 9 verifies this task's output live.

`sample_orders` supplies ten distinct, always-valid orders — comfortably more than
`sample_order_gen`'s expected batch size (`λ = 3.0`), so an ordinary `cabal run` demo
essentially never trips `run_order_gen`'s "N > length orders" guard. This is expected
behavior, not a workaround: a rare large Poisson draw exceeding 10 *should* fail loudly
per that guard, exactly as designed — the sample data is just sized to make that rare
in an ordinary demo run, mirroring `sample_price_gen`'s "safe by default" convention.

- [ ] **Step 1: Update `offchain/app/Sample.hs`**

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_orders
  , sample_order_gen
  , sample_price_gen
  , sample_tick
  ) where

import Data.Solidity.Prim.Address (Address)

import StochasticOrderGen.Types (ArrivalProcess (..), StochasticOrderGen (..))
import StochasticPriceGen.Types (ProcessType (..), StochasticPriceGen (..))
import VolOrder.Types (VolOrder (..))

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

price_setter_hook :: Address
price_setter_hook = "0x78f77B581417489BABC51CC63091db140962B000"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }

-- Ten distinct, always-valid orders -- comfortably more than
-- sample_order_gen's expected batch size (lambda = 3.0), so an ordinary
-- cabal run demo essentially never trips run_order_gen's "N > length orders"
-- guard (StochasticOrderGen.Rpc, decision 4). A rare large Poisson draw
-- exceeding 10 SHOULD fail loudly per that guard -- this is expected
-- behaviour, not a bug, if it ever happens on a demo run.
sample_orders :: [VolOrder]
sample_orders =
  [ VolOrder { vol_target = 1000 + n, range_width = 60, skew = 500 + n }
  | n <- [0, 10 .. 90]
  ]

-- Small lambda relative to sample_orders' length (10) -- deliberately
-- unlikely to trip run_order_gen's "N > length orders" guard on an ordinary
-- demo run, mirroring sample_price_gen's "safe by default" convention.
sample_order_gen :: StochasticOrderGen
sample_order_gen =
  StochasticOrderGen
    { arrival_process = Poisson { lambda = 3.0 }
    , orders          = sample_orders
    }

-- Nonzero and a multiple of the deployed pool's tickSpacing (60), so the demo
-- visibly moves state away from PriceSetterHookScript's initial tick = 0.
sample_tick :: Integer
sample_tick = 60

-- Small sigma relative to dt = 1.0 -- deliberately unlikely to trip
-- StochasticPriceGen.Simulate's domain guard on an ordinary demo run.
-- initial_tick matches sample_tick so the simulated path continues from where
-- the preceding write_price demo call leaves the pool.
sample_price_gen :: StochasticPriceGen
sample_price_gen =
  StochasticPriceGen
    { process      = GBM { mu = 0.0, sigma = 0.05 }
    , size         = 5
    , initial_tick = 60
    , dt           = 1.0
    }
```

- [ ] **Step 2: Replace `offchain/app/Main.hs` entirely**

```haskell
module Main where

import System.Random.MWC (createSystemRandom)

import Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_order_gen
  , sample_price_gen
  , sample_tick
  )
import Network.Web3.Provider (Provider (HttpProvider), runWeb3')
import PriceSetter.Report (report_price_write)
import PriceSetter.Rpc (write_price)
import StochasticOrderGen.Report (report_batch_result)
import StochasticOrderGen.Rpc (run_order_gen)
import StochasticPriceGen.Report (report_path_write)
import StochasticPriceGen.Rpc (run_price_gen)
import VolOrder.Report (report_receipt)
import VolOrder.Rpc (create_order)

main :: IO ()
main = do
  -- Created before entering the Web3 action (main is already IO, so no
  -- liftIO is needed here) -- run_price_gen/run_order_gen below just take
  -- the resulting GenIO value, consuming its random stream sequentially.
  gen <- createSystemRandom

  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (do receipt <- create_order account order_manager sample_order
          written <- write_price price_setter_hook sample_tick
          path_written <- run_price_gen price_setter_hook sample_price_gen gen
          batch_results <- run_order_gen account order_manager sample_order_gen gen
          pure (receipt, written, path_written, batch_results))

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right (receipt, written, path_written, batch_results) -> do
      report_receipt receipt
      report_price_write written
      report_path_write path_written
      mapM_ report_batch_result batch_results
```

- [ ] **Step 3: Build the whole package and confirm zero warnings**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal build exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task8-build.log
grep -i warning /tmp/sog-task8-build.log || echo "no warnings"
```

Expected: build succeeds, no warnings. No cabal file changes are needed for the
executable stanza — it already depends on the whole library, and `mwc-random`/
`web3-provider`/`web3-solidity` are already present from the `StochasticPriceGen` work.

- [ ] **Step 4: Commit**

```bash
git add offchain/app/Sample.hs offchain/app/Main.hs
git commit -m "feat: wire StochasticOrderGen into Main.hs"
```

---

### Task 9: End-to-end verification

**Files:** none (verification only).

**Interfaces:** none.

This task exercises the spec's Testing steps 4–9 against the live rig, plus a final
full-demo smoke test. It reuses the anvil node and deployed `VolOrderManager` from the
prior `create_order`/`write_price` work.

- [ ] **Step 1: Confirm the anvil node and deployed rig are still live**

```bash
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"web3_clientVersion","params":[]}'
curl -s -m 3 -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x5FbDB2315678afecb367f032d93F642f64180aa3","latest"]}'
```

Expected: an `anvil/...` result, and a non-`"0x"` `result` for the order manager's
code. If either fails, redeploy fresh per the fixed order documented in the
`write_price` plan (`docs/superpowers/plans/2026-07-18-write-price-implementation.md`,
Task 5) before continuing — treat a mismatched `order_manager` address as a blocker,
not something to silently substitute around in `Sample.hs`.

- [ ] **Step 2: `>128`-order chunking test**

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import Data.Solidity.Prim.Address (Address)
import Network.Web3.Provider (Provider(HttpProvider), runWeb3')
import StochasticOrderGen.Rpc (run_order_gen)
import StochasticOrderGen.Types (ArrivalProcess(..), StochasticOrderGen(..))
import System.Random.MWC (create)
import VolOrder.Types (VolOrder(..))

let owner = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" :: Address
let manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3" :: Address
let many_orders = [ VolOrder { vol_target = 1000 + n, range_width = 60, skew = 500 + (n `mod` 60000) } | n <- [1 .. 150] ]
let big_config = StochasticOrderGen { arrival_process = Poisson { lambda = 145.0 }, orders = many_orders }
gen <- create
result <- runWeb3' (HttpProvider "http://127.0.0.1:8545") (run_order_gen owner manager big_config gen)
case result of
  Left err -> print err
  Right chunks -> print (length chunks, map (length . snd) chunks)
:quit
EOF
```

Expected: `Right (n_chunks, chunk_sizes)` where `n_chunks >= 2` and every element of
`chunk_sizes` is `<= 128` (confirms the batch was actually split into multiple
sequential `create_orders` calls, never one oversized call). `Poisson(145)` draws above
128 with high probability but not certainty — if the printed `n_chunks` is `1` (a rare
draw `<= 128`), re-run with a fresh `Gen` (re-run the whole block) until a draw above
128 is observed. If this instead prints a `Left` error, read it: an out-of-gas or
revert on a valid 128-order chunk is a real finding (the plan's `callGas = Nothing`
should defer to node estimation even for a ~10M-gas chunk per the spec's ground
truth) — do not treat it as flaky and retry past it.

- [ ] **Step 3: Live `create_orders` run with a deliberately on-chain-invalid order —
      best-effort behavior and mined-readback consistency**

`skew = 65535` passes `pack_vol_order_input`'s Haskell-side bit-width check (`0 < skew
< 2^16` — `65535 < 65536`) but fails the contract's own business-rule validation
(`spread_tick_assimetry_is_complete` requires `skew` in `[1, 65534]`, excluding
`65535`) — this is a genuine "valid shape, rejected by contract logic" case, distinct
from anything `pack_vol_order_input` itself catches.

```bash
cd /home/jmsbpp/cfmms-playground/cfmm-wt/rpc_api
cabal repl lib:cfmm-replicationPlank-rpc-api <<'EOF'
:set -XOverloadedStrings
import Data.Solidity.Prim.Address (Address)
import Network.Web3.Provider (Provider(HttpProvider), runWeb3')
import VolOrder.Rpc (create_orders)
import VolOrder.Types (VolOrder(..))

let owner = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" :: Address
let manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3" :: Address
let good1 = VolOrder { vol_target = 2000, range_width = 60, skew = 111 }
let bad   = VolOrder { vol_target = 2001, range_width = 60, skew = 65535 }
let good2 = VolOrder { vol_target = 2002, range_width = 60, skew = 222 }
result <- runWeb3' (HttpProvider "http://127.0.0.1:8545") (create_orders owner manager [good1, bad, good2])
print result
:quit
EOF
```

Expected: `Right (receipt, [(True,_id1),(False,0),(True,_id2)])` — the invalid order at
position 2 (index 1) comes back `(False, 0)` without reverting the rest of the chunk
(Testing step 4). The fact that this call returns `Right (...)` at all — rather than
`Left`/an uncaught `fail` from inside `create_orders` — **is** the confirmation of
Testing step 8: `create_orders` itself asserts the preview's successful ids match the
`orderCount()` delta and that each mined order's unpacked content matches its input
before ever returning successfully, per Task 3's design. If this instead fails with a
`create_orders: mined order ... does not match` or `... preview predicted successful
order ids ...` message, that is a real finding about the sequential-id-assignment
assumption documented in Task 3 — do not silently patch around it without
understanding why it diverged.

- [ ] **Step 4: Confirm the fully-wired demo runs end-to-end without crashing**

```bash
cabal run -v0 exe:cfmm-replicationPlank-rpc-api 2>&1 | tee /tmp/sog-task9-run.log
```

Expected: the `create_order` receipt block, the `write_price` block, a `path
WRITTEN (5 observations)` block, and one or more `batch   tx ...` blocks (one per
chunk `run_order_gen` sent — with `sample_order_gen`'s `λ = 3.0` against 10 supplied
orders, this is virtually always exactly one chunk) each followed by a `succeeded /
failed` summary line and per-order `OK`/`SKIPPED` lines — no `rpc error:` line.

```bash
grep -c "batch   tx" /tmp/sog-task9-run.log
grep -c "rpc error:" /tmp/sog-task9-run.log
```

Expected: first command prints `1` or more, second prints `0`.

No commit for this task — verification only. If any step fails, fix the implementation
in the relevant earlier task and re-run this task from the failing step.
