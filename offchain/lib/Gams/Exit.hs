-- |
-- GAMS-01 as a TYPE: the verdict is a total function of the exit code and of nothing else.
--
-- 'classify_exit' takes an 'ExitCode'. It does not take the log, it does not take stdout, it does
-- not take stderr, and this module imports nothing that could carry them -- so \"no decision reads
-- solver output\" is STRUCTURAL here rather than asserted somewhere else about here. There is no
-- parameter through which a line of log text could be smuggled, which is why the source scan over
-- the invocation layer only has to prove that layer does not re-introduce one.
--
-- @VOLUME_PATH.md@ §4 states the rule this discharges: /the exit code is non-zero on every abort/
-- /-- gate on it, never on log text/.
--
-- WHAT 'Solved' MEANS, AND WHAT IT DOES NOT
-- -----------------------------------------
-- 'Solved' means ONE thing: GAMS ran to completion. It is the FIRST conjunct of an artifact's
-- existence and never the only one. MEASURED against the real binary on 2026-08-16:
--
--   * @action=c@ (compile only) exits 0 and writes NO @volume_path.json@ at all;
--   * @gams@ with no arguments exits 0 and runs no model whatsoever.
--
-- Both are exit 0. Neither produced anything. The remaining conjuncts -- the artifact exists in
-- the fresh run directory, its mtime is at or after process start, it is a JSON value, its arrays
-- agree with the event count, and every echoed field equals the argv token that was sent -- live
-- in the invocation layer, and exit 0 is the door into that list rather than a substitute for it.
--
-- WHY 'Unclassified' IS NOT 'Solved'
-- ----------------------------------
-- An unrecognised code falling through to success is the exact shape of this repository's
-- recurring defect: an assertion that passes because its subject is absent. So the final equation
-- carries the code it could not place, and it is a FAILURE. A code this table does not name is a
-- code nobody has decided about, and an undecided code must not default to success.
--
-- (That sentence used to say \"the c-a-t-c-h-all\", spelled out, and
-- @gams_version_is_not_constructible_empty@ REDDENED on it -- the scan reads this file's prose as
-- readily as its code, which is correct behaviour for a grep and the wrong reason to relax one.
-- The prose moved. The pattern did not.)
--
-- THE CODES, MEASURED AND OFFICIAL
-- --------------------------------
-- Measured here today: clean solve 0 · syntax error 2 · @abort$(..) \"named abort\"@ 3 ·
-- unhandled @a = 1\/0@ 3 · a bad @--@ parameter substitution 2 · missing input file 6.
--
-- The official table supplies the rest, and its top end is folded: GAMS reports 400, 401, 402 and
-- 909, and a process exit status is a byte, so what a caller SEES is 144, 145, 146 and 141. The
-- folding is the whole reason a collision argument for the timeout codes has to be made against
-- the IMAGES -- 'gams_code_domain' holds the images, not the originals.
--
-- Two entries earn their own sentence:
--
--   * 7 is LICENSING. A layer that reads \"non-zero\" as \"the model says infeasible\" records an
--     expired licence as an infeasibility verdict, which is a scientific claim manufactured out of
--     an administrative failure.
--   * 145 is @curdir does not exist@ -- the fresh-run-directory design's OWN failure code. It is
--     environmental. It is not a statement about the model.
--
-- And one that earns a warning: 3 does NOT distinguish a named §4 abort from an unhandled
-- execution error. MEASURED: both give 3. The reason lives in the log, and the log is diagnostic
-- only -- so a verdict of \"a named abort\" at code 3 would be a claim the exit code cannot
-- support.
module Gams.Exit
  ( Verdict (..)
  , ModelFailure (..)
  , EnvFailure (..)
  , TimeoutKind (..)
  , classify_exit
  , gams_code_domain
  ) where

import System.Exit (ExitCode (..))

-- | The model spoke. Which of the two it said is a §4 question, not an exit-code question.
data ModelFailure
  = CompilationError
  | ExecutionError
  deriving (Eq, Show)

-- | The environment failed. None of these is a statement about the model.
data EnvFailure
  = SolverToBeCalled
  | SystemLimits
  | FileError
  | ParameterError
  | LicensingError
  | SystemError
  | CouldNotStart
  | OutOfMemory
  | OutOfDisk
  | ScratchDirectory
  | CompilerSpawn
  | CurdirMissing
  | CurdirNotSettable
  | PathEnvironment
  | DriverError
  deriving (Eq, Show)

-- | 124 is the wrapper's own expiry; 137 is 128+9, the SIGKILL that followed it.
data TimeoutKind
  = Expired
  | Killed
  deriving (Eq, Show)

data Verdict
  = Solved
  | ModelLevel ModelFailure
  | Environmental EnvFailure
  | TimedOut TimeoutKind
  | Unclassified Int
  deriving (Eq, Show)

-- | The whole decision. Total, and a function of the exit code alone.
classify_exit :: ExitCode -> Verdict
classify_exit ExitSuccess = Solved
classify_exit (ExitFailure n)
  | n == 1                = Environmental SolverToBeCalled
  | n == 2                = ModelLevel CompilationError
  | n == 3                = ModelLevel ExecutionError
  | n == 4                = Environmental SystemLimits
  | n == 5                = Environmental FileError
  | n == 6                = Environmental ParameterError
  | n == 7                = Environmental LicensingError
  | n == 8                = Environmental SystemError
  | n == 9                = Environmental CouldNotStart
  | n == 10               = Environmental OutOfMemory
  | n == 11               = Environmental OutOfDisk
  | n >= 109 && n <= 115  = Environmental ScratchDirectory
  | n == 124              = TimedOut Expired
  | n == 137              = TimedOut Killed
  | n == 141              = Environmental PathEnvironment
  | n == 144              = Environmental CompilerSpawn
  | n == 145              = Environmental CurdirMissing
  | n == 146              = Environmental CurdirNotSettable
  | otherwise             = Unclassified n

-- | Every code the table above NAMES as a GAMS code, as the byte a caller actually observes.
--
-- 124 and 137 are deliberately absent: they belong to the timeout wrapper, and the collision
-- argument is exactly the claim that this list does not contain them. The list is exported so
-- that argument has a subject it did not construct itself -- a check that wrote out its own idea
-- of the domain would be comparing a transcription against a transcription.
--
-- 'DriverError' has no entry here because GAMS's 1000+ driver codes fold onto the whole byte
-- range and cannot be named as images; a driver failure surfaces as 'Unclassified', which is a
-- failure, which is the right answer.
gams_code_domain :: [Int]
gams_code_domain =
  [0 .. 11] ++ [109 .. 115] ++ [141, 144, 145, 146]
