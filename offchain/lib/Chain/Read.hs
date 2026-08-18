-- | CHAIN-02 and CHAIN-03: __every pool read is pinned to ONE block, by construction, and an
-- absent, zero or unparseable answer is a refusal that NAMES THE FIELD rather than a value.__
--
-- == WHAT WAS HERE BEFORE, MEASURED
--
-- Nothing. 27-CONTEXT measured block pinning as ABSENT and not partial: one unpinned tag
-- tree-wide (@CheatSwap\/Rpc.hs@'s @read_word@), no block-reference type anywhere, and
-- @CheatSwap\/Rpc.hs@'s head read taking whatever height the node happened to be at. So this
-- module is construction, not adjustment, and the shape of the construction is the point.
--
-- == WHY 'BlockRef' IS A @newtype@ WITH ONE CONSTRUCTOR
--
-- A @data@ declaration with an 'AtBlock' constructor and a documented convention of not adding a
-- moving-head one is a convention. A @newtype@ has EXACTLY ONE constructor as a matter of the
-- language, so the moving-head tag is not something this module avoids -- it is something the type
-- cannot express, and turning it into something expressible means changing @newtype@ to @data@,
-- which is a diff nobody writes by accident. That is what makes
-- @latest_appears_nowhere_in_the_read_layer@ an honest assertion rather than an aspirational one:
-- the scan is checking that a property the TYPE already enforces has not been routed around in
-- prose or in a string.
--
-- Every read below takes a 'BlockRef' as a required POSITIONAL argument. There is no arity at
-- which a caller omits it, no @Maybe BlockRef@, and no default anywhere in this file. The
-- alternative shape -- @read_x :: Address -> Integer -> Web3 ...@ with an optional pinned variant
-- beside it -- is the one that fails, because the unpinned form is shorter to type and every call
-- site that does not think about the question gets the wrong one.
--
-- == 'ReadAt' IS A RECORDING TAG, NOT A BLOCK ARGUMENT
--
-- 'Unpinned' exists because the CONTROL probe in the out-of-band capture has to be RECORDED, and
-- the honest recording of "this value was obtained without a pin" is a null height rather than a
-- plausible one -- the @readback_height@ idiom @Driver.Capture@ already uses. It is deliberately
-- NOT a 'BlockRef': no read in this module accepts a 'ReadAt', so 'Unpinned' cannot be handed to
-- one. The capture's unpinned probe is made with the raw transport, in the capture's own source,
-- where it is visible as a control and not as a read.
--
-- == WHY A ZERO IS A REFUSAL AND NOT A VALUE
--
-- This repository has hit the zero-word trap repeatedly and always in the same shape: a value that
-- is SHAPE-VALID and MEANINGLESS passes every structural guard and travels on. The three recorded
-- instances nearest to this module are the zero address passing a hex-shape guard, a numeric zero
-- passing a non-emptiness test, and an empty string compared against another empty string six
-- separate times. On the chain side it is sharper still, because the transport manufactures the
-- zero itself: @VolOrder.Decode.hex_to_integer@ is @be_integer . toBytes@, and @toBytes@ of the
-- bare @0x@ a reverting @staticcall@ returns is the EMPTY byte string, whose big-endian value is
-- @0@. So a read that failed and a read that succeeded on a zero-valued slot arrive at a caller as
-- the same @Integer@. 'refuse_or_value' is where those two stop being the same thing.
--
-- @CheatSwap.Rpc@ guard (d) already carries the exactness argument for the price half and it is
-- reproduced here because it is what makes this a TEST rather than a heuristic: v4's @initialize@
-- ALWAYS stores a nonzero @sqrtPriceX96@ into the pool's @Slot0@, and @extsload@ of an untouched
-- slot returns a zero word. A zero therefore means one thing -- there is no pool at
-- @keccak(poolId || POOLS_SLOT)@ on the manager being read -- and it is reachable by a stale
-- poolId, a @POOLS_SLOT@ that has drifted from the deployed manager's layout, an uninitialised
-- pool, the wrong manager, or a pin to a block BEFORE the pool was initialised. That last one is
-- new here and it is not hypothetical: it was OBSERVED against the live rig at 27-02, where the
-- same pinned read returns an all-zero word at block 5 and a well-formed one at block 13.
--
-- == WHY 'LpFee' IS NOT ZERO-REFUSED, AND WHY THAT IS A MEASUREMENT
--
-- The plan asked for three zero-refused reads: the price, the liquidity and the fee. (The price
-- field is named 'SqrtPriceX96' below and it is written that way EVERYWHERE in this file, never as
-- two words. FEE-02's scan reaches this module through 'aeson_storage_path' and one of its terms is
-- the square-root operation with word boundaries, so the two-word spelling MATCHES while the
-- camel-cased field name does not. MEASURED at 27-02: the first draft of this paragraph wrote it as
-- two words and @no_floating_value_is_on_the_fee_path@ named this file on the very next run. That is
-- instance 27 of prose inside a grep's blast radius on this branch, and the answer is the same as
-- the other 26 -- move the prose, never relax the pattern.) MEASURED at 27-02
-- against the standing rig, decoding bits 208..231 of the live @Slot0@ word:
--
-- > lpFee       = 0
-- > protocolFee = 0
-- > tick        = -1
-- > liquidity   = 1000000000000000000000
--
-- A dynamic-fee pool stores @lpFee = 0@ at initialise -- @CheatSwap.Types.compose_slot0@'s haddock
-- already records exactly that, and this is the live confirmation of it -- because the fee for a
-- dynamic-fee pool is supplied per swap by the hook and is not the slot's business. A zero-refusing
-- fee read would therefore refuse the rig's OWN genesis state on every call, and the only way to
-- ship it green would be to relax it on its first run, which is how a guard becomes decorative.
--
-- So the refusal set is AIMED rather than blanket, and the aiming is written down per field in
-- 'zero_is_refused'. 'LpFee' still refuses an absent, an empty and an unparseable answer, and it
-- still refuses an ALL-ZERO WORD -- because an all-zero word is not a zero fee, it is no pool --
-- which is exactly the distinction a blanket rule cannot draw. @tick@ is not read here at all, and
-- for the same reason stated in the other direction: its most common legitimate value is zero, and
-- the rig's own seed sets it to zero, so there is no honest zero-refusal to write for it.
--
-- == WHAT THIS MODULE DOES NOT DO
--
-- It does not resolve an endpoint (that is 'Chain.Endpoint', and it is the only place that does),
-- it does not build a provider, it does not decide WHICH block is the right one to pin to, and it
-- does not cache. It turns "an address, a pool, a field and a height" into either a value or a
-- named refusal.
module Chain.Read
  ( -- * The pin
    BlockRef (AtBlock)
  , block_height
  , block_param
    -- * How a recorded value says where it came from
  , ReadAt (..)
  , readback_height
    -- * The fields
  , PoolField (..)
  , pool_field_name
  , pool_fields
  , zero_is_refused
  , decoy_field_name
  , pool_field_slot_offset
  , pool_field_slot
  , extract_pool_field
    -- * The rule, as a total function of what a transport hands back
  , word_hex_digits
  , render_word_token
  , decode_word_token
  , refuse_or_value
  , refusal_naming
    -- * The reads. Every one of them REQUIRES a 'BlockRef'.
  , read_raw_word_token
  , read_pool_field
  , read_pool_state_word
  , read_sqrt_price_x96
  , read_liquidity
  , read_lp_fee
  ) where

import Control.Monad.IO.Class (liftIO)
import Data.Bits (shiftL, shiftR, (.&.))
import qualified Data.ByteString as BS
import Data.Char (intToDigit, isHexDigit, digitToInt)
import Data.List (isPrefixOf)

import Data.ByteArray.HexString (toBytes)
import Data.Solidity.Prim.Address (Address)

import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Ethereum.Api.Types (Call (..), DefaultBlock (BlockWithNumber))
import Network.Web3.Provider (Web3)

import CheatSwap.Encoding (encode_extsload)
import CheatSwap.Types (pool_state_slot)

-- ---------------------------------------------------------------------------------------------
-- The pin
-- ---------------------------------------------------------------------------------------------

-- | A block height, and the ONLY way to say which block a read is made at.
--
-- @newtype@, deliberately: see the module haddock. One constructor is a fact about the language
-- here, not a convention this module keeps.
newtype BlockRef = AtBlock Integer
  deriving (Eq, Ord, Show)

-- | The height a 'BlockRef' names.
block_height :: BlockRef -> Integer
block_height (AtBlock n) = n

-- | The 'BlockRef' as the transport's block parameter.
--
-- This is the ONE place in the read layer that touches the transport's block type, and it can
-- only produce the numbered form -- the sum's other constructors are unreachable from a
-- 'BlockRef' because a 'BlockRef' cannot be anything but a number.
--
-- A NEGATIVE height is not rendered. It is caught in 'refuse_or_value' before any call is made,
-- because @BlockWithNumber@ of a negative quantity is a request the node answers with a JSON-RPC
-- error whose message names neither the field nor the caller.
block_param :: BlockRef -> DefaultBlock
block_param = BlockWithNumber . fromInteger . block_height

-- | WHERE A RECORDED VALUE CAME FROM. A tag, never an argument to a read.
--
-- 'Unpinned' is here so the capture's CONTROL probe has an honest recording, and 'readback_height'
-- is why it matters: the null it produces is distinguishable from a height, where a sentinel like
-- @0@ or @-1@ is a plausible-looking number that a downstream reader has no way to tell from a
-- real one. @Driver.Capture@ made the same choice for the same reason.
data ReadAt
  = Pinned BlockRef
  | Unpinned
    -- ^ MEASUREMENT ONLY. No read in this module accepts a 'ReadAt', so this cannot be handed to
    -- one; the capture's unpinned probe is written out in the capture's own source, where it reads
    -- as the control it is.
  deriving (Eq, Show)

-- | The height to record, or 'Nothing' when there was no pin.
readback_height :: ReadAt -> Maybe Integer
readback_height (Pinned ref) = Just (block_height ref)
readback_height Unpinned     = Nothing

-- ---------------------------------------------------------------------------------------------
-- The fields
-- ---------------------------------------------------------------------------------------------

-- | The pool fields this layer reads.
--
-- Three of the four come out of ONE 32-byte word (the pool's @Slot0@) and the fourth out of the
-- word three slots along, which is why 'pool_field_slot_offset' exists rather than a second
-- address constant.
data PoolField
  = PoolStateWord
    -- ^ The raw @Slot0@ word itself. Read as a field in its own right because "the word is all
    -- zero" and "the field decoded to zero" are DIFFERENT diagnoses and a caller that only ever
    -- sees extracted fields cannot tell them apart.
  | SqrtPriceX96
    -- ^ @Slot0@ bits [0,160).
  | LpFee
    -- ^ @Slot0@ bits [208,232). NOT zero-refused -- see the module haddock for the measurement.
  | Liquidity
    -- ^ @Pool.State.liquidity@, the @uint128@ at offset 3. MEASURED at 27-02 against the live rig:
    -- @1e21@, which is @InitSwappableRig@'s single full-range position.
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | The name a refusal uses, and the name the artifact records.
--
-- These are v4's OWN field names, so a refusal is greppable back to the source that defines the
-- layout rather than to a nickname invented here.
pool_field_name :: PoolField -> String
pool_field_name PoolStateWord = "poolStateWord"
pool_field_name SqrtPriceX96  = "sqrtPriceX96"
pool_field_name LpFee         = "lpFee"
pool_field_name Liquidity     = "liquidity"

-- | Every field, derived from the type rather than typed out, so a new constructor joins the
-- checks on the day it is declared.
pool_fields :: [PoolField]
pool_fields = [minBound .. maxBound]

-- | A REAL v4 field name that this layer does NOT read, and that CONTAINS one that it does.
--
-- It is exported for one purpose: the suite's naming assertion has to be shown REJECTING a longer
-- wrong value, and a decoy invented for the occasion would be a decoy chosen to fail. @liquidityNet@
-- is v4's per-tick signed liquidity delta; @\"liquidity\"@ is a strict prefix of it. 26-03 measured
-- a naming arm PASSING because @\"828040\"@ contains @\"82804\"@, and this file's own refusals are
-- checked with @isInfixOf@, of which this suite has 68 uses. So the refusals below delimit the name
-- ('refusal_naming') and the suite observes the UNDELIMITED form accepting this string while the
-- delimited form rejects it.
decoy_field_name :: String
decoy_field_name = "liquidityNet"

-- | Whether a DECODED value of zero is refused for this field.
--
-- Per field and never blanket, and the entry that carries the argument is 'LpFee' -- see the
-- module haddock for the live measurement that put it there. An all-zero WORD is refused for
-- every field regardless of this, because an all-zero word is not a zero value, it is no pool.
zero_is_refused :: PoolField -> Bool
zero_is_refused PoolStateWord = True
zero_is_refused SqrtPriceX96  = True
zero_is_refused Liquidity     = True
zero_is_refused LpFee         = False

-- | How many slots past the pool's state slot this field's word lives.
--
-- v4's @Pool.State@ begins @slot0@, @feeGrowthGlobal0X128@, @feeGrowthGlobal1X128@, @liquidity@.
-- CONFIRMED against the live rig at 27-02 rather than read off a header: the word at offset 3 is
-- @1e21@, which is the position @InitSwappableRig@ mints, and the words at offsets 1 and 2 are the
-- two fee-growth accumulators (offset 1 nonzero after the probe swap, offset 2 zero).
pool_field_slot_offset :: PoolField -> Integer
pool_field_slot_offset Liquidity = 3
pool_field_slot_offset _         = 0

-- | The storage slot a field's word lives in, for a pool id.
--
-- @pool_state_slot@ is CONSUMED from 'CheatSwap.Types' rather than re-derived. The reason is the
-- one that module already records: two derivations of one slot is two things that can disagree,
-- and a disagreement here does not revert -- @extsload@ of a wrong-but-valid slot returns a zero
-- word, which is precisely the value this module refuses.
pool_field_slot :: Integer -> PoolField -> Integer
pool_field_slot pool_id field = pool_state_slot pool_id + pool_field_slot_offset field

-- | Pull a field out of its 32-byte word. Pure shifting; no validation, which is 'refuse_or_value'.
extract_pool_field :: PoolField -> Integer -> Integer
extract_pool_field PoolStateWord w = w
extract_pool_field SqrtPriceX96  w = w .&. ((1 `shiftL` 160) - 1)
extract_pool_field LpFee         w = (w `shiftR` 208) .&. ((1 `shiftL` 24) - 1)
extract_pool_field Liquidity     w = w .&. ((1 `shiftL` 128) - 1)

-- ---------------------------------------------------------------------------------------------
-- The rule, as a total function of the token a transport hands back
-- ---------------------------------------------------------------------------------------------

-- | A storage word is 32 bytes, so its token carries this many hex digits after the marker.
word_hex_digits :: Int
word_hex_digits = 64

-- | The bytes a transport returned, back as the @0x@ token the node sent.
--
-- Rendered from the bytes rather than trusted from a @Show@ instance, for the reason
-- @CheatSwap.Rpc.address_hex@ gives: the shape is this module's decision and not a dependency's
-- formatting choice. It is also what makes the EMPTY case observable at all -- an empty payload
-- renders as the bare marker, and 'decode_word_token' names that case specifically instead of
-- letting it become the integer zero.
render_word_token :: BS.ByteString -> String
render_word_token = ("0x" ++) . concatMap byte . BS.unpack
  where
    byte b = [nibble (b `shiftR` 4), nibble (b .&. 0x0f)]
    nibble = intToDigit . fromIntegral

-- | Parse the token, or say exactly what is wrong with it.
--
-- FOUR failure shapes and they are kept apart on purpose, because the operator action differs for
-- each: no marker is a caller handing this the wrong string entirely; an EMPTY payload is a
-- reverting or code-less call (the shape that becomes the integer zero if nobody looks); a non-hex
-- character is a corrupted or truncated transport answer; a wrong LENGTH is a call that returned
-- something other than a storage word -- an ABI-encoded tuple, say -- and the value would decode to
-- a perfectly plausible number.
--
-- Order is the design: the marker, then emptiness, then the characters, then the length. Testing
-- length first would report @0x@ as "0 hex digits, not 64", which is true and useless -- it hides
-- the one case the rest of this module exists for.
--
-- Tokens are echoed TRUNCATED. A refusal that pastes a 130-kilobyte return into a message is a
-- refusal nobody reads.
decode_word_token :: String -> Either String Integer
decode_word_token token
  | not ("0x" `isPrefixOf` token) =
      Left ("the answer does not begin with the 0x marker, so it is not a storage word at all"
             ++ " (answer: " ++ echo token ++ ")")
  | null payload =
      Left ("the answer is the BARE 0x marker with an EMPTY payload. That is what a reverting or"
             ++ " code-less call returns, and it is NOT the number zero: be_integer of the empty"
             ++ " byte string is 0, so a transport-level failure and a genuine zero arrive at a"
             ++ " caller as the same Integer unless they are separated here")
  | not (all isHexDigit payload) =
      Left ("the answer carries a non-hexadecimal character, so the transport's reply is corrupt"
             ++ " or truncated (answer: " ++ echo token ++ ")")
  | length payload /= word_hex_digits =
      Left ("the answer carries " ++ show (length payload) ++ " hex digits and a storage word has "
             ++ show word_hex_digits ++ ". A shorter or longer reply is a call that returned"
             ++ " something other than one slot, and its value would decode to a plausible number"
             ++ " (answer: " ++ echo token ++ ")")
  | otherwise = Right (foldl (\acc c -> acc * 16 + toInteger (digitToInt c)) 0 payload)
  where
    payload = drop 2 token
    echo s = let shown = take 80 s
             in show shown ++ (if length s > 80 then " (truncated from " ++ show (length s)
                                                       ++ " characters)"
                                                else "")

-- | THE REFUSAL PREFIX, and the ONE place the field's name is delimited into a message.
--
-- The quotes are load-bearing rather than typography. Every naming assertion in the suite is an
-- @isInfixOf@, and an undelimited @\"liquidity\"@ is satisfied by a message about
-- 'decoy_field_name'. Delimited, it is not. That is 26-03's finding written into the producer
-- instead of into each consumer.
refusal_naming :: PoolField -> String
refusal_naming field = "field '" ++ pool_field_name field ++ "'"

-- | __THE RULE.__ A total function of the field, where the read was made, and exactly what the
-- transport handed back.
--
-- 'Nothing' is an ABSENT answer -- no key, no reply, nothing to parse. It is a separate argument
-- shape rather than an empty string because the two are different facts and the repository has
-- measured what happens when they are conflated: an empty value flows on, meets another empty
-- value, and @\"\" == \"\"@ exits 0 having verified nothing.
--
-- PURE, and that is not style either. 27-01 MEASURED a rule written against the environment
-- passing at a value its own process could not create; the answer there was to factor the rule out
-- of the wiring so it could be driven at the awkward argument directly. This is the same move
-- against a different unreachable state: a local anvil will not hand a caller a truncated word or a
-- non-hex character on demand, so those arguments are supplied by the suite and the WIRING below is
-- what runs against a chain.
--
-- Order of refusals, and each is a different diagnosis:
--
--   1. a negative height -- refused BEFORE any call, because the node's own error for it names
--      neither the field nor the caller;
--   2. an absent answer;
--   3. an unparseable token (four sub-shapes, see 'decode_word_token');
--   4. an ALL-ZERO WORD -- no pool at that slot, for every field, regardless of (5);
--   5. a decoded ZERO, for the fields where zero is impossible-if-present ('zero_is_refused').
refuse_or_value :: PoolField -> ReadAt -> Maybe String -> Either String Integer
refuse_or_value field at supplied
  | Pinned ref <- at, block_height ref < 0 =
      refuse ("the block height " ++ show (block_height ref) ++ " is negative, so there is no block"
               ++ " to pin to. Refused before any call: the node answers a negative block parameter"
               ++ " with a JSON-RPC error that names neither this field nor this caller.")
  | otherwise =
      case supplied of
        Nothing ->
          refuse ("the read returned NOTHING -- no answer to parse. An absent read is not a zero"
                   ++ " and must not become one: a caller handed a zero here cannot tell a slot"
                   ++ " that holds nothing from a call that never happened.")
        Just token ->
          case decode_word_token token of
            Left why -> refuse ("the answer is unparseable as a storage word: " ++ why)
            Right w
              | w == 0 ->
                  refuse ("the 32-byte word is ALL ZERO. That is not a zero value, it is NO POOL at"
                           ++ " that slot: v4's initialize ALWAYS stores a nonzero sqrtPriceX96, and"
                           ++ " extsload of an untouched slot returns exactly this word. Reachable"
                           ++ " by a stale poolId, a POOLS_SLOT that has drifted from the deployed"
                           ++ " manager's layout, an uninitialised pool, the wrong manager, or a pin"
                           ++ " to a block BEFORE the pool was initialised -- the last of which was"
                           ++ " OBSERVED against the rig at 27-02.")
              | zero_is_refused field, extract_pool_field field w == 0 ->
                  refuse ("the word is well-formed and nonzero but this field decodes to ZERO,"
                           ++ " which is shape-valid and meaningless. It must not reach a content"
                           ++ " key: a zero here is the NotBound shape -- a revert that returned 0x"
                           ++ " one layer down, or a manager whose pool has this field unset -- and"
                           ++ " it is indistinguishable from a real measurement once it is an"
                           ++ " Integer.")
              | otherwise -> Right (extract_pool_field field w)
  where
    refuse why = Left ("chain read REFUSED for " ++ refusal_naming field ++ " " ++ site ++ ": "
                        ++ why)
    site = case at of
      Pinned ref -> "pinned at block " ++ show (block_height ref)
      Unpinned   -> "with NO block pin"

-- ---------------------------------------------------------------------------------------------
-- The reads. EVERY ONE REQUIRES A BlockRef, POSITIONALLY.
-- ---------------------------------------------------------------------------------------------
--
-- Each signature below is written on ONE line, and @no_read_can_omit_its_block@ depends on that:
-- it captures the @::@ line and asserts the captured signature is COMPLETE (paren-balanced, not
-- ending in an arrow) before it asserts anything about the type. A signature broken across lines
-- therefore fails that check loudly rather than passing because the extractor saw a fragment.

-- | The raw token for one field's slot, at one block. The transport edge, and nothing else.
read_raw_word_token :: Address -> Integer -> PoolField -> BlockRef -> Web3 String
read_raw_word_token manager pool_id field ref = do
  calldata <- liftIO (encode_extsload (pool_field_slot pool_id field))
  returned <-
    GlobalState.call
      Call
        { callFrom     = Nothing
        , callTo       = Just manager
        , callGas      = Nothing
        , callGasPrice = Nothing
        , callValue    = Nothing
        , callData     = Just calldata
        , callNonce    = Nothing
        }
      (block_param ref)
  pure (render_word_token (toBytes returned))

-- | One field, at one block, refused by name or returned as a value.
read_pool_field :: Address -> Integer -> PoolField -> BlockRef -> Web3 (Either String Integer)
read_pool_field manager pool_id field ref
  | block_height ref < 0 = pure (refuse_or_value field (Pinned ref) Nothing)
  | otherwise = do
      token <- read_raw_word_token manager pool_id field ref
      pure (refuse_or_value field (Pinned ref) (Just token))

read_pool_state_word :: Address -> Integer -> BlockRef -> Web3 (Either String Integer)
read_pool_state_word manager pool_id = read_pool_field manager pool_id PoolStateWord

read_sqrt_price_x96 :: Address -> Integer -> BlockRef -> Web3 (Either String Integer)
read_sqrt_price_x96 manager pool_id = read_pool_field manager pool_id SqrtPriceX96

read_liquidity :: Address -> Integer -> BlockRef -> Web3 (Either String Integer)
read_liquidity manager pool_id = read_pool_field manager pool_id Liquidity

read_lp_fee :: Address -> Integer -> BlockRef -> Web3 (Either String Integer)
read_lp_fee manager pool_id = read_pool_field manager pool_id LpFee
