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
