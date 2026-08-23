-- |
-- The loop's environment, and its COMPLETE exit-code table, in one place.
--
-- Two things live here and they live here together on purpose: everything an operator can set from
-- outside the process, and everything the process can say on its way out. Both are surfaces a
-- reader consults from a shell script or a CI log, and a surface stated in two places is a surface
-- that disagrees with itself the first time one of them is edited.
--
-- THE TABLE WAS COMPLETE ON DAY ONE FOR THE CONDITIONS THAT EXISTED, AND 28-05 ADDED A TENTH
-- ------------------------------------------------------------------------------------------
-- 'exit_table' already named the conditions plans 28-03, 28-04 and 28-05 would raise -- the
-- missing fixture directory, the unreachable ledger, the unresolvable prover paths. That is
-- deliberate. A table that grows one code per plan is a table nothing can assert is TOTAL: the
-- check over it would be comparing a list against the constructors that happen to exist today, and
-- would agree with every future in which a code was forgotten. Every 'Halt' and every
-- 'Precondition' maps to a code here, the codes are pairwise distinct, and the suite says so.
--
-- What 28-05 added is not a code for a condition that was already reachable and unnamed: it is a
-- code for a condition that did not EXIST until the iteration was wrapped. Before 28-05 an
-- exception escaping a stage of 'Loop.Run.process_block' killed the process with a bare Haskell
-- exception and no exit code from any table at all; 'HaltBlockException' is what that becomes, and
-- the totality check is what REQUIRED the entry rather than merely permitting it. A table that
-- grows because a new condition was created is a different thing from a table that grows because
-- an old one was forgotten, and only the second is the failure the paragraph above is about.
--
-- WHY THESE NUMBERS AND NOT SMALLER ONES
-- --------------------------------------
-- The whole domain is chosen to be DISJOINT from the prover's. @Gams.Exit.gams_code_domain@ holds
-- the images of every status the solver's own table can produce, and a loop exiting inside that
-- domain for a reason of its own would be indistinguishable, in a CI log, from a solver status a
-- later reader looks up in the vendor's documentation. The timeout wrapper's two codes are avoided
-- for the same reason and by the same argument. The specific numerals are NOT restated in this
-- module: they are held by the modules that own them, and
-- 'the_loop_exit_codes_are_total_and_disjoint_from_the_gams_domain' compares this table against
-- those lists rather than against a transcription of them.
--
-- Thirty-something is the halting family: the loop ran and stopped. Forty-something is the
-- precondition family: the loop never started. That split is what lets an operator read the first
-- digit and know whether anything was processed at all.
module Loop.Config
  ( -- * The poll interval
    loop_poll_ms_env_var
  , default_poll_ms
  , poll_ms_from
  , loop_poll_ms
    -- * Where the fixture is published
  , fixture_dir_env_var
  , default_fixture_dir
  , fixture_file_name
  , default_fixture_path
  , fixture_dir_from
  , fixture_dir
    -- * The first block a loop with no watermark starts at
  , loop_first_block
    -- * What stops a running loop
  , Halt (..)
    -- * What stops a loop from starting
  , Precondition (..)
    -- * The table
  , exit_ok
  , exit_usage
  , exit_table
  , exit_code_for_halt
  , exit_code_for_precondition
  , halt_name
  ) where

import Control.Exception (throwIO)
import Data.Char (isDigit)
import System.Environment (lookupEnv)
import System.FilePath ((</>))

import Loop.Ledger (EventId)

-- ---------------------------------------------------------------------------------------------
-- The poll interval
-- ---------------------------------------------------------------------------------------------

-- | The one place this variable is NAMED, following the @Store.Config@ / @Gams.Config@ idiom.
loop_poll_ms_env_var :: String
loop_poll_ms_env_var = "LOOP_POLL_MS"

-- | Milliseconds between head polls when the loop is caught up. 28-CONTEXT's ruling.
default_poll_ms :: Int
default_poll_ms = 1000

