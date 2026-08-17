-- |
-- The content key's pure core: a netstring framer, a TAGGED preimage over eight named components,
-- and an identity that cannot be built from a machine-specific path or from an absent solver
-- version.
--
-- WHY A FRAMER AND NOT A CONCATENATION
-- ------------------------------------
-- MEASURED (25-RESEARCH M1): 343 shock tuples rendered as bare decimals and concatenated produced
-- __30 collisions__ -- @(1, 1, 23, ...)@ and @(1, 12, 3, ...)@ both render
-- @1123500600028000000000000000008@, and both are ADMITTED by every one of 'render_argv'\'s eight
-- refusals, so the pair is admissible rather than contrived. The same 343 tuples rendered through
-- 'render_argv'\'s token form produced __0 collisions__ -- but that is luck with an argument behind
-- it rather than a framer: every token is @--\<literal name\>=\<digits\>@ and neither @-@ nor @=@ is
-- in the digit alphabet, so the token prefixes ARE a framing, an accidental one. A key that leaned
-- on it would lose its unambiguity the first time a free-form component (a model name, a version
-- string, a source file name) joined the preimage, and three of the eight components below are
-- exactly that.
--
-- So the framing is explicit here, it is netstring (@\<length\> ':' \<bytes\> ','@), and it is
-- unambiguous for ANY payload byte -- including a payload that contains a colon or a comma, which
-- is why the length rather than a separator is what delimits.
--
-- WHY EVERY COMPONENT CARRIES A TAG
-- ---------------------------------
-- Framing alone makes two DIFFERENT tuples different. It does not make a DROPPED component
-- visible: with framing alone, deleting the solver-version component yields a preimage that is a
-- perfectly valid preimage of a shorter tuple. With a tag in front of every value, it is not, and
-- 'preimage_tags' can read the tag sequence back out of the bytes and be compared against
-- 'key_component_tags' as a SET IN BOTH DIRECTIONS. A component added to the preimage and not
-- named in that list is then a failure rather than a silent widening.
--
-- WHAT IS DELIBERATELY NOT REACHABLE FROM THESE SIGNATURES
-- -------------------------------------------------------
-- MEASURED (25-RESEARCH M3): @Gams.Run@ builds its wrapper argument vector with the timeout
-- wrapper, its kill delay, its budget, the absolute solver binary and an option naming the
-- __exclusive per-run temporary directory__ the run executes in. That directory is a different
-- path on every invocation, by design -- it is the stale-file defence. Hashing "the argument
-- vector that actually ran" therefore satisfies "reconstruct the argv from the stored preimage"
-- PERFECTLY while giving a cache hit rate of exactly zero, which is the strongest failure mode
-- this module has to be structurally incapable of.
--
-- It is structurally incapable of it: no function here takes a run request, a run directory, a
-- binary path or any file path other than the model-source names, so the per-run option is not
-- reachable from any signature in this module. 'key_argv_tokens' is the one place the two halves
-- meet, and it composes 'render_argv'\'s seven tokens with 'fixed_model_options' -- the two
-- artifact-affecting options, and nothing else from the wrapper.
--
-- 'render_argv' and 'render_decimal' are the ONLY renderers on this path, and that is load-bearing
-- rather than tidy: @Gams.Argv@\'s own haddock records that the token it emits is copied verbatim
-- into the artifact for the two echoed string fields, so a second renderer here would key a
-- rendering the solver never saw.
--
-- THE BINARY DIGEST IS NOT IN THE PREIMAGE -- A DECISION OF RECORD
-- ---------------------------------------------------------------
-- The toolchain identity carries a digest of the solver executable. It is NOT folded in here, and
-- it is not an oversight. The determinism guarantee this store makes is phrased in VERSIONS
-- ("GAMS 54.1, CONOPT 4.39"), and 24-RESEARCH M13 measured that digest to be machine-specific: two
-- boxes with the identical version report different bytes. Folding it in turns every reinstall of
-- an identical version into a whole-store miss, which is a cost with no matching guarantee. It
-- stays in the stored row and in the run log, where evidence belongs, and it is asserted ABSENT
-- from the preimage against its real recorded value rather than assumed absent.
--
-- Reversing that decision is non-destructive because 'Store.Types.KeyScheme' is itself component
-- one: bumping the scheme ORPHANS the rows computed under the old formula instead of silently
-- reinterpreting them.
--
-- A NOTE ON THE PROSE ABOVE
-- ------------------------
-- This file is read by three source scans -- the storage-path scan for a JSON layer, the
-- floating-value scan, and the digest-literal purge -- and from plan 25-02 by a fourth looking for
-- a second renderer. Every token those scans look for is DESCRIBED here and never spelled, because
-- a comment claiming a token is absent is matched by the pattern that looks for it: eighteen
-- recorded instances of that on this branch, one of them substantive.
module Store.Key
  ( -- * Framing
    frame
  , field
  , frames
    -- * The identity a key may be computed from
  , KeyIdentity (..)
  , KeyIdentityError (..)
  , key_identity
    -- * The preimage
  , key_component_tags
  , key_preimage
  , preimage_tags
  , key_argv_tokens
    -- * The key
  , ContentKey (..)
  , content_key
  , content_key_hex
    -- * The constants on the key path
  , pips_denominator
  , fixed_model_options
  ) where

