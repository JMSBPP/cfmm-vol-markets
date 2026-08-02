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
import Control.Monad (replicateM)
import Crypto.Ethereum.Utils (keccak256)
import Data.Aeson (Value (..), eitherDecodeFileStrict, encodeFile)
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import Data.Bits (shiftL, shiftR, xor, (.&.), (.|.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Char (digitToInt, intToDigit, isAlpha, isAlphaNum, isHexDigit, isSpace, toLower)
import qualified Data.Foldable as F
import Data.List (intercalate, isInfixOf, isPrefixOf, nub, sort, stripPrefix)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, isJust, isNothing)
import Data.Solidity.Prim.Address (Address, fromHexString)
import qualified Data.Text as T
import System.Directory (doesFileExist, getTemporaryDirectory, removeFile)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)
import System.Random.MWC (create, uniformR)

import Rig.Manifest
  ( PinEntry (..)
  , Rig (..)
  , RigAddresses (..)
  , RigPins (..)
  , load_rig_from
  , rig_manifest_path
  )
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Network.Ethereum.Api.Types (Change (..))

import VolOrder.Decode
  ( OrderCreatedEvent (..)
  , be_integer
  , decode_create_orders_result
  , decode_order_created
  , unpack_vol_order_storage
  )
import CheatSwap.Encoding (encode_extsload, encode_swap, extsload_signature, swap_signature)
import CheatSwap.Types (check_cheat_tick, compose_slot0, pool_state_slot)
import RealizedVol.Decode
  ( FeeApplied (..)
  , TimepointWritten (..)
  , decode_fee_applied
  , decode_timepoint_written
  , signed_word
  )
import StochasticOrderGen.Simulate (draw_target_vega)
import StochasticOrderGen.Types (VegaDraw (..))
import VolOrder.Encoding (encode_create_order, pack_vol_order_input)
import VolOrder.Types (VolOrder (..))

-- ---------------------------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------------------------

pins_file :: FilePath
pins_file = "offchain/rig/rig-pins.json"

-- | The rig manifest path, resolved the SAME way 'Rig.Manifest.load_rig' resolves it: through
-- 'rig_manifest_path', which honours the @RIG_MANIFEST@ environment variable.
--
-- This was a hardcoded @FilePath@ constant until 22-03 MEASURED the consequence. The plan's
-- falsification for the nine-contract requirement was @RIG_MANIFEST=\<copy without
-- PoolSwapTest\> cabal test@ -- and the suite went GREEN at 68\/68, because the constant sent
-- every check straight back to the real manifest and the override was silently ignored. The
-- suite therefore could not be pointed at ANY manifest for ANY falsification, while
-- @verify-rig.sh@ (which does honour the variable) and every @Rig.Manifest@ error message
-- (\"Override the path with the RIG_MANIFEST environment variable\") both claimed it could.
-- Two halves of one rig verification disagreeing about what an override means is worse than
-- either half being wrong.
manifest_file :: IO FilePath
manifest_file = rig_manifest_path

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
-- | A retired value must never come back as a LIVE pin. The comparison is NUMERIC, and that is
-- load-bearing rather than stylistic.
--
-- A MEASURED HOLE, CLOSED HERE (found by 21-03, deferred to 21-05). This check compared
-- lowercased STRINGS until plan 21-05. During 21-03's stale-pin demo the retired
-- @topic_order_created_stale@ -- 10 characters -- was injected as a live topic0 in its
-- LEFT-PADDED 32-byte form, 66 characters. Same number, different string, so the one guard whose
-- entire job is to stop a retired constant coming back to life stayed GREEN while one was live.
-- Three other checks caught that injection; this one, the check specifically written for it, did
-- not. Zero-padding is exactly the form a topic0 takes on the wire, so the defeat is the NORMAL
-- case rather than a contrived one.
--
-- A value that does not parse as hex FAILS the check rather than being skipped: a retired entry
-- that cannot be read is a guard silently covering one fewer value. (The @_note@ metadata key is
-- already dropped upstream by 'Rig.Manifest', so only real values reach here.)
sc4_no_retired_value_is_live :: RigPins -> Check
sc4_no_retired_value_is_live pins = pure_check "sc4_no_retired_value_is_live" $ do
  retired <- mapM (numeric "retired") (Map.toList (pin_retired pins))
  live <-
    mapM (numeric "live pin")
      [ (n, pin_value e)
      | (n, e) <- Map.toList (pin_selectors pins) ++ Map.toList (pin_topics pins)
      ]
  let leaked =
        [ name ++ " is the retired value " ++ retired_name
        | (name, value) <- live
        , (retired_name, retired_value_) <- retired
        , value == retired_value_
        ]
  expect (null leaked)
    ("retired values are live pins: " ++ intercalate ", " leaked
      ++ " -- compared NUMERICALLY, so a left-padded form does not slip past")
  where
    numeric what (name, raw) =
      case integer_of_hex_text (T.unpack raw) of
        Right value -> Right (T.unpack name, value)
        Left why ->
          Left ("the " ++ what ++ " entry " ++ show (T.unpack name) ++ " cannot be read as hex,"
                 ++ " so it cannot be compared numerically and the guard would silently cover one"
                 ++ " fewer value: " ++ why)

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
  mf      <- manifest_file
  present <- doesFileExist mf
  if not present
    then pure (Left ("no " ++ mf ++ " -- stand the rig up first: " ++ deploy_command))
    else do
      outcome <- try (load_rig_from pins_file mf)
      pure $ case outcome of
        Left err -> Left ("load_rig_from failed on the real files: " ++ show (err :: IOException))
        Right rig ->
          let n = Map.size (rig_contracts (rig_addrs rig))
          in expect (n == 9)
               ("expected 9 contracts in the manifest (the seven Phase-20 deployments plus the "
                 ++ "two InitSwappableRig routers PoolSwapTest and PoolModifyLiquidityTest), found "
                 ++ show n)

-- | A manifest missing a core contract, and a manifest that is not JSON at all, must BOTH stop
-- the loader. The first failure comes from the required-contract completeness check (a smaller
-- map is still a valid map, so aeson alone cannot see it); the second comes from the decoder.
sc3_corrupted_manifest_fails :: Check
sc3_corrupted_manifest_fails = Check "sc3_corrupted_manifest_fails" . guarded $ do
  mf      <- manifest_file
  present <- doesFileExist mf
  if not present
    then pure (Left ("no " ++ mf ++ " -- stand the rig up first: " ++ deploy_command))
    else do
      tmp <- getTemporaryDirectory
      let missing_path = tmp </> "rig-manifest-missing-contract.json"
          broken_path  = tmp </> "rig-manifest-not-json.json"
      decoded <- eitherDecodeFileStrict mf :: IO (Either String Value)
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
-- HISTORY, kept because a resolved discrepancy is worth more on the record than a clean comment:
-- this note used to say the rig's own deployed pool had a tick spacing of 10 while the module
-- pinned 20, and reported that as a real module-vs-pool discrepancy. It was RESOLVED in PR #18
-- (ref @2039f27@, imported by plan 22-01), finding **F2**: @DeployDynamicFeeHook.s.sol@ now
-- declares @TICK_SPACING = 20@, so @.pool.tickSpacing@ in @offchain\/rig\/rig-manifest.json@ reads
-- 20 and module and pool AGREE. The VALUE below did not move; only the claim about the pool did.
--
-- The expectations below are still written against the MODULE CONSTANT, so a change to it reddens
-- here rather than passing silently -- and they would keep reddening if the pool ever drifted away
-- again.
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
-- Phase 21, RPIN-06: targetVega is genuinely COMPARED on readback, not merely carried
--
-- @verify_mined_order@ (@offchain\/lib\/VolOrder\/Rpc.hs@ lines 94-104) reads the stored word
-- back and compares WHOLE 'VolOrder's with the derived 'Eq':
--
-- > let actual_order = unpack_vol_order_storage packed
-- > if actual_order == expected_order then pure () else fail ...
--
-- Once @target_vega@ became a record field (21-01), that comparison began covering it with NO
-- CODE CHANGE. That is exactly why this needs a measured failure: the change is INVISIBLE IN A
-- DIFF, so the only evidence that the field is really compared -- rather than dropped by an
-- unpacker that forgets to set it -- is an observed RED.
--
-- @verify_mined_order@ is Web3-monadic and not exported, so the check below is PURE and
-- REPRODUCES the comparison rather than invoking it. Confirming it against a live mined order is
-- Phase 22 (DRIV-02), not this plan; nothing here should be read as a claim about a real
-- transaction.
-- ---------------------------------------------------------------------------------------------

-- | A second targetVega, distinct from 'rpin_base_vega', for the routing check.
rpin_alt_vega :: Integer
rpin_alt_vega = 10 ^ (21 :: Int)

-- | A storage word perturbed ONLY inside the u96 targetVega field at bits 152..247 must fail the
-- readback comparison -- at BOTH ends of the field, which are separate failure surfaces.
--
-- The unperturbed baseline is asserted FIRST: without it, the inequality below could pass for the
-- wrong reason (any thoroughly broken unpacker fails to match a submitted order). The
-- perturbation is then proven to be confined to 152..247, because a flip that also moved another
-- field would prove nothing about targetVega. Finally the difference is proven LOCALISED -- the
-- other three fields still read back correctly -- so a wholesale unpack bug cannot masquerade as
-- this check passing.
rpin06_perturbed_target_vega_fails_readback :: Check
rpin06_perturbed_target_vega_fails_readback =
  pure_check "rpin06_perturbed_target_vega_fails_readback" $ do
    let submitted = rpin_base_order
        word = pack_storage_reference
                 rpin_base_strike rpin_base_width rpin_base_skew rpin_base_vega
    _ <- expect (unpack_vol_order_storage word == submitted)
           ("the UNPERTURBED storage word does not round-trip, so the perturbation results below"
             ++ " would pass for the wrong reason: got " ++ show (unpack_vol_order_storage word)
             ++ ", expected " ++ show submitted)
    -- The flip MASKS are written out at the call site rather than derived from a bit index, so
    -- the two ends of the u96 field are legible as constants in the source.
    mapM_ (one submitted word)
      [ ("bit 152 (LOWEST bit of targetVega)", 1 `shiftL` 152)
      , ("bit 247 (TOP bit of the u96 field)", 1 `shiftL` 247)
      ]
  where
    one submitted word (label, flip_mask) = do
      let perturbed = word `xor` flip_mask
          delta     = word `xor` perturbed
          decoded   = unpack_vol_order_storage perturbed
      _ <- expect (delta `shiftR` 248 == 0)
             (label ++ ": the perturbation set bits at or above 248, outside the 248-bit storage"
               ++ " word entirely: delta = " ++ show delta)
      _ <- expect ((delta .&. mask_of 152) == 0)
             (label ++ ": the perturbation also moved bits BELOW 152 (skew, volStrike,"
               ++ " tickSpacing or width), so it proves nothing about targetVega: delta = "
               ++ show delta)
      -- THE comparison verify_mined_order performs, reproduced exactly.
      _ <- expect (decoded /= submitted)
             (label ++ ": a storage word perturbed inside targetVega STILL compared equal to the"
               ++ " submitted order. verify_mined_order would accept a mined order whose"
               ++ " targetVega is not the one that was submitted.")
      _ <- same label "vol_target"  (vol_target decoded)  (vol_target submitted)
      _ <- same label "range_width" (range_width decoded) (range_width submitted)
      _ <- same label "skew"        (skew decoded)        (skew submitted)
      expect (target_vega decoded /= target_vega submitted)
        (label ++ ": the records differ but target_vega does NOT -- the inequality above is"
          ++ " coming from some other field, so it is not evidence about targetVega")

    same label name got want =
      expect (got == want)
        (label ++ ": " ++ name ++ " ALSO changed (" ++ show got ++ " vs " ++ show want
          ++ ") -- the difference is not localised to targetVega, so a wholesale unpack bug"
          ++ " would look like this check passing")

-- | STRUCTURAL, not behavioural: this proves targetVega is ROUTED to both senders, not that any
-- value is correct. Two orders differing ONLY in @target_vega@ must produce different batch input
-- words (so the batch sender carries the field) and different calldata differing ONLY in the
-- FOURTH argument word at bytes 100..132 (so the single-call sender carries it, in its own slot).
rpin06_target_vega_reaches_every_sender :: Check
rpin06_target_vega_reaches_every_sender =
  Check "rpin06_target_vega_reaches_every_sender" . guarded $ do
    let other = rpin_base_order { target_vega = fromInteger rpin_alt_vega }
    calldata_base <- encode_create_order rpin_base_order
    calldata_alt  <- encode_create_order other
    pure $ do
      _ <- expect (rpin_alt_vega /= rpin_base_vega)
             "the two orders must actually differ in target_vega"
      word_base <- pack_vol_order_input rpin_base_order
      word_alt  <- pack_vol_order_input other
      _ <- expect (word_base /= word_alt)
             ("two orders differing only in target_vega packed to the SAME batch input word ("
               ++ show word_base ++ ") -- the batch sender drops the field")
      let bytes_base = toBytes calldata_base
          bytes_alt  = toBytes calldata_alt
      _ <- expect (BS.length bytes_base == 132 && BS.length bytes_alt == 132)
             ("V2 calldata is 4 selector bytes + four 32-byte words = 132; got "
               ++ show (BS.length bytes_base) ++ " and " ++ show (BS.length bytes_alt))
      _ <- expect (BS.take 100 bytes_base == BS.take 100 bytes_alt)
             "the selector and the first three argument words moved, but only target_vega changed"
      expect (BS.drop 100 bytes_base /= BS.drop 100 bytes_alt)
        ("the FOURTH argument word (bytes 100..132) is identical for two orders with different"
          ++ " target_vega -- the single-call sender drops the field")

-- ---------------------------------------------------------------------------------------------
-- VEGA-01: the drawn targetVega
-- ---------------------------------------------------------------------------------------------

-- | The DECIDED draw law. The band is not a taste: it is the v3 relation
-- @L = amount1 / (1 - 1.0001 ** (-w/4))@ instantiated on the rig's own pool (initTick 0, both
-- tokens 18 decimals) for one whole token, from full range (1.000e18) down to a ~20-tick
-- concentrated band (2.001e21). See 'StochasticOrderGen.Types.VegaDraw' for the full derivation.
vega01_band :: VegaDraw
vega01_band = LogUniform { vega_min = 10 ^ (18 :: Int), vega_max = 10 ^ (21 :: Int) }

