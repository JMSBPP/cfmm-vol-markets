-- |
-- THE ONE IO EDGE, and the four conjuncts that make \"the prover succeeded\" mean something.
--
-- WHY EXIT 0 IS THE FIRST CONJUNCT AND NEVER THE ONLY ONE
-- -------------------------------------------------------
-- GAMS's own documentation says exit @0@ means /GAMS ran/, not /the model solved/, and that was
-- MEASURED twice against the real binary on 2026-08-16:
--
--   * @action=c@ (compile only) exits 0, writes @volume_path.log@ and @volume_path.lst@, and
--     writes NO @volume_path.json@ at all;
--   * @gams@ with no arguments at all exits 0 and runs no model.
--
-- A layer that reported success on exit 0 alone is this repository's recurring defect -- an
-- assertion that passes because its subject is absent -- wearing a new representation. So the
-- verdict here is a CONJUNCTION, in this order:
--
--   1. the wrapper's exit code classifies as 'Solved' ('Gams.Exit.classify_exit');
--   2. @volume_path.json@ exists IN A DIRECTORY THAT COULD NOT HAVE PRE-EXISTED;
--   3. its modification time is at or after the marker written immediately before the spawn;
--   4. it decodes ('Gams.Artifact.decode_artifact'), which carries the array post-conditions;
--   5. every echoed string field equals the argv token that was SENT;
--   6. the run's own log carries a job banner naming the model that was invoked.
--
-- NOT ONE of those is log text. Which brings us to:
--
-- NO DECISION IN THIS MODULE READS A STREAM
-- -----------------------------------------
-- 'cs_stdout' and 'cs_stderr' are carried for DIAGNOSIS only. Nothing branches on them, and the
-- suite asserts that structurally with a source scan over this file and over "Gams.Exit" -- with a
-- proven positive control, because a scan that matched nothing would report the same green as a
-- clean one.
--
-- @lo=2@ makes that structurally easy rather than merely disciplined: MEASURED, both streams are
-- exactly 0 BYTES in every GAMS mode, and the log goes to a FILE in the run directory. A layer that
-- read stderr for a verdict would be comparing the empty string against the empty string on every
-- single run, in both the good case and the bad one.
--
-- THE FRESH DIRECTORY IS THE STALE-FILE DEFENCE, AND IT IS EXCLUSIVE
-- ------------------------------------------------------------------
-- @volume_path.gms:202@ is @file fj \/volume_path.json\/;@ -- a RELATIVE name, so it resolves
-- against the working directory. MEASURED (M6): @curdir=\<tempdir\>@ relocates the put file, and
-- the artifact came out at the golden digest across five scratch directories.
--
-- 'with_fresh_run_dir' uses 'createDirectory', which FAILS if the path exists. That exclusivity IS
-- the defence: a name that silently reused an existing directory would reopen exactly the hole a
-- fresh directory closes, because a valid-looking artifact left behind by anything else would be
-- readable at the path this module looks at. The directory is 'bracket'ed with
-- 'removeDirectoryRecursive', so it is gone on EVERY path -- success, abort, and exception alike.
--
-- 'Aborted' CARRIES NO ARTIFACT, AND THAT IS A CORRECTION OF RECORD
-- -----------------------------------------------------------------
-- The phase brief's SC-4 asks for an /aborted run-log row/. That is NOT deliverable in this phase:
-- the run-log table is STORE-07, which is Phase 25, and @offchain\/migrations\/@ contains only
-- @001_model_run.sql@ and @002_byte_corpus.sql@ today. Restating it at the TYPE LEVEL is both
-- stronger and deliverable here: 'Aborted' has no 'Gams.Artifact.ProverArtifact' field and this
-- module exports no total @ProverOutcome -> ProverArtifact@ function, so \"an aborted run produces
-- no output row\" is UNREPRESENTABLE rather than merely untested.
--
-- @Store.Types.DerivedDoc@ is the precedent, and it is a precedent because 23-01 OBSERVED the
-- compile error that idiom produces rather than assuming it. So did 24-03: a scratch module
-- defining a TOTAL accessor from 'ProverOutcome' to 'Gams.Artifact.ProverArtifact' was compiled,
-- and the GHC error refusing it is quoted verbatim in that plan's summary.
--
-- (That sentence used to spell the scratch accessor's identifier, and the acceptance criterion for
-- this file greps for exactly that identifier expecting none. The prose moved. The pattern did not
-- -- which is the same trade 24-01 and 24-02 both made, and this is the fourteenth time on this
-- branch that a comment turned out to be inside a grep's blast radius.)
module Gams.Run
  ( -- * The request
    RunRequest (..)
    -- * The outcome
  , ProverOutcome (..)
  , AbortReason (..)
  , ToolchainIdentity (..)
  , CapturedStreams (..)
    -- * The edge
  , run_prover
    -- * The three names the run directory carries
  , artifact_name
  , log_name
  , run_marker_name
  ) where

import Control.Exception (bracket, throwIO, try)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.List (isPrefixOf, sort)
import Data.Unique (hashUnique, newUnique)
import System.Directory
  ( createDirectory
  , doesFileExist
  , getModificationTime
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
import System.Timeout (timeout)

import Gams.Argv (ArgvError, Shock, render_argv)
import Gams.Artifact (ArtifactError, ProverArtifact (..), decode_artifact)
import Gams.Exit (Verdict (..), TimeoutKind (..), classify_exit)
import Gams.Version
  ( ConoptVersion
  , GamsVersion
  , VersionError
  , parse_conopt_version
  , parse_gams_version
  )
import Store.Types (sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- The names in the run directory
-- ---------------------------------------------------------------------------------------------

-- | The put file @volume_path.gms@ writes, relative to @curdir@.
artifact_name :: FilePath
artifact_name = "volume_path.json"

-- | The log @lo=2@ writes, relative to @curdir@. Both version banners are read from HERE and never
-- from a stream.
log_name :: FilePath
log_name = "volume_path.log"

-- | Written into the fresh directory immediately before the spawn, so the freshness conjunct has a
-- reference point taken from the SAME filesystem as the artifact rather than from a clock this
-- process happens to hold.
run_marker_name :: FilePath
run_marker_name = ".cfmm-run-start"

-- ---------------------------------------------------------------------------------------------
-- The types
-- ---------------------------------------------------------------------------------------------

-- | Everything the invocation needs, handed over explicitly.
--
-- Nothing here is resolved from the ambient environment by this module. 'Gams.Config' names the
-- three variables exactly once, and a caller resolves them there; a second resolver here would be
-- a second place for the same value to differ.
data RunRequest = RunRequest
  { rr_binary       :: !FilePath
    -- ^ ABSOLUTE path to the @gams@ executable. A relative name -- or a bare one resolved through
    -- @PATH@ -- is a shadow surface: the binary that ran is then a property of the caller's
    -- environment rather than of this request, and 'ti_gams_sha256' would be digesting whichever
    -- file the lookup happened to find. Refused, by name, below.
  , rr_model        :: !FilePath
    -- ^ ABSOLUTE path to the @.gms@. Its basename is the job name every banner is judged against.
  , rr_shock        :: !Shock
  , rr_env          :: !(Maybe [(String, String)])
    -- ^ @Just@ 'Gams.Env.whitelist_for' in production. @Nothing@ means INHERIT, and it exists so a
    -- check can spawn the same function both ways and observe the difference in the child's own
    -- environment vector.
  , rr_budget_s     :: !Int
    -- ^ seconds handed to @timeout(1)@.
  , rr_kill_after_s :: !Int
    -- ^ the @-k@ grace: how long after the TERM before the group is killed.
  } deriving (Eq, Show)

-- | WHICH TOOLCHAIN PRODUCED THESE BYTES. Phase 25 folds this into the content key.
data ToolchainIdentity = ToolchainIdentity
  { ti_gams_version   :: !GamsVersion
  , ti_conopt_version :: !(Maybe ConoptVersion)
    -- ^ @Nothing@ when the log carries no CONOPT banner. That is legitimate ONLY for a run that
    -- never reached the solver -- which is unreachable from a 'Produced' outcome, so a check on the
    -- clean path asserts it is present rather than letting the @Nothing@ stand unexamined.
  , ti_gams_path      :: !FilePath
  , ti_gams_sha256    :: !String
    -- ^ BARE lowercase hex, no @0x@ prefix. A @0x@-prefixed 64-hex literal anywhere under
    -- @offchain\/@ reddens @sc3_literal_purge@, and this value ends up in messages and artifacts.
  , ti_model_sources  :: ![(FilePath, String)]
    -- ^ sorted @(path, sha256)@. A LIST rather than one digest: @volume_path.gms@ has zero
    -- @$include@ directives today, so the list has one element, and the day it gains one the shape
    -- already fits.
  } deriving (Eq, Show)

-- | Captured FOR DIAGNOSIS ONLY. No decision in this module reads any of these three fields.
data CapturedStreams = CapturedStreams
  { cs_stdout  :: !BS.ByteString
    -- ^ diagnosis only. MEASURED 0 bytes under @lo=2@ in every GAMS mode.
  , cs_stderr  :: !BS.ByteString
    -- ^ diagnosis only. MEASURED 0 bytes under @lo=2@ in every GAMS mode -- which is why a layer
    -- that read this for a verdict would report the same thing on a clean solve and on a crash.
  , cs_log     :: !BS.ByteString
    -- ^ the run's own @volume_path.log@, verbatim. The version parse reads THIS, and a parse is not
    -- a verdict about the model: it either names the toolchain or aborts the run.
  , cs_run_dir :: !FilePath
    -- ^ A RECORDED FACT, not a decision input: the directory this invocation actually used. It is
    -- here so a check can observe that two invocations got two different directories and that
    -- neither survives -- claims that are otherwise arguments about code rather than observations.
    -- Empty ONLY when no directory was ever created, which happens exactly when the shock was
    -- refused before any spawn.
  } deriving (Eq, Show)

-- | Why an invocation produced nothing. Every constructor names its subject.
data AbortReason
  = NoArtifact
    -- ^ exit 0 and no @volume_path.json@ in the run directory. MEASURED with the real binary:
    -- @action=c@ produces exactly this shape.
  | StaleArtifact
    -- ^ a @volume_path.json@ older than the marker written just before the spawn.
  | ExitVerdict Verdict
    -- ^ the exit code did not classify as 'Solved'. @TimedOut Expired@ arrives here as plain exit
    -- 124 from @timeout(1)@, which is why the taxonomy has to carry it at all.
  | VersionUnreadable VersionError
    -- ^ DETECTION THAT FINDS NOTHING ABORTS THE RUN. A version that could not be read is not a
    -- version that is empty.
  | ArtifactRejected ArtifactError
  | EchoMismatch String String String
    -- ^ the field, the token SENT, the value the artifact echoed back.
  | ArgvRejected ArgvError
    -- ^ refused before any process was spawned.
  | NotAbsolute String FilePath
    -- ^ the field name and the relative path it carried.
  deriving (Eq, Show)

-- | THE ONLY CONSTRUCTOR CARRYING BYTES IS 'Produced'.
--
-- There is deliberately no total @ProverOutcome -> ProverArtifact@ anywhere in this module. See
-- this module's header: that absence is Correction 1 stated at the type level, and the GHC error it
-- produces was OBSERVED rather than argued.
data ProverOutcome
  = Produced !ProverArtifact !ToolchainIdentity !CapturedStreams
  | Aborted !AbortReason !Int !CapturedStreams
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The edge
-- ---------------------------------------------------------------------------------------------

-- | The ONE function in this phase that spawns a process.
run_prover :: RunRequest -> IO ProverOutcome
run_prover request
  | not (isAbsolute (rr_binary request)) =
      pure (refused_before_spawn (NotAbsolute "rr_binary" (rr_binary request)))
  | not (isAbsolute (rr_model request)) =
      pure (refused_before_spawn (NotAbsolute "rr_model" (rr_model request)))
  | otherwise =
      case render_argv (rr_shock request) of
        Left why   -> pure (refused_before_spawn (ArgvRejected why))
        Right argv -> with_fresh_run_dir (spawn_into request argv)

-- | No process, no directory, no streams -- and the run directory is EMPTY rather than invented,
-- because there was none.
refused_before_spawn :: AbortReason -> ProverOutcome
refused_before_spawn why =
  Aborted why 0 (CapturedStreams BS.empty BS.empty BS.empty "")

-- | An exclusive directory under the system temp directory, removed on every exit path.
--
-- 'createDirectory' is the EXCLUSIVE form. Its permissive sibling -- the one that creates a
-- directory only when it is missing, and succeeds quietly when it is not -- is deliberately absent
-- from this module, and a source scan asserts that by name. Only the exclusive form makes \"this
-- directory did not exist a moment ago\" a fact rather than a hope.
--
-- The retry below is NOT a fallback. It recovers from exactly one condition -- the name is already
-- taken -- and it recovers by asking for a DIFFERENT name, never by reusing the one that was taken
-- and never by continuing without a directory. Every other 'IOError' is re-thrown unchanged.
with_fresh_run_dir :: (FilePath -> IO a) -> IO a
with_fresh_run_dir body = do
  tmp <- getTemporaryDirectory
  bracket (allocate tmp) removeDirectoryRecursive body
  where
    allocate tmp = do
      u <- newUnique
      let dir = tmp </> ("cfmm-gams-run-" ++ show (hashUnique u))
      made <- try (createDirectory dir)
      case made of
        Right () -> pure dir
        Left err
          | isAlreadyExistsError err -> allocate tmp
          | otherwise                -> throwIO err

-- | The invocation, in the order the conjuncts are stated in this module's header.
spawn_into :: RunRequest -> [String] -> FilePath -> IO ProverOutcome
spawn_into request argv run_dir = do
  let marker = run_dir </> run_marker_name
  BS.writeFile marker BS.empty
  t0 <- getModificationTime marker
  -- The freshness conjunct is handed DOWN as a predicate rather than as a timestamp, so the one
  -- reference point lives in the one place it is taken and nothing downstream can compare against a
  -- different clock. @>=@ and not @>@: a filesystem whose timestamp resolution is coarser than the
  -- spawn would otherwise report a genuinely fresh artifact as stale.
  let is_fresh path = do
        written <- getModificationTime path
        pure (written >= t0)
  let wrapper_argv =
        [ "-k"
        , show (rr_kill_after_s request)
        , show (rr_budget_s request)
        , rr_binary request
        , rr_model request
        , "action=ce"
        , "curdir=" ++ run_dir
        , "lo=2"
        ] ++ argv
      spec = (proc "/usr/bin/timeout" wrapper_argv)
               { cwd = Just run_dir
               , env = rr_env request
               }
  -- 'readCreateProcessWithExitCode' forks two DRAINING threads -- MEASURED swallowing 2,000,000
  -- bytes of stderr with no deadlock -- so the pipe hazard is closed by construction rather than by
  -- a hand-rolled reader pair. The 'timeout' around it is a BACKSTOP for the one case @timeout(1)@
  -- cannot cover, namely @timeout(1)@ itself being absent.
  backstopped <- timeout ((rr_budget_s request + backstop_slack_s) * 1000000)
                   (readCreateProcessWithExitCode spec "")
  log_bytes <- read_if_present (run_dir </> log_name)
  case backstopped of
    Nothing ->
      pure (Aborted (ExitVerdict (TimedOut Killed)) backstop_no_exit_code
              (CapturedStreams BS.empty BS.empty log_bytes run_dir))
    Just (code, out, err) -> do
      let streams = CapturedStreams
                      { cs_stdout  = C8.pack out
                      , cs_stderr  = C8.pack err
                      , cs_log     = log_bytes
                      , cs_run_dir = run_dir
                      }
          seen = case code of
                   ExitSuccess    -> 0
                   ExitFailure n  -> n
      case classify_exit code of
        Solved -> conjuncts request argv run_dir is_fresh log_bytes streams
        other  -> pure (Aborted (ExitVerdict other) seen streams)

-- | Conjuncts 2 through 6, in order, over a run that exited 0.
conjuncts
  :: RunRequest -> [String] -> FilePath -> (FilePath -> IO Bool) -> BS.ByteString -> CapturedStreams
  -> IO ProverOutcome
conjuncts request argv run_dir is_fresh log_bytes streams = do
  let artifact_path = run_dir </> artifact_name
  there <- doesFileExist artifact_path
  if not there
    then pure (Aborted NoArtifact 0 streams)
    else do
      fresh <- is_fresh artifact_path
      if not fresh
        then pure (Aborted StaleArtifact 0 streams)
        else do
          -- The BYTE reader, never the one the Prelude exports: that one hands back a 'String'
          -- decoded with the handle's locale and translating newlines, so the oracle 'pa_bytes'
          -- would be a RENDERING of the artifact rather than the artifact. (Its qualified name is
          -- not spelled here for the reason recorded in this module's header.)
          bytes <- BS.readFile artifact_path
          case decode_artifact bytes of
            Left why -> pure (Aborted (ArtifactRejected why) 0 streams)
            Right artifact ->
              case echo_conjunct argv artifact of
                Left (field, sent, got) -> pure (Aborted (EchoMismatch field sent got) 0 streams)
                Right () ->
                  case parse_gams_version (takeFileName (rr_model request)) log_bytes of
                    Left why -> pure (Aborted (VersionUnreadable why) 0 streams)
                    Right gams -> do
                      binary_bytes <- BS.readFile (rr_binary request)
                      model_bytes  <- BS.readFile (rr_model request)
                      let identity = ToolchainIdentity
                            { ti_gams_version   = gams
                            , ti_conopt_version =
                                either (const Nothing) Just (parse_conopt_version log_bytes)
                            , ti_gams_path      = rr_binary request
                            , ti_gams_sha256    = sha256_hex binary_bytes
                            , ti_model_sources  =
                                sort [(rr_model request, sha256_hex model_bytes)]
                            }
                      pure (Produced artifact identity streams)

-- | The two echoed fields, compared against the tokens 'Gams.Argv.render_argv' actually emitted.
--
-- The comparison is between two STRINGS and neither side was rebuilt from a number, which is the
-- whole point: two spellings of one value would compare unequal and one spelling of two values
-- would compare equal, so a comparison made on numbers would be measuring something other than what
-- reached the @execve@.
echo_conjunct :: [String] -> ProverArtifact -> Either (String, String, String) ()
echo_conjunct argv artifact = do
  _ <- one "sqrtPriceX96" "--sqrtPriceX96=" (pa_sqrt_price_x96_text artifact)
  one "liquidityRaw" "--liquidityRaw=" (pa_liquidity_text artifact)
  where
    one :: String -> String -> String -> Either (String, String, String) ()
    one field prefix got =
      case [drop (length prefix) token | token <- argv, prefix `isPrefixOf` token] of
        (sent : _)
          | sent == got -> Right ()
          | otherwise   -> Left (field, sent, got)
        [] -> Left (field, no_such_token, got)

-- | Stated rather than left as @\"\"@, because an empty \"what was sent\" reads as a value that was
-- sent and was empty. 'Gams.Argv.render_argv' emits both tokens unconditionally, so this is
-- unreachable -- and an unreachable branch that reported an empty string would be indistinguishable
-- from a reachable one that did.
no_such_token :: String
no_such_token = "<no such token in the rendered argv>"

-- | The log, or an empty buffer when the run wrote none.
--
-- The empty buffer is NOT a default standing in for a measurement. It is diagnostic material, and
-- the only consumer that decides anything -- 'parse_gams_version' -- answers @Left EmptyInput@ on
-- it, which ABORTS the run. An absent log therefore fails loudly one step later rather than
-- silently here.
read_if_present :: FilePath -> IO BS.ByteString
read_if_present path = do
  there <- doesFileExist path
  if there then BS.readFile path else pure BS.empty

-- | The extra seconds the in-process backstop waits beyond the budget handed to @timeout(1)@.
backstop_slack_s :: Int
backstop_slack_s = 5

-- | THERE WAS NO EXIT STATUS. The backstop fired, which means the wrapper never returned one.
--
-- @-1@ is not a byte any process can exit with, so it cannot be mistaken for an observed code --
-- which is the point. Recording @0@ here would say \"GAMS ran\" about a run whose outcome is that
-- nothing came back, and recording @124@ or @137@ would manufacture a measurement out of a
-- mechanism that did not report one. The load-bearing part is the 'AbortReason'.
backstop_no_exit_code :: Int
backstop_no_exit_code = -1
