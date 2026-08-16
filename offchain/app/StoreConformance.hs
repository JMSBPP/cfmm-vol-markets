{-# LANGUAGE OverloadedStrings #-}

-- |
-- THE CAPTURE. The one place in Phase 23 that needs a server, and the first execution of every
-- database-facing line in "Store.Postgres".
--
-- Seven of the phase's guards can only be OBSERVED against a real Postgres: the @Binary@ wart's
-- silent value-level corruption, the @jsonb@ exhibit, the checksum-drift exit code, the
-- concurrency lock, the double run from an empty database, @key_scheme@ orphaning against real
-- SQL, and the live catalogue's constraint columns. A guard that has never been seen rejecting is
-- treated as absent, so every one of them is DRIVEN here and RECORDED as a value. Nothing in this
-- file asserts; the assertions live in @cabal test@, over the committed artifact, with no server.
--
-- == aeson IS PERMITTED HERE, AND ONLY HERE
--
-- This tool writes the JSON REPORT. The report is a DESCRIPTION of an experiment; the @raw@ column
-- is the experiment; and the two never meet. No artifact byte reaches this file's json encoder --
-- every byte-level fact travels as a length and a bare-hex digest, computed by
-- 'Store.Types.sha256_hex' over the bytes themselves. That is why BYTE-03's source scan is scoped
-- to the library's storage modules and not to this directory: the storage path must not be able to
-- re-render a number or reorder a key, and a report that never carries bytes cannot.
--
-- == THE SECOND DATABASE CLIENT IN THE TREE
--
-- Until this file, exactly one module under @offchain\/{lib,app,test}@ imported the client. This
-- is the second, deliberately: the corpus's BROKEN path needs an insert whose parameter is a naked
-- 'BS.ByteString', and putting that in the library would mean shipping the wart so that a test
-- could observe it. It is confined to 'bare_path_insert' below, it is used for nothing else, and
-- @cabal test@ still imports neither.
--
-- == COMPLETENESS
--
-- @sc_complete@ starts 'False' and is flipped only after every block has returned, in the
-- @dr_complete@ \/ @dr_configured_size@ idiom from "Driver.Capture". @sc_law_count@ is
-- @length store_laws@ -- read from the library, never transcribed -- so a capture that recorded
-- fewer verdicts than there are laws is visible as arithmetic rather than as a shorter file.
--
-- The FILE, by contrast, is written exactly ONCE, at the end, through
-- 'Driver.Capture.write_json_atomically'. Writing an incomplete artifact first and overwriting it
-- would destroy the committed evidence before this tool had produced any, which is the failure the
-- capture scripts' restore-on-failure shape exists to prevent. The completeness FLAG is what
-- starts false; the artifact is not.
module Main (main) where

import Control.Exception (SomeException, displayException, try)
import Control.Monad (forM, unless, void)
import Data.Aeson (Value, object, (.=))
import qualified Data.Aeson.Key as K
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (sort)
import Data.Maybe (fromMaybe)
import Data.String (fromString)

import Crypto.Hash (MD5 (..), hashWith)

import Database.PostgreSQL.Simple
  ( Binary (..)
  , Connection
  , Only (..)
  , Query
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

import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesFileExist
  , listDirectory
  , removeDirectoryRecursive
  )
import System.Environment (getArgs, getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)
import System.Process (readProcess, readProcessWithExitCode)

import Driver.Capture (write_json_atomically)
import Store.Class (Store (..))
import Store.Config (migrations_dir, pgstore_dsn, store_conformance_path)
import Store.Json (is_json_value)
import Store.Laws (store_laws)
import Store.Postgres
  ( live_identity_constraint_columns
  , migration_lock_key
  , new_postgres_store
  , run_migrations_or_exit
  , server_version
  , try_migration_lock
  , with_connection
  , with_migration_lock
  )
import Store.Schema (identity_constraint_name)
import Store.Types
  ( Artifact (..)
  , CorpusMember (..)
  , StoredRun (..)
  , adversarial_corpus
  , artifact_bytes
  , artifact_sha256
  , current_key_scheme
  , sha256_hex
  )

-- ---------------------------------------------------------------------------------------------
-- Constants of the capture
-- ---------------------------------------------------------------------------------------------

-- | The real GAMS artifact, copied into THIS workstream with provenance. Reading it across
-- worktrees at capture time would be the Phase-28 ownership problem arriving early.
golden_path :: FilePath
golden_path = "offchain/rig/volume-path-golden.json"

exhibit_model :: String
exhibit_model = "mev_tax_model_one"

exhibit_key :: BS.ByteString
exhibit_key = BS.pack [0x0b, 0xad, 0xc0, 0xde]

exhibit_gams_ver, exhibit_conopt_ver :: String
exhibit_gams_ver   = "54.1"
exhibit_conopt_ver = "4.39.0"

-- | The extra migration the concurrency probe would apply if the lock let it.
--
-- It exists so that @second_migrator_applied == 0@ is a real exclusion and not the arithmetic of
-- an already-migrated database, where a second migrator applies nothing whatever the lock does.
-- It lives only in a scratch directory: the working tree's migration directory is never written,
-- because the library applies EVERY entry it finds there and the suite asserts that directory's
-- whole contents against a manifest.
lock_probe_filename :: FilePath
lock_probe_filename = "003_lock_probe.sql"

lock_probe_sql :: String
lock_probe_sql = "create table lock_probe (n integer not null);\n"

-- | Appended to the SCRATCH copy of the first migration to move its checksum.
drift_line :: String
drift_line = "-- drift probe\n"

first_migration :: FilePath
first_migration = "001_model_run.sql"

report_schema_version :: Int
report_schema_version = 1

-- ---------------------------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------------------------

-- | Two modes, and the second one exists because @MigrationError@ is a VALUE.
--
-- DB-01 says the runner EXITS NON-ZERO on checksum drift. That cannot be demonstrated in-process:
-- the library returns an error constructor and the process stays alive, which is the whole wart
-- 'run_migrations_or_exit' closes. So the capture re-executes ITSELF as a subprocess in
-- @--migrate-only@ mode and records the real 'ExitCode'. Re-executing this binary rather than
-- shelling out to a build tool keeps the observation about the code under test.
main :: IO ()
main = do
  args <- getArgs
  case args of
    ["--migrate-only", dir] -> migrate_only dir
    []                      -> capture
    _                       -> do
      hPutStrLn stderr "usage: store-conformance [--migrate-only <migration-directory>]"
      exitFailure

migrate_only :: FilePath -> IO ()
migrate_only dir = do
  dsn <- pgstore_dsn
  with_connection dsn $ \con -> run_migrations_or_exit con dir
  putStrLn ("migrations applied from " ++ dir)

-- ---------------------------------------------------------------------------------------------
-- The capture
-- ---------------------------------------------------------------------------------------------

capture :: IO ()
capture = do
  dsn      <- pgstore_dsn
  out      <- store_conformance_path
  image    <- fromMaybe "(STORE_PG_IMAGE unset)" <$> lookupEnv "STORE_PG_IMAGE"
  complete <- newIORef False

  golden_present <- doesFileExist golden_path
  unless golden_present $ do
    hPutStrLn stderr ("CAPTURE FAIL: no golden artifact at " ++ golden_path)
    hPutStrLn stderr "              the jsonb exhibit has no subject; nothing was written."
    exitFailure
  golden <- BS.readFile golden_path

  with_connection dsn $ \con -> do
    run_migrations_or_exit con migrations_dir
    version   <- server_version con
    primary   <- current_database con

    verdicts  <- law_verdicts con
    exhibit   <- jsonb_exhibit con golden
    corpus    <- corpus_block con
    agreement <- agreement_block con golden
    migchecks <- migration_checks con dsn primary
    columns   <- live_identity_constraint_columns con
    digests   <- migration_digests
    stamp     <- generated_at

    writeIORef complete True
    done <- readIORef complete

    write_json_atomically out $
      object
        [ "schema_version"    .= report_schema_version
        , "generatedAt"       .= stamp
        , "server_version"    .= version
        , "image_tag"         .= image
        , "sc_complete"       .= done
        , "sc_law_count"      .= length store_laws
        , "law_verdicts"      .= object [K.fromString n .= v | (n, v) <- verdicts]
        , "corpus"            .= corpus
        , "jsonb_exhibit"     .= exhibit
        , "json_agreement"    .= agreement
        , "migration_checks"  .= migchecks
        , "unique_constraint" .= object
            [ "name"    .= identity_constraint_name
            , "columns" .= columns
            ]
        , "migrations"        .= digests
        ]
    putStrLn ("wrote " ++ out ++ "  (server_version " ++ version ++ ", "
               ++ show (length verdicts) ++ " law verdicts, image " ++ image ++ ")")

-- ---------------------------------------------------------------------------------------------
-- (a) The laws, against a REAL server
-- ---------------------------------------------------------------------------------------------

-- | Every law in the library's own list, against @Store.Postgres@, each from a clean schema state.
--
-- The truncate between laws is not tidiness: @Store.Laws@ promises each law writes everything it
-- reads, and the CALLER is required to supply a fresh store so one law's writes cannot satisfy
-- another law's read. On a shared connection this caller's version of \"fresh\" is a truncate.
--
-- A law that THROWS is recorded as a failure NAMING the exception, never allowed to escape and
-- never allowed to stand in for a verdict. The store contract says a misbehaving store returns
-- 'Left'; an exception means something outside that contract happened, and the reader must be able
-- to tell those two apart -- an exception is also exactly what an unreachable server produces.
law_verdicts :: Connection -> IO [(String, String)]
law_verdicts con =
  forM store_laws $ \(name, law) -> do
    truncate_tables con
    outcome <- try (law (new_postgres_store con)) :: IO (Either SomeException (Either String ()))
    pure . (,) name $ case outcome of
      Left e           -> "FAIL (exception escaped the law): " ++ displayException e
      Right (Left why) -> "FAIL: " ++ why
      Right (Right ()) -> "pass"

truncate_tables :: Connection -> IO ()
truncate_tables con = void $ execute_ con "truncate table model_run, byte_corpus"

-- ---------------------------------------------------------------------------------------------
-- (b) The corpus, down BOTH paths
-- ---------------------------------------------------------------------------------------------

-- | The value-level kill, and this is the only place in the repository that produces it.
--
-- For every corpus member: the @Binary@ path through 'store_put_blob' \/ 'store_get_blob', and the
-- BARE path through 'bare_path_insert' below. Both readbacks are recorded as a LENGTH and a bare
-- digest. Nothing here asserts -- the backslash-octal member going in at 6 bytes and coming back
-- at 3 with no error is a recorded pair of numbers, and it is plan 23-05 that reddens on it.
--
-- @bare_outcome@ separates the three MEASURED behaviours, because \"the guard fired\" is evidence
-- only if the reader knows WHICH failure was observed, and one of the three is shaped exactly like
-- a dead connection.
corpus_block :: Connection -> IO [Value]
corpus_block con = do
  let st = new_postgres_store con
  forM adversarial_corpus $ \m -> do
    let name  = cm_name m
        bytes = cm_bytes m
        bare  = "bare/" ++ name

    store_put_blob st name (Artifact bytes)
    binary_back <- store_get_blob st name

    bare_put <- try (bare_path_insert con bare bytes) :: IO (Either SomeException ())
    bare_back <- case bare_put of
      Left e   -> pure (Left (displayException e))
      Right () -> Right <$> store_get_blob st bare

    let (outcome, bare_len, bare_sha, bare_err) = case bare_back of
          Left why          -> ("SqlError" :: String, -1 :: Int, "", Just why)
          Right Nothing     -> ("absent", -1, "", Nothing)
          Right (Just back) -> ( "returned"
                               , BS.length (artifact_bytes back)
                               , artifact_sha256 back
                               , Nothing )

    pure $ object
      [ "name"              .= name
      , "behaviour"         .= show (cm_behaviour m)
      , "in_len"            .= BS.length bytes
      , "in_sha256"         .= sha256_hex bytes
      , "binary_out_len"    .= maybe (-1 :: Int) (BS.length . artifact_bytes) binary_back
      , "binary_out_sha256" .= maybe "" artifact_sha256 binary_back
      , "bare_outcome"      .= outcome
      , "bare_out_len"      .= bare_len
      , "bare_out_sha256"   .= bare_sha
      , "bare_error"        .= bare_err
      ]

-- | THE WART, ON PURPOSE, IN ONE PLACE.
--
-- The parameter is a naked 'BS.ByteString'. @ToField ByteString@ is @Escape@ -- a quoted TEXT
-- literal -- so the server runs @byteain@ over it, which still accepts the legacy escape format.
-- This is the exact defect @Store.Postgres@ exists to prevent, written out here so it can be
-- OBSERVED rather than argued, and deliberately NOT a change to that module: shipping the wart in
-- the library so a capture could see it would be worse than the wart.
--
-- It writes under a prefixed name so the broken row and the correct row for the same corpus member
-- coexist and neither can be mistaken for the other.
bare_path_insert :: Connection -> String -> BS.ByteString -> IO ()
bare_path_insert con name bytes = void $ execute con blob_upsert (name, bytes)

blob_upsert :: Query
blob_upsert =
  "insert into byte_corpus (name, raw) values (?, ?) \
  \on conflict on constraint byte_corpus_identity do update set raw = excluded.raw"

-- ---------------------------------------------------------------------------------------------
-- (c) The jsonb exhibit
-- ---------------------------------------------------------------------------------------------

-- | The real 606-byte artifact through @bytea@ and through @jsonb@, as two digests.
--
-- @doc_text_sha256@ comes from @convert_to(doc::text, 'UTF8')@ -- the server's own rendering of
-- its own column -- never from a json library and never from a re-serialization in Haskell. If the
-- two digests come out EQUAL that is NOT fixed here: it is recorded, and 23-05's check reddens,
-- because equal digests mean @jsonb@ stopped normalizing and the exhibit has lost its subject.
jsonb_exhibit :: Connection -> BS.ByteString -> IO Value
jsonb_exhibit con golden = do
  let st = new_postgres_store con
  truncate_tables con
  store_put st StoredRun
    { sr_model      = exhibit_model
    , sr_key_scheme = current_key_scheme
    , sr_key        = exhibit_key
    , sr_raw        = Artifact golden
    , sr_gams_ver   = exhibit_gams_ver
    , sr_conopt_ver = exhibit_conopt_ver
    }
  back <- store_lookup st exhibit_model current_key_scheme exhibit_key
  doc  <- store_doc_sha256 st exhibit_model current_key_scheme exhibit_key
  pure $ object
    [ "raw_len"         .= BS.length golden
    , "raw_in_sha256"   .= sha256_hex golden
    , "raw_out_sha256"  .= maybe "" (artifact_sha256 . sr_raw) back
    , "doc_text_sha256" .= fromMaybe "" doc
    ]

-- ---------------------------------------------------------------------------------------------
-- The tier-B-predicts-tier-C measurement
-- ---------------------------------------------------------------------------------------------

-- | Does the server-free recogniser agree with @jsonb@?
--
-- The 23-04 ruling made the keyed path require a json value and tightened @Store.Memory@ to match,
-- which puts a hand-written recogniser -- "Store.Json" -- in the position of PREDICTING the
-- server. That is a falsifiable claim, so it is measured rather than asserted: each probe goes to
-- both tiers and both answers are recorded, and a divergence becomes a value in a committed
-- artifact instead of a surprise months later.
--
-- Two probes are expected to DISAGREE and are here because they do: a NUL escape inside a string
-- and an exponent that overflows @numeric@ are both well-formed RFC 8259 and both refused by
-- @jsonb@. Neither is reachable from any fixture this repository writes. They are recorded, not
-- special-cased -- a recogniser that hard-coded them would be asserting agreement instead of
-- measuring it.
agreement_block :: Connection -> BS.ByteString -> IO [Value]
agreement_block con golden =
  forM (agreement_probes golden) $ \(name, bytes) -> do
    server <- try (query con jsonb_probe (Only (Binary bytes)))
                :: IO (Either SomeException [Only Bool])
    pure $ object
      [ "name"             .= name
      , "memory_accepts"   .= is_json_value bytes
      , "postgres_accepts" .= case server of
          Left _             -> False
          Right (Only b : _) -> b
          Right []           -> False
      ]

-- | The SAME conversion the keyed insert performs, so this measures the real gate rather than a
-- lookalike of it. The parameter is 'Binary'-wrapped for the same reason every other @bytea@
-- parameter in this repository is: a bare one would be mangled on the way in and the probe would
-- be about a different byte string than the one named.
jsonb_probe :: Query
jsonb_probe = "select convert_from(?, 'UTF8')::jsonb is not null"

agreement_probes :: BS.ByteString -> [(String, BS.ByteString)]
agreement_probes golden =
  [ ("law-fixture-object",       C8.pack "{\"a\":1}")
  , ("the-disagreeing-document", C8.pack "{\"a\":2,\"note\":\"SECOND-SOLVE-DISAGREED\"}")
  , ("the-non-json-probe",       C8.pack "SECOND-SOLVE-DISAGREED")
  , ("volume-path-golden",       golden)
  , ("trailing-content",         C8.pack "{\"a\":1} {\"b\":2}")
  , ("invalid-utf8",             BS.pack [0xC3, 0x28])
  , ("nul-escape-in-a-string",   C8.pack "\"\\u0000\"")
  , ("numeric-overflow",         C8.pack "1e1000")
  ]

-- ---------------------------------------------------------------------------------------------
-- (d) The migration observations
-- ---------------------------------------------------------------------------------------------

-- | Four things a server must be present to see, plus the two positive controls without which two
-- of them prove nothing.
migration_checks :: Connection -> String -> String -> IO Value
migration_checks con dsn primary = do
  (run1, applied2) <- empty_database_double_run dsn primary
  (drift_exit, drift_err, library_result) <- checksum_drift con
  (held_try, held_applied, freed_try, freed_applied) <- concurrency dsn primary
  pure $ object
    [ "empty_db_run1"                     .= run1
    , "empty_db_run2_applied"             .= applied2
    , "checksum_drift_exit"               .= drift_exit
    , "checksum_drift_stderr"             .= drift_err
    , "checksum_drift_exit_without_guard" .= (0 :: Int)
    , "checksum_drift_library_result"     .= library_result
    , "second_migrator_try_lock"          .= held_try
    , "second_migrator_applied"           .= held_applied
    , "after_release_try_lock"            .= freed_try
    , "after_release_applied"             .= freed_applied
    , "advisory_lock_key"                 .= migration_lock_key
    ]

-- | Two runs against a database created moments ago. The second must apply ZERO.
--
-- \"Applied\" is COUNTED from the library's own bookkeeping table across the second run, not
-- inferred from 'MigrationSuccess' -- which is returned either way, and which is exactly the shape
-- of a migration system that reports success while doing nothing.
empty_database_double_run :: String -> String -> IO (Bool, Int)
empty_database_double_run dsn primary =
  with_fresh_database dsn primary (primary ++ "_empty") $ \con -> do
    first_run <- runMigrations con defaultOptions real_migration_commands
    before    <- applied_count con
    _         <- runMigrations con defaultOptions real_migration_commands
    after     <- applied_count con
    pure ( case first_run of
             MigrationSuccess -> True
             MigrationError _ -> False
         , after - before )

real_migration_commands :: [MigrationCommand]
real_migration_commands = [MigrationInitialization, MigrationDirectory migrations_dir]

-- | The checksum-drift observation, taken TWICE on purpose.
--
-- @checksum_drift_exit@ is a real process exit code, from this binary re-executed against a
-- SCRATCH copy of the migration directory whose first file has one comment line appended. It must
-- be 1, and that 1 is 'run_migrations_or_exit''s @exitFailure@ rather than anything the library
-- does.
--
-- @library_result@ is the same drift, IN-PROCESS, recorded so the reason the guard exists is
-- legible in the artifact: the library returns an error CONSTRUCTOR and the process is still
-- alive, which is why the companion field is the integer 0. The payload is the SCRIPT NAME rather
-- than any particular wording -- 23-03 source-read that -- so only the constructor is recorded and
-- nothing downstream may assert on its text.
--
-- The working tree's migration directory is never written. Only the scratch copy is.
checksum_drift :: Connection -> IO (Int, String, String)
checksum_drift con = do
  scratch <- scratch_dir "drift"
  copy_migrations scratch
  appendFile (scratch </> first_migration) drift_line

  exe <- getExecutablePath
  (code, _, err) <- readProcessWithExitCode exe ["--migrate-only", scratch] ""

  in_process <- runMigrations con defaultOptions
                  [MigrationInitialization, MigrationDirectory scratch]

  removeDirectoryRecursive scratch
  pure ( case code of
           ExitSuccess   -> 0
           ExitFailure n -> n
       , first_line err
       , case in_process of
           MigrationSuccess -> "MigrationSuccess"
           MigrationError _ -> "MigrationError"
       )

-- | The lock, from BOTH sides.
--
-- A holds the blocking lock. B calls the non-blocking form, gets 'False', and while excluded it
-- applies ZERO of a migration directory that carries a THIRD migration the database does not have.
-- Then A releases and B is measured AGAIN: it takes the lock and applies exactly ONE.
--
-- The second half is the positive control and it is not optional. \"Applied 0\" against an
-- already-migrated database is satisfied by a migrator that could never apply anything, by a
-- broken connection, and by a directory with nothing new in it. Only the after-release pair says
-- the lock EXCLUDED work that would otherwise have happened.
--
-- Deterministic: no sleeps, no racing. Both connections live in one process and the ordering is
-- the program's.
concurrency :: String -> String -> IO (Bool, Int, Bool, Int)
concurrency dsn primary = do
  scratch <- scratch_dir "lock"
  copy_migrations scratch
  writeFile (scratch </> lock_probe_filename) lock_probe_sql

  result <- with_fresh_database dsn primary (primary ++ "_lock") $ \a -> do
    _ <- runMigrations a defaultOptions real_migration_commands
    with_connection (dsn_for dsn (primary ++ "_lock")) $ \b -> do
      before     <- applied_count a
      held_try   <- with_migration_lock a (try_migration_lock b)
      held_count <- applied_count a
      freed_try  <- try_migration_lock b
      freed <-
        if freed_try
          then do
            _     <- runMigrations b defaultOptions
                       [MigrationInitialization, MigrationDirectory scratch]
            after <- applied_count a
            pure (after - held_count)
          else pure 0
      _ <- query b "select pg_advisory_unlock(?)" (Only migration_lock_key) :: IO [Only Bool]
      pure (held_try, held_count - before, freed_try, freed)

  removeDirectoryRecursive scratch
  pure result

-- | How many migrations the library believes it has applied. @-1@ would mean the row did not come
-- back at all, which is a different fact from zero and is recorded as such.
applied_count :: Connection -> IO Int
applied_count con = do
  rows <- query_ con "select count(*)::int from schema_migrations"
  pure $ case rows of
    (Only n : _) -> n
    []           -> -1

-- ---------------------------------------------------------------------------------------------
-- (f) The migration digests
-- ---------------------------------------------------------------------------------------------

-- | @(filename, md5)@ COMPUTED from the repository's own migration files at capture time.
--
-- This is 23-05's freshness-oracle input: the suite recomputes these digests from the same files
-- and reddens on drift, so editing a migration without re-capturing is a red. Freshness is
-- COMPUTED and never stamped -- 21-02 measured in this repository that a @generatedAt@ timestamp
-- is not a regeneration witness.
--
-- The digest is OURS. It is not claimed to equal the checksum the migration library stores in its
-- own bookkeeping table, and nothing should compare the two.
--
-- The directory's WHOLE contents are digested, not only its SQL: the library applies every entry
-- it finds there with no extension filter, so a README dropped in would be executed and must
-- therefore be visible to the oracle.
migration_digests :: IO [Value]
migration_digests = do
  names <- sort <$> listDirectory migrations_dir
  forM names $ \n -> do
    bytes <- BS.readFile (migrations_dir </> n)
    pure $ object ["filename" .= n, "md5" .= show (hashWith MD5 bytes)]

copy_migrations :: FilePath -> IO ()
copy_migrations dest = do
  names <- listDirectory migrations_dir
  mapM_ (\n -> copyFile (migrations_dir </> n) (dest </> n)) names

-- ---------------------------------------------------------------------------------------------
-- Plumbing
-- ---------------------------------------------------------------------------------------------

-- | A database created for one observation and dropped when it is over.
--
-- Two of the migration observations need a database with a KNOWN history: the double run needs one
-- with no history at all, and the concurrency probe needs one it is free to add a third migration
-- to. Sharing the primary would make the first vacuous and would leave the second's probe table
-- in a database that later observations read.
with_fresh_database :: String -> String -> String -> (Connection -> IO a) -> IO a
with_fresh_database dsn primary name act = do
  with_connection dsn $ \admin -> do
    void $ execute_ admin (fromString ("drop database if exists \"" ++ name ++ "\""))
    void $ execute_ admin (fromString ("create database \"" ++ name ++ "\""))
  r <- with_connection (dsn_for dsn name) $ \con -> do
    -- VERIFIED, not assumed. If the conninfo override below ever stopped working, every
    -- observation taken from this connection would silently have been about the primary database,
    -- and the double run in particular would have been reading a history it did not create.
    landed <- current_database con
    unless (landed == name) $ do
      hPutStrLn stderr ("CAPTURE FAIL: asked for database " ++ name ++ " and landed in " ++ landed)
      hPutStrLn stderr ("              (the primary is " ++ primary ++ "). Nothing was written.")
      exitFailure
    act con
  with_connection dsn $ \admin ->
    void $ execute_ admin (fromString ("drop database if exists \"" ++ name ++ "\""))
  pure r

-- | Append the database name to the connection string. A later keyword overrides an earlier one in
-- a libpq conninfo string, and 'with_fresh_database' MEASURES that it did rather than trusting it.
dsn_for :: String -> String -> String
dsn_for dsn name = dsn ++ " dbname=" ++ name

current_database :: Connection -> IO String
current_database con = do
  rows <- query_ con "select current_database()"
  pure $ case rows of
    (Only d : _) -> d
    []           -> ""

-- | A scratch directory OUTSIDE the working tree.
--
-- The migration directory is asserted as a whole-directory SET by the suite, and the library
-- applies every entry it finds there, so a probe file written into it would both redden the suite
-- and be executed as SQL. Every mutation below happens to a copy.
scratch_dir :: String -> IO FilePath
scratch_dir tag = do
  let dir = "/tmp" </> ("cfmm-store-conformance-" ++ tag)
  gone <- try (removeDirectoryRecursive dir) :: IO (Either SomeException ())
  void (pure gone)
  createDirectoryIfMissing True dir
  pure dir

first_line :: String -> String
first_line s = case filter (not . null) (lines s) of
  (l : _) -> l
  []      -> ""

-- | @date@ rather than a new dependency, matching every other capture tool in this tree.
generated_at :: IO String
generated_at = trim <$> readProcess "date" ["-u", "+%Y-%m-%dT%H:%M:%SZ"] ""
  where trim = reverse . dropWhile (`elem` (" \t\r\n" :: String)) . reverse
