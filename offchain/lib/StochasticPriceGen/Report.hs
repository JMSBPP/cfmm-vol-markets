module StochasticPriceGen.Report
  ( report_path_write
  ) where

import Data.ByteArray.HexString (HexString)
import Data.Solidity.Prim.Address (Address)

report_path_write :: [(Address, HexString, HexString)] -> IO ()
report_path_write written = do
  putStrLn ("path    WRITTEN (" ++ show (length written) ++ " observations)")
  mapM_ report_step (zip [1 :: Int ..] written)

report_step :: (Int, (Address, HexString, HexString)) -> IO ()
report_step (step_number, (pool_manager, slot, value)) = do
  putStrLn ("  step " ++ show step_number)
  putStrLn ("    poolManager " ++ show pool_manager)
  putStrLn ("    slot        " ++ show slot)
  putStrLn ("    value       " ++ show value)
