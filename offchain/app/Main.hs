module Main where

import Sample (account, order_manager, sample_order)
import VolOrder.Rpc (create_order_and_report)

main :: IO ()
main = create_order_and_report account order_manager sample_order
