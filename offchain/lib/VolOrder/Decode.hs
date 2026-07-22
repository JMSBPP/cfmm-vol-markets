module VolOrder.Decode
  ( OrderCreatedEvent(..)
  , decode_order_created
  , topic_order_created
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

-- TOPIC_ORDER_CREATED in src/modules/VolOrderManagerMod.plk
topic_order_created :: Integer
topic_order_created = 0xa8892769

data OrderCreatedEvent = OrderCreatedEvent
  { orderOwner      :: HexString
  , orderCreatedAt  :: UTCTime
  , orderVolTarget  :: Integer
  , orderRangeWidth :: Integer
  , orderSkew       :: Integer
  } deriving (Eq, Show)

-- Log layout from log_create_order in src/modules/VolOrderManagerMod.plk:
-- topics are [TOPIC_ORDER_CREATED, owner, blockTimestamp], data is five
-- 32-byte words [32, 96, volTarget, rangeWidth, skew].
decode_order_created :: Change -> Maybe OrderCreatedEvent
decode_order_created log_entry =
  case changeTopics log_entry of
    [topic0, owner_topic, timestamp_topic]
      | hex_to_integer topic0 == topic_order_created ->
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
-- distinct bit layout from both the create_order(uint88,uint24,uint16) ABI-word
-- format and the create_orders input-word format (pack_vol_order_input's
-- layout). Storage layout inserts a hardcoded tickSpacing at bits 104-127 and
-- shifts range_width to bits 128-151 (pack_vol_order/unpack_vol_order in
-- src/types/pos_spec/VolOrder.plk). tickSpacing is read and discarded here --
-- it is always the contract's hardcoded constant, not part of VolOrder.
unpack_vol_order_storage :: Integer -> VolOrder
unpack_vol_order_storage packed =
  VolOrder
    { vol_target  = fromInteger (mask_bits 88 (packed `shiftR` 16))
    , range_width = fromInteger (mask_bits 24 (packed `shiftR` 128))
    , skew        = fromInteger (mask_bits 16 packed)
    }
  where
    mask_bits bits value = value .&. ((1 `shiftL` bits) - 1)
