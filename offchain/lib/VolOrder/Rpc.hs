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
