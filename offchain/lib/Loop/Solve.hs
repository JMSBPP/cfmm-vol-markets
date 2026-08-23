-- |
-- The two spike seams the loop cannot be written without, closed in the LIBRARY: __S2__, a
-- 'Solver' built from already-resolved paths, and __S3__, the classification of what
-- @Store.Cache.decide@ returned, as DATA rather than as a branch scattered through a poller.
--
-- == S2: RESOLUTION IS A STARTUP PRECONDITION, NOT A PER-SOLVE FAILURE
--
-- @.planning\/SPIKE-end-to-end.md@ records that the composing function of the resolving module --
-- the one a phase-28 author reaches for first -- does not fit the seam. Its type carries an
-- environment choice and returns an @Either@ over its own resolution error, and the seam wants
-- @Shock -> IO ProverOutcome@. The tempting repair is to widen @Gams.Run.AbortReason@ with a
-- constructor meaning \"the binary or the model could not be resolved\" and map the resolution
-- failure onto it. __That constructor is deliberately NOT added, and this module deliberately does
-- not import the resolving module at all.__
--
-- An @AbortReason@ is the reason a SOLVE produced nothing, and it is written into a ledger row and
-- read by a post-mortem. \"The model file was not where the process expected it\" is not a fact
-- about the shock and not a fact about the model: it is a fact about the process's own startup,
-- and a row recording it under the same discriminator as @CONOPT could not reach an admissible
-- point@ would make the two indistinguishable afterwards. That is exactly the conflation S3 exists
-- to prevent, arriving from the other end.
--
-- So this module receives absolute paths that someone else already resolved, and a caller that
-- cannot resolve them fails BEFORE the loop starts, naming the path. 'Gams.Run.run_prover' still
-- refuses a relative path by @NotAbsolute@, so a caller that lies about the field is caught by the
-- edge rather than trusted here.
--
-- == THE STASH, AND WHY IT HAS TO EXIST
--
-- @Store.Cache.decide@ matches @Produced artifact _toolchain _streams@ and DISCARDS the toolchain.
-- A resident caller that must notice toolchain drift -- 28-CONTEXT's user ruling is to adopt the
-- new identity and continue, logging the change, so the switch stays reconstructible from the
-- ledger -- has no other route to that value: it is produced only on the @Produced@ arm of
-- 'Gams.Run.run_prover', and the only call to @run_prover@ on the cache path is the one INSIDE the
-- seam. Widening @Decision@ instead would change a type five existing checks assert against by
-- equality, so the observation is stashed beside the seam and read back by whoever built it.
--
-- The stash is written on the @Produced@ arm ONLY. An abort carries no identity, and writing
-- @Nothing@ over a previously-observed one would turn a failed solve into a forgotten toolchain.
--
-- == S3: THE DISCRIMINATOR ALREADY EXISTS, AND 27-SUMMARY OVERSTATES THE SEAM
--
-- The spike recorded that a caller of @decide@ cannot tell an INADMISSIBLE shock from an
-- UNSOLVABLE one, because @NotPersisted@ drops the captured streams and the abort LINE NUMBER
-- (109 = the half-ellipse refusal, 171\/173 = CONOPT failing to reach an admissible point) lives
-- only in a run directory @Gams.Run@ deletes on every exit path.
--
-- __MEASURED against the shipped modules: an inadmissible shock never reaches the prover at all in
-- production.__ @Gams.Argv.render_argv@ applies a NINTH refusal, @admissible_pair@, before any
-- argument vector is produced; @Store.Key.content_key@ inherits it; and @Store.Cache.decide@
-- returns it as @Left (Inadmissible ...)@ BEFORE the solver is reachable. So the two failures
-- 28-CONTEXT gives opposite policies to arrive on two DIFFERENT constructors of
-- @Either ArgvError Decision@, and telling them apart needs no log, no captured stream and no
-- wider @Decision@.
--
-- The abort-line discriminator is still real and still needed -- by @app\/FeeSplitConformance.hs@,
-- which drives the UNGATED renderer on purpose in order to measure what the prover does one pip
-- below each boundary. That is the one consumer of the eight-refusal renderer and this module is
-- not a second one.
--
-- == WHY 'cl_halts' IS A FIELD
--
-- \"Which failures halt the loop\" is one expression a check can read, rather than a policy spread
-- over the call sites that implement it. 28-CONTEXT rules the two arms opposite: a bad input is
-- skipped VISIBLY (a row is written, the watermark advances), and an admissible shock the prover
-- could not answer halts at the block boundary without advancing, because a model problem that is
-- skipped silently is a model problem nobody ever reads about.
--
-- Nothing here does IO except 'solver_for', which does exactly one @IORef@ allocation and then
-- whatever the prover edge does. 'classify' is pure and total.
module Loop.Solve
  ( -- * S2 -- the seam, over already-resolved paths
    ProverPaths (..)
  , solver_for
    -- * S3 -- what happened, as data
  , Outcome (..)
  , outcomes
  , outcome_token
  , Classified (..)
  , classify
  ) where

import Data.IORef (newIORef, readIORef, writeIORef)

import Gams.Argv (ArgvError)
import Gams.Run
  ( ProverOutcome (..)
  , RunRequest (..)
  , ToolchainIdentity
  , run_prover
  )
import Store.Cache (Decision (..))
import Store.Solver (Solver (..))
import Store.Types (Artifact)

-- ---------------------------------------------------------------------------------------------
-- S2
-- ---------------------------------------------------------------------------------------------

