module Main where

import Network.Web3.Provider
import qualified Network.Ethereum.Api.Eth as GLOBAL_STATE

main :: IO ()
main =
  print =<< runWeb3' (HttpProvider "http://127.0.0.1:8545") GLOBAL_STATE.blockNumber