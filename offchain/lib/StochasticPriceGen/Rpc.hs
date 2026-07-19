module StochasticPriceGen.Rpc
  ( run_price_gen
  , run_price_gen_and_report
  ) where

import Control.Monad.IO.Class (liftIO)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')
import System.Random.MWC (GenIO)

import PriceSetter.Rpc (write_price)
import StochasticPriceGen.Report (report_path_write)
import StochasticPriceGen.Simulate (simulate_path)
import StochasticPriceGen.Types (StochasticPriceGen)

run_price_gen
  :: Address -> StochasticPriceGen -> GenIO -> Web3 [(Address, HexString, HexString)]
run_price_gen hook config gen = do
  ticks <- liftIO (simulate_path gen config)
  mapM (write_price hook) ticks

run_price_gen_and_report :: Address -> StochasticPriceGen -> GenIO -> IO ()
run_price_gen_and_report hook config gen = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (run_price_gen hook config gen)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right written    -> report_path_write written