-- | Everything a 'Solver' needs that is NOT the shock, resolved once by whoever starts the
-- process.
--
-- These are the same five fields @Gams.Run.RunRequest@ carries beside its shock, and they are
-- copied rather than reached for: a record that held a @RunRequest@ with a placeholder shock would
-- have a field whose value is never the one used, which is a value that can drift without anything
-- noticing.
data ProverPaths = ProverPaths
  { pp_binary       :: !FilePath
    -- ^ ABSOLUTE path to the solver executable. A relative one is refused by the edge, by name.
  , pp_model        :: !FilePath
    -- ^ ABSOLUTE path to the model source.
  , pp_env          :: !(Maybe [(String, String)])
    -- ^ @Just@ the whitelist in production; @Nothing@ means INHERIT.
  , pp_budget_s     :: !Int
    -- ^ seconds the invocation is given.
  , pp_kill_after_s :: !Int
    -- ^ the grace between the term signal and the kill.
  }

-- | The seam, plus the observation @Store.Cache.decide@ throws away.
--
-- The second component is a READ action over a stash the returned 'Solver' writes to. It is
-- @Nothing@ until the first completed run and the last completed run's identity afterwards, which
-- is precisely the value a drift check compares against its pinned one.
solver_for :: ProverPaths -> IO (Solver, IO (Maybe ToolchainIdentity))
solver_for paths = do
  stash <- newIORef Nothing
  let run shock = do
        outcome <-
          run_prover
            RunRequest
              { rr_binary       = pp_binary paths
              , rr_model        = pp_model paths
              , rr_shock        = shock
              , rr_env          = pp_env paths
              , rr_budget_s     = pp_budget_s paths
              , rr_kill_after_s = pp_kill_after_s paths
              }
        case outcome of
          Produced _artifact toolchain _streams -> writeIORef stash (Just toolchain)
          Aborted _why _code _streams           -> pure ()
        pure outcome
  pure
    ( Solver
        { solver_label = "Loop.Solve over " ++ pp_binary paths
        , solver_run   = run
        }
    , readIORef stash
    )

-- ---------------------------------------------------------------------------------------------
-- S3
-- ---------------------------------------------------------------------------------------------

-- | The four things that can happen to one event, and there are exactly four.
--
-- @Enum@ and @Bounded@ are derived so 'outcomes' can be @[minBound .. maxBound]@: a fifth
-- constructor then reaches every both-directions check that reads that list, instead of being
-- silently absent from a hand-written enumeration.
data Outcome
  = OutcomeElided
    -- ^ the key was already in the store. A cache hit is still NEWS and still gets a row.
  | OutcomeStored
    -- ^ the key was absent, the run completed, and the bytes are now stored under it.
  | OutcomeNotPersisted
    -- ^ an ADMISSIBLE shock the prover could not answer. Nothing was written.
  | OutcomeInadmissible
    -- ^ the shock was refused before it could be keyed, so it never reached a solver.
  deriving (Eq, Show, Enum, Bounded)

-- | Every 'Outcome', from the type rather than from a list someone maintains.
outcomes :: [Outcome]
outcomes = [minBound .. maxBound]

-- | The token a ledger row carries, and the token the migration's own check constrains.
--
-- Written out here rather than derived from the constructor names: the SQL check is external, and
-- a token derived from the Haskell constructor would make the check comparing the two a statement
-- of the producer agreeing with itself.
outcome_token :: Outcome -> String
outcome_token OutcomeElided       = "elided"
outcome_token OutcomeStored       = "stored"
outcome_token OutcomeNotPersisted = "not_persisted"
outcome_token OutcomeInadmissible = "inadmissible"

-- | One decided event: what happened, why, what bytes came back, and whether the loop stops.
data Classified = Classified
  { cl_outcome  :: !Outcome
  , cl_reason   :: !String
    -- ^ empty for the two success arms; the refusal or the abort, rendered, otherwise.
  , cl_artifact :: !(Maybe Artifact)
    -- ^ @Just@ for the two arms that have bytes, @Nothing@ for the two that do not. The publisher
    -- takes its bytes from HERE, so an outcome with nothing to publish cannot be published by
    -- reaching for a field that happens to hold the previous event's artifact.
  , cl_halts    :: !Bool
    -- ^ THE FAILURE POLICY, in one place.
  } deriving (Eq, Show)

-- | The whole of S3.
--
-- @Left@ is exactly and only the key refusing to compute -- the nine refusals @Store.Key@ inherits
-- from the renderer, of which the ninth is admissibility. The loop skips it, visibly, and keeps
-- going: a shock nobody can render is an input problem and the next event is unaffected by it.
--
-- @NotPersisted@ is the opposite ruling and it is the only arm that halts. The shock WAS
-- admissible, the argument vector WAS built, the prover WAS reached, and it returned nothing --
-- which is a statement about the model, not about the event, so the next event would be expected
-- to fail the same way and processing on past it turns one finding into a silent stretch of them.
classify :: Either ArgvError Decision -> Classified
classify (Left why) =
  Classified
    { cl_outcome  = OutcomeInadmissible
    , cl_reason   = show why
    , cl_artifact = Nothing
    , cl_halts    = False
    }
classify (Right (Elided artifact)) =
  Classified
    { cl_outcome  = OutcomeElided
    , cl_reason   = ""
    , cl_artifact = Just artifact
    , cl_halts    = False
    }
classify (Right (Stored artifact)) =
  Classified
    { cl_outcome  = OutcomeStored
    , cl_reason   = ""
    , cl_artifact = Just artifact
    , cl_halts    = False
    }
classify (Right (NotPersisted why code)) =
  Classified
    { cl_outcome  = OutcomeNotPersisted
    , cl_reason   = show why ++ " exit " ++ show code
    , cl_artifact = Nothing
    , cl_halts    = True
    }
