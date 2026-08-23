-- |
-- The PURE half of the chain edge: the range arithmetic, the identity of a log, and the fields a
-- filter is built from.
--
-- Everything a local chain will not do on demand is an ARGUMENT here, and the transport itself is
-- a RECORD of actions ('ChainSource') rather than a call. 27-02 recorded the same move for
-- @Chain.Read.refuse_or_value@ and it is the reason the LOOP-01 checks can drive a restart across
-- a down-time window with no node running: the check supplies the source, so it controls what the
-- chain did while the loop was not looking.
--
-- WHAT IS DELIBERATELY NOT HERE
-- -----------------------------
-- No provider, no request and no socket. "Loop.Chain" is the only module in this layer that names
-- the transport, and it is listed as an endpoint site for exactly that reason.
module Loop.Poll
  ( -- * The chain, as a value
    ChainSource (..)
    -- * The range
  , next_range
    -- * A log's identity
  , event_identity
  , log_block
    -- * The filter, as fields
  , shock_filter_fields
  , topic_word
  ) where

import qualified Data.ByteString as BS
import Data.Bits (shiftR, (.&.))
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Data.Solidity.Prim.Address (Address)

import Network.Ethereum.Api.Types (Change (..), DefaultBlock (BlockWithNumber))

import Chain.Read (BlockRef, render_word_token, word_hex_digits)
import Loop.Config (loop_first_block)
import Loop.Ledger (EventId (..))

-- ---------------------------------------------------------------------------------------------
-- The chain, as a value
-- ---------------------------------------------------------------------------------------------

-- | Everything the loop asks a chain for, as five actions it was handed.
--
-- 'source_logs' takes a CLOSED range and the loop only ever passes @[b, b]@; the range is in the
-- signature anyway because the wire's own filter has two ends and hiding one of them here would
-- put the closedness in a comment instead of in a type a check can drive.
data ChainSource = ChainSource
  { source_label    :: String
    -- ^ which source this is, so a failure names the one it came from.
  , source_head     :: IO Integer
    -- ^ the highest block the chain will admit to having.
  , source_logs     :: Integer -> Integer -> IO [Change]
    -- ^ the logs in the CLOSED range @[from, to]@.
  , source_reads    :: Integer -> BlockRef -> IO (Either String (Integer, Integer, Integer))
    -- ^ pool id and block to @(sqrtPriceX96, liquidity, lpFee)@, every one of them PINNED.
  , source_chain_id :: IO Integer
    -- ^ the network the three above were answered by. A wrong-network guard, never an input.
  }

-- ---------------------------------------------------------------------------------------------
-- The range
-- ---------------------------------------------------------------------------------------------

-- | The closed range still to scan, or 'Nothing' when the loop is caught up.
--
-- THE @Nothing@ WATERMARK CASE IS THE WHOLE OF LOOP-01. A loop with no watermark starts at
-- 'Loop.Config.loop_first_block' and NOT at the head, because a loop that starts at the head has
-- already skipped every event before it -- and on a chain that has produced no event yet, which is
-- every chain for the first minutes of every test, the two behaviours are indistinguishable. The
-- bug is invisible exactly when it is cheapest to introduce.
--
-- The comparison against the head is @<=@ rather than @<@: the watermark names the last block
-- FULLY PROCESSED, so a head equal to it is caught up and re-scanning it would re-offer every
-- event in it.
next_range :: Maybe Integer -> Integer -> Maybe (Integer, Integer)
next_range Nothing head_block
  | head_block < loop_first_block = Nothing
  | otherwise                     = Just (loop_first_block, head_block)
next_range (Just watermark) head_block
  | head_block <= watermark = Nothing
  | otherwise               = Just (watermark + 1, head_block)

-- ---------------------------------------------------------------------------------------------
-- A log's identity
-- ---------------------------------------------------------------------------------------------

