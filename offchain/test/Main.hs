{-# LANGUAGE OverloadedStrings #-}

-- |
-- SC-3 and SC-4 as a plain @exitcode-stdio-1.0@ runner.
--
-- No test framework: none is in @build-depends@ and none is needed. A check is a named
-- @IO (Either String ())@; every check runs, every failure prints what it expected, and the
-- process exits nonzero if any failed. Stopping at the first failure would hide the rest, and a
-- run that reports one problem when there are four is a worse signal than no run at all.
--
-- WHAT MAKES THIS A CONSUMPTION CHECK RATHER THAN A TRANSCRIPTION
-- ---------------------------------------------------------------
-- Every per-pin check opens the @.plk@ file named in that pin's own @source@ field, PARSES the
-- signature string out of it, and recomputes the value. The test does not carry its own copy of
-- any signature: a test that did would prove only that the test agrees with itself, which is the
-- exact failure this milestone exists to kill, moved one layer up.
--
-- The signature parser here is a SECOND, INDEPENDENT implementation of the two normalisation
-- rules that @offchain\/rig\/generate-pins.sh@ implements in awk. That is deliberate. The rules
-- are (a) balanced-paren accumulation across continuation @\/\/@ lines, and (b) strip @indexed@,
-- strip trailing parameter identifiers, strip whitespace -- idempotently.
module Main (main) where

import Control.Exception (IOException, try)
import Crypto.Ethereum.Utils (keccak256)
import Data.Aeson (Value (..), eitherDecodeFileStrict, encodeFile)
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import Data.Bits (shiftL, shiftR, (.&.), (.|.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Char (digitToInt, intToDigit, isAlpha, isAlphaNum, isHexDigit, isSpace, toLower)
import Data.List (intercalate, isInfixOf, isPrefixOf, nub, sort)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, isJust, isNothing)
import Data.Solidity.Prim.Address (Address, fromHexString)
import qualified Data.Text as T
import System.Directory (doesFileExist, getTemporaryDirectory, removeFile)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

import Rig.Manifest
  ( PinEntry (..)
  , Rig (..)
  , RigAddresses (..)
  , RigPins (..)
  , load_rig_from
  )
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Network.Ethereum.Api.Types (Change (..))

import VolOrder.Decode
  ( OrderCreatedEvent (..)
  , be_integer
  , decode_order_created
  , unpack_vol_order_storage
  )
import VolOrder.Encoding (encode_create_order, pack_vol_order_input)
import VolOrder.Types (VolOrder (..))

-- ---------------------------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------------------------

pins_file :: FilePath
pins_file = "offchain/rig/rig-pins.json"

manifest_file :: FilePath
manifest_file = "offchain/rig/rig-manifest.json"

deploy_command :: String
deploy_command = "bash offchain/rig/deploy-rig.sh"

-- ---------------------------------------------------------------------------------------------
-- Hashing
--
-- The web3-crypto wrapper is used, never a hand-rolled hash. Keccak-256 is NOT SHA3-256 -- they
-- differ in padding -- and a hand-rolled version that gets that wrong produces 32 bytes that look
-- exactly like a hash and never match anything.
-- ---------------------------------------------------------------------------------------------

selector_of :: String -> BS.ByteString
selector_of = BS.take 4 . keccak256 . C8.pack

topic0_of :: String -> BS.ByteString
topic0_of = keccak256 . C8.pack

to_hex :: BS.ByteString -> String
to_hex = concatMap byte . BS.unpack
  where
    byte b = [digit (b `shiftR` 4), digit (b .&. 0x0f)]
    digit n = intToDigit (fromIntegral n)

-- ---------------------------------------------------------------------------------------------
-- The signature parser -- rules (a) and (b), independently implemented
-- ---------------------------------------------------------------------------------------------

is_space_char :: Char -> Bool
is_space_char c = c == ' ' || c == '\t' || c == '\r'

trim :: String -> String
trim = dropWhile is_space_char . reverse . dropWhile is_space_char . reverse

-- | Strip ALL surrounding whitespace, newlines included. Subprocess output ends in one, and a
-- trailing newline is exactly the kind of difference that makes two identical-LOOKING hex strings
-- compare unequal.
strip_ws :: String -> String
strip_ws = dropWhile isSpace . reverse . dropWhile isSpace . reverse

-- | The text of a @\/\/@ comment line, or 'Nothing' if the line is not a comment.
comment_body :: String -> Maybe String
comment_body raw =
  case dropWhile is_space_char raw of
    '/' : '/' : rest -> Just (dropWhile is_space_char rest)
    _                -> Nothing

-- | Drop a @signature::@ / @event::@ marker. Files that use no marker at all (the bare
-- @\/\/ name(args)@ shape) fall through unchanged.
strip_marker :: String -> String
strip_marker s
  | "signature::" `isPrefixOf` s = dropWhile is_space_char (drop 11 s)
  | "event::"     `isPrefixOf` s = dropWhile is_space_char (drop 7 s)
  | otherwise                    = s

-- | An identifier immediately followed by an open paren -- the only shape that starts a
-- signature. Prose beginning with a word and then anything else is not a candidate.
signature_head :: String -> Maybe String
signature_head s =
  case span (\c -> isAlphaNum c || c == '_') s of
    (name@(c : _), rest)
      | isAlpha c || c == '_'
      , '(' : _ <- dropWhile is_space_char rest -> Just name
    _ -> Nothing

-- | RULE (a). Accumulate characters until the parenthesis OPENED BY THE SIGNATURE closes, then
-- stop and discard the rest of the line. A single-line regex would truncate a wrapped signature
-- and yield a perfectly valid-looking 32-byte hash that simply never matches anything.
take_signature :: String -> Maybe String
take_signature = go (0 :: Int) False ""
  where
    go _ _ _ [] = Nothing
    go depth opened acc (c : cs)
      | c == '(' = go (depth + 1) True (c : acc) cs
      | c == ')' =
          let depth' = depth - 1
          in if opened && depth' == 0
               then Just (reverse (c : acc))
               else go depth' opened (c : acc) cs
      | otherwise = go depth opened (c : acc) cs

-- | RULE (b), for one argument atom: its TYPE is the first whitespace-separated token that is not
-- @indexed@; everything else is a parameter identifier and is dropped. Idempotent on an
-- already-canonical atom, which is what lets the same parser read both comment shapes.
atom_type :: String -> String
atom_type a =
  case filter (/= "indexed") (words a) of
    (t : _) -> t
    []      -> ""

-- | RULE (b), whole signature. @Name(uint256 indexed id, uint88 x)@ -> @Name(uint256,uint88)@.
-- Nested tuple parens survive because @(@ and @)@ are treated as atom delimiters.
canonicalise :: String -> String
canonicalise sig =
  let (name, rest) = break (== '(') sig
      args         = drop 1 (take (length rest - 1) rest)
  in trim name ++ "(" ++ canon_args "" args ++ ")"
  where
    canon_args atom [] = atom_type atom
    canon_args atom (c : cs)
      | c == ',' || c == '(' || c == ')' = atom_type atom ++ [c] ++ canon_args "" cs
      | otherwise                        = canon_args (atom ++ [c]) cs

-- | Every signature a file's comments declare, as (name, canonical signature).
signatures_in :: [String] -> [(String, String)]
signatures_in ls = catMaybes [at i | i <- [0 .. length ls - 1]]
  where
    bodies = map comment_body ls
    at i = do
      body <- bodies !! i
      let body' = strip_marker body
      name <- signature_head body'
      -- the contiguous comment block from here down; take_signature stops as soon as the
      -- signature's own paren closes, so joining more than needed is harmless
      let block = body' : map (fromMaybe "") (takeWhile isJust (drop (i + 1) bodies))
      raw <- take_signature (intercalate " " block)
      let sig = canonicalise raw
      if any isSpace sig then Nothing else Just (name, sig)

-- | The signature a named pin is declared with, in one file. Two declarations that DISAGREE are
-- a failure, never a silent pick of the first.
signature_for :: String -> [(String, String)] -> Either String String
signature_for name parsed =
  case nub [s | (n, s) <- parsed, n == name] of
    [s] -> Right s
    []  -> Left ("no signature comment for " ++ show name ++ " was parsed out of this file")
    ss  -> Left ("this file declares " ++ show name ++ " with DISAGREEING signatures: " ++ show ss)

-- ---------------------------------------------------------------------------------------------
-- The checker itself
--
-- Factored out so the falsifiability case can drive THIS function -- not a copy of it -- over a
-- doctored pin value and observe it reporting a mismatch.
-- ---------------------------------------------------------------------------------------------

verify_pin
  :: (String -> BS.ByteString)  -- ^ selector_of or topic0_of
  -> String                     -- ^ pin name
  -> String                     -- ^ the PINNED value, @0x@-prefixed
  -> String                     -- ^ contents of the source .plk file
  -> Either String ()
verify_pin hash_of name pinned contents = do
  sig <- signature_for name (signatures_in (lines contents))
  let computed = "0x" ++ to_hex (hash_of sig)
      expected = map toLower pinned
  if computed == expected
    then Right ()
    else
      Left $
        intercalate "\n"
          [ "recomputed value does not match the pin"
          , "      signature parsed from the file : " ++ sig
          , "      recomputed (keccak256)         : " ++ computed
          , "      pinned in " ++ pins_file ++ "   : " ++ expected
          ]

-- ---------------------------------------------------------------------------------------------
-- Ground truth -- the ONLY signature/value literals in this module
--
-- These exist to prove the parser and the encoder are right, and they are NOT read from the pin
-- file, so a corrupted pin file cannot make them agree with it. They are keccak outputs of
-- STRINGS, not addresses or live selectors, and they are written WITHOUT the 0x prefix precisely
-- so the \b-anchored purge patterns in sc3_literal_purge do not match this file.
-- ---------------------------------------------------------------------------------------------

ground_truth :: [(String, String, String)]
ground_truth =
  [ ("selector", "create_order(uint88,uint24,uint16,uint96)", "98d950ec")
  , ("selector", "create_orders(uint256,uint256[])", "81357911")
  , ("selector", "writeTimepoint(uint32,int24)", "b09b2297")
  , ( "topic0"
    , "VolOrderCreated(uint256,uint88,uint24,uint16,uint96)"
    , "18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6"
    )
  , ( "topic0"
    , "TimepointWritten(bytes32,uint32,int24,uint88,int24,int56)"
    , "44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415"
    )
  ]

-- | The ground-truth row for a name, so the dedicated checks below need not repeat a literal.
truth_for :: String -> Either String (String, String)
truth_for name =
  case [(sig, val) | (_, sig, val) <- ground_truth, takeWhile (/= '(') sig == name] of
    (row : _) -> Right row
    []        -> Left ("no ground-truth row for " ++ name)

realized_vol_iface :: FilePath
realized_vol_iface = "src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk"

dynamic_fee_hook_iface :: FilePath
dynamic_fee_hook_iface = "src/interfaces/protocol_integrations/DynamicFeeHookInterface.plk"

-- ---------------------------------------------------------------------------------------------
-- Check plumbing
-- ---------------------------------------------------------------------------------------------

data Check = Check
  { check_name :: String
  , check_run  :: IO (Either String ())
  }

-- | An unexpected IO error inside a check is that check failing, not the suite dying.
guarded :: IO (Either String a) -> IO (Either String a)
guarded action = do
  outcome <- try action
  pure $ case outcome of
    Left err     -> Left ("unexpected IO error: " ++ show (err :: IOException))
    Right result -> result

pure_check :: String -> Either String () -> Check
pure_check name result = Check name (pure result)

expect :: Bool -> String -> Either String ()
expect True _    = Right ()
expect False why = Left why

-- ---------------------------------------------------------------------------------------------
-- SC-4: pin recomputation
-- ---------------------------------------------------------------------------------------------

-- | One check per pin. The signature comes from the FILE the pin names, never from this module.
per_pin_checks :: RigPins -> [Check]
per_pin_checks pins =
  [ pin_check "selector" selector_of name entry
  | (name, entry) <- Map.toList (pin_selectors pins)
  ]
    ++ [ pin_check "topic0" topic0_of name entry
       | (name, entry) <- Map.toList (pin_topics pins)
       ]

pin_check :: String -> (String -> BS.ByteString) -> T.Text -> PinEntry -> Check
pin_check kind hash_of name entry =
  Check ("sc4_pin_" ++ kind ++ "_" ++ T.unpack name) . guarded $ do
    let src = T.unpack (pin_source entry)
    contents <- readFile src
    pure $ case verify_pin hash_of (T.unpack name) (T.unpack (pin_value entry)) contents of
      Right () -> Right ()
      Left why -> Left (why ++ "\n      source file                    : " ++ src)

sc4_ground_truth_encoder :: Check
sc4_ground_truth_encoder = pure_check "sc4_ground_truth_encoder" $
  mapM_ one ground_truth
  where
    one (kind, sig, expected) =
      let computed = to_hex (if kind == "selector" then selector_of sig else topic0_of sig)
      in expect (computed == expected)
           (kind ++ " for " ++ sig ++ ": encoder gave " ++ computed ++ ", expected " ++ expected)

-- | The wrapped signature. Research 7.3: a truncating parser yields a valid 32-byte hash that
-- simply never matches, so this case is the only thing between a broken parser and a green suite.
sc4_multiline_timepoint_written :: Check
sc4_multiline_timepoint_written =
  Check "sc4_multiline_timepoint_written" . guarded $ do
    contents <- readFile realized_vol_iface
    pure $ do
      (expected_sig, expected_topic) <- truth_for "TimepointWritten"
      parsed <- signature_for "TimepointWritten" (signatures_in (lines contents))
      _ <- expect (parsed == expected_sig)
             ("the wrapped signature was parsed as " ++ parsed ++ " but must be " ++ expected_sig
               ++ " -- a truncating parser produces a valid-looking WRONG hash here")
      let computed = to_hex (topic0_of parsed)
      expect (computed == expected_topic)
        ("topic0 from the wrapped signature is " ++ computed ++ ", expected " ++ expected_topic)

-- | The SAME name in a file where the comment is ALREADY canonical. Agreement between the
-- decorated and the canonical shape is what makes idempotency a measurement, not a claim.
sc4_idempotent_canonical_form :: Check
sc4_idempotent_canonical_form =
  Check "sc4_idempotent_canonical_form" . guarded $ do
    canonical_side <- readFile dynamic_fee_hook_iface
    decorated_side <- readFile realized_vol_iface
    pure $ do
      (expected_sig, expected_topic) <- truth_for "TimepointWritten"
      already <- signature_for "TimepointWritten" (signatures_in (lines canonical_side))
      decorated <- signature_for "TimepointWritten" (signatures_in (lines decorated_side))
      _ <- expect (already == expected_sig)
             ("the already-canonical comment was altered by the normaliser: got " ++ already)
      _ <- expect (already == decorated)
             ("the two comment shapes disagree: canonical=" ++ already
               ++ " decorated=" ++ decorated)
      expect (to_hex (topic0_of already) == expected_topic)
        "the already-canonical form did not reproduce the ground-truth topic0"

-- | FALSIFIABILITY. Feed the checker the RETIRED stale topic0 (read from the pin file's own
-- @retired@ block -- never typed here) as VolOrderCreated's pinned value and require it to report
-- a mismatch. If this check does not observe a failure, the checker is not checking anything and
-- every green above is worthless.
sc4_falsifiable :: RigPins -> Check
sc4_falsifiable pins =
  Check "sc4_falsifiable" . guarded $
    case ( Map.lookup "VolOrderCreated" (pin_topics pins)
         , Map.lookup "topic_order_created_stale" (pin_retired pins)
         ) of
      (Nothing, _) -> pure (Left "rig-pins.json has no topics.VolOrderCreated to falsify")
      (_, Nothing) ->
        pure (Left "rig-pins.json has no retired.topic_order_created_stale to inject")
      (Just entry, Just stale_text) -> do
        contents <- readFile (T.unpack (pin_source entry))
        let stale = T.unpack stale_text
        pure $ case verify_pin topic0_of "VolOrderCreated" stale contents of
          Left _ -> Right ()
          Right () ->
            Left ("the checker ACCEPTED the retired value " ++ stale
                   ++ " as VolOrderCreated's topic0 -- it is not comparing anything")

-- | No live pin may carry a value the pin file records as retired.
sc4_no_retired_value_is_live :: RigPins -> Check
sc4_no_retired_value_is_live pins = pure_check "sc4_no_retired_value_is_live" $
  let retired = map (map toLower . T.unpack) (Map.elems (pin_retired pins))
      live =
        [ (T.unpack n, map toLower (T.unpack (pin_value e)))
        | (n, e) <- Map.toList (pin_selectors pins) ++ Map.toList (pin_topics pins)
        ]
      leaked = [n ++ " = " ++ v | (n, v) <- live, v `elem` retired]
  in expect (null leaked) ("retired values are live pins: " ++ intercalate ", " leaked)

-- | Two INDEPENDENT encoders agreeing is the strongest evidence pattern available here.
sc4_cast_agreement :: RigPins -> Check
sc4_cast_agreement pins = Check "sc4_cast_agreement" . guarded $ do
  (code, _, _) <- readProcessWithExitCode "cast" ["--version"] ""
  case code of
    ExitFailure _ -> pure (Left "cast (foundry) is not usable on PATH")
    ExitSuccess -> do
      let rows =
            [ ("cast sig", "sig", T.unpack (pin_signature e), T.unpack (pin_value e), T.unpack n)
            | (n, e) <- Map.toList (pin_selectors pins)
            ]
              ++ [ ("cast keccak", "keccak", T.unpack (pin_signature e), T.unpack (pin_value e), T.unpack n)
                 | (n, e) <- Map.toList (pin_topics pins)
                 ]
      disagreements <- mapM compare_one rows
      pure $
        let bad = catMaybes disagreements
        in expect (null bad) ("cross-encoder disagreement:\n      " ++ intercalate "\n      " bad)
  where
    compare_one (label, subcmd, sig, pinned, name) = do
      (code, out, _) <- readProcessWithExitCode "cast" [subcmd, sig] ""
      let from_cast = map toLower (strip_ws out)
          from_hs =
            "0x" ++ to_hex (if subcmd == "sig" then selector_of sig else topic0_of sig)
      pure $ case code of
        ExitFailure _ -> Just (name ++ ": " ++ label ++ " failed")
        ExitSuccess
          | from_cast == from_hs && from_cast == map toLower pinned -> Nothing
          | otherwise ->
              Just (name ++ ": " ++ label ++ "=" ++ from_cast ++ " haskell=" ++ from_hs
                     ++ " pinned=" ++ map toLower pinned)

-- ---------------------------------------------------------------------------------------------
-- SC-3: the manifest
-- ---------------------------------------------------------------------------------------------

-- | Deliberately FAILS rather than skips when the rig is down. cabal test is documented as
-- running after deploy-rig.sh; a suite that goes quietly green because the rig is missing is
-- worse than one that goes red.
sc3_load_succeeds :: Check
sc3_load_succeeds = Check "sc3_load_succeeds" . guarded $ do
  present <- doesFileExist manifest_file
  if not present
    then pure (Left ("no " ++ manifest_file ++ " -- stand the rig up first: " ++ deploy_command))
    else do
      outcome <- try (load_rig_from pins_file manifest_file)
      pure $ case outcome of
        Left err -> Left ("load_rig_from failed on the real files: " ++ show (err :: IOException))
        Right rig ->
          let n = Map.size (rig_contracts (rig_addrs rig))
          in expect (n == 7) ("expected 7 contracts in the manifest, found " ++ show n)

-- | A manifest missing a core contract, and a manifest that is not JSON at all, must BOTH stop
-- the loader. The first failure comes from the required-contract completeness check (a smaller
-- map is still a valid map, so aeson alone cannot see it); the second comes from the decoder.
sc3_corrupted_manifest_fails :: Check
sc3_corrupted_manifest_fails = Check "sc3_corrupted_manifest_fails" . guarded $ do
  present <- doesFileExist manifest_file
  if not present
    then pure (Left ("no " ++ manifest_file ++ " -- stand the rig up first: " ++ deploy_command))
    else do
      tmp <- getTemporaryDirectory
      let missing_path = tmp </> "rig-manifest-missing-contract.json"
          broken_path  = tmp </> "rig-manifest-not-json.json"
      decoded <- eitherDecodeFileStrict manifest_file :: IO (Either String Value)
      result <- case decoded of
        Left err -> pure (Left ("the real manifest did not decode as JSON: " ++ err))
        Right value -> do
          encodeFile missing_path (drop_contract "VolOrderManagerMod" value)
          writeFile broken_path "{\"chainId\": 31337, \"contracts\": {"
          a <- try (load_rig_from pins_file missing_path)
          b <- try (load_rig_from pins_file broken_path)
          pure $ do
            _ <- expect (failed a) "a manifest with VolOrderManagerMod deleted LOADED -- it must not"
            expect (failed b) "a manifest of invalid JSON LOADED -- it must not"
      mapM_ discard [missing_path, broken_path]
      pure result
  where
    failed :: Either IOException Rig -> Bool
    failed (Left _)  = True
    failed (Right _) = False

    discard path = do
      there <- doesFileExist path
      if there then removeFile path else pure ()

    drop_contract name (Object o) =
      let key = K.fromString "contracts"
      in case KM.lookup key o of
           Just contracts -> Object (KM.insert key (strip name contracts) o)
           Nothing        -> Object o
    drop_contract _ other = other

    strip name (Object o) = Object (KM.delete (K.fromString name) o)
    strip _ other         = other

-- | THE PURGE SCOPE, AND WHY IT IS THIS SCOPE.
--
-- The check covers @*.hs@ and @*.sh@ under @offchain\/@ -- the EXECUTABLE surface. CONTEXT's
-- "no whitelist" requirement is about exactly that: "the manifest cannot be quietly bypassed"
-- means no code path may reach an address without going through the manifest.
--
-- @offchain\/spec\/types.md@ holds a pasted RPC transcript containing addresses, a selector and
-- an anvil private key. It is documentation of a past session, it is never executed, and
-- redacting it would destroy evidence rather than close a hole. Scoping by FILE TYPE is a stated
-- rule with a reason; a list of individual exempted files is what CONTEXT forbade, and there is
-- none here. If a new @.hs@ or @.sh@ file needs a literal, that is a finding, not a new entry.
sc3_literal_purge :: Check
sc3_literal_purge = Check "sc3_literal_purge" . guarded $ do
  let pattern =
        intercalate "|"
          [ "0x[0-9a-fA-F]{40}\\b"
          , "0x[0-9a-fA-F]{64}\\b"
          , "0x[0-9a-fA-F]{8}\\b"
          ]
  (code, out, err) <-
    readProcessWithExitCode
      "grep"
      ["-rnE", pattern, "offchain", "--include=*.hs", "--include=*.sh"]
      ""
  pure $ case code of
    ExitFailure 1 -> Right ()
    ExitFailure n -> Left ("grep itself failed with exit " ++ show n ++ ": " ++ err)
    ExitSuccess ->
      Left ("address/selector/topic0 literals survive in the executable surface:\n"
             ++ unlines (map ("      " ++) (lines out)))

-- ---------------------------------------------------------------------------------------------
-- Phase 21, RPIN-01/02/03: the V2 wire layouts
--
-- The behaviour contract of the V2 re-pin, asserted directly and in one place. It is written
-- against the layouts read off the EXECUTABLE code
-- (@src\/modules\/pos_spec\/VolOrderManagerMod.plk@ lines 229-235 for the input word,
-- @src\/types\/pos_spec\/VolOrder.plk@ lines 50-66 for the storage word), never off the stale V1
-- comment block at lines 177-188 of that same module file, which still claims @width@ is the top
-- field and that bits >= 128 must be zero. Both sentences are false of V2.
-- ---------------------------------------------------------------------------------------------

volorder_iface :: FilePath
volorder_iface = "src/interfaces/pos_spec/VolOrderManagerInterface.plk"

-- | The four field values every V2 layout check is built from. DELIBERATELY FOUR DISTINCT
-- NUMBERS, so no transposition of two arguments or two fields can pass unnoticed.
rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega :: Integer
rpin_base_strike = 12345
rpin_base_width  = 600
rpin_base_skew   = 77
rpin_base_vega   = 10 ^ (18 :: Int)

rpin_base_order :: VolOrder
rpin_base_order =
  VolOrder
    { vol_target  = fromInteger rpin_base_strike
    , range_width = fromInteger rpin_base_width
    , skew        = fromInteger rpin_base_skew
    , target_vega = fromInteger rpin_base_vega
    }

-- | The low @bits@ set, as an 'Integer' mask. Written as a shift rather than as a hex literal:
-- 'sc3_literal_purge' greps this very file, and a mask that happens to be 8 hex digits with an
-- @0x@ prefix would redden it.
mask_of :: Int -> Integer
mask_of bits = (1 `shiftL` bits) - 1

-- | The @TICK_SPACING@ the module pins inside @build_vol_order@, occupying bits 104..127 of the
-- STORAGE word.
--
-- NOTE the rig's own deployed pool has tickSpacing = 10 (@offchain\/rig\/rig-manifest.json@,
-- @.pool.tickSpacing@). That is a real discrepancy between the module constant and the pool the
-- module writes against; it is REPORTED, not resolved -- resolving it means editing another
-- track's module. The expectations below are written against the MODULE CONSTANT, so a change to
-- it reddens here rather than passing silently.
module_tick_spacing :: Integer
module_tick_spacing = 20

-- | The V2 input word's four field positions, the bits->=224-are-zero guarantee, the u96 boundary
-- on both sides, and the 248-bit storage read-back -- the plan's behaviour contract in one place.
rpin_v2_layout_behavior :: Check
rpin_v2_layout_behavior = pure_check "rpin_v2_layout_behavior" $ do
  packed <- pack_vol_order_input rpin_base_order
  _ <- expect (packed == expected_input)
         ("V2 input word: packed " ++ show packed ++ ", expected " ++ show expected_input)
  _ <- rejects_target_vega 0
  _ <- rejects_target_vega (1 `shiftL` 96)
  top <- pack_vol_order_input rpin_base_order { target_vega = fromInteger (mask_of 96) }
  _ <- expect (top `shiftR` 224 == 0)
         ("target_vega = 2^96-1 packed with bits >= 224 SET, which the batch path would SKIP "
           ++ "silently: " ++ show top)
  expect (unpack_vol_order_storage expected_storage == rpin_base_order)
    ("the 248-bit storage word did not round-trip: got "
      ++ show (unpack_vol_order_storage expected_storage) ++ ", expected " ++ show rpin_base_order)
  where
    -- skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223
    expected_input =
      rpin_base_skew
        .|. (rpin_base_strike `shiftL` 16)
        .|. (rpin_base_width `shiftL` 104)
        .|. (rpin_base_vega `shiftL` 128)
    -- skew@0..15 | volStrike@16..103 | tickSpacing@104..127 | width@128..151 | targetVega@152..247
    expected_storage =
      rpin_base_skew
        .|. (rpin_base_strike `shiftL` 16)
        .|. (module_tick_spacing `shiftL` 104)
        .|. (rpin_base_width `shiftL` 128)
        .|. (rpin_base_vega `shiftL` 152)

    rejects_target_vega v =
      case pack_vol_order_input rpin_base_order { target_vega = fromInteger v } of
        Left why ->
          expect ("target_vega" `isInfixOf` why)
            ("target_vega = " ++ show v ++ " was rejected by a message that does not name "
              ++ "target_vega: " ++ why)
        Right w ->
          Left ("target_vega = " ++ show v ++ " was ACCEPTED, packing to " ++ show w)

-- ---------------------------------------------------------------------------------------------
-- RPIN-01: the calldata
-- ---------------------------------------------------------------------------------------------

-- | The encoder's selector, DERIVED three ways and required to agree: keccak of the signature
-- string PARSED OUT OF the interface file, the leading four bytes the encoder actually emits, and
-- the generated pin. Nothing here is transcribed -- a transcription would prove only that the test
-- agrees with itself.
rpin01_encoder_selector_is_recomputed :: RigPins -> Check
rpin01_encoder_selector_is_recomputed pins =
  Check "rpin01_encoder_selector_is_recomputed" . guarded $ do
    contents <- readFile volorder_iface
    calldata <- encode_create_order rpin_base_order
    pure $ do
      (truth_sig, truth_value) <- truth_for "create_order"
      sig <- signature_for "create_order" (signatures_in (lines contents))
      _ <- expect (sig == truth_sig)
             ("the interface file declares create_order as " ++ sig
               ++ " -- the V2 signature is " ++ truth_sig)
      let recomputed = to_hex (selector_of sig)
      _ <- expect (recomputed == truth_value)
             ("keccak of " ++ sig ++ " gave " ++ recomputed ++ ", expected " ++ truth_value)
      let emitted = to_hex (BS.take 4 (toBytes calldata))
      _ <- expect (emitted == recomputed)
             ("encode_create_order emits selector " ++ emitted
               ++ " but keccak of the interface file's OWN signature (" ++ sig ++ ") is "
               ++ recomputed ++ " -- the encoder is speaking a signature the module does not"
               ++ " dispatch")
      case Map.lookup "create_order" (pin_selectors pins) of
        Nothing -> Left ("rig-pins.json has no selectors.create_order -- regenerate it with: "
                          ++ "bash offchain/rig/generate-pins.sh")
        Just entry ->
          let pinned = map toLower (T.unpack (pin_value entry))
          in expect (pinned == "0x" ++ recomputed)
               (intercalate "\n"
                 [ "the generated pin and the recomputed selector disagree -- either the pin file"
                     ++ " or " ++ volorder_iface ++ " is stale"
                 , "      emitted by the encoder : " ++ emitted
                 , "      recomputed (keccak256) : " ++ recomputed
                 , "      pinned in " ++ pins_file ++ " : " ++ pinned
                 ])

-- | The four calldata argument words decode back as (strike, width, skew, targetVega), in that
-- order. The length assertion comes first: 96 bytes instead of 128 is a silent regression to the
-- retired 3-arg form, and it is the failure this check exists to catch.
rpin01_encoder_argument_order :: Check
rpin01_encoder_argument_order = Check "rpin01_encoder_argument_order" . guarded $ do
  calldata <- encode_create_order rpin_base_order
  let body = BS.drop 4 (toBytes calldata)
      arg_word :: Int -> Integer
      arg_word i = be_integer (BS.take 32 (BS.drop (32 * i) body))
  pure $ do
    _ <- expect (BS.length body == 128)
           ("the V2 call must carry exactly four 32-byte argument words (128 bytes); the encoder"
             ++ " produced " ++ show (BS.length body) ++ " -- 96 means it regressed to the retired"
             ++ " 3-arg form")
    _ <- word_is "strike"     0 (arg_word 0) rpin_base_strike
    _ <- word_is "width"      1 (arg_word 1) rpin_base_width
    _ <- word_is "skew"       2 (arg_word 2) rpin_base_skew
    word_is "targetVega" 3 (arg_word 3) rpin_base_vega
  where
    word_is name i got want =
      expect (got == want)
        ("argument word " ++ show (i :: Int) ++ " must be " ++ name ++ " = " ++ show want
          ++ ", got " ++ show got ++ " -- the declared argument order is"
          ++ " (strike, width, skew, targetVega)")

-- ---------------------------------------------------------------------------------------------
-- RPIN-02: the batch input word
-- ---------------------------------------------------------------------------------------------

-- | CONSTRUCTED corner corpus for the packed-word layouts. Deliberately kept SEPARATE from
-- StochasticOrderGen's DRAWN targetVega values: a 'Double'-based log-uniform draw has 53
-- significand bits against the band's ~70, so drawn values carry ~17 forced-zero low bits and are
-- a weak field-boundary corpus. See 21-RESEARCH.md section 6.6 note 2.
vega_corners :: [(String, Integer)]
vega_corners =
  [ ("min",             1)
  , ("mid_2_95",        1 `shiftL` 95)
  , ("max_u96",         (1 `shiftL` 96) - 1)
  , ("alternating_low", sum [1 `shiftL` b | b <- [0, 2 .. 94]])
  , ("band_bottom",     10 ^ (18 :: Int))
  , ("band_top",        10 ^ (21 :: Int))
  ]

-- | Every corner packs into a word whose four fields sit at 0 / 16 / 104 / 128 and whose bits
-- >= 224 are zero. The top-bit assertion is not cosmetic: on the BATCH path a dirty word is
-- SKIPPED with a @(false, 0)@ that is indistinguishable from an ordinary business rejection, so
-- this client-side guarantee is the only signal there is.
rpin02_input_word_layout :: Check
rpin02_input_word_layout = pure_check "rpin02_input_word_layout" $ mapM_ one vega_corners
  where
    one (label, v) = do
      w <- case pack_vol_order_input rpin_base_order { target_vega = fromInteger v } of
             Left why  -> Left ("corner " ++ label ++ " (" ++ show v ++ ") was REJECTED: " ++ why)
             Right ok  -> Right ok
      _ <- expect (w `shiftR` 224 == 0)
             ("corner " ++ label ++ ": bits >= 224 are SET in " ++ show w
               ++ " -- the batch path would skip this word silently")
      _ <- field label "targetVega@128..223" ((w `shiftR` 128) .&. mask_of 96) v
      _ <- field label "width@104..127 (INTERIOR in V2)"
             ((w `shiftR` 104) .&. mask_of 24) rpin_base_width
      _ <- field label "strike@16..103" ((w `shiftR` 16) .&. mask_of 88) rpin_base_strike
      field label "skew@0..15" (w .&. mask_of 16) rpin_base_skew

    field label slot got want =
      expect (got == want)
        ("corner " ++ label ++ ": " ++ slot ++ " reads back as " ++ show got
          ++ ", expected " ++ show want)

-- | Each of the four fields rejects ITS OWN out-of-range value with a message naming that field
-- and NO OTHER. Attributability is the property under test, not mere failure: a packer that
-- rejected everything with one generic message would satisfy "it failed" and tell a caller
-- nothing.
rpin02_field_rejections :: Check
rpin02_field_rejections = pure_check "rpin02_field_rejections" $ do
  mapM_ one probes
  case pack_vol_order_input rpin_base_order { target_vega = fromInteger (mask_of 96) } of
    Right _  -> Right ()
    Left why ->
      Left ("target_vega = 2^96-1 must be ACCEPTED -- the bound is exclusive on the high side,"
             ++ " exactly as target_vega_fits_packed enforces it on-chain: " ++ why)
  where
    field_names = ["vol_target", "range_width", "skew", "target_vega"]

    probes :: [(String, Integer -> VolOrder -> VolOrder, [Integer])]
    probes =
      [ ("vol_target",  \v o -> o { vol_target  = fromInteger v }, [0, 1 `shiftL` 88])
      , ("range_width", \v o -> o { range_width = fromInteger v }, [0, 1 `shiftL` 24])
      , ("skew",        \v o -> o { skew        = fromInteger v }, [0, 1 `shiftL` 16])
      , ("target_vega", \v o -> o { target_vega = fromInteger v }, [0, 1 `shiftL` 96])
      ]

    one (name, set, values) = mapM_ (probe name set) values

    probe name set v =
      case pack_vol_order_input (set v rpin_base_order) of
        Right w ->
          Left (name ++ " = " ++ show v ++ " was ACCEPTED, packing to " ++ show w
                 ++ " -- exactly one field was perturbed from a valid order, so this must fail")
        Left why -> do
          _ <- expect (name `isInfixOf` why)
                 (name ++ " = " ++ show v ++ " was rejected by a message that does not name it: "
                   ++ why)
          let others = [n | n <- field_names, n /= name, n `isInfixOf` why]
          expect (null others)
            (name ++ " = " ++ show v ++ " was rejected by a message that ALSO names "
              ++ intercalate ", " others ++ " -- the rejection is not attributable: " ++ why)

-- ---------------------------------------------------------------------------------------------
-- RPIN-03: the 248-bit storage word
-- ---------------------------------------------------------------------------------------------

-- | Mirror of @src\/types\/pos_spec\/VolOrder.plk@ lines 50-56 (@pack_vol_order@). 248 bits:
--
-- > skew@0..15 | volStrike@16..103 | tickSpacing@104..127 | width@128..151 | targetVega@152..247
--
-- Deliberately TEST-ONLY. It is the independent second implementation the library's unpacker is
-- checked against; promoting it to the library would create production code no requirement asks
-- for, and a round-trip against the library's own packer would prove only self-consistency.
pack_storage_reference :: Integer -> Integer -> Integer -> Integer -> Integer
pack_storage_reference strike width sk vega =
      (vega `shiftL` 152)
  .|. (width `shiftL` 128)
  .|. (module_tick_spacing `shiftL` 104)
  .|. (strike `shiftL` 16)
  .|. sk

-- | The storage word round-trips over the same corner corpus, the @tickSpacing@ slot is proven
-- POPULATED with the module constant rather than accidentally zero, and nothing sits above bit
-- 247. Assertions are per-field and name the corner, so a failure says which field and which
-- corner instead of dumping two records.
rpin03_storage_round_trip :: Check
rpin03_storage_round_trip = pure_check "rpin03_storage_round_trip" $ mapM_ one vega_corners
  where
    one (label, v) = do
      let word    = pack_storage_reference rpin_base_strike rpin_base_width rpin_base_skew v
          decoded = unpack_vol_order_storage word
      _ <- field label "vol_target" (toInteger (vol_target decoded)) rpin_base_strike
      _ <- field label "range_width" (toInteger (range_width decoded)) rpin_base_width
      _ <- field label "skew" (toInteger (skew decoded)) rpin_base_skew
      _ <- field label "target_vega" (toInteger (target_vega decoded)) v
      _ <- expect ((word `shiftR` 104) .&. mask_of 24 == module_tick_spacing)
             ("corner " ++ label ++ ": the tickSpacing slot at 104..127 holds "
               ++ show ((word `shiftR` 104) .&. mask_of 24) ++ ", expected the module constant "
               ++ show module_tick_spacing ++ " -- a zero there would make the round-trip pass"
               ++ " while the word was wrong")
      expect (word `shiftR` 248 == 0)
        ("corner " ++ label ++ ": the storage word is 248 bits, but bits >= 248 are SET in "
          ++ show word)

    field label name got want =
      expect (got == want)
        ("corner " ++ label ++ ": " ++ name ++ " read back as " ++ show got ++ ", expected "
          ++ show want)

-- | The INPUT word and the STORAGE word are different words for the same order, and they are
-- close enough to look interchangeable. This exhibits a concrete order where they differ, and
-- pins WHERE they differ rather than merely THAT they differ -- disagreement "somewhere" would
-- also be satisfied by two layouts that are wrong in the same way.
rpin03_input_word_is_not_storage_word :: Check
rpin03_input_word_is_not_storage_word =
  pure_check "rpin03_input_word_is_not_storage_word" $ do
    input <- pack_vol_order_input rpin_base_order
    let storage =
          pack_storage_reference
            rpin_base_strike rpin_base_width rpin_base_skew rpin_base_vega
    _ <- expect (input /= storage)
           ("the input word and the storage word are IDENTICAL (" ++ show input
             ++ ") -- one of the two layouts has been copy-pasted from the other")
    _ <- expect ((input `shiftR` 104) .&. mask_of 24 == rpin_base_width)
           ("input word: bits 104..127 must hold width = " ++ show rpin_base_width ++ ", got "
             ++ show ((input `shiftR` 104) .&. mask_of 24))
    _ <- expect ((storage `shiftR` 104) .&. mask_of 24 == module_tick_spacing)
           ("storage word: bits 104..127 must hold tickSpacing = " ++ show module_tick_spacing
             ++ ", got " ++ show ((storage `shiftR` 104) .&. mask_of 24))
    _ <- expect ((input `shiftR` 128) .&. mask_of 96 == rpin_base_vega)
           ("input word: targetVega must sit at 128..223, got "
             ++ show ((input `shiftR` 128) .&. mask_of 96))
    _ <- expect ((storage `shiftR` 152) .&. mask_of 96 == rpin_base_vega)
           ("storage word: targetVega must sit at 152..247, got "
             ++ show ((storage `shiftR` 152) .&. mask_of 96))
    expect (unpack_vol_order_storage input /= rpin_base_order)
      ("feeding the INPUT word to the STORAGE unpacker reproduced the original order -- the two"
        ++ " layouts are being conflated, which is exactly what a copy-paste between them looks"
        ++ " like: " ++ show (unpack_vol_order_storage input))

-- ---------------------------------------------------------------------------------------------
-- Phase 21, RPIN-04: the E1 VolOrderCreated v2 log shape
--
-- The emitter is @src\/lib\/events\/VolEventsLib.plk@ lines 47-54:
--
-- > let buf = @malloc_uninit(128);   ... four @mstore32 at 0, 32, 64, 96 ...
-- > @evm_log2(buf, 128, TOPIC0_VOL_ORDER_CREATED, order_id);
--
-- @\@evm_log2@ is EXACTLY TWO topics; 128 bytes is EXACTLY FOUR data words. The v1 decoder that
-- shipped before this phase matched a THREE-element topic list and read data words 2\/3\/4, so
-- against a v2 log it returned 'Nothing' -- it did not decode WRONGLY, it reported every real log
-- as \"unknown\" forever. That is why a topic0 constant swap alone would not have satisfied
-- RPIN-04, and why the positive decode below is the load-bearing assertion.
-- ---------------------------------------------------------------------------------------------

-- | A 32-byte big-endian encoding of a non-negative 'Integer'. Built by shifting rather than from
-- a hex string: 'sc3_literal_purge' greps this very file.
word32be :: Integer -> BS.ByteString
word32be n = BS.pack [fromIntegral ((n `shiftR` (8 * i)) .&. 0xff) | i <- [31, 30 .. 0]]

-- | An 'Integer' as a 32-byte topic\/data word.
hexstring_of :: Integer -> HexString
hexstring_of = fromBytes . word32be

-- | 'Change' has a non-optional @changeAddress@ and the decoder never looks at it. Twenty zero
-- bytes is exactly an address, so 'fromHexString' cannot fail here; the 'error' branch is
-- unreachable and exists only because the function is total in @Either@.
filler_address :: Address
filler_address =
  case fromHexString (fromBytes (BS.replicate 20 0)) of
    Right addr -> addr
    Left why   -> error ("20 zero bytes did not parse as an address: " ++ why)

-- | A hand-built log. Only @changeTopics@ and @changeData@ are load-bearing for the decoder; the
-- block\/tx metadata is filler. Built here rather than fetched so this check stays PURE -- @cabal
-- test@ is chain-independent, and the rig capture is the only thing in this repo that touches a
-- chain.
synthetic_log :: [HexString] -> [Integer] -> Change
synthetic_log topics data_words =
  Change
    { changeLogIndex         = Nothing
    , changeTransactionIndex = Nothing
    , changeTransactionHash  = Nothing
    , changeBlockHash        = Nothing
    , changeBlockNumber      = Nothing
    , changeAddress          = filler_address
    , changeData             = fromBytes (BS.concat (map word32be data_words))
    , changeTopics           = topics
    }

-- | The E1 topic0 as an 'Integer', RECOMPUTED from the signature string parsed out of the
-- interface file. Never transcribed, and never read from the pin file here -- the pin is compared
-- against this, not the source of it.
e1_topic0_from :: String -> Either String Integer
e1_topic0_from contents = do
  sig <- signature_for "VolOrderCreated" (signatures_in (lines contents))
  Right (be_integer (topic0_of sig))

-- | The order id carried in the INDEXED topic of the synthetic v2 log. Deliberately distinct from
-- all four data values, so \"orderId came from the topic\" is checkable rather than assumed.
rpin_base_order_id :: Integer
rpin_base_order_id = 7

-- | The v2 decode behaviour contract, asserted at the SHAPE level in one place: a two-topic \/
-- four-word log decodes, and the retired three-topic \/ five-word shape does not. Both assertions
-- are expressible against the pre-Phase-21 record, which is what makes this an ASSERTION-level
-- RED rather than a compile error.
rpin_e1_v2_decode_behavior :: Check
rpin_e1_v2_decode_behavior = Check "rpin_e1_v2_decode_behavior" . guarded $ do
  contents <- readFile volorder_iface
  pure $ do
    t0 <- e1_topic0_from contents
    let v2_log =
          synthetic_log
            [hexstring_of t0, hexstring_of rpin_base_order_id]
            [rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega]
        -- the shape the shipped decoder accepted: @evm_log3 (topic0, owner, timestamp) over a
        -- 160-byte payload
        v1_log =
          synthetic_log
            [hexstring_of t0, hexstring_of 0, hexstring_of 0]
            [32, 96, rpin_base_strike, rpin_base_width, rpin_base_skew]
    _ <- expect (isJust (decode_order_created t0 v2_log))
           ("the E1 v2 log shape (2 topics, 4 data words -- @evm_log2 over a 128-byte buffer)"
             ++ " did not decode. A decoder that returns Nothing here reports every real"
             ++ " VolOrderCreated log as \"unknown\" and never says so.")
    expect (isNothing (decode_order_created t0 v1_log))
      ("the RETIRED v1 log shape (3 topics, 5 data words) DECODED. That shape is not emitted by"
        ++ " any live module; accepting it means the decoder is still reading data words 2/3/4.")

-- | A pinned or retired hex value as an 'Integer'. Length is deliberately NOT constrained: the
-- retired @topic_order_created_stale@ is only 8 hex digits, and reading it numerically then
-- rebuilding the topic with 'word32be' left-pads it to 32 bytes exactly as the wire would.
integer_of_hex_text :: String -> Either String Integer
integer_of_hex_text raw =
  let s    = map toLower (strip_ws raw)
      body = if "0x" `isPrefixOf` s then drop 2 s else s
  in if not (null body) && all isHexDigit body
       then Right (foldl (\acc c -> acc * 16 + toInteger (digitToInt c)) 0 body)
       else Left ("not a hex value: " ++ show raw)

-- | A retired value, read from the pin file's own @retired@ block. NEVER typed into this file --
-- that is the whole point of the block existing.
retired_value :: RigPins -> T.Text -> Either String Integer
retired_value pins name =
  case Map.lookup name (pin_retired pins) of
    Nothing -> Left ("rig-pins.json has no retired." ++ T.unpack name
                      ++ " -- regenerate it with: bash offchain/rig/generate-pins.sh")
    Just t  -> integer_of_hex_text (T.unpack t)

-- | The topic0 is RECOMPUTED from the signature parsed out of the interface file, and the pin is
-- required to agree with THAT -- not the other way round. A pin file is an artifact; the @.plk@
-- declaration is the source of truth, so the arrow of evidence has to point from the file to the
-- pin. Ground truth is reused rather than a new literal introduced.
rpin04_topic0_is_recomputed :: RigPins -> Check
rpin04_topic0_is_recomputed pins = Check "rpin04_topic0_is_recomputed" . guarded $ do
  contents <- readFile volorder_iface
  pure $ do
    (truth_sig, truth_value) <- truth_for "VolOrderCreated"
    sig <- signature_for "VolOrderCreated" (signatures_in (lines contents))
    _ <- expect (sig == truth_sig)
           ("the interface file declares VolOrderCreated as " ++ sig
             ++ " -- the V2 signature is " ++ truth_sig
             ++ " (uint256 indexed orderId, uint88, uint24, uint16, uint96)")
    let recomputed = to_hex (topic0_of sig)
    _ <- expect (recomputed == truth_value)
           ("keccak of " ++ sig ++ " gave " ++ recomputed ++ ", expected " ++ truth_value)
    case Map.lookup "VolOrderCreated" (pin_topics pins) of
      Nothing -> Left ("rig-pins.json has no topics.VolOrderCreated -- regenerate it with: "
                        ++ "bash offchain/rig/generate-pins.sh")
      Just entry ->
        let pinned = map toLower (T.unpack (pin_value entry))
        in expect (pinned == "0x" ++ recomputed)
             (intercalate "\n"
               [ "the generated pin and the recomputed topic0 disagree -- either the pin file or "
                   ++ volorder_iface ++ " is stale"
               , "      signature parsed from the file : " ++ sig
               , "      recomputed (keccak256)         : 0x" ++ recomputed
               , "      pinned in " ++ pins_file ++ "  : " ++ pinned
               ])

-- | THE check a constant swap alone could not satisfy: a v2-shaped log DECODES, field by field.
--
-- The four data values are deliberately DISTINCT, so no transposition of two words can pass, and
-- @orderId@ is asserted to come from the INDEXED TOPIC by requiring that no data word carries its
-- value -- otherwise a decoder reading it out of the payload would look identical here.
rpin04_positive_v2_decode :: Check
rpin04_positive_v2_decode = Check "rpin04_positive_v2_decode" . guarded $ do
  contents <- readFile volorder_iface
  pure $ do
    t0 <- e1_topic0_from contents
    let data_values = [rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega]
        log_v2 = synthetic_log [hexstring_of t0, hexstring_of rpin_base_order_id] data_values
        wanted =
          OrderCreatedEvent
            { orderId         = rpin_base_order_id
            , orderStrike     = rpin_base_strike
            , orderRangeWidth = rpin_base_width
            , orderSkew       = rpin_base_skew
            , orderTargetVega = rpin_base_vega
            }
    _ <- expect (length (nub data_values) == 4)
           ("the four data values must be DISTINCT or a transposed pair would decode cleanly: "
             ++ show data_values)
    _ <- expect (rpin_base_order_id `notElem` data_values)
           ("the order id " ++ show rpin_base_order_id ++ " also appears as a DATA word, so this"
             ++ " check could not tell a topic-read from a data-read: " ++ show data_values)
    event <- case decode_order_created t0 log_v2 of
      Nothing ->
        Left ("a well-formed v2 log (2 topics, 4 data words, correct topic0) did NOT decode."
               ++ " This is the exact shape src/lib/events/VolEventsLib.plk:47-54 emits.")
      Just e -> Right e
    _ <- word_is "orderId (INDEXED topic 1)"      (orderId event)         rpin_base_order_id
    _ <- word_is "orderStrike (data word 0)"      (orderStrike event)     rpin_base_strike
    _ <- word_is "orderRangeWidth (data word 1)"  (orderRangeWidth event) rpin_base_width
    _ <- word_is "orderSkew (data word 2)"        (orderSkew event)       rpin_base_skew
    _ <- word_is "orderTargetVega (data word 3)"  (orderTargetVega event) rpin_base_vega
    expect (event == wanted)
      ("the whole record disagrees: got " ++ show event ++ ", expected " ++ show wanted)
  where
    word_is name got want =
      expect (got == want)
        (name ++ " decoded as " ++ show got ++ ", expected " ++ show want)

-- | Three negatives, each with its own message.
--
-- (1) The THREE-topic / five-word v1 shape carrying the CORRECT v2 topic0 -- the exact shape the
--     shipped decoder ACCEPTED, so this is what proves the rewrite is real rather than cosmetic.
-- (2) A two-topic log with only 96 bytes of data -- without the length guard, @data_word 3@ reads
--     off the end and returns a silent, plausible @targetVega = 0@.
-- (3) A well-formed v2 log decoded with the WRONG expected topic0.
rpin04_v1_shape_is_rejected :: Check
rpin04_v1_shape_is_rejected = Check "rpin04_v1_shape_is_rejected" . guarded $ do
  contents <- readFile volorder_iface
  pure $ do
    t0 <- e1_topic0_from contents
    let log_v1 =
          synthetic_log
            [hexstring_of t0, hexstring_of 0, hexstring_of 0]
            [32, 96, rpin_base_strike, rpin_base_width, rpin_base_skew]
        log_short =
          synthetic_log
            [hexstring_of t0, hexstring_of rpin_base_order_id]
            [rpin_base_strike, rpin_base_width, rpin_base_skew]
        log_v2 =
          synthetic_log
            [hexstring_of t0, hexstring_of rpin_base_order_id]
            [rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega]
    _ <- expect (isNothing (decode_order_created t0 log_v1))
           ("the v1 three-topic / five-word shape DECODED. No live module emits it -- accepting"
             ++ " it means the decoder still pattern-matches a 3-element topic list.")
    _ <- expect (isNothing (decode_order_created t0 log_short))
           ("a two-topic log with only 96 bytes of data DECODED. data_word 3 reads past the end"
             ++ " and yields 0, so this would have reported a fabricated targetVega = 0 as fact.")
    _ <- expect (isJust (decode_order_created t0 log_v2))
           "the control v2 log did not decode, so the negatives above prove nothing"
    expect (isNothing (decode_order_created (t0 + 1) log_v2))
      "a well-formed v2 log decoded under the WRONG expected topic0 -- the topic is not compared"

-- | Both retired topic0s are rejected, AND the rejection is shown to come from the TOPIC
-- COMPARISON rather than from a malformed fixture: the very same log decodes successfully when
-- the retired value is supplied as the expected topic0. Without that second half, a fixture that
-- was simply broken would produce the same green.
rpin04_retired_topic0s_are_rejected :: RigPins -> Check
rpin04_retired_topic0s_are_rejected pins =
  Check "rpin04_retired_topic0s_are_rejected" . guarded $ do
    contents <- readFile volorder_iface
    pure $ do
      live <- e1_topic0_from contents
      mapM_ (one live) ["topic_vol_order_created_v1", "topic_order_created_stale"]
  where
    one live name = do
      retired <- retired_value pins name
      _ <- expect (retired /= 0)
             ("retired." ++ T.unpack name ++ " read as 0 -- the pin file value did not parse")
      _ <- expect (retired /= live)
             ("retired." ++ T.unpack name ++ " EQUALS the live recomputed topic0 -- a retired"
               ++ " value is live again")
      let log_retired =
            synthetic_log
              [hexstring_of retired, hexstring_of rpin_base_order_id]
              [rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega]
      _ <- expect (isNothing (decode_order_created live log_retired))
             ("a log carrying the retired topic0 retired." ++ T.unpack name
               ++ " was ACCEPTED as a live VolOrderCreated event")
      expect (isJust (decode_order_created retired log_retired))
        ("the fixture built from retired." ++ T.unpack name ++ " does not decode even under its"
          ++ " OWN topic0, so the rejection above proves nothing about the topic comparison --"
          ++ " the log is simply malformed")

-- ---------------------------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  loaded <- eitherDecodeFileStrict pins_file :: IO (Either String RigPins)
  let checks = case loaded of
        Left err ->
          [ pure_check "sc4_pins_file_decodes" $
              Left ("could not decode " ++ pins_file ++ ": " ++ err
                     ++ "\n      regenerate it with: bash offchain/rig/generate-pins.sh")
          ]
        Right pins ->
          [ sc4_ground_truth_encoder
          , sc4_multiline_timepoint_written
          , sc4_idempotent_canonical_form
          , sc4_falsifiable pins
          , sc4_no_retired_value_is_live pins
          , sc4_cast_agreement pins
          , sc3_load_succeeds
          , sc3_corrupted_manifest_fails
          , sc3_literal_purge
          , rpin_v2_layout_behavior
          , rpin01_encoder_selector_is_recomputed pins
          , rpin01_encoder_argument_order
          , rpin02_input_word_layout
          , rpin02_field_rejections
          , rpin03_storage_round_trip
          , rpin03_input_word_is_not_storage_word
          , rpin_e1_v2_decode_behavior
          , rpin04_topic0_is_recomputed pins
          , rpin04_positive_v2_decode
          , rpin04_v1_shape_is_rejected
          , rpin04_retired_topic0s_are_rejected pins
          ]
            ++ per_pin_checks pins

  outcomes <- mapM run_one checks
  let failed = [name | (name, False) <- outcomes]
      total  = length outcomes
  putStrLn ""
  putStrLn (show (total - length failed) ++ "/" ++ show total ++ " checks passed")
  if null failed
    then putStrLn "SC-3 and SC-4 OK"
    else do
      putStrLn (show (length failed) ++ " FAILED: " ++ intercalate ", " (sort failed))
      exitFailure

run_one :: Check -> IO (String, Bool)
run_one check = do
  outcome <- check_run check
  case outcome of
    Right () -> putStrLn ("PASS " ++ check_name check) >> pure (check_name check, True)
    Left why ->
      putStrLn ("FAIL " ++ check_name check ++ ": " ++ why) >> pure (check_name check, False)
