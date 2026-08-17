{-# LANGUAGE OverloadedStrings #-}

-- |
-- The ONLY module in this tree that talks to a database, and the only one permitted to import the
-- client or the migration runner. Everything else in @offchain\/lib\/Store\/@ is server-free by
-- construction, which is what keeps @cabal test@ free of a socket without a single conditional.
--
-- THREE WARTS ARE CLOSED HERE, AND ALL THREE ARE SILENT AT COMPILE TIME.
--
-- (1) __The write path is @Binary@-only.__ @ToField ByteString@ is @Escape@ -- a quoted TEXT
--     literal (@ToField.hs:223-225@, source-read on this machine) -- while
--     @ToField (Binary ByteString)@ is @EscapeByteA@ (@ToField.hs:201-206@). Handing a bare
--     'BS.ByteString' to a @bytea@ parameter type-checks, runs, and CORRUPTS: MEASURED on PG 18.4,
--     @a\\101b@ = @61 5c 31 30 31 62@ (6 bytes) goes in and @61 41 62@ (3 bytes) comes back with
--     no error and no warning, because @byteain@ still accepts the legacy escape format and
--     re-reads @\\101@ as one octal byte. Every @bytea@ parameter below is wrapped.
--
--     The wart is WRITE-ONLY. @FromField ByteString@ special-cases the @bytea@ OID
--     (@FromField.hs:392-394@) and hands off to the @Binary@ reader, so reading a @bytea@ column
--     into a bare 'BS.ByteString' is correct and lossless -- which is why the reads below do
--     exactly that, deliberately. A negative control that swapped the newtype on the READ side
--     would pass and would prove nothing.
--
-- (2) __The migration runner exits non-zero.__ @postgresql-migration@ 0.2.1.8 RETURNS a
--     'MigrationError' and the PROCESS STILL EXITS 0. The @exitFailure@ in
--     'run_migrations_or_exit' is the whole of DB-01's \"exits non-zero\", and the observation that
--     counts is @echo $?@ == 1, never the returned value.
--
-- (3) __The migration mutex is ours.__ Source-read of @Migration.hs@ 0.2.1.8: @checkScript@
--     (@:253-262@) is a plain @SELECT@ with no @FOR UPDATE@ and no @LOCK TABLE@, and a grep for
--     @advisory@ across the whole module returns ZERO hits -- re-run at 23-03, not cited. Under
--     READ COMMITTED two concurrent migrators both observe @ScriptNotExecuted@ and both apply.
--     'with_migration_lock' is the caller-side lock that stops them.
--
-- A FOURTH WART, MEASURED AT 23-03 AND NOT IN THE RESEARCH: @execute@ and @execute_@ THROW on a
-- statement that returns columns -- @finishExecute@ raises
-- @QueryError \"execute resulted in 1-column result\"@ on @PQ.TuplesOk@ (@Internal.hs:408-428@).
-- So the lock cannot be taken by handing @execute_@ a @select@ of the lock function, which is the
-- form both the research and the plan prescribe: it compiles and then throws at the first
-- acquisition. The lock statements below go through @query@ and consume the row. (The prescribed
-- call is described rather than quoted for the same blast-radius reason as the import note below.)
--
-- Importing this module opens no connection. Only 'with_connection' does.
module Store.Postgres
  ( new_postgres_store
  , with_connection
  , run_migrations_or_exit
  , with_migration_lock
  , try_migration_lock
  , migration_lock_key
  , server_version
  , live_identity_constraint_columns
  ) where

import Control.Exception (bracket, bracket_)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.String (fromString)
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Encoding.Error as TEE
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

-- 'Binary' is RE-EXPORTED from the module imported below and must be taken from there. There is
-- no separate sub-module of the client named after the newtype, however natural that path looks:
-- an import written that way does not compile. The dead path is described rather than spelled,
-- because an acceptance grep counts occurrences of it in this file and a comment saying the import
-- is absent would be counted by the scan asserting it is absent -- the tenth time prose has landed
-- inside a grep's blast radius on this branch.
import Database.PostgreSQL.Simple
  ( Binary (..)
  , Connection
  , Only (..)
  , Query
  , close
  , connectPostgreSQL
  , execute
  , execute_
  , query
  , query_
  )
import Database.PostgreSQL.Simple.Migration
  ( MigrationCommand (..)
  , MigrationResult (..)
  , defaultOptions
  , runMigrations
  )

import Store.Class (Store (..))
import Store.Schema (identity_constraint_name)
import Store.Types
  ( Artifact (..)
  , KeyScheme (..)
  , ResetScope (..)
  , StoredRun (..)
  , artifact_bytes
  , derived_doc_from_text
  , derived_doc_sha256
  )

-- ---------------------------------------------------------------------------------------------
-- Connection
-- ---------------------------------------------------------------------------------------------

-- | The DSN is a PARAMETER, not something this module resolves.
--
-- @Store.Config@ owns the environment override, and keeping the lookup out of here means this
-- module reads no environment at all: whoever opens the connection is visibly the same code that
-- decided which server to open it against.
--
-- An empty DSN is legitimate and is the default: libpq falls back to its own @PG*@ environment,
-- so the no-override path names no host, no user and no secret.
with_connection :: String -> (Connection -> IO a) -> IO a
with_connection dsn = bracket (connectPostgreSQL (C8.pack dsn)) close

-- ---------------------------------------------------------------------------------------------
-- The migration mutex
-- ---------------------------------------------------------------------------------------------

-- | The migration mutex. A fixed, arbitrary, WRITTEN-DOWN constant.
--
-- Every migrator in this repository must use this same number or the lock is not a lock, so it is
-- exported and both statements below take it as a parameter rather than spelling it twice. The
-- capture that records it (@advisory_lock_key@) reads THIS binding, so the recorded evidence and
-- the lock that was actually taken cannot drift apart.
migration_lock_key :: Int
migration_lock_key = 872304

-- | Production form: BLOCKING.
--
-- The lock is SESSION-scoped, so it releases when the connection closes and the unlock is
-- belt-and-braces rather than load-bearing. It is taken OUTSIDE the migration transaction on
-- purpose: a transaction-scoped lock would release at commit, which is after the window it is
-- meant to cover.
with_migration_lock :: Connection -> IO a -> IO a
with_migration_lock con = bracket_ take_it release_it
  where
    take_it = do
      _ <- query con "select pg_advisory_lock(?)" (Only migration_lock_key) :: IO [Only ()]
      pure ()
    release_it = do
      _ <- query con "select pg_advisory_unlock(?)" (Only migration_lock_key) :: IO [Only Bool]
      pure ()

-- | Test form: NON-blocking, so the concurrency observation is deterministic and needs no
-- sleep-racing.
--
-- MEASURED across two sessions on PG 18.4: @f@ while another session holds it, @t@ after release.
-- 'False' here is the evidence that the second migrator was excluded.
try_migration_lock :: Connection -> IO Bool
try_migration_lock con = do
  rows <- query con "select pg_try_advisory_lock(?)" (Only migration_lock_key)
  pure $ case rows of
    (Only taken : _) -> taken
    []               -> False

-- ---------------------------------------------------------------------------------------------
-- Migrations
-- ---------------------------------------------------------------------------------------------

-- | Apply the migrations under @dir@, or KILL THE PROCESS.
--
-- @runMigrations@'s default @TransactionPerRun@ already wraps the run in @withTransaction@
-- (@Migration.hs:119@ -> @:381@), so a mid-run failure rolls back. What it does NOT do is fail the
-- process, and a caller that pattern-matches the result and carries on has a migration system that
-- reports success by exiting 0 while the schema is whatever it was before.
--
-- MEASURED CORRECTION to the research, source-read at 23-03: on checksum drift through this path
-- the payload is @MigrationError name@ -- the SCRIPT NAME (@Migration.hs:181@) -- not the string
-- @\"Checksum mismatch\"@. That wording comes from the separate @MigrationValidation@ path
-- (@:239@). Anything asserting on the payload TEXT of a drift observed through @runMigrations@
-- will be asserting on a filename.
run_migrations_or_exit :: Connection -> FilePath -> IO ()
run_migrations_or_exit con dir = with_migration_lock con $ do
  result <- runMigrations con defaultOptions [MigrationInitialization, MigrationDirectory dir]
  case result of
    MigrationSuccess -> pure ()
    MigrationError what -> do
      hPutStrLn stderr ("migration FAILED: " ++ what ++ " (dir: " ++ dir ++ ")")
      exitFailure

-- ---------------------------------------------------------------------------------------------
-- The store
-- ---------------------------------------------------------------------------------------------

-- | The 'Store' seam, backed by a live connection.
--
-- Same seven fields as @Store.Memory@, and the SAME eight laws run against both. That is the point
-- of the record: the reference implementation and the real one are two subjects for one contract,
-- and a law that holds against only one of them has found something.
--
-- The seventh field is 'store_reset', added at 25-03 for STORE-06, and it is the ONE function on
-- this record that no check in @cabal test@ drives against THIS implementation -- the suite is
-- server-free by construction (DB-03) and the reset's only in-suite subject is @Store.Memory@.
-- Recorded here rather than left to be discovered: the statement below is short and takes no
-- parameters, so it has no @Binary@ hazard and no placeholder to transpose, but "it compiles" is
-- the whole of the evidence for it and the phase summary says so.
new_postgres_store :: Connection -> Store
new_postgres_store con =
  Store
    { store_label      = "Store.Postgres"
    , store_put        = put_run con
    , store_lookup     = lookup_run con
    , store_put_blob   = put_blob con
    , store_get_blob   = get_blob con
    , store_doc_sha256 = doc_digest con
    , store_reset      = reset_scope con
    }

-- | STORE-06, server-side. @model_run@ emptied; @byte_corpus@ untouched.
--
-- 'ModelRunOnly' is matched EXPLICITLY, not with a wildcard, so a second scope is a compile-time
-- warning here rather than a table this function silently keeps not deleting.
--
-- @execute_@ and not @execute@: there are no parameters, and the fourth wart in the module haddock
-- above is the reason a statement's shape gets a sentence here at all -- @execute@ THROWS on
-- anything that returns columns. A @delete@ with no @returning@ returns none, so this is the safe
-- side of that trap.
--
-- No @where@ clause. STORE-05 (pinning) is DEFERRED, so there is no @pinned@ column to honour and
-- a predicate written in advance would be a filter that never excludes anything while reading, to
-- anyone auditing this file, exactly like a retention policy.
reset_scope :: Connection -> ResetScope -> IO ()
reset_scope con ModelRunOnly = do
  _ <- execute_ con "delete from model_run"
  pure ()

-- | The insert. @doc@ is derived from the SAME parameter as @raw@, in ONE statement.
--
-- This is what makes BYTE-02's \"the doc describes the bytes\" STRUCTURAL rather than a
-- convention: the artifact is passed twice, there is no second source the projection could have
-- come from, and no Haskell code anywhere constructs it. A doc built separately -- in Haskell,
-- in a second statement, from a re-read -- could describe different bytes and nothing would say so.
--
-- @on conflict ... do nothing@ is the implementation of @law_first_writer_wins_on_the_identity_triple@:
-- a second solve of the same shock that DISAGREES must not overwrite the first, or the
-- disagreement -- the thing Phase 25 exists to detect -- is destroyed by the write that reveals it.
--
-- The conflict target is the CONSTRAINT, named from 'identity_constraint_name' rather than spelled
-- here, so a schema rename cannot leave this statement pointing at a constraint that no longer
-- exists. That constant is compile-time and never user input, so building it into the 'Query' is
-- not an injection surface.
--
-- RULED AT 23-04, and the ruling is IMPLEMENTED rather than described: @doc@ is @not null jsonb@,
-- so every artifact written through THIS path must be a JSON value, and the statement raises
-- @invalid input syntax for type json@ BEFORE the conflict clause is ever reached -- Postgres
-- computes the row before it resolves the conflict, so @do nothing@ does not save it.
--
-- 23-03 measured that and refused to decide it, because
-- @law_first_writer_wins_on_the_identity_triple@ wrote the bytes @SECOND-SOLVE-DISAGREED@ as its
-- second put and that law PASSED against @Store.Memory@. The USER RULING is that the keyed path
-- requires JSON, @Store.Memory@ is tightened to match, and the fixture becomes a JSON value that
-- still disagrees. TIER B MUST PREDICT TIER C: a law suite that passes against the reference store
-- and fails against this one defeats the three-tier design, which is the only reason @cabal test@
-- is allowed to run without a server.
--
-- The rule is now an executable law rather than this paragraph --
-- @law_a_non_json_artifact_is_rejected_on_the_keyed_path@ -- and it runs against BOTH stores. The
-- keyed surface requires JSON; @byte_corpus@ below carries arbitrary bytes and deliberately has no
-- @jsonb@ column, which is where BYTE-01's requirement is served.
insert_sql :: Query
insert_sql =
  "insert into model_run (model, key_scheme, key, raw, doc, gams_ver, conopt_ver) \
  \values (?, ?, ?, ?, convert_from(?, 'UTF8')::jsonb, ?, ?) \
  \on conflict on constraint "
    <> fromString identity_constraint_name
    <> " do nothing"

put_run :: Connection -> StoredRun -> IO ()
put_run con sr = do
  let KeyScheme scheme = sr_key_scheme sr
      bytes            = artifact_bytes (sr_raw sr)
  _ <-
    execute
      con
      insert_sql
      ( sr_model sr
      , scheme
      , Binary (sr_key sr)   -- bytea
      , Binary bytes         -- bytea, the ORACLE
      , Binary bytes         -- the SAME parameter again, converted to the derived projection
      , sr_gams_ver sr
      , sr_conopt_ver sr
      )
  pure ()

-- | The keyed read. @raw@ comes back into a bare 'BS.ByteString' ON PURPOSE -- see wart (1) in the
-- module haddock: the read side special-cases @bytea@ and is lossless.
lookup_run :: Connection -> String -> KeyScheme -> BS.ByteString -> IO (Maybe StoredRun)
lookup_run con model scheme key = do
  let KeyScheme n = scheme
  rows <- query con lookup_sql (model, n, Binary key)
  pure $ case rows of
    [] -> Nothing
    ((raw, gams, conopt) : _) ->
      Just
        StoredRun
          { sr_model      = model
          , sr_key_scheme = scheme
          , sr_key        = key
          , sr_raw        = Artifact raw
          , sr_gams_ver   = gams
          , sr_conopt_ver = conopt
          }

lookup_sql :: Query
lookup_sql =
  "select raw, gams_ver, conopt_ver from model_run \
  \ where model = ? and key_scheme = ? and key = ?"

-- | The derived projection, as a DIGEST and never as bytes.
--
-- @doc::text@ is converted to @bytea@ server-side and digested here, so nothing on this path can
-- hand a caller something that could stand in for the oracle -- 'Store.Types.DerivedDoc' has no
-- way back to bytes and this function's result is a 'String' digest.
--
-- No JSON library is involved, in either direction. The @doc@ column is written by Postgres from
-- the artifact bytes and read back as text; BYTE-03's source scan over this file is what keeps it
-- that way, and it has been reading this filename since 23-02, when the file did not exist yet.
doc_digest :: Connection -> String -> KeyScheme -> BS.ByteString -> IO (Maybe String)
doc_digest con model (KeyScheme n) key = do
  rows <- query con doc_sql (model, n, Binary key)
  pure $ case rows of
    [] -> Nothing
    (Only rendered : _) ->
      Just (derived_doc_sha256 (derived_doc_from_text (TE.decodeUtf8With TEE.lenientDecode rendered)))

doc_sql :: Query
doc_sql =
  "select convert_to(doc::text, 'UTF8') from model_run \
  \ where model = ? and key_scheme = ? and key = ?"

-- ---------------------------------------------------------------------------------------------
-- The blob surface
-- ---------------------------------------------------------------------------------------------

-- | LAST-writer-wins, matching @Store.Memory@ and deliberately unlike 'put_run'.
--
-- The blob surface is not an identity surface: it has no @key_scheme@, its names are corpus member
-- names, and re-putting one is a RE-MEASUREMENT rather than a conflicting second solve. It is a
-- separate table because the corpus is neither valid UTF-8 nor valid JSON.
put_blob :: Connection -> String -> Artifact -> IO ()
put_blob con name art = do
  _ <- execute con blob_insert_sql (name, Binary (artifact_bytes art))
  pure ()

blob_insert_sql :: Query
blob_insert_sql =
  "insert into byte_corpus (name, raw) values (?, ?) \
  \on conflict on constraint byte_corpus_identity do update set raw = excluded.raw"

get_blob :: Connection -> String -> IO (Maybe Artifact)
get_blob con name = do
  rows <- query con "select raw from byte_corpus where name = ?" (Only name)
  pure $ case rows of
    []                -> Nothing
    (Only raw : _)    -> Just (Artifact raw)

-- ---------------------------------------------------------------------------------------------
-- Provenance and the live catalogue
-- ---------------------------------------------------------------------------------------------

-- | The server that actually answered, for the capture's provenance block.
--
-- DB-04 pins an image tag; this is the other half of that assertion -- the tag says what was asked
-- for and this says what replied.
server_version :: Connection -> IO String
server_version con = do
  rows <- query_ con "show server_version"
  pure $ case rows of
    (Only v : _) -> v
    []           -> ""

-- | The identity constraint's columns, IN ORDER, read from the LIVE CATALOGUE.
--
-- Not from the migration file: 23-03 already asserts the DDL text, and a DDL file that was never
-- applied is a different failure from a catalogue that drifted. @with ordinality@ is what makes
-- this an ORDERED answer -- @conkey@ is an array and its order is the constraint's column order,
-- which is lost by any query that lets the planner return the attributes in whatever order it
-- likes.
--
-- The constraint NAME is a parameter taken from 'identity_constraint_name', so this reads back the
-- same constraint the insert path conflicts on.
live_identity_constraint_columns :: Connection -> IO [String]
live_identity_constraint_columns con =
  map fromOnly <$> query con catalogue_sql (Only identity_constraint_name)

catalogue_sql :: Query
catalogue_sql =
  "select a.attname \
  \  from pg_constraint c \
  \  join pg_class t on t.oid = c.conrelid \
  \  join unnest(c.conkey) with ordinality as k(attnum, ord) on true \
  \  join pg_attribute a on a.attrelid = t.oid and a.attnum = k.attnum \
  \ where c.conname = ? and t.relname = 'model_run' \
  \ order by k.ord"
