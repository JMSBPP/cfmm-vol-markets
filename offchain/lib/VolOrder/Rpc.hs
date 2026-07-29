module VolOrder.Rpc
  ( create_order
  , create_order_and_report
  , create_orders
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

      preview_raw <- eth_call_manager manager Latest calldata
      preview <- either fail pure (decode_create_orders_result preview_raw)
      when (length preview /= length orders) $
        fail ("create_orders: preview returned " ++ show (length preview)
               ++ " results for a batch of " ++ show (length orders) ++ " orders")

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

create_order_and_report :: Address -> Address -> VolOrder -> IO ()
create_order_and_report owner manager vol_order = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (create_order owner manager vol_order)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right receipt   -> report_receipt receipt
