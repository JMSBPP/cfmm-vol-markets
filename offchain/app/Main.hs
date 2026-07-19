module Main where

import System.Random.MWC (createSystemRandom)

import Sample
  ( account
  , order_manager
  , price_setter_hook
  , sample_order
  , sample_price_gen
  , sample_tick
  )
import Network.Web3.Provider (Provider (HttpProvider), runWeb3')
import PriceSetter.Report (report_price_write)
import PriceSetter.Rpc (write_price)
import StochasticPriceGen.Report (report_path_write)
import StochasticPriceGen.Rpc (run_price_gen)
import VolOrder.Report (report_receipt)
import VolOrder.Rpc (create_order)

main :: IO ()
main = do
  -- Created before entering the Web3 action (main is already IO, so no liftIO
  -- is needed here) -- run_price_gen below just takes the resulting GenIO value.
  gen <- createSystemRandom

  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (do receipt <- create_order account order_manager sample_order
          written <- write_price price_setter_hook sample_tick
          path_written <- run_price_gen price_setter_hook sample_price_gen gen
          pure (receipt, written, path_written))

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right (receipt, written, path_written) -> do
      report_receipt receipt
      report_price_write written
      report_path_write path_written
