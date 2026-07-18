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
