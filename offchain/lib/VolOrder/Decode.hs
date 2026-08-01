module VolOrder.Decode
  ( OrderCreatedEvent(..)
  , decode_order_created
  , hex_to_integer
  , data_word
  , be_integer
  , decode_create_orders_result
  , unpack_vol_order_storage
  ) where

import Data.Bits (shiftL, shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Time.Clock (UTCTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)

import Network.Ethereum.Api.Types (Change (..))

import VolOrder.Types (VolOrder (..))

data OrderCreatedEvent = OrderCreatedEvent
  { orderOwner      :: HexString
  , orderCreatedAt  :: UTCTime
  , orderVolTarget  :: Integer
  , orderRangeWidth :: Integer
  , orderSkew       :: Integer
  } deriving (Eq, Show)

-- The E1 topic0 is a PARAMETER, supplied by the caller from the generated pin file
-- offchain/rig/rig-pins.json, under topics."VolOrderCreated". No topic0 literal lives in this
-- module.
--
-- It used to. The constant that sat here was hand-transcribed from a comment naming
-- src/modules/VolOrderManagerMod.plk -- a module that has since been superseded by
-- src/modules/pos_spec/VolOrderManagerMod.plk -- and it went stale without any symptom, because
-- a wrong topic0 does not look wrong: it simply matches no log, so decoding "succeeds" at
-- reporting nothing. Taking the value as an argument is what makes that impossible to repeat.
-- Note it is an ARGUMENT rather than an import of the rig loader, on purpose: this decode module
-- acquires no IO dependency and stays testable from pure values.
--
-- The stale constant itself is not lost. rig-pins.json's `retired` block records it, and
-- Phase 21 (RPIN-04) must prove the pin check REJECTS it.
--
-- The log layout below is the v1 shape (3 topics [topic0, owner, blockTimestamp]; data of five
-- 32-byte words [32, 96, volTarget, rangeWidth, skew]) and is deliberately left UNTOUCHED here.
-- Re-pinning the decoder to the v2 VolOrderCreated shape is Phase 21's work, not this purge's.
decode_order_created :: Integer -> Change -> Maybe OrderCreatedEvent
decode_order_created expected_topic0 log_entry =
  case changeTopics log_entry of
    [topic0, owner_topic, timestamp_topic]
      | hex_to_integer topic0 == expected_topic0 ->
          Just OrderCreatedEvent
            { orderOwner      = fromBytes (BS.drop 12 (toBytes owner_topic))
            , orderCreatedAt  = posixSecondsToUTCTime (fromIntegral (hex_to_integer timestamp_topic))
            , orderVolTarget  = data_word 2 (changeData log_entry)
            , orderRangeWidth = data_word 3 (changeData log_entry)
            , orderSkew       = data_word 4 (changeData log_entry)
            }
    _ -> Nothing

hex_to_integer :: HexString -> Integer
hex_to_integer = be_integer . toBytes

data_word :: Int -> HexString -> Integer
data_word index = be_integer . BS.take 32 . BS.drop (32 * index) . toBytes

be_integer :: BS.ByteString -> Integer
be_integer = BS.foldl' (\acc byte -> acc * 256 + fromIntegral byte) 0

-- create_orders returns (bool success, uint256 orderId)[], ABI-encoded as a
-- static-tuple array: offset word (0x20), length word (= count, in elements),
-- then inline (bool, uint256) pairs at stride 0x40. count = 0 is a well-formed
-- 64-byte empty result, not 0 or 32 bytes.
--
-- The contract always emits canonical 0/1 success words (never a truthy
-- nonzero, confirmed by its own dedicated test and an explicit "named mutant"
-- comment) -- this decoder matches that strictness: exactly 0 or 1, anything
-- else is a decode failure, not a lenient "nonzero = true" (a lenient decoder
-- would silently disagree with what a real abi.decode, which rejects
-- non-canonical bools, reports for the same bytes).
decode_create_orders_result :: HexString -> Either String [(Bool, Integer)]
decode_create_orders_result raw
  | byte_length < 64 =
      Left ("create_orders result too short: " ++ show byte_length ++ " bytes")
  | byte_length /= expected_length =
      Left ("create_orders result length mismatch: expected " ++ show expected_length
             ++ " bytes for count " ++ show count ++ ", got " ++ show byte_length)
  | otherwise = traverse decode_pair [0 .. count - 1]
  where
    byte_length     = BS.length (toBytes raw)
    count           = fromIntegral (data_word 1 raw) :: Int
    expected_length = 64 + 64 * count

    decode_pair index =
      let pair_base = 2 + 2 * index
          bool_word = data_word pair_base raw
          order_id  = data_word (pair_base + 1) raw
      in case bool_word of
           0     -> Right (False, order_id)
           1     -> Right (True, order_id)
           other -> Left ("create_orders result: non-canonical bool word at index "
                            ++ show index ++ ": " ++ show other)

-- The contract's *storage*-layout packed word (from getOrderPacked), a THIRD
-- distinct bit layout from both the create_order(uint88,uint24,uint16,uint96)
-- ABI-word format and the create_orders input-word format
-- (pack_vol_order_input's layout). V2 is 248 bits wide
-- (pack_vol_order / unpack_vol_order in src/types/pos_spec/VolOrder.plk:50-66):
--
--   skew        bits   0..15    u16
--   volStrike   bits  16..103   u88
--   tickSpacing bits 104..127   u24
--   range_width bits 128..151   u24
--   target_vega bits 152..247   u96   (OFF_TARGET_VEGA = 152, MASK_U96_VO = 24 F's)
--
-- Note how thoroughly this DIFFERS from the input word: there range_width sits
-- at 104 and target_vega at 128, because build_vol_order inserts TICK_SPACING at
-- 104..127 on the way in and pushes both fields up. The two layouts are close
-- enough to look interchangeable and are not; a copy-paste between them decodes
-- range_width out of tickSpacing's slot and reports the module constant as a
-- width.
--
-- tickSpacing is read and DISCARDED here -- it is the module's hardcoded
-- constant, not part of VolOrder. That constant is TICK_SPACING = 20, while the
-- rig's own deployed pool has tickSpacing = 10 (offchain/rig/rig-manifest.json,
-- .pool.tickSpacing). That is a real discrepancy between the module and the pool
-- it writes against; it is REPORTED here, not resolved -- resolving it means
-- changing another track's module.
unpack_vol_order_storage :: Integer -> VolOrder
unpack_vol_order_storage packed =
  VolOrder
    { vol_target  = fromInteger (mask_bits 88 (packed `shiftR` 16))
    , range_width = fromInteger (mask_bits 24 (packed `shiftR` 128))
    , skew        = fromInteger (mask_bits 16 packed)
    , target_vega = fromInteger (mask_bits 96 (packed `shiftR` 152))
    }
  where
    mask_bits bits value = value .&. ((1 `shiftL` bits) - 1)
