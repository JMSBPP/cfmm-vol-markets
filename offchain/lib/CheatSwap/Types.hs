-- | RED STATE (TDD). The two naive choices a reader of Slot0.sol and TickMath.sol makes first:
-- the word is composed at the SQRT-PRICE boundary (160) rather than at the FEE boundary (184),
-- and the cheat tick is admitted over TickMath's full +-887272 domain rather than over the
-- rig's one full-range position. Both are the subject of the failing check
-- @driv01_slot0_composition_behavior@; the GREEN commit supplies the 184 mask, the G4 domain and
-- the haddock explaining why each boundary is where it is.
module CheatSwap.Types
  ( pools_slot
  , pool_state_slot
  , compose_slot0
  , check_cheat_tick
  , word32be
  ) where

import Crypto.Ethereum.Utils (keccak256)
import Data.Bits (complement, shiftL, shiftR, (.&.), (.|.))
import qualified Data.ByteString as BS

import VolOrder.Decode (be_integer)

pools_slot :: Integer
pools_slot = 6

word32be :: Integer -> BS.ByteString
word32be n = BS.pack [fromIntegral ((n `shiftR` (8 * i)) .&. 0xff) | i <- [31, 30 .. 0]]

pool_state_slot :: Integer -> Integer
pool_state_slot pool_id =
  be_integer (keccak256 (word32be pool_id <> word32be pools_slot))

compose_slot0 :: Integer -> Integer -> Integer
compose_slot0 current_word pack_slot0_for_word =
  (current_word .&. complement low_bits) .|. (pack_slot0_for_word .&. low_bits)
  where
    low_bits = (1 `shiftL` 160) - 1

check_cheat_tick :: Integer -> Either String Integer
check_cheat_tick tick
  | tick < negate 887272 || tick > 887272 = Left "tick outside TickMath"
  | otherwise                             = Right tick
