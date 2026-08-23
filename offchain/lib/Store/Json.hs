-- |
-- A TOTAL, PURE RECOGNISER for the question @model_run.doc@'s column type asks of every artifact
-- that travels the keyed path: /is this a JSON value?/
--
-- == WHY THIS MODULE EXISTS
--
-- @model_run.doc@ is @not null jsonb@, derived by the server from the SAME parameter as @raw@ in
-- one statement, so an artifact that is not a JSON value cannot be written through the keyed path
-- at all -- the row is computed before the conflict clause is resolved, so not even
-- @on conflict do nothing@ saves it. That is a SCHEMA decision, ruled at 23-04 and recorded in
-- 23-03's summary: the only tenant of the keyed path is @volume_path.json@, which is always JSON,
-- and BYTE-01's arbitrary-bytes requirement is served by @byte_corpus@, a table that deliberately
-- has no @jsonb@ column.
--
-- The consequence is what this module is for. @Store.Memory@ is the SERVER-FREE tier and the laws
-- run against it inside @cabal test@; if it accepted an artifact the server would refuse, the law
-- suite would pass in tier B and fail in tier C, which defeats the whole three-tier design --
-- tier B exists to PREDICT tier C. So @Store.Memory@ needs the predicate, with no server and no
-- socket, and this is it.
--
-- == WHY IT IS HAND-WRITTEN AND NOT A JSON LIBRARY CALL
--
-- BYTE-03's source scan asserts that no JSON library is on the storage path -- every module under
-- @offchain\/lib\/Store\/@, this one included, is named in that scan's list. A recogniser is also
-- not a decoder: nothing here builds a value, so nothing here can re-render a number or reorder a
-- key, which is the entire failure mode BYTE-02 and BYTE-03 exist to prevent. It answers 'Bool'-
-- shaped questions with a reason attached and nothing else.
--
-- == THE AGREEMENT WITH @jsonb@ IS MEASURED, NOT CLAIMED
--
-- This is RFC 8259 with a UTF-8 gate in front of it, matching what the server actually does:
-- @convert_from(?, 'UTF8')@ rejects invalid UTF-8 before @jsonb@ ever sees the text. It is NOT
-- claimed to be extensionally equal to @jsonb@'s input grammar, because that claim would be
-- unfalsifiable prose. It is MEASURED instead: the capture drives an agreement probe set through
-- BOTH tiers and records, per input, what each one answered -- so a divergence is a recorded
-- value in a committed artifact rather than a surprise months later.
--
-- ONE divergence is MEASURED, at PG 18.4, in the direction of this recogniser being the more
-- permissive: a @\\u0000@ escape inside a string is well-formed RFC 8259 and is accepted here,
-- while @jsonb@ refuses it because Postgres text cannot carry a NUL. It is not reachable from any
-- fixture this repository writes, and it is recorded rather than worked around -- a recogniser
-- that quietly special-cased it would be asserting agreement instead of measuring it.
--
-- A SECOND divergence was predicted at 23-04 and REFUTED by the same measurement. The prediction
-- was that an exponent large enough to overflow @numeric@ would be accepted here and refused by
-- @jsonb@. Driven at two magnitudes, @1e1000@ and @1e100000@, the server accepted BOTH. The probes
-- are kept in the agreement block under their own names precisely because they came out the other
-- way: a prediction that was wrong is worth more on disk than off it, and a probe deleted for
-- agreeing is a probe that can never disagree later.
module Store.Json
  ( recognise_json_value
  , is_json_value
  ) where

import Data.Char (isDigit, isHexDigit)
import qualified Data.ByteString as BS
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

-- | 'Right' when the bytes are a JSON value; 'Left' with the reason otherwise.
--
-- The reason is not decoration: it is what an operator reads out of a law's failure message, and
-- \"the store refused it\" without a cause is the same unhelpful shape as \"an exception was
-- thrown\".
--
-- Total. It never throws, never diverges, and consumes the whole input -- trailing content after
-- the top-level value is a rejection, matching the server, which does not accept @{} {}@ either.
recognise_json_value :: BS.ByteString -> Either String ()
recognise_json_value bs =
  case TE.decodeUtf8' bs of
    Left err ->
      Left ("the bytes are not valid UTF-8, so the server's conversion step rejects them before "
             ++ "the json parser is reached: " ++ show err)
    Right t ->
      case json_value (skip_ws (T.unpack t)) of
        Left why -> Left why
        Right rest ->
          case skip_ws rest of
            []    -> Right ()
            extra -> Left ("a complete JSON value was parsed and " ++ show (length extra)
                            ++ " characters follow it, beginning " ++ show (take 16 extra)
                            ++ ". A json value is the WHOLE input, never a prefix of it.")