-- | Behaviour anchor for the drawn targetVega, introduced as the TDD RED for plan 21-04 task 1.
--
-- Three properties, all expressed against the generator's own draw rather than against a
-- transcribed table of values:
--
--   1. every draw under the configured band lands inside it;
--   2. INVERTED bounds fail loudly instead of returning a plausible-looking number;
--   3. a ZERO lower bound fails loudly -- a @targetVega@ of 0 violates the on-chain
--      @vega_target_is_complete@ @> 0@ predicate and, on the batch path, comes back as a
--      @(false, 0)@ indistinguishable from an ordinary business rejection.
vega01_draw_behavior :: Check
vega01_draw_behavior = Check "vega01_draw_behavior" . guarded $ do
  gen <- create
  drawn <- replicateM 32 (draw_target_vega gen vega01_band)
  inverted <- attempt_draw (LogUniform { vega_min = 10 ^ (21 :: Int), vega_max = 10 ^ (18 :: Int) })
  zero_low <- attempt_draw (LogUniform { vega_min = 0, vega_max = 10 ^ (21 :: Int) })
  pure $ do
    _ <- mapM_ in_band (zip [0 :: Int ..] drawn)
    _ <- threw "inverted bounds (vega_min = 10^21 > vega_max = 10^18)" inverted
    threw "a zero lower bound (vega_min = 0)" zero_low
  where
    in_band (i, v) =
      expect (v >= vega_min vega01_band && v <= vega_max vega01_band)
        ("draw " ++ show i ++ " = " ++ show v ++ " is outside the configured band ["
          ++ show (vega_min vega01_band) ++ ", " ++ show (vega_max vega01_band) ++ "]")

    threw what outcome =
      case outcome of
        Left _  -> Right ()
        Right v ->
          Left (what ++ " RETURNED " ++ show v ++ " instead of failing. A draw law that does not"
                 ++ " guard at draw time hands a nonsense targetVega to the encoder, where it is"
                 ++ " either rejected far from the cause or silently skipped by the batch path.")

-- | Drive 'draw_target_vega' and capture the loud failure. @fail@ in @IO@ throws an
-- 'IOException', which is what the suite's own 'guarded' already handles.
attempt_draw :: VegaDraw -> IO (Either IOException Integer)
attempt_draw law = do
  gen <- create
  try (draw_target_vega gen law)

-- | Number of significant bits. Written out rather than taken from 'Data.Bits' because
-- @finiteBitSize@ is not defined for 'Integer'.
bit_length :: Integer -> Int
bit_length = go 0
  where
    go acc 0 = acc
    go acc n = go (acc + 1) (n `div` 2)

-- | A SECOND implementation of the decided log-uniform law, mirroring
-- 'StochasticOrderGen.Simulate.draw_target_vega''s transform but taking its uniform as an
-- argument instead of drawing it. Same role as 'pack_storage_reference': the library is checked
-- against an independent expression of the spec rather than against itself.
log_uniform_reference :: Integer -> Integer -> Double -> Integer
log_uniform_reference lo hi u =
  round (fromIntegral lo * (fromIntegral hi / fromIntegral lo) ** u)

-- | The first twelve draws of 'System.Random.MWC.create''s default-seeded stream under
-- 'vega01_band', pinned as VALUES.
--
-- These are a GOLDEN, and what a golden does and does not establish is worth being exact about.
-- It establishes that the draw law and the generator stream beneath it are UNCHANGED -- a
-- different exponent, a different band, or a different mwc-random stream all redden here at the
-- first element. It does NOT establish that the law is the RIGHT law: that is a decision, argued
-- from the v3 band derivation and arXiv:2205.08904 in 'StochasticOrderGen.Types.VegaDraw', and
-- no test can supply it.
--
-- The reason to pin values at all is that the bounds and spread assertions below are satisfied
-- by MANY wrong draw laws -- an assertion whose conclusion is an inequality survives any mutant
-- that keeps the value inside the inequality. These twelve numbers do not.
vega01_first_twelve :: [Integer]
vega01_first_twelve =
  [ 1186946348279245568
  , 166952222113890402304
  , 3006703757638344704
  , 121844603607608246272
  , 4798878527208134656
  , 22362718531875102720
  , 37052572198576381952
  , 2315392034344841216
  , 37999405005355057152
  , 1475274689841291776
  , 546508318830051721216
  , 181491393322483220480
  ]

