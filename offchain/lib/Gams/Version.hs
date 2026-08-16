-- |
-- Toolchain identity as a type: a GAMS version that cannot be built empty, and a CONOPT version
-- that cannot be built from either decoy.
--
-- WHY THE JOB NAME IS THE DISCRIMINATOR
-- -------------------------------------
-- MEASURED against the real binary (GAMS 54.1.0, build 37378ce0) on 2026-08-16, and every one of
-- these is why a looser rule would pass:
--
--   * @gams --version@ IS NOT A COMMAND. The flag is parsed as an input filename; the process
--     exits 6, prints 275 bytes on STDOUT, and its first line is a perfectly well-formed banner
--     carrying the real version number.
--   * @gams@ WITH NO ARGUMENTS EXITS 0. It prints 1239 bytes over 27 lines, containing the version
--     string THREE times, and runs no model at all. Exit 0, non-empty, correctly shaped, wrong
--     subject -- the strongest member of the garbage battery, and it is captured output rather
--     than an invented string.
--   * STDERR IS EXACTLY 0 BYTES IN BOTH MODES, and in a normal solve as well. A detector that
--     reads stderr therefore compares the empty string against the empty string and reports
--     success -- this repository's defect number one, handed to it by the tool itself.
--   * @gams audit@ reports GAMSX, a COMPONENT that happens to carry the same number today. A
--     different subject, not a different rendering.
--
-- The three banners differ in exactly one field:
--
-- >  --- Job volume_path.gms Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
-- >  --- Job ? Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
-- >  --- Job --version Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux
--
-- So the rule is: the job name must EQUAL the basename of the @.gms@ that was actually invoked.
-- That single equality rejects both wrong-subject banners without a denylist, and it keeps
-- rejecting the ones nobody has met yet.
--
-- WHY THE CONOPT RULE IS THE SPACED-LETTER FORM
-- ---------------------------------------------
-- Three plausible strings exist side by side, all three MEASURED present in the same run:
--
-- >      C O N O P T   version 4.39.0                                          TRUE
-- >  CONOPT 4         54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux  DECOY, the
-- >                                                                             GAMS-side LINK
-- >  libconopt464.so                                                            DECOY, the object
--
-- Both decoys carry the token CONOPT; only the true line carries the spaced-letter form. And the
-- true line's POSITION MOVES: buffer line index 38 in the hermetic probe, 47 in the production
-- run. Any positional rule is wrong by construction, so this module matches on content and never
-- on a line number.
--
-- WHAT IS DELIBERATELY ABSENT
-- ---------------------------
-- Neither newtype exports its constructor, so no value of either type can be built outside this
-- module, and there is no expression here that produces one from nothing. Every failure is a
-- 'Left' carrying the reason it failed -- there is no default, no alternative, no fallback string
-- and no exception handler anywhere on this path. A version that reports a plausible value when
-- its subject was absent is worse than one that reports nothing, because Phase 25 folds both
-- strings into the content key: the rows written under an empty component are indistinguishable
-- from good ones afterwards, since the only evidence of which toolchain produced them is the
-- component that was emptied.
module Gams.Version
  ( -- * The GAMS version
    GamsVersion            -- ABSTRACT ON PURPOSE. Exporting the constructor re-opens GAMS-03.
  , gams_version_text
  , gams_build_text
  , parse_gams_version
    -- * The CONOPT version
  , ConoptVersion          -- ABSTRACT ON PURPOSE, for the same reason.
  , conopt_version_text
  , parse_conopt_version
    -- * Why a parse failed
  , VersionError (..)
  ) where

import qualified Data.ByteString as BS
import Data.Char (isDigit, isSpace)
import Data.List (stripPrefix)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

-- ---------------------------------------------------------------------------------------------
-- The types
-- ---------------------------------------------------------------------------------------------

