module PriceSetter.Decode
  ( decode_address
  ) where

import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Solidity.Prim.Address (Address, fromHexString)

-- ABI-encoded address return values are right-aligned in a 32-byte word,
-- left-padded with 12 zero bytes.
decode_address :: HexString -> Either String Address
decode_address raw = fromHexString (fromBytes (BS.drop 12 (toBytes raw)))
