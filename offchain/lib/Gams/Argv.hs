-- |
-- The canonical argv renderer -- and the reason it is not hygiene.
--
-- WHY THIS MODULE DECIDES THE ARTIFACT'S BYTES
-- --------------------------------------------
-- @volume_path.gms@ lines 206-207 are
--
-- > put '  "sqrtPriceX96": "%sqrtPriceX96%",' /;
-- > put '  "liquidity": "%liquidityRaw%",'    /;
--
-- and @%..%@ is a COMPILE-TIME SUBSTITUTION OF THE RAW COMMAND-LINE STRING. The token this module
-- emits is therefore copied verbatim into the artifact for those two fields. MEASURED against the
-- real binary on 2026-08-16, with everything else held fixed:
--
-- > --sqrtPriceX96=79228162514264337593543950336    exit 0, every gate green, sha256 e7b14f38..07d0d884  (golden)
-- > --sqrtPriceX96=079228162514264337593543950336   exit 0, every gate green, sha256 d64a7b32..14b9e650
--
-- Two numerically identical shocks, every §4 gate passing in both runs, DIFFERENT BYTES. So
-- \"same inputs plus same toolchain gives the same bytes\" is true only modulo a rendering
-- convention, and the convention is chosen HERE, because this phase owns the @execve@. The
-- canonical form is a decision of record: Phase 25's key normalization is DOWNSTREAM of it, and a
-- key computed over a shock whose rendering was never pinned would identify two artifacts that are
-- not byte-equal.
--
-- THE ASYMMETRY, ALSO MEASURED, THAT MUST NOT BE MIS-GENERALISED
-- -------------------------------------------------------------
-- Only the two echoed STRING fields are token-sensitive. @volTgtWad@ is a GAMS @Scalar@ -- it is
-- never echoed into the artifact, and @--volTgtWad=28e18@ and @--volTgtWad=2.8e19@ produce
-- BYTE-IDENTICAL output (both sha256 e7b14f38..07d0d884). The remaining five inputs are re-rendered
-- by GAMS itself through its own @:0:0@ and @:0:10@ put formats.
--
-- The conclusion a later reader must NOT draw from that is \"the renderer only matters for two
-- fields\". It matters for all seven; the two echoed ones are simply where its ABSENCE is
-- observable in the artifact. The other five would fail silently -- an out-of-range or oddly
-- spelled token there changes what the model computes, or aborts it, without leaving a rendering
-- fingerprint behind.
--
-- WHY EVERY FIELD IS A STRICT 'Integer' AND NOTHING IS OPTIONAL
-- ------------------------------------------------------------
-- There is no optional field and no defaultable field in 'Shock'. That is KEY-06's type-level half
-- arriving one phase early: @nEvents = 0@, @liquidity = 0@ and @sqrtPriceX96 = 0@ are REFUSALS
-- here rather than shape-valid nothings that reach the solver and produce a plausible artifact
-- from an absent subject.
--
-- 'Integer' is load-bearing twice. A bounded type would wrap at @2^64@ while @sqrtPriceX96@ is a
-- uint160 and @liquidity@ is a uint128. And a FLOATING type would put the C library's numeric
-- locale on the key path: its rendering carries a decimal separator and an exponent convention
-- that are settings rather than facts. No floating value appears in this module at all -- not as a
-- field, not as an intermediate, and not in @parse_shock_field@, which shifts mantissa digits by
-- an exponent in 'Integer' arithmetic instead of going through a floating conversion.
module Gams.Argv
  ( -- * The shock
    Shock (..)
    -- * Rendering
  , render_decimal
  , render_argv
    -- * The edge
  , parse_shock_field
    -- * Why a render or a parse failed
  , ArgvError (..)
  ) where

-- @foldl'@ is in the Prelude at base 4.20, so importing it from @Data.List@ is redundant and
-- -Wall says so. Nothing else is imported here: this module builds no value it was not handed.
import Data.Char (digitToInt, isDigit)

-- ---------------------------------------------------------------------------------------------
-- The types
-- ---------------------------------------------------------------------------------------------

