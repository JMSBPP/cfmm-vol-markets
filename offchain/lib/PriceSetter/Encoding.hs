module PriceSetter.Encoding
  ( encode_pool_manager
  , encode_slot0_slot
  , encode_pack_slot0_for
  ) where

import Data.ByteArray.HexString (HexString)
import Data.String (fromString)
import System.Process (readProcess)

encode_pool_manager :: IO HexString
encode_pool_manager = encode_call "poolManager()" []

encode_slot0_slot :: IO HexString
encode_slot0_slot = encode_call "slot0Slot()" []

encode_pack_slot0_for :: Integer -> IO HexString
encode_pack_slot0_for tick = encode_call "packSlot0For(int24)" [show tick]

encode_call :: String -> [String] -> IO HexString
encode_call signature args = do
  raw <- readProcess "cast" ("calldata" : signature : args) ""
  pure (fromString (trim raw))

trim :: String -> String
trim = unwords . words