import Data.ByteString.Builder (Builder, byteString, char8, intDec, toLazyByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy as BSL
import Data.Char (digitToInt, intToDigit, isDigit, isHexDigit)
import Data.List (sort)
import Data.Word (Word8)
import System.FilePath (isAbsolute, isPathSeparator, takeFileName)

import Gams.Argv (ArgvError, Shock, render_argv, render_decimal)
import Gams.Run (ToolchainIdentity (..))
import Gams.Version (ConoptVersion, GamsVersion, conopt_version_text, gams_version_text)
import Store.Types (KeyScheme (..), sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- Framing
-- ---------------------------------------------------------------------------------------------

-- | One netstring: the payload's length in decimal, a colon, the payload, a comma.
--
-- > frame (C8.pack "1") <> frame (C8.pack "23")   renders   1:1,2:23,
-- > frame (C8.pack "12") <> frame (C8.pack "3")   renders   2:12,1:3,
--
-- The two differ although @\"1\" <> \"23\"@ and @\"12\" <> \"3\"@ are the same three bytes. That
-- inequality is the whole of KEY-04, and the check that asserts it also asserts that the UNFRAMED
-- renderings are equal -- without that second half a framer that had become the identity function
-- would be green about nothing.
frame :: BS.ByteString -> Builder
frame bs = intDec (BS.length bs) <> char8 ':' <> byteString bs <> char8 ','

-- | A tagged component: the tag framed, then the value framed.
--
-- Two frames rather than one concatenated frame, so that a tag and the head of its value cannot be
-- traded against each other the way the model-source name and its digest could.
field :: BS.ByteString -> BS.ByteString -> Builder
field tag value = frame tag <> frame value

-- | A list rendered as the concatenation of its framed elements.
--
-- This is what makes a LIST-shaped component unambiguous: @[\"a\",\"bcd\"]@ and @[\"ab\",\"cd\"]@
-- are the same six bytes unframed and different bytes here.
frames :: [BS.ByteString] -> BS.ByteString
frames = build . mconcat . map frame

build :: Builder -> BS.ByteString
build = BSL.toStrict . toLazyByteString

c8 :: String -> BS.ByteString
c8 = C8.pack

-- ---------------------------------------------------------------------------------------------
-- The identity a key may be computed from
-- ---------------------------------------------------------------------------------------------

-- | The toolchain identity with the two shapes that poison a key REMOVED.
--
-- The record's constructor and its accessors are exported, because the check that mutates exactly
-- one component at a time needs to build eight neighbours of a baseline. 'key_identity' is
-- nevertheless the ONLY path from a measured @ToolchainIdentity@, and the relativisation of the
-- source paths happens there: @Store.Cache@ and every other consumer calls 'key_identity' and
-- never builds this record directly, or the relativisation stops being a property of the key path
-- and becomes a property of whoever remembered it.
data KeyIdentity = KeyIdentity
  { ki_gams_version   :: GamsVersion
    -- ^ the solver's own version, as a type that cannot be built empty
  , ki_conopt_version :: ConoptVersion
    -- ^ UNWRAPPED. The optional shape is refuted at the edge by 'key_identity', never defaulted
  , ki_model_sources  :: [(FilePath, String)]
    -- ^ (file NAME, digest) pairs, basenamed and sorted -- never a machine-specific path
  , ki_fixed_options  :: [String]
    -- ^ the artifact-affecting model options only
  , ki_pips_denom     :: Integer
    -- ^ KEY-05: the denominator the pip-valued inputs are quoted against
  }

-- | Why an identity could not be turned into a key identity. Every constructor NAMES its subject.
data KeyIdentityError
  = ConoptVersionAbsent
    -- ^ the solver-side version was not detected, and an absent version may not become an empty
    -- one: the rows written under an empty component are indistinguishable from good ones
    -- afterwards, because the only evidence of which toolchain produced them is the component
    -- that was emptied
  | AbsoluteModelSourcePath FilePath
    -- ^ a model source that is still machine-specific after relativisation, naming the path
  | EmptyModelSourceList
    -- ^ no model source at all: a key over an empty source list is a key over an absent subject
  | DuplicateModelSourceName String
    -- ^ two sources sharing a name, naming it -- their digests would be order-dependent
  | EmptyModelSourceDigest String
    -- ^ a source whose digest is the empty string, naming the source
  deriving (Eq, Show)

-- | THE ONLY PATH from a measured toolchain identity to something a key may be computed over.
--
-- Two shapes are refused here rather than tested for later (25-RESEARCH M4):
--
--   * the solver-side version arrives as an OPTIONAL field, and an absent one is a refusal naming
--     the field -- never the empty string, never a placeholder;
--   * the model sources arrive as ABSOLUTE machine paths. Folding one into the preimage makes the
--     key machine-specific, so the same shock solved on two boxes produces two keys and two rows
--     while the store looks healthy. The CONTENT is digested; the path is reduced to its file
--     name, and a name that is somehow still absolute or still carries a separator is a refusal
--     naming the original path rather than a silently truncated component.
--
-- The list shape is kept rather than collapsed to one digest: the model has no include directives
-- today, and a future one is then covered without a change here.
key_identity :: ToolchainIdentity -> Either KeyIdentityError KeyIdentity
key_identity identity = do
  conopt <- case ti_conopt_version identity of
              Nothing -> Left ConoptVersionAbsent
              Just v  -> Right v
  let sources = ti_model_sources identity
  _ <- if null sources then Left EmptyModelSourceList else Right ()
  named <- mapM relativise sources
  _ <- case [n | (n, _) <- named, occurrences n named > 1] of
         (n : _) -> Left (DuplicateModelSourceName n)
         []      -> Right ()
  _ <- case [n | (n, d) <- named, null d] of
         (n : _) -> Left (EmptyModelSourceDigest n)
         []      -> Right ()
  Right KeyIdentity
    { ki_gams_version   = ti_gams_version identity
    , ki_conopt_version = conopt
    , ki_model_sources  = sort named
    , ki_fixed_options  = fixed_model_options
    , ki_pips_denom     = pips_denominator
    }
  where
    occurrences n xs = length [() | (m, _) <- xs, m == n]

relativise :: (FilePath, String) -> Either KeyIdentityError (FilePath, String)
relativise (path, digest)
  | null name || isAbsolute name || any isPathSeparator name =
      Left (AbsoluteModelSourcePath path)
  | otherwise = Right (name, digest)
  where
    name = takeFileName path

-- ---------------------------------------------------------------------------------------------
-- The constants on the key path
-- ---------------------------------------------------------------------------------------------

-- | The denominator the pip-valued inputs are quoted against -- KEY-05, and it is IN the preimage.
--
-- Issue #28 pins the protocol's fee denominator at one million pips, the Algebra convention. It is
-- a component rather than a compile-time convention because a change to it must MOVE every key: a
-- shock whose fee fields meant hundredths of a basis point and a shock whose fee fields mean
-- something else are different shocks, and reinterpreting the stored rows in place is exactly the
-- silent corruption 'Store.Types.KeyScheme' exists to prevent.
--
-- Stated ONCE, here. The check that scans the key path for a second occurrence of this literal is
-- what keeps that true, and its scanned scope is pinned data rather than "whatever happens to
-- exist".
pips_denominator :: Integer
pips_denominator = 1000000

-- | The artifact-affecting model options, and NOTHING else from the wrapper vector.
--
-- @action=ce@ selects compile-and-execute and @lo=2@ sends the log to a file; both change what the
-- run produces or where it lands. The wrapper's remaining entries -- the timeout wrapper, its kill
-- delay, its budget, the absolute binary and the per-run temporary directory -- are ambient
-- properties of THIS invocation rather than of the request, and every one of them would make the
-- key unstable across runs. See this module's header for the measurement.
fixed_model_options :: [String]
fixed_model_options = ["action=ce", "lo=2"]

-- ---------------------------------------------------------------------------------------------
-- The preimage
-- ---------------------------------------------------------------------------------------------

-- | The eight component tags, in preimage order.
--
-- This list is the NAMED SET the tag sequence read back out of a real preimage is compared
-- against, in both directions. It is deliberately NOT the source of the tags 'key_preimage'
-- writes: a list read off the thing it is compared to agrees with it by construction, and the
-- comparison would then be an assertion about nothing.
key_component_tags :: [BS.ByteString]
key_component_tags =
  map c8 ["scheme", "model", "shock", "opts", "pipsdenom", "gams", "conopt", "modelsrc"]

-- | The seven rendered shock tokens followed by the fixed model options.
--
-- The ONE place KEY-02's two halves meet: what the preimage records and what the invocation passes
-- are the same list, so the argument vector can be reconstructed from the stored preimage -- and
-- the reconstruction is of the request, not of the run.
key_argv_tokens :: Shock -> KeyIdentity -> Either ArgvError [String]
key_argv_tokens shock ident = (++ ki_fixed_options ident) <$> render_argv shock

-- | The tagged, framed preimage.
--
-- It REFUSES BEFORE HASHING whenever 'render_argv' refuses -- the eight range and model refusals
-- of @Gams.Argv@ are inherited here rather than restated, so a shock that cannot be run cannot be
-- keyed either. That is KEY-06's range half: an out-of-range or absent input is an error at
-- construction time and never a default that hashes into a plausible-looking row.
key_preimage :: KeyScheme -> String -> Shock -> KeyIdentity -> Either ArgvError BS.ByteString
key_preimage scheme model shock ident = do
  tokens <- render_argv shock
  Right . build $ mconcat
    [ field (c8 "scheme")    (c8 (show_scheme scheme))
    , field (c8 "model")     (c8 model)
    , field (c8 "shock")     (frames (map c8 tokens))
    , field (c8 "opts")      (frames (map c8 (ki_fixed_options ident)))
    , field (c8 "pipsdenom") (c8 (render_decimal (ki_pips_denom ident)))
    , field (c8 "gams")      (c8 (gams_version_text (ki_gams_version ident)))
    , field (c8 "conopt")    (c8 (conopt_version_text (ki_conopt_version ident)))
    , field (c8 "modelsrc")  (frames (concatMap source_frames (sort (ki_model_sources ident))))
    ]

-- | A model source contributes TWO frames, not one.
--
-- DEVIATION OF RECORD, and it is a correction rather than a preference. 25-RESEARCH's sketch
-- rendered each source as one frame over the name concatenated with its digest. Under that shape
-- @[(\"a\",\"bcd\"), (\"e\",\"f\")]@ and @[(\"ab\",\"cd\"), (\"e\",\"f\")]@ produce the SAME frame
-- list -- the conflation the framer exists to prevent, reintroduced one level down, inside the
-- component where the free-form collision actually lives. Framing the name and the digest
-- separately makes the pair recoverable from the bytes and the two source lists distinguishable.
source_frames :: (FilePath, String) -> [BS.ByteString]
source_frames (name, digest) = [c8 name, c8 digest]

show_scheme :: KeyScheme -> String
show_scheme (KeyScheme n) = render_decimal (toInteger n)

-- | Read the tag sequence back OUT of a preimage's bytes.
--
-- A real reader, walking the netstrings, so the check that compares the tags reads the BYTES and
-- not the constant they were built from. The tags are the first frame of each pair; an odd frame
-- count means the preimage is not a sequence of tagged components at all and is reported as such
-- rather than silently rounded down.
preimage_tags :: BS.ByteString -> Either String [BS.ByteString]
preimage_tags bytes = parse_frames bytes >>= tags_of
  where
    tags_of (tag : _ : rest) = (tag :) <$> tags_of rest
    tags_of []               = Right []
    tags_of [orphan]         =
      Left ("the preimage ends with an unpaired frame " ++ show orphan
             ++ ": every component is a tag frame followed by a value frame, so an odd frame count"
             ++ " means this is not a tagged preimage.")

-- | Every netstring in order, or the reason the bytes are not a netstring sequence.
parse_frames :: BS.ByteString -> Either String [BS.ByteString]
parse_frames bytes
  | BS.null bytes = Right []
  | otherwise =
      case C8.elemIndex ':' bytes of
        Nothing -> Left ("no length separator in the remaining " ++ show (BS.length bytes)
                          ++ " bytes: a netstring is a decimal length, a colon, the payload and a"
                          ++ " comma.")
        Just at -> do
          let (digits, after_digits) = BS.splitAt at bytes
              body                   = BS.drop 1 after_digits
          size <- read_length digits
          if BS.length body < size + 1
            then Left ("a frame claims " ++ show size ++ " bytes but only "
                        ++ show (BS.length body) ++ " remain after its separator.")
            else do
              let (payload, after_payload) = BS.splitAt size body
              if C8.take 1 after_payload /= c8 ","
                then Left ("a frame of " ++ show size
                            ++ " bytes is not terminated by the frame terminator.")
                else (payload :) <$> parse_frames (BS.drop 1 after_payload)

read_length :: BS.ByteString -> Either String Int
read_length digits
  | BS.null digits = Left "a frame carries an empty length."
  | not (C8.all isDigit digits) =
      Left ("a frame's length " ++ show digits ++ " is not a run of decimal digits.")
  | otherwise = Right (C8.foldl' step 0 digits)
  where
    step acc ch = acc * 10 + digitToInt ch

-- ---------------------------------------------------------------------------------------------
-- The key
-- ---------------------------------------------------------------------------------------------

-- | The content key: the raw 32-byte digest of the preimage.
--
-- Raw bytes rather than text, because the column it lands in is @bytea@ and a key that were
-- carried as hex would be stored at twice its size and compared as a rendering.
newtype ContentKey = ContentKey BS.ByteString
  deriving (Eq, Ord, Show)

-- | The key, refusing for exactly the reasons 'key_preimage' refuses.
content_key :: KeyScheme -> String -> Shock -> KeyIdentity -> Either ArgvError ContentKey
content_key scheme model shock ident =
  ContentKey . digest_bytes . sha256_hex <$> key_preimage scheme model shock ident

-- | 64 BARE lowercase hex characters. No prefix, ever -- the digest-literal purge greps for the
-- prefixed form under this whole subtree and a prefixed rendering here would redden it on sight.
content_key_hex :: ContentKey -> String
content_key_hex (ContentKey raw) = concatMap hex_byte (BS.unpack raw)

hex_byte :: Word8 -> String
hex_byte w = [ intToDigit (fromIntegral (w `div` 16)), intToDigit (fromIntegral (w `mod` 16)) ]

-- | The 32 raw bytes behind 'Store.Types.sha256_hex'\'s 64-character rendering.
--
-- Its input is always that function's output, whose alphabet is exactly the lowercase hex digits.
-- A character outside that alphabet is therefore unreachable -- and if one ever did arrive, the
-- byte is DROPPED rather than replaced by a zero, so the key comes out SHORT and the 32-byte
-- assertion in the suite reddens. A substituted zero byte would instead be a plausible-looking key
-- computed from an absent digest, which is this repository's defect number one.
digest_bytes :: String -> BS.ByteString
digest_bytes = BS.pack . go
  where
    go (hi : lo : rest)
      | isHexDigit hi && isHexDigit lo =
          fromIntegral (digitToInt hi * 16 + digitToInt lo) : go rest
      | otherwise = go rest
    go _ = []
