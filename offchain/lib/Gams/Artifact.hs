-- |
-- BYTE-04: the artifact's arrays become @[Integer]@, and nothing on this path ever builds a
-- 53-bit floating value.
--
-- WHY THE 53-BIT PATH IS NOT AN OPTION
-- ------------------------------------
-- COMPUTED from the committed @offchain\/rig\/volume-path-golden.json@ (606 bytes, sha256
-- e7b14f38..07d0d884), by taking each array element through IEEE-754 binary64 and rounding back:
--
-- > dQx[0]  exact -2613128317657530400   binary64 -2613128317657530368   delta   32
-- > dQx[1]  exact -2680707973111378000   binary64 -2680707973111377920   delta   80
-- > dQx[2]  exact  4861675431041821000   binary64  4861675431041820672   delta -328
--
-- ALL SIXTEEN elements of @dQx ++ dQM@ are inexact, with @|delta|@ between 4 and 328. These are
-- wei. The arrays are swap amounts, so a rounded element is a swap this repository would execute
-- on chain for an amount the model never chose -- and 32 wei is small enough that no eye and no
-- tolerance catches it, which is exactly why the suite asserts the truncation as an EQUALITY on
-- 'Integer's rather than as a bound.
--
-- WHY THIS IS HAND-WRITTEN
-- ------------------------
-- 'Store.Json' is the precedent and the reason: BYTE-03's source scan asserts that no JSON library
-- sits on the storage path, every module under @offchain\/lib\/Store\/@ is named in that scan's
-- list, and this module is now on it too. A library that turned the document into its own value
-- type would re-render every number on the way in, which is the failure the scan exists to
-- prevent, moved one directory over. So the bytes are gated by 'Store.Json.recognise_json_value'
-- -- a total pure recogniser that builds nothing -- and then walked by a small total tokenizer
-- that hands back the DIGITS it found and lets this module decide what they mean.
--
-- WHY FOUR FIELDS ARE KEPT AS TEXT
-- --------------------------------
-- 'pa_sqrt_price_x96_text' and 'pa_liquidity_text' are the two fields @volume_path.gms@ echoes
-- VERBATIM from the command line. They are kept as text for two independent reasons. A uint160 and
-- a uint128 both exceed the exactly-representable ceiling of the 53-bit floating type -- section 3
-- MEASURED that path printing 2^64 off by 384 wei. And the cross-check that closes the invocation
-- contract compares them to the argv TOKEN THAT WAS SENT, an equality that means nothing if either
-- side was rebuilt from a number: two spellings of one value would compare unequal, and one
-- spelling of two values would compare equal.
--
-- 'pa_delta_realized_text' and 'pa_r_phi_realized_text' are the document's only fractional fields,
-- and they are kept as text because nothing on this path may construct a 53-bit value AT ALL. They
-- are outputs rather than key material, no consumer in this phase needs their numeric value, and a
-- module that parsed them would have the very conversion this module exists to exclude sitting one
-- function away from the arrays.
--
-- 'pa_bytes' is the ORACLE. The decoded fields are a view; the bytes are the artifact, and Phase
-- 25 stores THEM.
module Gams.Artifact
  ( -- * The artifact
    ProverArtifact (..)
  , decode_artifact
    -- * Why a document was refused
  , ArtifactError (..)
  ) where

import qualified Data.ByteString as BS
import Data.Char (chr, digitToInt, isDigit, isHexDigit)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

import Store.Json (recognise_json_value)

-- ---------------------------------------------------------------------------------------------
-- The types
-- ---------------------------------------------------------------------------------------------

-- | The @volume_path.json@ document, as this repository is willing to look at it.
data ProverArtifact = ProverArtifact
  { pa_sqrt_price_x96_text :: !String
    -- ^ the echoed token, VERBATIM. Never turned into a number here.
  , pa_liquidity_text      :: !String
    -- ^ likewise.
  , pa_txl_volume_rate     :: !Integer
  , pa_phi_x_pips          :: !Integer
  , pa_phi_m_pips          :: !Integer
  , pa_n_events            :: !Integer
  , pa_delta_realized_text :: !String
    -- ^ a fractional output, kept as its digits.
  , pa_r_phi_realized_text :: !String
    -- ^ likewise.
  , pa_dqx                 :: ![Integer]
  , pa_dqm                 :: ![Integer]
  , pa_bytes               :: !BS.ByteString
    -- ^ the oracle, verbatim.
  } deriving (Eq, Show)