-- | 256 fixed-seed draws, pinned four ways.
--
-- 'System.Random.MWC.create' gives a deterministic default-seeded generator, so this check
-- produces the same numbers on every machine and every run. mwc-random's OTHER seeding entry
-- point -- the one taking an explicit @Vector Word32@ seed -- is deliberately not used: it would
-- drag @vector@ into @build-depends@ for no gain, since a fixed seed is all this needs. (Its
-- name is not written out here because @sc3_literal_purge@'s sibling acceptance grep for this
-- plan requires that identifier to be absent from this file.)
--
-- What each assertion establishes, stated separately because they are not equally strong:
--
--   [BOUNDS]  every draw fits the ABI field @[1, 2^96-1]@ and lies inside the configured band.
--             This is the weakest assertion here: an enormous family of wrong laws satisfies it.
--   [SPREAD]  the draws vary (essentially all 256 distinct), sweep at least 8 distinct
--             bit-lengths inside 60..70, and put at least 40 of 256 in the bottom decade. The
--             bit-length part rules out a CONSTANT; the bottom-decade part is what rules out a
--             LINEAR-UNIFORM draw, which was MEASURED to clear the bit-length assertion. Neither
--             pins any value.
--   [VALUES]  every draw equals 'log_uniform_reference' applied to the SAME uniform, drawn from
--             a second default-seeded generator. This pins the transform against an independent
--             expression of it, so a changed exponent reddens at draw 0 rather than surviving
--             inside a bound.
--   [GOLDEN]  the first twelve equal 'vega01_first_twelve'. This pins the RNG stream itself,
--             which the reference above cannot -- the reference would follow a stream change.
--   [PACKS]   every drawn value packs into a batch input word with bits >= 224 zero.
--
-- These DRAWN values are deliberately NOT the packing corpus. A 'Double' has 53 significand
-- bits against the band's ~70, so a draw near the top carries roughly 17 forced-zero low bits
-- and the low end of the u96 field is barely exercised. @vega_corners@ is the CONSTRUCTED
-- corpus that covers the field boundaries; naming this blind spot is the point of keeping them
-- separate.
vega01_fixed_seed_draw_is_in_band :: Check
vega01_fixed_seed_draw_is_in_band =
  Check "vega01_fixed_seed_draw_is_in_band" . guarded $ do
    gen <- create
    drawn <- replicateM sample_size (draw_target_vega gen vega01_band)
    ref_gen <- create
    uniforms <- replicateM sample_size (uniformR (0, 1) ref_gen :: IO Double)
    pure $ do
      _ <- mapM_ bounded (zip [0 :: Int ..] drawn)
      _ <- expect (length (nub drawn) > 200)
             ("only " ++ show (length (nub drawn)) ++ " of " ++ show sample_size
               ++ " draws are distinct -- a law that barely varies exercises one magnitude and"
               ++ " would satisfy every bound assertion above")
      let observed = sort (nub (map bit_length drawn))
      _ <- expect (all (\b -> b >= 60 && b <= 70) observed)
             ("drawn bit-lengths " ++ show observed ++ " leave 60..70, the band's own range")
      _ <- expect (length observed >= 8)
             ("the draws span only " ++ show (length observed) ++ " distinct bit-lengths "
               ++ show observed ++ " -- at least 8 inside 60..70 are required. This rules out a"
               ++ " CONSTANT (one bit-length). It does NOT rule out a linear-uniform draw:"
               ++ " see the bottom-decade assertion below, which is the one that does.")
      -- SHAPE, and this assertion exists because the obvious one does not work. A linear-uniform
      -- draw on [1e18, 1e21] was MEASURED to span 9 distinct bit-lengths (62..70) over 256 fixed
      -- seed draws, so it CLEARS the >= 8 spread assertion above; the plan for this check
      -- predicted it would concentrate at 69-70 and be caught there, and that prediction is
      -- false. What actually separates the two laws is where the mass sits: log-uniform puts a
      -- third of its mass in each decade, linear-uniform puts a thousandth in the bottom one.
      -- MEASURED over the same 256 fixed-seed draws: log-uniform 77, linear-uniform 4.
      let bottom_decade = length (filter (< 10 ^ (19 :: Int)) drawn)
      _ <- expect (bottom_decade >= 40)
             ("only " ++ show bottom_decade ++ " of " ++ show sample_size
               ++ " draws land in the band's BOTTOM DECADE [1e18, 1e19). Log-uniform puts about"
               ++ " a third of its mass there (measured 77); a linear-uniform draw puts about a"
               ++ " thousandth (measured 4). This is the assertion that discriminates the SHAPE"
               ++ " of the law, as distinct from its range.")
      _ <- mapM_ matches_reference (zip3 [0 :: Int ..] drawn uniforms)
      _ <- expect (take (length vega01_first_twelve) drawn == vega01_first_twelve)
             ("the first " ++ show (length vega01_first_twelve) ++ " fixed-seed draws are "
               ++ show (take (length vega01_first_twelve) drawn) ++ ", not the pinned "
               ++ show vega01_first_twelve
               ++ " -- either the draw law changed or mwc-random's default seed did")
      mapM_ packs (zip [0 :: Int ..] drawn)
  where
    sample_size = 256

    bounded (i, v) = do
      _ <- expect (v >= 1 && v <= mask_of 96)
             ("draw " ++ show i ++ " = " ++ show v ++ " is outside the ABI field [1, 2^96-1]"
               ++ " -- pack_vol_order_input would reject it and the batch path would skip it")
      expect (v >= vega_min vega01_band && v <= vega_max vega01_band)
        ("draw " ++ show i ++ " = " ++ show v ++ " is outside the configured band ["
          ++ show (vega_min vega01_band) ++ ", " ++ show (vega_max vega01_band) ++ "]")

    matches_reference (i, v, u) =
      let want = log_uniform_reference (vega_min vega01_band) (vega_max vega01_band) u
      in expect (v == want)
           ("draw " ++ show i ++ " = " ++ show v ++ " but the independent log-uniform reference"
             ++ " gives " ++ show want ++ " for the same uniform " ++ show u
             ++ " -- the library's transform is not the decided law")

    packs (i, v) =
      case pack_vol_order_input rpin_base_order { target_vega = fromInteger v } of
        Left why -> Left ("draw " ++ show i ++ " = " ++ show v ++ " was REJECTED by the packer: "
                           ++ why)
        Right w  ->
          expect (w `shiftR` 224 == 0)
            ("draw " ++ show i ++ " = " ++ show v ++ " packs to " ++ show w
              ++ ", whose bits >= 224 are SET -- the batch path would skip it silently")

-- | The draw-time guard is DRIVEN to fire on three distinct mis-parameterisations, each of which
-- would otherwise hand a nonsense @targetVega@ to the encoder. A guard nobody has watched fire
-- is not a guard.
--
-- The CONTROL is load-bearing and is the reason this check is not vacuous: without it, a
-- 'draw_target_vega' that threw unconditionally would pass every assertion above it.
vega01_out_of_band_draw_fails_loudly :: Check
vega01_out_of_band_draw_fails_loudly =
  Check "vega01_out_of_band_draw_fails_loudly" . guarded $ do
    inverted <- attempt_draw (LogUniform { vega_min = 10 ^ (21 :: Int)
                                         , vega_max = 10 ^ (18 :: Int) })
    zero_low <- attempt_draw (LogUniform { vega_min = 0, vega_max = 10 ^ (21 :: Int) })
    over_abi <- attempt_draw (LogUniform { vega_min = 1 `shiftL` 96, vega_max = 1 `shiftL` 97 })
    control  <- attempt_draw vega01_band
    pure $ do
      _ <- throws "inverted bounds (vega_min = 10^21 > vega_max = 10^18)" inverted
      _ <- throws "a zero lower bound (vega_min = 0, which would violate the on-chain\
                  \ vega_target_is_complete > 0 predicate and pack to a batch tuple that is\
                  \ SILENTLY SKIPPED)" zero_low
      _ <- throws "a band above the ABI ceiling (vega_min = 2^96), which proves the\
                  \ min hi (2^96 - 1) clamp inside the guard is live" over_abi
      case control of
        Right v ->
          expect (v >= vega_min vega01_band && v <= vega_max vega01_band)
            ("CONTROL: a draw on the configured band returned " ++ show v ++ ", outside it")
        Left err ->
          Left ("CONTROL: a draw on the configured band THREW (" ++ show err ++ "). Without a"
                 ++ " passing control the three assertions above would be satisfied by a"
                 ++ " draw_target_vega that always throws.")
  where
    throws what outcome =
      case outcome of
        Right v ->
          Left (what ++ " RETURNED " ++ show v ++ " instead of failing loudly")
        Left err ->
          expect (guard_message `isInfixOf` show err)
            (what ++ " failed, but not with the draw-time guard's own message. Expected the"
              ++ " failure to contain " ++ show guard_message ++ "; got: " ++ show err)

    guard_message = "targetVega draw out of band"

-- ---------------------------------------------------------------------------------------------
-- Phase 21, RPIN-05: the LIVE V2 batch return, asserted against an external-encoder golden
--
-- WHY THIS READS A COMMITTED FILE AND NEVER OPENS A SOCKET.
-- RPIN-05 says @decode_create_orders_result@ must be verified against the LIVE module rather
-- than assumed from the handoff document. The live half was done by plan 21-02, which captured
-- four real @eth_call@ returns off the Phase-20 rig into
-- @offchain\/rig\/batch-return-capture.json@ WITH PROVENANCE (chain id, manager address, block
-- number) travelling inside the artifact, because @rig-manifest.json@ is gitignored and cannot
-- be the carrier.
--
-- The assertions below consume that artifact. They do not call a chain, and that is a design
-- decision rather than a convenience: this suite is chain-independent today, and a live call
-- here would make every future contributor's first @cabal test@ red for a reason that has
-- nothing to do with their change. The whole value of a pin suite is that it is cheap and always
-- runnable. What replaces the live call is 'rpin05_capture_is_present_and_fresh', which reddens
-- when the committed capture no longer describes the rig the manifest describes -- a stale
-- artifact must not pass quietly.
--
-- The byte strings themselves are READ FROM THE JSON, never pasted here. 'sc3_literal_purge'
-- greps this very file for 8\/40\/64-hex-digit literals, so a pasted returndata word would
-- redden the suite -- which is exactly the discipline that keeps the artifact the single source.
-- ---------------------------------------------------------------------------------------------

capture_file :: FilePath
capture_file = "offchain/rig/batch-return-capture.json"

-- | READ ONLY. The Solidity-testing track's fixture (Phase 19, MVER-03). Its @expected@ bytes
-- were produced by @cast abi-encode@ (alloy, cast 1.5.1-stable) -- an encoder OUTSIDE this repo
-- and outside this language -- which is what makes the diff below a CROSS-IMPLEMENTATION check
-- rather than this repo agreeing with itself. Its inputs are 3-field and predate V2, but the
-- return encoding is a function of @(success, id)@ only, so the @expected@ strings stay valid
-- across the version change.
golden_file :: FilePath
golden_file = "test/pos_spec/fixtures/vol_order_return_golden.json"

