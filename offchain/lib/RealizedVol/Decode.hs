-- | RED STATE (TDD). The naive decoder a reader of the event declaration writes first: every
-- data word read UNSIGNED and no length guard at all. Both defects are the subject of the
-- failing check @driv01_e3_decode_behavior@; the GREEN commit supplies 'signed_word' and the
-- @>= 160@ / @>= 64@ guards together with the haddock that explains why each exists.
module RealizedVol.Decode
  ( TimepointWritten(..)
  , FeeApplied(..)
  , decode_timepoint_written
  , decode_fee_applied
  , signed_word
  ) where

import qualified Data.ByteString as BS
import Data.ByteArray.HexString (toBytes)

import Network.Ethereum.Api.Types (Change (..))

import VolOrder.Decode (data_word, hex_to_integer)

data TimepointWritten = TimepointWritten
  { tw_timestamp :: Integer
  , tw_tick      :: Integer
  , tw_vol_cum   :: Integer
  , tw_avg_tick  :: Integer
  , tw_tick_cum  :: Integer
  } deriving (Eq, Show)

data FeeApplied = FeeApplied
  { fa_sigma :: Integer
  , fa_fee   :: Integer
  } deriving (Eq, Show)

decode_timepoint_written :: Integer -> Integer -> Change -> Maybe TimepointWritten
decode_timepoint_written expected_topic0 expected_pool_id log_entry =
  case changeTopics log_entry of
    [topic0, pool_id_topic]
      | hex_to_integer topic0 == expected_topic0
      , hex_to_integer pool_id_topic == expected_pool_id ->
          Just TimepointWritten
            { tw_timestamp = data_word 0 (changeData log_entry)
            , tw_tick      = data_word 1 (changeData log_entry)
            , tw_vol_cum   = data_word 2 (changeData log_entry)
            , tw_avg_tick  = data_word 3 (changeData log_entry)
            , tw_tick_cum  = data_word 4 (changeData log_entry)
            }
    _ -> Nothing

decode_fee_applied :: Integer -> Integer -> Change -> Maybe FeeApplied
decode_fee_applied expected_topic0 expected_pool_id log_entry =
  case changeTopics log_entry of
    [topic0, pool_id_topic]
      | hex_to_integer topic0 == expected_topic0
      , hex_to_integer pool_id_topic == expected_pool_id ->
          Just FeeApplied
            { fa_sigma = data_word 0 (changeData log_entry)
            , fa_fee   = data_word 1 (changeData log_entry)
            }
    _ -> Nothing

signed_word :: Integer -> Integer
signed_word w = w

-- keeps the RED module's import list honest while the guards are absent
_unused_length :: Change -> Int
_unused_length = BS.length . toBytes . changeData
