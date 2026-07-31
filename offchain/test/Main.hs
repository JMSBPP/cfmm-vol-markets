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
import Data.Bits (shiftR, (.&.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Char (intToDigit, isAlpha, isAlphaNum, isSpace, toLower)
import Data.List (intercalate, isPrefixOf, nub, sort)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, isJust)
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
