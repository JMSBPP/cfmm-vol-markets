{-# LANGUAGE OverloadedStrings #-}

-- |
-- THE CAPTURE. The one place in Phase 24 that needs a solver, and -- until the throwaway
-- end-to-end spike at @offchain\/app\/SpikeEndToEnd.hs@ joined it -- the only importer of
-- "Gams.Invoke". Both importers are under @offchain\/app\/@, which is the property that was ever
-- load-bearing; the count never was.
--
-- Nine of the phase's observations can only be made against the real GAMS 54.1 / CONOPT 4.39
-- toolchain: the golden bytes coming out of a real solve, @action=c@ exiting 0 with no artifact at
-- all, the two exit-0-and-exit-6 banners from invocations that ran no model, the exit-code taxonomy,
-- CONOPT's true version standing beside both of its decoys, the minimal environment vector, the
-- hostile one, and the argv token whose leading zero changes the bytes while every gate stays green.
-- A guard that has never been seen rejecting is treated as ABSENT, so every one of them is DRIVEN
-- here and RECORDED as a value. Nothing in this file asserts; the assertions live in @cabal test@,
-- over the committed artifact, with no solver anywhere near them.
--
-- == aeson IS PERMITTED HERE, AND ONLY HERE
--
-- This tool writes the JSON REPORT. The report is a DESCRIPTION of an experiment; the prover's
-- @volume_path.json@ is the experiment; and the two never meet. No artifact byte reaches this file's
-- json writer -- every byte-level fact travels as a LENGTH and a BARE hex digest computed by
-- 'Store.Types.sha256_hex' over the bytes themselves. That is why BYTE-03's source scan is scoped to
-- the library's storage modules and not to this directory: the storage path must not be able to
-- re-render a number or reorder a key, and a report that never carries bytes cannot.
--
-- == EVERY RECORDED VERSION AND VERDICT COMES FROM THE SHIPPED PARSER
--
-- 'parse_gams_version' and 'parse_conopt_version' are the functions under test, and they are also
-- the functions that produce every version string and every @parser_verdict@ below. A field derived
-- from a SECOND implementation would be a comparison of one expression against another expression's
-- output, which is the tautology defect this repository has been bitten by seven times -- most
-- recently at 24-04, where a check compared @whitelist_for@ against itself and stayed green while
-- the value under it was deleted.
--
-- The two places this file does its own reading are deliberate and neither is a version under test:
-- the CONOPT link-version DECOY (found as the third field of a line the shipped parser REFUSES, so
-- the reading is defined by the parser's refusal) and the shared object's filename (a directory
-- listing).
--
-- == THE FRESHNESS ORACLE'S TWO HALVES
--
-- @argv_module_sha256@ and @artifact_module_sha256@ are digests of @offchain\/lib\/Gams\/Argv.hs@ and
-- @offchain\/lib\/Gams\/Artifact.hs@ -- the renderer that decides the argv token and the decoder that
-- reads the bytes back. The suite RECOMPUTES both from this repository's own disk, so editing either
-- one without re-capturing reddens. That mirrors 23-05's oracle, which recomputes migration digests
-- from @offchain\/migrations\/@.
--
-- @model_sources@ is the half that CANNOT be recomputed offline: @volume_path.gms@ lives in the
-- sibling GAMS worktree and is unreachable from this repository. It is recorded, asserted on SHAPE,
-- and NAMED as a gap in the suite rather than given a manufactured subject -- 23-05's @PGSTORE_DSN@
-- ruling, applied unchanged.
--
-- == COMPLETENESS
--
-- @gc_complete@ starts 'False' and is flipped only after every block has returned, in the
-- @sc_complete@ \/ @dr_complete@ idiom. The FILE is written exactly once, at the end, through
-- 'Driver.Capture.write_json_atomically': writing an incomplete artifact first and overwriting it
-- would destroy the committed evidence before this tool had produced any.
--
-- == USAGE
--
-- > gams-conformance <scratch-directory>
--
-- The scratch directory is prepared by @offchain\/rig\/capture-gams-conformance.sh@ and carries the
-- four probe models named in 'required_probe_models'. It is never inside the working tree and never
-- inside @model\/@, which is another workstream's territory.
module Main (main) where

import Data.Aeson (object, (.=))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Either (isRight)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (isPrefixOf, isSuffixOf, sort)
import Data.Maybe (isJust, isNothing)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , listDirectory
  )
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO (hPutStrLn, stderr)
import System.Process (readProcess)

import Driver.Capture (write_json_atomically)
import Gams.Argv (Shock (..), render_argv, render_decimal)
import Gams.Artifact (ProverArtifact (..))
import Gams.Config (gams_conformance_path)
import Gams.Invoke
  ( EnvChoice (..)
  , InvokeError
  , RawRun (..)
  , binary_identity
  , environment_for
  , invoke_shock
  , raw_gams
  , resolve_gams_bin
  , resolve_gams_model
  )
import Gams.Run
  ( CapturedStreams (..)
  , ProverOutcome (..)
  , ToolchainIdentity (..)
  )
import Gams.Version
  ( conopt_version_text
  , gams_build_text
  , gams_version_text
  , parse_conopt_version
  , parse_gams_version
  )
import Store.Types (sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- Constants of the capture
-- ---------------------------------------------------------------------------------------------

-- | The committed golden artifact. It is the OUTSIDE ANCHOR for every digest below.
--
-- Recording the digest of a run and then comparing it against the digest of THAT SAME RUN would be
-- a comparison of a value with itself. So @golden@ is measured HERE, from a file that was committed
-- before this capture existed, and the three environment runs are compared against it. The suite in
-- turn compares this field against 'Store.Types.volume_path_golden_sha256', which is a third place.
golden_path :: FilePath
golden_path = "offchain/rig/volume-path-golden.json"

-- | The two library modules the freshness oracle recomputes.
argv_module_path, artifact_module_path :: FilePath
argv_module_path     = "offchain/lib/Gams/Argv.hs"
artifact_module_path = "offchain/lib/Gams/Artifact.hs"

-- | THE GOLDEN ARTIFACT'S OWN INPUTS.
--
-- These seven values are the shock that produced @offchain\/rig\/volume-path-golden.json@, read off
-- its echoed fields. @volTgtWad@ is not echoed into the output at all -- MEASURED, it is a GAMS
-- @Scalar@ -- so it is the one field here that comes from the research transcript rather than from
-- the file.
golden_shock :: Shock
golden_shock = Shock
  { sh_sqrt_price_x96  = 79228162514264337593543950336
  , sh_liquidity_raw   = 18446744073709551616
  , sh_txl_volume_rate = 490000
  , sh_phi_x_pips      = 500
  , sh_phi_m_pips      = 6000
  , sh_vol_tgt_wad     = 28000000000000000000
  , sh_n_events        = 8
  }

-- | The four models the capture script writes into the scratch directory.
--
-- They are NOT written by this executable and they are NOT committed. Writing them here would mean
-- a @.gms@ body living inside @offchain\/@, where four scans read every Haskell file; writing them
-- into the tree would mean a fifth file type to declare. The script owns them, this executable
-- refuses to run without them, and the refusal NAMES the missing one.
required_probe_models :: [FilePath]
required_probe_models =
  [ conopt_probe_model
  , compile_error_model
  , abort_model
  , exec_error_model
  ]

conopt_probe_model, compile_error_model, abort_model, exec_error_model :: FilePath
conopt_probe_model  = "probe_conopt.gms"
compile_error_model = "probe_compile_error.gms"
abort_model         = "probe_abort.gms"
exec_error_model    = "probe_exec_error.gms"

-- | A path that must NOT exist, so GAMS's parameter-error code has a subject.
missing_model :: FilePath
missing_model = "probe_no_such_model.gms"

-- | The four ambient variables MEASURED inert against the artifact's bytes, kept as @KEY=VALUE@
-- strings because that is how they are recorded and how the suite compares them.
hostile_pairs :: [(String, String)]
hostile_pairs =
  [ ("GAMSTHREADS", "8")
  , ("GDXCOMPRESS", "1")
  , ("LC_NUMERIC", "de_DE.UTF-8")
  , ("GAMSDIR", "/nonexistent")
  ]

-- | The environment the minimal run gets: the whitelist WITHOUT @HOME@.
minimal_pairs :: [(String, String)]
minimal_pairs = [("LC_ALL", "C"), ("PATH", "/usr/bin")]

-- | The two non-canonical spellings of @volTgtWad@ that MEASURED byte-identical.
voltgt_a, voltgt_b :: String
voltgt_a = "28e18"
voltgt_b = "2.8e19"

gams_version_method_text :: String
gams_version_method_text =
  "Gams.Version.parse_gams_version over volume_path.log line 1 of the clean solve, anchored on the\
  \ job name so the two exit-0 wrong-subject banners cannot satisfy it"

conopt_method_text :: String
conopt_method_text =
  "Gams.Version.parse_conopt_version over the stdout of an 8-line hermetic NLP probe run at lo=3,\
  \ matched on the spaced-letter banner and never on a line position"

-- ---------------------------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  case args of
    [scratch] -> capture scratch
    _         -> do
      hPutStrLn stderr "usage: gams-conformance <scratch-directory>"
      hPutStrLn stderr "       the directory is prepared by offchain/rig/capture-gams-conformance.sh"
      exitFailure

-- | Fail loudly, naming the subject, and write NOTHING. A capture that continues past a missing
-- precondition writes a partial artifact and reports success.
die :: [String] -> IO a
die messages = do
  mapM_ (hPutStrLn stderr) messages
  hPutStrLn stderr "              No artifact was written; the committed one is untouched."
  exitFailure

resolved :: String -> Either InvokeError a -> IO a
resolved what outcome =
  case outcome of
    Right value -> pure value
    Left why    -> die ["CAPTURE FAIL: " ++ what ++ ": " ++ show why]

-- | One environment run, through the PRODUCTION composition, all the way to bytes.
solve_with :: String -> EnvChoice -> IO (ProverArtifact, ToolchainIdentity, CapturedStreams)
solve_with label choice =
  invoke_shock choice golden_shock >>= resolved label >>= produced label

-- | 'Produced' or nothing. An 'Aborted' clean solve is a FINDING, never a value to record around.
produced :: String -> ProverOutcome -> IO (ProverArtifact, ToolchainIdentity, CapturedStreams)
produced label outcome =
  case outcome of
    Produced artifact identity streams -> pure (artifact, identity, streams)
    Aborted why code _ ->
      die [ "CAPTURE FAIL: the " ++ label ++ " did not produce an artifact."
          , "              " ++ show why ++ " at exit " ++ show code
          , "              Every digest below would then be a digest of nothing."
          ]

capture :: FilePath -> IO ()
capture scratch = do
  complete <- newIORef False
  out      <- gams_conformance_path

  -- --- Preconditions ------------------------------------------------------------------------
  mapM_ (require_probe scratch) required_probe_models
  golden_there <- doesFileExist golden_path
  if not golden_there
    then die [ "CAPTURE FAIL: no committed golden artifact at " ++ golden_path
             , "              Every byte claim below is stated AGAINST it, so without it the three"
             , "              environment runs would be compared only with each other."
             ]
    else pure ()
  golden_bytes <- BS.readFile golden_path

  binary <- resolve_gams_bin   >>= resolved "the prover binary could not be resolved"
  model  <- resolve_gams_model >>= resolved "the model could not be resolved"
  (binary_sha, binary_size) <- binary_identity binary

  -- The vector the whitelisted run is about to be handed, taken from the function that builds it.
  whitelist_env <- environment_for WhitelistEnv

  argv <- case render_argv golden_shock of
    Right tokens -> pure tokens
    Left why     -> die ["CAPTURE FAIL: the golden shock did not render: " ++ show why]

  -- --- (a) The three environment runs, through the PRODUCTION composition -------------------
  (wl_artifact, identity, wl_streams) <- solve_with "whitelisted solve" WhitelistEnv
  (min_artifact, _, _)     <- solve_with "minimal-environment solve" (ExactEnv minimal_pairs)
  (hostile_artifact, _, _) <-
    solve_with "hostile-environment solve" (ExactEnv (minimal_pairs ++ hostile_pairs))

  -- --- (b) The raw invocations the production path cannot make ------------------------------
  let scratch_env = minimal_pairs
      run tag extra = do
        let dir = scratch </> ("run-" ++ tag)
        createDirectoryIfMissing True dir
        raw_gams binary dir scratch_env (extra dir)

  clean_raw    <- run "clean"      (\d -> [model, "action=ce", "curdir=" ++ d, "lo=2"] ++ argv)
  action_c_raw <- run "action-c"   (\d -> [model, "action=c",  "curdir=" ++ d, "lo=2"] ++ argv)
  no_args_raw  <- run "no-args"    (const [])
  version_raw  <- run "version"    (const ["--version"])
  compile_raw  <- run "compile"    (\d -> [scratch </> compile_error_model, "curdir=" ++ d, "lo=2"])
  abort_raw    <- run "abort"      (\d -> [scratch </> abort_model, "curdir=" ++ d, "lo=2"])
  exec_raw     <- run "exec"       (\d -> [scratch </> exec_error_model, "curdir=" ++ d, "lo=2"])
  missing_raw  <- run "missing"    (\d -> [scratch </> missing_model, "curdir=" ++ d, "lo=2"])
  probe_raw    <- run "conopt"     (\d -> [scratch </> conopt_probe_model, "curdir=" ++ d, "lo=3"])
  zero_raw     <- run "leadingzero"
                    (\d -> [model, "action=ce", "curdir=" ++ d, "lo=2"] ++ leading_zero_argv argv)
  voltgt_a_raw <- run "voltgt-a"
                    (\d -> [model, "action=ce", "curdir=" ++ d, "lo=2"] ++ voltgt_argv argv voltgt_a)
  voltgt_b_raw <- run "voltgt-b"
                    (\d -> [model, "action=ce", "curdir=" ++ d, "lo=2"] ++ voltgt_argv argv voltgt_b)

  -- --- (c) The CONOPT triple ----------------------------------------------------------------
  conopt <- case parse_conopt_version (raw_stdout probe_raw) of
    Right v  -> pure (conopt_version_text v)
    Left why -> die [ "CAPTURE FAIL: the 8-line NLP probe produced no CONOPT banner: " ++ show why
                    , "              Without it GAMS-04 has no true version to distinguish from"
                    , "              its two decoys, and the whole observation is vacuous."
                    ]
  probe_index <- require_index "the probe's stdout" (conopt_line_index (raw_stdout probe_raw))
  real_index  <- require_index "the clean solve's own log" (conopt_line_index (cs_log wl_streams))
  link_version <- case conopt_link_field (raw_stdout probe_raw) of
    Just v  -> pure v
    Nothing -> die [ "CAPTURE FAIL: the probe's stdout carries no GAMS-side CONOPT link line."
                   , "              That line is the DECOY the true version exists to be told"
                   , "              apart from; without it the inequality below is unfalsifiable."
                   ]
  so_name <- conopt_shared_object (takeDirectory binary)

  -- --- (d) The verdicts ---------------------------------------------------------------------
  let golden_sha = sha256_hex golden_bytes
      wl_sha     = sha256_hex (pa_bytes wl_artifact)
      min_sha    = sha256_hex (pa_bytes min_artifact)
      host_sha   = sha256_hex (pa_bytes hostile_artifact)
      zero_sha   = maybe "" sha256_hex (raw_artifact zero_raw)
      a_sha      = maybe "" sha256_hex (raw_artifact voltgt_a_raw)
      b_sha      = maybe "" sha256_hex (raw_artifact voltgt_b_raw)
      basename   = takeFileName model

      observations :: [(String, Bool)]
      observations =
        [ ( "clean_solve_reproduces_the_committed_golden_bytes"
          , wl_sha == golden_sha )
        , ( "action_c_exits_zero_and_writes_no_artifact"
          , raw_exit action_c_raw == 0 && isNothing (raw_artifact action_c_raw) )
        , ( "no_arguments_exits_zero_with_a_wrong_subject_banner"
          , raw_exit no_args_raw == 0
              && BS.null (raw_stderr no_args_raw)
              && not (isRight (parse_gams_version basename (raw_stdout no_args_raw))) )
        , ( "version_flag_exits_six_with_a_wrong_subject_banner"
          , raw_exit version_raw == 6
              && BS.null (raw_stderr version_raw)
              && not (isRight (parse_gams_version basename (raw_stdout version_raw))) )
        , ( "the_exit_code_taxonomy_was_driven"
          , raw_exit compile_raw == 2 && raw_exit abort_raw == 3
              && raw_exit exec_raw == 3 && raw_exit missing_raw == 6 )
        , ( "conopt_true_version_differs_from_both_decoys"
          , conopt /= link_version && conopt /= so_name && probe_index /= real_index )
        , ( "the_minimal_whitelist_reproduces_the_golden_bytes"
          , min_sha == golden_sha )
        , ( "a_hostile_environment_leaves_the_bytes_identical"
          , host_sha == golden_sha )
        , ( "the_leading_zero_token_changes_the_bytes"
          , raw_exit zero_raw == 0 && zero_sha /= golden_sha && not (null zero_sha) )
        ]

  argv_sha     <- module_digest argv_module_path
  artifact_sha <- module_digest artifact_module_path
  stamp        <- generated_at

  writeIORef complete True
  done <- readIORef complete

  write_json_atomically out $ object
    [ "gc_complete"          .= done
    , "generatedAt"          .= stamp
    , "gams_path"            .= binary
    , "gams_sha256"          .= binary_sha
    , "gams_size"            .= binary_size
    , "gams_version"         .= gams_version_text (ti_gams_version identity)
    , "gams_build"           .= gams_build_text (ti_gams_version identity)
    , "gams_version_method"  .= gams_version_method_text
    , "conopt_version"       .= conopt
    , "conopt_method"        .= conopt_method_text
    , "conopt_link_version"  .= link_version
    , "conopt_so_name"       .= so_name
    , "conopt_true_line_index_probe" .= probe_index
    , "conopt_true_line_index_real"  .= real_index
    , "exit_codes" .= object
        [ "clean"         .= raw_exit clean_raw
        , "compile_error" .= raw_exit compile_raw
        , "abort"         .= raw_exit abort_raw
        , "exec_error"    .= raw_exit exec_raw
        , "missing_file"  .= raw_exit missing_raw
        , "no_args"       .= raw_exit no_args_raw
        , "action_c"      .= raw_exit action_c_raw
        ]
    , "action_c" .= object
        [ "exit"             .= raw_exit action_c_raw
        , "artifact_present" .= isJust (raw_artifact action_c_raw)
        ]
    , "no_args" .= object
        [ "exit"           .= raw_exit no_args_raw
        , "stdout_len"     .= BS.length (raw_stdout no_args_raw)
        , "stderr_len"     .= BS.length (raw_stderr no_args_raw)
        , "line1"          .= first_line (raw_stdout no_args_raw)
        , "parser_verdict" .= show (parse_gams_version basename (raw_stdout no_args_raw))
        ]
    , "version_flag" .= object
        [ "exit"           .= raw_exit version_raw
        , "stdout_len"     .= BS.length (raw_stdout version_raw)
        , "stderr_len"     .= BS.length (raw_stderr version_raw)
        , "line1"          .= first_line (raw_stdout version_raw)
        , "parser_verdict" .= show (parse_gams_version basename (raw_stdout version_raw))
        ]
    , "golden" .= object
        [ "sha256" .= golden_sha
        , "len"    .= BS.length golden_bytes
        ]
    , "whitelist_run" .= object
        [ "vars"   .= map fst whitelist_env
        , "sha256" .= wl_sha
        ]
    , "minimal_run" .= object
        [ "vars"   .= map fst minimal_pairs
        , "sha256" .= min_sha
        ]
    , "hostile_env_run" .= object
        [ "vars"   .= [k ++ "=" ++ v | (k, v) <- hostile_pairs]
        , "sha256" .= host_sha
        ]
    , "leading_zero_run" .= object
        [ "token"  .= leading_zero_token
        , "exit"   .= raw_exit zero_raw
        , "sha256" .= zero_sha
        ]
    , "voltgt_rendering" .= object
        [ "a"        .= voltgt_a
        , "b"        .= voltgt_b
        , "sha256_a" .= a_sha
        , "sha256_b" .= b_sha
        ]
    , "model_sources" .=
        [ object ["path" .= p, "sha256" .= d] | (p, d) <- ti_model_sources identity ]
    , "argv_module_sha256"     .= argv_sha
    , "artifact_module_sha256" .= artifact_sha
    , "observations" .=
        [ object ["name" .= n, "verdict" .= (if ok then "pass" else "fail" :: String)]
        | (n, ok) <- observations
        ]
    ]

  putStrLn ("wrote " ++ out)
  putStrLn ("  GAMS      " ++ gams_version_text (ti_gams_version identity)
             ++ " " ++ gams_build_text (ti_gams_version identity) ++ "  at " ++ binary)
  putStrLn ("  CONOPT    " ++ conopt ++ "   link decoy " ++ link_version
             ++ "   so decoy " ++ so_name)
  putStrLn ("  LINES     true banner at probe " ++ show probe_index ++ ", real run "
             ++ show real_index)
  putStrLn ("  GOLDEN    " ++ golden_sha ++ "  (" ++ show (BS.length golden_bytes) ++ " bytes)")
  putStrLn ("  LEADZERO  " ++ zero_sha ++ "  at exit " ++ show (raw_exit zero_raw))
  putStrLn ("  VERDICTS  "
             ++ show (length [() | (_, True) <- observations]) ++ "/"
             ++ show (length observations) ++ " pass")

-- ---------------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------------

require_probe :: FilePath -> FilePath -> IO ()
require_probe scratch name = do
  there <- doesFileExist (scratch </> name)
  if there
    then pure ()
    else die [ "CAPTURE FAIL: the scratch directory has no " ++ name
             , "              (" ++ (scratch </> name) ++ ")"
             , "              offchain/rig/capture-gams-conformance.sh writes the probe models."
             ]

require_index :: String -> Maybe Int -> IO Int
require_index what found =
  case found of
    Just i  -> pure i
    Nothing -> die [ "CAPTURE FAIL: no CONOPT banner in " ++ what ++ "."
                   , "              The recorded line index would then be a number about nothing."
                   ]

-- | The ONE-BASED index of the first line the SHIPPED parser accepts as CONOPT's own banner.
--
-- The index is found by asking 'parse_conopt_version' about each line in turn, so the position
-- recorded is the position of the line the production parser would take -- not the position of a
-- line some second rule in this file happened to like.
conopt_line_index :: BS.ByteString -> Maybe Int
conopt_line_index buffer =
  case [i | (i, l) <- zip [1 ..] (C8.lines buffer), isRight (parse_conopt_version l)] of
    (i : _) -> Just i
    []      -> Nothing

-- | The GAMS-side link version: the third field of a line opening with the unspaced token, on a
-- line the shipped parser REFUSES.
--
-- The refusal is what defines the reading. This is the DECOY, and it is deliberately extracted by a
-- rule that is not the parser under test -- if it were, the inequality the suite asserts would be
-- two runs of one function compared with each other.
conopt_link_field :: BS.ByteString -> Maybe String
conopt_link_field buffer =
  case [ fields
       | l <- C8.lines buffer
       , not (isRight (parse_conopt_version l))
       , let fields = words (C8.unpack l)
       , take 1 fields == ["CONOPT"]
       , length fields >= 3
       ] of
    (fields : _) -> Just (fields !! 2)
    []           -> Nothing

-- | The CONOPT shared object beside the resolved binary. The THIRD candidate, and the one whose
-- number (@464@) is neither the true version nor the link version.
conopt_shared_object :: FilePath -> IO String
conopt_shared_object dir = do
  entries <- listDirectory dir
  case sort [e | e <- entries, "libconopt" `isPrefixOf` e, ".so" `isSuffixOf` e] of
    (e : _) -> pure e
    []      -> die [ "CAPTURE FAIL: no libconopt*.so beside the resolved binary in " ++ dir
                   , "              That file is the second DECOY; recording an empty string for"
                   , "              it would make the inequality that distinguishes the true"
                   , "              version pass because its subject was absent."
                   ]

-- | The argv with a LEADING ZERO glued onto the price token.
--
-- MEASURED: this exits 0, every VOLUME_PATH.md section 4 gate passes, and the bytes differ. It
-- cannot be produced through 'render_argv', which rebuilds the value from its digits -- which is
-- exactly why it has to be built here, by hand, from the canonical token.
leading_zero_argv :: [String] -> [String]
leading_zero_argv = map bend
  where
    bend token
      | price_prefix `isPrefixOf` token = price_prefix ++ "0" ++ drop (length price_prefix) token
      | otherwise                       = token

leading_zero_token :: String
leading_zero_token = "0" ++ render_decimal (sh_sqrt_price_x96 golden_shock)

price_prefix :: String
price_prefix = "--sqrtPriceX96="

voltgt_prefix :: String
voltgt_prefix = "--volTgtWad="

-- | The argv with @volTgtWad@ re-spelled. The value is the same; the TOKEN is not.
voltgt_argv :: [String] -> String -> [String]
voltgt_argv argv spelling =
  [ if voltgt_prefix `isPrefixOf` token then voltgt_prefix ++ spelling else token
  | token <- argv
  ]

first_line :: BS.ByteString -> String
first_line buffer =
  case C8.lines buffer of
    (l : _) -> C8.unpack l
    []      -> ""

module_digest :: FilePath -> IO String
module_digest path = do
  there <- doesFileExist path
  if not there
    then die [ "CAPTURE FAIL: the freshness oracle's subject " ++ path ++ " is not on disk."
             , "              The suite recomputes this digest; recording one for a file that is"
             , "              gone would make the oracle compare nothing."
             ]
    else do
      bytes <- BS.readFile path
      pure (sha256_hex bytes)

-- | @date@ rather than a new dependency, matching every other capture tool in this tree.
generated_at :: IO String
generated_at = trim <$> readProcess "date" ["-u", "+%Y-%m-%dT%H:%M:%SZ"] ""
  where trim = reverse . dropWhile (`elem` (" \t\r\n" :: String)) . reverse
