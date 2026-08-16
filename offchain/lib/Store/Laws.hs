-- |
-- THE STORE CONTRACT, AS EXECUTABLE PROPERTIES.
--
-- One implementation, two subjects: these run against "Store.Memory" inside @cabal test@ (no
-- server, no socket) and against @Store.Postgres@ inside the capture tool. A law that only ever
-- ran against Postgres would be a law @cabal test@ cannot discriminate with, and DB-03 is exactly
-- the requirement that @cabal test@ must still discriminate with no database present.
--
-- WHY THESE SEVEN AND NOT FIVE
-- ----------------------------
-- 23-01 drove a NEGATIVE CONTROL through @cabal repl@: the same 'Store.Memory' keyed on
-- @(model, key)@ alone, with @key_scheme@ dropped. It COMPILES, which is the danger, and it was
-- MEASURED to leave the round-trip, first-writer-wins, blob-verbatim and label behaviours
-- COMPLETELY UNCHANGED. Only two behaviours moved: a lookup under a superseded scheme started
-- returning the older scheme's row, and a second scheme's insert was silently dropped.
--
-- So @law_key_scheme_orphans_rather_than_matching@ and @law_same_key_under_a_new_scheme_inserts@
-- are the two laws that carry KEY-07, and the other five do not carry it at all. A law set that
-- exercised round-tripping and first-writer-wins but never looked up under a superseded scheme
-- would be GREEN against a store that has no @key_scheme@ column whatsoever.
--
-- TOTALITY IS PART OF THE CONTRACT
-- --------------------------------
-- A misbehaving store must produce 'Left', never an exception. An exception raised inside the
-- capture tool is indistinguishable in shape from the database being unreachable -- which is the
-- defect class this whole phase exists to close -- so nothing here is partial and nothing here
-- throws. Every 'Left' names the store, the law, and the observed-versus-expected values, because
-- that message is what an operator reads when a law reddens against Postgres, where there is no
-- debugger.
--
-- Each law is self-contained: it writes everything it reads and never depends on another law
-- having run. The CALLER supplies a fresh store per law, so one law's writes cannot satisfy
-- another law's read.
--
-- This module imports nothing from @postgresql-simple@ and nothing from the aeson package, and
-- BYTE-03's source scan asserts that rather than trusting it.
--
-- The sentence above is deliberately written WITHOUT spelling the aeson module path out. That scan
-- greps this very file, so a comment claiming the absence of the import would be matched by the
-- pattern that looks for the import -- prose inside the grep's own blast radius, which is the
-- shape 23-01 already had to unpick three times.
module Store.Laws (store_laws, law_names) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Maybe (isNothing)

import Store.Class (Store (..))
import Store.Types
  ( Artifact (..)
  , CorpusMember (..)
  , KeyScheme (..)
  , StoredRun (..)
  , adversarial_corpus
  , artifact_bytes
  , artifact_sha256
  )

-- ---------------------------------------------------------------------------------------------
-- The surface
-- ---------------------------------------------------------------------------------------------

-- | The seven laws, as DATA rather than as a hardcoded sequence of calls, so that the suite can
-- assert the law SET in both directions and the capture tool can key its recorded verdicts on the
-- same names. A law that is renamed here and nowhere else is a set mismatch, not a silent loss.
store_laws :: [(String, Store -> IO (Either String ()))]
store_laws =
  [ (name_blob_round_trip,   law_blob_round_trip)
  , (name_blob_absent,       law_blob_absent)
  , (name_scheme_orphans,    law_scheme_orphans)
  , (name_scheme_inserts,    law_scheme_inserts)
  , (name_put_then_lookup,   law_put_then_lookup)
  , (name_models_distinct,   law_models_distinct)
  , (name_first_writer_wins, law_first_writer_wins)
  ]

law_names :: [String]
law_names = map fst store_laws

name_blob_round_trip :: String
name_blob_round_trip = "law_blob_round_trips_byte_identically"

name_blob_absent :: String
name_blob_absent = "law_blob_lookup_of_an_absent_name_is_nothing"

name_scheme_orphans :: String
name_scheme_orphans = "law_key_scheme_orphans_rather_than_matching"

name_scheme_inserts :: String
name_scheme_inserts = "law_same_key_under_a_new_scheme_inserts"

name_put_then_lookup :: String
name_put_then_lookup = "law_put_then_lookup_returns_the_same_artifact"

name_models_distinct :: String
name_models_distinct = "law_distinct_models_do_not_collide"

name_first_writer_wins :: String
name_first_writer_wins = "law_first_writer_wins_on_the_identity_triple"

-- ---------------------------------------------------------------------------------------------
-- Message plumbing
-- ---------------------------------------------------------------------------------------------

-- | The ONLY way a law reports a violation. Total in both directions, and it always prefixes the
-- store's own label -- @Store.Memory@ and @Store.Postgres@ run the identical code, so a bare
-- message would not say which subject produced it.
require :: Store -> String -> Bool -> String -> Either String ()
require _  _   True  _   = Right ()
require st law False why = Left (store_label st ++ ": " ++ law ++ ": " ++ why)