-- | @(version, build)@ -- @(\"54.1.0\", \"37378ce0\")@ for the measured toolchain.
--
-- The constructor is NOT exported. 'Store.Types.DerivedDoc' is the precedent, and 23-01 OBSERVED
-- the compile error that idiom produces rather than assuming it.
newtype GamsVersion = GamsVersion (String, String)
  deriving (Eq, Show)

gams_version_text :: GamsVersion -> String
gams_version_text (GamsVersion (v, _)) = v

gams_build_text :: GamsVersion -> String
gams_build_text (GamsVersion (_, b)) = b

-- | CONOPT's own version, @\"4.39.0\"@ on the measured toolchain -- never the GAMS-side link
-- version and never the shared object's soname.
newtype ConoptVersion = ConoptVersion String
  deriving (Eq, Show)

conopt_version_text :: ConoptVersion -> String
conopt_version_text (ConoptVersion v) = v

-- | Why a parse failed, in the terms of the thing that was actually read.
--
-- 'WrongJob' carries the job name it found, so the failure message can name the subject that was
-- reported instead of the one that was asked for -- @?@ for the no-argument banner, @--version@
-- for the flag.
data VersionError
  = EmptyInput
  | NoJobBanner
  | WrongJob String
  | MissingVersionField
  | MalformedVersion String
  | NoConoptBanner
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The GAMS version
-- ---------------------------------------------------------------------------------------------

-- | The prefix every GAMS job banner opens with, in the log and on stdout alike.
job_banner_prefix :: String
job_banner_prefix = "--- Job "

-- | The keyword that separates the job name from the timestamp-and-version tail. The log's LAST
-- line is a @--- Job \<name\> Stop \<elapsed\>@ banner with no version on it at all, so the
-- version field is anchored on this word rather than on \"the banner\".
job_start_keyword :: String
job_start_keyword = "Start"

-- | @parse_gams_version model_basename bytes@ -- the version of the GAMS that ran THIS model.
--
-- The first argument is the basename of the @.gms@ that was invoked; the banner's job name must
-- equal it. Bytes rather than 'String' because the caller reads them with
-- @Data.ByteString.readFile@ out of the run directory's log: no locale decoder touches a banner,
-- and a byte sequence that is not valid UTF-8 fails the parse instead of throwing from inside a
-- lazy read.
parse_gams_version :: String -> BS.ByteString -> Either VersionError GamsVersion
parse_gams_version model_basename raw =
  case TE.decodeUtf8' raw of
    Left _ -> Left NoJobBanner
    Right text
      | T.all isSpace text -> Left EmptyInput
      | otherwise ->
          case banner_field_lists text of
            []             -> Left NoJobBanner
            (fields : _)   -> banner_version model_basename fields

-- | The whitespace-delimited tail of every line opening with the job-banner prefix, in order.
banner_field_lists :: T.Text -> [[String]]
banner_field_lists text =
  [ words tail_of_line
  | line <- map T.unpack (T.lines text)
  , Just tail_of_line <- [stripPrefix job_banner_prefix line]
  ]

-- | The banner's fields, decided in one order: subject first, then presence, then shape.
--
-- Subject FIRST is the whole design. A banner from the wrong invocation carries a perfectly
-- well-shaped version, so a rule that validated the shape before the subject would accept it.
banner_version :: String -> [String] -> Either VersionError GamsVersion
banner_version model_basename fields =
  case fields of
    [] -> Left NoJobBanner
    (job : rest)
      | job /= model_basename -> Left (WrongJob job)
      | otherwise ->
          case rest of
            (keyword : _date : _time : version : build : _)
              | keyword == job_start_keyword ->
                  if not (is_dotted_triple version)
                    then Left (MalformedVersion version)
                    else if not (is_build_id build)
                      then Left (MalformedVersion build)
                      else Right (GamsVersion (version, build))
            _ -> Left MissingVersionField

-- ---------------------------------------------------------------------------------------------
-- The CONOPT version
-- ---------------------------------------------------------------------------------------------

-- | The spaced-letter form. This is the ONE token that separates the true banner from both
-- decoys, which is why it is written down once, here.
conopt_spaced_marker :: String
conopt_spaced_marker = "C O N O P T"

conopt_version_keyword :: String
conopt_version_keyword = "version"

-- | The FIRST line carrying the spaced-letter marker followed by the version keyword and a dotted
-- triple wins. Scanning every line, in order, is what makes the answer independent of where the
-- line sits: MEASURED at buffer index 38 in the probe and 47 in the production run.
parse_conopt_version :: BS.ByteString -> Either VersionError ConoptVersion
parse_conopt_version raw =
  case TE.decodeUtf8' raw of
    Left _ -> Left NoConoptBanner
    Right text
      | T.all isSpace text -> Left EmptyInput
      | otherwise ->
          case [ v | line <- map T.unpack (T.lines text), Just v <- [conopt_line_version line] ] of
            (v : _) -> Right (ConoptVersion v)
            []      -> Left NoConoptBanner

-- | The dotted triple on one line, if that line is the true banner.
conopt_line_version :: String -> Maybe String
conopt_line_version line =
  case after_infix conopt_spaced_marker line of
    Nothing   -> Nothing
    Just rest -> version_after_keyword (words rest)

-- | The token following the version keyword, if it is a dotted triple.
version_after_keyword :: [String] -> Maybe String
version_after_keyword fields =
  case fields of
    (keyword : token : more)
      | keyword == conopt_version_keyword && is_dotted_triple token -> Just token
      | otherwise -> version_after_keyword (token : more)
    _ -> Nothing

-- ---------------------------------------------------------------------------------------------
-- Shape
-- ---------------------------------------------------------------------------------------------

-- | @MAJOR.MINOR.PATCH@, every component non-empty and all digits. @54.1@ and @vNext@ both fail.
is_dotted_triple :: String -> Bool
is_dotted_triple token =
  case split_on '.' token of
    [major, minor, patch] -> all component [major, minor, patch]
    _                     -> False
  where
    component part = not (null part) && all isDigit part

-- | Eight lowercase hex digits, the build id's measured shape.
is_build_id :: String -> Bool
is_build_id token = length token == 8 && all hex_digit token
  where
    hex_digit c = isDigit c || (c >= 'a' && c <= 'f')

split_on :: Char -> String -> [String]
split_on separator s =
  case break (== separator) s of
    (chunk, [])       -> [chunk]
    (chunk, _ : rest) -> chunk : split_on separator rest

-- | The remainder of the second argument after the first occurrence of the first, if any.
after_infix :: String -> String -> Maybe String
after_infix needle hay =
  case stripPrefix needle hay of
    Just rest -> Just rest
    Nothing ->
      case hay of
        []       -> Nothing
        (_ : cs) -> after_infix needle cs
