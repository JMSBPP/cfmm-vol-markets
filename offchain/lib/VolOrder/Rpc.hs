module VolOrder.Rpc
  ( create_order
  , create_order_and_report
  , create_orders
  , preview_create_orders
    -- * Readbacks
    --
    -- | Exported for the DRIV-02 evidence capture, which must RECORD @orderCount()@ and the packed
    -- storage word at a chosen block rather than only assert them. 'create_orders' already performs
    -- both reads internally and keeps neither, so a caller that wants the numbers in an artifact has
    -- no other path to them. They are ordinary reads with no side effects.
  , read_order_count
  , read_order_packed
  , wait_for_receipt
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (Call (..), DefaultBlock (..), TxReceipt (..))
import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import VolOrder.Decode
  ( check_minted_id_run
  , decode_create_orders_result
  , hex_to_integer
  , unpack_vol_order_storage
  )
import VolOrder.Encoding
  ( encode_create_order
  , encode_create_orders
  , encode_get_order_packed
  , encode_order_count
  )
import VolOrder.Report (report_receipt)
import VolOrder.Types (VolOrder)

-- | The STRICT single-order path. Unlike 'create_orders' this one is all-or-nothing on chain:
-- @validate_order_strict@ REVERTS rather than skipping the offending tuple.
--
-- And it reverts EMPTY. A rejected order comes back as a receipt with status 0, no logs and no
-- reason data — which, without the check below, this function handed to its caller as an ordinary
-- success. MEASURED against the live rig with @skew = 65535@ (width-valid, domain-invalid, so it
-- reaches the module and is rejected): @status=Just 0 logs=0@, returned normally.
--
-- 'create_orders' has carried this check since it was written, with the reason spelled out beside
-- it — \"a reverted batch is byte-identical to a healthy all-invalid one in the report\". The same
-- sentence is true here with \"all-invalid\" replaced by \"rejected\", and this was the one path
-- missing the three lines.
create_order :: Address -> Address -> VolOrder -> Web3 TxReceipt
create_order owner manager vol_order = do
  calldata <- liftIO (encode_create_order vol_order)
  receipt  <- send_and_wait owner manager calldata
  when (receiptStatus receipt /= Just 1) $
    fail ("create_order: transaction REVERTED -- tx "
           ++ show (receiptTransactionHash receipt)
           ++ ", status " ++ show (receiptStatus receipt)
           ++ ", order " ++ show vol_order
           ++ ". The strict single-order entrypoint reverts EMPTY on a rejected order: no logs, no"
           ++ " reason data, and a receipt otherwise indistinguishable from a successful one whose"
           ++ " event went undecoded. This is the only place that difference is visible.")
  pure receipt

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

      preview_raw <- eth_call_manager manager Latest calldata
      preview <- either fail pure (decode_create_orders_result preview_raw)
      when (length preview /= length orders) $
        fail ("create_orders: preview returned " ++ show (length preview)
               ++ " results for a batch of " ++ show (length orders) ++ " orders")

      -- The orderId HALF of the return, asserted here and nowhere else.
      --
      -- It is checked BEFORE the send, on the preview, and that is the strongest place available:
      -- the ids this function hands back to its caller ARE the preview's (see the `pure (receipt,
      -- preview)` at the end), a mined transaction carries no returndata to re-read them from, and
      -- failing here means nothing was sent. So there is no tx hash to name -- there is no tx.
      --
      -- Only the SHAPE is asserted; see 'check_minted_id_run' for why the base cannot be. Note this
      -- is deliberately NOT anchored to `before_count` below even though that read happens moments
      -- later: an unrelated writer landing between the preview and that read shifts the preview's
      -- base legitimately while leaving the run consecutive, and the count assertion further down
      -- is the check that owns THAT failure mode.
      either (\why -> fail (why ++ " Nothing was sent.")) pure (check_minted_id_run preview)

      before_count <- read_order_count manager Latest
      receipt <- send_and_wait owner manager calldata

      -- The batch entrypoint is best-effort per ORDER, but the transaction as a
      -- whole can still revert (e.g. out-of-gas past the preview's much higher
      -- default gas cap). Without this check a reverted batch is byte-identical
      -- to a healthy all-invalid one in the report.
      when (receiptStatus receipt /= Just 1) $
        fail ("create_orders: transaction reverted -- tx "
               ++ show (receiptTransactionHash receipt)
               ++ ", status " ++ show (receiptStatus receipt))

      -- Readbacks are pinned to the receipt's block, never Latest: on anything
      -- but a single-writer local node, Latest can be a lagging replica (the
      -- count reads as not-advanced) or a later tip (a third party's mints
      -- fold into our delta).
      let mined_block = BlockWithNumber (receiptBlockNumber receipt)
          tx_hash     = receiptTransactionHash receipt
      after_count <- read_order_count manager mined_block

      -- The consistency check anchors on the locally-read counter and the
      -- preview's success PATTERN -- never the preview's absolute ids. On-chain
      -- validation is stateless (a pure function of each packed word), so WHICH
      -- positions succeed is preview-stable; the minted ids are not, since any
      -- other writer landing between preview and send shifts the id base. Ids
      -- are 1-based: the contract mints id = orderCount + 1, then advances the
      -- count to that id (VolOrderManagerMod.plk, "Ids are sequential from 1
      -- and orderCount IS the id source"; slot 0 is never written), so our
      -- batch minted exactly [before_count + 1 .. before_count + successes].
      --
      -- The id half of each pair is a wildcard HERE on purpose: the ids the module returned were
      -- already asserted structurally above, and re-using them as the readback keys would make this
      -- readback derive its own targets from the thing it is checking. Recomputing them from the
      -- locally-read counter keeps the two sources independent.
      let successes      = [ o | (o, (True, _)) <- zip orders preview ]
          expected_after = before_count + toInteger (length successes)

      if after_count /= expected_after
        then fail
               ("create_orders: preview predicted " ++ show (length successes)
                 ++ " successful orders but orderCount() moved "
                 ++ show before_count ++ " -> " ++ show after_count
                 ++ " -- tx " ++ show tx_hash)
        else do
          mapM_ (verify_mined_order manager mined_block tx_hash)
                (zip successes [before_count + 1 ..])
          pure (receipt, preview)

-- | The batch preview ALONE: build @create_orders@ calldata and @eth_call@ it, handing back the RAW
-- returndata bytes without decoding them.
--
-- == WHY THIS EXISTS, AND WHY IT IS THE ONLY CHANNEL THAT CAN SHOW WHAT IT SHOWS
--
-- 'create_orders' already makes exactly this call, and then discards the raw bytes — it keeps only
-- the decoded @[(Bool, Integer)]@. That is the right shape for a caller PLACING orders and the wrong
-- shape for a caller MEASURING the return contract.
--
-- A MINED TRANSACTION CARRIES NO RETURNDATA. An @eth_getTransactionReceipt@ answer has logs, a
-- status, a block and gas figures, and no return value anywhere in it — the EVM's return buffer is
-- not part of the receipt and no node reconstructs it. So v4.0's exit record named the empty-batch
-- clause (@N = 0@ returns EXACTLY 64 bytes: the array offset word plus a zero length word, never 0
-- and never 32) as the single clause most likely to break a consumer, and that clause is observable
-- through THIS @eth_call@ and through nothing else on the transaction path. Any check that claims to
-- read the byte length off a mined @create_orders@ tx is wrong about where the bytes live.
--
-- Exposing the preview is deliberately cheaper and less invasive than widening 'create_orders' to
-- return its raw bytes: five call sites depend on that function's current type and not one of them
-- wants the bytes.
preview_create_orders :: Address -> [VolOrder] -> Web3 HexString
preview_create_orders manager orders = do
  calldata <- liftIO (encode_create_orders orders)
  eth_call_manager manager Latest calldata

verify_mined_order :: Address -> DefaultBlock -> HexString -> (VolOrder, Integer) -> Web3 ()
verify_mined_order manager block tx_hash (expected_order, order_id) = do
  packed <- read_order_packed manager block order_id
  let actual_order = unpack_vol_order_storage packed
  if actual_order == expected_order
    then pure ()
    else fail
           ("create_orders: mined order " ++ show order_id
             ++ " does not match the input submitted for it -- expected "
             ++ show expected_order ++ ", read back " ++ show actual_order
             ++ " -- tx " ++ show tx_hash)

read_order_count :: Address -> DefaultBlock -> Web3 Integer
read_order_count manager block = do
  calldata <- liftIO encode_order_count
  hex_to_integer <$> eth_call_manager manager block calldata

read_order_packed :: Address -> DefaultBlock -> Integer -> Web3 Integer
read_order_packed manager block order_id = do
  calldata <- liftIO (encode_get_order_packed order_id)
  hex_to_integer <$> eth_call_manager manager block calldata

eth_call_manager :: Address -> DefaultBlock -> HexString -> Web3 HexString
eth_call_manager manager block calldata =
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
    block

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

-- The pinned E1 topic0 comes in as the first argument and goes straight to report_receipt.
-- This module deliberately does NOT load the rig itself: VolOrder.Rpc imports no part of the rig
-- loader, so the manifest is read exactly once, at startup, by the driver.
create_order_and_report :: Integer -> Address -> Address -> VolOrder -> IO ()
create_order_and_report topic_e1 owner manager vol_order = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (create_order owner manager vol_order)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right receipt   -> report_receipt topic_e1 manager receipt
