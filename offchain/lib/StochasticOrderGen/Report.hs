module StochasticOrderGen.Report
  ( report_batch_result
  ) where

import Network.Ethereum.Api.Types (Quantity, TxReceipt (..))

report_batch_result :: (TxReceipt, [(Bool, Integer)]) -> IO ()
report_batch_result (receipt, results) = do
  putStrLn ("batch   tx " ++ show (receiptTransactionHash receipt))
  putStrLn ("        status " ++ status_text (receiptStatus receipt))
  putStrLn ("        " ++ show succeeded ++ " succeeded, " ++ show failed
                       ++ " failed (of " ++ show total ++ ")")
  mapM_ report_entry (zip [1 :: Int ..] results)
  where
    total     = length results
    succeeded = length (filter fst results)
    failed    = total - succeeded

status_text :: Maybe Quantity -> String
status_text (Just 1) = "success"
status_text (Just 0) = "reverted"
status_text other    = "unknown " ++ show other

report_entry :: (Int, (Bool, Integer)) -> IO ()
report_entry (position, (True, order_id)) =
  putStrLn ("  order " ++ show position ++ " OK      id " ++ show order_id)
report_entry (position, (False, _)) =
  putStrLn ("  order " ++ show position ++ " SKIPPED")
