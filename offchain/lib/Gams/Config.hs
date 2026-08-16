-- |
-- Where the GAMS layer's three environment overrides are resolved, and the only place any of the
-- three variables is NAMED.
--
-- The shape is @Store.Config@'s, deliberately and verbatim: one constant holding the variable's
-- name, one constant holding the default, one @IO@ resolver that reads the name constant rather
-- than repeating the literal. 22-03 MEASURED @RIG_MANIFEST@ being advertised and silently ignored
-- and 22-04 measured the same defect on a second surface; a variable named once, in one place both
-- the resolver and the suite's override sweep read, is what keeps the advertisement and the
-- behaviour from drifting apart the way those two did.
--
-- NO absolute path appears in this module, and that includes the prose. The resolved binary on the
-- research machine lives under a versioned system directory and its digest is machine-specific
-- (recorded in the capture artifact, per run, asserted on SHAPE) -- writing either one down here
-- would make @cabal test@ fail on every other install, which is the difference between pinning
-- evidence and pinning an accident.
module Gams.Config
  ( -- * The prover binary
    gams_bin_env_var
  , gams_bin
  , default_gams_bin
    -- * The model
  , gams_model_env_var
  , gams_model
  , default_gams_model
    -- * The committed conformance artifact
  , gams_conformance_env_var
  , gams_conformance_path
  , default_gams_conformance_path
  ) where

import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)

-- ---------------------------------------------------------------------------------------------
-- The prover binary
-- ---------------------------------------------------------------------------------------------

gams_bin_env_var :: String
gams_bin_env_var = "GAMS_BIN"

-- | The BARE name, resolved through @findExecutable@ by the invocation layer, never a path.
--
-- The absolute path and the sha256 of the executable are the two facts GAMS-03 wants recorded,
-- because they are what a wrapper script or a @PATH@ shadow cannot lie about. They are also the
-- two facts that differ on every machine, so they belong in the per-run capture and not in a
-- source file the suite compiles everywhere.
default_gams_bin :: FilePath
default_gams_bin = "gams"

-- | @GAMS_BIN@, defaulting to the bare executable name.
gams_bin :: IO FilePath
gams_bin = fromMaybe default_gams_bin <$> lookupEnv gams_bin_env_var

-- ---------------------------------------------------------------------------------------------
-- The model
-- ---------------------------------------------------------------------------------------------

gams_model_env_var :: String
gams_model_env_var = "GAMS_MODEL"

-- | A FACT OF RECORD: @volume_path.gms@ DOES NOT EXIST IN THIS WORKTREE.
--
-- It lives in the sibling GAMS worktree, whose checkout of the monorepo carries the @model\/@ tree
-- this branch does not. The default below is therefore the canonical MONOREPO-RELATIVE path, and
-- resolving it from this worktree fails -- which is correct and is the point: a run here REQUIRES
-- the @GAMS_MODEL@ override, and the failure names the path it looked for rather than quietly
-- resolving something else.
--
-- The basename matters twice over. It is the file that is invoked, and it is the JOB NAME the
-- banner must carry for 'Gams.Version.parse_gams_version' to accept the version it reports -- so
-- the model path and the version's subject are the same fact, resolved once.
default_gams_model :: FilePath
default_gams_model = "model/mev_tax_model_one/volume_path.gms"

-- | @GAMS_MODEL@, defaulting to the canonical monorepo-relative model path.
gams_model :: IO FilePath
gams_model = fromMaybe default_gams_model <$> lookupEnv gams_model_env_var

-- ---------------------------------------------------------------------------------------------
-- The committed conformance artifact
-- ---------------------------------------------------------------------------------------------

gams_conformance_env_var :: String
gams_conformance_env_var = "GAMS_CONFORMANCE"

-- | The committed evidence, in the @store-conformance.json@ family: everything this package knows
-- about the REAL prover is an assertion over a file produced out of band, because @cabal test@ is
-- GAMS-free by construction and may not shell out to a solver.
default_gams_conformance_path :: FilePath
default_gams_conformance_path = "offchain/rig/gams-conformance.json"

-- | @GAMS_CONFORMANCE@, defaulting to the committed evidence.
gams_conformance_path :: IO FilePath
gams_conformance_path = fromMaybe default_gams_conformance_path <$> lookupEnv gams_conformance_env_var