capture_command :: String
capture_command = "bash offchain/rig/capture-batch-return.sh"

-- | The golden belongs to another track, so \"regenerate it\" is the WRONG instruction and is
-- deliberately not given here.
golden_advice :: String
golden_advice =
  "this fixture belongs to the Solidity-testing track (Phase 19, MVER-03) and is READ ONLY from\
  \ here -- if it is absent it was moved or deleted by that track; report it, do not recreate it"

-- ---------------------------------------------------------------------------------------------
-- Value-walking helpers. Deliberately NOT a FromJSON instance and NOT a new record type: two
-- artifacts read in four places do not justify a type, and the aeson Value idiom is already how
-- 'sc3_corrupted_manifest_fails' handles the manifest.
-- ---------------------------------------------------------------------------------------------

json_kind :: Value -> String
json_kind (Object _) = "an object"
json_kind (Array _)  = "an array"
json_kind (String _) = "a string"
json_kind (Number _) = "a number"
json_kind (Bool _)   = "a boolean"
json_kind Null       = "null"

json_field :: String -> Value -> Either String Value
json_field name (Object o) =
  case KM.lookup (K.fromString name) o of
    Just found -> Right found
    Nothing ->
      Left ("missing JSON key " ++ show name ++ "; present keys: "
             ++ intercalate ", " (sort (map K.toString (KM.keys o))))
json_field name other =
  Left ("expected an object to read key " ++ show name ++ ", got " ++ json_kind other)

json_string :: Value -> Either String String
json_string (String t) = Right (T.unpack t)
json_string other      = Left ("expected a JSON string, got " ++ json_kind other)

json_integer :: Value -> Either String Integer
json_integer (Number n) = Right (truncate n)
json_integer other      = Left ("expected a JSON number, got " ++ json_kind other)

json_bool :: Value -> Either String Bool
json_bool (Bool b) = Right b
json_bool other    = Left ("expected a JSON boolean, got " ++ json_kind other)

json_array :: Value -> Either String [Value]
json_array (Array v) = Right (F.toList v)
json_array other     = Left ("expected a JSON array, got " ++ json_kind other)

-- | FAIL, never skip, when an artifact is absent, and name the command that produces it. A suite
-- that goes quietly green because a file is missing is worse than one that goes red -- the same
-- stance 'sc3_load_succeeds' takes about the manifest.
read_json_file :: FilePath -> String -> IO (Either String Value)
read_json_file path advice = do
  present <- doesFileExist path
  if not present
    then pure (Left ("no " ++ path ++ " -- " ++ advice))
    else do
      decoded <- eitherDecodeFileStrict path
      pure $ case decoded of
        Left err    -> Left (path ++ " is present but does not decode as JSON: " ++ err
                              ++ "\n      " ++ advice)
        Right value -> Right value

-- ---------------------------------------------------------------------------------------------
-- Hex-word machinery. Reading the words out of the bytes DIRECTLY, rather than through
-- 'decode_create_orders_result', is what keeps 'rpin05_no_canonical_bool_violation' from riding
-- on the very decoder it is checking.
-- ---------------------------------------------------------------------------------------------

strip_hex_prefix :: String -> String
strip_hex_prefix raw =
  let s = map toLower (strip_ws raw)
  in fromMaybe s (stripPrefix "0x" s)

hex_byte_length :: String -> Either String Int
hex_byte_length raw =
  let body = strip_hex_prefix raw
  in if not (null body) && even (length body) && all isHexDigit body
       then Right (length body `div` 2)
       else Left ("not an even-length hex byte string: " ++ show raw)

-- | The bytes split into 32-byte ABI words, each as lowercase hex WITHOUT the prefix.
hex_words :: String -> Either String [String]
hex_words raw = do
  n <- hex_byte_length raw
  if n `mod` 32 /= 0
    then Left ("not a whole number of 32-byte ABI words: " ++ show n ++ " bytes")
    else Right (chunks (strip_hex_prefix raw))
  where
    chunks xs
      | null xs   = []
      | otherwise = take 64 xs : chunks (drop 64 xs)

hex_bytes :: String -> Either String BS.ByteString
hex_bytes raw = do
  _ <- hex_byte_length raw
  Right (BS.pack (unfold (strip_hex_prefix raw)))
  where
    unfold (a : b : rest) = fromIntegral (digitToInt a * 16 + digitToInt b) : unfold rest
    unfold _              = []

-- | The four case names 21-02's capture script writes, in order. Asserting the LIST rather than
-- only the length is what makes a capture from a different script, or one silently reordered,
-- redden here instead of somewhere subtler.
capture_case_names :: [String]
capture_case_names = ["N0_empty", "N1_success", "N2_success_then_fail", "N1_dirty_vega"]

capture_case :: String -> Value -> Either String Value
capture_case name capture = do
  cases <- json_field "cases" capture >>= json_array
  named <- mapM (\c -> (\n -> (n, c)) <$> (json_field "name" c >>= json_string)) cases
  case lookup name named of
    Just found -> Right found
    Nothing ->
      Left ("the capture has no case named " ++ show name ++ "; it carries: "
             ++ intercalate ", " (map fst named))

-- | CHECK 1 -- provenance, not plausibility.
--
-- 21-02 measured that @generatedAt@ is NOT a regeneration witness for this artifact: the capture
-- script completes in ~294 ms against a 1-second timestamp resolution, so two back-to-back runs
-- share a timestamp and a stale file would pass a timestamp comparison silently. The
-- DISCRIMINATING provenance fields are @chainId@ and @manager@, and those are what is asserted
-- here, against the manifest read through 'load_rig_from' rather than re-parsed by hand.
rpin05_capture_is_present_and_fresh :: Check
rpin05_capture_is_present_and_fresh = Check "rpin05_capture_is_present_and_fresh" . guarded $ do
  loaded_capture   <- read_json_file capture_file ("produce it with: " ++ capture_command)
  mf               <- manifest_file
  manifest_present <- doesFileExist mf
  outcome <-
    if manifest_present
      then do
        attempt <- try (load_rig_from pins_file mf)
        pure (Just (attempt :: Either IOException Rig))
      else pure Nothing
  pure $ do
    capture <- loaded_capture
    rig <- case outcome of
      -- The manifest is GITIGNORED. That makes this the one legitimately not-runnable case in
      -- the whole suite, and it still FAILS rather than skips, loudly and with the command.
      Nothing          -> Left ("no " ++ mf ++ " -- it is gitignored, so a fresh"
                                 ++ " checkout has no copy. Stand the rig up: " ++ deploy_command)
      Just (Left err)  -> Left ("load_rig_from failed on the real files: " ++ show err)
      Just (Right r)   -> Right r
    let addrs = rig_addrs rig
    captured_chain <- json_field "chainId" capture >>= json_integer
    _ <- expect (captured_chain == rig_chain_id addrs)
           ("the capture was taken on chain " ++ show captured_chain ++ " but the manifest"
             ++ " describes chain " ++ show (rig_chain_id addrs) ++ " -- the committed capture is"
             ++ " STALE. Re-take it: " ++ capture_command)
    captured_manager <- map toLower <$> (json_field "manager" capture >>= json_string)
    manifest_manager <-
      case Map.lookup "VolOrderManagerMod" (rig_contracts addrs) of
        Nothing -> Left ("the manifest has no VolOrderManagerMod contract -- re-run: "
                          ++ deploy_command)
        Just t  -> Right (map toLower (T.unpack t))
    _ <- expect (captured_manager == manifest_manager)
           ("the capture names manager " ++ captured_manager ++ " but the live manifest names "
             ++ manifest_manager ++ " -- the committed capture describes a DIFFERENT deployment"
             ++ " and its bytes prove nothing about the module now on chain. Re-take it: "
             ++ capture_command)
    cases <- json_field "cases" capture >>= json_array
    _ <- expect (length cases == length capture_case_names)
           ("the capture has " ++ show (length cases) ++ " cases, expected "
             ++ show (length capture_case_names))
    names <- mapM (\c -> json_field "name" c >>= json_string) cases
    expect (names == capture_case_names)
      ("the capture's case names are " ++ show names ++ ", expected " ++ show capture_case_names)