-- | The position in the chain this log occupies, or the FIELD that is missing.
--
-- FOUR of @Change@'s fields are optional and three of them are this identity. A PENDING log
-- carries none of them: it has no transaction hash, no index within a transaction and no block. It
-- therefore has no identity, and ledgering one under a fabricated key is how a replay stops being
-- detectable -- the ledger's whole guarantee is that the same position is one row, and a position
-- invented at read time is a different position every time it is read.
--
-- The refusal NAMES the field, in the transport's own spelling, and the fields are decided in a
-- fixed order so a log missing two of them reports the first rather than an arbitrary one.
event_identity :: Change -> Either String EventId
event_identity log_entry =
  case changeTransactionHash log_entry of
    Nothing ->
      Left (missing "changeTransactionHash"
             "a log with no transaction hash is PENDING: it has not been mined, so the position it\
             \ would be ledgered under does not exist yet")
    Just tx ->
      case changeLogIndex log_entry of
        Nothing ->
          Left (missing "changeLogIndex"
                 "a log with no index within its transaction cannot be told apart from the other\
                 \ logs of that same transaction, and the ledger's unique constraint is over the\
                 \ PAIR")
        Just ix ->
          case changeBlockNumber log_entry of
            Nothing ->
              Left (missing "changeBlockNumber"
                     "a log with no block cannot be read at a pinned height, and every read this\
                     \ loop makes REQUIRES one")
            Just _ ->
              Right EventId
                { ev_tx_hash   = render_word_token (toBytes tx)
                , ev_log_index = toInteger ix
                }
  where
    missing field why =
      "the log carries no " ++ field ++ ", so it has no identity: " ++ why ++ "."

-- | The block a log was mined in, or the field that is missing, in the same spelling.
log_block :: Change -> Either String Integer
log_block log_entry =
  case changeBlockNumber log_entry of
    Nothing ->
      Left ("the log carries no changeBlockNumber, so there is no height to pin its reads at.")
    Just n -> Right (toInteger n)

-- ---------------------------------------------------------------------------------------------
-- The filter, as fields
-- ---------------------------------------------------------------------------------------------

-- | A topic word: an 'Integer' as the 32 big-endian bytes a topic actually is.
--
-- Built from BYTES rather than from a rendered token, so there is no parse to fail and the
-- function is total. The width is 'Chain.Read.word_hex_digits' halved, taken from the module that
-- states it, rather than a second statement of what a word is.
topic_word :: Integer -> HexString
topic_word n = fromBytes (BS.pack [byte i | i <- [width - 1, width - 2 .. 0]])
  where
    width  = word_hex_digits `div` 2
    byte i = fromIntegral ((n `shiftR` (8 * i)) .&. 0xff)

-- | The four fields the @Shock@ filter is made of, for a CLOSED @[from, to]@ range.
--
-- Returned as FIELDS rather than as the transport's own request type on purpose: the suite can
-- then assert that @from@ and @to@ are the same block -- which is the property @[b, b]@ IS --
-- without importing the request type, and the suite is under a structural grep that forbids it
-- from naming the transport at all.
--
-- The topic list is @[topic0, Nothing]@: the first topic is the event's signature hash and the
-- second is left OPEN. The pool is in topic 1 and it is decided by the decoder, which refuses a
-- topic that is not an address and a pool that is zero -- filtering on it here as well would put
-- the same decision in two places, and the one on the wire is the one nobody can see fail.
shock_filter_fields
  :: Address   -- ^ the emitter the logs must come from
  -> Integer   -- ^ topic0
  -> Integer   -- ^ from, inclusive
  -> Integer   -- ^ to, inclusive
  -> (Maybe [Address], DefaultBlock, DefaultBlock, Maybe [Maybe HexString])
shock_filter_fields emitter topic0 from to =
  ( Just [emitter]
  , BlockWithNumber (fromInteger from)
  , BlockWithNumber (fromInteger to)
  , Just [Just (topic_word topic0), Nothing]
  )
