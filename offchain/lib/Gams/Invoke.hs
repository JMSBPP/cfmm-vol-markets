-- |
-- THE MODULE THAT NAMES THE REAL PROVER, AND THE ONE MODULE @cabal test@ MAY NOT IMPORT.
--
-- Everything else in the GAMS layer is reachable from the suite. "Gams.Run" spawns a process, but
-- it is handed its binary and its model as ABSOLUTE PATHS by its caller, so the Tier-B checks drive
-- it against @\/bin\/sh@ stubs they wrote themselves and a contributor with no solver installed gets
-- the same verdict as the research machine. THIS module is where that stops: it reads
-- "Gams.Config", resolves a live executable and a live model out of the environment, and hands them
-- to 'Gams.Run.run_prover'. Importing it from the test suite would make @cabal test@ structurally
-- capable of reaching a solver, which is exactly the property plan 24-04 installed a scanning check
-- to forbid -- with a proven positive control, and with this module's name as one of its three
-- tokens.
--
-- So the import graph is the enforcement, and what it enforces is a DIRECTORY rather than a count:
-- every importer of this module is under @offchain\/app\/@ and none is under @offchain\/test\/@.
-- The importers are @GamsConformance.hs@, the capture executable, and @SpikeEndToEnd.hs@, the
-- throwaway end-to-end spike, which reaches this module for the two RESOLVERS only -- writing a
-- second resolver rather than importing this one is the failure this module's own resolution
-- section exists to prevent. Everything the suite knows about the real toolchain it knows from
-- @offchain\/rig\/gams-conformance.json@, which the capture executable writes out of band.
--
-- == RESOLUTION FAILS LOUDLY, AND IT FAILS BY NAME
--
-- Both resolvers return 'Left' carrying the ENVIRONMENT VARIABLE that steers them, because an
-- operator who sees \"the model was not found\" needs to know which of three variables to set. There
-- is no default that stands in for a measurement anywhere on this path: "Gams.Config" supplies a
-- bare executable name and a monorepo-relative model path, and both of those are inputs to a
-- resolution that either succeeds or says which variable to set.
--
-- @volume_path.gms@ IS ABSENT FROM THIS WORKTREE. It lives in the sibling GAMS worktree, whose
-- checkout carries the @model\/@ tree this branch does not, so @GAMS_MODEL@ is REQUIRED here rather
-- than optional and 'ModelMissing' names it.
--
-- == THE BINARY IS RESOLVED TO AN ABSOLUTE PATH, AND THAT REMOVES A SURFACE RATHER THAN POLICING IT
--
-- A bare name handed to @execve@ is looked up through @PATH@, so the file that ran is a property of
-- the caller's environment and the digest recorded beside it is a digest of whatever the lookup
-- happened to find. Resolving here with 'findExecutable' and then invoking by absolute path deletes
-- that surface: MEASURED at 24-RESEARCH M9, the GAMS directory need not be on @PATH@ at all for the
-- run to produce the golden bytes, so the whitelist can pin @PATH@ to one system directory and the
-- prover is still reached.
--
-- 'Gams.Run.run_prover' refuses a relative @rr_binary@ or @rr_model@ by name, so this module's
-- guarantee is checked again one layer down rather than trusted.
--
-- == 'raw_gams' EXISTS BECAUSE THE CAPTURE HAS TO DRIVE THE WRONG INVOCATIONS TOO
--
-- 'invoke_shock' is the production composition and it is total in the good sense: it renders a
-- canonical argv, hands it a whitelisted environment, and returns a 'ProverOutcome' whose 'Produced'
-- case is the only one carrying bytes. But four of the observations the conformance artifact records
-- are things the production path CANNOT DO -- a compile-only run, an invocation with no arguments at
-- all, the @--version@ flag that is really a filename, and an argv token with a leading zero that
-- 'Gams.Argv.render_argv' normalises away before any process exists. Those are driven through
-- 'raw_gams', which spawns the resolved binary with an argument vector its caller built and reports
-- what came back without judging it.
--
-- 'raw_gams' decides NOTHING. It returns an exit status, two stream buffers and whatever the run
-- directory ended up holding; every verdict about those values is written down in the capture
-- executable and asserted, offline, over the recorded numbers.
module Gams.Invoke
  ( -- * Resolution
    InvokeError (..)
  , resolve_gams_bin
  , resolve_gams_model
  , binary_identity
    -- * The production composition
  , EnvChoice (..)
  , environment_for
  , invoke_shock
    -- * The invocations the production path cannot make
  , RawRun (..)
  , raw_gams
  , raw_budget_s
  , raw_kill_after_s
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import System.Directory
  ( doesFileExist
  , findExecutable
  , getHomeDirectory
  , makeAbsolute
  )
import System.Exit (ExitCode (..))
import System.FilePath (isPathSeparator, (</>))
import System.Process
  ( CreateProcess (..)
  , proc
  , readCreateProcessWithExitCode
  )

import Gams.Argv (Shock)
import Gams.Config (gams_bin, gams_bin_env_var, gams_model, gams_model_env_var)
import Gams.Env (whitelist_for)
import Gams.Run
  ( ProverOutcome
  , RunRequest (..)
  , artifact_name
  , log_name
  , run_prover
  )
import Store.Types (sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- Resolution
-- ---------------------------------------------------------------------------------------------

-- | Why the live toolchain could not be reached. Every constructor carries the NAME of the
-- environment variable that steers it, so the message an operator sees identifies the knob.
data InvokeError
  = BinaryNotFound String FilePath
    -- ^ the variable name, and the value that did not resolve to a file
  | ModelMissing String FilePath
    -- ^ the variable name, and the absolute path that does not exist
  deriving (Eq, Show)

-- | The @gams@ executable, ABSOLUTE.
--
-- A configured value carrying a path separator is taken as a path and made absolute; a bare name is
-- looked up with 'findExecutable' and the ANSWER is made absolute. Either way what leaves this
-- function is a path, never a name, and a lookup that found nothing is a 'Left' naming @GAMS_BIN@
-- rather than a bare name passed downstream for @execve@ to resolve a second time.
resolve_gams_bin :: IO (Either InvokeError FilePath)
resolve_gams_bin = do
  configured <- gams_bin
  if any isPathSeparator configured
    then do
      absolute <- makeAbsolute configured
      there    <- doesFileExist absolute
      pure $ if there
               then Right absolute
               else Left (BinaryNotFound gams_bin_env_var absolute)
    else do
      found <- findExecutable configured
      case found of
        Nothing   -> pure (Left (BinaryNotFound gams_bin_env_var configured))
        Just path -> Right <$> makeAbsolute path

-- | The @.gms@ that is invoked, ABSOLUTE, and it must EXIST.
--
-- The default is monorepo-relative and this worktree does not carry @model\/@, so on this branch
-- the resolution below fails unless @GAMS_MODEL@ is set -- which is the intended behaviour and the
-- reason the failure names the variable and quotes the path it looked for.
resolve_gams_model :: IO (Either InvokeError FilePath)
resolve_gams_model = do
  configured <- gams_model
  absolute   <- makeAbsolute configured
  there      <- doesFileExist absolute
  pure $ if there
           then Right absolute
           else Left (ModelMissing gams_model_env_var absolute)

-- | @(sha256 of the file, its size in bytes)@ -- the two facts GAMS-03 wants recorded about the
-- executable, because they are what a wrapper script or a @PATH@ shadow cannot lie about.
--
-- The digest is BARE lowercase hex. A @0x@-prefixed 64-hex literal anywhere under @offchain\/@
-- reddens @sc3_literal_purge@, and this value is written into a committed artifact.
--
-- Both numbers are MACHINE-SPECIFIC and neither is ever pinned in Haskell: the suite asserts their
-- SHAPE and their cross-consistency with the rest of the document, so a capture taken on another
-- install still reads as evidence rather than as a failure.
binary_identity :: FilePath -> IO (String, Integer)
binary_identity path = do
  bytes <- BS.readFile path
  pure (sha256_hex bytes, toInteger (BS.length bytes))

-- ---------------------------------------------------------------------------------------------
-- The production composition
-- ---------------------------------------------------------------------------------------------

-- | Which environment vector the child gets.
--
-- Spelled as a two-constructor type rather than as @Maybe [(String, String)]@ on purpose:
-- 'Gams.Run.rr_env' already uses 'Nothing' to mean INHERIT, so a 'Maybe' here would put two
-- opposite meanings on one shape at two layers of the same call. 'WhitelistEnv' is what production
-- uses; 'ExactEnv' exists so the capture can drive the identical function with the minimal vector
-- and with the hostile one and compare the BYTES all three produced.
data EnvChoice
  = WhitelistEnv
  | ExactEnv [(String, String)]
  deriving (Eq, Show)

-- | Resolve the toolchain and run the shock through it.
--
-- This is the whole of the production path: two resolutions, one environment vector, one
-- 'Gams.Run.run_prover'. Not one conjunct of the verdict is re-decided here -- @run_prover@ owns all
-- six, and a second opinion in this module would be a second place for the same question to be
-- answered differently.
invoke_shock :: EnvChoice -> Shock -> IO (Either InvokeError ProverOutcome)
invoke_shock choice shock = do
  resolved_bin <- resolve_gams_bin
  case resolved_bin of
    Left why -> pure (Left why)
    Right binary -> do
      resolved_model <- resolve_gams_model
      case resolved_model of
        Left why -> pure (Left why)
        Right model -> do
          environment <- environment_for choice
          outcome <- run_prover RunRequest
            { rr_binary       = binary
            , rr_model        = model
            , rr_shock        = shock
            , rr_env          = Just environment
            , rr_budget_s     = raw_budget_s
            , rr_kill_after_s = raw_kill_after_s
            }
          pure (Right outcome)

-- | @HOME@ comes from the machine; the other two pairs are decisions and they live in "Gams.Env".
--
-- EXPORTED so the capture can record the vector it ACTUALLY handed the child rather than a second
-- derivation of what it believes that vector to be. A recorded environment computed by an
-- expression other than the one that built it is the tautology this repository has already measured
-- seven representations of.
environment_for :: EnvChoice -> IO [(String, String)]
environment_for WhitelistEnv     = whitelist_for <$> getHomeDirectory
environment_for (ExactEnv pairs) = pure pairs

-- ---------------------------------------------------------------------------------------------
-- The invocations the production path cannot make
-- ---------------------------------------------------------------------------------------------

-- | What a raw invocation left behind. No field is a judgement.
data RawRun = RawRun
  { raw_exit     :: !Int
    -- ^ the wrapper's exit status. @124@ is @timeout(1)@ expiring, @137@ is the @-k@ SIGKILL, and
    -- neither collides with the mod-256 image of GAMS's own table.
  , raw_stdout   :: !BS.ByteString
  , raw_stderr   :: !BS.ByteString
    -- ^ MEASURED 0 bytes in every GAMS mode. Recorded so the capture can say so with a number.
  , raw_artifact :: !(Maybe BS.ByteString)
    -- ^ @volume_path.json@ in the working directory, if the run wrote one. 'Nothing' is the
    -- OBSERVATION that GAMS-02 exists for and it is distinct from @Just ""@.
  , raw_log      :: !(Maybe BS.ByteString)
    -- ^ @volume_path.log@ in the working directory, if the run wrote one.
  } deriving (Eq, Show)

-- | The wrapper that owns the process GROUP. GAMS runs CONOPT at @Solvelink=2@ as a separate
-- process, so a kill that reached only the direct child would leave a solver behind.
timeout_wrapper :: FilePath
timeout_wrapper = "/usr/bin/timeout"

-- | Seconds. Generous, because this is a capture and a real solve is the point; the value exists so
-- that a wedged toolchain fails the capture instead of hanging it.
raw_budget_s :: Int
raw_budget_s = 120

-- | The @-k@ grace between the TERM and the group KILL.
raw_kill_after_s :: Int
raw_kill_after_s = 5

-- | Spawn the resolved binary with an argument vector the CALLER built, in a directory the CALLER
-- made, with an environment the CALLER chose.
--
-- Every one of those is the caller's because this function's whole purpose is the invocations the
-- production path refuses to construct: no arguments at all, a flag that is really a filename,
-- @action=c@, and an argv token 'Gams.Argv.render_argv' normalises away. A function that supplied
-- any of them would be the production path again under another name.
--
-- 'readCreateProcessWithExitCode' forks two draining threads -- MEASURED swallowing 2,000,000 bytes
-- of stderr with no deadlock -- so the pipe hazard is closed by construction here as it is in
-- "Gams.Run".
raw_gams :: FilePath -> FilePath -> [(String, String)] -> [String] -> IO RawRun
raw_gams binary work_dir environment args = do
  let wrapper_argv =
        ["-k", show raw_kill_after_s, show raw_budget_s, binary] ++ args
      spec = (proc timeout_wrapper wrapper_argv)
               { cwd = Just work_dir
               , env = Just environment
               }
  (code, out, err) <- readCreateProcessWithExitCode spec ""
  artifact <- read_if_there (work_dir </> artifact_name)
  logged   <- read_if_there (work_dir </> log_name)
  pure RawRun
    { raw_exit     = exit_status code
    , raw_stdout   = C8.pack out
    , raw_stderr   = C8.pack err
    , raw_artifact = artifact
    , raw_log      = logged
    }

-- | 'Nothing' means the file is not there, and that is a MEASUREMENT rather than a default: the
-- whole of GAMS-02 is that @action=c@ exits 0 and this answer is 'Nothing'. An empty buffer here
-- would report a file that exists and is empty, which is a different observation.
read_if_there :: FilePath -> IO (Maybe BS.ByteString)
read_if_there path = do
  there <- doesFileExist path
  if there then Just <$> BS.readFile path else pure Nothing

exit_status :: ExitCode -> Int
exit_status ExitSuccess     = 0
exit_status (ExitFailure n) = n