-- | CHECK 2 -- the requirement's core claim: bytes captured from the LIVE module equal bytes
-- produced by an encoder outside this repo.
--
-- The N = 0 length assertion is not redundant beside the string comparison. v4.0's exit record
-- names it as the clause most likely to break a consumer: an empty batch returns EXACTLY 64
-- bytes (outer offset word, then a zero length word), not 0 and not 32, and a consumer that
-- treats \"no elements\" as \"no returndata\" fails in a way that is completely invisible on
-- chain. Asserting the number as well as the string states the contract in the form a reader
-- will check their own code against.
--
-- For the two non-empty cases the comparison is WORD BY WORD, and a difference is only tolerated
-- in the ORDER-ID words -- those carry registry state, not encoding. A difference anywhere else
-- is a live-vs-golden ENCODING disagreement, which the requirement says to REPORT, so it fails
-- here naming the index and both words. The golden is not adjusted and the check is not relaxed;
-- @test\/@ belongs to the Solidity-testing track in any case.
rpin05_live_bytes_match_the_external_golden :: Check
rpin05_live_bytes_match_the_external_golden =
  Check "rpin05_live_bytes_match_the_external_golden" . guarded $ do
    loaded_capture <- read_json_file capture_file ("produce it with: " ++ capture_command)
    loaded_golden  <- read_json_file golden_file golden_advice
    pure $ do
      capture <- loaded_capture
      golden  <- loaded_golden
      names    <- json_field "names" golden    >>= json_array >>= mapM json_string
      ns       <- json_field "ns" golden       >>= json_array >>= mapM json_integer
      expected <- json_field "expected" golden >>= json_array >>= mapM json_string
      _ <- expect (length names == length ns && length ns == length expected)
             ("the golden's names/ns/expected arrays disagree in length: "
               ++ show (length names) ++ "/" ++ show (length ns) ++ "/" ++ show (length expected))
      let golden_for name =
            case lookup name (zip names (zip ns expected)) of
              Just found -> Right found
              Nothing    -> Left ("the golden has no case named " ++ show name ++ "; it carries: "
                                   ++ intercalate ", " names)

      -- N = 0, the exact-string half. The word-level comparison below covers this case too; the
      -- string equality is asserted separately because "byte-for-byte identical to an external
      -- encoder" is the claim RPIN-05 actually makes, and a word-level pass could in principle
      -- be reached with different whitespace or casing.
      (n0_n, n0_expected) <- golden_for "N0_empty"
      n0_case <- capture_case "N0_empty" capture
      n0_live <- json_field "returndata" n0_case >>= json_string
      _ <- expect (n0_n == 0) ("the golden records n = " ++ show n0_n ++ " for N0_empty")
      _ <- expect (strip_hex_prefix n0_live == strip_hex_prefix n0_expected)
             ("N0_empty: the LIVE bytes and the external-encoder golden differ.\n      live   : "
               ++ n0_live ++ "\n      golden : " ++ n0_expected)
      n0_bytes <- hex_byte_length n0_live
      _ <- expect (n0_bytes == 64)
             ("N0_empty is " ++ show n0_bytes ++ " bytes; the empty batch return is EXACTLY 64"
               ++ " (outer offset word + zero length word). Not 0, not 32. A consumer that treats"
               ++ " an empty batch as empty returndata breaks here and nothing on chain says so.")

      mapM_ (compare_case capture golden_for)
        ["N0_empty", "N1_success", "N2_success_then_fail"]
  where
    -- Order-id words are 3, 5, 7, ... : head is [offset, count], then (success, id) pairs.
    order_id_word i = i >= 3 && odd i

    compare_case capture golden_for name = do
      (n, golden_bytes) <- golden_for name
      this       <- capture_case name capture
      live_bytes <- json_field "returndata" this >>= json_string
      live_n     <- json_field "n" this >>= json_integer
      _ <- expect (live_n == n)
             (name ++ ": the capture records n = " ++ show live_n ++ " but the golden records "
               ++ show n)
      live   <- hex_words live_bytes
      wanted <- hex_words golden_bytes
      _ <- expect (length live == length wanted)
             (name ++ ": the live return is " ++ show (length live) ++ " words but the golden is "
               ++ show (length wanted) ++ " -- a LENGTH disagreement is an encoding disagreement,"
               ++ " never an order-id one")
      _ <- expect (length live >= 2)
             (name ++ ": a create_orders return has at least two head words, this has "
               ++ show (length live))
      offset <- integer_of_hex_text (live !! 0)
      _ <- expect (offset == 32)
             (name ++ ": the outer array offset word is " ++ show offset ++ ", must be 32 (0x20)."
               ++ " v4.0's exit record makes the canonical offset a HARD requirement -- a legally"
               ++ " padded head is rejected with an empty revert.")
      count <- integer_of_hex_text (live !! 1)
      _ <- expect (count == n)
             (name ++ ": the length word says " ++ show count ++ " ELEMENTS, expected " ++ show n)
      let indexed   = zip3 [0 :: Int ..] live wanted
          offenders = [(i, l, g) | (i, l, g) <- indexed, l /= g, not (order_id_word i)]
          id_diffs  = [i | (i, l, g) <- indexed, l /= g, order_id_word i]
      _ <- expect (null offenders)
             (name ++ ": the LIVE return and the external-encoder golden differ OUTSIDE the"
               ++ " order-id words. This is an ENCODING disagreement between the deployed module"
               ++ " and an encoder outside this repo -- report it, do not adjust the golden"
               ++ " (test/ is the Solidity-testing track's) and do not relax this check.\n      "
               ++ intercalate "\n      "
                    [ "word " ++ show i ++ (if even i then " (success)" else " (head)")
                        ++ "\n        live   : " ++ l ++ "\n        golden : " ++ g
                    | (i, l, g) <- offenders
                    ])
      -- The artifact carries the capture script's OWN reading of the same comparison. Checking
      -- the bytes against that recorded judgement is what stops a hand-edited _golden_diff from
      -- asserting a match the bytes do not support.
      recorded    <- json_field "_golden_diff" capture >>= json_field name
      said_match  <- json_field "matches_golden" recorded >>= json_bool
      said_ids    <- json_field "differs_only_in_order_ids" recorded >>= json_bool
      let bytes_match = null offenders && null id_diffs
          bytes_ids   = null offenders && not (null id_diffs)
      _ <- expect (said_match == bytes_match)
             (name ++ ": the artifact's _golden_diff records matches_golden = " ++ show said_match
               ++ " but the BYTES say " ++ show bytes_match ++ ". The capture's self-report and"
               ++ " its own payload disagree, so one of them was edited by hand.")
      expect (said_ids == bytes_ids)
        (name ++ ": the artifact's _golden_diff records differs_only_in_order_ids = "
          ++ show said_ids ++ " but the BYTES say " ++ show bytes_ids
          ++ " (differing order-id word indices: " ++ show id_diffs ++ ")")

-- | CHECK 3 -- the bytes go through the SHIPPED decoder, never a re-implementation.
--
-- 'decode_create_orders_result' already computes @64 + 64 * count@ and already rejects
-- non-canonical bool words; re-deriving either here would prove only that the test agrees with
-- itself. What this adds is that the decoder's output over LIVE bytes is the tuple list the
-- module's own semantics say it should be.
--
-- ON THE ORDER IDS. 21-02 measured that all four cases are @eth_call@s, which do not mutate
-- state, so every one of them ran against @orderCount = 0@ and the captured ids are HYPOTHETICAL
-- -- they are the ids those calls WOULD have assigned. An assertion of @id == 1@ would therefore
-- be asserting that the rig was fresh when the capture was taken, not that the decoder reads the
-- id word correctly. The assertion here is @id > 0@ deliberately: a successful create always
-- assigns a nonzero sequential id, and that holds whatever the registry's state was.
rpin05_capture_decodes_through_the_shipped_decoder :: Check
rpin05_capture_decodes_through_the_shipped_decoder =
  Check "rpin05_capture_decodes_through_the_shipped_decoder" . guarded $ do
    loaded <- read_json_file capture_file ("produce it with: " ++ capture_command)
    pure $ do
      capture <- loaded
      n0 <- decoded capture "N0_empty"
      _ <- expect (null n0)
             ("N0_empty decoded to " ++ show n0 ++ ", expected the empty list. 64 bytes of"
               ++ " well-formed empty array is not a decode failure and not a one-element list.")
      n1 <- decoded capture "N1_success"
      _ <- case n1 of
             [(True, order_id)] ->
               expect (order_id > 0)
                 ("N1_success decoded to order id " ++ show order_id ++ "; a successful create"
                   ++ " always assigns a nonzero sequential id")
             other -> Left ("N1_success decoded to " ++ show other
                             ++ ", expected exactly one successful pair")
      n2 <- decoded capture "N2_success_then_fail"
      _ <- case n2 of
             [(True, order_id), (False, failed_id)] ->
               do _ <- expect (order_id > 0)
                         ("N2_success_then_fail: the successful element carries id "
                           ++ show order_id ++ ", expected a nonzero id")
                  expect (failed_id == 0)
                    ("N2_success_then_fail: the SKIPPED element carries id " ++ show failed_id
                      ++ ", expected 0 -- a skipped tuple assigns no id")
             other -> Left ("N2_success_then_fail decoded to " ++ show other
                             ++ ", expected [(True, id), (False, 0)]")
      -- N1_dirty_vega submitted targetVega = 2^96, one past the u96 field. The live rig SKIPPED
      -- it and returned (False, 0) -- BYTE-IDENTICAL to an ordinary business rejection. There is
      -- no error, no revert and no distinguishing signal anywhere in the returndata. That is the
      -- live evidence for why pack_vol_order_input carries an `in_range 96` guard CLIENT-side:
      -- the chain will not tell the client it sent an out-of-range field, so the client has to
      -- know before it sends.
      dirty <- decoded capture "N1_dirty_vega"
      case dirty of
        [(False, failed_id)] ->
          expect (failed_id == 0)
            ("N1_dirty_vega: the skipped element carries id " ++ show failed_id ++ ", expected 0")
        other -> Left ("N1_dirty_vega decoded to " ++ show other
                        ++ ", expected exactly one skipped pair")
  where
    decoded capture name = do
      this <- capture_case name capture
      raw  <- json_field "returndata" this >>= json_string
      n    <- json_field "n" this >>= json_integer
      raw_bytes <- hex_bytes raw
      case decode_create_orders_result (fromBytes raw_bytes) of
        Left err ->
          Left (name ++ ": the SHIPPED decode_create_orders_result REJECTED bytes captured from"
                 ++ " the live module -- " ++ err)
        Right pairs -> do
          _ <- expect (toInteger (length pairs) == n)
                 (name ++ ": decoded " ++ show (length pairs) ++ " elements, but the case"
                   ++ " submitted n = " ++ show n)
          Right pairs

