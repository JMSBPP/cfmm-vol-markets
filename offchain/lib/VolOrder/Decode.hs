module VolOrder.Decode
  ( OrderCreatedEvent(..)
  , decode_order_created
  , topic_order_created
  , hex_to_integer
  , data_word
  , be_integer
  ) where

import qualified Data.ByteString as BS
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Time.Clock (UTCTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)

import Network.Ethereum.Api.Types (Change (..))

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
