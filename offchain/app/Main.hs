{-# LANGUAGE OverloadedStrings #-}

module Main where

import System.Process (readProcess)
import Data.ByteArray.HexString.Internal (HexString)
import Data.String (fromString)

import Network.Web3.Provider
import Network.Ethereum.Api.Types
import qualified Network.Ethereum.Api.Eth as GlobalState

import Data.Solidity.Prim.Address

data VolOrder = VolOrder
  { vol_target  :: Quantity
  , range_width :: Quantity
  , skew        :: Quantity
  }

account :: Address
account = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

order_manager :: Address
order_manager = "0x5FbDB2315678afecb367f032d93F642f64180aa3"

sample_order :: VolOrder
sample_order =
  VolOrder
    { vol_target = 1000
    , range_width = 60
    , skew = 500
    }

main :: IO ()
main = create_order account order_manager sample_order

create_order :: Address -> Address -> VolOrder -> IO ()
create_order owner manager vol_order = do
  calldata <- encode_create_order vol_order

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

  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (GlobalState.sendTransaction create_order_call)

  print result

encode_create_order :: VolOrder -> IO HexString
encode_create_order order = do
  raw <-
    readProcess
      "cast"
      [ "calldata"
      , "create_order(uint88,uint24,uint16)"
      , show (vol_target order)
      , show (range_width order)
      , show (skew order)
      ]
      ""

  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words