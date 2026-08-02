-- | THIS MODULE READS LOGS AND NOTHING ELSE.
--
-- Phase 22's CONTEXT records a locked user decision: there is no @RealizedVol.*@ CLIENT. Nothing
-- offchain may call @writeTimepoint@ — \"by setting prices and moving across time the timepoints
-- will write themselves on the Hook [...] the only thing a client can do is query the DB api\".
-- @DynamicFeeHook.beforeSwap@ calls @rv_write_timepoint@ on the pre-swap tick, so DRIV-01 is
-- satisfied by making the hook FIRE, never by calling the vol module.
--
-- A decoder is squarely inside \"query the DB api\": it turns emitted logs into values and holds
-- no 'Network.Ethereum.Web3' action, no address, and no transaction. The module name says
-- @RealizedVol@ because that is whose events these are — a later reader must not read the name as
-- evidence the decision was violated.
--
-- == The two payloads
--
-- E3, emitter at @src\/lib\/events\/VolEventsLib.plk@ lines 62-77:
--
-- > let buf = @malloc_uninit(160);   ... five @mstore32 at 0/32/64/96/128 ...
-- > @evm_log2(buf, 160, TOPIC0_TIMEPOINT_WRITTEN, pool_id);
--
-- @\@evm_log2@ is EXACTLY two topics @[topic0, poolId]@; 160 bytes is EXACTLY five data words, in
-- emission order @[timestamp, tick, volatilityCumulative, averageTick, tickCumulative]@. The
-- declaration is
-- @TimepointWritten(bytes32 indexed poolId, uint32 timestamp, int24 tick, uint88
-- volatilityCumulative, int24 averageTick, int56 tickCumulative)@
-- (@src\/interfaces\/market_state_measurements\/RealizedVolatilityInterface.plk@).
--
-- E5, declared at @src\/interfaces\/protocol_integrations\/DynamicFeeHookInterface.plk@:
-- @FeeApplied(bytes32 indexed poolId, uint88 sigma, uint24 fee)@ — the same two-topic shape over
-- 64 bytes @[sigma, fee]@, both fields unsigned.
--
-- Both @expected_topic0@ and @expected_pool_id@ are ARGUMENTS, not constants: this module then
-- acquires no IO dependency, stays testable from pure values, and cannot go stale the way a
-- transcribed topic0 silently does (a wrong topic0 does not look wrong — it simply matches no log,
-- so decoding \"succeeds\" at reporting nothing). The caller supplies them from the generated pin
-- file @offchain\/rig\/rig-pins.json@ and from the manifest.
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

-- | The E3 payload. All five fields are 'Integer' and RAW — no scaling is applied on the way out,
-- because every one of them is a raw on-chain field and a decoder that quietly rescaled would make
-- the wire values unrecoverable. The three SIGNED fields are converted from two's complement (see
-- 'signed_word'); the two unsigned ones are not touched.
data TimepointWritten = TimepointWritten
  { tw_timestamp :: Integer   -- ^ data word 0 (u32, the hook's own clock)
  , tw_tick      :: Integer   -- ^ data word 1 (i24, SIGNED)
  , tw_vol_cum   :: Integer   -- ^ data word 2 (u88, Algebra volatility-cumulative units)
  , tw_avg_tick  :: Integer   -- ^ data word 3 (i24, SIGNED)
  , tw_tick_cum  :: Integer   -- ^ data word 4 (i56, SIGNED)
  } deriving (Eq, Show)

-- | The E5 payload. Two words, neither signed.
data FeeApplied = FeeApplied
  { fa_sigma :: Integer   -- ^ data word 0 (u88, the volatility the fee was computed from)
  , fa_fee   :: Integer   -- ^ data word 1 (u24, pips, WITHOUT the override flag)
  } deriving (Eq, Show)

-- | Decode an E3 @TimepointWritten@.
--
-- === Why the @>= 160@ length guard is load-bearing
--
-- 'VolOrder.Decode.data_word' is @be_integer . BS.take 32 . BS.drop (32*i)@, and 'BS.drop' past
-- the end of a 'BS.ByteString' yields the EMPTY string, whose big-endian value is @0@ — not an
-- error, not a 'Nothing'. Without this guard a short payload hands back
-- @tickCumulative = 0@: plausible, in range, and completely fabricated. Downstream that zero is
-- indistinguishable from a genuine zero cumulative at series start. This is the identical trap
-- RPIN-04 documented for E1, and the guard is the identical fix.
--
-- === Why ONE 'signed_word' covers all three signed fields
--
-- The emitter applies @\@evm_signextend@ to @tick@, @averageTick@ AND @tickCumulative@ before
-- @\@mstore32@ (@SIGN_BYTE_I24_EV@ for the two ticks, @SIGN_BYTE_I56_EV@ for the cumulative), so
-- every signed field arrives sign-extended to the FULL 256-bit word regardless of its declared
-- width. One uniform conversion is therefore correct for all three, and a per-width mask would be
-- wrong for all three.
--
-- The two ways to get this wrong both produce numbers rather than errors:
--
--   * masking to 24 bits turns @tick = -200@ into @16777016@;
--   * not converting at all turns it into
--     @115792089237316195423570985008687907853269984665640564039457584007913129639736@.
--
-- Both then fail an equality check against the tick that was submitted, and both fail it for a
-- reason that looks like a chain bug — a cheated slot0 that \"did not take\" — rather than like a
-- decoder bug. That misattribution is the actual cost, and it is why the negative cases are pinned
-- as exact values in @driv01_e3_decode_behavior@.
--
-- === Why filtering on topic0 alone is WRONG
--
-- The module-global @RealizedVolatilityMod@ emits the SAME topic0 with @poolId = bytes32(0)@. That
-- sentinel is PERMANENT and first-class (@notes\/DATA_CONTRACT.md@ section 2, spec D2 — the
-- emitter's own comment says so), so a topic0-only filter admits module-global logs as if they
-- were the pool's. Matching @expected_pool_id@ here removes that class of confusion, but it does
-- NOT remove all of it: the hook and the module both emit E3, and only the log's EMITTING ADDRESS
-- separates them when both carry a real poolId. This module cannot see intent, so the caller must
-- additionally filter @changeAddress == DynamicFeeHook@. Said here because there is nowhere else
-- a caller is guaranteed to look.
decode_timepoint_written :: Integer -> Integer -> Change -> Maybe TimepointWritten
decode_timepoint_written expected_topic0 expected_pool_id log_entry =
  case changeTopics log_entry of
    [topic0, pool_id_topic]
      | hex_to_integer topic0 == expected_topic0
      , hex_to_integer pool_id_topic == expected_pool_id
      , BS.length (toBytes (changeData log_entry)) >= 160 ->
          Just TimepointWritten
            { tw_timestamp =              data_word 0 (changeData log_entry)
            , tw_tick      = signed_word (data_word 1 (changeData log_entry))
            , tw_vol_cum   =              data_word 2 (changeData log_entry)
            , tw_avg_tick  = signed_word (data_word 3 (changeData log_entry))
            , tw_tick_cum  = signed_word (data_word 4 (changeData log_entry))
            }
    _ -> Nothing

-- | Decode an E5 @FeeApplied@. Same two-topic shape as E3 with a @>= 64@ guard for the same
-- reason — a short payload would otherwise report @fee = 0@, which on a dynamic-fee pool is a
-- perfectly representable fee and would be read as \"the hook charged nothing\".
--
-- Neither field is signed, so 'signed_word' is deliberately absent here; adding it would be a bug
-- the moment @sigma@ exceeded @2^255@, which @u88@ never can, so it would also be a SILENT one.
decode_fee_applied :: Integer -> Integer -> Change -> Maybe FeeApplied
decode_fee_applied expected_topic0 expected_pool_id log_entry =
  case changeTopics log_entry of
    [topic0, pool_id_topic]
      | hex_to_integer topic0 == expected_topic0
      , hex_to_integer pool_id_topic == expected_pool_id
      , BS.length (toBytes (changeData log_entry)) >= 64 ->
          Just FeeApplied
            { fa_sigma = data_word 0 (changeData log_entry)
            , fa_fee   = data_word 1 (changeData log_entry)
            }
    _ -> Nothing

-- | A 256-bit two's-complement word as a signed 'Integer'. The boundary is exact: @2^255@ is the
-- most negative representable value, @-(2^255)@, and @2^255 - 1@ is the most positive.
signed_word :: Integer -> Integer
signed_word w = if w >= 2 ^ (255 :: Int) then w - 2 ^ (256 :: Int) else w
