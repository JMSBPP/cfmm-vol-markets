-- |
-- STORE-01, as one function: look the key up FIRST, elide on a hit, and persist only a run that
-- completed.
--
-- THE ORDER IS THE REQUIREMENT
-- ----------------------------
-- The lookup happens before the solver is reached, and the solver is reached only from the branch
-- where the lookup returned nothing. That is the whole of \"the same shock skips the solve\", and
-- it is worth saying that a version which solved first and then consulted the store would satisfy
-- every claim about the BYTES this module makes -- same artifact in, same artifact out -- while
-- costing a full solve every time. So the elision check that guards this reads the solver's own
-- invocation counter as well as the bytes. Neither half is sufficient: a counter alone passes for
-- a solver that ran and was ignored, and a value alone passes for a solver that happened to agree.
--
-- WHAT THIS FUNCTION IS NOT GIVEN
-- -------------------------------
-- It takes a 'KeyIdentity' and a 'Shock' and nothing else that varies. It is NOT handed the record
-- an invocation is built from, and that omission is load-bearing rather than tidy: that record
-- carries a budget, a kill delay, a binary path and -- through @Gams.Run@ -- an exclusive per-run
-- temporary directory that is a different path on every call by design. A key computed over any of
-- them never repeats, so every solve would store a new row and no lookup would ever hit, while the
-- stored preimage still reconstructed the argument vector perfectly and nothing anywhere went red.
-- @Store.Key@ is structurally incapable of reaching those values; this module is the second half
-- of the same boundary, and a structural check asserts the type's name does not occur in this file.
--
-- WHICH VERSIONS THE ROW RECORDS
-- ------------------------------
-- The two version columns come from the 'KeyIdentity' the key was computed over, NOT from the
-- toolchain the outcome reports. Two reasons, and the first is a type-level one: the identity's
-- versions are unwrapped values that cannot be built empty, whereas the outcome's solver-side
-- version is optional, and writing the empty string into a column whose whole job is to say which
-- toolchain produced these bytes is the defect this subsystem exists to prevent. The second is
-- that a row whose evidence disagreed with its own key would be unreadable afterwards.
--
-- Nothing here CHECKS that the completed run's toolchain is the one the key was computed over.
-- That comparison, and the quarantine it would feed, are the deferred requirements of this phase;
-- they are named here so their absence is a recorded decision rather than an oversight.
--
-- WHY THE PERSIST CANNOT DROP BYTES ON THE FLOOR
-- ----------------------------------------------
-- 'Store.Memory' and the server both require a json value on the keyed path, and the keyed put
-- RAISES on anything else. That is not a hazard here: the only bytes this module ever puts are
-- @pa_bytes@ of a decoded artifact, and @Gams.Artifact@ refuses a document that is not a json
-- value before it produces one at all. The seam therefore cannot hand this function bytes the
-- store would reject, and there is deliberately no catch here that would turn such a rejection
-- into a quiet miss.
module Store.Cache
  ( Decision (..)
  , decide
  ) where

import Gams.Argv (ArgvError, Shock)
import Gams.Artifact (ProverArtifact (..))
import Gams.Version (conopt_version_text, gams_version_text)
import Store.Class (Store (..))
import Store.Key (ContentKey (..), KeyIdentity (..), content_key)
import Store.Solver (AbortReason, ProverOutcome (..), Solver (..))
import Store.Types (Artifact (..), KeyScheme, StoredRun (..))

-- | What happened, named so a caller cannot confuse a hit with a fresh solve.
--
-- 'Elided' and 'Stored' both carry an 'Artifact' and they are separate constructors anyway: the
-- bytes are the same shape and the EVENT is not, and a caller that only wanted the bytes would
-- otherwise have no way to report a hit rate.
data Decision
  = Elided !Artifact
    -- ^ the key was already in the store. These are the STORED bytes and the solver was never
    -- called -- not called and discarded, not called at all.
  | Stored !Artifact
    -- ^ the key was absent, the run completed, and its bytes are now in the store under it.
  | NotPersisted !AbortReason !Int
    -- ^ the key was absent and the run did not complete: the reason and the exit code the
    -- invocation reported. NOTHING was written. A cache entry for an aborted run is a poisoned
    -- one -- every later request for that shock would be served the absence of a solve.
  deriving (Eq, Show)

-- | The whole of it.
--
-- The scheme is an argument rather than a constant read from the library, because it is one third
-- of the store's identity triple: the key, the model and the scheme all have to be the same three
-- values on the way in and on the way out, and threading one of them from somewhere else is how a
-- lookup under a superseded scheme starts almost-matching.
--
-- 'Left' is exactly and only the key refusing to compute -- the eight range and model refusals
-- @Store.Key@ inherits from the renderer. A shock that cannot be run cannot be keyed, so it is
-- never looked up and never solved.
decide
  :: Store
  -> Solver
  -> KeyScheme
  -> String
  -> Shock
  -> KeyIdentity
  -> IO (Either ArgvError Decision)
decide store solver scheme model shock ident =
  case content_key scheme model shock ident of
    Left why -> pure (Left why)
    Right (ContentKey key) -> do
      hit <- store_lookup store model scheme key
      case hit of
        Just row -> pure (Right (Elided (sr_raw row)))
        Nothing -> do
          outcome <- solver_run solver shock
          case outcome of
            Aborted why code _streams -> pure (Right (NotPersisted why code))
            Produced artifact _toolchain _streams -> do
              let bytes = Artifact (pa_bytes artifact)
              store_put store StoredRun
                { sr_model      = model
                , sr_key_scheme = scheme
                , sr_key        = key
                , sr_raw        = bytes
                , sr_gams_ver   = gams_version_text (ki_gams_version ident)
                , sr_conopt_ver = conopt_version_text (ki_conopt_version ident)
                }
              pure (Right (Stored bytes))
