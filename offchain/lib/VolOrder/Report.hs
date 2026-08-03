module VolOrder.Report
  ( report_receipt
  , decode_e1_from
  ) where

import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (Change (..), Quantity, TxReceipt (..))

import VolOrder.Decode (OrderCreatedEvent (..), decode_order_created)

-- The first argument is the pinned E1 topic0 -- the topics."VolOrderCreated" entry of the
-- generated offchain/rig/rig-pins.json -- threaded straight through to the decoder. This module
-- holds no topic literal of its own.
--
-- The second is the address E1 must have been emitted FROM, and the filter it feeds is MANDATORY
-- rather than defensive -- the same rule, and the same reason, as the E3/E5 filter in
-- CheatSwap.Rpc. topic0 identifies an EVENT SIGNATURE, not an emitter: any contract in any receipt
-- may emit the same 32 bytes, and a decode that matched on topic0 alone would report that log as a
-- VolOrderCreated with an orderId lifted out of whatever its second topic happened to be. The
-- payload-length guard in the decoder does not close it either -- it rejects a SHORT payload, not a
-- long enough one from the wrong contract. Only the emitting address separates them, and it is
-- carried in every log.
report_receipt :: Integer -> Address -> TxReceipt -> IO ()
report_receipt topic_e1 emitter receipt = do
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
    logs -> mapM_ (report_log topic_e1 emitter) logs

status_text :: Maybe Quantity -> String
status_text (Just 1) = "success"
status_text (Just 0) = "reverted"
status_text other    = "unknown " ++ show other

report_log :: Integer -> Address -> Change -> IO ()
report_log topic_e1 emitter log_entry =
  case decode_e1_from topic_e1 emitter log_entry of
    Just event -> report_order_created event
    Nothing    -> do
      putStrLn ("log     from " ++ show (changeAddress log_entry))
      mapM_ (putStrLn . ("  topic " ++) . show) (changeTopics log_entry)
      putStrLn ("  data  " ++ show (changeData log_entry))

-- V2 field set. There is no owner and no timestamp: the emitter is @evm_log2 with orderId as its
-- only indexed topic, so neither value is in the log at all. Printing them would have meant
-- inventing them.
report_order_created :: OrderCreatedEvent -> IO ()
report_order_created event = do
  putStrLn "log     ORDER_CREATED"
  putStrLn ("  order_id    " ++ show (orderId event))
  putStrLn ("  strike      " ++ show (orderStrike event))
  putStrLn ("  width       " ++ show (orderRangeWidth event))
  putStrLn ("  skew        " ++ show (orderSkew event))
  putStrLn ("  target_vega " ++ show (orderTargetVega event))

-- | 'VolOrder.Decode.decode_order_created' with the emitting address required to match.
--
-- Exported because the driver's own capture needs the identical predicate and had been matching on
-- topic0 alone. Two call sites deriving "is this an E1" separately is how the two drift.
decode_e1_from :: Integer -> Address -> Change -> Maybe OrderCreatedEvent
decode_e1_from topic_e1 emitter log_entry
  | changeAddress log_entry == emitter = decode_order_created topic_e1 log_entry
  | otherwise                          = Nothing
