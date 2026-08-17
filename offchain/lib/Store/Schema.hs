-- |
-- The migration manifest and the identity constraint, as PURE data.
--
-- No IO, no client, no directory read: this module is what a check compares the directory and the
-- live catalogue AGAINST. A manifest derived by globbing the directory would agree with whatever
-- is on disk by construction, which is a statement about @listDirectory@ and not about the schema.
--
-- MEASURED, source-read of @postgresql-migration-0.2.1.8@: @MigrationDirectory@ resolves through
-- @scriptsInDirectory dir = sort \<$\> listDirectory dir@ (@Migration.hs:155-158@) and applies
-- @executeMigration@ to EVERY entry it finds -- there is no extension filter anywhere on that
-- path. So the migration directory is not \"a directory that happens to contain migrations\": every
-- file in it is read and handed to @execute_@ as SQL. That is why the check that reads this
-- manifest asserts the directory's WHOLE contents against it rather than only its SQL files.
module Store.Schema
  ( expected_migrations
  , identity_constraint_name
  , identity_constraint_columns
  , versions_nonempty_constraint_name
  , versions_nonempty_columns
  ) where

-- | The migrations, in application order.
--
-- The library sorts by filename, so the numeric prefix IS the order; this list is the INDEPENDENT
-- statement of what that order is supposed to be, so a renamed or dropped file is a set mismatch
-- rather than a silently shorter run that reports success.
--
-- The version numbers are not decoration either: they are asserted to be @[1 .. n]@, which is what
-- makes a deleted middle migration a gap rather than a shorter list.
expected_migrations :: [(Int, FilePath)]
expected_migrations =
  [ (1, "001_model_run.sql")
  , (2, "002_byte_corpus.sql")
  , (3, "003_version_columns_nonempty.sql")
  ]

-- | KEY-07, stated as data so a check can compare it to the LIVE catalogue and not only to the
-- file the migration was read from. The live half lands in plan 23-05; the file half is asserted
-- from 23-03 onward, and the two are deliberately different instruments: a DDL file that was never
-- applied and a catalogue that drifted from its DDL are different failures.
identity_constraint_name :: String
identity_constraint_name = "model_run_identity"

-- | All THREE columns. Dropping @key_scheme@ here would make a key-formula change collide with and
-- corrupt the old rows instead of orphaning them -- MEASURED at 23-01 against a two-part key: the
-- superseded scheme silently served a row computed under a different formula, and the second
-- insert vanished.
identity_constraint_columns :: [String]
identity_constraint_columns = ["model", "key_scheme", "key"]

-- | Migration @003@'s CHECK, stated as data for the same reason 'identity_constraint_name' is.
--
-- The constraint is named rather than left to Postgres's generated identifier because the capture
-- asserts that the SERVER'S OWN error message carries this string. A system-generated name would
-- still produce SQLSTATE @23514@, and @23514@ alone says only \"some check refused\" -- it does not
-- say WHICH, and this table is free to grow other checks later. The recorded evidence has to name
-- the constraint or it is evidence about the class and not about this guard.
versions_nonempty_constraint_name :: String
versions_nonempty_constraint_name = "model_run_versions_nonempty"

-- | Both columns, because ONE of them is the failure this is written against.
--
-- @NOT NULL@ does not forbid @''@ (24-RESEARCH M14), and a CHECK that covered only @gams_ver@ is
-- precisely the shape a copy-paste produces -- it would pass every test written about the GAMS
-- version while leaving the CONOPT version emptily storable, and KEY-01 folds BOTH into the key.
-- The capture attempts an empty value in each column independently and records the two outcomes
-- separately, so a half-covered constraint is a red rather than a green with a hole in it.
versions_nonempty_columns :: [String]
versions_nonempty_columns = ["gams_ver", "conopt_ver"]
