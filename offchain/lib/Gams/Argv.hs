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
  , render_argv_ungated
    -- * The edge
  , parse_shock_field
    -- * Why a render or a parse failed
  , ArgvError (..)
  ) where

-- @foldl'@ is in the Prelude at base 4.20, so importing it from @Data.List@ is redundant and
-- -Wall says so.
import Data.Char (digitToInt, isDigit)

-- The prover's own admissibility test, and the pip unit its bound is stated in. This is the ONLY
-- import here that is not from @base@, and it exists so the ninth refusal below is the model's test
-- itself rather than a second transcription of it living beside the first.
import Fee.Split (ellipse_test, is_admissible, min_admissible_dstar, pips_denominator)

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
  | Inadmissible Integer Integer Integer Integer (Maybe Integer)
    -- ^ @phiXpips@, @phiMpips@, @txlVolumeRate@, the exact @E@, and the least @txlVolumeRate@ this
    --   pair admits (@Nothing@ when the pair admits none at all).
    --
    --   POSITIONAL AND WITHOUT A SENTENCE FIELD, unlike its two siblings, and that is a decision
    --   rather than an oversight. The two above carry prose because the value alone does not say
    --   what was wanted; here every number a reader needs IS one of the five fields, and @show@
    --   prints all five. A sixth 'String' field would also make the value unpinnable -- a check
    --   that asserts the whole refusal by equality could then only assert a sentence it had to
    --   transcribe, and a transcribed sentence agrees with itself.
    --
    --   What a reader sees, and what each field is for, in the @in_range@ voice: the pair
    --   @(phiXpips, phiMpips)@ was handed the target @txlVolumeRate@ pips; the prover's own
    --   @ellTest@ at that point is @E@, and it must be at or below zero; the admitted range for
    --   this pair starts at the fifth field and runs to 999999, or the pair admits no target at
    --   all and there is no boundary to name. That last case is real and not defensive:
    --   @min_admissible_dstar 3000 3000@ is @Nothing@, because equal legs make the admissibility
    --   quadratic touch zero at a point that is not an integer number of pips.
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
-- NINE refusals happen before any token is built, each naming its field and its bound. Seven are
-- range facts. The eighth is a MODEL fact taken from @VOLUME_PATH.md@ §1.2: equal fees on the two
-- legs are infeasible for EVERY target, so the shock is refused here, in this process, rather than
-- spawned and recovered as a named abort whose exit code (3) cannot be distinguished from an
-- unhandled execution error anyway.
--
-- THE NINTH IS THE PROVER'S OWN GATE, and it is the model's line rather than a summary of it.
-- @volume_path.gms:100-108@ computes @ellTest@ and aborts on @ellTest > 0@; 'Fee.Split.ellipse_test'
-- is that expression transcribed term for term and multiplied through by a power of the pip unit so
-- it evaluates in exact 'Integer' arithmetic. A shock GAMS would abort on therefore has NO ARGV AT
-- ALL, which is a stronger statement than \"the abort is recovered\": there is nothing for
-- @Gams.Run.spawn_into@ to receive, so no process is started, no run directory is created, and the
-- refusal is a value in this process.
--
-- IT SUBSUMES THE @txlVolumeRate = 0@ HOLE RATHER THAN ADDING A SECOND BOUND. The range above
-- admits @0@ while every other field demands @>= 1@, and that asymmetry is real: a zero rate is a
-- quiet period, not an absent one. But @E(x, m, 0)@ is @D^4 * x * m@, strictly positive for any two
-- nonzero fees, so the ninth refusal already refuses it -- and refusing it HERE rather than by
-- raising the lower bound keeps one bound where a second could drift away from the model it came
-- from.
--
-- IT RUNS AFTER 'distinct_fees', ON PURPOSE, AND THE REASON IS MEASURED. At equal legs the
-- admissibility quadratic has a double root at a point that is not an integer number of pips, so
-- @Fee.Split.min_admissible_dstar 3000 3000@ is @Nothing@ -- the ellipse refuses equal fees for
-- EVERY integer target, entirely on its own. Running it first would leave the refusal COUNT
-- unchanged while replacing §1.2's specific diagnosis with a generic one, which is a diagnosis lost
-- without anything going red. The suite asserts this behaviourally rather than by line number,
-- because a later refactor that splits this function moves the two calls into different functions
-- and a line-number comparison between them then means nothing: what must survive is that a
-- @(3000, 3000)@ shock is refused by 'distinct_fees' and NOT by 'Inadmissible'.
--
-- THE SYMMETRY THAT MAKES THE LEG ORDER IRRELEVANT HERE. @ellTest@ is symmetric in the two legs --
-- every term is built from @x+m@, @(m-x)^2@ or @x*m@ -- so this refusal cannot depend on which leg
-- was handed in first. Only the LEVEL and the ordering convention care about that, and neither is
-- decided in this module.
--
-- THE FUNCTION IS SPLIT, AND THE COMPOSITION IS FIXED RATHER THAN CHOSEN. The eight refusals live
-- in 'render_argv_ungated' and the ninth is applied here, AFTER it. Writing this the other way
-- round -- the ninth bound first, the eight after -- type-checks, keeps the refusal COUNT at nine,
-- and silently replaces §1.2's diagnosis with a generic one for every equal-fee shock, because
-- 'Fee.Split.min_admissible_dstar' at equal legs is 'Nothing' for every integer target. The suite
-- asserts the composition BY CONSTRUCTOR for that reason.
render_argv :: Shock -> Either ArgvError [String]
render_argv shock = do
  argv <- render_argv_ungated shock
  _    <- admissible_pair shock
  pure argv