-- | The seven inputs of @VOLUME_PATH.md@ §2, all exact, none optional.
data Shock = Shock
  { sh_sqrt_price_x96  :: !Integer
    -- ^ uint160, the Q64.96 square root price.
  , sh_liquidity_raw   :: !Integer
    -- ^ uint128, raw pool liquidity.
  , sh_txl_volume_rate :: !Integer
    -- ^ pips: the realized transaction-volume rate times @1e6@.
  , sh_phi_x_pips      :: !Integer
    -- ^ pips: the fee on the numeraire leg.
  , sh_phi_m_pips      :: !Integer
    -- ^ pips: the fee on the other leg.
  , sh_vol_tgt_wad     :: !Integer
    -- ^ wei, EXACT. The one field GAMS consumes as a scalar, and still exact on this side.
  , sh_n_events        :: !Integer
    -- ^ the event count the two output arrays must both have.
  } deriving (Eq, Show)

-- | Why a shock could not be rendered, or a token could not be normalized.
--
-- Both constructors NAME their subject: the field or the offending token, so the message an
-- operator sees identifies which of seven inputs was wrong rather than reporting that one of them
-- was.
data ArgvError
  = FieldOutOfRange String Integer String
    -- ^ the field name, the value it carried, and the bound it violated
  | NotADecimalInteger String String
    -- ^ the token verbatim, and what was wrong with it
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------------------------

-- | The canonical decimal form of an 'Integer'. Total, and the only renderer on this path.
--
-- It never emits a leading zero, a @+@ sign, an exponent, a grouping separator or any whitespace,
-- because 'show' at 'Integer' emits none of those -- which is precisely why the type is 'Integer'
-- and not something whose rendering depends on a numeric locale.
--
-- > render_decimal 79228162514264337593543950336 == "79228162514264337593543950336"
-- > render_decimal 0 == "0"
--
-- A negative value would render with a leading @-@; every caller below refuses negatives by range
-- before this function is reached, so the sign never enters an argv token.
render_decimal :: Integer -> String
render_decimal = show

-- | The seven argv tokens, in this exact order and with nothing else in the list.
--
-- The order is fixed so the rendering is a function of the shock alone: GAMS accepts @--@
-- parameters in any order, and a rendering that reordered them would still solve while producing a
-- different command line for the same shock -- which is the same class of ambiguity the leading
-- zero produced in the bytes.
--
-- Eight refusals happen before any token is built, each naming its field and its bound. Seven are
-- range facts. The eighth is a MODEL fact taken from @VOLUME_PATH.md@ §1.2: equal fees on the two
-- legs are infeasible for EVERY target, so the shock is refused here, in this process, rather than
-- spawned and recovered as a named abort whose exit code (3) cannot be distinguished from an
-- unhandled execution error anyway.
render_argv :: Shock -> Either ArgvError [String]
render_argv shock = do
  _ <- in_range "sqrtPriceX96" (sh_sqrt_price_x96 shock) 1 (two_pow 160 - 1)
         "a uint160 that is nonzero: a zero price is not a shock, it is an absent one"
  _ <- in_range "liquidityRaw" (sh_liquidity_raw shock) 1 (two_pow 128 - 1)
         "a uint128 that is nonzero: a pool with no liquidity has no path to compute"
  _ <- in_range "txlVolumeRate" (sh_txl_volume_rate shock) 0 999999
         "pips strictly below 1000000 -- VOLUME_PATH.md section 4 aborts on a transaction-volume\
         \ rate at or above 100%"
  _ <- in_range "phiXpips" (sh_phi_x_pips shock) 1 (two_pow 64)
         "a positive pip count: a zero fee is not a fee schedule"
  _ <- in_range "phiMpips" (sh_phi_m_pips shock) 1 (two_pow 64)
         "a positive pip count: a zero fee is not a fee schedule"
  _ <- in_range "volTgtWad" (sh_vol_tgt_wad shock) 1 (two_pow 256 - 1)
         "a positive wei amount: a zero target admits every path and selects none"
  _ <- in_range "nEvents" (sh_n_events shock) 1 (two_pow 32)
         "a positive event count: zero events makes both output arrays empty, and an empty array\
         \ is what an absent subject looks like"
  _ <- distinct_fees shock
  Right
    [ "--sqrtPriceX96="  ++ render_decimal (sh_sqrt_price_x96 shock)
    , "--liquidityRaw="  ++ render_decimal (sh_liquidity_raw shock)
    , "--txlVolumeRate=" ++ render_decimal (sh_txl_volume_rate shock)
    , "--phiXpips="      ++ render_decimal (sh_phi_x_pips shock)
    , "--phiMpips="      ++ render_decimal (sh_phi_m_pips shock)
    , "--volTgtWad="     ++ render_decimal (sh_vol_tgt_wad shock)
    , "--nEvents="       ++ render_decimal (sh_n_events shock)
    ]

