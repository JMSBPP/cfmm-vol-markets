{-# LANGUAGE OverloadedStrings #-}

module PriceSetter.Rpc
  ( write_price
  , write_price_and_report
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (Value)

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Ethereum.Api.Types (Call (..), DefaultBlock (Latest))
import Network.JsonRpc.TinyClient (remote)
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import PriceSetter.Decode (decode_address)
import PriceSetter.Encoding
  ( encode_pack_slot0_for
  , encode_pool_manager
  , encode_slot0_slot
  )
import PriceSetter.Report (report_price_write)

-- write_price's only reachable on-chain failure is NotBound (via packSlot0For's
-- internal onlyBound gate on readSlot0) if price_setter_hook is unbound or wrong.
-- write_price only ever reads via eth_call plus the anvil_setStorageAt node cheat;
-- it never calls sendTransaction, since a hook cannot write PoolManager storage
-- through a normal transaction.
--
-- Caller obligation (not enforced here, per PriceSetterHook.sol's own doc comment):
-- a slot0 write is only coherent for pools with no liquidity or full-range-only
-- liquidity. Do not call this against a hook bound to a pool with interior
-- initialized-tick liquidity -- an imposed tick crossing such a boundary leaves
-- liquidity/fee accounting stale.
--
-- Observed (2026-07-18, against a hook address with no deployed code): throws an
-- uncaught exception, crashing the process/session -- "user error (Incorrect
-- address length: 0)". This comes from decode_address's `either fail pure` above:
-- an eth_call against an address with no code returns empty calldata ("0x"), which
-- decode_address cannot parse as an address, so it fails; that failure surfaces via
-- the Web3 monad's MonadFail instance as an IO exception that is NOT a Web3Error,
-- so it escapes runWeb3'/write_price_and_report's `Left` handling entirely. Not the
-- NotBound/eth_call-JsonRpcException path hypothesized above -- a different,
-- earlier failure point with the same practical consequence (uncaught, not Left).
write_price :: Address -> Integer -> Web3 (Address, HexString, HexString)
write_price hook tick = do
  pool_manager_raw <- eth_call_hook hook =<< liftIO encode_pool_manager
  pool_manager <- either fail pure (decode_address pool_manager_raw)

  slot <- eth_call_hook hook =<< liftIO encode_slot0_slot
  value <- eth_call_hook hook =<< liftIO (encode_pack_slot0_for tick)

  _ <- anvil_set_storage_at pool_manager slot value
  pure (pool_manager, slot, value)

eth_call_hook :: Address -> HexString -> Web3 HexString
eth_call_hook hook calldata =
  GlobalState.call
    Call
      { callFrom = Nothing
      , callTo = Just hook
      , callGas = Nothing
      , callGasPrice = Nothing
      , callValue = Nothing
      , callData = Just calldata
      , callNonce = Nothing
      }
    Latest

anvil_set_storage_at :: Address -> HexString -> HexString -> Web3 Value
anvil_set_storage_at = remote "anvil_setStorageAt"

write_price_and_report :: Address -> Integer -> IO ()
write_price_and_report hook tick = do
  result <-
    runWeb3'
      (HttpProvider "http://127.0.0.1:8545")
      (write_price hook tick)

  case result of
    Left web3_error -> putStrLn ("rpc error: " ++ show web3_error)
    Right written    -> report_price_write written
