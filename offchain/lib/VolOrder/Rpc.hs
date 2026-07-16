module VolOrder.Rpc
  ( create_order
  , create_order_and_report
  , wait_for_receipt
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad.IO.Class (liftIO)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (Call (..), TxReceipt)
import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import VolOrder.Encoding (encode_create_order)
import VolOrder.Report (report_receipt)
import VolOrder.Types (VolOrder)

create_order :: Address -> Address -> VolOrder -> Web3 TxReceipt
create_order owner manager vol_order = do
  calldata <- liftIO (encode_create_order vol_order)

  let create_order_call :: Call
      create_order_call =
        Call
          { callFrom = Just owner
          , callTo = Just manager
          , callGas = Nothing
          , callGasPrice = Nothing
          , callValue = Nothing
          , callData = Just calldata
          , callNonce = Nothing
          }

  GlobalState.sendTransaction create_order_call >>= wait_for_receipt

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