-- | THE EIGHT REFUSALS ONLY -- and it exists for EXACTLY ONE CONSUMER.
--
-- That consumer is @offchain\/app\/FeeSplitConformance.hs@, the out-of-band capture that drives the
-- real prover at points the ninth refusal rejects. It has to: the whole content of that capture is
-- what GAMS does ONE PIP BELOW each fee pair's admissibility boundary, and 'render_argv' cannot
-- build a command line for such a shock. That is the point of the ninth refusal and it is not being
-- weakened here -- it is being stepped around, once, by the tool whose subject is the refusal
-- itself.
--
-- USING THIS ANYWHERE ELSE DEFEATS FEE-03. \"An inadmissible shock is refused before any
-- subprocess\" is a property of the import graph, not of a comment: a second consumer is how it
-- quietly stops being true, because nothing about the second one would look wrong. The suite
-- therefore asserts the CONSUMER SET in both directions -- 'the_ungated_renderer_has_exactly_one_consumer'
-- scans @offchain\/@ and requires exactly this module and that file. A one-directional assertion
-- passes on a second consumer appearing, which is why it is a set.
--
-- Production callers -- including 'Gams.Run.run_prover', which is the only path to an @execve@ --
-- go through 'render_argv' and get all nine.
render_argv_ungated :: Shock -> Either ArgvError [String]
render_argv_ungated shock = do
  _ <- in_range "sqrtPriceX96" (sh_sqrt_price_x96 shock) 1 (two_pow 160 - 1)
         "a uint160 that is nonzero: a zero price is not a shock, it is an absent one"
  _ <- in_range "liquidityRaw" (sh_liquidity_raw shock) 1 (two_pow 128 - 1)
         "a uint128 that is nonzero: a pool with no liquidity has no path to compute"
  -- The upper bound is stated as the pip unit less one rather than as a second copy of 999999,
  -- because it IS that unit: §4 aborts on a transaction-volume rate at or above 100%. The lower
  -- bound stays at zero deliberately -- see the ninth refusal below, which is what actually refuses
  -- a zero rate, and does it with the model's own test instead of a second bound.
  _ <- in_range "txlVolumeRate" (sh_txl_volume_rate shock) 0 (pips_denominator - 1)
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

-- | THE NINTH REFUSAL: @volume_path.gms@'s own @ellTest@, evaluated here, in exact 'Integer'
-- arithmetic, before any token exists.
--
-- Ordered AFTER 'distinct_fees' for the reason recorded in 'render_argv': the ellipse refuses equal
-- legs too, so putting it first would keep the refusal and lose §1.2's diagnosis.
--
-- The boundary is recomputed rather than remembered. 'Fee.Split.min_admissible_dstar' is the same
-- bisection the splitter uses to fill @fs_boundary_pips@, so the number an operator reads in this
-- refusal and the number a recorded split carries come from one implementation; a constant here
-- would be a second answer that could drift, and \"infeasible\" with no number at all is the
-- failure this constructor exists to prevent.
admissible_pair :: Shock -> Either ArgvError ()
admissible_pair shock
  | is_admissible phi_x phi_m target = Right ()
  | otherwise =
      Left (Inadmissible phi_x phi_m target
             (ellipse_test phi_x phi_m target)
             (min_admissible_dstar phi_x phi_m))
  where
    phi_x  = sh_phi_x_pips shock
    phi_m  = sh_phi_m_pips shock
    target = sh_txl_volume_rate shock

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