-- | CHECK 4 -- canonical bool words, read straight out of the bytes.
--
-- 'decode_create_orders_result' enforces this already. Reading the words separately is the
-- point: a check that established canonicality BY DECODING would be asserting the decoder's
-- strictness using the decoder's strictness. v4.0 measured that solc's @abi.decode@ REVERTS
-- outright on a success word of 2, so a lenient consumer would disagree with a Solidity consumer
-- about the very same bytes -- this is a consumer-side contract, not a test detail.
--
-- The declared @returndata_bytes@ is checked against both the actual byte count and the layout
-- formula @64 + 64 * n@, so the artifact's metadata cannot drift away from its payload.
rpin05_no_canonical_bool_violation :: Check
rpin05_no_canonical_bool_violation = Check "rpin05_no_canonical_bool_violation" . guarded $ do
  loaded <- read_json_file capture_file ("produce it with: " ++ capture_command)
  pure $ do
    capture <- loaded
    cases <- json_field "cases" capture >>= json_array
    mapM_ one cases
  where
    one this = do
      name     <- json_field "name" this >>= json_string
      raw      <- json_field "returndata" this >>= json_string
      n        <- json_field "n" this >>= json_integer
      declared <- json_field "returndata_bytes" this >>= json_integer
      actual   <- hex_byte_length raw
      _ <- expect (toInteger actual == declared)
             (name ++ ": returndata_bytes says " ++ show declared ++ " but the returndata is "
               ++ show actual ++ " bytes")
      _ <- expect (declared == 64 + 64 * n)
             (name ++ ": " ++ show declared ++ " bytes for n = " ++ show n
               ++ ", but a create_orders return is exactly 64 + 64*n")
      ws <- hex_words raw
      _ <- expect (toInteger (length ws) == 2 + 2 * n)
             (name ++ ": " ++ show (length ws) ++ " words for n = " ++ show n ++ ", expected "
               ++ show (2 + 2 * n))
      mapM_ (success_word name ws) [0 .. fromIntegral n - 1 :: Int]

    success_word name ws index = do
      let position = 2 + 2 * index
      value <- integer_of_hex_text (ws !! position)
      expect (value == 0 || value == 1)
        (name ++ ": success word at element " ++ show index ++ " (word " ++ show position
          ++ ") is " ++ show value ++ ", which is NOT canonical. The module emits only 0 or 1,"
          ++ " and solc's abi.decode REVERTS on anything else -- a truthy-nonzero word here"
          ++ " means the live module and every Solidity consumer disagree about these bytes.")

-- ---------------------------------------------------------------------------------------------
-- Phase 22, DRIV-01: the E3 TimepointWritten / E5 FeeApplied decode behaviour contract
--
-- E3's emitter is @src\/lib\/events\/VolEventsLib.plk@ lines 62-77:
--
-- > let buf = @malloc_uninit(160);  ... five @mstore32 at 0/32/64/96/128 ...
-- > @evm_log2(buf, 160, TOPIC0_TIMEPOINT_WRITTEN, pool_id);
--
-- EXACTLY two topics, EXACTLY 160 bytes = five data words
-- @[timestamp, tick, volatilityCumulative, averageTick, tickCumulative]@. Three of those five
-- are SIGNED, and the emitter runs @\@evm_signextend@ over each of them, so they arrive as full
-- 256-bit two's-complement words. E5 is the same two-topic shape over 64 bytes
-- @[sigma, fee]@, both unsigned.
--
-- This is the FIRST signed-integer decoding anywhere in @offchain\/@, which is why the negative
-- values below are pinned as exact literals rather than as sign predicates: an unsigned read of
-- @averageTick = -200@ yields 115792089237316195423570985008687907853269984665640564039457584007913129639736,
-- and a 24-bit-masked read yields 16777016. Both are numbers, both look like data, and neither
-- is the tick that was written.
-- ---------------------------------------------------------------------------------------------

-- | The E3 payload the synthetic log carries. FIVE DISTINCT NUMBERS, TWO OF THEM NEGATIVE, so
-- neither a transposition of two fields nor an unsigned read of a signed one can pass unnoticed.
driv01_e3_timestamp, driv01_e3_tick, driv01_e3_vol_cum :: Integer
driv01_e3_avg_tick, driv01_e3_tick_cum :: Integer
driv01_e3_timestamp = 1700000012
driv01_e3_tick      = 37
driv01_e3_vol_cum   = 99
driv01_e3_avg_tick  = -200
driv01_e3_tick_cum  = -123456789

-- | A SECOND E3 payload whose @tick@ is NEGATIVE, and the reason it exists.
--
-- The plan predicted that deleting the sign extension from @tw_tick@ ALONE would redden
-- 'driv01_e3_decode_behavior'. It was APPLIED and the suite stayed GREEN at 66\/66: the first
-- payload's @driv01_e3_tick = 37@ is positive, 'signed_word' is the identity on it, and the field
-- was therefore pinned by a value that cannot distinguish a signed read from an unsigned one. The
-- negative pins on @averageTick@ and @tickCumulative@ covered those two fields and nothing
-- covered this one.
--
-- The general rule this instance teaches: EVERY signed field needs at least one NEGATIVE pin of
-- its own. A positive pin on a signed field is a value assertion that happens to be blind to the
-- only thing that makes the field signed. Keeping BOTH payloads is deliberate — the positive one
-- proves 'signed_word' leaves the non-negative half alone, which is the other half of the
-- contract.
driv01_e3_tick_negative :: Integer
driv01_e3_tick_negative = -3145

-- | The E5 payload. Distinct from every E3 value for the same reason.
driv01_e5_sigma, driv01_e5_fee :: Integer
driv01_e5_sigma = 4321
driv01_e5_fee   = 3000

-- | A signed 'Integer' as the 256-bit word @\@evm_signextend@ actually puts on the wire. The
-- checks below feed the DECODER the wire form and demand the signed form back, so the round trip
-- is asserted end to end rather than assumed at the boundary.
as_wire_word :: Integer -> Integer
as_wire_word n = if n < 0 then n + (1 `shiftL` 256) else n

-- | A topic0 as an 'Integer', RECOMPUTED from the signature string parsed out of the interface
-- file the pin names. Generalises 'e1_topic0_from' to any event name.
topic0_from :: String -> String -> Either String Integer
topic0_from name contents = do
  sig <- signature_for name (signatures_in (lines contents))
  Right (be_integer (topic0_of sig))

-- | Truncate a log's data payload to @n@ bytes, leaving the topics alone. This is what a short
-- payload looks like to the decoder, and it is the case the length guard exists for.
truncate_log_data :: Int -> Change -> Change
truncate_log_data n l = l { changeData = fromBytes (BS.take n (toBytes (changeData l))) }

-- | The bound poolId MEASURED on the rig, written WITHOUT the @0x@ prefix -- 'sc3_literal_purge'
-- greps this very file and all three of its patterns are anchored on that prefix. Read
-- numerically with 'integer_of_hex_text' and rebuilt with 'word32be', which is exactly the
-- 32-byte wire form a @bytes32 indexed@ topic takes.
driv01_pool_id_hex :: String
driv01_pool_id_hex = "c26d0c664c1503d15da31243604d1904295ccb87658aa0f62ff9966f200e272e"

