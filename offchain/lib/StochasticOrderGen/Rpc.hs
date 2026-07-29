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

-- Failure caveat (same MonadFail characteristic documented in PriceSetter.Rpc):
-- a `fail` here or inside create_orders surfaces as an uncaught IOException, NOT
-- as runWeb3'/run_order_gen_and_report's Left -- and unlike the single-call
-- modules, it can fire MID-FOLD, after earlier chunks' transactions have already
-- been mined. The on-chain state those chunks committed is not rolled back and
-- their receipts are lost with the exception.
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
