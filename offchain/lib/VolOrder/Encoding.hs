module VolOrder.Encoding
  ( encode_create_order
  ) where

import Data.ByteArray.HexString (HexString)
import Data.String (fromString)
import System.Process (readProcess)

import VolOrder.Types (VolOrder(..))

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
