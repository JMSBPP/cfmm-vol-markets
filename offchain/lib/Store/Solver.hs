-- |
-- THE SOLVER SEAM: the one thing @Store.Cache@ reaches for when a lookup misses, held as a field
-- of a record rather than called by name.
--
-- WHY A SEAM
-- ----------
-- STORE-01 says an identical shock skips the solve. \"Skips\" is a claim about a call that did NOT
-- happen, and a claim of that shape is satisfied by reading the code and nodding. Behind a record
-- field it is a MEASUREMENT instead: a test solver closes over a counter, increments it on every
-- invocation, and the elision check asserts the counter is zero. The record shape is the one
-- @Store.Class@ already argues for -- a deliberately-wrong instrument is one line of record update
-- rather than a new type and a new instance.
--
-- The counter alone is not enough and the check that uses this does not stop there: a solver that
-- RAN and whose bytes were then discarded passes a counter test the moment the counter is the only
-- thing asserted. So the elision check asserts the returned bytes are the STORED ones as well, and
-- hands this seam a solver whose bytes deliberately disagree with the store's.
--
-- WHY THE OUTCOME TYPE IS RE-EXPORTED RATHER THAN REDEFINED
-- ---------------------------------------------------------
-- @Gams.Run@ already has this sum, and it already carries every shape the cache has to tell apart:
-- 'Produced' with the bytes, and 'Aborted' with an 'AbortReason' that names @NoArtifact@ (exit 0
-- with nothing written -- MEASURED with the real binary under @action=c@), @ExitVerdict@ (the exit
-- code did not classify as solved, which is also how the timeout wrapper's 124 arrives) and the
-- refusals that happen before any spawn.
--
-- A SECOND sum of the same name in the same package would mean the cache speaks a type the real
-- prover never returns, and every abort-safety claim below would then be a claim about a shape
-- that exists only in the test tree. The seam is a record of functions OVER the real outcome type;
-- it is not a re-modelling of it.
--
-- WHAT IS DELIBERATELY NOT REACHABLE FROM HERE
-- --------------------------------------------
-- Nothing in this module spawns anything. It imports the outcome type and the shock type and no
-- edge at all: the module that resolves a live binary and a live model is not imported here and
-- not by @Store.Cache@ either, so the whole cache path stays inside @cabal test@'s no-solver rule
-- without anyone having to remember it. Wiring a real prover into a 'Solver' is a caller's job,
-- and the caller that does it is not in this package's test tree.
module Store.Solver
  ( Solver (..)
    -- * The outcome, from the module that produces it
  , ProverOutcome (..)
  , AbortReason (..)
  ) where

import Gams.Argv (Shock)
import Gams.Run (AbortReason (..), ProverOutcome (..))

-- | The solve, as a value.
--
-- The shock is the ONLY argument. Everything an invocation additionally needs -- the binary, the
-- model, the budget, the kill delay, the working directory -- is per-invocation ambient state that
-- @Store.Key@ is structurally incapable of keying over, so it is closed over by whoever builds the
-- 'Solver' and never travels through the cache. That is the same boundary stated twice: once as
-- \"no signature on the key path takes one\", and here as \"no signature on the cache path takes
-- one either\".
data Solver = Solver
  { solver_label :: String
    -- ^ which solver this is, so a failure names the one it came from -- 'Store.Class' spells out
    -- the same reason for the store's own label.
  , solver_run   :: Shock -> IO ProverOutcome
    -- ^ run it. Total in the sense that matters: every failure is an 'Aborted' carrying the reason
    -- and the exit code, never an exception and never a 'Produced' with nothing in it.
  }