-- | @VOLUME_PATH.md@ §1.2: equal fees are infeasible for every target, so this is a refusal and
-- not a warning.
distinct_fees :: Shock -> Either ArgvError ()
distinct_fees shock
  | sh_phi_x_pips shock == sh_phi_m_pips shock =
      Left (FieldOutOfRange "phiXpips" (sh_phi_x_pips shock)
             ("a pip count DIFFERENT from phiMpips, which carries the same value "
               ++ render_decimal (sh_phi_m_pips shock)
               ++ ". VOLUME_PATH.md section 1.2: equal fees on the two legs are infeasible for"
               ++ " EVERY target, so this"
               ++ " shock has no solution at all and spawning it would spend a solve to learn"
               ++ " something the input already says."))
  | otherwise = Right ()

in_range :: String -> Integer -> Integer -> Integer -> String -> Either ArgvError ()
in_range field value low high wanted
  | value < low || value > high =
      Left (FieldOutOfRange field value
             (wanted ++ " (admitted range " ++ render_decimal low ++ " .. "
               ++ render_decimal high ++ ")"))
  | otherwise = Right ()

two_pow :: Integer -> Integer
two_pow n = 2 ^ n

-- ---------------------------------------------------------------------------------------------
-- The edge
-- ---------------------------------------------------------------------------------------------

-- | THE NORMALIZER AT THE EDGE. Every externally-supplied token passes through here, and what
-- comes out is an 'Integer' that 'render_decimal' will then spell canonically.
--
-- This is what makes the leading zero unable to survive to the @execve@: the value is rebuilt from
-- its digits and re-spelled, so @\"079228162514264337593543950336\"@ and
-- @\"79228162514264337593543950336\"@ become the same 'Integer' and therefore the same token. It
-- is also what settles Phase 25's KEY-04 in advance -- @\"28e18\"@ and @\"28000000000000000000\"@
-- are the SAME value here, so they cannot key two rows.
--
-- Accepted: a non-empty run of decimal digits, optionally followed by @e@ or @E@ and a second
-- non-empty run of decimal digits, whose value is @mantissa * 10^exponent@ computed entirely in
-- 'Integer' arithmetic.
--
-- Refused, each naming the token: an empty token, a sign of either kind, leading or trailing
-- whitespace, a decimal point (@1.5@, and also @2.85e1@, whose VALUE is an integer -- a
-- fractional mantissa is refused on FORM, because admitting it would require deciding when a
-- floating spelling is exact and that decision does not belong at an edge), a negative or absent
-- exponent, a radix prefix, and a digit-grouping separator.
--
-- The exponent is bounded. An unbounded one turns a 4-character token into an arbitrarily large
-- allocation, which is a denial of service handed to whoever supplies the shock; @10^96@ is far
-- above every field's admitted range and the refusal names the bound.
parse_shock_field :: String -> Either ArgvError Integer
parse_shock_field token =
  case break is_exponent_marker token of
    (mantissa, []) -> from_digits token "the token" mantissa
    (mantissa, _ : power) -> do
      m <- from_digits token "the mantissa" mantissa
      e <- from_digits token "the exponent" power
      if e > max_exponent
        then Left (NotADecimalInteger token
                    ("the exponent " ++ render_decimal e ++ " exceeds the admitted bound "
                      ++ render_decimal max_exponent ++ ", which is above every field's range"))
        else Right (m * (10 ^ e))

is_exponent_marker :: Char -> Bool
is_exponent_marker c = c == 'e' || c == 'E'

max_exponent :: Integer
max_exponent = 96

-- | A non-empty run of ASCII decimal digits, folded into an 'Integer'.
--
-- 'Data.Char.digitToInt' is applied only after 'Data.Char.isDigit' has admitted the character, so
-- it is total here; 'Data.Char.isDigit' is ASCII-only, which is why a full-width digit or an
-- Arabic-Indic one is refused rather than silently accepted with some other value.
from_digits :: String -> String -> String -> Either ArgvError Integer
from_digits token part s
  | null s =
      Left (NotADecimalInteger token (part ++ " is empty"))
  | not (all isDigit s) =
      Left (NotADecimalInteger token
             (part ++ " carries a character that is not an ASCII decimal digit; a sign, a decimal"
               ++ " point, whitespace, a radix prefix and a grouping separator are all refused"))
  | otherwise =
      Right (foldl' step 0 s)
  where
    step acc c = acc * 10 + toInteger (digitToInt c)