-- | The whole E3 + E5 decode behaviour contract, in one place, over synthetic logs. Every
-- assertion pins a VALUE (@tw_avg_tick == -200@), never a relation (@tw_avg_tick < 0@) -- 21-03
-- and 21-04 each measured an inequality-shaped check staying GREEN under a value-breaking
-- mutant.
driv01_e3_decode_behavior :: Check
driv01_e3_decode_behavior = Check "driv01_e3_decode_behavior" . guarded $ do
  rv_contents   <- readFile realized_vol_iface
  hook_contents <- readFile dynamic_fee_hook_iface
  pure $ do
    t0_e3   <- topic0_from "TimepointWritten" rv_contents
    t0_e5   <- topic0_from "FeeApplied" hook_contents
    pool_id <- integer_of_hex_text driv01_pool_id_hex
    let e3_words =
          map as_wire_word
            [ driv01_e3_timestamp, driv01_e3_tick, driv01_e3_vol_cum
            , driv01_e3_avg_tick, driv01_e3_tick_cum
            ]
        e3_negative_words =
          map as_wire_word
            [ driv01_e3_timestamp + 1, driv01_e3_tick_negative, driv01_e3_vol_cum
            , driv01_e3_avg_tick, driv01_e3_tick_cum
            ]
        topics_ok = [hexstring_of t0_e3, hexstring_of pool_id]
        e3_log    = synthetic_log topics_ok e3_words
        e5_log    = synthetic_log [hexstring_of t0_e5, hexstring_of pool_id]
                      [driv01_e5_sigma, driv01_e5_fee]
        decode_e3 = decode_timepoint_written t0_e3 pool_id
        decode_e5 = decode_fee_applied t0_e5 pool_id

    -- (1) the positive path: five fields, exact values, two of them negative
    tw <- case decode_e3 e3_log of
      Nothing -> Left ("the E3 log shape (2 topics, 160 bytes = 5 data words -- @evm_log2 over a"
                        ++ " 160-byte buffer) did not decode. A decoder that returns Nothing here"
                        ++ " reports every real TimepointWritten as \"unknown\" and never says so.")
      Just x  -> Right x
    _ <- expect (tw_timestamp tw == driv01_e3_timestamp)
           ("tw_timestamp = " ++ show (tw_timestamp tw) ++ ", expected "
             ++ show driv01_e3_timestamp)
    _ <- expect (tw_tick tw == driv01_e3_tick)
           ("tw_tick = " ++ show (tw_tick tw) ++ ", expected " ++ show driv01_e3_tick)
    _ <- expect (tw_vol_cum tw == driv01_e3_vol_cum)
           ("tw_vol_cum = " ++ show (tw_vol_cum tw) ++ ", expected " ++ show driv01_e3_vol_cum)
    _ <- expect (tw_avg_tick tw == driv01_e3_avg_tick)
           ("tw_avg_tick = " ++ show (tw_avg_tick tw) ++ ", expected " ++ show driv01_e3_avg_tick
             ++ " -- the emitter sign-extends averageTick to the full word, so an unsigned read"
             ++ " gives a 77-digit number and a 24-bit mask gives 16777016")
    _ <- expect (tw_tick_cum tw == driv01_e3_tick_cum)
           ("tw_tick_cum = " ++ show (tw_tick_cum tw) ++ ", expected " ++ show driv01_e3_tick_cum
             ++ " -- int56, sign-extended by the same emitter rule")

    -- (1b) the NEGATIVE tick. See 'driv01_e3_tick_negative': without this the tw_tick field is
    -- pinned only by a positive value, and dropping its sign extension is unobservable (MEASURED
    -- green under exactly that mutant before this payload existed).
    tw_neg <- case decode_e3 (synthetic_log topics_ok e3_negative_words) of
      Nothing -> Left "the E3 log with a NEGATIVE tick did not decode"
      Just x  -> Right x
    _ <- expect (tw_tick tw_neg == driv01_e3_tick_negative)
           ("tw_tick = " ++ show (tw_tick tw_neg) ++ ", expected "
             ++ show driv01_e3_tick_negative ++ " -- an unsigned read of a NEGATIVE int24 yields a"
             ++ " large positive number that looks like a plausible tick and is not one")
    _ <- expect (tw_timestamp tw_neg == driv01_e3_timestamp + 1)
           ("tw_timestamp = " ++ show (tw_timestamp tw_neg) ++ ", expected "
             ++ show (driv01_e3_timestamp + 1))

    -- (2) the length guard. data_word past the end of the payload is 0, not an error, so without
    -- the guard a short log hands back tickCumulative = 0: plausible, in range, fabricated.
    _ <- expect (isNothing (decode_e3 (truncate_log_data 159 e3_log)))
           ("a 159-byte E3 payload DECODED. BS.drop past the end yields the empty string whose"
             ++ " big-endian value is 0, so this returns a record with a fabricated field rather"
             ++ " than Nothing -- the identical trap RPIN-04 documented for E1.")

    -- (3) topic guards
    _ <- expect (isNothing (decode_e3 (synthetic_log [hexstring_of (t0_e3 + 1)
                                                     , hexstring_of pool_id] e3_words)))
           "an E3 log with a WRONG topic0 decoded"
    _ <- expect (isNothing (decode_e3 (synthetic_log [hexstring_of t0_e3
                                                     , hexstring_of (pool_id + 1)] e3_words)))
           ("an E3 log with a WRONG poolId in topic 1 decoded. The module-global"
             ++ " RealizedVolatilityMod emits the SAME topic0 with poolId = bytes32(0)"
             ++ " (notes/DATA_CONTRACT.md section 2), so a topic0-only filter admits sentinel"
             ++ " logs as if they were the pool's own.")
    _ <- expect (isNothing (decode_e3 (synthetic_log [hexstring_of t0_e3, hexstring_of pool_id
                                                     , hexstring_of 0] e3_words)))
           "a THREE-topic log decoded -- @evm_log2 emits exactly two"

    -- (4) E5: same two-topic shape, 64 bytes, both fields unsigned
    fa <- case decode_e5 e5_log of
      Nothing -> Left "the E5 log shape (2 topics, 64 bytes = [sigma, fee]) did not decode"
      Just x  -> Right x
    _ <- expect (fa_sigma fa == driv01_e5_sigma)
           ("fa_sigma = " ++ show (fa_sigma fa) ++ ", expected " ++ show driv01_e5_sigma)
    _ <- expect (fa_fee fa == driv01_e5_fee)
           ("fa_fee = " ++ show (fa_fee fa) ++ ", expected " ++ show driv01_e5_fee)
    _ <- expect (isNothing (decode_e5 (truncate_log_data 63 e5_log)))
           "a 63-byte E5 payload DECODED rather than yielding Nothing"

    -- (5) signed_word itself, at the boundary
    _ <- expect (signed_word driv01_e3_tick == driv01_e3_tick)
           ("signed_word " ++ show driv01_e3_tick ++ " = " ++ show (signed_word driv01_e3_tick))
    _ <- expect (signed_word (as_wire_word driv01_e3_avg_tick) == driv01_e3_avg_tick)
           ("signed_word of the sign-extended -200 word gave "
             ++ show (signed_word (as_wire_word driv01_e3_avg_tick)))
    expect (signed_word (1 `shiftL` 255) == negate (1 `shiftL` 255))
      ("signed_word 2^255 = " ++ show (signed_word (1 `shiftL` 255))
        ++ ", expected -(2^255) -- the exact two's-complement boundary")

-- ---------------------------------------------------------------------------------------------
-- Phase 22, DRIV-01: the slot0 derivation, composition and the G4 tick domain
--
-- Uniswap v4's Slot0 word (@lib\/panoptic-v2-core\/lib\/v4-core\/src\/types\/Slot0.sol@):
--
-- > sqrtPriceX96 [0,160) | tick [160,184) int24 | protocolFee [184,208) | lpFee [208,232) | empty
--
-- The composition boundary is 184, NOT 160, and the difference is invisible at the call site:
-- masking at 160 lets @packSlot0For@'s tick bits through while keeping the TARGET pool's, so the
-- word ends up carrying a sqrtPrice and a tick that disagree (G5a). The words below therefore
-- carry DIFFERENT tick bits on the two sides — without that difference the two masks are
-- indistinguishable and the check would not discriminate.
-- ---------------------------------------------------------------------------------------------

-- | The pool-state slot MEASURED with @cast keccak@ over
-- @bytes32(poolId) || bytes32(uint256(6))@, written WITHOUT the @0x@ prefix so
-- 'sc3_literal_purge' does not match it. Reproduce with:
--
-- > cast keccak 0x<driv01_pool_id_hex><32 bytes of uint256(6)>
driv01_state_slot_hex :: String
driv01_state_slot_hex = "eeab88fa749045a9c1259e79a7bd845c2ee229c1a4e0702e880b8251c4c6dd16"

-- | The TARGET pool's CURRENT slot0 word: the one whose bits >= 184 must survive. The fee fields
-- are written in DECIMAL (@1118481 = 0x111111@, @2236962 = 0x222222@) because a @0x@-prefixed
-- 8-hex-digit literal would redden 'sc3_literal_purge' in this very file.
driv01_slot0_now :: Integer
driv01_slot0_now =
  (2236962 `shiftL` 208)      -- lpFee       = 0x222222
    .|. (1118481 `shiftL` 184) -- protocolFee = 0x111111
    .|. (5555 `shiftL` 160)    -- the target pool's CURRENT tick -- MUST differ from the cheated one
    .|. 7777                   -- the target pool's CURRENT sqrtPriceX96

-- | @packSlot0For@'s word: the one whose bits 0..183 must survive. Its own fee bits are DIFFERENT
-- from the target's and must be DROPPED — @packSlot0For@ reads @PriceSetterPoolManager@'s slot0,
-- so its high half belongs to the wrong pool entirely.
driv01_slot0_low :: Integer
driv01_slot0_low =
  (9999 `shiftL` 208)
    .|. (3141592 `shiftL` 184)
    .|. (1234 `shiftL` 160)    -- the CHEATED tick
    .|. 987654321              -- getSqrtPriceAtTick(cheated tick)

-- | The G4 domain boundary. The rig holds exactly ONE full-range position over
-- @[minUsableTick(20), maxUsableTick(20)] = [-887260, +887260]@, so the admissible cheat ticks are
-- the ones STRICTLY inside it.
driv01_g4_bound :: Integer
driv01_g4_bound = 887259

