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
import StochasticOrderGen.Simulate (draw_target_vega, simulate_batch_count)
import StochasticOrderGen.Types (OrderShape (..), StochasticOrderGen (..), VegaDraw)
import VolOrder.Rpc (create_orders)
import VolOrder.Types (VolOrder (..))

max_batch :: Int
max_batch = 128

-- Failure caveat (same MonadFail characteristic documented in PriceSetter.Rpc):
-- a `fail` here or inside create_orders surfaces as an uncaught IOException, NOT
-- as runWeb3'/run_order_gen_and_report's Left -- and unlike the single-call
-- modules, it can fire MID-FOLD, after earlier chunks' transactions have already
-- been mined. The on-chain state those chunks committed is not rolled back and
-- their receipts are lost with the exception.
--
-- draw_target_vega's guard is NOT in that category: it fires BEFORE any transaction
-- is built, so a mis-parameterised VegaDraw cannot leave a partially-sent batch
-- behind -- unlike a mid-fold create_orders failure, which can.
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
                ++ " orders but only " ++ show (length (orders config))
                ++ " order shapes were supplied")
    else do
      let shapes = take batch_count (orders config)
      built <- liftIO (mapM (attach_vega gen (vega_draw config)) shapes)
      mapM (create_orders owner manager) (chunk max_batch built)

-- | Pair one supplied 'OrderShape' with one drawn @targetVega@ to make a sendable 'VolOrder'.
--
-- The draw happens ONCE PER ORDER AT GENERATION TIME, before any transaction is built -- not
-- per send. A retried send therefore re-sends the SAME order rather than silently re-rolling the
-- value it is retrying, which would make a retry indistinguishable from a new order.
attach_vega :: GenIO -> VegaDraw -> OrderShape -> IO VolOrder
attach_vega gen law shape = do
  v <- draw_target_vega gen law
  pure VolOrder
    { vol_target  = shape_vol_target shape
    , range_width = shape_range_width shape
    , skew        = shape_skew shape
    , target_vega = fromInteger v
    }

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