-- | Why a document is not an artifact. Every constructor names its subject.
data ArtifactError
  = NotJson String
    -- ^ the bytes are not a JSON value at all, with the recogniser's reason
  | MissingField String
    -- ^ the field name the document does not carry
  | NotAnInteger String
    -- ^ the offending token, verbatim
  | ShapeMismatch String
    -- ^ what disagreed with what
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The decoder
-- ---------------------------------------------------------------------------------------------

-- | Bytes to an artifact, or the reason they are not one. Total.
--
-- The order is deliberate: the recogniser refuses non-JSON before anything is extracted, the ten
-- named fields are then pulled out by name, and the post-conditions are applied LAST, over fields
-- that are already in hand. A shape check that ran during extraction could report a length
-- mismatch on a document whose real defect was a missing field.
decode_artifact :: BS.ByteString -> Either ArtifactError ProverArtifact
decode_artifact bytes = do
  _ <- case recognise_json_value bytes of
         Left why -> Left (NotJson why)
         Right () -> Right ()
  text <- case TE.decodeUtf8' bytes of
            Left err -> Left (NotJson (show err))
            Right t  -> Right (T.unpack t)
  members <- case json_value (skip_ws text) of
               Left why           -> Left (NotJson why)
               Right (JObject ms, _) -> Right ms
               Right (_, _)       ->
                 Left (ShapeMismatch "the artifact's top level is not a JSON object")
  sqrt_text  <- text_field  members "sqrtPriceX96"
  liq_text   <- text_field  members "liquidity"
  txl        <- int_field   members "txlVolumeRate"
  phi_x      <- int_field   members "phiXpips"
  phi_m      <- int_field   members "phiMpips"
  n_events   <- int_field   members "nEvents"
  delta_text <- digits_field members "deltaRealized"
  rphi_text  <- digits_field members "rPhiRealized"
  dqx        <- int_array   members "dQx"
  dqm        <- int_array   members "dQM"
  _ <- post_conditions n_events dqx dqm
  Right ProverArtifact
    { pa_sqrt_price_x96_text = sqrt_text
    , pa_liquidity_text      = liq_text
    , pa_txl_volume_rate     = txl
    , pa_phi_x_pips          = phi_x
    , pa_phi_m_pips          = phi_m
    , pa_n_events            = n_events
    , pa_delta_realized_text = delta_text
    , pa_r_phi_realized_text = rphi_text
    , pa_dqx                 = dqx
    , pa_dqm                 = dqm
    , pa_bytes               = bytes
    }

-- | The three structural facts, asserted over fields that are already in hand.
--
-- @nEvents@ is required POSITIVE. A zero event count makes both arrays legitimately empty, and an
-- empty array carrying no elements is indistinguishable from a solve that produced nothing -- the
-- absent-subject shape, in the one place where it would be handed straight to a swap builder.
--
-- The length comparison is made in 'Integer', not by narrowing @nEvents@ to a machine word: a
-- document claiming an event count above the word range would otherwise wrap into agreement with a
-- short array.
post_conditions :: Integer -> [Integer] -> [Integer] -> Either ArtifactError ()
post_conditions n_events dqx dqm
  | n_events <= 0 =
      Left (ShapeMismatch ("nEvents is " ++ show n_events ++ ", which is not positive. Both output"
                            ++ " arrays would legitimately be empty, and an empty array is what a"
                            ++ " solve that produced nothing looks like."))
  | toInteger (length dqx) /= n_events =
      Left (ShapeMismatch ("dQx carries " ++ show (length dqx) ++ " elements and nEvents is "
                            ++ show n_events ++ "."))
  | length dqm /= length dqx =
      Left (ShapeMismatch ("dQx carries " ++ show (length dqx) ++ " elements and dQM carries "
                            ++ show (length dqm) ++ "; they are the two legs of the same path."))
  | otherwise = Right ()