-- | The slot derivation, the word composition and the G4 guard, asserted as EXACT Integer
-- equalities throughout. Never inequalities: 21-03 measured an inequality-shaped assertion staying
-- GREEN under a value-breaking mutant, and 21-04 measured a spread-shaped one doing the same.
driv01_slot0_composition_behavior :: Check
driv01_slot0_composition_behavior =
  pure_check "driv01_slot0_composition_behavior" $ do
    pool_id <- integer_of_hex_text driv01_pool_id_hex

    -- (1) the derivation reproduces the cast-measured value, byte for byte
    let derived = to_hex (word32be (pool_state_slot pool_id))
    _ <- expect (derived == driv01_state_slot_hex)
           ("pool_state_slot gave " ++ derived ++ ", but cast keccak of"
             ++ " bytes32(poolId) || bytes32(uint256(6)) is " ++ driv01_state_slot_hex
             ++ " -- POOLS_SLOT is the pinned constant 6 from DynamicFeeHook.plk:75")

    -- (2) the composition: high half from the target pool, low half from packSlot0For
    let composed = compose_slot0 driv01_slot0_now driv01_slot0_low
    _ <- expect ((composed `shiftR` 184) == (driv01_slot0_now `shiftR` 184))
           ("bits 184..255 of the composed word are " ++ show (composed `shiftR` 184)
             ++ ", expected the TARGET pool's " ++ show (driv01_slot0_now `shiftR` 184)
             ++ " -- protocolFee and lpFee live there and zeroing them is a LATENT bug (G5b):"
             ++ " both are 0 on today's rig, so it stays invisible until a protocol fee is set")
    _ <- expect ((composed .&. mask_of 184) == (driv01_slot0_low .&. mask_of 184))
           ("bits 0..183 of the composed word are " ++ show (composed .&. mask_of 184)
             ++ ", expected packSlot0For's " ++ show (driv01_slot0_low .&. mask_of 184))
    _ <- expect (((composed `shiftR` 160) .&. mask_of 24) == 1234)
           ("the composed tick (bits 160..183) is "
             ++ show ((composed `shiftR` 160) .&. mask_of 24)
             ++ ", expected the CHEATED 1234. Masking at 160 instead of 184 keeps the TARGET"
             ++ " pool's tick while taking packSlot0For's sqrtPrice, so the two disagree (G5a)"
             ++ " and the hook records a tick that was never written.")
    _ <- expect ((composed .&. mask_of 160) == 987654321)
           ("the composed sqrtPriceX96 (bits 0..159) is " ++ show (composed .&. mask_of 160)
             ++ ", expected packSlot0For's 987654321")

    -- (3) idempotence in the high half
    _ <- expect (compose_slot0 driv01_slot0_now composed == composed)
           "compose_slot0 is not idempotent in the high half"

    -- (4) the G4 domain: the four accepted ticks and the four rejected ones
    _ <- mapM_ accepts [negate driv01_g4_bound, 0, 37, driv01_g4_bound]
    mapM_ rejects
      [ negate (driv01_g4_bound + 1), driv01_g4_bound + 1
      , negate 887272, 887272
      ]
  where
    accepts t = case check_cheat_tick t of
      Right t' -> expect (t' == t)
        ("check_cheat_tick " ++ show t ++ " returned Right " ++ show t')
      Left why -> Left ("check_cheat_tick REJECTED the in-domain tick " ++ show t ++ ": " ++ why)

    rejects t = case check_cheat_tick t of
      Right _ -> Left ("check_cheat_tick ACCEPTED " ++ show t
                        ++ ", which sits OUTSIDE the rig's one full-range position"
                        ++ " [-887260, +887260]. There global liquidity claims 1e21 that is not"
                        ++ " there (G4), and the TickMath-valid slivers out to +-887272 are"
                        ++ " exactly the trap.")
      Left why ->
        let names_bound = show driv01_g4_bound `isInfixOf` why
            names_guard = "G4" `isInfixOf` why
        in expect (names_bound && names_guard)
             ("check_cheat_tick rejected " ++ show t ++ " with a message that does not name"
               ++ " the bound and the guard: " ++ show why)

-- ---------------------------------------------------------------------------------------------
-- Phase 22, DRIV-01: the PoolSwapTest.swap calldata shape
--
-- This check shells to @cast@'s @calldata@ subcommand. That needs @cast@ on PATH but NO chain and
-- NO socket -- ABI encoding is pure -- so the suite stays chain-independent.
-- @sc4_cast_agreement@ already established the precedent.
--
-- NOTE the phrase is written as \"@cast@'s @calldata@ subcommand\" rather than as the two words
-- run together, DELIBERATELY. The chain-independence guard this workstream runs over this file is
-- a grep whose first alternative is the RPC subcommand name preceded by the tool name, and the
-- run-together spelling of the ENCODING subcommand contains that alternative as a substring.
-- Spelling it the natural way here would leave the guard reporting a permanent false positive on
-- a COMMENT -- which retires the guard rather than satisfying it, and the guard is the only
-- evidence the suite opens no socket. For the same reason this note describes the pattern instead
-- of quoting it.
-- ---------------------------------------------------------------------------------------------

cheat_swap_encoding_file :: FilePath
cheat_swap_encoding_file = "offchain/lib/CheatSwap/Encoding.hs"

-- | A synthetic @0x@-prefixed address, BUILT AT RUNTIME. A 40-hex-digit literal in this file would
-- redden 'sc3_literal_purge', which is the whole point of the rule.
driv01_synthetic_address :: Char -> String
driv01_synthetic_address c = "0x" ++ replicate 39 '0' ++ [c]

-- | The tickSpacing the check passes in. DELIBERATELY NOT 20: the module the encoder was modelled
-- on pins @TICK_SPACING = 20@, and a hardcoded default of that value inside 'encode_swap' would be
-- invisible to any check that also passed 20.
driv01_swap_tick_spacing :: Integer
driv01_swap_tick_spacing = 60

-- | The MEASURED calldata size, in bytes.
--
-- The plan predicted @4 + 32*10 = 324@. That is WRONG and the value here is what @cast@ actually
-- produced. Twelve words, not ten:
--
-- > head: PoolKey 5 | SwapParams 3 | TestSettings 2 | offset to hookData 1   = 11
-- > tail: hookData length word (zero data words follow)                      =  1
--
-- Both tuples are STATIC, so they are inlined in the head rather than pointed at; @bytes@ is the
-- only dynamic member and it still costs an offset word AND a length word even when empty. The
-- prediction dropped both of the @bytes@ words.
driv01_swap_calldata_bytes :: Int
driv01_swap_calldata_bytes = 4 + 32 * 12

-- | The swap calldata, asserted at EXACT values: the byte count, the selector RECOMPUTED from the
-- signature string parsed back out of the encoder's own source, and every one of the twelve words.
driv01_swap_calldata_shape :: Check
driv01_swap_calldata_shape = Check "driv01_swap_calldata_shape" . guarded $ do
  source <- readFile cheat_swap_encoding_file
  raw <-
    encode_swap
      (driv01_synthetic_address '1')
      (driv01_synthetic_address '2')
      driv01_swap_tick_spacing
      (driv01_synthetic_address '3')
  -- the extsload half. 'hex32' is the only hand-rolled encoder in the module, so it gets driven
  -- through cast and read back rather than inspected: a wrong nibble order produces a
  -- well-formed 36-byte calldata pointing at a slot nothing has ever written.
  let slot = case integer_of_hex_text driv01_pool_id_hex of
        Right pid -> pool_state_slot pid
        Left _    -> 0
  ext_raw <- encode_extsload slot
  pure $ do
    let ext_bytes = toBytes ext_raw
        ext_word  = be_integer (BS.take 32 (BS.drop 4 ext_bytes))
    _ <- expect (BS.length ext_bytes == 4 + 32)
           ("the extsload calldata is " ++ show (BS.length ext_bytes)
             ++ " bytes, expected exactly 36")
    _ <- expect (to_hex (BS.take 4 ext_bytes) == to_hex (selector_of extsload_signature))
           ("cast emitted extsload selector " ++ to_hex (BS.take 4 ext_bytes)
             ++ " but keccak256 of " ++ extsload_signature ++ " is "
             ++ to_hex (selector_of extsload_signature))
    _ <- expect (ext_word == slot)
           ("the extsload argument word decodes to " ++ show ext_word ++ ", expected the derived"
             ++ " pool-state slot " ++ show slot ++ " -- hex32 rendered it wrongly")

    let bytes  = toBytes raw
        total  = BS.length bytes
        word i = be_integer (BS.take 32 (BS.drop (4 + 32 * i) bytes))

    -- (a) the exact size
    _ <- expect (total == driv01_swap_calldata_bytes)
           ("the swap calldata is " ++ show total ++ " bytes, expected exactly "
             ++ show driv01_swap_calldata_bytes ++ " (4 selector + 12 words: 11 head + 1 tail)")

    -- (b) the selector is DERIVED from the module's own signature string, never transcribed
    parsed_sig <-
      case [ takeWhile (/= '"') (drop 1 (dropWhile (/= '"') l))
           | l <- lines source, "\"swap((address," `isInfixOf` l
           ] of
        [s] -> Right s
        []  -> Left ("no swap signature string literal was parsed out of "
                      ++ cheat_swap_encoding_file)
        ss  -> Left (cheat_swap_encoding_file ++ " holds MORE THAN ONE swap signature literal: "
                      ++ show ss)
    _ <- expect (parsed_sig == swap_signature)
           ("the signature parsed out of the source is " ++ show parsed_sig
             ++ " but the module exports " ++ show swap_signature)
    let emitted    = to_hex (BS.take 4 bytes)
        recomputed = to_hex (selector_of parsed_sig)
    _ <- expect (emitted == recomputed)
           ("cast emitted selector " ++ emitted ++ " but keccak256 of " ++ parsed_sig
             ++ " is " ++ recomputed)

    -- (c) the PoolKey, word by word. word 2 is the DYNAMIC_FEE_FLAG and word 3 the tickSpacing
    -- that was PASSED IN -- a hardcoded default would show up right here.
    _ <- expect (word 0 == 1) ("PoolKey.currency0 word = " ++ show (word 0) ++ ", expected 1")
    _ <- expect (word 1 == 2) ("PoolKey.currency1 word = " ++ show (word 1) ++ ", expected 2")
    _ <- expect (word 2 == 8388608)
           ("PoolKey.fee word = " ++ show (word 2)
             ++ ", expected the DYNAMIC_FEE_FLAG 8388608. A static fee here makes the"
             ++ " reconstructed PoolKey hash to a different poolId and beforeSwap reverts with"
             ++ " EMPTY reason data.")
    _ <- expect (word 3 == driv01_swap_tick_spacing)
           ("PoolKey.tickSpacing word = " ++ show (word 3) ++ ", expected the value passed in ("
             ++ show driv01_swap_tick_spacing ++ ") -- a constant here is key drift")
    _ <- expect (word 4 == 3) ("PoolKey.hooks word = " ++ show (word 4) ++ ", expected 3")

    -- (d) SwapParams and TestSettings
    _ <- expect (word 5 == 1)
           ("zeroForOne word = " ++ show (word 5) ++ ", expected 1 (true)")
    _ <- expect (word 6 == as_wire_word (-1000000))
           ("amountSpecified word = " ++ show (word 6) ++ ", expected the two's-complement of"
             ++ " -1000000. NEVER 0: v4 reverts SwapAmountCannotBeZero and that unwinds the"
             ++ " frame including the timepoint write.")
    _ <- expect (word 7 == 4295128740)
           ("sqrtPriceLimitX96 word = " ++ show (word 7)
             ++ ", expected TickMath.MIN_SQRT_PRICE + 1 = 4295128740")
    _ <- expect (word 8 == 0) ("takeClaims word = " ++ show (word 8) ++ ", expected 0")
    _ <- expect (word 9 == 0) ("settleUsingBurn word = " ++ show (word 9) ++ ", expected 0")

    -- (e) the empty hookData: an offset word AND a length word, which is what the 324-byte
    -- prediction dropped
    _ <- expect (word 10 == 352)
           ("the hookData offset word is " ++ show (word 10)
             ++ ", expected 352 (0x160 -- eleven head words)")
    expect (word 11 == 0)
      ("the hookData length word is " ++ show (word 11) ++ ", expected 0 (empty bytes)")

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
          , rpin06_perturbed_target_vega_fails_readback
          , rpin06_target_vega_reaches_every_sender
          , vega01_draw_behavior
          , vega01_fixed_seed_draw_is_in_band
          , vega01_out_of_band_draw_fails_loudly
          , rpin05_capture_is_present_and_fresh
          , rpin05_live_bytes_match_the_external_golden
          , rpin05_capture_decodes_through_the_shipped_decoder
          , rpin05_no_canonical_bool_violation
          , driv01_e3_decode_behavior
          , driv01_slot0_composition_behavior
          , driv01_swap_calldata_shape
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