-- | A byte string as its LENGTH and its bare-hex digest, which is what a violation message needs.
-- Rendering the bytes themselves would be unreadable for the 606-byte artifact and actively
-- misleading for the corpus, three of whose members are not valid UTF-8.
describe :: BS.ByteString -> String
describe bs = show (BS.length bs) ++ " bytes, sha256 " ++ artifact_sha256 (Artifact bs)

describe_maybe :: Maybe Artifact -> String
describe_maybe = maybe "no row at all" (describe . artifact_bytes)

-- ---------------------------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------------------------

probe_model :: String
probe_model = "mev_tax_model_one"

other_model :: String
other_model = "mev_tax_model_two"

probe_key :: BS.ByteString
probe_key = BS.pack [0x0b, 0xad, 0xc0, 0xde]

scheme_one :: KeyScheme
scheme_one = KeyScheme 1

-- | The SUPERSEDED-versus-current pair KEY-07 is about. Two schemes are the minimum that can tell
-- orphaning apart from a near-miss.
scheme_two :: KeyScheme
scheme_two = KeyScheme 2

run_of :: String -> KeyScheme -> BS.ByteString -> String -> StoredRun
run_of model scheme key body = StoredRun
  { sr_model      = model
  , sr_key_scheme = scheme
  , sr_key        = key
  , sr_raw        = Artifact (C8.pack body)
  , sr_gams_ver   = "54.1"
  , sr_conopt_ver = "4.39.0"
  }

-- | The bytes a law wrote, compared against the bytes it got back. Asserted on the 'Artifact'
-- itself AND on its digest: 'Artifact' has 'Eq' and the digest is what the capture records, so a
-- store that satisfied one and not the other would be a store whose recorded verdicts disagree
-- with its live behaviour.
same_artifact :: Store -> String -> String -> Maybe StoredRun -> Artifact -> Either String ()
same_artifact st law what got want =
  case got of
    Nothing ->
      require st law False
        (what ++ " returned no row, and the row it asked for was written by this same law"
          ++ " moments earlier. Expected " ++ describe (artifact_bytes want) ++ ".")
    Just sr -> do
      _ <- require st law (sr_raw sr == want)
             (what ++ " returned " ++ describe (artifact_bytes (sr_raw sr))
               ++ " and the bytes written were " ++ describe (artifact_bytes want))
      require st law (artifact_sha256 (sr_raw sr) == artifact_sha256 want)
        (what ++ " returned bytes that compare equal but digest differently: got "
          ++ artifact_sha256 (sr_raw sr) ++ ", wrote " ++ artifact_sha256 want)

-- ---------------------------------------------------------------------------------------------
-- The laws
-- ---------------------------------------------------------------------------------------------

-- | BYTE-01 \/ BYTE-05 against the whole adversarial corpus.
--
-- The assertion ORDER is evidence design, not tidiness. @Just@ first, because an absent row and a
-- corrupted row are different defects; then LENGTH, because that is what names the corruption
-- legibly as @6 -> 3@ for the @octal-escape@ member; and only then the DIGEST. A digest-only
-- assertion would report two indistinguishable hex strings and say nothing about what happened.
law_blob_round_trip :: Store -> IO (Either String ())
law_blob_round_trip st = do
  mapM_ (\m -> store_put_blob st (cm_name m) (Artifact (cm_bytes m))) adversarial_corpus
  readbacks <- mapM (\m -> (,) m <$> store_get_blob st (cm_name m)) adversarial_corpus
  pure (mapM_ (uncurry (one_member st)) readbacks)

one_member :: Store -> CorpusMember -> Maybe Artifact -> Either String ()
one_member st m got =
  case got of
    Nothing ->
      require st name_blob_round_trip False
        ("member " ++ cm_name m ++ " was put at " ++ show (BS.length (cm_bytes m))
          ++ " bytes and came back absent")
    Just back -> do
      _ <- require st name_blob_round_trip
             (BS.length (artifact_bytes back) == BS.length (cm_bytes m))
             ("member " ++ cm_name m ++ " went in at " ++ show (BS.length (cm_bytes m))
               ++ " bytes and came back at " ++ show (BS.length (artifact_bytes back)) ++ " bytes")
      require st name_blob_round_trip
        (artifact_sha256 back == artifact_sha256 (Artifact (cm_bytes m)))
        ("member " ++ cm_name m ++ " kept its length and changed its bytes: went in as "
          ++ artifact_sha256 (Artifact (cm_bytes m)) ++ ", came back as "
          ++ artifact_sha256 back)

-- | A name never written returns 'Nothing'.
--
-- Cheap, and it is what stops the round-trip law above from being satisfiable by a store that
-- returns the same bytes for every name it is asked about.
law_blob_absent :: Store -> IO (Either String ())
law_blob_absent st = do
  got <- store_get_blob st absent_blob_name
  pure $
    require st name_blob_absent (isNothing got)
      ("the blob name " ++ absent_blob_name ++ " was never written and the store answered with "
        ++ describe_maybe got)

