-- |
-- Where the store's two environment overrides are resolved, and the only place either variable is
-- NAMED.
--
-- DB-02: connection config comes from the environment, no credential is hardcoded, and the
-- resolution follows the convention already in force -- @Rig.Manifest.rig_pins_path@'s
-- @fromMaybe default \<$\> lookupEnv@ (@offchain\/lib\/Rig\/Manifest.hs:191-197@) and
-- @Driver.Capture.capture_env_var@'s name-the-variable-once constant
-- (@offchain\/lib\/Driver\/Capture.hs:319-327@).
--
-- The constants exist because 22-03 MEASURED @RIG_MANIFEST@ being advertised and silently
-- ignored, and 22-04 measured the same defect on a second surface. A variable named once, in one
-- place that both the resolver and the test suite's override sweep read, is what keeps the
-- advertisement and the behaviour from drifting apart the way those two did.
--
-- NO credential, host, port, user or DSN literal appears in this module -- and that includes the
-- PROSE. A future @no_credential_is_present_in_a_tracked_file@ check greps for exactly those
-- tokens, and a comment saying \"no secret here\" would redden it just as loudly as a secret,
-- which is the correct behaviour for a grep and the wrong reason to have to relax one.
module Store.Config
  ( -- * The connection string
    pgstore_dsn_env_var
  , pgstore_dsn
  , default_pgstore_dsn
    -- * The committed conformance artifact
  , store_conformance_env_var
  , store_conformance_path
  , default_store_conformance_path
    -- * The migration directory
  , migrations_dir
  ) where

import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)

-- ---------------------------------------------------------------------------------------------
-- The connection string
-- ---------------------------------------------------------------------------------------------

pgstore_dsn_env_var :: String
pgstore_dsn_env_var = "PGSTORE_DSN"

-- | The EMPTY string, deliberately.
--
-- @postgresql-simple@'s @connectPostgreSQL \"\"@ falls back to libpq's own @PG*@ environment
-- variables (MEASURED with @DATABASE_URL@ unset), so the no-override path names no host, no port,
-- no user and no secret -- and therefore no credential is ever written down in a tracked file.
-- An empty default is the SAFE default here for the same reason it is usually the dangerous one:
-- there is nothing to leak and nothing to go stale.
default_pgstore_dsn :: String
default_pgstore_dsn = ""

-- | @PGSTORE_DSN@, defaulting to libpq's own environment.
pgstore_dsn :: IO String
pgstore_dsn = fromMaybe default_pgstore_dsn <$> lookupEnv pgstore_dsn_env_var

-- ---------------------------------------------------------------------------------------------
-- The committed conformance artifact
-- ---------------------------------------------------------------------------------------------

store_conformance_env_var :: String
store_conformance_env_var = "STORE_CONFORMANCE"

default_store_conformance_path :: FilePath
default_store_conformance_path = "offchain/rig/store-conformance.json"

-- | @STORE_CONFORMANCE@, defaulting to the committed evidence.
store_conformance_path :: IO FilePath
store_conformance_path = fromMaybe default_store_conformance_path <$> lookupEnv store_conformance_env_var

-- ---------------------------------------------------------------------------------------------
-- The migration directory
-- ---------------------------------------------------------------------------------------------

-- | Under @offchain\/@ ON PURPOSE, and it is not free: the first @.sql@ landing here forces
-- @purge_scanned_extensions@, @purge_known_extensions@ and a re-MEASURED @purge_file_floor@ to
-- move together (plan 23-03's task, budgeted rather than discovered as a red). SQL is EXECUTED
-- content, and free-passing an executable file type by keeping it outside the purge's reach is
-- the worse trade.
migrations_dir :: FilePath
migrations_dir = "offchain/migrations"