-- | THE RULE, AS A PURE FUNCTION OF WHAT @lookupEnv@ HANDS BACK.
--
-- Pure because the state that matters cannot be created from inside this process:
-- @System.Environment.setEnv k ""@ routes an empty value to @unsetEnv@, so a check that tried to
-- drive the present-but-empty case through the environment would be driving the ABSENT case twice
-- and reporting on the empty one. 27-01 MEASURED a whole check being vacuous on exactly that, and
-- the repair was to make the rule a function of the @Maybe@ so the argument can be supplied
-- directly.
--
-- Three answers, and the third is the point. Absent is the default. A positive integer is itself.
-- Anything else -- an empty value, a negative one, a word, a value with a unit glued on -- is a
-- REFUSAL naming what was read. It is never a silent return to the default: an operator who typed
-- a poll interval and got the default instead has an override that is advertised and dead, which
-- is this repository's most-measured defect.
poll_ms_from :: Maybe String -> Either String Int
poll_ms_from Nothing = Right default_poll_ms
poll_ms_from (Just raw)
  | null raw =
      Left (loop_poll_ms_env_var ++ " is set and EMPTY. An empty value is not a poll interval, and"
             ++ " resolving it to the default would report an operator's typo as a working"
             ++ " override.")
  | not (all isDigit raw) =
      Left (loop_poll_ms_env_var ++ " is set to " ++ show raw ++ ", which is not a decimal integer."
             ++ " It is REFUSED rather than defaulted: a loop that polled at the default after"
             ++ " being told to poll at something else would be advertising an override it does"
             ++ " not honour.")
  | otherwise =
      case reads raw :: [(Integer, String)] of
        [(n, "")]
          | n <= 0 ->
              Left (loop_poll_ms_env_var ++ " is set to " ++ show raw ++ ", and a poll interval of"
                     ++ " zero is a busy loop rather than a cadence.")
          | n > toInteger (maxBound :: Int) ->
              Left (loop_poll_ms_env_var ++ " is set to " ++ show raw ++ ", which does not fit the"
                     ++ " machine's own integer. Truncating it would produce a cadence nobody"
                     ++ " asked for.")
          | otherwise -> Right (fromInteger n)
        _ ->
          Left (loop_poll_ms_env_var ++ " is set to " ++ show raw ++ " and could not be read as a"
                 ++ " number at all.")

-- | The rule, through the environment. A refusal is raised rather than swallowed.
loop_poll_ms :: IO Int
loop_poll_ms = do
  raw <- lookupEnv loop_poll_ms_env_var
  case poll_ms_from raw of
    Right ms  -> pure ms
    Left  why -> throwIO (userError ("Loop.Config: " ++ why))

-- ---------------------------------------------------------------------------------------------
-- Where the fixture is published
-- ---------------------------------------------------------------------------------------------

-- | The one place this variable is NAMED, following the same idiom as the cadence above.
--
-- ONE RESOLVER, an env override, a repo-relative default -- 28-CONTEXT rules this is exactly the
-- @Chain.Endpoint@ shape, and the reason it is a resolver rather than a constant is that
-- @cabal test@ must be able to aim a publication somewhere harmless. The real directory belongs to
-- another workstream and does not exist in this worktree; every publication check in the suite
-- points this variable at a temporary directory it created moments earlier.
fixture_dir_env_var :: String
fixture_dir_env_var = "FIXTURE_DIR"

-- | The DIRECTORY the consuming forge test reads its fixture out of, relative to the repository
-- root.
--
-- Stated ONCE, here. It is the @mev_tax_model_one@ track\'s directory (GitHub issues #24 and #25)
-- and the loop never creates it -- LOOP-04. Plan 28-04 asserts the joined path below against the
-- consuming test on @origin\/develop@ rather than against a copy of the string kept here, which is
-- the only comparison that can see the two drifting apart.
default_fixture_dir :: FilePath
default_fixture_dir = "test/models/mev_tax_model_one/fixtures"

-- | The file name, FIXED. The consuming test names one path and there is exactly one fixture.
fixture_file_name :: FilePath
fixture_file_name = "volume_path.json"

-- | The default path, joined once so no caller joins it a second time.
--
-- Byte-equal to the consuming test\'s own @VOLUME_PATH_JSON@ constant. That equality is the whole
-- contract of issue #25 and it is asserted by plan 28-04 against the file on @origin\/develop@.
default_fixture_path :: FilePath
default_fixture_path = default_fixture_dir </> fixture_file_name

