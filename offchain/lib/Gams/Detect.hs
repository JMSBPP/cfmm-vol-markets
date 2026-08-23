-- |
-- SPIKE SEAM S1, CLOSED IN THE LIBRARY: a 'Gams.Run.ToolchainIdentity' obtained BEFORE the first
-- production solve.
--
-- @.planning\/SPIKE-end-to-end.md@ §S1 recorded the hole: 'Store.Key.key_identity' takes a
-- 'Gams.Run.ToolchainIdentity', the only producer of one in this package is the @Produced@ arm of
-- 'Gams.Run.run_prover', and 'Store.Cache.decide' needs the identity BEFORE it can compute a key.
-- The spike paid a BOOTSTRAP SOLVE whose only product was the identity. A resident loop must not:
-- a bootstrap solve is a production run charged to no event, with an artifact nobody reads and a
-- run directory nobody names, and its cost is paid at every restart.
--
-- WHAT \"VERSION-ONLY\" MEANS HERE, AND WHAT IT DOES NOT
-- -----------------------------------------------------
-- It means NO PRODUCTION MODEL IS COMPILED AND NO PRODUCTION SOLVE IS PAID. It does NOT mean no
-- process. Two MEASURED facts make a process unavoidable:
--
--   * The version flag IS NOT A COMMAND. @gams --version@ is parsed as an input FILENAME; the
--     process exits 6 and prints a perfectly well-formed banner whose job field is the flag itself,
--     and the very parser this module reuses refuses it as @Left (WrongJob \"--version\")@. That
--     verdict is committed in @offchain\/rig\/gams-conformance.json@ under
--     @version_flag\/parser_verdict@, beside the banner line that produced it.
--   * CONOPT states its own version in ONE place: the output of a run that actually reaches the
--     solver. @offchain\/rig\/gams-conformance.json@'s @conopt_method@ records how it was obtained
--     -- 'Gams.Version.parse_conopt_version' over the stdout of an eight-line hermetic NLP probe
--     run at @lo=3@, matched on the spaced-letter banner and never on a line position. The two
--     decoys (the GAMS-side link line and the shared object's soname) both carry the token CONOPT
--     and neither carries the version this key is built from.
--
-- So the probe SOLVES -- a five-line convex NLP with a closed-form minimum, costing milliseconds --
-- and it solves 'probe_model_source', which is written into a directory this module makes and
-- removes. The production model is never handed to the binary. It is only DIGESTED.
--
-- WHY THE PRODUCTION MODEL'S DIGEST AND NOT THE PROBE'S
-- ----------------------------------------------------
-- @ti_model_sources@ is the identity component the content key folds in, and the key is over the
-- model that WILL BE SOLVED. A probe that leaked into the identity would key every stored row to a
-- throwaway file, so every row would agree with every other row about a model none of them ran.
-- 'toolchain_from_probe' therefore takes the production sources as an argument and never derives
-- them from the invocation it just made.
--
-- WHY THE JOB NAME IS STILL THE DISCRIMINATOR
-- -------------------------------------------
-- 'Gams.Version.parse_gams_version' judges a banner by ONE equality: the job field must equal the
-- basename of the @.gms@ that was invoked. Here that basename is the PROBE's, because the probe is
-- what ran. The rule is not weakened for this caller; it is applied to this caller's own subject,
-- which is exactly why the two committed wrong-subject banners are still refused when they are fed
-- to this module.
--
-- WHAT IS DELIBERATELY ABSENT
-- ---------------------------
-- No default, no alternative, no placeholder and no exception handler on the identity path. Every
-- failure is a 'DetectError' naming what was read. A detector that reported a plausible value when
-- its subject was absent is worse than one that reported nothing, because Phase 25 folds both
-- version strings into the content key.
module Gams.Detect
  ( -- * The probe
    probe_model_name
  , probe_model_source
    -- * Why detection failed
  , DetectError (..)
    -- * The pure half
  , toolchain_from_probe
    -- * The edge
  , detect_toolchain
  ) where

import Control.Exception (bracket, throwIO, try)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.List (sort)
import Data.Unique (hashUnique, newUnique)
import System.Directory
  ( createDirectory
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode (..))
import System.FilePath (isAbsolute, takeFileName, (</>))
import System.IO.Error (isAlreadyExistsError)
import System.Process
  ( CreateProcess (..)
  , proc
  , readCreateProcessWithExitCode
  )

import Gams.Run (ToolchainIdentity (..))
import Gams.Version
  ( VersionError
  , parse_conopt_version
  , parse_gams_version
  )
import Store.Types (sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- The probe
-- ---------------------------------------------------------------------------------------------

-- | The probe's file name, and therefore the job name every banner it produces must EQUAL.
probe_model_name :: FilePath
probe_model_name = "probe_toolchain.gms"

-- | The hermetic NLP, VERBATIM from @offchain\/rig\/capture-gams-conformance.sh@.
--
-- Five lines, one variable, one equation, a bounded box and a closed-form minimum at @x = 1@. It
-- reads no data, writes no artifact and touches nothing outside the directory it is run in. Its
-- ONLY job is to make CONOPT print its own banner.
probe_model_source :: String
probe_model_source =
  unlines
    [ "variable z, x;  equation e;"
    , "e.. z =e= sqr(x-1) + 1;"
    , "x.lo = -10; x.up = 10;"
    , "model m /e/;  option nlp = conopt;"
    , "solve m using nlp minimizing z;"
    ]

-- | The log-level the probe is run at, so BOTH banners reach stdout.
--
-- @lo=3@ is what @offchain\/rig\/gams-conformance.json@'s @conopt_method@ records, and the level
-- matters: at the production level the solver's own banner goes to the log file in the run
-- directory instead of to the captured stream.
probe_log_option :: String
probe_log_option = "lo=3"

-- | Seconds the probe is given. A convex five-line NLP that takes minutes is a wedged toolchain,
-- and a wedged toolchain must fail startup rather than hang it.
probe_budget_s :: Int
probe_budget_s = 60

-- | The grace between the term signal and the group kill.
--
-- The wrapper owns the process GROUP for the reason "Gams.Invoke" records: GAMS runs CONOPT as a
-- SEPARATE process, so a signal that reached only the direct child would leave a solver behind --
-- and this module's whole subject is the run that reaches the solver.
probe_kill_after_s :: Int
probe_kill_after_s = 5

-- | The same wrapper "Gams.Run" spawns through, named once here.
probe_wrapper :: FilePath
probe_wrapper = "/usr/bin/timeout"

-- ---------------------------------------------------------------------------------------------
-- Why detection failed
-- ---------------------------------------------------------------------------------------------

-- | Every constructor NAMES its subject, and none of them is a value the caller may proceed with.
data DetectError
  = ProbeExitNonZero Int
    -- ^ the probe process did not exit 0, carrying the status it did exit with. A non-zero probe
    -- reached neither banner reliably, and reading its output anyway is how an environmental
    -- failure becomes a version string.
  | ProbeVersionUnreadable VersionError
    -- ^ the probe's output carried no banner this module's parser accepts for the PROBE's own job
    -- name, carrying the parser's reason. @WrongJob@ here means the output came from some other
    -- invocation entirely.
  | ProbeConoptUnreadable VersionError
    -- ^ no spaced-letter CONOPT banner in the probe's output. 'Store.Key.key_identity' refuses an
    -- absent solver-side version outright, so admitting one here would only move the refusal.
  | ProbeBinaryNotAbsolute FilePath
    -- ^ the binary was handed in as a bare name or a relative path, naming it. Resolution is the
    -- caller's startup precondition, and a name left for @execve@ to resolve a second time is a
    -- different binary than the one that was digested.
  | ProbeModelNotAbsolute FilePath
    -- ^ the PRODUCTION model was handed in as a relative path, naming it. It is digested rather
    -- than run, and a digest of whatever happened to sit at a relative path is not evidence.
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The pure half
-- ---------------------------------------------------------------------------------------------

-- | Everything a suite cannot make a solver do on demand is an ARGUMENT here.
--
-- The first argument is the job name the banner must equal -- the probe's basename, supplied by
-- the caller that ran it, so this function never assumes which file produced the bytes it was
-- handed. The last is the PRODUCTION source list: see the module header for why it is not the
-- probe's.
toolchain_from_probe
  :: FilePath              -- ^ the probe model's basename: the job name the banner must EQUAL
  -> BS.ByteString         -- ^ the probe's captured output
  -> FilePath -> String    -- ^ the binary path and its sha256
  -> [(FilePath, String)]  -- ^ the PRODUCTION model sources and their digests
  -> Either DetectError ToolchainIdentity
toolchain_from_probe probe_basename output binary binary_sha sources =
  case parse_gams_version probe_basename output of
    Left why -> Left (ProbeVersionUnreadable why)
    Right gams ->
      case parse_conopt_version output of
        Left why -> Left (ProbeConoptUnreadable why)
        Right conopt ->
          Right
            ToolchainIdentity
              { ti_gams_version   = gams
              , ti_conopt_version = Just conopt
              , ti_gams_path      = binary
              , ti_gams_sha256    = binary_sha
              , ti_model_sources  = sort sources
              }

-- ---------------------------------------------------------------------------------------------
-- The edge
-- ---------------------------------------------------------------------------------------------

-- | Probe the toolchain once, with no production model and no production solve.
--
-- The environment vector has the same meaning it has in "Gams.Run": @Just@ pairs are the child's
-- ENTIRE environment, @Nothing@ inherits.
detect_toolchain
  :: FilePath                       -- ^ absolute prover binary
  -> FilePath                       -- ^ absolute PRODUCTION model, digested into the identity
  -> Maybe [(String, String)]       -- ^ the environment vector
  -> IO (Either DetectError ToolchainIdentity)
detect_toolchain binary model environment
  | not (isAbsolute binary) = pure (Left (ProbeBinaryNotAbsolute binary))
  | not (isAbsolute model)  = pure (Left (ProbeModelNotAbsolute model))
  | otherwise =
      with_fresh_probe_dir $ \dir -> do
        let probe = dir </> probe_model_name
        writeFile probe probe_model_source
        let wrapper_argv =
              [ "-k"
              , show probe_kill_after_s
              , show probe_budget_s
              , binary
              , probe
              , "curdir=" ++ dir
              , probe_log_option
              ]
            spec = (proc probe_wrapper wrapper_argv)
                     { cwd = Just dir
                     , env = environment
                     }
        -- 'readCreateProcessWithExitCode' forks two DRAINING threads, so the pipe hazard is closed
        -- by construction here exactly as it is in "Gams.Run" and "Gams.Invoke".
        (code, out, _err) <- readCreateProcessWithExitCode spec ""
        case code of
          ExitFailure n -> pure (Left (ProbeExitNonZero n))
          ExitSuccess -> do
            binary_bytes <- BS.readFile binary
            model_bytes  <- BS.readFile model
            pure
              (toolchain_from_probe
                 (takeFileName probe)
                 (C8.pack out)
                 binary
                 (sha256_hex binary_bytes)
                 [(model, sha256_hex model_bytes)])

-- | An EXCLUSIVE directory under the system temp directory, removed on every exit path.
--
-- 'createDirectory' is the exclusive form and its permissive sibling is deliberately absent from
-- this module, as it is from "Gams.Run", and a source scan asserts that by name. Only the
-- exclusive form makes \"this directory did not exist a moment ago\" a fact rather than a hope.
--
-- The retry is NOT a fallback. It recovers from exactly one condition -- the name is already taken
-- -- and it recovers by asking for a DIFFERENT name, never by reusing the taken one and never by
-- continuing without a directory. Every other 'IOError' is re-thrown unchanged.
with_fresh_probe_dir :: (FilePath -> IO a) -> IO a
with_fresh_probe_dir body = do
  tmp <- getTemporaryDirectory
  bracket (allocate tmp) removeDirectoryRecursive body
  where
    allocate tmp = do
      u <- newUnique
      let dir = tmp </> ("cfmm-gams-probe-" ++ show (hashUnique u))
      made <- try (createDirectory dir)
      case made of
        Right () -> pure dir
        Left err
          | isAlreadyExistsError err -> allocate tmp
          | otherwise                -> throwIO err
