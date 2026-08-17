-- | THIS MODULE READS ONE LOG AND NOTHING ELSE.
--
-- The @Shock@ event is the mev-tax model's one outbound measurement: the tick delta the period
-- moved, the transactional-volume rate that period realized, and the decay applied to it. The
-- emitter is @src\/models\/mev_tax_model_one\/libraries\/ShockLib.plk@, which is NOT in this
-- worktree — it lives on @origin\/develop@ (merged there by PR #30) and is read here through
-- @git show@, never by merging and never by editing. Its whole body is four statements:
--
-- > let buf = @malloc_uninit(96);
-- > @mstore32(buf,       shock_tick_diff(R, s));
-- > @mstore32(buf +% 32, shock_txl_volm_norm_rate(R, s));
-- > @mstore32(buf +% 64, shock_txl_volm_decay(R, s));
-- > @evm_log2(buf, 96, SHOCK_EVENT_TOPIC0, pool);
--
-- @\@evm_log2@ is EXACTLY two topics, @[topic0, pool]@; 96 bytes is EXACTLY three data words, in
-- emission order @[tickDiff, txlVolmNormRate, txlVolmDecay]@. The declaration the topic0 hashes is
-- @Shock(address,int24,uint24,uint24)@, and 'shock_signature' below is that string — it lives in
-- the LIBRARY so a test hashing it is hashing the string this decoder is documented against rather
-- than a second transcription of it.
--
-- == WHAT THIS DECODER MUST NOT BE TRUSTED ON
--
-- Three separate things, and every one of them is a caller obligation this module cannot discharge.
--
-- (1) __Two of the three data words are structurally zero in v6.0 production traffic.__ Issue #28
-- tags the on-chain hookData @flags = 0b010@, so @Shock.plk@'s @shock_tick_diff@ and
-- @shock_txl_volm_decay@ accessors return a literal @0@ — their flag bits are unset — and every
-- production log therefore carries @tickDiff = 0@ and @txlVolmDecay = 0@ by construction. A
-- decoder that never sign-extends, that reads the wrong word, or that defaults to zero on failure
-- is GREEN on every real log. Any confidence in this module comes from the synthetic corpus
-- carrying a NEGATIVE @tickDiff@ and a NONZERO decay, which production never emits.
--
-- (2) __An event topic is UNAUTHENTICATED.__ Any contract at any address can emit a log whose
-- topic0 is the keccak of this signature with any 32-byte word it likes in topic 1. @pool \/= 0@
-- and @pool \< 2^160@ make a log WELL-SHAPED, not AUTHENTIC. That is why 'decode_shock' takes an
-- @expected_emitter@ argument and refuses with 'WrongEmitter' — matching the address the log came
-- from is the only thing in the log that a stranger cannot forge. @RealizedVol.Decode@ says the
-- same thing about its own two events; this one needs it more, because its topic 1 is an address
-- rather than a poolId and so carries no second discriminator at all.
--
-- (3) __The return type carries no block, no log index and no transaction.__ 'Change' has
-- @changeBlockNumber@, @changeLogIndex@ and @changeTransactionHash@; 'ShockEvent' has none of them
-- and cannot be given them without changing every consumer. Decode a batch and you get N events
-- with no way to say which block each came from, which is the \"silently mix state from two
-- blocks\" failure in its purest form. A caller that decodes more than one log MUST carry the
-- block coherence itself, alongside the 'Change' values it decoded from. Said here because there
-- is nowhere else a caller is guaranteed to look.
--
-- == Why @expected_topic0@ is an ARGUMENT
--
-- Verbatim the reason @RealizedVol.Decode@ gives: a wrong topic0 does not look wrong — it simply
-- matches no log, so decoding \"succeeds\" at reporting nothing, forever. Passing it in keeps this
-- module free of any dependency it would otherwise acquire to compute it, keeps it testable from
-- pure values, and puts the staleness where a check can see it. @expected_emitter@ is an argument
-- for the same reason and one more: the address is a deployment fact, and a deployment fact
-- compiled into a decoder is a decoder that is wrong on every other deployment.
module Chain.Shock
  ( shock_signature
  , ShockEvent (..)
  , ShockDecodeError (..)
  , decode_shock
  ) where

import qualified Data.ByteString as BS
import Data.ByteArray.HexString (toBytes)
import Data.Solidity.Prim.Address (toHexString)

import Network.Ethereum.Api.Types (Change (..))

import RealizedVol.Decode (signed_word)
import VolOrder.Decode (data_word, hex_to_integer)

-- | The canonical signature string the event's topic0 is the keccak of.
--
-- It is @address@-keyed, not poolId-keyed, and that is a fact about THIS event rather than about
-- the family: a sibling writer interface in the same model
-- (@UniswapV4MevTaxModelOneShocksWriterInterface.plk@) keys by @bytes32@ poolId, which would be a
-- DIFFERENT signature string and therefore a DIFFERENT topic0. See 'NotAnAddress'.
shock_signature :: String
shock_signature = "Shock(address,int24,uint24,uint24)"

-- | The decoded payload. All four fields are 'Integer' and RAW — nothing is rescaled on the way
-- out, because every one of them is a raw on-chain field and a decoder that quietly rescaled would
-- make the wire value unrecoverable.
data ShockEvent = ShockEvent
  { se_pool      :: !Integer
    -- ^ topic 1, an indexed @address@, left-padded into a 32-byte word by the log encoding.
  , se_tick_diff :: !Integer
    -- ^ data word 0, an @int24@ that arrives SIGN-EXTENDED to the full 256-bit word.
  , se_norm_rate :: !Integer
    -- ^ data word 1, a @uint24@ in pips. THE ONE FIELD that becomes the prover's
    -- @txlVolumeRate@ argv token.
  , se_txl_decay :: !Integer
    -- ^ data word 2, a @uint24@ in pips. RECORDED here and, by @VOLUME_PATH.md@ section 2's
    -- ruling, never sent to the prover: \"@txlDecayRate@ is __not__ an input by ruling: the closed
    -- loop is trusted.\"
  } deriving (Eq, Show)

-- | Why a log was refused. POSITIONAL constructors on purpose — record selectors on a sum type are
-- partial, and GHC 9.10 puts @-Wincomplete-record-selectors@ inside @-Wall@, which is a gate here.
--
-- Every constructor carries the value it objected to, so an operator learns which of ten reasons
-- fired AND what the log actually said, rather than that one of them fired.
data ShockDecodeError
  = WrongTopicArity Int
    -- ^ the number of topics found. @\@evm_log2@ emits exactly two.
  | WrongTopic0 Integer
    -- ^ the topic0 found, as an 'Integer'.
  | WrongEmitter Integer
    -- ^ the emitting address found, as an 'Integer'. A well-shaped forgery from a stranger.
  | NotAnAddress Integer
    -- ^ topic 1 read as an 'Integer', when it does not fit in 160 bits.
  | ZeroPool
    -- ^ topic 1 is the zero address, which is what an ABSENT subject looks like.
  | WrongDataLength Int
    -- ^ the payload length in bytes. Must be exactly 96.
  | ZeroShock
    -- ^ all three data words are zero. NOT corruption — see 'decode_shock'.
  | TickDiffOutOfRange Integer
    -- ^ the sign-extended word 0, when it is outside @int24@.
  | NormRateOutOfRange Integer
    -- ^ word 1, when it is outside @uint24@.
  | DecayOutOfRange Integer
    -- ^ word 2, when it is outside @uint24@.
  deriving (Eq, Show)

-- | The most negative @int24@, @-(2^23)@.
int24_low :: Integer
int24_low = -8388608

-- | One past the most positive @int24@, @2^23@.
int24_high :: Integer
int24_high = 8388608

-- | One past the most positive @uint24@, @2^24@. This is @Shock.plk@'s own @MASK_U24@ bound
-- stated as an open upper limit rather than as a mask, because this module never masks: masking
-- here would DISCARD the very bits a transposed or garbage payload announces itself with.
uint24_high :: Integer
uint24_high = 16777216

-- | One past the largest @address@, @2^160@.
address_high :: Integer
address_high = 2 ^ (160 :: Int)

-- | Decode one @Shock@ log.
--
-- === The guard order is load-bearing and is therefore written down
--
-- It decides WHICH reason a malformed log reports, and a log can violate several rules at once:
--
--   1. topic arity must be exactly 2, else 'WrongTopicArity'. Checked first because every
--      subsequent guard reads a topic by position and a shorter list has none to read.
--   2. topic 0 must equal @expected_topic0@, else 'WrongTopic0'. This says the log is
--      Shock-SHAPED.
--   3. the emitting address must equal @expected_emitter@, else 'WrongEmitter'. This says the log
--      is Shock-shaped AND ours. It is second because a log from the wrong contract carrying the
--      wrong topic0 is more usefully reported as the wrong event than as the wrong source — the
--      topic is the thing a filter is written against.
--   4. topic 1 must be an address: @\< 2^160@ else 'NotAnAddress', then nonzero else 'ZeroPool'.
--      The zero address is the shape an absent subject takes, and it passes every hex-shape guard
--      in existence, so it is refused by name.
--   5. the payload must be EXACTLY 96 bytes, else 'WrongDataLength'.
--   6. all-zero payload, else the ranges. Ordered BEFORE the ranges because zero passes all three.
--   7. per-word ranges.
--
-- === Why the length rule is an EQUALITY and not an at-least
--
-- The at-least form is deliberately NOT spelled here, and that is itself a rule of this
-- repository: @26-02@'s own acceptance gate is @grep -c@ for that two-character operator followed
-- by @96@ over this file, and the first draft of this paragraph tripped it in the sentence
-- claiming the operator was absent. Prose is inside a grep's blast radius; the prose moved.
--
-- A DELIBERATE divergence from the at-least rule that @RealizedVol.Decode@ uses for E3 and E5 and
-- that @VolOrder.Decode@ uses for E1. That rule exists because 'VolOrder.Decode.data_word' is
-- @be_integer . BS.take 32 . BS.drop (32*i)@ and 'BS.drop' past the end of a 'BS.ByteString'
-- yields the EMPTY string, whose big-endian value is @0@ — not an error, not a 'Nothing'. So a
-- SHORT payload fabricates zeroes and must be refused. But an at-least rule also ACCEPTS A LONGER
-- ONE silently, and here that is strictly worse than refusing it: the emitter writes
-- @\@evm_log2(buf, 96, ...)@, so 96 is not a minimum but the only length this event has, and a
-- four-field event would carry a different signature and therefore a different topic0 and would
-- already have been refused at guard 2. @==@ is strictly stronger and loses nothing. @128@ is the
-- fixture that tells the two rules apart.
--
-- === Why 'ZeroShock' is not called corruption
--
-- All three data words zero is a LEGAL, MEANINGFUL production log, and the name says so.
--
-- Issue #28 emits all three components always, with absent ones written as @0@; v6.0 tags
-- @flags = 0b010@, so @tickDiff@ and @txlVolmDecay@ are zero on every production log. The only
-- thing that makes a real log non-all-zero is @txlVolmNormRate \/= 0@ — and that is the
-- transactional-volume rate, which is @0@ in a period with no transactional volume. A quiet period
-- is therefore all-zero, and calling that @AllZeroPayload@ would collapse \"nothing happened\"
-- into \"the log is corrupt\".
--
-- __The consumer rule, stated once, here.__ 'ZeroShock' is a SKIP: the period carried no shock and
-- there is nothing to prove. It is never a decode alarm and must never be escalated as one.
-- Refusing it costs nothing downstream either, because @Gams.Argv.render_argv@ already refuses
-- @txlVolumeRate = 0@ for a separate and independent reason — the prover's own ellipse gives
-- @E(x, m, 0) = D^4 x m > 0@, so a zero rate is inadmissible for every fee pair.
--
-- A second, rarer route to the same bytes exists and is worth recording: @shock_decode@ accepts
-- @flags = 0@ (it requires @buf.length == 1 + 3k@, and @k = 0@ with length 1 passes), so a log
-- with no components at all is emittable upstream too. Both routes are legal; neither is damage.
--
-- === Sign extension, on word 0 ONLY
--
-- @shock_tick_diff@ ends in @\@evm_signextend(2, raw)@, so word 0 arrives sign-extended to the
-- full 256 bits and 'RealizedVol.Decode.signed_word' — whose threshold is @2^255@ — is EXACTLY the
-- right conversion. A 24-bit mask is WRONG: it turns @-200@ into @16777016@, a plausible in-range
-- tick that is not one. No conversion at all is wrong the other way: it yields a 77-digit number.
--
-- @shock_txl_volm_norm_rate@ and @shock_txl_volm_decay@ end in @& MASK_U24@ — unsigned, range
-- @[0, 2^24)@. Applying 'signed_word' to either would be a SILENT bug, because a @uint24@ never
-- reaches @2^255@ and so the conversion would be an identity that looks correct until the day
-- someone widened the field.
--
-- === What the range guards are actually for
--
-- They are the ONLY thing in this decoder that catches a garbage 96-byte payload or a TRANSPOSED
-- word order, and they are derivable from @Shock.plk@'s own masks rather than chosen. They do NOT
-- close the pip domain: @uint24@ admits values up to @2^24@ while the model's rates are pips
-- strictly below @1000000@, and the gap between the two is real — a rate of @5000000@ passes here
-- and is refused by @Gams.Argv.render_argv@'s @txlVolumeRate@ bound. This module does not enforce
-- the pip domain and must not pretend to.
decode_shock :: Integer -> Integer -> Change -> Either ShockDecodeError ShockEvent
decode_shock expected_topic0 expected_emitter log_entry =
  case changeTopics log_entry of
    [topic0, pool_topic] -> do
      let found_topic0 = hex_to_integer topic0
          emitter      = hex_to_integer (toHexString (changeAddress log_entry))
          pool         = hex_to_integer pool_topic
          payload      = changeData log_entry
          payload_len  = BS.length (toBytes payload)
      refuse_unless (found_topic0 == expected_topic0) (WrongTopic0 found_topic0)
      refuse_unless (emitter == expected_emitter) (WrongEmitter emitter)
      refuse_unless (pool < address_high) (NotAnAddress pool)
      refuse_unless (pool /= 0) ZeroPool
      refuse_unless (payload_len == 96) (WrongDataLength payload_len)
      let w0 = data_word 0 payload
          w1 = data_word 1 payload
          w2 = data_word 2 payload
      refuse_unless (not (w0 == 0 && w1 == 0 && w2 == 0)) ZeroShock
      let tick = signed_word w0
      refuse_unless (int24_low <= tick && tick < int24_high) (TickDiffOutOfRange tick)
      refuse_unless (w1 < uint24_high) (NormRateOutOfRange w1)
      refuse_unless (w2 < uint24_high) (DecayOutOfRange w2)
      Right ShockEvent
        { se_pool      = pool
        , se_tick_diff = tick
        , se_norm_rate = w1
        , se_txl_decay = w2
        }
    topics -> Left (WrongTopicArity (length topics))

-- | @Left@ the given reason unless the condition holds. Written out rather than reached for so
-- that this module keeps its import list at five and imports no monad utility.
refuse_unless :: Bool -> ShockDecodeError -> Either ShockDecodeError ()
refuse_unless True  _   = Right ()
refuse_unless False why = Left why