absent_blob_name :: String
absent_blob_name = "a-name-no-law-in-this-module-ever-writes"

-- | KEY-07, first half. THIS IS ONE OF THE TWO LAWS THAT CARRY IT.
--
-- Write under 'scheme_one', read under 'scheme_two', get 'Nothing'. Not a near-miss, not a
-- fallback, not a warning: a row computed under a superseded key formula must ORPHAN. 23-01
-- MEASURED the alternative -- a store keyed on @(model, key)@ alone hands back the scheme-1 row
-- here, which is a value computed by a formula the caller is no longer using.
law_scheme_orphans :: Store -> IO (Either String ())
law_scheme_orphans st = do
  store_put st (run_of probe_model scheme_one probe_key "{\"a\":1}")
  got <- store_lookup st probe_model scheme_two probe_key
  pure $
    require st name_scheme_orphans (isNothing got)
      ("a row was written under key_scheme " ++ show scheme_one ++ " and a lookup under "
        ++ show scheme_two ++ " for the same (model, key) returned "
        ++ describe_maybe (fmap sr_raw got)
        ++ ". A superseded scheme must orphan, never almost-match.")

-- | KEY-07, second half. THIS IS THE OTHER LAW THAT CARRIES IT.
--
-- The same @(model, key)@ under a NEW scheme is an INSERT, not a conflict and not an overwrite.
-- Both rows survive and each scheme answers with its own bytes. 23-01 MEASURED the alternative:
-- under a two-part key plus first-writer-wins, the second scheme's row is SILENTLY DROPPED, so a
-- key-formula change would quietly stop recording anything at all.
law_scheme_inserts :: Store -> IO (Either String ())
law_scheme_inserts st = do
  store_put st (run_of probe_model scheme_one probe_key "{\"a\":1}")
  store_put st (run_of probe_model scheme_two probe_key "{\"b\":2}")
  first  <- store_lookup st probe_model scheme_one probe_key
  second <- store_lookup st probe_model scheme_two probe_key
  pure $ do
    _ <- same_artifact st name_scheme_inserts
           ("the lookup under key_scheme " ++ show scheme_one ++ ", after a second row was"
             ++ " written under " ++ show scheme_two)
           first (Artifact (C8.pack "{\"a\":1}"))
    same_artifact st name_scheme_inserts
      ("the lookup under the NEW key_scheme " ++ show scheme_two ++ ", whose row shares its"
        ++ " (model, key) with an existing scheme-1 row")
      second (Artifact (C8.pack "{\"b\":2}"))

-- | The plain round-trip of a keyed row.
--
-- Note what this law does NOT establish, per 23-01's negative control: it is UNCHANGED by dropping
-- @key_scheme@ from the store's key entirely. It is a floor, not evidence for KEY-07.
law_put_then_lookup :: Store -> IO (Either String ())
law_put_then_lookup st = do
  store_put st (run_of probe_model scheme_one probe_key "{\"a\":1}")
  got <- store_lookup st probe_model scheme_one probe_key
  pure $
    same_artifact st name_put_then_lookup
      "the lookup of the triple this law had just written"
      got (Artifact (C8.pack "{\"a\":1}"))

-- | The model is part of the identity, so the same key under two models is two rows.
law_models_distinct :: Store -> IO (Either String ())
law_models_distinct st = do
  store_put st (run_of probe_model scheme_one probe_key "{\"a\":1}")
  store_put st (run_of other_model scheme_one probe_key "{\"b\":2}")
  first  <- store_lookup st probe_model scheme_one probe_key
  second <- store_lookup st other_model scheme_one probe_key
  pure $ do
    _ <- same_artifact st name_models_distinct
           ("the lookup under model " ++ probe_model ++ ", which shares its key with "
             ++ other_model)
           first (Artifact (C8.pack "{\"a\":1}"))
    same_artifact st name_models_distinct
      ("the lookup under model " ++ other_model ++ ", which shares its key with " ++ probe_model)
      second (Artifact (C8.pack "{\"b\":2}"))

-- | FIRST-writer-wins on @(model, key_scheme, key)@, and this is a correctness property rather
-- than a preference.
--
-- The store is keyed on the SHOCK that produced the output, so a second solve of the same shock
-- that disagrees with the first is the determinism defect Phase 25 exists to catch. A
-- last-write-wins store destroys exactly the evidence that defect is made of: the disagreement
-- would have to be READ BACK and compared, and there would be nothing left to compare against.
law_first_writer_wins :: Store -> IO (Either String ())
law_first_writer_wins st = do
  store_put st (run_of probe_model scheme_one probe_key "{\"a\":1}")
  store_put st (run_of probe_model scheme_one probe_key "SECOND-SOLVE-DISAGREED")
  got <- store_lookup st probe_model scheme_one probe_key
  pure $
    same_artifact st name_first_writer_wins
      ("the lookup after a SECOND put on the identity triple; the first writer's bytes must"
        ++ " survive so that a disagreeing re-solve is detectable rather than absorbed")
      got (Artifact (C8.pack "{\"a\":1}"))