-- ---------------------------------------------------------------------------------------------
-- Field extraction
-- ---------------------------------------------------------------------------------------------

member_of :: [(String, Json)] -> String -> Either ArtifactError Json
member_of members name =
  case [v | (k, v) <- members, k == name] of
    (v : _) -> Right v
    []      -> Left (MissingField name)

-- | A field that must be a JSON string, kept exactly as it arrived.
text_field :: [(String, Json)] -> String -> Either ArtifactError String
text_field members name = do
  value <- member_of members name
  case value of
    JString s -> Right s
    other     -> Left (ShapeMismatch (name ++ " is not a JSON string: " ++ render_json other))

-- | A field that must be a JSON number, kept as the digits it arrived with.
digits_field :: [(String, Json)] -> String -> Either ArtifactError String
digits_field members name = do
  value <- member_of members name
  case value of
    JNumber token -> Right token
    other         -> Left (ShapeMismatch (name ++ " is not a JSON number: " ++ render_json other))

int_field :: [(String, Json)] -> String -> Either ArtifactError Integer
int_field members name = do
  value <- member_of members name
  integer_of value

int_array :: [(String, Json)] -> String -> Either ArtifactError [Integer]
int_array members name = do
  value <- member_of members name
  case value of
    JArray elements -> mapM integer_of elements
    other           -> Left (ShapeMismatch (name ++ " is not a JSON array: " ++ render_json other))

-- | THE RULE THAT MAKES BYTE-04 A TYPE FACT RATHER THAN A CONVENTION.
--
-- A token is an integer only if it matches @-?(0|[1-9][0-9]*)@ IN FULL and is not @-0@. So
-- @1.5@, @2.8e19@, @1e3@, @007@ and @-0@ are all refused, and so is anything that is not a number
-- token at all -- an empty string element included, which is what a truncated writer leaves
-- behind.
--
-- MEASURED at 24-02, and worth recording because it moves a refusal one layer EARLIER than
-- expected: @007@ never reaches this function. RFC 8259 admits no leading zero, so
-- 'Store.Json.recognise_json_value' refuses the whole document and the answer is @NotJson@ rather
-- than @NotAnInteger@. The leading-zero arm below is kept anyway. It costs one pattern, it is the
-- arm that would matter if this decoder were ever placed behind a laxer gate, and a guard whose
-- only defence is a component someone else maintains is a guard that can be removed by a change
-- nobody thought was about it.
--
-- @2.8e19@ deserves its own sentence. That is the exact form in which a volatility target
-- legitimately arrives on the COMMAND LINE, where 'Gams.Argv.parse_shock_field' normalizes it to
-- an exact 'Integer'. It is refused HERE because the artifact is an OUTPUT: a fractional or
-- exponent spelling in @dQx@ means the writer produced something this path cannot carry exactly,
-- and normalizing it would be this module deciding that a value it was not given is close enough.
integer_of :: Json -> Either ArtifactError Integer
integer_of value =
  case value of
    JNumber token -> integer_token token
    other         -> Left (NotAnInteger (render_json other))

integer_token :: String -> Either ArtifactError Integer
integer_token token =
  case token of
    ('-' : rest) -> fmap negate (unsigned_token token rest)
    _            -> unsigned_token token token

