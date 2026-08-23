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
-- ONE law CATCHES, which is the same promise from the other side.
-- @law_a_non_json_artifact_is_rejected_on_the_keyed_path@ asserts that a store REFUSED something,
-- and a refusal arrives as an exception from both tiers. It is caught here and turned into a
-- value, alongside a liveness control, so that \"the store refused\" is never reported by this
-- module in the same shape as \"the store is unreachable\".
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

import Control.Exception (SomeException, displayException, try)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Either (isLeft)
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

-- | The eight laws, as DATA rather than as a hardcoded sequence of calls, so that the suite can
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
  , (name_non_json_rejected, law_non_json_rejected)
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

name_non_json_rejected :: String
name_non_json_rejected = "law_a_non_json_artifact_is_rejected_on_the_keyed_path"

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
--
-- THE DISAGREEING PAYLOAD IS A JSON VALUE, and it was not always. Until 23-04 it was the bare
-- bytes @SECOND-SOLVE-DISAGREED@, which the keyed path cannot carry -- @model_run.doc@ is
-- @not null jsonb@ and the server computes the row before it resolves the conflict clause, so
-- against @Store.Postgres@ this law raised while against @Store.Memory@ it passed. The USER RULING
-- at 23-04 was that the keyed path REQUIRES json and the reference store is tightened to match, so
-- the fixture became a json value that still disagrees. Its discriminating power is unchanged: the
-- law tests WHICH blob comes back, and these bytes still differ from the first writer's. The old
-- bytes were not discarded -- they are the probe in
-- 'law_a_non_json_artifact_is_rejected_on_the_keyed_path' below, which is the law that now carries
-- the rule they revealed.
law_first_writer_wins :: Store -> IO (Either String ())
law_first_writer_wins st = do
  store_put st (run_of probe_model scheme_one probe_key "{\"a\":1}")
  store_put st (run_of probe_model scheme_one probe_key disagreeing_document)
  got <- store_lookup st probe_model scheme_one probe_key
  pure $
    same_artifact st name_first_writer_wins
      ("the lookup after a SECOND put on the identity triple; the first writer's bytes must"
        ++ " survive so that a disagreeing re-solve is detectable rather than absorbed")
      got (Artifact (C8.pack "{\"a\":1}"))

-- | The second solve's payload: a json value, and one that disagrees.
--
-- It carries the word the old non-json bytes carried, in a field, because the FAILURE MESSAGE is
-- where \"disagreed\" needs to be legible -- not in the bytes.
disagreeing_document :: String
disagreeing_document = "{\"a\":2,\"note\":\"SECOND-SOLVE-DISAGREED\"}"

