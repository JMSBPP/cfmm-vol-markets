module PriceSetter.Report
  ( report_price_write
  ) where

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

report_price_write :: (Address, HexString, HexString) -> IO ()
report_price_write (pool_manager, slot, value) = do
  putStrLn "price   WRITTEN"
  putStrLn ("  poolManager " ++ show pool_manager)
  putStrLn ("  slot        " ++ show slot)
  putStrLn ("  value       " ++ show value)