-- The leading-zero arm is written as a PATTERN rather than as @head digits == '0'@ on purpose:
-- -Wall's -Wx-partial rejects the partial accessor, and the case split says the same thing
-- totally. @0@ alone is a number; @007@ is a spelling nobody decided about.
unsigned_token :: String -> String -> Either ArtifactError Integer
unsigned_token token digits
  | not (all isDigit digits) = Left (NotAnInteger token)
  | token == "-0"            = Left (NotAnInteger token)
  | otherwise =
      case digits of
        []        -> Left (NotAnInteger token)
        ['0']     -> Right 0
        ('0' : _) -> Left (NotAnInteger token)
        _         -> Right (foldl' step 0 digits)
  where
    step acc c = acc * 10 + toInteger (digitToInt c)

-- ---------------------------------------------------------------------------------------------
-- The tokenizer
--
-- Small, total, and deliberately not a general-purpose value type: the number case keeps the
-- DIGITS rather than a numeric value, so nothing here can re-render what it was handed.
-- ---------------------------------------------------------------------------------------------

data Json
  = JString String
  | JNumber String
  | JArray [Json]
  | JObject [(String, Json)]
  | JLiteral String
  deriving (Eq, Show)

-- | Enough of a rendering to NAME a value in a failure message. Never a round trip.
render_json :: Json -> String
render_json value =
  case value of
    JString s  -> show s
    JNumber t  -> t
    JArray _   -> "an array"
    JObject _  -> "an object"
    JLiteral l -> l

skip_ws :: String -> String
skip_ws = dropWhile (\c -> c == ' ' || c == '\t' || c == '\n' || c == '\r')

json_value :: String -> Either String (Json, String)
json_value s =
  case s of
    []      -> Left "the input ended where a json value was expected"
    '{' : r -> json_object (skip_ws r)
    '[' : r -> json_array (skip_ws r)
    '"' : r -> do
      (str, rest) <- json_string r
      Right (JString str, rest)
    't' : r -> literal "rue"  "true"  r
    'f' : r -> literal "alse" "false" r
    'n' : r -> literal "ull"  "null"  r
    c : _
      | c == '-' || isDigit c ->
          case span is_number_char s of
            ([], _)         -> Left "a json number with no characters in it"
            (token, rest)   -> Right (JNumber token, rest)
      | otherwise -> Left ("a json value cannot begin with " ++ show c)

is_number_char :: Char -> Bool
is_number_char c = isDigit c || c `elem` ("-+.eE" :: String)

literal :: String -> String -> String -> Either String (Json, String)
literal wanted whole r =
  case splitAt (length wanted) r of
    (got, rest) | got == wanted -> Right (JLiteral whole, rest)
    _                           -> Left ("expected the literal " ++ whole)

json_object :: String -> Either String (Json, String)
json_object ('}' : r) = Right (JObject [], r)
json_object s0        = go s0 []
  where
    go t acc = do
      (name, after_name) <-
        case skip_ws t of
          '"' : r -> json_string r
          _       -> Left "an object member name must be a string in double quotes"
      case skip_ws after_name of
        ':' : r -> do
          (value, after_value) <- json_value (skip_ws r)
          case skip_ws after_value of
            ',' : r2 -> go (skip_ws r2) (acc ++ [(name, value)])
            '}' : r2 -> Right (JObject (acc ++ [(name, value)]), r2)
            _        -> Left "expected a comma or a closing brace after an object member"
        _ -> Left "expected a colon after an object member name"

json_array :: String -> Either String (Json, String)
json_array (']' : r) = Right (JArray [], r)
json_array s0        = go s0 []
  where
    go t acc = do
      (value, after_value) <- json_value (skip_ws t)
      case skip_ws after_value of
        ',' : r -> go (skip_ws r) (acc ++ [value])
        ']' : r -> Right (JArray (acc ++ [value]), r)
        _       -> Left "expected a comma or a closing bracket after an array element"

-- | Called with the text AFTER the opening quote; returns the contents and the rest.
json_string :: String -> Either String (String, String)
json_string = go []
  where
    go acc s =
      case s of
        []           -> Left "the input ended inside a string"
        '"'  : r     -> Right (reverse acc, r)
        '\\' : rest  ->
          case rest of
            []      -> Left "the input ended inside a string escape"
            'u' : r ->
              case splitAt 4 r of
                (h, r2) | length h == 4 && all isHexDigit h ->
                            go (chr (foldl' (\a c -> a * 16 + digitToInt c) 0 h) : acc) r2
                _ -> Left "a \\u escape must be followed by exactly four hexadecimal digits"
            c : r   ->
              case unescape c of
                []      -> Left ("a backslash may not be followed by " ++ show c)
                (u : _) -> go (u : acc) r
        c : r        -> go (c : acc) r

    unescape c =
      case c of
        '"'  -> "\""
        '\\' -> "\\"
        '/'  -> "/"
        'b'  -> "\b"
        'f'  -> "\f"
        'n'  -> "\n"
        'r'  -> "\r"
        't'  -> "\t"
        _    -> ""