-- | THE SCHEMA RULE, AS AN EXECUTABLE LAW rather than as a comment.
--
-- The keyed path requires a json value, because @model_run.doc@ is a @not null jsonb@ derived from
-- the same parameter as @raw@. This law is that rule, and it exists because the alternative was a
-- sentence in a haddock that no tier could disagree with.
--
-- FOUR OBSERVATIONS, IN THIS ORDER, AND THE ORDER IS THE EVIDENCE DESIGN:
--
--   1. the LIVENESS control -- a json row written and read back. Without it, every remaining
--      assertion is satisfied by a store that stores nothing, by a store whose every call raises,
--      and by a database that is switched off. \"The put failed and the row is absent\" is the
--      exact shape of an unreachable server, which is this repository's defect class wearing its
--      seventh costume, so the control comes FIRST and a dead subject fails HERE with a message
--      that says so;
--   2. the non-json put RAISED. A store that accepted it and dropped it silently would satisfy (3)
--      while behaving nothing like the server, and it is also indistinguishable from the no-op-put
--      mutant that @law_put_then_lookup_returns_the_same_artifact@ exists to kill;
--   3. the row is ABSENT -- a VALUE-level observation, not an exception one. This is what says the
--      rejection was a rejection and not a write that also happened to complain;
--   4. the rejection did not damage the store: the liveness row is still readable AFTER the
--      refused write, which is the property that makes a rejected artifact recoverable rather than
--      a poisoned connection.
--
-- The probe bytes are the ones 23-03 found this incompatibility with.
law_non_json_rejected :: Store -> IO (Either String ())
law_non_json_rejected st = do
  live_before  <- attempt (store_put st (run_of probe_model scheme_one probe_key live_document))
  live_read    <- attempt (store_lookup st probe_model scheme_one probe_key)
  refused      <- attempt (store_put st (run_of probe_model scheme_one non_json_key non_json_body))
  orphan       <- attempt (store_lookup st probe_model scheme_one non_json_key)
  live_after   <- attempt (store_lookup st probe_model scheme_one probe_key)
  pure $ do
    -- (1) LIVENESS. Everything below is vacuous without it.
    _ <- case (live_before, live_read) of
           (Left why, _) ->
             require st name_non_json_rejected False
               ("the LIVENESS control could not even write a json row: " ++ why
                 ++ ". Nothing below this line is evidence about json rejection -- this is what a"
                 ++ " store that is switched off looks like.")
           (_, Left why) ->
             require st name_non_json_rejected False
               ("the LIVENESS control could not read its json row back: " ++ why)
           (Right (), Right got) ->
             same_artifact st name_non_json_rejected
               "the LIVENESS control, a json row written and read back before any rejection"
               got (Artifact (C8.pack live_document))
    -- (2) The non-json put RAISED.
    _ <- require st name_non_json_rejected (isLeft refused)
           ("a " ++ show (BS.length (C8.pack non_json_body)) ++ "-byte artifact that is not a json"
             ++ " value was ACCEPTED on the keyed path. model_run.doc is a NOT NULL jsonb derived"
             ++ " from the same parameter as raw, so the server refuses this before the conflict"
             ++ " clause is reached; a store that accepts it does not predict the server, which is"
             ++ " the only reason the law suite is allowed to run without one.")
    -- (3) And the row is ABSENT -- the value-level half.
    _ <- case orphan of
           Left why ->
             require st name_non_json_rejected False
               ("the lookup AFTER the rejected put raised rather than answering: " ++ why
                 ++ ". A refusal must leave the store readable; this is what a poisoned connection"
                 ++ " looks like and it is a different defect from accepting the artifact.")
           Right got ->
             require st name_non_json_rejected (isNothing got)
               ("the non-json put was refused and the row is PRESENT anyway: "
                 ++ describe_maybe (fmap sr_raw got))
    -- (4) The refusal did not damage what was already there.
    case live_after of
      Left why ->
        require st name_non_json_rejected False
          ("the liveness row could not be read AFTER the refused write: " ++ why
            ++ ". The refusal cost the store its earlier contents.")
      Right got ->
        same_artifact st name_non_json_rejected
          "the LIVENESS row, re-read AFTER the refused write"
          got (Artifact (C8.pack live_document))

-- | The bytes that revealed the rule. 23-03 measured @model_run.doc@ refusing exactly these while
-- @Store.Memory@ accepted them, and refused to decide which side should move.
non_json_body :: String
non_json_body = "SECOND-SOLVE-DISAGREED"

live_document :: String
live_document = "{\"live\":true}"

-- | A key of this law's own, so the refused write and the liveness control cannot be confused for
-- one another by a store that ignores the key entirely.
non_json_key :: BS.ByteString
non_json_key = BS.pack [0x0b, 0xad, 0xf0, 0x0d]

-- | Run an action and turn ANY exception into a reason string.
--
-- The store contract says a law returns 'Left' and never throws, and the only way to keep that
-- promise while asserting that a store DID throw is to catch here. Recording
-- 'displayException' rather than a bare @show@ is deliberate: the server's error carries the
-- column, the type and the offending token, and that text is what an operator reads when this law
-- reddens against Postgres, where there is no debugger.
attempt :: IO a -> IO (Either String a)
attempt io = do
  r <- try io
  pure $ case r of
    Left e  -> Left (displayException (e :: SomeException))
    Right a -> Right a
