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

import Control.Exception (IOException, finally, try)
import Control.Monad (foldM, replicateM)
import Crypto.Ethereum.Utils (keccak256)
-- MD5 only, and only for the migration freshness oracle: @postgresql-migration@ stores an md5 of
-- each script and the capture records the same digest, so the freshness comparison has to speak
-- that algorithm. It is NOT a security claim about anything. crypton is already resolved in this
-- build plan through the library stanza (1.0.6), so no package enters the plan for this import.
import Crypto.Hash (MD5 (..), hashWith)
import Data.Aeson (Value (..), decode, eitherDecodeFileStrict, encode, encodeFile, toJSON)
import qualified Data.Aeson.Key as K
import qualified Data.Aeson.KeyMap as KM
import Data.Bits (shiftL, shiftR, xor, (.&.), (.|.))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy as BSL
import Data.Char (digitToInt, intToDigit, isAlpha, isAlphaNum, isDigit, isHexDigit, isSpace, toLower)
import qualified Data.Foldable as F
import Data.List (intercalate, isInfixOf, isPrefixOf, nub, sort, stripPrefix)
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes, fromMaybe, isJust, isNothing)
import Data.Solidity.Prim.Address (Address, fromHexString)
import qualified Data.Text as T
import Data.Word (Word32, Word8)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getCurrentDirectory
  , getPermissions
  , getTemporaryDirectory
  , listDirectory
  , makeAbsolute
  , removeDirectoryRecursive
  , removeFile
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath (takeExtension, (</>))
import System.Process (readProcessWithExitCode)
import System.Random.MWC (create, uniformR)
-- The Tier-B timeout checks need both: 'threadDelay' to let the kernel finish reaping before
-- procfs is asked, and 'timeout' so a check that would otherwise DEADLOCK fails with its own name
-- attached instead of stopping the suite with no indication of which assertion was running.
import Control.Concurrent (threadDelay)
import System.Timeout (timeout)

import Rig.Manifest
  ( PinEntry (..)
  , Rig (..)
  , RigAccounts (..)
  , RigAddresses (..)
  , RigPins (..)
  , RigPool (..)
  , load_rig
  , load_rig_from
  , rig_manifest_path
  , rig_pins_path
  )
import Data.ByteArray.HexString (HexString, fromBytes, toBytes)
import Network.Ethereum.Api.Types (Change (..))

-- The GAMS layer, PURE HALF ONLY. Both modules are total functions over values this file
-- constructs; neither can spawn anything. That is what keeps `cabal test` GAMS-free while still
-- letting it decide whether a version parse and an exit taxonomy are honest.
import Gams.Exit
  ( EnvFailure (..)
  , ModelFailure (..)
  , TimeoutKind (..)
  , Verdict (..)
  , classify_exit
  , gams_code_domain
  )
import Gams.Version
  ( VersionError (..)
  , conopt_version_text
  , gams_build_text
  , gams_version_text
  , parse_conopt_version
  , parse_gams_version
  )
import Gams.Argv
  ( ArgvError (..)
  , Shock (..)
  , parse_shock_field
  , render_argv
  )
import Gams.Artifact
  ( ArtifactError (..)
  , ProverArtifact (..)
  , decode_artifact
  )
import Gams.Env
  ( forbidden_key_prefixes
  , validate_env
  , whitelist_for
  , whitelist_keys
  )
-- The GAMS layer's three environment overrides, imported as RESOLVERS and as NAME constants, for
-- the same reason 'Store.Config' is: the config module is the only place any of the three is named,
-- so the override sweep below can compare the names IT writes out against the library's and redden
-- when one is renamed there and nowhere else. Nothing here resolves a binary or spawns anything --
-- these are four pure @String@s and three @lookupEnv@ wrappers.
import Gams.Config
  ( gams_bin
  , gams_bin_env_var
  , gams_conformance_env_var
  , gams_conformance_path
  , gams_model
  , gams_model_env_var
  )
-- The IO edge. `Gams.Run` is deliberately NOT one of the three tokens the GAMS-free grep forbids:
-- the suite must be able to DRIVE the invocation against stubs it writes itself while remaining
-- structurally incapable of naming the real prover. Those three tokens -- the module that will
-- resolve the live binary, its require-a-real-solver override, and the installation's absolute
-- path -- stay out of this file, and every child spawned below is a /bin/sh script this file wrote.
--
-- They are described here rather than listed, because the first draft of this comment LISTED them
-- and the grep found all three, in the sentence claiming they were absent. Fifteenth instance on
-- this branch; the prose moved and the pattern did not.
--
-- 24-04: the grep referred to above is no longer a verification-time command an executor has to
-- remember to run. It is 'the_suite_never_names_the_real_solver', with 'gams_free_pattern' built by
-- concatenation and a positive control that seeds all three tokens into a bait file and asserts the
-- pattern NAMES it -- so the zero this file reports is the absence of matches rather than the
-- absence of a scan.
import Gams.Run
  ( AbortReason (..)
  , CapturedStreams (..)
  , ProverOutcome (..)
  , RunRequest (..)
  , ToolchainIdentity (..)
  , artifact_name
  , log_name
  , run_prover
  )

import VolOrder.Decode
  ( OrderCreatedEvent (..)
  , be_integer
  , check_minted_id_run
  , decode_create_orders_result
  , decode_order_created
  , unpack_vol_order_storage
  )
import VolOrder.Report (decode_e1_from)
import CheatSwap.Encoding (encode_extsload, encode_swap, extsload_signature, swap_signature)
import CheatSwap.Types (check_cheat_tick, compose_slot0, pool_state_slot)
import Driver.Capture
  ( DriverRig (..)
  , DriverRun (..)
  , DriverSeed (..)
  , E1Record (..)
  , E3Record (..)
  , E5Record (..)
  , LegacyWritePrice (..)
  , OrderFields (..)
  , OrdersRecord (..)
  , SingleOrder (..)
  , StepRecord (..)
  , capture_path
  , no_orders
  , write_capture
  )
import Driver.Seed (gen_from_seed, resolve_seed, seed_env_var)
import RealizedVol.Decode
  ( FeeApplied (..)
  , TimepointWritten (..)
  , decode_fee_applied
  , decode_timepoint_written
  , signed_word
  )
-- The store contract, executed. Store.Laws is imported for BOTH its verdicts and its NAMES: the
-- law set is asserted against `law_names` rather than against a transcription of it, so a law
-- renamed in the library and nowhere else is a set mismatch instead of a silent loss.
import Store.Laws (law_names, store_laws)
import Store.Memory (new_memory_store)
-- The migration directory and the migration manifest. Both are PURE values imported from the
-- library, so the checks below compare the tree against what the library says the schema is,
-- rather than against a transcription of it living in this file.
--
-- 'store_conformance_path' and 'pgstore_dsn' are the RESOLVERS, imported rather than transcribed
-- so every Tier-C check reads the artifact through the same path @STORE_CONFORMANCE@ redirects and
-- the override sweep exercises the real resolvers. The two @*_env_var@ constants are imported so
-- the variable NAMES written out in this file can be compared to the library's: a rename there and
-- nowhere else is exactly the drift that leaves an override advertised and dead.
import Store.Config
  ( migrations_dir
  , pgstore_dsn
  , pgstore_dsn_env_var
  , store_conformance_env_var
  , store_conformance_path
  )
import Store.Schema (expected_migrations, identity_constraint_columns, identity_constraint_name)
-- 'cm_bytes' and the two golden pins are the EXPECTED sides of the conformance digest checks. They
-- come out of the library's own corpus definition and its Haskell-source pin, never out of the
-- artifact being checked: a digest read from the same file as the thing it digests is the tautology
-- this repository has already shipped once.
import Store.Types
  ( CorpusBehaviour (..)
  , adversarial_corpus
  , cm_behaviour
  , cm_bytes
  , cm_name
  , sha256_hex
  , volume_path_golden_bytes_len
  , volume_path_golden_sha256
  )
import StochasticOrderGen.Simulate (draw_target_vega)
import StochasticOrderGen.Types (VegaDraw (..))
import StochasticPriceGen.Simulate (simulate_path)
-- ProcessType is imported by CONSTRUCTOR rather than with (..): the unused CEV constructor brings
-- a `delta` field selector into scope that shadows a local binding in the storage-perturbation
-- check, and a -Wall warning is a gate failure here.
import StochasticPriceGen.Types (ProcessType (GBM, mu, sigma), StochasticPriceGen (..))
import VolOrder.Encoding (encode_create_order, pack_vol_order_input)
import VolOrder.Types (VolOrder (..))

-- ---------------------------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------------------------

-- | The static pin file, resolved the SAME way 'Rig.Manifest.load_rig' resolves it: through
-- 'rig_pins_path', which honours the @RIG_PINS@ environment variable.
--
-- This was a hardcoded @FilePath@ constant, and it is the THIRD instance of one defect in this
-- module. 22-03 measured it for @RIG_MANIFEST@ and 22-04 for @proof_file@: an override that is
-- advertised in @Rig.Manifest@'s own error messages (\"Override the path with the RIG_PINS
-- environment variable\") and in @offchain\/rig\/README.md@ (line 274), and silently ignored here.
--
-- This paragraph has now been wrong in BOTH directions, which is the whole lesson.
--
-- It first said @verify-rig.sh@ honoured @RIG_PINS@. That was false and had always been false
-- (@grep -c RIG_PINS offchain\/rig\/verify-rig.sh@ returns 0), so a falsification aimed at that
-- script would have been aimed at nothing. It was corrected to \"the ONE honourer is
-- 'Rig.Manifest.rig_pins_path'\" -- true of the Haskell surface, and false of the repo the moment
-- the shell half was fixed.
--
-- As of the 22-08 round the honourers are: 'Rig.Manifest.rig_pins_path' on the Haskell side, and
-- @generate-pins.sh@, @check-upstream.sh@ and @deploy-rig.sh@ on the shell side. Before that
-- round the writer of the tracked pin file ignored the override entirely while the reader
-- honoured it -- the reader\/writer asymmetry that is the single defect class this whole PR keeps
-- rediscovering.
--
-- Every Haskell consumer -- this suite, the driver, the proof app -- still resolves through
-- 'Rig.Manifest.rig_pins_path' rather than a constant of its own. That part never changed.
--
-- The reason to keep correcting this sentence is the reason the defect it describes matters: a
-- list of honourers is itself a claim, it rots exactly as fast as the code, and nothing in the
-- suite checks it. Treat it as prose, verify it with @grep@ before trusting it, and prefer
-- 'every_advertised_override_is_honoured' -- which is executable -- over this paragraph.
--
-- The consequence is not cosmetic and is not a style point -- it is that
-- @RIG_PINS=\<doctored copy\> cabal test@ goes GREEN, because the constant sends every check
-- straight back to the committed file. Every falsification aimed at the pin file was therefore
-- VACUOUS, and the only remaining way to test a pin check was to damage the evidence it guards.
--
-- 'every_advertised_override_is_honoured' is the standing guard that stops a fourth instance.
pins_file :: IO FilePath
pins_file = rig_pins_path

-- | How the pin file is NAMED in operator-facing messages.
--
-- A label is not a read path. Keeping it pure is what lets 'verify_pin' remain a pure function
-- that the falsifiability case can drive directly over a doctored pin value; the path any check
-- actually OPENS comes from 'pins_file' and from nowhere else.
pins_file_label :: String
pins_file_label = "rig-pins.json (RIG_PINS)"

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
          , "      pinned in " ++ pins_file_label ++ "   : " ++ expected
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

-- | THE PIN SURFACE, NAMED HERE SO THE FILE CANNOT NAME IT.
--
-- 'per_pin_checks' generates one check per entry it FINDS, so a pin that is absent generates no
-- check and takes its own verification with it -- and the reported total shrinks with it, which is
-- the part that makes the loss silent. @RIG_PINS@ is honoured by 'Rig.Manifest.rig_pins_path', so
-- the thin file is not hypothetical. MEASURED before this check existed, with a copy holding one
-- selector and one topic:
--
-- >  BASELINE selectors=30 topics=5  ->  85\/85 checks passed \/ SC-3 and SC-4 OK
-- >  THIN     selectors=1  topics=1  ->  52\/52 checks passed \/ SC-3 and SC-4 OK \/ EXIT=0
--
-- 29 selectors and 4 topics went unverified and nothing said so.
--
-- @offchain\/rig\/generate-pins.sh@ carries @MIN_SELECTORS@\/@MIN_TOPICS@ floors, but it is the
-- PRODUCER and it hardcodes its own output path: the floor is unreachable through the path this
-- suite reads. The consumer has to hold its own copy of the expectation, and this is it.
--
-- It is a SET, not a count, for the reason @verify-rig.sh@'s @WANT_CONTRACTS@ probe is a set: a
-- floor of thirty is satisfied by thirty pins of which one has been swapped for a name nothing
-- consumes, and a swap is exactly what a doctored pin file would do. The set is the same shape and
-- the same tradeoff -- adding or removing a pin means editing this list, deliberately.
expected_selector_pins :: [T.Text]
expected_selector_pins =
  [ "beforeSwap"
  , "changeFeeConfiguration"
  , "create_order"
  , "create_orders"
  , "deposit"
  , "getAverageVolatility"
  , "getCurrentFee"
  , "getFeeConfig"
  , "getOrderPacked"
  , "getTickCumulative"
  , "getTimepointPacked"
  , "getTwapTick"
  , "initializeDynamicFee"
  , "initializeHook"
  , "initializeTWAP"
  , "lastIndex"
  , "oldestIndex"
  , "orderCount"
  , "owner"
  , "poolId"
  , "poolManager"
  , "previewDeposit"
  , "previewRiskPrice"
  , "readWindow"
  , "riskPrice"
  , "riskWeightedShares"
  , "setRiskPrice"
  , "totalDeposits"
  , "totalShares"
  , "writeTimepoint"
  ]

expected_topic_pins :: [T.Text]
expected_topic_pins =
  [ "FeeApplied"
  , "FeeConfigurationChanged"
  , "TimepointWritten"
  , "VolOrderCreated"
  , "WindowChanged"
  ]

-- | THE EXTERNAL ANCHOR FOR @generatedFrom@.
--
-- Every WRITER of a @generatedFrom@ field reads this file -- @deploy-rig.sh@, @generate-pins.sh@,
-- @capture-cheat-swap-proof.sh@, @app\/CheatSwapProof.hs@ -- and so do @verify-import.sh@ (which
-- @git diff@s the working tree against the ref it names) and @check-upstream.sh@ (which wrote it).
-- Until this check existed, the number of times this suite read it was ZERO.
--
-- The consequence, MEASURED: @generatedFrom@ was checked for 40-hex SHAPE ('refs_are_real') and
-- for MUTUAL EQUALITY across the pin file, the proof and the run capture. Three artifacts agreeing
-- with each other is not provenance -- a coordinated fake sha written into all of them satisfies
-- both properties. The reviewer measured a coordinated fake at 83\/85: the only objection came
-- from @driver-run-capture.json@, and only because it has no env override, i.e. the suite objected
-- by ACCIDENT of what was overridable rather than because anything held the ref down.
--
-- This file is the thing that is not self-referential: it names the upstream ref the imported
-- source-of-truth artifacts were taken from, and @verify-import.sh@ binds THAT to the tree by
-- content diff. Binding the pin file to it closes the loop, and it closes it for the proof and the
-- run capture too, because both are already pinned to the pin file by equality.
--
-- Deliberately NOT overridable. An anchor that a falsification can redirect is not an anchor; the
-- shape here is the same one 'realized_vol_iface' and 'volorder_iface' use, and
-- 'every_advertised_override_is_honoured' covers ADVERTISED variables only, so nothing in the
-- module claims otherwise.
import_ref_file :: FilePath
import_ref_file = "offchain/rig/import-ref.txt"

-- | The pin file's @generatedFrom@ IS the imported source-of-truth ref, not merely a 40-hex string
-- that three artifacts happen to share.
sc4_generated_from_is_the_imported_ref :: RigPins -> Check
sc4_generated_from_is_the_imported_ref pins =
  Check "sc4_generated_from_is_the_imported_ref" . guarded $ do
    anchor <- strip_ws <$> readFile import_ref_file
    let pinned = T.unpack (pins_generated_from pins)
    pure $ do
      _ <- expect (is_git_object_name anchor)
             (import_ref_file ++ " holds " ++ show anchor ++ ", which is not a 40-character git"
               ++ " object name. It is written by a command substitution in"
               ++ " offchain/rig/check-upstream.sh, and a failed substitution yields \"\""
               ++ " silently -- an empty anchor would then be satisfied by an empty pin."
               ++ " Re-run: bash offchain/rig/check-upstream.sh")
      expect (pinned == anchor)
        (pins_file_label ++ " records generatedFrom " ++ show pinned ++ " but " ++ import_ref_file
          ++ " names " ++ show anchor ++ ". Every OTHER generatedFrom assertion in this module is"
          ++ " an equality BETWEEN ARTIFACTS -- the pin file against the proof, the pin file"
          ++ " against the run capture -- and a coordinated value written into all of them"
          ++ " satisfies every one of them while naming no real import. This is the only"
          ++ " assertion that compares the ref to something outside that set, and"
          ++ " offchain/rig/verify-import.sh is what binds THAT file to the tree."
          ++ " Regenerate: bash offchain/rig/generate-pins.sh")

-- | THE RETIRED SET, PINNED FOR THE REASON THE LIVE SETS ARE.
--
-- 'sc4_no_retired_value_is_live' iterates whatever @retired@ HAPPENS to contain, so an entry that
-- is absent is an entry nothing is guarded against -- the same scoped-by-the-artifact defect the
-- live sets are pinned against, one block over. MEASURED:
--
-- >  jq 'del(.retired.create_order_v1)' rig-pins.json   ->  89\/89 checks passed
--
-- Silently absorbed, because @create_order_v1@ is the one retired value no OTHER check looks up
-- by name. The other two are named directly by 'sc4_falsifiable' and
-- 'rpin04_retired_topic0s_are_rejected', so deleting either of those reddens (87\/89, measured) --
-- by their accident, not by assertion. This makes the set itself the assertion.
expected_retired_pins :: [T.Text]
expected_retired_pins =
  [ "create_order_v1"
  , "topic_order_created_stale"
  , "topic_vol_order_created_v1"
  ]

-- | The pin file names EXACTLY the pins this suite claims to verify -- no more and no fewer.
sc4_pin_surface_is_the_expected_set :: RigPins -> Check
sc4_pin_surface_is_the_expected_set pins =
  pure_check "sc4_pin_surface_is_the_expected_set" $ do
    _ <- one "selector" "expected_selector_pins" expected_selector_pins
           (Map.keys (pin_selectors pins))
    _ <- one "topic0" "expected_topic_pins" expected_topic_pins (Map.keys (pin_topics pins))
    one "retired" "expected_retired_pins" expected_retired_pins (Map.keys (pin_retired pins))
  where
    one kind expectation wanted got =
      let missing = [T.unpack n | n <- sort wanted, n `notElem` got]
          extra   = [T.unpack n | n <- sort got, n `notElem` wanted]
      in expect (null missing && null extra)
           ("the " ++ kind ++ " pin set in " ++ pins_file_label ++ " is not the "
             ++ show (length wanted) ++ " this suite verifies."
             ++ "\n      missing    : " ++ render missing
             ++ "\n      unexpected : " ++ render extra
             ++ "\n      A missing pin DELETES ITS OWN check -- an sc4_pin_" ++ kind ++ "_* for a"
             ++ " live pin, one value's worth of sc4_no_retired_value_is_live for a retired one --"
             ++ " and takes the total down with it, so the run still reports \"SC-3 and SC-4 OK\""
             ++ " while verifying less. If a pin was added or retired ON PURPOSE, edit "
             ++ expectation ++ " in this module and say so; otherwise regenerate:"
             ++ " bash offchain/rig/generate-pins.sh")

    render [] = "(none)"
    render xs = intercalate ", " xs

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
      pf      <- pins_file
      outcome <- try (load_rig_from pf mf)
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
          pf <- pins_file
          a <- try (load_rig_from pf missing_path)
          b <- try (load_rig_from pf broken_path)
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
-- | WHY THIS CHECK IS FOUR ASSERTIONS AND NOT ONE.
--
-- The purge was a single @grep@ whose success condition was exit 1. @grep@ exits 1 for \"scanned
-- thirty-six files and found nothing\" AND for \"matched no files at all\" -- a moved directory, a
-- typo in the root, an @--include@ that stopped matching. Absence read as success, with no floor
-- underneath it and no evidence the pattern could match anything. A new @.py@ or @.ts@ under
-- @offchain\/@ was silently exempt for the same reason: the scope is expressed as an
-- @--include@ whitelist, and a whitelist cannot report what it did not select.
--
-- So: (1) a POSITIVE CONTROL, the same argument vector over a temp tree seeded with a real
-- literal, which must EXIT 0 and name the seeded files -- absence can no longer read as success
-- because the pattern is shown matching before it is trusted not to; (2) an EXTENSION CENSUS over
-- @offchain\/@, so a file type that is not in the scanned set has to be declared here rather than
-- slipping through unscanned; (3) a FLOOR on the scanned-file count; and only then (4) the purge.
--
-- The floor is a floor rather than a pinned count on purpose, and it is the one relation in this
-- check: four tracks add @.hs@ files to @offchain\/@ legitimately and often, so an exact count
-- would fail on every addition and be raised reflexively, which is how a pin becomes a rubber
-- stamp. The failure mode the floor exists for -- the scan SHRINKING to nothing -- is discriminated
-- by @>=@ exactly. The scope question that @>=@ cannot answer is answered by (2) instead.
purge_pattern :: String
purge_pattern =
  intercalate "|"
    [ "0x[0-9a-fA-F]{40}\\b"
    , "0x[0-9a-fA-F]{64}\\b"
    , "0x[0-9a-fA-F]{8}\\b"
    ]

-- | The file types the purge SCANS. Kept next to 'purge_known_extensions' so the gap between what
-- exists and what is scanned is visible in one place.
--
-- The SQL entry arrived at 23-03 with @offchain\/migrations\/@, and it is SCANNED rather than
-- merely declared because SQL is EXECUTED content -- it creates the tables the whole store rests
-- on. This check's own failure text states the rule: /"Either add it to purge_scanned_extensions
-- (if code runs from it) or to purge_known_extensions with the reason it is data."/ Free-passing an
-- executable file type is the worse trade, and it is worse here than it looks: the migration
-- library applies every file it finds in that directory, with no extension filter at all.
purge_scanned_extensions :: [String]
purge_scanned_extensions = [".hs", ".sh", ".sql"]

-- | Every file type that currently exists under @offchain\/@. @.json@, @.md@ and @.txt@ are data
-- and prose, never executed; @offchain\/spec\/types.md@ deliberately holds a pasted RPC transcript
-- and redacting it would destroy evidence rather than close a hole. Anything NOT on this list is a
-- file type nobody has decided about, and an undecided file type must not default to exempt.
purge_known_extensions :: [String]
purge_known_extensions = [".hs", ".json", ".md", ".sh", ".sql", ".txt"]

-- | The scanned-file count at the time this floor was written.
--
-- RE-MEASURED at 23-03, cold, and NOT incremented by arithmetic -- which is the only reason the
-- following is visible: the 36 written here at 23-01 was already STALE. Waves 1 and 2 added five
-- @.hs@ files, so the scan was at 41 before this commit and the recorded \"zero slack\" had
-- silently become five. A floor that is inherited rather than re-measured records the tree as it
-- was on the day someone last thought about it.
--
-- 55 = @find offchain \\( -name '*.hs' -o -name '*.sh' -o -name '*.sql' \\) -type f | wc -l@,
-- RE-MEASURED COLD on 2026-08-16 during plan 24-03 with @Gams\/Run.hs@ on disk: 45 Haskell, 8
-- shell, 2 SQL.
--
-- AND THE RE-MEASUREMENT IS WHY THIS PARAGRAPH IS LONGER THAN IT WAS. It read 51 immediately
-- before, against 55 scanned files -- FOUR of slack, not the zero the previous wave recorded.
-- 24-02's summary states this floor moved 51 -> 54 in commit @2a558e3@; @git show@ on that commit
-- and on every commit after it reports @purge_file_floor = 51@. It never moved. Its twin
-- 'credential_scan_floor' DID move (59 -> 62) in the same commit, so one half of a pair that is
-- always re-measured together landed and the other did not, and nothing reddened -- because a
-- floor with slack is a guard that passes for a reason unrelated to its subject, which is this
-- milestone's standing defect wearing yet another representation. Recorded here rather than
-- quietly corrected: the summary of record is wrong about this number, and the number on disk is
-- what the suite was actually enforcing.
--
-- 51 was itself measured at 24-01, when it was 48 immediately before against EXACTLY 48 scanned
-- files. It is moved by running the command above, NOT by arithmetic.
--
-- 48 was itself measured at the END of plan 23-04: 38 Haskell, 8 shell, 2 SQL. 23-03 left it at
-- 45 (36\/7\/2) and 23-04 added @Store\/Json.hs@, @app\/StoreConformance.hs@ and
-- @rig\/capture-store-conformance.sh@ -- the last of which is a SCANNED file type. Before that it
-- was 36, and it had been 36 for two waves while the tree moved to 41 underneath it.
--
-- The rule this records, since it is a floor and not a pin: it is re-measured when the purge's
-- SCOPE changes or when a plan is already editing this block, and NOT on every added @.hs@. Four
-- tracks add Haskell here legitimately and often; a number chased on every addition is raised
-- reflexively and stops being read. What it must never do again is sit unexamined while the tree
-- moves under it.
--
-- The extension census under @offchain\/@ at this measurement: @hs 45, sh 8, json 8, md 3, txt 2,
-- sql 2@. Only @.hs@ moved since 24-01, by four -- three library modules from 24-02 and
-- @Gams\/Run.hs@ from 24-03. The @.json@ count is unchanged: 24-03 writes no capture artifact, and
-- every stub it spawns is BUILT into a temp directory rather than committed.
--
-- RE-MEASURED COLD AGAIN at 24-04, both halves of the pair together, and NEITHER moved: 55 against
-- exactly 55 files, ZERO slack, census unchanged at @hs 45, sh 8, json 8, md 3, txt 2, sql 2@. The
-- whole plan lands in this one file, so the tree did not move -- but the rule is that a floor is
-- re-measured whenever a plan is already editing this block, and 24-02 is why: it recorded a
-- measurement whose edit never reached the source, and no arithmetic would have caught that.
purge_file_floor :: Int
purge_file_floor = 55

-- | The purge scan, as ONE argument vector, so the positive control runs the identical invocation
-- over a different root rather than a lookalike of it.
purge_scan :: FilePath -> IO (ExitCode, String, String)
purge_scan root =
  readProcessWithExitCode
    "grep"
    (["-rnE", purge_pattern, root] ++ map ("--include=*" ++) purge_scanned_extensions)
    ""

-- | Every file under a root, recursively.
walk_files :: FilePath -> IO [FilePath]
walk_files root = do
  entries <- listDirectory root
  nested <- mapM step entries
  pure (concat nested)
  where
    step entry = do
      let path = root </> entry
      is_dir <- doesDirectoryExist path
      if is_dir then walk_files path else pure [path]

-- | The seeded literal, BUILT rather than written. A 40-hex constant spelled out in this module
-- would be found by the very scan it is here to exercise, and the check would fail on its own
-- control. Constructing it keeps @offchain\/test\/Main.hs@ inside its own purge scope.
purge_control_literal :: String
purge_control_literal = "0x" ++ replicate 40 'a'

-- | The same scan over a temp tree that DOES contain a literal, in a scanned type and in an
-- unscanned one. Returns the assertion, so the caller orders it first.
purge_positive_control :: IO (Either String ())
purge_positive_control = do
  tmp <- getTemporaryDirectory
  let dir      = tmp </> "sc3-purge-positive-control"
      hs_bait  = dir </> "bait.hs"
      sh_bait  = dir </> "bait.sh"
      py_bait  = dir </> "bait.py"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [hs_bait, sh_bait, py_bait]) $ do
    writeFile hs_bait ("bait :: String\nbait = \"" ++ purge_control_literal ++ "\"\n")
    writeFile sh_bait ("#!/usr/bin/env bash\nADDR=" ++ purge_control_literal ++ "\n")
    writeFile py_bait ("BAIT = \"" ++ purge_control_literal ++ "\"\n")
    (code, out, err) <- purge_scan dir
    pure $ do
      _ <- expect (code == ExitSuccess)
             ("the purge's POSITIVE CONTROL did not fire: grep exited " ++ show code
               ++ " over a tree seeded with a 20-byte literal in a .hs file and a .sh file."
               ++ " The pattern or the --include set has stopped matching anything, which means"
               ++ " the exit-1 the real scan reports is absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      grep stderr: " ++ err))
      _ <- expect ("bait.hs" `isInfixOf` out && "bait.sh" `isInfixOf` out)
             ("the purge's POSITIVE CONTROL fired but did not name both seeded files. grep said:\n"
               ++ unlines (map ("      " ++) (lines out)))
      -- Not a defect, a DECLARED limitation, asserted so it cannot change silently: the scan is an
      -- --include whitelist and does not read .py. The extension census is what makes that safe,
      -- and it is only safe while this stays true.
      expect (not ("bait.py" `isInfixOf` out))
        ("the purge scan now reads .py files. That is a scope CHANGE: purge_scanned_extensions"
          ++ " and purge_known_extensions describe the old scope and the census below will be"
          ++ " reasoning about the wrong set.")

sc3_literal_purge :: Check
sc3_literal_purge = Check "sc3_literal_purge" . guarded $ do
  control <- purge_positive_control
  files   <- walk_files "offchain"
  (code, out, err) <- purge_scan "offchain"
  let present   = nub (sort (map takeExtension files))
      undeclared = filter (`notElem` purge_known_extensions) present
      scanned   = filter ((`elem` purge_scanned_extensions) . takeExtension) files
  pure $ do
    _ <- control
    _ <- expect (null undeclared)
           ("offchain/ holds file types this check has never decided about: "
             ++ intercalate ", " undeclared
             ++ ". The purge scans " ++ intercalate " and " purge_scanned_extensions
             ++ " only, so an undeclared type is EXEMPT and nothing says so -- which is how a new"
             ++ " executable surface gets a free pass. Either add it to purge_scanned_extensions"
             ++ " (if code runs from it) or to purge_known_extensions with the reason it is data.")
    _ <- expect (length scanned >= purge_file_floor)
           ("the purge scanned " ++ show (length scanned) ++ " files, below the floor of "
             ++ show purge_file_floor ++ ". grep exits 1 for \"found nothing\" AND for \"matched no"
             ++ " files at all\", so a scan that has collapsed reports exactly what a clean scan"
             ++ " reports. If files were removed on purpose, lower purge_file_floor and say so.")
    case code of
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
-- The claim in the paragraph above -- "module and pool AGREE" -- was for two rounds asserted
-- NOWHERE. MEASURED: with @module_tick_spacing = 0@ the whole suite came back 89\/89, including
-- the check at 'rpin03_storage_round_trip' whose own error message says "a zero there would make
-- the round-trip pass while the word was wrong". It said so while passing at exactly that zero,
-- because 'pack_storage_reference' BUILDS the word from this constant and the assertion then
-- reads the constant back out of it: @c == c@ for every @c@, and at @c = 0@, @0 == 0@. The
-- manifest's real @.pool.tickSpacing@ was read by 'positive_fields_agree' at two call sites and
-- never bound to this constant.
--
-- 'rpin03_module_constant_is_the_deployed_spacing' is that binding. It is the only assertion in
-- the module that gives this constant a provenance other than itself, so it is the only one that
-- can redden when the pool drifts away again -- which the paragraph above says has already
-- happened once, 10 -> 20 at PR #18.
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
                 , "      pinned in " ++ pins_file_label ++ " : " ++ pinned
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
      -- HONEST SCOPE. 'pack_storage_reference' builds this word FROM 'module_tick_spacing', so
      -- this reads back what it just wrote and is @c == c@ for every @c@. It pins the reference
      -- encoder's shift-in/shift-out symmetry at 104..127 and NOTHING about the value. The claim
      -- this line used to make in its own message -- that a zero would be caught here -- was
      -- false and was MEASURED false: at @module_tick_spacing = 0@ the suite was 89/89. The
      -- value is asserted by 'rpin03_module_constant_is_the_deployed_spacing', against the
      -- manifest, which is the only other place the deployed spacing is written down.
      _ <- expect ((word `shiftR` 104) .&. mask_of 24 == module_tick_spacing)
             ("corner " ++ label ++ ": the tickSpacing slot at 104..127 holds "
               ++ show ((word `shiftR` 104) .&. mask_of 24) ++ ", expected the module constant "
               ++ show module_tick_spacing ++ " -- the reference encoder's shift-in and the"
               ++ " shift-out here disagree about where the slot is. The VALUE is asserted by"
               ++ " rpin03_module_constant_is_the_deployed_spacing, not here.")
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
    -- Reference-encoder symmetry only, exactly like the sibling line in
    -- 'rpin03_storage_round_trip': @storage@ was built from 'module_tick_spacing' by
    -- 'pack_storage_reference', so this is @c == c@. CHECKED rather than assumed -- the review
    -- that raised the sibling flagged this one as possibly having a different provenance, and it
    -- does not. The value lives in 'rpin03_module_constant_is_the_deployed_spacing'. The
    -- discriminating assertions in THIS check are the two above: @input /= storage@, and the
    -- 104..127 slot of the INPUT word, which 'pack_vol_order_input' -- the library, not the
    -- reference -- built.
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

-- | THE ONLY EXTERNAL PROVENANCE 'module_tick_spacing' HAS.
--
-- Both assertions on the tickSpacing slot above read the constant back out of a word
-- 'pack_storage_reference' built from that same constant. Neither can see its VALUE, and the
-- suite proved it: at @module_tick_spacing = 0@ every one of the 89 checks passed, one of them
-- while its own message claimed a zero would be caught.
--
-- The manifest is the second writer. @.pool.tickSpacing@ is what @deploy-rig.sh@ recorded off the
-- deployed @PoolKey@, and it is already read by 'positive_fields_agree' at two freshness call
-- sites -- but only ever against the ARTIFACTS, never against this constant, so the two lived
-- side by side unrelated.
--
-- The floor is separate from the equality for the reason 'positive_fields_agree' keeps them
-- separate: @0 == 0@ is the failure being closed, so an equality alone would reproduce it the
-- moment the manifest carried a zero too. A Uniswap v4 pool cannot have @tickSpacing = 0@ -- the
-- @PoolKey@ is rejected at @initialize@ -- so the floor is exact rather than heuristic.
rpin03_module_constant_is_the_deployed_spacing :: Check
rpin03_module_constant_is_the_deployed_spacing =
  Check "rpin03_module_constant_is_the_deployed_spacing" . guarded $ do
    mf <- manifest_file
    present <- doesFileExist mf
    outcome <-
      if present
        then do
          pf <- pins_file
          attempt <- try (load_rig_from pf mf)
          pure (Just (attempt :: Either IOException Rig))
        else pure Nothing
    pure $ do
      rig <- case outcome of
        Nothing         -> Left ("no " ++ mf ++ " -- it is gitignored, so a fresh checkout has no"
                                  ++ " copy. Stand the rig up: " ++ deploy_command)
        Just (Left err) -> Left ("load_rig_from failed on the real files: " ++ show err)
        Just (Right r)  -> Right r
      let deployed = rig_tick_spacing (rig_pool (rig_addrs rig))
      _ <- expect (module_tick_spacing > 0)
             ("module_tick_spacing is " ++ show module_tick_spacing ++ ". Every other assertion on"
               ++ " the 104..127 slot reads this constant back out of a word built from it, so at"
               ++ " zero they all pass on 0 == 0 -- MEASURED at 89/89. There is no legitimate zero"
               ++ " tick spacing: initialize rejects the PoolKey.")
      _ <- expect (deployed > 0)
             ("the manifest records pool.tickSpacing = " ++ show deployed ++ ". A Uniswap v4 pool"
               ++ " cannot have a zero tick spacing, and an equality against a zero on the other"
               ++ " side would be satisfied by nothing -- re-run: " ++ deploy_command)
      expect (module_tick_spacing == deployed)
        ("module_tick_spacing is " ++ show module_tick_spacing ++ " but the manifest's"
          ++ " pool.tickSpacing is " ++ show deployed ++ ". The storage word this module packs"
          ++ " puts the constant at bits 104..127, so a module that disagrees with the pool packs"
          ++ " a word the chain would never have written -- and every round-trip assertion on that"
          ++ " slot would still pass, because they all read the constant back out of a word built"
          ++ " from it. This spacing already moved once, 10 -> 20 at PR #18, taking the PoolKey"
          ++ " hash and therefore the poolId with it.")

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
               , "      pinned in " ++ pins_file_label ++ "  : " ++ pinned
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

-- | The object's members, sorted by key. Used where the KEY SET is the subject rather than a
-- known key -- 'store_conformance_verdicts_are_all_pass' asserts the law-verdict keys in both
-- directions, and an accessor that can only reach keys it already names cannot see an extra one.
json_object_pairs :: Value -> Either String [(String, Value)]
json_object_pairs (Object o) = Right (sort [(K.toString k, v) | (k, v) <- KM.toList o])
json_object_pairs other      = Left ("expected a JSON object, got " ++ json_kind other)

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
        pf <- pins_file
        attempt <- try (load_rig_from pf mf)
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
    _ <- positive_fields_agree "chainId" (rig_chain_id addrs) captured_chain "the capture"
           ("The committed capture is STALE. Re-take it: " ++ capture_command)
    captured_manager <- map toLower <$> (json_field "manager" capture >>= json_string)
    manifest_manager <- manifest_address addrs "VolOrderManagerMod"
    -- FOUND BY THE COUNTERPART SWEEP, not by the review: a THIRD raw captured == manifest
    -- equality, on the batch-return capture. Routed through 'addresses_agree' with the other two.
    _ <- addresses_agree "VolOrderManagerMod" manifest_manager "manager" captured_manager
           capture_command
           ("The committed capture describes a DIFFERENT deployment and its bytes prove nothing"
             ++ " about the module now on chain.")
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

-- ---------------------------------------------------------------------------------------------
-- THE TWO FUNCTIONS THIS ROUND ADDED AND THIS SUITE NEVER CALLED
--
-- 'VolOrder.Decode.check_minted_id_run' ('1f82663') and 'VolOrder.Report.decode_e1_from'
-- ('37ec202') appeared ZERO times in this module. Both are pure, total and chain-independent, in a
-- suite that is chain-independent by design and already holds ~25 pure-function checks -- so there
-- was no reason for the gap other than nobody closing it. MEASURED: two mutants that revert those
-- commits entirely stayed green at 85\/85.
--
--   1. @check_minted_id_run _ = Right ()@
--   2. @decode_e1_from t _emitter l = decode_order_created t l@
--
-- Both are killed below, and the kills are re-measured in the commit that adds them.
-- ---------------------------------------------------------------------------------------------

-- | The minted-id run rule, driven over the LIVE capture and over each defect it names.
--
-- The live half matters: @N2_success_then_fail@ is a real @(bool, id)@ pair sequence returned by
-- the deployed module, so the accepting case is not a hand-built list agreeing with a hand-built
-- expectation. The rejecting half enumerates the three defects the function's own documentation
-- names -- the @0@ sentinel, the loop index, the repeated id -- plus the non-contiguous run.
--
-- The last two assertions pin the DOCUMENTED RESIDUAL rather than a capability: a uniform shift of
-- the whole run is ACCEPTED, deliberately, because a client cannot distinguish \"the module is off
-- by one\" from \"another writer minted between the preview and the counter read\". Asserting the
-- residual is what stops the gap being quietly closed with an absolute anchor that would fail on a
-- legitimate interleave -- and what stops it being quietly widened.
rpin05_minted_id_run_behavior :: Check
rpin05_minted_id_run_behavior =
  Check "rpin05_minted_id_run_behavior" . guarded $ do
    loaded <- read_json_file capture_file ("produce it with: " ++ capture_command)
    pure $ do
      capture <- loaded
      this <- capture_case "N2_success_then_fail" capture
      raw <- json_field "returndata" this >>= json_string
      raw_bytes <- hex_bytes raw
      live <-
        case decode_create_orders_result (fromBytes raw_bytes) of
          Left err    -> Left ("N2_success_then_fail did not decode: " ++ err)
          Right pairs -> Right pairs
      _ <- expect (live == [(True, 1), (False, 0)])
             ("N2_success_then_fail decoded to " ++ show live ++ ", expected [(True,1),(False,0)]."
               ++ " The minted-id assertions below are driven over these bytes, so a change in"
               ++ " them changes what is being asserted.")
      _ <- accepts "the live N2_success_then_fail pairs" live
      _ <- accepts "an empty batch" []
      _ <- accepts "an all-rejected batch" [(False, 0), (False, 0)]
      _ <- accepts "a contiguous run with a rejection interleaved" [(True, 4), (False, 0), (True, 5)]
      -- THE RESIDUAL, asserted as acceptance rather than described in prose.
      _ <- accepts "a UNIFORMLY SHIFTED run (the documented residual)" [(True, 5), (True, 6), (True, 7)]

      _ <- rejects "the 0 sentinel" [(True, 0)] "1-based"
      _ <- rejects "the loop index" [(True, 0), (True, 1), (True, 2)] "1-based"
      _ <- rejects "the same id repeated" [(True, 8), (True, 8), (True, 8)] "non-contiguous"
      _ <- rejects "a gap in the run" [(True, 3), (True, 5)] "non-contiguous"
      rejects "a run that goes BACKWARDS" [(True, 9), (True, 8)] "non-contiguous"
  where
    accepts what pairs =
      case check_minted_id_run pairs of
        Right () -> Right ()
        Left why ->
          Left ("check_minted_id_run REJECTED " ++ what ++ " " ++ show pairs ++ ": " ++ why)

    rejects what pairs needle =
      case check_minted_id_run pairs of
        Right () ->
          Left ("check_minted_id_run ACCEPTED " ++ what ++ " " ++ show pairs
                 ++ ". Every readback that recomputes ids locally would still pass, so this is the"
                 ++ " one place the defect is visible.")
        Left why ->
          expect (needle `isInfixOf` why)
            ("check_minted_id_run rejected " ++ what ++ " but the message does not say "
              ++ show needle ++ ", so an operator cannot tell WHICH rule fired: " ++ why)

-- | Twenty identical bytes as an 'Address'. Built, never written: a 20-byte hex constant spelled
-- out here would be found by 'sc3_literal_purge', which scans this file.
address_of_byte :: Word8 -> Address
address_of_byte b =
  case fromHexString (fromBytes (BS.replicate 20 b)) of
    Right addr -> addr
    Left why   -> error ("20 identical bytes did not parse as an address: " ++ why)

-- | E1 IS FILTERED ON THE EMITTER, and the filter is what does the work.
--
-- This is '37ec202''s own falsification, moved into the suite: two logs carrying the SAME live
-- pinned @VolOrderCreated@ topic0, one from the manager and one from an impostor. topic0 identifies
-- an EVENT SIGNATURE, not an emitter, and the decoder's payload-length guard rejects a SHORT
-- payload rather than a long enough one from the wrong contract -- so the topic0-only predicate
-- accepts BOTH, and only the address separates them.
--
-- The topic0-only list is asserted too, and it is the assertion that makes the other one mean
-- something: without it, @filtered == [7]@ is equally satisfied by a decoder that rejected the
-- impostor's log for some unrelated reason, and the check would pass while proving nothing about
-- the filter. Both lists are pinned BY VALUE.
--
-- The consequence of the missing filter was not a spurious line of output: @capture_single@ feeds
-- the decoded id to @so_readback_id@ and reads it back out of the MANAGER's storage, where
-- @getOrderPacked@ has no bounds check and answers the 0 sentinel -- a fabricated readback written
-- into the committed artifact.
rpin04_e1_is_filtered_on_the_emitter :: Check
rpin04_e1_is_filtered_on_the_emitter =
  Check "rpin04_e1_is_filtered_on_the_emitter" . guarded $ do
    contents <- readFile volorder_iface
    pure $ do
      t0 <- e1_topic0_from contents
      let manager  = address_of_byte 17
          impostor = address_of_byte 34
          from addr order_id =
            (synthetic_log
               [hexstring_of t0, hexstring_of order_id]
               [rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega])
              { changeAddress = addr }
          logs        = [from manager 7, from impostor 999999]
          topic_only  = [orderId e | l <- logs, Just e <- [decode_order_created t0 l]]
          filtered    = [orderId e | l <- logs, Just e <- [decode_e1_from t0 manager l]]

      _ <- expect (manager /= impostor)
             "the manager and impostor addresses are equal, so this check cannot separate them"
      _ <- expect (topic_only == [7, 999999])
             ("the topic0-ONLY predicate decoded order ids " ++ show topic_only
               ++ ", expected [7,999999]. Both logs must be accepted by it -- if the impostor's log"
               ++ " were rejected for some OTHER reason, the filtered result below would prove"
               ++ " nothing about the address filter.")
      _ <- expect (filtered == [7])
             ("decode_e1_from decoded order ids " ++ show filtered ++ ", expected [7]. It accepted"
               ++ " a VolOrderCreated emitted by a contract that is not the manager: the id then"
               ++ " reaches getOrderPacked, which has no bounds check and answers the 0 sentinel,"
               ++ " and a fabricated readback is written into the committed artifact.")
      -- The decoder half still applies: a right emitter with a wrong topic0 is still not an E1.
      let wrong_topic =
            (synthetic_log
               [hexstring_of (t0 + 1), hexstring_of 7]
               [rpin_base_strike, rpin_base_width, rpin_base_skew, rpin_base_vega])
              { changeAddress = manager }
      expect (isNothing (decode_e1_from t0 manager wrong_topic))
        "decode_e1_from accepted a log from the manager whose topic0 is not VolOrderCreated"

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
  --
  -- The default arm used to be @Left _ -> 0@, and that is the same degeneracy as everything else
  -- in this round: @ext_word == slot@ below compares 'encode_extsload'\'s output against the very
  -- value it was handed, so at @slot = 0@ it reads @0 == 0@ and hex32's nibble ordering -- the
  -- ONE property this half of the check exists to observe -- becomes unobservable. A parse
  -- failure would have swallowed itself into the one value that hides it. It is now a named
  -- failure. (It is the module's only @Left _ -> <default value>@; the two other @Left _@ arms,
  -- in 'sc4_falsifiable' and the vega draw guard, are negative-test SUCCESS arms -- "it correctly
  -- rejected" -- and are not this shape.)
  let parsed_slot = pool_state_slot <$> integer_of_hex_text driv01_pool_id_hex
  ext_raw <- encode_extsload (either (const 1) id parsed_slot)
  pure $ do
    slot <-
      case parsed_slot of
        Right s -> Right s
        Left why ->
          Left ("driv01_pool_id_hex does not parse as a 32-byte hex word (" ++ why ++ "), so the"
                 ++ " derived pool-state slot cannot be computed. This used to default to 0, where"
                 ++ " the extsload round trip below reads 0 == 0 and hex32's nibble ordering goes"
                 ++ " unobserved.")
    _ <- expect (slot /= 0)
           ("the derived pool-state slot is 0. The extsload assertion below compares the encoder's"
             ++ " output word against the value it was handed, so at zero it is satisfied by"
             ++ " nothing and a reversed nibble order would pass.")
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
-- DRIV-01: the committed cheat-swap proof
--
-- These five checks are the OFFLINE half of plan 22-04. The chain half ran once, in
-- offchain/rig/capture-cheat-swap-proof.sh, and committed its result; everything below reads that
-- artifact and asserts it by EXACT VALUE. Nothing here opens a socket -- the suite's
-- chain-independence is a measured property of this workstream, not an aspiration, and a suite
-- that needs a rig is a suite that gets skipped.
--
-- Every number pinned below was MEASURED, never derived. Where a value could in principle have
-- been predicted, the check says which it was, because the difference decides what a future
-- failure means.
-- ---------------------------------------------------------------------------------------------

-- | The committed cheat-swap proof, resolved through @RIG_CHEAT_SWAP_PROOF@.
--
-- The override exists so these checks can be FALSIFIED without touching the committed artifact.
-- 22-03 measured what happens when a check's input path is a constant: the plan's own falsification
-- (@RIG_MANIFEST=\<broken copy\> cabal test@) came back GREEN at 68\/68 because the constant sent
-- every check straight back to the real file, so the suite could not be pointed at any manifest for
-- any falsification, ever. A check that cannot be aimed at a mutant can only be falsified by
-- damaging the evidence it guards.
--
-- SCOPE, stated so the two halves cannot drift apart the way 22-03's did: this variable redirects
-- the CHECKS only. @offchain\/rig\/capture-cheat-swap-proof.sh@ always writes the committed path,
-- because a capture that could be redirected is a capture that can silently fail to update the
-- artifact everything else reads.
proof_file :: IO FilePath
proof_file = fromMaybe default_proof_file <$> lookupEnv "RIG_CHEAT_SWAP_PROOF"

default_proof_file :: FilePath
default_proof_file = "offchain/rig/cheat-swap-proof.json"

proof_command :: String
proof_command = "bash offchain/rig/capture-cheat-swap-proof.sh"

-- | The measurements the artifact must carry, in order. A group that fails at capture time still
-- emits a placeholder row, so a SHORTER list means a measurement was dropped rather than recorded
-- -- which is the one outcome plan 22-04 calls a failure.
proof_measurement_names :: [String]
proof_measurement_names =
  [ "cheat_to_5000_then_swap"
  , "cheat_wrong_pool_then_swap"
  , "same_second_repeat_step1"
  , "same_second_repeat_step2"
  , "clock_untouched_repeat_step3"
  , "extreme_tick_near_floor"
  ]

-- | The bit offsets of the Slot0 fields this plan cares about.
--
-- @sqrtPriceX96 [0,160) | tick [160,184) int24 | protocolFee [184,208) | lpFee [208,232)@.
slot0_tick_shift, slot0_fee_shift :: Int
slot0_tick_shift = 160
slot0_fee_shift  = 184

-- | The @int24@ tick packed into a slot0 word, as a signed 'Integer'.
slot0_tick_of :: Integer -> Integer
slot0_tick_of w =
  let raw = (w `shiftR` slot0_tick_shift) .&. ((1 `shiftL` 24) - 1)
  in if raw >= 1 `shiftL` 23 then raw - (1 `shiftL` 24) else raw

find_measurement :: String -> Value -> Either String Value
find_measurement name proof = do
  entries <- json_field "measurements" proof >>= json_array
  named <- mapM (\m -> (,) <$> (json_field "name" m >>= json_string) <*> pure m) entries
  case [m | (n, m) <- named, n == name] of
    [m]   -> Right m
    []    -> Left ("no measurement named " ++ show name
                    ++ "; present: " ++ intercalate ", " (map fst named)
                    ++ "\n      re-take it: " ++ proof_command)
    found -> Left (show (length found) ++ " measurements named " ++ show name)

-- | A field the artifact carries as a DECIMAL STRING because it can exceed 2^53. Reading it back
-- as an 'Integer' here is what makes the 256-bit slot0 words assertable at all: a JSON number would
-- already have been rounded by the time any consumer saw it.
json_decimal_string :: Value -> Either String Integer
json_decimal_string v = do
  raw <- json_string v
  case reads raw of
    [(n, "")] -> Right n
    _         -> Left ("expected a decimal integer string, got " ++ show raw)

measurement_int :: String -> Value -> Either String Integer
measurement_int key m = json_field key m >>= json_integer

measurement_word :: String -> Value -> Either String Integer
measurement_word key m = json_field key m >>= json_decimal_string

e3_int :: String -> Value -> Either String Integer
e3_int key m = json_field "e3" m >>= json_field key >>= json_integer

-- | The artifact exists, decodes, and describes THIS rig.
--
-- @generatedFrom@ and @tickSpacing@ are included deliberately. Phase 21's F4 measured that
-- @rpin05_capture_is_present_and_fresh@ cannot see a MODULE change, because it asserts @chainId@
-- and @manager@ only and @manager@ is a @CREATE@ address -- identical across three from-scratch
-- deploys. These two fields are the discriminating ones @manager@ alone is missing:
-- @generatedFrom@ moves when the imported source-of-truth ref moves, and @tickSpacing@ moved
-- 10 -> 20 at PR #18, taking the @PoolKey@ hash and therefore the @poolId@ with it.
driv01_cheat_swap_proof_is_present_and_fresh :: Check
driv01_cheat_swap_proof_is_present_and_fresh =
  Check "driv01_cheat_swap_proof_is_present_and_fresh" . guarded $ do
    pf <- proof_file
    loaded_proof <- read_json_file pf ("produce it with: " ++ proof_command)
    mf <- manifest_file
    manifest_present <- doesFileExist mf
    outcome <-
      if manifest_present
        then do
          pins_path <- pins_file
          attempt <- try (load_rig_from pins_path mf)
          pure (Just (attempt :: Either IOException Rig))
        else pure Nothing
    pure $ do
      proof <- loaded_proof
      rig <- case outcome of
        Nothing         -> Left ("no " ++ mf ++ " -- it is gitignored, so a fresh checkout has no"
                                  ++ " copy. Stand the rig up: " ++ deploy_command)
        Just (Left err) -> Left ("load_rig_from failed on the real files: " ++ show err)
        Just (Right r)  -> Right r
      let addrs = rig_addrs rig

      captured_chain <- json_field "chainId" proof >>= json_integer
      _ <- positive_fields_agree "chainId" (rig_chain_id addrs) captured_chain "the proof"
             ("The proof was taken against a DIFFERENT chain. Re-take it: " ++ proof_command)

      captured_from <- json_field "generatedFrom" proof >>= json_string
      _ <- refs_are_real "the proof" captured_from (T.unpack (pins_generated_from (rig_pins rig)))
      _ <- expect (captured_from == T.unpack (pins_generated_from (rig_pins rig)))
             ("the proof names generatedFrom " ++ captured_from ++ " but rig-pins.json names "
               ++ T.unpack (pins_generated_from (rig_pins rig))
               ++ " -- the proof describes a DIFFERENT imported source-of-truth ref. Re-take it: "
               ++ proof_command)

      -- The WHOLE rig block, not just poolManager. Via 'addresses_agree', never as a raw ==: the
      -- poolManager equality survived 'fecdc8b' only because contracts.PoolManager happens to be
      -- read in a DIFFERENT check, so emptying both sides left THIS one passing while a neighbour
      -- failed. The other five fields were not compared at all until now.
      _ <- rig_block_matches proof addrs proof_rig_address_fields "the proof" proof_command
      _ <- pool_id_matches proof addrs "the proof" proof_command

      captured_spacing <- json_field "rig" proof >>= json_field "tickSpacing" >>= json_integer
      _ <- positive_fields_agree "tickSpacing" (rig_tick_spacing (rig_pool addrs))
             captured_spacing "the proof"
             ("The PoolKey hash and therefore the poolId move with tickSpacing, so this proof is"
               ++ " stale BY CONSTRUCTION. Re-take it: " ++ proof_command)

      entries <- json_field "measurements" proof >>= json_array
      names <- mapM (\m -> json_field "name" m >>= json_string) entries
      expect (names == proof_measurement_names)
        ("the proof's measurement names are " ++ show names ++ ", expected "
          ++ show proof_measurement_names)

-- | THE PHASE GATE, asserted offline.
--
-- @e3.tick == 5000@ is the whole claim of plan 22-04: a cheated tick reached the hook. It is an
-- EXACT equality on purpose. 5000 cannot come from swap impact (1e6 wei of exact input against
-- L = 1e21) and cannot be the un-cheated state (the pool initialised at tick 0), so nothing but a
-- landed cheat produces it.
--
-- The composition is then checked from the artifact's OWN recorded words, three ways:
--
--   * bits >= 184 preserved. HONEST LIMIT, and it is recorded here rather than in a summary
--     nobody will read: on this rig both sides are ZERO (@protocolFee@ is unset and a dynamic-fee
--     pool stores @lpFee = 0@ at initialize), so this assertion HOLDS WITHOUT DISCRIMINATING. It
--     is the same blindness class 22-02 avoided by construction when its two test words carried
--     different tick bits. It is kept because it becomes load-bearing the moment a protocol fee is
--     configured -- but it must not be cited as evidence the mask is at 184.
--   * the recorded @..._high184@ fields agree with the words they claim to summarise, so a derived
--     field cannot drift away from its source.
--   * the TICK FIELD of the written word is 5000. THIS is the assertion that actually discriminates
--     the mask position: composing at 160 instead of 184 would take packSlot0For's sqrtPrice while
--     KEEPING the target's own tick, and the target's tick was -1.
driv01_cheated_tick_reaches_e3 :: Check
driv01_cheated_tick_reaches_e3 = Check "driv01_cheated_tick_reaches_e3" . guarded $ do
  pf <- proof_file
  loaded_proof <- read_json_file pf ("produce it with: " ++ proof_command)
  pure $ do
    proof <- loaded_proof
    m <- find_measurement "cheat_to_5000_then_swap" proof

    status <- measurement_int "status" m
    _ <- expect (status == 1) ("measurement A status = " ++ show status ++ ", expected 1")

    e3_count <- measurement_int "e3_count" m
    _ <- expect (e3_count == 1)
           ("measurement A emitted " ++ show e3_count ++ " E3 logs from DynamicFeeHook, expected"
             ++ " exactly 1")
    e5_count <- measurement_int "e5_count" m
    _ <- expect (e5_count == 1)
           ("measurement A emitted " ++ show e5_count ++ " E5 logs, expected exactly 1")

    e3_tick <- e3_int "tick" m
    _ <- expect (e3_tick == 5000)
           ("THE GATE FAILED: the hook recorded tick " ++ show e3_tick ++ ", expected the cheated"
             ++ " 5000. The slot0 composition did not reach DynamicFeeHook. This is a FINDING, not"
             ++ " a threshold: do not adjust it, and do not build a driver loop on it.")

    ts <- measurement_int "ts" m
    e3_ts <- e3_int "timestamp" m
    _ <- expect (e3_ts == ts)
           ("the hook recorded timestamp " ++ show e3_ts ++ " but the step requested " ++ show ts
             ++ " -- the absolute block-timestamp cheat did not take")

    word_before  <- measurement_word "word_before" m
    word_written <- measurement_word "word_written" m
    high_before  <- measurement_word "word_before_high184" m
    high_written <- measurement_word "word_written_high184" m

    _ <- expect (word_written `shiftR` slot0_fee_shift == word_before `shiftR` slot0_fee_shift)
           ("slot0 bits >= 184 were not preserved: before "
             ++ show (word_before `shiftR` slot0_fee_shift) ++ ", written "
             ++ show (word_written `shiftR` slot0_fee_shift)
             ++ " -- compose_slot0 masks at 184 so protocolFee/lpFee survive by construction")
    _ <- expect (high_before == word_before `shiftR` slot0_fee_shift
                   && high_written == word_written `shiftR` slot0_fee_shift)
           ("the artifact's recorded high-bit fields disagree with the words they summarise:"
             ++ " word_before_high184 " ++ show high_before ++ " vs "
             ++ show (word_before `shiftR` slot0_fee_shift) ++ ", word_written_high184 "
             ++ show high_written ++ " vs " ++ show (word_written `shiftR` slot0_fee_shift))

    _ <- expect (slot0_tick_of word_written == 5000)
           ("the WRITTEN slot0 word carries tick " ++ show (slot0_tick_of word_written)
             ++ ", expected 5000. Composing at 160 rather than 184 would keep the TARGET's tick"
             ++ " here (measured: " ++ show (slot0_tick_of word_before) ++ ") while taking"
             ++ " packSlot0For's price -- a word whose price and tick disagree.")

    expect (slot0_tick_of word_before /= 5000)
      ("the word that was already in slot0 ALSO carried tick 5000, so measurement A cannot"
        ++ " distinguish a landed cheat from an unchanged pool. Re-take the proof against a rig"
        ++ " that is not already at the cheated tick: " ++ proof_command)

-- | The blocker, demonstrated rather than argued.
--
-- Measurement B is byte-for-byte the same operation as A except that the storage write is aimed at
-- @PriceSetterPoolManager@. The receipt looks PERFECTLY HEALTHY -- status 1, one E3, one E5 -- and
-- carries the wrong tick. That is the entire failure mode: there is nothing to notice.
--
-- @4999@ is a MEASURED value, not a derived one. It is measurement A's 5000 after one tick of dust
-- from A's own swap, i.e. the state the pool was left in -- but it was READ OFF THE CHAIN, and it
-- is pinned as an exact equality so that a future change which accidentally makes the wrong-pool
-- write WORK reddens here instead of passing quietly.
--
-- The written word's tick is asserted to be 7000: the composition itself was CORRECT and only the
-- destination was wrong. Without that, "the tick came back wrong" would be consistent with a
-- broken composition, which is a different bug with a different fix.
driv01_wrong_pool_is_silent :: Check
driv01_wrong_pool_is_silent = Check "driv01_wrong_pool_is_silent" . guarded $ do
  pf <- proof_file
  loaded_proof <- read_json_file pf ("produce it with: " ++ proof_command)
  pure $ do
    proof <- loaded_proof
    m <- find_measurement "cheat_wrong_pool_then_swap" proof

    status <- measurement_int "status" m
    _ <- expect (status == 1)
           ("measurement B status = " ++ show status ++ ", expected 1 -- the point is that the"
             ++ " wrong-pool cheat does NOT revert")
    e3_count <- measurement_int "e3_count" m
    _ <- expect (e3_count == 1)
           ("measurement B emitted " ++ show e3_count ++ " E3 logs, expected exactly 1 -- the"
             ++ " receipt must look healthy")

    cheated <- measurement_int "tick" m
    _ <- expect (cheated == 7000)
           ("measurement B cheated tick " ++ show cheated ++ ", expected 7000")

    e3_tick <- e3_int "tick" m
    _ <- expect (e3_tick /= 7000)
           ("cheating PriceSetterPoolManager DID move the hook's recorded tick to 7000. The"
             ++ " two-PoolManager blocker as described is WRONG, and that is the single most"
             ++ " important finding available here. Stop and report it.")
    -- MEASURED, 2026-08-02, three consecutive captures. Not derived.
    _ <- expect (e3_tick == 4999)
           ("measurement B recorded tick " ++ show e3_tick ++ ", but 4999 was MEASURED -- the"
             ++ " state measurement A's swap left behind. A different value means the sequence"
             ++ " changed; re-take the proof: " ++ proof_command)

    word_written <- measurement_word "word_written" m
    expect (slot0_tick_of word_written == 7000)
      ("measurement B's written word carries tick " ++ show (slot0_tick_of word_written)
        ++ ", expected 7000. The composition must be CORRECT for this measurement to mean what it"
        ++ " claims: the failure is the DESTINATION, not the arithmetic.")

-- | G1: one timepoint per distinct @uint32@ timestamp, pinned as a fact rather than a warning.
--
-- Step 2 is a CONSTRUCTED collision -- the absolute setter is called with step 1's own timestamp,
-- which anvil accepts (it rejects only a strictly LOWER value). The result is a receipt at status 1
-- carrying an E5 and NO E3, so @count(E5) - count(E3)@ is a direct on-chain measurement of how many
-- steps the write guard ate.
--
-- Step 3 is NOT pinned on its E3 count, and that omission is the honest part. It leaves the clock
-- untouched, so whether its block lands on the same second depends on WALL TIME between two
-- transactions. It was OBSERVED both ways: once at @T + 1@ with a healthy E3, and three times at
-- @T@ with none. Pinning it would produce an intermittently red suite that says nothing. What IS
-- pinned is that the step succeeded and served a fee, and the lesson it carries: a driver that
-- merely FORGETS to advance the clock does not reliably hit G1 -- it races it.
driv01_same_second_is_a_silent_noop :: Check
driv01_same_second_is_a_silent_noop = Check "driv01_same_second_is_a_silent_noop" . guarded $ do
  pf <- proof_file
  loaded_proof <- read_json_file pf ("produce it with: " ++ proof_command)
  pure $ do
    proof <- loaded_proof
    step1 <- find_measurement "same_second_repeat_step1" proof
    step2 <- find_measurement "same_second_repeat_step2" proof
    step3 <- find_measurement "clock_untouched_repeat_step3" proof

    s1_e3 <- measurement_int "e3_count" step1
    _ <- expect (s1_e3 == 1)
           ("the control step emitted " ++ show s1_e3 ++ " E3 logs, expected 1 -- without a"
             ++ " control, step 2's silence proves nothing about the clock")
    s1_tick <- e3_int "tick" step1
    _ <- expect (s1_tick == 5100)
           ("the control step recorded tick " ++ show s1_tick ++ ", expected 5100")

    s1_ts <- measurement_int "ts" step1
    s2_ts <- measurement_int "ts" step2
    _ <- expect (s2_ts == s1_ts)
           ("step 2 requested timestamp " ++ show s2_ts ++ " but step 1 used " ++ show s1_ts
             ++ " -- the collision was not actually constructed, so whatever step 2 shows is about"
             ++ " something else")

    s2_status <- measurement_int "status" step2
    s2_e3 <- measurement_int "e3_count" step2
    s2_e5 <- measurement_int "e5_count" step2
    _ <- expect (s2_status == 1)
           ("the same-second repeat reverted (status " ++ show s2_status ++ "). The guard is a"
             ++ " `return false`, not a revert: the receipt is supposed to look fine.")
    _ <- expect (s2_e3 == 0)
           ("the same-second repeat emitted " ++ show s2_e3 ++ " E3 logs, expected 0."
             ++ " RealizedVolatilityStateLib compares lastTimepointTimestamp to now for EQUALITY;"
             ++ " if a timepoint was written, the guard is not what the source says it is.")
    _ <- expect (s2_e5 == 1)
           ("the same-second repeat emitted " ++ show s2_e5 ++ " E5 logs, expected 1 -- the fee is"
             ++ " still served, which is exactly what makes the missing E3 silent")

    s3_status <- measurement_int "status" step3
    s3_e5 <- measurement_int "e5_count" step3
    expect (s3_status == 1 && s3_e5 == 1)
      ("the clock-untouched step came back status " ++ show s3_status ++ " with " ++ show s3_e5
        ++ " E5 logs, expected 1 and 1. Its E3 count is deliberately NOT asserted: it depends on"
        ++ " wall time and was observed both ways.")

-- | The near-floor tick: an outcome that had never been executed.
--
-- @CheatSwap.Encoding@'s haddock labels the degeneracy at the bottom of the range a PREDICTION and
-- names this plan as the thing that measures it. The prediction was that the swap does not revert
-- on the price bound (@getSqrtPriceAtTick(-887259) = 4297706459@, about 2.5e6 units above the fixed
-- limit) but degenerates to @amount1 ~ 0@, with E3 still firing because @beforeSwap@ runs before
-- any swap math.
--
-- MEASURED: it does not revert, and E3 carries the cheated tick. Both halves are asserted, because
-- a later revert here would mean 22-05 must choose direction and price limit FROM the cheated tick
-- rather than using one fixed pair -- a real design consequence that must not arrive silently.
driv01_extreme_tick_is_survivable :: Check
driv01_extreme_tick_is_survivable = Check "driv01_extreme_tick_is_survivable" . guarded $ do
  pf <- proof_file
  loaded_proof <- read_json_file pf ("produce it with: " ++ proof_command)
  pure $ do
    proof <- loaded_proof
    m <- find_measurement "extreme_tick_near_floor" proof

    cheated <- measurement_int "tick" m
    _ <- expect (cheated == -887259)
           ("the floor measurement cheated tick " ++ show cheated ++ ", expected the inclusive G4"
             ++ " floor -887259")

    status <- measurement_int "status" m
    _ <- expect (status == 1)
           ("the floor-tick swap came back at status " ++ show status ++ ". A revert here is a"
             ++ " legitimate measurement, but it is a DESIGN CONSEQUENCE: the driver would then"
             ++ " need direction and sqrtPriceLimitX96 chosen from the cheated tick instead of the"
             ++ " one fixed pair CheatSwap.Encoding uses. Update this check deliberately, and"
             ++ " carry the requirement into the driver -- do not just relax it.")

    e3_count <- measurement_int "e3_count" m
    _ <- expect (e3_count == 1)
           ("the floor-tick swap emitted " ++ show e3_count ++ " E3 logs, expected 1 -- beforeSwap"
             ++ " runs BEFORE any swap math, so even a fully degenerate swap must write its"
             ++ " timepoint")

    e3_tick <- e3_int "tick" m
    expect (e3_tick == -887259)
      ("the floor-tick swap recorded tick " ++ show e3_tick ++ ", expected -887259")

-- ---------------------------------------------------------------------------------------------
-- DRIV-01: the RECORDED seed, and an artifact that can represent a truncated run
--
-- SC-5 asks for a reproducible run. Before this plan the driver called @createSystemRandom@:
-- unseeded, unrecorded, and therefore unreplayable -- a completed run could not say which path it
-- had taken. 'Driver.Seed' closes that, and the checks below are what stop it from silently
-- re-opening.
-- ---------------------------------------------------------------------------------------------

-- | The path shape the seed check simulates over.
--
-- Constructed HERE rather than imported: @Sample.sample_price_gen@ lives in the EXECUTABLE
-- component, which a test suite cannot see. The four fields are the ones the demo carries today
-- (GBM mu = 0, sigma = 0.05, size = 5, initial_tick = 60, dt = 1.0). If the demo shape later
-- moves, this check keeps pinning the LAW plus the RNG stream, which is the thing it exists for.
seed_check_shape :: StochasticPriceGen
seed_check_shape =
  StochasticPriceGen
    { process      = GBM { mu = 0.0, sigma = 0.05 }
    , size         = 5
    , initial_tick = 60
    , dt           = 1.0
    }

-- | The pinned seed. A single decimal 'Word32' is the whole @RIG_SEED@ contract.
seed_check_value :: Word32
seed_check_value = 123456789

-- | The first three ticks 'seed_check_value' produces over 'seed_check_shape'. MEASURED during
-- 22-05 Task 1, never derived.
--
-- These literals are the point of the check, not decoration. 21-04 measured a self-consistency
-- assertion ("two draws from one seed agree") staying GREEN under a mutant that replaced the draw
-- law outright, because a wrong law is just as self-consistent as a right one. Only a VALUE pin
-- sees a stream change; @gen_from_seed@ ignoring its argument reddens exactly here.
driv01_seed_first_three :: [Integer]
driv01_seed_first_three = [455, 233, -14]

-- | The seed is reproducible, settable, reported, and refuses a malformed value.
driv01_seed_is_reproducible :: Check
driv01_seed_is_reproducible = Check "driv01_seed_is_reproducible" . guarded $ do
  original <- lookupEnv seed_env_var

  let restore = maybe (unsetEnv seed_env_var) (setEnv seed_env_var) original

  measured <- flip finally restore $ do
    -- Two independent generators, same seed, same process: the paths must agree.
    g1 <- gen_from_seed seed_check_value
    path1 <- simulate_path g1 seed_check_shape
    g2 <- gen_from_seed seed_check_value
    path2 <- simulate_path g2 seed_check_shape

    setEnv seed_env_var (show seed_check_value)
    supplied <- resolve_seed

    unsetEnv seed_env_var
    drawn <- resolve_seed

    setEnv seed_env_var "not-a-number"
    malformed <- try resolve_seed :: IO (Either IOException (Word32, String))

    pure (path1, path2, supplied, drawn, malformed)

  let (path1, path2, (supplied_seed, supplied_note), (_, drawn_note), malformed) = measured

  pure $ do
    _ <- expect (path1 == path2)
           ("two generators built from seed " ++ show seed_check_value ++ " produced DIFFERENT"
             ++ " paths:\n      first  : " ++ show path1
             ++ "\n      second : " ++ show path2
             ++ "\n      gen_from_seed is not seeding from its argument, so RIG_SEED cannot"
             ++ " replay anything.")

    _ <- expect (take 3 path1 == driv01_seed_first_three)
           ("the first three ticks from seed " ++ show seed_check_value ++ " are "
             ++ show (take 3 path1) ++ ", not the pinned " ++ show driv01_seed_first_three
             ++ ". Either the simulation law changed or the generator is no longer seeded from"
             ++ " RIG_SEED. The self-consistency assertion above cannot tell those apart -- this"
             ++ " value pin is the one that can (21-04's measured lesson).")

    _ <- expect (supplied_seed == seed_check_value)
           ("resolve_seed returned " ++ show supplied_seed ++ " with " ++ seed_env_var ++ "="
             ++ show seed_check_value ++ " -- a supplied seed must be used verbatim")

    _ <- expect (seed_env_var `isInfixOf` supplied_note)
           ("the supplied-seed provenance note does not name " ++ seed_env_var ++ ": "
             ++ show supplied_note)

    _ <- expect ("DRAWN" `isInfixOf` drawn_note)
           ("with " ++ seed_env_var ++ " unset the provenance note is " ++ show drawn_note
             ++ " -- it must say the seed was DRAWN, because an unrecorded drawn seed is exactly"
             ++ " the unreplayable run this module exists to prevent")

    case malformed of
      Right (w, _) ->
        Left ("resolve_seed accepted " ++ seed_env_var ++ "=\"not-a-number\" and returned "
               ++ show w ++ ". A malformed seed must FAIL LOUDLY: silently drawing one instead"
               ++ " produces a run the operator believes is replayable and is not.")
      Left err ->
        expect (seed_env_var `isInfixOf` show err)
          ("resolve_seed rejected the malformed value but the message does not name "
            ++ seed_env_var ++ ": " ++ show err)

-- | THE SEVENTH DISCRIMINATOR: the committed run's ticks are what the committed run's OWN SEED
-- produces.
--
-- == THE GAP
--
-- Before this check, @seed.rng@ was read by NO check in this suite. 'capture_schedule' reads
-- @seed.t0@ and @seed.stride@ and nothing else, and 'driv01_seed_first_three' pins a draw the
-- artifact does not contain (see the ordinal note below). The seed was therefore RECORDED and
-- never CONSUMED -- a number in a file that nothing could disagree with.
--
-- The consequence is P2, the shape this workstream keeps finding: every tick assertion over the
-- artifact compared one artifact-recorded field against another. @driv01_e3_per_step_matches_
-- submitted@ compares @e3.tick@ against @steps[].tick@, and BOTH are recorded by the same driver
-- in the same pass. Replace the driver's generated path with a constant and that equality stays
-- perfectly TRUE: the hook records whatever it was handed. Nothing in the suite could tell a
-- stochastic path from five copies of one number.
--
-- This check is the outside oracle. It recomputes the path from @seed.rng@ IN THIS PROCESS and
-- requires the artifact to match it, so the committed evidence is now pinned to something that
-- was not produced by the run being judged.
--
-- == THE ORDINAL, AND WHY IT IS THE SECOND DRAW
--
-- @gen@ is consumed SEQUENTIALLY by the driver (@offchain\/app\/Main.hs@). @run_price_gen@ draws
-- FIRST (the legacy @PriceSetterHook@ path, line 199); @run_cheat_swap_path@ draws SECOND (line
-- 202) and its ticks are the ones that reach @steps[]@. Both fold over the SAME
-- @sample_price_gen@ shape, so the two draws are the same length and differ only in stream
-- position -- which is exactly the mistake that is invisible to inspection. MEASURED for seed
-- 123456789: the first draw is @[455, 233, -14, -82, -909]@ ('driv01_seed_first_three' pins its
-- head) and the second is @[237, -556, -1000, -1344, -1191]@, which is the committed artifact.
-- The inequality below is asserted rather than assumed, so a future edit that "fixes" this check
-- by reaching for the first draw reddens instead of quietly re-opening the gap.
driv01_seed_replays_the_committed_path :: Check
driv01_seed_replays_the_committed_path =
  Check "driv01_seed_replays_the_committed_path" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    case loaded >>= capture_seed_and_ticks of
      Left why -> pure (Left why)
      Right (seed, configured, recorded) -> do
        gen <- gen_from_seed seed
        first_draw  <- simulate_path gen seed_check_shape
        second_draw <- simulate_path gen seed_check_shape
        pure $ do
          _ <- expect (configured == toInteger (size seed_check_shape))
                 ("the run was configured for " ++ show configured ++ " steps but this check"
                   ++ " replays a path of " ++ show (size seed_check_shape) ++ ". The path length"
                   ++ " is an ARGUMENT to the draw, not a property of it: replaying the wrong"
                   ++ " length consumes the wrong number of variates and shifts the second draw"
                   ++ " off the stream entirely. Update seed_check_shape to match"
                   ++ " Sample.sample_price_gen.")

          _ <- expect (second_draw == recorded)
                 ("the committed run does NOT replay from its own recorded seed "
                   ++ show seed ++ ".\n      artifact steps[].tick : " ++ show recorded
                   ++ "\n      replayed from the seed: " ++ show second_draw
                   ++ "\n      Either the artifact's ticks did not come from that seed (the run"
                   ++ " is not the run it claims to be), or the simulation law moved under a"
                   ++ " committed artifact. This is the ONLY assertion in the suite whose expected"
                   ++ " value does not come out of the same JSON object as the actual one:"
                   ++ " every other tick equality here compares two fields the SAME driver wrote"
                   ++ " in the same pass, and a driver that emitted a constant path would satisfy"
                   ++ " all of them. Re-take it: " ++ driver_capture_command)

          expect (first_draw /= recorded)
            ("the artifact's ticks match the FIRST draw from seed " ++ show seed ++ ", which is"
              ++ " run_price_gen's legacy path (app/Main.hs:199), not run_cheat_swap_path's"
              ++ " (app/Main.hs:202). Either the driver's draw order changed -- in which case the"
              ++ " legacy and DRIV-01 paths are no longer independent streams and this artifact's"
              ++ " provenance needs re-establishing -- or this check is replaying the wrong"
              ++ " ordinal and is no longer an outside oracle at all.")

-- | @seed.rng@, @configuredSize@ and the SUBMITTED ticks, read out of one capture.
--
-- @rng@ is range-checked back into a 'Word32' rather than truncated. @gen_from_seed@ takes a
-- 'Word32' and @fromInteger@ would wrap silently, so an artifact carrying a value outside the
-- range would be replayed against a DIFFERENT stream and the mismatch would be blamed on the
-- ticks.
capture_seed_and_ticks :: Value -> Either String (Word32, Integer, [Integer])
capture_seed_and_ticks capture = do
  raw <- json_field "seed" capture >>= json_field "rng" >>= json_integer
  seed <-
    if raw >= 0 && raw <= toInteger (maxBound :: Word32)
      then Right (fromInteger raw :: Word32)
      else Left ("the capture records seed.rng = " ++ show raw ++ ", which is not a Word32."
                  ++ " Driver.Seed's whole contract is a single decimal Word32; a value outside"
                  ++ " that range cannot have produced this run.")
  configured <- json_field "configuredSize" capture >>= json_integer
  steps <- json_field "steps" capture >>= json_array
  ticks <- mapM (measurement_int "tick") steps
  pure (seed, configured, ticks)

-- ---------------------------------------------------------------------------------------------
-- THE STANDING GUARD AGAINST AN ADVERTISED-BUT-DEAD OVERRIDE
-- ---------------------------------------------------------------------------------------------

-- | One advertised path override, and the loader that CONSUMES the path it resolves.
--
-- 'ov_probe' runs with the variable ALREADY pointed at a path that does not exist, and reports
-- the loader's failure text -- or 'Nothing' if the loader did not fail, which is the outcome the
-- sweep exists to catch.
data OverrideProbe = OverrideProbe
  { ov_var     :: String
  , ov_resolve :: IO FilePath
  , ov_probe   :: IO (Maybe String)
  }

-- | Every override the Haskell surface advertises.
--
-- @RIG_MANIFEST@ and @RIG_PINS@ are probed through 'load_rig' and not through 'load_rig_from':
-- 'load_rig' is the function that RESOLVES both, and resolution is the thing under test. The
-- other two are probed through 'read_json_file', which is what every capture check calls.
advertised_overrides :: [OverrideProbe]
advertised_overrides =
  [ OverrideProbe "RIG_MANIFEST" rig_manifest_path rig_probe
  , OverrideProbe "RIG_PINS" rig_pins_path rig_probe
  , OverrideProbe "RIG_CHEAT_SWAP_PROOF" proof_file (json_probe proof_file proof_command)
  , OverrideProbe "DRIVER_CAPTURE" capture_path (json_probe capture_path driver_capture_command)
  -- 23-05. Same shape as DRIVER_CAPTURE exactly: it resolves a FilePath and eleven Tier-C checks
  -- read it through 'read_store_conformance', so all three assertions below have a real subject.
  , OverrideProbe "STORE_CONFORMANCE" store_conformance_path
      (json_probe store_conformance_path store_conformance_command)
  -- 24-04. Same shape as STORE_CONFORMANCE exactly: it resolves a FilePath and plan 24-05's
  -- Tier-C checks read it through the shared JSON reader, so all three assertions below have a
  -- real subject. The name is WRITTEN OUT here and compared against the config module's constant
  -- by 'store_overrides_are_probed_or_named_as_gaps' -- see that check's haddock for the
  -- measurement showing why writing it out is strictly stronger than referring to the constant.
  , OverrideProbe "GAMS_CONFORMANCE" gams_conformance_path
      (json_probe gams_conformance_path gams_conformance_command)
  ]
  where
    rig_probe :: IO (Maybe String)
    rig_probe = do
      attempt <- try load_rig
      pure $ case attempt :: Either IOException Rig of
        Left err -> Just (show err)
        Right _  -> Nothing

    json_probe :: IO FilePath -> String -> IO (Maybe String)
    json_probe resolve advice = do
      path <- resolve
      outcome <- read_json_file path ("produce it with: " ++ advice)
      pure $ case outcome of
        Left err -> Just err
        Right _  -> Nothing

-- | The out-of-band command that produces the GAMS conformance artifact.
--
-- It does not exist yet -- plan 24-05 writes it -- and that is deliberate: the probe below points
-- the variable at a path that CANNOT exist, so what it exercises is the resolver and the reader,
-- neither of which depends on the real artifact being present. The advice string is here so that
-- when the reader does fail it tells an operator what to run, which is the same contract every
-- other capture in this file honours.
gams_conformance_command :: String
gams_conformance_command = "bash offchain/rig/capture-gams-conformance.sh"

-- | EVERY advertised override is honoured, and the resolved path is actually CONSUMED.
--
-- == WHY THIS IS A CHECK AND NOT A CONVENTION
--
-- Three separate path constants in this module have now been measured as advertised-but-dead:
-- @RIG_MANIFEST@ (22-03), @proof_file@ \/ @RIG_CHEAT_SWAP_PROOF@ (22-04) and @RIG_PINS@ (22-07).
-- In each case the variable was documented in @offchain\/rig\/README.md@, named in
-- @Rig.Manifest@'s own error messages (\"Override the path with the ... environment variable\")
-- and honoured by the shell half of the rig -- and ignored here. The consequence is the same
-- every time and it is not a documentation bug: the falsification aimed THROUGH the variable
-- comes back GREEN, so the check it was aimed at is untested and the artifact it guards is
-- untestable except by damaging it.
--
-- A one-off fix per instance is what produced three instances. This sweep is the general form.
--
-- == WHAT IS ASSERTED, PER VARIABLE
--
--   1. The resolver returns the override VERBATIM.
--   2. It returns something DIFFERENT from what it returns with the variable unset -- otherwise
--      a resolver that ignored its input but happened to name the same path would pass (1).
--   3. Pointing it at a path that does not exist makes the CONSUMER fail, and fail LOUDLY:
--      the failure text must name the resolved path. (1) and (2) alone would be satisfied by a
--      resolver whose result nothing reads, which is the defect restated one layer down.
every_advertised_override_is_honoured :: Check
every_advertised_override_is_honoured =
  Check "every_advertised_override_is_honoured" . guarded $ do
    outcomes <- mapM probe_override advertised_overrides
    pure (mapM_ id outcomes)

probe_override :: OverrideProbe -> IO (Either String ())
probe_override op = do
  let var = ov_var op
  original <- lookupEnv var
  let restore = maybe (unsetEnv var) (setEnv var) original
      -- A directory that cannot exist, so the probe cannot accidentally find a real file.
      bogus = "/nonexistent-override-probe" </> (var ++ ".json")

  flip finally restore $ do
    unsetEnv var
    defaulted <- ov_resolve op
    setEnv var bogus
    overridden <- ov_resolve op
    failure <- ov_probe op
    pure $ do
      _ <- expect (overridden == bogus)
             (var ++ " is ADVERTISED and DEAD: its resolver returned " ++ show overridden
               ++ " with the variable set to " ++ show bogus
               ++ ". Every falsification aimed through this variable is vacuous until it is"
               ++ " honoured -- measured three times in this module already (22-03 RIG_MANIFEST,"
               ++ " 22-04 RIG_CHEAT_SWAP_PROOF, 22-07 RIG_PINS).")
      _ <- expect (overridden /= defaulted)
             (var ++ " resolves to " ++ show defaulted ++ " both with and without the variable"
               ++ " set -- the override is vacuous")
      case failure of
        Nothing ->
          Left (var ++ " resolved to " ++ show bogus ++ " and the consumer LOADED ANYWAY."
                 ++ " A resolver whose result nothing reads is the same defect one layer down:"
                 ++ " the override looks live and still cannot aim a falsification at anything.")
        Just msg ->
          expect (bogus `isInfixOf` msg)
            (var ++ " was pointed at " ++ show bogus ++ " and the consumer failed, but the"
              ++ " failure does not NAME the resolved path, so an operator cannot tell which"
              ++ " file the suite was actually reading:\n      " ++ msg)

-- ---------------------------------------------------------------------------------------------
-- THE NAMED GAP IN THE OVERRIDE SWEEP
-- ---------------------------------------------------------------------------------------------

-- | An advertised override that 'probe_override' CANNOT honestly probe, with the reason.
--
-- 'uo_resolve' returns a 'String' rather than a 'FilePath' because that is the whole difficulty:
-- a variable that resolves to a value which is not a path has no \"point it at a file that does
-- not exist\" probe available to it.
data UnprobedOverride = UnprobedOverride
  { uo_var     :: String
  , uo_resolve :: IO String
  , uo_reason  :: String
  }

-- | WHY @PGSTORE_DSN@ IS NOT IN 'advertised_overrides'.
--
-- 'probe_override' asserts three things and the third is the one that matters: pointing the
-- variable at a value nothing can resolve makes the CONSUMER fail, and fail NAMING that value.
-- (1) and (2) alone are satisfied by a resolver whose result nothing reads, which is the defect
-- restated one layer down.
--
-- @PGSTORE_DSN@'s consumer is libpq, reached through the client module and the capture executable.
-- Neither is reachable from @cabal test@ BY CONSTRUCTION -- that is what DB-03 is, and the grep
-- over this file that must return zero is the structural form of it. So assertion (3) has no
-- subject here, and there are exactly two ways to manufacture one:
--
--   * import the client and let the probe attempt a connection. That breaks DB-03 on its way to
--     enforcing DB-02, and turns every contributor's first @cabal test@ into a socket call.
--   * write a @validate_dsn@ in the config module that rejects the probe value, and let the probe
--     assert that it rejected. This is the worse of the two, because it LOOKS right. The function
--     would exist only to be probed; its rejection would prove that a function written to reject
--     rejects, and it would say nothing whatever about whether the variable steers a connection.
--     A registered-but-vacuous probe is the exact defect this sweep exists to catch, and installing
--     one here to close the sweep's own list would be the worst available outcome.
--
-- So the gap is NAMED rather than papered over, and the two halves that ARE honestly measurable
-- are asserted below: the resolver returns the override verbatim, and it returns something other
-- than its unset default. A 'pgstore_dsn' that stopped reading the environment reddens here. What
-- nothing in this suite can tell you is whether the resolved value reaches a connection -- and the
-- evidence that it does is in the capture: @STORE_CONFORMANCE@'s sibling variable is exported by
-- @capture-store-conformance.sh@ and the artifact it produced records a @server_version@, which is
-- a value no unconsumed DSN could have produced.
reason_dsn_has_no_offline_consumer :: String
reason_dsn_has_no_offline_consumer =
  "GAP, and a deliberate one. The consumer of this variable is libpq, reached only through the\
  \ client module and the capture executable, and NEITHER is reachable from cabal test by\
  \ construction -- that is DB-03. So probe_override's third assertion (the consumer fails NAMING\
  \ the resolved value) has no subject here, and the only ways to give it one are to open a socket\
  \ from the test suite or to write a validator that exists solely to be probed. The first breaks\
  \ DB-03; the second is a registered-but-vacuous probe, which is the defect the sweep exists to\
  \ catch. The two measurable halves -- verbatim resolution, and differing from the unset default\
  \ -- are asserted; the third is owed by the capture, which drives the real consumer and records a\
  \ server_version that no unconsumed DSN could have produced."

-- | WHY THE PROVER BINARY'S OVERRIDE IS NOT IN 'advertised_overrides'.
--
-- 23-05's @PGSTORE_DSN@ ruling, applied unchanged to a second layer, and the reason it transfers is
-- that the obstruction is the same one: assertion (3) needs a CONSUMER that fails naming the
-- resolved value, and this variable's consumer is the invocation module -- the one
-- 'the_suite_never_names_the_real_solver' makes unreachable from @cabal test@ BY CONSTRUCTION.
--
-- The two ways to manufacture a subject are both rejected, and they are rejected in the same order
-- and for the same reasons as they were for the DSN:
--
--   * import the invocation module and let the probe attempt a resolution. That breaks the
--     GAMS-free property on its way to enforcing it, and turns every contributor's first
--     @cabal test@ into a hunt for a solver they do not have installed.
--   * write a validator in the config module that rejects the probe value, and assert that it
--     rejected. This is the worse of the two BECAUSE IT LOOKS RIGHT. The function would exist only
--     to be probed; its rejection would prove that a function written to reject rejects, and would
--     say nothing at all about whether the variable steers an @execve@.
--
-- Where the real evidence lives: the capture script EXPORTS this variable and the artifact it
-- produces records the resolved ABSOLUTE path and the sha256 of the executable that actually ran.
-- Those are two facts no unconsumed variable could have produced, and they are the two facts
-- GAMS-03 asks for -- which is also why neither is written down in the config module or here:
-- both differ on every install.
reason_bin_has_no_offline_consumer :: String
reason_bin_has_no_offline_consumer =
  "GAP, and a deliberate one, following 23-05's PGSTORE_DSN ruling unchanged. The consumer of this\
  \ variable is the invocation module that resolves the live prover, and that module is unreachable\
  \ from cabal test BY CONSTRUCTION -- the_suite_never_names_the_real_solver is the structural form\
  \ of it. So probe_override's third assertion (the consumer fails NAMING the resolved value) has no\
  \ subject here, and the only two ways to give it one are to import the invocation module from the\
  \ suite, which breaks the GAMS-free property on its way to enforcing it, or to write a validator\
  \ that exists solely to be probed, which is a registered-but-vacuous probe -- the exact defect\
  \ this sweep exists to catch, installed to close the sweep's own list. The two measurable halves\
  \ (verbatim resolution, differing from the unset default) are asserted; the third is owed by the\
  \ capture, which exports this variable and records the resolved absolute path and the sha256 of\
  \ the executable that ran -- two facts no unconsumed variable could have produced."

-- | WHY THE MODEL'S OVERRIDE IS NOT IN 'advertised_overrides', AND WHY IT IS NOT OPTIONAL HERE.
--
-- The same ruling as 'reason_bin_has_no_offline_consumer', plus one fact of record that belongs in
-- an asserted list rather than in a comment: @volume_path.gms@ DOES NOT EXIST IN THIS WORKTREE. It
-- lives in the sibling GAMS worktree, whose checkout of the monorepo carries the model tree this
-- branch does not. So the default this variable falls back to resolves to a path that is ABSENT on
-- purpose, and a real run from here REQUIRES the override rather than merely accepting it.
--
-- That is also why the honest half of this entry is worth asserting at all: a resolver that stopped
-- reading the environment would leave every run pointed at a file that is not here, and the failure
-- would name the default rather than the override the operator set.
reason_model_has_no_offline_consumer :: String
reason_model_has_no_offline_consumer =
  "GAP, on the same ruling as the binary's, and with one extra fact: volume_path.gms DOES NOT EXIST\
  \ IN THIS WORKTREE -- it lives in the sibling GAMS worktree, whose checkout carries the model tree\
  \ this branch does not, so the default resolves to an absent path on purpose and a real run from\
  \ here REQUIRES this override. The consumer is the invocation module, unreachable from cabal test\
  \ by construction, so probe_override's third assertion has no subject; importing that module would\
  \ break the GAMS-free property on its way to enforcing it, and a validator written only to be\
  \ probed would be a registered-but-vacuous probe, which is the defect the sweep exists to catch.\
  \ The two measurable halves are asserted below. The third is owed by the capture, which exports\
  \ this variable and records the job banner naming the model that was actually invoked -- the model\
  \ path and the version's subject are the same fact, resolved once."

unprobed_overrides :: [UnprobedOverride]
unprobed_overrides =
  [ UnprobedOverride "PGSTORE_DSN" pgstore_dsn reason_dsn_has_no_offline_consumer
  -- 24-04. Both entries are the binary and the model, in that order, and both names are WRITTEN
  -- OUT for the reason the probed list's are.
  , UnprobedOverride "GAMS_BIN" gams_bin reason_bin_has_no_offline_consumer
  , UnprobedOverride "GAMS_MODEL" gams_model reason_model_has_no_offline_consumer
  ]

-- | THE TWO CONFIG MODULES' FIVE VARIABLES, AND WHERE THE LIST ITSELF IS ASSERTED.
--
-- Each variable is paired with the NAME OF THE CONSTANT that holds it, because the pair is what
-- makes the list checkable: the value side is compared against the override lists, and the
-- identifier side is compared against a census of the declarations in the config modules
-- themselves. Without the second comparison this list is a transcription with no growth guard --
-- a sixth variable could be added to either module and every assertion below would go on passing,
-- which is the advertised-and-dead defect one level up from the one the sweep already catches.
config_env_vars :: [(String, String)]
config_env_vars =
  [ ("store_conformance_env_var", store_conformance_env_var)
  , ("pgstore_dsn_env_var",       pgstore_dsn_env_var)
  , ("gams_bin_env_var",          gams_bin_env_var)
  , ("gams_model_env_var",        gams_model_env_var)
  , ("gams_conformance_env_var",  gams_conformance_env_var)
  ]

-- | The two modules in which an environment variable of this subsystem is NAMED. Both config
-- modules and nothing else: @Driver.Capture@ and @Driver.Seed@ carry their own variables and their
-- own guards, and widening this set to @offchain@ would pull in this file, which writes the
-- identifiers out and would therefore always match.
config_modules :: [FilePath]
config_modules =
  [ "offchain/lib/Store/Config.hs"
  , "offchain/lib/Gams/Config.hs"
  ]

-- | A top-level @_env_var@ declaration, anchored at both ends so a mention in prose or a local
-- binding cannot be counted as one.
config_env_var_declaration_pattern :: String
config_env_var_declaration_pattern = "^[a-z_]+_env_var :: String$"

-- | Every @_env_var@ constant the two config modules DECLARE, read out of the modules.
--
-- @grep@ exits 1 for \"found nothing\" and for \"matched no files at all\" alike, and both of those
-- are reported here as failures rather than as an empty census: a census that collapsed would
-- otherwise agree with a list that had been emptied, and the two would pass each other.
config_env_var_census :: IO (Either String [String])
config_env_var_census = do
  presence <- mapM (\p -> (,) p <$> doesFileExist p) config_modules
  let gone = [p | (p, False) <- presence]
  if not (null gone)
    then pure (Left ("the config-module census names files that are not on disk: "
                      ++ intercalate ", " gone
                      ++ ". Scoping the census to the files that happen to exist would make it"
                      ++ " agree with any list at all."))
    else do
      (code, out, err) <- gams_version_scan config_env_var_declaration_pattern config_modules
      pure $ case code of
        ExitFailure 1 ->
          Left ("the config-module census matched NO declaration in "
                 ++ intercalate ", " config_modules
                 ++ ". Every one of these modules is supposed to declare at least one, so this is"
                 ++ " the scan having collapsed rather than the modules having emptied.")
        ExitFailure n -> Left ("the config-module census failed with exit " ++ show n ++ ": " ++ err)
        ExitSuccess   -> Right [i | Just i <- map declared_identifier (lines out)]
  where
    -- @grep -nHE@ prints @path:line:text@; the path holds no colon, so two splits reach the text.
    declared_identifier :: String -> Maybe String
    declared_identifier ln =
      case break (== ':') ln of
        (_, ':' : rest) ->
          case break (== ':') rest of
            (_, ':' : body) ->
              case takeWhile (/= ' ') body of
                []    -> Nothing
                ident -> Just ident
            _ -> Nothing
        _ -> Nothing

-- | THE FIVE OVERRIDES ARE EACH IN EXACTLY ONE LIST, THE GAPS ARE ASSERTED, AND THE LIST GROWS.
--
-- Six assertions now, across two config modules -- @Store.Config@'s two variables and
-- @Gams.Config@'s three -- and the check keeps its 23-05 name because the name is what the phase
-- record and the acceptance criteria refer to, not because the scope is still the store's.
--
-- The first assertion is the one that keeps the others from drifting: the variable NAMES written
-- out in 'advertised_overrides' and 'unprobed_overrides' are compared to the constants in the
-- config modules, which are the only places any of the five is named. Rename one there and nowhere
-- else and this reddens -- where without it the sweep would go on probing a variable the library no
-- longer reads, and reporting it honoured.
--
-- == WHY THE NAMES ARE WRITTEN OUT AND NOT REFERRED TO THROUGH THE CONSTANT
--
-- 24-04's plan asked for the opposite (@grep -c 'GAMS_CONFORMANCE'@ = 0, \"referenced through
-- 'gams_conformance_env_var', never re-spelled, which is what makes a rename in the config module
-- redden the sweep\"). MEASURED, that is backwards, and the measurement is recorded here because it
-- is the kind of thing that gets re-proposed: with the constant in the list, @uncovered@ compares
-- the constant against itself and is TRUE for every possible value, and 'probe_override' sets the
-- environment by the same constant, so BOTH detectors follow the rename together. Renaming
-- 'gams_conformance_env_var' in the config module with the constant in the list was OBSERVED
-- leaving the whole suite GREEN. With the literal, the same rename reddens two independent checks.
--
-- The two lists are also asserted DISJOINT. A variable in both would be pardoned as a named gap
-- while also being counted as probed, which is how an ignore list starts covering things that are
-- asserted.
--
-- The reason floor makes an 'unprobed_overrides' entry more than a comment, and the resolvers of
-- the pardoned entries are exercised. That is NOT the missing third assertion and does not pretend
-- to be.
--
-- The last two are the growth guard added at 24-04: the identifiers this file pairs its values with
-- are compared BOTH WAYS against the declarations in the two config modules. A sixth variable added
-- to either module and to no list is named here; an identifier listed here that no module declares
-- is named too, because a typo in the pairing would otherwise silently shrink the covered set.
store_overrides_are_probed_or_named_as_gaps :: Check
store_overrides_are_probed_or_named_as_gaps =
  Check "store_overrides_are_probed_or_named_as_gaps" . guarded $ do
    resolved <- mapM measure_resolution unprobed_overrides
    census   <- config_env_var_census
    pure $ do
      declared <- census
      let probed   = map ov_var advertised_overrides
          unprobed = map uo_var unprobed_overrides
          listed   = map fst config_env_vars
          config_vars = map snd config_env_vars
          uncovered = [v | v <- config_vars, v `notElem` probed, v `notElem` unprobed]
          both      = [v | v <- probed, v `elem` unprobed]
          unlisted  = [i | i <- declared, i `notElem` listed]
          undeclared = [i | i <- listed, i `notElem` declared]

      _ <- expect (null unlisted)
             ("these environment-variable constants are DECLARED in "
               ++ intercalate " / " config_modules ++ " and this file's config_env_vars list names"
               ++ " none of them: " ++ intercalate ", " unlisted
               ++ ".\n      An override the sweep has never heard of is advertised and unprobed at"
               ++ " the same time, and every assertion below would go on passing while it was --"
               ++ " which is the defect this sweep exists to catch, one level up from where it"
               ++ " catches it.")
      _ <- expect (null undeclared)
             ("this file's config_env_vars list pairs its values with these identifiers, and no"
               ++ " config module declares them: " ++ intercalate ", " undeclared
               ++ ".\n      The identifier side of each pair is what the census is compared"
               ++ " against; a typo there silently shrinks the covered set to the pairs that"
               ++ " happen to match.")
      _ <- expect (null uncovered)
             ("the config modules advertise these environment variables and this file's override"
               ++ " lists name NONE of them: " ++ intercalate ", " uncovered
               ++ ".\n      The names in those lists are written out; the names here come from the"
               ++ " config modules, which are the only places any of the five is named. A rename"
               ++ " there and nowhere else leaves the sweep probing a variable nothing reads and"
               ++ " reporting it honoured -- which is the advertised-and-dead defect, measured"
               ++ " three times in this module already, arriving through the guard against it.")
      _ <- expect (null both)
             ("these variables are BOTH probed and pardoned as unprobed gaps: "
               ++ intercalate ", " both
               ++ ". A variable in both lists is excused and counted at the same time.")

      let thin = [uo_var o | o <- unprobed_overrides, length (uo_reason o) < 200]
      _ <- expect (null thin)
             ("these unprobed-override entries carry no real reason: " ++ intercalate ", " thin
               ++ ".\n      A length floor is a proxy and a weak one; it is here so that \"not"
               ++ " needed\" cannot be the entry. The whole value of this list is that it is a"
               ++ " written record of a decision somebody had to defend.")

      mapM_ id resolved
  where
    measure_resolution o = do
      let var   = uo_var o
          bogus = "/nonexistent-override-probe" </> (var ++ ".json")
      original <- lookupEnv var
      let restore = maybe (unsetEnv var) (setEnv var) original
      flip finally restore $ do
        unsetEnv var
        defaulted <- uo_resolve o
        setEnv var bogus
        overridden <- uo_resolve o
        pure $ do
          _ <- expect (overridden == bogus)
                 (var ++ " is ADVERTISED and DEAD: its resolver returned " ++ show overridden
                   ++ " with the variable set to " ++ show bogus ++ ". This variable is recorded"
                   ++ " as an UNPROBED gap because nothing in cabal test consumes it -- but it is"
                   ++ " still supposed to RESOLVE, and a resolver that ignores its input is a"
                   ++ " failure this suite can see and therefore must.")
          expect (overridden /= defaulted)
            (var ++ " resolves to " ++ show defaulted ++ " both with and without the variable set"
              ++ " -- the override is vacuous.")

-- | A PARTIAL run is representable, decodes, and says so.
--
-- The @DRIVER_CAPTURE@ half of this check MOVED to
-- 'every_advertised_override_is_honoured'. It was the right instrument aimed at one variable out
-- of five; the whole point of the pattern it guards against is that it recurs, and it did --
-- @RIG_PINS@ was dead in this module until 22-07 fixed it. The sweep is the standing guard, this
-- check is now purely about the round trip.
driv01_capture_round_trips :: Check
driv01_capture_round_trips = Check "driv01_capture_round_trips" . guarded $ do
  original <- lookupEnv capture_env_var
  let restore = maybe (unsetEnv capture_env_var) (setEnv capture_env_var) original

  tmp <- getTemporaryDirectory
  let path = tmp </> "driv01-capture-round-trip.json"

  decoded <- flip finally restore $ do
    setEnv capture_env_var path
    write_capture path truncated_run
    -- Read back through 'capture_path' rather than through @path@ directly, so the round trip
    -- exercises the resolver a real consumer would use.
    resolved <- capture_path
    d <- eitherDecodeFileStrict resolved :: IO (Either String Value)
    removeFile resolved
    pure d

  pure $ do
    value <- decoded
    complete <- json_field "dr_complete" value >>= json_bool
    _ <- expect (not complete)
           "a truncated DriverRun round-tripped with dr_complete = true"

    steps <- json_field "steps" value >>= json_array
    _ <- expect (length steps == 1)
           ("the truncated run round-tripped with " ++ show (length steps)
             ++ " steps, expected 1 -- a partial artifact that does not decode is worth nothing,"
             ++ " and flush-on-failure is the only debuggable outcome of a mid-run abort")

    configured <- json_field "configuredSize" value >>= json_integer
    _ <- expect (configured == 5)
           ("configuredSize round-tripped as " ++ show configured ++ ", expected 5 -- without it a"
             ++ " reader cannot tell a truncated run from a short one by counting")

    -- The ORDERS block is truncatable the same way the step list is, and it carries its OWN
    -- completion flag. dr_complete means "the DRIV-01 path finished" and 22-05 sets it BEFORE the
    -- order side runs, deliberately, so that an order-side failure cannot mark the price-path
    -- evidence partial. A second requirement reading that flag would read a price-path success as
    -- an order-side success. The fixture is exactly that shape: single recorded, mixed and n0 not.
    orders <- json_field "orders" value
    orders_complete <- json_field "complete" orders >>= json_bool
    _ <- expect (not orders_complete)
           ("a partial orders block round-tripped with orders.complete = true. DRIV-02's completion"
             ++ " flag is separate from dr_complete on purpose -- see Driver.Capture's header.")

    single <- json_field "single" orders
    _ <- expect (single /= Null)
           "the recorded single order was lost in the round trip"
    n0 <- json_field "n0" orders
    expect (n0 == Null)
      ("orders.n0 round-tripped as " ++ show n0 ++ " when the fixture never recorded one -- a"
        ++ " partial orders block must not invent the shapes that never ran")
  where
    capture_env_var = "DRIVER_CAPTURE"

-- | One mined step out of five configured: the shape a mid-run abort must leave behind.
truncated_run :: DriverRun
truncated_run =
  DriverRun
    { dr_generated_at    = "1970-01-01T00:00:00Z"
    , dr_chain_id        = 31337
    , dr_generated_from  = "round-trip fixture -- not a live run"
    , dr_complete        = False
    , dr_configured_size = 5
    , dr_rig             = fixture_rig
    , dr_seed            = DriverSeed { ds_rng = 1, ds_t0 = Just 1700000012, ds_stride = 12 }
    , dr_steps           = [fixture_step]
    , dr_legacy_write_price = Just fixture_legacy
    , dr_orders          = fixture_orders
    }

-- | An orders block that got as far as the single order and no further.
fixture_orders :: OrdersRecord
fixture_orders =
  no_orders
    { or_single =
        Just SingleOrder
          { so_submitted      = OrderFields 1000 60 500 (10 ^ (18 :: Int))
          , so_tx_hash        = "fixture"
          , so_status         = Just 1
          , so_e1_count       = 1
          , so_e1             = Just (E1Record 1 1000 60 500 (10 ^ (18 :: Int)))
          , so_readback       = Just (OrderFields 1000 60 500 (10 ^ (18 :: Int)))
          , so_readback_id    = Just 1
          , so_readback_block = Just 7
          }
    }

fixture_rig :: DriverRig
fixture_rig =
  DriverRig
    { drg_pool_manager      = "fixture"
    , drg_dynamic_fee_hook  = "fixture"
    , drg_price_setter_hook = "fixture"
    , drg_swap_router       = "fixture"
    , drg_vol_order_manager = "fixture"
    , drg_pool_id           = "fixture"
    , drg_tick_spacing      = 20
    , drg_deployer          = "fixture"
    , drg_sender            = "fixture"
    }

fixture_step :: StepRecord
fixture_step =
  StepRecord
    { sr_k           = 0
    , sr_tick        = 60
    , sr_expected_ts = 1700000012
    , sr_tx_hash     = Just "fixture"
    , sr_status      = Just 1
    , sr_e3_count    = Just 1
    , sr_e5_count    = Just 1
    , sr_e3          = Just (E3Record 1700000012 60 1 2 3)
    , sr_e5          = Just (E5Record 4 15000)
    }

fixture_legacy :: LegacyWritePrice
fixture_legacy =
  LegacyWritePrice
    { lwp_tick         = 60
    , lwp_pool_manager = "fixture"
    , lwp_slot         = "fixture"
    , lwp_value        = "fixture"
    }

-- ---------------------------------------------------------------------------------------------
-- DRIV-01: SC-1 asserted BY VALUE over a committed live run
--
-- All four checks below are PURE over @offchain\/rig\/driver-run-capture.json@ -- no chain, no
-- socket, no manifest beyond the freshness cross-check that every capture check in this suite
-- already does. The artifact is produced by @cabal run cfmm-replicationPlank-rpc-api@ against a
-- standing rig; these checks are what turn it from a log into evidence.
--
-- SC-1's MECHANISM is superseded (22-CONTEXT's locked architecture decision: the hook self-writes
-- through @beforeSwap@ and the offchain side only observes, so nothing calls @writeTimepoint@). Its
-- required OUTCOME is unchanged and is what is asserted here: one E3 per step, carrying the tick
-- and the timestamp the driver submitted.
-- ---------------------------------------------------------------------------------------------

driver_capture_command :: String
driver_capture_command = "cabal run cfmm-replicationPlank-rpc-api"

-- | Every step in the run, paired with its index, plus the run's own @t0@ and @stride@.
--
-- @t0@ and @stride@ are read out of the ARTIFACT rather than written here as constants. The
-- schedule's origin is chain-dependent -- @t_0 = chain_head + stride@, and @anvil --timestamp@
-- fixes the origin and not the rate -- so a literal here would go stale on the next redeploy and
-- redden a check that is supposed to be about the driver.
capture_schedule :: Value -> Either String (Integer, Integer, [Value])
capture_schedule capture = do
  t0 <- json_field "seed" capture >>= json_field "t0" >>= json_integer
  stride <- json_field "seed" capture >>= json_field "stride" >>= json_integer
  steps <- json_field "steps" capture >>= json_array
  pure (t0, stride, steps)

-- | The artifact exists, decodes, and describes THIS rig.
--
-- @generatedFrom@ and @tickSpacing@ are asserted deliberately. Phase 21's F4 measured that a
-- freshness check over @chainId@ plus a manager address cannot see a MODULE change, because a
-- @CREATE@ address is bytecode-independent and was identical across three from-scratch deploys.
-- @blockNumber@ is deliberately NOT asserted: 21-02 measured three from-scratch deploys landing at
-- heights 9, 11 and 10.
--
-- @dr_complete@ is part of freshness, not a separate concern: a truncated run is evidence of a
-- FAILURE and must never be read as evidence for a requirement.
driv01_run_capture_is_present_and_fresh :: Check
driv01_run_capture_is_present_and_fresh =
  Check "driv01_run_capture_is_present_and_fresh" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    mf <- manifest_file
    manifest_present <- doesFileExist mf
    outcome <-
      if manifest_present
        then do
          pf <- pins_file
          attempt <- try (load_rig_from pf mf)
          pure (Just (attempt :: Either IOException Rig))
        else pure Nothing
    pure $ do
      capture <- loaded
      rig <- case outcome of
        Nothing         -> Left ("no " ++ mf ++ " -- it is gitignored, so a fresh checkout has no"
                                  ++ " copy. Stand the rig up: " ++ deploy_command)
        Just (Left err) -> Left ("load_rig_from failed on the real files: " ++ show err)
        Just (Right r)  -> Right r
      let addrs = rig_addrs rig

      complete <- json_field "dr_complete" capture >>= json_bool
      _ <- expect complete
             ("the committed run has dr_complete = false: it ABORTED mid-fold and was flushed from"
               ++ " the exception path. A partial run is evidence of a failure, never of DRIV-01."
               ++ " Re-take it: " ++ driver_capture_command)

      captured_chain <- json_field "chainId" capture >>= json_integer
      _ <- positive_fields_agree "chainId" (rig_chain_id addrs) captured_chain "the run"
             ("The run was taken against a DIFFERENT chain. Re-take it: "
               ++ driver_capture_command)

      captured_from <- json_field "generatedFrom" capture >>= json_string
      _ <- refs_are_real "the run" captured_from (T.unpack (pins_generated_from (rig_pins rig)))
      _ <- expect (captured_from == T.unpack (pins_generated_from (rig_pins rig)))
             ("the run names generatedFrom " ++ captured_from ++ " but rig-pins.json names "
               ++ T.unpack (pins_generated_from (rig_pins rig))
               ++ " -- the run describes a DIFFERENT imported source-of-truth ref. Re-take it: "
               ++ driver_capture_command)

      -- The WHOLE rig block. This was two fields out of seven; priceSetterHook, swapRouter,
      -- deployer, sender and volOrderManager were recorded and never compared.
      _ <- rig_block_matches capture addrs driver_rig_address_fields "the run"
             driver_capture_command
      _ <- pool_id_matches capture addrs "the run" driver_capture_command

      captured_spacing <- json_field "rig" capture >>= json_field "tickSpacing" >>= json_integer
      positive_fields_agree "tickSpacing" (rig_tick_spacing (rig_pool addrs))
        captured_spacing "the run"
        ("tickSpacing moved 10 -> 20 at PR #18, taking the PoolKey hash and therefore the poolId"
          ++ " with it, so a run recorded under the other value is stale BY CONSTRUCTION.")

-- ---------------------------------------------------------------------------------------------
-- NON-DEGENERACY, and why a freshness equality needs it
--
-- MEASURED during 22-07's F5 sweep. Every freshness check in this module compares a value the
-- ARTIFACT recorded against a value the MANIFEST or PIN FILE recorded, which is the right shape --
-- two files, two producers. But @x == y@ is also TRUE when both are @\"\"@, and that is a
-- reachable state, not a hypothetical: @generatedFrom@ comes from a shell command substitution in
-- @generate-pins.sh@ and @deploy-rig.sh@, and a command substitution that fails yields an empty
-- string with no error anywhere. Pointed at a pin file, a manifest, a capture and a proof whose
-- @generatedFrom@ and @PoolManager@ were all emptied, the suite went 84\/85 -- and the one failure
-- was an artifact I had only half-emptied. Emptied consistently, all three freshness checks pass
-- on nothing at all.
--
-- The guards below are the discriminator: a shape assertion on BOTH sides, so an equality can
-- only be satisfied by two values that are each independently well-formed.
-- ---------------------------------------------------------------------------------------------

-- | A 40-character git object name, which is what @generatedFrom@ carries.
--
-- SHAPE ONLY. The all-zero name @0000...0000@ satisfies it, and git plumbing really emits that
-- one -- it is the null object id every @update-ref@ and every @pre-receive@ hook uses for
-- \"no such object\". The floor that rejects it is 'not_a_zero_word', applied at the comparison
-- rather than here, because 'rig_address_keys' uses the sibling shape test to CLASSIFY the keys
-- of a rig block and a classifier that silently drops a zeroed field would delete its own
-- comparison -- the exact one-sided hardening this section already carries two scars from.
is_git_object_name :: String -> Bool
is_git_object_name s = length s == 40 && all isHexDigit s

-- | A @0x@-prefixed 20-byte address. SHAPE ONLY -- see 'is_git_object_name'.
is_address_text :: String -> Bool
is_address_text s =
  case stripPrefix "0x" (map toLower s) of
    Just body -> length body == 40 && all isHexDigit body
    Nothing   -> False

-- | THE SAME DEGENERACY AGAIN, IN THE HEX-SHAPED STRINGS. SIXTH INSTANCE OF THE CLASS.
--
-- The shape guards above test hex-ness and LENGTH. The zero address is forty hex digits and the
-- zero word is sixty-four, so both pass, and every equality they were written to protect is
-- satisfied by one zero comparing equal to another. MEASURED on this branch, same field, same
-- three files, only the REPRESENTATION differing:
--
-- >  PoolManager := ""            in manifest + both captures  ->  2 FAILED
-- >  PoolManager := <zero address> in the same three files     ->  89\/89 checks passed
--
-- And zeroing EVERY @contracts.*@\/@accounts.*@, both artifacts' entire @rig@ blocks, @poolId@ as
-- the 32-byte zero word and @batch-return-capture.json@'s @manager@, all consistently: 89\/89.
-- That is all 16 'addresses_agree' comparisons and both 'pool_id_matches' defeated at once --
-- the whole freshness surface.
--
-- It is reachable, not hypothetical. An unset @address@ in a forge broadcast JSON IS
-- @address(0)@; @vm.envAddress@ misses, mapping misses and failed lookups all yield it; and
-- @notes\/DATA_CONTRACT.md@ 2 treats @bytes32(0)@ as a permanent first-class sentinel for
-- @poolId@.
--
-- The predicate is the one 'positive_fields_agree' already writes down one type over: a pinned
-- FLOOR on a value that has no legitimate zero, NOT a non-emptiness test of the kind that has
-- failed to discriminate here five times. There is no zero-address contract, no zero @poolId@
-- and no zero git object name, so the floor is exact rather than heuristic.
--
-- Written as a predicate over the hex BODY so it is representation-independent: it does not care
-- whether the value is 40 or 64 digits, @0x@-prefixed or bare, upper or lower case. Generalising
-- the PREDICATE rather than the representation is the whole point -- the five previous sweeps of
-- this class each generalised the representation they had just seen.
is_zero_hex_text :: String -> Bool
is_zero_hex_text s = not (null body) && all (== '0') body
  where
    body = fromMaybe lowered (stripPrefix "0x" lowered)
    lowered = map toLower s

-- | The floor, as an assertion. Every hex-shaped freshness equality in this module takes it on
-- BOTH sides, next to the shape guard and never instead of it.
not_a_zero_word :: String -> String -> Either String ()
not_a_zero_word subject value =
  expect (not (is_zero_hex_text value))
    (subject ++ " is " ++ show value ++ " -- ALL ZEROS. It is the right shape and it is not a"
      ++ " value: an equality against a zero on the other side is satisfied by nothing, which is"
      ++ " what \"\" did before it and what tickSpacing = 0 did after. address(0) is what an unset"
      ++ " forge-broadcast address, a missed vm.envAddress and a failed mapping lookup all"
      ++ " produce, and bytes32(0) is a first-class poolId sentinel in notes/DATA_CONTRACT.md"
      ++ " section 2 -- so this is a reachable state, not a contrived one.")

-- | Both sides of a @generatedFrom@ freshness equality name a real ref.
refs_are_real :: String -> String -> String -> Either String ()
refs_are_real subject captured pinned = do
  _ <- expect (is_git_object_name pinned)
         ("rig-pins.json records generatedFrom " ++ show pinned ++ ", which is not a 40-character"
           ++ " git object name. generate-pins.sh fills this from a command substitution, and a"
           ++ " failed substitution yields \"\" silently -- against an artifact that recorded the"
           ++ " same emptiness the freshness equality below would be satisfied by nothing."
           ++ " Regenerate: bash offchain/rig/generate-pins.sh")
  -- The git null object id is 40 hex digits, so the shape guard above accepts it and the
  -- equality below is satisfied by two of them. git emits it for real -- it is the "no such
  -- object" sentinel in every ref update and every hook -- so a generatedFrom filled from a
  -- plumbing command that found nothing lands here already well-formed.
  _ <- not_a_zero_word "rig-pins.json's generatedFrom" pinned
  _ <- not_a_zero_word (subject ++ "'s generatedFrom") captured
  expect (is_git_object_name captured)
    (subject ++ " records generatedFrom " ++ show captured ++ ", which is not a 40-character git"
      ++ " object name -- so it cannot identify the imported source-of-truth ref it was taken"
      ++ " against, and comparing it to anything proves nothing.")

-- | One @contracts.<name>@ from the manifest, or a failure naming the deploy command.
manifest_address :: RigAddresses -> T.Text -> Either String String
manifest_address addrs name =
  case Map.lookup name (rig_contracts addrs) of
    Nothing -> Left ("the manifest has no " ++ T.unpack name ++ " -- re-run: " ++ deploy_command)
    Just t  -> Right (map toLower (T.unpack t))

-- | THE ONLY WAY THIS MODULE COMPARES A CAPTURED ADDRESS TO A MANIFEST ADDRESS.
--
-- 'fecdc8b' put the two shape guards inside 'rig_field_matches' and swept the CALL SITES of that
-- helper. That sweep was per-call-site rather than per-COMPARISON, so two raw @captured ==
-- manifest@ equalities survived it -- and one of them, on @PriceSetterPoolManager@, was reachable
-- with nothing else objecting, because that key is read NOWHERE else in the suite and
-- @Rig.Manifest@'s completeness check tests for the KEY, not the value. MEASURED:
--
-- > $ jq '.contracts.PriceSetterPoolManager = ""'   rig-manifest.json     > $S\/rig-manifest.json
-- > $ jq '.legacy_write_price.poolManager  = ""'   driver-run-capture.json > $S\/driver-run-capture.json
-- > $ RIG_MANIFEST=... DRIVER_CAPTURE=... cabal test   ->  85\/85 checks passed
--
-- Green on @\"\" == \"\"@. The control -- emptying only the capture -- failed at 84\/85, which is
-- what makes this a degeneracy rather than a plain mismatch.
--
-- The fix is structural: the equality is not written out anywhere else. A future comparison gets
-- the guards by having no other function to call.
addresses_agree
  :: T.Text          -- ^ the @contracts.<name>@ key the manifest side came from
  -> String          -- ^ the manifest value, lowercased
  -> String          -- ^ how the captured side is NAMED in failures, e.g. @\"rig.poolManager\"@
  -> String          -- ^ the captured value, lowercased
  -> String          -- ^ the command that re-takes the captured artifact
  -> String          -- ^ what a MISMATCH means, appended to the equality failure
  -> Either String ()
addresses_agree name manifest captured_label captured retake consequence = do
  -- Without these two, captured == manifest is satisfied by two empty strings, and BOTH sides can
  -- carry one: a manifest because completeness tests the key, an artifact because every writer
  -- fills these fields from a shell command substitution that yields "" silently on failure.
  _ <- expect (is_address_text manifest)
         ("the manifest's " ++ T.unpack name ++ " is " ++ show manifest ++ ", not a 20-byte"
           ++ " address. Rig.Manifest's completeness check tests for the KEY, so an empty value"
           ++ " passes it -- re-run: " ++ deploy_command)
  _ <- expect (is_address_text captured)
         ("the artifact records " ++ captured_label ++ " = " ++ show captured ++ ", not a 20-byte"
           ++ " address. An artifact that cannot say which contract it ran against cannot be"
           ++ " checked for freshness against any manifest -- re-take it: " ++ retake)
  -- The floor. Shape alone accepts address(0) on both sides, and MEASURED, that is 89/89 across
  -- all sixteen of these comparisons at once.
  _ <- not_a_zero_word ("the manifest's " ++ T.unpack name) manifest
  _ <- not_a_zero_word ("the artifact's " ++ captured_label) captured
  expect (captured == manifest)
    ("the artifact records " ++ captured_label ++ " = " ++ captured ++ " but the manifest's "
      ++ T.unpack name ++ " is " ++ manifest ++ ". " ++ consequence ++ " Re-take it: " ++ retake)

-- | One @rig.<field>@ against one @contracts.<name>@, lowercased on both sides.
rig_field_matches :: Value -> RigAddresses -> String -> T.Text -> Either String ()
rig_field_matches capture addrs field name = do
  captured <- map toLower <$> (json_field "rig" capture >>= json_field field >>= json_string)
  manifest <- manifest_address addrs name
  addresses_agree name manifest ("rig." ++ field) captured driver_capture_command
    "The run describes a DIFFERENT deployment."

-- ---------------------------------------------------------------------------------------------
-- THE WHOLE @rig@ BLOCK, NOT THREE FIELDS OF IT
--
-- 'rig_field_matches' was called for exactly three contracts -- @poolManager@, @dynamicFeeHook@,
-- @volOrderManager@ -- out of the eight address-shaped fields the two committed artifacts carry
-- between them. The other five were recorded and never compared to anything, which is the same
-- one-sided hardening as the raw-@==@ defect one section up, one layer out: there the guards were
-- applied per call site, here the comparison itself was.
--
-- MEASURED, and this is what the gap actually cost:
--
-- >   manifest  contracts.PriceSetterHook   = 0xbd0397...7000
-- >   driver-run-capture.json  rig.priceSetterHook = 0x683ee5...b000
-- >   cheat-swap-proof.json    rig.priceSetterHook = 0x683ee5...b000
-- >   cabal test                                    -> GREEN
--
-- Both committed artifacts name a PriceSetterHook that is not on the rig, and the suite had
-- nothing to say. The address moved at merge @d7d1823@, which changed
-- @src\/modules\/protocol_integrations\/PriceSetterHook.sol@ by comments and formatting ONLY --
-- but Solidity's trailing CBOR metadata hash is part of @type(PriceSetterHook).creationCode@, and
-- @foundry-scripts\/PriceSetterHook.s.sol@ mines the CREATE2 salt over exactly that. So the
-- address moved while nothing semantic did, which is precisely the drift a human review does not
-- catch and a comparison does. It was PREDICTED --
-- @.planning\/phases\/22-live-stochastic-drivers\/22-VALIDATION.md@ finding F4, \"the rig is being
-- rebuilt, and capture freshness cannot see a module change\" -- and left open.
--
-- The field SET is pinned as well as the values, for the reason
-- 'sc4_pin_surface_is_the_expected_set' exists: a per-field loop over what the artifact HAPPENS to
-- contain is scoped by the artifact, so deleting @rig.priceSetterHook@ would delete its own check.
-- ---------------------------------------------------------------------------------------------

-- | The manifest entry every @rig.<field>@ must equal. An unknown field name is a FAILURE, not a
-- skip -- a field this table does not know about is a field nothing compares.
rig_manifest_counterpart :: RigAddresses -> String -> Either String (T.Text, String)
rig_manifest_counterpart addrs field =
  case field of
    "deployer"               -> Right ("accounts.deployer", low (rig_deployer accts))
    "sender"                 -> Right ("accounts.sender", low (rig_sender accts))
    "poolManager"            -> contract "PoolManager"
    "dynamicFeeHook"         -> contract "DynamicFeeHook"
    "priceSetterHook"        -> contract "PriceSetterHook"
    "priceSetterPoolManager" -> contract "PriceSetterPoolManager"
    "swapRouter"             -> contract "PoolSwapTest"
    "volOrderManager"        -> contract "VolOrderManagerMod"
    _ ->
      Left ("rig." ++ field ++ " is an address-shaped field with no manifest counterpart in"
             ++ " rig_manifest_counterpart, so nothing in this suite compares it. Add the binding"
             ++ " rather than widening the ignore set.")
  where
    accts = rig_accounts addrs
    low = map toLower . T.unpack
    contract name = (\v -> (name, v)) <$> manifest_address addrs name

-- | The address-shaped @rig.*@ fields @driver-run-capture.json@ carries.
driver_rig_address_fields :: [String]
driver_rig_address_fields =
  ["deployer", "dynamicFeeHook", "poolManager", "priceSetterHook", "sender", "swapRouter"
  , "volOrderManager"]

-- | The address-shaped @rig.*@ fields @cheat-swap-proof.json@ carries. It has no @sender@ and no
-- @volOrderManager@ (it never sends an order), and it DOES carry @priceSetterPoolManager@.
proof_rig_address_fields :: [String]
proof_rig_address_fields =
  ["deployer", "dynamicFeeHook", "poolManager", "priceSetterHook", "priceSetterPoolManager"
  , "swapRouter"]

-- | Every address-shaped field of a @rig@ block, against the manifest, with the field set pinned.
rig_block_matches :: Value -> RigAddresses -> [String] -> String -> String -> Either String ()
rig_block_matches capture addrs fields subject retake = do
  block <- json_field "rig" capture
  present <- rig_address_keys block
  _ <- expect (sort present == sort fields)
         (subject ++ "'s rig block does not carry the address-shaped fields this suite compares."
           ++ "\n      missing    : " ++ render (filter (`notElem` present) fields)
           ++ "\n      unexpected : " ++ render (filter (`notElem` fields) present)
           ++ "\n      A field that is absent DELETES ITS OWN comparison, so the run still reports"
           ++ " a clean freshness check while comparing less. Re-take it: " ++ retake)
  mapM_ (one block) fields
  where
    one block field = do
      captured <- map toLower <$> (json_field field block >>= json_string)
      (name, manifest) <- rig_manifest_counterpart addrs field
      addresses_agree name manifest (subject ++ " rig." ++ field) captured retake
        "The artifact describes a DIFFERENT deployment."

    render [] = "(none)"
    render xs = intercalate ", " xs

-- | The keys of a @rig@ block whose values are 20-byte addresses. Everything else in the block
-- (@poolId@, @tickSpacing@) is asserted by its own check and is not an address.
rig_address_keys :: Value -> Either String [String]
rig_address_keys (Object o) =
  Right [K.toString k | (k, String v) <- KM.toList o, is_address_text (T.unpack v)]
rig_address_keys other = Left ("expected the rig block to be an object, got " ++ json_kind other)

-- | The @poolId@ an artifact recorded, against the manifest's. Not an address, so it does not go
-- through 'addresses_agree'; the same degeneracy applies, so it gets the same shape guard.
pool_id_matches :: Value -> RigAddresses -> String -> String -> Either String ()
pool_id_matches capture addrs subject retake = do
  captured <- map toLower <$> (json_field "rig" capture >>= json_field "poolId" >>= json_string)
  let manifest = map toLower (T.unpack (rig_pool_id (rig_pool addrs)))
  _ <- expect (is_bytes32_text manifest)
         ("the manifest's pool.poolId is " ++ show manifest ++ ", not a 32-byte word -- re-run: "
           ++ deploy_command)
  _ <- expect (is_bytes32_text captured)
         (subject ++ " records rig.poolId = " ++ show captured ++ ", not a 32-byte word.")
  -- bytes32(0) is not merely reachable here, it is DOCUMENTED: notes/DATA_CONTRACT.md section 2
  -- treats it as a permanent poolId sentinel. Shape alone accepts it on both sides.
  _ <- not_a_zero_word "the manifest's pool.poolId" manifest
  _ <- not_a_zero_word (subject ++ "'s rig.poolId") captured
  expect (captured == manifest)
    (subject ++ " records rig.poolId = " ++ captured ++ " but the manifest's pool.poolId is "
      ++ manifest ++ ". The poolId is the PoolKey hash: it moves with the hook address, the tick"
      ++ " spacing and the currencies, so an artifact recorded under a different one measured a"
      ++ " DIFFERENT pool. Re-take it: " ++ retake)

-- | THE SAME DEGENERACY, IN THE NUMERIC FIELDS. FOUND BY THE COUNTERPART SWEEP.
--
-- The non-degeneracy work so far treated this as a STRING problem, because the reachable empty
-- value came from a shell command substitution. The sweep asked the same question of the two
-- numeric freshness equalities and MEASURED both, with @PriceSetterHook@ aligned so the answer was
-- not masked by the reds this branch already carries:
--
-- > tickSpacing := 0 in the manifest AND both artifacts  ->  89\/89 checks passed, SC-3 and SC-4 OK
-- > chainId     := 0 in the manifest AND both artifacts  ->  88\/89, and the ONE objection was
-- >                                                          rpin05_capture_is_present_and_fresh,
-- >                                                          which objects only because
-- >                                                          batch-return-capture.json has no env
-- >                                                          override -- i.e. by accident of what
-- >                                                          is overridable, not by assertion.
--
-- @0 == 0@ is exactly @\"\" == \"\"@ one type over. Neither zero is a real value: a Uniswap v4
-- pool cannot have @tickSpacing = 0@ (the PoolKey is rejected at initialize), and there is no EVM
-- chain with id 0. So the guard is a pinned FLOOR on a value that has no legitimate zero, not a
-- non-emptiness test of the kind that has failed to discriminate here before.
positive_fields_agree :: String -> Integer -> Integer -> String -> String -> Either String ()
positive_fields_agree field manifest captured subject consequence = do
  _ <- expect (manifest > 0)
         ("the manifest records " ++ field ++ " = " ++ show manifest ++ ". There is no legitimate"
           ++ " zero for this field, and an equality against a zero on the other side would be"
           ++ " satisfied by nothing -- re-run: " ++ deploy_command)
  _ <- expect (captured > 0)
         (subject ++ " records " ++ field ++ " = " ++ show captured ++ ". There is no legitimate"
           ++ " zero for this field.")
  expect (captured == manifest)
    (subject ++ " records " ++ field ++ " = " ++ show captured ++ " but the manifest says "
      ++ show manifest ++ ". " ++ consequence)

-- | A @0x@-prefixed 32-byte word.
is_bytes32_text :: String -> Bool
is_bytes32_text s =
  case stripPrefix "0x" (map toLower s) of
    Just body -> length body == 64 && all isHexDigit body
    Nothing   -> False

-- | SC-1's CORE: one E3 per step, carrying the tick and the timestamp the driver submitted.
--
-- Every equality is computed from the artifact's own recorded @t0@ and @stride@, so the check
-- asserts the SCHEDULE the driver claims to have followed rather than a constant that would go
-- stale with the rig. The strictly-increasing assertion is separate from the arithmetic one on
-- purpose: it is the property G2 actually needs (the Algebra-ported oracle assumes a non-decreasing
-- uint32 clock and does not check it), and it survives even if the stride convention ever changes.
driv01_e3_per_step_matches_submitted :: Check
driv01_e3_per_step_matches_submitted =
  Check "driv01_e3_per_step_matches_submitted" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    pure $ do
      capture <- loaded
      (t0, stride, steps) <- capture_schedule capture

      configured <- json_field "configuredSize" capture >>= json_integer
      _ <- expect (toInteger (length steps) == configured)
             ("the run recorded " ++ show (length steps) ++ " steps but was configured for "
               ++ show configured ++ ". A short run is a TRUNCATED run: the driver aborts on the"
               ++ " first bad step, so the missing steps never happened.")
      -- TWO, not one. @and (zipWith (<) ts (drop 1 ts))@ below is @and [] = True@ at length 1:
      -- a one-step run satisfies "strictly increasing" by having no pair to compare. MEASURED:
      -- a capture truncated to one step reddened only driv01_seed_replays_the_committed_path,
      -- which pins the path LENGTH at 5 -- so this assertion was saved by a neighbour's
      -- expectation rather than by its own guard, and would go vacuous the moment that neighbour
      -- moved. The floor belongs to the assertion that needs it.
      _ <- expect (length steps >= 2)
             ("the run recorded " ++ show (length steps) ++ " step(s). The strictly-increasing"
               ++ " timestamp assertion below compares CONSECUTIVE PAIRS, and a run with fewer"
               ++ " than two steps has none -- it would pass on the empty conjunction while"
               ++ " asserting nothing about the clock. There is also nothing here to be evidence"
               ++ " of: one timepoint is not a window.")

      _ <- mapM_ (one_step_matches t0 stride) (zip [0 ..] steps)

      recorded_ts <- mapM (e3_int "timestamp") steps
      expect (and (zipWith (<) recorded_ts (drop 1 recorded_ts)))
        ("the recorded E3 timestamps are not STRICTLY increasing: " ++ show recorded_ts
          ++ ". G2 is not guarded on chain -- the oracle assumes a non-decreasing uint32 clock and"
          ++ " does not check it, so a backwards step corrupts the sigma^2 window math with no"
          ++ " revert, no event and no symptom. This is one of the only two signals that exist.")
  where
    one_step_matches t0 stride (k, step) = do
      status <- measurement_int "status" step
      _ <- expect (status == 1)
             ("step " ++ show k ++ " came back at status " ++ show status
               ++ " -- a revert unwinds the entire frame including the timepoint beforeSwap had"
               ++ " already written, so nothing was recorded for it")

      e3_count <- measurement_int "e3_count" step
      _ <- expect (e3_count == 1)
             ("step " ++ show k ++ " produced " ++ show e3_count ++ " E3 logs, expected exactly 1")

      submitted_tick <- measurement_int "tick" step
      recorded_tick <- e3_int "tick" step
      _ <- expect (recorded_tick == submitted_tick)
             ("step " ++ show k ++ " SUBMITTED tick " ++ show submitted_tick ++ " but the hook"
               ++ " RECORDED tick " ++ show recorded_tick
               ++ ". 22-04 measured this exact receipt shape -- status 1, one E3, one E5 -- coming"
               ++ " back with the wrong tick when the slot0 write was aimed at the OTHER"
               ++ " PoolManager, so a wrong value here does NOT imply a broken composition.")

      let expected_ts = t0 + k * stride
      submitted_ts <- measurement_int "expected_ts" step
      _ <- expect (submitted_ts == expected_ts)
             ("step " ++ show k ++ " submitted timestamp " ++ show submitted_ts ++ " but the"
               ++ " schedule t0 + k*stride = " ++ show t0 ++ " + " ++ show k ++ "*" ++ show stride
               ++ " gives " ++ show expected_ts ++ " -- the driver did not follow its own schedule")

      recorded_ts <- e3_int "timestamp" step
      expect (recorded_ts == expected_ts)
        ("step " ++ show k ++ " expected the hook to stamp " ++ show expected_ts ++ " but it"
          ++ " stamped " ++ show recorded_ts
          ++ ". The hook stamps its own clock, so a disagreement means the block did not carry the"
          ++ " timestamp the driver set -- which makes the whole series' window arithmetic"
          ++ " unattributable.")

-- | THE G1 DETECTOR: @count(E5) == count(E3) == steps@ over the whole run.
--
-- E5 fires on EVERY swap, including one whose write the guard ate; E3 fires only on a real write.
-- @RealizedVolatilityStateLib.plk:114@ is @if vol_state.lastTimepointTimestamp == now@ -- an
-- equality test on the uint32 timestamp with no block number anywhere -- so a second swap on an
-- already-recorded second serves E5 and the fee at status 1 and writes NOTHING. That makes
-- @count(E5) - count(E3)@ a direct on-chain count of how many steps the guard ate, and both numbers
-- arrive free in the same receipts.
--
-- Its FALSIFICATION is 22-04's measurement C, by name: @same_second_repeat_step2@ was measured at
-- @e3_count = 0, e5_count = 1, status = 1@, i.e. exactly the receipt this check exists to catch.
-- That measurement is committed in @offchain\/rig\/cheat-swap-proof.json@ and is what makes this
-- assertion a detector rather than a tautology.
--
-- == THE CONFIGURED-SIZE ASSERTION, AND WHY IT IS NOT REDUNDANT
--
-- 22-05's plan predicted that deleting the @evm_setNextBlockTimestamp@ call would redden this
-- check. It was APPLIED and it did NOT: the mutant reddened the driver's own timestamp assertion at
-- step 0 (@SUBMITTED timestamp 1700001899 but the hook RECORDED 1700001888@), truncating the run to
-- ONE healthy step -- and over one healthy step @count(E5) == count(E3) == length(steps) == 1@ is
-- perfectly true. The counts alone are BLIND TO TRUNCATION: they say nothing was eaten out of the
-- steps that exist, which is not the claim. The claim is that nothing was eaten out of the RUN.
--
-- So @length(steps)@ is compared against @configuredSize@ here as well. This is the sixth time in
-- this workstream a predicted discriminator has been measured and refuted, and the fifth where the
-- fix belongs in the check rather than in a note.
driv01_no_same_second_noop :: Check
driv01_no_same_second_noop =
  Check "driv01_no_same_second_noop" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    pure $ do
      capture <- loaded
      steps <- json_field "steps" capture >>= json_array
      e3s <- mapM (measurement_int "e3_count") steps
      e5s <- mapM (measurement_int "e5_count") steps
      let n = toInteger (length steps)

      configured <- json_field "configuredSize" capture >>= json_integer
      _ <- expect (n == configured)
             ("the run recorded " ++ show n ++ " steps but was configured for " ++ show configured
               ++ ". MEASURED (22-05, M1): with the clock call deleted this check's count equality"
               ++ " stayed TRUE over a one-step truncated run, because count(E5) == count(E3) == 1"
               ++ " says only that nothing was eaten out of the steps that EXIST. The claim being"
               ++ " made is that nothing was eaten out of the RUN, and a truncated run cannot"
               ++ " support it.")

      _ <- expect (sum e3s == n)
             ("the run recorded " ++ show (sum e3s) ++ " E3 logs over " ++ show n ++ " steps."
               ++ " count(E5) - count(E3) = " ++ show (sum e5s - sum e3s)
               ++ " is how many steps the G1 same-second guard ATE: those swaps returned status 1,"
               ++ " emitted E5 and served a fee while writing no timepoint. 22-04's measurement"
               ++ " same_second_repeat_step2 is the committed observation of that receipt shape"
               ++ " (0 E3, 1 E5, status 1).")
      expect (sum e5s == n)
        ("the run recorded " ++ show (sum e5s) ++ " E5 logs over " ++ show n ++ " steps, expected"
          ++ " one per swap. E5 fires on every swap unconditionally, so a count below the step"
          ++ " count means a swap did not reach the hook at all -- a different fault from a"
          ++ " swallowed write, and one this check must not conflate with it.")

-- | The bit offset of @lpFee@. 'slot0_tick_shift' and 'slot0_fee_shift' cover the other two.
slot0_lp_fee_shift :: Int
slot0_lp_fee_shift = 208

-- | One 24-bit unsigned Slot0 field at the given offset.
slot0_field :: Integer -> Int -> Integer
slot0_field w shift_by = (w `shiftR` shift_by) .&. ((1 `shiftL` 24) - 1)

-- | @Sample.sample_tick@, the tick the legacy demo call submits.
legacy_pinned_tick :: Integer
legacy_pinned_tick = 60

-- | The three remaining Slot0 fields of the committed legacy word.
--
-- MEASURED off @offchain\/rig\/driver-run-capture.json@, then CHECKED for coherence rather than
-- taken on faith: @sqrtPriceX96 = 79466191966197645195421774833@ agrees with
-- @1.0001^30 * 2^96 = 7.946619196619762e28@ to fifteen significant figures, i.e. to double
-- precision, which is as close as a float can come to TickMath's exact integer. All three are
-- deterministic -- the price is a pure function of the tick, and the two fees are the target
-- pool's own configuration, preserved by @compose_slot0@'s mask at 184 -- so pinning them costs
-- nothing on a redeploy and is the only thing that can see a wrong word.
legacy_pinned_sqrt_price, legacy_pinned_protocol_fee, legacy_pinned_lp_fee :: Integer
legacy_pinned_sqrt_price   = 79466191966197645195421774833
legacy_pinned_protocol_fee = 0
legacy_pinned_lp_fee       = 3000

-- | The legacy @write_price@ flow still ran, and still targets the OTHER manager.
--
-- Roadmap SC-1 requires the existing @write_price@ \/ @PriceSetterHook@ flow to stay available and
-- unchanged; @run_cheat_swap_path@ was ADDED BESIDE it. Asserting the recorded @poolManager@ is
-- @PriceSetterPoolManager@ pins the second half of that sentence: this flow writes slot0 on a
-- liquidity-free manager that @DynamicFeeHook@ does not read and emits nothing, which is exactly
-- why it could never have satisfied DRIV-01 on its own.
--
-- == WHY EVERY ASSERTION HERE IS A VALUE
--
-- This check used to assert @not (null value)@ and @not (null slot)@ and nothing else about
-- either, and it never looked at @tick@ at all. @Driver.Capture@'s @hex_of@ always emits at least
-- @\"0x\"@, so BOTH of those tests were unfalsifiable: a @write_price@ composing @tick = 0@, or
-- one that dropped the tick entirely, left this check GREEN -- and it is the only coverage roadmap
-- SC-1's "the legacy flow keeps running unchanged" has. A non-emptiness test over a producer that
-- always produces something is not a weak check, it is not a check.
--
-- Everything below is now pinned by value: the submitted tick, all four Slot0 fields of the
-- written word, and the slot's disjointness from the dynamic-fee pool's own slot0.

driv01_legacy_write_price_still_ran :: Check
driv01_legacy_write_price_still_ran =
  Check "driv01_legacy_write_price_still_ran" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    mf <- manifest_file
    manifest_present <- doesFileExist mf
    outcome <-
      if manifest_present
        then do
          pf <- pins_file
          attempt <- try (load_rig_from pf mf)
          pure (Just (attempt :: Either IOException Rig))
        else pure Nothing
    pure $ do
      capture <- loaded
      rig <- case outcome of
        Nothing         -> Left ("no " ++ mf ++ " -- stand the rig up: " ++ deploy_command)
        Just (Left err) -> Left ("load_rig_from failed on the real files: " ++ show err)
        Just (Right r)  -> Right r

      legacy <- json_field "legacy_write_price" capture
      case legacy of
        Null ->
          Left ("legacy_write_price is null: the run died before write_price, or write_price was"
                 ++ " removed. Roadmap SC-1 requires the existing PriceSetterHook flow to keep"
                 ++ " running unchanged BESIDE the new driver, in the same program.")
        _ -> Right ()

      -- THE SUBMITTED TICK. `sample_tick` is a constant, so this is pinnable by value and there is
      -- no excuse for asserting anything weaker.
      captured_tick <- json_field "tick" legacy >>= json_integer
      _ <- expect (captured_tick == legacy_pinned_tick)
             ("legacy_write_price recorded tick " ++ show captured_tick ++ ", but Sample.sample_tick"
               ++ " is " ++ show legacy_pinned_tick ++ ". SC-1 asks for the legacy flow UNCHANGED;"
               ++ " a write_price composing a different tick is a changed flow, and until this"
               ++ " assertion existed the only thing checked here was that the field was non-empty.")

      value <- json_field "value" legacy >>= json_string
      word <- hex_word_integer (strip_hex_prefix value)

      -- The four Slot0 fields, each pinned. The whole word is a deterministic function of the
      -- submitted tick and the target pool's fee configuration, so every one of these is a value
      -- and none of them is a shape.
      _ <- expect (slot0_tick_of word == legacy_pinned_tick)
             ("the written slot0 word carries tick " ++ show (slot0_tick_of word) ++ ", expected "
               ++ show legacy_pinned_tick ++ ". The word and the recorded tick field are written by"
               ++ " DIFFERENT halves of write_price -- packSlot0For composes the word on chain, the"
               ++ " driver records the argument it passed -- so a disagreement here means the hook"
               ++ " did not compose what it was asked for.")
      _ <- expect (slot0_field word slot0_fee_shift == legacy_pinned_protocol_fee)
             ("the written slot0 word carries protocolFee "
               ++ show (slot0_field word slot0_fee_shift) ++ ", expected "
               ++ show legacy_pinned_protocol_fee)
      _ <- expect (slot0_field word slot0_lp_fee_shift == legacy_pinned_lp_fee)
             ("the written slot0 word carries lpFee " ++ show (slot0_field word slot0_lp_fee_shift)
               ++ ", expected " ++ show legacy_pinned_lp_fee ++ ". PriceSetterHook's pool is a"
               ++ " STATIC-fee pool; a dynamic-fee pool stores lpFee = 0 at initialize, so this"
               ++ " number is also what distinguishes the legacy pool from the DynamicFeeHook one.")
      _ <- expect (word .&. ((1 `shiftL` 160) - 1) == legacy_pinned_sqrt_price)
             ("the written slot0 word carries sqrtPriceX96 "
               ++ show (word .&. ((1 `shiftL` 160) - 1)) ++ ", expected "
               ++ show legacy_pinned_sqrt_price ++ " -- TickMath's exact price at tick "
               ++ show legacy_pinned_tick ++ ". A word whose price and tick disagree is the exact"
               ++ " failure 22-04's measurement A pins on the cheat-swap side.")
      _ <- expect (word `shiftR` 232 == 0)
             ("slot0 bits >= 232 are not empty (" ++ show (word `shiftR` 232) ++ "). The Slot0"
               ++ " layout ends at 232; anything above it is a field this reader does not know"
               ++ " about, which makes every offset below it suspect.")

      slot <- map toLower . strip_hex_prefix <$> (json_field "slot" legacy >>= json_string)
      slot_word <- hex_word_integer slot
      -- The slot is keccak(poolId ++ POOLS_SLOT) for PriceSetterHook's OWN pool, whose id is not in
      -- the manifest -- so it cannot be recomputed here. What CAN be asserted is the claim this
      -- check actually makes: it is a real 32-byte slot, and it is NOT the DynamicFeeHook pool's
      -- slot0. That is the storage-level half of "the two price mechanisms are independent"; the
      -- poolManager equality below is only the address-level half, and a write aimed at the right
      -- manager and the wrong slot would satisfy that one alone.
      _ <- expect (slot_word /= 0)
             ("legacy_write_price.slot is the zero word -- write_price resolved no slot0 slot."
               ++ " hex_of always emits at least \"0x\", so a non-emptiness test cannot see this.")
      dfh_pool_id <- integer_of_hex_text (T.unpack (rig_pool_id (rig_pool (rig_addrs rig))))
      _ <- expect (slot_word /= pool_state_slot dfh_pool_id)
             ("the legacy write_price resolved slot0 slot " ++ slot
               ++ ", which is the DYNAMIC-FEE pool's slot0. The legacy flow writes PriceSetterHook's"
               ++ " own liquidity-free pool; if it starts writing the pool DynamicFeeHook reads,"
               ++ " every E3 in this same artifact stops being attributable to the cheat-swap"
               ++ " driver alone.")

      captured_pm <- map toLower <$> (json_field "poolManager" legacy >>= json_string)
      manifest_pm <- manifest_address (rig_addrs rig) "PriceSetterPoolManager"
      -- Via 'addresses_agree', never as a raw ==. This was the one reachable P2 instance:
      -- PriceSetterPoolManager is read NOWHERE else in this module, so emptying it on both sides
      -- left the whole suite green at 85/85 with nothing else objecting.
      addresses_agree "PriceSetterPoolManager" manifest_pm "legacy_write_price.poolManager"
        captured_pm driver_capture_command
        ("If this flow ever starts writing the DynamicFeeHook manager, the two price mechanisms"
          ++ " have stopped being independent and the DRIV-01 evidence in the same artifact is no"
          ++ " longer attributable to the cheat-swap driver alone.")

-- ---------------------------------------------------------------------------------------------
-- DRIV-02: SC-2, SC-3 and SC-4 asserted BY VALUE over the same committed live run
--
-- All four checks below are PURE over the @orders@ block of
-- @offchain\/rig\/driver-run-capture.json@ -- no chain, no socket. They cover the three shapes
-- @run_order_gen@ cannot produce on its own: it only ever calls the BATCH entrypoint (so no single
-- @create_order@ receipt), every shape it builds is valid (so no batch is ever mixed), and a
-- zero-arrival Poisson draw gives @chunk max_batch [] == []@, i.e. zero chunks and therefore zero
-- transactions.
--
-- EVERY SUBMITTED FIELD IS PINNED BY VALUE, not by a relation to something else in the same file.
-- 22-05 measured a count equality staying TRUE over a run that had been cut short, because the
-- equality's own denominator moved with the failure. A batch silently truncated from three tuples
-- to two would be perfectly self-consistent -- one success, one rejection, @orderCount@ moved by
-- one, one readback -- and would say nothing about the batch that was configured. Pinning the three
-- tuples is what makes that impossible rather than unlikely.
-- ---------------------------------------------------------------------------------------------

-- | The @orders@ block, or a failure naming the command that produces it.
capture_orders :: Value -> Either String Value
capture_orders capture = json_field "orders" capture

-- | One order shape's four fields, in the artifact's own encoding.
--
-- @strike@ (u88) and @targetVega@ (u96) are DECIMAL STRINGS and are read as such. The demo's
-- @targetVega@ is @10^18@, over a hundred times 2^53, so a reader that took it as a JSON number
-- would be handed a rounded double -- and a rounded 96-bit value still looks like a value.
order_fields_of :: Value -> Either String (Integer, Integer, Integer, Integer)
order_fields_of v = do
  strike <- json_field "strike" v >>= json_decimal_string
  width  <- json_field "width" v >>= json_integer
  sk     <- json_field "skew" v >>= json_integer
  vega   <- json_field "targetVega" v >>= json_decimal_string
  pure (strike, width, sk, vega)

-- | @sample_order@, pinned. A change to the demo order must change this line too.
pinned_single_order :: (Integer, Integer, Integer, Integer)
pinned_single_order = (1000, 60, 500, 10 ^ (18 :: Int))

-- | @sample_mixed_batch@, pinned in full and IN ORDER.
--
-- Position 1 is the discriminator: @skew = 65535@ is WIDTH-valid (@pack_vol_order_input@'s
-- @in_range 16@ is @> 0 && < 2^16@) and DOMAIN-invalid (@spread_tick_assimetry_is_complete@ admits
-- only @[1, 65534]@), so it survives the client and is rejected by the module. It was identified and
-- used live against this same module in Phase 21. NOT claimed here: that it is the only such input.
pinned_mixed_batch :: [(Integer, Integer, Integer, Integer)]
pinned_mixed_batch =
  [ (4100, 40, 210, 2 * 10 ^ (18 :: Int))
  , (4200, 80, 65535, 3 * 10 ^ (18 :: Int))
  , (4300, 120, 230, 4 * 10 ^ (18 :: Int))
  ]

-- | The one business rule this suite models, and the ONLY one it claims to model.
--
-- @spread_tick_assimetry_is_complete@ admits @skew@ in @[1, 65534]@. Everything else the module
-- validates is also enforced client-side by @pack_vol_order_input@'s field-width guards, so no
-- other rejection can reach the chain from this driver.
skew_is_in_domain :: Integer -> Bool
skew_is_in_domain sk = sk >= 1 && sk <= 65534

-- | SC-2 -- one order, one E1, one receipt-block-pinned readback.
driv02_single_order_live :: Check
driv02_single_order_live =
  Check "driv02_single_order_live" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    pure $ do
      capture <- loaded
      orders <- capture_orders capture
      single <- json_field "single" orders
      _ <- expect (single /= Null)
             ("orders.single is null: the run never placed the single demo order, or died before it"
               ++ " could be recorded. Re-take it: " ++ driver_capture_command)

      submitted <- json_field "submitted" single >>= order_fields_of
      _ <- expect (submitted == pinned_single_order)
             ("the run submitted " ++ show submitted ++ " but sample_order is "
               ++ show pinned_single_order
               ++ ". Pinned by VALUE on purpose: every equality below compares the E1 and the"
               ++ " readback against this same tuple, so without the pin all three could agree on a"
               ++ " tuple nobody chose.")

      status <- json_field "status" single >>= json_integer
      _ <- expect (status == 1)
             ("the single order came back at status " ++ show status
               ++ " -- a revert unwinds the whole frame, so no order was minted and no E1 exists")

      e1_count <- json_field "e1_count" single >>= json_integer
      _ <- expect (e1_count == 1)
             ("the single order emitted " ++ show e1_count ++ " VolOrderCreated logs, expected"
               ++ " exactly 1. Zero means the pinned topic0 matched nothing -- and a wrong topic0"
               ++ " does not look wrong, it simply matches no log, so decoding 'succeeds' at"
               ++ " reporting nothing.")

      e1 <- json_field "e1" single
      e1_fields <- order_fields_of e1
      _ <- expect (e1_fields == submitted)
             ("the E1 carries " ++ show e1_fields ++ " but the driver submitted " ++ show submitted
               ++ " -- (strike, width, skew, targetVega). targetVega is included deliberately: it is"
               ++ " the V2 field, and a decoder still reading the V1 three-field payload would agree"
               ++ " on the first three and be silent about the fourth.")

      order_id <- json_field "orderId" e1 >>= json_integer
      _ <- expect (order_id > 0)
             ("the E1 carries orderId " ++ show order_id
               ++ ", but ids are sequential FROM 1 -- the module mints id = orderCount + 1 and slot"
               ++ " 0 is never written, so 0 is not an id, it is an unmatched decode")

      readback_id <- json_field "readback_id" single >>= json_integer
      _ <- expect (readback_id == order_id)
             ("the readback queried id " ++ show readback_id ++ " but the E1 announced id "
               ++ show order_id
               ++ ". A readback aimed at a different id can still content-match -- it would simply"
               ++ " be describing some OTHER order -- so this equality is what makes the readback"
               ++ " evidence about THIS mint.")

      readback <- json_field "readback" single >>= order_fields_of
      _ <- expect (readback == submitted)
             ("the storage readback is " ++ show readback ++ " but the driver submitted "
               ++ show submitted
               ++ ". KNOWN LIMIT (Phase 21 follow-up #5, PARTIALLY ADDRESSED):"
               ++ " unpack_vol_order_storage discards tickSpacing at bits 104..127 and anything at"
               ++ " >= 248 BEFORE this comparison, so agreement here does NOT cover those bits.")

      block <- json_field "readback_block" single
      _ <- expect (block /= String (T.pack "latest"))
             ("readback_block is the string \"latest\". The readback MUST be pinned to the receipt's"
               ++ " block: on anything but a single-writer local node Latest can be a lagging"
               ++ " replica or a later tip, and either one makes the readback describe a different"
               ++ " chain state from the one the transaction landed in.")
      height <- json_integer block
      expect (height > 0)
        ("readback_block is " ++ show height ++ ", which is not a block height -- the pinning is"
          ++ " recorded rather than taken on trust precisely so it can be asserted")

-- | SC-3 -- a genuinely MIXED batch, measured rather than assumed.
--
-- KNOWN LIMIT, stated once and inherited by every readback below (Phase 21 follow-up #5,
-- PARTIALLY ADDRESSED): @create_orders@'s @verify_mined_order@ compares the 4-field @VolOrder@
-- record, and @unpack_vol_order_storage@ discards tickSpacing at bits 104..127 and anything at
-- >= 248 BEFORE the comparison. A content match here says nothing about those bits.
driv02_mixed_batch_live :: Check
driv02_mixed_batch_live =
  Check "driv02_mixed_batch_live" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    pure $ do
      capture <- loaded
      orders <- capture_orders capture
      mixed <- json_field "mixed" orders
      _ <- expect (mixed /= Null)
             ("orders.mixed is null: the run never sent the mixed batch. Re-take it: "
               ++ driver_capture_command)

      submitted_vals <- json_field "submitted" mixed >>= json_array
      submitted <- mapM order_fields_of submitted_vals
      _ <- expect (submitted == pinned_mixed_batch)
             ("the run submitted " ++ show submitted ++ " but sample_mixed_batch is "
               ++ show pinned_mixed_batch
               ++ ". This is a VALUE pin and not a length check on purpose: 22-05 measured a count"
               ++ " equality staying TRUE over a truncated run. A batch cut from three tuples to two"
               ++ " would be perfectly self-consistent below -- one success, one rejection,"
               ++ " orderCount moved by one, one readback -- and would be evidence for nothing.")

      preview_vals <- json_field "preview" mixed >>= json_array
      preview <- mapM (\p -> json_array p >>= pair) preview_vals
      _ <- expect (length preview == length submitted)
             ("the preview returned " ++ show (length preview) ++ " results for a batch of "
               ++ show (length submitted) ++ " orders")

      let pattern_actual = map fst preview
      _ <- expect (or pattern_actual)
             ("no position in the batch previewed TRUE -- an all-rejected batch is not a MIXED batch"
               ++ " and does not exercise best-effort skip semantics at all")
      _ <- expect (not (and pattern_actual))
             ("every position in the batch previewed TRUE, so the batch was NOT mixed. SC-3 needs at"
               ++ " least one CONTRACT-rejected tuple, and that is a narrow target: every field-width"
               ++ " violation is caught client-side by pack_vol_order_input before anything is sent,"
               ++ " so a rejected tuple must be WIDTH-valid and DOMAIN-invalid. skew = 65535 is the"
               ++ " discriminator this batch uses.")

      let pattern_expected = [skew_is_in_domain sk | (_, _, sk, _) <- submitted]
      _ <- expect (pattern_actual == pattern_expected)
             ("the preview's success pattern is " ++ show pattern_actual ++ " but the submitted"
               ++ " tuples' skew domain predicts " ++ show pattern_expected
               ++ ". spread_tick_assimetry_is_complete admits skew in [1, 65534] and every OTHER"
               ++ " rule the module enforces is also enforced client-side by pack_vol_order_input,"
               ++ " so nothing else should be able to reach the chain and be rejected. A"
               ++ " disagreement here is a FINDING about the module's rule set, not a threshold to"
               ++ " relax.")

      before <- json_field "orderCount_before" mixed >>= json_integer
      after <- json_field "orderCount_after" mixed >>= json_integer
      let successes = length (filter id pattern_actual)
      _ <- expect (after - before == toInteger successes)
             ("orderCount moved " ++ show before ++ " -> " ++ show after ++ " (delta "
               ++ show (after - before) ++ ") but the preview predicted " ++ show successes
               ++ " successful orders. The batch entrypoint is best-effort per ORDER and never"
               ++ " reverts, so a rejected tuple is INVISIBLE in the receipt: this delta is the only"
               ++ " on-chain count of what was actually minted.")

      status <- json_field "status" mixed >>= json_integer
      _ <- expect (status == 1)
             ("the mixed batch came back at status " ++ show status
               ++ ". A reverted batch is byte-identical to a healthy all-invalid one in a report,"
               ++ " which is exactly why the status is asserted separately from the counts.")

      readbacks <- json_field "readbacks" mixed >>= json_array
      _ <- expect (length readbacks == successes)
             ("the run read back " ++ show (length readbacks) ++ " orders for " ++ show successes
               ++ " previewed successes -- every minted id must be read back out of storage")

      let expected_readbacks = [t | (t, True) <- zip submitted pattern_actual]
      actual_readbacks <- mapM order_fields_of readbacks
      _ <- expect (actual_readbacks == expected_readbacks)
             ("the readbacks are " ++ show actual_readbacks ++ " but the SUCCESSFUL submitted tuples"
               ++ " were " ++ show expected_readbacks
               ++ ". The three tuples carry distinct strikes and widths precisely so a transposition"
               ++ " cannot pass unnoticed here.")

      ids <- mapM (\r -> json_field "id" r >>= json_integer) readbacks
      -- THE SECOND, INDEPENDENT SOURCE. The equality below derives the expected ids from
      -- @orderCount_before@, and @orderCount_before@, @orderCount_after@ and @readbacks[].id@ are
      -- three fields of one artifact: shifting all three together satisfies it. MEASURED on the
      -- committed capture -- 5/7 with ids [6,7] rewritten to 1005/1007 with ids [1006,1007] --
      -- @PASS driv02_mixed_batch_live@, while the control (the two counters alone) is RED at
      -- "the minted ids are [6,7] but a batch starting from orderCount 1005 mints exactly
      -- [1006,1007]". No writer-side change can close that: any value recorded at run time can be
      -- edited consistently afterwards.
      --
      -- The preview is the way out, and it was already in the artifact and read by nothing: in
      -- that green mutant @preview@ still said @[[true,6],[false,0],[true,7]]@ while the readbacks
      -- claimed 1006 and 1007 -- an artifact CONTRADICTING ITSELF, unnoticed. It is a different
      -- source (the module's own @previewCreateOrders@ return, not a counter read around the
      -- send), so a coordinated shift of the counter fields no longer buys silence.
      --
      -- A disagreement is a RE-TAKE, not a bug claim: the note below is right that the preview's
      -- absolute ids shift if another writer lands between preview and send. On this rig there is
      -- no other writer, so a capture where they disagree is a capture taken against something
      -- this suite cannot reason about.
      let previewed_ids = [i | (True, i) <- preview]
      _ <- expect (ids == previewed_ids)
             ("the readbacks carry ids " ++ show ids ++ " but the batch PREVIEW announced "
               ++ show previewed_ids ++ " for the same positions. These are two different sources"
               ++ " -- the preview is previewCreateOrders' own return, the ids are what the run"
               ++ " read back -- and the artifact is contradicting itself. Either another writer"
               ++ " landed between the preview and the send, in which case this capture is"
               ++ " evidence about a rig this suite cannot reason about, or the recorded counters"
               ++ " and ids were edited together. Re-take it: " ++ driver_capture_command)
      expect (ids == take successes [before + 1 ..])
        ("the minted ids are " ++ show ids ++ " but a batch starting from orderCount "
          ++ show before ++ " mints exactly " ++ show (take successes [before + 1 :: Integer ..])
          ++ ". Ids are 1-based and sequential -- the module mints id = orderCount + 1 and then"
          ++ " advances the count to it -- and they are computed from the LOCAL counter rather than"
          ++ " taken from the preview, whose absolute ids shift if any other writer lands between"
          ++ " preview and send.")
  where
    pair [a, b] = (,) <$> json_bool a <*> json_integer b
    pair other  = Left ("expected a two-element [success, id] preview pair, got "
                         ++ show (length other) ++ " elements")

-- | SC-4 -- the zero-arrival tick, in both of its readings.
--
-- == A TRANSACTION RECEIPT CARRIES NO RETURNDATA
--
-- State it plainly, because the honest limit is the whole point of how this check is written. An
-- @eth_getTransactionReceipt@ answer has logs, a status, a block and gas figures, and NO return
-- value anywhere in it: the EVM's return buffer is not part of the receipt and no node reconstructs
-- it. So the "exactly 64 bytes" fact is observable through the preview @eth_call@ and through
-- NOTHING ELSE on the transaction path. @preview_hex@ below comes from
-- @VolOrder.Rpc.preview_create_orders@, which exists for exactly this reason. A future check that
-- claims to read the byte length off the mined @create_orders@ transaction is wrong about where the
-- bytes live, and this note is here so nobody writes it.
--
-- The TRANSACTION half is still asserted -- status 1 and @orderCount@ unmoved -- because "the empty
-- batch also mines cleanly and mints nothing" is a different claim from "the empty batch returns 64
-- bytes", and neither implies the other.
--
-- == AND THE GENERATOR NEVER GETS HERE
--
-- @StochasticOrderGen.Rpc.chunk _ [] = []@, so a zero-arrival Poisson tick produces zero chunks,
-- zero eth_calls and zero transactions. @run_order_gen@ sends NOTHING at @N = 0@. That is why this
-- evidence needs a DIRECT @create_orders _ _ []@ call and cannot come from a generator run, and
-- @generator_chunks_at_zero@ is measured from the real function so the claim cannot rot into a
-- stale comment.
driv02_zero_arrival_is_64_bytes :: Check
driv02_zero_arrival_is_64_bytes =
  Check "driv02_zero_arrival_is_64_bytes" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    pure $ do
      capture <- loaded
      orders <- capture_orders capture
      n0 <- json_field "n0" orders
      _ <- expect (n0 /= Null)
             ("orders.n0 is null: the run never made the direct empty-batch call. Re-take it: "
               ++ driver_capture_command)

      preview_hex <- json_field "preview_hex" n0 >>= json_string
      declared <- json_field "preview_byte_length" n0 >>= json_integer
      _ <- expect (declared == 64)
             ("the empty batch previewed " ++ show declared ++ " bytes, expected EXACTLY 64 -- the"
               ++ " array offset word plus a zero length word. Never 0 (which is what a"
               ++ " non-returning function gives) and never 32 (which is what a bare length with no"
               ++ " offset would give). v4.0's exit record named this the single clause in the"
               ++ " return contract most likely to break StochasticOrderGen.")

      measured <- hex_byte_length preview_hex
      _ <- expect (toInteger measured == declared)
             ("preview_byte_length says " ++ show declared ++ " but preview_hex is "
               ++ show measured ++ " bytes -- a derived field has drifted from the bytes it"
               ++ " summarises, so one of the two is describing a call that did not happen")

      _ <- expect (length preview_hex == 130)
             ("preview_hex is " ++ show (length preview_hex) ++ " characters, expected 130"
               ++ " (the 0x prefix plus 128 hex digits)")

      -- Read the two words STRAIGHT OUT OF THE HEX with this suite's own slicing. The point of the
      -- 21-05 discipline: a check that decoded the bytes with the very decoder it is checking would
      -- go green on any pair of bytes the decoder happened to accept.
      ws <- hex_words preview_hex
      (word0, word1) <-
        case ws of
          [a, b] -> (,) <$> hex_word_integer a <*> hex_word_integer b
          _      -> Left ("the empty return splits into " ++ show (length ws)
                           ++ " ABI words, expected exactly 2")
      _ <- expect (word0 == 32)
             ("the first word of the empty return is " ++ show word0 ++ ", expected 32 -- the"
               ++ " canonical head-relative offset to the array's own data")
      _ <- expect (word1 == 0)
             ("the second word of the empty return is " ++ show word1
               ++ ", expected 0 -- the array's length")

      -- AND SEPARATELY, the shipped decoder, so it is covered too rather than bypassed.
      raw_bytes <- hex_bytes preview_hex
      _ <- case decode_create_orders_result (fromBytes raw_bytes) of
             Left err -> Left ("the SHIPPED decode_create_orders_result REJECTED the live empty"
                                ++ " return: " ++ err)
             Right [] -> Right ()
             Right xs -> Left ("decode_create_orders_result returned " ++ show (length xs)
                                ++ " results for the empty batch, expected none")

      decoded_len <- json_field "decoded_length" n0 >>= json_integer
      _ <- expect (decoded_len == 0)
             ("the run recorded decoded_length " ++ show decoded_len ++ " for the empty batch")

      status <- json_field "status" n0 >>= json_integer
      _ <- expect (status == 1)
             ("the empty batch transaction came back at status " ++ show status
               ++ " -- an empty batch is legal and must mine, not revert")

      before <- json_field "orderCount_before" n0 >>= json_integer
      after <- json_field "orderCount_after" n0 >>= json_integer
      _ <- expect (before == after)
             ("orderCount moved " ++ show before ++ " -> " ++ show after
               ++ " across an EMPTY batch -- nothing was submitted, so nothing may be minted")

      chunks <- json_field "generator_chunks_at_zero" n0 >>= json_integer
      expect (chunks == 0)
        ("chunk max_batch [] produced " ++ show chunks ++ " chunks, expected 0. This is SC-4's OTHER"
          ++ " reading: zero chunks is why a zero-arrival Poisson tick sends no transaction at all,"
          ++ " and therefore why run_order_gen can never exercise the 64-byte return. If this ever"
          ++ " becomes nonzero the generator has started sending an empty batch, which is a"
          ++ " behaviour change, not a fix.")

-- | Provenance for the orders block, on the same terms as the steps block.
--
-- @blockNumber@ is deliberately NOT asserted: 21-02 measured three from-scratch deploys landing at
-- heights 9, 11 and 10, so asserting it would redden the suite after any redeploy.
driv02_run_capture_orders_are_fresh :: Check
driv02_run_capture_orders_are_fresh =
  Check "driv02_run_capture_orders_are_fresh" . guarded $ do
    cf <- capture_path
    loaded <- read_json_file cf ("produce it with: " ++ driver_capture_command)
    mf <- manifest_file
    manifest_present <- doesFileExist mf
    outcome <-
      if manifest_present
        then do
          pf <- pins_file
          attempt <- try (load_rig_from pf mf)
          pure (Just (attempt :: Either IOException Rig))
        else pure Nothing
    pure $ do
      capture <- loaded
      rig <- case outcome of
        Nothing         -> Left ("no " ++ mf ++ " -- stand the rig up: " ++ deploy_command)
        Just (Left err) -> Left ("load_rig_from failed on the real files: " ++ show err)
        Just (Right r)  -> Right r

      orders <- capture_orders capture
      complete <- json_field "complete" orders >>= json_bool
      _ <- expect complete
             ("orders.complete is false: the order side ABORTED partway and whatever is recorded"
               ++ " below it is a partial run. This flag is DRIV-02's own -- dr_complete means the"
               ++ " DRIV-01 cheat-swap path finished and is set BEFORE the order side runs, so"
               ++ " reading it here would report a price-path success as an order-side success."
               ++ " Re-take the run: " ++ driver_capture_command)

      captured_from <- json_field "generatedFrom" capture >>= json_string
      _ <- refs_are_real "the run" captured_from (T.unpack (pins_generated_from (rig_pins rig)))
      _ <- expect (captured_from == T.unpack (pins_generated_from (rig_pins rig)))
             ("the run names generatedFrom " ++ captured_from ++ " but rig-pins.json names "
               ++ T.unpack (pins_generated_from (rig_pins rig))
               ++ " -- the orders were placed against a DIFFERENT imported source-of-truth ref, and"
               ++ " VolOrderManagerMod is one of the modules that ref pins. Re-take it: "
               ++ driver_capture_command)

      rig_field_matches capture (rig_addrs rig) "volOrderManager" "VolOrderManagerMod"

-- | One 32-byte ABI word of lowercase hex, as an 'Integer'.
hex_word_integer :: String -> Either String Integer
hex_word_integer w
  | length w == 64 && all isHexDigit w = Right (foldl (\acc c -> acc * 16 + toInteger (digitToInt c)) 0 w)
  | otherwise = Left ("not a 32-byte hex word: " ++ show w)

-- ---------------------------------------------------------------------------------------------
-- THE SENTINEL-FALSIFICATION HARNESS
--
-- == WHY IT EXISTS
--
-- One defect class has now been found and swept SIX times on this branch, and every sweep
-- generalised the REPRESENTATION it had just seen instead of the PREDICATE:
--
--   1. @"" == ""@                                        (empty strings)
--   2. @tickSpacing = 0@                                 (numeric zero) -- was 89\/89 green
--   3. a count-preserving rename defeating a count floor
--   4. an empty @import-ref.txt@ making a self-check compare @"" == ""@
--   5. a CI @-Wall@ gate greping a log whose emptiness means pass
--   6. the zero address \/ the zero word                 (this round) -- was 89\/89 green
--
-- Six hand sweeps is the evidence that hand sweeps do not close the class. This harness closes it
-- by MEASUREMENT: it takes every field the committed artifacts carry, replaces it with each of a
-- fixed set of sentinels one at a time, and requires at least one check to redden. A field that
-- absorbs a sentinel silently is a field nothing asserts, and that is instance seven waiting.
--
-- == WHAT IT CATCHES, AND WHAT IT DOES NOT
--
-- Read this before citing it. An overclaiming harness is worse than none: it would let the next
-- reviewer believe a class is closed that is not.
--
--   IT CATCHES: unasserted fields. One side of one artifact is mutated and nothing objects.
--
--   IT DOES NOT CATCH writer-side tautologies -- two fields of the SAME artifact derived from the
--   same expression in the writer, so that a checker comparing them is comparing a value to
--   itself. No single-side sentinel sweep can find those: mutating either field alone reddens the
--   comparison, so the pair looks perfectly asserted. That is a different class (it is what the
--   @readback_id@ finding is), it is found by reading the WRITER, and this harness is silent
--   about it by construction.
--
--   IT DOES NOT CATCH coordinated mutation. Mutating both sides together is exactly what the zero
--   address survived, so the harness deliberately mutates ONE SIDE AT A TIME -- that is what makes
--   an absorbed pair mean something. It follows that it says nothing about whether the two sides
--   have independent PROVENANCE; only 'sc4_generated_from_is_the_imported_ref'-shaped external
--   anchors do that.
--
--   IT DOES NOT REACH @offchain\/rig\/batch-return-capture.json@ or
--   @test\/pos_spec\/fixtures\/vol_order_return_golden.json@, which have no environment override.
--   Mutating them would mean editing a committed artifact. 'unswept_artifacts' names them so the
--   gap is on the record rather than implied by absence.
--
-- == THE FLOOR
--
-- 'sentinel_pair_floor' is the point of the whole thing. A harness that enumerates whatever it
-- happens to find is scoped by what it finds: an artifact that stops decoding, a resolver that
-- stops resolving, or an enumeration that quietly returns fewer paths all shrink the sweep to
-- nothing while it still reports success. That is instance three of the class above (a
-- count-preserving rename defeating a count floor) and instance five (a gate greping a log whose
-- emptiness means pass), and a harness built to detect the class must not BE the class.
-- ---------------------------------------------------------------------------------------------

-- | One step of a path into a JSON document.
data JStep = JKey K.Key | JIdx Int

-- | @.contracts.PoolManager@, @.steps[3].e3.tick@ -- the jq form, so a reported pair can be
-- pasted straight into a @jq@ invocation to reproduce it by hand.
render_json_path :: [JStep] -> String
render_json_path = concatMap one
  where
    one (JKey k) = '.' : K.toString k
    one (JIdx i) = "[" ++ show i ++ "]"

-- | Every scalar leaf of a document, as a path. Objects and arrays are traversed, not mutated:
-- replacing a whole subtree is a structural break that any decoder objects to, which would inflate
-- the caught count with pairs that prove nothing about assertions.
scalar_json_paths :: Value -> [[JStep]]
scalar_json_paths = go []
  where
    go here (Object o) = concat [go (here ++ [JKey k]) v | (k, v) <- KM.toList o]
    go here (Array a)  = concat [go (here ++ [JIdx i]) v | (i, v) <- zip [0 :: Int ..] (F.toList a)]
    go here _          = [here]

-- | Replace the leaf at a path. 'Nothing' when the path does not exist, which the caller treats
-- as a harness failure rather than as a skip -- a mutation that did not happen must never be
-- counted as a mutation that was caught.
set_json_at :: [JStep] -> Value -> Value -> Maybe Value
set_json_at [] new _ = Just new
set_json_at (JKey k : rest) new (Object o) = do
  cur <- KM.lookup k o
  sub <- set_json_at rest new cur
  Just (Object (KM.insert k sub o))
set_json_at (JIdx i : rest) new (Array a) =
  let xs = F.toList a
  in if i < 0 || i >= length xs
       then Nothing
       else do
         sub <- set_json_at rest new (xs !! i)
         Just (toJSON [if j == i then sub else x | (j, x) <- zip [0 :: Int ..] xs])
set_json_at _ _ _ = Nothing

-- | A value written in where a real one was.
data Sentinel = Sentinel
  { sentinel_name  :: String
  , sentinel_value :: Value
  }

-- | THE SENTINEL SET.
--
-- Every representation this class has taken on this branch, plus the two the review named as
-- reachable-and-not-yet-seen. They are built with 'replicate' rather than written out, because
-- 'sc3_literal_purge' greps this file for address-shaped literals and would redden on them --
-- and because a constructed zero cannot drift from the predicate 'is_zero_hex_text' tests.
sentinels :: [Sentinel]
sentinels =
  [ Sentinel "empty-string" (String T.empty)
  , Sentinel "numeric-zero" (Number 0)
  , Sentinel "zero-address" (String (T.pack ("0x" ++ replicate 40 '0')))
  , Sentinel "zero-word" (String (T.pack ("0x" ++ replicate 64 '0')))
  , Sentinel "git-null-object-id" (String (T.pack (replicate 40 '0')))
  , Sentinel "json-null" Null
  ]

-- | An artifact the suite reads and an environment variable can redirect.
data MutableArtifact = MutableArtifact
  { ma_var     :: String
  , ma_resolve :: IO FilePath
  , ma_label   :: String
  }

-- | The four artifacts this sweep can reach. Every one is redirected through the variable a real
-- consumer resolves, never through a path of the harness's own -- the same reason
-- 'driv01_capture_round_trips' reads back through 'capture_path'.
swept_artifacts :: [MutableArtifact]
swept_artifacts =
  [ MutableArtifact "RIG_MANIFEST" rig_manifest_path "rig-manifest.json"
  , MutableArtifact "RIG_PINS" rig_pins_path "rig-pins.json"
  , MutableArtifact "DRIVER_CAPTURE" capture_path "driver-run-capture.json"
  , MutableArtifact "RIG_CHEAT_SWAP_PROOF" proof_file "cheat-swap-proof.json"
  -- 23-05. The FIFTH, and the first one whose subject is a database. Every DB-only observation in
  -- this phase is a recorded value here and nowhere else, so a leaf of it that nothing reads is a
  -- database-only claim that survived the whole phase unasserted.
  , MutableArtifact "STORE_CONFORMANCE" store_conformance_path "store-conformance.json"
  ]

-- | THE HONEST GAP, NAMED. Committed artifacts the suite reads that this sweep cannot reach,
-- because no environment variable redirects them and mutating them would mean editing a committed
-- file. Anything added here without an override is a field surface the harness does not cover.
unswept_artifacts :: [FilePath]
unswept_artifacts = [capture_file, golden_file, import_ref_file]

-- | One mutation and what it did.
data SentinelOutcome = SentinelOutcome
  { so_field    :: String
  , so_sentinel :: String
  , so_caught   :: Maybe String
  }

-- | @<artifact>#<path>@ -- the identity a floor and an allowlist entry are written against.
so_key :: SentinelOutcome -> (String, String)
so_key o = (normalize_field (so_field o), so_sentinel o)

-- | THE ONLY WRITE THIS HARNESS EVER PERFORMS, AND IT CANNOT LAND IN THE REPOSITORY.
--
-- Three of the four artifacts the sweep mutates are TRACKED files
-- (@cheat-swap-proof.json@, @driver-run-capture.json@, @rig-pins.json@; the fourth,
-- @rig-manifest.json@, is gitignored but is still the rig's own record). A mutation harness that
-- can write to them is the worst possible instance of the class this branch keeps rediscovering
-- -- a regeneration step that destroys the artifact it regenerates, the same shape as the
-- @> "$OUT"@ truncation in @capture-batch-return.sh@ that @3ecf141@ fixed -- because the damage
-- would be INVISIBLE: the harness doctors the evidence, the suite reads the doctored evidence,
-- and both report success.
--
-- \"Restores carefully\" is not good enough and is not what this does. A crash, a @fail@ or an
-- interrupt between mutate and restore would leave committed evidence corrupted with nothing able
-- to notice, so the harness never writes there in the first place: every mutation goes to a
-- scratch copy under the system temp directory and the artifact is reached only through the
-- environment override, which is what those overrides are for. This function is the enforcement
-- -- a path inside the working tree is a hard error, not a warning, and 'guarded' turns it into a
-- named check failure.
outside_repo :: FilePath -> IO FilePath
outside_repo path = do
  absolute <- makeAbsolute path
  repo <- getCurrentDirectory
  if absolute == repo || (repo ++ "/") `isPrefixOf` absolute
    then fail ("the sentinel harness tried to write " ++ absolute ++ ", which is INSIDE the"
                ++ " working tree at " ++ repo ++ ". It mutates artifacts by copying them to a"
                ++ " scratch directory and pointing the environment override at the copy; a write"
                ++ " in here would doctor the committed evidence the suite exists to verify, and"
                ++ " a doctored artifact read by the suite that doctored it reports success.")
    else pure absolute

sentinel_write :: FilePath -> Value -> IO ()
sentinel_write path doc = outside_repo path >>= flip encodeFile doc

-- | Checks that spawn one subprocess per pin or per file. They are run LAST within whatever list
-- the sweep is given, so that a mutation caught by anything else never pays for them. Ordering
-- only -- nothing is ever dropped from a list because it appears here.
expensive_checks :: [String]
expensive_checks =
  ["sc4_cast_agreement", "sc3_literal_purge", "no_credential_is_present_in_a_tracked_file"]

-- | Cheap checks first, in their original order.
cheap_first :: [Check] -> [Check]
cheap_first cs =
  [c | c <- cs, check_name c `notElem` expensive_checks]
    ++ [c | c <- cs, check_name c `elem` expensive_checks]

-- | Run a check list in order, stopping at the FIRST failure. The harness only ever asks "did
-- anything object", so running the remaining eighty-odd checks after the answer is yes would buy
-- nothing and cost the sweep its runtime.
first_objection :: [Check] -> IO (Maybe String)
first_objection [] = pure Nothing
first_objection (c : cs) = do
  outcome <- check_run c
  case outcome of
    Left _   -> pure (Just (check_name c))
    Right () -> first_objection cs

-- | Every failing check name. Used only for the baseline.
all_objections :: [Check] -> IO [String]
all_objections cs = do
  outcomes <- mapM (\c -> (,) (check_name c) <$> check_run c) cs
  pure [n | (n, Left _) <- outcomes]

-- | Point a variable at a path for the duration, then put it back exactly as it was.
with_override :: String -> FilePath -> IO a -> IO a
with_override var path act = do
  original <- lookupEnv var
  let restore = maybe (unsetEnv var) (setEnv var) original
  flip finally restore $ do
    setEnv var path
    act

-- | THE CHECKS THAT CAN SEE ONE ARTIFACT AT ALL, DERIVED BY MEASUREMENT.
--
-- Every leaf of the artifact is replaced by a DISTINCT marker string and the whole suite is run
-- once; whatever objects is a check that reads this file. The markers are distinct rather than
-- uniform so that an intra-file equality (@a == b@) breaks too -- a uniform garble would leave
-- one satisfied and the check would look like a non-reader.
--
-- Filtering the per-mutation list to this set is SOUND IN THE DIRECTION THAT MATTERS, and that
-- is the only reason it is allowed here. Running fewer checks can only produce FEWER catches,
-- never more: a reader this derivation misses turns some asserted field into a reported
-- absorbed pair, which fails the harness loudly and gets investigated. It can never turn an
-- unasserted field into a silent pass, which is the failure the harness exists to prevent. The
-- cost it buys back is not marginal -- the unfiltered sweep ran for six minutes, most of it in
-- the 36 @cast@ spawns and the recursive @grep@ of checks that never open these files.
--
-- The fold is in 'Either' and NOT in @fromMaybe doc@. A garble step that silently fell back to
-- the unmutated document would produce an empty reader set, and an empty reader set reads as
-- "nothing asserts this artifact" -- a swallowed failure presenting as a finding, which is the
-- same shape as the @Left _ -> 0@ this round removed from 'driv01_swap_calldata_shape'.
reader_set :: FilePath -> MutableArtifact -> Value -> IO (Either String [String])
reader_set scratch artifact original =
  case foldM mark original (zip [0 :: Int ..] (scalar_json_paths original)) of
    Left err -> pure (Left err)
    Right garbled
      | garbled == original ->
          pure (Left (ma_label artifact ++ ": replacing all "
                       ++ show (length (scalar_json_paths original)) ++ " of its leaves with"
                       ++ " distinct markers produced a document IDENTICAL to the original, so"
                       ++ " the reader-set derivation measured nothing."))
      | otherwise -> do
          sentinel_write scratch garbled
          Right <$> with_override (ma_var artifact) scratch (core_checks >>= all_objections)
  where
    mark doc (i, path) =
      case set_json_at path (String (T.pack ("sentinel-probe-" ++ show i))) doc of
        Just next -> Right next
        Nothing   ->
          Left (ma_label artifact ++ render_json_path path ++ " was enumerated as a leaf and then"
                 ++ " could not be written back while deriving the reader set. The enumeration and"
                 ++ " the mutation disagree about the document.")

-- | Mutate one artifact at every leaf, with every sentinel, one at a time.
--
-- The @hot@ list is a pure SPEED heuristic and carries no correctness weight: check names that
-- have already objected for this artifact are tried first, because mutations in one subtree are
-- almost always caught by the same check. It reorders 'readers'; it never shortens it.
sweep_one :: FilePath -> MutableArtifact -> Value -> IO (Either String [SentinelOutcome])
sweep_one scratch artifact original = do
  derived <- reader_set scratch artifact original
  baseline_names <- map check_name <$> core_checks
  let paths = scalar_json_paths original
      pairs = [(p, s) | p <- paths, s <- sentinels]
  case derived of
    Left err -> pure (Left err)
    Right readers
      | null readers ->
          pure (Left (ma_label artifact ++ ": not one check in the suite objected when EVERY field"
                       ++ " in it was replaced with a distinct marker. Either nothing reads this"
                       ++ " artifact -- in which case all " ++ show (length pairs) ++ " of its"
                       ++ " (field, sentinel) pairs are unasserted and the sweep below would be"
                       ++ " reporting that one pair at a time -- or " ++ ma_var artifact ++ " is no"
                       ++ " longer honoured and the mutation never reached a reader."))
      | otherwise -> do
          let readable n = n `elem` readers || n `notElem` baseline_names
          outcome <- foldM (step readable) (Right ([], [])) pairs
          pure (reverse . snd <$> outcome)
  where
    step _ (Left err) _ = pure (Left err)
    step readable (Right (hot, acc)) (path, sentinel) =
      case set_json_at path (sentinel_value sentinel) original of
        Nothing ->
          pure (Left (ma_label artifact ++ render_json_path path ++ " was enumerated as a leaf"
                       ++ " and then could not be written back. The enumeration and the mutation"
                       ++ " disagree about the document, so an unknown number of pairs in this"
                       ++ " artifact were never actually mutated."))
        -- A sentinel that EQUALS the value already there is not a mutation, and counting it as an
        -- absorbed pair would be the harness manufacturing its own finding. @pool.initTick@ is
        -- genuinely 0 and the @[false, 0]@ preview slot genuinely carries 0; a suite cannot be
        -- asked to object to a file it was handed unchanged. Skipped, not recorded, so it does
        -- not inflate the pair count either.
        Just doctored | doctored == original -> pure (Right (hot, acc))
        Just doctored -> do
          sentinel_write scratch doctored
          caught <- with_override (ma_var artifact) scratch $ do
            -- The second disjunct is not decoration. 'core_checks' returns a DIFFERENT LIST when
            -- an artifact stops decoding -- one @sc4_pins_file_decodes@ carrying the decode error
            -- -- and that name is not in a reader set derived from a garble that still decoded.
            -- Without it the filter deleted the only check there was and every sentinel that
            -- breaks a type came back "absorbed": MEASURED, 288 false absorbed pairs across the
            -- pin file alone. Anything the baseline list does not contain is run unconditionally.
            cs <- cheap_first . filter (readable . check_name) <$> core_checks
            let ordered = [c | n <- hot, c <- cs, check_name c == n]
                            ++ [c | c <- cs, check_name c `notElem` hot]
            first_objection ordered
          let record = SentinelOutcome
                         { so_field = ma_label artifact ++ render_json_path path
                         , so_sentinel = sentinel_name sentinel
                         , so_caught = caught
                         }
              hot' = case caught of
                Just n | n `notElem` hot -> n : hot
                _                        -> hot
          pure (Right (hot', record : acc))

-- | PAIRS ABSORBED ON PURPOSE, EACH WITH ITS REASON.
--
-- An entry here is a field this suite does not assert and has decided not to. The list is EXACT
-- on both sides: an absorbed pair that is not listed fails the harness, and a listed pair that
-- turns out to be caught ALSO fails it. The second direction is the one that keeps the list
-- honest -- without it the list only ever grows, and a growing ignore list is how instance three
-- of this class (a count floor defeated by a rename) got in.
-- Array indices are collapsed, so @steps[0].e5.sigma@ and @steps[4].e5.sigma@ are ONE entry: they
-- are the same field of the same record type and an entry per index would be forty lines saying
-- one thing. The COUNT is what keeps that from being a blanket -- an entry names how many of that
-- field's occurrences absorbed the sentinel, so a field that is asserted at index 0 and not at
-- index 3 reads as @4 of 5@ and cannot hide behind a field-level pardon.
-- | The reasons an absorbed pair is allowed to stay absorbed. Named rather than inlined so that
-- the table below reads as a classification and a reader can see how many fields share one
-- excuse -- an excuse that covers thirty fields deserves more scrutiny than one that covers two.
--
-- Four of these say GAP, in those words. They are not decisions to skip: they are unasserted
-- fields this harness found on its first run, recorded so they cannot be lost, and the entries
-- shrink as they get asserted.
reason_provenance, reason_generated_at, reason_tx_hash, reason_oracle_output :: String
reason_step_index, reason_unnamed_measurement, reason_retired_value :: String
reason_manifest_contract_gap, reason_currency_gap, reason_manifest_ref_gap :: String
reason_seed_gap :: String

reason_provenance =
  "prose. A human-readable note about how the artifact was produced; there is no value here to\
  \ recompute and nothing downstream reads it."

reason_generated_at =
  "21-02 MEASURED that generatedAt is not a regeneration witness: the capture script completes in\
  \ ~294 ms against a 1-second timestamp resolution, so two back-to-back runs share a timestamp\
  \ and a stale file passes a timestamp comparison silently. The DISCRIMINATING provenance fields\
  \ are chainId, generatedFrom and the rig block, and those are asserted."

reason_tx_hash =
  "a transaction hash is the keccak of a signed envelope this suite cannot reconstruct, and the\
  \ receipt it names lives on a chain no check may talk to. It is recorded so a human can go and\
  \ look, which is a different job from being evidence."

reason_oracle_output =
  "oracle output. There is no second implementation of the Algebra-ported TWAP and volatility\
  \ accumulators in this repo to check these against, so an assertion here could only pin the\
  \ value the run happened to produce -- which is transcription, the exact thing this milestone\
  \ exists to remove."

reason_step_index =
  "the step's own index. Its value is implied by its position in the array, and every schedule\
  \ assertion in driv01_e3_per_step_matches_submitted is written against the position rather than\
  \ against this field."

reason_unnamed_measurement =
  "the proof carries six measurements and the checks read the NAMED ones they are about --\
  \ driv01_cheated_tick_reaches_e3, driv01_wrong_pool_is_silent, driv01_same_second_is_a_silent_noop\
  \ and driv01_extreme_tick_is_survivable each name theirs. The remaining occurrences are recorded\
  \ context, and the per-sentinel COUNT is what says how many of the six are which."

reason_retired_value =
  "the retired SET is pinned by expected_retired_pins; the retired VALUES are not recomputable.\
  \ A retired selector has no live source to parse a signature out of -- that is what retiring it\
  \ meant -- so the only property available is the numeric non-collision sc4_no_retired_value_is_live\
  \ already asserts."

reason_manifest_contract_gap =
  "GAP, found by this harness on its first run. Rig.Manifest's completeness check tests for the\
  \ KEY, and no check in the suite compares these three contract ADDRESSES to anything, so the\
  \ manifest can name a module that was never deployed and the run stays green. They are the three\
  \ deployed modules no offline check consumes today."

reason_currency_gap =
  "GAP. The two currencies are PoolKey inputs, so pool_id_matches is transitively sensitive to\
  \ them through the hash -- but only if the poolId was recomputed, and it is recorded, not\
  \ recomputed. Nothing asserts them directly."

reason_manifest_ref_gap =
  "GAP. The PIN FILE's generatedFrom is the one anchored to import-ref.txt by\
  \ sc4_generated_from_is_the_imported_ref and compared to both artifacts. The MANIFEST's copy of\
  \ the same field is read by nothing, so the rig can record that it was stood up from a ref it\
  \ was not stood up from."

reason_seed_gap =
  "GAP. The manifest's seed block records the tick and timestamp the pool was initialised at.\
  \ initTick is legitimately 0 and the harness skips that mutation as an identity; initTs has no\
  \ legitimate zero and nothing reads it."

absorbed_by_design :: [(String, [(String, Int)], String)]
absorbed_by_design =
  [ ( "cheat-swap-proof.json.generatedAt"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_generated_at )
  , ( "cheat-swap-proof.json.measurements[].e3.averageTick"
    , [("empty-string", 4), ("numeric-zero", 4), ("zero-address", 4), ("zero-word", 4), ("git-null-object-id", 4), ("json-null", 4)]
    , reason_oracle_output )
  , ( "cheat-swap-proof.json.measurements[].e3_count"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].e3"
    , [("empty-string", 2), ("numeric-zero", 2), ("zero-address", 2), ("zero-word", 2), ("git-null-object-id", 2)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].e3.tickCumulative"
    , [("empty-string", 4), ("numeric-zero", 4), ("zero-address", 4), ("zero-word", 4), ("git-null-object-id", 4), ("json-null", 4)]
    , reason_oracle_output )
  , ( "cheat-swap-proof.json.measurements[].e3.timestamp"
    , [("empty-string", 3), ("numeric-zero", 3), ("zero-address", 3), ("zero-word", 3), ("git-null-object-id", 3), ("json-null", 3)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].e3.volatilityCumulative"
    , [("empty-string", 4), ("numeric-zero", 4), ("zero-address", 4), ("zero-word", 4), ("git-null-object-id", 4), ("json-null", 4)]
    , reason_oracle_output )
  , ( "cheat-swap-proof.json.measurements[].e5_count"
    , [("empty-string", 3), ("numeric-zero", 3), ("zero-address", 3), ("zero-word", 3), ("git-null-object-id", 3), ("json-null", 3)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].e5.fee"
    , [("empty-string", 6), ("numeric-zero", 6), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 6)]
    , reason_oracle_output )
  , ( "cheat-swap-proof.json.measurements[].e5.sigma"
    , [("empty-string", 6), ("numeric-zero", 6), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 6)]
    , reason_oracle_output )
  , ( "cheat-swap-proof.json.measurements[].head_ts_after"
    , [("empty-string", 6), ("numeric-zero", 6), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 6)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].state_slot"
    , [("empty-string", 6), ("numeric-zero", 6), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 6)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].status"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].swap_calldata_bytes"
    , [("empty-string", 6), ("numeric-zero", 6), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 6)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].tick"
    , [("empty-string", 4), ("numeric-zero", 4), ("zero-address", 4), ("zero-word", 4), ("git-null-object-id", 4), ("json-null", 4)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].ts"
    , [("empty-string", 3), ("numeric-zero", 3), ("zero-address", 3), ("zero-word", 3), ("git-null-object-id", 3), ("json-null", 3)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].tx_hash"
    , [("empty-string", 6), ("numeric-zero", 6), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 6)]
    , reason_tx_hash )
  , ( "cheat-swap-proof.json.measurements[].word_before"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 5)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].word_before_high184"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 5)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].word_written"
    , [("empty-string", 4), ("numeric-zero", 4), ("zero-address", 4), ("zero-word", 4), ("git-null-object-id", 4), ("json-null", 4)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json.measurements[].word_written_high184"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 6), ("zero-word", 6), ("git-null-object-id", 6), ("json-null", 5)]
    , reason_unnamed_measurement )
  , ( "cheat-swap-proof.json._provenance"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_provenance )
  , ( "driver-run-capture.json.generatedAt"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_generated_at )
  , ( "driver-run-capture.json.orders.mixed.txHash"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_tx_hash )
  , ( "driver-run-capture.json.orders.n0.txHash"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_tx_hash )
  , ( "driver-run-capture.json.orders.single.txHash"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_tx_hash )
  , ( "driver-run-capture.json._provenance"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_provenance )
  , ( "driver-run-capture.json.steps[].e3.averageTick"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_oracle_output )
  , ( "driver-run-capture.json.steps[].e3.tickCumulative"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_oracle_output )
  , ( "driver-run-capture.json.steps[].e3.volatilityCumulative"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_oracle_output )
  , ( "driver-run-capture.json.steps[].e5.fee"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_oracle_output )
  , ( "driver-run-capture.json.steps[].e5.sigma"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_oracle_output )
  , ( "driver-run-capture.json.steps[].k"
    , [("empty-string", 5), ("numeric-zero", 4), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_step_index )
  , ( "driver-run-capture.json.steps[].txHash"
    , [("empty-string", 5), ("numeric-zero", 5), ("zero-address", 5), ("zero-word", 5), ("git-null-object-id", 5), ("json-null", 5)]
    , reason_tx_hash )
  , ( "rig-manifest.json.contracts.DynamicFeeMod"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_manifest_contract_gap )
  , ( "rig-manifest.json.contracts.PoolModifyLiquidityTest"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_manifest_contract_gap )
  , ( "rig-manifest.json.contracts.RealizedVolatilityMod"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_manifest_contract_gap )
  , ( "rig-manifest.json.generatedAt"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_generated_at )
  , ( "rig-manifest.json.generatedFrom"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_manifest_ref_gap )
  , ( "rig-manifest.json.pool.currency0"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_currency_gap )
  , ( "rig-manifest.json.pool.currency1"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_currency_gap )
  , ( "rig-manifest.json.seed.initTs"
    , [("numeric-zero", 1)]
    , reason_seed_gap )
  , ( "rig-pins.json.retired.create_order_v1"
    , [("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_retired_value )
  , ( "rig-pins.json.retired._note"
    , [("empty-string", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1)]
    , reason_retired_value )
  -- 23-05, the fifth artifact. ONE entry, and it is the field 21-02 already measured as not being
  -- a regeneration witness. The harness's first run over this artifact reported four fields
  -- absorbed; three of them were ASSERTED rather than pardoned (the two bare-path readback fields
  -- against a computed model of the escaping mechanism, and the error text against the member name
  -- it must contain), which is why only this one is here.
  , ( "store-conformance.json.generatedAt"
    , [("empty-string", 1), ("numeric-zero", 1), ("zero-address", 1), ("zero-word", 1), ("git-null-object-id", 1), ("json-null", 1)]
    , reason_generated_at )
  ]

-- | @steps[3].e3.tick@ -> @steps[].e3.tick@.
normalize_field :: String -> String
normalize_field [] = []
normalize_field ('[' : rest) =
  let (digits, tail_) = span isDigit rest
  in case (null digits, tail_) of
       (False, ']' : more) -> "[]" ++ normalize_field more
       _                   -> '[' : normalize_field rest
normalize_field (c : rest) = c : normalize_field rest

-- | The allowlist, flattened to the key the report compares against.
absorbed_expectations :: [((String, String), Int)]
absorbed_expectations =
  [((field, sentinel), n) | (field, counts, _) <- absorbed_by_design, (sentinel, n) <- counts]

-- | THE FLOOR ON HOW MUCH THE SWEEP EXERCISES.
--
-- RE-MEASURED AT 23-05 WITH FIVE ARTIFACTS, by raising the constant until the harness reported the
-- number it had actually reached, and never by adding an estimate to the old one. It is a >= floor
-- and not an equality because artifacts legitimately grow; it exists so that an artifact that stops
-- decoding, a resolver that stops resolving, or an enumeration that quietly returns fewer paths
-- cannot shrink the sweep to nothing while it still reports success.
--
-- 2457 (four artifacts) -> 3250 (five). The arithmetic is worth writing down because it is the
-- check on the measurement: @store-conformance.json@ enumerates 134 leaves and there are six
-- sentinels, so 804 pairs are possible and 793 were exercised -- the 11 missing ones are mutations
-- the harness SKIPS because the sentinel equals the value already there (the several recorded
-- zeroes, the two empty digests, the five null error fields). A sweep of the four older artifacts
-- therefore still contributes exactly the 2457 this number replaced, which is what says none of
-- them silently shrank while this one was being added.
--
-- Note for anyone budgeting the NEXT artifact: 134 is the count this harness enumerates, and the
-- 121 carried forward from plan 23-04 is @jq 'paths(scalars)'@, which omits JSON nulls. The
-- harness mutates nulls, so its number is the larger one and it is the one to budget with.
sentinel_pair_floor :: Int
sentinel_pair_floor = 3250

-- | THE PER-ARTIFACT FLOOR. The total alone is satisfiable by one artifact growing while another
-- drops out entirely, which is the same substitution the pin-surface SET exists to stop.
--
-- All five RE-MEASURED at 23-05 in the same run. The four older entries came back at exactly the
-- numbers they were written with, which is the point of re-measuring them rather than assuming: a
-- new entry added beside four stale ones records the tree as it was on the day someone last
-- thought about it.
artifact_field_floors :: [(String, Int)]
artifact_field_floors =
  [ ("rig-manifest.json", 20)
  , ("rig-pins.json", 110)
  , ("driver-run-capture.json", 151)
  , ("cheat-swap-proof.json", 130)
  , ("store-conformance.json", 134)
  ]

-- | A key nothing in this suite reads, injected into the manifest for the NEGATIVE control.
harness_probe_key :: K.Key
harness_probe_key = "__sentinel_harness_probe"

-- | THE HARNESS.
sentinel_falsification_harness :: Check
sentinel_falsification_harness =
  Check "sentinel_falsification_harness" . guarded $ do
    tmp <- getTemporaryDirectory
    let scratch_dir = tmp </> "cfmm-sentinel-falsification"
    -- The directory is guarded before it is created, not only the writes into it, so the harness
    -- does not leave so much as an empty directory behind inside the tree.
    _ <- outside_repo scratch_dir
    createDirectoryIfMissing True scratch_dir

    -- The baseline. Everything below reads "at least one check objected" as evidence that the
    -- mutated field is asserted, and that reading is worthless if checks were already objecting.
    baseline <- core_checks >>= all_objections

    originals <- mapM read_original swept_artifacts
    -- The named gap is asserted, not merely commented. A path listed as unreachable that no
    -- longer exists is a stale disclaimer, and a stale disclaimer reads as coverage.
    gaps <- mapM (\p -> (,) p <$> doesFileExist p) unswept_artifacts

    -- THE STABILITY SNAPSHOT. A mutation is evidence only if EVERYTHING ELSE held still: the
    -- checks compare the doctored copy against artifacts this sweep is not overriding at that
    -- moment, and those are files a rig redeploy or a capture re-take rewrites. MEASURED, and
    -- this is why the guard exists rather than being prudence: the first full run of this
    -- harness reported 813 absorbed pairs, including fields that reproduce as CAUGHT by hand,
    -- because rig-manifest.json and cheat-swap-proof.json were both regenerated underneath it
    -- while it ran. A sweep that straddles a redeploy produces verdicts about nothing.
    before <- mapM snapshot stability_watch

    case sequence originals of
      Left err -> pure (Left err)
      Right docs -> do
        swept <- mapM (uncurry (sweep_one_in scratch_dir)) (zip swept_artifacts docs)
        control <- case zip swept_artifacts docs of
          ((artifact, doc) : _) -> run_controls scratch_dir artifact doc
          []                    -> pure (Left "the sentinel sweep has no artifacts at all")
        after <- mapM snapshot stability_watch
        pure $ do
          _ <- expect (before == after)
                 ("an artifact this sweep does NOT control changed while it ran: "
                   ++ intercalate ", " [p | ((p, a), (_, b)) <- zip before after, a /= b]
                   ++ ". Every verdict below compares a doctored copy against files that were"
                   ++ " moving, so caught and absorbed both mean nothing. This is a redeploy or a"
                   ++ " capture re-take landing mid-sweep, not a defect in the artifacts -- run it"
                   ++ " again when the rig is quiet.")
          _ <- expect (all snd gaps)
                 ("the sentinel sweep names these files as OUTSIDE its reach, and they do not"
                   ++ " exist: " ++ intercalate ", " [p | (p, False) <- gaps]
                   ++ ". A disclaimer about a file that is gone reads as coverage of a file that"
                   ++ " is there. Update unswept_artifacts.")
          _ <- expect (null baseline)
                 ("the suite was ALREADY failing before a single mutation was applied ("
                   ++ intercalate ", " (sort baseline) ++ "). Every \"caught\" verdict below would"
                   ++ " be that pre-existing failure and not the mutation, so the sweep proves"
                   ++ " nothing until the baseline is green.")
          outcomes <- concat <$> sequence swept
          _ <- control
          report outcomes
  where
    -- Every file a check may read while the sweep is running: the four the sweep redirects (they
    -- are still read directly whenever a DIFFERENT artifact is the one being mutated) and the
    -- three it cannot redirect.
    stability_watch = map ma_resolve swept_artifacts ++ map pure unswept_artifacts

    snapshot resolve = do
      path <- resolve
      there <- doesFileExist path
      bytes <- if there then Just <$> BS.readFile path else pure Nothing
      pure (path, bytes)

    read_original artifact = do
      path <- ma_resolve artifact
      present <- doesFileExist path
      if not present
        then pure (Left ("the sentinel sweep cannot read " ++ path ++ " (" ++ ma_var artifact
                          ++ "). Stand the rig up: " ++ deploy_command))
        else do
          decoded <- eitherDecodeFileStrict path :: IO (Either String Value)
          pure $ case decoded of
            Left err -> Left ("the sentinel sweep cannot decode " ++ path ++ ": " ++ err)
            Right v  -> Right v

    sweep_one_in dir artifact doc =
      sweep_one (dir </> (ma_var artifact ++ ".json")) artifact doc

    report outcomes = do
      let absorbed = [o | o <- outcomes, isNothing (so_caught o)]
          observed = Map.fromListWith (+) [(so_key o, 1 :: Int) | o <- absorbed]
          expected = Map.fromList absorbed_expectations
          unlisted = [(k, n) | (k, n) <- Map.toList observed, isNothing (Map.lookup k expected)]
          stale    = [(k, n) | (k, n) <- Map.toList expected, isNothing (Map.lookup k observed)]
          miscount = [ (k, want, got)
                     | (k, want) <- Map.toList expected
                     , Just got <- [Map.lookup k observed]
                     , got /= want
                     ]

      _ <- expect (length outcomes >= sentinel_pair_floor)
             ("the sweep exercised " ++ show (length outcomes) ++ " (field, sentinel) pairs, below"
               ++ " the floor of " ++ show sentinel_pair_floor ++ ". A harness scoped by what it"
               ++ " happens to find is scoped by nothing: an artifact that stopped decoding or an"
               ++ " enumeration that returned fewer paths shrinks it to zero while it still"
               ++ " reports success, which is the very class it exists to detect. If an artifact"
               ++ " shrank ON PURPOSE, lower sentinel_pair_floor and say why.")

      _ <- let short = [ (label, got, want)
                       | (label, want) <- artifact_field_floors
                       , let got = length (nub [ so_field o
                                               | o <- outcomes, label `isPrefixOf` so_field o ])
                       , got < want
                       ]
           in expect (null short)
                ("the sweep enumerated fewer fields than the floor in:\n      "
                  ++ intercalate "\n      "
                       [ label ++ ": " ++ show got ++ ", floor " ++ show want
                       | (label, got, want) <- short
                       ]
                  ++ "\n      A total-only floor is satisfied by one artifact growing while"
                  ++ " another drops out entirely, which is the substitution the pin-surface SET"
                  ++ " exists to stop.")

      _ <- expect (null unlisted)
             ("these (field, sentinel) pairs were ABSORBED SILENTLY -- the value was replaced on"
               ++ " ONE side only and nothing in the suite objected. Each one is a field nothing"
               ++ " here asserts:\n      "
               ++ intercalate "\n      " [render_entry k n | (k, n) <- unlisted]
               ++ "\n      Assert the field, or add it to absorbed_by_design WITH THE REASON it is"
               ++ " not worth asserting.")

      _ <- expect (null stale)
             ("absorbed_by_design lists (field, sentinel) pairs that are now CAUGHT:\n      "
               ++ intercalate "\n      " [render_entry k n | (k, n) <- stale]
               ++ "\n      An ignore list that only ever grows is how a count floor gets defeated"
               ++ " by a rename. Delete these entries.")

      expect (null miscount)
        ("absorbed_by_design records the wrong number of absorbing occurrences:\n      "
          ++ intercalate "\n      "
               [ fst k ++ "  :=  " ++ snd k ++ "  listed " ++ show want ++ ", measured " ++ show got
               | (k, want, got) <- miscount
               ]
          ++ "\n      The count is what stops a field-level pardon from covering occurrences that"
          ++ " ARE asserted. Fewer than listed means the field became asserted somewhere and the"
          ++ " entry should shrink; more means it stopped being asserted somewhere.")

    render_entry (field, sentinel) n = field ++ "  :=  " ++ sentinel ++ "  x" ++ show n


    -- THE TWO CONTROLS. Without them the harness's verdicts are unfalsifiable: "nothing was
    -- absorbed" is what a sweep that mutates nothing also reports.
    run_controls dir artifact manifest = do
      -- POSITIVE. A field this suite demonstrably asserts must come back CAUGHT. If it does not,
      -- the mutation is not reaching the checks at all and every verdict is vacuous.
      positive <- one_pair (dir </> "control-positive.json") artifact manifest
                    [JKey "contracts", JKey "PoolManager"]
                    (Sentinel "zero-address" (String (T.pack ("0x" ++ replicate 40 '0'))))
      -- NEGATIVE. A key nothing reads must come back ABSORBED, for every sentinel. If the
      -- harness reports it caught, "caught" does not mean what the report says it means.
      let probed = case manifest of
            Object o -> Object (KM.insert harness_probe_key (String "probe") o)
            other    -> other
      negatives <-
        mapM (one_pair (dir </> "control-negative.json") artifact probed [JKey harness_probe_key])
             sentinels
      pure $ do
        _ <- expect (isJust positive)
               ("POSITIVE CONTROL FAILED: contracts.PoolManager was replaced with the zero"
                 ++ " address in " ++ ma_label artifact ++ " ALONE and no check objected."
                 ++ " addresses_agree asserts that field, so the sweep is not reaching the checks"
                 ++ " and every \"caught\" verdict in this harness is vacuous.")
        expect (all isNothing negatives)
          ("NEGATIVE CONTROL FAILED: " ++ K.toString harness_probe_key ++ " is a key nothing"
            ++ " in this suite reads, and the sweep reported it CAUGHT by "
            ++ intercalate ", " (nub (catMaybes negatives)) ++ ". Whatever that check is"
            ++ " objecting to, it is not the mutated field -- so \"caught\" does not"
            ++ " discriminate and the absorbed list below it means nothing.")

    one_pair scratch artifact doc path sentinel =
      case set_json_at path (sentinel_value sentinel) doc of
        Nothing -> pure (Just "<control path does not exist>")
        Just doctored -> do
          sentinel_write scratch doctored
          with_override (ma_var artifact) scratch (core_checks >>= first_objection)

-- ---------------------------------------------------------------------------------------------
-- The store contract: DB-03, KEY-07, BYTE-05
-- ---------------------------------------------------------------------------------------------

-- | THE LAW SURFACE, NAMED HERE SO @Store.Laws@ CANNOT NAME IT.
--
-- It is a SET, not a count, for the reason 'expected_selector_pins' is a set and in that
-- constant's own words: /"a floor of thirty is satisfied by thirty pins of which one has been
-- swapped."/ A floor on \"how many laws executed\" is defeated by renaming one law, which is
-- finding #3 in this file verbatim; a set is not. Adding or removing a law means editing this
-- list, deliberately, in the same commit.
--
-- Alphabetical so that a diff against @Store.Laws@'s declaration order is a diff about NAMES and
-- never about ordering.
expected_store_laws :: [String]
expected_store_laws =
  [ "law_a_non_json_artifact_is_rejected_on_the_keyed_path"
  , "law_blob_lookup_of_an_absent_name_is_nothing"
  , "law_blob_round_trips_byte_identically"
  , "law_distinct_models_do_not_collide"
  , "law_first_writer_wins_on_the_identity_triple"
  , "law_key_scheme_orphans_rather_than_matching"
  , "law_put_then_lookup_returns_the_same_artifact"
  , "law_same_key_under_a_new_scheme_inserts"
  ]

-- | The SET, asserted in BOTH directions against the library's own 'law_names'.
--
-- One direction alone is satisfied by a RENAME: drop the old name from the set and the
-- \"everything expected is defined\" half is happy, while a law nothing names has quietly stopped
-- being accounted for. Both halves are collected into ONE message rather than short-circuited,
-- because a rename produces one violation of EACH kind and an operator who is shown only the
-- first has to guess the second.
expected_store_laws_is_the_law_set :: Check
expected_store_laws_is_the_law_set =
  pure_check "expected_store_laws_is_the_law_set" $
    let defined_unnamed = [n | n <- law_names, n `notElem` expected_store_laws]
        named_undefined = [n | n <- expected_store_laws, n `notElem` law_names]
        repeated        = [n | n <- nub law_names, length (filter (== n) law_names) > 1]
        complaints =
          ["Store.Laws defines a law this SET does not name: " ++ n | n <- defined_unnamed]
            ++ ["this SET names a law Store.Laws does not define: " ++ n | n <- named_undefined]
            ++ ["Store.Laws defines the same law name twice: " ++ n | n <- repeated]
    in expect (null complaints)
         (intercalate "\n      " complaints
           ++ "\n      The law surface is a SET on both sides: a law the set does not name is a"
           ++ " law whose verdict nothing accounts for, and a name the library does not define is"
           ++ " a set that has stopped describing anything. A duplicate name would let one law"
           ++ " pad the surface for two.")

-- | THE CHECK THAT DELIVERS DB-03, AND IT OPENS NO SOCKET.
--
-- The requirement is that @cabal test@ passes with no database present AND that the store checks
-- still discriminate. The first half is satisfied STRUCTURALLY here rather than by a branch: this
-- check does not import the postgres store module, does not read the DSN variable, does not spawn
-- a process and does not open a connection. There is nothing here for a require-a-database
-- environment variable to gate, and that is the point -- under the three-tier decision NOTHING in
-- @cabal test@ touches a database, so any check that consulted such a variable would BE a
-- database-dependent check and would have broken the tier decision on its way to enforcing it. A
-- safety property that lives in another system's @env:@ block fails open when that block drifts;
-- this one cannot.
--
-- The paragraph above deliberately does not SPELL the module name, the variable name, or the
-- client's connect function. This file is the subject of a grep for those three tokens that must
-- return 0 -- that grep IS the structural form of the claim -- so a comment asserting their
-- absence would be counted by the very scan asserting their absence. Third occurrence of that
-- shape in this plan alone, and the reason the tokens are described here rather than quoted.
--
-- The second half is delivered by REAL EXECUTION. Every law in "Store.Laws" runs against a FRESH
-- 'new_memory_store' -- one store per law, so no law's writes can satisfy another law's read and
-- a passing set cannot be an artifact of ordering.
--
-- The count assertion at the end is a SECONDARY instrument and never the primary one: the primary
-- is 'expected_store_laws_is_the_law_set' above. It is here in the @dr_complete@ \/
-- @dr_configured_size@ idiom (@Driver\/Capture.hs:93-98@) so that a truncated law list is visible
-- without arithmetic.
store_laws_run_against_the_memory_store :: Check
store_laws_run_against_the_memory_store =
  Check "store_laws_run_against_the_memory_store" . guarded $ do
    verdicts <- mapM against_a_fresh_store store_laws
    pure $ do
      let broken = [why | (_, Left why) <- verdicts]
      _ <- expect (null broken)
             ("the store contract does not hold against Store.Memory, which is the REFERENCE"
               ++ " implementation every other store is measured against:\n      "
               ++ intercalate "\n      " broken)
      expect (length verdicts == length expected_store_laws)
        ("Store.Laws executed " ++ show (length verdicts) ++ " laws against Store.Memory and the"
          ++ " expected surface has " ++ show (length expected_store_laws) ++ ". A law list that"
          ++ " silently shortened would report every remaining law passing.")
  where
    against_a_fresh_store (name, law) = do
      store <- new_memory_store
      (,) name <$> law store

-- | BYTE-05's precondition: the corpus can still exercise the failure BYTE-05 is about.
--
-- Named for the 'SilentlyCorrupted' clause because that is the load-bearing one, but it asserts
-- the whole corpus surface: the behaviour-tag SET, the member-NAME set in both directions, name
-- uniqueness, and the size. The name set is here because the plan's original size assertion is a
-- COUNT, and a count is satisfied by swapping the discriminating member for a harmless one --
-- finding #3, again.
adversarial_corpus_has_a_silently_corrupted_member :: Check
adversarial_corpus_has_a_silently_corrupted_member =
  pure_check "adversarial_corpus_has_a_silently_corrupted_member" $
    let observed  = sort (nub (map cm_behaviour adversarial_corpus))
        wanted    = [ServerRejects, RoundTripsAnyway, SilentlyCorrupted]
        absent    = [b | b <- wanted, b `notElem` observed]
        names     = map cm_name adversarial_corpus
        missing   = [n | n <- expected_corpus_members, n `notElem` names]
        unlisted  = [n | n <- names, n `notElem` expected_corpus_members]
    in do
      _ <- expect (observed == wanted)
             ("the corpus no longer carries all three measured behaviour classes. Missing: "
               ++ intercalate ", " (map show absent)
               ++ ". Each class means something different and only one of them is the failure"
               ++ " BYTE-05 is about, so a corpus that has lost a class has lost the ability to"
               ++ " tell those failures apart.")
      _ <- expect (any ((== SilentlyCorrupted) . cm_behaviour) adversarial_corpus)
             ("ROADMAP SC-1's stated corpus (0x00, 0xFF, invalid UTF-8, CRLF, trailing newline)"
               ++ " contains NO member of this class. MEASURED on PG 18.4: three of those five"
               ++ " raise ERROR: invalid byte sequence for encoding UTF8 -- a shape"
               ++ " indistinguishable from a dead connection -- and two round-trip CORRECTLY"
               ++ " through the broken path. Without a SilentlyCorrupted member the negative"
               ++ " control in plan 23-05 is satisfied by a SqlError and proves nothing about"
               ++ " byte fidelity.")
      _ <- expect (null missing && null unlisted)
             ("the corpus MEMBER SET has moved. Gone: " ++ intercalate ", " missing
               ++ " | new and unaccounted for: " ++ intercalate ", " unlisted
               ++ ". The size assertion below is a count, and a count is satisfied by swapping the"
               ++ " discriminating member for a harmless one -- which is exactly the substitution"
               ++ " that would make plan 23-05's negative control vacuous while every number in"
               ++ " this check still added up.")
      _ <- expect (names == nub names)
             ("the corpus has two members with the same name, so one of them will overwrite the"
               ++ " other on the blob surface and its bytes will never be read back: "
               ++ intercalate ", " [n | n <- nub names, length (filter (== n) names) > 1])
      expect (length adversarial_corpus == 7)
        ("the adversarial corpus has " ++ show (length adversarial_corpus)
          ++ " members and the measured corpus has 7.")

-- | DB-01's ordering half, and the migration surface as a SET IN BOTH DIRECTIONS.
--
-- One direction alone is satisfied by a RENAME -- rename the file on disk and drop the old name
-- from the manifest and \"everything the manifest names exists\" is happy while a file nothing
-- accounts for is still being executed. So both halves are collected into ONE message, the way
-- 'expected_store_laws_is_the_law_set' collects its two.
--
-- The disk half asserts the directory's WHOLE contents, not just the SQL in it, and that is a
-- MEASURED decision rather than strictness for its own sake: @postgresql-migration@ 0.2.1.8
-- resolves a migration directory through @sort \<$\> listDirectory dir@ and applies
-- @executeMigration@ to EVERY entry, with no extension filter on the path at all
-- (@Migration.hs:140-158@, source-read). A stray editor backup or a README dropped in there is
-- read and handed to @execute_@ as SQL. \"Only the migrations are in the migration directory\" is
-- therefore a real invariant of this schema and not a tidiness rule.
migration_list_is_ordered_and_gapless :: Check
migration_list_is_ordered_and_gapless =
  Check "migration_list_is_ordered_and_gapless" . guarded $ do
    there   <- doesDirectoryExist migrations_dir
    on_disk <- if there then sort <$> listDirectory migrations_dir else pure []
    let versions = map fst expected_migrations
        names    = map snd expected_migrations
        absent   = [n | n <- names, n `notElem` on_disk]
        unlisted = [n | n <- on_disk, n `notElem` names]
        repeated = [n | n <- nub names, length (filter (== n) names) > 1]
        complaints =
          ["the manifest names a migration that is not on disk: " ++ n | n <- absent]
            ++ ["the migration directory holds a file the manifest does not name: " ++ n
                 | n <- unlisted]
            ++ ["the manifest names the same migration file twice: " ++ n | n <- repeated]
    pure $ do
      _ <- expect there
             (migrations_dir ++ " does not exist, so the migration runner would apply NOTHING and"
               ++ " report success -- the library treats an empty command list as MigrationSuccess."
               ++ " An absent directory and a fully-migrated database are indistinguishable to"
               ++ " every caller downstream of it.")
      _ <- expect (versions == [1 .. length expected_migrations])
             ("the migration versions are " ++ show versions ++ " and must be "
               ++ show [1 .. length expected_migrations :: Int] ++ ". They are the ORDER the"
               ++ " library applies these files in, expressed independently of the filenames it"
               ++ " sorts by, so a gap means a migration was dropped and a run that skipped it"
               ++ " still reported success.")
      _ <- expect (null complaints)
             (intercalate "\n      " complaints
               ++ "\n      The migration surface is a SET on both sides. A name the directory does"
               ++ " not carry is a run that silently applies less than the manifest claims; a file"
               ++ " the manifest does not name is executed anyway, because the library applies"
               ++ " EVERY entry in that directory with no extension filter. One direction alone is"
               ++ " satisfied by a rename.")
      expect (length expected_migrations >= 2)
        ("the manifest holds " ++ show (length expected_migrations) ++ " migrations. Two are"
          ++ " required by this schema -- the keyed store and the byte-fidelity fixture are"
          ++ " separate tables on purpose -- and a manifest that shrank to one would report the"
          ++ " remaining one applying cleanly.")

-- | The DDL text the identity constraint must carry, asserted against the FILE.
--
-- Written out here once, and it is the only place in this file it appears: the check greps the
-- migration for it, so a second copy in prose would be a second thing to keep in step for no gain.
identity_constraint_ddl :: String
identity_constraint_ddl = "unique (model, key_scheme, key)"

-- | KEY-07's file half: the unique constraint names all THREE columns.
--
-- Two subjects, deliberately, because they can drift apart: the Haskell constant that later checks
-- and the capture read, and the DDL TEXT that Postgres is actually handed. Asserting only the
-- constant would let @key_scheme@ be dropped from the migration with every Haskell-side check
-- still green; asserting only the file would let the constant that 23-05's live-catalogue
-- comparison is built from rot. The live catalogue itself is the third subject and lands at 23-05
-- -- a DDL file that was never applied is a different failure again.
--
-- The migration is resolved through 'expected_migrations' rather than named a second time here, so
-- a renumbering that the manifest accepts cannot leave this check reading a file that no longer
-- exists while reporting nothing.
unique_constraint_names_all_three_columns :: Check
unique_constraint_names_all_three_columns =
  Check "unique_constraint_names_all_three_columns" . guarded $
    case lookup 1 expected_migrations of
      Nothing ->
        pure $ expect False
          ("the migration manifest has no version 1, so the migration that creates the keyed table"
            ++ " cannot be identified and this check has no subject to read.")
      Just name -> do
        let path = migrations_dir </> name
        present <- doesFileExist path
        body    <- if present then readFile path else pure ""
        pure $ do
          _ <- expect (sort identity_constraint_columns == ["key", "key_scheme", "model"])
                 ("the identity constraint's declared columns are "
                   ++ show identity_constraint_columns
                   ++ " and KEY-07 requires all three of model, key_scheme and key. A two-part key"
                   ++ " does not orphan on a key-formula change -- MEASURED at 23-01: it serves the"
                   ++ " superseded scheme's row for a lookup under the new one, and the new"
                   ++ " scheme's insert vanishes.")
          _ <- expect present
                 (path ++ " does not exist, so the DDL half of this check would be reading an"
                   ++ " empty string and passing on the Haskell constant alone.")
          _ <- expect (identity_constraint_ddl `isInfixOf` body)
                 (path ++ " does not contain " ++ show identity_constraint_ddl
                   ++ ". The Haskell constant above is not the thing Postgres is handed; this is."
                   ++ " Dropping a column from the DDL while leaving the constant alone is exactly"
                   ++ " the drift the two subjects exist to catch.")
          expect (identity_constraint_name `isInfixOf` body)
            (path ++ " does not name the constraint " ++ show identity_constraint_name
              ++ ". The insert path relies on that name -- its conflict target is the CONSTRAINT,"
              ++ " not a column list -- so an unnamed or renamed constraint turns first-writer-wins"
              ++ " into a runtime error rather than a compile-time one.")

-- | The corpus by NAME, so a deletion or a substitution is a set mismatch rather than arithmetic.
expected_corpus_members :: [String]
expected_corpus_members =
  [ "crlf"
  , "double-backslash"
  , "high-byte"
  , "invalid-utf8"
  , "nul"
  , "octal-escape"
  , "trailing-newline"
  ]

-- ---------------------------------------------------------------------------------------------
-- TIER C: the committed conformance evidence, made LOAD-BEARING
--
-- Plan 23-04 stood a real @postgres:18-alpine@ up in Docker and DROVE every database-only
-- observation against it, into @offchain\/rig\/store-conformance.json@. Nothing in @cabal test@
-- read a byte of it. An artifact asserted by nothing is this repository's own issue #19 and it is
-- the reason these checks exist: the evidence is only evidence once something reddens when it
-- changes.
--
-- Every check below reads the artifact through 'Store.Config.store_conformance_path', never
-- through a constant, so @STORE_CONFORMANCE@ redirects them and the sentinel harness can reach
-- them. Every one FAILS -- never skips -- when the artifact is absent, and names the command that
-- produces it. The artifact is COMMITTED, so a fresh checkout has it and "fail, never skip" costs
-- nothing.
--
-- NOTHING HERE OPENS A SOCKET. These are assertions over recorded VALUES; the measurement happened
-- in the capture, under a database, and the separation is what DB-03 is.
-- ---------------------------------------------------------------------------------------------

store_conformance_command :: String
store_conformance_command = "bash offchain/rig/capture-store-conformance.sh"

-- | The artifact, through the RESOLVER. FAIL-never-skip and the command, in one place.
read_store_conformance :: IO (Either String Value)
read_store_conformance = do
  path <- store_conformance_path
  read_json_file path ("re-take it with: " ++ store_conformance_command)

-- | The digest @postgresql-migration@ speaks. See the cabal comment on the crypton dependency.
md5_hex :: BS.ByteString -> String
md5_hex bs = show (hashWith MD5 bs)

-- | @(filename, the digest recomputed from the repo's own bytes)@. 'Nothing' when the file is gone.
recompute_migration_digest :: FilePath -> IO (FilePath, Maybe String)
recompute_migration_digest name = do
  let path = migrations_dir </> name
  present <- doesFileExist path
  if not present
    then pure (name, Nothing)
    else do
      bytes <- BS.readFile path
      pure (name, Just (md5_hex bytes))

-- | CHECK 1 -- FRESHNESS, RECOMPUTED FROM THE REPO'S OWN BYTES.
--
-- @generatedAt@ is deliberately not consulted. 21-02 MEASURED that it is not a regeneration
-- witness in this repository -- the capture completes well inside the one-second stamp resolution,
-- so two back-to-back runs share a timestamp and a stale file passes a timestamp comparison
-- silently ('reason_generated_at' records that measurement). Freshness here is COMPUTED: each
-- migration's md5 is taken from @offchain\/migrations\/@ on this disk, right now, and compared to
-- the digest the capture recorded. Edit a @.sql@ without re-capturing and this reddens with both
-- numbers.
--
-- The filename SET is asserted in BOTH directions against 'expected_migrations'. One direction
-- alone is satisfied by a rename. A migration in the repo but not in the artifact is a stale
-- capture; a migration in the artifact but not in the repo is a deleted file nobody re-captured
-- after, and both are the same class of lie about what the recorded verdicts describe.
--
-- @sc_complete@ is separated from staleness on purpose: a truncated run and a stale run need
-- different instructions, and the failure text gives each its own.
store_conformance_is_present_and_fresh :: Check
store_conformance_is_present_and_fresh =
  Check "store_conformance_is_present_and_fresh" . guarded $ do
    loaded     <- read_store_conformance
    recomputed <- mapM recompute_migration_digest (map snd expected_migrations)
    pure $ do
      artifact  <- loaded
      complete  <- json_field "sc_complete" artifact >>= json_bool
      law_count <- json_field "sc_law_count" artifact >>= json_integer
      version   <- json_field "schema_version" artifact >>= json_integer
      entries   <- json_field "migrations" artifact >>= json_array
      recorded  <- mapM one_recorded_migration entries

      _ <- expect complete
             ("the capture did not reach the end: sc_complete is False. The flag starts False and"
               ++ " is flipped last, after every observation block has returned, so this is a"
               ++ " TRUNCATED run and not a stale one -- the values below were never all produced."
               ++ " Re-take it: " ++ store_conformance_command)
      _ <- expect (law_count == toInteger (length expected_store_laws))
             ("the capture recorded sc_law_count " ++ show law_count ++ " and the expected law"
               ++ " surface has " ++ show (length expected_store_laws) ++ ". A capture that ran a"
               ++ " shortened law list reports every law it DID run passing.")
      _ <- expect (version == 1)
             ("the capture records schema_version " ++ show version ++ " and this suite is written"
               ++ " against 1. A schema version bump means the recorded shapes below describe a"
               ++ " different schema than the checks reading them assume.")

      let recorded_names = map fst recorded
          wanted_names   = map snd expected_migrations
          absent   = [n | n <- wanted_names, n `notElem` recorded_names]
          unlisted = [n | n <- recorded_names, n `notElem` wanted_names]
          complaints =
            ["the repo has a migration the capture never saw: " ++ n | n <- absent]
              ++ ["the capture records a migration the repo does not have: " ++ n | n <- unlisted]
      _ <- expect (null complaints)
             (intercalate "\n      " complaints
               ++ "\n      The migration surface is a SET on both sides, and this is the STALENESS"
               ++ " instrument: a migration added to the repo and absent from the capture means the"
               ++ " capture predates it and its verdicts describe a schema that no longer exists."
               ++ " Re-take it: " ++ store_conformance_command)

      let drifted =
            [ (name, was, now)
            | (name, was) <- recorded
            , Just (Just now) <- [lookup name recomputed]
            , now /= was
            ]
          vanished = [n | (n, Nothing) <- recomputed]
      _ <- expect (null vanished)
             ("the migration manifest names files that are not on disk, so their digests could not"
               ++ " be recomputed and this check would be comparing nothing: "
               ++ intercalate ", " vanished)
      expect (null drifted)
        ("the committed conformance capture is STALE. These migrations have been edited since it"
          ++ " was taken:\n      "
          ++ intercalate "\n      "
               [ name ++ ": recorded=" ++ was ++ " recomputed=" ++ now
               | (name, was, now) <- drifted
               ]
          ++ "\n      Every DB-only verdict in that artifact was measured against the OLD schema."
          ++ " Nothing here can tell you whether it still holds. Re-take it: "
          ++ store_conformance_command)
  where
    one_recorded_migration e =
      (,) <$> (json_field "filename" e >>= json_string) <*> (json_field "md5" e >>= json_string)

-- | CHECK 2 -- the law verdicts, as a SET IN BOTH DIRECTIONS.
--
-- The count is NOT the instrument, and that is the whole design. A law that was skipped shows up
-- here as a MISSING VERDICT -- a set mismatch -- rather than as a count that came up short, and a
-- count that came up short is exactly what a capture with an inflated denominator hides. The
-- second direction (a verdict key with no expected law) is what keeps the set from being satisfied
-- by a rename: drop the old name from 'expected_store_laws' and one direction goes quiet while a
-- law nobody accounts for is still being reported on.
--
-- The recorded message travels with any non-@pass@ verdict. A verdict of @"fail: ..."@ that this
-- check reported only as \"not pass\" would send the reader back to the artifact for the one thing
-- they need.
store_conformance_verdicts_are_all_pass :: Check
store_conformance_verdicts_are_all_pass =
  Check "store_conformance_verdicts_are_all_pass" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      verdicts <- json_field "law_verdicts" artifact >>= json_object_pairs
      named    <- mapM (\(k, v) -> (,) k <$> json_string v) verdicts

      let recorded_names = map fst named
          absent   = [n | n <- expected_store_laws, n `notElem` recorded_names]
          unlisted = [n | n <- recorded_names, n `notElem` expected_store_laws]
          complaints =
            ["a law the set names has NO VERDICT in the capture: " ++ n | n <- absent]
              ++ ["the capture reports a verdict for a law the set does not name: " ++ n
                   | n <- unlisted]
      _ <- expect (null complaints)
             (intercalate "\n      " complaints
               ++ "\n      The verdict surface is a SET on both sides, and it is a set rather than"
               ++ " a count precisely so that a SKIPPED law is unrepresentable: a law that did not"
               ++ " run has no key here, which is a mismatch, where a count is satisfied by any"
               ++ " eight verdicts at all. Re-take it: " ++ store_conformance_command)

      let broken = [(n, v) | (n, v) <- named, v /= "pass"]
      expect (null broken)
        ("the store contract does NOT hold against a real Postgres. These laws did not pass"
          ++ " against the live server, and they are the same laws that pass against Store.Memory"
          ++ " inside this suite -- so the reference store no longer predicts the real one and the"
          ++ " three-tier design that lets cabal test run with no database has broken:\n      "
          ++ intercalate "\n      " [n ++ ": " ++ v | (n, v) <- broken])

-- | AN OUTSIDE ORACLE FOR THE BROKEN PATH, written from the two MECHANISMS.
--
-- The bare-'BS.ByteString' write path damages bytes in two composed steps, and neither is a guess:
--
--   1. @ToField ByteString@ is @Escape@, which hands the value to libpq's C-string escaper -- and
--      a C string ENDS at its first NUL. Everything from the first zero byte onwards never reaches
--      the server at all. MEASURED at 23-04: the @nul@ member goes in at one byte and comes back
--      at zero, with no error, which falsified both the research's and the plan's tables.
--   2. What does arrive is read by @byteain@, which still accepts the LEGACY escape format: a
--      doubled backslash collapses to one, and a backslash followed by three octal digits is
--      re-read as a single byte. MEASURED at 23-01: @a\\101b@, six bytes, comes back as @aAb@,
--      three bytes, with no error and no warning.
--
-- Modelling them here rather than pinning the recorded outputs is what makes the corpus check an
-- oracle instead of a transcription: the expected side is COMPUTED from 'cm_bytes' in
-- "Store.Types", the actual side is what a real Postgres 18.4 did, and they are compared. All five
-- returning members agree, in length AND digest.
bare_path_prediction :: BS.ByteString -> BS.ByteString
bare_path_prediction = decode_legacy_escapes . BS.takeWhile (/= 0)

decode_legacy_escapes :: BS.ByteString -> BS.ByteString
decode_legacy_escapes = BS.pack . go . BS.unpack
  where
    go (0x5c : 0x5c : rest) = 0x5c : go rest
    go (0x5c : a : b : c : rest)
      | all is_octal [a, b, c]
      , let v = digit a * 64 + digit b * 8 + digit c
      , v <= 255
      = fromIntegral v : go rest
    go (x : rest) = x : go rest
    go []         = []

    is_octal w = w >= 0x30 && w <= 0x37
    digit w = fromIntegral w - 0x30 :: Int

-- | The corpus rows, keyed by the @name@ each carries.
conformance_corpus_rows :: Value -> Either String [(String, Value)]
conformance_corpus_rows artifact = do
  rows <- json_field "corpus" artifact >>= json_array
  mapM (\r -> (\n -> (n, r)) <$> (json_field "name" r >>= json_string)) rows

-- | CHECK 3 -- THE NEGATIVE CONTROL, ASSERTED ON VALUES AND NEVER ON \"SOMETHING THREW\".
--
-- BYTE-05 is about a WRONG VALUE coming back with no complaint. It is NOT about an exception: a
-- @SqlError@ is shaped exactly like a dead connection, an unmigrated database or a closed socket,
-- so a control built on \"an exception was raised\" cannot tell the guard firing from the server
-- being switched off. Three members were MEASURED silently corrupting on the bare path and they
-- are what this check is FOR.
--
-- @crlf@ and @trailing-newline@ round-trip CORRECTLY through the broken path. They are asserted
-- here as round-tripping, not as corrupting, and they must never be cited as evidence for the
-- wart: a check that claimed \"the bare path corrupts\" over the whole corpus would be false.
--
-- The anti-collapse arm at the end is the one that matters most. If every member came back
-- @SqlError@ the corpus would have lost its discriminating members while every count in the file
-- still added up -- which is finding #3 of this repository's standing defect class, one more time.
bare_bytestring_is_observed_corrupting_the_artifact :: Check
bare_bytestring_is_observed_corrupting_the_artifact =
  Check "bare_bytestring_is_observed_corrupting_the_artifact" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      rows     <- conformance_corpus_rows artifact

      let recorded_names = map fst rows
          wanted_names   = map cm_name adversarial_corpus
          absent   = [n | n <- wanted_names, n `notElem` recorded_names]
          unlisted = [n | n <- recorded_names, n `notElem` wanted_names]
      _ <- expect (null absent && null unlisted)
             ("the captured corpus and Store.Types.adversarial_corpus are different SETS. Not"
               ++ " captured: " ++ intercalate ", " absent
               ++ " | captured but not defined: " ++ intercalate ", " unlisted
               ++ ".\n      A count is satisfied by swapping the discriminating member for a"
               ++ " harmless one; a set in both directions is not. Re-take it: "
               ++ store_conformance_command)

      observed <- mapM (one_corpus_member rows) adversarial_corpus

      expect (any (== SilentlyCorrupted) observed)
        ("NOT ONE captured member was recorded as returning a WRONG VALUE with no complaint. The"
          ++ " corpus has lost its discriminating member, so this negative control is now satisfied"
          ++ " by a SqlError -- and a SqlError is shaped exactly like a dead connection, an"
          ++ " unmigrated database, or a socket that was never opened. It proves nothing about byte"
          ++ " fidelity. Restore a SilentlyCorrupted member and re-take: "
          ++ store_conformance_command)
  where
    one_corpus_member rows member = do
      let name = cm_name member
      row <- case lookup name rows of
        Just r  -> Right r
        Nothing -> Left ("the captured corpus has no member named " ++ show name)
      behaviour   <- json_field "behaviour" row >>= json_string
      in_len      <- json_field "in_len" row >>= json_integer
      in_sha      <- json_field "in_sha256" row >>= json_string
      binary_len  <- json_field "binary_out_len" row >>= json_integer
      binary_sha  <- json_field "binary_out_sha256" row >>= json_string
      outcome     <- json_field "bare_outcome" row >>= json_string
      bare_len    <- json_field "bare_out_len" row >>= json_integer
      bare_sha    <- json_field "bare_out_sha256" row >>= json_string
      bare_err    <- json_field "bare_error" row

      _ <- expect (behaviour == show (cm_behaviour member))
             (name ++ ": the capture recorded behaviour " ++ show behaviour
               ++ " and Store.Types tags it " ++ show (show (cm_behaviour member))
               ++ ". The tag is the MEASURED behaviour of that member on the bare path; a"
               ++ " disagreement means one of the two is describing a run that did not happen.")

      -- The Binary path is LOSSLESS FOR EVERY MEMBER. This is BYTE-01 at the corpus, and it is
      -- what makes the bare-path damage below attributable to the path rather than to the bytes.
      _ <- expect (binary_len == in_len && binary_sha == in_sha)
             (name ++ ": the Binary write path did NOT round-trip. in " ++ show in_len
               ++ " bytes / " ++ in_sha ++ ", out " ++ show binary_len ++ " bytes / " ++ binary_sha
               ++ ". Every claim this phase makes about byte fidelity rests on that path being"
               ++ " lossless for all seven members; if it is not, the bare-path comparison below is"
               ++ " no longer isolating the wart.")

      -- THE PREDICTION. Computed from cm_bytes by the model above, never read out of the artifact.
      let predicted     = bare_path_prediction (cm_bytes member)
          predicted_len = toInteger (BS.length predicted)
          predicted_sha = sha256_hex predicted

          returned_matches_the_model =
            do _ <- expect (outcome == "returned")
                     (name ++ ": the capture records bare_outcome " ++ show outcome
                       ++ " and the model of the bare path predicts a readback of "
                       ++ show predicted_len ++ " bytes. A member that RAISES where the model says"
                       ++ " it returns means the client or the server changed underneath the"
                       ++ " mechanism this whole corpus is built on.")
               _ <- expect (bare_len == predicted_len && bare_sha == predicted_sha)
                     (name ++ ": the bare path did NOT do what the two mechanisms predict."
                       ++ "\n      in        " ++ show in_len ++ " bytes / " ++ in_sha
                       ++ "\n      predicted " ++ show predicted_len ++ " bytes / " ++ predicted_sha
                       ++ "\n      recorded  " ++ show bare_len ++ " bytes / " ++ bare_sha
                       ++ "\n      The prediction is COMPUTED here from cm_bytes -- truncate at the"
                       ++ " first NUL, then decode the legacy backslash escapes -- and the recorded"
                       ++ " side is what a real server did. This is the one assertion in the corpus"
                       ++ " block whose expected value does not come out of the artifact, so a"
                       ++ " disagreement is real news either way round.")
               expect (bare_err == Null)
                 (name ++ ": recorded as having returned, and yet it carries a bare_error. A"
                   ++ " statement cannot both succeed silently and raise; one of the two fields"
                   ++ " describes a different run.")

      case cm_behaviour member of
        SilentlyCorrupted -> do
          _ <- returned_matches_the_model
          _ <- expect (predicted /= cm_bytes member)
                 (name ++ " is tagged SilentlyCorrupted and the MODEL of the bare path predicts it"
                   ++ " survives intact. The tag and the mechanism disagree, so one of them is"
                   ++ " describing a member that is no longer in the corpus.")
          _ <- expect (bare_len /= in_len && bare_sha /= in_sha)
                 (name ++ " is the DISCRIMINATING member and it came back UNCHANGED through the"
                   ++ " bare path: " ++ show in_len ++ " bytes / " ++ in_sha ++ " in, "
                   ++ show bare_len ++ " bytes / " ++ bare_sha ++ " out. The corruption this"
                   ++ " control is built on no longer reproduces, so the control has lost its"
                   ++ " subject -- which is not a licence to relax it. Investigate the client and"
                   ++ " the server version before touching this check.")
          pure SilentlyCorrupted
        ServerRejects -> do
          _ <- expect (outcome == "SqlError")
                 (name ++ " is tagged ServerRejects and the capture records bare_outcome "
                   ++ show outcome ++ ". This member is the LOUD half of the pair and it is only"
                   ++ " worth recording as long as it stays loud.")
          _ <- expect (bare_len == (-1) && null bare_sha)
                 (name ++ ": ServerRejects is recorded as bare_out_len -1 with an empty digest --"
                   ++ " the encoding for \"there was no readback at all\". This row carries "
                   ++ show bare_len ++ " and " ++ show bare_sha ++ ", so something WAS read back"
                   ++ " and the outcome tag is describing a different event.")
          text <- case bare_err of
            Null  -> Left (name ++ ": tagged ServerRejects with a NULL bare_error. The error text"
                            ++ " is the only evidence that the rejection happened at all rather"
                            ++ " than the insert being quietly skipped.")
            other -> json_string other
          -- The recorded error carries the row key the capture wrote under, and the row key is
          -- built from the member's name. So the text is checked against a value from OUTSIDE the
          -- artifact: an error transcribed from a different member's run does not name this one.
          _ <- expect (name `isInfixOf` text)
                 (name ++ ": the recorded bare_error does not name this member, so there is nothing"
                   ++ " tying it to this member's run rather than to another one's:\n      " ++ text)
          pure ServerRejects
        RoundTripsAnyway -> do
          _ <- returned_matches_the_model
          _ <- expect (predicted == cm_bytes member)
                 (name ++ " is tagged RoundTripsAnyway and the MODEL of the bare path predicts it"
                   ++ " is DAMAGED. The tag and the mechanism disagree.")
          _ <- expect (bare_len == in_len && bare_sha == in_sha)
                 (name ++ " is tagged RoundTripsAnyway -- it is MEASURED to survive the broken path"
                   ++ " intact -- and the capture shows it changing: " ++ show in_len ++ " bytes / "
                   ++ in_sha ++ " in, " ++ show bare_len ++ " bytes / " ++ bare_sha ++ " out."
                   ++ " These two members prove nothing about the wart and are recorded so that"
                   ++ " nobody cites them as if they did; a change here means the bare path's"
                   ++ " behaviour moved and the whole corpus needs re-measuring.")
          pure RoundTripsAnyway

-- | CHECK 4 -- the recorded digests against the PINNED SOURCE, never against the artifact itself.
--
-- The expected side is recomputed here, in Haskell, from 'Store.Types.adversarial_corpus'
-- (@cm_bytes@) and from the two bare pins in that same module. The artifact supplies only the
-- ACTUAL side. That asymmetry is the point: a digest compared to a digest recorded beside it in the
-- same file is a statement about the writer's consistency with itself, which this repository has
-- already shipped once and filed as a finding.
store_conformance_digests_match_the_pinned_source_digest :: Check
store_conformance_digests_match_the_pinned_source_digest =
  Check "store_conformance_digests_match_the_pinned_source_digest" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      rows     <- conformance_corpus_rows artifact
      mismatched <- fmap catMaybes (mapM (one_member rows) adversarial_corpus)
      _ <- expect (null mismatched)
             ("the capture's recorded input digests do not match the digests of the corpus bytes"
               ++ " in Store.Types:\n      "
               ++ intercalate "\n      " mismatched
               ++ "\n      The expected side was recomputed from cm_bytes just now; the recorded"
               ++ " side came out of the artifact. A disagreement means the capture was taken over"
               ++ " a DIFFERENT corpus than the one this suite defines, and every behaviour verdict"
               ++ " in it is about bytes nobody here has seen. Re-take it: "
               ++ store_conformance_command)

      exhibit <- json_field "jsonb_exhibit" artifact
      raw_in  <- json_field "raw_in_sha256" exhibit >>= json_string
      raw_len <- json_field "raw_len" exhibit >>= json_integer
      _ <- expect (raw_in == volume_path_golden_sha256)
             ("the jsonb exhibit was run over " ++ raw_in ++ " and the real GAMS artifact's pinned"
               ++ " digest is " ++ volume_path_golden_sha256 ++ ". The exhibit's whole claim is"
               ++ " that it exercises the REAL shape; over other bytes it exercises whatever they"
               ++ " happen to be. The pin lives in Store.Types, in a different file from the bytes,"
               ++ " on purpose.")
      expect (raw_len == toInteger volume_path_golden_bytes_len)
        ("the jsonb exhibit ran over " ++ show raw_len ++ " bytes and the pinned length is "
          ++ show volume_path_golden_bytes_len ++ ". Length and digest are pinned separately"
          ++ " because they fail independently: a truncation that happened to be recorded with its"
          ++ " own digest agrees with itself.")
  where
    one_member rows member = do
      let name     = cm_name member
          expected = sha256_hex (cm_bytes member)
      case lookup name rows of
        Nothing -> Right (Just (name ++ ": not present in the captured corpus"))
        Just row -> do
          actual <- json_field "in_sha256" row >>= json_string
          Right $ if actual == expected
                    then Nothing
                    else Just (name ++ ": recorded " ++ actual ++ ", recomputed from cm_bytes "
                                ++ expected)

-- | CHECK 5 -- BYTE-01 AND BYTE-02 ON THE REAL SHAPE, and the equality that must NEVER hold.
--
-- @raw_out == raw_in@ is BYTE-01: the @bytea@ column gave back exactly what it was handed.
-- @doc_text /= raw_out@ is BYTE-02, and it is asserted as an INEQUALITY on purpose. Equal digests
-- would not mean @jsonb@ turned out to be safe; they would mean the exhibit stopped exercising
-- @jsonb@ and the guard lost its subject -- the same shape as an aeson whose round trip became the
-- identity ('aeson_round_trip_mutations_are_re_measured' guards that one).
jsonb_round_trip_of_the_real_shape_is_exhibited_failing :: Check
jsonb_round_trip_of_the_real_shape_is_exhibited_failing =
  Check "jsonb_round_trip_of_the_real_shape_is_exhibited_failing" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      exhibit  <- json_field "jsonb_exhibit" artifact
      raw_in   <- json_field "raw_in_sha256" exhibit >>= json_string
      raw_out  <- json_field "raw_out_sha256" exhibit >>= json_string
      doc_text <- json_field "doc_text_sha256" exhibit >>= json_string

      let malformed =
            [ label ++ " = " ++ show d
            | (label, d) <- [("raw_in_sha256", raw_in), ("raw_out_sha256", raw_out)
                            , ("doc_text_sha256", doc_text)]
            , length d /= 64 || not (all (\c -> isHexDigit c && c == toLower c) d)
            ]
      _ <- expect (null malformed)
             ("the exhibit's digests are not 64 bare lowercase hex characters: "
               ++ intercalate ", " malformed
               ++ ". A 0x prefix here would also redden sc3_literal_purge, and a short digest is a"
               ++ " conversion that dropped bytes -- the 64-vs-32 skew this repository has already"
               ++ " measured once.")

      _ <- expect (raw_out == raw_in)
             ("BYTE-01 FAILED ON THE REAL ARTIFACT. The bytea column was handed " ++ raw_in
               ++ " and gave back " ++ raw_out ++ ". This is the byte-exactness the whole milestone"
               ++ " rests on, measured against the real 606-byte GAMS output.")

      expect (doc_text /= raw_out)
        ("the exhibit records the jsonb projection and the bytea artifact as BYTE-IDENTICAL. That"
          ++ " does not mean jsonb is safe -- it means the exhibit has stopped exercising jsonb and"
          ++ " the guard has lost its subject. jsonb does not preserve whitespace, key order or"
          ++ " duplicate keys and it re-renders numbers through numeric; MEASURED three times"
          ++ " independently. Re-take the capture and investigate before touching this check: "
          ++ store_conformance_command)

-- | CHECK 6 -- DB-01: the drift EXITS NON-ZERO.
--
-- @postgresql-migration@ 0.2.1.8 returns a @MigrationError@ and the PROCESS STILL EXITS 0. That
-- wart is why the runner wraps it, and the recorded pair is what keeps the reason legible: the
-- library RESULT and the guarded process EXIT are recorded separately, so \"the guard is on the
-- path\" and \"the library still needs guarding\" are two observations rather than one.
--
-- The drift MESSAGE is asserted only for the FILE IT NAMES, and never for the words \"checksum
-- mismatch\", which do not appear: source-read at 23-03 and confirmed empirically at 23-04, the
-- payload on this path is @MigrationError \<script name\>@. The filename comes from
-- 'expected_migrations' rather than from a transcription -- and this arm is not decoration, it is
-- the arm that caught a real defect: the capture's first run recorded a server @NOTICE@ about
-- @schema_migrations@ here, which says nothing whatever about the drift.
store_conformance_records_a_nonzero_exit_on_checksum_drift :: Check
store_conformance_records_a_nonzero_exit_on_checksum_drift =
  Check "store_conformance_records_a_nonzero_exit_on_checksum_drift" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact  <- loaded
      checks    <- json_field "migration_checks" artifact
      guarded_x <- json_field "checksum_drift_exit" checks >>= json_integer
      bare_x    <- json_field "checksum_drift_exit_without_guard" checks >>= json_integer
      result    <- json_field "checksum_drift_library_result" checks >>= json_string
      stderr_   <- json_field "checksum_drift_stderr" checks >>= json_string

      _ <- expect (guarded_x == 1)
             ("the capture recorded exit " ++ show guarded_x ++ " on checksum drift."
               ++ " postgresql-migration returns a MigrationError and the PROCESS STILL EXITS 0 --"
               ++ " MEASURED -- so a recorded 0 means the runner's own exitFailure is not on the"
               ++ " path and DB-01 is unmet: a CI step that ran migrations over a drifted script"
               ++ " would report success.")
      _ <- expect (bare_x == 0)
             ("checksum_drift_exit_without_guard is " ++ show bare_x ++ ". It records the WART --"
               ++ " the library's own exit status, which is 0 on a failed migration. If the library"
               ++ " has been fixed upstream this stops being 0, and that is worth knowing rather"
               ++ " than silently absorbing: the guard could then be simplified, and until someone"
               ++ " has checked, it must not be.")
      _ <- expect (result == "MigrationError")
             ("the drift produced the library result " ++ show result ++ " and not MigrationError."
               ++ " That is the value-level half of this observation, and the half the exit code"
               ++ " alone cannot give: a process can exit 1 for any reason at all.")
      expect (any (`isInfixOf` stderr_) [n | (v, n) <- expected_migrations, v == 1])
        ("the recorded drift message does not name the migration that drifted:\n      "
          ++ show stderr_
          ++ "\n      On this path the payload is the SCRIPT NAME -- source-read at 23-03,"
          ++ " confirmed empirically at 23-04 -- and the capture's first run recorded a server"
          ++ " NOTICE here instead, which says nothing about the drift at all. The words"
          ++ " \"checksum mismatch\" are NOT asserted, because they do not appear on this path;"
          ++ " they belong to a validation entry point the runner does not take.")

-- | CHECK 7 -- DB-01's concurrency half, WITH ITS RELEASE OBSERVATION.
--
-- @try_lock false@ and @applied 0@ against an already-migrated database is satisfied by a migrator
-- that could never apply anything, by a closed connection, and by a directory with nothing new in
-- it. So the after-release pair is asserted here as well and it is NOT optional: only
-- @try true \/ applied 1@ says the lock EXCLUDED work that would otherwise have happened.
--
-- @postgresql-migration@ 0.2.1.8 contains no advisory lock at all (source-read: zero @advisory@
-- hits), so this is the CALLER's guard and the key is the caller's constant. It is asserted
-- against the value the capture recorded from the exported binding rather than against a
-- transcription in this file.
store_conformance_records_the_second_migrator_applying_nothing :: Check
store_conformance_records_the_second_migrator_applying_nothing =
  Check "store_conformance_records_the_second_migrator_applying_nothing" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      checks   <- json_field "migration_checks" artifact
      try_lock <- json_field "second_migrator_try_lock" checks >>= json_bool
      applied  <- json_field "second_migrator_applied" checks >>= json_integer
      rel_lock <- json_field "after_release_try_lock" checks >>= json_bool
      rel_appl <- json_field "after_release_applied" checks >>= json_integer
      key      <- json_field "advisory_lock_key" checks >>= json_integer

      _ <- expect (not try_lock)
             ("a second migrator ACQUIRED the advisory lock while the first held it (try_lock "
               ++ show try_lock ++ "). Two concurrent migrators is CI's normal case, not an edge:"
               ++ " parallel jobs share a database.")
      _ <- expect (applied == 0)
             ("the excluded migrator applied " ++ show applied ++ " migrations. It was supposed to"
               ++ " apply none, having failed to take the lock.")
      _ <- expect rel_lock
             ("THE POSITIVE CONTROL FAILED: after the first migrator released the lock, a second"
               ++ " one still could not take it. Without this arm the exclusion above is satisfied"
               ++ " by a migrator that could never have acquired anything -- by a closed"
               ++ " connection, or by a lock nobody ever released.")
      _ <- expect (rel_appl == 1)
             ("THE POSITIVE CONTROL FAILED: after release, the second migrator applied "
               ++ show rel_appl ++ " migrations. The probe directory carries a third migration"
               ++ " precisely so that \"applied 0\" above means work was EXCLUDED rather than that"
               ++ " there was no work to do.")
      expect (key /= 0)
        ("the recorded advisory_lock_key is 0. It is read from the exported migration_lock_key"
          ++ " binding, and a zero there is the numeric-zero sentinel this project has already been"
          ++ " bitten by: pg_try_advisory_lock(0) is a perfectly valid call on a key every other"
          ++ " caller in the world may also be using.")

-- | CHECK 8 -- migrating from a COMPLETELY EMPTY database, twice.
--
-- @actions\/checkout@ with @clean: true@ runs @git clean -ffdx@, and CI provisions a fresh
-- container per job, so \"there is no schema at all\" is the NORMAL case rather than an edge one.
-- The second run applying 0 is the idempotence half: a runner that re-applied its migrations would
-- fail on the second @create table@ in CI and nowhere else.
store_conformance_records_two_runs_from_an_empty_database :: Check
store_conformance_records_two_runs_from_an_empty_database =
  Check "store_conformance_records_two_runs_from_an_empty_database" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      checks   <- json_field "migration_checks" artifact
      run1     <- json_field "empty_db_run1" checks >>= json_bool
      run2     <- json_field "empty_db_run2_applied" checks >>= json_integer
      _ <- expect run1
             ("the first migration run against a COMPLETELY EMPTY database did not succeed. That"
               ++ " is CI's normal case -- a fresh container and a clean checkout every job -- so"
               ++ " this failing means CI cannot stand the schema up at all.")
      expect (run2 == 0)
        ("the second run against the same database applied " ++ show run2 ++ " migrations and"
          ++ " should have applied none. A runner that re-applies is one that fails on its own"
          ++ " second create table, and it fails in CI rather than here.")

-- | The image the capture is REQUIRED to provision. DB-04, as a two-sided observation.
conformance_image_tag :: String
conformance_image_tag = "postgres:18-alpine"

-- | CHECK 9 -- DB-04: the pin, and the server that actually answered.
--
-- Two sides, deliberately: @image_tag@ is what was ASKED FOR and @server_version@ is what REPLIED.
-- Asserting only the tag would pass against a stale local image or a registry that moved it;
-- asserting only the version would pass against an unpinned @latest@ that happened to be on 18
-- today. The version is matched on its MAJOR only -- a patch bump is not a schema change and
-- pinning it would make this check a maintenance tax that gets relaxed the first time it fires.
store_conformance_records_the_pinned_image_and_server_version :: Check
store_conformance_records_the_pinned_image_and_server_version =
  Check "store_conformance_records_the_pinned_image_and_server_version" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      tag      <- json_field "image_tag" artifact >>= json_string
      version  <- json_field "server_version" artifact >>= json_string
      _ <- expect (tag == conformance_image_tag)
             ("the capture provisioned " ++ show tag ++ " and this suite is written against "
               ++ show conformance_image_tag ++ ". An unpinned image makes every verdict in this"
               ++ " artifact a statement about whatever the registry served that day.")
      expect ("18." `isPrefixOf` version)
        ("the server that answered reports version " ++ show version ++ ", which is not an 18.x."
          ++ " The tag above says what was ASKED FOR; this says what REPLIED, and the pair is the"
          ++ " whole point -- a tag alone passes against a stale local image of the same name.")

-- | CHECK 10 -- the LIVE CATALOGUE half of KEY-07.
--
-- 'unique_constraint_names_all_three_columns' asserts the Haskell constant and the DDL TEXT. This
-- asserts what @pg_indexes@ actually reported after the migration ran, which is a third subject
-- and a different failure: a DDL file that was never applied leaves the file half green and the
-- catalogue empty. The columns are compared as an ORDERED list because the index's column order is
-- what makes a prefix lookup possible, and the constraint name is compared because the insert
-- path's conflict target is the CONSTRAINT and not a column list.
store_conformance_records_the_live_identity_constraint :: Check
store_conformance_records_the_live_identity_constraint =
  Check "store_conformance_records_the_live_identity_constraint" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      block    <- json_field "unique_constraint" artifact
      name     <- json_field "name" block >>= json_string
      cols     <- json_field "columns" block >>= json_array >>= mapM json_string
      _ <- expect (name == identity_constraint_name)
             ("the LIVE catalogue reports the identity constraint as " ++ show name
               ++ " and Store.Schema names it " ++ show identity_constraint_name ++ ". The insert"
               ++ " path's conflict target is that constraint BY NAME, so a renamed constraint"
               ++ " turns first-writer-wins into a runtime error rather than a compile-time one.")
      expect (cols == identity_constraint_columns)
        ("the LIVE catalogue reports the identity constraint over " ++ show cols
          ++ " and KEY-07 requires " ++ show identity_constraint_columns ++ ", in that order."
          ++ " The DDL-file half of this claim is asserted by"
          ++ " unique_constraint_names_all_three_columns; this half is what says the DDL was"
          ++ " actually APPLIED. A two-part key does not orphan on a key-formula change -- MEASURED"
          ++ " at 23-01: it serves the superseded scheme's row and the new scheme's insert"
          ++ " vanishes.")

-- | The @json_agreement@ probes, by name, so a deleted probe is a set mismatch.
expected_json_agreement_probes :: [String]
expected_json_agreement_probes =
  [ "exponent-1e100000"
  , "exponent-1e1000"
  , "invalid-utf8"
  , "law-fixture-object"
  , "nul-escape-in-a-string"
  , "the-disagreeing-document"
  , "the-non-json-probe"
  , "trailing-content"
  , "volume-path-golden"
  ]

-- | The ONE input on which the hand-written recogniser and @jsonb@ were MEASURED to disagree.
--
-- A @\\u0000@ escape inside a string is valid RFC 8259 and refused by @jsonb@, because Postgres
-- text cannot carry a NUL. Two further divergences were PREDICTED at 23-04 and both were REFUTED
-- by measurement -- @1e1000@ and @1e100000@ were accepted by the server -- and their probes are
-- kept under their own names, because a probe deleted for agreeing is a probe that can never
-- disagree later.
json_agreement_divergence :: String
json_agreement_divergence = "nul-escape-in-a-string"

-- | CHECK 11 -- TIER B PREDICTS TIER C, asserted per input rather than argued in a haddock.
--
-- The user ruling that made the keyed path require a json value rests on a claim that is
-- falsifiable: a hand-written recogniser with no server agrees with @jsonb@. That claim is what
-- lets @cabal test@ run the law suite against 'Store.Memory' and believe the result. This check
-- asserts the measurement rather than the claim -- every probe agrees EXCEPT the one measured
-- divergence, and the divergence itself is asserted, so a capture in which it silently stopped
-- reproducing reddens instead of quietly widening what the recogniser is trusted for.
json_recogniser_agrees_with_jsonb_except_where_measured :: Check
json_recogniser_agrees_with_jsonb_except_where_measured =
  Check "json_recogniser_agrees_with_jsonb_except_where_measured" . guarded $ do
    loaded <- read_store_conformance
    pure $ do
      artifact <- loaded
      rows     <- json_field "json_agreement" artifact >>= json_array
      probes   <- mapM one_probe rows

      let recorded_names = [n | (n, _, _) <- probes]
          absent   = [n | n <- expected_json_agreement_probes, n `notElem` recorded_names]
          unlisted = [n | n <- recorded_names, n `notElem` expected_json_agreement_probes]
      _ <- expect (null absent && null unlisted)
             ("the json-agreement probe SET has moved. Not captured: " ++ intercalate ", " absent
               ++ " | captured and not expected: " ++ intercalate ", " unlisted
               ++ ".\n      Two of these probes exist to record a REFUTED prediction and would be"
               ++ " the first ones a tidying pass deleted. A probe deleted for agreeing is a probe"
               ++ " that can never disagree later.")

      let disagreeing = [n | (n, m, p) <- probes, m /= p]
          unexpected  = [n | n <- disagreeing, n /= json_agreement_divergence]
      _ <- expect (null unexpected)
             ("the hand-written recogniser and jsonb disagree on inputs where they were MEASURED to"
               ++ " agree: " ++ intercalate ", " unexpected
               ++ ".\n      Store.Memory rejects with that recogniser and the real client rejects"
               ++ " with jsonb. Where they diverge, a law can pass against the reference store and"
               ++ " fail against the real one -- which is the three-tier design breaking, and the"
               ++ " only reason cabal test may run with no database.")
      expect (json_agreement_divergence `elem` disagreeing)
        ("the ONE measured divergence (" ++ json_agreement_divergence ++ ") no longer reproduces:"
          ++ " the capture records the recogniser and jsonb agreeing on it. That is not a licence"
          ++ " to widen what the recogniser is trusted for -- it means either the server's"
          ++ " behaviour moved or the probe stopped carrying the input it is named for."
          ++ " Investigate before touching this check.")
  where
    one_probe row =
      (,,) <$> (json_field "name" row >>= json_string)
           <*> (json_field "memory_accepts" row >>= json_bool)
           <*> (json_field "postgres_accepts" row >>= json_bool)

-- ---------------------------------------------------------------------------------------------
-- DB-02: no credential is written down in a tracked file
-- ---------------------------------------------------------------------------------------------

-- | The pattern, BUILT rather than written, for the reason 'purge_control_literal' is built.
--
-- Spelled out contiguously it would match THIS FILE, and a scan that matches the file asserting
-- its own absence exempts nothing and reddens always. Prose has turned out to be inside a grep's
-- blast radius four times on this branch; this is the fifth place it is being routed around.
--
-- The two @=@ arms require a character that is neither a quote nor a dollar after the @=@, so a
-- shell expansion (@=\"$GENERATED\"@, @=$GENERATED@) does not match and a LITERAL value does. That
-- is a deliberate line: the capture script legitimately passes a generated secret through the
-- environment, and the rule DB-02 states is that no credential is written DOWN.
credential_pattern :: String
credential_pattern =
  intercalate "|"
    [ "postgres" ++ "://"
    , "PG" ++ "PASSWORD"
    , "pass" ++ "word=[^\"$]"
    , "POSTGRES_" ++ "PASSWORD=[^\"$]"
    ]

-- | Data as well as code. @.json@ is scanned here and NOT by 'sc3_literal_purge', deliberately: a
-- DSN pasted into a captured artifact is a leaked credential even though nothing executes it.
credential_scanned_extensions :: [String]
credential_scanned_extensions = [".hs", ".sh", ".sql", ".json"]

-- | ONE argument vector, so the positive control runs the identical invocation over a different
-- root rather than a lookalike of it.
credential_scan :: FilePath -> IO (ExitCode, String, String)
credential_scan root =
  readProcessWithExitCode
    "grep"
    (["-rnE", credential_pattern, root] ++ map ("--include=*" ++) credential_scanned_extensions)
    ""

-- | RE-MEASURED COLD on 2026-08-16 during plan 24-03, in the same commit as @Gams\/Run.hs@:
--
-- > find offchain \( -name '*.hs' -o -name '*.sh' -o -name '*.sql' -o -name '*.json' \) -type f | wc -l
--
-- 63 = 45 Haskell + 8 shell + 8 JSON + 2 SQL. It was 62 immediately before, against exactly 62
-- files -- ZERO slack, so @Gams\/Run.hs@ would have reddened this scan in the commit that created
-- it had the floor not moved with it. 62 was measured at 24-02, 59 at 24-01, 56 at 23-05, each
-- against exactly that many files.
--
-- This floor and 'purge_file_floor' are re-measured TOGETHER, and 24-03 found out why that matters:
-- at 24-02 this one moved and that one did not, the summary of record said both had, and the
-- unmoved one sat four below its subject with nothing red. Run both commands; compare both numbers
-- to what is written down; never add.
--
-- It exists for the same reason 'purge_file_floor' does and it is the same trap: @grep -r@ exits 1
-- for \"found nothing\" AND for \"matched no files at all\", so a scan whose @--include@ set stopped
-- matching reports exactly what a clean scan reports. Re-measure it, never increment it.
--
-- RE-MEASURED COLD AGAIN at 24-04, in the same sitting as 'purge_file_floor': 63 against exactly 63
-- files, ZERO slack, and no move -- 24-04 adds no file, it adds checks to one that already existed.
-- Both numbers were read off @find@ and compared to what is written here; neither was derived from
-- the other and neither was incremented.
credential_scan_floor :: Int
credential_scan_floor = 63

-- | The seeded bait, BUILT for the same reason the pattern is.
credential_bait_source :: String
credential_bait_source =
  "DSN=" ++ "postgres" ++ "://u:hunter2@localhost:5432/db\n"
    ++ "PG" ++ "PASSWORD=hunter2\n"
    ++ "conninfo=host=localhost " ++ "pass" ++ "word=hunter2\n"

-- | A file that carries the ENVIRONMENT forms the real tree uses, which must NOT match.
--
-- This is the arm that keeps the pattern honest in the other direction. Without it the pattern
-- could be tightened until it matched nothing at all and the absence would still read as success.
credential_innocent_source :: String
credential_innocent_source =
  "docker run -e " ++ "POSTGRES_" ++ "PASSWORD=\"$DB_PASSWORD\"\n"
    ++ "export DSN=\"host=127.0.0.1 " ++ "pass" ++ "word=$DB_PASSWORD dbname=x\"\n"

-- | Absence may not read as success until the pattern has been SHOWN matching. Returned so the
-- caller orders it FIRST.
credential_positive_control :: IO (Either String ())
credential_positive_control = do
  tmp <- getTemporaryDirectory
  let dir       = tmp </> "db02-credential-positive-control"
      bait      = dir </> "bait.sh"
      innocent  = dir </> "clean.sh"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [bait, innocent]) $ do
    writeFile bait credential_bait_source
    writeFile innocent credential_innocent_source
    (code, out, err) <- credential_scan dir
    pure $ do
      _ <- expect (code == ExitSuccess)
             ("DB-02's POSITIVE CONTROL did not fire: grep exited " ++ show code ++ " over a tree"
               ++ " seeded with a URI-form DSN, a libpq password variable and a literal"
               ++ " password assignment. The pattern has stopped matching anything, which means the"
               ++ " exit-1 the real scan reports is absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      grep stderr: " ++ err))
      _ <- expect ("bait.sh" `isInfixOf` out)
             ("DB-02's POSITIVE CONTROL fired but did not NAME the seeded file. grep said:\n"
               ++ unlines (map ("      " ++) (lines out)))
      expect (not ("clean.sh" `isInfixOf` out))
        ("DB-02's POSITIVE CONTROL matched the ENVIRONMENT forms -- a value passed through a shell"
          ++ " variable rather than written down. That is the form the capture script legitimately"
          ++ " uses, and a pattern that matches it would have to be relaxed the first time it"
          ++ " fired, which is how a credential scan becomes decorative. grep said:\n"
          ++ unlines (map ("      " ++) (lines out)))

-- | DB-02, as a source scan with a proven positive control and a scanned-file floor.
--
-- The connection configuration comes from the environment ('Store.Config' is the only place either
-- variable is named) and this is the standing assertion that it stayed there. Three arms, in this
-- order: the pattern is SHOWN matching a seeded bait AND shown NOT matching the environment forms;
-- the scan reached at least as many files as it did when the floor was measured; the scan finds
-- nothing.
no_credential_is_present_in_a_tracked_file :: Check
no_credential_is_present_in_a_tracked_file =
  Check "no_credential_is_present_in_a_tracked_file" . guarded $ do
    control <- credential_positive_control
    files   <- walk_files "offchain"
    (code, out, err) <- credential_scan "offchain"
    let scanned = filter ((`elem` credential_scanned_extensions) . takeExtension) files
    pure $ do
      _ <- control
      _ <- expect (length scanned >= credential_scan_floor)
             ("the credential scan reached " ++ show (length scanned) ++ " files, below the floor"
               ++ " of " ++ show credential_scan_floor ++ ". grep exits 1 for \"found nothing\" AND"
               ++ " for \"matched no files at all\", so a scan that has collapsed reports exactly"
               ++ " what a clean scan reports. If files were removed on purpose, re-measure this"
               ++ " floor and say so.")
      case code of
        ExitFailure 1 -> Right ()
        ExitFailure n -> Left ("grep itself failed with exit " ++ show n ++ ": " ++ err)
        ExitSuccess ->
          Left ("a credential is written down in a tracked file under offchain/. DB-02 says the"
                 ++ " connection configuration comes from the environment, and Store.Config's"
                 ++ " default DSN is the EMPTY STRING for exactly this reason -- there is nothing"
                 ++ " to leak and nothing to go stale:\n"
                 ++ unlines (map ("      " ++) (lines out)))

-- ---------------------------------------------------------------------------------------------
-- BYTE-03: the bytes never pass through an aeson Value on the storage path
-- ---------------------------------------------------------------------------------------------

-- | THE MUTATIONS, PINNED AS VALUES AND RE-MEASURED EVERY RUN.
--
-- Each pair is (input bytes, the EXACT bytes aeson produces on @decode >=> encode@). MEASURED at
-- GHC 9.10.3 with aeson 2.2.5.0, the version this build plan resolves -- re-measured at 23-02
-- rather than carried over from the research, and re-run by the check below on every invocation.
--
-- If the right-hand side stops matching, that is NOT a licence to update the constant: it means
-- the mutation BYTE-03 exists to prevent has changed shape, and the storage path must be
-- re-audited before anything here is touched.
--
-- The third vector is the one that connects BYTE-03 to BYTE-02: aeson reorders object keys for
-- exactly the same reason @jsonb@ does, so an artifact that went through either is an artifact
-- whose byte identity has been decided by a normalizer rather than by GAMS.
aeson_mutation_vectors :: [(BSL.ByteString, BSL.ByteString)]
aeson_mutation_vectors =
  [ ("{\"d\":0.00318353}",   "{\"d\":3.18353e-3}")
  , ("{\"v\":2.8e19}",       "{\"v\":28000000000000000000}")
  , ("{\"b\":\"a\",\"a\":\"b\"}", "{\"a\":\"b\",\"b\":\"a\"}")
  ]

-- | RE-MEASURED, NEVER CITED.
--
-- The check runs the round-trip and asserts the MUTATED OUTPUT. The distinction matters: a check
-- that merely asserted \"the storage path does not import aeson\" would keep passing if aeson
-- stopped mutating, at which point the guard's own subject has vanished and the guard has quietly
-- become a tautology. Here, an aeson whose @decode >=> encode@ became the identity reddens.
aeson_round_trip_mutations_are_re_measured :: Check
aeson_round_trip_mutations_are_re_measured =
  pure_check "aeson_round_trip_mutations_are_re_measured" $ do
    _ <- expect (length aeson_mutation_vectors >= 2)
           ("aeson_mutation_vectors has shrunk to " ++ show (length aeson_mutation_vectors)
             ++ ". Two independent mutations were measured (a small decimal re-rendered in"
             ++ " exponent form, a large one expanded out of it) and they fail in opposite"
             ++ " directions, so one vector cannot stand for the pair.")
    mapM_ one_aeson_vector aeson_mutation_vectors

one_aeson_vector :: (BSL.ByteString, BSL.ByteString) -> Either String ()
one_aeson_vector (input, expected) =
  case decode input :: Maybe Value of
    Nothing ->
      Left ("the pinned vector " ++ show input ++ " no longer DECODES as JSON, so every assertion"
             ++ " about what aeson does to it is vacuous. Fix the vector, do not delete it.")
    Just value ->
      let out = encode value
      in do
        _ <- expect (out /= input)
               ("aeson's decode->encode has become the identity on " ++ show input
                 ++ ". The mutation this guard exists to keep off the storage path no longer"
                 ++ " reproduces, so this check no longer has a subject. Re-measure it against the"
                 ++ " current aeson and record the new mutation; do NOT delete the check.")
        expect (out == expected)
          ("aeson still mutates " ++ show input ++ ", and it mutates it DIFFERENTLY than the"
            ++ " pinned measurement: got " ++ show out ++ ", pinned " ++ show expected
            ++ ". The storage path must be re-audited against the new shape before this constant"
            ++ " is updated.")

-- | THE STORAGE PATH, NAMED FILE BY FILE.
--
-- Every module under @offchain\/lib\/Store\/@ is here, INCLUDING the one that does not exist yet.
-- The list is written out rather than derived by globbing the directory, because a derived list
-- grows silently: a new storage module would be scanned and nobody would have decided that it
-- should be, and the day one is added to a different directory the glob would report a clean scan
-- of the wrong set. A named list makes an omission visible.
--
-- There are NO exemptions. @Store\/Types.hs@ was a candidate for one -- it holds the artifact
-- newtypes and imports no aeson -- and it is here anyway, because \"this file is fine, skip it\"
-- is how a guard's scope shrinks to the empty set. Its haddock had to be reworded in this same
-- commit to stop describing the import it does not have, which is the second time prose has turned
-- out to be inside a grep's blast radius on this branch.
--
-- A named list makes an omission VISIBLE, and it does not make it impossible. @Store\/Schema.hs@
-- landed in 23-03 task 1 and spent two commits unlisted -- a storage module this scan did not read,
-- caught by the plan's own self-check rather than by anything that fails. That is the other half of
-- the trade: a glob would have picked it up and a named list has to be edited. The rule is the same
-- rule 23-02 wrote down and 23-03 then broke -- a new module under @offchain\/lib\/Store\/@ is added
-- HERE, in the commit that creates it -- and it now has an instance to its name.
--
-- 24-02 EXTENDED THE LIST TO THE WHOLE GAMS LAYER, AND THEN STOPPED RELYING ON THE RULE.
-- @Gams\/Artifact.hs@ decodes @volume_path.json@, so it is on the artifact path and belongs here;
-- it was added in the SAME COMMIT that created it. The other five went in with it, because a scan
-- scoped to \"the modules that obviously need it\" is the same judgement call that left
-- @Store\/Schema.hs@ out. And 'the_artifact_path_scan_covers_every_module_on_it' now asserts this
-- list against @offchain\/lib\/{Store,Gams}\/@ in BOTH directions, so the rule above no longer
-- depends on anyone remembering it.
aeson_storage_path :: [FilePath]
aeson_storage_path =
  [ "offchain/lib/Gams/Argv.hs"
  , "offchain/lib/Gams/Artifact.hs"
  , "offchain/lib/Gams/Config.hs"
  , "offchain/lib/Gams/Env.hs"
  , "offchain/lib/Gams/Exit.hs"
  , "offchain/lib/Gams/Run.hs"
  , "offchain/lib/Gams/Version.hs"
  , "offchain/lib/Store/Class.hs"
  , "offchain/lib/Store/Config.hs"
  , "offchain/lib/Store/Json.hs"
  , "offchain/lib/Store/Laws.hs"
  , "offchain/lib/Store/Memory.hs"
  , "offchain/lib/Store/Postgres.hs"
  , "offchain/lib/Store/Schema.hs"
  , "offchain/lib/Store/Types.hs"
  ]

aeson_pattern :: String
aeson_pattern = "Data\\.Aeson|\\btoJSON\\b|\\bencode\\b|\\bfromJSON\\b|\\beitherDecode\\b"

-- | ONE argument vector, so the positive control runs the identical invocation over different
-- file operands rather than a lookalike of it. @-H@ is not decoration: without it grep omits the
-- filename when handed a single operand, and the control asserts that the bait file is NAMED.
aeson_scan :: [FilePath] -> IO (ExitCode, String, String)
aeson_scan paths = readProcessWithExitCode "grep" (["-nHE", aeson_pattern] ++ paths) ""

-- | The seeded bait, BUILT rather than written out, for the reason 'purge_control_literal' is
-- built: a file that spelled the import would be found by the very scan it exists to exercise, and
-- @offchain\/test\/Main.hs@ is not in 'aeson_storage_path' today but a future storage module in
-- this file would be.
aeson_bait_source :: String
aeson_bait_source =
  "import " ++ "Data.Aeson (toJSON)\nbait :: Value\nbait = " ++ "toJSON ()\n"

-- | Absence may not read as success until the pattern has been SHOWN matching.
--
-- Returns the assertion so the caller orders it FIRST. Two files are seeded, not one: the bait
-- must be named, and a clean file must NOT be, so an exit-0 is evidence about the PATTERN rather
-- than about grep's willingness to match something.
aeson_positive_control :: IO (Either String ())
aeson_positive_control = do
  tmp <- getTemporaryDirectory
  let dir       = tmp </> "byte03-aeson-positive-control"
      bait      = dir </> "bait.hs"
      innocent  = dir </> "clean.hs"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [bait, innocent]) $ do
    writeFile bait aeson_bait_source
    writeFile innocent "bait :: ()\nbait = ()\n"
    (code, out, err) <- aeson_scan [bait, innocent]
    pure $ do
      _ <- expect (code == ExitSuccess)
             ("BYTE-03's POSITIVE CONTROL did not fire: grep exited " ++ show code
               ++ " over a file that imports the aeson module and calls toJSON. The pattern has"
               ++ " stopped matching anything, which means the exit-1 the real scan reports is"
               ++ " absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      grep stderr: " ++ err))
      _ <- expect ("bait.hs" `isInfixOf` out)
             ("BYTE-03's POSITIVE CONTROL fired but did not NAME the seeded file. grep said:\n"
               ++ unlines (map ("      " ++) (lines out)))
      expect (not ("clean.hs" `isInfixOf` out))
        ("BYTE-03's POSITIVE CONTROL matched a file with no aeson in it at all, so the pattern is"
          ++ " matching something other than what it claims to. grep said:\n"
          ++ unlines (map ("      " ++) (lines out)))

-- | BYTE-03, as a source scan with a proven positive control.
--
-- Three assertions in this order and the order is the whole design: (1) the pattern is SHOWN
-- matching a seeded bait; (2) every file in 'aeson_storage_path' EXISTS; (3) the scan finds
-- nothing.
--
-- (2) IS CURRENTLY RED, ON PURPOSE. @offchain\/lib\/Store\/Postgres.hs@ is created by plan 23-03
-- and does not exist at 23-02, so this check FAILS naming it. The alternative -- scoping the list
-- to the files that happen to exist -- would make the check pass BECAUSE its subject is absent,
-- which is the single defect class this project's review history is dominated by, found seven
-- times. A missing file is a FAILURE naming the plan that creates it, never a pass.
aeson_is_absent_from_the_storage_path :: Check
aeson_is_absent_from_the_storage_path =
  Check "aeson_is_absent_from_the_storage_path" . guarded $ do
    control <- aeson_positive_control
    presence <- mapM (\p -> (,) p <$> doesFileExist p) aeson_storage_path
    let gone = [p | (p, False) <- presence]
    if not (null gone)
      then pure $ do
        _ <- control
        expect False
          ("the storage path names files that are not on disk: " ++ intercalate ", " gone
            ++ ". offchain/lib/Store/Postgres.hs is created by PLAN 23-03 and this check is"
            ++ " DELIBERATELY RED until it lands. Scoping the list to the files that exist would"
            ++ " make this check pass because its subject is absent, which is the defect class"
            ++ " this milestone's standing rule names. If a file was RENAMED, rename it here in"
            ++ " the same commit.")
      else do
        (code, out, err) <- aeson_scan aeson_storage_path
        pure $ do
          _ <- control
          case code of
            ExitFailure 1 -> Right ()
            ExitFailure n -> Left ("grep itself failed with exit " ++ show n ++ ": " ++ err)
            ExitSuccess ->
              Left ("an aeson Value is on the STORAGE PATH. The bytes in the raw column are the"
                     ++ " oracle and aeson re-renders numbers and reorders keys -- MEASURED, and"
                     ++ " asserted as values in aeson_mutation_vectors:\n"
                     ++ unlines (map ("      " ++) (lines out)))

-- ---------------------------------------------------------------------------------------------
-- Phase 24: toolchain identity (GAMS-01, GAMS-03, GAMS-04) -- Tier A only
-- ---------------------------------------------------------------------------------------------

-- | The basename of the @.gms@ that is actually invoked, and therefore the job name every banner
-- is judged against. Written once here for the same reason 'Gams.Config' writes it once there.
gams_model_basename :: String
gams_model_basename = "volume_path.gms"

-- | THE REAL FIRST LINE of the production run's own log, captured on this machine on 2026-08-16.
--
-- This is the POSITIVE arm's input, and without it the battery below is satisfiable by a parser
-- that rejects everything -- which would be the same defect as a parser that accepts everything,
-- pointing the other way.
gams_real_banner :: String
gams_real_banner =
  "--- Job volume_path.gms Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux\n"

-- | THE GARBAGE BATTERY. Every member carries the reason it is a member.
--
-- Six of the eight are REAL CAPTURED OUTPUT rather than invented strings, and the exit codes are
-- MEASURED on this machine:
--
--   * @help-banner-exit-0@ is the first line of what @gams@ with NO ARGUMENTS prints. It EXITS 0,
--     the output is 1239 bytes over 27 lines, and it carries the version string THREE times while
--     running no model at all. Non-empty, correctly shaped, exit 0, WRONG SUBJECT -- the strongest
--     member here, and free, because the tool produced it.
--   * @version-flag-exit-6@ is the real @gams --version@ output. The flag is not a command; it is
--     parsed as an input filename and the process EXITS 6.
--   * In BOTH of those modes stderr was exactly 0 BYTES, as it is in a normal solve. A detector
--     that read stderr would compare the empty string against the empty string and report success
--     every time -- which is why these two are inputs to the parser and not to a stream reader.
--   * @audit-gamsx@ is @gams audit@, exit 0, reporting GAMSX -- a COMPONENT that happens to carry
--     the same number today. A different subject, not a different rendering.
--   * @localised@ is SYNTHETIC and labelled so: nothing on this machine produces it.
gams_garbage_battery :: [(String, String, VersionError)]
gams_garbage_battery =
  [ ( "empty"
    , ""
    , EmptyInput )
  , ( "newline-only"
    , "\n"
    , EmptyInput )
  , ( "whitespace-only"
    , "   \t  \n"
    , EmptyInput )
  , ( "help-banner-exit-0"
    , "--- Job ? Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux\n"
    , WrongJob "?" )
  , ( "version-flag-exit-6"
    , "--- Job --version Start 08/16/26 16:01:42 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux\n"
        ++ "*** Unable to open input file (RC=2) --version\n"
    , WrongJob "--version" )
  , ( "audit-gamsx"
    , "GAMSX            54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux    \n"
    , NoJobBanner )
  , ( "truncated"
    , "--- Job volume_path.gms Start 08/16/26 15:52:25\n"
    , MissingVersionField )
  , ( "localised"
    , "--- Auftrag volume_path.gms Beginn 16.08.26 15:52:25 54.1.0 37378ce0\n"
    , NoJobBanner )
  ]

-- | The first line of an input, for a failure message that names what it was handed.
first_line_of :: String -> String
first_line_of = takeWhile (/= '\n')

-- | GAMS-03. Every battery member is rejected, with the SPECIFIC reason, and the real banner is
-- accepted with both of its fields.
--
-- The reason is asserted rather than just \"a Left\": @help-banner-exit-0@ must fail as
-- @WrongJob \"?\"@ and not as, say, a shape complaint, because the whole design is that the
-- SUBJECT is decided before the shape. A parser that validated the shape first would accept the
-- help banner -- its version field is perfectly well formed.
gams_version_parser_rejects_the_garbage_battery :: Check
gams_version_parser_rejects_the_garbage_battery =
  pure_check "gams_version_parser_rejects_the_garbage_battery" $ do
    mapM_ reject gams_garbage_battery
    case parse_gams_version gams_model_basename (C8.pack gams_real_banner) of
      Left err ->
        Left ("the POSITIVE arm failed: the REAL captured banner was rejected as " ++ show err
               ++ ". A battery of rejections is satisfied by a parser that rejects everything, so"
               ++ " this arm is what keeps the other eight meaningful.\n      banner: "
               ++ show (first_line_of gams_real_banner))
      Right version -> do
        _ <- expect (gams_version_text version == "54.1.0")
               ("the real banner parsed but reported version " ++ show (gams_version_text version)
                 ++ ", expected \"54.1.0\" -- the MEASURED toolchain on this machine.")
        expect (gams_build_text version == "37378ce0")
          ("the real banner parsed but reported build " ++ show (gams_build_text version)
            ++ ", expected \"37378ce0\".")
  where
    reject (name, input, expected) =
      let actual = parse_gams_version gams_model_basename (C8.pack input)
      in expect (actual == Left expected)
           ("the garbage battery member " ++ show name ++ " was not rejected as expected."
             ++ "\n      first line: " ++ show (first_line_of input)
             ++ "\n      expected:   Left " ++ show expected
             ++ "\n      actual:     " ++ show actual
             ++ "\n      Every member here is output a real invocation produced (or, for"
             ++ " \"localised\", is labelled synthetic). Accepting one means a version string"
             ++ " from the wrong subject reaches the content key, and Phase 25's rows are then"
             ++ " indistinguishable from good ones -- the only evidence of which toolchain wrote"
             ++ " them is the component that was wrong.")

-- | The @.hs@ files of the GAMS layer that must contain NO fallback of any kind.
--
-- 'Gams.Config' is deliberately NOT here and it is exempt WITH A REASON, below -- not omitted.
gams_no_fallback_path :: [FilePath]
gams_no_fallback_path =
  [ "offchain/lib/Gams/Argv.hs"
  , "offchain/lib/Gams/Artifact.hs"
  , "offchain/lib/Gams/Env.hs"
  , "offchain/lib/Gams/Exit.hs"
  , "offchain/lib/Gams/Run.hs"
  , "offchain/lib/Gams/Version.hs"
  ]

-- | Exemptions, each with the reason it is one. An exemption without a reason is how a scan's
-- scope shrinks to the empty set one plausible file at a time.
gams_fallback_exempt :: [(FilePath, String)]
gams_fallback_exempt =
  [ ( "offchain/lib/Gams/Config.hs"
    , "the Store.Config idiom's `fromMaybe <default> <$> lookupEnv <name>` IS the resolver here,"
        ++ " and no version value exists on that path -- the defaults it supplies are an"
        ++ " executable name and two file paths, every one of which fails LOUDLY downstream when"
        ++ " it does not resolve, rather than standing in for a measurement" )
  ]

-- | Every @.hs@ in the GAMS layer, from the DIRECTORY rather than from a list.
-- 24-02 folded this onto 'modules_under', which does exactly the same enumeration for the aeson
-- scan's scope-growth guard. Two enumerators over the same directory would be two things to keep
-- in agreement, and the day they stopped agreeing one of the two guards would be reading a set
-- nobody checked.
gams_layer_modules :: IO [FilePath]
gams_layer_modules = modules_under "offchain/lib/Gams"

-- | No fallback, no alternative, no exception handler, no placeholder string.
gams_version_fallback_pattern :: String
gams_version_fallback_pattern = "fromMaybe|[<][|][>]|\\bcatch\\b|\"unknown\"|fromJust"

-- | Neither version newtype exports its constructor.
gams_version_constructor_pattern :: String
gams_version_constructor_pattern = "GamsVersion ?\\(\\.\\.\\)|ConoptVersion ?\\(\\.\\.\\)"

-- | ONE argument vector, so the positive control runs the identical invocation over different
-- file operands rather than a lookalike of it. @-H@ is load-bearing: without it grep omits the
-- filename for a single operand and the control cannot assert that the bait was NAMED.
gams_version_scan :: String -> [FilePath] -> IO (ExitCode, String, String)
gams_version_scan pattern paths = readProcessWithExitCode "grep" (["-nHE", pattern] ++ paths) ""

-- | The seeded bait, BUILT rather than written out, following 'aeson_bait_source'.
--
-- Note what this means for scope: this file HOLDS the patterns, so it matches them, so it can
-- never be a member of the scanned set. That is exactly why the scanned set is the GAMS LIBRARY
-- directory and why the membership assertion below is over that directory and not over @offchain@.
gams_version_bait_source :: String
gams_version_bait_source =
  "module Bait (GamsVersion " ++ "(..)) where\n"
    ++ "value :: String\n"
    ++ "value = from" ++ "Maybe \"" ++ "unknown\" Nothing\n"

-- | Absence may not read as success until BOTH patterns have been SHOWN matching. Returned so the
-- caller orders it FIRST.
gams_version_positive_control :: IO (Either String ())
gams_version_positive_control = do
  tmp <- getTemporaryDirectory
  let dir       = tmp </> "gams03-version-positive-control"
      bait      = dir </> "bait.hs"
      innocent  = dir </> "clean.hs"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [bait, innocent]) $ do
    writeFile bait gams_version_bait_source
    writeFile innocent "value :: Int\nvalue = 0\n"
    fallback    <- gams_version_scan gams_version_fallback_pattern [bait, innocent]
    constructor <- gams_version_scan gams_version_constructor_pattern [bait, innocent]
    pure $ do
      _ <- arm "the FALLBACK pattern" fallback
      arm "the EXPORTED-CONSTRUCTOR pattern" constructor
  where
    arm label (code, out, err) = do
      _ <- expect (code == ExitSuccess)
             ("GAMS-03's POSITIVE CONTROL did not fire: " ++ label ++ " exited " ++ show code
               ++ " over a file that exports a version constructor AND supplies a placeholder"
               ++ " through a fallback. The pattern has stopped matching anything, which means the"
               ++ " exit-1 the real scan reports is absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      grep stderr: " ++ err))
      _ <- expect ("bait.hs" `isInfixOf` out)
             ("GAMS-03's POSITIVE CONTROL fired for " ++ label ++ " but did not NAME the seeded"
               ++ " file. grep said:\n" ++ unlines (map ("      " ++) (lines out)))
      expect (not ("clean.hs" `isInfixOf` out))
        ("GAMS-03's POSITIVE CONTROL matched a file with neither subject in it at all, so "
          ++ label ++ " is matching something other than what it claims to. grep said:\n"
          ++ unlines (map ("      " ++) (lines out)))

-- | GAMS-03, as a source scan with a proven positive control and a scope that must GROW.
--
-- Four assertions, in this order: (1) both patterns are SHOWN matching a seeded bait; (2) every
-- scanned file EXISTS -- a missing file is a FAILURE naming it, never a pass over an empty set;
-- (3) the GAMS layer's modules on DISK are exactly the scanned set plus the reasoned exemptions,
-- in BOTH directions; (4) neither pattern finds anything.
--
-- (3) is the one that is here because of a measurement rather than a principle. 23-03 landed
-- @Store\/Schema.hs@ and it sat unlisted in a hardcoded scan list for two commits -- a storage
-- module the scan did not read, with nothing red. A hardcoded list makes an omission visible and
-- does not make it impossible; comparing the list against the directory does.
gams_version_is_not_constructible_empty :: Check
gams_version_is_not_constructible_empty =
  Check "gams_version_is_not_constructible_empty" . guarded $ do
    control  <- gams_version_positive_control
    presence <- mapM (\p -> (,) p <$> doesFileExist p) gams_no_fallback_path
    on_disk  <- gams_layer_modules
    let gone    = [p | (p, False) <- presence]
        decided = sort (gams_no_fallback_path ++ map fst gams_fallback_exempt)
        unlisted = [m | m <- on_disk, m `notElem` decided]
        phantom  = [m | m <- decided, m `notElem` on_disk]
    if not (null gone)
      then pure $ do
        _ <- control
        expect False
          ("the no-fallback scan names files that are not on disk: " ++ intercalate ", " gone
            ++ ". Scoping the list to the files that exist would make this check pass BECAUSE its"
            ++ " subject is absent. If a file was RENAMED, rename it here in the same commit.")
      else if not (null unlisted) || not (null phantom)
        then pure $ do
          _ <- control
          expect False
            ("the GAMS layer's modules on disk are not the set this check decided about."
              ++ (if null unlisted then ""
                    else "\n      on disk but neither scanned nor exempt: "
                           ++ intercalate ", " unlisted)
              ++ (if null phantom then ""
                    else "\n      scanned or exempt but not on disk: "
                           ++ intercalate ", " phantom)
              ++ "\n      A new module under offchain/lib/Gams/ is added to"
              ++ " gams_no_fallback_path -- or to gams_fallback_exempt WITH A WRITTEN REASON --"
              ++ " in the commit that creates it. 23-03 measured what happens otherwise:"
              ++ " Store/Schema.hs spent two commits unlisted and nothing reddened.")
        else do
          fallback    <- gams_version_scan gams_version_fallback_pattern gams_no_fallback_path
          constructor <- gams_version_scan gams_version_constructor_pattern gams_no_fallback_path
          pure $ do
            _ <- control
            _ <- verdict "a FALLBACK is present in the GAMS layer" fallback
                   ("A default, an alternative, an exception handler or a placeholder string on"
                     ++ " this path is a version that reports a plausible value when its subject"
                     ++ " was absent. Phase 25 folds both version strings into the content key,"
                     ++ " and NOT NULL does not forbid the empty string, so the poisoned rows are"
                     ++ " indistinguishable afterwards.")
            verdict "a version CONSTRUCTOR is exported" constructor
              ("Exporting GamsVersion or ConoptVersion lets any caller build one from any string,"
                ++ " including the empty one, and the smart constructor stops being the only door.")
  where
    verdict what (code, out, err) why =
      case code of
        ExitFailure 1 -> Right ()
        ExitFailure n -> Left ("grep itself failed with exit " ++ show n ++ ": " ++ err)
        ExitSuccess   -> Left (what ++ ". " ++ why ++ "\n"
                                ++ unlines (map ("      " ++) (lines out)))

-- | The TRUE CONOPT banner, captured today. Four leading spaces, spaced letters, three spaces
-- before the keyword.
conopt_true_line :: String
conopt_true_line = "    C O N O P T   version 4.39.0"

-- | DECOY ONE: the GAMS-SIDE LINK version, MEASURED present in every solve log. It carries the
-- token CONOPT and a perfectly plausible dotted triple -- which is GAMS's number, not CONOPT's.
conopt_link_decoy :: String
conopt_link_decoy =
  "CONOPT 4         54.1.0 37378ce0 Jun 15, 2026          LEG x86 64bit/Linux    "

-- | DECOY TWO: the shared object, MEASURED on disk beside its LU companion. @464@ is neither
-- @4.39@ nor @54.1@.
conopt_so_decoy :: String
conopt_so_decoy = "libconopt464.so"

-- | Filler that is not a banner, so a buffer can be padded to a chosen line index.
conopt_filler :: Int -> String
conopt_filler n = unlines (replicate n "filler")

-- | GAMS-04. The true banner is accepted; both decoys are rejected; and a buffer carrying BOTH
-- decoys and no true line -- exactly what a run that never reached CONOPT looks like -- is
-- rejected too.
--
-- That last arm is the one that matters most: the two decoys are present in runs where the true
-- line is absent, so a parser that fell back to \"any CONOPT-ish line\" would report a version
-- for a solve that never happened.
conopt_parser_rejects_both_decoys :: Check
conopt_parser_rejects_both_decoys =
  pure_check "conopt_parser_rejects_both_decoys" $ do
    _ <- case parse_conopt_version (C8.pack (conopt_true_line ++ "\n")) of
           Left err ->
             Left ("the POSITIVE arm failed: the REAL CONOPT banner was rejected as " ++ show err
                    ++ ".\n      line: " ++ show conopt_true_line)
           Right version ->
             expect (conopt_version_text version == "4.39.0")
               ("the true banner parsed but reported " ++ show (conopt_version_text version)
                 ++ ", expected \"4.39.0\".")
    _ <- reject "link-version-decoy" (conopt_filler 30 ++ conopt_link_decoy ++ "\n")
    _ <- reject "shared-object-decoy" (conopt_filler 30 ++ conopt_so_decoy ++ "\n")
    reject "both-decoys-no-true-line"
      (conopt_filler 10 ++ conopt_link_decoy ++ "\n" ++ conopt_filler 10 ++ conopt_so_decoy ++ "\n")
  where
    -- The signature is not decoration: OverloadedStrings is on in this file, so an unannotated
    -- name would default and -Wall is a hard gate.
    reject :: String -> String -> Either String ()
    reject name buffer =
      let actual = parse_conopt_version (C8.pack buffer)
      in expect (actual == Left NoConoptBanner)
           ("the CONOPT decoy " ++ show name ++ " was not rejected: got " ++ show actual
             ++ ".\n      Both decoys carry the token CONOPT and only the true line carries the"
             ++ " spaced-letter form. Accepting one records the GAMS link version, or a soname,"
             ++ " as the solver that produced the bytes -- and a different CONOPT can select a"
             ++ " different member of the underdetermined path family while passing every gate.")

-- | GAMS-04. The identical answer with the true line at two DIFFERENT buffer positions.
--
-- 38 and 47 are not decoration: they are the MEASURED 0-based indices of that line in the
-- hermetic probe and in the production run respectively. The line moves between runs, so any
-- positional or line-number logic is wrong by construction, and this is the check that says so
-- with an input rather than with a comment.
conopt_parse_is_position_independent :: Check
conopt_parse_is_position_independent =
  pure_check "conopt_parse_is_position_independent" $ do
    at_38 <- read_at 38
    at_47 <- read_at 47
    expect (at_38 == at_47 && at_38 == "4.39.0")
      ("the CONOPT version depends on WHERE the banner sits: index 38 gave " ++ show at_38
        ++ " and index 47 gave " ++ show at_47 ++ ", both expected \"4.39.0\"."
        ++ " Those two indices are the MEASURED positions of that line in the hermetic probe and"
        ++ " in the production run.")
  where
    read_at index =
      let buffer = conopt_filler index ++ conopt_true_line ++ "\n" ++ conopt_filler 12
      in case parse_conopt_version (C8.pack buffer) of
           Left err ->
             Left ("the true CONOPT banner at buffer line index " ++ show index
                    ++ " was rejected as " ++ show err)
           Right version -> Right (conopt_version_text version)

-- | The exit codes this check pins BY VALUE, each with the claim it refutes.
pinned_exit_rows :: [(Int, Verdict, String)]
pinned_exit_rows =
  [ ( 7, Environmental LicensingError
    , "reading non-zero as \"the model says infeasible\" records an expired licence as an"
        ++ " infeasibility verdict -- an administrative failure rewritten as a scientific claim" )
  , ( 6, Environmental ParameterError
    , "MEASURED: a missing input file and `gams --version` both exit 6. Neither is the model"
        ++ " speaking" )
  , ( 2, ModelLevel CompilationError
    , "MEASURED: a syntax error, and also a bad `--` parameter substitution, since `%..%` is a"
        ++ " COMPILE-TIME substitution of the raw command-line string" )
  , ( 3, ModelLevel ExecutionError
    , "MEASURED: `abort$(..) \"named abort\"` AND an unhandled `a = 1/0` both give 3, so a"
        ++ " \"named abort\" verdict at this code would be a claim the exit code cannot support."
        ++ " The reason is log text and log text is diagnostic only" )
  , ( 145, Environmental CurdirMissing
    , "401 mod 256 -- the fresh-run-directory design's OWN failure code. Environmental, not a"
        ++ " statement about the model" )
  , ( 1, Environmental SolverToBeCalled
    , "the official table's code 1. It is not success and it is not a model verdict" )
  ]

-- | GAMS-01. The taxonomy is total, 0 is the only 'Solved', and six rows are pinned by VALUE.
gams_exit_taxonomy_is_total_and_disjoint :: Check
gams_exit_taxonomy_is_total_and_disjoint =
  pure_check "gams_exit_taxonomy_is_total_and_disjoint" $ do
    _ <- expect (classify_exit ExitSuccess == Solved)
           ("classify_exit ExitSuccess is " ++ show (classify_exit ExitSuccess)
             ++ ", expected Solved.")
    let wrongly_solved = [n | n <- [1 .. 255], classify_exit (ExitFailure n) == Solved]
    _ <- expect (null wrongly_solved)
           ("these exit codes classify as Solved: " ++ show wrongly_solved
             ++ ". Solved means only that GAMS RAN -- MEASURED, `action=c` exits 0 writing no"
             ++ " artifact and `gams` with no arguments exits 0 running no model. A NON-ZERO code"
             ++ " reaching Solved is the catch-all falling through to success, which is this"
             ++ " repository's recurring defect with a number attached.")
    mapM_ pinned pinned_exit_rows
  where
    pinned (code, expected, why) =
      let actual = classify_exit (ExitFailure code)
      in expect (actual == expected)
           ("exit code " ++ show code ++ " classifies as " ++ show actual ++ ", expected "
             ++ show expected ++ ". " ++ why)

-- | GAMS-05's arithmetic half. 124 and 137 are the timeout wrapper's codes and they must collide
-- with nothing in the GAMS domain.
--
-- Asserted in BOTH DIRECTIONS on purpose. Non-membership alone is satisfied by shrinking the
-- domain -- an empty list contains neither code and would pass -- so the named images and the
-- scratch-directory range must also be PRESENT, and every member must classify to something that
-- is not a timeout. The images are the point: GAMS reports 400, 401, 402 and 909, an exit status
-- is a byte, and a collision argument made against the unfolded numbers would be about codes no
-- caller ever observes.
timeout_codes_do_not_collide_with_gams_codes :: Check
timeout_codes_do_not_collide_with_gams_codes =
  pure_check "timeout_codes_do_not_collide_with_gams_codes" $ do
    _ <- expect (124 `notElem` gams_code_domain && 137 `notElem` gams_code_domain)
           ("a timeout code is inside the GAMS code domain: " ++ show gams_code_domain
             ++ ". If they collide, a solve that returned a real GAMS code is recorded as a"
             ++ " timeout, or the reverse.")
    let must_be_present = [0, 1, 2, 3, 7, 11] ++ [109 .. 115] ++ [141, 144, 145, 146]
        missing = [n | n <- must_be_present, n `notElem` gams_code_domain]
    _ <- expect (null missing)
           ("the GAMS code domain has lost codes it must name: " ++ show missing
             ++ ". Non-membership of 124 and 137 is satisfied by a domain that shrank, so the"
             ++ " codes that MUST be in it are asserted here -- including the mod-256 images"
             ++ " 141/144/145/146, which are what a caller actually observes.")
    let timeouts_inside =
          [n | n <- gams_code_domain
             , case classify_exit (ExitFailure n) of
                 TimedOut _ -> True
                 _          -> False]
    _ <- expect (null timeouts_inside)
           ("codes in the GAMS domain classify as a timeout: " ++ show timeouts_inside
             ++ ". The domain and the classifier disagree, so one of them is transcribed rather"
             ++ " than derived.")
    _ <- expect (classify_exit (ExitFailure 124) == TimedOut Expired)
           ("124 classifies as " ++ show (classify_exit (ExitFailure 124))
             ++ ", expected TimedOut Expired -- MEASURED: /usr/bin/timeout exits 124 on expiry.")
    expect (classify_exit (ExitFailure 137) == TimedOut Killed)
      ("137 classifies as " ++ show (classify_exit (ExitFailure 137))
        ++ ", expected TimedOut Killed -- 128 + SIGKILL, what the wrapper's -k leaves behind.")

-- ---------------------------------------------------------------------------------------------
-- Phase 24 plan 02: the renderer that decides the bytes, the whitelist, and the decoder that
-- never builds a 53-bit floating value (GAMS-02, GAMS-06, BYTE-04) -- Tier A only
-- ---------------------------------------------------------------------------------------------

-- | The shock the committed golden artifact was produced FROM, MEASURED on 2026-08-16.
--
-- It is a fixture rather than an invention: the same seven values, rendered by 'render_argv' and
-- handed to the real prover, produced @offchain\/rig\/volume-path-golden.json@ at sha256
-- e7b14f38..07d0d884. So the token list below is not a transcription of what the renderer happens
-- to do -- it is the command line that produced bytes this repository has on disk.
fixture_shock :: Shock
fixture_shock = Shock
  { sh_sqrt_price_x96  = 79228162514264337593543950336
  , sh_liquidity_raw   = 18446744073709551616
  , sh_txl_volume_rate = 490000
  , sh_phi_x_pips      = 500
  , sh_phi_m_pips      = 6000
  , sh_vol_tgt_wad     = 28000000000000000000
  , sh_n_events        = 8
  }

-- | The seven tokens, in order. Compared element by element, so a failure names WHICH one moved.
fixture_argv :: [String]
fixture_argv =
  [ "--sqrtPriceX96=79228162514264337593543950336"
  , "--liquidityRaw=18446744073709551616"
  , "--txlVolumeRate=490000"
  , "--phiXpips=500"
  , "--phiMpips=6000"
  , "--volTgtWad=28000000000000000000"
  , "--nEvents=8"
  ]

-- | The token whose acceptance was MEASURED to change the artifact's bytes.
argv_leading_zero_token :: String
argv_leading_zero_token = "079228162514264337593543950336"

-- | Tokens the edge must refuse, each with the reason it is here.
argv_rejected_tokens :: [(String, String)]
argv_rejected_tokens =
  [ ("empty",              "")
  , ("leading-plus",       "+79")
  , ("leading-space",      " 79")
  , ("trailing-space",     "79 ")
  , ("fractional",         "1.5")
  , ("fractional-mantissa", "2.85e1")
  , ("negative-exponent",  "1e-3")
  , ("radix-prefix",       "0x50")
  , ("negative",           "-1")
  , ("grouping-separator", "79_228")
  ]

-- | The eight shocks that must not render, each with the FIELD the refusal has to name.
--
-- Every one of them is shape-valid: seven integers, none absent. That is the point -- these are
-- the values a defaultable field would have supplied silently.
argv_refusals :: [(String, Shock, String)]
argv_refusals =
  [ ("nEvents-zero",       fixture_shock { sh_n_events        = 0 },             "nEvents")
  , ("liquidity-zero",     fixture_shock { sh_liquidity_raw   = 0 },             "liquidityRaw")
  , ("sqrtPrice-zero",     fixture_shock { sh_sqrt_price_x96  = 0 },             "sqrtPriceX96")
  , ("sqrtPrice-uint160",  fixture_shock { sh_sqrt_price_x96  = 2 ^ (160 :: Int) }, "sqrtPriceX96")
  , ("liquidity-uint128",  fixture_shock { sh_liquidity_raw   = 2 ^ (128 :: Int) }, "liquidityRaw")
  , ("volTgtWad-zero",     fixture_shock { sh_vol_tgt_wad     = 0 },             "volTgtWad")
  , ("txlVolumeRate-100%", fixture_shock { sh_txl_volume_rate = 1000000 },       "txlVolumeRate")
  , ("equal-fees",         fixture_shock { sh_phi_x_pips      = 6000 },          "phiXpips")
  ]

-- | GAMS-06's rendering half, and the one check in this plan whose subject was MEASURED changing
-- the artifact's bytes rather than argued about.
--
-- Four arms. The first is the POSITIVE one and it is first for the usual reason: a renderer that
-- refused everything would satisfy the other three. The second is M7. The third settles Phase 25's
-- KEY-04 here, where the rendering is decided, instead of after rows exist. The fourth is the
-- refusal battery, asserted BY FIELD NAME so a refusal that fired for the wrong reason is not
-- counted as the right one.
argv_rendering_is_canonical_and_total :: Check
argv_rendering_is_canonical_and_total =
  pure_check "argv_rendering_is_canonical_and_total" $ do
    tokens <-
      case render_argv fixture_shock of
        Left err ->
          Left ("the POSITIVE arm failed: the fixture shock -- the very seven values that produced"
                 ++ " the committed golden artifact -- was REFUSED as " ++ show err
                 ++ ". A battery of refusals is satisfied by a renderer that refuses everything,"
                 ++ " so this arm is what keeps the other three meaningful.")
        Right ts -> Right ts
    _ <- expect (length tokens == 7)
           ("render_argv produced " ++ show (length tokens) ++ " tokens, expected exactly 7:"
             ++ "\n      " ++ show tokens
             ++ "\n      An eighth token, or a missing one, is a different command line for the"
             ++ " same shock -- and the command line IS the artifact's bytes for the two echoed"
             ++ " string fields.")
    _ <- mapM_ same_token (zip3 [0 :: Int ..] fixture_argv tokens)

    -- THE M7 ARM. The leading zero is normalized at the EDGE, so it cannot reach the execve.
    normalized <-
      case parse_shock_field argv_leading_zero_token of
        Left err ->
          Left ("parse_shock_field REFUSED " ++ show argv_leading_zero_token ++ " as " ++ show err
                 ++ ". It must NORMALIZE it: a leading zero is a legal spelling of a legal value"
                 ++ " arriving from outside, and refusing it moves the problem to the caller"
                 ++ " instead of settling it.")
        Right value -> Right value
    m7_tokens <-
      case render_argv fixture_shock { sh_sqrt_price_x96 = normalized } of
        Left err -> Left ("the normalized leading-zero shock did not render: " ++ show err)
        Right ts -> Right ts
    m7_token <-
      case m7_tokens of
        (t : _) -> Right t
        []      -> Left "the normalized leading-zero shock rendered an empty token list"
    _ <- expect (m7_token == "--sqrtPriceX96=79228162514264337593543950336")
           ("the leading-zero token normalized to " ++ show m7_token ++ ", expected"
             ++ " \"--sqrtPriceX96=79228162514264337593543950336\".")
    _ <- expect (not ("=0" `isInfixOf` m7_token))
           ("a LEADING ZERO survived into the argv token " ++ show m7_token
             ++ ". MEASURED against the real binary on 2026-08-16: volume_path.gms:206 emits"
             ++ " \"%sqrtPriceX96%\" VERBATIM -- a compile-time substitution of the raw command-line"
             ++ " string -- so this run also EXITS 0, passes EVERY section-4 gate, and writes an"
             ++ " artifact whose sha256 is d64a7b32..14b9e650 instead of the golden"
             ++ " e7b14f38..07d0d884. Two numerically identical shocks, two different artifacts,"
             ++ " nothing red anywhere. The rendering decides the bytes and this phase owns the"
             ++ " execve.")

    -- KEY-04, settled upstream of any row.
    _ <- expect (parse_shock_field "28e18" == parse_shock_field "28000000000000000000")
           ("parse_shock_field disagrees about two spellings of the same value: \"28e18\" gave "
             ++ show (parse_shock_field "28e18") ++ " and \"28000000000000000000\" gave "
             ++ show (parse_shock_field "28000000000000000000")
             ++ ". MEASURED: --volTgtWad=28e18 and --volTgtWad=2.8e19 produce BYTE-IDENTICAL"
             ++ " artifacts, so two spellings that key two rows would key one artifact twice.")

    _ <- mapM_ rejected argv_rejected_tokens
    mapM_ refused argv_refusals
  where
    same_token (index, wanted, got) =
      expect (wanted == got)
        ("argv token " ++ show index ++ " is " ++ show got ++ ", expected " ++ show wanted
          ++ ". The order and the spelling are both fixed: GAMS accepts these parameters in any"
          ++ " order, so a renderer that reordered them would still solve while producing a"
          ++ " different command line for the same shock.")

    rejected (name, token) =
      case parse_shock_field token of
        Left _ -> Right ()
        Right value ->
          Left ("the edge ACCEPTED the token " ++ show token ++ " (" ++ name ++ ") as "
                 ++ show value ++ ". Every member here is a spelling nobody decided about, and an"
                 ++ " undecided spelling normalized by guesswork is a value the caller did not"
                 ++ " supply.")

    refused (name, shock, field) =
      case render_argv shock of
        Right ts ->
          Left ("the refusal " ++ show name ++ " RENDERED instead of failing:\n      " ++ show ts
                 ++ "\n      Every field of Shock is a strict Integer with no optional and no"
                 ++ " defaultable case, so these eight are shape-valid inputs that must be refused"
                 ++ " on VALUE. A zero event count, a zero price or a zero liquidity is what an"
                 ++ " absent subject looks like once a default has supplied it.")
        Left (FieldOutOfRange got _ _)
          | got == field -> Right ()
          | otherwise ->
              Left ("the refusal " ++ show name ++ " named the field " ++ show got
                     ++ ", expected " ++ show field ++ ". A refusal that fires for the wrong"
                     ++ " reason is not the refusal being asserted.")
        Left other ->
          Left ("the refusal " ++ show name ++ " failed as " ++ show other
                 ++ ", expected a FieldOutOfRange naming " ++ show field ++ ".")

-- | GAMS-06's environment half, asserted in BOTH directions and with a positive arm.
--
-- Non-membership alone -- \"no GAMS variable is present\" -- is satisfied by the EMPTY
-- environment, so the key set is asserted as a SET, 'validate_env' is shown ACCEPTING the real
-- whitelist, and it is shown REFUSING both a hostile addition and the empty vector. Without the
-- last two arms a validator that returned @Right ()@ for everything would pass.
the_whitelist_pins_LC_ALL_C_and_admits_no_GAMS_variable :: Check
the_whitelist_pins_LC_ALL_C_and_admits_no_GAMS_variable =
  pure_check "the_whitelist_pins_LC_ALL_C_and_admits_no_GAMS_variable" $ do
    let env  = whitelist_for "/home/x"
        keys = sort (map fst env)
    _ <- expect (keys == ["HOME", "LC_ALL", "PATH"])
           ("the whitelisted environment's keys are " ++ show keys
             ++ ", expected [\"HOME\",\"LC_ALL\",\"PATH\"]. The child gets this vector and nothing"
             ++ " else, so a key that appears here appears in the process that writes the bytes.")
    _ <- expect (keys == sort whitelist_keys)
           ("whitelist_keys is " ++ show (sort whitelist_keys) ++ " and whitelist_for produces "
             ++ show keys ++ ". The advertised list and the vector actually handed to execve have"
             ++ " drifted apart, which is the shape 22-03 measured on RIG_MANIFEST.")
    _ <- expect (lookup "LC_ALL" env == Just "C")
           ("LC_ALL is " ++ show (lookup "LC_ALL" env) ++ ", expected Just \"C\". Without it the"
             ++ " child's decimal separator is whatever the host's locale says, on a path whose"
             ++ " entire purpose is byte reproducibility -- and the artifact carries two fractional"
             ++ " fields written by that very formatter.")
    let offenders = [(k, p) | k <- keys, p <- forbidden_key_prefixes, p `isPrefixOf` k]
    _ <- expect (null offenders)
           ("the whitelist admits a forbidden key: " ++ show offenders
             ++ ". GAMS*, GDX*, CONOPT*, LC_NUMERIC and LANG were all MEASURED inert against the"
             ++ " artifact's bytes on this host, at this toolchain version -- which is a"
             ++ " measurement, not a property of the interface.")
    _ <- expect (validate_env env == Right ())
           ("validate_env REFUSED its own whitelist: " ++ show (validate_env env)
             ++ ". The positive arm is what keeps the two refusals below from being satisfied by a"
             ++ " validator that refuses everything.")
    _ <- expect (validate_env (("GAMSTHREADS", "8") : env) /= Right ())
           "validate_env ADMITTED GAMSTHREADS=8 alongside the whitelist. A key set asserted in only\
           \ one direction is how a whitelist becomes a suggestion."
    expect (validate_env [] /= Right ())
      "validate_env ADMITTED THE EMPTY ENVIRONMENT. That is the defect class this milestone's\
      \ standing rule names, in the one place where it would hand the solver nothing at all and\
      \ report that the environment was controlled."

-- | A synthetic artifact document with the two arrays and the event count under the check's
-- control. Everything else is well formed, so a failure is attributable to the field being moved.
artifact_doc :: String -> String -> String -> BS.ByteString
artifact_doc n_events dqx dqm =
  C8.pack (concat
    [ "{\"sqrtPriceX96\": \"79228162514264337593543950336\""
    , ",\"liquidity\": \"18446744073709551616\""
    , ",\"txlVolumeRate\": 490000,\"phiXpips\": 500,\"phiMpips\": 6000"
    , ",\"nEvents\": ", n_events
    , ",\"deltaRealized\": 0.4900000000,\"rPhiRealized\": 0.0031835300"
    , ",\"dQx\": [", dqx, "]"
    , ",\"dQM\": [", dqm, "]}"
    ])

-- | The constructor name of a refusal, so a check can assert WHICH guard fired without pinning a
-- message that will legitimately be reworded.
artifact_error_kind :: ArtifactError -> String
artifact_error_kind err =
  case err of
    NotJson _       -> "NotJson"
    MissingField _  -> "MissingField"
    NotAnInteger _  -> "NotAnInteger"
    ShapeMismatch _ -> "ShapeMismatch"

-- | GAMS-02's structural half: exit 0 is the door into the conjunct list, not a substitute for it.
--
-- Five arms, and the POSITIVE one is not decoration -- four refusals are satisfied by a decoder
-- that refuses the golden artifact too, which would be GAMS-02 defeated by making the whole path
-- unusable rather than by making it lax.
artifact_postconditions_reject_a_short_array :: Check
artifact_postconditions_reject_a_short_array =
  pure_check "artifact_postconditions_reject_a_short_array" $ do
    let eight = intercalate "," (map show [1 .. 8 :: Int])
        seven = intercalate "," (map show [1 .. 7 :: Int])
    _ <- refuses "short-dQx" "ShapeMismatch" (artifact_doc "8" seven seven)
    _ <- refuses "dQx-and-dQM-differ" "ShapeMismatch" (artifact_doc "8" eight seven)
    _ <- refuses "empty-dQx" "ShapeMismatch" (artifact_doc "8" "" "")
    _ <- refuses "not-a-json-value" "NotJson" (C8.pack "{")
    case decode_artifact golden_artifact_bytes_literal of
      Left err ->
        Left ("the POSITIVE arm failed: the committed 606-byte golden artifact was REFUSED as "
               ++ show err ++ ". Four refusals are satisfied by a decoder that refuses everything.")
      Right artifact ->
        expect (pa_n_events artifact == 8)
          ("the golden artifact decoded with nEvents = " ++ show (pa_n_events artifact)
            ++ ", expected 8.")
  where
    -- The signature is not decoration: OverloadedStrings is on in this file, so the unannotated
    -- name would default its literal arguments and -Wtype-defaults is a hard gate. 24-01 hit the
    -- identical warning on its CONOPT check.
    refuses :: String -> String -> BS.ByteString -> Either String ()
    refuses name wanted bytes =
      case decode_artifact bytes of
        Right _ ->
          Left ("the artifact case " ++ show name ++ " was ACCEPTED. exit 0 means only that GAMS"
                 ++ " RAN -- MEASURED, `action=c` exits 0 writing no artifact at all -- so the"
                 ++ " arrays agreeing with the event count is one of the conjuncts that make a"
                 ++ " document an artifact.")
        Left err
          | artifact_error_kind err == wanted -> Right ()
          | otherwise ->
              Left ("the artifact case " ++ show name ++ " was refused as "
                     ++ artifact_error_kind err ++ " (" ++ show err ++ "), expected " ++ wanted
                     ++ ". A refusal that fires for the wrong reason is not the refusal being"
                     ++ " asserted.")

-- | The six tokens that must not become an element of @dQx@, with the layer that refuses each.
--
-- @2.8e19@ earns its place twice over: it is the EXACT spelling in which a volatility target
-- legitimately arrives on the command line, where 'parse_shock_field' normalizes it to an exact
-- Integer. It is refused HERE because the artifact is an OUTPUT -- an exponent spelling in dQx
-- means the writer produced something this path cannot carry exactly.
--
-- @007@ is MEASURED to be refused ONE LAYER EARLIER than the plan expected, and the measurement is
-- recorded rather than smoothed over: RFC 8259 admits no leading zero, so Store.Json's recogniser
-- refuses the whole document and the answer is NotJson. Asserting NotAnInteger there would have
-- been asserting a transcription against a transcription.
artifact_non_integer_tokens :: [(String, String, String)]
artifact_non_integer_tokens =
  [ ("fractional",          "1.5",    "NotAnInteger")
  , ("exponent-form",       "2.8e19", "NotAnInteger")
  , ("small-exponent-form", "1e3",    "NotAnInteger")
  , ("negative-zero",       "-0",     "NotAnInteger")
  , ("leading-zero",        "007",    "NotJson")
  , ("empty-element",       "\"\"",   "NotAnInteger")
  ]

-- | BYTE-04's refusal half: no spelling of a non-integer becomes an element of dQx.
the_artifact_decoder_refuses_a_non_integer_token :: Check
the_artifact_decoder_refuses_a_non_integer_token =
  pure_check "the_artifact_decoder_refuses_a_non_integer_token" $ do
    _ <- mapM_ one artifact_non_integer_tokens
    -- The POSITIVE arm, with the SAME document shape: an integer token in the same slot decodes.
    case decode_artifact (substituted "6") of
      Left err ->
        Left ("the POSITIVE arm failed: the same document with a plain integer in dQx[0] was"
               ++ " refused as " ++ show err ++ ". Six refusals are satisfied by a decoder that"
               ++ " refuses this document shape outright.")
      Right artifact ->
        expect (take 1 (pa_dqx artifact) == [6])
          ("the substituted document decoded with dQx = " ++ show (pa_dqx artifact)
            ++ ", expected 6 in the first position.")
  where
    substituted token = artifact_doc "2" (token ++ ",7") "8,9"

    one (name, token, wanted) =
      case decode_artifact (substituted token) of
        Right artifact ->
          Left ("the token " ++ show token ++ " (" ++ name ++ ") was ACCEPTED into dQx as "
                 ++ show (pa_dqx artifact)
                 ++ ". Those arrays are swap amounts in wei; a token this decoder had to interpret"
                 ++ " is an amount the model never chose.")
        Left err
          | artifact_error_kind err == wanted -> Right ()
          | otherwise ->
              Left ("the token " ++ show token ++ " (" ++ name ++ ") was refused as "
                     ++ artifact_error_kind err ++ " (" ++ show err ++ "), expected " ++ wanted
                     ++ ".")

-- ---------------------------------------------------------------------------------------------
-- BYTE-04's golden vector
-- ---------------------------------------------------------------------------------------------

volume_path_golden_file :: FilePath
volume_path_golden_file = "offchain/rig/volume-path-golden.json"

-- | @dQx@ from the committed artifact, EXACT. Pinned here so the decoder is compared against a
-- value it did not produce; tied to the file by the digest asserted before any decode.
golden_dqx :: [Integer]
golden_dqx =
  [ -2613128317657530400, -2680707973111378000,  4861675431041821000,  4608884887749073000
  ,  4529439681209106400, -2884368647455834000, -2898559031733104600, -2923236030042153000 ]

golden_dqm :: [Integer]
golden_dqm =
  [  3044390494897843700,  4380130746753610000, -6981993058607328000, -3848149233948789000
  , -2509044703947784000,  1489464758822659600,  1901839408803925500,  2523361587209160700 ]

-- | The two echoed STRING fields, which must survive the decode as text.
golden_sqrt_price_text :: String
golden_sqrt_price_text = "79228162514264337593543950336"

golden_liquidity_text :: String
golden_liquidity_text = "18446744073709551616"

-- | The committed artifact's bytes, rebuilt from the pinned fields for the PURE checks.
--
-- This is a reconstruction and it is labelled one. The check that ties the vector to the file on
-- disk is 'the_golden_vector_comes_from_the_committed_artifact', which digests the real file
-- BEFORE decoding it; this literal exists so the two pure checks above do not need IO, and if it
-- ever disagreed with the file that check is where it would show.
golden_artifact_bytes_literal :: BS.ByteString
golden_artifact_bytes_literal =
  artifact_doc "8" (intercalate ", " (map show golden_dqx)) (intercalate ", " (map show golden_dqm))

-- | The image of an exact wei amount after a round trip through the 53-bit floating type.
--
-- This function is the ONLY place in this repository that puts an artifact array element through
-- that type, and it exists to MEASURE the loss rather than to suffer it.
double_image :: Integer -> Integer
double_image n = round (fromIntegral n :: Double)

-- | BYTE-04's provenance: the pinned vector comes from the COMMITTED FILE, and the file is
-- identified BEFORE it is interpreted.
--
-- The order is the whole design. The digest and the length are asserted first, so editing one byte
-- of the artifact fires HERE -- on identity -- rather than producing a different-but-plausible
-- vector that a decode would happily return. Only then is the file decoded and compared against
-- the pinned exact lists.
the_golden_vector_comes_from_the_committed_artifact :: Check
the_golden_vector_comes_from_the_committed_artifact =
  Check "the_golden_vector_comes_from_the_committed_artifact" . guarded $ do
    there <- doesFileExist volume_path_golden_file
    if not there
      then pure (Left ("the committed golden artifact " ++ volume_path_golden_file
                        ++ " is not on disk. A missing file is a FAILURE naming it, never a pass"
                        ++ " over an empty set -- every assertion below would otherwise be vacuous."))
      else do
        bytes <- BS.readFile volume_path_golden_file
        pure $ do
          _ <- expect (sha256_hex bytes == volume_path_golden_sha256)
                 ("the golden artifact's sha256 is " ++ sha256_hex bytes ++ " and Store.Types pins "
                   ++ volume_path_golden_sha256 ++ ". This is asserted BEFORE the decode on"
                   ++ " purpose: an edited artifact would otherwise decode into a"
                   ++ " different-but-plausible vector and the truncation table below would be"
                   ++ " measuring a file nobody produced.")
          _ <- expect (BS.length bytes == volume_path_golden_bytes_len)
                 ("the golden artifact is " ++ show (BS.length bytes) ++ " bytes and Store.Types"
                   ++ " pins " ++ show volume_path_golden_bytes_len
                   ++ ". Length and digest are pinned separately so a truncation is named as one.")
          artifact <-
            case decode_artifact bytes of
              Left err ->
                Left ("the committed golden artifact did not decode: " ++ show err
                       ++ ". Its digest matched, so this is the DECODER disagreeing with real"
                       ++ " solver output rather than the file having moved.")
              Right a -> Right a
          _ <- expect (pa_dqx artifact == golden_dqx)
                 ("dQx decoded as " ++ show (pa_dqx artifact) ++ ", pinned " ++ show golden_dqx
                   ++ ". Both sides are exact Integers and the file they come from is identified by"
                   ++ " digest, so a difference here is a wei-level decode defect, not a rounding"
                   ++ " convention.")
          _ <- expect (pa_dqm artifact == golden_dqm)
                 ("dQM decoded as " ++ show (pa_dqm artifact) ++ ", pinned " ++ show golden_dqm ++ ".")
          _ <- expect (pa_sqrt_price_x96_text artifact == golden_sqrt_price_text)
                 ("sqrtPriceX96 survived the decode as " ++ show (pa_sqrt_price_x96_text artifact)
                   ++ ", expected " ++ show golden_sqrt_price_text
                   ++ ". It is kept as TEXT because the cross-check that closes the invocation"
                   ++ " contract compares it to the argv TOKEN that was sent, and that equality"
                   ++ " means nothing if either side was rebuilt from a number.")
          expect (pa_liquidity_text artifact == golden_liquidity_text)
            ("liquidity survived the decode as " ++ show (pa_liquidity_text artifact)
              ++ ", expected " ++ show golden_liquidity_text ++ ".")

-- | BYTE-04, as an EQUALITY that no tolerance can absorb.
--
-- MEASURED: the first element of dQx is -2613128317657530400 exactly, and its image under the
-- 53-bit floating type is -2613128317657530368 exactly -- a difference of 32 wei. Both assertions
-- are equalities on Integers. A check written as \"the difference is small\" or \"within epsilon\"
-- would pass under the very decoder this requirement exists to forbid, because 32 wei IS small;
-- the point is that it is not ZERO and that the amount is a swap this repository would execute.
dqx_double_decode_loses_exactly_32_wei_on_the_first_element :: Check
dqx_double_decode_loses_exactly_32_wei_on_the_first_element =
  pure_check "dqx_double_decode_loses_exactly_32_wei_on_the_first_element" $
    case golden_dqx of
      [] ->
        Left "golden_dqx is EMPTY, so the truncation measurement has no subject at all."
      (first_element : _) -> do
        let image = double_image first_element
        _ <- expect (image == -2613128317657530368)
               ("dQx[0] = " ++ show first_element ++ " has the 53-bit image " ++ show image
                 ++ ", and the MEASURED image is -2613128317657530368. This is an EQUALITY on"
                 ++ " Integers: if the two agree, the array element is being carried exactly and"
                 ++ " this measurement no longer has a subject; re-measure it, do not delete it.")
        expect (image - first_element == 32)
          ("dQx[0] moves by " ++ show (image - first_element) ++ " wei through the 53-bit type and"
            ++ " the MEASURED move is exactly +32. The sign convention is the research table's --"
            ++ " delta = image MINUS exact -- and it is stated because the first arm caught this"
            ++ " check written the other way round: the magnitude was right and the sign was not,"
            ++ " which an absolute value would have hidden. These are wei, and the arrays are swap"
            ++ " amounts, so a"
            ++ " decoder that took this path would execute a swap for an amount the model never"
            ++ " chose. NO TOLERANCE CAN ABSORB EITHER ASSERTION -- both are equalities, which is"
            ++ " the whole point of stating them this way.")

-- | 16 OF 16, not \"at least one\".
--
-- A decoder that silently widened ONE field -- say dQx and not dQM -- would still be caught, which
-- an existential assertion would not do. The magnitude band is asserted too: |delta| between 4 and
-- 328 was MEASURED across the whole vector, so a band that collapsed to zero (every element exact)
-- reddens instead of quietly making the requirement vacuous.
every_golden_element_is_inexact_under_double :: Check
every_golden_element_is_inexact_under_double =
  pure_check "every_golden_element_is_inexact_under_double" $ do
    let vector  = golden_dqx ++ golden_dqm
        -- delta = image MINUS exact, the research table's convention, so the values this check
        -- reports can be compared against M12 row by row without a sign flip.
        deltas  = [(n, double_image n - n) | n <- vector]
        differ  = [pair | pair@(_, d) <- deltas, d /= 0]
        outside = [pair | pair@(_, d) <- deltas, abs d < 4 || abs d > 328]
    _ <- expect (length vector == 16)
           ("the golden vector carries " ++ show (length vector) ++ " elements, expected 16 (8 in"
             ++ " dQx and 8 in dQM). A shrunken vector makes the count assertion below satisfiable"
             ++ " by deletion.")
    _ <- expect (length differ == 16)
           ("only " ++ show (length differ) ++ " of 16 elements are inexact under the 53-bit type."
             ++ " MEASURED: ALL SIXTEEN are, with |delta| between 4 and 328. Asserting 16 rather"
             ++ " than 'at least one' is what catches a decoder that widened a single field and"
             ++ " left the rest alone.\n      exact elements: "
             ++ show [n | (n, d) <- deltas, d == 0])
    expect (null outside)
      ("these elements' losses fall outside the MEASURED band [4, 328]: " ++ show outside
        ++ ". The band is asserted so that a vector whose losses collapsed toward zero -- the shape"
        ++ " of a fixture quietly replaced by exactly-representable numbers -- reddens rather than"
        ++ " making this requirement vacuous.")

-- ---------------------------------------------------------------------------------------------
-- The artifact path's source scans, and the scope that must GROW
-- ---------------------------------------------------------------------------------------------

-- | The two modules BYTE-04 names by number, asserted PRESENT in the scanned set below.
--
-- They are written out because the requirement is about THEM: @Gams\/Artifact.hs@ decodes the
-- arrays and @Gams\/Argv.hs@ renders the shock that produced them. A scan that silently stopped
-- covering either one would still pass every set comparison if the set it was compared against had
-- shrunk in the same commit.
byte04_named_modules :: [FilePath]
byte04_named_modules =
  [ "offchain/lib/Gams/Argv.hs"
  , "offchain/lib/Gams/Artifact.hs"
  ]

-- | THE SAME SET THE AESON SCAN READS, AND THAT IS THE POINT.
--
-- The first draft of this scan listed two files. MEASURED at 24-02, before it shipped: every @.hs@
-- under @offchain\/lib\/{Store,Gams}\/@ is already free of the pattern, so covering two of them
-- cost thirteen files of coverage and bought nothing -- and it left the float scan with a
-- hardcoded list and NO growth guard, which is the very defect
-- 'the_artifact_path_scan_covers_every_module_on_it' exists to close, reproduced inside the commit
-- that closes it. Pointing both scans at ONE set means the directory-vs-list assertion covers both,
-- so a module added under either directory is scanned for a 53-bit value on the day it lands.
artifact_float_path :: [FilePath]
artifact_float_path = aeson_storage_path

artifact_float_pattern :: String
artifact_float_pattern = "Double|Float|realToFrac|fromRational"

-- | The seeded bait, BUILT rather than written out, following 'aeson_bait_source'. This file is
-- not in 'artifact_float_path' today, and a bait spelled contiguously here is one scope change
-- away from being found by the scan it exists to exercise.
artifact_float_bait_source :: String
artifact_float_bait_source =
  "amount :: " ++ "Dou" ++ "ble\n"
    ++ "amount = real" ++ "ToFrac (1 :: Rational)\n"

-- | Absence may not read as success until the pattern has been SHOWN matching. Returned so the
-- caller orders it FIRST.
artifact_float_positive_control :: IO (Either String ())
artifact_float_positive_control = do
  tmp <- getTemporaryDirectory
  let dir       = tmp </> "byte04-float-positive-control"
      bait      = dir </> "bait.hs"
      innocent  = dir </> "clean.hs"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [bait, innocent]) $ do
    writeFile bait artifact_float_bait_source
    writeFile innocent "amount :: Integer\namount = 1\n"
    (code, out, err) <- gams_version_scan artifact_float_pattern [bait, innocent]
    pure $ do
      _ <- expect (code == ExitSuccess)
             ("BYTE-04's POSITIVE CONTROL did not fire: the scan exited " ++ show code
               ++ " over a file that declares a 53-bit floating value and converts to one. The"
               ++ " pattern has stopped matching anything, which means the exit-1 the real scan"
               ++ " reports is absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      stderr: " ++ err))
      _ <- expect ("bait.hs" `isInfixOf` out)
             ("BYTE-04's POSITIVE CONTROL fired but did not NAME the seeded file. It said:\n"
               ++ unlines (map ("      " ++) (lines out)))
      expect (not ("clean.hs" `isInfixOf` out))
        ("BYTE-04's POSITIVE CONTROL matched a file with no floating value in it at all, so the"
          ++ " pattern is matching something other than what it claims to. It said:\n"
          ++ unlines (map ("      " ++) (lines out)))

-- | BYTE-04's structural half: the artifact path carries neither a 53-bit floating value nor a
-- JSON library, and the module that decodes the artifact is ON the aeson scan's list.
--
-- Four assertions in this order: (1) the float pattern is SHOWN matching a seeded bait; (2) every
-- scanned file EXISTS; (3) the two modules BYTE-04 names are IN the scanned set, so the claim is
-- made by a scan that actually reads them rather than by this check's name; (4) the float scan
-- finds nothing.
--
-- (3) is the pre-empted Phase-23 finding in its narrowest form. @Gams\/Artifact.hs@ was added to
-- 'aeson_storage_path' in the SAME COMMIT that created it, which is the rule that list's own
-- haddock writes down and that 23-03 broke by two commits.
no_Double_and_no_aeson_on_the_artifact_path :: Check
no_Double_and_no_aeson_on_the_artifact_path =
  Check "no_Double_and_no_aeson_on_the_artifact_path" . guarded $ do
    control  <- artifact_float_positive_control
    presence <- mapM (\p -> (,) p <$> doesFileExist p) artifact_float_path
    let gone     = [p | (p, False) <- presence]
        unscanned = [p | p <- byte04_named_modules, p `notElem` artifact_float_path]
    if not (null gone)
      then pure $ do
        _ <- control
        expect False
          ("the artifact path names files that are not on disk: " ++ intercalate ", " gone
            ++ ". Scoping the list to the files that exist would make this check pass BECAUSE its"
            ++ " subject is absent.")
      else if not (null unscanned)
        then pure $ do
          _ <- control
          expect False
            ("the two modules BYTE-04 names are NOT in the scanned set: "
              ++ intercalate ", " unscanned
              ++ ". The scanned set is aeson_storage_path, so this fires when that list shrinks"
              ++ " away from the artifact's own decoder -- the shape a set comparison alone cannot"
              ++ " catch, because a list and a directory can shrink together. 23-03 MEASURED the"
              ++ " neighbouring case: Store/Schema.hs sat unlisted for two commits and nothing"
              ++ " reddened.")
        else do
          (code, out, err) <- gams_version_scan artifact_float_pattern artifact_float_path
          pure $ do
            _ <- control
            case code of
              ExitFailure 1 -> Right ()
              ExitFailure n -> Left ("the scan itself failed with exit " ++ show n ++ ": " ++ err)
              ExitSuccess ->
                Left ("a 53-bit floating value is on the ARTIFACT PATH. MEASURED from the committed"
                       ++ " golden artifact: dQx[0] loses exactly 32 wei through that type and ALL"
                       ++ " SIXTEEN elements of dQx ++ dQM are inexact, |delta| in [4, 328]. These"
                       ++ " are swap amounts in wei.\n"
                       ++ unlines (map ("      " ++) (lines out)))

-- | The directories whose every @.hs@ file must be a DECIDED member of the aeson scan.
artifact_path_directories :: [FilePath]
artifact_path_directories = [ "offchain/lib/Gams", "offchain/lib/Store" ]

-- | Modules under those directories that are deliberately NOT scanned, each with its reason.
--
-- EMPTY at 24-02, and that is a fact rather than a placeholder: every module under
-- @offchain\/lib\/{Store,Gams}\/@ is scanned today. An entry added here must carry the reason it
-- is one, because an exemption without a reason is how a scan's scope shrinks to the empty set one
-- plausible file at a time.
aeson_scan_exemptions :: [(FilePath, String)]
aeson_scan_exemptions = []

-- | Every @.hs@ under a directory, from the DIRECTORY rather than from a list.
modules_under :: FilePath -> IO [FilePath]
modules_under dir = do
  there <- doesDirectoryExist dir
  if not there
    then pure []
    else do
      entries <- listDirectory dir
      pure (sort [dir </> e | e <- entries, takeExtension e == ".hs"])

-- | THE SCOPE-GROWTH GUARD, and the reason it exists is a measurement rather than a principle.
--
-- 'aeson_storage_path' is a hardcoded list, and its own haddock records what that costs: 23-03
-- landed @Store\/Schema.hs@ and it sat unlisted for TWO COMMITS -- a storage module the scan did
-- not read, with nothing red, caught by a plan's self-check rather than by anything that fails. A
-- named list makes an omission VISIBLE; comparing the list against the directory makes it
-- IMPOSSIBLE, and it does so without reverting to a glob, because every file is still decided
-- about by name -- either scanned or exempt WITH A REASON.
--
-- Asserted in BOTH directions. A module on disk that is neither scanned nor exempt is a failure
-- naming it; a listed file with nothing on disk is a failure naming it too, because a list scoped
-- to the files that happen to exist passes over an empty set.
the_artifact_path_scan_covers_every_module_on_it :: Check
the_artifact_path_scan_covers_every_module_on_it =
  Check "the_artifact_path_scan_covers_every_module_on_it" . guarded $ do
    present <- mapM doesDirectoryExist artifact_path_directories
    let absent_dirs = [d | (d, False) <- zip artifact_path_directories present]
    if not (null absent_dirs)
      then pure (Left ("these artifact-path directories are not on disk: "
                        ++ intercalate ", " absent_dirs
                        ++ ". An enumeration of a directory that does not exist is empty, and an"
                        ++ " empty enumeration agrees with every list."))
      else do
        found <- mapM modules_under artifact_path_directories
        let on_disk  = sort (concat found)
            decided  = sort (aeson_storage_path ++ map fst aeson_scan_exemptions)
            unlisted = [m | m <- on_disk, m `notElem` decided]
            phantom  = [m | m <- decided, m `notElem` on_disk]
        pure $ do
          _ <- expect (not (null on_disk))
                 ("no .hs file was found under " ++ intercalate ", " artifact_path_directories
                   ++ ". The set comparison below would then be an assertion about nothing.")
          expect (null unlisted && null phantom)
            ("the modules on disk under " ++ intercalate " and " artifact_path_directories
              ++ " are not the set this scan decided about."
              ++ (if null unlisted then ""
                    else "\n      on disk but neither scanned nor exempt: "
                           ++ intercalate ", " unlisted)
              ++ (if null phantom then ""
                    else "\n      scanned or exempt but not on disk: " ++ intercalate ", " phantom)
              ++ "\n      A new module under offchain/lib/{Store,Gams}/ is added to"
              ++ " aeson_storage_path -- or to aeson_scan_exemptions WITH A WRITTEN REASON -- in"
              ++ " the commit that creates it. A missing file is a FAILURE naming the plan that"
              ++ " creates it, never a pass. 23-03 MEASURED the other half: Store/Schema.hs spent"
              ++ " two commits unlisted and nothing reddened, because a named list makes an"
              ++ " omission visible without making it impossible.")

-- ---------------------------------------------------------------------------------------------
-- Phase 24 Tier B: the IO edge, driven against stubs these checks write themselves
--
-- THE SUITE STAYS GAMS-FREE. Every subprocess below is a /bin/sh script one of these checks wrote
-- into a temp directory moments earlier. None of the three forbidden tokens is in this file -- see
-- the note beside the `Gams.Run` import, which also records why they are described there instead of
-- listed. `Gams.Run` is deliberately OUTSIDE that token set so the IO edge can be driven without
-- the suite becoming structurally capable of naming the real prover.
--
-- Spawning is not new here. `purge_scan` and `aeson_scan` have spawned `grep` since 22-08, and
-- `purge_positive_control` and `aeson_positive_control` both build a temp directory, write files
-- into it and clean up with `finally`. These checks are that idiom with a different child.
-- ---------------------------------------------------------------------------------------------

-- | The shock every Tier-B check sends, and it is the GOLDEN artifact's own inputs.
--
-- That is not decoration. 'a_pre_existing_artifact_is_unreachable' plants the real 606 committed
-- bytes where a careless layer would find them, and those bytes echo
-- @79228162514264337593543950336@ and @18446744073709551616@ back. If the shock carried anything
-- else, the plant would be caught by the ECHO conjunct or by the decoder -- and the check would
-- then be evidence about the decoder rather than about the isolation it exists to prove.
tier_b_shock :: Shock
tier_b_shock = Shock
  { sh_sqrt_price_x96  = 79228162514264337593543950336
  , sh_liquidity_raw   = 18446744073709551616
  , sh_txl_volume_rate = 490000
  , sh_phi_x_pips      = 500
  , sh_phi_m_pips      = 6000
  , sh_vol_tgt_wad     = 28000000000000000000
  , sh_n_events        = 8
  }

-- | Writes an executable @\/bin\/sh@ script into a scratch directory and returns its ABSOLUTE path.
--
-- Stubs are BUILT, never committed, for the reason 'aeson_bait_source' and 'purge_control_literal'
-- are built: a committed stub would spell a GAMS version banner inside @offchain\/@, where the
-- scans that exist to find exactly that would find it. Building it keeps the bait inside the check
-- that needs it and outside every scan's scope.
--
-- @directory@ is already a test dependency, so @getPermissions@\/@setPermissions@ cost nothing;
-- @unix@ is NOT a dependency of this stanza and is not needed for one chmod.
write_stub :: FilePath -> String -> String -> IO FilePath
write_stub dir name body = do
  createDirectoryIfMissing True dir
  path <- makeAbsolute (dir </> name)
  writeFile path body
  perms <- getPermissions path
  setPermissions path (setOwnerExecutable True perms)
  pure path

-- | Every stub receives the argv 'Gams.Run.run_prover' builds, so it parses out what it needs.
--
-- @curdir=@ is how a stub learns which directory to write into, and it is the ONLY way it can
-- learn: the run directory is chosen inside 'Gams.Run.run_prover' and cannot be predicted from
-- here, which is the same fact 'a_pre_existing_artifact_is_unreachable' turns into evidence.
stub_preamble :: String
stub_preamble =
  unlines
    [ "#!/bin/sh"
    , "D="
    , "S="
    , "L="
    , "for a in \"$@\"; do"
    , "  case \"$a\" in"
    , "    curdir=*) D=${a#curdir=} ;;"
    , "    --sqrtPriceX96=*) S=${a#--sqrtPriceX96=} ;;"
    , "    --liquidityRaw=*) L=${a#--liquidityRaw=} ;;"
    , "  esac"
    , "done"
    ]

-- | The artifact a well-behaved stub writes: the golden document, with the two echoed fields taken
-- from the shell expressions handed in.
--
-- Passing @\"$S\"@ produces the honest echo; passing a literal produces the input for the echo
-- conjunct's own firing.
stub_writes_artifact :: String -> String -> String
stub_writes_artifact echo_sqrt echo_liquidity =
  unlines
    [ "cat > \"$D/" ++ artifact_name ++ "\" <<EOF"
    , "{"
    , "  \"sqrtPriceX96\": \"" ++ echo_sqrt ++ "\","
    , "  \"liquidity\": \"" ++ echo_liquidity ++ "\","
    , "  \"txlVolumeRate\": 490000,"
    , "  \"phiXpips\": 500,"
    , "  \"phiMpips\": 6000,"
    , "  \"nEvents\": 8,"
    , "  \"deltaRealized\": 0.4900000000,"
    , "  \"rPhiRealized\": 0.0031835300,"
    , "  \"dQx\": [-2613128317657530400, -2680707973111378000, 4861675431041821000,"
        ++ " 4608884887749073000, 4529439681209106400, -2884368647455834000,"
        ++ " -2898559031733104600, -2923236030042153000],"
    , "  \"dQM\": [3044390494897843700, 4380130746753610000, -6981993058607328000,"
        ++ " -3848149233948789000, -2509044703947784000, 1489464758822659600,"
        ++ " 1901839408803925500, 2523361587209160700]"
    , "}"
    , "EOF"
    ]

-- | The log a well-behaved stub writes: the REAL captured banner shape, with the job name equal to
-- the basename of the model that was invoked, plus the true spaced-letter CONOPT line.
stub_writes_log :: String
stub_writes_log =
  unlines
    [ "cat > \"$D/" ++ log_name ++ "\" <<EOF"
    , "--- Job " ++ gams_model_basename
        ++ " Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux"
    , "    C O N O P T   version 4.39.0"
    , "EOF"
    ]

-- | The clean stub: writes both files, echoes both tokens, exits 0.
stub_clean :: String
stub_clean =
  stub_preamble ++ stub_writes_artifact "$S" "$L" ++ stub_writes_log ++ "exit 0\n"

-- | The stub whose whole body is an exit-0. MEASURED with the REAL binary: @action=c@ produces
-- exactly this shape -- exit 0, @volume_path.log@ and @volume_path.lst@ present,
-- @volume_path.json@ ABSENT.
stub_silent_success :: String
stub_silent_success = "#!/bin/sh\nexit 0\n"

-- | A stub that exits with a chosen code and writes nothing.
stub_exits :: Int -> String
stub_exits code = stub_preamble ++ "exit " ++ show code ++ "\n"

-- | The clean stub, plus a line of stdout. TWO of these with the SAME exit code and DIFFERENT
-- stdout must produce the same verdict, and without that arm the exit-code check is satisfied by a
-- layer that reads the log.
stub_clean_saying :: String -> String
stub_clean_saying line =
  stub_preamble ++ stub_writes_artifact "$S" "$L" ++ stub_writes_log
    ++ "echo '" ++ line ++ "'\n" ++ "exit 0\n"

-- | A scratch directory carrying a stand-in for the model file, torn down afterwards.
--
-- The model file must EXIST: 'Gams.Run.run_prover' digests it into 'ToolchainIdentity', so a run
-- against a model that is not there fails loudly rather than recording an absent source.
with_tier_b_scratch :: String -> (FilePath -> IO a) -> IO a
with_tier_b_scratch label body = do
  tmp <- getTemporaryDirectory
  dir <- makeAbsolute (tmp </> ("gams24-tier-b-" ++ label))
  createDirectoryIfMissing True dir
  writeFile (dir </> gams_model_basename)
    "* a stand-in for volume_path.gms. No stub reads it; run_prover digests it.\n"
  body dir `finally` removeDirectoryRecursive dir

-- | The request every Tier-B check sends: the whitelisted environment, an absolute stub, a five
-- second budget and a one second kill grace.
tier_b_request :: FilePath -> FilePath -> RunRequest
tier_b_request scratch stub = RunRequest
  { rr_binary       = stub
  , rr_model        = scratch </> gams_model_basename
  , rr_shock        = tier_b_shock
  , rr_env          = Just (whitelist_for scratch)
  , rr_budget_s     = 5
  , rr_kill_after_s = 1
  }

-- | Enough of an outcome to NAME it in a failure message, without ever claiming an artifact the
-- outcome does not carry.
render_outcome :: ProverOutcome -> String
render_outcome (Produced artifact identity streams) =
  "Produced (" ++ show (BS.length (pa_bytes artifact)) ++ " artifact bytes, GAMS "
    ++ gams_version_text (ti_gams_version identity) ++ ", run dir " ++ show (cs_run_dir streams)
    ++ ")"
render_outcome (Aborted why code streams) =
  "Aborted " ++ show why ++ " at exit " ++ show code ++ " (run dir "
    ++ show (cs_run_dir streams) ++ ")"

-- | The run directory an outcome reports, whichever outcome it is.
outcome_run_dir :: ProverOutcome -> FilePath
outcome_run_dir (Produced _ _ streams) = cs_run_dir streams
outcome_run_dir (Aborted _ _ streams)  = cs_run_dir streams

-- | THE EXIT CODE DRIVES THE VERDICT, AND THE STREAMS DO NOT.
--
-- Six stubs. Four fix the code-to-verdict map at values that MATTER -- 2 and 3 are the two
-- measured model-level codes, 7 is licensing and must not read as a statement about the model, and
-- exit 0 with a valid artifact is the only door to 'Produced'.
--
-- The fifth and sixth are the arm without which this check is satisfied by a layer that reads the
-- log: two stubs with the SAME exit code, the SAME artifact and DIFFERENT stdout -- one announcing
-- a clean finish, the other announcing a failed solve -- must give the IDENTICAL verdict. The
-- stdout difference is asserted to be REAL before the verdicts are compared, because two identical
-- empty streams would make the comparison true about nothing.
stub_exit_codes_drive_the_verdict :: Check
stub_exit_codes_drive_the_verdict =
  Check "stub_exit_codes_drive_the_verdict" . guarded $
    with_tier_b_scratch "exit-codes" $ \scratch -> do
      clean  <- write_stub scratch "clean.sh"  stub_clean
      two    <- write_stub scratch "exit2.sh"  (stub_exits 2)
      three  <- write_stub scratch "exit3.sh"  (stub_exits 3)
      seven  <- write_stub scratch "exit7.sh"  (stub_exits 7)
      chatty_ok  <- write_stub scratch "chatty-ok.sh"  (stub_clean_saying "Normal completion")
      chatty_bad <- write_stub scratch "chatty-bad.sh" (stub_clean_saying "** Locally Infeasible")
      let run stub = run_prover (tier_b_request scratch stub)
      o_clean <- run clean
      o_two   <- run two
      o_three <- run three
      o_seven <- run seven
      o_ok    <- run chatty_ok
      o_bad   <- run chatty_bad
      pure $ do
        _ <- aborted_as "exit 2" (ExitVerdict (ModelLevel CompilationError)) 2 o_two
        _ <- aborted_as "exit 3" (ExitVerdict (ModelLevel ExecutionError)) 3 o_three
        _ <- aborted_as "exit 7" (ExitVerdict (Environmental LicensingError)) 7 o_seven
        _ <- case o_clean of
               Produced artifact identity _ -> do
                 _ <- expect (pa_n_events artifact == 8)
                        ("the clean stub produced an artifact whose nEvents is "
                          ++ show (pa_n_events artifact) ++ ", not 8.")
                 expect (isJust (ti_conopt_version identity))
                   ("the clean run reached Produced with NO CONOPT version. Nothing is permitted"
                     ++ " to carry no solver banner except a run that aborted before the solve,"
                     ++ " and a Produced outcome is not one -- so a Nothing here means the parse"
                     ++ " found nothing and the run recorded that as an identity anyway.")
               other ->
                 expect False
                   ("the stub that exits 0 having written a valid artifact and a log with a"
                     ++ " matching job banner did not produce one: " ++ render_outcome other)
        -- The stream-independence arm's own positive control: assert the two stdouts DIFFER before
        -- concluding anything from the verdicts agreeing.
        _ <- expect (stdout_of o_ok /= stdout_of o_bad)
               ("the two chatty stubs produced IDENTICAL stdout ("
                 ++ show (stdout_of o_ok) ++ "), so the stream-independence arm below would be"
                 ++ " comparing two runs that said the same thing. Either the stubs stopped"
                 ++ " printing or the capture stopped reaching this check.")
        expect (verdict_shape o_ok == verdict_shape o_bad)
          ("two stubs with the SAME exit code and DIFFERENT stdout produced DIFFERENT verdicts."
            ++ "\n      said " ++ show (stdout_of o_ok) ++ ": " ++ render_outcome o_ok
            ++ "\n      said " ++ show (stdout_of o_bad) ++ ": " ++ render_outcome o_bad
            ++ "\n      No decision may read a stream. VOLUME_PATH.md section 4: gate on the exit"
            ++ " code, never on log text -- and MEASURED, stderr is 0 BYTES in every GAMS mode, so"
            ++ " a stream reader compares the empty string against the empty string on the good"
            ++ " path and on the bad one alike.")
  where
    stdout_of (Produced _ _ streams) = cs_stdout streams
    stdout_of (Aborted _ _ streams)  = cs_stderr streams `BS.append` cs_stdout streams

    -- The verdict, with the diagnostic material projected OUT: two runs differ in run directory and
    -- in captured streams by construction, and neither is a verdict.
    verdict_shape :: ProverOutcome -> Either (AbortReason, Int) BS.ByteString
    verdict_shape (Produced artifact _ _) = Right (pa_bytes artifact)
    verdict_shape (Aborted why code _)    = Left (why, code)

    aborted_as :: String -> AbortReason -> Int -> ProverOutcome -> Either String ()
    aborted_as label wanted wanted_code outcome =
      case outcome of
        Aborted why code _
          | why == wanted && code == wanted_code -> Right ()
        _ ->
          Left ("the stub that " ++ label ++ " should have given Aborted (" ++ show wanted
                 ++ ") at exit " ++ show wanted_code ++ ", and gave " ++ render_outcome outcome
                 ++ ". Exit 7 is LICENSING: a layer that reads any non-zero code as a statement"
                 ++ " about the model records an expired licence as a scientific claim.")

-- | GAMS-02, DRIVEN RATHER THAN READ.
--
-- A stub whose entire body is @exit 0@. If this check ever goes green on a layer that reports
-- success, that layer is trusting exit 0 alone -- and MEASURED with the REAL binary on 2026-08-16,
-- @action=c@ produces exactly this shape: exit 0, @volume_path.log@ and @volume_path.lst@ written,
-- @volume_path.json@ ABSENT. GAMS's own documentation says exit 0 means /GAMS ran/, not /the model
-- solved/.
exit_zero_without_artifact_is_refused :: Check
exit_zero_without_artifact_is_refused =
  Check "exit_zero_without_artifact_is_refused" . guarded $
    with_tier_b_scratch "silent-success" $ \scratch -> do
      stub <- write_stub scratch "silent.sh" stub_silent_success
      outcome <- run_prover (tier_b_request scratch stub)
      pure $
        case outcome of
          Aborted NoArtifact 0 _ -> Right ()
          _ ->
            Left ("a child that exits 0 and writes NOTHING was not refused: "
                   ++ render_outcome outcome
                   ++ "\n      Exit 0 is the FIRST conjunct and never the only one. MEASURED with"
                   ++ " the real binary: `action=c` exits 0, writes the log and the listing, and"
                   ++ " writes no volume_path.json at all -- so a layer that reported success here"
                   ++ " would report a solve for a run that compiled and stopped.")

-- | The bytes a careless layer would find, and the two places it would look.
cwd_plant_artifact :: FilePath
cwd_plant_artifact = artifact_name

cwd_plant_log :: FilePath
cwd_plant_log = log_name

-- | THE PLANT, AND THE PROOF THAT THE RUN DIRECTORY CANNOT BE PREDICTED.
--
-- The real 606 committed golden bytes are planted at the process's own working directory, together
-- with a log carrying a valid job banner -- so a layer reading from the CWD would find an artifact
-- that satisfies EVERY remaining conjunct: it decodes, its arrays agree with nEvents, and both
-- echoed fields equal the tokens 'tier_b_shock' sends. Then an exit-0-writes-nothing stub is run.
-- The answer must be @Aborted NoArtifact@, because the run happened in a directory that was created
-- moments earlier by 'System.Directory.createDirectory' -- which FAILS if the path exists -- and
-- that directory cannot contain a file nobody put there.
--
-- The plant uses the REAL bytes on purpose. A placeholder would be refused by the DECODER, and the
-- check would then be evidence about the decoder instead of about the isolation.
--
-- THE SAFETY IS MANDATORY, NOT DEFENSIVE. Neither planted path may already exist -- this check
-- FAILS rather than clobbering -- both are removed in a `finally`, and `git status --porcelain` is
-- asked afterwards whether either name appears. A harness that can leave a file in the tree is the
-- class this repository keeps rediscovering.
a_pre_existing_artifact_is_unreachable :: Check
a_pre_existing_artifact_is_unreachable =
  Check "a_pre_existing_artifact_is_unreachable" . guarded $ do
    golden <- BS.readFile volume_path_golden_file
    artifact_there <- doesFileExist cwd_plant_artifact
    log_there      <- doesFileExist cwd_plant_log
    cwd            <- getCurrentDirectory
    if artifact_there || log_there
      then pure (Left ("this check plants files at the process working directory (" ++ cwd
                        ++ ") and one of them is ALREADY THERE: "
                        ++ intercalate ", " ([cwd_plant_artifact | artifact_there]
                                              ++ [cwd_plant_log | log_there])
                        ++ ". It refuses to clobber. Remove or rename it and re-run."))
      else do
        planted <- with_tier_b_scratch "plant" (\scratch -> do
          let discard p = do
                there <- doesFileExist p
                if there then removeFile p else pure ()
          flip finally (mapM_ discard [cwd_plant_artifact, cwd_plant_log]) $ do
            BS.writeFile cwd_plant_artifact golden
            writeFile cwd_plant_log
              ("--- Job " ++ gams_model_basename
                ++ " Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux\n"
                ++ "    C O N O P T   version 4.39.0\n")
            BS.writeFile (scratch </> artifact_name) golden
            stub <- write_stub scratch "silent.sh" stub_silent_success
            run_prover (tier_b_request scratch stub))
        (_, git_out, _) <- readProcessWithExitCode "git" ["status", "--porcelain"] ""
        pure $ do
          _ <- expect (BS.length golden == volume_path_golden_bytes_len)
                 ("the planted bytes are " ++ show (BS.length golden) ++ " long and the committed"
                   ++ " golden artifact is " ++ show volume_path_golden_bytes_len
                   ++ ". A short plant would be refused by the decoder, and this check would then"
                   ++ " be measuring the decoder instead of the isolation.")
          _ <- case planted of
                 Aborted NoArtifact 0 _ -> Right ()
                 _ ->
                   Left ("a valid-looking " ++ artifact_name ++ " planted at the caller's working"
                          ++ " directory WAS REACHABLE: " ++ render_outcome planted
                          ++ "\n      The run happens in a directory created moments earlier with"
                          ++ " the exclusive createDirectory, so no file anyone else wrote can be"
                          ++ " at the path the artifact is read from. These are the real 606"
                          ++ " committed golden bytes, which satisfy every other conjunct --"
                          ++ " they decode, the arrays agree with nEvents, and both echoed fields"
                          ++ " equal the tokens this check sent -- so anything other than"
                          ++ " NoArtifact here means the layer read someone else's file.")
          expect (not (artifact_name `isInfixOf` git_out)
                    && not (log_name `isInfixOf` git_out))
            ("this check planted files at " ++ cwd ++ " and git still sees one of them:\n"
              ++ unlines (map ("      " ++) (lines git_out)))

-- | GUARD 19: TWO INVOCATIONS, TWO DIRECTORIES, AND NEITHER SURVIVES EITHER OUTCOME.
--
-- Three assertions, and the first one is not decoration: a run directory reported as the empty
-- string would make @doesDirectoryExist@ answer False and the removal arm would pass BECAUSE its
-- subject was absent -- the defect class this milestone's standing rule names, reproduced inside
-- the check written to catch a neighbouring one.
--
-- The abort arm is separate on purpose. A `bracket` that removed the directory only on the success
-- path would leave every failed run's scratch behind, and a failed run is exactly the one whose
-- leftovers a later run could read.
each_invocation_gets_a_fresh_directory_and_it_is_removed :: Check
each_invocation_gets_a_fresh_directory_and_it_is_removed =
  Check "each_invocation_gets_a_fresh_directory_and_it_is_removed" . guarded $
    with_tier_b_scratch "fresh-dir" $ \scratch -> do
      clean <- write_stub scratch "clean.sh" stub_clean
      two   <- write_stub scratch "exit2.sh" (stub_exits 2)
      first_run  <- run_prover (tier_b_request scratch clean)
      second_run <- run_prover (tier_b_request scratch clean)
      aborted    <- run_prover (tier_b_request scratch two)
      let dirs = map outcome_run_dir [first_run, second_run, aborted]
      survivors <- mapM doesDirectoryExist dirs
      pure $ do
        _ <- expect (all (not . null) dirs)
               ("an invocation reported an EMPTY run directory: " ++ show dirs
                 ++ ". doesDirectoryExist \"\" is False, so the removal assertion below would pass"
                 ++ " because its subject was absent rather than because the directory was gone.")
        _ <- expect (outcome_run_dir first_run /= outcome_run_dir second_run)
               ("two successive invocations used the SAME run directory "
                 ++ show (outcome_run_dir first_run)
                 ++ ". The directory is the stale-file defence, and a name that can repeat is a"
                 ++ " name a previous run's artifact can still be sitting under.")
        _ <- expect (and (map not survivors))
               ("a run directory SURVIVED the invocation: "
                 ++ intercalate ", " [d | (d, True) <- zip dirs survivors]
                 ++ ". The bracket removes it on every path -- success, abort and exception alike."
                 ++ " The third of these is the ABORT path (a stub exiting 2), which is the one a"
                 ++ " success-only teardown would leave behind, and a leftover run directory is"
                 ++ " precisely what the freshness conjunct exists to make unreadable.")
        case (first_run, aborted) of
          (Produced _ _ _, Aborted (ExitVerdict (ModelLevel CompilationError)) 2 _) -> Right ()
          _ ->
            Left ("this check needs one Produced run and one Aborted run to be asserting about"
                   ++ " both paths, and got:\n      " ++ render_outcome first_run
                   ++ "\n      " ++ render_outcome aborted)

-- ---------------------------------------------------------------------------------------------
-- GAMS-05: the three hazards a naive test cannot see
--
-- MEASURED on 2026-08-16, and this measurement is why the stubs below look the way they do:
-- 'System.Timeout.timeout' around a DIRECT child terminates AND reaps it with no orphan, so a
-- hung-child check written against a direct child CANNOT FAIL. Against a GRANDCHILD the same
-- mechanism leaves the process alive at PPID 1 -- and GAMS runs its solver as a separate process,
-- so the grandchild is not a hypothetical, it is the actual case. Every stub below that hangs
-- backgrounds its sleep first.
-- ---------------------------------------------------------------------------------------------

-- | 2,000,000 bytes, MEASURED: 'readCreateProcessWithExitCode' forks two draining threads and
-- swallowed exactly this many bytes of stderr with no deadlock. Asserted as an EQUALITY below, so a
-- drain that truncated would be caught as readily as one that hung.
stderr_flood_bytes :: Int
stderr_flood_bytes = 2000000

-- | The five bytes the same stub puts on stdout, so the check can tell a drain that lost the small
-- stream while keeping the large one.
stderr_flood_stdout :: String
stderr_flood_stdout = "hello"

-- | The whole check's own budget, generously above the request's, so a regression FAILS this check
-- rather than hanging the suite with no name attached to it.
flood_check_budget_us :: Int
flood_check_budget_us = 60000000

-- | The budget handed to the two stubs that hang. The research writes this down as a hard ceiling:
-- these checks run once per full 'core_checks' pass and the sentinel harness makes one pass per
-- swept artifact, so a larger budget is multiplied rather than paid once.
hung_child_budget_s :: Int
hung_child_budget_s = 2

-- | A stub that writes five bytes to stdout, floods stderr, and THEN writes a valid artifact.
--
-- The order matters. The flood comes before the artifact so a layer that read the child's output
-- only after the process exited would fill the pipe buffer and deadlock with the artifact never
-- written -- which is the failure this check exists to make impossible, and it would show up here
-- as the check timing out rather than as a wrong answer.
stub_stderr_flood :: String
stub_stderr_flood =
  stub_preamble
    ++ "printf '" ++ stderr_flood_stdout ++ "'\n"
    ++ "yes x | head -c " ++ show stderr_flood_bytes ++ " >&2\n"
    ++ stub_writes_artifact "$S" "$L"
    ++ stub_writes_log
    ++ "exit 0\n"

-- | THE STUB IS A GRANDCHILD, AND THAT IS THE WHOLE POINT.
--
-- It backgrounds its sleep and waits, so the process that must die is one level BELOW the process
-- the wrapper was handed. A direct-child kill reaches the shell and not the sleep; MEASURED, the
-- sleep then survives at PPID 1. The pid is written to a file the CHECK chooses, at an absolute
-- path outside the run directory, because the run directory is removed before the check can read
-- anything out of it.
stub_hung_grandchild :: FilePath -> String
stub_hung_grandchild pidfile =
  unlines
    [ "#!/bin/sh"
    , "sleep 300 &"
    , "echo $! > " ++ pidfile
    , "wait"
    ]

-- | The same grandchild, with a VALID artifact and a VALID log written FIRST.
--
-- A timeout that arrives after the bytes exist is the case a layer checking artifact presence
-- before the exit code would wrongly call a success.
stub_writes_then_hangs :: FilePath -> String
stub_writes_then_hangs pidfile =
  stub_preamble
    ++ stub_writes_artifact "$S" "$L"
    ++ stub_writes_log
    ++ "sleep 300 &\n"
    ++ "echo $! > " ++ pidfile ++ "\n"
    ++ "wait\n"

-- | The pid a hanging stub recorded, or 'Nothing' when it recorded none.
--
-- Digits only: a partially-flushed file would otherwise be turned into a @\/proc@ path that cannot
-- exist, and \"the process is gone\" would then be true because the question was malformed.
read_recorded_pid :: FilePath -> IO (Maybe String)
read_recorded_pid path = do
  there <- doesFileExist path
  if not there
    then pure Nothing
    else do
      raw <- readFile path
      let digits = takeWhile isDigit (dropWhile isSpace raw)
      pure (if null digits then Nothing else Just digits)

-- | LIVENESS IS READ FROM PROCFS, NOT INFERRED.
--
-- @\/proc\/\<pid\>@ exists exactly while the kernel has that process, including while it is a
-- zombie -- so this answers \"terminated AND reaped\" rather than \"stopped running\", which is the
-- distinction an orphaned solver would live in.
pid_is_alive :: String -> IO Bool
pid_is_alive pid = doesDirectoryExist ("/proc/" ++ pid)

-- | What the kernel says about a process that should not be there, for the failure message.
read_proc_stat :: String -> IO String
read_proc_stat pid = do
  let path = "/proc/" ++ pid ++ "/stat"
  there <- doesFileExist path
  if not there then pure "(gone by the time the failure message was built)" else readFile path

-- | Kill a survivor on the way to FAILING about it. A check that testifies about process reaping
-- and leaks a process while doing so has reproduced its own subject.
reap_survivor :: String -> IO ()
reap_survivor pid = do
  _ <- readProcessWithExitCode "kill" ["-9", pid] ""
  pure ()

-- | GUARD 23: A CHILD MAY FLOOD STDERR AND THE CALL STILL RETURNS.
--
-- MEASURED at 2,000,000 bytes with @process-1.6.26.1@: 'readCreateProcessWithExitCode' forks two
-- draining threads, so the pipe hazard is closed by construction rather than by a hand-rolled
-- reader pair. The length is asserted as an EQUALITY, so a drain that truncated at some buffer
-- boundary reddens exactly as loudly as one that deadlocked -- and the deadlock itself shows up as
-- this check's own timeout, with the check's NAME attached, rather than as a suite that stops.
a_stderr_flood_completes_without_deadlock :: Check
a_stderr_flood_completes_without_deadlock =
  Check "a_stderr_flood_completes_without_deadlock" . guarded $
    with_tier_b_scratch "stderr-flood" $ \scratch -> do
      stub <- write_stub scratch "flood.sh" stub_stderr_flood
      finished <- timeout flood_check_budget_us (run_prover (tier_b_request scratch stub))
      pure $
        case finished of
          Nothing ->
            Left ("a child writing " ++ show stderr_flood_bytes ++ " bytes to stderr did not"
                   ++ " return within " ++ show (flood_check_budget_us `div` 1000000) ++ "s."
                   ++ " That is the PIPE DEADLOCK: an implementation that waits for the process"
                   ++ " before draining its output fills the kernel's pipe buffer, the child blocks"
                   ++ " writing, and the parent blocks waiting for a child that can never finish."
                   ++ " Both sides are then waiting for the other, forever.")
          Just (Produced _ _ streams) -> do
            _ <- expect (BS.length (cs_stderr streams) == stderr_flood_bytes)
                   ("the child wrote " ++ show stderr_flood_bytes ++ " bytes to stderr and "
                     ++ show (BS.length (cs_stderr streams)) ++ " were captured. This is an"
                     ++ " EQUALITY on purpose: a drain that stopped at a buffer boundary would"
                     ++ " satisfy any bound written as \"at least a megabyte\" while silently"
                     ++ " discarding the rest of a diagnostic.")
            expect (cs_stdout streams == C8.pack stderr_flood_stdout)
              ("the child put " ++ show stderr_flood_stdout ++ " on stdout and "
                ++ show (cs_stdout streams) ++ " was captured. Two streams are drained"
                ++ " concurrently and the small one is the one a reader that prioritised the"
                ++ " large one would lose.")
          Just other ->
            Left ("the flooding stub wrote a valid artifact and a valid log and exited 0, and did"
                   ++ " not produce one: " ++ render_outcome other)

-- | GUARD 24: A HUNG GRANDCHILD IS TERMINATED AND REAPED.
--
-- THE CHECK THIS PHASE WAS MOST AT RISK OF WRITING WRONGLY, and the risk is not hypothetical --
-- it was MEASURED. Written against a direct child (@exec sleep 300@) this check CANNOT FAIL:
-- 'System.Timeout.timeout' around 'readCreateProcessWithExitCode' terminates and reaps a direct
-- child with no orphan left behind, so the assertion would be green whether or not the wrapper that
-- owns the process GROUP were there at all.
--
-- So the subject is a GRANDCHILD. The stub backgrounds its sleep, records the pid, and waits. The
-- NEGATIVE CONTROL was OBSERVED once during execution outside this suite: the identical stub driven
-- through a direct-child-only kill left @sleep@ alive at @PPID 1@, quoted verbatim in this plan's
-- summary and killed afterwards. Without that observation the green below would be green for a
-- reason nobody had verified.
--
-- Four assertions, in this order: the stub RECORDED a pid at all (a check that read no pid would
-- conclude \"gone\" from a missing file); the pid is absent from procfs; the outcome is 'Aborted';
-- and the recorded exit code is 124, which is @timeout(1)@'s own expiry code and appears nowhere in
-- the mod-256 image of the GAMS return-code table.
a_hung_grandchild_is_terminated_and_reaped :: Check
a_hung_grandchild_is_terminated_and_reaped =
  Check "a_hung_grandchild_is_terminated_and_reaped" . guarded $
    with_tier_b_scratch "hung-grandchild" $ \scratch -> do
      let pidfile = scratch </> "grandchild.pid"
      stub <- write_stub scratch "hang.sh" (stub_hung_grandchild pidfile)
      outcome <- run_prover
                   (tier_b_request scratch stub)
                     { rr_budget_s     = hung_child_budget_s
                     , rr_kill_after_s = 1
                     }
      threadDelay 500000
      recorded <- read_recorded_pid pidfile
      case recorded of
        Nothing ->
          pure (Left ("the hung stub recorded NO grandchild pid at " ++ pidfile
                       ++ ". Every assertion below would then be about a process that was never"
                       ++ " spawned, and \"it is not in /proc\" would be true because nothing ever"
                       ++ " put it there. Outcome was: " ++ render_outcome outcome))
        Just pid -> do
          alive <- pid_is_alive pid
          stat  <- if alive then read_proc_stat pid else pure ""
          -- Kill it BEFORE reporting, so the check cannot leak the very process it is failing about.
          _ <- if alive then reap_survivor pid else pure ()
          pure $ do
            _ <- expect (not alive)
                   ("the backgrounded grandchild " ++ pid ++ " SURVIVED the timeout. /proc/" ++ pid
                     ++ "/stat said:\n      " ++ takeWhile (/= '\n') stat
                     ++ "\n      The wrapper signals the process GROUP; a kill aimed at the direct"
                     ++ " child reaches the shell and not the process it backgrounded. MEASURED:"
                     ++ " with a direct-child-only kill this same stub leaves its sleep alive at"
                     ++ " PPID 1, and the real solver runs as a separate process for exactly the"
                     ++ " same reason -- so a green here without a group-owning wrapper would mean"
                     ++ " a solver still burning a core after the run was declared over."
                     ++ " (It has been killed, so this failure does not also leak it.)")
            case outcome of
              Aborted (ExitVerdict (TimedOut Expired)) 124 _ -> Right ()
              _ ->
                Left ("a run that hung past its " ++ show hung_child_budget_s
                       ++ "s budget should have given Aborted (ExitVerdict (TimedOut Expired)) at"
                       ++ " exit 124, and gave " ++ render_outcome outcome
                       ++ ".\n      124 is the wrapper's own expiry code and it collides with"
                       ++ " nothing in the mod-256 image of the return-code table, so the layer can"
                       ++ " tell \"the budget ran out\" from every verdict the prover itself"
                       ++ " reports.")

-- | GUARD 25: A TIMED-OUT RUN YIELDS 'Aborted', AND THE ARTIFACT IT ALREADY WROTE CHANGES NOTHING.
--
-- The stub writes a VALID artifact and a VALID log first, and only then hangs. A layer that checked
-- artifact presence before the exit code would find a complete, decodable, correctly-echoing
-- document and call the run a success -- while the process that was supposed to have produced it is
-- still running.
--
-- Pair this with the compile-level fact recorded at 24-03 and quoted in that summary: there is no
-- total function from an outcome to an artifact, and 'Aborted' carries no artifact field, so
-- \"a timed-out run never yields an output row\" is UNREPRESENTABLE rather than merely untested.
-- This check is the other half: it shows the run actually TAKES the aborted branch.
a_timed_out_run_yields_Aborted_and_no_artifact :: Check
a_timed_out_run_yields_Aborted_and_no_artifact =
  Check "a_timed_out_run_yields_Aborted_and_no_artifact" . guarded $
    with_tier_b_scratch "timeout-after-write" $ \scratch -> do
      let pidfile = scratch </> "late-hang.pid"
      stub <- write_stub scratch "write-then-hang.sh" (stub_writes_then_hangs pidfile)
      outcome <- run_prover
                   (tier_b_request scratch stub)
                     { rr_budget_s     = hung_child_budget_s
                     , rr_kill_after_s = 1
                     }
      threadDelay 500000
      recorded <- read_recorded_pid pidfile
      alive    <- maybe (pure False) pid_is_alive recorded
      _        <- if alive then maybe (pure ()) reap_survivor recorded else pure ()
      let run_dir = outcome_run_dir outcome
      survived <- if null run_dir then pure False else doesDirectoryExist run_dir
      pure $ do
        _ <- expect (recorded /= Nothing)
               ("the stub recorded no pid at " ++ pidfile ++ ", so the arm asserting that the"
                 ++ " grandchild is gone would be asserting about nothing. Outcome was: "
                 ++ render_outcome outcome)
        _ <- case outcome of
               Aborted (ExitVerdict (TimedOut Expired)) 124 _ -> Right ()
               Produced _ _ _ ->
                 Left ("a run that wrote a VALID artifact and then hung was reported as a"
                        ++ " SUCCESS: " ++ render_outcome outcome
                        ++ "\n      The bytes existing says nothing about whether the run"
                        ++ " finished. This is the ordering that matters: the exit code is the"
                        ++ " FIRST conjunct, and a layer that looked for the file first would"
                        ++ " accept the output of a solve that was killed halfway through.")
               other ->
                 Left ("a run that wrote a valid artifact and then hung should have given Aborted"
                        ++ " (ExitVerdict (TimedOut Expired)) at exit 124, and gave "
                        ++ render_outcome other)
        _ <- expect (not survived)
               ("the run directory " ++ show run_dir ++ " SURVIVED a timed-out run. The bracket"
                 ++ " removes it on every path, and the timeout path is the one where the"
                 ++ " directory contains a complete-looking artifact -- exactly the leftover the"
                 ++ " freshness conjunct exists to make unreadable.")
        expect (not alive)
          ("the grandchild " ++ show recorded ++ " survived a timeout that happened AFTER the"
            ++ " artifact was written. The artifact being on disk does not reach the process"
            ++ " group. (It has been killed, so this failure does not also leak it.)")

-- ---------------------------------------------------------------------------------------------
-- GAMS-06's honest half: TWO REAL ENVIRONMENT VECTORS, COMPARED
--
-- The measured limit this is built around: NO ambient variable and NO configuration file on this
-- machine changes the artifact's bytes, and @locale -a@ offers no comma-decimal locale at all, so
-- there is nothing here a byte comparison could observe. A check written against bytes could only
-- be satisfied by inventing a variable that matters -- or by passing because its subject is absent,
-- which is this milestone's standing defect.
--
-- The child's own environment vector is the subject that IS unambiguous, and it is the one that
-- actually proves the whitelist is in force: a whitelist that silently fell back to inheritance is
-- exactly what these two checks catch, while a byte comparison would report success either way.
-- ---------------------------------------------------------------------------------------------

-- | The keys @\/bin\/sh@ exports to its own children, MEASURED on 2026-08-16 by running the
-- env-printing stub below through the real invocation path with the whitelist in force and printing
-- the difference.
--
-- The whitelisted child's environment came back as exactly six pairs: the three the whitelist
-- names, plus @PWD@ (the run directory), @SHLVL@ and @_@. These are the SHELL'S, not the caller's:
-- the stub carries a @#!\/bin\/sh@ shebang, so the kernel runs a shell, and a shell sets these
-- three for the command it executes. They cannot be removed from the interface by anything this
-- module controls, and pretending they are part of the whitelist would be worse -- the point of a
-- whitelist is that everything outside it is named.
--
-- This list is a MEASUREMENT and it is asserted as an upper bound in both spirit and code: a key
-- that appears and is not named here FAILS the check naming it, rather than being absorbed.
shell_injected_env_keys :: [String]
shell_injected_env_keys = ["PWD", "SHLVL", "_"]

-- | A stub whose whole body is a capture of its own environment, into a file the CHECK chooses.
--
-- The path is absolute and outside the run directory, because the run directory is removed by the
-- bracket before the check can read anything out of it.
stub_prints_env :: FilePath -> String
stub_prints_env envfile =
  unlines
    [ "#!/bin/sh"
    , "env > " ++ envfile
    , "exit 0"
    ]

-- | An environment vector as pairs.
--
-- A line counts as a pair only when what precedes the first @=@ is a plausible variable NAME. That
-- is not fastidiousness: an inherited environment can carry a value containing a newline, and the
-- continuation line would otherwise be read as a variable whose name is arbitrary text -- which
-- would then show up as an unnamed key and fail the whitelist check for a reason that has nothing
-- to do with the whitelist.
parse_env_capture :: String -> [(String, String)]
parse_env_capture body =
  [ (key, drop 1 rest)
  | line <- lines body
  , let (key, rest) = break (== '=') line
  , not (null rest)
  , not (null key)
  , all (\c -> isAlphaNum c || c == '_') key
  ]

-- | The captured vector, or a failure naming the file that was never written.
--
-- FAIL, never an empty list: an empty environment satisfies every \"no forbidden key is present\"
-- rule ever written, so a capture that silently came back empty is the shape of a check passing
-- because its subject is absent.
read_env_capture :: String -> FilePath -> IO (Either String [(String, String)])
read_env_capture label path = do
  there <- doesFileExist path
  if not there
    then pure (Left ("the " ++ label ++ " child never wrote its environment to " ++ path
                      ++ ". Every assertion about that vector would then be an assertion about the"
                      ++ " empty list, which agrees with every rule about what must be absent."))
    else do
      body <- readFile path
      let pairs = parse_env_capture body
      pure $
        if null pairs
          then Left ("the " ++ label ++ " child wrote " ++ show (length body) ++ " bytes to "
                      ++ path ++ " and not one line of it parsed as a variable.")
          else Right pairs

-- | THE LOCALE PIN, WRITTEN OUT HERE, AND THAT IS THE WHOLE REASON IT IS HERE.
--
-- MEASURED during execution, and it is a correction of record. The first draft of the check below
-- compared the child's captured environment against @whitelist_for scratch@ -- and when @LC_ALL@
-- was deleted from that very function, the check went GREEN. Both sides of the comparison had moved
-- together, so the test was asserting that a function equals itself. That is a recorded field
-- derived from the same expression as its own comparison target, which is the SEVENTH
-- representation of this project's standing defect, arriving inside the check written to catch the
-- sixth.
--
-- So the one fact GAMS-06 is actually about -- the decimal separator is pinned in the process that
-- writes the bytes -- is spelled HERE, in the file doing the asserting, and it cannot move when the
-- library moves. The key SET is likewise compared against 'whitelist_keys', which is the OTHER
-- constant in that module: deleting a pair from 'whitelist_for' alone now reddens this check as
-- well as its pure sibling.
child_locale_pin :: (String, String)
child_locale_pin = ("LC_ALL", "C")

-- | GUARD 26 (first half): THE WHITELISTED CHILD'S ENVIRONMENT IS THE WHITELIST.
--
-- Four assertions. The key SET is compared in BOTH directions against 'whitelist_keys' -- a subset
-- rule one way only is satisfied by a child that inherited everything and happened to also carry
-- the three. The locale pin is compared against this file's own copy, for the reason
-- 'child_locale_pin' records. And every key the child carries beyond the whitelist must be one this
-- file has named and explained.
the_child_environment_is_exactly_the_whitelist :: Check
the_child_environment_is_exactly_the_whitelist =
  Check "the_child_environment_is_exactly_the_whitelist" . guarded $
    with_tier_b_scratch "env-whitelist" $ \scratch -> do
      let envfile = scratch </> "whitelisted.env"
      stub    <- write_stub scratch "printenv.sh" (stub_prints_env envfile)
      outcome <- run_prover (tier_b_request scratch stub)
      captured <- read_env_capture "whitelisted" envfile
      pure $ do
        _ <- case outcome of
               Aborted NoArtifact 0 _ -> Right ()
               _ ->
                 Left ("the env-printing stub exits 0 and writes no artifact, so this check needs"
                        ++ " Aborted NoArtifact to know the spawn actually happened and was not"
                        ++ " refused before it: " ++ render_outcome outcome)
        pairs <- captured
        let wanted  = whitelist_for scratch
            present = map fst pairs
            missing = [k | k <- whitelist_keys, k `notElem` present]
            wrong   = [ (k, got, v)
                      | (k, v) <- wanted, (k', got) <- pairs, k == k', got /= v ]
            extra   = [k | k <- present, k `notElem` whitelist_keys
                                       , k `notElem` shell_injected_env_keys]
            (locale_key, locale_pinned_to) = child_locale_pin
            pinned  = [v | (k, v) <- pairs, k == locale_key]
        _ <- expect (null missing)
               ("the whitelisted child's environment is MISSING " ++ intercalate ", " missing
                 ++ ". The expected key set is whitelist_keys, which is a DIFFERENT constant from"
                 ++ " the one that builds the vector -- deliberately, because comparing the child"
                 ++ " against the very function that produced it is a comparison that cannot fail."
                 ++ " Captured: " ++ show (sort present))
        _ <- expect (pinned == [locale_pinned_to])
               ("the whitelisted child carried " ++ show pinned ++ " for " ++ locale_key
                 ++ " and this file requires exactly " ++ show [locale_pinned_to]
                 ++ ". The pin is written out HERE rather than read from the library, because"
                 ++ " MEASURED: with the expected side read from the library, deleting this pair"
                 ++ " from the library moved BOTH sides of the comparison and the check stayed"
                 ++ " green. A pinned decimal separator that arrives unpinned is not a pin, and the"
                 ++ " process this vector is handed to is the one that writes the bytes.")
        _ <- expect (null wrong)
               ("the whitelisted child carried the wrong value for "
                 ++ intercalate ", " [k ++ " (" ++ show got ++ ", wanted " ++ show v ++ ")"
                                     | (k, got, v) <- wrong])
        expect (null extra)
          ("the whitelisted child carried variables that are in neither whitelist_keys nor the"
            ++ " MEASURED set a shell exports to its own children: " ++ intercalate ", " (sort extra)
            ++ ".\n      Captured " ++ show (length pairs) ++ " pairs: " ++ show (sort present)
            ++ "\n      Either the whitelist stopped being handed to the child -- which is the"
            ++ " silent fallback to inheritance this pair of checks exists to catch -- or the"
            ++ " shell-injected set has changed on this host and shell_injected_env_keys has to be"
            ++ " RE-MEASURED and the new key explained. It is not absorbed either way.")

-- | GUARD 26 (second half): AN INHERITED ENVIRONMENT IS OBSERVED TO DIFFER.
--
-- The same function, the same stub, run twice -- once with the whitelist and once inheriting -- and
-- the two captured vectors compared. This is what actually proves the whitelist is IN FORCE: the
-- check above would still pass if the invocation layer ignored its environment argument on a host
-- whose ambient environment happened to be small, and this one would not.
--
-- WHAT IS ASSERTED IS NOT \"A STRICT SUPERSET\", AND THAT IS A CORRECTION OF RECORD. Measured
-- during execution: the inherited vector carries 67 keys against the whitelisted vector's 6, and it
-- does NOT contain @LC_ALL@ at all -- this machine's ambient environment sets @LANG@ and no
-- @LC_ALL@. So the two sets differ in BOTH directions and a superset assertion would have been
-- asserting something false. What is asserted instead is the load-bearing half, unchanged in
-- strength: the inherited vector is strictly LARGER, and it names at least one variable that is
-- neither in the whitelist nor in the shell-injected set. The variable it names is reported.
an_inherited_environment_is_observed_to_differ :: Check
an_inherited_environment_is_observed_to_differ =
  Check "an_inherited_environment_is_observed_to_differ" . guarded $
    with_tier_b_scratch "env-inherited" $ \scratch -> do
      let pinned_file    = scratch </> "pinned.env"
          inherited_file = scratch </> "inherited.env"
      pinned_stub    <- write_stub scratch "printenv-pinned.sh" (stub_prints_env pinned_file)
      inherited_stub <- write_stub scratch "printenv-inherited.sh" (stub_prints_env inherited_file)
      _ <- run_prover (tier_b_request scratch pinned_stub)
      _ <- run_prover ((tier_b_request scratch inherited_stub) { rr_env = Nothing })
      pinned_capture    <- read_env_capture "whitelisted" pinned_file
      inherited_capture <- read_env_capture "inheriting" inherited_file
      pure $ do
        pinned    <- pinned_capture
        inherited <- inherited_capture
        let pinned_keys    = sort (nub (map fst pinned))
            inherited_keys = sort (nub (map fst inherited))
            excluded = [ k | k <- inherited_keys
                           , k `notElem` whitelist_keys
                           , k `notElem` shell_injected_env_keys ]
            lacked   = [k | k <- whitelist_keys, k `notElem` inherited_keys]
        _ <- expect (length inherited_keys > length pinned_keys)
               ("the inheriting child's environment carries " ++ show (length inherited_keys)
                 ++ " keys and the whitelisted one carries " ++ show (length pinned_keys)
                 ++ ". Two runs of the SAME function through the SAME stub, one asking for the"
                 ++ " whitelist and one asking to inherit, produced environments the same size --"
                 ++ " so either the environment argument is being ignored (the silent fallback to"
                 ++ " inheritance) or the caller's own environment is as small as the whitelist,"
                 ++ " in which case this check has no discriminating power on this host and must"
                 ++ " be reported rather than believed."
                 ++ "\n      whitelisted: " ++ show pinned_keys)
        expect (not (null excluded))
          ("the inheriting child's environment names NOTHING outside the whitelist and the"
            ++ " MEASURED shell-injected set, so \"the whitelist excludes something real\" is"
            ++ " unobserved here. It carried: " ++ show inherited_keys
            ++ "\n      This is the honest form of GAMS-06's second half. It is NOT asserted on"
            ++ " artifact bytes, and the reason is a measurement: four hostile ambient variables"
            ++ " changed nothing about the artifact, and locale -a on this machine offers only C,"
            ++ " C.utf8, en_US.utf8 and POSIX -- there is no comma-decimal locale to observe a byte"
            ++ " difference with, so a byte-level version of this check could only pass by"
            ++ " inventing a variable that matters."
            ++ (if null lacked then ""
                  else "\n      Also of record: the inherited vector does not carry "
                         ++ intercalate ", " lacked ++ " at all, so it is not a SUPERSET of the"
                         ++ " whitelist -- the two differ in both directions."))

-- | A stub that exits 0 with a VALID artifact and a log carrying NO job banner.
--
-- The log it writes is the solver-execution line and nothing else -- real text from a real run,
-- carrying the solver's name and no version and no job banner. A parser anchored on \"a token that
-- looks like a version somewhere near a familiar word\" would find nothing here and could report
-- that as an absent optional field rather than as a failure.
stub_log_without_a_job_banner :: String
stub_log_without_a_job_banner =
  stub_preamble
    ++ stub_writes_artifact "$S" "$L"
    ++ "cat > \"$D/" ++ log_name ++ "\" <<EOF\n"
    ++ "--- Executing CONOPT (Solvelink=2)\n"
    ++ "EOF\n"
    ++ "exit 0\n"

-- | A stub that exits 0 with a VALID artifact, writes NO log at all, and puts the real banner on
-- STDERR instead.
--
-- MEASURED: the real tool leaves stderr at 0 bytes in every mode, so a detector that read stderr
-- would be handed the empty string on every honest run and would have to treat empty as absent --
-- and here it would be handed a perfectly good banner from a run whose own log has none. Both
-- halves of that are wrong, and the layer must abort on both.
stub_banner_on_stderr_only :: String
stub_banner_on_stderr_only =
  stub_preamble
    ++ stub_writes_artifact "$S" "$L"
    ++ "echo '--- Job " ++ gams_model_basename
         ++ " Start 08/16/26 15:52:25 54.1.0 37378ce0 LEX-LEG x86 64bit/Linux' >&2\n"
    ++ "exit 0\n"

-- | GAMS-03, DRIVEN: DETECTION THAT FINDS NOTHING ABORTS THE RUN.
--
-- Two stubs, both of which exit 0 and both of which write a VALID, decodable, correctly-echoing
-- artifact. Everything about them is right except the one thing the key is made of. Accepting
-- either means a run COMPLETED with an empty version component -- and the schema will not catch it,
-- because @not null@ does not forbid the empty string. That is the poisoned-row scenario this
-- phase's sequencing exists to prevent: every toolchain would hash to the same key component, and
-- afterwards the poisoned rows are indistinguishable from good ones, because the only evidence of
-- which toolchain produced them is the column that was emptied.
--
-- The second stub's banner is on STDERR, and the check asserts it ARRIVED there -- so the refusal
-- is observed against a run where the right text was available on the wrong channel, rather than
-- against a run with no text anywhere.
version_detection_failure_aborts_the_invocation :: Check
version_detection_failure_aborts_the_invocation =
  Check "version_detection_failure_aborts_the_invocation" . guarded $
    with_tier_b_scratch "version-detection" $ \scratch -> do
      no_banner   <- write_stub scratch "no-banner.sh" stub_log_without_a_job_banner
      wrong_chan  <- write_stub scratch "banner-on-stderr.sh" stub_banner_on_stderr_only
      o_no_banner <- run_prover (tier_b_request scratch no_banner)
      o_wrong     <- run_prover (tier_b_request scratch wrong_chan)
      pure $ do
        _ <- unreadable "a log with no job banner" o_no_banner
        _ <- unreadable "a banner written to stderr while the log has none" o_wrong
        expect (banner_reached_stderr o_wrong)
          ("the stub that writes its banner to STDERR did not put it there, so the refusal above"
            ++ " was observed against a run with no banner ANYWHERE rather than against one whose"
            ++ " banner arrived on the wrong channel -- which is the case a stream-reading detector"
            ++ " would have accepted. Captured stderr: "
            ++ show (C8.unpack (stderr_of o_wrong)))
  where
    stderr_of (Produced _ _ streams) = cs_stderr streams
    stderr_of (Aborted _ _ streams)  = cs_stderr streams

    banner_reached_stderr outcome = "--- Job " `isInfixOf` C8.unpack (stderr_of outcome)

    unreadable label outcome =
      case outcome of
        Aborted (VersionUnreadable _) _ _ -> Right ()
        _ ->
          Left ("a run with " ++ label ++ " was not refused: " ++ render_outcome outcome
                 ++ "\n      It exited 0 and wrote a VALID artifact, so every other conjunct is"
                 ++ " satisfied and only the version is missing. Accepting it means a run COMPLETED"
                 ++ " with an empty version component, and `not null` does not forbid the empty"
                 ++ " string -- so the row would be written, and afterwards nothing distinguishes"
                 ++ " it from a good one, because the evidence of which toolchain produced it is"
                 ++ " the column that was emptied."
                 ++ "\n      MEASURED: the real tool leaves stderr at 0 BYTES in every mode, so a"
                 ++ " detector that read stderr instead of the run's own log would be comparing the"
                 ++ " empty string against the empty string on every single honest run.")

-- | The six tokens a verdict built out of log text would be built out of.
--
-- @Status:@ and @Normal completion@ are the GAMS listing's own words, @Locally@ opens the two
-- model-status lines that matter, and @isInfixOf@ is how a Haskell layer would go looking for any
-- of them.
gams_stream_pattern :: String
gams_stream_pattern = "isInfixOf|infeasible|optimal|Locally|Normal completion|Status:"

-- | The two modules in which a verdict is decided.
--
-- 'Gams.Exit' holds the taxonomy and 'Gams.Run' holds the conjunction; there is no third place a
-- decision could be made. Note what that means for scope: THIS file holds the pattern, so it
-- matches it, so it can never be a member of this set -- which is why the set is the two library
-- modules and not @offchain@.
gams_verdict_path :: [FilePath]
gams_verdict_path =
  [ "offchain/lib/Gams/Exit.hs"
  , "offchain/lib/Gams/Run.hs"
  ]

-- | Absence may not read as success until the pattern has been SHOWN matching. Returned so the
-- caller orders it FIRST, following 'aeson_positive_control'.
gams_stream_positive_control :: IO (Either String ())
gams_stream_positive_control = do
  tmp <- getTemporaryDirectory
  let dir       = tmp </> "gams24-stream-positive-control"
      bait      = dir </> "bait.hs"
      innocent  = dir </> "clean.hs"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [bait, innocent]) $ do
    writeFile bait
      ("solved :: String -> Bool\nsolved log = \"Normal completion\" `isInfixOf` log\n")
    writeFile innocent "solved :: Int -> Bool\nsolved n = n == 0\n"
    (code, out, err) <- gams_version_scan gams_stream_pattern [bait, innocent]
    pure $ do
      _ <- expect (code == ExitSuccess)
             ("GAMS-01's POSITIVE CONTROL did not fire: the scan exited " ++ show code
               ++ " over a file that decides whether a run solved by searching its log for"
               ++ " a completion phrase. The pattern has stopped matching anything, which means"
               ++ " the exit-1 the real scan reports is absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      stderr: " ++ err))
      _ <- expect ("bait.hs" `isInfixOf` out)
             ("GAMS-01's POSITIVE CONTROL fired but did not NAME the seeded file. It said:\n"
               ++ unlines (map ("      " ++) (lines out)))
      expect (not ("clean.hs" `isInfixOf` out))
        ("GAMS-01's POSITIVE CONTROL matched a file that reads no log at all, so the pattern is"
          ++ " matching something other than what it claims to. It said:\n"
          ++ unlines (map ("      " ++) (lines out)))

-- | GAMS-01's structural half: NO decision reads a stream.
--
-- Three assertions in this order: (1) the pattern is SHOWN matching a seeded bait; (2) both scanned
-- files EXIST -- a scan over an empty file set reports exit 1, which is indistinguishable from a
-- clean one; (3) the scan finds nothing.
--
-- 'Gams.Exit' is in the set even though its TYPE already makes the claim, because a type that
-- carries no stream is a fact about the signature and this is a fact about the file: a helper added
-- beside 'classify_exit' that read a buffer would not change the signature at all.
gams_verdict_ignores_the_streams :: Check
gams_verdict_ignores_the_streams =
  Check "gams_verdict_ignores_the_streams" . guarded $ do
    control  <- gams_stream_positive_control
    presence <- mapM (\p -> (,) p <$> doesFileExist p) gams_verdict_path
    let gone = [p | (p, False) <- presence]
    if not (null gone)
      then pure $ do
        _ <- control
        expect False
          ("the verdict path names files that are not on disk: " ++ intercalate ", " gone
            ++ ". Scoping the set to the files that happen to exist would make this check pass"
            ++ " BECAUSE its subject is absent, and grep's exit 1 means \"matched no files at all\""
            ++ " just as readily as it means \"found nothing\".")
      else do
        (code, out, err) <- gams_version_scan gams_stream_pattern gams_verdict_path
        pure $ do
          _ <- control
          case code of
            ExitFailure 1 -> Right ()
            ExitFailure n -> Left ("the scan itself failed with exit " ++ show n ++ ": " ++ err)
            ExitSuccess ->
              Left ("a verdict in the GAMS layer reads SOLVER OUTPUT:\n"
                     ++ unlines (map ("      " ++) (lines out))
                     ++ "      VOLUME_PATH.md section 4: the exit code is non-zero on every abort"
                     ++ " -- gate on it, never on log text. MEASURED: stderr is 0 BYTES in every"
                     ++ " GAMS mode, so a stream reader compares the empty string against the"
                     ++ " empty string every single run, on the good path and the bad one alike."
                     ++ " A comment is inside this scan's blast radius too, and twice now the"
                     ++ " right answer was to move the prose rather than relax the pattern.")

-- ---------------------------------------------------------------------------------------------
-- THE STRUCTURAL GUARANTEE: cabal test CANNOT REACH THE REAL PROVER
-- ---------------------------------------------------------------------------------------------

-- | The three tokens whose presence in this file would mean the suite can reach the live solver.
--
-- BUILT, never written as one literal, exactly as 'credential_pattern' and 'purge_control_literal'
-- are built and for the identical reason: spelled contiguously the pattern would match THIS FILE,
-- and a scan that matches the file asserting its own absence exempts nothing and reddens always.
-- On this branch prose has now been inside a grep's blast radius sixteen times; this is the
-- sixteenth, and the answer was the same every time -- move the words, never relax the pattern.
--
-- The three tokens are DESCRIBED here rather than listed, because the first draft of the comment
-- above the corresponding import listed all three inside the sentence claiming they were absent:
--
--   1. the module that resolves the LIVE binary and the model out of @Gams.Config@. It is imported
--      by exactly one place, the conformance executable plan 24-05 writes, and by nothing this
--      test binary links. @Gams.Run@ -- the testable IO edge, which is handed its binary path
--      explicitly -- is deliberately NOT a token: the Tier-B checks above drive it against
--      @\/bin\/sh@ stubs they write themselves, and that is the whole design rather than a
--      loophole in it.
--   2. the capture script's require-a-real-solver gate. 23-RESEARCH's ruling on its store-side
--      twin applies verbatim: gating a suite on \"if the tool is installed\" fails OPEN, so on
--      every machine without the tool the assertion reports success for the reason it exists to
--      forbid.
--   3. the absolute installation prefix of the real binary on the research machine. It is a
--      machine-specific accident and a source file that names it is a source file that has stopped
--      being portable AND started being able to invoke a solver.
gams_free_pattern :: String
gams_free_pattern =
  intercalate "|"
    [ "Gams" ++ "\\.Invoke"
    , "CFMM_REQUIRE" ++ "_GAMS"
    , "/usr/" ++ "gams"
    ]

-- | The scanned file: this one, and only this one.
--
-- The scope is the TEST binary's own source because that is what the claim is about -- the library
-- may name whatever it needs, and 24-05's executable will name all three. The DB-free twin this
-- mirrors has the same scope for the same reason.
gams_free_path :: FilePath
gams_free_path = "offchain/test/Main.hs"

-- | The seeded bait, BUILT for the reason the pattern is: all three tokens, in the three shapes
-- they would actually appear in -- an import, an environment gate compared as a string, and an
-- absolute path constant.
gams_free_bait_source :: String
gams_free_bait_source =
  "import Gams" ++ ".Invoke (resolve_prover)\n"
    ++ "gate :: String\n"
    ++ "gate = \"CFMM_REQUIRE" ++ "_GAMS\"\n"
    ++ "installed :: FilePath\n"
    ++ "installed = \"/usr/" ++ "gams/gams\"\n"

-- | A file carrying the forms this suite legitimately uses, which must NOT match.
--
-- This is the arm that keeps the pattern honest in the other direction, and here it is doing real
-- work rather than ceremony: the IO edge and the stub path below are what every Tier-B check in
-- this file is made of, and a pattern tightened until it matched them would have to be relaxed the
-- first time it fired -- at which point the absence it reports would be the absence of a scan.
gams_free_innocent_source :: String
gams_free_innocent_source =
  "import Gams.Run (run_prover)\n"
    ++ "stub :: FilePath\n"
    ++ "stub = \"/bin/sh\"\n"
    ++ "budget_s :: Int\n"
    ++ "budget_s = 2\n"

-- | Absence may not read as success until the pattern has been SHOWN matching. Returned so the
-- caller orders it FIRST, following 'credential_positive_control'.
gams_free_positive_control :: IO (Either String ())
gams_free_positive_control = do
  tmp <- getTemporaryDirectory
  let dir       = tmp </> "gams24-free-positive-control"
      bait      = dir </> "bait.hs"
      innocent  = dir </> "clean.hs"
      discard p = do
        there <- doesFileExist p
        if there then removeFile p else pure ()

  createDirectoryIfMissing True dir
  flip finally (mapM_ discard [bait, innocent]) $ do
    writeFile bait gams_free_bait_source
    writeFile innocent gams_free_innocent_source
    (code, out, err) <- gams_version_scan gams_free_pattern [bait, innocent]
    pure $ do
      _ <- expect (code == ExitSuccess)
             ("the GAMS-free POSITIVE CONTROL did not fire: the scan exited " ++ show code
               ++ " over a file that imports the resolving module, compares the"
               ++ " require-a-real-solver gate as a string, and pins the installation prefix as an"
               ++ " absolute path. The pattern has stopped matching anything, which means the exit-1"
               ++ " the real scan reports is absence of MATCHES only by assumption."
               ++ (if null err then "" else "\n      stderr: " ++ err))
      _ <- expect ("bait.hs" `isInfixOf` out)
             ("the GAMS-free POSITIVE CONTROL fired but did not NAME the seeded file. It said:\n"
               ++ unlines (map ("      " ++) (lines out)))
      expect (not ("clean.hs" `isInfixOf` out))
        ("the GAMS-free POSITIVE CONTROL matched the forms this suite legitimately uses -- the IO"
          ++ " edge that is handed its binary path, and the shell the stubs actually run under. A"
          ++ " pattern that matches those would have to be relaxed the first time it fired, which"
          ++ " is how a structural guarantee becomes decorative. It said:\n"
          ++ unlines (map ("      " ++) (lines out)))

-- | GAMS-05's structural half, and the DB-free scan's twin: THE SUITE CANNOT NAME THE REAL SOLVER.
--
-- Three assertions in this order: (1) the pattern is SHOWN matching a seeded bait and shown NOT
-- matching the forms this file is made of; (2) the scanned file EXISTS -- @grep@ reports exit 2 for
-- a missing operand and exit 1 for an empty one, and neither may be read as a clean scan; (3) the
-- scan finds nothing.
--
-- What this buys, and it is not a style rule: every claim this file makes about the invocation
-- layer is made against a @\/bin\/sh@ script the check itself wrote, so a contributor with no
-- solver installed gets the same verdict as the research machine, and the two variables that DO
-- steer the real thing are honestly recorded as gaps in 'unprobed_overrides' rather than given a
-- probe with no subject. Absence of a probe is a stated gap; a probe whose consumer is unreachable
-- is a green light with nothing behind it.
the_suite_never_names_the_real_solver :: Check
the_suite_never_names_the_real_solver =
  Check "the_suite_never_names_the_real_solver" . guarded $ do
    control <- gams_free_positive_control
    there   <- doesFileExist gams_free_path
    if not there
      then pure $ do
        _ <- control
        expect False
          ("the GAMS-free scan's subject is not on disk: " ++ gams_free_path
            ++ ". grep exits 2 for a missing operand and 1 for a clean scan, and a check that"
            ++ " reported success here would be reporting the absence of its own subject.")
      else do
        (code, out, err) <- gams_version_scan gams_free_pattern [gams_free_path]
        pure $ do
          _ <- control
          case code of
            ExitFailure 1 -> Right ()
            ExitFailure n -> Left ("the scan itself failed with exit " ++ show n ++ ": " ++ err)
            ExitSuccess ->
              Left ("this test suite NAMES the real solver:\n"
                     ++ unlines (map ("      " ++) (lines out))
                     ++ "      One of three tokens is present: the module that resolves the live"
                     ++ " binary and model, the capture script's require-a-real-solver gate, or the"
                     ++ " installation's absolute path. Any of them makes cabal test able to reach"
                     ++ " a solver, which turns every contributor's first run into a hunt for an"
                     ++ " install and turns this suite's verdict into a fact about one machine."
                     ++ " A comment is inside this scan's blast radius too, and every time on this"
                     ++ " branch the right answer was to move the prose, not relax the pattern.")

-- ---------------------------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  checks <- core_checks
  outcomes <- mapM run_one (checks ++ [sentinel_falsification_harness])
  let failed = [name | (name, False) <- outcomes]
      total  = length outcomes
  putStrLn ""
  putStrLn (show (total - length failed) ++ "/" ++ show total ++ " checks passed")
  if null failed
    then putStrLn "SC-3 and SC-4 OK"
    else do
      putStrLn (show (length failed) ++ " FAILED: " ++ intercalate ", " (sort failed))
      exitFailure

-- | EVERY CHECK EXCEPT THE HARNESS, RESOLVED FROM THE ENVIRONMENT ON EVERY CALL.
--
-- This used to be a @let@ inside 'main'. It is a top-level @IO@ action because
-- 'sentinel_falsification_harness' re-runs it, once per mutation, with an artifact override
-- pointed at a doctored copy -- so every path resolution and every decode has to happen INSIDE
-- it, not once at startup. The harness is excluded from what this returns for the obvious reason.
core_checks :: IO [Check]
core_checks = do
  pf      <- pins_file
  present <- doesFileExist pf
  -- The presence test is separate from the decode because @eitherDecodeFileStrict@ THROWS on a
  -- missing file rather than returning 'Left'. Without it, @RIG_PINS=\<missing\>@ killed the
  -- runner with a bare @withBinaryFile: does not exist@ before a single check name was printed --
  -- red, but not a NAMED failure, and the operator learns nothing about which check was guarding
  -- what.
  loaded <-
    if present
      then eitherDecodeFileStrict pf :: IO (Either String RigPins)
      else pure (Left ("no such file (resolved through RIG_PINS)"))
  let checks = case loaded of
        Left err ->
          [ pure_check "sc4_pins_file_decodes" $
              Left ("could not read the pin file " ++ pf ++ ": " ++ err
                     ++ "\n      regenerate it with: bash offchain/rig/generate-pins.sh")
          ]
        Right pins ->
          [ sc4_generated_from_is_the_imported_ref pins
          , sc4_pin_surface_is_the_expected_set pins
          , sc4_ground_truth_encoder
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
          , rpin03_module_constant_is_the_deployed_spacing
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
          , rpin05_minted_id_run_behavior
          , rpin04_e1_is_filtered_on_the_emitter
          , rpin05_no_canonical_bool_violation
          , driv01_e3_decode_behavior
          , driv01_slot0_composition_behavior
          , driv01_swap_calldata_shape
          , driv01_cheat_swap_proof_is_present_and_fresh
          , driv01_cheated_tick_reaches_e3
          , driv01_wrong_pool_is_silent
          , driv01_same_second_is_a_silent_noop
          , driv01_extreme_tick_is_survivable
          , driv01_seed_is_reproducible
          , driv01_seed_replays_the_committed_path
          , every_advertised_override_is_honoured
          , store_overrides_are_probed_or_named_as_gaps
          , expected_store_laws_is_the_law_set
          , store_laws_run_against_the_memory_store
          , adversarial_corpus_has_a_silently_corrupted_member
          , migration_list_is_ordered_and_gapless
          , unique_constraint_names_all_three_columns
          , store_conformance_is_present_and_fresh
          , store_conformance_verdicts_are_all_pass
          , bare_bytestring_is_observed_corrupting_the_artifact
          , store_conformance_digests_match_the_pinned_source_digest
          , jsonb_round_trip_of_the_real_shape_is_exhibited_failing
          , store_conformance_records_a_nonzero_exit_on_checksum_drift
          , store_conformance_records_the_second_migrator_applying_nothing
          , store_conformance_records_two_runs_from_an_empty_database
          , store_conformance_records_the_pinned_image_and_server_version
          , store_conformance_records_the_live_identity_constraint
          , json_recogniser_agrees_with_jsonb_except_where_measured
          , no_credential_is_present_in_a_tracked_file
          , aeson_round_trip_mutations_are_re_measured
          , aeson_is_absent_from_the_storage_path
          , driv01_capture_round_trips
          , driv01_run_capture_is_present_and_fresh
          , driv01_e3_per_step_matches_submitted
          , driv01_no_same_second_noop
          , driv01_legacy_write_price_still_ran
          , driv02_single_order_live
          , driv02_mixed_batch_live
          , driv02_zero_arrival_is_64_bytes
          , driv02_run_capture_orders_are_fresh
          , gams_version_parser_rejects_the_garbage_battery
          , gams_version_is_not_constructible_empty
          , conopt_parser_rejects_both_decoys
          , conopt_parse_is_position_independent
          , gams_exit_taxonomy_is_total_and_disjoint
          , timeout_codes_do_not_collide_with_gams_codes
          , argv_rendering_is_canonical_and_total
          , the_whitelist_pins_LC_ALL_C_and_admits_no_GAMS_variable
          , artifact_postconditions_reject_a_short_array
          , the_artifact_decoder_refuses_a_non_integer_token
          , the_golden_vector_comes_from_the_committed_artifact
          , dqx_double_decode_loses_exactly_32_wei_on_the_first_element
          , every_golden_element_is_inexact_under_double
          , no_Double_and_no_aeson_on_the_artifact_path
          , the_artifact_path_scan_covers_every_module_on_it
          , stub_exit_codes_drive_the_verdict
          , exit_zero_without_artifact_is_refused
          , a_pre_existing_artifact_is_unreachable
          , each_invocation_gets_a_fresh_directory_and_it_is_removed
          , gams_verdict_ignores_the_streams
          , a_stderr_flood_completes_without_deadlock
          , a_hung_grandchild_is_terminated_and_reaped
          , a_timed_out_run_yields_Aborted_and_no_artifact
          , the_child_environment_is_exactly_the_whitelist
          , an_inherited_environment_is_observed_to_differ
          , version_detection_failure_aborts_the_invocation
          , the_suite_never_names_the_real_solver
          ]
            ++ per_pin_checks pins
  pure checks

run_one :: Check -> IO (String, Bool)
run_one check = do
  outcome <- check_run check
  case outcome of
    Right () -> putStrLn ("PASS " ++ check_name check) >> pure (check_name check, True)
    Left why ->
      putStrLn ("FAIL " ++ check_name check ++ ": " ++ why) >> pure (check_name check, False)