-- | THE RULE, AS A PURE FUNCTION OF WHAT @lookupEnv@ HANDS BACK.
--
-- Pure for the reason \'poll_ms_from\' is pure: @System.Environment.setEnv k ""@ routes an empty
-- value to @unsetEnv@, so the present-but-EMPTY case cannot be created from inside this process
-- and a check that tried would be driving the absent case twice while reporting on the empty one.
-- 27-01 MEASURED a whole check going vacuous on exactly that.
--
-- An empty value resolves to the DEFAULT here, and that is the opposite of the cadence\'s ruling
-- one section up. The two differ because the failures differ: an unreadable cadence has no
-- interpretation at all, while an empty directory string would resolve to the process\'s working
-- directory and publish the fixture into the repository root -- a real file, in the wrong place,
-- with nothing to say so. Falling back to the declared default puts the miss where LOOP-04\'s
-- missing-directory precondition can see it.
fixture_dir_from :: Maybe String -> FilePath
fixture_dir_from (Just raw) | not (null raw) = raw
fixture_dir_from _                           = default_fixture_dir

-- | The rule, through the environment.
fixture_dir :: IO FilePath
fixture_dir = fixture_dir_from <$> lookupEnv fixture_dir_env_var

-- ---------------------------------------------------------------------------------------------
-- The first block
-- ---------------------------------------------------------------------------------------------

-- | Where a loop with NO watermark starts scanning.
--
-- Genesis, and it is stated here rather than defaulted to the current head, because a loop that
-- starts at the head has already skipped every event before it. That is the LOOP-01 bug in its
-- purest form and it is invisible on a chain that has not produced an event yet -- which is every
-- chain, for the first few minutes of every test.
loop_first_block :: Integer
loop_first_block = 0

-- ---------------------------------------------------------------------------------------------
-- What stops a running loop
-- ---------------------------------------------------------------------------------------------

-- | The five ways a loop that STARTED can stop, each carrying what a post-mortem needs.
--
-- Every one of these leaves the watermark where it was, so the block is re-processed on restart.
-- That is the whole of LOOP-05 on this side: the halt happens BEFORE the commit, not after it.
data Halt
  = HaltUnsolvable EventId
    -- ^ an ADMISSIBLE shock the prover could not answer, naming the event. 28-CONTEXT's ruling:
    -- this is a statement about the model, not about the event, so the next event would be
    -- expected to fail the same way and processing past it turns one finding into a silent stretch
    -- of them.
  | HaltRpcExhausted Integer Int
    -- ^ the block, and the number of attempts made against the chain before giving up. Nothing is
    -- recorded as an event outcome: the block never produced one.
  | HaltDb String
    -- ^ the ledger or the store refused, carrying what it said. The transaction never committed,
    -- so there is nothing to undo.
  | HaltSolverException String
    -- ^ the solver seam threw rather than returning an outcome. Distinct from 'HaltUnsolvable' on
    -- purpose: an exception is a fact about the process, and recording it as an infeasibility
    -- verdict would manufacture a scientific claim out of a crash.
  | HaltBlockException Integer String
    -- ^ 28-05. AN EXCEPTION ESCAPED A STAGE OF THE ITERATION, carrying the block it escaped from
    -- and what was thrown.
    --
    -- The three classes above are the ones a caller CAN tell apart, because each is raised at a
    -- site that knows what it was doing: the solver seam, the ledger, the pinned read. This one is
    -- the outer wrapper around the whole iteration, and it is deliberately NOT mapped onto one of
    -- them. An outer wrapper genuinely cannot tell which stage threw -- the log fetch, the replay
    -- lookup, the toolchain stash -- and reporting a chain failure as 'HaltDb' would put a wrong
    -- diagnosis in a ledger-shaped post-mortem, which is the same conflation 28-01 refused to add
    -- an @AbortReason@ constructor for.
    --
    -- What it guarantees is the only thing LOOP-05 asks: the block was abandoned WITHOUT a commit.
    -- 'Loop.Ledger.ledger_commit_block' is the last statement of the iteration and nothing before
    -- it writes anything, so an exception from any earlier stage leaves the watermark where it was
    -- and the block is re-processed on restart.
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- What stops a loop from starting
-- ---------------------------------------------------------------------------------------------

