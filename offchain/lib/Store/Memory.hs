-- |
-- The reference 'Store', backed by two 'IORef'-held 'M.Map's and no server.
--
-- This is where DB-03's "the store checks still discriminate" is actually delivered. The laws in
-- @Store.Laws@ run for REAL against this implementation inside @cabal test@ -- real executions of
-- the store contract, not assertions over a committed file -- so most of the discrimination never
-- needed a database at all.
--
-- == THE ONE THING THAT THROWS, AND WHY IT MUST
--
-- Every function here was total until 23-04. 'put_run' is now the single exception, and it is a
-- USER RULING implemented rather than a defect tolerated.
--
-- @model_run.doc@ is @not null jsonb@ derived from the same parameter as @raw@, so the keyed path
-- REQUIRES a json value: the server computes the row before it resolves the conflict clause, so an
-- artifact that is not json raises before @on conflict do nothing@ is ever reached. 23-03 measured
-- that and refused to decide it. The ruling: the keyed path requires json, this store is tightened
-- to match, and the law fixture that wrote non-json bytes becomes a json value that still
-- disagrees.
--
-- The rationale is worth keeping next to the code. The only tenant of the keyed path is
-- @volume_path.json@, which is always json; BYTE-01's arbitrary-bytes requirement is served by
-- @byte_corpus@, which deliberately has no @jsonb@ column and whose surface -- 'put_blob' below --
-- is untouched and still total. And the point of tightening the REFERENCE store rather than
-- loosening the real one is that TIER B MUST PREDICT TIER C: a law suite that passes here and
-- fails against the server defeats the entire three-tier design, which is the only reason the
-- suite is allowed to be free of a database at all.
--
-- Throwing, rather than silently dropping the row, is what makes the two tiers agree in SHAPE as
-- well as in outcome. A silent no-op would satisfy \"the row is absent\" while being
-- indistinguishable from the last-writer-wins mutant, and
-- @law_a_non_json_artifact_is_rejected_on_the_keyed_path@ separates those two on purpose.
module Store.Memory (new_memory_store) where

import           Control.Exception     (throwIO)
import           Data.IORef            (IORef, modifyIORef', newIORef, readIORef)
import qualified Data.ByteString       as BS
import qualified Data.Map.Strict       as M
import qualified Data.Text.Encoding    as TE
import qualified Data.Text.Encoding.Error as TEE

import Store.Class (Store (..))
import Store.Json (recognise_json_value)
import Store.Types
  ( Artifact
  , KeyScheme
  , StoredRun (..)
  , artifact_bytes
  , derived_doc_from_text
  , derived_doc_sha256
  )

-- | The FULL triple. Keying on @(model, key)@ alone would make an insert under a new
-- 'KeyScheme' silently OVERWRITE the old row instead of creating a second one, which is precisely
-- the corruption KEY-07 exists to prevent -- and a Memory store that got this wrong would let the
-- KEY-07 law pass against it and fail only against Postgres, months later.
type RunKey = (String, KeyScheme, BS.ByteString)

run_key :: StoredRun -> RunKey
run_key sr = (sr_model sr, sr_key_scheme sr, sr_key sr)

new_memory_store :: IO Store
new_memory_store = do
  runs  <- newIORef M.empty
  blobs <- newIORef M.empty
  pure Store
    { store_label      = "Store.Memory"
    , store_put        = put_run runs
    , store_lookup     = \model scheme key -> M.lookup (model, scheme, key) <$> readIORef runs
    , store_put_blob   = put_blob blobs
    , store_get_blob   = \name -> M.lookup name <$> readIORef blobs
    , store_doc_sha256 = \model scheme key ->
        fmap doc_digest . M.lookup (model, scheme, key) <$> readIORef runs
    }

-- | FIRST-WRITER-WINS on the full triple. Re-putting an existing @(model, key_scheme, key)@ is a
-- no-op, so a second solve that disagrees cannot quietly replace the first one -- it has to be
-- READ BACK and compared, which is the whole point of keying on the shock.
--
-- Inserting the same @(model, key)@ under a DIFFERENT 'KeyScheme' SUCCEEDS and creates a second
-- entry. That is not an oversight in the first-writer rule; it is KEY-07.
--
-- THE JSON GATE COMES FIRST, and its order is load-bearing: the server rejects before it resolves
-- the conflict, so a non-json SECOND put of an existing triple must raise here too rather than be
-- absorbed by the first-writer rule. Checking after the map insert would make this store accept
-- exactly the case the server refuses.
put_run :: IORef (M.Map RunKey StoredRun) -> StoredRun -> IO ()
put_run ref sr =
  case recognise_json_value (artifact_bytes (sr_raw sr)) of
    Left why ->
      throwIO . userError $
        "Store.Memory: the keyed path requires a json value and this artifact is not one -- "
          ++ why
          ++ " (model " ++ sr_model sr ++ ", " ++ show (BS.length (artifact_bytes (sr_raw sr)))
          ++ " bytes). model_run.doc is a NOT NULL jsonb derived from the same parameter as raw,"
          ++ " so the server raises on this before the conflict clause is reached. The blob"
          ++ " surface carries arbitrary bytes; the keyed surface does not."
    Right () -> modifyIORef' ref (M.insertWith keep_the_first (run_key sr) sr)

-- | LAST-writer-wins, unlike 'put_run', and deliberately.
--
-- The blob surface is not an identity surface: it has no @key_scheme@, its names are corpus
-- member names, and re-putting one is a RE-MEASUREMENT rather than a conflicting second solve.
-- The bytes are stored and returned verbatim -- no normalization, no encoding, no 'Data.Text'
-- anywhere on this path.
put_blob :: IORef (M.Map String Artifact) -> String -> Artifact -> IO ()
put_blob ref name art = modifyIORef' ref (M.insert name art)

keep_the_first :: a -> a -> a
keep_the_first _new old = old

-- | The derived projection's digest, rendered the only way a server-free store honestly can.
--
-- This decodes the artifact's bytes as UTF-8 and digests that. It does NOT model @jsonb@
-- normalization, and it must not pretend to: the reordered-keys\/re-rendered-numbers exhibit is a
-- POSTGRES observation and belongs to the capture (plan 23-04). A Memory-side "exhibit" would be
-- comparing a value to itself through a function that changes nothing -- the tautology this repo
-- has already been bitten by, wearing an eighth costume.
--
-- 'TEE.lenientDecode' rather than a partial decoder because this module promises totality; the
-- substitution it performs is invisible to every caller, since the only thing that ever leaves
-- here is a digest of the result and the corpus that is not valid UTF-8 travels the blob path.
doc_digest :: StoredRun -> String
doc_digest =
  derived_doc_sha256
    . derived_doc_from_text
    . TE.decodeUtf8With TEE.lenientDecode
    . artifact_bytes
    . sr_raw
