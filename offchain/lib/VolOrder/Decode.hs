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
import Data.ByteArray.HexString (HexString, toBytes)

import Network.Ethereum.Api.Types (Change (..))

import VolOrder.Types (VolOrder (..))

-- | The E1 @VolOrderCreated@ payload, V2. Five fields, all 'Integer' and all RAW -- no scaling is
-- applied on the way out, because every one of them is a raw on-chain field and a decoder that
-- quietly rescaled would make the wire values unrecoverable.
data OrderCreatedEvent = OrderCreatedEvent
  { orderId         :: Integer   -- ^ from the INDEXED topic 1, not from the data payload
  , orderStrike     :: Integer   -- ^ data word 0 (u88, Algebra vol units, raw)
  , orderRangeWidth :: Integer   -- ^ data word 1 (u24)
  , orderSkew       :: Integer   -- ^ data word 2 (u16)
  , orderTargetVega :: Integer   -- ^ data word 3 (u96, DeltaQ_v*, RAW LIQUIDITY units)
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
-- RPIN-04 proves the pin check REJECTS it.
--
-- THE V2 LOG SHAPE, read off the emitter at src/lib/events/VolEventsLib.plk:47-54.
--
--   @evm_log2(buf, 128, TOPIC0_VOL_ORDER_CREATED, order_id)
--
-- `@evm_log2` means EXACTLY TWO topics: [topic0, orderId]. 128 bytes means EXACTLY FOUR data
-- words, written by four @mstore32 at offsets 0/32/64/96: [strike, width, skew, targetVega].
-- The declared event is
-- VolOrderCreated(uint256 indexed orderId, uint88 strike, uint24 width, uint16 skew,
-- uint96 targetVega) -- src/interfaces/pos_spec/VolOrderManagerInterface.plk:34-39.
--
-- THE FAILURE MODE THIS REPLACES, and why RPIN-04 is not a constant swap. The decoder that
-- shipped before Phase 21 was the v1 shape: it matched a THREE-element topic list
-- [topic0, owner, blockTimestamp] and read data words 2/3/4 of a five-word payload. Against a v2
-- log it did not decode WRONGLY -- its topic pattern simply did not match, so it returned
-- Nothing, and report_log printed the log as an anonymous "unknown" one forever. Swapping the
-- topic0 constant alone would have left that intact and silent, which is why the check that
-- covers this is a POSITIVE decode of a v2-shaped log, not a comparison of constants.
--
-- The data-length guard below is not defensive padding. `data_word` is
-- `be_integer . BS.take 32 . BS.drop (32*i)`, and BS.drop past the end yields the empty string,
-- whose big-endian value is 0. A short payload would therefore hand back targetVega = 0 -- a
-- plausible, in-range, completely fabricated number. Requiring 128 bytes turns that into a
-- Nothing.
decode_order_created :: Integer -> Change -> Maybe OrderCreatedEvent
decode_order_created expected_topic0 log_entry =
  case changeTopics log_entry of
    [topic0, order_id_topic]
      | hex_to_integer topic0 == expected_topic0
      , BS.length (toBytes (changeData log_entry)) >= 128 ->
          Just OrderCreatedEvent
            { orderId         = hex_to_integer order_id_topic
            , orderStrike     = data_word 0 (changeData log_entry)
            , orderRangeWidth = data_word 1 (changeData log_entry)
            , orderSkew       = data_word 2 (changeData log_entry)
            , orderTargetVega = data_word 3 (changeData log_entry)
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
-- constant, not part of VolOrder. That reason is unchanged and still load-bearing:
-- the field occupies bits 104..127 of the storage word and must be skipped over,
-- but its value carries no order information.
--
-- HISTORY (kept deliberately -- a resolved discrepancy is worth recording): this
-- paragraph used to report a REAL discrepancy -- module TICK_SPACING = 20 against
-- a deployed pool whose tick spacing was 10 -- and said resolving it meant changing
-- another track's module. That is exactly what happened. It was RESOLVED UPSTREAM in
-- PR #18 (ref 2039f27, imported by plan 22-01), finding F2:
-- foundry-scripts/deploy/DeployDynamicFeeHook.s.sol now declares
-- TICK_SPACING = 20, so offchain/rig/rig-manifest.json's .pool.tickSpacing reads
-- 20 and module and pool AGREE. Consequence for anyone reading a stale rig: the
-- PoolKey hash -- and therefore the poolId -- MOVED with it, so any manifest
-- recorded before that ref is stale by construction, not merely mislabelled.
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