-- | The predicate form, for call sites that only branch on it.
is_json_value :: BS.ByteString -> Bool
is_json_value = either (const False) (const True) . recognise_json_value

-- ---------------------------------------------------------------------------------------------
-- The grammar. Every production consumes a prefix and returns the rest.
-- ---------------------------------------------------------------------------------------------

-- | RFC 8259 whitespace, which is exactly four characters and NOT 'Data.Char.isSpace'. A vertical
-- tab or a form feed is not JSON whitespace, and accepting one here would make this recogniser
-- more permissive than the thing it is predicting.
skip_ws :: String -> String
skip_ws = dropWhile (\c -> c == ' ' || c == '\t' || c == '\n' || c == '\r')

json_value :: String -> Either String String
json_value s =
  case s of
    []      -> Left "the input ended where a json value was expected"
    '{' : r -> json_object (skip_ws r)
    '[' : r -> json_array (skip_ws r)
    '"' : r -> json_string r
    't' : r -> keyword "rue"  "true"  r
    'f' : r -> keyword "alse" "false" r
    'n' : r -> keyword "ull"  "null"  r
    c   : _
      | c == '-' || isDigit c -> json_number s
      | otherwise             -> Left ("a json value cannot begin with " ++ show c)

keyword :: String -> String -> String -> Either String String
keyword tail_wanted whole r =
  case splitAt (length tail_wanted) r of
    (got, rest) | got == tail_wanted -> Right rest
    _                                -> Left ("expected the literal " ++ whole)

-- | Called with the text AFTER the opening brace and after whitespace.
json_object :: String -> Either String String
json_object ('}' : r) = Right r
json_object s0        = member s0
  where
    member t = do
      after_name <-
        case skip_ws t of
          '"' : r -> json_string r
          _       -> Left "an object member name must be a string in double quotes"
      case skip_ws after_name of
        ':' : r -> do
          after_val <- json_value (skip_ws r)
          case skip_ws after_val of
            ',' : r2 -> member (skip_ws r2)
            '}' : r2 -> Right r2
            _        -> Left "expected a comma or a closing brace after an object member"
        _ -> Left "expected a colon after an object member name"

-- | Called with the text AFTER the opening bracket and after whitespace.
json_array :: String -> Either String String
json_array (']' : r) = Right r
json_array s0        = element s0
  where
    element t = do
      after_val <- json_value (skip_ws t)
      case skip_ws after_val of
        ',' : r -> element (skip_ws r)
        ']' : r -> Right r
        _       -> Left "expected a comma or a closing bracket after an array element"

-- | Called with the text AFTER the opening quote.
json_string :: String -> Either String String
json_string []            = Left "the input ended inside a string"
json_string ('"'  : r)    = Right r
json_string ('\\' : rest) =
  case rest of
    []      -> Left "the input ended inside a string escape"
    'u' : r ->
      case splitAt 4 r of
        (h, r2) | length h == 4 && all isHexDigit h -> json_string r2
        _ -> Left "a \\u escape must be followed by exactly four hexadecimal digits"
    c : r
      | c `elem` ("\"\\/bfnrt" :: String) -> json_string r
      | otherwise -> Left ("a backslash in a string may only be followed by one of \\\"\\\\/bfnrt "
                            ++ "or u, and it was followed by " ++ show c)
json_string (c : r)
  | c < '\x20' = Left ("a raw control character " ++ show c ++ " appears inside a string; it must "
                        ++ "be escaped")
  | otherwise  = json_string r

json_number :: String -> Either String String
json_number s0 =
  let after_sign = case s0 of
                     '-' : r -> r
                     _       -> s0
  in integer_part after_sign >>= fraction_part >>= exponent_part

-- | A leading zero admits NO further digits, which is what stops @0123@ from being read as a
-- number followed by silence. The rejection surfaces at the caller -- inside an array @[0123]@
-- fails on the missing comma -- which is the same place the server reports it.
integer_part :: String -> Either String String
integer_part ('0' : r) = Right r
integer_part s@(c : _)
  | isDigit c = Right (dropWhile isDigit s)
integer_part _ = Left "a json number needs at least one digit before any decimal point"

fraction_part :: String -> Either String String
fraction_part ('.' : r) =
  case span isDigit r of
    ([], _)   -> Left "a json number's decimal point must be followed by at least one digit"
    (_, rest) -> Right rest
fraction_part s = Right s

exponent_part :: String -> Either String String
exponent_part (c : r)
  | c == 'e' || c == 'E' =
      let digits = case r of
                     sign : rr | sign == '+' || sign == '-' -> rr
                     _                                      -> r
      in case span isDigit digits of
           ([], _)   -> Left "a json number's exponent must have at least one digit"
           (_, rest) -> Right rest
exponent_part s = Right s