-- | The five ways a loop can fail BEFORE its first block, each naming its subject.
--
-- Three of these have no producer yet -- the fixture resolver arrives with 28-03 and the ledger
-- and prover-path failures are wired in 28-02's own executable. They are declared now for the
-- reason the module header gives: a table that grows one code per plan is a table nothing can
-- assert is total.
data Precondition
  = FixtureDirMissing FilePath
    -- ^ LOOP-04. The loop NEVER creates the publication directory; a missing one is a failure
    -- naming the path and the workstream that owns it.
  | ToolchainUnreadable String
    -- ^ 'Gams.Detect.detect_toolchain' or 'Store.Key.key_identity' refused, carrying the reason.
  | EndpointUnresolvable String
  | ProverPathsUnresolvable String
    -- ^ the binary or the model could not be resolved. This is a STARTUP fact and it is reported
    -- here rather than as an @AbortReason@ inside the solver seam -- 28-01's ruling, because a
    -- startup fact recorded under the same discriminator as a solver failure is exactly the
    -- conflation S3 exists to prevent.
  | LedgerUnreachable String
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The table
-- ---------------------------------------------------------------------------------------------

-- | Drained, or the requested pass completed. The only zero.
exit_ok :: Int
exit_ok = 0

-- | THE PROCESS WAS INVOKED WRONGLY, which is neither a halt nor a precondition.
--
-- It is not in 'exit_table' for the same reason 'exit_ok' is not: the table is about the two
-- families a RUN can end in, and a command line that was never a valid invocation ended no run.
-- The value is the conventional usage status, and the suite asserts it is distinct from every
-- entry of the table and outside the prover's domain along with them.
exit_usage :: Int
exit_usage = 64

-- | THE COMPLETE TABLE, name to code, stated once.
--
-- The names are the ones a runbook uses; the codes are what a shell sees. Ten non-zero entries,
-- one per constructor of 'Halt' and 'Precondition' between them, and the suite asserts both
-- directions.
exit_table :: [(String, Int)]
exit_table =
  [ ("halt_unsolvable",          30)
  , ("halt_rpc_exhausted",       31)
  , ("halt_db",                  32)
  , ("halt_solver_exception",    33)
  , ("halt_block_exception",     34)
  , ("precondition_fixture_dir", 40)
  , ("precondition_toolchain",   41)
  , ("precondition_endpoint",    42)
  , ("precondition_prover_paths", 43)
  , ("precondition_ledger",      44)
  ]

-- | The code, THROUGH the table, so the table is the only statement of it.
--
-- The lookup cannot miss: every name below is in 'exit_table' and the suite asserts that as a set.
-- The miss branch returns a code that is in neither family precisely so that a future edit which
-- broke the correspondence would produce an obviously wrong number rather than a plausible one.
exit_code_for_halt :: Halt -> Int
exit_code_for_halt = coded . halt_name

-- | The runbook NAME of a halt, exported so a caller can say which condition ended the run without
-- keeping a second table of its own.
--
-- @offchain\/app\/LoopMain.hs@ prints it on the final machine-readable line beside the code, and
-- the code is 'exit_code_for_halt' of the same value -- so the line and the status byte cannot
-- disagree about which condition they describe.
halt_name :: Halt -> String
halt_name (HaltUnsolvable _)         = "halt_unsolvable"
halt_name (HaltRpcExhausted _ _)     = "halt_rpc_exhausted"
halt_name (HaltDb _)                 = "halt_db"
halt_name (HaltSolverException _)    = "halt_solver_exception"
halt_name (HaltBlockException _ _)   = "halt_block_exception"

-- | The code for a precondition failure, through the same table.
exit_code_for_precondition :: Precondition -> Int
exit_code_for_precondition p = coded (precondition_name p)
  where
    precondition_name (FixtureDirMissing _)       = "precondition_fixture_dir"
    precondition_name (ToolchainUnreadable _)     = "precondition_toolchain"
    precondition_name (EndpointUnresolvable _)    = "precondition_endpoint"
    precondition_name (ProverPathsUnresolvable _) = "precondition_prover_paths"
    precondition_name (LedgerUnreachable _)       = "precondition_ledger"

-- | The one lookup, so neither function above states a number.
coded :: String -> Int
coded name =
  case [c | (n, c) <- exit_table, n == name] of
    (c : _) -> c
    []      -> unnamed_condition_code

-- | The code for a condition the table does not name, which is unreachable today and asserted so.
--
-- It sits outside both families deliberately: an unreachable branch that returned a plausible code
-- would look like a real answer on the day it stopped being unreachable.
unnamed_condition_code :: Int
unnamed_condition_code = 99
